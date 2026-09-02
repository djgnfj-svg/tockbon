# **04-ground-decal — the drag box PROJECTED ONTO THE TERRAIN, following its height.**
#
# The rect is a screen thing at the moment of the drag; this candidate asks the ground what lies under
# it. Every `STEP_PX` along the rect's four edges a screen point is thrown through the field's own
# `screen_to_terrain_px` — the same near-to-far ray walk a press goes through, which is how the lab
# derived `drag.ground` — and the outline is a ribbon of thin quads laid from hit to hit in the field's
# world space, each hit lifted `Look.FX_GROUND_LIFT_TILES` like every other ground mark.
#
# ⚠⚠ **It is a shape on the island, not on the glass.** Where the rect's top edge crosses the foot of
# the 2층 tongue the hits jump to the tongue's top and the ribbon climbs the face with them; when the
# board turns a quarter the ribbon turns with the ground it was laid on and is no longer a rectangle
# on screen. **That is the whole of what this candidate is for.**
#
# The material is `FieldView._fx_layer`'s, copied: unshaded, vertex-coloured, alpha-blended, both
# faces, no depth write (still depth-TESTED so a cliff in front hides what is behind), and a
# `render_priority` above the 판's so sort order does not bury it — the same reason the 이동선 carries one.
#
# ⚠ **The fill is one quad and nothing more** — two triangles across the four corner hits, faint. It
# is flat at the corners' height, so where the ground rises inside the rect the terrain hides it; the
# outline is the subject and the fill is only so the inside reads as inside.
extends RefCounted

const NAME := "04-ground-decal"

## Screen px between two samples along an edge. 8 px is a fifth of a 조각 at the opening zoom, so no
## piece can span more than one step of the terrain.
const STEP_PX := 8.0
## Half-width of the outline ribbon in world units (조각). 0.045 is about 1.4 px at the opening zoom
## (0.762 × 40 px per 조각), a hair thicker than the StarCraft 1 px so the mint reads on pale ground.
const HALF_W := 0.045
## Draws above the ground layer (priority 1) and the 판 — sort order, not depth, decides this.
const PRIORITY := 2

var _common: GDScript = load("res://.prototypes/selection_box/common.gd")
var _fv: Node = null
var _mesh: MeshInstance3D = null
var _v := PackedVector3Array()
var _c := PackedColorArray()


func mount(_game: Node, fv: Node, drag: Dictionary) -> void:
	_fv = fv
	var rect: Rect2 = drag["rect"]
	var ink: Color = _common.ink_colour()
	var fill := Color(ink.r, ink.g, ink.b, 0.10)
	var line := Color(ink.r, ink.g, ink.b, 0.95)

	_v.clear()
	_c.clear()

	# --- the fill: one quad across the four corner hits, lifted -------------------------------------
	var g: PackedVector3Array = drag["ground"]
	if g.size() == 4:
		var lift := Vector3(0.0, Look.FX_GROUND_LIFT_TILES, 0.0)
		var tl: Vector3 = g[0] + lift
		var tr: Vector3 = g[1] + lift
		var br: Vector3 = g[2] + lift
		var bl: Vector3 = g[3] + lift
		_tri(tl, tr, br, fill)
		_tri(tl, br, bl, fill)

	# --- the outline: the rect's perimeter sampled every STEP_PX and projected onto the terrain -----
	var pts := _perimeter_hits(rect)
	var n := pts.size()
	for k in n:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % n]
		_ribbon(a, b, line)
	# Square caps on the four corners hide the notch a 90° bend leaves on its outside.
	for corner in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end,
			rect.position + Vector2(0.0, rect.size.y)]:
		_cap(_hit(corner), line)

	_mesh = MeshInstance3D.new()
	_mesh.name = "selbox_ground_decal"
	var im := ImmediateMesh.new()
	if not _v.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in _v.size():
			im.surface_set_color(_c[k])
			im.surface_add_vertex(_v[k])
		im.surface_end()
	_mesh.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = PRIORITY
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fv._world.add_child(_mesh)
	print("[04-ground-decal] %d perimeter hits, %d vertices" % [n, _v.size()])


func unmount() -> void:
	if _mesh != null:
		if _mesh.get_parent() != null:
			_mesh.get_parent().remove_child(_mesh)
		_mesh.queue_free()
		_mesh = null
	_fv = null
	_v.clear()
	_c.clear()


func lines() -> PackedStringArray:
	return PackedStringArray([
		"buys — reads as 「this ground」: the outline climbs the 2층 tongue where the top edge crosses it and turns with the board at yaw 90, so the box names a place on the island and not a patch of glass",
		"costs — a terrain projection per sample per frame while dragging (about 80 ray walks for this rect); jagged on cliffs, where the ribbon stands up the face and the corners stop being square",
		"cannot — cannot stay a rectangle once the camera turns: it becomes the shape the ground was under the glass at drag time, and it cannot be a pulled picture — it is geometry, so the frame_01 ink has nowhere to go",
	])


# --- the projection --------------------------------------------------------------------------------

## The terrain point under one screen px in the field's world space, lifted off the ground —
## `screen_to_terrain_px` → `world_to_tile` → `_ground_h`, exactly the lab's `ground_hit`, plus lift.
func _hit(at: Vector2) -> Vector3:
	var w: Vector2 = _fv.screen_to_terrain_px(at)
	var tv: Vector2i = _fv.world_to_tile(w)
	var h: float = _fv._ground_h(tv.x, tv.y) + Look.FX_GROUND_LIFT_TILES
	return Vector3(w.x / Look.TILE_PX, h, w.y / Look.TILE_PX)


## The rect's perimeter, clockwise from the top-left, one hit every `STEP_PX` — closed, so the last
## hit joins back to the first.
func _perimeter_hits(rect: Rect2) -> PackedVector3Array:
	var out := PackedVector3Array()
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end,
		rect.position + Vector2(0.0, rect.size.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var len_px := (b - a).length()
		var steps := maxi(1, int(ceil(len_px / STEP_PX)))
		for k in steps:
			out.append(_hit(a.lerp(b, float(k) / float(steps))))
	return out


# --- the geometry ----------------------------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		_v.append(p)
		_c.append(col)


## One thin quad from `a` to `b`, its width perpendicular to the run in the ground plane — so a piece
## that climbs a face still shows its face to the camera above.
func _ribbon(a: Vector3, b: Vector3, col: Color) -> void:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var len_w := flat.length()
	var side: Vector3
	if len_w <= 0.0001:
		# A purely vertical piece (straight up a face): widen it across the camera's right instead.
		var cam: Camera3D = _fv._cam
		var r: Vector3 = cam.global_transform.basis.x
		side = Vector3(r.x, 0.0, r.z).normalized() * HALF_W
		if side.length() <= 0.0001:
			side = Vector3(HALF_W, 0.0, 0.0)
	else:
		var s := Vector2(-flat.y, flat.x) / len_w * HALF_W
		side = Vector3(s.x, 0.0, s.y)
	_tri(a - side, a + side, b + side, col)
	_tri(a - side, b + side, b - side, col)


## A square lying on the ground at `p`, `HALF_W` to each side.
func _cap(p: Vector3, col: Color) -> void:
	var x := Vector3(HALF_W, 0.0, 0.0)
	var z := Vector3(0.0, 0.0, HALF_W)
	_tri(p - x - z, p + x - z, p + x + z, col)
	_tri(p - x - z, p + x + z, p - x + z, col)
