# **Four ways for the 조각 판 to become one 칸 when the camera pulls back.**
#
# ⚠⚠ **It drives the REAL game** and hides the baked 판, then hangs one version's own board in the
# field's world. What is being judged is what happens BETWEEN two distances, so every version is
# photographed at three of them.
#
# **Two ways to run it, and the default is the one you WATCH.**
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/merge/lab.gd
#       opens a window and stays. **1..4 pick a version · LEFT/RIGHT step.** The game's own wheel
#       zooms, and the merge follows it live — which is the thing to look at. ESC quits.
#
#   Godot_v4.7.1-stable_win64.exe --path . -s prototypes/merge/lab.gd -- shoot
#       photographs every version at three distances and quits.
#
# ⚠ **Never `--headless`**: there is no swapchain to read a frame back from and every PNG comes out
# black with no error anywhere.
extends SceneTree

const DIR := "res://prototypes/merge"
const OUT := "res://prototypes/merge/out/%s_%s.png"

## **The merge is driven by ZOOM and by nothing else** (2026-08-29, the user: 「멀면 칸단위로 하려고함
## 줌에따라」). Below `ZOOM_MERGED` a 칸 is one lump; above `ZOOM_APART` the 조각 are separate; between
## them it is a straight ramp. ⚠ **The same numbers for every version** — the ramp is not what is being
## judged, the mechanism is.
const ZOOM_MERGED := 0.72
const ZOOM_APART := 1.45

## The three distances every version is photographed at.
const SHOTS := [["far", 0.55], ["mid", 0.95], ["near", 1.70]]

var game: Game = null
var field: FieldView = null
var grid: Grid = null

var _names: Array = []
var _extra: Node3D = null
var _mats: Array = []
var _i := 0
var _wait := 0
var _boot := 0
var _shot := 0
var _booted := false
var _shooting := false
var _label: Label = null
var _held := {}
## **The 조각 under the cursor, or -1.** Read straight from the shell so the lab and the game cannot
## disagree about which 조각 that is.
var hover_tile := -1


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	game = Game.new()
	root.add_child(game)
	_shooting = OS.get_cmdline_args().has("shoot") or OS.get_cmdline_user_args().has("shoot")


func _process(_d: float) -> bool:
	if _booted and not _shooting:
		return _watch()
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	if not _booted:
		return _boot_step()
	return _shoot_step()


func _boot_step() -> bool:
	match _boot:
		0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Look.title_slot_hit_rect_px(0).get_center()
			game._unhandled_input(ev)
		1:
			for _n in 120:
				game._process(1.0 / 60.0)
		2:
			field = game.field_view
			grid = game.battle.grid if game.battle != null else null
			if field == null or grid == null:
				push_error("lab: 시작하기 did not open an island")
				return true
			# ⚠ **The shipped 판 is switched off, not left under.** Two boards on one island is two
			# answers photographed as one.
			if field._pads != null:
				field._pads.visible = false
			_names = _find_versions()
			if _names.is_empty():
				push_error("lab: prototypes/merge holds no version folder with a scene.gd")
				return true
			_booted = true
			if _shooting:
				# **A photographed run has no cursor**, so one 조각 is hovered by hand — two east of
				# the body, in frame and clear of the body's own picture.
				var b: Vector2i = _body_tile() + Vector2i(2, 0)
				hover_tile = grid.tile_index(b.x, b.y)
			if not _shooting:
				_label = Label.new()
				_label.position = Vector2(14, 10)
				_label.add_theme_font_size_override("font_size", 22)
				_label.add_theme_color_override("font_color", Color(1, 1, 1))
				_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				_label.add_theme_constant_override("outline_size", 6)
				root.add_child(_label)
				var start := 0
				for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
					if a.is_valid_int() and int(a) >= 1 and int(a) <= _names.size():
						start = int(a) - 1
				_show(start)
	_boot += 1
	return false


