extends RefCounted
## `src/view/settlement_layout.gd` and `src/view/settlement_window.gd`
## (`run-end-settlement.md`, Stages B and C).
##
## **Stage B measures the pure functions** — `rows`/`button_rect` (do the panel's own shapes collide),
## `time_text` (the hour-safe form), `count_value` (the count-up curve itself, walked end to end).
##
## **Stage C drives `SettlementWindow` outside the tree** — the same technique `net_pick.gd`'s own header
## names (`_gui_input` needs no live viewport). `_draw()` is not called here — **not because it cannot run
## headless in principle** (verify-read: driven inside a ticking `SceneTree`, `get_theme_default_font()` is
## non-null and `_draw()` runs to completion), **but because `run_nets.gd`'s runner never advances a frame**
## (`_initialize()` calls `quit()` before the loop starts). That is `harness-manager`'s fix to make, not this
## file's — until then, `_draw()`'s own visual correctness stays verify-look's job.
## `_ready()` never runs on its own outside the tree either (the same fact `net_pick.gd` records), so it is
## called by hand, once, before anything else touches the node.

## **Stage D wires the whole shell** — `stage.gd`'s own `_physics_process`/`reset_stage`/`_interact` now all
## reach `_settlement`, so this file needs the same untreed-root technique `net_render._wired_stage_root` and
## `net_town._wired_root` already hold, **copied, not imported** (`net_town.gd`'s own header states the policy:
## each net runs in its own process, so there is no shared base class).

