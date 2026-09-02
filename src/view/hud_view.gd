class_name HudView
extends Node2D

## The heads-up layer, and it draws **ONE thing**: the words GAME OVER, once the 성채 has fallen
## (2026-09-01, the user: 「엔딩씬을 생각해봤는데 그냥 게임 오버 뜨면 될 거 같은데? 게임 오버 빨간
## 글씨고 딱 뜨고. 끝」 — *"I thought about the ending scene — I think just showing GAME OVER is enough.
## Red letters, it just appears, and that is the end."*). **The island keeps drawing behind it and the
## board stops answering**, which is the same day's answer and lives in `game.gd`.
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
## table indexed by the same ids, and the split showed on screen: 까마귀 stood in it twice, because the
## player's ranged row borrowed the enemy crow's body while the CROW row was the enemy species itself.
## That duplicate was user-approved as an interim (2026-08-24: 「구지? 그냥 까마귀라고 하면 되는거
## 아니야?」) and the five-species roster is what dissolves it — **at the cause, by there being one
## table.**
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

## Resolved once and kept, and STATIC because panel_view needs the same face — the explanation for
## picking it lives here only, in one file, rather than in both view files.
## `ThemeDB` is available untreed and headless: "there is no font outside the tree" was measured
## wrong twice, and the real cause was a script that quit before turning a single frame.
static var _face: Font = null


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
func _draw() -> void:
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

