class_name CardPanel
extends Control
## The level-up pick: three cards, click one or press 1/2/3.
##
## **A card names a PART and nothing else.** Plan 2's six cards each carried a title and a paragraph out of
## `Cards.TITLE`/`Cards.DESC`; both tables are deleted with the cards, and the face is now `Parts.NAME[p]`
## — the id in `offer` IS a row in the parts table. A card for a part already worn is a level-up of it and
## says so: `말 다리 → Lv2`, the level it will BE, not the one it is.
##
## ⚠ **The failure this file is most likely to ship is invisibility.** `CLAUDE.md` records a panel that
## **never set `visible`** shipping under 5,576 green checks. So: `show_offer()` is the only way it opens,
## it sets `visible` itself, and a net asserts `visible` on both edges — offered and taken.
##
## Every actual draw call is a leaf (`_paint_rect` / `_paint_text`), the same discipline `ending_screen.gd`
## and `body_panel.gd` state. It was worth adopting on the rewrite rather than later: `draw_multiline_string`
## went out with `Cards.DESC`, so the file dropped from seven bare call sites and three primitives to two.
## ⚠ **It is NOT in `net_draw_leaf.SCOPED_FILES` yet** — that list lives in `tests/` and this stage may not
## edit it. Nothing stops the next bare `c.draw_` here until it joins.

signal picked(card: int)

const CARD_SIZE := Vector2(260.0, 300.0)
const CARD_GAP := 28.0
## **No colour of its own.** All six moved to `look.gd` as `Look.CARD_*` — the one-file rule, which
## `net_draw_leaf` now scans for. The pixel literals below and in `_paint()` have NOT moved.

## Part ids, not card ids. Three at most, and **legitimately fewer** — `Cards.roll()` draws from what has
## been eaten, so the pool can hold one or two. Every rectangle here is laid out from `offer.size()`.
var offer := PackedInt32Array()

## **The body, so a card can say what LEVEL it would be.** Read-only: the panel emits `picked` and the
## shell is what calls `World.take_card()`. Null between runs — `Run.to_title()` drops the world — so
## every read of it is guarded and an unwired panel prints the bare name rather than crashing.
var body: Body = null

var _hover := -1


func _ready() -> void:
	# **`set_anchors_preset` sets anchors and leaves the offsets alone**, so a Control added to a bare
	# CanvasLayer keeps `size == (0, 0)` and every layout below — all of which is computed from `size` —
	# collapses into the top-left corner. Reported by the user on the first play: the cards came up in the
	# wrong place. `_and_offsets_` is the one that actually resizes.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_offer(cards: PackedInt32Array) -> void:
	offer = cards
	_hover = -1
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	offer = PackedInt32Array()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible or offer.is_empty():
		return
	if event is InputEventMouseMotion:
		var was := _hover
		_hover = _card_at(event.position)
		if was != _hover:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := _card_at(event.position)
		if k >= 0:
			picked.emit(offer[k])


## Keys arrive here, not in `_gui_input`: a Control only sees key events through `_gui_input` when it
## holds focus, and this panel is opened by the game rather than clicked into.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or offer.is_empty():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var k := key.keycode - KEY_1
	if k >= 0 and k < offer.size():
		picked.emit(offer[k])
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if offer.is_empty():
		return
	_paint_rect(c, Rect2(Vector2.ZERO, size), Look.CARD_DIM, true, -1.0)
	_paint_text(c, Vector2(size.x * 0.5 - 60.0, _top() - 46.0), "레벨 업", 34, Look.CARD_TITLE_COLOR)
	for k in offer.size():
		_paint_card(c, k, _rect_of(k), offer[k], k == _hover)


## One card. Forwards to the two leaves and draws nothing itself.
func _paint_card(c: CanvasItem, slot: int, r: Rect2, part: int, hot: bool) -> void:
	_paint_rect(c, r, Look.CARD_HOVER if hot else Look.CARD_BG, true, -1.0)
	_paint_rect(c, r, Look.CARD_EDGE, false, 3.0 if hot else 1.0)
	_paint_text(c, r.position + Vector2(22.0, 74.0), face_of(part), 30, Look.CARD_TITLE_COLOR)
	_paint_text(c, r.position + Vector2(22.0, r.size.y - 24.0), "[%d]" % (slot + 1), 20, Look.CARD_KEY_COLOR)


## What the card reads. **Public because it is the one thing about this panel worth asserting by value** —
## a net capturing `_paint_text` has to know what string to look for, and re-deriving it in the net would
## measure the net's arithmetic.
##
## The suffix is the level this card would MAKE it, `part_level + 1`, not the level it is. `말 다리 → Lv2`
## on a Lv1 part is the promise the pick is making; printing the current level would read as "you already
## have this" on the one card that is worth taking twice.
func face_of(part: int) -> String:
	if part < 0 or part >= Parts.NAME.size():
		return ""
	var name_str := str(Parts.NAME[part])
	if body == null or not body.is_worn(part):
		return name_str
	return "%s → Lv%d" % [name_str, body.part_level(part) + 1]


## The only place `draw_rect` is called in this file.
func _paint_rect(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
	c.draw_rect(r, col, filled, width)


## The only place `draw_string` is called in this file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _rect_of(slot: int) -> Rect2:
	var total := CARD_SIZE.x * offer.size() + CARD_GAP * maxf(0.0, offer.size() - 1.0)
	var x := size.x * 0.5 - total * 0.5 + slot * (CARD_SIZE.x + CARD_GAP)
	return Rect2(Vector2(x, _top()), CARD_SIZE)


func _top() -> float:
	return size.y * 0.5 - CARD_SIZE.y * 0.5


func _card_at(p: Vector2) -> int:
	for k in offer.size():
		if _rect_of(k).has_point(p):
			return k
	return -1
