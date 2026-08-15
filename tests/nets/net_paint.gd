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
		# `col_a` rather than `col`: an assertion that the captured colour equals the constant it came from
		# moves both sides when the constant moves, which is how `Color(0, 0, 0, 0)` stayed green.
		arcs.append({"p": p, "r": r, "from": from, "to": to, "width": width, "col_a": col.a})
		super._paint_arc(c, p, r, from, to, col, width)

	func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float, arc: float,
			col: Color) -> void:
		cones.append({"p": p, "dir": dir, "range_px": range_px, "arc": arc})
		super._paint_cone(c, p, dir, range_px, arc, col)


## The ground, and it is its own leaf on purpose: `_paint_dot` is the eyes and a spy already watches it, so
## folding forty rocks into the same capture would make every eye assertion unreadable.
class DiscSpy extends FieldView:
	var discs: Array = []

	func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		discs.append({"p": p, "r": r, "col": col})
		super._paint_disc(c, p, r, col)


## The number under every body. `draw_string` is native and Godot refuses to override it, so the leaf takes
## the values as arguments and this captures them — including the `p` the centring produced, which is the
## only way an alignment argument that silently does nothing can be seen headless.
class LabelSpy extends FieldView:
	var labels: Array = []

	func _paint_label(c: CanvasItem, p: Vector2, text: String, col: Color) -> void:
		labels.append({"p": p, "text": text, "col": col})
		super._paint_label(c, p, text, col)


