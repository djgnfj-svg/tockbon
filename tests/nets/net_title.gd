extends RefCounted
## The title screen, driven treed with real frames: the three slots, the one that does NOT press, the
## hover and the dip, and the cells drifting behind them.
##
## **What this net exists for is one sentence the user said after the last round**: *"뭐 어떻게
## 동작시키는지 전혀모르겠는데?"* — a screen shipped with no text, a 10 px drag source and a drop zone
## at alpha 0.18. So every row below is a bound on the PICTURE, not on the code: how big the smallest
## press is, how much brighter a hovered slot is than a resting one, how much darker an unpressable
## one is than a pressable one, and that the background never reaches either.
##
## ⚠ **`TitleView` holds no `Run` and there is nothing to bind**, so unlike `net_shell` this file
## builds the view alone. The SHELL's half — that pressing 시작하기 actually makes a run, that 설정하기
## does nothing, that 종료 asks the tree to close — is `net_shell`'s, driven through
## `game._unhandled_input`. Split that way on purpose: this file measures what the screen LOOKS like
## and that file measures what a press DOES, and neither can pass on the other's evidence.
##
## ⚠⚠ **The view's own clock is stopped (`set_process(false)`) and `_fx_step(dt)` is called by hand.**
## A headless frame is 6.56 ms here (measured), so a hover ramp of 0.10 s is fifteen frames of
## guessing — and a captured frame and a value read after it would not be the same instant. `_draw` is
## still driven for real: `queue_redraw()` then `pump_frames(1)`, treed, so the hooks below carry what
## the engine actually asked for.


## Every one of the four leaves is overridden, and that is not bookkeeping: a hook left out binds to
## nothing, the REAL `draw_*` runs headless, the capture array stays empty, and every check about it
## reads as "nothing was drawn" rather than as a failure.
##
## `_seq` is the layer contract. The arrays are per hook, so the order BETWEEN hooks cannot be
## recovered from them — and here the order is a real claim: the drifting cells are painted first and
## a slot box is painted before its own label, or the box covers the word inside it.
class TitleSpy extends TitleView:
	var draws := 0
	var seq := 0
	var cells := []
	var titles := []
	var boxes := []
	var labels := []

	func _draw() -> void:
		cells.clear()
		titles.clear()
		boxes.clear()
		labels.clear()
		seq = 0
		super()
		draws += 1

	func _bump() -> int:
		seq += 1
		return seq - 1

	func _paint_tile(centre: Vector2, radius: float, col: Color) -> void:
		cells.append({"seq": _bump(), "centre": centre, "radius": radius, "col": col})

	func _paint_title(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		titles.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})

	func _paint_slot_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
		boxes.append({"seq": _bump(), "rect": rect, "bg": bg, "edge": edge, "width": edge_width})

	func _paint_slot_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		labels.append({"seq": _bump(), "face": face, "at": at, "text": text, "fsize": fsize,
			"col": col})


## The viewport, as LITERALS. A check whose bounds come from the thing it checks proves nothing —
## reading `Look.VIEWPORT_W_PX` on both sides would let the screen shrink and every rectangle shrink
## with it.
const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)

## The smallest press this repo had before the title existed: the panel's 다시 하기 button. A title
## slot must not be smaller than it. Written out rather than read off `Look.button_rect_px()` for the
## same reason as `SCREEN`.
const SMALLEST_PRESS_BEFORE := Vector2(220.0, 64.0)


func run(t) -> void:
	_geometry_is_readable(t)
	_the_dead_slot_says_so(t)
	_hover_and_press_answer_the_hand(t)
	_the_background_is_background(t)
	await _the_leaves_draw_what_they_were_handed(t)
	_the_drifting_shape_is_not_a_cell(t)


# -- geometry: can it be aimed at ------------------------------------------------------------------

