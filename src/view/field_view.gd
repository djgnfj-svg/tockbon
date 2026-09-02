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

## How many rungs `screen_to_terrain_px` cuts the view ray's descent into. **The height step is this
## divided into `Look.terrain_height_ceiling()`**, so at pitch 40 one rung slides the ground point about
## 5 world px along the ground.
##
## ⚠⚠ **SINCE 2026-09-02 THE RUNG IS NOT THE RESOLUTION A PRESS IS ANSWERED TO** (ticket 03-16). It
## was: the walk answered AT a rung, so every surface that sat between two rungs was answered 0.07 조각
## up the screen, and a 2층 조각's far edge was skipped clean. **Now every 조각 the ray crosses between
## two rungs is tested against the ray's own height where it enters and leaves it**, so the answer is
## exact at any count and no ridge can fall between rungs. **48 stays by the ticket's decision** — the
## count bounds how the work is cut, and it does not move the answer.
const TERRAIN_PICK_STEPS := 48
## How far into a 조각 the ground point is set when the ray meets that 조각's FACE rather than its top,
## as a fraction of the way from the entry point to the 조각's centre. The entry point sits exactly on
## the edge shared with the 조각 in front, and `world_to_tile` floors — so a face hit answered on the edge
## itself would name whichever of the two 조각 the last bit of the float fell into. **The face belongs to
## the taller 조각**, which is what the player is looking at, and this nudge is what makes the floor say
## so. Below the 0.02 조각 a net can tell from an edge.
const FACE_HIT_INSET := 0.001

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

## **How many degrees of turn are still OWED**, signed. Q adds −90, E adds +90, and `_process` pays it
## off a frame's worth at a time through `turn_by`.
##
## ⚠⚠ **REMAINING, AND NEVER A TARGET ANGLE.** `turn_by` wraps with `fmod(yaw + deg, 360.0)` and a
## stored target does not wrap with it: **from yaw 270 an E press targets 360**, the step that would
## reach it comes back through `fmod` as 0, the remainder becomes 360 again, and **the board spins for
## ever.** Simulated exactly before it was written: 0, 90 and 180 settle in 14 frames and 270 is still
## turning at frame 2000. ⚠ Wrapping the target instead is not the fix either — from 270 with a target
## of 0 the remainder is −270 and the board sweeps three quarters the wrong way.
## ⇒ **Nothing here is ever compared against an absolute angle**, so nothing can cross 360. Two
## presses inside one sweep add up, Q then E cancels, and the last step is the exact remainder, so the
## yaw lands ON the notch rather than near it.
##
## ⚠⚠ **IT IS ALSO WHAT KEEPS THE INSTRUMENTS WORKING.** Four live tools call `turn_by` directly on a
## `FieldView` that is inside a real tree with `_process` running — two of them turn 45° on purpose to
## photograph a seam measured at that angle. **A sweep that pulled the yaw toward a target would drag
## every one of them back at 409°/s.** A direct `turn_by` leaves this at zero, the sweep stays idle,
## and nothing that is not a key press is touched.
var _yaw_remaining := 0.0

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
var _foot_body: Dictionary = _measure_body_feet(_tex_facing, _tex_anim)
## **The first and last texel column of each body picture that holds any opaque pixel**, `(lo, hi)`
## inclusive, keyed by the picture — the INK's own extent across its canvas, standing pictures and
## every strip frame alike. See `_measure_ink_cols`.
##
## ⚠⚠ **ONE SCAN, TWO READERS** (2026-09-02, ticket 03-16). `_ink_frac` below divides the canvas back
## out of a body's drawn width, and `body_at_px` answers a press by the ink's drawn edges — **a press
## rectangle on the CANVAS was 2.2 times the man**: a 72-texel frame carries 33 texels of 검사, and a
## press 8 px beside him on empty ground picked him (`verify-look`). Both facts are the same columns,
## so both read this one dictionary rather than each scanning alpha on its own.
var _ink_cols: Dictionary = _measure_ink_cols(_tex_facing, _tex_anim)
## **How much of its own canvas each row's ANIMAL actually fills across**, read off the standing
## pictures' columns above. **This is what divides the canvas back out of a body's drawn size**, so a
## strip that needs a wider frame stops changing how big the body reads. See `Look.beast_draw_scale`.
var _ink_frac: Array = _measure_body_ink(_tex_facing, _ink_cols)

## **The two drawn things the marks wear, and the font the number is set in.** Loaded once, beside
## the body pictures, for the same reason: a `load()` in a drawer is a disk read in a frame.
var _tex_tooth: Texture2D = load(Look.FX_TOOTH) as Texture2D
var _tex_slash: Texture2D = load(Look.FX_SLASH) as Texture2D
var _font_digits: Font = load(Look.FX_DIGIT_FONT) as Font

## **The air layer, rebuilt.** ⚠⚠ **IT WAS DELETED WHOLE ON 2026-08-29** with the twelve effects, and
## nothing has drawn above the ground since — the ground buffer survived only because a body's shadow
## goes into it. **These two pools are the smallest thing that brings it back**: billboards for the
## shards and the arc, `Label3D` for the number.
## ⚠ **Two pools and not one**, because a number is text and a shard is a texture, and one node type
## cannot be both. They are opened and closed together, like the bodies and their outlines.
var _marks: Array[Sprite3D] = []
var _marks_used := 0
var _labels: Array[Label3D] = []
var _labels_used := 0
## **Everything currently in the air**, aged every frame and dropped when its clock runs out.
## ⚠⚠ **Geometry is FROZEN on the frame the blow happened** — a mark carries its own position and
## velocity and never re-reads a body. **A mark that re-read a position would follow a corpse**, which
## is rule 2 of the five the deleted set paid for.
var _live: Array = []

## **The answer `_aim_of` gives for a body aiming at nothing.** A sentinel and not a `null`, so the
## row it sits in stays one flat array of values rather than a array of maybe-Vector2.
const OFFMAP_AIM := Vector2(-9999.0, -9999.0)
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
## **Which pooled sprite each living, ashore 검사 is wearing this frame** — soldier id to index into
## `_sprites`. Rebuilt by `_paint_bodies` every frame and read by `body_at_px`, which is how a press
## finds a body by where it is DRAWN (2026-09-02, the user: 「몸은 화면에서 잡자」 — *"let us pick the
## body on the glass"*).
##
## ⚠⚠ **THE INDEX IS `_sprites_used - 1` RIGHT AFTER `_put_walker`, WHICH IS THE SAME CONVENTION
## `_put_outline` STANDS ON.** A walker takes exactly one sprite from the pool, and the bar it wears
## comes from `_bars`, not from here — so the last sprite handed out IS the body's. **Recorded in the
## one loop that draws the 검사** rather than derived here from `soldier_pos`, because a body mid-sway or
## mid-lunge is picked where it is drawn, and only the paint knows where that is.
## ⚠ **짐승, riders and a body still falling are not in here** — none of them is pickable, as before.
var _sprite_of_soldier := {}
## **Where each body was DRAWN last frame, in `soldier_pos` units** — body key (`s%d` · `e%d`) to
## `Vector2`. Ticket 03-17's one piece of view state: a body coming to rest slides from where the sim
## left it onto its seat at `Look.SEAT_GLIDE_TILES_PER_S`, and this is the point it slides from.
##
## ⚠⚠ **KEYED ON THE BODY'S STRING KEY AND NOT ON THE POOL SLOT** (the plan's amendment 2). `_sprite()`
## hands out pool slots by draw order and every index shifts after a death, so a glide kept in the
## sprite's own position would make a body inherit a stranger's in-flight point.
## ⚠⚠ **A BODY'S FIRST FRAME IN THE POOL DRAWS AT ITS STAND POINT, NO GLIDE** — there is no entry to
## glide from — so bodies placed by hand in a net read their seat immediately, and the slide only plays
## on a walk → rest transition the view has watched. **A key is dropped the frame its body leaves the
## pool**, so a body that dies and stands again does not slide in from where it fell.
## ⚠ **Walking bodies track the sim plus their seat offset** (`_seat_offset`) and only overwrite
## their entry; a falling body is drawn at its entry and never moves it.
## ⚠⚠ **`_advance_seat_glide` IS THE ONLY WRITER AND IT RUNS BEFORE ANYTHING IS PAINTED** (the 03-17
## bounce). It stood inside `_put_walker` for one round, and the 이동선 — painted BEFORE the bodies so it
## lies under their shadows — read the frame's target instead: on the first resting frame the line's
## start led the drawn body by the whole glide gap, up to 1.65 조각, closing over half a second. The
## table is rebuilt whole every frame from the sim's lists, so every reader in the frame — the line, the
## body, the shadow, the bar — reads one point, and a body that left the pool is simply not in it.
var _seat_glide := {}
## **Where each living body is drawn RELATIVE to the sim's own point** — body key → `Vector2`, in
## `soldier_pos` units, the second half of the glide and rebuilt in the same pass. At rest it is simply
## `_seat_glide[key] − at`: the seat's offset from the 조각 centre once the glide has settled, and the
## in-flight gap before. **Walking, it is FROZEN at the value it had on the last resting frame**, and the
## body is drawn at `at + offset` for the whole walk.
##
## ⚠⚠ **WITHOUT THIS THE FIRST WALKING FRAME SNAPPED THE BODY ONTO THE 조각 CENTRE** (2026-09-02, the
## user: 「그냥 딱 이동하게 하면 새로 생성되는 느낌으로 출발함 그냥 그자리에서 병사가 이동하는게 아니라」
## — *"on a move order they depart as if newly spawned, not the soldier walking from where he stood"*).
## A body at rest is drawn on its seat, 0.53–0.71 조각 from the 조각 centre the sim has it on; the walk's
## first sub-step moved the sim a tenth of a 조각 and the drawn point the whole seat gap, in a direction
## that had nothing to do with the walk. **And every body sharing a 조각 was drawn on the one sim point
## while it walked** (「캐릭터가 움직일때 겹친다」 — *"the characters overlap when moving"*): three bodies
## on one 조각 spread onto three seats at rest and collapsed onto one point the moment they moved.
## Carrying the offset keeps them apart by exactly what kept them apart at rest.
## ⚠ **Bounded by `Look.SEAT_OFFSET_MAX_TILES`**, and **a body that never rested has none** — it is
## drawn on the sim's point, which is where a wolf walking off its boat has always been drawn.
## ⚠ **The sim never reads this.** Reservation, capacity and arrival are all on the sim's own point;
## this is the picture's memory of where the body was standing, and nothing else.
var _seat_offset := {}
## **기법 17's black copies, one per body, in their own pool.** ⚠⚠ **A parallel pool and not a child
## node**, because the body sprites are recycled by index across frames: a child would be carried to
## whichever body reused that slot, and the outline would be right by accident. **Index `i` of this
## pool belongs to index `i` of `_sprites`, always**, and `_hide_unused` closes both together.
var _outlines: Array[Sprite3D] = []
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
	# The selection box's own mesh — see `set_box`. Built once like the decal; what changes is the
	# geometry inside it, and only when the rect or the camera does.
	_box_mesh = _fx_layer(Look.SELECTION_BOX_RENDER_PRIORITY)

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
## **Whether the 3D board is on screen at all.**
##
## ⚠⚠ **IT EXISTS BECAUSE `visible` ON THIS NODE DOES NOT REACH THE BOARD.** This is a `Node2D` and the
## island hangs off it as a `Node3D`; the two use different visibility systems, so hiding the parent
## leaves the whole island drawn with every check about it green. **The shell needs one call to clear
## the glass** — going back to the title is the first thing that ever needed it (2026-09-01).
## ⚠ **A method and not the shell reaching for `_world`.** `src/shell/` wires `sim` to `view`; it does
## not know this file builds its world out of one node, and the day it is two this stays one call.
func show_board(on: bool) -> void:
	if _world != null:
		_world.visible = on


func setup(battle: Battle, army: Army, rows: Array) -> void:
	self.battle = battle
	self.army = army
	self.rows = rows
	# **Both drawers are emptied here.** Without it island 2 opens with island 1's explosions still in
	# flight over bodies that no longer exist, and every id in them means a different unit now.
	_fx = []
	# ⚠⚠ **THE AIR IS EMPTIED WHEN A BOARD LOADS, AND `_body` DELIBERATELY IS NOT.** A mark carries its
	# own frozen position, so one left over from the last island would hang in the air over this one at
	# a place nothing happened. **The body rows survive because a 검사 carries across islands.**
	_live = []
	_body = {}
	# ⚠ **The glide forgets every body too.** It holds drawn POINTS on the last island's board, and a
	# 검사 carried across would otherwise slide in from a place on a different island.
	_seat_glide = {}
	_seat_offset = {}
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
	# ⚠ **A sweep in flight does not survive an island opening.** Without this, the quarter still owed
	# when the last board closed would go on being paid onto the new one, off the angle `setup` just
	# said the board opens at.
	_yaw_remaining = 0.0
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
	# A fresh island opens with no box — the shell clears it on every release and dropped gesture too,
	# and both writers are accepted for the reason `game._drop_the_gestures` gives.
	_box = Rect2()
	_rebuild_box()


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
	_step_marks(delta)
	# The sea's own clock — the bob and the roll, and nothing else, read it. See `_sea_clock`.
	_sea_clock += delta
	# ⚠ **After the tick and not before it.** Every remembered point is stamped with `_sea_clock`,
	# and a stamp taken before the tick is a frame behind the hull the same frame is about to draw.
	_paint_wake()
	# ⚠ **Above `_place_camera` and not below it.** The sweep writes `cam_yaw_deg`, and the camera is
	# placed from that field — a frame that placed first would draw every sweep one frame behind.
	_sweep_the_yaw(delta)
	_place_camera()
	# ⚠ **After the sweep and the placement**: the box is laid on the ground under a screen rect, so a
	# turn while the button is held (Q/E stay live during a press) moves the ground under it, and the
	# rebuild has to read the yaw this frame draws with — see `set_box`.
	# ⚠⚠ **THIS IS THE ONLY PLACE THE BOX IS REBUILT WHILE THE GAME RUNS** — once a frame at most,
	# whether the shell handed over one rect or twelve since the last one. See `set_box`.
	if _box_dirty or (_box.size != Vector2.ZERO and _box_cam != _box_cam_key()):
		_rebuild_box()
	# ⚠ **The buffer is opened BEFORE the bodies and flushed after them.** A body's shadow is painted
	# from inside `_paint_bodies` — it is a per-body fact, and that is the one loop with a body's
	# centre and radius in hand at the same time.
	_fx_begin()
	# ⚠ **The glide steps BEFORE the line and the bodies**, so both read the same drawn point this
	# frame — see `_seat_glide`.
	_advance_seat_glide(delta)
	# ⚠ **Before the bodies and that is the stacking order.** The buffer is one surface drawn in the
	# order it was filled, so a route laid down first passes UNDER the shadows of the bodies walking
	# it — which is the way round that reads as a line on the ground rather than over the feet.
	_paint_move_lines()
	_paint_bodies()
	_paint_marks()
	_fx_flush()
	# ⚠ **Outside the buffer.** A picture prop writes nothing into the fx buffers — it is a standing
	# node, not a per-frame draw — and the only reason it is touched at all is the camera's pitch.
	# ⚠ **The wind's clock is aged FIRST.** The cards read it as a uniform, so painting them before
	# it ticks hands every card the frame before the one the meshes are already standing in.
	_paint_sway(delta)
	_paint_flat_props()


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
##
## ⚠⚠ **IT ANSWERED AT A RUNG UNTIL 2026-09-02, AND EVERY 2층 PRESS WAS 0.071 조각 UP THE SCREEN**
## (ticket 03-16, measured against the engine's own ray). The rung is `5.02 / 48 = 0.1046` of height;
## the 1층 top at 0.21 sits 0.001 above a rung and the 2층 top at 1.21 sits 0.0596 above one, so the
## first rung at or below the 2층 top was already 2.84 world px past it along the ground. **Two things
## came of that**: in the far 0.071 조각 of every 2층 조각 the neighbour answered, and **at a 2층 덩어리's
## far cliff edge the ray stepped clean over the top and fell to the 1층 land 1.19 조각 behind it** —
## the 「ledge skip」 the ticket named as a suspect, and it was real.
## ⇒ **Between two consecutive rungs, every 조각 the ground segment crosses is walked in order, and
## for each the ray's height where it ENTERS and where it LEAVES that 조각 is compared with the 조각's
## own top.** Top between the two: the ray met that top, and the answer is the ray at exactly that
## height — over that 조각 by construction. Top above the entry height: the ray met that 조각's FACE, and
## the answer is the entry point set a hair inside it (`FACE_HIT_INSET`). Otherwise the ray cleared it
## and the walk goes on. **The rung count no longer moves the answer** — see `TERRAIN_PICK_STEPS`.
##
## ⚠⚠ **TWO WORDINGS THAT WERE TRIED ON PAPER AND ARE WRONG** (`adversary`, 2026-09-02), so nobody
## re-tries them: 「snap the rung's point to the found 조각's top」 moves the point 0.071 조각 further
## along the ground, so a press inside the last 0.071 of a 2층 조각 snaps past its far edge onto the
## hidden 1층 behind and answers height 1.21 over a 0.21 surface; 「test only the 조각 newly entered
## between the two rungs」 reads the low land at a far cliff edge and the skip survives. **The 조각 that
## owns the top is the one the ray was over at the HIGHER rung, and during the 0.22 s sweep the segment
## can cross a corner** — so every crossed 조각 is walked, not one.
##
## ⚠ **Off the board there is no surface**, so an off-grid 조각 is stepped over rather than read as a
## top at height 0 — that is the same answer the rung walk gave, whose rungs never reached 0.
##
## `steps` is how many rungs the descent is cut into — `TERRAIN_PICK_STEPS` for a press, and **1 for
## the selection box's hits** (`_box_hit`), which is the same walk over the same 조각 in one segment
## instead of 48 and costs a sixteenth of it. ⚠ Not a second, cheaper answer: the rung count bounds
## how the work is cut and does not move the answer, and `_box_hit` carries the measurement.
func screen_to_terrain_px(at: Vector2, steps: int = TERRAIN_PICK_STEPS) -> Vector2:
	var ceiling := Look.terrain_height_ceiling()
	var step := ceiling / float(steps)
	var h_hi := ceiling
	var w_hi := screen_to_world_px(at, h_hi)
	for _i in steps:
		var h_lo := h_hi - step
		var w_lo := screen_to_world_px(at, h_lo)
		var met := _ground_met(w_hi, h_hi, w_lo, h_lo)
		if met.is_finite():
			return met
		h_hi = h_lo
		w_hi = w_lo
	# Under every hill on the board: the ray reached sea level without meeting anything, so the sea is
	# what it hit. **Not `0.0`** — the water is a surface at `TERRAIN_H_WATER` like any other, and
	# answering on the plane below it would put a press on open sea a fifth of a tile off.
	return screen_to_world_px(at, Look.TERRAIN_H_WATER)


