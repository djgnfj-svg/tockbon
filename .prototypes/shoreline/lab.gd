# **One block on water, and every shoreline method tried on it.**
#
# ⚠⚠ **NOT the game.** This builds its own tiny world — one 2x2 piece, one sea plane, the game's camera
# angle and the game's sun — so a method can be judged in seconds instead of a Blender bake. Nothing here
# is imported by `src/`, and nothing here has to obey that folder's rule.
#
# It hands every version the same two fields, so a method may take its shoreline from whichever it wants:
#   · `land_field`  — SIGNED distance to the waterline, negative inland, encoded 0.5 + d / (2 * span)
#   · `depth_field` — how deep the water is in tiles, 0 on land, encoded d / span
# ⚠ **A version that needs neither simply does not declare them.**
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/shoreline/lab.gd
#       opens a window and stays. **1..9 pick a version · LEFT/RIGHT step through them · Q/E turn the
#       camera · W/S zoom · ESC quits.** The version's name is on screen.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/shoreline/lab.gd -- shoot
#       photographs every version four times and quits.
#
# ⚠ **Never `--headless`, either way**: there is no swapchain to read a frame back from and every PNG
# comes out black with no error anywhere.
extends SceneTree

const DIR := "res://.prototypes/shoreline"
const OUT := "res://.prototypes/shoreline/out/%s_%d.png"
# ⚠⚠ **FOUR FRAMES PER VERSION, SECONDS APART.** One picture cannot answer「움직이나」— a still shore and
# a shore caught mid-swing look identical in it. The shader clock runs on real time and cannot be
# advanced by hand, so the only way to photograph a change is to wait for it.
const FRAMES := 4
const GAP := 26

# The piece, in tiles. ⚠ **These mirror `tools/blender/island_build.py`** — a lab whose block is a
# different shape from the game's is a lab measuring something else.
const S := 2.0
const TOP_H := 0.14
const SKIRT := 0.75
const SKIRT_ROLL := 0.55
const SKIRT_KNEE := 0.50
const RIM_Z := -0.50
const WALL_DOWN := 1.15
const SEA_Y := 0.075
const CORNER_R := 0.34
const CORNER_PTS := 6
const EDGE_PTS := 5
const EDGE_BOW := 0.16

# The fields. ⚠ **`SPAN` has to cover the widest thing any version reads.**
const SPAN := 3.0
const SUB := 32
const MARGIN := 3.0

var _sea: MeshInstance3D = null
var _land: MeshInstance3D = null
var _looks: Array = []
var _i := 0
var _wait := 0
var _land_tex: ImageTexture = null
var _depth_tex: ImageTexture = null
var _field_lo := Vector2.ZERO
var _field_size := Vector2.ONE
## Whether this run photographs and quits, or opens and stays.
var _shooting := false
var _cam: Camera3D = null
var _label: Label = null
var _turn := 0.0
var _zoom := 4.6
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(900, 700)
	var world := Node3D.new()
	root.add_child(world)

	var ring := _ring()
	_land = MeshInstance3D.new()
	_land.mesh = _block_mesh(ring)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.760, 0.735, 0.520)
	lm.roughness = 1.0
	lm.metallic_specular = 0.1
	_land.material_override = lm
	world.add_child(_land)

	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0, 40.0)
	# ⚠ **Subdivided for the versions that MOVE the surface.** A flat quad has four corners and a
	# `vertex()` function has nothing to push; the ones that only paint do not care that it is here.
	pm.subdivide_width = 160
	pm.subdivide_depth = 160
	_sea.mesh = pm
	_sea.position = Vector3(S * 0.5, SEA_Y, S * 0.5)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_sea)

	# ⚠ **The game's light, not a studio light.** A method judged under a different sun is judged wrong.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.0
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
	cam.size = 4.6
	# ⚠⚠ **`look_at_from_position`, NOT `look_at`.** Inside `_initialize` the node is not yet considered
	# in the tree, so `look_at` errors out and leaves the camera aimed down -Z — a photograph of the sky
	# with no island in it, and the run still prints five happy lines.
	cam.look_at_from_position(Vector3(S * 0.5 + 3.0, 3.2, S * 0.5 + 3.6),
							  Vector3(S * 0.5, 0.0, S * 0.5), Vector3.UP)
	world.add_child(cam)

	_cam = cam
	_bake_fields(ring)
	_looks = _versions()
	if _looks.is_empty():
		push_error("lab: .prototypes/shoreline holds no version folder with a water.gdshader")
		return
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")
	if not _shooting:
		_label = Label.new()
		_label.position = Vector2(14, 10)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		root.add_child(_label)
		# **A bare number on the command line is which version to open on.** Coming back to compare one
		# candidate against the rest is the whole use of this thing, and pressing a key every time is
		# how the wrong one gets photographed.
		var start := 0
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			if a.is_valid_int() and int(a) >= 1 and int(a) <= _looks.size():
				start = int(a) - 1
		_show(start)


