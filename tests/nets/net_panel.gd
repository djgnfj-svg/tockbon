extends RefCounted
## **The picked body's panel — the screen half of 03-02** (2026-09-02, the user: 「캐릭터 누르면 선택되고
## 정보ㄴ뜨고 이동되는게 필요할듯」 · 「화면 구석 판으로」 · 「고른 수랑 첫 몸으로」).
##
## The claim under test: **while the hand holds somebody, `HudView` paints one plate and exactly four
## lines — 이름 · 특성 · 체력 · 허기 — about the FIRST body held, with 「x N」 on the name when the hand
## holds more, the 체력 read live off the fight; and while the hand holds nobody it paints nothing.**
##
## ⚠⚠ **MEASURED AT THE HOOKS, TREED, WITH PUMPED FRAMES** — the shape `how-nets-lie` prescribes for
## exactly this ticket: a `_draw()` that ran is not a thing drawn, so a `PanelSpy` overrides the two
## `_paint_*` leaves and records their arguments; the spy cannot see the `draw_*` inside a leaf, so
## `net_draw_leaf` pins each leaf's count; a pure layout function asserted on its own proves nothing
## about `_draw`, so **every origin and baseline is read off the hook and compared to `Look`'s answer**;
## and a panel that laid itself out from a zero size would pile into the top-left, so **every point is
## asserted inside the viewport and inside the plate**.
##
## ⚠ **The labels are typed here as literals on purpose** — 「이름 특성 체력 허기」 is what the user
## decided, and a net that read them back off `Look.PANEL_LABELS` would be green for any four words.
##
## ⚠ **The sim half — `Names.LIST` and `Army.names` — is measured in its own net.** This file reads
## `army.name_of` only to say what the panel must print.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.


## Records what the two panel leaves are handed, per frame. `_draw` clears first, so what is read
## after a pumped frame is that frame's picture and never the last one's.
class PanelSpy extends HudView:
	var panels := []
	var lines := []
	var draws := 0

	func _draw() -> void:
		panels.clear()
		lines.clear()
		super()
		draws += 1

	func _paint_panel(tex: Texture2D, at: Vector2) -> void:
		panels.append({"tex": tex, "at": at})

	func _paint_line(text: String, at: Vector2, font: Font, size_px: int, col: Color) -> void:
		lines.append({"text": text, "at": at, "font": font, "size_px": size_px, "col": col})


## **All land, landlocked, flat** — nothing here is about the board, so the board must not be able to
## refuse a body a place to stand. Nine bodies stood on one 조각 spread into the 칸 and past it, and
## every one of them has to be ASHORE for `Hand.pick_many` to keep it.
const FIELD := [
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
]
const HOME_TX := 1
const HOME_TY := 1

## Nine picked is the number the ticket names (「Nine picked shows 「9」」). ⚠ **Net-only** — the
## running game holds four bodies and nothing recruits; the user saw that and said 「ㅇㅇ 이대로 가자」.
const NINE := 9


