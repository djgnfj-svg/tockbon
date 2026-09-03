extends SceneTree
## **Ticket 03-21 on the real screen** — a 부대 walking the foot of the plateau across the named run
## 조각 (8,3) … (12,3), the 이동선 that starts under its feet, the price at a cliff-edge 칸, a body
## dying at the ledge, and the same walk after a quarter turn.
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_0321.gd -- <out-dir> <mode>
## ```
##
## | mode | frames |
## |---|---|
## | `recon` | `00_title` · `01_open` · `02_centred` — and the numbers for every body |
## | `walk` | the run, west to east, with the 이동선 frame before the press |
## | `crowd` | four bodies ordered onto the cliff-edge 칸, at rest and mid-walk |
## | `death` | one body killed mid-stride at the ledge |
## | `yaw` | the same walk at two further yaws, then B into 짓기 모드 and ESC out |
##
## ⚠ **`00_title` is the known-answer frame.** If it comes back wrong nothing below it is readable.
## ⚠⚠ **Every input goes through `Input.parse_input_event`** — no Win32, no key injection, never
## `--headless`.
## ⚠⚠ **THE CAMERA IS NEVER WRITTEN.** `_look_at` calibrates the pan keys by pressing them and reading
## the answer back, then drives the board with those keys — the shell rewrites the camera from its own
## state every frame, so a hand-written `cam_px` would be undone between the write and the shutter.
## ⚠⚠ **THE NEGATIVE CONTROL IS `raw`**: every report line prints the 눈금 the drawn point takes AND the
## 눈금 the UNSHORTENED offset would have taken. A walk in which `raw` never differs from `base` never
## put the defect in front of the lens and proves nothing.

const SUB := 1.0 / 60.0
const CENTRE := Vector2(Look.VIEWPORT_W_PX * 0.5, Look.VIEWPORT_H_PX * 0.5)
const MOTIONS := 30

## The run the ticket names, and the plateau that stands one storey over its south side.
const RUN_Y := 3
const RUN_X0 := 8
const RUN_X1 := 12

var _dir := ""
var _mode := "recon"
var _game: Game = null
var _sec := 0.0
var _at_risk_frames := 0
var _risk_seen := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("capture_0321: <출력 폴더> 인자를 달라")
		quit(1)
		return
	_dir = args[0]
	if args.size() > 1:
		_mode = args[1]
	if DisplayServer.get_name() == "headless":
		push_error("capture_0321: --headless 로는 픽셀을 못 읽는다")
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
		push_error("capture_0321: 섬이 안 열렸다")
		quit(1)
		return
	_game.set_process(false)
	var b: Battle = _game.battle
	await _until(func() -> bool: return b.ashore_ids().size() >= Rules.SWORDSMAN_START_COUNT, 30.0)
	await _settle(6)
	_park()
	print("island %dx%d ashore=%d zoom=%.2f yaw=%.1f"
		% [b.grid.w, b.grid.h, b.ashore_ids().size(), _game.field_view.zoom,
			_game.field_view.cam_yaw_deg])
	_report_terrain()
	_report_run_px()

	match _mode:
		"recon":
			await _mode_recon()
		"walk":
			await _mode_walk("")
		"crowd":
			await _mode_crowd()
		"death":
			await _mode_death()
		"yaw":
			await _mode_yaw()
		_:
			push_error("capture_0321: 모르는 모드 %s" % _mode)
			quit(1)
			return
	print("capture_0321: %s (%s) at-risk frames=%d bodies seen at risk=%s"
		% [_dir, _mode, _at_risk_frames, str(_risk_seen.keys())])
	quit()


# --- the modes -----------------------------------------------------------------------------------------

func _mode_recon() -> void:
	await _shot("01_open")
	await _frame_the_run(1.35)
	await _shot("02_centred")
	_report_bodies("recon")


## **The walk the lead asked for**: pick the four, park them on the west end of the run, then order
## them along it to the east end and shoot the stride.
func _mode_walk(tag: String) -> void:
	await _frame_the_run(1.35)
	await _pick_all()
	await _order_to(RUN_X0, RUN_Y, "west end")
	await _rest(45.0)
	_report_bodies("at rest, west end")
	await _shot("03-21%s-rest-west" % tag)

	await _pick_all()
	# The 이동선, hovered but not yet pressed — its first point is the thing to look at.
	var aim := _press_point_for(RUN_X1, RUN_Y)
	_motion(aim)
	await _settle(3)
	print("hover tile=%d lines=%d" % [_game._tile_at(aim), _game.field_view._move_lines.size()])
	_report_bodies("hover, line laid")
	await _shot("03-21%s-move-line" % tag)

	await _press_and_watch(aim, "%s-east" % tag)

	# **The leg back**, because the seats are re-dealt on every order and it is the seat that decides
	# whether a body carries its offset at the cliff at all.
	await _pick_all()
	var back := _press_point_for(RUN_X0, RUN_Y)
	await _press_and_watch(back, "%s-west" % tag)


