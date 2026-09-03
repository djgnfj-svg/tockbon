class_name HudView
extends Node2D

## The heads-up layer, and it draws **ONE thing**: the words GAME OVER, once the 성채 has fallen
## (2026-09-01, the user: 「엔딩씬을 생각해봤는데 그냥 게임 오버 뜨면 될 거 같은데? 게임 오버 빨간
## 글씨고 딱 뜨고. 끝」 — *"I thought about the ending scene — I think just showing GAME OVER is enough.
## Red letters, it just appears, and that is the end."*). **The island keeps drawing behind it and the
## board stops answering**, which is the same day's answer and lives in `game.gd`.
##
## ⚠⚠ **「ONE THING」 IS THREE NOW AND THIS LINE IS THE COUNT**: the words, **the picked body's panel**
## (03-02, 2026-09-02) and **the wave alarm** (12-01, 2026-09-03). Each is a plate pulled in a tool
## with lettering typed over it, each is switched by a bool the shell hands in, and each has its own
## `_paint_*` leaves so no net counting one can see another's calls. The paragraph below is the day
## the count was one, kept because what it records is the BAR, not the number.
##
## ⚠⚠ **「ONE THING」 WAS TWO FOR PART OF 2026-09-02 AND IS ONE AGAIN** (ticket 03-12): **the selection
## box** the left drag pulls over the island lived here for a few hours — a pulled picture cut into four
## corners and four stretched edges, in SCREEN space — and the user's verdict on it was that it was not
## the candidate they chose: 「이게 일단 4번이 적용된게 맞음? 이게 아니였는데」 — *"was number 4 applied? this
## was not it."* **The box is a shape on the terrain now, `FieldView.set_box`**, and nothing of it is
## left on this layer: no rect, no picture, no leaf.
##
## ⚠⚠ **IT DREW NOTHING AT ALL FROM 2026-08-28 UNTIL THEN, AND THE BAR THAT ENDED THAT IS THE POINT.**
## Three things went in one day, all on the user's word:
##
## | What | The words |
## |---|---|
## | **the start button** and **the summon slot boxes** | 「게임플레이에서 시작버튼하고 1은 왜있음? 이거 전 게임의 유산인듯 지워줘」 |
## | **the enemies-left count** | 「위에 적이 몇명이나 오는지도 필요없을듯」 |
##
## The first two belonged to the shape the game had **before the sides swapped**: the player authored
## a landing out of boats, pressed 시작, and then watched. ⚠ **They were not merely unused — they
## could not work**: `Battle.commit` refused while `boats` was empty and the only thing that ever
## filled `boats` was `Battle.summon`, driven by those very slot boxes.
## ⚠ **Item 8 of combat-juice (press feedback) went with them** — `note_chip`, the shake and the
## colour flash existed for exactly those two controls and had no other caller.
## ⚠ **The clock was the first to go**, with the rule it counted to (2026-08-24).
##
## ⚠⚠ **THE NODE STAYED AND THAT IS WHY THE LOSS HAD SOMEWHERE TO LAND.** What comes back here is a
## HUD somebody DESIGNED, and `CLAUDE.md` carries the rule it has to be built under: **a screen is
## drawn in a tool, not typed as `draw_rect` calls.** ⚠ **The one thing back in `_draw` obeys it** —
## the lettering is a picture pulled in `tools/pixel/`, not a `draw_string`. Everything else on this
## layer is still deleted, and an empty canvas stays the honest state for it.
## ⚠ **`default_font` and `type_label` are why the class is not deleted outright**: both are STATIC
## and both are read by `panel_view` and `refit_view`.
##
## It READS `battle` and writes nothing back — src/view/ is a reader by contract, and a view that
## nudges the sim makes "the screen changed but the sim did not" indistinguishable from its inverse.
##
## Everything that reaches the screen goes through a `_paint_*` hook and `_draw()` calls nothing
## else. A spy can capture a hook's arguments; it cannot see a native `draw_string` sitting directly
## in `_draw`, which is how a bare draw call once shipped twice under a green round. net_draw_leaf
## pins each hook's `draw_*` count exactly AND reddens any function in this file it does not name,
## so a helper added tomorrow is red until it is listed — adding names only fixes the day it is done.


