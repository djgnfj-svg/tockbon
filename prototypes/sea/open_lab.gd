# **WHAT HAS TO BE IN THE OPEN SEA SO IT DOES NOT READ AS EMPTY WHILE A BOAT CROSSES IT.**
#
# > **「배가 건너다니는 열린 바다가 비어 보이지 않으려면 무엇이 있어야 하나」**
# > — *what has to be in the open sea so it does not read as empty while a boat crosses it?*
#
# The user, watching the wake lab: **「물이 좀 너무 없긴하다 뭔가」**.
#
# ⚠⚠ **THIS QUESTION WAS ASKED ONCE, ON 2026-08-29, AND EVERY ONE OF TEN CANDIDATES WAS TURNED DOWN**
# — not because a winner lost but because nothing beat flat. **Those ten are `01-crests` .. `05-paper`
# here and `prototypes/wave/`'s five, and they are NOT in this sheet**; `SKIP` below names them and why.
#
# **Two things are different now and they are the whole reason for a second asking:**
#
#   1. ⚠⚠ **That round judged EMPTY water.** No boat, no wake, in any of the ten frames. **Here a hull
#      crosses with its trail behind it** — the sea may not need filling so much as it needs something
#      to be relative to.
#   2. **The camera now roams `Look.CAM_ROAM_TILES` = 20 조각 out over open water**, and the emptiness
#      is worst out there. The old round never looked.
#
# ⚠⚠ **NEITHER THE FLAT SEA NOR THE 해안선 IS REOPENED.** The flat water was confirmed three times and
# the border was chosen out of twenty-seven versions (`prototypes/swash/`, the winner `27-gaps`).
# **`build.py` splices the shipped shader round each candidate**, so the border is byte-identical in
# every picture by construction, and this file hands every version the game's own dials. **A candidate
# that alters either is disqualified.**
#
# ⚠ **This is `island_lab.gd` next door with a hull sailing through it**, not a third harness: the
# island, the field bake and the dial hand-off are that file's, the crossing and the wake blocks are
# `field_view._paint_wake`'s. **What is new here is the boat, and the three named frames.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/open_lab.gd
#       opens and stays. **0 is the sea as it ships · 1.. are the candidates · LEFT/RIGHT step ·
#       TAB steps the three frames · ESC quits.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/sea/open_lab.gd -- shoot
#       photographs every version in all three frames into `out/open2/` and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const DIR := "res://prototypes/sea"
const OUT := "res://prototypes/sea/out/open2/%s_%s.png"
const ISLAND_SCENE := "res://assets/terrain/island.glb"
const ISLAND_JSON := "res://assets/terrain/island.json"
## ⚠ **The shipped sea is index 0 and it is not a candidate.** It is what the screen looks like today,
## and a comparison with no "today" in it is five unknowns and no baseline. **It is also the control
## the lead asked for**: flat is the thing every candidate has to beat.
const SHIPPED := "res://src/view/water.gdshader"

## ⚠⚠ **THE 2026-08-29 ROUND'S FIVE, LEFT ON DISK AND KEPT OUT OF THIS SHEET.** Every one was shown to
## the user and turned down. Reshooting them is a round spent proving what was already measured, and
## their `NOTES.md` files are the record. **`10-grain` is the one shape from that round rebuilt on
## purpose**, as this sheet's own control for 「a fine texture everywhere」.
const SKIP := ["01-crests", "02-facets", "03-swell", "04-bands", "05-paper", "out"]

# --- copied out of `look.gd` and `rules.gd`, never read from them ------------------------------------
# ⚠⚠ **THE VALUES ARE LITERALS AND THAT IS DELIBERATE.** Two other agents are inside `src/` right now;
# a lab that reads `Look` goes down the moment the game does not parse, and this one exists to survive
# exactly that. **They were copied on 2026-08-30** — if the sea in these pictures stops looking like
# the sea in the game, this block is the first place to look. The SHADER is a different matter: it is
# spliced from the shipped file by `build.py`, so it cannot drift at all.
const SEA_SPAN_TILES := 400.0
const SEA_Y_TILES := 0.075
const COL_SKY := Color(0.055, 0.055, 0.075)
const COL_AMBIENT := Color(0.620, 0.680, 0.790)
const AMBIENT_ENERGY := 0.92
const COL_WATER := Color(0.430, 0.590, 0.660)
const COL_WATER_FOAM := Color(0.900, 0.940, 0.950)
const SUN_PITCH_DEG := -52.0
const SUN_YAW_DEG := -35.0
const SUN_ENERGY := 1.5
const SUN_SHADOW_DIST_TILES := 60.0
const SUN_SHADOW_NORMAL_BIAS := 1.8
const CAM_PITCH_DEG := 40.0
const CAM_DIST_TILES := 90.0
const CAM_FAR_TILES := 140.0
const WATER_FIELD_SPAN_TILES := 4.0
const WATER_FIELD_SUBDIV := 16

