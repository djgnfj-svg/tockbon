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

	## `corner` is the seventh argument now — bone sharpens the host's corners, so it is a per-body value
	## and `_blob()` may not read `Look.CORNER` internally. Godot rejects an override whose signature does
	## not match the parent, so this is the shape the file forces.
	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		seen.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot, corner)


## The host's own body, and the four values the five INTERNAL slots are worth in pixels. They are captured
## as separate arguments on purpose: an internal slot adds no shape, so "the arguments differ" is the A/B
## comparison that lets all five change nothing on screen and stay green — which is how a doubled power
## once moved zero pixels. Every number asserted below is a literal.
##
## ⚠ **`GUT` and `LUNG` have no drawing value at all.** The plan names four values for five internal slots
## and says all eleven read on screen; nine do. That gap is reported rather than asserted — pinning it here
## would turn a hole into a contract.
class BodySpy extends FieldView:
	var bodies: Array = []
	var cells: Array = []
	## ⚠ **The arguments alone were not enough, and that is measured.** `_blob()` rewritten to read
	## `Look.CORNER` internally instead of its own `corner` argument left every value captured at
	## `_paint_body` and `_paint_cell` correct — 47 checks green — while the bone slot moved not one pixel.
	## Capturing what `_blob` actually BUILT is the only place that chain can be closed.
	var blobs: Array = []
	## The four leaves below. Cleared by `_capture()` with everything else.
	var shapes: Array = []
	var lines: Array = []
	var outlines: Array = []
	var dots: Array = []

	func _blob(r: float, at: Vector2 = Vector2.ZERO,
			corner: float = Look.CORNER) -> PackedVector2Array:
		var pts := super._blob(r, at, corner)
		blobs.append({"r": r, "at": at, "corner": corner, "pts": pts})
		return pts

	func _paint_body(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
			corner: float, outline_width: float, colour_depth: float, dot_radius: float,
			slot_part: PackedInt32Array) -> void:
		bodies.append({"p": p, "r": r, "corner": corner, "outline_width": outline_width,
				"colour_depth": colour_depth, "dot_radius": dot_radius,
				"slots": PackedInt32Array(slot_part)})
		super._paint_body(c, p, r, col, squash, rot, corner, outline_width, colour_depth, dot_radius,
				slot_part)

	## ⚠ **`col` is captured here and it was not.** `colour_depth` was pinned as an ARGUMENT of
	## `_paint_body` and the colour that actually reached the body was thrown away, so
	## `col.darkened(colour_depth)` folded back to a bare `col` left the hide slot moving zero pixels with
	## 811 checks green — the same chain `corner` had closed one line over.
	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		cells.append({"p": p, "r": r, "corner": corner, "col": col})
		super._paint_cell(c, p, r, col, squash, rot, corner)

	## **The four leaves everything a slot adds goes through, and every one of them was spied by nothing.**
	## Measured: `_has()` rewritten to `return false` erased all SIX external slots at once — head, torso,
	## back, forelimbs, hindlimbs, tail — with 811 checks green, because check 13 only ever asserted that
	## `slot_part` ARRIVED as an argument and `_drawn_corner()` filters to `at == Vector2.ZERO`, which every
	## part shape fails by construction (they are built at the body's world position). The plan's own
	## acceptance question — "did the body visibly become a horse" — was the thing left outside the round.
	func _paint_part_shape(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color) -> void:
		shapes.append({"p": p, "r": r, "corner": corner})
		super._paint_part_shape(c, p, r, corner, col)

	func _paint_part_line(c: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
		lines.append({"a": a, "b": b, "width": width})
		super._paint_part_line(c, a, b, width, col)

	func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
			width: float) -> void:
		outlines.append({"p": p, "r": r, "corner": corner, "width": width})
		super._paint_outline(c, p, r, corner, col, width)

	func _paint_dot(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		dots.append({"p": p, "r": r})
		super._paint_dot(c, p, r, col)


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
	await _c13_body_values(t)


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
## Shape read off what `Swarm.bite()` itself stored, not off a constant. `Rules.BITE_RANGE`/`BITE_ARC` are
## deleted — the reach belongs to the part that fired, and three keys can hold three different ARC parts at
## three different levels, so a constant here would draw one part's cone over another part's hit. The
## stored value is then pinned to the literal 70px separately, because "the view drew what the sim stored"
## is satisfied just as well by both of them being wrong together.
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

	t.ok(w.body.fire(0, host + Vector2(400.0, 0.0)), "설정: 좌클릭이 실제로 먹이를 물었다")
	t.eq(w.swarm.bite_show, 0.0, "문 순간 원뿔 시계가 0에서 다시 시작한다")
	spy.cones.clear()
	await t.pump_frames(1)
	t.eq(spy.cones.size(), 1, "물면 원뿔이 그려진다")
	if spy.cones.size() == 1:
		var c: Dictionary = spy.cones[0]
		t.eq(c["p"], w.swarm.pos[0], "원뿔의 꼭짓점은 호스트다")
		t.eq(c["range_px"], w.swarm.bite_range, "원뿔의 길이가 sim이 실제로 잰 사거리다")
		t.eq(c["arc"], w.swarm.bite_arc, "원뿔의 각도도 sim이 실제로 잰 각이다")
		t.eq(c["dir"], w.swarm.bite_aim, "원뿔이 문 방향을 그대로 가리킨다")
		# And the number the sim stored is plan 2's own. Pinned once, here, so "화면이 sim을 따라 그렸다"
		# cannot be satisfied by both sides drifting to the same wrong reach.
		t.ok(absf(float(c["range_px"]) - 70.0) < 0.001,
				"그 사거리는 70px다 — 그린 쪽과 잰 쪽이 함께 틀릴 수는 없다 (%.3f)" % float(c["range_px"]))
		t.ok(absf(float(c["arc"]) - 1.2217304764) < 0.000001,
				"그 각은 70도(1.2217304764rad)다 (%.10f)" % float(c["arc"]))

	var show_before: float = w.swarm.bite_show
	t.ok(not w.body.fire(0, host + Vector2(400.0, 0.0)), "설정: 쿨다운 안의 두 번째 물기는 거부된다")
	t.eq(w.swarm.bite_show, show_before, "거부당한 물기는 원뿔 시계를 다시 돌리지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- 13: the body's own values, as literals per configuration --------------------------------------------
## ⚠ **Driven, and not A/B.** "The bare body and the bone-wearing body differ" is exactly the comparison
## that lets five internal slots change nothing on screen and stay green — both sides can be the same wrong
## number, or both can be zero. So every configuration below is asserted against a pinned number:
## 0.34 → 0.28 → 0.16 → 0.06 for the corner, 0.0 → 4.0 for the outline, 0.0 → 0.2 for the colour depth,
## 0.0 → 0.17 → 0.27 for the eye dot.
##
## ⚠ **No part in the August table occupies `BONE`, `EYES` or `HIDE`**, so `slot_level` is written by hand
## here. Nothing a player does reaches these three squares in this plan; the drawing side is real and the
## content side is not, and that is reported rather than papered over.
func _c13_body_values(t) -> void:
	var w := World.new()
	w.setup(93)
	_silence(w)
	w.critter_count = 0

	var spy := BodySpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	var bare: Dictionary = await _capture(t, spy)
	t.eq(spy.bodies.size(), 1, "호스트 하나만 _paint_body를 지난다 — 분신에게는 몸이 없다")
	t.eq(bare["p"], w.swarm.pos[0], "몸은 sim의 좌표 그대로 그려진다")
	t.ok(absf(float(bare["r"]) - 14.0) < 0.001, "그리고 sim의 반지름 그대로다 (%.3f)" % float(bare["r"]))
	t.ok(absf(float(bare["corner"]) - 0.34) < 0.0001,
			"맨 몸의 모서리는 0.34다 (리터럴) (%.4f)" % float(bare["corner"]))
	t.ok(absf(float(bare["outline_width"])) < 0.0001, "맨 몸에는 테두리가 없다 — 0.0이다")
	t.ok(absf(float(bare["colour_depth"])) < 0.0001, "맨 몸의 색 깊이는 0.0이다")
	t.ok(absf(float(bare["dot_radius"])) < 0.0001, "맨 몸에는 눈이 없다 — 0.0이다")
	t.eq(int(bare["slots"].size()), 11, "열한 칸이 통째로 그리는 쪽까지 건너간다")
	var bare_filled := 0
	for k in bare["slots"].size():
		if int(bare["slots"][k]) >= 0:
			bare_filled += 1
	t.eq(bare_filled, 0, "맨 몸의 열한 칸은 전부 비어서 건너간다")

	# **The negative control for every leaf below**, and it is what makes each "그려진다" mean something: a
	# body that draws parts unconditionally would pass every count assertion further down.
	t.eq(spy.shapes.size(), 0, "맨 몸에는 겉 부품 도형이 하나도 그려지지 않는다")
	t.eq(spy.lines.size(), 0, "맨 몸에는 겉 부품 선도 하나도 그려지지 않는다")
	t.eq(spy.outlines.size(), 0, "맨 몸에는 테두리가 그려지지 않는다")
	t.eq(spy.dots.size(), 0, "맨 몸에는 눈이 그려지지 않는다")
	# The tone the body was actually painted with, before any slot moves it. Taken from the capture rather
	# than from `Look.HOST_COLOR`, so the comparison below is against what this run really drew.
	var base_col: Color = _cell_col(spy, w.swarm.pos[0], 14.0)
	t.ok(base_col.a > 0.0, "설정: 맨 몸이 실제로 어떤 색으로 칠해졌는지 잡았다 (%s)" % str(base_col))

	# **The base blob still goes through `_paint_cell`, carrying the same corner.** `_paint_body` cutting
	# its own drawing out of that call would leave every existing host capture in the round looking at a
	# body nobody draws.
	var host_cell := false
	for e: Dictionary in spy.cells:
		if e["p"] == w.swarm.pos[0] and absf(float(e["corner"]) - 0.34) < 0.0001:
			host_cell = true
	t.ok(host_cell, "그 몸의 바탕은 여전히 _paint_cell을 같은 모서리로 지난다")
	# **And the silhouette it BUILT carries that number too.** Everything above reads arguments; this reads
	# the polygon. Measured: `_blob` reading `Look.CORNER` internally leaves all of it green.
	t.ok(absf(_drawn_corner(spy, 14.0) - 0.34) < 0.0001,
			"실제로 깎인 도형의 모서리도 0.34다 (%.4f)" % _drawn_corner(spy, 14.0))

	# -- bone SHARPENS, and it has a floor ---------------------------------------------------------------
	w.body.slot_level[Parts.Slot.BONE] = 1
	var bone1: Dictionary = await _capture(t, spy)
	t.ok(absf(float(bone1["corner"]) - 0.28) < 0.0001,
			"뼈 Lv1이면 모서리가 0.28로 깎인다 (리터럴) (%.4f)" % float(bone1["corner"]))
	t.ok(absf(_drawn_corner(spy, 14.0) - 0.28) < 0.0001,
			"그리고 실제 도형이 0.28로 깎인다 — 인자만 바뀌고 그림은 그대로일 수 없다 (%.4f)"
					% _drawn_corner(spy, 14.0))
	w.body.slot_level[Parts.Slot.BONE] = 3
	var bone3: Dictionary = await _capture(t, spy)
	t.ok(absf(float(bone3["corner"]) - 0.16) < 0.0001,
			"뼈 Lv3이면 0.16이다 — 레벨마다 더 깎인다 (%.4f)" % float(bone3["corner"]))
	t.ok(absf(_drawn_corner(spy, 14.0) - 0.16) < 0.0001,
			"실제 도형도 0.16이다 (%.4f)" % _drawn_corner(spy, 14.0))
	# One bite does not prove the range: without the floor the body becomes a plain square and then inverts.
	w.body.slot_level[Parts.Slot.BONE] = 9
	var bone9: Dictionary = await _capture(t, spy)
	t.ok(absf(float(bone9["corner"]) - 0.06) < 0.0001,
			"뼈 Lv9라도 0.06에서 멈춘다 — 몸이 각진 사각형이 되지 않는다 (%.4f)" % float(bone9["corner"]))
	t.ok(absf(_drawn_corner(spy, 14.0) - 0.06) < 0.0001,
			"실제 도형도 0.06에서 멈춘다 (%.4f)" % _drawn_corner(spy, 14.0))
	w.body.slot_level[Parts.Slot.BONE] = 0

	# -- hide/fur: an outline AND a colour depth, two values from one slot -------------------------------
	w.body.slot_level[Parts.Slot.HIDE] = 2
	var hide2: Dictionary = await _capture(t, spy)
	t.ok(absf(float(hide2["outline_width"]) - 4.0) < 0.0001,
			"가죽 Lv2면 테두리가 4.0px다 (리터럴) (%.4f)" % float(hide2["outline_width"]))
	t.ok(absf(float(hide2["colour_depth"]) - 0.2) < 0.0001,
			"그리고 색 깊이는 0.2다 — 한 칸이 두 값을 움직인다 (%.4f)" % float(hide2["colour_depth"]))
	t.ok(absf(float(hide2["corner"]) - 0.34) < 0.0001, "가죽은 모서리를 건드리지 않는다 (여전히 0.34)")
	# **Both halves of the slot, past the argument.** `_paint_outline`'s `draw_polyline` and
	# `col.darkened(colour_depth)` were each erasable with the round green while the two literals above
	# still passed — the value was proven to be computed and never proven to be used.
	t.eq(spy.outlines.size(), 1, "가죽 Lv2면 테두리가 실제로 한 번 그려진다 — 인자로만 4.0인 것이 아니다")
	if spy.outlines.size() == 1:
		var o: Dictionary = spy.outlines[0]
		t.ok(absf(float(o["width"]) - 4.0) < 0.001,
				"그려진 테두리의 폭이 4.0px다 (%.3f)" % float(o["width"]))
		t.ok(_near(o["p"], w.swarm.pos[0]), "테두리는 몸 자리에 그려진다")
		t.ok(absf(float(o["r"]) - 14.0) < 0.001, "그리고 몸과 같은 반지름을 따라 그려진다")
		t.ok(absf(float(o["corner"]) - 0.34) < 0.0001, "몸의 실루엣을 그대로 따라간다 (모서리 0.34)")
	var hide_col: Color = _cell_col(spy, w.swarm.pos[0], 14.0)
	t.ok(hide_col != base_col, "가죽이 몸에 실제로 칠해지는 색을 바꾼다")
	t.ok(_near_col(hide_col, base_col.darkened(0.2)),
			"그 색은 맨 몸 색을 0.2만큼 어둡게 한 것이다 (리터럴) (%s / %s)"
					% [str(hide_col), str(base_col.darkened(0.2))])
	w.body.slot_level[Parts.Slot.HIDE] = 0

	# -- eyes: the one internal slot that adds marks, and the number IS the radius -----------------------
	w.body.slot_level[Parts.Slot.EYES] = 1
	var eye1: Dictionary = await _capture(t, spy)
	t.ok(absf(float(eye1["dot_radius"]) - 0.17) < 0.0001,
			"눈 Lv1이면 점의 반지름이 몸의 0.17배다 (리터럴) (%.4f)" % float(eye1["dot_radius"]))
	# Past the argument, again: `_paint_dot`'s `draw_circle` was erasable with `dot_radius == 0.17` green.
	# Both sides, because only one side's offset is written in `look.gd` and the mirror is derived — a pair
	# tuned into asymmetry is exactly what a single-dot assertion cannot see.
	t.eq(spy.dots.size(), 2, "눈은 좌우 한 쌍으로 실제로 그려진다")
	t.ok(_has_dot(spy.dots, w.swarm.pos[0] + Vector2(5.32, 5.04), 2.38),
			"오른눈이 몸 앞 5.32px·옆 5.04px에 반지름 2.38px로 찍힌다 (리터럴) %s" % str(spy.dots))
	t.ok(_has_dot(spy.dots, w.swarm.pos[0] + Vector2(5.32, -5.04), 2.38),
			"왼눈은 그 거울상이다 — 한쪽만 찍어도 통과하지 않는다")
	w.body.slot_level[Parts.Slot.EYES] = 3
	var eye3: Dictionary = await _capture(t, spy)
	t.ok(absf(float(eye3["dot_radius"]) - 0.27) < 0.0001,
			"눈 Lv3이면 0.27이다 — 레벨마다 커진다 (%.4f)" % float(eye3["dot_radius"]))
	t.ok(_has_dot(spy.dots, w.swarm.pos[0] + Vector2(5.32, 5.04), 3.78),
			"그리고 실제로 찍힌 점이 3.78px로 커진다 (리터럴) %s" % str(spy.dots))
	w.body.slot_level[Parts.Slot.EYES] = 0

	# -- and the SIX EXTERNAL slots actually reach the drawing side --------------------------------------
	## ⚠ **One square at a time, at pinned coordinates.** `_has()` rewritten to `return false` erased all
	## six at once with 811 checks green, and a single count over all of them cannot see one branch being
	## deleted. Every number below is a literal (`Rules.BODY_RADIUS` 14 × the anchor in `look.gd`), because
	## written as `14.0 * Look.PART_HEAD_ANCHOR` the check would move with the constant it exists to pin.
	var host: Vector2 = w.swarm.pos[0]
	w.body.wear(Parts.HORSE_LEGS)
	var worn: Dictionary = await _capture(t, spy)
	t.eq(int(worn["slots"][Parts.Slot.HINDLIMBS]), Parts.HORSE_LEGS,
			"입은 부품이 그 칸 자리 그대로 그리는 쪽까지 건너간다")
	t.eq(int(worn["slots"][Parts.Slot.HEAD]), -1, "입지 않은 칸은 -1로 건너간다")
	t.ok(absf(float(worn["corner"]) - 0.34) < 0.0001, "겉 부품은 속의 값을 바꾸지 않는다 (모서리 0.34 그대로)")
	t.eq(spy.lines.size(), 2, "뒷다리 칸이 차면 다리 한 쌍이 실제로 그려진다 — 입은 것이 몸에 나타난다")
	t.eq(spy.shapes.size(), 0, "그 칸은 선을 그리는 칸이라 도형은 하나도 그려지지 않는다")
	t.ok(_has_seg(spy.lines, host + Vector2(-5.6, 11.2), host + Vector2(-5.6, 22.4)),
			"뒷다리 한쪽이 몸 뒤 5.6px·옆 11.2px에서 11.2px 뻗는다 (리터럴) %s" % str(spy.lines))
	t.ok(_has_seg(spy.lines, host + Vector2(-5.6, -11.2), host + Vector2(-5.6, -22.4)),
			"다른 한쪽은 그 거울상이다 — 한쪽만 그려도 통과하지 않는다")

	# The other five squares: no row in the August table occupies them, so they are written by hand exactly
	# as `slot_level` is above. **The drawing side is what is measured**; the content side is plan 4's.
	w.body.slot_part[Parts.Slot.HINDLIMBS] = -1
	await _capture(t, spy)
	t.eq(spy.lines.size(), 0, "부정 대조: 그 칸을 비우면 다리가 사라진다")

	w.body.slot_part[Parts.Slot.FORELIMBS] = Parts.HORSE_LEGS
	await _capture(t, spy)
	t.eq(spy.lines.size(), 2, "앞다리 칸도 한 쌍을 그린다")
	t.ok(_has_seg(spy.lines, host + Vector2(5.6, 11.2), host + Vector2(5.6, 22.4)),
			"앞다리는 몸 앞 5.6px에서 난다 — 뒷다리와 같은 자리가 아니다 %s" % str(spy.lines))
	w.body.slot_part[Parts.Slot.FORELIMBS] = -1

	w.body.slot_part[Parts.Slot.TAIL] = Parts.HORSE_LEGS
	await _capture(t, spy)
	t.eq(spy.lines.size(), 1, "꼬리 칸은 선 하나를 그린다")
	t.ok(_has_seg(spy.lines, host + Vector2(-14.0, 0.0), host + Vector2(-31.5, 0.0)),
			"꼬리는 몸 뒤끝에서 17.5px 더 뻗는다 (리터럴) %s" % str(spy.lines))
	w.body.slot_part[Parts.Slot.TAIL] = -1

	w.body.slot_part[Parts.Slot.HEAD] = Parts.HORSE_MANE
	await _capture(t, spy)
	t.eq(spy.shapes.size(), 1, "머리 칸은 도형 하나를 그린다")
	t.ok(_has_shape(spy.shapes, host + Vector2(13.3, 0.0), 5.88),
			"머리는 몸 앞 13.3px에 반지름 5.88px로 붙는다 (리터럴) %s" % str(spy.shapes))
	w.body.slot_part[Parts.Slot.HEAD] = -1

	w.body.slot_part[Parts.Slot.TORSO] = Parts.HORSE_MANE
	await _capture(t, spy)
	t.eq(spy.shapes.size(), 1, "몸통 칸도 도형 하나를 그린다")
	t.ok(_has_shape(spy.shapes, host + Vector2(1.68, 0.0), 10.36),
			"몸통은 몸 앞 1.68px에 반지름 10.36px로 부푼다 (리터럴) %s" % str(spy.shapes))
	w.body.slot_part[Parts.Slot.TORSO] = -1

	w.body.slot_part[Parts.Slot.BACK] = Parts.HORSE_MANE
	await _capture(t, spy)
	t.eq(spy.shapes.size(), 1, "등 칸도 도형 하나를 그린다")
	t.ok(_has_shape(spy.shapes, host + Vector2(-13.3, 0.0), 5.32),
			"등은 몸 뒤 13.3px에 반지름 5.32px로 붙는다 (리터럴) %s" % str(spy.shapes))
	w.body.slot_part[Parts.Slot.BACK] = -1

	# All six together, then emptied again. The pair is what says the six are independent rather than one
	# flag: six filled draws three shapes and five lines, and six empty draws none.
	for s: int in [Parts.Slot.HEAD, Parts.Slot.TORSO, Parts.Slot.BACK, Parts.Slot.FORELIMBS,
			Parts.Slot.HINDLIMBS, Parts.Slot.TAIL]:
		w.body.slot_part[s] = Parts.HORSE_MANE
	await _capture(t, spy)
	t.eq(spy.shapes.size(), 3, "겉 칸 여섯이 다 차면 도형은 셋이고 (머리·몸통·등)")
	t.eq(spy.lines.size(), 5, "선은 다섯이다 (앞다리 둘·뒷다리 둘·꼬리 하나)")
	for s: int in [Parts.Slot.HEAD, Parts.Slot.TORSO, Parts.Slot.BACK, Parts.Slot.FORELIMBS,
			Parts.Slot.HINDLIMBS, Parts.Slot.TAIL]:
		w.body.slot_part[s] = -1
	await _capture(t, spy)
	t.eq(spy.shapes.size(), 0, "부정 대조: 여섯을 다시 비우면 도형이 하나도 남지 않는다")
	t.eq(spy.lines.size(), 0, "부정 대조: 선도 하나도 남지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


## One frame, one body. Cleared and re-pumped every time: the node draws once per frame it is asked to, so
## a capture kept across frames holds several passes and every "the only body" assertion above would be
## measuring frames instead.
##
## A body that was never drawn returns a row of `INF`, not an empty dictionary — every literal above then
## goes red by name instead of the whole file dying on a missing key.
func _capture(t, spy: BodySpy) -> Dictionary:
	spy.bodies.clear()
	spy.cells.clear()
	spy.blobs.clear()
	spy.shapes.clear()
	spy.lines.clear()
	spy.outlines.clear()
	spy.dots.clear()
	await t.pump_frames(1)
	if spy.bodies.size() > 0:
		return spy.bodies[0]
	return {"p": Vector2.INF, "r": INF, "corner": INF, "outline_width": INF, "colour_depth": INF,
			"dot_radius": INF, "slots": PackedInt32Array()}


## The corner the host's SILHOUETTE actually carries, recovered from `_blob`'s own output rather than from
## the argument handed to it. `_blob` builds its first point as `at + Vector2(-r + r*corner, -r)`, so the
## cut is `pts[0].x + r` (at the origin) and the corner is that over `r`.
##
## Only the host's body and its shadow are built at `(r == BODY_RADIUS, at == ZERO)`: the top-light uses
## `r * 0.52` at an offset, a clone uses `CLONE_BODY_RADIUS`, and every part shape and the hide outline are
## built at the body's world position rather than at the origin.
func _drawn_corner(spy: BodySpy, radius: float) -> float:
	for e: Dictionary in spy.blobs:
		if absf(float(e["r"]) - radius) > 0.001 or e["at"] != Vector2.ZERO:
			continue
		var pts: PackedVector2Array = e["pts"]
		if pts.size() > 0:
			return (pts[0].x + radius) / radius
	return INF


## Positions come out of float32 `Vector2` arithmetic, so `14.0 * 0.95` is not exactly `13.3`. The band is
## far tighter than the smallest gap between any two anchors above (1.68 vs 5.6 vs 13.3), so it cannot make
## two different squares read as each other.
const NEAR := 0.02


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < NEAR


func _near_col(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002


## A segment, either way round — `_paint_limb_pair` names its own root and tip and the order is not the
## contract; where the two ends ARE is.
func _has_seg(list: Array, a: Vector2, b: Vector2) -> bool:
	for e: Dictionary in list:
		if (_near(e["a"], a) and _near(e["b"], b)) or (_near(e["a"], b) and _near(e["b"], a)):
			return true
	return false


func _has_shape(list: Array, at: Vector2, r: float) -> bool:
	for e: Dictionary in list:
		if _near(e["p"], at) and absf(float(e["r"]) - r) < NEAR:
			return true
	return false


func _has_dot(list: Array, at: Vector2, r: float) -> bool:
	return _has_shape(list, at, r)


## The colour the host's own base blob was painted with, off `_paint_cell`. Not `Look.HOST_COLOR` read
## back: what is being measured is the tone that reached the draw, and `col.darkened(colour_depth)`
## collapsing to a bare `col` is invisible to anything that reads the constant instead.
func _cell_col(spy: BodySpy, at: Vector2, radius: float) -> Color:
	for e: Dictionary in spy.cells:
		if _near(e["p"], at) and absf(float(e["r"]) - radius) < 0.001:
			return e["col"]
	return Color(0.0, 0.0, 0.0, 0.0)


func _silence(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
