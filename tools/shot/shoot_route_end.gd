# Photographs the 이동선's terminator against the 칸 it is aimed at, so 「the dot is in the middle」
# can be read off pixels instead of off an impression. **Not a net**: it asserts nothing.
#
# It picks one body, hovers a 칸 four 조각 away, and saves the board with the route on it — then it
# moves the pointer out to sea, which clears the route and the hover, and saves the same board again.
# **The pair is what the measurement is made from**: the marks and the line are what BRIGHTENS between
# the two, so a difference image separates them from the sand without any colour matching.
#
# ⚠ **The board is NOT paused for this pair.** Every ground mark is built inside the fx pass in
# `field_view._process`, so a paused tree draws no line at all — the thing being photographed only
# exists while the game is running. The two bodies drift a frame's worth between the shots; the 칸
# aimed at is chosen away from them for that reason.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_route_end.gd
extends SceneTree

const SHOT := "res://tools/shot/out/pads/route_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0
var _aim := Vector2.ZERO
var _from := Vector2.ZERO


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tools/shot/out/pads"))


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


# ⚠⚠ **A PICK IS A PRESS AND A RELEASE.** `Game._end_press` is what commands — a press alone opens the
# gesture and decides nothing, so a shooter that sends only the down edge picks nobody and photographs
# an empty hand.
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
	print("[shot] %s" % shot_name)


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
		2:
			for _i in 8:
				_game._unhandled_input(_wheel_up())
		3:
			# The first body standing on the island, pressed where it is drawn.
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
		4:
			# ⚠ **The 칸 is chosen out of `Hand.reach_blocks` and not by arithmetic on the body's own
			# 조각.** A 칸 that is merely nearby can be unreachable or off the glass, and the shot
			# would then be of a board with no line on it — which reads exactly like a broken fix.
			var grid := _game.battle.grid
			var want := -1
			for k in _game.hand.reach_blocks.size():
				var bk := int(_game.hand.reach_blocks[k])
				var mates := grid.tiles_of_block(bk)
				if mates.size() < 4:
					continue
				var at := _game.field_view.tile_to_screen_px(
					int(mates[0]) % grid.w, int(mates[0]) / grid.w)
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
			print("[aim] picked %d | 칸 %d | cursor %.1f, %.1f"
				% [_game.hand.ids.size(), want, _aim.x, _aim.y])
			_game._unhandled_input(_move(_aim))
		5:
			_save("on")
		6:
			# Out to sea: off the reach, so the route and the hover both go dark and the ground under
			# them is what the difference is measured against.
			_game._unhandled_input(_move(Vector2(4.0, Look.VIEWPORT_H_PX - 4.0)))
		7:
			_save("off")
		_:
			return true
	_step += 1
	return false