## The hull, and the marks the water makes about it. **All of section 7 of `look.gd`.**
const WAKE_HULLS := 12
const WAKE_SLOTS := 8
const WAKE_LIFE_SEC := 4.0
const WAKE_W_TILES := 0.16
const WAKE_HARD := 0.35
const WAKE_ALPHA := 0.85
const WAKE_FROTH_SCALE := 2.2
const WAKE_FROTH_AMT := 0.35
## `-(Rules.BOAT_HULL_HALF_TILES - Look.WAKE_STERN_INSET_TILES)` = `-(2.6 - 0.15)`.
const WAKE_STERN_TILES := -2.45
## `Look.WAKE_LIFE_SEC / (WAKE_SLOTS - 2)`.
const WAKE_EVERY_SEC := WAKE_LIFE_SEC / 6.0
const HULL_HALF_TILES := 2.6
const HULL_BEAM_HALF_TILES := 1.005
const HULL_SHADOW_W_TILES := 0.30
const HULL_SHADOW_BOW := 0.35
const HULL_SHADOW_DIM := 0.62
const HULL_SHADOW_COOL := 1.18
const HULL_SHADOW_ALPHA := 0.85
const HULL_BREAK_AT_TILES := 0.10
const HULL_BREAK_W_TILES := 0.035
const HULL_BREAK_AMT := 0.85
const HULL_BREAK_BOW := 0.80
const HULL_HALO_TILES := 1.00
const HULL_HALO_AMT := 0.12
const HULL_HALO_AFT := 1.60

## The boat on screen, and how fast it goes. `Rules.BOAT_SPEED_TILES` is 1.2.
## ⚠ **Not the lab's 4.0 next door.** `prototypes/wake/` sailed at 4.0 because it had copied a stale
## number, and `look.gd` records that the trail the user judged was three times longer than the one the
## game draws. **This sheet uses the game's speed**, so the trail in these pictures is the real one.
const BOAT_SCENE := "res://assets/props/boat.glb"
const BOAT_SPEED_TILES := 1.2
const BOAT_DRAFT_TILES := -0.20
const BOAT_BOB_TILES := 0.06
const BOAT_BOB_SEC := 2.2
const BOAT_ROLL_DEG := 3.0
const BOAT_ROLL_SEC := 3.1

## The shipped 해안선's dials, handed to every version including index 0.
const SHORE := {
	"line_tiles": 0.035, "line_hard": 0.85, "line_alpha": 0.90,
	"run": 0.30, "cycle": 2.6, "grad_step": 0.06,
	"warp_a": 0.055, "warp_a_scale": 0.45, "warp_b": 0.030, "warp_b_scale": 1.30,
	"along_scale": 0.55, "curve_step": 0.30,
	"refract_amt": 0.85, "point_gain": 2.1, "bay_floor": 0.35,
	"rate": 0.16, "swash": 0.16, "rise_frac": 0.22,
	"rest_frac": 0.45, "surge": 1.6, "rest_shape": 0.7,
	"second_at": 0.22, "second_w": 0.035, "second_amt": 0.85,
	"cut_scale": 0.55, "cut_drift": 0.03, "cut_shut": 0.40, "cut_open": 0.62,
	"tip_at": 0.90, "tip_full": 1.30, "first_cut": 0.35,
	"calm": 0.25, "calm_scale": 0.38, "calm_speed": 0.035,
}

# --- the three frames --------------------------------------------------------------------------------
## ⚠⚠ **THE SIM IS STEPPED AT A FIXED RATE AND PHOTOGRAPHED AT A FIXED TIME.** The real frame delta
## would put a different length of trail in every picture, and the sheet would be measuring the
## machine's mood rather than the mechanism.
const DT := 1.0 / 60.0