func _geometry_is_readable(t) -> void:
	var view := TitleView.new()
	t.eq(view.SLOT_LABELS.size(), 3, "칸은 셋이다 — 시작하기 · 설정하기 · 종료")
	t.eq(str(view.SLOT_LABELS[0]), "시작하기", "0번 칸은 시작하기다")
	t.eq(str(view.SLOT_LABELS[1]), "설정하기", "1번 칸은 설정하기다")
	t.eq(str(view.SLOT_LABELS[2]), "종료", "2번 칸은 종료다")

	# 「칸 셋의 사각형이 겹치지 않고 화면 안에 있다」 — floor: all three inside the LITERAL screen;
	# ceiling: no two HIT rects intersect. Mutation: TITLE_SLOT_GAP_PX -> 0.
	var outside := 0
	var overlapping := 0
	for i in 3:
		var drawn := view.slot_rect_of(i)
		var hit := view.slot_hit_rect_of(i)
		if not SCREEN.encloses(hit):
			outside += 1
		if drawn.size.x <= 0.0 or drawn.size.y <= 0.0:
			outside += 1
		for j in range(i + 1, 3):
			if hit.intersects(view.slot_hit_rect_of(j)):
				overlapping += 1
	t.eq(outside, 0, "칸 셋의 판정 사각형이 전부 1280x720 안이고 넓이가 0이 아니다")
	t.eq(overlapping, 0, "어느 두 칸의 판정 사각형도 안 겹친다 — 간격이 0이면 여기가 문다")

	# 「판정 사각형이 그림보다 사방 8px 크다」 — floor: the hit rect contains the drawn one and is
	# strictly bigger; ceiling: it is not more than 1.6x the area, or the pad is a second button.
	var pad_bad := 0
	var area_bad := 0
	for i in 3:
		var drawn := view.slot_rect_of(i)
		var hit := view.slot_hit_rect_of(i)
		if not hit.encloses(drawn):
			pad_bad += 1
		if not is_equal_approx(hit.size.x - drawn.size.x, 2.0 * Look.PRESS_HIT_PAD_PX):
			pad_bad += 1
		if not is_equal_approx(hit.size.y - drawn.size.y, 2.0 * Look.PRESS_HIT_PAD_PX):
			pad_bad += 1
		if hit.size.x * hit.size.y > drawn.size.x * drawn.size.y * 1.6:
			area_bad += 1
	t.eq(pad_bad, 0, "판정 사각형이 그림보다 사방으로 정확히 %.0fpx 크다" % Look.PRESS_HIT_PAD_PX)
	t.eq(area_bad, 0, "그래도 판정이 그림 넓이의 1.6배를 안 넘는다 — 여백이 두 번째 단추가 되지 않는다")
	t.ok(Look.PRESS_HIT_PAD_PX >= 4.0 and Look.PRESS_HIT_PAD_PX <= 11.0,
		"누름 여백이 4~11px 사이다 (%.1f) — 0이면 조준이 정확해야 하고, 112px 칸 간격의 1/10을 넘으면 옆 칸을 먹는다"
			% Look.PRESS_HIT_PAD_PX)

	# 「가장 작은 누름이 220x64보다 작지 않다」 — floor and ceiling on the same row.
	t.ok(Look.TITLE_SLOT_SIZE_PX.x >= SMALLEST_PRESS_BEFORE.x
			and Look.TITLE_SLOT_SIZE_PX.y >= SMALLEST_PRESS_BEFORE.y,
		"칸이 %.0fx%.0f 이고, 이 게임에 이미 있던 가장 작은 누름 220x64 보다 크다"
			% [Look.TITLE_SLOT_SIZE_PX.x, Look.TITLE_SLOT_SIZE_PX.y])
	t.ok(Look.TITLE_SLOT_SIZE_PX.x <= 480.0 and Look.TITLE_SLOT_SIZE_PX.y <= 120.0,
		"그렇다고 480x120 을 넘지도 않는다 — 화면을 단추가 다 먹으면 칸 셋이 한 덩어리로 읽힌다")
	t.ok(Look.TITLE_SLOT_GAP_PX >= 12.0 and Look.TITLE_SLOT_GAP_PX <= 44.0,
		"칸 사이가 12~44px 다 (%.0f) — 12 밑이면 셋이 한 막대로 읽히고, 44 위면 셋째 칸이 화면을 넘는다"
			% Look.TITLE_SLOT_GAP_PX)

	# 「칸의 글자가 30px보다 크다」 · 「제목 글자가 칸 글자보다 16px 이상 크다」 — both ends each.
	t.ok(Look.TITLE_SLOT_FONT_SIZE_PX > Look.HUD_TIMER_FONT_SIZE_PX,
		"칸 글자 %dpx 가 지금까지 가장 큰 글자였던 시계 %dpx 보다 크다"
			% [Look.TITLE_SLOT_FONT_SIZE_PX, Look.HUD_TIMER_FONT_SIZE_PX])
	t.ok(Look.TITLE_SLOT_FONT_SIZE_PX <= 56, "그래도 56px 을 안 넘는다 — 네 글자가 칸을 넘어간다")
	t.ok(Look.TITLE_FONT_SIZE_PX >= Look.TITLE_SLOT_FONT_SIZE_PX + 16,
		"제목 %dpx 가 칸 글자보다 16px 이상 크다 — 제목이 화면에서 가장 큰 것이다"
			% Look.TITLE_FONT_SIZE_PX)
	t.ok(Look.TITLE_FONT_SIZE_PX <= 96, "그래도 96px 을 안 넘는다")

	# 「글자가 칸 원점에 안 찍힌다」 — a baseline at the rect's own origin puts every glyph ABOVE the
	# box. Floor: x > 0 and y >= the font size. Ceiling: the baseline is still inside the rect.
	t.ok(Look.TITLE_SLOT_TEXT_OFFSET_PX.x > 0.0
			and Look.TITLE_SLOT_TEXT_OFFSET_PX.y >= float(Look.TITLE_SLOT_FONT_SIZE_PX),
		"칸 글자 자리가 (%.0f, %.0f) 로 원점이 아니다 — y 가 글자 크기 이상이라 글자가 상자 안으로 내려온다"
			% [Look.TITLE_SLOT_TEXT_OFFSET_PX.x, Look.TITLE_SLOT_TEXT_OFFSET_PX.y])
	t.ok(Look.TITLE_SLOT_TEXT_OFFSET_PX.x < Look.TITLE_SLOT_SIZE_PX.x
			and Look.TITLE_SLOT_TEXT_OFFSET_PX.y <= Look.TITLE_SLOT_SIZE_PX.y,
		"그리고 그 자리가 칸 사각형 안이다")
	t.ok(SCREEN.has_point(Look.TITLE_TEXT_POS_PX), "제목 글자 자리도 화면 안이다")
	t.ok(Look.TITLE_TEXT_POS_PX.y >= 120.0 and Look.TITLE_TEXT_POS_PX.y <= 280.0,
		"제목이 y %.0f — 120 밑이면 72px 글자가 화면 위로 잘리고, 280 위면 첫 칸(y 340)에 붙는다"
			% Look.TITLE_TEXT_POS_PX.y)

	# The hit test itself, at the four corners and at the two gaps between slots. `slot_at` is what
	# the shell asks, so a rectangle that is right and a hit test that is wrong is still a dead screen.
	for i in 3:
		var hit := view.slot_hit_rect_of(i)
		t.eq(view.slot_at(hit.get_center()), i, "%d번 칸 가운데를 찍으면 %d번이 나온다" % [i, i])
		t.eq(view.slot_at(hit.position + Vector2(1.0, 1.0)), i, "%d번 칸 왼쪽 위 모서리도 %d번이다" % [i, i])
	t.eq(view.slot_at(Vector2(640.0, 700.0)), -1, "빈 데를 찍으면 -1 이다")
	t.eq(view.slot_at(Vector2(640.0, 60.0)), -1, "제목 위를 찍어도 -1 이다")
	var between := (view.slot_hit_rect_of(0).end.y + view.slot_hit_rect_of(1).position.y) * 0.5
	t.eq(view.slot_at(Vector2(640.0, between)), -1, "칸과 칸 사이를 찍으면 -1 이다 — 두 판정이 안 붙어 있다")
	t.eq(view.slot_at(Vector2(-5.0, -5.0)), -1, "화면 밖은 -1 이다")

	t.eq(view.slot_rect_of(-1), Rect2(), "없는 칸의 사각형은 빈 Rect2 다")
	t.eq(view.slot_rect_of(3), Rect2(), "명단 밖 칸도 빈 Rect2 다")
	t.eq(view.slot_hit_rect_of(99), Rect2(), "없는 칸의 판정도 빈 Rect2 다 — has_point 가 언제나 false 다")
	view.free()


