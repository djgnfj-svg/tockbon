extends Control
## The one flash that announces a rune ownership grant reaching the screen. `Progress.grant_rune()`
## (`src/actor/`) is silent — no scene tree, no comment on it ever reaches a player. Before this the only
## sign the bull's reward had landed was the assembly palette's fire cell quietly un-veiling, visible only
## once the player happens to open the window (Tab). `trigger(rune_id)` is the one door in, called from
## `stage._take_boss_reward()` at the single call site where a grant actually happens
## (`rune-lock-and-receiving.md` Stage C) — never polled, never derived from `Progress` state.
##
## **Holds its own countdown — the one exception to "derive, do not push".** `onboard_view.gd`'s own header
## states that rule for `visible` because a sim-side flag (`_onboard_step`) already exists to derive it from.
## A grant has no such flag: `Progress._owned_runes` looks identical whether the grant happened one tick ago
## or a thousand, so there is nothing to derive a "just now" flash from. This view is where the state has to
## live.
##
## **Not full-screen, `mouse_filter` is `IGNORE` in the scene** — the same CLAUDE.md risk `onboard_view.gd`
## already names: a full-screen `Control` while the run is live would kill "you can shoot with the window
## open" (design acceptance 4). This box sits centered, well clear of `HP_RECT`/`MONEY_RECT`, and steals no
## input.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/rune_grant_layout.gd")

var _tex: Texture2D
var _elapsed := 0.0
var _active := false


func _ready() -> void:
	position = Fx.RUNE_GRANT_RECT.position
	size = Fx.RUNE_GRANT_RECT.size
	visible = false


## **The one door in.** `rune_id` picks the icon out of `Fx.RUNE_TEX` (the same map `circle_window` already
## loads its rune beads from — no new art). Re-triggering while already showing restarts the countdown
## rather than stacking a second timer; there is exactly one grant in the game today so this branch is
## unexercised in play, but a double call must not read as two overlapping flashes.
func trigger(rune_id: int) -> void:
	var path: String = Fx.RUNE_TEX.get(rune_id, "")
	_tex = (load(path) as Texture2D) if path != "" else null
	_elapsed = 0.0
	_active = true
	visible = true
	queue_redraw()


func _process(dt: float) -> void:
	if not _active:
		return
	_elapsed += dt
	if _elapsed >= Fx.RUNE_GRANT_DURATION_SECS:
		_active = false
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	_paint(Layout.panel_rect(size), Layout.icon_rect(size), Layout.text_baseline_y(size), _tex,
		get_theme_default_font())


## **Named so a net can capture the arguments `_draw()` actually handed it** — the `settlement_layout.
## notice_rect` lesson (CLAUDE.md's own "no fake nets"): a pure layout function asserted alone does not
## prove `_draw()` handed it real content instead of a bare `Rect2()`.
func _paint(panel: Rect2, icon: Rect2, text_y: float, tex: Texture2D, font: Font) -> void:
	draw_rect(panel, Fx.RUNE_GRANT_PANEL_BG, true)
	draw_rect(panel, Fx.RUNE_GRANT_PANEL_EDGE, false, Fx.RUNE_GRANT_PANEL_EDGE_PX)
	if tex != null:
		draw_texture_rect(tex, icon, false)
	if font == null:
		return
	var w := font.get_string_size(Fx.RUNE_GRANT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.RUNE_GRANT_TEXT_SIZE).x
	draw_string(font, Vector2(size.x * 0.5 - w * 0.5, text_y), Fx.RUNE_GRANT_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RUNE_GRANT_TEXT_SIZE, Fx.RUNE_GRANT_TEXT_COLOR)


## Read by a net — whether the flash is currently up, without the net having to race `_process`'s countdown.
func is_active() -> bool:
	return _active
