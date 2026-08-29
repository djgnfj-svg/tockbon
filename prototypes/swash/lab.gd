# **The island as a WAFER on water, and every way of moving its shoreline tried on it.**
#
# ⚠⚠ **NOT the game, and not `prototypes/shoreline/` either.** That lab asked *where does the white
# line come from* and the answer was settled: distance to the baked outline. **This one asks the next
# question — HOW DOES THAT LINE MOVE** — and it is a different question, so it gets a different world.
#
# **Why a wafer** (2026-08-29, the user: 「완전 얇은 판을 만들어서 거기서 진행해줘」 — *"make a
# completely thin slab and work on that"*). The block lab stood one 2x2 piece up with a skirt, a rim and
# a wall, and **the rock's own shadow fell across the very line being judged.** Here the land is
# `THICK` tiles tall and nothing else: the outline is a vertical cut, the sun has nothing to cast a
# shadow onto, and **every pixel that differs between two versions is water.**
#
# ⚠⚠ **The outline is the REAL island's**, read out of `assets/terrain/island.json` — the segments the
# Blender bake writes, chained into one closed loop. **A square would have answered nothing**: three of
# the candidates below only differ from the rest where the coast bends, and a square has no bay.
# ⚠ **How many segments that is changes every time the island is re-baked**, so nothing here counts them.
#
# Every version is handed the same one field:
#   · `land_field` — SIGNED distance to the outline, negative inland, encoded 0.5 + d / (2 * span)
# ⚠ **A version takes its gradient from that field itself** by sampling it twice more. There is no
# second texture: the whole point of most of these candidates is that the gradient was always there to
# be read and nothing was reading it.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/lab.gd
#       opens a window and stays. **1..9 pick a version · LEFT/RIGHT step · Q/E turn · W/S zoom ·
#       F flips between the whole island and one stretch of coast up close · ESC quits.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/swash/lab.gd -- shoot
#       photographs every version four times, close up, and quits.
#
# ⚠ **Never `--headless`, either way**: there is no swapchain to read a frame back from and every PNG
# comes out black with no error anywhere.
extends SceneTree

const DIR := "res://prototypes/swash"
const OUT := "res://prototypes/swash/out/%s_%d.png"
const ISLAND := "res://assets/terrain/island.json"

# ⚠⚠ **FOUR FRAMES PER VERSION, SECONDS APART.** One picture cannot answer 「움직이나」 — a still shore
# and a shore caught mid-swing look identical in it. The shader clock runs on real time and cannot be
# advanced by hand, so the only way to photograph a change is to wait for it.
const FRAMES := 4
## ⚠⚠ **SECONDS, NOT FRAMES.** This was a frame count and the whole shoot finished in nine seconds:
## with no vsync in script mode the four "seconds apart" pictures of a version were a fifth of a second
## apart, and **every candidate was photographed four times at the same instant of its own cycle.**
## The lab reported nine motions and had measured none of them.
const GAP_SEC := 1.6
const WARM_SEC := 0.4

## **How thick the wafer is, in tiles.** Thin enough that the cut face is a hairline at this camera
## angle, thick enough that the top face never z-fights the sea.
## ⚠⚠ **0.06 WAS TOO THIN AND IT DID NOT FAIL HONESTLY.** Six centimetres of separation is under this
## depth buffer's resolution at the default far plane, so the sea won the fight over the island's
## interior **in some versions and not others** — 01 came out correct and 03 came out with a white
## island, from the same geometry. **A z-fight that only shows on half the candidates is a lab that
## reports a difference the shaders do not have.** The far plane is pulled in as well, below.
const THICK := 0.20
const SEA_Y := 0.0

# The field. ⚠ **`SPAN` has to cover the widest thing any version reads** — the travelling lines get
# about a tile out, so two and a half is room to spare.
const SPAN := 2.5
## Texels per tile. ⚠⚠ **16, the same as the game's bake** — the line is under a tenth of a tile wide
## and at 4 texels per tile it comes out dashed wherever the coast is not axis-aligned.
const SUB := 16
const MARGIN := 2.5

## Where the close-up sits and how wide it is, in tiles. **A stretch of coast with a point and a bay in
## it** — the whole island at once is how a difference between two candidates gets averaged away.
const NEAR_AT := Vector2(4.2, 8.0)
## ⚠ **Seven, not five.** At five the frame was most island and one edge of water; what is being judged
## is the water, so the coast belongs across the middle with sea on both sides of the frame.
const NEAR_SIZE := 7.0

