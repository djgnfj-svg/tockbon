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
## ⚠ **The 판's own shader.** It is a second material on a second object inside `island.glb`, not a
## second copy of the water's — the two answer different questions and share no uniform.
const PADS_SHADER := "res://src/view/pads.gdshader"
## The name Blender gives the 판 object inside `island.glb`. ⚠ **Both sides spell it once**: the
## export names it in `tools/blender/island_build.py` and this is the only place the game reads it.
const PADS_NODE := "pads"


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

## **`[type][facing]`, every picture every row of `Look.BEAST_TEX` declares, loaded once.** A row's
## inner array is as long as that row has facings — two for the side-on species, four for the wolf —
## and **an empty inner array is a row with no picture at all**, which `_put_body` already draws the
## plain rounded shape for.
##
## ⚠⚠ **IT WAS TWO FLAT ARRAYS, `_tex_facing_r` AND `_tex_facing_l`** (2026-08-30, 티켓 25). Two
## parallel arrays are exactly two facings and no more, so the H wolf's four could not be held here at
## all — and while they could not, the deck loaded them from a second list of its own and the island
## kept walking the picture the user had already replaced.
var _tex_facing: Array = _load_beast_tex()
## The frame strips, `[type][facing][anim][frame]`, loaded once beside the standing pictures. **Empty
## wherever `Look.BEAST_TEX` declares no strip** — which is EVERY row today, and is exactly why nothing
## below names a species: an empty strip falls back on the standing picture at the one place a body's
## picture is chosen, so a species animates by editing its own row and nothing else.
var _tex_anim: Array = _load_beast_anim()
## **How far each body picture's opaque ink stands above the bottom of its own frame**, as a fraction
## of that frame's height, keyed by the picture. See `_measure_body_feet`. ⚠ **Declared here and not
## beside the boats**, because the island needs it for exactly the reason the deck always did.
var _foot_body: Dictionary = _measure_body_feet(_tex_facing)
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
var _sun: DirectionalLight3D = null
## **The mark on the MAT under the cursor.** Its mesh is rebuilt when the cursor crosses into
## another mat -- see `set_hover_tile`.
## Which MAT the cursor is on, not which tile. -1 for none.
var _hover_cell := -1
## Which mat each tile belongs to, kept from the last `_rebuild_wash`. The hover mark reads it.
var _wash_cell := PackedInt32Array()
var _sprites: Array[Sprite3D] = []
var _sprites_used := 0
## What the terrain in the mesh was built for. Rebuilding 5120 boxes every frame is waste; the island
## only changes when it opens, and the summonable band only when the plan is committed.
var _built_for := ""


# --- what the sea is doing ----------------------------------------------------------------------

## ⚠⚠ **THE PLAN'S OWN THREE FIELDS STOOD HERE AND ALL THREE ARE DELETED**: `_summon_slot` and
## `_summon_aim` on 2026-08-28 (the slot a key had armed and the tile the cursor was over), and
## `_wait_clock` on 2026-08-29 with the boats — it aged the tint on a hull that had arrived and was
## waiting to unload.


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
	_hand_the_sea_its_look(sea_mat)
	_sea.material_override = sea_mat
	# ⚠⚠ **The sea casts nothing, and that is a fix rather than an optimisation.** A flat quad 400
	# tiles across shadows ITSELF at grazing angles, and the whole sea drew as diagonal stripes — the
	# capture that added the quad shows them. A flat sea has nothing to cast anyway; the island still
	# casts onto it, which is the only shadow out there that means something.
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ⚠ **The water sits where `SEA_Y_TILES` says**, and it was left at the plane's own zero until
	# 2026-08-28. See that constant for what raising it buys and what it must not pass.
	_sea.position.y = Look.SEA_Y_TILES
	_world.add_child(_sea)

	# One mesh, one material, one draw call for the whole island — see `_rebuild_terrain`.
	_terrain = MeshInstance3D.new()
	_world.add_child(_terrain)

	# The two effect layers. Built here and never rebuilt, because what changes every frame is the
	# geometry inside them and not the nodes.
	_decal = _fx_layer()

	# ⚠⚠ **THE MARK IS A MAT, NOT A QUAD.** It used to be one plane the size of one tile, moved
	# about; the user asked for the 2x2 piece to be the unit that lights up, and a square of that size
	# hangs over the shore on every coastal piece. **It is cut from the mat's own mask instead**, so it
	# is exactly the shape of the thing it lights up, and its mesh is rebuilt only when the cursor
	# crosses into another mat.
	# ⚠⚠ **THE MARK HAS NO MESH OF ITS OWN ANY MORE** (2026-08-28). Two quads built out of a mask
	# stood here — a bright plate and its dark twin — because the mat was drawn by this file and had
	# nothing to raise. **The mats are baked objects now**, so the mark IS one of them, lifted. See
	# `set_hover_tile`.

	# ⚠⚠ **THE RESTING MAT IS BAKED INTO THE ISLAND NOW AND THIS NODE IS GONE** (2026-08-28). A white
	# quad per tile used to lie over the ground here. The user's word on it was 「위에 노드만 살짝 얹은
	# 느낌이어서 너무 별로」 and 「너무 흰색이 너무 잘 보여」 — and it could not be fixed in place: a flat
	# quad cannot bend with a surface `COAST_WOB` and a `BEVEL` have already curved, and every quad was
	# the same rectangle. **`tools/blender/island_build.py` paints each piece's own flat interior
	# lighter instead**, so the mat IS the walking surface, wears that piece's own wobble, and needs no
	# colour of its own. ⚠ **The mask below survives** — the HOVER still wears it.


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



## **Which mat each tile belongs to, worked out once when the board loads.**
##
## ⚠⚠ **THIS FUNCTION WAS A MASK BUILDER AND IT IS AN INDEX NOW** (2026-08-28). It used to cut the mat
## shape out of a walkability distance field — erode, dilate, feather, then a quad per walkable tile
## wearing the result as a texture — because the mat was drawn by this file. **The mats are baked
## objects** (`assets/terrain/pads.glb`), so their shape is authored and nothing here has to guess it.
## What is still needed is the lookup the shape used to be built from: which piece a pressed tile is
## in, so the hover knows which pad to raise.
##
## ⚠ **The distance field, the feathered rim and the per-tile quads went with it**, and so did the four
## constants that tuned them. They are recoverable from git; what is not recoverable is a round spent
## re-tuning a mask against a shape Blender already decides.
func _rebuild_wash() -> void:
	if battle == null or battle.grid == null:
		return
	_wash_cell = _wash_cells(battle.grid)
	_hover_cell = -1


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
	# ⚠ **And the water forgets every hull.** The blocks are indexed by boat number, so island 2's
	# first boat would otherwise open wearing island 1's first boat's trail.
	_wake = _wake_empty()
	_wake_last = _wake_no_last()
	# The survey: an island opens zoomed all the way out, so the WHOLE island is on screen before
	# anything is planned — `plan-then-watch` 6.3, on the user's 「조금 더 카메라를 뒤로 빼야 될」.
	# ⚠ **Not `ZOOM_MIN` any more.** See `Look.survey_zoom_of`: the opening view is a question about the
	# grid that just loaded, and a constant could only ever answer it for one map size.
	zoom = Look.survey_zoom_of(_map_tiles().x, _map_tiles().y)
	cam_yaw_deg = Look.CAM_YAW_DEG
	cam_pitch_deg = Look.CAM_PITCH_DEG
	# ⚠⚠ **THE OPENING FRAME IS CENTRED HERE AND IT USED TO BE THE CLAMP THAT DID IT.** This was
	# `cam_px = Vector2.ZERO` followed by `_clamp_cam()`, and it worked only because the clamp pinned
	# any axis narrower than the view to the middle. **The clamp lets the camera roam out to sea now**
	# (`Look.CAM_ROAM_TILES`), so zero is a perfectly legal place to be and the island would open in
	# the corner. **The framing has to be said out loud rather than fall out of a bound.**
	# ⚠ Same arithmetic the clamp used, so every opening literal in `net_camera` is unchanged.
	var map_px := Vector2(float(_map_tiles().x), float(_map_tiles().y)) * Look.TILE_PX
	cam_px = map_px * 0.5 - _visible_ground_px() * 0.5
	_clamp_cam()
	# ⚠ **Forces a terrain rebuild even when the same island re-opens.** `_built_for` is a fingerprint
	# of the rows, and re-entering island 0 from the map would otherwise keep the mesh from the last
	# time — which is right for the boxes and wrong for the band, because the plan has been reset.
	_built_for = ""
	_build_world()
	_rebuild_terrain()
	_rebuild_wash()
	_place_camera()


## **Which 판 each tile belongs to** -- its own index, or -1 where nothing walks.
##
## ⚠⚠ **ONE 판 PER 조각 SINCE 2026-08-29** (the user, after seeing both on screen: 「판이 조각단위로
## 뜨고 그것으로 이동할 수 있는게 좋을 것 같아」). This function used to answer the index of the tile's
## **2x2 칸**, because the island is laid down in 2x2 pieces and a raised block is always a whole
## piece. ⚠ **That is a reversal, not a cleanup**: one mat per tile had been on screen once before and
## the word then was 「너무 많으」. What changed is that the move command has always taken a 조각, so a
## 판 that was a 칸 meant the mark and the order spoke different units.
## ⚠ **The Blender bake writes the same number into every 판's UV** — change one side and the cursor
## lights the wrong thing.
func _wash_cells(grid: Grid) -> PackedInt32Array:
	var n := grid.w * grid.h
	var cell := PackedInt32Array()
	cell.resize(n)
	for ty in grid.h:
		for tx in grid.w:
			var t := ty * grid.w + tx
			# ⚠⚠ **A STAIR CARRIES NO MAT** (2026-08-27, the user: 「계단에는 칸을 안만들어야하는데」,
			# and again on 2026-08-29: 「계단에서 머물수 없는게 좋을듯」). **No shape has to be authored
			# per tile to say so** — the board already knows: an ODD notch IS a stair
			# (`Grid.is_stair_level`), which is the same fact that makes the stair the only way up.
			# A mat says「여기 서라」 and a stair is something a body passes THROUGH.
			# ⚠ It stays walkable. Only the light stops there.
			var no_mat: bool = grid.passable[t] != 1 or Grid.is_stair_level(grid.level_of(t))
			cell[t] = -1 if no_mat else t
	return cell



