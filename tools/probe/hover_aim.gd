extends SceneTree
## **Does the hover plate land under the cursor?** One frame, no shots, no window needed for the
## arithmetic — it asks the shell which tile a screen point is on, then asks the CAMERA where that
## tile's centre lands back on screen, and prints the gap.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/probe/hover_aim.gd
## ```
##
## ⚠ Not `--headless`: `unproject_position` needs a real camera with a real viewport size.

func _initialize() -> void:
	_run()


func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	await process_frame

	game._start_run()
	game.run.seed_cards(20260827)
	if game.run.state() == Run.State.PICK:
		game.run.take_card(0)
	if game.run.state() == Run.State.REFIT:
		game.run.close_refit()
	game._show_state()
	if game.battle == null:
		push_error("hover_aim: 섬이 안 열렸다")
		quit(1)
		return
	for _i in 40:
		await process_frame

	var grid: Grid = game.battle.grid
	var fv: FieldView = game.field_view
	var cam: Camera3D = fv.get("_cam")
	print("hover_aim: 섬 %d x %d, zoom %.3f, cam %s" % [grid.w, grid.h, fv.zoom, str(fv.cam_px)])

	var worst := 0.0
	for at in [Vector2(500, 200), Vector2(640, 300), Vector2(700, 360), Vector2(400, 420),
			Vector2(880, 300), Vector2(536, 344)]:
		var t: int = game._tile_at(at)
		if t < 0:
			print("hover_aim: %s -> 섬 밖" % str(at))
			continue
		fv.set_hover_tile(-1)
		fv.set_hover_tile(t)
		var plate: MeshInstance3D = fv.get("_hover")
		var back: Vector2 = cam.unproject_position(plate.global_position)
		var gap: float = (at as Vector2).distance_to(back)
		worst = maxf(worst, gap)
		print("hover_aim: 누른 %s -> 칸 %d (%d,%d) 층 %d -> 판이 화면 %s, 어긋남 %.1f px" % [
			str(at), t, t % grid.w, t / grid.w, grid.level_of(t), str(back), gap])
	print("hover_aim: 가장 크게 어긋난 값 %.1f px (칸 하나는 화면에서 약 %.1f px)" % [
		worst, Look.TILE_PX * fv.zoom])
	quit()
