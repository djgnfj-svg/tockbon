extends RefCounted
## The hands: the three commands, the three active slots, the body panel and the input gate.
##
## **The gate is the reason this file drives the real shell.** `Input.is_action_just_pressed` is a POLL,
## and no `mouse_filter` and no `set_input_as_handled()` stops a poll — so clicking a level-up card or a
## binding row also fires slot 0 unless `main.gd` refuses to read input at all while a panel is up. That
## refusal cannot be measured by reading the gate's own flag; the keys are actually pressed here
## (`Input.action_press`, process-local and headless — it steals nothing from anyone) and the simulation is
## asserted unchanged.
##
## **Every "nothing happened" check carries its opposite.** A press that does nothing because the pressing
## itself is broken looks exactly like a working gate, so the same eight actions are pressed again with no
## panel open and three specific effects are asserted to land.

const DT := 1.0 / 60.0

## Every polled action `main.gd::_read_input()` reads. Eight, and the gate has to stop all eight.
const ACTIONS := ["fire_0", "fire_1", "fire_2", "split", "absorb",
		"cmd_rally", "cmd_scatter", "cmd_strike"]


class HudSpy extends Hud:
	var lines: Array[String] = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		lines.append(text)
		super._paint_text(c, p, text, font_size, col)


## **Both leaves, not just the rectangles.** `_paint_text` was unspied, so `Parts.NAME[bound[key]]` could
## be replaced with a constant and every row would name the wrong part while the layout checks stayed
## green — a body screen that lies about what is bound, laid out perfectly inside 1280x720.
class PanelSpy extends BodyPanel:
	var rects: Array = []
	var texts: Array = []

	func _paint_panel(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
		rects.append(r)
		super._paint_panel(c, r, col, filled, width)

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		texts.append(text)
		super._paint_text(c, p, text, font_size, col)


## The real wiring runs first and unmodified — `super._ready()` is `main.gd`'s own, building and parenting
## the real `BodyPanel` exactly as the game does. Only afterwards is a spy swapped onto the same parent, so
## deleting the shell's own `add_child` line still goes red here (there would be no parent to read).
##
## ⚠ **The signal connections are COPIED off the real panel, never re-made here.** Written as
## `panel_spy.bind_requested.connect(_on_bind_requested)`, this class supplies the very wire it is
## supposed to be watching: `main.gd`'s own `body.bind_requested.connect(...)` line could be replaced with
## `pass` and the whole round stayed green while `Tab` became a still picture. Copied instead, a missing
## line leaves nothing to copy and every bind below goes red.
class MainSpy extends "res://src/shell/main.gd":
	var panel_spy: PanelSpy = null

	func _ready() -> void:
		super._ready()
		var layer := body.get_parent()
		panel_spy = PanelSpy.new()
		for con: Dictionary in body.bind_requested.get_connections():
			panel_spy.bind_requested.connect(con["callable"] as Callable)
		layer.remove_child(body)
		body.queue_free()
		layer.add_child(panel_spy)
		body = panel_spy


func run(t) -> void:
	_c_walk_and_dash(t)
	_c19_rally(t)
	_c20_c21_strike(t)
	_c22_c25_slots(t)
	await _c25b_bind_driven(t)
	await _c26_c30_c31_panel(t)
	await _c27_panel_rects(t)
	await _c28_c29_gate(t)
	await _c_sustain_through_the_shell(t)
	await _c32_legend(t)
	await _s1_click_reaches_the_world(t)
	await _s2_hud_camera_rect(t)


# -- the walk and the burst, per step -------------------------------------------------------------------
## ⚠ **These six moved here from `net_hunt` with plan 4.** They contain no creature at all — they are two
## keys and the distance a body covers in one frame — and they were the last thing holding that file to its
## old subject. Nothing about them changed in the move.
##
## Both magnitudes are pinned as literals. Read through `Rules.HOST_SPEED` or `Parts.SELF_MUL[DASH]` these
## checks scale with the constant and stay green at every value, including zero.
func _c_walk_and_dash(t) -> void:
	var sw := Swarm.new()
	sw.setup(21, Vector2(1000.0, 1000.0))
	sw.host_input = Vector2.RIGHT
	sw.step(DT, null)
	var walk := sw.pos[0].distance_to(Vector2(1000.0, 1000.0))
	t.ok(absf(walk - 3.33) < 0.02, "한 스텝에 200px/s 만큼 걸었다 (%.3f)" % walk)

	# **The burst is a PART on a key**, not a method on the swarm: `try_dash()` and its three `Rules.DASH_*`
	# constants are gone, and 짧은 숨 is a row in the parts table that `space` opens holding.
	var body := Body.new()
	body.setup()
	body.swarm = sw
	t.eq(body.bound[Body.KEY_MOVEMENT], Parts.DASH, "설정: 스페이스는 짧은 숨을 들고 열린다")
	t.ok(body.fire(Body.KEY_MOVEMENT, Vector2(2000.0, 1000.0)), "대시가 나간다")
	t.ok(not body.fire(Body.KEY_MOVEMENT, Vector2(2000.0, 1000.0)), "쿨다운 중에는 두 번째 대시가 없다")
	var before: Vector2 = sw.pos[0]
	sw.step(DT, null)
	var dash_step := sw.pos[0].distance_to(before)
	t.ok(dash_step > walk * 2.0, "대시 한 스텝이 걷기보다 훨씬 멀다 (%.1f > %.1f)" % [dash_step, walk])
	# 9.33 = `HOST_SPEED 200 × SELF_MUL 2.8 / 60`, which is plan 2's absolute 560px/s carried across.
	t.ok(absf(dash_step - 9.33) < 0.02, "한 스텝에 560px/s 만큼 튀었다 (%.3f)" % dash_step)


# -- 19: `1` puts the swarm back into FOLLOW, and steers at the host LIVE -------------------------------
## Two different host positions, and the mean distance has to fall after each. A latched point passes the
## first half on its own — the second is the whole check.
##
## ⚠ **The swarm is scattered first, and without that this check measures nothing about the key.**
## `setup()` writes `FOLLOW` into row 0 and nothing rewrites it; `add_clone()` copies its parent's state;
## so every clone in a fresh swarm is already FOLLOW and `command_rally()`'s body could be `pass` with the
## whole round green. What the stepping below measures is `_move_clone()`'s FOLLOW branch reading `pos[0]`
## live — real, and not the key. The state assertion is the key.
func _c19_rally(t) -> void:
	var sw := Swarm.new()
	sw.setup(19, Vector2(1000.0, 1000.0))
	for i in 10:
		var k := sw.add_clone()
		sw.pos[k] = Vector2(2400.0 + float(i) * 40.0, 1600.0)
	sw.command_scatter()
	var scattered := 0
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.SCATTER:
			scattered += 1
	t.eq(scattered, 10, "설정: 열이 전부 흩어진 상태다 — 부르기가 되돌릴 것이 실제로 있다")

	var host_state_before: int = sw.state[0]
	sw.command_rally()
	var followers := 0
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.FOLLOW:
			followers += 1
	t.eq(followers, 10, "1이 흩어진 열을 전부 FOLLOW로 되돌린다")
	t.eq(sw.state[0], host_state_before, "호스트의 줄은 그대로다 — 명령은 1번부터 돈다")

	var d0 := _mean_to(sw, sw.pos[0])
	for _s in 60:
		sw.step(DT, null)
	var d1 := _mean_to(sw, sw.pos[0])
	t.ok(d1 < d0 - 100.0, "무리가 호스트 쪽으로 실제로 다가온다 (%.0f → %.0f)" % [d0, d1])

	# The host walks off. Nothing re-issues the command; a stored rendezvous point would keep the swarm
	# walking at the old coordinate and this distance would grow instead.
	sw.pos[0] = Vector2(3000.0, 400.0)
	var d2 := _mean_to(sw, sw.pos[0])
	for _s in 60:
		sw.step(DT, null)
	var d3 := _mean_to(sw, sw.pos[0])
	t.ok(d3 < d2 - 100.0, "호스트가 자리를 옮기면 무리는 새 자리를 따라온다 (%.0f → %.0f)" % [d2, d3])


# -- 20/21: `3` sends them somewhere and they STAY ------------------------------------------------------
func _c20_c21_strike(t) -> void:
	# 20: the coordinate is a pinned literal, never `sw.strike_point` — a bound read out of the thing it
	# measures moves with it and proves nothing.
	var point := Vector2(2500.0, 1600.0)
	var sw := Swarm.new()
	sw.setup(20, Vector2(1000.0, 1000.0))
	for i in 8:
		var k := sw.add_clone()
		sw.pos[k] = Vector2(1000.0 + float(i) * 40.0, 1000.0)
	sw.command_strike(point)
	for _s in 600:
		sw.step(DT, null)
	var arrived := _mean_to(sw, point)
	t.ok(arrived < 60.0, "보낸 무리가 찍은 좌표(2500,1600)에 도착한다 (%.1f)" % arrived)
	t.ok(sw.pos[0].distance_to(point) > 1000.0,
			"설정: 호스트는 멀리 있다 — 머무는 것과 돌아오는 것이 구별된다")
	var worst := arrived
	for _s in 120:
		sw.step(DT, null)
		worst = maxf(worst, _mean_to(sw, point))
	t.ok(worst < 60.0, "2초를 더 돌려도 그 자리에 머문다 — 호스트에게 되돌아가지 않는다 (%.1f)" % worst)

	# 21: a sent clone does not peel off for a crumb. `_move_clone` still computes `_target_food` every
	# frame for every state, so "it never noticed the food" is not what makes this pass — the STRIKE branch
	# simply does not steer at it.
	var host := Vector2(2000.0, 1400.0)
	var strike := Vector2(2000.0, 1000.0)
	var crumb := strike + Vector2(30.0, 0.0)
	var a := Swarm.new()
	a.setup(21, host)
	var ca := a.add_clone()
	a.pos[ca] = Vector2(1850.0, 1000.0)
	a.command_strike(strike)
	var fa := _food_at([crumb])
	for _s in 200:
		a.step(DT, fa)
	t.eq(fa.alive_count, 1, "보내진 분신은 30px 옆 먹이를 쫓지 않는다")
	t.ok(a.pos[ca].distance_to(strike) <= 30.0,
			"보내진 분신은 찍은 지점 곁에 머문다 (%.1f)" % a.pos[ca].distance_to(strike))
	# **The distance alone cannot tell the two apart** and that is measured, not guessed: a clone that DID
	# steer at the crumb still stops `rally_radius()` short of it, which lands it 6px from the strike point
	# — inside the bound above. The side it stopped on is what separates them. It came from -x, so a clone
	# that never went for the crumb never passes the point at all.
	t.ok(a.pos[ca].x <= strike.x + 1.0,
			"찍은 지점을 지나 먹이 쪽으로 넘어가지 않았다 (x %.1f)" % a.pos[ca].x)

	# The control, and it is not optional: without it "the food survived" is satisfied just as well by a
	# crumb no clone could ever have reached. Same start, same crumb, SCATTER instead of STRIKE.
	var b := Swarm.new()
	b.setup(211, host)
	var cb := b.add_clone()
	b.pos[cb] = Vector2(1850.0, 1000.0)
	b.command_scatter()
	var fb := _food_at([crumb])
	for _s in 400:
		b.step(DT, fb)
	t.eq(fb.alive_count, 0, "대조: 흩어진 분신은 같은 먹이를 실제로 먹는다 (닿을 수 없는 자리가 아니다)")


# -- 22..25: the three keys -----------------------------------------------------------------------------
## **The keys live on `Body` now.** `bound`, `bound_cd`, `fire()` and `bind()` moved off `Swarm` with the
## parts table, `src/sim/actives.gd` is deleted, and the ids in `bound` are PART ids — `Parts.BITE` is 0,
## so the empty square is `-1` and can never be 0 again.
func _c22_c25_slots(t) -> void:
	# 22: inside the cone, exactly one dies. `fire()` reads the food the last `step()` was handed, so the
	# step comes first — and every crumb sits past EAT_RADIUS_HOST so ordinary eating cannot be what moved.
	#
	# ⚠ **The extra crumb pins the cone's ANGLE, which had no bound at all.** The only out-of-cone crumb
	# used to sit at 180°, so the whole arc assertion said was "not directly behind": widen the arc from
	# 70° to 350° and the bite becomes a near-circle with every check here green. (1025, 1043) is 50px out
	# and 60° off the aim axis — inside the range, outside the 35° half-arc. A literal, because written as
	# `Parts.RANGE[BITE] * something` it would scale with the very number it exists to pin.
	var rig := _rig(22)
	var sw: Swarm = rig[0]
	var b: Body = rig[1]
	var wide_angle := Vector2(1025.0, 1043.0)
	var f := _food_at([Vector2(1050.0, 1000.0), Vector2(1058.0, 1006.0), Vector2(1064.0, 994.0),
			wide_angle])
	sw.step(DT, f)
	t.eq(f.alive_count, 4, "설정: 그냥 밟고 지나가서 먹히는 거리가 아니다")
	t.ok(b.fire(0, Vector2(1400.0, 1000.0)), "좌클릭이 앞쪽 원뿔 안 먹이를 문다")
	t.eq(f.alive_count, 3, "한 입에 정확히 하나만 사라진다")
	t.ok(_alive_at(f, wide_angle), "각이 벗어난 50px 먹이는 살아남는다 — 부채꼴은 원이 아니다")

	# ⚠ **The RANGE needs its own fixture, and the first attempt at it was inert.** A far crumb added
	# alongside near ones proves nothing: `bite()` takes the NEAREST candidate, so raising the reach from
	# 70 to 700 eats the same near crumb and the far one survives either way — measured, green. The only
	# crumb here is the far one, so a widened range has nothing else to reach for.
	var rig_far := _rig(222)
	var far: Swarm = rig_far[0]
	var far_b: Body = rig_far[1]
	var h := _food_at([Vector2(1100.0, 1000.0)])
	far.step(DT, h)
	t.eq(h.alive_count, 1, "설정: 100px 앞 먹이가 아직 살아 있다")
	# ⚠ **이 두 검사는 주장이 바뀌었다.** 물기는 이제 빈 원뿔에도 반드시 휘두른다(`Swarm.bite`가 무조건
	# true), 그래서 `not fire(...)`로는 사거리를 잴 수 없다. 재는 것은 그대로 사거리이고, 재는 방법이
	# **먹이가 살아남았다**로 바뀌었다. 헛스윙이 쿨다운을 무는지도 같이 못 박는다 — 그게 없으면 "휘두르긴
	# 했다"가 아무것도 하지 않은 것과 구별되지 않는다.
	t.ok(far_b.fire(0, Vector2(1400.0, 1000.0)), "설정: 빈 원뿔에도 좌클릭은 헛스윙으로 나간다")
	t.ok(far_b.bound_cd[0] > 0.0, "헛스윙도 쿨다운을 낸다 — 빈 원뿔은 죽은 키가 아니다")
	t.eq(h.alive_count, 1, "정면 한가운데라도 100px는 물리지 않는다 — 사거리는 70px다")

	var rig_behind := _rig(221)
	var behind: Swarm = rig_behind[0]
	var behind_b: Body = rig_behind[1]
	var g := _food_at([Vector2(950.0, 1000.0)])
	behind.step(DT, g)
	t.eq(g.alive_count, 1, "설정: 등 뒤 먹이가 아직 살아 있다")
	t.ok(behind_b.fire(0, Vector2(1400.0, 1000.0)), "설정: 등 뒤여도 좌클릭은 헛스윙으로 나간다")
	t.ok(behind_b.bound_cd[0] > 0.0, "그 헛스윙도 쿨다운을 낸다")
	t.eq(g.alive_count, 1, "같은 거리라도 등 뒤 먹이는 물리지 않는다 — 각도가 실력이다")

	# 23: the cooldown is a real refusal, and it expires. **`Body.step()` is what ticks it now** — left to
	# `Swarm.step()` the number never comes down and the second bite below never lands. 32 frames is
	# 0.533s, past 물기's own 0.5; a literal, because `Parts.COOLDOWN[BITE] / DT` scales with the value it
	# is meant to pin.
	t.ok(not b.fire(0, Vector2(1400.0, 1000.0)), "쿨다운 안의 두 번째 물기는 거부된다")
	t.eq(f.alive_count, 3, "거부당한 물기로는 먹이가 죽지 않는다")
	for _s in 32:
		b.step(DT)
		sw.step(DT, f)
	t.ok(b.fire(0, Vector2(1400.0, 1000.0)), "쿨다운이 지나면 다시 문다")
	t.eq(f.alive_count, 2, "그때 하나가 더 사라진다")

	# 24: `space` takes movement parts only, and the refusal leaves the key alone.
	var rig_d := _rig(24)
	var sw_d: Swarm = rig_d[0]
	var d: Body = rig_d[1]
	t.eq(d.bound[Body.KEY_MOVEMENT], Parts.DASH, "설정: 스페이스는 짧은 숨을 들고 열린다")
	t.ok(d.fire(Body.KEY_MOVEMENT, Vector2(1400.0, 1000.0)), "스페이스가 대시를 낸다")
	t.ok(sw_d.dash_left > 0.0, "실제로 대시 상태가 됐다")
	t.ok(not d.bind(Parts.BITE, Body.KEY_MOVEMENT), "스페이스는 움직이지 않는 것을 거부한다")
	t.eq(d.bound[Body.KEY_MOVEMENT], Parts.DASH, "거부당한 뒤에도 스페이스에는 짧은 숨이 그대로다")

	# 25: **binding has to reach behaviour.** Asserting that `bound[1]` changed is asserting that a field
	# moved; the empty key is fired before and after so the bind is what the food died of.
	var rig_e := _rig(25)
	var sw_e: Swarm = rig_e[0]
	var e: Body = rig_e[1]
	var fe := _food_at([Vector2(1050.0, 1000.0)])
	sw_e.step(DT, fe)
	t.eq(e.bound[1], -1, "설정: 우클릭은 빈 칸으로 열린다 — 0이 아니라 -1이다 (0은 물기다)")
	t.ok(not e.fire(1, Vector2(1400.0, 1000.0)), "빈 칸은 아무 일도 하지 않는다")
	t.eq(fe.alive_count, 1, "빈 칸이 먹이를 죽이지도 않는다")
	t.ok(e.bind(Parts.BITE, 1), "우클릭에 물기를 넣는다")
	t.ok(e.fire(1, Vector2(1400.0, 1000.0)), "묶은 뒤에는 우클릭이 실제로 문다")
	t.eq(fe.alive_count, 0, "묶기가 행동까지 닿는다 — 필드만 옮긴 것이 아니다")
	t.eq(e.bound[0], Parts.BITE, "좌클릭은 제 것을 그대로 갖고 있다 — 묶기는 옮기기가 아니라 복사다")


# -- 25b: the panel actually binds, through the real click path -----------------------------------------
## ⚠ **The whole `BodyPanel` → shell → `Swarm` chain had no caller anywhere in `tests/`.** `_gui_input`,
## `_row_at`, `refuse()`, `REFUSAL` and `main.gd`'s `body.bind_requested.connect(...)` line were driven by
## nothing: the connect line replaced with `pass` left the round green while the player clicked two rows,
## nothing bound, and no message appeared. Check 25 drives `Swarm.bind()` directly and is the sim half.
##
## **Clicks go through `t.root.push_input(...)`, the real hit test.** Calling `_gui_input()` by hand skips
## `mouse_filter` entirely, so a panel silently set to `MOUSE_FILTER_IGNORE` would still pass — the same
## reason `net_screens` drives its buttons this way.
func _c25b_bind_driven(t) -> void:
	var m := MainSpy.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group below.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		var w: World = m.run.world
		var bd: Body = w.body
		# `main.gd`'s own `body` field is the PANEL and `World.body` is the `Body` — the same word for two
		# things, on purpose. Missing the shell's `body.world = run.world` line leaves the panel drawing
		# literally nothing on every `Tab` while the pause and toggle checks all stay green.
		t.ok(m.body.world == w, "설정: 몸 창이 이 런의 세상을 가리킨다 (같은 인스턴스)")
		bd.wear(Parts.HORSE_LEGS)
		m.body.open()
		await t.pump_frames(2)
		t.eq(m.body.size, Vector2(1280.0, 720.0),
				"설정: 몸 창이 화면 전체를 덮는다 — 아래 클릭 좌표가 이것을 전제한다")
		t.eq(bd.bound[1], -1, "설정: 우클릭 줄은 빈 칸으로 열린다")

		# An EMPTY square and an EMPTY row both hand out nothing and must not light up as picked up.
		# Latched unconditionally, the empty 우클릭 row highlighted with nothing in hand and the player's
		# next click TOOK from the row they meant to drop onto — two clicks, no bind, no refusal, and the
		# panel looking like it worked. **Plan 3 creates eleven of the empty case, so it is driven too.**
		t.root.push_input(_click_at(m.body._slot_rect_of(Parts.Slot.HEAD).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, -1, "빈 칸을 눌러도 손에 들리는 것은 없다")
		t.eq(m.body._held_slot, -1, "그리고 그 칸이 '집었다'로 켜지지도 않는다")
		t.root.push_input(_click_at(m.body._row_rect_of(1).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, -1, "빈 줄을 눌러도 손에 들리는 것은 없다")
		t.eq(m.body._held_row, -1, "그리고 그 줄이 켜지지도 않는다")

		# (a) **plan 3's model: a worn square is the source.** 뒷다리 칸을 누르고, 우클릭 줄에 놓는다.
		t.root.push_input(_click_at(m.body._slot_rect_of(Parts.Slot.HINDLIMBS).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, Parts.HORSE_LEGS, "입은 부품이 든 칸을 누르면 그것이 손에 들린다")
		t.eq(m.body._held_slot, Parts.Slot.HINDLIMBS, "그리고 그 칸이 집힌 것으로 켜진다")
		t.root.push_input(_click_at(m.body._row_rect_of(1).get_center()), true)
		await t.pump_frames(1)
		t.eq(bd.bound[1], Parts.HORSE_LEGS, "칸 하나와 줄 하나를 실제로 눌러 우클릭에 말 다리가 들어간다")
		t.eq(bd.slot_part[Parts.Slot.HINDLIMBS], Parts.HORSE_LEGS,
				"집어온 칸은 제 것을 그대로 갖고 있다 — 묶기는 옮기기가 아니라 복사다")
		# The same standard as check 25: a bind that only moved a field is not a bind. 갤럽 is HELD, not
		# fired, so the key is held for one frame and the host's speed multiplier is what answers.
		bd.held[1] = 1
		bd.step(DT)
		t.ok(absf(w.swarm.active_speed_mul - 1.1) < 0.001,
				"묶은 뒤 우클릭을 누르고 있으면 실제로 갤럽이 돈다 (%.3f)" % w.swarm.active_speed_mul)
		bd.held[1] = 0

		# (b) a key row is still a source too — plan 2's model, unchanged.
		t.root.push_input(_click_at(m.body._row_rect_of(Body.KEY_MOVEMENT).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, Parts.DASH, "스페이스 줄을 누르면 짧은 숨이 손에 들린다")
		t.root.push_input(_click_at(m.body._row_rect_of(1).get_center()), true)
		await t.pump_frames(1)
		t.eq(bd.bound[1], Parts.DASH, "줄 둘을 실제로 눌러 우클릭에 짧은 숨이 들어간다")
		t.ok(bd.fire(1, Vector2(1400.0, 1000.0)), "묶은 뒤 우클릭이 실제로 대시를 낸다")
		t.ok(w.swarm.dash_left > 0.0, "그리고 진짜 대시 상태가 됐다")
		t.eq(bd.bound[Body.KEY_MOVEMENT], Parts.DASH, "집어온 줄도 제 것을 그대로 갖고 있다")

		# A PASSIVE square must not be picked up at all — the panel asks `Body.can_bind()` before it will
		# hand anything out, so a part `space` would refuse can never even be dropped on it.
		bd.wear(Parts.HORSE_MANE)
		t.root.push_input(_click_at(m.body._slot_rect_of(Parts.Slot.TORSO).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, -1, "패시브가 든 칸은 집히지 않는다 — 패널이 sim에게 먼저 묻는다")

		# The negative control comes BEFORE the refusal, on purpose: the refusal line survives on screen
		# until something clears it, so "no refusal was drawn" after one would measure nothing.
		m.panel_spy.texts.clear()
		t.root.push_input(_click_at(Vector2(640.0, 40.0)), true)
		await t.pump_frames(2)
		t.eq(bd.bound[1], Parts.DASH, "부정 대조: 빈 자리를 눌러도 묶인 것이 바뀌지 않는다")
		t.ok(not _has_line(m.panel_spy.texts, BodyPanel.REFUSAL),
				"부정 대조: 아무 줄도 안 눌렀으면 거부 문구도 없다")

		# 좌클릭의 물기를 스페이스에 놓으려 하면 거부당한다 — 규칙은 sim, 문구는 화면.
		m.panel_spy.texts.clear()
		t.root.push_input(_click_at(m.body._row_rect_of(0).get_center()), true)
		await t.pump_frames(1)
		t.eq(m.body._held, Parts.BITE, "설정: 좌클릭 줄에서 물기를 집었다")
		t.root.push_input(_click_at(m.body._row_rect_of(Body.KEY_MOVEMENT).get_center()), true)
		await t.pump_frames(2)
		t.eq(bd.bound[Body.KEY_MOVEMENT], Parts.DASH,
				"스페이스는 물기를 거부하고 짧은 숨을 그대로 지킨다")
		t.ok(_has_line(m.panel_spy.texts, BodyPanel.REFUSAL),
				"거부는 화면에 한 줄로 나온다 %s" % str(m.panel_spy.texts))

	t.root.remove_child(m)
	m.queue_free()


# -- 26 / 30 / 31: the panel pauses, Esc closes it, and it drops the charge ------------------------------
func _c26_c30_c31_panel(t) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded: without it every line below crashes on a null world and buries the one check that named the
	# real problem — the same shape `net_shell` guards for.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		var sw: Swarm = m.run.world.swarm

		# 26: **both ends.** A pause asserted only while the panel is open passes for a panel that never
		# closes, which is a run the player can never get back.
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(m.body.visible, "Tab이 몸 창을 연다")
		t.ok(m.run.paused, "몸 창이 열려 있는 동안 런은 정지 상태다")
		var e0: float = m.run.world.elapsed
		await t.pump_frames(5)
		t.eq(m.run.world.elapsed, e0, "정지 중에는 세상의 시간이 흐르지 않는다")
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(not m.body.visible, "Tab을 다시 누르면 닫힌다")
		t.ok(not m.run.paused, "닫으면 정지가 풀린다")
		t.ok(m.run.world.elapsed > e0, "닫은 뒤 세상의 시간이 다시 흐른다 (%.3f → %.3f)"
				% [e0, m.run.world.elapsed])

		# 30: Esc in PLAY closes the panel and does nothing else. It is not a pause, not a quit, not a menu.
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(1)
		t.ok(m.body.visible, "설정: 몸 창이 다시 열려 있다")
		m._unhandled_key_input(_esc())
		await t.pump_frames(1)
		t.ok(not m.body.visible, "PLAY에서 Esc가 몸 창을 닫는다")
		t.eq(m.run.phase, Run.Phase.PLAY, "Esc로 런이 끝나지는 않는다")

		# 31: the wind-up is DROPPED when a panel opens, not paused. Resuming a charge across a menu is a
		# decision the player never made.
		sw.split_charge = Rules.SPLIT_HOLD_TIME * 0.9
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(1)
		t.eq(sw.split_charge, 0.0, "창이 열리면 감기던 F가 버려진다")
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(1)
		var count_before: int = sw.count
		Input.action_press("split")
		await t.pump_frames(3)
		Input.action_release("split")
		t.ok(sw.split_charge > 0.0, "설정: 다시 누른 F가 실제로 감기고 있다 (%.3f)" % sw.split_charge)
		t.ok(sw.split_charge < Rules.SPLIT_HOLD_TIME * 0.9,
				"감김은 0에서 다시 시작한다 — 창을 닫아도 이어지지 않는다 (%.3f)" % sw.split_charge)
		t.eq(sw.count, count_before, "그래서 창을 닫자마자 갈라지지도 않는다")
		await t.pump_frames(1)

	t.root.remove_child(m)
	m.queue_free()


# -- 27: the panel's rectangles, driven and captured ----------------------------------------------------
## ⚠ **Attack the check first.** Asserting the rectangles against the panel's own `size` shrinks the test
## with the panel: a `Control` on a bare `CanvasLayer` keeps `size == (0, 0)` unless the preset sets
## offsets, every rectangle collapses into the top-left corner, and a size-relative check stays green. So
## the bound is the literal viewport, and zero-sized rectangles are counted separately — a hook handed a
## bare `Rect2()` has to make this red.
func _c27_panel_rects(t) -> void:
	var screen := Vector2(1280.0, 720.0)
	var m := MainSpy.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group above.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		t.eq(m.get_viewport().get_visible_rect().size, screen, "설정: 화면이 1280x720이다")
		m.body.open()
		await t.pump_frames(2)
		t.ok(m.body.visible, "설정: 몸 창이 실제로 보인다")
		t.eq(m.body.size, screen, "몸 창이 화면 전체 크기를 갖는다 (0 크기면 전부 왼쪽 위로 몰린다)")

		var rects: Array = m.panel_spy.rects
		# One backdrop + eleven slots (fill + edge) + three rows (fill + edge) = 29, EXACTLY. A floor of
		# ">= 29" stops bounding anything the moment the slots start drawing what is in them.
		t.eq(rects.size(), 29, "패널이 그리는 사각형은 정확히 29개다 (바탕 1 + 칸 11×2 + 줄 3×2)")
		var empty := 0
		var outside := 0
		for r: Rect2 in rects:
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				empty += 1
			if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > screen.x or r.end.y > screen.y:
				outside += 1
		t.eq(empty, 0, "빈 Rect2()로 그려진 사각형이 하나도 없다")
		t.eq(outside, 0, "모든 사각형이 1280x720 안에 들어 있다")

		# The two halves are actually two halves — one column left of centre, one right. Without this the
		# whole panel could be one pile and every bound above would still hold.
		#
		# ⚠ **Picked out of what was CAPTURED, never out of `_slot_rect_of`/`_row_rect_of`.** Measuring a
		# pure layout function is not measuring that anything calls it: `_paint`'s slot loop rewritten to
		# `_paint_slot(c, _row_rect_of(k % 3))` leaves both functions returning a left and a right column,
		# every drawn rect non-empty and inside 1280x720, and the count unchanged — eleven slots stacked on
		# top of three key rows, reported as two halves.
		#
		# ⚠ **And the MATCH COUNTS are asserted first.** With `slot_right` starting at `INF`, zero matches
		# made `row_left > 640` pass and `slot_right < 640` fail — the half that catches a regression and
		# the half that hides one sat on consecutive lines. The size to classify by is `BODY_SLOT_SIZE`,
		# the panel's own square; `Look.SLOT_SIZE` is the ending screen's summary strip and matches nothing
		# here.
		var slot_right := -INF
		var slots_seen := 0
		var row_left := INF
		var rows_seen := 0
		for r: Rect2 in rects:
			if r.size == Look.BODY_SLOT_SIZE:
				slots_seen += 1
				slot_right = maxf(slot_right, r.end.x)
			elif r.size == Look.BODY_ROW_SIZE:
				rows_seen += 1
				row_left = minf(row_left, r.position.x)
		t.eq(slots_seen, 22, "칸 열하나가 배경·테두리 두 번씩 그려졌다")
		t.eq(rows_seen, 6, "줄 셋이 배경·테두리 두 번씩 그려졌다")
		t.ok(slot_right < screen.x * 0.5, "가장 오른쪽 칸까지도 왼쪽 절반 안에 있다 (%.0f)" % slot_right)
		t.ok(row_left > screen.x * 0.5, "그려진 손의 줄들이 오른쪽 절반에 있다 (%.0f)" % row_left)

		# **The panel's TEXT, from the same driven capture.** Only its rectangles were read here, so
		# `Parts.NAME[body.bound[key]]` could be replaced with a constant and every row would name the
		# wrong part with check 27 green. Read through the table's own owner, not as re-typed Korean.
		var texts: Array = m.panel_spy.texts
		t.eq(texts.size(), 11, "빈 몸이 적는 글자는 열하나다 (몸·겉·속·숫자줄·손 + 줄 셋의 키 이름과 부품 이름)")
		t.ok(texts.has(str(Parts.NAME[Parts.BITE])), "좌클릭 줄이 물기를 이름으로 적는다 %s" % str(texts))
		t.ok(texts.has(BodyPanel.EMPTY_LABEL), "우클릭 줄이 빈 칸이라고 적는다")
		# ⚠ `-1` is a LEGAL index in GDScript and counts from the END, so a bare `Parts.NAME[bound[key]]`
		# would print the last row — 말 폐활량 — on the empty key, with no error and nothing red.
		t.ok(not texts.has(str(Parts.NAME[Parts.HORSE_LUNG])),
				"그 자리에 표의 마지막 행(말 폐활량)이 나오지 않는다 — -1을 뒤에서 세지 않았다")
		t.ok(texts.has(str(Parts.NAME[Parts.DASH])), "스페이스 줄이 짧은 숨을 적는다")
		t.ok(texts.has(BodyPanel.KEY_LABELS[Body.KEY_MOVEMENT]), "키 이름표도 그려진다 (스페이스)")
		t.ok(texts.has(BodyPanel.GROUP_LABELS[0]) and texts.has(BodyPanel.GROUP_LABELS[1]),
				"겉과 속이 두 무리의 머리말로 나온다 — 열한 칸이 한 줄로 붙어 있지 않다")

		# **The only place force and HP reach the screen.** `_grow()`'s `force[0] += FORCE_PER_LEVEL` is a
		# level's WHOLE payout, `F` halves every row, and `hp_max()`'s ceiling grows with parts — none of it
		# was drawn anywhere, which is the signature fake inverted (the simulation moves, the picture does
		# not). Three different literals, so a panel printing one number three times cannot pass.
		m.run.world.swarm.force[0] = 37
		m.run.world.swarm.add_clone(0, 5)
		m.run.world.host_hp = 2
		m.panel_spy.texts.clear()
		m.body.queue_redraw()
		await t.pump_frames(1)
		var force_line := ""
		for l: String in m.panel_spy.texts:
			if l.contains("힘"):
				force_line = l
		t.ok(force_line.contains("37"), "몸 창이 호스트의 힘을 적는다 — %s" % force_line)
		t.ok(force_line.contains("42"), "무리 전체의 힘(37+5)도 함께 적는다 — %s" % force_line)
		t.ok(force_line.contains("2/30"), "현재/최대 체력도 그 줄에 함께 적힌다 — %s" % force_line)
		t.ok(not force_line.contains("방어"),
				"방어라는 별도의 숫자는 없다 — '접촉 한 번 더'와 '최대 체력 +1'은 같은 문장이다")

		# **A worn square shows what is in it, and its level.** Eleven empty squares was plan 2's picture;
		# this is the one thing plan 3 puts on this screen.
		m.run.world.body.wear(Parts.HORSE_LEGS)
		m.run.world.body.wear(Parts.HORSE_LEGS)
		m.run.world.body.wear(Parts.HORSE_MANE)
		m.panel_spy.rects.clear()
		m.panel_spy.texts.clear()
		m.body.queue_redraw()
		await t.pump_frames(1)
		t.ok(m.panel_spy.texts.has(str(Parts.NAME[Parts.HORSE_LEGS])),
				"입은 부품의 이름이 제 칸에 적힌다 %s" % str(m.panel_spy.texts))
		t.ok(m.panel_spy.texts.has("Lv2"), "그리고 Lv2가 그 칸에 함께 적힌다")
		t.ok(not m.panel_spy.texts.has("Lv1"),
				"Lv1은 적지 않는다 — 모든 칸에 아무 말도 아닌 숫자를 붙이지 않는다")
		t.eq(m.panel_spy.rects.size(), 29, "칸이 채워져도 사각형 수는 그대로 29개다")

		# ⚠ **The HP CEILING, driven above its floor.** `2/30` above is taken at `level == 0` on an empty
		# body, where `hp_max(0)` is exactly `Rules.HOST_HP` — so both things that add to the ceiling (a
		# level, and 말 갈기's HP) are absent at that moment and the panel could print a constant 30 forever.
		# Measured: `b.hp_max(world.level)` replaced with `Rules.HOST_HP` left 811 checks green, and a maned,
		# levelled host would read 5/30 here while the HUD prints a different ceiling beside it. 말 갈기 is
		# worn twenty lines above; only the level is new, and 30 + 2×3 + 5 is a literal.
		m.run.world.level = 2
		m.panel_spy.texts.clear()
		m.body.queue_redraw()
		await t.pump_frames(1)
		var hp_line := ""
		for l: String in m.panel_spy.texts:
			if l.contains("체력"):
				hp_line = l
		t.ok(hp_line.contains("2/41"),
				"레벨 둘에 갈기 하나면 몸 창의 체력은 2/41이다 (30 + 6 + 5, 리터럴) — %s" % hp_line)

	t.root.remove_child(m)
	m.queue_free()


# -- 28 / 29: the input gate, pressed for real ----------------------------------------------------------
## The mutation this exists for is narrowing the gate back to `pending_levels == 0`: the cards would still
## be covered and the body panel would not, so both panels are driven. And the same eight presses are made
## with nothing open, because "nothing changed" is what a broken press looks like too.
func _c28_c29_gate(t) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group above.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		var w: World = m.run.world
		var sw: Swarm = w.swarm
		for _i in 3:
			sw.add_clone(0, 2)
		# ⚠ **The two mouse buttons were the two this check could not see.** `fire_1` opens empty and does
		# nothing by construction, and with every food spot silenced a leaked `fire_0` finds no candidate
		# and returns false without touching one field in `_snapshot` — so narrowing the gate to let both
		# mouse buttons through stayed green, and the mouse is exactly what a player clicks while a panel
		# is up. Bound and fed, both are now observable.
		w.body.bind(Parts.BITE, 1)
		_ring_food(m)
		await t.pump_frames(2)   ## one real world step, so `bite()` has a `_food` and a food grid to read
		# **The card pool has to be opened by hand.** Nothing in plan 3 writes `species_eaten` — corpses
		# are plan 4's — so a real run banks every level forever and the cards half of this gate would
		# never open at all.
		w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
		sw.banked = Rules.LEVEL_COST_BASE
		await t.pump_frames(3)
		t.ok(m.cards.visible, "설정: 레벨이 올라 카드가 실제로 떠 있다")
		t.eq(_ring_alive(m), 12, "설정: 원뿔 안 먹이 열둘이 아직 살아 있다")

		# 28a: the cards are up.
		var before_cards := _snapshot(m)
		await _press_all(t)
		t.eq(_snapshot(m), before_cards, "카드가 떠 있으면 여덟 키 어느 것도 세상을 바꾸지 않는다")

		# 29: one panel at a time. The cards are not dismissable, so a stack of two pauses has no owner.
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(not m.body.visible, "카드가 떠 있는 동안에는 Tab이 몸 창을 열지 않는다")
		t.ok(m.cards.visible, "그리고 카드는 그대로 떠 있다")

		# ⚠ **Bounded, and it breaks on an empty offer.** Written as a bare `while pending_levels > 0`,
		# an empty pool makes `offer[0]` an out-of-bounds read, `take_card` returns false, and the level
		# never decrements — the net does not go red, it SPINS FOREVER, and neither the runner nor the
		# wrapper has a per-net timeout.
		var guard := 0
		while m.run.world.pending_levels > 0 and guard < 20:
			guard += 1
			if m.run.world.offer.is_empty():
				break
			m.cards.picked.emit(m.run.world.offer[0])
			await t.pump_frames(1)
		t.ok(guard < 20, "카드를 스무 번 안에 다 골랐다 — 빈 제시로 영원히 돌지 않는다 (%d)" % guard)
		await t.pump_frames(2)
		t.ok(not m.cards.visible, "설정: 카드를 다 골라 창이 닫혔다")

		# 28b: the body panel is up. This is the half that catches a gate narrowed back to `pending_levels`.
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(m.body.visible, "설정: 몸 창이 열려 있다")
		var before_body := _snapshot(m)
		await _press_all(t)
		t.eq(_snapshot(m), before_body, "몸 창이 떠 있어도 여덟 키 어느 것도 세상을 바꾸지 않는다")
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(not m.body.visible, "설정: 몸 창을 닫았다")

		# 28c: the control. Three named effects, not "something moved" — the four keys they belong to are
		# the ones a dead press would silently swallow.
		for _i in 3:
			sw.add_clone(0, 2)
		var strike_before := sw.strike_point
		var count_before := sw.count
		var ring_before := _ring_alive(m)
		await _press_all(t)
		t.ok(sw.strike_point != strike_before, "대조: 아무 창도 없으면 3이 실제로 지점을 옮긴다")
		# `dash_cd` is gone — `Body.bound_cd[key]` is the ONE cooldown now, so the two numbers that could
		# disagree about whether the hand is free are one number. The burst itself is 0.16s and the presses
		# below it take longer than that, so the cooldown is what is still standing when this is read.
		t.ok(sw.dash_left > 0.0 or w.body.bound_cd[Body.KEY_MOVEMENT] > 0.0,
				"대조: 스페이스가 실제로 대시를 낸다")
		t.ok(sw.count < count_before, "대조: V가 실제로 곁의 분신을 거둬들인다 (%d → %d)"
				% [count_before, sw.count])
		# Counted over the ring's own twelve indices, never `food.alive_count`: respawn revives other dead
		# spots every second, so the global count can rise while these die. A consumed spot carries a
		# 12-second cooldown, so none of these twelve can come back inside the test.
		t.ok(_ring_alive(m) < ring_before,
				"대조: 좌·우클릭이 실제로 원뿔 안 먹이를 문다 (%d → %d)" % [ring_before, _ring_alive(m)])

	t.root.remove_child(m)
	m.queue_free()


# -- the HOLD, driven through the real keyboard ---------------------------------------------------------
## ⚠ **The one line that connects a key to a SUSTAINED active had no caller anywhere in `tests/`.**
## `Body.fire()` returns false for a sustained part by construction, so `held` is 갤럽's ONLY path into the
## sim — and every `held` write in the round was by hand (eight sites in `net_body`, one in `_c25b` above).
## `_c28_c29_gate` presses `fire_2` for real, but `space` there holds 짧은 숨, whose `SUSTAINED` is 0, so no
## shell-driven path could ever reach `Body.step()`'s sustain branch. Measured: `main.gd`'s
## `b.held[key] = 1 if Input.is_action_pressed(action) else 0` replaced with `b.held[key] = 0` left 811
## checks green while 말 다리 — this plan's headline mechanic — was a dead key in the real game.
##
## **The second half is the panel-open drop**, `run.world.body.held.fill(0)`, which had the same problem
## for the same reason: with nothing sustained ever bound through the shell, a gallop latched across a menu
## was invisible too. Its own comment calls it "the third poll, and it is the one plan 3 added".
func _c_sustain_through_the_shell(t) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group above.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		var w: World = m.run.world
		var bd: Body = w.body
		bd.wear(Parts.HORSE_LEGS)
		t.ok(bd.bind(Parts.HORSE_LEGS, Body.KEY_MOVEMENT), "설정: 말 다리를 스페이스에 묶었다")
		await t.pump_frames(2)
		t.eq(bd.held[Body.KEY_MOVEMENT], 0, "설정: 아무 키도 안 눌린 동안에는 0이다")
		t.eq(w.swarm.active_speed_mul, 1.0, "설정: 그래서 아직 갤럽이 돌지 않는다")
		var breath0: float = bd.breath

		Input.action_press("fire_2")
		await t.pump_frames(3)
		t.eq(bd.held[Body.KEY_MOVEMENT], 1, "누르고 있으면 셸이 그것을 몸에 적는다")
		t.ok(absf(w.swarm.active_speed_mul - 1.1) < 0.001,
				"그래서 실제 게임에서 갤럽이 돈다 (%.3f)" % w.swarm.active_speed_mul)
		t.ok(bd.breath < breath0, "그리고 숨이 실제로 닳는다 (%.3f → %.3f)" % [breath0, bd.breath])

		# The panel-open drop, with the key still physically down. A poll left alone keeps its last value,
		# so the gallop would sit latched behind the pause and be running again the frame the panel closes.
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(m.body.visible, "설정: 누른 채로 몸 창을 열었다")
		t.eq(bd.held[Body.KEY_MOVEMENT], 0,
				"창이 열리면 누르고 있던 것도 버려진다 — 메뉴 너머로 갤럽이 걸려 있지 않다")
		m._unhandled_key_input(_key(KEY_TAB))
		await t.pump_frames(2)
		t.ok(not m.body.visible, "설정: 창을 다시 닫았다")
		t.eq(bd.held[Body.KEY_MOVEMENT], 1, "닫으면 여전히 눌려 있던 키가 다시 읽힌다")

		# And releasing is what stops it — "held" has to be a poll, not a latch of its own.
		Input.action_release("fire_2")
		await t.pump_frames(3)
		t.eq(bd.held[Body.KEY_MOVEMENT], 0, "손을 떼면 0으로 돌아온다")
		t.eq(w.swarm.active_speed_mul, 1.0, "그리고 갤럽이 실제로 멈춘다")

	t.root.remove_child(m)
	m.queue_free()


# -- 32: the only instruction the player ever gets ------------------------------------------------------
## Captured through `_paint_text`, never grepped: a legend asserted by reading the file measures its
## letters and not what reached the screen.
func _c32_legend(t) -> void:
	var w := World.new()
	w.setup(32)
	var spy := HudSpy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.lines.clear()
	await t.pump_frames(1)

	var legend := ""
	for l: String in spy.lines:
		if l.contains("WASD"):
			legend = l
	t.ok(legend != "", "안내줄이 실제로 화면에 그려졌다 %s" % str(spy.lines))
	t.ok(legend.contains("F 나누기"), "안내줄이 F를 알려준다 — %s" % legend)
	t.ok(legend.contains("V 모으기"), "안내줄이 V를 알려준다")
	t.ok(legend.contains("3 보내기"), "안내줄이 3을 알려준다")
	t.ok(not legend.contains("대시"), "옛 안내줄(Space 대시)이 남아 있지 않다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- S1: the shell's click reaches `World.fire`, not `Body.fire` ---------------------------------------
## ⚠ **`main.gd`'s one key line could say `body.fire(key, aim)` and nothing anywhere would notice.** Both
## calls return a bool, both put the key on its cooldown, both make the cone appear on screen; only
## `World.fire()` goes on to dispatch `strike()`, which is the entire damage path for every key a player
## will ever press. Measured on this build: the shell was rewired to the `World` and the round stayed at
## **1032 checks, unmoved** — not one net drove a key into a creature, so left click drawing a cone that
## hurts nothing was a bug no amount of green could see. This is the five-minutes-of-play class.
##
## The key is pressed for real through `Input` and the assertion is the creature's own hp. Nothing here
## calls `fire()` by hand: a check that does is measuring `World`, which `net_force` already does, and not
## the line in the shell.
func _s1_click_reaches_the_world(t) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group above. `m.run.world` is dereferenced immediately below.
	if m.run.phase == Run.Phase.PLAY:
		_quiet(m)
		var w: World = m.run.world
		_clear_terrain(w)
		# `_quiet` empties the creature table and leaves `boss_index` pointing into it; the arrays are
		# preallocated, so the arena step would read a stranger's position rather than fail.
		w.boss_index = -1
		# The camera is parked on the host so the world point under the (headless, never-moved) mouse
		# stops drifting between the frame the crow is placed and the frame the key is read.
		m.cam.position = w.swarm.pos[0]
		await t.pump_frames(1)

		t.eq(w.body.bound[0], Parts.BITE, "설정: 좌클릭에 물기가 묶여 있다")
		# The aim the shell really passes is `get_global_mouse_position()`, so the crow is put on THAT ray
		# instead of on a heading picked here — a check that pins its own heading is measuring the mouse.
		var host: Vector2 = w.swarm.pos[0]
		var to_aim: Vector2 = m.get_global_mouse_position() - host
		var dir := Vector2.RIGHT if to_aim.length_squared() < 0.0001 else to_aim.normalized()
		w.critter_count = 1
		# 40px: inside `Parts.RANGE[Parts.BITE]` (70) and outside contact reach (crow 15 + BODY_RADIUS 14),
		# so the only thing that can move this crow's hp is the click.
		w.critter_pos[0] = host + dir * 40.0
		w.critter_dir[0] = Vector2.RIGHT
		w.critter_species[0] = Parts.Species.CROW
		w.critter_force[0] = 10
		w.critter_hp[0] = 30
		w.critter_flees[0] = 0
		w.critter_atk_cd[0] = 0.0
		w.critter_counter[0] = 0.0
		# A number no default produces. A bite deals the ATTACKER's force, so 30 - 7 = 23 pins that too, on
		# the path a player's finger actually takes — `FORCE_START` 10 would leave 20 and 20 is also what
		# two levels or a stray part would land on.
		w.swarm.force[0] = 7

		Input.action_press("fire_0")
		await t.pump_frames(2)
		Input.action_release("fire_0")
		# The two failures are told apart on purpose: a key that never reached the sim at all and a key
		# that reached it and dealt nothing look identical from the creature's hp alone.
		t.ok(w.body.bound_cd[0] > 0.0, "설정: 좌클릭이 실제로 나갔다 (쿨다운이 걸렸다)")
		t.eq(w.critter_hp[0], 23, "셸의 좌클릭이 앞에 선 까마귀를 실제로 깎는다 (30 - 호스트 힘 7)")

	t.root.remove_child(m)
	m.queue_free()


# -- S2: the HUD's camera rectangle is the TRUE one, and it is cleared with the world -------------------
## ⚠ **The padded rect and the true rect are one assignment apart and the screen never says which it got.**
## `_camera_rect()` is 20% larger so `FieldView` keeps drawing a body about to walk on screen; anything
## that draws a camera box from it draws one a fifth too big in both axes, which reads as "roughly right"
## rather than as a bug. So the size is asserted against the viewport over the zoom, **and against
## `view.view_rect` as the padded control** — without the second half a check could pass on a rect that
## happens to be near enough.
##
## The second claim is the reset. `_process` writes this field only inside the PLAY branch, so a run that
## goes back to TITLE without the `_bind_world()` line keeps drawing the dead run's camera box, and every
## visibility check in the round stays green through it.
func _s2_hud_camera_rect(t) -> void:
	var m: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(2)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see the note in the panel group above.
	if m.run.phase == Run.Phase.PLAY:
		t.eq(m.get_viewport().get_visible_rect().size, Vector2(1280.0, 720.0), "설정: 화면이 1280x720이다")
		# Read AFTER the frame, in the same order `_process` writes them: `_apply_zoom` sets `cam.zoom`
		# and `_follow_camera` sets `cam.position` before the rect is built, so this is that frame's pair
		# and not the previous frame's.
		var vp: Vector2 = m.get_viewport_rect().size / m.cam.zoom.x
		t.ok(vp.x > 0.0, "설정: 줌이 실제로 걸려 있다 (%.1f)" % m.cam.zoom.x)
		t.ok(m.hud.camera_rect.size.is_equal_approx(vp),
				"HUD가 받는 사각형은 화면 그대로다 — 20%% 여유가 붙지 않았다 %s vs %s"
						% [str(m.hud.camera_rect.size), str(vp)])
		t.ok(m.hud.camera_rect.position.is_equal_approx(m.cam.position - vp * 0.5),
				"그 사각형은 카메라를 한가운데 두고 있다 %s" % str(m.hud.camera_rect.position))
		# The padded one, as the control. Both are written in the same `_process`, so if the HUD were
		# handed `_camera_rect()` these two would be identical instead of 1.2 apart.
		t.ok(m.view.view_rect.size.is_equal_approx(vp * 1.2),
				"설정: 컬링용 사각형은 여전히 1.2배다 %s" % str(m.view.view_rect.size))
		t.ok(m.hud.camera_rect != m.view.view_rect, "그래서 둘은 같은 사각형이 아니다")

		m.ending.title_pressed.emit()
		await t.pump_frames(2)
		t.eq(m.run.phase, Run.Phase.TITLE, "설정: 제목으로 돌아왔다")
		# TITLE never enters the PLAY branch, so a missing reset is not merely one stale frame — it is the
		# dead run's camera box standing on the title screen and on the next run's first frame.
		t.eq(m.hud.camera_rect, Rect2(), "제목으로 돌아가면 카메라 사각형도 world와 함께 비워진다")

	t.root.remove_child(m)
	m.queue_free()


# -- helpers --------------------------------------------------------------------------------------------

## ⚠ **Any check here that pins a body or a creature at a LITERAL coordinate needs this.** `Swarm.place()`
## and `_step_critters` both push out of rocks, and the shell rolls a **fresh seed** on every `start()`, so
## a hand-placed row lands where it was put on the runs where no rock is there and a few px off on the
## runs where one is. `net_shell` measured that as one round red and the next green with nothing but the
## ground changing.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()

## A host wired exactly the way `World.setup()` wires it — `body.setup()` then `body.swarm = swarm`, in
## that order. Building a whole `World` for a check about one key would drag five hundred food spots and
## six critters in with it. **`net_body` carries the check that `World.setup()` really makes this wire**,
## so this helper cannot be hiding a missing line in the shell.
func _rig(seed_value: int, at: Vector2 = Vector2(1000.0, 1000.0)) -> Array:
	var sw := Swarm.new()
	sw.setup(seed_value, at)
	var b := Body.new()
	b.setup()
	b.swarm = sw
	return [sw, b]


## Everything the eight keys can reach, in one comparable value. Read as a whole so a key that moves any
## one of them while a panel is up is caught, not only the one somebody thought to assert.
##
## ⚠ **`bound_cd` is in here because the two MOUSE buttons were the two the gate could not see.** Nothing
## else in this array moves for a leaked `fire_0`/`fire_1` when the food is silenced, and the mouse is
## what a player is most likely to be clicking while a panel is up — the exact failure the gate exists to
## prevent. **It now covers `space` too**: `Body.bound_cd[key]` is the one cooldown in the game, so a
## leaked burst sets it exactly as a leaked bite does, and `dash_cd` no longer exists to disagree with it.
##
## `breath` and `active_speed_mul` are in here for the THIRD key's other shape: 갤럽 is held rather than
## fired, and it moves neither the cooldown nor `dash_left`.
func _snapshot(m: Node) -> Array:
	var w: World = m.run.world
	var sw: Swarm = w.swarm
	var states: Array = []
	for i in sw.count:
		states.append(sw.state[i])
	var cds: Array = []
	for s in w.body.bound_cd.size():
		cds.append(w.body.bound_cd[s])
	return [sw.count, sw.strike_point, sw.split_charge, sw.dash_left, sw.active_speed_mul,
			w.body.breath, sw.banked, sw.total_force(), w.food.alive_count, states, cds]


## Presses each action for real and lets the shell's own `_process` see it. Process-local state on the
## `Input` singleton — nothing is injected into the OS and no window is focused.
func _press_all(t) -> void:
	for a: String in ACTIONS:
		Input.action_press(a)
		await t.pump_frames(2)
		Input.action_release(a)
		await t.pump_frames(1)


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


## Esc is read by keycode in the shell, not through an action, so it is built the same way and simply
## matches no action.
func _esc() -> InputEventKey:
	return _key(KEY_ESCAPE)


## Twelve crumbs in a ring 60px out from the host — inside 물기's own reach (the `RANGE` cell of its row in
## the parts table, 70), outside `EAT_RADIUS_HOST` (26), and further than `EAT_RADIUS_CLONE` from any clone
## parked at the rendezvous ring. Spaced 30° apart, so the 70° cone contains at least one of them whichever
## way the headless mouse points and a leaked bite has something to kill.
func _ring_food(m: Node) -> void:
	var w: World = m.run.world
	var host: Vector2 = w.swarm.pos[0]
	for k in 12:
		w.food.pos[k] = host + Vector2(cos(float(k) * TAU / 12.0), sin(float(k) * TAU / 12.0)) * 60.0
		w.food.alive[k] = 1
	w.food.alive_count += 12


func _ring_alive(m: Node) -> int:
	var w: World = m.run.world
	var n := 0
	for k in 12:
		if w.food.alive[k] == 1:
			n += 1
	return n


func _alive_at(f: Food, p: Vector2) -> bool:
	for i in f.pos.size():
		if f.pos[i] == p:
			return f.alive[i] == 1
	return false


func _has_line(lines: Array, needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false


func _click_at(p: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	return ev


func _quiet(m: Node) -> void:
	var w: World = m.run.world
	w.critter_count = 0
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


func _food_at(points: Array) -> Food:
	var f := Food.new()
	f.pos = PackedVector2Array(points)
	f.alive = PackedInt32Array()
	f.timer = PackedFloat32Array()
	f.alive.resize(points.size())
	f.timer.resize(points.size())
	for i in points.size():
		f.alive[i] = 1
		f.timer[i] = 0.0
	f.alive_count = points.size()
	return f


func _mean_to(sw: Swarm, p: Vector2) -> float:
	var sum := 0.0
	for i in range(1, sw.count):
		sum += sw.pos[i].distance_to(p)
	return sum / float(maxi(1, sw.count - 1))
