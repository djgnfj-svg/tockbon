# **The 판 grows into its neighbours.**
#
# **Where the merge comes from**: the VERTICES move. Every ring point carries, in `UV2`, the delta from
# where it rests to where it stands when the 칸 is one lump; the vertex stage walks it along that delta
# by `merge`. Nothing is faded, nothing is swapped -- there is one mesh and it changes shape.
extends RefCounted

const C := preload("res://.prototypes/merge/common.gd")


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in C.pad_tiles(lab.grid):
		var pair: Array = C.rings(lab.grid, t.x, t.y)
		C.fan(st, t, pair[0], pair[1], C.pad_y(lab.grid, t.x, t.y), C.tone())
	var mat := ShaderMaterial.new()
	mat.shader = load("res://.prototypes/merge/01-grow/grow.gdshader")
	var holder := Node3D.new()
	holder.add_child(C.mesh_node(st, mat))
	return holder
