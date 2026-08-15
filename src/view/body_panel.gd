class_name BodyPanel
extends Control
## `Tab`: the body and the three keys, on one screen.
##
## **Two independent halves.** The user flagged that one key may be carrying too much and that `C` might
## take the second half later; laid out as two columns computed from `size`, that split is a re-parent
## rather than a rewrite. Left: the body's slots. Right: the three key rows.
##
## **This file never writes the simulation.** `src/view/` reads `sim` and nothing else, so a bind is a
## `bind_requested` signal the shell turns into `Body.bind()` — the same shape `CardPanel.picked` already
## has. It is also why the refusal message lives here and the refusal RULE lives in `Body.can_bind()`: the
## shell asks, the sim answers false, and `refuse()` puts a line on screen.
##
## ⚠ **`Body.can_bind()` gained a SECOND false case in plan 3** — a part that is neither worn nor already
## on a key — and one message for two refusals tells the player the wrong reason. Rather than copy the
## rule here to tell them apart, the panel **asks the sim** (`_can_pick()`) before it will hand a part out
## at all, so the only refusal a click can still produce is the movement gate. That is structural, not an
## assumption: a part the panel refused to pick up can never be dropped onto a key.
##
## **Every actual draw call is a leaf** — `_paint_panel` and `_paint_text` are the only places `draw_rect`
## and `draw_string` are called here, and `net_draw_leaf` holds this file to exactly that. Everything plan
## 3 added to the panel — part names, levels, the group headings, force and HP — is a rectangle or a
## string, so none of it needed a third primitive.
##
## ⚠ `set_anchors_and_offsets_preset`, not `set_anchors_preset`. Every rectangle below is computed from
## `size`, and anchors alone leave it at (0, 0) — the whole panel then piles into the top-left corner with
## every check about it green. Reported by the user on the first play, about `card_panel.gd`.

## ⚠ **`(part, key)`, in that order, matching `Body.bind(part, key)`.** Plan 2's signal was
## `(slot, active)` — the reverse — and both halves are `int`, so a mechanical re-point compiles, runs, and
## binds backwards with nothing to catch it. The argument names are the only thing that says which is which.
signal bind_requested(part: int, key: int)

## What each key row is called on screen, in the order `Body` fires them. Row 2 is `Body.KEY_MOVEMENT`.
const KEY_LABELS := ["좌클릭", "우클릭", "스페이스"]

## The two slot groups. **Externals put a shape on the body, internals change a drawing value** — one row
## of eleven says they are the same kind of thing. Headings rather than a silent gap, because the
## difference is the whole reason eleven slots cost no art.
const GROUP_LABELS := ["겉", "속"]

## The only refusal a click can reach — see the header. `Body.can_bind()` owns the rule; this is the
## sentence the player reads when it says no.
const REFUSAL := "스페이스에는 움직이는 것만 넣을 수 있다"

const EMPTY_LABEL := "빈 칸"

## **The whole `World`, not just the `Swarm`.** Plan 2's panel showed force only and held a `Swarm`; plan 3
## puts the host's HP beside it, and HP lives on `World` (current) and `Body` (the ceiling). Two references
## for one screen is two things the shell can forget to wire.
var world: World = null

## Which PART id is in hand, and where it was taken from. **-1 is empty and the sentinel is negative on
## purpose**: `Parts.BITE` is 0, so plan 2's `Actives.NONE == 0` carried across unchanged would read
## "holding 물기" as "holding nothing", and it would compile and run.
var _held := -1
var _held_row := -1
var _held_slot := -1
var _refusal := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## The only way it opens, and it sets `visible` itself — `CLAUDE.md` records a panel that never set it
## shipping under 5,576 green checks. A fresh open holds nothing and shows no stale refusal.
func open() -> void:
	visible = true
	_clear_hand()
	_refusal = ""
	queue_redraw()


func close() -> void:
	visible = false
	queue_redraw()


## Called by the shell when `Body.bind()` returned false. The panel does not decide this — it reports it.
func refuse() -> void:
	_refusal = REFUSAL
	queue_redraw()


## Two clicks, never a drag. Dragging is a different input model and it is not worth building for three
## rows. **Click a slot (or a key row) that holds an active to take it, then click the key row it should
## go to** — which is plan 3's model: the slots are the source now that parts fill them.
##
## ⚠ **Binding COPIES; the source keeps what it had.** A slot is not emptied by being bound to a key, so
## one part can sit on two keys at once and that is deliberate. What is NOT copied is the part the bind
## landed on: an active overwritten out of its last key and worn nowhere is gone, which is the trade the
## design wants when 말 다리 goes over `짧은 숨`.
##
## A slot is never a DESTINATION. Clicking one with something in hand puts the hand down rather than doing
## nothing, so the first click is always undoable.
func _gui_input(event: InputEvent) -> void:
	if not visible or world == null:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var k := _row_at(event.position)
	if k >= 0:
		if _held < 0:
			_take(world.body.bound[k], k, -1)
		else:
			# Cleared BEFORE the emit: the shell's handler runs inside it and may call `refuse()`, and
			# clearing afterwards would wipe the very message this click produced.
			_refusal = ""
			var part := _held
			_clear_hand()
			bind_requested.emit(part, k)
		queue_redraw()
		return
	var s := _slot_at(event.position)
	if s >= 0:
		if _held < 0:
			_take(world.body.slot_part[s], -1, s)
		else:
			_clear_hand()
			_refusal = ""
		queue_redraw()


