class_name Run
extends RefCounted
## Session state: which island the army stands on, which reward is waiting to be taken, and whether the
## run is still going. One island's fight lives in `battle.gd`; this file is everything between them.
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


## Where the run is. `BATTLE` means an island is open and `begin_island` will build its fight;
## `REWARD` means a pick is waiting; `WON` and `LOST` are both terminal until `restart`.
enum State { BATTLE, REWARD, WON, LOST }

## What an island pays on the way out. `COUNT` has nothing to choose, so it is applied on the win and
## the run walks straight to the next island — **only `BEAK` opens a `REWARD` state.**
enum Reward { NONE, COUNT, BEAK }

## The reward each island pays, indexed by the island just cleared. The last island pays nothing:
## clearing it ends the run.
##
## This lives here and not in `rules.gd` because it is the shape of the session, not a value that
## changes what happens inside a fight. A plain `const` Array: `const X := PackedInt32Array([...])` is
## a parse error in 4.7, and a const Array loses element typing, so the read below casts.
const _REWARDS := [Reward.COUNT, Reward.BEAK, Reward.NONE]


## The island the army is on. **It never leaves the range of real islands.** Winning the last one
## leaves this at the last index and moves `state()` to `WON` instead of stepping to a fourth island
## that does not exist — an out-of-range index here would read as a real island to every caller that
## indexes with it and would only fault later, inside whichever of them indexed first.
var island_index := 0

## The roster that survives islands. Never rebuilt outside `_reset`.
var army: Army = null

var _state := State.BATTLE
var _pending := Reward.NONE


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
	_state = State.BATTLE
	_pending = Reward.NONE


## Builds the current island's fight and hands it back. Returns `null` when no island is open — during
## a reward pick, or once the run is over — so a caller that ignores `state()` gets a null instead of a
## fight on an island the army has already left.
##
## The `Grid` is new every time. `load_rows` does clear reservations, but a grid built here can never
## be one another `Battle` still holds unit ids inside, and that costs 576 tiles once per island.
func begin_island() -> Battle:
	if _state != State.BATTLE:
		return null
	var grid := Grid.new()
	grid.load_rows(Islands.rows_of(island_index))
	var battle := Battle.new()
	battle.setup(grid, army, Islands.spawns_of(island_index), Islands.time_limit_of(island_index))
	return battle


## Closes the island. A loss is terminal at once; a win queues that island's reward, and the reward is
## what decides whether the run stops for a pick or walks on by itself.
##
## Ignored unless an island is actually open, so a loss cannot be un-lost, a finished run cannot be
## reopened, and a reward waiting to be picked cannot be skipped past.
##
## ⚠ What that does **not** catch is the same island being closed twice in a row: the first call has
## already opened the next one, so the second closes *that*, and the run walks past an island nobody
## fought. Distinguishing the two needs `begin_island` to arm this, and arming it would make a caller
## that closes an island it never began a **silent** no-op instead — worse, because nothing moves and
## nothing says why. So this is called exactly once per island, by whoever ran the fight.
func finish_island(won: bool) -> void:
	if _state != State.BATTLE:
		return
	if not won:
		_state = State.LOST
		return
	_pending = _reward_for_island(island_index)
	match _pending:
		Reward.COUNT:
			take_count_reward()
		Reward.BEAK:
			_state = State.REWARD
		_:
			_advance()


## `Reward.NONE`, `Reward.COUNT` or `Reward.BEAK` — what is waiting to be taken right now.
func pending_reward() -> int:
	return _pending


## Island 1's reward: more soldiers, at full HP, appended to the roster that is already carrying the
## survivors. `Army.add` is what fills their HP, so no starting value is written twice.
##
## Called by `finish_island` the moment it is queued, because there is nothing to choose — it is public
## only so that the applying of the reward and the naming of it are the same function in both cases.
func take_count_reward() -> void:
	if _pending != Reward.COUNT:
		return
	for _i in range(Rules.REWARD_MELEE):
		army.add(Rules.CELL_MELEE)
	for _i in range(Rules.REWARD_RANGED):
		army.add(Rules.CELL_RANGED)
	_pending = Reward.NONE
	_advance()


## Island 2's reward: the beak onto one **surviving** soldier, then on to the boss.
##
## A bad pick — an id off the end of the roster, or a soldier who died on the island that paid for it —
## leaves everything where it was: the reward stays pending and `state()` stays `REWARD`, so the caller
## can see that nothing happened and ask again. It does not bark, matching `grid.load_rows`: validating
## a click is the caller's job, and a bark here would have to be forgiven by every net that pokes at the
## roster. What it must never do is consume the reward, which is the one beak the whole slice has.
func apply_beak(soldier_id: int) -> void:
	if _pending != Reward.BEAK:
		return
	if soldier_id < 0 or soldier_id >= army.alive.size():
		return
	if army.alive[soldier_id] == 0:
		return
	army.has_beak[soldier_id] = 1
	_pending = Reward.NONE
	_advance()


## `State.BATTLE`, `State.REWARD`, `State.WON` or `State.LOST`.
func state() -> int:
	return _state


## Onto the next island, or the run is won. See `island_index` for why this stops rather than counting
## past the last island.
func _advance() -> void:
	if island_index + 1 < Islands.count():
		island_index += 1
		_state = State.BATTLE
	else:
		_state = State.WON


## Anything past the table pays nothing. The table is written for three islands and `islands.gd` owns
## how many there are, so if the two ever disagree the extra island ends the run quietly instead of
## indexing off the end of a const Array.
static func _reward_for_island(i: int) -> int:
	if i < 0 or i >= _REWARDS.size():
		return Reward.NONE
	return int(_REWARDS[i])
