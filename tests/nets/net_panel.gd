extends RefCounted
## **The picked body's panel — the screen half of 03-02, layout A 「세 칸」** (2026-09-02, the user:
## 「캐릭터 누르면 선택되고 정보ㄴ뜨고 이동되는게 필요할듯」 · 「크게 한 판으로 한 다음에 왼쪽부터 상태,
## 능력치, 적성」 · 「아니야 아이콘하지마」).
##
## The claim under test: **while the hand holds somebody, `HudView` paints one 480x180 plate and
## exactly fifteen lines — the name line across the top, then three columns 상태 · 능력치 · 적성 under
## it — about the FIRST body held, with 「x N」 on the name when the hand holds more, every number read
## live off the sim; and while the hand holds nobody it paints nothing.**
##
## ⚠⚠ **MEASURED AT THE HOOKS, TREED, WITH PUMPED FRAMES** — the shape `how-nets-lie` prescribes for
## exactly this ticket: a `_draw()` that ran is not a thing drawn, so a `PanelSpy` overrides the two
## `_paint_*` leaves and records their arguments; the spy cannot see the `draw_*` inside a leaf, so
## `net_draw_leaf` pins each leaf's count; a pure layout function asserted on its own proves nothing
## about `_draw`, so **every origin and baseline is read off the hook and compared to `Look`'s answer**;
## and a panel that laid itself out from a zero size would pile into the top-left, so **every point is
## asserted inside the viewport and inside the plate**.
##
## ⚠ **The labels, the column positions and the aptitude scale are typed here as literals on
## purpose** — they are what the user decided, and a net that read them back off `Look` or `Rules`
## would be green for any ten words at any x. The pure functions are compared to the hooks; the
## literals are compared to the pure functions.
##
## ⚠ **The sim half — names, aptitudes, hunger, defense — is measured in `net_names`.** This file
## reads `army.name_of` · `aptitude_of` · `hunger_of` and `Rules.defense_of` · `period_of` only to say
## what the panel must print.
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

## **Layout A, as the user and the plan fixed it** — the numbers `Look` has to answer with. Pinned
## here so a column quietly moved in `look.gd` reads red rather than the net following it.
const LINES := 15
const PLATE_PX := Vector2(480, 180)
const PAD_PX := 12
const PITCH_PX := 19
const COL_X_PX := [12, 162, 312]
## Column widths: to the next column, and for the last to the far pad.
const COL_W_PX := [150, 150, 156]
## Which column each of the fourteen column lines belongs to, and its line within that column —
## 상태 head + 3, 능력치 head + 3, 적성 head + 5. Index 0 is the full-width name line.
const COL_OF := [-1, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2]
const ROW_OF := [0, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 4, 5]
## The five aptitude words in panel order (the user: 「요리 제작 낚시 채광 벌목」) and the scale
## (「영에서 십이고」). `Rules` owns them for the game; this is what the panel must print.
const APTITUDE_WORDS := ["요리", "제작", "낚시", "채광", "벌목"]
const APTITUDE_TOP := 10
## What 허기 reads for a body nobody has starved yet — 05-07 owns the drain, so today it is the max.
const HUNGER_FULL := 100


func run(t) -> void:
	await _nothing_picked_paints_nothing(t)
	await _one_picked_paints_the_plate_and_fifteen_lines(t)
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