# -- the slot that does not press ------------------------------------------------------------------

## ⚠ **This is the row that stops the screen from lying.** A slot that answers the cursor is a slot
## that says "this presses"; 설정하기 does nothing, so it must not answer, and it must not merely be
## silent — it has to be drawn as unpressable. Silence reads as "nothing happened", which is the
## complaint this whole round exists to answer.
func _the_dead_slot_says_so(t) -> void:
	var view := TitleView.new()
	t.ok(view.is_slot_pressable(TitleView.SLOT_START), "시작하기는 눌린다")
	t.ok(not view.is_slot_pressable(TitleView.SLOT_SETTINGS), "설정하기는 안 눌린다")
	t.ok(view.is_slot_pressable(TitleView.SLOT_QUIT), "종료는 눌린다")
	t.ok(not view.is_slot_pressable(-1), "-1 은 눌리는 칸이 아니다 — 빈 데를 찍은 결과가 그대로 들어온다")
	t.ok(not view.is_slot_pressable(3), "명단 밖 칸도 안 눌린다")

	# 「설정하기는 안 눌린다고 그려진다」 — floor: its fill alpha is at or under PRESS_ALPHA_OFF and it
	# has NO saturation; ceiling: it is still visible at all. Mutation: give it PRESS_ALPHA_ON.
	var dead := view._slot_fill(TitleView.SLOT_SETTINGS)
	var live := view._slot_fill(TitleView.SLOT_START)

	# ⚠ `+ EPS`, and not because the check is being loosened: `Color` stores 32-bit floats, so the
	# 0.30 `Look.dimmed` writes reads back as 0.30000001192 against a 64-bit `PRESS_ALPHA_OFF`. A bare
	# `<=` is red on a value that is exactly right. Measured, not guessed — it failed that way first.
	t.ok(dead.a <= Look.PRESS_ALPHA_OFF + Rules.EPS,
		"설정하기의 알파가 %.2f 로 PRESS_ALPHA_OFF 이하다" % dead.a)
	t.ok(dead.a >= 0.20, "그래도 0.20 이상이다 — 그 밑은 안 눌리는 게 아니라 없는 것이다")
	t.eq(dead.s, 0.0, "설정하기는 채도가 0이다 — 색이 남아 있으면 '파란 쪽 단추'로 눈이 계속 분류한다")
	t.ok(live.a / dead.a >= 3.0,
		"눌리는 칸이 못 누르는 칸보다 알파가 3배 넘게 밝다 (%.2f / %.2f = %.1f배)"
			% [live.a, dead.a, live.a / dead.a])
	t.ok(live.s > 0.0, "그리고 눌리는 칸은 채도가 남아 있다 (자가 점검 — 둘 다 0이면 위 비교가 무의미하다)")

	# 「설정하기는 호버해도 안 변한다」 — the delta is exactly zero, and the reason it is zero is that
	# `set_hover` refuses to make it the hovered slot at all. Mutation: let `set_hover` match every slot.
	var rest := view._slot_fill(TitleView.SLOT_SETTINGS)
	view.set_hover(view.slot_hit_rect_of(TitleView.SLOT_SETTINGS).get_center())
	view._fx_step(Look.PRESS_HOVER_SEC * 2.0)
	t.eq(view._hover_slot, -1, "설정하기 위에 커서를 올려도 호버 칸이 -1 로 남는다")
	t.eq(view._hover_of(TitleView.SLOT_SETTINGS), 0.0, "그래서 호버 값이 정확히 0이다")
	t.eq(view._slot_fill(TitleView.SLOT_SETTINGS), rest, "칸 색이 한 톨도 안 변했다")

	# And a press on it is refused at the view as well, not only at the shell.
	view.note_press(TitleView.SLOT_SETTINGS)
	t.eq(view._press_slot, -1, "설정하기는 note_press 를 불러도 눌린 칸이 안 된다")
	t.eq(view._press_of(TitleView.SLOT_SETTINGS), 0.0, "그래서 눌림 값도 0이다")
	t.eq(view._slot_box(TitleView.SLOT_SETTINGS), view.slot_rect_of(TitleView.SLOT_SETTINGS),
		"상자도 안 쭈그러든다 — 아무 일도 안 일어났는데 그림만 반응하지 않는다")
	view.free()