## ⚠ **Latched only when something was actually taken.** An empty square left `_held` empty while
## `_held_row` still painted that row as lifted — a row highlighted with nothing in hand, and the player's
## next click then TOOK from the row they meant to drop onto.
func _take(part: int, row: int, slot: int) -> void:
	if part < 0 or not _can_pick(part):
		return
	_held = part
	_held_row = row
	_held_slot = slot


## **The sim answers this, the panel does not work it out.** `Body.can_bind()` against key 0 is exactly
## "this is an active the body actually has": key 0 applies every gate except the movement one, so a part
## that fails here fails on every key, and a part that passes can only ever be refused by `space`.
func _can_pick(part: int) -> bool:
	return world != null and world.body.can_bind(part, 0)


func _clear_hand() -> void:
	_held = -1
	_held_row = -1
	_held_slot = -1


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if world == null:
		return
	var b := world.body
	_paint_panel(c, Rect2(Vector2.ZERO, size), Look.BODY_DIM, true, -1.0)

	var first_slot := _slot_rect_of(0)
	var group_y := first_slot.position.y - Look.BODY_GROUP_LIFT
	_paint_text(c, Vector2(first_slot.position.x, group_y - Look.BODY_HEAD_LIFT), "몸",
			Look.FONT_HEADLINE, Look.SCREEN_TEXT)
	_paint_text(c, Vector2(first_slot.position.x, group_y), GROUP_LABELS[0], Look.FONT_GROUP,
			Look.SCREEN_TEXT)
	var first_internal := _slot_rect_of(_external_count())
	_paint_text(c, Vector2(first_internal.position.x, first_internal.position.y - Look.BODY_GROUP_LIFT),
			GROUP_LABELS[1], Look.FONT_GROUP, Look.SCREEN_TEXT)

	for k in _slot_count():
		var p := b.slot_part[k]
		_paint_slot(c, _slot_rect_of(k), _name_of(p), b.slot_level[k], k == _held_slot)

	# **The only place force and HP reach the screen.** A level's whole payout is `force[0] +=
	# FORCE_PER_LEVEL`, `F` halves every row, and a worn part moves both — all of it was invisible, which is
	# `CLAUDE.md`'s signature fake inverted (the simulation moves and the picture does not). Both force
	# numbers are read off the swarm and both HP numbers off the sim: the host's own row, the swarm's total,
	# the current HP and the ceiling parts raise. ⚠ **The sentence here used to say the total was what the
	# ecosystem is compared against.** No such comparison exists any more — disposition comes from the
	# species and damage is the attacker's force — so this panel is the only place the swarm's total force
	# is read for anything a player sees.
	#
	# ⚠ **Force and HP, and nothing else.** There is no separate defence number — "one extra contact" and
	# "+1 max HP" are the same sentence, and an earlier draft counted the mane's effect twice by printing
	# both.
	var last_slot := _slot_rect_of(_slot_count() - 1)
	_paint_text(c, Vector2(first_slot.position.x, last_slot.end.y + Look.BODY_NUMBERS_DROP),
			"힘 %d · 무리의 힘 %d · 체력 %d/%d" % [world.swarm.force[0], world.swarm.total_force(),
			world.host_hp, b.hp_max(world.level)], Look.FONT_ROW, Look.SCREEN_TEXT)

	var first_row := _row_rect_of(0)
	_paint_text(c, first_row.position - Vector2(0.0, Look.BODY_HEAD_LIFT), "손",
			Look.FONT_HEADLINE, Look.SCREEN_TEXT)
	for k in Body.KEY_COUNT:
		_paint_row(c, _row_rect_of(k), k, k == _held_row)

	if _refusal != "":
		var last := _row_rect_of(Body.KEY_COUNT - 1)
		_paint_text(c, Vector2(last.position.x, last.end.y + Look.BODY_REFUSAL_DROP), _refusal,
				Look.FONT_ROW, Look.BODY_REFUSAL_COLOR)


## ⚠ **`Parts.NAME[part]` on an empty square would return the LAST ROW.** `-1` is a legal index in
## GDScript and it counts from the end, so an unbound key would quietly read 말 폐활량 — no error, no red
## net. Every read of a part id in this file goes through here.
func _name_of(part: int) -> String:
	return str(Parts.NAME[part]) if part >= 0 else EMPTY_LABEL


