# **07 — the shoreline is GEOMETRY, not a shader term.**
#
# ⚠⚠ **Nothing in the water shader knows where the land is.** The shore is a strip of quads built from
# the waterline polygon, laid flat on the sea, and pushed outward over time. Four of them ride at
# different phases, so one is always leaving the rock while another is halfway out and a third is fading.
#
# This is the shape a particle system or a decal would take, and it is on the sheet because it is the one
# family of answers that **is not a shader at all**: the shoreline is a thing in the world, so it can be
# spawned where a boat lands, cut where a jetty is built, or removed entirely.
extends RefCounted

## How many strips ride at once, and how far each travels before it is gone, in tiles.
const RINGS := 4
const TRAVEL := 0.55
const SPEED := 0.22
## The strip's own thickness, in tiles.
const THICK := 0.085
## ⚠ Above the sea, or the strip and the sea fight for the depth buffer and the shore draws as stipple.
const LIFT := 0.004


static func build(lab) -> Node3D:
	var line: PackedVector2Array = lab.waterline()
	if line.size() < 3:
		return null
	var mid := Vector2(lab.S, lab.S) * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := line.size()
	for r in RINGS:
		# Each strip's own place in the cycle. ⚠ Carried in UV.x so the shader can advance them all with
		# one clock rather than one material per strip.
		var phase := float(r) / float(RINGS)
		for i in n:
			var j := (i + 1) % n
			var a: Vector2 = line[i]
			var b: Vector2 = line[j]
			var na: Vector2 = (a - mid).normalized()
			var nb: Vector2 = (b - mid).normalized()
			var a0 := a
			var a1 := a + na * THICK
			var b0 := b
			var b1 := b + nb * THICK
			# ⚠ **The outward direction travels WITH the vertex**, in the vertex colour: the strip has to
			# know which way to move, and it is different at every point of a closed ring.
			_v(st, a0, na, phase, 0.0)
			_v(st, a1, na, phase, 1.0)
			_v(st, b1, nb, phase, 1.0)
			_v(st, a0, na, phase, 0.0)
			_v(st, b1, nb, phase, 1.0)
			_v(st, b0, nb, phase, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position.y = lab.SEA_Y + LIFT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load("res://prototypes/shoreline/07-rings/rings.gdshader")
	m.set_shader_parameter("travel", TRAVEL)
	m.set_shader_parameter("speed", SPEED)
	mi.material_override = m
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder


static func _v(st: SurfaceTool, p: Vector2, outw: Vector2, phase: float, across: float) -> void:
	# The outward direction is packed 0..1 because a vertex colour cannot hold a negative.
	st.set_color(Color(outw.x * 0.5 + 0.5, outw.y * 0.5 + 0.5, 0.0, 1.0))
	st.set_uv(Vector2(phase, across))
	st.add_vertex(Vector3(p.x, 0.0, p.y))
