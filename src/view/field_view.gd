class_name FieldView
extends Node2D
## The field. **A 3D space wearing 2D pictures** — 티켓 08, 2026-08-24.
##
## ⚠⚠ **This file used to paint the whole fight by hand on a canvas.** Terrain, cliff faces, bodies,
## hulls, rings, halos, tracers, sparks and bursts were 537 lines of `_draw()` and fourteen `_paint_*`
## leaves. **The engine does the first three now**, and the rest is not ported yet — see "What is not
## here yet" at the bottom of this comment. The move was measured before it was made: of the 1033
## checks tied to painting in 2D, about 550 survive it and about 480 do not.
##
## **It is still a `Node2D`.** A `Node3D` subtree parented under a `Node2D` renders exactly as it
## would anywhere else, and every canvas item in the shell still draws ON TOP of it — probed before a
## line of this was written (`probe_3d_under_2d`). So the shell's child order, and every check that
## reads it, is untouched: field, hud, map, reward, refit, title, panel still means what it meant,
## with the 3D world sitting under all seven.
##
## **What the engine took over, and what that bought:**
##
## | It used to be | Now | What that gets |
## |---|---|---|
## | rows drawn `TILE_H_PX` tall on a flat canvas | a real camera at 40 degrees | height reads at all |
## | a face line along every seaward cliff edge | a box 2.4 tall | the cliff IS tall |
## | a squashed ellipse under every body | one directional light | shadows nobody draws |
## | `position = -cam_px * zoom` | `Camera3D`, orthogonal | it can turn |
##
## **The camera contract did not change, and that is deliberate.** `cam_px` is still the world-px
## corner of the visible ground, `zoom` is still the same ladder between `ZOOM_MIN` and `ZOOM_MAX`,
## and `screen_to_world_px` still answers in world px. `pan_by` / `zoom_at` / `_clamp_cam` are the
## same pure functions they were, so the shell needed no edit at all and the checks that drove them
## through `.new()` still drive them. **What is new inside them is one axis**: the ground is no longer
## square on screen, so a screen-y px covers `1 / cos(pitch)` ground px, and the two conversions say
## so in one place each.
##
## ⚠ **Orthogonal, not perspective.** This game is read off a grid; a perspective camera draws two
## tiles of one size at two sizes, and that reading is the thing it cannot lose.
##
## ⚠ **This paragraph used to say the effects were not drawn, and that stopped being true on
## 2026-08-24** — 티켓 09's step 4 brought all twelve back on two immediate-mesh layers (the ground
## one follows the terrain, the air one stands on the camera plane). It is corrected rather than
## deleted because a header claiming a quiet screen is how a real absence gets read as expected.
##
## **What is not here**, as of 2026-08-25: nothing on that list. The beak was never this layer's —
## it belongs to the roster screen and the twelve were wrong to count it.


## Kept because `_rounded_square` is gone but the baked picture wants the same corner it drew.
const CORNER_SEGMENTS := 6

## How many rungs `screen_to_terrain_px` walks down the view ray. **The height step is this divided
## into `Look.terrain_height_ceiling()`**, so at pitch 40 one rung slides the ground point about 3.6
## world px — under a tenth of a tile, which is the resolution a press is answered to. Raising it buys
## precision nobody can press to; lowering it lets a thin ridge fall between two rungs.
const TERRAIN_PICK_STEPS := 48

const WATER_SHADER := "res://src/view/water.gdshader"


# --- what it reads, and never writes ---------------------------------------------------------------

var battle: Battle = null
var army: Army = null
var rows: Array = []


# --- its own clock. Unchanged by the move: an effect ages in seconds whatever draws it -------------

var _fx: Array = []
var _body: Dictionary = {}



# --- the camera ------------------------------------------------------------------------------------

## World px of the visible ground's top-left corner, exactly as before the move.
var cam_px := Vector2.ZERO
var zoom := 1.0
## ⚠ **The new axis, and the only piece of state this move added.** 0 is the view the flat board
## always had. **Nothing turns it yet** — what turns it, and whether a hand is allowed to during a
## fight, is 티켓 07, which is open precisely because turning IS the hand moving.
var cam_yaw_deg := Look.CAM_YAW_DEG

## How far the camera is tilted, in degrees off the horizon. **A runtime float like `cam_yaw_deg` and
## like `zoom`** — `Look.CAM_PITCH_DEG` is only where it starts. ⚠ Every conversion between the screen
## and the ground reads THIS and not the constant, or a tilted view answers a press with the tile the
## opening tilt would have had.
var cam_pitch_deg := Look.CAM_PITCH_DEG


# --- pictures ---------------------------------------------------------------------------------------

## One texture per row of `Look.BEAST_TEX`, both facings, loaded once. **`null` where that row's path
## is empty**, which `_put_body` already draws the plain rounded shape for.
var _tex_facing_r: Array[Texture2D] = _load_beast_tex(true)
var _tex_facing_l: Array[Texture2D] = _load_beast_tex(false)
## The frame strips, `[type][anim][frame]`, loaded once beside the standing pictures. **Empty wherever
## `Look.BEAST_TEX` declares no strip** — which is eight of the nine rows today, and is exactly why
## nothing below names a species: an empty strip falls back on the standing picture at the one place a
## body's picture is chosen, so the ninth species animates by editing its own row and nothing else.
var _tex_anim_r: Array = _load_beast_anim(true)
var _tex_anim_l: Array = _load_beast_anim(false)
## The rounded square, baked once. Every enemy wears it, tinted — the same two marks `_paint_body`
## drew by hand (the outline and the centre dot) with nothing filled between them.
var _tex_body: Texture2D = null
## One white texel, for the two halves of an HP bar.
var _tex_flat: Texture2D = null


# --- the 3D subtree, all of it built in code -------------------------------------------------------

var _world: Node3D = null
var _cam: Camera3D = null
var _terrain: MeshInstance3D = null

var _sea: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _sun: DirectionalLight3D = null
## **The mark on the MAT under the cursor.** Its mesh is rebuilt when the cursor crosses into
## another mat -- see `set_hover_tile`.
var _hover: MeshInstance3D = null
## Which MAT the cursor is on, not which tile. -1 for none.
var _hover_cell := -1
## Which mat each tile belongs to, kept from the last `_rebuild_wash`. The hover mark reads it.
var _wash_cell := PackedInt32Array()
var _wash: MeshInstance3D = null
var _sprites: Array[Sprite3D] = []
var _hulls: Array[MeshInstance3D] = []
var _sprites_used := 0
var _hulls_used := 0
## What the terrain in the mesh was built for. Rebuilding 5120 boxes every frame is waste; the island
## only changes when it opens, and the summonable band only when the plan is committed.
var _built_for := ""


# --- the plan being authored -------------------------------------------------------------------------

var _summon_slot := -1
var _summon_aim := -1
var _wait_clock := 0.0


func _ready() -> void:
	_build_world()


## Everything under here is made in code and never from a scene file, the same rule `game.gd` keeps
## for its seven children and for the same reason: a node parked in a `.tscn` lets the line that makes
## it be deleted with nothing going red.
func _build_world() -> void:
	if _world != null:
		return
	_tex_body = _make_body_tex()
	_tex_flat = _make_flat_tex()

	_world = Node3D.new()
	add_child(_world)

	# ⚠ **The sea goes in FIRST so it is under everything**, and it is a single quad rather than more
	# tiles: see `SEA_SPAN_TILES`. It carries no band and never changes, so it is built once here and
	# only ever moved to the middle of whatever island opens.
	_sea = MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(Look.SEA_SPAN_TILES, Look.SEA_SPAN_TILES)
	_sea.mesh = sea_mesh
	# The sea is a shader, not a flat colour and not a bought texture — see `water.gdshader`.
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = load(WATER_SHADER)
	sea_mat.set_shader_parameter("trough", Look.COL_WATER)
	sea_mat.set_shader_parameter("crest", Look.COL_WATER_CREST)
	sea_mat.set_shader_parameter("wave_scale", Look.WATER_WAVE_SCALE)
	sea_mat.set_shader_parameter("wave_speed", Look.WATER_WAVE_SPEED)
	sea_mat.set_shader_parameter("contrast", Look.WATER_CONTRAST)
	sea_mat.set_shader_parameter("ripple_scale", Look.WATER_RIPPLE_SCALE)
	sea_mat.set_shader_parameter("ripple_speed", Look.WATER_RIPPLE_SPEED)
	sea_mat.set_shader_parameter("ripple_strength", Look.WATER_RIPPLE_STRENGTH)
	sea_mat.set_shader_parameter("ripple_fade_tiles", Look.WATER_RIPPLE_FADE)
	sea_mat.set_shader_parameter("ripple_wind_deg", Look.WATER_RIPPLE_WIND_DEG)
	sea_mat.set_shader_parameter("ripple_stretch", Look.WATER_RIPPLE_STRETCH)
	sea_mat.set_shader_parameter("ripple_chop", Look.WATER_RIPPLE_CHOP)
	_sea.material_override = sea_mat
	# ⚠⚠ **The sea casts nothing, and that is a fix rather than an optimisation.** A flat quad 400
	# tiles across shadows ITSELF at grazing angles, and the whole sea drew as diagonal stripes — the
	# capture that added the quad shows them. A flat sea has nothing to cast anyway; the island still
	# casts onto it, which is the only shadow out there that means something.
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_sea)

	# One mesh, one material, one draw call for the whole island — see `_rebuild_terrain`.
	_terrain = MeshInstance3D.new()
	_world.add_child(_terrain)

	# The ring: where a boat may be put down. Built once, moved and resized per island.
	_ring = MeshInstance3D.new()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Look.COL_SUMMON_RING
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Unshaded: it is a MARK on the water, not a thing floating on it, and a mark that dims when the
	# sun goes round is a mark that stops answering the question it was drawn for.
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_ring)

	# The two effect layers. Built here and never rebuilt, because what changes every frame is the
	# geometry inside them and not the nodes.
	_decal = _fx_layer()
	_air = _fx_layer()

	# ⚠⚠ **THE MARK IS A MAT, NOT A QUAD.** It used to be one plane the size of one tile, moved
	# about; the user asked for the 2x2 piece to be the unit that lights up, and a square of that size
	# hangs over the shore on every coastal piece. **It is cut from the mat's own mask instead**, so it
	# is exactly the shape of the thing it lights up, and its mesh is rebuilt only when the cursor
	# crosses into another mat.
	_hover = MeshInstance3D.new()
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	# ⚠ **Unshaded.** A lit mark goes grey on the shadow side of the island and stops reading as a
	# cursor -- it is a mark, not a surface, the same argument the outline pass makes for its ink.
	plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plate_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ⚠ **It must not throw a shadow.** A floating quad casting a hard square onto the ground under
	# it is the giveaway that it is hovering rather than lying on the tile.
	_hover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover.material_override = plate_mat
	_hover.visible = false
	_world.add_child(_hover)

	# ⚠ **Built empty and filled by `_rebuild_wash`**, which needs a grid — `_build_world` runs before
	# one is loaded on the very first island.
	_wash = MeshInstance3D.new()
	var wash_mat := StandardMaterial3D.new()
	wash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	wash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wash.material_override = wash_mat
	_wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_wash)


	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(Look.SUN_PITCH_DEG, Look.SUN_YAW_DEG, 0.0)
	_sun.light_energy = Look.SUN_ENERGY
	# ⚠ **The whole point of the light.** Without this the boxes are shaded but nothing is cast, and a
	# cliff standing 2.4 tall is told apart from land only by its own face being darker — which is what
	# the flat board already did with a line, at the cost of a leaf and a width constant.
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = Look.SUN_SHADOW_DIST_TILES
	# ⚠ **One split, not four.** The default cascade splits its range into four shadow maps, and the
	# seam between two of them drew as **a hard line straight across the sea** in this port's first
	# capture — cascades exist to spend detail near a perspective camera, and this camera is
	# orthogonal, so every tile on screen is the same distance from it in the only sense that matters.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# The same acne the sea showed, on the island's own long flat stretches. Pushed off the surface
	# along its normal rather than along the light, so a slope and a flat face need one number.
	_sun.shadow_normal_bias = Look.SUN_SHADOW_NORMAL_BIAS
	_world.add_child(_sun)

	# ⚠⚠ **THERE IS NO SECOND LIGHT, AND THAT IS A DECISION** (2026-08-26, the user: 「해 하나가 맞는듯」).
	# A dim fill from the opposite side used to lift the faces the sun never reaches. It also gave every
	# object a second lit direction, so nothing on the island agreed about where the light came from —
	# and the moment real cast shadows appeared, that disagreement was the thing on screen. **What the
	# fill was doing is now done by the ambient**, which has no direction to disagree with.
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Look.COL_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Look.COL_AMBIENT
	e.ambient_light_energy = Look.AMBIENT_ENERGY
	var env := WorldEnvironment.new()
	env.environment = e
	_world.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# KEEP_WIDTH so `size` is the visible WIDTH in tiles and the existing zoom ladder converts across
	# with one division. Under the default KEEP_HEIGHT the same number would mean the visible height,
	# and every camera literal measured against a 1280-wide viewport would quietly mean something else.
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	# ⚠⚠ **THIS LINE IS THE SHADOW RANGE, not a clipping detail.** Under an orthogonal camera Godot
	# ignores `directional_shadow_max_distance` and spreads the directional shadow map over the camera's
	# `far` instead. Left at the default 4000 it gave half a tile per texel and NOTHING on the island
	# cast a shadow onto anything — see `Look.CAM_FAR_TILES` for the measurement.
	_cam.far = Look.CAM_FAR_TILES
	_world.add_child(_cam)
	_place_camera()


## A white rounded-square OUTLINE with a white centre dot and nothing in between — the two marks
## `_paint_body` used to draw with `draw_polyline` and `draw_circle`. White, so the one modulate on the
## sprite carries the body's own colour; baked, because a billboard wears a picture and cannot be
## handed a polyline.
func _make_body_tex() -> Texture2D:
	var n := Look.BODY_TEX_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Look.COL_BAKE_CLEAR)
	var half := float(n) * 0.5
	var edge := half - float(Look.BODY_TEX_OUTLINE_PX) * 0.5
	var corner := edge * 0.45
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half)
			# Distance to a rounded square, the usual box-minus-corner form: push the point into the
			# straight part and measure what is left over.
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(edge - corner, edge - corner)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - corner
			if absf(d) <= float(Look.BODY_TEX_OUTLINE_PX) * 0.5:
				img.set_pixel(x, y, Look.COL_BAKE_MARK)
			elif p.length() <= float(Look.BODY_TEX_DOT_PX):
				img.set_pixel(x, y, Look.COL_BAKE_MARK)
	return ImageTexture.create_from_image(img)



