class_name Game
extends Node2D
## The shell. **The only file in the tree that reads an input event**, and the only one that wires the
## sim to the views.
##
## It builds its five children in code inside `_ready()` and never from the scene file, so a net that
## calls `_ready()` on an untreed instance exercises the real wiring. A child parked in `game.tscn`
## instead would let the line that creates it be deleted with every check still green — the same shape
## as pre-setting an `@onready` field from a net, which CLAUDE.md forbids for the same reason.
##
## Nothing here is `@onready` and nothing here is `@export`: every field below is assigned by `_ready`
## or by `_open_island`, so there is no path where the engine fills one in and the wiring is not run.
##
## Draw order is tree order for `Node2D` siblings, so the five children are added field -> hud -> map
## -> title -> panel and the panel lands on top of everything. Map and title never coexist (one needs
## a `Run` on the map, the other needs no run at all), so their relative order decides nothing — it is
## fixed anyway so nobody has to reason about it twice. There is no `CanvasLayer`.
##
## ⚠ **THREE SCREENS LIVE IN THIS ONE NODE and they are told apart by `run` alone**: `run == null` is
## the title, `run.state() == MAP` is the map, and everything else is an island. `title-and-map`
## records why the title is not a `Run.State`: before 시작하기 there is no run, and a state on an
## object that does not exist cannot be reached.
##
## The input table this file implements is `plan-then-watch`, section "Input", with `title-and-map`'s
## two branches on top of it. ⚠ The landing is authored with the mouse before a start button, and
## after that press nothing but the speed chips and the camera answers at all. The keyboard is not
## read anywhere.


## Session state. **`null` IS the title screen** — there is no separate scene and no autoload, and
## `project.godot`'s `run/main_scene` is still `game.tscn`. Built by 시작하기, dropped by the panel's
## restart button.
var run: Run = null

## The island being fought, or the last island fought once it is over. **It is deliberately not
## cleared when an island ends**: on the reward pick, the win and the loss the field stays on screen
## behind the panel, and the loss screen has to keep showing enemies-left to say *why* it was lost.
var battle: Battle = null

var field_view: FieldView = null
var hud_view: HudView = null
var map_view: MapView = null
var title_view: TitleView = null
var panel_view: PanelView = null

## True while a left-button drag on the FIELD (not the panel, not a soldier) is moving the camera.
## Mutually exclusive with `_drag_soldier` below — a press grabs a soldier XOR begins a pan, never
## both (`boat-and-landing`, section 6).
##
## ⚠ **The pan is NOT gated on the commit.** Camera pan and zoom stay live for the whole fight on
## purpose: they change nothing about what happens, and watching is the entire activity — removing
## them would turn 결정 4's 「pausing doesn't let me do anything more」 into 「and you cannot even
## look」. It is also the row that stops the post-commit checks from being satisfied by a dead screen.
var _panning := false

## The soldier a left-drag is currently placing, or -1. Set by `_on_left_press` when the press landed
## on a body still standing at the harbour (`field_view.idle_soldier_rect`), cleared by
## `_on_left_release` or by the hold guard below.
##
## ⚠ **It is a soldier, not a boat** (`plan-then-watch`, 결정 14R). Boats are unlimited and one is
## created BY the drop, so there is nothing to pick up and nothing to run out of.
var _drag_soldier := -1

## Which rung of `Rules.SPEED_STEPS` the fight is being watched at — **an index into the ladder, never
## the float**. The multiplier is read through `Rules.speed_mul_of` at the two places it is used.
##
## ⚠ **The name ends in `slot` for a measured reason**: `net_draw_leaf`'s widened literal sweep covers
## `src/shell/`, and both `mul` and `speed` are suffixes in it, so a field called `_speed_mul` or
## `_speed` would redden the round. This is not an evasion — a slot is what this actually holds.
## ⚠ **And the default is NOT slot 0.** Slot 0 is 0.0, `step` returns on `dt <= 0.0` before
## `_phase_clock`, so a shell that opened there would freeze the fight the instant start was pressed.
var _speed_slot := Rules.SPEED_SLOT_DEFAULT

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

