class_name RewardView
extends Node2D
## The reward screen: six cards after a won fight, take two. Each card carries a part and a species —
## `run.cards` is `Rules.CARDS_PER_WIN` `(part, species)` pairs, flat, drawn by `Run._draw_cards`.
##
## It READS `run` and writes nothing back — `is_card_pressable` asks `Run.take_card` would accept the
## index, the same call the shell makes when the hold expires, so the picture can never offer a card
## the sim refuses. Pressing is the shell's job.
##
## The press vocabulary is REUSED from `look.gd`'s "Pressable things" block, the same one `title_view`
## and `map_view` already carry: a card is 3.3x brighter than a card that cannot be taken, it has a
## hover border and a press dip, and none of that is redeclared here.
##
## Its clock is its own (`_fx_step`), like every other screen's: `game.gd::_process` reaches nothing
## here while the panel is not up, and an effect hung off the shell's time would freeze the moment a
## hold or a fight paused it.
##
## `_draw()` calls `_paint_*` hooks and nothing else; `net_draw_leaf` pins each hook's `draw_*` count
## and reddens any function here it does not name.


## Labels, not sentences — same exception `title_view.SLOT_LABELS` carries. Indexed by `Rules.Part`.
const PART_LABELS := ["머리", "가슴", "배", "팔", "손", "다리"]

## Indexed by `Rules.Species`.
const SPECIES_LABELS := ["포유류", "조류", "어류"]

var run: Run = null

## The cursor's card and how long it has been there; the pressed card and how long ago. Same shape as
## every other screen's hover/press pair.
var _hover_card := -1
var _hover_age := 0.0
var _press_card := -1
var _press_age := 0.0

## Item: the taken mark grows over its own beat, per card, so the second pick does not restart the
## first mark's growth. Keyed by card index.
var _taken_age: Dictionary = {}

## The screen's own age, since `bind`. Drives the card reveal stagger below — `map_view._reveal_age`'s
## exact shape, reused rather than re-invented: the screen arrived, it was not always there.
var _reveal_age := 0.0


func bind(r: Run) -> void:
	run = r
	_hover_card = -1
	_hover_age = 0.0
	_press_card = -1
	_press_age = 0.0
	_taken_age.clear()
	_reveal_age = 0.0
	queue_redraw()


## 0..1, how far card `k` has faded in. `k` cards apart, `MAP_REVEAL_STEP_SEC` apart, each taking
## `MAP_NODE_FADE_SEC` — `map_view._reveal_alpha_of`'s own constants, reused rather than redeclared,
## for the reason `look.gd`'s own header on that pair gives: the map already answered "how fast does
## one thing among several fade in" and a second answer here would be the same fact chosen twice.
func _reveal_alpha_of(k: int) -> float:
	var start := float(k) * Look.MAP_REVEAL_STEP_SEC
	return clampf((_reveal_age - start) / Look.MAP_NODE_FADE_SEC, 0.0, 1.0)


func card_rect_of(k: int) -> Rect2:
	if k < 0 or k >= Rules.CARDS_PER_WIN:
		return Rect2()
	return Look.card_rect_px(k)


func card_hit_rect_of(k: int) -> Rect2:
	if k < 0 or k >= Rules.CARDS_PER_WIN:
		return Rect2()
	return Look.card_hit_rect_px(k)


func card_at(point: Vector2) -> int:
	for k in Rules.CARDS_PER_WIN:
		if card_hit_rect_of(k).has_point(point):
			return k
	return -1


## ⚠ **Asked of the SIM and not of a local `cards_taken` read**, the same shape `map_view.is_node_pressable`
## already carries: whether a card may be taken is `Run.take_card`'s call to make, and this file must
## never offer a press the sim would refuse. `take_card` changes nothing on a refusal, so calling it
## here to test would consume a card just to ask about it — this asks without acting instead.
func is_card_pressable(k: int) -> bool:
	if run == null or run.state() != Run.State.PICK:
		return false
	if k < 0 or k >= Rules.CARDS_PER_WIN:
		return false
	if run.cards_taken[k] != 0:
		return false
	var taken := 0
	for b in run.cards_taken:
		if b != 0:
			taken += 1
	return taken < Rules.CARD_PICKS


func set_hover(point: Vector2) -> void:
	var found := card_at(point)
	if not is_card_pressable(found):
		found = -1
	if found == _hover_card:
		return
	_hover_card = found
	_hover_age = 0.0


## The shell calls this on an ACCEPTED press, after asking `is_card_pressable` and before calling
## `run.take_card`.
func note_press(k: int) -> void:
	if not is_card_pressable(k):
		return
	_press_card = k
	_press_age = 0.0


func _hover_of(k: int) -> float:
	if k != _hover_card:
		return 0.0
	return clampf(_hover_age / Look.PRESS_HOVER_SEC, 0.0, 1.0)