const Character := preload("res://src/actor/character.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const STAGE_SCENE := "res://src/stage/stage.tscn"
const STAGE_SCRIPT := "res://src/stage/stage.gd"

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/settlement_layout.gd")
const SettlementWindow := preload("res://src/view/settlement_window.gd")

## **Overrides `_draw_title`, not the native `draw_string`** — GDScript refuses to let a script override a
## method from a native class (measured directly: a hard parse error, not a warning). `settlement_window.
## _draw_title` is a small ordinary script method `_draw()` calls instead, added for exactly this seam
## (verify-read, H3), so this subclass can catch the exact string `_draw()` decided to paint. Needed because
## `_cleared`'s only visible effect is *which string* reaches the title — a check that only follows `_cleared`
## itself (the stored bool) never asks whether that bool actually reaches the screen; deleting the title's
## own ternary and hardcoding `Fx.SETTLEMENT_TITLE` left every such check green.
##
## **`_draw_notice` is caught the same way, and for a sharper reason**: on a death it must not be called at
## all, and "was not called" is only measurable if there is a call to count. `notice_calls` is that count —
## `notices.is_empty()` alone would stay true if the hook were called with two empty strings.
##
## **`notice_rect` is captured too, and it was not — this is the hole that shipped** (verify-read, an
## adversarial pass by an agent that did not build this feature). The rect argument was named `_r` and
## discarded, so `settlement_window._draw()` could hand the hook **`Rect2()`** — the notice drawn at (0,0)
## with zero size, off the panel, invisible — and **all 320 checks in this file stayed green.** Measured, not
## reasoned: the mutation was run.
##
## **What makes it worth this much comment is that the identical hole was found and closed *in the same
## feature*, one file over, by the same author.** `net_gate._the_drawn_tint_is_the_one_the_counters_decided`
## exists because hardcoding `_paint_arch(_tex, rect(), Color.WHITE)` left the pure tint curve measured and
## the wiring unmeasured. `_notice_rect_sits_between_the_last_row_and_the_button` below is that same pure
## function, and nothing asked whether `_draw()` used it. ⇒ **Measuring a pure layout function is never
## measuring the layout.** The second one was missed by the person who had just fixed the first.
class _CapturingSettlementWindow extends SettlementWindow:
	var drawn: Array[String] = []
	var notices: Array[String] = []
	var notice_calls := 0
	var notice_rects: Array[Rect2] = []
	func _draw_title(_font: Font, title: String, _pos: Vector2) -> void:
		drawn.append(title)
	func _draw_notice(_font: Font, line1: String, line2: String, r: Rect2) -> void:
		notice_calls += 1
		notices.append(line1)
		notices.append(line2)
		notice_rects.append(r)


func run(t) -> void:
	_button_rect_is_inside_the_panel_and_does_not_overlap_any_row(t)
	_time_text_matches_the_mockup_and_stays_hour_safe(t)
	_count_value_starts_at_zero_never_decreases_and_lands_exactly_on_total(t)
	_ready_seats_from_settlement_rect(t)
	_open_then_tick_countup_walks_shown_gems_from_zero_to_total(t)
	_gui_input_inside_button_rect_fires_signal_outside_it_does_not(t)
	await _the_title_actually_drawn_matches_cleared_or_not(t)
	# -- Stage clear sequence — the notice --
	_notice_rect_sits_between_the_last_row_and_the_button(t)
	_the_three_clear_strings_are_the_ones_the_plan_names(t)
	_the_two_notice_lines_fit_inside_the_band_they_are_drawn_in(t)
	await _the_notice_is_painted_on_a_clear_and_never_on_a_death(t)
	_the_notice_is_centred_in_its_rect(t)
	# -- Stage D — the wired shell --
	_hud_hides_while_the_settlement_screen_shows(t)
	_snapshot_values_equal_progresss_live_values_at_the_instant_it_opens(t)
	_blowing_yourself_down_in_the_town_does_not_open_it(t)
	_sim_really_stops_while_showing_grid_tick_does_not_move(t)
	_button_effect_returns_to_town_and_zeroes_run_state_but_not_gems(t)
	_ready_itself_connects_the_button_to_enter_town(t)
	_reset_stage_while_showing_closes_it_and_stays_in_the_stage(t)
	_interact_while_downed_in_the_stage_no_longer_leaves(t)
	_gems_zero_still_opens_and_count_up_stays_at_zero(t)


# ══════════════════════════════════════════════════════════════════
#  Stage B — the pure layout and the two value functions
# ══════════════════════════════════════════════════════════════════

func _button_rect_is_inside_the_panel_and_does_not_overlap_any_row(t) -> void:
	var size := Fx.SETTLEMENT_RECT.size
	var panel := Rect2(Vector2.ZERO, size)
	var btn := Layout.button_rect(size)
	t.ok(panel.encloses(btn), "버튼이 패널(960x540) 안에 있다")
	t.ok(btn.size.x > 0.0 and btn.size.y > 0.0, "버튼에 크기가 있다")

	var rows := Layout.rows(size)
	t.eq(rows.size(), 3, "행이 정확히 셋이다 (플레이 시간·준 피해·원석 — 그 이상도 이하도 아니다)")
	for i in rows.size():
		t.ok(panel.encloses(rows[i]), "%d번 행이 패널 안에 있다" % i)
		t.ok(not btn.intersects(rows[i]), "버튼이 %d번 행과 안 겹친다" % i)


func _time_text_matches_the_mockup_and_stays_hour_safe(t) -> void:
	t.eq(Layout.time_text(0), "0초", "0초는 그대로 0초다")
	t.eq(Layout.time_text(41), "41초", "분 없이 41초만 (화면 시안의 값)")
	t.eq(Layout.time_text(12 * 60 + 41), "12분 41초", "12분 41초 (화면 시안 그대로)")

	# Bounds — "a very long run needs an hour form, or it reads 241분".
	var past_hour := Layout.time_text(3661)  # 1시간 1분 1초
	t.ok(not past_hour.contains("61분"), "한 시간을 넘겨도 '61분'으로 안 읽힌다 (얻은 값 %s)" % past_hour)
	t.ok(past_hour.contains("시간"), "한 시간을 넘기면 시간 단위가 나타난다 (얻은 값 %s)" % past_hour)


## **`count_value` is the whole animation** (`settlement_layout.gd`'s own header) — walked end to end here,
## the same idiom `net_water`'s own per-tick measurement holds for a curve rather than a single before/after.
func _count_value_starts_at_zero_never_decreases_and_lands_exactly_on_total(t) -> void:
	var total := 7
	t.eq(Layout.count_value(total, 0), 0, "0프레임째엔 0에서 시작한다")

	var step := Fx.SETTLEMENT_COUNT_FRAMES_PER_POINT
	var bound := step * total + step * 4  # 총계 도달을 확인하고도 몇 프레임 더 여유를 둔다
	var prev := -1
	var reached_at := -1
	for f in range(bound):
		var v: int = Layout.count_value(total, f)
		t.ok(v >= prev, "프레임 %d에서 값이 줄지 않는다 (%d -> %d)" % [f, prev, v])
		prev = v
		if v == total and reached_at < 0:
			reached_at = f
	t.ok(reached_at >= 0, "정해진 프레임 수 안에 정확히 총계(%d)에 도달한다" % total)
	t.eq(Layout.count_value(total, bound), total, "도달한 뒤에는 총계에 머문다 (넘지 않는다)")

	# **원석 0 — 죽어도 화면은 열린다** (Bounds, acceptance 6). 몇 프레임을 돌려도 0에 머물러야 한다.
	for k in [0, 1, 5, 100]:
		t.eq(Layout.count_value(0, k), 0, "원석이 0이면 프레임 %d에서도 0이다" % k)


# ══════════════════════════════════════════════════════════════════
#  Stage C — the window node, driven outside the tree
# ══════════════════════════════════════════════════════════════════

## `_ready()` never fires on its own outside the tree (`net_pick.gd`'s own header records the same fact for
## `ThreePickWindow`) — called by hand here, and this is the only check that measures its own effect.
func _ready_seats_from_settlement_rect(t) -> void:
	var win := SettlementWindow.new()
	win._ready()
	t.eq(win.position, Fx.SETTLEMENT_RECT.position, "_ready()가 SETTLEMENT_RECT의 위치로 앉는다")
	t.eq(win.size, Fx.SETTLEMENT_RECT.size, "_ready()가 SETTLEMENT_RECT의 크기로 앉는다")
	win.free()


## **Measures `visible`, not only `_showing`** — the two used to be able to diverge (`_showing` true while
## the actual `Control.visible` stayed at its `_ready()`-time default `false`), which drew nothing at all
## while every other check in this file, driving `is_showing()`/`shown_gems()` directly, stayed green (this
## doc's own signature fake: the sim/state side moves and the screen does not).
func _open_then_tick_countup_walks_shown_gems_from_zero_to_total(t) -> void:
	var win := SettlementWindow.new()
	win._ready()
	# **`close()` first, to establish a known baseline.** `stage.tscn` declares `visible = false`, but that is a
	#  scene-file property override — a bare `.new()` here never goes through the `.tscn`, so the engine's own
	#  `Control` default (`visible == true`) applies until something says otherwise. In the real game that
	#  "something" is `reset_stage()`'s own `_settlement.close()` call, which always runs once inside `_ready()`
	#  before anything else can observe this node — so calling it here first is not a workaround, it is the
	#  same first event the real game always produces.
	win.close()
	t.ok(not win.is_showing(), "열기 전엔 안 보인다 (전제)")
	t.ok(not win.visible, "그리고 실제 Control.visible도 꺼져 있다 (전제)")

	win.open(761, 8420, 7, false)
	t.ok(win.is_showing(), "open() 뒤엔 보인다")
	t.ok(win.visible, "그리고 실제로 화면에 켜진다 (visible == true)")
	t.eq(win.shown_gems(), 0, "연 직후, 아직 한 틱도 돌기 전엔 원석이 0에서 시작한다")

	var step := Fx.SETTLEMENT_COUNT_FRAMES_PER_POINT
	var prev := 0
	for _i in range(step * 7 + step * 2):
		win.tick_countup()
		var v := win.shown_gems()
		t.ok(v >= prev, "tick_countup()을 부를 때마다 값이 줄지 않는다")
		prev = v
	t.eq(win.shown_gems(), 7, "충분히 돌리면 정확히 이번 런의 원석 총량(7)에 닿는다")

	win.close()
	t.ok(not win.is_showing(), "close()가 다시 닫는다")
	t.ok(not win.visible, "그리고 실제로 화면에서도 꺼진다")
	win.free()


func _gui_input_inside_button_rect_fires_signal_outside_it_does_not(t) -> void:
	var win := SettlementWindow.new()
	win._ready()
	win.open(60, 100, 3, false)

	# **A boxed counter, not a bare local.** GDScript lambdas capture a local by value (a snapshot at creation
	#  time) - `func(): fired += 1` over a bare `int` would increment a copy the outer scope never sees. An
	#  `Array` is captured by the same rule, but the *value* captured is a reference to the array object, so
	#  mutating its contents (not reassigning the variable) reaches the same object the outer scope reads.
	var fired := [0]
	win.town_pressed.connect(func(): fired[0] += 1)

	var btn := Layout.button_rect(win.size)
	_click(win, btn.get_center())
	t.eq(fired[0], 1, "버튼 한가운데를 누르면 신호가 한 번 뜬다")

	_click(win, Vector2(1.0, 1.0))
	t.eq(fired[0], 1, "버튼 밖을 눌러도 신호가 더 뜨지 않는다")
	win.free()


## **`_cleared` reaching the screen, not just being stored** (verify-read, H3 — `gate-ending-to-game.md`'s
## own Stage D exists to make a clear and a death read differently; a check that only follows `_cleared`
## itself never asks whether that bool actually reaches `_draw()`'s title).
##
## **Driven through a real, treed draw pass, not a bare `.call("_draw")`.** `_draw()` also calls `draw_rect`/
## `draw_string`/`draw_texture_rect` directly for the rows and the button, and the engine refuses those
## outside an actual `NOTIFICATION_DRAW` dispatch ("Drawing is only allowed inside this node's `_draw()`...",
## measured directly) — only the title line is intercepted (`_draw_title`), so the rest must run for real.
## `net_frame_runner.gd`'s own technique: add to `t.root`, `queue_redraw()`, pump real frames.
func _the_title_actually_drawn_matches_cleared_or_not(t) -> void:
	var win := _CapturingSettlementWindow.new()
	t.root.add_child(win)  # Triggers a real _ready(), seating it from Fx.SETTLEMENT_RECT.

	win.open(10, 20, 3, true)
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.drawn.has(Fx.SETTLEMENT_TITLE_CLEAR),
		"클리어로 열면 실제로 '%s' 문자열이 그려진다" % Fx.SETTLEMENT_TITLE_CLEAR)
	t.ok(not win.drawn.has(Fx.SETTLEMENT_TITLE), "그리고 죽음 제목('%s')은 안 그려진다" % Fx.SETTLEMENT_TITLE)

	win.drawn.clear()
	win.open(10, 20, 3, false)
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.drawn.has(Fx.SETTLEMENT_TITLE), "죽음으로 열면 '%s'이 그려진다" % Fx.SETTLEMENT_TITLE)
	t.ok(not win.drawn.has(Fx.SETTLEMENT_TITLE_CLEAR),
		"그리고 클리어 제목('%s')은 안 그려진다" % Fx.SETTLEMENT_TITLE_CLEAR)

	t.root.remove_child(win)
	win.queue_free()


