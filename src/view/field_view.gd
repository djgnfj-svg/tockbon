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
## **What is not here yet** (they were 210 of the checks that died, and they are the next step):
## the summon aim ring and its route, target lines, area and landing rings, hit halos, tracers,
## sparks, death bursts, the beak, and the refusal mark. `_fx_step` and `_drain_events` below still
## run and still fill `_fx` every frame — **the effects are being simulated, nobody is drawing them.**
## That is stated here rather than left to be discovered from a quiet screen.


## Kept because `_rounded_square` is gone but the baked picture wants the same corner it drew.
const CORNER_SEGMENTS := 6

const WATER_SHADER := "res://src/view/water.gdshader"


# --- what it reads, and never writes ---------------------------------------------------------------

var battle: Battle = null
var army: Army = null
var rows: Array = []


# --- its own clock. Unchanged by the move: an effect ages in seconds whatever draws it -------------

var _fx: Array = []
var _body: Dictionary = {}
var _shake_amp := 0.0
var _shake_left := 0.0


# --- the camera ------------------------------------------------------------------------------------

## World px of the visible ground's top-left corner, exactly as before the move.
var cam_px := Vector2.ZERO
var zoom := 1.0
## ⚠ **The new axis, and the only piece of state this move added.** 0 is the view the flat board
## always had. **Nothing turns it yet** — what turns it, and whether a hand is allowed to during a
## fight, is 티켓 07, which is open precisely because turning IS the hand moving.
var cam_yaw_deg := Look.CAM_YAW_DEG


# --- pictures ---------------------------------------------------------------------------------------

var _tex_wolf_r: Texture2D = load(Look.BEAST_WOLF_R)
var _tex_wolf_l: Texture2D = load(Look.BEAST_WOLF_L)
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

	# The fill. See `FILL_ENERGY`: it casts nothing, so it costs one more pass over the shaded faces and
	# nothing else.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(Look.FILL_PITCH_DEG, Look.FILL_YAW_DEG, 0.0)
	fill.light_energy = Look.FILL_ENERGY
	fill.shadow_enabled = false
	_world.add_child(fill)

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
	_world.add_child(_cam)
	_place_camera()


## A white rounded-square OUTLINE with a white centre dot and nothing in between — the two marks
## `_paint_body` used to draw with `draw_polyline` and `draw_circle`. White, so the one modulate on the
## sprite carries the body's own colour; baked, because a billboard wears a picture and cannot be
## handed a polyline.
func _make_body_tex() -> Texture2D:
	var n := Look.BODY_TEX_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
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
				img.set_pixel(x, y, Color.WHITE)
			elif p.length() <= float(Look.BODY_TEX_DOT_PX):
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _make_flat_tex() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
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
	_shake_amp = 0.0
	_shake_left = 0.0
	# A slot armed on island 1 must not survive onto island 2, and the tile index it was aiming at
	# would name a different piece of water there.
	_summon_slot = -1
	_summon_aim = -1
	_wait_clock = 0.0
	# The survey: an island opens zoomed all the way out, so the WHOLE island is on screen before
	# anything is planned — `plan-then-watch` 6.3, on the user's 「조금 더 카메라를 뒤로 빼야 될」.
	zoom = Look.ZOOM_MIN
	cam_px = Vector2.ZERO
	cam_yaw_deg = Look.CAM_YAW_DEG
	_clamp_cam()
	# ⚠ **Forces a terrain rebuild even when the same island re-opens.** `_built_for` is a fingerprint
	# of the rows, and re-entering island 0 from the map would otherwise keep the mesh from the last
	# time — which is right for the boxes and wrong for the band, because the plan has been reset.
	_built_for = ""
	_build_world()
	_rebuild_terrain()
	_place_camera()


## The sim moves every frame and the picture has to follow it.
##
## **The order is load-bearing and it is the order it always was.** Ageing first and draining second
## means an effect born this frame is at full amplitude on the frame it was born, so the flinch really
## does reach `HIT_KNOCK_PX` once and the shake really does reach its peak once.
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
	_paint_bodies()


