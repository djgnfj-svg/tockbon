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

	## `squash` and `rot` joined the signature with 갈래 ㄴ's rim — Godot rejects an override that does not
	## match, so this shape is forced by the file rather than chosen.
	func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
			width: float, squash: Vector2, rot: float) -> void:
		outlines.append({"p": p, "r": r, "corner": corner, "width": width, "squash": squash, "rot": rot})
		super._paint_outline(c, p, r, corner, col, width, squash, rot)

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
		# `col_a` is kept SEPARATE from `col` on purpose: an assertion that the captured colour equals the
		# constant it came from moves both sides when the constant moves, which is how `Color(0, 0, 0, 0)`
		# stayed green. Checks that want the hue compare against a lerp of two constants computed from a
		# value the fixture DROVE (a clone's `carried`, a creature's species), which does not move with it.
		arcs.append({"p": p, "r": r, "from": from, "to": to, "width": width, "col_a": col.a, "col": col})
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


## §6: the per-species attack gesture, captured across **all three leaves a gesture can reach, in one spy**.
## A spy on a single leaf cannot answer the question this feature is: 까마귀 draws two lines, 들쥐 draws a
## disc, 보스 draws an arc, and the whole claim is that two species swinging in the same frame do not reach
## the screen with the same arguments. Three separate spies would give three counts and no way to say the
## seven marks belong to seven different creatures.
##
## ⚠ **`_paint_cell` rides along and it is not decoration.** The LUNGE is carried by the body's own drawn
## position and by nothing else — `Look.SPECIES_LUNGE_MUL` is the elephant's and the lion's entire gesture
## in one of its two halves, and no gesture leaf ever sees it.
class SwingSpy extends FieldView:
	var lines: Array = []
	var discs: Array = []
	var arcs: Array = []
	var cells: Array = []

	func _paint_part_line(c: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
		lines.append({"a": a, "b": b, "width": width, "col": col})
		super._paint_part_line(c, a, b, width, col)

	func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		discs.append({"p": p, "r": r, "col": col})
		super._paint_disc(c, p, r, col)

	func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
			width: float) -> void:
		arcs.append({"p": p, "r": r, "from": from, "to": to, "width": width, "col_a": col.a})
		super._paint_arc(c, p, r, from, to, col, width)

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		cells.append({"p": p, "r": r})
		super._paint_cell(c, p, r, col, squash, rot, corner)

	func forget() -> void:
		lines.clear()
		discs.clear()
		arcs.clear()
		cells.clear()


## §B-1: the monster hit flash and its spark. Both go through leaves that already have spies of their own —
## `_paint_cell` and `_paint_disc` — captured together here because the two checks (colour mixed vs. colour
## painted, spark present vs. absent) are read off the SAME frame.
class HitSpy extends FieldView:
	var seen: Array = []
	var discs: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		seen.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot, corner)

	func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		discs.append({"p": p, "r": r, "col": col})
		super._paint_disc(c, p, r, col)


## §E: what order things actually landed on screen in, across THREE different leaves at once. A spy on any
## one leaf alone cannot answer "before" or "after" a different kind of draw — three separate counts of 2,
## 1 and 1 say nothing about which came first. One shared, ordered list is what a position claim needs.
class OrderSpy extends FieldView:
	var order: Array = []

	func _paint_disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		order.append({"kind": "disc", "p": p})
		super._paint_disc(c, p, r, col)

	func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
			width: float) -> void:
		order.append({"kind": "arc", "p": p, "r": r, "width": width})
		super._paint_arc(c, p, r, from, to, col, width)

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		order.append({"kind": "cell", "p": p})
		super._paint_cell(c, p, r, col, squash, rot, corner)


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
	await _p4_the_half_eaten_corpse_shrinks(t)
	await _t6_the_drawn_ground_is_the_sim_s(t)
	await _c31_c32_c33_labels(t)
	await _p3_the_label_is_centred(t)
	await _u16c_the_cluster_centroid_is_the_mean(t)
	await _c35_minimap(t)
	await _c35b_what_is_on_the_map(t)
	await _c35c_the_camera_box_is_clipped(t)
	await _c35d_water_is_on_the_map(t)
	await _b1_monster_hit_flash(t)
	await _d2_boss_pulse(t)
	await _e_wall_reads_the_live_radius(t)
	await _e_wall_persists_every_frame_after_closing(t)
	await _e_draw_order_floor_before_bodies(t)
	await _e_summon_rings_at_the_arrival_point(t)
	await _b3_clone_hit_flash_uses_cargo_colour(t)
	await _b3_b4_death_bursts_persist_and_fade(t)
	await _b3_view_does_not_clear_died_this_frame(t)
	await _b5_clone_swing_line(t)
	await _f7_food_pop_is_small_and_travels(t)
	await _f9_level_pop_differs_from_absorb_pop(t)
	await _f10_split_ring_at_the_split_point(t)
	await _f12_afterimage_gated_by_species(t)
	await _p13_every_species_reaches_the_screen(t)
	await _p14_every_species_reaches_the_minimap(t)
	await _p15_every_species_swings_its_own_shape(t)
	await _p16_the_clone_swing_is_not_a_creatures(t)


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

	# 1 호스트 + 4 분신 + 3 먹이 + 2 생물 + 1 시체 + 말의 잔상 셋(§F-12: HORSE_SPEED_MUL 1.15 > 1.0, 까마귀는
	# 0.55라 잔상이 없다). Every term a literal.
	t.eq(spy.seen.size(), 14,
			"호스트·분신 넷·먹이 셋·생물 둘·시체 하나·말의 잔상 셋이 전부 그려졌다 (1+4+3+2+1+3)")

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
	# ⚠ **더 이상 0이 아니다 — §F-10이 갈라진 자리에 링을 하나 더 그린다** (`_paint_ring`도 `_paint_arc`를
	# 두 번 부른다). 그래서 이 검사는 「감김 호 자체가 없다」로 좁힌다: 그 반지름
	# (`Rules.BODY_RADIUS * Look.SPLIT_CHARGE_RING`)을 가진 호가 하나도 없으면 감김 호는 비워진 것이다 —
	# §F-10의 새 링과 혼동하지 않는다.
	var charge_r := Rules.BODY_RADIUS * Look.SPLIT_CHARGE_RING
	var charge_ring_found := false
	for e: Dictionary in spy.arcs:
		if absf(float(e["r"]) - charge_r) < 0.01:
			charge_ring_found = true
	t.ok(not charge_ring_found,
			"갈라진 그 순간 감김 호가 비워진다 — 떼기를 기다리지 않는다 %s" % str(spy.arcs))

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
		# ⚠ **12.0, not 14.0, since 갈래 ㄴ's rim landed.** The stroke is centred at `r - width * 0.5`, so
		# its OUTER edge lands exactly on the body's own 14 — a stroke centred on 14 straddles it and the
		# drawn body ends up wider than the circle the sim collides with.
		t.ok(absf(float(o["r"]) - 12.0) < 0.001,
				"그리고 몸의 반지름 안쪽을 따라 그려진다 — 14 - 4/2 = 12px (리터럴) (%.3f)" % float(o["r"]))
		t.ok(absf(float(o["corner"]) - 0.34) < 0.0001, "몸의 실루엣을 그대로 따라간다 (모서리 0.34)")
	var hide_col: Color = _cell_col(spy, w.swarm.pos[0], 14.0)
	t.ok(hide_col != base_col, "가죽이 몸에 실제로 칠해지는 색을 바꾼다")
	t.ok(_near_col(hide_col, base_col.darkened(0.2)),
			"그 색은 맨 몸 색을 0.2만큼 어둡게 한 것이다 (리터럴) (%s / %s)"
					% [str(hide_col), str(base_col.darkened(0.2))])
	w.body.slot_level[Parts.Slot.HIDE] = 0

	# -- eyes: the one internal slot that adds marks, and the number IS the radius -----------------------
	# ⚠ **Both drawing branches are driven here, explicitly, and neither is left to the default.** This slot
	# is the one place the two candidates disagree about WHAT to draw rather than how: FILL puts a mirrored
	# PAIR on the body's face, LINE puts ONE nucleus at the centre — the shape
	# `the-body-is-a-line-drawn-by-code` decided, with the pair on that same doc's rejected list. The default
	# is LINE since the user picked it, so reading whatever is current would leave FILL's pair unmeasured;
	# reading only FILL is what left LINE unmeasured until the default moved and four checks went red at once.
	var eyes_style_was := Look.BODY_STYLE
	Look.BODY_STYLE = Look.BodyStyle.FILL
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

	# The other branch: ONE dot, at the body's own centre, and the slot's level still reaches it. The radius
	# is `_outline_dot_r(14, dot_radius)` = `max(14 × (0.22 + dot_radius), 2.0)` — pinned as literals, since
	# written as the expression it would move with the constants it exists to hold still.
	Look.BODY_STYLE = Look.BodyStyle.LINE
	w.body.slot_level[Parts.Slot.EYES] = 1
	var nuc1: Dictionary = await _capture(t, spy)
	t.ok(absf(float(nuc1["dot_radius"]) - 0.17) < 0.0001,
			"선 갈래에서도 같은 인자가 건너간다 (0.17) (%.4f)" % float(nuc1["dot_radius"]))
	t.eq(spy.dots.size(), 1, "선 갈래의 눈은 한 쌍이 아니라 가운데 점 하나다 — 두 점 눈은 기각된 안이다")
	t.ok(_has_dot(spy.dots, w.swarm.pos[0], 5.46),
			"그 점은 몸 한가운데에 반지름 5.46px로 찍힌다 (리터럴) %s" % str(spy.dots))
	w.body.slot_level[Parts.Slot.EYES] = 3
	var nuc3: Dictionary = await _capture(t, spy)
	t.ok(absf(float(nuc3["dot_radius"]) - 0.27) < 0.0001,
			"선 갈래의 레벨도 인자로 건너간다 (0.27) (%.4f)" % float(nuc3["dot_radius"]))
	t.ok(_has_dot(spy.dots, w.swarm.pos[0], 6.86),
			"그리고 실제로 찍힌 점이 6.86px로 커진다 — 레벨이 화면에 닿는다 (리터럴) %s" % str(spy.dots))

	Look.BODY_STYLE = eyes_style_was
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


## The disc drawn at a given point, or an empty dictionary. **Located by position, never by index** — a hit
## draws two discs (the bloom at the body's centre, the spark on the struck surface) and reading `discs[0]`
## would pass unchanged if the two ever swapped places.
func _disc_at(spy, at: Vector2) -> Dictionary:
	for e: Dictionary in spy.discs:
		if (e["p"] as Vector2).distance_to(at) < 0.05:
			return e
	return {}


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


