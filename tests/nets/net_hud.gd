extends RefCounted
## The live bank, swarm size and carried total — the three numbers the HUD shows during PLAY.
##
## It was measured by nothing: printing the bank as a literal `0` was green, because no net loaded `Hud`
## at all. A HUD that lies is worse than no HUD.
##
## `draw_string` is native and cannot be overridden, so `Hud` routes every readout through `_paint_text`
## and this net captures the strings that went to it.
##
## **The end-of-run panel (`_paint_result`) is gone from `hud.gd`** — the run shell plan replaced it with
## `EndingScreen`, whose own net (`net_screens.gd`) is where those four numbers are checked now.
##
## **The key legend is not asserted here.** It is one string with one owner, and `net_hands` — which owns
## every key it names — is where it is read back off `_paint_text`. Two files asserting one string is the
## second copy that diverges. ⚠ **Its POSITION and its 12-second life are asserted here** — those are not
## the string, they are the layout, and this file owns the layout.
##
## ⇒ **The level bar was measured by nothing at all.** `_bar_shown`, `BAR_FILL` and `level_progress` had
## **two** hits in the whole of `tests/`, both asserting `level_progress()` as a pure function and neither
## connected to a rectangle. Green: both `_paint_rect` calls deleted, the fill drawn at zero width, the
## chase deleted so the gauge never moves, the HP readout laid out at `y = 0` on top of the bank number.
## `hud.gd`'s own header names the stake — *"a dozen clones being swallowed in a row and the gauge lurching
## forward; if that does not read on screen, the harvest is invisible."* So the spy below captures
## `_paint_rect` and every `_paint_text` argument, not only the text.


class Spy extends Hud:
	var lines: Array[String] = []
	## Every `_paint_text` argument, so a readout laid out at the wrong place is visible headless. The
	## string alone cannot see a line piled on top of another one.
	var texts: Array = []
	## Every rectangle: the bar's groove, the bar's fill, and the map's three.
	var rects: Array = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		lines.append(text)
		texts.append({"p": p, "text": text, "size": font_size, "col": col})
		super._paint_text(c, p, text, font_size, col)

	func _paint_rect(c: CanvasItem, r: Rect2, col: Color) -> void:
		rects.append({"r": r, "col": col})
		super._paint_rect(c, r, col)

	func forget() -> void:
		lines.clear()
		texts.clear()
		rects.clear()


func run(t) -> void:
	await _numbers(t)
	await _u3_the_level_bar(t)
	await _u3b_where_every_readout_lands(t)


