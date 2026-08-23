class_name RefitView
extends Node2D
## The refit screen, two steps: a strip of slot boxes, then — once one is pressed — that slot's 3x2
## board of part cells beside the held pile, a five-number dashboard and a preview of the slot's body.
##
## It READS `run` — `run.army.loadout` for the board and the pile, `run.army` for which type each
## slot summons — and writes nothing back. Fitting and unfitting are the shell's job: this file answers
## "what is under this point" and `game.gd` calls `run.army.loadout.fit` / `unfit`.
##
## ⚠⚠ **The dashboard reads `run.army.loadout.stat_of(slot, col)` and NOTHING else** — the exact call
## `Army.max_hp_of` / `damage_of` / `period_of` / `speed_of` make. That is what makes "the screen and
## the sim disagree" unbuildable rather than merely checked: there is no second formula in this file
## for a part's five numbers to disagree with.
##
## ⚠ **The pile COMPACTS.** `Loadout.fit`/`unfit` may renumber every row after the one that changed, so
## this file never caches a held row's index across a frame boundary — it re-reads
## `run.army.loadout.held_part` / `held_species` fresh every time it needs them.
##
## The press vocabulary is REUSED from `look.gd`'s "Pressable things" block — no new press constant is
## declared here, matching `title_view` and `map_view` and `reward_view` before it.
##
## `_draw()` calls `_paint_*` hooks and nothing else; `net_draw_leaf` pins each hook's `draw_*` count
## and reddens any function here it does not name.


## Labels, indexed by `Rules.Part` / `Rules.Species`. `reward_view` carries the same two tables; a
## third copy here would be the same fact written three times, so this file reads THOSE rather than
## declaring its own.
const PART_LABELS := RewardView.PART_LABELS
const SPECIES_LABELS := RewardView.SPECIES_LABELS

## The five dashboard rows, top to bottom, indexed by `Rules.PART_COL_*`.
const STAT_LABELS := ["체력", "공격력", "공격주기", "사거리", "이동속도"]

var run: Run = null

## Which slot's board is open, or -1 for the strip alone.
var _open_slot := -1

var _hover_slot := -1
var _hover_age := 0.0
var _press_slot := -1
var _press_age := 0.0

## Cells and held rows share one hover/press pair each, keyed by their own index space (0..5 for a
## cell, 0..`refit_held_capacity()`-1 for a held row) — never confused with a slot because the caller
## always says which kind it is asking about.
var _hover_cell := -1
var _hover_cell_age := 0.0
var _press_cell := -1
var _press_cell_age := 0.0

var _hover_held := -1
var _hover_held_age := 0.0
var _press_held := -1
var _press_held_age := 0.0

var _hover_done := false
var _hover_done_age := 0.0
var _press_done := false
var _press_done_age := 0.0

## The dashboard's own chase, one triple per `Rules.PART_COL_*` — `map_view`'s `_force_from` /
## `_force_to` / `_force_age` shape, reused per column instead of once for the pool. ⚠⚠ **Without
## this, fitting a part and not fitting it look identical on screen** — the number would simply BE the
## new value, one frame apart from the old one, and nothing on the picture would say a change had just
## landed. `_stat_tracked_slot` is what tells a NEW SUBJECT (a different slot opened) from a RISE (the
## same slot's own number moved): the first snaps, only the second climbs.
## ⚠ **`Array[float]`, never `PackedFloat32Array`.** `Loadout.stat_of` returns a 64-bit `float`, and a
## packed array of 32-bit floats truncates every value written into it — measured: a period of exactly
## `0.85` round-trips through `PackedFloat32Array` at a hair off `0.85`, which is enough to flip which
## side of a `%.1f` rounding boundary it lands on between the value this file computed and the value
## the dashboard's own test re-derives independently. The five columns never need packing for speed;
## the loss bought nothing and cost the one thing this file exists to get right.
var _stat_from: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _stat_to: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _stat_age: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _stat_tracked_slot := -1

## The cell a part just landed in, or -1 — the shell's own `note_press` shape, called from
## `game.gd`'s `_refit_input` on an ACCEPTED fit and nowhere else. Keyed by part, not by slot: the
## board showing is already the open slot's own, so one index is enough.
var _filled_part := -1
var _filled_age := 0.0

## The screen's own age, since `bind` — `map_view._reveal_age`'s and `reward_view._reveal_age`'s own
## shape, reused for the scene wash below. This screen has no reveal stagger of its own to piggyback
## on the way the reward screen's card fade does, so this is the only clock driving it.
var _reveal_age := 0.0