func run(t) -> void:
	await _nothing_picked_paints_nothing(t)
	await _one_picked_paints_the_plate_and_four_lines(t)
	await _nine_picked_names_the_first_and_counts_nine(t)
	await _the_hp_line_follows_the_fight(t)
	await _a_new_island_drops_the_pick(t)
	_the_plate_and_the_font_are_what_look_says(t)
	await _the_shell_hands_the_hand_to_the_panel(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the panel, driven at the view seam ==============================================================

## Bound, nothing picked, a frame turned: no leaf is called. **The floor of the whole net** — a
## `_draw` that painted the plate unconditionally would pass every row below and fail this one.
func _nothing_picked_paints_nothing(t) -> void:
	var b := _battle(1)
	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(b)
	spy.set_picked(PackedInt32Array())
	await t.pump_frames(1)
	t.ok(spy.draws >= 1, "자가 점검 — 틀에 붙은 뷰가 한 프레임에 그리기를 돌았다")
	t.eq(spy.panels.size(), 0, "아무도 안 골랐으면 판이 안 그려진다")
	t.eq(spy.lines.size(), 0, "그리고 글줄도 한 줄 안 그려진다")
	_let_go(spy)


## One body picked: one plate, four lines, in the order 이름 · 특성 · 체력 · 허기, every value read
## off the sim and not off a literal. **Both bounds** — exactly four, never three (a dropped 허기 line)
## and never five (a line typed in beside them).
func _one_picked_paints_the_plate_and_four_lines(t) -> void:
	var b := _battle(1)
	var id := _stand_at_home(b, 1)[0]
	var hand := Hand.new()
	t.ok(hand.pick(b, id), "자가 점검 — 손이 몸 하나를 쥐었다")
	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(b)
	spy.set_picked(hand.ids)
	await t.pump_frames(1)

	t.eq(spy.panels.size(), 1, "몸 하나를 고르면 판이 정확히 한 번 그려진다")
	t.eq(spy.lines.size(), 4, "그리고 글줄이 정확히 넉 줄이다 — 이름 · 특성 · 체력 · 허기")
	if spy.lines.size() == 4:
		var who: String = b.army.name_of(id)
		t.ok(who != "", "자가 점검 — 그 몸에 이름이 붙어 있다")
		t.eq(str(spy.lines[0]["text"]), "이름 " + who,
			"첫 줄이 「이름 」 뒤에 그 몸의 이름이다 (%s)" % who)
		t.eq(str(spy.lines[1]["text"]), "특성 ", "둘째 줄은 「특성 」 라벨뿐이다 — 11-01 이 채운다")
		var hp := int(b.soldier_hp[id])
		var max_hp := int(b.army.max_hp_of(id))
		t.ok(hp > 0 and hp == max_hp, "자가 점검 — 막 선 몸은 체력이 가득이다 (%d/%d)" % [hp, max_hp])
		t.eq(str(spy.lines[2]["text"]), "체력 %d/%d" % [hp, max_hp],
			"셋째 줄이 「체력 현재/최대」 다")
		t.eq(str(spy.lines[3]["text"]), "허기 ", "넷째 줄은 「허기 」 라벨뿐이다 — 05-07 이 채운다")
		t.ok(not str(spy.lines[0]["text"]).contains(" x "),
			"하나만 골랐으면 이름 줄에 「x N」 이 안 붙는다")
	_the_layout_is_looks_answer(t, spy, "몸 하나")
	_let_go(spy)


## Nine picked: the name line ends with 「x 9」 and names the FIRST id the hand holds — not the last,
## not the lowest. ⚠ The hand is filled in a scrambled order so 「first held」 and 「smallest id」 are
## different bodies; a panel that sorted the list would name the wrong one and go red.
func _nine_picked_names_the_first_and_counts_nine(t) -> void:
	var b := _battle(NINE)
	var stood := _stand_at_home(b, NINE)
	t.eq(stood.size(), NINE, "자가 점검 — 아홉이 섬에 섰다")
	var want := PackedInt32Array()
	# The last body first, then the rest in order: the head of the hand is id 8, not id 0.
	want.append(stood[NINE - 1])
	for k in NINE - 1:
		want.append(stood[k])
	var hand := Hand.new()
	t.ok(hand.pick_many(b, want), "자가 점검 — 손이 아홉을 한꺼번에 쥐었다")
	t.eq(hand.ids.size(), NINE, "자가 점검 — 손에 아홉이 들려 있다")
	var first := int(hand.ids[0])
	t.ok(first != int(stood[0]), "자가 점검 — 손의 첫 몸이 가장 낮은 id 가 아니다 (%d)" % first)

	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(b)
	spy.set_picked(hand.ids)
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 1, "아홉을 골라도 판은 하나다")
	t.eq(spy.lines.size(), 4, "아홉을 골라도 글줄은 넉 줄이다 — 나머지 여덟은 안 뜬다")
	if spy.lines.size() == 4:
		var text := str(spy.lines[0]["text"])
		t.ok(text.ends_with(" x %d" % NINE), "이름 줄이 「x 9」 로 끝난다 (%s)" % text)
		t.eq(text, "이름 %s x %d" % [b.army.name_of(first), NINE],
			"그리고 그 앞은 손의 FIRST 몸의 이름이다")
		var other: String = b.army.name_of(int(stood[0]))
		t.ok(not text.begins_with("이름 " + other + " "),
			"가장 낮은 id 의 이름이 아니다 (%s) — 목록을 정렬해 버리면 여기가 빨개진다" % other)
		t.eq(str(spy.lines[2]["text"]),
			"체력 %d/%d" % [int(b.soldier_hp[first]), int(b.army.max_hp_of(first))],
			"체력 줄도 그 첫 몸의 것이다")
	_the_layout_is_looks_answer(t, spy, "아홉")
	_let_go(spy)


