# **Three quads crossed through each other, wearing the picture of the same clump.**
#
# It does not turn: the bush has a real footprint, so the sun throws a real shadow of it and the
# camera may move without the bush swivelling.
extends RefCounted

const C := preload("res://.prototypes/bush/common.gd")


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for yaw in [0.0, 60.0, 120.0]:
		C.quad(st, yaw)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://.prototypes/bush/02-quads/quads.gdshader")
	mat.set_shader_parameter("card", C.card_tex())
	var holder := Node3D.new()
	for t in C.spots(lab):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.transform = t
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mi.extra_cull_margin = 0.5
		holder.add_child(mi)
	lab.collect(mat)
	return holder
