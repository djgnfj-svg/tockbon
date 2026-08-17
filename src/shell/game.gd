class_name Game
extends Node2D
## The shell. **The only file in the tree that reads an input event**, and the only one that wires the
## sim to the views.
##
## It builds its three children in code inside `_ready()` and never from the scene file, so a net that
## calls `_ready()` on an untreed instance exercises the real wiring. A child parked in `game.tscn`
## instead would let the line that creates it be deleted with every check still green — the same shape
## as pre-setting an `@onready` field from a net, which CLAUDE.md forbids for the same reason.
##
## Nothing here is `@onready` and nothing here is `@export`: every field below is assigned by `_ready`
## or by `_open_island`, so there is no path where the engine fills one in and the wiring is not run.
##
## Draw order is tree order for `Node2D` siblings, so the three children are added field -> hud ->
## panel and the panel lands on top. That is the whole of the layering; there is no `CanvasLayer`.
##
## See the first-slice plan, section "The shell", for the input table this file implements.


## Session state. Built once in `_ready` and **mutated in place** by `Run.restart()`, so this
## reference stays valid for the life of the node.
var run: Run = null

## The island being fought, or the last island fought once it is over. **It is deliberately not
## cleared when an island ends**: on the reward pick, the win and the loss the field stays on screen
## behind the panel, and the loss screen has to keep showing enemies-left to say *why* it was lost.
var battle: Battle = null

var field_view: FieldView = null
var hud_view: HudView = null
var panel_view: PanelView = null

## True while a left-button drag on the FIELD (not the panel, not a boat) is moving the camera.
## Mutually exclusive with `_drag_boat` below — a press grabs a boat XOR begins a pan, never both
## (`boat-and-landing`, section 6).
var _panning := false

## The boat a left-drag is currently sending, or -1. Set by `_on_left_press` when the press landed on
## a loaded, at-harbour boat (its hull on the map, or its HUD berth icon — two grab targets that read
## as one control, `boat-and-landing` section 6, decided #8), cleared by `_on_left_release` or by the
## hold guard below.
var _drag_boat := -1

## Seconds the shell is standing still, holding a moment on screen before it walks the run forward.
## Two things ride it — the verdict pause and the beak stain — and they never overlap, because a hold
## does not call `step` and so cannot see a second outcome, and `_release_hold` moves the state on the
## frame it expires. `combat-juice`, items "승패 전환" and "부리 부착".
##
## **Declared with an explicit type and not `:= 0.0` on purpose.** `net_draw_leaf`'s literal scan
## reads `src/shell/` as well, and a bare `_hold_sec := <number>` is exactly the shape it is widened
## to catch — the shape that would let the 0.8 be hardcoded here instead of read from `look.gd`. The
## zero is a "nothing is held" sentinel, not a duration, and it is written so the scan can keep
## biting the duration.
var _hold_sec: float = 0.0

## The soldier the beak is destined for while the panel is still showing him being picked, or -1.
## **The sim does not know yet**: `run.apply_beak` is called by `_release_hold` and not by the click,
## which is what buys item 9 a frame to play in. `combat-juice` explains in its "부리 부착" box why
## delaying the CALL is the fix and editing `run.gd` is not.
var _pending_beak := -1


func _ready() -> void:
	field_view = FieldView.new()
	hud_view = HudView.new()
	panel_view = PanelView.new()
	add_child(field_view)
	add_child(hud_view)
	add_child(panel_view)

	run = Run.new()
	_open_island()


## Opens the island `run` is standing on and re-points all three views at it.
##
## `Run.begin_island()` returns null during a reward pick and once the run is over, and this leaves
## `battle` alone in that case rather than nulling it — see `battle` above for why the last island has
## to stay drawable. The views are still re-bound, because the panel reads `run.state()` and has to
## learn that the island it is sitting on top of is finished.
func _open_island() -> void:
	# A drag in flight on the island that just ended must not survive onto the one that just opened —
	# its boat id would now name a stranger on the new island's fleet. Cleared unconditionally, not
	# only when a new island actually opens: a REWARD transition (`opened == null`) still has to drop
	# a drag that was in flight when the panel came up.
	_drag_boat = -1
	field_view.set_drag(-1, -1)
	var opened := run.begin_island()
	if opened != null:
		battle = opened
		# A fresh `Grid` and a fresh `Battle` per island, but the SAME `Army` — that is how HP and the
		# beak carry across islands. The army handed to the field is `run.army`, the same object
		# `begin_island` just gave the battle; rebuilding it anywhere would heal the run between
		# islands while a check that only counted soldiers stayed green.
		#
		# The field is handed the island's legend ROWS as well, because `grid.passable` is one byte and
		# water and a hole are both 0 in it: coloured from passability alone the sea and the pits come
		# out the same tone and the map reads as one shape.
		#
		# The rows are read with `run.island_index` straight after `begin_island`, which does not
		# advance it. Taking them from anywhere else would let the field draw one island's terrain
		# under another island's units, and both halves would look plausible.
		field_view.setup(battle, run.army, Islands.rows_of(run.island_index))
		hud_view.bind(battle)
	panel_view.bind(run, battle)


