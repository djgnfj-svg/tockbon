class_name TitleView
extends Node2D

## The first screen. A name, three slots — **시작하기 · 설정하기 · 종료**, the three the user named in
## as many words — and cells drifting behind them.
##
## ⚠ **It holds no `Run` and asks the sim nothing**, which is not an omission: the title IS
## `run == null`, so there is no object to read. The shell raises and lowers it with `visible`, and
## that one field is the whole of the coupling. A `Run.State.TITLE` was considered and refused in the
## design — a state on an object that does not exist yet cannot be reached.
##
## It READS nothing and writes nothing. `slot_at` answers "what is under this point" and the SHELL
## decides what that means; `src/view/` is the folder with no way to change what happens.
##
## ⚠ **Everything on this screen exists to answer one failure**: the round before this one shipped a
## screen the user could not operate at all. So a slot is 360 x 88 (bigger than any press already in
## the game), it carries a border, it answers the cursor within 0.10 s, and it dips when pressed. **A
## slot that does not answer the cursor reads as "this does not press", not as "nothing happened"** —
## which is exactly why 설정하기 is drawn with no hover at all rather than with a silent one.
##
## Its clock is its own (`_fx_step`), like `panel_view`'s. `game.gd::_process` returns early while
## there is no run, so anything hung off the shell's time would be frozen for the entire time this
## screen is up — see `title-and-map`, and `combat-juice` section B for the same reasoning about the
## panel.
##
## `_draw()` calls `_paint_*` hooks and nothing else; `net_draw_leaf` pins each hook's `draw_*` count
## and reddens any function here it does not name.


## ⚠ **The game has no name yet.** This is `project.godot`'s own `config/name` in 한글, and it is the
## one string on this screen the user has not dictated — 시작하기 · 설정하기 · 종료 are theirs
## verbatim. It is a placeholder in the sense that it is waiting for a word, not in the sense that it
## is a stub: something has to be the loudest thing on the title screen.
const TITLE_TEXT := "톡본"

## The three slots, top to bottom. **Labels, not sentences**: the map screen carries the design's "no
## text" rule and the title carries this one exception, because the user named these three.
const SLOT_LABELS := ["시작하기", "설정하기", "종료"]

## Slot ids, so the shell never presses a bare integer.
const SLOT_START := 0
const SLOT_SETTINGS := 1
const SLOT_QUIT := 2

## Seconds this screen has been alive. The cells' drift is a pure function of it and of the cell's
## index — **no RNG anywhere**, the same reason `SHAKE_A_FREQ` is a constant: a random drift cannot be
## measured, and two `TitleView`s at the same age must agree exactly.
var _age := 0.0

## Which slot the cursor is over, or -1, and how long it has been there. The pair is a slot plus an
## age rather than a per-slot table because the cursor is in exactly one place.
var _hover_slot := -1
var _hover_age := 0.0

## The slot that was last pressed, and how long ago. Cleared by time, not by a second event: the dip
## is 0.10 s long and nothing has to remember to end it.
var _press_slot := -1
var _press_age := 0.0