## **The wash over every walkable tile, cut from the walkable SHAPE and not from the tile grid.**
##
## ⚠⚠ **This is what「맞춤형」means and it is why the shape is computed rather than tiled.** A rounded
## square drawn per tile gives a grid of squares, and on a coastal tile it hangs over the sea (measured
## 2026-08-27). The mask below is opened — eroded, then dilated — over the whole walkable region at
## once, so a run of tiles comes out as ONE shape with rounded outer corners, and the erosion pulls it
## clear of every edge the Blender bake moved.
##
## ⚠ **One mesh, one texture, built when the board loads.** Nothing here runs per frame.
func _rebuild_wash() -> void:
	if _wash == null:
		return
	_wash.mesh = null
	if battle == null or battle.grid == null:
		return
	var grid: Grid = battle.grid
	var res := Look.WASH_TEX_PER_TILE_PX
	var mw := grid.w * res
	var mh := grid.h * res

	var cell := _wash_cells(grid)
	_wash_cell = cell
	_hover_cell = -1
	if _hover != null:
		_hover.visible = false

	# **The two boundaries, marked at mask resolution.** A pixel is on a boundary when the tile across
	# one of its sides is classified differently from its own, which puts the mark exactly on the tile
	# line and nowhere else.
	#
	# ⚠⚠ **WALKED PER TILE AND NOT PER PIXEL.** A mask pixel's neighbours are in another tile only on
	# its own border, so the whole classification is a handful of comparisons per TILE -- 520 of them
	# instead of 133k. The per-pixel version was measured unusable (2026-08-27).
	#
	# ⚠⚠ **THE LAND EDGE IS TESTED EIGHT WAYS AND THE FOUR DIAGONALS ARE THE POINT.** A tile whose
	# DIAGONAL neighbour is water sits on an OUTSIDE corner of the shore, and that is where the bake
	# rounds hardest -- the corner the mat kept hanging off. Four ways alone leave those unmarked.
	#
	# ⚠ **A change of LEVEL counts as a land edge**, which is what pulls the mat back off the cliffs:
	# a plateau tile and the ground beside it are both walkable, so measured flat the drop between them
	# is invisible to the mask and the mat hangs over it.
	var land0 := PackedByteArray()
	var seam0 := PackedByteArray()
	land0.resize(mw * mh)
	seam0.resize(mw * mh)
	for i in mw * mh:
		land0[i] = 1
		seam0[i] = 1
	for ty in grid.h:
		for tx in grid.w:
			var t := ty * grid.w + tx
			var x0 := tx * res
			var y0 := ty * res
			if grid.passable[t] != 1:
				for yy in range(y0, y0 + res):
					var row := yy * mw
					for xx in range(x0, x0 + res):
						land0[row + xx] = 0
						seam0[row + xx] = 0
				continue
			var lv := grid.level_of(t)
			var c := int(cell[t])
			for side in 4:
				var nx := tx + (1 if side == 0 else (-1 if side == 1 else 0))
				var ny := ty + (1 if side == 2 else (-1 if side == 3 else 0))
				var is_land_edge := true
				var is_seam := false
				if nx >= 0 and ny >= 0 and nx < grid.w and ny < grid.h:
					var nt := ny * grid.w + nx
					if grid.passable[nt] == 1 and grid.level_of(nt) == lv:
						is_land_edge = false
						is_seam = int(cell[nt]) != c
				if not is_land_edge and not is_seam:
					continue
				var ax := x0 if side != 0 else x0 + res - 1
				var ay := y0 if side != 2 else y0 + res - 1
				for k in res:
					var mx := ax if side < 2 else x0 + k
					var my := y0 + k if side < 2 else ay
					var mi := my * mw + mx
					if is_land_edge:
						land0[mi] = 0
					else:
						seam0[mi] = 0
			for corner in 4:
				var dx := 1 if corner < 2 else -1
				var dy := 1 if corner % 2 == 0 else -1
				var nx2 := tx + dx
				var ny2 := ty + dy
				var bad := true
				if nx2 >= 0 and ny2 >= 0 and nx2 < grid.w and ny2 < grid.h:
					var nt2 := ny2 * grid.w + nx2
					bad = grid.passable[nt2] != 1 or grid.level_of(nt2) != lv
				if not bad:
					continue
				land0[(y0 + (res - 1 if dy > 0 else 0)) * mw + x0 + (res - 1 if dx > 0 else 0)] = 0
	var d_land := _dist_to_zero(land0, mw, mh)
	var d_seam := _dist_to_zero(seam0, mw, mh)

	# Opening: erode by (inset + round), then take everything within `round` of what survived.
	var r_in := (Look.WASH_INSET_TILES + Look.WASH_ROUND_TILES) * float(res)
	var r_out := Look.WASH_ROUND_TILES * float(res)
	var r_gap := (Look.WASH_BLOCK_GAP_TILES + Look.WASH_ROUND_TILES) * float(res)
	# ⚠⚠ **EVERY MAT SITS AT ITS PIECE'S CENTRE, AND THIS IS WHAT PUTS IT THERE** (2026-08-27, the
	# user: 「4개를 합쳤을때 가운데에 새롭게 만드는건지」). The mat is what is LEFT after the ground is
	# cut, not a shape laid on the middle — so an edge that bites on ONE side pushes what is left off
	# centre, which is exactly what the coastal pieces were doing.
	#
	# **The fix is to erode all four sides by the WORST side's amount.** For each piece, find how far the
	# land edge intrudes into the mat it would otherwise have, and take that off every side. A coastal
	# mat comes out smaller than an inland one and both come out centred.
	var need := PackedFloat32Array()
	need.resize(grid.w * grid.h)
	for i in mw * mh:
		if d_seam[i] < r_gap:
			continue
		var t := (i / mw / res) * grid.w + ((i % mw) / res)
		if int(cell[t]) < 0:
			continue
		var short: float = r_in - d_land[i]
		if short > need[int(cell[t])]:
			need[int(cell[t])] = short

	var core := PackedByteArray()
	core.resize(mw * mh)
	var any := false
	for i in mw * mh:
		# ⚠ **The two boundaries are held apart and eroded by DIFFERENT amounts.** A seam is a gap
		# between two mats on the same flat ground; a land edge is a fall. Erode both by the same
		# number and either the seam swallows the mat or the mat walks off the cliff.
		# ⚠ **Inverted on purpose**: `_dist_to_zero` measures to the nearest 0, so the core has to be
		# the 0s of the array handed to the second pass.
		var t := (i / mw / res) * grid.w + ((i % mw) / res)
		var c := int(cell[t])
		var deep: bool = c >= 0 and d_seam[i] >= r_gap + maxf(need[c], 0.0)
		core[i] = 0 if deep else 1
		if deep:
			any = true

	if not any:
		return
	var d_core := _dist_to_zero(core, mw, mh)

	# ⚠⚠ **ONE BUFFER HANDED OVER WHOLE, NOT `set_pixel` PER PIXEL.** `set_pixel` on a board this
	# size is most of what made the island slow to open. `resize` zero-fills, so a pixel the mat does
	# not cover is already fully transparent and costs nothing to skip.
	var rim := Look.WASH_RIM_TILES * float(res)
	var buf := PackedByteArray()
	var lit := PackedByteArray()
	buf.resize(mw * mh * 4)
	lit.resize(mw * mh * 4)
	for i in mw * mh:
		var d: float = d_core[i]
		# One mask pixel of feather, so the edge is not a staircase at any zoom.
		var a := clampf(r_out - d + 0.5, 0.0, 1.0)
		if a <= 0.0:
			continue
		var on_rim: bool = d > r_out - rim
		var col: Color = Look.COL_WASH_RIM if on_rim else Look.COL_WASH
		# ⚠⚠ **THE HOVER MARK WEARS THE SAME MASK, BRIGHTER.** A square of its own hangs over the
		# shore on every coastal piece; sharing the mask is what makes the mark exactly the shape of
		# the mat it lights up, feathered edge and all.
		var hot: Color = Look.COL_HOVER_RIM if on_rim else Look.COL_HOVER_PLATE
		var o := i * 4
		buf[o] = int(col.r * 255.0)
		buf[o + 1] = int(col.g * 255.0)
		buf[o + 2] = int(col.b * 255.0)
		buf[o + 3] = int(col.a * a * 255.0)
		lit[o] = int(hot.r * 255.0)
		lit[o + 1] = int(hot.g * 255.0)
		lit[o + 2] = int(hot.b * 255.0)
		lit[o + 3] = int(hot.a * a * 255.0)
	var mat: StandardMaterial3D = _wash.material_override
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.create_from_data(mw, mh, false, Image.FORMAT_RGBA8, buf))
	if _hover != null:
		var hmat: StandardMaterial3D = _hover.material_override
		hmat.albedo_texture = ImageTexture.create_from_image(
				Image.create_from_data(mw, mh, false, Image.FORMAT_RGBA8, lit))


	# One quad per walkable tile, at that tile's own drawn surface. **The quad follows the ground and
	# the SHAPE follows the mask** — a stair tile is sloped, so its four corners are sampled separately.
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var lift := Look.WASH_LIFT_TILES
	for ty in grid.h:
		for tx in grid.w:
			if grid.passable[ty * grid.w + tx] != 1:
				continue
			_append_ground_quad(verts, uvs, grid, tx, ty, lift)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_wash.mesh = mesh


## **One tile's quad on the drawn ground**, appended to `verts`/`uvs`. The mat and the hover mark are
## the same shape in the same place at different heights, so they build their geometry the same way --
## written twice, the two would drift and the mark would stop covering what it lights.
##
## ⚠ 0.49 and not 0.5: `surface_h` rounds to a tile, and half a tile out lands on the neighbour --
## which on a stair is the next step up and reads as a torn quad.
func _append_ground_quad(verts: PackedVector3Array, uvs: PackedVector2Array, grid: Grid,
		tx: int, ty: int, lift: float) -> void:
	var c := Vector2(float(tx), float(ty))
	var p00 := Vector3(c.x - 0.5, _stand_h(c + Vector2(-0.49, -0.49)) + lift, c.y - 0.5)
	var p10 := Vector3(c.x + 0.5, _stand_h(c + Vector2(0.49, -0.49)) + lift, c.y - 0.5)
	var p11 := Vector3(c.x + 0.5, _stand_h(c + Vector2(0.49, 0.49)) + lift, c.y + 0.5)
	var p01 := Vector3(c.x - 0.5, _stand_h(c + Vector2(-0.49, 0.49)) + lift, c.y + 0.5)
	var u0 := float(tx) / float(grid.w)
	var u1 := float(tx + 1) / float(grid.w)
	var v0 := float(ty) / float(grid.h)
	var v1 := float(ty + 1) / float(grid.h)
	verts.append_array([p00, p10, p11, p00, p11, p01])
	uvs.append_array([
		Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1),
		Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)])


## **Which mat each tile belongs to** -- the index of its 2x2 piece, or -1 where nothing walks.
##
## ⚠⚠ **2x2 BECAUSE THE ISLAND IS BUILT THAT WAY** -- `tools/blender/island_build.py` lays the whole
## island down as 2x2 pieces and a raised block is always a whole piece, so the piece is the unit the
## eye already reads. Two other units were on screen and rejected: one mat per TILE
## (「너무 많으」) and mats grown freely from seeds (「맘대로 되어있는」).
func _wash_cells(grid: Grid) -> PackedInt32Array:
	var n := grid.w * grid.h
	var cell := PackedInt32Array()
	cell.resize(n)
	var span := Look.WASH_BLOCK_TILES
	var across := (grid.w + span - 1) / span
	for ty in grid.h:
		for tx in grid.w:
			var t := ty * grid.w + tx
			# ⚠⚠ **A STAIR CARRIES NO MAT** (2026-08-27, the user: 「계단에는 칸을 안만들어야하는데」).
			# **No shape has to be authored per tile to say so** — the board already knows: an ODD notch
			# IS a stair (`Grid.is_stair_level`), which is the same fact that makes the stair the only
			# way up. A mat says「여기 서라」 and a stair is something a body passes THROUGH.
			# ⚠ It stays walkable. Only the light stops there.
			var no_mat: bool = grid.passable[t] != 1 or Grid.is_stair_level(grid.level_of(t))
			cell[t] = -1 if no_mat else (ty / span) * across + (tx / span)
	return cell



## Distance, in mask pixels, from every cell to the nearest cell holding 0. **Two-pass chamfer**, which
## is O(n) and within a few percent of true Euclidean — far closer than the shape needs.
func _dist_to_zero(cells: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	var big := 1.0e9
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = big if cells[i] != 0 else 0.0
	var diag := 1.41421356
	for y in h:
		for x in w:
			var i := y * w + x
			if d[i] == 0.0:
				continue
			var m: float = d[i]
			if x > 0:
				m = minf(m, d[i - 1] + 1.0)
			if y > 0:
				m = minf(m, d[i - w] + 1.0)
				if x > 0:
					m = minf(m, d[i - w - 1] + diag)
				if x < w - 1:
					m = minf(m, d[i - w + 1] + diag)
			d[i] = m
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if d[i] == 0.0:
				continue
			var m: float = d[i]
			if x < w - 1:
				m = minf(m, d[i + 1] + 1.0)
			if y < h - 1:
				m = minf(m, d[i + w] + 1.0)
				if x < w - 1:
					m = minf(m, d[i + w + 1] + diag)
				if x > 0:
					m = minf(m, d[i + w - 1] + diag)
			d[i] = m
	return d


func _make_flat_tex() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Look.COL_BAKE_MARK)
	return ImageTexture.create_from_image(img)


@warning_ignore("shadowed_variable")
func setup(battle: Battle, army: Army, rows: Array) -> void:
	self.battle = battle
	self.army = army
	self.rows = rows
	# **Both drawers are emptied here.** Without it island 2 opens with island 1's explosions still in
	# flight over bodies that no longer exist, and every id in them means a different unit now.
	_fx = []
	_body = {}
	# A slot armed on island 1 must not survive onto island 2, and the tile index it was aiming at
	# would name a different piece of water there.
	_summon_slot = -1
	_summon_aim = -1
	_wait_clock = 0.0
	# The survey: an island opens zoomed all the way out, so the WHOLE island is on screen before
	# anything is planned — `plan-then-watch` 6.3, on the user's 「조금 더 카메라를 뒤로 빼야 될」.
	# ⚠ **Not `ZOOM_MIN` any more.** See `Look.survey_zoom_of`: the opening view is a question about the
	# grid that just loaded, and a constant could only ever answer it for one map size.
	zoom = Look.survey_zoom_of(_map_tiles().x, _map_tiles().y)
	cam_px = Vector2.ZERO
	cam_yaw_deg = Look.CAM_YAW_DEG
	cam_pitch_deg = Look.CAM_PITCH_DEG
	_clamp_cam()
	# ⚠ **Forces a terrain rebuild even when the same island re-opens.** `_built_for` is a fingerprint
	# of the rows, and re-entering island 0 from the map would otherwise keep the mesh from the last
	# time — which is right for the boxes and wrong for the band, because the plan has been reset.
	_built_for = ""
	_build_world()
	_rebuild_terrain()
	_rebuild_wash()
	_place_camera()


