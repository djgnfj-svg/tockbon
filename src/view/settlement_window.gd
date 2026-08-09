extends Control
## The run-end settlement screen — `docs/plans/3.done/run-end-settlement.md`. The one screen in this game
## allowed to stop the world: "the world is not visible behind it and the sim stops — the run is over, so
## there is nothing left to watch" (that doc's own Screen section). `circle_window.gd`'s own header narrows
## its repo-wide "no full-screen `Control` is laid down" claim to "while the run is live" for exactly this
## screen — see that file's comment for the argument.
##
## **It snapshots, it does not read `Progress` live.** `open()` takes three plain ints and holds them. The
## button's own click runs `enter_town() -> reset_stage() -> Progress.reset()` in the same call chain; a live
## read would draw the panel at 0 on the very frame it is closing, with nothing barking (this doc's own
## "get the order backwards" trap — closed here by construction, not by discipline).
##
## **A signal, not a call into the shell.** `src/view/` is not in fact forbidden from referencing
## `src/stage/` — `net_layers.RULES` lists it as forbidden nothing, and `run-end-settlement.md`'s own
## Correction log voids the plan's earlier claim otherwise. The real reason is testability: a window that
## calls the shell directly cannot stand up without a stage, and the technique this file's own net uses —
## drive the node outside the tree, read the result — depends on never needing one.
##
## **`tick_countup()` is driven by `stage._physics_process`, never by this node's own `_process()`.**
## `three_pick_window.tick_confirm()`'s own header records the exact lesson this copies: a screen clock on the
## idle rate and a HUD reader on the physics rate open a one-frame seam between them.
##
## **Copies `three_pick_window`'s node contract**: seated from `Fx` in `_ready()`, `focus_mode = NONE` here,
## `mouse_filter = STOP` written in the scene (`stage.tscn`), not overwritten here — the same reason
## `three_pick_window.gd`'s own header gives for leaving that value alone. **And its `visible`/`queue_redraw()`
## discipline too** (`_process()`'s own header there: `visible = pick_open or ...`; `if visible: queue_redraw()`)
## — `open()`/`close()` write `visible` directly (there is no per-frame derivation to read here, since this
## window snapshots instead of tracking `Progress` live), and `tick_countup()` is this window's one per-frame
## hook, so that is where the redraw request belongs.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/settlement_layout.gd")

## Fired on the one button. `stage.gd` connects this to `enter_town` (Stage D — not wired yet).
signal town_pressed

## **`RESEARCH_ICONS["material"]` reused, not a sixth entry** — `SETTLEMENT_ICON_COLOR`'s own comment. A plain
## `Texture2D`, not a collection, so it needs no entry in `net_pick`'s allowlist (this file's own header on
## `_showing`/`_seconds`/etc. names the same scan).
var _gem_icon: Texture2D = load(Fx.RESEARCH_ICONS["material"])

## **All five fields are plain `bool`/`int`** — no `Array`/`Dictionary` here, so this file needs no entry in
## `net_pick._no_pushed_out_glyph_is_stashed_anywhere`'s allowlist (that scan's own header: `const` is exempt,
## a `var` collection is not — this file simply has none).
var _showing := false
var _seconds := 0
var _damage := 0
var _gems := 0
## **Which title `_draw()` picks** (`gate-ending-to-game.md`, Stage D). Snapshotted the same way the other
##  three fields are — a live read would let the flag that decided it move out from under an open panel.
var _cleared := false
## Frames counted since the last `open()`, by `tick_countup()` — the count-up's only clock, and it lives here
## rather than in `Progress` because it is screen-only state, not sim state (the same split `three_pick_
## window._confirm_ticks` already holds for its own afterglow timer).
var _frames := 0


func _ready() -> void:
	position = Fx.SETTLEMENT_RECT.position
	size = Fx.SETTLEMENT_RECT.size
	focus_mode = FOCUS_NONE


