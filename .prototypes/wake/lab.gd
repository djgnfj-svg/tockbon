# **THE WAKE A BOAT LEAVES BEHIND IT, AND WHAT COULD DRAW IT.**
#
# ⚠⚠ **TWO SHEETS LIVE IN HERE NOW.** `01`..`05` are five different MECHANISMS, and the user chose the
# fourth. `04a`..`04e` are that one mechanism at five sets of NUMBERS — the user's follow-up was
# 「심플하게 있으면 될듯 4번인데 좀더 심플하게 할 수 있나」. **They share this harness on purpose**, so a picture
# from either sheet can be laid beside a picture from the other.
#
# > **「배가 바다를 지나며 뒤에 남기는 물결을 무엇으로 그리나」**
# > — *what draws the wake a boat leaves behind it as it crosses the sea?*
#
# ⚠⚠ **THE ISLAND, THE BUILDINGS, THE 검사 AND THE 짐승 ARE OUT OF THE FRAME ON PURPOSE.** Water, boat,
# wake, and nothing else. Anything else in the picture is something the eye lands on instead of the
# thing being judged, and this repo has spent a round on that already.
#
# **Every candidate carries the shipped sea byte for byte.** `build.py` splices
# `src/view/water.gdshader` around each folder's `mech.gdshader`, and this file hands every one of them
# the same forty dials out of `look.gd`. ⚠ **A tool that quietly overrides a uniform makes the user
# approve a look the game cannot reproduce** — so the only value here that the game does not already
# hold is the wake's own.
#
# ⚠⚠ **THE 해안선 IS NOT IN THESE PICTURES AND THAT IS NOT AN OVERRIDE.** There is no island, so the
# distance field says "open sea" everywhere and the shipped border draws nothing — which is what it
# does over open water in the game too. The shader is unaltered; it is simply out of land.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wake/lab.gd
#       opens and stays. **1..9 pick a candidate · SPACE swaps the straight run for the turning one ·
#       TAB near/far camera · R restarts the crossing · ESC quits.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/wake/lab.gd -- shoot
#       photographs every candidate, three frames each, into `out/` and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const Common := preload("res://.prototypes/wake/common.gd")

const DIR := "res://.prototypes/wake"
const OUT := "res://.prototypes/wake/out/%s_%s.png"

## ⚠⚠ **The sim is stepped at a FIXED rate and photographed at a FIXED time.** The real frame delta
## would put a different length of trail in every picture.
const DT := 1.0 / 60.0

## The camera's own two distances, in 조각 of visible WIDTH. ⚠ `keep_aspect = KEEP_WIDTH`, exactly as
## `field_view` sets it, so `size` means the same thing here as it does in the game.
##
## ⚠ **`NEAR` was 16 for one round and the hull filled a third of the frame** — a picture of a boat
## with a wake in the corner rather than a picture of a wake.
##
## ⚠⚠ **`FAR` IS THE GAME'S OWN OPENING FRAME.** The shipped 30 x 26 island opens at about 42 조각 of
## visible ground — `look.gd` records the measurement — and **a wake that only reads at `NEAR` is not a
## wake this game can use.** That is the frame the player actually watches a landing from.
const NEAR := 24.0
const FAR := 42.0

## Copied from `look.gd`, not read from it. ⚠ **Another builder is inside `src/` right now**; a lab
## that imports the game goes down the moment the game does not parse, and this one exists to survive
## exactly that.
const SEA_SPAN_TILES := 400.0
const SEA_Y := 0.075
const COL_SKY := Color(0.055, 0.055, 0.075)
const COL_AMBIENT := Color(0.620, 0.680, 0.790)
const AMBIENT_ENERGY := 0.92
const SUN_PITCH_DEG := -52.0
const SUN_YAW_DEG := -35.0
const SUN_ENERGY := 1.5
const SUN_SHADOW_DIST_TILES := 60.0
const SUN_SHADOW_NORMAL_BIAS := 1.8
const CAM_PITCH_DEG := 40.0
const CAM_DIST_TILES := 90.0
const CAM_FAR_TILES := 140.0

## **name · turning · when to shoot · how wide the frame is.**
const SHOTS := [
	["straight", false, Common.T_STRAIGHT, NEAR],
	["turn", true, Common.T_TURN, NEAR],
	["far", false, Common.T_STRAIGHT, FAR],
]
## How many frames each photograph gets before it is taken. ⚠ **Not one**: a shader that has just been
## handed to a material compiles on the first frame it is drawn, and the picture of that frame is the
## sea without the wake on it.
const SETTLE := 4

var _world: Node3D = null
var _sea: MeshInstance3D = null
var _boat: Node3D = null
var _cam: Camera3D = null
var _label: Label = null

var _cands: Array = []
var _cur: Object = null
var _cur_i := -1

var _shooting := false
var _job := 0
var _frame := 0