## The sim moves every frame and the picture has to follow it.
##
## **The order is load-bearing and it is the order it always was.** Ageing first and draining second
## means an effect born this frame is at full amplitude on the frame it was born, so the flinch really
## does reach its full flinch once and the idle sway really does start from rest.
##
## ⚠ **Every clock here is aged by the BARE frame delta**, `_wait_clock` included — there is no speed
## multiplier to fold in, and a leaf handed a constant 1.0 is the shape "No fake code" names.
func _process(delta: float) -> void:
	_fx_step(delta)
	_drain_events()
	_wait_clock += delta
	# ⚠ **A visibility flip, not a rebuild.** The plan used to be painted into the terrain's own
	# colours, so committing meant building the whole mesh a second time; it is a ring of its own now.
	if _ring != null:
		_ring.visible = _band_on()
	_place_camera()
	# ⚠ **The buffers are opened BEFORE the bodies and flushed after everything.** The hit halo and the
	# ghosts are painted from inside `_paint_bodies` — they are per-body facts and that is the one loop
	# that has a body's centre, radius and clock in hand at the same time.
	_fx_begin()
	_paint_bodies()
	_paint_fx()
	_fx_flush()


# --- the camera: still one transform, still in one place -------------------------------------------

## How much GROUND, in world px, the viewport covers at this zoom.
##
## ⚠⚠ **The two axes no longer share a divisor and that is the whole of what tilting cost.** A screen
## px across is a ground px across; a screen px DOWN is `1 / sin(pitch)` ground px, because the ground
## is leaning away. Written once, here, and both conversions below read it — computed at each call
## site instead, the two would drift and the drift would look like a mis-aimed click.
##
## ⚠⚠ **IT WAS `cos` AND THAT WAS A MEASURED DEFECT** (2026-08-25, the user: 「놓는 위치랑 배의 위치가
## 다른데?」). `cam_pitch_deg` is measured OFF THE HORIZON — 0 is a camera lying flat, 90 is a camera
## straight overhead — so the ground's foreshortening is its SINE: at 90 a tile of ground is unsquashed
## (`sin 90 == 1`) and at 0 it is edge on (`sin 0 == 0`). `cos` gets both ends backwards. Measured
## against `Camera3D.unproject_position` at pitch 40: one tile of ground along +z covers **0.6428** of
## a tile on screen, which is `sin 40` and not `cos 40`. The 19% error it cost put a press up to **two
## tiles above the tile under the cursor** at the bottom of the screen.
func _visible_ground_px() -> Vector2:
	var v := Look.viewport_size_px() / zoom
	return Vector2(v.x, v.y / sin(deg_to_rad(cam_pitch_deg)))


## The two ground axes the screen's own axes lie along, at this yaw. `_right` is screen-right,
## `_down` is screen-down. At yaw 0 they are +x and +y, which is what the flat board had.
func _ground_right() -> Vector2:
	var a := deg_to_rad(cam_yaw_deg)
	return Vector2(cos(a), sin(a))


func _ground_down() -> Vector2:
	var a := deg_to_rad(cam_yaw_deg)
	return Vector2(-sin(a), cos(a))


## The ground point at the middle of the screen, in world px. `cam_px` is a corner, and a corner is
## what the clamp and every check about it speak in; the camera needs the middle.
func _ground_centre_px() -> Vector2:
	return cam_px + _visible_ground_px() * 0.5


## A screen (viewport) px back to a point on the horizontal plane `ground_h` TILES up, in world px.
## **The one conversion every click goes through**, the same promise the flat board's
## `(at - position) / zoom` made.
##
## ⚠ At yaw 0, pitch 90 and `ground_h` 0 this IS that expression. The pitch squashes the vertical, the
## yaw turns the two axes, and nothing else about it moved.
##
## ⚠⚠ **`ground_h` is why a press on a hill used to land in the sea behind it.** The island has real
## height and this mapping had no argument for it, so it answered every press with the point the plane
## at height 0 would have — and a thing standing `h` tiles up draws `h / tan(pitch)` world px UP the
## screen from where that plane says it is. Measured on island 0 at the opening survey: **every one of
## its 180 walkable tiles** answered with a tile a mean of **2.8** and up to **4** rows away.
## **Nothing calls this with a height it invented**: `screen_to_terrain_px` reads the landscape's own
## `_ground_h`, and the camera gestures below pass nothing because they are about the plane.
func screen_to_world_px(at: Vector2, ground_h: float = 0.0) -> Vector2:
	var span := _visible_ground_px()
	var u := at.x / Look.VIEWPORT_W_PX - 0.5
	var v := at.y / Look.VIEWPORT_H_PX - 0.5
	var flat := _ground_centre_px() + _ground_right() * (u * span.x) + _ground_down() * (v * span.y)
	return flat + _ground_down() * (ground_h * Look.TILE_PX / tan(deg_to_rad(cam_pitch_deg)))


## A screen px back to the point on the LANDSCAPE under it, in world px. **This is what a press means**
## — `screen_to_world_px` answers about a plane, and the player is pointing at a hill.
##
## ⚠⚠ **It walks the view ray from the EYE OUTWARD and stops at the first ground it meets, and that
## near-to-far order is the whole of why it is a walk and not a fixed point.** The obvious version —
## take the sea-level answer, look up that tile's height, ask again, repeat — settles, and **it settles
## on the wrong surface**: at a screen point where a hilltop stands in front of open water, both the
## hilltop and the water behind it are answers that reproduce themselves, and the loop lands on
## whichever it started nearest. Measured on island 0: it left **60 of the 180 walkable tiles** still
## answering with a tile up to 3 rows away, every one of them behind something tall. The player can
## only press what they can SEE, so the nearest surface is the only right answer.
##
## **Near to far is DOWNWARD in height**: this camera stands on the `_ground_down` side of what it
## looks at, so along one view ray a higher point is a nearer point. The walk starts one step above
## `Look.terrain_height_ceiling()` — above every hill the legend can build — and drops until the ray is
## no longer above the ground under it.
##
## `TERRAIN_PICK_STEPS` is a COUNT and the height step is derived from it, so a shallow pitch (where
## one step of height slides the ground point a long way) costs the same work as a steep one instead of
## costing an unbounded amount.
func screen_to_terrain_px(at: Vector2) -> Vector2:
	var ceiling := Look.terrain_height_ceiling()
	var step := ceiling / float(TERRAIN_PICK_STEPS)
	var h := ceiling
	for _i in TERRAIN_PICK_STEPS:
		var world := screen_to_world_px(at, h)
		var tile := world_to_tile(world)
		if _ground_h(tile.x, tile.y) >= h:
			return world
		h -= step
	# Under every hill on the board: the ray reached sea level without meeting anything, so the sea is
	# what it hit. **Not `0.0`** — the water is a surface at `TERRAIN_H_WATER` like any other, and
	# answering on the plane below it would put a press on open sea a fifth of a tile off.
	return screen_to_world_px(at, Look.TERRAIN_H_WATER)


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / Look.TILE_PX)), int(floor(world.y / Look.TILE_PX)))


## The forward of `screen_to_world_px`, for a world point standing `ground_h` tiles up. **Written here
## beside its own inverse and nowhere else**: six instruments under `tools/` each carried a private
## copy, every one of them still on the flat board's formula and none of them turning with the yaw, so
## every one of them aimed its clicks at a tile next to the one it meant.
func world_to_screen_px(world: Vector2, ground_h: float = 0.0) -> Vector2:
	var span := _visible_ground_px()
	var off := world - _ground_centre_px()
	off -= _ground_down() * (ground_h * Look.TILE_PX / tan(deg_to_rad(cam_pitch_deg)))
	return Vector2(
		(off.dot(_ground_right()) / span.x + 0.5) * Look.VIEWPORT_W_PX,
		(off.dot(_ground_down()) / span.y + 0.5) * Look.VIEWPORT_H_PX)


## The forward of `screen_to_terrain_px`: where a tile's own surface lands on the glass.
func tile_to_screen_px(tx: int, ty: int) -> Vector2:
	return world_to_screen_px(Look.tile_point_px(Vector2(tx, ty)), _ground_h(tx, ty))


## Moves the camera by a SCREEN-space delta (mouse motion) and re-clamps. The ground under the cursor
## keeps up with the cursor, which is the only thing a drag has to promise.
func pan_by(delta_screen: Vector2) -> void:
	var span := _visible_ground_px()
	var on_ground := _ground_right() * (delta_screen.x / Look.VIEWPORT_W_PX * span.x) \
		+ _ground_down() * (delta_screen.y / Look.VIEWPORT_H_PX * span.y)
	cam_px -= on_ground
	_clamp_cam()


## Multiplies `zoom` by `factor` (clamped to `ZOOM_MIN`..`ZOOM_MAX`) while keeping the ground point
## under `at` fixed on screen.
##
## ⚠ **It asks `screen_to_world_px` twice rather than re-deriving the old closed form.** The closed
## form was true of a square, unturned ground; asking the conversion itself stays true at every yaw,
## and there is then exactly one place where the screen-to-ground mapping is written down.
func zoom_at(at: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, Look.ZOOM_MIN, Look.ZOOM_MAX)
	if new_zoom == zoom:
		return
	var before := screen_to_world_px(at)
	zoom = new_zoom
	cam_px += before - screen_to_world_px(at)
	_clamp_cam()


## Keeps the camera over the island. **It bounds the ground point at the MIDDLE of the screen**, not
## the corners of a screen-shaped rectangle.
##
## ⚠⚠ **That change is what let the board turn.** The old rule clamped `cam_px` into
## `[0, map - visible]`, which is only a bound while the visible ground is a screen-aligned rectangle;
## a turned view sees a DIAMOND and a rectangle's corners stop meaning anything about it. Bounding the
## centre is true at every yaw, and **at yaw 0 it is the same rule it always was** — the arithmetic
## below reduces to the old one term for term, which is why the pan and zoom checks that drove it
## still describe it.
##
## An axis whose map is narrower than the visible ground is CENTRED on it rather than clamped to an
## empty range — that is the survey framing an island opens at.
func _clamp_cam() -> void:
	var map_px := Vector2(float(_map_tiles().x), float(_map_tiles().y)) * Look.TILE_PX
	var visible := _visible_ground_px()
	var centre := cam_px + visible * 0.5
	for axis in 2:
		if map_px[axis] < visible[axis]:
			centre[axis] = map_px[axis] * 0.5
		else:
			centre[axis] = clampf(centre[axis], visible[axis] * 0.5, map_px[axis] - visible[axis] * 0.5)
	cam_px = centre - visible * 0.5


## Turns the board by `deg` about the point in the middle of the screen.
##
## ⚠⚠ **This is 티켓 07's question wearing a keyboard.** 「전투 중엔 손이 안 움직인다」 is the rule this
## game is built on, and turning the board IS the hand moving — so whether this survives, and whether
## it survives during a fight or only while planning, is a decision and not a knob. **It is here so the
## decision can be made by trying it instead of by arguing about it** (2026-08-24, the user: 「3D 회전
## 회전 버튼이 내가 돌려봐야 될 듯」).
##
## The ground point at the centre of the screen is held fixed, so the island turns in place rather
## than swinging out of view.
func turn_by(deg: float) -> void:
	var held := _ground_centre_px()
	cam_yaw_deg = fmod(cam_yaw_deg + deg, 360.0)
	cam_px = held - _visible_ground_px() * 0.5
	_clamp_cam()


## Tilts the camera and keeps the ground point at the MIDDLE of the screen where it was — the same
## promise `turn_by` makes, and for the same reason: the vertical span changes with the pitch, so a
## tilt that only wrote the angle would slide the island under the cursor.
func tilt_by(deg: float) -> void:
	var held := _ground_centre_px()
	cam_pitch_deg = clampf(cam_pitch_deg + deg, Look.CAM_PITCH_MIN_DEG, Look.CAM_PITCH_MAX_DEG)
	cam_px = held - _visible_ground_px() * 0.5
	_clamp_cam()


