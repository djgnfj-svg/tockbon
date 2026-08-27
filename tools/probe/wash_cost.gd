extends SceneTree
## **How long does the ground mat take to build?** The island's own `setup` is timed, then the mat
## alone, so「섬을 여는 데 걸리는 시간」and「그중 마당이 먹는 시간」are two numbers rather than one.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/probe/wash_cost.gd
## ```

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

	var t0 := Time.get_ticks_usec()
	game._show_state()
	var t1 := Time.get_ticks_usec()
	if game.battle == null:
		push_error("wash_cost: 섬이 안 열렸다")
		quit(1)
		return
	var fv: FieldView = game.field_view
	var runs := 5
	var t2 := Time.get_ticks_usec()
	for _i in runs:
		fv._rebuild_wash()
	var t3 := Time.get_ticks_usec()
	print("wash_cost: 섬 여는 데 %.1f ms" % [float(t1 - t0) / 1000.0])
	print("wash_cost: 마당 한 번 굽는 데 %.1f ms (%d 번 평균)" % [
		float(t3 - t2) / 1000.0 / float(runs), runs])
	quit()
