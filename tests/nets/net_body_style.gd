extends RefCounted
## **The fork itself: does `Look.BODY_STYLE` actually change the picture.**
##
## `melee-legibility-ko` opens a fork nobody has decided — the body as a fill (갈래 ㄴ) or the body as a line
## with one centred dot (갈래 ㄱ, which is what `the-body-is-a-line-drawn-by-code` decided by generating
## candidates and looking at them). Both candidates live in one build behind one runtime switch so the user
## can be handed two photographs of the same field, and the danger that comes with that shape is named in
## CLAUDE.md as the signature fake: **a switch that changes nothing on screen while every check stays
## green.** That is the one thing this net exists to make impossible.
##
## Three instruments, because no one of them is enough:
##  · **the leaves that were called** — under LINE the fill leaf must be reached ZERO times and vice versa,
##    which is what reddens `_paint_cell_line` quietly forwarding to `_paint_cell_fill`
##  · **the numbers that were computed** — `_outline_width`/`_outline_dot_r` are spied AND pinned at literal
##    radii, so the stroke and the nucleus cannot be a constant that happens to look plausible
##  · **`net_draw_leaf`'s per-function `draw_*` count** — the last inch, and it lives there rather than here:
##    a spy sees the hook being CALLED and never the native call inside it
##
## ⚠ **`Look.BODY_STYLE` is a `static var`, so it is process-global and every check in this file shares one
## process.** Every function below sets it back to `FILL` before it returns; a check that left it on LINE
## would silently decide what the checks after it were measuring.


