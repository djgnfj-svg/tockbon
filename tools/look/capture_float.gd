extends SceneTree
## **What is floating on the arriving boat.** One frozen moment, photographed once with everything on
## and then once per part removed, so the part that takes the floating away with it is the answer.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_float.gd -- <out-dir>
## ```
##
## ⚠ **`00_title` is the known-answer frame.** ⚠ **Every input is an `InputEvent` handed to the engine.**
## ⚠ **The shell's `_process` AND the field's are both switched off**, and the field is repainted by
## calling `_process(0.0)` by hand — so the sea clock never advances, the bob never moves the hull
## between two shots of the same moment, and the wake never ages out from under the comparison.

var _dir := ""
var _game: Game = null
var _fv: FieldView = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_float: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_float: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_float: 섬이 안 열렸다")
		quit(1)
		return
	_fv = _game.field_view
	await _shot("01_open")

	# Let a hull get well clear of the ring and lay a full trail behind it.
	await _until(11.0)

	# --- freeze -------------------------------------------------------------------------------------
	_game.set_process(false)
	_fv.set_process(false)
	await process_frame

	_report()

	await _series("a", 5)
	await _series("b", 3)

	print("capture_float: %s" % _dir)
	quit()


## One framing, then that framing with one part taken out at a time.
func _series(tag: String, zoom_steps: int) -> void:
	_frame_on_boat(0, zoom_steps)
	_repaint()
	await _shot("%s0_all" % tag)

	# 1 — the rig. Sail, yard and mast together, then the sail alone.
	_hide_in_hulls(["boat_sail"], false)
	_repaint()
	await _shot("%s1_no_sail" % tag)
	_hide_in_hulls(["boat_sail", "boat_yard", "boat_mast"], false)
	_repaint()
	await _shot("%s2_no_rig" % tag)
	_hide_in_hulls(["boat_sail", "boat_yard", "boat_mast"], true)

	# 2 — the wake. Every white mark the water makes about a hull.
	_wake(0.0)
	_repaint()
	await _shot("%s3_no_wake" % tag)
	_wake(Look.WAKE_ALPHA)

	# 3 — the riders, then the riders and their shadow discs.
	# ⚠ **The wolf's own picture row, which the deck reads since 2026-08-30.** `_tex_rider` was the
	# deck's second copy of these four and it is deleted; emptying the row is what leaves `_beast_tex`
	# with nothing to answer, so `_paint_riders` returns before it draws one.
	var pics: Array = _fv._tex_facing[Rules.WOLF]
	var keep := pics.duplicate()
	pics.clear()
	_repaint()
	await _shot("%s4_no_riders" % tag)
	_hide_in_hulls(["deck_shadows"], false)
	_repaint()
	await _shot("%s5_no_riders_no_discs" % tag)
	_hide_in_hulls(["deck_shadows"], true)
	pics.assign(keep)

	# 4 — the bow post and the stern block.
	_hide_in_hulls(["boat_stem", "boat_tail"], false)
	_repaint()
	await _shot("%s6_no_posts" % tag)
	_hide_in_hulls(["boat_stem", "boat_tail"], true)

	# 5 — the bare hull: no rig, no posts, no riders, no discs, no wake.
	_hide_in_hulls(["boat_sail", "boat_yard", "boat_mast", "boat_stem", "boat_tail",
		"deck_shadows"], false)
	pics.clear()
	_wake(0.0)
	_repaint()
	await _shot("%s7_hull_only" % tag)
	_wake(Look.WAKE_ALPHA)
	pics.assign(keep)
	_hide_in_hulls(["boat_sail", "boat_yard", "boat_mast", "boat_stem", "boat_tail",
		"deck_shadows"], true)
	_repaint()


# --- the hand ---------------------------------------------------------------------------------------

func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.pressed = down
		root.push_input(ev, true)


## Centre boat `i` and zoom in `n` notches, re-centring after every notch — `zoom_at` pivots on the
## screen point it is given, so a centre written once drifts out from under the boat as it zooms.
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


## Repaint with the clock standing still. `_process` is off on both, so this is the only thing that
## moves the picture — and it moves it without advancing `_sea_clock`.
func _repaint() -> void:
	_fv._process(0.0)


func _wake(a: float) -> void:
	var mat := _fv._sea.material_override as ShaderMaterial
	mat.set_shader_parameter("wake_alpha", a)


## Hide (or show) every node under every pooled hull whose name contains one of `words`.
func _hide_in_hulls(words: Array, show: bool) -> void:
	for hull in _fv._boats:
		_walk(hull, words, show)


func _walk(n: Node, words: Array, show: bool) -> void:
	for c in n.get_children():
		var low := String(c.name).to_lower()
		var hit := false
		for w in words:
			if low.contains(String(w)):
				hit = true
		if hit and c is Node3D:
			(c as Node3D).visible = show
		else:
			_walk(c, words, show)


# --- the clock and the shutter ----------------------------------------------------------------------

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
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_float: %s 를 못 썼다" % path)
	print("--- %s  zoom=%.3f cam=%s" % [name, _fv.zoom if _fv != null else 0.0,
		str(_fv.cam_px.round()) if _fv != null else ""])


## What the numbers say about the frozen moment, so the pictures can be read against them.
func _report() -> void:
	var b: Battle = _game.battle
	print("=== frozen at t=%.2f, %d hull(s)" % [b.elapsed, b.boat_pos.size()])
	print("=== SEA_Y=%.4f  DRAFT=%.4f  hull bottom sits %.4f 조각 under the sea"
		% [Look.SEA_Y_TILES, Look.BOAT_DRAFT_TILES, -Look.BOAT_DRAFT_TILES])
	print("=== hull_beam handed to the water = %.4f 조각; WAKE_W=%.4f  SIDE_CLOSE=%.4f"
		% [Rules.BOAT_HULL_BEAM_TILES * 0.5, Look.WAKE_W_TILES, Look.WAKE_SIDE_CLOSE])
	for i in b.boat_pos.size():
		var hull := _fv._boats[i] if i < _fv._boats.size() else null
		var y := hull.position.y if hull != null else 0.0
		print("=== boat %d at %s  riders=%d  hull.y=%.4f (sea %.4f)"
			% [i, str(b.boat_pos[i]), int(b.boat_riders[i]), y, Look.SEA_Y_TILES])
