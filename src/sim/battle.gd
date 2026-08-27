class_name Battle
extends RefCounted
## One island's fight. `step(dt)` drives all of it — boats, landings, targeting, movement, attacks,
## deaths and the clock — and nothing in this file is a Node, so a net builds one with `.new()` and
## drives it frame by frame with no tree at all.
##
## **The island is planned before it is fought, and the plan lives in `boats`.** `send` creates a boat
## sitting at its harbour with `t == 0.0`; `step` refuses to move anything until `commit` has been
## called. That is a RULE and not a calling habit: without `_committed` "planning" would exist only as
## the shell choosing not to call `step`, and every net, probe and future caller would break it in
## silence. `plan-then-watch` is where the reversal that produced this is recorded.
##
## **The phase order inside `step` is a contract, not an implementation detail.** Boats before
## landings means a boat that reaches the shore this sub-step unloads this sub-step instead of next.
## Attacks before deaths means two units that finish each other off both land their blow — the
## alternative silently gives whoever iterates first a free kill, and the free kill is invisible in
## final state. The clock last means an island cleared on the very sub-step the timer expires is a WIN.
## The first slice plan pins this under "The sim — shapes and entry points".
##
## **`step` has three guard lines and they are not interchangeable.** The null test and the `dt <= 0.0`
## test are per-CALL facts and stay outside the sub-step loop; the running test is answered per
## SUB-STEP, inside, as a `break`. Hoisted out, a WIN latched on sub-step 3 of 6 would let 4, 5 and 6
## keep attacking — and since `army` carries to the next island and death is permanent, a soldier
## could die AFTER the island was already won, at 6x and not at 1x.
##
## Distances are in TILES throughout, centre to centre, and positions carry tile centres on integers.
## The view multiplies by the tile size and nothing here knows what a pixel is.


enum Outcome { RUNNING, WON, LOST }

## Why the island was lost. The loss screen has to say which, because these are different mistakes and
## a screen that shows the wrong one teaches the wrong lesson.
##
## ⚠⚠ **`LANDING_LOST` and `WIPED` are two facts, not one, and the difference is on screen.** WIPED is
## *every soldier you own is dead*. LANDING_LOST is *everyone you SENT is dead and the ones you kept
## back can never be sent*, which is the same run-ending position with living soldiers still standing
## at the harbour. Showing 「전멸」 for the second one puts a sentence on screen that the screen itself
## disproves — the player is looking at those soldiers — and that is how a screen stops being trusted.
##
## ⚠ **Appended, never inserted.** These are ordinals a saved run or a pinned literal could hold.
##
## ⚠⚠ **`TIMEOUT` WAS REMOVED 2026-08-27 and that DID renumber the two below it.** The rule against
## inserting is about ordinals surviving in something outside this file, and December is a demo with
## no saves — nothing outside the running process holds one. **What did hold them is `net_shell`**,
## which pinned the enum's size and every member's screen wording, and that pin moved with this line.
## ⇒ **The day a save file exists, this becomes append-only for real.**
##
## ⚠⚠ **BOTH ARE TRUE AT ONCE when the last body dies with nobody in reserve, and `WIPED` WINS.**
## The precedence is stated here and applied in exactly one place (`_phase_clock`), because "every
## soldier is dead" is strictly more than "the landing force is gone" — it is the stronger claim and
## the more useful one to read. `net_battle` pins both arms of it.
enum Lose { NONE, WIPED, LANDING_LOST }

## Where a soldier is right now, on THIS island. It is per-island state and not part of the roster:
## `army` holds who exists and how hurt they are, and that is what carries to the next island.
##
## RESERVE -> TRANSIT -> ASHORE is one way. **A soldier that has landed never goes back to RESERVE**,
## which is what makes "one deployment per soldier per island" structural instead of a rule someone
## has to remember in `send`. The one edge that runs backwards is `recall`, which is refused after the
## commit, so it can only ever undo a boat that has not moved.
##
## There used to be a LOADED state between RESERVE and TRANSIT, for a soldier standing on a boat that
## had not sailed. **It is deleted rather than left unreachable**: with boats created by the drop
## there is no quayside to wait on, and an enum member no code path can enter is a slot a future
## writer fills by accident.
enum SoldierState { RESERVE, TRANSIT, ASHORE, DEAD }

## Which leg of the round trip a boat at sea is on. OUTBOUND carries cargo toward `target`;
## RETURNING is the empty hull sailing to its new harbour, `home`. There is no third state — a boat
## that has arrived but cannot unload is OUTBOUND with `t` already past arrival (4.5 of
## `boat-and-landing`).
enum Phase { OUTBOUND, RETURNING }

## What happened inside one `step()`. **Three kinds and no more** — the view turns each into a
## picture and decides on its own how long and in what colour, because a duration in this file would
## be a rule that changes what happens. `combat-juice`, section "How an event crosses from sim to
## view", is where the shape is pinned.
##
## The kind is an enum and not a string on purpose: `Battle.Event.ATTAK` is a parse error, `"ATTAK"`
## is a silent miss that draws nothing with every check about it green.
enum Event { ATTACK, DEATH, LAND }

## Enemy ids share `grid.reserved` with soldier ids, and a soldier's id is its army index starting at
## 0. Without a disjoint range enemy 0 and soldier 0 would each release the other's tile, and the
## symptom is a soldier walking through a bison with every check about reservation still green.
const ENEMY_UID_BASE := 1 << 20

## A flow field older than this is thrown away and rebuilt on the next request. The grid is 1536
## tiles (`boat-and-landing`'s 48 x 32), so one BFS is ~1536 operations and twenty units at 2 Hz is
## ~61k operations a second: the cache exists to stop the same field being rebuilt twenty times in
## one frame, not because the engine could not afford it.
const FIELD_TTL := 0.5

## Ceiling on tiles crossed in one `_walk` call. A unit at speed 6 with a 0.1 s frame moves 0.6
## tiles, so this is never reached in play — it exists so a `step_toward` that ever stops making
## progress ends the frame instead of hanging the round, because a hung net prints no verdict at all
## and that disarms mutation testing on the whole net.
const WALK_TILES_MAX := 64

## Position of a soldier that is not on the island. Deliberately off-grid: a view that draws reserve
## soldiers anyway puts them outside the viewport where it is obvious, rather than piling them all
## on tile (0,0) where it reads as one soldier.
const OFFMAP := Vector2(-1.0, -1.0)


var grid: Grid = null
var army: Army = null
## ⚠ **`elapsed` STAYED when the time limit went** (2026-08-27). It is not half of a deleted rule: it
## is how several nets prove the clock actually moved, which is the difference between a fight that ran
## and a fight that was silently never stepped.
var elapsed := 0.0

## One frame's facts, oldest first. Each is a Dictionary whose `kind` is an `Event`:
##  · ATTACK — `from` (attacker id) · `from_enemy` (bool) · `to` (primary target) · `dmg` ·
##    `area` (tiles) · `splash` (PackedInt32Array of the SECONDARY victims that actually took damage)
##  · DEATH — `id` · `is_enemy`
##  · LAND — `id` (soldier)
##
## **No position is carried.** `enemy_pos` and `soldier_pos` are never cleared and `army` never drops
## a row, so the view reads the place off the id and the same value is not written down twice.
##
## **Whoever drives this calls `begin_frame()` first**, every frame — see that function.
## **There is no cap, deliberately.** A cap would not fix a forgotten `begin_frame()`, it would make
## it quiet: thousands of ATTACKs truncated at 256 leaves memory fine and nobody feeling anything
## wrong. A net measures the per-frame ceiling instead.
var events: Array = []

# --- enemies. Parallel columns, index e is the same enemy in all of them --------------------------
var enemy_type := PackedInt32Array()
var enemy_hp := PackedFloat32Array()
var enemy_alive := PackedByteArray()
var enemy_pos: Array = []                 # Vector2, tile units
var enemy_target := PackedInt32Array()    # soldier id, or -1
## Seconds left before a DECLARED blow lands, 0.0 when nothing is declared. Public because the
## telegraph is a state the view draws for its whole length, not a one-frame fact: an event plus a
## view-side clock would be a second copy of this countdown, and two clocks drift.
var enemy_windup := PackedFloat32Array()
## The soldier a declared blow is aimed at, -1 when nothing is declared. The blow is re-checked
## against THIS id and not against `enemy_target`, so the ring the view drew and the damage that
## lands can never name two different soldiers.
var enemy_windup_at := PackedInt32Array()
var _enemy_cd := PackedFloat32Array()
var _enemy_goal: Array = []               # Vector2, the tile centre this enemy is walking into
var _enemy_stale := PackedByteArray()     # 1 = may still hold the tile behind it
## The tier an enemy was posted on, or **-1 for one that is free to go anywhere** (티켓 19).
##
## ⚠⚠ **ONLY A DEFENDER THAT STARTED ON HIGH GROUND HOLDS, AND THAT NARROWNESS IS THE WHOLE RULE.**
## Enemies move by "walk at the nearest soldier" and nothing else, so the ones posted on a plateau
## walked DOWN their own stair and died on the flat — **measured in play: most WON fights never sent
## anyone up the stairs at all, because the defenders came to them.** The ticket's answer is that the
## advantage is positional and the ATTACKER does the walking; a defender that abandons the height
## inverts it.
## ⚠ **Giving every enemy a holding behaviour would stop the fight coming to the player at all**, so a
## defender on the low ground is untouched and still advances.
var _enemy_home_level := PackedInt32Array()

## Per-enemy status clocks, flat over the STATUS TABLE: index `s * enemy_alive.size() + e` (see
## `_status_at`) holds the seconds left of status `s` on enemy `e`, and the magnitude its lit tier
## wrote. ⚠ **Generic across `Rules.Status`, never bleed-shaped** — a new status must not open this
## file for its storage. Public like `enemy_windup` and for the same reason: a status is a state the
## view may draw for its whole length, and a view-side copy of a countdown drifts.
var status_time := PackedFloat32Array()
var status_mag := PackedFloat32Array()

# --- soldiers. Indexed by ARMY id, so index i is the same soldier here and in `army` --------------
var soldier_state := PackedInt32Array()
var soldier_pos: Array = []               # Vector2, tile units
var soldier_target := PackedInt32Array()  # enemy index, or -1
var _soldier_cd := PackedFloat32Array()
var _soldier_goal: Array = []
var _soldier_stale := PackedByteArray()
## 1 once this body has spent its once-per-island shove (`Rules.shove_once_of`). **Per island**, which
## is free: `setup` rebuilds it and a `Battle` is new every island.
var _charged := PackedByteArray()

