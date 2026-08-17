class_name Battle
extends RefCounted
## One island's fight. `step(dt)` drives all of it — boats, landings, targeting, movement, attacks,
## deaths and the clock — and nothing in this file is a Node, so a net builds one with `.new()` and
## drives it frame by frame with no tree at all.
##
## **The phase order inside `step` is a contract, not an implementation detail.** Boats before
## landings means a boat that reaches the shore this frame unloads this frame instead of next.
## Attacks before deaths means two units that finish each other off both land their blow — the
## alternative silently gives whoever iterates first a free kill, and the free kill is invisible in
## final state. The clock last means an island cleared on the very frame the timer expires is a WIN.
## The first slice plan pins this under "The sim — shapes and entry points".
##
## Distances are in TILES throughout, centre to centre, and positions carry tile centres on integers.
## The view multiplies by the tile size and nothing here knows what a pixel is.


enum Outcome { RUNNING, WON, LOST }

## Why the island was lost. The loss screen has to say which, because "the timer ran out" and "every
## soldier is dead" are different mistakes and a screen that shows neither teaches nothing.
enum Lose { NONE, TIMEOUT, WIPED }

## Where a soldier is right now, on THIS island. It is per-island state and not part of the roster:
## `army` holds who exists and how hurt they are, and that is what carries to the next island.
##
## RESERVE -> LOADED -> TRANSIT -> ASHORE is one way. **A soldier that has landed never goes back to
## RESERVE**, which is what makes "one deployment per soldier per island" structural instead of a
## rule someone has to remember in `load_soldier`.
enum SoldierState { RESERVE, LOADED, TRANSIT, ASHORE, DEAD }

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
var time_limit := 0.0
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

# --- soldiers. Indexed by ARMY id, so index i is the same soldier here and in `army` --------------
var soldier_state := PackedInt32Array()
var soldier_pos: Array = []               # Vector2, tile units
var soldier_target := PackedInt32Array()  # enemy index, or -1
var _soldier_cd := PackedFloat32Array()
var _soldier_goal: Array = []
var _soldier_stale := PackedByteArray()

# --- boats -----------------------------------------------------------------------------------------
## Which harbour each boat is sitting at, indexed by boat (`Rules.boat_count()` of them). Meaningless
## while a boat is in `boats` — see `pending` below for why there is no third "berth" state.
var boat_at := PackedInt32Array()
## Soldier ids loaded onto each boat that has not sailed yet — one `PackedInt32Array` per boat,
## capped at `Rules.cap_of(boat)`.
var pending: Array = []
## Boats at sea. **A boat is busy IFF it is in here** — `boat-and-landing`, 4.2, deletes the old berth
## timer outright rather than indexing it per boat: the return leg is now simulated and drawn, so a
## timer running in parallel with it would be a second copy of the same fact, and two clocks drift.
## Each entry is `{boat, phase, speed, from, to, dist, t, soldiers, target, home}`, with `from` / `to`
## in tile units. `phase` is `Phase.OUTBOUND` (soldiers aboard, sailing to `target`) or
## `Phase.RETURNING` (empty, sailing to harbour `home`). Waiting-to-unload is OUTBOUND with `t` past
## arrival — there is no separate waiting state.
var boats: Array = []

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
func setup(grid: Grid, army: Army, spawns: Array, time_limit: float) -> void:
	self.grid = grid
	self.army = army
	self.time_limit = time_limit
	elapsed = 0.0
	events = []
	_outcome = Outcome.RUNNING
	_lose = Lose.NONE
	_fields = {}
	_field_age = {}
	boats = []
	pending = []
	for _b in Rules.boat_count():
		pending.append(PackedInt32Array())
	# Every boat starts at the same harbour — the one `grid.load_rows` derived as farthest from its
	# own reachable coast (`boat-and-landing`, section 5), so the run opens with the fleet out at sea
	# and the longest crossing it will ever face.
	boat_at = PackedInt32Array()
	boat_at.resize(Rules.boat_count())
	if grid != null:
		boat_at.fill(grid.start_harbour)

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
	soldier_pos = []
	_soldier_goal = []
	for i in roster:
		# A soldier who died on an earlier island is DEAD here, never RESERVE. Leaving them in
		# RESERVE would let `load_soldier` walk past them one by one and the boarding order would
		# quietly skip live soldiers behind a wall of corpses.
		soldier_state[i] = SoldierState.RESERVE if army.alive[i] != 0 else SoldierState.DEAD
		soldier_target[i] = -1
		_soldier_cd[i] = 0.0
		_soldier_stale[i] = 0
		soldier_pos.append(OFFMAP)
		_soldier_goal.append(OFFMAP)


