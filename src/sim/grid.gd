class_name Grid
extends RefCounted
## The island's tiles: passability, water, harbours, landing reach, per-unit tile reservation, and the
## BFS flow field every unit walks down. Pure data — no Node, no tree, `.new()` is the whole
## construction.
##
## **Movement is a flow field and never a greedy descent.** Greedy 8-way descent was measured stalling
## on five of twenty-six dock-to-enemy pairs on these three grids, so a walker that "obviously works"
## silently freezes on island 2's north-east crow and everything inside island 3's ring. The first-slice
## plan records the measurement under "What two adversarial passes broke".
##
## **The coastline is open, not docked, and landing is a DENYLIST.** `boat-and-landing`, section 3,
## replaced the old fixed-dock legend with harbours (`H`, plural, water tiles a boat sails from and
## returns to). `speed-off-open-landing` then replaced the permit list with the refusal list the user
## actually asked for: ***"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"***.
##
## ⚠⚠ **What the old rule cost, measured on all three shipped islands before it was replaced**: it
## refused **39% · 42% · 40%** of each island's own coastline, because `water_line_clear` sampled a
## STRAIGHT line from the harbour and any headland blocked it. That is what read as *the landing spots
## are fixed*. The replacement is a BFS over WATER — `_water_field` — so a boat sails AROUND the
## headland, and since all water on all three islands is one connected body (724 / 690 / 726 tiles,
## every one reachable from every harbour) **the refused set is now exactly `cliff + inland`, with
## nothing left over**. Sendable went 50 -> 84, 44 -> 76, 48 -> 82.
##
## ⚠ **A bigger number is not the same as the right set.** Merely dropping the coast-adjacency test
## would have given 97 / 83 / 94 — MORE tiles than the water route gives — by letting a boat land one
## tile INLAND while still refusing 40% of the actual shore. `speed-off-open-landing` 2.1 records the
## whole table; do not read that middle column as better.
##
## `can_land_at(harbour, tile)` is the one rule that decides where a boat may go, and
## `home_harbour_for` — which is `can_land_at` filtered and then nearest BY WATER ROUTE — is what
## `Battle.send` answers to, so the screen cannot promise a tile the sim refuses.


## Unreachable tiles carry this instead of a sentinel like -1, so a caller comparing field values with
## `<` treats them as the worst option rather than the best one.
const UNREACHABLE := 1 << 30

## Row legend. Anything not listed is loaded as an impassable hole: validating the legend is
## `net_islands`' job, and a `push_error` here would have to be forgiven by every net that hands this
## function a hand-written fixture.
##
## `.` land, `/` ramp (a doorway through a cliff wall — both walkable), `B`/`C`/`L` land with a spawn.
const LAND_CHARS := "./BCL"
## `~` water, `H` harbour — a water tile a boat may sail from and return to.
const WATER_CHARS := "~H"
const HARBOUR_CHAR := "H"

## 8-way, listed in a fixed order so an equal-cost tie always resolves the same way. Plain `const`
## Arrays: `const X := PackedInt32Array([...])` is a parse error on 4.7, so every read casts.
const NEIGHBOURS := [
	[-1, -1], [0, -1], [1, -1],
	[-1, 0], [1, 0],
	[-1, 1], [0, 1], [1, 1],
]

## ⚠ **`ORTHO` is deleted from this file.** It existed for `landable` — "a tile touching water only
## at a corner is not landable" — and `speed-off-open-landing` deleted that predicate whole: the
## denylist opens the 8-WAY coast, so a tile touching water at a corner IS landable now, and that is
## the difference between 82 and 84 tiles on island 0. Its one other reader was `field_view`'s
## cliff-face pass, which walks a cliff tile's seaward EDGES and genuinely needs the four sides; the
## four offsets moved into that file as its own private constant rather than dying.
##
## ⚠ **`Rules.LINE_SAMPLE_STEP` and `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV` are deleted too.** They
## tuned `water_line_clear`, which is gone, and a rule constant nobody reads rots silently.