## One body picked: one plate, fifteen lines in the fixed order, every value read off the sim and
## not off a literal. **Both bounds** — exactly fifteen, never fourteen (a dropped 특성 line) and
## never sixteen (a line typed in beside them).
func _one_picked_paints_the_plate_and_fifteen_lines(t) -> void:
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
	t.eq(spy.lines.size(), LINES, "그리고 글줄이 정확히 열다섯 줄이다 — 이름 하나, 상태 넷, 능력치 넷, 적성 여섯")
	if spy.lines.size() == LINES:
		var who: String = b.army.name_of(id)
		t.ok(who != "", "자가 점검 — 그 몸에 이름이 붙어 있다")
		var hp := int(b.soldier_hp[id])
		var max_hp := int(b.army.max_hp_of(id))
		t.ok(hp > 0 and hp == max_hp, "자가 점검 — 막 선 몸은 체력이 가득이다 (%d/%d)" % [hp, max_hp])
		var want := _expected_lines(b, id, 1)
		for i in LINES:
			t.eq(str(spy.lines[i]["text"]), str(want[i]), "%d째 줄이 「%s」 다" % [i, str(want[i])])
		t.ok(not str(spy.lines[0]["text"]).contains(" x "),
			"하나만 골랐으면 이름 줄에 「x N」 이 안 붙는다")
		# The values that are not the sim's own reading back but the day's decisions, pinned as words:
		t.eq(str(spy.lines[3]["text"]), "허기 %d" % HUNGER_FULL,
			"허기 줄이 「허기 100」 이다 — 05-07 이 깎기 전까지 가득이다")
		t.eq(str(spy.lines[4]["text"]), "특성 ", "특성 줄은 「특성 」 라벨뿐이다 — 11-01 이 채운다")
		var period := str(spy.lines[8]["text"])
		t.ok(period.begins_with("공격간격 ") and period.ends_with("초"),
			"공격간격 줄이 「공격간격 」 로 열고 「초」 로 닫는다 (%s)" % period)
		var number := period.trim_prefix("공격간격 ").trim_suffix("초")
		t.ok(number.is_valid_float() and number.find(".") == number.length() - 2,
			"그 사이가 소수 한 자리 수다 (%s) — 초 단위, 클수록 느린 몸" % number)
		t.eq(number, "%.1f" % Rules.period_of(int(b.army.type_id[id])),
			"그 수가 이 몸의 Rules.period_of 를 소수 한 자리로 찍은 것이다")
		for k in APTITUDE_WORDS.size():
			var line := str(spy.lines[10 + k]["text"])
			t.ok(line.ends_with("/%d" % APTITUDE_TOP), "적성 %d째 줄이 「/10」 으로 끝난다 (%s)" % [k, line])
			var got := line.trim_prefix(str(APTITUDE_WORDS[k]) + " ").trim_suffix("/%d" % APTITUDE_TOP)
			t.eq(got.to_int(), b.army.aptitude_of(id, k),
				"적성 %d째 줄의 수가 aptitude_of 다 (%s)" % [k, line])
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
	t.eq(spy.lines.size(), LINES, "아홉을 골라도 글줄은 열다섯 줄이다 — 나머지 여덟은 안 뜬다")
	if spy.lines.size() == LINES:
		var text := str(spy.lines[0]["text"])
		t.ok(text.ends_with(" x %d" % NINE), "이름 줄이 「x 9」 로 끝난다 (%s)" % text)
		t.eq(text, "이름 %s x %d" % [b.army.name_of(first), NINE],
			"그리고 그 앞은 손의 FIRST 몸의 이름이다")
		var other: String = b.army.name_of(int(stood[0]))
		t.ok(not text.begins_with("이름 " + other + " "),
			"가장 낮은 id 의 이름이 아니다 (%s) — 목록을 정렬해 버리면 여기가 빨개진다" % other)
		var expected := _expected_lines(b, first, NINE)
		for i in range(1, LINES):
			t.eq(str(spy.lines[i]["text"]), str(expected[i]), "%d째 줄도 그 첫 몸의 것이다" % i)
		# ⚠ Nine bodies were born from one seed-less army, so at least one of the eight others has
		# some aptitude row different from the first's — the check above is then not vacuous.
		var differs := false
		for raw in stood:
			for k in APTITUDE_WORDS.size():
				if b.army.aptitude_of(int(raw), k) != b.army.aptitude_of(first, k):
					differs = true
		t.ok(differs, "자가 점검 — 아홉 중 첫 몸과 적성이 다른 몸이 있다 (없으면 위 줄이 아무것도 안 잰다)")
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
	t.eq(spy.lines.size(), LINES, "자가 점검 — 첫 프레임에 열다섯 줄이 섰다")
	var before := str(spy.lines[2]["text"]) if spy.lines.size() == LINES else ""
	var full := float(b.soldier_hp[id])
	var less := full - 1.0
	t.ok(less > 0.0, "자가 점검 — 하나를 깎아도 살아 있다 (%s)" % str(full))
	b.soldier_hp[id] = less
	# The shell's own rhythm: `set_picked` again with the same hand, and one more frame.
	spy.set_picked(hand.ids)
	await t.pump_frames(1)
	t.eq(spy.lines.size(), LINES, "둘째 프레임에도 열다섯 줄이다")
	if spy.lines.size() == LINES:
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
	if spy.lines.size() == LINES:
		t.eq(str(spy.lines[0]["text"]), "이름 " + other.army.name_of(other_id),
			"그리고 새 섬의 몸 이름이다")

	# The other edge: emptying the hand takes the plate down on the very next frame.
	spy.set_picked(PackedInt32Array())
	await t.pump_frames(1)
	t.eq(spy.panels.size(), 0, "손을 비우면 다음 프레임에 판이 내려간다")
	_let_go(spy)