## The map node a press has been accepted for, while the you-are-here ring is still walking the edge
## toward it, or -1. **The sim does not know yet**: `run.enter_node` is called by `_release_hold` and
## not by the click, which is what buys the travel its 0.45 s to play in.
##
## ⚠ Cutting straight to the island instead would make the map's work invisible — the walk IS the
## progress readout. Same shape as `_pending_beak` above, and for the same reason: the beat needs a
## frame, and delaying the CALL is the fix that does not edit the sim.
var _pending_node := -1


func _ready() -> void:
	field_view = FieldView.new()
	hud_view = HudView.new()
	map_view = MapView.new()
	title_view = TitleView.new()
	panel_view = PanelView.new()
	add_child(field_view)
	add_child(hud_view)
	add_child(map_view)
	add_child(title_view)
	add_child(panel_view)

	# ⚠ **No `Run` is built here and no island is opened.** The game opens on the title, and the two
	# lines that used to be here are exactly what 「켜면 섬이 떵하니 나온다」 named. `panel_view.bind`
	# is not called either: `panel_view.run` stays null and `panel_active()` is false for free.
	run = null


## Opens the island `run` is standing on and re-points all three views at it.
##
## `Run.begin_island()` returns null during a reward pick and once the run is over, and this leaves
## `battle` alone in that case rather than nulling it — see `battle` above for why the last island has
## to stay drawable. The views are still re-bound, because the panel reads `run.state()` and has to
## learn that the island it is sitting on top of is finished.
func _open_island() -> void:
	# A drag in flight on the island that just ended must not survive onto the one that just opened —
	# its soldier id would now name a body standing at a different harbour. Cleared unconditionally,
	# not only when a new island actually opens: a REWARD transition (`opened == null`) still has to
	# drop a drag that was in flight when the panel came up.
	_drag_soldier = -1
	field_view.set_drag(-1, -1)
	# Every island opens at 1x and is PLANNED at 1x. Carrying the slot across would let island 2 open
	# paused because island 1 was paused when it ended, and 「the fight never started」 and 「the fight
	# is over」 look identical on a still screen.
	_speed_slot = Rules.SPEED_SLOT_DEFAULT
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
## ⚠ **It no longer re-opens unconditionally, and the comment that said it should is gone with the
## behaviour it described.** A won island now lands the run back in `MAP` (`take_count_reward` and the
## chest both end there), so re-opening would ask `begin_island` for a fight the run is not in, get a
## null, and leave the island just won drawing underneath the map. A `BEAK` node still stops in
## `REWARD` and a boss still ends in `WON`/`LOST`, and `_open_island` handles all three exactly as it
## did — by leaving the last island drawable behind the panel.
func _close_island() -> void:
	run.finish_island(battle.outcome() == Battle.Outcome.WON)
	if run.state() == Run.State.MAP:
		_enter_map_screen()
	else:
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
## ⚠ **The early return was SPLIT rather than moved, and the half that matters kept its place.**
## `title-and-map` pins this function's first line, and its stated reason is that both new views age
## their own clocks — making the shell hand time down would be one clock in two places. That reason is
## untouched: neither `map_view` nor `title_view` is given a second of time by this file. What changed
## is that a hold can now run while there is no battle at all (the map's travel walk), so the battle
## guard sits below the hold instead of above it. `begin_frame()` still sits directly under the run
## check and above everything else that touches `battle`, which is the one position `combat-juice`
## allows it in.
func _process(delta: float) -> void:
	if run == null:
		return
	# **The ladder is handed down here and nowhere else**, on every frame, above every early return
	# below this line. One number, read once, given to the sim as `delta * k` and to both views as `k`
	# — the sim runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps so `k` is arithmetically inert for it, and
	# the views age their own drawers by it so a 6x fight does not play a different animation. A view
	# that looked the float up itself would be a second reader of `Rules.SPEED_STEPS`.
	# ⚠ Above the hold and the panel guard on purpose: a paused ladder has to freeze the picture too,
	# and two places deciding "what is the current speed" is how the sim and the screen drift apart.
	var k := Rules.speed_mul_of(_speed_slot)
	if battle != null:
		battle.begin_frame()
		field_view.set_time_scale(k)
		hud_view.set_speed(_speed_slot, k)
	if _hold_sec > 0.0:
		_hold_sec = maxf(0.0, _hold_sec - delta)
		if _hold_sec <= 0.0:
			_release_hold()
		return
	if battle == null:
		return
	if run.state() != Run.State.BATTLE:
		return
	# ⚠ **At 0x this still calls `step(0.0)`** rather than skipping the call. `step` owns the pause —
	# it returns on `dt <= 0.0` before `_phase_clock`, which is the only writer of `elapsed` and so of
	# the loss condition. A second test up here would be the same rule in two places, and two tests
	# for one fact diverge.
	battle.step(delta * k)
	if battle.outcome() != Battle.Outcome.RUNNING:
		# This REPLACES the old immediate `_close_island()`. Without the pause the last enemy's death
		# ring never gets a frame: the verdict and the next island's `setup()` landed inside one frame,
		# and `setup()` empties the view's effect drawers.
		_hold_sec = Look.HOLD_OUTCOME_SEC


