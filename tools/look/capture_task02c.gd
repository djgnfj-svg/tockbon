extends SceneTree
## **One frame: the hull still at sea with its riders on it** (02-05).
##
## ⚠ **The zoom comes BEFORE the centring and that is the whole of why this file exists.** `_clamp_cam`
## bounds the ground point in the middle of the screen by the visible span, so centring at the opening
## zoom pins the camera a screen-half inside the roam bound and the hull stays off the glass — which is
## what the second pass photographed.

var _dir := ""
var _game: Game = null
var _sec := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_task02c: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_task02c: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_task02c: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	var b: Battle = _game.battle

	# Far enough in that the hull is inside the camera's roam bound, and still SAILING.
	await _advance_until(_near_and_sailing, 40.0)
	_zoom_to(2.2)
	_centre_on(Look.tile_point_px(b.boat_pos[0] as Vector2))
	await _settle(6)
	print("sailing: state=%d riders=%d pos=%s cam=%s"
		% [int(b.boat_state[0]), int(b.boat_riders[0]), str(b.boat_pos[0]),
			str(_game.field_view.cam_px.round())])
	await _shot("20_boat_sailing")
	print("capture_task02c: %s" % _dir)
	quit()


func _near_and_sailing() -> bool:
	var b: Battle = _game.battle
	if b.boat_pos.size() == 0:
		return false
	var p: Vector2 = b.boat_pos[0]
	return p.x > -6.0 and int(b.boat_state[0]) == Battle.BoatState.SAILING


func _advance_until(test: Callable, cap_sec: float) -> void:
	var dt := 1.0 / 60.0
	var spent := 0.0
	while spent < cap_sec:
		_game._process(dt)
		_sec += dt
		spent += dt
		if test.call():
			break
		if int(spent / dt) % 15 == 0:
			await process_frame
	await process_frame
	await process_frame


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
		push_error("capture_task02c: %s 를 못 썼다" % path)
	print("--- %s  t=%.1f zoom=%.2f" % [name, _sec, _game.field_view.zoom])
