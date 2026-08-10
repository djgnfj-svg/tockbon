extends RefCounted
## `src/view/pick_layout.gd` — the three-pick window's coordinates
## (`levelup-and-three-picks.md`, Stage D).
##
## **`circle_window.gd`'s own header pins the reason this file exists at all**: `_draw()` used to be
## unmeasurable headless — not because of a null font (checked directly, harness-manager: a bare `Control`
## and the real `CircleWindow`, both untreed, both return a non-null `get_theme_default_font()` — Godot
## 4.7.1's default theme needs no tree at all), but because `run_nets.gd` itself never turned a single
## engine frame before quitting (see that file's own header, and `net_frame_runner.gd` for the fix and the
## proof). Judgment is still pushed into a static coordinate file the nets *can* call directly regardless —
## that part of the design was never about what a net *can* run, only about the drawing and the hit test
## reading the *same* function instead of two copies, and pixel-level "does it look right" staying verify-look's job.
##
## **`_gui_input()` is a different case — verify-read's own correction.** It needs no draw context: `size` is
## settable by hand, `Layout.*` is static, `Progress` is injectable, and `accept_event()` is harmless untreed.
## `_gui_input_drives_the_real_window_state` below calls it directly, outside the tree, the same way this
## repo already calls other non-`_draw` methods on untreed nodes elsewhere in the suite.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/pick_layout.gd")
const CircleLayout := preload("res://src/view/circle_layout.gd")
const Progress := preload("res://src/actor/progress.gd")
const ThreePick := preload("res://src/actor/three_pick.gd")
const ThreePickWindow := preload("res://src/view/three_pick_window.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const Character := preload("res://src/actor/character.gd")
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")
## **Borrowed, not copied** — `_scan_gd_files` (`net_progress.gd`'s own recursive `.gd` walker) and
## `_hits_to_kill` (`net_monster.gd`'s own fire-until-dead helper) each already exist for exactly the
## purpose Stage E's checks below need. A second copy of either is the same drift risk `NetDeterminism._strip`
## is already borrowed to avoid, one level up.
const NetProgress := preload("res://tests/nets/net_progress.gd")
const NetMonster := preload("res://tests/nets/net_monster.gd")

## How far inside a rect's own corner to probe — enough to stay clear of floating-point edge cases at the
## boundary itself, small enough that a hit test shrunk by a few pixels on any side still gets caught.
const CORNER_INSET_PX := 2.0

## A few representative window sizes — the real one, and a couple of others so a check does not accidentally
## hold only for the exact live dimensions.
##
## **The first entry is read from `Fx.PICK_RECT.size`, not written as a second copy of it.** A literal
## `Vector2(864.0, 372.0)` here is exactly the trap `net_render._window_uses_the_tuning_rect` exists to block
## for the assembly window's own dimensions — a hardcoded twin cannot go stale when the real constant moves,
## so a `PICK_RECT` regression (position or size) would perturb the drawing but never this file's own checks.
static var WINDOW_SIZES: Array[Vector2] = [
	Fx.PICK_RECT.size,
	Vector2(600.0, 300.0),
	Vector2(300.0, 200.0),
]


func run(t) -> void:
	_cards_stay_inside_the_window_and_do_not_overlap(t)
	_card_at_reads_the_same_rects_as_cards(t)
	_card_count_matches_a_real_drained_draw(t)
	_buttons_stay_inside_the_window_and_do_not_overlap_cards(t)
	_gui_input_drives_the_real_window_state(t)
	_card_rects_reads_the_live_draw_size(t)
	_layer_click_places_replaces_and_rejects_family_conflicts(t)
	_picked_card_click_returns_to_step_1(t)
	_confirmation_shows_after_a_placement_and_expires(t)
	_confirmation_can_be_dismissed_early_by_a_click(t)
	_a_fresh_pick_preempts_a_lingering_confirmation(t)
	_cancel_confirm_clears_it_without_touching_progress(t)
	_no_pushed_out_glyph_is_stashed_anywhere(t)
	_full_round_trip_pick_to_a_bigger_hit(t)
	await _card_picture_draws_every_glyph_with_a_rarity_ring(t)


## **The three card rects do not overlap and sit inside the window.** Widening a card into its neighbor's
## space, or past the window edge, is exactly the class of bug `net_circle`'s `RECT_EPS` idiom exists for —
## measured here with a plain `Rect2.encloses`/`intersects` pair since this window has no rotation or scale
## to fight, unlike that file's book pages.
func _cards_stay_inside_the_window_and_do_not_overlap(t) -> void:
	for size: Vector2 in WINDOW_SIZES:
		var area := Rect2(Vector2.ZERO, size)
		for count in [1, 2, 3]:
			var rects := Layout.cards(size, count)
			t.eq(rects.size(), count, "%s에서 카드 %d장을 요청하면 %d장이 나온다" % [size, count, count])
			for r: Rect2 in rects:
				t.ok(area.encloses(r), "%s / %d장 배치의 카드(%s~%s)가 창 안에 들어간다" % [
					size, count, r.position, r.end])
			for i in rects.size():
				for j in range(i + 1, rects.size()):
					t.ok(not rects[i].intersects(rects[j]),
						"%s / %d장 배치에서 카드 %d·%d가 안 겹친다" % [size, count, i, j])


## **`card_at()` and `cards()` must read the same rects** — walking every card's own center and confirming
## the hit test returns exactly that index is the only way to prove they are not two separately-computed
## copies that happen to agree today.
##
## **The center alone is not enough — verify-read's own finding.** Shrinking a card's hit box by a few pixels
## on every side was green here, because a center click is nowhere near the edge that shrank. Each rect's
## inset corners are probed too, so a hit box narrower than its drawn rect actually shows up.
func _card_at_reads_the_same_rects_as_cards(t) -> void:
	for size: Vector2 in WINDOW_SIZES:
		for count in [1, 2, 3]:
			var rects := Layout.cards(size, count)
			for i in rects.size():
				var r := rects[i]
				var hit := Layout.card_at(size, count, r.get_center())
				t.eq(hit, i, "%s / %d장 배치에서 카드 %d의 한가운데를 찍으면 %d가 나온다" % [size, count, i, i])
				# **The four inset corners** — a hit box shrunk on any one side loses exactly one of these
				#  while the center check above stays green, which is the whole gap this loop closes.
				for corner: Vector2 in [
						r.position + Vector2(CORNER_INSET_PX, CORNER_INSET_PX),
						Vector2(r.end.x - CORNER_INSET_PX, r.position.y + CORNER_INSET_PX),
						r.position + Vector2(CORNER_INSET_PX, r.size.y - CORNER_INSET_PX),
						r.end - Vector2(CORNER_INSET_PX, CORNER_INSET_PX),
				]:
					t.eq(Layout.card_at(size, count, corner), i,
						"%s / %d장 배치에서 카드 %d의 안쪽 모서리(%s)를 찍어도 %d가 나온다" % [size, count, i, corner, i])
			# Outside every card — including the empty-pool case — must miss.
			t.eq(Layout.card_at(size, 0, Vector2(1.0, 1.0)), -1, "%s에서 카드가 0장이면 어디를 찍어도 -1이다" % size)
			t.eq(Layout.card_at(size, count, Vector2(-50.0, -50.0)), -1,
				"%s / %d장 배치에서 창 밖을 찍으면 -1이다" % [size, count])


## **Renamed from `_card_count_matches_the_draw_size` — verify-read's own finding.** The old body asserted only
## `Layout.cards(size, 0).size() == 0`, an empty-list edge case with no draw anywhere in it; the name promised
## a link to a real draw's size that the body never made. This drives an actual `ThreePick.draw()` past the
## pool (the same technique `net_three_pick._fallback_takes_what_remains_without_repeating` already uses) to
## get a real fewer-than-3 result, and lays *that* count out — a 2-card (or 1-card) window must produce
## exactly that many non-overlapping cards, not 3 with a gap where the missing one would be (`pick_layout.gd`'s
## own header claim about `count`).
func _card_count_matches_a_real_drained_draw(t) -> void:
	t.eq(Layout.cards(Fx.PICK_RECT.size, 0).size(), 0, "0장 요청은 0장을 돌려준다 (죽지 않는다)")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# **`Glyph.PICKABLE`, not `Glyph.ALL`** — `draw()` reads the pickable pool (`glyph_defs.gd`'s own build
	#  note); the dummy family sits outside it and owning-or-not never moves this test's count.
	var owned: Array[int] = Glyph.PICKABLE.duplicate()
	owned.remove_at(0)
	t.eq(owned.size(), Glyph.PICKABLE.size() - 1, "하나만 빼고 다 가진 상태를 만들었다 (전제)")
	var drawn := ThreePick.draw(owned, rng)
	t.eq(drawn.size(), 1, "서고가 거의 빈 상태에서는 실제로 한 장만 뽑힌다 (전제)")

	var rects := Layout.cards(Fx.PICK_RECT.size, drawn.size())
	t.eq(rects.size(), 1, "한 장이 뽑히면 카드도 딱 한 장만 배치된다 (셋 그려놓고 하나만 채우지 않는다)")


## The decline/dice buttons sit inside the window and do not overlap each other or the card area.
func _buttons_stay_inside_the_window_and_do_not_overlap_cards(t) -> void:
	for size: Vector2 in WINDOW_SIZES:
		var area := Rect2(Vector2.ZERO, size)
		var decline := Layout.decline_rect(size)
		var dice := Layout.dice_rect(size)
		t.ok(area.encloses(decline), "%s에서 취소 버튼이 창 안에 들어간다" % size)
		t.ok(area.encloses(dice), "%s에서 주사위 버튼이 창 안에 들어간다" % size)
		t.ok(not decline.intersects(dice), "%s에서 취소·주사위 버튼이 안 겹친다" % size)

		for count in [1, 2, 3]:
			for r: Rect2 in Layout.cards(size, count):
				t.ok(not r.intersects(decline), "%s / %d장에서 카드가 취소 버튼과 안 겹친다" % [size, count])
				t.ok(not r.intersects(dice), "%s / %d장에서 카드가 주사위 버튼과 안 겹친다" % [size, count])


## **`_gui_input()` driven for real — verify-read's own correction to this file's own header.** Three things
## that were previously unmeasured entirely, because nothing called the click handler at all:
##  · **the decline button actually calls `Progress.decline()`.** `_declining_a_pick_leaves_the_circle_byte_
##    identical` (`net_render.gd`) proves the *effect* of declining is safe; nothing until now proved the
##    button itself *reaches* that call — deleting the button's `_progress.decline()` line entirely passed
##    every check that only drove `P`
##  · **the dice button is genuinely inert** — a click does not move `_picked_index` and does not close the pick
##  · **picking toggles off** — pressing the same picked card again clears the pick (this window's own comment,
##    the same idiom `circle_window._click_palette` already holds for the assembly window's palette)
##
## **Outside the tree on purpose** — the same discipline the rest of this suite holds. `setup()` injects
## `Progress` directly, `size` is set by hand (`_ready()` never runs untreed), and `Layout.*` — the only thing
## `_gui_input` actually consults for hit-testing — is static. `_draw()` is not called here — untreed was
## never the blocker on its own (this file's own header has the correction: the font is not null untreed,
## measured directly), but a frame still has to actually turn for it to run, which is `net_frame_runner.gd`'s
## job to prove, not this file's — so rarity, dummy-marking and effect-text judgment stay pushed into
## `pick_layout.gd`/`fx_tuning.gd` instead of living here.
func _gui_input_drives_the_real_window_state(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 1
	t.ok(pr.open_pick([]), "뽑기가 열렸다 (전제)")
	t.eq(pr.drawn().size(), 3, "세 장이 뽑혔다 (전제)")

	var win := ThreePickWindow.new()
	win.setup(pr, SpellCircle.new())
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, pr.drawn().size())
	t.eq(win.get("_picked_index"), -1, "처음엔 아무 카드도 안 골랐다 (전제)")

	# -- picking, by center --
	_click(win, rects[0].get_center())
	t.eq(win.get("_picked_index"), 0, "카드 0의 한가운데를 누르면 그 카드가 골린다")

	# -- pressing the same picked card again drops the pick --
	_click(win, rects[0].get_center())
	t.eq(win.get("_picked_index"), -1, "같은 카드를 다시 누르면 골랐던 게 풀린다 (조립창 팔레트와 같은 관용구)")

	# -- picking, by an inset corner, not just the center --
	var corner := rects[1].position + Vector2(CORNER_INSET_PX, CORNER_INSET_PX)
	_click(win, corner)
	t.eq(win.get("_picked_index"), 1, "카드 1의 안쪽 모서리를 눌러도 그 카드가 골린다")

	# -- the dice button is inert: it neither changes the pick nor closes the window --
	_click(win, Layout.dice_rect(win.size).get_center())
	t.eq(win.get("_picked_index"), 1, "주사위를 눌러도 고른 카드가 그대로다")
	t.ok(pr.is_pick_open(), "주사위를 눌러도 뽑기가 안 닫힌다 (dice_left 0 — 아무 것도 안 한다)")

	# -- the decline button actually calls Progress.decline() --
	_click(win, Layout.decline_rect(win.size).get_center())
	t.ok(not pr.is_pick_open(), "취소 버튼을 누르면 뽑기가 실제로 닫힌다")
	t.eq(pr.drawn().size(), 0, "취소하면 뽑힌 목록도 비워진다")

	win.free()


## Builds a left-click-press `InputEventMouseButton` at `pos` (window-local) and drives `_gui_input` with it
## directly — the same event shape `_gui_input`'s own `mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed`
## guard checks, so a wrong button or a release event would silently do nothing here too, the same as in play.
func _click(win: Control, pos: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pos
	win.call("_gui_input", mb)


## **`three_pick_window._card_rects()` — the rects `_draw()` actually paints, pulled out on purpose so a net
## can call it directly.** This file's checks don't turn a frame, so `_draw()` itself doesn't run here (the
## font is not the reason — see the header correction above), and a
## text-scan for `"Layout.cards(size, drawn.size())"` was tried first and **evaded**: adding an unused decoy
## call with the real expression next to a hardcoded `Layout.cards(size, 3)` satisfied the scan while the
## drawing still used the wrong count. Calling `_card_rects()` and reading its actual return value cannot be
## evaded that way — there is no text pattern to satisfy, only a real count to compute.
func _card_rects_reads_the_live_draw_size(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.open_pick([])
	t.eq(pr.drawn().size(), 3, "세 장이 뽑혔다 (전제)")

	var win := ThreePickWindow.new()
	win.setup(pr, SpellCircle.new())
	win.size = Fx.PICK_RECT.size

	var rects: Array = win.call("_card_rects")
	t.eq(rects.size(), 3, "세 장이 뽑히면 카드 자리도 세 곳이다")
	t.eq(rects, Layout.cards(win.size, pr.drawn().size()),
		"`_card_rects()`가 `Layout.cards()`를 뽑힌 실제 장수로 부른 것과 정확히 같다")
	win.free()

	# **The actual mutation this check exists to catch** — a drained-to-1 draw (the same technique
	#  `_card_count_matches_a_real_drained_draw` and `net_three_pick`'s own fallback check use) must yield
	#  exactly one rect from `_card_rects()`, not three with two empty. A hardcoded `3` inside `_card_rects()`
	#  (or inside `_draw()`, before this function existed to hold the count logic) would fail this line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var owned: Array[int] = Glyph.PICKABLE.duplicate()
	owned.remove_at(0)
	var drawn := ThreePick.draw(owned, rng)
	t.eq(drawn.size(), 1, "서고가 거의 빈 상태에서는 실제로 한 장만 뽑힌다 (전제)")

	var pr2 := Progress.new()
	pr2.pending_picks = 1
	# `Progress.open_pick` always draws against an empty `owned` in this test's other checks — here the point
	#  is only `_card_rects()`'s own count logic, so the drawn list is written directly rather than routed
	#  through a second, unrelated near-full circle just to reach the same 1-card shape.
	pr2.set("_drawn", drawn)
	t.eq(pr2.drawn().size(), 1, "Progress에 한 장짜리 뽑기 상태를 직접 심었다 (전제)")

	var win2 := ThreePickWindow.new()
	win2.setup(pr2, SpellCircle.new())
	win2.size = Fx.PICK_RECT.size
	var rects2: Array = win2.call("_card_rects")
	t.eq(rects2.size(), 1, "한 장이 뽑히면 `_card_rects()`도 딱 한 자리만 낸다 (셋 내놓고 하나만 채우지 않는다)")
	win2.free()


# ══════════════════════════════════════════════════════════════════
#  Stage E — step 2, the layer choice
# ══════════════════════════════════════════════════════════════════

## **Placement goes through `spell_circle.place_glyph()` and nothing else** (that file's own header) — this
## drives the real click, through `_gui_input`, and reads the result off the real `SpellCircle`, not off any
## state this window might hold. Three claims in one pass, because they share one setup:
##  · **placing into an empty layer succeeds**
##  · **the same family already sitting on a *different* layer is rejected, and visibly so** (`_reject`) —
##    not silently, the Stage D screen lesson one level up (a card reading as identical to its siblings was
##    a real defect; a click doing nothing with no reason shown is the same disease)
##  · **placing over the *same* layer's own family replaces**, and `glyph_list().size()` does not grow
func _layer_click_places_replaces_and_rejects_family_conflicts(t) -> void:
	# **A round circle explicitly** — `SpellCircle.new()` alone is `CIRCLE_NONE` now (Stage 3's empty boot).
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.eq(circle.layer_count(), 2, "기본 진은 2층이다 (전제)")
	t.ok(circle.place_glyph(0, Glyph.SPREAD_C), "0층에 확산(일반)을 미리 놓았다 (전제)")
	t.eq(circle.glyph_list().size(), 1, "목록에 하나 있다 (전제)")

	var pr := Progress.new()
	pr.pending_picks = 1
	# A known draw, not a random one — `net_three_pick` owns the draw rule itself.
	pr.set("_drawn", [Glyph.SPREAD_R, Glyph.BLAST_C, Glyph.DUMMY_U] as Array[int])
	t.ok(pr.is_pick_open(), "뽑기가 열렸다 (전제)")

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size

	# -- pick card 0 (확산 희귀) -> step 2 --
	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	t.eq(win.get("_picked_index"), 0, "확산(희귀) 카드를 골랐다 (전제)")

	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	t.eq(slots.size(), 2, "층 자리가 둘이다 (전제)")

	# -- layer 1 is empty, but the family (확산) already sits on layer 0 -> rejected, visibly --
	_click(win, circle_rect.position + slots[1])
	t.eq(circle.glyph_at(1), Glyph.GLYPH_NONE, "계열 충돌이면 1층은 그대로 비어 있다")
	t.eq(circle.glyph_list().size(), 1, "목록 크기도 그대로다 (거절됐으니 늘지 않는다)")
	t.ok(win.get("_reject"), "거절이 화면에 표시된다 (조용히 무시되지 않는다 — 이 검사의 핵심)")
	t.ok(pr.is_pick_open(), "거절돼도 뽑기는 그대로 열려 있다")
	t.eq(pr.pending_picks, 1, "거절되면 대기 수도 그대로다")
	t.eq(win.get("_picked_index"), 0, "거절돼도 고른 카드는 그대로다 (풀리지 않는다)")

	# -- a harmless click (the dice button — inert either way) still clears the stale rejection --
	#  **Not only a successful placement clears it.** `_gui_input`'s own comment claims "there is no path
	#  that leaves an old message on screen" — measured: removing the top-of-function `_reject = false` line
	#  was green everywhere else, because every *other* check here only ever follows a rejection with either
	#  nothing or a successful placement, never a click that does nothing at all.
	_click(win, Layout.dice_rect(win.size).get_center())
	t.ok(not win.get("_reject"), "아무 효과 없는 클릭(주사위) 한 번으로도 거절 표시가 꺼진다")
	t.eq(win.get("_picked_index"), 0, "그리고 고른 카드는 그대로다 (주사위는 아무것도 안 바꾼다)")

	# -- layer 0 already holds the *same* family -> this is a replace, not a second member --
	_click(win, circle_rect.position + slots[0])
	t.eq(circle.glyph_at(0), Glyph.SPREAD_R, "같은 층을 누르면 실제로 교체된다")
	t.eq(circle.glyph_list().size(), 1, "교체는 목록 크기를 늘리지 않는다 (추가가 아니다)")
	t.ok(not win.get("_reject"), "성공하면 거절 표시가 꺼진다")
	t.ok(not pr.is_pick_open(), "성공하면 뽑기가 닫힌다")
	t.eq(pr.pending_picks, 0, "성공하면 대기 수가 정확히 하나 줄었다")
	t.eq(win.get("_picked_index"), -1, "성공하면 고른 카드도 풀린다 (다음 뽑기를 위해)")

	win.free()


## **Step 2's "back" — click the picked card's own corner (shrunk into `picked_card_rect`) and step 1
## returns**, the same "press what is placed and it comes back out" idiom the step-1 card toggle already
## holds, one level up (a *pick*, not a placement, coming back out).
func _picked_card_click_returns_to_step_1(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.open_pick([])
	t.eq(pr.drawn().size(), 3, "세 장이 뽑혔다 (전제)")

	var win := ThreePickWindow.new()
	win.setup(pr, SpellCircle.new())
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	t.eq(win.get("_picked_index"), 0, "카드 0을 골랐다 (전제 — 2단계다)")

	_click(win, Layout.picked_card_rect(win.size).get_center())
	t.eq(win.get("_picked_index"), -1, "축소된 카드를 다시 누르면 1단계로 돌아간다")
	t.ok(pr.is_pick_open(), "돌아가도 뽑기 자체는 여전히 열려 있다 (취소가 아니다)")
	t.eq(pr.drawn().size(), 3, "뽑힌 목록도 그대로 세 장이다 (아무것도 소비되지 않았다)")

	win.free()


## **Confirmation — real, testable state, not `_draw()`-only.** `is_showing()`/`_confirm_glyph`/
## `_confirm_layer`/`CONFIRM_FRAMES` are plain fields and methods, not the drawing itself — callable and
## readable directly, the same as `_picked_index`/`_reject` already are. Two claims:
##  · **the window keeps showing after a successful placement**, even though `Progress.is_pick_open()` has
##    already gone false — the gap `is_showing()` exists to close (verify-look's own finding: "the window
##    just vanishes" was the whole of the prior confirmation)
##  · **it expires on its own** after `CONFIRM_FRAMES` driven `_process()` ticks
func _confirmation_shows_after_a_placement_and_expires(t) -> void:
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.set("_drawn", [Glyph.DUMMY_U, Glyph.BLAST_C, Glyph.SPREAD_C] as Array[int])

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size
	t.ok(win.is_showing(), "뽑기가 열려 있으니 카드를 고르기 전(1단계)에도 이미 보인다 (전제)")
	t.eq(win.get("_confirm_glyph"), Glyph.GLYPH_NONE, "아직 확인 화면은 아니다 (전제)")

	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(win, circle_rect.position + slots[0])

	t.ok(not pr.is_pick_open(), "놓고 나면 뽑기 자체는 닫힌다 (전제)")
	t.ok(win.is_showing(), "그런데도 창은 여전히 보인다 (확인 화면 — Progress만 보면 이걸 놓친다)")
	t.eq(win.get("_confirm_glyph"), Glyph.DUMMY_U, "확인 화면이 실제로 놓은 문양을 기억한다")
	t.eq(win.get("_confirm_layer"), 0, "그리고 놓은 층도 기억한다")

	# **`tick_confirm()`, not `_process()`** — the countdown moved to `stage._physics_process()`'s own call
	#  chain (`tick_confirm()`'s own header: closing the one-frame seam between the idle and physics clocks),
	#  so driving `_process()` here would not move it at all.
	var frames: int = win.get("CONFIRM_FRAMES")
	t.ok(frames > 0, "CONFIRM_FRAMES가 0보다 크다 (전제 — 안 그러면 아래 루프가 아무것도 안 돈다)")
	for _i in frames:
		win.call("tick_confirm")
	t.ok(not win.is_showing(), "CONFIRM_FRAMES 틱이 지나면 저절로 닫힌다")

	win.free()


## A click during the confirmation afterglow dismisses it early — the timer is a floor, not a forced wait.
func _confirmation_can_be_dismissed_early_by_a_click(t) -> void:
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.set("_drawn", [Glyph.DUMMY_U, Glyph.BLAST_C, Glyph.SPREAD_C] as Array[int])

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(win, circle_rect.position + slots[0])
	t.ok(win.is_showing(), "확인 화면이 떴다 (전제)")

	_click(win, Vector2(1.0, 1.0))
	t.ok(not win.is_showing(), "아무 데나 눌러도 확인 화면이 즉시 닫힌다")

	win.free()


## **A fresh pick pre-empts a lingering confirmation — verify-read's own finding this was unmeasured.**
## Neutering the `if pick_open:` branch in `_process()` (so it never fires) passed the full suite: pressing
## P for a *second* pick while the first placement's confirmation is still showing used to leave `_draw()`
## painting the new three cards **and** the stale confirmation on top of them (`_draw_confirm` is gated only
## on `_confirm_ticks > 0`, not on whether a fresh pick has since opened). This drives that exact sequence
## and reads the state directly — `_draw()` itself still can't run headless, but the state it would read is
## real and inspectable.
func _a_fresh_pick_preempts_a_lingering_confirmation(t) -> void:
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var pr := Progress.new()
	pr.pending_picks = 2
	pr.set("_drawn", [Glyph.DUMMY_U, Glyph.BLAST_C, Glyph.SPREAD_C] as Array[int])

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(win, circle_rect.position + slots[0])
	t.ok(win.is_showing(), "확인 화면이 떴다 (전제)")
	t.eq(pr.pending_picks, 1, "대기가 하나 남아 있다 (전제 — 두 번째 뽑기를 열 수 있다)")

	t.ok(pr.open_pick([]), "확인 화면이 떠 있는 동안 새 뽑기를 연다 (전제)")
	win.call("_process", 1.0 / 60.0)
	t.eq(win.get("_confirm_glyph"), Glyph.GLYPH_NONE, "새 뽑기가 열리면 지난 확인 화면이 즉시 지워진다")
	t.eq(win.get("_confirm_layer"), -1, "그 층 기억도 지워진다")
	t.eq(win.get("_picked_index"), -1, "그리고 1단계(카드 셋)로 돌아간다 (아직 새 카드를 안 골랐다)")
	t.ok(win.is_showing(), "그래도 창 자체는 계속 보인다 (새 뽑기가 열려 있으니까)")

	win.free()


## **`cancel_confirm()` — `stage._toggle_assembly()`'s own call, driven directly.** Without this, pressing
## Tab during the afterglow would leave the pick window `is_showing() == true` while the assembly window also
## opens — both windows visible at once, the exact class `net_render._opening_one_window_closes_the_other`
## exists to prevent. **It must not touch `Progress`** — the pick already closed for real when `take()` ran;
## `cancel_confirm()` only clears this window's own after-the-fact display state.
func _cancel_confirm_clears_it_without_touching_progress(t) -> void:
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.set("_drawn", [Glyph.DUMMY_U, Glyph.BLAST_C, Glyph.SPREAD_C] as Array[int])

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, pr.drawn().size())
	_click(win, rects[0].get_center())
	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(win, circle_rect.position + slots[0])
	t.ok(win.is_showing(), "확인 화면이 떴다 (전제)")
	var pending_before := pr.pending_picks

	win.call("cancel_confirm")
	t.ok(not win.is_showing(), "cancel_confirm()이 확인 화면을 닫는다")
	t.eq(pr.pending_picks, pending_before, "그리고 대기 수는 안 건드린다 (이미 소비된 뒤였다 — 전제)")

	win.free()


## Acceptance 7b — **"There is nowhere for the old one to go and no code that could hold it."** The plan's
## own words: measured as the **absence of a container**, not as a behavior — weak by nature (a rename could
## dodge a naive text match), written knowing that (the plan's own admission).
##
## **Widened twice after verify-read's own three evasions passed the narrower version**: an untyped
## `var _pushed_out := []` in the very file the old version read, a `Dictionary` in that same file, and a
## correctly-typed `Array[int]` in a **third file the old version never opened at all.** Both the **pattern**
## (it matched only `var name: Array[...]`) and the **scope** (it opened only two named files) had to widen —
## the same "widen the scan, not the exemption" fix `net_progress._dice_left_is_zero_and_inert` already
## needed once, and (per verify-read) this file's own `mouse_filter` scan needed a second time. Both times the
## fix was `net_progress._scan_gd_files("res://src")`; borrowed here too, not copied a third time.
##
## **`const` is not scanned — only `var`/`static var`.** A stash is mutation over time; an immutable table
## (`Fx.GLYPH_TINT`, `Glyph.DEFS`, every lookup dictionary this repo already has dozens of) cannot become one,
## so scanning `const` would drown this check in the codebase's ordinary data tables for no safety gained.
##
## **The known-good declarations are named, not silently allowed** — the same idiom `net_render.INTERACTIVE`/
## `OUT_OF_TREE_SIZE_ZERO` already hold. Every one of these predates this feature or is a different, already-
## understood piece of *current* state, not a record of what left it (`spell_circle._layers`/`_runes` are the
## circle's **current** slots — that file's own header already draws the "not a stash" line for them).
func _no_pushed_out_glyph_is_stashed_anywhere(t) -> void:
	# **Anchored to column 0 (`(?m)^`), not merely to the word `var`** — the first version matched *every*
	#  local, tab-indented `var x := []` inside a function body too (measured: 14 files, mostly ordinary
	#  locals like `var out`, `var pts`, `var e` — a stash-detector that fires on the word "var" is not a
	#  stash detector at all). GDScript's own indentation rule makes this reliable, not merely stylistic: a
	#  class-level field is **always** at column 0, a local is **never** at column 0 in this codebase's style,
	#  and the language itself enforces the second half of that.
	#
	# **A leading `@annotation` is consumed before `var` too — verify-read's own fourth evasion.**
	# `@export var _pushed_out: Array[int] = []` on one line does not start with `var` at column 0, it starts
	# with `@export` — the converse of "a class field is always at column 0" ("a class field always starts
	# with the literal word `var`") is false, and `@export`/`@onready`/etc. are the most idiomatic class-level
	# declarations in GDScript. The two-line form (`@export` alone, `var ...` on the next line) was already
	# caught — that `var` line starts at column 0 regardless of what sits above it; only the one-line form
	# needed this widening.
	var re_typed := RegEx.new()
	t.eq(re_typed.compile(
			"(?m)^(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?var\\s+(\\w+)\\s*:\\s*" +
			"(Array(?:\\[[^\\]]*\\])?|Dictionary|Packed[A-Za-z]*Array)\\b"),
		OK, "타입 있는 컬렉션 선언 패턴이 컴파일된다 (전제)")
	var re_literal := RegEx.new()
	t.eq(re_literal.compile(
			"(?m)^(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?var\\s+(\\w+)\\s*:?=\\s*(\\[|\\{)"),
		OK, "타입 없이 리터럴로 추론되는 컬렉션 선언 패턴이 컴파일된다 (전제)")

	# **Every evasion actually bites first** — an uninverted check proves "it runs", not "it measures".
	t.ok(re_typed.search("var _pushed_out: Array[int] = []") != null, "기본형을 문다 (전제)")
	t.ok(re_typed.search("static var _pushed_out: Array[int] = []") != null,
		"static var도 문다 (전제 — 회피 3, 세 번째 파일에서 나온 형태)")
	t.ok(re_typed.search("var _pushed_out: Dictionary = {}") != null,
		"Dictionary도 문다 (전제 — 회피 2)")
	t.ok(re_literal.search("var _pushed_out := []") != null,
		"타입 없는 배열 리터럴도 문다 (전제 — 회피 1)")
	t.ok(re_literal.search("var _pushed_out := {}") != null, "타입 없는 사전 리터럴도 문다 (전제)")
	t.ok(re_typed.search("@export var _pushed_out: Array[int] = []") != null,
		"@export가 앞에 붙어도 문다 (전제 — 회피 4)")
	t.ok(re_typed.search("@onready var _pushed_out: Array[int] = []") != null,
		"@onready가 앞에 붙어도 문다 (전제)")
	t.ok(re_typed.search("@export_range(0, 10) var _pushed_out: Array[int] = []") != null,
		"괄호 딸린 어노테이션(@export_range(...))도 문다 (전제)")
	t.ok(re_typed.search("if kind == Array[int]:") == null, "비교문은 안 문다 (오탐이 아니다 — 전제)")
	# **The column-0 anchor's own bite** — an indented local (every function body in this codebase's style)
	#  must **not** match; that is the exact false-positive flood the anchor exists to cut off.
	t.ok(re_literal.search("\tvar out: Array[int] = []") == null,
		"들여쓴 지역변수는 이 패턴이 안 문다 (전제 — 앵커가 없으면 여기서 14개 파일이 오탐 났었다)")

	# **Every entry here predates this feature or belongs to state this doc's own boundary already names**
	#  (monster bookkeeping, particle/trail pools, the circle's own *current* slots — none of them a record of
	#  a glyph that left a layer). Not hand-audited from memory — this is the exact list `_scan_gd_files`
	#  returns today; add a real field anywhere in `src/` and this test names the file, so the allowlist can
	#  never silently grow to cover something that should have been questioned.
	# **`_reward_pending` (`stage1-bosses.md` Stage I) added here, deliberately, not by widening a regex to
	#  miss it.** It is boss-death bookkeeping (keyed by monster kind — which bosses have died and not yet had
	#  their reward taken), the same shape `world_step.gd`'s own `_died_kind`/`_monsters` entries below already
	#  are — not a record of a glyph that left a spell layer, so it is not what this file's own no-inventory
	#  check exists to catch.
	var allow: Dictionary = {
		# **`_owned_runes` (`rune-lock-and-receiving.md`, Stage A) added here, deliberately** — the same
		#  discipline `_reward_pending`'s own comment names: a record of which runes have been granted, not a
		#  glyph that left a spell layer, so it is not what this file's no-inventory check exists to catch
		#  (`docs/decisions/no-inventory.md`'s own exception for exactly this field).
		# **`_unlocked` (`research-bench-unlocks.md`) added here, deliberately, and not by widening the regex
		#  to miss it** — a set of what has been bought at the research bench, keyed by `UnlockDefs` id. The
		#  same argument `_owned_runes` one line up already makes: it is a record of a purchase, not of a
		#  glyph that left a spell layer, which is what this file's no-inventory check exists to catch.
		# **`_owned_circles` (`onboarding-and-palette-tabs.md`, Stage 2) added here, deliberately, the same
		#  shape and the same reason as `_owned_runes` above** — 삼각 is not owned at boot (user confirmed),
		#  so the palette needs a record of which circles have been granted, not of a glyph that left a spell
		#  layer, which is what this file's no-inventory check exists to catch.
		"res://src/actor/progress.gd":
			["_drawn", "_owned_circles", "_owned_runes", "_reward_pending", "_unlocked"],
		"res://src/actor/spell_circle.gd": ["_layers", "_runes"],
		"res://src/actor/world_step.gd": ["_died_kind", "_died_x", "_died_y", "_monsters", "_queue"],
		# **`monster_placement.gd` added here, deliberately** (`monster-placement-stage1.md`,
		#  Stages A+B) — placement bookkeeping keyed by row index (which
		#  row is spent, which row's monster died, the wake hysteresis bit), the exact shape
		#  `world_step.gd`'s own `_monsters`/`_died_kind` entries one line up already are. Not a record of
		#  a glyph that left a spell layer, which is what this file's no-inventory check exists to catch.
		# **`_trigger_tx` added here, deliberately** (`boss-entrance-and-hp-bar.md`, Stage A) — one more
		#  parallel row-index array, the boss entrance trigger tile (`-1` when a row has none). The same
		#  bookkeeping shape as `_tx`/`_kind` beside it, not a record of a glyph that left a spell layer.
		"res://src/actor/monster_placement.gd":
			["_id_to_row", "_kind", "_monster_id", "_primed", "_spent", "_trigger_tx", "_tx"],
		"res://src/view/blast_fx.gd": ["_flashes", "_pillars"],
		# **`_dust` added here, deliberately** (사용자 요청 — 「캐릭터가 움직일 때 뒤에 먼지」) — the same idiom
		#  `blast_fx.gd`'s own `_flashes`/`_pillars` one line up already are: short-lived screen-only particles,
		#  aged and drawn from a plain array with no per-particle node. Not a record of a glyph that left a
		#  spell layer, which is what this file's no-inventory check exists to catch.
		"res://src/view/character_view.gd": ["_dust"],
		# **`ROWS` added here, deliberately, and it is the one entry that is a `static var` only because a
		#  net needs it to be.** It is the room table — map content, the shelf `terrain_map_generated.gd`
		#  and `stage1_monsters.gd` sit on, and every other table in that file is `const`. The chain between
		#  stages can only be driven **into a second stage**, and the game has one; `net_stages` appends a
		#  synthetic row, walks the chain into it, and pops it (that file's own header). Nothing in `src/`
		#  writes it. Not a record of a glyph that left a spell layer, which is what this check exists to catch.
		"res://src/stage/stage_defs.gd": ["ROWS"],
		# **`_socket_glyph_tex` added here, deliberately** (`triangle-circle-to-game.md` step 6) — glyph id
		#  -> loaded texture, the same shape `spell_view._bolt_tex`/`research_window._icons` already are.
		#  Loaded art is not a glyph that left a spell layer, which is what this file's no-inventory check
		#  exists to catch.
		# **`_ring_tex`/`_rune_tex`/`_icon_tex` here for the same reason as `_socket_glyph_tex`** — loaded art
		#  keyed by glyph id and element id. Textures on a shelf, not a glyph that left a spell layer.
		#  **Sorted** — this check compares the two lists as sorted arrays.
		"res://src/view/circle_window.gd":
			["_icon_tex", "_ring_tex", "_rune_tex", "_socket_glyph_tex"],
			# **`_socket_glyph_tex` added here too, deliberately** — the same cache, the same loader
			#  (`CircleWindow.load_socket_glyph_tex()`), now also read by this window's own card picture
			#  (`three_pick_window._draw_pick_card_glyph`). Loaded art, not a record of a glyph that left a
			#  spell layer — the same reasoning `circle_window.gd`'s own entry above already gives.
			# **`_ring_tex` added here too, deliberately** — the same ring-art cache `circle_window.gd`'s own
			#  entry above already lists, loaded by the same window base class. Loaded art, not a stash.
			"res://src/view/three_pick_window.gd": ["_ring_tex", "_socket_glyph_tex"],
		# **The six animation fields added here, deliberately** — the same discipline `_reward_pending`'s own
		#  comment names. `_anim`/`_prev_x`/`_prev_reload`/`_attack_left`/`_hurt_left` are all keyed by
		#  **monster id** and hold a frame counter, and `_anim_sheets` is loaded art; none of them is a record
		#  of a glyph that left a spell layer, which is what this file's no-inventory check exists to catch.
		"res://src/view/monster_view.gd": [
			# **`_prev_asleep`/`_wake_marks` are in this list deliberately** — the waking presentation
			#  (`left-run-clumps-and-platforms.md`, Screen). One is a per-id previous-frame bool, the exact
			#  shape `_prev_hp`/`_prev_reload` already are; the other is a list of short-lived view
			#  effects, the exact shape `_death_pops` is. Neither is a glyph that left a spell layer.
			#  **Sorted** — this check compares the two lists as sorted arrays.
			"_anim", "_anim_sheets", "_attack_left", "_corpses", "_death_pops", "_dmg_numbers",
			"_flash_left", "_hurt_left", "_prev_asleep", "_prev_hp", "_prev_melee_cd", "_prev_reload",
			"_prev_x",
			"_sheets", "_wake_marks",
		],
		"res://src/view/spell_view.gd": ["_bolt_tex", "_trails"],
		# **`_seats` added here, deliberately** — the town's three fixture positions, read once out of
		#  `town_map.FIXTURE_TILES` (level content). A room's furniture is not a glyph that left a spell
		#  layer, which is what this file's no-inventory check exists to catch.
		"res://src/view/town_view.gd": ["_seats", "_sprites"],
		# **`_icons` added here, deliberately** — five loaded ui textures keyed by name, the same shape
		#  `_sprites` one line up already is. Loaded art is not a glyph that left a spell layer.
		"res://src/view/research_window.gd": ["_icons"],
		# **`_play_counts`/`_players` added here, deliberately** (the "약하지만" sound pass). Neither is a
		#  record of a glyph that left a spell layer, which is what this file's no-inventory check exists to
		#  catch: `_players` is a fixed pool of `AudioStreamPlayer` node references (the same shape
		#  `circle_window._icon_tex` above is — a shelf of engine objects, not game state), and `_play_counts`
		#  is a running tally of how many times each sound name was asked to play (headless-measurable
		#  "did it ring", `sfx_bank.gd`'s own header) — a counter, not an inventory.
		"res://src/view/sfx_bank.gd": ["_play_counts", "_players"],
	}

	var files := NetProgress.new()._scan_gd_files("res://src")
	t.ok(files.size() > 0, "src/ 아래에서 .gd 파일을 찾았다 (%d개 — 전제)" % files.size())

	var by_file: Dictionary = {}
	for path: String in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw := f.get_as_text()
		f.close()
		if raw.contains("\"\"\""):
			continue # a triple-quoted string would defeat the stripper — none exist under src/ today
		var src := NetDeterminism._strip(raw)
		var names: Array[String] = []
		for m: RegExMatch in re_typed.search_all(src):
			names.append(m.get_string(1))
		for m: RegExMatch in re_literal.search_all(src):
			names.append(m.get_string(1))
		if not names.is_empty():
			names.sort()
			by_file[path] = names

	for path: String in by_file.keys():
		var found: Array = by_file[path]
		var want: Array = allow.get(path, [])
		t.eq(found, want,
			"%s에 선언된 배열/사전이 딱 %s뿐이다 (그 밖의 것이 곧 밀려난 문양의 스태시일 수 있다)" % [path, want])
	for path: String in allow.keys():
		t.ok(by_file.has(path) or (allow[path] as Array).is_empty(),
			"%s는 허용 목록에 있고 실제로도 그 선언들이 있다 (전제)" % path)


## **Acceptance 8 re-hung at the top level — the plan's own words.** level up -> open -> pick -> place ->
## `packed_glyphs()` changed -> fire -> the damage number changed. The one check that dies if any earlier
## stage regressed.
##
## **Widened after verify-read's own two findings**: the first version hand-set `Progress._drawn`, skipping
## level-up and the draw — the chain's own name promised "the check that dies if any earlier stage
## regressed" while its body started after Stage B. And it asserted `t.ok(boosted < common)`, a difference,
## never a number pinned on either side — exactly the "A/B nets that only compare" risk this plan's own risk
## table names. This version drives the real award loop (`net_progress`'s own kill-until-level idiom) and the
## real, unseeded-by-hand draw (only the RNG's own **seed** is chosen, by searching for one whose draw
## actually includes the card under test — the draw *rule* stays `net_three_pick`'s job; nothing here reads
## `_drawn` directly), then asserts absolute hit counts on both sides, read from the table the same way
## `net_monster._dummy_raises_hits_to_kill_a_pig` (Stage A's own home check) already does.
##
## **`BLAST_U`, not `DUMMY_U`** (`glyph-condense.md`'s build note on the three-pick pool) — the dummy left
## `Glyph.PICKABLE` the day condense arrived, so the card a real draw can actually hand the player is never a
## `MODIFY` any more. A `TERMINAL`'s `power_pct` composes only onto **the blast it makes**, never onto a
## direct segment hit (`spell_sim._run_glyph`'s "power_pct" header), so the hit count below comes from
## `net_monster._blast_hits_to_kill` — the blast-side twin of `_hits_to_kill`, written for exactly this.
##
## **Firing and the hit count are not re-derived here.** `net_monster._blast_hits_to_kill` already proves
## that exact chain; borrowed, not copied, the same device this file already uses for
## `net_progress._scan_gd_files`. **What this check adds, and the only thing it adds**, is the path that
## *gets to* the packed value — through real kills, a real draw and the pick window's own `_gui_input`, never
## written by hand — and proves that value is the exact same one Stage A already trusts.
func _full_round_trip_pick_to_a_bigger_hit(t) -> void:
	var np := NetProgress.new()
	var world: Variant = np._new_world()
	var pr: Progress = world.progress()
	# **A round circle explicitly** — `SpellCircle.new()` alone is `CIRCLE_NONE` now (Stage 3's empty boot).
	var circle := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	t.eq(circle.packed_glyphs(), Glyph.GLYPH_NONE, "놓기 전엔 빈 목록이다 (0 — 전제)")

	# -- level up, for real, through the same award path Stage B measures --
	var pig := MonsterDefs.KIND_PIG
	var kills := 0
	while pr.level < 1 and kills < 50:
		var mid: int = world.spawn_monster(pig, 600, NetProgress.FLOOR_TOP - MonsterDefs.h_px(pig))
		t.ok(mid > 0, "돼지 %d번째가 스폰됐다 (전제)" % (kills + 1))
		np._kill(world, world.monster_count() - 1)
		kills += 1
	t.ok(pr.level >= 1, "실제로 레벨이 올랐다 (%d마리 — 전제)" % kills)
	t.ok(pr.pending_picks >= 1, "대기 중인 뽑기가 생겼다 (전제)")
	var pending_before := pr.pending_picks

	# -- a real draw, not a hand-set one — only the RNG's own seed is chosen, so `BLAST_U` is guaranteed to
	#  be somewhere in the three cards without touching `_drawn` or the draw rule itself.
	var mirror := RandomNumberGenerator.new()
	var seed := 0
	while seed < 10000:
		mirror.seed = seed
		if ThreePick.draw(circle.glyph_list(), mirror).has(Glyph.BLAST_U):
			break
		seed += 1
	t.ok(seed < 10000, "만 개 씨앗 안에서 폭발(유니크)이 나오는 씨앗을 찾았다 (전제)")
	pr._rng.seed = seed

	t.ok(pr.open_pick(circle.glyph_list()), "뽑기가 실제로 열렸다 (전제)")
	var drawn := pr.drawn()
	var idx := drawn.find(Glyph.BLAST_U)
	t.ok(idx >= 0, "폭발(유니크)이 실제로 뽑힌 세 장 안에 있다 (%s — 전제)" % [drawn])

	var win := ThreePickWindow.new()
	win.setup(pr, circle)
	win.size = Fx.PICK_RECT.size

	var rects := Layout.cards(win.size, drawn.size())
	_click(win, rects[idx].get_center())
	t.eq(win.get("_picked_index"), idx, "폭발(유니크) 카드를 골랐다 (전제)")

	var circle_rect := Layout.circle_rect(win.size)
	var area := CircleLayout.circle_area(circle_rect.size)
	var slots := CircleLayout.layer_slots(circle.circle_id(), area)
	_click(win, circle_rect.position + slots[0])
	win.free()

	t.eq(circle.glyph_at(0), Glyph.BLAST_U, "0층에 실제로 폭발(유니크)이 놓였다 (클릭이 배치를 만들었다)")
	t.ok(not pr.is_pick_open(), "놓고 나면 뽑기가 닫힌다")
	t.eq(pr.pending_picks, pending_before - 1,
		"대기 수가 정확히 하나 줄었다 (%d -> %d)" % [pending_before, pr.pending_picks])

	var packed: int = circle.packed_glyphs()
	t.eq(packed, Glyph.pack([Glyph.BLAST_U]),
		"packed_glyphs()가 [폭발(유니크)] 하나를 팩한 값과 정확히 같다 (0 -> %d)" % packed)

	# -- fire, and measure absolute hit counts on both sides, read from the table (not only a difference) --
	var nm := NetMonster.new()
	var kind := MonsterDefs.KIND_PIG
	var boost := Glyph.power_pct_of(Glyph.BLAST_U)
	var common: int = nm._blast_hits_to_kill(kind, Glyph.pack([Glyph.GLYPH_BLAST]))
	var boosted: int = nm._blast_hits_to_kill(kind, packed)

	var dmg_common := Character.DAMAGE_HIT * Glyph.power_pct_of(Glyph.GLYPH_BLAST) / 100
	var want_common := ceili(float(MonsterDefs.max_hp(kind)) / float(dmg_common))
	var dmg_boosted := Character.DAMAGE_HIT * boost / 100
	var want_boosted := ceili(float(MonsterDefs.max_hp(kind)) / float(dmg_boosted))

	t.eq(common, want_common,
		"기본 폭발이면 돼지(hp %d)가 %d대에 죽는다 (한 대 %d) — 절대값" % [
			MonsterDefs.max_hp(kind), want_common, dmg_common])
	t.eq(boosted, want_boosted,
		"화면의 클릭으로 만든 packed_glyphs()로 쏘면 %d대에 죽는다 (한 대 %d — %d%%) — 절대값" % [
			want_boosted, dmg_boosted, boost])
	t.ok(boosted < common, "그리고 실제로 더 적은 대수다 (%d < %d)" % [boosted, common])


# ══════════════════════════════════════════════════════════════════
#  The card's own glyph picture — driven for real, not text-scanned
# ══════════════════════════════════════════════════════════════════

## **Records what `three_pick_window.gd`'s own drawing hooks actually did** — the same idiom
## `net_circle._RecordingCircleWindow` already established for `circle_window.gd`'s equivalent functions
## (that file's own header: a native `draw_texture_rect`/`draw_circle` call cannot be overridden directly,
## only a named method, so the production code was split into small hooks for exactly this reuse).
class _RecordingThreePickWindow extends ThreePickWindow:
	var card_glyph_calls: Array[int] = []
	var texture_draws: Array[Dictionary] = []      # {glyph_id, tex} for each card-picture texture draw
	var rarity_ring_calls: Array[Dictionary] = []  # {glyph_id, r} for each card-picture rarity ring
	var procedural_draws: Array[int] = []          # glyph ids drawn procedurally (_draw_pick_glyph_shape)

	func _draw_pick_card_glyph(at: Vector2, r: float, glyph_id: int) -> void:
		card_glyph_calls.append(glyph_id)
		super._draw_pick_card_glyph(at, r, glyph_id)

	func _draw_pick_card_texture(at: Vector2, r: float, tex: Texture2D, glyph_id: int) -> void:
		texture_draws.append({"glyph_id": glyph_id, "tex": tex})
		super._draw_pick_card_texture(at, r, tex, glyph_id)

	func _draw_pick_card_rarity_ring(at: Vector2, r: float, glyph_id: int) -> void:
		rarity_ring_calls.append({"glyph_id": glyph_id, "r": r})
		super._draw_pick_card_rarity_ring(at, r, glyph_id)

	func _draw_pick_glyph_shape(at: Vector2, r: float, glyph_id: int, alpha: float) -> void:
		procedural_draws.append(glyph_id)
		super._draw_pick_glyph_shape(at, r, glyph_id, alpha)


## **Every id in `Glyph.ALL`, actually drawn — tree-and-pumped, the same technique `net_circle._draw_
## actually_runs_headless` uses for `circle_window.gd`** (`net_frame_runner.gd`'s own correction: untreed was
## never the blocker, zero frames turning was — `_draw()` needed a real frame, not a font, and this file's
## own header already carried the old, wrong half of that belief).
##
## **Before this feature, a three-pick card drew name/rarity-word/effect-sentence and nothing pictorial** —
## the user, looking at the real screen, asked for exactly the gap this check now closes: "문양링이나 이런
## 게 떴을 때 이게 문양 모양이 같이 뜨게 해줘". An id silently skipped by either branch is this repo's
## signature fake (CLAUDE.md: "screen changes but sim doesn't" — the model already holds this glyph in the
## drawn list, the card must show *something* for it).
##
## **Split by branch on purpose**: the ids with real art (`Fx.SOCKET_GLYPH_TEX`) must take the texture
## path and never the procedural one; the ids with none yet (the dummy family, and now condense —
## `glyph-condense.md`, "no art is added") must take the procedural fallback and never the texture one — a
## card that quietly swapped the two for any id would still "draw something" and pass a weaker check.
## **The rarity ring is read by the id it was actually drawn with, not just counted** —
## `net_circle._draw_actually_runs_headless`'s own regression (the socket rarity ring skipped once, three
## rarities pixel-identical) is exactly the class of bug a call-count alone hides.
func _card_picture_draws_every_glyph_with_a_rarity_ring(t) -> void:
	for glyph_id: int in Glyph.ALL:
		var pr := Progress.new()
		pr.pending_picks = 1
		pr.set("_drawn", [glyph_id] as Array[int])

		var win := _RecordingThreePickWindow.new()
		win.setup(pr, SpellCircle.new())
		win.size = Fx.PICK_RECT.size
		win.visible = true
		t.root.add_child(win)
		win.queue_redraw()
		await t.pump_frames(3)
		t.ok(win.is_inside_tree(), "문양 %d 카드 창을 트리에 넣었다 (전제)" % glyph_id)

		t.ok(win.card_glyph_calls.has(glyph_id),
			"문양 %d — 카드 그림 함수가 실제로 호출됐다 (%s)" % [glyph_id, win.card_glyph_calls])

		var textured_ids: Array[int] = []
		for d: Dictionary in win.texture_draws:
			textured_ids.append(int(d["glyph_id"]))

		# **`_draw_pick_card_glyph` checks `Fx.RING_TEX` before `Fx.SOCKET_GLYPH_TEX`** (`three_pick_window.
		#  gd`'s own comment — the card now matches the layer's own ring picture) — the dummy family has
		#  ring art (`ring_dummy.png`) but no socket-card art, so `SOCKET_GLYPH_TEX` alone under-counts which
		#  ids take the texture path.
		if Fx.RING_TEX.has(glyph_id) or Fx.SOCKET_GLYPH_TEX.has(glyph_id):
			t.ok(textured_ids.has(glyph_id),
				"문양 %d — 그림이 있으니 텍스처 경로로 그려졌다 (%s)" % [glyph_id, textured_ids])
			t.eq(win.procedural_draws.count(glyph_id), 0,
				"문양 %d — 그림이 있는 id는 절차적 폴백을 안 탄다" % glyph_id)
		else:
			t.ok(win.procedural_draws.has(glyph_id),
				"문양 %d — 그림이 없으니 절차적 폴백으로 그려졌다 (%s)" % [glyph_id, win.procedural_draws])
			t.eq(textured_ids.count(glyph_id), 0,
				"문양 %d — 그림 없는 id는 텍스처 경로를 안 탄다" % glyph_id)

		var ring_ids: Array[int] = []
		for d: Dictionary in win.rarity_ring_calls:
			ring_ids.append(int(d["glyph_id"]))
		t.ok(ring_ids.has(glyph_id),
			"문양 %d — 희귀도 링이 그 문양 자신의 id로 그려졌다 (%s)" % [glyph_id, ring_ids])

		t.root.remove_child(win)
		win.queue_free()
