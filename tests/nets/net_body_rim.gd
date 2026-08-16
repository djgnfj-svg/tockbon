extends RefCounted
## **갈래 ㄴ: the filled body made legible, and whether the three marks it IS actually reach the screen.**
##
## `melee-legibility-ko` opens a fork nobody has decided. `net_body_style` covers the switch itself and 갈래
## ㄱ; this file covers the third value, `Look.BodyStyle.RIM`, whose whole content is three marks —
## **every body y-sorted into one pass · one dark stroke on each body's own silhouette · a ring on the ground
## under the host.** Pushes are deliberately not part of it: a push changes where bodies are over successive
## frames and the fork is decided from one photograph.
##
## Three things this file exists to make impossible, all of them named in CLAUDE.md:
##  · **a switch that changes nothing on screen while the round stays green** — so the order the spy received
##    is asserted as an exact sequence under 갈래 ㄴ and as today's fixed sequence under the other two
##  · **a merge that quietly drops work** — the three loops that became `_paint_clone`/`_paint_critter`/
##    `_paint_host` each carried something the others did not, and every one of those is driven here
##  · **an argument that was handed on and never used** — the rim's width, its inset radius and its transform
##    are each pinned against the body's own capture from the SAME frame
##
## ⚠ **`Look.BODY_STYLE` is a `static var`, so it is process-global and every check in this file shares one
## process.** Every function below puts it back to `FILL` before it returns.


