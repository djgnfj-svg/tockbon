# **Two boards, and the camera decides which one you are looking at.**
#
# **Where the merge comes from**: nowhere — there is no merge. **Both boards are built up front**, the
# 조각 판 and the 칸 판, and one fades out as the other fades in. Nothing is ever half-merged; you are
# always looking at a finished board.
extends RefCounted

const C := preload("res://.prototypes/merge/common.gd")


static func build(lab) -> Node3D:
	var near := SurfaceTool.new()
	near.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far := SurfaceTool.new()
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in C.pad_tiles(lab.grid):
		var pair: Array = C.rings(lab.grid, t.x, t.y)
		var y: float = C.pad_y(lab.grid, t.x, t.y)
		C.fan(near, t, pair[0], pair[0], y, C.tone())
		# ⚠ **The far board is the four merged quarters, not one big rounded square.** They tile the
		# 칸's inner square exactly, so a 칸 the land does not fill still comes out the right shape.
		C.fan(far, t, pair[1], pair[1], y, C.tone())
	var holder := Node3D.new()
	holder.add_child(C.mesh_node(near, _mat(2)))
	holder.add_child(C.mesh_node(far, _mat(1)))
	return holder


## `mode` 1 fades in as the camera pulls back, 2 fades out.
static func _mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://.prototypes/merge/03-crossfade/fade.gdshader")
	m.set_shader_parameter("mode", mode)
	return m