## **The notice's own rect, computed against its two neighbours — never against a literal y.**
## `settlement_layout.gd`'s panel-internal numbers are hand-derived from its own constants, so a literal here
## would rot the day any of them moves and would still read green. The claim is "it clears both neighbours",
## and that is what is asked directly.
func _notice_rect_sits_between_the_last_row_and_the_button(t) -> void:
	var size := Fx.SETTLEMENT_RECT.size
	var panel := Rect2(Vector2.ZERO, size)
	var notice := Layout.notice_rect(size)
	t.ok(panel.encloses(notice), "안내 문구 자리가 패널(960x540) 안에 있다")
	t.ok(notice.size.x > 0.0 and notice.size.y > 0.0, "안내 문구 자리에 크기가 있다")

	var last_row := Layout.rows(size)[2]
	var btn := Layout.button_rect(size)
	t.ok(not notice.intersects(last_row), "안내 문구가 마지막 행(원석)과 안 겹친다")
	t.ok(not notice.intersects(btn), "안내 문구가 '마을로' 버튼과 안 겹친다")
	t.ok(notice.position.y >= last_row.end.y, "안내 문구가 마지막 행보다 아래에 있다")
	t.ok(notice.end.y <= btn.position.y, "안내 문구가 버튼보다 위에 있다")