## What the shell does when a hold runs out: step onto the map node the ring has just walked to, bolt
## on the beak the panel has been showing, or close the island that was left standing on screen.
##
## The three are exclusive by construction and the order only decides which is read first. A map hold
## runs with `battle == null`, so it can never reach `_close_island` below; a beak hold cannot start
## while an outcome hold is running, because a hold does not step and only a step can latch an
## outcome.
func _release_hold() -> void:
	if _pending_node >= 0:
		var n := _pending_node
		_pending_node = -1
		_enter_node(n)
		return
	if _pending_beak >= 0:
		run.apply_beak(_pending_beak)
		_pending_beak = -1
		# ⚠ **Not `_open_island()`.** `apply_beak` ends in `_advance`, which now lands in `MAP` — asking
		# `begin_island` for a fight the run is not in returns null and leaves the previous island
		# drawing under the map.
		_enter_map_screen()
		return
	_close_island()


# --- input ----------------------------------------------------------------------------------------

## `_unhandled_input` and not `_input`, and a raw `InputEvent` and not an `InputMap` action: a net
## drives this by building the event and calling this method, so what is measured is the shell rather
## than `project.godot`. There is no `[input]` section in that file for the same reason.
func _unhandled_input(event: InputEvent) -> void:
	# ⚠⚠ **The `if run == null: return` that used to be here is DELETED, not moved and not layered
	# over.** It was the line that made 시작하기 unpressable: with no run there was no way to make one.
	# The title branch takes exactly that position — see `title-and-map`'s refutation box, which
	# records the earlier draft citing that same `return` as an ADVANTAGE.
	if run == null:
		_title_input(event)
		return
	# One line closes the door on all three inputs during a hold, instead of three state tests spread
	# across the handlers below. It has to be here and not in them: during an outcome hold
	# `finish_island` has not run yet, so `run.state()` is still BATTLE and every guard downstream
	# waves the press through — 1/2 would keep boarding soldiers onto a won island, and a pan or a
	# zoom started into a sim that is not stepping would leave the camera moving over a frozen frame.
	#
	# ⚠ **It stays BELOW the title branch and that is safe, measured against the code rather than
	# assumed**: a hold is armed by `_process` (which returns on `run == null`), by `_click_panel`
	# (which itself returns early while a hold runs) or by `_map_input` (which needs a run). The only
	# path to `run == null` is the restart button inside `_click_panel`, and `_hold_sec` is 0 there.
	# The next reader will otherwise "fix" this order.
	#
	# ⚠ A drag in flight is CANCELLED here, not merely suppressed: `_panning` and `_drag_soldier` are
	# cleared on every event that arrives while a hold is active, not just left alone. Without this
	# line the hold only blocks the MOTION events that would have kept panning or dragging — the flag
	# itself survives the hold, and once it ends with the mouse button still down, the very next
	# motion resumes the gesture the plan says must have been cancelled.
	if _hold_sec > 0.0:
		_panning = false
		_drag_soldier = -1
		field_view.set_drag(-1, -1)
		return
	# ⚠ **The map branch sits ABOVE the mouse block below**, and that is measured against the code
	# rather than tidy: the fall-through at the bottom of `_on_left_press` is `_panning = true`, so a
	# click on a node would otherwise pan the camera over the island still sitting behind the map.
	if run.state() == Run.State.MAP:
		_map_input(event)
		return
	# ⚠ **There is no `InputEventKey` branch any more, and `_on_key` is deleted whole.** The 1/2 summon
	# keys were the whole of the keyboard, and `plan-then-watch` deletes them: the landing is authored
	# with the mouse before the start button and the hand does nothing during the fight.
	if event is InputEventMouseButton:
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
		# ⚠ **One of the three PLAN BRANCHES the commit gate lives on** (`plan-then-watch`, section 7).
		# The gate is on the branch and not on the handler: the pan below has to keep working after the
		# commit, and gating the whole handler would be the inert screen that makes the post-commit
		# checks pass for the wrong reason.
		if _drag_soldier >= 0 and battle != null and not battle.committed():
			# The candidate tile tracks the cursor; `battle.send` is not called until the release, so a
			# drag that never releases over a droppable tile never touches the sim at all.
			field_view.set_drag(_drag_soldier, _tile_at(motion.position))
		elif _panning:
			field_view.pan_by(motion.relative)


