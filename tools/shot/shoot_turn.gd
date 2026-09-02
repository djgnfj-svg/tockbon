# Drives the real shell through ONE press of E and saves three frames: the board before, one frame
# partway through the sweep, and the board settled a quarter round. **Not a net** — it asserts
# nothing; it is how a human answers 「도는 것이 보여」 without playing to it. Nets live in
# `tests/nets/` and this is why they stay there: nothing here can go red.
#
# ⚠⚠ **IT IS ITS OWN TOOL AND NOT A STEP IN `shoot_pick.gd`, AND THAT WAS MEASURED.** That file gates
# every step on six frames — about 0.1 s — against a 0.22 s sweep, so a shot taken there lands near
# **41°**, at whatever angle the frame rate happened to produce. **The middle frame is the whole point
# of this tool**, so the moment is chosen rather than caught.
#
# ⚠⚠ **THE SWEEP IS DRIVEN BY HAND AND THE VIEW'S OWN `_process` IS TURNED OFF FOR IT.** Left running,
# the engine would advance the sweep by one real frame between the moment this file picks and the
# moment the renderer reads it back — 6.8° at 60 fps, on a machine-dependent delta.
#
# ⚠ **The shots land beside the ticket** (03-10), which is where its acceptance asks for them. One
# copy, in the folder that owns the question.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_turn.gd
extends SceneTree

const SHOT := "res://docs/roadmap/task-03-command-the-squads/10-turn-in-quarter-notches/03-10-%s.png"

## The angle the middle frame is aimed at — **half a quarter**, the furthest point from both ends.
const MID_DEG := 45.0

var _game: Game = null
var _step := 0
var _wait := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _press(at: Vector2) -> InputEventMouseButton:
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


func _turn_key() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_E
	return ev


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % shot_name))
	print("[shot] %s  yaw=%.2f  owed=%.2f"
		% [shot_name, _game.field_view.cam_yaw_deg, _game.field_view._yaw_remaining])


## Runs the field's own frame by hand, at a steady 60 a second. ⚠ **Bounded**, like every loop that
## waits on this sweep: a turn that never settles must not take the tool with it.
func _sweep(until_deg: float) -> void:
	var fv := _game.field_view
	for _n in 60:
		if fv._yaw_remaining == 0.0 or absf(fv.cam_yaw_deg) >= until_deg:
			return
		fv._process(1.0 / 60.0)


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_press(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# The beasts' boats sail in and unload; the player's bodies are ashore from the start.
			for _i in 240:
				_game._process(1.0 / 60.0)
		2:
			for _i in 10:
				_game._unhandled_input(_wheel_up())
		3:
			# ⚠ **The cursor is parked in the middle before anything else.** The shell edge-pans off
			# the remembered pointer, and a live window leaves it wherever the hand last was.
			var mid := Look.viewport_size_px() * 0.5
			var ev := InputEventMouseMotion.new()
			ev.position = mid
			_game._unhandled_input(ev)
			# Both clocks come under this file's hand from here.
			_game.set_process(false)
			_game.field_view.set_process(false)
		4:
			_save("1_before_0deg")
		5:
			_game._unhandled_input(_turn_key())
			_sweep(MID_DEG)
		6:
			# **The middle frame.** ⚠ Nothing has moved since step 5 chose it — the view's own
			# `_process` is off, so this is the angle that was picked and not the one a frame later.
			_save("2_midsweep")
		7:
			_sweep(360.0)
		8:
			_save("3_settled_90deg")
		_:
			return true
	_step += 1
	return false