func bind(r: Run) -> void:
	run = r
	_reveal_age = 0.0
	_open_slot = -1
	_hover_slot = -1
	_hover_age = 0.0
	_press_slot = -1
	_press_age = 0.0
	_hover_cell = -1
	_hover_cell_age = 0.0
	_press_cell = -1
	_press_cell_age = 0.0
	_hover_held = -1
	_hover_held_age = 0.0
	_press_held = -1
	_press_held_age = 0.0
	_hover_done = false
	_hover_done_age = 0.0
	_press_done = false
	_press_done_age = 0.0
	_stat_tracked_slot = -1
	_filled_part = -1
	_filled_age = 0.0
	queue_redraw()


## Called by `game.gd`'s `_refit_input`, and only on a fit that actually landed — a refused press
## (an empty held row, an out-of-range slot) must never start this beat, or a cell that did nothing
## would flash exactly like one that did.
func note_fitted(part: int) -> void:
	_filled_part = part
	_filled_age = 0.0


func open_slot(s: int) -> void:
	if s < 0 or s >= Rules.summon_slot_count():
		_open_slot = -1
	else:
		_open_slot = s
	_hover_cell = -1
	_hover_held = -1
	# Switching slots (or closing the board) leaves any in-flight flash behind — it belongs to a cell
	# on the board that just left the screen, not to whatever opens next.
	_filled_part = -1
	_filled_age = 0.0
	# A newly opened slot's numbers arrive already settled — there is nothing to have climbed FROM.
	# `_stat_shown` below reads `_stat_age >= MAP_HEAL_SEC` as "arrived", so this is the one place both
	# ends of the triple are set equal and the age is pinned at the ceiling.
	if _open_slot >= 0 and _open_slot != _stat_tracked_slot and run != null:
		_stat_tracked_slot = _open_slot
		var loadout := run.army.loadout
		for col in Rules.PART_COL_TOTAL:
			var v := loadout.stat_of(_open_slot, col)
			_stat_from[col] = v
			_stat_to[col] = v
			_stat_age[col] = Look.MAP_HEAL_SEC


func is_board_open() -> bool:
	return _open_slot >= 0


## Which slot's board is open, or -1. The shell reads this to know which slot a held-row or cell press
## belongs to; the field stays private (leading underscore) and this is its one public window.
func open_slot_index() -> int:
	return _open_slot


# --- geometry, read straight out of look.gd -----------------------------------------------------

func slot_rect_of(slot: int) -> Rect2:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return Rect2()
	return Look.refit_slot_rect_px(slot)


func slot_hit_rect_of(slot: int) -> Rect2:
	if slot < 0 or slot >= Rules.summon_slot_count():
		return Rect2()
	return Look.refit_slot_hit_rect_px(slot)


func slot_at(point: Vector2) -> int:
	for s in Rules.summon_slot_count():
		if slot_hit_rect_of(s).has_point(point):
			return s
	return -1


func cell_rect_of(part: int) -> Rect2:
	if part < 0 or part >= Rules.part_count():
		return Rect2()
	return Look.refit_cell_rect_px(part)


func cell_hit_rect_of(part: int) -> Rect2:
	if part < 0 or part >= Rules.part_count():
		return Rect2()
	return Look.refit_cell_hit_rect_px(part)


func cell_at(point: Vector2) -> int:
	if not is_board_open():
		return -1
	for p in Rules.part_count():
		if cell_hit_rect_of(p).has_point(point):
			return p
	return -1


func held_rect_of(row_index: int) -> Rect2:
	if row_index < 0 or row_index >= Look.refit_held_capacity():
		return Rect2()
	return Look.refit_held_rect_px(row_index)


func held_hit_rect_of(row_index: int) -> Rect2:
	if row_index < 0 or row_index >= Look.refit_held_capacity():
		return Rect2()
	return Look.refit_held_hit_rect_px(row_index)


## The held row under `point`, or -1. Only among rows the pile actually holds right now — a stray hit
## past the end of `held_part` cannot match, because that index names no card.
func held_at(point: Vector2) -> int:
	if not is_board_open() or run == null:
		return -1
	var n := run.army.loadout.held_part.size()
	for row in mini(n, Look.refit_held_capacity()):
		if held_hit_rect_of(row).has_point(point):
			return row
	return -1


func done_rect() -> Rect2:
	return Look.refit_done_rect_px(is_board_open())


func done_hit_rect() -> Rect2:
	return done_rect().grow(Look.PRESS_HIT_PAD_PX)


func is_done_pressable(point: Vector2) -> bool:
	return done_hit_rect().has_point(point)


func back_rect() -> Rect2:
	return Look.refit_back_rect_px()