# -- the two things a hand gets back ---------------------------------------------------------------

func _hover_and_press_answer_the_hand(t) -> void:
	var view := TitleView.new()

	# 「호버하면 테두리가 3에서 6으로 간다」 — the widths themselves are `look.gd`'s, bounded at both
	# ends there and read back here; what this row measures is that the RAMP actually reaches the top.
	t.ok(Look.PRESS_HOVER_BORDER_WIDTH_PX - Look.PRESS_BORDER_WIDTH_PX >= 2.0,
		"호버 테두리가 기본보다 2px 이상 굵다 (%.0f -> %.0f) — 2px 밑은 반올림에 먹혀 안 보인다"
			% [Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX])
	t.ok(Look.PRESS_HOVER_BORDER_WIDTH_PX <= 10.0, "그래도 10px 을 안 넘는다 — 그 위는 테두리가 아니라 액자다")
	t.ok(Look.PRESS_BORDER_WIDTH_PX >= 2.0, "기본 테두리도 2px 이상이다 — 없는 테두리는 단추가 아니다")

	t.eq(view._hover_of(TitleView.SLOT_START), 0.0, "커서가 없으면 호버가 0이다")
	view.set_hover(view.slot_hit_rect_of(TitleView.SLOT_START).get_center())
	t.eq(view._hover_slot, TitleView.SLOT_START, "시작하기 위에 커서를 올리면 그 칸이 호버 칸이다")
	t.eq(view._hover_of(TitleView.SLOT_START), 0.0, "올린 그 순간에는 아직 0이다 — 램프가 있다")
	view._fx_step(Look.PRESS_HOVER_SEC * 0.5)
	var half := view._hover_of(TitleView.SLOT_START)
	t.ok(half > 0.0 and half < 1.0, "절반 시간이면 호버가 0과 1 사이다 (%.2f) — 계단이 아니라 램프다" % half)
	view._fx_step(Look.PRESS_HOVER_SEC * 0.6)
	t.eq(view._hover_of(TitleView.SLOT_START), 1.0, "%.2f초가 지나면 호버가 1이다" % Look.PRESS_HOVER_SEC)
	t.eq(view._hover_of(TitleView.SLOT_QUIT), 0.0, "그동안 종료 칸의 호버는 0으로 남아 있다")
	t.ok(Look.PRESS_HOVER_SEC >= 0.084 and Look.PRESS_HOVER_SEC <= 0.20,
		"호버 시간이 다섯 프레임(0.084초)과 0.20초 사이다 (%.2f) — 밑은 튀고 위는 늦다" % Look.PRESS_HOVER_SEC)

	var fresh := TitleView.new()
	var lit := view._slot_fill(TitleView.SLOT_START)
	var dark := fresh._slot_fill(TitleView.SLOT_START)
	t.ok(lit.get_luminance() > dark.get_luminance(),
		"호버한 칸이 안 호버한 칸보다 실제로 밝다 (%.3f > %.3f)" % [lit.get_luminance(), dark.get_luminance()])
	t.ok(lit.get_luminance() - dark.get_luminance() <= 0.25,
		"그래도 0.25 이상 밝아지지는 않는다 — 그 위는 호버가 아니라 다른 색이다")
	t.ok(Look.PRESS_HOVER_BRIGHTEN >= 0.08 and Look.PRESS_HOVER_BRIGHTEN <= 0.25,
		"밝기 증분이 0.08~0.25 다 (%.2f)" % Look.PRESS_HOVER_BRIGHTEN)

	# The cursor moving OFF has to put it back. A hover that only ever turns on leaves two slots lit.
	view.set_hover(Vector2(20.0, 700.0))
	t.eq(view._hover_slot, -1, "커서가 칸을 벗어나면 호버 칸이 -1 로 돌아온다")
	t.eq(view._hover_of(TitleView.SLOT_START), 0.0, "그리고 그 칸의 호버가 0으로 꺼진다")
	view.free()

	# 「누르면 0.96배로 눌리고 0.10초 뒤 돌아온다」 — floor: the box is measurably smaller at t=0.05;
	# ceiling: it is exactly the resting rect again at t=0.11 and never smaller than PRESS_DOWN_SCALE.
	var pressed := TitleView.new()
	var resting := pressed.slot_rect_of(TitleView.SLOT_START)
	t.eq(pressed._slot_box(TitleView.SLOT_START), resting, "누르기 전 상자는 쉬는 사각형 그대로다")
	pressed.note_press(TitleView.SLOT_START)
	t.eq(pressed._press_slot, TitleView.SLOT_START, "시작하기를 누르면 그 칸이 눌린 칸이 된다")
	t.eq(pressed._press_of(TitleView.SLOT_START), 1.0, "누른 그 순간 눌림이 1이다")
	pressed._fx_step(Look.PRESS_DOWN_SEC * 0.5)
	var mid := pressed._slot_box(TitleView.SLOT_START)
	t.ok(mid.size.x < resting.size.x - 3.0,
		"절반 시간에 상자가 가로로 3px 넘게 줄었다 (%.1f -> %.1f) — 바닥이다. 눌림이 0이면 여기가 문다"
			% [resting.size.x, mid.size.x])
	t.ok(mid.size.x >= resting.size.x * Look.PRESS_DOWN_SCALE,
		"그래도 %.2f배보다 더 쭈그러들지는 않는다" % Look.PRESS_DOWN_SCALE)
	t.ok(is_equal_approx(mid.get_center().x, resting.get_center().x)
			and is_equal_approx(mid.get_center().y, resting.get_center().y),
		"쭈그러들어도 가운데는 제자리다 — 상자가 왼쪽 위로 미끄러지지 않는다")
	t.ok(Look.PRESS_DOWN_SCALE <= 0.98 and Look.PRESS_DOWN_SCALE >= 0.92,
		"눌림 배율이 0.92~0.98 이다 (%.2f) — 0.98 위는 360px 칸에서 3.6px 이라 안 보인다"
			% Look.PRESS_DOWN_SCALE)
	t.ok(Look.PRESS_DOWN_SEC >= 0.084 and Look.PRESS_DOWN_SEC <= 0.15,
		"눌림이 다섯 프레임과 0.15초 사이다 (%.2f)" % Look.PRESS_DOWN_SEC)
	pressed._fx_step(Look.PRESS_DOWN_SEC * 0.6)
	t.eq(pressed._press_slot, -1, "%.2f초가 지나면 눌린 칸이 스스로 풀린다" % Look.PRESS_DOWN_SEC)
	t.eq(pressed._slot_box(TitleView.SLOT_START), resting,
		"상자가 정확히 쉬는 사각형으로 돌아온다 — 반 px 작은 채로 남지 않는다")
	pressed.free()
	var dipped := TitleView.new()
	dipped.note_press(TitleView.SLOT_START)
	t.ok(dipped._slot_fill(TitleView.SLOT_START).get_luminance()
			< fresh._slot_fill(TitleView.SLOT_START).get_luminance(),
		"누른 칸은 색도 함께 어두워진다")
	dipped.free()
	fresh.free()
	t.ok(Look.PRESS_DOWN_DIM >= 0.10 and Look.PRESS_DOWN_DIM <= 0.30,
		"누름 어두워짐이 0.10~0.30 이다 (%.2f)" % Look.PRESS_DOWN_DIM)