## The sim moves every frame and the picture has to follow it.
##
## **The order is load-bearing and it is the order it always was.** Ageing first and draining second
## means an effect born this frame is at full amplitude on the frame it was born, so the flinch really
## does reach its full flinch once and the idle sway really does start from rest.
##
## ⚠ **Every clock here is aged by the BARE frame delta** — there is no speed
## multiplier to fold in, and a leaf handed a constant 1.0 is the shape "No fake code" names.
func _process(delta: float) -> void:
	_fx_step(delta)
	# The sea's own clock — the bob and the roll, and nothing else, read it. See `_sea_clock`.
	_sea_clock += delta
	# ⚠ **After the tick and not before it.** Every remembered point is stamped with `_sea_clock`,
	# and a stamp taken before the tick is a frame behind the hull the same frame is about to draw.
	_paint_wake()
	_place_camera()
	# ⚠ **The buffer is opened BEFORE the bodies and flushed after them.** A body's shadow is painted
	# from inside `_paint_bodies` — it is a per-body fact, and that is the one loop with a body's
	# centre and radius in hand at the same time.
	_fx_begin()
	_paint_bodies()
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
	# ⚠ **The 판 merge with distance**, so every zoom is also a change to what they look like.
	_tell_the_pads()


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
## ⚠⚠ **THE BOUND IS THE ISLAND PLUS `Look.CAM_ROAM_TILES` OF SEA, AND IT USED TO BE THE ISLAND ITSELF.**
## Under the old bound an axis whose board was narrower than the visible ground was CENTRED on it — and
## every island is narrower than the view at its own opening zoom, so **the camera could not move at
## all**. That was right while the island was the whole game; it is wrong now that **finding a boat out
## at sea is the player's job and the camera is the only tool for it** (2026-08-30, the user: 「안
## 알아채는 게 맞겠다」).
##
## ⚠ **The centring branch survives, one level out.** When the ROAM rectangle is still narrower than
## the view there is no range to clamp into and the middle is the only answer — that is a tiny board or
## a very wide zoom, not the shipped island.
## ⚠ **The opening frame is no longer this function's doing** — see `setup`, which now says the
## centring out loud instead of leaning on a bound that has moved.
func _clamp_cam() -> void:
	var map_px := Vector2(float(_map_tiles().x), float(_map_tiles().y)) * Look.TILE_PX
	var visible := _visible_ground_px()
	var roam := Look.CAM_ROAM_TILES * Look.TILE_PX
	var centre := cam_px + visible * 0.5
	for axis in 2:
		var lo := -roam
		var hi := map_px[axis] + roam
		if hi - lo < visible[axis]:
			centre[axis] = (lo + hi) * 0.5
		else:
			centre[axis] = clampf(centre[axis], lo + visible[axis] * 0.5, hi - visible[axis] * 0.5)
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
## **The beasts' hull, as one object Blender made.** ⚠ **Loaded, never built** (`CLAUDE.md`: what the
## player looks at is made in a tool). It arrives at its authored size and nothing scales it — 티켓 47
## says the hull, the sail and their proportions are judged on the game screen, after it is in.
## ⚠ **It sits here and not in `look.gd` because it is a scene path**, and the three above it already
## decided where those live. Every number the hull is DRAWN with is still `look.gd`'s.
const BOAT_SCENE := "res://assets/props/boat.glb"

var _island: Node3D = null
## **The 판 object, found inside the island scene by name**, and the material this file put on it.
## ⚠⚠ **Null is a real state and it is not an error**: a bake that has not been re-run yet has no
## `pads` node, and every writer below no-ops rather than crashing. `set_hover_tile` and the reveal
## key both go through `_tell_the_pads`, which is the one place that null is checked.
var _pads: MeshInstance3D = null
var _pads_mat: ShaderMaterial = null
## Whether the player is holding the reveal key. **Written only by `set_pads_revealed`**, which the
## shell calls on the key down and the key up.
var _pads_revealed := false
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
	# ⚠⚠ **THE ISLAND WEARS NO OUTLINE SINCE 2026-08-28** (the user, on the game screen: 「외곽선이 너무
	# 두꺼워서 좀 그런데? 외곽선 좀 없애줄래?」). The shell is a WORLD width, so it thickens as the camera
	# comes in — and once the 판 was cut into every 칸 it inked those edges too and the ground came out
	# scribbled with broken black lines.
	# ⚠ **The buildings and the scatter keep theirs** (`_rebuild_buildings`, `_rebuild_props`): they are
	# objects standing ON the ground and the rim is what separates them from it.
	# ⚠ **티켓 01 records the island losing this rim once before and the loss being noticed** — it
	# stopped reading as 「단단한 물체」 from above. That is the thing to watch for now.
	_adopt_the_pads()
	_hand_the_sea_its_shoreline()
	_rebuild_buildings()
	_rebuild_props()


## **Finds the 판 inside the island scene and gives it its shader.**
##
## ⚠⚠ **THE 판 IS A SECOND OBJECT IN THE SAME FILE** (2026-08-28). It spent one day welded into the
## island's own mesh, where the hover had nothing to raise and nothing to hide — which is exactly why
## the mark went missing for a round. `tools/blender/island_build.py` exports it beside the island and
## this is where the game picks it up.
##
## ⚠ **A missing `pads` node is not an error.** The island file is baked by hand; a build from before
## the split simply has no such child, and every writer below checks for null rather than this
## function inventing a mesh the artist did not author (`CLAUDE.md`: what the player looks at is made,
## not typed).
func _adopt_the_pads() -> void:
	_pads = null
	_pads_mat = null
	if _island == null:
		return
	var found := _island.find_child(PADS_NODE, true, false)
	if found == null or not (found is MeshInstance3D):
		return
	_pads = found as MeshInstance3D
	var mat := ShaderMaterial.new()
	mat.shader = load(PADS_SHADER)
	mat.set_shader_parameter("all_alpha", Look.PAD_ALL_ALPHA)
	mat.set_shader_parameter("hover_alpha", Look.PAD_HOVER_ALPHA)
	mat.set_shader_parameter("all_lighten", Look.PAD_ALL_LIGHTEN)
	mat.set_shader_parameter("hover_lighten", Look.PAD_HOVER_LIGHTEN)
	mat.set_shader_parameter("hover_lift", Look.PAD_HOVER_LIFT)
	_pads.material_override = mat
	# ⚠ **No shadow.** The 판 is a mark on the ground, and a mark that casts one reads as a slab
	# floating over it — the same argument the summon ring's own material carried.
	_pads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pads_mat = mat
	_tell_the_pads()


## **The one place the shader is written**, so the hover and the reveal key can never disagree about
## what is on screen. Called from `set_hover_tile`, from `set_pads_revealed` and once at adoption.
func _tell_the_pads() -> void:
	if _pads_mat == null:
		return
	_pads_mat.set_shader_parameter("hover_cell", float(_hover_cell))
	_pads_mat.set_shader_parameter("show_all", 1.0 if _pads_revealed else 0.0)
	# ⚠⚠ **The merge and the board's width go the same way as the hover**, because the shader needs all
	# three to answer one question: what lights up. Far out a 칸 is one 판, so the whole 칸 lights.
	_pads_mat.set_shader_parameter("merge", pad_merge())
	if battle != null and battle.grid != null:
		_pads_mat.set_shader_parameter("board_w", float(battle.grid.w))


## **How far the 판 have merged at the camera's current distance**, 0 apart and 1 one-per-칸.
##
## ⚠ **The only reader is the shader**, and the only thing that moves it is the zoom -- which is why
## `zoom_at` has to say so. **A merge that lagged the camera by a frame reads as the board sliding.**
func pad_merge() -> float:
	return clampf((Look.PAD_APART_ZOOM - zoom) / (Look.PAD_APART_ZOOM - Look.PAD_MERGE_ZOOM), 0.0, 1.0)


## **Whether the whole board is showing.** The shell drives this off the reveal key being held —
## down is true, up is false — so the board is visible for exactly as long as the key is.
##
## ⚠ **Not a toggle.** A held key cannot leave the board switched on behind a player who forgot, and
## the user asked for 「특정버튼 눌러야 그 뜨게해줘」 — pressed, not latched.
func set_pads_revealed(on: bool) -> void:
	_pads_revealed = on
	_tell_the_pads()


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
		# ⚠ Scaled about its own origin, which sits at the footprint's centre on the ground — so a
		# shrunken building stays on its tile and stays standing on it rather than floating.
		one.scale = Vector3(Look.BUILD_SCALE, Look.BUILD_SCALE, Look.BUILD_SCALE)
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
##
## ⚠⚠ **THE ISLAND IS GOING TO CHANGE WHILE THE GAME IS RUNNING** (2026-08-28, the user: 「유저가 땅을
## 추가하거나 섬을 넓힐 수가 있다」). Calling this again rebuilds everything the sea knows about the land,
## and the cache below is keyed on the land's own bytes so a rebuild after a block is placed cannot be
## served a stale map. ⚠⚠ **What is NOT yet ready for that is the outline itself**: `Islands.coast()` is
## a polyline the Blender bake exported for THIS island, so a block placed at runtime moves the rock and
## not the line. **The bake has to export a rule the game can compose an outline from — per piece side
## and per corner — rather than one island's finished polyline.** Until it does, added land will have a
## shore the water cannot see, and that is a known gap and not a surprise.
## ⚠⚠ **The baked field, kept between builds.** There is ONE island and it is read from a file, so the
## distance map is the same picture every time a board is built — and a net run builds hundreds. Baking
## it once took the whole net run from 31 seconds to 42; keeping it takes it back. ⚠ **Keyed on
## everything the bake depends on**, so a changed constant re-bakes instead of serving a stale map.
static var _field_cache: ImageTexture = null
static var _field_key := ""


func _hand_the_sea_its_shoreline() -> void:
	if _sea == null or battle == null:
		return
	var g := battle.grid
	var sub := int(Look.WATER_FIELD_SUBDIV)
	var span := float(Look.WATER_FIELD_SPAN_TILES)
	# ⚠⚠ **A MARGIN OF OPEN WATER ROUND THE GRID, and without it the sea grows straight white lines out
	# to the horizon** (found 2026-08-28). The field used to cover the island's tile box exactly; the
	# sampler clamps outside it, so whatever distance the border texel happened to hold was repeated
	# forever outward. Where the island reached its box — the east arm does — the border said "almost
	# ashore" and the foam obeyed it all the way off screen. **The margin has to be at least `span`**, so
	# that every border texel is real open sea and clamping repeats nothing but open sea.
	var margin := span
	var tw := int(round((float(g.w) + margin * 2.0) * float(sub)))
	var th := int(round((float(g.h) + margin * 2.0) * float(sub)))

	# ⚠⚠ **The REAL coastline, not the tile grid.** Coastal corners are cut and pushed when the island
	# is built, so a field measured to square tiles put a square wash around a coast that is not square
	# (2026-08-26, the user saw it before the code did). `Islands.coast()` is the line the mesh actually
	# ends on, exported beside the mesh by the same run that shaped it.
	var coast := Islands.coast()
	# ⚠⚠ **THE KEY IS THE LAND ITSELF, NOT ITS SIZE** (2026-08-28, the user: 「유저가 땅을 추가하거나
	# 섬을 넓힐 수가 있다는 점을 꼭 명심하도록 두고 작업해야 돼 ... 땅이 추가되었을 때 해안선도 바뀌고
	# 해안 라인도 바뀐다」). The first version of this cache keyed on width, height, resolution and the
	# **number** of coast segments — every one of which a player adding a block can leave untouched while
	# moving the shore. **A cache that cannot see the change it is caching is a stale picture served
	# silently**, which is the exact failure this repo already paid for once with Godot's own import
	# cache. `water` carries one byte per tile, so hashing it sees any block placed or removed.
	var key := "%d,%d,%d,%.3f,%d,%d" % [g.w, g.h, sub, span, coast.size(),
										hash(g.water) ^ hash(coast)]

	var tex: ImageTexture = _field_cache if key == _field_key else null
	if tex == null:
		tex = _bake_land_field(tw, th, sub, span, margin, coast)
		_field_cache = tex
		_field_key = key

	var mat := _sea.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("land_field", tex)
	_hand_the_sea_its_numbers(mat, g, margin, span)