## Points the real camera at what `cam_px` / `zoom` / `cam_yaw_deg` describe. **The one place any of
## those three reach the engine**, the same rule `_compose_position` used to keep for `position`.
##
## ⚠⚠ **`back.z` WAS NEGATIVE AND THE WHOLE PICTURE WAS TURNED HALF A TURN** (2026-08-25, the user:
## 「놓는 위치랑 배의 위치가 다른데?」). Standing the camera on the -z side of its target makes it look
## along **+z**, and a Godot camera looking along +z has its own +x pointing at **world -x** — so world
## +x drew toward the LEFT of the screen and world +z drew UP it, while `_ground_right` / `_ground_down`
## and every press that goes through them said the opposite. **The island was drawn 180 degrees around
## from the board the shell was reading.** Measured against `Camera3D.unproject_position` on island 0:
## a press aimed at the tile actually under the cursor landed a **mean of 18.6 tiles** away.
## ⚠ **It is not symmetric and cannot be absorbed into the yaw**: `cam_yaw_deg` is the player's, Q and E
## write it, and 0 has to be the view the flat board had.
func _place_camera() -> void:
	if _cam == null:
		return
	var pitch := deg_to_rad(cam_pitch_deg)
	var yaw := deg_to_rad(cam_yaw_deg)
	# ⚠ The screen shake was added here as a ground offset in the screen's own two axes and it is
	# DELETED (2026-08-25, the user: 「이게 화면이 흔들릴 필요는 없을듯?」). The camera's resting
	# place is now the only thing this composes, which is why it cannot be corrupted by one.
	var centre := _ground_centre_px()
	var target := Vector3(centre.x / Look.TILE_PX, 0.0, centre.y / Look.TILE_PX)
	var back := Vector3(-sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_cam.size = _visible_ground_px().x / Look.TILE_PX
	_cam.look_at_from_position(target + back * Look.CAM_DIST_TILES, target, Vector3.UP)


# --- the island: DELETED 2026-08-26 --------------------------------------------------------------
# ⚠⚠ **569 lines that built the terrain mesh were deleted here, on the user's instruction**
# (***"판을 완전히 갈아엎어야 돼. 마음에 하나도 안 들어 ... 일단 다 지우자"***). What stood here was a
# hand-rolled landscape: value noise, stepped heights, shore fades, corner wetness, swell, rim
# darkening, skirts and wall quads — and **the user judged the picture it made, three times.**
#
# ⚠ **What replaces it is not written yet.** The island is going to be built by the user in the editor
# and read by the game, so nothing here should grow back: this file's job becomes *read the board the
# user made*, not *invent one*. **The board is blank until then, and the game says so by drawing
# nothing.**
#
# ⚠ **`_ground_h` survives as arithmetic only** — bodies still have to stand at their own level's
# height, and that is a number from `sim`, not a picture.


## The world height of the ground under tile `(tx, ty)`. **Level times rise, and nothing else** —
## every fade, swell and noise term that used to bend this number went with the mesh.
func _ground_h(tx: int, ty: int) -> float:
	if battle == null or battle.grid == null:
		return 0.0
	if tx < 0 or ty < 0 or tx >= battle.grid.w or ty >= battle.grid.h:
		return 0.0
	# ⚠ **Asked of the board file, not of `look.gd`.** The heights belong to the mesh that was built,
	# and the mesh and the file are written by the same run of the Blender script.
	return Islands.ground_h(int(battle.grid.level[ty * battle.grid.w + tx]))


func _tile_h(tx: int, ty: int) -> float:
	return _ground_h(tx, ty)


## The world height a body's feet rest at, for a point in TILE units. **Flat ground answers exactly
## what `_ground_h` would**; a stair answers the sloping surface the Blender bake drew.
## ⚠ **Presentation only.** Nothing here feeds a decision — the sim measures reach off `height_at`.
##
## ⚠⚠ **`Islands.base_h()` IS ADDED HERE AND LEAVING IT OUT BURIES EVERYTHING THAT STANDS.** `surface_h`
## counts tiers up from zero, which is what a walking rule should do; the MESH's level-0 top is 0.26
## above zero. Measured 2026-08-27: the hover plate sat 0.26 tiles inside the sand and the user's report
## was 「그런게 없음」 — it was on screen, underground, on every flat tile. The sentence above about
## `_ground_h` was written true and had been false ever since the island was authored in Blender.
func _stand_h(p: Vector2) -> float:
	if battle == null or battle.grid == null:
		return 0.0
	return battle.grid.surface_h(p) + Islands.base_h()


## The island, as ONE MESH MADE IN BLENDER.
##
## ⚠⚠ **Nothing here generates terrain any more, and that is the point.** 569 lines of noise, stepped
## heights, shore fades and skirts stood here and the user rejected the picture they made six times
## (2026-08-26). The shape is now authored — `tools/blender/island_build.py` builds it and exports
## `assets/terrain/island.glb`, and this function's whole job is to put that file on screen.
##
## ⚠ **The mesh carries its own colour in VERTEX COLOURS**, so there is no palette here either. What
## decides how the island looks lives in the Blender script, next to the shape it belongs to.
const ISLAND_SCENE := "res://assets/terrain/island.glb"
## ⚠ **The buildings arrive as one file with one node per kind**, and the game clones out of it. Loading
## a scene per building would be five imports for five boxes.
const BUILDINGS_SCENE := "res://assets/buildings/buildings.glb"
## The scatter — trees, rocks, bushes. One file, one node per kind, cloned out of.
const PROPS_SCENE := "res://assets/props/props.glb"

var _island: Node3D = null
var _builds: Node3D = null
var _props: Node3D = null


func _rebuild_terrain() -> void:
	if _world == null:
		return
	if _island != null:
		_island.queue_free()
		_island = null
	if battle == null:
		return
	var packed := load(ISLAND_SCENE) as PackedScene
	if packed == null:
		return
	_island = packed.instantiate() as Node3D
	# ⚠⚠ **The Z offset, and it is not a fudge.** glTF's Y-up conversion maps Blender +Y to Godot −Z,
	# so an island authored over 0..h in Blender arrives over −h..0 here. The Blender script already
	# reverses the row order (so north stays north); this slides it back into 0..h, where the sim's
	# tile coordinates are. Without it every body walks on open water beside the island.
	_island.position.z = float(battle.grid.h)
	_world.add_child(_island)
	# ⚠ **Vertex colours are OFF by default on an imported material.** Without this the island comes in
	# as flat white and every tone the Blender script decided is thrown away silently.
	_use_vertex_colours(_island)
	_outline(_island)
	_hand_the_sea_its_shoreline()
	_rebuild_buildings()
	_rebuild_props()


## **Puts the standing buildings on the ground.** ⚠ **Nothing is placed by eye**: the kind comes from
## the island file, the footprint comes from the building table, and the height comes from the tile the
## building stands on. All three are written by the two Blender runs, so a building cannot end up half
## a tile off or floating over a step.
##
## ⚠⚠ **This draws them and nothing else.** They do not block a body, they do not burn, and losing the
## run when the keep burns is not wired. Saying so here is cheaper than someone reading a picture of a
## keep as a keep that works.
func _rebuild_buildings() -> void:
	if _world == null:
		return
	if _builds != null:
		_builds.queue_free()
		_builds = null
	if battle == null:
		return
	var placed := Islands.builds()
	if placed.is_empty():
		return
	var packed := load(BUILDINGS_SCENE) as PackedScene
	if packed == null:
		return
	var lib := packed.instantiate()
	_builds = Node3D.new()
	_world.add_child(_builds)
	for row in placed:
		var d := row as Dictionary
		var kind := str(d["kind"])
		var src := lib.find_child(kind, true, false) as MeshInstance3D
		if src == null:
			continue
		var fp := Builds.footprint_of(kind)
		if fp == Vector2i.ZERO:
			continue
		var one := src.duplicate() as MeshInstance3D
		# The footprint's CENTRE, in tile units — the mesh is authored about its own centre, so a
		# building placed by its low corner would sit half a footprint off in both directions.
		var cx := float(d["x"]) + float(fp.x) * 0.5
		var cy := float(d["y"]) + float(fp.y) * 0.5
		var t := int(d["y"]) * battle.grid.w + int(d["x"])
		one.position = Vector3(cx, Islands.ground_h(battle.grid.level_of(t)), cy)
		_builds.add_child(one)
	# ⚠⚠ **NOT `_use_vertex_colours` here, and that call was the bug** (2026-08-26, the user: 「건물
	# 벽면이 이상함」). It exists for the ISLAND, whose mesh carries a colour per vertex. **The buildings
	# carry no colour attribute at all** — they are painted with one flat material per part — so turning
	# `vertex_color_use_as_albedo` on told the renderer to multiply their albedo by a vertex colour that
	# is not there, and the walls came out in wedges of bright and dark that met at the triangle seams.
	# ⚠ **The same mesh renders perfectly flat inside Blender**, which is what finally located it: the
	# geometry was never the problem, and two rounds were spent on normals and coplanar faces first.
	_outline(_builds)
	lib.free()


## **Tells the sea where the land is.** ⚠⚠ **This is what replaces the shore band that failed.** A ring
## built as geometry sat ON the water and read as a plate; the coastline is drawn by the sea itself now,
## and the only thing the sea needs for that is a distance-to-land map.
##
## Built once per island, on the CPU, at `Look.WATER_FIELD_SUBDIV` texels per tile. ⚠ **One texel per
## tile is not enough** — the foam then steps square at tile edges, which is the grid drawn back in
## water after the geometry stopped drawing it.
func _hand_the_sea_its_shoreline() -> void:
	if _sea == null or battle == null:
		return
	var g := battle.grid
	var sub := int(Look.WATER_FIELD_SUBDIV)
	var span := float(Look.WATER_FIELD_SPAN_TILES)
	var tw := g.w * sub
	var th := g.h * sub

	# ⚠⚠ **The REAL coastline, not the tile grid.** Coastal corners are cut and pushed when the island
	# is built, so a field measured to square tiles put a square wash around a coast that is not square
	# (2026-08-26, the user saw it before the code did). `Islands.coast()` is the line the mesh actually
	# ends on, exported beside the mesh by the same run that shaped it.
	var coast := Islands.coast()

	var img := Image.create(tw, th, false, Image.FORMAT_L8)
	if coast.is_empty():
		img.fill(Color(1.0, 1.0, 1.0))
	else:
		for py in th:
			for px in tw:
				var at := Vector2((float(px) + 0.5) / float(sub), (float(py) + 0.5) / float(sub))
				var best := span
				for seg in coast:
					var a := Vector2(float(seg[0]), float(seg[1]))
					var b := Vector2(float(seg[2]), float(seg[3]))
					var ab := b - a
					var len2 := ab.length_squared()
					# The nearest point ON the segment, clamped to its ends — measuring to the infinite
					# line would foam along the coast's continuation out into open sea.
					var u := 0.0 if len2 <= 0.0 else clampf((at - a).dot(ab) / len2, 0.0, 1.0)
					var d := at.distance_to(a + ab * u)
					if d < best:
						best = d
				var v := clampf(best / span, 0.0, 1.0)
				img.set_pixel(px, py, Color(v, v, v))

	var mat := _sea.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("land_field", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("field_size", Vector2(float(g.w), float(g.h)))
	mat.set_shader_parameter("field_span", span)
	mat.set_shader_parameter("foam", Look.COL_WATER_FOAM)
	mat.set_shader_parameter("foam_tiles", Look.WATER_FOAM_TILES)
	mat.set_shader_parameter("foam_speed", Look.WATER_FOAM_SPEED)
	mat.set_shader_parameter("foam_bands", Look.WATER_FOAM_BANDS)
	mat.set_shader_parameter("foam_sharp", Look.WATER_FOAM_SHARP)
	mat.set_shader_parameter("foam_break", Look.WATER_FOAM_BREAK)
	mat.set_shader_parameter("foam_break_scale", Look.WATER_FOAM_BREAK_SCALE)
	mat.set_shader_parameter("foam_lip_tiles", Look.WATER_FOAM_LIP_TILES)
	mat.set_shader_parameter("foam_lee", Look.WATER_FOAM_LEE)
	mat.set_shader_parameter("shallow", Look.COL_WATER_SHALLOW)
	mat.set_shader_parameter("shallow_tiles", Look.WATER_SHALLOW_TILES)


## **Dresses the island.** ⚠ Everything about where each prop goes was decided when the island was
## built; this reads the list and clones. **Nothing is randomised here** — a scatter that rolled dice at
## load time would give a different island every launch and no screenshot would mean anything.
func _rebuild_props() -> void:
	if _world == null:
		return
	if _props != null:
		_props.queue_free()
		_props = null
	if battle == null:
		return
	var placed := Islands.props()
	if placed.is_empty():
		return
	var packed := load(PROPS_SCENE) as PackedScene
	if packed == null:
		return
	var lib := packed.instantiate()
	_props = Node3D.new()
	_world.add_child(_props)
	for row in placed:
		var d := row as Dictionary
		var src := lib.find_child(str(d["kind"]), true, false) as MeshInstance3D
		if src == null:
			continue
		var one := src.duplicate() as MeshInstance3D
		var t := int(d["y"]) * battle.grid.w + int(d["x"])
		one.position = Vector3(
			float(d["x"]) + 0.5 + float(d.get("ox", 0.0)),
			Islands.ground_h(battle.grid.level_of(t)),
			float(d["y"]) + 0.5 + float(d.get("oy", 0.0)))
		one.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
		var sc := float(d.get("scale", 1.0))
		one.scale = Vector3(sc, sc, sc)
		_props.add_child(one)
	_outline(_props)
	lib.free()


## --- the drawn blob is GONE -------------------------------------------------------------------------
## ⚠⚠ **Deleted 2026-08-26, and the reason it existed was a wrong diagnosis.** A dark disc was laid flat
## under every prop and building because「the shadow map cannot resolve anything smaller than a cliff」.
## It could all along — what could not was a shadow map stretched over the camera's default `far` of
## 4000 tiles (see `Look.CAM_FAR_TILES`). With that fixed, real shadows land on the ground and the disc
## became the second shadow on every object: **round, soft, and pointing nowhere**, beside a hard one
## that points away from the sun. The user, seeing it: 「해 기준으로 그림자가 있어야 하는데 이게 좀 안
## 그런거 같음」.
## ⚠ **It also slid the WRONG WAY.** The disc was offset by `(sin(yaw), cos(yaw))`, which is toward the
## sun; the cast shadow goes the other way. The offset was small enough that nobody caught it for the
## whole time the disc was the only shadow there was.
## ⚠⚠ **Do not bring it back as a fallback.** One sun, one shadow per object, is what the user chose
## (2026-08-26: 「해 하나가 맞는듯」), and a second shadow with no direction is what that decision removes.


## **Draws a mesh a second time, inverted and swollen, in near-black.** ⚠⚠ **This is the Bad North
## outline**, and the talk describes exactly this: the mesh inside out, pushed out along its normals, in
## a dark colour, with the real mesh drawn over it. What survives is a rim wherever the silhouette turns
## away — a contour with no post-process, no second camera and no edge detection.
##
## ⚠ **`next_pass` and not a duplicated node.** A second `MeshInstance3D` would double the node count and
## have to be kept in step with every move; a next pass is the same draw call's second half and cannot
## fall out of sync.
func _outline(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				var sm := m as StandardMaterial3D
				# ⚠ **Only once.** These materials come out of a shared imported scene, so a second call
				# would chain another shell onto the first and the outline would thicken every rebuild.
				if sm == null or sm.next_pass != null:
					continue
				var shell := StandardMaterial3D.new()
				shell.albedo_color = Look.COL_OUTLINE
				# Unshaded: an outline that takes the light goes pale on the sunny side and stops being
				# a line. It is ink, not a surface.
				shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				# ⚠ **Front faces culled, so only the BACK of the swollen shell is drawn** — that is the
				# whole trick. Without it the shell covers the object entirely.
				shell.cull_mode = BaseMaterial3D.CULL_FRONT
				shell.grow = true
				shell.grow_amount = Look.OUTLINE_GROW
				# It must not throw a shadow of its own: it is a shell around something that already does.
				sm.next_pass = shell
	for c in n.get_children():
		_outline(c)


func _use_vertex_colours(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					(m as StandardMaterial3D).vertex_color_use_as_albedo = true
	for c in n.get_children():
		_use_vertex_colours(c)


## Whether the summon band is showing. **Survives the terrain's deletion** — it is a fact about the
## plan, not about the ground, and it was only ever sitting in that section by accident.
func _band_on() -> bool:
	return battle != null and not battle.committed()



# --- the bodies, as billboards ------------------------------------------------------------------------

## A pooled `Sprite3D`. **Pooled and never freed per frame**: making and freeing forty nodes a frame is
## the one shape that turns a MultiMesh's saving straight back into garbage.
func _sprite() -> Sprite3D:
	if _sprites_used < _sprites.size():
		var reused := _sprites[_sprites_used]
		_sprites_used += 1
		reused.visible = true
		return reused
	var s := Sprite3D.new()
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# ⚠ **Both of these, or the animals are cardboard.** DISCARD gives the sprite a real depth value so
	# a wolf behind a cliff is hidden by it and casts a shaped shadow instead of a rectangle; without
	# it a billboard is one transparent quad that neither occludes nor is occluded.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_world.add_child(s)
	_sprites.append(s)
	_sprites_used += 1
	return s


func _hull_box() -> MeshInstance3D:
	if _hulls_used < _hulls.size():
		var reused := _hulls[_hulls_used]
		_hulls_used += 1
		reused.visible = true
		return reused
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	# ⚠⚠ **Unshaded, like the summon ring and like the bodies standing on it.** `COL_BOAT` is a light
	# tan measured on a FLAT BOARD, and under this world's sun plus fill plus ambient a 0.85 albedo
	# lands well past 1.0 — every hull rendered as **a solid white rectangle**, which is what the first
	# capture with big bodies made impossible to miss. A boat is the plan's own mark on the water and
	# has to read the same at every sun angle, which is the ring's argument one object over.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	_world.add_child(m)
	_hulls.append(m)
	_hulls_used += 1
	return m


## Puts one billboard at a body's feet. `centre_px` is the same world px the flat board drew at, so
## every offset that already went through `_body_offset_of` follows across for free.
##
## ⚠⚠ **`bleed_sec` IS MIXED IN AFTER THE FACTION TINT AND THAT ORDER IS THE WHOLE OF WHETHER IT CAN
## BE SEEN.** Tinting a bled colour pulls it 45% back toward white and throws most of the pull away:
## measured, the body's HUE did not move at all and only its brightness fell 27%, which reads as
## shade rather than as blood. The side's colour is resolved first and the blood goes on top of it.
func _put_body(centre_px: Vector2, radius: float, colour: Color, squash: Vector2, tex: Texture2D,
		bleed_sec: float) -> float:
	var s := _sprite()
	var pic: Texture2D = tex if tex != null else _tex_body
	s.texture = pic
	var team := Look.beast_tint(colour) if tex != null else colour
	s.modulate = Look.bleeding(team, bleed_sec)
	var wide := radius * Look.BEAST_SPRITE_W_RATIO if tex != null else radius * 2.0
	var sx := wide * squash.x / float(pic.get_width())
	var sy := sx * squash.y / maxf(squash.x, 0.001)
	s.scale = Vector3(sx, sy, 1.0)
	var tall := float(pic.get_height()) * sy / Look.TILE_PX
	# ⚠⚠ **`_stand_h` AND NOT `_ground_h`, SO A BODY WALKS UP THE STAIR INSTEAD OF POPPING UP IT.**
	# `_ground_h` is one number per tile, which is right for the RULES and wrong for the feet: a stair
	# run climbs a whole storey across its tiles, so a body standing on one would float half a storey
	# at the mouth and sink half a storey at the head. **The sim's own height is untouched** — see
	# `Grid.surface_h`, which exists next to `height_at` precisely so the drawn ground and the measured
	# ground can differ without either pretending to be the other.
	var foot := _stand_h(centre_px / Look.TILE_PX) + Look.BODY_LIFT_PX / Look.TILE_PX
	s.position = Vector3(centre_px.x / Look.TILE_PX, foot + tall * 0.5, centre_px.y / Look.TILE_PX)
	# ⚠⚠ **The TOP is returned and it is not `radius * 2`.** A wolf is 55 x 40 and a caveman 36 x 40:
	# sized by WIDTH off the same radius, the man stands half again as tall as the animal, which is
	# right and is exactly why nothing that hangs above a body may compute its own height from the
	# radius. The bar did, and it landed across the caveman's face the first time he was on screen.
	return foot + tall


## The two halves of an HP bar, standing above the body rather than below it — a bar UNDER a
## billboard is inside the ground the billboard is standing on.
func _put_hp(centre_px: Vector2, top_y: float, type_id: int, frac: float) -> void:
	var rects := _hp_rects(centre_px, type_id, frac)
	var back: Rect2 = rects[0]
	var fill: Rect2 = rects[1]
	var y := top_y + Look.HP_BAR_GAP_PX * 2.0 / Look.TILE_PX
	for k in 2:
		var r: Rect2 = back if k == 0 else fill
		if r.size.x <= 0.0:
			continue
		var s := _sprite()
		s.texture = _tex_flat
		s.modulate = Look.hp_bar_colour(k == 1)
		s.scale = Vector3(r.size.x, r.size.y, 1.0)
		# Left edges share an origin so a short fill shrinks from the right, exactly as the flat bar
		# did — centring the fill would make a wounded body read as two bars.
		var cx := r.position.x + r.size.x * 0.5
		s.position = Vector3(cx / Look.TILE_PX, y + float(k) * 0.001, centre_px.y / Look.TILE_PX)


## Every body, every frame. **This is what pass 6, 7 and 8 of the old `_draw` were**, minus the marks
## that are not ported yet.
func _paint_bodies() -> void:
	_sprites_used = 0
	_hulls_used = 0
	if battle == null or army == null or battle.grid == null:
		_hide_unused()
		return

	# Enemies first, allies after, so an ally on the same tile reads on top of what it is fighting.
	# ⚠ **In 3D the depth buffer decides that now, not the order** — the order is kept because it costs
	# nothing and because whoever reads this next should see where the rule went.
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] == 0:
			continue
		var et := int(battle.enemy_type[e])
		var ekey := "e%d" % e
		var ecentre := Look.tile_point_px(battle.enemy_pos[e]) + _body_offset_of(ekey)
		var eradius := Look.body_radius_of(et)
		# ⚠ **The bleed is handed DOWN rather than mixed in here**, so `_put_body` can put it on after
		# the faction tint — see that function's own header for why the other order is invisible.
		var etop := _put_body(ecentre, eradius,
			Look.body_colour_of(true).lerp(Look.COL_FLASH, _flash_of(ekey)),
			_gait_squash(ekey), _body_tex(ekey, et, _facing_of(e, true).x >= 0.0),
			battle.status_left(Rules.Status.BLEED, e))
		_put_hp(ecentre, etop, et, battle.enemy_hp[e] / Rules.hp_of(et))
		_put_halo(ekey, ecentre, Look.sprite_half_px(et), etop)

	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		_put_soldier(i, battle.soldier_pos[i])

	# The boats: a hull on the water and its passengers standing on it.
	#
	# ⚠⚠ **THIS USED TO SKIP EVERY BOAT BEFORE THE COMMIT AND THE USER CAUGHT IT** (2026-08-25:
	# 「배를 놨으면 그게 바다에 보여야할듯」). The reason written here was *"a boat that has not left is
	# its PLAN, and thirteen hulls stacked on one harbour is a blob that says nothing"* — and that was
	# TRUE OF A GESTURE THAT NO LONGER EXISTS. It was the harbour drag: `Battle.send` starts every boat
	# at `path[0]`, the harbour, so thirteen sends really did pile thirteen hulls on one tile. The drag
	# is deleted and the shell has no caller for `send` at all; the sea summon starts a boat at
	# `path[0]` too, and for a summon **that is the water tile the player pressed**. Thirteen summons
	# are thirteen hulls in thirteen places.
	# ⇒ **A placed boat is drawn from the moment it is placed.** What is drawn before the commit and
	# after it is now the same picture, which is also the honest one: the boat EXISTS in `battle.boats`
	# the instant the press lands, and a plan that shows nothing for a body it has already spent is the
	# screen disagreeing with the sim.
	for bk in battle.boats.size():
		var boat: Dictionary = battle.boats[bk]
		var anchor := Look.tile_point_px(Vector2(boat["pos"]))
		var arrived := float(boat["t"]) * float(boat["speed"]) + Rules.EPS >= float(boat["dist"])
		var waiting := int(boat["phase"]) == Battle.Phase.OUTBOUND and arrived
		var hull_col := Look.COL_BOAT
		if waiting:
			hull_col = hull_col.lerp(Look.COL_HULL_WAIT, _wait_blend())
		_put_hull(anchor, hull_col)
		var soldiers: Array = boat["soldiers"]
		for k in soldiers.size():
			_put_soldier(int(soldiers[k]), Vector2(boat["pos"]))

	_paint_ghosts()
	_hide_unused()


## Item 3 of the twelve, and WITHOUT IT THAT ITEM DOES NOT EXIST — `COL_HIT_HALO`'s own comment says
## so: a body here is a 2 px outline and a 3 px dot, so tinting it repaints two pixels of border and
## nothing else. The halo is the area the hit is actually seen on.
func _put_halo(key: String, centre_px: Vector2, radius: float, top_y: float) -> void:
	var h := _halo_of(key)
	if h <= 0.0:
		return
	var col := Look.COL_HIT_HALO
	col.a *= h
	# ⚠⚠ **`radius` IS THE DRAWN HALF-WIDTH, not the sim radius, and it was the sim radius until
	# 2026-08-25.** 1.35 x a wolf's 14 px put the halo 18.9 px out — INSIDE a 49 px picture, so the
	# thing that says 「this one was just hit」 was drawn underneath the body. It is 33.1 px now and
	# clears the picture on every side. **This is the death burst's own lesson, one effect over.**
	# Hung at the body's MIDDLE, which is half its own height and not one radius: see `_put_body`.
	var mid := Vector3(centre_px.x / Look.TILE_PX,
		(_ground_y_px(centre_px) + top_y) * 0.5, centre_px.y / Look.TILE_PX)
	_a_disc(mid, radius * Look.HIT_HALO_MUL, col)


## The picture a body wears. **One place**, so the ghost, the soldier on a deck and the body ashore
## cannot end up wearing three different things.
##
## ⚠⚠ **`is_enemy` IS GONE, and its absence is the point.** The argument existed because one table row
## served two species — the player's ranged slot borrowed the enemy crow's row — so a row had to
## answer with two pictures depending on who asked. `Rules.UNITS` has a row per species now, so there
## is nothing left for it to select between. Which side a body is on still reaches the screen, through
## `Look.body_colour_of`; it is a TINT and not a different animal.
func _beast_tex(type_id: int, facing_right: bool) -> Texture2D:
	var pool: Array[Texture2D] = _tex_facing_r if facing_right else _tex_facing_l
	if type_id < 0 or type_id >= pool.size():
		return null
	return pool[type_id]


## ⚠ **Static so it can run in a member initialiser**, which is where the ten hand-named `load()`
## calls it replaces used to run. `null` for an empty path rather than a missing entry: the array is
## indexed by unit row and a short one would fault on the last species instead of drawing a square.
static func _load_beast_tex(facing_right: bool) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for ty in Look.BEAST_TEX.size():
		var path := Look.beast_tex_path(ty, facing_right)
		out.append(null if path.is_empty() else load(path) as Texture2D)
	return out


## Every strip every row declares, loaded once. **Static for the same reason `_load_beast_tex` is** —
## it runs in a member initialiser. The loop walks `Anim` rather than a list of animated species, so a
## row that declares nothing contributes an empty strip and costs no branch anywhere downstream.
static func _load_beast_anim(facing_right: bool) -> Array:
	var out := []
	for ty in Look.BEAST_TEX.size():
		var per_anim := []
		for anim in Look.ANIM_NAME.size():
			var strip: Array[Texture2D] = []
			for f in Look.beast_anim_frames(ty, anim):
				strip.append(load(Look.beast_frame_path(ty, anim, f, facing_right)) as Texture2D)
			per_anim.append(strip)
		out.append(per_anim)
	return out


## Row `type_id`'s `anim` strip facing `facing_right`, empty where there is none.
func _anim_strip(type_id: int, anim: int, facing_right: bool) -> Array:
	var pool: Array = _tex_anim_r if facing_right else _tex_anim_l
	if type_id < 0 or type_id >= pool.size():
		return []
	var per_anim: Array = pool[type_id]
	if anim < 0 or anim >= per_anim.size():
		return []
	return per_anim[anim]


## How long row `type_id`'s `anim` strip runs end to end, **0 s for a row that has none.** The bite
## clock is started from this and read back against it, so the strip's length lives in one place — a
## literal at the start and a divisor at the read is the pair that drifts and leaves the last frame
## either unreachable or held forever.
func _anim_sec(type_id: int, anim: int) -> float:
	return float(Look.beast_anim_frames(type_id, anim)) * Look.BEAST_FRAME_SEC


## The picture a body wears THIS frame: its bite strip while a bite is running, its walk strip the
## rest of the time, and **its standing picture whenever the strip it asked for is empty** — which is
## the whole of how eight species keep working with no frames of their own.
##
## ⚠⚠ **The walk phase is TIME, not distance, and that is the opposite of `_gait_squash` one clock
## over.** The squash is a stride and is right to stop dead with the body. The legs are not: phased on
## distance they made a body in contact the only completely motionless thing on the island, which is
## what the user was looking at when he said 「그냥 붙어서 그냥 벌렁벌렁하는 거밖에 없어」. A standing
## body keeps cycling its legs and `_idle_offset` is what says it is standing.
func _body_tex(key: String, type_id: int, facing_right: bool) -> Texture2D:
	var idle := _beast_tex(type_id, facing_right)
	if not _body.has(key):
		return idle
	var b: Dictionary = _body[key]
	var bite := float(b["bite"])
	var anim := Look.Anim.BITE if bite > 0.0 else Look.Anim.WALK
	var strip := _anim_strip(type_id, anim, facing_right)
	if strip.is_empty():
		return idle
	var at := 0
	if anim == Look.Anim.BITE:
		# The clock runs DOWN, so `1 - left/whole` is how far in the strip is. Clamped at both ends:
		# `int()` of exactly 1.0 lands one past the last frame, and the last frame is the one the
		# mouth is widest in — a bite that never reaches it is a bite nobody sees.
		at = clampi(int((1.0 - bite / _anim_sec(type_id, anim)) * float(strip.size())),
			0, strip.size() - 1)
	else:
		at = int(float(b["walk"]) / Look.BEAST_FRAME_SEC) % strip.size()
	return strip[at] as Texture2D


## One soldier at a tile position, ashore or on a deck. Both call sites want the same body, the same
## gait and the same facing, and splitting them was how the deck soldier lost its HP bar once already.
func _put_soldier(i: int, at: Vector2) -> void:
	var st := int(army.type_id[i])
	var skey := "s%d" % i
	var sradius := Look.body_radius_of(st)
	var scentre := Look.tile_point_px(at) + _body_offset_of(skey)
	# The wolf faces what it is walking at. `_facing_of` returns RIGHT when there is no target, so an
	# idle body faces right rather than flipping on a zero vector.
	var stex := _body_tex(skey, st, _facing_of(i, false).x >= 0.0)
	# ⚠ **0.0, and not a lookup**: `battle`'s status arrays are per ENEMY. An allied body never carries
	# one, and `_hit_soldiers` has no `_apply_statuses` twin — see `battle.gd`.
	var stop := _put_body(scentre, sradius,
		Look.body_colour_of(false).lerp(Look.COL_FLASH, _flash_of(skey)),
		_gait_squash(skey), stex, 0.0)
	_put_hp(scentre, stop, st, army.hp[i] / army.max_hp_of(i))
	_put_halo(skey, scentre, Look.sprite_half_px(st), stop)


func _put_hull(anchor: Vector2, colour: Color) -> void:
	var r := _hull_rect(anchor)
	var m := _hull_box()
	var box: BoxMesh = m.mesh
	box.size = Vector3(r.size.x / Look.TILE_PX, Look.HULL_H_TILES, r.size.y / Look.TILE_PX)
	var mat: StandardMaterial3D = m.material_override
	mat.albedo_color = colour
	m.position = Vector3(anchor.x / Look.TILE_PX,
		Look.TERRAIN_H_WATER + Look.HULL_H_TILES * 0.5,
		anchor.y / Look.TILE_PX)


## ⚠ **Hidden, never freed.** A pool that shrinks is a pool that reallocates on the next busy frame,
## and a stale sprite left visible is a body that died and stayed on screen — the exact failure the
## per-frame drawer could not have.
func _hide_unused() -> void:
	for k in range(_sprites_used, _sprites.size()):
		_sprites[k].visible = false
	for k in range(_hulls_used, _hulls.size()):
		_hulls[k].visible = false


# --- the effect drawers, carried across the move unchanged -------------------------------------------
## ⚠⚠ **Everything below this line is the file as it was.** The effects were never drawing code: they
## are a little simulation of their own with its own clock, and moving the picture into 3D did not
## touch one line of it. That is why `_fx` is still filling every frame while nothing paints it.

enum FxKind { SHOT, SPARK, BURST, AREA, LAND, REFUSE }

## Called by `game.gd` whenever a slot is armed or disarmed, whenever the cursor moves with one armed,
## and on the release. `slot == -1` clears the whole aim. **0 draw calls** — the same shape the
## deleted `set_drag` had, and for the same reason: one call site for three events means the two fields cannot
## disagree.
## **Lights up the MAT the cursor is on.** The shell still hands a TILE -- which mat that belongs to
## is looked up here, so nothing outside this file has to know how the ground is divided.
##
## ⚠⚠ **The unit is the 2x2 piece and that is the user's call** (2026-08-27: 「이번에 긐 4칸짜리를 기준으로 마우스 올리면 동작하게 해줘」).
## ⚠ **Short-circuits on the MAT and not the tile**, so crossing a tile line inside one mat rebuilds
## nothing -- which is what makes a per-mat mesh affordable at all.
## ⚠ **Lifted higher than the mat it covers** (`HOVER_PLATE_LIFT_TILES` against `WASH_LIFT_TILES`):
## the two are the same shape in the same place, and the mark has to win.
func set_hover_tile(t: int) -> void:
	var c := -1
	if t >= 0 and t < _wash_cell.size():
		c = int(_wash_cell[t])
	if c == _hover_cell:
		return
	_hover_cell = c
	if _hover == null:
		return
	if c < 0 or battle == null or battle.grid == null:
		_hover.visible = false
		return
	var grid: Grid = battle.grid
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for ty in grid.h:
		for tx in grid.w:
			if int(_wash_cell[ty * grid.w + tx]) != c:
				continue
			_append_ground_quad(verts, uvs, grid, tx, ty, Look.HOVER_PLATE_LIFT_TILES)
	if verts.is_empty():
		_hover.visible = false
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_hover.mesh = mesh
	_hover.visible = true



func set_summon_aim(slot: int, tile: int) -> void:
	_summon_slot = slot
	_summon_aim = tile

## One mark at `at_px` (world px) saying the sim REFUSED this drop. **0 draw calls** — it pushes one
## entry into the transient drawer and the ground-ring block paints it on the next frame, the same
## path every other transient takes.
##
## ⚠⚠ **The shell calls this off `Battle.send`'s own -1 and off nothing else.** A view that decided
## for itself whether a tile was refusable would be a second copy of `grid.home_harbour_for`, and two
## copies of one predicate is exactly what the deleted green wash was trusted NOT to be. Driving it
## from the sim's answer is how the honesty guarantee survives the wash it used to belong to
## (`speed-off-open-landing`, 2.5).
##
## `delay` is 0.0: the mark has to land on the frame of the press, not one beat after it — Swink's
## bound on input-to-response is under 100 ms and `REFUSE_MARK_SEC` is the whole of the effect.
func note_refusal(at_px: Vector2) -> void:
	_fx.append({
		"kind": FxKind.REFUSE,
		"age": 0.0,
		"delay": 0.0,
		"life": Look.REFUSE_MARK_SEC,
		"at": at_px,
	})

## **The grid's own size in tiles, and the one place anything here asks for it.**
##
## ⚠⚠ **Nothing that draws or clamps may read `Look.GRID_W` / `GRID_H` directly any more.** They were
## `const 48` / `32` and `_draw` and `_clamp_cam` read them instead of the grid, so **two maps of
## different sizes were unrepresentable** — a long map and a small one could not both exist. The
## constants survive only as the answer for a view that has no grid yet (`setup(Battle.new(), …)`, and
## the frames between the shell building the node and opening an island), and that fallback is what
## keeps every camera literal measured against 48 x 32 still true.
func _map_tiles() -> Vector2i:
	if battle != null and battle.grid != null and battle.grid.w > 0 and battle.grid.h > 0:
		return Vector2i(battle.grid.w, battle.grid.h)
	return Vector2i(Look.GRID_W, Look.GRID_H)

## The part of a boat's route it has NOT sailed yet, in canvas px: where the hull is standing now,
## then every waypoint strictly past the segment it is on. **Draw 0** — it builds geometry and hands
## it to `_paint_route`.
##
## ⚠⚠ **`leg` is read off the SIM and the walk is never re-derived here.** `_phase_boats` advances it
## as the boat moves; a view that found its own segment by re-walking `cum` would be the same fact
## computed in two places, and the two would drift the first time one of them changed — which is the
## failure this file's own deleted `_deck_slots` comment records. The drawn line therefore cannot show
## a boat sailing water it has already crossed, because the sim is what decides what is behind it.
func _route_ahead(boat: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(Look.tile_point_px(Vector2(boat["pos"])))
	var path: PackedVector2Array = boat["path"]
	for k in range(int(boat["leg"]) + 1, path.size()):
		out.append(Look.tile_point_px(path[k]))
	return out

func _tile_xy(tile: int) -> Vector2i:
	var w := battle.grid.w
	return Vector2i(tile % w, tile / w)

## The hull rectangle, centred on world point `at` (`boat["pos"]`). **One size for every boat**: the
## capacity column died with `Rules.BOATS` (`plan-then-watch`, 결정 14R), a boat carries the one
## soldier that was dragged onto it, and nothing distinguishes two boats. `BOAT_SLOT_PX + 2 *
## BOAT_HULL_PAD_PX` = 46 px wide.
##
## ⚠ **It lost its `boat` and `slot` arguments, and both are gone rather than defaulted.** There is no
## fleet slot to index, and there is no second hull at one anchor to shift sideways — a boat is drawn
## only after the commit, by which point it is moving.
func _hull_rect(at: Vector2) -> Rect2:
	var w := Look.BOAT_SLOT_PX + 2.0 * Look.BOAT_HULL_PAD_PX
	var h := Look.BOAT_HULL_H_PX
	return Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))

## Where the wolf goes: a rectangle centred on the body, **as wide as `BEAST_SPRITE_W_RATIO` body
## radii**, with the height taken from the texture's own aspect so the animal is never stretched.
##
## `squash` is the SAME gait vector the rounded square was squashed by, applied to the rectangle's
## size about its centre. ⚠ **Dropping it here would have made the ally the only thing on the field
## that stands still while it fights** — 「붙어서 가만히 있으면 재미가 죽는다」 — and no per-function
## count or argument in `net_draw_leaf` would have changed.
func _beast_rect(centre: Vector2, radius: float, squash: Vector2, tex: Texture2D) -> Rect2:
	var w := radius * Look.BEAST_SPRITE_W_RATIO * squash.x
	var h := w * float(tex.get_height()) / float(tex.get_width()) * squash.y
	return Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))

