extends SceneTree
## The game screenshots its own LANDING PHASE. Written 2026-08-19 for `speed-off-open-landing`'s
## Screen rows S1-S5, which `capture_map.gd` cannot answer: that file photographs the title, the node
## map and three island openings, and **nothing in it ever drags a soldier, refuses a drop, or
## watches a boat cross**.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_landing.gd -- <dir>
## ```
##
## The three rules in this folder's README bind unchanged and are re-stated where they bite:
##
## - **Not `--headless`.** No swapchain means `root.get_texture()` comes back blank with no error, and
##   the dummy renderer never emits `frame_post_draw` at all, so the first shot hangs. Guarded below.
## - **It never takes the user's mouse or keyboard.** Every gesture is an `InputEvent` built here and
##   handed to `game._unhandled_input` inside the engine.
## - **`RenderingServer.frame_post_draw` before every read**, or the shot photographs the PREVIOUS
##   frame — silently, and it reads exactly like a change that never landed.
##
## ⚠ **The shell's `_process` is off for every still and ON for the two crossings.** A still of an
## opening must not have a fight walking through it; a crossing that is not stepped is not a crossing.
##
## ⚠ **The two S4 landings are named as tiles and the reason is printed with them**, because they
## answer opposite halves of that row. `(2, 3)` is the far north-west shore — the straight line to it
## crosses the whole island, so the deleted rule refused it, and the route has to wrap the west end.
## `(24, 17)` is the head of island 1's own bay, straight up an open water column from the start
## harbour — and the route to it is NOT straight. See `_TILE_BAY_HEAD` below.

## Island 1's far north-west shore. Straight line from the start harbour (24, 31) crosses the island;
## the water route wraps the west end along row 21 and up column 0. 45.80 tiles against 35.61.
const _TILE_NW := Vector2i(2, 3)

## Island 1's bay head. The start harbour sits at the mouth of that bay and the water column between
## them is open — and the hop-count BFS still routes seven tiles out to the west and seven back.
const _TILE_BAY_HEAD := Vector2i(24, 17)

## Island 2's cliff ridge, which is the one place a seaward cliff FACE runs down the middle of open
## water rather than along the top border.
const _TILE_RIDGE := Vector2i(21, 12)

