class_name PanelView
extends Node2D

## The overlay between islands: pick who gets the beak, and — when the run ends — say WHY it ended
## and offer a restart.
##
## ⚠ This is a Node2D and NOT a Control, deliberately. `set_anchors_preset` sets anchors and leaves
## the offsets alone, so a Control added to a bare layer keeps `size == (0, 0)` and piles into the
## top-left corner while every check about it passes. It draws its own rectangles and hands the
## shell hit-rects instead of owning a Button.
##
## It READS `run` and `battle` and writes neither. Clicking is the shell's job: `soldier_id_at` and
## `button_hit` answer "what is under this point", and `Run.apply_beak` / `Run.restart` are called
## by the shell, not here. src/view/ is the only folder with no way to change what happens.
##
## `_draw()` calls `_paint_*` hooks and nothing else, and net_draw_leaf pins each hook's `draw_*`
## count and reddens any function here it does not name. `roster_rect_of` and `button_rect` exist
## precisely so the hit test and the picture read the same rectangle out of look.gd — a hit rect
## computed a second time by the shell is the same value living in two places.
##
## Losing shows its reason because an autobattler takes the hands away, so the screen is the whole
## of the feedback — see cell-army-gdd, "오토배틀러로 간 대가". "Enemies left" is NOT repeated here:
## hud_view keeps drawing it underneath, and a count stated in two places diverges.
##
## Items 9 and 10 of combat-juice live here, and both are time the screen did not have before. The
## clock is this node's own — combat-juice, section B: the shell skips `battle.step()` entirely while
## the panel is up, so anything hung off sim time would be frozen for exactly the beats these two
## effects exist to fill. `_fx_step` holds the fade's age at zero while the panel is not drawn, so
## the rise starts on the frame it appears and the shell never has to say "rise now".

## Shown on the message band. Titles, not sentences — the panel is read at a glance.
const MSG_REWARD := "부리를 달 병사를 고르세요"
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

## Item 9's drawer: `army id -> seconds of stain left`. Keyed by the soldier and not by the roster
## row, because the row index is a place on screen and the stain belongs to the body — a roster that
## reorders would otherwise move the colour onto somebody else.
var _beak_fx: Dictionary = {}

## Item 10's age, in seconds, of the panel being on screen. Zero whenever it is not.
var _panel_age := 0.0


func bind(r: Run, b: Battle) -> void:
	run = r
	battle = b
	# A new island opens with a clean panel: no leftover stain, no half-finished fade.
	_beak_fx.clear()
	_panel_age = 0.0
	queue_redraw()


## True while the panel owns the screen. The shell must not route a click into `soldier_id_at` or
## `button_hit` without asking this first — the panel's rectangles exist whether it is drawn or not,
## so a click during a battle would land on an invisible roster.
##
## ⚠ **An ALLOW-list, never `state() != BATTLE`.** The denylist form was correct only for as long as
## BATTLE was the only state that is not a panel, and one added `Run.State` member breaks it five ways
## at once: a red 「패배」 band paints over the live screen and the panel then swallows every click,
## drag, pan and zoom, with `panel_active()` reading perfectly true the whole time. This costs nothing
## today — `plan-then-watch`'s planning phase deliberately adds no `Run.State` member, and the gap
## between `_open_island` and the first committed `step` is spent in BATTLE — so this is insurance,
## and it must not be read as evidence that a planning state lives in `Run`.
func panel_active() -> bool:
	return run != null and (run.state() == Run.State.REWARD or is_finished())


func is_reward() -> bool:
	return run != null and run.state() == Run.State.REWARD


func is_finished() -> bool:
	if run == null:
		return false
	return run.state() == Run.State.WON or run.state() == Run.State.LOST


## Living soldier ids in ascending id order, capped at what the panel can physically show.
##
## ⚠ **This comment used to say the cap never actually bites, and the node map made that false once
## already.** `Look.PANEL_SIZE_PX`'s own header carries the current arithmetic — `roster_capacity()` is
## now pinned CONSERVATIVE, at the largest roster a run can ever field (22), specifically so this cap
## does not have to be re-derived from where the beak nodes happen to sit on a route. It is still here
## so that a roster grown past the panel drops entries instead of drawing a clickable rectangle outside
## the viewport, and `net_shell`'s 22-body fixture is what keeps this line honest.
func roster_ids() -> Array:
	var ids := []
	if run == null or run.army == null:
		return ids
	var a := run.army
	for i in a.type_id.size():
		if a.alive[i] == 0:
			continue
		ids.append(i)
		if ids.size() >= Look.roster_capacity():
			break
	return ids


