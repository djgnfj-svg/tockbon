# **Five trees on the outlying island, lit and sitting in a shadow.**
#
# ⚠⚠ **Everything else is gone** (2026-08-29, the user: 「다 치우고 나무들만 한 곳을 몰아서」). No
# grass, no flowers, no reeds, no rock — the previous round scattered nine kinds over the whole
# island, and the question being asked here is only about trees.
#
# **The three things this adds over a bare card**, each read off the reference the user handed over
# rather than argued for:
#   - **the card is LIT** — a normal map is baked from the silhouette (`bake_normals.py`), so a
#     crown bulges toward the sun instead of coming out one flat colour;
#   - **the card sits in a shadow** — a wide soft pool on the grass, not a cast shadow of a plane;
#   - **the card is drawn twice**, dark and swollen first, which is Bad North's own way of giving a
#     clump one common outline.
#
# ⚠ **This lab drives the REAL game.** It opens `Game`, presses 시작하기, and hangs the trees in the
# field's own world, under the game's own camera and sun.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/props/lab.gd
#       opens a window and stays. **SPACE reseeds.** Q/E turn · R/F tilt · wheel zoom · ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s .prototypes/props/lab.gd -- shoot
#       photographs the outlying island twice — whole board, then zoomed in — and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const DIR := "res://.prototypes/props"
const OUT := "res://.prototypes/props/out/board_%s.png"
const NEAR_NOTCHES := 7

## **The trees, and how often each is drawn.** Height is in 조각, and a 조각 is one metre.
## ⚠⚠ **ONE tree, and only its size changes** (2026-08-29, the user: 「종류가 많이 있을 필요도
## 없어. 하나에서 사이즈만 막 왔다 갔다 하면 돼」). Three kinds were built and thrown away.
## ⚠⚠ **And it is almost a single colour** (the same round: 「너무 표현해... 단순하게 단색으로
## 거의. 그림자가 있으면 된다니까」). `flatten.py` keeps pixellab's SHAPE and throws away everything
## painted into it — the leaf texture, the baked highlight, the two-tone crown. What shading the tree
## has comes from the game's own sun through the baked normal, and from the pool it sits in.
const TREE := "tree.png"
## How tall one tree stands, in 조각 — a 조각 is one metre. **The only thing that varies.**
const TALL := Vector2(1.6, 3.6)
const HOW_MANY := 5

## **The ink copy**: how much bigger, and how far it is pushed straight away from the camera.
## ⚠⚠ **The camera is ORTHOGONAL, so pushing along its forward axis moves the ink in depth and NOT
## on screen.** Pushing it down in world space instead — tried twice — left half the trees solid
## black wherever the drop happened to read as nearer.
## ⚠ **Thinned 2026-08-29** (the user: 「테두리도 너무 두꺼워」). At 1.05 the ink was a fifth of a
## metre proud of a three-metre tree and read as a shadow rather than as a line.
const INK_SWELL := 1.022
const INK_BACK := 0.9

## How wide the shadow pool is against the tree's own height, and how far it floats over the grass.
const POOL_W := 0.95
const POOL_LIFT := 0.02

## How strongly the baked normal map bends the light. **1.0 is the map as baked**; under this game's
## single sun a card needs more than that before the bulge is visible at all.
const NORMAL_DEPTH := 2.2
## How far the card's own colour is scaled down before the sun multiplies it back up.
## ⚠⚠ **The card is a FINISHED colour, not an albedo**, and this game's sun plus ambient roughly
## doubles what it is handed. Three values were tried on screen: 0.55 buried the busy high-res cards,
## 0.8 turned the flat sage into pale mint, and 0.48 lands on the reference's own dark green.
const TINT := 0.48

var game: Game = null
var field: FieldView = null
var grid: Grid = null

var _extra: Node3D = null
var _inks: Array[MeshInstance3D] = []
var _aimed := Vector3.ZERO
var _tex := {}
var _quad: QuadMesh = null
var _seed := 3
var _wait := 0
var _boot := 0
var _shot := 0
var _booted := false
var _shooting := false
var _label: Label = null
var _held := {}


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if not _booted:
		return _boot_step()
	if _shooting:
		return _shoot_step()
	return _watch()