## **Snapshots, nothing more.** See this file's own header for why a live `Progress` read is exactly the trap
## this function exists to avoid — the caller (`stage.gd`) reads `pr.run_seconds()`/`pr.damage_dealt`/
## `pr.gems_this_run()` once, here, and this window never touches `Progress` again for the rest of the time
## it is open.
##
## **`cleared` has no default value** (`gate-ending-to-game.md`, Stage D — the repo's own rule,
## `cell_grid.cmd_fill`/`character.take_hit`'s own signatures: a call site that forgets a load-bearing
## argument must not silently pick a behaviour). A caller that forgot this argument would draw a clear as a
## death, or the reverse — exactly the fake this repo bans, so GDScript refuses to compile the call instead.
func open(seconds: int, damage: int, gems: int, cleared: bool) -> void:
	_showing = true
	_seconds = seconds
	_damage = damage
	_gems = gems
	_cleared = cleared
	_frames = 0
	# **The actual `Control` property, not only the internal flag** — `is_showing()` reading `_showing` alone
	#  told the rest of the shell the truth while the node itself stayed invisible on screen. `visible` is what
	#  the engine actually draws (and what a real click's `_gui_input` routing depends on).
	visible = true


## Called by `stage.reset_stage()` (Stage D), the same reason `three_pick_window.cancel_confirm()` exists —
## the count-up clock lives here, not in `Progress`, so nothing else would ever clear it on `R`.
func close() -> void:
	_showing = false
	visible = false


func is_showing() -> bool:
	return _showing


## Called once per physics tick from `stage._physics_process` (Stage D) — **not** from this node's own
## `_process()` (this file's own header). A no-op while closed, the same guard `three_pick_window.tick_
## confirm()`'s own `_confirm_ticks <= 0` check holds — there is nothing to advance if nobody is looking.
func tick_countup() -> void:
	if not _showing:
		return
	_frames += 1
	# **The count-up is the whole animation** (`settlement_layout.count_value`'s own header) — without a
	#  redraw request each tick, `_draw()` never runs again after the first frame and the shown 원석 freezes at
	#  whatever it was then, even though `shown_gems()` itself keeps advancing correctly underneath.
	queue_redraw()


## The 원석 figure currently on screen. `settlement_layout.count_value` is the entire animation (that
## function's own header) — this is only the one place `_gems`/`_frames` are threaded into it.
func shown_gems() -> int:
	return Layout.count_value(_gems, _frames)


## **Window-local coordinates already** — the same reason `three_pick_window._gui_input` takes clicks this
## way rather than through `_unhandled_input`: draw and click must read the same rects, and both read them
## from `Layout` directly.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# A click anywhere on this screen is not firing — there is nothing left to shoot at (this file's own
	#  header: the sim has stopped). Accepting unconditionally matches `circle_window`/`three_pick_window`'s
	#  own "inside this rect, the click does not leak" contract, widened here to the whole 960x540 canvas.
	accept_event()
	if not _showing:
		return
	if Layout.button_rect(size).has_point(mb.position):
		town_pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Fx.SETTLEMENT_BG, true)
	draw_rect(r, Fx.SETTLEMENT_EDGE, false, Fx.SETTLEMENT_EDGE_PX)

	# If there is no font it does not draw further — passing `null` barks every frame, and the wrapper counts
	#  stderr as failure (the same guard `three_pick_window._draw`/`circle_window._draw` already hold).
	var font := get_theme_default_font()
	if font == null:
		return

	# **The one line this Stage adds** (`gate-ending-to-game.md`, Stage D) — everything else about the panel
	#  is unchanged: no extra row, no bonus, no second layout.
	var title := Fx.SETTLEMENT_TITLE_CLEAR if _cleared else Fx.SETTLEMENT_TITLE
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_TITLE_SIZE).x
	_draw_title(font, title, Vector2((size.x - title_w) * 0.5, Fx.SETTLEMENT_PAD_PX + float(Fx.SETTLEMENT_TITLE_SIZE)))

	var rows := Layout.rows(size)
	_draw_row(rows[0], font, Fx.SETTLEMENT_TIME_LABEL, Layout.time_text(_seconds))
	_draw_row(rows[1], font, Fx.SETTLEMENT_DAMAGE_LABEL, "%d" % _damage)
	_draw_gems_row(rows[2], font)

	# **On a clear only** (`stage-clear-sequence.md`, Beat 4) — a death is not the end of
	#  the content, and telling a player who just died that the build stops here says the wrong thing.
	if _cleared:
		_draw_notice(font, Fx.SETTLEMENT_NOTICE_1, Fx.SETTLEMENT_NOTICE_2, Layout.notice_rect(size))

	var btn := Layout.button_rect(size)
	draw_rect(btn, Fx.SETTLEMENT_BUTTON_BG, true)
	draw_rect(btn, Fx.SETTLEMENT_BUTTON_EDGE, false, Fx.SETTLEMENT_EDGE_PX)
	var btn_w := font.get_string_size(Fx.SETTLEMENT_BUTTON_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE).x
	draw_string(font, btn.position + Vector2((btn.size.x - btn_w) * 0.5, btn.size.y * 0.5 + float(Fx.SETTLEMENT_ROW_SIZE) * 0.35),
		Fx.SETTLEMENT_BUTTON_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE, Fx.SETTLEMENT_BUTTON_TEXT_COLOR)


