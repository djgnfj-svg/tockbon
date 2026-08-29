# **The OPEN SEA, and every way of filling it, on the real island.**
#
# ⚠⚠ **NOT `prototypes/shoreline/` and NOT `prototypes/swash/`.** Those two settled the white line
# where the water meets the rock: *where does it come from* (distance to the baked outline, chosen out
# of seven) and *how does it move* (chosen out of twenty-seven, `27-gaps`). **Both answers are shipped
# and neither is reopened here.**
#
# **This lab asks the one question nobody has ever chosen an answer to: WHAT IS THE REST OF THE WATER
# MADE OF.** Today it is a single flat unshaded colour covering most of the screen, and it got there by
# subtraction — the swell, the ripples and the shallows were thrown away with the old shader — not by
# anyone looking at alternatives and picking this.
#
# ⚠⚠ **EVERY CANDIDATE CARRIES THE SHIPPED SHORELINE, BYTE FOR BYTE, AND IS HANDED THE GAME'S OWN
# SHORELINE DIALS.** That is the opposite of what the swash lab does next door and it is deliberate:
# there the line WAS the subject, here it is the thing that must not vary. **If the shore differs
# between two pictures the eye lands on the shore and the open water is never judged.**
#
# ⚠ **What is NOT here**: bodies, boats, the 판's white marks, the HUD. The island, the sun and the sea.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/island_lab.gd
#       opens and stays. **0 is the sea as it ships · 1.. are the candidates · LEFT/RIGHT step ·
#       Q/E turn · W/S zoom · R/F tilt · ESC quits.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/island_lab.gd -- shoot
#       photographs every version four times into `out/island/` and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const DIR := "res://prototypes/sea"
const OUT := "res://prototypes/sea/out/island/%s_%d.png"
const OUT_FAR := "res://prototypes/sea/out/far/%s_%d.png"
## ⚠⚠ **THE SECOND CAMERA, AND IT IS THE ONE THE QUESTION WAS ASKED ABOUT.** (2026-08-29, the user:
## 「먼 바다까지 생각했을 때의 바다를 어떻게 할지 고민하는 중임」.) Every candidate is also photographed
## from a point this many tiles off the island with **no land in the frame at all** — a mechanism that
## only works as a halo round the coast has nothing to show here, and that is the whole discrimination.
const FAR_OFF := Vector3(46.0, 0.0, 30.0)
const ISLAND_SCENE := "res://assets/terrain/island.glb"
const ISLAND_JSON := "res://assets/terrain/island.json"
## ⚠ **The shipped sea is index 0 and it is not a candidate.** It is what the screen looks like today,
## and a comparison with no "today" in it is nine unknowns and no baseline.
const SHIPPED := "res://src/view/water.gdshader"

const FRAMES := 4
const GAP_SEC := 1.6
const WARM_SEC := 0.5

var _sea: MeshInstance3D = null
var _island: Node3D = null
var _looks: Array = []
var _i := 0
var _clock := 0.0
var _cam: Camera3D = null
var _label: Label = null
var _shooting := false
var _far := false
var _turn := 0.0
var _tilt := 0.0
## ⚠⚠ **TWENTY-TWO, AND NEXT DOOR IT IS TEN, BECAUSE THE SUBJECT CHANGED.** The camera is orthogonal
## and its `size` is the screen's HEIGHT in tiles. At 10 the shoreline fills the frame and the open sea
## is two corners — the right frame for judging a line and **the wrong one for judging the water**, which
## is the thing that covers most of the real screen. At 22 the whole island sits in the middle with open
## sea on every side, which is what the player actually looks at.
var _zoom := 22.0
var _mid := Vector3.ZERO
var _held := {}
var _field_tex: ImageTexture = null
var _field_org := Vector2.ZERO
var _field_siz := Vector2.ONE


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)

	var f := FileAccess.open(ISLAND_JSON, FileAccess.READ)
	if f == null:
		push_error("sea_lab: no island.json — bake the island first")
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("sea_lab: island.json did not parse")
		return
	var gw := int(data["w"])
	var gh := int(data["h"])
	_mid = Vector3(float(gw) * 0.5, 0.0, float(gh) * 0.5)
	_tilt = Look.MAP_TILT_DEG

	# **The island, exactly as the game puts it on screen.**
	var packed := load(ISLAND_SCENE) as PackedScene
	if packed == null:
		push_error("sea_lab: island.glb will not load")
		return
	_island = packed.instantiate() as Node3D
	# ⚠⚠ **The Z offset is copied from the field view and it is not a fudge.** glTF's Y-up conversion
	# maps Blender +Y to Godot −Z, so an island authored over 0..h arrives over −h..0. Without this the
	# sea's field and the mesh describe two islands a board apart, and every candidate draws its line
	# through open water.
	_island.position.z = float(gh)
	world.add_child(_island)
	# ⚠ **Vertex colours are OFF by default on an imported material** — without this the island comes in
	# flat white and every tone the Blender script decided is thrown away silently.
	_use_vertex_colours(_island)

	# **The sea, at the game's water height and the game's span.**
	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Look.SEA_SPAN_TILES, Look.SEA_SPAN_TILES)
	pm.subdivide_width = 200
	pm.subdivide_depth = 200
	_sea.mesh = pm
	_sea.position = Vector3(_mid.x, Look.TERRAIN_H_WATER, _mid.z)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_sea)

	# **The game's sun**, down to the energy — a sea judged under a different light is judged wrong.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(Look.SUN_PITCH_DEG, Look.SUN_YAW_DEG, 0.0)
	sun.light_energy = Look.SUN_ENERGY
	sun.shadow_enabled = true
	world.add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.06, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.72)
	e.ambient_light_energy = 0.55
	env.environment = e
	world.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _zoom
	cam.near = 0.5
	cam.far = 200.0
	world.add_child(cam)
	_cam = cam

	_bake_field(gw, gh, data["coast"])
	_looks = _versions()
	var argv := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_shooting = argv.has("shoot")
	_far = argv.has("far")
	if _shooting:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			"res://prototypes/sea/out/far" if _far else "res://prototypes/sea/out/island"))
	else:
		_label = Label.new()
		_label.position = Vector2(14, 10)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		root.add_child(_label)
		var start := 0
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			if a.is_valid_int() and int(a) >= 0 and int(a) < _looks.size():
				start = int(a)
		_show(start)
	_aim()