# --- getting to the island ---------------------------------------------------------------------

func _boot_step() -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			game._unhandled_input(ev)
		1:
			for _i in 120:
				game._process(1.0 / 60.0)
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			_booted = true
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE
			# The quad is built centred, so its foot has to be lifted onto the node's origin.
			_quad.center_offset = Vector3(0.0, 0.5, 0.0)
			_plant()
			if not _shooting:
				# Open on the trees rather than on the whole board: at the far zoom the outlying
				# island is a thumbnail and the question is about the trees on it.
				_zoom(NEAR_NOTCHES)
				_centre_on_outlier()
				_label = Label.new()
				_label.position = Vector2(14, 10)
				_label.add_theme_font_size_override("font_size", 22)
				_label.add_theme_color_override("font_color", Color(1, 1, 1))
				_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				_label.add_theme_constant_override("outline_size", 6)
				_label.text = "five lit trees on the outlying island\nSPACE reseed · Q/E turn · R/F tilt · wheel zoom · ESC quit"
				root.add_child(_label)
	_boot += 1
	return false


# --- where they go ------------------------------------------------------------------------------

## **The smallest patch of land that does not touch the main island.**
## ⚠ It is found rather than typed: the island file is rebuilt by a Blender run, and a hard-coded
## coordinate would quietly point at open water the next time the coast moves.
func _outlier() -> Array:
	var seen := {}
	var best: Array = []
	for t in grid.w * grid.h:
		if grid.water[t] == 1 or seen.has(t):
			continue
		var lump: Array = []
		var stack: Array = [t]
		seen[t] = true
		while not stack.is_empty():
			var c: int = stack.pop_back()
			lump.append(c)
			var cx := c % grid.w
			var cy := c / grid.w
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + off.x
				var ny: int = cy + off.y
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var n := grid.tile_index(nx, ny)
				if grid.water[n] == 1 or seen.has(n):
					continue
				seen[n] = true
				stack.append(n)
		if best.is_empty() or lump.size() < best.size():
			best = lump
	return best


## The middle of the outlying patch, in 조각.
func _outlier_mid() -> Vector2:
	var lump := _outlier()
	if lump.is_empty():
		return Vector2(float(grid.w) * 0.5, float(grid.h) * 0.5)
	var mid := Vector2.ZERO
	for t in lump:
		mid += Vector2(float(t % grid.w) + 0.5, float(t / grid.w) + 0.5)
	return mid / float(lump.size())


## **Bring the outlying island to the middle of the screen.** The field exposes no 「centre on this」
## call, so the point is put through the field's own forward transform and the gap is panned away.
func _centre_on_outlier() -> void:
	var mid := _outlier_mid()
	var on_glass := field.world_to_screen_px(Look.tile_point_px(mid), Islands.base_h())
	field.pan_by(Look.viewport_size_px() * 0.5 - on_glass)


func _plant() -> void:
	if _extra != null:
		_extra.queue_free()
		_extra = null
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_extra = Node3D.new()
	_inks.clear()
	field._world.add_child(_extra)
	var mid := _outlier_mid()
	for _n in HOW_MANY:
		var tall := rng.randf_range(TALL.x, TALL.y)
		var a := rng.randf() * TAU
		# ⚠ **sqrt, not a flat radius** — without it five trees stand in a ring with a hole in it.
		var r: float = 0.9 * sqrt(rng.randf())
		var at := mid + Vector2(cos(a), sin(a)) * r
		var tx := clampi(int(at.x), 0, grid.w - 1)
		var ty := clampi(int(at.y), 0, grid.h - 1)
		var y := Islands.ground_h(grid.level_at(tx, ty))
		_pool(at, y, tall)
		_pair(TREE, at, y, tall)
	_aim_ink()


# --- what one tree is ----------------------------------------------------------------------------

## **The picture, read straight off disk.** ⚠ **Not `load()`**: a throwaway folder has no `.import`
## beside its assets, and `load()` on a bare `.png` fails outside the editor.
func _card_tex(file: String) -> ImageTexture:
	if _tex.has(file):
		return _tex[file]
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(DIR + "/" + file)) != OK:
		push_error("lab: cannot read " + file)
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[file] = t
	return t