# --- boats -----------------------------------------------------------------------------------------
## **The plan AND the fleet, in one array.** There is no second structure: `send` appends here with
## `t == 0.0`, and free undo is one `remove_at` that cannot leave a duplicate behind.
##
## ⚠ **The drop CREATES the boat; the commit is what makes it move.** Every boat is still at
## `t == 0.0` when `commit()` lands, so they all depart on the same frame, and there is no
## departure-time field. **That is a CHOICE and it is not settled** — 미정 16 in `plan-then-watch`
## asks whether 「끌어서 탁 놓으면은 그때부터 출발하는 거지」 means ① the drop is that boat's own commit
## and the start button only starts the clock, or ② everything dropped leaves together at the start
## button. **This build assumes ②**, because 결정 1 (the hand does not move during combat) survives
## under both and ② needs no per-boat state. The user has not chosen between them, and a comment
## reading the user's sentence as already implemented is how the repo starts lying about a decision
## nobody made.
##
## Each entry is `{uid, phase, speed, path, cum, leg, dist, t, pos, soldiers, target, home}`.
## `phase` is `Phase.OUTBOUND` (one soldier aboard, sailing to `target`) or `Phase.RETURNING` (empty,
## sailing to harbour `home`). Waiting-to-unload is OUTBOUND with `t` past arrival — there is no
## separate waiting state.
##
## ⚠⚠ **`from` and `to` are DELETED and a boat is a POLYLINE now** (`speed-off-open-landing`, 2.3).
## Landing became a denylist, which means a boat sails a WATER ROUTE around a headland instead of a
## straight line, so two endpoints can no longer describe a crossing:
##
##  · `path` — `PackedVector2Array` in TILE units, harbour at index 0 and the landing last, straight
##    out of `grid.water_route`. Never rebuilt from geometry anywhere else in this file
##  · `cum` — `PackedFloat32Array`, prefix arc length along `path`, `cum[0] == 0.0`. `pos` is found by
##    walking it, which is what makes the boat follow the water rather than cut the corner
##  · `leg` — which segment the hull is on. **Stored by the SIM and read by the view**, so the drawn
##    remaining route and the sailed position come from one fact rather than two walks of the same
##    array. `t` is monotone, so advancing it is O(1) amortised and exact
##  · `dist` — the path's TOTAL length, floored at `Rules.EPS`. Still what `_arrived` tests
##
## **The append order IS the drop order**, and `_phase_landings` reads it: two boats aimed at one tile
## arrive on the same sub-step, and whoever unloads first stands on the target tile.
var boats: Array = []

## False until `commit()`. **`step()` refuses to do anything at all while it is false.**
var _committed := false

## Whole sub-steps only: `step` adds `dt` here and consumes `Rules.SIM_SUBSTEP_SEC` at a time, so the
## decomposition is additive over ANY sequence of `dt`s and a 6x run lands on the same state as a 1x
## run. Consuming a remainder pass instead would hand `_phase_targeting`, `_phase_landings` and
## `_phase_deaths` — which take no `dt` at all — a free extra retarget and death latch on every frame
## whose `dt` is not a multiple of the sub-step, which in the shipped shell is every frame.
var _substep_acc := 0.0

## How many whole sub-steps this island has run, counted **inside** the loop. It is an instrument and
## nothing in `src/` reads it: comparing final state across a 1x arm and a 6x arm catches *diverged*
## and never *vanished*, so the equivalence rows need the process itself to compare, and a pass count
## derived from `elapsed` would be blind to exactly the defect they exist to catch — a remainder pass
## adds a phase pass without adding a second of simulated time. `plan-then-watch`, the net row
## 「서브스텝 횟수 자체가 같다」.
var substeps := 0

## Monotonic boat id. `boats` entries carry `uid` instead of a fleet-slot index, because with boats
## created on demand there is no fleet slot to index and the view keys its per-boat effects by it.
## **Never reused inside one island** — a recalled boat's uid dies with it, so a stale reference
## cannot silently come to name a different boat.
var _next_boat_uid := 0

var _fields := {}                         # target tile -> PackedInt32Array
var _field_age := {}                      # target tile -> seconds since it was built
var _outcome := Outcome.RUNNING
var _lose := Lose.NONE


## Builds one island's fight. **`grid.load_rows` must already have run** — this writes tile
## reservations for every enemy, and `load_rows` clears the reservation table, so calling it
## afterwards would leave every enemy standing on a tile anyone may walk into.
##
## `spawns` is `islands.gd`'s `spawns_of` output: `[{"type_id": int, "tile": int}]`.
@warning_ignore("shadowed_variable")
func setup(grid: Grid, army: Army, spawns: Array) -> void:
	self.grid = grid
	self.army = army
	elapsed = 0.0
	events = []
	_outcome = Outcome.RUNNING
	_lose = Lose.NONE
	_fields = {}
	_field_age = {}
	boats = []
	# All three, every time. A `Battle` is reused across islands, and a leftover `_substep_acc` is a
	# fraction of the previous island's fight; a leftover `_committed` would start the next island
	# already fought. `setup` exists to make a reused Battle indistinguishable from a fresh one.
	_committed = false
	_substep_acc = 0.0
	_next_boat_uid = 0
	substeps = 0

	if grid == null or grid.w <= 0 or grid.h <= 0:
		# Not swallowed: a battle on an unloaded grid has no tiles, so every unit would stand still
		# for the whole island and the round would read as "nothing happened" with nothing to point
		# at. A net that builds this case on purpose forgives this exact substring.
		push_error("battle.setup: 격자가 비어 있다 — grid.load_rows 를 먼저 불러야 한다")
		return

	var enemy_count := spawns.size()
	enemy_type = PackedInt32Array()
	enemy_type.resize(enemy_count)
	enemy_hp = PackedFloat32Array()
	enemy_hp.resize(enemy_count)
	enemy_alive = PackedByteArray()
	enemy_alive.resize(enemy_count)
	enemy_target = PackedInt32Array()
	enemy_target.resize(enemy_count)
	enemy_windup = PackedFloat32Array()
	enemy_windup.resize(enemy_count)
	enemy_windup_at = PackedInt32Array()
	enemy_windup_at.resize(enemy_count)
	_enemy_cd = PackedFloat32Array()
	_enemy_cd.resize(enemy_count)
	_enemy_stale = PackedByteArray()
	_enemy_stale.resize(enemy_count)
	_enemy_home_level = PackedInt32Array()
	_enemy_home_level.resize(enemy_count)
	# resize on a fresh array zero-fills, so every status starts expired.
	status_time = PackedFloat32Array()
	status_time.resize(Rules.status_count() * enemy_count)
	status_mag = PackedFloat32Array()
	status_mag.resize(Rules.status_count() * enemy_count)
	enemy_pos = []
	_enemy_goal = []
	var claimed := grid.reserved
	for e in enemy_count:
		var spawn: Dictionary = spawns[e]
		var tile := int(spawn["tile"])
		var here := _point_of_tile(tile)
		enemy_type[e] = int(spawn["type_id"])
		enemy_hp[e] = Rules.hp_of(enemy_type[e])
		enemy_alive[e] = 1
		enemy_target[e] = -1
		enemy_windup[e] = 0.0
		enemy_windup_at[e] = -1
		_enemy_cd[e] = 0.0
		_enemy_stale[e] = 0
		# Posted high means posted; posted low means free. Read once, off the spawn tile, so a defender
		# that is somehow moved later still holds the tier it was placed to hold.
		var home := grid.level_of(tile)
		_enemy_home_level[e] = home if home > 0 else -1
		enemy_pos.append(here)
		_enemy_goal.append(here)
		if tile >= 0 and tile < claimed.size():
			claimed[tile] = ENEMY_UID_BASE + e
	grid.reserved = claimed

	var roster := army.type_id.size()
	soldier_state = PackedInt32Array()
	soldier_state.resize(roster)
	soldier_target = PackedInt32Array()
	soldier_target.resize(roster)
	_soldier_cd = PackedFloat32Array()
	_soldier_cd.resize(roster)
	_soldier_stale = PackedByteArray()
	_soldier_stale.resize(roster)
	# resize on a fresh array zero-fills, so nobody has charged yet. **Per island for free**: a
	# `Battle` is new every island, so 「몸당 섬당 한 번」 needs no reset anywhere else.
	_charged = PackedByteArray()
	_charged.resize(roster)
	soldier_pos = []
	_soldier_goal = []
	for i in roster:
		# A soldier who died on an earlier island is DEAD here, never RESERVE. Leaving them in
		# RESERVE would make a corpse draggable at the harbour and sendable to a beach — `send`
		# refuses anything that is not RESERVE, and this line is what gives that test something
		# to refuse.
		soldier_state[i] = SoldierState.RESERVE if army.alive[i] != 0 else SoldierState.DEAD
		soldier_target[i] = -1
		_soldier_cd[i] = 0.0
		_soldier_stale[i] = 0
		soldier_pos.append(OFFMAP)
		_soldier_goal.append(OFFMAP)


# --- the plan ------------------------------------------------------------------------------------

