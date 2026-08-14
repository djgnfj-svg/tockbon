class_name BodyPanel
extends Control
## `Tab`: the body and the three keys, on one screen.
##
## **Two independent halves.** The user flagged that one key may be carrying too much and that `C` might
## take the second half later; laid out as two columns computed from `size`, that split is a re-parent
## rather than a rewrite. Left: the body's slots. Right: the three active rows.
##
## **This file never writes the simulation.** `src/view/` reads `sim` and nothing else, so a bind is a
## `bind_requested` signal the shell turns into `Swarm.bind()` — the same shape `CardPanel.picked` already
## has. It is also why the refusal message lives here and the refusal RULE lives in `Swarm.bind()`: the
## shell asks, the sim answers false, and `refuse()` puts a line on screen. Copying the rule into this
## file to grey a row out in advance would be the second copy that diverges.
##
## **Every actual draw call is a leaf** — `_paint_panel` and `_paint_text` are the only places `draw_rect`
## and `draw_string` are called here. `card_panel.gd` does not have this discipline (seven bare call sites)
## and is the wrong template; `ending_screen.gd` is the right one. A spy on a forwarding hook learns only
## that the hook was called, never that its body went on to draw.
##
## ⚠ `set_anchors_and_offsets_preset`, not `set_anchors_preset`. Every rectangle below is computed from
## `size`, and anchors alone leave it at (0, 0) — the whole panel then piles into the top-left corner with
## every check about it green. Reported by the user on the first play, about `card_panel.gd`.

signal bind_requested(slot: int, active: int)

## The eleven slots are `ending_screen.gd`'s number, read rather than restated — two screens drawing the
## same body from two literals is the divergence `CLAUDE.md` forbids. It moves onto the body itself in
## plan 3, and then both screens read it from there.
const SLOT_COUNT := EndingScreen.SLOT_COUNT

## What each active row is called on screen, in slot order. Slot 2 is `Swarm.SLOT_MOVEMENT`.
const KEY_LABELS := ["좌클릭", "우클릭", "스페이스"]

const REFUSAL := "스페이스에는 움직이는 것만 넣을 수 있다"

var swarm: Swarm = null

## Which active is in hand, and the row it was taken from. `Actives.NONE` means nothing is held — an empty
## row hands out nothing, so clicking it twice cannot bind emptiness onto another key.
var _held: int = Actives.NONE
var _held_row := -1
var _refusal := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## The only way it opens, and it sets `visible` itself — `CLAUDE.md` records a panel that never set it
## shipping under 5,576 green checks. A fresh open holds nothing and shows no stale refusal.
func open() -> void:
	visible = true
	_held = Actives.NONE
	_held_row = -1
	_refusal = ""
	queue_redraw()


func close() -> void:
	visible = false
	queue_redraw()


## Called by the shell when `Swarm.bind()` returned false. The panel does not decide this — it reports it.
func refuse() -> void:
	_refusal = REFUSAL
	queue_redraw()


## Two clicks, never a drag. Dragging is a different input model and it is not worth building for three
## rows. Click a row that holds an active to take it, then click the row it should go to.
##
## The body's slots are the other source of actives, and they are empty until plan 3 fills them — clicking
## one clears the hand rather than doing nothing, so the first click is always undoable.
##
## ⚠ **Binding COPIES; the source row keeps what it had.** The plan's source of an active is a body slot,
## and a slot is not emptied by being bound to a key — a key row standing in as the source until plan 3
## fills the slots does not change that rule, so 물기 can sit on two keys at once and that is deliberate,
## not an oversight. The source row is never painted empty, so the screen never claims otherwise. Asserted
## in `net_hands` rather than left to be re-decided the next time somebody reads this.
func _gui_input(event: InputEvent) -> void:
	if not visible or swarm == null:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var k := _row_at(event.position)
	if k >= 0:
		if _held == Actives.NONE:
			_held = swarm.bound[k]
			# ⚠ Latched only when something was actually taken. Slot 1 opens empty, so clicking it left
			# `_held` at NONE while `_held_row` still painted that row in `BODY_ROW_PICKED` — a row
			# highlighted as lifted with nothing in hand, and the player's next click then TOOK from the
			# row they meant to drop onto.
			if _held != Actives.NONE:
				_held_row = k
		else:
			# Cleared BEFORE the emit: the shell's handler runs inside it and may call `refuse()`, and
			# clearing afterwards would wipe the very message this click produced.
			_refusal = ""
			var active := _held
			_held = Actives.NONE
			_held_row = -1
			bind_requested.emit(k, active)
		queue_redraw()
		return
	if _slot_at(event.position) >= 0:
		_held = Actives.NONE
		_held_row = -1
		_refusal = ""
		queue_redraw()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if swarm == null:
		return
	_paint_panel(c, Rect2(Vector2.ZERO, size), Look.BODY_DIM, true, -1.0)

	var first_slot := _slot_rect_of(0)
	_paint_text(c, first_slot.position - Vector2(0.0, Look.BODY_HEAD_LIFT), "몸",
			Look.FONT_HEADLINE, Look.SCREEN_TEXT)
	for k in SLOT_COUNT:
		_paint_slot(c, _slot_rect_of(k))

	# **The only place force reaches the screen.** A level's whole payout is `force[0] += FORCE_PER_LEVEL`
	# and `F` halves every row — both were invisible, which is `CLAUDE.md`'s signature fake inverted (the
	# simulation moves and the picture does not), and a player holding `F` could not tell what halved or by
	# how much. Both numbers are read off the swarm, never restated: the host's own row, and the sum the
	# ecosystem is actually compared against (`World.is_hunter_of`).
	_paint_text(c, Vector2(first_slot.position.x, first_slot.end.y + Look.BODY_NUMBERS_DROP),
			"힘 %d · 무리의 힘 %d" % [swarm.force[0], swarm.total_force()], Look.FONT_ROW,
			Look.SCREEN_TEXT)

	var first_row := _row_rect_of(0)
	_paint_text(c, first_row.position - Vector2(0.0, Look.BODY_HEAD_LIFT), "손",
			Look.FONT_HEADLINE, Look.SCREEN_TEXT)
	for k in Swarm.SLOT_COUNT:
		_paint_row(c, _row_rect_of(k), k, k == _held_row)

	if _refusal != "":
		var last := _row_rect_of(Swarm.SLOT_COUNT - 1)
		_paint_text(c, Vector2(last.position.x, last.end.y + Look.BODY_REFUSAL_DROP), _refusal,
				Look.FONT_ROW, Look.BODY_REFUSAL_COLOR)


