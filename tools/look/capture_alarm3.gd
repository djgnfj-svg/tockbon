extends SceneTree
## **The alarm on the frame the island is lost** (12-01). The alarm's paint runs ABOVE `HudView`'s
## `_over` early return, so the two can stand at once — this is what that looks like.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_alarm3.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.**
## ⚠⚠ **BOTH the clock and the loss are STAGED** — `battle.elapsed` and `battle.lost` are written
## directly, because walking either takes minutes of sim. The wave clock is a pure function of
## `elapsed` and the shell reads `lost` every frame, so what goes on the glass is what the game would
## put there; nothing else about the board is claimed.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_alarm3: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_alarm3: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_alarm3: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	_game.battle.elapsed = 302.0
	_game._process(0.05)
	await _settle(3)
	await _shot("20_alarm_alone")
	_game.battle.lost = true
	_game._process(0.05)
	await _settle(3)
	await _shot("21_alarm_and_game_over")
	quit(0)


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
	if img.save_png("%s/%s.png" % [_dir, name]) != OK:
		push_error("capture_alarm3: %s 를 못 썼다" % name)
	print("--- %s" % name)