# -- the cells behind ------------------------------------------------------------------------------

func _the_background_is_background(t) -> void:
	# 「배경 알파가 못 누르는 칸보다 어둡다」 — floor: it exists at all; ceiling: it is below the
	# dimmest button, or a drifting cell reads as one more thing to press.
	t.ok(Look.TITLE_TILE_ALPHA >= 0.06, "배경 타일 알파가 0.06 이상이다 (%.2f) — 밑은 배경이 아예 없는 것이다"
		% Look.TITLE_TILE_ALPHA)
	t.ok(Look.TITLE_TILE_ALPHA < Look.PRESS_ALPHA_OFF,
		"그리고 못 누르는 칸(%.2f)보다 어둡다 — 안 그러면 떠다니는 타일가 단추로 읽힌다"
			% Look.PRESS_ALPHA_OFF)
	t.ok(Look.TITLE_TILE_COUNT >= 5 and Look.TITLE_TILE_COUNT <= 16,
		"타일이 5~16개다 (%d) — 5 밑은 점 셋이고 16 위는 무늬다" % Look.TITLE_TILE_COUNT)
	t.ok(Look.TITLE_TILE_HALF_PX >= 8.0 and Look.TITLE_TILE_HALF_PX <= 24.0,
		"타일 반폭이 8~24px 다 (%.0f)" % Look.TITLE_TILE_HALF_PX)

	# 「배경 타일가 실제로 움직이고 화면을 안 벗어난다」 — ⚠ the FLOOR is the half that proves the
	# drift exists. Measured as the TORUS distance, because `fposmod` wraps and a cell that crossed an
	# edge would otherwise read as having jumped the width of the screen.
	var view := TitleView.new()
	var start := []
	for i in Look.TITLE_TILE_COUNT:
		start.append(view._tile_centre(i))
	view._fx_step(2.0)
	var still := 0
	var runaway := 0
	var off := 0
	var reach := Look.TITLE_TILE_SPEED_PX * 2.0
	for i in Look.TITLE_TILE_COUNT:
		var now: Vector2 = view._tile_centre(i)
		var was: Vector2 = start[i]
		var dx: float = absf(now.x - was.x)
		var dy: float = absf(now.y - was.y)
		dx = minf(dx, Look.VIEWPORT_W_PX - dx)
		dy = minf(dy, Look.VIEWPORT_H_PX - dy)
		var moved := Vector2(dx, dy).length()
		if moved < 2.0:
			still += 1
		if moved > reach + 0.001:
			runaway += 1
		if not SCREEN.has_point(now) or not SCREEN.has_point(was):
			off += 1
	t.eq(still, 0, "2초 뒤 타일 %d개가 전부 2px 넘게 움직였다 — 속도가 0이면 여기가 문다"
		% Look.TITLE_TILE_COUNT)
	t.eq(runaway, 0, "그리고 어느 것도 %.0fpx(= 속도 x 2초)보다 멀리 가지 않았다" % reach)
	t.eq(off, 0, "타일 중심이 전부 화면 안이다 — fposmod 가 감싸고 있다")
	t.ok(Look.TITLE_TILE_SPEED_PX >= 3.0 and Look.TITLE_TILE_SPEED_PX <= 20.0,
		"타일 속도가 3~20px/s 다 (%.0f) — 3 밑은 안 움직이는 것과 같고 20 위는 배경이 시끄럽다"
			% Look.TITLE_TILE_SPEED_PX)

	# The long run, because `fposmod` is what keeps them in: a bounce rule would have to be measured
	# too, and a drift that leaks off screen leaks slowly.
	var far := TitleView.new()
	far._fx_step(600.0)
	var escaped := 0
	for i in Look.TITLE_TILE_COUNT:
		if not SCREEN.has_point(far._tile_centre(i)):
			escaped += 1
	t.eq(escaped, 0, "10분을 흘려도 타일이 화면을 못 벗어난다")
	view.free()
	far.free()

	# 「배경 타일가 난수를 안 쓴다」 — two views at the same age agree EXACTLY. A random drift cannot
	# be measured, which is the same reason the shake frequencies are constants.
	var a := TitleView.new()
	var b := TitleView.new()
	a._fx_step(3.7)
	b._fx_step(3.7)
	var drifted := 0
	for i in Look.TITLE_TILE_COUNT:
		if a._tile_centre(i) != b._tile_centre(i):
			drifted += 1
	t.eq(drifted, 0, "같은 나이의 두 타이틀이 타일 %d개 자리가 전부 정확히 같다 — 난수가 없다"
		% Look.TITLE_TILE_COUNT)
	# And they are not all in one place, or "identical" would be trivially true.
	var distinct := {}
	for i in Look.TITLE_TILE_COUNT:
		distinct[a._tile_centre(i).snapped(Vector2(1.0, 1.0))] = true
	t.ok(distinct.size() >= Look.TITLE_TILE_COUNT - 1,
		"그리고 타일 %d개가 서로 다른 자리에 있다 (%d군데) — 한 점에 겹쳐 있으면 위 비교가 공짜다"
			% [Look.TITLE_TILE_COUNT, distinct.size()])
	a.free()
	b.free()


