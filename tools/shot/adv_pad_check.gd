# ADVERSARY SHOOTER — photographs the 판 twice at TWO camera distances and the 이동선's terminator
# against the 칸 it is aimed at, so a second pair of eyes can read the same numbers off pixels.
# **Not a net**: it asserts nothing, it takes the pictures the numbers are read off.
#
# ⚠ The reveal pair is taken with the tree PAUSED, so the only thing differing between the two PNGs
# is the 판. The route pair cannot be — every ground mark is built inside `field_view._process`'s fx
# pass and a paused tree draws no line at all.
#
# Run (a window has to open — a headless run has no swapchain to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/adv_pad_check.gd
extends SceneTree

const SHOT := "res://tools/shot/out/pads/adv/%s.png"

var _game: Game = null
var _step := 0
var _wait := 0
var _aim := Vector2.ZERO
var _from := Vector2.ZERO
var _aim_block := -1


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tools/shot/out/pads/adv"))


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _lift(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _move(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % shot_name))
	print("[shot] %s  zoom=%.4f yaw=%.2f" % [shot_name, _game.field_view.zoom,
		_game.field_view.cam_yaw_deg])


# Prints the screen rect of one 칸, corner by corner, so the geometric answer stands beside the
# photographed one.
func _print_block_rect(tag: String, blk: int) -> void:
	var grid := _game.battle.grid
	var mates := grid.tiles_of_block(blk)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for k in mates.size():
		var t := int(mates[k])
		var p := _game.field_view.tile_to_screen_px(t % grid.w, t / grid.w)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	print("[geom] %s 칸 %d tile-centres span x %.1f..%.1f y %.1f..%.1f middle %.1f, %.1f"
		% [tag, blk, lo.x, hi.x, lo.y, hi.y, (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5])


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			for _i in 300:
				_game._process(1.0 / 60.0)
			print("[open] zoom=%.4f  grid %dx%d" % [_game.field_view.zoom,
				_game.battle.grid.w, _game.battle.grid.h])
		2:
			paused = true
		3:
			_save("open_off")
		4:
			_game.field_view.set_pads_revealed(true)
		5:
			_save("open_on")
		6:
			# --- HOVER at the opening zoom, board revealed, nobody picked -------------------------
			# The hovered 판 is the ONLY thing that changes against `open_on`, so the difference is
			# the hover square with no route and no body on top of it.
			var grid := _game.battle.grid
			var best := -1
			var best_at := Vector2.ZERO
			for by in range(0, grid.h, 2):
				for bx in range(0, grid.w, 2):
					var t := grid.tile_index(bx, by)
					if not grid.is_passable(bx, by):
						continue
					var p := _game.field_view.tile_to_screen_px(bx, by)
					if p.x < 300.0 or p.x > Look.VIEWPORT_W_PX - 300.0:
						continue
					if p.y < 250.0 or p.y > Look.VIEWPORT_H_PX - 250.0:
						continue
					best = grid.block_of(t)
					best_at = p
			_aim_block = best
			_aim = best_at
			print("[hover] cursor %.1f, %.1f -> 조각 %d 칸 %d"
				% [_aim.x, _aim.y, _game._tile_at(_aim), _aim_block])
			_print_block_rect("open", _aim_block)
			_game._unhandled_input(_move(_aim))
			print("[hover] field_view hover uniform now %d" % _game.field_view._hover_cell)
		7:
			_save("open_hover")
		8:
			_game.field_view.set_pads_revealed(false)
			paused = false
		9:
			# --- FULLY ZOOMED IN ------------------------------------------------------------------
			for _i in 20:
				_game._unhandled_input(_wheel_up())
			print("[zoom] now %.4f (ZOOM_MAX %.2f)" % [_game.field_view.zoom, Look.ZOOM_MAX])
		10:
			paused = true
		11:
			_save("max_off")
		12:
			_game.field_view.set_pads_revealed(true)
		13:
			_save("max_on")
		14:
			# ⚠ **The turn has to happen UNPAUSED** — `turn_by` writes `cam_yaw_deg` and only
			# `_place_camera`, inside `_process`, reaches the engine with it.
			_game.field_view.set_pads_revealed(false)
			paused = false
			_game.field_view.turn_by(45.0)
		15:
			paused = true
		16:
			_save("max45_off")
		17:
			_game.field_view.set_pads_revealed(true)
		18:
			_save("max45_on")
		19:
			_game.field_view.set_pads_revealed(false)
			paused = false
			_game.field_view.turn_by(-45.0)
		20:
			# back out to the opening distance for the route pair
			for _i in 20:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
				ev.pressed = true
				ev.position = Look.viewport_size_px() * 0.5
				_game._unhandled_input(ev)
		21:
			for _i in 4:
				_game._unhandled_input(_wheel_up())
			print("[zoom] route pair at %.4f" % _game.field_view.zoom)
		22:
			# --- ROUTE --------------------------------------------------------------------------
			var b := _game.battle
			var who := -1
			for k in b.soldier_state.size():
				if int(b.soldier_state[k]) == Battle.SoldierState.ASHORE:
					who = k
					break
			var here: Vector2 = b.soldier_pos[who]
			_from = _game.field_view.tile_to_screen_px(int(here.x), int(here.y))
			print("[aim] body %d at 조각 (%d, %d), screen %.1f, %.1f"
				% [who, int(here.x), int(here.y), _from.x, _from.y])
			_game._unhandled_input(_click(_from))
			_game._unhandled_input(_lift(_from))
		23:
			var grid2 := _game.battle.grid
			var want := -1
			for k in _game.hand.reach_blocks.size():
				var bk := int(_game.hand.reach_blocks[k])
				var mates := grid2.tiles_of_block(bk)
				if mates.size() < 4:
					continue
				var at := _game.field_view.tile_to_screen_px(
					int(mates[0]) % grid2.w, int(mates[0]) / grid2.w)
				if at.x < 260.0 or at.x > Look.VIEWPORT_W_PX - 260.0:
					continue
				if at.y < 200.0 or at.y > Look.VIEWPORT_H_PX - 200.0:
					continue
				var span := (at - _from).length()
				if span < 200.0 or span > 420.0:
					continue
				want = bk
				_aim = at
				break
			_aim_block = want
			print("[aim] picked %d | 칸 %d | cursor %.1f, %.1f"
				% [_game.hand.ids.size(), want, _aim.x, _aim.y])
			_print_block_rect("route", want)
			_game._unhandled_input(_move(_aim))
		24:
			_save("route_on")
		25:
			# ⚠ **The pointer goes out to sea AND the hover is written straight back.** `_show_route`
			# runs every frame off `_pointer_at`, so the only way to have the hovered 칸 lit with NO
			# 이동선 on it is to kill the pointer and restore the hover by hand. The difference
			# between this frame and `route_on` is the line and its terminator ALONE.
			_game._unhandled_input(_move(Vector2(4.0, Look.VIEWPORT_H_PX - 4.0)))
			_game.field_view.set_hover_tile(int(_game.battle.grid.tiles_of_block(_aim_block)[0]))
		26:
			_save("route_hover_only")
		27:
			_game.field_view.set_hover_tile(-1)
		28:
			_save("route_off")
		29:
			var seats := _game.hand.routes(_game.battle, _aim_block)
			var pts := _game.hand.route_points(_game.battle, _aim_block)
			for k in pts.size():
				var line: PackedVector2Array = pts[k]
				var last: Vector2 = line[line.size() - 1]
				var st: Vector2 = _game.field_view.tile_to_screen_px(int(last.x), int(last.y))
				print("[seat] body %d ends on 조각 (%d, %d) screen %.1f, %.1f"
					% [k, int(last.x), int(last.y), st.x, st.y])
			print("[seat] routes returned %d" % seats.size())
		_:
			return true
	_step += 1
	return false
