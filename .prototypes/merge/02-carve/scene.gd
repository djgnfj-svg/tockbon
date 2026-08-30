# **The mesh is one flat 조각; the shader carves the 판 out of it.**
#
# **Where the merge comes from**: the gutter is a NUMBER the fragment stage owns rather than a shape
# that was baked, so closing it costs nothing and moves nothing. The quad is the whole 조각 and every
# visible edge is a cut.
extends RefCounted

const C := preload("res://.prototypes/merge/common.gd")


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in C.pad_tiles(lab.grid):
		var y: float = C.pad_y(lab.grid, t.x, t.y)
		# The resting inset per side, in the shader's own order: west, east, north, south.
		var ins := Color(
			C.COAST if not C.walkable(lab.grid, t.x - 1, t.y) else C.GUT,
			C.COAST if not C.walkable(lab.grid, t.x + 1, t.y) else C.GUT,
			C.COAST if not C.walkable(lab.grid, t.x, t.y - 1) else C.GUT,
			C.COAST if not C.walkable(lab.grid, t.x, t.y + 1) else C.GUT)
		_quad(st, t.x, t.y, y, ins)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://.prototypes/merge/02-carve/carve.gdshader")
	mat.set_shader_parameter("pad_tone", C.tone())
	mat.set_shader_parameter("radius", C.R_IN)
	var holder := Node3D.new()
	holder.add_child(C.mesh_node(st, mat))
	return holder


## One whole 조각, UV running 0..1 across it so the shader knows where it is, and **UV2 carrying the
## tile index** -- which quarter of its 칸 this is, and whether the cursor is on it, both come from that.
static func _quad(st: SurfaceTool, tx: int, ty: int, y: float, ins: Color) -> void:
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var tile := Vector2(float(tx), float(ty))
	for i in [0, 1, 2, 0, 2, 3]:
		var u: Vector2 = corners[i]
		st.set_color(ins)
		st.set_normal(Vector3.UP)
		st.set_uv(u)
		st.set_uv2(tile)
		st.add_vertex(Vector3(float(tx) + u.x, y, float(ty) + u.y))