## Puts soldier `soldier_id` on a boat aimed at `tile`, and returns that boat's **uid**, or **-1** on
## refusal with **nothing at all changed**. One drag, one boat, one soldier — there is no fleet, no
## capacity and no queue to join, so the caller names both halves and this call has no choice of its
## own to make.
##
## ⚠ **The return is an int and uid 0 is the FIRST boat of every island**, so `if battle.send(...)`
## is a bug that refuses the common case. Every caller compares `>= 0`.
##
## Refused when: already committed · no grid or army · `soldier_id` out of range · that soldier is not
## RESERVE (dead, already sent, or already ashore) · **no harbour can see `tile`**.
##
## ⚠ **`grid.home_harbour_for` is the one predicate for both the refusal and the departure point**, and
## the shell's refusal mark is drawn off THIS call's own -1, so the screen can never deny a tile this
## call allows. It returns the harbour with the shortest WATER ROUTE among those that can reach the
## landing, so a boat departs from and returns to the same harbour by construction.
##
## ⚠ **A route of fewer than two points is a refusal too**, and it is a separate line rather than an
## assumption: `home_harbour_for` and `water_route` agree by construction today (both refuse on
## `can_land_at`), and the day one of them grows a case the other has not, a one-point path would
## divide by a zero-length crossing instead of barking.
func send(soldier_id: int, tile: int) -> int:
	if _committed:
		return -1
	if grid == null or army == null:
		return -1
	if soldier_id < 0 or soldier_id >= soldier_state.size():
		return -1
	if soldier_state[soldier_id] != SoldierState.RESERVE:
		return -1
	var hb := grid.home_harbour_for(tile)
	if hb < 0:
		return -1

	var path := grid.water_route(hb, tile)
	if path.size() < 2:
		return -1
	var cum := _arc_lengths(path)
	var uid := _next_boat_uid
	_next_boat_uid += 1
	soldier_state[soldier_id] = SoldierState.TRANSIT
	soldier_pos[soldier_id] = path[0]
	boats.append({
		"uid": uid,
		"phase": Phase.OUTBOUND,
		"speed": Rules.BOAT_SPEED,
		"path": path,
		"cum": cum,
		"leg": 0,
		"dist": maxf(cum[cum.size() - 1], Rules.EPS),
		"t": 0.0,
		# `pos` is set here and not only by the first `_phase_boats` call: before the commit `step`
		# never runs at all, so the whole planning screen would have nothing to draw the boat at.
		"pos": path[0],
		"soldiers": [soldier_id],
		"target": tile,
	})
	return uid


## The bodies slot `slot` may still put on a boat: living, of that slot's type, and still RESERVE.
## Empty for an unbound or out-of-range slot, which is what lets the shell test "unbound OR dry" with
## one call.
##
## ⚠⚠ **MOST HURT FIRST, and it used to be healthiest first.** The user, asked which body a slot spends
## when a key is pressed: ***"다친놈부터"***. **It is a rule and not a preference**, and what it does is
## bigger than an ordering: a slot spends damaged bodies first, so **「which of these is nearly gone」
## stops being something the player has to read** — which is exactly the picture that died with the
## reserve stack (`sea-summon` §6, Open 4: per-soldier HP has no home).
## ⚠ **It MAY close that hole by removing the need for it. Nobody has measured whether it does**, and
## this comment does not claim it — a rule that makes a readout unnecessary and a rule that makes it
## invisible look identical until somebody plays it.
##
## ⚠⚠ **`army.living_ids_of_type` IS NOT REORDERED, and that was checked rather than assumed.** It has
## three other readers: `hud_view` and `net_run` take only `.size()` (order-blind), but
## **`tools/probe/run_run.gd` used to read `ids[0]` to put the beak on the HEALTHIEST living body** —
## the beak reward is deleted (2026-08-25) but the ORDER is still this function's contract. Its own
## comment says so. Flipping that function would silently invert the probe's reward policy, which is a
## design instrument, not a caller. So the summon gets its own ordering here and `army` keeps its
## documented one.
##
## ⚠ **Ties break on the LOWER ID**, the same tie-break `army._hp_desc` already carries and for the
## same reason: `sort_custom` is not stable, so two bodies on equal HP would otherwise board in
## whatever order the sort happened to produce and two runs from identical state would diverge with
## every check about them green. The tie is exact `==` and not `is_equal_approx` — an approximate tie
## is not transitive, and a comparator that is not a strict weak ordering lets `sort_custom` return
## anything at all.
##
## **There is deliberately no second `slot_reserve_count`.** The HUD calls `.size()`; a count written
## twice diverges.
##
## ⚠⚠ **Filtered by `army.slot_id[i] == slot`, NOT by `army.type_id[i] == want`.** The two agree today
## (one slot per type), and they stop agreeing the day two slots bind to the same type — which is what
## `Army.slots` allows. Filtering on type would draw two slots from one pool
## with every count check downstream still green.
func slot_reserve_ids(slot: int) -> Array:
	var out: Array = []
	if army == null:
		return out
	if army.slot_type_of(slot) < 0:
		return out
	for raw in army.living_ids_of_slot(slot):
		var i := int(raw)
		if i < 0 or i >= soldier_state.size():
			continue
		if soldier_state[i] != SoldierState.RESERVE:
			continue
		out.append(i)
	# Re-sorted rather than filtered in a different order: `living_ids_of_slot` is the one place that
	# knows what "living, of this slot" means, and re-deriving that here would be the same rule twice.
	out.sort_custom(_hp_asc)
	return out


## Ascending HP, ties to the lower id. **A strict weak ordering** — see `army._hp_desc`, which is this
## function's mirror and carries the same warning for the same reason.
func _hp_asc(a: int, b: int) -> bool:
	if army.hp[a] == army.hp[b]:
		return a < b
	return army.hp[a] < army.hp[b]


## Puts one body of slot `slot`'s type on a boat **at the sea tile `tile`**, aimed at the landing the
## grid derives from it, and returns that boat's **uid** — or **-1 with nothing at all changed**.
## `sea-summon` is the design.
##
## ⚠⚠ **This is `send` inverted.** `send` names the DESTINATION and `grid.home_harbour_for` derives the
## origin; this names the ORIGIN and `grid.summon_landing_of` derives the destination. **A summon has
## no harbour**, which is why nothing below asks for one.
##
## Refused when: already committed · no grid or army · the slot is out of range · the slot is unbound ·
## the tile is not in the band · the slot is dry · the route is shorter than two points.
##
## ⚠ **The route test is a separate line rather than an assumption**, exactly as `send` carries it:
## `can_summon_at` and `summon_route` agree by construction today (the second refuses on the first),
## and the day one of them grows a case the other has not, a one-point path would divide by a
## zero-length crossing instead of barking.
##
## ⚠ **The return is an int and uid 0 is the FIRST boat of every island**, so `if battle.summon(...)`
## is a bug that refuses the common case. Every caller compares `>= 0`.
func summon(slot: int, tile: int) -> int:
	# ⚠ **Seam #1 of `sea-summon`'s OPEN question 1.** This build assumes the press happens BEFORE the
	# start button; a live-fire version deletes this one line and nothing else in this function. Do not
	# seal it by folding this call into a planning-only helper.
	if _committed:
		return -1
	if grid == null or army == null:
		return -1
	if slot < 0 or slot >= army.slot_count():
		return -1
	if army.slot_type_of(slot) < 0:
		return -1
	# ⚠ **REDUNDANT TODAY AND MEASURED SO**: `grid.summon_route` refuses on this same predicate, so
	# deleting this line reddens nothing — the route test below catches every case. It is kept for the
	# reason `send` keeps its own pair, written out rather than inferred: the two agree by construction
	# *today*, and the day one of them grows a case the other has not, the refusal has to come from the
	# predicate rather than from a side effect of the path being short.
	if not grid.can_summon_at(tile):
		return -1
	var ids := slot_reserve_ids(slot)
	if ids.is_empty():
		return -1
	# ⚠⚠ **The path and the target come from the summon field and from NOTHING else.** A `summon` that
	# called `home_harbour_for` to satisfy an existing net would put the harbour back into a gesture
	# that has none, and a grid with zero harbours would then refuse every press — which is exactly what
	# `net_summon`'s zero-harbour row exists to catch.
	var path := grid.summon_route(tile)
	if path.size() < 2:
		return -1
	var cum := _arc_lengths(path)
	var uid := _next_boat_uid
	_next_boat_uid += 1
	var sid := int(ids[0])
	soldier_state[sid] = SoldierState.TRANSIT
	soldier_pos[sid] = path[0]
	boats.append({
		"uid": uid,
		"phase": Phase.OUTBOUND,
		"speed": Rules.BOAT_SPEED,
		"path": path,
		"cum": cum,
		"leg": 0,
		"dist": maxf(cum[cum.size() - 1], Rules.EPS),
		"t": 0.0,
		"pos": path[0],
		"soldiers": [sid],
		"target": grid.summon_landing_of(tile),
	})
	return uid


