class_name RewardView
extends Node2D
## The reward screen: three cards after a won fight, take one. Each card carries an equipment ITEM —
## `run.cards` is `Rules.CARDS_PER_WIN` item ids, one int per card, drawn by `Run._draw_cards`.
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


## Labels, not sentences — same exception `title_view.SLOT_LABELS` carries. Indexed by `Rules.Rarity`.
## ⚠⚠ **`PART_LABELS` and `SPECIES_LABELS` are DELETED** (2026-08-24). They said 「머리 · 가슴 · 배 ·
## 팔 · 손 · 다리」 and 「포유류 · 조류 · 어류」 — the cell game's body diagram, still on the card two
## games later. A card carries an ITEM now: its name, what it does, and how rare it is.
const RARITY_LABELS := ["일반", "희귀", "영웅", "전설"]

var run: Run = null

## The item pictures, loaded once at init off `Look.ITEM_ART` — the same `load(Look.…)`-at-var-init
## shape `field_view`'s picture block uses. An empty art row loads as `null` and the art leaf is
## simply not called for it: **no picture is drawn rather than a wrong one** (티켓 12's closed fork).
var _art: Array = _load_item_art()

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


static func _load_item_art() -> Array:
	var out: Array = []
	for p in Look.ITEM_ART:
		out.append(null if str(p) == "" else load(str(p)))
	return out


## How far card `k` still is from its resting place, in px — the deal-in. Eased on the reveal's OWN
## value (smoothstep, so it arrives without a snap), and ⚠ **applied to the DRAWN box only**:
## `card_rect_of`/hit rects stay at rest, so input and the sim see nothing move.
func _deal_offset_of(k: int) -> Vector2:
	var r := _reveal_alpha_of(k)
	var eased := r * r * (3.0 - 2.0 * r)
	return Vector2(0.0, (1.0 - eased) * Look.CARD_DEAL_SLIDE_PX)


## 0..1, where card `k`'s rarity pulse is in its breath — a sine on `_reveal_age`, the screen's one
## clock. 0 for a rarity whose `RARITY_PULSE_SEC` row is 0: no pulse, never a division by it.
func _pulse_of(k: int) -> float:
	if run == null:
		return 0.0
	var rarity := Rules.item_rarity_of(int(run.cards[k]))
	var period := float(Look.RARITY_PULSE_SEC[rarity])
	if period <= 0.0:
		return 0.0
	return 0.5 + 0.5 * sin(TAU * _reveal_age / period)


## The art square inside card `k`'s DEALT box — it rides the slide with the card it belongs to.
func _art_rect(k: int) -> Rect2:
	var box := _card_box(k)
	return Rect2(box.position + _deal_offset_of(k) + Look.CARD_ART_OFFSET_PX, Look.CARD_ART_SIZE_PX)


