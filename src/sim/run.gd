class_name Run
extends RefCounted
## Session state: which node of the map the army is standing on, which reward is waiting to be taken,
## and whether the run is still going. One island's fight lives in `battle.gd`, the map's shape is
## `rules.gd`'s node table and the walk over it is `map.gd`; this file is everything between them.
##
## **`army` is built in exactly two places — `_init` and `restart` — and nowhere else.** HP carries
## across islands by identity: the same rows, the same ids, the same wounds. So `begin_island` hands
## `battle` the roster this object already holds instead of making one. Building a fresh `Army` there
## instead would heal every soldier between islands **while a check that only counts
## soldiers stayed green**, which is the mutation the first-slice plan names for `net_run` to bite on.
##
## Every value that changes what happens lives in `rules.gd`, and the islands' own facts — how many
## there are, their grids, their spawns, their time limits — live in `islands.gd`. Nothing here holds a
## second copy of either; a number counted in two places diverges.
##
## ⚠ **The 「cell army GDD」 this line used to cite does not exist** (2026-08-25, 티켓 23) — the deleted
## cell game's design document. The session loop is read out of `.scratch/cell-hook/`'s map. See the
## first-slice plan's "The sim — shapes and entry, and the first-slice plan's "The sim — shapes and entry
## points" for the signatures below.


## Where the run is. `MAP` means the node map is open and a node is waiting to be pressed; `BATTLE`
## means an island is open and `begin_island` will build its fight; a card pick is
## waiting; `PICK` means the six cards are up and two are waiting to be taken; `REFIT` means the two
## taken cards are ready to be laid into a board; `WON` and `LOST` are both terminal until `restart`.
##
## ⚠ **`MAP` is FIRST so it is 0**, and a default-constructed int therefore lands on the map rather
## than in a battle against an island nobody entered. ⚠ **Nothing anywhere may compare a state against
## a literal int** — `net_run` pins `State.MAP == 0` and the rest by name.
## ⚠⚠ **`REWARD` IS GONE** (2026-08-25): its only producer was a `Reward.BEAK` node, and the user
## deleted that reward — 「부리 보상 없지 끝나면 카드보상으로 통일했잖아」. A state nothing can enter
## is a screen nobody can reach, and leaving it would keep every check about it green.
enum State { MAP, BATTLE, PICK, REFIT, WON, LOST }


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

## `Rules.CARDS_PER_WIN` cards. **`cards[k]` means an ITEM id or a `UNITS` row depending on
## `card_kind[k]`** — a card is one of two things since 티켓 15.
## ⚠ **Flat and parallel, not an Array of Arrays**, for the reason `army.gd`'s header gives.
var cards := PackedInt32Array()
## `Rules.CardKind` per card, index-aligned with `cards`. ⚠ **Never inferred from the value**: item 4
## and unit row 4 are both 4, and a reader that guessed would be right most of the time.
var card_kind := PackedInt32Array()
var cards_taken := PackedByteArray()

## ⚠⚠ **The first RNG in `src/sim/`, and it is bounded on purpose**: one object, one reader
## (`_draw_cards`), one seed verb. **The map stays authored** — `title-and-map`'s reason for that (four
## routes a net can walk exhaustively) is untouched.
var _rng := RandomNumberGenerator.new()

## Whether the round currently on the table was dealt beasts-only. **Read by `seed_cards` alone**, so
## a re-deal produces the same KIND of round the player is looking at rather than an ordinary one.
var _round_is_beasts_only := false


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
	card_kind = PackedInt32Array()
	cards_taken = PackedByteArray()
	_rng.randomize()
	# ⚠⚠ **A RUN OPENS ON A CARD SCREEN, NOT ON THE MAP** (2026-08-25, the user: 「시작하자마자 세 개
	# 중에 하나 고르는 거 그거 하고 가자」). Three cards, **beasts only** — equipment here would make
	# the one species a run holds stronger instead of splitting the horde, which pushes the fork this
	# game is about a whole island later.
	_draw_cards(true)
	_state = State.PICK


## For nets and the probe: makes `_draw_cards()` reproducible.
##
## ⚠⚠ **AND IT RE-DEALS AN UNTOUCHED ROUND.** The opening three are drawn inside `_reset`, which runs
## before any caller can hand a seed in — so without this the first screen of the whole game is the
## one screen nothing can ever pin, and 「무작위라 못 잰다」 would be true of it forever.
##
## ⚠ **Only while nothing has been taken from that round.** A seed handed in mid-pick must never
## replace cards somebody is looking at.
func seed_cards(s: int) -> void:
	_rng.seed = s
	if _state == State.PICK and _cards_taken_count() == 0:
		_draw_cards(_round_is_beasts_only)


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
	Islands.load_into(grid, island_index)
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