func _press_of(k: int) -> float:
	if k != _press_card:
		return 0.0
	return clampf(1.0 - _press_age / Look.PRESS_DOWN_SEC, 0.0, 1.0)


## 0..1, how grown the taken mark on card `k` is. 0 for a card that was never taken.
func _taken_of(k: int) -> float:
	if not _taken_age.has(k):
		return 0.0
	return clampf(float(_taken_age[k]) / Look.CARD_TAKEN_GROW_SEC, 0.0, 1.0)


func _card_box(k: int) -> Rect2:
	var rect := card_rect_of(k)
	var s := lerpf(1.0, Look.PRESS_DOWN_SCALE, _press_of(k))
	var inner := rect.size * s
	return Rect2(rect.position + (rect.size - inner) * 0.5, inner)


## ⚠⚠ **A taken card and a card that can no longer be taken both fall to `PRESS_ALPHA_OFF`, so alpha
## alone cannot tell them apart.** This is the fill's own half of the channel — the mark drawn on top
## (`_paint_taken_mark`) is the third.
func _card_fill(k: int) -> Color:
	var base := Look.COL_CARD
	if run != null and int(run.cards_taken[k]) != 0:
		base.a = Look.PRESS_ALPHA_OFF
		return base
	base.a = Look.PRESS_ALPHA_ON if is_card_pressable(k) else Look.PRESS_ALPHA_OFF
	if not is_card_pressable(k):
		return base
	return Look.press_dipped(Look.hover_lit(base, _hover_of(k)), _press_of(k))


func _fx_step(delta: float) -> void:
	_reveal_age += delta
	if _hover_card >= 0:
		_hover_age += delta
	if _press_card >= 0:
		_press_age += delta
		if _press_age >= Look.PRESS_DOWN_SEC:
			_press_card = -1
	if run == null:
		return
	for k in Rules.CARDS_PER_WIN:
		if int(run.cards_taken[k]) != 0:
			_taken_age[k] = float(_taken_age.get(k, 0.0)) + delta


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


## The picks made so far, out of `Rules.CARD_PICKS` — the hint line's whole content.
func _picks_made() -> int:
	if run == null:
		return 0
	var n := 0
	for b in run.cards_taken:
		if b != 0:
			n += 1
	return n


func _draw() -> void:
	if run == null or run.state() != Run.State.PICK:
		return
	var face := HudView.default_font()
	if face == null:
		return

	for k in Rules.CARDS_PER_WIN:
		# ⚠⚠ **The reveal is the FILL's alpha alone, multiplied in — not a second colour.** The fill
		# already carries the pressable/taken/hover story on its own alpha; multiplying the reveal
		# factor on top is "not yet arrived" riding the exact channel "not yet pressable" already
		# uses, so the two never have to agree on a second rule about what a low alpha means.
		var reveal := _reveal_alpha_of(k)
		var box := _card_box(k)
		var edge_width := lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX,
			_hover_of(k))
		var fill := _card_fill(k)
		fill.a *= reveal
		_paint_card(box, fill, edge_width)
		var part := int(run.cards[2 * k])
		var species := int(run.cards[2 * k + 1])
		var part_col := Look.COL_HUD_TEXT
		part_col.a *= reveal
		_paint_card_part(face, box.position + Look.CARD_PART_OFFSET_PX,
			str(PART_LABELS[part]), Look.CARD_PART_FONT_SIZE_PX, part_col)
		var species_col: Color = Look.COL_SPECIES[species]
		species_col.a *= reveal
		_paint_card_species(face, box.position + Look.CARD_SPECIES_OFFSET_PX,
			str(SPECIES_LABELS[species]), Look.CARD_SPECIES_FONT_SIZE_PX, species_col)
		if int(run.cards_taken[k]) != 0:
			var mark := Look.COL_HUD_TEXT
			mark.a = Look.PRESS_ALPHA_ON * _taken_of(k)
			_paint_taken_mark(box.get_center(), Look.CARD_TAKEN_MARK_R_PX * _taken_of(k), mark)

	var hint := "%d / %d 골랐습니다" % [_picks_made(), Rules.CARD_PICKS]
	_paint_hint(face, Look.CARD_HINT_POS_PX, hint, Look.CARD_HINT_FONT_SIZE_PX, Look.COL_HUD_TEXT)


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf's `_table()`, and every parameter is
# used in the body: a leaf that quietly drops one of its arguments is invisible on screen and green in
# the round.

func _paint_card(rect: Rect2, bg: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, Look.COL_HUD_TEXT, false, edge_width)


func _paint_card_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_card_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_taken_mark(centre: Vector2, radius: float, col: Color) -> void:
	draw_circle(centre, radius, col)


func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