var w: int = 0
var h: int = 0
var passable := PackedByteArray()      # w*h, 1 = walkable (includes a ramp)
var water := PackedByteArray()         # w*h, 1 = water (includes a harbour)
var harbour_tiles := PackedInt32Array()   # row-major order — this defines harbour index
## One BFS field per harbour over WATER tiles, hop count from that harbour, `UNREACHABLE` where a
## boat cannot get. Indexed the same way `sendable` is. **This is the whole of the landing rule** —
## a tile is sendable iff some 8-neighbour of it is water this field reached — and it is also where
## `water_route` reads the polyline a boat actually sails.
##
## ⚠ **`landable` is DELETED and not kept beside this.** It was `passable AND some ORTHO neighbour is
## water`, and the denylist opens the 8-way coast instead, so keeping it would be a second and
## narrower answer to the same question sitting one line away from the real one.
var water_fields: Array = []           # Array of PackedInt32Array, one per harbour
## `sendable[hb][t]` = 1 iff a boat at harbour `hb` may be sent to tile `t` — passable AND some 8-way
## neighbour of `t` is water that `water_fields[hb]` reached. Filled ONCE per harbour inside
## `load_rows`; `can_land_at` only ever reads it back. See 3.5: computed live it would be 1536 tiles
## x 3 harbours a FRAME, and a BFS is more expensive than the line test it replaced, not less.
var sendable: Array = []               # Array of PackedByteArray, one per harbour
## The harbour whose nearest reachable coast tile is farthest away, ties to the lowest tile index (which
## is also the lowest harbour index, since `harbour_tiles` is row-major). -1 on an empty grid.
var start_harbour: int = -1
## Every water BFS ever built, one per harbour per `load_rows`. **A net asserts this does not move
## across pumped frames or across sixty `can_land_at` / `home_harbour_for` / `water_route` calls** —
## the field is a load-time cost, not a per-frame one, and that is the whole reason it is cached.
## ⚠ It replaces `line_tests`, which counted the deleted straight-line sampler's calls and was the
## same guarantee about the cheaper thing.
var water_field_builds: int = 0

var reserved := PackedInt32Array()     # tile -> unit id, or -1

## unit id -> Array of tiles it currently holds. At most two: the tile it stands on and the tile it is
## walking into. This is only the fast path for releasing — `reserved` is the authority, which is why
## `release_all` rescans it in full instead of trusting this.
var _held := {}


## Loads one island's rows. Safe to call twice: every array is rebuilt, so a `Grid` reused across
## islands cannot inherit the previous island's reservations.
func load_rows(rows: Array) -> void:
	h = rows.size()
	w = 0
	if h > 0:
		w = String(rows[0]).length()
	var n := w * h
	passable = PackedByteArray()
	passable.resize(n)
	water = PackedByteArray()
	water.resize(n)
	reserved = PackedInt32Array()
	reserved.resize(n)
	reserved.fill(-1)
	harbour_tiles = PackedInt32Array()
	_held = {}
	water_field_builds = 0

	for y in h:
		var row := String(rows[y])
		for x in w:
			var t := y * w + x
			if x >= row.length():
				passable[t] = 0
				water[t] = 0
				continue
			var c := row[x]
			passable[t] = 1 if LAND_CHARS.find(c) != -1 else 0
			water[t] = 1 if WATER_CHARS.find(c) != -1 else 0
			# Append order IS harbour index, row-major — the same convention the deleted `dock_tiles`
			# used, so an index is stable and reproducible.
			if c == HARBOUR_CHAR:
				harbour_tiles.append(t)

	# ⚠ **Both tables are filled here and NOWHERE else, once per island.** The comment on
	# `can_land_at` records the cost that forces it; a BFS per harbour is ~1536 operations, and
	# recomputing one per tile per frame would be 1536 x 3 BFS passes a frame.
	water_fields = []
	sendable = []
	for hb in harbour_tiles.size():
		var field := _water_field(int(harbour_tiles[hb]))
		var arr := PackedByteArray()
		arr.resize(n)
		for t in n:
			# The landing tile itself must be LAND — a boat unloads soldiers onto it — and it must
			# touch, on any of eight sides, water this harbour's boat can actually reach. Those two
			# conditions are the whole denylist: what is left refused is cliff (impassable) and
			# inland (no water neighbour).
			if passable[t] == 0:
				continue
			if _entry_water_tile(field, t) >= 0:
				arr[t] = 1
		water_fields.append(field)
		sendable.append(arr)

	start_harbour = _derive_start_harbour()