## Closes the island that just finished and walks the run forward.
##
## Island 1's reward has nothing to click, so `finish_island` applies it and leaves the run in
## `BATTLE` on the next island — which is why this re-opens unconditionally instead of waiting for a
## click. Without it `_process` would keep stepping a battle whose outcome has already latched, and
## the screen would sit on a won island forever.
func _close_island() -> void:
	run.finish_island(battle.outcome() == Battle.Outcome.WON)
	_open_island()


## `battle.step(delta)` is called here and **nowhere else**. The three views only ever call
## `queue_redraw` in their own `_process`, so the shell does not repeat it: a redraw asked for twice a
## frame is the same picture, and the same instruction living in two files is what diverges.
##
## **`begin_frame()` sits directly under the null check and above everything else**, which is the one
## position `combat-juice` allows it in its "사건이 sim 에서 뷰로 건너오는 길" section. Higher and it
## dereferences a null `battle` on the frames this returns early; lower and either a hold or a
## finished run skips it, and `events` then grows for the rest of the run with nothing on screen
## saying so. There is deliberately no cap on that array — this call is the price of not having one.
##
## **That is also the whole of how events reach the view.** Godot processes a parent before its
## children, and the three views are this node's children, so the order inside one frame is: clear,
## fill (`step`), then each view drains `battle.events` in its own `_process`. Nothing is pushed from
## here; a push would be a second copy of the same list.
##
## Nothing steps during a hold. That is what makes the hold a hold — the last frame of the fight
## stays on screen, its death rings and shards keep aging on the views' own clocks, and the sim's
## clock (which is also the loss condition) does not advance while nobody is playing.
func _process(delta: float) -> void:
	if run == null or battle == null:
		return
	battle.begin_frame()
	if _hold_sec > 0.0:
		_hold_sec = maxf(0.0, _hold_sec - delta)
		if _hold_sec <= 0.0:
			_release_hold()
		return
	if run.state() != Run.State.BATTLE:
		return
	battle.step(delta)
	if battle.outcome() != Battle.Outcome.RUNNING:
		# This REPLACES the old immediate `_close_island()`. Without the pause the last enemy's death
		# ring never gets a frame: the verdict and the next island's `setup()` landed inside one frame,
		# and `setup()` empties the view's effect drawers.
		_hold_sec = Look.HOLD_OUTCOME_SEC


## What the shell does when a hold runs out: bolt on the beak the panel has been showing, or close the
## island that was left standing on screen. The beak branch is checked first because it is the only
## one that can be pending — an outcome hold cannot start while a beak hold is running, since a hold
## does not step and only a step can latch an outcome.
func _release_hold() -> void:
	if _pending_beak >= 0:
		run.apply_beak(_pending_beak)
		_pending_beak = -1
		_open_island()
		return
	_close_island()


# --- input ----------------------------------------------------------------------------------------

