class_name EndingScreen
extends Control
## One screen, two outcomes — same layout, different headline and colour (user, 2026-08-14).
##
## Reads a `RunResult` snapshot, never `World`: `Run.to_title()` drops the world, and this screen would
## then be holding a dead reference. **`세포` appears nowhere here** — the unit is 경험치
## (`hunting-and-the-boss`, newer than the old word and the GDD that used it).
##
## **Every actual draw call is a leaf** — `_paint_rect` and `_paint_text` are the only two places
## `draw_rect`/`draw_string` are called anywhere in this file. See `title_screen.gd`'s header for why:
## a spy overriding `_paint_button`/`_paint_slot` and capturing before calling `super()` sees that the
## hook was CALLED correctly, but cannot see whether the base class's body went on to actually draw
## anything — an early return or a deleted line inside either hook would pass every check built only on
## that capture. Nothing above `_paint_rect`/`_paint_text` may call `draw_rect`/`draw_string` directly.
##
## `R`/`Esc` are read in the shell, not here — `src/shell/` is the only place that reads `Input`. This
## file only emits `restart_pressed` / `title_pressed` for its two buttons; the shell maps both keys onto
## the same two calls.

signal restart_pressed
signal title_pressed

## **`Parts.Slot` and nowhere else.** This was the literal 11 with a comment pointing at the plan's slot
## table, and `body_panel.gd` read it back off this file — two view files drawing the same body from a
## number the table did not own. `Run._snapshot()` fills `result.body_slots` from the same enum, so the
## day a twelfth slot lands all three move together instead of two screens quietly drawing eleven squares.
## Deliberately not `result.body_slots.size()`: a snapshot that failed to fill it would then draw nothing
## at all rather than eleven empties.
func _slot_count() -> int:
	return Parts.Slot.size()

var result: RunResult = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _rect_of(0).has_point(event.position):
		restart_pressed.emit()
	elif _rect_of(1).has_point(event.position):
		title_pressed.emit()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if result == null:
		return
	_paint_rect(c, Rect2(Vector2.ZERO, size), Look.ENDING_DIM, true, -1.0)

	var cleared := result.outcome == Run.Outcome.CLEARED
	var x := size.x * 0.5 - Look.HEADLINE_X_OFFSET
	var y := Look.HEADLINE_Y
	_paint_text(c, Vector2(x, y), "보스를 삼켰다" if cleared else "먹혔다", Look.FONT_HEADLINE,
			Look.ENDING_CLEARED if cleared else Look.ENDING_DIED)

	var rows := _rows()
	for i in rows.size():
		_paint_text(c, Vector2(x, y + Look.ROW_START_Y + i * Look.ROW_GAP), rows[i], Look.FONT_ROW,
				Look.SCREEN_TEXT)

	for k in _slot_count():
		var filled := result.body_slots[k] if k < result.body_slots.size() else ""
		_paint_slot(c, _slot_rect_of(k), filled)

	# Always enabled — this screen has no greyed-out state, unlike the title's 도감/설정.
	_paint_button(c, _rect_of(0), "다시 하기", Look.BUTTON_BG, Look.SCREEN_TEXT)
	_paint_button(c, _rect_of(1), "타이틀로", Look.BUTTON_BG, Look.SCREEN_TEXT)


## The six rows below the headline — always drawn, in this order. `없음` when nothing was eaten: a bare
## `join()` on an empty PackedStringArray reads as a blank line, which is not a value.
func _rows() -> Array[String]:
	var species_str := ", ".join(result.species) if not result.species.is_empty() else "없음"
	return [
		"걸린 시간 %d:%02d" % [int(result.elapsed) / 60, int(result.elapsed) % 60],
		"먹은 경험치 %d" % result.experience,
		"먹은 종 %s" % species_str,
		"최대 무리 %d" % result.peak_swarm,
		"잃은 클론 %d" % result.clones_lost,
		"같이 날아간 것 %d" % result.cargo_lost,
	]


## Forwards to the two leaf hooks below and does nothing else.
func _paint_button(c: CanvasItem, r: Rect2, label: String, bg: Color, text_col: Color) -> void:
	_paint_rect(c, r, bg, true, -1.0)
	_paint_rect(c, r, Look.BUTTON_EDGE, false, Look.BUTTON_EDGE_WIDTH)
	_paint_text(c, r.position + Look.BUTTON_LABEL_INSET, label, Look.FONT_BUTTON, text_col)


## Forwards to the two leaf hooks below and does nothing else.
func _paint_slot(c: CanvasItem, r: Rect2, filled: String) -> void:
	_paint_rect(c, r, Look.SLOT_EMPTY, true, -1.0)
	_paint_rect(c, r, Look.BUTTON_EDGE, false, Look.SLOT_EDGE_WIDTH)
	if filled != "":
		_paint_text(c, r.position + Look.SLOT_LABEL_INSET, filled, Look.FONT_SLOT, Look.SCREEN_TEXT)


## The only place `draw_rect` is called in this file.
func _paint_rect(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
	c.draw_rect(r, col, filled, width)


## The only place `draw_string` is called in this file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _rect_of(k: int) -> Rect2:
	var total := Look.BUTTON_SIZE.x * 2.0 + Look.BUTTON_GAP
	var x := size.x * 0.5 - total * 0.5 + k * (Look.BUTTON_SIZE.x + Look.BUTTON_GAP)
	return Rect2(Vector2(x, size.y - Look.BUTTON_BOTTOM_MARGIN), Look.BUTTON_SIZE)


func _slot_rect_of(k: int) -> Rect2:
	var n := _slot_count()
	var total := Look.SLOT_SIZE.x * n + Look.SLOT_GAP * (n - 1)
	var x := size.x * 0.5 - total * 0.5 + k * (Look.SLOT_SIZE.x + Look.SLOT_GAP)
	return Rect2(Vector2(x, size.y - Look.SLOT_BOTTOM_MARGIN), Look.SLOT_SIZE)

