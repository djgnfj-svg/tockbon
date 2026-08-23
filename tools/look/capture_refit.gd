extends SceneTree
## The game screenshots the two screens this round added: the reward pick and the refit board.
## **verify-look without the bridge**, the sibling of `capture_map.gd` and written against the same
## three measured rules its header states.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_refit.gd -- <output-dir>
## ```
##
## ⚠ **Not `--headless`** (no swapchain, and the dummy renderer never emits `frame_post_draw`), the
## user's mouse and keyboard are never taken — every gesture is an `InputEvent` handed to
## `game._unhandled_input` inside the engine — and `RenderingServer.frame_post_draw` is awaited before
## every read or the shot photographs the PREVIOUS frame.
##
## ⚠ **The known-answer shot is first.** `00_title` is a screen this repo has already looked at; if it
## comes back wrong, nothing below it can be read.

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_refit: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_refit: --headless 로는 픽셀을 못 읽는다. 창을 띄워서 돌려라")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	# The sim freezes; each view ages on its own clock. See `capture_map.gd`'s header.
	_game.set_process(false)
	await process_frame

	# --- the known answer -------------------------------------------------------------------------
	await _settle(24)
	await _shot("00_title")

	# --- a won fight, which is what pays the six cards --------------------------------------------
	_game._start_run()
	_game.run.seed_cards(20260821)
	_game.run.enter_node(0)
	_game.run.finish_island(true)
	_game._show_state()
	print("capture_refit: state after a win = %d (PICK is %d)" % [_game.run.state(), Run.State.PICK])
	await _settle(72)
	await _shot("10_pick_six_cards")

	# hover the middle card of the top row
	_motion(Look.card_rect_px(1).get_center())
	await _settle(18)
	await _shot("11_pick_hover_card1")

	# take one
	_click(Look.card_rect_px(0).get_center())
	await _settle(24)
	await _shot("12_pick_one_taken")

	# take the second — the sim leaves PICK on this press
	_click(Look.card_rect_px(4).get_center())
	print("capture_refit: state after two picks = %d (REFIT is %d)" % [_game.run.state(), Run.State.REFIT])
	await _settle(24)
	await _shot("13_after_second_pick")

	# --- the refit screen, step one: the slot strip -----------------------------------------------
	await _settle(24)
	await _shot("20_refit_strip")

	_motion(Look.refit_slot_rect_px(0).get_center())
	await _settle(18)
	await _shot("21_refit_strip_hover")

	# A fuller pile than two cards, so a board can actually be filled. Four more cards straight into
	# the pile — the same thing four more wins would have paid.
	var loadout := _game.run.army.loadout
	loadout.take_card(Rules.Part.CHEST, Rules.Species.BIRD)
	loadout.take_card(Rules.Part.ARM, Rules.Species.FISH)
	loadout.take_card(Rules.Part.LEG, Rules.Species.MAMMAL)
	loadout.take_card(Rules.Part.HAND, Rules.Species.BIRD)
	loadout.take_card(Rules.Part.HEAD, Rules.Species.FISH)
	loadout.take_card(Rules.Part.BELLY, Rules.Species.MAMMAL)

	# --- step two: slot 0's board -----------------------------------------------------------------
	_click(Look.refit_slot_rect_px(0).get_center())
	print("capture_refit: board open = %s, slot = %d" % [
		_game.refit_view.is_board_open(), _game.refit_view.open_slot_index()])
	await _settle(24)
	await _shot("30_refit_board_empty")

	# fit the first held row, and catch the flash mid-flight as well as settled
	_click(Look.refit_held_rect_px(0).get_center())
	await _settle(4)
	await _shot("31_refit_fit_flash")
	await _settle(48)
	await _shot("32_refit_one_fitted")

	# fill the rest of the board off the pile. The pile COMPACTS, so row 0 every time.
	for _n in 5:
		_click(Look.refit_held_rect_px(0).get_center())
		await _settle(30)
	await _settle(48)
	await _shot("33_refit_board_full")
	_print_board(0)

	# hover a cell, then unfit it
	_motion(Look.refit_cell_rect_px(Rules.Part.ARM).get_center())
	await _settle(18)
	await _shot("34_refit_hover_cell")
	_click(Look.refit_cell_rect_px(Rules.Part.ARM).get_center())
	await _settle(48)
	await _shot("35_refit_after_unfit")

	# --- the other slot's board, which is the body preview's whole job ----------------------------
	_click(Look.refit_slot_rect_px(1).get_center())
	await _settle(24)
	await _shot("36_refit_slot2_board")

	print("capture_refit: 열두 장, %s" % _dir)
	quit()


func _print_board(slot: int) -> void:
	var loadout := _game.run.army.loadout
	var cells := []
	for p in Rules.part_count():
		cells.append(loadout.fitted_species(slot, p))
	var stats := []
	for col in Rules.PART_COL_TOTAL:
		stats.append("%.2f" % loadout.stat_of(slot, col))
	print("capture_refit: slot %d cells = %s, stats = %s, pile = %d" % [
		slot, str(cells), str(stats), loadout.held_part.size()])


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_refit: %s 를 못 썼다" % path)


## A press and its release, exactly the two events a mouse sends. The shell acts on the press.
func _click(at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	_game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	_game._unhandled_input(release)


func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	_game._unhandled_input(motion)