## The piece's outline at the walking surface: a square with rounded corners and bowed edges, the same
## two moves the bake makes.
func _ring() -> PackedVector2Array:
	var corn := [Vector2(0, 0), Vector2(S, 0), Vector2(S, S), Vector2(0, S)]
	var mid := Vector2(S, S) * 0.5
	var out := PackedVector2Array()
	for i in 4:
		var c: Vector2 = corn[i]
		var pv: Vector2 = corn[(i + 3) % 4]
		var nx: Vector2 = corn[(i + 1) % 4]
		var a: Vector2 = c + (pv - c).normalized() * CORNER_R
		var b: Vector2 = c + (nx - c).normalized() * CORNER_R
		# Quadratic Bezier with the corner as the control point: a fillet through where the cut was.
		for j in CORNER_PTS:
			var u := float(j) / float(CORNER_PTS - 1)
			var m := 1.0 - u
			out.append(a * (m * m) + c * (2.0 * m * u) + b * (u * u))
		# The edge from this corner to the next, bowed outward and zero at both ends.
		var e: Vector2 = nx - c
		var outw: Vector2 = (((b + (nx - b) * 0.5) - mid)).normalized()
		for j in range(1, EDGE_PTS + 1):
			var u2 := float(j) / float(EDGE_PTS + 1)
			var q: Vector2 = b + (nx + (c - nx).normalized() * CORNER_R - b) * u2
			out.append(q + outw * (EDGE_BOW * sin(PI * u2)))
	return out


func _block_mesh(ring: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := ring.size()
	var mid := Vector2(S, S) * 0.5
	var knee := PackedVector3Array()
	var hem := PackedVector3Array()
	var foot := PackedVector3Array()
	var kz: float = TOP_H - (TOP_H - RIM_Z) * SKIRT_KNEE
	for i in n:
		var p: Vector2 = ring[i]
		var o: Vector2 = (p - mid).normalized()
		knee.append(Vector3(p.x + o.x * SKIRT * SKIRT_ROLL, kz, p.y + o.y * SKIRT * SKIRT_ROLL))
		hem.append(Vector3(p.x + o.x * SKIRT, RIM_Z, p.y + o.y * SKIRT))
		foot.append(Vector3(p.x + o.x * SKIRT, -WALL_DOWN, p.y + o.y * SKIRT))
	var ctr := Vector3(mid.x, TOP_H, mid.y)
	for i in n:
		var j := (i + 1) % n
		var a := Vector3(ring[i].x, TOP_H, ring[i].y)
		var b := Vector3(ring[j].x, TOP_H, ring[j].y)
		_tri(st, ctr, a, b)
		_tri(st, a, knee[i], knee[j])
		_tri(st, a, knee[j], b)
		_tri(st, knee[i], hem[i], hem[j])
		_tri(st, knee[i], hem[j], knee[j])
		_tri(st, hem[i], foot[i], foot[j])
		_tri(st, hem[i], foot[j], hem[j])
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## **Both fields, off the same profile.** The waterline is where the skirt crosses `SEA_Y`, walked from
## the top edge outward — the same walk the Blender bake does, so the lab and the game agree.
func _bake_fields(ring: PackedVector2Array) -> void:
	var n := ring.size()
	var mid := Vector2(S, S) * 0.5
	var kz: float = TOP_H - (TOP_H - RIM_Z) * SKIRT_KNEE
	var knee_out: float = SKIRT * SKIRT_ROLL
	var wline := PackedVector2Array()
	var reach := 0.0
	if TOP_H >= SEA_Y and SEA_Y >= kz:
		reach = (TOP_H - SEA_Y) / maxf(TOP_H - kz, 1e-6) * knee_out
	else:
		reach = knee_out + (kz - SEA_Y) / maxf(kz - RIM_Z, 1e-6) * (SKIRT - knee_out)
	for i in n:
		var p: Vector2 = ring[i]
		wline.append(p + (p - mid).normalized() * reach)
	_wline = wline

	_field_lo = Vector2(-MARGIN, -MARGIN)
	_field_size = Vector2(S + MARGIN * 2.0, S + MARGIN * 2.0)
	var tw := int(_field_size.x * float(SUB))
	var th := int(_field_size.y * float(SUB))
	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	var dep := PackedFloat32Array()
	dep.resize(tw * th)
	for py in th:
		var wy: float = _field_lo.y + (float(py) + 0.5) / float(SUB)
		for px in tw:
			var wx: float = _field_lo.x + (float(px) + 0.5) / float(SUB)
			var q := Vector2(wx, wy)
			var best := 1e9
			for i in n:
				var a: Vector2 = wline[i]
				var b: Vector2 = wline[(i + 1) % n]
				var e: Vector2 = b - a
				var l2: float = e.length_squared()
				var u: float = 0.0 if l2 <= 0.0 else clampf((q - a).dot(e) / l2, 0.0, 1.0)
				best = minf(best, (q - (a + e * u)).length())
			var sd: float = -best if _inside(q, wline) else best
			dist[py * tw + px] = clampf(0.5 + sd / (SPAN * 2.0), 0.0, 1.0)
			# **How deep the water is here.** On the rock it is zero; off the hem the wall drops away
			# and the field simply saturates.
			var ground := -WALL_DOWN
			if sd <= 0.0:
				# Inland of the waterline: walk back UP the same profile the mesh is built from.
				var back := -sd
				if _inside(q, ring):
					ground = TOP_H
				else:
					ground = lerpf(SEA_Y, TOP_H, clampf(back / maxf(reach, 1e-6), 0.0, 1.0))
			else:
				# Seaward: down the rest of the roll, then the wall.
				var f := clampf(sd / maxf(SKIRT - reach, 1e-6), 0.0, 1.0)
				ground = lerpf(SEA_Y, RIM_Z, f)
				if sd > SKIRT - reach:
					ground = -WALL_DOWN
			dep[py * tw + px] = clampf((SEA_Y - ground) / SPAN, 0.0, 1.0)
	_land_tex = ImageTexture.create_from_image(
		Image.create_from_data(tw, th, false, Image.FORMAT_RF, dist.to_byte_array()))
	_depth_tex = ImageTexture.create_from_image(
		Image.create_from_data(tw, th, false, Image.FORMAT_RF, dep.to_byte_array()))


func _inside(q: Vector2, poly: PackedVector2Array) -> bool:
	var c := false
	var n := poly.size()
	var j := n - 1
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > q.y) != (b.y > q.y):
			if q.x < a.x + (q.y - a.y) / (b.y - a.y) * (b.x - a.x):
				c = not c
		j = i
	return c


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


