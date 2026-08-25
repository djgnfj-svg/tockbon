# How long a frame of the field's own drawing takes, in milliseconds.
#
# **Not a net** — it reports, it does not assert. It exists because the first person to play the 3D
# field said 「이게 왜 렉이 걸리지」, and 「it feels fine now」 is not a measurement.
#
# Run:
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/probe/probe_frame_cost.gd
extends SceneTree

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


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	return ev


func _summon_px(n: int) -> Vector2:
	var fv := _game.field_view
	var g := _game.battle.grid
	var seen := 0
	for t in g.w * g.h:
		if not g.can_summon_at(t):
			continue
		if seen < n:
			seen += 1
			continue
		# The VIEW's own forward, and not a copy of it. Three probes and three shooters each carried a
		# private one; all six were the flat board's, all six ignored the yaw, and every click they
		# aimed landed on a tile next to the one it meant (2026-08-25).
		var tx := t % g.w
		var ty := t / g.w
		return fv.tile_to_screen_px(tx, ty)
	return Vector2.ZERO


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 4:
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
			for slot in 2:
				_game._unhandled_input(_key(KEY_1 + slot))
				for _k in 4:
					_game._unhandled_input(_click(_summon_px(2)))
			_game._unhandled_input(_click(Look.start_rect_px().get_center()))
		4:
			# Walk into the fight so the effect layer has real work: bodies ashore, intent lines up.
			for _i in 150:
				_game._process(1.0 / 60.0)
				_game.field_view._process(1.0 / 60.0)
		5:
			var fv := _game.field_view
			var n := 300
			var t0 := Time.get_ticks_usec()
			for _i in n:
				_game._process(1.0 / 60.0)
				fv._process(1.0 / 60.0)
			var t1 := Time.get_ticks_usec()
			print("[cost] sim+view %.3f ms/frame over %d frames" % [float(t1 - t0) / float(n) / 1000.0, n])
			var t2 := Time.get_ticks_usec()
			for _i in n:
				fv._process(0.0)
			var t3 := Time.get_ticks_usec()
			print("[cost] view alone %.3f ms/frame  (ground verts %d, air verts %d, bodies ashore %d)" % [
				float(t3 - t2) / float(n) / 1000.0, fv._g_v.size(), fv._a_v.size(),
				_game.battle.ashore_ids().size()])
			# ⚠ **The same frame with the height caches thrown away every time** — this is what the
			# field was doing before 2026-08-24, and the gap between the two numbers is the lag.
			var t4 := Time.get_ticks_usec()
			for _i in n:
				fv._tile_h_cache.clear()
				fv._ground_h_cache.clear()
				fv._process(0.0)
			var t5 := Time.get_ticks_usec()
			print("[cost] view with the height cache thrown away every frame %.3f ms/frame" %
				[float(t5 - t4) / float(n) / 1000.0])
		_:
			return true
	_step += 1
	return false