# --- the camera: still one transform, still in one place -------------------------------------------

## How much GROUND, in world px, the viewport covers at this zoom.
##
## ⚠⚠ **The two axes no longer share a divisor and that is the whole of what tilting cost.** A screen
## px across is a ground px across; a screen px DOWN is `1 / cos(pitch)` ground px, because the ground
## is leaning away. Written once, here, and both conversions below read it — computed at each call
## site instead, the two would drift and the drift would look like a mis-aimed click.
func _visible_ground_px() -> Vector2:
	var v := Look.viewport_size_px() / zoom
	return Vector2(v.x, v.y / cos(deg_to_rad(Look.CAM_PITCH_DEG)))


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


## A screen (viewport) px back to a ground point in world px. **The one conversion every click goes
## through**, the same promise the flat board's `(at - position) / zoom` made.
##
## ⚠ At yaw 0 and pitch 0 this IS that expression. The pitch divides the vertical, the yaw turns the
## two axes, and nothing else about it moved.
func screen_to_world_px(at: Vector2) -> Vector2:
	var span := _visible_ground_px()
	var u := at.x / Look.VIEWPORT_W_PX - 0.5
	var v := at.y / Look.VIEWPORT_H_PX - 0.5
	return _ground_centre_px() + _ground_right() * (u * span.x) + _ground_down() * (v * span.y)


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / Look.TILE_PX)), int(floor(world.y / Look.TILE_PX)))


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


## Points the real camera at what `cam_px` / `zoom` / `cam_yaw_deg` describe. **The one place any of
## those three reach the engine**, the same rule `_compose_position` used to keep for `position`.
func _place_camera() -> void:
	if _cam == null:
		return
	var pitch := deg_to_rad(Look.CAM_PITCH_DEG)
	var yaw := deg_to_rad(cam_yaw_deg)
	# The shake was an offset on a canvas; it is an offset on the ground now, in the screen's own two
	# axes so a shake still reads as the screen jerking rather than as the island sliding.
	var shake := _shake_offset()
	var centre := _ground_centre_px() + _ground_right() * shake.x + _ground_down() * shake.y
	var target := Vector3(centre.x / Look.TILE_PX, 0.0, centre.y / Look.TILE_PX)
	var back := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	_cam.size = _visible_ground_px().x / Look.TILE_PX
	_cam.look_at_from_position(target + back * Look.CAM_DIST_TILES, target, Vector3.UP)


# --- the island, as a landscape ----------------------------------------------------------------------
## ⚠⚠ **This was 5120 boxes in a `MultiMesh` for one afternoon and the user judged it: 「너무 딱딱해서
## 재미가 없을까?」.** A box per tile gives the ground a HEIGHT and no SHAPE — every rise is a step and
## every ramp is a stair. It is one mesh now, built from the same legend, with tile corners JOINED, so
## a rise is a slope and a ramp really is diagonal.
##
## **What joins and what does not** is the whole design of this pass. A corner is averaged only across
## tiles of the same KIND: land with land, water with water. Where two kinds meet, the corner stays put
## on each side and a skirt drops from the higher one — which is what keeps a cliff a wall rather than
## a helpful ramp up it, and what keeps the coast an edge instead of a beach that slides into the sea.
##
## ⚠ **Colours stay per tile even though heights are shared.** Every tile owns its own vertices, so the
## corner it shares with its neighbour is at the same HEIGHT (no crack) and its own COLOUR (no smear).
## Averaging colour as well would turn the legend into a gradient, and the legend is how the player
## reads what is walkable.
##
## ⚠ **Flat shading, deliberately.** Every facet keeps its own plane, so a slope reads as a slope and a
## step reads as a step. Smoothed normals would round the two into each other and the ground would stop
## saying which of them it is.

enum Kind { WATER, HOLE, CLIFF, RAMP, LAND }


## The kind a legend character belongs to. **Not the colour and not the height** — it is the question
## "does this join to that", and it is the only thing the joining rule reads.
##
## ⚠ **The ramp is its own kind now** (2026-08-24, the user: 「경사로 가능함?」). It used to fall through
## to LAND, which joined it to the field below and walled it off from the cliff above — **a doorway
## through a cliff drawn as a step.** It is the one character whose whole job is to be a slope.
func _kind_of(ch: String) -> int:
	match ch:
		"~":
			return Kind.WATER
		"H":
			return Kind.WATER
		"#":
			return Kind.HOLE
		"^":
			return Kind.CLIFF
		"/":
			return Kind.RAMP
		_:
			return Kind.LAND


## **Whether two kinds share a corner — the whole shape of the island is in this one function.**
##
## | pair | joins | what that draws |
## |---|---|---|
## | land / land | yes | the rolling hills |
## | land / water | **yes** | **a shore that shelves into the sea instead of a wall around the island** |
## | land / ramp, ramp / cliff | **yes** | **a real diagonal from the field up through the cliff wall** |
## | cliff / cliff | yes | a ridge that undulates instead of a row of identical blocks |
## | anything / hole | no | a pit stays a pit |
## | cliff / land, cliff / water | no | **the wall stays a wall** |
##
## ⚠⚠ **`land / water` joining is what makes the coast look like a coast**, and it is the one row that
## trades something away: the shoreline is no longer a hard edge, so where exactly the water starts is
## read off the COLOUR rather than off a cliff. That is the right trade — the legend was always what
## said where you can walk, and a wall around an entire island is not what an island looks like.
##
## ⚠ **`cliff / land` deliberately does NOT join**, or every cliff would grow a helpful ramp up it on
## all four sides and the one character whose job is to be that ramp would mean nothing.
func _joins(a: int, b: int) -> bool:
	if a == b:
		return a != Kind.HOLE
	if a == Kind.HOLE or b == Kind.HOLE:
		return false
	if a == Kind.RAMP or b == Kind.RAMP:
		var other := b if a == Kind.RAMP else a
		return other == Kind.LAND or other == Kind.CLIFF
	if a == Kind.CLIFF or b == Kind.CLIFF:
		return false
	return true


## The legend character at a tile, with everything off the island reading as open water — the same
## fallback the colour lookup makes, made in one place so the two cannot disagree about where the
## island ends.
func _char_at(tx: int, ty: int) -> String:
	if ty < 0 or ty >= rows.size():
		return "~"
	var row: String = String(rows[ty])
	if tx < 0 or tx >= row.length():
		return "~"
	return row[tx]


