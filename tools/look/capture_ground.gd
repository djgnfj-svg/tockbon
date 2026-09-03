extends SceneTree
## **The ground and nothing else.** The buildings are hidden and no body is stood up, so what is on
## screen is the island, the sea and the mats — which is what the user asked to look at.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_ground.gd -- <output-dir> [blocks|baked]
## ```
##
## ⚠ **It HIDES rather than deletes.** Nothing here changes what the game builds; a frame that removed
## the keep from the board would be a picture of an island this game does not have.
##
## ⚠⚠ **THE SECOND ARGUMENT IS THE WHOLE POINT OF SHOOTING THIS TWICE** (티켓 08-01, stage 2). The
## ground is either the board's 칸 stood out of `pieces.glb` or the one mesh baked into `island.glb`,
## and the question 「did the look survive being taken apart into blocks」 is answered by the two
## frames side by side and by nothing else. **The camera is untouched between them**, so the only
## thing that differs is `FieldView.ground_source`.

var _dir := ""
var _source := FieldView.Ground.KIT_BLOCKS
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_ground: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if args.size() > 1:
		if args[1] == "baked":
			_source = FieldView.Ground.BAKED_MESH
		elif args[1] != "blocks":
			push_error("capture_ground: 둘째 인자는 blocks 아니면 baked 다")
			quit(1)
			return
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
	# ⚠⚠ **`_game._show_state()` STOOD HERE AND `Game` HAS NO SUCH FUNCTION** (found 2026-09-03). The
	# call faulted, `_run()` was abandoned on the spot, and the process sat with an open window forever
	# — **no PNG, exit code 0, and nothing on screen to say so.** `capture_boat.gd` calls `_start_run`
	# and nothing else, which is what this file does now.
	if _game.battle == null:
		push_error("capture_ground: 섬이 안 열렸다")
		quit(1)
		return

	# The keep and the scatter go dark.
	var fv := _game.field_view
	# ⚠ **Rebuilt rather than set before `_start_run`.** `_open_island` is what calls `setup`, and the
	# arm has to be in place by then; standing the ground again afterwards runs the very same function
	# the game runs and leaves everything else — the camera included — where the opening put it.
	if fv.ground_source != _source:
		fv.ground_source = _source
		fv._rebuild_terrain()
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
	print("capture_ground: 섬 %d x %d, 서 있는 몸 %d, 땅은 %s" % [b.grid.w, b.grid.h,
		b.ashore_ids().size(), "블록" if _source == FieldView.Ground.KIT_BLOCKS else "구운 메시"])

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