func _body_tile() -> Vector2i:
	var b := game.battle
	for uid in b.ashore_ids():
		var p: Vector2 = b.soldier_pos[uid]
		return Vector2i(int(p.x), int(p.y))
	return Vector2i(grid.w / 2, grid.h / 2)


func _find_versions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		if ResourceLoader.exists("%s/%s/scene.gd" % [DIR, name]):
			out.append(name)
	out.sort()
	return out


func _apply(k: int) -> void:
	if _extra != null:
		_extra.queue_free()
		_extra = null
	_mats = []
	var scr: GDScript = load("%s/%s/scene.gd" % [DIR, str(_names[k])])
	var made = scr.build(self)
	if made == null:
		return
	_extra = made
	field._world.add_child(_extra)
	# **Every material in the version gets the merge**, whatever the version chose to do with it.
	for child in _extra.get_children():
		var mi := child as MeshInstance3D
		if mi != null and mi.material_override is ShaderMaterial:
			_mats.append(mi.material_override)
	_push_merge()


## How merged the board should be at the camera's current distance.
func merge_now() -> float:
	return clampf((ZOOM_APART - field.zoom) / (ZOOM_APART - ZOOM_MERGED), 0.0, 1.0)


func _push_merge() -> void:
	var m := merge_now()
	# ⚠⚠ **The hover goes in beside the merge and is not a separate concern.** What lights is whatever
	# the 판 IS at this distance -- one 조각 up close, the whole 칸 once they have closed up -- and the
	# shader decides that from these two numbers together.
	var h := Vector2(-1.0, -1.0)
	if hover_tile >= 0:
		h = Vector2(float(hover_tile % grid.w), float(hover_tile / grid.w))
	for mat in _mats:
		mat.set_shader_parameter("merge", m)
		mat.set_shader_parameter("hover_tile", h)


func _show(k: int) -> void:
	_i = posmod(k, _names.size())
	_apply(_i)
	_label_now()


func _label_now() -> void:
	if _label == null:
		return
	_label.text = "%d/%d  %s\nzoom %.2f  merge %.2f  hover %d\n1..%d pick · LEFT/RIGHT step · wheel zooms · ESC quit" % [
		_i + 1, _names.size(), str(_names[_i]), field.zoom, merge_now(), hover_tile, _names.size()]


# --- the three distances -------------------------------------------------------------------------

func _shoot_step() -> bool:
	var per := SHOTS.size() * 2 + 1
	var k: int = _shot / per
	if k >= _names.size():
		return true
	var step: int = _shot % per
	if step == 0:
		_apply(k)
	else:
		var s: int = (step - 1) / 2
		if (step - 1) % 2 == 0:
			# ⚠ **Through `zoom_at`, not by writing `zoom`.** Setting the field straight leaves the
			# camera where it was and the island slides into a corner — the first sheet was shot that
			# way and half of every picture was open sea.
			field.zoom_at(Look.viewport_size_px() * 0.5, float(SHOTS[s][1]) / field.zoom)
			_push_merge()
		else:
			_save(str(_names[k]), str(SHOTS[s][0]))
	_shot += 1
	return false


func _save(name: String, which: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % [name, which]))
	print("[merge] %s %s zoom %.2f merge %.2f" % [name, which, field.zoom, merge_now()])


# --- the watched run -----------------------------------------------------------------------------

func _tap(code: Key) -> bool:
	var down := Input.is_key_pressed(code)
	var was: bool = _held.get(code, false)
	_held[code] = down
	return down and not was


func _watch() -> bool:
	if Input.is_key_pressed(KEY_ESCAPE):
		return true
	for n in _names.size():
		if _tap((KEY_1 + n) as Key):
			_show(n)
	if _tap(KEY_RIGHT):
		_show(_i + 1)
	if _tap(KEY_LEFT):
		_show(_i - 1)
	# **The merge follows the wheel every frame** — that is the whole thing being looked at.
	hover_tile = game._tile_at(root.get_mouse_position())
	_push_merge()
	_label_now()
	return false
