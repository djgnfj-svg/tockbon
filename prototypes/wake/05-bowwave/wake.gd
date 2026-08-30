# **05-bowwave — a V of foam at the bow, welded to the boat, and nothing behind it.**
#
# **The honest "do less" candidate.** Sea of Thieves ships with no persistent wake at all: what a ship
# has is foam where the hull meets water, and the water it has left is water again.
#
# The mesh is built ONCE and never rebuilt. `step` does nothing. There is no history, no buffer and no
# per-frame geometry — and if the boat stops, so does this.
extends RefCounted

const Common := preload("res://prototypes/wake/common.gd")

## Where the V starts and how far aft each arm runs, in 조각, and how far out it opens.
## ⚠ **The angle and the length were 26° and 4.2 for one round and the V never came out from under the
## hull.** `boat.glb` is 5.2 조각 long and 1.9 wide, so an arm that opens slower than the hull does is an
## arm drawn inside the boat's own silhouette and occluded by it.
const BOW_X := 2.30
const ARM_LEN := 5.60
const ARM_ANGLE := 34.0
## Half-width of an arm at the bow and at its tail.
const ARM_W0 := 0.18
const ARM_W1 := 0.62
## The froth the transom drags, right behind the hull and no further.
const STERN_L := 1.10
const STERN_W := 0.62
const SEGS := 10
const ALPHA := 0.90
const FROTH_SCALE := 3.0
const FROTH_AMT := 0.45

var _node: MeshInstance3D = null
## Where the hull is NOW, and nothing else. ⚠ **This is not history** — it is one transform, replaced
## every step, which is exactly what makes this candidate cost nothing and leave nothing.
var _pos := Vector2.ZERO
var _head := Vector2(1.0, 0.0)


## ⚠ **Not a child of the boat node.** The hull bobs and rolls; a flat sheet of foam that rolled with it
## would lift out of the water on one side. This follows the boat's PLACE and its heading only.
func build(world: Node3D, boat: Node3D) -> void:
	_node = Common.fx_layer(world)
	var mat := Common.fx_material("res://prototypes/wake/05-bowwave/bow.gdshader")
	mat.set_shader_parameter("col", Color(0.900, 0.940, 0.950, ALPHA))
	mat.set_shader_parameter("froth_scale", FROTH_SCALE)
	mat.set_shader_parameter("froth_amt", FROTH_AMT)
	_node.material_override = mat
	_node.mesh = _build_v()


func reset() -> void:
	pass


func step(dt: float, t: float, pos: Vector2, head: Vector2) -> void:
	_pos = pos
	_head = head


func present(t: float, mat: ShaderMaterial) -> void:
	if _node == null:
		return
	# ⚠ **The bob is added as a constant, not as the hull's own bob.** A sheet of foam that rose and
	# fell with the hull would sink under the water on every down beat; this rides at the top of the
	# hull's travel and stays there.
	_node.position = Vector3(_pos.x, Common.SEA_Y + Common.LIFT + Common.BOAT_BOB_TILES, _pos.y)
	_node.rotation = Vector3(0.0, Common.yaw_of(_head), 0.0)


## The V, in the hull's own space: +X is the bow, +Z is to starboard.
func _build_v() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := deg_to_rad(ARM_ANGLE)
	for side in [1.0, -1.0]:
		var dir := Vector2(-cos(a), side * sin(a))
		for i in SEGS:
			var t0 := float(i) / float(SEGS)
			var t1 := float(i + 1) / float(SEGS)
			_rung(st, dir, t0, t1)
	_stern(st)
	return st.commit()


func _rung(st: SurfaceTool, dir: Vector2, t0: float, t1: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var c0 := Vector2(BOW_X, 0.0) + dir * (ARM_LEN * t0)
	var c1 := Vector2(BOW_X, 0.0) + dir * (ARM_LEN * t1)
	var w0: float = lerpf(ARM_W0, ARM_W1, t0)
	var w1: float = lerpf(ARM_W0, ARM_W1, t1)
	# The arm is brightest a third of the way back and gone at the tail.
	var f0: float = smoothstep(0.0, 0.12, t0) * (1.0 - smoothstep(0.55, 1.0, t0))
	var f1: float = smoothstep(0.0, 0.12, t1) * (1.0 - smoothstep(0.55, 1.0, t1))
	var pts := [c0 + perp * w0, c0 - perp * w0, c1 - perp * w1, c1 + perp * w1]
	var fs := [f0, f0, f1, f1]
	var uvs := [Vector2(0.0, t0), Vector2(1.0, t0), Vector2(1.0, t1), Vector2(0.0, t1)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			st.set_color(Color(1, 1, 1, fs[k]))
			st.set_uv(uvs[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(pts[k].x, 0.0, pts[k].y))


## The transom's own froth: one short patch that ends where the hull ends.
func _stern(st: SurfaceTool) -> void:
	var back := Common.STERN_X
	var pts := [Vector2(back, STERN_W), Vector2(back, -STERN_W),
				Vector2(back - STERN_L, -STERN_W * 0.7), Vector2(back - STERN_L, STERN_W * 0.7)]
	var fs := [0.85, 0.85, 0.0, 0.0]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			st.set_color(Color(1, 1, 1, fs[k]))
			st.set_uv(uvs[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(pts[k].x, 0.0, pts[k].y))


func teardown() -> void:
	if _node != null:
		_node.queue_free()
		_node = null