var _dir := ""
var _game: Game = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_landing: 출력 폴더를 인자로 달라")
		quit(1)
		return
	_dir = args[0]
	if DisplayServer.get_name() == "headless":
		push_error("capture_landing: --headless 로는 픽셀을 못 읽는다. 창을 띄워서 돌려라")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	_game = Game.new()
	root.add_child(_game)
	_game.set_process(false)
	await process_frame

	_game._start_run()
	await _settle(6)
	_game._enter_node(0)
	await _settle(4)

	# --- 0. the known answer ----------------------------------------------------------------------
	# `capture_map.gd`'s own: island 1 row 8 carries `####` at columns 13-16 and 31-34 and nothing
	# else on those rows. At ZOOM_MAX with the camera at the map origin they must be the only dark
	# blocks in the upper band, at x 520-680 and x 1240-1280. If this frame is wrong, every frame
	# after it is unreadable — and the failure looks exactly like a camera that had no effect.
	_game.field_view.zoom = Look.ZOOM_MAX
	_game.field_view.cam_px = Vector2.ZERO
	_game.field_view._clamp_cam()
	await _shot("00_known_answer_island1_topleft")

	# --- 1-3. the three islands as they open (S1 · S2 · S3) ---------------------------------------
	for i in 3:
		_game.run.island_index = i
		_game._open_island()
		await _settle(4)
		await _shot("%02d_island%d_open" % [i + 1, i + 1])
		await _crop("%02d_island%d_bottomright" % [i + 1, i + 1], Rect2i(700, 380, 580, 340))

	# --- 4. the cliff faces at full zoom (S3) -----------------------------------------------------
	# Island 2's ridge, because it is the one seaward cliff that is not the map's top border.
	_game.run.island_index = 1
	_game._open_island()
	await _settle(4)
	_stage_camera_on(_TILE_RIDGE, Look.ZOOM_MAX)
	await _shot("04_island2_ridge_zoom_max")
	# And island 1's northern cliff row at mid-map, which is the ONLY 「못 내림」 mark that island has.
	_game.run.island_index = 0
	_game._open_island()
	await _settle(4)
	_stage_camera_on(Vector2i(24, 3), Look.ZOOM_MAX)
	await _shot("05_island1_north_cliff_zoom_max")

	# --- 6. a refused drop (S5) -------------------------------------------------------------------
	_game._open_island()
	await _settle(4)
	var inland := _an_inland_tile()
	print("capture_landing: 내륙 %s, home_harbour=%d" % [
		str(_game.battle.grid.tile_point(inland)),
		_game.battle.grid.home_harbour_for(inland)])
	await _drag_soldier_to(0, inland)
	# NO settle: the question is whether the mark is on the frame of the release. `_shot` turns two
	# frames of its own, which is already the honest worst case.
	await _shot("06_refused_drop")
	await _crop("06b_refused_drop_cursor", _crop_box_around(inland, 240))
	await _settle(40)
	await _shot("06c_refused_drop_after_1s")

	# --- 6d. the route WHILE the drag is still in flight, at two zooms -----------------------------
	# A different call site from the crossing below (`field_view` block 2b builds `plan_px` from
	# `grid.water_route` itself) drawn over the same water, and then the same frame at ZOOM_MAX over
	# the harbour end. ⚠ **`ROUTE_WIDTH_PX` WAS 3.0 world px = 1.35 px on the glass at ZOOM_MIN, under
	# `look.gd`'s own 2.0 px snap floor, and this capture is what found it.** It is 5.0 (2.25 px) now,
	# and `look.gd` grew a whole world-width table off the finding. The zoom SWEEP stays regardless:
	# the two zooms are the instrument for whether the whole line reaches the canvas, and that question
	# outlives whichever value the constant currently holds.
	_game._open_island()
	await _settle(4)
	var nw := _game.battle.grid.tile_index(_TILE_NW.x, _TILE_NW.y)
	await _press_and_drag_to(0, nw)
	await _settle(2)
	await _shot("06d_drag_in_flight_zoom_min")
	# A sweep, because the question is not 「is it ever drawn」 but 「at which zoom does it stop being
	# drawn」 — and ZOOM_MIN is the one the game itself opens every island at.
	for z in [0.45, 0.55, 0.675, 0.9, 1.35, Look.ZOOM_MAX]:
		_stage_camera_on(Vector2i(4, 27), float(z))
		await _shot("06e_drag_harbour_zoom_%03d" % int(float(z) * 100.0))
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-100.0, -100.0)
	_game._unhandled_input(up)

	# --- 7. S4-A: the far north-west shore, which the straight-line rule refused -------------------
	await _crossing(_TILE_NW, "07_nw")
	# --- 8. S4-B: the bay head, straight up an open water column ----------------------------------
	await _crossing(_TILE_BAY_HEAD, "08_bay")

	print("capture_landing: 끝, %s" % _dir)
	quit()


## One whole S4 case: re-open island 1, drag one soldier onto `tile`, shoot the planned route, press
## 시작, and shoot six frames of the crossing with a crop of the hull on each.
func _crossing(tile: Vector2i, tag: String) -> void:
	_game.run.island_index = 0
	_game._open_island()
	await _settle(4)
	var g := _game.battle.grid
	var t := g.tile_index(tile.x, tile.y)
	var route := g.water_route(g.start_harbour, t)
	var length := 0.0
	for k in range(1, route.size()):
		length += route[k].distance_to(route[k - 1])
	print("capture_landing: %s 착륙 %s  경유 %d  항로 %.2f  직선 %.2f" % [
		tag, str(tile), route.size(), length,
		g.tile_point(g.harbour_tiles[g.start_harbour]).distance_to(g.tile_point(t))])
	await _drag_soldier_to(0, t)
	await _settle(2)
	# What the SIM built, printed beside what the picture shows: the drawn line is `_route_ahead`,
	# which is `pos` followed by every waypoint past `leg`, so these three numbers are the whole of
	# what a frame can be argued with.
	if not _game.battle.boats.is_empty():
		var boat: Dictionary = _game.battle.boats[0]
		var path: PackedVector2Array = boat["path"]
		print("  boat pos=%s leg=%s home=%s dist=%.2f path[%d]=%s" % [
			str(boat["pos"]), str(boat["leg"]), str(boat["home"]), float(boat["dist"]),
			path.size(), str(path)])
		var scr := PackedStringArray()
		for wp in _route_ahead_px(boat):
			scr.append("(%d,%d)" % [int(wp.x), int(wp.y)])
		print("  drawn screen: %s" % ", ".join(scr))
	await _shot("%s_0_planned_route" % tag)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Look.start_rect_px().get_center()
	_game._unhandled_input(press)

	# The shell drives itself from here — this is the game running, not a staged frame.
	# Twelve shots at twenty frames, because six at twelve covered only the first quarter of a 4.95 s
	# crossing — and on the bay route the whole question is whether the boat comes BACK.
	_game.set_process(true)
	for k in 12:
		await _settle(20)
		await _shot("%s_%d_crossing" % [tag, k + 1])
		if not _game.battle.boats.is_empty():
			var boat: Dictionary = _game.battle.boats[0]
			await _crop("%s_%db_hull" % [tag, k + 1],
					_crop_box_at(Look.tile_point_px(Vector2(boat["pos"])), 360))
	_game.set_process(false)