## **The distance field, on the game's own numbers but baked here.**
##
## ⚠⚠ **IT CALLED `FieldView._bake_land_field` FOR ONE ROUND AND THAT WAS A MISTAKE.** Reading the
## game's own bake is the more honest measurement right up until the game does not compile — and on the
## day this was written `src/` was half way through a large edit, `field_view.gd` failed to parse, and
## **a prototype whose whole job is to survive the main code being in pieces went down with it.**
## ⇒ **This lab reads the island FILE and nothing else.** The dials still come from `look.gd`, which is
## data; the machinery does not.
##
## ⚠ **Distance is SCATTERED, not gathered**: measuring every texel against every segment is tens of
## millions of operations in GDScript. Each segment writes only into the box it can reach, which is a
## fraction of the work and exactly the same answer. **The sign is a scanline fill.**
func _bake_field(gw: int, gh: int, coast: Array) -> void:
	var sub := int(Look.WATER_FIELD_SUBDIV)
	var span := float(Look.WATER_FIELD_SPAN_TILES)
	# ⚠ **The margin is `span`, exactly as the field view sets it** — the sampler clamps outside the
	# field, so every border texel has to be real open sea or the foam repeats outward forever.
	var margin := span
	var tw := int(round((float(gw) + margin * 2.0) * float(sub)))
	var th := int(round((float(gh) + margin * 2.0) * float(sub)))
	_field_org = Vector2(-margin, -margin)
	_field_siz = Vector2(float(gw) + margin * 2.0, float(gh) + margin * 2.0)

	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	dist.fill(span)
	for s in coast:
		var a := Vector2(float(s[0]), float(s[1]))
		var b := Vector2(float(s[2]), float(s[3]))
		var e: Vector2 = b - a
		var l2: float = e.length_squared()
		var x0 := maxi(0, int((minf(a.x, b.x) - span - _field_org.x) * float(sub)))
		var x1 := mini(tw - 1, int((maxf(a.x, b.x) + span - _field_org.x) * float(sub)))
		var y0 := maxi(0, int((minf(a.y, b.y) - span - _field_org.y) * float(sub)))
		var y1 := mini(th - 1, int((maxf(a.y, b.y) + span - _field_org.y) * float(sub)))
		for py in range(y0, y1 + 1):
			var wy: float = _field_org.y + (float(py) + 0.5) / float(sub)
			var row := py * tw
			for px in range(x0, x1 + 1):
				var wx: float = _field_org.x + (float(px) + 0.5) / float(sub)
				var q := Vector2(wx, wy)
				var u: float = 0.0 if l2 <= 0.0 else clampf((q - a).dot(e) / l2, 0.0, 1.0)
				var dd: float = (q - (a + e * u)).length()
				if dd < dist[row + px]:
					dist[row + px] = dd

	var enc := PackedFloat32Array()
	enc.resize(tw * th)
	for py in th:
		var wy: float = _field_org.y + (float(py) + 0.5) / float(sub)
		var xs := PackedFloat32Array()
		for s in coast:
			var ay := float(s[1])
			var by := float(s[3])
			if (ay > wy) != (by > wy):
				xs.append(float(s[0]) + (wy - ay) / (by - ay) * (float(s[2]) - float(s[0])))
		xs.sort()
		var row := py * tw
		var k := 0
		var inside := false
		for px in tw:
			var wx: float = _field_org.x + (float(px) + 0.5) / float(sub)
			while k < xs.size() and wx >= xs[k]:
				inside = not inside
				k += 1
			var sd: float = -dist[row + px] if inside else dist[row + px]
			enc[row + px] = clampf(0.5 + sd / (span * 2.0), 0.0, 1.0)

	_field_tex = ImageTexture.create_from_image(
		Image.create_from_data(tw, th, false, Image.FORMAT_RF, enc.to_byte_array()))
	print("[sea_lab] field %dx%d texels, %d coast segments" % [tw, th, coast.size()])