## Back rectangle first, filled rectangle second. The fill shrinks from the right, so the bar's left
## edge stays put and a body's HP can be compared to its neighbour's at a glance.
func _hp_rects(centre: Vector2, type_id: int, frac: float) -> Array:
	var origin := Look.hp_bar_origin_px(centre, type_id)
	var span := Look.hp_bar_size_px()
	var f := clampf(frac, 0.0, 1.0)
	return [Rect2(origin, span), Rect2(origin, Vector2(span.x * f, span.y))]

## Which way a body is pointing: toward its current target, and to the right when it has none — a
## zero vector normalised is zero, which would collapse a facing mark to a point and aim a lunge
## nowhere while every check about them still passed.
##
## **`is_enemy` is not decoration.** Two of the three types whose range is 0 — the bison and the lion
## — are enemies, and they are exactly the ones that lunge, so a soldier-only version of this
## function would aim every enemy lunge to the right.
func _facing_of(i: int, is_enemy: bool) -> Vector2:
	var here := Vector2.ZERO
	var there := Vector2.ZERO
	if is_enemy:
		var aim := int(battle.enemy_target[i])
		if aim < 0 or not battle.is_hittable(aim):
			return Vector2.RIGHT
		here = battle.enemy_pos[i]
		there = battle.soldier_pos[aim]
	else:
		var tgt := int(battle.soldier_target[i])
		if tgt < 0 or tgt >= battle.enemy_alive.size() or battle.enemy_alive[tgt] == 0:
			return Vector2.RIGHT
		here = battle.soldier_pos[i]
		there = battle.enemy_pos[tgt]
	var away := there - here
	if away.length() <= Rules.EPS:
		return Vector2.RIGHT
	return away.normalized()