func back_hit_rect() -> Rect2:
	return back_rect().grow(Look.PRESS_HIT_PAD_PX)


func is_back_pressable(point: Vector2) -> bool:
	return is_board_open() and back_hit_rect().has_point(point)


# --- hover / press --------------------------------------------------------------------------------

func set_hover(point: Vector2) -> void:
	var s := slot_at(point)
	if s != _hover_slot:
		_hover_slot = s
		_hover_age = 0.0
	var c := cell_at(point)
	if c != _hover_cell:
		_hover_cell = c
		_hover_cell_age = 0.0
	var h := held_at(point)
	if h != _hover_held:
		_hover_held = h
		_hover_held_age = 0.0
	var d := is_done_pressable(point) or is_back_pressable(point)
	if d != _hover_done:
		_hover_done = d
		_hover_done_age = 0.0


func note_slot_press(s: int) -> void:
	_press_slot = s
	_press_age = 0.0


func note_cell_press(part: int) -> void:
	_press_cell = part
	_press_cell_age = 0.0


func note_held_press(row_index: int) -> void:
	_press_held = row_index
	_press_held_age = 0.0


func note_done_press() -> void:
	_press_done = true
	_press_done_age = 0.0


func _hover_of(v: float, k: int, want: int) -> float:
	if k != want:
		return 0.0
	return clampf(v / Look.PRESS_HOVER_SEC, 0.0, 1.0)


func _press_of(v: float) -> float:
	return clampf(1.0 - v / Look.PRESS_DOWN_SEC, 0.0, 1.0)


func _fx_step(delta: float) -> void:
	_reveal_age += delta
	if _hover_slot >= 0:
		_hover_age += delta
	if _press_slot >= 0:
		_press_age += delta
		if _press_age >= Look.PRESS_DOWN_SEC:
			_press_slot = -1
	if _hover_cell >= 0:
		_hover_cell_age += delta
	if _press_cell >= 0:
		_press_cell_age += delta
		if _press_cell_age >= Look.PRESS_DOWN_SEC:
			_press_cell = -1
	if _hover_held >= 0:
		_hover_held_age += delta
	if _press_held >= 0:
		_press_held_age += delta
		if _press_held_age >= Look.PRESS_DOWN_SEC:
			_press_held = -1
	if _hover_done:
		_hover_done_age += delta
	if _press_done:
		_press_done_age += delta
		if _press_done_age >= Look.PRESS_DOWN_SEC:
			_press_done = false
	if _filled_part >= 0:
		_filled_age = minf(_filled_age + delta, Look.REFIT_CELL_FILL_SEC)
	# The dashboard chase. Read at whatever point a fit or an unfit actually landed — never re-derived
	# from `_open_slot` alone — so a column that did not move keeps its own `_stat_to` and reads back
	# byte-identical, and a column that did starts its climb from where the picture ALREADY was, not
	# from the value it was chasing before (a second fit mid-climb does not restart at the first fit's
	# own start).
	if _open_slot >= 0 and run != null:
		var loadout := run.army.loadout
		for col in Rules.PART_COL_TOTAL:
			_stat_age[col] = minf(_stat_age[col] + delta, Look.MAP_HEAL_SEC)
			var live := loadout.stat_of(_open_slot, col)
			if not is_equal_approx(live, _stat_to[col]):
				_stat_from[col] = _stat_shown(col)
				_stat_to[col] = live
				_stat_age[col] = 0.0


## 0..1 chase read back as the actual number, column by column -- `map_view`'s own `lerpf` line,
## reused. `_stat_age >= MAP_HEAL_SEC` answers "arrived" so a column that never moved (age pinned at
## the ceiling by `open_slot`) returns `_stat_to` exactly rather than a lerp that happens to land there.
func _stat_shown(col: int) -> float:
	if _stat_age[col] >= Look.MAP_HEAL_SEC:
		return _stat_to[col]
	return lerpf(_stat_from[col], _stat_to[col], clampf(_stat_age[col] / Look.MAP_HEAL_SEC, 0.0, 1.0))


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


