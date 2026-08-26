# Drives the real shell from the title to the island and saves screenshots. **Not a net** — it asserts
# nothing; it is how a human sees the game without playing to it. Nets live in `tests/nets/` and this is
# why they stay there: nothing here can go red.
#
# ⚠ **Nothing here can go red, so a stale step writes a wrong PNG without failing.** That happened once
# (2026-08-25): a screen was inserted into the flow, every click after it landed on the wrong screen, and
# eight pictures of the wrong thing were saved silently. **If a shot does not show what its name says,
# the step order is wrong — fix the order, not the name.**
#
# The flow this walks, as of the 2026-08-26 side swap: **title → one equipment card → refit → island.**
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_field.gd
extends SceneTree

const SHOT := "res://tools/shot/out/field/field_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0


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


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % name))
	print("[shot] %s" % name)


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_save("1_title")
		1:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		2:
			_save("2_card")
		3:
			# Every card is equipment now — the beast cards left the table with the side swap.
			_game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
		4:
			_save("3_refit")
		5:
			_game._unhandled_input(_click(_game.refit_view.done_hit_rect().get_center()))
		6:
			_save("4_island")
		7:
			for _i in 300:
				_game._process(1.0 / 60.0)
		8:
			_save("5_island_running")
		9:
			for _i in 3:
				_game._unhandled_input(_key(KEY_E))
		10:
			_save("6_turned")
		11:
			for _i in 12:
				_game._unhandled_input(_wheel_up())
		12:
			_save("7_close")
		13:
			for _i in 8:
				_game._unhandled_input(_wheel_up())
		14:
			_save("8_closer")
		_:
			return true
	_step += 1
	return false