## Smooth value noise, deterministic, in `[0, 1]`. **Written out rather than pulled from
## `FastNoiseLite`** for one reason: this has to give the same island on every machine and every run,
## and that reproducibility is the point (see `HILL_SEED`).
func _noise_at(x: float, y: float, cell: float) -> float:
	var fx := x / cell
	var fy := y / cell
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	# Smoothstep on both axes, so the value has no creases along the lattice — a linear blend leaves a
	# visible fold down every cell boundary and the land reads as folded paper.
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var a := _hash_at(ix, iy)
	var b := _hash_at(ix + 1, iy)
	var c := _hash_at(ix, iy + 1)
	var d := _hash_at(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


func _hash_at(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263 + Look.HILL_SEED
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


## How high a tile stands: its legend height, plus the swell if it is land. **Two octaves**, the second
## finer and smaller, so a hillside has a shoulder instead of being one clean dome.
func _tile_h(tx: int, ty: int) -> float:
	var ch := _char_at(tx, ty)
	var base := Look.terrain_height_of_char(ch)
	var kind := _kind_of(ch)
	if kind == Kind.LAND or kind == Kind.RAMP:
		return base + _swell_at(tx, ty) * Look.HILL_AMP_TILES
	# A cliff takes a fraction of the same swell, so a ridge is a ridge and not a row of identical
	# blocks. It reads the SAME noise as the land under it, so the ridge follows the ground it stands on.
	if kind == Kind.CLIFF:
		return base + _swell_at(tx, ty) * Look.HILL_AMP_TILES * Look.HILL_CLIFF_RATIO
	return base


## How far up the swell this tile sits, in `[0, 1]`. **Two octaves**, the second finer and smaller, so
## a hillside has a shoulder instead of being one clean dome.
##
## ⚠ **The height and the colour read the SAME number.** Computing the tint from its own noise would
## put the light patch next to the hill instead of on it, and nothing on screen would say so.
func _swell_at(tx: int, ty: int) -> float:
	var big := _noise_at(float(tx), float(ty), Look.HILL_CELL_TILES)
	var fine := _noise_at(float(tx), float(ty), Look.HILL_CELL_TILES * Look.HILL_DETAIL_RATIO)
	return big * (1.0 - Look.HILL_DETAIL_RATIO) + fine * Look.HILL_DETAIL_RATIO


## The height of one corner of one tile. `dx`/`dy` are 0 or 1 and name which corner.
##
## ⚠⚠ **The join happens here and nowhere else.** The four tiles touching this corner are averaged, but
## only the ones of the SAME kind — so two land tiles meet smoothly while land meeting water does not
## drag the coast down into the sea. A tile always counts itself, so the average is never empty.
func _corner_h(tx: int, ty: int, dx: int, dy: int) -> float:
	var kind := _kind_of(_char_at(tx, ty))
	var sum := 0.0
	var n := 0
	for oy in [dy - 1, dy]:
		for ox in [dx - 1, dx]:
			if not _joins(kind, _kind_of(_char_at(tx + ox, ty + oy))):
				continue
			sum += _tile_h(tx + ox, ty + oy)
			n += 1
	if n == 0:
		return _tile_h(tx, ty)
	return sum / float(n)


## What a body standing on this tile stands ON: the middle of its four corners, so a wolf on a hillside
## is at the height of the ground under it rather than at the height the legend would give a box.
func _ground_h(tx: int, ty: int) -> float:
	return (_corner_h(tx, ty, 0, 0) + _corner_h(tx, ty, 1, 0)
		+ _corner_h(tx, ty, 0, 1) + _corner_h(tx, ty, 1, 1)) * 0.25


## Whether any of the four tiles orthogonally next to this one is open water. **Four and not eight**:
## a diagonal touch is a corner, and colouring a tile that only meets the sea at one point puts sand
## where the eye sees none.
func _touches_water(tx: int, ty: int) -> bool:
	for d in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
		if _kind_of(_char_at(tx + int(d[0]), ty + int(d[1]))) == Kind.WATER:
			return true
	return false


## Whether the summonable band is showing: before the commit, and never after it.
##
## ⚠⚠ **It goes with the slot boxes at the commit.** After the commit `Battle.summon` refuses
## everything and `hud_view` stops drawing the slots, so a sea still wearing "your hand goes here"
## would be the only mark on the field that lies. Measured on the flat board: adding this test ran the
## whole round green, which is why `net_slots` reads the band's tile count on both sides of `commit()`.
func _band_on() -> bool:
	return battle != null and not battle.committed()


## The colour a tile is painted, band and all. The band is a BLEND into the tile's own colour and never
## a second surface on top of it: a second surface costs a depth fight, and a blend is what a check
## reads as two fills being different.
## ⚠⚠ **The `band` argument is gone and so is the green wash it painted** (2026-08-24, the user:
## 「초록색이 있을 필요는 없다」). Where a boat may be put down is a RING on the water now, drawn by
## `_rebuild_ring`, and the rule behind it became a circle to match (`Rules.SUMMON_RADIUS_TILES`).
## ⇒ **Nothing about a tile's colour depends on the plan any more**, which is also why the terrain mesh
## no longer has to be rebuilt at the commit.
func _tile_colour(tx: int, ty: int) -> Color:
	var ch := _char_at(tx, ty)
	var col := Look.terrain_colour_of_char(ch)
	# High ground drifts lighter. See `COL_LAND_HIGH`: from 40 degrees at `ZOOM_MIN` this is what makes
	# a hill a hill, and the geometry alone is not.
	if _kind_of(ch) == Kind.LAND:
		col = col.lerp(Look.COL_LAND_HIGH, _swell_at(tx, ty))
		# ...and land that touches the sea takes the shore's tone on top of that. Applied AFTER the
		# height tint so a high headland still reads as a coast rather than as a bright inland field.
		if _touches_water(tx, ty):
			col = col.lerp(Look.COL_SHORE, Look.SHORE_BLEND)
	return col


## One mesh for the whole island, `WATER_MARGIN_TILES` wider than the grid on every side so no zoom
## shows bare background at its edge.
##
## ⚠ **Built once per island and once more at the commit**, never per frame — it is tens of thousands
## of triangles, and the only thing about it that changes mid-island is the band.
func _rebuild_terrain() -> void:
	if _terrain == null:
		return
	var tiles := _map_tiles()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# -1 is "no smoothing group": every triangle keeps its own normal. See the header.
	st.set_smooth_group(-1)

	# ⚠⚠ **Water is not in this mesh at all, and the margin ring is gone with it.** The sea is one
	# shaded quad under everything (`water.gdshader`), so a water tile here would be a second flat
	# surface fighting it for the same pixels — which is exactly what it was, and it is what made the
	# sea draw as stripes. Skipping them also cuts the mesh to the island itself: on the shipped maps
	# that is 1536 tiles instead of 5120, with the water half of those gone too.
	# ⚠ A hole (`#`) is NOT water and stays: it is a pit in the land, and the sea showing through one
	# would say it can be sailed.
	for ty in range(tiles.y):
		for tx in range(tiles.x):
			if _kind_of(_char_at(tx, ty)) == Kind.WATER:
				continue
			var col := _tile_colour(tx, ty)
			var h00 := _corner_h(tx, ty, 0, 0)
			var h10 := _corner_h(tx, ty, 1, 0)
			var h01 := _corner_h(tx, ty, 0, 1)
			var h11 := _corner_h(tx, ty, 1, 1)
			var x0 := float(tx)
			var z0 := float(ty)
			var a := Vector3(x0, h00, z0)
			var b := Vector3(x0 + 1.0, h10, z0)
			var c := Vector3(x0 + 1.0, h11, z0 + 1.0)
			var d := Vector3(x0, h01, z0 + 1.0)
			_quad(st, col, a, b, c, d)

			# The four skirts. **A skirt is what a box's side used to be**, and it is emitted only
			# where the neighbour is genuinely lower — a slope that already meets its neighbour needs
			# no wall, and emitting one anyway would put a hairline seam down every hillside.
			_skirt(st, col, tx, ty, 0, -1, a, b)
			_skirt(st, col, tx, ty, 0, 1, c, d)
			_skirt(st, col, tx, ty, -1, 0, d, a)
			_skirt(st, col, tx, ty, 1, 0, b, c)

	st.generate_normals()
	_terrain.mesh = st.commit()
	# The sea sits at the water's own surface height, so it and the margin tiles are one flat plane
	# rather than two at a hairline apart.
	_sea.position = Vector3(float(tiles.x) * 0.5,
		Look.TERRAIN_H_WATER - Look.SEA_DROP_TILES, float(tiles.y) * 0.5)
	_rebuild_ring()
	_terrain.material_override = _terrain_material()
	_built_for = "%dx%d:%d" % [tiles.x, tiles.y, rows.size()]


## The ring on the water: **the outer edge of where a boat may be put down, drawn as the circle it now
## is.**
##
## ⚠⚠ **The centre and the radius are read off the SIM, never chosen here.** `Grid.summon_centre()` and
## `Grid.summon_radius()` are the same two numbers `can_summon_at` tests against, so the drawn
## circle cannot promise a tile the sim then refuses. That guarantee used to belong to the green wash
## (which asked `can_summon_at` per tile); it belongs to these two lines now, and it is the reason the
## wash could be deleted rather than merely restyled.
##
## ⚠ **It says nothing about the INNER edge.** A boat still has to be `SUMMON_BAND_MIN_TILES` off the
## shore, and that bound is a distance from the coast rather than from the middle — it is not a circle
## and it cannot be drawn as one. **Not drawn at all today**, and written down here as missing rather
## than left to be discovered by pressing just off a beach and being refused.
func _rebuild_ring() -> void:
	if _ring == null or battle == null or battle.grid == null:
		return
	var centre := battle.grid.summon_centre()
	var r := battle.grid.summon_radius()
	var half := Look.SUMMON_RING_W_TILES * 0.5
	var y := Look.TERRAIN_H_WATER + Look.SEA_DROP_TILES
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := Look.SUMMON_RING_SEGMENTS
	for k in n:
		var a0 := TAU * float(k) / float(n)
		var a1 := TAU * float(k + 1) / float(n)
		var i0 := Vector3(cos(a0) * (r - half), y, sin(a0) * (r - half))
		var o0 := Vector3(cos(a0) * (r + half), y, sin(a0) * (r + half))
		var i1 := Vector3(cos(a1) * (r - half), y, sin(a1) * (r - half))
		var o1 := Vector3(cos(a1) * (r + half), y, sin(a1) * (r + half))
		_quad(st, Look.COL_SUMMON_RING, i0, o0, o1, i1)
	st.generate_normals()
	_ring.mesh = st.commit()
	_ring.position = Vector3(centre.x, 0.0, centre.y)
	_ring.visible = _band_on()


## Two triangles, wound so the face points up, with one colour on all four corners.
func _quad(st: SurfaceTool, col: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.set_color(col)
		st.add_vertex(v)


## Drops a wall from this tile's edge to whatever the neighbour's edge sits at, when the neighbour is
## lower. The neighbour's own corner heights are asked for rather than guessed, so the wall lands
## exactly on the surface below it and no gap opens at the join.
func _skirt(st: SurfaceTool, col: Color, tx: int, ty: int, dx: int, dy: int, a: Vector3, b: Vector3) -> void:
	var nx := tx + dx
	var ny := ty + dy
	# The neighbour's two corners along the shared edge, named by which side the edge is on.
	var na := 0.0
	var nb := 0.0
	if dy == -1:
		na = _corner_h(nx, ny, 0, 1)
		nb = _corner_h(nx, ny, 1, 1)
	elif dy == 1:
		na = _corner_h(nx, ny, 1, 0)
		nb = _corner_h(nx, ny, 0, 0)
	elif dx == -1:
		na = _corner_h(nx, ny, 1, 1)
		nb = _corner_h(nx, ny, 1, 0)
	else:
		na = _corner_h(nx, ny, 0, 0)
		nb = _corner_h(nx, ny, 0, 1)
	if na >= a.y - 0.001 and nb >= b.y - 0.001:
		return
	var pad := Look.TERRAIN_SKIRT_PAD
	# Darkened so a wall is told from the top face it hangs off even when the sun is straight on it —
	# the cliff-face line the flat board drew did the same job with a leaf and a width constant.
	_quad(st, col.darkened(0.15),
		a, b, Vector3(b.x, nb - pad, b.z), Vector3(a.x, na - pad, a.z))


func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# ⚠ Two-sided: a skirt's winding depends on which way it faces, and a one-sided wall seen from
	# behind is a hole in the island.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


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
	s.pixel_size = 1.0 / Look.TILE_PX
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
	m.material_override = mat
	_world.add_child(m)
	_hulls.append(m)
	_hulls_used += 1
	return m


## Puts one billboard at a body's feet. `centre_px` is the same world px the flat board drew at, so
## every offset that already went through `_body_offset_of` follows across for free.
func _put_body(centre_px: Vector2, radius: float, colour: Color, squash: Vector2, tex: Texture2D) -> void:
	var s := _sprite()
	var pic: Texture2D = tex if tex != null else _tex_body
	s.texture = pic
	s.modulate = Look.beast_tint(colour) if tex != null else colour
	var wide := radius * Look.BEAST_SPRITE_W_RATIO if tex != null else radius * 2.0
	var sx := wide * squash.x / float(pic.get_width())
	var sy := sx * squash.y / maxf(squash.x, 0.001)
	s.scale = Vector3(sx, sy, 1.0)
	var tall := float(pic.get_height()) * sy / Look.TILE_PX
	var tile := Vector2i(int(floor(centre_px.x / Look.TILE_PX)), int(floor(centre_px.y / Look.TILE_PX)))
	var foot := _ground_h(tile.x, tile.y) + Look.BODY_LIFT_PX / Look.TILE_PX
	s.position = Vector3(centre_px.x / Look.TILE_PX, foot + tall * 0.5, centre_px.y / Look.TILE_PX)


## The two halves of an HP bar, standing above the body rather than below it — a bar UNDER a
## billboard is inside the ground the billboard is standing on.
func _put_hp(centre_px: Vector2, radius: float, type_id: int, frac: float) -> void:
	var rects := _hp_rects(centre_px, type_id, frac)
	var back: Rect2 = rects[0]
	var fill: Rect2 = rects[1]
	var tile := Vector2i(int(floor(centre_px.x / Look.TILE_PX)), int(floor(centre_px.y / Look.TILE_PX)))
	var y := _ground_h(tile.x, tile.y) + (radius * 2.0 + Look.HP_BAR_GAP_PX * 2.0) / Look.TILE_PX
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
		_put_body(ecentre, eradius,
			Look.body_colour_of(true).lerp(Look.COL_FLASH, _flash_of(ekey)),
			_gait_squash(ekey), null)
		_put_hp(ecentre, eradius, et, battle.enemy_hp[e] / Rules.hp_of(et))

	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		_put_soldier(i, battle.soldier_pos[i])

	# The boats: a hull on the water and its passengers standing on it. Before the commit there is no
	# hull — a boat that has not left is its PLAN, and thirteen hulls stacked on one harbour is a blob
	# that says nothing. ⚠ **The plan's own picture (the route, the ring, the ghost fan) is NOT ported
	# yet**, so before the commit the field shows the band and nothing else.
	for bk in battle.boats.size():
		var boat: Dictionary = battle.boats[bk]
		if not battle.committed():
			continue
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

	_hide_unused()


## One soldier at a tile position, ashore or on a deck. Both call sites want the same body, the same
## gait and the same facing, and splitting them was how the deck soldier lost its HP bar once already.
func _put_soldier(i: int, at: Vector2) -> void:
	var st := int(army.type_id[i])
	var skey := "s%d" % i
	var sradius := Look.body_radius_of(st)
	var scentre := Look.tile_point_px(at) + _body_offset_of(skey)
	# The wolf faces what it is walking at. `_facing_of` returns RIGHT when there is no target, so an
	# idle body faces right rather than flipping on a zero vector.
	var stex: Texture2D = _tex_wolf_r if _facing_of(i, false).x >= 0.0 else _tex_wolf_l
	_put_body(scentre, sradius,
		Look.body_colour_of(false).lerp(Look.COL_FLASH, _flash_of(skey)),
		_gait_squash(skey), stex)
	_put_hp(scentre, sradius, st, army.hp[i] / army.max_hp_of(i))


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
## zero vector normalised is zero, which would collapse the beak triangle to a point and aim a lunge
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

	_shake_left = maxf(0.0, _shake_left - delta)
	if _shake_left <= 0.0:
		_shake_amp = 0.0

	for key: String in _body:
		var b: Dictionary = _body[key]
		b["flash"] = maxf(0.0, float(b["flash"]) - delta)
		b["knock"] = maxf(0.0, float(b["knock"]) - delta)
		b["lunge"] = maxf(0.0, float(b["lunge"]) - delta)

	if battle == null or army == null:
		return

	# Every alive enemy and every HITTABLE soldier — a soldier still aboard a boat can be shot by a
	# coastal crow, and without an entry that hit would have nothing to flash.
	var walkers := []
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] != 0:
			walkers.append(["e%d" % e, battle.enemy_pos[e]])
	for i in battle.soldier_state.size():
		if battle.is_hittable(i):
			walkers.append(["s%d" % i, battle.soldier_pos[i]])

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
				"gait": 0.0,
				"head": Vector2.RIGHT,
				"last": here,
			}
		var b: Dictionary = _body[key]
		var last: Vector2 = b["last"]
		var moved := here.distance_to(last)
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
			var push := minf(Look.LUNGE_PUSH_RATIO * r_self, gap + Look.LUNGE_BITE_PX) \
				* Look.fx_gain_of(2)
			if _body.has(atk_key):
				var ab: Dictionary = _body[atk_key]
				ab["lunge"] = Look.LUNGE_SEC
				ab["lunge_dir"] = facing
				ab["push"] = push
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
			var vtile: Vector2 = battle.soldier_pos[v] if from_enemy else battle.enemy_pos[v]
			var away := Look.tile_point_px(vtile) - atk_px
			vb["knock_dir"] = Vector2.RIGHT if away.length() <= Rules.EPS else away.normalized()

		# Amplitude tracks damage, or half of this effect is dead: a 2-damage cell and the lion's 4
		# have to feel different. A hit landing during an older shake only restarts it when it is at
		# least as strong as what is left, so a crow cannot cut a lion's blow short.
		var amp := minf(Look.SHAKE_MAX_PX, float(ev["dmg"]) * Look.SHAKE_PER_DAMAGE_PX)
		if amp >= _shake_amp * (_shake_left / Look.SHAKE_SEC):
			_shake_amp = amp
			_shake_left = Look.SHAKE_SEC

	for raw_new in born:
		_fx.append(raw_new)
	# The transient drawer is capped and the OLDEST goes: the per-body drawer is bounded by the
	# number of bodies instead, which is why this rule cannot reach a flash or a lunge.
	while _fx.size() > Look.FX_MAX_COUNT:
		_fx.remove_at(0)

## The shake, as an ABSOLUTE offset to assign to `position`.
##
## The phase runs off the shake's OWN age rather than a wall clock, which makes it deterministic —
## a random shake cannot be measured by any net — and starts it from rest so there is no pop. The
## magnitude is limited rather than left as two independent sines, because two sines at ±1 would put
## the corner at 1.41 x the cap and the cap would stop being a cap.
func _shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var decay := _shake_left / Look.SHAKE_SEC
	var age := Look.SHAKE_SEC - _shake_left
	var mag := _shake_amp * decay * Look.fx_gain_of(11)
	if mag <= 0.0:
		return Vector2.ZERO
	var raw := Vector2(sin(age * Look.SHAKE_A_FREQ), sin(age * Look.SHAKE_B_FREQ))
	return (raw * mag).limit_length(mag)

## P7. 0..1, one full on/off cycle every `HULL_WAIT_BLINK_SEC` — a raised cosine rather than a raw
## sine, so it sits at exactly 0 and 1 at the ends of each half-cycle instead of sweeping through
## every value with no rest, which reads as a pulse rather than a smear.
func _wait_blend() -> float:
	return 0.5 - 0.5 * cos(TAU * _wait_clock / Look.HULL_WAIT_BLINK_SEC)

## The one place a body's drawing offset is computed, so the body, the halo, the beak and the HP bar
## are all handed the same number. Split across call sites, one of them is eventually forgotten and
## the body walks out from under its own health bar with the whole round green.
func _body_offset_of(key: String) -> Vector2:
	return _lunge_offset(key) + _knock_offset(key)

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
	return dir * (Look.HIT_KNOCK_PX * Look.fx_gain_of(3) * (left / Look.HIT_KNOCK_SEC))

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