# --- drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	if run == null or run.state() != Run.State.REFIT:
		return
	var face := HudView.default_font()
	if face == null:
		return

	# The strip is drawn on BOTH steps and the boxes do not move — the open one stays legible even
	# once the board covers the rest of the screen.
	#
	# ⚠ **`lit` is "not dimmed", not "is the open one".** Before any slot is opened both boxes ARE
	# pressable — pressing either one opens it — so `Look.dimmed` (the SAME tone the title screen
	# uses for a slot that CANNOT be pressed at all) painted on both would say the opposite of what
	# is true. Once one is open, the OTHER dims to say "you are looking at slot N, not this one" —
	# still pressable, just not the one on screen — never "locked".
	for s in Rules.summon_slot_count():
		var lit := s == _open_slot or _open_slot < 0
		var fill := Look.COL_BUTTON if lit else Look.dimmed(Look.COL_BUTTON)
		fill.a = Look.PRESS_ALPHA_ON if lit else Look.PRESS_ALPHA_OFF
		var hover_k := _hover_of(_hover_age, _hover_slot, s)
		fill = Look.hover_lit(fill, hover_k)
		var edge_w := lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX, hover_k)
		_paint_slot_box(slot_rect_of(s), fill, Look.COL_HUD_TEXT, edge_w)
		_paint_slot_label(face, slot_rect_of(s).position + Look.CARD_PART_OFFSET_PX,
			"슬롯 %d" % (s + 1), Look.REFIT_CELL_PART_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	if is_board_open():
		_draw_board(face)
	else:
		# The one line of text on this screen while nothing is open yet — without it, this is the
		# only screen the player stands on where everything pressable is unlabelled.
		_paint_hint(face, Look.REFIT_HINT_POS_PX, "슬롯을 눌러 부위를 낍니다",
			Look.REFIT_HINT_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	var done_label := "완료"
	var done_col := Look.press_dipped(Look.hover_lit(Look.COL_START, 1.0 if _hover_done else 0.0),
		_press_of(_press_done_age) if _press_done else 0.0)
	_paint_button(face, done_rect(), done_col, done_label,
		done_rect().position + Vector2(70.0, 50.0), Look.REFIT_STAT_LABEL_FONT_SIZE_PX,
		Look.COL_HUD_TEXT)
	if is_board_open():
		_paint_button(face, back_rect(), Look.COL_BUTTON, "뒤로",
			back_rect().position + Vector2(70.0, 50.0), Look.REFIT_STAT_LABEL_FONT_SIZE_PX,
			Look.COL_HUD_TEXT)

	# The scene wash, last and over everything — `map_view`'s own shape. Without it this screen has
	# no arrival at all: two captures 0.4s apart used to be byte-identical, a hard cut with nothing on
	# screen saying the screen had just changed.
	var wash := clampf(1.0 - _reveal_age / Look.SCENE_FADE_SEC, 0.0, 1.0)
	if wash > 0.0:
		_paint_fade(Rect2(Vector2.ZERO, Look.viewport_size_px()), Look.scene_fade_colour(wash))


## The cell's own fill colour — item 5's flash, folded into the same channel the filled/empty story
## already uses. ⚠⚠ **Without this, fitting a part and not fitting it look identical on screen** —
## the cell would simply BE filled, one frame apart from empty. A cell that is NOT the one that just
## landed reads exactly as before this beat existed; only `_filled_part`'s own cell climbs instead of
## snapping, over `REFIT_CELL_FILL_SEC`.
func _cell_fill(p: int, filled: bool) -> Color:
	if filled and p == _filled_part and _filled_age < Look.REFIT_CELL_FILL_SEC:
		var t := clampf(_filled_age / Look.REFIT_CELL_FILL_SEC, 0.0, 1.0)
		var fill := Look.dimmed(Look.COL_BUTTON).lerp(Look.COL_BUTTON, t)
		fill.a = lerpf(Look.PRESS_ALPHA_OFF, Look.PRESS_ALPHA_ON, t)
		return fill
	var fill := Look.COL_BUTTON if filled else Look.dimmed(Look.COL_BUTTON)
	fill.a = Look.PRESS_ALPHA_ON if filled else Look.PRESS_ALPHA_OFF
	return fill


func _draw_board(face: Font) -> void:
	var loadout := run.army.loadout
	for p in Rules.part_count():
		var species := loadout.fitted_species(_open_slot, p)
		var filled := species >= 0
		var hover_k := _hover_of(_hover_cell_age, _hover_cell, p)
		var fill := Look.hover_lit(_cell_fill(p, filled), hover_k)
		var edge_w := lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX, hover_k)
		var box := cell_rect_of(p)
		var scale := lerpf(1.0, Look.PRESS_DOWN_SCALE, _press_of(_press_cell_age) if _press_cell == p else 0.0)
		var inner := Rect2(box.position + box.size * (1.0 - scale) * 0.5, box.size * scale)
		_paint_cell_box(inner, fill, Look.COL_HUD_TEXT, edge_w)
		_paint_cell_part(face, box.position + Look.CARD_PART_OFFSET_PX * 0.7,
			str(PART_LABELS[p]), Look.REFIT_CELL_PART_FONT_SIZE_PX, Look.COL_HUD_TEXT)
		var species_text := str(SPECIES_LABELS[species]) if filled else "-"
		var species_col: Color = Look.COL_SPECIES[species] if filled else Look.dimmed(Look.COL_HUD_TEXT)
		_paint_cell_species(face, box.position + Look.CARD_SPECIES_OFFSET_PX * 0.7,
			species_text, Look.REFIT_CELL_SPECIES_FONT_SIZE_PX, species_col)

	var held_n := mini(loadout.held_part.size(), Look.refit_held_capacity())
	for row in held_n:
		var part := int(loadout.held_part[row])
		var species := int(loadout.held_species[row])
		var rect := held_rect_of(row)
		var hover_k := _hover_of(_hover_held_age, _hover_held, row)
		var edge_w := lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX, hover_k)
		_paint_held_row(rect, Look.hover_lit(Look.COL_BUTTON, hover_k), Look.COL_HUD_TEXT, edge_w)
		_paint_held_part(face, rect.position + Vector2(8.0, 22.0), str(PART_LABELS[part]),
			Look.REFIT_CELL_SPECIES_FONT_SIZE_PX, Look.COL_HUD_TEXT)
		_paint_held_species(face, rect.position + Vector2(8.0, 42.0), str(SPECIES_LABELS[species]),
			Look.REFIT_CELL_SPECIES_FONT_SIZE_PX, Look.COL_SPECIES[species])

	# ⚠⚠ The dashboard's TARGET is `loadout.stat_of` and nothing else — the same call `Army`'s five
	# lookups make — but the drawn NUMBER is `_stat_shown(col)`, the chase toward that target. The two
	# agree the instant a slot opens and the instant a climb finishes; between those two moments the
	# picture is honestly mid-flight, and that gap is item 6's whole point — without it a fitted part
	# and an unfitted one look identical on screen for exactly one frame less than forever.
	for col in Rules.PART_COL_TOTAL:
		var value := _stat_shown(col)
		_paint_stat_label(face, Look.refit_stat_origin_px(col), str(STAT_LABELS[col]),
			Look.REFIT_STAT_LABEL_FONT_SIZE_PX, Look.COL_HUD_TEXT)
		_paint_stat_value(face, Look.refit_stat_origin_px(col) + Vector2(0.0, 30.0),
			"%.1f" % value, Look.REFIT_STAT_VALUE_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	# The body preview: which slot you are editing and nothing else — no part is drawn on it. Both the
	# radius and the corner rounding are the slot's own type at `REFIT_BODY_SCALE`, so two slots read
	# differently on both channels — 14 px vs 11.2 px radius, 0.25 vs 0.85 corner ratio.
	var type_id := Rules.summon_type_of(_open_slot)
	var radius := Look.body_radius_of(type_id) * Look.REFIT_BODY_SCALE
	var corner := Look.body_corner_radius_of(type_id) * Look.REFIT_BODY_SCALE
	_paint_body(Look.REFIT_BODY_CENTRE_PX, radius, corner, Look.COL_ALLY)


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf; every parameter is used in the body.

func _paint_slot_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, edge, false, edge_width)


