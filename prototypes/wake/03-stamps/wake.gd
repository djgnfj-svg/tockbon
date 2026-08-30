# **03-stamps — a foam quad dropped at intervals behind the stern, each living its own life.**
#
# No strip, no buffer: a list of positions with a birth time, each drawn as one oval that grows and
# fades. **Nothing joins them** — the ribbon they make is made by the eye.
extends RefCounted

const Common := preload("res://prototypes/wake/common.gd")

## How far the stern moves between two stamps, in 조각. ⚠ **This one number IS the candidate.** Wide
## apart and it is a dotted line; close together and every pixel is under three overlapping alphas.
const EVERY := 0.42
## Half-size of a stamp at birth and how fast it grows, in 조각 and 조각/second. The long axis lies
## along the boat's heading.
const BORN_W := 0.46
const BORN_L := 0.62
const GROW := Common.SPREAD * Common.SPEED
const ALPHA := 0.55
const FROTH_SCALE := 3.4
const FROTH_AMT := 0.60

var _node: MeshInstance3D = null
var _mat: ShaderMaterial = null
## Each stamp is `[Vector2 at, Vector2 head, float born, float seed]`.
var _stamps: Array = []
var _rng := RandomNumberGenerator.new()


func build(world: Node3D, boat: Node3D) -> void:
	_node = Common.fx_layer(world)
	_mat = Common.fx_material("res://prototypes/wake/03-stamps/stamp.gdshader")
	_mat.set_shader_parameter("col", Color(0.900, 0.940, 0.950, ALPHA))
	_mat.set_shader_parameter("froth_scale", FROTH_SCALE)
	_mat.set_shader_parameter("froth_amt", FROTH_AMT)
	_node.material_override = _mat
	reset()


func reset() -> void:
	_stamps.clear()
	# ⚠ **Seeded.** Two runs of the same crossing must put the same froth in the same place, or the
	# sheet is comparing this candidate against itself.
	_rng.seed = 20260830
	if _node != null:
		_node.mesh = null


func step(dt: float, t: float, pos: Vector2, head: Vector2) -> void:
	var stern := Common.stern_of(pos, head)
	if _stamps.is_empty() or (stern - (_stamps[-1][0] as Vector2)).length() >= EVERY:
		_stamps.append([stern, head, t, _rng.randf()])
	while not _stamps.is_empty() and t - float(_stamps[0][2]) > Common.LIFE:
		_stamps.pop_front()


func present(t: float, mat: ShaderMaterial) -> void:
	if _node == null:
		return
	if _stamps.is_empty():
		_node.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# **Oldest first**, so the newest stamp is the last thing laid down.
	for s in _stamps:
		var at: Vector2 = s[0]
		var head: Vector2 = s[1]
		var age: float = t - float(s[2])
		var fade := clampf(1.0 - age / Common.LIFE, 0.0, 1.0)
		var grow := GROW * age
		var half_l := BORN_L + grow
		var half_w := BORN_W + grow
		var perp := Vector2(-head.y, head.x)
		var a := at + head * half_l + perp * half_w
		var b := at + head * half_l - perp * half_w
		var c := at - head * half_l - perp * half_w
		var d := at - head * half_l + perp * half_w
		_quad(st, a, b, c, d, fade, float(s[3]))
	_node.mesh = st.commit()


func _quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2,
		   fade: float, seed_v: float) -> void:
	var pts := [a, b, c, a, c, d]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
				Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in 6:
		st.set_color(Color(seed_v, 0.0, 0.0, fade))
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(pts[k].x, 0.0, pts[k].y))


func teardown() -> void:
	if _node != null:
		_node.queue_free()
		_node = null