## Puts one soldier of `type_id` on a boat that has not sailed. **The highest-HP living soldier of
## that type still in reserve** — `army.living_ids_of_type` is already sorted that way and breaks
## ties on the smaller id, so two runs from identical state board identically.
##
## **Which boat**: the lowest-index boat that is not at sea and still has room — the big boat first,
## the fast boat once the big one is full or at sea. Returns that boat's index so the caller (the HUD)
## can mark the right one, or **-1** when every boat is at sea or no such soldier exists. This is a
## feel item and the user marked it temporary (`boat-and-landing`, 4.4) — it is a rule only because
## per-boat capacity forces the question of who boards where.
##
## ⚠ **A boat at sea can no longer be loaded** — `boat-and-landing`, 4.4. With per-boat cargo there is
## no queue for a load to join while every boat is out; a harbour drawn empty then means exactly one
## thing: nothing to load, nothing to send.
func load_soldier(type_id: int) -> int:
	if army == null:
		return -1
	var boat := -1
	for b in Rules.boat_count():
		if boat_busy(b):
			continue
		var here: PackedInt32Array = pending[b]
		if here.size() >= Rules.cap_of(b):
			continue
		boat = b
		break
	if boat == -1:
		return -1
	for raw in army.living_ids_of_type(type_id):
		var i := int(raw)
		if soldier_state[i] != SoldierState.RESERVE:
			continue
		soldier_state[i] = SoldierState.LOADED
		var loaded: PackedInt32Array = pending[boat]
		loaded.append(i)
		pending[boat] = loaded
		return boat
	return -1


## True while `boat` is at sea (outbound with cargo, or returning empty) — the state that makes it
## unloadable and undraggable. There is no separate berth timer; membership in `boats` IS the state
## (`boat-and-landing`, 4.2).
func boat_busy(boat: int) -> bool:
	for raw in boats:
		var bo: Dictionary = raw
		if int(bo["boat"]) == boat:
			return true
	return false


## Sends `boat` — sitting loaded at whichever harbour `boat_at[boat]` names — to `tile`. False and
## **nothing happens at all** when the boat index is out of range, the boat is empty, the boat is
## already at sea, or `tile` is not a coast that boat's OWN harbour can reach
## (`grid.can_land_at(boat_at[boat], tile)` — the one predicate the drag overlay and this call both
## answer to, so the screen can never disagree with the rule).
func launch(boat: int, tile: int) -> bool:
	if grid == null or boat < 0 or boat >= Rules.boat_count():
		return false
	if boat_busy(boat):
		return false
	var cargo: PackedInt32Array = pending[boat]
	if cargo.is_empty():
		return false
	var harbour_idx := int(boat_at[boat])
	if not grid.can_land_at(harbour_idx, tile):
		return false

	var from: Vector2 = _point_of_tile(int(grid.harbour_tiles[harbour_idx]))
	var to: Vector2 = _point_of_tile(tile)
	var carried := []
	for raw in cargo:
		var i := int(raw)
		soldier_state[i] = SoldierState.TRANSIT
		soldier_pos[i] = from
		carried.append(i)
	pending[boat] = PackedInt32Array()
	boats.append({
		"boat": boat,
		"phase": Phase.OUTBOUND,
		"speed": Rules.boat_speed_of(boat),
		"from": from,
		"to": to,
		"dist": maxf(from.distance_to(to), Rules.EPS),
		"t": 0.0,
		# `pos` is also set here, not only by the first `_phase_boats` call — the view reads
		# `boat["pos"]` on layer 6 and nothing steps between `launch` and the first `_draw()` unless
		# the caller does so on purpose (a net proving the drag overlay before the first frame, say).
		"pos": from,
		"soldiers": carried,
		"target": tile,
		"home": -1,
	})
	return true


## Throws away last frame's `events`. **Every driver of this class calls it once a frame, before
## `step`** — the shell, the headless probe and every net that turns frames.
##
## It is not done inside `step` and that is not a style choice. `step` returns early when the island
## is over or `dt` is 0, so clearing at its head means the last frame's events survive from the
## moment a panel opens and the view replays them forever; clearing at its tail means nobody ever
## sees them. Both were shipped in the dead game and cost two effects outright.
func begin_frame() -> void:
	events.clear()


## One frame. The phase order below is the contract described at the top of this file.
func step(dt: float) -> void:
	if _outcome != Outcome.RUNNING or grid == null or army == null:
		return
	if dt <= 0.0:
		return
	_phase_boats(dt)
	_phase_landings()
	_phase_targeting()
	_phase_movement(dt)
	_phase_attacks(dt)
	_phase_deaths()
	_phase_clock(dt)


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


func time_left() -> float:
	return maxf(0.0, time_limit - elapsed)


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
		var dist := float(boat["dist"])
		var f := clampf(float(boat["t"]) * float(boat["speed"]) / dist, 0.0, 1.0)
		var here: Vector2 = Vector2(boat["from"]).lerp(Vector2(boat["to"]), f)
		boat["pos"] = here
		for sid in boat["soldiers"]:
			soldier_pos[int(sid)] = here