## Ages both drawers by one frame and drops what has finished, then walks every body that can be on
## screen so the gait phase advances by DISTANCE rather than by time.
##
## Creating the per-body entries is done HERE and nowhere else. `_drain_events` deliberately refuses
## to create one: a body with no entry this frame is a body that is not on screen this frame, and
## flashing a corpse is the one thing item 3 must not do.
func _fx_step(delta: float) -> void:
	var live := []
	for raw_fx in _fx:
		var fx: Dictionary = raw_fx
		fx["age"] = float(fx["age"]) + delta
		if float(fx["age"]) < float(fx["delay"]) + float(fx["life"]):
			live.append(fx)
	_fx = live


	for key: String in _body:
		var b: Dictionary = _body[key]
		b["flash"] = maxf(0.0, float(b["flash"]) - delta)
		b["knock"] = maxf(0.0, float(b["knock"]) - delta)
		b["lunge"] = maxf(0.0, float(b["lunge"]) - delta)
		b["bite"] = maxf(0.0, float(b["bite"]) - delta)
		# ⚠ **Advanced unconditionally, and NOT inside the `moved` test below.** That test is the gait's
		# and it is right there; putting the legs under it is the rule 「움직이지 않는 몸은 애니메이션
		# 하지 않는다」, which is what left a body in melee frozen. This clock never stops.
		b["walk"] = float(b["walk"]) + delta

	if battle == null or army == null:
		return

	# Every alive enemy and every HITTABLE soldier — a soldier still aboard a boat can be shot by a
	# coastal crow, and without an entry that hit would have nothing to flash.
	var walkers := []
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] != 0:
			walkers.append(["e%d" % e, battle.enemy_pos[e],
				Look.sprite_half_px(int(battle.enemy_type[e]))])
	for i in battle.soldier_state.size():
		if battle.is_hittable(i):
			walkers.append(["s%d" % i, battle.soldier_pos[i],
				Look.sprite_half_px(int(army.type_id[i]))])

	for raw_walker in walkers:
		var walker: Array = raw_walker
		var key: String = walker[0]
		var here: Vector2 = walker[1]
		if not _body.has(key):
			_body[key] = {
				"flash": 0.0,
				"knock": 0.0,
				"knock_dir": Vector2.RIGHT,
				"lunge": 0.0,
				"lunge_dir": Vector2.RIGHT,
				"push": 0.0,
				# Seconds left of a bite, and the strip is read off how far in that is. 0 is "not
				# biting" and is also what a species with no bite strip is pinned at forever.
				"bite": 0.0,
				# Seconds this body has existed, which is what the walk strip is phased on. ⚠ **The
				# start is scattered by the key's hash**, the same trick `_idle_offset` uses: a pack
				# that steps in lockstep reads as one animal rather than as five. One second covers
				# more than any strip, so every phase is reachable.
				"walk": float(absi(key.hash()) % 1000) / 1000.0,
				"gait": 0.0,
				"head": Vector2.RIGHT,
				"last": here,
				# How wide this body is DRAWN, so the knock and the sway are sized off the picture and
				# not off the sim radius. Looked up once — a body's species never changes.
				"half": float(walker[2]),
				# Seconds since it last moved. **The gait phases on DISTANCE and so stops dead when a
				# body stops; this is what carries the other half.**
				"still": 0.0,
			}
		var b: Dictionary = _body[key]
		var last: Vector2 = b["last"]
		var moved := here.distance_to(last)
		b["still"] = 0.0 if moved > Rules.EPS else float(b["still"]) + delta
		if moved > Rules.EPS:
			# Positions are in TILES and so is the period, so the two divide directly. Phase on
			# distance is the whole of "it must not slide": a body that does not move does not
			# animate, and no amount of time passing changes that.
			b["gait"] = fposmod(
				float(b["gait"]) + TAU * moved / Look.GAIT_PERIOD_TILES, TAU)
			b["head"] = (here - last).normalized()
		b["last"] = here

