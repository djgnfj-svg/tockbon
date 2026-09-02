extends SceneTree
## **Ticket 03-12 on the real screen** — the selection box mid-drag over the four 검사 at the 성채
## door, the same box after a quarter turn, the four wearing the rim once the button comes up, and
## what the 부대 does after it: one reach, one 이동선, four walking.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_0312.gd -- <out-dir> <mode>
## ```
##
## | mode | frames |
## |---|---|
## | `box` (default) | `00_title` · `03-12-box-mid-drag` · `03-12-box-mid-drag-yaw90` · `03-12-box-picked` |
## | `reach` | `00_title` · `03-12-reach-one` (one body picked) · `03-12-reach-four` (the 부대) |
## | `move` | `00_title` · `03-12-move-line` (hover a lit 칸) · `03-12-walking` (after the press) |
## | `yaw` | `00_title` · `03-12-yaw90-mid-drag` · `03-12-yaw90-picked` (a drag AFTER the turn) |
##
## ⚠ **`00_title` is the known-answer frame.** If it comes back wrong nothing below it is readable.
## ⚠⚠ **Every input goes through `Input.parse_input_event`** — the shell's own `_unhandled_input` is what
## receives it, exactly as it would from the OS. No Win32, no key injection, and never `--headless`.
## ⚠ **The sim is driven by calling the shell's own `_process`** until the opening four are ashore, in
## `capture_0701.gd`'s shape; `set_process(false)` is what stops the engine advancing it a second time,
## so the four stand still under the box for all three frames.

const SUB := 1.0 / 60.0
## The drag the ticket names: press here, thirty motions to the far corner, hold.
const PRESS_AT := Vector2(440.0, 345.0)
const DRAG_TO := Vector2(660.0, 445.0)
const MOTIONS := 30