func _paint_slot_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_cell_box(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, edge, false, edge_width)


func _paint_cell_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_cell_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_held_row(rect: Rect2, bg: Color, edge: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, edge, false, edge_width)


func _paint_held_part(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_held_species(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_stat_label(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_stat_value(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## The body: an outline and a centre dot, the same shape `field_view._paint_body` draws, at this
## screen's own scale. **No part is drawn on it** — the dashboard carries what a fitted part moved.
func _paint_body(centre: Vector2, radius: float, corner: float, colour: Color) -> void:
	draw_polyline(_rounded_square(centre, radius, corner), colour, Look.BODY_OUTLINE_WIDTH_PX)
	draw_circle(centre, Look.BODY_DOT_RADIUS_PX, colour)


func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_fade(rect: Rect2, col: Color) -> void:
	draw_rect(rect, col, true)


## 0 draws — geometry built for `_paint_body`, the `_spark_points` precedent.
func _rounded_square(centre: Vector2, radius: float, corner: float) -> PackedVector2Array:
	var half := radius - corner
	var pts: Array[Vector2] = []
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for ci in 4:
		var base: Vector2 = corners[ci] * half
		for a in 3:
			var ang := (float(ci) + float(a) / 2.0) * PI * 0.5
			pts.append(centre + base + Vector2(cos(ang), sin(ang)) * corner)
	pts.append(pts[0])
	var out := PackedVector2Array()
	for p in pts:
		out.append(p)
	return out