## Empty in this plan — plan 3 puts a part's name in it. Forwards to the two leaves and draws nothing
## itself.
func _paint_slot(c: CanvasItem, r: Rect2) -> void:
	_paint_panel(c, r, Look.SLOT_EMPTY, true, -1.0)
	_paint_panel(c, r, Look.BUTTON_EDGE, false, Look.SLOT_EDGE_WIDTH)


## One key and what is bound to it. Forwards to the two leaves and draws nothing itself.
func _paint_row(c: CanvasItem, r: Rect2, slot: int, picked: bool) -> void:
	_paint_panel(c, r, Look.BODY_ROW_PICKED if picked else Look.BODY_ROW_BG, true, -1.0)
	_paint_panel(c, r, Look.BUTTON_EDGE, false, Look.BUTTON_EDGE_WIDTH)
	_paint_text(c, r.position + Look.BODY_ROW_INSET, str(KEY_LABELS[slot]), Look.FONT_ROW,
			Look.SCREEN_TEXT)
	_paint_text(c, r.position + Look.BODY_ROW_INSET + Vector2(Look.BODY_ROW_TITLE_X, 0.0),
			str(Actives.TITLE[swarm.bound[slot]]), Look.FONT_ROW, Look.SCREEN_TEXT)


## The only place `draw_rect` is called in this file. Named for the panel because every rectangle the
## panel puts on screen goes through it, which is what lets a net assert them against the viewport rather
## than against the panel's own size — a bound taken from the thing it checks proves nothing.
func _paint_panel(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
	c.draw_rect(r, col, filled, width)


## The only place `draw_string` is called in this file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## Left half: the eleven slots in one row, centred on the quarter-width.
func _slot_rect_of(k: int) -> Rect2:
	var total := Look.SLOT_SIZE.x * SLOT_COUNT + Look.SLOT_GAP * (SLOT_COUNT - 1)
	var x := size.x * 0.25 - total * 0.5 + k * (Look.SLOT_SIZE.x + Look.SLOT_GAP)
	return Rect2(Vector2(x, size.y * 0.5 - Look.SLOT_SIZE.y * 0.5), Look.SLOT_SIZE)


## Right half: three key rows stacked, centred on the three-quarter width.
func _row_rect_of(k: int) -> Rect2:
	var total := Look.BODY_ROW_SIZE.y * Swarm.SLOT_COUNT + Look.BODY_ROW_GAP * (Swarm.SLOT_COUNT - 1)
	var x := size.x * 0.75 - Look.BODY_ROW_SIZE.x * 0.5
	var y := size.y * 0.5 - total * 0.5 + k * (Look.BODY_ROW_SIZE.y + Look.BODY_ROW_GAP)
	return Rect2(Vector2(x, y), Look.BODY_ROW_SIZE)


func _row_at(p: Vector2) -> int:
	for k in Swarm.SLOT_COUNT:
		if _row_rect_of(k).has_point(p):
			return k
	return -1


func _slot_at(p: Vector2) -> int:
	for k in SLOT_COUNT:
		if _slot_rect_of(k).has_point(p):
			return k
	return -1
