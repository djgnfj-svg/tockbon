extends RefCounted
## Palette coordinates — **it is "slot kind x item". It is not "a glyph palette".**
##
## ```
##  ┌ tabs: 진 · 룬 · 문양 ┐   <- one tab per slot kind, exactly one open
##  ├──────────────────────┤
##  │  open tab's cells    │      items come from iterating the table, filtered by ownership
##  ├──────────────────────┤
##  │   마법진 완성          │   <- always present, in every tab
##  └──────────────────────┘
## ```
##
## **Write it for glyphs only and attaching circles and runes means rewriting it wholesale** — that is the most
##  expensive mistake at this stage, so the plan pinned it in red. Growing a fourth kind must be **adding one
##  tab**, not rebuilding the page.
##
## **Items are not written by hand.** All three iterate an explicit list, so adding a row to a table grows the
##  palette **on its own** — that is visible evidence that "one new circle = one table row" is true.
##  Write them by hand and the table can grow with the palette not growing and **nobody barks.**
##
## **What you do not have has no cell** (`onboarding-and-palette-tabs.md`, reversing
##  `rune-lock-and-receiving.md`'s "veiled, not hidden") — `items_of()` filters by ownership, so an unowned
##  item is not merely dimmed, it is **absent** from the list `section()`/`item_slot()`/`item_at()` all walk.
##  This is a different question from "can it be placed right now" (`circle_window._can_pick`) and the two
##  must not share a function — fold them and placing spread makes spread **vanish** from the palette the
##  instant it is placed (`max_per_circle: 1` failing against its own family).
##
## **Drawing and clicking both pass through the same functions in this file.**
##  Coordinates in two places gives "I clicked this and that got picked", and **no error is raised.**
##  `item_at()` walks only the open tab's kind — a closed tab's former coordinates return `{}`, not merely
##  go undrawn.
##
## The palette **does not know which page it sits on** — the same discipline as `circle_layout`.
##  The window moves the coordinate system and this side takes **size only.**
## **`Fx.PALETTE_*` only** — never `Fx.WINDOW_*`, never `book_layout` (`net_circle` bars both by text scan).

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
## Live ownership and assembly state, **read only** — this file never writes either. No cycle: neither
##  file reaches into `src/view/`, the same allowance `fx_tuning.gd` already uses for `MonsterDefs`.
const Progress := preload("res://src/actor/progress.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

## Slot kinds. **These three are the palette's axis.**
const KIND_CIRCLE := 0
const KIND_RUNE := 1
const KIND_GLYPH := 2

## **One new slot kind = two files.**
##
## ```
## palette_layout.gd   const KIND_X · KIND_DEFS · KINDS · the items_of branch   (table and coordinates)
## circle_window.gd    the _draw_palette_item branch                           (drawing)
## ```
##
## **It once said "this went past four" and the unit of the count was wrong** — this repo's "four places means
##  the design is wrong" is a **file-count contract**, but lines and branches were counted against it instead.
##  Two files is not a violation.
##
## **One thing worth keeping anyway: the drawing is in a different file, so it is the easiest to miss.** Grow only
##  the table and that kind **takes a seat in the palette while nothing gets drawn** — it looks like an empty cell
##  and raises no error.
##
## This count is **a different axis from adding a glyph.** Adding glyphs does not change the branches above —
##  glyphs all go into the single `KIND_GLYPH` branch, and inside it `glyph_defs`'s `kind` decides the shape.
## Why the names live here: **what belongs to one concept stays in one place** (CLAUDE.md).
##  Build the kind list and the name list separately and the two have to be matched by hand, and they will drift.
const KIND_DEFS: Dictionary = {
	KIND_CIRCLE: {"name": &"진"},
	KIND_RUNE: {"name": &"룬"},
	KIND_GLYPH: {"name": &"문양"},
}

## Iteration goes **only through this explicit list.** The tab strip reads it too — a fourth kind grows a
##  fourth tab with no second list to edit.
const KINDS: Array[int] = [KIND_CIRCLE, KIND_RUNE, KIND_GLYPH]


## What exists in that kind **and is owned by `pr`/seated in `circle`.** An item you do not have is not in
## this list at all — the cell does not exist (`onboarding-and-palette-tabs.md` §2).
##
## ```
## KIND_CIRCLE  CircleDefs.ALL filtered by pr.owns_circle()   <- 삼각 starts unowned (user confirmed)
## KIND_RUNE    Tuning.ELEM_ALL filtered by pr.owns_rune()    <- unchanged gate, moved here from _slot_accepts
## KIND_GLYPH   circle.glyph_list()                            <- the seated glyphs, in layer order.
##                                                                 No held-glyph stash exists or is read
##                                                                 (`docs/decisions/the-glyph-tab-shows-the-circle.md`)
## ```
##
## **This is a different question from "can it be placed right now" and the two must not be folded into one
## gate** — `circle_window._can_pick`/`_slot_accepts` still answer that, reading `pr`/`circle` themselves.
## Fold the two and placing a `max_per_circle: 1` glyph makes it vanish from its own tab the instant it is
## placed, which is exactly the failure the design doc's worked example names.
##
## **`pr`/`circle` are the live objects the window already holds** (`circle_window._progress`/`_circle`) —
## reading them here rather than copying is what lets a mid-run grant (the bull's fire rune) add a cell with
## no restart, the same reason `_owns_rune_gates_can_pick_on_an_untreed_window` drives a grant mid-test on
## one live window instance.
static func items_of(kind: int, pr: Progress, circle: SpellCircle) -> Array[int]:
	if kind == KIND_CIRCLE:
		var out: Array[int] = []
		for id: int in CircleDefs.ALL:
			if pr.owns_circle(id):
				out.append(id)
		return out
	if kind == KIND_RUNE:
		var out: Array[int] = []
		for id: int in Tuning.ELEM_ALL:
			if pr.owns_rune(id):
				out.append(id)
		return out
	if kind == KIND_GLYPH:
		return circle.glyph_list()
	# It barks on an unknown kind — grow the table's kinds without growing this and that cell **quietly empties.**
	push_error("PaletteLayout: unknown slot kind %d - it has no items" % kind)
	return []


## Tabs across the top of the page — one rect per `KINDS` entry, so a fourth kind grows a fourth tab with
## no second list to edit.
static func tabs(page_size: Vector2) -> Array[Rect2]:
	var n := KINDS.size()
	if n <= 0:
		return []
	var pad := Fx.PALETTE_PAD_PX
	var gap := Fx.PALETTE_TAB_GAP_PX
	var w := maxf((page_size.x - pad * 2.0 - gap * float(n - 1)) / float(n), 0.0)
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(pad + float(i) * (w + gap), pad, w, Fx.PALETTE_TAB_BAND_PX))
	return out