## Press, then walk the clock in tenths — **shooting the frames in which a body's raw offset WOULD have
## put it a storey up**, which are the only frames that can prove or disprove anything here.
func _press_and_watch(aim: Vector2, tag: String) -> void:
	_motion(aim)
	_button(aim, true)
	_button(aim, false)
	_park()
	await _settle(2)
	var shots := 0
	var plain := 0
	for step in 90:
		await _advance(0.1)
		var risky := _risky_now()
		var done := _all_rested()
		if risky.size() > 0 and shots < 4:
			await _settle(1)
			_report_bodies("AT RISK %s %d" % [tag, shots])
			await _shot("03-21%s-atrisk-%d" % [tag, shots])
			shots += 1
		elif plain < 2 and step > 3 and not done:
			await _settle(1)
			_report_bodies("walking %s %d" % [tag, plain])
			await _shot("03-21%s-walk-%d" % [tag, plain])
			plain += 1
		if done:
			break
	await _advance(0.8)
	await _settle(3)
	_report_bodies("at rest %s" % tag)
	await _shot("03-21%s-rest" % tag)


## Every living body whose UNSHORTENED offset would land on a 조각 of a different 눈금 right now.
func _risky_now() -> Array:
	var g: Grid = _game.battle.grid
	var out: Array = []
	for raw in _game.battle.ashore_ids():
		var i := int(raw)
		var at: Vector2 = _game.battle.soldier_pos[i]
		var off: Vector2 = _game.field_view._seat_offset.get("s%d" % i, Vector2.ZERO)
		var base := g.level_at(int(round(at.x)), int(round(at.y)))
		var raw_pt := at + off
		if g.level_at(int(round(raw_pt.x)), int(round(raw_pt.y))) != base:
			out.append(i)
	return out


func _all_rested() -> bool:
	for raw in _game.battle.ashore_ids():
		if int(_game.battle.soldier_order[int(raw)]) >= 0:
			return false
	return true


## **The price, looked at.** Four bodies onto the 칸 whose south 조각 row is the ledge itself.
func _mode_crowd() -> void:
	await _frame_the_run(1.8)
	await _pick_all()
	await _order_to(10, RUN_Y, "cliff-edge 칸")
	for i in 4:
		await _advance(0.5)
		await _settle(2)
		_report_bodies("crowd walking %d" % i)
		await _shot("03-21-crowd-walk-%d" % i)
	await _rest(20.0)
	_report_bodies("crowd at rest")
	await _shot("03-21-crowd-rest")
	# And one 조각 further from the ledge, for the eye to compare the spacing against.
	await _pick_all()
	await _order_to(10, 1, "칸 two 조각 off the ledge")
	await _rest(20.0)
	_report_bodies("control 칸 at rest")
	await _shot("03-21-crowd-rest-control")


## **A body killed mid-stride at the ledge** — the death must not jump a storey.
func _mode_death() -> void:
	await _frame_the_run(1.8)
	await _pick_all()
	await _order_to(RUN_X0, RUN_Y, "west end")
	await _rest(45.0)
	await _pick_all()
	var aim := _press_point_for(RUN_X1, RUN_Y)
	_motion(aim)
	_button(aim, true)
	_button(aim, false)
	_park()
	await _advance(1.1)
	await _settle(2)
	var who := _closest_to_ledge()
	print("killing body %d at %s drawn %s"
		% [who, str(_game.battle.soldier_pos[who]), str(_seat_drawn(who))])
	await _shot("03-21-death-before")
	_game.battle.soldier_hp[who] = 0.0
	await _advance(0.10)
	await _settle(2)
	_report_bodies("just died")
	await _shot("03-21-death-0")
	await _advance(0.30)
	await _settle(2)
	await _shot("03-21-death-1")
	await _advance(0.30)
	await _settle(2)
	await _shot("03-21-death-2")


