# Drives the real shell through the pick gesture and saves screenshots. **Not a net** — it asserts
# nothing; it is how a human sees 「press a body -> the reach lights -> hover -> the 이동선 -> press ->
# he walks」 without playing to it. Nets live in `tests/nets/` and this is why they stay there:
# nothing here can go red.
#
# ⚠ **Nothing here can go red, so a stale step writes a wrong PNG without failing** — the failure
# `shoot_field.gd` records from 2026-08-25. **If a shot does not show what its name says, the step
# order is wrong — fix the order, not the name.**
#
# The gesture this walks (2026-08-31, the user: 「tab 없이 그냥 캐릭터를 누르면 이동할 수 있는 칸들이
# 뜨고 눌러서 이동하는거임」, 「이동할때 이동선이 미리 보였으면 좋겠네」).
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_pick.gd
extends SceneTree

const SHOT := "res://tools/shot/out/pick/pick_%s.png"

## How far from the picked body the destination is aimed, in 조각. ⚠ **Far enough that the 이동선 has
## bends in it** — a route one 조각 long is a dot and proves nothing about the line following ground.
const AIM_TILES := 6.0

var _game: Game = null
var _step := 0
var _wait := 0
var _who := -1
var _dest_at := Vector2.ZERO

## ⚠⚠ **A SEPARATE FLAG AND NOT `_dest_at.x >= 0`, BECAUSE A SCREEN X IS LEGITIMATELY NEGATIVE.** The
## first working version of this file used the sign as its 「found one」 sentinel; the aim landed at
## x = -20 (a 조각 just off the left edge), the sentinel read it as 「not found」, and the hover was
## never sent at all — the tool photographed an island with no 이동선 on it and nothing went red.
var _has_dest := false


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://tools/shot/out/pick"))
	_game = Game.new()
	root.add_child(_game)


func _press(at: Vector2) -> InputEventMouseButton:
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


func _motion(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.relative = Vector2.ZERO
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _wheel_down() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _turn_key() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_E
	return ev


func _save(shot_name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % shot_name))
	print("[shot] %s" % shot_name)


## Where the first body ashore is standing, in screen px. -1 in `_who` means nobody has landed yet.
func _body_at_screen() -> Vector2:
	var b: Battle = _game.battle
	var ashore := b.ashore_ids()
	if ashore.is_empty():
		return Vector2(-1.0, -1.0)
	_who = int(ashore[0])
	var p: Vector2 = b.soldier_pos[_who]
	return _game.field_view.tile_to_screen_px(int(p.x), int(p.y))


## **The 조각 to send him to, taken from the reach itself.** ⚠ Never a literal — the island's shape
## has moved twice, and a typed 조각 would be a picture of a board this file does not own.
##
## ⚠⚠ **IT HAS TO BE ON SCREEN.** A hover is a cursor position, and a cursor cannot be outside the
## window — aiming at a 조각 the camera is not looking at produces a shot of nothing at all.
func _aim_from_reach() -> Vector2:
	var b: Battle = _game.battle
	var hand: Hand = _game.hand
	var p: Vector2 = b.soldier_pos[_who]
	var view := Look.viewport_size_px()
	var best := Vector2.ZERO
	var best_gap := INF
	_has_dest = false
	for k in hand.reach.size():
		var t := int(hand.reach[k])
		var q := Vector2(float(t % b.grid.w) + 0.5, float(t / b.grid.w) + 0.5)
		var at := _game.field_view.tile_to_screen_px(t % b.grid.w, t / b.grid.w)
		if at.x < 0.0 or at.y < 0.0 or at.x >= view.x or at.y >= view.y:
			continue
		# ⚠ **The round trip is the self-check**: a screen point that resolves back to a different
		# 조각 would hover somewhere else and the shot would quietly show the wrong route.
		if _game._tile_at(at) != t:
			continue
		var gap: float = absf(q.distance_to(p) - AIM_TILES)
		if gap < best_gap:
			best_gap = gap
			best = at
			_has_dest = true
	return best


