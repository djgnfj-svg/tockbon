class_name Run
extends RefCounted
## Session state: which node of the map the army is standing on, which reward is waiting to be taken,
## and whether the run is still going. One island's fight lives in `battle.gd`, the map's shape is
## `rules.gd`'s node table and the walk over it is `map.gd`; this file is everything between them.
##
## **`army` is built in exactly two places — `_init` and `restart` — and nowhere else.** HP carries
## across islands by identity: the same rows, the same ids, the same wounds. So `begin_island` hands
## `battle` the roster this object already holds instead of making one. Building a fresh `Army` there
## instead would heal every soldier and drop every beak between islands **while a check that only counts
## soldiers stayed green**, which is the mutation the first-slice plan names for `net_run` to bite on.
##
## Every value that changes what happens lives in `rules.gd`, and the islands' own facts — how many
## there are, their grids, their spawns, their time limits — live in `islands.gd`. Nothing here holds a
## second copy of either; a number counted in two places diverges.
##
## See the cell army GDD for the session loop, and the first-slice plan's "The sim — shapes and entry
## points" for the signatures below.


## Where the run is. `MAP` means the node map is open and a node is waiting to be pressed; `BATTLE`
## means an island is open and `begin_island` will build its fight; `REWARD` means a beak pick is
## waiting; `PICK` means the six cards are up and two are waiting to be taken; `REFIT` means the two
## taken cards are ready to be laid into a board; `WON` and `LOST` are both terminal until `restart`.
##
## ⚠ **`MAP` is FIRST so it is 0**, and a default-constructed int therefore lands on the map rather
## than in a battle against an island nobody entered. ⚠ **Nothing anywhere may compare a state against
## a literal int** — `net_run` pins `State.MAP == 0` and the rest by name.
enum State { MAP, BATTLE, REWARD, PICK, REFIT, WON, LOST }


## The island the node the army is standing on opened. **It never leaves the range of real islands.**
## An out-of-range index here would read as a real island to every caller that indexes with it and
## would only fault later, inside whichever of them indexed first.
##
## ⚠ **It is no longer the run's position.** The position is `map.at()`; this is written only by
## `enter_node`, and `_advance` does not touch it. A `+ 1` put back here walks the run past an island
## nobody chose, and the map is then a picture the run ignores.
var island_index := 0

## The roster that survives islands. Never rebuilt outside `_reset`.
var army: Army = null

## The route walked so far. Built in `_reset` beside `army` — **the two places a run's state is built
## stay exactly two.**
var map: RunMap = null

var _state := State.MAP
var _pending := Rules.Reward.NONE

## `Rules.CARDS_PER_WIN` pairs, flat: `cards[2*k]` is the part, `cards[2*k + 1]` the species.
## ⚠ **Flat and parallel, not an Array of Arrays**, for the reason `army.gd`'s header gives.
var cards := PackedInt32Array()
var cards_taken := PackedByteArray()

## ⚠⚠ **The first RNG in `src/sim/`, and it is bounded on purpose**: one object, one reader
## (`_draw_cards`), one seed verb. **The map stays authored** — `title-and-map`'s reason for that (four
## routes a net can walk exhaustively) is untouched.
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_reset()


## Back to the identical starting state. A run carries no meta and no unlock, so this is the whole of
## it — and it shares `_reset` with `_init` on purpose: a field added to one path and forgotten in the
## other would make the second run start somewhere the first did not, with nothing to bark about it.
func restart() -> void:
	_reset()


func _reset() -> void:
	island_index = 0
	army = Army.new()
	army.add_starting_force()
	map = RunMap.new()
	_state = State.MAP
	_pending = Rules.Reward.NONE
	cards = PackedInt32Array()
	cards_taken = PackedByteArray()
	_rng.randomize()


## For nets and the probe: makes `_draw_cards()` reproducible.
func seed_cards(s: int) -> void:
	_rng.seed = s


