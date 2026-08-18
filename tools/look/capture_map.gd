extends SceneTree
## The game screenshots its own map. **verify-look without the bridge**, rebuilt for the third game's
## shell — the three scripts this folder's README describes drove the swarm game and died with it.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_map.gd -- <output-dir>
## ```
##
## Ten PNGs, about ten seconds, and it quits on its own. It answers two questions: the one
## `boat-and-landing` stage 3 puts on screen — **can the player read the island before sending a
## boat** — and the one `title-and-map` puts in front of it, **can the player read the title and the
## node map**, which is that round's acceptance row and the row the previous round failed on contact
## with a human.
##
## ⚠ **The game no longer opens on an island**, so this file starts a run itself: `_start_run()` and
## then `_enter_node(0)`, which are the shell's own two verbs. Calling them directly skips the
## `MAP_TRAVEL_SEC` hold, which `_process(false)` below would never age anyway.
##
## The three rules from this folder's README still bind and are re-stated where they bite:
##
## - **Not `--headless`.** No swapchain means `root.get_texture()` comes back blank with no error, and
##   `capture_bodies.gd` measured it HANGING on a `frame_post_draw` the dummy renderer never emits. The
##   guard below refuses outright rather than writing the rule down.
## - **It never takes the user's mouse or keyboard.** Every gesture is an `InputEvent` built here and
##   handed to `game._unhandled_input` inside the engine. No Win32, no key injection, no OS capture. A
##   window does open and hold focus for the run, which is why nothing here ever waits for a person.
## - **`RenderingServer.frame_post_draw` before every read**, or `get_texture()` hands back the
##   PREVIOUS frame and a shot photographs the state before the change — silently.
##
## ⚠ **The shell's own `_process` is switched off and the sim is frozen.** `FieldView._process` is a
## different node's and keeps running, so the transform still composes and the picture is still the
## game's own `_draw()`. Left on, `battle.step` would walk the units between shots and a survey frame
## would photograph a fight instead of an opening.
##
## ⚠ **`_unhandled_input` is called directly rather than `root.push_input()`.** Not for the headless
## reason (this window is a real 1280x720, so the stretch transform is 1.0) but because it is the path
## `net_shell` drove for the camera pan and zoom gestures this file also stages — `boat-and-landing`
## stage 4's own drag suite switched to `root.push_input(ev, true)` (section 6's own correction), but
## nothing in THIS file drives a boat drag, so the simpler direct call is still the right one here.

## Where the frames land. Nothing is written into the repo.
var _dir := ""

