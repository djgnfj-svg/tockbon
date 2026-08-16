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
	## §D-2's edge arrow, one per frame it is shown.
	var tris: Array = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		lines.append(text)
		texts.append({"p": p, "text": text, "size": font_size, "col": col})
		super._paint_text(c, p, text, font_size, col)

	func _paint_rect(c: CanvasItem, r: Rect2, col: Color) -> void:
		rects.append({"r": r, "col": col})
		super._paint_rect(c, r, col)

	func _paint_tri(c: CanvasItem, p: Vector2, dir: Vector2, size_px: float, col: Color) -> void:
		tris.append({"p": p, "dir": dir, "size_px": size_px, "col": col})
		super._paint_tri(c, p, dir, size_px, col)

	func forget() -> void:
		lines.clear()
		texts.clear()
		rects.clear()
		tris.clear()


func run(t) -> void:
	await _numbers(t)
	await _u3_the_level_bar(t)
	await _u3b_where_every_readout_lands(t)
	await _b2_hurt_vignette(t)
	await _d1_hunt_wash_and_text(t)
	await _d2_boss_arrow(t)
	await _f9_the_level_kick_and_the_phrase(t)


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


# -- B-2: the hurt vignette — four edge bands, alpha follows host_grace / HOST_HIT_GRACE -------------------
## `host_grace` already counts DOWN from `Rules.HOST_HIT_GRACE` for `HOST_HURT_COLOR`'s own window, so this
## drives that one field by hand rather than a real hit — the same idiom the level bar's own check uses for
## `world.level`.
func _b2_hurt_vignette(t) -> void:
	var w := World.new()
	w.setup(151)
	_silence(w)
	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	var screen: Vector2 = spy.get_viewport_rect().size

	# 부정 대조: 아직 안 맞았으면 번짐이 없다.
	w.host_grace = 0.0
	spy.forget()
	await t.pump_frames(1)
	t.eq(_vignette_rects(spy).size(), 0, "설정: 안 맞았으면 가장자리 번짐이 하나도 안 그려진다")

	# 방금 맞았다 — 무적 그대로, 알파는 상수 그대로다.
	w.host_grace = Rules.HOST_HIT_GRACE
	spy.forget()
	await t.pump_frames(1)
	var rects := _vignette_rects(spy)
	t.eq(rects.size(), 4, "네 변 전부 번짐이 그려진다 %s" % str(rects))
	for e: Dictionary in rects:
		var col: Color = e["col"]
		t.ok(absf(col.a - Look.HURT_VIGNETTE.a) < 0.01,
				"맞은 직후 알파는 상수 그대로다 (%.3f / %.3f)" % [col.a, Look.HURT_VIGNETTE.a])

	var top := false
	var bottom := false
	var left := false
	var right := false
	for e: Dictionary in rects:
		var r: Rect2 = e["r"]
		if absf(r.position.y) < 0.5 and absf(r.size.x - screen.x) < 0.5 \
				and absf(r.size.y - Look.HURT_VIGNETTE_WIDTH) < 0.5:
			top = true
		if absf(r.position.y - (screen.y - Look.HURT_VIGNETTE_WIDTH)) < 0.5 \
				and absf(r.size.x - screen.x) < 0.5:
			bottom = true
		if absf(r.position.x) < 0.5 and absf(r.size.y - screen.y) < 0.5 \
				and absf(r.size.x - Look.HURT_VIGNETTE_WIDTH) < 0.5:
			left = true
		if absf(r.position.x - (screen.x - Look.HURT_VIGNETTE_WIDTH)) < 0.5 \
				and absf(r.size.y - screen.y) < 0.5:
			right = true
	t.ok(top and bottom and left and right,
			"위·아래·왼쪽·오른쪽 네 변에 각각 하나씩이다 %s" % str(rects))

	# 절반 남았으면 알파도 절반이다 — 값이 바뀌면 그림도 바뀐다는 것이 이 검사의 핵심이다.
	w.host_grace = Rules.HOST_HIT_GRACE * 0.5
	spy.forget()
	await t.pump_frames(1)
	var half_rects := _vignette_rects(spy)
	t.eq(half_rects.size(), 4, "절반 남았어도 네 변 다 그려진다")
	for e: Dictionary in half_rects:
		var col: Color = e["col"]
		t.ok(absf(col.a - Look.HURT_VIGNETTE.a * 0.5) < 0.02,
				"절반 남았으면 알파도 절반이다 (%.3f / %.3f)" % [col.a, Look.HURT_VIGNETTE.a * 0.5])
	t.ok(float(half_rects[0]["col"].a) < float(rects[0]["col"].a),
			"그리고 절반의 알파는 방금 맞았을 때보다 확실히 옅다")

	t.root.remove_child(spy)
	spy.queue_free()