## Every hook one frame of 갈래 ㄴ touches, captured into ONE ordered list as well as into its own. The list
## is not a convenience: "the rim came after its body" and "the host's ring came before every body" are
## claims about ORDER across different leaves, and three separate counts cannot make either of them.
class RimSpy extends FieldView:
	var order: Array = []
	var cells: Array = []
	var outlines: Array = []
	var arcs: Array = []
	var discs: Array = []
	var seg_lines: Array = []
	var bodies: Array = []
	var cones: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		var e := {"p": p, "r": r, "col": col, "squash": squash, "rot": rot}
		cells.append(e)
		order.append({"kind": "cell", "p": p, "r": r})
		super._paint_cell(c, p, r, col, squash, rot, corner)

	func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
			width: float, squash: Vector2, rot: float) -> void:
		outlines.append({"p": p, "r": r, "corner": corner, "col": col, "width": width,
				"squash": squash, "rot": rot})
		order.append({"kind": "outline", "p": p, "r": r})
		super._paint_outline(c, p, r, corner, col, width, squash, rot)

	func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
			width: float) -> void:
		arcs.append({"p": p, "r": r, "from": from, "to": to, "col": col, "width": width})
		order.append({"kind": "arc", "p": p, "r": r})
		super._paint_arc(c, p, r, from, to, col, width)

	func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		discs.append({"p": p, "r": r, "col": col})
		super._paint_disc(c, p, r, col)

	func _paint_part_line(c: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
		seg_lines.append({"a": a, "b": b, "width": width})
		super._paint_part_line(c, a, b, width, col)

	func _paint_body(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
			corner: float, outline_width: float, colour_depth: float, dot_radius: float,
			slot_part: PackedInt32Array) -> void:
		bodies.append({"p": p, "r": r, "corner": corner, "outline_width": outline_width,
				"slots": PackedInt32Array(slot_part)})
		super._paint_body(c, p, r, col, squash, rot, corner, outline_width, colour_depth, dot_radius,
				slot_part)

	func _paint_cone(c: CanvasItem, p: Vector2, dir: Vector2, range_px: float, arc: float,
			col: Color) -> void:
		cones.append({"p": p, "range_px": range_px, "arc": arc})
		order.append({"kind": "cone", "p": p, "r": range_px})
		super._paint_cone(c, p, dir, range_px, arc, col)

	func forget() -> void:
		order.clear()
		cells.clear()
		outlines.clear()
		arcs.clear()
		discs.clear()
		seg_lines.clear()
		bodies.clear()
		cones.clear()


func run(t) -> void:
	_n1_the_key_packing_holds(t)
	_n2_the_rim_width_at_literal_radii(t)
	await _n3_the_order_is_y_under_the_rim_and_fixed_otherwise(t)
	await _n4_the_order_survives_the_edges_of_the_field(t)
	await _n5_every_body_gets_one_rim_and_nothing_else_does(t)
	await _n6_the_host_ring_is_permanent_and_on_the_ground(t)
	await _n7_the_host_is_told_apart_by_a_shape_not_a_colour(t)
	await _n8_every_per_body_effect_survives_the_merge(t)
	await _n9_the_bite_cone_is_drawn_exactly_once_in_every_candidate(t)


# -- N1: the three values, and the bit layout the sort rests on ------------------------------------------
## `_body_order()` packs a body into `(depth << 10) | (kind << 8) | index`, so **an index that does not fit
## in eight bits silently aliases two bodies onto one key** — one of them then draws twice and the other
## never. The two table sizes are asserted rather than trusted, because the day one grows is the day this
## breaks with nothing on screen to say so.
func _n1_the_key_packing_holds(t) -> void:
	t.eq(Look.BODY_STYLE, Look.BodyStyle.LINE,
			"이 프로세스가 열릴 때 몸 스타일은 LINE이다 — 사용자가 고른 갈래이고, RIM이 기본값을 건드리지 않았다")
	t.ok(Look.BodyStyle.RIM != Look.BodyStyle.FILL and Look.BodyStyle.RIM != Look.BodyStyle.LINE,
			"설정: RIM은 앞의 두 값과 다른 값이다 — 같으면 아래 분기 검사는 전부 공짜로 통과한다")
	t.ok(Rules.POOL <= 256,
			"무리 배열은 %d칸이라 여덟 비트에 들어간다 — 넘으면 두 몸이 한 키로 겹친다" % Rules.POOL)
	t.ok(Rules.CRITTER_MAX <= 256,
			"크리터 배열도 %d칸이라 여덟 비트에 들어간다" % Rules.CRITTER_MAX)


# -- N2: the rim's width, at literal radii ---------------------------------------------------------------
## **A flat px cap AND a fraction cap, and a clamp is exactly the shape CLAUDE.md records as half-measured
## when only one end is bitten** — so both ends and the knee are pinned, with literals on both sides. The
## radii are the real ones: a 7px 다람쥐, an empty 8px clone, a fully loaded 12.8px clone, the 14px host and
## the 48px boss.
func _n2_the_rim_width_at_literal_radii(t) -> void:
	var f := FieldView.new()
	for pair in [[7.0, 1.26], [8.0, 1.44], [12.8, 2.0], [14.0, 2.0], [48.0, 2.0]]:
		var r: float = pair[0]
		var want: float = pair[1]
		t.ok(absf(f._rim_width(r) - want) < 0.0001,
				"반지름 %.1f의 림 굵기는 %.2fpx다 (리터럴) (%.4f)" % [r, want, f._rim_width(r)])
	t.ok(f._rim_width(7.0) < f._rim_width(8.0),
			"천장 밑에서는 작은 몸일수록 림이 가늘다 — 7px 몸에 2px는 지름의 절반을 먹는다")
	t.ok(f._rim_width(14.0) == f._rim_width(48.0),
			"천장 위에서는 보스도 호스트와 같은 굵기다 — 림은 몸을 따라 두꺼워지지 않는다")
	f.free()


# -- N3: the order the leaves were actually reached in ---------------------------------------------------
## **The whole of §A-1, and it is an ordering contract, so it is measured as a process and not as a final
## state.** Six bodies are staged at pinned y values chosen so the two orders are different sequences of the
## same six numbers: sorted they come out ascending, unsorted they come out clones (in index order), then
## creatures, then the host — which is exactly what `FieldView._paint` did before this candidate existed.
##
## Crows, not horses: `Rules.SPECIES_SPEED_MUL` is under 1.0 for the crow, so no afterimage ghost joins the
## cell count and the sequence is six entries long by construction.
func _n3_the_order_is_y_under_the_rim_and_fixed_otherwise(t) -> void:
	var w := _staged(140)
	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.cells.size(), 6, "설정: 한 프레임에 몸 여섯이 그려진다 (호스트 1 + 분신 3 + 까마귀 2)")
	var sorted_ys := _cell_ys(spy)
	t.eq(str(sorted_ys), str([600.0, 800.0, 1000.0, 1200.0, 1400.0, 1600.0]),
			"갈래 ㄴ에서는 몸이 y가 작은 것부터 그려진다 (리터럴 여섯) %s" % str(sorted_ys))
	var ascending := true
	for i in range(1, sorted_ys.size()):
		if sorted_ys[i] < sorted_ys[i - 1]:
			ascending = false
	t.ok(ascending, "그래서 남쪽 몸이 북쪽 몸 위에 온다 — 정렬을 빼면 여기가 빨강이다")

	# The other two candidates keep today's picture, and "today's picture" is a sequence, not a set.
	for style: int in [Look.BodyStyle.FILL, Look.BodyStyle.LINE]:
		Look.BODY_STYLE = style
		spy.forget()
		await t.pump_frames(1)
		var ys := _cell_ys(spy)
		t.eq(str(ys), str([1400.0, 600.0, 1200.0, 800.0, 1600.0, 1000.0]),
				"스타일 %d에서는 분신(색인 순) → 크리터 → 호스트 그대로다 — 지금 빌드의 순서다 %s"
						% [style, str(ys)])

	# **And back**, because a switch that only goes one way is not a switch.
	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)
	t.eq(str(_cell_ys(spy)), str([600.0, 800.0, 1000.0, 1200.0, 1400.0, 1600.0]),
			"다시 갈래 ㄴ로 돌리면 순서도 다시 y순이다")

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N4: a body far off the field still lands at the right end -------------------------------------------
## The depth is `y` biased into a positive range, so a body north of the field's origin and one far south of
## its edge are the two places a packing mistake shows up as "a stray clone on top of everything".
## ⚠ **The clamp itself is NOT bitten by this check and that is stated rather than implied** — at these
## distances an unclamped depth still sorts to the same end. What this measures is that the two extremes end
## up at the two ends, which is the property the picture rests on.
func _n4_the_order_survives_the_edges_of_the_field(t) -> void:
	var w := _staged(141)
	# Clone 2 far north, crow 1 far south, both well outside `Rules.FIELD` — so `view_rect` is widened, or
	# `_body_order` culls them before the sort ever sees them.
	w.swarm.pos[2] = Vector2(1820.0, -900.0)
	w.critter_pos[1] = Vector2(2400.0, 3900.0)
	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2(-4000.0, -4000.0), Vector2(12000.0, 12000.0))
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)
	var ys := _cell_ys(spy)
	t.eq(str(ys), str([-900.0, 800.0, 1000.0, 1200.0, 1400.0, 3900.0]),
			"필드 밖으로 나간 몸도 제 y 자리에 정렬된다 (리터럴 여섯) %s" % str(ys))

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N5: one rim per body, and nothing but a body gets one -----------------------------------------------
## §A-3's stroke. **Every clone, every creature, the host — and not food, not a corpse, not an afterimage
## ghost.** The negative half is the load-bearing one: a rim on a fading trail is three hard dark edges
## saying the opposite of what the trail says, and a rim on the ground under a corpse is a body that is not
## there. The fixture therefore carries both, plus a horse, whose three ghosts must NOT be counted.
func _n5_every_body_gets_one_rim_and_nothing_else_does(t) -> void:
	var w := _staged(142)
	var host: Vector2 = w.swarm.pos[0]
	# One food crumb and one corpse, both drawn through `_paint_cell` like a body — which is exactly why the
	# count below cannot simply be "one rim per cell".
	w.food.pos[0] = host + Vector2(300.0, 0.0)
	w.food.alive[0] = 1
	w.food.alive_count = 1
	w.corpse_count = 1
	w.corpse_pos[0] = host + Vector2(0.0, 300.0)
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = 3
	# A horse: `SPECIES_SPEED_MUL` is over 1.0, so it drags three afterimage ghosts through `_paint_cell`.
	w._write_critter(Parts.Species.HORSE, host + Vector2(500.0, 100.0), 30)

	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)
	# 3 분신 + 까마귀 둘 + 말 하나 + 호스트 = 7 몸, 그 위에 먹이 1 · 시체 1 · 말의 잔상 3 = 셀 열둘.
	t.eq(spy.cells.size(), 12, "설정: 셀은 열둘이다 (몸 일곱 + 먹이 · 시체 · 잔상 셋)")
	t.eq(spy.outlines.size(), 7,
			"림은 일곱 개다 — 몸에만 그어지고 먹이·시체·잔상에는 안 그어진다 %d" % spy.outlines.size())

	# **Each rim belongs to the body it was drawn right after.** Position, the inset radius, the width and the
	# transform are all read back against that body's OWN capture from the same frame — a rim that used a
	# literal, or `Vector2.ONE`, or the body's bare `r`, passes every count above and fails here.
	var matched := 0
	for o: Dictionary in spy.outlines:
		var body := _cell_at(spy, o["p"])
		if body.is_empty():
			continue
		var want_w: float = minf(2.0, float(body["r"]) * 0.18)
		if absf(float(o["width"]) - want_w) > 0.0001:
			continue
		if absf(float(o["r"]) - (float(body["r"]) - want_w * 0.5)) > 0.0001:
			continue
		if o["squash"] != body["squash"] or absf(float(o["rot"]) - float(body["rot"])) > 0.0001:
			continue
		matched += 1
	t.eq(matched, 7,
			"일곱 림이 전부 제 몸의 자리·굵기·안쪽 반지름·스쿼시·회전을 그대로 받았다 %d" % matched)

	# The empty clone, as literals on both sides: radius 8 → width 1.44 → stroke centred at 7.28.
	var clone_rim := _outline_at(spy, w.swarm.pos[1])
	t.ok(not clone_rim.is_empty(), "빈 분신에도 림이 하나 있다 %s" % str(spy.outlines))
	if not clone_rim.is_empty():
		t.ok(absf(float(clone_rim["width"]) - 1.44) < 0.0001,
				"그 굵기는 1.44px다 (8 × 0.18, 리터럴) (%.4f)" % float(clone_rim["width"]))
		t.ok(absf(float(clone_rim["r"]) - 7.28) < 0.0001,
				"그리고 8 - 1.44/2 = 7.28px 안쪽에 그어진다 — 몸보다 넓게 그리지 않는다 (%.4f)"
						% float(clone_rim["r"]))

	# ⚠ **The rim's COLOUR was captured above and asserted by nothing.** `Look.BODY_RIM_COLOR`'s own alpha is
	# measured in `net_numbers`, but that says nothing about what reaches the leaf: measured, handing
	# `Look.BODY_RIM_COLOR * 0.0` at `_paint_rim`'s one call site erased all seven rims — 갈래 ㄴ's middle
	# mark — with 2617 checks green and stderr clean, because every count, radius and transform above stays
	# exactly right. Pinned to the constant itself, and the alpha floor asserted beside it so a constant
	# quietly faded to nothing cannot satisfy the equality alone.
	var tinted := 0
	for o: Dictionary in spy.outlines:
		if o["col"] == Look.BODY_RIM_COLOR:
			tinted += 1
	t.eq(tinted, 7,
			"일곱 림이 전부 BODY_RIM_COLOR 그대로 그어졌다 — 투명하게 넘겨도 개수와 자리는 안 변한다 %d"
					% tinted)
	t.ok(Look.BODY_RIM_COLOR.a > 0.2,
			"그 색의 알파는 %.2f다 — 상수끼리만 비교하면 0으로 바래도 통과하므로 여기서 따로 잰다"
					% Look.BODY_RIM_COLOR.a)

	# **Order, not just count**: the rim is drawn in its body's own slot, immediately after it. A slot later
	# and it separates the wrong pair; before it and the fill covers it.
	var right_after := 0
	for i in range(1, spy.order.size()):
		var e: Dictionary = spy.order[i]
		if String(e["kind"]) != "outline":
			continue
		var prev: Dictionary = spy.order[i - 1]
		if String(prev["kind"]) == "cell" and prev["p"] == e["p"]:
			right_after += 1
	t.eq(right_after, 7, "일곱 림이 전부 제 몸 바로 다음에 그려졌다 — 한 칸 뒤면 남의 몸을 가른다")

	# The negative half, and it is what makes the seven mean anything.
	for style: int in [Look.BodyStyle.FILL, Look.BodyStyle.LINE]:
		Look.BODY_STYLE = style
		spy.forget()
		await t.pump_frames(1)
		t.eq(spy.outlines.size(), 0,
				"부정 대조: 스타일 %d에서는 림이 하나도 안 그어진다 — 지금 빌드의 그림이 안 바뀐다" % style)
		t.eq(spy.cells.size(), 12, "설정: 그런데도 같은 열두 셀이 그려졌다 (스타일 %d)" % style)

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N6: the host's ring, on the ground, every frame -----------------------------------------------------
## §A-3's permanent mark. **Permanent is the claim**, so it is driven over three separate frames with no
## world state touched between them, and its place in the order is asserted as well as its size: a ring drawn
## after the bodies is a UI element over the fight, which is a different picture and a decision nobody made.
func _n6_the_host_ring_is_permanent_and_on_the_ground(t) -> void:
	var w := _staged(143)
	var host: Vector2 = w.swarm.pos[0]
	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	for frame in 3:
		spy.forget()
		await t.pump_frames(1)
		# Nobody is striking, the `F` charge is zero and no corpse is being eaten, so the host's own ring is
		# the only arc on screen — which is what lets the count be a literal.
		t.eq(spy.arcs.size(), 1, "%d번째 프레임에도 호는 하나뿐이다 — 아무 조건에도 안 걸린다 %s"
				% [frame + 1, str(spy.arcs)])
		if spy.arcs.size() == 1:
			var a: Dictionary = spy.arcs[0]
			t.eq(a["p"], host, "그 호는 호스트 자리에 있다")
			t.ok(absf(float(a["r"]) - 30.8) < 0.001,
					"반지름은 30.8px다 (14 × 2.2, 리터럴) (%.3f)" % float(a["r"]))
			t.ok(absf(float(a["width"]) - 2.0) < 0.001,
					"굵기는 2.0px다 — 0이면 계산은 맞고 화면에는 아무것도 없다 (%.3f)" % float(a["width"]))
			t.ok(absf(float(a["to"]) - float(a["from"]) - TAU) < 0.001,
					"그리고 한 바퀴 다 도는 링이다 — 조각난 호가 아니다 (%.4f)"
							% (float(a["to"]) - float(a["from"])))
			t.ok(float(a["col"].a) > 0.2,
					"실제로 보이는 알파로 그려진다 (%.2f) — 색을 상수끼리 비교하면 0도 통과한다"
							% float(a["col"].a))

	# **On the GROUND**: before every body in the same frame's ordered list.
	var arc_at := -1
	var first_cell := -1
	for i in spy.order.size():
		var e: Dictionary = spy.order[i]
		if String(e["kind"]) == "arc" and arc_at < 0:
			arc_at = i
		elif String(e["kind"]) == "cell" and first_cell < 0:
			first_cell = i
	t.ok(arc_at >= 0 and first_cell >= 0, "설정: 호도 몸도 실제로 그려졌다 (%d, %d)" % [arc_at, first_cell])
	t.ok(arc_at < first_cell,
			"호스트 표시는 모든 몸보다 먼저 그려진다 — 발밑이지 몸 위에 얹은 UI가 아니다 (%d < %d)"
					% [arc_at, first_cell])

	# The negative control: the other two candidates have no permanent host mark at all, which is precisely
	# what `melee-legibility-ko` counts as zero in today's build.
	for style: int in [Look.BodyStyle.FILL, Look.BodyStyle.LINE]:
		Look.BODY_STYLE = style
		spy.forget()
		await t.pump_frames(1)
		t.eq(spy.arcs.size(), 0,
				"부정 대조: 스타일 %d에는 호스트 표시가 없다 — 항구적인 표시가 0개라는 그 그림이다" % style)

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N7: told apart by a SHAPE, and colour is the reason it had to be ------------------------------------
## `Look.CLONE_LOADED_COLOR` is brighter than `HOST_COLOR` in both red and green and a loaded clone's drawn
## radius is over 90% of the host's — so "the brightest, biggest one is me" answers **wrong** and then nearly
## ties. This check drives exactly that frame: a fully loaded clone standing beside the host, both captured,
## with the ring as the only thing that separates them.
func _n7_the_host_is_told_apart_by_a_shape_not_a_colour(t) -> void:
	var w := _staged(144)
	var host: Vector2 = w.swarm.pos[0]
	w.swarm.pos[1] = host + Vector2(40.0, 0.0)
	w.swarm.carried[1] = Look.CLONE_LOAD_FULL
	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)

	var loaded := _cell_at(spy, host + Vector2(40.0, 0.0))
	var me := _cell_at(spy, host)
	t.ok(not loaded.is_empty() and not me.is_empty(), "설정: 꽉 실은 분신과 호스트가 둘 다 그려졌다")
	if not loaded.is_empty() and not me.is_empty():
		# **The premise, driven rather than quoted.** If either of these ever stops being true the mark below
		# is answering a question nobody is asking any more, and this is where that shows up.
		var lc: Color = loaded["col"]
		var hc: Color = me["col"]
		# ⚠ **The host's own drawn colour was pinned by NOTHING in the whole round, and `>=` is satisfied by
		# the two being equal — so the premise below could be met by destroying the very thing it is the
		# premise for.** Measured: `_paint_host`'s `Look.HOST_COLOR` replaced with `Look.CLONE_LOADED_COLOR`
		# left 2617 checks green in every candidate, with the host painted as a fat clone. `_paint_host` has
		# no style branch for colour, so pinning it here holds for all three pictures. A bare body's
		# `colour_depth` is 0 and `Color.darkened(0.0)` is identity, which is why this is the constant itself
		# rather than a tone derived from it.
		t.eq(hc, Look.HOST_COLOR,
				"호스트는 제 색으로 칠해진다 — 분신 색으로 그려도 나머지 검사는 전부 통과한다 (%s)" % str(hc))
		t.eq(lc, Look.CLONE_LOADED_COLOR,
				"꽉 실은 분신은 적재 색 그대로 칠해진다 (%s)" % str(lc))
		t.ok(lc != hc,
				"그리고 둘은 서로 다른 색이다 — 같으면 아래 「더 밝다」는 주장이 공짜로 통과한다 (%s / %s)"
						% [str(lc), str(hc)])
		t.ok(lc.r > hc.r and lc.g > hc.g,
				"설정: 꽉 실은 분신이 호스트보다 밝다 — 색은 「어느 것이 나인가」에 거꾸로 답한다 (%s / %s)"
						% [str(lc), str(hc)])
		t.ok(float(loaded["r"]) / float(me["r"]) > 0.9,
				"설정: 크기도 호스트의 90%%를 넘는다 (%.3f) — 크기도 못 가른다"
						% (float(loaded["r"]) / float(me["r"])))
		t.ok(float(loaded["r"]) < 30.8,
				"그런데 발밑 링(30.8px)은 그 분신(%.1fpx)보다 훨씬 크다 — 링의 주인을 헷갈릴 수 없다"
						% float(loaded["r"]))

	# One ring on the field, not one per body: forty clones with forty rings is not a host mark.
	t.eq(spy.arcs.size(), 1, "링은 필드에 하나뿐이다 — 분신은 하나도 못 받는다 %s" % str(spy.arcs))
	if spy.arcs.size() == 1:
		t.eq(spy.arcs[0]["p"], host, "그 하나는 호스트의 것이다 — 분신 자리가 아니다")

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N8: nothing the three loops carried was lost in the merge -------------------------------------------
## **The whole risk of turning three loops into one ordered pass.** Each of them carried work the others did
## not, and a merge that kept the bodies and dropped the rest would pass every ordering check above. Every
## one is driven here, in one frame, under 갈래 ㄴ.
func _n8_every_per_body_effect_survives_the_merge(t) -> void:
	var w := _staged(145)
	var host: Vector2 = w.swarm.pos[0]
	# A clone that is fully loaded, has just been hit, and has just swung.
	var loaded_at := host + Vector2(60.0, 0.0)
	w.swarm.pos[1] = loaded_at
	w.swarm.carried[1] = Look.CLONE_LOAD_FULL
	w.swarm.hit_show[1] = 0.0
	w.swarm.swing_show[1] = 0.0
	w.swarm.swing_dir[1] = Vector2(1.0, 0.0)
	# A crow that has just been hit, from the east.
	var crow_at: Vector2 = w.critter_pos[0]
	w.critter_hit_show[0] = 0.0
	w.critter_hit_dir[0] = Vector2(1.0, 0.0)
	# A horse, for the afterimages.
	w._write_critter(Parts.Species.HORSE, host + Vector2(500.0, 100.0), 30)
	var horse_at: Vector2 = w.critter_pos[2]

	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)

	# 1) the clone's cargo colour and cargo radius.
	var fat := _cell_at(spy, loaded_at)
	var empty := _cell_at(spy, w.swarm.pos[2])
	t.ok(not fat.is_empty() and not empty.is_empty(), "설정: 실은 분신과 빈 분신이 둘 다 그려졌다")
	if not fat.is_empty() and not empty.is_empty():
		t.ok(absf(float(fat["r"]) - 12.8) < 0.001,
				"실은 분신은 12.8px로 그려진다 (8 × 1.6, 리터럴) (%.3f)" % float(fat["r"]))
		t.ok(float(fat["r"]) > float(empty["r"]), "빈 분신보다 크다 — 적재량이 크기로 읽힌다")
		t.ok(fat["col"] != empty["col"], "그리고 색도 다르다 — 적재 색 lerp이 합쳐지면서 사라지지 않았다")

	# 2) the clone's hit flash. Driven against the SAME clone with the flash off, so the comparison cannot be
	# satisfied by two different clones simply having different cargo.
	var flashed: Color = fat["col"] if not fat.is_empty() else Color(0.0, 0.0, 0.0, 0.0)
	w.swarm.hit_show[1] = 99.0
	spy.forget()
	await t.pump_frames(1)
	var calm := _cell_at(spy, loaded_at)
	t.ok(not calm.is_empty() and calm["col"] != flashed,
			"맞은 분신의 색이 안 맞은 프레임과 다르다 — 분신의 피격 깜빡임이 살아 있다 (%s / %s)"
					% [str(flashed), str(calm["col"] if not calm.is_empty() else "")])
	w.swarm.hit_show[1] = 0.0

	# 3) the clone's swing line, at literal endpoints (8 × 1.8 = 14.4px east of the body).
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.seg_lines.size(), 1, "휘두른 분신 하나가 선 하나를 남긴다 %s" % str(spy.seg_lines))
	if spy.seg_lines.size() == 1:
		var seg: Dictionary = spy.seg_lines[0]
		t.ok(seg["a"].distance_to(loaded_at) < 0.02, "그 선은 분신에서 시작하고")
		t.ok(seg["b"].distance_to(loaded_at + Vector2(27.2, 0.0)) < 0.02,
				"27.2px 뻗는다 (8 × 3.4, 리터럴) %s" % str(seg))

	# 4) the creature's hit flash and its spark. The crow at force 10 draws at 15px, so the struck surface is
	# 15px back along the hit direction and the spark opens at its full 6px.
	var spark_at := crow_at - Vector2(15.0, 0.0)
	var spark := _disc_at(spy, spark_at)
	t.ok(not spark.is_empty(), "맞은 크리터의 표면에 스파크가 찍힌다 (%s) %s" % [str(spark_at), str(spy.discs)])
	if not spark.is_empty():
		t.ok(absf(float(spark["r"]) - 16.0) < 0.001,
				"그 스파크는 16.0px에서 시작한다 (리터럴) (%.3f)" % float(spark["r"]))
	var crow_cell := _cell_at(spy, crow_at)
	t.ok(not crow_cell.is_empty() and crow_cell["col"] != Look.CROW_COLOR,
			"그리고 그 크리터의 색이 제 종 색에서 흰쪽으로 섞여 있다 — 피격 깜빡임이 살아 있다")

	# 5) the horse's afterimages: three ghosts, at 13.2px steps behind it, all translucent.
	var ghosts := 0
	for e: Dictionary in spy.cells:
		if e["p"] == horse_at or absf(float(e["r"]) - 22.0) > 0.001:
			continue
		var d: float = e["p"].distance_to(horse_at)
		for n in 3:
			if absf(d - 13.2 * float(n + 1)) < 0.05 and float(e["col"].a) < 1.0:
				ghosts += 1
	t.eq(ghosts, 3, "말은 잔상 셋을 13.2px 간격으로 끌고 다닌다 (22 × 0.6, 리터럴) %d" % ghosts)

	# 6) the host's own eleven-argument `_paint_body`.
	t.eq(spy.bodies.size(), 1, "호스트 하나만 _paint_body를 지난다 — 분신에게는 몸이 없다")
	if spy.bodies.size() == 1:
		var b: Dictionary = spy.bodies[0]
		t.eq(b["p"], host, "그 몸은 sim의 호스트 좌표 그대로다")
		t.ok(absf(float(b["r"]) - 14.0) < 0.001, "그리고 sim의 반지름 그대로다 (%.3f)" % float(b["r"]))
		t.eq(int(b["slots"].size()), 11, "열한 칸이 통째로 그리는 쪽까지 건너간다")

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- N9: the one mark y-sorting would have buried --------------------------------------------------------
## The bite cone is the single melee mark the user has already said is fine, so 갈래 ㄴ lifts it out of the
## host's slot into the overlay. **Two call sites with complementary guards is exactly the shape that draws
## twice or not at all**, so the count is pinned in every candidate and the position in the order is pinned
## in two of them.
func _n9_the_bite_cone_is_drawn_exactly_once_in_every_candidate(t) -> void:
	var w := _staged(146)
	var host: Vector2 = w.swarm.pos[0]
	# A creature to the SOUTH of the host: sorted, it draws after the host and would cover a cone left in the
	# host's slot. That is the whole reason the cone moves.
	w.critter_pos[0] = host + Vector2(0.0, 40.0)
	w.food.pos[0] = host + Vector2(50.0, 0.0)
	w.food.alive[0] = 1
	w.food.alive_count = 1
	w.swarm.step(1.0 / 60.0, w.food)
	t.ok(w.body.fire(0, host + Vector2(400.0, 0.0)), "설정: 좌클릭이 나갔다")
	t.eq(w.swarm.bite_show, 0.0, "설정: 원뿔 시계가 0에서 다시 시작했다")

	var spy := RimSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	for style: int in [Look.BodyStyle.FILL, Look.BodyStyle.LINE, Look.BodyStyle.RIM]:
		Look.BODY_STYLE = style
		spy.forget()
		await t.pump_frames(1)
		t.eq(spy.cones.size(), 1,
				"스타일 %d에서 원뿔은 정확히 하나 그려진다 — 두 자리에서 부르지만 조건이 배타적이다" % style)
		if spy.cones.size() == 1:
			t.eq(spy.cones[0]["p"], host, "그 원뿔의 꼭짓점은 호스트다 (스타일 %d)" % style)
			t.eq(spy.cones[0]["range_px"], w.swarm.bite_range,
					"길이도 sim이 잰 사거리 그대로다 (스타일 %d)" % style)

	# Where it landed, and the two candidates answer differently on purpose.
	Look.BODY_STYLE = Look.BodyStyle.RIM
	spy.forget()
	await t.pump_frames(1)
	t.ok(_index_of(spy, "cone") > _last_index_of(spy, "cell"),
			"갈래 ㄴ에서는 원뿔이 모든 몸 뒤에 그려진다 — 남쪽 크리터에 안 깔린다 (%d > %d)"
					% [_index_of(spy, "cone"), _last_index_of(spy, "cell")])

	Look.BODY_STYLE = Look.BodyStyle.FILL
	spy.forget()
	await t.pump_frames(1)
	var cone_at := _index_of(spy, "cone")
	var host_cell := _last_index_of(spy, "cell")
	t.ok(cone_at < host_cell,
			"지금 빌드에서는 원뿔이 호스트 밑에 남는다 — 그 그림이 안 바뀐다 (%d < %d)"
					% [cone_at, host_cell])
	t.ok(cone_at > 0, "그러면서도 크리터 위에는 있다 — 첫 몸보다는 뒤다 (%d)" % cone_at)

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- fixture ---------------------------------------------------------------------------------------------
## Six bodies at pinned positions and an empty field, so every count and every y above is a literal rather
## than a function of the spawner's randomness. **Crows, not horses**: the crow's `SPECIES_SPEED_MUL` is
## under 1.0, so no afterimage ghost joins the cell count unless a check asks for one.
##
## The y values are chosen so that "sorted by y" and "clones, then creatures, then the host" are two
## different sequences of the same six numbers — an ordering claim measured against a fixture where the two
## orders agree measures nothing.
func _staged(seed_n: int) -> World:
	var w := World.new()
	w.setup(seed_n)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
	w.corpse_count = 0
	w.critter_count = 0
	w.boss_index = -1
	w.swarm.pos[0] = Vector2(1920.0, 1000.0)
	var ys := [1400.0, 600.0, 1200.0]
	for j in ys.size():
		var k := w.swarm.add_clone()
		w.swarm.pos[k] = Vector2(1920.0 - 100.0 * float(j + 1), float(ys[j]))
		w.swarm.vel[k] = Vector2.ZERO
	w.swarm.vel[0] = Vector2.ZERO
	# ⚠ **One clone is given a velocity on purpose.** Every other body in the fixture stands still, so its
	# squash is `Vector2.ONE` and its heading 0 — and a rim handed `Vector2.ONE`/`0.0` instead of the body's
	# own transform would then be indistinguishable from a correct one. This is the body that makes N5's
	# transform assertion able to fail.
	w.swarm.vel[1] = Vector2(0.0, 400.0)
	w._write_critter(Parts.Species.CROW, Vector2(2200.0, 800.0), 10)
	w._write_critter(Parts.Species.CROW, Vector2(2400.0, 1600.0), 10)
	return w


## The y of every body drawn this frame, in the order the leaf received them. Floats, so the comparison
## against a literal array is exact — every y in the fixture is written as a whole number.
func _cell_ys(spy: RimSpy) -> Array:
	var out := []
	for e: Dictionary in spy.cells:
		out.append(e["p"].y)
	return out


func _cell_at(spy: RimSpy, at: Vector2) -> Dictionary:
	for e: Dictionary in spy.cells:
		if e["p"].distance_to(at) < 0.02:
			return e
	return {}


func _outline_at(spy: RimSpy, at: Vector2) -> Dictionary:
	for e: Dictionary in spy.outlines:
		if e["p"].distance_to(at) < 0.02:
			return e
	return {}


func _disc_at(spy: RimSpy, at: Vector2) -> Dictionary:
	for e: Dictionary in spy.discs:
		if e["p"].distance_to(at) < 0.05:
			return e
	return {}


func _index_of(spy: RimSpy, kind: String) -> int:
	for i in spy.order.size():
		if String(spy.order[i]["kind"]) == kind:
			return i
	return -1


func _last_index_of(spy: RimSpy, kind: String) -> int:
	var out := -1
	for i in spy.order.size():
		if String(spy.order[i]["kind"]) == kind:
			out = i
	return out
