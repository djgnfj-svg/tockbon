extends SceneTree
## **The boundary sub-steps of a wave's warning window** (12-01, re-check) — the FIRST frame it is
## open on and the LAST, for wave 1 and again for wave 5.
##
## ⚠⚠ **IT IS NOT `capture_alarm.gd` TWICE.** Both walk the real clock; that one photographs eight
## human-readable minutes in 0.25 s chunks and answers 「does the alarm come and go over a run」, and
## **0.25 s cannot land on the one sub-step a window opens or closes on** — which is exactly where
## the two defects of 2026-09-03 lived. This one single-steps onto those frames, which is how
## 179.999999999944 and the four wave residuals were read at all. **Keep both.**
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_alarm4.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.** ⚠ Every input is an `InputEvent` handed to the engine.
## ⚠⚠ **The clock is REAL** — the shell's own `_process` is called by hand in 0.25 s chunks and then,
## near each boundary, in single `Rules.SIM_SUBSTEP_SEC` steps, so the frame photographed is the
## FIRST sub-step the warning is open on and the ONE sub-step `wave_seconds_left` is exactly 0.0 on.
## Nothing about the clock is staged.

const CHUNK := 0.25
const CROP := Rect2i(0, 0, 448, 144)

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_alarm4: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_alarm4: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	await _settle(10)
	await _shot("00_title", false)

	_click(Look.title_slot_rect_px(TitleView.SLOT_START).get_center())
	await _settle(6)
	if _game.battle == null:
		push_error("capture_alarm4: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	var b: Battle = _game.battle
	# ⚠⚠ **THE BEASTS ARE OFF AND THE CLOCK IS NOT.** An unopposed wave 1 ends the run at about 8:15,
	# `Battle.step` returns early once `lost`, and `elapsed` would then never reach wave 5 at all.
	# `boats_come` is the sim's own field; the wave clock hangs on `elapsed` alone and does not read
	# it, so every number the plate shows below is the number a defended board would show.
	b.boats_come = false

	# -- the sub-step the warning opens on ---------------------------------------------------------
	_coarse(299.0)
	var guard := 0
	while not b.wave_warning_open and guard < 400:
		_game._process(Rules.SIM_SUBSTEP_SEC)
		guard += 1
	print("OPEN AT t=%.9f left=%.12f text='%s'" % [
		b.elapsed, b.wave_seconds_left, Look.alarm_clock_text(b.wave_seconds_left)])
	await _shot("10_first_open", true)

	# -- it falls ----------------------------------------------------------------------------------
	_coarse(360.0)
	print("FALL t=%.2f text='%s'" % [b.elapsed, Look.alarm_clock_text(b.wave_seconds_left)])
	await _shot("11_t0600_two_minutes", true)

	# -- the LAST sub-step wave 1's window is open on ----------------------------------------------
	_coarse(479.0)
	await _last_open("12_wave1_last_open")

	# -- and wave 5's, which is a different answer -------------------------------------------------
	_coarse(2399.0)
	await _last_open("13_wave5_last_open")
	quit(0)


## Single sub-steps until the warning is one sub-step from closing, then shoots THAT frame — the last
## number the plate ever shows for this wave.
func _last_open(name: String) -> void:
	var b: Battle = _game.battle
	var lowest := INF
	var guard := 0
	while guard < 400:
		var before := b.wave_seconds_left
		_game._process(Rules.SIM_SUBSTEP_SEC)
		guard += 1
		if not b.wave_warning_open:
			push_warning("%s: 창이 닫혔다, 마지막 값은 %.12f" % [name, before])
			break
		lowest = b.wave_seconds_left
		if b.wave_seconds_left <= Rules.SIM_SUBSTEP_SEC * 0.5:
			break
	print("%s  t=%.9f left=%.12f text='%s' open=%s" % [
		name, b.elapsed, lowest, Look.alarm_clock_text(lowest), str(b.wave_warning_open)])
	await _shot(name, true)


## Whole 0.25 s chunks until `sec` is reached or passed, the way a real player's clock would get there.
##
## ⚠⚠ **THE CHUNK IS NEVER CLAMPED TO THE REMAINING DISTANCE, AND THAT IS A MEASURED HANG.**
## `Battle.step` accumulates `dt` and advances `elapsed` only in whole `Rules.SIM_SUBSTEP_SEC`, so a
## final `dt` of the leftover — a hair under a sub-step, sometimes 1e-9 — advances the clock not at
## all and the `while` feeds it the same hair again. **Two runs sat at 100 % of a core for thirteen
## minutes between 6:00 and 7:59 doing this**, with no error and no frame. ⚠ `capture_alarm.gd`'s
## `_at` carried the clamped shape and could hang the same way; it took a sub-step floor, the same
## stopped-clock guard as below, and a step cap on 2026-09-03.
func _coarse(sec: float) -> void:
	var b: Battle = _game.battle
	while b.elapsed < sec:
		var before := b.elapsed
		_game._process(CHUNK)
		# ⚠ A lost island stops accumulating too — without this the loop is the same hang by another road.
		if b.elapsed == before:
			push_error("capture_alarm4: 시계가 %.3f 에서 멈췄다 (lost=%s)" % [b.elapsed, str(b.lost)])
			quit(1)
			return


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = down
		root.push_input(ev, true)


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String, crop: bool) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.save_png("%s/%s.png" % [_dir, name]) != OK:
		push_error("capture_alarm4: %s 를 못 썼다" % name)
	if crop:
		if img.get_region(CROP).save_png("%s/%s_corner.png" % [_dir, name]) != OK:
			push_error("capture_alarm4: %s 구석을 못 썼다" % name)
	print("--- %s" % name)