## Set true by the known-answer shot's guard. See `_run`.
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_map: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		# Not a warning. Headless does not merely come back black here — it never emits
		# `frame_post_draw`, so the first shot waits forever.
		push_error("capture_map: --headless 로는 픽셀을 못 읽는다. 창을 띄워서 돌려라")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	# The sim freezes; the view does not. See the header.
	_game.set_process(false)
	await process_frame

	# --- 0. the title, exactly as `_ready` leaves it ----------------------------------------------
	# Its own known answer: three boxes down the middle, the top one and the bottom one bordered and
	# the middle one flat and grey. If 설정하기 is indistinguishable from the other two here, the round
	# has failed its own acceptance row and nothing further down matters.
	await _settle(24)
	await _shot("00_title")

	# --- 1. the map, after its reveal and its scene fade have finished -----------------------------
	# ⚠ **`_settle` is not optional here.** The map arrives out of the background over
	# `SCENE_FADE_SEC` and its nodes fade in floor by floor over another 0.42 s; shot two frames after
	# `_start_run()` this frame is a near-black rectangle, and it would read as "the map does not
	# draw". The game's own `_process` is off, but every view ages on its own clock.
	_game._start_run()
	await _settle(48)
	await _shot("01_map")

	# --- 2. the map ONCE THE ARMY HAS WALKED — the only frame with all four states on it -----------
	# ⚠ `01_map` cannot answer the question the map is judged on. A fresh run has landed nowhere, so
	# node 0 is the only thing on offer and there is no "you are here" at all — which is exactly how
	# a reader came away calling the one lit node "the current node". With `path` = [0, 1] the screen
	# carries all four at once: node 1 wrapped by the ring, 3 and 4 bordered and full size, 0 walked
	# and smaller, the rest small and grey. **A capture harness that cannot photograph the change is
	# not an instrument**, which is this folder's own README.
	#
	# The run is driven and `_enter_map_screen()` is called by hand rather than pressing two nodes,
	# because pressing one opens an ISLAND and the way back out is a whole fight.
	_game.run.enter_node(0)
	_game.run.finish_island(true)
	_game.run.enter_node(1)
	_game.run.finish_island(true)
	_game._enter_map_screen()
	await _settle(48)
	await _shot("01b_map_walked")

	# Back to a fresh run, or `_enter_node(0)` below would be refused: the map has moved on and node 0
	# is behind it.
	_game._start_run()
	await _settle(2)
	_game._enter_node(0)

	# --- the known-answer shot for the ISLAND ------------------------------------------------------
	# `README.md`: a capture harness is an instrument, so take one frame you already know the answer
	# to before trusting any of the others. Island 1 row 8 carries `####` at columns 13-16 and 31-34
	# and nothing else on that row. Zoomed to ZOOM_MAX with the camera parked at the map's top-left,
	# those two blocks must be the ONLY dark shapes in the upper band. If this frame is wrong, every
	# frame after it is unreadable and nothing below means anything.
	_game.field_view.zoom = Look.ZOOM_MAX
	_game.field_view.cam_px = Vector2.ZERO
	_game.field_view._clamp_cam()
	await _shot("02_known_answer_island1_topleft")

	# --- 3-5. the survey: each island as the player first sees it ---------------------------------
	# `setup()` is what puts an island at ZOOM_MIN with the camera home, so re-opening the island is
	# the honest way to reach the opening frame — writing `zoom = ZOOM_MIN` here would photograph a
	# state the game never produces.
	for i in 3:
		_game.run.island_index = i
		_game._open_island()
		await _shot("%02d_island%d_survey" % [i + 3, i + 1])

	# --- 6. island 2 at full zoom, on the ridge ---------------------------------------------------
	# The ridge is columns 22-23, the ramp is rows 12-13. At ZOOM_MAX the viewport shows 32 x 18
	# tiles, so parking the camera at tile (8, 4) puts the ramp near the middle of the frame.
	_game.run.island_index = 1
	_game._open_island()
	await process_frame
	_wheel_to_max(Vector2(640.0, 360.0))
	_game.field_view.cam_px = Vector2(8.0, 4.0) * Look.TILE_PX
	_game.field_view._clamp_cam()
	await _shot("06_island2_ramp_zoom_max")

	# --- 7-8. the clamp, both corners -------------------------------------------------------------
	# Driven as a real gesture, not by writing `cam_px`: the question is whether the player can shove
	# the map off its own edge, and that is `pan_by`'s clamp reached through `_unhandled_input`.
	_drag(Vector2(640.0, 360.0), Vector2(400.0, 400.0), 12)
	await _shot("07_clamp_top_left")
	_drag(Vector2(640.0, 360.0), Vector2(-400.0, -400.0), 24)
	await _shot("08_clamp_bottom_right")

	print("capture_map: 열 장, %s" % _dir)
	quit()


## Turns `n` real frames without writing anything. **The views age on their own clocks even with the
## shell's `_process` switched off**, so this is what lets a beat FINISH before it is photographed —
## a fade caught halfway reads as a screen that does not draw.
func _settle(n: int) -> void:
	for _i in n:
		await process_frame


## One frame to disk. The `frame_post_draw` await is the whole of why this is a function.
func _shot(name: String) -> void:
	# Two process frames, not one: `FieldView._process` composes the transform and asks for a redraw,
	# and the redraw lands on the frame after the ask.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_map: %s 를 못 썼다" % path)


## Wheel notches until the zoom stops moving, through the shell's own handler.
func _wheel_to_max(at: Vector2) -> void:
	for _n in 12:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		e.position = at
		_game._unhandled_input(e)


## A left-drag: press, `steps` motions of `step_rel`, release. Exactly the three events a mouse sends.
func _drag(from: Vector2, step_rel: Vector2, steps: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	_game._unhandled_input(press)
	for _n in steps:
		var motion := InputEventMouseMotion.new()
		motion.relative = step_rel
		_game._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = from
	_game._unhandled_input(release)