## The title screen's whole input table. Motion lights the slot under the cursor; a left press either
## starts a run or closes the game.
##
## ⚠ **설정하기 is passed over in silence and `note_press` is NOT called for it.** A press animation on
## a slot that does nothing is the picture saying something happened when nothing did — this repo's
## named "screen changes but the sim doesn't" fake, wearing a menu. The slot is drawn as unpressable
## and it behaves as unpressable; those two are the same claim.
func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		title_view.set_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var slot := title_view.slot_at(click.position)
	if not title_view.is_slot_pressable(slot):
		return
	title_view.note_press(slot)
	if slot == TitleView.SLOT_START:
		_start_run()
	elif slot == TitleView.SLOT_QUIT:
		_quit_the_game()


## Closes the game. **One line, cut out into its own function for exactly the reason every `_paint_*`
## hook in `src/view/` is**: a net cannot drive `get_tree().quit()` and live to report anything —
## `SceneTree.quit()` stops the loop, every pending `await process_frame` in the runner is abandoned,
## and the round vanishes with exit code 0 instead of going red. There is no un-quit call in 4.x and
## `get_tree()` cannot be shadowed in GDScript (measured on 4.7.1: *"overrides a method from native
## class Node"*, a parse error), so this is the only seam a spy can hold.
##
## ⚠ **What that spy proves is that the 종료 branch reaches this function, and nothing more.** The
## `get_tree().quit()` inside it is one statement and it is not measured by anything — the same last
## inch every hook in this repo leaves open, written down here rather than left to be discovered.
func _quit_the_game() -> void:
	get_tree().quit()


## The map screen's whole input table: one hover and one press, and the press is the run's only verb
## on this screen.
##
## ⚠ **Reachability is asked of the SIM and not of the view's own picture.** `map_view.is_node_pressable`
## calls `RunMap.is_reachable`, which is the same call `run.enter_node` makes when the hold expires, so
## a press can never be offered on screen and refused a moment later.
func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		map_view.set_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var n := map_view.node_at(click.position)
	if n < 0 or not run.map.is_reachable(n):
		return
	# The view is told first and the sim is told last, exactly as the beak pick is: `enter_node` leaves
	# `MAP` on the spot, and `map_view._draw` returns the instant it does — so the ring would have zero
	# frames to walk in however long the shell then waited.
	map_view.note_press(n)
	_pending_node = n
	_hold_sec = Look.MAP_TRAVEL_SEC


## 시작하기: a brand new run, and the map rather than an island. **`Run.restart()` is not called here**
## — a fresh `Run` is what 시작하기 means, and `restart` stays alive for `net_run` to keep `_reset`
## honest about fields added to one path and not the other.
func _start_run() -> void:
	run = Run.new()
	_enter_map_screen()


## Steps onto a node once its ring has finished walking. A node that opens an island hands over to
## `_open_island`; a chest opens none — its reward already landed inside `enter_node` — so the map
## simply comes back, and `map_view` notices the pool moved and climbs the 「힘」 number to it.
func _enter_node(n: int) -> void:
	if not run.enter_node(n):
		return
	if run.state() == Run.State.BATTLE:
		_open_island()
	else:
		_enter_map_screen()