## Anything a version adds to the world beyond its water shader. ⚠ **Torn down before the next one**,
## or version four is photographed wearing version three's geometry.
var _extra: Node3D = null


func _apply(name: String) -> void:
	if _extra != null:
		_extra.queue_free()
		_extra = null
	var sh: Shader = load("%s/%s/water.gdshader" % [DIR, name])
	var m := ShaderMaterial.new()
	m.shader = sh
	# Handed to every version; one that does not declare them ignores them.
	m.set_shader_parameter("land_field", _land_tex)
	m.set_shader_parameter("depth_field", _depth_tex)
	m.set_shader_parameter("field_origin", _field_lo)
	m.set_shader_parameter("field_size", _field_size)
	m.set_shader_parameter("field_span", SPAN)
	m.set_shader_parameter("sea_y", SEA_Y)
	_sea.material_override = m
	# **A version may also build geometry** — a ring of foam quads, a different block, anything. It says
	# so by carrying a `scene.gd` with `static func build(lab) -> Node3D`.
	var extra_path := "%s/%s/scene.gd" % [DIR, name]
	if ResourceLoader.exists(extra_path):
		var scr: GDScript = load(extra_path)
		_extra = scr.build(self)
		if _extra != null:
			_sea.get_parent().add_child(_extra)


## The watched run: one version on screen, and the keys that change it.
func _show(k: int) -> void:
	_i = posmod(k, _looks.size())
	_apply(str(_looks[_i]))
	if _label != null:
		_label.text = "%d/%d  %s
1..%d pick · ←→ step · Q/E turn · W/S zoom · ESC quit" % [
			_i + 1, _looks.size(), str(_looks[_i]), _looks.size()]


func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


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
	if Input.is_key_pressed(KEY_Q):
		_turn -= delta * 1.2
	if Input.is_key_pressed(KEY_E):
		_turn += delta * 1.2
	if Input.is_key_pressed(KEY_W):
		_zoom = maxf(1.6, _zoom - delta * 3.0)
	if Input.is_key_pressed(KEY_S):
		_zoom = minf(12.0, _zoom + delta * 3.0)
	var mid := Vector3(S * 0.5, 0.0, S * 0.5)
	var r := 4.7
	_cam.size = _zoom
	_cam.look_at_from_position(mid + Vector3(sin(_turn) * r, 3.2, cos(_turn) * r), mid, Vector3.UP)
	return false


func _process(_delta: float) -> bool:
	if not _shooting:
		return _watch(_delta)
	_wait += 1
	if _wait < (20 if _i % (FRAMES + 1) == 0 else GAP):
		return false
	_wait = 0
	var per := FRAMES + 1
	if _i >= _looks.size() * per:
		return true
	var k: int = _i / per
	var step: int = _i % per
	if step == 0:
		_apply(str(_looks[k]))
	else:
		# ⚠ **Apply on one step, SHOOT on the next.** `get_texture()` hands back the frame already drawn,
		# so doing both in one step files every picture under the previous version's name.
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT % [str(_looks[k]), step - 1]))
		print("[lab] %s %d" % [str(_looks[k]), step - 1])
	_i += 1
	return false


## The waterline polygon, for a version that wants to build geometry on it.
func waterline() -> PackedVector2Array:
	return _wline


var _wline := PackedVector2Array()