## The map screen's ONE verb: step onto a node. Returns false and changes nothing when the run is not
## on the map or the node is not reachable — the caller validates its own click, matching `RunMap.enter`
## and `grid.load_rows`.
##
## Reachability is asked of `map.enter` and nowhere else here. Testing `is_reachable` first and then
## calling `enter` would be the same rule written twice, free to disagree the day one of them grows a
## clause.
##
## ⚠ **Every node opens an island now — the chest is gone.** `enter_node` used to have a second branch
## for a node with no island (`island < 0`, applying its reward on the spot and staying on the map);
## that branch is DELETED rather than left unreachable, because an unreachable arm reads as a supported
## case. No node's `map_island_of` is ever negative any more.
func enter_node(n: int) -> bool:
	if _state != State.MAP:
		return false
	if not map.enter(n):
		return false
	island_index = Rules.map_island_of(n)
	_state = State.BATTLE
	return true


## Builds the current island's fight and hands it back. Returns `null` when no island is open — **on
## the map**, during a reward pick, or once the run is over — so a caller that ignores `state()` gets a
## null instead of a fight on an island the army has already left or has not chosen yet.
##
## The `Grid` is new every time. `load_rows` does clear reservations, but a grid built here can never
## be one another `Battle` still holds unit ids inside, and that costs 1536 tiles once per island
## (`boat-and-landing`'s 48 x 32 grid, up from 576).
func begin_island() -> Battle:
	if _state != State.BATTLE:
		return null
	var grid := Grid.new()
	grid.load_rows(Islands.rows_of(island_index))
	var battle := Battle.new()
	battle.setup(grid, army, Islands.spawns_of(island_index), Islands.time_limit_of(island_index))
	return battle


## Closes the island. A loss is terminal at once; a win queues the reward of **the node the run is
## standing on**, and the reward is what decides whether the run stops for a pick or goes back to the
## map by itself.
##
## Ignored unless an island is actually open, so a loss cannot be un-lost, a finished run cannot be
## reopened, and a reward waiting to be picked cannot be skipped past.
##
## ⚠ **The double-close hole this guard used to leave is now closed by the map, not by this line.**
## It used to open the next island by itself, so a second call closed *that* one and the run walked
## past an island nobody fought; now a win lands in `MAP` and the second call falls out on the guard
## above. ⚠ **That is a property of `_advance` no longer stepping `island_index`** — put the step back
## and this paragraph becomes a lie again as well.
## ⚠ **Six cards are drawn on every win, before the node's own reward is queued** — 「6개중 2택」, paid
## by every fight ON TOP of the node's own reward (open question A, closed). ⚠ **A node pays cards iff
## it is not the boss** — the boss node is the one node that ends the run, and `map.is_finished()` is
## the same fact `_advance()` checks first; a route walk cannot ask `map.is_finished()` and a standing
## run cannot ask a route, so this is the one place both directions agree.
func finish_island(won: bool) -> void:
	if _state != State.BATTLE:
		return
	if not won:
		_state = State.LOST
		return
	if not map.is_finished():
		_draw_cards()
	_queue_reward(map.at())


## `Rules.CARDS_PER_WIN` independent draws of `(part, species)`, flat. `cards_taken` is cleared with it,
## so a stale mark from a previous win can never survive into the next one.
func _draw_cards() -> void:
	cards = PackedInt32Array()
	cards.resize(Rules.CARDS_PER_WIN * 2)
	for k in Rules.CARDS_PER_WIN:
		cards[2 * k] = _rng.randi_range(0, Rules.part_count() - 1)
		cards[2 * k + 1] = _rng.randi_range(0, Rules.species_count() - 1)
	cards_taken = PackedByteArray()
	cards_taken.resize(Rules.CARDS_PER_WIN)


## Queues the node's reward and resolves it as far as it can go on its own. **One dispatch**, so a
## reward that needs no fight and one that did are applied by the same lines.
func _queue_reward(n: int) -> void:
	_pending = Rules.map_reward_of(n)
	match _pending:
		Rules.Reward.COUNT:
			take_count_reward()
		Rules.Reward.BEAK:
			_state = State.REWARD
		_:
			_advance()


## `Rules.Reward.NONE`, `COUNT` or `BEAK` — what is waiting to be taken right now.
func pending_reward() -> int:
	return _pending


