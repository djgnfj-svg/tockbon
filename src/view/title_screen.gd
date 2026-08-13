class_name TitleScreen
extends Control
## The title: four buttons, a background, nothing else.
##
## **The two disabled buttons are drawn on purpose.** The user asked for 도감/설정 to occupy their real
## place now rather than be added later — greyed reads as "coming", hidden reads as "does not exist".
##
## **Every actual draw call is a leaf.** `_paint_rect` and `_paint_text` are the only two places
## `draw_rect`/`draw_string` are called anywhere in this file — `_paint_button` calls them, it never draws
## directly. This is not the same claim as "every colour is decided in `_paint()`, one level up" (still
## true, and still why the colour-decision bugs are caught): a spy overriding `_paint_button` and capturing
## before calling `super()` sees that the hook was CALLED with the right arguments, but cannot see whether
## `super()` — the real base-class body — went on to actually draw anything. `if bg == BUTTON_BG_OFF:
## return` inside `_paint_button` would pass every check built only on that capture, because the capture
## already happened. Routing every real draw through `_paint_rect`/`_paint_text` closes that: nothing
## above those two hooks can produce a rectangle or a string on screen, so a spy watching THOSE two is
## watching the only path pixels can take.
##
## **This file never calls `get_tree().quit()`.** `src/view/` draws and reports; it does not decide the
## process ends — the shell connects `quit_pressed` and acts on it. `_gui_input` is not the folder-contract
## violation `card_panel.gd`'s `_unhandled_key_input` is: the engine hands this Control an event it already
## hit-tested, which is different from this file reading `Input` itself. Keys stay in the shell.

signal start_pressed
signal quit_pressed

const LABELS: Array[String] = ["시작하기", "도감", "설정", "종료"]
const ENABLED: Array[bool] = [true, false, false, true]


func _ready() -> void:
	# `_and_offsets_`, not just `_preset` — see card_panel.gd's note. Anchors alone leave a Control on a
	# bare CanvasLayer at size == (0, 0), and every rect below is computed from `size`.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _rect_of(0).has_point(event.position):
		start_pressed.emit()
	elif _rect_of(3).has_point(event.position):
		quit_pressed.emit()
	# Clicks on 1 (도감) and 2 (설정) do nothing — drawn, greyed, wired to nothing.


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	_paint_rect(c, Rect2(Vector2.ZERO, size), Look.TITLE_BG, true, -1.0)
	for k in LABELS.size():
		var enabled := ENABLED[k]
		_paint_button(c, _rect_of(k), LABELS[k],
				Look.BUTTON_BG if enabled else Look.BUTTON_BG_OFF,
				Look.SCREEN_TEXT if enabled else Look.BUTTON_TEXT_OFF)


## Forwards to the two leaf hooks below and does nothing else — see the file header for why this function
## must never call `draw_rect`/`draw_string` itself.
func _paint_button(c: CanvasItem, r: Rect2, label: String, bg: Color, text_col: Color) -> void:
	_paint_rect(c, r, bg, true, -1.0)
	_paint_rect(c, r, Look.BUTTON_EDGE, false, Look.BUTTON_EDGE_WIDTH)
	_paint_text(c, r.position + Look.BUTTON_LABEL_INSET, label, Look.FONT_BUTTON, text_col)


## The only place `draw_rect` is called in this file.
func _paint_rect(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
	c.draw_rect(r, col, filled, width)


## The only place `draw_string` is called in this file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## Pure — the same rect the paint call above passes, so a net can assert the two agree exactly. Four
## buttons stacked and centred.
func _rect_of(k: int) -> Rect2:
	var total := Look.BUTTON_SIZE.y * LABELS.size() + Look.BUTTON_GAP * (LABELS.size() - 1)
	var top := size.y * 0.5 - total * 0.5
	var x := size.x * 0.5 - Look.BUTTON_SIZE.x * 0.5
	var y := top + k * (Look.BUTTON_SIZE.y + Look.BUTTON_GAP)
	return Rect2(Vector2(x, y), Look.BUTTON_SIZE)