func _use_vertex_colours(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m: Mesh = mi.mesh
		if m != null:
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s) as StandardMaterial3D
				if mat != null:
					mat.vertex_color_use_as_albedo = true
	for c in n.get_children():
		_use_vertex_colours(c)


## Index 0 is the shipped sea; the rest are the candidate folders, in name order.
func _versions() -> Array:
	var out: Array = [["shipped", SHIPPED]]
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	var names: Array = []
	for name in d.get_directories():
		if name == "out":
			continue
		if ResourceLoader.exists("%s/%s/water.gdshader" % [DIR, name]):
			names.append(name)
	names.sort()
	for name in names:
		out.append([name, "%s/%s/water.gdshader" % [DIR, name]])
	return out


## **Everything is handed the game's numbers, the candidates included** — and here that is right where
## next door it was wrong.
##
## ⚠⚠ **The swash lab must NOT do this and this lab MUST.** There the shoreline was the subject, so
## pushing the winner's width and rate onto a loser would have been a picture of a comparison that never
## ran. **Here the shoreline is the CONTROL**: every candidate carries the shipped border verbatim and
## every candidate must draw it identically, or the difference between two pictures is not the open
## water. A candidate's own new dials are its own; it declares them and defaults them itself.
func _apply(row: Array) -> void:
	var sh: Shader = load(str(row[1]))
	if sh == null:
		push_warning("sea_lab: could not load %s" % row[1])
		return
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("land_field", _field_tex)
	m.set_shader_parameter("field_origin", _field_org)
	m.set_shader_parameter("field_size", _field_siz)
	m.set_shader_parameter("field_span", float(Look.WATER_FIELD_SPAN_TILES))
	m.set_shader_parameter("shore_offset", Look.WATER_SHORE_OFFSET_TILES)
	m.set_shader_parameter("sea", Look.COL_WATER)
	m.set_shader_parameter("foam", Look.COL_WATER_FOAM)
	_hand_it_the_game_s_numbers(m)
	_sea.material_override = m


## **The shipped shoreline's dials, handed to every version.** ⚠ It has to track
## `FieldView._hand_the_sea_its_look` — a dial this file forgets is a dial every picture draws at the
## shader's default rather than the game's value, and index 0 is supposed to BE the game.
func _hand_it_the_game_s_numbers(m: ShaderMaterial) -> void:
	m.set_shader_parameter("line_tiles", Look.WATER_LINE_TILES)
	m.set_shader_parameter("line_hard", Look.WATER_LINE_HARD)
	m.set_shader_parameter("line_alpha", Look.WATER_LINE_ALPHA)
	m.set_shader_parameter("run", Look.WATER_RUN)
	m.set_shader_parameter("cycle", Look.WATER_CYCLE)
	m.set_shader_parameter("grad_step", Look.WATER_GRAD_STEP)
	m.set_shader_parameter("warp_a", Look.WATER_WARP_A)
	m.set_shader_parameter("warp_a_scale", Look.WATER_WARP_A_SCALE)
	m.set_shader_parameter("warp_b", Look.WATER_WARP_B)
	m.set_shader_parameter("warp_b_scale", Look.WATER_WARP_B_SCALE)
	m.set_shader_parameter("along_scale", Look.WATER_ALONG_SCALE)
	m.set_shader_parameter("curve_step", Look.WATER_CURVE_STEP)
	m.set_shader_parameter("refract_amt", Look.WATER_REFRACT)
	m.set_shader_parameter("point_gain", Look.WATER_POINT_GAIN)
	m.set_shader_parameter("bay_floor", Look.WATER_BAY_FLOOR)
	m.set_shader_parameter("rate", Look.WATER_RATE)
	m.set_shader_parameter("swash", Look.WATER_SWASH)
	m.set_shader_parameter("rise_frac", Look.WATER_RISE_FRAC)
	m.set_shader_parameter("rest_frac", Look.WATER_REST_FRAC)
	m.set_shader_parameter("surge", Look.WATER_SURGE)
	m.set_shader_parameter("rest_shape", Look.WATER_REST_SHAPE)
	m.set_shader_parameter("second_at", Look.WATER_SECOND_AT)
	m.set_shader_parameter("second_w", Look.WATER_SECOND_W)
	m.set_shader_parameter("second_amt", Look.WATER_SECOND_AMT)
	m.set_shader_parameter("cut_scale", Look.WATER_CUT_SCALE)
	m.set_shader_parameter("cut_drift", Look.WATER_CUT_DRIFT)
	m.set_shader_parameter("cut_shut", Look.WATER_CUT_SHUT)
	m.set_shader_parameter("cut_open", Look.WATER_CUT_OPEN)
	m.set_shader_parameter("tip_at", Look.WATER_TIP_AT)
	m.set_shader_parameter("tip_full", Look.WATER_TIP_FULL)
	m.set_shader_parameter("first_cut", Look.WATER_FIRST_CUT)
	m.set_shader_parameter("calm", Look.WATER_CALM)
	m.set_shader_parameter("calm_scale", Look.WATER_CALM_SCALE)
	m.set_shader_parameter("calm_speed", Look.WATER_CALM_SPEED)


