extends SceneTree
## **Task 02 on the real screen** — the boat, the keep, the bars, the ground and GAME OVER.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_task02.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.** If it comes back wrong nothing below it is readable.
## ⚠ **Every input is an `InputEvent` handed to the engine.** No Win32, no key injection.
## ⚠ **The sim is driven by calling the shell's own `_process`**, so a hundred seconds of board time
## costs a few real seconds. `set_process(false)` is what stops the engine advancing it a second time.

var _dir := ""
var _game: Game = null
var _sec := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_task02: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_task02: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_task02: 섬이 안 열렸다")
		quit(1)
		return
	# The engine must not advance the sim behind our back — every second below is deliberate.
	_game.set_process(false)
	var b: Battle = _game.battle
	print("island %d x %d  keep_hp=%.1f  soldiers=%d  keep_tiles=%d"
		% [b.grid.w, b.grid.h, b.keep_hp, b.living_soldier_count(), b.keep_tiles.size()])
	await _settle(4)
	await _shot("01_open")

	# --- the ground, before anything walks on it (02-06) -------------------------------------------
	_centre_on(_island_centre())
	_zoom_to(1.7)
	await _settle(6)
	await _shot("02_ground_close")
	_game.field_view.turn_by(45.0)
	_centre_on(_island_centre())
	await _settle(6)
	await _shot("03_ground_turned")
	_game.field_view.turn_by(-45.0)
	_zoom_to(1.0)

	# --- the boat (02-04, 02-05) -------------------------------------------------------------------
	await _advance_until(func() -> bool:
		return b.boat_state.size() > 0 and int(b.boat_state[0]) == Battle.BoatState.ARRIVED, 60.0)
	_centre_on(Look.tile_point_px(b.boat_pos[0] as Vector2))
	_zoom_to(1.9)
	await _settle(6)
	print("boat0 state=%d riders=%d pos=%s linger=%.2f  beasts=%d"
		% [int(b.boat_state[0]), int(b.boat_riders[0]), str(b.boat_pos[0]),
			float(b.boat_linger[0]), b.living_enemy_ids().size()])
	await _shot("04_boat_arrived")

	await _advance(3.6)
	print("boat0 state=%d riders=%d  hulls=%d  beasts=%d"
		% [int(b.boat_state[0]), int(b.boat_riders[0]), b.boat_pos.size(),
			b.living_enemy_ids().size()])
	await _shot("05_boat_gone")

	# --- the keep (02-01, 02-02, 02-09) ------------------------------------------------------------
	_centre_on(_keep_centre())
	_zoom_to(1.5)
	await _settle(6)
	await _advance_until(func() -> bool: return _keep_dist_min() < 2.2, 90.0)
	print("wolves at the keep: dist=%.2f strike_gap=%.2f keep_hp=%.1f soldiers=%d  %s"
		% [_keep_dist_min(), _keep_gap_min(), b.keep_hp, b.living_soldier_count(), _levels()])
	await _shot("06_wolves_at_keep")

	var held := b.keep_hp
	await _advance_until(func() -> bool: return b.keep_hp < held - 0.5, 90.0)
	print("keep falling: keep_hp=%.1f dist=%.2f strike_gap=%.2f soldiers=%d beasts=%d  %s"
		% [b.keep_hp, _keep_dist_min(), _keep_gap_min(), b.living_soldier_count(),
			b.living_enemy_ids().size(), _levels()])
	await _settle(4)
	await _shot("07_keep_hit")

	# --- the loss (02-03) --------------------------------------------------------------------------
	await _advance_until(func() -> bool: return b.lost, 240.0)
	_zoom_to(0.8)
	_centre_on(_island_centre())
	await _settle(8)
	print("lost=%s keep_hp=%.1f t=%.1f soldiers=%d" % [str(b.lost), b.keep_hp, _sec,
		b.living_soldier_count()])
	await _shot("08_game_over")

	print("capture_task02: %s" % _dir)
	quit()


# --- the clock ---------------------------------------------------------------------------------------

## One board second at a time, through the shell's own `_process`. A real frame every 0.25 s so the
## views keep up and nothing is photographed a hundred seconds stale.
func _advance(sec: float) -> void:
	var dt := 1.0 / 60.0
	var n := int(sec / dt)
	for i in n:
		_game._process(dt)
		_sec += dt
		if i % 15 == 14:
			await process_frame
	await process_frame


func _advance_until(test: Callable, cap_sec: float) -> void:
	var dt := 1.0 / 60.0
	var spent := 0.0
	var last_print := 0.0
	while spent < cap_sec:
		_game._process(dt)
		_sec += dt
		spent += dt
		if test.call():
			break
		if spent - last_print >= 10.0:
			last_print = spent
			var b: Battle = _game.battle
			print("  t=%.1f keep_hp=%.1f soldiers=%d beasts=%d boats=%s"
				% [_sec, b.keep_hp, b.living_soldier_count(), b.living_enemy_ids().size(),
					str(b.boat_state)])
		if int(spent / dt) % 15 == 0:
			await process_frame
	await process_frame
	await process_frame


# --- where things are --------------------------------------------------------------------------------

func _keep_centre() -> Vector2:
	var b: Battle = _game.battle
	if b.keep_tiles.is_empty():
		return _island_centre()
	var sum := Vector2.ZERO
	for t in b.keep_tiles:
		sum += Vector2(int(t) % b.grid.w, int(t) / b.grid.w)
	return Look.tile_point_px(sum / float(b.keep_tiles.size()))


func _island_centre() -> Vector2:
	var b: Battle = _game.battle
	var sum := Vector2.ZERO
	var n := 0
	for t in b.grid.passable.size():
		if int(b.grid.passable[t]) != 0:
			sum += Vector2(t % b.grid.w, t / b.grid.w)
			n += 1
	if n == 0:
		return Look.tile_point_px(Vector2(b.grid.w, b.grid.h) * 0.5)
	return Look.tile_point_px(sum / float(n))


## The nearest living 짐승 to any 성채 조각, in 조각.
func _keep_gap_min() -> float:
	var b: Battle = _game.battle
	var best := 999.0
	for raw in b.living_enemy_ids():
		var e := int(raw)
		var g: float = b.keep_gap(b.enemy_pos[e])
		if g < best:
			best = g
	return best


## Plain distance from the nearest living 짐승 to a 성채 조각, in 조각 — no level rule in it, so it
## still answers while the 짐승 is shut out of striking.
func _keep_dist_min() -> float:
	var b: Battle = _game.battle
	var best := 999.0
	for raw in b.living_enemy_ids():
		var e := int(raw)
		var p: Vector2 = b.enemy_pos[e]
		for k in b.keep_tiles.size():
			var t := int(b.keep_tiles[k])
			var c := Vector2(t % b.grid.w, t / b.grid.w)
			best = minf(best, p.distance_to(c))
	return best


## The 눈금 every living 짐승 stands on — this is what says whether one climbed the 계단.
func _levels() -> String:
	var b: Battle = _game.battle
	var out := "levels="
	for raw in b.living_enemy_ids():
		var e := int(raw)
		var p: Vector2 = b.enemy_pos[e]
		var tx := int(round(p.x))
		var ty := int(round(p.y))
		if tx < 0 or ty < 0 or tx >= b.grid.w or ty >= b.grid.h:
			continue
		out += "%d " % int(b.grid.level[ty * b.grid.w + tx])
	return out


# --- the camera ----------------------------------------------------------------------------------------

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
		push_error("capture_task02: %s 를 못 썼다" % path)
	print("--- %s  t=%.1f zoom=%.2f" % [name, _sec, _game.field_view.zoom])
