extends SceneTree
## **Ticket 07-01 on the real screen** — a 검사 turning to face a 늑대 he noticed, and the first wave
## meeting the watch at the door.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_0701.gd -- <out-dir> noticed
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_0701.gd -- <out-dir> wave
## ```
##
## ⚠ **`00_title` is the known-answer frame.** If it comes back wrong nothing below it is readable.
## ⚠ **Every input is an `InputEvent` handed to the engine.** No Win32, no key injection.
## ⚠ **The sim is driven by calling the shell's own `_process`**, so a landing 22.75 s into the run
## costs a few real seconds. `set_process(false)` is what stops the engine advancing it a second time.
## ⚠⚠ **`noticed` walks the 검사 to (5,11) and THEN one step EAST to (6,11) on purpose.** A still body
## holds the heading it last walked, so his resting picture faces east and the frame where the target
## column names a 늑대 is a turn of about 135 degrees rather than a coincidence of the route.

const SUB := 1.0 / 60.0

var _dir := ""
var _mode := ""
var _game: Game = null
var _sec := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("capture_0701: <출력 폴더> <noticed|wave> 두 인자를 달라")
		quit(1)
		return
	_dir = args[0]
	_mode = args[1]
	if DisplayServer.get_name() == "headless":
		push_error("capture_0701: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	await _settle(10)
	await _shot("00_title")

	_click(Look.title_slot_rect_px(TitleView.SLOT_START).get_center())
	await _settle(6)
	if _game.battle == null:
		push_error("capture_0701: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	var b: Battle = _game.battle
	var w := b.grid.w
	print("island %dx%d keep=%s soldiers=%d" % [w, b.grid.h, str(b.keep_tiles), b.living_soldier_count()])

	if _mode == "noticed":
		await _noticed(b, w)
	else:
		await _wave(b)
	print("capture_0701: %s" % _dir)
	quit()


# --- the facing ---------------------------------------------------------------------------------------

func _noticed(b: Battle, w: int) -> void:
	if not b.order_walk(0, 11 * w + 5):
		push_error("capture_0701: (5,11) 명령이 안 먹었다")
		quit(1)
		return
	await _until(func() -> bool: return b.soldier_pos[0].is_equal_approx(Vector2(5, 11)), 20.0)
	if not b.order_walk(0, 11 * w + 6):
		push_error("capture_0701: (6,11) 명령이 안 먹었다")
		quit(1)
		return
	await _until(func() -> bool: return b.soldier_pos[0].is_equal_approx(Vector2(6, 11)), 20.0)
	print("s0 stood at %s facing east, t=%.2f" % [str(b.soldier_pos[0]), _sec])

	# The 검사 alone, no beast ashore — this is the head the turn is measured against.
	_zoom_to(2.2)
	_centre_on(Look.tile_point_px(Vector2(5.4, 10.2)))
	await _until(func() -> bool: return _sec >= 22.5, 30.0)
	await _settle(4)
	print("before: beasts=%d s0=%s target=%d"
		% [b.living_enemy_ids().size(), str(b.soldier_pos[0]), int(b.soldier_target[0])])
	await _shot("01_before_the_landing")

	# The landing, one sub-step at a time, then a fifth of a second so the 늑대 are visibly off the
	# 조각 they came ashore on and still outside reach 1.75.
	await _until(func() -> bool: return b.living_enemy_ids().size() > 0, 5.0)
	print("landed t=%.3f" % _sec)
	await _step_subs(9)
	await _settle(4)
	_report(b)
	await _shot("02_noticed")


# --- the wave ------------------------------------------------------------------------------------------

func _wave(b: Battle) -> void:
	_zoom_to(1.8)
	_centre_on(Look.tile_point_px(Vector2(9.6, 11.2)))
	await _until(func() -> bool: return b.living_enemy_ids().size() > 0, 40.0)
	print("landed t=%.3f" % _sec)
	await _until(func() -> bool: return _sec >= 52.0, 40.0)
	await _settle(4)
	_report(b)
	await _shot("03_shipped_first_wave")


# --- the clock -----------------------------------------------------------------------------------------

## One sub-step at a time through the shell's own `_process`, with a real frame every quarter second
## so the views keep up and nothing is photographed a hundred seconds stale.
func _until(test: Callable, cap_sec: float) -> void:
	var spent := 0.0
	var n := 0
	while spent < cap_sec:
		_game._process(SUB)
		_sec += SUB
		spent += SUB
		n += 1
		if test.call():
			break
		if n % 15 == 0:
			await process_frame
	await process_frame
	await process_frame


func _step_subs(n: int) -> void:
	for _i in n:
		_game._process(SUB)
		_sec += SUB
	await process_frame
	await process_frame


func _report(b: Battle) -> void:
	var line := "t=%.3f keep_hp=%.1f lost=%s" % [_sec, b.keep_hp, str(b.lost)]
	for i in b.soldier_state.size():
		if int(b.soldier_state[i]) != Battle.SoldierState.ASHORE:
			continue
		line += ("\n  s%d (%.2f,%.2f) L%d target=%d hp=%.1f"
			% [i, b.soldier_pos[i].x, b.soldier_pos[i].y, _level(b, b.soldier_pos[i]),
				int(b.soldier_target[i]), float(b.soldier_hp[i])])
	for e in b.enemy_type.size():
		if b.enemy_alive[e] == 0:
			continue
		var p: Vector2 = b.enemy_pos[e]
		line += ("\n  e%d (%.2f,%.2f) L%d target=%d hp=%.1f keep_gap=%.2f to_s0=%.2f"
			% [e, p.x, p.y, _level(b, p), int(b.enemy_target[e]), float(b.enemy_hp[e]),
				b.keep_gap(p), p.distance_to(b.soldier_pos[0])])
	print(line)


func _level(b: Battle, p: Vector2) -> int:
	var tx := clampi(int(round(p.x)), 0, b.grid.w - 1)
	var ty := clampi(int(round(p.y)), 0, b.grid.h - 1)
	return int(b.grid.level[ty * b.grid.w + tx])


# --- the camera ----------------------------------------------------------------------------------------

## ⚠ **Zoom BEFORE centring.** `_clamp_cam` bounds the ground point in the middle of the screen by the
## visible span, so centring at the opening zoom pins the camera a screen-half inside the roam bound.
func _centre_on(world_px: Vector2) -> void:
	var fv := _game.field_view
	fv.cam_px = world_px - fv._visible_ground_px() * 0.5
	fv._clamp_cam()


func _zoom_to(want: float) -> void:
	var fv := _game.field_view
	var guard := 0
	while fv.zoom < want - 0.001 and guard < 40:
		fv.zoom_at(Look.viewport_size_px() * 0.5, Look.ZOOM_STEP)
		guard += 1
	while fv.zoom > want + 0.001 and guard < 80:
		fv.zoom_at(Look.viewport_size_px() * 0.5, 1.0 / Look.ZOOM_STEP)
		guard += 1


# --- the shutter ---------------------------------------------------------------------------------------

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


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_0701: %s 를 못 썼다" % path)
	print("--- %s  t=%.3f zoom=%.2f cam=%s"
		% [name, _sec, _game.field_view.zoom, str(_game.field_view.cam_px.round())])
