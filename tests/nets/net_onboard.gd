extends RefCounted
## Onboarding — `onboarding-and-palette-tabs.md` Stage 7. The arrow, the auto-advancing tab, the step
## machine in `stage.gd`, and the closed 연구대 door.
##
## **Everything that drives a real `Stage` is treed** (`t.root.add_child`, `await t.pump_frames`) — the
## same discipline `net_research._treed_stage`'s own header argues for over a hand-wired `_wired_root`:
## `_ready()` connects `circle_window.onboard_inserted`/`onboard_confirmed` to the shell, and a hand-wired
## root would need to re-create those connections itself, which is exactly the "does the shell really wire
## it" question this file exists to answer.

const Fx := preload("res://src/view/fx_tuning.gd")
const Palette := preload("res://src/view/palette_layout.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Book := preload("res://src/view/book_layout.gd")
const Progress := preload("res://src/actor/progress.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const CircleWindow := preload("res://src/view/circle_window.gd")
const OnboardView := preload("res://src/view/onboard_view.gd")
const OnboardLayout := preload("res://src/view/onboard_layout.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const TownView := preload("res://src/view/town_view.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"

## Records the arrow/key rects `onboard_view._draw()` actually paints — the `settlement_layout.notice_rect`
## lesson: a pure layout function asserted alone let a `_draw()` hand it a bare `Rect2()` under 320 green
## checks once already in this repo.
class _RecordingOnboardView extends OnboardView:
	var key_calls: Array[Rect2] = []
	var arrow_calls: Array[Rect2] = []
	var panel_calls: Array[Rect2] = []
	var text_calls: Array[float] = []

	func _draw_onboard_key(rect: Rect2, font: Font) -> void:
		key_calls.append(rect)
		super._draw_onboard_key(rect, font)

	func _draw_onboard_arrow(rect: Rect2) -> void:
		arrow_calls.append(rect)
		super._draw_onboard_arrow(rect)

	func _draw_onboard_panel(rect: Rect2) -> void:
		panel_calls.append(rect)
		super._draw_onboard_panel(rect)

	func _draw_onboard_text(y: float, font: Font) -> void:
		text_calls.append(y)
		super._draw_onboard_text(y, font)


func run(t) -> void:
	_tab_auto_advances_only_while_onboarding(t)
	_confirm_signal_fires_only_while_onboarding(t)
	await _the_arrow_and_key_are_actually_painted_at_the_layouts_own_rects(t)
	await _onboard_view_is_really_wired_by_the_shell(t)
	await _the_walkthrough_runs_once_end_to_end(t)
	await _research_door_is_closed_and_prompts_prep(t)


## **The inversion of the whole feature** (design §8: "Auto-advance is onboarding-only. Outside it,
## pressing 일반진 seats it and the 진 tab stays open."). Driven on the same untreed `CircleWindow`
## `net_circle.gd` already proves callable this way — `_click_palette`/`set_onboarding` are ordinary
## methods, no tree needed.
func _tab_auto_advances_only_while_onboarding(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	var pal := Book.palette_page(win.size)
	var sec := Palette.section(pal.size)

	# -- onboarding ON: placing 진 auto-advances the tab and emits the signal --
	win.set_onboarding(true)
	# **A boxed counter, not a bare local** — GDScript lambdas capture a local by value (a snapshot at
	#  creation time), so `func(): advanced += 1` over a bare `int` would increment a copy this scope never
	#  sees (`net_settlement._the_button_click_actually_fires_the_signal`'s own established idiom).
	var advanced := [0]
	win.onboard_inserted.connect(func() -> void: advanced[0] += 1)
	var circle_items := Palette.items_of(Palette.KIND_CIRCLE, pr, c)
	var round_idx := circle_items.find(CircleDefs.CIRCLE_ROUND)
	c.set_circle(CircleDefs.CIRCLE_NONE)
	win.call("_click_palette", pal, Palette.item_slot(sec, round_idx, circle_items.size()).get_center())
	t.eq(win.get("_open_tab"), Palette.KINDS.find(Palette.KIND_RUNE),
		"온보딩 중에는 진을 놓으면 탭이 룬으로 저절로 넘어간다")
	t.eq(advanced[0], 1, "onboard_inserted가 정확히 한 번 울렸다")

	# -- onboarding OFF: placing 무속성 seats it, and the tab (now on 룬) does not move --
	win.set_onboarding(false)
	var rune_items := Palette.items_of(Palette.KIND_RUNE, pr, c)
	var none_idx := rune_items.find(Tuning.ELEM_NONE)
	win.call("_click_palette", pal, Palette.item_slot(sec, none_idx, rune_items.size()).get_center())
	t.eq(c.rune_at(0), Tuning.ELEM_NONE, "온보딩이 꺼져 있어도 놓이기는 놓인다")
	t.eq(win.get("_open_tab"), Palette.KINDS.find(Palette.KIND_RUNE),
		"하지만 탭은 그대로다 (온보딩이 꺼지면 자동 전환도 꺼진다)")
	t.eq(advanced[0], 1, "onboard_inserted도 더는 안 울린다 (그대로 1)")
	win.free()


## 완성 emits `onboard_confirmed` only while onboarding — the same on/off shape as the tab above, for the
## other signal.
func _confirm_signal_fires_only_while_onboarding(t) -> void:
	var pr := Progress.new()
	var c := SpellCircle.new(CircleDefs.CIRCLE_ROUND)
	var win := CircleWindow.new()
	win.setup(pr, c)
	win.size = Fx.WINDOW_RECT.size
	var pal := Book.palette_page(win.size)
	var confirmed := [0]  # boxed — see `_tab_auto_advances_only_while_onboarding`'s own comment
	win.onboard_confirmed.connect(func() -> void: confirmed[0] += 1)

	win.call("_click_palette", pal, Palette.done_rect(pal.size).get_center())
	t.eq(confirmed[0], 0, "온보딩이 꺼져 있으면 완성을 눌러도 신호가 안 울린다")

	win.set_onboarding(true)
	win.call("_click_palette", pal, Palette.done_rect(pal.size).get_center())
	t.eq(confirmed[0], 1, "온보딩 중에 완성을 누르면 신호가 울린다")
	win.free()


## **The arrow and the key cap paint at exactly `OnboardLayout`'s own answer** — not merely "`_draw()` ran".
func _the_arrow_and_key_are_actually_painted_at_the_layouts_own_rects(t) -> void:
	var view := _RecordingOnboardView.new()
	view.visible = true
	t.root.add_child(view)
	await t.pump_frames(3)

	t.ok(view.key_calls.size() > 0, "키 캡이 실제로 그려졌다 (%d회)" % view.key_calls.size())
	t.ok(view.arrow_calls.size() > 0, "화살표가 실제로 그려졌다 (%d회)" % view.arrow_calls.size())
	if view.key_calls.size() > 0:
		t.ok(view.key_calls[0].is_equal_approx(OnboardLayout.key_rect(view.size)),
			"키 캡 자리가 onboard_layout.key_rect()의 답과 같다")
	if view.arrow_calls.size() > 0:
		t.ok(view.arrow_calls[0].is_equal_approx(OnboardLayout.arrow_rect(view.size)),
			"화살표 자리가 onboard_layout.arrow_rect()의 답과 같다")

	# **Added with the panel and the sentence** — the same `notice_rect` shape as the two checks above,
	#  for the two seats added after 「온보딩이 잘 안 보이고」. Without these, a `_draw()` that hands the
	#  panel a bare `Rect2()` or the text a wrong `y` would still leave the key/arrow checks green.
	t.ok(view.panel_calls.size() > 0, "배경판이 실제로 그려졌다 (%d회)" % view.panel_calls.size())
	t.ok(view.text_calls.size() > 0, "안내 문장이 실제로 그려졌다 (%d회)" % view.text_calls.size())
	if view.panel_calls.size() > 0:
		t.ok(view.panel_calls[0].is_equal_approx(OnboardLayout.panel_rect(view.size)),
			"배경판 자리가 onboard_layout.panel_rect()의 답과 같다")
	if view.text_calls.size() > 0:
		t.ok(is_equal_approx(view.text_calls[0], OnboardLayout.text_baseline_y(view.size)),
			"안내 문장의 y가 onboard_layout.text_baseline_y()의 답과 같다")
	t.ok(not Fx.ONBOARD_TEXT.is_empty() and Fx.ONBOARD_TEXT.contains("마법진"),
		"안내 문장이 실제로 무엇을 하라는 말이다 (빈 문자열이나 키 이름만이 아니다)")

	t.root.remove_child(view)
	view.queue_free()


## **The `_wired_root` trap** (CLAUDE.md) — a never-treed instance has every `@onready` field unset; calling
## `_ready()` by hand exactly once must fill `_onboard_view` in from the scene's own `$HUD/OnboardView`
## line. **Not treed first** — treeing runs `_ready()` once already (wiring every signal in it), and calling
## it a second time on the same node barks "already connected" on every one of them; this checks the one
## real call `_ready()` ever gets, the same as it happens in play.
func _onboard_view_is_really_wired_by_the_shell(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	t.ok(root.get("_onboard_view") == null, "_ready() 전에는 필드가 비어 있다 (전제 — @onready 미해결)")

	root.call("_ready")
	t.ok(root.get("_onboard_view") != null,
		"_ready()를 부르면 $HUD/OnboardView로 채워진다 (배선 줄이 실재한다)")

	root.queue_free()


## **The whole walkthrough, driven end to end on a real, treed `Stage`.** Arrow shows before Tab; Tab opens
## the window on 진 and hides the arrow; placing 일반진 advances to 룬; placing 무속성 advances to 문양;
## pressing 완성 glows and, once the glow ends, closes the window and marks onboarding seen. Acceptance
## 12/13 in one pass.
func _the_walkthrough_runs_once_end_to_end(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	t.root.add_child(root)
	await t.pump_frames(2)

	var pr: Progress = (root.get("_world") as Object).call("progress")
	t.ok(not pr.has_seen_onboarding(), "전제 — 아직 온보딩을 안 봤다")

	root.call("_leave_town")
	# **`_onboard_view.visible` is set by `_tick_onboard()`, called from `_physics_process()`** — `pump_frames`
	#  only advances the *idle* frame (`await process_frame`), so a state whose only visible effect lives in
	#  a physics-only function needs `_physics_process` driven directly, the same established idiom
	#  `net_gate.gd`'s own `_wired_root` checks use throughout.
	root.call("_physics_process", 1.0 / 60.0)
	t.eq(int(root.get("_onboard_step")), 0, "떠나자마자 ARROW 단계다 (전제 — ONBOARD_ARROW == 0)")
	var onboard_view: Control = root.get("_onboard_view")
	t.ok(onboard_view.visible, "화살표가 보인다 (아직 Tab을 안 눌렀다)")
	var circle_window: CircleWindow = root.get("_circle_window")
	t.ok(not circle_window.visible, "조립창은 아직 안 열려 있다 (전제)")

	# -- Tab: ARROW -> CIRCLE --
	root.call("_toggle_assembly")
	root.call("_physics_process", 1.0 / 60.0)
	t.ok(circle_window.visible, "Tab을 누르면 조립창이 열린다")
	t.eq(int(root.get("_onboard_step")), 1, "CIRCLE 단계로 넘어갔다 (ONBOARD_CIRCLE == 1)")
	t.ok(not onboard_view.visible, "화살표는 이제 안 보인다 (Tab을 이미 눌렀다)")
	t.eq(int(circle_window.get("_open_tab")), Palette.KINDS.find(Palette.KIND_CIRCLE),
		"진 탭이 열려 있다 (전제)")

	# -- 일반진 seats: CIRCLE -> RUNE --
	var circle: SpellCircle = root.get("_circle")
	var pal := Book.palette_page(circle_window.size)
	var sec := Palette.section(pal.size)
	var circle_items := Palette.items_of(Palette.KIND_CIRCLE, pr, circle)
	var round_idx := circle_items.find(CircleDefs.CIRCLE_ROUND)
	t.ok(round_idx >= 0, "동그라미가 진 칸에 있다 (전제)")
	circle_window.call("_click_palette", pal,
		Palette.item_slot(sec, round_idx, circle_items.size()).get_center())
	t.eq(circle.circle_id(), CircleDefs.CIRCLE_ROUND, "일반진이 실제로 놓였다")
	t.eq(int(root.get("_onboard_step")), 2, "RUNE 단계로 넘어갔다 (ONBOARD_RUNE == 2)")
	t.eq(int(circle_window.get("_open_tab")), Palette.KINDS.find(Palette.KIND_RUNE),
		"룬 탭으로 저절로 넘어갔다")

	# -- 무속성 룬 seats: RUNE -> GLYPH --
	var rune_items := Palette.items_of(Palette.KIND_RUNE, pr, circle)
	var none_idx := rune_items.find(Tuning.ELEM_NONE)
	t.ok(none_idx >= 0, "무속성이 룬 칸에 있다 (전제)")
	circle_window.call("_click_palette", pal,
		Palette.item_slot(sec, none_idx, rune_items.size()).get_center())
	t.eq(circle.rune_at(0), Tuning.ELEM_NONE, "무속성 룬이 실제로 놓였다")
	t.eq(int(root.get("_onboard_step")), 3, "GLYPH 단계로 넘어갔다 (ONBOARD_GLYPH == 3)")
	t.eq(int(circle_window.get("_open_tab")), Palette.KINDS.find(Palette.KIND_GLYPH),
		"문양 탭으로 저절로 넘어갔다")
	t.ok(circle.can_fire(), "여기서 이미 쏠 수 있다 (창을 닫기 전에도 — 확인 14)")

	# **Fire before leaving is allowed** (design §8, acceptance 14) — nothing here gates a shot on having
	#  finished the walkthrough; `can_fire()` above already proves the circle itself is live.

	# -- 완성: GLYPH -> DONE -> (glow ends) -> OFF, marked seen --
	circle_window.call("_click_palette", pal, Palette.done_rect(pal.size).get_center())
	t.eq(int(root.get("_onboard_step")), 4, "완성을 누르면 DONE 단계다 (ONBOARD_DONE == 4)")
	t.ok(circle_window.visible, "글로우가 도는 동안은 창이 아직 열려 있다")

	# **The glow itself counts down on the *idle* clock** (`circle_window._process`) — `pump_frames` is right
	#  for this half.
	circle_window.queue_redraw()
	await t.pump_frames(Fx.DONE_GLOW_FRAMES * 2)
	t.ok(not circle_window.visible, "글로우가 끝나면 창이 닫힌다")
	# **Noticing the closed window and marking onboarding seen is `_tick_onboard()` again — physics.**
	root.call("_physics_process", 1.0 / 60.0)
	t.eq(int(root.get("_onboard_step")), 5, "OFF로 떨어졌다 (ONBOARD_OFF == 5)")
	t.ok(pr.has_seen_onboarding(), "온보딩을 봤다고 기록됐다")

	# **Outside onboarding, nothing auto-advances any more** (acceptance 13, the other direction from the
	#  untreed check above — this time end to end on the real shell). Opening the window again and placing
	#  a circle must not move the tab.
	root.call("_toggle_assembly")
	root.call("_physics_process", 1.0 / 60.0)
	t.ok(circle_window.visible, "다시 Tab을 누르면 조립창이 또 열린다 (전제)")
	t.eq(int(circle_window.get("_open_tab")), Palette.KINDS.find(Palette.KIND_CIRCLE),
		"진 탭이 열려 있다 (toggle이 매번 되돌린다 — 전제)")
	circle.set_circle(CircleDefs.CIRCLE_NONE)
	circle_window.call("_click_palette", pal,
		Palette.item_slot(sec, round_idx, circle_items.size()).get_center())
	t.eq(circle.circle_id(), CircleDefs.CIRCLE_ROUND, "온보딩이 끝난 뒤에도 클릭은 여전히 놓는다")
	t.eq(int(circle_window.get("_open_tab")), Palette.KINDS.find(Palette.KIND_CIRCLE),
		"하지만 탭은 진에 그대로 머문다 (자동 전환이 다시는 안 일어난다)")

	t.root.remove_child(root)
	root.queue_free()


## **연구대: the door is closed, and the visible seat says so.** `_interact()` at the seat leaves the
## research window closed; `town_view.prompt_text()` reads 「준비중」 there, on-screen through the one seat
## a player who never opens F3 can actually see.
func _research_door_is_closed_and_prompts_prep(t) -> void:
	t.eq(TownView.prompt_text(Fixtures.KIND_RESEARCH), Fx.TOWN_RESEARCH_PROMPT,
		"연구대의 프롬프트 문구가 「준비중」이다")
	t.ok(TownView.prompt_text(Fixtures.KIND_ASSEMBLY) != Fx.TOWN_RESEARCH_PROMPT,
		"조립대는 그대로 [E] 형식이다 (연구대만 닫혔다)")

	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세울 수 있다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	t.root.add_child(root)
	await t.pump_frames(2)

	var ch: Variant = root.get("_char")
	var seats := TownMap.fixture_seats()
	ch.call("place", int(float(seats[Fixtures.KIND_RESEARCH])), TownMap.SPAWN_TILE.y * 16)
	root.call("_interact")
	await t.pump_frames(2)
	var win: Variant = root.get("_research_window")
	t.ok(not bool((win as Object).get("visible")), "연구대 앞에서 E를 눌러도 연구창이 안 열린다")

	t.root.remove_child(root)
	root.queue_free()