## `_unhandled_input` and not `_input`, and a raw `InputEvent` and not an `InputMap` action: a net
## drives this by building the event and calling this method, so what is measured is the shell rather
## than `project.godot`. There is no `[input]` section in that file for the same reason.
func _unhandled_input(event: InputEvent) -> void:
	if run == null:
		return
	# One line closes the door on all three inputs during a hold, instead of three state tests spread
	# across the handlers below. It has to be here and not in them: during an outcome hold
	# `finish_island` has not run yet, so `run.state()` is still BATTLE and every guard downstream
	# waves the press through — 1/2 would keep boarding soldiers onto a won island, and a pan or a
	# zoom started into a sim that is not stepping would leave the camera moving over a frozen frame.
	#
	# ⚠ A drag in flight is CANCELLED here, not merely suppressed: `_panning` and `_drag_boat` are
	# cleared on every event that arrives while a hold is active, not just left alone. Without this
	# line the hold only blocks the MOTION events that would have kept panning or dragging — the flag
	# itself survives the hold, and once it ends with the mouse button still down, the very next
	# motion resumes the gesture the plan says must have been cancelled.
	if _hold_sec > 0.0:
		_panning = false
		_drag_boat = -1
		field_view.set_drag(-1, -1)
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		# A physical-only event carries keycode 0. Reading `keycode` alone loses every press the engine
		# could not resolve to a layout, and it loses it silently — the key simply does nothing.
		var code := key.keycode
		if code == 0:
			code = key.physical_keycode
		_on_key(code)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			_on_wheel(click.position, Look.ZOOM_STEP)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			_on_wheel(click.position, 1.0 / Look.ZOOM_STEP)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_on_left_press(click.position)
			else:
				_on_left_release(click.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# The panel is asked here too, and not only on press: a drag begun on the field before the
		# panel opened must not keep panning (or sending) behind it once it does — `panel_active()`
		# becoming true mid-drag is what `_on_left_press` alone cannot catch.
		if panel_view.panel_active():
			return
		if _drag_boat >= 0:
			# The overlay's candidate tile tracks the cursor; `battle.launch` is not called until the
			# release, so a drag that never releases over land never touches the sim at all.
			field_view.set_drag(_drag_boat, _tile_at(motion.position))
		elif _panning:
			field_view.pan_by(motion.relative)


## `1` and `2` load the highest-HP living soldier of that type **still in reserve** onto the boat that
## has not sailed. `Battle.load_soldier` owns that choice; nothing about who boards is decided here.
##
## Which type a key means comes from `HudView.KEY_TYPES`, because the HUD is what draws that roster on
## screen. A second list written here would let the keyboard offer a type the screen does not, or
## silently reorder the two against each other, and neither side would bark.
func _on_key(code: int) -> void:
	if battle == null or run.state() != Run.State.BATTLE:
		return
	var slot := code - KEY_1
	if slot < 0 or slot >= HudView.key_slot_count():
		return
	# The bool is handed to the HUD and not dropped. It is the ONLY thing that separates "that key did
	# nothing because the boat is full" from "that key did nothing because the game is not listening",
	# and the shell is the only place both facts exist at once. Refusals are not told apart by reason:
	# a bool cannot carry three, and widening it to an enum would move existing checks in two nets for
	# a distinction the screen does not draw. `combat-juice`, item "소환 피드백".
	#
	# `load_soldier` now returns the boat it boarded, or -1 — `>= 0` is the bool the HUD still wants.
	hud_view.note_key(slot, battle.load_soldier(HudView.key_type_of(slot)) >= 0)


## The panel is asked first, and it is asked through `panel_active()` rather than through a state
## check written out again here. Its rectangles exist whether it is drawn or not, so routing a click
## into the roster during a battle would bolt the beak on from an invisible list.
##
## Off the panel, a press on a loaded, at-harbour boat grabs it; anywhere else on the field begins a
## camera pan (`boat-and-landing`, section 6 — both are left-drags, and where the press LANDED is the
## only thing that tells them apart).
func _on_left_press(at: Vector2) -> void:
	if panel_view.panel_active():
		_click_panel(at)
		return
	if battle != null:
		var boat := _boat_hit_at(at)
		if boat >= 0:
			_drag_boat = boat
			field_view.set_drag(boat, _tile_at(at))
			return
	_panning = true


## Ends whichever gesture was in flight. A boat drag either launches — `battle.launch` is the single
## source of truth `grid.can_land_at` already agrees with, so the overlay can never promise a tile the
## sim then refuses — or cancels with the same shake a refused key gets (`hud_view.note_launch`, item
## 8 extended to the berth box). A release while the panel is up (the panel opened mid-drag, exactly
## the gap `_unhandled_input`'s motion branch also guards) cancels silently: no launch, no shake,
## because the sim is not the thing the player is looking at any more.
func _on_left_release(at: Vector2) -> void:
	if _drag_boat >= 0:
		var boat := _drag_boat
		_drag_boat = -1
		field_view.set_drag(-1, -1)
		if not panel_view.panel_active():
			var tile := _tile_at(at)
			var ok := tile >= 0 and battle != null and battle.launch(boat, tile)
			hud_view.note_launch(boat, ok)
	_panning = false


## Which boat (if any) a press at `at` should grab, checked before falling through to a camera pan.
## Two grab targets read as one control: the HUD berth box and the harbour tile a boat is actually
## sitting at are two renderings of the same boat (`boat-and-landing`, section 6, decided #8), so
## whichever one the press landed on returns the same boat, the same way. Only a boat that is loaded
## and at a harbour (not at sea) is grabbable — an empty or busy boat has nothing a drag could send.
func _boat_hit_at(at: Vector2) -> int:
	for b in Rules.boat_count():
		if _boat_grabbable(b) and Look.berth_rect_px(b).has_point(at):
			return b
	# The hull itself, not the tile it happens to sit on — `field_view.idle_hull_rect` is the SAME
	# rect `_draw()` just painted, converted through the camera the same way a click always is
	# (`screen_to_world_px`). Testing the tile index instead once left ~70% of a hull dead to a
	# press (only its centre tile was live) and let two boats sharing a harbour both answer to the
	# same press — the drawn rects are disjoint even when the tile beneath them is not.
	var world := field_view.screen_to_world_px(at)
	for b in Rules.boat_count():
		if not _boat_grabbable(b):
			continue
		if field_view.idle_hull_rect(b).has_point(world):
			return b
	return -1


func _boat_grabbable(b: int) -> bool:
	if battle.boat_busy(b):
		return false
	var cargo: PackedInt32Array = battle.pending[b]
	return not cargo.is_empty()


## A screen press converted to the tile it landed on, or -1 off the grid — the one function every
## boat hit-test and every drag update goes through, so a click and the overlay it is compared against
## can never disagree about which tile the cursor is over.
func _tile_at(at: Vector2) -> int:
	if battle == null or battle.grid == null:
		return -1
	var world := field_view.screen_to_world_px(at)
	var tv := field_view.world_to_tile(world)
	if tv.x < 0 or tv.y < 0 or tv.x >= battle.grid.w or tv.y >= battle.grid.h:
		return -1
	return battle.grid.tile_index(tv.x, tv.y)


## Zooms the field about `at`, keeping the world point under the cursor fixed
## (`field_view.zoom_at`). Refused while the panel is up, same as the drag.
func _on_wheel(at: Vector2, factor: float) -> void:
	if panel_view.panel_active():
		return
	field_view.zoom_at(at, factor)


## Reward pick and restart, both of which the panel resolves. `soldier_id_at` returns -1 outside the
## REWARD state and `button_hit` is false outside WON/LOST, so the two cannot both fire and neither
## needs a state test on this side — the mapping from a point to a soldier id lives in exactly one
## place, next to the code that draws the entries.
func _click_panel(at: Vector2) -> void:
	# `_unhandled_input` already refuses every real press during a hold. This second guard is for the
	# callers that skip it — a net drives this handler directly, because headless the window is 64x64
	# and a pushed click lands thousands of pixels off target. Without it a second pick would overwrite
	# `_pending_beak` while the first is still being stained.
	if _hold_sec > 0.0:
		return
	var picked := panel_view.soldier_id_at(at)
	if picked >= 0:
		# The view is told first and the sim is told last. `run.apply_beak` ends in `_advance()`, which
		# puts the run back into BATTLE, and `panel_view.panel_active()` is false the instant it does —
		# so calling it here would stop the panel drawing on this very frame however long the shell
		# then waited to open the next island. Delaying the CALL is the only fix that does not edit the
		# sim, and it pays for itself: `army.has_beak[picked]` stays 0 for the whole stain, so the only
		# thing that can colour that row differently is `note_beak`.
		panel_view.note_beak(picked)
		_pending_beak = picked
		_hold_sec = Look.HOLD_BEAK_SEC
		return
	if panel_view.button_hit(at):
		run.restart()
		_open_island()

# ⚠ `_click_dock` is gone whole — a fixed dock no longer exists to click. `boat-and-landing` stage 4
# replaces it with a drag: `_on_left_press` grabs a boat's hull or its HUD icon, the motion branch of
# `_unhandled_input` tracks the candidate tile, and `_on_left_release` calls `battle.launch(boat,
# tile)` or cancels — see those three for the whole of it.
