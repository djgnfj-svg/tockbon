extends RefCounted
## The VIEW half of the twelve combat effects: `FieldView` on the live tree, real frames pumped, and
## the arguments every leaf was handed read back and measured.
##
## **Two frames, not one.** A check that reads one frame's final state cannot tell an effect that is
## running from one that is frozen — "the lunge is always 0", "the shake never starts", "the squash
## never changes" all pass a single-frame check. Almost every check below compares two frames, or
## pairs a ceiling with a floor, because `combat-juice`'s own refutation box found four rows of its
## draft measuring only the ceiling.
##
## **The clock is driven by hand, and `_process` is turned off to make that exact.** Headless frames
## do not carry a delta this file can predict, and every number in the spec is a duration — so the
## view's own `_process(delta)` is CALLED with the delta this file chose, and the engine is stopped
## from calling it a second time. That the engine really does call it at all is measured first, with
## `_process` still on, before anything else runs: without that one scene, `set_process(false)` would
## be hiding a missing `_process` behind hand-driving.
##
## ⚠ **`FX_GAIN[n] = 0` cannot be driven from here and is NOT measured.** `Look.FX_GAIN` is a `const`
## Array, so it is read-only at runtime and nothing in `field_view.gd` takes a gain from anywhere
## else. What this file can bite is the accessor's off-by-one (item 1 must read slot 0), and it does.
## The twelve "gain 0" rows of combat-juice's F section stay unmeasured — recorded here rather than
## quietly skipped, because a table that claims twelve rows and delivers zero is the failure this
## repo keeps paying for.
##
## The sim is stepped at `TICK_ONE` (under `Rules.EPS`) wherever a body must not move, and at the
## same delta as the view wherever the sim's OWN clock is what is being measured — the lion's
## telegraph is the one that needs the two clocks to agree, because it is drawn from sim state.


## ⚠ **`step` runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps and carries the leftover**
## (`plan-then-watch`, 5.2), so there is no step too small to do anything any more: a `dt` under one
## sub-step runs ZERO phases and every column stays at its fixture value — which reads as 「the rule
## did not fire」 on every check at once. ⇒ **One sub-step is the smallest thing that happens**, and
## that is what `TICK_ONE` is. A unit already inside its reach still does not walk, so the fixtures
## that needed 「nobody moves」 keep the property they actually needed.
const TICK_ONE := Rules.SIM_SUBSTEP_SEC

## Pixel slack for a coordinate that made a round trip through a `Vector2` — Godot's `real_t` is a
## 32-bit float, so a double computed here and the same double stored in an fx differ in the seventh
## digit. Every defect this file hunts is a whole pixel or more.
const NEAR_PX := 0.01

const ARENA_W := 24
const ARENA_H := 12


