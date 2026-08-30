# **The Bad North package, all of it: a turning card, no shadow, and an offset silhouette for ink.**
#
# Taking the billboard without the package is what the research note warns against, so this candidate
# takes the package. ⚠ **Two draws per bush** -- the dark copy pushed back and swollen, then the card.
extends RefCounted

const C := preload("res://.prototypes/bush/common.gd")


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	C.quad(st, 0.0)
	var mesh := st.commit()
	var card := ShaderMaterial.new()
	card.shader = load("res://.prototypes/bush/03-badnorth/card.gdshader")
	card.set_shader_parameter("card", C.card_tex())
	card.set_shader_parameter("silhouette", false)
	var ink := ShaderMaterial.new()
	ink.shader = card.shader
	ink.set_shader_parameter("card", C.card_tex())
	ink.set_shader_parameter("silhouette", true)
	ink.set_shader_parameter("ink", Look.COL_OUTLINE)
	var holder := Node3D.new()
	for t in C.spots(lab):
		for m in [ink, card]:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = m
			mi.transform = t
			# **No shadow, on purpose.** A card's shadow is the shadow of a plane that keeps turning,
			# and Bad North does not cast one at all -- it bakes its light into a 3D texture instead.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 0.6
			holder.add_child(mi)
	lab.collect(card)
	lab.collect(ink)
	return holder
