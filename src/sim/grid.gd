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
## **The coastline is open, not docked.** `boat-and-landing`, section 3, replaces the old fixed-dock
## legend with harbours (`H`, plural, water tiles a boat sails from and returns to) and a `landable`
## predicate any passable shore tile can satisfy. `can_land_at(harbour, tile)` is the one rule that
## decides where a boat may go, and `home_harbour_for` — which is `can_land_at` filtered and then
## nearest — is what both the droppable overlay and `Battle.send` answer to, so the screen cannot
## promise a tile the sim refuses.


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

## 4-way, used ONLY by `landable` (3.3 of the plan): a tile touching water only at a corner is not
## landable, because coming ashore there reads as landing on the rock beside it. `NEIGHBOURS` above
## stays 8-way for movement and reservation, which is a different question.
const ORTHO := [[0, -1], [0, 1], [-1, 0], [1, 0]]

## The straight-line sampler's step and its landing-end exemption both live in `rules.gd`
## (`Rules.LINE_SAMPLE_STEP`, `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV`), not here — a coarser step
## ACCEPTS targets a finer one refuses, so it changes what happens rather than how this file is
## structured, and `CLAUDE.md`'s folder contract gives every constant that changes what happens to
## `rules.gd` alone.

var w: int = 0
var h: int = 0
var passable := PackedByteArray()      # w*h, 1 = walkable (includes a ramp)
var water := PackedByteArray()         # w*h, 1 = water (includes a harbour)
var landable := PackedByteArray()      # w*h, 1 = passable AND orthogonally beside water
var harbour_tiles := PackedInt32Array()   # row-major order — this defines harbour index
## `sendable[hb][t]` = 1 iff a boat at harbour `hb` may be sent to tile `t` — landable AND the straight
## line from that harbour does not cross land. Filled ONCE per harbour inside `load_rows`; `can_land_at`
## only ever reads it back. See 3.5: computed live it would be 1536 tiles * ~500 samples a FRAME.
var sendable: Array = []               # Array of PackedByteArray, one per harbour
## The harbour whose nearest reachable coast tile is farthest away, ties to the lowest tile index (which
## is also the lowest harbour index, since `harbour_tiles` is row-major). -1 on an empty grid.
var start_harbour: int = -1
## Every call to `water_line_clear`, ever. A net asserts this does not move across pumped frames once
## `load_rows` has run — the straight-line test is a load-time cost, not a per-frame one.
var line_tests: int = 0

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
	line_tests = 0

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

	landable = PackedByteArray()
	landable.resize(n)
	for t in n:
		if passable[t] == 0:
			continue
		var tx := t % w
		var ty := t / w
		for k in ORTHO.size():
			var nx := tx + int(ORTHO[k][0])
			var ny := ty + int(ORTHO[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if water[ny * w + nx] != 0:
				landable[t] = 1
				break

	sendable = []
	for hb in harbour_tiles.size():
		var arr := PackedByteArray()
		arr.resize(n)
		var origin := tile_point(int(harbour_tiles[hb]))
		for t in n:
			if landable[t] == 0:
				continue
			if water_line_clear(origin, tile_point(t)):
				arr[t] = 1
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
## `sendable` table filled once in `load_rows` — never recomputes a straight line here.** That split is
## what makes `line_tests` flat across a pumped frame; recomputed per call at 1536 tiles a frame it would
## be a real wall (3.5 of the plan).
func can_land_at(harbour_idx: int, t: int) -> bool:
	if harbour_idx < 0 or harbour_idx >= sendable.size():
		return false
	var arr: PackedByteArray = sendable[harbour_idx]
	if t < 0 or t >= arr.size():
		return false
	return arr[t] != 0


## The straight line from world point `a` to world point `b` does not cross land, sampled every
## `Rules.LINE_SAMPLE_STEP` tiles and rounded to the nearest tile — fine enough that a one-tile wall
## cannot be stepped over. Tiles within `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV` of `b` are exempt (see
## that constant's comment): grazing the beach beside the target is not sailing over the island.
##
## Public, and not folded away inside `load_rows`, because `net_coast` drives this directly to pin the
## sampler's own geometry — the cached path above is what a caller in the running game actually uses.
func water_line_clear(a: Vector2, b: Vector2) -> bool:
	line_tests += 1
	var dist := a.distance_to(b)
	if dist <= 0.0:
		return true
	var steps := int(ceil(dist / Rules.LINE_SAMPLE_STEP))
	var bx := int(round(b.x))
	var by := int(round(b.y))
	for s in range(steps + 1):
		var f := float(s) / float(steps)
		var p := a.lerp(b, f)
		var tx := int(round(p.x))
		var ty := int(round(p.y))
		if maxi(absi(tx - bx), absi(ty - by)) <= Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV:
			continue
		if tx < 0 or ty < 0 or tx >= w or ty >= h:
			return false
		if water[ty * w + tx] == 0:
			return false
	return true


## The harbour nearest `landing` AMONG the harbours that can still see it (`can_land_at(h, landing)`),
## ties to the lowest index. **The set is never empty when `landing` was ever sendable at all** — the
## boat sailed from one such harbour, so at worst it stays put. Returns -1 only when NO harbour can see
## the tile, which a caller should never pass in (the boat could not have landed there to begin with).
##
## The naive "nearest harbour, full stop" strands a beachhead behind a headland the nearest harbour
## cannot see (measured: 2 of 46 beachheads on island 3) — the `can_land_at` filter is what makes that
## unrepresentable.
func home_harbour_for(landing: int) -> int:
	var best := -1
	var best_d := 0.0
	for hb in harbour_tiles.size():
		if not can_land_at(hb, landing):
			continue
		var d: float = tile_point(int(harbour_tiles[hb])).distance_to(tile_point(landing))
		if best == -1 or d < best_d - Rules.EPS:
			best = hb
			best_d = d
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