## Rectangles whose colour matches `Look.HURT_VIGNETTE`'s RGB — the alpha varies with `host_grace`, so only
## the RGB half of the match is fixed.
func _vignette_rects(spy) -> Array:
	var out := []
	for e: Dictionary in spy.rects:
		var col: Color = e["col"]
		if absf(col.r - Look.HURT_VIGNETTE.r) < 0.001 and absf(col.g - Look.HURT_VIGNETTE.g) < 0.001 \
				and absf(col.b - Look.HURT_VIGNETTE.b) < 0.001:
			out.append(e)
	return out


# -- D1: the full-screen wash and the announcement line --------------------------------------------------
## `_rect_of`/`_count_of` match a rectangle's colour EXACTLY, which the wash's own fading alpha would fail —
## so this file keeps a second matcher on RGB alone, the same shape `_vignette_rects` already uses for B-2.
func _d1_hunt_wash_and_text(t) -> void:
	var w := World.new()
	w.setup(124)
	_silence(w)

	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)
	var screen: Vector2 = spy.get_viewport_rect().size

	# Before the hunt: neither the wash nor the line.
	spy.forget()
	await t.pump_frames(1)
	t.eq(_wash_rects(spy).size(), 0, "사냥이 시작되기 전엔 화면 번짐이 없다")
	t.ok(not _has(spy.lines, "그것이 온다"), "사냥이 시작되기 전엔 문구도 없다")

	# The instant it starts: one rectangle covering the whole screen, at the constant's own alpha, and the
	# line drawn centred both ways.
	w.elapsed = Rules.BOSS_HUNT_AT
	spy.forget()
	await t.pump_frames(1)
	var washed := _wash_rects(spy)
	t.eq(washed.size(), 1, "번지는 순간엔 사각형이 한 장 그려진다 %s" % str(washed))
	var start_a := 0.0
	if washed.size() == 1:
		var e: Dictionary = washed[0]
		t.eq(e["r"], Rect2(Vector2.ZERO, screen), "그리고 화면 전체를 덮는다")
		start_a = float(e["col"].a)
		t.ok(absf(start_a - Look.BOSS_HUNT_FLASH.a) < 0.01,
				"막 시작한 순간의 알파는 상수 그대로다 (%.3f)" % start_a)
	t.ok(_has(spy.lines, "그것이 온다"), "그리고 문구가 실제로 그려진다 %s" % str(spy.lines))
	var p := _text_p(spy, "그것이 온다")
	t.ok(p != Vector2.INF, "설정: 그 줄을 찾았다")
	if p != Vector2.INF:
		var font := spy.get_theme_default_font()
		var sz := font.get_string_size("그것이 온다", HORIZONTAL_ALIGNMENT_LEFT, -1, Look.FONT_BOSS_HUNT_TEXT)
		t.ok(absf((p.x + sz.x * 0.5) - screen.x * 0.5) < 0.5,
				"문구는 가로로 화면 가운데 놓인다 (%.2f)" % (p.x + sz.x * 0.5))
		t.ok(absf((p.y + sz.y * 0.5) - screen.y * 0.5) < 0.5,
				"그리고 세로로도 가운데다 (%.2f)" % (p.y + sz.y * 0.5))

	# Half of BOSS_HUNT_FLASH_TIME later: still there, but fainter — it FADES, it does not snap off.
	w.elapsed = Rules.BOSS_HUNT_AT + Look.BOSS_HUNT_FLASH_TIME * 0.5
	spy.forget()
	await t.pump_frames(1)
	var mid := _wash_rects(spy)
	t.eq(mid.size(), 1, "절반 지점에도 번짐은 아직 그려진다")
	if mid.size() == 1:
		t.ok(float(mid[0]["col"].a) < start_a,
				"그리고 그 알파는 시작보다 옅다 — 덮어씌운 채 서 있는 것이 아니다 (%.3f < %.3f)"
						% [float(mid[0]["col"].a), start_a])

	# Past BOSS_HUNT_FLASH_TIME: the wash is gone, but the line is still up — the two clocks are different.
	w.elapsed = Rules.BOSS_HUNT_AT + Look.BOSS_HUNT_FLASH_TIME + 0.01
	spy.forget()
	await t.pump_frames(1)
	t.eq(_wash_rects(spy).size(), 0, "번짐 시간이 지나면 사각형은 사라진다")
	t.ok(_has(spy.lines, "그것이 온다"), "그래도 문구는 아직 남아 있다 — 번짐보다 오래 간다")

	# Past BOSS_HUNT_TEXT_TIME: the line is gone too.
	w.elapsed = Rules.BOSS_HUNT_AT + Look.BOSS_HUNT_TEXT_TIME + 0.01
	spy.forget()
	await t.pump_frames(1)
	t.ok(not _has(spy.lines, "그것이 온다"), "문구도 결국 사라진다")

	t.root.remove_child(spy)
	spy.queue_free()


