extends SceneTree
## Reads NO pixels — so headless is correct here, exactly as `probe_run.gd`'s own header argued.
## It asks one question the frames raise: on the refit screen the slot strip's rectangles and the
## board's cells occupy the same pixels, and `_refit_input` asks `slot_at` BEFORE `cell_at` — so
## which of the two does a press in the shared region actually reach?
##
## ⚠ It never touches the user's mouse: every event is built here and handed to
## `game._unhandled_input`, the entry the OS uses.


func _initialize() -> void:
	_run()


## ⚠ **`await process_frame` after `add_child` is not optional.** A child added during
## `_initialize` has not run `_ready` yet, so every view on the shell is still `null` and each
## press faults instead of routing — measured, and it reads exactly like a dead input table.
func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._start_run()
	game.run.seed_cards(20260821)
	game.run.enter_node(0)
	game.run.finish_island(true)
	game._show_state()
	_click(game, Look.card_rect_px(0).get_center())
	_click(game, Look.card_rect_px(4).get_center())
	var loadout := game.run.army.loadout
	for p in Rules.ITEM_CELLS:
		loadout.take_card(p % Rules.item_count())
	_click(game, Look.refit_slot_rect_px(0).get_center())
	for _n in Rules.ITEM_CELLS:
		_click(game, Look.refit_held_rect_px(0).get_center())
	print("slot 0 board full? open=%d cells=%s" % [
		game.refit_view.open_slot_index(), str(_cells(loadout, 0))])

	# Every cell, pressed at its own centre. A press that unfits leaves the cell empty; a press the
	# strip stole leaves the board on the OTHER slot with the cell untouched.
	for p in Rules.ITEM_CELLS:
		var before := game.refit_view.open_slot_index()
		var at := Look.refit_cell_rect_px(p).get_center()
		_click(game, at)
		var after := game.refit_view.open_slot_index()
		var still := loadout.fitted_item(0, p)
		print("cell %d at %s: open %d -> %d, slot0 cell now %d, slot_at=%d, cell_at=%d" % [
			p, str(at), before, after, still, game.refit_view.slot_at(at),
			game.refit_view.cell_at(at)])
		if after != 0:
			game.refit_view.open_slot(0)

	# And the held rows: does anything on the pile share a rectangle with the strip?
	for row in 4:
		var at := Look.refit_held_rect_px(row).get_center()
		print("held row %d at %s: slot_at=%d" % [row, str(at), game.refit_view.slot_at(at)])
	quit()


func _cells(loadout: Loadout, slot: int) -> Array:
	var out := []
	for p in Rules.ITEM_CELLS:
		out.append(loadout.fitted_item(slot, p))
	return out


func _click(game: Game, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	game._unhandled_input(press)
