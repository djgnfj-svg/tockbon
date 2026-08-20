class_name HudView
extends Node2D

## The heads-up layer: the clock, how many enemies are left, and **the start button**. Three things,
## and that is the whole of it.
##
## It READS `battle` and writes nothing back — src/view/ is a reader by contract, and a view that
## nudges the sim makes "the screen changed but the sim did not" indistinguishable from its inverse.
##
## Everything that reaches the screen goes through a `_paint_*` hook and `_draw()` calls nothing
## else. A spy can capture a hook's arguments; it cannot see a native `draw_string` sitting directly
## in `_draw`, which is how a bare draw call once shipped twice under a green round. net_draw_leaf
## pins each hook's `draw_*` count exactly AND reddens any function in this file it does not name,
## so a helper added tomorrow is red until it is listed — adding names only fixes the day it is done.
##
## ⚠ **The two berth boxes and the 1/2 key roster are gone, and so is the paragraph that explained
## them.** `plan-then-watch` reversed 결정 14: boats are unlimited and created by a drag, so there is
## no fleet to meter and no resource for a berth to draw down. The thing that visibly empties as the
## player plans is the stack of soldiers standing at the harbour, and `field_view` draws that.
##
## ⚠ **The 1/2 keys' BOXES are gone with them, and so is the speed ladder.** The hand does not move
## during combat: the whole landing is authored before the start button and then watched. This file
## carries exactly ONE press — `commit` — and once that press has landed nothing on this layer answers
## a click at all. `speed-off-open-landing`'s question A took the pause with the chips, and its own row
## records that this overturns `plan-then-watch`'s decided 4 and takes the instrument away from that
## decision's own metric.
##
## ⚠⚠ **THE KEYBOARD IS BACK, AND IT PRESSES NOTHING ON THIS LAYER** (`sea-summon`). Five summon slot
## boxes are drawn bottom right and 1~5 arm one of them — but the boxes themselves are **not clickable
## and have no hit rect at all**: what places a body is a press on the water. So the sentence above
## survives exactly as written, and this file still holds one press. The user corrected the record
## themselves: *"정확히는 배 속이 별로여서 뺀거임 1~5번키"* — the keys came out because of what was in
## the boat, not because a key is the wrong door.
## ⚠ The whole slot row lives inside the same `not battle.committed()` gate the start button does, and
## that is **seam #4 of `sea-summon`'s OPEN question 1**: the bar's denominator (living bodies of the
## slot's type) is only honest while nobody can die. Do not lift the gate without giving the bar a
## denominator recorded at island open.
##
## Enemies-left is drawn from `battle.enemies_left()` and survives onto the lose screen on purpose:
## "the timer ran out with four alive" is a different loss from a wipe, and the player has to be able
## to tell which one happened.
##
## Item 8 of combat-juice (press feedback) lives here, and it is the one effect the sim knows NOTHING
## about: `battle.commit()` already returns a bool the shell can push in rather than poll. The shell
## calls `note_chip` on every start press, whether the commit was accepted or refused.
## The clock is this node's own — see combat-juice, section B: `battle.step()` is skipped entirely
## while a panel is up, so an effect hung off sim time freezes behind the win screen.


## Display names, indexed by the type id in rules.gd. `Rules.name_of` returns the table's IDENTIFIER
## ("CELL_MELEE"), which is not text a player reads, and the user cannot read English at all.
## panel_view reads this through `HudView.type_label` rather than keeping a second copy — a table
## written down twice diverges.
##
## ⚠ **Nothing on the HUD reads it any more** — the roster strip it was written for is deleted. It
## survives because `panel_view` names soldiers in the reward list, which is the one place in the
## game a unit still has to be named in words.
const TYPE_LABELS := ["근접", "원거리", "들소", "까마귀", "사자"]

## `_chip_fx` slot ids. **The start button is 0 and the five summon boxes are 1..5**, so one drawer
## and one `_chip_offset` serve both — one concept, one value. Named rather than written as bare
## numbers at four call sites, because the shell has to key the same slots from the other side.
const CHIP_START := 0
const CHIP_SLOT_BASE := 1

var battle: Battle = null

## Which summon slot the shell has armed, or -1. **Written only by `set_armed`**, which `game.gd` calls
## from its own `_arm` / `_disarm` — the same two functions that tell `field_view` — so the HUD and the
## field can never disagree about which slot is live.
var _armed := -1