## **Where the ray's ground segment from `w_hi` (at height `h_hi`) to `w_lo` (at `h_lo`) first meets
## the landscape, in world px — or `Vector2.INF` when it clears every 조각 it crosses.** The half of
## `screen_to_terrain_px` that walks 조각; see its header for what it replaced and why.
##
## The 조각 are walked in the order the ray crosses them, and the ray's height is linear along the
## segment — `screen_to_world_px` is linear in its height — so the height at any point of it is a lerp
## between the two ends. ⚠ **A 조각 the segment only grazes at a corner (a zero-length crossing) is
## skipped**: there is no length of ray over it for a top to lie under.
func _ground_met(w_hi: Vector2, h_hi: float, w_lo: Vector2, h_lo: float) -> Vector2:
	if battle == null or battle.grid == null:
		return Vector2.INF
	var p0 := w_hi / Look.TILE_PX
	var d := (w_lo - w_hi) / Look.TILE_PX
	var tx := int(floor(p0.x))
	var ty := int(floor(p0.y))
	var step_x := 1 if d.x > 0.0 else -1
	var step_y := 1 if d.y > 0.0 else -1
	# How far along the segment (0..1) the next x line and the next y line are crossed, and how much
	# further each whole 조각 costs. An axis the segment does not move along is never crossed.
	var t_dx := INF if d.x == 0.0 else absf(1.0 / d.x)
	var t_dy := INF if d.y == 0.0 else absf(1.0 / d.y)
	var t_x := INF if d.x == 0.0 else ((float(tx) + (1.0 if d.x > 0.0 else 0.0)) - p0.x) / d.x
	var t_y := INF if d.y == 0.0 else ((float(ty) + (1.0 if d.y > 0.0 else 0.0)) - p0.y) / d.y
	var t_in := 0.0
	while t_in < 1.0:
		var t_out := minf(minf(t_x, t_y), 1.0)
		var on_board := tx >= 0 and ty >= 0 and tx < battle.grid.w and ty < battle.grid.h
		if on_board and t_out > t_in:
			var top := _ground_h(tx, ty)
			var h_in := lerpf(h_hi, h_lo, t_in)
			if top >= h_in:
				# The ray is already under this 조각's top as it arrives: it met the FACE, and the face is
				# this 조각's — see `FACE_HIT_INSET` for why the point is pushed off the shared edge.
				var p_in := p0 + d * t_in
				var centre := Vector2(float(tx) + 0.5, float(ty) + 0.5)
				return (p_in + (centre - p_in) * FACE_HIT_INSET) * Look.TILE_PX
			if top >= lerpf(h_hi, h_lo, t_out):
				# The top lies between the entry and exit heights: the ray met it. The ray at exactly the
				# top's height is over this 조각 by construction.
				return (p0 + d * ((h_hi - top) / (h_hi - h_lo))) * Look.TILE_PX
		if t_x < t_y:
			tx += step_x
			t_x += t_dx
		else:
			ty += step_y
			t_y += t_dy
		t_in = t_out
	return Vector2.INF


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


## **Which 검사 is drawn under the screen point `at`, or -1** (2026-09-02, the user: 「몸은 화면에서
## 잡자」 — *"let us pick the body on the glass"*). The answer is the soldier id whose drawn picture —
## foot to top, the sprite's own width — contains the press; **when two pictures contain it, the one
## whose drawn foot is nearest the press**, which is the front-most body and the one the eye picks.
##
## ⚠⚠ **THE PRESS USED TO BE ANSWERED ON THE GROUND AND IT MISSED AT TWO OF THE FOUR YAWS** (ticket
## 03-16, measured 2026-09-02). The shell turned the press into a ground point and `Hand.body_at`
## measured its distance to `soldier_pos` — but a body is drawn standing UP from its feet, so a press on
## the chest lands on the ground `h / tan(pitch)` 조각 BEHIND the feet, and screen-up is a world direction
## that turns with the yaw: at 0° and 270° it cancelled a half-조각 origin error in that conversion, at
## 90° and 180° it added to it, and chest and head presses picked nobody. At pitch 20° the factor is
## 2.75 and no radius on the ground reaches a head at any yaw. **Both `Hand.body_at` and the constant
## it read are deleted**; the question 「which body is under the finger」 lives here now.
##
## ⚠⚠ **IT READS THE POOLED SPRITES THE VIEW ITSELF PLACED** — position, scale, texture, visible, the
## agreed measuring surface in `GLOSSARY.md` — and projects them through `world_to_screen_px`, so the
## rectangle IS the picture: the pitch, the yaw, the zoom, the seat on the 칸's lattice, the idle sway
## and the `_pitch_stretch` are all already inside the sprite's own fields. **No new constant** — the
## picture's size is the pick area, and 03-17 moving a body onto its lattice seat moved the pick with
## the drawing by construction.
##
## ⚠⚠ **THE WIDTH IS THE INK'S AND NOT THE CANVAS'S** (2026-09-02, the bounce). For one round the
## rectangle was the whole `Sprite3D` quad — texture width times scale — and that quad is 2.2 times the
## man: a 72-texel frame with 33 texels of 검사 in it, the rest transparent margin. `verify-look` pressed
## empty ground 8 px beside a body and picked him. **The drawn edges are the first and last opaque
## column of the texture the sprite wears** (`_ink_cols`, the same scan that sizes the body), placed off
## the canvas centre in texels — a billboard's own x is the camera's right, so a texel to the right of
## centre is a texel to the right on the glass. The height stays the canvas's: the frames fill it, and
## the rows under the feet are already folded into the sprite's position by `_put_body`.
## ⚠ **Sprite px per 조각 across is read off `_visible_ground_px`**, the one place the zoom becomes a
## ground span, rather than written as `zoom * TILE_PX` a second time here.
## ⚠ **The foot and the top go through `world_to_screen_px` at their own heights**, so the vertical
## extent is the same foreshortening the camera applies to the upright card; the width is the card's
## world width, which an orthographic camera does not foreshorten.
## ⚠ Only living, ashore 검사 are in `_sprite_of_soldier`; 짐승 are not pickable, as before.
## ⚠ **The rectangle itself is `_drawn_rect_of` since 03-12**, so the box (`bodies_in_rect_px`) and the
## press read one arithmetic and cannot disagree about where a body is drawn.
func body_at_px(at: Vector2) -> int:
	var who := -1
	var best := INF
	var px_per_tile := Look.VIEWPORT_W_PX / _visible_ground_px().x * Look.TILE_PX
	for raw_id in _sprite_of_soldier:
		var k := int(_sprite_of_soldier[raw_id])
		if k < 0 or k >= _sprites.size():
			continue
		var s := _sprites[k]
		var drawn := _drawn_rect_of(s, px_per_tile)
		if drawn.size == Vector2.ZERO or not drawn.has_point(at):
			continue
		var d := at.distance_to(_sprite_edge_px(s, -1.0))
		if d < best:
			best = d
			who = int(raw_id)
	return who


## **The rectangle 검사 `sid` is drawn in on the glass, or an empty `Rect2` when no pooled sprite is his
## this frame** (ticket 03-12). Public so a net can aim a box at a body's own picture.
func drawn_rect_px(sid: int) -> Rect2:
	if not _sprite_of_soldier.has(sid):
		return Rect2()
	var k := int(_sprite_of_soldier[sid])
	if k < 0 or k >= _sprites.size():
		return Rect2()
	var px_per_tile := Look.VIEWPORT_W_PX / _visible_ground_px().x * Look.TILE_PX
	return _drawn_rect_of(_sprites[k], px_per_tile)