# == the plate, the font and the layout ==============================================================

## The picture and the face, loaded the way the view loads them, against `Look`'s own numbers — and
## `Look`'s numbers against the layout the user fixed.
func _the_plate_and_the_font_are_what_look_says(t) -> void:
	var tex := load(Look.PANEL_TEX) as Texture2D
	t.ok(tex != null, "판 그림이 불러진다 (%s)" % Look.PANEL_TEX)
	if tex != null:
		t.eq(tex.get_size(), Look.PANEL_SIZE_PX,
			"판 그림의 크기가 PANEL_SIZE_PX 그대로다 — 배치는 그림에 안 맞추고 그림이 배치에 맞춘다")
	t.eq(Look.PANEL_SIZE_PX, PLATE_PX, "판이 480x180 이다 — 배치 A 「세 칸」")
	var vp := Look.viewport_size_px()
	t.ok(Look.PANEL_SIZE_PX.x < vp.x and Look.PANEL_SIZE_PX.y < vp.y, "판이 화면보다 작다")
	t.eq(Look.PANEL_LABELS.size(), 10, "타자로 친 라벨이 열이다 — 다섯 적성 낱말은 Rules 가 가진다")
	t.eq(Look.PANEL_COL_X_PX.size(), 3, "칸이 셋이다")
	for c in COL_X_PX.size():
		if c < Look.PANEL_COL_X_PX.size():
			t.eq(int(Look.PANEL_COL_X_PX[c]), int(COL_X_PX[c]),
				"%d째 칸이 x=%d 에서 시작한다" % [c, int(COL_X_PX[c])])
	t.eq(int(Look.PANEL_LINE_PX), PITCH_PX, "줄 사이가 19 이다")
	t.eq(Rules.APTITUDES.size(), APTITUDE_WORDS.size(), "적성이 다섯이다")
	for k in APTITUDE_WORDS.size():
		if k < Rules.APTITUDES.size():
			t.eq(str(Rules.APTITUDES[k]), str(APTITUDE_WORDS[k]),
				"%d째 적성이 「%s」 다 — 판의 순서" % [k, str(APTITUDE_WORDS[k])])
	t.eq(int(Rules.APTITUDE_MAX), APTITUDE_TOP, "적성 눈금이 열까지다 — 「영에서 십이고」")

	var font := HudView.panel_font()
	t.ok(font != null, "판의 글꼴이 불러진다 (%s)" % Look.PANEL_FONT)
	if font != null:
		var w := font.get_string_size("돌쇠", HORIZONTAL_ALIGNMENT_LEFT, -1, Look.PANEL_FONT_PX).x
		t.ok(w > 0.0, "그 글꼴에 한글이 들어 있다 — 「돌쇠」 의 폭이 0 이 아니다 (%s)" % str(w))
		_the_font_is_galmuri(t, font, "글꼴")
		# **The widest line the name row can ever be asked to hold**: the widest name in the list with
		# the full-list count behind it, and it still fits between the paddings. ⚠ **Measured with the
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
		var longest_px := _width(font, longest)
		t.ok(longest_px > 0.0 and longest_px <= PLATE_PX.x - 2.0 * PAD_PX,
			"가장 넓은 이름 줄 「%s」 (%s px) 이 여백 안쪽 폭 %d 에 든다"
				% [longest, str(longest_px), int(PLATE_PX.x - 2.0 * PAD_PX)])
		# **The widest line each column can be asked to hold fits its column** — two digits before the
		# point for 공격간격 (no row is that slow; the width is the ceiling), 「10/10」 for an aptitude,
		# three digits of 체력 for 상태.
		t.ok(_width(font, "공격간격 99.9초") <= float(COL_W_PX[1]),
			"「공격간격 99.9초」 가 둘째 칸 폭 %d 에 든다 (%s px)" % [int(COL_W_PX[1]), str(_width(font, "공격간격 99.9초"))])
		t.ok(_width(font, "체력 999/999") <= float(COL_W_PX[0]),
			"「체력 999/999」 가 첫째 칸 폭 %d 에 든다" % int(COL_W_PX[0]))
		for k in APTITUDE_WORDS.size():
			t.ok(_width(font, "%s 10/10" % str(APTITUDE_WORDS[k])) <= float(COL_W_PX[2]),
				"「%s 10/10」 이 셋째 칸 폭 %d 에 든다" % [str(APTITUDE_WORDS[k]), int(COL_W_PX[2])])

	# The pure functions, on their own — the hook-vs-function compare below is what proves `_draw`
	# calls them; this is what proves they answer a corner, a column and a line pitch, in the
	# literal numbers the layout fixed.
	var origin := Look.panel_origin_px(Look.PANEL_SIZE_PX)
	var plate := Rect2(origin, Look.PANEL_SIZE_PX)
	t.ok(_inside(plate, Rect2(Vector2.ZERO, vp)), "판의 자리가 화면 안이다 (%s)" % str(plate))
	t.ok(is_equal_approx(origin.x, 0.0) and is_equal_approx(plate.end.y, vp.y),
		"판이 왼쪽 아래 화면 끝에 붙어 있다 — 여백 없음")
	var a := 11.0
	var l0 := Look.panel_line_baseline_px(origin, 0, a)
	t.ok(l0.is_equal_approx(origin + Vector2(PAD_PX, PAD_PX + a)),
		"이름 줄의 기준선이 여백 12 안쪽으로 어센트만큼 내려간 자리다")
	for c in COL_X_PX.size():
		var c0 := Look.panel_cell_baseline_px(origin, c, 0, a)
		t.ok(c0.is_equal_approx(origin + Vector2(int(COL_X_PX[c]), PAD_PX + a + PITCH_PX)),
			"%d째 칸의 머리 줄이 x=%d, 이름 줄 한 줄 아래다 (%s)" % [c, int(COL_X_PX[c]), str(c0)])
		var c1 := Look.panel_cell_baseline_px(origin, c, 1, a)
		t.ok((c1 - c0).is_equal_approx(Vector2(0.0, PITCH_PX)), "%d째 칸의 줄 사이가 19 다" % c)
		t.ok(is_equal_approx(c0.y, Look.panel_line_baseline_px(origin, 1, a).y),
			"%d째 칸의 머리 줄이 이름 줄 아래 첫 줄과 같은 높이다" % c)
	# The bottom of the last column line and the far pad — the fit the plate was sized for.
	var last := Look.panel_cell_baseline_px(origin, 2, 5, 15.0)
	t.ok(last.y + 3.0 <= plate.end.y - PAD_PX,
		"여섯째 적성 줄의 기준선 %s 에 꼬리를 더해도 아래 여백 안이다 (%s)" % [str(last.y), str(plate.end.y - PAD_PX)])