## **The distance map itself.** Split out so the caller can skip it entirely when the same island is
## being built again.
static func _bake_land_field(tw: int, th: int, sub: int, span: float, margin: float,
							 coast: Array) -> ImageTexture:
	# ⚠⚠ **Written into a byte buffer, NOT with `set_pixel`.** The field is built at sixteen texels per
	# tile now — a quarter of a million of them — and `set_pixel` is a call across the engine boundary
	# for every one. The buffer plus one `create_from_data` is the same picture in a fraction of the
	# time, and the resolution is what lets the lip follow a cut corner instead of stepping down it.
	# ⚠⚠ **FLOATS, not bytes, and the byte version was a visible defect** (2026-08-28, the user: 「너무
	# 딱딱하게」). `FORMAT_L8` over a span of 4 tiles is one level every **0.0157 tiles**; the lip is 0.06
	# tiles wide, so its soft edge had **four steps in it** and read as a stair rather than as a fade.
	# ⚠ `PackedFloat32Array.to_byte_array()` is one conversion, not a call per texel.
	# ⚠⚠ **SIGNED, AND UNSIGNED WAS THE DEFECT** (2026-08-28, the user: 「왜 저게 흔색 이 거품이 딱
	# 붙질 못할까」). The bake measures the coastline where the shore crosses **its own** sea height,
	# and the game's water plane sits half a tile above that — so the line the sea draws itself at is a
	# third of a tile INSIDE the line it was handed. ⚠ **An unsigned field cannot be shifted.** The dial
	# that exists for exactly this, `WATER_SHORE_OFFSET_TILES`, subtracts a distance; on an unsigned
	# field that turns the contour into a BAND — the zero crossing appears twice, once each side of the
	# baked line, and everything between goes full white. **Measured: it welded the line to the rock and
	# made it four times as thick**, which is the fat collar and not a shoreline.
	# ⇒ **Store the sign.** Negative inside the coast ring, positive outside, so moving the contour is
	# one addition and lands where a real waterline lands: rounded off at a convex corner, exactly as
	# the shore's own roll is rounded.
	# ⚠ Encoded as `0.5 + signed / (2 * span)` — 0 is deep inland, 1 is open sea, 0.5 is the baked line.
	var buf := PackedFloat32Array()
	buf.resize(tw * th)
	if coast.is_empty():
		for i in buf.size():
			buf[i] = 1.0
	else:
		# Unpacked once: reading four floats out of a nested array inside the inner loop is the same
		# work repeated a quarter of a million times over.
		var ax := PackedFloat32Array()
		var ay := PackedFloat32Array()
		var bx := PackedFloat32Array()
		var by := PackedFloat32Array()
		for seg in coast:
			ax.append(float(seg[0]))
			ay.append(float(seg[1]))
			bx.append(float(seg[2]))
			by.append(float(seg[3]))
		var n := ax.size()
		# Per-segment vertical reach, so a row can skip every segment that cannot possibly be its
		# nearest. ⚠⚠ **This is not a micro-optimisation, it is what pays for the resolution**: at
		# sixteen texels per tile the field is a quarter of a million texels, and without the filter the
		# whole net run went from 31 seconds to 53.
		var ylo := PackedFloat32Array()
		var yhi := PackedFloat32Array()
		for i in n:
			ylo.append(minf(ay[i], by[i]) - span)
			yhi.append(maxf(ay[i], by[i]) + span)
		var span2 := span * span
		var near := PackedInt32Array()
		# ⚠⚠ **The sign comes from a ray count, and it is done PER ROW and not per texel.** Asking
		# 48 segments about a quarter of a million texels is twelve million tests in GDScript; a
		# horizontal line crosses the ring at a handful of places, so the crossings are found once for
		# the row and swept. **The ring is closed** — every endpoint in `island.json` has degree two,
		# checked — which is what makes an odd crossing count mean「inside」at all.
		var xs := PackedFloat32Array()
		for py in th:
			var wy := (float(py) + 0.5) / float(sub) - margin
			var row := py * tw
			near.clear()
			for i in n:
				if wy >= ylo[i] and wy <= yhi[i]:
					near.append(i)
			xs.clear()
			for i in n:
				# Half-open on purpose: a vertex sitting exactly on the row is counted once, not twice.
				if (ay[i] > wy) != (by[i] > wy):
					xs.append(ax[i] + (wy - ay[i]) * (bx[i] - ax[i]) / (by[i] - ay[i]))
			xs.sort()
			var xn := xs.size()
			if near.is_empty():
				# ⚠ **Still asks the sign**, or a row deep enough inland that no segment is within reach
				# would be written down as open sea. Nothing stands there today; a wider island is one
				# block away from it.
				for px in tw:
					var wxo := (float(px) + 0.5) / float(sub) - margin
					var co := 0
					for q in xn:
						if xs[q] < wxo:
							co += 1
					buf[row + px] = 0.0 if (co & 1) == 1 else 1.0
				continue
			var m := near.size()
			var cross := 0
			for px in tw:
				var wx := (float(px) + 0.5) / float(sub) - margin
				while cross < xn and xs[cross] < wx:
					cross += 1
				var inside := (cross & 1) == 1
				var best2 := span2
				for k in m:
					var i := near[k]
					var ex := bx[i] - ax[i]
					var ey := by[i] - ay[i]
					var len2 := ex * ex + ey * ey
					var qx := wx - ax[i]
					var qy := wy - ay[i]
					# The nearest point ON the segment, clamped to its ends — measuring to the infinite
					# line would foam along the coast's continuation out into open sea.
					var u := 0.0 if len2 <= 0.0 else clampf((qx * ex + qy * ey) / len2, 0.0, 1.0)
					var dx2 := qx - ex * u
					var dy2 := qy - ey * u
					var d2 := dx2 * dx2 + dy2 * dy2
					if d2 < best2:
						best2 = d2
				var sd := sqrt(best2)
				buf[row + px] = clampf(0.5 + (-sd if inside else sd) / (span * 2.0), 0.0, 1.0)
	var img := Image.create_from_data(tw, th, false, Image.FORMAT_RF, buf.to_byte_array())
	return ImageTexture.create_from_image(img)



## **Every dial the sea reads**, handed over on every build because a constant may have moved
## even when the island has not.
static func _hand_the_sea_its_numbers(mat: ShaderMaterial, g, margin: float,
									  span: float) -> void:
	var gw := float(g.w)
	var gh := float(g.h)
	mat.set_shader_parameter("field_origin", Vector2(-margin, -margin))
	mat.set_shader_parameter("field_size", Vector2(gw + margin * 2.0, gh + margin * 2.0))
	mat.set_shader_parameter("field_span", span)
	_hand_the_sea_its_look(mat)


