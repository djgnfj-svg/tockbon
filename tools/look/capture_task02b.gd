extends SceneTree
## **Task 02, second pass** — the three things the first pass could not photograph on its own:
## the riders on the deck while the hull is still sailing, a hurt 몸 wearing a bar, and the recruit
## ceiling.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_task02b.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.**
## ⚠ **The last part STAGES the board** — `keep_hp` is held at full so the round runs past 100 초 and
## the ceiling can be looked at. Nothing else is written to the sim.

var _dir := ""
var _game: Game = null
var _sec := 0.0
var _pin_keep := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_task02b: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_task02b: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_task02b: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	# ⚠ **STAGED FROM THE FIRST FRAME**: the 성채 is held at full health for the whole run. Without it
	# the round is lost at 38 초 and `Battle.step` returns early forever — every second after that is a
	# frozen board, which is exactly what the first attempt photographed.
	_pin_keep = true
	var b: Battle = _game.battle

	# --- the riders, while the hull is still at sea (02-05) ----------------------------------------
	await _advance_until(func() -> bool: return b.boat_pos.size() > 0, 20.0)
	await _advance(8.0)
	_centre_on(Look.tile_point_px(b.boat_pos[0] as Vector2))
	_zoom_to(2.2)
	await _settle(6)
	print("sailing: state=%d riders=%d pos=%s" % [int(b.boat_state[0]), int(b.boat_riders[0]),
		str(b.boat_pos[0])])
	await _shot("10_boat_sailing")

	# --- a hurt 몸 (02-02) --------------------------------------------------------------------------
	await _advance_until(func() -> bool: return b.living_enemy_ids().size() > 0, 40.0)
	await _advance(1.0)
	# **The 검사 are ordered at the 늑대** — the player's own hand does this in the game; the tool
	# does it through `order_walk`, which is the same call the shell makes.
	var beasts := b.living_enemy_ids()
	if not beasts.is_empty():
		var e := int(beasts[0])
		var p: Vector2 = b.enemy_pos[e]
		var tile := int(round(p.y)) * b.grid.w + int(round(p.x))
		for raw in b.ashore_ids():
			b.order_walk(int(raw), tile)
	await _advance_until(func() -> bool: return _anybody_hurt(), 40.0)
	_centre_on(_hurt_centre())
	_zoom_to(2.2)
	await _settle(6)
	print("hurt: %s" % _hp_line())
	await _shot("11_hurt_bars")
	await _advance(2.0)
	_centre_on(_hurt_centre())
	await _settle(4)
	print("hurt2: %s" % _hp_line())
	await _shot("12_hurt_bars_later")

	# --- the recruit ceiling (02-09) ---------------------------------------------------------------
	var seen := {}
	for k in 12:
		await _advance(10.0)
		var n := b.living_soldier_count()
		print("  t=%.0f soldiers=%d roster=%d beasts=%d" % [_sec, n, b.army.type_id.size(),
			b.living_enemy_ids().size()])
		if not seen.has(n):
			seen[n] = _sec
	print("roster over time: %s" % str(seen))
	_centre_on(_keep_centre())
	_zoom_to(1.9)
	await _settle(6)
	await _shot("13_recruits")

	print("capture_task02b: %s" % _dir)
	quit()


# --- the clock ---------------------------------------------------------------------------------------

func _tick(dt: float) -> void:
	if _pin_keep and _game.battle != null:
		_game.battle.keep_hp = Rules.KEEP_MAX_HP
	_game._process(dt)
	_sec += dt


func _advance(sec: float) -> void:
	var dt := 1.0 / 60.0
	var n := int(sec / dt)
	for i in n:
		_tick(dt)
		if i % 15 == 14:
			await process_frame
	await process_frame


func _advance_until(test: Callable, cap_sec: float) -> void:
	var dt := 1.0 / 60.0
	var spent := 0.0
	while spent < cap_sec:
		_tick(dt)
		spent += dt
		if test.call():
			break
		if int(spent / dt) % 15 == 0:
			await process_frame
	await process_frame
	await process_frame


# --- who is hurt --------------------------------------------------------------------------------------

func _anybody_hurt() -> bool:
	var b: Battle = _game.battle
	for raw in b.ashore_ids():
		var i := int(raw)
		if float(b.soldier_hp[i]) < b.army.max_hp_of(i) - 0.01:
			return true
	for raw in b.living_enemy_ids():
		var e := int(raw)
		if float(b.enemy_hp[e]) < Rules.hp_of(int(b.enemy_type[e])) - 0.01:
			return true
	return false


func _hurt_centre() -> Vector2:
	var b: Battle = _game.battle
	for raw in b.ashore_ids():
		var i := int(raw)
		if float(b.soldier_hp[i]) < b.army.max_hp_of(i) - 0.01:
			return Look.tile_point_px(b.soldier_pos[i] as Vector2)
	for raw in b.living_enemy_ids():
		var e := int(raw)
		if float(b.enemy_hp[e]) < Rules.hp_of(int(b.enemy_type[e])) - 0.01:
			return Look.tile_point_px(b.enemy_pos[e] as Vector2)
	return _keep_centre()


func _hp_line() -> String:
	var b: Battle = _game.battle
	var out := "soldiers "
	for raw in b.ashore_ids():
		var i := int(raw)
		out += "%.0f/%.0f " % [float(b.soldier_hp[i]), b.army.max_hp_of(i)]
	out += "| beasts "
	for raw in b.living_enemy_ids():
		var e := int(raw)
		out += "%.0f/%.0f " % [float(b.enemy_hp[e]), Rules.hp_of(int(b.enemy_type[e]))]
	out += "| keep %.0f" % b.keep_hp
	return out


func _keep_centre() -> Vector2:
	var b: Battle = _game.battle
	if b.keep_tiles.is_empty():
		return Look.tile_point_px(Vector2(b.grid.w, b.grid.h) * 0.5)
	var sum := Vector2.ZERO
	for t in b.keep_tiles:
		sum += Vector2(int(t) % b.grid.w, int(t) / b.grid.w)
	return Look.tile_point_px(sum / float(b.keep_tiles.size()))


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
		push_error("capture_task02b: %s 를 못 썼다" % path)
	print("--- %s  t=%.1f zoom=%.2f" % [name, _sec, _game.field_view.zoom])
