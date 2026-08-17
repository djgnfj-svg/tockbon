class_name Grid
extends RefCounted
## The island's tiles: passability, dock order, per-unit tile reservation, and the BFS flow field
## every unit walks down. Pure data — no Node, no tree, `.new()` is the whole construction.
##
## **Movement is a flow field and never a greedy descent.** Greedy 8-way descent was measured stalling
## on five of twenty-six dock-to-enemy pairs on these three grids, so a walker that "obviously works"
## silently freezes on island 2's north-east crow and everything inside island 3's ring. The first-slice
## plan records the measurement under "What two adversarial passes broke".


## Unreachable tiles carry this instead of a sentinel like -1, so a caller comparing field values with
## `<` treats them as the worst option rather than the best one.
const UNREACHABLE := 1 << 30

## Row legend. Anything not listed is loaded as an impassable hole: validating the legend is
## `net_islands`' job, and a `push_error` here would have to be forgiven by every net that hands this
## function a hand-written fixture.
const LAND_CHARS := ".DBCL"
const DOCK_CHAR := "D"

## 8-way, listed in a fixed order so an equal-cost tie always resolves the same way. Plain `const`
## Arrays: `const X := PackedInt32Array([...])` is a parse error on 4.7, so every read casts.
const NEIGHBOURS := [
	[-1, -1], [0, -1], [1, -1],
	[-1, 0], [1, 0],
	[-1, 1], [0, 1], [1, 1],
]

var w: int = 0
var h: int = 0
var passable := PackedByteArray()      # w*h, 1 = walkable
var dock_tiles := PackedInt32Array()   # in row-major order — this defines dock_index
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
	passable = PackedByteArray()
	passable.resize(w * h)
	reserved = PackedInt32Array()
	reserved.resize(w * h)
	reserved.fill(-1)
	dock_tiles = PackedInt32Array()
	_held = {}
	for y in h:
		var row := String(rows[y])
		for x in w:
			var t := y * w + x
			if x >= row.length():
				passable[t] = 0
				continue
			var c := row[x]
			passable[t] = 1 if LAND_CHARS.find(c) != -1 else 0
			# Append order IS dock_index — `battle.launch(0)` means the first `D` met scanning
			# row-major. Sorting or de-duplicating this list renumbers every dock click.
			if c == DOCK_CHAR:
				dock_tiles.append(t)


func is_passable(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return false
	return passable[ty * w + tx] != 0


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