## Item 8's drawer. `slot -> {"sec": float, "ok": bool}`.
##
## A Dictionary keyed by the thing the effect is stuck to, and NOT a flat list of effects: mashing
## the same button twice can then only reset the age, never stack two stains that multiply into a
## solid block. combat-juice, section B, picks the same shape for field_view's per-body drawer and
## for the same reason — stacking is made impossible by the container instead of by code that
## remembers. **Slot `CHIP_START` is the start button and `CHIP_SLOT_BASE + i` is summon slot `i`** —
## six slots, and the drawer would keep its dictionary shape at one, because the anti-stacking property
## is the reason it is a dictionary and the number of slots never was.
## ⚠ A held summon on a dry slot pushes one refusal PER BEAT and not per frame — `game.gd` owns that
## rate; a mark fired every frame is a solid disc rather than a blink.
var _chip_fx: Dictionary = {}

## Resolved once and kept, and STATIC because panel_view needs the same face — the explanation for
## picking it lives here only, in one file, rather than in both view files.
## `ThemeDB` is available untreed and headless: "there is no font outside the tree" was measured
## wrong twice, and the real cause was a script that quit before turning a single frame.
static var _face: Font = null


## The project's own default font carries Hangul; the engine's fallback need not, and a missing
## glyph is SILENT — every Korean label would come out as boxes with the whole round still green.
static func default_font() -> Font:
	if _face != null:
		return _face
	var theme := ThemeDB.get_default_theme()
	if theme != null and theme.default_font != null:
		_face = theme.default_font
	else:
		_face = ThemeDB.fallback_font
	return _face


static func type_label(type_id: int) -> String:
	return str(TYPE_LABELS[type_id])


func bind(b: Battle) -> void:
	battle = b
	# Island 2 must not open still wearing island 1's feedback. combat-juice pins the clearing on
	# every `setup` / `bind` precisely because nothing else in the frame would ever notice.
	_chip_fx.clear()
	# Same argument, one field over: a slot armed on island 1 must not be drawn armed on island 2.
	_armed = -1
	queue_redraw()


## The shell's one call, from `game.gd::_arm` and `_disarm`. -1 is "nothing armed".
func set_armed(slot: int) -> void:
	_armed = slot
	queue_redraw()


## ⚠ **Aged by the bare frame delta.** `set_speed` is deleted with the ladder, and with no multiplier
## the only honest scale is 1.0 — handing a leaf a constant 1.0 is the shape 「No fake code」 names, so
## the multiply is removed rather than pinned. Every duration in `look.gd` is budgeted against real
## seconds again, which is where they were written.
func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


## The shell hands over the bool `battle.commit()` already returns. Swink's Game Feel puts the
## input→response budget for real-time controls under 100ms; this lands on the SAME frame the press
## happened, because Godot runs input before `_process` and `_process` queues the redraw.
##
## Slot `CHIP_START` is the start button and `CHIP_SLOT_BASE + i` is summon slot `i`. **The name was
## generic before the second caller existed and now it has five of them** — each one needs its own
## rect, which is what `_chip_offset`'s caller reads.
func note_chip(slot: int, ok: bool) -> void:
	if slot < 0:
		return
	_chip_fx[slot] = {"sec": Look.CHIP_FX_SEC, "ok": ok}


## Ages the drawer and drops what has run out. `keys()` hands back a copy, so erasing inside the
## loop is safe; iterating the dictionary itself while erasing is not.
func _fx_step(delta: float) -> void:
	for slot in _chip_fx.keys():
		var fx: Dictionary = _chip_fx[slot]
		var left := float(fx["sec"]) - delta
		if left <= 0.0:
			_chip_fx.erase(slot)
		else:
			fx["sec"] = left


## The refuse shake, in canvas px, along x only. An ACCEPTED press does not move — it only brightens;
## moving both would make the two answers tell the player the same thing.
##
## A decaying cosine and not a random jitter: random cannot be measured by a net, and this repo has
## already paid for that once. It starts at its MAXIMUM rather than at zero, which is the half that
## matters — a headless frame is 6.9ms, so a shake shaped like `sin` would be under one canvas pixel
## on the first frame after the press and read as nothing at all. One full cycle over `CHIP_FX_SEC`
## with a linear decay ends at exactly zero, so the button never stays displaced.
##
## ⚠ **This is `REFUSE_SHAKE_PX`'s only reader.** `_berth_offset` was the second one and it died with
## the berths, so deleting this function deletes that constant's last reader — which is why the
## amplitude is pinned at BOTH ends (it is never 0 on the frame of a refusal, and it never exceeds
## `REFUSE_SHAKE_PX`) rather than only above.
func _chip_offset(slot: int) -> Vector2:
	if not _chip_fx.has(slot):
		return Vector2.ZERO
	var fx: Dictionary = _chip_fx[slot]
	if bool(fx["ok"]):
		return Vector2.ZERO
	var p := clampf(1.0 - float(fx["sec"]) / Look.CHIP_FX_SEC, 0.0, 1.0)
	var amp := Look.REFUSE_SHAKE_PX * (1.0 - p) * Look.fx_gain_of(8)
	return Vector2(amp * cos(p * TAU), 0.0)