## **Hook argument against pure function**, for one spied frame: the plate's origin is
## `panel_origin_px`, line 0's `at` is `panel_line_baseline_px(origin, 0, ascent)`, every other line's
## `at` is `panel_cell_baseline_px(origin, col, row, ascent)` for its column, every point lies inside
## the viewport AND inside the plate, the ink stays off the plate's bevel and inside its column, the
## last descender clears the bottom pad, and the size and colour ride on every call.
func _the_layout_is_looks_answer(t, spy: PanelSpy, label: String) -> void:
	if spy.panels.size() != 1 or spy.lines.size() != LINES:
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
	var img := _plate_image(tex)
	var plate_lum := _plate_centre_luminance(img)
	var ascent := font.get_ascent(Look.PANEL_FONT_PX)
	var descent := font.get_descent(Look.PANEL_FONT_PX)
	var last_y := -1.0
	var col_last_y := [-1.0, -1.0, -1.0]
	for i in spy.lines.size():
		var line: Dictionary = spy.lines[i]
		var p: Vector2 = line["at"]
		var col: Color = line["col"]
		var text := str(line["text"])
		var c := int(COL_OF[i])
		# ⚠ `col == COL_PANEL_TEXT` alone is green at alpha 0 and green in the plate's own colour —
		# the letters have to be opaque and have to stand off the plate.
		t.ok(is_equal_approx(col.a, 1.0), "%s — %d째 줄의 글자색이 불투명하다 (a=%s)" % [label, i, str(col.a)])
		t.ok(absf(col.get_luminance() - plate_lum) > 0.3,
			"%s — %d째 줄의 글자색이 판 한가운데 색과 밝기로 갈린다 (%s 대 %s)"
				% [label, i, str(col.get_luminance()), str(plate_lum)])
		var text_px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(line["size_px"])).x
		var room := float(PLATE_PX.x - 2 * PAD_PX) if c < 0 else float(COL_W_PX[c])
		t.ok(text_px > 0.0 and text_px <= room,
			"%s — %d째 줄 「%s」 의 폭 %s px 가 제 칸 폭 %s px 에 든다"
				% [label, i, text, str(text_px), str(room)])
		var want: Vector2 = Look.panel_line_baseline_px(at, 0, ascent) if c < 0 \
			else Look.panel_cell_baseline_px(at, c, int(ROW_OF[i]), ascent)
		t.ok(p.is_equal_approx(want),
			"%s — %d째 줄의 기준선이 %s 의 답이다 (%s)" % [label, i,
				"panel_line_baseline_px" if c < 0 else "panel_cell_baseline_px", str(p)])
		t.ok(vp.has_point(p), "%s — %d째 줄의 기준선이 화면 안이다" % [label, i])
		t.ok(plate.has_point(p), "%s — %d째 줄의 기준선이 판 안이다" % [label, i])
		# **Off the bevel**: the plate pixel under the line's first ink column, at the line's own
		# height, is the plate's flat field — the same colour as the centre — and not the bevel's
		# highlight or shadow. Measured off the picture, so a pad typed too small goes red here for
		# the reason it is wrong and not for being a different number.
		var under := Vector2i(int(p.x - at.x), int(p.y - at.y))
		t.ok(absf(_lum_at(img, under) - plate_lum) < 0.05,
			"%s — %d째 줄의 첫 먹이 판의 평평한 바닥 위에 선다 (%s: %s 대 %s)"
				% [label, i, str(under), str(_lum_at(img, under)), str(plate_lum)])
		if c < 0:
			t.ok(p.y > last_y, "%s — 이름 줄이 맨 위다" % label)
		else:
			t.ok(p.y > float(col_last_y[c]), "%s — %d째 줄이 제 칸의 앞 줄보다 아래다" % [label, i])
			col_last_y[c] = p.y
			t.ok(p.y > last_y, "%s — %d째 줄이 이름 줄보다 아래다" % [label, i])
		if c < 0:
			last_y = p.y
		t.eq(int(line["size_px"]), Look.PANEL_FONT_PX,
			"%s — %d째 줄이 PANEL_FONT_PX 로 그려진다" % [label, i])
		t.eq(line["col"], Look.COL_PANEL_TEXT, "%s — %d째 줄이 COL_PANEL_TEXT 로 그려진다" % [label, i])
	# The three heads share one baseline, one pitch under the name line.
	t.ok(is_equal_approx(spy.lines[1]["at"].y, spy.lines[5]["at"].y)
		and is_equal_approx(spy.lines[5]["at"].y, spy.lines[9]["at"].y),
		"%s — 상태 · 능력치 · 적성 머리가 한 높이다" % label)
	t.ok(is_equal_approx(spy.lines[1]["at"].y - spy.lines[0]["at"].y, float(PITCH_PX)),
		"%s — 머리 줄이 이름 줄 한 줄 아래다" % label)
	# **The vertical fit**: the name line's top clears the top pad and the lowest line's descender
	# clears the bottom pad — the sixth 적성 line, the longest column. The plate is not sized from
	# the line count any more, so this is the row that says fifteen lines fit on it.
	var top: float = spy.lines[0]["at"].y - ascent
	var top_under := Vector2i(int(PLATE_PX.x * 0.5), int(top - at.y))
	t.ok(absf(_lum_at(img, top_under) - plate_lum) < 0.05,
		"%s — 이름 줄의 머리 밑도 판의 평평한 바닥이다 (%s)" % [label, str(top_under)])
	var bottom: float = spy.lines[LINES - 1]["at"].y + descent
	t.ok(top >= plate.position.y + PAD_PX and bottom <= plate.end.y - PAD_PX,
		"%s — 이름 줄의 머리와 마지막 적성 줄의 꼬리가 다 여백 안이다 (%s..%s 대 %s..%s)"
			% [label, str(top), str(bottom), str(plate.position.y + PAD_PX), str(plate.end.y - PAD_PX)])