## **Do the two lines actually fit in the box they are given** — **a value, not a feel.**
##
## `stage-clear-sequence.md` filed this under Screen, for verify-look. **It does not belong there**: font
## metrics are readable headless (`ThemeDB.fallback_font`, the same default theme font `settlement_window`
## itself falls back to), so "two 18px lines inside a 64px band" is measurable and therefore must be
## measured. Only *whether the notice reads as information rather than as an error message* is the eye's.
##
## **Measured today: line height 26, two lines 52, against `NOTICE_H_PX` 64 — it fits, with 12px to spare.**
## Nothing is broken; what was missing was anything that says so the day `SETTLEMENT_NOTICE_SIZE` is bumped
## or a line is lengthened. Both would silently clip, and clipping the one sentence that tells the player the
## build ends here is the failure this whole beat exists to prevent.
func _the_two_notice_lines_fit_inside_the_band_they_are_drawn_in(t) -> void:
	var font := ThemeDB.fallback_font
	t.ok(font != null, "기본 테마 글꼴을 읽었다 (전제 — 트리 밖에서도 있다)")
	if font == null:
		return
	var s := Fx.SETTLEMENT_NOTICE_SIZE
	var r := Layout.notice_rect(Fx.SETTLEMENT_RECT.size)
	var line_h := font.get_height(s)
	t.ok(line_h * 2 <= r.size.y,
		"안내 두 줄(%dpx)이 자리 높이(%dpx) 안에 들어간다" % [line_h * 2, int(r.size.y)])
	for line: String in [Fx.SETTLEMENT_NOTICE_1, Fx.SETTLEMENT_NOTICE_2]:
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		t.ok(w <= r.size.x,
			"'%s'의 폭(%dpx)이 자리 폭(%dpx)을 안 넘는다" % [line, int(w), int(r.size.x)])


## **The strings themselves are the deliverable** (`stage-clear-sequence.md`'s own table), so they are pinned
## by literal here and nowhere else. Every other check in this file reads the constant — which is right for
## measuring *which* string reaches the screen, and useless for measuring *what the string says*: leaving
## `SETTLEMENT_TITLE_CLEAR` at the provisional `런 클리어` would keep all of them green.
func _the_three_clear_strings_are_the_ones_the_plan_names(t) -> void:
	t.eq(Fx.SETTLEMENT_TITLE_CLEAR, "스테이지 1 클리어", "클리어 제목이 '스테이지 1 클리어'다 (임시값 '런 클리어'가 아니다)")
	t.eq(Fx.SETTLEMENT_NOTICE_1, "지금은 여기까지만 개발돼 있습니다.", "안내 첫 줄이 정해진 문장 그대로다")
	t.eq(Fx.SETTLEMENT_NOTICE_2, "스테이지 2는 아직 없습니다.", "안내 둘째 줄이 정해진 문장 그대로다")
	t.ok(Fx.SETTLEMENT_TITLE_CLEAR != Fx.SETTLEMENT_TITLE, "클리어 제목과 죽음 제목이 다른 문장이다")


