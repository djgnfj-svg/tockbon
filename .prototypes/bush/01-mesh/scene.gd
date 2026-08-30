# **Real geometry, the island's own outline, the island's own shadow.**
#
# The clump is the baked mesh. The leaves bend because their vertices move, weighted by what the bake
# wrote into vertex alpha. The outline is the same inverted hull the island wears, and it sways with
# the mesh so the ink stays on the leaves.
extends RefCounted

const C := preload("res://.prototypes/bush/common.gd")


static func build(lab) -> Node3D:
	var mesh := C.bush_mesh()
	if mesh == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = load("res://.prototypes/bush/01-mesh/bush.gdshader")
	var hull := ShaderMaterial.new()
	hull.shader = load("res://.prototypes/bush/01-mesh/hull.gdshader")
	hull.set_shader_parameter("ink", Look.COL_OUTLINE)
	hull.set_shader_parameter("grow", Look.OUTLINE_GROW)
	mat.next_pass = hull
	var holder := Node3D.new()
	for t in C.spots(lab):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.transform = t
		# ⚠ **The shadow is cast by the swaying shell too**, so it is switched to the double-sided
		# setting rather than left on the default that only casts from front faces.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# The wind pushes vertices outside the mesh's baked box; without this the bush pops out of
		# existence near the screen edge. Every source names this one.
		mi.extra_cull_margin = 0.5
		holder.add_child(mi)
	lab.collect(mat)
	lab.collect(hull)
	return holder
