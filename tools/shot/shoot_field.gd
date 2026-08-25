# Drives the real shell to an island and saves screenshots. **Not a net** — it asserts nothing; it is
# how a human sees the field without playing to it. Nets live in `tests/nets/` and this is why they
# stay there: nothing here can go red.
#
# ⚠⚠ **THIS SHOOTER IS STALE AND ITS PICTURES ARE NOT OF WHAT THEY SAY** (found 2026-08-25).
# 티켓 15 put a BEAST CARD ROUND between the title and the map, and step 1 below still clicks a map
# node straight after the title — so the click lands on the card screen, no island ever opens, and
# `_summonable_screen_px` barks `grid on a base object of type 'Nil'` while every `_save` after it
# writes a frame of the wrong screen. **Nothing here can go red, so it wrote eight wrong PNGs without
# failing.** ⇒ Take a card (`Look.card_hit_rect_px(0)`) between steps 0 and 1, then re-shoot the set;
# `tools/shot/shoot_loop.gd` and `shoot_species.gd` already do this and both still run.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_field.gd
extends SceneTree

const SHOT := "res://tools/shot/field_%s.png"

var _game: Game = null
var _step := 0
var _wait := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _release(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % name))
	print("[shot] %s" % name)


## A water tile the sim will actually accept a boat on, found through the same predicate `Battle.summon`
## refuses on rather than by eye.
func _summonable_screen_px() -> Vector2:
	var g := _game.battle.grid
	for t in g.w * g.h:
		if g.can_summon_at(t):
			# ⚠ **The VIEW's own forward** (`tile_to_screen_px`), and no longer a copy of it kept here.
			# The copy was the flat board's, it ignored the yaw, and it aimed every click in this file
			# at a tile next to the one it meant (2026-08-25).
			return _game.field_view.tile_to_screen_px(t % g.w, t / g.w)
	return Vector2.ZERO


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			_game._unhandled_input(_click(Look.map_node_pos_px(0)))
		2:
			_game._process(Look.MAP_TRAVEL_SEC)
		3:
			_save("1_planning")
		4:
			_game._unhandled_input(_key(KEY_1))
			var at := _summonable_screen_px()
			_game._unhandled_input(_click(at))
			_game._unhandled_input(_release(at))
		5:
			_save("2_one_boat_planned")
		6:
			_game._unhandled_input(_click(Look.start_rect_px().get_center()))
		7:
			for _i in 90:
				_game._process(1.0 / 60.0)
		8:
			_save("3_crossing")
		9:
			for _i in 400:
				_game._process(1.0 / 60.0)
		10:
			_save("4_fighting")
		11:
			for _i in 3:
				_game._unhandled_input(_key(KEY_E))
		12:
			_save("5_turned_45")
		13:
			for _i in 3:
				_game._unhandled_input(_key(KEY_E))
		14:
			_save("6_turned_90")
		15:
			for _i in 2:
				_game._unhandled_input(_key(KEY_E))
			for _i in 6:
				_game._unhandled_input(_wheel_up())
		16:
			_save("7_turned_close")
		17:
			# ⚠ **Island 0 has no ramp in it at all** — the four `/` tiles in the shipped set are on
			# islands 1 and 2 — so the one legend character whose whole job is to be a slope cannot be
			# seen on the island the shell opens first. The field is pointed at island 2 directly here,
			# through the same `setup` the shell uses, purely so a human can look at it.
			var grid := Grid.new()
			Islands.load_into(grid, 2)
			var b := Battle.new()
			b.setup(grid, _game.run.army, Islands.spawns_of(2), Islands.time_limit_of(2))
			_game.field_view.setup(b, _game.run.army, Islands.rows_of(2))
			for _i in 6:
				_game.field_view.turn_by(Look.CAM_YAW_STEP_DEG)
			for _i in 2:
				_game.field_view.zoom_at(Look.viewport_size_px() * 0.5, Look.ZOOM_STEP)
		18:
			_save("8_island2_ramps")
		_:
			return true
	_step += 1
	return false

func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev
