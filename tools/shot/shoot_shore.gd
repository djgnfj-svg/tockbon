# **The shoreline, four times, seconds apart.** ⚠ Every other shooter saves ONE frame, and one frame
# cannot answer 「is it moving?」 — a still line and a line caught mid-swing look identical in a single
# picture. This walks the same flow `shoot_field.gd` does, stops at the island zoomed in, and saves four
# frames spaced about a second and a half apart, so the swash, the peel and the travelling foam can be
# judged by laying the four side by side.
#
# **Not a net** — it asserts nothing.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_shore.gd
extends SceneTree

const SHOT := "res://tools/shot/out/shore/shore_%d.png"
## Frames between saved pictures. At 60 a second this is about a second and a half, which is long
## enough for one swash cycle to have moved and short enough that four fit in a run.
const APART := 90

var _game: Game = null
var _step := 0
var _wait := 0
var _shot := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _process(_delta: float) -> bool:
	_wait += 1
	if _step < 5:
		if _wait < 6:
			return false
		_wait = 0
		match _step:
			0:
				_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
			1:
				pass
			2:
				# ⚠ **The card and refit presses are DELETED** (2026-08-28) with the screens.
				pass
			3:
				# ⚠ **Twelve and not twenty.** `shoot_field.gd`'s 7_close is twelve wheel steps in; going
				# further fills the frame with land and leaves no coast to judge.
				for _i in 12:
					_game._unhandled_input(_wheel_up())
			4:
				pass
		_step += 1
		return false
	if _wait < APART:
		return false
	_wait = 0
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % _shot))
	print("[shore] %d" % _shot)
	_shot += 1
	return _shot >= 4