# --- staging helpers ------------------------------------------------------------------------------

## A passable tile with no harbour that can reach it, nearest the island's centre — the middle of the
## island, which is what S5's row asks a player to drag onto.
func _an_inland_tile() -> int:
	var g := _game.battle.grid
	var centre := Vector2(g.w, g.h) * 0.5
	var best := -1
	var best_d := 1e9
	for t in g.passable.size():
		if g.passable[t] == 0:
			continue
		if g.home_harbour_for(t) >= 0:
			continue
		var d := g.tile_point(t).distance_to(centre)
		if d < best_d:
			best_d = d
			best = t
	return best


func _stage_camera_on(tile: Vector2i, zoom: float) -> void:
	var world := Look.tile_point_px(Vector2(tile))
	_game.field_view.zoom = zoom
	_game.field_view.cam_px = world - Vector2(640.0, 360.0) / zoom
	_game.field_view._clamp_cam()


## What `field_view._route_ahead` will hand `draw_polyline`, in SCREEN px — the same walk, so a
## printed list and a photographed line can be laid side by side. It is deliberately a copy and not a
## call: reaching into the view's private helper would make this file agree with it by construction,
## which is the one thing an instrument must not do.
func _route_ahead_px(boat: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(_to_screen(Look.tile_point_px(Vector2(boat["pos"]))))
	var path: PackedVector2Array = boat["path"]
	for k in range(int(boat["leg"]) + 1, path.size()):
		out.append(_to_screen(Look.tile_point_px(path[k])))
	return out


## Screen px for a world px, through the node's own composition. Never a second transform.
func _to_screen(world: Vector2) -> Vector2:
	return world * _game.field_view.zoom + _game.field_view.position


func _crop_box_at(world: Vector2, size: int) -> Rect2i:
	var s := _to_screen(world)
	var half := size / 2
	var x: int = clampi(int(s.x) - half, 0, 1280 - size)
	var y: int = clampi(int(s.y) - half, 0, 720 - size)
	return Rect2i(x, y, size, size)


func _crop_box_around(tile: int, size: int) -> Rect2i:
	return _crop_box_at(Look.tile_point_px(_game.battle.grid.tile_point(tile)), size)


## Press on soldier `i` where it stands at the harbour, walk the cursor, release over `tile`. Exactly
## the three events a mouse sends, through the shell's own handler.
func _drag_soldier_to(i: int, tile: int) -> void:
	var from := _to_screen(_game.field_view.idle_soldier_rect(i).get_center())
	var to := _to_screen(Look.tile_point_px(_game.battle.grid.tile_point(tile)))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	_game._unhandled_input(press)
	for k in 8:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(k + 1) / 8.0)
		motion.relative = (to - from) / 8.0
		_game._unhandled_input(motion)
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	_game._unhandled_input(release)


## The same gesture as `_drag_soldier_to` with the button still DOWN at the end, so the frame can be
## photographed with the drag in flight — which is the only way to reach `field_view`'s block 2b.
func _press_and_drag_to(i: int, tile: int) -> void:
	var from := _to_screen(_game.field_view.idle_soldier_rect(i).get_center())
	var to := _to_screen(Look.tile_point_px(_game.battle.grid.tile_point(tile)))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	_game._unhandled_input(press)
	for k in 8:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(k + 1) / 8.0)
		motion.relative = (to - from) / 8.0
		_game._unhandled_input(motion)
		await process_frame


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
		push_error("capture_landing: %s 를 못 썼다" % path)


func _crop(name: String, box: Rect2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.get_region(box).save_png(path) != OK:
		push_error("capture_landing: %s 를 못 썼다" % path)