## Boats that have finished a leg act on it. **OUTBOUND** tries to unload — if there are fewer free
## tiles than soldiers aboard the whole boat waits (landing part of a load would silently reorder the
## deployment the player chose), and only on success does it turn RETURNING and sail to
## `grid.home_harbour_for(target)` — the harbour nearest the landing among the ones that can still see
## it, never simply the nearest, or a beachhead behind a headland strands itself (`boat-and-landing`,
## 4.3). **RETURNING** leaves `boats` on arrival and hands the harbour back to `boat_at`, which is the
## whole of what makes a boat loadable and draggable again.
func _phase_landings() -> void:
	var i := boats.size() - 1
	while i >= 0:
		var boat: Dictionary = boats[i]
		var arrived := float(boat["t"]) * float(boat["speed"]) + Rules.EPS >= float(boat["dist"])
		if not arrived:
			i -= 1
			continue
		if int(boat["phase"]) == Phase.OUTBOUND:
			if _try_unload(boat):
				var target := int(boat["target"])
				var home := grid.home_harbour_for(target)
				boat["phase"] = Phase.RETURNING
				boat["soldiers"] = []
				boat["home"] = home
				boat["from"] = _point_of_tile(target)
				boat["to"] = _point_of_tile(int(grid.harbour_tiles[home]))
				boat["dist"] = maxf(Vector2(boat["from"]).distance_to(Vector2(boat["to"])), Rules.EPS)
				boat["t"] = 0.0
				boats[i] = boat
		else:
			boat_at[int(boat["boat"])] = int(boat["home"])
			boats.remove_at(i)
		i -= 1


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
		soldier_target[i] = _nearest_enemy(soldier_pos[i])

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
		var speed := Rules.speed_of(int(army.type_id[i]))
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
		var speed := Rules.speed_of(int(enemy_type[e]))
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
				_field_for(_tile_of(seek)), seek, _enemy_reach(e))
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
		var st := int(army.type_id[i])
		_soldier_cd[i] = Rules.period_of(st)
		_hit_enemies(i, tgt, Rules.damage_of(st), Rules.area_of(st))

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
		_drop_from_pending(i)
		events.append({"kind": Event.DEATH, "id": i, "is_enemy": false})


## The clock, and the verdict. **WON is checked before either loss**, so an island cleared on the
## frame the timer expires is a win rather than a coin flip on phase order.
func _phase_clock(dt: float) -> void:
	elapsed += dt
	if enemies_left() == 0:
		_outcome = Outcome.WON
		_lose = Lose.NONE
		return
	if army.living_count() == 0:
		_outcome = Outcome.LOST
		_lose = Lose.WIPED
		return
	if elapsed + Rules.EPS >= time_limit:
		_outcome = Outcome.LOST
		_lose = Lose.TIMEOUT


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
func _walk(uid: int, pos: Vector2, goals: Array, gi: int, step_len: float,
		field: PackedInt32Array, stop_at: Vector2, stop_dist: float) -> Vector2:
	var remaining := step_len
	var guard := 0
	var here := pos
	while remaining > Rules.EPS:
		guard += 1
		if guard > WALK_TILES_MAX:
			break
		if here.distance_to(stop_at) <= stop_dist + Rules.EPS:
			break
		var goal: Vector2 = goals[gi]
		if here.distance_to(goal) <= Rules.EPS:
			goal = grid.step_toward(uid, here, field)
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
## `army.range_of`, which returns the beak's range and nothing else.
func _soldier_reach(i: int) -> float:
	return army.range_of(i) + Rules.REACH_BONUS


func _enemy_reach(e: int) -> float:
	return Rules.range_of(int(enemy_type[e])) + Rules.REACH_BONUS


## `<=` with an epsilon. A diagonal neighbour is exactly 1.41421..., and a bare `<=` on that float
## boundary decides from frame to frame whether four melee can reach a target or eight can.
func _within(a: Vector2, b: Vector2, reach: float) -> bool:
	return a.distance_to(b) <= reach + Rules.EPS


func _nearest_enemy(from: Vector2) -> int:
	var best := -1
	var best_d := 0.0
	for e in enemy_alive.size():
		if enemy_alive[e] == 0:
			continue
		var d: float = from.distance_to(enemy_pos[e])
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
		var d: float = from.distance_to(soldier_pos[i])
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
## first when it is free and the load lands in the order it boarded.
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
	while head < queue.size() and out.size() < wanted:
		var t := queue[head]
		head += 1
		if grid.passable[t] != 0 and grid.reserved[t] == -1:
			out.append(t)
		var tx := t % grid.w
		var ty := t / grid.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				continue
			var nt := ny * grid.w + nx
			if seen[nt] != 0 or grid.passable[nt] == 0:
				continue
			seen[nt] = 1
			queue.append(nt)
	return out


# --- bookkeeping ---------------------------------------------------------------------------------

func _drop_from_boats(sid: int) -> void:
	for raw in boats:
		var boat: Dictionary = raw
		var carried: Array = boat["soldiers"]
		var at := carried.find(sid)
		if at != -1:
			carried.remove_at(at)


## A LOADED soldier cannot be attacked, so this only ever fires if a future rule lets one die at the
## quayside. It is one line per boat and it keeps a dead id out of the next launch.
func _drop_from_pending(sid: int) -> void:
	for b in pending.size():
		var here: PackedInt32Array = pending[b]
		var at := here.find(sid)
		if at != -1:
			here.remove_at(at)
			pending[b] = here
			return