## ⚠⚠ **`TYPE_LABELS` IS DELETED and the words are a COLUMN of `Rules.UNITS` now.** It was a second
## table indexed by the same ids, and one name could stand in it twice — **one table ends that at the
## cause.**
##
## `type_label` stays as the one call site everything already reads (`panel_view` names soldiers in the
## reward list, `refit_view` labels the beast strip), so nothing outside this line moved.

var battle: Battle = null

## **Whether the 성채 has fallen**, and the ONE thing this layer draws (2026-09-01). It is written by
## `game._process` right after `battle.step`, never read off `battle` here: the shell is the only file
## allowed to turn a screen on, and a view that decided for itself when to cover the board would be a
## second reader of the loss condition to keep in step with the first.
## ⚠ **`_draw` is `pass` no longer** — this is the first thing back in it since 2026-08-28, and the
## header above says what the bar for that is.
var _over := false

## **The words, as a PICTURE.** Pulled in `tools/pixel/` and loaded, because `draw_string` chrome is
## not a placeholder — it is what ships. See `Look.GAME_OVER_TEX` for why no width lives beside it.
var _tex_over: Texture2D = load(Look.GAME_OVER_TEX) as Texture2D
## **The button that takes a lost run back to the title.** ⚠ Loaded the same way and for the same
## reason: it is a picture made in pixellab, not a plate typed as `draw_rect` under a `draw_string`.
var _tex_back: Texture2D = load(Look.BACK_TO_TITLE_TEX) as Texture2D

## **The bodies the hand is holding**, as soldier ids, handed in by the shell every frame (03-02, the
## user: 「캐릭터 누르면 선택되고 정보ㄴ뜨고 이동되는게 필요할듯」). Empty is 「nothing picked」 and the
## panel is not drawn at all. ⚠ A COPY of `hand.ids`, never the same array — a view holding the
## sim's own container is one aliasing bug away from writing it.
var _picked := PackedInt32Array()

## **The plate under the fifteen lines.** Pulled in a tool and loaded, for the reason `_tex_over` gives.
var _tex_panel: Texture2D = load(Look.PANEL_TEX) as Texture2D

## **Whether a wave is inside its warning window** (12-01, the user: 「시간은 3분때만 뜨면 될듯」 —
## *"I think the time only needs to show during the 3 minutes."*). Written by `game._process` off
## `battle.wave_warning_open`, never read off `battle` here, for the reason `_over` gives.
var _warning := false

## **The countdown, ALREADY AS THE SCREEN WILL PRINT IT.**
##
## ⚠⚠ **THE STRING AND NOT THE FLOAT, AND THAT IS WHAT KEEPS THE REDRAWS DOWN TO ONE A SECOND.**
## `wave_seconds_left` changes sixty times a second and 「M:SS」 changes once; holding the float here
## would mean `set_warning` could not tell a frame that changed the picture from one that did not,
## and the layer would ask the engine to repaint an identical canvas fifty-nine times over. **One
## place formats it** — `Look.alarm_clock_text` — and the guard and the draw read that one answer.
var _warning_text := ""

## **The alarm's plate.** Pulled in a tool and loaded, for the reason `_tex_over` gives.
var _tex_alarm: Texture2D = load(Look.ALARM_TEX) as Texture2D

## **The countdown's face**, loaded once and kept beside the other two, and STATIC for the same
## reason they are.
static var _clock_face: Font = null

## Resolved once and kept, and STATIC because panel_view needs the same face — the explanation for
## picking it lives here only, in one file, rather than in both view files.
## `ThemeDB` is available untreed and headless: "there is no font outside the tree" was measured
## wrong twice, and the real cause was a script that quit before turning a single frame.
static var _face: Font = null

