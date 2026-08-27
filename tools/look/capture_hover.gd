extends SceneTree
## The game screenshots the HOVER PLATE — the one thing this repo has built and never looked at.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_hover.gd -- <output-dir>
## ```
##
## Obeys this folder's four rules: not `--headless`, no OS input, `frame_post_draw` before every read,
## and a known-answer shot first.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_hover: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_hover: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	_game.set_process(false)
	await process_frame

	await _settle(24)
	await _shot("00_title")

	# --- walk the run onto the island -------------------------------------------------------------
	_game._start_run()
	_game.run.seed_cards(20260827)
	if _game.run.state() == Run.State.PICK:
		_game.run.take_card(0)
	if _game.run.state() == Run.State.REFIT:
		_game.run.close_refit()
	_game._show_state()
	print("capture_hover: state = %d (BATTLE is %d), battle = %s" % [
		_game.run.state(), Run.State.BATTLE, str(_game.battle != null)])
	if _game.battle == null:
		push_error("capture_hover: 섬이 안 열렸다")
		quit(1)
		return
	await _settle(48)
	await _shot("10_island_no_plate")

	# --- which screen point lands on which tile ----------------------------------------------------
	var grid: Grid = _game.battle.grid
	var seen := {}
	var y := 24
	while y < 700:
		var x := 24
		while x < 1260:
			var t: int = _game._tile_at(Vector2(x, y))
			if t >= 0 and not seen.has(t):
				seen[t] = Vector2(x, y)
			x += 4
		y += 4
	print("capture_hover: 화면에 걸린 칸 %d 개, 섬은 %d x %d" % [seen.size(), grid.w, grid.h])

	# --- classify -----------------------------------------------------------------------------------
	var inner := -1
	var stair := -1
	var upper := -1
	var coast := -1
	for t in seen.keys():
		var lv: int = grid.level_of(t)
		var tx: int = t % grid.w
		var ty: int = int(t / grid.w)
		if int(grid.water[t]) == 1:
			continue
		var touches_water := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = tx + d.x
			var ny: int = ty + d.y
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				touches_water = true
			elif int(grid.water[ny * grid.w + nx]) == 1:
				touches_water = true
		if Grid.is_stair_level(lv):
			if stair < 0:
				stair = t
		elif lv >= 2:
			if upper < 0:
				upper = t
		elif lv == 0:
			if touches_water:
				if coast < 0:
					coast = t
			elif inner < 0:
				inner = t
	print("capture_hover: 안쪽=%d 계단=%d 이층=%d 해안=%d" % [inner, stair, upper, coast])

	await _plate("20_plate_inner", inner, seen)
	await _plate("21_plate_stair", stair, seen)
	await _plate("22_plate_upper", upper, seen)
	await _plate("23_plate_coast", coast, seen)

	# --- the same four zoomed all the way in, because the two known defects are small ---------------
	for _n in 6:
		_game.field_view.zoom_at(Vector2(640, 360), 1.25)
	await _settle(12)
	await _plate("30_zoom_stair", stair, seen)
	await _plate("31_zoom_coast", coast, seen)
	await _plate("32_zoom_inner", inner, seen)

	print("capture_hover: %s" % _dir)
	quit()


func _plate(name: String, tile: int, seen: Dictionary) -> void:
	if tile < 0:
		print("capture_hover: %s — 그런 칸이 화면에 없다" % name)
		return
	# The camera may have moved (zoom), so ask the shell where that tile is NOW.
	var at: Vector2 = seen[tile]
	var hit: int = _game._tile_at(at)
	if hit != tile:
		at = _find_on_screen(tile)
		if at.x < 0.0:
			print("capture_hover: %s — 줌 뒤에 칸 %d 이 화면 밖" % [name, tile])
			return
	_motion(at)
	await _settle(16)
	var fv := _game.field_view
	var plate: MeshInstance3D = fv.get("_hover")
	var cam: Camera3D = fv.get("_cam")
	var on_screen := cam.unproject_position(plate.global_position) if cam != null and plate != null else Vector2(-1, -1)
	print("capture_hover: %s — 칸 %d, 커서 %s, 판 보임=%s, 판 위치 %s, 판 화면 %s" % [
		name, tile, str(at), str(plate.visible), str(plate.position), str(on_screen)])
	await _shot(name)


func _find_on_screen(tile: int) -> Vector2:
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
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_hover: %s 를 못 썼다" % path)


func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	_game._unhandled_input(motion)