## The legendary rays, as segment pairs for one `draw_multiline` — built HERE and handed over whole,
## the `_spark_points` split: built inside the leaf they never leave it, and the census skips
## 0-draw functions' arguments. Rays grow out from the card's edge over `LEGEND_BURST_SEC` of the
## card's own reveal window, so the burst arrives WITH its card, never before it.
func _burst_points(k: int) -> PackedVector2Array:
	var box := _card_box(k)
	box.position += _deal_offset_of(k)
	var centre := box.get_center()
	var grow := clampf((_reveal_age - float(k) * Look.MAP_REVEAL_STEP_SEC) / Look.LEGEND_BURST_SEC,
		0.0, 1.0)
	var out := PackedVector2Array()
	for i in Look.LEGEND_RAY_COUNT:
		var ang := TAU * float(i) / float(Look.LEGEND_RAY_COUNT)
		var dir := Vector2(cos(ang), sin(ang))
		# From the card's own edge outward: the box is a rectangle, so the edge distance along `dir`
		# is the smaller of the two half-extent crossings.
		var half := box.size * 0.5
		var edge := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		out.append(centre + dir * edge)
		out.append(centre + dir * (edge + Look.LEGEND_RAY_LEN_PX * grow))
	return out


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

	# The bursts first, in their own pass, so a legendary's rays sit BEHIND every card — one loop
	# later and a middle card's rays would lie on top of its left neighbour but under its right one.
	for k in Rules.CARDS_PER_WIN:
		if Rules.item_rarity_of(int(run.cards[k])) != Rules.Rarity.LEGENDARY:
			continue
		var burst_col: Color = Look.COL_RARITY_GLOW[Rules.Rarity.LEGENDARY]
		burst_col.a *= _reveal_alpha_of(k)
		_paint_legendary_burst(_burst_points(k), burst_col)

	for k in Rules.CARDS_PER_WIN:
		# ⚠⚠ **The reveal is the FILL's alpha alone, multiplied in — not a second colour.** The fill
		# already carries the pressable/taken/hover story on its own alpha; multiplying the reveal
		# factor on top is "not yet arrived" riding the exact channel "not yet pressable" already
		# uses, so the two never have to agree on a second rule about what a low alpha means. Every
		# mark below multiplies the same value in — a mark fully lit before its card arrives is the
		# exact failure the first-frame check shape catches.
		var reveal := _reveal_alpha_of(k)
		var box := _card_box(k)
		box.position += _deal_offset_of(k)
		var edge_width := lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX,
			_hover_of(k))
		var fill := _card_fill(k)
		fill.a *= reveal
		_paint_card(box, fill, edge_width)
		var item := int(run.cards[k])
		var rarity := Rules.item_rarity_of(item)
		# The rarity frame and its glow, over the card's own border — the ladder tables answer how
		# loud, and COMMON's 0-layer row means no call at all rather than an invisible one.
		var layers := int(Look.RARITY_GLOW_LAYERS[rarity])
		if layers > 0:
			var glow: Color = Look.COL_RARITY_GLOW[rarity]
			glow.a = float(Look.RARITY_GLOW_ALPHA[rarity]) \
				* (1.0 + _pulse_of(k) * float(Look.RARITY_PULSE_GAIN[rarity])) * reveal
			_paint_rarity_frame(box, glow, float(Look.RARITY_FRAME_WIDTH_PX[rarity]), layers)
		var art: Texture2D = _art[item]
		if art != null:
			var art_col := Look.COL_HUD_TEXT
			art_col.a *= reveal
			_paint_card_art(art, _art_rect(k), art_col)
		var name_col := Look.COL_HUD_TEXT
		name_col.a *= reveal
		_paint_card_name(face, box.position + Look.CARD_PART_OFFSET_PX,
			Rules.item_name_of(item), Look.CARD_PART_FONT_SIZE_PX, name_col)
		# The rarity is carried by the COLOUR of the effect line and by one word in front of it — a
		# tone alone cannot be told apart by a player who has seen two cards, and a word alone does not
		# catch the eye across a spread.
		var effect_col: Color = Look.COL_RARITY[rarity]
		effect_col.a *= reveal
		_paint_card_effect(face, box.position + Look.CARD_SPECIES_OFFSET_PX,
			"%s  %s" % [str(RARITY_LABELS[rarity]), Rules.item_effect_text(item)],
			Look.CARD_EFFECT_WRAP_W_PX, Look.CARD_SPECIES_FONT_SIZE_PX, effect_col)
		if int(run.cards_taken[k]) != 0:
			var mark := Look.COL_HUD_TEXT
			mark.a = Look.PRESS_ALPHA_ON * _taken_of(k)
			_paint_taken_mark(box.get_center(), Look.CARD_TAKEN_MARK_R_PX * _taken_of(k), mark)

	var hint := "%d / %d 골랐습니다" % [_picks_made(), Rules.CARD_PICKS]
	_paint_hint(face, Look.CARD_HINT_POS_PX, hint, Look.CARD_HINT_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	# The scene wash, last and over everything — `map_view`'s own shape, reused rather than a second
	# fade invented for this screen. Without it the reward screen is a hard cut with no arrival of its
	# own; the card stagger covers the CARDS, this covers the SCREEN they sit on.
	var wash := clampf(1.0 - _reveal_age / Look.SCENE_FADE_SEC, 0.0, 1.0)
	if wash > 0.0:
		_paint_fade(Rect2(Vector2.ZERO, Look.viewport_size_px()), Look.scene_fade_colour(wash))


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf's `_table()`, and every parameter is
# used in the body: a leaf that quietly drops one of its arguments is invisible on screen and green in
# the round.

func _paint_card(rect: Rect2, bg: Color, edge_width: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, Look.COL_HUD_TEXT, false, edge_width)


func _paint_card_art(tex: Texture2D, rect: Rect2, col: Color) -> void:
	draw_texture_rect(tex, rect, false, col)


## The frame and its glow in one leaf: layer 0 is the frame itself, each further layer the same
## stroke one width out and linearly fainter — the outermost keeps `1/layers` of the alpha, never
## zero — the glow IS the frame layered, not a second mark.
func _paint_rarity_frame(rect: Rect2, col: Color, width: float, layers: int) -> void:
	for i in layers:
		var layer_col := col
		layer_col.a *= 1.0 - float(i) / float(layers)
		draw_rect(rect.grow(width * float(i)), layer_col, false, width)


func _paint_legendary_burst(points: PackedVector2Array, col: Color) -> void:
	draw_multiline(points, col, Look.LEGEND_RAY_WIDTH_PX)


func _paint_card_name(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## A MULTILINE string, wrapped at `width` — the longest item line (폭풍의 가죽's) was measured
## clipping at the card border as a single `draw_string`, and word-wrap makes "no item can clip"
## true by construction instead of true of the items checked.
func _paint_card_effect(face: Font, at: Vector2, text: String, width: float, fsize: int,
		col: Color) -> void:
	draw_multiline_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, fsize, -1, col)


func _paint_taken_mark(centre: Vector2, radius: float, col: Color) -> void:
	draw_circle(centre, radius, col)


func _paint_hint(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_fade(rect: Rect2, col: Color) -> void:
	draw_rect(rect, col, true)