## The minimap's own hook, on the HUD rather than the field: this one is SCREEN space on a `Control` and the
## field's leaves are world space on a `Node2D`. `frame` and `marks` are both captured, because where the
## map IS is a separate defect from what is inside it.
## ⚠ **The two leaves are captured as well, and for a measured reason.** Spying `_paint_minimap` alone
## sees the composer being CALLED and nothing it did: with `maps` as the only capture, `_to_map` rewritten
## to `return frame.position` (host, forty clones and the boss all on one pixel), every mark radius zeroed,
## the whole `for m in marks:` loop emptied and all six minimap constants set to zero at once were **each
## green** — a blank rectangle with the round passing. `frame` and `marks` are captured too because where
## the map IS is a separate defect from what is inside it.
class MapSpy extends Hud:
	var maps: Array = []
	## Background, edge and camera box — the three rectangles inside the map, plus the level bar's two.
	## Classified by colour below, which is what tells the five apart.
	var rects: Array = []
	## What each mark leaf was actually handed: position, radius and colour.
	var marks: Array = []

	func _paint_minimap(c: CanvasItem, frame: Rect2, camera: Rect2, marks_in: Array) -> void:
		maps.append({"frame": frame, "camera": camera, "marks": marks_in.duplicate()})
		super._paint_minimap(c, frame, camera, marks_in)

	func _paint_rect(c: CanvasItem, r: Rect2, col: Color) -> void:
		rects.append({"r": r, "col": col})
		super._paint_rect(c, r, col)

	func _paint_mark(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		marks.append({"p": p, "r": r, "col": col})
		super._paint_mark(c, p, r, col)

	func forget() -> void:
		maps.clear()
		rects.clear()
		marks.clear()


func run(t) -> void:
	await _c_cells(t)
	await _c_strike_marker(t)
	await _c_bite_cone(t)
	await _c13_body_values(t)
	await _p2_creatures_are_drawn_by_species(t)
	await _p1_the_eating_ring(t)
	await _t6_the_drawn_ground_is_the_sim_s(t)
	await _c31_c32_c33_labels(t)
	await _p3_the_label_is_centred(t)
	await _u16c_the_cluster_centroid_is_the_mean(t)
	await _c35_minimap(t)
	await _c35b_what_is_on_the_map(t)
	await _c35c_the_camera_box_is_clipped(t)
	await _c35d_water_is_on_the_map(t)


## ⚠ **Every term of `expect` is a literal and the world is built to make that possible.** It used to read
## `1 + swarm.count - 1 + food.alive_count + critter_count` — a bound taken straight off the thing under
## test, which shrinks with whatever it is checking.
##
## ⚠ **Rocks and water are NOT in this count.** They go through `_paint_disc`, which the cell spy never
## sees; T6 carries its own. Corpses ARE, because a corpse is drawn as a cell.
func _c_cells(t) -> void:
	var w := World.new()
	w.setup(9)
	_silence(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	# Three food at pinned coordinates near the host, so the expected draw count is a number and not a
	# function of the spawner's randomness.
	for i in 3:
		w.food.pos[i] = host + Vector2(40.0 + i * 20.0, 0.0)
		w.food.alive[i] = 1
	w.food.alive_count = 3
	# The run opens with the host alone, so these four are the whole swarm and the count below is exact.
	for i in 4:
		var k := w.swarm.add_clone()
		w.swarm.pos[k] = host + Vector2(-60.0 - i * 25.0, 30.0)
	# Two creatures and one corpse, written by hand over the twelve `setup()` placed.
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(Parts.Species.CROW, host + Vector2(200.0, 0.0), 10)
	w._write_critter(Parts.Species.HORSE, host + Vector2(300.0, 0.0), 30)
	w.corpse_count = 1
	w.corpse_pos[0] = host + Vector2(0.0, 200.0)
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	# Two rocks and one water circle, at literal coordinates: `Terrain.setup()`'s rejection sampler makes
	# `rock_pos.size()` seed-dependent, so nothing here may read the generated ground.
	w.terrain.rock_pos.append(host + Vector2(-400.0, 0.0))
	w.terrain.rock_radius.append(90.0)
	w.terrain.rock_pos.append(host + Vector2(-600.0, 0.0))
	w.terrain.rock_radius.append(50.0)
	w.terrain.water_pos.append(host + Vector2(0.0, -400.0))
	w.terrain.water_radius.append(150.0)

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	# Cleared and re-pumped: the node draws once per frame it is asked to, so a multi-frame capture would
	# hold two passes and the count assertion below would be measuring frames, not bodies.
	spy.seen.clear()
	await t.pump_frames(1)

	# 1 호스트 + 4 분신 + 3 먹이 + 2 생물 + 1 시체. Every term a literal.
	t.eq(spy.seen.size(), 11, "호스트·분신 넷·먹이 셋·생물 둘·시체 하나가 전부 그려졌다 (1+4+3+2+1)")

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

	t.ok(w.body.fire(0, host + Vector2(400.0, 0.0)), "설정: 좌클릭이 나갔다")
	# `fire()`는 이제 빈 원뿔에도 true를 돌려준다 — 위 한 줄만으로는 "키가 쿨다운이 아니었다"밖에 재지
	# 못한다. 먹이가 실제로 사라졌는지는 따로 못 박아야 라벨이 재는 것과 같아진다.
	t.eq(w.food.alive[0], 0, "설정: 그리고 먹이가 실제로 사라졌다")
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


# -- P2: a creature's COLOUR and RADIUS both come from its species ---------------------------------------
## ⚠ **Nothing in the round had ever asserted a creature's drawn colour or its drawn radius.** Both used to
## come from `threat` — one number the design deleted — and the loop that replaced them could have drawn the
## whole field in one tone with every other check green.
func _p2_creatures_are_drawn_by_species(t) -> void:
	var w := World.new()
	w.setup(94)
	_silence(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(Parts.Species.CROW, host + Vector2(200.0, 0.0), 10)
	w._write_critter(Parts.Species.HORSE, host + Vector2(400.0, 0.0), 30)
	w._write_critter(Parts.Species.BOSS, host + Vector2(600.0, 0.0), 120)

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.seen.clear()
	await t.pump_frames(1)

	# Radii are the literals check 30 pins through `_radius_of`: crow at force 10 is 15, the weakest horse is
	# 22, the boss is 48.
	t.ok(_cell_is(spy, host + Vector2(200.0, 0.0), 15.0, Look.CROW_COLOR),
			"까마귀는 제 종의 색으로, 제 종의 15px로 그려진다 %s" % str(spy.seen))
	t.ok(_cell_is(spy, host + Vector2(400.0, 0.0), 22.0, Look.HORSE_COLOR),
			"말은 말의 색으로 22px로 그려진다")
	t.ok(_cell_is(spy, host + Vector2(600.0, 0.0), 48.0, Look.BOSS_COLOR),
			"보스는 보스의 색으로 48px로 그려진다 — 세 종이 한 색으로 뭉개지지 않는다")
	t.ok(Look.CROW_COLOR != Look.HORSE_COLOR and Look.HORSE_COLOR != Look.BOSS_COLOR
			and Look.CROW_COLOR != Look.BOSS_COLOR,
			"설정: 세 색은 서로 다른 색이다 — 같은 색이면 위의 셋은 아무것도 구분하지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- P1: the eating ring ---------------------------------------------------------------------------------
## A six-second boss meal with nothing on screen is the beat happening invisibly. The sweep AND the radius
## are both pinned: a bare radius passed to `_paint_arc` draws a ring that says nothing about the corpse.
func _p1_the_eating_ring(t) -> void:
	var w := World.new()
	w.setup(95)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at: Vector2 = w.swarm.pos[0] + Vector2(300.0, 0.0)
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.5

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.arcs.clear()
	await t.pump_frames(1)
	# Nobody is in STRIKE and the `F` charge is zero, so the eating ring is the only arc on screen.
	t.eq(spy.arcs.size(), 1, "반쯤 먹은 시체 위에 호가 하나 그려진다 %s" % str(spy.arcs))
	if spy.arcs.size() == 1:
		var a: Dictionary = spy.arcs[0]
		t.eq(a["p"], at, "그 호는 시체 자리에 있다")
		t.ok(absf(float(a["to"]) - float(a["from"]) - TAU * 0.5) < 0.001,
				"쓸고 간 각이 진행도의 절반과 같다 (%.4f)" % (float(a["to"]) - float(a["from"])))
		# 18.0 = corpse_radius 12 × CORPSE_PROGRESS_RING 1.5, by hand.
		t.ok(absf(float(a["r"]) - 18.0) < 0.01,
				"반지름은 그 시체의 크기의 배수다 — 12 × 1.5 = 18px (리터럴) (%.3f)" % float(a["r"]))
		# ⚠ **The WIDTH reaching the leaf, as a literal.** `CORPSE_PROGRESS_WIDTH` had zero hits in all of
		# `tests/` — a zero-width arc is a ring that is computed correctly and drawn as nothing.
		t.ok(absf(float(a["width"]) - 3.0) < 0.01,
				"그리고 굵기 3px로 그려진다 — 0이면 계산은 맞고 화면에는 아무것도 없다 (%.3f)"
						% float(a["width"]))
		t.ok(float(a["col_a"]) > 0.5,
				"그 호는 실제로 보이는 알파로 그려진다 (%.2f) — 색을 상수끼리 비교하면 0도 통과한다"
						% float(a["col_a"]))

	w.corpse_progress[0] = 0.0
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 0, "부정 대조: 아무도 안 먹은 시체에는 호가 없다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- T6: the DRAWN rock is the sim's rock ----------------------------------------------------------------
## ⚠ **`_paint_disc`, not `_paint_cell`.** All three of `Terrain`'s predicates are `distance < radius`, and
## `_paint_cell` draws a rounded square whose corners stick ~26px past a 90px rock's collision circle — you
## would walk through visible rock, which is screen and sim disagreeing in the feature herding rests on.
func _t6_the_drawn_ground_is_the_sim_s(t) -> void:
	var w := World.new()
	w.setup(96)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var rock := Vector2(1200.0, 900.0)
	var water := Vector2(1600.0, 1200.0)
	w.terrain.rock_pos.append(rock)
	w.terrain.rock_radius.append(90.0)
	w.terrain.water_pos.append(water)
	w.terrain.water_radius.append(150.0)

	var spy := DiscSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.discs.clear()
	await t.pump_frames(1)

	t.eq(spy.discs.size(), 2, "바위 하나와 물 하나, 원 두 개가 그려진다 %s" % str(spy.discs))
	t.ok(_disc_is(spy, rock, 90.0, Look.ROCK_COLOR),
			"바위는 sim이 부딪히는 그 중심에 그 반지름으로 그려진다 (1200,900 · 90px)")
	t.ok(_disc_is(spy, water, 150.0, Look.WATER_COLOR),
			"물도 마찬가지다 (1600,1200 · 150px) — 그리고 바위와 다른 색이다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- 31 / 32 / 33: the number under every body -----------------------------------------------------------
## Three rules in one treed fixture, because each of them passes against the others' bug.
func _c31_c32_c33_labels(t) -> void:
	var w := World.new()
	w.setup(97)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	var pile := host + Vector2(400.0, 0.0)
	for _i in 40:
		var k := w.swarm.add_clone(0, 5)
		w.swarm.pos[k] = pile
	t.eq(w.swarm.count, 41, "설정: 힘 5짜리 분신 마흔을 한 점에 세웠다")

	var spy := LabelSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.labels.clear()
	await t.pump_frames(1)

	t.eq(spy.labels.size(), 2, "뭉친 마흔과 호스트는 라벨 두 개다 %s" % str(_texts(spy)))
	# 200·600 = 40 × force 5 and 40 × hp 15. **Not 8**: `SimGrid.neighbours()` truncates at NEIGHBOUR_CAP,
	# so a pile of forty summed through it would read 40.
	t.ok(_has_text(spy, "200·600"),
			"뭉친 쪽은 합해서 200·600으로 읽힌다 — 8이 아니다 %s" % str(_texts(spy)))
	# The host's hp comes from `World.host_hp`, never `swarm.hp[0]` — row 0 of that column is the -1
	# sentinel and printing it puts `-1` under the host on the opening frame.
	t.ok(_has_text(spy, "10·30"), "호스트는 언제나 제 라벨을 따로 갖는다 — 10·30 %s" % str(_texts(spy)))

	# Spread past `FORCE_CLUSTER_RADIUS` and every one of them is its own label again.
	# ⚠ **A grid, not a line.** Forty bodies 100px apart in a row run off the east edge of the field, and
	# `_force_labels()` culls against `view_rect` — the count came back 18 and read like a clustering bug.
	for i in range(1, w.swarm.count):
		var j := i - 1
		w.swarm.pos[i] = Vector2(200.0 + float(j % 8) * 300.0, 200.0 + float(j / 8) * 300.0)
	spy.labels.clear()
	await t.pump_frames(1)
	t.eq(spy.labels.size(), 41, "떨어뜨려 놓으면 마흔한 개가 된다 — 뭉치는 것은 거리 규칙이다")

	# 32(a): mine and theirs never share a cluster, and the two SHAPES differ.
	var w2 := World.new()
	w2.setup(98)
	_silence(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	var host2: Vector2 = w2.swarm.pos[0]
	var spot := host2 + Vector2(500.0, 0.0)
	var c := w2.swarm.add_clone(0, 5)
	w2.swarm.pos[c] = spot
	w2._write_critter(Parts.Species.CROW, spot + Vector2(10.0, 0.0), 10)
	w2.species_eaten = PackedInt32Array([int(Parts.Species.CROW)])
	spy.world = w2
	spy.labels.clear()
	await t.pump_frames(1)
	t.eq(spy.labels.size(), 3, "겹쳐 선 까마귀와 분신은 라벨 둘이다 (호스트까지 셋) %s" % str(_texts(spy)))
	t.ok(_has_text(spy, "5·15") and _has_text(spy, "10"),
			"내 쪽은 힘·체력, 저쪽은 숫자 하나 — 합쳐 15로 읽히지 않는다 %s" % str(_texts(spy)))

	# 32(b): two different SPECIES never share one either. A boss of 120 beside a crow of 10 reading 130
	# would leave the `?` lookup with no species to ask about.
	var w3 := World.new()
	w3.setup(99)
	_silence(w3)
	_clear_terrain(w3)
	w3.critter_count = 0
	w3.boss_index = -1
	var spot3: Vector2 = w3.swarm.pos[0] + Vector2(500.0, 0.0)
	w3._write_critter(Parts.Species.CROW, spot3, 10)
	w3._write_critter(Parts.Species.BOSS, spot3 + Vector2(10.0, 0.0), 120)
	w3.boss_index = 1
	spy.world = w3
	spy.labels.clear()
	await t.pump_frames(1)
	t.eq(spy.labels.size(), 3, "겹쳐 선 까마귀와 보스도 라벨 둘이다 (호스트까지 셋) %s" % str(_texts(spy)))
	# 33: never eaten reads `?`, and the BOSS is the exception — it shows its 120 from t = 0.
	t.ok(_has_text(spy, "?"), "아직 안 먹어 본 까마귀는 ?로 읽힌다 %s" % str(_texts(spy)))
	t.ok(_has_text(spy, "120"), "보스만은 t=0부터 제 숫자를 보여준다 — 못 닿는 숫자를 보는 것이 그 호다")
	t.ok(not _has_text(spy, "130"), "그리고 둘이 합쳐 130으로 읽히는 일은 없다")

	# 33, the other half: eat one and the `?` becomes the number, exactly `"10"` with no separator — a
	# creature's label never carries hp, or forty of them turn the field into a debug overlay.
	w3.species_eaten = PackedInt32Array([int(Parts.Species.CROW)])
	spy.labels.clear()
	await t.pump_frames(1)
	t.ok(not _has_text(spy, "?"), "한 번 먹고 나면 물음표가 사라지고")
	t.ok(_has_text(spy, "10"), "그 자리에 숫자가 나온다 — 몸 밑의 숫자는 벌어 온 지식이다 %s" % str(_texts(spy)))

	t.root.remove_child(spy)
	spy.queue_free()


# -- P3: the label's origin is CENTRED -------------------------------------------------------------------
## ⚠ **Godot 4 ignores `HORIZONTAL_ALIGNMENT_CENTER` when `width` is negative**, so passing it does nothing
## at all and every label sits half its own width to the right of the centroid it documents — invisible
## headless, because there are no pixels and a spy captures a `p` that is correct for what it was told.
## The centring is done in `_label()` for exactly that reason, which makes the offset an argument.
func _p3_the_label_is_centred(t) -> void:
	var w := World.new()
	w.setup(100)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	var mine := host + Vector2(600.0, 0.0)
	var theirs := host + Vector2(1200.0, 0.0)
	var c := w.swarm.add_clone(0, 5)
	w.swarm.pos[c] = mine
	w._write_critter(Parts.Species.CROW, theirs, 10)
	w.species_eaten = PackedInt32Array([int(Parts.Species.CROW)])

	var spy := LabelSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.labels.clear()
	await t.pump_frames(1)

	var long_p := _label_p(spy, "5·15")
	var short_p := _label_p(spy, "10")
	t.ok(long_p != Vector2.INF and short_p != Vector2.INF,
			"설정: 긴 라벨과 짧은 라벨을 둘 다 잡았다 %s" % str(_texts(spy)))
	var long_w := ThemeDB.fallback_font.get_string_size("5·15", HORIZONTAL_ALIGNMENT_LEFT, -1,
			Look.FORCE_LABEL_SIZE).x
	var short_w := ThemeDB.fallback_font.get_string_size("10", HORIZONTAL_ALIGNMENT_LEFT, -1,
			Look.FORCE_LABEL_SIZE).x
	t.ok(long_w > short_w + 1.0,
			"설정: 「5·15」는 「10」보다 실제로 넓다 (%.1f > %.1f)" % [long_w, short_w])
	t.ok(absf((mine.x - long_p.x) - long_w * 0.5) < 0.01,
			"긴 라벨은 제 폭의 절반만큼 왼쪽에서 시작한다 (%.2f)" % (mine.x - long_p.x))
	t.ok(absf((theirs.x - short_p.x) - short_w * 0.5) < 0.01,
			"짧은 라벨도 제 폭의 절반만큼이다 — 두 값이 다르다는 것이 가운데 맞춤의 증거다 (%.2f)"
					% (theirs.x - short_p.x))
	t.ok(absf(mine.x - long_p.x) > absf(theirs.x - short_p.x) + 0.5,
			"그래서 긴 쪽이 더 많이 밀린다 — 원점을 그대로 넘겼다면 둘 다 0이다")
	t.ok(absf(long_p.y - (mine.y + Look.FORCE_LABEL_OFFSET)) < 0.01,
			"그리고 라벨은 몸 아래 FORCE_LABEL_OFFSET만큼에 놓인다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- U16c: the cluster's centroid is the MEAN, not the first body --------------------------------------
## **Every fixture in this file puts its bodies at one IDENTICAL point**, so `centre + (pts[i] - centre) / n`
## always equals `pts[i]` and never updating the running centroid at all is green — the summed number would
## then be drawn under whichever body happened to be first in the table instead of in the middle of the pile.
##
## Three distinct points, all inside `FORCE_CLUSTER_RADIUS` (48), and the expected centroid is hand-computed:
## (1000+1030+1000)/3 = 1010 and (1000+1000+1030)/3 = 1010. The greedy join is what makes the running mean
## equal the true mean — the second body joins at 30px from A, the third at 33.5px from the pair's midpoint.
func _u16c_the_cluster_centroid_is_the_mean(t) -> void:
	var w := World.new()
	w.setup(102)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	# The host is 800px away, so it can never be pulled into the clones' cluster and its own label cannot be
	# mistaken for theirs.
	w.swarm.pos[0] = Vector2(200.0, 1000.0)
	var pts := [Vector2(1000.0, 1000.0), Vector2(1030.0, 1000.0), Vector2(1000.0, 1030.0)]
	for p: Vector2 in pts:
		var k := w.swarm.add_clone(0, 5)
		w.swarm.pos[k] = p
	t.eq(w.swarm.count, 4, "설정: 힘 5짜리 분신 셋과 호스트")
	t.ok(pts[0].distance_to(pts[1]) < Look.FORCE_CLUSTER_RADIUS,
			"설정: 셋은 서로 뭉치는 거리 안이다 (30px)")

	var spy := LabelSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.labels.clear()
	await t.pump_frames(1)

	t.eq(spy.labels.size(), 2, "라벨은 둘이다 — 뭉친 셋과 호스트 %s" % str(_texts(spy)))
	var p := _label_p(spy, "15·45")
	t.ok(p != Vector2.INF, "뭉친 셋은 15·45로 읽힌다 %s" % str(_texts(spy)))
	if p != Vector2.INF:
		var wide := ThemeDB.fallback_font.get_string_size("15·45", HORIZONTAL_ALIGNMENT_LEFT, -1,
				Look.FORCE_LABEL_SIZE).x
		# The centroid, undone through `_label`'s own two offsets: half the string width in x, 18 in y.
		var centre := Vector2(p.x + wide * 0.5, p.y - 18.0)
		t.ok(absf(centre.x - 1010.0) < 0.01,
				"그 숫자는 셋의 평균 x 1010에 놓인다 — 첫 몸의 1000이 아니다 (%.3f)" % centre.x)
		t.ok(absf(centre.y - 1010.0) < 0.01,
				"평균 y도 1010이다 — 굴러가는 무게중심을 안 갱신해도 초록이었다 (%.3f)" % centre.y)
		t.ok(centre != pts[0], "그리고 그 자리는 어느 한 몸의 자리도 아니다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- 35: the minimap, and WHERE the map itself is --------------------------------------------------------
## ⚠ **`set_anchors_preset` leaves the offsets alone**, so a `Control` on a bare `CanvasLayer` can sit at
## `size == (0, 0)` and pile the map into the top-left corner with every mark assertion still passing. The
## frame's own position and extent are asserted for that reason, and so is `size` against the viewport.
func _c35_minimap(t) -> void:
	var w := World.new()
	w.setup(101)
	_silence(w)
	_clear_terrain(w)
	var host := Vector2(400.0, 400.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	# The boss is placed FAR past `MINIMAP_SHOW_DIST`, so "always shown" is the only thing that can put it
	# on the map; the crow sits just past the same line.
	w._write_critter(Parts.Species.CROW, host + Vector2(Look.MINIMAP_SHOW_DIST + 100.0, 0.0), 10)
	w._write_critter(Parts.Species.BOSS, host + Vector2(0.0, Look.MINIMAP_SHOW_DIST + 500.0), 120)
	w.boss_index = 1

	var spy := MapSpy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.maps.clear()
	await t.pump_frames(1)

	t.eq(spy.maps.size(), 1, "한 프레임에 미니맵이 한 번 그려진다")
	if spy.maps.size() != 1:
		t.root.remove_child(spy)
		spy.queue_free()
		return
	var m: Dictionary = spy.maps[0]
	var frame: Rect2 = m["frame"]
	t.eq(spy.size, spy.get_viewport_rect().size, "설정: HUD는 뷰포트 크기로 펼쳐져 있다 (%s)" % str(spy.size))
	t.eq(frame.size, Look.MINIMAP_SIZE, "지도의 크기는 MINIMAP_SIZE 그대로다")
	t.ok(frame.position.x > spy.size.x * 0.5 and frame.position.y > spy.size.y * 0.5,
			"지도는 오른쪽 아래에 있다 — 0 크기 Control이 만드는 왼쪽 위 구석이 아니다 (%s)"
					% str(frame.position))
	t.ok(frame.end.x <= spy.size.x and frame.end.y <= spy.size.y, "그리고 화면 안에 다 들어와 있다")

	var marks: Array = m["marks"]
	var boss_marks := 0
	var crow_marks := 0
	for e: Dictionary in marks:
		if e["col"] == Look.BOSS_COLOR:
			boss_marks += 1
		if e["col"] == Look.CROW_COLOR:
			crow_marks += 1
	t.eq(boss_marks, 1, "2100px 떨어진 보스는 언제나 지도에 있다 — 걸어갈 곳이 처음부터 보인다")
	t.eq(crow_marks, 0, "1700px 떨어진 까마귀는 지도에 없다 — 지도는 방향이지 정보가 아니다")

	# The negative control: the same crow inside the line DOES appear, or "never shown" passes just as well
	# as the rule does.
	w.critter_pos[0] = host + Vector2(Look.MINIMAP_SHOW_DIST - 100.0, 0.0)
	spy.maps.clear()
	await t.pump_frames(1)
	var near := 0
	for e: Dictionary in (spy.maps[0]["marks"] as Array):
		if e["col"] == Look.CROW_COLOR:
			near += 1
	t.eq(near, 1, "대조: 같은 까마귀가 선 안으로 들어오면 지도에 뜬다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- 35b: WHERE every mark sits, and how big it is -------------------------------------------------------
## **The largest unmeasured surface in this build, and five of seven verifiers found it separately.** 35
## above classifies marks by `col` and throws `p` and `r` away, builds its spy with `camera_rect` at its
## `Rect2()` default (so the camera-box branch never executed once in the whole round) and runs a swarm of
## `count == 1` (so the clone loop never ran). Measured green against that: `_to_map` → `return
## frame.position`, every mark radius → 0, the mark loop emptied, all six minimap constants zeroed.
##
## ⚠ **Every expected number here is arithmetic on hand-written coordinates**, never `_to_map` re-run.
## The field is 3840×2160 and the map is 240×135, so the mapping is exactly ×0.0625 — a body at the field's
## centre is at the map's centre and a body at a quarter across is a quarter across. The radii are the
## three `Look` constants written out as literals (3.0 / 1.5 / 2.0); read back symbolically they move on
## both sides of the assertion and zeroing them stays green, which is what happened.
func _c35b_what_is_on_the_map(t) -> void:
	var w := World.new()
	w.setup(102)
	_silence(w)
	_clear_terrain(w)

	# The host at the field's exact centre, two clones at a quarter and three quarters across.
	var host := Vector2(1920.0, 1080.0)
	w.swarm.pos[0] = host
	var c1 := w.swarm.add_clone()
	var c2 := w.swarm.add_clone()
	w.swarm.pos[c1] = Vector2(960.0, 540.0)
	w.swarm.pos[c2] = Vector2(2880.0, 1620.0)

	w.critter_count = 0
	w.boss_index = -1
	# 1500px from the host — inside `MINIMAP_SHOW_DIST`, so it is on the map.
	w._write_critter(Parts.Species.CROW, Vector2(3420.0, 1080.0), 10)
	# ~1930px away and it is on the map anyway, because it is the boss.
	w._write_critter(Parts.Species.BOSS, Vector2(240.0, 216.0), 120)
	w.boss_index = 1
	# ~2140px away and not the boss: off the map. Without it "everything is shown" passes too.
	w._write_critter(Parts.Species.HORSE, Vector2(3800.0, 2100.0), 30)

	var spy := MapSpy.new()
	spy.world = w
	# The camera, as a real rectangle: a quarter in from the top-left, half the field wide.
	spy.camera_rect = Rect2(960.0, 540.0, 1920.0, 1080.0)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	t.eq(spy.maps.size(), 1, "설정: 한 프레임에 미니맵이 한 번 그려진다")
	if spy.maps.size() != 1:
		t.root.remove_child(spy)
		spy.queue_free()
		return
	var frame: Rect2 = spy.maps[0]["frame"]
	var at: Vector2 = frame.position

	# **The frame's own numbers as literals.** 35 asserts `frame.size == Look.MINIMAP_SIZE`, which is the
	# constant read back against itself: shrink it to 9×4 and that assertion still passes.
	t.eq(frame.size, Vector2(240.0, 135.0), "지도는 240×135다 (리터럴)")
	t.eq(at, spy.size - Vector2(240.0, 135.0) - Vector2(16.0, 16.0),
			"그리고 오른쪽 아래 구석에서 16만큼 안쪽이다 (%s)" % str(at))

	# -- the marks -------------------------------------------------------
	t.eq(spy.marks.size(), 5, "찍힌 점은 다섯이다 — 분신 둘, 가까운 까마귀, 보스, 호스트 %s"
			% str(spy.marks.size()))
	t.ok(_mark_at(spy, at + Vector2(120.0, 67.5), 3.0, Look.HOST_COLOR),
			"호스트는 필드 한가운데에 있으니 지도 한가운데 반지름 3.0으로 찍힌다")
	t.ok(_mark_at(spy, at + Vector2(60.0, 33.75), 1.5, Look.CLONE_COLOR),
			"1/4 지점의 분신은 지도의 1/4 지점에 반지름 1.5로 찍힌다")
	t.ok(_mark_at(spy, at + Vector2(180.0, 101.25), 1.5, Look.CLONE_COLOR),
			"3/4 지점의 분신도 제자리에 찍힌다 — 두 점이 한 점에 겹치지 않는다")
	t.ok(_mark_at(spy, at + Vector2(213.75, 67.5), 2.0, Look.CROW_COLOR),
			"1500px 떨어진 까마귀는 지도 오른쪽에 반지름 2.0으로 찍힌다")
	t.ok(_mark_at(spy, at + Vector2(15.0, 13.5), 2.0, Look.BOSS_COLOR),
			"보스는 1900px 밖이어도 지도 왼쪽 위에 찍힌다")
	t.eq(_marks_col(spy, Look.HORSE_COLOR), 0, "1600px 밖의 말은 찍히지 않는다")

	# **Every mark inside the frame.** A mapping that overflows draws over the play area, and nothing
	# about the five positions above would say so on its own.
	for e: Dictionary in spy.marks:
		t.ok(frame.has_point(e["p"]), "점 %s는 지도 안에 있다" % str(e["p"]))

	# -- the three rectangles --------------------------------------------
	t.eq(_rects_col(spy, Look.MINIMAP_FRAME), 1, "테두리는 한 장이다")
	t.eq(_rect_col(spy, Look.MINIMAP_FRAME), Rect2(at - Vector2(2.0, 2.0), Vector2(244.0, 139.0)),
			"테두리는 지도보다 사방 2만큼 크다")
	t.eq(_rect_col(spy, Look.MINIMAP_BG), frame, "바탕은 지도 그대로다")
	# The camera box: a quarter in, half wide. `_c35` left `camera_rect` at its default, so this branch
	# never ran once in the whole round.
	t.ok(_rect_near(_rect_col(spy, Look.MINIMAP_CAMERA_COLOR),
			Rect2(at + Vector2(60.0, 33.75), Vector2(120.0, 67.5))),
			"카메라 상자는 화면이 보고 있는 만큼만 차지한다 (%s)"
					% str(_rect_col(spy, Look.MINIMAP_CAMERA_COLOR)))

	# The negative control for the `camera.size.x > 0.0` guard: an empty rect is what `_bind_world()`
	# leaves behind between runs, and drawing it would put a dot in the map's corner.
	spy.camera_rect = Rect2()
	spy.forget()
	await t.pump_frames(1)
	t.eq(_rects_col(spy, Look.MINIMAP_CAMERA_COLOR), 0, "대조: 카메라 사각형이 비어 있으면 상자는 안 그린다")
	t.eq(_rects_col(spy, Look.MINIMAP_BG), 1, "그래도 지도 자체는 그대로 그려진다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- 35c: the camera box may not leave the map ----------------------------------------------------------
## The box is the camera's rectangle mapped into map space, and **the camera routinely hangs off the
## field**: the host against the west edge at `Look.ZOOM_FAR` on a 1280-wide viewport puts
## `camera_rect.position.x` at −786, which maps ~49px LEFT of a 240px map — a bright bar drawn across the
## play area, every frame, with nothing else on this `Control` drawing outside its own rectangle.
##
## *Mutation: drop the `.intersection(frame)`.*
func _c35c_the_camera_box_is_clipped(t) -> void:
	var w := World.new()
	w.setup(103)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1

	var spy := MapSpy.new()
	spy.world = w
	# 768px off the west edge, 108px down: the left fifth of the box is outside the field entirely.
	spy.camera_rect = Rect2(-768.0, 108.0, 1920.0, 1080.0)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	var frame: Rect2 = spy.maps[0]["frame"]
	var at: Vector2 = frame.position
	var box: Rect2 = _rect_col(spy, Look.MINIMAP_CAMERA_COLOR)
	# −768 maps to −48 and 1920 maps to 120, so the unclipped box would run from at.x−48 to at.x+72.
	t.ok(_rect_near(box, Rect2(at + Vector2(0.0, 6.75), Vector2(72.0, 67.5))),
			"필드 밖으로 나간 카메라 상자는 지도 가장자리에서 잘린다 (%s)" % str(box))
	t.ok(frame.encloses(box), "그래서 상자는 지도 안에 온전히 들어 있다 — 플레이 화면 위로 삐져나오지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- label / disc / cell helpers ------------------------------------------------------------------------
## A mark drawn at `p` with radius `r` in `col`. All three, or the check reads one column of the three the
## leaf was handed — which is exactly how the whole map could render blank.
func _mark_at(spy, p: Vector2, r: float, col: Color) -> bool:
	for e: Dictionary in spy.marks:
		if _near(e["p"], p) and absf(float(e["r"]) - r) < 0.01 and e["col"] == col:
			return true
	return false


func _marks_col(spy, col: Color) -> int:
	var n := 0
	for e: Dictionary in spy.marks:
		if e["col"] == col:
			n += 1
	return n


func _rect_col(spy, col: Color) -> Rect2:
	for e: Dictionary in spy.rects:
		if e["col"] == col:
			return e["r"]
	return Rect2()


func _rects_col(spy, col: Color) -> int:
	var n := 0
	for e: Dictionary in spy.rects:
		if e["col"] == col:
			n += 1
	return n


func _rect_near(a: Rect2, b: Rect2) -> bool:
	return _near(a.position, b.position) and _near(a.size, b.size)



func _texts(spy) -> Array:
	var out := []
	for e: Dictionary in spy.labels:
		out.append(e["text"])
	return out


func _has_text(spy, needle: String) -> bool:
	for e: Dictionary in spy.labels:
		if String(e["text"]) == needle:
			return true
	return false


func _label_p(spy, needle: String) -> Vector2:
	for e: Dictionary in spy.labels:
		if String(e["text"]) == needle:
			return e["p"]
	return Vector2.INF


func _disc_is(spy, at: Vector2, r: float, col: Color) -> bool:
	for e: Dictionary in spy.discs:
		if _near(e["p"], at) and absf(float(e["r"]) - r) < 0.01 and e["col"] == col:
			return true
	return false


func _cell_is(spy, at: Vector2, r: float, col: Color) -> bool:
	for e: Dictionary in spy.seen:
		if _near(e["p"], at) and absf(float(e["r"]) - r) < 0.01 and e["col"] == col:
			return true
	return false


# -- 35d: the ponds are on the map ------------------------------------------------------------------------
## **Every other mark on this map is a body; a pond is terrain**, and the two differences that come with
## that are what this check pins: it is not gated by `MINIMAP_SHOW_DIST`, and its radius is the real one
## scaled rather than a fixed dot. Both are erasable independently — a pond drawn at `MINIMAP_CREATURE_R`
## looks like a creature, and a pond hidden past 1600px makes the map answer a question nobody asked it.
##
## ⚠ **Every expected number is arithmetic on hand-written coordinates, never `_to_map` re-run.** 3840×2160
## onto 240×135 is exactly ×0.0625, so a pond of radius 160 is 10.0px on the map — read back symbolically
## it would move on both sides of the assertion and zeroing the scale would stay green, which is measured
## on this file's neighbour.
##
## ⚠ **And water goes in FIRST**, under every body. Asserted by index, because "both are in the array" is
## satisfied by an order that draws a pond over the host dot you are looking for.
func _c35d_water_is_on_the_map(t) -> void:
	var w := World.new()
	w.setup(103)
	_silence(w)
	_clear_terrain(w)

	var host := Vector2(1920.0, 1080.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	# Two ponds: one beside the host, one in the far corner — **3060px away**, which is nearly twice
	# `MINIMAP_SHOW_DIST`. If water were gated like a creature the second one would be missing.
	w.terrain.water_pos.append(Vector2(1920.0, 1440.0))
	w.terrain.water_radius.append(160.0)
	w.terrain.water_pos.append(Vector2(3600.0, 1920.0))
	w.terrain.water_radius.append(96.0)

	var spy := MapSpy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	var marks: Array = spy.marks
	var water := []
	for e: Dictionary in marks:
		if e["col"] == Look.MINIMAP_WATER_COLOR:
			water.append(e)
	t.eq(water.size(), 2, "웅덩이 둘이 다 지도에 있다 — 하나는 1600px 밖이고 그래도 그려진다")
	if water.size() != 2:
		t.root.remove_child(spy)
		spy.queue_free()
		return

	# The map's own rectangle, computed the same way the layout does — the marks below are absolute screen
	# coordinates and a map that piled into the corner would otherwise pass every offset assertion.
	var origin: Vector2 = spy.size - Look.MINIMAP_SIZE - Vector2.ONE * Look.MINIMAP_MARGIN
	var near: Dictionary = water[0]
	var far: Dictionary = water[1]
	t.ok((near["p"] as Vector2).distance_to(origin + Vector2(120.0, 90.0)) < 0.01,
			"가까운 웅덩이는 지도의 가로 한가운데, 세로 3분의 2 지점이다 (%s)" % str(near["p"]))
	t.ok(absf(float(near["r"]) - 10.0) < 0.001,
			"그리고 반지름 160px는 지도에서 10px다 — 고정된 점이 아니라 실제 크기다 (%.3f)" % float(near["r"]))
	t.ok((far["p"] as Vector2).distance_to(origin + Vector2(225.0, 120.0)) < 0.01,
			"먼 웅덩이도 제자리에 있다 (%s)" % str(far["p"]))
	t.ok(absf(float(far["r"]) - 6.0) < 0.001,
			"그 96px는 6px다 — 둘의 반지름이 서로 다르다 (%.3f)" % float(far["r"]))
	t.ok(float(near["r"]) != Look.MINIMAP_CREATURE_R and float(far["r"]) != Look.MINIMAP_CREATURE_R,
			"대조: 어느 쪽도 생물 점 크기가 아니다 — 웅덩이는 몸이 아니다")

	# The host is the LAST mark and both ponds are before it: drawing order is the array's order.
	t.eq(marks[marks.size() - 1]["col"], Look.HOST_COLOR, "설정: 호스트는 여전히 맨 나중에 그려진다")
	t.eq(marks[0]["col"], Look.MINIMAP_WATER_COLOR, "그리고 물은 맨 처음에 — 모든 몸이 그 위에 얹힌다")

	t.root.remove_child(spy)
	spy.queue_free()


func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()


func _silence(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