## Rectangles whose colour matches `Look.BOSS_HUNT_FLASH`'s RGB — the alpha fades, so only the RGB half of
## the match is fixed. The same shape `_vignette_rects` uses for B-2's vignette.
func _wash_rects(spy) -> Array:
	var out := []
	for e: Dictionary in spy.rects:
		var col: Color = e["col"]
		if absf(col.r - Look.BOSS_HUNT_FLASH.r) < 0.001 and absf(col.g - Look.BOSS_HUNT_FLASH.g) < 0.001 \
				and absf(col.b - Look.BOSS_HUNT_FLASH.b) < 0.001:
			out.append(e)
	return out


# -- D2: the edge arrow — only while the boss is off camera, and only once the hunt is on ------------------
func _d2_boss_arrow(t) -> void:
	var w := World.new()
	w.setup(123)
	_silence(w)
	w.critter_count = 0
	w.boss_index = -1
	var host: Vector2 = w.swarm.pos[0]
	var b := w._write_critter(Parts.Species.BOSS, host + Vector2(5000.0, 0.0), 120)
	w.boss_index = b

	var spy := Spy.new()
	spy.world = w
	# A modest camera box centred on the host — the boss, 5000px east, is well outside it.
	spy.camera_rect = Rect2(host - Vector2(640.0, 360.0), Vector2(1280.0, 720.0))
	t.root.add_child(spy)
	await t.pump_frames(2)

	# Before the hunt: nothing, even though the boss is off camera the whole time.
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.tris.size(), 0, "사냥이 시작되기 전엔 보스가 화면 밖이어도 화살표가 없다")

	# `World.boss_hunting()` is derived from `elapsed`, not latched — so this is the whole of "the hunt
	# started", and there is no second flag that could disagree with it.
	w.elapsed = Rules.BOSS_HUNT_AT
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.tris.size(), 1,
			"사냥이 시작되고 보스가 화면 밖이면 화살표가 하나 그려진다 %s" % str(spy.tris))
	if spy.tris.size() == 1:
		var a: Dictionary = spy.tris[0]
		var dir: Vector2 = a["dir"]
		t.ok(dir.x > 0.9, "보스는 동쪽에 있고 화살표도 동쪽을 가리킨다 (%s)" % str(dir))
		# ⚠ **`size_px`, and it is the one argument this check never read.** `Look.BOSS_ARROW_SIZE` → 0
		# collapses the triangle to three coincident points — nothing on screen — while `p`, `dir` and `col`
		# all stay exactly right and the leaf's own `draw_` count stays at 1. The literal 14.0 is written out
		# rather than compared symbolically, or zeroing the constant moves both sides at once.
		t.ok(absf(float(a["size_px"]) - 14.0) < 0.001,
				"화살표의 크기는 Look.BOSS_ARROW_SIZE(14px)다 — 0이면 삼각형은 넓이가 없다 (%.2f)"
						% float(a["size_px"]))
		t.ok(absf(Look.BOSS_ARROW_SIZE - 14.0) < 0.001, "설정: 그 상수 자체도 14.0이다")
		var p: Vector2 = a["p"]
		t.ok(p.x > spy.size.x * 0.5, "화살표는 화면 오른쪽 절반에 찍힌다 (%.1f)" % p.x)
		t.ok(p.x <= spy.size.x - 0.01 and p.y >= 0.0 and p.y <= spy.size.y,
				"그리고 화면 안쪽이다 — 가장자리 밖으로 새지 않는다 (%s)" % str(p))

	# The boss inside the camera box: no arrow, even with the hunt already on.
	w.critter_pos[b] = host
	spy.forget()
	await t.pump_frames(1)
	t.eq(spy.tris.size(), 0, "대조: 보스가 화면 안에 들어오면 화살표는 사라진다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- F-9: the level's own kick on the bar, and the phrase --------------------------------------------------
## **Both halves of §F-9's HUD side reached the screen through zero checks.** `if world.level_show <
## Look.LEVEL_BAR_FLASH_TIME:` → `if false and ...` and the same for the phrase were each green at 2327:
## `net_force` proves `World.level_show` is a correct sim clock and `net_paint` proves the HOST pop reads
## it, and nothing anywhere drove that clock against `hud.gd`. §F-9's own note is that a level with no cards
## is normal, so for most levels this bar kick and this phrase are the ONLY thing that says one happened.
##
## The two windows are different lengths on purpose (0.35 vs 1.2), so the middle sample below — flash gone,
## phrase still up — is what tells them apart from one shared timer.
func _f9_the_level_kick_and_the_phrase(t) -> void:
	var w := World.new()
	w.setup(126)
	_silence(w)

	var spy := Spy.new()
	spy.world = w
	t.root.add_child(spy)
	await t.pump_frames(2)

	# A run that has never levelled: `level_show` opens at `INF`.
	spy.forget()
	await t.pump_frames(1)
	t.eq(_flash_rects(spy).size(), 0, "아직 레벨이 없었으면 바에 번쩍임이 없다")
	t.ok(not _has(spy.lines, "레벨업!"), "그리고 문구도 없다")

	# The instant a level fires.
	w.level_show = 0.0
	spy.forget()
	await t.pump_frames(1)
	var flashes := _flash_rects(spy)
	t.eq(flashes.size(), 1, "레벨이 터진 프레임엔 홈 위에 번쩍임이 한 장 그려진다 %s" % str(flashes))
	var full_a := 0.0
	if flashes.size() == 1:
		var f: Dictionary = flashes[0]
		var groove := Rect2(Look.HUD_BAR_AT, Vector2(spy.size.x - Look.HUD_BAR_INSETS, Look.HUD_BAR_HEIGHT))
		t.ok((f["r"] as Rect2).position.distance_to(groove.position) < 0.01
						and (f["r"] as Rect2).size.distance_to(groove.size) < 0.01,
				"그 번쩍임은 게이지 홈 전체를 덮는다 — 채워진 만큼이 아니라 (%s / 홈 %s)"
						% [str(f["r"]), str(groove)])
		full_a = (f["col"] as Color).a
		t.ok(absf(full_a - 0.6) < 0.001,
				"터진 순간의 알파는 LEVEL_BAR_FLASH_COLOR의 0.6 그대로다 (%.3f)" % full_a)
	t.ok(_has(spy.lines, "레벨업!"), "그리고 「레벨업!」 문구가 뜬다 %s" % str(spy.lines))
	t.eq(_text_p(spy, "레벨업!"), Look.LEVEL_TEXT_AT, "문구는 LEVEL_TEXT_AT 자리에 찍힌다")
	t.eq(_text_size(spy, "레벨업!"), Look.FONT_LEVEL_TEXT, "그리고 FONT_LEVEL_TEXT 크기다")

	# Halfway through the flash: still there, and dimmer — a window that never fades is a state, not a kick.
	w.level_show = Look.LEVEL_BAR_FLASH_TIME * 0.5
	spy.forget()
	await t.pump_frames(1)
	var half := _flash_rects(spy)
	t.eq(half.size(), 1, "번쩍임의 절반 시점에도 아직 한 장이다")
	if half.size() == 1 and full_a > 0.0:
		var half_a: float = (half[0]["col"] as Color).a
		t.ok(absf(half_a - full_a * 0.5) < 0.01,
				"그 알파는 정확히 절반이다 — 켜졌다 꺼지는 것이 아니라 사그라든다 (%.3f / %.3f)"
						% [half_a, full_a])

	# **Past the flash, inside the phrase.** 0.35 and 1.2 are different numbers and this is what says so.
	w.level_show = Look.LEVEL_BAR_FLASH_TIME + 0.01
	spy.forget()
	await t.pump_frames(1)
	t.eq(_flash_rects(spy).size(), 0, "LEVEL_BAR_FLASH_TIME이 지나면 번쩍임은 사라진다")
	t.ok(_has(spy.lines, "레벨업!"), "그래도 문구는 아직 있다 — 둘은 서로 다른 시계를 산다")

	# Past both.
	w.level_show = Look.LEVEL_TEXT_TIME + 0.01
	spy.forget()
	await t.pump_frames(1)
	t.eq(_flash_rects(spy).size(), 0, "부정 대조: 더 지나면 번쩍임도 없고")
	t.ok(not _has(spy.lines, "레벨업!"), "문구도 사라진다")

	t.root.remove_child(spy)
	spy.queue_free()


## The bar's level flash, matched on RGB alone — its alpha fades from the very first frame, so an exact
## `Color ==` against `Look.LEVEL_BAR_FLASH_COLOR` would only ever match at `level_show == 0`. Nothing else
## this `Control` draws is white: the groove is dark, the fill is the host's yellow, and the map's three
## rectangles are black, a warm grey and the same yellow.
func _flash_rects(spy) -> Array:
	var out := []
	for e: Dictionary in spy.rects:
		var col: Color = e["col"]
		if col.r > 0.99 and col.g > 0.99 and col.b > 0.99:
			out.append(e)
	return out
