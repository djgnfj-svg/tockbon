# The picked body's panel (03-02), photographed IN THE GAME for the 시안 round: one plate candidate in
# each of the four corners, and a fifth shot with every ashore body picked so 「x N」 is on the glass.
# **Not a net** — it asserts nothing; nets live in `tests/nets/` (`net_panel`), and nothing here can
# go red.
#
# ⚠ **Nothing here can go red, so a stale step writes a wrong PNG without failing** — `shoot_pick.gd`'s
# rule. **If a shot shows no panel, the hand is empty: the body press missed, and the step order is
# what to fix, not the name.** Every save prints the hand's size beside it for exactly that reason.
#
# ⚠⚠ **`Look.PANEL_CORNER` IS NOT EDITED.** The corner is only decided once the user has looked, so
# this file swaps in a `HudView` subclass whose two leaves shift `at` by a corner offset and then draw
# through `super` — the same pixels, moved. The offset is measured from where `Look.panel_origin_px`
# actually puts the plate, so the shot named `bl` is `Look`'s own answer when the corner is bottom-left.
#
# The plate the game is wearing is whatever `assets/ui/panel.png` is when this runs; the driver
# `shoot_panel.ps1` swaps the candidates in one at a time and names each run with `--plate=<name>`.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_panel.gd -- --plate=crimson
# Without `--plate=`, the name is read from `tools/shot/out/panel/current.txt`.
extends SceneTree

const OUT_DIR := "res://tools/shot/out/panel"
const SHOT := OUT_DIR + "/panel_%s_%s.png"
const CURRENT_FILE := OUT_DIR + "/current.txt"
const PLATE_ARG := "--plate="

## The corner shots, in the order they are taken. `bl_x4` is bottom-left again with every ashore
## body in the hand — the running island holds four, so the line reads 「x 4」 (2026-09-02, the user
## shown that four is the most the screen can show: 「ㅇㅇ 이대로 가자」).
const CORNERS := ["bl", "br", "tl", "tr"]


## The hud with its two panel leaves shifted. ⚠ **`super` and not a second `draw_*`** — the whole
## point is that the picture is the game's own leaf, moved, so what the user judges is what ships.
class CornerHud extends HudView:
	var offset := Vector2.ZERO

	func _paint_panel(tex: Texture2D, at: Vector2) -> void:
		super(tex, at + offset)

	func _paint_line(text: String, at: Vector2, font: Font, size_px: int, col: Color) -> void:
		super(text, at + offset, font, size_px, col)


var _game: Game = null
var _hud: CornerHud = null
var _plate := ""
var _step := 0
var _wait := 0
var _who := -1


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_plate = _plate_name()
	print("[shot] plate=%s" % _plate)
	_game = Game.new()
	root.add_child(_game)


## Puts `CornerHud` where the real hud stands. ⚠⚠ **Called from the first `_process` step and NOT
## from `_initialize`** — measured: `add_child` inside a `SceneTree._initialize` does not run
## `_ready`, so `hud_view` is still null there and the swap removes nothing. **Before the title
## press**, so the real `_open_island` binds this one and nothing here has to remember to. Put back
## at index 1 so the draw order stays field -> hud -> title.
func _swap_in_corner_hud() -> void:
	_game.remove_child(_game.hud_view)
	_game.hud_view.queue_free()
	_hud = CornerHud.new()
	_game.hud_view = _hud
	_game.add_child(_hud)
	_game.move_child(_hud, 1)


## `--plate=<name>` off the user args, else the one line of `current.txt`, else `unnamed`.
func _plate_name() -> String:
	for raw in OS.get_cmdline_user_args():
		var a := str(raw)
		if a.begins_with(PLATE_ARG):
			return a.substr(PLATE_ARG.length()).strip_edges()
	var path := ProjectSettings.globalize_path(CURRENT_FILE)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var line := f.get_line().strip_edges()
			f.close()
			if line != "":
				return line
	return "unnamed"


## Where the plate's top-left would be in `corner`, minus where `Look` puts it now.
func _offset_for(corner: String) -> Vector2:
	var far := Look.viewport_size_px() - Look.PANEL_SIZE_PX
	var want := Vector2.ZERO
	match corner:
		"br":
			want = far
		"tl":
			want = Vector2.ZERO
		"tr":
			want = Vector2(far.x, 0.0)
		_:
			want = Vector2(0.0, far.y)
	return want - Look.panel_origin_px(Look.PANEL_SIZE_PX)


func _press(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _release(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _motion(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.relative = Vector2.ZERO
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _save(corner: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % [_plate, corner]))
	print("[shot] panel_%s_%s hand=%d offset=%s" % [_plate, corner, _game.hand.ids.size(),
		str(_hud.offset)])


## Where the first body ashore is standing, in screen px. -1 in `_who` means nobody has landed yet.
func _body_at_screen() -> Vector2:
	var b: Battle = _game.battle
	var ashore := b.ashore_ids()
	if ashore.is_empty():
		return Vector2(-1.0, -1.0)
	_who = int(ashore[0])
	var p: Vector2 = b.soldier_pos[_who]
	return _game.field_view.tile_to_screen_px(int(p.x), int(p.y))


func _process(_delta: float) -> bool:
	# ⚠ **The cursor is parked in the middle every frame.** The window is real and so is the operating
	# system's pointer; the shell edge-pans off wherever it last was, and a pointer left near a border
	# pans the island out from under the shot (`shoot_pick.gd`, step 13).
	if _step >= 4:
		_game._unhandled_input(_motion(Look.viewport_size_px() * 0.5))
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_swap_in_corner_hud()
			_game._unhandled_input(_press(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# The beasts' boats sail in and unload; the player's bodies are ashore from the start.
			for _i in 240:
				_game._process(1.0 / 60.0)
		2:
			for _i in 10:
				_game._unhandled_input(_wheel_up())
		3:
			# **The real gesture**: a press and a release on the first body ashore.
			var at := _body_at_screen()
			if at.x >= 0.0:
				_game._unhandled_input(_press(at))
				_game._unhandled_input(_release(at))
			print("[shot] pressed=%s who=%d hand=%d" % [str(at), _who, _game.hand.ids.size()])
		4:
			_hud.offset = _offset_for(CORNERS[0])
		5:
			_save(CORNERS[0])
			_hud.offset = _offset_for(CORNERS[1])
		6:
			_save(CORNERS[1])
			_hud.offset = _offset_for(CORNERS[2])
		7:
			_save(CORNERS[2])
			_hud.offset = _offset_for(CORNERS[3])
		8:
			_save(CORNERS[3])
			# Back to bottom-left with everybody ashore in the hand, through `Hand.pick_many` — the
			# shell has no gesture for 「all of them」 yet (03-16/03-17's branch owns the press).
			_hud.offset = _offset_for(CORNERS[0])
			var b: Battle = _game.battle
			var want := PackedInt32Array()
			for raw in b.ashore_ids():
				want.append(int(raw))
			_game.hand.pick_many(b, want)
		9:
			_save("%s_x4" % CORNERS[0])
		_:
			print("[shot] done plate=%s who=%d" % [_plate, _who])
			return true
	_step += 1
	return false
