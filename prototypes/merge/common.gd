# **The shapes every version of this set draws, in one place.**
#
# All four mechanisms move between the same two shapes: **the 판 as it rests** (one per 조각, a gutter
# all round) and **the 판 merged** (the four in a 칸 filling that 칸's inner square, so the seams inside
# it are gone). What differs is HOW they get from one to the other, and that is what the set is for.
#
# ⚠ **A throwaway.** The shipped 판 is baked in Blender; these are built in GDScript so four mechanisms
# can be on screen in an hour. **The winner gets rebuilt in the bake.**
## ⚠ **No `class_name`.** A throwaway does not put a global symbol in the project; every version
## reaches it with `preload`.
extends RefCounted

## The gutter as it rests, per side, in 조각. **The bake's own `PAD_GAP_IN`.**
const GUT := 0.22
## The bigger pull-back where the land stops, again the bake's number.
const COAST := 0.30
const R_IN := 0.16
const R_OUT := 0.30
const ARC := 3
## How far above the walking surface a 판 floats.
const LIFT := 0.02


## **Every walkable, non-stair 조각 on the board.** Same test the game's `_wash_cells` makes.
static func pad_tiles(grid) -> Array:
	var out: Array = []
	for ty in grid.h:
		for tx in grid.w:
			var t: int = ty * grid.w + tx
			if grid.passable[t] != 1:
				continue
			if Grid.is_stair_level(grid.level_of(t)):
				continue
			out.append(Vector2i(tx, ty))
	return out


static func walkable(grid, tx: int, ty: int) -> bool:
	return grid.is_passable(tx, ty)


## **Which sides of this 조각 face the other three in its 칸.** Returns [west, east, north, south] as
## booleans -- north is -z, south is +z, the same way the tile grid runs.
static func inner_sides(tx: int, ty: int) -> Array:
	var e := (tx % 2) == 0
	var s := (ty % 2) == 0
	return [not e, e, not s, s]


## **The 판's outline at rest, and the same outline merged**, as two rings with matching point counts.
## ⚠⚠ **The correspondence is the whole trick**: point `i` of one is point `i` of the other, so a
## version may simply move each vertex from one to the other and get the merge for free.
static func rings(grid, tx: int, ty: int) -> Array:
	var open_w := not walkable(grid, tx - 1, ty)
	var open_e := not walkable(grid, tx + 1, ty)
	var open_n := not walkable(grid, tx, ty - 1)
	var open_s := not walkable(grid, tx, ty + 1)
	var inner: Array = inner_sides(tx, ty)
	var rest_in := [
		COAST if open_w else GUT, COAST if open_e else GUT,
		COAST if open_n else GUT, COAST if open_s else GUT,
	]
	# Merged: the sides facing into the 칸 close up entirely. Everything else stays where it was.
	var merged_in := rest_in.duplicate()
	for i in 4:
		if inner[i]:
			merged_in[i] = 0.0
	# A corner is square when either of the two sides it joins has closed.
	var rest_r := [R_IN, R_IN, R_IN, R_IN]
	var merged_r: Array = []
	# ⚠ **Corner order is `_ring`'s own**: SE(+x,+z), SW(-x,+z), NW(-x,-z), NE(+x,-z). Sides are
	# [w, e, n, s]. Getting this pairing wrong rounds the wrong corner and nothing errors.
	var pairs := [[1, 3], [0, 3], [0, 2], [1, 2]]
	for i in 4:
		var a: int = pairs[i][0]
		var b: int = pairs[i][1]
		rest_r[i] = R_OUT if (open_side(rest_in, a) or open_side(rest_in, b)) else R_IN
		merged_r.append(0.0 if (inner[a] or inner[b]) else rest_r[i])
	return [_ring(tx, ty, rest_in, rest_r), _ring(tx, ty, merged_in, merged_r)]


static func open_side(insets: Array, i: int) -> bool:
	return float(insets[i]) >= COAST - 0.0001


## One rounded rectangle inside the 조각. `insets` is [w, e, n, s]; `radii` is [NE, NW, SW, SE].
static func _ring(tx: int, ty: int, insets: Array, radii: Array) -> PackedVector2Array:
	var x0: float = float(tx) + float(insets[0])
	var x1: float = float(tx) + 1.0 - float(insets[1])
	var z0: float = float(ty) + float(insets[2])
	var z1: float = float(ty) + 1.0 - float(insets[3])
	var corners := [Vector2(x1, z1), Vector2(x0, z1), Vector2(x0, z0), Vector2(x1, z0)]
	var out := PackedVector2Array()
	for i in 4:
		var c: Vector2 = corners[i]
		var r: float = minf(float(radii[i]), minf((x1 - x0) * 0.5, (z1 - z0) * 0.5))
		var sx: float = 1.0 if c.x > (x0 + x1) * 0.5 else -1.0
		var sz: float = 1.0 if c.y > (z0 + z1) * 0.5 else -1.0
		var a := Vector2(c.x - sx * r, c.y - sz * r)
		# ⚠ **Always ARC+1 points, even at radius zero.** A corner that drops its points would break
		# the point-for-point correspondence the merge rides on.
		var base := [0.0, PI * 0.5, PI, PI * 1.5][i] as float
		for j in ARC + 1:
			var ang: float = base + PI * 0.5 * (float(j) / float(ARC))
			out.append(a + Vector2(cos(ang), sin(ang)) * r)
	return out


## The height a 판 on this 조각 floats at, in world units.
static func pad_y(grid, tx: int, ty: int) -> float:
	return Islands.ground_h(grid.level_at(tx, ty)) + LIFT


## **One flat shape, as a fan.** `move` is where each ring point goes when the merge is complete, and
## it is written into UV2 as a delta -- zero for a version that does not move anything.
##
## ⚠⚠ **`tile` goes into UV and every version needs it**: it is how a shader knows whether it is the
## 조각 the cursor is on, and whether it is in that 조각's 칸. **Not derived from the vertex position** --
## once the merge closes an inner side, the points there sit exactly on the tile boundary and half of
## them floor into the neighbour.
static func fan(st: SurfaceTool, tile: Vector2i, ring: PackedVector2Array, moved: PackedVector2Array,
				y: float, col: Color) -> void:
	var n := ring.size()
	var mid := Vector2.ZERO
	var mid_moved := Vector2.ZERO
	for i in n:
		mid += ring[i]
		mid_moved += moved[i]
	mid /= float(n)
	mid_moved /= float(n)
	var uv := Vector2(float(tile.x), float(tile.y))
	for i in n:
		var j := (i + 1) % n
		_v(st, uv, mid, mid_moved - mid, y, col)
		_v(st, uv, ring[i], moved[i] - ring[i], y, col)
		_v(st, uv, ring[j], moved[j] - ring[j], y, col)


static func _v(st: SurfaceTool, uv: Vector2, p: Vector2, d: Vector2, y: float, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.set_uv2(d)
	st.add_vertex(Vector3(p.x, y, p.y))


## The node a version hands back for one mesh: no shadow, one material, one draw call.
static func mesh_node(st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## **The one tone every version wears.** ⚠ Fixed on purpose: the tone is ticket 33's question and a
## version that also moved it would be two changes photographed as one.
static func tone() -> Color:
	return Color(1.0, 1.0, 0.93, 0.42)