# -- the leaves, treed and pumped ------------------------------------------------------------------

## ⚠ **Argument capture proves a value was computed and handed on; it never proves it was used.** The
## last inch is `net_draw_leaf`'s per-function table, which pins each hook here at exactly one
## `draw_*` call site (`_paint_slot_box` at two) and reddens any function this file grows. What is
## measured here is the other half: that `_draw` reached every hook, with the arguments the layout
## functions computed, in an order that does not bury one under another.
func _the_leaves_draw_what_they_were_handed(t) -> void:
	var spy := TitleSpy.new()
	t.root.add_child(spy)
	# ⚠⚠ **`set_process(false)` DOES NOT HOLD, and this was measured on 4.7.1 rather than assumed.**
	# A `Node2D` whose script defines `_process` has processing switched back ON by the engine on the
	# first frame after it enters the tree — `set_process(false)` right after `add_child` reads back
	# false immediately and TRUE two frames later, and setting it before `add_child` loses the same
	# way. A view frozen that way is aged by a real 6.9 ms delta on every pumped frame, which is
	# exactly the tolerance a timing row cannot absorb. `PROCESS_MODE_DISABLED` holds, and `_draw`
	# still runs under it (both halves measured).
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.queue_redraw()
	await t.pump_frames(2)
	t.ok(spy.draws >= 1, "타이틀의 _draw 가 트리 위에서 진짜 돌았다 (%d프레임)" % spy.draws)

	t.eq(spy.cells.size(), Look.TITLE_TILE_COUNT, "타일을 %d개 그렸다" % Look.TITLE_TILE_COUNT)
	var cell_bad := 0
	for c: Dictionary in spy.cells:
		if not is_equal_approx(float(c["radius"]), Look.TITLE_TILE_HALF_PX):
			cell_bad += 1
		if not is_equal_approx((c["col"] as Color).a, Look.TITLE_TILE_ALPHA):
			cell_bad += 1
		if not SCREEN.has_point(c["centre"]):
			cell_bad += 1
	t.eq(cell_bad, 0, "타일이 전부 look.gd 의 반지름과 알파로, 화면 안에 그려졌다")

	t.eq(spy.titles.size(), 1, "제목을 한 번 그렸다")
	t.eq(str(spy.titles[0]["text"]), TitleView.TITLE_TEXT, "제목 글자가 「%s」다" % TitleView.TITLE_TEXT)
	t.eq(spy.titles[0]["at"], Look.TITLE_TEXT_POS_PX, "제목이 look.gd 가 정한 자리에 갔다")
	t.eq(int(spy.titles[0]["fsize"]), Look.TITLE_FONT_SIZE_PX, "제목 크기가 look.gd 값이다")
	t.ok(spy.titles[0]["face"] != null, "제목이 진짜 글꼴을 받았다")

	t.eq(spy.boxes.size(), 3, "칸 상자를 셋 그렸다")
	t.eq(spy.labels.size(), 3, "칸 글자도 셋 그렸다")
	var box_bad := 0
	var label_bad := 0
	for i in 3:
		if spy.boxes[i]["rect"] != Look.title_slot_rect_px(i):
			box_bad += 1
		if str(spy.labels[i]["text"]) != str(TitleView.SLOT_LABELS[i]):
			label_bad += 1
		if spy.labels[i]["at"] != Look.title_slot_rect_px(i).position + Look.TITLE_SLOT_TEXT_OFFSET_PX:
			label_bad += 1
		if int(spy.labels[i]["fsize"]) != Look.TITLE_SLOT_FONT_SIZE_PX:
			label_bad += 1
		if int(spy.boxes[i]["seq"]) > int(spy.labels[i]["seq"]):
			box_bad += 1
	t.eq(box_bad, 0, "칸 상자 셋이 각자 자리에, 자기 글자보다 먼저 그려졌다 — 상자가 뒤면 글자를 덮는다")
	t.eq(label_bad, 0, "칸 글자 셋이 각자 문구로, look.gd 가 정한 자리에 그려졌다")
	# The layer contract: everything the background is drawn before everything the foreground is.
	var last_cell := 0
	for c: Dictionary in spy.cells:
		last_cell = maxi(last_cell, int(c["seq"]))
	t.ok(last_cell < int(spy.titles[0]["seq"]),
		"타일이 전부 제목보다 먼저다 — 배경이 뒤에 오면 글자를 덮는다")
	t.ok(int(spy.titles[0]["seq"]) < int(spy.boxes[0]["seq"]), "제목이 첫 칸 상자보다 먼저다")

	# The dead slot, as the picture actually receives it: alpha 0 on the border and a dimmed fill.
	# ⚠ A hairline border reads as a faint button rather than as no button, so it is alpha and not
	# width that has to be zero here.
	t.eq((spy.boxes[TitleView.SLOT_SETTINGS]["edge"] as Color).a, 0.0,
		"설정하기 상자는 테두리 알파가 0이다 — 얇은 테두리는 '멀리 있는 단추'로 읽힌다")
	t.ok((spy.boxes[TitleView.SLOT_START]["edge"] as Color).a > 0.0,
		"시작하기 상자는 테두리가 실제로 보인다 (자가 점검)")
	t.eq(float(spy.boxes[TitleView.SLOT_START]["width"]), Look.PRESS_BORDER_WIDTH_PX,
		"안 호버한 칸의 테두리가 기본 굵기다")
	t.ok((spy.boxes[TitleView.SLOT_SETTINGS]["bg"] as Color).a <= Look.PRESS_ALPHA_OFF + Rules.EPS,
		"설정하기 상자 바탕도 흐리게 왔다")
	t.ok((spy.labels[TitleView.SLOT_SETTINGS]["col"] as Color).a
			< (spy.labels[TitleView.SLOT_START]["col"] as Color).a,
		"설정하기 글자도 시작하기 글자보다 흐리다")

	# Now the hover, through the same door the shell uses, and read back off the picture. This is the
	# row that fails if `set_hover` is made a no-op: the width would stay at the resting value.
	spy.set_hover(Look.title_slot_hit_rect_px(TitleView.SLOT_START).get_center())
	spy._fx_step(Look.PRESS_HOVER_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(float(spy.boxes[TitleView.SLOT_START]["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX,
		"호버한 칸의 테두리가 %.0fpx 로 굵어져서 화면까지 갔다" % Look.PRESS_HOVER_BORDER_WIDTH_PX)
	t.eq(float(spy.boxes[TitleView.SLOT_QUIT]["width"]), Look.PRESS_BORDER_WIDTH_PX,
		"그동안 종료 칸은 기본 굵기 그대로다")
	t.eq(float(spy.boxes[TitleView.SLOT_SETTINGS]["width"]), Look.PRESS_BORDER_WIDTH_PX,
		"설정하기의 굵기도 안 변했다 — 알파가 0이라 어차피 안 보이지만, 값 자체가 안 움직인다")

	# And the press, read off the picture: the box shrinks AND the label moves with it. Dipping the
	# box alone walks the glyphs out of it.
	var rest_box: Rect2 = spy.boxes[TitleView.SLOT_START]["rect"]
	var rest_label: Vector2 = spy.labels[TitleView.SLOT_START]["at"]
	spy.note_press(TitleView.SLOT_START)
	spy._fx_step(Look.PRESS_DOWN_SEC * 0.5)
	spy.queue_redraw()
	await t.pump_frames(1)
	var down_box: Rect2 = spy.boxes[TitleView.SLOT_START]["rect"]
	var down_label: Vector2 = spy.labels[TitleView.SLOT_START]["at"]
	t.ok(down_box.size.x < rest_box.size.x - 3.0,
		"누른 칸이 화면에서 실제로 줄었다 (%.1f -> %.1f)" % [rest_box.size.x, down_box.size.x])
	t.ok(down_box.size.x >= rest_box.size.x * Look.PRESS_DOWN_SCALE,
		"그래도 %.2f배 밑으로는 안 줄었다" % Look.PRESS_DOWN_SCALE)
	t.ok(down_label != rest_label,
		"글자도 상자를 따라 움직였다 — 상자만 쭈그러들면 글자가 상자 밖으로 걸어 나간다")
	t.ok(down_box.has_point(down_label),
		"그리고 움직인 글자 자리가 여전히 쭈그러든 상자 안이다")
	t.eq(spy.boxes[TitleView.SLOT_QUIT]["rect"], Look.title_slot_rect_px(TitleView.SLOT_QUIT),
		"안 누른 칸은 그대로다")

	t.root.remove_child(spy)
	spy.queue_free()


## ⚠⚠ **A TEXT SCAN, AND THE LABEL SAYS SO** — this repo has measured five scans being evaded inside
## one feature. It is here because the SHAPE is the whole of what changed and nothing else can see it:
## the spy captures a centre, a half-width and a colour, which a circle and a square hand over
## identically, and `net_draw_leaf` counts `draw_*` calls without recording which one. **One call
## either way, so the count row stayed green through the change.**
##
## Why it is worth a row at all: 2026-08-25, 티켓 23 — the first screen of a beast roguelike was nine
## translucent CIRCLES drifting behind the menu, which is the deleted cell game's own picture. A
## square is this game's ground unit. **If the shape goes back, everything else about this screen
## still measures green.**
func _the_drifting_shape_is_not_a_cell(t) -> void:
	var src := FileAccess.get_file_as_string("res://src/view/title_view.gd")
	t.ok(src.length() > 0, "타이틀 파일을 실제로 읽었다 (자가 점검)")
	var body := _func_body(src, "_paint_tile")
	t.ok(body.length() > 0, "_paint_tile 의 본문을 찾았다 (자가 점검 — 못 찾으면 아래가 공허하다)")
	t.ok(body.contains("draw_rect"), "떠다니는 배경이 네모다 — draw_rect 로 그린다")
	t.ok(not body.contains("draw_circle"), "그리고 원이 아니다 — 원은 죽은 세포 게임의 그림이다")

	# ⚠ **Inverting the INSTRUMENT.** A body-finder that returned nothing would pass both rows above
	# forever, so it is handed a body it must read and one it must not confuse with its neighbour.
	var fake := "func _paint_tile(a, b, c) -> void:
	draw_circle(a, b, c)


func _other() -> void:
	draw_rect(a)
"
	t.ok(_func_body(fake, "_paint_tile").contains("draw_circle"),
		"훑개가 원으로 그린 본문을 실제로 잡는다 (계측기 자가 점검)")
	t.ok(not _func_body(fake, "_paint_tile").contains("draw_rect"),
		"그리고 다음 함수의 본문을 안 섞는다 (계측기 자가 점검)")


## One function's body out of a source file: from its `func` line to the next line that starts a new
## top-level `func`. Comments are not stripped — the two rows above ask about CALLS, and a `draw_rect`
## written in a comment inside this one function would be a lie worth reddening on.
func _func_body(src: String, name: String) -> String:
	var lines := src.split("
")
	var out := ""
	var inside := false
	for raw: String in lines:
		if raw.begins_with("func "):
			if inside:
				break
			inside = raw.begins_with("func %s(" % name)
			continue
		if inside:
			out += raw + "
"
	return out