## **The island's opening framing, worked out rather than guessed.** `Look.survey_zoom_of(30, 26)` is
## `min(1280 / (30*40*1.40), 720 / (26*40*1.40*sin 40))` = 0.7619, and `field_view` sets
## `cam.size = 1280 / zoom / 40` — **42.0 조각 of visible WIDTH**, with `keep_aspect = KEEP_WIDTH`
## exactly as the game sets it. The ground it covers is 42.0 wide by `720/0.7619/40/sin 40` = **36.75
## 조각 deep**, because the board is leaning away.
const OPEN_SIZE := 42.0
const OPEN_DEEP := 36.75

## **The island's middle**, from `island.json`: a 30 x 26 board.
const MID := Vector2(15.0, 13.0)

## **Where the camera can get to, and it is the roam bound and not a number picked to look empty.**
## `field_view._clamp_cam` keeps the visible rect inside the island grown by `Look.CAM_ROAM_TILES` on
## every side — 70 x 66 조각 — so the middle of the screen reaches `(70 - 42) / 2` = **14.0 조각** across
## and `(66 - 36.75) / 2` = **14.6 조각** down. **That corner is this frame**, and the island falls into
## the top-left quarter of it with open water filling the rest.
const OUT_AT := Vector2(29.0, 27.6)

## **name · where the camera looks · is there a hull · where it starts · which way it points · when to
## shoot.** The heading is normalised here so the table reads as a bearing rather than as a unit vector.
##
## ⚠ **`open` carries no hull on purpose** — it is the baseline the other two are read against, and the
## frame the player actually first sees.
const SHOTS := [
	["open", MID, Vector2.ZERO, Vector2.ZERO, 0.0],
	["out", OUT_AT, Vector2(52.0, 40.0), Vector2(-37.0, -27.0), 14.0],
	["cross", MID, Vector2(40.0, 31.0), Vector2(-26.0, -11.0), 9.0],
]
## How many frames a picture gets before it is taken. ⚠ **Not one**: a shader that has just been handed
## to a material compiles on the first frame it is drawn, and a picture of that frame is the sea
## without the candidate on it.
const SETTLE := 6

var _world: Node3D = null
var _sea: MeshInstance3D = null
var _island: Node3D = null
var _boat: Node3D = null
var _cam: Camera3D = null
var _label: Label = null

var _looks: Array = []
var _i := 0
var _shot := 0

var _shooting := false
var _job := 0
var _frame := 0
var _held := {}

var _field_tex: ImageTexture = null
var _field_org := Vector2.ZERO
var _field_siz := Vector2.ONE

## The wake's twelve blocks of eight, and the moment each hull last committed a point.
var _wake := PackedVector4Array()
var _wake_t := 0.0
## Only the live lab moves. See `LOOP_SEC`.
var _live := 0.0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_world = Node3D.new()
	root.add_child(_world)

	var f := FileAccess.open(ISLAND_JSON, FileAccess.READ)
	if f == null:
		push_error("open_lab: no island.json — bake the island first")
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("open_lab: island.json did not parse")
		return
	var gw := int(data["w"])
	var gh := int(data["h"])

	var packed := load(ISLAND_SCENE) as PackedScene
	if packed == null:
		push_error("open_lab: island.glb will not load")
		return
	_island = packed.instantiate() as Node3D
	# ⚠⚠ **The Z offset is copied from the field view and it is not a fudge.** glTF's Y-up conversion
	# maps Blender +Y to Godot −Z, so an island authored over 0..h arrives over −h..0. Without this the
	# sea's field and the mesh describe two islands a board apart.
	_island.position.z = float(gh)
	_world.add_child(_island)
	# ⚠ **Vertex colours are OFF by default on an imported material** — without this the island comes
	# in flat white and every tone the Blender script decided is thrown away silently.
	_use_vertex_colours(_island)

	# **The sea, at the game's water height and the game's span, and NOT subdivided** — the shipped one
	# is two triangles, and every candidate here decides its colour per pixel.
	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SEA_SPAN_TILES, SEA_SPAN_TILES)
	_sea.mesh = pm
	_sea.position = Vector3(MID.x, SEA_Y_TILES, MID.y)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_sea)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(SUN_PITCH_DEG, SUN_YAW_DEG, 0.0)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SUN_SHADOW_DIST_TILES
	# One split, not four: the seam between cascades drew as a hard line straight across the sea.
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

	var boat_scene := load(BOAT_SCENE) as PackedScene
	if boat_scene == null:
		push_error("open_lab: assets/props/boat.glb will not load")
		return
	_boat = boat_scene.instantiate() as Node3D
	_world.add_child(_boat)

	_bake_field(gw, gh, data["coast"])
	_looks = _versions()

	var argv := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_shooting = argv.has("shoot")
	if _shooting:
		# ⚠⚠ **THIS IS WHAT MAKES THE 해안선 THE CONTROL RATHER THAN A SECOND VARIABLE, AND WITHOUT IT
		# THE SHEET WAS WRONG.** The shipped border rides `TIME`, which cannot be pinned from outside
		# without editing the shipped shader — and editing it is disqualifying. **Measured before this
		# line existed: 0.6% of the `open` frame moved by more than 40 of 255 between two candidates,
		# every one of those pixels at the coast** and none of them in the open water the sheet is
		# about. `Engine.time_scale` scales the clock the rendering server hands the shader, so at zero
		# every picture is the same instant of the same border.
		# ⚠ **Shooting only.** The live lab has to run or nothing moves in it at all.
		Engine.time_scale = 0.0
		DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path("res://prototypes/sea/out/open2"))
	else:
		_label = Label.new()
		_label.position = Vector2(14, 10)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		root.add_child(_label)
		_show(0)