func _show(k: int) -> void:
	_i = posmod(k, _looks.size())
	_apply(_looks[_i])
	if _label != null:
		_label.text = "%d  %s\n0..9 pick (%d in all) · LEFT/RIGHT step · TAB island/open sea · Q/E turn · W/S zoom · R/F tilt · ESC quit" % [
			_i, str(_looks[_i][0]), _looks.size()]


func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _aim() -> void:
	_cam.size = _zoom
	var r := 40.0
	var p := deg_to_rad(clampf(_tilt, Look.CAM_PITCH_MIN_DEG, Look.CAM_PITCH_MAX_DEG))
	var at: Vector3 = _mid + (FAR_OFF if _far else Vector3.ZERO)
	var eye := at + Vector3(sin(_turn) * cos(p), sin(p), cos(_turn) * cos(p)) * r
	_cam.look_at_from_position(eye, at, Vector3.UP)


func _watch(delta: float) -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	# ⚠⚠ **SHIFT IS THE TENS DIGIT.** There are more than ten versions now and a keyboard has ten number
	# keys, so 11 was unreachable and pressing it went to 1 — which looks like the lab ignoring you
	# rather than running out of keys.
	# ⚠ **Two modifiers, because ten keys and a shift only reach 19** and the list is past that.
	var tens := 0
	if Input.is_key_pressed(KEY_SHIFT):
		tens = 10
	elif Input.is_key_pressed(KEY_CTRL):
		tens = 20
	for n in 10:
		if _tap(KEY_0 + n):
			_show(tens + n)
	if _tap(KEY_TAB):
		_far = not _far
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	if Input.is_key_pressed(KEY_Q):
		_turn -= delta * 1.0
	if Input.is_key_pressed(KEY_E):
		_turn += delta * 1.0
	if Input.is_key_pressed(KEY_W):
		_zoom = maxf(4.0, _zoom - delta * 10.0)
	if Input.is_key_pressed(KEY_S):
		_zoom = minf(40.0, _zoom + delta * 10.0)
	if Input.is_key_pressed(KEY_R):
		_tilt = minf(Look.CAM_PITCH_MAX_DEG, _tilt + delta * 25.0)
	if Input.is_key_pressed(KEY_F):
		_tilt = maxf(Look.CAM_PITCH_MIN_DEG, _tilt - delta * 25.0)
	_aim()
	return false


func _process(delta: float) -> bool:
	if not _shooting:
		return _watch(delta)
	_clock += delta
	if _clock < (WARM_SEC if _i % (FRAMES + 1) == 0 else GAP_SEC):
		return false
	_clock = 0.0
	var per := FRAMES + 1
	if _i >= _looks.size() * per:
		return true
	var k: int = _i / per
	var step: int = _i % per
	if step == 0:
		_apply(_looks[k])
	else:
		# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already
		# drawn, so doing both in one step files every picture under the previous version's name.
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path((OUT_FAR if _far else OUT) % [str(_looks[k][0]), step - 1]))
		print("[sea_lab] %s %d" % [str(_looks[k][0]), step - 1])
	_i += 1
	return false