## **Every 검사 whose drawn picture overlaps `rect`, ascending by id** (ticket 03-12, 2026-09-02, the
## user: *"Drag to select and move them. There is no other method as good as that one."*). The
## selection box's whole hit test.
##
## ⚠ **`Rect2.intersects` and not containment**: a box that clips a body's edge catches him, which is
## what the user tested in the lab. A purely horizontal 6 px drag is a rect of zero height, and
## `intersects` still answers true when that row cuts a picture — the lab's `_bodies_in_rect` used the
## same call.
## ⚠ **Player-only by construction**: only ashore 검사 are in `_sprite_of_soldier`, so a box drawn
## around a 늑대 and a 검사 answers the 검사 alone with no filter written here.
func bodies_in_rect_px(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var px_per_tile := Look.VIEWPORT_W_PX / _visible_ground_px().x * Look.TILE_PX
	for raw_id in _sprite_of_soldier:
		var k := int(_sprite_of_soldier[raw_id])
		if k < 0 or k >= _sprites.size():
			continue
		var drawn := _drawn_rect_of(_sprites[k], px_per_tile)
		if drawn.size == Vector2.ZERO:
			continue
		if drawn.intersects(rect):
			out.append(int(raw_id))
	out.sort()
	return out


## **The screen rectangle one pooled body sprite is drawn in** — foot to top, the ink's own width — or
## an empty `Rect2` for a sprite that is hidden or wears nothing. The body of `body_at_px`'s loop until
## 03-12 cut it out so the box could read the same arithmetic; **the paragraphs on `body_at_px` are its
## explanation**, and nothing about the numbers moved.
##
## ⚠ `px_per_tile` is passed in rather than read here, because every caller loops the pool and
## `_visible_ground_px` is one answer per frame, not one per body.
func _drawn_rect_of(s: Sprite3D, px_per_tile: float) -> Rect2:
	if not s.visible or s.texture == null:
		return Rect2()
	var foot := _sprite_edge_px(s, -1.0)
	var top := _sprite_edge_px(s, 1.0)
	# One texel of this sprite on the glass, and where its ink starts and ends measured from the
	# canvas centre the sprite is placed by. A picture never scanned spans its whole canvas.
	var texel_px := s.scale.x * s.pixel_size * px_per_tile
	var half_w := float(s.texture.get_width()) * 0.5
	var span: Vector2i = _ink_cols.get(s.texture, Vector2i(0, s.texture.get_width() - 1))
	var left := foot.x + (float(span.x) - half_w) * texel_px
	var right := foot.x + (float(span.y) + 1.0 - half_w) * texel_px
	return Rect2(left, top.y, right - left, foot.y - top.y)


## **Where a pooled sprite's canvas centre column meets its bottom edge (`side` -1, the drawn foot) or
## its top edge (`side` +1) on the glass.** The one owner of 「the foot」: `_drawn_rect_of` builds its
## rectangle from both edges, and `body_at_px` breaks a tie between two overlapping pictures on the
## nearer foot — written twice, the tie-break and the rectangle would drift apart by a texel.
func _sprite_edge_px(s: Sprite3D, side: float) -> Vector2:
	var xz := Vector2(s.position.x, s.position.z) * Look.TILE_PX
	var half_tall := float(s.texture.get_height()) * s.scale.y * s.pixel_size * 0.5
	return world_to_screen_px(xz, s.position.y + side * half_tall)


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
##
## ⚠⚠ **THIS USED TO TELL THE 판 AND IT DOES NOT ANY MORE** (2026-09-01). The zoom drove the merge
## on a ramp, so the marks were 조각 up close and 칸 far out; **the merge is pinned at 1 now and the
## camera has nothing left to say to them** — see `_adopt_the_pads`. Nothing else on that call was
## ever a function of the zoom.
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


## **Asks for a notch of turn and returns immediately** — the board arrives over the next few frames.
## Q hands this −`Look.CAM_YAW_SNAP_DEG` and E hands it +.
##
## ⚠⚠ **THIS IS THE ONLY WRITER OF `_yaw_remaining` OUTSIDE THE SWEEP ITSELF**, and that is what keeps
## a direct `turn_by` — which four instruments make on a live tree — from being dragged anywhere.
## ⚠ **It ADDS rather than replacing**, so two quick presses turn a half and neither is eaten mid-way;
## Q then E cancels to nothing rather than leaving the board off a notch.
func turn_notch(deg: float) -> void:
	_yaw_remaining += deg


## **Pays off one frame's share of the turn that is owed** (2026-09-02, the user choosing the sweep
## over an instant snap: 「즉시 돌 거 같아. 도는 것이 보여」).
##
## ⚠ **The step is scaled by the frame's own delta**, so `_process(0.0)` moves nothing — which is what
## lets every net that hand-sets `cam_yaw_deg` and then calls `_process` keep its number.
## ⚠ **The last step is the exact remainder**, so the yaw lands on the notch instead of near it and the
## next press starts from a whole quarter.
func _sweep_the_yaw(delta: float) -> void:
	if _yaw_remaining == 0.0:
		return
	# ⚠ **A sweep of 0.0 s is the INSTANT turn**, which is the other half of the choice the user made
	# by looking — the whole remainder is paid on the first frame. Written as a branch rather than as a
	# division, because dividing by the duration is `inf` and `inf * 0.0` is `nan`.
	var share := absf(_yaw_remaining)
	if Look.CAM_YAW_SWEEP_SEC > 0.0:
		share = Look.CAM_YAW_SNAP_DEG / Look.CAM_YAW_SWEEP_SEC * delta
	var step := clampf(_yaw_remaining, -share, share)
	_yaw_remaining -= step
	turn_by(step)


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
## ⚠ **It is not symmetric and cannot be absorbed into the yaw**: `cam_yaw_deg` is the player's, the
## turn keys write it — the right-button drag did from 2026-08-26 until it was deleted on 2026-09-02,
## and Q and E carry it again — and 0 has to be the view the flat board had.
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
## ⚠⚠ **The other half of the scatter, and it is PICTURES** (2026-08-31, the user: 「the tree is 2D,
## the bush is 2D too, and the stone, the iron ore and the buildings are 3D」). One PNG per kind,
## named exactly as the kind is named in `island.json`. **A kind found in `props.glb` never reaches
## here** — the mesh wins, so moving a tree from 3D to 2D is deleting it from the `.blend`.
const FLAT_PROP_DIR := "res://assets/props/flat/"
## **The card's own shader** — it turns itself, bends itself in the wind and draws its own ink.
const PROP_CARD_SHADER := "res://src/view/prop_card.gdshader"
## **The beasts' hull, as one object Blender made.** ⚠ **Loaded, never built** (`CLAUDE.md`: what the
## player looks at is made in a tool). It arrives at its authored size and nothing scales it — 티켓 47
## says the hull, the sail and their proportions are judged on the game screen, after it is in.
## ⚠ **It sits here and not in `look.gd` because it is a scene path**, and the three above it already
## decided where those live. Every number the hull is DRAWN with is still `look.gd`'s.
const BOAT_SCENE := "res://assets/props/boat_small.glb"

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

## **The reach mask the shader reads, one texel per 조각**, and the image behind it. ⚠ **Both are
## rebuilt when the BOARD changes size and only then** — a pick rewrites the pixels of the image that
## is already there, because reallocating a texture on every click is a stall the player feels.
var _reach_img: Image = null
var _reach_tex: ImageTexture = null

## Whether the hand is holding anybody. **Drives the shader's `show_reach`**, which is what took over
## from TAB as the reason a 판 is visible.
var _reach_on := false

## **Which bodies the hand is holding**, as a set of soldier ids. ⚠ **A set and not one id**, for the
## same reason `Hand.ids` is a list: the day a 부대 is picked, nine bodies wear the rim and nothing here
## changes. Written by the shell through `set_picked`.
var _picked := {}

## The rim sprites, pooled the way the bodies are. ⚠ **Their own pool and not the body pool**, because
## each one carries a `ShaderMaterial` with that body's picture in it — handing one back out as a plain
## body would put a white silhouette where a soldier should be.
## ⚠⚠ **THIS WAS ALSO CALLED `_outlines` UNTIL 2026-09-01**, on a branch where 기법 17's black copies did
## not exist. Both landed the same day and the name could only mean one of them; **the black copy kept
## `_outlines` because every body has one, and the rim is a `_rim` because only the picked body has one.**
var _rims: Array[Sprite3D] = []
var _rims_used := 0
const RIM_SHADER := "res://src/view/body_outline.gdshader"

## **The health bars, one pair of sprites each — the frame and the fill that is cropped inside it.**
##
## ⚠⚠ **A PARALLEL POOL AND NOT A CHILD NODE**, exactly the reason `_outlines` is one: the entries are
## recycled by index across frames, so a fill parented to a frame would be carried to whichever bar
## reused that slot. **Index `i` of `_bar_fills` belongs to index `i` of `_bars`, always**, and
## `_hide_unused` closes both by the same count.
## ⚠ **Its own count and not the body index.** Every body wears a black copy, so that pool is closed by
## `_sprites_used`; only a HURT body wears a bar, and the 성채 wears one while being no body at all.
## ⚠⚠ **THE OLD BAR WAS DELETED 2026-08-28 AND THIS IS NOT IT COMING BACK.** That one was two
## rectangles `_put_hp` laid out from `_hp_rects`; this one is two pictures pulled in `tools/pixel/`.
var _bars: Array[Sprite3D] = []
var _bar_fills: Array[Sprite3D] = []
var _bars_used := 0
## ⚠ **Loaded at declaration, the same way `_tex_tooth` is** — a picture that never changes has no
## reason to wait for `_build_world`, and loading it there would be a second place a bar can fail.
var _tex_bar_frame: Texture2D = load(Look.HP_BAR_FRAME) as Texture2D
var _tex_bar_fill: Texture2D = load(Look.HP_BAR_FILL) as Texture2D

## **Where the 성채's roof is, in world units**, and whether one was ever put on screen. Written by
## `_rebuild_buildings` from the very numbers that placed the mesh, so the bar cannot end up over a
## roof the building is not standing at.
## ⚠⚠ **NOT DERIVED FROM `keep_tiles`.** The sim's tiles say where the keep IS; how tall it is drawn
## is `BUILD_SCALE` times a mesh nobody here authored, and a second guess at it is a bar floating over
## the ridge or buried in it.
var _keep_roof := Vector3.ZERO
var _keep_roof_known := false


## **The 이동선 waiting to be drawn**, one `PackedInt32Array` of 조각 per picked body. Written by the
## shell on hover, read by `_paint_move_lines` inside the fx pass, and cleared by handing back an
## empty array. ⚠ **It holds 조각 and not points** — the height each piece is laid at is decided at
## draw time by `_ground_y_px`, exactly as every other ground mark is.
var _move_lines: Array = []

## Whose line each entry of `_move_lines` is, in the same order. **Empty is allowed** and means no
## seat — a line leaving the middle of a 조각 rather than a body's feet.
var _move_ids := PackedInt32Array()
var _builds: Node3D = null
var _props: Node3D = null
## **The picture props, and the two numbers `_paint_flat_props` needs to redraw them.**
## ⚠ **Three parallel arrays and they are built in one place** — `_put_flat_prop` appends to all three
## and `_rebuild_props` clears all three. Nothing else may append to one of them.
## **The picture props, two draws each — the ink first and the card over it.**
## ⚠ Filled in one place (`_put_flat_prop`) and cleared in one place (`_rebuild_props`).
var _flat_props: Array = []
var _card_shader: Shader = null
## **The plants that lean, and what they lean off.** ⚠ Four parallel arrays filled in one place
## (`_maybe_sway`) and cleared in one place (`_rebuild_props`). Nothing else may append to one.
var _sway_nodes: Array[Node3D] = []
var _sway_base: Array[Basis] = []
var _sway_amp: Array[float] = []
var _sway_phase: Array[float] = []
## The wind's own clock. ⚠ **Aged by the bare frame delta**, like every other clock in this file.
var _sway_clock := 0.0


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
	mat.set_shader_parameter("reach_alpha", Look.PAD_REACH_ALPHA)
	mat.set_shader_parameter("reach_lighten", Look.PAD_REACH_LIGHTEN)
	# ⚠⚠ **ONE MARK PER 칸, ALWAYS — THE MERGE IS PINNED AND IS NO LONGER A CAMERA THING**
	# (2026-09-01, the user: "let us do it by the 블록"). The order takes a 칸 now, so a board showing
	# 280 조각 marks while the press commands one of 70 칸 is the mark-vs-order mismatch the
	# 2026-08-29 reversal was made to END, read backwards. `Look.PAD_MERGE_ZOOM` 0.72 and
	# `PAD_APART_ZOOM` 1.45 were the ramp's two ends and both are deleted with `pad_merge()`.
	# ⚠ **This is a displacement, not a stack, so the alpha does NOT multiply.** The shader moves
	# every vertex by its own `UV2` delta; measured off `assets/terrain/island.glb` on 2026-09-01,
	# at merge 1 the four 판 of 칸 (2,1) span x -0.700..0.000 and 0.000..0.780 and the same in z —
	# **each grows into its own quadrant and the four tile into one lump.** No re-bake is needed and
	# none was done.
	# ⚠⚠ **AND THE SHADER IS NOT EDITED, ON PURPOSE.** Its 조각 branch — `on_cell`, the
	# `(1.0 - merge)` term and the `reach_at(UV.x)` side of the mix — is unreachable at merge 1 and
	# is LEFT STANDING: **this decision has already flipped twice** (칸 on 2026-08-28, 조각 on
	# 2026-08-29, 칸 today), and the 조각 look is one uniform away for as long as that branch lives.
	mat.set_shader_parameter("merge", 1.0)
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
	# ⚠⚠ **THE MASK GOES THROUGH HERE TOO AND NOT FROM `set_reach` DIRECTLY.** The 판 is re-adopted
	# every time the island is rebuilt, and a mask pushed anywhere else would be the one uniform the
	# new material never received — the reach would go dark on island two with every other mark fine.
	_pads_mat.set_shader_parameter("show_reach", 1.0 if _reach_on else 0.0)
	if _reach_tex != null:
		_pads_mat.set_shader_parameter("reach_tex", _reach_tex)
	# ⚠⚠ **The board's width goes the same way as the hover**, because the shader needs both to answer
	# one question: what lights up. It is handed a 조각 index and decodes it with this stride, then
	# collapses the four 조각 into their 칸 itself — which is why `set_hover_tile` and `set_reach`
	# stay per-조각 while what appears on the ground is one mark per 칸.
	# ⚠ **The merge is NOT written here any more** (2026-09-01). It is pushed once at adoption and
	# never moves; pushing a constant on every mouse move said the camera still decided it.
	if battle != null and battle.grid != null:
		_pads_mat.set_shader_parameter("board_w", float(battle.grid.w))


## ⚠⚠ **`pad_merge()` STOOD HERE AND IT IS DELETED** (2026-09-01). It answered how far the 판 had
## merged at the camera's current distance — 0 one-per-조각, 1 one-per-칸 — off the zoom and the two
## bounds `Look.PAD_MERGE_ZOOM` / `PAD_APART_ZOOM`, which went with it. **The merge is 1 at every
## zoom now**, pushed once in `_adopt_the_pads`, because the order takes a 칸 and the marks may not
## count differently from the press.


## **Whether the whole board is showing.** The shell drives this off the reveal key being held —
## down is true, up is false — so the board is visible for exactly as long as the key is.
##
## ⚠ **Not a toggle.** A held key cannot leave the board switched on behind a player who forgot, and
## the user asked for 「특정버튼 눌러야 그 뜨게해줘」 — pressed, not latched.
func set_pads_revealed(on: bool) -> void:
	_pads_revealed = on
	_tell_the_pads()


## **Lights every 조각 the picked bodies may stand on, and nothing else.** An empty list puts the board
## back to rest, which is what an empty hand hands in.
##
## ⚠⚠ **THIS IS WHAT REPLACED HOLDING TAB** (2026-08-31, the user: 「tab 없이 그냥 캐릭터를 누르면
## 이동할 수 있는 칸들이 뜨고」). The reveal key still works and still shows the whole board; it is no
## longer the only way to see where a body may go, and it is no longer required for the hover to light.
##
## ⚠ **The set is `Hand.reach` and this does not recompute it.** A second reachability rule living here
## is exactly the drift `how-nets-lie` names: the picture would light 조각 the order then refuses.
func set_reach(tiles: PackedInt32Array) -> void:
	var size := _map_tiles()
	if _reach_img == null or _reach_img.get_width() != size.x or _reach_img.get_height() != size.y:
		# ⚠ **`FORMAT_R8` and one channel.** The shader asks a yes/no question and an RGBA8 mask would
		# be four times the upload for three channels nobody reads.
		_reach_img = Image.create(size.x, size.y, false, Image.FORMAT_R8)
		_reach_tex = ImageTexture.create_from_image(_reach_img)
	_reach_img.fill(Look.COL_REACH_OFF)
	for k in tiles.size():
		var t := int(tiles[k])
		if t < 0:
			continue
		var tx := t % size.x
		var ty := t / size.x
		if ty >= size.y:
			continue
		_reach_img.set_pixel(tx, ty, Look.COL_REACH_ON)
	_reach_tex.update(_reach_img)
	_reach_on = not tiles.is_empty()
	_tell_the_pads()


## **The route each picked body would walk**, handed in as 조각 lists. An empty array draws nothing,
## which is the resting state and the state a press restores.
##
## ⚠ **Stored and not drawn here.** Every ground mark in this file is built inside the one fx pass in
## `_process`, between the buffer opening and its flush — a mark drawn outside it is a mark on a
## buffer that has already been committed, and it never reaches the screen.
func set_move_lines(lines: Array, ids: PackedInt32Array = PackedInt32Array()) -> void:
	_move_lines = lines
	# ⚠ **The ids are what let the line leave the FEET.** A body at rest is drawn off its 조각's middle
	# on its seat, and a line that ignored that started from the middle of the 조각 with nobody on it
	# — 2026-08-31, the user: 「지금은 블록 가운데서 오는듯한데?」.
	_move_ids = ids


## **Puts the white rim on these bodies and takes it off every other** (2026-08-31, the user: 「내가
## 누른 캐릭이 티가 나야할듯함」). An empty list is the resting state.
##
## ⚠ **Ids and not positions.** The rim is drawn inside the body loop from the body's own picture and
## its own place, so a rim cannot end up a frame behind the body it belongs to.
func set_picked(ids: PackedInt32Array) -> void:
	_picked = {}
	for k in ids.size():
		_picked[int(ids[k])] = true


## **Puts the standing buildings on the ground.** ⚠ **Nothing is placed by eye**: the kind comes from
## the island file, the footprint comes from the building table, and the height comes from the tile the
## building stands on. All three are written by the two Blender runs, so a building cannot end up half
## a tile off or floating over a step.
##
## ⚠⚠ **This draws them and nothing else, and everything a building DOES lives in `Battle`.** The
## 성채 blocks bodies (`setup` fills every 조각 it covers under `KEEP_UID`), it burns (a 늑대 that takes
## `TARGET_KEEP` spends its blow on `keep_hp`), and the run is lost in the sub-step it falls. **Read
## those there** — a picture that stopped agreeing with them is a question for the sim, not for this
## function.
func _rebuild_buildings() -> void:
	if _world == null:
		return
	if _builds != null:
		_builds.queue_free()
		_builds = null
	# ⚠ **Forgotten with the buildings and not beside them.** A roof remembered from the last island
	# is a bar hanging over open ground on this one.
	_keep_roof_known = false
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
		# ⚠⚠ **THE ROOF IS READ OFF THE MESH THAT WAS JUST PLACED, NOT OFF A NUMBER HERE.** The keep's
		# height is `BUILD_SCALE` times whatever `buildings.blend` was saved with, and `buildings.json`
		# answers the footprint and nothing else — a constant for the roof would be a second copy of a
		# shape this file does not own, wrong the first time the `.blend` is opened.
		# ⚠ **`get_aabb()` is the mesh's own box in LOCAL units**, so the scale has to be applied here;
		# `one.position.y` is already the ground the building stands on.
		if kind == Builds.KEEP and one.mesh != null:
			_keep_roof = Vector3(cx, one.position.y + one.mesh.get_aabb().end.y * Look.BUILD_SCALE, cy)
			_keep_roof_known = true
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
	# next export of the hull.
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
	_flat_props.clear()
	_sway_nodes.clear()
	_sway_base.clear()
	_sway_amp.clear()
	_sway_phase.clear()
	for row in placed:
		var d := row as Dictionary
		var t := int(d["y"]) * battle.grid.w + int(d["x"])
		var foot := Vector3(
			float(d["x"]) + 0.5 + float(d.get("ox", 0.0)),
			Islands.ground_h(battle.grid.level_of(t)),
			float(d["y"]) + 0.5 + float(d.get("oy", 0.0)))
		var sc := float(d.get("scale", 1.0))
		var src := lib.find_child(str(d["kind"]), true, false) as MeshInstance3D
		if src == null:
			_put_flat_prop(str(d["kind"]), foot, sc)
			continue
		var one := src.duplicate() as MeshInstance3D
		one.position = foot
		one.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
		one.scale = Vector3(sc, sc, sc)
		# ⚠ **After the yaw AND after the scale** — what is remembered is the finished basis, and the
		# lean is composed onto it every frame. Remember it before either and the prop snaps to
		# north at full size on the first frame it sways.
		_maybe_sway(one, str(d["kind"]), t)
		_props.add_child(one)
	# ⚠⚠ **BEFORE the pictures are hung, and that is why they are added after this call.** `_outline`
	# walks `MeshInstance3D` and a `Sprite3D` is not one, so a picture would be skipped anyway — but
	# the ordering is written down because the pictures ALREADY CARRY THEIR OWN BORDER. Every tree
	# 시안 came back with a dark rim (pixellab's `lineless` is documented as weakly guiding and behaved
	# that way), so an engine outline on top of them is a second rim on a 64 px picture — and 1.10 was
	# measured to eat a 21 px wolf whole.
	_outline(_props)
	for pair in _flat_props:
		for mi in pair:
			_props.add_child(mi)
	lib.free()


## **Enrols a prop in the wind, if its kind is one that moves.**
##
## ⚠⚠ **The phase comes from the TILE and never from a random number.** A scatter that rolled dice at
## load time would sway differently every launch and no screenshot of it would mean anything — the
## same rule `_rebuild_props`'s own header states about where props go.
func _maybe_sway(n: Node3D, kind: String, tile: int) -> void:
	var deg := float(Look.PROP_SWAY_DEG_OF.get(kind, 0.0))
	if deg <= 0.0:
		return
	_sway_nodes.append(n)
	_sway_base.append(n.basis)
	_sway_amp.append(deg_to_rad(deg))
	# **An irrational times the tile, wrapped into ONE CYCLE** — neighbours land far apart in phase,
	# so a row of bushes does not lean as one board. ⚠ **0..1, not radians**: `_gust_wave` counts
	# cycles, and a phase in radians would put every prop within a sixth of a cycle of its neighbour.
	_sway_phase.append(fposmod(float(tile) * 0.381966, 1.0))


## **Leans every plant, once a frame.**
##
## ⚠ **Composed onto the remembered basis, never accumulated onto the live one.** Multiplying this
## frame's tilt into whatever is already there is how a prop walks itself over on its own axis in
## about four seconds — the drift is invisible per frame and total after a minute.
func _paint_sway(dt: float) -> void:
	if _sway_nodes.is_empty():
		return
	_sway_clock += dt
	var wind := deg_to_rad(Look.PROP_SWAY_WIND_DEG)
	# the lean tips TOWARD the wind, so the turn is about the axis across it
	var axis := Vector3(-sin(wind), 0.0, cos(wind))
	var w := Look.PROP_SWAY_HZ * _sway_clock
	var g := Look.PROP_SWAY_GUST_HZ * _sway_clock
	for i in _sway_nodes.size():
		var ph: float = _sway_phase[i]
		var a: float = _sway_amp[i] * lerpf(
			_gust_wave(w + ph), _gust_wave(g + ph * 0.37), Look.PROP_SWAY_GUST)
		_sway_nodes[i].basis = Basis(axis, a) * _sway_base[i]


## **The wave the lean rides, in −1..1, one cycle per unit of `x`.**
##
## ⚠⚠ **A SINE IS THE WRONG SHAPE AND THAT IS WRITTEN DOWN OUTSIDE THIS REPO.** Crysis's own vegetation
## code uses a SMOOTHED TRIANGLE — `smooth(tri(x))` — and Unity's shipped grass raises its sine to the
## fourth power; both sharpen the crest and flatten the trough, so a plant **rests, gusts, and rests**
## instead of ticking like a metronome. **The reference note on foliage, mesh-vs-card and sway already
## carries the complaint that names the defect** — a reply to Bad North's developer: 「your bush
## wiggling is too regular… wind is more wave like」. The formulas are in the note beside it, on the
## sway arithmetic and the outline shell.
static func _gust_wave(x: float) -> float:
	var tri := absf(fposmod(x + 0.5, 1.0) * 2.0 - 1.0)      # 0..1..0, a triangle
	return (tri * tri * (3.0 - 2.0 * tri)) * 2.0 - 1.0      # eased at both ends, then to −1..1


## **A prop drawn as a picture instead of a mesh** — `assets/props/flat/<kind>.png`.
##
## ⚠⚠ **The kind is looked up in `props.glb` FIRST and here only if it is not there**, so nothing in
## `island.json` says which of the two a prop is. **The file that exists decides**, which means a tree
## going from mesh to picture is a file move and not a data edit.
##
## ⚠ **Built once and kept**, unlike a body: a prop never moves, so the per-frame `Sprite3D` pool would
## be paying a body's price for a rock that stands still. **The one thing that must still change every
## frame is the pitch stretch** — see `_paint_flat_props`.
func _put_flat_prop(kind: String, foot: Vector3, sc: float) -> void:
	var path := FLAT_PROP_DIR + kind + ".png"
	if not ResourceLoader.exists(path):
		return
	var pic := load(path) as Texture2D
	if pic == null:
		return
	# ⚠⚠ **A `Sprite3D` STOOD HERE AND IT COULD NOT MOVE** (2026-08-31). `BILLBOARD_FIXED_Y` rebuilds
	# the node's basis every frame and throws its rotation away — measured at **0.00 px of sway while
	# the mesh beside it travelled 5.8** — and a `Sprite3D` also wears no outline, measured at **0
	# near-black pixels against the mesh's 306**. **Both are cured by owning the quad**: the card
	# below turns itself, bends itself, and draws its own ink, which is the package Bad North's
	# billboards actually ship with.
	# ⚠ **One texture pixel is one world px** at `Look.SPRITE_PIXEL_SIZE` (1 / `TILE_PX`), so a 64 px
	# picture at scale 1.0 stands **1.6 조각** tall. That rule did not change with the mechanism.
	var base := Look.PROP_PIC_SCALE * sc
	var wide := float(pic.get_width()) * base * Look.SPRITE_PIXEL_SIZE
	var tall := float(pic.get_height()) * base * Look.SPRITE_PIXEL_SIZE
	var quad := QuadMesh.new()
	quad.size = Vector2(wide, tall)
	# ⚠ **Offset up by half, so the quad's FOOT is its origin.** The shader's stretch and its wind
	# weight both measure from y = 0, and a centred quad would lift off the ground as either grew.
	quad.center_offset = Vector3(0.0, tall * 0.5, 0.0)
	if _card_shader == null:
		_card_shader = load(PROP_CARD_SHADER) as Shader
	var pair: Array[MeshInstance3D] = []
	# ⚠⚠ **The ink is a SEPARATE DRAW and it goes first.** It is not a `next_pass`: a next pass is
	# ordered by material properties and distance rather than by request, and the ink has to be the
	# one behind. **Two nodes, and the shader's own `back_push` keeps them apart in depth.**
	for is_ink in [true, false]:
		var mat := ShaderMaterial.new()
		mat.shader = _card_shader
		mat.set_shader_parameter("card", pic)
		mat.set_shader_parameter("silhouette", is_ink)
		mat.set_shader_parameter("ink", Look.COL_OUTLINE)
		mat.set_shader_parameter("wind_dir", Vector2(
			cos(deg_to_rad(Look.PROP_SWAY_WIND_DEG)), sin(deg_to_rad(Look.PROP_SWAY_WIND_DEG))))
		mat.set_shader_parameter("wind_strength", Look.PROP_CARD_WIND_STRENGTH)
		mat.set_shader_parameter("wind_speed", Look.PROP_CARD_WIND_SPEED)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.position = Vector3(foot.x, foot.y + Look.PROP_PIC_LIFT_PX / Look.TILE_PX, foot.z)
		# **No shadow, on purpose.** A card's shadow is the shadow of a plane that keeps turning.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# ⚠ **The wind pushes the top out past the quad's own bounds.** Without a margin the card
		# pops out of existence near the screen edge — the stale-AABB trap the reference note names.
		mi.extra_cull_margin = tall
		pair.append(mi)
	_flat_props.append(pair)


## **Hands every card the wind's clock and the camera's pitch, once a frame.**
##
## ⚠⚠ **A body gets the pitch stretch inside `_billboard_scale` and a card cannot**, because the card
## rebuilds its own basis in the vertex shader and throws the node's scale away with it. It arrives as
## a uniform instead. Without it a card shortens as the camera tilts while the swordsman beside it
## does not, and **two things drawn the same way disagreeing on screen is worse than both being wrong.**
## ⚠ **The same clock the meshes lean off**, so a card and a bush do not blow different weather.
func _paint_flat_props() -> void:
	if _flat_props.is_empty():
		return
	var k := _pitch_stretch()
	for pair in _flat_props:
		for mi in pair:
			var mat := mi.material_override as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("stretch", k)
			mat.set_shader_parameter("wind_t", _sway_clock)


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
		# ⚠ **The pool is shared and one member may have been something else last frame.** Nothing in
		# here overrides a material today except the rim, which has its own pool — this line is what
		# keeps that true if a second one is ever added.
		reused.material_override = null
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
	# **기법 17's copy is born with its body**, so the two pools can never come apart by one.
	var edge := Sprite3D.new()
	edge.pixel_size = Look.SPRITE_PIXEL_SIZE * Look.BODY_OUTLINE_SCALE
	edge.billboard = s.billboard
	edge.alpha_cut = s.alpha_cut
	edge.texture_filter = s.texture_filter
	edge.shaded = false
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge.modulate = Look.COL_BODY_OUTLINE
	edge.visible = false
	_world.add_child(edge)
	_outlines.append(edge)
	_sprites_used += 1
	return s


## **The black copy standing behind the body the pool just handed out.** ⚠ `_sprites_used` has already
## been advanced by `_sprite()`, so the body's own index is one less than it.
##
## ⚠⚠ **PUSHED ALONG THE CAMERA'S OWN AXIS, NEVER THE WORLD'S.** A billboard faces the screen, so a
## copy pushed along world Z slides out from behind its body the moment the board turns — it would
## read as a black shadow beside the animal at some yaws and as an outline at others.
func _put_outline(body: Sprite3D) -> void:
	var i := _sprites_used - 1
	if i < 0 or i >= _outlines.size():
		return
	var edge := _outlines[i]
	edge.visible = true
	edge.texture = body.texture
	edge.scale = body.scale
	edge.pixel_size = Look.SPRITE_PIXEL_SIZE * Look.BODY_OUTLINE_SCALE
	edge.centered = body.centered
	edge.offset = body.offset
	edge.position = body.position - _cam.global_transform.basis.z * Look.BODY_OUTLINE_BACK_TILES


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
## ⇒ **A tile-unit position goes in, untouched.** The picture is offset afterwards.
## ⚠⚠ **THERE WAS A THIRD POINT HERE, `crowd_px`, AND IT IS GONE** (2026-09-02, ticket 03-17). A 조각
## admits `Rules.TILE_CAPACITY` bodies since 2026-08-30 and the sim walks every one of them to the same
## 조각 centre; the ring that spread them is replaced by the seat, and the seat is already folded into
## `at_tiles` by the caller. **The rule the third point carried still holds**: where the body STANDS
## takes the shadow with it and the idle sway does not — the sway is the body moving over a disc that
## stays put.
## ⚠⚠ **IT TOOK A `radius` AND IT TAKES THE `type_id` IT WAS DERIVED FROM** (2026-08-30). The radius is
## one read of the row; the row also says how big this species is drawn, and passing the derived number
## while the caller kept the row is how the two would have been read in two places.
## ⚠ **`at_tiles` IS THE DRAWN STAND POINT SINCE 2026-09-02** (ticket 03-17) — the seat on the 칸's
## lattice for a body at rest, the sim's point for one walking — and not the sim's position outright:
## the seat is a still point a body stands on, so the ground and the shadow belong under it, where the
## sway (which moves every frame) still does not. **The `crowd_px` parameter stood between these two and
## is deleted** with the per-조각 ring; the shadow needs no second offset now.
func _put_body(centre_px: Vector2, at_tiles: Vector2, type_id: int, colour: Color,
		squash: Vector2, tex: Texture2D, outlined: bool = false) -> float:
	var radius := Look.body_radius_of(type_id)
	# ⚠⚠ **THE ROW'S INK FRACTION, AND DIVIDING BY IT IS THE WHOLE POINT** (2026-08-31).
	# `beast_draw_scale` is how wide the ANIMAL is drawn; this turns that into how wide the PICTURE
	# around it has to be. **Without the division every strip that needed a wider canvas shrank the
	# body** — it was paid back by hand twice in one afternoon, 0.65 to 0.78 and 0.85 to 0.956, with
	# the two halves of each pair sitting in two different files.
	var frac := _ink_of(type_id)
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
			* Look.BODY_SPRITE_SCALE * Look.beast_draw_scale(type_id) / frac
	# ⚠⚠ **THE DISC IS A FRACTION OF THE DRAWN PICTURE, NOT OF THE SIM RADIUS** (2026-08-30, the user:
	# 「the soldiers have no shadow」). It was `radius * BODY_SPRITE_SCALE * 0.62`, and the picture is
	# `radius * BEAST_SPRITE_W_RATIO(3.5) * BODY_SPRITE_SCALE` across — **so the disc was one fifth of the
	# body's width and sat entirely hidden underneath it.** The swordsman showed it worst: his picture is
	# 33x40 where a wolf's is 74x40, so at one drawn WIDTH he stands far taller and buries the disc.
	# ⚠⚠ **`wide * frac` AND NOT `wide`** (2026-08-31) — the disc is a fraction of the ANIMAL,
	# so a canvas widened by a death pose no longer widens the shadow. See `Look.BODY_SHADOW_OF_INK`.
	_put_ground_shadow(Look.tile_point_px(at_tiles),
		wide * frac * 0.5 * Look.BODY_SHADOW_OF_INK)
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
	# **기법 24 · 깊이 조금 밀어주기 IS NOT DONE HERE, AND IT WAS TRIED** (2026-08-31). Moving the body
	# along the camera's own axis is invisible under an ORTHOGRAPHIC camera — the screen position does
	# not change — but **the world position does, and this camera is pitched, so the body rose 0.0245
	# 조각 off the ground.** `net_fx_view` caught it on the frame-bottom row. ⇒ **The technique needs a
	# depth BIAS, not a translation**, and nothing here has reported the z-fighting it cures.
	# ⚠ **The OUTLINE is still pushed along that axis and that is correct** — it is meant to sit behind,
	# and it stands on nothing.
	#
	# **기법 23 · 살짝 뒤로 눕히기.** ⚠ Measured inert on a billboard — see `Look.BODY_LEAN_DEG`. The
	# line stays so the technique has one home rather than none.
	s.rotation = Vector3(deg_to_rad(-Look.BODY_LEAN_DEG), 0.0, 0.0)
	# **기법 17 · 외곽선**, last, because it copies everything decided above.
	# ⚠ **기법 26 · 색으로 배경에서 떼기 is not a line here** — it lives inside `Look.beast_tint`, so
	# there is one place a body's colour is decided and `net_shell` reads the same answer this does.
	_put_outline(s)
	# ⚠⚠ **THE RIM IS PLACED FROM THE BODY'S FINISHED POSITION AND SCALE, NOT RE-DERIVED.** Every
	# correction above it — the foot height, the frame's empty rows, the gait squash, the seat
	# — would otherwise have to be repeated, and a rim that repeated four of five would sit a little
	# off its own body in exactly the cases that were hardest to get right.
	if outlined:
		_put_pick_outline(s, pic)
	# ⚠⚠ **THE TOP IS RETURNED AGAIN** (2026-09-01), for the HP bar that hangs off it. It was returned
	# until 2026-08-29 for a halo that is deleted, and the rule that outlived both is the reason it is
	# a return and not arithmetic at the caller: a wolf is 55 x 40 and a caveman 36 x 40, so sized by
	# WIDTH off the same radius the man stands half again as tall as the animal. ⇒ **Nothing that
	# hangs above a body may compute its own height from the radius.** The old HP bar did, and it
	# landed across the caveman's face the first time he was on screen.
	# ⚠ **The picture's top and not the ink's.** `_measure_body_feet` scans the empty rows UNDER the
	# animal only, so a strip that grew its canvas upward lifts the bar with it — which is the safe
	# direction: a bar too high is a bar, a bar too low is a bar across a face.
	return s.position.y + tall * 0.5


## ⚠⚠ **`_put_hp` STOOD HERE AND IS DELETED** (2026-08-28, the user: 「체력바 없이」). It drew the two
## halves of a bar above every body. **The bodies are being redone** — the user, earlier the same day:
## 「캐릭터랑 건물제거 다시잡을꺼임」 — and a bar over every one of them is chrome nobody chose, of
## exactly the kind `CLAUDE.md` now says is designed in a tool rather than typed here.
## ⚠ **The sim is untouched**: `army.hp` and `battle.enemy_hp` are unchanged and still decide who dies.


## Every body, every frame. **This is what pass 6, 7 and 8 of the old `_draw` were**, minus the marks
## that are not ported yet.
## ⚠ **It reads the glide and never moves it** — `_advance_seat_glide` ran before the 이동선 was laid,
## and a body with no entry (the nets that call this straight, before any frame) is drawn at its stand
## point, which is what the first frame would have written.
func _paint_bodies() -> void:
	_sprites_used = 0
	# ⚠ **Opened with the body pool and closed by the same `_hide_unused`.** A rim pool opened
	# anywhere else is a rim left standing over a body that has died.
	_rims_used = 0
	# ⚠ **Opened here even on the empty path below**, so a bar from the last island cannot be left
	# hanging over the title screen — the same reason `_paint_boats` is still called down there.
	_bars_used = 0
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
		var ety := int(battle.enemy_type[e])
		_put_walker("e%d" % e, ety,
			_drawn_of("e%d" % e, battle.enemy_pos[e], Battle.ENEMY_UID_BASE + e, _resting_enemy(e)),
			true, false, _hp_frac(float(battle.enemy_hp[e]), Rules.hp_of(ety)))

	# ⚠ **Emptied here and not on the empty path above**, so a frame with no island leaves the last
	# frame's map standing — and the last frame's sprites are hidden, which `body_at_px` reads.
	_sprite_of_soldier = {}
	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		# ⚠ **`army.max_hp_of` and not `Rules.hp_of` off the row.** There is no `hp` column in the
		# army since the revival, and `max_hp_of` is the one answer to 「what is this body healed to」.
		_put_walker("s%d" % i, int(army.type_id[i]),
			_drawn_of("s%d" % i, battle.soldier_pos[i], i, _resting_soldier(i)),
			false, _picked.has(i), _hp_frac(float(battle.soldier_hp[i]), army.max_hp_of(i)))
		# The sprite `_put_walker` just took is this body's — see `_sprite_of_soldier` for why the
		# index is read here and nowhere else.
		_sprite_of_soldier[i] = _sprites_used - 1

	# ⚠⚠ **THE ONE PLACE A BODY THE SIM HAS ALREADY DROPPED IS STILL DRAWN** (2026-08-31). Both lists
	# above hold the living only — `living_enemy_ids`'s own header says a corpse must not be left on
	# screen — and that is still true: **what is drawn here is not a corpse, it is a body in the
	# middle of falling**, and it stops the frame its death strip runs out.
	# ⚠ **It reads `last` and never the sim's position**, which is OFFMAP for a dead beast.
	# ⚠ **It falls where it was DRAWN, not where the sim had it.** The 조각 and the seat were released
	# the moment the body died, so `_stand_point` has nothing to say; the glide entry still holds the
	# seat it was standing on, and a fall that popped back onto the 조각 centre first would read as the
	# body stepping before it drops. `last` is the fallback for a body that died on its first frame.
	for key: String in _body:
		var b: Dictionary = _body[key]
		if float(b["dying"]) <= 0.0:
			continue
		_put_walker(key, int(b["type"]), _seat_glide.get(key, b["last"]), key.begins_with("e"))

	# ⚠ **Inside this function and not beside it.** The riders come out of the same `Sprite3D` pool the
	# bodies do, and that pool is opened by the `_sprites_used = 0` above and closed by the
	# `_hide_unused()` below — painted outside the pair, every rider would be hidden the same frame it
	# was drawn.
	_paint_boats()

	# ⚠ **Inside the pair too**, for the same reason the riders are: the 성채's bar comes out of the
	# pool opened above and closed below, and painted outside them it would be hidden the same frame.
	_paint_bars()

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


## The picture a body wears THIS frame: its bite strip while a bite is running, its **walk strip while
## it is moving and its breath strip while it is not**, and **its standing picture whenever every
## strip it asked for is empty** — which is the whole of how the species with no art keep working.
## ⚠⚠ **IT WAS BITE-OR-WALK AND NOTHING ELSE** (until 2026-08-31). A standing body wore the walk,
## which is why the note below says a standing body keeps cycling its legs — **it does not any more,
## it breathes**, and `Look.BODY_STILL_SEC` is the line between the two. **The bite became the attack
## and the flinch and the fall joined it the same day**, which is why the choice is a list now.
##
## ⚠⚠ **The walk phase is TIME, not distance, and that is the opposite of `_gait_squash` one clock
## over.** The squash is a stride and is right to stop dead with the body. The legs are not: phased on
## distance they made a body in contact the only completely motionless thing on the island, which is
## what the user was looking at when he said 「그냥 붙어서 그냥 벌렁벌렁하는 거밖에 없어」. A standing
## body keeps cycling its legs and `_idle_offset` is what says it is standing.
func _body_tex(key: String, type_id: int, head: Vector2) -> Texture2D:
	var stand := _beast_tex(type_id, head)
	if not _body.has(key):
		return stand
	var b: Dictionary = _body[key]
	var facing := _facing_index(type_id, head)
	# **The order this body asks in, and it is a LIST rather than a chain of `if`s because the second
	# choice is what carries a species with only some of its art.** A row with a walk and no breath
	# keeps walking on the spot when it stands still, which is what it did before the breath existed
	# and is still better than a held frame.
	#
	# ⚠⚠ **DEATH FIRST, THEN HURT, THEN ATTACK, AND THE ORDER IS THE WHOLE OF THE RULE.** A body
	# that is dying is not interrupted by anything — it has already left the sim. A body being hit
	# drops the swing it was in the middle of, because **a blow that lands has to be the thing on
	# screen**; the other way round, a body under fire keeps calmly punching and nothing reads.
	# ⚠⚠ **EXCEPT A SWING WHOSE BLOW HAS NOT LANDED YET** (2026-09-02). The sim lands the blow
	# `Rules.SWING_LAND_SEC` into the swing whether or not the striker was hit meanwhile, and a swing
	# hidden under a flinch is damage dealt by a sword nobody saw — the very thing the flinch-first
	# rule exists to prevent, the other way round. So: the swing until it lands, the flinch after.
	var order := []
	if float(b["dying"]) > 0.0:
		order.append(Look.Anim.DEATH)
	var swinging := float(b["attack"]) > 0.0
	var landed := swinging and _anim_sec(type_id, Look.Anim.ATTACK) - float(b["attack"]) \
			>= Rules.SWING_LAND_SEC - Rules.EPS
	if swinging and not landed:
		order.append(Look.Anim.ATTACK)
	if float(b["hurt"]) > 0.0:
		order.append(Look.Anim.HURT)
	if landed:
		order.append(Look.Anim.ATTACK)
	if float(b["still"]) <= Look.BODY_STILL_SEC:
		order.append_array([Look.Anim.WALK, Look.Anim.IDLE])
	else:
		order.append_array([Look.Anim.IDLE, Look.Anim.WALK])
	for raw_anim in order:
		var anim := int(raw_anim)
		var strip := _anim_strip(type_id, anim, facing)
		if strip.is_empty():
			continue
		var at := 0
		var left := _clock_of(b, anim)
		if left >= 0.0:
			# The clock runs DOWN, so `1 - left/whole` is how far in the strip is. Clamped at both
			# ends: `int()` of exactly 1.0 lands one past the last frame, and the last frame is the
			# one the blow is widest in — a swing that never reaches it is a swing nobody sees.
			at = clampi(int((1.0 - left / _anim_sec(type_id, anim)) * float(strip.size())),
				0, strip.size() - 1)
		else:
			# ⚠ **One clock for the walk AND the breath**, so a body that stops mid-stride picks the
			# breath up wherever the phase already was. Two clocks is two things to keep wound.
			at = int(float(b["walk"]) / Look.BEAST_FRAME_SEC) % strip.size()
		return strip[at] as Texture2D
	return stand


## **Seconds left of the one-shot strip `anim`, or -1 for a strip that loops.** The three one-shots
## each own a countdown in the body's own dictionary; the walk and the breath share the free-running
## clock instead. ⚠ **The name of the clock is the name of the strip on purpose** — a lookup table
## keyed by `Anim` here and a set of literals in `_fx_step` is the pair that drifts.
func _clock_of(b: Dictionary, anim: int) -> float:
	match anim:
		Look.Anim.DEATH:
			return float(b["dying"])
		Look.Anim.HURT:
			return float(b["hurt"])
		Look.Anim.ATTACK:
			return float(b["attack"])
	return -1.0



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
## ⚠⚠ **`hp_frac` DEFAULTS TO 1.0, WHICH IS 「no bar」, AND THE FALLING BODIES RELY ON IT** (2026-09-01).
## A body in the middle of its death strip is already at 0 hp, and a bar drawn from that number would
## be an empty trough riding a corpse down — the one thing 「깎인 것만 뜬다」 was chosen to avoid.
##
## ⚠⚠ **`drawn` IS WHERE THE BODY IS DRAWN THIS FRAME, ALREADY GLIDED** (2026-09-02, ticket 03-17) —
## `_drawn_of`'s answer: the seat on the 칸's lattice for a body at rest, the sim's own point plus the
## seat offset it left with for one walking, and the point in between while it slides. **This function moves nothing**; the glide stepped
## in `_advance_seat_glide` before the 이동선 was laid, so the line under the feet and the feet agree.
## ⚠ **The `slot` parameter stood here and it is deleted** with the per-조각 ring it indexed.
func _put_walker(key: String, type_id: int, drawn: Vector2, is_enemy: bool,
		outlined: bool = false, hp_frac: float = 1.0) -> void:
	var centre := Look.tile_point_px(drawn) + _body_offset_of(key)
	# A body faces the way it last walked. `_facing_of` returns RIGHT when it has never moved, so a
	# body standing still faces right rather than flipping on a zero vector.
	var tex := _body_tex(key, type_id, _facing_of(key))
	# ⚠ **The flash is mixed into the SIDE colour before the tint**, so a flashing body still reads as
	# whose it is — see `Look.hit_flash_colour`.
	var lit := Look.hit_flash_colour(Look.body_colour_of(is_enemy), _flash_of(key))
	# ⚠ **The two squashes MULTIPLY.** A body can be walking into a blow, and the gait and the swing
	# are different motions — replacing one with the other would drop whichever came second.
	var gait := _gait_squash(key)
	var swing := _swing_squash(key)
	# ⚠ **`outlined` rides along untouched** — whether this body is the one in hand is the shell's
	# answer, not a thing the view re-derives.
	var top := _put_body(centre, drawn, type_id, lit,
		Vector2(gait.x * swing.x, gait.y * swing.y), tex, outlined)
	# ⚠ **Here and not in `_paint_bodies`**, because this is the one line where the body's drawn top is
	# in hand. `_put_body`'s own note carries what re-deriving it off the radius cost.
	# ⚠ **`centre` and not the sim's 조각**: the bar hangs over the picture, so it takes the sway, the
	# lunge and the seat the picture took — a bar left on the 조각 centre would drift off the head of a
	# body that is leaning into a blow.
	_put_bar(Vector3(centre.x / Look.TILE_PX, top + Look.HP_BAR_LIFT_PX / Look.TILE_PX,
		centre.y / Look.TILE_PX), hp_frac)


## **How far into its flash a body is**, 1.0 at the instant of the blow and 0.0 once it is spent.
func _flash_of(key: String) -> float:
	if not _body.has(key):
		return 0.0
	return float((_body[key] as Dictionary)["flash"]) / Look.HIT_FLASH_SEC


## **Steps every body's drawn point one frame toward where it is to be drawn** — the one writer of
## `_seat_glide`, run once per frame before anything is painted. Rebuilt whole: every living body gets
## an entry, a body still falling keeps the one it had, and anything else is gone.
##
## ⚠ **A body with no entry is drawn AT its stand point** — that is the first frame in the pool, and
## why bodies stood by hand in a net read their seat at once. ⚠ **Walking, the entry is the sim's point
## plus the body's `_seat_offset`**, frozen at what it was on the last resting frame; the offset is
## rewritten only at rest, from the entry this pass just produced, so the two tables cannot disagree
## about a body.
## ⚠ **At rest the step is `Look.SEAT_GLIDE_TILES_PER_S` a second, and only across a 칸's width or
## less.** The glide is the hand-off from the last walking point to the seat — under a 조각 to the far
## seat, under two between two seats of one 칸 re-faced — and a target further off than a whole 칸 was
## not walked to: the sim placed the body there, as `net_pick` does by writing `soldier_pos`, and a body
## that slid ten 조각 across the island for that would be the screen doing a thing the sim did not.
func _advance_seat_glide(delta: float) -> void:
	var next := {}
	var offsets := {}
	if battle != null and army != null and battle.grid != null:
		for raw_id in battle.living_enemy_ids():
			var e := int(raw_id)
			var key := "e%d" % e
			var resting := _resting_enemy(e)
			next[key] = _glided(key, battle.enemy_pos[e], Battle.ENEMY_UID_BASE + e, resting, delta)
			offsets[key] = _offset_after(key, battle.enemy_pos[e], next[key], resting)
		for raw_id in battle.ashore_ids():
			var i := int(raw_id)
			var key := "s%d" % i
			var resting := _resting_soldier(i)
			next[key] = _glided(key, battle.soldier_pos[i], i, resting, delta)
			offsets[key] = _offset_after(key, battle.soldier_pos[i], next[key], resting)
		for key: String in _body:
			if float((_body[key] as Dictionary)["dying"]) > 0.0 and not next.has(key):
				next[key] = _seat_glide.get(key, (_body[key] as Dictionary)["last"])
	_seat_glide = next
	_seat_offset = offsets


## **The seat offset a body carries out of this frame**: at rest, where it was just drawn relative to
## the sim's point, bounded to `Look.SEAT_OFFSET_MAX_TILES`; walking, whatever it carried in — a body
## that never rested carries zero. ⚠ **The clamp is applied where the offset is WRITTEN, at rest, and
## not where it is read**, so a resting body drawn further off than the bound (the glide's own
## 「further than a 칸 → stand」 rule keeps that under 2 조각, but a body's first walking frame is what
## the player sees) leaves at the bound and never further.
func _offset_after(key: String, at: Vector2, drawn: Vector2, resting: bool) -> Vector2:
	if resting:
		return (drawn - at).limit_length(Look.SEAT_OFFSET_MAX_TILES)
	return _seat_offset.get(key, Vector2.ZERO)


## One body's drawn point for this frame, from last frame's entry and where it is to stand now.
## ⚠⚠ **A WALKING BODY IS `at` PLUS ITS `_seat_offset`, NEVER `at` ALONE** — `at` alone is the snap
## the user saw on every move order (see `_seat_offset`). A body with no offset entry walks on the sim's
## point, which is the same thing.
func _glided(key: String, at: Vector2, unit_id: int, resting: bool, delta: float) -> Vector2:
	if not resting:
		return at + _seat_offset.get(key, Vector2.ZERO)
	var stand := _stand_point(at, unit_id, resting)
	if not _seat_glide.has(key):
		return stand
	var from: Vector2 = _seat_glide[key]
	if from.distance_to(stand) > float(Rules.BLOCK_TILES):
		return stand
	return from.move_toward(stand, Look.SEAT_GLIDE_TILES_PER_S * delta)


## **Where a body is drawn this frame** — its glide entry, or its stand point when it has none (a
## `_paint_bodies` called straight by a net before any frame has stepped the glide).
func _drawn_of(key: String, at: Vector2, unit_id: int, resting: bool) -> Vector2:
	if _seat_glide.has(key):
		return _seat_glide[key]
	return _stand_point(at, unit_id, resting)


## **Where a body is to be drawn, in `soldier_pos` units** — its seat on the 칸's lattice when it is at
## rest, the sim's own point otherwise. Ticket 03-17; the glide (`_advance_seat_glide`) is its only
## reader, and the body, the shadow under it, a falling body and the 이동선's first point all read the
## glide.
##
## ⚠⚠ **`_crowd_slot_of` STOOD HERE AND IT IS DELETED** (2026-09-02). It read `Grid.slot_of` — a body's
## place inside ONE 조각 — and `Look.crowd_offset_px` rang the three of them around that 조각's centre;
## the user rejected the picture by eye (「the characters ought to fill in starting from the centre」).
## **The sentence it stood on still holds**: the sim owns the place and this only reads it. `Grid.seat_of`
## hands the seat to whoever holds a 조각 of the 칸, so two bodies cannot be handed one point the moment
## a third dies — a seat invented here would.
##
## ⚠⚠ **AT REST IT IS THE 칸's MIDDLE PLUS THE SEAT, AND BOTH HALVES ARE SIM FACTS.** The middle is
## `_block_middle_tiles` — asked of the grid, never `+ 0.5` — and the seat is `Look.seat_point_tiles`
## over `Grid.seat_of` and `Battle.block_face` (the order's direction; a 칸 with none faces `(0, 1)`).
## `Look` holds the lattice's geometry because nothing in `src/sim/` reads it.
## ⚠ **A resting body with NO seat is drawn on its 조각 centre**, which is `at` itself. That is a body
## stood by writing `soldier_pos` without `Grid.hold` — `net_pick` does it — and drawing it at the
## middle would put a body somewhere the reservation table says nobody is.
## ⚠ **Walking it is `at`, exactly** — `_glided` adds the body's `_seat_offset` on top, so the drawn
## point never lags a walk and never snaps at its start; `_resting_soldier` and `_resting_enemy` are
## the two rest tests and the caller passes the answer in.
func _stand_point(at: Vector2, unit_id: int, resting: bool) -> Vector2:
	if not resting or battle == null or battle.grid == null or battle.grid.w <= 0:
		return at
	var g := battle.grid
	var tx := clampi(int(round(at.x)), 0, g.w - 1)
	var ty := clampi(int(round(at.y)), 0, g.h - 1)
	var block := g.block_of(ty * g.w + tx)
	var seat := g.seat_of(block, unit_id)
	if seat < 0:
		return at
	var face: Vector2 = battle.block_face.get(block, Vector2(0.0, 1.0))
	return _block_middle_tiles(Vector2(float(tx), float(ty))) + Look.seat_point_tiles(seat, face)


## **Whether 검사 `i` is at rest**: no order out, and standing exactly on a 조각 centre. A body one
## sub-step into a walk is off the centre and is drawn where it is.
## ⚠ **Exactly, under `Rules.EPS`** — the same test `_phase_orders` uses for 「arrived」, so the view and
## the sim agree about the frame a walk ends.
func _resting_soldier(i: int) -> bool:
	if battle == null or int(battle.soldier_order[i]) >= 0:
		return false
	return _on_a_piece_centre(battle.soldier_pos[i])


## **Whether 짐승 `e` is at rest**: standing exactly on a 조각 centre. **A wolf has no order column, so
## its position is the whole test** (the plan's amendment 3) — a wolf blocked in a queue at a neck reads
## as at rest, glides to its seat, and glides back onto its path when the queue moves. That shuffle is
## accepted and named: a queue of wolves spreading across the 칸 is the intended look, and a wolf that
## stopped to bite is at rest by the same test.
func _resting_enemy(e: int) -> bool:
	if battle == null:
		return false
	return _on_a_piece_centre(battle.enemy_pos[e])


func _on_a_piece_centre(p: Vector2) -> bool:
	return p.distance_to(p.round()) <= Rules.EPS


## ⚠ **Hidden, never freed.** A pool that shrinks is a pool that reallocates on the next busy frame,
## and a stale sprite left visible is a body that died and stayed on screen — the exact failure the
## per-frame drawer could not have.
func _hide_unused() -> void:
	for k in range(_sprites_used, _sprites.size()):
		_sprites[k].visible = false
	# ⚠⚠ **The outline pool is closed by the SAME index**, never by its own count. A copy left visible
	# behind a hidden body is a black silhouette of a dead animal standing on the island.
	for k in range(_sprites_used, _outlines.size()):
		_outlines[k].visible = false
	# ⚠⚠ **THE RIM POOL IS CLOSED BY ITS OWN COUNT AND THE BLACK POOL IS NOT, AND THAT IS NOT AN
	# INCONSISTENCY.** Every body wears a black copy, so that pool is closed by the body index; only a
	# body in hand wears a white rim, so this one has to carry its own.
	for k in range(_rims_used, _rims.size()):
		_rims[k].visible = false
	# ⚠⚠ **THE BAR POOL CARRIES ITS OWN COUNT FOR THE SAME REASON THE RIM POOL DOES**: only a hurt
	# thing wears a bar, and one of the wearers is the 성채, which is not in the body pool at all.
	# ⚠ **The fill is closed by the FRAME's index**, never by its own — a fill left visible over a
	# hidden frame is a red stripe hanging in the air where a body died.
	for k in range(_bars_used, _bars.size()):
		_bars[k].visible = false
	for k in range(_bars_used, _bar_fills.size()):
		_bar_fills[k].visible = false


## **The white rim behind one body**, grown from that body's own finished sprite.
##
## ⚠⚠ **BEHIND IS ALONG THE CAMERA'S FORWARD AND NOTHING ELSE.** Both quads are billboards standing at
## the same point, so 「behind」 has no world axis — pushed along +Y the rim would ride up the body's
## head as the camera pitched, and along +Z it would swing out from behind it as the board turned.
## ⚠ **Both write depth**, which is what leaves only the rim showing: the body sits in front and its
## own silhouette fails the test everywhere the two overlap.
func _put_pick_outline(body: Sprite3D, pic: Texture2D) -> void:
	if _cam == null:
		return
	var rim := _rim_sprite()
	rim.texture = pic
	rim.scale = body.scale * Look.PICK_OUTLINE_GROW
	# ⚠⚠ **ALONG THE RAY FROM THE CAMERA TO THIS BODY, NOT ALONG THE CAMERA'S OWN FORWARD.** Under a
	# perspective camera the ray is the only direction that holds a thing's screen position exactly;
	# the forward does it only for something dead centre.
	# ⚠ **This was NOT what the user saw when they said 「약간 회전하니까 이상한거 같은데?」** — measured
	# afterwards, the push moves the rim about one screen pixel either way, and what was actually wrong
	# on that turn was the 이동선 leaving from half a 조각 away. **Written down because the first reading
	# of that sentence was wrong and the next reader should not re-derive it.**
	# ⚠ **Both points in the same space.** `_cam` and every body sprite are children of `_world`, so
	# `position` is what they share; the camera's `global_transform.origin` is a different frame and
	# mixing the two is a ray that means nothing.
	var eye := _cam.position
	var ray := (body.position - eye)
	if ray.length() > Rules.EPS:
		rim.position = body.position + ray.normalized() * Look.PICK_OUTLINE_BACK_TILES
	else:
		rim.position = body.position
	var mat: ShaderMaterial = rim.material_override
	mat.set_shader_parameter("body_tex", pic)
	mat.set_shader_parameter("line_col", Look.COL_PICK_OUTLINE)


## One rim sprite, pooled and hidden but never freed — the same rule `_sprite` keeps.
##
## ⚠ **A `ShaderMaterial` PER SPRITE and not one shared.** The picture goes into the material, and a
## facing or an animation frame is a different picture; one material for all of them would put the
## last body drawn's silhouette around every rim on screen.
func _rim_sprite() -> Sprite3D:
	if _rims_used < _rims.size():
		var reused := _rims[_rims_used]
		_rims_used += 1
		reused.visible = true
		return reused
	var s := Sprite3D.new()
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load(RIM_SHADER)
	s.material_override = mat
	_world.add_child(s)
	_rims.append(s)
	_rims_used += 1
	return s


# --- the health bars -------------------------------------------------------------------------------
## **A bar over a 몸 and a bar over the 성채, and both are the same two pictures** (2026-09-01, the
## user: 「뭔가 HP바가 보여야 상황이 보여야 될 거 같아」 — *"I think an HP bar has to show, the situation
## has to be visible"*). ⚠ **Nothing here is read back by `sim`** — `soldier_hp`, `enemy_hp` and
## `keep_hp` all already existed and already decide who dies.

## **How full a bar is, 0 at dead and 1 at untouched.** ⚠ **Clamped at BOTH ends**: `keep_hp` is
## allowed to go negative for one sub-step before the floor catches it, and a negative fraction is a
## `region_rect` with a negative width, which is a quad the engine draws inside out.
func _hp_frac(now: float, most: float) -> float:
	if most <= 0.0:
		return 1.0
	return clampf(now / most, 0.0, 1.0)


## One bar's pair of sprites, pooled and hidden but never freed — the same rule `_sprite` keeps.
## **The fill is born with its frame**, so the two pools can never come apart by one.
func _bar_sprite() -> Sprite3D:
	if _bars_used < _bars.size():
		var reused := _bars[_bars_used]
		_bars_used += 1
		reused.visible = true
		return reused
	var frame := Sprite3D.new()
	var fill := Sprite3D.new()
	for s: Sprite3D in [frame, fill]:
		s.pixel_size = Look.SPRITE_PIXEL_SIZE
		# ⚠⚠ **FIXED_Y, the same as a body** (개발지식 01 기법 1). Full billboard turns on every axis,
		# so pitching the camera down would lay the bar flat on the ground beside its own body.
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		# ⚠⚠ **DISCARD, AND THE FILL DEPENDS ON IT.** It gives both quads a real depth value, which is
		# what lets `HP_BAR_FILL_FRONT_TILES` decide which of the two is in front — left transparent,
		# the pair would neither write depth nor be sorted against each other and the fill would
		# flicker behind its own trough. ⚠ It is also what hides a bar behind a cliff, like a body.
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Unshaded for the reason a body is: a billboard's normal faces the CAMERA, so the sun hits it
		# square-on at full strength and washes the picture's own colours out.
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		_world.add_child(s)
	frame.visible = true
	_bars.append(frame)
	_bar_fills.append(fill)
	_bars_used += 1
	return frame


## **One bar hanging at `at`, and it is drawn only when `frac` is under 1.** (2026-09-01, the user
## choosing among the recommendations: a full bar over every 몸 and the 성채 would fill the screen from
## the opening frame, when nothing has been hit yet.)
##
## ⚠⚠ **THE FILL IS CROPPED AND THE FRAME IS NOT.** A single loaded picture is a fixed width, so the
## shrinking half is `region_rect` over the fill and nothing else — see `Look.HP_BAR_FRAME` for why the
## two pictures share one centre and therefore need no offset between them.
## ⚠⚠ **`offset` PUTS THE CROP'S LEFT EDGE BACK WHERE THE FULL BAR'S WAS.** A centred sprite with a
## narrowed region shrinks toward its own middle, which reads as a bar closing in from both ends
## instead of draining from the right. The push is half of what the crop took, in TEXTURE px, and the
## sprite's own scale carries it into the world — so it stays right at every zoom for free.
## ⚠ **`offset` and not the position**: the bar is a billboard, so 「left」 has no world axis.
func _put_bar(at: Vector3, frac: float) -> void:
	if _cam == null or _tex_bar_frame == null or _tex_bar_fill == null:
		return
	if frac >= 1.0:
		return
	var frame := _bar_sprite()
	frame.texture = _tex_bar_frame
	frame.scale = _billboard_scale(_tex_bar_frame, Look.HP_BAR_W_PX, Vector2.ONE)
	frame.position = at
	var fill := _bar_fills[_bars_used - 1]
	var wide := float(_tex_bar_fill.get_width()) / float(_tex_bar_frame.get_width())
	# ⚠ **Zero is HIDDEN and not a zero-width region.** A `Rect2` of width 0 is a degenerate quad, and
	# an empty trough is what a dead thing should read as anyway.
	if frac <= 0.0:
		fill.visible = false
		return
	fill.visible = true
	fill.texture = _tex_bar_fill
	fill.scale = _billboard_scale(_tex_bar_fill, Look.HP_BAR_W_PX * wide, Vector2.ONE)
	fill.region_enabled = true
	fill.region_rect = Rect2(0.0, 0.0, float(_tex_bar_fill.get_width()) * frac,
		float(_tex_bar_fill.get_height()))
	fill.offset = Vector2(-float(_tex_bar_fill.get_width()) * (1.0 - frac) * 0.5, 0.0)
	# ⚠⚠ **ALONG THE CAMERA'S OWN AXIS, NEVER THE WORLD'S** — the same rule `_put_outline` keeps, and
	# `basis.z` points back at the viewer, so ADDING it is toward the camera. Pushed along world Z the
	# fill would slide out of its own trough the moment the board turned.
	# ⚠ **`transform` and not `global_transform`**, the frame `_put_pick_outline` already names: the
	# camera and every bar are children of `_world`, so that is the space they share. It is also the
	# one of the two that does not need the node to be inside a tree.
	fill.position = at + _cam.transform.basis.z * Look.HP_BAR_FILL_FRONT_TILES


## **The 성채's bar, and only that one.** A body's bar is put from `_put_walker` instead, because the
## drawn TOP of a body exists in exactly one place — the sprite `_put_body` just finished — and
## `Look.BODY_SPRITE_SCALE` records what re-deriving it off the radius did: the old bar landed across
## the caveman's face the first time he was on screen.
##
## ⚠⚠ **GATED ON `keep_tiles` AND NOT ON `keep_hp`.** A board with no house carries `keep_hp` 0, which
## is a permanently empty bar standing over nothing — the same floor `Battle`'s own burn check uses.
func _paint_bars() -> void:
	if battle == null or battle.keep_tiles.is_empty() or not _keep_roof_known:
		return
	_put_bar(_keep_roof + Vector3(0.0, Look.HP_BAR_KEEP_LIFT_PX / Look.TILE_PX, 0.0),
		_hp_frac(battle.keep_hp, Rules.KEEP_MAX_HP))


# --- the beasts' boats, and the riders standing on them ---------------------------------------------
## **The sim's boat is a flat point and a landing 조각. Everything below is what the eye is given on top
## of that** — the bob, the roll, the hull's yaw and four wolves on the benches. ⚠ **Nothing here is
## read back by `sim`**, which is the whole of the view seam's rule.

## One instantiated `boat_small.glb` per live hull. **Pooled and hidden, never freed**, the same rule
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
## ⚠⚠ **IT TOOK THE STANDING PICTURES ONLY AND THE ANIMATION FRAMES TOOK THE 0.0 FALLBACK**
## (2026-08-31). Every reader is `_foot_body.get(pic, 0.0)`, so a frame that was never measured is
## footed at the bottom of its own canvas while the standing picture beside it is footed at the
## animal — **the body would jump the moment it started walking and drop back when it stopped**, and
## nothing would have gone red. The strips are walked here for that reason and no other.
static func _measure_body_feet(pool: Array, strips: Array) -> Dictionary:
	var out := {}
	for raw_pics in pool:
		for pic: Texture2D in (raw_pics as Array):
			_foot_one(out, pic)
	# `[type][facing][anim][frame]`, which is why this is four deep and not two.
	for raw_type in strips:
		for raw_facing in (raw_type as Array):
			for raw_anim in (raw_facing as Array):
				for pic: Texture2D in (raw_anim as Array):
					_foot_one(out, pic)
	return out


## **How wide each row's animal is inside its own frame, as a fraction, and the widest facing wins.**
##
## ⚠⚠ **ONE NUMBER PER ROW AND NOT ONE PER FACING, AND THE DIFFERENCE IS THE WHOLE ANSWER.** Per
## facing, every facing would be drawn to the same ink width — **a man seen edge-on would be stretched
## to the width of a man seen face-on**, which is the opposite of what four pictures are for. Per row,
## the four keep their proportions to each other and only the frame around them is divided out.
## ⚠ **The standing pictures only.** A strip is exactly the thing that reaches wider than the animal,
## so measuring the frames would let a raised arm shrink the whole body for as long as it was raised.
## ⚠ **1.0 for a row with no picture**, which draws the plain rounded shape and needs no division.
## ⚠ **It reads `cols` and scans nothing itself since 2026-09-02** — the columns are `_measure_ink_cols`'s,
## the same ones `body_at_px` picks by, so the width a body is drawn at and the width it is pressed at
## cannot come from two scans that disagree.
static func _measure_body_ink(pool: Array, cols: Dictionary) -> Array:
	var out := []
	for raw_pics in pool:
		var widest := 0.0
		for pic: Texture2D in (raw_pics as Array):
			if pic == null or not cols.has(pic):
				continue
			var span: Vector2i = cols[pic]
			if span.y >= span.x:
				widest = maxf(widest, float(span.y - span.x + 1) / float(pic.get_width()))
		out.append(widest if widest > 0.0 else 1.0)
	return out


## **Every body picture's opaque columns, `(lo, hi)` inclusive, keyed by the picture** — the standing
## pictures and every strip frame, for the reason `_measure_body_feet` walks the strips: a frame that was
## never measured would be picked by its whole canvas while the standing picture beside it is picked by
## the man, and the pick area would jump the moment he started walking.
static func _measure_ink_cols(pool: Array, strips: Array) -> Dictionary:
	var out := {}
	for raw_pics in pool:
		for pic: Texture2D in (raw_pics as Array):
			_ink_one(out, pic)
	for raw_type in strips:
		for raw_facing in (raw_type as Array):
			for raw_anim in (raw_facing as Array):
				for pic: Texture2D in (raw_anim as Array):
					_ink_one(out, pic)
	return out


## One picture's opaque columns, written into `out` and skipped when it is already there. **A picture
## with no opaque pixel at all spans its whole canvas** — there is nothing narrower to point at.
static func _ink_one(out: Dictionary, pic: Texture2D) -> void:
	if pic == null or out.has(pic):
		return
	var img := pic.get_image()
	if img == null:
		return
	var w := img.get_width()
	var lo := w
	var hi := -1
	for x in w:
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				break
	out[pic] = Vector2i(lo, hi) if hi >= lo else Vector2i(0, w - 1)


## Row `type_id`'s ink fraction, **and never 0** — it is a divisor.
func _ink_of(type_id: int) -> float:
	if type_id < 0 or type_id >= _ink_frac.size():
		return 1.0
	return maxf(float(_ink_frac[type_id]), 0.01)


## One picture's foot, written into `out` and skipped when it is already there.
static func _foot_one(out: Dictionary, pic: Texture2D) -> void:
	if pic == null or out.has(pic):
		return
	var img := pic.get_image()
	if img == null:
		return
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
	# less. But `boat_small.glb` carries no COLOR_0 attribute at all (its six materials hold their own
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


## The name of the node holding one hull's four deck shadows. ⚠ **The hull owns them and there is no
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
##
## ⚠⚠ **A `GONE` HULL TAKES ITS POOL SLOT AND THEN HIDES, AND SKIPPING THE SLOT IS THE DEFECT.** The
## pool is handed out in the order this loop asks for it, so a row that asks for nothing shifts every
## hull after it down one — **the second boat wears the first one's node**, its deck shadows and
## whatever the last frame left on it. Taking the slot and hiding it keeps `_boats[i]` the hull of boat
## `i` for as long as the island lasts, which is the same reason `Battle` never erases a hull row.
func _paint_boats() -> void:
	_boats_used = 0
	if battle == null or battle.grid == null:
		_hide_unused_boats()
		return
	for i in battle.boat_pos.size():
		var hull := _boat()
		if hull == null:
			break
		if int(battle.boat_state[i]) == Battle.BoatState.GONE:
			# **A cut and not a fade** — the user called the disappearance a game-y allowance, so there
			# is nothing to shade. ⚠ The deck shadows are children of the hull and go with it; there is
			# no second list to hide.
			hull.visible = false
			continue
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
## ⚠⚠ **THE MODEL'S BOW IS +X, MEASURED OFF THE FILE AND NOT GUESSED.** `boat_small.glb` runs
## −1.50 .. +1.50 along x against −0.75 .. +0.75 along z, so the long axis is X; and **the sharp end is
## the positive one** — over the last fifth of the hull it is 0.12 조각 wide on the +X side against
## 0.445 on the −X side. **Godot's own convention is −Z forward**, so a yaw written for that convention
## would sail every boat broadside on with every position check still green.
## ⚠ **The hull it arrives on has no named parts** (2026-09-01) — `boat.glb` carried `boat_stem` at
## x = +2.30 and `boat_tail` at x = −2.26, and `net_boats` read those; on one joined mesh what says
## which end is sharp is the width there, and that is what the net reads now.
##
## ⇒ `rotation.y = θ` sends local +X to world `(cos θ, 0, −sin θ)`. A tile-space heading `(hx, hy)` is
## world `(hx, 0, hy)`, so `cos θ = hx` and `−sin θ = hy`, which is `θ = atan2(−hy, hx)`.
func _boat_yaw(head: Vector2) -> float:
	return atan2(-head.y, head.x)


## Four wolves on two benches. **Placed through the hull's own transform**, so the bob and the roll
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
	# ⚠⚠ **THE DECK IS BACK ON THE ISLAND'S OWN WIDTH** (2026-08-31, the user at the sheet: 「why is it
	# so small when it is on the boat? It has to go big on the boat too. Why are the boat and this a
	# different size. The size is the same. On the boat and on the island」). **This is the exact
	# coupling 2026-08-30 broke on purpose**, and the reason it broke is written under
	# `BOAT_RIDER_W_RATIO`: the riders overflowed their benches. ⇒ **If they overflow again, the answer
	# is the bench layout or the hull, not a second size rule** — one animal reading two sizes is what
	# the user is looking at and rejecting.
	var wide := Look.body_radius_of(Rules.WOLF) * Look.BEAST_SPRITE_W_RATIO \
			* Look.BODY_SPRITE_SCALE * Look.beast_draw_scale(Rules.WOLF)
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
		# ⚠⚠ **A `GONE` HULL IS OFF THE BOARD AND `live` CANNOT SAY SO** (2026-09-01, seen on screen:
		# 「사라진 배가 물 위에 자국을 남긴다」). `boat_pos` never shrinks — a row flips to `GONE` and
		# stays — so the count alone still calls a vanished hull live, and this block kept stamping
		# its transom. **Both marks come out of this one array**: the contact shadow reads slot 0 and
		# the trail reads the rest, so the hull disappeared while its black ellipse and its two white
		# lines sat on the water for the rest of the island. Three of them were floating at 178 초.
		# ⚠ **Forgotten whole and not aged out.** The user chose a CUT for the hull (티켓 02-04:
		# 「몇 초 있다가 사라지는 걸로」, cut over fade), and a mark that outlives the thing that made
		# it is the same fiction the cut was chosen to avoid.
		var gone := h < live and int(battle.boat_state[h]) == Battle.BoatState.GONE
		if h >= live or gone:
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

## **Where a body is aiming, or `OFFMAP_AIM` for one aiming at nothing.** `targets` is the other
## side's position column and `here` is the body's own place, which is what the 성채 case needs.
##
## ⚠ **The 성채 answers with its NEAREST 조각 and not its corner.** A body standing against the far
## wall would otherwise face across the building at a point nobody is standing on — the same
## 「a mean is not a place anybody stands」 trap `Battle.keep_gap` records about itself.
func _aim_of(target: int, targets: Array, here: Vector2) -> Vector2:
	if target >= 0:
		if target >= targets.size():
			return OFFMAP_AIM
		return targets[target]
	if target != Battle.TARGET_KEEP or battle == null or battle.grid == null:
		return OFFMAP_AIM
	var best := OFFMAP_AIM
	var best_d := INF
	for raw_tile in battle.keep_tiles:
		var tile := int(raw_tile)
		var at := Vector2(float(tile % battle.grid.w), float(tile / battle.grid.w))
		var d := here.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = at
	return best


## **One blow landing, and everything the six do about it.** `from_px`/`to_px` are in TILES.
##
## ⚠⚠ **BOTH BODIES HOLD, ONLY THE VICTIM FLASHES AND IS KNOCKED.** A striker that flashed would say
## it was hit; a striker that was knocked would be thrown backwards by its own swing.
## ⚠ **Nothing here reads a body's position again.** The shards, the arc and the number are handed
## the two places once and never look them up — rule 2 of the five the deleted effects paid for.
## ⚠ **A blow at the 성채 spawns marks and no victim clocks**, because a building has no body row.
func _land_blow(striker: String, victim: String, from_tiles: Vector2, aim: Vector2,
		type_id: int) -> void:
	if _body.has(striker):
		(_body[striker] as Dictionary)["hold"] = Look.HITSTOP_SEC
	if _body.has(victim):
		var v: Dictionary = _body[victim]
		v["hold"] = Look.HITSTOP_SEC
		v["flash"] = Look.HIT_FLASH_SEC
		v["knock"] = Look.KNOCK_SEC
		var away := aim - from_tiles
		if away.length_squared() > Rules.EPS:
			v["knock_dir"] = away.normalized()
	if aim == OFFMAP_AIM:
		return
	_spawn_marks(Look.tile_point_px(from_tiles), Look.tile_point_px(aim),
		int(round(Rules.damage_of(type_id))))


## **The shards, the arc and the number**, all three born at once and never touched again.
##
## ⚠⚠ **THE SHARDS LEAVE ALONG THE TANGENT, NOT ALONG THE FACING** — see `Look.SPARK_FAN_DEG`. The
## contact point sits INSIDE the striker's outline, so a fan opened along the facing puts every shard
## back inside the animal that threw it.
## ⚠ **Alternating sides, so five shards are three one way and two the other** rather than a fan that
## reads as a single spray.
func _spawn_marks(from_px: Vector2, to_px: Vector2, damage: int) -> void:
	var gap := to_px - from_px
	var dir := gap.normalized() if gap.length_squared() > Rules.EPS else Vector2.RIGHT
	var contact := from_px + gap * 0.5
	var tangent := Vector2(-dir.y, dir.x)
	for i in Look.SPARK_COUNT:
		var spread := (float(i) / maxf(1.0, float(Look.SPARK_COUNT - 1)) - 0.5) \
				* deg_to_rad(Look.SPARK_FAN_DEG)
		var side := tangent if i % 2 == 0 else -tangent
		_live.append({"tex": _tex_tooth, "text": "", "at": contact,
			"vel": side.rotated(spread) * Look.SPARK_SPEED_PX,
			"left": Look.SPARK_SEC, "life": Look.SPARK_SEC, "wide": Look.SPARK_PX,
			"rise": 0.0, "flip": dir.x < 0.0})
	_live.append({"tex": _tex_slash, "text": "", "at": from_px + gap * Look.SLASH_REACH,
		"vel": Vector2.ZERO, "left": Look.SLASH_SEC, "life": Look.SLASH_SEC,
		"wide": Look.SLASH_PX, "rise": 0.0, "flip": dir.x < 0.0})
	if damage > 0:
		_live.append({"tex": null, "text": str(damage), "at": to_px, "vel": Vector2.ZERO,
			"left": Look.DAMAGE_SEC, "life": Look.DAMAGE_SEC, "wide": Look.DAMAGE_FONT_PX,
			"rise": Look.DAMAGE_RISE_PX, "flip": false})


## Ages every mark by a frame and drops what has finished. **Position is integrated, never re-read.**
func _step_marks(delta: float) -> void:
	var kept := []
	for raw in _live:
		var m: Dictionary = raw
		m["left"] = float(m["left"]) - delta
		if float(m["left"]) <= 0.0:
			continue
		m["at"] = (m["at"] as Vector2) + (m["vel"] as Vector2) * delta
		kept.append(m)
	_live = kept


## **Every live mark onto a pooled node.** ⚠ **0 draw calls** — like every other drawer in this file,
## it fills node fields the engine consumes.
## ⚠⚠ **THEY ARE BILLBOARDS AND THEY ARE NOT ROTATED.** A shard lying flat on the ground would be
## drawn under the body that threw it and never seen; a shard rotated on a `BILLBOARD_FIXED_Y` node is
## a rotation the engine throws away when it rebuilds the basis — **measured on this repo's own bodies
## (기법 23) and written up in `Look.BODY_LEAN_DEG`.** The arc is flipped instead of turned.
func _paint_marks() -> void:
	_marks_used = 0
	_labels_used = 0
	for raw in _live:
		var m: Dictionary = raw
		var at: Vector2 = m["at"]
		var fade := clampf(float(m["left"]) / maxf(0.001, float(m["life"])), 0.0, 1.0)
		var lift := (Look.MARK_LIFT_PX + float(m["rise"]) * (1.0 - fade)) / Look.TILE_PX
		var spot := Vector3(at.x / Look.TILE_PX, _stand_h(at / Look.TILE_PX) + lift,
			at.y / Look.TILE_PX)
		var text: String = m["text"]
		if text.is_empty():
			var pic: Texture2D = m["tex"]
			if pic == null:
				continue
			var s := _mark()
			s.texture = pic
			s.flip_h = bool(m["flip"])
			# the same arithmetic `_billboard_scale` does for a body: a Sprite3D drawn at
			# `SPRITE_PIXEL_SIZE` covers `tex_px * scale` world px, so the scale IS the ratio.
			# ⚠ **Dividing by `SPRITE_PIXEL_SIZE` here blew every shard up 40x** — photographed.
			var k := float(m["wide"]) / float(pic.get_width())
			s.scale = Vector3(k, k, 1.0)
			s.modulate = Look.mark_fade(fade)
			s.position = spot
		else:
			var l := _label()
			l.text = text
			l.modulate = Look.damage_fade(fade)
			l.position = spot
	_hide_unused_marks()


## A pooled mark billboard. **Born once and reused**, the same discipline the body pool keeps.
func _mark() -> Sprite3D:
	if _marks_used < _marks.size():
		var reused := _marks[_marks_used]
		_marks_used += 1
		reused.visible = true
		return reused
	var s := Sprite3D.new()
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# ⚠⚠ **NOT `ALPHA_CUT_DISCARD`, WHICH THE BODIES USE.** Discard gives a sprite a real depth value
	# and makes it occlude — and it also throws away every partly transparent pixel, **so a mark that
	# fades would vanish in one step instead of fading.** A mark is allowed to be sorted rather than
	# depth-tested; a body is not.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(s)
	_marks.append(s)
	return s


## A pooled damage number. ⚠ **The font is loaded once, on the first number of the run.**
func _label() -> Label3D:
	if _labels_used < _labels.size():
		var reused := _labels[_labels_used]
		_labels_used += 1
		reused.visible = true
		return reused
	var l := Label3D.new()
	l.pixel_size = Look.SPRITE_PIXEL_SIZE
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.font_size = int(Look.DAMAGE_FONT_PX)
	l.outline_size = int(Look.DAMAGE_OUTLINE_PX)
	l.modulate = Look.COL_DAMAGE
	l.outline_modulate = Look.COL_DAMAGE_EDGE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_digits != null:
		l.font = _font_digits
	_world.add_child(l)
	_labels.append(l)
	return l


## Closes both mark pools by their own index, the way the body pool closes its outlines.
func _hide_unused_marks() -> void:
	for k in range(_marks_used, _marks.size()):
		_marks[k].visible = false
	for k in range(_labels_used, _labels.size()):
		_labels[k].visible = false


## **How far a struck body has been thrown**, in px along the way it was knocked.
##
## ⚠⚠ **THE CURVE PEAKS AT 18% AND EASES BACK OVER THE REST**, and that asymmetry is the whole of why
## this reads as a blow where the deleted lunge read as sliding. See `Look.KNOCK_SNAP`.
func _knock_offset(key: String) -> Vector2:
	if not _body.has(key):
		return Vector2.ZERO
	var b: Dictionary = _body[key]
	var left := float(b["knock"])
	if left <= 0.0:
		return Vector2.ZERO
	var t := clampf(1.0 - left / Look.KNOCK_SEC, 0.0, 1.0)
	var push := sin(PI * pow(t, Look.KNOCK_SNAP))
	return (b["knock_dir"] as Vector2) * (push * Look.KNOCK_RATIO * float(b["half"]))


## Ages every one-shot strip by a frame, then walks every body the SIM knows so the gait advances by
## DISTANCE and so the three events — **공격 · 피격 · 죽음** — are seen at all.
##
## ⚠⚠ **THE SIM HAS NO EVENT LIST AND IS NOT BEING GIVEN ONE.** `battle` carries state: a cooldown,
## a health, an alive flag. **All three events are read here as a CHANGE in that state between two
## frames**, which is what keeps `src/sim/` untouched by a question that is entirely about pictures.
## ⚠ **The cost of that choice is one frame of latency and a seeded first frame** — a body's first
## frame on screen copies the sim's numbers rather than comparing against zero, or every body would
## be born mid-flinch.
##
## Creating the per-body entries is done HERE and nowhere else, and **an entry is never erased**: a
## corpse still needs the position it fell at, and a revived 검사 comes back on the row it left.
func _fx_step(delta: float) -> void:
	for key: String in _body:
		var b: Dictionary = _body[key]
		# ⚠ **Advanced unconditionally, and NOT inside the `moved` test below.** That test is the gait's
		# and it is right there; putting the legs under it is the rule 「움직이지 않는 몸은 애니메이션
		# 하지 않는다」, which is what left a body in melee frozen. This clock never stops.
		# ⚠⚠ **THE HOLD IS AGED FIRST AND ALONE, AND EVERY OTHER CLOCK IS UNDER IT.** That is the
		# whole of 히트스톱: a body in the instant of a blow keeps its picture, its knock and its
		# flash exactly where they are for four frames. **Age one of them anyway and the freeze
		# becomes a stutter** — the picture holds while the body it belongs to keeps sliding.
		b["hold"] = maxf(0.0, float(b["hold"]) - delta)
		if float(b["hold"]) > 0.0:
			continue
		b["walk"] = float(b["walk"]) + delta
		# The three one-shots. ⚠ **A death that reaches 0 takes the body off the screen** — see
		# `_paint_bodies`, which draws a `_body` row the sim no longer lists only while this is above 0.
		b["attack"] = maxf(0.0, float(b["attack"]) - delta)
		b["hurt"] = maxf(0.0, float(b["hurt"]) - delta)
		b["dying"] = maxf(0.0, float(b["dying"]) - delta)
		b["flash"] = maxf(0.0, float(b["flash"]) - delta)
		b["knock"] = maxf(0.0, float(b["knock"]) - delta)

	if battle == null or army == null:
		return

	# ⚠⚠ **EVERY BODY THE SIM KNOWS, DEAD ONES INCLUDED, and that is the whole reason this is not
	# `ashore_ids()` and `living_enemy_ids()` any more.** A death has to be seen as a CHANGE; read off
	# the living lists it is an absence, and an absence is also what a body in reserve looks like.
	# ⚠ **`enemy_pos` is set to OFFMAP the frame a beast dies**, so the position a corpse falls at can
	# only come from what this loop stored last frame — `last`.
	var rows := []
	for i in battle.soldier_state.size():
		# ⚠ **The roster and the army are sized together and this does not trust that.** A row without
		# a type has no picture and no strip lengths, and asking for one faults inside the loop that
		# every body on screen goes through.
		if i >= army.type_id.size():
			break
		var state := int(battle.soldier_state[i])
		# ⚠ **The victim is the one the SWING was thrown at** (`soldier_swing_at`), not this frame's
		# target — the sim locks it at the start of the swing and the blow lands on it 0.4 s later,
		# by which time `soldier_target` may already be the next beast over.
		rows.append(["s%d" % i, state != Battle.SoldierState.DEAD,
			state == Battle.SoldierState.ASHORE, battle.soldier_pos[i],
			float(battle.soldier_hp[i]), float(battle.soldier_cool[i]), int(army.type_id[i]),
			_aim_of(int(battle.soldier_target[i]), battle.enemy_pos, battle.soldier_pos[i]),
			"e%d" % int(battle.soldier_swing_at[i]) if int(battle.soldier_swing_at[i]) >= 0 else "",
			int(battle.soldier_blows[i])])
	for e in battle.enemy_alive.size():
		var living := battle.enemy_alive[e] != 0
		rows.append(["e%d" % e, living, living, battle.enemy_pos[e],
			float(battle.enemy_hp[e]), float(battle.enemy_cool[e]), int(battle.enemy_type[e]),
			_aim_of(int(battle.enemy_target[e]), battle.soldier_pos, battle.enemy_pos[e]),
			"s%d" % int(battle.enemy_swing_at[e]) if int(battle.enemy_swing_at[e]) >= 0 else "",
			int(battle.enemy_blows[e])])

	for raw_row in rows:
		var row: Array = raw_row
		var key: String = row[0]
		var alive: bool = row[1]
		var ashore: bool = row[2]
		var here: Vector2 = row[3]
		var hp: float = row[4]
		var cool: float = row[5]
		var type_id: int = row[6]
		var aim: Vector2 = row[7]
		var victim: String = row[8]
		var blows: int = row[9]
		# ⚠⚠ **THE DRAWN POINT, NOT THE SIM'S, IS WHAT THE LEGS AND THE FACING READ** (2026-09-02). A body
		# that has arrived glides to its seat over half a second (`_seat_glide`) while the sim's point
		# stands still — measured off `here` it read as standing, and BREATHED while it slid. Walking,
		# the glide entry IS the sim's point, so nothing changes there. Last frame's entry (the glide
		# steps after this) — one frame late, and the same frame late every frame.
		var drawn: Vector2 = _seat_glide.get(key, here)
		if not _body.has(key):
			if not ashore:
				continue
			_body[key] = {
				# Seconds left of the swing, the flinch and the fall. **0 is "not in it"**, and it is
				# also what a species with no such strip is pinned at forever.
				"attack": 0.0,
				"hurt": 0.0,
				"dying": 0.0,
				# **히트스톱** — while this is above 0 the body's own clocks do not advance, so its
				# picture holds. ⚠ **The simulation is not frozen**; see `Look.HITSTOP_SEC`.
				"hold": 0.0,
				# **히트 플래시** — seconds left of the wash toward white.
				"flash": 0.0,
				# **넉백** — seconds left, and the way it was thrown. ⚠ **Away from the striker**, which
				# is the whole difference between this and the lunge that was thrown out.
				"knock": 0.0,
				"knock_dir": Vector2.RIGHT,
				# Seconds this body has existed, which is what the walk strip is phased on. ⚠ **The
				# start is scattered by the key's hash**, the same trick `_idle_offset` uses: a pack
				# that steps in lockstep reads as one animal rather than as five. One second covers
				# more than any strip, so every phase is reachable.
				"walk": float(absi(key.hash()) % 1000) / 1000.0,
				"gait": 0.0,
				"head": Vector2.RIGHT,
				"last": drawn,
				# How wide this body is DRAWN, so the knock and the sway are sized off the picture and
				# not off the sim radius. Looked up once — a body's species never changes.
				"half": float(Look.sprite_half_px(type_id)),
				# Seconds since it last moved. **The gait phases on DISTANCE and so stops dead when a
				# body stops; this is what carries the other half.**
				"still": 0.0,
				# ⚠⚠ **THE THREE THINGS AN EVENT IS READ OUT OF, and they are all LAST FRAME'S.** The
				# sim keeps no event list at all — it has state and nothing else — so a swing is a
				# cooldown that went UP, a blow taken is health that went DOWN, and a death is
				# `alive` going false. **Seeded from this frame**, so a body's first frame on screen
				# never reads as three events at once.
				"hp": hp,
				"cool": cool,
				# Blows this body has LANDED, per the sim. **A rise is the blow landing** — the one
				# moment the flash, the shards and the number belong to. Seeded like the three above.
				"blows": blows,
				"alive": alive,
				"type": type_id,
			}
		var b: Dictionary = _body[key]
		if type_id != int(b["type"]):
			b["type"] = type_id
			b["half"] = float(Look.sprite_half_px(type_id))

		# ⚠ **The cooldown is RESET to the whole period the instant a swing STARTS** (`battle`'s attack
		# phase), and it only ever counts down otherwise — so a rise is a swing and there is no other
		# way for it to rise. **Not `> 0`**: a body whose target dies mid-cooldown keeps a positive
		# cooldown for a second without swinging again.
		# ⚠⚠ **THE STRIP STARTS HERE AND THE BLOW LANDS `Rules.SWING_LAND_SEC` LATER** (2026-09-02).
		# Until then the sim dealt the damage on this same sub-step, and everything below — the
		# flash, the shards, the number, the victim's flinch — fired on the FIRST frame of an
		# eight-frame swing, the sword reaching out a third of a second after the bar had dropped.
		if cool > float(b["cool"]) + Rules.EPS:
			b["attack"] = _anim_sec(type_id, Look.Anim.ATTACK)
		# ⚠⚠ **THE WHOLE OF 타격감 HANGS OFF THIS ONE LINE**, and it is on the STRIKER's blow count
		# rather than on the victim's health drop because **this is the only place both ends of a
		# blow are in hand**. The victim's own row knows it lost health; it does not know who took it.
		# `blows` rises only when the sim dealt the damage — a swing that whiffed shows nothing here.
		if blows > int(b.get("blows", blows)):
			_land_blow(key, victim, here, aim, type_id)
		# ⚠ **Health only falls in this game** — there is no heal — so a drop is a blow taken. A
		# revived body comes back at full and that is a RISE, which is why this is one-sided.
		# ⚠⚠ **THE FLINCH NO LONGER CANCELS THE SWING** (2026-09-02). It did — and with the blow
		# landing a third of a second into the swing, a body hit in its wind-up dropped the picture
		# of a blow the sim still landed: damage dealt, no sword seen. `_body_tex` decides which of
		# the two is on top — the swing until its blow has landed, the flinch after.
		if hp < float(b["hp"]) - Rules.EPS:
			b["hurt"] = _anim_sec(type_id, Look.Anim.HURT)
			# ⚠ **The flinch is triggered by health falling and everything else by the blow landing**,
			# the same sub-step. **Health is the honest signal for「I was hurt」** — it is true
			# even for damage nothing swung for, and the day something like that exists this line is
			# already right.
		# ⚠⚠ **The fall starts where the body was standing, not where the sim says it is.** A beast's
		# position is OFFMAP by the time this runs.
		if bool(b["alive"]) and not alive:
			b["dying"] = _anim_sec(type_id, Look.Anim.DEATH)
			b["hurt"] = 0.0
			b["attack"] = 0.0
			b["still"] = 999.0
		# ⚠ **A revived body is a NEW life on an old row.** Without this the next death would not be a
		# change at all and the body would simply vanish.
		if alive and not bool(b["alive"]):
			b["dying"] = 0.0
		b["hp"] = hp
		b["cool"] = cool
		b["blows"] = blows
		b["alive"] = alive

		if not ashore:
			continue
		var last: Vector2 = b["last"]
		var moved := drawn.distance_to(last)
		b["still"] = 0.0 if moved > Rules.EPS else float(b["still"]) + delta
		if moved > Rules.EPS:
			# Positions are in TILES and so is the period, so the two divide directly. Phase on
			# distance is the whole of "it must not slide": a body that does not move does not
			# animate, and no amount of time passing changes that.
			b["gait"] = fposmod(
				float(b["gait"]) + TAU * moved / Look.GAIT_PERIOD_TILES, TAU)
			b["head"] = (drawn - last).normalized()
		elif aim != OFFMAP_AIM:
			# ⚠⚠ **A BODY THAT HAS STOPPED FACES WHAT IT IS HITTING** (2026-08-31). Until this
			# line a body faced the way it last WALKED, and the lunge went that way too — photographed
			# once with a 검사 throwing himself **away from the wolf he was punching**, because he had
			# walked up-left and then turned to fight something down-right.
			# ⚠ **Only while STILL.** A walking body already heads where it is going, and a body
			# that walks one way while facing another is the sliding animal `_facing_of`'s own header
			# was written against.
			var to_aim := aim - drawn
			if to_aim.length_squared() > Rules.EPS:
				b["head"] = to_aim.normalized()
		b["last"] = drawn

## ⚠ **`_drain_events` stood here and it is deleted** (2026-08-29) — see the effects block below.

## The one place a body's drawing offset is computed, so the body and its shadow are handed the same
## number. Split across call sites, one of them is eventually forgotten and the body walks out from
## under its own mark with the whole round green.
##
## ⚠⚠ **THE LUNGE AND THE KNOCK-BACK WERE THE OTHER TWO TERMS AND BOTH ARE DELETED** (2026-08-29) with
## the fight. **The idle sway is not one of them and does not go with them** — 「붙어서 가만히 있으면
## 재미가 죽는다」 — so what is left is the sway alone.
func _body_offset_of(key: String) -> Vector2:
	return _idle_offset(key) + _knock_offset(key) + _swing_offset(key)


## **How far into its own blow a body is, from 0 at the first frame of the strip to 1 at the last.**
## −1 for a body that is not swinging, so a caller can tell 「not swinging」 from 「about to start」.
func _swing_at(key: String) -> float:
	if not _body.has(key):
		return -1.0
	var b: Dictionary = _body[key]
	var left := float(b["attack"])
	if left <= 0.0:
		return -1.0
	var whole := _anim_sec(int(b["type"]), Look.Anim.ATTACK)
	if whole <= 0.0:
		return -1.0
	return clampf(1.0 - left / whole, 0.0, 1.0)


## **Where the body is along its own blow**, in px along the way it is facing.
##
## ⚠⚠ **BACK, THEN OUT, THEN STILL, THEN HOME** — and the asymmetry is the whole of why this reads as
## a blow where 2026-08-31's symmetric lunge read as sliding. See `Look.SWING_WINDUP`.
## ⚠ **Negative during the wind-up on purpose.** A body that only ever moves toward what it is hitting
## has no moment where the blow is *coming*, which is the half the user could not see.
func _swing_offset(key: String) -> Vector2:
	var t := _swing_at(key)
	if t < 0.0:
		return Vector2.ZERO
	var half := float((_body[key] as Dictionary)["half"])
	var reach := 0.0
	var snap_end := Look.SWING_WINDUP + Look.SWING_SNAP
	var hold_end := snap_end + Look.SWING_HOLD
	if t < Look.SWING_WINDUP:
		# easing out, so the pull-back slows as it reaches its furthest point
		reach = -Look.SWING_BACK * sin(PI * 0.5 * (t / Look.SWING_WINDUP))
	elif t < snap_end:
		reach = lerpf(-Look.SWING_BACK, Look.SWING_REACH,
			(t - Look.SWING_WINDUP) / Look.SWING_SNAP)
	elif t < hold_end:
		reach = Look.SWING_REACH
	else:
		reach = Look.SWING_REACH * (1.0 - (t - hold_end) / maxf(0.001, 1.0 - hold_end))
	return _facing_of(key) * (reach * half)


## **The stretch a body takes along the blow while it is snapping and holding.** `(1, 1)` otherwise.
##
## ⚠ **Wide and short, never tall.** A body drawn taller as it strikes reads as jumping; the same
## body drawn wider reads as reaching, which is what a blow is.
func _swing_squash(key: String) -> Vector2:
	var t := _swing_at(key)
	if t < 0.0 or t < Look.SWING_WINDUP:
		return Vector2.ONE
	var hold_end := Look.SWING_WINDUP + Look.SWING_SNAP + Look.SWING_HOLD
	if t >= hold_end:
		return Vector2.ONE
	return Vector2(1.0 + Look.SWING_STRETCH, 1.0 - Look.SWING_STRETCH)


## ⚠⚠ **`_lunge_offset` STOOD HERE FOR ONE AFTERNOON AND THE USER THREW IT OUT** (2026-08-31:
## 「지금 갑자기 왜다 갔다 하는게 있는데 이런거 말고 너무 별로고」 — *"there's this thing going back and forth
## now, not this, it's really bad"*). It pushed the body 8.2 px along its heading for the first 0.18 s
## of a swing and eased it back, sized as a ratio of the drawn half-width.
##
## ⚠⚠ **WHAT IT WAS BUILT FOR IS STILL TRUE AND IS STILL UNSOLVED**: at 20.9 px a wolf's jaws
## opening change its outline by **0 px across four frames**, so the swing does not read from a
## distance. **The lunge was the wrong answer to a real question**, and the user named the right one
## in the same breath — 「아그작 하고 한번」, one hard snap, plus something drawn at the moment of
## contact. **See the reference `2026-08-31-hit-feel-elements`** for the six elements that answer
## it and what each one costs here.
## ⚠ **`Look.BODY_LUNGE_SEC` and `BODY_LUNGE_RATIO` went with it.** A constant left behind is a
## number the next round tunes and nothing reads.
## ⚠ **What did NOT go with it is `_aim_of`** — a still body facing what it is hitting. That was a
## defect this found rather than a part of it: a 검사 was photographed throwing himself **away** from
## the wolf he was punching, because he faced the way he last walked.


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


## One unshaded, vertex-coloured, alpha-blended surface. `priority` is its `render_priority` — the
## ground layer's 1, or `Look.SELECTION_BOX_RENDER_PRIORITY` for the box that has to sort over it.
func _fx_layer(priority: int = 1) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# ⚠⚠ **THIS IS WHAT PUTS A GROUND MARK IN FRONT OF THE 판, AND IT IS SORT ORDER AND NOT DEPTH**
	# (measured 2026-08-31). Both this layer and the 판 are transparent and neither writes depth, so
	# the engine orders them by their AABB — and both AABBs are the whole island, which makes the
	# ordering arbitrary. **The 판 was winning**: the moment a pick lit the board, the bodies' own
	# shadows and the 이동선 both disappeared under it. ⚠ **Raising the marks does nothing** — measured
	# at half a 조각 of lift, still invisible; a priority is the only thing that decides this.
	mat.render_priority = priority
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


## **Lays every 이동선 on the ground**, one per picked body, plus a dot where the 부대 is going.
##
## ⚠ **Nothing here decides where the line goes.** The points arrive from `Hand.route_points` in tile
## units and this converts them to world px and draws — a view that worked its own route out would be
## a second copy of the walking rule, which is the defect shape `how-nets-lie` opens with.
##
## ⚠⚠ **THE LINE STOPS IN THE MIDDLE OF ITS 칸 AND NOT ON THE 조각 THE BODY SEATS IN** (2026-09-02).
## `Hand._seats` hands back the 조각 a body will actually stand in, which is one QUARTER of the aimed
## 칸 — so with the marks one per 칸 the line ended in a corner of the mark it was pointing at, half a
## 칸 away from the middle of the thing the player had aimed at. **Measured on the screen**: the pale
## 칸 spanned x 744..785 and y 299..329 and the round terminator sat at (750, 305), its top-left
## corner. ⚠ **This does not re-derive the route.** Every point but the last is drawn exactly as it
## arrives; only the tail is moved onto the middle of the 칸 that same last point already names, which
## is the one thing the sim's answer and the screen disagreed about.
##
## ⚠ **ONE DOT PER 칸 AND NOT ONE PER BODY.** Nine 이동선 into one 칸 stacked nine discs of alpha 0.92
## on one spot, and `_seats` can spill the surplus into a NEIGHBOURING 칸 — so a second dot appearing
## is the picture telling the truth about a 부대 that is going to two places, not a duplicate.
func _paint_move_lines() -> void:
	if _move_lines.is_empty():
		return
	# ⚠⚠ **THE WIDTH IS DIVIDED BY THE ZOOM AND THAT IS THE WHOLE OF 「자연스럽게」 ON THE WHEEL**
	# (2026-08-31, the user: 「마우스 휠을 내릴 수도 올릴 수도 있는거니까 항상 개발할때 고려해야함 ...
	# 회전 및 확대 축소때」). A ground mark's world size becomes `size * zoom` on screen, so a fixed
	# world width is a hairline pulled back and a stripe pushed in. **This is a mark the hand reads, not
	# a thing in the world** — it holds its width on screen instead.
	# ⚠ **Clamped at both ends.** Past the far bound the line would be wider than the 조각 it crosses;
	# past the near one it would thin back to nothing at a zoom nobody uses.
	var steady: float = clampf(1.0 / maxf(zoom, 0.01), Look.MOVE_LINE_ZOOM_MIN,
		Look.MOVE_LINE_ZOOM_MAX)
	# Where the lines end, one entry per DISTINCT 칸 middle, in the order the 부대 offered them.
	var stops := PackedVector2Array()
	for i in _move_lines.size():
		var pts: PackedVector2Array = _move_lines[i]
		if pts.size() < 2:
			continue
		var stop := _block_middle_tiles(pts[pts.size() - 1])
		if not stops.has(stop):
			stops.append(stop)
		# ⚠ **Only the FIRST point is moved onto the body's DRAWN point.** The rest are 조각 middles and
		# should be — the route is a list of 조각 and the body walks through their centres. A body at
		# rest is drawn on its seat, up to 0.94 조각 from the 조각 centre `Hand.route_points` hands back,
		# and a line leaving the centre would leave from beside nobody's feet.
		# ⚠⚠ **THE GLIDE ENTRY AND NOT THE STAND POINT** (the 03-17 bounce): the stand point is where
		# the body is GOING, and for the half second after it arrives the two differ by the whole seat
		# gap — verify measured the line leading the sprite by up to 1.65 조각. `_advance_seat_glide`
		# has already stepped this frame, so this is the very point the body is about to be drawn at.
		var from := Look.tile_point_px(pts[0])
		if i < _move_ids.size():
			var who := int(_move_ids[i])
			from = Look.tile_point_px(_drawn_of("s%d" % who, pts[0], who, _resting_soldier(who)))
		for k in range(pts.size() - 1):
			# ⚠ **The last leg runs to the 칸's middle**, which is 0.71 조각 from the seat it replaces
			# and always inside that same 칸. **Moving the dot alone was tried on paper and dropped**:
			# the dot's radius is 0.175 조각 at zoom 1 (`MOVE_LINE_END_PX` over `TILE_PX`), so a line
			# still stopping at the seat would break off four of those short of its own terminator.
			var to := Look.tile_point_px(stop if k == pts.size() - 2 else pts[k + 1])
			_g_ribbon(from, to, Look.MOVE_LINE_HALF_PX * steady, Look.COL_MOVE_LINE)
			from = to
	for k in stops.size():
		_g_disc(Look.tile_point_px(stops[k]), Look.MOVE_LINE_END_PX * steady,
			Look.COL_MOVE_LINE_END)


## **The middle of the 칸 a 조각 sits in, in `Hand.route_points`' own units** — corner-anchored, so
## `Look.tile_point_px` turns it into world px exactly as it does for a body or a route point.
##
## ⚠⚠ **IT ASKS THE GRID RATHER THAN DIVIDING BY TWO.** `Grid.block_of`'s low-corner decode has been
## hand-copied three times outside `src/` already and `Grid.tiles_of_block` carries the warning about
## it; a fourth copy in here would be a 칸 middle that can disagree with the 칸 the press commands,
## with nothing going red. **Averaging the 조각 the grid names also gets a truncated 칸 right** — a
## board of odd width hangs its last column of 칸 off the edge, and the middle of the two 조각 that
## exist is where the mark on the ground actually is. ⚠ This island is 30x26, so no 칸 is truncated
## today and that clause is a guard rather than a measurement.
##
## ⚠ **The point handed in has to be a whole 조각.** Every route point but the first is one; the first
## is a real `soldier_pos` and is never passed here.
func _block_middle_tiles(at: Vector2) -> Vector2:
	if battle == null or battle.grid == null:
		return at
	var grid := battle.grid
	var tx := int(at.x)
	var ty := int(at.y)
	if tx < 0 or ty < 0 or tx >= grid.w or ty >= grid.h:
		return at
	var mates := grid.tiles_of_block(grid.block_of(ty * grid.w + tx))
	if mates.is_empty():
		return at
	var sum := Vector2.ZERO
	for k in mates.size():
		var t := int(mates[k])
		sum += Vector2(float(t % grid.w), float(t / grid.w))
	return sum / float(mates.size())


## **One straight run of the line, CUT INTO PIECES along its length.**
##
## ⚠⚠ **THE CUT IS THE WHOLE REASON THIS IS NOT ONE QUAD** — the same reason the header of this
## section already gives for every ground mark. A run crossing a stair drawn as a single quad becomes
## a chord across the slope and half the line ends up inside the hill.
func _g_ribbon(a: Vector2, b: Vector2, half: float, col: Color) -> void:
	var span := b - a
	var len_px := span.length()
	if len_px <= Rules.EPS:
		return
	var side := Vector2(-span.y, span.x) / len_px * half
	var steps := maxi(1, int(ceil(len_px / Look.FX_GROUND_STEP_PX)))
	for k in steps:
		var p0 := a + span * (float(k) / float(steps))
		var p1 := a + span * (float(k + 1) / float(steps))
		_g_tri(p0 - side, p0 + side, p1 + side, col)
		_g_tri(p0 - side, p1 + side, p1 - side, col)


# --- the selection box: a shape on the ground under the dragged rect ---------------------------------
## ⚠⚠ **THE BOX IS LAID ON THE TERRAIN, NOT DRAWN ON THE GLASS** (2026-09-02, ticket 03-12 rebuilt on
## the user's verdict — the picture-on-the-HUD build was not the candidate they chose: 「이게 일단 4번이
## 적용된게 맞음? 이게 아니였는데」 — *"was number 4 applied? this was not it."*, then 「선말고 선택된 부분을
## 약간 드래그 영역 안쪽 색상이 보여야함」 — *"not the line — the inside of the drag region should show a
## colour."*). The shell hands over the screen rect it is dragging; every `Look.SELECTION_BOX_STEP_PX`
## across it a screen point is thrown through `screen_to_terrain_px` — the same near-to-far walk a press
## goes through — and the hits become a tinted grid on the ground with a thin ribbon around its border.
## **Where the rect crosses the foot of the 2층 the hits jump to its top and the tint climbs the face
## with them; when the board turns the shape turns with the ground it was laid on.** That is the whole
## of what the candidate was for.
##
## ⚠ **Its own mesh, not the per-frame decal buffer.** `_g_tri` writes into `_g_v`, which `_fx_begin`
## clears every frame — a box there would cost its projections sixty times a second whether or not
## anything moved. This mesh is rebuilt **at most once a frame, in `_process`**, and only when the rect
## changed since the last build (`set_box` marks it) or the camera did (`_box_cam_key`).
##
## ⚠⚠ **IT WAS REBUILT ON EVERY MOUSE MOTION AND THE USER FELT IT** (2026-09-02: 「렉이 겁나걸리네
## 드래그좀 한다고?」 — *"it lags like crazy — just from dragging?"*). Three things were wrong at once,
## measured headless on the real island at the opening camera: **`set_box` rebuilt at once**, so a
## frame with several motion events paid several rebuilds; **every sample went through the 48-rung
## press walk** at 112 µs a point; and **the 8 px step was unbounded**, so a rect across the glass was
## 14,651 samples. A 220 x 100 rect cost **58.3 ms** a rebuild and a full-glass rect **1,731 ms**.
## ⇒ The rebuild is coalesced into `_process`; a sample is the same walk cut into ONE segment
## (`_box_hit`); and the step grows past 8 px so the grid is never more than
## `Look.SELECTION_BOX_MAX_CELLS` across. **After**: the numbers `_rebuild_box` carries.
##
## ⚠ **Two surfaces in one `ImmediateMesh`, fill first**: surface 0 is the tint, surface 1 the ribbon,
## so the edge is drawn over the area. Both are read by `net_fx_view` — buffers prove geometry was built,
## the surface count proves it was committed, and the two together are the seam `GLOSSARY.md` names.

## **The box in screen px, as the shell last handed it over.** Up when its size is not zero; the shell
## only ever hands a rect past the drag threshold or `Rect2()`.
var _box := Rect2()
var _box_mesh: MeshInstance3D = null
## **The border hits in world 조각, clockwise from the rect's top-left, closed** — what the ribbon was
## laid along. Kept so a net can unproject them through the same camera and find them inside the rect.
var _box_hits := PackedVector3Array()
## The four camera fields the mesh was last built against — see `_box_cam_key`. Empty until built.
var _box_cam := []
## **The rect changed since the mesh was last built.** Set by `set_box`, spent by `_rebuild_box`; the
## frame's `_process` is the one reader.
var _box_dirty := false
## **How many times the mesh has been rebuilt since the view was made.** Read by nothing in the game —
## it is the counter `net_fx_view` reads to prove three rects in one frame are one rebuild, because a
## surface count cannot tell one rebuild from three.
var _box_rebuilds := 0
var _b_v := PackedVector3Array()
var _b_c := PackedColorArray()


## **The shell says where the box is, or that there is none.** Stores the rect and marks it — the
## rebuild is `_process`'s, once a frame, so the motion branch may hand over a rect on every mouse
## event and the frame pays for the last one only. Returns on no change so a repeated rect does not
## even mark.
func set_box(rect: Rect2) -> void:
	if rect == _box:
		return
	_box = rect
	_box_dirty = true


## The four fields every screen-to-ground conversion reads. ⚠ **These and not `_cam.transform`**:
## `screen_to_terrain_px` is pure over them, and `_place_camera` only ever writes the engine's camera
## FROM them, so a change to any of the four is exactly 「the ground under the glass moved」.
func _box_cam_key() -> Array:
	return [cam_px, zoom, cam_yaw_deg, cam_pitch_deg]


## Where one screen px meets the landscape, in world 조각, lifted off the ground like every other mark.
##
## **The press's own walk, cut into one segment instead of 48.** The near-to-far rule is the whole of
## why a press is a walk (see `screen_to_terrain_px`), and the box needs the same rule — a sample
## answered by 「take the sea-level point, read its height, ask again」 settles on the hidden land behind
## a 2층 cliff, which is the defect that header measured at 60 of 180 조각. **So the box does not take
## the cheap way; it takes the exact way with the rungs removed.** Measured 2026-09-02 on 625 screen
## points over the real island at the opening camera: one segment and 48 rungs answer **within 0.00012
## world px** of each other, at **~7 µs** a point against **~112 µs**. ⚠ There is no cliff-edge error
## to state, because there is no approximation.
func _box_hit(at: Vector2) -> Vector3:
	var w := screen_to_terrain_px(at, 1)
	return Vector3(w.x / Look.TILE_PX, _ground_y_px(w), w.y / Look.TILE_PX)


## Rebuilds both surfaces from the current rect and camera. An empty rect leaves the mesh with no
## surfaces — ⚠ an `ImmediateMesh` surface with zero vertices is an error, so nothing is begun for it.
##
## **What one rebuild costs** (measured headless 2026-09-02 on the real island at the opening camera,
## after the three fixes the section header names): **220 x 100 → 2.7 ms · 1280 x 720 → 3.2 ms**, from
## 58.3 and 1,731. `net_fx_view`'s timing row prints the same two rebuilds on its arena every round.
## ⚠ **The 0.3 ms and 2 ms the two were asked to come under are NOT met, and the floor is measured**: a
## sample is ~6 µs (two `screen_to_world_px` at 1.2 µs and a one-segment walk over some six 조각 at
## 0.65 µs each) and a vertex ~0.17 µs, in GDScript. A 220 x 100 rect is 253 samples at the 10 px step
## the bound gives it, so 1.5 ms before a vertex is laid. **Fewer samples is the only lever left**, and
## that is `Look.SELECTION_BOX_STEP_PX` and `Look.SELECTION_BOX_MAX_CELLS` — a tuning, not a rebuild.
func _rebuild_box() -> void:
	_box_dirty = false
	_box_rebuilds += 1
	_box_hits = PackedVector3Array()
	_box_cam = _box_cam_key()
	if _box_mesh == null:
		return
	var im: ImmediateMesh = _box_mesh.mesh
	im.clear_surfaces()
	if _box.size == Vector2.ZERO:
		return
	# The grid of hits: `nx` x `ny` cells, `(nx + 1) x (ny + 1)` corners, row-major from the top-left.
	# **The step is the finest one until the rect's longer side would take more than
	# `SELECTION_BOX_MAX_CELLS` of it**, and grows with the rect from there — see that constant.
	# ⚠ At least one cell on each axis, so the 6 px first box (0 px on one axis) still builds — its
	# cells are zero-area and its ribbon is a stroke, which is what a 6 x 0 drag looks like.
	var step := maxf(Look.SELECTION_BOX_STEP_PX,
		ceil(maxf(_box.size.x, _box.size.y) / float(Look.SELECTION_BOX_MAX_CELLS)))
	var nx := maxi(1, int(ceil(_box.size.x / step)))
	var ny := maxi(1, int(ceil(_box.size.y / step)))
	var hits := PackedVector3Array()
	hits.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			var at := _box.position + Vector2(_box.size.x * float(i) / float(nx),
				_box.size.y * float(j) / float(ny))
			hits[j * (nx + 1) + i] = _box_hit(at)

	# Surface 0 — the tint: two triangles per cell, every corner at the height under it.
	var fill := Look.COL_SELECTION_BOX
	fill.a = Look.SELECTION_BOX_FILL_ALPHA
	_b_v.clear()
	_b_c.clear()
	for j in ny:
		for i in nx:
			var a: Vector3 = hits[j * (nx + 1) + i]
			var b: Vector3 = hits[j * (nx + 1) + i + 1]
			var c: Vector3 = hits[(j + 1) * (nx + 1) + i + 1]
			var d: Vector3 = hits[(j + 1) * (nx + 1) + i]
			_box_tri(a, b, c, fill)
			_box_tri(a, c, d, fill)
	_box_commit(im)

	# Surface 1 — the ribbon along the grid's own border, clockwise from the top-left and closed.
	for i in nx:
		_box_hits.append(hits[i])
	for j in ny:
		_box_hits.append(hits[j * (nx + 1) + nx])
	for i in nx:
		_box_hits.append(hits[ny * (nx + 1) + nx - i])
	for j in ny:
		_box_hits.append(hits[(ny - j) * (nx + 1)])
	var line := Look.COL_SELECTION_BOX
	var n := _box_hits.size()
	for k in n:
		_box_ribbon(_box_hits[k], _box_hits[(k + 1) % n], line)
	# Square caps on the four corners hide the notch a 90° bend leaves on its outside.
	for corner in [hits[0], hits[nx], hits[ny * (nx + 1) + nx], hits[ny * (nx + 1)]]:
		_box_cap(corner, line)
	_box_commit(im)


## One surface from the buffer, then the buffer is spent. Nothing is begun for an empty buffer.
func _box_commit(im: ImmediateMesh) -> void:
	if _b_v.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _b_v.size():
		im.surface_set_color(_b_c[k])
		im.surface_add_vertex(_b_v[k])
	im.surface_end()
	_b_v.clear()
	_b_c.clear()


## Three appends written out rather than a `for p in [a, b, c]`: the array that loop builds is an
## allocation per triangle, and a full-glass box is 800 of them a rebuild.
func _box_tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_b_v.append(a)
	_b_v.append(b)
	_b_v.append(c)
	_b_c.append(col)
	_b_c.append(col)
	_b_c.append(col)


## One thin quad from `a` to `b`, its width perpendicular to the run in the ground plane — so a piece
## that climbs a face still shows its face to the camera above. A purely vertical piece (straight up a
## face) has no run to be perpendicular to and is widened across screen-right on the ground instead.
func _box_ribbon(a: Vector3, b: Vector3, col: Color) -> void:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var len_w := flat.length()
	var side: Vector3
	if len_w <= Rules.EPS:
		var r := _ground_right() * Look.SELECTION_BOX_HALF_W_TILES
		side = Vector3(r.x, 0.0, r.y)
	else:
		var s := Vector2(-flat.y, flat.x) / len_w * Look.SELECTION_BOX_HALF_W_TILES
		side = Vector3(s.x, 0.0, s.y)
	_box_tri(a - side, a + side, b + side, col)
	_box_tri(a - side, b + side, b - side, col)


## A square lying on the ground at `p`, a half-width to each side.
func _box_cap(p: Vector3, col: Color) -> void:
	var x := Vector3(Look.SELECTION_BOX_HALF_W_TILES, 0.0, 0.0)
	var z := Vector3(0.0, 0.0, Look.SELECTION_BOX_HALF_W_TILES)
	_box_tri(p - x - z, p + x - z, p + x + z, col)
	_box_tri(p - x - z, p + x + z, p - x + z, col)