## **Every dial the sea reads.** ⚠ **The count used to be written into this line and it was six out by
## the time anybody read it** — the list below is the only place it lives now.
## ⚠⚠ **There were about forty until
## 2026-08-28**, when seven shorelines were built side by side in `.prototypes/shoreline/` and the one
## that does the least won. Swell, ripple, drawn crests, travelling foam and the shallows all left with
## the old shader; **their constants are still in `look.gd`, parked and unread.**
##
## ⚠⚠ **The list was replaced again on 2026-08-29**, when twenty-seven versions of the border itself
## were built side by side in `.prototypes/swash/` and the user chose `27-gaps` — **two whites, thin and
## hard-edged, slow, and broken.** Eleven dials of the 08-28 border went with it (the third warp octave,
## the warp speeds, the swing set and the peel set) and eighteen arrived. **The flat sea and the single
## border are untouched**; what changed is what that border is made of.
##
## ⚠ Split out and called from BOTH places on purpose: the material is built once at startup and the
## island's own numbers are handed over on every build, and a dial that only one of them set was a dial
## that changed nothing until the next island opened.
static func _hand_the_sea_its_look(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("sea", Look.COL_WATER)
	mat.set_shader_parameter("foam", Look.COL_WATER_FOAM)
	mat.set_shader_parameter("shore_offset", Look.WATER_SHORE_OFFSET_TILES)
	mat.set_shader_parameter("line_tiles", Look.WATER_LINE_TILES)
	mat.set_shader_parameter("line_hard", Look.WATER_LINE_HARD)
	mat.set_shader_parameter("line_alpha", Look.WATER_LINE_ALPHA)
	mat.set_shader_parameter("run", Look.WATER_RUN)
	mat.set_shader_parameter("cycle", Look.WATER_CYCLE)
	mat.set_shader_parameter("grad_step", Look.WATER_GRAD_STEP)
	mat.set_shader_parameter("warp_a", Look.WATER_WARP_A)
	mat.set_shader_parameter("warp_a_scale", Look.WATER_WARP_A_SCALE)
	mat.set_shader_parameter("warp_b", Look.WATER_WARP_B)
	mat.set_shader_parameter("warp_b_scale", Look.WATER_WARP_B_SCALE)
	mat.set_shader_parameter("along_scale", Look.WATER_ALONG_SCALE)
	mat.set_shader_parameter("curve_step", Look.WATER_CURVE_STEP)
	mat.set_shader_parameter("refract_amt", Look.WATER_REFRACT)
	mat.set_shader_parameter("point_gain", Look.WATER_POINT_GAIN)
	mat.set_shader_parameter("bay_floor", Look.WATER_BAY_FLOOR)
	mat.set_shader_parameter("rate", Look.WATER_RATE)
	mat.set_shader_parameter("swash", Look.WATER_SWASH)
	mat.set_shader_parameter("rise_frac", Look.WATER_RISE_FRAC)
	mat.set_shader_parameter("rest_frac", Look.WATER_REST_FRAC)
	mat.set_shader_parameter("surge", Look.WATER_SURGE)
	mat.set_shader_parameter("rest_shape", Look.WATER_REST_SHAPE)
	mat.set_shader_parameter("second_at", Look.WATER_SECOND_AT)
	mat.set_shader_parameter("second_w", Look.WATER_SECOND_W)
	mat.set_shader_parameter("second_amt", Look.WATER_SECOND_AMT)
	mat.set_shader_parameter("cut_scale", Look.WATER_CUT_SCALE)
	mat.set_shader_parameter("cut_drift", Look.WATER_CUT_DRIFT)
	mat.set_shader_parameter("cut_shut", Look.WATER_CUT_SHUT)
	mat.set_shader_parameter("cut_open", Look.WATER_CUT_OPEN)
	mat.set_shader_parameter("tip_at", Look.WATER_TIP_AT)
	mat.set_shader_parameter("tip_full", Look.WATER_TIP_FULL)
	mat.set_shader_parameter("first_cut", Look.WATER_FIRST_CUT)
	mat.set_shader_parameter("calm", Look.WATER_CALM)
	mat.set_shader_parameter("calm_scale", Look.WATER_CALM_SCALE)
	mat.set_shader_parameter("calm_speed", Look.WATER_CALM_SPEED)

	# **Section 8's dials — the open water itself**, chosen 2026-08-30 out of five candidates shot with
	# a hull crossing. ⚠ **They are constants like the rest of this list and none of them moves**: the
	# scatter drifts on `TIME` inside the shader, so there is nothing here to hand over per frame.
	mat.set_shader_parameter("fleck_col", Look.COL_WATER_FLECK)
	mat.set_shader_parameter("fleck_cell", Look.WATER_FLECK_CELL)
	mat.set_shader_parameter("fleck_fill", Look.WATER_FLECK_FILL)
	mat.set_shader_parameter("fleck_r_min", Look.WATER_FLECK_R_MIN)
	mat.set_shader_parameter("fleck_r_max", Look.WATER_FLECK_R_MAX)
	mat.set_shader_parameter("fleck_hard", Look.WATER_FLECK_HARD)
	mat.set_shader_parameter("fleck_amt", Look.WATER_FLECK_AMT)
	mat.set_shader_parameter("fleck_current", Look.WATER_FLECK_CURRENT)

	# ⚠⚠ **Section 7's dials, and the two that MOVE are not here.** `wake_hull` and `wake_t` change
	# every frame and are handed over by `_paint_wake`; everything below is a constant, so it goes with
	# the rest of the sea's numbers and cannot be the dial that only one of the two call sites set.
	mat.set_shader_parameter("wake_life", Look.WAKE_LIFE_SEC)
	mat.set_shader_parameter("wake_stern", Look.wake_stern_tiles())
	mat.set_shader_parameter("wake_w", Look.WAKE_W_TILES)
	mat.set_shader_parameter("wake_hard", Look.WAKE_HARD)
	mat.set_shader_parameter("wake_side_close", Look.WAKE_SIDE_CLOSE)
	mat.set_shader_parameter("wake_alpha", Look.WAKE_ALPHA)
	mat.set_shader_parameter("wake_froth_scale", Look.WAKE_FROTH_SCALE)
	mat.set_shader_parameter("wake_froth_amt", Look.WAKE_FROTH_AMT)
	# ⚠ **The hull's own footprint comes out of `Rules` and not out of `Look`**: where a boat stops is
	# a rule, the box it stops with is the same box, and a second copy here would be right until the
	# next export of `boat.glb`.
	mat.set_shader_parameter("hull_half", Rules.BOAT_HULL_HALF_TILES)
	mat.set_shader_parameter("hull_beam", Rules.BOAT_HULL_BEAM_TILES * 0.5)
	mat.set_shader_parameter("hull_shadow_w", Look.HULL_SHADOW_W_TILES)
	mat.set_shader_parameter("hull_shadow_bow", Look.HULL_SHADOW_BOW)
	mat.set_shader_parameter("hull_shadow_col", Look.hull_shadow_colour())
	mat.set_shader_parameter("hull_break_w", Look.HULL_BREAK_W_TILES)
	mat.set_shader_parameter("hull_break_amt", Look.HULL_BREAK_AMT)
	mat.set_shader_parameter("hull_break_bow", Look.HULL_BREAK_BOW)
	mat.set_shader_parameter("hull_halo_tiles", Look.HULL_HALO_TILES)
	mat.set_shader_parameter("hull_halo_amt", Look.HULL_HALO_AMT)
	mat.set_shader_parameter("hull_halo_aft", Look.HULL_HALO_AFT)

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
	# ⚠⚠ **FIXED_Y AND NOT ENABLED** (2026-08-31, 개발지식 01 기법 1). Full billboard turns on every
	# axis, so pitching the camera down lays the body flat on the ground; fixing the up axis keeps it
	# standing whatever the camera does. ⚠ **Godot rebuilds the model matrix for a billboard and can
	# throw the node's scale away** — this repo already measured that on the labs — so `_billboard_scale`
	# is checked on screen after this line changes, never assumed.
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# ⚠ **DISCARD gives the sprite a real depth value**, so a body behind a cliff is hidden by it
	# rather than drawing through it. Without it a billboard is one transparent quad that neither
	# occludes nor is occluded.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# ⚠⚠ **UNSHADED, AND IT WAS TRIED THE OTHER WAY TODAY** (2026-08-31, 개발지식 01 기법 16). The doc
	# calls taking the same light the minimum, so `shaded = true` was put in and photographed: **the
	# faction tint washed out to near white.** A billboard's normal faces the CAMERA, so the sun hits
	# every body square-on at full strength and multiplies the blue away — and which side a body is on
	# is carried by exactly that blue (기법 27, and this repo's own rule).
	# ⇒ **Technique 16 is not free here. It needs the ambient matched WITHOUT the sun**, or the tint
	# re-applied after the light, and neither is a line. **Left unshaded on purpose, not by omission.**
	s.shaded = false
	# ⚠⚠ **A BODY CASTS NO REAL SHADOW ANY MORE** (2026-08-28, the user: 「그림자도 단순하게 아래
	# 동그라미정도해줘」). A billboard's cast shadow is the shadow of a flat card that keeps turning to
	# face the camera — it swings as the board turns, which is the one thing a shadow must not do.
	# **`_put_ground_shadow` draws a disc under the body instead**, and that disc is now the only
	# shadow a body has.
	# ⚠ **The island, the buildings and the props keep their real shadows** — they are solid and the
	# sun's own direction reads correctly on them (2026-08-26, the user: 「해 하나가 맞는듯」).
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(s)
	_sprites.append(s)
	_sprites_used += 1
	return s


## ⚠⚠ **`_hull_box` STOOD HERE AND IT IS DELETED** (2026-08-29) with the boats. **The fact it cost a
## capture to learn**: `COL_BOAT` was a tan measured on a FLAT BOARD, and under this world's sun plus
## fill plus ambient a 0.85 albedo lands past 1.0 — every hull rendered as a solid white rectangle.
## **A mark on the water has to read the same at every sun angle**, so its material was unshaded.


## **The scale a `Sprite3D` needs so `pic` draws `wide` world-px across**, squashed by `squash`.
##
## ⚠ **One place, because a body on the ground and a rider on a deck are the same picture drawn the
## same size.** Splitting the arithmetic is how one of the two silently loses whatever the other gains —
## it happened once with the HP bar, and the note about it is still in `_put_soldier`.
## ⚠ `squash.x` is divided by, so it is floored: a squash of zero is a width of zero and a scale of
## infinity, and an infinite scale is a body that fills the screen for one frame.
func _billboard_scale(pic: Texture2D, wide: float, squash: Vector2) -> Vector3:
	var sx := wide * squash.x / float(pic.get_width())
	var sy := sx * squash.y / maxf(squash.x, 0.001)
	return Vector3(sx, sy * _pitch_stretch(), 1.0)


## **How much taller a body is drawn to pay back what the camera's pitch takes away** (개발지식 01
## 기법 22). `BILLBOARD_FIXED_Y` stands the card upright in the WORLD, so a camera looking down sees a
## foreshortened card — the further down, the shorter the man, and 「the art is bad」 is what that looks
## like from outside. ⚠ **1.0 at the opening angle by construction**, so the size judged on screen is
## the size that is kept; the ratio only ever pulls the body back UP, never squashes it.
func _pitch_stretch() -> float:
	var opened := cos(deg_to_rad(Look.CAM_PITCH_DEG))
	var now := cos(deg_to_rad(cam_pitch_deg))
	if now <= 0.001:
		return Look.BILLBOARD_PITCH_STRETCH_MAX
	return clampf(opened / now, 1.0, Look.BILLBOARD_PITCH_STRETCH_MAX)


## Puts one billboard at a body's feet. `centre_px` is the same world px the flat board drew at, so
## every offset that already went through `_body_offset_of` follows across for free.
##
## ⚠⚠ **A `bleed_sec` PARAMETER STOOD HERE AND IT IS DELETED** (2026-08-29) with the statuses — see
## `battle.gd`'s status block for why nothing could ever light one. **The measurement it carried, for
## the day blood comes back**: the blood must be mixed in AFTER the faction tint, because tinting an
## already-bled colour pulls it 45% back toward white and throws most of the pull away — measured, the
## body's HUE did not move at all and only its brightness fell 27%, which reads as shade, not as blood.
## ⚠⚠ **`at_tiles` IS THE BODY'S REAL PLACE AND `centre_px` IS WHERE IT IS DRAWN, AND THEY ARE NOT THE
## SAME POINT** (2026-08-28, the user: 「캐릭터가 좌우하면서 idle때 자꾸 2층을 넘어가네 이건 무슨
## 버그임?」). `centre_px` carries the lunge, the knock-back and the idle sway on top of the sim's
## position; the ground under it was being sampled at that swayed point, so **a body standing still on
## the lip of the plateau swayed across the tile line and its feet dropped a whole storey and came
## back, over and over.** It was not walking anywhere — the sway alone did it.
##
## ⚠⚠ **AND IT IS IN TILES, NOT PIXELS, WHICH IS THE SECOND HALF OF THE SAME BUG** (2026-08-28, the
## user: 「지금보면 땅속으로 들어감 2층 에서 보셈」). The height was asked as `centre_px / TILE_PX`, and
## `Look.tile_point_px` puts a tile CENTRE half a tile along both axes — so the sample landed at
## `pos + 0.5`, and `Grid.surface_h` rounds. **A body standing on the lip of the plateau read the
## height of the tile NEXT to it**, which on the plateau's edge is the floor a storey down: the body
## sank into the ground. ⚠ The y axis was worse still — `TILE_H_PX` need not equal `TILE_PX`, so the
## two axes were off by different amounts.
## ⇒ **The sim's own tile-unit position goes in, untouched.** The picture is offset afterwards.
## ⚠⚠ **`crowd_px` IS THE THIRD POINT AND IT IS NOT A FOURTH IDEA OF WHERE THE BODY IS.** A 조각
## admits `Rules.TILE_CAPACITY` bodies since 2026-08-30 and the sim walks every one of them to the same
## 조각 centre; this is how far off that centre THIS body is drawn. **The shadow takes it and the idle
## sway does not** — a crowd offset is where the body is standing, so the disc goes with it, while the
## sway is the body moving over a disc that stays put.
## ⚠⚠ **IT TOOK A `radius` AND IT TAKES THE `type_id` IT WAS DERIVED FROM** (2026-08-30). The radius is
## one read of the row; the row also says how big this species is drawn, and passing the derived number
## while the caller kept the row is how the two would have been read in two places.
func _put_body(centre_px: Vector2, at_tiles: Vector2, crowd_px: Vector2, type_id: int, colour: Color,
		squash: Vector2, tex: Texture2D) -> void:
	var radius := Look.body_radius_of(type_id)
	# ⚠⚠ **The shadow goes down FIRST and it is the body's only one** (2026-08-28, the user: 「그림자도
	# 단순하게 아래 동그라미정도해줘」). It is drawn from here rather than from the two callers because
	# this is the one place a body's centre and its drawn width are both in hand — putting it in the
	# callers is how the deck soldier lost its HP bar once, one function over.
	# ⚠ **The shadow goes under the SIM's position, not the swayed one.** A shadow that slides with the
	# idle sway reads as the body hovering; a body swaying over a still shadow reads as breathing.
	# ⚠⚠ **`beast_draw_scale` IS THE SPECIES' OWN DEPARTURE FROM THE SHARED SIZE** (2026-08-30, the
	# user: 「the wolf ... is so small I can't spot it」 against 「I'd like the character to be about
	# right」 for the swordsman). One number could not answer both judgements — see `BODY_SPRITE_SCALE`.
	var wide := (radius * Look.BEAST_SPRITE_W_RATIO if tex != null else radius * 2.0) \
			* Look.BODY_SPRITE_SCALE * Look.beast_draw_scale(type_id)
	# ⚠⚠ **THE DISC IS A FRACTION OF THE DRAWN PICTURE, NOT OF THE SIM RADIUS** (2026-08-30, the user:
	# 「the soldiers have no shadow」). It was `radius * BODY_SPRITE_SCALE * 0.62`, and the picture is
	# `radius * BEAST_SPRITE_W_RATIO(3.5) * BODY_SPRITE_SCALE` across — **so the disc was one fifth of the
	# body's width and sat entirely hidden underneath it.** The swordsman showed it worst: his picture is
	# 33x40 where a wolf's is 74x40, so at one drawn WIDTH he stands far taller and buries the disc.
	_put_ground_shadow(Look.tile_point_px(at_tiles) + crowd_px, wide * 0.5)
	var s := _sprite()
	var pic: Texture2D = tex if tex != null else _tex_body
	s.texture = pic
	s.modulate = Look.beast_tint(colour) if tex != null else colour
	s.scale = _billboard_scale(pic, wide, squash)
	var tall := float(pic.get_height()) * s.scale.y / Look.TILE_PX
	# ⚠⚠ **`_stand_h` AND NOT `_ground_h`, SO A BODY WALKS UP THE STAIR INSTEAD OF POPPING UP IT.**
	# `_ground_h` is one number per tile, which is right for the RULES and wrong for the feet: a stair
	# run climbs a whole storey across its tiles, so a body standing on one would float half a storey
	# at the mouth and sink half a storey at the head. **The sim's own height is untouched** — see
	# `Grid.surface_h`, which exists next to `height_at` precisely so the drawn ground and the measured
	# ground can differ without either pretending to be the other.
	var foot := _stand_h(at_tiles) + Look.BODY_LIFT_PX / Look.TILE_PX
	# ⚠⚠ **AND THE FRAME'S BOTTOM IS NOT THE ANIMAL'S FEET** — see `_measure_body_feet`, which the deck
	# has needed since it was built and the island needs now that the wolf ashore is a 92 x 92 frame
	# with 11 to 25 empty rows under it. **Footed by the frame it hangs 0.26 조각 above the ground, by a
	# DIFFERENT amount per picture**, so the animal would rise and fall as it turned. ⚠ **Every other
	# body picture measures 0 rows**, so nothing but the wolf moved when this went in.
	var sole := float(_foot_body.get(pic, 0.0)) * tall
	s.position = Vector3(centre_px.x / Look.TILE_PX, foot - sole + tall * 0.5,
		centre_px.y / Look.TILE_PX)
	# ⚠⚠ **THE TOP USED TO BE RETURNED HERE and the halo that read it is deleted** (2026-08-29).
	# **The rule it carried is the part to keep**: a wolf is 55 x 40 and a caveman 36 x 40, so sized by
	# WIDTH off the same radius the man stands half again as tall as the animal. ⇒ **Nothing that
	# hangs above a body may compute its own height from the radius.** The HP bar did, and it landed
	# across the caveman's face the first time he was on screen.


## ⚠⚠ **`_put_hp` STOOD HERE AND IS DELETED** (2026-08-28, the user: 「체력바 없이」). It drew the two
## halves of a bar above every body. **The bodies are being redone** — the user, earlier the same day:
## 「캐릭터랑 건물제거 다시잡을꺼임」 — and a bar over every one of them is chrome nobody chose, of
## exactly the kind `CLAUDE.md` now says is designed in a tool rather than typed here.
## ⚠ **The sim is untouched**: `army.hp` and `battle.enemy_hp` are unchanged and still decide who dies.


## Every body, every frame. **This is what pass 6, 7 and 8 of the old `_draw` were**, minus the marks
## that are not ported yet.
func _paint_bodies() -> void:
	_sprites_used = 0
	if battle == null or army == null or battle.grid == null:
		# ⚠ **Still called on the empty path**: `_paint_boats` is what hides a pooled hull, so skipping
		# it here would leave the last island's boats standing on the title screen.
		_paint_boats()
		_hide_unused()
		return

	# ⚠ **Beasts first and 검사 after, which is the order the deleted drawer kept** — and in 3D the
	# depth buffer decides what reads on top, not the order. It is written this way so the day
	# something needs the order back, it is here rather than having to be rediscovered.
	for raw_id in battle.living_enemy_ids():
		var e := int(raw_id)
		_put_walker("e%d" % e, int(battle.enemy_type[e]), battle.enemy_pos[e], true,
			_crowd_slot_of(battle.enemy_pos[e], Battle.ENEMY_UID_BASE + e))

	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		_put_walker("s%d" % i, int(army.type_id[i]), battle.soldier_pos[i], false,
			_crowd_slot_of(battle.soldier_pos[i], i))

	# ⚠ **Inside this function and not beside it.** The riders come out of the same `Sprite3D` pool the
	# bodies do, and that pool is opened by the `_sprites_used = 0` above and closed by the
	# `_hide_unused()` below — painted outside the pair, every rider would be hidden the same frame it
	# was drawn.
	_paint_boats()

	_hide_unused()


## **One flat disc on the ground under a body, and it is the whole of a body's shadow.**
##
## ⚠⚠ **A billboard's real cast shadow is deleted with this** (`_sprite`). A card that turns to face
## the camera casts a shadow that swings when the board turns, which is the one thing a shadow must
## not do — the island, the buildings and the props keep theirs, because they are solid.
##
## ⚠ **It goes into the GROUND fx buffer**, so it wears the terrain's own height at every vertex and
## climbs a slope with the body instead of hovering flat over one. That is the same path the landing
## ring and the area ring take, and `net_fx_view` already measures that property on them.
##
## ⚠ **No offset toward or away from the sun.** The disc laid under props in 2026-08-25 was offset by
## `(sin(yaw), cos(yaw))` — *toward* the sun, the wrong way — and nobody caught it for as long as it
## was the only shadow there was. **A disc directly under the body cannot be pointing the wrong way.**
## ⚠⚠ **`half_px` IS THE DRAWN PICTURE'S HALF-WIDTH AND IT ALREADY CARRIES `BODY_SPRITE_SCALE`**
## (2026-08-30). It took the SIM radius until then and multiplied the scale in here, which is how the
## disc ended up one fifth of the body's width. **Do not multiply the scale in again.**
func _put_ground_shadow(centre_px: Vector2, half_px: float) -> void:
	var r := half_px * Look.BODY_SHADOW_RADIUS_RATIO
	_g_disc(centre_px, r, Look.COL_BODY_SHADOW)


## ⚠ **`_put_halo` stood here and it is deleted** (2026-08-29) with the hit it marked — see the
## effects block at the foot of this file for what it knew.


## The picture a body wears. **One place**, so the ghost, the soldier on a deck and the body ashore
## cannot end up wearing three different things.
##
## ⚠⚠ **`is_enemy` IS GONE, and its absence is the point.** The argument existed because one table row
## served two species — the player's ranged slot borrowed the enemy crow's row — so a row had to
## answer with two pictures depending on who asked. `Rules.UNITS` has a row per species now, so there
## is nothing left for it to select between. Which side a body is on still reaches the screen, through
## `Look.body_colour_of`; it is a TINT and not a different animal.
func _beast_tex(type_id: int, head: Vector2) -> Texture2D:
	if type_id < 0 or type_id >= _tex_facing.size():
		return null
	var pics: Array = _tex_facing[type_id]
	var facing := _facing_index(type_id, head)
	if facing < 0 or facing >= pics.size():
		return null
	return pics[facing]


## **Which of its row's pictures a body heading `head` wears. ONE rule, and the only place the camera's
## own axes decide anything about a body's picture.**
##
## ⚠⚠ **SCREEN AXES AND NOT A COMPASS.** The board turns, so a picker written against world north puts
## a body facing the wrong way the moment the player presses the turn key — and nothing else on screen
## moves, so it reads as the bodies spinning for no reason. This is the resolution the boat deck has
## used since it was built; **it is not a second copy of it, it is the same one, and the deck now comes
## through here too.**
## ⚠⚠ **THE ROW'S OWN LENGTH IS WHAT DECIDES WHETHER UP AND DOWN EXIST**, so a species gains them by
## gaining two pictures and nothing here is edited. A two-picture row leans its whole heading onto
## screen-right, which is what a side-on drawing can say.
## ⚠ **A tie goes to right/left**, which is what the deck did before this and is worth keeping: a
## body walking exactly diagonally reads better side-on than head-on.
## ⚠⚠ **THE TWO-PICTURE ROWS MOVED FROM WORLD `head.x` TO SCREEN RIGHT** (2026-08-30). At the opening
## yaw the two are the same axis, so nothing changed on the screen the user is looking at; **turned,
## the swordsman, the bear and the crow used to face backwards** and now do not. It is one rule because
## two rules in one picker is how the wolf and the man end up disagreeing about which way is right.
func _facing_index(type_id: int, head: Vector2) -> int:
	var right := head.dot(_ground_right())
	var down := head.dot(_ground_down())
	if Look.beast_facings(type_id) > Look.FACE_DOWN and absf(down) > absf(right):
		return Look.FACE_DOWN if down >= 0.0 else Look.FACE_UP
	return Look.FACE_RIGHT if right >= 0.0 else Look.FACE_LEFT


## ⚠ **Static so it can run in a member initialiser**, which is where the ten hand-named `load()`
## calls it replaces used to run. `null` for an empty path rather than a missing entry: the outer array
## is indexed by unit row and a short one would fault on the last species instead of drawing a square.
static func _load_beast_tex() -> Array:
	var out := []
	for ty in Look.BEAST_TEX.size():
		var pics: Array[Texture2D] = []
		for facing in Look.beast_facings(ty):
			var path := Look.beast_tex_path(ty, facing)
			pics.append(null if path.is_empty() else load(path) as Texture2D)
		out.append(pics)
	return out


## Every strip every row declares, loaded once. **Static for the same reason `_load_beast_tex` is** —
## it runs in a member initialiser. The loop walks the row's own facings and `Anim` rather than a list
## of animated species, so a row that declares nothing contributes an empty strip and costs no branch
## anywhere downstream. ⚠ **Every row declares nothing today** — see `Look.NO_ANIM_FRAMES`.
static func _load_beast_anim() -> Array:
	var out := []
	for ty in Look.BEAST_TEX.size():
		var per_facing := []
		for facing in Look.beast_facings(ty):
			var per_anim := []
			for anim in Look.ANIM_NAME.size():
				var strip: Array[Texture2D] = []
				for f in Look.beast_anim_frames(ty, anim):
					strip.append(load(Look.beast_frame_path(ty, anim, f, facing)) as Texture2D)
				per_anim.append(strip)
			per_facing.append(per_anim)
		out.append(per_facing)
	return out


## Row `type_id`'s `anim` strip facing `facing`, empty where there is none.
func _anim_strip(type_id: int, anim: int, facing: int) -> Array:
	if type_id < 0 or type_id >= _tex_anim.size():
		return []
	var per_facing: Array = _tex_anim[type_id]
	if facing < 0 or facing >= per_facing.size():
		return []
	var per_anim: Array = per_facing[facing]
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
func _body_tex(key: String, type_id: int, head: Vector2) -> Texture2D:
	var idle := _beast_tex(type_id, head)
	if not _body.has(key):
		return idle
	var b: Dictionary = _body[key]
	var bite := float(b["bite"])
	var anim := Look.Anim.BITE if bite > 0.0 else Look.Anim.WALK
	var strip := _anim_strip(type_id, anim, _facing_index(type_id, head))
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


## **One walking body at a 조각 position — a 검사 or a 짐승, and it is deliberately ONE function.**
##
## ⚠⚠ **IT TOOK A SOLDIER ID AND IT TAKES A KEY NOW** (2026-08-30, 티켓 41). The two sides index
## different columns in the sim, so an id alone cannot say which body it names; **the key is what every
## per-body clock in this file is already stored under**, so passing it in is what stops the beast arm
## growing its own copy of the gait, the sway and the facing. **Splitting them is how one of the two
## silently loses whatever the other gains** — it happened once with the HP bar, itself deleted now.
##
## ⚠ **The side reaches the screen as a TINT and never as a different animal** — `Look.body_colour_of`.
## The picture comes from the unit row, which is why a 검사 and a 늑대 need no branch here at all.
func _put_walker(key: String, type_id: int, at: Vector2, is_enemy: bool, slot: int) -> void:
	# ⚠ **The crowd offset is kept apart from the sway** and handed down separately — see `_put_body`,
	# where the shadow takes one and not the other.
	var crowd := Look.crowd_offset_px(slot, Rules.TILE_CAPACITY)
	var centre := Look.tile_point_px(at) + crowd + _body_offset_of(key)
	# A body faces the way it last walked. `_facing_of` returns RIGHT when it has never moved, so a
	# body standing still faces right rather than flipping on a zero vector.
	var tex := _body_tex(key, type_id, _facing_of(key))
	_put_body(centre, at, crowd, type_id, Look.body_colour_of(is_enemy), _gait_squash(key), tex)


## **Which slot of its own 조각 this body holds, or 0 when the sim does not say.**
##
## ⚠⚠ **THE SIM OWNS THE SLOT AND THIS ONLY READS IT.** `Grid` hands the lowest free slot to whoever
## claims a 조각, so the number is already deterministic and already the same for everyone looking; a
## slot invented here — off the body's index, say — would put two bodies in one place the moment one of
## them died.
##
## ⚠ **0 on a refusal, and 0 is the 조각 centre**, which is where a body was drawn before crowds
## existed. A body mid-step holds the 조각 it is walking into as well as the one it stands on; the
## rounded position is which of the two it is nearer, and that is the one it is drawn in.
func _crowd_slot_of(at: Vector2, unit_id: int) -> int:
	if battle == null or battle.grid == null or battle.grid.w <= 0:
		return 0
	var g := battle.grid
	var tx := clampi(int(round(at.x)), 0, g.w - 1)
	var ty := clampi(int(round(at.y)), 0, g.h - 1)
	return maxi(g.slot_of(ty * g.w + tx, unit_id), 0)


## ⚠ **Hidden, never freed.** A pool that shrinks is a pool that reallocates on the next busy frame,
## and a stale sprite left visible is a body that died and stayed on screen — the exact failure the
## per-frame drawer could not have.
func _hide_unused() -> void:
	for k in range(_sprites_used, _sprites.size()):
		_sprites[k].visible = false


# --- the beasts' boats, and the riders standing on them ---------------------------------------------
## **The sim's boat is a flat point and a landing 조각. Everything below is what the eye is given on top
## of that** — the bob, the roll, the hull's yaw and eight wolves on the benches. ⚠ **Nothing here is
## read back by `sim`**, which is the whole of the view seam's rule.

## One instantiated `boat.glb` per live hull. **Pooled and hidden, never freed**, the same rule
## `_sprite` keeps — and it bites harder here: instantiating a `PackedScene` is a whole scene build, and
## doing one per frame per boat is the shape that made the old per-frame node churn expensive.
var _boats: Array[Node3D] = []
var _boats_used := 0
var _boat_scene: PackedScene = null
## ⚠⚠ **`_tex_rider` AND `_load_rider_tex` STOOD HERE AND BOTH ARE DELETED** (2026-08-30). They loaded
## the four `wolf_h` pictures from a list of the deck's own, which is why the deck could wear the
## picture the user chose while the island wore the one he did not. **The riders read the wolf's row in
## `Look.BEAST_TEX`, through the same `_beast_tex` every body ashore goes through.**
## Seconds since this view was built, and **the only clock the bob and the roll read**. Advanced from
## `_process`'s own delta, so the sea rides the render loop like everything else in this file. ⚠ **Not
## `battle.elapsed`** — that is the sim's clock, and a hull that stopped bobbing when the sim was not
## stepped would read as the picture having frozen.
var _sea_clock := 0.0


## **Where each body picture's animal actually ends, so it can be stood on the ground rather than on
## the frame around it.**
##
## ⚠⚠ **THE FRAME'S BOTTOM IS NOT THE WOLF'S FEET.** `east.png` and `west.png` carry 25 empty rows
## under the animal, `south.png` 23 and `north.png` 11 — out of 92. Footed by the frame, a wolf hangs
## **0.26 조각 above the ground it stands on**, and it hangs a DIFFERENT amount per picture, so it
## rises and falls as it turns. ⚠ **Every other body picture measures 0**, so this costs the swordsman,
## the bear and the crow nothing at all.
## ⚠ **Once, at load**, and the answer cannot change while the game runs.
##
## ⚠⚠ **KEYED BY THE TEXTURE AND NOT BY INDEX.** A parallel array in the picture pool's own shape would
## have to be kept in step with it by hand, and the day the two disagree a body is footed with another
## species' padding — silently, because every value in range is plausible.
## ⚠ **Measured off the alpha channel, not typed.** A constant would be wrong for three of the wolf's
## four pictures however it was chosen.
static func _measure_body_feet(pool: Array) -> Dictionary:
	var out := {}
	for raw_pics in pool:
		for pic: Texture2D in (raw_pics as Array):
			if pic == null or out.has(pic):
				continue
			var img := pic.get_image()
			if img == null:
				continue
			var h := img.get_height()
			var w := img.get_width()
			var last := -1
			for y in h:
				for x in w:
					if img.get_pixel(x, y).a > 0.0:
						last = y
						break
			# **A picture with no opaque pixel at all foots at the frame**, which is what the old code
			# did for every picture — the fallback is the previous behaviour and not a guess.
			out[pic] = 0.0 if last < 0 else float(h - 1 - last) / float(h)
	return out


## A pooled hull. Null when the scene will not load, and **that is a real state**: `boat.glb` had never
## been imported before this ticket, and a caller that assumed a node came back would take the whole
## frame down instead of drawing one thing less.
func _boat() -> Node3D:
	if _boats_used < _boats.size():
		var reused := _boats[_boats_used]
		_boats_used += 1
		reused.visible = true
		return reused
	if _world == null:
		return null
	if _boat_scene == null:
		_boat_scene = load(BOAT_SCENE) as PackedScene
	if _boat_scene == null:
		return null
	var made := _boat_scene.instantiate() as Node3D
	if made == null:
		return null
	# ⚠ **The rim and NOT `_use_vertex_colours`.** The buildings and the scatter are objects standing on
	# the world and the rim is what separates them from it — a hull on open water needs it more, not
	# less. But `boat.glb` carries no COLOR_0 attribute at all (its six materials hold their own
	# colours), so reading vertex colours as albedo would multiply by nothing and land it white.
	_outline(made)
	# ⚠⚠ **AFTER `_outline` AND NEVER BEFORE.** `_outline` walks every `MeshInstance3D` under the node
	# and hangs a swollen black shell off it. Run over the shadow discs it would ring each one in ink,
	# which on a 13 px disc is the disc.
	_put_deck_shadows(made)
	_world.add_child(made)
	_boats.append(made)
	_boats_used += 1
	return made


## The name of the node holding one hull's eight deck shadows. ⚠ **The hull owns them and there is no
## second list of them anywhere** — a parallel array indexed by hull would have to be grown, shrunk and
## hidden in step with `_boats` by hand.
const DECK_SHADOWS := "deck_shadows"


## **One disc on the plank under each seat, built once with the hull.**
##
## ⚠⚠ **A CHILD OF THE HULL, WHICH IS THE WHOLE REASON IT IS BUILT HERE.** The boat bobs and rolls, and
## both live in the hull's own transform — see `_paint_boats`. A disc placed from the boat's POSITION
## each frame would keep the bob and lose the roll, and it would lose it in the way that is hardest to
## see: the shadow stays put while the deck under it tilts.
##
## ⚠ **The same idea as `_put_ground_shadow` and not the same code, and the difference is the surface.**
## A body's disc goes into the ground fx buffer, which wears the terrain's height at every vertex — a
## deck is not the terrain, and it moves. What is shared is the decision, which lives in `Look`:
## a flat disc directly underneath, no offset toward the sun, dark and cool rather than black.
func _put_deck_shadows(hull: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = DECK_SHADOWS
	for raw_slot in Look.BOAT_DECK_SLOTS:
		var slot := raw_slot as Vector3
		var m := MeshInstance3D.new()
		m.mesh = _disc_mesh()
		# ⚠ **`material_override` and not a surface material**, so `_outline` — which reads
		# `surface_get_material` — cannot reach the disc even if the call order above is changed back.
		m.material_override = _disc_material()
		m.position = Vector3(slot.x, slot.y + Look.BOAT_RIDER_SHADOW_LIFT_TILES, slot.z)
		# It is a shadow. Casting one would be the shadow of a shadow, and the sun would find its edge.
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(m)
	hull.add_child(holder)


## The one disc mesh and the one material every deck shadow wears. ⚠ **Shared, because every disc in
## the game is the same disc** — a per-instance copy is a second place the size could be written.
var _disc_cache: ArrayMesh = null
var _disc_mat: StandardMaterial3D = null


## A flat disc lying in the hull's own XZ plane, at `Look.boat_rider_shadow_r_tiles()`.
##
## ⚠ **The radius is read inside and not passed in.** With a parameter and a cache the second caller's
## radius is silently the first caller's, and every value in range looks right.
func _disc_mesh() -> ArrayMesh:
	if _disc_cache != null:
		return _disc_cache
	var r := Look.boat_rider_shadow_r_tiles()
	var v := PackedVector3Array()
	var segs := Look.BOAT_RIDER_SHADOW_SEGS
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		v.append(Vector3.ZERO)
		v.append(Vector3(cos(a0) * r, 0.0, sin(a0) * r))
		v.append(Vector3(cos(a1) * r, 0.0, sin(a1) * r))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_disc_cache = mesh
	return mesh


func _disc_material() -> StandardMaterial3D:
	if _disc_mat != null:
		return _disc_mat
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Look.COL_BOAT_RIDER_SHADOW
	# A shadow that takes the light is not a shadow — the same rule the outline shell keeps.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# ⚠ **Both faces.** The hull rolls, and a one-sided disc vanishes the moment the deck tips away.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ⚠ **Depth is read but not written.** The gunwale must be able to hide it; the wolf standing on it
	# must not be sorted behind it.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_disc_mat = mat
	return mat


func _hide_unused_boats() -> void:
	for k in range(_boats_used, _boats.size()):
		_boats[k].visible = false


## Every live hull, and the riders standing on it.
##
## ⚠ **The riders come out of `_sprite()`**, so this must run inside `_paint_bodies`' pool window — see
## the call site.
func _paint_boats() -> void:
	_boats_used = 0
	if battle == null or battle.grid == null:
		_hide_unused_boats()
		return
	for i in battle.boat_pos.size():
		var hull := _boat()
		if hull == null:
			break
		var centre := _boat_centre(i)
		# ⚠ **Each hull is one `BOAT_BOB_PHASE_PER_HULL` further along its own bob**, so two boats
		# sitting off the same island do not rise and fall as one object — see that constant.
		var phase := float(i) * Look.BOAT_BOB_PHASE_PER_HULL
		var bob := sin(_sea_clock * TAU / Look.BOAT_BOB_SEC + phase) * Look.BOAT_BOB_TILES
		hull.position = Vector3(centre.x, Look.SEA_Y_TILES + Look.BOAT_DRAFT_TILES + bob, centre.y)
		var head := _boat_heading(i)
		hull.rotation = Vector3(0.0, _boat_yaw(head), 0.0)
		# ⚠ **`rotate_object_local` and not a second Euler term.** The lean is about the hull's OWN
		# length, which is its local +X — written into `rotation.x` it would be a lean about the world's
		# x axis, and a boat sailing east would pitch bow-up instead of rolling.
		var roll := sin(_sea_clock * TAU / Look.BOAT_ROLL_SEC + phase) * Look.BOAT_ROLL_DEG
		hull.rotate_object_local(Vector3.RIGHT, deg_to_rad(roll))
		_paint_riders(hull, i, head)
	_hide_unused_boats()


## **Which way the hull is pointing, in 조각 units** — at the 조각 it is going to.
##
## ⚠ An ARRIVED boat is not on top of its beach 조각, it is `Rules.BOAT_STANDOFF_TILES` short of it, so
## this stays well defined after it stops and the hull keeps facing the shore. The guard below is for a
## degenerate board where the two coincide, not for arrival.
## **Where a hull's middle is, in 조각.**
##
## ⚠ **One place, because the hull and the water both need it.** The boat is drawn at this point and
## every mark the water makes about it is measured from the same one; two copies of the conversion
## would put the shadow beside the boat instead of under it.
func _boat_centre(i: int) -> Vector2:
	return Look.tile_point_px(battle.boat_pos[i]) / Look.TILE_PX


func _boat_heading(i: int) -> Vector2:
	var beach := int(battle.boat_beach[i])
	var target := Vector2(beach % battle.grid.w, beach / battle.grid.w)
	var d: Vector2 = target - (battle.boat_pos[i] as Vector2)
	if d.length() <= 0.001:
		return Vector2(0.0, -1.0)
	return d.normalized()


## The `rotation.y` that turns the model's bow along `head`.
##
## ⚠⚠ **THE MODEL'S BOW IS +X, MEASURED OFF THE FILE AND NOT GUESSED.** Inside `boat.glb`, `boat_stem`
## sits at local x = +2.30 and `boat_tail` at x = −2.26, and the hull's bounds run −2.60 .. +2.60 along x
## against −0.95 .. +0.95 along z: the long axis is X and the sharp end is the positive one. **Godot's
## own convention is −Z forward**, so a yaw written for that convention would sail every boat broadside
## on with every position check still green.
##
## ⇒ `rotation.y = θ` sends local +X to world `(cos θ, 0, −sin θ)`. A tile-space heading `(hx, hy)` is
## world `(hx, 0, hy)`, so `cos θ = hx` and `−sin θ = hy`, which is `θ = atan2(−hy, hx)`.
func _boat_yaw(head: Vector2) -> float:
	return atan2(-head.y, head.x)


## Eight wolves on four benches. **Placed through the hull's own transform**, so the bob and the roll
## carry them without either being written down twice.
func _paint_riders(hull: Node3D, i: int, head: Vector2) -> void:
	# ⚠⚠ **THE WOLF'S OWN ROW, THROUGH THE SAME CALL A BODY ASHORE MAKES** (2026-08-30). The deck had a
	# picture list and a picker of its own until then, and the island's wolf had a different pair of
	# pictures — which is exactly how the deck came to wear the animal the user chose while the island
	# did not. **There is one list now and the boat is not allowed its own.**
	var pic := _beast_tex(Rules.WOLF, head)
	if pic == null:
		return
	var riders := int(battle.boat_riders[i])
	# ⚠ **`BODY_SPRITE_SCALE` is NOT a factor here since 2026-08-30** — it is folded into
	# `BOAT_RIDER_W_RATIO`, so retuning how big a body reads on the ISLAND cannot resize the deck.
	var wide := Look.body_radius_of(Rules.WOLF) * Look.BOAT_RIDER_W_RATIO
	var shadows := hull.get_node_or_null(NodePath(DECK_SHADOWS))
	# ⚠ **The deck is what limits it, not the count.** A boat carrying more than there are benches puts
	# the extras nowhere rather than stacking two on one seat.
	# ⚠⚠ **ONE LOOP OVER THE SEATS AND NOT ONE PER THING A SEAT CARRIES.** The wolf and the disc under
	# it are the same seat being occupied; asked in two places, the day one of them is skipped is the
	# day a shadow lies on an empty plank.
	for k in Look.BOAT_DECK_SLOTS.size():
		var aboard := k < riders
		if shadows != null and k < shadows.get_child_count():
			(shadows.get_child(k) as Node3D).visible = aboard
		if not aboard:
			continue
		var s := _sprite()
		s.texture = pic
		s.modulate = Look.beast_tint(Look.body_colour_of(true))
		s.scale = _billboard_scale(pic, wide, Vector2.ONE)
		# ⚠⚠ **`hull.transform *` AND NOT `hull.to_global`, AND IT IS A MEASUREMENT.** `to_global` reads
		# `get_global_transform`, which on a node that is not inside the tree **errors and hands back
		# IDENTITY** — so every rider landed at its raw local offset in world space. In the game the
		# hull is under `_world` and treed, so the picture was right; **`net_fx_view` builds its view
		# untreed, so every rider row it holds was measuring nothing, and it barked 96 times in one
		# round saying so.** Multiplying by the hull's own transform is the same answer here (`_world`
		# is at identity and nothing moves it) and it is the same answer untreed.
		# ⚠ **The roll and the bob ride along for free**, because both are in that transform — which is
		# the whole reason a seat is asked of the hull rather than rebuilt from the boat's position.
		var seat := hull.transform * (Look.BOAT_DECK_SLOTS[k] as Vector3)
		# The sprite is centred on its own middle, so half its drawn height puts the bottom of its
		# FRAME on the plank.
		var tall := float(pic.get_height()) * s.scale.y / Look.TILE_PX
		# ⚠⚠ **AND THE FRAME'S BOTTOM IS NOT THE WOLF'S FEET** — see `_measure_body_feet`. The empty
		# rows under the animal are subtracted back off, so what stands on the plank is the animal.
		# **It is worth 0.16 조각 on the side-on picture** — a quarter of the wolf's own height, and the
		# difference between an animal whose legs start below the gunwale line and one whose whole body
		# is above it. ⚠ **And the four pictures differ**, so without this the deck's riders rise and
		# fall as the boat turns.
		var foot := float(_foot_body.get(pic, 0.0)) * tall
		s.position = Vector3(seat.x, seat.y - foot + tall * 0.5, seat.z)


## ⚠⚠ **`_boat_rider_tex` STOOD HERE AND IT IS DELETED** (2026-08-30). It resolved a heading against the
## board's two screen axes and indexed the deck's own picture list. **The resolution is not gone — it is
## `_facing_index`**, which every body on the island now goes through as well; what is gone is the deck
## having a second copy of it and a second list to point it at.


# --- what the water does about a hull ----------------------------------------------------------------
## **The wake and the contact, and it is ONE array because they are one shape.**
##
## One block of `Look.WAKE_SLOTS` per hull, and **every slot is a point on that hull's transom track**:
## slot 0 is where the transom is NOW and carries the heading, the rest are where it has been, newest
## first. The water shader reads the lot and draws both halves — see section 7 of `water.gdshader`.
##
## ⚠ **A slot with a negative time was never written**, which is the only「no hull here」 either side
## carries. `_sea_clock` never goes below zero, so there is no second flag to keep in step.
## ⚠⚠ **NOTHING HERE IS READ BACK BY `sim` AND NOTHING IN IT IS A FACT `sim` OWNS.** It is `boat_pos`
## remembered for a few seconds so that the water has something to draw.
var _wake := _wake_empty()
## When each hull's newest remembered point was taken, on `_sea_clock`. Negative for a hull with none.
var _wake_last := _wake_no_last()


## An empty history — every slot unwritten.
## ⚠ **`resize` alone is not this.** A `PackedVector4Array` grows filled with `Vector4.ZERO`, whose z
## is 0.0 — which reads as「written at time zero」 and stands twelve hulls on the origin.
static func _wake_empty() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(Look.WAKE_HULLS * Look.WAKE_SLOTS)
	for k in out.size():
		out[k] = Vector4(0.0, 0.0, -1.0, 0.0)
	return out


static func _wake_no_last() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(Look.WAKE_HULLS)
	out.fill(-1.0)
	return out


## **Pushes one remembered point onto a hull's block**, newest first, dropping the oldest off the end.
## ⚠ **Slot 0 is not touched here** — that one is rewritten every frame with where the hull is now,
## and this is what turns one of those frames into a point that stays.
static func _wake_commit(hist: PackedVector4Array, hull: int,
						 at: Vector4) -> PackedVector4Array:
	var base := hull * Look.WAKE_SLOTS
	for k in range(Look.WAKE_SLOTS - 1, 1, -1):
		hist[base + k] = hist[base + k - 1]
	hist[base + 1] = at
	return hist


## **Wipes one hull's whole block.** ⚠ Without it the last island opens the next one wearing its
## trails, and a hull that never sailed is drawn with a mark round nothing.
static func _wake_forget(hist: PackedVector4Array, hull: int) -> PackedVector4Array:
	var base := hull * Look.WAKE_SLOTS
	for k in Look.WAKE_SLOTS:
		hist[base + k] = Vector4(0.0, 0.0, -1.0, 0.0)
	return hist


## **The heading a slot carries, in radians, measured in 조각 space.**
##
## ⚠⚠ **THIS IS NOT `_boat_yaw` AND THE TWO DISAGREE ON EVERY HEADING BUT DUE EAST AND DUE WEST.**
## `_boat_yaw` answers the `rotation.y` that turns a MODEL whose bow is +X, and Godot's own convention
## puts +X at world `(cos θ, 0, −sin θ)` — so it carries a sign flip this does not. The shader reads
## `vec2(cos w, sin w)` straight, in the same 조각 space `boat_pos` speaks, and handing it a model yaw
## would draw every mark on the wrong side of the boat with every position check still green.
static func _wake_head_rad(head: Vector2) -> float:
	return atan2(head.y, head.x)


## **When a hull was last anywhere but here** — the moment its marks are aged from.
##
## ⚠⚠ **A HULL THAT HAS STOPPED STOPS MARKING THE WATER, AND WITHOUT THIS IT NEVER DOES.** An
## arrived boat sits off its beach for the rest of the island; stamped with `_sea_clock` every frame
## its newest point is forever nought seconds old, and the trail collapses to **a bright dot the width
## of the stroke, sitting on its transom, that never goes out.** Frozen at the last moment it actually
## moved, the whole trail ages out and stays out — which is what a wake is.
##
## ⚠ **A band and not an equality, and the band is the array's and not the arithmetic's.** A
## `PackedVector4Array` holds 32-bit floats, so a stored coordinate differs from the one that was
## written in about its seventh digit; one frame of real motion is `Rules.BOAT_SPEED_TILES / 60`, which
## is two hundred times the band either way.
func _wake_stamp(hull: int, stern: Vector2) -> float:
	var was: Vector4 = _wake[hull * Look.WAKE_SLOTS]
	if was.z < 0.0:
		return _sea_clock
	var still := absf(was.x - stern.x) < Look.WAKE_STILL_TILES 			and absf(was.y - stern.y) < Look.WAKE_STILL_TILES
	return was.z if still else _sea_clock


## **Remembers where every hull is, and hands the lot to the water.**
##
## ⚠⚠ **THE CLOCK IS `_sea_clock` AND THE SHADER IS HANDED THE SAME NUMBER.** Every slot is stamped
## against it, so a shader ageing them against its own `TIME` would fade a trail by however far the
## two stand apart — which is however long the game sat on the title screen.
## ⚠ **Called after the clock is ticked**, so a slot is stamped with the moment the same frame draws.
func _paint_wake() -> void:
	if _sea == null:
		return
	var mat := _sea.material_override as ShaderMaterial
	if mat == null:
		return
	var live := 0
	if battle != null and battle.grid != null:
		live = battle.boat_pos.size()
	# ⚠ **Over the SLOTS and not over the boats.** Past `Look.WAKE_HULLS` there is no block to write
	# into; a loop over the boats would run off the end of the array the thirteenth time one lands.
	for h in Look.WAKE_HULLS:
		if h >= live:
			_wake = _wake_forget(_wake, h)
			_wake_last[h] = -1.0
			continue
		var head := _boat_heading(h)
		var stern := _boat_centre(h) + head * Look.wake_stern_tiles()
		var now := Vector4(stern.x, stern.y, _wake_stamp(h, stern), _wake_head_rad(head))
		_wake[h * Look.WAKE_SLOTS] = now
		if _wake_last[h] < 0.0 or _sea_clock - _wake_last[h] >= Look.wake_every_sec():
			_wake_last[h] = _sea_clock
			_wake = _wake_commit(_wake, h, now)
	mat.set_shader_parameter("wake_hull", _wake)
	mat.set_shader_parameter("wake_t", _sea_clock)

# --- the body clocks, carried across the move unchanged ----------------------------------------------
## ⚠⚠ **Everything below this line is the file as it was.** The effects were never drawing code: they
## are a little simulation of their own with its own clock, and moving the picture into 3D did not
## touch one line of it. That is why `_fx` is still filling every frame while nothing paints it.


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
##
## ⚠⚠ **THE MARK IS BACK, AND IT IS THE 판 ITSELF** (2026-08-28, 티켓 14). It was three things in one
## day and then nothing at all for a round: two quads cut from a mask, then a raise of the mat's own
## object, then — when the 판 was welded into the island's single mesh — no node left to touch. **The
## 판 is its own object again** and the shader raises and lightens exactly the 칸 named here.
## ⚠ **Not a mesh rebuild and not a node hunt: one float.** Crossing a 조각 line inside one 칸 writes
## the same number again and costs nothing, which is what makes this affordable on every mouse move.
## ⚠ **-1 travels all the way through.** `game._tile_at` answers -1 off the island, `_wash_cell`
## answers -1 on water and on a stair, and the shader treats -1 as 「no 칸」 — so there is no second
## 「is the mouse on the ground」 test anywhere in this path.
## ⚠⚠ **THE CURSOR IS TRACKED WHETHER OR NOT ANYTHING IS ON SCREEN, and the shader is what gates it**
## (2026-08-28, the user: 「탭을 눌러서 떳을때만 오버가 되야 의미가 있을듯 한데?」). Skipping this
## write while the board is hidden would mean the mark appears one mouse-move LATE on the frame the
## key goes down — the cursor is already somewhere, and the 칸 it is on is already known.
func set_hover_tile(t: int) -> void:
	var c := -1
	if t >= 0 and t < _wash_cell.size():
		c = int(_wash_cell[t])
	if c == _hover_cell:
		return
	_hover_cell = c
	_tell_the_pads()


## ⚠⚠ **`set_summon_aim` AND `note_refusal` STOOD HERE AND BOTH ARE DELETED** (2026-08-28). The
## first carried the armed slot and the aimed tile in from the shell; the second stamped the mark
## that said the sim had REFUSED a drop. Both belonged to the summon gesture — see `game.gd`'s
## header — and `FxKind.REFUSE` went with them.

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

## ⚠⚠ **`_route_ahead` · `_tile_xy` · `_hull_rect` STOOD HERE AND ALL THREE ARE DELETED**
## (2026-08-29) with the boats. **What the route drawer knew**: `leg` was read off the SIM and the walk
## was never re-derived here, so the drawn line could not show a boat sailing water it had already
## crossed. A view that finds its own segment by re-walking the arc lengths is the same fact computed
## in two places, and the two drift the first time one of them changes.


## ⚠ **`_beast_rect` stood here and it is deleted** (2026-08-29) — a rectangle for the flat drawer,
## with no caller since the bodies became billboards.

## ⚠⚠ **`_hp_rects` STOOD HERE AND IS DELETED** (2026-08-28) with the bar it laid out.


## Which way a body is FACING, as a unit vector. **RIGHT when it has never moved**, because a zero
## vector normalised is zero, which would collapse a facing mark to a point.
##
## ⚠⚠ **IT TOOK AN `is_enemy` FLAG AND POINTED AT THE BODY'S TARGET** until 2026-08-29, and it takes the
## body's own KEY now (2026-08-30). **A body faces the way it last walked** — `_fx_step` records that as
## `head`, and it is the same value the gait phases on. ⚠ **Not the target, even though there are targets
## again**: a 늑대 that turns to face something it cannot reach reads as a body looking the wrong way,
## and the walk is what the picture is phased on everywhere else in this file.
func _facing_of(key: String) -> Vector2:
	var b: Dictionary = _body.get(key, {})
	var head: Vector2 = b.get("head", Vector2.RIGHT)
	return head if head.length_squared() > Rules.EPS else Vector2.RIGHT

## Ages both drawers by one frame and drops what has finished, then walks every body that can be on
## screen so the gait phase advances by DISTANCE rather than by time.
##
## Creating the per-body entries is done HERE and nowhere else. `_drain_events` deliberately refuses
## to create one: a body with no entry this frame is a body that is not on screen this frame, and
## flashing a corpse is the one thing item 3 must not do.
func _fx_step(delta: float) -> void:
	for key: String in _body:
		var b: Dictionary = _body[key]
		b["bite"] = maxf(0.0, float(b["bite"]) - delta)
		# ⚠ **Advanced unconditionally, and NOT inside the `moved` test below.** That test is the gait's
		# and it is right there; putting the legs under it is the rule 「움직이지 않는 몸은 애니메이션
		# 하지 않는다」, which is what left a body in melee frozen. This clock never stops.
		b["walk"] = float(b["walk"]) + delta

	if battle == null or army == null:
		return

	# ⚠ **Both sides into one list**, so the gait, the sway and the facing are one clock per body and
	# not two tables that have to be kept in step.
	var walkers := []
	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		walkers.append(["s%d" % i, battle.soldier_pos[i],
			Look.sprite_half_px(int(army.type_id[i]))])
	for raw_id in battle.living_enemy_ids():
		var e := int(raw_id)
		walkers.append(["e%d" % e, battle.enemy_pos[e],
			Look.sprite_half_px(int(battle.enemy_type[e]))])

	for raw_walker in walkers:
		var walker: Array = raw_walker
		var key: String = walker[0]
		var here: Vector2 = walker[1]
		if not _body.has(key):
			_body[key] = {
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

## ⚠ **`_drain_events` stood here and it is deleted** (2026-08-29) — see the effects block below.

## The one place a body's drawing offset is computed, so the body and its shadow are handed the same
## number. Split across call sites, one of them is eventually forgotten and the body walks out from
## under its own mark with the whole round green.
##
## ⚠⚠ **THE LUNGE AND THE KNOCK-BACK WERE THE OTHER TWO TERMS AND BOTH ARE DELETED** (2026-08-29) with
## the fight. **The idle sway is not one of them and does not go with them** — 「붙어서 가만히 있으면
## 재미가 죽는다」 — so what is left is the sway alone.
func _body_offset_of(key: String) -> Vector2:
	return _idle_offset(key)


## What a body does when it CANNOT move. See `Look.IDLE_AFTER_SEC` for why it exists at all.
##
## ⚠ **Phased off the key, so a queue does not sway in unison** — twelve bodies breathing on one
## beat read as a single object, which is worse than stillness. Deterministic, because a random
## wobble cannot be measured.
## ⚠ **Zero until `IDLE_AFTER_SEC` and it starts FROM zero**: the sway is a `sin` of elapsed
## stillness, so a body that has just stopped eases in rather than snapping sideways.
## ⚠⚠ **THE SIDEWAYS SWAY IS OFF** (2026-08-30, the user at the screen: 「why are they wobbling left and
## right so much? the swordsman and the wolf... it feels like they are shaking, this needs removing」,
## and 「the springy up-and-down is right, this is not」). **The bodies had just gone from 0.45 to 0.80
## scale and this amplitude is a ratio of the drawn half-width, so it grew by 78% with them.**
##
## ⚠ **What this costs, said out loud**: the gait phases on DISTANCE, so a body that cannot move now has
## NOTHING moving on it — which is exactly the state 「붙어서 가만히 있으면 재미가 죽는다」(*"존나
## 중요해"*, 2026-08-25) was written against. **The user's own words say the motion should be up and
## down**, and this offset cannot deliver that: it is added to a point on the GROUND plane, where
## `.y` is depth into the screen and not height. **A vertical bob is a change to the body's `foot`
## height in `_put_body`, and it is not this function.**
##
## ⚠⚠ **THE BODY IS KEPT AS A RECIPE AND NOT AS DEAD CODE.** A second function left sitting here was
## caught by `net_draw_leaf` the moment it was written, which is that net doing its job. What it did,
## so it can be rebuilt on the day the bob goes in:
## **zero until `still > IDLE_AFTER_SEC`; amplitude `IDLE_SWAY_RATIO * half`, the drawn half-width, so
## it survives the art changing; `sin(TAU * (still - IDLE_AFTER_SEC) / IDLE_PERIOD_SEC + phase)`, with
## `phase` taken off `absi(key.hash()) % 100` so a queue does not breathe in unison; and NOT routed
## through `fx_gain_of`, because borrowing the gait's slot would switch the two off together.**
## **The three constants are still in `look.gd` and nothing else reads them.**
func _idle_offset(_key: String) -> Vector2:
	return Vector2.ZERO

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
	# ⚠ **`Look.fx_gain_of(12)` was a factor here and the whole gain table is deleted** (2026-08-29)
	# with the twelve effects. The gait is not one of them — it is how a body WALKS.
	var s := Look.GAIT_SQUASH * sin(float(b["gait"]))
	if absf(s) <= 0.0:
		return Vector2.ONE
	var head: Vector2 = b["head"]
	if absf(head.x) >= absf(head.y):
		return Vector2(1.0 - s, 1.0 + s)
	return Vector2(1.0 + s, 1.0 - s)

# --- the effects: DELETED 2026-08-29 ---------------------------------------------------------------
## ⚠⚠ **THE TWELVE COMBAT EFFECTS AND THE WHOLE AIR LAYER ARE GONE** with the fight (2026-08-29):
## `FxKind` (shot · spark · burst · area · land), `_fx`, `_drain_events`, `_spark_points`, `_paint_fx`,
## `_paint_intent`, `_paint_transients`, `_put_halo`, `_halo_of`, `_body_anchor`, `_fx_point3` and
## every `_a_*` drawer with the `_air` node they filled.
##
## ⚠ **The GROUND buffer survives and so do its drawers.** A body's shadow goes into it, and a shadow
## is not an effect: it wears the terrain's own height at every vertex, so it climbs a slope with the
## body instead of hovering flat over one.
##
## ⚠⚠ **WHAT THE EFFECTS KNEW, and what a rebuilt set owes:**
##
##  · **Ageing runs BEFORE draining, every frame.** An effect born this frame is then at full
##    amplitude on the frame it was born — the flinch really does reach its full flinch once, and the
##    idle sway really does start from rest.
##  · **Everything geometric is frozen on the frame the fact happened**, because every effect outlives
##    the frame that produced it. A ring that re-reads a position follows a corpse.
##  · **The halo is the area a hit is SEEN on**, and it has to clear the picture on every side. At
##    1.35 × the SIM radius it was drawn 18.9 px out, **INSIDE a 49 px body** — the mark that said
##    「this one was just hit」 was underneath the thing it marked. It was sized off the DRAWN
##    half-width in the end.
##  · **The transient list is capped and the OLDEST goes.** The per-body drawer is bounded by the
##    number of bodies instead, which is why that rule cannot reach a flash or a lunge.
##  · **The intent lines are a TEXTURE over the fight, not readable lines** — alpha 0.12, at most
##    fourteen at once. Raising either number turns the island into a cage.
##  · **A body must not flinch away from a bullet that has not arrived**: the knock and the flash both
##    read only inside the window that opens when the tracer lands, never when it is fired.


# --- the ground layer ------------------------------------------------------------------------------
## ⚠⚠ **THIS SURVIVED THE FIGHT'S DELETION BECAUSE A BODY'S SHADOW IS DRAWN INTO IT** (2026-08-29).
## The AIR layer went with the effects — the tracer, the shards, the burst and the halo were all it
## ever carried, and all four belonged to a blow.
##
## **One buffer and one draw call, not a node per mark.** It is rebuilt every frame into a single
## `ImmediateMesh`, because a mark that lives a tenth of a second cannot afford a node.
##
## ⚠⚠ **A ground mark is CUT INTO PIECES and each piece laid at the height under it.** That is the
## whole reason this is not one quad per mark: a 6-tile line drawn as one quad crosses a ramp as a
## chord and half of it ends up underground.
##
## ⚠ **It does not write depth** (`DEPTH_DRAW_DISABLED`) but it IS tested against it: a cliff in front
## still hides what is behind it, and two overlapping marks do not punch holes in each other.

var _decal: MeshInstance3D = null
var _g_v := PackedVector3Array()
var _g_c := PackedColorArray()


## One unshaded, vertex-coloured, alpha-blended surface.
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


## ⚠ **An `ImmediateMesh` surface with zero vertices is an ERROR, not an empty picture.** A frame with
## no body on the island is the common case at the title, so the buffer is guarded.
func _fx_flush() -> void:
	if _decal == null:
		return
	var im: ImmediateMesh = _decal.mesh
	im.clear_surfaces()
	if _g_v.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _g_v.size():
		im.surface_set_color(_g_c[k])
		im.surface_add_vertex(_g_v[k])
	im.surface_end()


## The height of the ground under a point given in world px. **The one place a ground mark asks where
## the ground is**, so two marks cannot disagree about the hill they are both crossing.
func _ground_y_px(p: Vector2) -> float:
	var tx := int(floor(p.x / Look.TILE_PX))
	var ty := int(floor(p.y / Look.TILE_PX))
	return _ground_h(tx, ty) + Look.FX_GROUND_LIFT_TILES


func _g_tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	for p in [a, b, c]:
		_g_v.append(Vector3(p.x / Look.TILE_PX, _ground_y_px(p), p.y / Look.TILE_PX))
		_g_c.append(col)


## A disc lying on the ground. Every wedge samples its own height, so it follows whatever it is drawn
## across instead of hovering flat over one 조각.
func _g_disc(centre: Vector2, radius: float, col: Color) -> void:
	if radius <= Rules.EPS:
		return
	var segs := maxi(8, int(ceil(TAU * radius / Look.FX_GROUND_STEP_PX)))
	for k in segs:
		var a0 := TAU * float(k) / float(segs)
		var a1 := TAU * float(k + 1) / float(segs)
		_g_tri(centre, centre + Vector2(cos(a0), sin(a0)) * radius,
			centre + Vector2(cos(a1), sin(a1)) * radius, col)
