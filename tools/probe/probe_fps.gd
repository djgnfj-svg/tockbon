# Real frames per second, with the engine driving its own loop.
#
# **Not a net** — it reports. The frame-cost probe beside it measures SCRIPT time and came out under
# 0.2 ms, which does not explain 「이게 왜 렉이 걸리지」 (2026-08-24). What that probe cannot see is the
# GPU: this project runs on the **Compatibility** renderer, with a shadow-casting sun over
# `SUN_SHADOW_DIST_TILES` and one alpha-tested shadow-casting billboard per body.
#
# Run (a window has to open — a headless run does not render):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/probe/probe_fps.gd
extends SceneTree

var _game: Game = null
var _step := 0
var _wait := 0
var _frames := 0
var _t0 := 0
var _worst := 0.0
var _last := 0


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
	match _step:
		0, 1, 2, 3, 4:
			_wait += 1
			if _wait < 4:
				return false
			_wait = 0
			match _step:
				0:
					_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
				1:
					# The opening beast card: the map used to be pressed here, and a card takes
					# its place — the island opens the moment it is taken.
					_game._unhandled_input(_click(Look.card_rect_px(0).get_center()))
				2:
					pass
				3:
					for slot in 2:
						_game._unhandled_input(_key(KEY_1 + slot))
						for _k in 4:
							_game._unhandled_input(_click(_summon_px(2)))
					_game._unhandled_input(_click(Look.start_rect_px().get_center()))
				4:
					_t0 = Time.get_ticks_usec()
					_last = _t0
			_step += 1
			return false
		5:
			# **The engine's own loop from here.** Nothing is stepped by hand; the sim runs off the
			# field's real `_process` exactly as it does when a person is playing.
			_frames += 1
			var now := Time.get_ticks_usec()
			var ms := float(now - _last) / 1000.0
			if _frames > 10:
				_worst = maxf(_worst, ms)
			_last = now
			if _frames < 400:
				return false
			var total := float(now - _t0) / 1000000.0
			print("[fps] %.1f fps over %d frames (%.2f s) · worst frame %.1f ms · 몸 %d · 적 %d" % [
				float(_frames) / total, _frames, total, _worst,
				_game.battle.ashore_ids().size(), _game.battle.enemies_left()])
			_step += 1
			return false
		_:
			return true