var _dir := ""
var _mode := "box"
var _game: Game = null
var _sec := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("capture_0312: <출력 폴더> 인자를 달라")
		quit(1)
		return
	_dir = args[0]
	if args.size() > 1:
		_mode = args[1]
	if DisplayServer.get_name() == "headless":
		push_error("capture_0312: --headless 로는 픽셀을 못 읽는다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)
	await process_frame
	await _settle(10)
	await _shot("00_title")

	_click(Look.title_slot_rect_px(TitleView.SLOT_START).get_center())
	await _settle(6)
	if _game.battle == null:
		push_error("capture_0312: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	var b: Battle = _game.battle
	# The counted boot: the opening watch walks out of the 성채 door one by one.
	await _until(func() -> bool: return b.ashore_ids().size() >= Rules.SWORDSMAN_START_COUNT, 30.0)
	await _settle(6)
	print("island %dx%d ashore=%d t=%.2f zoom=%.2f" % [b.grid.w, b.grid.h, b.ashore_ids().size(), _sec,
		_game.field_view.zoom])
	_report_bodies()

	match _mode:
		"box":
			await _mode_box()
		"reach":
			await _mode_reach()
		"move":
			await _mode_move()
		"yaw":
			await _mode_yaw()
		_:
			push_error("capture_0312: 모르는 모드 %s" % _mode)
			quit(1)
			return
	print("capture_0312: %s (%s)" % [_dir, _mode])
	quit()


# --- the four modes ------------------------------------------------------------------------------------

func _mode_box() -> void:
	await _drag(PRESS_AT, DRAG_TO)
	print("mid-drag boxing=%s box=%s caught=%s"
		% [str(_game._boxing), str(_game._box), str(_game.field_view.bodies_in_rect_px(_game._box))])
	await _shot("03-12-box-mid-drag")

	# ⚠ **The release comes BEFORE the Q frame, not after it.** The ticket's own order (drag, Q,
	# release) turns the board under a screen-space box, so the four are no longer inside it when the
	# button comes up and `03-12-box-picked` came back with an EMPTY hand. The turn gets its own drag.
	_button(DRAG_TO, false)
	await _settle(4)
	print("picked=%s reach=%d blocks=%d box=%s"
		% [str(_game.hand.ids), _game.hand.reach.size(), _game.hand.reach_blocks.size(),
			str(_game._box)])
	await _shot("03-12-box-picked")

	_key(KEY_ESCAPE)
	await _settle(2)
	await _drag(PRESS_AT, DRAG_TO)
	_key(KEY_Q)
	await _settle(100)
	print("yaw=%.2f box=%s" % [_game.field_view.cam_yaw_deg, str(_game._box)])
	await _shot("03-12-box-mid-drag-yaw90")
	_button(DRAG_TO, false)
	await _settle(2)


## **The comparison the ticket asks for**: what ONE body lights, then what the four light.
func _mode_reach() -> void:
	var one := _body_centre(int(_game.battle.ashore_ids()[0]))
	_click(one)
	await _settle(4)
	print("one picked=%s reach=%d blocks=%d"
		% [str(_game.hand.ids), _game.hand.reach.size(), _game.hand.reach_blocks.size()])
	await _shot("03-12-reach-one")

	_key(KEY_ESCAPE)
	await _settle(2)
	await _drag_over_all()
	_button(_game._box.end, false)
	await _settle(4)
	print("four picked=%s reach=%d blocks=%d"
		% [str(_game.hand.ids), _game.hand.reach.size(), _game.hand.reach_blocks.size()])
	await _shot("03-12-reach-four")


## **One 이동선 for the 부대, then the walk.**
func _mode_move() -> void:
	await _drag_over_all()
	_button(_game._box.end, false)
	await _settle(4)
	print("picked=%s reach=%d" % [str(_game.hand.ids), _game.hand.reach.size()])

	var aim := _far_lit_point()
	if aim.x < 0.0:
		push_error("capture_0312: 화면 위에서 불 들어온 칸을 못 찾았다")
		quit(1)
		return
	_motion(aim)
	await _settle(3)
	print("hover at %s lines=%d lead=%d"
		% [str(aim), _game.field_view._move_lines.size(),
			_game.hand.lead(_game.battle, _game.battle.grid.block_of(_game._tile_at(aim)))])
	await _shot("03-12-move-line")

	_button(aim, true)
	_button(aim, false)
	await _settle(2)
	var ordered := 0
	for sid in _game.hand.ids:
		ordered += 1
	print("after press: hand=%s box=%s boxing=%s"
		% [str(_game.hand.ids), str(_game._box), str(_game._boxing)])
	# Let the sim walk for a moment so the frame catches them mid-stride.
	await _advance(0.9)
	await _settle(3)
	print("walking: lines=%d hand_empty=%s" % [_game.field_view._move_lines.size(),
		str(_game.hand.is_empty())])
	_report_bodies()
	await _shot("03-12-walking")

	await _advance(7.0)
	await _settle(3)
	print("arrived:")
	_report_bodies()
	await _shot("03-12-arrived")


## **A drag AFTER the quarter turn** — the board is at yaw 90 and the box still catches what it covers.
func _mode_yaw() -> void:
	_key(KEY_Q)
	await _settle(120)
	print("yaw=%.2f" % _game.field_view.cam_yaw_deg)
	_report_bodies()
	await _drag_over_all()
	print("yaw mid-drag box=%s caught=%s"
		% [str(_game._box), str(_game.field_view.bodies_in_rect_px(_game._box))])
	await _shot("03-12-yaw90-mid-drag")
	_button(_game._box.end, false)
	await _settle(4)
	print("yaw picked=%s reach=%d" % [str(_game.hand.ids), _game.hand.reach.size()])
	await _shot("03-12-yaw90-picked")


# --- staging helpers -----------------------------------------------------------------------------------

func _report_bodies() -> void:
	for sid in _game.battle.ashore_ids():
		print("  body %d at %s drawn %s"
			% [int(sid), str(_game.battle.soldier_pos[int(sid)]),
				str(_game.field_view.drawn_rect_px(int(sid)))])


func _body_centre(sid: int) -> Vector2:
	return _game.field_view.drawn_rect_px(sid).get_center()


## The bounding box of every drawn body, grown 8 px, as a press point and a release point.
func _all_bodies_rect() -> Rect2:
	var out := Rect2()
	var first := true
	for sid in _game.battle.ashore_ids():
		var r := _game.field_view.drawn_rect_px(int(sid))
		if r.size == Vector2.ZERO:
			continue
		out = r if first else out.merge(r)
		first = false
	return out.grow(8.0)


func _drag_over_all() -> void:
	var r := _all_bodies_rect()
	await _drag(r.position, r.end)


func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from)
	_button(from, true)
	for i in range(1, MOTIONS + 1):
		_motion(from.lerp(to, float(i) / float(MOTIONS)))
		await process_frame
	await _settle(4)


## A lit 칸 far from the bodies, projected onto the glass and checked to be on screen.
func _far_lit_point() -> Vector2:
	var g: Grid = _game.battle.grid
	var home := Vector2.ZERO
	var n := 0
	for sid in _game.hand.ids:
		home += _game.battle.soldier_pos[int(sid)] as Vector2
		n += 1
	if n > 0:
		home /= float(n)
	var best := Vector2(-1.0, -1.0)
	var best_d := 0.0
	for t in _game.hand.reach:
		var tx := int(t) % g.w
		var ty := int(t) / g.w
		var d := Vector2(tx, ty).distance_to(home)
		if d <= best_d:
			continue
		var px: Vector2 = _game.field_view.tile_to_screen_px(tx, ty)
		if px.x < 60.0 or px.y < 60.0 or px.x > Look.VIEWPORT_W_PX - 60.0 or px.y > Look.VIEWPORT_H_PX - 60.0:
			continue
		if _game._tile_at(px) != int(t):
			continue
		best_d = d
		best = px
	return best


# --- the clock -----------------------------------------------------------------------------------------

## One sub-step at a time through the shell's own `_process`, with a real frame every quarter second
## so the views keep up and nothing is photographed a hundred seconds stale.
func _until(test: Callable, cap_sec: float) -> void:
	var spent := 0.0
	var n := 0
	while spent < cap_sec:
		_game._process(SUB)
		_sec += SUB
		spent += SUB
		n += 1
		if test.call():
			break
		if n % 15 == 0:
			await process_frame
	await process_frame
	await process_frame


func _advance(sec: float) -> void:
	var spent := 0.0
	var n := 0
	while spent < sec:
		_game._process(SUB)
		_sec += SUB
		spent += SUB
		n += 1
		if n % 4 == 0:
			await process_frame
	await process_frame


# --- the hand, through the engine's own input door ------------------------------------------------------

func _click(at: Vector2) -> void:
	_motion(at)
	_button(at, true)
	_button(at, false)


func _button(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = at
	ev.pressed = down
	Input.parse_input_event(ev)


func _motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	Input.parse_input_event(ev)


func _key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)


# --- the shutter ---------------------------------------------------------------------------------------

func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_0312: %s 를 못 썼다" % path)
	print("--- %s  t=%.3f zoom=%.2f cam=%s"
		% [name, _sec, _game.field_view.zoom, str(_game.field_view.cam_px.round())])