# -- P13: EVERY row of `SPECIES_COLOR` actually reaches the screen ---------------------------------------
## ⚠ **`_p2` above names three species and stops, and that is how four more landed with their colours
## measured by nothing at all.** Naming the next four would close them and leave the twelfth open on the day
## it lands, so this walks `FieldView.SPECIES_COLOR`'s own length: **a row added to that table and never
## painted reddens here, and so does a row that is missing from it entirely** — the missing case is an
## index-out-of-range inside `_paint_critter`, which is a crash in play and a green round otherwise.
##
## Every creature is written at its species MINIMUM force, so `_radius_of`'s ramp is 0 and the drawn radius
## is `SPECIES_RADIUS[s]` exactly — the same device `_p2` and `net_overlap._o5` use, and it is what makes
## the radius assertable at all.
##
## ⚠ **Spread far enough apart that nothing overlaps anything**, because `_cell_is` matches on position and
## the fast rows (말·치타·토끼) each drag three afterimage ghosts BEHIND themselves. A ghost sits at a
## different position and a faded alpha, so an exact `Color ==` on the real body is what separates them.
func _p13_every_species_reaches_the_screen(t) -> void:
	var w := World.new()
	w.setup(96)
	_silence(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	var rows: int = FieldView.SPECIES_COLOR.size()
	t.eq(rows, Rules.SPECIES_RADIUS.size(),
			"설정: 색 표와 크기 표의 길이가 같다 — 다르면 아래 반복문이 있지도 않은 종을 그리려 든다 (%d)" % rows)
	var at: Array = []
	for s in rows:
		# ⚠ **340px apart, on a line that stays INSIDE the field.** `_body_order()` culls every creature
		# outside `view_rect`, and `view_rect` is the field here — a row laid out at x = -80 is not drawn at
		# all and this check would report the table's last species missing for a reason that is not the
		# table's. 340 clears the biggest body (보스 48) and the longest ghost tail
		# (말 22 × `AFTERIMAGE_GAP_RING` 0.6 × 3 = 40px) many times over.
		var p := Vector2(60.0 + float(s) * 340.0, host.y)
		at.append(p)
		w._write_critter(s, p, int(Rules.SPECIES_FORCE_MIN[s]))
	t.eq(w.critter_count, rows, "설정: 종마다 한 마리씩 세웠다")

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.seen.clear()
	await t.pump_frames(1)

	for s in rows:
		var col: Color = FieldView.SPECIES_COLOR[s]
		var r: float = float(Rules.SPECIES_RADIUS[s])
		t.ok(_cell_is(spy, at[s], r, col),
				"%d종은 제 종의 색으로, 제 종의 %.0fpx로 화면에 닿는다" % [s, r])

	# **And the colours are distinct**, or every assertion above is satisfied by one tone for the whole field
	# — the exact defect `_p2`'s own note was written against, at eleven rows instead of three.
	var distinct := {}
	for s in rows:
		distinct[str(FieldView.SPECIES_COLOR[s])] = true
	t.eq(distinct.size(), rows,
			"설정: 열한 색이 서로 다 다르다 — 두 종이 같은 색이면 위의 열한 줄은 아무것도 구분하지 않는다 (%d)"
					% distinct.size())

	t.root.remove_child(spy)
	spy.queue_free()


# -- P14: every row of `SPECIES_COLOR` reaches the MINIMAP too --------------------------------------------
## ⚠ **`_c35` and `_c35b` name 까마귀 · 보스 · 말 and stop**, so eight of the eleven species had never been
## on the map in any check. `FieldView.SPECIES_COLOR` has **two** readers — `_paint_critter` in the field and
## `Hud._minimap_marks()` in the HUD — and `_p13` above only walks the first. A colour that reaches the field
## and not the map is green today; so is a table short by one row, which is an index-out-of-range in a
## different file on a different frame from the one `_p13` drives.
##
## Driven over the table's own length, so a twelfth row reddens the day it lands — **and the length is also
## pinned to the literal 11**, because a table emptied to zero rows makes the loop below run zero times and
## reports a perfectly clean map. A loop whose condition is false from the start never runs the check.
##
## ⚠ **Every expected position is hand arithmetic on hand-written coordinates, never `_to_map` re-run.**
## The field is 3840×2160 and the map is 240×135, so the mapping is exactly ÷16. `_to_map` rewritten to
## `return frame.position` — every mark on one pixel — was measured green against a check that recomputed it.
##
## `boss_index` is left at **-1** on purpose. This asks whether the boss ROW's colour reaches the map through
## the ordinary distance-gated path, which is a different question from "the boss is shown however far away
## it is" — that one is `_c35`'s and it is already answered.
func _p14_every_species_reaches_the_minimap(t) -> void:
	const ROWS := 11
	## 3840/240 and 2160/135 are both exactly this. `Hud._minimap_marks` scales x and y separately; the two
	## agreeing is what makes one number legal here, and `_c35b` is where that is asserted.
	const MAP_SCALE := 16.0
	var w := World.new()
	w.setup(103)
	_silence(w)
	_clear_terrain(w)
	var host := Vector2(1920.0, 1080.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	var rows: int = FieldView.SPECIES_COLOR.size()
	t.eq(rows, ROWS, "설정: 색 표는 열한 줄이다 (리터럴) — 비면 아래 반복문이 한 번도 안 돌고 지도가 깨끗해 보인다")

	# 200px apart on a line through the host: the farthest is 1000px away, well inside `MINIMAP_SHOW_DIST`
	# 1600, and 200px is 12.5px on the map — six times `MINIMAP_CREATURE_R`, so no two dots are one dot.
	# Every creature is written at its species MINIMUM force; the map's dot is a fixed radius so that does
	# not matter here, but it keeps this fixture the same shape as `_p13`'s.
	var at: Array = []
	for s in rows:
		var p := Vector2(920.0 + float(s) * 200.0, 1080.0)
		at.append(p)
		t.ok(host.distance_to(p) < Look.MINIMAP_SHOW_DIST,
				"설정: %d종은 지도에 뜨는 거리 안에 서 있다 (%.0fpx)" % [s, host.distance_to(p)])
		# The row index is asserted to equal the species index, because the control at the bottom moves one
		# creature by `critter_pos[MOUSE]` and that is only the mouse while the two happen to coincide.
		t.eq(w._write_critter(s, p, int(Rules.SPECIES_FORCE_MIN[s])), s,
				"설정: %d종은 %d번 줄에 앉는다 — 아래의 대조가 그 줄을 종 번호로 집는다" % [s, s])
	t.eq(w.critter_count, rows, "설정: 종마다 한 마리씩 세웠다")

	var spy := MapSpy.new()
	spy.world = w
	spy.camera_rect = Rect2(1280.0, 720.0, 1280.0, 720.0)
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
	t.eq(frame.size, Vector2(240.0, 135.0), "설정: 지도는 240×135다 (리터럴) — ÷16이 성립하는 근거다")
	# Water is cleared and the swarm is one body, so the map holds exactly the eleven creatures and the host.
	# Without this the eleven assertions below would also pass on a map that drew a hundred stray dots.
	t.eq(spy.marks.size(), rows + 1, "지도에 찍힌 점은 열둘이다 — 종 열하나와 호스트 하나 (%d)"
			% spy.marks.size())

	for s in rows:
		var p: Vector2 = at[s]
		t.ok(_mark_at(spy, frame.position + p / MAP_SCALE, Look.MINIMAP_CREATURE_R,
						FieldView.SPECIES_COLOR[s]),
				"%d종은 제 종의 색으로 제자리에 지도에 찍힌다 — 화면과 지도는 같은 표를 읽는 두 파일이다" % s)

	# **The negative control, and it is aimed at a NEW row rather than at 까마귀.** Without it "지도는 전부
	# 그린다" satisfies all eleven lines above just as well as the gate does — and `_c35`'s control names the
	# crow, which is row 0 and was never the row at risk.
	var mouse := int(Parts.Species.MOUSE)
	w.critter_pos[mouse] = host + Vector2(Look.MINIMAP_SHOW_DIST + 300.0, 0.0)
	spy.forget()
	await t.pump_frames(1)
	t.eq(_marks_col(spy, FieldView.SPECIES_COLOR[mouse]), 0,
			"대조: 그 들쥐가 1900px 밖으로 나가면 지도에서 사라진다 — 지도는 방향이지 정보가 아니다")
	t.eq(spy.marks.size(), rows, "그래서 점은 하나 줄어 열하나다 (%d)" % spy.marks.size())

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
	# **Untouched: three of three bites left.** `resize()` zero-fills, and a corpse with 0 bites left draws at
	# `CORPSE_SHRINK_BASE` — the literal 18.0 below is the FULL-size ring, so the fixture has to say so.
	w.corpse_bites_left[0] = 3

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

	# **The ring shrinks WITH the drawn corpse, and the literal says by how much.** One bite of three left is
	# `0.45 + 0.55 / 3` = 0.6333, so the ring is `18 × 0.6333` = 11.4px. Left unshrunk it stays 18px around a
	# body drawn at 7.6px — a hoop 3.3× the corpse's diameter, floating in empty grass.
	w.corpse_bites_left[0] = 1
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 1, "한 입 남은 시체에도 호는 하나다 %s" % str(spy.arcs))
	if spy.arcs.size() == 1:
		t.ok(absf(float(spy.arcs[0]["r"]) - 11.4) < 0.05,
				"그 호는 줄어든 몸을 따라 11.4px로 줄어든다 (18 × (0.45 + 0.55/3), 리터럴) (%.3f)"
						% float(spy.arcs[0]["r"]))

	w.corpse_bites_left[0] = 3
	w.corpse_progress[0] = 0.0
	spy.arcs.clear()
	await t.pump_frames(1)
	t.eq(spy.arcs.size(), 0, "부정 대조: 아무도 안 먹은 시체에는 호가 없다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- P4: the half-eaten corpse shrinks, but its own `corpse_radius()` (the arc above reads it too) does not
## §C's own line: "그 셀의 반지름만 줄어든다" — what may NOT shrink is `World.corpse_radius()` itself, because
## `corpse_reach()` reads it and a half-eaten boss must stay as easy to keep eating as a whole one. The drawn
## cell and the progress ring around it both shrink (`_p1` pins the ring at both sizes). A corpse at 1 of 3 bites left
## draws smaller than a fresh one at 3 of 3, and BOTH are smaller than the bare `corpse_radius()` unless the
## bites are all still there (`CORPSE_SHRINK_BASE + CORPSE_SHRINK_RANGE = 0.45 + 0.55 = 1.0`, full size).
func _p4_the_half_eaten_corpse_shrinks(t) -> void:
	var w := World.new()
	w.setup(96)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at: Vector2 = w.swarm.pos[0] + Vector2(300.0, 0.0)
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	var full_r: float = w.corpse_radius(0)
	var total: int = w.corpse_bites_total(0)
	t.eq(total, 3, "설정: 까마귀 시체는 세 입이다")

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	# Fresh (3 of 3 bites): drawn at full size.
	w.corpse_bites_left[0] = 3
	spy.seen.clear()
	await t.pump_frames(1)
	t.ok(_cell_is(spy, at, full_r, Look.CORPSE_COLOR),
			"설정: 아직 손 안 댄 시체는 제 크기 그대로 그려진다 (%.2f)" % full_r)

	# One bite left: shrunk to the floor.
	w.corpse_bites_left[0] = 1
	var shrunk_r := full_r * (Look.CORPSE_SHRINK_BASE + Look.CORPSE_SHRINK_RANGE * (1.0 / 3.0))
	spy.seen.clear()
	await t.pump_frames(1)
	t.ok(shrunk_r < full_r, "설정: 계산된 반지름이 실제로 더 작다 (%.2f < %.2f)" % [shrunk_r, full_r])
	t.ok(_cell_is(spy, at, shrunk_r, Look.CORPSE_COLOR),
			"한 입 남은 시체는 더 작게 그려진다 (%.2f)" % shrunk_r)
	t.ok(not _cell_is(spy, at, full_r, Look.CORPSE_COLOR), "그리고 이제 제 크기로는 그려지지 않는다")

	# `corpse_radius()` itself never moved — the ring in `_p1` and `corpse_reach()` both still read the
	# WHOLE size regardless of how few bites are left.
	t.eq(w.corpse_radius(0), full_r, "sim의 corpse_radius()는 안 바뀐다 — 줄어드는 것은 그려지는 값뿐이다")

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


# -- §E: the arena wall reads Terrain's CURRENT radius, driven directly -----------------------------------
## **Driven, not grepped.** `terrain.arena_radius` is written by hand to two different values with
## `arena_closed` held true, and the drawn wall has to follow BOTH — a hook that read `Rules.ARENA_RADIUS`
## instead of `ground.arena_radius` would draw the same 900px ring either way, and one value alone could
## not tell the two apart.
func _e_wall_reads_the_live_radius(t) -> void:
	var w := World.new()
	w.setup(131)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var centre := w.swarm.pos[0] + Vector2(500.0, 0.0)
	w.terrain.arena_centre = centre
	w.terrain.arena_closed = true
	w.terrain.arena_radius = 450.0

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.arcs.clear()
	await t.pump_frames(1)

	# ⚠ **ONE circle, and the count is the assertion.** The wall went through `_paint_ring` for a plan, which
	# is the two-circle MARKER shape (`r` and `r × 0.45`) — on the shipped 900px arena that echo is a 405px
	# ring in the wall's own colour and width, straight across the fight, and a check that only asked "is
	# there an arc at 450" was satisfied by it. `_paint_arc` direct is the fix; this is what holds it.
	var at_centre := []
	for e: Dictionary in spy.arcs:
		if _near(e["p"], centre):
			at_centre.append(e)
	t.eq(at_centre.size(), 1, "아레나 벽은 원 하나다 — 표식의 안쪽 메아리 링이 따라오지 않는다 %s" % str(spy.arcs))
	if at_centre.size() == 1:
		var wall: Dictionary = at_centre[0]
		t.ok(absf(float(wall["r"]) - 450.0) < 0.01,
				"아레나 반지름을 손으로 450으로 두면 벽도 450으로 그려진다 (%.2f)" % float(wall["r"]))
		t.ok(absf(float(wall["to"]) - float(wall["from"]) - TAU) < 0.001,
				"그리고 한 바퀴 다 도는 원이다 — 부채꼴이 아니다")
		t.ok(float(wall["col_a"]) > 0.1, "실제로 보이는 알파로 그려진다 (%.2f)" % float(wall["col_a"]))
	for e: Dictionary in spy.arcs:
		t.ok(not (_near(e["p"], centre) and absf(float(e["r"]) - 450.0 * 0.45) < 0.01),
				"부정 대조: 반지름 202.5(= 450 × 0.45)짜리 안쪽 링은 그려지지 않는다")

	# A different value on the SAME world — a radius baked into the draw call would still read 450 (or the
	# constant 900) here; only a live read of `ground.arena_radius` follows the change.
	w.terrain.arena_radius = 220.0
	spy.arcs.clear()
	await t.pump_frames(1)
	var outer_220 := false
	for e: Dictionary in spy.arcs:
		if _near(e["p"], centre) and absf(float(e["r"]) - 220.0) < 0.01:
			outer_220 = true
	t.ok(outer_220, "반지름을 220으로 바꾸면 그려지는 벽도 220을 따라간다 — 고정된 900이 아니다 %s" % str(spy.arcs))
	t.ok(220.0 != 450.0 and absf(220.0 - Rules.ARENA_RADIUS) > 1.0,
			"설정: 두 값 다 ARENA_RADIUS(900)와도 서로와도 다르다 — 우연히 맞은 것이 아니다")

	# The stroke's WIDTH, on the ONE arc at the centre — never an ANY over a folded pair. While the wall was
	# two arcs, either of them could revert to the marker's default `RING_WIDTH` and the other's width kept
	# this green: CLAUDE.md's own "a dim-check folded two alphas into one array" shape, one file over.
	var walls_220 := []
	for e: Dictionary in spy.arcs:
		if _near(e["p"], centre):
			walls_220.append(e)
	t.eq(walls_220.size(), 1, "반지름을 바꾼 뒤에도 벽은 여전히 원 하나다 %s" % str(spy.arcs))
	if walls_220.size() == 1:
		t.ok(absf(float(walls_220[0]["width"]) - Look.ARENA_WALL_WIDTH) < 0.001,
				"벽의 굵기는 Look.ARENA_WALL_WIDTH다 — 표식의 기본 굵기가 아니다 (%.2f)"
						% float(walls_220[0]["width"]))
		t.ok(absf(Look.ARENA_WALL_WIDTH - 2.0) > 0.5,
				"설정: 그 굵기는 _paint_ring의 기본값(RING_WIDTH 2.0)과 실제로 다르다 — 아니면 이 검사는 공허하다")

	# Negative control: the arena open again (radius 0, the default before any close) draws nothing there.
	w.terrain.arena_closed = false
	w.terrain.arena_radius = 0.0
	spy.arcs.clear()
	await t.pump_frames(1)
	var still_there := false
	for e: Dictionary in spy.arcs:
		if _near(e["p"], centre):
			still_there = true
	t.ok(not still_there, "부정 대조: 반지름이 0으로 돌아가면 벽도 사라진다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- §E: the wall stays every frame after closing, not only the frame it appeared on -----------------------
func _e_wall_persists_every_frame_after_closing(t) -> void:
	var w := World.new()
	w.setup(132)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var centre := w.swarm.pos[0] + Vector2(300.0, 0.0)
	w.terrain.arena_centre = centre
	w.terrain.arena_closed = true
	w.terrain.arena_radius = Rules.ARENA_RADIUS

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	# Three SEPARATELY-cleared frames, not one capture read three times — a wall drawn once and cached would
	# still pass a check that only ever looked once.
	for sample in 3:
		spy.arcs.clear()
		await t.pump_frames(1)
		var seen := false
		for e: Dictionary in spy.arcs:
			if _near(e["p"], centre) and absf(float(e["r"]) - Rules.ARENA_RADIUS) < 0.01:
				seen = true
		t.ok(seen, "닫힌 뒤 %d번째로 따로 잰 프레임에도 벽이 그려져 있다" % (sample + 1))

	t.root.remove_child(spy)
	spy.queue_free()


# -- §E: the draw order is asserted by POSITION, never by the table's shape ---------------------------------
## Water and rock through `_paint_disc`, the arena wall through `_paint_arc`, the corpse through
## `_paint_cell` — three different leaves, so no single spy's own count can say which came first. One
## shared, index-ordered list (`OrderSpy`) is what a "before"/"after" claim needs.
func _e_draw_order_floor_before_bodies(t) -> void:
	var w := World.new()
	w.setup(133)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	w.terrain.rock_pos.append(host + Vector2(-500.0, 0.0))
	w.terrain.rock_radius.append(80.0)
	w.terrain.water_pos.append(host + Vector2(0.0, -500.0))
	w.terrain.water_radius.append(120.0)
	w.terrain.arena_centre = host
	w.terrain.arena_closed = true
	w.terrain.arena_radius = Rules.ARENA_RADIUS
	w.corpse_count = 1
	w.corpse_pos[0] = host + Vector2(200.0, 0.0)
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	# 0.0 on purpose: a progress ring is a SECOND `_paint_arc` call this fixture does not want to have to
	# tell apart from the wall's.
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = 3

	var spy := OrderSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.order.clear()
	# A clone killed on this exact call, so the frame captured below holds a death burst as well as bodies.
	var doomed := w.swarm.add_clone(0, 5)
	var dead_at: Vector2 = host + Vector2(-700.0, 0.0)
	w.swarm.pos[doomed] = dead_at
	w.swarm.damage(doomed, 999)
	t.eq(w.swarm.count, 1, "설정: 그 분신은 실제로 죽어 사라졌다")
	await t.pump_frames(1)

	var last_disc := -1
	var first_arc := -1
	var first_cell := -1
	for i in spy.order.size():
		var e: Dictionary = spy.order[i]
		var kind := String(e["kind"])
		if kind == "disc":
			last_disc = i
		elif kind == "arc" and first_arc < 0:
			first_arc = i
		elif kind == "cell" and first_cell < 0:
			first_cell = i
	t.ok(last_disc >= 0, "설정: 물과 바위가 실제로 그려졌다 (색인 %d)" % last_disc)
	t.ok(first_arc >= 0, "설정: 아레나 벽도 실제로 그려졌다 (색인 %d)" % first_arc)
	t.ok(first_cell >= 0, "설정: 시체(첫 셀)도 실제로 그려졌다 (색인 %d)" % first_cell)
	t.ok(last_disc < first_arc,
			"바닥(물·바위)이 아레나 벽보다 먼저 그려진다 (색인 %d < %d)" % [last_disc, first_arc])
	t.ok(first_arc < first_cell,
			"그리고 아레나 벽이 몸(시체부터)보다 먼저 그려진다 (색인 %d < %d)" % [first_arc, first_cell])

	# ⚠ **And the death burst goes the OTHER way — over every body, not under them.** The whole `_deaths`
	# loop used to sit up with the floor, so a clone dying inside the swarm burst at 10px underneath forty
	# 8px bodies and could not be seen at all — which is precisely the picture plan 2's unanswered "뚱뚱한
	# 분신을 잃는 것이 아픈가" is waiting on. A burst marks a body that is already GONE; nothing may occlude
	# it. Asserted by index against the LAST cell, not the first: over the corpse alone is not over the swarm.
	var last_cell := -1
	var burst_at := -1
	for i in spy.order.size():
		var e: Dictionary = spy.order[i]
		if String(e["kind"]) == "cell":
			last_cell = i
		elif String(e["kind"]) == "arc" and _near(e["p"], dead_at) and burst_at < 0:
			burst_at = i
	t.ok(burst_at >= 0, "설정: 죽은 자리의 파열이 실제로 그려졌다 (색인 %d)" % burst_at)
	t.ok(last_cell >= 0 and burst_at > last_cell,
			"죽음의 파열은 모든 몸보다 나중에 그려진다 — 무리 한복판의 죽음이 몸 밑에 깔리지 않는다 (색인 %d > %d)"
					% [burst_at, last_cell])

	t.root.remove_child(spy)
	spy.queue_free()


# -- §E: each teleported clone gets a ring at its arrival point ---------------------------------------------
## The exact fixture shape `net_run`'s own check 15 drives `World::_step_arena` with — the boss walked to
## `ARENA_RADIUS` and one clone parked 3000px out — so the frame this test measures is the SAME frame the
## sim side already proves the teleport lands on.
func _e_summon_rings_at_the_arrival_point(t) -> void:
	var w := World.new()
	w.setup(134)
	_silence(w)
	_clear_terrain(w)
	for k in range(w.critter_count - 1, -1, -1):
		if k != w.boss_index:
			w._remove_critter(k)
	w.elapsed = Rules.BOSS_HUNT_AT
	var host: Vector2 = w.swarm.pos[0]
	w.critter_pos[w.boss_index] = host + Vector2(Rules.ARENA_RADIUS, 0.0)
	var cl := w.swarm.add_clone()
	w.swarm.pos[cl] = host + Vector2(3000.0, 0.0)
	t.ok(not w.terrain.arena_closed, "설정: 아직 아레나가 닫히기 전이다")

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.arcs.clear()

	# The one step that closes the arena AND teleports the clone — driven directly, exactly as `net_run`'s
	# own check 15 drives `_step_arena`, so this is proven to be the same frame the sim side already covers.
	w.step(1.0 / 60.0)
	t.ok(w.terrain.arena_closed, "설정: 이 한 스텝에서 아레나가 실제로 닫혔다")
	var arrival: Vector2 = w.swarm.pos[cl]
	t.ok(arrival.distance_to(host) < Rules.ARENA_SUMMON_RING + 1.0,
			"설정: 분신이 실제로 소환 링 안으로 순간이동했다 (%.1f)" % arrival.distance_to(host))

	await t.pump_frames(1)
	# Not an exact `r0` — one real pumped frame's `delta` has already grown it a little, and headless frame
	# time is not pinned to any one value here. The BAND is `[r0, r0 * BURST_GROWTH]`: still on its very
	# first frame, nowhere near fully grown.
	var lo := Look.ARENA_SUMMON_R0
	var hi := Look.ARENA_SUMMON_R0 * Look.BURST_GROWTH
	var found := 0
	for e: Dictionary in spy.arcs:
		if not _near(e["p"], arrival):
			continue
		var r := float(e["r"])
		if (r >= lo - 0.01 and r <= lo + (hi - lo) * 0.5) \
				or (r >= lo * 0.45 - 0.01 and r <= (lo + (hi - lo) * 0.5) * 0.45):
			found += 1
	t.eq(found, 2, "분신의 도착 자리에 갓 태어난 링이 두 겹 그려진다 (r0=%.2f 근방, 아직 다 자라지 않았다) %s"
			% [Look.ARENA_SUMMON_R0, str(spy.arcs)])

	# ⚠ **ONE ring per clone, once — the arming EDGE, not the state.** `Terrain.arena_closed` never clears,
	# so `if arena_closed:` without `and not _arena_was_closed` appends a fresh `ARENA_SUMMON_R0` ring for
	# every clone on EVERY frame for the rest of the run: forty clones × the whole boss fight, and the run's
	# last act becomes unreadable. Both mutations kept every position and radius assertion above true — MORE
	# true — so the count of live bursts is what has to be read, and nothing was reading it.
	t.eq(spy._deaths.size(), 1, "소환 링은 순간이동한 분신 하나당 하나다 (%d)" % spy._deaths.size())
	for _f in 4:
		await t.pump_frames(1)
	t.eq(spy._deaths.size(), 1,
			"그리고 네 프레임이 더 지나도 여전히 하나다 — 닫힌 상태가 아니라 닫히는 그 한 번이 문이다 (%d)"
					% spy._deaths.size())

	# It fades: cleared, then several more frames later the ring at that exact spot and starting size is
	# gone — the list does not hold it forever.
	spy.arcs.clear()
	for _i in 40:
		await t.pump_frames(1)
	var still := false
	for e: Dictionary in spy.arcs:
		if _near(e["p"], arrival) and absf(float(e["r"]) - Look.ARENA_SUMMON_R0) < 0.05:
			still = true
	t.ok(not still, "그리고 시간이 지나면 그 도착 링은 사라진다 — 영원히 남지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- B-3: the clone's own hit flash, mixed FROM its cargo colour --------------------------------------------
## The same technique `_b1_monster_hit_flash` uses — partway through `HIT_FLASH_TIME`, never at `0.0` or past
## it, so a binary overpaint and a true `lerp` can be told apart. Two clones, one empty and one full, so
## "the flash starts from the clone's OWN colour" is provable: an implementation that always started from the
## flat `Look.CLONE_COLOR` regardless of cargo would make both clones read the identical flash colour.
func _b3_clone_hit_flash_uses_cargo_colour(t) -> void:
	var w := World.new()
	w.setup(141)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var empty := w.swarm.add_clone(0, 5)
	var loaded := w.swarm.add_clone(0, 5)
	w.swarm.pos[empty] = w.swarm.pos[0] + Vector2(200.0, 0.0)
	w.swarm.pos[loaded] = w.swarm.pos[0] + Vector2(400.0, 0.0)
	w.swarm.carried[loaded] = Look.CLONE_LOAD_FULL

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	spy.seen.clear()
	await t.pump_frames(1)
	var empty_rest := _cell_col_at(spy, w.swarm.pos[empty])
	var loaded_rest := _cell_col_at(spy, w.swarm.pos[loaded])
	t.ok(empty_rest != loaded_rest,
			"설정: 빈 분신과 가득 찬 분신은 안 맞았을 때도 이미 다른 색이다 (%s / %s)"
					% [str(empty_rest), str(loaded_rest)])

	w.swarm.hit_show[empty] = Look.HIT_FLASH_TIME * 0.5
	w.swarm.hit_show[loaded] = Look.HIT_FLASH_TIME * 0.5
	spy.seen.clear()
	await t.pump_frames(1)
	var empty_hit := _cell_col_at(spy, w.swarm.pos[empty])
	var loaded_hit := _cell_col_at(spy, w.swarm.pos[loaded])
	t.ok(empty_hit != Look.HIT_FLASH_COLOR and loaded_hit != Look.HIT_FLASH_COLOR,
			"섞은 것이지 덮은 것이 아니다 — 반쯤 지난 시점엔 둘 다 순백이 아니다 (%s / %s)"
					% [str(empty_hit), str(loaded_hit)])
	t.ok(empty_hit != loaded_hit,
			"두 분신의 깜빡임 색이 서로 다르다 — 종 색 하나로 덮은 것이 아니라 각자의 화물 색에서 출발했다 (%s / %s)"
					% [str(empty_hit), str(loaded_hit)])
	# The exact formula: each clone's own cargo colour lerped toward white — never a flat base. The weight is
	# `HIT_FLASH_STRENGTH × (1 - t/TIME)`, and the cap is not decoration: without it the weight is exactly 1.0
	# on the frame the hit lands and the body is painted flat white, which is the state §B-1 forbids.
	var expect_empty := Look.CLONE_COLOR.lerp(Look.HIT_FLASH_COLOR, Look.HIT_FLASH_STRENGTH * 0.5)
	var expect_loaded := Look.CLONE_LOADED_COLOR.lerp(Look.HIT_FLASH_COLOR, Look.HIT_FLASH_STRENGTH * 0.5)
	t.ok(_near_col(empty_hit, expect_empty),
			"빈 분신의 깜빡임 색은 CLONE_COLOR에서 출발한 lerp다 (%s)" % str(empty_hit))
	t.ok(_near_col(loaded_hit, expect_loaded),
			"가득 찬 분신의 깜빡임 색은 CLONE_LOADED_COLOR에서 출발한 lerp다 — 화물 색이 기준이다 (%s)"
					% str(loaded_hit))

	# ⚠ **The frame OF the hit, `hit_show == 0.0`, which is the one every check above deliberately avoided.**
	# `World._contact()` writes the clock to 0.0 and the view reads it before the next `+= dt`, so this frame
	# happens on every single hit — and at weight `1 - 0/TIME` = 1.0 it was a flat white overpaint, forty at a
	# time, the exact state §B-1 names and forbids. `HIT_FLASH_STRENGTH` is the cap that stops it.
	w.swarm.hit_show[empty] = 0.0
	w.swarm.hit_show[loaded] = 0.0
	spy.seen.clear()
	await t.pump_frames(1)
	var empty_peak := _cell_col_at(spy, w.swarm.pos[empty])
	var loaded_peak := _cell_col_at(spy, w.swarm.pos[loaded])
	t.ok(not _near_col(empty_peak, Look.HIT_FLASH_COLOR),
			"맞은 그 프레임(hit_show == 0)에도 순백으로 덮이지 않는다 (%s)" % str(empty_peak))
	t.ok(empty_peak != loaded_peak,
			"그 프레임에도 두 분신은 서로 다른 색이다 — 덮었다면 둘 다 똑같은 흰색이다 (%s / %s)"
					% [str(empty_peak), str(loaded_peak)])
	t.ok(_near_col(empty_peak, Look.CLONE_COLOR.lerp(Look.HIT_FLASH_COLOR, Look.HIT_FLASH_STRENGTH)),
			"가장 밝은 순간의 세기는 정확히 HIT_FLASH_STRENGTH다 (%s)" % str(empty_peak))
	t.ok(Look.HIT_FLASH_STRENGTH < 1.0,
			"설정: 그 상한은 1.0보다 작다 — 1.0이면 이 검사는 공허하다 (%.2f)" % Look.HIT_FLASH_STRENGTH)

	t.root.remove_child(spy)
	spy.queue_free()


# -- B-3 / B-4: a death burst outlives the body, and it leaves the list when it is done ---------------------
## A clone and a creature, killed by hand through the REAL functions (`Swarm.damage()`, `World._damage_
## critter()`) rather than by writing `_deaths` directly — driving the value, not the picture, is what makes
## "the burst is still there after the body is gone" provable at all: the row is gone from `sim` by the time
## `_process` reads `died_this_frame`/`critters_died_this_frame`, and the ring only exists because `view`'s
## own list remembers where it happened.
func _b3_b4_death_bursts_persist_and_fade(t) -> void:
	var w := World.new()
	w.setup(142)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	# **Two clones, one empty and one loaded**, because "the burst is proportional to what was lost" (§B-3)
	# cannot be read off a single body: one radius is satisfied by any constant. `CLONE_LOAD_FULL` is 8, so
	# `carried = 4` is exactly half-loaded and the expected colour is a lerp at 0.5 — driven, not read back.
	var empty := w.swarm.add_clone(0, 5)
	w.swarm.pos[empty] = w.swarm.pos[0] + Vector2(300.0, 0.0)
	w.swarm.carried[empty] = 0.0
	var empty_pos: Vector2 = w.swarm.pos[empty]
	var loaded := w.swarm.add_clone(0, 5)
	w.swarm.pos[loaded] = w.swarm.pos[0] + Vector2(600.0, 0.0)
	w.swarm.carried[loaded] = 4.0
	var loaded_pos: Vector2 = w.swarm.pos[loaded]
	# **A cheetah, not a crow** — §B-4 says 종 색으로, and the crow is `SPECIES_COLOR[0]`, so a burst that
	# indexed the table with a constant zero would be right by accident on one. Force 25 is the species
	# minimum, so `_radius_of` ramps to 0 and the radius is `SPECIES_RADIUS[CHEETAH]` exactly.
	var beast := w._write_critter(Parts.Species.CHEETAH, w.swarm.pos[0] + Vector2(-300.0, 0.0), 25)
	var beast_pos: Vector2 = w.critter_pos[beast]
	var beast_r: float = w.critter_radius(beast)
	t.ok(absf(beast_r - 15.0) < 0.01, "설정: 힘 25 치타의 반지름은 15.0이다 (리터럴) (%.2f)" % beast_r)

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.arcs.clear()

	# All three die on these exact calls, through the real damage functions — no `w.step()` in between, so
	# nothing else (no eating, no movement) can move any position before the burst is captured.
	w.swarm.damage(loaded, 999)
	w.swarm.damage(empty, 999)
	w._damage_critter(beast, 999)
	t.eq(w.swarm.count, 1, "설정: 두 분신이 실제로 죽어 사라졌다")
	t.eq(w.critter_count, 0, "설정: 생물도 실제로 죽어 사라졌다")
	await t.pump_frames(1)

	t.ok(_burst_r(spy, empty_pos) != INF, "몸이 이미 사라진 뒤에도 분신의 파열이 그려진다 %s" % str(spy.arcs))
	t.ok(_burst_r(spy, beast_pos) != INF, "생물의 파열도 마찬가지다 — 둘 다 sim의 표에서는 이미 없다")

	# ⚠ **The RADIUS, as a literal per body.** Nothing anywhere read one back: `CLONE_DEATH_R_BASE` → 0 and
	# `carried × CLONE_DEATH_R_PER_LOAD` → 0 were each green, so a fat clone and an empty one burst the same
	# size — and at radius 0 there was no burst on screen at all. The band is `[r0, r0 × 1.10]`: one real
	# pumped frame has already grown it a little (`BURST_GROWTH` over `BURST_TIME`), and 11.0 < 18.0 keeps
	# the two bodies bands apart.
	_burst_r_is(t, spy, empty_pos, Look.CLONE_DEATH_R_BASE, "빈 분신의 파열은 10px에서 시작한다")
	_burst_r_is(t, spy, loaded_pos, Look.CLONE_DEATH_R_BASE + 4.0 * Look.CLONE_DEATH_R_PER_LOAD,
			"4를 지고 있던 분신의 파열은 18px에서 시작한다 — 잃은 만큼 크다")
	t.ok(_burst_r(spy, loaded_pos) > _burst_r(spy, empty_pos) + 1.0,
			"그래서 뚱뚱한 분신의 파열이 빈 분신의 것보다 실제로 크다 (%.2f > %.2f)"
					% [_burst_r(spy, loaded_pos), _burst_r(spy, empty_pos)])
	_burst_r_is(t, spy, beast_pos, beast_r * Look.MONSTER_DEATH_R_MUL,
			"몬스터의 파열은 제 반지름 × MONSTER_DEATH_R_MUL(21px)에서 시작한다")

	# ⚠ **And the COLOUR.** `SPECIES_COLOR[0 × species]` (every monster bursting in the crow's red) and
	# `CLONE_COLOR.lerp(CLONE_LOADED_COLOR, 0 × load_t)` (a fat clone bursting in an empty one's tone) were
	# both green. Compared against a lerp of two `Look` constants at a weight this fixture DROVE, RGB only —
	# the alpha is faded from the very first frame and is asserted separately below.
	t.ok(_rgb_matches(_burst_col(spy, empty_pos), Look.CLONE_COLOR),
			"빈 분신의 파열은 분신의 색이다 (%s)" % str(_burst_col(spy, empty_pos)))
	t.ok(_rgb_matches(_burst_col(spy, loaded_pos),
					Look.CLONE_COLOR.lerp(Look.CLONE_LOADED_COLOR, 0.5)),
			"반쯤 실은 분신의 파열은 적재 색으로 반쯤 간 색이다 — 화물이 색에도 남는다 (%s)"
					% str(_burst_col(spy, loaded_pos)))
	t.ok(_rgb_matches(_burst_col(spy, beast_pos), Look.CHEETAH_COLOR),
			"몬스터의 파열은 제 종 색이다 — 까마귀의 빨강이 아니다 (%s)" % str(_burst_col(spy, beast_pos)))
	t.ok(not _rgb_matches(Look.CHEETAH_COLOR, Look.CROW_COLOR),
			"설정: 치타 색과 까마귀 색은 실제로 다르다 — 아니면 위 검사는 공허하다")

	# ⚠ **The ALPHA, at two instants.** `col.a *= (1.0 - frac)` → `col.a *= 0.0` was green: all five burst
	# effects fully transparent, nothing on screen at all, while every position and colour check still
	# matched. It is asserted visible now, and asserted to actually fade — a constant alpha passes > 0.
	var alpha_first := _burst_a(spy, empty_pos)
	t.ok(alpha_first > 0.5, "파열은 실제로 보이는 알파로 그려진다 (%.3f)" % alpha_first)
	spy.arcs.clear()
	for _i in 12:
		await t.pump_frames(1)
	var alpha_later := _burst_a(spy, empty_pos)
	t.ok(alpha_later > 0.0 and alpha_later < alpha_first - 0.02,
			"그리고 시간이 지나며 실제로 흐려진다 (%.3f → %.3f)" % [alpha_first, alpha_later])

	# **왜 손으로 새 프레임을 여는가**: 실제 게임에서는 셸이 매 프레임 `run.begin_frame()`을 부른다. 이
	# 픽스처는 그것을 한 번도 부르지 않으므로, 여기서 열어 주지 않으면 아래 90프레임 내내 `_process`가 같은
	# 죽음을 매번 새로 읽어 파열이 영원히 사라지지 않는 것처럼 보인다.
	w.begin_frame()
	# 39 frames to let the burst run its course, THEN clear-and-pump-one exactly the way every other check in
	# this file isolates a single frame's draws. **Not `spy.arcs.clear()` before the whole 40**: `ArcSpy`
	# APPENDS every frame it draws, so a clear-once-then-pump-forty would still hold every frame the burst
	# WAS alive for — a ring visible at frame 5 and gone by frame 40 would still read "still there" from the
	# frame-5 entry sitting in the same accumulated array.
	# ⚠ **Measured, not assumed**: a headless pumped frame here runs closer to ~135fps than 60fps (39 frames
	# landed `t` at 0.29s, short of `Look.BURST_TIME` 0.4), so the wait carries real margin rather than
	# copying `_e_summon_rings_at_the_arrival_point`'s 40 verbatim.
	for _i in 90:
		await t.pump_frames(1)
	spy.arcs.clear()
	await t.pump_frames(1)
	t.ok(_burst_r(spy, empty_pos) == INF and _burst_r(spy, beast_pos) == INF,
			"그리고 시간이 지나면 둘 다 사라진다 — 목록에 영원히 남지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


## The OUTER radius of the newest burst captured at `at`, or `INF` when there is none. `_paint_ring` emits
## two circles per burst (`r` and `r × 0.45`); the outer one is the burst own size and the inner is the
## marker echo, so a check that took either would be reading whichever came last.
func _burst_r(spy, at: Vector2) -> float:
	var best := INF
	for e: Dictionary in spy.arcs:
		if not _near(e["p"], at):
			continue
		if best == INF or float(e["r"]) > best:
			best = float(e["r"])
	return best


func _burst_col(spy, at: Vector2) -> Color:
	var best := -1.0
	var out := Color(0.0, 0.0, 0.0, 0.0)
	for e: Dictionary in spy.arcs:
		if _near(e["p"], at) and float(e["r"]) > best:
			best = float(e["r"])
			out = e["col"]
	return out


func _burst_a(spy, at: Vector2) -> float:
	return _burst_col(spy, at).a


## `[r0, r0 × 1.10]` — one real pumped frame has already grown the ring a little and headless frame time is
## not pinned to any one value, so the band is a tenth of the way up `BURST_GROWTH` rather than an equality.
func _burst_r_is(t, spy, at: Vector2, r0: float, label: String) -> void:
	var got := _burst_r(spy, at)
	t.ok(got >= r0 - 0.01 and got <= r0 * 1.10, "%s (%.2f, 기대 %.2f 근방)" % [label, got, r0])


# -- B-3: `view` reads `died_this_frame`, and it must not clear it ------------------------------------------
## `sim` owns the clock: `Swarm.step()` clears the list at ITS own top, next frame. If `view._process()`
## clears it instead, the very next read (by anything else, or by this same check one line later) finds it
## already empty — `view` may not write `sim` (§0-2).
func _b3_view_does_not_clear_died_this_frame(t) -> void:
	var w := World.new()
	w.setup(143)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var clone := w.swarm.add_clone(0, 5)
	w.swarm.damage(clone, 999)
	t.eq(w.swarm.died_this_frame.size(), 1, "설정: 분신 하나가 실제로 이번 프레임에 죽었다")

	var view := FieldView.new()
	view.world = w
	view.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(view)
	await t.pump_frames(1)

	t.eq(w.swarm.died_this_frame.size(), 1,
			"view의 _process가 한 프레임 지나도 died_this_frame은 그대로 남아 있다 — view가 지우지 않는다")

	t.root.remove_child(view)
	view.queue_free()


# -- B-5: the clone's own short swing line ------------------------------------------------------------------
## `BodySpy`'s `_paint_part_line` capture, reused — the swing line goes through the SAME leaf a limb already
## uses, so no new spy is needed for it.
func _b5_clone_swing_line(t) -> void:
	var w := World.new()
	w.setup(144)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var clone := w.swarm.add_clone(0, 5)
	var p := w.swarm.pos[0] + Vector2(250.0, 0.0)
	w.swarm.pos[clone] = p

	var spy := BodySpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	spy.lines.clear()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 0, "설정: 한 번도 휘두르지 않은 분신은 선을 그리지 않는다 — swing_show가 INF로 연다")

	# Off-axis (0.6, 0.8): `_h10`가 이미 세운 이유와 같다 — 상수 방향으로는 이 값을 흉내 낼 수 없다.
	var dir := Vector2(0.6, 0.8)
	w.swarm.swing_show[clone] = 0.0
	w.swarm.swing_dir[clone] = dir
	spy.lines.clear()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 1, "휘두른 순간 짧은 선이 하나 그려진다 %s" % str(spy.lines))
	if spy.lines.size() == 1:
		var seg: Dictionary = spy.lines[0]
		t.ok(_near(seg["a"], p), "선은 분신 자리에서 시작한다")
		var expect_b := p + dir * (Rules.CLONE_BODY_RADIUS * Look.CLONE_HIT_LINE_RING)
		t.ok(_near(seg["b"], expect_b),
				"그리고 맞은 방향으로 CLONE_BODY_RADIUS의 배수만큼 뻗는다 (%s / 기대 %s)"
						% [str(seg["b"]), str(expect_b)])
		t.ok(absf(float(seg["width"]) - Look.CLONE_HIT_LINE_WIDTH) < 0.001,
				"굵기는 Look.CLONE_HIT_LINE_WIDTH다")

	# `Look.CLONE_HIT_LINE_TIME`을 지난 시각 — 이미 사라졌다.
	w.swarm.swing_show[clone] = Look.CLONE_HIT_LINE_TIME + 0.01
	spy.lines.clear()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 0, "부정 대조: CLONE_HIT_LINE_TIME이 지나면 선은 사라진다")

	t.root.remove_child(spy)
	spy.queue_free()


func _cell_col_at(spy, p: Vector2) -> Color:
	for e: Dictionary in spy.seen:
		if _near(e["p"], p):
			return e["col"]
	return Color(0.0, 0.0, 0.0, 0.0)


# -- B-1: the monster hit flash and its spark -------------------------------------------------------------
## `critter_hit_show`/`critter_hit_dir` are written by `World._damage_critter` (§A), so this drives the
## columns directly rather than through a real strike — the same idiom `_p1_the_eating_ring` uses for
## `corpse_progress`.
func _b1_monster_hit_flash(t) -> void:
	var w := World.new()
	w.setup(121)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	var a := w._write_critter(Parts.Species.CROW, host + Vector2(200.0, 0.0), 10)
	var b := w._write_critter(Parts.Species.CROW, host + Vector2(400.0, 0.0), 10)

	var spy := HitSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	# Baseline: neither has ever been hit (`critter_hit_show` opens at `INF`).
	spy.seen.clear()
	await t.pump_frames(1)
	var rest_a := _species_col_at(spy, w.critter_pos[a])
	t.ok(rest_a == Look.CROW_COLOR, "설정: 안 맞은 까마귀는 제 종 색 그대로다 (%s)" % str(rest_a))

	# `a` is hit; `b` is not touched at all. **Partway through `HIT_FLASH_TIME`, not at `0.0`** — a binary
	# overpaint ("white while `hit_t < HIT_FLASH_TIME`, else species colour") and a true `lerp` agree at the
	# very instant of the hit (both are fully white then) and can only be told apart mid-fade, where a
	# `lerp` sits BETWEEN the two colours and an overpaint is still flat white.
	# Off-axis on purpose: `(0.6, 0.8)` is a unit vector no constant direction in the file can imitate, so a
	# spark placed from a fallback or from the centre cannot land on it by coincidence.
	w.critter_hit_show[a] = Look.HIT_FLASH_TIME * 0.5
	w.critter_hit_dir[a] = Vector2(0.6, 0.8)
	spy.seen.clear()
	spy.discs.clear()
	await t.pump_frames(1)
	var hit_col := _species_col_at(spy, w.critter_pos[a])
	var untouched_col := _species_col_at(spy, w.critter_pos[b])
	t.ok(hit_col != Look.CROW_COLOR, "맞은 지 얼마 안 된 색은 종 색에서 벗어나 있다 (%s)" % str(hit_col))
	t.ok(untouched_col == Look.CROW_COLOR,
			"같은 프레임, 안 맞은 쪽은 그대로다 — 하나만 맞았는데 마흔 마리 전부가 하얘지지 않는다 (%s)"
					% str(untouched_col))
	# **Mixed toward white, not painted white outright.** Half the flash time in, the mix sits strictly
	# BETWEEN the species colour and pure white — a binary overpaint would already read as flat white here.
	t.ok(hit_col != Look.HIT_FLASH_COLOR,
			"덮은 것이 아니라 섞은 것이다 — 반쯤 지난 시점에 순백은 아니다 (%s)" % str(hit_col))

	# A hit now leaves TWO discs, and they are different marks: the bloom is a filled halo at the body's own
	# centre, drawn UNDER it and growing outward, and the spark is the small bright dot on the struck
	# surface. **They are separated by position, not by index** — a check reading `discs[0]` would pass just
	# as happily if the two swapped and the halo started landing on the wound.
	t.eq(spy.discs.size(), 2, "한 대 맞으면 원반이 둘이다 — 몸의 헤일로와 맞은 지점의 불꽃 %s" % str(spy.discs))
	var bloom := _disc_at(spy, w.critter_pos[a])
	t.ok(not bloom.is_empty(), "헤일로가 몸 한가운데에 찍힌다 %s" % str(spy.discs))
	if not bloom.is_empty():
		# ⚠ **Strictly larger than the body**, or the halo is inside the silhouette and invisible — which is
		# the entire failure this mark exists to fix: a tint on 갈래 ㄱ's stroke has no area at all.
		t.ok(float(bloom["r"]) > w.critter_radius(a),
				"그 헤일로는 몸보다 크다 — 안쪽에 있으면 실루엣에 가려 아무것도 안 보인다 (%.2f > %.2f)"
						% [float(bloom["r"]), w.critter_radius(a)])
		var bloom_a := float((bloom["col"] as Color).a)
		t.ok(bloom_a > 0.0 and bloom_a < Look.HIT_BLOOM_COLOR.a,
				"그리고 반쯤 지난 시점에 이미 옅어져 있다 — 0과 %.3f 사이 (%.3f)"
						% [Look.HIT_BLOOM_COLOR.a, bloom_a])
	var d := _disc_at(spy, w.critter_pos[a] - Vector2(0.6, 0.8) * w.critter_radius(a))
	t.ok(not d.is_empty(), "불꽃이 맞은 지점에 찍힌다 %s" % str(spy.discs))
	if not d.is_empty():
		t.ok(float(d["r"]) > 0.0 and float(d["r"]) <= Look.HIT_SPARK_R,
				"불꽃의 반지름은 0과 HIT_SPARK_R 사이다 (%.2f)" % float(d["r"]))
		# ⚠ **The exact point, not "somewhere inside the body".** A bound taken from the thing being checked
		# proves nothing (CLAUDE.md): the centre is the most-inside point there is, so `p - hit_dir × 0 × r`
		# satisfied "inside the body" perfectly while the spark stopped saying which side the blow came from.
		# `critter_hit_dir` points AWAY from the attacker, so the struck surface is at `-hit_dir` from centre.
		var want_p := w.critter_pos[a] - Vector2(0.6, 0.8) * w.critter_radius(a)
		t.ok((d["p"] as Vector2).distance_to(want_p) < 0.05,
				"불꽃은 맞은 지점 — 중심에서 -hit_dir 쪽 표면 — 에 정확히 찍힌다 (%s / 기대 %s)"
						% [str(d["p"]), str(want_p)])
		t.ok(want_p.distance_to(w.critter_pos[a]) > 1.0,
				"설정: 그 지점은 중심과 실제로 떨어져 있다 — 아니면 위 검사는 중심과 구별되지 않는다")

	# ⚠ **The frame OF the hit, `critter_hit_show == 0.0`** — the one instant every sample above deliberately
	# avoids, and the one that happens on every single hit: `_damage_critter()` writes the clock to `0.0` and
	# `_step_critters()` only adds `dt` on the NEXT frame. At weight `1 - 0/TIME` = 1.0 the species colour was
	# painted out entirely, forty creatures at a time — the flat white §B-1 names and forbids. Sampling only
	# at half the window cannot see it: 0.5 and 0.375 are both "not white and not the species colour".
	w.critter_hit_show[a] = 0.0
	spy.seen.clear()
	await t.pump_frames(1)
	var peak_col := _species_col_at(spy, w.critter_pos[a])
	t.ok(peak_col != Look.HIT_FLASH_COLOR,
			"맞은 그 프레임(hit_show == 0)에도 순백으로 덮이지 않는다 (%s)" % str(peak_col))
	t.ok(_near_col(peak_col, Look.CROW_COLOR.lerp(Look.HIT_FLASH_COLOR, Look.HIT_FLASH_STRENGTH)),
			"가장 밝은 순간의 세기는 정확히 HIT_FLASH_STRENGTH다 — 종 색이 그 밑에 남는다 (%s)" % str(peak_col))
	t.ok(_species_col_at(spy, w.critter_pos[b]) == Look.CROW_COLOR,
			"그 프레임에도 옆의 안 맞은 까마귀는 제 종 색 그대로다")

	# 0.09초(`HIT_FLASH_TIME`)를 지난 시각 — 0.2초 뒤.
	w.critter_hit_show[a] = 0.2
	spy.seen.clear()
	spy.discs.clear()
	await t.pump_frames(1)
	var later_col := _species_col_at(spy, w.critter_pos[a])
	t.ok(later_col == Look.CROW_COLOR, "0.2초 뒤엔 다시 종 색이다 (%s)" % str(later_col))
	t.ok(later_col != hit_col, "그래서 맞은 순간과 0.2초 뒤는 서로 다른 색이었다")
	t.eq(spy.discs.size(), 0, "그리고 그때는 불꽃도 이미 사라졌다")

	t.root.remove_child(spy)
	spy.queue_free()


func _species_col_at(spy: HitSpy, p: Vector2) -> Color:
	for e: Dictionary in spy.seen:
		if e["p"] == p:
			return e["col"]
	return Color(0.0, 0.0, 0.0, 0.0)


# -- D2: the minimap boss dot pulses, and only while the hunt is on -----------------------------------------
## A pure function of `elapsed` — no view timer — so the same instant sampled twice must draw the same
## radius, and different instants must draw DIFFERENT radii, both within the documented range. Before the
## hunt starts the boss reads exactly like any other creature mark.
func _d2_boss_pulse(t) -> void:
	var w := World.new()
	w.setup(122)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var b := w._write_critter(Parts.Species.BOSS, w.swarm.pos[0] + Vector2(200.0, 0.0), 120)
	w.boss_index = b

	var spy := MapSpy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)

	# Before the hunt: the ordinary FIXED radius, exactly — no pulse at all.
	spy.forget()
	await t.pump_frames(1)
	t.ok(absf(_mark_r(spy, Look.BOSS_COLOR) - Look.MINIMAP_CREATURE_R) < 0.001,
			"보스 사냥이 시작되기 전엔 여느 생물처럼 고정된 반지름이다 (%.3f)" % _mark_r(spy, Look.BOSS_COLOR))

	# After: several instants past the crossing, each inside the documented range, and not all equal.
	var seen := {}
	for e in 8:
		w.elapsed = Rules.BOSS_HUNT_AT + float(e) * 0.3
		spy.forget()
		await t.pump_frames(1)
		var r := _mark_r(spy, Look.BOSS_COLOR)
		t.ok(r != INF, "설정: 그 순간에도 보스 점을 찾았다")
		t.ok(r >= Look.MINIMAP_CREATURE_R - 0.001
						and r <= Look.MINIMAP_CREATURE_R * Look.MINIMAP_BOSS_PULSE_MUL + 0.001,
				"반지름은 언제나 MINIMAP_CREATURE_R과 그 MINIMAP_BOSS_PULSE_MUL배 사이다 (%.3f)" % r)
		seen[str(snappedf(r, 0.01))] = true
	t.ok(seen.size() > 1, "여러 순간을 재면 반지름이 실제로 달라진다 — 고정값이 아니다 %s" % str(seen))

	# The same instant, twice: the same radius both times — a pure function, never `Math.random`.
	w.elapsed = Rules.BOSS_HUNT_AT + 1.234
	spy.forget()
	await t.pump_frames(1)
	var r1 := _mark_r(spy, Look.BOSS_COLOR)
	spy.forget()
	await t.pump_frames(1)
	var r2 := _mark_r(spy, Look.BOSS_COLOR)
	t.eq(r1, r2, "같은 elapsed는 같은 반지름을 낸다 — 시계를 따로 갖지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


## The radius of the one mark drawn in `col`, or `INF` when none was found.
func _mark_r(spy, col: Color) -> float:
	for e: Dictionary in spy.marks:
		if e["col"] == col:
			return float(e["r"])
	return INF


# -- §F-7: the food-eaten pop, small and travelling ------------------------------------------------------
## ⚠ **Driven through an actual `World.step()`, never through `world.swarm.food_eaten_this_frame` written
## by hand** — a hand-filled list would only prove `_process` reads a list, not that eating one actually
## fills it. `w.step()` runs the real `_try_eat()` path once, with nothing else in the fixture that could
## also touch `food_eaten_this_frame` (no critters, no clones).
func _f7_food_pop_is_small_and_travels(t) -> void:
	var w := World.new()
	w.setup(320)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	w.food.pos[0] = host + Vector2(-6.0, 0.0)
	w.food.alive[0] = 1
	w.food.alive_count = 1
	w.swarm.eat_cd[0] = 0.0

	var spy := DiscSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.discs.clear()
	w.step(1.0 / 60.0)
	await t.pump_frames(1)

	# ⚠ **RGB only, never full `Color ==`.** The pop's alpha is faded (`col.a *= 1.0 - frac`) from the very
	# first frame — see the branch in `_paint` — so it is never bit-identical to `Look.FOOD_COLOR` (alpha
	# 1.0), the exact shape the afterimage check below had to be built the same way for.
	var pop_p := Vector2.INF
	var pop_r := 0.0
	for e: Dictionary in spy.discs:
		if _rgb_matches(e["col"], Look.FOOD_COLOR) and e["r"] > 0.0 and e["r"] <= Look.FOOD_POP_R + 0.01:
			pop_p = e["p"]
			pop_r = e["r"]
	t.ok(pop_p != Vector2.INF, "먹은 자리에 아주 작은 원이 하나 뜬다 %s" % str(spy.discs))
	t.ok(Look.FOOD_POP_R < Look.CLONE_DEATH_R_BASE,
			"그 크기(FOOD_POP_R)는 분신 죽음 파열(CLONE_DEATH_R_BASE)보다 작다 — 초당 여러 번 뜨는 유일한 사건이다")

	# ⚠ **`food_eaten_this_frame` cleared BY HAND before pumping further** — the identical shape and the
	# identical reason `_b3_b4_death_bursts_persist_and_fade` already documents: nothing here calls
	# `w.step()` again, so `Swarm.step()` never clears it, and `_process` would otherwise re-read the SAME
	# uncleared entry every pumped frame and spawn a FRESH pop at `t=0` each time — which is exactly what
	# happened the first time this check was written, and it is why the "travels/shrinks" half moved to its
	# own single-cleared window rather than trusting several frames pumped in one call.
	w.swarm.food_eaten_this_frame.clear()
	if pop_p != Vector2.INF:
		var d0 := pop_p.distance_to(w.swarm.pos[0])
		spy.discs.clear()
		await t.pump_frames(4)
		var later_p := Vector2.INF
		var later_r := 0.0
		for e: Dictionary in spy.discs:
			if _rgb_matches(e["col"], Look.FOOD_COLOR) and e["r"] > 0.0:
				later_p = e["p"]
				later_r = e["r"]
		t.ok(later_p != Vector2.INF, "몇 프레임 뒤에도 아직 줄어들며 남아 있다 %s" % str(spy.discs))
		if later_p != Vector2.INF:
			t.ok(later_p.distance_to(w.swarm.pos[0]) < d0,
					"그 사이 몸 쪽으로 가까워졌다 — 고정된 점이 아니라 빨려 들어간다 (%.3f → %.3f)"
							% [d0, later_p.distance_to(w.swarm.pos[0])])
			t.ok(later_r < pop_r, "그리고 그 사이 줄어든다 (%.3f → %.3f)" % [pop_r, later_r])

	t.root.remove_child(spy)
	spy.queue_free()


# -- §F-9: the level pop, distinct from _absorb_pop ------------------------------------------------------
func _f9_level_pop_differs_from_absorb_pop(t) -> void:
	var w := World.new()
	w.setup(321)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	spy.seen.clear()
	await t.pump_frames(1)
	var base := _host_entry(spy, w.swarm.pos[0])
	t.ok(float(base.get("r", 0.0)) > 0.0, "설정: 기준 호스트를 찾았다 %s" % str(spy.seen))

	# `_absorb_pop` driven exactly the way `net_shell.gd` already drives it — through the view's own field.
	spy._absorb_pop = 1.0
	spy.seen.clear()
	await t.pump_frames(1)
	var absorb_only := _host_entry(spy, w.swarm.pos[0])
	spy._absorb_pop = 0.0

	# `level_show` driven through `World`, never through a `view`-owned diff of `level` (§0-2).
	w.level_show = 0.0
	spy.seen.clear()
	await t.pump_frames(1)
	var level_only := _host_entry(spy, w.swarm.pos[0])
	w.level_show = INF

	t.eq(absorb_only.get("col"), base.get("col"),
			"설정부터 확인한다: 흡수 팝은 색을 전혀 바꾸지 않는다")
	t.ok(float(level_only.get("r", 0.0)) > float(base.get("r", 0.0)), "레벨 팝은 실제로 몸을 키운다")
	t.ok(absf(float(level_only.get("r", 0.0)) - float(absorb_only.get("r", 0.0))) > 0.01,
			"레벨 팝은 흡수 팝과 다른 세기다 (레벨 %.2f, 흡수 %.2f)"
					% [float(level_only.get("r", 0.0)), float(absorb_only.get("r", 0.0))])
	t.ok(level_only.get("col") != absorb_only.get("col"),
			"레벨 팝은 흡수 팝과 다른 색이다 — 흡수는 색을 전혀 바꾸지 않으므로 이 색 자체가 다름의 증거다 (%s vs %s)"
					% [str(level_only.get("col")), str(absorb_only.get("col"))])

	t.root.remove_child(spy)
	spy.queue_free()


## RGB-only equality, ignoring alpha — for colours a burst or a ghost fades toward transparent, where a
## bit-identical `Color ==` against the fully-opaque `Look` constant would never be true.
func _rgb_matches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001


## The one `Spy`-captured cell drawn exactly at `host_pos` — the host is the only body ever drawn there in
## a fixture with no clone parked on top of it. `{}` when nothing matched.
func _host_entry(spy, host_pos: Vector2) -> Dictionary:
	for e: Dictionary in spy.seen:
		if e["p"] == host_pos:
			return e
	return {}


# -- §F-10: `F`'s own burst, at the point the split happened ----------------------------------------------
func _f10_split_ring_at_the_split_point(t) -> void:
	var w := World.new()
	w.setup(322)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w.swarm.force[0] = 1
	var c := w.swarm.add_clone(0, 20)
	var origin: Vector2 = w.swarm.pos[c]

	var spy := ArcSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	spy.arcs.clear()
	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(w.swarm.count, 3, "설정: 실제로 갈라졌다")
	await t.pump_frames(1)

	# ⚠ `ArcSpy` captures only the colour's ALPHA (`"col_a"`), never the full `Color` — so the ring is
	# identified by POSITION and by `_paint_ring`'s own two-arc shape (r and r×0.45), the same technique
	# `_c_strike_marker` already uses, rather than a colour this spy cannot actually compare.
	var outer := false
	var inner := false
	for e: Dictionary in spy.arcs:
		if not _near(e["p"], origin):
			continue
		if absf(float(e["r"]) - Look.SPLIT_POP_R0) < 0.5:
			outer = true
		if absf(float(e["r"]) - Look.SPLIT_POP_R0 * 0.45) < 0.5:
			inner = true
	t.ok(outer and inner, "갈라진 그 자리에 두 겹 링이 뜬다 %s" % str(spy.arcs))

	t.root.remove_child(spy)
	spy.queue_free()


# -- §F-12: the afterimage is gated by SPECIES, never by the frame's own velocity -------------------------
## ⚠ **Both a positive and a negative control, driven off the real per-species table** — never grepped.
## Reading `Rules.SPECIES_SPEED_MUL` here is the check itself asking the same question `_paint` asks.
func _f12_afterimage_gated_by_species(t) -> void:
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.CROW]) <= 1.0,
			"설정: 까마귀는 1.0을 넘지 않는다 — 이 검사의 부정 대조가 실제로 부정 대조이려면 필요하다")
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.CHEETAH]) > 1.0,
			"설정: 치타는 1.0을 넘는다 — 이 검사의 긍정 대조다")
	# ⚠ **The gate is a `> 1.0` on the whole table, and this fixture named two rows and stopped.** 토끼's
	# 1.05 puts it inside the gate, which is wanted — the trail is the mark that says 저건 못 잡는다, and the
	# rabbit is the first thing in the run that out-runs a held direction. But nothing asserted it, so the
	# rabbit wearing or not wearing a trail was invisible to the round. Named here rather than derived:
	# **exactly which species carry a trail is a design fact**, and the whole table is counted below.
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.RABBIT]) > 1.0,
			"설정: 토끼도 1.0을 넘는다 — 210px/s, 잡고 있는 방향으로는 못 잡는다는 표시다")
	var fast: Array = []
	for s in Rules.SPECIES_SPEED_MUL.size():
		if float(Rules.SPECIES_SPEED_MUL[s]) > 1.0:
			fast.append(s)
	t.eq(str(fast), str([int(Parts.Species.HORSE), int(Parts.Species.CHEETAH),
			int(Parts.Species.RABBIT)]),
			"잔상을 다는 종은 말·치타·토끼 셋뿐이다 — 넷째가 생기면 이 줄이 먼저 빨강이다 %s" % str(fast))

	var w := World.new()
	w.setup(323)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	var crow := w._write_critter(Parts.Species.CROW, host + Vector2(300.0, 0.0), 10)
	var cheetah := w._write_critter(Parts.Species.CHEETAH, host + Vector2(600.0, 0.0), 30)
	var rabbit := w._write_critter(Parts.Species.RABBIT, host + Vector2(900.0, 0.0), 6)
	# A real, nonzero heading on all three — the gate has to hold even though every row is equally "moving".
	w.critter_dir[crow] = Vector2(1.0, 0.0)
	w.critter_dir[cheetah] = Vector2(1.0, 0.0)
	w.critter_dir[rabbit] = Vector2(1.0, 0.0)

	var spy := Spy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.seen.clear()
	await t.pump_frames(1)

	var crow_hits := 0
	var cheetah_hits := 0
	var rabbit_hits := 0
	# ⚠ **RGB only, never full `Color ==`, for BOTH counts.** A ghost's alpha is faded
	# (`Look.AFTERIMAGE_ALPHA * fade`), so it is never bit-identical to either species' fully-opaque `Look`
	# constant. Measured the hard way: an exact `Color ==` on the crow's count first shipped here, and it
	# stayed green even with the species gate DELETED entirely, because it could only ever see the one
	# real, unfaded body — the mutation this check exists to catch bit it without this being RGB-only too.
	for e: Dictionary in spy.seen:
		if _rgb_matches(e["col"], Look.CROW_COLOR):
			crow_hits += 1
		if _rgb_matches(e["col"], Look.CHEETAH_COLOR):
			cheetah_hits += 1
		if _rgb_matches(e["col"], Look.RABBIT_COLOR):
			rabbit_hits += 1
	t.eq(crow_hits, 1, "까마귀는 제 자리 하나만 그려진다 — 잔상이 없다 (%d)" % crow_hits)
	t.eq(cheetah_hits, Look.AFTERIMAGE_COUNT + 1,
			"치타는 제 자리 하나 + 잔상 AFTERIMAGE_COUNT개가 그려진다 (%d, 기대 %d)"
					% [cheetah_hits, Look.AFTERIMAGE_COUNT + 1])
	t.eq(rabbit_hits, Look.AFTERIMAGE_COUNT + 1,
			"토끼도 잔상을 단다 — 1.05는 문턱 위다 (%d, 기대 %d)"
					% [rabbit_hits, Look.AFTERIMAGE_COUNT + 1])

	# ⚠ **The ghost ALPHA, as literals.** `_rgb_matches` has to ignore alpha to see a faded ghost at all — and
	# that is exactly what let `Look.AFTERIMAGE_ALPHA * fade` → `0.0 * ...` stay green: three fully
	# transparent ghosts still count as three drawn ones. §F-12 is the trail that IS the information "저건 못
	# 잡는다"; at alpha 0 there is no trail. `0.35 × (1 - n/4)` for n = 1, 2, 3 = 0.2625 / 0.175 / 0.0875,
	# written out rather than recomputed, so zeroing the constant moves one side of the comparison only.
	t.ok(absf(Look.AFTERIMAGE_ALPHA - 0.35) < 0.0001,
			"설정: AFTERIMAGE_ALPHA는 0.35다 — 아래 리터럴 셋이 그 값에서 나온다")
	t.eq(Look.AFTERIMAGE_COUNT, 3, "설정: 잔상은 셋이다 — 아래 리터럴 셋이 그 개수에서 나온다")
	var ghost_alphas := []
	var body_alphas := 0
	for e: Dictionary in spy.seen:
		if not _rgb_matches(e["col"], Look.CHEETAH_COLOR):
			continue
		var a: float = (e["col"] as Color).a
		if absf(a - 1.0) < 0.001:
			body_alphas += 1
		else:
			ghost_alphas.append(a)
	t.eq(body_alphas, 1, "설정: 불투명하게 그려진 진짜 몸은 하나다 (%d)" % body_alphas)
	ghost_alphas.sort()
	t.eq(ghost_alphas.size(), 3, "그리고 나머지 셋은 반투명한 잔상이다 %s" % str(ghost_alphas))
	if ghost_alphas.size() == 3:
		for pair in [[0, 0.0875], [1, 0.175], [2, 0.2625]]:
			var got: float = ghost_alphas[int(pair[0])]
			t.ok(absf(got - float(pair[1])) < 0.001,
					"잔상의 알파는 %.4f다 — 0이면 잔상은 화면에 없다 (%.4f)" % [float(pair[1]), got])

	# A second, independent frame — same species, same nonzero heading, still no ghost. Repeats the negative
	# control rather than trusting the single frame above.
	spy.seen.clear()
	await t.pump_frames(1)
	var crow_hits2 := 0
	for e: Dictionary in spy.seen:
		if _rgb_matches(e["col"], Look.CROW_COLOR):
			crow_hits2 += 1
	t.eq(crow_hits2, 1, "다음 프레임에도 까마귀는 여전히 잔상이 없다 — 속도가 아니라 종이 문(gate)이다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- P15: every species swings its own shape, and two of them in one frame differ --------------------------
## **The whole claim of §6 in one fixture**: seven creatures, seven species, all swinging on the same frame
## with the same direction and the same progress, and every one of them reaching the leaves with different
## arguments. Before this pass all seven drew the identical `_paint_part_line` at `r × CRITTER_SWING_RING`,
## and nothing in the round could have told the difference.
##
## Every expectation is hand arithmetic from `look.gd`'s literals, never a value read back off the view:
## `_lunge_offset` is re-derived here from the curve its own comment states (`sin(pi x) × PUSH`) rather than
## called, because a check that asks the code under test what it did measures nothing.
##
## ⚠ **Each creature is written at its `SPECIES_FORCE_MIN`, so `World._radius_of`'s force ramp is exactly 0
## and the drawn radius is the species' bare `SPECIES_RADIUS`** — 12 · 5 · 10 · 18 · 40 · 26 · 48, asserted
## as literals below. Without that every geometry expectation would be a multiple of a number taken from the
## thing being checked.
func _p15_every_species_swings_its_own_shape(t) -> void:
	var w := World.new()
	w.setup(618)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1

	var kinds := [Parts.Species.CROW, Parts.Species.MOUSE, Parts.Species.DOG, Parts.Species.BOAR,
			Parts.Species.ELEPHANT, Parts.Species.LION, Parts.Species.BOSS]
	var radii := [12.0, 5.0, 10.0, 18.0, 40.0, 26.0, 48.0]
	t.eq(kinds.size(), 7, "설정: 제 몸짓을 가진 종은 일곱이다 — 나머지 넷은 아예 공격을 안 한다")
	var rows := []
	for i in kinds.size():
		var s: int = kinds[i]
		var k := w._write_critter(s, Vector2(320.0 + float(i) * 480.0, 400.0),
				int(Rules.SPECIES_FORCE_MIN[s]))
		rows.append(k)
		t.ok(absf(w.critter_radius(k) - float(radii[i])) < 0.001,
				"설정: %s의 그린 반지름은 %.1fpx다 — 힘을 최소로 썼으니 종의 바탕 크기 그대로다 (%.3f)"
						% [String(Parts.SPECIES_NAME[s]), float(radii[i]), w.critter_radius(k)])
	# **The negative control, and it is a creature that never attacks.** 다람쥐 carries `SPECIES_FLEES` 1, so
	# `World._contact()` returns before writing a swing and its `critter_swing_show` stays at the `INF` it was
	# born with. It must draw no gesture mark at all and its body must sit exactly on its sim position — the
	# line that says the counts below are counting swings and not creatures.
	var quiet := w._write_critter(Parts.Species.SQUIRREL, Vector2(3500.0, 400.0), 3)

	# Off-axis on purpose: `(0.6, 0.8)` is a unit vector no constant direction in `field_view.gd` can imitate,
	# so a mark placed from a fallback direction cannot land on these points by coincidence.
	var dir := Vector2(0.6, 0.8)
	for k: int in rows:
		w.critter_swing_dir[k] = dir
		w.critter_swing_show[k] = Look.CRITTER_SWING_TIME * 0.25
	t.eq(w.critter_swing_show[quiet], INF, "설정: 다람쥐는 한 번도 휘두른 적이 없다 (INF로 태어난다)")

	var spy := SwingSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	# **The totals first, and they are the control for every position assertion under them.** Four lines
	# (까마귀 둘 · 들개 하나 · 코끼리 하나), two discs (들쥐 · 사자), two arcs (멧돼지 · 보스). A gesture that
	# drew an extra mark, or a stray `_paint_disc` from anywhere else, moves one of these three numbers.
	t.eq(spy.lines.size(), 4,
			"한 프레임에 선은 넷이다 — 까마귀의 두 갈래, 들개의 한 획, 코끼리의 가로 막대 (%d)" % spy.lines.size())
	t.eq(spy.discs.size(), 2, "원반은 둘이다 — 들쥐의 갉는 점과 사자가 내려앉은 점")
	t.eq(spy.arcs.size(), 2, "호는 둘이다 — 멧돼지의 뿔과 보스의 발밑 고리")
	t.eq(spy.cells.size(), 9, "몸은 아홉이다 — 생물 여덟과 호스트 하나 (잔상을 그리는 종은 하나도 없다)")

	var tol := 0.2
	# -- 까마귀 쪼기: two strokes at ±SWING_PECK_ANGLE, both at full length --------------------------
	var crow_at := _swung_at(w.critter_pos[rows[0]], dir, 0.25, Parts.Species.CROW)
	var crow_tips := []
	for m: float in [1.0, -1.0]:
		var d := dir.rotated(Look.SWING_PECK_ANGLE * m)
		var a := crow_at + d * 12.0
		var seg := _seg_from(spy.lines, a, tol)
		t.ok(not seg.is_empty(), "까마귀의 %+.0f°짜리 획이 몸 가장자리에서 시작한다 (%s)" % [m * 14.0, str(a)])
		if seg.is_empty():
			continue
		var want_b := a + d * 18.0
		t.ok((seg["b"] as Vector2).distance_to(want_b) < tol,
				"그리고 그 획은 제 반지름의 1.5배만큼 더 뻗는다 (%s / 기대 %s)" % [str(seg["b"]), str(want_b)])
		t.ok(absf(float(seg["width"]) - 5.0) < 0.001, "굵기는 5px다 (리터럴)")
		crow_tips.append(seg["b"])
	# ⚠ **A fork, not one line drawn twice.** Two identical strokes would satisfy every assertion above if
	# `SWING_PECK_ANGLE` were zeroed — the tips would coincide and the crow would go back to one line.
	t.eq(crow_tips.size(), 2, "설정: 두 획을 다 찾았다")
	if crow_tips.size() == 2:
		t.ok((crow_tips[0] as Vector2).distance_to(crow_tips[1]) > 10.0,
				"두 끝은 서로 10px 넘게 떨어져 있다 — 각을 0으로 만들면 한 획이 둘로 겹친다 (%.2f)"
						% (crow_tips[0] as Vector2).distance_to(crow_tips[1]))

	# -- 들쥐 갉기: one shrinking dot at the contact point, and NO line ------------------------------
	var mouse_at := _swung_at(w.critter_pos[rows[1]], dir, 0.25, Parts.Species.MOUSE)
	var gnaw := _disc_from(spy.discs, mouse_at + dir * 5.0, tol)
	t.ok(not gnaw.is_empty(), "들쥐의 점은 닿은 지점에 찍힌다 %s" % str(spy.discs))
	if not gnaw.is_empty():
		t.ok(absf(float(gnaw["r"]) - 1.875) < 0.001,
				"그 반지름은 5 × 0.5 × (1 - 0.25) = 1.875px다 (리터럴) — %.4f" % float(gnaw["r"]))

	# -- 들개 물어뜯기: one stroke, ROTATED away from the swing direction ----------------------------
	var dog_at := _swung_at(w.critter_pos[rows[2]], dir, 0.25, Parts.Species.DOG)
	var bite := _seg_from(spy.lines, dog_at, tol)
	t.ok(not bite.is_empty(), "들개의 획은 몸 한가운데에서 시작한다 %s" % str(dog_at))
	if not bite.is_empty():
		var bd := dir.rotated(lerpf(-Look.SWING_BITE_SWEEP, Look.SWING_BITE_SWEEP, 0.25))
		var want_b := dog_at + bd * 20.0
		t.ok((bite["b"] as Vector2).distance_to(want_b) < tol,
				"그리고 제 반지름의 2배만큼, 휘두른 방향에서 -10° 돌아간 곳으로 뻗는다 (%s / 기대 %s)"
						% [str(bite["b"]), str(want_b)])
		# ⚠ **The rotation is the gesture.** A stroke straight along `dir` satisfies "a line of length 20"
		# perfectly, and that is exactly what zeroing `SWING_BITE_SWEEP` produces.
		var straight := dog_at + dir * 20.0
		t.ok((bite["b"] as Vector2).distance_to(straight) > 3.0,
				"그 끝은 휘두른 방향 그대로 뻗은 자리와 3px 넘게 다르다 — 안 돌면 들개는 그냥 선 하나다 (%.2f)"
						% (bite["b"] as Vector2).distance_to(straight))

	# -- 멧돼지 들이받기: a partial arc that has not finished opening yet ----------------------------
	var boar_at := _swung_at(w.critter_pos[rows[3]], dir, 0.25, Parts.Species.BOAR)
	var tusk := _arc_from(spy.arcs, boar_at, tol)
	t.ok(not tusk.is_empty(), "멧돼지의 호는 몸 자리에 있다 %s" % str(spy.arcs))
	if not tusk.is_empty():
		t.ok(absf(float(tusk["r"]) - 25.2) < 0.001,
				"그 반지름은 18 × 1.4 = 25.2px다 (리터럴) — %.4f" % float(tusk["r"]))
		var sweep := float(tusk["to"]) - float(tusk["from"])
		t.ok(absf(rad_to_deg(sweep) - 22.5) < 0.01,
				"창의 4분의 1 지점에서 90°의 4분의 1인 22.5°만 열려 있다 (%.3f°)" % rad_to_deg(sweep))
		t.ok(absf(float(tusk["from"]) - (dir.angle() - deg_to_rad(45.0))) < 0.0001,
				"그리고 그 호는 휘두른 방향에서 45° 뒤에서 시작한다 — 방향에 붙어 있다")

	# -- 코끼리 밀치기: a heavy bar ACROSS the direction, and a doubled lunge ------------------------
	var ele_at := _swung_at(w.critter_pos[rows[4]], dir, 0.25, Parts.Species.ELEPHANT)
	var across := Vector2(-dir.y, dir.x) * 32.0
	var mid := ele_at + dir * 40.0
	var bar := _seg_from(spy.lines, mid - across, tol)
	t.ok(not bar.is_empty(), "코끼리의 막대는 닿은 지점을 가운데 두고 놓인다 %s" % str(mid))
	if not bar.is_empty():
		t.ok((bar["b"] as Vector2).distance_to(mid + across) < tol,
				"그 막대는 양쪽으로 40 × 0.8 = 32px씩 뻗는다 (%s / 기대 %s)"
						% [str(bar["b"]), str(mid + across)])
		t.ok(absf(float(bar["width"]) - 10.0) < 0.001,
				"굵기는 5 × 2 = 10px다 — 화면에서 가장 굵은 획이다 (%.2f)" % float(bar["width"]))
		# ⚠ **Perpendicular, and that is what makes it a shove rather than a stab.** A bar drawn ALONG `dir`
		# would keep its length and its width and stop being a different gesture from the dog's.
		var along := ((bar["b"] as Vector2) - (bar["a"] as Vector2)).normalized()
		t.ok(absf(along.dot(dir)) < 0.001,
				"그리고 그 막대는 휘두른 방향과 정확히 직각이다 (내적 %.5f)" % along.dot(dir))

	# -- 사자 덮치기: one shrinking dot where the tripled lunge landed, and no line ------------------
	var lion_at := _swung_at(w.critter_pos[rows[5]], dir, 0.25, Parts.Species.LION)
	var pounce := _disc_from(spy.discs, lion_at + dir * 46.8, tol)
	t.ok(not pounce.is_empty(), "사자의 점은 몸 앞 26 × 1.8 = 46.8px에 찍힌다 %s" % str(spy.discs))
	if not pounce.is_empty():
		t.ok(absf(float(pounce["r"]) - 12.0) < 0.001,
				"그 반지름은 HIT_SPARK_R 16 × (1 - 0.25) = 12px다 (리터럴) — %.4f" % float(pounce["r"]))

	# -- 보스 내려찍기: a full ring at its feet, at the arena wall's own weight ----------------------
	var boss_at := _swung_at(w.critter_pos[rows[6]], dir, 0.25, Parts.Species.BOSS)
	var stomp := _arc_from(spy.arcs, boss_at, tol)
	t.ok(not stomp.is_empty(), "보스의 고리는 제 발밑에 있다 %s" % str(spy.arcs))
	if not stomp.is_empty():
		t.ok(absf(float(stomp["to"]) - float(stomp["from"]) - TAU) < 0.0001,
				"그것은 0에서 TAU까지, 통짜 원이다 — _paint_ring이 아니라 _paint_arc를 쓴 이유가 그것이다")
		t.ok(absf(float(stomp["r"]) - 62.4) < 0.001,
				"반지름은 48에서 48 × 2.2로 가는 길의 4분의 1, 62.4px다 (리터럴) — %.4f" % float(stomp["r"]))
		t.ok(absf(float(stomp["width"]) - Look.ARENA_WALL_WIDTH) < 0.001,
				"굵기는 아레나 벽과 같은 무게다 (%.2f)" % float(stomp["width"]))
		t.ok(float(stomp["col_a"]) < Look.CRITTER_SWING_COLOR.a - 0.05,
				"그리고 이미 옅어져 있다 — 알파가 1 - t로 빠진다 (%.4f)" % float(stomp["col_a"]))

	# -- the negative control: the one creature that is not swinging draws nothing extra ------------
	var quiet_p := w.critter_pos[quiet]
	t.ok(_seg_from(spy.lines, quiet_p, 60.0).is_empty()
			and _disc_from(spy.discs, quiet_p, 60.0).is_empty()
			and _arc_from(spy.arcs, quiet_p, 60.0).is_empty(),
			"안 휘두른 다람쥐 둘레 60px 안에는 선도 원반도 호도 없다")
	var quiet_cell := false
	for e: Dictionary in spy.cells:
		if (e["p"] as Vector2).distance_to(quiet_p) < 0.001:
			quiet_cell = true
	t.ok(quiet_cell, "그리고 그 몸은 sim 좌표 그대로 그려진다 — 안 휘두른 몸은 달려들지도 않는다")

	# -- THE CLAIM: two species in the SAME frame did not reach the leaves with the same arguments --
	# Compared pairwise and on the axis each pair is supposed to differ on, rather than by "the lists are not
	# equal" — a single generic inequality is satisfied by two positions being different, which two creatures
	# standing apart already guarantee whatever they drew.
	if not gnaw.is_empty() and not pounce.is_empty():
		t.ok(absf(float(gnaw["r"]) - float(pounce["r"])) > 5.0,
				"같은 프레임에서 들쥐의 점과 사자의 점은 크기가 5px 넘게 다르다 (%.2f vs %.2f)"
						% [float(gnaw["r"]), float(pounce["r"])])
	if not tusk.is_empty() and not stomp.is_empty():
		var tusk_sweep := float(tusk["to"]) - float(tusk["from"])
		t.ok(absf((float(stomp["to"]) - float(stomp["from"])) - tusk_sweep) > 1.0,
				"멧돼지의 호는 부분이고 보스의 호는 통짜다 — 같은 잎, 다른 인수 (%.3f vs %.3f rad)"
						% [tusk_sweep, float(stomp["to"]) - float(stomp["from"])])
	if not bite.is_empty() and not bar.is_empty():
		t.ok(absf(float(bite["width"]) - float(bar["width"])) > 1.0,
				"들개의 획과 코끼리의 막대는 굵기가 다르다 (%.2f vs %.2f)"
						% [float(bite["width"]), float(bar["width"])])

	# -- the lunge is a species value, and it is the elephant's and the lion's whole other half -----
	# Read off `_paint_cell`'s own position, which is the ONLY place the multiplier ever appears — no gesture
	# leaf is handed it. `sin(pi × 0.25) × 14` = 9.8995px, and the two rows that are not 1.0 have to come
	# back at exactly two and three times that.
	var crow_push := _drawn_push(spy, w.critter_pos[rows[0]], 12.0)
	var ele_push := _drawn_push(spy, w.critter_pos[rows[4]], 40.0)
	var lion_push := _drawn_push(spy, w.critter_pos[rows[5]], 26.0)
	t.ok(absf(crow_push - 9.8995) < 0.01,
			"까마귀는 9.8995px 달려든다 — sin(pi/4) × SWING_LUNGE_PUSH (%.4f)" % crow_push)
	t.ok(absf(ele_push - crow_push * 2.0) < 0.02,
			"코끼리는 그 두 배를 달려든다 (%.4f / 기대 %.4f)" % [ele_push, crow_push * 2.0])
	t.ok(absf(lion_push - crow_push * 3.0) < 0.02,
			"사자는 세 배를 달려든다 — 사자에게는 달려드는 것 자체가 몸짓이다 (%.4f / 기대 %.4f)"
					% [lion_push, crow_push * 3.0])
	t.ok(_drawn_push(spy, quiet_p, 7.0) < 0.001,
			"안 휘두른 다람쥐는 0px 달려든다 — 배수는 휘두를 때만 붙는다")

	# ================= the second frame: three quarters through the window ==========================
	# ⚠ **`sin(pi x)` is symmetric about the middle, so the LUNGE is identical at 0.25 and 0.75.** That is
	# what makes this frame a clean read of the gesture alone: 까마귀 and 코끼리 must come back unchanged
	# (their shapes do not read `t` at all) and the other five must all have moved.
	for k: int in rows:
		w.critter_swing_show[k] = Look.CRITTER_SWING_TIME * 0.75
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 4, "늦은 프레임에도 선은 여전히 넷이다")
	t.eq(spy.discs.size(), 2, "원반도 둘이다")
	t.eq(spy.arcs.size(), 2, "호도 둘이다")

	var gnaw2 := _disc_from(spy.discs, mouse_at + dir * 5.0, tol)
	t.ok(not gnaw2.is_empty(), "들쥐의 점은 여전히 닿은 지점에 있다")
	if not gnaw2.is_empty():
		t.ok(absf(float(gnaw2["r"]) - 0.625) < 0.001,
				"그런데 반지름은 5 × 0.5 × (1 - 0.75) = 0.625px로 줄었다 (리터럴) — %.4f" % float(gnaw2["r"]))
	var pounce2 := _disc_from(spy.discs, lion_at + dir * 46.8, tol)
	t.ok(not pounce2.is_empty(), "사자의 점도 같은 자리에 있다")
	if not pounce2.is_empty():
		t.ok(absf(float(pounce2["r"]) - 4.0) < 0.001,
				"그리고 16 × (1 - 0.75) = 4px로 줄었다 (리터럴) — %.4f" % float(pounce2["r"]))
	var bite2 := _seg_from(spy.lines, dog_at, tol)
	t.ok(not bite2.is_empty(), "들개의 획도 여전히 몸에서 시작한다")
	if not bite2.is_empty() and not bite.is_empty():
		var bd2 := dir.rotated(lerpf(-Look.SWING_BITE_SWEEP, Look.SWING_BITE_SWEEP, 0.75))
		t.ok((bite2["b"] as Vector2).distance_to(dog_at + bd2 * 20.0) < tol,
				"그런데 이번엔 +10° 쪽으로 돌아가 있다 — 창을 가로질러 휘저은 것이다")
		t.ok((bite2["b"] as Vector2).distance_to(bite["b"]) > 5.0,
				"두 프레임의 끝은 5px 넘게 다르다 (%.2f)"
						% (bite2["b"] as Vector2).distance_to(bite["b"]))
	var tusk2 := _arc_from(spy.arcs, boar_at, tol)
	t.ok(not tusk2.is_empty(), "멧돼지의 호도 같은 자리에 있다")
	if not tusk2.is_empty():
		t.ok(absf(rad_to_deg(float(tusk2["to"]) - float(tusk2["from"])) - 67.5) < 0.01,
				"그런데 90°의 4분의 3인 67.5°까지 열렸다 (%.3f°)"
						% rad_to_deg(float(tusk2["to"]) - float(tusk2["from"])))
	var stomp2 := _arc_from(spy.arcs, boss_at, tol)
	t.ok(not stomp2.is_empty(), "보스의 고리도 같은 자리에 있다")
	if not stomp2.is_empty() and not stomp.is_empty():
		t.ok(absf(float(stomp2["r"]) - 91.2) < 0.001,
				"그런데 91.2px까지 자랐다 (리터럴) — %.4f" % float(stomp2["r"]))
		t.ok(float(stomp2["col_a"]) < float(stomp["col_a"]) - 0.05,
				"그리고 더 옅어졌다 (%.4f < %.4f)" % [float(stomp2["col_a"]), float(stomp["col_a"])])

	# The two that must NOT have moved — the control that says the frame really redrew everything.
	t.ok(not _seg_from(spy.lines, crow_at + dir.rotated(Look.SWING_PECK_ANGLE) * 12.0, tol).is_empty(),
			"까마귀의 갈래는 늦은 프레임에도 똑같은 자리다 — 쓸어내는 것이 아니라 갈래이기 때문이다")
	t.ok(not _seg_from(spy.lines, mid - across, tol).is_empty(),
			"코끼리의 막대도 그대로다 — 이 둘만 t를 안 읽는다")

	# ================= the fallback branch, which the shipped tables cannot reach ===================
	# `_paint_swing`'s default arm draws the line this file drew for every species before §6, and **nothing
	# in play can enter it**: the four species without a gesture all carry `SPECIES_FLEES` 1 and never have a
	# swing written at all. A branch no fixture drives is a branch that can be emptied with the round green,
	# so the squirrel is handed a swing by hand — the view reads `critter_swing_show` and knows nothing about
	# who is allowed to attack, which is exactly what makes this drivable without touching the rules.
	w.critter_swing_dir[quiet] = dir
	w.critter_swing_show[quiet] = Look.CRITTER_SWING_TIME * 0.25
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 5, "다람쥐에게 손으로 휘두름을 쥐여 주면 선이 하나 는다 (%d)" % spy.lines.size())
	var quiet_at := _swung_at(quiet_p, dir, 0.25, Parts.Species.SQUIRREL)
	var lash := _seg_from(spy.lines, quiet_at, tol)
	t.ok(not lash.is_empty(), "그 선은 대체 몸짓 — 몸 한가운데에서 시작한다 %s" % str(quiet_at))
	if not lash.is_empty():
		t.ok((lash["b"] as Vector2).distance_to(quiet_at + dir * 10.5) < tol,
				"그리고 7 × CRITTER_SWING_RING 1.5 = 10.5px만큼 휘두른 방향 그대로 뻗는다 (%s / 기대 %s)"
						% [str(lash["b"]), str(quiet_at + dir * 10.5)])
	t.eq(spy.discs.size(), 2, "그런데 원반은 여전히 둘이다 — 대체 몸짓은 선 하나이지 여러 표시가 아니다")
	t.eq(spy.arcs.size(), 2, "호도 여전히 둘이다")

	t.root.remove_child(spy)
	spy.queue_free()