## Records every hook's arguments AND a monotonic call number, because the layer order in
## combat-juice's "the layers" table is a contract that final state cannot express: a filled halo at
## 1.35x the body radius drawn AFTER the body erases a 2 px outline and a 3 px dot completely, and
## every count and every argument stays exactly the same.
##
## `seq` is bumped by every hook whether or not the call is recorded, so the numbers stay comparable
## between layers. `tiles_on` is off by default only because 680 tile dictionaries a frame, on every
## frame this file pumps, is the whole net's runtime.
class FieldSpy extends FieldView:
	var seq := 0
	var draws := 0
	var tiles_on := false
	var tiles := []
	var docks := []
	var hulls := []
	var cliff_faces := []
	var bodies := []
	var beaks := []
	var hps := []
	var overlays := []
	var routes := []
	var shots := []
	var halos := []
	var rings := []
	var lines := []
	var sparks := []

	func _draw() -> void:
		seq = 0
		tiles.clear()
		docks.clear()
		hulls.clear()
		cliff_faces.clear()
		bodies.clear()
		beaks.clear()
		hps.clear()
		overlays.clear()
		routes.clear()
		shots.clear()
		halos.clear()
		rings.clear()
		lines.clear()
		sparks.clear()
		super()
		draws += 1

	func _paint_tile(rect: Rect2, fill: Color, line_colour: Color, line_width: float) -> void:
		if tiles_on:
			tiles.append({"rect": rect, "fill": fill, "line": line_colour, "width": line_width,
				"seq": seq})
		seq += 1

	func _paint_dock(rect: Rect2, colour: Color, outline_width: float) -> void:
		docks.append({"rect": rect, "colour": colour, "width": outline_width, "seq": seq})
		seq += 1

	func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color,
			outline_width: float, dot_radius: float, squash: Vector2) -> void:
		bodies.append({"centre": centre, "radius": radius, "corner": corner, "colour": colour,
			"width": outline_width, "dot": dot_radius, "squash": squash, "seq": seq})
		seq += 1

	func _paint_beak(tip: Vector2, left: Vector2, right: Vector2, colour: Color) -> void:
		beaks.append({"tip": tip, "left": left, "right": right, "colour": colour, "seq": seq})
		seq += 1

	func _paint_hp(back: Rect2, back_colour: Color, fill: Rect2, fill_colour: Color) -> void:
		hps.append({"back": back, "back_colour": back_colour, "fill": fill,
			"fill_colour": fill_colour, "seq": seq})
		seq += 1

	func _paint_hull(rect: Rect2, colour: Color, outline_width: float) -> void:
		hulls.append({"rect": rect, "colour": colour, "width": outline_width, "seq": seq})
		seq += 1

	func _paint_cliff_face(points: PackedVector2Array, colour: Color, width: float) -> void:
		cliff_faces.append({"points": points, "colour": colour, "width": width, "seq": seq})
		seq += 1

	func _paint_overlay(rects: Array, colour: Color) -> void:
		overlays.append({"rects": rects, "colour": colour, "seq": seq})
		seq += 1

	func _paint_route(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		routes.append({"from": from, "to": to, "colour": colour, "width": width, "seq": seq})
		seq += 1

	func _paint_shot(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		shots.append({"from": from, "to": to, "colour": colour, "width": width, "seq": seq})
		seq += 1

	func _paint_halo(centre: Vector2, radius: float, colour: Color) -> void:
		halos.append({"centre": centre, "radius": radius, "colour": colour, "seq": seq})
		seq += 1

	func _paint_ring(centre: Vector2, radius: float, colour: Color, width: float) -> void:
		rings.append({"centre": centre, "radius": radius, "colour": colour, "width": width,
			"seq": seq})
		seq += 1

	func _paint_target_line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
		lines.append({"from": from, "to": to, "colour": colour, "width": width, "seq": seq})
		seq += 1

	## ⚠ The point array itself, not a count. Built inside the leaf it would never leave it, and
	## `net_draw_leaf`'s unused-argument scan skips a function whose draw count is 0 — so the pure
	## builder could return anything at all and the round would stay green with nothing on screen.
	func _paint_spark(points: PackedVector2Array, colour: Color, width: float) -> void:
		sparks.append({"points": points, "colour": colour, "width": width, "seq": seq})
		seq += 1


## The HUD layer's one drawer, captured the same way. `HudView` has exactly one hook that reaches a
## rectangle (`_paint_button`, shared by the start button and the five speed chips), so the whole
## spy is one override.
class HudSpy extends HudView:
	var buttons := []

	func _draw() -> void:
		buttons.clear()
		super()

	func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
			col: Color) -> void:
		buttons.append({"rect": rect, "bg": bg, "text": text, "at": at, "fsize": fsize, "col": col})


func run(t) -> void:
	await _the_engine_really_drives_it(t)
	await _transit_body_is_drawn_and_can_flash(t)
	await _hull_waits_and_blinks(t)
	await _destination_marker_both_legs(t)
	await _contact(t)
	await _tracer(t)
	await _the_reaction_waits_for_the_bullet(t)
	await _spark_over_body_under_burst(t)
	await _target_lines(t)
	await _landing_rings(t)
	await _shake(t)
	await _gait(t)
	await _the_ladder_does_not_destroy_the_picture(t)
	await _the_hud_ladder_ages_with_the_speed(t)
	await _zero_speed_freezes_the_picture(t)
	_spark_points_is_a_function_of_progress(t)
	_the_inequalities_the_spark_stands_on(t)
	_fx_gain_is_indexed_by_item_number(t)
	_the_readers_themselves(t)



# -- the speed ladder, and the picture it would destroy if the view did not scale with it ------------

## ⚠⚠ **No net drove a view above 1x before this round, and three of `look.gd`'s own written
## inequalities break at 6x.** `HIT_FLASH_SEC` 0.14 claims 「14% duty against the 1.0 s attack period」;
## at 6x that period is 0.1667 real seconds and an unscaled flash is **84%** — every body permanently
## white. `LUNGE_SEC` 0.18 claims 「exactly 0 at both ends, so no body is ever left sitting displaced」;
## 0.18 > 0.1667, so an unscaled lunge never returns to rest. `SPARK_SEC` 0.12's own eight-neighbour
## bound goes from 0.96 to **5.76**.
##
## ⇒ **`field_view` ages its drawers by `delta * _time_scale`**, and these rows are the only thing
## standing between that line and a destroyed picture. Each one drives the SIM at `dt * k` and the VIEW
## at the real `dt`, exactly as `game.gd::_process` does, and measures over one real attack period.
##
## ⚠ **Every row is bounded at BOTH ends.** A duty ceiling with no floor is green with the effect
## deleted outright — this repo found that on four items at once in the presentation round.
func _the_ladder_does_not_destroy_the_picture(t) -> void:
	for raw_k in [1.0, 2.0, 3.0, 6.0]:
		var k := float(raw_k)
		var m: Dictionary = await _ladder_measure(t, k)
		# ① the white. `CELL_MELEE`'s period is 1.0 s, so the duty is `HIT_FLASH_SEC / 1.0` at every
		# rung once the view is scaled — 0.14. Unscaled at 6x it is 0.84.
		t.ok(float(m["flash_duty"]) > 0.05,
			"%.0f배속 — 몸이 실제로 하얗게 번쩍인다 (듀티 %.3f, 바닥 0.05)" % [k, float(m["flash_duty"])])
		t.ok(float(m["flash_duty"]) <= 0.25,
			"%.0f배속으로 감아도 몸이 하얗게 물들지 않는다 (듀티 %.3f, 천장 0.25)"
				% [k, float(m["flash_duty"])])
		# ② the lunge. Both ends of ONE quantity: it leaves rest, and it comes back to EXACTLY rest.
		t.ok(float(m["lunge_peak"]) > 0.5,
			"%.0f배속 — 때린 몸이 실제로 앞으로 나갔다 (%.2f px, 바닥)" % [k, float(m["lunge_peak"])])
		t.ok(float(m["lunge_duty"]) <= 0.45,
			"%.0f배속으로 감아도 몸이 밀린 채로 안 남는다 (밀려 있던 프레임 비율 %.3f, 천장 0.45)"
				% [k, float(m["lunge_duty"])])
		# ③ the shards. One bundle per body at a time, and the fraction of the period they cover has to
		# stay well under 1 or a body's rim is never clean.
		t.ok(float(m["spark_duty"]) > 0.02,
			"%.0f배속 — 파편이 실제로 튄다 (듀티 %.3f, 바닥)" % [k, float(m["spark_duty"])])
		t.ok(float(m["spark_duty"]) <= 0.45,
			"%.0f배속에서도 불꽃이 몸 테두리를 다 덮지 않는다 (듀티 %.3f, 천장 0.45)"
				% [k, float(m["spark_duty"])])
		t.ok(int(m["spark_max_per_frame"]) <= int(m["bodies_max"]),
			"%.0f배속에서도 한 프레임의 파편 묶음이 몸 수를 안 넘는다 — 몸마다 하나뿐이다 (%d개 / 몸 %d개)"
				% [k, int(m["spark_max_per_frame"]), int(m["bodies_max"])])


## One melee cell beside one bison, driven for `2.0 / k` REAL seconds in 1/60 s real frames — two whole
## attack periods at that rung. The sim is stepped `dt * k` and the view `dt`, which is exactly the
## pair `game.gd::_process` hands out.
##
## Returns the three duties and the lunge's two ends. ⚠ **Everything is read off the CAPTURED draw
## arguments**, never off `_flash_of` / `_lunge_offset` directly: a pure function measured on its own
## proves nothing about whether the picture uses it.
func _ladder_measure(t, k: float) -> Dictionary:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [_spawn(Rules.BISON, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var fv := _view_of(t, b, army)
	fv.set_time_scale(k)

	var soldier_px := Look.tile_point_px(Vector2(12, 5))
	var plain_enemy := Look.body_colour_of(true)
	var frames := int(round(120.0 / k))
	var flash_frames := 0
	var spark_frames := 0
	var spark_max := 0
	var lunge_peak := 0.0
	var lunge_frames := 0
	var bodies_max := 0
	var drawn := 0
	for _f in frames:
		await _frame(t, b, fv, (1.0 / 60.0) * k, 1.0 / 60.0)
		drawn += 1
		# The bison is the body that gets hit; the cell is the body that lunges.
		for rawb: Dictionary in fv.bodies:
			if _col(rawb, "colour") != plain_enemy and _col(rawb, "colour") == Look.body_colour_of(true).lerp(
					Look.COL_FLASH, Look.HIT_FLASH_STRENGTH):
				flash_frames += 1
				break
		var here := 0
		for _s in fv.sparks:
			here += 1
		spark_max = maxi(spark_max, here)
		bodies_max = maxi(bodies_max, fv.bodies.size())
		if here > 0:
			spark_frames += 1
		for rawb2: Dictionary in fv.bodies:
			if _col(rawb2, "colour") == Look.body_colour_of(false):
				var off: float = (_pt(rawb2, "centre") - soldier_px).length()
				lunge_peak = maxf(lunge_peak, off)
				# ⚠⚠ **Counted as a DUTY, not as 「it was 0 at some point」.** Every fixture starts at
				# rest, so 「it returned to 0」 is true on frame one and stays true — measured: the
				# unscaled 6x view passed that shape with the body never returning at all. The fraction
				# of frames on which the body is displaced is the quantity that actually moves: scaled
				# it is `LUNGE_SEC / period` = 0.18, unscaled at 6x it approaches 1.0.
				if off > 0.01:
					lunge_frames += 1
	t.ok(drawn == frames and frames > 0, "%.0f배속 — 실제 프레임 %d장을 돌렸다 (자가 점검)" % [k, drawn])
	_drop(t, fv)
	return {
		"flash_duty": float(flash_frames) / float(maxi(frames, 1)),
		"spark_duty": float(spark_frames) / float(maxi(frames, 1)),
		"spark_max_per_frame": spark_max,
		"lunge_peak": lunge_peak,
		"lunge_duty": float(lunge_frames) / float(maxi(frames, 1)),
		"bodies_max": bodies_max,
	}


## ⚠⚠ **The HUD takes the same multiplier, and nothing proved it USED it.** `net_shell` reads
## `hud_view._speed_scale` off the field and finds the shell's number there — which proves it was
## computed and handed down, never that a drawer ages by it. **Measured: `_fx_step(delta *
## _speed_scale)` changed to `_fx_step(delta)` left the whole round green**, because `_chip_fx` is
## this layer's only drawer and it can only fire pre-commit, where the shell is always at 1x. The
## moment a second drawer lands here, or the start button gains a post-commit state, the ladder
## destroys it silently — this is `CLAUDE.md`'s named shape: capturing an argument proves it was
## computed, never that it was used.
##
## The shake is read off the DRAWN rect, not off `_chip_offset`, so a hook that stopped applying the
## offset would fail here too. Both arms run the same REAL interval and the same real frames; only
## the multiplier differs, so the 1x arm is the self-check that the interval is genuinely short.
func _the_hud_ladder_ages_with_the_speed(t) -> void:
	# One sixth of the drawer's life, plus a hair. At 6x that is the whole of it; at 1x it is a
	# sixth of it, and the button is still visibly displaced.
	var real_sec := Look.CHIP_FX_SEC / 6.0 + 0.001
	var top := float(Rules.SPEED_STEPS[Rules.speed_slot_count() - 1])
	t.eq(top, 6.0, "사다리 꼭대기가 6배속이다 (자가 점검 — 이 행의 산술이 그 숫자에서 나온다)")
	for raw_k in [1.0, top]:
		var k := float(raw_k)
		var army := _army_of([Rules.CELL_MELEE])
		var b := _planning_battle_of(_open(), army, [_spawn(Rules.BISON, 13, 5)], 999.0)
		var hud := HudSpy.new()
		hud.bind(b)
		t.root.add_child(hud)
		hud.set_process(false)
		hud.set_speed(Rules.SPEED_SLOT_DEFAULT if k == 1.0 else Rules.speed_slot_count() - 1, k)
		# A refused start — `boats` is empty, so `commit()` says false and this is the real refusal
		# the shell pushes in, not a hand-set field.
		t.ok(not b.commit(), "%.0f배속 — 빈 계획으로 누른 시작이 거절된다 (자가 점검)" % k)
		hud.note_chip(0, false)
		await t.pump_frames(1)
		var peak := _start_shift(hud)
		t.ok(peak.length() > 0.0,
			"%.0f배속 — 거절 흔들림이 실제로 일어난다 (%.2f px, 바닥)" % [k, peak.length()])
		t.ok(peak.length() <= Look.REFUSE_SHAKE_PX + 0.01,
			"%.0f배속 — 그리고 REFUSE_SHAKE_PX 를 안 넘는다 (천장)" % k)
		# The real clock advances by the same amount in both arms.
		hud._process(real_sec)
		await t.pump_frames(1)
		var after := _start_shift(hud)
		if k == 1.0:
			t.ok(after.length() > 0.0,
				"1배속 — 실제 %.3fs 뒤에도 단추가 아직 흔들리고 있다 (자가 점검 — 간격이 진짜 짧다)"
					% real_sec)
		else:
			t.eq(after, Vector2.ZERO,
				"%.0f배속 — 같은 실제 시간에 흔들림이 정확히 끝나 있다 (HUD 도 배속으로 늙는다)" % k)
		t.root.remove_child(hud)
		hud.free()


## The start button's displacement from its resting rect, read off the captured draw call. The
## reader matches on SIZE because the shake moves the position, and a reader keyed on the whole rect
## would stop finding the button on the one frame that matters.
func _start_shift(hud: HudSpy) -> Vector2:
	for raw in hud.buttons:
		var btn: Dictionary = raw
		if (btn["rect"] as Rect2).size == Look.HUD_START_SIZE_PX:
			return (btn["rect"] as Rect2).position - Look.start_rect_px().position
	return Vector2(1e9, 1e9)


## ⚠ **0x is not a viewing rate for the picture either.** A still sim under a running animation is the
## exact shape 「pause」 must not be, so the view's own clock has to stop with it. Both ends: the effect
## exists at all on the frame of the blow, and it does not age by so much as one frame afterwards.
func _zero_speed_freezes_the_picture(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [_spawn(Rules.BISON, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var fv := _view_of(t, b, army)

	# One real frame at 1x to make a blow, and to spawn the drawers this row is about.
	fv.set_time_scale(1.0)
	await _frame(t, b, fv, TICK_ONE, 1.0 / 60.0)
	var flash_col := Look.body_colour_of(true).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH)
	var lit := 0
	for rawb: Dictionary in fv.bodies:
		if _col(rawb, "colour") == flash_col:
			lit += 1
	t.eq(lit, 1, "0배속 시험 — 먼저 1배속에서 몸 하나가 실제로 번쩍였다 (바닥)")
	var frozen_col := _col(_at(fv.bodies, 0), "colour")
	var frozen_pos := _pt(_at(fv.bodies, 1), "centre")

	# Now 0x, and twenty real frames. Nothing on either clock may move.
	fv.set_time_scale(0.0)
	for _f in 20:
		await _frame(t, b, fv, 0.0, 1.0 / 60.0)
	t.eq(_col(_at(fv.bodies, 0), "colour"), frozen_col,
		"0배속이면 연출도 멈춘다 — 스무 프레임을 돌려도 흰색이 한 톨도 안 빠진다")
	t.eq(_pt(_at(fv.bodies, 1), "centre"), frozen_pos, "런지도 그 자리에 얼어붙어 있다")
	_drop(t, fv)

# -- the instrument, inverted ----------------------------------------------------------------------

## Cases that fail the READERS above rather than the tree. Twice in one night this repo shipped a
## check carrying the very defect it was written to catch, and neither was found by inverting the
## code — both were found by inverting the check. `_before` is the one that matters: written as a
## bare `<` on two possibly-missing keys it answers "yes, in order" about a layer that was never
## drawn, and the layer contract would be green for a screen with no halos on it at all.
func _the_readers_themselves(t) -> void:
	t.ok(_before({"seq": 1}, {"seq": 2}), "_before — 앞선 것이 앞이다")
	t.ok(not _before({"seq": 2}, {"seq": 1}), "_before — 뒤선 것은 앞이 아니다")
	t.ok(not _before({}, {"seq": 2}), "_before — 왼쪽이 안 그려졌으면 거짓이다 (없는 층이 초록이 되면 안 된다)")
	t.ok(not _before({"seq": 1}, {}), "_before — 오른쪽이 안 그려져도 거짓이다")

	t.eq(_at([], 0), {}, "_at — 빈 포착은 빈 사전이다 (인덱싱해서 넷을 죽이지 않는다)")
	t.eq(_num({}, "radius"), -99999.0, "_num — 없는 값은 어떤 실제 값과도 안 맞는 센티넬이다")
	t.eq(_pt({}, "centre"), Vector2(-99999.0, -99999.0), "_pt — 없는 좌표도 마찬가지다")
	t.eq(_col({}, "colour"), Look.COL_HOLE, "_col — 없는 색은 어떤 연출도 안 쓰는 색이다")
	t.eq(_pts({}).size(), 0, "_pts — 없는 점 배열은 길이 0이다")

	# `_rings_of` sorts by RGB with the alpha ignored, because every ring fades its own alpha. The
	# case that matters is the near miss: the landing ring and the ally burst share an RGB, so the two
	# must never be told apart by colour alone in the same frame — and they never are, above.
	var fake := FieldSpy.new()
	fake.rings = [
		{"colour": Look.COL_AREA_RING, "radius": 1.0},
		{"colour": Look.COL_LAND_RING, "radius": 2.0},
		{"colour": Look.body_colour_of(true), "radius": 3.0},
	]
	t.eq(_rings_of(fake, Look.COL_AREA_RING).size(), 1, "_rings_of — 광역 링만 하나 골라낸다")
	t.eq(_rings_of(fake, Look.body_colour_of(true)).size(), 1, "_rings_of — 적 색 파열만 하나 골라낸다")
	t.eq(_rings_of(fake, Look.COL_BEAK).size(), 0, "_rings_of — 없는 색이면 하나도 안 고른다")
	fake.free()

	var pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(0, 4)])
	t.ok(absf(_max_dist(pts, Vector2.ZERO) - 10.0) <= 1e-6, "_max_dist — 가장 먼 점을 잰다")
	t.ok(absf(_min_dist(pts, Vector2.ZERO)) <= 1e-6, "_min_dist — 가장 가까운 점을 잰다")
	t.eq(_max_dist(PackedVector2Array(), Vector2.ZERO), 0.0, "_max_dist — 빈 배열은 0이다 (바닥 검사가 문다)")
	t.ok(_centroid(PackedVector2Array([Vector2(0, 0), Vector2(4, 2)])).is_equal_approx(Vector2(2, 1)),
			"_centroid — 무게중심을 잰다")
	t.ok(absf(_luma(Look.COL_FLASH) - 1.0) <= 1e-6, "_luma — 흰색의 밝기가 1.0 이다 (Rec.709)")


# -- the engine's own clock ------------------------------------------------------------------------

## Everything after this runs with `_process` off and the delta chosen by hand. **This scene is what
## keeps that honest**: with `_process` deleted outright, every other check here would still pass,
## and the game would draw one frozen frame forever.
func _the_engine_really_drives_it(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [_spawn(Rules.BISON, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var fv := FieldSpy.new()
	fv.setup(b, army, _open())
	t.root.add_child(fv)

	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.events.size() > 0, "sim 이 이 프레임에 사건을 냈다 (%d개)" % b.events.size())
	await t.pump_frames(3)
	t.ok(fv.draws >= 1, "트리 위에서 _draw 가 진짜 돌았다 (%d프레임)" % fv.draws)
	t.ok(fv._fx.size() > 0, "엔진이 부른 _process 가 사건을 이펙트로 퍼갔다 (%d개)" % fv._fx.size())
	t.ok(fv._body.size() > 0, "그리고 몸 서랍도 채웠다 (%d개)" % fv._body.size())
	var aged := 0.0
	for raw in fv._fx:
		var fx: Dictionary = raw
		aged = maxf(aged, float(fx["age"]))
	t.ok(aged > 0.0, "그리고 프레임마다 나이를 더했다 (%.4f초) — 뷰가 자기 시계를 돈다" % aged)

	# The tile count is here because this is the one scene where the engine draws on its own.
	fv.tiles_on = true
	fv._process(0.001)
	await t.pump_frames(2)
	# The literal, not `(Look.GRID_W + 2*margin) * (Look.GRID_H + 2*margin)` — a check whose bound
	# comes from the constants it is checking shrinks with them. **72 x 56 = 4032** (48 + 2x12,
	# 32 + 2x12): `WATER_MARGIN_TILES` went 5 -> 12 with `ZOOM_MIN` 0.5625 -> 0.45, because at the new
	# framing the visible world runs 11.6 tiles past the grid on the x axis and bare ground would show.
	# ⚠ `_paint_tile` is 2 draw calls, so this is 8064 a frame, up from 4872 — `plan-then-watch`, 6.3.
	t.eq(fv.tiles.size(), 4032,
			"지형을 물 여백까지 4032칸 그렸다 — 줌 아웃해도 가장자리에 맨바닥이 안 드러난다")
	fv.tiles_on = false
	_drop(t, fv)


# -- P4: a soldier at sea is finally drawn, and can finally flash -----------------------------------

## `boat-and-landing` stage 5, P4. `battle.is_hittable` already returned true for a TRANSIT soldier
## and the ATTACK tracer already flew to the boat — the rule existed with nothing on screen for it to
## land on. This proves the body now exists to hit: two bodies while boarded (not one), the ally
## coloured one sitting inside its OWN boat's hull rectangle, and — once a crow actually lands a
## hit — the white mix and the halo that item 3 has always produced for anyone else `is_hittable`.
func _transit_body_is_drawn_and_can_flash(t) -> void:
	# TWO passengers, and now on TWO BOATS — 결정 14R deleted capacity, so a boat carries the one
	# soldier that was dragged onto it (`plan-then-watch`, 4.2). That makes the fallback bug this
	# fixture was built for MORE reachable, not less: each body has to be drawn at ITS OWN boat's
	# position, and a halo reading some shared boat point lands on the wrong hull entirely.
	var army := _army_of([Rules.CELL_RANGED, Rules.CELL_RANGED])
	# 3.0 tiles from the harbour's own water, inside a crow's 4.5-tile reach — the same distance
	# `net_battle`'s TRANSIT fixture already measured for "the crow can hit a boat this far out".
	var b := _planning_battle_of(_port(), army, [_spawn(Rules.CROW, 2, 2)], 999.0)
	var fv := _view_of(t, b, army)

	# Two DIFFERENT landings, so the two boats are two places. Aimed at one tile they would sail the
	# identical route and the "not drawn on top of each other" floor below would be measuring nothing.
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	var landing2 := int(_PORT_LANDING.y - 2.0) * ARENA_W + int(_PORT_LANDING.x)
	t.ok(b.send(0, landing) >= 0, "1번 병사를 배에 태워 보냈다 (자가 점검)")
	t.ok(b.send(1, landing2) >= 0, "2번 병사는 다른 해안으로 보냈다 (자가 점검)")
	t.ok(b.commit(), "시작을 눌러 두 척을 띄웠다 (자가 점검)")

	# 0.4 s of SIM and 0.001 s of VIEW, on purpose. The two boats leave the same harbour, so a single
	# sub-step leaves them 1.2 px apart and the "not drawn on top of each other" floor below would be
	# measuring nothing; 0.4 s at `BOAT_SPEED` 4.0 is 1.6 tiles of divergence and neither has arrived
	# (the shorter leg is 4.0 tiles). The view clock stays at ~0 so no hit reaction has surfaced yet
	# and the two bodies are still their own colour.
	await _frame(t, b, fv, 0.4, 0.001)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "병사 둘 다 아직 배 위에 있다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.TRANSIT, "(자가 점검, 두 번째 병사)")
	t.eq(fv.bodies.size(), 3, "적 하나 + 배 위의 병사 둘, 몸 셋을 그렸다 — 예전엔 하나(적)뿐이었다")
	# 층 6(배)이 층 7(적)보다 먼저 그려지므로 배 위의 병사 둘이 인덱스 0·1이다.
	var body0 := _at(fv.bodies, 0)
	var body1 := _at(fv.bodies, 1)
	t.eq(_col(body0, "colour"), Look.body_colour_of(false), "1번 병사도 자기 편 색이다")
	t.eq(_col(body1, "colour"), Look.body_colour_of(false), "2번 병사도 자기 편 색이다")
	# Every hull is `BOAT_SLOT_PX 26 + 2 x BOAT_HULL_PAD_PX 10` = 46 px wide now — the 124 / 72 pair
	# died with the boat table. Each passenger has to be inside ITS OWN boat's rectangle.
	var hull_w := 46.0
	t.eq(_hull_rect_at(b, 0, hull_w).has_point(_pt(body0, "centre")), true,
			"1번 병사는 자기 배의 선체 사각형 안에서 그려졌다 — 갑판 위다")
	t.eq(_hull_rect_at(b, 1, hull_w).has_point(_pt(body1, "centre")), true,
			"2번 병사도 자기 배의 선체 사각형 안이다 — 남의 배가 아니다")
	t.eq(fv.hps.size(), 3, "몸마다 HP 막대도 하나씩이다 — 배 위에서도 막대가 있다")

	# The two passengers must not be drawn on top of each other. A body diameter is the floor: closer
	# than that and the two outlines would overlap, which is exactly what a body drawn at some shared
	# boat point instead of its own would produce.
	var one_diameter := Look.body_radius_of(Rules.CELL_RANGED) * 2.0
	t.ok(_pt(body0, "centre").distance_to(_pt(body1, "centre")) >= one_diameter,
		"두 병사가 적어도 몸 지름만큼 떨어져 그려진다 (%.1f px, 지름 %.1f px)"
		% [_pt(body0, "centre").distance_to(_pt(body1, "centre")), one_diameter])

	# Real sim time now, until the crow actually lands a hit on ONE of the boarded soldiers.
	var before_hp0 := army.hp[0]
	var before_hp1 := army.hp[1]
	var hit_id := -1
	for _f in 60:
		await _frame(t, b, fv, 0.05, 0.05)
		if army.hp[0] < before_hp0:
			hit_id = 0
			break
		if army.hp[1] < before_hp1:
			hit_id = 1
			break
	t.ok(hit_id >= 0, "까마귀가 실제로 배 위의 한 병사를 맞췄다 (자가 점검)")

	# The reaction is delayed by SHOT_SEC (already proven elsewhere in this file) — a few more frames
	# clear it, and this asks two things at once: does the white mix and the halo exist AT ALL for a
	# body that, before this round, was never drawn to receive them (G's headline), AND does the halo
	# land where THAT soldier's own body is, not merely somewhere on the boat (G's actual gap — the
	# halo's fallback path used to read `battle.soldier_pos[ti]`, the boat's shared raw position,
	# while the body read the deck slot; the two only ever agreed by coincidence in a one-passenger
	# fixture where the slot happened to be close to the boat's own point).
	# ⚠ Sim `dt` 0.0, not 0.001: a `dt` under one sub-step runs zero phases anyway, and writing it as
	# zero says what is meant — only the VIEW clock moves here, to clear `SHOT_SEC`.
	await _frame(t, b, fv, 0.0, Look.SHOT_SEC + 0.02)
	var flash_col := Look.body_colour_of(false).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH)
	var hit_body := {}
	var flashed := 0
	for raw: Dictionary in fv.bodies:
		if raw["colour"] == flash_col:
			hit_body = raw
			flashed += 1
	t.ok(not hit_body.is_empty(),
		"맞은 뒤 그 몸에 흰색이 실제로 섞였다 — 그릴 몸이 없던 예전에는 있을 수 없던 일이다")
	# ⚠ **Counted, not asserted as one halo.** The crow's period is 1.0 s and this fixture runs several
	# seconds of sim, so the NUMBER of hits is not a stable quantity — what is stable, and what G's gap
	# was actually about, is WHERE they land. So: exactly one body is white, and **every** halo sits on
	# that body. A halo reading a boat's shared point instead of the passenger's own lands off it.
	t.eq(flashed, 1, "맞은 병사 하나만 하얗게 물들었다 — 안 맞은 병사는 자기 색 그대로다")
	t.ok(fv.halos.size() >= 1, "헤일로가 떴다 (바닥 — 하나도 없으면 연출이 아예 없는 것이다)")
	# The two ends of the claim, and the count is deliberately not one of them: a halo is anchored where
	# the body stood when it was spawned, and this fixture runs several crow periods, so older halos sit
	# behind the moving boat. What has to be true is that one of them is ON the body that was hit, and
	# that NONE of them is on the soldier who was not.
	var other := {}
	for raw: Dictionary in fv.bodies:
		if raw["colour"] == Look.body_colour_of(false):
			other = raw
	var on_hit := 0
	var on_other := 0
	for raw: Dictionary in fv.halos:
		if _pt(raw, "centre").distance_to(_pt(hit_body, "centre")) <= NEAR_PX:
			on_hit += 1
		if not other.is_empty() and _pt(raw, "centre").distance_to(_pt(other, "centre")) <= NEAR_PX:
			on_other += 1
	t.ok(not other.is_empty(), "안 맞은 병사의 몸도 화면에 있다 (자가 점검)")
	t.ok(on_hit >= 1, "헤일로가 맞은 그 몸의 정확한 자리에 떴다 — 배의 대표 위치가 아니라 그 병사의 자리다")
	t.eq(on_other, 0, "안 맞은 병사 위에는 헤일로가 하나도 없다")
	_drop(t, fv)


## Boat `i`'s hull rectangle, built the way `field_view._hull_rect` builds it and centred on that
## boat's OWN `pos` — so a body drawn at some other boat's point falls outside it.
func _hull_rect_at(b: Battle, i: int, hull_w: float) -> Rect2:
	var at := Look.tile_point_px(Vector2((b.boats[i] as Dictionary)["pos"]))
	return Rect2(at - Vector2(hull_w, Look.BOAT_HULL_H_PX) * 0.5, Vector2(hull_w, Look.BOAT_HULL_H_PX))


## `Color` has no `distance_to` — Euclidean distance over r/g/b, alpha ignored (every colour here is
## opaque anyway).
func _col_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## The colour of the hull whose width matches `want_w` (boat 0's own, cap 4), or `Look.COL_HULL_WAIT`
## itself if none is found — a sentinel no rest-state hull could ever equal, so a missing capture
## reddens the check that wanted it rather than passing by accident.
func _hull_colour(fv: FieldSpy, want_w: float) -> Color:
	for raw: Dictionary in fv.hulls:
		if absf((raw["rect"] as Rect2).size.x - want_w) < 0.01:
			return raw["colour"]
	return Look.COL_HULL_WAIT


## P7 (`boat-and-landing` stage 5). `boat["t"]` is poked directly to force "arrived, still OUTBOUND"
## — the exact shape `_try_unload` leaves a boat in when the shore has fewer free tiles than cargo.
## `net_boat._boat_waits_for_shore` already proves the SIM half; this only asks whether the VIEW
## paints it, and paints it as a BLINK — bound at both ends, or a static tint would pass this too.
func _hull_waits_and_blinks(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(Rules.BISON, 20, 9)], 999.0)
	var fv := _view_of(t, b, army)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	t.ok(b.send(0, landing) >= 0 and b.commit(), "배를 한 척 띄웠다 (자가 점검)")
	# The sim is frozen from here (`sim_dt` 0.0 in every `_frame` call below) — with the coast wide
	# open in `_port()`, a real `_phase_landings` would unload this boat for real on the very next
	# `step` and silently resolve the forced state before the view ever saw "waiting" at all.
	var boat: Dictionary = b.boats[0]
	boat["t"] = float(boat["dist"]) / float(boat["speed"])
	b.boats[0] = boat

	# Every hull is `BOAT_SLOT_PX 26 + 2 x BOAT_HULL_PAD_PX 10` = 46 px. LITERAL: the 124 / 72 pair
	# died with the boat table, and a width read back off `_hull_rect` would move with it.
	var hull_w := 46.0
	# A tolerance, not `==`: the clock has already moved 0.001s off zero, so the blend is a hair
	# above 0.0 rather than exactly it — the floor this row measures is "still near COL_BOAT", not
	# "bit-identical to it".
	await _frame(t, b, fv, 0.0, 0.001)
	t.ok(_col_dist(_hull_colour(fv, hull_w), Look.COL_BOAT) < 0.01,
		"깜빡임 시계가 막 시작해 아직 기본색에 가깝다 (바닥)")

	# ⚠ LITERAL seconds from here, never a fraction of `Look.HULL_WAIT_BLINK_SEC` — a check that steps
	# "a quarter of whatever the constant is" cannot catch the constant itself moving (measured:
	# `HULL_WAIT_BLINK_SEC` 0.5 -> 0.02 stayed green under the derived form). At the real 0.5s period,
	# 0.25s in is the PEAK (`cos(pi) = -1`) and 0.5s in is back at rest (`cos(2*pi) = 1`); at 0.02s
	# those two checkpoints land many cycles later, at an unpredictable phase.
	await _frame(t, b, fv, 0.0, 0.249)   # cumulative ~0.25s
	var peak := _hull_colour(fv, hull_w)
	t.ok(_col_dist(peak, Look.COL_HULL_WAIT) < 0.05,
		"0.25초(리터럴) 뒤엔 대기색에 거의 닿아 있다 — 주기가 진짜 0.5초일 때만 맞는 위상이다 (%.3f 차)"
		% _col_dist(peak, Look.COL_HULL_WAIT))
	t.ok(_col_dist(peak, Look.COL_BOAT) > 0.3, "그리고 기본색과는 확실히 멀다 (%.3f 차)" % _col_dist(peak, Look.COL_BOAT))

	await _frame(t, b, fv, 0.0, 0.25)   # cumulative ~0.5s
	var full := _hull_colour(fv, hull_w)
	t.ok(_col_dist(full, Look.COL_BOAT) < 0.05,
		"0.5초(리터럴) 뒤엔 다시 기본색 가까이 돌아온다 — 한 바퀴를 정확히 돌았다, 고정 틴트가 아니다")
	_drop(t, fv)


## P5 / P6 (`boat-and-landing` stage 5). The whole crossing is on screen, both legs: a ring on the
## target tile and a route line from the hull to it while OUTBOUND, and — without which the fleet
## TELEPORTS home and 4.3's relocation rule never reaches the screen — the SAME route line pointing
## at the new harbour while RETURNING, no ring, no passengers.
##
## `boat["phase"]`/`["home"]`/`["soldiers"]` are poked directly into the RETURNING shape
## `_phase_landings` itself produces on a real arrival — `net_boat` already proves the sim transition;
## this only asks whether the view reads the field it changed.
func _destination_marker_both_legs(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(Rules.BISON, 20, 9)], 999.0)
	var fv := _view_of(t, b, army)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	t.ok(b.send(0, landing) >= 0 and b.commit(), "배를 한 척 띄웠다 (자가 점검)")

	await _frame(t, b, fv, TICK_ONE, 0.001)
	var target_px := Look.tile_point_px(b.grid.tile_point(landing))
	var ring_found := false
	for raw: Dictionary in fv.rings:
		if _pt(raw, "centre").distance_to(target_px) <= NEAR_PX:
			ring_found = true
	t.ok(ring_found, "가는 중에는 목표 칸에 도착 링이 떠 있다")
	t.eq(fv.routes.size(), 1, "항로 선도 하나 그렸다")
	t.eq(_pt(_at(fv.routes, 0), "to"), target_px, "그 선이 목표 칸을 향한다")
	t.eq(_pt(_at(fv.routes, 0), "from"), Look.tile_point_px(Vector2(b.boats[0]["pos"])),
		"그리고 배 자신의 자리에서 출발한다 (from 도 잰다 — to 만 재면 collapsed line 이 안 잡힌다)")

	# `sim_dt` 0.0 from here — `to`/`dist`/`t` still hold the OUTBOUND leg's own values (the view
	# never reads them for a RETURNING boat, only `home`), so a real `step` would misread `arrived`
	# against them and could remove the boat from `battle.boats` before the view ever saw it.
	# `pos` is also moved to the landing tile — the real position a RETURNING boat actually starts
	# from (`_phase_landings` sets `boat["from"] = _point_of_tile(target)`). `_port()` has only ONE
	# harbour, so leaving `pos` where it was (still near the harbour, from the tiny `t` above) would
	# make "home" and "here" nearly the same point and the from/to-apart check below couldn't tell a
	# real line from a collapsed one — the fixture's own fault, not a control worth keeping.
	var home_hb := b.grid.start_harbour
	var boat: Dictionary = b.boats[0]
	boat["phase"] = Battle.Phase.RETURNING
	boat["soldiers"] = []
	boat["home"] = home_hb
	boat["pos"] = Vector2(_PORT_LANDING)
	b.boats[0] = boat

	await _frame(t, b, fv, 0.0, 0.001)
	var home_px := Look.tile_point_px(b.grid.tile_point(int(b.grid.harbour_tiles[home_hb])))
	var ring_gone := true
	for raw: Dictionary in fv.rings:
		if _pt(raw, "centre").distance_to(target_px) <= NEAR_PX:
			ring_gone = false
	t.ok(ring_gone, "돌아가는 중에는 도착 링이 사라진다 — 더는 노리는 칸이 없다")
	t.eq(fv.routes.size(), 1, "항로 선은 여전히 하나다")
	t.eq(_pt(_at(fv.routes, 0), "to"), home_px, "이제는 새 항구를 향한다 — 배가 순간이동하지 않는다")
	# ⚠ `to` alone passes a line collapsed to a point (`_paint_route(anchor, home_px)` mutated to
	# `_paint_route(home_px, home_px)`) — measured green under a check that only read `to`. `from`
	# has to be the boat's OWN position (still near the landing, nowhere near `home_px` in this
	# fixture), and the two ends have to actually be apart.
	t.eq(_pt(_at(fv.routes, 0), "from"), Look.tile_point_px(Vector2(b.boats[0]["pos"])),
		"그리고 여전히 배 자신의 자리에서 출발한다 — from 이 조용히 to 로 무너지지 않았다")
	t.ok(_pt(_at(fv.routes, 0), "from").distance_to(_pt(_at(fv.routes, 0), "to")) > 1.0,
		"두 끝점이 실제로 떨어져 있다 (자가 점검 아님 — from 이 무너지면 여기서 문다)")
	t.eq(fv.bodies.size(), 1, "화물칸이 비었으니 배 위의 몸이 없다 — 적 하나만 남는다")
	_drop(t, fv)


# -- items 2 / 3 / 5 / 4: the melee contact, and the lion's telegraph -------------------------------

## One melee soldier and the lion on adjacent tiles, which is the worst pairing in combat-juice's
## overlap table: gap 40 - 14 - 22 = 4 px, so the lion's 12.1 px push is the one the bite cap has to
## cut down to 10.0 and the overlap lands exactly on `LUNGE_BITE_PX`.
##
## The sim and the view are stepped by the SAME delta here. The telegraph is drawn from
## `enemy_windup`, which counts down inside the sim, so a view clock running at a different rate
## would make the ring and the blow name two different moments.
func _contact(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [_spawn(Rules.LION, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var fv := _view_of(t, b, army)

	var s_px := Look.tile_point_px(Vector2(12, 5))
	var e_px := Look.tile_point_px(Vector2(13, 5))
	var r_s := Look.body_radius_of(Rules.CELL_MELEE)
	var r_l := Look.body_radius_of(Rules.LION)
	var facing := Vector2.RIGHT
	var gap := maxf(0.0, s_px.distance_to(e_px) - r_s - r_l)
	var push_s := minf(Look.LUNGE_PUSH_RATIO * r_s, gap + Look.LUNGE_BITE_PX)
	var contact := s_px + facing * (r_s + push_s)

	# --- the frame of the blow --------------------------------------------------------------------
	# One SUB-STEP, not 0.001: `step` runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps, so a smaller `dt`
	# runs no phases at all and this frame would carry no blow, no telegraph and no target line.
	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(fv.bodies.size(), 2, "적 하나와 병사 하나, 몸 둘을 그렸다")
	var lion := _at(fv.bodies, 0)
	var cell := _at(fv.bodies, 1)
	t.eq(fv.sparks.size(), 0, "타격 프레임에는 파편이 아직 0개다 (런지 반값만큼 늦게 튄다)")

	# item 3① — the white, with its own floor: the body that was NOT hit is exactly its own colour.
	t.eq(_col(lion, "colour"), Look.body_colour_of(true).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH),
			"맞은 몸에 흰색이 HIT_FLASH_STRENGTH 만큼 섞였다")
	t.eq(_col(cell, "colour"), Look.body_colour_of(false), "안 맞은 몸은 자기 색 그대로다")

	# item 3② — the halo, and the layer that makes it exist at all
	t.eq(fv.halos.size(), 1, "맞은 몸 하나에 헤일로 하나")
	var halo := _at(fv.halos, 0)
	t.ok(absf(_num(halo, "radius") - r_l * Look.HIT_HALO_MUL) <= NEAR_PX,
			"헤일로 반지름이 그 몸 반지름 × HIT_HALO_MUL 이다 (%.2f px)" % _num(halo, "radius"))
	t.eq(_col(halo, "colour"), Look.COL_HIT_HALO, "헤일로 색이 COL_HIT_HALO 다")
	t.ok(_before(halo, lion),
			"헤일로가 그 몸보다 먼저 그려진다 — 뒤에 그리면 채운 원이 외곽선을 통째로 덮는다")
	t.eq(_pt(halo, "centre"), _pt(lion, "centre"), "헤일로가 몸과 같은 자리에 깔린다 (움찔 오프셋까지 같이)")

	# item 3③ — the flinch, at full amplitude on the frame the blow is felt
	var knock: Vector2 = _pt(lion, "centre") - e_px
	t.ok(absf(knock.length() - Look.HIT_KNOCK_PX) <= NEAR_PX,
			"맞은 몸이 HIT_KNOCK_PX 만큼 밀렸다 (%.2f px)" % knock.length())
	t.ok(knock.normalized().dot(facing) > 0.99, "밀린 방향이 때린 쪽의 반대다")
	# item 2① — the lunge is exactly 0 at the START of its life, not just at the end
	t.ok(s_px.distance_to(_pt(cell, "centre")) <= NEAR_PX, "때린 몸은 타격 프레임에 아직 안 나갔다 (런지 양끝은 0)")

	# item 5 — the telegraph, drawn from sim STATE and not from an event
	t.eq(fv.rings.size(), 1, "예고 링 하나가 떠 있다")
	var tele := _at(fv.rings, 0)
	t.eq(_pt(tele, "centre"), s_px, "예고 링의 중심이 겨눠진 병사다")
	t.eq(_col(tele, "colour"), Look.COL_AREA_RING, "예고 링 색이 COL_AREA_RING 이다")
	var tele_start := Rules.area_of(Rules.LION) * Look.TILE_PX * Look.AREA_RING_START_RATIO
	t.ok(absf(_num(tele, "radius") - tele_start) <= 0.2,
			"선언된 순간의 반지름이 최종 반경의 AREA_RING_START_RATIO 다 (%.1f px)" % _num(tele, "radius"))
	t.ok(_before(tele, lion), "바닥 링이 모든 몸보다 먼저 그려진다")

	# item 6 — the enemy's line, under every body
	t.eq(fv.lines.size(), 1, "적이 노리는 선 하나를 그렸다")
	var tline := _at(fv.lines, 0)
	t.ok(_before(tline, lion),
			"타겟 선이 몸보다 먼저 그려진다 (몸을 가로지르면 구름이 된다)")

	# --- the peak of the lunge, which is also the shard's first frame ------------------------------
	# `LUNGE_SEC * 0.5` is both the peak and the delay, deliberately — combat-juice refuses a separate
	# delay constant because the instant is the same instant.
	await _frame(t, b, fv, Look.LUNGE_SEC * 0.5, Look.LUNGE_SEC * 0.5)
	var peak_cell := _at(fv.bodies, 1)
	var lunge: Vector2 = _pt(peak_cell, "centre") - s_px
	t.ok(lunge.length() >= push_s * 0.9,
			"반값 프레임에 때린 몸이 %.2f px 나갔다 (밀림 %.2f px 의 90%% 이상)" % [lunge.length(), push_s])
	t.ok(lunge.normalized().dot(facing) > 0.99, "나간 방향이 _facing_of 와 같다")

	t.eq(fv.sparks.size(), 1, "반값 프레임에 파편 묶음이 정확히 하나 떴다")
	var first_spark := _at(fv.sparks, 0)
	var first_pts := _pts(first_spark)
	t.eq(first_pts.size(), Look.SPARK_COUNT * 2, "점이 SPARK_COUNT × 2 = %d개다" % (Look.SPARK_COUNT * 2))
	t.eq(_col(first_spark, "colour"), Look.COL_SPARK, "파편 색이 COL_SPARK 다 (진영과 무관한 한 색)")
	t.ok(absf(_num(first_spark, "width") - Look.SPARK_WIDTH_PX) <= NEAR_PX,
			"파편 굵기가 SPARK_WIDTH_PX 다 — 잎이 인자로 받아서 잴 수 있다")
	# The identity combat-juice pins: at the half-lunge frame the contact point IS the drawn body
	# edge. Both sides of it are captured — the body centre off `_paint_body`, the points off
	# `_paint_spark` — so a shard rooted at the body centre, or at the un-pushed edge, moves it by
	# 14 px or 7.7 px and this bites.
	var root := _centroid(first_pts)
	t.ok(first_pts.size() > 0 and root.distance_to(contact) <= 0.2,
			"파편의 뿌리가 접촉점이다 (%.3f px 차)" % root.distance_to(contact))
	# The same identity read entirely off captured arguments: the shard's root is the DRAWN body's
	# edge. Frozen at the un-pushed edge instead it misses by the whole push, and rooted at the body
	# centre it misses by the radius.
	var from_drawn := _pt(peak_cell, "centre") + facing * r_s
	t.ok(first_pts.size() > 0 and root.distance_to(from_drawn) <= 0.2,
			"그리고 그 뿌리는 그린 몸 중심 + facing × 자기 반지름과 같다 (%.3f px 차) — 두 훅의 인자만으로 서는 항등식"
			% root.distance_to(from_drawn))
	t.ok(first_pts.size() > 0 and root.distance_to(_pt(peak_cell, "centre")) >= r_s - 0.2,
			"그 뿌리는 몸 중심에서 자기 반지름만큼 떨어져 있다 — 몸 한복판이 아니다")

	# item 2 — the offset rides the WHOLE body: bar and beak move with it
	t.eq(fv.hps.size(), 2, "몸마다 HP 막대가 하나씩")
	var bar := _rect(_at(fv.hps, 1), "back")
	var bar_shift: Vector2 = bar.position - Look.hp_bar_origin_px(s_px, Rules.CELL_MELEE)
	t.ok(bar_shift.distance_to(lunge) <= NEAR_PX,
			"HP 막대가 몸과 같은 오프셋으로 따라 움직였다 — 안 그러면 몸만 튀어나간다")

	# --- the shards actually move ------------------------------------------------------------------
	await _frame(t, b, fv, 0.02, 0.02)
	var mid_reach := _max_dist(_pts(_at(fv.sparks, 0)), contact)

	await _frame(t, b, fv, 0.09, 0.09)
	t.eq(fv.sparks.size(), 1, "파편은 아직 살아 있다")
	var late_pts := _pts(_at(fv.sparks, 0))
	var late_reach := _max_dist(late_pts, contact)
	t.ok(late_reach - mid_reach >= 2.0,
			"파편이 접촉점에서 %.1f px 더 뻗었다 (스냅 바닥 2.0px 이상) — 멈춘 그림 위의 움직임이 이 연출의 근거다"
			% (late_reach - mid_reach))
	t.ok(late_pts.size() > 0 and late_reach <= Look.SPARK_REACH_PX + NEAR_PX,
			"그래도 SPARK_REACH_PX 를 안 넘는다 (%.1f px)" % late_reach)
	var same := 0
	for i in late_pts.size():
		for j in range(i + 1, late_pts.size()):
			if late_pts[i].distance_to(late_pts[j]) <= 1e-4:
				same += 1
	t.eq(same, 0, "열두 점 중 겹치는 짝이 하나도 없다 — 빈 배열도 한 점도 아니다")

	# The fan opens along the TANGENT. The thresholds are built from the INNER end at this frame's own
	# progress, never from the tip: built from the tip, half the points pass a check they are not in.
	var progress := (Look.LUNGE_SEC * 0.5 + 0.02 + 0.09 - Look.LUNGE_SEC * 0.5) / Look.SPARK_SEC
	var outer := Look.SPARK_REACH_PX * progress
	var inner := maxf(0.0, outer - Look.SPARK_LEN_PX)
	var spread := deg_to_rad(Look.SPARK_SPREAD_DEG)
	var tangent := Vector2(-facing.y, facing.x)
	var off_axis := 0
	var too_short := 0
	var plus := 0
	var minus := 0
	for k in late_pts.size():
		var v: Vector2 = late_pts[k] - contact
		if absf(v.dot(facing)) > outer * sin(spread) + NEAR_PX:
			off_axis += 1
		if absf(v.dot(tangent)) < inner * cos(spread) - NEAR_PX:
			too_short += 1
		if v.dot(tangent) > 0.0:
			plus += 1
		else:
			minus += 1
	# The size guard is on both: with no points at all every "not one point broke it" loop counts zero.
	t.ok(late_pts.size() == Look.SPARK_COUNT * 2 and off_axis == 0,
			"모든 점이 facing 축에서 %.2f px 안쪽이다 — 부채가 접선으로 열렸다" % (outer * sin(spread)))
	t.ok(late_pts.size() == Look.SPARK_COUNT * 2 and too_short == 0,
			"모든 점이 접선 축으로 %.2f px 이상 나가 있다 (안쪽 끝 기준)" % (inner * cos(spread)))
	t.eq(plus, Look.SPARK_COUNT, "접선 한쪽에 %d점" % Look.SPARK_COUNT)
	t.eq(minus, Look.SPARK_COUNT, "반대쪽에도 %d점 — 부채가 좌우 대칭이다" % Look.SPARK_COUNT)

	# item 2① — and the lunge is back to exactly 0 at the end of its life
	t.ok(s_px.distance_to(_pt(_at(fv.bodies, 1), "centre")) <= NEAR_PX,
			"런지가 끝난 몸은 정확히 제자리로 돌아왔다 — 옮겨진 채 남지 않는다")

	# --- the shard dies -----------------------------------------------------------------------------
	await _frame(t, b, fv, 0.03, 0.03)
	t.eq(fv.sparks.size(), 0, "수명(딜레이 + SPARK_SEC)이 지나면 파편 호출이 0이다")

	# --- the telegraph fills, then the blow lands ---------------------------------------------------
	var before_hp := army.hp[0]
	var last_tele := 0.0
	var landed := false
	for _f in 40:
		await _frame(t, b, fv, 0.02, 0.02)
		if army.hp[0] < before_hp:
			landed = true
			break
		if fv.rings.size() > 0:
			last_tele = maxf(last_tele, _num(_at(fv.rings, 0), "radius"))
	t.ok(landed, "예고가 끝나고 사자의 일격이 떨어졌다")
	var full_area := Rules.area_of(Rules.LION) * Look.TILE_PX
	t.ok(last_tele >= full_area * 0.9,
			"터지기 직전 예고 링이 실제 광역 반경의 90%% 까지 자랐다 (%.1f / %.1f px)" % [last_tele, full_area])
	t.ok(last_tele <= full_area + NEAR_PX, "그리고 실제 광역 반경을 안 넘는다 — 그린 원과 맞는 칸이 같다")

	# item 5 — the area ring, born at the blow
	t.eq(fv.rings.size(), 1, "일격이 떨어진 프레임에 광역 링 하나 (예고는 지워졌다)")
	var area_ring := _at(fv.rings, 0)
	t.eq(_pt(area_ring, "centre"), s_px, "광역 링의 중심이 표적의 자리다")
	t.ok(absf(_num(area_ring, "radius") - full_area * Look.AREA_RING_START_RATIO) <= 0.2,
			"광역 링이 AREA_RING_START_RATIO 에서 시작한다 (%.1f px)" % _num(area_ring, "radius"))
	t.ok(absf(_num(area_ring, "width") - Look.AREA_RING_WIDTH_PX) <= NEAR_PX, "광역 링 굵기가 look.gd 값이다")
	t.ok(_before(area_ring, _at(fv.bodies, 0)),
			"광역 링은 몸 밑이다 — 바닥에 난 자국이다")

	# --- the lion's own lunge, and the bite cap -----------------------------------------------------
	await _frame(t, b, fv, Look.LUNGE_SEC * 0.5, Look.LUNGE_SEC * 0.5)
	var lion_c := _pt(_at(fv.bodies, 0), "centre")
	var cell_c := _pt(_at(fv.bodies, 1), "centre")
	var overlap := r_l + r_s - lion_c.distance_to(cell_c)
	t.ok(overlap <= Look.LUNGE_BITE_PX + NEAR_PX,
			"사자가 40px 옆의 근접셀을 때린 반값 프레임의 겹침이 %.2f px — LUNGE_BITE_PX 이하다" % overlap)
	t.ok(overlap >= Look.LUNGE_BITE_PX * 0.5,
			"그런데 실제로 겹치기는 한다 (%.2f px) — 삼키지 않고 부딪힌다" % overlap)
	var grown_area := 0.0
	for raw_ring in fv.rings:
		var ring: Dictionary = raw_ring
		grown_area = maxf(grown_area, float(ring["radius"]))
	t.ok(grown_area > full_area * Look.AREA_RING_START_RATIO + 1.0,
			"광역 링이 그 사이 자랐다 (%.1f px) — 상수로 박혀 있지 않다" % grown_area)

	# --- the death burst, and the view clock that keeps running with the sim stopped ----------------
	b.enemy_hp[0] = 0.0
	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(b.outcome(), Battle.Outcome.WON, "마지막 적이 죽어 섬이 끝났다 — 여기서부터 sim 은 멈춘다")
	t.eq(fv.bodies.size(), 1, "죽은 몸은 그 프레임부터 안 그려진다")
	var burst := _rings_of(fv, Look.body_colour_of(true))
	t.eq(burst.size(), 1, "죽은 자리에 파열 링 하나")
	var burst0 := _at(burst, 0)
	t.ok(absf(float(burst0["radius"]) - r_l) <= 0.2,
			"파열은 그 몸의 반지름에서 시작한다 (%.1f px)" % float(burst0["radius"]))
	t.ok(_before(_at(fv.bodies, 0), burst0), "파열 링은 모든 몸 위다 — 밑에 그리면 큰 몸에 묻힌다")

	var frozen := b.elapsed
	await _frame(t, b, fv, 0.05, 0.05)
	await _frame(t, b, fv, 0.05, 0.05)
	await _frame(t, b, fv, 0.05, 0.05)
	t.eq(b.elapsed, frozen, "그 사이 sim 시계는 한 번도 안 움직였다 (outcome 이 끝났다)")
	var grown := float(_rings_of(fv, Look.body_colour_of(true))[0]["radius"])
	t.ok(grown > float(burst0["radius"]) + 1.0,
			"그래도 파열은 계속 자랐다 (%.1f → %.1f px) — 뷰가 자기 시계를 갖는 이유가 이 줄이다"
			% [float(burst0["radius"]), grown])

	await _frame(t, b, fv, 0.05, 0.15)
	var big := _rings_of(fv, Look.body_colour_of(true))
	t.eq(big.size(), 1, "파열은 BURST_SEC 안에는 아직 살아 있다")
	t.ok(_num(_at(big, 0), "radius") >= r_l * Look.BURST_GROWTH * 0.9,
			"끝 무렵 반지름이 시작 × BURST_GROWTH 의 90%% 이상이다 (%.1f / %.1f px)"
			% [_num(_at(big, 0), "radius"), r_l * Look.BURST_GROWTH])

	# --- setup empties both drawers -----------------------------------------------------------------
	# Without it island 2 opens with island 1's explosions still in flight over bodies that no longer
	# exist, and every id inside them means a different unit now.
	t.ok(fv._fx.size() > 0, "다시 열기 전 서랍에 이펙트가 남아 있다 (%d개)" % fv._fx.size())
	fv.setup(b, army, _open())
	t.eq(fv._fx.size(), 0, "setup 이 스쳐 가는 서랍을 비웠다")
	t.eq(fv._body.size(), 0, "setup 이 몸 서랍도 비웠다")
	# `position` now also carries the camera's own pan (`boat-and-landing`), so only the SHAKE
	# component of it is asserted here — `_shake_component` subtracts the camera's own contribution.
	t.eq(_shake_component(fv), Vector2.ZERO, "setup 이 흔들림 오프셋도 0으로 돌렸다")
	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(fv.rings.size(), 0, "다시 연 첫 프레임에 링 호출이 0이다")
	t.eq(fv.halos.size(), 0, "헤일로 호출도 0이다")
	t.eq(fv.sparks.size(), 0, "파편 호출도 0이다")
	_drop(t, fv)


# -- item 1: the tracer ----------------------------------------------------------------------------

## A ranged cell four tiles from a bison. Both endpoints are frozen on the firing frame, so the
## bullet does not bend onto the next enemy when its target dies — which is what re-reading
## `soldier_target` every frame produces, and the target dies constantly.
func _tracer(t) -> void:
	var army := _army_of([Rules.CELL_RANGED])
	var b := _battle_of(_open(), army, [
		_spawn(Rules.BISON, 12, 5),
		_spawn(Rules.BISON, 12, 8),
	], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	var fv := _view_of(t, b, army)
	var muzzle := Look.tile_point_px(Vector2(8, 5))
	var target := Look.tile_point_px(Vector2(12, 5))

	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(b.soldier_target[0], 0, "원거리 병사가 0번 적을 쐈다")
	t.eq(fv.shots.size(), 1, "예광선 하나가 떴다")
	t.eq(_col(_at(fv.shots, 0), "colour"), Look.COL_SHOT, "예광선 색이 COL_SHOT 이다")
	t.ok(absf(_num(_at(fv.shots, 0), "width") - Look.SHOT_WIDTH_PX) <= NEAR_PX, "예광선 굵기가 look.gd 값이다")

	await _frame(t, b, fv, TICK_ONE, 0.02)
	var early := _at(fv.shots, 0)
	var early_from := _pt(early, "from")
	var early_to := _pt(early, "to")
	t.ok(absf(early_from.distance_to(early_to) - Look.SHOT_LEN_PX) <= NEAR_PX,
			"토막 길이가 SHOT_LEN_PX 다 (%.2f px) — 선 전체를 그리면 그것은 6번이 된다"
			% early_from.distance_to(early_to))
	t.ok(_before(_at(fv.bodies, 0), early), "예광선은 몸 위를 지난다")

	await _frame(t, b, fv, TICK_ONE, 0.04)
	var later := _at(fv.shots, 0)
	var later_to := _pt(later, "to")
	t.ok(later_to.distance_to(early_to) >= 2.0,
			"두 프레임의 예광선이 %.1f px 옮겨졌다 — 진행도를 실제로 쓴다" % later_to.distance_to(early_to))
	t.ok(muzzle.distance_to(later_to) > muzzle.distance_to(early_to), "그리고 표적 쪽으로 나아간다")

	# the target dies and the shooter re-targets — the bullet must not follow
	b.enemy_hp[0] = 0.0
	await _frame(t, b, fv, TICK_ONE, 0.02)
	t.eq(b.enemy_alive[0], 0, "표적이 죽었다")
	await _frame(t, b, fv, TICK_ONE, 0.01)
	t.eq(b.soldier_target[0], 1, "병사는 다음 적으로 갈아탔다 — 비교할 대상이 실제로 생겼다")
	t.eq(fv.shots.size(), 1, "예광선은 아직 날고 있다")
	var flight := _pt(_at(fv.shots, 0), "to")
	var other := Look.tile_point_px(Vector2(12, 8))
	t.ok(flight.distance_to(target) <= flight.distance_to(other),
			"그래도 도착점은 처음 겨눈 그 자리다 — 발사 프레임에 얼렸다")

	# item 4 — the burst that death left, above every body
	var burst := _rings_of(fv, Look.body_colour_of(true))
	t.eq(burst.size(), 1, "죽은 적 자리에 파열 링 하나")
	t.ok(_before(_at(fv.bodies, fv.bodies.size() - 1), _at(burst, 0)),
			"파열은 마지막 몸보다도 뒤에 그려진다")
	var was := _num(_at(burst, 0), "radius")

	await _frame(t, b, fv, TICK_ONE, 0.09)
	t.eq(fv.shots.size(), 0, "SHOT_SEC 이 지나면 예광선 호출이 0이다")
	t.ok(_num(_at(_rings_of(fv, Look.body_colour_of(true)), 0), "radius") > was + 1.0,
			"그 사이 파열은 계속 커졌다")
	_drop(t, fv)


## The tracer lies about time: the sim landed the damage on the firing frame, so the white and the
## flinch are held back by exactly `SHOT_SEC`. Both halves are measured — off before it arrives, on
## after — because "it never flashes at all" passes the first one on its own.
func _the_reaction_waits_for_the_bullet(t) -> void:
	var army := _army_of([Rules.CELL_RANGED])
	var b := _battle_of(_open(), army, [_spawn(Rules.BISON, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	var fv := _view_of(t, b, army)
	var enemy_px := Look.tile_point_px(Vector2(12, 5))

	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.BISON) - Rules.damage_of(Rules.CELL_RANGED),
			"sim 은 발사 프레임에 이미 피해를 넣었다")
	await _frame(t, b, fv, TICK_ONE, 0.05)
	t.eq(_col(_at(fv.bodies, 0), "colour"), Look.body_colour_of(true),
			"총알이 도착하기 전에는 표적 색이 그대로다 — 지연이 없으면 여기서 이미 하얗다")
	t.eq(fv.halos.size(), 0, "헤일로도 아직 안 켜졌다")
	# ⚠ **Against the sim's own current position, not the fixture's literal.** The bison detects the
	# soldier and walks, and one sub-step is 2.5/60 of a tile — so a literal anchor would measure the
	# walk instead of the flinch. The flinch IS the view-side offset on top of `enemy_pos`, so zero
	# distance between the drawn centre and the sim point is exactly "no flinch yet", and the mutation
	# this row exists for (dropping the `SHOT_SEC` delay) opens it by `HIT_KNOCK_PX`.
	t.eq(_pt(_at(fv.bodies, 0), "centre"), Look.tile_point_px(b.enemy_pos[0]), "움찔도 아직 없다")

	await _frame(t, b, fv, TICK_ONE, 0.06)
	t.eq(_col(_at(fv.bodies, 0), "colour"), Look.body_colour_of(true).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH),
			"SHOT_SEC 이 지나자 표적이 번쩍인다 (바닥)")
	t.eq(fv.halos.size(), 1, "그때 헤일로도 같이 켜진다")

	await _frame(t, b, fv, TICK_ONE, 0.04)
	var flinch := _pt(_at(fv.bodies, 0), "centre") - Look.tile_point_px(b.enemy_pos[0])
	t.ok(flinch.length() > 0.5, "움찔도 그때부터 실린다 (%.2f px)" % flinch.length())
	t.ok(flinch.length() <= Look.HIT_KNOCK_PX + NEAR_PX, "그리고 HIT_KNOCK_PX 를 안 넘는다")
	_drop(t, fv)


# -- the layer the shard lives on -------------------------------------------------------------------

## Sparks and a burst in the same frame, which is the only way to pin layer 9 from both sides: above
## every body, below the death burst. Also the "hit twice, age reset not stacked" rule, which is
## structural (the drawer is keyed by body) but silently undone by a list.
func _spark_over_body_under_burst(t) -> void:
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [
		_spawn(Rules.BISON, 13, 5),
		_spawn(Rules.BISON, 12, 9),
	], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	_ashore(b, 1, Vector2(14, 5))
	b.enemy_hp[1] = 0.0
	var fv := _view_of(t, b, army)

	await _frame(t, b, fv, TICK_ONE, 0.001)
	t.eq(b.enemy_alive[1], 0, "구석의 적 하나가 그 프레임에 죽었다")
	# Both soldiers are within reach of the same bison, so it is hit twice in one frame.
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.BISON) - 2.0 * Rules.damage_of(Rules.CELL_MELEE),
			"남은 적이 한 프레임에 두 번 맞았다")
	t.ok(fv._body.has("e0"), "그 몸의 서랍 항목이 있다")
	var entry: Dictionary = fv._body["e0"]
	t.ok(absf(float(entry["flash"]) - Look.HIT_FLASH_SEC) <= 1e-6,
			"두 번 맞아도 번쩍임은 하나이고 나이만 0으로 돌아간다 (%.4f초) — 쌓으면 헤일로 알파가 곱해진다"
			% float(entry["flash"]))
	# Counted at that body's own centre: the bison hit one of the two soldiers back, so the frame
	# holds a second halo that has nothing to do with the stacking rule.
	var on_bison := 0
	for raw in fv.halos:
		var h: Dictionary = raw
		if _pt(h, "centre").distance_to(_pt(_at(fv.bodies, 0), "centre")) <= NEAR_PX:
			on_bison += 1
	t.eq(on_bison, 1, "그래서 그 몸 위의 헤일로도 하나뿐이다")

	await _frame(t, b, fv, TICK_ONE, Look.LUNGE_SEC * 0.5)
	t.ok(fv.sparks.size() >= 1, "파편이 떠 있다 (%d묶음)" % fv.sparks.size())
	var burst := _rings_of(fv, Look.body_colour_of(true))
	t.eq(burst.size(), 1, "파열 링도 같은 프레임에 떠 있다")
	var last_body := 0
	for raw in fv.bodies:
		last_body = maxi(last_body, int(raw["seq"]))
	var bad_low := 0
	var bad_high := 0
	for raw in fv.sparks:
		var sp: Dictionary = raw
		if int(sp["seq"]) < last_body:
			bad_low += 1
		if int(sp["seq"]) > _num(_at(burst, 0), "seq"):
			bad_high += 1
	t.eq(bad_low, 0, "모든 파편이 모든 몸보다 뒤에 그려진다 — 밑에 그리면 두 외곽선에 다시 깔린다")
	t.eq(bad_high, 0, "그리고 파열 링보다는 앞이다 (층 9는 몸과 10 사이다)")
	_drop(t, fv)


# -- item 6: target lines ---------------------------------------------------------------------------

## Six enemies draw six lines; `TARGET_LINE_MAX_COUNT + 1` draw none.
##
## ⚠ **RE-MEASURED when `plan-then-watch` stage 4 raised the counts to 8 · 12 · 14.** At the old
## `TARGET_LINE_MAX_COUNT` 8 the guard bit for the first time ever — islands 2 and 3 would have drawn
## ZERO intent lines until 4 and 6 enemies were dead, which is the opening of the fight and exactly
## the phase where the hand cannot move and reading is the whole activity. The constant went to 14,
## **the largest island's count**, so the row below is no longer synthetic on its lower end: 14 is a
## real island's opening and it has to draw all fourteen. The upper end (15) still is synthetic, and
## says so.
func _target_lines(t) -> void:
	var six := await _lines_with(t, [
		Vector2(9, 6), Vector2(15, 6), Vector2(12, 3), Vector2(12, 9), Vector2(9, 3), Vector2(15, 9),
	])
	t.eq(int(six["lines"]), 6, "적 여섯이면 선 여섯 — 적 쪽만 그린다 (병사 쪽은 안 그린다)")
	t.ok(bool(six["ends_ok"]), "선의 두 끝이 그 적과 그 적이 노리는 병사의 자리다")
	t.ok(bool(six["under_bodies"]), "선이 전부 몸보다 먼저 그려진다")
	t.eq(six["colour"], Look.COL_TARGET_LINE, "선 색이 COL_TARGET_LINE 이다 (알파 0.12)")

	# Fifteen tiles, every one of them inside BISON detect 6.0 of the soldier at (12, 6), so every
	# enemy really acquires a target and a missing line is the guard and not an absent aim.
	var spots := [
		Vector2(9, 6), Vector2(15, 6), Vector2(12, 3), Vector2(12, 9), Vector2(9, 3), Vector2(15, 9),
		Vector2(9, 9), Vector2(15, 3), Vector2(12, 10), Vector2(8, 6), Vector2(16, 6),
		Vector2(10, 4), Vector2(14, 8), Vector2(10, 8), Vector2(14, 4),
	]
	t.eq(spots.size(), Look.TARGET_LINE_MAX_COUNT + 1,
		"자가 점검 — 상한보다 딱 하나 많은 자리를 준비했다 (%d개)" % spots.size())
	# ⚠ **The floor, and it is the half the raise was for.** The largest real island holds
	# `TARGET_LINE_MAX_COUNT` enemies, so the fight OPENS at exactly the guard's limit and every line
	# has to be on. At the old 8 this arm drew zero.
	var at_cap := await _lines_with(t, spots.slice(0, Look.TARGET_LINE_MAX_COUNT))
	t.eq(int(at_cap["alive"]), Look.TARGET_LINE_MAX_COUNT,
		"가장 큰 섬만큼 적을 세웠다 (%d마리)" % Look.TARGET_LINE_MAX_COUNT)
	t.eq(int(at_cap["lines"]), Look.TARGET_LINE_MAX_COUNT,
		"상한과 같은 수까지는 전부 그린다 — 가장 큰 섬은 첫 프레임부터 의도선이 다 켜져 있다 (바닥)")

	# The ceiling. One over the limit is synthetic — no island holds this many — and it says so.
	var over := await _lines_with(t, spots)
	t.eq(int(over["alive"]), Look.TARGET_LINE_MAX_COUNT + 1,
		"합성 전투 — 상한보다 하나 많게 만들었다 (%d마리)" % (Look.TARGET_LINE_MAX_COUNT + 1))
	t.eq(int(over["lines"]), 0, "TARGET_LINE_MAX_COUNT 를 넘으면 하나도 안 그린다 (천장)")


func _lines_with(t, spots: Array) -> Dictionary:
	var army := _army_of([Rules.CELL_MELEE])
	var spawns := []
	for raw in spots:
		var p: Vector2 = raw
		spawns.append(_spawn(Rules.BISON, int(p.x), int(p.y)))
	var b := _battle_of(_open(), army, spawns, 999.0)
	_ashore(b, 0, Vector2(12, 6))
	var fv := _view_of(t, b, army)
	await _frame(t, b, fv, TICK_ONE, 0.001)

	var ends_ok := fv.lines.size() > 0
	var under := true
	var first_body := 1 << 30
	for raw in fv.bodies:
		first_body = mini(first_body, int(raw["seq"]))
	var seen := 0
	for e in b.enemy_alive.size():
		var aim := int(b.enemy_target[e])
		if b.enemy_alive[e] == 0 or aim < 0:
			continue
		if seen >= fv.lines.size():
			break
		var line: Dictionary = fv.lines[seen]
		if Vector2(line["from"]) != Look.tile_point_px(b.enemy_pos[e]):
			ends_ok = false
		if Vector2(line["to"]) != Look.tile_point_px(b.soldier_pos[aim]):
			ends_ok = false
		if int(line["seq"]) > first_body:
			under = false
		seen += 1
	var out := {
		"lines": fv.lines.size(),
		"alive": b.enemies_left(),
		"ends_ok": ends_ok,
		"under_bodies": under,
		"colour": _col(_at(fv.lines, 0), "colour") if fv.lines.size() > 0 else Look.COL_TARGET_LINE,
	}
	_drop(t, fv)
	return out


# -- item 7: the landing ring ------------------------------------------------------------------------

func _landing_rings(t) -> void:
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(Rules.LION, 20, 9)], 999.0)
	var fv := _view_of(t, b, army)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	# Two boats aimed at ONE tile: they arrive on the same sub-step, and 「the first dropped stands on
	# the target tile」 is what puts the second on the neighbour — two rings, two places.
	b.send(0, landing)
	b.send(1, landing)
	b.commit()
	var sailed := 0
	while sailed < 80 and b.ashore_ids().size() < 2:
		sailed += 1
		b.begin_frame()
		b.step(0.1)
	t.ok(b.ashore_ids().size() == 2, "%d 프레임 만에 둘 다 내렸다" % sailed)

	# The view drains that frame's events without stepping the sim again, so what is drawn is the
	# landing frame and nothing else.
	fv._process(0.001)
	await t.pump_frames(2)
	var born := _rings_of(fv, Look.COL_LAND_RING)
	t.eq(born.size(), 2, "내린 병사마다 링 하나")
	var wide := 0
	for raw in born:
		if float(raw["radius"]) > 1.0:
			wide += 1
	t.eq(wide, 0, "첫 프레임 반지름은 0 에 가깝다 (링이 발밑에서 퍼져 나간다)")
	var first_body := 1 << 30
	for raw in fv.bodies:
		first_body = mini(first_body, int(raw["seq"]))
	t.ok(_num(_at(born, 0), "seq") >= 0.0 and _num(_at(born, 0), "seq") < float(first_body),
			"상륙 링도 몸 밑이다")
	t.ok(absf(_num(_at(born, 0), "width") - Look.LAND_RING_WIDTH_PX) <= NEAR_PX, "상륙 링 굵기가 look.gd 값이다")

	await _frame(t, b, fv, TICK_ONE, Look.LAND_RING_SEC * 0.9)
	var grown := _rings_of(fv, Look.COL_LAND_RING)
	t.eq(grown.size(), 2, "링 둘이 아직 살아 있다")
	t.ok(_num(_at(grown, 0), "radius") >= Look.LAND_RING_R_PX * 0.85,
			"끝 무렵 반지름이 LAND_RING_R_PX 의 85%% 이상이다 (%.1f / %.1f px)"
			% [_num(_at(grown, 0), "radius"), Look.LAND_RING_R_PX])
	t.ok(grown.size() > 0 and _num(_at(grown, 0), "radius") <= Look.LAND_RING_R_PX + NEAR_PX,
			"그리고 타일 반 칸을 안 넘는다 — 직교 인접한 두 링이 딱 맞닿는 값이다")

	await _frame(t, b, fv, TICK_ONE, 0.09)
	t.eq(_rings_of(fv, Look.COL_LAND_RING).size(), 0, "LAND_RING_SEC 이 지나면 링 호출이 0이다")
	_drop(t, fv)


# -- item 11: the shake ------------------------------------------------------------------------------

## Amplitude has to track damage or half of this effect is dead, so two different blows are measured
## and compared. The peak is sampled across the whole window because the offset is two sines and one
## frame says nothing about how big it ever got.
func _shake(t) -> void:
	var light := await _shake_peak(t, Rules.CELL_RANGED, Vector2(8, 5), Rules.BISON, Vector2(12, 5))
	var heavy := await _shake_peak(t, Rules.CELL_MELEE, Vector2(12, 5), Rules.BISON, Vector2(13, 5))
	var light_dmg := Rules.damage_of(Rules.CELL_RANGED)
	var heavy_dmg := Rules.damage_of(Rules.BISON)

	t.ok(float(light["peak"]) >= light_dmg * Look.SHAKE_PER_DAMAGE_PX * 0.8,
			"피해 %.1f 의 흔들림 최대가 %.2f px 다 (dmg × SHAKE_PER_DAMAGE_PX 의 80%% 이상)"
			% [light_dmg, float(light["peak"])])
	t.ok(float(heavy["peak"]) >= heavy_dmg * Look.SHAKE_PER_DAMAGE_PX * 0.8,
			"피해 %.1f 의 흔들림 최대가 %.2f px 다" % [heavy_dmg, float(heavy["peak"])])
	t.ok(float(heavy["peak"]) > float(light["peak"]) + 0.5,
			"큰 피해가 더 크게 흔든다 (%.2f > %.2f px) — 비례하지 않으면 이 연출의 절반이 죽는다"
			% [float(heavy["peak"]), float(light["peak"])])
	t.ok(float(heavy["peak"]) <= Look.SHAKE_MAX_PX,
			"그래도 SHAKE_MAX_PX 를 안 넘는다 (%.2f px)" % float(heavy["peak"]))
	t.eq(light["rest"], Vector2.ZERO,
			"SHAKE_SEC 이 지나면 position 이 정확히 (0,0) 이다 — += 로 쌓으면 옛 게임처럼 9배로 자란다")
	t.eq(heavy["rest"], Vector2.ZERO, "큰 흔들림도 정확히 0으로 돌아온다")


func _shake_peak(t, stype: int, spot: Vector2, etype: int, espot: Vector2) -> Dictionary:
	var army := _army_of([stype])
	var b := _battle_of(_open(), army, [_spawn(etype, int(espot.x), int(espot.y))], 999.0)
	_ashore(b, 0, spot)
	var fv := _view_of(t, b, army)
	await _frame(t, b, fv, TICK_ONE, 0.001)
	var peak := 0.0
	for _f in 20:
		await _frame(t, b, fv, TICK_ONE, Look.SHAKE_SEC / 20.0)
		peak = maxf(peak, _shake_component(fv).length())
	await _frame(t, b, fv, TICK_ONE, 0.02)
	var out := {"peak": peak, "rest": _shake_component(fv)}
	_drop(t, fv)
	return out


## `position` composes `-cam_px * zoom + shake_offset()` now (`boat-and-landing`'s camera), so
## isolating the shake means subtracting the camera's own (non-shake) contribution back out.
func _shake_component(fv: FieldSpy) -> Vector2:
	return fv.position + fv.cam_px * fv.zoom


# -- item 12: the gait --------------------------------------------------------------------------------

## Phase turns on DISTANCE, so a body that does not move does not animate. Both halves: twenty frames
## of standing still change nothing, and one quarter-period step changes it by more than half the
## amplitude.
##
## ⚠ **A quarter period and not the half combat-juice's F table names.** Half a period advances the
## phase by exactly pi and `sin(pi)` is 0, so the correct implementation would come back to rest and
## the row would redden a build that is right. A quarter lands on the peak.
func _gait(t) -> void:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(), army, [_spawn(Rules.BISON, 20, 9)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var fv := _view_of(t, b, army)

	await _frame(t, b, fv, TICK_ONE, 0.001)
	var rest := _pt(_at(fv.bodies, 1), "squash")
	t.eq(rest, Vector2.ONE, "서 있는 몸의 스쿼시는 Vector2.ONE 이다")
	var moved_while_still := 0
	# ⚠ **Sim `dt` 0.0 for these twenty frames.** The soldier's target is a bison it can see, so any
	# simulated time at all makes it WALK — and then the squash changing would be correct rather than a
	# defect. 「안 움직인 채」 has to be literally true for this row to mean what it says, and only a
	# frozen sim gives that.
	for _f in 20:
		await _frame(t, b, fv, 0.0, 1.0 / 60.0)
		if _pt(_at(fv.bodies, 1), "squash") != rest:
			moved_while_still += 1
	t.eq(moved_while_still, 0, "안 움직인 채 20프레임을 돌려도 스쿼시가 안 변한다 — 위상이 시간이 아니라 거리로 돈다")

	_place(b, 0, Vector2(12 + Look.GAIT_PERIOD_TILES * 0.25, 5))
	await _frame(t, b, fv, 0.0, 1.0 / 60.0)
	var squash := _pt(_at(fv.bodies, 1), "squash")
	t.ok(absf(squash.x - 1.0) >= Look.GAIT_SQUASH * 0.5,
			"주기의 1/4 만큼 옮기자 스쿼시가 %.3f 로 변했다 (GAIT_SQUASH 의 절반 이상)" % squash.x)
	t.ok(squash.x != squash.y, "그리고 x 와 y 가 다르다 — 등방 맥박이 아니다")
	t.ok((squash.x - 1.0) * (squash.y - 1.0) < 0.0,
			"한 축이 눌리면 다른 축은 퍼진다 (%.3f / %.3f) — 진행 방향으로 눌린다" % [squash.x, squash.y])
	_drop(t, fv)


# -- the pure builder, and the arithmetic the shard stands on ------------------------------------------

## `_spark_points` is called with the REAL implementation, twice, because the captured array alone
## cannot say whether `progress` is read or ignored — a builder that returned its final shape on every
## frame would still hand out twelve distinct points in a symmetric fan.
func _spark_points_is_a_function_of_progress(t) -> void:
	var fv := FieldSpy.new()
	var facing := Vector2.RIGHT
	var centre := Vector2(400.0, 300.0)
	var early := fv._spark_points(centre, facing, 0.25)
	var late := fv._spark_points(centre, facing, 0.75)
	t.eq(early.size(), Look.SPARK_COUNT * 2, "0.25 에서도 점이 %d개다" % (Look.SPARK_COUNT * 2))
	t.ok(_max_dist(late, centre) > _max_dist(early, centre),
			"progress 0.25 → 0.75 에 최대 거리가 늘었다 (%.1f → %.1f px)"
			% [_max_dist(early, centre), _max_dist(late, centre)])
	t.ok(_min_dist(late, centre) > _min_dist(early, centre),
			"최소 거리도 같이 늘었다 (%.1f → %.1f px) — 파편이 통째로 전진한다"
			% [_min_dist(early, centre), _min_dist(late, centre)])

	# The literal thresholds of combat-juice's F table hold at full progress, where the inner end is
	# `SPARK_REACH_PX - SPARK_LEN_PX` — every margin in that table is built from the inner end.
	var full := fv._spark_points(centre, facing, 1.0)
	var spread := deg_to_rad(Look.SPARK_SPREAD_DEG)
	var tangent := Vector2(-facing.y, facing.x)
	var off := 0
	var short := 0
	for k in full.size():
		var v: Vector2 = full[k] - centre
		if absf(v.dot(facing)) > Look.SPARK_REACH_PX * sin(spread) + 1e-4:
			off += 1
		if absf(v.dot(tangent)) < (Look.SPARK_REACH_PX - Look.SPARK_LEN_PX) * cos(spread) - 1e-4:
			short += 1
	t.eq(off, 0, "끝까지 뻗어도 facing 축 변위가 %.2f px 안이다" % (Look.SPARK_REACH_PX * sin(spread)))
	t.eq(short, 0, "그리고 모든 점이 접선으로 %.2f px 이상 나가 있다"
			% ((Look.SPARK_REACH_PX - Look.SPARK_LEN_PX) * cos(spread)))
	fv.free()


## Four constants move together in the first inequality and two in the second. Tuning any one of them
## alone and staying green is exactly what these two lines exist to stop.
func _the_inequalities_the_spark_stands_on(t) -> void:
	var inner := Look.SPARK_REACH_PX - Look.SPARK_LEN_PX
	var spread := sin(deg_to_rad(Look.SPARK_SPREAD_DEG))
	var worst := 0.0
	var worst_label := ""
	for striker in [Rules.CELL_MELEE, Rules.BISON, Rules.LION]:
		var r_self := Look.body_radius_of(striker)
		for victim in Rules.TYPE_COUNT:
			var gap := maxf(0.0, Look.TILE_PX - r_self - Look.body_radius_of(victim))
			var push := minf(Look.LUNGE_PUSH_RATIO * r_self, gap + Look.LUNGE_BITE_PX)
			var contact_d := absf(Look.TILE_PX - (r_self + push))
			var need := 2.0 * maxf(r_self, contact_d) * spread
			if need > worst:
				worst = need
				worst_label = "%s → %s" % [Rules.name_of(striker), Rules.name_of(victim)]
	t.ok(inner >= worst,
			"부등식 1 — 안쪽 끝 %.1f px ≥ 최악 조합(%s)의 %.1f px: 모든 점이 두 중심에서 접촉점보다 멀다"
			% [inner, worst_label, worst])
	t.ok(Look.SPARK_REACH_PX / (Look.SPARK_SEC * 60.0) >= 2.0,
			"부등식 2 — 프레임당 전진 %.2f px 가 스냅 바닥 2.0px 위다"
			% (Look.SPARK_REACH_PX / (Look.SPARK_SEC * 60.0)))
	t.ok(Look.SPARK_SEC * 8.0 < Rules.period_of(Rules.CELL_MELEE),
			"한 몸 둘레의 듀티 8 × %.3f 초 < 최소 근접 주기 %.1f 초 — 몸 둘레에 빈 순간이 남는다"
			% [Look.SPARK_SEC, Rules.period_of(Rules.CELL_MELEE)])

	# The shard's whole case for existing is that it reads on top of the filled halo.
	t.ok(Look.COL_HIT_HALO.a <= 0.4, "헤일로 알파가 0.4 이하다 (%.2f)" % Look.COL_HIT_HALO.a)
	var over := Look.COL_LAND.lerp(Look.COL_HIT_HALO, Look.COL_HIT_HALO.a)
	var contrast := absf(_luma(Look.COL_SPARK) - _luma(over))
	t.ok(contrast >= 0.25,
			"COL_SPARK 와 (헤일로 ⊕ 바닥)의 밝기 차가 %.2f 다 (Rec.709, 0.25 이상)" % contrast)


## `FX_GAIN` is a `const` Array, so a net cannot set a slot to 0 and no effect can be switched off
## from here — see this file's header. What IS reachable is the off-by-one, and it is the quietest
## possible failure: the round stays green and the wrong effect is the one that turns off.
func _fx_gain_is_indexed_by_item_number(t) -> void:
	t.eq(Look.FX_GAIN.size(), 12, "FX_GAIN 이 12칸이다 (연출 번호 1~12)")
	t.ok(absf(Look.fx_gain_of(1) - float(Look.FX_GAIN[0])) <= 1e-9,
			"fx_gain_of(1) 이 0번 칸을 읽는다 — 항목 번호와 배열 인덱스의 어긋남이 이 함수 하나에만 산다")
	t.ok(absf(Look.fx_gain_of(12) - float(Look.FX_GAIN[11])) <= 1e-9, "fx_gain_of(12) 가 11번 칸을 읽는다")
	var off := 0
	for n in range(1, 13):
		if not (Look.fx_gain_of(n) >= 0.0 and Look.fx_gain_of(n) <= 1.0):
			off += 1
	t.eq(off, 0, "열두 칸이 전부 0~1 안이다 — 위의 진폭 검사들이 전부 그 값에 곱해져 있다")


# -- helpers ------------------------------------------------------------------------------------------

## One frame of the whole pipeline in the shell's own order: clear last frame's facts, step the sim,
## then let the view age its drawers and drain what the sim just said.
##
## `sim_dt` and `view_dt` are separate because most of these fixtures need the sim FROZEN while the
## view's clock runs — that separation is the design (the view owns its clock) and not a convenience.
func _frame(t, b: Battle, fv: FieldSpy, sim_dt: float, view_dt: float) -> void:
	b.begin_frame()
	if sim_dt > 0.0:
		b.step(sim_dt)
	fv._process(view_dt)
	await t.pump_frames(2)


## Element `i` of a capture array, or an empty Dictionary. **An empty capture is exactly what a
## deleted effect produces**, and indexing it kills every check after it in the file instead of
## reddening one — measured while inverting the flash, which took 69 checks down with it. Every read
## below goes through `_pt` / `_num`, whose sentinels are far outside any legal value, so a missing
## capture reddens the check that wanted it and nothing else.
func _at(rows: Array, i: int) -> Dictionary:
	return rows[i] if i >= 0 and i < rows.size() else {}


func _pt(d: Dictionary, key: String) -> Vector2:
	if not d.has(key):
		return Vector2(-99999.0, -99999.0)
	var v: Vector2 = d[key]
	return v


func _num(d: Dictionary, key: String) -> float:
	return float(d[key]) if d.has(key) else -99999.0


func _rect(d: Dictionary, key: String) -> Rect2:
	if not d.has(key):
		return Rect2(Vector2(-99999.0, -99999.0), Vector2.ZERO)
	var r: Rect2 = d[key]
	return r


## The captured colour, or one no effect uses. Never a default that could match what is expected.
func _col(d: Dictionary, key: String) -> Color:
	if not d.has(key):
		return Look.COL_HOLE
	var c: Color = d[key]
	return c


## Was `a` drawn before `b`. **A capture that is missing makes this false, never true** — an ordering
## check that cannot see both sides has to be red, and "the halo was never drawn" must not read as
## "the halo was drawn underneath".
func _before(a: Dictionary, b: Dictionary) -> bool:
	return a.has("seq") and b.has("seq") and int(a["seq"]) < int(b["seq"])


## The captured points, or an empty array — which is also what a leaf handed nothing looks like, and
## every geometry check below reddens on it.
func _pts(d: Dictionary) -> PackedVector2Array:
	if not d.has("points"):
		return PackedVector2Array()
	var p: PackedVector2Array = d["points"]
	return p


func _view_of(t, b: Battle, army: Army) -> FieldSpy:
	var fv := FieldSpy.new()
	fv.setup(b, army, _open())
	t.root.add_child(fv)
	# The engine must not add a delta of its own on top of the one each check chose. That it DOES
	# drive `_process` at all is measured in the first scene, with this line absent.
	fv.set_process(false)
	return fv


func _drop(t, fv: FieldSpy) -> void:
	t.root.remove_child(fv)
	fv.queue_free()


## Rings the same RGB as `tint`, alpha ignored — every ring fades its own alpha with age, and the
## three users of `_paint_ring` (burst, area/telegraph, landing) are told apart by colour and width.
func _rings_of(fv: FieldSpy, tint: Color) -> Array:
	var out := []
	for raw in fv.rings:
		var ring: Dictionary = raw
		var col: Color = ring["colour"]
		if absf(col.r - tint.r) <= 1e-3 and absf(col.g - tint.g) <= 1e-3 \
				and absf(col.b - tint.b) <= 1e-3:
			out.append(ring)
	return out


func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for k in points.size():
		sum += points[k]
	return sum / float(maxi(1, points.size()))


func _max_dist(points: PackedVector2Array, from: Vector2) -> float:
	var out := 0.0
	for k in points.size():
		out = maxf(out, from.distance_to(points[k]))
	return out


func _min_dist(points: PackedVector2Array, from: Vector2) -> float:
	var out := 1e30
	for k in points.size():
		out = minf(out, from.distance_to(points[k]))
	return out


## Rec.709 relative luminance — the same weights look.gd's halo comment works its contrast in.
func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Water border, land inside, no docks. 24 x 12, so every body sits well inside the 1280x720 canvas.
func _open() -> Array:
	var rows := []
	for y in ARENA_H:
		if y == 0 or y == ARENA_H - 1:
			rows.append("~".repeat(ARENA_W))
		else:
			rows.append("~" + ".".repeat(ARENA_W - 2) + "~")
	return rows


## The same arena with a bay: rows 3-7 water for the first six columns, land from column 6 on, one
## harbour at (2,5). `_PORT_LANDING` (6,5) is the coast it can see straight across open water.
const _PORT_LANDING := Vector2(6, 5)

func _port() -> Array:
	var rows := _open()
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


func _army_of(types: Array) -> Army:
	var a := Army.new()
	for raw in types:
		a.add(int(raw))
	return a


func _spawn(type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * ARENA_W + x}


## An island already under way. ⚠ **The commit flag is set directly, and that matters more here than
## anywhere else**: `step` refuses everything until the island is committed (`plan-then-watch`, 4.3),
## and **an uncommitted battle produces no `events` at all** — which is what every effect in this file
## is driven by. A fixture that forgot to commit would run its checks against an empty effect list and
## the zero-check rule would not catch it, because the file still runs plenty of checks. The commit
## gate itself is `net_plan`'s to measure.
func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var b := _planning_battle_of(rows, army, spawns, limit)
	b._committed = true
	return b


## The same island, left in the planning state, so a check can drive `send` and `commit` for real.
func _planning_battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var b := Battle.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	var g := Grid.new()
	g.load_rows(rows)
	b.setup(g, army, spawns, limit)
	return b


func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	_place(b, i, p)
	var claimed := b.grid.reserved
	claimed[int(round(p.y)) * b.grid.w + int(round(p.x))] = i
	b.grid.reserved = claimed


## Moves a landed soldier, GOAL included. Writing only `soldier_pos` leaves the stale goal behind and
## the next movement phase glides the soldier straight back toward it.
func _place(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