var _sea: MeshInstance3D = null
var _land: MeshInstance3D = null
var _looks: Array = []
var _i := 0
var _clock := 0.0
var _land_tex: ImageTexture = null
var _field_lo := Vector2.ZERO
var _field_size := Vector2.ONE
var _ring := PackedVector2Array()
var _mid := Vector2(8.0, 6.0)
var _shooting := false
var _cam: Camera3D = null
var _label: Label = null
var _turn := 0.0
var _zoom := 14.0
var _near := false
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(1000, 780)
	var world := Node3D.new()
	root.add_child(world)

	_ring = _read_outline()
	if _ring.size() < 8:
		push_error("lab: assets/terrain/island.json gave no closed outline")
		return
	var lo := _ring[0]
	var hi := _ring[0]
	for p in _ring:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_mid = (lo + hi) * 0.5

	# **The wafer is a plane with the island cut out of it**, not a triangulated outline — see the head
	# of `land.gdshader` for what happened when it was the latter.
	_land = MeshInstance3D.new()
	var lp := PlaneMesh.new()
	lp.size = Vector2(60.0, 60.0)
	_land.mesh = lp
	_land.position = Vector3(_mid.x, SEA_Y + THICK, _mid.y)
	_land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_land)

	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	# ⚠ **Subdivided for any version that MOVES the surface.** A flat quad has four corners and a
	# `vertex()` function has nothing to push; the ones that only paint do not care that it is here.
	pm.subdivide_width = 200
	pm.subdivide_depth = 200
	_sea.mesh = pm
	_sea.position = Vector3(_mid.x, SEA_Y, _mid.y)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_sea)

	# ⚠ **The game's light, not a studio light.** A method judged under a different sun is judged wrong.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
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
	# ⚠ **A far plane of 4000 over a world 17 tiles wide** spends the whole depth buffer on empty space.
	cam.near = 0.5
	cam.far = 60.0
	# ⚠⚠ **`look_at_from_position`, NOT `look_at`.** Inside `_initialize` the node is not yet considered
	# in the tree, so `look_at` errors out and leaves the camera aimed down -Z — a photograph of the sky
	# with no island in it, and the run still prints five happy lines.
	cam.look_at_from_position(Vector3(_mid.x, 9.0, _mid.y + 10.0),
							  Vector3(_mid.x, 0.0, _mid.y), Vector3.UP)
	world.add_child(cam)
	_cam = cam

	_bake_field()
	var lm := ShaderMaterial.new()
	lm.shader = load("%s/land.gdshader" % DIR)
	lm.set_shader_parameter("land_field", _land_tex)
	lm.set_shader_parameter("field_origin", _field_lo)
	lm.set_shader_parameter("field_size", _field_size)
	lm.set_shader_parameter("field_span", SPAN)
	_land.material_override = lm

	_looks = _versions()
	if _looks.is_empty():
		push_error("lab: prototypes/swash holds no version folder with a water.gdshader")
		return
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")
	if _shooting:
		# ⚠ **Photographs are taken CLOSE UP.** At island width the line is three pixels across and two
		# candidates that differ completely come out as the same picture.
		_near = true
		_zoom = NEAR_SIZE
		_aim()
	else:
		_label = Label.new()
		_label.position = Vector2(14, 10)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		root.add_child(_label)
		# **A bare number on the command line is which version to open on.** Coming back to compare one
		# candidate against the rest is the whole use of this thing.
		var start := 0
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			if a.is_valid_int() and int(a) >= 1 and int(a) <= _looks.size():
				start = int(a) - 1
		_show(start)


## **The real island's outline, chained into one loop.** The bake writes 112 segments in no particular
## order; they are joined end to end here. ⚠ Rounded before matching — the endpoints agree to four
## decimals in the file and to nothing at all in binary.
func _read_outline() -> PackedVector2Array:
	var f := FileAccess.open(ISLAND, FileAccess.READ)
	if f == null:
		return PackedVector2Array()
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("coast"):
		return PackedVector2Array()
	var nxt := {}
	var first := Vector2.ZERO
	var have_first := false
	for s in data["coast"]:
		var a := Vector2(snappedf(float(s[0]), 0.001), snappedf(float(s[1]), 0.001))
		var b := Vector2(snappedf(float(s[2]), 0.001), snappedf(float(s[3]), 0.001))
		nxt[a] = b
		if not have_first:
			first = a
			have_first = true
	var out := PackedVector2Array()
	var cur := first
	for _n in range(nxt.size() + 2):
		out.append(cur)
		if not nxt.has(cur):
			break
		cur = nxt[cur]
		if cur == first:
			break
	return out


