extends SceneTree
## **The ground and nothing else.** The buildings are hidden and no body is stood up, so what is on
## screen is the island, the sea and the mats — which is what the user asked to look at.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_ground.gd -- <output-dir>
## ```
##
## ⚠ **It HIDES rather than deletes.** Nothing here changes what the game builds; a frame that removed
## the keep from the board would be a picture of an island this game does not have.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_ground: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_ground: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	_game.set_process(false)
	await process_frame

	# ⚠ **Three lines stood here walking past the card and refit screens** and both are deleted
	# (2026-08-28). `_start_run` opens the island outright.
	_game._start_run()
	_game._show_state()
	if _game.battle == null:
		push_error("capture_ground: 섬이 안 열렸다")
		quit(1)
		return

	# The keep and the scatter go dark.
	var fv := _game.field_view
	for key in ["_builds", "_props"]:
		var node = fv.get(key)
		if node != null:
			node.visible = false
	# And nobody stands on it. **Back to RESERVE and not killed**: a corpse would still be a body the
	# picture could draw, and `ashore_ids` is the whole filter the field draws soldiers through.
	var b: Battle = _game.battle
	for raw_id in b.ashore_ids():
		var i := int(raw_id)
		b.soldier_state[i] = Battle.SoldierState.RESERVE
		b.soldier_pos[i] = Battle.OFFMAP
	print("capture_ground: 섬 %d x %d, 서 있는 몸 %d" % [b.grid.w, b.grid.h, b.ashore_ids().size()])

	await _settle(40)
	await _shot("00_ground")
	for _n in 5:
		fv.zoom_at(Vector2(640, 360), 1.25)
	await _settle(16)
	await _shot("10_ground_close")
	print("capture_ground: %s" % _dir)
	quit()


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_ground: %s 를 못 썼다" % path)