func _numbers(t) -> void:
	var w := World.new()
	w.setup(77)
	_silence(w)
	# A run opens with the host alone, so the swarm below is entirely this check's own. Nothing has to be
	# cut back first — that line existed while `START_CLONES` did.
	for i in 5:
		var k := w.swarm.add_clone()
		w.swarm.carried[k] = float(i)
	w.swarm.banked = 137.0

	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	spy.forget()
	await t.pump_frames(1)

	t.ok(_has(spy.lines, "137"), "은행 숫자가 화면에 그대로 나온다 %s" % str(spy.lines))
	t.ok(_has(spy.lines, "무리 5"), "무리 수가 나온다")
	t.ok(_has(spy.lines, "지고 있는 것 10"), "무리가 지고 있는 것의 합(0+1+2+3+4)이 나온다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- U3: the level bar is a rectangle whose WIDTH is the harvest -----------------------------------------
## ⚠ **Every literal here is hand-written from `hud.gd`'s layout, never read back off it.** 24 is the
## bar's left inset, 48 the pair of insets, 22 its top and 14 its height. A width taken from the rect
## under test is the bound-off-the-subject trap: shrink the bar and the expectation shrinks with it.
##
## *Mutations this must redden:* the fill's width term → `0.0`; either `_paint_rect` call deleted; the
## `lerpf` in `_process` replaced by a plain assignment of the old value (the gauge never moves); the fill
## drawn in `BAR_BG` so the two halves are indistinguishable.
func _u3_the_level_bar(t) -> void:
	var w := World.new()
	w.setup(78)
	_silence(w)
	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)

	var screen: Vector2 = spy.get_viewport_rect().size
	t.eq(spy.size, screen, "설정: HUD는 뷰포트 크기로 펼쳐져 있다 — 0×0이 아니다 (%s)" % str(spy.size))
	var wide := screen.x - 48.0

	# (a) A fresh run. The groove is full width; the fill is EMPTY and is still a rectangle at the same
	# place, so "deleted" and "empty" are two different failures.
	w.swarm.banked = 0.0
	spy._bar_shown = 0.0
	spy.forget()
	await t.pump_frames(1)
	t.eq(_rect_of(spy, Look.HUD_BAR_BG), Rect2(24.0, 22.0, wide, 14.0),
			"빈 홈은 화면 폭에서 좌우 24씩 뺀 만큼이다 (24, 22, %.1f, 14)" % wide)
	t.eq(_rect_of(spy, Look.HUD_BAR_FILL), Rect2(24.0, 22.0, 0.0, 14.0),
			"아무것도 안 먹었으면 채움은 폭 0이다 — 그래도 그려지긴 한다")
	t.eq(_count_of(spy, Look.HUD_BAR_BG), 1, "홈은 한 장이다")
	t.eq(_count_of(spy, Look.HUD_BAR_FILL), 1, "채움도 한 장이다")

	# (b) A quarter of the way to level 1. `LEVEL_COST_BASE` is 10.0 and nothing has been paid, so 2.5
	# banked is 0.25 — asserted as a literal here so the bar and the sim are pinned to the same number.
	w.swarm.banked = 2.5
	t.eq(w.level_progress(), 0.25, "설정: 은행 2.5는 첫 레벨 비용 10.0의 1/4이다 (리터럴)")
	# The gauge is placed on its own target, so the engine's own `_process` between here and the frame
	# below lerps 0.25 toward 0.25 and leaves it exactly there. That is what makes an EQUALITY possible.
	spy._bar_shown = 0.25
	spy.forget()
	await t.pump_frames(1)
	t.eq(_rect_of(spy, Look.HUD_BAR_FILL), Rect2(24.0, 22.0, wide * 0.25, 14.0),
			"1/4 찼으면 채움도 홈의 1/4이다 (%.2f)" % (wide * 0.25))
	t.eq(_rect_of(spy, Look.HUD_BAR_BG), Rect2(24.0, 22.0, wide, 14.0), "홈은 그대로 꽉 차 있다")
	t.ok(_rect_of(spy, Look.HUD_BAR_FILL).end.x < _rect_of(spy, Look.HUD_BAR_BG).end.x,
			"그래서 채움은 홈보다 짧다 — 둘이 같은 사각형이면 게이지가 아니다")

	# (c) **The chase, driven by hand.** `_process` is called with a chosen delta rather than pumped,
	# because a pumped headless frame's delta is whatever the machine felt like and the smoothing is a
	# function of it. One 60fps step must move the gauge a LITTLE — neither snapping to the target nor
	# standing still is what the surge is.
	w.swarm.banked = 5.0
	t.eq(w.level_progress(), 0.5, "설정: 은행 5.0이면 절반이다 (리터럴)")
	spy._bar_shown = 0.0
	spy._process(1.0 / 60.0)
	t.ok(spy._bar_shown > 0.02 and spy._bar_shown < 0.15,
			"한 프레임은 게이지를 조금만 민다 — 붙지도 멈추지도 않는다 (%.4f)" % spy._bar_shown)
	# Two half-second steps put it within 0.1% of the target; the drawn width is what is asserted, so the
	# chase is tied to the rectangle and not only to the variable.
	spy._process(0.5)
	spy._process(0.5)
	spy.forget()
	await t.pump_frames(1)
	var fill: Rect2 = _rect_of(spy, Look.HUD_BAR_FILL)
	t.ok(absf(fill.size.x - wide * 0.5) < wide * 0.01,
			"쫓아간 뒤에는 채움이 홈의 절반이 된다 (%.2f, 기대 %.2f)" % [fill.size.x, wide * 0.5])
	t.eq(fill.position, Vector2(24.0, 22.0), "채움은 언제나 홈의 왼쪽 끝에서 자란다")
	t.eq(fill.size.y, 14.0, "높이는 홈과 같다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- U3b: where every readout lands ---------------------------------------------------------------------
## `set_anchors_preset` leaves the offsets alone, so a `Control` on a bare `CanvasLayer` sits at
## `size == (0, 0)` and every line in this file piles into the top-left corner — that defect already
## shipped once on this build. The strings were asserted; **their positions were not**, so the HP readout
## could be drawn at `y = 0` straight through the bank number with the whole round green.
##
## *Mutations this must redden:* any of the four `Vector2(...)` arguments in `_paint`; `size.y - 28.0` →
## `28.0`; the `world.elapsed < 12.0` guard → `if true:`.
func _u3b_where_every_readout_lands(t) -> void:
	var w := World.new()
	w.setup(79)
	_silence(w)
	w.swarm.banked = 137.0
	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	var screen: Vector2 = spy.get_viewport_rect().size
	spy.forget()
	await t.pump_frames(1)

	t.eq(_text_p(spy, "137"), Vector2(24.0, 84.0), "은행 숫자는 (24, 84)에 앉는다")
	t.eq(_text_size(spy, "137"), 44, "그리고 가장 큰 글씨다 — 44")
	t.eq(_text_p(spy, "무리 0"), Vector2(24.0, 112.0), "무리 줄은 은행 아래 (24, 112)다")
	t.eq(_text_size(spy, "무리 0"), 20, "무리 줄은 20이다 — 은행보다 작다")
	t.eq(_text_p(spy, "30/30"), Vector2(34.0, screen.y - 28.0),
			"체력은 화면 바닥에서 28 위, 왼쪽에서 34다 — 은행 위에 겹치지 않는다")
	t.eq(_text_size(spy, "30/30"), 26, "체력은 26이다")
	t.eq(_text_p(spy, "WASD"), Vector2(24.0, screen.y - 68.0),
			"안내줄은 체력보다 한 줄 더 위, 바닥에서 68이다")

	# Every one of them inside the screen, and none of them on top of another. The four y values are
	# distinct by construction, which is exactly what a zero-sized Control destroys.
	for e: Dictionary in spy.texts:
		var p: Vector2 = e["p"]
		t.ok(p.x >= 0.0 and p.x < screen.x and p.y >= 0.0 and p.y < screen.y,
				"「%s」은 화면 안에 떨어진다 (%s)" % [String(e["text"]).substr(0, 12), str(p)])

	# **The legend has a clock and nothing measured it.** 12 seconds is a literal in `hud.gd`; without a
	# check the guard could read `if true` and the only instruction in the game would never leave.
	w.elapsed = 12.0
	spy.forget()
	await t.pump_frames(1)
	t.eq(_text_p(spy, "WASD"), Vector2.INF, "12초가 지나면 안내줄은 사라진다")
	t.ok(_text_p(spy, "137") != Vector2.INF, "대조: 은행 숫자는 그대로 남아 있다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- helpers ---------------------------------------------------------------------------------------------
func _has(lines: Array[String], needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false


## The rectangle drawn in `col`. `Rect2()` when there is none, which no real rectangle in this file equals
## — so "deleted" fails against a hand-written expectation rather than passing as a zero-width one.
func _rect_of(spy, col: Color) -> Rect2:
	for e: Dictionary in spy.rects:
		if e["col"] == col:
			return e["r"]
	return Rect2()


func _count_of(spy, col: Color) -> int:
	var n := 0
	for e: Dictionary in spy.rects:
		if e["col"] == col:
			n += 1
	return n


## `Vector2.INF` when the line is not on screen at all, so absence is a value a check can assert.
func _text_p(spy, needle: String) -> Vector2:
	for e: Dictionary in spy.texts:
		if String(e["text"]).contains(needle):
			return e["p"]
	return Vector2.INF


func _text_size(spy, needle: String) -> int:
	for e: Dictionary in spy.texts:
		if String(e["text"]).contains(needle):
			return int(e["size"])
	return -1


func _silence(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