## **Two further yaws, then 짓기 모드 in and out.**
func _mode_yaw() -> void:
	_key(KEY_Q)
	await _turn_done()
	print("yaw now %.1f" % _game.field_view.cam_yaw_deg)
	await _mode_walk("-yaw1")

	_key(KEY_Q)
	await _turn_done()
	print("yaw now %.1f" % _game.field_view.cam_yaw_deg)
	await _mode_walk("-yaw2")

	_key(KEY_E)
	await _turn_done()
	await _pick_all()
	_key(KEY_B)
	await _settle(4)
	_motion(CENTRE)
	await _settle(3)
	print("build mode: building=%s hand=%s" % [str(_game.hand.building), str(_game.hand.ids)])
	await _shot("03-21-build-mode")
	_key(KEY_ESCAPE)
	await _settle(4)
	print("after ESC: building=%s hand=%s" % [str(_game.hand.building), str(_game.hand.ids)])
	await _shot("03-21-build-mode-out")


# --- staging -------------------------------------------------------------------------------------------

func _report_terrain() -> void:
	var g: Grid = _game.battle.grid
	var line := ""
	for x in range(RUN_X0 - 1, RUN_X1 + 2):
		line += " (%d,%d)=%d/%d" % [x, RUN_Y, g.level_at(x, RUN_Y), g.level_at(x, RUN_Y + 1)]
	print("run 조각 level / 조각 below:%s" % line)


## One line per body: the sim's point, the drawn point, the offset, and the three 눈금 that matter.
## Where the named run lands on the glass at the framing the game itself opened with.
func _report_run_px() -> void:
	var line := ""
	for x in range(RUN_X0, RUN_X1 + 1):
		line += " (%d,%d)=%s" % [x, RUN_Y, str(_tile_px(x, RUN_Y).round())]
	print("run on glass:%s" % line)


func _report_bodies(tag: String) -> void:
	var g: Grid = _game.battle.grid
	var risky := false
	for raw in _game.battle.ashore_ids():
		var i := int(raw)
		var key := "s%d" % i
		var at: Vector2 = _game.battle.soldier_pos[i]
		var drawn: Vector2 = _game.field_view._seat_glide.get(key, at)
		var off: Vector2 = _game.field_view._seat_offset.get(key, Vector2.ZERO)
		var base := g.level_at(int(round(at.x)), int(round(at.y)))
		var kept := g.level_at(int(round(drawn.x)), int(round(drawn.y)))
		var raw_pt := at + off
		var raw_lv := g.level_at(int(round(raw_pt.x)), int(round(raw_pt.y)))
		var flag := ""
		if raw_lv != base:
			flag = "  <== AT RISK (raw would sit on 눈금 %d)" % raw_lv
			risky = true
			_risk_seen[i] = true
		if kept != base:
			flag += "  <== STILL LIFTED"
		print("  %s s%d at=%.2f,%.2f drawn=%.2f,%.2f off=%.2f,%.2f base=%d kept=%d h=%.2f%s"
			% [tag, i, at.x, at.y, drawn.x, drawn.y, off.x, off.y, base, kept,
				g.surface_h(drawn), flag])
		if kept != base:
			var re: Vector2 = _game.field_view._offset_kept_on_level(g, at, off)
			print("     exact at=%.9f,%.9f off=%.9f,%.9f drawn=%.9f,%.9f  kept_now=%.9f,%.9f"
				% [at.x, at.y, off.x, off.y, drawn.x, drawn.y, re.x, re.y])
	if risky:
		_at_risk_frames += 1


func _seat_drawn(i: int) -> Vector2:
	return _game.field_view._seat_glide.get("s%d" % i, _game.battle.soldier_pos[i])


## The living body whose drawn point sits nearest the plateau edge, for the death shot.
func _closest_to_ledge() -> int:
	var best := -1
	var best_y := -1e9
	for raw in _game.battle.ashore_ids():
		var i := int(raw)
		var y := _seat_drawn(i).y
		if y > best_y:
			best_y = y
			best = i
	return best


func _pick_all() -> void:
	_key(KEY_ESCAPE)
	await _settle(2)
	var r := _all_bodies_rect()
	if r.size == Vector2.ZERO:
		push_error("capture_0321: 화면에 몸이 하나도 안 그려졌다")
		quit(1)
		return
	await _drag(r.position, r.end)
	_button(r.end, false)
	await _settle(3)
	_park()
	print("picked=%s reach=%d" % [str(_game.hand.ids), _game.hand.reach.size()])