## **The distance field, on the game's own numbers but baked here.**
##
## ⚠⚠ **`island_lab.gd` records why this reads the island FILE rather than calling the game's own
## bake**: for one round it called `FieldView._bake_land_field`, and on the day that was written
## `field_view.gd` did not parse and a lab whose whole job is to survive the main code being in pieces
## went down with it. **Copied from that file unchanged except for the dials, which are literals here.**
##
## ⚠ **Distance is SCATTERED, not gathered**: each segment writes only into the box it can reach.
## **The sign is a scanline fill.**
func _bake_field(gw: int, gh: int, coast: Array) -> void:
	var sub := WATER_FIELD_SUBDIV
	var span := WATER_FIELD_SPAN_TILES
	# ⚠ **The margin is `span`, exactly as the field view sets it** — the sampler clamps outside the
	# field, so every border texel has to be real open sea.
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
		var ed: Vector2 = b - a
		var l2: float = ed.length_squared()
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
				var u: float = 0.0 if l2 <= 0.0 else clampf((q - a).dot(ed) / l2, 0.0, 1.0)
				var dd: float = (q - (a + ed * u)).length()
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
	print("[open_lab] field %dx%d texels, %d coast segments" % [tw, th, coast.size()])


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


## Index 0 is the shipped sea; the rest are the candidate folders, in name order, minus `SKIP`.
func _versions() -> Array:
	var out: Array = [["shipped", SHIPPED]]
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	var names: Array = []
	for name in d.get_directories():
		if SKIP.has(name):
			continue
		if ResourceLoader.exists("%s/%s/water.gdshader" % [DIR, name]):
			names.append(name)
	names.sort()
	for name in names:
		out.append([name, "%s/%s/water.gdshader" % [DIR, name]])
	return out


