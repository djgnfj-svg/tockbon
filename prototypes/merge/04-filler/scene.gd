# **The 판 never change. The seams between them get filled in.**
#
# **Where the merge comes from**: a second, separate piece per seam — a bar laid over the gutter between
# two 조각 of the same 칸 — which is invisible up close and fades in as the camera pulls back. The
# resting board is untouched, and nothing about it has to know this exists.
extends RefCounted

const C := preload("res://prototypes/merge/common.gd")

## How far past the gutter each bar reaches, so its edge lands under the 판 rather than beside it.
const OVER := 0.03


static func build(lab) -> Node3D:
	var pads := SurfaceTool.new()
	pads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in C.pad_tiles(lab.grid):
		var pair: Array = C.rings(lab.grid, t.x, t.y)
		var y: float = C.pad_y(lab.grid, t.x, t.y)
		C.fan(pads, t, pair[0], pair[0], y, C.tone())
		# **East and south only**, so each seam inside a 칸 is written once.
		var inner: Array = C.inner_sides(t.x, t.y)
		if inner[1] and C.walkable(lab.grid, t.x + 1, t.y):
			_bar(seams, t, Vector2(float(t.x + 1) - C.GUT - OVER, float(t.y) + C.GUT),
				 Vector2(float(t.x + 1) + C.GUT + OVER, float(t.y) + 1.0 - C.GUT), y)
		if inner[3] and C.walkable(lab.grid, t.x, t.y + 1):
			_bar(seams, t, Vector2(float(t.x) + C.GUT, float(t.y + 1) - C.GUT - OVER),
				 Vector2(float(t.x) + 1.0 - C.GUT, float(t.y + 1) + C.GUT + OVER), y)
	var holder := Node3D.new()
	holder.add_child(C.mesh_node(pads, _mat(0)))
	holder.add_child(C.mesh_node(seams, _mat(1)))
	return holder


## One flat bar over a seam. ⚠ **Two bars crossing cover the little hole where four 판 meet**, so no
## third piece is needed at the centre of a 칸.
static func _bar(st: SurfaceTool, tile: Vector2i, lo: Vector2, hi: Vector2, y: float) -> void:
	var pts := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
	# ⚠ **A bar wears the tile it was written from**, so it lights with that 조각's own 칸.
	var uv := Vector2(float(tile.x), float(tile.y))
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = pts[i]
		st.set_color(C.tone())
		st.set_normal(Vector3.UP)
		st.set_uv(uv)
		st.set_uv2(Vector2.ZERO)
		st.add_vertex(Vector3(p.x, y, p.y))


## `mode` 0 is always on, 1 fades in as the camera pulls back.
static func _mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://prototypes/merge/04-filler/fade.gdshader")
	m.set_shader_parameter("mode", mode)
	return m
