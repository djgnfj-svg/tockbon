# Photographs the 판's merged lump twice at the SAME camera — once with the reveal key up and once
# with it down — so the marks can be measured as a per-pixel difference against the bare ground.
# **Not a net**: it asserts nothing, it takes the picture a number is read off.
#
# ⚠⚠ **THE TREE IS PAUSED BEFORE THE PAIR IS TAKEN.** Bodies walk and the sea moves, so two frames
# taken a frame apart differ everywhere a wolf stood — and the difference IS the measurement here.
# Paused, the only thing that changes between the two PNGs is the 판.
#
# ⚠ **Both yaws are shot on purpose.** At yaw 0 a 판's side wall lying in the plane x = const projects
# to zero screen width, so the join between the left and right halves of a 칸 cannot be seen at all;
# turned 45° both joins are equally oblique to the camera and both show. **The turned pair is what
# says whether the vertical join has the same defect as the horizontal one.**
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_pad_seam.gd
extends SceneTree

const SHOT := "res://tools/shot/out/pads/seam_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tools/shot/out/pads"))


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


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % shot_name))
	print("[shot] %s" % shot_name)


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			for _i in 300:
				_game._process(1.0 / 60.0)
		2:
			for _i in 12:
				_game._unhandled_input(_wheel_up())
		3:
			paused = true
		4:
			_save("yaw00_off")
		5:
			_game.field_view.set_pads_revealed(true)
		6:
			_save("yaw00_on")
		7:
			# ⚠ **The turn has to happen UNPAUSED.** `turn_by` writes `cam_yaw_deg` and nothing else;
			# `_place_camera` is what reaches the engine and it runs inside `_process`, which a paused
			# tree never calls — a turn written under the pause is a turn that never happens, and the
			# two pairs came out pixel-identical the first time this was run.
			_game.field_view.set_pads_revealed(false)
			paused = false
			_game.field_view.turn_by(45.0)
		8:
			paused = true
		9:
			_save("yaw45_off")
		10:
			_game.field_view.set_pads_revealed(true)
		11:
			_save("yaw45_on")
		12:
			# ⚠⚠ **THE 조각 LOOK, PHOTOGRAPHED.** `merge` is pinned to 1 in `_adopt_the_pads` and the
			# 조각 branch of the shader is unreachable there — **so it is written straight onto the
			# material here.** This shot is the evidence that the branch still draws 280 separate
			# marks, each with its own rim, and it is the picture the seam fix has to leave alone.
			paused = false
			_game.field_view.turn_by(-45.0)
		13:
			paused = true
			_game.field_view._pads_mat.set_shader_parameter("merge", 0.0)
		14:
			_save("merge0_on")
		_:
			return true
	_step += 1
	return false