func _process(_delta: float) -> bool:
	# ⚠⚠ **THE HOVER IS RE-AIMED EVERY FRAME AND THAT IS NOT BELT-AND-BRACES.** The window is real and
	# so is the operating system's cursor: a live `InputEventMouseMotion` arrives from wherever the
	# hand actually left the pointer, and it overwrites the aim this file set one step earlier. The
	# first run of this tool photographed an empty island for exactly that reason — the 이동선 was
	# built, handed to the view, and cleared again by a stray motion before the frame was read back.
	# ⚠ **Held for every step that photographs the line, not just the first.** The camera moves under
	# a still cursor when the board turns or zooms, so the aim has to be re-sent AND re-derived — the
	# same screen point is a different 조각 after a turn.
	if _has_dest and _step >= 7 and _step <= 11:
		_game._unhandled_input(_motion(_dest_at))
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_game._unhandled_input(_press(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# The beasts' boats sail in and unload; the player's bodies are ashore from the start.
			for _i in 240:
				_game._process(1.0 / 60.0)
		2:
			for _i in 10:
				_game._unhandled_input(_wheel_up())
		3:
			_save("1_island")
		4:
			var at := _body_at_screen()
			if at.x >= 0.0:
				_game._unhandled_input(_press(at))
				_game._unhandled_input(_release(at))
		5:
			# **The reach, and nothing pressed since.** This is the shot the whole ticket is about.
			print("[shot] picked_set=%d rims_drawn=%d hand=%d"
				% [_game.field_view._picked.size(), _game.field_view._rims_used,
					_game.hand.ids.size()])
			_save("2_picked")
		6:
			_dest_at = _aim_from_reach()
			if _has_dest:
				_game._unhandled_input(_motion(_dest_at))
		7:
			# **The 이동선 under the cursor, before any press.** 미리 means exactly this frame.
			# ⚠ The counts are printed because a line that is computed but not visible and a line that
			# was never computed look identical in the PNG.
			var hand: Hand = _game.hand
			var pts := hand.route_points(_game.battle, _game._tile_at(_dest_at))
			var total := 0
			for line in pts:
				total += (line as PackedVector2Array).size()
			print("[shot] reach=%d routes=%d points=%d aim_tile=%d view_lines=%d fx_verts=%d"
				% [hand.reach.size(), pts.size(), total, _game._tile_at(_dest_at),
					_game.field_view._move_lines.size(), _game.field_view._g_v.size()])
			_save("3_line")
		8:
			# **Turn the board and re-aim.** ⚠⚠ **The 이동선 and the rim both have to survive this**
			# (2026-08-31, the user: 「약간 회전하니까 이상한거 같은데? 회전했을때도 자연스럽게
			# 해줄래?」).
			for _i in 3:
				_game._unhandled_input(_turn_key())
			_dest_at = _aim_from_reach()
		9:
			_save("4_turned")
		10:
			# **Pull the camera back.** ⚠ **The wheel goes both ways and the user asked for both to be
			# considered** (「마우스 휠을 내릴 수도 올릴 수도 있는거니까 항상 개발할때 고려해야함」).
			for _i in 8:
				_game._unhandled_input(_wheel_down())
			_dest_at = _aim_from_reach()
		11:
			_save("5_far")
		12:
			# ⚠ **Read the picked id BEFORE the press.** The order lets go of the hand, so afterwards
			# there is nobody in it to ask.
			if not _game.hand.is_empty():
				_who = int(_game.hand.ids[0])
			if _has_dest:
				_game._unhandled_input(_press(_dest_at))
				_game._unhandled_input(_release(_dest_at))
		13:
			# ⚠⚠ **PARK THE CURSOR IN THE MIDDLE BEFORE LETTING TIME RUN.** The shell edge-pans off
			# `_pointer_at`, and the aim above sits near a border — 180 frames with the pointer left
			# there panned the camera clean off the island and photographed open sea.
			_game._unhandled_input(_motion(Look.viewport_size_px() * 0.5))
			for _i in 60:
				_game._process(1.0 / 60.0)
		14:
			# ⚠ **Who was picked, where he is and where he was sent** — the picture alone cannot tell
			# an ordered body apart from one the sim moved on its own, and both are on screen here.
			var b: Battle = _game.battle
			print("[shot] picked=%d at=%s order_tile=%d dest_tile=%d hand_empty=%s reach=%d"
				% [_who, b.soldier_pos[_who], int(b.soldier_order[_who]),
					_game._tile_at(_dest_at), _game.hand.is_empty(), _game.hand.reach.size()])
			_save("6_walking")
		15:
			for _i in 180:
				_game._process(1.0 / 60.0)
		16:
			_save("7_arrived")
		_:
			print("[shot] picked=%d" % _who)
			return true
	_step += 1
	return false
