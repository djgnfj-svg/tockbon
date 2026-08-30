# **02-ribbon — a strip of triangles that grows at the stern and dies at the tail.**
#
# One row of two vertices per remembered stern position; consecutive rows are joined into quads. The
# strip is rebuilt whole every frame, which is what a throwaway does — a shipped one would push only the
# new row.
#
# ⚠⚠ **The rows are laid out on each sample's OWN heading, and that is where this mechanism breaks.**
# On a quarter turn in a second the inside edge of the strip turns faster than the strip is long, the
# two sides cross, and the triangles between them fold inside out. **It is not hidden in the picture.**
extends RefCounted

const Common := preload("res://.prototypes/wake/common.gd")

## How far the stern moves before another row is remembered, in 조각. ⚠ **Coarser than the step**: a
## row per frame is 435 rows on a 7-second crossing and the strip is no smoother for it.
const EVERY := 0.22
const ALPHA := 0.85
const FROTH_SCALE := 2.6
const FROTH_AMT := 0.55

var _node: MeshInstance3D = null
var _mat: ShaderMaterial = null
## Each row is `[Vector2 stern, Vector2 head, float born]`.
var _rows: Array = []


func build(world: Node3D, boat: Node3D) -> void:
	_node = Common.fx_layer(world)
	_mat = Common.fx_material("res://.prototypes/wake/02-ribbon/ribbon.gdshader")
	_mat.set_shader_parameter("col", Color(0.900, 0.940, 0.950, ALPHA))
	_mat.set_shader_parameter("froth_scale", FROTH_SCALE)
	_mat.set_shader_parameter("froth_amt", FROTH_AMT)
	_node.material_override = _mat
	reset()


func reset() -> void:
	_rows.clear()
	if _node != null:
		_node.mesh = null


func step(dt: float, t: float, pos: Vector2, head: Vector2) -> void:
	var stern := Common.stern_of(pos, head)
	if _rows.is_empty() or (stern - (_rows[-1][0] as Vector2)).length() >= EVERY:
		_rows.append([stern, head, t])
	while not _rows.is_empty() and t - float(_rows[0][2]) > Common.LIFE:
		_rows.pop_front()


func present(t: float, mat: ShaderMaterial) -> void:
	if _node == null:
		return
	if _rows.size() < 2:
		_node.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var prev: Vector2 = _rows[0][0]
	# Two vertices per row, then a quad between every neighbouring pair.
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var fade := PackedFloat32Array()
	var v := PackedFloat32Array()
	for r in _rows:
		var p: Vector2 = r[0]
		var head: Vector2 = r[1]
		var age: float = t - float(r[2])
		var w: float = Common.HALF_W + Common.SPREAD * Common.SPEED * age
		var perp := Vector2(-head.y, head.x)
		along += (p - prev).length()
		prev = p
		left.append(Vector3(p.x + perp.x * w, 0.0, p.y + perp.y * w))
		right.append(Vector3(p.x - perp.x * w, 0.0, p.y - perp.y * w))
		fade.append(clampf(1.0 - age / Common.LIFE, 0.0, 1.0))
		v.append(along)
	for i in range(left.size() - 1):
		_quad(st, left[i], right[i], left[i + 1], right[i + 1],
			  fade[i], fade[i + 1], v[i], v[i + 1])
	_node.mesh = st.commit()


func _quad(st: SurfaceTool, l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3,
		   f0: float, f1: float, v0: float, v1: float) -> void:
	var pts := [l0, r0, r1, l0, r1, l1]
	var uvs := [Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1),
				Vector2(0.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)]
	var fs := [f0, f0, f1, f0, f1, f1]
	for k in 6:
		st.set_color(Color(1, 1, 1, fs[k]))
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[k])


func teardown() -> void:
	if _node != null:
		_node.queue_free()
		_node = null