## The start button's background: `COL_START` at rest, pulled all the way to `COL_WIN` or `COL_LOSE`
## on the frame of the press and easing back over `CHIP_FX_SEC`. Gain 0 collapses the whole lerp to
## `COL_START` — that is what combat-juice's `FX_GAIN[8]` row measures.
func _chip_colour(slot: int) -> Color:
	return _chip_tint(Look.COL_START, slot)


## ⚠⚠ **THE COLOUR HALF OF ITEM 8, AND IT WAS ONLY WIRED TO THE START BUTTON.** `_chip_offset` served
## both the start button and the five slot boxes from the day the slots shipped — one shake, one
## concept, one value — while the tint was written inline in `_chip_colour` and reached nothing else.
## So **a refused number key shook and never flashed**: one channel where the design asked for two,
## and the box that barked looked exactly like the box that did not.
##
## Pulled out here so both callers read the same lerp off the same drawer. `rest` is the caller's own
## resting tone, because the start button rests on `COL_START` and a slot rests on one of three tones —
## folding that choice in here would put `_slot_colour`'s table in two places.
## Gain 0 collapses the lerp to `rest`, which is what `combat-juice`'s `FX_GAIN[8]` row measures.
func _chip_tint(rest: Color, slot: int) -> Color:
	if not _chip_fx.has(slot):
		return rest
	var fx: Dictionary = _chip_fx[slot]
	var p := clampf(1.0 - float(fx["sec"]) / Look.CHIP_FX_SEC, 0.0, 1.0)
	var goal: Color = Look.COL_WIN if bool(fx["ok"]) else Look.COL_LOSE
	return rest.lerp(goal, (1.0 - p) * Look.fx_gain_of(8))


