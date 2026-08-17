class_name HudView
extends Node2D

## The heads-up layer: the clock, the two berths, how many are loaded, the 1/2 key roster, and how
## many enemies are left.
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
## The berth rectangle IS the resource meter. A boat at sea leaves its berth drawn empty, so the
## restriction is the picture rather than a number beside one — see cell-army-gdd, section Screen.
## Replacing it with a readout deletes the one thing v2-openfield died for the want of: something on
## screen that visibly goes down.
##
## Enemies-left is drawn from `battle.enemies_left()` and survives onto the lose screen on purpose:
## "the timer ran out with four alive" is a different loss from a wipe, and the player has to be able
## to tell which one happened.
##
## Item 8 of combat-juice (summon feedback) lives here, and it is the one effect the sim knows
## NOTHING about: `battle.load_soldier` and `battle.launch` already return a bool and the shell used
## to throw it away. The shell pushes it in through `note_key` / `note_launch`; nothing is polled.
## The clock is this node's own — see combat-juice, section B: `battle.step()` is skipped entirely
## while a panel is up, so an effect hung off sim time freezes behind the win screen.


## Display names, indexed by the type id in rules.gd. `Rules.name_of` returns the table's IDENTIFIER
## ("CELL_MELEE"), which is not text a player reads, and the user cannot read English at all.
## panel_view reads this through `HudView.type_label` rather than keeping a second copy — a table
## written down twice diverges.
const TYPE_LABELS := ["근접", "원거리", "들소", "까마귀", "사자"]

## The summonable types in hotkey order: slot 0 is key `1`. The shell binds the keys from this same
## array, so a third soldier type appears on screen and on the keyboard in one edit.
const KEY_TYPES := [Rules.CELL_MELEE, Rules.CELL_RANGED]

var battle: Battle = null

## Item 8's two drawers. `_key_fx` is `slot -> {"sec": float, "ok": bool}`, `_berth_fx` is
## `berth -> {"sec": float, "ok": bool}`.
##
## Dictionaries keyed by the thing the effect is stuck to, and NOT a flat list of effects: mashing
## the same key twice can then only reset the age, never stack two stains that multiply into a solid
## block. combat-juice, section B, picks the same shape for field_view's per-body drawer and for the
## same reason — stacking is made impossible by the container instead of by code that remembers.
## Nothing here can grow past the key count or the berth count, so no cap is needed either.
var _key_fx: Dictionary = {}
var _berth_fx: Dictionary = {}

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


static func key_slot_count() -> int:
	return KEY_TYPES.size()


static func key_type_of(slot: int) -> int:
	return int(KEY_TYPES[slot])


func bind(b: Battle) -> void:
	battle = b
	# Island 2 must not open still wearing island 1's feedback. combat-juice pins the clearing on
	# every `setup` / `bind` precisely because nothing else in the frame would ever notice.
	_key_fx.clear()
	_berth_fx.clear()
	queue_redraw()


## Living soldiers of `type_id` that have not been put on a boat yet, i.e. the ones a `1` or `2`
## press could still load. RESERVE only: a soldier already ashore cannot be re-boarded, so counting
## it here would advertise a load that `battle.load_soldier` refuses.
func reserve_count(type_id: int) -> int:
	if battle == null or battle.army == null:
		return 0
	var a := battle.army
	var n := 0
	for i in a.type_id.size():
		if a.alive[i] == 0:
			continue
		if a.type_id[i] != type_id:
			continue
		if i < battle.soldier_state.size() \
				and battle.soldier_state[i] == Battle.SoldierState.RESERVE:
			n += 1
	return n


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


## The shell hands over the bool `battle.load_soldier` already returns. Swink's Game Feel puts the
## input→response budget for real-time controls under 100ms; this lands on the SAME frame the key was
## pressed, because Godot runs input before `_process` and `_process` queues the redraw.
func note_key(slot: int, ok: bool) -> void:
	if slot < 0 or slot >= KEY_TYPES.size():
		return
	_key_fx[slot] = {"sec": Look.KEY_FX_SEC, "ok": ok}


## The same, for a dock click. The parameter is the DOCK the shell clicked, but the picture is on the
## berth, because the berth rectangle is this screen's resource meter.
##
## `battle.launch` picks the berth itself and returns only a bool, so the berth it just took is read
## back rather than plumbed out: `launch` sets that berth's timer to a full crossing on this very
## frame while every other berth has already been counted down, so the highest one is it. A refusal
## takes no berth at all — the fleet as a whole is what said no — so every berth answers.
func note_launch(dock: int, ok: bool) -> void:
	if battle == null or dock < 0 or dock >= battle.dock_count():
		return
	if not ok:
		for b in battle.berth_free_in.size():
			_berth_fx[b] = {"sec": Look.BERTH_FX_SEC, "ok": false}
		return
	var taken := -1
	var longest := -1.0
	for b in battle.berth_free_in.size():
		if battle.berth_free_in[b] > longest:
			longest = battle.berth_free_in[b]
			taken = b
	if taken < 0:
		return
	_berth_fx[taken] = {"sec": Look.BERTH_FX_SEC, "ok": true}