## **Every version is handed the game's numbers**, because here the 해안선 and the hull's own marks are
## the CONTROL and only the open water is the subject. A candidate's own new dials are its own; it
## declares them and defaults them itself, and this file never writes one.
func _apply(row: Array) -> void:
	var sh: Shader = load(str(row[1]))
	if sh == null:
		push_warning("open_lab: could not load %s" % row[1])
		return
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("land_field", _field_tex)
	m.set_shader_parameter("field_origin", _field_org)
	m.set_shader_parameter("field_size", _field_siz)
	m.set_shader_parameter("field_span", WATER_FIELD_SPAN_TILES)
	m.set_shader_parameter("shore_offset", 0.0)
	m.set_shader_parameter("sea", COL_WATER)
	m.set_shader_parameter("foam", COL_WATER_FOAM)
	for k in SHORE:
		m.set_shader_parameter(str(k), SHORE[k])

	m.set_shader_parameter("wake_life", WAKE_LIFE_SEC)
	m.set_shader_parameter("wake_stern", WAKE_STERN_TILES)
	m.set_shader_parameter("wake_w", WAKE_W_TILES)
	m.set_shader_parameter("wake_hard", WAKE_HARD)
	m.set_shader_parameter("wake_alpha", WAKE_ALPHA)
	m.set_shader_parameter("wake_froth_scale", WAKE_FROTH_SCALE)
	m.set_shader_parameter("wake_froth_amt", WAKE_FROTH_AMT)
	m.set_shader_parameter("hull_half", HULL_HALF_TILES)
	m.set_shader_parameter("hull_beam", HULL_BEAM_HALF_TILES)
	m.set_shader_parameter("hull_shadow_w", HULL_SHADOW_W_TILES)
	m.set_shader_parameter("hull_shadow_bow", HULL_SHADOW_BOW)
	m.set_shader_parameter("hull_shadow_col", _hull_shadow_colour())
	m.set_shader_parameter("hull_break_at", HULL_BREAK_AT_TILES)
	m.set_shader_parameter("hull_break_w", HULL_BREAK_W_TILES)
	m.set_shader_parameter("hull_break_amt", HULL_BREAK_AMT)
	m.set_shader_parameter("hull_break_bow", HULL_BREAK_BOW)
	m.set_shader_parameter("hull_halo_tiles", HULL_HALO_TILES)
	m.set_shader_parameter("hull_halo_amt", HULL_HALO_AMT)
	m.set_shader_parameter("hull_halo_aft", HULL_HALO_AFT)
	_sea.material_override = m


## `Look.hull_shadow_colour` — the open sea, darker and a little cooler.
func _hull_shadow_colour() -> Color:
	return Color(COL_WATER.r * HULL_SHADOW_DIM,
			COL_WATER.g * HULL_SHADOW_DIM,
			minf(1.0, COL_WATER.b * HULL_SHADOW_DIM * HULL_SHADOW_COOL),
			HULL_SHADOW_ALPHA)


# --- the crossing ------------------------------------------------------------------------------------

## **Runs one hull from t = 0 to `to` at the fixed step and fills the water's twelve blocks.**
##
## ⚠⚠ **Copied from `field_view._paint_wake` and its two helpers**, so the trail in these pictures is
## the one the game draws and not a lab's idea of one. Slot 0 is where the transom is NOW and carries
## the heading in `w`; the other seven are where it has been, newest first, committed every
## `WAKE_EVERY_SEC`. **A slot with a negative time was never written.**
##
## ⚠ **The whole history is built before anything is drawn**, so the camera sees a trail of an exact
## age rather than one whose length depends on how fast this machine got through the loop.
func _drive(shot: Array, to: float) -> void:
	_wake = PackedVector4Array()
	_wake.resize(WAKE_HULLS * WAKE_SLOTS)
	for k in _wake.size():
		_wake[k] = Vector4(0.0, 0.0, -1.0, 0.0)
	_wake_t = to
	var head: Vector2 = shot[3]
	if head == Vector2.ZERO or _wake_t <= 0.0:
		_place_boat(Vector2.ZERO, Vector2.RIGHT, false)
		return
	head = head.normalized()
	var from: Vector2 = shot[2]

	var t := 0.0
	var last := -1.0
	var pos := from
	while t < _wake_t:
		var dt: float = minf(DT, _wake_t - t)
		t += dt
		pos = from + head * (BOAT_SPEED_TILES * t)
		var stern := pos + head * WAKE_STERN_TILES
		var now := Vector4(stern.x, stern.y, t, atan2(head.y, head.x))
		_wake[0] = now
		if last < 0.0 or t - last >= WAKE_EVERY_SEC:
			last = t
			for k in range(WAKE_SLOTS - 1, 1, -1):
				_wake[k] = _wake[k - 1]
			_wake[1] = now
	_place_boat(pos, head, true)


## The hull on screen. **The bob, the roll, the draft and the yaw are `field_view._paint_boats`'.**
func _place_boat(pos: Vector2, head: Vector2, shown: bool) -> void:
	if _boat == null:
		return
	_boat.visible = shown
	if not shown:
		return
	var bob := sin(_wake_t * TAU / BOAT_BOB_SEC) * BOAT_BOB_TILES
	_boat.position = Vector3(pos.x, SEA_Y_TILES + BOAT_DRAFT_TILES + bob, pos.y)
	_boat.rotation = Vector3(0.0, atan2(-head.y, head.x), 0.0)
	# ⚠ **`rotate_object_local` and not a second Euler term** — the lean is about the hull's own axis.
	_boat.rotate_object_local(Vector3.RIGHT,
			deg_to_rad(sin(_wake_t * TAU / BOAT_ROLL_SEC) * BOAT_ROLL_DEG))


