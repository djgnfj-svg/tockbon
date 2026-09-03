extends SceneTree
## **The alarm standing beside the body panel and the selection box** (12-01). Opens the title,
## presses 시작하기 through a real mouse event, **sets the run clock forward by hand** so the warning
## window is open in seconds, then drags a selection box over the bodies so the bottom-left panel is
## up in the same frame as the top-left alarm.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_alarm2.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.**
## ⚠⚠ **THE CLOCK IS STAGED, NOT RUN.** `battle.elapsed` is written directly, because the sim costs
## minutes of CPU to walk to 5:00 — see `probe_wave_cost.gd`. The wave clock is a pure function of
## `elapsed`, so what the alarm shows is what it would show on a walked clock; the BODIES are not,
## and this frame says nothing about their hunger.
## ⚠ **Every input is an `InputEvent` handed to the engine.** No Win32, no key injection.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_alarm2: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_alarm2: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	await _settle(10)
	await _shot("00_title")

	_click(Look.title_slot_rect_px(TitleView.SLOT_START).get_center())
	await _settle(6)
	if _game.battle == null:
		push_error("capture_alarm2: 섬이 안 열렸다")
		quit(1)
		return

	# The bodies, picked with a real left-drag box.
	await _drag(Vector2(420.0, 340.0), Vector2(570.0, 410.0))
	await _settle(4)
	await _shot("10_picked_no_alarm")

	# The clock, staged to just inside the warning window, and then RUN — so the countdown falling is
	# the sim's own doing and not a second staged number.
	_game.battle.elapsed = 302.0
	await _settle(4)
	await _shot("11_picked_alarm_open")
	await _run_sim(8.0)
	await _shot("12_eight_seconds_later")

	_game.battle.elapsed = 419.0
	await _settle(4)
	await _shot("13_one_minute_left")

	_game.battle.elapsed = 478.5
	await _settle(4)
	await _shot("14_last_seconds")

	# ⚠ The launch queue is driven, not staged: the clock is set a hair before the hull's own launch
	# moment (`wave_land_sec - BOAT_CROSSING_SEC`, about 461.75) and the sim runs from there.
	_game.battle.elapsed = 460.0
	await _run_sim(19.5)
	await _shot("15_just_before_landing")
	await _run_sim(2.5)
	await _shot("16_just_after_landing")
	await _run_sim(10.0)
	await _shot("17_ten_seconds_after")
	quit(0)


## Runs the shell's own `_process` for `sec` of run time, a real frame at a time, so the picture keeps
## up with the sim and the countdown falls under its own steam.
func _run_sim(sec: float) -> void:
	var b: Battle = _game.battle
	var stop := b.elapsed + sec
	while b.elapsed < stop:
		_game._process(minf(0.05, stop - b.elapsed))
		await process_frame


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = down
		root.push_input(ev, true)


func _drag(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = from
	down.pressed = true
	root.push_input(down, true)
	var steps := 8
	for i in steps:
		var at := from.lerp(to, float(i + 1) / float(steps))
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.relative = (to - from) / float(steps)
		root.push_input(mv, true)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = to
	up.pressed = false
	root.push_input(up, true)


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.save_png("%s/%s.png" % [_dir, name]) != OK:
		push_error("capture_alarm2: %s 를 못 썼다" % name)
	var b: Battle = _game.battle
	if b == null:
		print("--- %s  battle null" % name)
		return
	print("--- %s  t=%.2f open=%s left=%.2f clock='%s' picked=%d" % [
		name, b.elapsed, str(b.wave_warning_open), b.wave_seconds_left,
		Look.alarm_clock_text(b.wave_seconds_left), _game.hand.ids.size()])