## **Which font this is**, by two things a swapped face cannot fake: Galmuri14's ascent at 15 px is
## 15.0 (measured 2026-09-02; the theme's Hangul face answers 18.0), and the resource was loaded from
## `Look.PANEL_FONT` and nowhere else.
func _the_font_is_galmuri(t, font: Font, label: String) -> void:
	t.eq(font.get_ascent(Look.PANEL_FONT_PX), 15.0,
		"%s — 15 px 에서 어센트가 15.0 이다 (갈무리14 의 값 — 테마 글꼴은 18.0)" % label)
	t.eq(font.resource_path, Look.PANEL_FONT, "%s — 글꼴이 PANEL_FONT 에서 불러진 그 파일이다" % label)


## What the panel must print for body `id` held first among `held` — the fifteen lines, from the
## user's labels and the sim's stored values. ⚠ **Every label is a literal here**; only the numbers
## are read.
func _expected_lines(b: Battle, id: int, held: int) -> Array:
	var who: String = b.army.name_of(id)
	if held > 1:
		who += " x %d" % held
	var type := int(b.army.type_id[id])
	var out := [
		"이름 " + who,
		"상태",
		"체력 %d/%d" % [int(b.soldier_hp[id]), int(b.army.max_hp_of(id))],
		"허기 %d" % int(b.army.hunger_of(id)),
		"특성 ",
		"능력치",
		"공격력 %d" % int(Rules.damage_of(type)),
		"방어력 %d" % int(Rules.defense_of(type)),
		"공격간격 %.1f초" % Rules.period_of(type),
		"적성",
	]
	for k in APTITUDE_WORDS.size():
		out.append("%s %d/%d" % [str(APTITUDE_WORDS[k]), b.army.aptitude_of(id, k), APTITUDE_TOP])
	return out