## Absolute viewport rect of one roster slot. Empty for an index the panel does not have, so a stray
## hit test cannot match — Rect2() has no area and `has_point` is false for every point.
func roster_rect_of(entry_index: int) -> Rect2:
	if entry_index < 0 or entry_index >= Look.roster_capacity():
		return Rect2()
	return Look.roster_entry_rect_px(entry_index)


## The army id under `point`, or -1. Returns -1 outside the REWARD state so that a click landing on
## the win screen cannot bolt a beak onto anybody.
func soldier_id_at(point: Vector2) -> int:
	if not is_reward():
		return -1
	var ids := roster_ids()
	for e in ids.size():
		if roster_rect_of(e).has_point(point):
			return int(ids[e])
	return -1


func button_rect() -> Rect2:
	return Look.button_rect_px()


func button_hit(point: Vector2) -> bool:
	return is_finished() and button_rect().has_point(point)


## Stains the picked row. The shell calls this BEFORE `run.apply_beak` and then holds for
## `HOLD_BEAK_SEC` before applying it.
##
## ⚠ The order is the whole of why this effect exists at all: `run.apply_beak` ends in `_advance()`,
## which puts the run back into BATTLE, and `panel_active()` is false the instant it does — so a
## shell that applies first shows this for zero frames no matter how long it then waits. Deferring
## also makes the check honest: while the hold runs, `army.has_beak[id]` is STILL 0, so the row can
## only look different because of this call. See combat-juice, item 9.
func note_beak(id: int) -> void:
	if id < 0:
		return
	_beak_fx[id] = Look.HOLD_BEAK_SEC


## Ages item 9's drawer and item 10's fade. `keys()` hands back a copy, so erasing inside the loop is
## safe. The fade's age is HELD at zero while the panel is down instead of being reset by whoever
## raises it — one place owns it, and there is nothing to forget to call.
func _fx_step(delta: float) -> void:
	if panel_active():
		_panel_age += delta
	else:
		_panel_age = 0.0
	for id in _beak_fx.keys():
		var left := float(_beak_fx[id]) - delta
		if left <= 0.0:
			_beak_fx.erase(id)
		else:
			_beak_fx[id] = left


## The background of one roster row. `COL_BUTTON` at rest; pulled to `COL_BEAK` the frame the row is
## picked and easing back over `HOLD_BEAK_SEC`, which is deliberately the same constant as the shell's
## hold — one concept, one constant, so the stain cannot outlive the panel or finish early.
##
## `entry_index` is the row and `id` is the soldier; both are checked, because a row the panel cannot
## physically show must not answer with a colour any more than `roster_rect_of` answers with a rect.
func _entry_bg(entry_index: int, id: int) -> Color:
	if entry_index < 0 or entry_index >= Look.roster_capacity():
		return Look.COL_BUTTON
	if not _beak_fx.has(id):
		return Look.COL_BUTTON
	var p := clampf(1.0 - float(_beak_fx[id]) / Look.HOLD_BEAK_SEC, 0.0, 1.0)
	return Look.COL_BUTTON.lerp(Look.COL_BEAK, (1.0 - p) * Look.fx_gain_of(9))


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
	# the band, the roster and the button keep their own colours, which is what combat-juice pins
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

	if is_reward():
		var a := run.army
		var ids := roster_ids()
		for e in ids.size():
			var i := int(ids[e])
			var rect := roster_rect_of(e)
			var beaked := a.has_beak[i] != 0
			_paint_roster_entry(face, rect, _entry_bg(e, i), _entry_text(i, beaked),
				rect.position + Look.ROSTER_TEXT_OFFSET_PX, Look.PANEL_BODY_FONT_SIZE_PX,
				Look.COL_BEAK if beaked else Look.COL_HUD_TEXT)

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


func _paint_roster_entry(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## HP is shown against the type's maximum, not on its own: the reward asks "who is worth the beak",
## and 8 HP means one thing on a melee body and half a life on a ranged one.
func _entry_text(i: int, beaked: bool) -> String:
	var a := run.army
	var t := int(a.type_id[i])
	var line := "%d  %s  %.0f/%.0f" % [i, HudView.type_label(t), a.hp[i], a.max_hp_of(i)]
	return (line + "  부리") if beaked else line


## ⚠ **A new `Lose` reason opens no new state, and that was checked rather than assumed.** The band and
## the panel are one path: `_draw` returns on `not panel_active()` before this is ever called, and
## `panel_active` keys on `Run.State` alone. The failure this file's own `panel_active` paragraph
## describes — a red 「패배」 band over a live screen, swallowing every click — is reachable by adding a
## `Run.State` member, and `Lose` is not one.
func _message_text() -> String:
	if is_reward():
		return MSG_REWARD
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
	if is_reward():
		return Look.COL_HUD_TEXT
	return Look.COL_LOSE