## The same pick on two consecutive frames with the body's hp lowered between them: the second frame's
## 체력 line carries the lower number. **The panel follows the fight, not the pick** — a view that
## formatted the line once at `set_picked` and cached it would go red here.
func _the_hp_line_follows_the_fight(t) -> void:
	var b := _battle(1)
	var id := _stand_at_home(b, 1)[0]
	var hand := Hand.new()
	hand.pick(b, id)
	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(b)
	spy.set_picked(hand.ids)
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 4, "자가 점검 — 첫 프레임에 넉 줄이 섰다")
	var before := str(spy.lines[2]["text"]) if spy.lines.size() == 4 else ""
	var full := float(b.soldier_hp[id])
	var less := full - 1.0
	t.ok(less > 0.0, "자가 점검 — 하나를 깎아도 살아 있다 (%s)" % str(full))
	b.soldier_hp[id] = less
	# The shell's own rhythm: `set_picked` again with the same hand, and one more frame.
	spy.set_picked(hand.ids)
	await t.pump_frames(1)
	t.eq(spy.lines.size(), 4, "둘째 프레임에도 넉 줄이다")
	if spy.lines.size() == 4:
		var after := str(spy.lines[2]["text"])
		t.eq(after, "체력 %d/%d" % [int(less), int(b.army.max_hp_of(id))],
			"둘째 프레임의 체력 줄이 깎인 수를 든다 (%s)" % after)
		t.ok(after != before, "그리고 첫 프레임의 줄과 다르다 (%s -> %s) — 고를 때 한 번 찍은 게 아니다"
			% [before, after])
	_let_go(spy)


## `bind(other)` after a pick: the next frame paints nothing, until `set_picked` is called again — and
## then it paints. **Both halves**: the clear, and that the clear is not permanent.
func _a_new_island_drops_the_pick(t) -> void:
	var b := _battle(1)
	var id := _stand_at_home(b, 1)[0]
	var hand := Hand.new()
	hand.pick(b, id)
	var spy := PanelSpy.new()
	t.root.add_child(spy)
	spy.bind(b)
	spy.set_picked(hand.ids)
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 1, "자가 점검 — 첫 섬에서 판이 섰다")

	var other := _battle(1)
	var other_id := _stand_at_home(other, 1)[0]
	spy.bind(other)
	await t.pump_frames(1)
	t.ok(spy.draws >= 2, "자가 점검 — bind 가 다시 그리기를 청했다")
	t.eq(spy.panels.size(), 0, "다른 섬에 묶이면 지난 섬의 판이 안 뜬다")
	t.eq(spy.lines.size(), 0, "글줄도 없다")

	var hand2 := Hand.new()
	hand2.pick(other, other_id)
	spy.set_picked(hand2.ids)
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 1, "그 섬에서 다시 고르면 판이 다시 선다 — 비운 것이 영영이 아니다")
	if spy.lines.size() == 4:
		t.eq(str(spy.lines[0]["text"]), "이름 " + other.army.name_of(other_id),
			"그리고 새 섬의 몸 이름이다")

	# The other edge: emptying the hand takes the plate down on the very next frame.
	spy.set_picked(PackedInt32Array())
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 0, "손을 비우면 다음 프레임에 판이 내려간다")
	_let_go(spy)


# == the plate, the font and the layout ==============================================================

