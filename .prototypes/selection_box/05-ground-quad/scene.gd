# **05-ground-quad — the pulled frame picture laid FLAT on the island as one textured quad.**
#
# The four terrain hits under the rect's corners (`drag.ground`, TL TR BR BL) become one quad at their
# AVERAGE height plus `Look.FX_GROUND_LIFT_TILES`, textured with `selbox_frame_01` through
# `common.load_ink` (white keyed to alpha). **It ignores height on purpose**: the whole point of this
# candidate is to see what a picture lying on the ground looks like — it turns with the board, it is
# foreshortened by the pitch, and where the ground rises above it (the 2층 tongue at the top edge) the
# terrain's depth hides it, because the material reads depth even though it does not write it — the
# same rule `FieldView._fx_layer` keeps.
#
# ⚠ **`render_priority` is what puts it above the 판**, not the lift — `field_view.gd` measured that on
# 2026-08-31: both are transparent, neither writes depth, and the AABBs tie.
extends RefCounted

const NAME := "05-ground-quad"
const PIC := "res://.candidates/selection_box/selbox_frame_01_seed2137183347_64px.png"

var _node: MeshInstance3D = null


func mount(_game: Node, fv: Node, drag: Dictionary) -> void:
	var common: GDScript = load("res://.prototypes/selection_box/common.gd")
	var tex: ImageTexture = common.load_ink(PIC)
	var g: PackedVector3Array = drag["ground"]
	if g.size() < 4:
		push_error("05-ground-quad: drag.ground has %d points, need 4" % g.size())
		return
	# **One height for the whole plate**: the mean of the four corners, lifted so the ground does not
	# z-fight through it. This is the line that makes it dive under a cliff and float over a dip.
	var y := (g[0].y + g[1].y + g[2].y + g[3].y) * 0.25 + Look.FX_GROUND_LIFT_TILES
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var n := PackedVector3Array()
	var corners := [g[0], g[1], g[2], g[3]]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in 4:
		var c: Vector3 = corners[k]
		v.append(Vector3(c.x, y, c.z))
		uv.append(uvs[k])
		n.append(Vector3.UP)
	# Two triangles, TL-TR-BR and TL-BR-BL. Culling is off so the winding does not matter.
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth is read, not written — a cliff in front hides it; nothing sorts behind it.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	# Above the 판 (priority 1 in `_fx_layer`) and above the 이동선.
	mat.render_priority = 2

	_node = MeshInstance3D.new()
	_node.name = "SelBoxGroundQuad"
	_node.mesh = mesh
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fv._world.add_child(_node)
	print("[05-ground-quad] quad at y=%.3f, corners TL=%s TR=%s BR=%s BL=%s, tex=%s" % [
		y, str(g[0]), str(g[1]), str(g[2]), str(g[3]),
		"%dx%d" % [tex.get_width(), tex.get_height()] if tex != null else "null"])


func unmount() -> void:
	if _node != null:
		if _node.get_parent() != null:
			_node.get_parent().remove_child(_node)
		_node.queue_free()
		_node = null


func lines() -> PackedStringArray:
	return PackedStringArray([
		"buys — a pulled picture, one quad, one draw; it lies on the island and turns with the board at yaw 90",
		"costs — foreshortened by the pitch; the 64 px frame is stretched 7.2 x 5.1 조각 so its stroke thickens on the long sides and thins with zoom",
		"cannot — cannot follow height: one flat plate at the mean corner height goes UNDER the 2층 tongue and its cliff face clips the edge (measured in both shots), it runs out over the inlet water, and it would float over a dip; cannot stay screen-crisp",
	])
