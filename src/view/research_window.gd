extends Control
## The research bench's window — **the compendium half of it, which is the half that exists.**
##
## `docs/design/town.md` gives this bench two jobs: spend materials on permanent unlocks, and **show unlocked
##  and locked in one list** ("the best possible demonstration that the pool widened"). The second job is
##  built here. **The first is not, and the window says so** — there is no price table and no material cost
##  anywhere in the design yet (that doc's own TBD), so there is no buy button to press. A button that took a
##  material and gave nothing back is this repo's signature fake; an honest empty shelf is not.
##
## **It reads `Progress` and writes nothing.** Same discipline as `circle_window` holding a live reference:
##  the material count and the rune pool are read every `_draw()`, so nothing has to be pushed in when they
##  change.
##
## The window is under `HUD` (a `CanvasLayer`) — the same reason `circle_window.gd` gives for its own
##  placement: as a `Node2D` it would ride the screen shake.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/research_layout.gd")
const Progress := preload("res://src/actor/progress.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

var _progress: Progress = null

## **Loaded once.** The same reason `town_view._sprites` and `monster_view._anim_sheets` are: `load()` is
##  engine-cached, but relying on that cache is relying on something no net can see.
var _panel: Texture2D = load(Fx.RESEARCH_PANEL)
var _slots: Texture2D = load(Fx.RESEARCH_SLOT_SHEET)
var _icons: Dictionary = load_icons()


## static, so a net can confirm every path resolves before any node exists — the same door
##  `MonsterView._load_sheets` and `TownView.load_sprites` open.
static func load_icons() -> Dictionary:
	var out: Dictionary = {}
	for key: String in Fx.RESEARCH_ICONS:
		out[key] = load(Fx.RESEARCH_ICONS[key]) as Texture2D
	return out


## **The seat comes from `fx_tuning`, not the scene file.** The same discipline `three_pick_window._ready`
##  holds — pinned in the scene as well, the two drift and only the screen shows it.
func _ready() -> void:
	position = Fx.RESEARCH_RECT.position
	size = Fx.RESEARCH_RECT.size


func setup(progress: Progress) -> void:
	_progress = progress
	queue_redraw()


## **Opening and closing is this node's own state, read by the shell** — the same shape as
##  `circle_window.toggle()`, and for the same reason: a second latch in `stage.gd` would let "I closed it
##  but it is still on screen" exist.
func toggle() -> void:
	visible = not visible
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var area := Rect2(Vector2.ZERO, size)
	_draw_panel(area)
	if font == null or _progress == null:
		# **No font means no text, and it does not bark** — passing `null` to `draw_string` barks every frame,
		#  and the wrapper counts stderr as failure, so an ordinary screen would turn the nets red
		#  (`monster_view._draw_dmg_number`'s own note). The panel still draws, so the window is not invisible.
		return
	var inner := Layout.inner(size)
	draw_string(font, Vector2(inner.position.x, inner.position.y + Fx.RESEARCH_TITLE_SIZE),
		Fx.RESEARCH_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_TITLE_SIZE, Fx.RESEARCH_INK)
	_draw_material(font)
	_draw_rows(font)
	var foot := Layout.footer_line(size)
	# **Sat at the band's bottom, not its top.** Drawn at the top the footer's cap-height touched the last
	#  row's own state line — legible, but the two read as one paragraph. The band's height is the clearance;
	#  using it is the point of having one.
	draw_string(font, Vector2(foot.position.x, foot.end.y - Layout.BASELINE_DROP_PX),
		Fx.RESEARCH_FOOTER, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_DIM_SIZE, Fx.RESEARCH_INK_DIM)


## The stone frame, in nine pieces. **The corners never scale** — `research_layout.nine`'s own comment.
func _draw_panel(area: Rect2) -> void:
	if _panel == null:
		# Substitute, do not bark — the same layered-fallback discipline the monster and fixture art hold.
		draw_rect(area, Color(0.93, 0.88, 0.74, 1.0))
		return
	var tex_size := Vector2(_panel.get_width(), _panel.get_height())
	for pair: Array in Layout.nine(area, tex_size, Fx.RESEARCH_PANEL_BORDER_PX):
		draw_texture_rect_region(_panel, pair[1], pair[0])


## **The material count, and the one sentence about what it is for.** It sits above the four rows because it
##  is the number every one of them will eventually cost — the doc's own ordering ("points and items are a
##  pair… you need both for a build to widen") starts from what you have.
func _draw_material(font: Font) -> void:
	var line := Layout.material_line(size)
	var y := line.position.y + line.size.y * 0.5
	var icon_r := Rect2(line.position.x, y - Fx.RESEARCH_ICON_PX * 0.5,
		Fx.RESEARCH_ICON_PX, Fx.RESEARCH_ICON_PX)
	_draw_icon("material", icon_r)
	# **원석, the name the design settled on** (`docs/decisions/gems-from-bosses-and-levels.md`). The icon's
	#  file is still `icon_material.png` — renaming an asset the user picked is a bigger edit than it looks,
	#  and the key is internal while the word is what the player reads.
	draw_string(font, Vector2(icon_r.end.x + 8.0, y + Fx.RESEARCH_TEXT_SIZE * 0.36),
		Fx.RESEARCH_GEMS_FMT % _progress.gems, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.RESEARCH_TEXT_SIZE, Fx.RESEARCH_INK)


## The four unlock axes. **Every one of them is locked and drawn as locked**, because not one unlock exists —
##  and that is the list the design asks for, not a defect in it.
##
## **The rune pool rides in the "item" row's own line**, rather than getting a fifth row: `town.md` is explicit
##  that "item unlock" and the GDD's "pool" are the same thing ("keep them as one. Split them and the list
##  becomes two, and the player doesn't know which one they bought"). Two rows would be exactly that split.
func _draw_rows(font: Font) -> void:
	var rects := Layout.rows(size)
	for i in mini(rects.size(), Fx.RESEARCH_ROWS.size()):
		var row: Rect2 = rects[i]
		var entry: Array = Fx.RESEARCH_ROWS[i]
		var frame := Layout.slot(row)
		_draw_slot(frame, false)
		var icon_side := minf(Fx.RESEARCH_ICON_PX, frame.size.y * 0.5)
		_draw_icon(entry[0], Rect2(frame.get_center() - Vector2(icon_side, icon_side) * 0.5,
			Vector2(icon_side, icon_side)))
		var tx := Layout.text_x(row)
		# **Both baselines come from the layout, not from the row's centre** — that function's own box
		#  records the overlap this fixed.
		var base := Layout.text_baselines(row)
		draw_string(font, Vector2(tx, base[0]), "%s — %s" % [entry[1], entry[2]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_TEXT_SIZE, Fx.RESEARCH_INK)
		draw_string(font, Vector2(tx, base[1]), _row_state(entry[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_DIM_SIZE, Fx.RESEARCH_INK_DIM)


## What a row says underneath its name. **Pure static, so a net drives the list itself** — the same seat as
##  `Stage.research_text`, and the reason is the same: *which entries read as locked* is a value, and a bench
##  that showed everything open would make the pool look already-widened on run one.
##
## **Only the item row reads live state.** The other three have no unlock and no counterpart in `Progress`,
##  so they say the one true thing about themselves. **`dice_left` is deliberately not read** even though the
##  field exists — it is inert by its own declaration ("a real field, moved by nothing today"), and printing
##  a 0 from it would dress an inert field as a live one.
static func row_state(key: String, progress: Progress) -> String:
	if key != "item" or progress == null:
		return Fx.RESEARCH_LOCKED_TEXT
	var parts: Array[String] = []
	for rune: int in Tuning.ELEM_ALL:
		var nm := str(Fx.ELEM_NAMES.get(rune, "?"))
		parts.append(nm if progress.owns_rune(rune) else "%s(%s)" % [nm, Fx.RESEARCH_LOCKED_TEXT])
	return "룬 " + " · ".join(parts)


func _row_state(key: String) -> String:
	return row_state(key, _progress)


## One slot frame. **`locked` picks the left third of the sheet (chain and padlock) and `false` the middle
##  third (empty)** — `Fx.RESEARCH_SLOT_LOCKED_SRC`'s own comment has why one png carries both.
##
## **The four rows pass `false` today, on purpose.** The padlock overlay is what a *bought* unlock's absence
##  should look like, and with no prices at all the whole list is "not yet built" rather than "locked behind
##  a cost" — the empty frame says the first, the padlock would claim the second.
func _draw_slot(r: Rect2, locked: bool) -> void:
	if _slots == null:
		draw_rect(r, Color(0.86, 0.78, 0.60, 1.0), false, 2.0)
		return
	draw_texture_rect_region(_slots, r,
		Fx.RESEARCH_SLOT_LOCKED_SRC if locked else Fx.RESEARCH_SLOT_OPEN_SRC)


## **Tinted, not a second png.** Every icon in `assets/ui/` is a white silhouette, so one colour constant
##  drives all of them and a palette change is one edit rather than five regenerations.
func _draw_icon(key: String, r: Rect2) -> void:
	var tex: Texture2D = _icons.get(key)
	if tex == null:
		return
	draw_texture_rect(tex, r, false, Fx.RESEARCH_ICON_COLOR)
