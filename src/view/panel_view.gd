class_name PanelView
extends Node2D

## The overlay when the run ends: say WHY it ended and offer a restart.
##
## ⚠⚠ **IT WAS ALSO THE BEAK PICK UNTIL 2026-08-25**, and that half is deleted — the user: 「부리
## 보상 없지 끝나면 카드보상으로 통일했잖아」. The roster of clickable bodies, the message band's
## reward title, the stain effect and the hit test all went with the reward they served. **What is
## left is one band and one button.**
##
## ⚠ This is a Node2D and NOT a Control, deliberately. `set_anchors_preset` sets anchors and leaves
## the offsets alone, so a Control added to a bare layer keeps `size == (0, 0)` and piles into the
## top-left corner while every check about it passes. It draws its own rectangles and hands the
## shell hit-rects instead of owning a Button.
##
## It READS `run` and `battle` and writes neither. Clicking is the shell's job: `button_hit` answers
## "what is under this point" and `Run.restart` is called by the shell, not here. src/view/ is the
## only folder with no way to change what happens.
##
## `_draw()` calls `_paint_*` hooks and nothing else, and net_draw_leaf pins each hook's `draw_*`
## count and reddens any function here it does not name. `button_rect` exists precisely so the hit
## test and the picture read the same rectangle out of look.gd — a hit rect computed a second time
## by the shell is the same value living in two places.
##
## Losing shows its reason because an autobattler takes the hands away, so the screen is the whole
## of the feedback — see cell-army-gdd, "오토배틀러로 간 대가". "Enemies left" is NOT repeated here:
## hud_view keeps drawing it underneath, and a count stated in two places diverges.
##
## Item 10 of combat-juice lives here (item 9, the beak stain, died with the reward). It is time the
## screen did not have before. The
## clock is this node's own — combat-juice, section B: the shell skips `battle.step()` entirely while
## the panel is up, so anything hung off sim time would be frozen for exactly the beats these two
## effects exist to fill. `_fx_step` holds the fade's age at zero while the panel is not drawn, so
## the rise starts on the frame it appears and the shell never has to say "rise now".

## Shown on the message band. Titles, not sentences — the panel is read at a glance.
const MSG_WON := "승리"
const MSG_LOST_TIMEOUT := "패배 — 시간 초과"
const MSG_LOST_WIPED := "패배 — 전멸"
## ⚠⚠ **`Battle.Lose.LANDING_LOST` — everyone you SENT is dead, and the ones you kept back can never
## be sent.** It is its own line because 「전멸」 was a lie in this case: the player is looking at
## living soldiers standing at the harbour while the band tells them they were annihilated, and a
## screen that says something the screen disproves stops being read at all.
## The wording is a TITLE, like the other four — 「상륙 실패」 rather than a sentence about reserves,
## because the panel is read at a glance and the reserves are visible underneath it.
const MSG_LOST_LANDING := "패배 — 상륙 실패"
const MSG_LOST := "패배"
const BUTTON_LABEL := "다시 하기"

var run: Run = null
var battle: Battle = null

## Item 10's age, in seconds, of the panel being on screen. Zero whenever it is not.
var _panel_age := 0.0


func bind(r: Run, b: Battle) -> void:
	run = r
	battle = b
	# A new island opens with a clean panel: no half-finished fade.
	_panel_age = 0.0
	queue_redraw()


## True while the panel owns the screen. The shell must not route a click into `button_hit` without
## asking this first — the button's rectangle exists whether it is drawn or not, so a click during a
## battle would land on an invisible button.
##
## ⚠ **It named a second entry point, `soldier_id_at`, until 2026-08-25.** That was the roster the beak
## reward asked the player to click, and it went with the reward — the sentence outlived the function
## it pointed at by one round.
##
## ⚠ **An ALLOW-list, never `state() != BATTLE`.** The denylist form was correct only for as long as
## BATTLE was the only state that is not a panel, and one added `Run.State` member breaks it five ways
## at once: a red 「패배」 band paints over the live screen and the panel then swallows every click,
## drag, pan and zoom, with `panel_active()` reading perfectly true the whole time. This costs nothing
## today — `plan-then-watch`'s planning phase deliberately adds no `Run.State` member, and the gap
## between `_open_island` and the first committed `step` is spent in BATTLE — so this is insurance,
## and it must not be read as evidence that a planning state lives in `Run`.
func panel_active() -> bool:
	return is_finished()