## Turns one frame of sim FACTS into effects. Everything geometric is frozen here, on the frame the
## fact happened, because every one of these outlives the frame that produced it.
func _drain_events() -> void:
	if battle == null or army == null:
		return
	var born := []
	for raw_ev in battle.events:
		var ev: Dictionary = raw_ev
		var kind := int(ev["kind"])

		if kind == Battle.Event.LAND:
			if Look.fx_gain_of(7) > 0.0:
				born.append({
					"kind": FxKind.LAND,
					"age": 0.0,
					"delay": 0.0,
					"life": Look.LAND_RING_SEC,
					"at": Look.tile_point_px(battle.soldier_pos[int(ev["id"])]),
				})
			continue

		if kind == Battle.Event.DEATH:
			if Look.fx_gain_of(4) <= 0.0:
				continue
			var did := int(ev["id"])
			var dead_enemy: bool = ev["is_enemy"]
			var dtype := int(battle.enemy_type[did]) if dead_enemy else int(army.type_id[did])
			var dpos: Vector2 = battle.enemy_pos[did] if dead_enemy else battle.soldier_pos[did]
			born.append({
				"kind": FxKind.BURST,
				"age": 0.0,
				"delay": 0.0,
				"life": Look.BURST_SEC,
				"at": Look.tile_point_px(dpos),
				"radius": Look.body_radius_of(dtype),
				"colour": Look.body_colour_of(dead_enemy),
			})
			continue

		if kind != Battle.Event.ATTACK:
			continue

		var from_id := int(ev["from"])
		var from_enemy: bool = ev["from_enemy"]
		var to_id := int(ev["to"])
		var atk_type := int(battle.enemy_type[from_id]) if from_enemy else int(army.type_id[from_id])
		var tgt_type := int(army.type_id[to_id]) if from_enemy else int(battle.enemy_type[to_id])
		var atk_tile: Vector2 = battle.enemy_pos[from_id] if from_enemy \
			else battle.soldier_pos[from_id]
		var tgt_tile: Vector2 = battle.soldier_pos[to_id] if from_enemy \
			else battle.enemy_pos[to_id]
		var atk_px := Look.tile_point_px(atk_tile)
		var tgt_px := Look.tile_point_px(tgt_tile)
		var atk_key := ("e%d" if from_enemy else "s%d") % from_id

		# **The reaction is delayed by exactly the tracer's flight time.** The sim landed the damage
		# on the firing frame, so without this the target flashes and flinches before the bullet has
		# left the muzzle — the one thing item 1's own spec calls a lie about time.
		#
		# ⚠ **Tracer-vs-lunge reads the ATTACKER'S OWN reach, not the type's base range.** A soldier
		# is the one side of this that can carry a fitted 머리 part, and `army.range_of(from_id)` is
		# what combat itself throws that soldier's blow with — `Rules.range_of(atk_type)` alone would
		# play the melee lunge for a body that just became ranged, pushing it toward a target it
		# never walked to. Enemies stay type-keyed, same as everywhere else this round.
		var atk_reach := army.range_of(from_id) if not from_enemy else Rules.range_of(atk_type)
		var reaction := 0.0
		if atk_reach > 0.0:
			reaction = Look.SHOT_SEC
			if Look.fx_gain_of(1) > 0.0:
				born.append({
					"kind": FxKind.SHOT,
					"age": 0.0,
					"delay": 0.0,
					"life": Look.SHOT_SEC,
					"from": atk_px,
					"to": tgt_px,
				})
		else:
			var facing := _facing_of(from_id, from_enemy)
			var r_self := Look.body_radius_of(atk_type)
			# The push is capped at `gap + LUNGE_BITE_PX` rather than being a flat distance: the grid
			# guarantees one body per tile, so the gap is 40 px or 56.6 px and a flat push drove the
			# lion 33.6 px into a body 40 px away and swallowed it whole. With the cap the worst
			# overlap in any pairing is exactly LUNGE_BITE_PX, by construction.
			var gap := maxf(0.0,
				atk_px.distance_to(tgt_px) - r_self - Look.body_radius_of(tgt_type))
			# ⚠⚠ **`sprite_half_px` and not `r_self`.** The ratio is unchanged; what it multiplies is.
			# 0.55 of a wolf's SIM radius is 7.7 px of lunge on a 49 px picture — the fraction of the
			# body it was worth on the flat board, where a body WAS its radius, has more than halved.
			var push := minf(Look.LUNGE_PUSH_RATIO * Look.sprite_half_px(atk_type),
				gap + Look.LUNGE_BITE_PX) * Look.fx_gain_of(2)
			if _body.has(atk_key):
				var ab: Dictionary = _body[atk_key]
				ab["lunge"] = Look.LUNGE_SEC
				ab["lunge_dir"] = facing
				ab["push"] = push
				# ⚠⚠ **The mouth and the body start on ONE event and on one line of it.** Started
				# anywhere else — off a cooldown, off the target's flash — the two would be two
				# clocks measuring the same blow, and the pair that drifts is the pair that reads
				# as a wolf snapping at nothing. **0 s for a species with no bite strip**, so this
				# costs nothing and says nothing for the other eight.
				ab["bite"] = _anim_sec(atk_type, Look.Anim.BITE)
			if Look.fx_gain_of(2) > 0.0:
				# The contact point is frozen at the body edge AS IT WILL BE at the peak of the
				# lunge, `r_self + push` out — not at `r_self`. The shards are seen half a lunge
				# later, when the body really is that far forward, so freezing the un-pushed edge
				# would root them inside the striker.
				born.append({
					"kind": FxKind.SPARK,
					"age": 0.0,
					"delay": Look.LUNGE_SEC * 0.5,
					"life": Look.SPARK_SEC,
					"at": atk_px + facing * (r_self + push),
					"facing": facing,
				})

		var area := float(ev["area"])
		if area > 0.0 and Look.fx_gain_of(5) > 0.0:
			born.append({
				"kind": FxKind.AREA,
				"age": 0.0,
				"delay": 0.0,
				"life": Look.AREA_RING_SEC,
				"at": tgt_px,
				"radius": area * Look.TILE_PX,
			})

		var victims := [to_id]
		for raw_splash in ev["splash"]:
			victims.append(int(raw_splash))
		for raw_victim in victims:
			var v := int(raw_victim)
			var vkey := ("s%d" if from_enemy else "e%d") % v
			if not _body.has(vkey):
				continue
			var vb: Dictionary = _body[vkey]
			# Age is RESET, never stacked. A second entry would multiply the halo's alpha until the
			# body was simply white, and the Dictionary key makes stacking structurally impossible.
			vb["flash"] = Look.HIT_FLASH_SEC + reaction
			vb["knock"] = Look.HIT_KNOCK_SEC + reaction
			vb["knock_px"] = Look.HIT_KNOCK_RATIO * float(vb["half"])
			var vtile: Vector2 = battle.soldier_pos[v] if from_enemy else battle.enemy_pos[v]
			var away := Look.tile_point_px(vtile) - atk_px
			vb["knock_dir"] = Vector2.RIGHT if away.length() <= Rules.EPS else away.normalized()


	for raw_new in born:
		_fx.append(raw_new)
	# The transient drawer is capped and the OLDEST goes: the per-body drawer is bounded by the
	# number of bodies instead, which is why this rule cannot reach a flash or a lunge.
	while _fx.size() > Look.FX_MAX_COUNT:
		_fx.remove_at(0)

## P7. 0..1, one full on/off cycle every `HULL_WAIT_BLINK_SEC` — a raised cosine rather than a raw
## sine, so it sits at exactly 0 and 1 at the ends of each half-cycle instead of sweeping through
## every value with no rest, which reads as a pulse rather than a smear.
func _wait_blend() -> float:
	return 0.5 - 0.5 * cos(TAU * _wait_clock / Look.HULL_WAIT_BLINK_SEC)

## The one place a body's drawing offset is computed, so the body, the halo and the HP bar
## are all handed the same number. Split across call sites, one of them is eventually forgotten and
## the body walks out from under its own health bar with the whole round green.
func _body_offset_of(key: String) -> Vector2:
	return _lunge_offset(key) + _knock_offset(key) + _idle_offset(key)


## What a body does when it CANNOT move. See `Look.IDLE_AFTER_SEC` for why it exists at all.
##
## ⚠ **Phased off the key, so a queue does not sway in unison** — twelve bodies breathing on one
## beat read as a single object, which is worse than stillness. Deterministic, because a random
## wobble cannot be measured.
## ⚠ **Zero until `IDLE_AFTER_SEC` and it starts FROM zero**: the sway is a `sin` of elapsed
## stillness, so a body that has just stopped eases in rather than snapping sideways.
func _idle_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	# `.get`, because a net may hand-build a body entry that has no history yet — and "no history"
	# is exactly "not standing still", which is the right answer for a body nobody has stepped.
	var still := float(b.get("still", 0.0))
	if still <= Look.IDLE_AFTER_SEC:
		return Vector2.ZERO
	var phase := TAU * float(absi(key.hash()) % 100) / 100.0
	# ⚠ **No `fx_gain_of` here, deliberately.** The twelve slots are numbered for the twelve
	# combat-juice effects and the sway is not one of them; borrowing slot 12 would tie it to the
	# GAIT, so switching the walk cycle off would silently switch this off too — which is the exact
	# failure `fx_gain_of`'s own comment names.
	var amp := Look.IDLE_SWAY_RATIO * float(b.get("half", 0.0))
	var t := still - Look.IDLE_AFTER_SEC
	return Vector2(sin(TAU * t / Look.IDLE_PERIOD_SEC + phase), 0.0) * amp

## Item 2①. A triangle: exactly 0 at both ends and full push at the halfway point, so no body is ever
## left sitting displaced when it finishes.
func _lunge_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	var left := float(b["lunge"])
	if left <= 0.0:
		return Vector2.ZERO
	var dir: Vector2 = b["lunge_dir"]
	var at := 1.0 - left / Look.LUNGE_SEC
	return dir * (float(b["push"]) * (1.0 - absf(2.0 * at - 1.0)))

## Item 3③. Full `HIT_KNOCK_PX` on the frame the blow is felt, decaying to 0.
##
## The countdown carries the tracer's delay on top of `HIT_KNOCK_SEC` and this only reads while it is
## back inside that window — the same trick the flash uses, and for the same reason: a body must not
## flinch away from a bullet that has not arrived.
func _knock_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	var left := float(b["knock"])
	if left <= 0.0 or left > Look.HIT_KNOCK_SEC:
		return Vector2.ZERO
	var dir: Vector2 = b["knock_dir"]
	return dir * (float(b.get("knock_px", 0.0)) * Look.fx_gain_of(3)
		* (left / Look.HIT_KNOCK_SEC))

## Item 3①. How much white is mixed into this body's colour, 0.0 when it is not being hit.
##
## It does NOT ramp: `HIT_FLASH_STRENGTH` is held for the whole window and then drops out. Fading it
## would spend the back half of a 9-frame beat on a tint too weak to see, and the halo underneath is
## what carries the effect anyway.
func _flash_of(key: String) -> float:
	if not _body.has(key):
		return 0.0
	var b: Dictionary = _body[key]
	var left := float(b["flash"])
	if left <= 0.0 or left > Look.HIT_FLASH_SEC:
		return 0.0
	return Look.HIT_FLASH_STRENGTH * Look.fx_gain_of(3)