## **The panel's own face** — the Hangul pixel font `Look.PANEL_FONT` names — loaded once and kept,
## beside `_face` and for the same reason.
static var _panel_face: Font = null


## The project's own default font carries Hangul; the engine's fallback need not, and a missing
## glyph is SILENT — every Korean label would come out as boxes with the whole round still green.
static func default_font() -> Font:
	if _face != null:
		return _face
	var theme := ThemeDB.get_default_theme()
	if theme != null and theme.default_font != null:
		_face = theme.default_font
	else:
		_face = ThemeDB.fallback_font
	return _face


## **The font the panel is typed in**, not the default face: the panel draws at the pixel font's own
## size, and the theme's Hangul face at 15 px is smooth lettering on a pixel plate.
static func panel_font() -> Font:
	if _panel_face == null:
		_panel_face = load(Look.PANEL_FONT) as Font
	return _panel_face


## **The face the countdown is typed in** — numerals and a colon, not the panel's Hangul face.
## ⚠ It has no Hangul at all, so the alarm's label goes through `panel_font` and only the digits come
## through here; `Look.ALARM_CLOCK_FONT` says why.
static func alarm_font() -> Font:
	if _clock_face == null:
		_clock_face = load(Look.ALARM_CLOCK_FONT) as Font
	return _clock_face


## The word a player reads for a beast row. **One line reading the unit table**, so the name on the
## refit strip and the name in the reward list cannot say two different things.
static func type_label(type_id: int) -> String:
	return Rules.label_of(type_id)


## ⚠ **A bind clears the words**, because a bind is a DIFFERENT island and the last one's verdict is
## not this one's. Left latched, the second island of a run would open under a GAME OVER for the one
## frame before `game._process` reads the fresh `battle.lost` — and 「it just appears」 is the whole of
## what this screen claims, so appearing when nothing happened is the failure.
func bind(b: Battle) -> void:
	battle = b
	_over = false
	# ⚠ Cleared for the same reason `_over` is: the ids survive an island and the last island's pick
	# would open the next one with a panel about a body standing nowhere yet.
	_picked = PackedInt32Array()
	# ⚠ And the alarm, for the third time the same reason: `Run` builds a fresh `Battle` per island so
	# the new one's wave clock starts at a whole interval, and a latched warning would put 「늑대 무리
	# 0:00」 over an island where the next wave is eight minutes out.
	_warning = false
	_warning_text = ""
	queue_redraw()


## The shell says what the hand is holding, and the panel follows.
##
## ⚠⚠ **NO GUARD ON A NON-EMPTY LIST, ON PURPOSE — it is the opposite of `set_over`.** The shell
## calls this once per frame off `hand.ids`, and the 체력 line has to follow the fight, so every
## non-empty call asks for a redraw. **The call that empties the list asks once more** — that is the
## frame the plate comes down — and an empty list after an empty list asks for nothing, which is what
## keeps an unpicked island from redrawing an empty canvas sixty times a second.
func set_picked(ids: PackedInt32Array) -> void:
	var was_empty := _picked.is_empty()
	_picked = ids.duplicate()
	if not _picked.is_empty() or not was_empty:
		queue_redraw()


## The shell says the island is lost, and the words go up.
##
## ⚠⚠ **IT RETURNS ON NO CHANGE, AND THAT IS WHAT KEEPS `_process` DELETED.** The shell calls this
## once per frame off `battle.lost`, so a `queue_redraw()` with no guard would be the sixty-a-second
## redraw of a canvas nobody can see that the header above records deleting. **A `Node2D`'s canvas
## survives until it is asked to redraw**, so the words stay up between calls without one.
## ⚠ **It takes a bool rather than being a `note_lost()`**, so the OFF edge exists: a run that opens a
## second island must not inherit the last one's words, and a setter with no false arm would leave
## `_over` latched for the life of the node.
func set_over(over: bool) -> void:
	if over == _over:
		return
	_over = over
	queue_redraw()