## Ages both drawers and drops what has run out. `keys()` hands back a copy, so erasing inside the
## loop is safe; iterating the dictionary itself while erasing is not.
func _fx_step(delta: float) -> void:
	for slot in _key_fx.keys():
		var fx: Dictionary = _key_fx[slot]
		var left := float(fx["sec"]) - delta
		if left <= 0.0:
			_key_fx.erase(slot)
		else:
			fx["sec"] = left
	for b in _berth_fx.keys():
		var bfx: Dictionary = _berth_fx[b]
		var bleft := float(bfx["sec"]) - delta
		if bleft <= 0.0:
			_berth_fx.erase(b)
		else:
			bfx["sec"] = bleft


## The refuse shake, in canvas px, along x only. An ACCEPTED press does not move — it only brightens;
## moving both would make the two answers tell the player the same thing.
##
## A decaying cosine and not a random jitter: random cannot be measured by a net, and this repo has
## already paid for that once. It starts at its MAXIMUM rather than at zero, which is the half that
## matters — a headless frame is 6.9ms, so a shake shaped like `sin` would be under one canvas pixel
## on the first frame after the press and read as nothing at all. One full cycle over `KEY_FX_SEC`
## with a linear decay ends at exactly zero, so the box never stays displaced.
func _key_offset(slot: int) -> Vector2:
	if not _key_fx.has(slot):
		return Vector2.ZERO
	var fx: Dictionary = _key_fx[slot]
	if bool(fx["ok"]):
		return Vector2.ZERO
	var p := clampf(1.0 - float(fx["sec"]) / Look.KEY_FX_SEC, 0.0, 1.0)
	var amp := Look.KEY_REFUSE_SHAKE_PX * (1.0 - p) * Look.fx_gain_of(8)
	return Vector2(amp * cos(p * TAU), 0.0)


## The key box's background: `COL_BUTTON` at rest, pulled all the way to `COL_WIN` or `COL_LOSE` on
## the frame of the press and easing back over `KEY_FX_SEC`. Gain 0 collapses the whole lerp to
## `COL_BUTTON` — that is what combat-juice's `FX_GAIN[8]` row measures.
func _key_colour(slot: int) -> Color:
	if not _key_fx.has(slot):
		return Look.COL_BUTTON
	var fx: Dictionary = _key_fx[slot]
	var p := clampf(1.0 - float(fx["sec"]) / Look.KEY_FX_SEC, 0.0, 1.0)
	var goal: Color = Look.COL_WIN if bool(fx["ok"]) else Look.COL_LOSE
	return Look.COL_BUTTON.lerp(goal, (1.0 - p) * Look.fx_gain_of(8))


func _draw() -> void:
	if battle == null:
		return
	var face := default_font()
	if face == null:
		return

	_paint_timer(face, Look.HUD_TIMER_POS_PX, "남은 시간 %.1f" % battle.time_left(),
		Look.HUD_TIMER_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	# The berth's own two states stay the base colour; item 8 only tints on top of whichever one is
	# showing, so "a boat is at sea" is never overwritten by "that click landed".
	for b in battle.berth_free_in.size():
		var free := battle.berth_free_in[b] <= 0.0
		var berth_col: Color = Look.COL_BOAT if free else Look.COL_BERTH_EMPTY
		if _berth_fx.has(b):
			var bfx: Dictionary = _berth_fx[b]
			var bp := clampf(1.0 - float(bfx["sec"]) / Look.BERTH_FX_SEC, 0.0, 1.0)
			var bgoal: Color = Look.COL_WIN if bool(bfx["ok"]) else Look.COL_LOSE
			berth_col = berth_col.lerp(bgoal, (1.0 - bp) * Look.fx_gain_of(8))
		_paint_berth(Look.berth_rect_px(b), berth_col)

	_paint_load(face, Look.HUD_LOAD_POS_PX,
		"탑승 %d/%d" % [battle.pending.size(), Rules.CAP],
		Look.HUD_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	# The shake rides on `rect.position`, and the label's `at` is derived FROM the shifted rect rather
	# than from the resting one. Shaking the box alone walks the glyphs out of it; shaking the glyphs
	# alone leaves the box still and reads as nothing moving — combat-juice, item 8.
	for slot in KEY_TYPES.size():
		var t := key_type_of(slot)
		var rect := Look.key_rect_px(slot)
		rect.position += _key_offset(slot)
		_paint_key(face, rect, _key_colour(slot),
			"%d  %s  %d" % [slot + 1, type_label(t), reserve_count(t)],
			rect.position + Look.HUD_KEY_TEXT_OFFSET_PX,
			Look.HUD_FONT_SIZE_PX, Look.COL_HUD_TEXT)

	_paint_enemies_left(face, Look.HUD_ENEMIES_LEFT_POS_PX, "적 %d" % battle.enemies_left(),
		Look.HUD_FONT_SIZE_PX, Look.COL_HUD_TEXT)


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf; the table is in first-slice, under
# "The view". Every parameter must be used in the body: a leaf handed a value it drops turned forty
# rocks invisible with the round green.

func _paint_timer(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_berth(rect: Rect2, col: Color) -> void:
	draw_rect(rect, col, true)


func _paint_load(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_key(face: Font, rect: Rect2, bg: Color, text: String, at: Vector2, fsize: int,
		col: Color) -> void:
	draw_rect(rect, bg, true)
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_enemies_left(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
