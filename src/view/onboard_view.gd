extends Control
## Onboarding's one visual — an arrow pointing at the **key** Tab, plus a drawn key cap since Tab is not a
## thing that exists anywhere on screen otherwise (`onboarding-and-palette-tabs.md` Stage 7's own named
## problem: the HUD key line already says "Tab 조립창" but sits behind F3).
##
## **A backing panel and a sentence were added after the user's first look — 「온보딩이 잘 안 보이고」.** The
## arrow and key cap alone painted straight onto the world with nothing behind them, so a bright patch of
## sky or dirt at this screen position could match the warm-yellow arrow's own brightness; and an arrow at
## an invented key with no words never said what pressing it does. Both fixes are in `fx_tuning.gd`'s
## `ONBOARD_*` block, not here — this file only draws what that block and `onboard_layout.gd` hand it.
##
## **Purely presentational — it holds no onboarding state of its own.** `stage.gd` derives `visible` every
## frame from `_onboard_step`, the same "derive, do not push" idiom `_town_view.visible = _in_town` and
## `_research_window`'s own comment on that idiom already hold: a second latch here could go stale the
## moment a path that changes the step forgets to also touch this node's `visible`.
##
## **Not full-screen, and `mouse_filter` is `IGNORE` in the scene** — CLAUDE.md's own risk: a full-screen
## `Control` while the run is live would kill "you can shoot with the window open" (design acceptance 4).
## This box sits near the bottom of the screen and steals no input at all.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/onboard_layout.gd")


func _ready() -> void:
	position = Fx.ONBOARD_RECT.position
	size = Fx.ONBOARD_RECT.size


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	_draw_onboard_panel(Layout.panel_rect(size))
	_draw_onboard_text(Layout.text_baseline_y(size), font)
	_draw_onboard_key(Layout.key_rect(size), font)
	_draw_onboard_arrow(Layout.arrow_rect(size))


## The backing panel, drawn under everything else — see `onboard_layout.panel_rect`'s own comment for why
## this box cannot assume a dark background the way a real window can.
func _draw_onboard_panel(rect: Rect2) -> void:
	draw_rect(rect, Fx.ONBOARD_PANEL_BG, true)
	draw_rect(rect, Fx.ONBOARD_PANEL_EDGE, false, Fx.ONBOARD_PANEL_EDGE_PX)


## The instruction sentence, centered on `y` (its own baseline). **Named so a net can capture the string
## it was actually handed** — the same `notice_rect` lesson `_draw_onboard_key` already cites: a pure
## layout function asserted alone does not prove `_draw()` handed it real content.
func _draw_onboard_text(y: float, font: Font) -> void:
	if font == null:
		return
	var w := font.get_string_size(Fx.ONBOARD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.ONBOARD_TEXT_SIZE).x
	draw_string(font, Vector2(size.x * 0.5 - w * 0.5, y), Fx.ONBOARD_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.ONBOARD_TEXT_SIZE, Fx.ONBOARD_TEXT_COLOR)


## The key cap. **Named so a net can capture the rect it was actually handed** — the `settlement_layout.
## notice_rect` lesson: a pure function asserted alone let `_draw()` hand it a bare `Rect2()` once, under
## 320 green checks.
func _draw_onboard_key(rect: Rect2, font: Font) -> void:
	draw_rect(rect, Fx.ONBOARD_KEY_BG, true)
	draw_rect(rect, Fx.ONBOARD_KEY_EDGE, false, Fx.ONBOARD_KEY_EDGE_PX)
	if font == null:
		return
	var w := font.get_string_size(Fx.ONBOARD_KEY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.ONBOARD_KEY_TEXT_SIZE).x
	draw_string(font, rect.get_center() + Vector2(-w * 0.5, Fx.ONBOARD_KEY_TEXT_SIZE * 0.35),
		Fx.ONBOARD_KEY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.ONBOARD_KEY_TEXT_SIZE, Fx.ONBOARD_KEY_TEXT_COLOR)


## A filled triangle pointing down at the key cap — the simplest shape that reads as "there, specifically"
## without new art for a first slice (design's own "what the arrow looks like" TBD).
func _draw_onboard_arrow(rect: Rect2) -> void:
	var pts: Array[Vector2] = [
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.get_center().x, rect.position.y + rect.size.y),
	]
	draw_polygon(pts, [Fx.ONBOARD_ARROW_COLOR])