## **The notice reaching the paint, and — the half that matters — not reaching it on a death.**
## Driven treed and pumped, exactly as the title check above is and for the same recorded reason: `_draw()`
## still calls `draw_rect`/`draw_string`/`draw_texture_rect` for the rows and the button, and the engine
## refuses those outside a real `NOTIFICATION_DRAW` dispatch. A hand `_draw()` here would bark, and the
## wrapper counts stderr as failure.
func _the_notice_is_painted_on_a_clear_and_never_on_a_death(t) -> void:
	var win := _CapturingSettlementWindow.new()
	t.root.add_child(win)

	win.open(10, 20, 3, true)
	win.queue_redraw()
	await t.pump_frames(3)
	t.ok(win.notice_calls > 0, "클리어로 열면 안내 문구가 실제로 그려진다 (_draw()가 돌았다가 아니라)")
	t.ok(win.notices.has(Fx.SETTLEMENT_NOTICE_1),
		"첫 줄 '%s'이 그대로 화면에 닿는다" % Fx.SETTLEMENT_NOTICE_1)
	t.ok(win.notices.has(Fx.SETTLEMENT_NOTICE_2),
		"둘째 줄 '%s'도 그대로 화면에 닿는다" % Fx.SETTLEMENT_NOTICE_2)
	# **And at the rect the layout decided, not merely at some rect** (the class header's own story).
	#  `_draw()` handing `Rect2()` here left every other check in this file green.
	t.eq(win.notice_rects.size(), win.notice_calls, "잡은 자리 수가 호출 수와 같다 (전제)")
	if not win.notice_rects.is_empty():
		t.eq(win.notice_rects[0], Layout.notice_rect(Fx.SETTLEMENT_RECT.size),
			"그리고 실제로 넘기는 자리가 notice_rect()가 정한 그 자리다 (Rect2()를 넘겨도 여기 말고는 다 초록이었다)")

	win.notices.clear()
	win.notice_rects.clear()
	win.notice_calls = 0
	win.open(10, 20, 3, false)
	win.queue_redraw()
	await t.pump_frames(3)
	t.eq(win.notice_calls, 0, "죽음으로 열면 안내 문구는 한 번도 안 그려진다 (죽음은 콘텐츠의 끝이 아니다)")
	t.ok(win.drawn.has(Fx.SETTLEMENT_TITLE), "그리고 죽음 제목은 그대로 그려진다 (그리기 자체는 멀쩡하다는 전제)")

	t.root.remove_child(win)
	win.queue_free()


## Same technique `net_pick._click` already holds — a bare `InputEventMouseButton`, driven through
## `_gui_input` directly on an untreed `Control`.
func _click(win: Control, pos: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = pos
	win.call("_gui_input", mb)


# ══════════════════════════════════════════════════════════════════
#  Stage D — the wiring, driven through a wired-up stage root
# ══════════════════════════════════════════════════════════════════

## **Risk 2 (`run-end-settlement.md`, Stage D) — forget this and the debug readout (`HUD/Stats`) prints on top
## of the panel, and nothing barks.** `_hud.visible` is derived, not pushed, the same discipline it already
## holds against `_circle_window`/`_pick_window`/`_research_window`.
func _hud_hides_while_the_settlement_screen_shows(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var stats := root.get_node("HUD/Stats") as Label
	t.ok(stats.visible, "정산 화면이 뜨기 전엔 Stats가 보인다 (전제)")

	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)

	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "정산 화면이 열렸다 (전제)")
	t.ok(not stats.visible, "정산 화면이 열리면 디버그 글자(Stats)가 숨는다 (패널 위에 안 찍힌다)")

	root.free()


## **Acceptance — the panel's three snapshot values equal `Progress`'s real values at the instant it opens.**
## The fake this catches (`run-end-settlement.md`'s own Risk 4, "the signature fake for this feature"): a
## panel that draws a plausible-looking number instead of the one actually accumulated. XP/damage/a boss's
## gems are all pushed to non-zero first, or an all-zero coincidence could pass this by accident.
func _snapshot_values_equal_progresss_live_values_at_the_instant_it_opens(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	var pr: Variant = world.call("progress")
	pr.add_xp(50)
	pr.add_damage(37)
	pr.add_boss_gems()

	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	t.ok(bool(ch.downed), "쓰러졌다 (전제)")

	var want_seconds: int = pr.run_seconds()
	var want_damage: int = pr.damage_dealt
	var want_gems: int = pr.gems_this_run()

	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "쓰러지자 정산 화면이 열린다")
	t.ok(bool(settlement.visible), "그리고 실제 Control.visible도 켜진다 (is_showing()만 참이고 화면엔 안 뜨는 상태가 아니다)")
	t.eq(int(settlement.get("_seconds")), want_seconds,
		"연 순간의 플레이 시간이 Progress의 실제 값과 같다 (그럴듯한 값이 아니다)")
	t.eq(int(settlement.get("_damage")), want_damage, "연 순간의 준 피해도 실제 값과 같다")
	t.eq(int(settlement.get("_gems")), want_gems, "연 순간의 원석도 실제 값(이번 런 몫)과 같다")

	root.free()


