# Measures ONE thing: **what resolution the 3D field is actually rendered at when the window is
# larger than 1280x720.** Not a net — it asserts nothing, it saves a picture and prints a size.
#
# ⚠ It deliberately does NOT set `root.size`. `shoot_field.gd` does, and that would overwrite the very
# thing being measured: the window size the stretch setting is asked to deal with.
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --path . --resolution 2560x1440 -s tools/shot/shoot_big.gd
extends SceneTree

var _game: Game = null
var _step := 0
var _wait := 0


func _initialize() -> void:
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
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
		2:
			_game._unhandled_input(_click(_game.refit_view.done_hit_rect().get_center()))
		3:
			for _i in 60:
				_game._process(1.0 / 60.0)
		4:
			for _i in 20:
				_game._unhandled_input(_wheel_up())
		5:
			var img := root.get_texture().get_image()
			print("[big] window=%s  frame=%dx%d  content_scale=%s size=%s"
				% [str(DisplayServer.window_get_size()), img.get_width(), img.get_height(),
				   str(root.content_scale_mode), str(root.content_scale_size)])
			img.save_png(ProjectSettings.globalize_path("res://tools/shot/big_closer.png"))
		_:
			return true
	_step += 1
	return false