## The shell says a wave is inside its warning window and how long is left, and the alarm goes up.
##
## ⚠⚠ **THE GUARD COMPARES THE PRINTED STRING, NOT THE FLOAT** — see `_warning_text`. The shell calls
## this every frame while the sim runs; the picture changes once a second, and comparing the seconds
## the screen would show is the difference between one redraw and sixty.
## ⚠ **It takes the window's state rather than being a `note_wave()`**, so the OFF edge exists: the
## call that closes the window is the frame the plate comes down, and a setter with no false arm
## would leave the alarm up for the rest of the island.
func set_warning(open: bool, seconds_left: float) -> void:
	var shown := Look.alarm_clock_text(seconds_left) if open else ""
	if open == _warning and shown == _warning_text:
		return
	_warning = open
	_warning_text = shown
	queue_redraw()


## ⚠⚠ **THERE IS NO `_process` ANY MORE.** It called `queue_redraw()` every frame so the enemy count
## could follow the sim; **with nothing drawn there is nothing to keep fresh**, and a node asking the
## engine to redraw an empty canvas sixty times a second is work nobody can see. It comes back with
## whatever the designed HUD needs, and not one frame earlier.


## **The words once the island is lost, and nothing else.** Everything else on this layer is still
## deleted — see the header, and the ticket's own "out of scope" (no win screen, no stats, no way
## back). While the island stands this is the empty canvas it has been since 2026-08-28. ⚠ The
## selection box was drawn above this early return for part of 2026-09-02 and is the field's now.
## ⚠ **`battle` is still bound** by `game._open_island`, so the wiring a real HUD needs is live and
## `net_shell` still measures that the bind happened. ⚠ **`_over` and not `battle.lost`** — see
## `set_over`; the shell owns which screen is up.
##
## **And the panel, while the hand holds somebody** (03-02, layout A 「세 칸」). The plate goes down
## first, then **fifteen lines**: the name line across the top — the first held body's name, with
## 「x N」 when the hand holds more — and three columns under it, each a head word on its own line
## with its values under it as 「label value」, one space between:
##
## | column | lines | read off |
## |---|---|---|
## | 상태 | 「체력 현재/최대」 · 「허기 N」 · 「특성 」 | `Battle.soldier_hp` / `Army.max_hp_of` · `Army.hunger_of` · nothing yet (11-01) |
## | 능력치 | 「공격력 N」 · 「방어력 N」 · 「공격간격 N.N초」 | `Army.damage_of` · `Rules.defense_of` · `Army.period_of` |
## | 적성 | one 「<word> N/최대」 per row of `Rules.APTITUDES` | `Army.aptitude_of` / `Rules.APTITUDE_MAX` |
##
## **And the wave alarm, while a wave is inside its warning window** (12-01): the plate top-left,
## flush with the viewport edge, with 「늑대 무리」 on it and the countdown beside that. It is drawn
## above the `_over` return and above the panel, so the alarm and the panel stand together — the
## alarm's corner is TOP_LEFT and the panel's is BOTTOM_LEFT, and `Look.corner_origin_px` is the one
## place that says what either of those means.
##
## ⚠⚠ **AND `not _over`, WHICH IS A REPAIR AND NOT A TIDY-UP.** Drawn without it, a lost run was
## photographed under GAME OVER with the alarm still up and **frozen at 「2:57」** — the sim stops
## advancing after a loss, so the countdown stops with it. **A finished run promising 늑대 in three
## minutes is the screen saying something that is not true**, which is the one thing this layer is
## not allowed to do. ⚠ **The panel deliberately does NOT take this guard**: 「이 몸의 체력은 이것이다」
## is still true on a board that has fallen, and a promise about the future is not.
## ⚠ **`_warning` and not `battle.wave_warning_open`** — see `set_warning`; the shell owns which
## screen is up, exactly as it does for the loss.
##
## ⚠ **The 「특성 」 line is painted with its blank value**, so the count is fifteen whether or not
## a body has a word there — a count that moved with the data would be a net that cannot pin it.
## ⚠ **The first id the hand holds is shown, alive or not** — `Hand` never prunes a dead body, so
## 「체력 0/max」 is the panel's honest resting state after a picked body dies, until 03-14 prunes the
## hand. ⚠ **`Look.PANEL_LABELS` is read by position, in its own order** — the name line, then the
## 상태 four, the 능력치 four, then the 적성 head; the five aptitude words are `Rules.APTITUDES`'s.
## ⚠ **The origin is laid out from `Look.PANEL_SIZE_PX` and not from the picture's size** — the plate
## is pulled AT that size and the net asserts it is; a layout that re-fitted itself to the file would
## hide a wrongly-sized plate under green checks.
func _draw() -> void:
	if _warning and not _over and _tex_alarm != null:
		var alarm_at := Look.alarm_origin_px(Look.ALARM_SIZE_PX)
		_paint_alarm(_tex_alarm, alarm_at)
		_paint_alarm_line(Look.ALARM_LABEL, Look.alarm_baseline_px(alarm_at, 0), panel_font(),
			Look.ALARM_LABEL_FONT_PX, Look.COL_ALARM_TEXT)
		_paint_alarm_line(_warning_text, Look.alarm_baseline_px(alarm_at, 1), alarm_font(),
			Look.ALARM_CLOCK_FONT_PX, Look.COL_ALARM_TEXT)
	if battle != null and not _picked.is_empty() and _tex_panel != null:
		var font := panel_font()
		var ascent := font.get_ascent(Look.PANEL_FONT_PX)
		var origin := Look.panel_origin_px(Look.PANEL_SIZE_PX)
		var id := int(_picked[0])
		var army: Army = battle.army
		var labels: Array = Look.PANEL_LABELS
		# ⚠ `who`, not `name` — a Node already has a `name`, and a shadowed member is a warning on
		# stderr, which the runner counts as red.
		var who: String = army.name_of(id)
		if _picked.size() > 1:
			who += " x %d" % _picked.size()
		var status := [
			str(labels[1]),
			"%s %d/%d" % [str(labels[2]), int(battle.soldier_hp[id]), int(army.max_hp_of(id))],
			"%s %d" % [str(labels[3]), int(army.hunger_of(id))],
			"%s " % str(labels[4]),
		]
		var stats := [
			str(labels[5]),
			"%s %d" % [str(labels[6]), int(army.damage_of(id))],
			"%s %d" % [str(labels[7]), int(Rules.defense_of(int(army.type_id[id])))],
			"%s %.1f초" % [str(labels[8]), army.period_of(id)],
		]
		var aptitudes := [str(labels[9])]
		for k in Rules.APTITUDES.size():
			aptitudes.append("%s %d/%d" % [str(Rules.APTITUDES[k]), army.aptitude_of(id, k),
				Rules.APTITUDE_MAX])
		_paint_panel(_tex_panel, origin)
		_paint_line("%s %s" % [str(labels[0]), who], Look.panel_line_baseline_px(origin, 0, ascent),
			font, Look.PANEL_FONT_PX, Look.COL_PANEL_TEXT)
		var columns := [status, stats, aptitudes]
		for c in columns.size():
			var column: Array = columns[c]
			for l in column.size():
				_paint_line(str(column[l]), Look.panel_cell_baseline_px(origin, c, l, ascent), font,
					Look.PANEL_FONT_PX, Look.COL_PANEL_TEXT)
	if not _over or _tex_over == null:
		return
	_paint_over(_tex_over, Look.game_over_origin_px(_tex_over.get_size()))
	var back := back_rect_px()
	if back.size.x > 0.0:
		_paint_back(_tex_back, back.position)


## **Where the back-to-title button is, or a zero rect when there is no button to press.**
##
## ⚠⚠ **THE SHELL HIT-TESTS THIS AND `_draw` DRAWS THIS**, which is the whole reason it is a function
## and not two rectangles. A hit rect written beside a draw position is how a button ends up pressable
## somewhere it is not drawn, and the two only disagree once somebody re-pulls one of the pictures.
## ⚠ **Zero while the island stands.** `_over` is the shell's own flag — see `set_over` — so a click
## on a live board can never land on a button that is not on screen.
func back_rect_px() -> Rect2:
	if not _over or _tex_over == null or _tex_back == null:
		return Rect2()
	return Look.back_to_title_rect_px(_tex_over.get_size(), _tex_back.get_size())


## The words GAME OVER, drawn 1:1 at their own size.
##
## ⚠⚠ **NO `draw_string` AND NO RECT BEHIND IT.** The lettering is a picture pulled in `tools/pixel/`,
## which is the rule `CLAUDE.md` carries by name — chrome typed as draw calls is not a placeholder, it
## is the thing that ships. A `draw_texture_rect` with a size of its own would put the picture's width
## in a second place; `draw_texture` takes the file's width as the answer.
func _paint_over(tex: Texture2D, at: Vector2) -> void:
	draw_texture(tex, at)


## The back-to-title button, drawn 1:1 at its own size.
##
## ⚠⚠ **ONE `draw_texture` AND NOTHING ELSE, exactly like the lettering above it.** A hover tint or a
## press flash typed in here would be chrome nobody chose; the day the button reacts to the cursor, it
## reacts by wearing a SECOND picture, and this leaf still draws one thing.
func _paint_back(tex: Texture2D, at: Vector2) -> void:
	draw_texture(tex, at)


## The plate under the picked body's lines, drawn 1:1 at its own size.
##
## ⚠⚠ **ONE `draw_texture` AND NO RECT**, like the two leaves above it: the plate is a picture pulled
## in a tool, and `draw_texture` takes the file's own width so no second copy of it lives here.
func _paint_panel(tex: Texture2D, at: Vector2) -> void:
	draw_texture(tex, at)


## One line of the panel, typed in the panel's font at the panel's size — the house shape is
## `title_view.gd`'s `draw_string`.
##
## ⚠⚠ **THE SIZE AND THE COLOUR ARRIVE AS ARGUMENTS SO THE SPY SEES THEM.** `draw_string` defaults to
## 16 px, and a leaf that read `Look.PANEL_FONT_PX` for itself could be edited to omit the size with
## every hook capture still green; through the argument, `net_panel` reads 15 off the call.
## `at` IS the baseline — `Look.panel_line_baseline_px` already added the ascent.
func _paint_line(text: String, at: Vector2, font: Font, size_px: int, col: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


## The alarm's plate, drawn 1:1 at its own size.
##
## ⚠⚠ **ONE `draw_texture` AND NO RECT**, like the three leaves above it. The banner — the red, the
## gold rails, the torn ends — is all in the file; a rect or a border typed here would be chrome
## nobody chose, over a picture the user chose by looking.
func _paint_alarm(tex: Texture2D, at: Vector2) -> void:
	draw_texture(tex, at)


## One line on the alarm's plate, typed in whichever face it was handed at whichever size.
##
## ⚠⚠ **IT IS A SECOND LEAF AND NOT `_paint_line`, ON PURPOSE.** The two bodies are the same call and
## that is not an accident to be tidied away: `net_panel` spies `_paint_line` and counts what comes
## through it as the panel's fifteen lines, so an alarm sharing that hook would put two more in the
## spy's list the moment a warning opened over a picked body — a net going red about a panel that
## never changed. **A leaf per plate keeps each one's count its own**, which is also what lets
## `net_draw_leaf` say 「the alarm painted nothing while it was closed」 without reading any text.
## `at` IS the baseline — `Look.alarm_baseline_px` already placed it.
func _paint_alarm_line(text: String, at: Vector2, font: Font, size_px: int, col: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