## **The screen point that actually hits the wanted 칸.** ⚠⚠ **The 조각's own projected point is not
## it at a ledge**: `tile_to_screen_px(8, 3)` came back over the plateau's face and `_tile_at` read
## (8,4) — a storey up and the wrong 칸 — so the 부대 was ordered ONTO the cliff instead of along its
## foot. The point is searched around the projection until the shell's own hit test agrees.
func _press_point_for(tx: int, ty: int) -> Vector2:
	var g: Grid = _game.battle.grid
	var want := g.block_of(ty * g.w + tx)
	var base := _tile_px(tx, ty)
	var best := Vector2(-1.0, -1.0)
	var best_d := 1e9
	for ring in range(0, 13):
		var step := float(ring) * 4.0
		for dx in [-step, 0.0, step]:
			for dy in [-step, 0.0, step]:
				var at := base + Vector2(dx, dy)
				if at.x < 20.0 or at.y < 20.0 or at.x > Look.VIEWPORT_W_PX - 20.0 or at.y > Look.VIEWPORT_H_PX - 20.0:
					continue
				var hit := _game._tile_at(at)
				if hit < 0 or g.block_of(hit) != want:
					continue
				var d := at.distance_to(base)
				if d < best_d:
					best_d = d
					best = at
		if best.x >= 0.0 and ring >= 1:
			break
	return best


## A short left press on the 칸 that holds `(tx, ty)`, through the shell's own hit test.
func _order_to(tx: int, ty: int, what: String) -> void:
	var g: Grid = _game.battle.grid
	var px := _press_point_for(tx, ty)
	if px.x < 0.0:
		push_error("capture_0321: %s (%d,%d) 를 화면에서 못 짚었다" % [what, tx, ty])
		quit(1)
		return
	var hit := _game._tile_at(px)
	print("order to %s (%d,%d): press %s hits tile %d = 조각 (%d,%d) 칸 %d (want 칸 %d)"
		% [what, tx, ty, str(px.round()), hit, hit % g.w, hit / g.w, g.block_of(hit),
			g.block_of(ty * g.w + tx)])
	_motion(px)
	await _settle(2)
	_button(px, true)
	_button(px, false)
	_park()
	await _settle(2)


## Run the sim until nobody holds an order any more, or the cap runs out.
func _rest(cap_sec: float) -> void:
	await _until(func() -> bool:
		for raw in _game.battle.ashore_ids():
			if int(_game.battle.soldier_order[int(raw)]) >= 0:
				return false
		return true, cap_sec)
	await _advance(0.8)
	await _settle(3)


func _all_bodies_rect() -> Rect2:
	var out := Rect2()
	var first := true
	for sid in _game.battle.ashore_ids():
		var r := _game.field_view.drawn_rect_px(int(sid))
		if r.size == Vector2.ZERO:
			continue
		out = r if first else out.merge(r)
		first = false
	return out.grow(10.0)


func _tile_px(tx: int, ty: int) -> Vector2:
	return _game.field_view.tile_to_screen_px(tx, ty)


## **The pointer parked in the middle of the glass**, so the edge band never pans the board between a
## gesture and the shutter.
func _park() -> void:
	_motion(CENTRE)


# --- the camera, driven only through the pan keys --------------------------------------------------------

## **Centre the board on a 조각 by pressing the pan keys and reading the answer back.** The two keys are
## calibrated first — press, measure, release — so the mapping is measured rather than assumed, and it
## is re-measured after every turn.
## **Zoom to `want` and put the run in the middle** — idempotent, so calling it once per yaw does not
## ratchet the zoom to its stop.
func _frame_the_run(want: float) -> void:
	for _i in 12:
		if absf(_game.field_view.zoom - want) <= 0.02 * want:
			break
		await _zoom(1 if _game.field_view.zoom < want else -1)
	await _look_at(Vector2(float(RUN_X0 + RUN_X1) * 0.5, float(RUN_Y) + 0.5))


## **The wheel, through the shell's own handler** — zoomed about the middle of the glass so the framing
## turns about the thing being looked at.
func _zoom(notches: int) -> void:
	for _i in absi(notches):
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if notches > 0 else MOUSE_BUTTON_WHEEL_DOWN
			ev.position = CENTRE
			ev.pressed = down
			ev.factor = 1.0
			Input.parse_input_event(ev)
		await _settle(2)
	print("zoom now %.2f" % _game.field_view.zoom)


func _look_at(where: Vector2) -> void:
	var tx := int(round(where.x))
	var ty := int(round(where.y))
	var last := Vector2(1e9, 1e9)
	for _iter in 16:
		var now := _tile_px(tx, ty)
		var err := CENTRE - now
		if err.length() < 14.0:
			break
		# **The roam box can simply refuse.** When a pass changes nothing, the board is against its stop
		# and the residual is reported rather than looped on.
		if now.distance_to(last) < 2.0:
			print("look_at: roam 끝에 걸렸다, 남은 err=%s" % str(err.round()))
			break
		last = now
		# ⚠ **Calibrated ON THE TARGET 조각 and not on a corner.** The board is drawn in perspective, so
		# the same key moves a near 조각 and a far one by different amounts; calibrating on (0,0) sent
		# this loop past the roam clamp and off the bottom of the glass.
		var a := await _axis(tx, ty, KEY_D, KEY_A)
		var bvec := await _axis(tx, ty, KEY_W, KEY_S)
		var det := a.x * bvec.y - a.y * bvec.x
		if absf(det) < 1e-6:
			print("look_at: 팬이 더 안 움직인다. err=%s" % str(err.round()))
			break
		var u := (err.x * bvec.y - err.y * bvec.x) / det
		var v := (a.x * err.y - a.y * err.x) / det
		# Damped, because the roam clamp cuts a hold short and an undamped solve then overshoots.
		await _hold(KEY_D if u >= 0.0 else KEY_A, absf(u) * 0.05 * 0.7)
		await _hold(KEY_W if v >= 0.0 else KEY_S, absf(v) * 0.05 * 0.7)
		print("  iter err=%s a=%s b=%s u=%.2f v=%.2f -> %s cam=%s"
			% [str(err.round()), str(a.round()), str(bvec.round()), u, v,
				str(_tile_px(tx, ty).round()), str(_game.field_view.cam_px.round())])
	await _settle(2)
	print("look_at (%d,%d) -> %s  cam=%s zoom=%.2f"
		% [tx, ty, str(_tile_px(tx, ty).round()), str(_game.field_view.cam_px.round()),
			_game.field_view.zoom])


## **How far the target 조각 moves for one key, with the opposite key as the fallback** — a camera
## already against the roam clamp answers zero to one of the two, and that zero is what turns the
## solve degenerate.
func _axis(tx: int, ty: int, pos: int, neg: int) -> Vector2:
	var before := _tile_px(tx, ty)
	await _hold(pos, 0.05)
	var got := _tile_px(tx, ty) - before
	if got.length() > 1.0:
		return got
	before = _tile_px(tx, ty)
	await _hold(neg, 0.05)
	return -(_tile_px(tx, ty) - before)


func _hold(code: int, sec: float) -> void:
	if sec <= 0.0:
		return
	sec = minf(sec, 1.5)
	_key_down(code)
	await _advance(sec)
	_key_up(code)
	# ⚠ **The camera lags the key.** Measuring the moment the key comes up read a third of the travel
	# and the solve then undershot by 3x and oscillated; let the board finish arriving first.
	await _advance(0.30)


## The board's quarter turn is paid off frame by frame; wait it out rather than guessing a frame count.
func _turn_done() -> void:
	var was := _game.field_view.cam_yaw_deg
	for _i in 400:
		_game._process(SUB)
		_sec += SUB
		if _i % 4 == 0:
			await process_frame
		if absf(_game.field_view.cam_yaw_deg - was) >= 89.5:
			break
	await _settle(4)


# --- the clock -----------------------------------------------------------------------------------------

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


# --- input ----------------------------------------------------------------------------------------------

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


func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from)
	_button(from, true)
	for i in range(1, MOTIONS + 1):
		_motion(from.lerp(to, float(i) / float(MOTIONS)))
		await process_frame
	await _settle(4)


func _key(code: int) -> void:
	_key_down(code)
	_key_up(code)


func _key_down(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _key_up(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)


# --- the shutter ----------------------------------------------------------------------------------------

func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		push_error("capture_0321: %s 를 못 썼다" % path)
	print("--- %s  t=%.3f zoom=%.2f cam=%s yaw=%.1f"
		% [name, _sec, _game.field_view.zoom, str(_game.field_view.cam_px.round()),
			_game.field_view.cam_yaw_deg])