## The distance a body was DRAWN from where it stands. `radius_hint` picks the one cell of that exact drawn
## radius, so two bodies near one point cannot be confused for each other.
func _drawn_push(spy: SwingSpy, at: Vector2, radius_hint: float) -> float:
	var best := -1.0
	for e: Dictionary in spy.cells:
		if absf(float(e["r"]) - radius_hint) > 0.001:
			continue
		var d := (e["p"] as Vector2).distance_to(at)
		if best < 0.0 or d < best:
			best = d
	return maxf(0.0, best)


## Where a creature's body is DRAWN, mid-swing: its sim position plus the lunge. **Re-derived from the curve
## `Look.SWING_LUNGE_TIME`'s own comment states**, never read back from `_lunge_offset`.
func _swung_at(p: Vector2, dir: Vector2, t_frac: float, s: int) -> Vector2:
	var swing_t := Look.CRITTER_SWING_TIME * t_frac
	return p + dir * (sin(PI * (swing_t / Look.SWING_LUNGE_TIME)) * Look.SWING_LUNGE_PUSH
			* float(Look.SPECIES_LUNGE_MUL[s]))


func _seg_from(list: Array, a: Vector2, tol: float) -> Dictionary:
	for e: Dictionary in list:
		if (e["a"] as Vector2).distance_to(a) < tol:
			return e
	return {}