## Prefix arc length along `path`, `cum[0] == 0.0` and `cum[last]` the total. **One function and not
## an expression written twice** — `send` builds it and `_phase_landings` rebuilds it for the reversed
## return leg, and two copies of this sum is exactly how a return leg comes to disagree with the
## outbound one it is supposed to be the mirror of.
func _arc_lengths(path: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(path.size())
	cum[0] = 0.0
	for k in range(1, path.size()):
		cum[k] = cum[k - 1] + path[k - 1].distance_to(path[k])
	return cum


## Undoes one `send`. The boat leaves `boats` and its soldier goes back to exactly what `setup` left —
## RESERVE at `OFFMAP` — so it can be sent again and no duplicate can be left behind. False when
## already committed, or when no boat carries that uid.
##
## ⚠ **This is not the inverse of `send` for a boat that has MOVED, and must never be called on one.**
## After the commit the `_committed` test refuses it, and there is no other window in which a boat has
## `t > 0` — which is what makes 「언제든지 어디서든지」 a rule rather than a habit.
func recall(uid: int) -> bool:
	if _committed:
		return false
	for i in boats.size():
		var boat: Dictionary = boats[i]
		if int(boat["uid"]) != uid:
			continue
		for raw in boat["soldiers"]:
			var sid := int(raw)
			soldier_state[sid] = SoldierState.RESERVE
			soldier_pos[sid] = OFFMAP
		boats.remove_at(i)
		return true
	return false


## Closes the plan and lets the clock run. **False and nothing changes** when already committed, or
## when `boats` is empty — a start press that would land nobody is a refusal with a shake, not a fight
## nobody can win.
##
## It launches nothing: every boat was built by `send` and is already sitting at `t == 0.0`, so the
## commit adds no motion of its own. That is the whole point — the plan and the fleet are one array.
func commit() -> bool:
	if _committed:
		return false
	if boats.is_empty():
		return false
	_committed = true
	return true


func committed() -> bool:
	return _committed


## Throws away last frame's `events`. **Every driver of this class calls it once a frame, before
## `step`** — the shell, the headless probe and every net that turns frames.
##
## It is not done inside `step` and that is not a style choice. `step` returns early when the island
## is over or `dt` is 0, so clearing at its head means the last frame's events survive from the
## moment a panel opens and the view replays them forever; clearing at its tail means nobody ever
## sees them. Both were shipped in the dead game and cost two effects outright.
func begin_frame() -> void:
	events.clear()


## One frame's worth of simulated time, run as whole `Rules.SIM_SUBSTEP_SEC` sub-steps with the
## leftover carried in `_substep_acc`. The phase order below is the contract described at the top of
## this file, and it is the SUB-STEP that is one pass of it, not the call.
##
## ⇒ **`step(dt)` and `step(dt/k)` k times land on identical state**, which is what makes the speed
## ladder a viewing rate instead of a different game. Without it a cooldown reset to the whole period
## on fire loses `dt/period` of every cycle, and the loss is asymmetric: the bison's 2.0 s period
## sheds half the fraction the 1.0 s cells do, so speeding up is a quiet buff to the player.
func step(dt: float) -> void:
	# Per-CALL facts, answered once. See the header for why the running test is NOT one of them.
	if grid == null or army == null:
		return
	if not _committed:
		return
	if dt <= 0.0:
		return
	_substep_acc += dt
	while _substep_acc >= Rules.SIM_SUBSTEP_SEC:
		if _outcome != Outcome.RUNNING:
			break
		_substep_acc -= Rules.SIM_SUBSTEP_SEC
		substeps += 1
		_phase_boats(Rules.SIM_SUBSTEP_SEC)
		_phase_landings()
		_phase_targeting()
		_phase_movement(Rules.SIM_SUBSTEP_SEC)
		_phase_attacks(Rules.SIM_SUBSTEP_SEC)
		# After attacks, before deaths: an enemy bled to 0 this sub-step passes the SAME sub-step's
		# death latch instead of standing a frame at no HP.
		_phase_status(Rules.SIM_SUBSTEP_SEC)
		_phase_deaths()
		_phase_clock(Rules.SIM_SUBSTEP_SEC)


func outcome() -> int:
	return _outcome


## NONE while the island is running or won. The loss screen reads this to say WHY.
func lose_reason() -> int:
	return _lose


func enemies_left() -> int:
	var n := 0
	for e in enemy_alive.size():
		if enemy_alive[e] != 0:
			n += 1
	return n


## Docks are gone; every harbour lookup goes through `grid` (`boat-and-landing`, 4.4's call table).
func harbour_count() -> int:
	return 0 if grid == null else grid.harbour_tiles.size()


func harbour_tile(h: int) -> int:
	if grid == null or h < 0 or h >= grid.harbour_tiles.size():
		return -1
	return int(grid.harbour_tiles[h])


## Soldiers standing on the island right now. The view draws these and nothing else on the ground.
func ashore_ids() -> Array:
	var out := []
	for i in soldier_state.size():
		if soldier_state[i] == SoldierState.ASHORE:
			out.append(i)
	return out


## Soldiers aboard a boat at sea right now — `boat-and-landing` stage 5, P4: these are `is_hittable`
## and share their boat's `soldier_pos`, so a crow can already hit one and the tracer already flies
## to it. This is the read the view needs to finally draw them there instead of leaving the hit with
## nothing on screen to land on.
func transit_ids() -> Array:
	var out := []
	for i in soldier_state.size():
		if soldier_state[i] == SoldierState.TRANSIT:
			out.append(i)
	return out


## True while this soldier can be shot: ashore, or aboard a boat at sea. **A soldier in transit is
## hit but cannot hit back**, and is excluded from enemy MOVEMENT targeting — see `_phase_movement`.
func is_hittable(i: int) -> bool:
	if i < 0 or i >= soldier_state.size():
		return false
	if army.alive[i] == 0:
		return false
	var s := soldier_state[i]
	return s == SoldierState.ASHORE or s == SoldierState.TRANSIT


# --- phases --------------------------------------------------------------------------------------

## Boat crossings, both legs. Soldiers aboard an OUTBOUND boat are dragged along with it so an enemy
## on the coast can target them where the boat actually is; a RETURNING boat carries nobody, so the
## loop below is a no-op for it and only its own `pos` moves — which is what P6 (the return leg drawn
## empty) reads off `pos` and `soldiers.is_empty()`.
func _phase_boats(dt: float) -> void:
	for raw in boats:
		var boat: Dictionary = raw
		boat["t"] = float(boat["t"]) + dt
		var path: PackedVector2Array = boat["path"]
		var cum: PackedFloat32Array = boat["cum"]
		var travelled := clampf(float(boat["t"]) * float(boat["speed"]), 0.0, float(boat["dist"]))
		# ⚠ **`leg` walks FORWARD from where it already is and is never re-searched from 0.** `t` only
		# ever grows within a leg (the return leg resets both together), so this is O(1) amortised over
		# the whole crossing and lands on exactly the same segment a full re-scan would. It stops at
		# `size() - 2` so the last segment is always the one a boat at `dist` is standing on, rather
		# than an index one past the end.
		var leg := int(boat["leg"])
		while leg < path.size() - 2 and cum[leg + 1] < travelled:
			leg += 1
		boat["leg"] = leg
		var span := cum[leg + 1] - cum[leg]
		# A zero-length span cannot happen off `water_route` (consecutive tiles are always a hop
		# apart), but dividing by it would give INF rather than a bark, and a boat at INF is a boat
		# nobody can see. 0.0 puts it at the start of the segment, which is where it is.
		var f := 0.0 if span <= Rules.EPS else clampf((travelled - cum[leg]) / span, 0.0, 1.0)
		var here: Vector2 = path[leg].lerp(path[leg + 1], f)
		boat["pos"] = here
		for sid in boat["soldiers"]:
			soldier_pos[int(sid)] = here


## Boats that have finished a leg act on it. **Two passes, and the split is load-bearing.**
##
## ⚠ **Pass 1 walks ASCENDING because `boats` append order IS drop order**, and `_try_unload` writes
## `grid.reserved` as it lands, so whoever unloads first stands on the target tile and the next stands
## on the BFS-next. Several boats aimed at one beach from one harbour have identical `dist` and
## identical speed, so they arrive on exactly the same sub-step — the sim carries no randomness — and
## this walk is therefore the ONLY thing in the sim that reads the drop order at all. A single
## descending pass (which is what shipped before the planning round) gave the front row to the boat
## dropped LAST, the exact opposite of 「끌어서 탁 놓으면」. **Nothing is removed in pass 1**, so
## ascending is safe here and only here.
##
## Pass 2 walks DESCENDING because `remove_at` is in it. A boat that turned RETURNING in pass 1 cannot
## be removed by pass 2 on the same sub-step: it is set to `t == 0.0` and its new leg spans at least
## one tile (a harbour is water, a landing is land, so they are never the same tile).
##
## **OUTBOUND** tries to unload — if there are fewer free tiles than soldiers aboard the whole boat
## waits, because landing part of a load would silently reorder the deployment the player chose — and
## only on success does it turn RETURNING and **sail its own outbound path BACKWARDS**.
##
## ⚠⚠ **The return leg REVERSES `path` in place and never recomputes it** (`speed-off-open-landing`,
## 2.3). `home` was decided by `send` off the same `home_harbour_for(target)` call the refusal test
## used, and `path` came out of that same harbour, so asking `water_route` again here would be one
## fact computed in two places — and the two would be free to disagree the day the route's tie-break
## moves. `dist` and `home` are therefore NOT recomputed either: a reversed polyline has exactly the
## length of the polyline. `cum` IS rebuilt, because a prefix sum is not symmetric under reversal
## unless every segment is; `leg` and `t` go back to 0 together.
##
## **RETURNING** leaves `boats` on arrival and the boat ceases to exist: 「배는 왕복」 ends there,
## with nothing to reload and nothing to re-launch.
func _phase_landings() -> void:
	for i in boats.size():
		var boat: Dictionary = boats[i]
		if int(boat["phase"]) != Phase.OUTBOUND or not _arrived(boat):
			continue
		if not _try_unload(boat):
			continue
		var back: PackedVector2Array = boat["path"]
		back.reverse()
		boat["phase"] = Phase.RETURNING
		boat["soldiers"] = []
		boat["path"] = back
		boat["cum"] = _arc_lengths(back)
		boat["leg"] = 0
		boat["t"] = 0.0
		boats[i] = boat

	var j := boats.size() - 1
	while j >= 0:
		var boat: Dictionary = boats[j]
		if int(boat["phase"]) == Phase.RETURNING and _arrived(boat):
			boats.remove_at(j)
		j -= 1


## This boat has covered its leg. `dist` is floored at `Rules.EPS` in both writers, so a zero-length
## leg reads as arrived on the sub-step it is created rather than never.
func _arrived(boat: Dictionary) -> bool:
	return float(boat["t"]) * float(boat["speed"]) + Rules.EPS >= float(boat["dist"])


func _try_unload(boat: Dictionary) -> bool:
	var carried: Array = boat["soldiers"]
	if carried.is_empty():
		return true
	var spots := _free_tiles_from(int(boat["target"]), carried.size())
	if spots.size() < carried.size():
		return false
	var claimed := grid.reserved
	for k in carried.size():
		var sid := int(carried[k])
		var tile := int(spots[k])
		var here := _point_of_tile(tile)
		soldier_state[sid] = SoldierState.ASHORE
		soldier_pos[sid] = here
		_soldier_goal[sid] = here
		_soldier_stale[sid] = 0
		claimed[tile] = sid
		# The id and nothing else. There are two tiles in scope here — the coast tile the boat aimed
		# at and the spot this soldier actually stands on — and they are different tiles, so carrying
		# "the" tile would be carrying an ambiguity. `soldier_pos[id]` was written one line up and is
		# the answer.
		events.append({"kind": Event.LAND, "id": sid})
	grid.reserved = claimed
	return true


## Who everyone is shooting at. A target is kept while it is alive AND still in reach; the moment it
## dies or leaves reach, the nearest is chosen again.
##
## **Nearest is Euclidean and ties go to the smaller id.** A tie broken by iteration order would make
## two runs from identical state diverge with every check about them green.
func _phase_targeting() -> void:
	for i in soldier_state.size():
		if soldier_state[i] != SoldierState.ASHORE:
			soldier_target[i] = -1
			continue
		var held := int(soldier_target[i])
		if held >= 0 and enemy_alive[held] != 0 \
				and _within(soldier_pos[i], enemy_pos[held], _soldier_reach(i)):
			continue
		# ⚠ The pack decides WHERE it looks from; the body decides HOW HIGH it looks from. Reading the
		# height off the seek point instead had wolves on the ground aiming from a plateau.
		soldier_target[i] = _nearest_enemy(_seek_point_of(i), grid.height_at(soldier_pos[i]))

	for e in enemy_alive.size():
		if enemy_alive[e] == 0:
			enemy_target[e] = -1
			continue
		var held := int(enemy_target[e])
		if held >= 0 and is_hittable(held) \
				and _within(enemy_pos[e], soldier_pos[held], _enemy_reach(e)):
			continue
		# Soldiers on a boat ARE in this scan: without it no crow in the slice ever fires on a
		# landing, and the coastal crows exist for exactly that.
		enemy_target[e] = _nearest_soldier(enemy_pos[e], Rules.detect_of(enemy_type[e]), false)


## Everyone walks toward their target and **stops the instant it is in reach**. Without that one
## rule a range-4 soldier walks all the way into melee and the ranged type stops existing; the plan
## measured it moving island 3's damage taken by 30%.
func _phase_movement(dt: float) -> void:
	_age_fields(dt)

	for i in soldier_state.size():
		if soldier_state[i] != SoldierState.ASHORE:
			continue
		var goal: Vector2 = _soldier_goal[i]
		var speed := army.speed_of(i)
		var tgt := int(soldier_target[i])
		if tgt < 0 or _within(soldier_pos[i], enemy_pos[tgt], _soldier_reach(i)):
			# Stopping mid-tile would leave the unit holding both tiles for the rest of the island,
			# which halves a doorway's throughput with nothing on screen to explain it. So a unit
			# caught between tiles finishes the one it already reserved, and stops next frame.
			if soldier_pos[i].distance_to(goal) > Rules.EPS:
				soldier_pos[i] = _glide(soldier_pos[i], goal, speed * dt)
			elif _soldier_stale[i] != 0:
				_settle(i, goal)
				_soldier_stale[i] = 0
			continue
		var seek: Vector2 = enemy_pos[tgt]
		soldier_pos[i] = _walk(i, soldier_pos[i], _soldier_goal, i, speed * dt,
				_field_for(_tile_of(seek)), seek, _soldier_reach(i))
		_soldier_stale[i] = 1

	for e in enemy_alive.size():
		if enemy_alive[e] == 0:
			continue
		var uid := ENEMY_UID_BASE + e
		var goal: Vector2 = _enemy_goal[e]
		# The ONE read site a live SLOW-kind status has: the enemy's speed, glide and walk alike.
		# The soldier branch above deliberately has no twin — allied bodies never carry a status.
		var speed := Rules.speed_of(int(enemy_type[e])) * _slow_mul_of(e)
		var atk := int(enemy_target[e])
		var seek_id := -1
		if atk < 0 or not _within(enemy_pos[e], soldier_pos[atk], _enemy_reach(e)):
			# The movement scan excludes soldiers still aboard. Chasing one means asking
			# `flow_field` for a path to a water tile, which comes back unreachable everywhere, and
			# then EVERY enemy on the island stands still for the rest of the fight with nothing
			# logged. Shooting one is still allowed — that is what `enemy_target` is for.
			seek_id = _nearest_soldier(enemy_pos[e], Rules.detect_of(enemy_type[e]), true)
		if seek_id < 0:
			# In reach, or nothing detected: stand. No patrol, no return-to-post.
			if enemy_pos[e].distance_to(goal) > Rules.EPS:
				enemy_pos[e] = _glide(enemy_pos[e], goal, speed * dt)
			elif _enemy_stale[e] != 0:
				_settle(uid, goal)
				_enemy_stale[e] = 0
			continue
		var seek: Vector2 = soldier_pos[seek_id]
		enemy_pos[e] = _walk(uid, enemy_pos[e], _enemy_goal, e, speed * dt,
				_field_for(_tile_of(seek)), seek, _enemy_reach(e), int(_enemy_home_level[e]))
		_enemy_stale[e] = 1


## Damage lands here and **nothing dies here**. A unit reduced to 0 HP by an earlier attacker in
## this same phase still swings, because `alive` is what gates an attack and `alive` only moves in
## the deaths phase. Otherwise whoever the loop reached first would get a free kill, and a free kill
## is invisible in final state.
func _phase_attacks(dt: float) -> void:
	for i in soldier_state.size():
		if soldier_state[i] != SoldierState.ASHORE:
			continue
		_soldier_cd[i] = maxf(0.0, _soldier_cd[i] - dt)
		var tgt := int(soldier_target[i])
		if tgt < 0 or enemy_alive[tgt] == 0:
			continue
		if not _within(soldier_pos[i], enemy_pos[tgt], _soldier_reach(i)):
			continue
		if _soldier_cd[i] > Rules.EPS:
			continue
		# The cooldown is NOT reset when the target changes. Reset on retarget, and a soldier
		# standing in a crowd fires every frame by killing one enemy and picking the next.
		#
		# ⚠⚠ **`army.period_of(i)` / `army.damage_of(i)`, not `Rules.period_of` / `Rules.damage_of`
		# keyed on the TYPE.** This is what lets a fitted 팔 or 손 change what THIS soldier does —
		# two soldiers of one type can now differ. `Rules.area_of(st)` stays: 면적 is not one of the
		# five columns a part moves, and moving it too would invent a sixth stat with no table
		# behind it.
		var st := int(army.type_id[i])
		_soldier_cd[i] = army.period_of(i)
		_hit_enemies(i, tgt, army.damage_of(i), Rules.area_of(st))

	for e in enemy_alive.size():
		if enemy_alive[e] == 0:
			continue
		_enemy_cd[e] = maxf(0.0, _enemy_cd[e] - dt)
		var et := int(enemy_type[e])
		var wind := _windup_of(et)
		# While a blow is declared the aim is the LOCKED id, never whatever `enemy_target` holds now.
		# Re-targeting only happens when the held target dies or leaves reach, so the two agree
		# everywhere except on the frame a replacement is picked — and there, following `enemy_target`
		# would land the blow on a soldier the drawn ring was never pointing at.
		var aim := int(enemy_windup_at[e]) if enemy_windup[e] > 0.0 else int(enemy_target[e])
		if aim < 0 or not is_hittable(aim) \
				or not _within(enemy_pos[e], soldier_pos[aim], _enemy_reach(e)):
			# An interrupted wind-up is thrown away whole and never resumed. Keeping the remainder
			# would let the next blow be announced for a fraction of its time, and a telegraph that
			# is sometimes short is worse than none at all — announcing EVERY blow is the whole
			# reason this exists.
			enemy_windup[e] = 0.0
			enemy_windup_at[e] = -1
			continue
		if enemy_windup[e] > 0.0:
			enemy_windup[e] = maxf(0.0, enemy_windup[e] - dt)
			if enemy_windup[e] > Rules.EPS:
				continue
			enemy_windup[e] = 0.0
			enemy_windup_at[e] = -1
			_enemy_cd[e] = Rules.period_of(et)
			_hit_soldiers(e, aim, Rules.damage_of(et), Rules.area_of(et))
			continue
		if _enemy_cd[e] > Rules.EPS:
			continue
		if wind > 0.0:
			# Declared, not landed — and **this is the frame the old rule fired on.** The cooldown
			# drains while there is no target and then sits at 0, so the frame a soldier walks into
			# reach used to be an instant blow with nothing before it. Declaring here is what makes
			# the FIRST blow announced like every one after it.
			#
			# The cooldown is deliberately NOT started here: the period measures blow to blow, so
			# starting it at the declaration would make the wind-up free on every blow but the first.
			enemy_windup[e] = wind
			enemy_windup_at[e] = aim
			continue
		_enemy_cd[e] = Rules.period_of(et)
		_hit_soldiers(e, aim, Rules.damage_of(et), Rules.area_of(et))


## Seconds this type spends announcing a blow before it lands, 0.0 for the types that just swing.
## Only the lion has one — see `LION_WINDUP_SEC` in `rules.gd` for why the ranged cell's area does
## not get one even though it has an area.
func _windup_of(type_id: int) -> float:
	return Rules.LION_WINDUP_SEC if type_id == Rules.LION else 0.0


## `area > 0` also damages every OTHER ENEMY within `area` of the primary target. Only enemies —
## there is no friendly fire in this slice, so a soldier's splash can never touch a soldier.
##
## `from_id` is the attacker and it is here for the event alone: the faction is not passed because
## this function already knows it — only soldiers hit enemies. Handing the event a faction flag as
## well would be the same fact written in two places.
func _hit_enemies(from_id: int, primary: int, damage: float, area: float) -> void:
	enemy_hp[primary] -= damage
	var splash := PackedInt32Array()
	if area > 0.0:
		var centre: Vector2 = enemy_pos[primary]
		for e in enemy_alive.size():
			if e == primary or enemy_alive[e] == 0:
				continue
			if _within(enemy_pos[e], centre, area):
				enemy_hp[e] -= damage
				splash.append(e)
	# Every lit status tier rides every allied blow, onto everyone the blow actually hit. Only HERE —
	# `_hit_soldiers` has no twin, so an enemy blow can never leave a status on a soldier.
	_apply_statuses(from_id, primary, splash)
	# 다람쥐 pulls what it bites in, 소 drives it away — one signed number in `Rules.SPECIES_SHOVE`.
	# Same place and same victims as the statuses above, for the same reason: what a blow does to what
	# it hit belongs on one line, not two.
	_shove_victims(from_id, primary, splash)
	events.append({
		"kind": Event.ATTACK,
		"from": from_id,
		"from_enemy": false,
		"to": primary,
		"dmg": damage,
		"area": area,
		# Who ACTUALLY took the splash, not who was in the radius: an enemy already dead this frame
		# is skipped above, and a view that flashed the radius instead would light up corpses.
		"splash": splash,
	})


func _hit_soldiers(from_id: int, primary: int, damage: float, area: float) -> void:
	army.hp[primary] -= damage
	var splash := PackedInt32Array()
	if area > 0.0:
		var centre: Vector2 = soldier_pos[primary]
		for i in soldier_state.size():
			if i == primary or not is_hittable(i):
				continue
			if _within(soldier_pos[i], centre, area):
				army.hp[i] -= damage
				splash.append(i)
	events.append({
		"kind": Event.ATTACK,
		"from": from_id,
		"from_enemy": true,
		"to": primary,
		"dmg": damage,
		"area": area,
		"splash": splash,
	})


## Moves everyone this blow hit, if the attacker's species is in `Rules.SPECIES_SHOVE`. Nothing at
## all for a species with no row — the table lookup answers 0.0 and this returns before touching
## anything.
func _shove_victims(from_id: int, primary: int, splash: PackedInt32Array) -> void:
	if from_id < 0 or from_id >= army.type_id.size():
		return
	var st := int(army.type_id[from_id])
	var tiles := Rules.shove_tiles_of(st)
	if absf(tiles) <= Rules.EPS:
		return
	var once := Rules.shove_once_of(st)
	if once and _charged[from_id] != 0:
		return
	# ⚠⚠ **THE FLAG IS SET BY THE MOVE AND NOT BY THE ATTEMPT.** Setting it first spent 소's whole
	# island on a target with its back to a wall — `_shove` refuses to put a body on a blocked tile,
	# so the charge was consumed by a blow that moved nobody and every later blow was refused for a
	# charge that never happened. **A once-per-island rule has to be spent by the thing it names.**
	var moved := _shove(from_id, primary, tiles)
	for v in splash:
		moved = _shove(from_id, int(v), tiles) or moved
	if once and moved:
		_charged[from_id] = 1


## Moves enemy `e` up to `tiles` along the line to soldier `from_id` — **positive is TOWARD the
## attacker** — and stops at the last tile on the way that a body may actually stand on.
##
## ⚠⚠ **FOUR THINGS HAVE TO MOVE TOGETHER AND THREE OF THEM ARE INVISIBLE.** Writing `enemy_pos`
## alone reads as a shove for exactly one sub-step and then undoes itself:
##  · `_phase_movement`'s standing branch glides the body back toward `_enemy_goal`
##  · `_walk` re-picks that same stale goal on the branch that walks
##  · `grid.reserved` still holds the tile the body LEFT, so two bodies end up holding one tile and a
##    doorway is half as wide with nothing on screen to explain it
## ⇒ `enemy_pos`, `_enemy_goal` and `_settle` all move here, and `_enemy_stale` is cleared because
## this call IS the settle.
##
## ⚠ **It walks tile by tile rather than jumping to the endpoint.** A jump can land past a wall, past
## a body, or on top of the attacker; stopping at the last legal tile is what makes 「지나쳐 넘어가지
## 않는다」 a property of the search instead of a rule somebody has to remember.
## **Returns whether anything actually moved**, which is what `_shove_victims` spends 소's
## once-per-island charge on.
func _shove(from_id: int, e: int, tiles: float) -> bool:
	if e < 0 or e >= enemy_alive.size() or enemy_alive[e] == 0:
		return false
	var here: Vector2 = enemy_pos[e]
	var away: Vector2 = here - soldier_pos[from_id]
	if away.length() <= Rules.EPS:
		return false
	var dir := -away.normalized() if tiles > 0.0 else away.normalized()
	var uid := ENEMY_UID_BASE + e
	var best := here
	var want := absf(tiles)
	var steps := int(ceil(want))
	# ⚠⚠ **BODIES NEVER CHANGE TIER BY BEING PUSHED** (티켓 19, the user: 「높은 데서 밀리면 안 떨어져.
	# 안 떨어지는 걸로」). Before this, 소's charge shoved enemies UP onto a plateau and 다람쥐's pull
	# dragged them DOWN off one — the decision inverted, by the same omission that put landed bodies on
	# top of the wall: placement that never consulted the tier.
	# ⚠ **The body's OWN level, not `can_step`.** A shove is not a step: it may not use a stair either,
	# because a body flung a tier up a staircase is the falling rule wearing a different hat.
	var stand_level := grid.level_of(_tile_of(here))
	for k in range(1, steps + 1):
		var reach := minf(float(k), want)
		var tile := _tile_of(here + dir * reach)
		if tile < 0:
			break
		var candidate := _point_of_tile(tile)
		if candidate.distance_to(best) <= Rules.EPS:
			continue
		if grid.passable[tile] == 0:
			break
		if grid.level_of(tile) != stand_level:
			break
		var holder := int(grid.reserved[tile])
		if holder >= 0 and holder != uid:
			break
		best = candidate
	if best.distance_to(here) <= Rules.EPS:
		return false
	enemy_pos[e] = best
	_enemy_goal[e] = best
	_settle(uid, best)
	_enemy_stale[e] = 0
	return true


func _status_at(s: int, e: int) -> int:
	return s * enemy_alive.size() + e


## Seconds left of status `s` on enemy `e`, 0.0 for anything out of range or expired.
##
## ⚠ **The one public window onto `status_time`'s flat indexing.** `field_view` reads a bleed clock to
## tint a body, and a view that re-derived `s * count + e` would be a second copy of the layout —
## which is exactly the shape that silently reads the wrong enemy the day a status is appended.
func status_left(s: int, e: int) -> float:
	if e < 0 or e >= enemy_alive.size() or s < 0 or s >= Rules.status_count():
		return 0.0
	return status_time[_status_at(s, e)]


## The magnitude of status `s` standing on enemy `e`, 0.0 for anything out of range. **The same one
## window `status_left` is**, for the same reason: the flat layout is written down once.
func status_mag_of(s: int, e: int) -> float:
	if e < 0 or e >= enemy_alive.size() or s < 0 or s >= Rules.status_count():
		return 0.0
	return status_mag[_status_at(s, e)]


## Writes what ONE blow leaves on `primary` and on the splash victims.
##
## ⚠⚠ **An overwrite, never an accumulate**: re-hitting resets the clock to the winning tier's own
## values — the magnitude must not add or fold onto itself, or six fast blows rebuild the -0.5 s mine
## here.
##
## ⚠⚠ **EVERY SOURCE FOR THIS BLOW IS RESOLVED BEFORE ANYTHING IS WRITTEN, AND THE STRONGEST WINS.**
## A blow has two sources of a status now — the equipment tag tiers and the attacker's own species —
## and they can name the SAME status. Writing them one after the other let whichever came last stand,
## which measured as a 까마귀 wearing a full bleed set biting for 0.5 a second where a 늑대 wearing the
## same set bit for 1.5: **the crow was PENALISED by its own passive**, and by equipment fitted
## anywhere on the board, since `tag_count` sums the whole horde.
func _apply_statuses(from_id: int, primary: int, splash: PackedInt32Array) -> void:
	var best := {}
	for r in Rules.tag_status_row_count():
		var tier := Rules.tag_status_tier_at(r, army.loadout.tag_count(Rules.tag_status_tag_of(r)))
		if tier.is_empty():
			continue
		var s := Rules.tag_status_status_of(r)
		best[s] = Rules.stronger_status_tier(s, best.get(s, {}), tier)
	# ⚠ **The attacker's SPECIES is a second SOURCE and not a second mechanism** (티켓 15): 까마귀
	# bites bleed into whatever it hits with no equipment at all. Same `_put_status`, same overwrite
	# rule, same generic `_phase_status` walk — a species row and a tag tier are indistinguishable by
	# the time they reach the clock.
	if from_id >= 0 and from_id < army.type_id.size():
		var own := Rules.species_status_of(int(army.type_id[from_id]))
		if not own.is_empty():
			var os := int(own["status"])
			best[os] = Rules.stronger_status_tier(os, best.get(os, {}), own)
	for raw in best:
		var st := int(raw)
		var win: Dictionary = best[st]
		_put_status(st, primary, win)
		for v in splash:
			_put_status(st, int(v), win)


func _put_status(s: int, e: int, tier: Dictionary) -> void:
	var at := _status_at(s, e)
	status_time[at] = float(tier["sec"])
	status_mag[at] = float(tier["mag"])


## Ages every status and lets the damage-over-time kind bite. It walks the KIND table and never knows
## a status by name — that is what keeps the next damage-over-time status (poison is the named one) a
## table row in `rules.gd` with this file shut.
func _phase_status(dt: float) -> void:
	for s in Rules.status_count():
		var dot := Rules.status_kind_of(s) == Rules.StatusKind.DOT
		for e in enemy_alive.size():
			if enemy_alive[e] == 0:
				continue
			var at := _status_at(s, e)
			var left := status_time[at]
			if left <= 0.0:
				continue
			if dot:
				# `minf` so the last partial sub-step bites only what is left — the total a tier deals
				# is exactly magnitude x duration, not a sub-step more.
				enemy_hp[e] -= status_mag[at] * minf(left, dt)
			status_time[at] = maxf(0.0, left - dt)


## The product of every live SLOW-kind status on this enemy — 1.0 with none. The product is across
## DIFFERENT status rows only: one status re-applied was overwritten, never folded onto itself.
func _slow_mul_of(e: int) -> float:
	var mul := 1.0
	for s in Rules.status_count():
		if Rules.status_kind_of(s) != Rules.StatusKind.SLOW:
			continue
		if status_time[_status_at(s, e)] > 0.0:
			mul *= status_mag[_status_at(s, e)]
	return mul


## Everything at or below 0 HP dies, and the row stays. `army.kill` keeps the roster's history so a
## soldier's id names the same soldier for the whole run — the plan's "permanent death".
func _phase_deaths() -> void:
	for e in enemy_alive.size():
		if enemy_alive[e] != 0 and enemy_hp[e] <= 0.0:
			enemy_alive[e] = 0
			enemy_hp[e] = 0.0
			enemy_target[e] = -1
			# A dead attacker's declared blow dies with it, or the view keeps drawing a telegraph
			# over a corpse for the rest of the island.
			enemy_windup[e] = 0.0
			enemy_windup_at[e] = -1
			grid.release_all(ENEMY_UID_BASE + e)
			events.append({"kind": Event.DEATH, "id": e, "is_enemy": true})
	for i in soldier_state.size():
		if army.alive[i] == 0 or army.hp[i] > 0.0:
			continue
		army.kill(i)
		grid.release_all(i)
		soldier_state[i] = SoldierState.DEAD
		soldier_target[i] = -1
		_drop_from_boats(i)
		events.append({"kind": Event.DEATH, "id": i, "is_enemy": false})


## The clock, and the verdict. **WON is checked before either loss**, so an island cleared on the
## frame the timer expires is a win rather than a coin flip on phase order.
func _phase_clock(dt: float) -> void:
	elapsed += dt
	if enemies_left() == 0:
		_outcome = Outcome.WON
		_lose = Lose.NONE
		return
	if _the_landing_force_is_gone():
		_outcome = Outcome.LOST
		# ⚠⚠ **The CONDITION and the REASON are two questions, and `army.living_count() == 0` is the
		# right answer to the second one only.** It used to be the condition, which is the bug this
		# round before last fixed: reserves at the harbour kept it from ever firing. As the REASON it
		# is exactly right — it is what 「전멸」 means — and WIPED wins when both are true, per the
		# precedence written on the `Lose` enum.
		_lose = Lose.WIPED if army.living_count() == 0 else Lose.LANDING_LOST
		return
	# ⚠⚠ **THE TIME LIMIT NO LONGER DECIDES ANYTHING** (2026-08-24, the user: 「제한 시간 안에 클리어
	# 조건은 일단 지워」). An island ends when the enemies are gone or the landing force is, and it can
	# run as long as it takes.
	#
	# ⚠⚠ **AND ON 2026-08-27 THE REST OF IT WENT TOO.** `time_limit`, `time_left()`, `Lose.TIMEOUT`,
	# `Islands.TIME_LIMIT_SEC` and the loss screen's 「패배 — 시간 초과」 had all been kept unproducible
	# on the strength of the 「일단」 in that sentence — three days, a fourth argument threaded through
	# `setup` at every call site, and an enum value the code openly documented as unreachable.
	# **A rule nothing can produce is not a rule kept warm, it is a rule that lies about existing.**
	# ⇒ Putting the clock back is a branch here plus a number, and that is cheaper than carrying a
	# fourth parameter no caller has a real value for.


## ⚠⚠ **THE FIGHT IS OVER WHEN NOBODY IS STILL IN IT, AND A SOLDIER AT THE HARBOUR IS NOT IN IT.**
##
## This was `army.living_count() == 0`, and `living_count` counts every soldier that is not dead —
## **including the ones still standing in RESERVE at the harbour.** After the commit `send` returns -1
## for anything, so a reserve soldier **can never be landed**: if everyone you sent dies and you kept
## anyone back, the run is already decided and the old test could never fire. The player sat watching
## an empty island until `TIMEOUT`, which is what they reported:
## ***"실패조건은 시작하기하고 못깨면 이지 제한시간을 계속 기다리고 있길래"***.
##
## ⚠ **The `_committed` gate is not defensive padding.** Every soldier is RESERVE during planning, so
## without it this answers TRUE on the frame an island opens and the island is lost before the player
## has dropped anything. `step` already returns before `_phase_clock` while uncommitted, so today the
## gate is unreachable — it is here because the two guards are one idea and reading `_committed`
## is what keeps them from becoming two.
##
## ⚠⚠ **TRANSIT COUNTS, and collapsing this to ASHORE would be a fake failure.** A soldier aboard an
## OUTBOUND boat has not landed and has not lost; the last crossing on an island where everything
## ashore just died is exactly the interesting case, and it is the one a narrower test would throw
## away one sub-step before it resolved.
##
## ⚠⚠ **IT READS BOTH COLUMNS, AND AN EARLIER DRAFT OF THIS COMMENT SAID THEY COULD NOT DISAGREE.**
## They can. `_phase_deaths` writes `SoldierState.DEAD` in the same block as `army.kill(i)`, but its
## first line is `if army.alive[i] == 0 ... continue` — so a soldier killed through `army` from
## OUTSIDE the fight is skipped forever and keeps whatever state it had. Nothing in `src/` does that
## today; a net does, and it is the shape a session save/load or a between-island effect would take.
## A rule that answered "still in the fight" for a corpse would hold the run open exactly as the
## reserve bug did, one column over.
##
## `army.living_count()` keeps its own reader on the map screen, where 「how many soldiers do I still
## have」 really does include reserves — that reading is correct there and wrong here, which is why
## this is a second function rather than a second caller.
func _the_landing_force_is_gone() -> bool:
	if not _committed:
		return false
	for i in soldier_state.size():
		if army.alive[i] == 0:
			continue
		var s := int(soldier_state[i])
		if s == SoldierState.ASHORE or s == SoldierState.TRANSIT:
			return false
	return true


# --- movement helpers ----------------------------------------------------------------------------

## Walks up to `step_len` tiles down `field`, tile by tile, stopping the moment it comes within
## `stop_dist` of `stop_at`.
##
## The per-tile loop is not an optimisation: with one tile per call a 0.5 s frame caps every unit at
## 2 tiles/s regardless of its speed row, so the ranged types and the crow would quietly lose their
## speed advantage the moment a probe stepped in anything but tiny increments.
##
## `goals` is a plain Array on purpose — a `PackedVector2Array` is copy-on-write and a write through
## a parameter would land in a copy, leaving every unit re-requesting the same first step forever.
## `keep_level` is passed straight to `grid.step_toward` — -1 for everybody except a defender holding
## high ground. See `_enemy_home_level`.
func _walk(uid: int, pos: Vector2, goals: Array, gi: int, step_len: float,
		field: PackedInt32Array, stop_at: Vector2, stop_dist: float,
		keep_level: int = -1) -> Vector2:
	var remaining := step_len
	var guard := 0
	var here := pos
	while remaining > Rules.EPS:
		guard += 1
		if guard > WALK_TILES_MAX:
			break
		# ⚠⚠ **`_dist` AND NOT `distance_to`, AND THIS ONE LINE FROZE THE GAME.** Everything else that
		# asks "how far" moved onto the height-aware distance and this arrival test did not, which left
		# a BAND at every tier boundary: a low tile inside a body's PLANAR reach of something standing a
		# tier up. A body told to walk exits here on the first iteration, cannot attack because the real
		# distance is 2.236, and never moves again — **12 seconds, zero pixels, nothing logged, and no
		# time limit left to end the island on.** Measured with three wolves against a plateau lion.
		# ⇒ **The stop test and the reach test have to be the same question**, or "arrived" and "in
		# reach" disagree and the gap between them is a body standing still forever.
		if _dist(here, stop_at) <= stop_dist + Rules.EPS:
			break
		var goal: Vector2 = goals[gi]
		if here.distance_to(goal) <= Rules.EPS:
			goal = grid.step_toward(uid, here, field, keep_level)
			goals[gi] = goal
			if here.distance_to(goal) <= Rules.EPS:
				# Every neighbour is taken or none is closer: the unit stands. That is the queue at
				# a two-tile neck, and it is the whole reason reservation exists.
				break
		var to_go := here.distance_to(goal)
		if to_go <= remaining:
			here = goal
			remaining -= to_go
		else:
			here += (goal - here) / to_go * remaining
			remaining = 0.0
	return here


## Gives back the tile behind a unit that has stopped for good, keeping only the one it stands on.
## `step_toward` is what normally swaps the two-tile hold, so a unit that never steps again would
## keep the tile behind it forever and a queue at a neck would be half as wide as the neck.
##
## The caller clears the stale flag so this runs once per stop and not every frame: `release_all`
## rescans the whole reservation table, and doing that for every idle unit every frame is 690k
## operations a second for no change at all.
##
## The flag itself is NOT passed in. A `PackedByteArray` parameter is a copy-on-write copy, so
## clearing it here would land in the copy and this would run again every single frame — measurably
## slower with every check about it still green.
func _settle(uid: int, goal: Vector2) -> void:
	grid.release_all(uid)
	var tile := _tile_of(goal)
	if tile < 0:
		return
	var claimed := grid.reserved
	claimed[tile] = uid
	grid.reserved = claimed


func _glide(pos: Vector2, goal: Vector2, step_len: float) -> Vector2:
	var to_go := pos.distance_to(goal)
	if to_go <= Rules.EPS or step_len >= to_go:
		return goal
	return pos + (goal - pos) / to_go * step_len


# --- targeting helpers ---------------------------------------------------------------------------

## The soldier's own range plus the reach bonus. The bonus is added HERE and never inside
## `army.range_of`, which returns the species board's range and nothing else.
func _soldier_reach(i: int) -> float:
	return army.range_of(i) + Rules.REACH_BONUS


func _enemy_reach(e: int) -> float:
	return Rules.range_of(int(enemy_type[e])) + Rules.REACH_BONUS


## **How far apart two bodies are, height included — and the ONLY place this file measures a
## distance between bodies.** 티켓 19.
##
## Bodies keep 2D positions: height is a property of the TILE, not of the body, so nothing about
## `soldier_pos`, the boats, the screen or three thousand existing net literals had to move to bring
## the axis in. The ground's own height is looked up and folded in here.
##
## ⚠⚠ **Everything that asks "how far" goes through this — reach, target choice AND the pack radius.**
## Making only the reach three-dimensional and leaving target choice planar would give the word
## "distance" two meanings inside one file, and the wolf would keep picking the enemy over the wall
## while being unable to touch it. **That it picks its own tier first is the point**: a body up a tier
## is farther away, so the pack goes for what it can actually reach and the flow field walks the rest
## to the stair.
##
## ⚠⚠ **A TIER IS ONE TILE** (`Rules.TIER_RISE_TILES`, lowered from 2.0 on 2026-08-27), so the
## neighbour across a boundary is sqrt(1 + 1) = **1.414**, and the diagonal one is sqrt(2 + 1) =
## **1.732**. A melee reach is `range_of` + `Rules.REACH_BONUS` = 0.0 + 1.75 for every beast in the
## table, so **BOTH OF THOSE ARE INSIDE MELEE REACH: a beast standing under the cliff bites a body
## on the plateau.** This comment used to say 2.236 and "outside a melee reach of 1.5", and both
## halves died with the 2.0 tier.
##
## ⚠⚠ **THAT IS A LIVE DESIGN QUESTION AND NOT A BUG THIS COMMENT MAY QUIETLY DECIDE.** The user's
## line for the second storey is 「2층은 안전한 땅이고 그 안전을 값으로 산다」, and that line is NOT
## true of this code today. Whoever changes it changes what a plateau is worth. **Do not retune
## `REACH_BONUS` to fix it** — the reach is shared by every body and every weapon; a tier-aware
## refusal belongs in `_within`, where the height is already known.
##
## **This is still not the 숫자 보너스 the user refused**: no range and no damage changed, the space
## they are measured in did.
##
## ⚠ **The equal-height branch returns `distance_to` unchanged rather than a square root of a sum with
## a zero in it.** Every board in the game was flat until this ticket and most still are; taking the
## same expression as before on those boards is what makes "no existing literal moves" a property of
## the code instead of a hope about floating point.
func _dist(a: Vector2, b: Vector2) -> float:
	return _dist_from_height(a, grid.height_at(a), b)


## The same measurement with `a`'s height supplied rather than looked up. **One caller needs it**:
## the pack's seek point is a mean of positions and the ground under that mean is not the ground
## anybody is standing on. See `_nearest_enemy`.
func _dist_from_height(a: Vector2, a_h: float, b: Vector2) -> float:
	var dh := a_h - grid.height_at(b)
	if absf(dh) <= Rules.EPS:
		return a.distance_to(b)
	return sqrt(a.distance_squared_to(b) + dh * dh)


## `<=` with an epsilon. A diagonal neighbour is exactly 1.41421..., and a bare `<=` on that float
## boundary decides from frame to frame whether four melee can reach a target or eight can.
##
## ⚠ **Through `_dist`, so a swing, a shot and a bite all measure the same space.** The bear's splash
## rides this function and therefore follows for free — `net_tiers` keeps a row on it anyway, because
## what follows for free also disappears quietly.
func _within(a: Vector2, b: Vector2, reach: float) -> bool:
	return _dist(a, b) <= reach + Rules.EPS


## Where soldier `i` LOOKS FROM when it picks a target — its own tile for most species, and the
## centre of mass of its nearby own kind (itself included) for a species with a `Rules.SPECIES_PACK`
## row.
##
## ⚠⚠ **This one function is the whole of 무리사냥, AND IT HAS NOT RUN SINCE THE SIDE SWAP** (2026-08-26).
## Same point, same pick, so the pack bites one enemy; `_phase_movement` then walks each of them at
## that enemy, so the pack ARRIVES as one body. Nothing else in this file knows a pack exists.
##
## ⚠⚠ **WHY IT IS DEAD, AND WHY IT IS KEPT.** `soldier_*` is the PLAYER's side, and `Army.register_species`
## refuses any `type_id` whose `Rules.side_of` is not `PLAYER`. The only player row is SWORDSMAN, which
## has no `Rules.SPECIES_PACK` entry, so `radius <= 0.0` returns on the first line **every single time**
## and the huddle below never runs. The one row in that table is WOLF, and the wolf is an enemy now.
## ⇒ **The enemy side has no pack behaviour at all**, and the table is waiting for the day it gets one.
## **Do not read the loop below as live behaviour, and do not delete it to chase a green** — it is the
## worked answer to "how does a pack aim", and rewriting it later costs more than keeping it.
##
## ⚠ **Ashore only, and its own species only.** A body still on a boat has no place on the ground to
## average, and averaging across species would make a wolf's aim depend on where the crows are.
func _seek_point_of(i: int) -> Vector2:
	var st := int(army.type_id[i])
	var radius := Rules.pack_radius_of(st)
	if radius <= 0.0:
		return soldier_pos[i]
	var here: Vector2 = soldier_pos[i]
	var sum := here
	var n := 1
	for k in soldier_state.size():
		if k == i or soldier_state[k] != SoldierState.ASHORE:
			continue
		if int(army.type_id[k]) != st:
			continue
		# ⚠⚠ **THIS COMMENT USED TO SAY A PACKMATE A TIER UP "DROPS OUT AT 2.236" AND THAT WAS
		# ARITHMETIC NOBODY DID.** (The figure is 1.414 now that a tier is one tile, which only makes
		# the point stronger.) A wolf's pack radius is 6.0; neither number is near it, so the
		# packmate stays in the huddle and always did. The height belongs in this test because the
		# radius is a distance and every distance in this file is measured the same way — **not because
		# it excludes anybody at the sizes this game actually uses.**
		if _dist(here, soldier_pos[k]) > radius + Rules.EPS:
			continue
		sum += soldier_pos[k]
		n += 1
	return sum / float(n)


## Nearest living enemy to `from`, measured from the height `from_h`.
##
## ⚠⚠ **THE HEIGHT IS PASSED IN AND NOT LOOKED UP, BECAUSE `from` IS NOT ALWAYS A PLACE ANYONE
## STANDS.** The pack's seek point is the MEAN of several bodies' positions, and `_dist` would read its
## height off whatever tile that mean happens to round onto — so three wolves on the ground with one
## packmate on a plateau were aiming from **two tiles up**, preferring the enemy above, and walking
## into the wall. The asking body's own tile is the only height that means anything here.
func _nearest_enemy(from: Vector2, from_h: float) -> int:
	var best := -1
	var best_d := 0.0
	for e in enemy_alive.size():
		if enemy_alive[e] == 0:
			continue
		var d: float = _dist_from_height(from, from_h, enemy_pos[e])
		if best == -1 or d < best_d - Rules.EPS:
			best = e
			best_d = d
	return best


## Nearest soldier within `detect`. `ashore_only` is the movement scan; the attack scan passes false
## so a boat still in the water can be fired on.
##
## Iterating ascending and replacing only on a STRICTLY smaller distance is what makes ties go to
## the smaller id.
func _nearest_soldier(from: Vector2, detect: float, ashore_only: bool) -> int:
	var best := -1
	var best_d := 0.0
	for i in soldier_state.size():
		if ashore_only:
			if soldier_state[i] != SoldierState.ASHORE:
				continue
		elif not is_hittable(i):
			continue
		var d: float = _dist(from, soldier_pos[i])
		if detect >= 0.0 and d > detect + Rules.EPS:
			continue
		if best == -1 or d < best_d - Rules.EPS:
			best = i
			best_d = d
	return best


# --- field cache ---------------------------------------------------------------------------------

func _age_fields(dt: float) -> void:
	var expired := []
	for key in _field_age:
		var age := float(_field_age[key]) + dt
		if age >= FIELD_TTL:
			expired.append(key)
		else:
			_field_age[key] = age
	for key in expired:
		_fields.erase(key)
		_field_age.erase(key)


func _field_for(tile: int) -> PackedInt32Array:
	if _fields.has(tile):
		var cached: PackedInt32Array = _fields[tile]
		return cached
	var built := grid.flow_field(tile)
	_fields[tile] = built
	_field_age[tile] = 0.0
	return built


# --- tiles ---------------------------------------------------------------------------------------

func _point_of_tile(tile: int) -> Vector2:
	if grid == null or grid.w <= 0:
		return OFFMAP
	return Vector2(tile % grid.w, tile / grid.w)


func _tile_of(pos: Vector2) -> int:
	if grid == null or grid.w <= 0:
		return -1
	var tx := clampi(int(round(pos.x)), 0, grid.w - 1)
	var ty := clampi(int(round(pos.y)), 0, grid.h - 1)
	return ty * grid.w + tx


## Free tiles nearest `target_tile`, breadth-first, in visit order — so the landing tile itself comes
## first when it is free.
##
## ⚠ **This is where the drop order becomes a picture.** A boat is one soldier now, so with several
## boats aimed at one beach every call after the first finds the target tile already reserved and
## walks one ring out. Combined with `_phase_landings`' ascending pass that makes "the first dropped
## stands in front" a property of the search order rather than of a rule someone maintains — and it is
## the ONLY thing the drop order decides, since every boat departs on the commit sub-step.
##
## The search WALKS OVER reserved tiles and only COLLECTS unreserved ones. A search that refused to
## cross an occupied tile would be sealed in by the first soldier to land, and the boat behind it
## would wait out the island at a coast with an empty beach two tiles away.
func _free_tiles_from(target_tile: int, wanted: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := grid.w * grid.h
	if n == 0 or target_tile < 0 or target_tile >= n or wanted <= 0:
		return out
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	queue.append(target_tile)
	seen[target_tile] = 1
	var head := 0
	# ⚠⚠ **THE LANDING'S OWN TIER, AND WITHOUT IT A BOAT PUT BODIES ON TOP OF THE WALL.** Measured on
	# the real first island: asking this for four standing tiles from an approved landing handed back a
	# tile ON THE PLATEAU — a place nothing can walk to and nothing can walk from. Worse than a
	# misplaced body: `step_toward` reads a body's tier off the tile it stands on, so one dropped up
	# there **becomes a legitimate plateau resident**, unreachable by every enemy, and the island can
	# never end.
	var want_level := grid.level_of(target_tile)
	while head < queue.size() and out.size() < wanted:
		var t := queue[head]
		head += 1
		# Collect only at the landing's own height. A body walks off a boat; it does not climb on the
		# way out, so a full beach must NOT spill up the stair.
		if grid.passable[t] != 0 and grid.reserved[t] == -1 and grid.level_of(t) == want_level:
			out.append(t)
		var tx := t % grid.w
		var ty := t / grid.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				continue
			var nt := ny * grid.w + nx
			# ⚠ **`can_step` and not `passable`** — the SEARCH may not cross a wall either, so a beach
			# cannot borrow free tiles from a strip of land that is only reachable through the plateau.
			# ⚠⚠ **THE TWO GUARDS OVERLAP AND THAT WAS MEASURED, NOT ASSUMED.** Removing either one
			# alone reddens NOTHING on today's islands: this one already refuses to enqueue a plateau
			# tile, and the collect test already refuses to hand one back. **Each covers the other for
			# level 2.** What they do not share is at the edges — the collect test alone stops a body
			# standing on a STAIR (level 1, which this one is right to walk through), and this one alone
			# stops a search reaching land it cannot walk to. `net_tiers` carries a case for each, on
			# boards built so the other guard cannot answer.
			if seen[nt] != 0 or not grid.can_step(t, nt):
				continue
			seen[nt] = 1
			queue.append(nt)
	return out


# --- bookkeeping ---------------------------------------------------------------------------------

## A soldier shot dead in transit leaves its boat, and the empty boat sails on: `_try_unload` returns
## true for empty cargo, so it turns RETURNING at the beach and vanishes at its harbour like any
## other. **This is the ONLY cleanup a death needs** — with no queue and no berth there is no second
## list a dead id can be sitting in, which is what makes "a body killed far from home loses its cargo"
## structurally true rather than something a caller has to remember.
func _drop_from_boats(sid: int) -> void:
	for raw in boats:
		var boat: Dictionary = raw
		var carried: Array = boat["soldiers"]
		var at := carried.find(sid)
		if at != -1:
			carried.remove_at(at)