## **Acceptance 9 — blow yourself down in the town, and nothing opens.** The GDD's "magic hits the player too"
## holds in the town as well, so `_char.downed` can become true there — the trigger is `downed` **and not in
## the town**, and `_sync_settlement()`'s own `want` expression is what makes this true by construction.
func _blowing_yourself_down_in_the_town_does_not_open_it(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	t.ok(bool(root.get("_in_town")), "마을에서 시작한다 (전제)")
	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	t.ok(bool(ch.downed), "마을에서도 쓰러질 수 있다 (전제)")

	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(not bool(settlement.is_showing()), "마을에서 쓰러져도 정산 화면은 안 열린다 (달리기가 아니다)")

	root.free()


## **The sim really stops behind the screen** (this doc's own TBD, now closed) — measured as a value, not
## assumed from reading the gate in `_physics_process`. `_grid.get_tick()` must not move across N calls while
## the panel is showing.
func _sim_really_stops_while_showing_grid_tick_does_not_move(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)

	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "정산 화면이 열렸다 (전제)")
	var grid: Variant = root.get("_grid")
	var tick_before: int = grid.get_tick()

	for _i in 60:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(grid.get_tick(), tick_before,
		"패널이 열린 60프레임 동안 틱이 한 번도 안 움직인다 (시뮬이 정말로 멈춘다)")

	root.free()


## **Acceptance 8 — the button sends you to the town, and 원석 alone survives it.**
## **The signal's own connection lives in `_ready()`, which never runs outside the tree** (`_wired_root`'s own
## header) — the same reason `_toggle_pick`/`_toggle_assembly` are driven by calling them directly elsewhere in
## this suite rather than through the input signal that would reach them in the real game. `enter_town` is
## exactly what `stage.gd`'s own `_settlement.town_pressed.connect(enter_town)` runs on a real click.
func _button_effect_returns_to_town_and_zeroes_run_state_but_not_gems(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	var pr: Variant = world.call("progress")
	pr.add_xp(90)
	pr.add_damage(12)
	var gems_before: int = pr.gems

	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "정산 화면이 열렸다 (전제)")

	root.call("enter_town")
	t.ok(bool(root.get("_in_town")), "버튼이 하는 일(enter_town)을 실행하면 마을로 돌아온다")
	t.eq(pr.xp, 0, "경험치가 지워진다")
	t.eq(pr.level, 0, "레벨도 지워진다")
	t.eq(pr.damage_dealt, 0, "준 피해도 지워진다")
	t.eq(pr.run_ticks, 0, "플레이 시간 카운터도 지워진다")
	t.eq(pr.gems, gems_before, "원석 총량은 그대로다 (달리기를 넘어 남는 유일한 것)")
	t.ok(not bool(settlement.is_showing()), "그리고 정산 화면도 닫힌다")

	root.free()