var _turning := false
var _far := false
var _t := 0.0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_world = Node3D.new()
	root.add_child(_world)

	# **The sea, at the game's water height and the game's span.** The shader arrives with the
	# candidate; this is only the surface it is painted on.
	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SEA_SPAN_TILES, SEA_SPAN_TILES)
	_sea.mesh = pm
	_sea.position.y = SEA_Y
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_sea)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(SUN_PITCH_DEG, SUN_YAW_DEG, 0.0)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SUN_SHADOW_DIST_TILES
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_normal_bias = SUN_SHADOW_NORMAL_BIAS
	_world.add_child(sun)

	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = COL_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = COL_AMBIENT
	e.ambient_light_energy = AMBIENT_ENERGY
	var env := WorldEnvironment.new()
	env.environment = e
	_world.add_child(env)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.far = CAM_FAR_TILES
	_world.add_child(_cam)

	_boat = Common.boat_node()
	if _boat != null:
		_world.add_child(_boat)

	_cands = _versions()
	if _cands.is_empty():
		push_error("wake_lab: no candidate folder has a water.gdshader — run build.py first")
		return

	var argv := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_shooting = argv.has("shoot")
	if _shooting:
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://.prototypes/wake/out"))
	else:
		_label = Label.new()
		_label.position = Vector2(14, 10)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		root.add_child(_label)
		_pick(0)
		_aim(NEAR)


## The candidate folders, in name order. **There is no "shipped" row**: the game draws no wake at all
## today, and the nearest thing to that baseline is `05-bowwave`, which is a candidate.
func _versions() -> Array:
	var out: Array = []
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
		out.append(name)
	return out


func _pick(k: int) -> void:
	var i := posmod(k, _cands.size())
	if i == _cur_i:
		return
	if _cur != null:
		_cur.teardown()
		_cur = null
	_cur_i = i
	var name: String = str(_cands[i])
	var script := load("%s/%s/wake.gd" % [DIR, name])
	if script == null:
		push_error("wake_lab: %s has no wake.gd" % name)
		return
	_cur = script.new()
	_cur.build(_world, _boat)

	var mat := ShaderMaterial.new()
	mat.shader = load("%s/%s/water.gdshader" % [DIR, name])
	_hand_it_the_game_s_numbers(mat)
	_sea.material_override = mat
	_t = 0.0
	_cur.reset()
	_relabel()


func _relabel() -> void:
	if _label == null or _cur_i < 0:
		return
	_label.text = "%d  %s\n1..%d pick · SPACE %s · TAB %s · R restart · ESC quit" % [
		_cur_i + 1, str(_cands[_cur_i]), _cands.size(),
		"turning run" if _turning else "straight run",
		"far" if _far else "near"]


func _restart() -> void:
	_t = 0.0
	if _cur != null:
		_cur.reset()
	_relabel()


## **The dials the sea reads, every one of them out of `look.gd`.** ⚠ It has to track
## `field_view._hand_the_sea_its_look` — a dial this file forgets is a dial every picture draws at the
## shader's default rather than the game's value.
##
## ⚠⚠ **The values are LITERALS here and that is deliberate.** Reading `Look` would tie five prototypes
## to a file another builder is editing. **They were copied on 2026-08-30**; if the sea in these
## pictures stops looking like the sea in the game, this block is the first place to look.
func _hand_it_the_game_s_numbers(m: ShaderMaterial) -> void:
	# **No island, so the field says open sea everywhere.** One texel at 1.0 decodes to +`field_span`
	# 조각 from land, which is past everything the border reads — the shipped shoreline therefore draws
	# nothing, unaltered.
	var far_from_land := PackedFloat32Array([1.0])
	var img := Image.create_from_data(1, 1, false, Image.FORMAT_RF, far_from_land.to_byte_array())
	m.set_shader_parameter("land_field", ImageTexture.create_from_image(img))
	m.set_shader_parameter("field_origin", Vector2(-1.0, -1.0))
	m.set_shader_parameter("field_size", Vector2(2.0, 2.0))
	m.set_shader_parameter("field_span", 4.0)
	m.set_shader_parameter("shore_offset", 0.0)

	m.set_shader_parameter("sea", Color(0.430, 0.590, 0.660))
	m.set_shader_parameter("foam", Color(0.900, 0.940, 0.950))
	m.set_shader_parameter("line_tiles", 0.30)
	m.set_shader_parameter("line_hard", 0.85)
	m.set_shader_parameter("line_alpha", 1.0)
	m.set_shader_parameter("run", 0.35)
	m.set_shader_parameter("cycle", 9.0)
	m.set_shader_parameter("grad_step", 0.09)
	m.set_shader_parameter("warp_a", 0.16)
	m.set_shader_parameter("warp_a_scale", 0.55)
	m.set_shader_parameter("warp_b", 0.07)
	m.set_shader_parameter("warp_b_scale", 1.7)
	m.set_shader_parameter("along_scale", 0.16)
	m.set_shader_parameter("curve_step", 1.1)
	m.set_shader_parameter("refract_amt", 0.85)
	m.set_shader_parameter("point_gain", 1.5)
	m.set_shader_parameter("bay_floor", 0.35)
	m.set_shader_parameter("rate", 0.17)
	m.set_shader_parameter("swash", 0.30)
	m.set_shader_parameter("rise_frac", 0.34)
	m.set_shader_parameter("rest_frac", 0.30)
	m.set_shader_parameter("surge", 1.5)
	m.set_shader_parameter("rest_shape", 0.6)
	m.set_shader_parameter("second_at", 0.22)
	m.set_shader_parameter("second_w", 0.09)
	m.set_shader_parameter("second_amt", 0.85)
	m.set_shader_parameter("cut_scale", 0.42)
	m.set_shader_parameter("cut_drift", 0.05)
	m.set_shader_parameter("cut_shut", 0.42)
	m.set_shader_parameter("cut_open", 0.52)
	m.set_shader_parameter("tip_at", 0.75)
	m.set_shader_parameter("tip_full", 1.15)
	m.set_shader_parameter("first_cut", 0.55)
	m.set_shader_parameter("calm", 0.55)
	m.set_shader_parameter("calm_scale", 0.055)
	m.set_shader_parameter("calm_speed", 0.02)