## The picture and the face, loaded the way the view loads them, against `Look`'s own numbers.
func _the_plate_and_the_font_are_what_look_says(t) -> void:
	var tex := load(Look.PANEL_TEX) as Texture2D
	t.ok(tex != null, "판 그림이 불러진다 (%s)" % Look.PANEL_TEX)
	if tex != null:
		t.eq(tex.get_size(), Look.PANEL_SIZE_PX,
			"판 그림의 크기가 PANEL_SIZE_PX 그대로다 — 배치는 그림에 안 맞추고 그림이 배치에 맞춘다")
	var vp := Look.viewport_size_px()
	t.ok(Look.PANEL_SIZE_PX.x < vp.x and Look.PANEL_SIZE_PX.y < vp.y, "판이 화면보다 작다")
	# The plate's height is the four lines plus the padding, and nothing else — a fifth line, or a
	# wider pitch, has to move the plate too.
	t.eq(int(Look.PANEL_SIZE_PX.y), 2 * Look.PANEL_PAD_PX + Look.PANEL_LABELS.size() * Look.PANEL_LINE_PX,
		"판 높이가 여백 둘에 글줄 넷을 더한 것이다")
	t.eq(Look.PANEL_LABELS.size(), 4, "라벨이 넷이다")

	var font := HudView.panel_font()
	t.ok(font != null, "판의 글꼴이 불러진다 (%s)" % Look.PANEL_FONT)
	if font != null:
		var w := font.get_string_size("돌쇠", HORIZONTAL_ALIGNMENT_LEFT, -1, Look.PANEL_FONT_PX).x
		t.ok(w > 0.0, "그 글꼴에 한글이 들어 있다 — 「돌쇠」 의 폭이 0 이 아니다 (%s)" % str(w))
		_the_font_is_galmuri(t, font, "글꼴")
		# **The widest line the panel can ever be asked to hold**: the widest name in the list with the
		# full-list count behind it, and it still fits between the paddings. ⚠ **Measured with the
		# font, not by syllable count** — the widest name by glyphs is whatever the font says it is.
		var widest := ""
		var widest_px := 0.0
		for raw in Names.LIST:
			var name_px := font.get_string_size(str(raw), HORIZONTAL_ALIGNMENT_LEFT, -1,
				Look.PANEL_FONT_PX).x
			if name_px > widest_px:
				widest_px = name_px
				widest = str(raw)
		var longest := "이름 %s x %d" % [widest, Names.LIST.size()]
		var longest_px := font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Look.PANEL_FONT_PX).x
		t.ok(longest_px > 0.0 and longest_px <= Look.PANEL_SIZE_PX.x - 2.0 * Look.PANEL_PAD_PX,
			"가장 넓은 이름 줄 「%s」 (%s px) 이 여백 안쪽 폭에 든다" % [longest, str(longest_px)])

	# The two pure functions, on their own — the hook-vs-function compare below is what proves
	# `_draw` calls them; this is what proves they answer a corner and a line pitch.
	var origin := Look.panel_origin_px(Look.PANEL_SIZE_PX)
	var plate := Rect2(origin, Look.PANEL_SIZE_PX)
	t.ok(_inside(plate, Rect2(Vector2.ZERO, vp)), "판의 자리가 화면 안이다 (%s)" % str(plate))
	t.ok(is_equal_approx(origin.x, 0.0) or is_equal_approx(plate.end.x, vp.x),
		"판이 왼쪽이나 오른쪽 화면 끝에 붙어 있다 — 여백 없음")
	t.ok(is_equal_approx(origin.y, 0.0) or is_equal_approx(plate.end.y, vp.y),
		"판이 위나 아래 화면 끝에 붙어 있다 — 여백 없음")
	var a := 11.0
	var l0 := Look.panel_line_baseline_px(origin, 0, a)
	var l1 := Look.panel_line_baseline_px(origin, 1, a)
	t.ok(l0.is_equal_approx(origin + Vector2(Look.PANEL_PAD_PX, Look.PANEL_PAD_PX + a)),
		"첫 기준선이 여백 안쪽으로 어센트만큼 내려간 자리다")
	t.ok((l1 - l0).is_equal_approx(Vector2(0.0, Look.PANEL_LINE_PX)),
		"줄 사이가 PANEL_LINE_PX 다")