## Which tab was clicked. **-1 if none** — a click above or below the strip must not silently pick tab 0.
static func tab_at(page_size: Vector2, p: Vector2) -> int:
	var t := tabs(page_size)
	for i in t.size():
		if t[i].has_point(p):
			return i
	return -1


## The "마법진 완성" band — always present, in every tab (design §5: it confirms, it does not apply).
static func done_rect(page_size: Vector2) -> Rect2:
	var pad := Fx.PALETTE_PAD_PX
	var h := Fx.PALETTE_DONE_BAND_PX
	return Rect2(pad, page_size.y - pad - h, maxf(page_size.x - pad * 2.0, 0.0), h)


## The open tab's own body — between the tab strip and the 완성 band.
## **No kind index** — the rect does not depend on which tab is open, only its contents do. An argument
##  this function does not read would be a false knob (`net_circle` pins the old two-argument signature by
##  literal text; the new one-argument signature moves into that same pin).
static func section(page_size: Vector2) -> Rect2:
	var pad := Fx.PALETTE_PAD_PX
	var top := pad + Fx.PALETTE_TAB_BAND_PX + Fx.PALETTE_TAB_GAP_PX
	var bottom := page_size.y - pad - Fx.PALETTE_DONE_BAND_PX - Fx.PALETTE_TAB_GAP_PX
	var w := maxf(page_size.x - pad * 2.0, 0.0)
	var h := maxf(bottom - top, 0.0)
	return Rect2(pad, top, w, h)


## The cell one item occupies inside the open section. **Divided by the item count.**
## Only the part below the title band is used — items sitting on top of the title makes both unreadable.
static func item_slot(sec: Rect2, item_index: int, item_count: int) -> Rect2:
	if item_count <= 0 or item_index < 0 or item_index >= item_count:
		return Rect2()
	var head := Fx.PALETTE_HEAD_PX
	var top := sec.position.y + head
	var h := maxf(sec.size.y - head, 0.0)
	var w := sec.size.x / float(item_count)
	return Rect2(sec.position.x + float(item_index) * w, top, w, h)


## Radius of an item's symbol.
##
## **The cell's short side decides it.** That is why the symbol is the same size whether there is one item or four —
##  the section height is always the short side. Decide it by the long side and only the one-item kinds
##  (circle, rune) get enormous, which misreads as "is the circle the most important one".
static func item_symbol_radius(slot: Rect2) -> float:
	return minf(slot.size.x, slot.size.y) * 0.5 * Fx.PALETTE_SYMBOL_RATIO


## **What was clicked.** `{"kind": int, "item": int, "index": int}` — **an empty dictionary** if nothing.
## `index` is the cell's position within the open tab's own list (0-based) — `KIND_CIRCLE`/`KIND_RUNE`
## callers ignore it (a value alone identifies what to place), but Stage 8's glyph moves need it: two
## seated members of an unlimited family (dummy) can share the same `item` value and are told apart only
## by which cell was actually clicked.
##
## **Walks only `KINDS[open_tab]`** — a closed tab's former coordinates must return nothing, not merely go
##  undrawn (the palette's headline failure: coordinates in two places gives "I clicked this and that got
##  picked", and no error is raised). `pr`/`circle` are threaded to `items_of` so an unowned item's former
##  coordinates are gone from the hit test too, the same as from the drawing.
## The argument `p` is **relative to the page origin** — the caller must **subtract** however much the window
##  moved with `draw_set_transform` (risk 22).
##
## **The whole cell is the clickable seat** (not the symbol circle). Make it symbol-sized and a small item
##  cannot be clicked, and that becomes "I clicked and nothing happened".
static func item_at(page_size: Vector2, p: Vector2, open_tab: int, pr: Progress, circle: SpellCircle) -> Dictionary:
	if open_tab < 0 or open_tab >= KINDS.size():
		return {}
	var sec := section(page_size)
	var kind: int = KINDS[open_tab]
	var items := items_of(kind, pr, circle)
	for ii in items.size():
		if item_slot(sec, ii, items.size()).has_point(p):
			return {"kind": kind, "item": items[ii], "index": ii}
	return {}