## One slot: the square, its edge, the part's name and its level. A worn square reads as filled before the
## name is read. Forwards to the two leaves and draws nothing itself.
##
## `Lv1` is not printed — every worn part is at least Lv1, so printing it puts a number on ten squares
## that says nothing. The level only appears once it is worth something.
func _paint_slot(c: CanvasItem, r: Rect2, part_name: String, level: int, picked: bool) -> void:
	var bg: Color = Look.SLOT_EMPTY
	if picked:
		bg = Look.BODY_ROW_PICKED
	elif level > 0:
		bg = Look.BODY_SLOT_FILLED
	_paint_panel(c, r, bg, true, -1.0)
	_paint_panel(c, r, Look.BUTTON_EDGE, false, Look.SLOT_EDGE_WIDTH)
	if level > 0:
		_paint_text(c, r.position + Look.BODY_SLOT_NAME_INSET, part_name, Look.FONT_SLOT_NAME,
				Look.SCREEN_TEXT)
	if level > 1:
		_paint_text(c, r.position + Look.BODY_SLOT_LEVEL_INSET, "Lv%d" % level, Look.FONT_SLOT_LEVEL,
				Look.SCREEN_TEXT)


## One key and the part bound to it. Forwards to the two leaves and draws nothing itself.
##
## The level is deliberately NOT printed here: `BODY_ROW_TITLE_X` leaves 172px at `FONT_ROW`, 말 폐활량
## alone is close to it, and every `_paint_text` in this repo passes `-1` as the wrap width — a name that
## does not fit does not clip, it runs out over the panel. The level is on the slot, which is where the
## part actually lives.
func _paint_row(c: CanvasItem, r: Rect2, key: int, picked: bool) -> void:
	_paint_panel(c, r, Look.BODY_ROW_PICKED if picked else Look.BODY_ROW_BG, true, -1.0)
	_paint_panel(c, r, Look.BUTTON_EDGE, false, Look.BUTTON_EDGE_WIDTH)
	_paint_text(c, r.position + Look.BODY_ROW_INSET, str(KEY_LABELS[key]), Look.FONT_ROW,
			Look.SCREEN_TEXT)
	_paint_text(c, r.position + Look.BODY_ROW_INSET + Vector2(Look.BODY_ROW_TITLE_X, 0.0),
			_name_of(world.body.bound[key]), Look.FONT_ROW, Look.SCREEN_TEXT)


## The only place `draw_rect` is called in this file. Named for the panel because every rectangle the
## panel puts on screen goes through it, which is what lets a net assert them against the viewport rather
## than against the panel's own size — a bound taken from the thing it checks proves nothing.
func _paint_panel(c: CanvasItem, r: Rect2, col: Color, filled: bool, width: float) -> void:
	c.draw_rect(r, col, filled, width)


## The only place `draw_string` is called in this file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## **Eleven is `Parts.Slot` and nowhere else.** This file held the literal by way of
## `EndingScreen.SLOT_COUNT`, and that view constant is now read from the table too — the day a twelfth
## slot lands, two screens drawing eleven squares each is exactly the divergence the table's own header
## forbids.
func _slot_count() -> int:
	return Parts.Slot.size()


## Where the internals begin, from the table's own order rather than from a literal 6. `EYES` is the first
## internal slot; moving a slot across that line in `Parts.Slot` moves this with it.
func _external_count() -> int:
	return Parts.Slot.EYES


## Left half: the six external slots in a row with the five internal ones under them, both centred on the
## quarter-width, the pair centred vertically.
func _slot_rect_of(k: int) -> Rect2:
	var ext := _external_count()
	var row := 0 if k < ext else 1
	var idx := k if row == 0 else k - ext
	var n := ext if row == 0 else _slot_count() - ext
	var total := Look.BODY_SLOT_SIZE.x * n + Look.BODY_SLOT_GAP * (n - 1)
	var x := size.x * 0.25 - total * 0.5 + idx * (Look.BODY_SLOT_SIZE.x + Look.BODY_SLOT_GAP)
	var block := Look.BODY_SLOT_SIZE.y * 2.0 + Look.BODY_SLOT_ROW_GAP
	var y := size.y * 0.5 - block * 0.5 + row * (Look.BODY_SLOT_SIZE.y + Look.BODY_SLOT_ROW_GAP)
	return Rect2(Vector2(x, y), Look.BODY_SLOT_SIZE)


## Right half: three key rows stacked, centred on the three-quarter width.
func _row_rect_of(k: int) -> Rect2:
	var total := Look.BODY_ROW_SIZE.y * Body.KEY_COUNT + Look.BODY_ROW_GAP * (Body.KEY_COUNT - 1)
	var x := size.x * 0.75 - Look.BODY_ROW_SIZE.x * 0.5
	var y := size.y * 0.5 - total * 0.5 + k * (Look.BODY_ROW_SIZE.y + Look.BODY_ROW_GAP)
	return Rect2(Vector2(x, y), Look.BODY_ROW_SIZE)


func _row_at(p: Vector2) -> int:
	for k in Body.KEY_COUNT:
		if _row_rect_of(k).has_point(p):
			return k
	return -1


func _slot_at(p: Vector2) -> int:
	for k in _slot_count():
		if _slot_rect_of(k).has_point(p):
			return k
	return -1