## **Hook argument against pure function**, for one spied frame: the plate's origin is
## `panel_origin_px`, each line's `at` is `panel_line_baseline_px(origin, i, ascent)`, every point
## lies inside the viewport AND inside the plate, and the size and colour ride on every call.
func _the_layout_is_looks_answer(t, spy: PanelSpy, label: String) -> void:
	if spy.panels.size() != 1 or spy.lines.size() != 4:
		return
	var vp := Rect2(Vector2.ZERO, Look.viewport_size_px())
	var at: Vector2 = spy.panels[0]["at"]
	var tex: Texture2D = spy.panels[0]["tex"]
	t.ok(tex != null and tex.get_size() == Look.PANEL_SIZE_PX,
		"%s — 후크에 건네진 판 그림이 PANEL_SIZE_PX 다" % label)
	t.ok(at.is_equal_approx(Look.panel_origin_px(Look.PANEL_SIZE_PX)),
		"%s — 후크에 건네진 판의 자리가 panel_origin_px 의 답이다 (%s)" % [label, str(at)])
	var plate := Rect2(at, Look.PANEL_SIZE_PX)
	t.ok(_inside(plate, vp), "%s — 판이 통째로 화면 안에 든다" % label)
	var font: Font = spy.lines[0]["font"]
	t.ok(font == HudView.panel_font(), "%s — 글줄이 판의 글꼴로 그려진다" % label)
	# ⚠ Identity alone is green when `panel_font()` is quietly swapped to the theme face — the ascent
	# and the path pin WHICH font that is.
	_the_font_is_galmuri(t, font, label)
	var plate_lum := _plate_centre_luminance(tex)
	var ascent := font.get_ascent(Look.PANEL_FONT_PX)
	var descent := font.get_descent(Look.PANEL_FONT_PX)
	var inner_w := Look.PANEL_SIZE_PX.x - 2.0 * Look.PANEL_PAD_PX
	var last_y := -1.0
	for i in spy.lines.size():
		var line: Dictionary = spy.lines[i]
		var p: Vector2 = line["at"]
		var col: Color = line["col"]
		var text := str(line["text"])
		# ⚠ `col == COL_PANEL_TEXT` alone is green at alpha 0 and green in the plate's own colour —
		# the letters have to be opaque and have to stand off the plate.
		t.ok(is_equal_approx(col.a, 1.0), "%s — %d째 줄의 글자색이 불투명하다 (a=%s)" % [label, i, str(col.a)])
		t.ok(absf(col.get_luminance() - plate_lum) > 0.3,
			"%s — %d째 줄의 글자색이 판 한가운데 색과 밝기로 갈린다 (%s 대 %s)"
				% [label, i, str(col.get_luminance()), str(plate_lum)])
		var text_px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(line["size_px"])).x
		t.ok(text_px > 0.0 and text_px <= inner_w,
			"%s — %d째 줄 「%s」 의 폭 %s px 가 여백 안쪽 %s px 에 든다"
				% [label, i, text, str(text_px), str(inner_w)])
		t.ok(p.is_equal_approx(Look.panel_line_baseline_px(at, i, ascent)),
			"%s — %d째 줄의 기준선이 panel_line_baseline_px 의 답이다 (%s)" % [label, i, str(p)])
		t.ok(vp.has_point(p), "%s — %d째 줄의 기준선이 화면 안이다" % [label, i])
		t.ok(plate.has_point(p), "%s — %d째 줄의 기준선이 판 안이다" % [label, i])
		t.ok(p.y > last_y, "%s — %d째 줄이 앞 줄보다 아래다" % [label, i])
		last_y = p.y
		t.eq(int(line["size_px"]), Look.PANEL_FONT_PX,
			"%s — %d째 줄이 PANEL_FONT_PX 로 그려진다" % [label, i])
		t.eq(line["col"], Look.COL_PANEL_TEXT, "%s — %d째 줄이 COL_PANEL_TEXT 로 그려진다" % [label, i])
	# The first line's top and the last line's descender both stay inside the plate — a plate too
	# short for four lines of this font would pass the baseline rows and fail here.
	var top: float = spy.lines[0]["at"].y - ascent
	var bottom: float = spy.lines[3]["at"].y + descent
	t.ok(top >= plate.position.y and bottom <= plate.end.y,
		"%s — 첫 줄의 머리와 넷째 줄의 꼬리가 다 판 안이다 (%s..%s)" % [label, str(top), str(bottom)])