## **Split out of `_draw()` so a net can verify which title string actually reaches the screen** (verify-read,
## H3 — a check that only follows `_cleared` itself, the stored bool, never asks whether that bool actually
## reaches `draw_string`; deleting the title ternary and hardcoding `Fx.SETTLEMENT_TITLE` left every such
## check green). GDScript refuses to let a script override a *native* `CanvasItem` method like `draw_string`
## (a hard parse error here, measured directly), so this ordinary script method is the seam instead — a test
## subclass overrides `_draw_title` and catches exactly the string `_draw()` decided to paint.
func _draw_title(font: Font, title: String, pos: Vector2) -> void:
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_TITLE_SIZE, Fx.SETTLEMENT_TITLE_COLOR)


## **The one thing on this panel that is not about the run** — two lines saying the build ends at stage 1
## (`stage-clear-sequence.md`, Beat 4). Two lines rather than one because `draw_string`
## does not wrap and a wrapped sentence is a layout problem for text that gets deleted the day stage 2 exists.
##
## **A hook for the same reason `_draw_title` is one**: GDScript refuses to override the native `draw_string`
## (a hard parse error, measured directly in `net_settlement.gd`), so without this seam a net can only ask
## whether `_draw()` ran — never whether either Korean line reached the paint, nor that a death draws neither.
func _draw_notice(font: Font, line1: String, line2: String, r: Rect2) -> void:
	var line_h := float(Fx.SETTLEMENT_NOTICE_SIZE) * 1.6
	var y := r.position.y + float(Fx.SETTLEMENT_NOTICE_SIZE)
	draw_string(font, Vector2(r.position.x, y), line1,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_NOTICE_SIZE, Fx.SETTLEMENT_NOTICE_COLOR)
	draw_string(font, Vector2(r.position.x, y + line_h), line2,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_NOTICE_SIZE, Fx.SETTLEMENT_NOTICE_COLOR)


## Label on the left, value right-aligned to the row's own width — the mockup's own "label ... value" reading.
func _draw_row(rect: Rect2, font: Font, label: String, value: String) -> void:
	var y := rect.position.y + rect.size.y * 0.5 + float(Fx.SETTLEMENT_ROW_SIZE) * 0.35
	draw_string(font, Vector2(rect.position.x, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE, Fx.SETTLEMENT_ROW_LABEL_COLOR)
	var value_w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE).x
	draw_string(font, Vector2(rect.end.x - value_w, y), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE, Fx.SETTLEMENT_ROW_VALUE_COLOR)


## **The one row that moves.** Same label/value reading as `_draw_row`, plus the 원석 icon beside the value —
## the mockup's own "▸ 7", here the actual icon rather than a placeholder glyph.
func _draw_gems_row(rect: Rect2, font: Font) -> void:
	var y := rect.position.y + rect.size.y * 0.5 + float(Fx.SETTLEMENT_ROW_SIZE) * 0.35
	draw_string(font, Vector2(rect.position.x, y), Fx.SETTLEMENT_GEMS_LABEL,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE, Fx.SETTLEMENT_ROW_LABEL_COLOR)

	var value := "%d" % shown_gems()
	var value_w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE).x
	draw_string(font, Vector2(rect.end.x - value_w, y), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.SETTLEMENT_ROW_SIZE, Fx.SETTLEMENT_ROW_VALUE_COLOR)

	if _gem_icon != null:
		var icon_r := Rect2(rect.end.x - value_w - Fx.SETTLEMENT_ICON_PX - 8.0,
			rect.position.y + (rect.size.y - Fx.SETTLEMENT_ICON_PX) * 0.5,
			Fx.SETTLEMENT_ICON_PX, Fx.SETTLEMENT_ICON_PX)
		draw_texture_rect(_gem_icon, icon_r, false, Fx.SETTLEMENT_ICON_COLOR)