## Both candidates, the two pure functions behind 갈래 ㄱ, and the two leaves a slot still owns. One spy
## rather than five, because "the fill leaf ran zero times while the line leaf ran six" is a claim about one
## frame and reading it off two separate captures cannot say they were the same frame.
class StyleSpy extends FieldView:
	var cells: Array = []
	var fills: Array = []
	var lines: Array = []
	var dots: Array = []
	var outlines: Array = []
	## What the stroke and the nucleus were computed FROM. A body's own radius has to arrive here, or the
	## width is a number that merely looks right — the parameter scan cannot see `r` swapped for a literal
	## inside the call, because `r` stays mentioned by the `_blob()` on the line above.
	var widths: Array = []
	var dot_rs: Array = []
	## ⚠ **What the shape was actually BUILT from, which no capture at a hook can see.** Both candidates hand
	## a body's radius to `_blob()` and then to a native `draw_*` the engine will not let us override, so
	## `r` swapped for `r * 0.0` inside either leaf keeps every argument on every hook correct — and keeps
	## `r` mentioned, so `net_draw_leaf`'s parameter scan cannot see it either. Measured on BOTH branches:
	## `_blob(r * 0.0, …)` in `_paint_cell_line` (bodies collapse to bare dots) and the same in
	## `_paint_cell_fill` (the filled body vanishes under its own shadow) were each green at 2617 checks.
	## `net_paint` already spies this function for the host's corner chain; this is the same instrument
	## pointed at the radius, for every body and in both candidates.
	var blobs: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		cells.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot, corner)

	func _paint_cell_fill(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
			corner: float) -> void:
		fills.append({"p": p, "r": r, "col": col})
		super._paint_cell_fill(c, p, r, col, squash, rot, corner)

	func _paint_cell_line(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float,
			corner: float) -> void:
		lines.append({"p": p, "r": r, "col": col})
		super._paint_cell_line(c, p, r, col, squash, rot, corner)

	func _blob(r: float, at: Vector2 = Vector2.ZERO,
			corner: float = Look.CORNER) -> PackedVector2Array:
		var pts := super._blob(r, at, corner)
		blobs.append({"r": r, "at": at, "pts": pts})
		return pts

	func _outline_width(r: float) -> float:
		var w := super._outline_width(r)
		widths.append({"r": r, "w": w})
		return w

	func _outline_dot_r(r: float, bonus: float = 0.0) -> float:
		var out := super._outline_dot_r(r, bonus)
		dot_rs.append({"r": r, "bonus": bonus, "out": out})
		return out

	func _paint_dot(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
		dots.append({"p": p, "r": r, "col": col})
		super._paint_dot(c, p, r, col)

	## `squash` and `rot` joined the signature with 갈래 ㄴ's rim — Godot rejects an override that does not
	## match, so this shape is forced by the file rather than chosen.
	func _paint_outline(c: CanvasItem, p: Vector2, r: float, corner: float, col: Color,
			width: float, squash: Vector2, rot: float) -> void:
		outlines.append({"p": p, "r": r, "width": width})
		super._paint_outline(c, p, r, corner, col, width, squash, rot)

	func forget() -> void:
		cells.clear()
		fills.clear()
		lines.clear()
		dots.clear()
		outlines.clear()
		widths.clear()
		dot_rs.clear()
		blobs.clear()


func run(t) -> void:
	_s1_the_default_is_todays_picture(t)
	_s2_the_numbers_behind_the_line(t)
	await _s3_the_switch_reaches_the_leaves(t)
	await _s4_the_eyes_square_under_the_line(t)
	await _s5_hide_still_owns_the_outline_leaf(t)


# -- S1: the switch ships as FILL ------------------------------------------------------------------------
## **The default decides which candidate an unrelated round quietly photographs**, so it is asserted twice
## and in two different ways: the value this process opened with (before any check below flips it) and the
## text on disk. The runtime read alone would pass on a tree whose default had been changed and then set
## back by an earlier net; the text alone would pass on a file the engine never loaded.
func _s1_the_default_is_todays_picture(t) -> void:
	t.eq(Look.BODY_STYLE, Look.BodyStyle.LINE,
			"이 프로세스가 열릴 때 몸 스타일은 LINE이다 — 사용자가 세 장을 보고 고른 갈래다")
	t.ok(Look.BodyStyle.FILL != Look.BodyStyle.LINE,
			"설정: 두 갈래는 서로 다른 값이다 — 같은 값이면 아래 분기 검사는 전부 공짜로 통과한다")

	var text := _read("res://src/look.gd")
	t.ok(text != "", "look.gd를 읽었다")
	var line := _static_var_line(text, "BODY_STYLE")
	t.ok(line != "", "look.gd에 static var BODY_STYLE 선언이 있다 — 찾은 줄: '%s'" % line)
	t.ok(line.contains("BodyStyle.LINE"),
			"그 선언은 LINE으로 적혀 있다 — 사용자가 고른 갈래가 게임이 여는 그림이다 ('%s')" % line)
	t.ok(not line.contains("BodyStyle.FILL"),
			"그리고 FILL로 적혀 있지 않다 — 한쪽만 보면 두 이름이 다 든 줄도 통과한다")
	# **A `const` would fold one branch into the build and leave the other as unreachable text**, and then a
	# net could only ever drive whichever branch happened to be selected. The declaration form is the thing
	# that makes the whole comparison below possible, so it is asserted rather than trusted.
	t.ok(not text.contains("const BODY_STYLE"),
			"const이 아니라 static var다 — const면 한 갈래가 도달 불가능한 글이 되고 절반이 안 재진다")

	# **Invert the instrument.** A reader that cannot find the line reads exactly like a file declaring the
	# value we want. The synthetic carries the OTHER value for that reason — a fake file spelling the real
	# default would pass this whether the scanner read it or returned it by accident.
	t.eq(_static_var_line("static var BODY_STYLE: int = BodyStyle.FILL\n", "BODY_STYLE"),
			"static var BODY_STYLE: int = BodyStyle.FILL",
			"FILL로 적힌 가짜 파일에서는 그 줄이 그대로 읽힌다 (스캐너 자가 점검)")
	t.eq(_static_var_line("static var BODY_STYLE_OTHER := 1\n", "BODY_STYLE"), "",
			"접두사가 같은 다른 이름에 걸려들지 않는다 (스캐너 자가 점검)")
	t.eq(_static_var_line("## static var BODY_STYLE := BodyStyle.LINE in prose\n", "BODY_STYLE"), "",
			"주석 속 선언은 선언으로 세지 않는다 (스캐너 자가 점검)")


# -- S2: the stroke and the nucleus, at literal radii ----------------------------------------------------
## **Pure functions driven, never constants read back.** `_outline_width` is a fraction of the body clamped
## at both ends, and a clamp is exactly the shape CLAUDE.md records as half-measured when only one end is
## bitten — so both ends and the knee are pinned, and the numbers are literals on both sides.
##
## Radii are the real ones: a crumb is 3, an empty clone 8, the host 14, a 사자 26, the boss 48, and a boss
## at the 1.5× force cap is 72. Only the two largest reach the width cap, so the stroke is monotone in body
## size across everything fought before the boss.
func _s2_the_numbers_behind_the_line(t) -> void:
	var f := FieldView.new()

	for pair in [[3.0, 1.5], [8.0, 1.5], [14.0, 1.96], [26.0, 3.64], [48.0, 6.0], [72.0, 6.0]]:
		var r: float = pair[0]
		var want: float = pair[1]
		t.ok(absf(f._outline_width(r) - want) < 0.0001,
				"반지름 %.0f의 선 굵기는 %.2fpx다 (리터럴) (%.4f)" % [r, want, f._outline_width(r)])
	t.ok(f._outline_width(3.0) == f._outline_width(8.0),
			"가장 작은 두 몸은 바닥값에서 만난다 — 바닥이 없으면 3px짜리 몸의 선은 0.42px다")
	t.ok(f._outline_width(48.0) == f._outline_width(72.0),
			"가장 큰 두 몸은 천장에서 만난다 — 천장이 없으면 보스의 선이 10px 덩어리가 된다")
	t.ok(f._outline_width(14.0) < f._outline_width(26.0),
			"그 사이에서는 몸이 클수록 선이 굵다 — 클램프 두 개가 전부를 눌러 버리지 않는다")

	for pair in [[3.0, 2.0], [8.0, 2.0], [14.0, 3.08], [26.0, 5.72], [48.0, 10.56]]:
		var r: float = pair[0]
		var want: float = pair[1]
		t.ok(absf(f._outline_dot_r(r) - want) < 0.0001,
				"반지름 %.0f의 가운데 점은 %.2fpx다 (리터럴) (%.4f)" % [r, want, f._outline_dot_r(r)])
	t.ok(f._outline_dot_r(3.0) == f._outline_dot_r(8.0),
			"가장 작은 몸의 점도 바닥값을 지킨다 — 바닥이 없으면 「그냥 사각형」이 된다")
	# The EYES square's own payout under 갈래 ㄱ: it enlarges the ONE nucleus rather than adding a pair.
	t.ok(absf(f._outline_dot_r(14.0, 0.17) - 5.46) < 0.0001,
			"눈 칸 Lv1을 낀 호스트의 점은 5.46px다 (14 × (0.22 + 0.17), 리터럴) (%.4f)"
					% f._outline_dot_r(14.0, 0.17))
	t.ok(f._outline_dot_r(14.0, 0.17) > f._outline_dot_r(14.0),
			"눈 칸은 가운데 점을 실제로 키운다 — 0을 더하는 인자가 아니다")

	f.free()


# -- S3: the switch actually reaches the leaves ----------------------------------------------------------
## **The same frame, drawn twice, and only one axis moves.** Six bodies are staged at pinned offsets — the
## host, three clones and two crows (crows because `SPECIES_SPEED_MUL` is under 1.0, so no afterimage joins
## the count) — with no food, no rocks, no ponds and no corpses, so the number of bodies is a literal.
##
## Under FILL the line leaf must be reached **zero** times and under LINE the fill leaf must be reached
## **zero** times. That pair is what reddens the fake this whole file exists for: `_paint_cell_line`
## forwarding to `_paint_cell_fill` keeps every count of "the line leaf ran" correct while the screen is
## unchanged. The `_paint_cell` capture is compared element by element across the two styles, because the
## fork is only worth photographing if the two shots differ in ONE thing.
func _s3_the_switch_reaches_the_leaves(t) -> void:
	var w := _staged(120)
	var spy := StyleSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	# -- FILL: today's picture ---------------------------------------------------------------------------
	Look.BODY_STYLE = Look.BodyStyle.FILL
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.cells.size(), 6, "설정: 한 프레임에 몸 여섯이 그려진다 (호스트 1 + 분신 3 + 까마귀 2)")
	t.eq(spy.fills.size(), 6, "FILL에서는 여섯 몸이 전부 채우는 잎을 지난다")
	t.eq(spy.lines.size(), 0, "그리고 선 잎은 한 번도 안 불린다 — 스위치가 한쪽만 켠다")
	t.eq(spy.widths.size(), 0, "FILL에서는 선 굵기를 아예 계산하지 않는다")
	t.eq(spy.dot_rs.size(), 0, "FILL에서는 가운데 점의 크기도 계산하지 않는다")
	var fill_cells := spy.cells.duplicate(true)
	# **The shape that was BUILT, not the arguments that were handed on.** 채우는 잎은 몸마다 `_blob`을 제
	# 반지름으로 두 번 — 그림자 하나, 몸 하나 — 부르고 위쪽 밝은 면만 `r × 0.52`로 부른다. 그 둘 중 하나를
	# `r × 0.0`으로 바꿔도 나머지 하나가 반지름을 그대로 나르므로, **개수를 세지 않으면 안 잡힌다.**
	t.eq(_blobs_on_bodies(spy, fill_cells), 12,
			"FILL에서는 여섯 몸이 제 반지름으로 도형을 열둘 짓는다 (그림자 여섯 + 몸 여섯, 리터럴) %d"
					% _blobs_on_bodies(spy, fill_cells))

	# -- LINE: 갈래 ㄱ ------------------------------------------------------------------------------------
	Look.BODY_STYLE = Look.BodyStyle.LINE
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 6, "LINE에서는 같은 여섯 몸이 전부 선 잎을 지난다")
	t.eq(spy.fills.size(), 0,
			"그리고 채우는 잎은 한 번도 안 불린다 — 선 잎이 몰래 채운 몸을 그리면 여기가 빨강이다")
	var line_cells := spy.cells.duplicate(true)
	# 갈래 ㄱ의 같은 자리. 선 잎은 몸마다 도형을 **하나만** 짓고 그것이 화면에 나오는 전부다 — 이것이 0이면
	# 필드의 모든 몸이 가운데 점 하나로 쪼그라들고, 그 사진은 사용자가 고르라고 받은 그림이 아니다.
	t.eq(_blobs_on_bodies(spy, line_cells), 6,
			"LINE에서는 여섯 몸이 제 반지름으로 도형을 여섯 짓는다 (리터럴) %d"
					% _blobs_on_bodies(spy, line_cells))
	# **Invert the instrument.** 반지름이 안 맞는 도형은 세지 않는다는 것이 이 계기의 주장 전부다.
	t.eq(_blobs_on_bodies(spy, [{"r": 999.0}]), 0,
			"아무 몸도 갖지 않은 반지름으로는 하나도 안 세어진다 (스캐너 자가 점검)")

	# **One axis, and this is the check that says so.** Colour, size, squash, ordering, terrain and the HUD
	# all stay where they are; if the two shots differed in two things the comparison would answer nothing.
	t.eq(line_cells.size(), fill_cells.size(), "두 갈래가 그린 몸의 수는 같다")
	var same := 0
	for i in mini(line_cells.size(), fill_cells.size()):
		var a: Dictionary = fill_cells[i]
		var b: Dictionary = line_cells[i]
		if a["p"] == b["p"] and a["r"] == b["r"] and a["col"] == b["col"]:
			same += 1
	t.eq(same, 6, "여섯 몸의 자리·반지름·색이 두 갈래에서 똑같다 — 바뀌는 축은 채움이냐 선이냐 하나뿐이다")

	# **The stroke and the nucleus were computed from each body's OWN radius.** Six of each, and every drawn
	# radius has to appear — a width pinned to a literal inside the leaf keeps the count at 4 and keeps `r`
	# mentioned, so nothing else in the round can see it.
	t.eq(spy.widths.size(), 6, "선 굵기를 몸마다 한 번씩 계산했다")
	t.eq(spy.dot_rs.size(), 6, "가운데 점의 크기도 몸마다 한 번씩 계산했다")
	var radii_ok := 0
	var dot_radii_ok := 0
	for e: Dictionary in line_cells:
		if _has_r(spy.widths, float(e["r"])):
			radii_ok += 1
		if _has_r(spy.dot_rs, float(e["r"])):
			dot_radii_ok += 1
	t.eq(radii_ok, 6, "그 굵기는 몸 자신의 반지름에서 나왔다 — 상수를 그리면 여기가 빨강이다")
	t.eq(dot_radii_ok, 6, "가운데 점도 몸 자신의 반지름에서 나왔다")
	# The boss and the crumb are not the same stroke, and that is the whole reason the width is a fraction.
	var host_w := _w_for(spy.widths, Rules.BODY_RADIUS)
	var clone_w := _w_for(spy.widths, Rules.CLONE_BODY_RADIUS)
	t.ok(host_w > clone_w,
			"호스트의 선이 빈 분신의 선보다 굵다 (%.3f > %.3f) — 몸 크기를 따라간다" % [host_w, clone_w])

	# -- and back --------------------------------------------------------------------------------------
	Look.BODY_STYLE = Look.BodyStyle.FILL
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.fills.size(), 6, "다시 FILL로 돌리면 여섯 몸이 채우는 잎으로 돌아온다")
	t.eq(spy.lines.size(), 0, "그리고 선 잎은 다시 0이다 — 스위치는 한 방향으로만 가는 것이 아니다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- S4: what the EYES square draws under each candidate -------------------------------------------------
## `the-body-is-a-line-drawn-by-code` rejected **two eyes** by name — a face has a front, and this body takes
## parts on all six sides. Under 갈래 ㄱ the square enlarges the one centred nucleus instead, so the same
## slot at the same level has to reach `_paint_dot` a different number of times, in a different place, at a
## different size. Deleting the branch entirely would give the fork a side effect nobody asked for: an
## internal slot that draws nothing.
##
## ⚠ **No part in the August table occupies `EYES`**, so `slot_level` is written by hand exactly as
## `net_paint` already does for the other internal squares.
func _s4_the_eyes_square_under_the_line(t) -> void:
	var w := _staged(121)
	w.body.slot_level[Parts.Slot.EYES] = 1
	var host: Vector2 = w.swarm.pos[0]
	var spy := StyleSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.FILL
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.dots.size(), 2, "FILL에서는 눈이 좌우 한 쌍으로 찍힌다")
	t.ok(_has_dot(spy.dots, host + Vector2(5.32, 5.04), 2.38),
			"오른눈은 몸 앞 5.32px·옆 5.04px에 반지름 2.38px다 (리터럴) %s" % str(spy.dots))
	t.ok(_has_dot(spy.dots, host + Vector2(5.32, -5.04), 2.38), "왼눈은 그 거울상이다")

	Look.BODY_STYLE = Look.BodyStyle.LINE
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.dots.size(), 1, "LINE에서는 점이 하나다 — 거절된 눈 두 개를 그리지 않는다")
	if spy.dots.size() == 1:
		var d: Dictionary = spy.dots[0]
		t.ok(d["p"] == host, "그 점은 몸 한가운데다 — 앞뒤로 밀린 자리가 아니다 %s" % str(d))
		t.ok(absf(float(d["r"]) - 5.46) < 0.001,
				"그리고 반지름 5.46px로 커진 핵이다 (14 × (0.22 + 0.17), 리터럴) (%.3f)" % float(d["r"]))
	# **The negative control, and it is what makes the 1 above mean something.** A bare body under LINE still
	# carries its nucleus, but that one is drawn by `_paint_cell_line`'s own circle and never through
	# `_paint_dot` — so an empty EYES square has to leave this leaf untouched.
	w.body.slot_level[Parts.Slot.EYES] = 0
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.dots.size(), 0,
			"부정 대조: 눈 칸이 비면 LINE에서도 _paint_dot은 안 불린다 — 몸의 핵은 그 잎을 안 지난다")

	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- S5: the body's own stroke is not the HIDE square's outline -------------------------------------------