## **Which font this is**, by two things a swapped face cannot fake: Galmuri14's ascent at 15 px is
## 15.0 (measured 2026-09-02; the theme's Hangul face answers 18.0), and the resource was loaded from
## `Look.PANEL_FONT` and nowhere else.
func _the_font_is_galmuri(t, font: Font, label: String) -> void:
	t.eq(font.get_ascent(Look.PANEL_FONT_PX), 15.0,
		"%s — 15 px 에서 어센트가 15.0 이다 (갈무리14 의 값 — 테마 글꼴은 18.0)" % label)
	t.eq(font.resource_path, Look.PANEL_FONT, "%s — 글꼴이 PANEL_FONT 에서 불러진 그 파일이다" % label)


## The luminance of the plate's own centre pixel — what the letters have to stand off.
func _plate_centre_luminance(tex: Texture2D) -> float:
	if tex == null:
		return -1.0
	var img := tex.get_image()
	if img == null:
		return -1.0
	var c := img.get_pixel(int(img.get_width() / 2), int(img.get_height() / 2))
	return c.get_luminance()


# == the shell ========================================================================================

## `Game._ready()` treed, an island opened through the real title press, the hud swapped for the spy
## by the same order `net_shell` uses, and the hand filled: **one `_process` and the spy paints.**
## ⚠⚠ **This is the row that catches the shell never calling `set_picked`** — every row above hands
## the ids to the view by hand.
func _the_shell_hands_the_hand_to_the_panel(t) -> void:
	var game := Game.new()
	t.root.add_child(game)
	await t.pump_frames(2)
	game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
	# The spy goes in AFTER `_ready` built the real three and is wired by a real `_open_island`: a
	# spy pre-set before `_ready` would let the wiring line be deleted.
	game.remove_child(game.hud_view)
	game.hud_view.queue_free()
	var spy := PanelSpy.new()
	game.hud_view = spy
	game.add_child(spy)
	game._open_island()
	await t.pump_frames(2)

	var b: Battle = game.battle
	t.ok(b != null, "자가 점검 — 섬이 열렸다")
	if b == null:
		game.queue_free()
		return
	t.ok(game.hand.is_empty(), "자가 점검 — 빈 손으로 시작한다")
	t.eq(spy.panels.size(), 0, "빈 손이면 셸을 지나도 판이 안 뜬다")

	var ashore := b.ashore_ids()
	t.ok(ashore.size() >= 2, "자가 점검 — 섬에 몸이 둘 이상 서 있다 (%d)" % ashore.size())
	var want := PackedInt32Array()
	for raw in ashore:
		want.append(int(raw))
	t.ok(game.hand.pick_many(b, want), "자가 점검 — 셸의 손이 그 몸들을 쥐었다")
	var held := game.hand.ids.size()
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 1, "손이 차 있으면 셸의 한 프레임이 판을 세운다 — set_picked 줄을 지우면 빨개진다")
	t.eq(spy.lines.size(), 4, "그리고 넉 줄이다")
	if spy.lines.size() == 4:
		var text := str(spy.lines[0]["text"])
		t.eq(text, "이름 %s x %d" % [b.army.name_of(int(game.hand.ids[0])), held],
			"이름 줄이 손의 첫 몸과 손의 수를 말한다 (%s)" % text)
	_the_layout_is_looks_answer(t, spy, "셸")

	# And letting go takes it down through the same line.
	game.hand.clear()
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 0, "손을 놓으면 셸의 다음 프레임에 판이 내려간다")

	t.root.remove_child(game)
	game.queue_free()


# == fixtures =========================================================================================

## A flat board with `n` bodies on the roster, none yet ashore — `net_hand`'s shape.
func _battle(n: int) -> Battle:
	var g := Grid.new()
	g.load_rows(FIELD, [])
	var army := Army.new()
	var slot := army.register_species(Rules.SWORDSMAN)
	for _i in n:
		army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, [], PackedInt32Array(), -1)
	return b


## Stands `n` bodies at the home corner and answers their ids, `0 .. n - 1`.
func _stand_at_home(b: Battle, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var home := b.grid.tile_index(HOME_TX, HOME_TY)
	for i in n:
		if b.place_ashore(i, home) >= 0:
			out.append(i)
	return out


func _let_go(spy: PanelSpy) -> void:
	spy.get_parent().remove_child(spy)
	spy.queue_free()


func _inside(r: Rect2, outer: Rect2) -> bool:
	return r.position.x >= outer.position.x and r.position.y >= outer.position.y \
		and r.end.x <= outer.end.x and r.end.y <= outer.end.y


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev
