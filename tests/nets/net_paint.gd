extends RefCounted
## What actually reached the screen.
##
## **"`_draw()` ran" is not "anything was drawn."** `CLAUDE.md` records three features shipped on that
## confusion in a single day, each erasable with thousands of checks still green — and a pure position
## function asserted correct while `_draw()` passed a bare `Rect2()` at the call site, painting at zero
## size. Godot refuses to override a native draw call, so `FieldView` cuts a `_paint_cell()` hook out of
## `_draw()` and this net overrides that and captures every argument.
##
## Driven **treed, with real frames pumped** — calling `_draw()` by hand barks about drawing outside
## NOTIFICATION_DRAW, and a node outside the tree has no viewport to draw into at all.


class Spy extends FieldView:
	var seen: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0) -> void:
		seen.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot)


## The other two leaves in `field_view.gd`. **All three of this plan's new visuals were spied by nothing**
## — the strike marker, the `F` charge arc and the bite cone — and each could be deleted on its own with
## the whole round green: the simulation stays correct, `_draw()` still runs, `_paint_cell` still paints
## every body, stderr is clean. Pure-picture regressions, which is the signature fake, and the strike
## marker is the one the plan predicted in writing ("the feature would vanish with every net green").
class ArcSpy extends FieldView:
	var arcs: Array = []
	var cones: Array = []

	func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
			width: float) -> void:
		arcs.append({"p": p, "r": r, "from": from, "to": to, "width": width})
		super._paint_arc(c, p, r, from, to, col, width)

	func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float, arc: float,
			col: Color) -> void:
		cones.append({"p": p, "dir": dir, "range_px": range_px, "arc": arc})
		super._paint_cone(c, p, dir, range_px, arc, col)


func run(t) -> void:
	await _c_cells(t)
	await _c_strike_marker(t)
	await _c_bite_cone(t)


func _c_cells(t) -> void:
	var w := World.new()
	w.setup(9)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	# Three food at pinned coordinates near the host, so the expected draw count is a number and not a
	# function of the spawner's randomness.
	var host: Vector2 = w.swarm.pos[0]
	for i in 3:
		w.food.pos[i] = host + Vector2(40.0 + i * 20.0, 0.0)
		w.food.alive[i] = 1
	w.food.alive_count = 3
	# The run opens with the host alone, so these four are the whole swarm and the count below is exact.
	for i in 4:
		var k := w.swarm.add_clone()
		w.swarm.pos[k] = host + Vector2(-60.0 - i * 25.0, 30.0)

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	# Cleared and re-pumped: the node draws once per frame it is asked to, so a multi-frame capture would
	# hold two passes and the count assertion below would be measuring frames, not bodies.
	spy.seen.clear()
	await t.pump_frames(1)

	var expect := 1 + w.swarm.count - 1 + w.food.alive_count + w.critter_count
	t.eq(spy.seen.size(), expect, "호스트·분신·먹이·포식자가 전부 그려졌다")

	# The captured position must EQUAL the simulation's, not merely be non-zero: passing Vector2.ZERO for
	# every body is the exact mutation this check exists to catch, and a count-only assertion survives it.
	var host_hit := false
	for e: Dictionary in spy.seen:
		if e["p"] == w.swarm.pos[0] and e["r"] >= Rules.BODY_RADIUS:
			host_hit = true
	t.ok(host_hit, "호스트를 sim 의 좌표 그대로 그렸다")

	var clone_points := {}
	for i in range(1, w.swarm.count):
		for e: Dictionary in spy.seen:
			if e["p"] == w.swarm.pos[i]:
				clone_points[e["p"]] = true
	t.eq(clone_points.size(), w.swarm.count - 1, "분신 넷이 서로 다른 자리에 그려졌다")

	var zeros := 0
	for e: Dictionary in spy.seen:
		if e["p"] == Vector2.ZERO or e["r"] <= 0.0:
			zeros += 1
	t.eq(zeros, 0, "0 좌표나 0 크기로 그려진 것이 없다")

	# A loaded clone is visibly bigger — the one readability requirement in this build, and the only way
	# an abandoned harvest reads as a loss without a number on screen.
	w.swarm.carried[1] = Look.CLONE_LOAD_FULL
	spy.seen.clear()
	await t.pump_frames(1)
	var loaded_r := 0.0
	var empty_r := 0.0
	for e: Dictionary in spy.seen:
		if e["p"] == w.swarm.pos[1]:
			loaded_r = e["r"]
		elif e["p"] == w.swarm.pos[2]:
			empty_r = e["r"]
	t.ok(loaded_r > empty_r, "실은 분신이 빈 분신보다 크게 그려진다 (%.1f > %.1f)" % [loaded_r, empty_r])

	t.root.remove_child(spy)
	spy.queue_free()


# -- the `3` marker and the `F` charge arc, both through `_paint_arc` -------------------------------------
## `_paint_ring` forwards to `_paint_arc` and draws nothing itself, so the spy sees both circles rather
## than only learning that the ring hook was called.
func _c_strike_marker(t) -> void:
	var w := World.new()
	w.setup(91)
	_silence(w)
	w.critter_count = 0
	# A pinned literal, never `sw.strike_point` read back — a bound taken from the thing it measures moves
	# with it and proves nothing.
	var strike := Vector2(1500.0, 900.0)
	var k := w.swarm.add_clone()
	w.swarm.pos[k] = Vector2(1400.0, 900.0)
	w.swarm.command_strike(strike)

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.arcs.clear()
	await t.pump_frames(1)

	var outer := false
	var inner := false
	var at_point := 0
	for e: Dictionary in spy.arcs:
		if e["p"] != strike:
			continue
		at_point += 1
		if absf(float(e["r"]) - Look.STRIKE_RADIUS) < 0.01:
			outer = true
		if absf(float(e["r"]) - Look.STRIKE_RADIUS * 0.45) < 0.01:
			inner = true
	t.eq(at_point, 2, "보낸 지점(1500,900)에 표식이 두 겹으로 그려진다 %s" % str(spy.arcs))
	t.ok(outer and inner, "두 겹은 서로 다른 반지름이다 — 한쪽만 그려도 통과하지 않는다")

	# The negative control, and it is the whole reason the guard exists: rally is at the host now, so the
	# old `rally != pos[0]` guard would have been false forever and this marker would have disappeared
	# with every net green. Nobody in STRIKE, nothing drawn.
	w.swarm.command_rally()
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 0, "부정 대조: STRIKE 중인 몸이 없으면 표식은 그려지지 않는다")

	# The `F` wind-up. 0.45 seconds with nothing on screen is a key that reads as broken, and the sweep is
	# the one value the arc carries — a hook that only ever drew full circles could not show it.
	w.swarm.split_charge = Rules.SPLIT_HOLD_TIME * 0.5
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 1, "감기는 동안 호스트 위에 호가 하나 그려진다 %s" % str(spy.arcs))
	if spy.arcs.size() == 1:
		var a: Dictionary = spy.arcs[0]
		t.eq(a["p"], w.swarm.pos[0], "호는 호스트 자리에 그려진다")
		t.ok(absf(float(a["to"]) - float(a["from"]) - TAU * 0.5) < 0.001,
				"호가 쓸고 간 각도가 감긴 비율(절반)과 같다 (%.4f)" % (float(a["to"]) - float(a["from"])))
		t.ok(absf(float(a["r"]) - Rules.BODY_RADIUS * Look.SPLIT_CHARGE_RING) < 0.01,
				"호의 반지름은 몸 반지름의 배수다 — 별도 상수가 아니다")

	# ⚠ **The arc has to empty on FIRING, not on release.** `_hold_fired` latches so the body count is
	# right either way, and every existing assertion about `split_charge` drives `split_release()` — so
	# deleting `split_charge = 0.0` from the firing path left the round green while this ring stayed
	# visibly FULL after the split had already landed. Held past the hold time WITHOUT releasing.
	w.swarm.split_release()
	var count_before: int = w.swarm.count
	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	t.ok(w.swarm.count > count_before, "설정: 손을 떼지 않은 채 분열이 실제로 일어났다")
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 0, "갈라진 그 순간 감김 호가 비워진다 — 떼기를 기다리지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- the bite cone ---------------------------------------------------------------------------------------
## Shape read off the two `Rules` constants `Swarm._bite()` itself tested with. A cone tuned in `look.gd`
## to look right would be a picture of a hit that did not happen.
func _c_bite_cone(t) -> void:
	var w := World.new()
	w.setup(92)
	_silence(w)
	w.critter_count = 0
	var host: Vector2 = w.swarm.pos[0]
	# 50px out: inside BITE_RANGE, outside EAT_RADIUS_HOST, so ordinary eating cannot be what killed it.
	w.food.pos[0] = host + Vector2(50.0, 0.0)
	w.food.alive[0] = 1
	w.food.alive_count = 1
	w.swarm.step(1.0 / 60.0, w.food)

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.cones.clear()
	await t.pump_frames(1)
	t.eq(spy.cones.size(), 0, "설정: 한 번도 물지 않은 런은 원뿔을 그리지 않는다 (bite_show가 INF로 열린다)")

	t.ok(w.swarm.fire(0, host + Vector2(400.0, 0.0)), "설정: 좌클릭이 실제로 먹이를 물었다")
	t.eq(w.swarm.bite_show, 0.0, "문 순간 원뿔 시계가 0에서 다시 시작한다")
	spy.cones.clear()
	await t.pump_frames(1)
	t.eq(spy.cones.size(), 1, "물면 원뿔이 그려진다")
	if spy.cones.size() == 1:
		var c: Dictionary = spy.cones[0]
		t.eq(c["p"], w.swarm.pos[0], "원뿔의 꼭짓점은 호스트다")
		t.eq(c["range_px"], Rules.BITE_RANGE, "원뿔의 길이가 sim이 실제로 잰 사거리다")
		t.eq(c["arc"], Rules.BITE_ARC, "원뿔의 각도도 sim이 실제로 잰 각이다")
		t.eq(c["dir"], w.swarm.bite_aim, "원뿔이 문 방향을 그대로 가리킨다")

	var show_before: float = w.swarm.bite_show
	t.ok(not w.swarm.fire(0, host + Vector2(400.0, 0.0)), "설정: 쿨다운 안의 두 번째 물기는 거부된다")
	t.eq(w.swarm.bite_show, show_before, "거부당한 물기는 원뿔 시계를 다시 돌리지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


func _silence(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