## `_paint_outline` is spied by `net_paint` on the claim that it is reached **only** when hide is worn. 갈래
## ㄱ strokes its own polyline rather than reusing that leaf precisely so that claim survives — folding every
## body on the field into that spy would make every hide assertion in the round unreadable.
func _s5_hide_still_owns_the_outline_leaf(t) -> void:
	var w := _staged(122)
	var spy := StyleSpy.new()
	spy.world = w
	spy.view_rect = Rect2(Vector2.ZERO, Rules.FIELD)
	t.root.add_child(spy)
	await t.pump_frames(2)

	Look.BODY_STYLE = Look.BodyStyle.LINE
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.outlines.size(), 0,
			"LINE에서 가죽을 안 입은 필드는 _paint_outline을 한 번도 안 부른다 — 몸의 선은 그 잎이 아니다")
	t.eq(spy.lines.size(), 6, "설정: 그런데도 여섯 몸은 전부 선으로 그려졌다")

	w.body.slot_level[Parts.Slot.HIDE] = 2
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.outlines.size(), 1, "가죽 Lv2를 입으면 LINE에서도 그 잎이 한 번 불린다 — 칸이 죽지 않았다")
	if spy.outlines.size() == 1:
		t.ok(absf(float(spy.outlines[0]["width"]) - 4.0) < 0.001,
				"그 테두리의 폭은 여전히 4.0px다 (리터럴) (%.3f)" % float(spy.outlines[0]["width"]))

	w.body.slot_level[Parts.Slot.HIDE] = 0
	Look.BODY_STYLE = Look.BodyStyle.FILL
	t.root.remove_child(spy)
	spy.queue_free()