## **Runs one crossing from t = 0 to `to`, at the fixed step.** The whole history is built here, in one
## frame, before anything is drawn — so what the camera sees is a wake of an exact age and not a wake
## whose length depends on how fast this machine got through the loop.
func _run_to(to: float) -> void:
	if _cur == null:
		return
	_cur.reset()
	_t = 0.0
	while _t < to:
		var dt: float = minf(DT, to - _t)
		_t += dt
		var b: Array = Common.boat_at(_t, _turning)
		_cur.step(dt, _t, b[0] as Vector2, b[1] as Vector2)
	_present()


## Hands the mechanism the frame it is about to be drawn in: the sea's material for the two that live
## in the shader, and a chance to rebuild geometry for the three that do not.
func _present() -> void:
	if _cur == null:
		return
	_cur.present(_t, _sea.material_override as ShaderMaterial)
	_place_boat()


func _place_boat() -> void:
	if _boat == null:
		return
	var b: Array = Common.boat_at(_t, _turning)
	var pos: Vector2 = b[0]
	var head: Vector2 = b[1]
	var bob := sin(_t * TAU / Common.BOAT_BOB_SEC) * Common.BOAT_BOB_TILES
	_boat.position = Vector3(pos.x, SEA_Y + bob, pos.y)
	var roll := sin(_t * TAU / Common.BOAT_ROLL_SEC) * Common.BOAT_ROLL_DEG
	_boat.rotation = Vector3.ZERO
	_boat.rotate_y(Common.yaw_of(head))
	_boat.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(roll))


## The game's camera: orthogonal, pitched `CAM_PITCH_DEG`, aimed at the middle of the crossing.
func _aim(size: float) -> void:
	_cam.size = size
	var p := deg_to_rad(CAM_PITCH_DEG)
	var back := Vector3(0.0, sin(p), cos(p))
	_cam.look_at_from_position(back * CAM_DIST_TILES, Vector3.ZERO, Vector3.UP)


# --- shooting -------------------------------------------------------------------------------------

func _shoot(delta: float) -> bool:
	var total: int = _cands.size() * SHOTS.size()
	if _job >= total:
		return true
	var ci: int = _job / SHOTS.size()
	var si: int = _job % SHOTS.size()
	var shot: Array = SHOTS[si]
	if _frame == 0:
		_turning = bool(shot[1])
		_pick(ci)
		# ⚠ `_pick` is a no-op when the candidate has not changed, and the run has to be re-driven for
		# every shot regardless — the second shot of a candidate is a different crossing.
		_aim(float(shot[3]))
		_run_to(float(shot[2]))
	elif _frame >= SETTLE:
		var path: String = OUT % [str(_cands[ci]), str(shot[0])]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("[wake_lab] %s %s" % [str(_cands[ci]), str(shot[0])])
		_job += 1
		_frame = -1
	_frame += 1
	return false


# --- watching -------------------------------------------------------------------------------------

var _held := {}

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch(delta: float) -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in _cands.size():
		if _tap(KEY_1 + n):
			_cur_i = -1
			_pick(n)
	if _tap(KEY_SPACE):
		_turning = not _turning
		_restart()
	if _tap(KEY_TAB):
		_far = not _far
		_relabel()
	if _tap(KEY_R):
		_restart()
	_aim(FAR if _far else NEAR)

	# The crossing loops, so the lab can be left running and watched.
	_t += delta
	if _t > (Common.T_TURN if _turning else Common.T_STRAIGHT) + 2.0:
		_t = 0.0
		_cur.reset()
	var b: Array = Common.boat_at(_t, _turning)
	_cur.step(delta, _t, b[0] as Vector2, b[1] as Vector2)
	_present()
	return false


func _process(delta: float) -> bool:
	if _cands.is_empty():
		return true
	if _shooting:
		return _shoot(delta)
	return _watch(delta)
