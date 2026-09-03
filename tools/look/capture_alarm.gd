extends SceneTree
## **The wave alarm, on the real screen** (12-01). Opens the title, presses 시작하기 through a real
## mouse event, then drives the shell's own `_process` by hand so eight minutes of run time pass in
## seconds — and photographs the top-left corner before the warning opens, three times while it is
## open, and once after the first hull has landed.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_alarm.gd -- <out-dir>
## ```
##
## ⚠⚠ **THIS ONE IS THE RUN, AND `capture_alarm4.gd` IS THE BOUNDARY.** Both walk the real clock and
## neither stages it, so they are not the same instrument twice: **this one photographs eight
## human-readable minutes** — quiet, the window opening, it falling, the hull landing — and is what
## answers 「does the alarm come and go over a run」. **`capture_alarm4.gd` steps one sub-step at a
## time onto the FIRST frame a window is open and the LAST**, which is the only way to see the value
## the plate ends a wave on. ⚠ The two staged ones are `capture_alarm2.gd` (the alarm beside the body
## panel) and `capture_alarm3.gd` (the alarm on a lost board); both write `elapsed` by hand and say so.
##
## ⚠ **`00_title` is the known-answer frame** — a screen this repo has already looked at. If it comes
## back wrong nothing below it is readable.
## ⚠ **Every input is an `InputEvent` handed to the engine.** No Win32, no key injection.
## ⚠ **The shell's own `_process` is switched OFF and called by hand** with whole 0.25 s chunks;
## `Battle.step` consumes whole `Rules.SIM_SUBSTEP_SEC` sub-steps and carries the leftover, so the
## state it lands on is the state a real player's clock would land on. The views keep their own
## `_process`, so the picture is still the game's own `_draw()`.

const CHUNK := 0.25
## The corner crop, saved at 1:1 so legibility is judged at ship size: the plate is 384 x 96 and the
## crop takes a little of the empty ground beside it, so a gap at the viewport edge would show.
const CROP := Rect2i(0, 0, 448, 144)

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_alarm: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_alarm: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_alarm: 섬이 안 열렸다")
		quit(1)
		return
	print("capture_alarm: 섬 %d x %d, boats_come=%s" % [
		_game.battle.grid.w, _game.battle.grid.h, str(_game.battle.boats_come)])
	await _shot("01_open", true)

	# ⚠ The shell drives the sim from here on, by hand.
	_game.set_process(false)

	await _at(180.0, "02_t0300_quiet", true)
	await _at(299.0, "03_t0459_quiet", true)
	await _at(310.0, "04_t0510_open", true)
	await _at(420.0, "05_t0700", true)
	await _at(479.0, "06_t0759", true)
	await _at(479.9, "07_t0759_9", true)
	await _at(481.5, "08_t0801_landed", true)
	await _at(490.0, "09_t0810", true)
	quit(0)


## Runs the shell forward to `sec` of run time, then shoots.
##
## ⚠⚠ **THE STEP HAS A FLOOR OF ONE SUB-STEP AND IT SPUN FOREVER WITHOUT ONE.** `Battle.step`
## accumulates `dt` and moves `elapsed` only in whole `Rules.SIM_SUBSTEP_SEC`, carrying the leftover
## — so a final `dt` clamped to the remaining distance, a hair under a sub-step, advanced the clock
## not at all and this loop handed it the same hair again. **Two runs sat at 100 % of one core for
## thirteen minutes between 6:00 and 7:59, with no error line and no frame written.** Measured
## 2026-09-03. ⇒ The shot lands up to one sub-step PAST `sec` rather than on it, which is the price
## and is worth saying out loud.
## ⚠ **The second road to the same hang is a lost board**: `Battle.step` returns early once `lost`,
## so `elapsed` stops for a reason no floor can fix. That is what the equality guard catches, and it
## is why the guard is 「did the clock move」 rather than 「did we run out of turns」.
## ⚠ The cap is DERIVED from the target — one sub-step is the smallest step this loop can take, so
## `sec / SIM_SUBSTEP_SEC` is the arithmetic ceiling on how many it can need. A typed number here
## would be a second thing to keep in step with `CHUNK`.
func _at(sec: float, name: String, crop: bool) -> void:
	var b: Battle = _game.battle
	var cap := int(sec / Rules.SIM_SUBSTEP_SEC) + 8
	var steps := 0
	while b.elapsed < sec:
		if steps >= cap:
			push_error("capture_alarm: %.2f 로 가는 데 %d 걸음을 썼다 (지금 %.3f)" % [sec, steps, b.elapsed])
			quit(1)
			return
		var before := b.elapsed
		_game._process(maxf(Rules.SIM_SUBSTEP_SEC, minf(CHUNK, sec - b.elapsed)))
		steps += 1
		if b.elapsed == before:
			push_error("capture_alarm: 시계가 %.3f 에서 멈췄다 (lost=%s)" % [b.elapsed, str(b.lost)])
			quit(1)
			return
	await _shot(name, crop)


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
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_alarm: %s 를 못 썼다" % path)
	if crop:
		var cut := img.get_region(CROP)
		if cut.save_png("%s/%s_corner.png" % [_dir, name]) != OK:
			push_error("capture_alarm: %s 구석을 못 썼다" % name)
	print("--- %s  %s" % [name, _where()])


func _where() -> String:
	var b: Battle = _game.battle
	if b == null:
		return "battle null"
	var afloat := 0
	for i in b.boat_state.size():
		if b.boat_state[i] != Battle.BoatState.GONE:
			afloat += 1
	return "t=%.2f ordinal=%d left=%.2f open=%s clock='%s' boats=%d afloat=%d enemies=%d" % [
		b.elapsed, b.wave_ordinal, b.wave_seconds_left, str(b.wave_warning_open),
		Look.alarm_clock_text(b.wave_seconds_left), b.boat_pos.size(), afloat,
		b.enemy_alive.size()]