## Slot `slot_index`'s RESTING rectangle. Read straight out of `look.gd` — the picture, the hit test
## and the net all ask the same function, so the geometry exists once.
func slot_rect_of(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= SLOT_LABELS.size():
		return Rect2()
	return Look.title_slot_rect_px(slot_index)


## The same rectangle grown by the shared press pad. Empty for a slot that does not exist, so a stray
## hit test cannot match: `Rect2()` has no area and `has_point` is false for every point.
func slot_hit_rect_of(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= SLOT_LABELS.size():
		return Rect2()
	return Look.title_slot_hit_rect_px(slot_index)


## The slot under `point`, or -1. **It answers for 설정하기 too** — whether that slot does anything is
## `is_slot_pressable`'s question, and folding the two would make "the cursor is over it" and "it
## works" the same fact, which is precisely the distinction the grey slot exists to draw.
func slot_at(point: Vector2) -> int:
	for i in SLOT_LABELS.size():
		if slot_hit_rect_of(i).has_point(point):
			return i
	return -1


## ⚠ **설정하기 does not press, and that is a decision rather than an unfinished feature.** `src/` has
## no audio, no window mode, no input map and no saved config; `FX_GAIN` is a `const` Array and cannot
## be written at runtime. A slot that opens an empty screen is worse than a slot that says it is not
## on offer. See `title-and-map`, open question B.
func is_slot_pressable(slot_index: int) -> bool:
	return slot_index == SLOT_START or slot_index == SLOT_QUIT


## The shell calls this on an ACCEPTED press and on nothing else.
##
## ⚠ It is deliberately not called for 설정하기: a press animation on a slot that does nothing is the
## picture telling the player something happened when nothing did, which is this repo's named
## "screen changes but sim doesn't" fake wearing a different hat.
func note_press(slot_index: int) -> void:
	if not is_slot_pressable(slot_index):
		return
	_press_slot = slot_index
	_press_age = 0.0


## The cursor moved. **The hover restarts only when the slot under it CHANGES**, so holding still over
## a slot does not keep the ramp pinned at zero.
##
## ⚠ A slot that cannot be pressed never becomes the hovered one. Its hover value is therefore always
## exactly 0 and `_slot_fill` cannot brighten it — the check that 「설정하기는 호버해도 안 변한다」
## bites here and not in the drawing code.
func set_hover(point: Vector2) -> void:
	var found := slot_at(point)
	if not is_slot_pressable(found):
		found = -1
	if found == _hover_slot:
		return
	_hover_slot = found
	_hover_age = 0.0


## How lit slot `slot_index` is, 0..1, ramping over `PRESS_HOVER_SEC`.
func _hover_of(slot_index: int) -> float:
	if slot_index != _hover_slot:
		return 0.0
	return clampf(_hover_age / Look.PRESS_HOVER_SEC, 0.0, 1.0)


## How far into its dip slot `slot_index` is, 1 at the instant of the press and 0 once
## `PRESS_DOWN_SEC` has passed. Linear, so the box returns to exactly its resting size rather than
## easing toward it forever — a slot left a fraction of a pixel small is a slot that never came back.
func _press_of(slot_index: int) -> float:
	if slot_index != _press_slot:
		return 0.0
	return clampf(1.0 - _press_age / Look.PRESS_DOWN_SEC, 0.0, 1.0)


## The slot's fill. `COL_START` for 시작하기 (**the same verb as the fight's start button, so the same
## tone**), `COL_BUTTON` for 종료, and `COL_SLOT_OFF` at `PRESS_ALPHA_OFF` with no saturation for the
## one that does not press. Hover lifts it, a press dips it, and both are no-ops on the dead slot
## because both of their inputs are pinned at zero for it.
func _slot_fill(slot_index: int) -> Color:
	if not is_slot_pressable(slot_index):
		return Look.dimmed(Look.COL_SLOT_OFF)
	var base: Color = Look.COL_START if slot_index == SLOT_START else Look.COL_BUTTON
	base.a = Look.PRESS_ALPHA_ON
	return Look.press_dipped(Look.hover_lit(base, _hover_of(slot_index)), _press_of(slot_index))


## The rectangle actually drawn: the resting one, shrunk about its own centre by the press dip.
##
## ⚠ **The label is placed off THIS rect and not off the resting one.** Dipping the box alone walks
## the glyphs out of it and dipping the glyphs alone leaves the box still — `combat-juice` item 8
## measured both halves on the refuse shake and this is the same rule.
func _slot_box(slot_index: int) -> Rect2:
	var rect := slot_rect_of(slot_index)
	var k := lerpf(1.0, Look.PRESS_DOWN_SCALE, _press_of(slot_index))
	var inner := rect.size * k
	return Rect2(rect.position + (rect.size - inner) * 0.5, inner)


## Where background cell `i` is right now. A unit direction from the index and a start point from the
## index, both through the two frequencies, so **every cell moves at exactly `TITLE_CELL_SPEED_PX`**
## and none of them can sit still. Wrapped with `fposmod`, which is what keeps every centre inside the
## viewport without a bounce rule that would have to be measured too.
func _cell_centre(i: int) -> Vector2:
	var th := float(i) * TAU * Look.TITLE_CELL_A_FREQ
	var ph := float(i) * TAU * Look.TITLE_CELL_B_FREQ
	var w := Look.VIEWPORT_W_PX
	var h := Look.VIEWPORT_H_PX
	var x := 0.5 * (1.0 + sin(ph)) * w + cos(th) * Look.TITLE_CELL_SPEED_PX * _age
	var y := 0.5 * (1.0 + cos(ph)) * h + sin(th) * Look.TITLE_CELL_SPEED_PX * _age
	return Vector2(fposmod(x, w), fposmod(y, h))


## Ages everything this screen owns. One function, so there is no second place a clock can be
## forgotten — and `_hover_age` is only aged while something is hovered, so an idle cursor does not
## quietly run the ramp up on nothing.
func _fx_step(delta: float) -> void:
	_age += delta
	if _hover_slot >= 0:
		_hover_age += delta
	if _press_slot >= 0:
		_press_age += delta
		if _press_age >= Look.PRESS_DOWN_SEC:
			_press_slot = -1


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


func _draw() -> void:
	var face := HudView.default_font()
	if face == null:
		return

	# The background first, and dimmer than a dead slot on purpose: at `PRESS_ALPHA_OFF` a drifting
	# cell would read as one more button.
	var cell := Look.COL_ALLY
	cell.a = Look.TITLE_CELL_ALPHA
	for i in Look.TITLE_CELL_COUNT:
		_paint_cell(_cell_centre(i), Look.TITLE_CELL_RADIUS_PX, cell)

	_paint_title(face, Look.TITLE_TEXT_POS_PX, TITLE_TEXT, Look.TITLE_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	for i in SLOT_LABELS.size():
		var box := _slot_box(i)
		# The border is the mark that says "this presses", so the slot that does not press is given
		# one at alpha 0 rather than a thin one: a hairline reads as a faint border, and a faint
		# border reads as a button that is merely far away.
		var edge := Look.COL_HUD_TEXT
		var edge_width := Look.PRESS_BORDER_WIDTH_PX
		if is_slot_pressable(i):
			edge_width = lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX,
				_hover_of(i))
		else:
			edge.a = 0.0
		_paint_slot_box(box, _slot_fill(i), edge, edge_width)
		var label: Color = Look.COL_HUD_TEXT
		if not is_slot_pressable(i):
			label = Look.dimmed(Look.COL_HUD_TEXT)
		_paint_slot_label(face, box.position + Look.TITLE_SLOT_TEXT_OFFSET_PX,
			str(SLOT_LABELS[i]), Look.TITLE_SLOT_FONT_SIZE_PX, label)


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf's `_table()`, and every parameter is
# used in the body: a leaf that quietly drops one of its arguments is invisible on screen and green in
# the round.

func _paint_cell(centre: Vector2, radius: float, col: Color) -> void:
	draw_circle(centre, radius, col)


func _paint_title(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## 2 calls: the fill, then the border that says it presses. One hook and not two, because a box
## without its border is not a different thing to draw — it is the same box saying something else.
func _paint_slot_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, edge, false, edge_width)


func _paint_slot_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