## A `COUNT` node's reward: more soldiers, at full HP, appended to the roster that is already carrying
## the survivors. `Army.recruit` is what fills their HP, so no starting value is written twice.
##
## Applied the moment it is queued, because there is nothing to choose — it is public only so that the
## applying of the reward and the naming of it are the same function in all three cases.
func take_count_reward() -> void:
	if _pending != Rules.Reward.COUNT:
		return
	for s in Rules.summon_slot_count():
		for _i in range(Rules.slot_reward_count(s)):
			army.recruit(s)
	_pending = Rules.Reward.NONE
	_advance()


## A `BEAK` node's reward: the beak onto one **surviving** soldier, then back to the map.
##
## A bad pick — an id off the end of the roster, or a soldier who died on the island that paid for it —
## leaves everything where it was: the reward stays pending and `state()` stays `REWARD`, so the caller
## can see that nothing happened and ask again. It does not bark, matching `grid.load_rows`: validating
## a click is the caller's job, and a bark here would have to be forgiven by every net that pokes at the
## roster. What it must never do is consume the reward without applying it.
##
## ⚠ **A run may collect more than one beak now** — a route can step on two beak nodes — so nothing
## downstream may treat a beak already on the roster as proof this reward was spent. `_pending` is.
func apply_beak(soldier_id: int) -> void:
	if _pending != Rules.Reward.BEAK:
		return
	if soldier_id < 0 or soldier_id >= army.alive.size():
		return
	if army.alive[soldier_id] == 0:
		return
	army.has_beak[soldier_id] = 1
	_pending = Rules.Reward.NONE
	_advance()


## Takes card `k`. Refused (and nothing changes) unless the run is in `PICK`, `k` is in range, that
## card has not already been taken, and fewer than `Rules.CARD_PICKS` have been taken so far.
##
## When the `CARD_PICKS`th card is taken, the run moves to `REFIT` — the two taken cards are already
## in `army.loadout`'s held pile by then, so refit has something to lay into a board.
func take_card(k: int) -> bool:
	if _state != State.PICK:
		return false
	if k < 0 or k >= Rules.CARDS_PER_WIN:
		return false
	if cards_taken[k] != 0:
		return false
	var taken := _cards_taken_count()
	if taken >= Rules.CARD_PICKS:
		return false
	cards_taken[k] = 1
	army.loadout.take_card(int(cards[2 * k]), int(cards[2 * k + 1]))
	if taken + 1 >= Rules.CARD_PICKS:
		_state = State.REFIT
	return true


func _cards_taken_count() -> int:
	var n := 0
	for b in cards_taken:
		if b != 0:
			n += 1
	return n


## Closes the refit screen. Refused unless the run is actually in `REFIT`. ⚠ **The boss pays no cards**
## (`Reward.NONE`, and `_advance` checks `map.is_finished()` first), so this arm exists only so a
## future boss-that-pays cannot end a run on the refit screen.
func close_refit() -> bool:
	if _state != State.REFIT:
		return false
	_advance()
	return true


## `State.MAP`, `State.BATTLE`, `State.REWARD`, `State.PICK`, `State.REFIT`, `State.WON` or
## `State.LOST`.
func state() -> int:
	return _state


## The reward is settled: `WON` if the map is finished; else `PICK` if there is a card still undrawn
## from (`cards.size() > 0 and taken < CARD_PICKS`); else `MAP`.
##
## ⚠⚠ **The `PICK` arm is ABOVE the `MAP` arm.** Below it, the cards are drawn and never shown and the
## round stays green — the roster grows (or the beak lands), the run walks back to the map, and every
## check that only counts soldiers or beaks stays green.
##
## ⚠ **It does not touch `island_index`.** Walking to the next island by itself is what the old
## `island_index + 1` did, and a map added on top of that just gets walked past — the map appears, the
## run ignores it, and every check that only counts islands stays green. Which node comes next is the
## player's press, and `enter_node` is the only writer.
func _advance() -> void:
	if map.is_finished():
		_state = State.WON
	elif cards.size() > 0 and _cards_taken_count() < Rules.CARD_PICKS:
		_state = State.PICK
	else:
		_state = State.MAP
