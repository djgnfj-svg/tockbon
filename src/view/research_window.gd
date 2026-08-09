extends Control
## The research bench's window — **the compendium half of it, which is the half that exists.**
##
## `docs/design/town.md` gives this bench two jobs: spend 원석 on permanent unlocks, and **show unlocked and
##  locked in one list** ("the best possible demonstration that the pool widened"). **Both are built now**
##  (`research-bench-unlocks.md`) — this file's header used to say the first job did not
##  exist and that an honest empty shelf beat a button that took a material and gave nothing back. A price
##  exists, so the shelf is stocked.
##
## **The chips are on the state line, not below it.** The window has no vertical room for a third text line —
##  each row is exactly 35px and already carries two baselines (`research_layout.chip_band`'s own measurement).
##  So the line the player already reads is the thing they now press.
##
## **It reads `Progress` and writes nothing — except through `Progress.buy()`, its one door.** Same discipline
##  as `circle_window` holding a live reference: the 원석 count and the rune pool are read every `_draw()`, so
##  nothing has to be pushed in when they change, and a purchase shows up on the next redraw by itself rather
##  than being pushed anywhere.
##
## The window is under `HUD` (a `CanvasLayer`) — the same reason `circle_window.gd` gives for its own
##  placement: as a `Node2D` it would ride the screen shake.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/research_layout.gd")
const Progress := preload("res://src/actor/progress.gd")
## **`sim_tuning` is no longer preloaded here.** The item row used to walk `Tuning.ELEM_ALL` itself; it now
##  walks `UnlockDefs.ids_for_axis()`, which is the same list with the not-for-sale row marked — and
##  `net_research` asserts those two are identical, so the pool is still the pool.
const UnlockDefs := preload("res://src/actor/unlock_defs.gd")