func _draw() -> void:
	if battle == null:
		return
	var face := default_font()
	if face == null:
		return

	# 「시간 %.1f」 and not 「남은 시간 %.1f」 — one word instead of two. The user's own instruction was
	# 「글자가 너무 많고 조금 더 단순하게 해줄래? 아니면 좀 UI를 크게 해서」, and this file answers both
	# halves: three text items during a fight instead of six, each of them drawn bigger.
	_paint_timer(face, Look.HUD_TIMER_POS_PX, "시간 %.1f" % battle.time_left(),
		Look.HUD_TIMER_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	# The start button, and ONLY while the plan can still be started. A button that cannot be pressed
	# and is still drawn is the "well, while we're stopped…" door `plan-then-watch` closes on purpose.
	# ⚠ **The moment `committed()` is true this layer draws no pressable thing at all** — the speed row
	# that used to survive the commit is deleted, so a committed fight has nothing the hand can press.
	#
	# The shake rides on `rect.position`, and the label's `at` is derived FROM the shifted rect rather
	# than from the resting one. Shaking the box alone walks the glyphs out of it; shaking the glyphs
	# alone leaves the box still and reads as nothing moving — combat-juice, item 8.
	if not battle.committed():
		var srect := Look.start_rect_px()
		srect.position += _chip_offset(CHIP_START)
		_paint_button(face, srect, _chip_colour(CHIP_START), "시작",
			srect.position + Look.HUD_START_TEXT_OFFSET_PX,
			Look.HUD_START_FONT_SIZE_PX, Look.COL_HUD_TEXT)

		# --- the five summon slots (sea-summon) ---------------------------------------------------
		# ⚠ **Inside the SAME gate the start button is**, and that is seam #4 of OPEN question 1 — see
		# this file's header. Nobody dies during planning, so the bar's denominator cannot move under
		# its numerator; during a fight it could, and the bar would climb.
		for i in Rules.summon_slot_count():
			# ⚠ **The shake rides `rect.position` AND the glyph's `at` is derived from the SHIFTED
			# rect.** Shake the box alone and the digit walks out of it; shake the digit alone and it
			# reads as nothing having moved — combat-juice item 8, the same as the start button above.
			var shake := _chip_offset(CHIP_SLOT_BASE + i)
			var box := Look.slot_rect_px(i)
			box.position += shake
			# Two channels — fill AND border — so neither one carries the read of "this is the armed
			# slot" alone. The pair's own inequality (`> PRESS_BORDER_WIDTH_PX + 2`, the snap floor) is
			# what makes the thicker border reach the screen at all.
			_paint_slot_box(box, _slot_colour(i), Look.COL_HUD_TEXT,
				Look.PRESS_HOVER_BORDER_WIDTH_PX if i == _armed else Look.PRESS_BORDER_WIDTH_PX)
			_paint_slot_digit(face, box.position + Look.HUD_SLOT_TEXT_OFFSET_PX, str(i + 1),
				Look.HUD_SLOT_FONT_SIZE_PX, Look.COL_HUD_TEXT)
			# **An unbound slot draws NO bar; a slot whose bodies are all out draws an empty rail.**
			# That rail is the only thing separating 「다 내보냈다」 from 「아직 아무것도 안 넣었다」.
			var want := Rules.summon_type_of(i)
			if want < 0:
				continue
			var rail := Look.slot_bar_rect_px(i)
			rail.position += shake
			var pool := 0
			if battle.army != null:
				pool = battle.army.living_ids_of_slot(i).size()
			var left := battle.slot_reserve_ids(i).size()
			var frac := 0.0 if pool <= 0 else clampf(float(left) / float(pool), 0.0, 1.0)
			_paint_slot_bar(rail, Look.COL_HP_EMPTY,
				Rect2(rail.position, Vector2(rail.size.x * frac, rail.size.y)), Look.COL_ALLY)

	_paint_enemies_left(face, Look.HUD_ENEMIES_LEFT_POS_PX, "적 %d" % battle.enemies_left(),
		Look.HUD_FONT_SIZE_PX, Look.COL_HUD_TEXT)


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf; the table is that file's `_table()`.
# Every parameter must be used in the body: a leaf handed a value it drops turned forty rocks
# invisible with the round green.

func _paint_timer(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## 2 calls: the filled rectangle, then its label. Renamed from `_paint_key` rather than deleted —
## the 1/2 key boxes are gone but the SHAPE they drew (a pressable box with one word in it) is what
## the start button is. ⚠ **The start button is now its ONLY call site**, the five speed chips having
## been the other five; the hook stays a hook because `_draw` calling `draw_rect` directly is the bare
## draw call `net_draw_leaf` exists to redden.
func _paint_button(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_enemies_left(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## What a summon slot's box is filled with. **0 draws.** Three states and three tones:
## armed -> `COL_START` (the same green the one press that ends planning wears, because arming is the
## verb that leads to it) · bound and holding bodies -> `COL_BUTTON` · unbound or all bodies out ->
## `COL_SLOT_OFF`, which already means *a slot that does not press* on the title screen.
##
## ⚠ Unbound and exhausted are ONE tone on purpose. They are the same sentence to the player — 「지금
## 여기서는 아무것도 안 나온다」 — and what tells them apart is the bar underneath: an exhausted slot
## has an empty rail and an unbound one has no rail at all.
##
## ⚠⚠ **EMPTY IS TESTED BEFORE ARMED, and the order was the other way round.** A slot armed with one
## body left goes dry the moment that body is summoned, and while `armed` won the box **stayed
## `COL_START` — reading 「ready」 for a key that will now bark.** The fill says what will come out; the
## BORDER says which slot the key is on (`PRESS_HOVER_BORDER_WIDTH_PX` in `_draw`), and this file's own
## paragraph up there already says neither channel carries that read alone. So an armed dry slot is
## grey with a thick border, which is both facts at once.
##
## ⚠ **The tint rides on top of whichever tone was chosen.** A refused key flashes toward `COL_LOSE`
## from its own resting colour — see `_chip_tint`, which the start button has used since item 8 shipped
## and the slot boxes did not.
func _slot_colour(slot: int) -> Color:
	var rest := Look.COL_BUTTON
	if battle == null or battle.slot_reserve_ids(slot).is_empty():
		rest = Look.COL_SLOT_OFF
	elif slot == _armed:
		rest = Look.COL_START
	return _chip_tint(rest, CHIP_SLOT_BASE + slot)


## 2 calls: the fill, then the border that says which slot is live. One hook and not two — a box
## without its border is the same box saying something else, not a second thing to draw. `border_w` is
## an ARGUMENT rather than read from `look.gd` in here, so a spy can bite the armed/resting difference.
func _paint_slot_box(rect: Rect2, bg: Color, border_col: Color, border_w: float) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, border_col, false, border_w)


## 1 call. The single digit that names the key which arms this slot.
func _paint_slot_digit(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## 2 calls: the empty rail, then the filled part on top of it — the same two-rect shape `_paint_hp`
## uses, and the empty half is drawn for the same reason. A bar only ever as long as what is left has
## no length to lose, and 「nothing on screen ever went down」 is half of why the last game died.
func _paint_slot_bar(back: Rect2, back_col: Color, fill: Rect2, fill_col: Color) -> void:
	draw_rect(back, back_col)
	draw_rect(fill, fill_col)
