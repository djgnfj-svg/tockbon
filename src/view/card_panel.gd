class_name CardPanel
extends Control
## The level-up pick: three cards, click one or press 1/2/3.
##
## ⚠ **The failure this file is most likely to ship is invisibility.** `CLAUDE.md` records a panel that
## **never set `visible`** shipping under 5,576 green checks. So: `show_offer()` is the only way it opens,
## it sets `visible` itself, and a net asserts `visible` on both edges — offered and taken.
##
## Everything is `_draw()`n rather than built from Buttons and StyleBoxes, because the whole panel is
## three rectangles and the theme work would outweigh it.

signal picked(card: int)

const CARD_SIZE := Vector2(260.0, 300.0)
const CARD_GAP := 28.0
const DIM := Color(0.04, 0.03, 0.03, 0.72)
const CARD_BG := Color(0.16, 0.14, 0.13)
const CARD_EDGE := Color(0.95, 0.85, 0.45)
const CARD_HOVER := Color(0.24, 0.22, 0.18)
const TITLE_COLOR := Color(0.98, 0.93, 0.72)
const DESC_COLOR := Color(0.78, 0.74, 0.68)
const KEY_COLOR := Color(0.62, 0.58, 0.52)

var offer := PackedInt32Array()
var _hover := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	c.draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var font := get_theme_default_font()
	var head := "레벨 업"
	c.draw_string(font, Vector2(size.x * 0.5 - 60.0, _top() - 46.0), head,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, TITLE_COLOR)
	for k in offer.size():
		_paint_card(c, k, _rect_of(k), offer[k], k == _hover)


func _paint_card(c: CanvasItem, slot: int, r: Rect2, card: int, hot: bool) -> void:
	c.draw_rect(r, CARD_HOVER if hot else CARD_BG)
	c.draw_rect(r, CARD_EDGE, false, 3.0 if hot else 1.0)
	var font := get_theme_default_font()
	c.draw_string(font, r.position + Vector2(22.0, 74.0), str(Cards.TITLE[card]),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 30, TITLE_COLOR)
	c.draw_multiline_string(font, r.position + Vector2(22.0, 126.0), str(Cards.DESC[card]),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44.0, 20, 3, DESC_COLOR)
	c.draw_string(font, r.position + Vector2(22.0, r.size.y - 24.0), "[%d]" % (slot + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, KEY_COLOR)


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