func is_passable(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return false
	return passable[ty * w + tx] != 0


func tile_point(t: int) -> Vector2:
	if w <= 0:
		return Vector2.ZERO
	return Vector2(t % w, t / w)


func tile_index(tx: int, ty: int) -> int:
	return ty * w + tx


## Whether a boat sitting at harbour `harbour_idx` may be sent to tile `t`. **Reads the cached
## `sendable` table filled once in `load_rows` — never runs a BFS here.** That split is what makes
## `water_field_builds` flat across a pumped frame; recomputed per call at 1536 tiles a frame it would
## be a real wall (3.5 of the plan), and worse than the straight-line test it replaced rather than
## better.
func can_land_at(harbour_idx: int, t: int) -> bool:
	if harbour_idx < 0 or harbour_idx >= sendable.size():
		return false
	var arr: PackedByteArray = sendable[harbour_idx]
	if t < 0 or t >= arr.size():
		return false
	return arr[t] != 0


## Breadth-first from a harbour over WATER tiles, 8-way, cost in hops. **A deliberate mirror of
## `flow_field` and not a call to it**: same queue, same `UNREACHABLE` sentinel, same fixed
## `NEIGHBOURS` order — `water[nt] == 0: continue` in place of `passable[nt] == 0: continue`, and
## that one line is the entire difference. Sharing one function through a flag would put the two
## traversals one typo apart, and a boat that walked the LAND field would sail over the island with
## every check about reachability still green.
##
## The seed is planted at the harbour tile whatever its own contents, exactly as `flow_field` does,
## and for the same reason: an all-unreachable field produces an island with no landings at all and
## nothing logged.
func _water_field(seed_tile: int) -> PackedInt32Array:
	water_field_builds += 1
	var n := w * h
	var field := PackedInt32Array()
	field.resize(n)
	field.fill(UNREACHABLE)
	if seed_tile < 0 or seed_tile >= n:
		return field
	field[seed_tile] = 0
	var queue := PackedInt32Array()
	queue.append(seed_tile)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var tx := t % w
		var ty := t / w
		var next_cost := field[t] + 1
		for k in NEIGHBOURS.size():
			var nx := tx + int(NEIGHBOURS[k][0])
			var ny := ty + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if water[nt] == 0:
				continue
			if field[nt] <= next_cost:
				continue
			field[nt] = next_cost
			queue.append(nt)
	return field


## The water tile a boat aimed at `t` actually stops on: the 8-neighbour of `t` that is water AND
## that `field` reached, cheapest first. **-1 when none, and -1 is the refusal** — an inland tile has
## no water neighbour at all, and a coast tile on a lake this harbour cannot reach has one the field
## never touched.
##
## Ties go to the earliest `NEIGHBOURS` entry (the comparison is a strict `<`), so two runs from
## identical rows pick the same approach and `water_route` is reproducible.
##
## ⚠ **8-way and not 4-way.** A tile touching water only at a CORNER is landable now — that is the
## user's 「어디든지」, and on island 0 it is exactly the two tiles between the ortho coast (82) and
## the 8-way coast (84).
func _entry_water_tile(field: PackedInt32Array, t: int) -> int:
	var n := w * h
	if n == 0 or t < 0 or t >= n or field.size() != n:
		return -1
	var tx := t % w
	var ty := t / w
	var best := -1
	var best_cost := 0
	for k in NEIGHBOURS.size():
		var nx := tx + int(NEIGHBOURS[k][0])
		var ny := ty + int(NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var nt := ny * w + nx
		if water[nt] == 0:
			continue
		if field[nt] == UNREACHABLE:
			continue
		if best == -1 or field[nt] < best_cost:
			best = nt
			best_cost = field[nt]
	return best


## **The route a boat sails**, harbour first and landing last, in TILE units with tile centres on
## integers — never pixels. Empty when the landing is refused, which is the same test `Battle.send`
## refuses on, so a caller can price a crossing without asking twice.
##
## It walks DOWN `water_fields[harbour_idx]` from the landing's entry tile, one strictly-lower 8-way
## water neighbour at a time, the way `step_toward` walks `flow_field` — then reverses, so index 0 is
## the harbour. The landing tile itself is appended as the last hop: it is LAND, so it is not in the
## field and cannot come out of the descent.
##
## ⚠ **The descent terminates because BFS cost drops by exactly 1 every step**, but the loop is
## guarded at `w * h` anyway. A hung sim prints no verdict at all, and that is the failure shape that
## silently disarmed a whole net in this repo once.
func water_route(harbour_idx: int, landing: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not can_land_at(harbour_idx, landing):
		return out
	var field: PackedInt32Array = water_fields[harbour_idx]
	var cur := _entry_water_tile(field, landing)
	if cur < 0:
		return out
	var guard := 0
	var limit := w * h
	while true:
		out.append(tile_point(cur))
		if field[cur] == 0:
			break
		guard += 1
		if guard > limit:
			break
		var cx := cur % w
		var cy := cur / w
		var step := -1
		var step_cost := field[cur]
		for k in NEIGHBOURS.size():
			var nx := cx + int(NEIGHBOURS[k][0])
			var ny := cy + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if water[nt] == 0:
				continue
			# Strictly lower, so the walk cannot sit between two equal-cost tiles forever. The same
			# `<` (and not `<=`) that `step_toward` carries, and for the same reason.
			if field[nt] >= step_cost:
				continue
			step = nt
			step_cost = field[nt]
		if step < 0:
			break
		cur = step
	out.reverse()
	out.append(tile_point(landing))
	return out


## The harbour with the SHORTEST WATER ROUTE to `landing`, among the harbours that can reach it at
## all (`can_land_at(h, landing)`), ties to the lowest index. **The set is never empty when `landing`
## was ever sendable at all** — the boat sailed from one such harbour, so at worst it stays put.
## Returns -1 only when NO harbour can reach the tile, which is exactly the refusal `Battle.send`
## answers to.
##
## ⚠ **It was straight-line distance and it is not any more.** Straight-line ranking picks a harbour
## on the far side of a headland — near as the crow flies, a long sail — and a beachhead behind that
## headland strands itself (measured under the old rule: 2 of 46 beachheads on island 3).
##
## ⚠⚠ **The metric is HOP COUNT and not sailed length, and that is a deliberate coarseness.** It
## mirrors `flow_field`, which is also hop count; a diagonal hop costs 1 here and sqrt(2) tiles on the
## water, so the fewest-hops harbour is occasionally not the shortest actual sail. Making it exact
## needs a Dijkstra with two edge weights, which is a bigger change than this rule is worth — the
## error is bounded by 41% on a route that is all diagonal, and every harbour on these islands is
## reached by a mixed route. **Do not "fix" it by weighting one and leaving `flow_field` unweighted**;
## the two would then disagree about what "near" means on the same grid.
func home_harbour_for(landing: int) -> int:
	var best := -1
	var best_hops := 0
	for hb in harbour_tiles.size():
		if not can_land_at(hb, landing):
			continue
		var field: PackedInt32Array = water_fields[hb]
		var entry := _entry_water_tile(field, landing)
		if entry < 0:
			continue
		var hops := int(field[entry])
		if best == -1 or hops < best_hops:
			best = hb
			best_hops = hops
	return best


## The harbour whose nearest reachable coast tile is farthest away, ties to the lowest tile index (which
## `harbour_tiles`' row-major fill makes the same as the lowest harbour index). Called once from
## `load_rows`, after `sendable` is filled.
func _derive_start_harbour() -> int:
	var best := -1
	var best_d := -1.0
	for hb in harbour_tiles.size():
		var nearest := -1.0
		var arr: PackedByteArray = sendable[hb]
		for t in arr.size():
			if arr[t] == 0:
				continue
			var d: float = tile_point(int(harbour_tiles[hb])).distance_to(tile_point(t))
			if nearest < 0.0 or d < nearest - Rules.EPS:
				nearest = d
		if nearest < 0.0:
			nearest = 0.0
		if best == -1 or nearest > best_d + Rules.EPS:
			best = hb
			best_d = nearest
	return best


## Breadth-first from `target_tile` over passable tiles, 8-way. Cost is hop count; unreachable tiles
## keep `UNREACHABLE`.
##
## **Reserved tiles are traversable here on purpose.** If occupancy entered the field, every field
## would have to be rebuilt the moment anybody moved; instead the field is terrain-only and cached,
## and `step_toward` is where occupancy is honoured.
func flow_field(target_tile: int) -> PackedInt32Array:
	var n := w * h
	var field := PackedInt32Array()
	field.resize(n)
	field.fill(UNREACHABLE)
	if target_tile < 0 or target_tile >= n:
		return field
	# The seed is planted whatever the target's own passability. A target standing on an impassable
	# tile — a soldier still aboard a boat — would otherwise produce an all-unreachable field, and
	# every unit asking for it stands still for the rest of the island with nothing logged.
	field[target_tile] = 0
	var queue := PackedInt32Array()
	queue.append(target_tile)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var tx := t % w
		var ty := t / w
		var next_cost := field[t] + 1
		for k in NEIGHBOURS.size():
			var nx := tx + int(NEIGHBOURS[k][0])
			var ny := ty + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if passable[nt] == 0:
				continue
			if field[nt] <= next_cost:
				continue
			field[nt] = next_cost
			queue.append(nt)
	return field


## One step down `field`. `from` is in **tile units, tile centres on integers** — not pixels; the view
## multiplies by the tile size, and mixing the two is the 4.8x error this repo has already paid for.
##
## Picks the neighbour with the lowest field value that is passable and either unreserved or already
## this unit's, reserves it, releases the tile behind, and returns the point to walk toward. **If every
## candidate is taken the unit's own position comes back and it stands** — that is the queue at a neck.
func step_toward(unit_id: int, from: Vector2, field: PackedInt32Array) -> Vector2:
	var n := w * h
	if n == 0 or field.size() != n:
		return from
	var cx := clampi(int(round(from.x)), 0, w - 1)
	var cy := clampi(int(round(from.y)), 0, h - 1)
	var cur := cy * w + cx
	_hold(unit_id, cur)
	var best := -1
	var best_cost := field[cur]
	for k in NEIGHBOURS.size():
		var nx := cx + int(NEIGHBOURS[k][0])
		var ny := cy + int(NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var nt := ny * w + nx
		if passable[nt] == 0:
			continue
		if reserved[nt] != -1 and reserved[nt] != unit_id:
			continue
		# Strictly better than where it stands. An `<=` here lets a unit already on the target tile
		# step off onto an equal-cost neighbour and oscillate forever, which reads as jitter rather
		# than as a bug.
		if field[nt] >= best_cost:
			continue
		best = nt
		best_cost = field[nt]
	if best == -1:
		_release_except(unit_id, cur, cur)
		return from
	_hold(unit_id, best)
	# The swap: the tile behind is freed only once the unit's rounded position has moved onto the tile
	# it was walking into, so the two-tile hold is never wider than two.
	_release_except(unit_id, cur, best)
	return Vector2(best % w, best / w)


## Every tile this unit holds goes back. Called on death and on boarding.
##
## Rescans `reserved` in full rather than walking `_held`: `battle` may write `reserved` directly when
## it places a landing soldier, and a tile that never entered `_held` would stay locked for the rest of
## the island with no unit standing on it.
func release_all(unit_id: int) -> void:
	for t in reserved.size():
		if reserved[t] == unit_id:
			reserved[t] = -1
	_held.erase(unit_id)


## Claims `tile` unless someone else already holds it. A tile already marked with this unit's id but
## missing from `_held` is adopted, so a direct write by `battle` still gets released later.
func _hold(unit_id: int, tile: int) -> void:
	if reserved[tile] != -1 and reserved[tile] != unit_id:
		return
	reserved[tile] = unit_id
	var held: Array = _held.get(unit_id, [])
	if not held.has(tile):
		held.append(tile)
	_held[unit_id] = held


func _release_except(unit_id: int, keep_a: int, keep_b: int) -> void:
	if not _held.has(unit_id):
		return
	var kept := []
	for raw in _held[unit_id]:
		var tile := int(raw)
		if tile == keep_a or tile == keep_b:
			if not kept.has(tile):
				kept.append(tile)
			continue
		if reserved[tile] == unit_id:
			reserved[tile] = -1
	_held[unit_id] = kept