## **The signed distance field, and it is baked in two passes because one pass is too slow.**
## ⚠⚠ **Distance is SCATTERED, not gathered**: measuring every texel against all 112 segments is eleven
## million operations and GDScript takes most of a minute over it. Each segment instead writes only into
## the box it can possibly reach, which is under a tenth of the work and exactly the same answer.
## **The sign is a scanline fill** — one crossing list per row rather than a point-in-polygon per texel.
func _bake_field() -> void:
	var lo := _ring[0]
	var hi := _ring[0]
	for p in _ring:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_field_lo = lo - Vector2(MARGIN, MARGIN)
	_field_size = (hi - lo) + Vector2(MARGIN, MARGIN) * 2.0
	var tw := int(_field_size.x * float(SUB))
	var th := int(_field_size.y * float(SUB))
	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	dist.fill(SPAN)

	var n := _ring.size()
	for i in n:
		var a: Vector2 = _ring[i]
		var b: Vector2 = _ring[(i + 1) % n]
		var e: Vector2 = b - a
		var l2: float = e.length_squared()
		var bl := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(SPAN, SPAN)
		var tr := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(SPAN, SPAN)
		var x0 := maxi(0, int((bl.x - _field_lo.x) * float(SUB)))
		var x1 := mini(tw - 1, int((tr.x - _field_lo.x) * float(SUB)))
		var y0 := maxi(0, int((bl.y - _field_lo.y) * float(SUB)))
		var y1 := mini(th - 1, int((tr.y - _field_lo.y) * float(SUB)))
		for py in range(y0, y1 + 1):
			var wy: float = _field_lo.y + (float(py) + 0.5) / float(SUB)
			var row := py * tw
			for px in range(x0, x1 + 1):
				var wx: float = _field_lo.x + (float(px) + 0.5) / float(SUB)
				var q := Vector2(wx, wy)
				var u: float = 0.0 if l2 <= 0.0 else clampf((q - a).dot(e) / l2, 0.0, 1.0)
				var dd: float = (q - (a + e * u)).length()
				if dd < dist[row + px]:
					dist[row + px] = dd

	# The sign, one row at a time: every crossing of the ring by this row, sorted, and the spans
	# between an odd and an even crossing are land.
	var enc := PackedFloat32Array()
	enc.resize(tw * th)
	for py in th:
		var wy: float = _field_lo.y + (float(py) + 0.5) / float(SUB)
		var xs := PackedFloat32Array()
		for i in n:
			var a: Vector2 = _ring[i]
			var b: Vector2 = _ring[(i + 1) % n]
			if (a.y > wy) != (b.y > wy):
				xs.append(a.x + (wy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var row := py * tw
		var k := 0
		var inside := false
		for px in tw:
			var wx: float = _field_lo.x + (float(px) + 0.5) / float(SUB)
			while k < xs.size() and wx >= xs[k]:
				inside = not inside
				k += 1
			var sd: float = -dist[row + px] if inside else dist[row + px]
			enc[row + px] = clampf(0.5 + sd / (SPAN * 2.0), 0.0, 1.0)

	_land_tex = ImageTexture.create_from_image(
		Image.create_from_data(tw, th, false, Image.FORMAT_RF, enc.to_byte_array()))
	print("[lab] field %dx%d texels over %.1f x %.1f tiles" % [tw, th, _field_size.x, _field_size.y])


func _versions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if name == "out":
			continue
		if ResourceLoader.exists("%s/%s/water.gdshader" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


func _apply(name: String) -> void:
	var sh: Shader = load("%s/%s/water.gdshader" % [DIR, name])
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("land_field", _land_tex)
	m.set_shader_parameter("field_origin", _field_lo)
	m.set_shader_parameter("field_size", _field_size)
	m.set_shader_parameter("field_span", SPAN)
	_sea.material_override = m


func _show(k: int) -> void:
	_i = posmod(k, _looks.size())
	_apply(str(_looks[_i]))
	if _label != null:
		_label.text = "%d/%d  %s\n1..%d pick · LEFT/RIGHT step · Q/E turn · W/S zoom · F near/far · ESC quit" % [
			_i + 1, _looks.size(), str(_looks[_i]), _looks.size()]


func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


## Where the camera looks and how far away, for whichever of the two framings is on.
func _aim() -> void:
	var at := NEAR_AT if _near else _mid
	_cam.size = _zoom
	var r := 11.0
	_cam.look_at_from_position(Vector3(at.x + sin(_turn) * r, 8.0, at.y + cos(_turn) * r),
							   Vector3(at.x, 0.0, at.y), Vector3.UP)


func _watch(delta: float) -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in _looks.size():
		if _tap(KEY_1 + n):
			_show(n)
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	if _tap(KEY_F):
		_near = not _near
		_zoom = NEAR_SIZE if _near else 14.0
	if Input.is_key_pressed(KEY_Q):
		_turn -= delta * 1.2
	if Input.is_key_pressed(KEY_E):
		_turn += delta * 1.2
	if Input.is_key_pressed(KEY_W):
		_zoom = maxf(2.0, _zoom - delta * 6.0)
	if Input.is_key_pressed(KEY_S):
		_zoom = minf(26.0, _zoom + delta * 6.0)
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
		_apply(str(_looks[k]))
	else:
		# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already
		# drawn, so doing both in one step files every picture under the previous version's name.
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT % [str(_looks[k]), step - 1]))
		print("[lab] %s %d" % [str(_looks[k]), step - 1])
	_i += 1
	return false
