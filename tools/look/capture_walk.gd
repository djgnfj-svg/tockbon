extends SceneTree
## The game screenshots ONE SWORDSMAN WALKING TO A PRESSED TILE.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_walk.gd -- <output-dir>
## ```
##
## ⚠ **The shell's `_process` is LEFT ON here**, unlike every other script in this folder. What is
## being measured is a body crossing tiles over time, and a frozen shell never steps the sim — the
## staging rule that makes a survey frame honest would make this one measure nothing.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_walk: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_walk: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	await process_frame

	_game._start_run()
	_game.run.seed_cards(20260827)
	if _game.run.state() == Run.State.PICK:
		_game.run.take_card(0)
	if _game.run.state() == Run.State.REFIT:
		_game.run.close_refit()
	_game._show_state()
	if _game.battle == null:
		push_error("capture_walk: 섬이 안 열렸다")
		quit(1)
		return

	var b: Battle = _game.battle
	var grid: Grid = b.grid
	print("capture_walk: 섬 %d x %d, 본채 칸 %d" % [grid.w, grid.h, Islands.home_tile()])
	var ashore: Array = b.ashore_ids()
	print("capture_walk: 섬 위의 몸 %d, %s" % [ashore.size(), str(ashore)])
	if ashore.is_empty():
		push_error("capture_walk: 아무도 안 서 있다")
		quit(1)
		return
	var who := int(ashore[0])
	var start: Vector2 = b.soldier_pos[who]
	print("capture_walk: 몸 %d 가 %s 에 서 있다" % [who, str(start)])
	await _settle(30)
	await _shot("00_he_stands")

	# --- press a far tile ---------------------------------------------------------------------------
	var far := _far_land_from(grid, start)
	if far < 0:
		push_error("capture_walk: 보낼 칸을 못 찾았다")
		quit(1)
		return
	var at := _screen_of(far)
	if at.x < 0.0:
		push_error("capture_walk: 그 칸이 화면 밖이다")
		quit(1)
		return
	print("capture_walk: 칸 %d (%d,%d) 를 화면 %s 에서 누른다" % [far, far % grid.w, far / grid.w, str(at)])
	_click(at)
	print("capture_walk: 명령 = %d, 커밋 = %s" % [int(b.soldier_order[who]), str(b.committed())])
	await _settle(2)
	await _shot("10_ordered")

	# --- watch him cross ----------------------------------------------------------------------------
	var marks := [20, 45, 75, 110, 150]
	var seen := 0
	for k in marks.size():
		while seen < int(marks[k]):
			await process_frame
			seen += 1
		print("capture_walk: %d 프레임 — 자리 %s, 명령 %d" % [
			seen, str(b.soldier_pos[who]), int(b.soldier_order[who])])
		await _shot("2%d_walking" % k)

	var moved: float = (b.soldier_pos[who] as Vector2).distance_to(start)
	print("capture_walk: 처음에서 %.2f 칸 움직였다 (목표까지는 %.2f 였다)" % [
		moved, start.distance_to(Vector2(float(far % grid.w), float(far / grid.w)))])
	print("capture_walk: %s" % _dir)
	quit()


## The farthest walkable tile on the same level, so the walk is long enough to see.
func _far_land_from(grid: Grid, from: Vector2) -> int:
	var best := -1
	var best_d := 0.0
	var lv := grid.level_of(int(round(from.y)) * grid.w + int(round(from.x)))
	for t in grid.w * grid.h:
		if grid.passable[t] != 1 or grid.level_of(t) != lv:
			continue
		var d: float = from.distance_to(Vector2(float(t % grid.w), float(t / grid.w)))
		if d > best_d:
			best_d = d
			best = t
	return best


## Sweeps the screen for a point the shell resolves to `tile`. The forward projection lives in the
## view; asking the shell's own converter is what guarantees the press lands where the test thinks.
func _screen_of(tile: int) -> Vector2:
	var y := 24
	while y < 700:
		var x := 24
		while x < 1260:
			if _game._tile_at(Vector2(x, y)) == tile:
				return Vector2(x, y)
			x += 4
		y += 4
	return Vector2(-1, -1)


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_walk: %s 를 못 썼다" % path)


func _click(at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	_game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	_game._unhandled_input(release)