func is_finished() -> bool:
	if run == null:
		return false
	return run.state() == Run.State.WON or run.state() == Run.State.LOST


func button_rect() -> Rect2:
	return Look.button_rect_px()


func button_hit(point: Vector2) -> bool:
	return is_finished() and button_rect().has_point(point)


## Ages item 10's fade. The age is HELD at zero while the panel is down instead of being reset by
## whoever raises it — one place owns it, and there is nothing to forget to call.
func _fx_step(delta: float) -> void:
	if panel_active():
		_panel_age += delta
	else:
		_panel_age = 0.0


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


func _draw() -> void:
	if not panel_active():
		return
	var face := HudView.default_font()
	if face == null:
		return

	# Item 10: the panel rises out of alpha 0 rather than snapping on. Only the backdrop fades —
	# the band and the button keep their own colours, which is what combat-juice pins
	# ("the existing `_paint_panel` colour argument, no new leaf"). The fade IS the beat: a full-alpha
	# cover reads as a cut, and there is nothing left on screen to say a moment just passed.
	var panel := Look.panel_rect_px()
	var bg := Look.COL_PANEL_BG
	var rise := clampf(_panel_age / Look.PANEL_FADE_SEC, 0.0, 1.0)
	bg.a = Look.COL_PANEL_BG.a * lerpf(1.0, rise, Look.fx_gain_of(10))
	_paint_panel(panel, bg)

	# The band sits in the title's line, derived from the title offset rather than from a second
	# pair of numbers, so moving the title in look.gd moves the band with it.
	var band := Rect2(
		Vector2(panel.position.x,
			panel.position.y + Look.PANEL_TITLE_OFFSET_PX.y - Look.PANEL_TITLE_FONT_SIZE_PX),
		Vector2(panel.size.x, Look.PANEL_TITLE_OFFSET_PX.y))
	_paint_message(face, band, Look.COL_BUTTON, _message_text(),
		panel.position + Look.PANEL_TITLE_OFFSET_PX, Look.PANEL_TITLE_FONT_SIZE_PX,
		_message_colour())

	if is_finished():
		var brect := button_rect()
		_paint_button(face, brect, Look.COL_BUTTON, BUTTON_LABEL,
			brect.position + Look.BUTTON_TEXT_OFFSET_PX, Look.PANEL_BODY_FONT_SIZE_PX,
			Look.COL_HUD_TEXT)


# --- hooks. Counts pinned per function by net_draw_leaf; the table is in first-slice, under "The
# view". Every parameter is used in the body, because a leaf that quietly drops one of its arguments
# is invisible on screen and green in the round.

func _paint_panel(rect: Rect2, col: Color) -> void:
	draw_rect(rect, col, true)


func _paint_message(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## ⚠ **A new `Lose` reason opens no new state, and that was checked rather than assumed.** The band and
## the panel are one path: `_draw` returns on `not panel_active()` before this is ever called, and
## `panel_active` keys on `Run.State` alone. The failure this file's own `panel_active` paragraph
## describes — a red 「패배」 band over a live screen, swallowing every click — is reachable by adding a
## `Run.State` member, and `Lose` is not one.
func _message_text() -> String:
	if run.state() == Run.State.WON:
		return MSG_WON
	if battle == null:
		return MSG_LOST
	if battle.lose_reason() == Battle.Lose.TIMEOUT:
		return MSG_LOST_TIMEOUT
	if battle.lose_reason() == Battle.Lose.WIPED:
		return MSG_LOST_WIPED
	if battle.lose_reason() == Battle.Lose.LANDING_LOST:
		return MSG_LOST_LANDING
	# ⚠ `Lose.NONE` with a lost run lands here, and so would a reason added tomorrow. The bare 「패배」
	# is honest about knowing nothing; `net_shell` walks the whole enum so a new member cannot arrive
	# and quietly fall through to it.
	return MSG_LOST


func _message_colour() -> Color:
	if run != null and run.state() == Run.State.WON:
		return Look.COL_WIN
	# ⚠ A third arm here returned the plain text colour for the beak-pick band. **Both the reward and
	# its state are deleted** (2026-08-25), so the panel says exactly two things: won, or lost.
	return Look.COL_LOSE