## **The two clocks the picture is reproducible from**, handed over after the crossing has been driven.
##
## ⚠⚠ **`lab_t` IS THE ONLY THING IN THIS SHEET THE GAME DOES NOT HAVE, AND IT IS NOT AN OVERRIDE OF
## ANYTHING.** A candidate that animates cannot use `TIME` here — `TIME` is the engine's clock and it
## keeps running between one version's photograph and the next, so six pictures would be six different
## instants of six different mechanisms. Every candidate reads `lab_t` instead and is therefore
## photographed at the same moment as all the others.
## ⚠ **The 해안선 still rides `TIME`** and cannot be pinned without editing the shipped shader, which is
## disqualifying. **The whole shoot is about two seconds of `TIME` long** and the shore's own run is
## 6.25 s, so the border moves by about a third of one wave across the entire sheet.
func _hand_over_the_clocks() -> void:
	var m := _sea.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("wake_hull", _wake)
	m.set_shader_parameter("wake_t", _wake_t)
	m.set_shader_parameter("lab_t", _wake_t)


func _aim(shot: Array) -> void:
	_cam.size = OPEN_SIZE
	var p := deg_to_rad(CAM_PITCH_DEG)
	var back := Vector3(0.0, sin(p), cos(p))
	var at: Vector2 = shot[1]
	var target := Vector3(at.x, 0.0, at.y)
	_cam.look_at_from_position(target + back * CAM_DIST_TILES, target, Vector3.UP)


func _stage(k: int, s: int) -> void:
	_i = posmod(k, _looks.size())
	_shot = posmod(s, SHOTS.size())
	_apply(_looks[_i])
	_drive(SHOTS[_shot], float(SHOTS[_shot][4]))
	_hand_over_the_clocks()
	_aim(SHOTS[_shot])


func _show(k: int) -> void:
	_stage(k, _shot)
	if _label != null:
		_label.text = "%d  %s   [%s]\n0..9 pick (%d in all) · LEFT/RIGHT step · TAB frame · ESC quit" % [
				_i, str(_looks[_i][0]), str(SHOTS[_shot][0]), _looks.size()]


# --- shooting ----------------------------------------------------------------------------------------

func _shoot() -> bool:
	var total: int = _looks.size() * SHOTS.size()
	if _job >= total:
		return true
	var ci: int = _job / SHOTS.size()
	var si: int = _job % SHOTS.size()
	if _frame == 0:
		_stage(ci, si)
	elif _frame >= SETTLE:
		var path: String = OUT % [str(_looks[ci][0]), str(SHOTS[si][0])]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("[open_lab] %s %s" % [str(_looks[ci][0]), str(SHOTS[si][0])])
		_job += 1
		_frame = -1
	_frame += 1
	return false


# --- watching ----------------------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


## ⚠⚠ **THE LIVE LAB RUNS THE CLOCK AND THE SHEET DOES NOT, AND FOR ONE MECHANISM THAT IS THE WHOLE
## JUDGEMENT.** 「Movement rather than pattern」 has almost no signature in a still; the still shows
## what it costs when nothing is moving, and this is where it is actually looked at.
## ⚠ **The crossing loops** back to its own shot time, so the boat sails the same stretch over again
## rather than leaving the frame for good.
const LOOP_SEC := 24.0

func _watch(delta: float) -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	_live += delta
	_drive(SHOTS[_shot], float(SHOTS[_shot][4]) + fmod(_live, LOOP_SEC))
	_hand_over_the_clocks()
	# ⚠ **SHIFT is the tens digit** — there are more than ten rows once the old five come back off
	# `SKIP`, and a keyboard has ten number keys.
	var tens := 10 if Input.is_key_pressed(KEY_SHIFT) else 0
	for n in 10:
		if _tap(KEY_0 + n):
			_show(tens + n)
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	if _tap(KEY_TAB):
		_shot = posmod(_shot + 1, SHOTS.size())
		_show(_i)
	return false


func _process(delta: float) -> bool:
	if _looks.is_empty():
		return true
	if _shooting:
		return _shoot()
	return _watch(delta)