func _disc_from(list: Array, p: Vector2, tol: float) -> Dictionary:
	for e: Dictionary in list:
		if (e["p"] as Vector2).distance_to(p) < tol:
			return e
	return {}


func _arc_from(list: Array, p: Vector2, tol: float) -> Dictionary:
	for e: Dictionary in list:
		if (e["p"] as Vector2).distance_to(p) < tol:
			return e
	return {}


# -- P16: the clone's own swing is still not a creature's --------------------------------------------------
## Both go through `_paint_part_line`, in the same frame, and they must not be the same mark. The clone's
## line is the one thing §6 deliberately did NOT touch — forty simultaneous clone swings are a different
## picture problem from one monster's gesture, and `melee-legibility-ko`'s §B-1 is where that argument lives.
func _p16_the_clone_swing_is_not_a_creatures(t) -> void:
	var w := World.new()
	w.setup(619)
	_silence(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1

	var dog := w._write_critter(Parts.Species.DOG, Vector2(900.0, 700.0),
			int(Rules.SPECIES_FORCE_MIN[Parts.Species.DOG]))
	var dir := Vector2(0.6, 0.8)
	w.critter_swing_dir[dog] = dir
	w.critter_swing_show[dog] = Look.CRITTER_SWING_TIME * 0.25

	var clone := w.swarm.add_clone(0, 5)
	w.swarm.pos[clone] = Vector2(2600.0, 1500.0)
	# `0.0` on purpose: `_lunge_offset` is exactly zero at both ends of its window, so the clone's line starts
	# at its true position and the expectation below needs no lunge term at all.
	w.swarm.swing_show[clone] = 0.0
	w.swarm.swing_dir[clone] = dir

	var spy := SwingSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	t.eq(spy.lines.size(), 2, "한 프레임에 선은 둘 — 분신 하나와 들개 하나 (%d)" % spy.lines.size())
	var clone_seg := _seg_from(spy.lines, w.swarm.pos[clone], 0.2)
	var dog_at := _swung_at(w.critter_pos[dog], dir, 0.25, Parts.Species.DOG)
	var dog_seg := _seg_from(spy.lines, dog_at, 0.2)
	t.ok(not clone_seg.is_empty(), "분신의 선을 찾았다 %s" % str(w.swarm.pos[clone]))
	t.ok(not dog_seg.is_empty(), "들개의 획도 찾았다 %s" % str(dog_at))
	if clone_seg.is_empty() or dog_seg.is_empty():
		t.root.remove_child(spy)
		spy.queue_free()
		return

	var clone_len := (clone_seg["b"] as Vector2).distance_to(clone_seg["a"])
	var dog_len := (dog_seg["b"] as Vector2).distance_to(dog_seg["a"])
	t.ok(absf(clone_len - 27.2) < 0.01, "분신의 선은 8 × 3.4 = 27.2px다 (리터럴) — %.3f" % clone_len)
	t.ok(absf(dog_len - 20.0) < 0.01, "들개의 획은 10 × 2.0 = 20px다 (리터럴) — %.3f" % dog_len)
	t.ok(absf(float(clone_seg["width"]) - 4.0) < 0.001, "분신의 굵기는 4px다 (리터럴)")
	t.ok(absf(float(dog_seg["width"]) - 5.0) < 0.001, "들개의 굵기는 5px다 (리터럴)")
	t.ok(absf(float(clone_seg["width"]) - float(dog_seg["width"])) > 0.5,
			"그래서 같은 잎을 지나도 굵기가 다르다 — 분신의 타격과 몬스터의 몸짓은 여전히 다른 표시다")
	# The clone's line runs straight along its swing direction; the dog's is rotated by the sweep. Same leaf,
	# same frame, different geometry — which is what "still distinct" has to mean.
	var clone_along := ((clone_seg["b"] as Vector2) - (clone_seg["a"] as Vector2)).normalized()
	var dog_along := ((dog_seg["b"] as Vector2) - (dog_seg["a"] as Vector2)).normalized()
	t.ok(absf(clone_along.dot(dir) - 1.0) < 0.001,
			"분신의 선은 휘두른 방향 그대로다 — §6은 분신 쪽을 일부러 안 건드렸다")
	t.ok(clone_along.dot(dog_along) < 0.995,
			"들개의 획은 그 방향에서 돌아가 있다 (내적 %.5f)" % clone_along.dot(dog_along))

	t.root.remove_child(spy)
	spy.queue_free()
