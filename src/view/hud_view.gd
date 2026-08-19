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
## ⚠ **The 1/2 keys are gone with them, and so is the speed ladder.** The hand does not move during
## combat: the whole landing is authored before the start button and then watched. This file
## therefore carries exactly ONE press — `commit` — and once that press has landed nothing on this
## layer answers a click at all. `speed-off-open-landing`'s question A took the pause with the chips,
## and its own row records that this overturns `plan-then-watch`'s decided 4 and takes the instrument
## away from that decision's own metric.
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

var battle: Battle = null

## Item 8's drawer. `slot -> {"sec": float, "ok": bool}`.
##
## A Dictionary keyed by the thing the effect is stuck to, and NOT a flat list of effects: mashing
## the same button twice can then only reset the age, never stack two stains that multiply into a
## solid block. combat-juice, section B, picks the same shape for field_view's per-body drawer and
## for the same reason — stacking is made impossible by the container instead of by code that
## remembers. **Slot 0 is the start button and it is the only slot there is**, now that the speed
## chips are gone; the drawer keeps its dictionary shape because the anti-stacking property is the
## reason it is a dictionary, not the number of slots.
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
## Slot 0 is the start button. The name is generic because the drawer is, not because a second
## caller exists — and a second caller would need a second rect, which `_chip_offset` reads.
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
	if not _chip_fx.has(slot):
		return Look.COL_START
	var fx: Dictionary = _chip_fx[slot]
	var p := clampf(1.0 - float(fx["sec"]) / Look.CHIP_FX_SEC, 0.0, 1.0)
	var goal: Color = Look.COL_WIN if bool(fx["ok"]) else Look.COL_LOSE
	return Look.COL_START.lerp(goal, (1.0 - p) * Look.fx_gain_of(8))


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
		srect.position += _chip_offset(0)
		_paint_button(face, srect, _chip_colour(0), "시작",
			srect.position + Look.HUD_START_TEXT_OFFSET_PX,
			Look.HUD_START_FONT_SIZE_PX, Look.COL_HUD_TEXT)

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