## **`_ready()` itself makes the connection — driven directly, not through the tree.** `_ready()` never fires
## on its own outside the tree (every wired root in this suite works around exactly that), but it is still a
## plain method, callable by hand once every field its own body touches is pre-wired. `_terrain`/`_char_view`
## are wired **only here** — no other check in this file drives `_ready()` itself, so nowhere else needs them.
##
## **This is the one piece of the click path a tree-less technique can reach.** Whether a *real* click (mouse
## input through a live `Viewport`) would actually route to `_gui_input` and fire the signal is not measured
## here or anywhere in this suite — that is `verify-look`'s job.
func _ready_itself_connects_the_button_to_enter_town(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.set("_terrain", root.get_node("Terrain"))
	root.set("_char_view", root.get_node("CharacterView"))
	# **Isolates what `_ready()` itself wires** (verify-read, H1). `_wired_root()` above already calls
	# `GateView.setup(...)` by hand for every *other* check in this file (none of which call `_ready()` at
	# all) — left in place here, that pre-wiring would mask `_ready()`'s own `_gate_view.setup(...)` call
	# being deleted entirely, since `_progress` would already be non-null before `_ready()` ever ran.
	# Nulling it first means only `_ready()` itself can make the check below pass.
	root.get_node("GateView").set("_progress", null)
	root.call("_ready")

	var settlement: Variant = root.get("_settlement")
	var conns: Array = settlement.town_pressed.get_connections()
	t.eq(conns.size(), 1, "_ready()가 town_pressed에 연결을 정확히 하나 만든다")
	if conns.size() == 1:
		var target: Callable = conns[0]["callable"]
		t.ok(target.get_object() == root, "그 연결의 대상 객체가 바로 이 무대다")
		t.eq(String(target.get_method()), "enter_town", "그리고 그 대상 메서드가 정확히 enter_town이다")

	# **H1 — `_ready()` must itself call `_gate_view.setup(_world.progress())`.** Left out, `_progress` stays
	# the `null` this test just forced, `_process()`'s `visible` expression short-circuits on `_progress !=
	# null` and stays `false` forever, and the arch never appears — with no error anywhere (`stage._fire_at`'s
	# own shape: a wiring line missing, and nothing barks).
	var world: Variant = root.get("_world")
	var pr: Variant = world.call("progress")
	pr.set_boss_reward_pending(MonsterDefs.KIND_ROOSTER)
	var gate_view: Variant = root.get_node("GateView")
	gate_view.call("_process", 0.0)
	t.ok(bool(gate_view.visible),
		"_ready()가 _gate_view.setup()을 실제로 불러서, 죽은 뒤엔 아치가 보인다 (안 그러면 _progress가 null인 채로 영원히 안 보인다)")

	root.free()


## **Acceptance 10 — `R`(reset_stage) while the screen is open closes it and stands a fresh, unsettled stage.**
## `reset_stage()` already cancels the circle window and the three-pick for exactly this reason (this doc's
## own Bounds) — a settlement panel left standing over a fresh stage would be a screen reporting a run that no
## longer exists.
func _reset_stage_while_showing_closes_it_and_stays_in_the_stage(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)
	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "정산 화면이 열렸다 (전제)")

	root.call("reset_stage")
	t.ok(not bool(settlement.is_showing()), "R(reset_stage)을 누르면 정산 화면이 닫힌다")
	t.ok(not bool(settlement.visible), "그리고 실제 Control.visible도 꺼진다")
	t.ok(not bool(root.get("_in_town")), "그런데도 무대에 그대로 남는다 (마을로 가지 않는다)")
	t.ok(not bool(ch.downed), "새로 선 캐릭터는 쓰러진 상태가 아니다 (새 무대다)")

	root.free()