## **The four chip states. They live here, not in `fx_tuning`, because they are states and not presentation
##  values** — this is the file that both decides one (`chip_state()`) and draws it (`_paint_unlock_chip()`),
##  and a state constant sitting in the tuning file would read as a knob somebody is meant to turn.
##
## **Only `CHIP_BUYABLE` gets a box.** The box is the whole affordance: exactly one state is meant to be
##  pressed, so exactly one state is marked. `CHIP_FIXED` (무 — never for sale) and `CHIP_UNLOCKED` (already
##  bought) look identical on purpose — from the player's side "it is mine" is one fact, not two.
##
## **A `CHIP_SHORT` chip pressed does nothing and says nothing, and that is the repo's own answer**: the
##  palette refuses to even pick a veiled rune, and `circle_window.gd:175-177` says why a message is the wrong
##  fix — "get it picked and then have the slot refuse it and it becomes *I pressed it and nothing happened*".
##  The dim ink, the printed price, and the 원석 count directly above are the affordance.
const CHIP_FIXED := 0
const CHIP_UNLOCKED := 1
const CHIP_BUYABLE := 2
const CHIP_SHORT := 3

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
	# **The price comes from `Progress`, not from the string** — one number, one home, so retuning it moves
	#  what the player is charged and what the player reads in the same edit.
	draw_string(font, Vector2(foot.position.x, foot.end.y - Layout.BASELINE_DROP_PX),
		Fx.RESEARCH_FOOTER_FMT % Progress.GEMS_PER_UNLOCK,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_DIM_SIZE, Fx.RESEARCH_INK_DIM)


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
		var key := String(entry[0])
		var ids := UnlockDefs.ids_for_axis(key)
		var frame := Layout.slot(row)
		# **The chained-shut slot art finally means something.** It has always cut the padlock third out of
		#  `slot_row.png` and every row has always passed `false`, with a comment saying an empty frame means
		#  "not yet built" while a padlock would claim "locked behind a cost". **A cost now exists**, so the
		#  two rows that have one wear the padlock while anything on them is still unbought — and 점수 and
		#  주사위 keep `false`, because nothing is buyable there and "not yet built" is still the true thing
		#  about them.
		_draw_slot(frame, _row_locked(key))
		var icon_side := minf(Fx.RESEARCH_ICON_PX, frame.size.y * 0.5)
		_draw_icon(entry[0], Rect2(frame.get_center() - Vector2(icon_side, icon_side) * 0.5,
			Vector2(icon_side, icon_side)))
		var tx := Layout.text_x(row)
		# **Both baselines come from the layout, not from the row's centre** — that function's own box
		#  records the overlap this fixed.
		var base := Layout.text_baselines(row)
		draw_string(font, Vector2(tx, base[0]), "%s — %s" % [entry[1], entry[2]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_TEXT_SIZE, Fx.RESEARCH_INK)
		if ids.is_empty():
			# **A row with no unlock keeps its state line.** 점수 and 주사위 have nothing to press, and a row
			#  that went blank would read as broken rather than as honest.
			draw_string(font, Vector2(tx, base[1]), _row_state(key),
				HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_DIM_SIZE, Fx.RESEARCH_INK_DIM)
			continue
		var chips := Layout.unlock_chip_rects(row, ids.size())
		for c in mini(chips.size(), ids.size()):
			_paint_unlock_chip(font, ids[c], chips[c], chip_state(ids[c], _progress))


## Does this row still have something unbought on it. **Asks `Progress.is_unlocked()`, not `owns_rune()`** —
##  the bull grants 불 mid-run, and a padlock that came off because a boss handed you a rune would be claiming
##  a purchase that never happened (and would come back on at the next `reset()`).
## **A row with no unlocks at all is never locked** — see `_draw_rows`.
func _row_locked(key: String) -> bool:
	if _progress == null:
		return false
	for id: int in UnlockDefs.ids_for_axis(key):
		if _progress.can_buy(id):
			return true
	return false


## What a row says underneath its name. **Pure static, so a net drives the list itself** — the same seat as
##  `Stage.research_text`, and the reason is the same: *which entries read as locked* is a value, and a bench
##  that showed everything open would make the pool look already-widened on run one.
##
## **Only the item row reads live state.** The other three have no unlock and no counterpart in `Progress`,
##  so they say the one true thing about themselves. **`dice_left` is deliberately not read** even though the
##  field exists — it is inert by its own declaration ("a real field, moved by nothing today"), and printing
##  a 0 from it would dress an inert field as a live one.
## **It joins `chip_text()`, it does not spell the list a second time.** The chips *are* the item row on
##  screen now, so a `row_state` that built its own wording would be a second copy of the same sentence —
##  and `net_town._the_item_row_is_the_rune_pool` would then be measuring a string nothing draws. One
##  function, two readers.
static func row_state(key: String, progress: Progress) -> String:
	if key != UnlockDefs.AXIS_ITEM or progress == null:
		return Fx.RESEARCH_LOCKED_TEXT
	var parts: Array[String] = []
	for id: int in UnlockDefs.ids_for_axis(UnlockDefs.AXIS_ITEM):
		parts.append(chip_text(id, progress))
	return "룬 " + " · ".join(parts)


func _row_state(key: String) -> String:
	return row_state(key, _progress)


## **Which of the four states a chip is in. Pure static, so a net drives the table directly** — the same seat
##  `row_state()` above and `Stage.research_text()` sit in.
##
## **`gems` is asked last, and only for something actually for sale.** The order is the point: not-for-sale
##  beats bought beats affordable, so 무 can never read as "you cannot afford it" no matter what the counter
##  says, and a bought unlock can never read as buyable again.
## **A null `Progress` falls to `CHIP_SHORT` rather than crashing** — the same guard `row_state()` holds, and
##  the same answer: with nothing known, nothing is presented as pressable.
static func chip_state(unlock_id: int, progress: Progress) -> int:
	if not UnlockDefs.is_for_sale(unlock_id):
		return CHIP_FIXED
	if progress == null:
		return CHIP_SHORT
	if progress.is_unlocked(unlock_id):
		return CHIP_UNLOCKED
	if progress.gems >= Progress.GEMS_PER_UNLOCK:
		return CHIP_BUYABLE
	return CHIP_SHORT


## What a chip says. **The 잠김 marker keys on ownership and the price keys on `can_buy()`, and they are two
##  different questions** (`research-bench-unlocks.md`):
##
##  · 불 granted by the bull mid-run is **owned** — printing 잠김 beside it would contradict the palette,
##    which unveils it the moment it is granted
##  · …and still **buyable**, because a grant dies at `reset()` and a purchase does not. So the price stays
##    on, and what 10 원석 buys there is permanence rather than first access
##
## **The rune name comes from `Fx.ELEM_NAMES` and only a non-rune unlock's name comes from `UnlockDefs`** —
##  each name has exactly one home (`unlock_defs.DEFS`'s own box).
static func chip_text(unlock_id: int, progress: Progress) -> String:
	var rune := UnlockDefs.rune_of(unlock_id)
	var out := str(Fx.ELEM_NAMES.get(rune, "?")) if rune >= 0 else UnlockDefs.name_of(unlock_id)
	var owned := false
	if progress != null:
		owned = progress.owns_rune(rune) if rune >= 0 else progress.is_unlocked(unlock_id)
	if not owned:
		out += " " + Fx.RESEARCH_LOCKED_TEXT
	if progress != null and progress.can_buy(unlock_id):
		out += " %d" % Progress.GEMS_PER_UNLOCK
	return out


## **One chip. Cut out of `_draw_rows()` as its own method so a net can override it and read the arguments**
##  — CLAUDE.md's own rule: "`_draw()` ran" is not "anything was drawn", and Godot refuses to let a script
##  override a native draw call (`draw_string`/`draw_rect` are hard parse errors), so the seam has to be an
##  ordinary method like this one. `net_gate._CapturingGateView` is the pattern.
##
## **Only `CHIP_BUYABLE` draws a box** — the box is the affordance and nothing else may wear it.
func _paint_unlock_chip(font: Font, unlock_id: int, r: Rect2, state: int) -> void:
	if state == CHIP_BUYABLE:
		draw_rect(r, Fx.RESEARCH_INK, false, Layout.CHIP_BOX_PX)
	var ink := Fx.RESEARCH_INK_DIM if state == CHIP_SHORT else Fx.RESEARCH_INK
	draw_string(font,
		Vector2(r.position.x + Layout.CHIP_TEXT_INSET_PX, r.end.y - Layout.BASELINE_DROP_PX),
		chip_text(unlock_id, _progress), HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.RESEARCH_DIM_SIZE, ink)


## **A left click on a chip buys it — and `Progress.buy()` decides whether anything happens, not this file.**
##  Every refusal (not for sale, already bought, not enough 원석) lives in that one guard, so the window never
##  holds a second copy of the rule and can never disagree with the chip state it just drew.
##
## **The click is accepted whether or not it bought anything**, the same as `three_pick_window._gui_input`:
##  a click inside a window is not firing, and letting it fall through would launch magic while the player is
##  shopping. **A dim chip pressed still does nothing and still says nothing** — the `CHIP_SHORT` box above
##  has why a message would be the wrong fix.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	accept_event()
	if _progress == null:
		return
	var rects := Layout.rows(size)
	for i in mini(rects.size(), Fx.RESEARCH_ROWS.size()):
		var ids := UnlockDefs.ids_for_axis(String(Fx.RESEARCH_ROWS[i][0]))
		if ids.is_empty():
			continue
		var idx := Layout.unlock_chip_at(rects[i], ids.size(), mb.position)
		if idx < 0:
			continue
		# **`queue_redraw()` runs whether or not the buy took**, because the row under the cursor is the one
		#  the player just looked at — and a redraw on a refused click costs one frame and removes a whole
		#  class of "the screen did not update" report.
		_progress.buy(ids[idx])
		queue_redraw()
		return


## One slot frame. **`locked` picks the left third of the sheet (chain and padlock) and `false` the middle
##  third (empty)** — `Fx.RESEARCH_SLOT_LOCKED_SRC`'s own comment has why one png carries both.
##
## **Two rows pass `true` now and two still pass `false`, and the split is the whole meaning of the art.**
##  The padlock says "locked behind a cost"; the empty frame says "not yet built". 아이템 and 신체 have a cost,
##  so they wear the padlock until everything on them is bought (`_row_locked`). 점수 and 주사위 have no cost
##  and no unlock, so the empty frame is still the true thing about them — giving them a padlock would claim a
##  price that does not exist.
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