## `Rules.CARDS_PER_WIN` independent draws. `cards_taken` is cleared with them, so a stale mark from a
## previous win can never survive into the next one.
##
## ⚠⚠ **THE KIND IS ROLLED FIRST, PER CARD, and both halves of that sentence are decisions.**
##  · **Kind first**, for exactly the reason the rarity roll below already carries in its own comment:
##    pooling beasts and items into one list makes a beast quietly rarer every time an item is added,
##    so the drop table would move whenever the CONTENT moved
##  · **Per card and never "exactly one of the three"** — a fixed share IS a reservation, and the user
##    cut the reservation on 2026-08-25. Some rounds hold no beast; some hold three
##
## `beasts_only` is 시작 라운드's door: the opening round pays beasts and nothing else.
func _draw_cards(beasts_only: bool = false) -> void:
	_round_is_beasts_only = beasts_only
	cards = PackedInt32Array()
	cards.resize(Rules.CARDS_PER_WIN)
	card_kind = PackedInt32Array()
	card_kind.resize(Rules.CARDS_PER_WIN)
	var pool := _species_pool()
	for k in Rules.CARDS_PER_WIN:
		# ⚠ **An empty pool falls back to an item, whatever was asked for.** A beast card naming a
		# species the run already holds is a card that cannot be picked — a dead face on the screen.
		if pool.size() > 0 and (beasts_only or _rng.randf() < Rules.SPECIES_CARD_WEIGHT):
			card_kind[k] = Rules.CardKind.SPECIES
			# ⚠⚠ **WITHOUT REPLACEMENT — no species may stand twice in one round.** Drawn with it,
			# 64% of opening rounds held a duplicate and 6% were three of one animal, which is a
			# three-card screen offering one choice. **There is exactly enough slack**: four
			# candidates for three cards on the opening round. A pool that runs out mid-round falls
			# through to equipment on the lines below, which is what it already did when empty.
			var at := _rng.randi_range(0, pool.size() - 1)
			cards[k] = int(pool[at])
			pool.remove_at(at)
			continue
		card_kind[k] = Rules.CardKind.ITEM
		# **Rarity first, item second.** Rolling straight over the item list would make legendaries
		# rarer every time a common one was added — the drop table would move when the CONTENT moved.
		var rarity := Rules.rarity_at_roll(_rng.randi_range(0, Rules.rarity_weight_total() - 1))
		var items := Rules.items_of_rarity(rarity)
		cards[k] = int(items[_rng.randi_range(0, items.size() - 1)]) if items.size() > 0 else 0
	cards_taken = PackedByteArray()
	cards_taken.resize(Rules.CARDS_PER_WIN)


## The beast rows this run could still take: on the player's side, not already in a slot, and only
## while there is a slot left to put one in. **Empty is the ceiling** — every card is then an item.
func _species_pool() -> PackedInt32Array:
	var out := PackedInt32Array()
	if army == null or army.slot_count() >= Rules.SUMMON_SLOT_MAX:
		return out
	for r in Rules.species_card_count():
		var ty := Rules.species_card_type_of(r)
		if army.slot_of_type(ty) < 0:
			out.append(ty)
	return out


## Queues the node's reward and resolves it as far as it can go on its own. **One dispatch**, so a
## reward that needs no fight and one that did are applied by the same lines.
func _queue_reward(n: int) -> void:
	_pending = Rules.map_reward_of(n)
	match _pending:
		Rules.Reward.COUNT:
			take_count_reward()
		_:
			_advance()


## `Rules.Reward.NONE` or `COUNT` — what is waiting to be taken right now.
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
	# ⚠ **Over the RUN's own slots** — the pay table is indexed by slot number and a run that has
	# registered fewer slots than the table has rows collects only the rows it reaches.
	for s in army.slot_count():
		for _i in range(Rules.slot_pay_of(s)):
			army.recruit(s)
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
	if int(card_kind[k]) == Rules.CardKind.SPECIES:
		_take_species_card(int(cards[k]))
	else:
		army.loadout.take_card(int(cards[k]))
	if taken + 1 >= Rules.CARD_PICKS:
		# ⚠⚠ **The fork is 「is there anything in the pile」 and NOT 「what kind was that card」.**
		# Branching on the kind makes two paths out of this screen, and two paths diverge — a beast
		# card taken while an earlier item is still unfitted would strand that item.
		if army.loadout.held.is_empty():
			_advance()
		else:
			_state = State.REFIT
	return true


## A beast card: the species takes the next free slot and **arrives with bodies**.
##
## ⚠⚠ **The bodies are not optional.** Registering alone adds a button that refuses when pressed —
## the user's own `Reward.COUNT` failure (a thing that exists and is not on screen) built backwards.
## ⚠ A refused registration (full, already held, enemy side) recruits nobody: `register_species` is
## the one place that decides, and this reads its answer instead of re-deciding.
func _take_species_card(type_id: int) -> void:
	var slot := army.register_species(type_id)
	if slot < 0:
		return
	for _i in Rules.SPECIES_CARD_BODIES:
		army.recruit(slot)


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


## `State.MAP`, `State.BATTLE`, `State.PICK`, `State.REFIT`, `State.WON` or
## `State.LOST`.
func state() -> int:
	return _state


## The reward is settled: `WON` if the map is finished; else `PICK` if there is a card still undrawn
## from (`cards.size() > 0 and taken < CARD_PICKS`); else `MAP`.
##
## ⚠⚠ **The `PICK` arm is ABOVE the `MAP` arm.** Below it, the cards are drawn and never shown and the
## round stays green — the roster grows, the run walks back to the map, and every
## check that only counts soldiers stays green.
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
