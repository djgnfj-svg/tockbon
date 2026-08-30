extends SceneTree
## **Which white mark stands off the hull.** The water draws four things about a boat — a wide halo, a
## dark contact shadow, a bright break line outside that shadow, and two trail lines astern — and this
## turns them off one at a time at the framing the user cropped.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_float2.gd -- <out-dir>
## ```

var _dir := ""
var _game: Game = null
var _fv: FieldView = null
var _mat: ShaderMaterial = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_float2: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_float2: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_float2: 섬이 안 열렸다")
		quit(1)
		return
	_fv = _game.field_view
	_mat = _fv._sea.material_override as ShaderMaterial
	await _shot("01_open")
	await _until(11.0)

	_game.set_process(false)
	_fv.set_process(false)
	await process_frame

	# The user's crop looks along the hull at an angle, not broadside. Turn the camera, not the boat.
	_fv.cam_yaw_deg = 40.0
	await _series("y")
	_fv.cam_yaw_deg = 0.0
	await _series("s")

	print("capture_float2: %s" % _dir)
	quit()


func _series(tag: String) -> void:
	_frame_on_boat(0, 8)
	_repaint()
	await _shot("%s0_all" % tag)

	_p("hull_break_amt", 0.0)
	_repaint()
	await _shot("%s1_no_break_line" % tag)
	_p("hull_break_amt", Look.HULL_BREAK_AMT)

	_p("hull_halo_amt", 0.0)
	_repaint()
	await _shot("%s2_no_halo" % tag)
	_p("hull_halo_amt", Look.HULL_HALO_AMT)

	var col := Look.hull_shadow_colour()
	_p("hull_shadow_col", Color(col.r, col.g, col.b, 0.0))
	_repaint()
	await _shot("%s3_no_contact_shadow" % tag)
	_p("hull_shadow_col", col)

	# Everything the water says about a hull, off at once.
	_p("wake_alpha", 0.0)
	_p("hull_halo_amt", 0.0)
	_p("hull_shadow_col", Color(col.r, col.g, col.b, 0.0))
	_repaint()
	await _shot("%s4_water_says_nothing" % tag)
	_p("wake_alpha", Look.WAKE_ALPHA)
	_p("hull_halo_amt", Look.HULL_HALO_AMT)
	_p("hull_shadow_col", col)
	_repaint()


func _p(k: String, v: Variant) -> void:
	_mat.set_shader_parameter(k, v)


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = down
		root.push_input(ev, true)


func _frame_on_boat(i: int, n: int) -> void:
	_centre_on_boat(i)
	for _k in n:
		_fv.zoom_at(Vector2(640.0, 360.0), Look.ZOOM_STEP)
		_centre_on_boat(i)


func _centre_on_boat(i: int) -> void:
	var b: Battle = _game.battle
	if i >= b.boat_pos.size():
		return
	var world := Look.tile_point_px(b.boat_pos[i] as Vector2)
	_fv.cam_px = world - _fv._visible_ground_px() * 0.5
	_fv._clamp_cam()


func _repaint() -> void:
	_fv._process(0.0)


func _until(sec: float) -> void:
	while _game.battle != null and _game.battle.elapsed < sec:
		await process_frame


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.save_png("%s/%s.png" % [_dir, name]) != OK:
		push_error("capture_float2: %s 를 못 썼다" % name)
	print("--- %s" % name)