## Item 12. `1 - s*sin(phase)` along the heading and `1 + s*sin(phase)` across it, delivered in
## SCREEN axes because that is all `_rounded_square` can apply.
##
## The heading is resolved to whichever screen axis it leans on rather than blended between them:
## blending cancels the two factors exactly on a 45-degree heading, and units on this grid walk
## diagonals constantly — the effect would simply vanish for half of all movement. The cost is a
## swap when a body crosses 45 degrees, on an amplitude of 2 to 4 px.
##
## `sin` and not `cos` is load-bearing: a standing body sits at phase 0 and must be UNDEFORMED, and
## a cosine would leave every idle body permanently squashed.
func _gait_squash(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ONE
	var b: Dictionary = _body[key]
	var s := Look.GAIT_SQUASH * Look.fx_gain_of(12) * sin(float(b["gait"]))
	if absf(s) <= 0.0:
		return Vector2.ONE
	var head: Vector2 = b["head"]
	if absf(head.x) >= absf(head.y):
		return Vector2(1.0 - s, 1.0 + s)
	return Vector2(1.0 + s, 1.0 - s)

## `(HIT_HALO_MUL - 1) * own radius` deep inside the striker's own halo. The shards are NOT claimed
## to escape the target's halo — what carries this effect is that they move while everything under
## them stands still.
func _spark_points(centre: Vector2, facing: Vector2, progress: float) -> PackedVector2Array:
	var tangent := Vector2(-facing.y, facing.x)
	var outer := Look.SPARK_REACH_PX * progress
	# The shard has LENGTH, so its inner end trails the tip by SPARK_LEN_PX. Every margin in the
	# spec is computed from this end and never from the tip — built from the tip, half the points
	# would pass a check they were never inside.
	var inner := maxf(0.0, outer - Look.SPARK_LEN_PX)
	var per_side := Look.SPARK_COUNT / 2
	var spread := deg_to_rad(Look.SPARK_SPREAD_DEG)
	var out := PackedVector2Array()
	for k in Look.SPARK_COUNT:
		var side := 1.0 if k < per_side else -1.0
		var slot := k % per_side
		var lean := 0.0
		if per_side > 1:
			lean = float(slot) / float(per_side - 1) * 2.0 - 1.0
		var dir := (tangent * side).rotated(spread * lean)
		out.append(centre + dir * inner)
		out.append(centre + dir * outer)
	return out


# --- the effects, as geometry ------------------------------------------------------------------------
## ⚠⚠ **This section is what the 3D move deleted, put back.** `_fx_step` and `_drain_events` above never
## stopped running — effects were born, aged and died every frame with nothing painting them, and the
## field went quiet without one check going red. **That is the exact shape "Nothing pretends to work"
## names**, and it stood for a day.
##
## **Two buffers and two draw calls, not a node per effect.** Everything here is rebuilt every frame
## into one `ImmediateMesh` per layer, because an effect that lives 0.12 s cannot afford a node.
##
## **The two layers exist because the board became a landscape, and the split IS the answer to
## ticket 09's second open question** (bottom marks on ground that is no longer flat):
##
##   `_decal`  — marks that BELONG TO THE GROUND: the aim ring, the route, the landing ring, the area
##               ring, the refusal mark, the intent lines. Cut into `FX_GROUND_STEP_PX` pieces and each
##               piece laid at the height of the ground under it, so a ring across a ramp climbs it.
##   `_air`    — marks that belong to a BODY: the tracer, the shards, the death burst, the hit halo.
##               Built in the CAMERA'S OWN PLANE, so they read exactly as they did on the flat board
##               and turning the island does not shear them.
##
## ⚠ **Neither layer writes depth** (`DEPTH_DRAW_DISABLED`) but both are TESTED against it: a cliff in
## front still hides what is behind it, and two overlapping effects do not punch holes in each other.

var _decal: MeshInstance3D = null
var _air: MeshInstance3D = null
var _g_v := PackedVector3Array()
var _g_c := PackedColorArray()
var _a_v := PackedVector3Array()
var _a_c := PackedColorArray()


## One unshaded, vertex-coloured, alpha-blended surface. Both layers are the same material; what
## differs is only which buffer the geometry lands in and how it is built.
func _fx_layer() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(m)
	return m


func _fx_begin() -> void:
	_g_v.clear()
	_g_c.clear()
	_a_v.clear()
	_a_c.clear()


## ⚠ **An `ImmediateMesh` surface with zero vertices is an ERROR, not an empty picture.** A quiet frame
## — no plan, no fighting — is the common case at the start of an island, so both layers are guarded.
func _fx_flush() -> void:
	_fx_commit(_decal, _g_v, _g_c)
	_fx_commit(_air, _a_v, _a_c)


func _fx_commit(node: MeshInstance3D, verts: PackedVector3Array, cols: PackedColorArray) -> void:
	if node == null:
		return
	var im: ImmediateMesh = node.mesh
	im.clear_surfaces()
	if verts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in verts.size():
		im.surface_set_color(cols[k])
		im.surface_add_vertex(verts[k])
	im.surface_end()


# --- the ground layer ---------------------------------------------------------------------------------

## The height of the ground under a point given in world px. **The one place a ground mark asks where
## the ground is**, so a ring and a route cannot disagree about the hill they are both crossing.
func _ground_y_px(p: Vector2) -> float:
	var tx := int(floor(p.x / Look.TILE_PX))
	var ty := int(floor(p.y / Look.TILE_PX))
	return _ground_h(tx, ty) + Look.FX_GROUND_LIFT_TILES


func _g_tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	for p in [a, b, c]:
		_g_v.append(Vector3(p.x / Look.TILE_PX, _ground_y_px(p), p.y / Look.TILE_PX))
		_g_c.append(col)


func _g_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_g_tri(a, b, c, col)
	_g_tri(a, c, d, col)


## One straight mark on the ground, cut into pieces small enough to follow it. **The cutting is the
## whole of why this is not a single quad**: a 6-tile route drawn as one quad crosses a ramp as a
## chord and half of it is underground.
func _g_seg(a: Vector2, b: Vector2, width: float, col: Color, step: float = 0.0) -> void:
	var span := b - a
	var len_px := span.length()
	if len_px <= Rules.EPS:
		return
	var n := Vector2(-span.y, span.x) / len_px * (width * 0.5)
	var cut := step if step > 0.0 else Look.FX_GROUND_STEP_PX
	var steps := maxi(1, int(ceil(len_px / cut)))
	for k in steps:
		var p0 := a.lerp(b, float(k) / float(steps))
		var p1 := a.lerp(b, float(k + 1) / float(steps))
		_g_quad(p0 + n, p1 + n, p1 - n, p0 - n, col)


func _g_line(points: PackedVector2Array, width: float, col: Color) -> void:
	for k in range(1, points.size()):
		_g_seg(points[k - 1], points[k], width, col)


## A ring lying on the ground. Every segment is its own quad and every corner samples its own height,
## so the ring climbs whatever it is drawn across.
func _g_ring(centre: Vector2, radius: float, width: float, col: Color) -> void:
	if radius <= Rules.EPS:
		return
	var half := width * 0.5
	var segs := maxi(8, int(ceil(TAU * radius / Look.FX_GROUND_STEP_PX)))
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		_g_quad(centre + d0 * (radius - half), centre + d1 * (radius - half),
			centre + d1 * (radius + half), centre + d0 * (radius + half), col)


func _g_disc(centre: Vector2, radius: float, col: Color) -> void:
	if radius <= Rules.EPS:
		return
	var segs := maxi(8, int(ceil(TAU * radius / Look.FX_GROUND_STEP_PX)))
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		_g_tri(centre, centre + Vector2(cos(a0), sin(a0)) * radius,
			centre + Vector2(cos(a1), sin(a1)) * radius, col)


# --- the air layer ------------------------------------------------------------------------------------

## A world point given as an offset in SCREEN px from an anchor. `-off.y` because the flat board's y
## ran down the screen and every constant in `look.gd` was measured in that frame.
func _air_at(anchor: Vector3, off: Vector2) -> Vector3:
	var b := _cam.transform.basis
	return anchor + b.x * (off.x / Look.TILE_PX) + b.y * (-off.y / Look.TILE_PX)


func _a_quad(anchor: Vector3, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		_a_v.append(_air_at(anchor, p))
		_a_c.append(col)


func _a_seg(anchor: Vector3, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var span := b - a
	var len_px := span.length()
	if len_px <= Rules.EPS:
		return
	var n := Vector2(-span.y, span.x) / len_px * (width * 0.5)
	_a_quad(anchor, a + n, b + n, b - n, a - n, col)


func _a_ring(anchor: Vector3, radius: float, width: float, col: Color) -> void:
	if radius <= Rules.EPS:
		return
	var half := width * 0.5
	var segs := Look.FX_RING_SEGMENTS
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		_a_quad(anchor, d0 * (radius - half), d1 * (radius - half),
			d1 * (radius + half), d0 * (radius + half), col)


func _a_disc(anchor: Vector3, radius: float, col: Color) -> void:
	if radius <= Rules.EPS:
		return
	var segs := Look.FX_RING_SEGMENTS
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		_a_quad(anchor, Vector2.ZERO, Vector2(cos(a0), sin(a0)) * radius,
			Vector2(cos(a1), sin(a1)) * radius, Vector2.ZERO, col)


## Where a body's own effects hang: over the tile it stands on, a body-radius up. **Not the sprite's
## centre** — the sprite is 2.4 radii wide and its middle drifts with the picture's aspect, and an
## effect that moved when the artwork changed would be an effect measured against the wrong thing.
func _body_anchor(centre_px: Vector2, radius: float) -> Vector3:
	return Vector3(centre_px.x / Look.TILE_PX,
		_ground_y_px(centre_px) + (Look.BODY_LIFT_PX + radius) / Look.TILE_PX,
		centre_px.y / Look.TILE_PX)


## How much of a body's hit flash is left, 0..1. `_flash_of` deliberately returns a CONSTANT strength
## while the flash is live — it is a tint, and a tint that ramps reads as a fade rather than a hit —
## but the halo is an area and has to go out, so it reads the clock itself.
func _halo_of(key: String) -> float:
	if not _body.has(key):
		return 0.0
	var b: Dictionary = _body[key]
	var left := float(b["flash"])
	if left <= 0.0 or left > Look.HIT_FLASH_SEC:
		return 0.0
	return left / Look.HIT_FLASH_SEC


## A straight mark between two points that are BOTH in the world, thickened in the camera's plane.
## The tracer needs this and the camera-plane `_a_seg` cannot serve it: a shooter on a cliff and a
## target on the beach are 2.4 tiles apart in height, and a line built from screen offsets alone would
## leave the muzzle it was fired from.
func _a_seg3(a: Vector3, b: Vector3, width: float, col: Color) -> void:
	var basis := _cam.transform.basis
	var d := b - a
	var du := d.dot(basis.x)
	var dv := d.dot(basis.y)
	var l := sqrt(du * du + dv * dv)
	if l <= Rules.EPS:
		return
	var n := (basis.x * (-dv / l) + basis.y * (du / l)) * (width * 0.5 / Look.TILE_PX)
	for v in [a + n, b + n, b - n, a + n, b - n, a - n]:
		_a_v.append(v)
		_a_c.append(col)


## A world px point lifted to the height an effect with no body of its own hangs at. See
## `FX_AIR_LIFT_PX`.
func _fx_point3(p: Vector2) -> Vector3:
	return Vector3(p.x / Look.TILE_PX,
		_ground_y_px(p) + Look.FX_AIR_LIFT_PX / Look.TILE_PX,
		p.y / Look.TILE_PX)


# --- what actually gets painted -------------------------------------------------------------------

## Everything that is not bolted to a body, in the order it has to stack: the plan under the fight,
## the intent lines under the transients. **One entry point** so a caller cannot paint half of it.
func _paint_fx() -> void:
	if battle == null or army == null or battle.grid == null:
		return
	_paint_plan()
	_paint_placed_boats()
	_paint_boat_routes()
	_paint_intent()
	_paint_transients()


## **The plan's own picture** — item 1 of the twelve and the one the ticket called the most painful to
## have lost: without it a press puts a boat on the water with nothing having said where it would go.
##
## ⚠ **The ring's colour is the SIM'S answer and never the view's guess.** `can_summon_at` is the same
## predicate `Battle.summon` refuses on, so a green ring cannot promise a drop the sim will reject —
## the failure the deleted green wash was trusted not to have.
func _paint_plan() -> void:
	if battle.committed() or _summon_slot < 0 or _summon_aim < 0:
		return
	# ⚠ **A DRY slot (no reserve left) draws NOTHING — no ring, no route** (2026-08-24, the user
	# closed the fork: 「추천대로」, restoring the old rule). A valid-looking mark on a press the sim
	# will refuse is the screen promising what `Battle.summon` denies; `_paint_ghosts` has kept this
	# gate all along, and the shell's per-beat refusal mark is what says 「더 없다」 instead.
	if battle.slot_reserve_ids(_summon_slot).is_empty():
		return
	var grid := battle.grid
	var ok := grid.can_summon_at(_summon_aim)
	var at := Look.tile_point_px(grid.tile_point(_summon_aim))
	if ok:
		var route := grid.summon_route(_summon_aim)
		var pts := PackedVector2Array()
		for k in route.size():
			pts.append(Look.tile_point_px(route[k]))
		_g_line(pts, Look.ROUTE_WIDTH_PX, Look.COL_ROUTE)
	_g_ring(at, Look.TARGET_RING_R_PX, Look.ROUTE_WIDTH_PX,
		Look.COL_WIN if ok else Look.COL_LOSE)


## **Where each boat ALREADY PLACED is going to land**, one ring per boat, while the plan is still
## open. `_paint_plan` above draws the AIM — the one tile the cursor is over — and it has never drawn
## the drops already made.
##
## ⚠⚠ **The ring is not decoration: it is the UNDO, and it had no picture at all.**
## `game._ring_hit_at` takes a drop back when a press lands inside `TARGET_RING_R_PX` of that boat's
## landing tile, and its own header says the radius is *"read the same way `field_view` draws them"* —
## which was false, because nothing drew them. A control the player cannot see is a control they do
## not have (2026-08-25, found while answering 「배를 놨으면 그게 바다에 보여야할듯」).
##
## ⚠ **`COL_BOAT` and not `COL_WIN`.** The valid-aim ring is `COL_WIN` and it means *"a press here
## would work"*; this one means *"a boat is already going here"*. Two different sentences may not wear
## one colour, and the hull's own tan is what ties the ring to the boat it belongs to.
##
## ⚠⚠ **The ring and NOT the route, and that is a decision.** A placed boat's whole water route in
## `COL_ROUTE` would be the aim's own mark worn by something else — `net_slots` reads the aim's route
## by that colour to prove a dry slot promises nothing — and thirteen placed boats would lay thirteen
## lines over the sea the plan is authored on. **What a placed boat owes the player is where it IS and
## where it ENDS**; the hull says the first and this ring says the second. The route comes back the
## moment it starts sailing, in `_paint_boat_routes`.
func _paint_placed_boats() -> void:
	if battle.committed():
		return
	for raw_boat in battle.boats:
		var boat: Dictionary = raw_boat
		_g_ring(Look.tile_point_px(battle.grid.tile_point(int(boat["target"]))),
			Look.TARGET_RING_R_PX, Look.ROUTE_WIDTH_PX, Look.COL_BOAT)


## **The remaining water route under every boat still crossing** — the part it has NOT sailed, read
## straight off the sim's own `leg` through `_route_ahead` (whose header owns the argument for why
## the view never re-walks it). This is the caller `_route_ahead` lost in the 3D move: the line was
## computed every frame and drawn by nobody, the exact shape ticket 09 exists to close.
##
## Only after the commit — before it a boat is its PLAN and `_paint_plan` owns the water — and only
## while OUTBOUND: an arrived boat has no water left to claim, and a line drawn from its deck reads
## as a route it is about to sail again.
func _paint_boat_routes() -> void:
	if not battle.committed():
		return
	for raw_boat in battle.boats:
		var boat: Dictionary = raw_boat
		if int(boat["phase"]) != Battle.Phase.OUTBOUND:
			continue
		_g_line(_route_ahead(boat), Look.ROUTE_WIDTH_PX, Look.COL_ROUTE)


## The ghosts: **where the bodies this press would send are going to stand.** Painted as real bodies at
## the LANDING and not at the press, because the press is water and the landing is where they end up.
##
## ⚠ These go through `_put_body` and therefore through the same sprite pool as everything alive, so
## `_hide_unused` covers them and a ghost cannot outlive the aim that made it.
func _paint_ghosts() -> void:
	if battle.committed() or _summon_slot < 0 or _summon_aim < 0:
		return
	var grid := battle.grid
	if not grid.can_summon_at(_summon_aim):
		return
	var landing := grid.summon_landing_of(_summon_aim)
	if landing < 0:
		return
	var at := Look.tile_point_px(grid.tile_point(landing))
	var ids: Array = battle.slot_reserve_ids(_summon_slot)
	var n := ids.size()
	if n <= 0:
		return
	# A fan and not a stack: `GHOST_FAN_PX` is the spacing that keeps two ghosts from reading as one
	# blob, and the row is centred on the landing so the middle of the fan is the tile itself.
	var span := float(n - 1) * Look.GHOST_FAN_PX.x
	for k in n:
		var i := int(ids[k])
		var st := int(army.type_id[i])
		var off := Vector2(float(k) * Look.GHOST_FAN_PX.x - span * 0.5,
			float(k % 2) * Look.GHOST_FAN_PX.y)
		# ⚠ **The ghost wears the SPECIES it is a ghost of**, and it used to wear the wolf whatever was
		# in the slot. With one slot bound to one species the two agreed by accident; with five they do
		# not, and a plan that draws the wrong animal is the plan lying about what it will land.
		_put_body(at + off, Look.body_radius_of(st), Look.ghost_tint(), Vector2.ONE,
			_beast_tex(st, true), 0.0)


## **Who is going for whom**, one thin line per pair. The alpha is 0.12 and up to
## `TARGET_LINE_MAX_COUNT` of them cross the island at once: this effect is a TEXTURE over the fight,
## not a set of readable lines, and raising either number turns it into a cage.
func _paint_intent() -> void:
	var left := Look.TARGET_LINE_MAX_COUNT
	for i in battle.soldier_target.size():
		if left <= 0:
			break
		var e := int(battle.soldier_target[i])
		if e < 0 or not battle.is_hittable(i):
			continue
		if e >= battle.enemy_alive.size() or battle.enemy_alive[e] == 0:
			continue
		_g_seg(Look.tile_point_px(battle.soldier_pos[i]), Look.tile_point_px(battle.enemy_pos[e]),
			Look.TARGET_LINE_WIDTH_PX, Look.COL_TARGET_LINE, Look.FX_INTENT_STEP_PX)
		left -= 1
	for e in battle.enemy_target.size():
		if left <= 0:
			break
		if battle.enemy_alive[e] == 0:
			continue
		var i := int(battle.enemy_target[e])
		if i < 0 or not battle.is_hittable(i):
			continue
		_g_seg(Look.tile_point_px(battle.enemy_pos[e]), Look.tile_point_px(battle.soldier_pos[i]),
			Look.TARGET_LINE_WIDTH_PX, Look.COL_TARGET_LINE, Look.FX_INTENT_STEP_PX)
		left -= 1


## The six transient kinds `_drain_events` makes. **Nothing here decides WHEN anything happens** — the
## sim froze the geometry on the frame the fact happened and this reads it back at whatever age it has
## reached, which is why an island re-opening cannot show a stale explosion.
func _paint_transients() -> void:
	for raw_fx in _fx:
		var fx: Dictionary = raw_fx
		var age := float(fx["age"]) - float(fx["delay"])
		if age < 0.0:
			continue
		var p := clampf(age / maxf(float(fx["life"]), Rules.EPS), 0.0, 1.0)
		var fade := 1.0 - p
		match int(fx["kind"]):
			FxKind.SHOT:
				# A STUB, not the whole line: drawing muzzle-to-target every frame is a laser, and a
				# laser says "a beam is standing there" rather than "something crossed".
				var p0 := _fx_point3(fx["from"])
				var p1 := _fx_point3(fx["to"])
				var full := p0.distance_to(p1)
				var dir := (p1 - p0).normalized() if full > Rules.EPS else Vector3.RIGHT
				var head := full * p
				var tail := maxf(0.0, head - Look.SHOT_LEN_PX / Look.TILE_PX)
				_a_seg3(p0 + dir * tail, p0 + dir * head, Look.SHOT_WIDTH_PX, Look.COL_SHOT)
			FxKind.SPARK:
				var anchor := _fx_point3(fx["at"])
				var pts := _spark_points(Vector2.ZERO, fx["facing"], p)
				var col := Look.COL_SPARK
				col.a = fade
				for k in range(0, pts.size() - 1, 2):
					_a_seg(anchor, pts[k], pts[k + 1], Look.SPARK_WIDTH_PX, col)
			FxKind.BURST:
				# ⚠ The fx carries the SIM radius (the fact frozen at death); the PICTURE starts at
				# that body's sprite half-width — `BURST_START_MUL`'s own paragraph owns why, and the
				# anchor keeps the sim radius so the ring hangs at the body's real middle.
				var r := float(fx["radius"]) * Look.BURST_START_MUL * lerpf(1.0, Look.BURST_GROWTH, p)
				var col: Color = fx["colour"]
				col.a = fade
				_a_ring(_body_anchor(fx["at"], float(fx["radius"])), r, Look.BURST_WIDTH_PX, col)
			FxKind.AREA:
				var r := float(fx["radius"]) * lerpf(Look.AREA_RING_START_RATIO, 1.0, p)
				var col := Look.COL_AREA_RING
				col.a *= fade
				_g_ring(fx["at"], r, Look.AREA_RING_WIDTH_PX, col)
			FxKind.LAND:
				# ⚠ **Fixed radius, unlike the two above.** `LAND_RING_R_PX` has no growth constant
				# beside it, and inventing one would be a number nobody measured.
				var col := Look.COL_LAND_RING
				col.a *= fade
				_g_ring(fx["at"], Look.LAND_RING_R_PX, Look.LAND_RING_WIDTH_PX, col)
			FxKind.REFUSE:
				var col := Look.COL_LOSE
				col.a = fade
				_g_ring(fx["at"], Look.REFUSE_MARK_R_PX, Look.REFUSE_MARK_WIDTH_PX, col)