## Puts the map on screen and takes the island off it.
##
## ⚠⚠ **`battle = null` is the one lever that silences `field_view` AND `hud_view` at once**, and it is
## the opposite of what `_open_island` does on purpose: the island the run just left has to stop being
## drawn, stop panning, and take its clock and its start button with it. `field_view._draw` gates on
## `battle == null`, and so does `hud_view._draw`.
##
## The `setup(null, ...)` and `bind(null)` calls under it are not redundant in the way that matters:
## `field_view` holds its OWN reference and would keep drawing the last island's terrain if only this
## file's field were cleared.
func _enter_map_screen() -> void:
	battle = null
	_drag_soldier = -1
	_speed_slot = Rules.SPEED_SLOT_DEFAULT
	field_view.setup(null, null, [])
	field_view.set_drag(-1, -1)
	hud_view.bind(null)
	map_view.bind(run)
	# The node the run is standing on is the one that was just cleared, and -1 (a run that has landed
	# nowhere yet) is a no-op. Asked of the map rather than remembered here — the shell keeping its own
	# "which node did I just win" would be `path` written down a second time.
	map_view.note_cleared(run.map.at())
	panel_view.bind(run, null)
	title_view.visible = false


## The panel is asked first, and it is asked through `panel_active()` rather than through a state
## check written out again here. Its rectangles exist whether it is drawn or not, so routing a click
## into the roster during a battle would bolt the beak on from an invisible list.
##
## Then, in this order and the order is not arbitrary:
##
##  1. **the start button**, which is HUD chrome and therefore sits ON TOP of the island — at
##     `ZOOM_MIN` the island band and the button's rectangle overlap in one corner, and chrome that
##     loses to what it is drawn over is chrome that cannot be pressed;
##  2. **a speed chip**, and only after the commit — before it there is nothing running to speed up;
##  3. **a placed boat's landing ring** (`_ring_hit_at`), which undoes that drop;
##  4. **a soldier still standing at the harbour** (`_soldier_hit_at`), which begins a drag;
##  5. otherwise a camera pan.
##
## ⚠ **3 before 4 is measured, not tidy.** A landing ring can sit on top of the harbour when a player
## drops a boat onto the beach beside it, and undo losing to grab is the worse failure: a grab that
## should have been an undo starts a drag the player then has to cancel, whereas an undo that should
## have been a grab is one press to recover.
##
## ⚠ **Two of the three PLAN BRANCHES the commit gate lives on are here** (1 with 3 and 4), and it is
## the branches that are gated rather than this handler: the pan fall-through and `_on_wheel` read the
## same before and after the commit, and gating them turns the "camera still works" row red — the one
## row that stops the post-commit checks from being satisfied by a screen that does nothing at all.
func _on_left_press(at: Vector2) -> void:
	if panel_view.panel_active():
		_click_panel(at)
		return
	if battle != null:
		if not battle.committed():
			if Look.start_rect_px().has_point(at):
				# The bool is handed to the HUD and not dropped. It is the ONLY thing separating "that
				# press did nothing because nobody is being landed" from "that press did nothing because
				# the game is not listening", and the shell is the only place both facts exist at once.
				# `combat-juice`, item 8, now pointed at the one press that ends the planning phase.
				hud_view.note_chip(0, battle.commit())
				return
			var uid := _ring_hit_at(at)
			if uid >= 0:
				battle.recall(uid)
				return
			var soldier := _soldier_hit_at(at)
			if soldier >= 0:
				_drag_soldier = soldier
				field_view.set_drag(soldier, _tile_at(at))
				return
		else:
			var chip := _speed_hit_at(at)
			if chip >= 0:
				_speed_slot = chip
				return
	_panning = true


## Ends whichever gesture was in flight. A soldier drag either sends — `battle.send` is the single
## source of truth `grid.home_harbour_for` already agrees with, and the droppable tint on screen is
## drawn from that same call, so the picture can never promise a tile the sim then refuses — or
## cancels, silently, because the ring under the cursor was already `COL_LOSE` and the refusal was
## readable before the button came up.
##
## ⚠ **`send` returns an int uid and uid 0 is the FIRST boat of every island**, so `if battle.send(…)`
## would refuse the common case. Nothing here reads the return as a bool.
##
## ⚠ **The `_drag_soldier` branch is the third PLAN BRANCH the commit gate lives on.** Without it a
## press that started before the commit and released after it would still author a landing.
func _on_left_release(at: Vector2) -> void:
	if _drag_soldier >= 0:
		var soldier := _drag_soldier
		_drag_soldier = -1
		field_view.set_drag(-1, -1)
		if not panel_view.panel_active() and battle != null and not battle.committed():
			var tile := _tile_at(at)
			if tile >= 0:
				battle.send(soldier, tile)
	_panning = false


