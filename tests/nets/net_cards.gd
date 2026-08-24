extends RefCounted
## The reward screen: six cards after a won fight, take two. `run.cards` is `Rules.CARDS_PER_WIN`
## `(part, species)` pairs, flat, drawn by `Run._draw_cards`; `RewardView` reads them and writes
## nothing back. See `parts-on-a-board-not-on-the-body`.
##
## ⚠ **`RewardView` holds a `Run` and this file drives both halves**: the SIM half (six cards drawn,
## two takeable, the seed determinism) through `Run`'s own verbs, and the PICTURE half (the rectangles,
## the press ramp, what each leaf was actually handed) through a spy, exactly as `net_title` splits the
## two for the screen it set the pattern with.
##
## ⚠⚠ **The view's own clock is stopped and `_fx_step(dt)` is called by hand**, for the same reason
## `net_title` gives: a headless frame cannot pin a ramp to a fraction of a second.


## Every one of the five leaves is overridden. A hook left out binds to nothing, the REAL `draw_*` runs
## headless, the capture array stays empty, and every check about it reads as "nothing was drawn"
## rather than as a failure.
class RewardSpy extends RewardView:
	var draws := 0
	var cards := []
	var parts := []
	var species := []
	var marks := []
	var hints := []
	var fades := []

	func _draw() -> void:
		cards.clear()
		parts.clear()
		species.clear()
		marks.clear()
		hints.clear()
		fades.clear()
		super()
		draws += 1

	func _paint_card(rect: Rect2, bg: Color, edge_width: float) -> void:
		cards.append({"rect": rect, "bg": bg, "width": edge_width})

	func _paint_card_name(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		parts.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_card_effect(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		species.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_taken_mark(centre: Vector2, radius: float, col: Color) -> void:
		marks.append({"centre": centre, "radius": radius, "col": col})

	func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
		hints.append({"face": face, "at": at, "text": text, "fsize": fsize, "col": col})

	func _paint_fade(rect: Rect2, col: Color) -> void:
		fades.append({"rect": rect, "col": col})


const SCREEN := Rect2(0.0, 0.0, 1280.0, 720.0)
const SMALLEST_PRESS_BEFORE := Vector2(220.0, 64.0)


func run(t) -> void:
	_the_six_cards(t)
	_taking_two(t)
	_the_seed(t)
	_the_geometry(t)
	_the_alpha_channel(t)
	_the_species_colours_read(t)
	await _the_screen_itself_fades_in(t)
	await _the_leaves_draw_what_they_were_handed(t)
	await _the_cards_fade_in_staggered(t)


## Wins island 0, at a fixed seed unless `seed` is < 0, and hands back the `Run` sitting in `PICK`.
func _won_run(seed: int = 1) -> Run:
	var r := Run.new()
	if seed >= 0:
		r.seed_cards(seed)
	r.enter_node(0)
	r.finish_island(true)
	return r


# -- the sim: what the cards ARE ---------------------------------------------------------------------

func _the_six_cards(t) -> void:
	# 「이기면 카드가 여섯 장 나온다」 — floor: six pairs; ceiling: none taken yet.
	var r := _won_run()
	t.eq(r.state(), Run.State.PICK, "이기면 카드 고르기가 열린다 (자가 점검)")
	# ⚠ **One int per card, not two** (2026-08-24): a card was a (part, species) pair and is an item id.
	t.eq(r.cards.size(), Rules.CARDS_PER_WIN, "카드 배열이 세 장이다")
	var taken := 0
	for b in r.cards_taken:
		if b != 0:
			taken += 1
	t.eq(taken, 0, "아직 아무것도 안 골랐다")
	for k in Rules.CARDS_PER_WIN:
		var item := int(r.cards[k])
		t.ok(item >= 0 and item < Rules.item_count(), "%d번 카드가 장비 표 안이다 (%d)" % [k, item])
		t.ok(Rules.item_name_of(item) != "", "%d번 카드에 이름이 있다" % k)


## 「둘을 고르면 정비로 넘어간다」 · 「같은 카드를 두 번 못 고른다」 · 「고른 카드가 더미에 그대로
## 들어간다」, in one walk — each reads the state right after the call it claims about.
func _taking_two(t) -> void:
	var r := _won_run()
	var want_item := int(r.cards[0])
	var pile_before := r.army.loadout.held.size()

	t.ok(r.take_card(0), "0번 카드를 고른다")
	# ⚠⚠ **ONE PICK NOW, NOT TWO** (2026-08-24, 티켓 06). The block below used to walk 「한 장으로는
	# 아직 정비로 안 넘어간다」 and then take a second; with `CARD_PICKS` at 1 the first pick IS the
	# transition, and asserting the old sentence would be asserting the old rule.
	t.eq(r.state(), Run.State.REFIT, "한 장을 고르면 바로 정비로 넘어간다")
	t.eq(r.army.loadout.held.size(), pile_before + 1, "더미가 하나 늘었다")
	t.eq(int(r.army.loadout.held[pile_before]), want_item,
		"고른 카드의 장비가 더미에 그대로 들어갔다")

	t.ok(not r.take_card(0), "같은 카드를 두 번 못 고른다")
	t.eq(r.army.loadout.held.size(), pile_before + 1, "그래서 더미 크기가 그대로다")
	t.ok(not r.take_card(1), "고르기가 끝났으니 다른 카드도 못 고른다")
	t.ok(not r.take_card(2), "정비로 넘어간 뒤에는 세 번째 카드도 안 먹는다")
	t.ok(not r.take_card(-1), "음수 인덱스는 애초에 거절한다")
	t.ok(not r.take_card(99), "범위 밖 인덱스도 거절한다")


## ⚠⚠ 「같은 씨앗이면 여섯 장이 똑같고, 씨앗이 다르면 어딘가 다르다」. Mutation:
## `_rng.randi_range(0, Rules.ITEM_CELLS - 1)` -> `0`.
##
## ⚠ 「씨앗을 여럿 돌리면 부위 여섯과 종 셋이 전부 나온다」 is the row that structurally catches that
## exact mutation — a same/different-seed comparison of the WHOLE array can still see two seeds differ
## on the SPECIES half alone while every part reads 머리, so it is this row, and not the one above, that
## has to fail when a part goes constant.
func _the_seed(t) -> void:
	var a := _won_run(42)
	var b := _won_run(42)
	t.eq(a.cards, b.cards, "같은 씨앗의 두 런이 카드 배열까지 완전히 같다")

	var first := _won_run(1).cards
	var any_diff := false
	for s in range(2, 9):
		if _won_run(s).cards != first:
			any_diff = true
	t.ok(any_diff, "씨앗 여덟 개 중 적어도 한 번은 카드 배열이 달라진다")

	var seen_parts := {}
	var seen_rarity := {}
	# ⚠ **Widened from forty seeds to four hundred, because the draw got a shape.** A legendary is 3 in
	# 100, so forty runs of three cards is 120 draws and would miss one about 3% of the time — a net
	# that is red one round in thirty is a net nobody believes.
	for s in range(100, 500):
		var r := _won_run(s)
		for k in Rules.CARDS_PER_WIN:
			seen_parts[int(r.cards[k])] = true
			seen_rarity[Rules.item_rarity_of(int(r.cards[k]))] = true
	t.eq(seen_parts.size(), Rules.item_count(),
		"씨앗 사백 개에 걸쳐 장비 %d개가 전부 한 번은 나왔다" % Rules.item_count())
	t.eq(seen_rarity.size(), Rules.RARITY_WEIGHT.size(),
		"그리고 등급 %d개도 전부 나왔다" % Rules.RARITY_WEIGHT.size())


# -- the geometry: can it be aimed at ------------------------------------------------------------------

func _the_geometry(t) -> void:
	var view := RewardView.new()
	# 「카드 여섯의 사각형이 안 겹치고 화면 안이다」 — floor: every hit rect inside the literal screen;
	# ceiling: no two hit rects intersect.
	var outside := 0
	var overlapping := 0
	for k in Rules.CARDS_PER_WIN:
		var drawn := view.card_rect_of(k)
		var hit := view.card_hit_rect_of(k)
		if not SCREEN.encloses(hit):
			outside += 1
		if drawn.size.x <= 0.0 or drawn.size.y <= 0.0:
			outside += 1
		for j in range(k + 1, Rules.CARDS_PER_WIN):
			if hit.intersects(view.card_hit_rect_of(j)):
				overlapping += 1
	t.eq(outside, 0, "카드 여섯의 판정 사각형이 전부 1280x720 안이고 넓이가 0이 아니다")
	t.eq(overlapping, 0, "어느 두 카드의 판정 사각형도 안 겹친다")

	# 「판정 사각형이 그림보다 사방 8px 크다」
	var pad_bad := 0
	for k in Rules.CARDS_PER_WIN:
		var drawn := view.card_rect_of(k)
		var hit := view.card_hit_rect_of(k)
		if not hit.encloses(drawn):
			pad_bad += 1
		if not is_equal_approx(hit.size.x - drawn.size.x, 2.0 * Look.PRESS_HIT_PAD_PX):
			pad_bad += 1
		if not is_equal_approx(hit.size.y - drawn.size.y, 2.0 * Look.PRESS_HIT_PAD_PX):
			pad_bad += 1
	t.eq(pad_bad, 0, "판정 사각형이 그림보다 사방으로 정확히 %.0fpx 크다" % Look.PRESS_HIT_PAD_PX)

	# 「가장 작은 누름이 220x64보다 작지 않다」
	t.ok(Look.CARD_SIZE_PX.x >= SMALLEST_PRESS_BEFORE.x and Look.CARD_SIZE_PX.y >= SMALLEST_PRESS_BEFORE.y,
		"카드가 %.0fx%.0f 이고 220x64 보다 크다" % [Look.CARD_SIZE_PX.x, Look.CARD_SIZE_PX.y])

	t.eq(view.card_rect_of(-1), Rect2(), "없는 카드의 사각형은 빈 Rect2 다")
	t.eq(view.card_rect_of(Rules.CARDS_PER_WIN), Rect2(), "범위 밖 카드도 빈 Rect2 다")

	# The hit test itself, at each card's own hit-rect centre.
	for k in Rules.CARDS_PER_WIN:
		t.eq(view.card_at(view.card_hit_rect_of(k).get_center()), k,
			"%d번 카드 가운데를 찍으면 %d번이 나온다" % [k, k])
	t.eq(view.card_at(Vector2(20.0, 700.0)), -1, "빈 데를 찍으면 -1 이다")
	view.free()


# -- the two channels a taken card and an unreachable one are told apart on ---------------------------

func _the_alpha_channel(t) -> void:
	var r := _won_run()
	var view := RewardView.new()
	view.bind(r)

	# 「고를 수 있는 카드와 못 고르는 카드의 알파가 3배 넘게 다르다」 — take both picks first, so card 2
	# reads as genuinely unreachable rather than merely untaken.
	r.take_card(0)
	r.take_card(1)
	var live := view._card_fill(2)
	t.ok(live.a <= Look.PRESS_ALPHA_OFF + Rules.EPS,
		"둘을 다 고른 뒤 셋째 칸도 알파 %.2f 로 못 고르는 칸과 같은 흐림이다" % live.a)

	var fresh_run := _won_run()
	var fresh_view := RewardView.new()
	fresh_view.bind(fresh_run)
	var pressable := fresh_view._card_fill(0)
	var not_pressable := view._card_fill(2)
	t.ok(pressable.a / not_pressable.a >= 3.0,
		"고를 수 있는 카드가 못 고르는 카드보다 알파가 3배 넘게 밝다 (%.2f / %.2f = %.1f배)"
			% [pressable.a, not_pressable.a, pressable.a / not_pressable.a])
	fresh_view.free()
	view.free()


## ⚠⚠ 「종 글자가 카드 위에서 읽힌다」 — WCAG relative-luminance contrast, both halves. `COL_SPECIES`
## used to be picked for PAIRWISE separation alone (`look.gd`'s own old comment said so) and never
## against `COL_CARD`, the one surface it is ever drawn on (`reward_view._paint_card_species`,
## `refit_view._paint_cell_species`) — the three landed at 1.03:1 / 1.16:1 / 1.56:1 against the card,
## under WCAG's own 3:1 floor for large text, while every pairwise ratio still cleared 1.4. Mutation:
## restore the old triple `[Color(0.796,0.596,0.322), Color(0.451,0.780,0.851), Color(0.373,0.596,0.941)]`
## — every one of those fails the card-contrast row below and none fail the pairwise row, which is
## exactly why a check that only ever compared species to species could not see this.
func _the_species_colours_read(t) -> void:
	# ⚠⚠ **The table this measures is `COL_RARITY` now and it has four rows, not three** (2026-08-24).
	# **Both constraints are carried across unchanged** — pairwise separation AND contrast against the
	# one surface it is drawn on — because the failure the paragraph above records is a property of
	# "coloured text on a light card", not of what the colours happened to mean.
	var low := 0
	for a in Look.COL_RARITY.size():
		for b in range(a + 1, Look.COL_RARITY.size()):
			if _contrast(Look.COL_RARITY[a], Look.COL_RARITY[b]) < 1.30:
				low += 1
	# ⚠⚠ **1.4 -> 1.30, and the number moved because it became UNREACHABLE, not because it was
	# inconvenient.** `COL_CARD`'s luminance caps a readable tone at 0.0671; four tones spread between
	# 0 and that cap sit at most (0.1171/0.05)^(1/3) = 1.328 apart. The old floor was measured for
	# THREE species and three fit under it with room. **The rarity word on the card is what actually
	# separates them** — see `look.gd`'s own paragraph beside the table.
	t.eq(low, 0, "등급 색 넷이 서로 대비 1.30:1 이상이다 (자가 점검 — 카드 위 대비와는 다른 값이다)")

	var unreadable := 0
	for s in Look.COL_RARITY.size():
		if _contrast(Look.COL_RARITY[s], Look.COL_CARD) < 3.0:
			unreadable += 1
	t.eq(unreadable, 0,
		"등급 색 넷 전부 카드 배경(COL_CARD)과 WCAG 대비 3:1 이상이다 — 이름은 안 읽히면 아무 값도 아니다")

	t.eq(Look.COL_RARITY.size(), Rules.RARITY_WEIGHT.size(),
		"색 수와 등급 수가 같다 — 한쪽만 늘면 색 없는 등급이 생긴다")


## WCAG 2.x relative-luminance contrast ratio, `(L_light + 0.05) / (L_dark + 0.05)`.
func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi := maxf(la, lb)
	var lo := minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


## ⚠⚠ 「카드 화면도 배경에서 떠오른다」 — both ends, `map_view`'s own scene-wash shape, reused. Floor:
## right after `bind` the wash is still up, near-full alpha. Ceiling: aged past `SCENE_FADE_SEC` the
## leaf is not even CALLED (the `if wash > 0.0` guard `map_view`'s own `_paint_fade` site shares) — a
## duty bounded only above (never overlaps X) is a duty a deleted effect also satisfies; both ends are
## what a beat this section warns about needs.
func _the_screen_itself_fades_in(t) -> void:
	var r := _won_run()
	var spy := RewardSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(2)
	t.eq(spy.fades.size(), 1, "묶인 직후엔 화면 자체의 흐림이 아직 떠 있다")
	t.ok((spy.fades[0]["col"] as Color).a > 0.5,
		"그 흐림의 알파가 절반 넘게 짙다 (%.2f)" % (spy.fades[0]["col"] as Color).a)
	t.eq(spy.fades[0]["rect"], Rect2(Vector2.ZERO, Look.viewport_size_px()), "흐림이 화면 전체를 덮는다")

	spy._fx_step(Look.SCENE_FADE_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.fades.size(), 0, "SCENE_FADE_SEC 이 지나면 흐림 호출 자체가 없다 — 다 사라진 뒤에도 계속 그리지 않는다")

	t.root.remove_child(spy)
	spy.queue_free()


# -- the leaves, treed and pumped ----------------------------------------------------------------------

func _the_leaves_draw_what_they_were_handed(t) -> void:
	var r := _won_run()
	var spy := RewardSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(2)
	t.ok(spy.draws >= 1, "카드 화면의 _draw 가 트리 위에서 진짜 돌았다 (%d프레임)" % spy.draws)

	t.eq(spy.cards.size(), Rules.CARDS_PER_WIN, "카드 상자를 세 개 그렸다")
	# 「카드에 이름과 하는 일이 둘 다 찍힌다」
	t.eq(spy.parts.size(), Rules.CARDS_PER_WIN, "이름도 세 개 그렸다")
	t.eq(spy.species.size(), Rules.CARDS_PER_WIN, "효과 줄도 세 개 그렸다")
	var text_bad := 0
	for k in Rules.CARDS_PER_WIN:
		var item := int(r.cards[k])
		if str(spy.parts[k]["text"]) != Rules.item_name_of(item):
			text_bad += 1
		# ⚠ The effect line carries the rarity word in front of what the item does, so it is checked by
		# CONTAINMENT rather than by equality — the row is about the numbers coming off the table.
		if not str(spy.species[k]["text"]).ends_with(Rules.item_effect_text(item)):
			text_bad += 1
	t.eq(text_bad, 0, "카드마다 장비 이름과 효과가 그 카드의 실제 장비와 맞는다")
	t.eq(spy.marks.size(), 0, "고르기 전에는 표가 하나도 없다 (자가 점검)")

	# ⚠ **The hover and press rows have to run BEFORE any card is taken** — the run reaches `REFIT`
	# the moment the second pick lands, and `is_card_pressable` (which `set_hover`/`note_press` both
	# gate on) answers false for every card once it does. Card 2 is left untouched for exactly this.

	# 「호버하면 테두리가 3에서 6으로 간다」
	var rest_width := float(spy.cards[2]["width"])
	t.eq(rest_width, Look.PRESS_BORDER_WIDTH_PX, "쉬는 카드의 테두리가 기본 굵기다 (자가 점검)")
	spy.set_hover(spy.card_rect_of(2).get_center())
	spy._fx_step(Look.PRESS_HOVER_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(float(spy.cards[2]["width"]), Look.PRESS_HOVER_BORDER_WIDTH_PX,
		"호버한 카드의 테두리가 %.0fpx 로 굵어져서 화면까지 갔다" % Look.PRESS_HOVER_BORDER_WIDTH_PX)

	# 「누르면 0.96배로 눌렸다가 0.10초 뒤 돌아온다」
	var rest_rect: Rect2 = spy.cards[2]["rect"]
	spy.note_press(2)
	spy._fx_step(Look.PRESS_DOWN_SEC * 0.5)
	spy.queue_redraw()
	await t.pump_frames(1)
	var down_rect: Rect2 = spy.cards[2]["rect"]
	t.ok(down_rect.size.x < rest_rect.size.x - 3.0,
		"누른 카드가 화면에서 실제로 줄었다 (%.1f -> %.1f)" % [rest_rect.size.x, down_rect.size.x])
	t.ok(down_rect.size.x >= rest_rect.size.x * Look.PRESS_DOWN_SCALE,
		"그래도 %.2f배 밑으로는 안 줄었다" % Look.PRESS_DOWN_SCALE)
	spy._fx_step(Look.PRESS_DOWN_SEC * 0.6)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq((spy.cards[2]["rect"] as Rect2).size, rest_rect.size,
		"%.2f초가 지나면 카드가 정확히 쉬는 크기로 돌아온다" % Look.PRESS_DOWN_SEC)

	# 「가져간 카드에 표가 그려진다」 — ⚠ **`run.cards_taken[1]` is written directly, not through
	# `take_card`.** `take_card`'s SECOND call moves the run straight to `REFIT`, and `_draw` gates on
	# `run.state() == PICK` — so the real door can never hold two marks on screen at once long enough
	# to read them back. Poking the byte in is the same fixture shape `net_parts`'s
	# `_slot_reserves_are_filtered_by_slot` already uses: it isolates what THIS leaf does with two taken
	# cards from the sim's own screen-switching side effect, which is a separate claim `net_run` owns.
	# ⚠⚠ **Both marks are set by HAND and `take_card` is not called.** With `CARD_PICKS` at 1 the first
	# real pick leaves `PICK`, and this screen stops drawing the moment it does — so driving it through
	# the sim would test the transition instead of the leaf. What this row is about is the LEAF: two
	# taken flags, two marks.
	var taken := r.cards_taken
	taken[0] = 1
	taken[1] = 1
	r.cards_taken = taken
	# The mark's own growth beat ages off `_taken_age`, populated by `_fx_step` reading
	# `run.cards_taken` — which only just changed, so it has to run at least once before either mark
	# reads as grown at all.
	spy._fx_step(Look.CARD_TAKEN_GROW_SEC)
	spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(spy.marks.size(), 2, "둘 다 표시되면 표가 정확히 둘 그려졌다")
	var mark_bad := 0
	for m: Dictionary in spy.marks:
		if float(m["radius"]) <= 0.0:
			mark_bad += 1
		if (m["col"] as Color).a < 0.8 * Look.PRESS_ALPHA_ON:
			mark_bad += 1
	t.eq(mark_bad, 0, "표 둘 다 반지름이 있고 알파가 다 자란 값에 가깝다")
	t.root.remove_child(spy)
	spy.queue_free()

	# 「안내 글이 몇 장 골랐는지 말한다」
	var fresh_run := _won_run()
	var fresh_spy := RewardSpy.new()
	t.root.add_child(fresh_spy)
	fresh_spy.process_mode = Node.PROCESS_MODE_DISABLED
	fresh_spy.bind(fresh_run)
	fresh_spy.queue_redraw()
	await t.pump_frames(1)
	t.eq(fresh_spy.hints.size(), 1, "안내 글을 한 번 그렸다")
	t.ok(str(fresh_spy.hints[0]["text"]).contains("0"), "고르기 전 안내 글에 0이 있다")
	fresh_run.take_card(0)
	fresh_spy.queue_redraw()
	await t.pump_frames(1)
	t.ok(str(fresh_spy.hints[0]["text"]).contains("1"), "한 장을 고르면 안내 글이 1로 바뀐다")
	t.root.remove_child(fresh_spy)
	fresh_spy.queue_free()


# -- item: the reveal --------------------------------------------------------------------------------

## 「카드 화면이 열리면 카드가 하나씩 나타난다」 — floor: every card starts effectively invisible, not
## snapped straight to its resting alpha; the stagger: card 0 is already ahead of card 5 mid-reveal;
## ceiling: every card settles at its full, un-revealed alpha (read off `_card_fill` directly), so the
## beat never gets stuck dim. `MAP_NODE_FADE_SEC` / `MAP_REVEAL_STEP_SEC` are `map_view`'s own reveal
## constants, reused rather than redeclared.
##
## ⚠⚠ Bounded on BOTH ends on purpose — `combat-juice`'s own header names four beats this repo shipped
## bounded only above once, and deleting the whole animation stayed green under that shape.
func _the_cards_fade_in_staggered(t) -> void:
	var r := _won_run()
	var spy := RewardSpy.new()
	t.root.add_child(spy)
	spy.process_mode = Node.PROCESS_MODE_DISABLED
	spy.bind(r)
	spy.queue_redraw()
	await t.pump_frames(1)
	var alpha_bad := 0
	for k in Rules.CARDS_PER_WIN:
		if (spy.cards[k]["bg"] as Color).a > 0.05:
			alpha_bad += 1
	t.eq(alpha_bad, 0, "화면이 열린 첫 프레임에는 카드 여섯이 전부 알파 0에 가깝다 — 튀어나오지 않는다")

	# The stagger: age past card 0's own fade window, nowhere near card 5's start.
	spy._fx_step(Look.MAP_NODE_FADE_SEC * 0.6)
	spy.queue_redraw()
	await t.pump_frames(1)
	var a0 := (spy.cards[0]["bg"] as Color).a
	var a5 := (spy.cards[Rules.CARDS_PER_WIN - 1]["bg"] as Color).a
	t.ok(a0 > a5,
		"0번 카드가 마지막 카드보다 먼저, 더 진하게 나타났다 (%.2f > %.2f) — 한꺼번에 안 뜬다" % [a0, a5])
	t.ok(a5 <= 0.05, "마지막 카드는 이 시점에 아직 시작도 안 했다 (%.2f)" % a5)

	# The ceiling: age past the LAST card's own fade window entirely.
	var full := float(Rules.CARDS_PER_WIN - 1) * Look.MAP_REVEAL_STEP_SEC + Look.MAP_NODE_FADE_SEC
	spy._fx_step(full)
	spy.queue_redraw()
	await t.pump_frames(1)
	var settle_bad := 0
	for k in Rules.CARDS_PER_WIN:
		var shown := (spy.cards[k]["bg"] as Color).a
		var want := spy._card_fill(k).a
		if not is_equal_approx(shown, want):
			settle_bad += 1
	t.eq(settle_bad, 0, "다 나타나면 카드 여섯 다 원래 알파로 정확히 도착한다 — 흐린 채로 안 남는다")
	t.ok(Look.MAP_NODE_FADE_SEC >= 0.084 and Look.MAP_NODE_FADE_SEC <= 0.40,
		"카드 한 장의 등장이 다섯 프레임~0.40초다 (%.2f)" % Look.MAP_NODE_FADE_SEC)
	t.ok(Look.MAP_REVEAL_STEP_SEC >= 0.03 and Look.MAP_REVEAL_STEP_SEC < 0.084,
		"카드 사이 간격이 0.03초 이상, 다섯 프레임 밑이다 (%.2f) — 간격은 박자가 아니라 사이다" % Look.MAP_REVEAL_STEP_SEC)

	t.root.remove_child(spy)
	spy.queue_free()
