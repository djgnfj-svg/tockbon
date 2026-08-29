# **The ground itself says it: walkable land wears a patchy turf, and nothing else is drawn.**
#
# **Where the mark comes from**: a TEXTURE over the walking surface, not a shape. There is no square,
# no rim and no 칸 — the speckle simply stops where the walkable land stops.
#
# ⚠ This is Bad North's own answer, in the developer's words: the ground between levels is drawn
# ***"way patchier than the rest of the grass... that mark out the places where you can navigate"***,
# and the unwalkable ground gets forests instead. **The player reads terrain, never an overlay.**
#
# ⚠ **A shipped version would bake this into the island's vertex colours**, which is what makes it
# free. Here it is a layer floating 0.02 over the ground because a prototype may not re-bake the
# island for every idea.
extends RefCounted


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for ty in lab.grid.h:
		for tx in lab.grid.w:
			if not lab.walkable(tx, ty):
				continue
			any = true
			var c := Vector3(float(tx) + 0.5, lab.tile_y(tx, ty), float(ty) + 0.5)
			# ⚠ **Full tiles, edge to edge.** The speckle is what breaks the square up; a gap here
			# would put a grid back on screen through the back door.
			lab.lay_quad(st, c, 1.0, 1.0, Color(1, 1, 1, 1))
	if not any:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://prototypes/pads/02-turf/turf.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder
