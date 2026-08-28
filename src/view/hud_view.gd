class_name HudView
extends Node2D

## The heads-up layer, and **it draws NOTHING** (2026-08-28).
##
## ⚠⚠ **THE ISLAND SCREEN HAS NO HUD AT ALL.** Three things went in one day, all on the user's word:
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
## ⚠⚠ **THE NODE STAYS AND THAT IS THE POINT.** What comes back here is a HUD somebody DESIGNED, and
## `CLAUDE.md` now carries the rule it has to be built under: **a screen is drawn in a tool, not typed
## as `draw_rect` calls.** An empty `_draw` is the honest state until then — a layer drawing
## placeholder chrome nobody chose is exactly what this round deleted.
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


func bind(b: Battle) -> void:
	battle = b
	queue_redraw()


## ⚠⚠ **THERE IS NO `_process` ANY MORE.** It called `queue_redraw()` every frame so the enemy count
## could follow the sim; **with nothing drawn there is nothing to keep fresh**, and a node asking the
## engine to redraw an empty canvas sixty times a second is work nobody can see. It comes back with
## whatever the designed HUD needs, and not one frame earlier.


## **Deliberately empty**, and it is not a stub waiting to be filled in by hand — see the header. The
## island screen carries no chrome at all until a designed one arrives.
## ⚠ **`battle` is still bound** by `game._open_island`, so the wiring a real HUD needs is live and
## `net_shell` still measures that the bind happened.
func _draw() -> void:
	pass