func _width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Look.PANEL_FONT_PX).x


func _plate_image(tex: Texture2D) -> Image:
	return null if tex == null else tex.get_image()


## The luminance of the plate's own centre pixel — what the letters have to stand off, and what its
## flat field reads everywhere the ink lands.
func _plate_centre_luminance(img: Image) -> float:
	if img == null:
		return -1.0
	return _lum_at(img, Vector2i(int(img.get_width() / 2), int(img.get_height() / 2)))


func _lum_at(img: Image, at: Vector2i) -> float:
	if img == null or at.x < 0 or at.y < 0 or at.x >= img.get_width() or at.y >= img.get_height():
		return -1.0
	return img.get_pixel(at.x, at.y).get_luminance()


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
	t.eq(spy.lines.size(), LINES, "그리고 열다섯 줄이다")
	if spy.lines.size() == LINES:
		var first := int(game.hand.ids[0])
		var expected := _expected_lines(b, first, held)
		t.eq(str(spy.lines[0]["text"]), str(expected[0]),
			"이름 줄이 손의 첫 몸과 손의 수를 말한다 (%s)" % str(spy.lines[0]["text"]))
		for i in range(1, LINES):
			t.eq(str(spy.lines[i]["text"]), str(expected[i]),
				"셸을 지나서도 %d째 줄이 그 몸의 저장된 값이다" % i)
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
