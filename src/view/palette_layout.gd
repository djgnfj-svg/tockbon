extends RefCounted
## Palette coordinates — **it is "slot kind x item". It is not "a glyph palette".**
##
## ```
##  ┌ circle ──────────┐   <- one section = one slot kind
##  │  ○               │      items come from iterating the table
##  ├ rune ────────────┤
##  │  ●               │
##  ├ glyph ───────────┤
##  │  ✳      ●        │
##  └──────────────────┘
## ```
##
## **Write it for glyphs only and attaching circles and runes means rewriting it wholesale** — that is the most
##  expensive mistake at this stage, so the plan pinned it in red. Stage 5 must be **adding two cells.**
##
## **Items are not written by hand.** All three iterate an explicit list, so adding a row to a table grows the
##  palette **on its own** — that is visible evidence that "one new circle = one table row" is true.
##  Write them by hand and the table can grow with the palette not growing and **nobody barks.**
##
## **Drawing and clicking both pass through the same functions in this file** (stage 4b-2b's hit test).
##  Coordinates in two places gives "I clicked this and that got picked", and **no error is raised.**
##
## The palette **does not know which page it sits on** — the same discipline as `circle_layout`.
##  The window moves the coordinate system and this side takes **size only.**

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

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

## Iteration goes **only through this explicit list.**
const KINDS: Array[int] = [KIND_CIRCLE, KIND_RUNE, KIND_GLYPH]


## What exists in that kind. **All of them return the table as-is** — build a list here and the day comes when
## the table grew and the palette did not, and that divergence is quiet.
## There is no notion of "owning" — **everything that exists** shows up (earning things in a dungeon is outside
## this stage's scope).
static func items_of(kind: int) -> Array[int]:
	if kind == KIND_CIRCLE:
		return CircleDefs.ALL
	if kind == KIND_RUNE:
		return Tuning.ELEM_ALL
	if kind == KIND_GLYPH:
		return Glyph.ALL
	# It barks on an unknown kind — grow the table's kinds without growing this and that cell **quietly empties.**
	push_error("PaletteLayout: unknown slot kind %d - it has no items" % kind)
	return []


## The section one kind occupies. **Divided by the kind count** — grow the kinds and it narrows automatically.
##  Pin it as a constant and the day circle and rune cells are attached, sections overlap or run past the page.
static func section(page_size: Vector2, kind_index: int) -> Rect2:
	var n := KINDS.size()
	if n <= 0 or kind_index < 0 or kind_index >= n:
		return Rect2()
	var pad := Fx.PALETTE_PAD_PX
	var gap := Fx.PALETTE_SECTION_GAP_PX
	var w := maxf(page_size.x - pad * 2.0, 0.0)
	var h := maxf((page_size.y - pad * 2.0 - gap * float(n - 1)) / float(n), 0.0)
	return Rect2(pad, pad + float(kind_index) * (h + gap), w, h)


## The cell one item occupies inside a section. **Divided by the item count.**
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


## **What was clicked.** `{"kind": int, "item": int}` — **an empty dictionary** if nothing.
##
## **It walks the same `section()` and `item_slot()` as the drawing.** Find the coordinates again here and
##  it becomes "I clicked this and that got picked", and **no error is raised** (risk 6's palette face).
## The argument `p` is **relative to the page origin** — the caller must **subtract** however much the window
##  moved with `draw_set_transform` (risk 22).
##
## **The whole cell is the clickable seat** (not the symbol circle). Make it symbol-sized and a small item
##  cannot be clicked, and that becomes "I clicked and nothing happened".
static func item_at(page_size: Vector2, p: Vector2) -> Dictionary:
	for ki in KINDS.size():
		var sec := section(page_size, ki)
		var kind: int = KINDS[ki]
		var items := items_of(kind)
		for ii in items.size():
			if item_slot(sec, ii, items.size()).has_point(p):
				return {"kind": kind, "item": items[ii]}
	return {}