## Which soldier still standing at the harbour a press at `at` grabs, or -1.
##
## ⚠ **`field_view.idle_soldier_rect` is the SAME rect `_draw()` just painted**, converted through the
## camera the way every click is (`screen_to_world_px`). Testing the tile index instead once left ~70%
## of a hull dead to a press in this repo — the drawn rects are disjoint even where the tiles beneath
## them are not, and re-deriving the anchor here would be the geometry written down twice.
##
## Descending, so the body drawn LAST wins an overlap. `IDLE_SOLDIER_PITCH_PX` is bounded below by the
## widest body so they should never overlap at all; this only decides which one answers if that bound
## is ever loosened.
func _soldier_hit_at(at: Vector2) -> int:
	if battle == null:
		return -1
	var world := field_view.screen_to_world_px(at)
	var i := battle.soldier_state.size() - 1
	while i >= 0:
		var rect := field_view.idle_soldier_rect(i)
		if rect.size != Vector2.ZERO and rect.has_point(world):
			return i
		i -= 1
	return -1


## Which placed boat's landing ring a press at `at` is on, as that boat's **uid**, or -1.
##
## The ring's centre and radius are read the same way `field_view` draws them — the landing tile's
## centre at `Look.TARGET_RING_R_PX` — rather than from a rect invented here. A press anywhere INSIDE
## the ring counts, not only on its stroke: a 2 px annulus at `ZOOM_MIN` is 0.9 px on the glass and
## would be a control nobody could hit.
##
## Descending, so the most recently dropped boat — the one drawn last, and on top — is the one undone.
func _ring_hit_at(at: Vector2) -> int:
	if battle == null or battle.grid == null:
		return -1
	var world := field_view.screen_to_world_px(at)
	var i := battle.boats.size() - 1
	while i >= 0:
		var boat: Dictionary = battle.boats[i]
		var centre := Look.tile_point_px(battle.grid.tile_point(int(boat["target"])))
		if centre.distance_to(world) <= Look.TARGET_RING_R_PX:
			return int(boat["uid"])
		i -= 1
	return -1


## Which speed chip a press at `at` is on, or -1. Viewport coordinates, not world ones: the chips are
## HUD chrome and do not move with the camera.
func _speed_hit_at(at: Vector2) -> int:
	for i in Rules.speed_slot_count():
		if Look.speed_rect_px(i).has_point(at):
			return i
	return -1


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
##
## ⚠ **This is NOT gated on the commit and must not be.** It holds no plan gesture — it reads exactly
## the same before and after the start button — and gating it turns the "the camera still works
## during the fight" row red, which is the one row that stops the "the hand does nothing after the
## commit" rows from being satisfied by a screen that does nothing at all. `plan-then-watch`, section
## "Input": **three plan branches are gated, not four.**
##
## ⚠ At `ZOOM_MIN` the map is narrower than the visible world on BOTH axes, so a PAN cannot move the
## camera at all — `_clamp_cam` centres both. That is the framing the user asked for (「조금 더 카메라를
## 뒤로 빼야 될」) and not a defect: there is nothing off screen to pan to. The wheel is what unlocks
## the pan, which is also the mitigation for an 18 px tile being a small drop target.
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
		# ⚠ **Back to the TITLE, not to a fresh island.** `run == null` IS the title screen, so this is
		# one line — but `battle` must be nulled in the same breath or the boss island keeps drawing
		# behind it, and `map_view` must be unbound or a finished map stays on screen under the menu.
		run = null
		battle = null
		field_view.setup(null, null, [])
		hud_view.bind(null)
		map_view.bind(null)
		panel_view.bind(null, null)
		title_view.visible = true

# ⚠ Three handlers are gone whole and none of them was replaced by an equivalent:
#  - `_click_dock` — a fixed dock stopped existing in `boat-and-landing`;
#  - `_on_key` — the 1/2 summon keys stopped existing in `plan-then-watch`, along with the whole
#    `InputEventKey` branch of `_unhandled_input`. The keyboard does nothing in this game now;
#  - `_boat_hit_at` / `_boat_grabbable` — they tested a HUD berth rect and an idle hull rect for a
#    FLEET SLOT, and there is no fleet. `_soldier_hit_at` and `_ring_hit_at` above are what a press
#    is asked instead, and neither one names a boat that already exists.