# -- fixture ---------------------------------------------------------------------------------------------
## Six bodies at pinned offsets and nothing else on the field, so every count above is a literal rather than
## a function of the spawner's randomness. **Crows, not horses**: `Rules.SPECIES_SPEED_MUL` is under 1.0 for
## the crow, so no afterimage ghost joins the cell count.
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
	var host: Vector2 = w.swarm.pos[0]
	for i in 3:
		var k := w.swarm.add_clone()
		w.swarm.pos[k] = host + Vector2(-60.0 - i * 25.0, 30.0)
	w._write_critter(Parts.Species.CROW, host + Vector2(200.0, 0.0), 10)
	w._write_critter(Parts.Species.CROW, host + Vector2(280.0, 0.0), 10)
	return w


## The one `static var NAME` line, or `""`. Whole-word on the name, and comment lines are dropped first —
## the same classification `net_draw_leaf` and `net_citations` both use.
func _static_var_line(text: String, name: String) -> String:
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("static var "):
			continue
		var rest := line.substr(11).strip_edges()
		var cut := rest.find(":")
		var eq_at := rest.find("=")
		if cut < 0 or (eq_at >= 0 and eq_at < cut):
			cut = eq_at
		if cut < 0:
			continue
		if rest.substr(0, cut).strip_edges() == name:
			return line
	return ""


## How many polygons this frame were built AT THE ORIGIN from one of the drawn bodies' own radii. The
## origin filter is what keeps a part's own shape — `_blob(r, p, corner)`, built at the body's world
## position — out of a count that is about bodies.
func _blobs_on_bodies(spy: StyleSpy, cells: Array) -> int:
	var out := 0
	for b: Dictionary in spy.blobs:
		if b["at"] != Vector2.ZERO:
			continue
		for e: Dictionary in cells:
			if absf(float(b["r"]) - float(e["r"])) < 0.0001:
				out += 1
				break
	return out


func _has_r(list: Array, r: float) -> bool:
	for e: Dictionary in list:
		if absf(float(e["r"]) - r) < 0.001:
			return true
	return false


func _w_for(list: Array, r: float) -> float:
	for e: Dictionary in list:
		if absf(float(e["r"]) - r) < 0.001:
			return float(e["w"])
	return -1.0


func _has_dot(list: Array, at: Vector2, r: float) -> bool:
	for e: Dictionary in list:
		if e["p"].distance_to(at) < 0.02 and absf(float(e["r"]) - r) < 0.02:
			return true
	return false


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()