## **The two draws: the ink, then the lit card, on the same spot.**
func _pair(file: String, at: Vector2, y: float, tall: float) -> void:
	var tex := _card_tex(file)
	if tex == null:
		return
	var nrm := _card_tex(file.replace(".png", "_n.png"))
	var wide := tall * float(tex.get_width()) / float(tex.get_height())
	var ink := _card(tex, nrm, true)
	ink.position = Vector3(at.x, y, at.y)
	ink.scale = Vector3(wide * INK_SWELL, tall * INK_SWELL, 1.0)
	# ⚠ **Dropped by half the growth.** The quad's foot is its origin, so scaling it up grows the
	# card UPWARD only — the ink appeared as a black cap on the crown with no line down the sides.
	# Half the extra height back down turns it into a ring around the whole tree.
	ink.position.y -= tall * (INK_SWELL - 1.0) * 0.5
	ink.set_meta("home", ink.position)
	_inks.append(ink)
	_extra.add_child(ink)
	var lit := _card(tex, nrm, false)
	lit.position = Vector3(at.x, y, at.y)
	lit.scale = Vector3(wide, tall, 1.0)
	_extra.add_child(lit)


func _card(tex: ImageTexture, nrm: ImageTexture, is_ink: bool) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "/tree.gdshader")
	m.set_shader_parameter("card", tex)
	if nrm != null:
		m.set_shader_parameter("card_n", nrm)
	m.set_shader_parameter("normal_depth", NORMAL_DEPTH)
	m.set_shader_parameter("tint", TINT)
	m.set_shader_parameter("silhouette", is_ink)
	m.set_shader_parameter("ink", Look.COL_OUTLINE)
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = m
	# ⚠ **No cast shadow**: the shadow of a plane that keeps turning is a shape that keeps changing,
	# and the pool under the tree does that job instead.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ⚠ **The billboard happens in the vertex shader**, so the engine's own bounds are wrong for it
	# and the card is culled while still on screen without this margin.
	mi.extra_cull_margin = 4.0
	return mi


## **The pool the tree sits in** — a disc lying flat on the grass, multiplying the light out of it.
func _pool(at: Vector2, y: float, tall: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "/shadow.gdshader")
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := tall * POOL_W
	mi.scale = Vector3(w, 1.0, w)
	mi.position = Vector3(at.x, y + POOL_LIFT, at.y)
	_extra.add_child(mi)


## **Push every ink draw straight away from the camera.** Re-aimed whenever the camera turns.
func _aim_ink() -> void:
	if field == null or field._cam == null:
		return
	var fwd: Vector3 = -field._cam.global_transform.basis.z
	if fwd.is_equal_approx(_aimed):
		return
	_aimed = fwd
	for ink in _inks:
		ink.position = (ink.get_meta("home") as Vector3) + fwd * INK_BACK


# --- the two shots ------------------------------------------------------------------------------

func _shoot_step() -> bool:
	match _shot:
		0:
			pass
		1:
			# ⚠ **Let a frame through, THEN read it back.** `get_texture()` hands back the frame
			# already drawn, so shooting on the same step files the picture of the empty board.
			_save("far")
		2:
			_zoom(NEAR_NOTCHES)
			# ⚠ **Centred AFTER the zoom, and only then.** `_clamp_cam` pins the camera to the middle
			# of the map whenever the whole board fits on the glass, so a pan at the far zoom is
			# thrown away without a word.
			_centre_on_outlier()
		3:
			_save("near")
		_:
			return true
	_shot += 1
	return false


func _zoom(notches: int) -> void:
	var at := Look.viewport_size_px() * 0.5
	var f := Look.ZOOM_STEP if notches > 0 else 1.0 / Look.ZOOM_STEP
	for _n in absi(notches):
		field.zoom_at(at, f)


func _save(which: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "/out"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % which))
	print("[lab] board %s" % which)


# --- the watched run ----------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	if _tap(KEY_SPACE):
		_seed += 1
		_plant()
	# ⚠ **Re-aimed every frame**: Q/E turn the camera, and an ink pushed along the old forward axis
	# swings out from behind its card and reads as a second, black tree.
	_aim_ink()
	return false