## **The old door is gone.** E while downed in the stage used to call `enter_town()` directly
## (`_interact()`'s own header) — now it does nothing, because the settlement screen is what tells the player
## the run is over.
func _interact_while_downed_in_the_stage_no_longer_leaves(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	t.ok(bool(ch.downed), "쓰러졌다 (전제)")

	root.call("_interact")
	t.ok(not bool(root.get("_in_town")), "쓰러진 채 E를 눌러도 무대에 그대로 남는다 (옛 문이 사라졌다)")

	root.free()


## **Acceptance 6 — 원석 0. 죽었는데도 화면은 나타나야 하고("아무것도 못 얻었다"도 정보다), 카운트업은 0에
## 머물러야 한다.** 아무것도 안 죽인 채로 쓰러진다.
func _gems_zero_still_opens_and_count_up_stays_at_zero(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var world: Variant = root.get("_world")
	var pr: Variant = world.call("progress")
	t.eq(pr.gems_this_run(), 0, "아무것도 안 죽였으니 이번 런 몫이 0이다 (전제)")

	var ch: Variant = root.get("_char")
	ch.take_hit(Character.MAX_HP, false)
	root.call("_physics_process", 1.0 / 60.0)

	var settlement: Variant = root.get("_settlement")
	t.ok(bool(settlement.is_showing()), "원석이 0이어도 화면은 그대로 열린다 (숨기지 않는다)")
	t.eq(settlement.call("shown_gems"), 0, "카운트업 값도 0에서 멈춰 있다")

	for _i in 30:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(settlement.call("shown_gems"), 0, "프레임이 더 지나도 0에서 그대로다")

	root.free()


## **The same wiring `net_render._wired_stage_root` does, copied rather than shared** — each net runs in its
## own process (`net_town._wired_root`'s own header states the policy), so there is no shared base class.
## The onready paths for `_hud`/`_progress_label`/`_levelup_label` are read out of the script rather than
## assumed, the same reason `net_render`'s own copy does it that way — a renamed field goes red there first,
## by name, rather than as a null crash here.
func _wired_root(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()

	var src := _read(STAGE_SCRIPT)
	var re := RegEx.new()
	re.compile("@onready\\s+var\\s+(_levelup_label|_hud)\\s*:[^=]+=\\s*\\$([A-Za-z0-9_/]+)")
	var paths: Dictionary = {}
	for m: RegExMatch in re.search_all(src):
		paths[m.get_string(1)] = m.get_string(2)
	t.ok(paths.has("_hud") and paths.has("_levelup_label") and paths.has("_levelup_label"),
		"onready 경로를 찾았다 (전제)")
	if not (paths.has("_hud") and paths.has("_levelup_label") and paths.has("_levelup_label")):
		root.free()
		return null

	for path: String in [paths["_hud"], paths["_levelup_label"], "HUD/HpBar",
			"HUD/CircleWindow", "HUD/ThreePickWindow", "SpellView", "BlastFx", "StageInput", "Camera2D",
			"MonsterView", "CellRenderer", "TownView", "SkyBackground", "HUD/ResearchWindow",
			# **`GateView`** (`gate-ending-to-game.md`, Stage C) — `_ready()` now calls `_gate_view.setup(...)`
			#  unconditionally. Left out, `_ready_itself_connects_the_button_to_enter_town` below dies on a
			#  null mid-call and its own checks disappear rather than fail (this file's own header risk).
			"GateView",
			# **`HUD/BossBar`** (`boss-entrance-and-hp-bar.md` Stage C) — `_rebuild()`/`_physics_process()`
			#  both touch `_boss_bar` unconditionally now; left out, this file's own tests that call
			#  `reset_stage()`/`enter_town()`/`_leave_town()` on this root crash on a null mid-call, the same
			#  risk this file's own comment already names for `GateView` one line up.
			"HUD/BossBar",
			"HUD/SettlementWindow"]:
		t.ok(root.get_node_or_null(path) != null, "씬에 %s 가 있다 (전제)" % path)

	root.set("_hud", root.get_node(paths["_hud"]))
	root.set("_levelup_label", root.get_node(paths["_levelup_label"]))
	root.set("_hp_view", root.get_node("HUD/HpBar"))
	root.set("_spell_view", root.get_node("SpellView"))
	root.set("_blast_fx", root.get_node("BlastFx"))
	root.set("_circle_window", root.get_node("HUD/CircleWindow"))
	root.set("_pick_window", root.get_node("HUD/ThreePickWindow"))
	root.set("_input", root.get_node("StageInput"))
	root.set("_camera", root.get_node("Camera2D"))
	root.set("_monster_view", root.get_node("MonsterView"))
	root.set("_town_view", root.get_node("TownView"))
	root.get_node("TownView").call("setup", root.get("_char"))
	root.set("_sky", root.get_node("SkyBackground"))
	root.get_node("SkyBackground").call("setup", root.get_node("Camera2D"))
	root.set("_research_window", root.get_node("HUD/ResearchWindow"))
	root.set("_boss_bar", root.get_node("HUD/BossBar"))
	root.set("_settlement", root.get_node("HUD/SettlementWindow"))
	root.set("_renderer", root.get_node("CellRenderer"))
	root.get_node("CellRenderer").call("setup", root.get("_grid"))
	var world0: Variant = root.get("_world")
	if world0 != null:
		root.get_node("HUD/ThreePickWindow").call("setup", world0.progress(), root.get("_circle"))
	root.set("_gate_view", root.get_node("GateView"))
	if world0 != null:
		root.get_node("GateView").call("setup", world0.progress())
	return root


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_settlement: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## **The notice is centred, not left-aligned to the row margin** (verify-look: left-aligned it read as a
##  fourth data row, while the title above and the button below are centred).
##
## **`_centred_x` is asserted directly because the capture subclass above cannot see it** — that subclass
##  overrides `_draw_notice` wholesale and never calls `super()`, so the centring happens on a path the
##  capture replaces. The same gap shape as `spell_view._paint_bolt`'s. **A pure static is the cheap way
##  to close it**: no font-in-a-tree problem, no frame pumping, and it is the exact function the drawing calls.
func _the_notice_is_centred_in_its_rect(t) -> void:
	var font: Font = ThemeDB.fallback_font
	t.ok(font != null, "기본 폰트가 있다 (전제)")
	if font == null:
		return
	var r := Layout.notice_rect(Fx.SETTLEMENT_RECT.size)

	for s: String in [Fx.SETTLEMENT_NOTICE_1, Fx.SETTLEMENT_NOTICE_2]:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_NOTICE_SIZE).x
		var x: float = SettlementWindow._centred_x(font, s, r)
		# **The gap on the left equals the gap on the right** — that is what centred means, and it is
		#  measured rather than compared against a recomputed x (which would be the same arithmetic twice).
		var left := x - r.position.x
		var right := r.end.x - (x + w)
		t.ok(absf(left - right) < 1.0,
			"'%s' 의 좌우 여백이 같다 (왼쪽 %.1f · 오른쪽 %.1f)" % [s, left, right])
		# **And it is not the old left-aligned value** — without this, centring a string exactly as wide as
		#  the rect would pass the symmetry check while nothing had changed.
		t.ok(x > r.position.x + 1.0,
			"'%s' 가 줄 라벨과 같은 왼쪽 여백에 붙어 있지 않다 (x %.1f > %.1f)" % [s, x, r.position.x])

	# **A line wider than the rect must not be pushed off the left edge** — centring a too-wide string gives
	#  a negative offset, and clamping is a decision, not an accident. Recorded as what it does today.
	var wide := "가".repeat(200)
	var wx: float = SettlementWindow._centred_x(font, wide, r)
	t.ok(wx < r.position.x, "칸보다 긴 줄은 왼쪽으로 넘친다 (클램프 안 한다 — 오늘의 동작을 적어 둔다)")
