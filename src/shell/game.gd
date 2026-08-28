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
## Draw order is tree order for `Node2D` siblings, so the children are added field -> hud -> title ->
## panel and the panel lands on top of everything. There is no `CanvasLayer`.
##
## ⚠⚠ **THE MAP SCREEN IS DELETED** (2026-08-26) with the seven nodes and the eight islands behind it.
## `map_view`, `_map_input`, `_enter_map_screen`, `_enter_node` and `_pending_node` all went with it.
##
## ⚠ **TWO SCREENS LIVE IN THIS ONE NODE and they are told apart by `run` alone**: `run == null` is the
## title, and everything else is the island. The title is not a `Run.State` because before 시작하기
## there is no run, and a state on an object that does not exist cannot be reached.
##
## The input table this file implements is `plan-then-watch`, section "Input", with `title-and-map`'s
## two branches and `sea-summon`'s two on top of it. ⚠ The landing is authored before a start button,
## and **after that press only the camera answers at all** — `speed-off-open-landing` deleted the speed
## chips and the pause with them, so a committed fight has nothing the hand can do to it.
##
## ⚠⚠ **THE KEYBOARD IS READ AGAIN, and 1~5 ARM a summon slot rather than spawning anything**
## (`sea-summon`). The user corrected the record themselves — *"정확히는 배 속이 별로여서 뺀거임
## 1~5번키"* — the old keys came out because of what was IN the boat, not because a key is the wrong
## door. What places a body is still a press, on the green band of water; the key only says which
## slot. **The hand still does not move during combat**: every summon branch below is gated on
## `battle.committed()`, and those gates are seams #2 and #3 of `sea-summon`'s OPEN question 1 — a
## live-fire version deletes them and this build must not seal them shut.


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
var reward_view: RewardView = null
var refit_view: RefitView = null
var title_view: TitleView = null
var panel_view: PanelView = null

## True while a left-button drag on the FIELD is moving the camera. ⚠ **It used to be mutually
## exclusive with `_drag_soldier`** — a press grabbed a soldier XOR began a pan — and the soldier drag
## is deleted, so a press that is not a summon and not HUD chrome is now always a pan.
##
## ⚠ **The pan is NOT gated on the commit.** Camera pan and zoom stay live for the whole fight on
## purpose: they change nothing about what happens, and watching is the entire activity — removing
## them would turn 결정 4's 「pausing doesn't let me do anything more」 into 「and you cannot even
## look」. It is also the row that stops the post-commit checks from being satisfied by a dead screen.
var _panning := false

## Seconds the shell is standing still, holding a moment on screen before it walks the run forward.
## One thing rides it — the verdict pause — and `_release_hold` moves the state on the frame it
## expires. `combat-juice`, item "승패 전환".
## ⚠ **Two others rode it and are gone**: the beak stain (2026-08-25) and the map ring's travel walk
## (2026-08-26).
##
## **Declared with an explicit type and not `:= 0.0` on purpose.** `net_draw_leaf`'s literal scan
## reads `src/shell/` as well, and a bare `_hold_sec := <number>` is exactly the shape it is widened
## to catch — the shape that would let the 0.8 be hardcoded here instead of read from `look.gd`. The
## zero is a "nothing is held" sentinel, not a duration, and it is written so the scan can keep
## biting the duration.
var _hold_sec: float = 0.0

## `sea-summon`'s four. `_armed_slot` is which slot a number key has armed, or -1; `_summon_down` is
## true while a summon press is being held; `_summon_at` is the tile under the cursor and
## `_summon_cursor` the raw screen point it came from.
##
## ⚠ **The raw point is kept BESIDE the tile and is not derived from it.** `_tile_at` answers -1 off
## the grid, and a press off the grid is a refusal that still has to draw its mark somewhere — with
## only the tile there would be nowhere to put it.
var _armed_slot := -1
var _summon_down := false
var _summon_at := -1
var _summon_cursor := Vector2.ZERO

## Seconds until the held summon puts out one more body.
##
## **Declared with an explicit type and not `:= 0.0`**, for the reason `_hold_sec` above already
## carries: `net_draw_leaf`'s literal scan reads `src/shell/`, `sec` is one of its suffixes, and
## `_x_sec := <number>` is exactly the shape it is widened to catch — the shape that would let the 0.20
## be hardcoded here instead of read from `look.gd`. The zero is a "no beat is pending" sentinel, not a
## duration.
##
## ⚠ **It is a different clock from `_hold_sec`** and the two never overlap: a hold cancels every
## gesture on the first event it sees.
var _summon_beat_sec: float = 0.0


func _ready() -> void:
	field_view = FieldView.new()
	hud_view = HudView.new()
	reward_view = RewardView.new()
	refit_view = RefitView.new()
	title_view = TitleView.new()
	panel_view = PanelView.new()
	add_child(field_view)
	add_child(hud_view)
	add_child(reward_view)
	add_child(refit_view)
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
	# Cleared unconditionally and not only when an island actually opens: a transition with
	# `opened == null` still has to drop an aim that was live when the panel came up.
	_disarm()
	var opened := run.begin_island()
	if opened != null:
		battle = opened
		# A fresh `Grid` and a fresh `Battle`, but the SAME `Army` — that is how HP and every fitted
		# item carry. The army handed to the field is `run.army`, the same object `begin_island` just
		# gave the battle; rebuilding it anywhere would heal the run while a check that only counted
		# soldiers stayed green.
		#
		# The field is handed the island's legend ROWS as well, because `grid.passable` is one byte and
		# water and a hole are both 0 in it: coloured from passability alone the sea and the pits come
		# out the same tone and the map reads as one shape.
		field_view.setup(battle, run.army, Islands.rows())
		hud_view.bind(battle)
	panel_view.bind(run, battle)


## Closes the island that just finished and walks the run forward.
##
## ⚠ **It no longer re-opens unconditionally, and the comment that said it should is gone with the
## behaviour it described.** A won island lands the run in `PICK`, and the card taken there sends it
## on to `REFIT`, so re-opening would ask `begin_island` for a fight the run is not in, get a null, and
## leave the island just won drawing underneath. A boss still ends in `WON`/`LOST`, and `_open_island`
## handles that exactly as it did — by leaving the last island drawable behind the panel.
##
## ⚠⚠ **THIS COMMENT SAID `MAP` AND `take_count_reward` UNTIL 2026-08-27 AND NEITHER EXISTS.** The map
## screen, its state and its rewards were deleted with the seven islands (2026-08-26); `Run.State` is
## `BATTLE · PICK · REFIT · WON · LOST` and `take_count_reward` is not a symbol in this repo.
## ⚠ **A `BEAK` node used to stop in `REWARD` here.** Both the node kind and that state are deleted
## (2026-08-25) — a finished island now ends in `PICK`, `REFIT`, `WON` or `LOST`.
func _close_island() -> void:
	run.finish_island(battle.outcome() == Battle.Outcome.WON)
	_show_state()


## The one mapping from `run.state()` to a screen. Three copies of a state->screen dispatch is three
## places to forget a new state — `_close_island` calls this instead of deciding for itself.
func _show_state() -> void:
	match run.state():
		Run.State.PICK:
			_enter_pick_screen()
		Run.State.REFIT:
			_enter_refit_screen()
		_:
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
## untouched: `title_view` is not given a second of time by this file. The battle guard sits below the
## hold rather than above it, which is where the map's travel walk left it. `begin_frame()` still sits directly under the run
## check and above everything else that touches `battle`, which is the one position `combat-juice`
## allows it in.
func _process(delta: float) -> void:
	if run == null:
		return
	# ⚠ **No multiplier is handed down any more.** `speed-off-open-landing` deleted the ladder, so the
	# sim and both views run on the bare frame delta — which is what every duration in `look.gd` was
	# budgeted against in the first place. `set_time_scale` and `set_speed` are gone rather than being
	# called with a constant 1.0: a leaf handed a constant is the shape 「No fake code」 names.
	if battle != null:
		battle.begin_frame()
	if _hold_sec > 0.0:
		_hold_sec = maxf(0.0, _hold_sec - delta)
		if _hold_sec <= 0.0:
			_release_hold()
		return
	if battle == null:
		return
	if run.state() != Run.State.BATTLE:
		return
	# The held summon's beat (`sea-summon`). It sits ABOVE `battle.step` so a body placed this frame is
	# on its boat before the sim looks at the boats.
	#
	# ⚠ **Seam #3 of OPEN question 1.** `not battle.committed()` is what makes this a planning gesture;
	# a live-fire version deletes it, and `Look.SLOT_HOLD_SEC` then moves to `rules.gd` because during
	# a fight it is the arrival spacing of reinforcements and changes what happens. Do not hard-code
	# the cadence here and do not fold this into a planning-only helper — the seam is the thing worth
	# preserving, the same argument `speed-off-open-landing` made for `Battle.step(dt)` keeping a bare
	# delta after the multiplier was deleted.
	if _summon_down and battle != null and not battle.committed():
		_summon_beat_sec -= delta
		# ⚠ **`+=` and not `=`**, so a long frame does not swallow beats. **It terminates
		# unconditionally**: every pass adds a positive constant whether or not the summon succeeded,
		# so the accumulator climbs out in a bounded number of passes. That argument is written down
		# rather than assumed, because a `while` inside a `_process` is the shape that hung a net for
		# 148.7 s in this repo once and printed no verdict at all.
		# ⚠ **`<= Rules.EPS` and not `<= 0.0`, and the epsilon is load-bearing.** Four frames of 0.05
		# against a 0.20 cadence leave `1.4e-17` on the accumulator, and a bare `<= 0.0` holds the beat
		# back a whole extra frame for a residue eleven orders of magnitude under a millisecond. This is
		# the same boundary — and the same epsilon — `Battle._arrived` already carries for the same
		# reason: a float sum that lands ON the mark must count as having reached it.
		while _summon_beat_sec <= Rules.EPS:
			_fire_one_summon()
			_summon_beat_sec += Look.SLOT_HOLD_SEC
	# ⚠ **A BARE delta, and the call keeps taking one.** `speed-off-open-landing`'s 「what does NOT
	# come out」 pins this: do not inline a constant anywhere, because the seam a multiplier plugs back
	# into is the thing worth preserving. `Battle.step` still consumes whole `Rules.SIM_SUBSTEP_SEC`
	# sub-steps and carries the leftover, so `step(dt)` and `step(dt/k)` k times still land on
	# identical state — which is the property the restored multiplier would stand on.
	battle.step(delta)
	if battle.outcome() != Battle.Outcome.RUNNING:
		# This REPLACES the old immediate `_close_island()`. Without the pause the last enemy's death
		# ring never gets a frame: the verdict and the next island's `setup()` landed inside one frame,
		# and `setup()` empties the view's effect drawers.
		_hold_sec = Look.HOLD_OUTCOME_SEC


## What the shell does when a hold runs out: close the island that was left standing on screen.
##
## ⚠ **Two other branches were deleted from here** — bolting on the beak (2026-08-25) and stepping onto
## a map node the ring had walked to (2026-08-26). **One hold, one thing to do.**
func _release_hold() -> void:
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
	# (which itself returns early while a hold runs). The only
	# path to `run == null` is the restart button inside `_click_panel`, and `_hold_sec` is 0 there.
	# The next reader will otherwise "fix" this order.
	#
	# ⚠ A gesture in flight is CANCELLED here, not merely suppressed: `_panning` and `_summon_down` are
	# cleared on every event that arrives while a hold is active, not just left alone. Without this
	# the hold only blocks the MOTION events that would have kept panning or summoning — the flag
	# itself survives the hold, and once it ends with the mouse button still down, the very next
	# motion resumes the gesture the plan says must have been cancelled.
	if _hold_sec > 0.0:
		_panning = false
		# The held summon is cancelled here for exactly the reason the drag is: suppressing only the
		# MOTION events leaves the flag alive, and the very next motion after the hold ends resumes a
		# gesture the plan says must have been cancelled. The slot stays ARMED — arming is a mode, not
		# a gesture in flight.
		_summon_down = false
		return
	# ⚠⚠ **The `PICK` and `REFIT` branches sit ABOVE the `battle != null` block.** Below it, a click on
	# a card or a cell falls through to `_panning = true` — the field is `null` on both these screens,
	# but `_on_left_press` does not know that until it gets there.
	if run.state() == Run.State.PICK:
		_pick_input(event)
		return
	if run.state() == Run.State.REFIT:
		_refit_input(event)
		return
	# ⚠⚠ **The `InputEventKey` branch is BACK** (`sea-summon`), and it does something different from
	# the `_on_key` `plan-then-watch` deleted: those keys spawned a body straight onto a boat, and
	# these only ARM a slot. The landing is still authored by a press on the field, and it is still all
	# authored before the start button. ⚠ Raw keycodes off the event and no `[input]` action: there is
	# no `[input]` section in `project.godot` and none is added, so what a net drives is the shell
	# rather than a settings file. Numpad keycodes and rebinding are out of scope.
	if event is InputEventKey and (event as InputEventKey).pressed:
		# ⚠⚠ **Turning comes FIRST and it is not gated on the commit.** Every other key here only arms a
		# slot while the plan is open; this one answers during the fight too, on purpose — 티켓 07 asks
		# whether a hand may move the board mid-fight, and gating it before the question is decided
		# would answer it by omission (2026-08-24, the user: 「3D 회전 회전 버튼이 내가 돌려봐야 될 듯」).
		if _on_turn_key(event as InputEventKey):
			return
		_on_summon_key(event as InputEventKey)
		return
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
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# ⚠⚠ **Right-drag turns the board** (2026-08-26, the user: 「회전은 오른쪽 마우스 누르고
			# 돌릴 수 있었으면 좋겠음」). Q and E stay: they turn by a fixed notch, which is what a
			# check can drive and what a keyboard hand wants. **This is the same camera and the same
			# `turn_by`** — a second path to one state, never a second state.
			_turning = click.pressed
			_turn_from = click.position
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _turning:
			# ⚠ **Horizontal travel only.** Adding the vertical axis to the tilt here was tried on paper
			# and dropped: R and F step the tilt, and a drag that changed two things at once made every
			# accidental diagonal a lost camera the user then had to fix by hand.
			var dx := motion.position.x - _turn_from.x
			_turn_from = motion.position
			field_view.turn_by(dx * Look.CAM_YAW_PER_PX_DEG)
			return
		# The panel is asked here too, and not only on press: a drag begun on the field before the
		# panel opened must not keep panning (or sending) behind it once it does — `panel_active()`
		# becoming true mid-drag is what `_on_left_press` alone cannot catch.
		if panel_view.panel_active():
			return
		# ⚠⚠ **THE HOVER PLATE, AND IT IS ASKED ON EVERY MOTION.** `_tile_at` answers -1 off the island,
		# which is exactly the value that hides the plate, so there is no second test for "is the mouse
		# on the ground". **It is set here and not inside the summon branch below** — the plate says
		# where the cursor is, which is true whether or not a slot is armed.
		field_view.set_hover_tile(_tile_at(motion.position))
		# ⚠ **One of the three PLAN BRANCHES the commit gate lives on** (`plan-then-watch`, section 7).
		# The gate is on the branch and not on the handler: the pan below has to keep working after the
		# commit, and gating the whole handler would be the inert screen that makes the post-commit
		# checks pass for the wrong reason.
		#
		# ⚠ **The summon aim is updated whether or not the button is down**, so the ring and the route
		# are readable BEFORE the press rather than after it. It is gated on the commit for the same
		# reason the drag is and not as padding: ungated, a committed fight would consume every motion
		# here and the pan below would never run again.
		if _armed_slot >= 0 and battle != null and not battle.committed():
			_summon_cursor = motion.position
			_summon_at = _tile_at(motion.position)
			field_view.set_summon_aim(_armed_slot, _summon_at)
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


## The reward screen's whole input table: one hover and one press.
##
## ⚠ **Whether a card may be taken is asked of the SIM**: `reward_view.is_card_pressable` calls the
## same predicate `run.take_card` refuses on, so the picture can never offer a card the sim then
## refuses. **The comparison here used to be `run.map.is_reachable`, and the map is deleted** —
## the rule outlived its example.
func _pick_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		reward_view.set_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var k := reward_view.card_at(click.position)
	if not reward_view.is_card_pressable(k):
		return
	reward_view.note_press(k)
	run.take_card(k)
	# ⚠⚠ **`_show_state()` and no longer a hard-wired `_enter_refit_screen()`** (티켓 15). A beast card
	# pays a slot and bodies rather than the held pile, so the run walks straight back to the MAP —
	# and the refit screen it used to open unconditionally would have been a board with nothing to lay
	# on it, over a map nobody could see.
	if run.state() != Run.State.PICK:
		_show_state()


## The refit screen's whole input table: one hover and, in order, four kinds of press — 완료, 뒤로 (only
## with a board open), a slot box (only on the strip), a held row, or a filled cell.
func _refit_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		refit_view.set_hover((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var at := click.position
	if refit_view.is_done_pressable(at):
		refit_view.note_done_press()
		run.close_refit()
		_show_state()
		return
	if refit_view.is_back_pressable(at):
		refit_view.open_slot(-1)
		return
	var s := refit_view.slot_at(at)
	if s >= 0:
		refit_view.note_slot_press(s)
		refit_view.open_slot(s)
		return
	if not refit_view.is_board_open():
		return
	# ⚠ What the strip opens is a BEAST TYPE, not a summon slot (티켓 11) — this value goes straight
	# into the type-keyed `fit` / `unfit` / `first_empty`, so all five species take equipment here.
	var open_beast := refit_view.open_slot_index()
	var row := refit_view.held_at(at)
	if row >= 0:
		refit_view.note_held_press(row)
		# ⚠ **The CELL is read before `fit` runs**, not after: `first_empty` is where the card is about
		# to land, and once `fit` returns that cell is full and the answer has changed. (It used to
		# read the card's own part, which named its target back when cells had names.)
		var landing_cell := run.army.loadout.first_empty(open_beast)
		if run.army.loadout.fit(open_beast, row):
			refit_view.note_fitted(landing_cell)
		return
	var part := refit_view.cell_at(at)
	if part >= 0:
		refit_view.note_cell_press(part)
		run.army.loadout.unfit(open_beast, part)


## 시작하기: a brand new run. **`Run.restart()` is not called here** — a fresh `Run` is what 시작하기
## means, and `restart` stays alive for `net_run` to keep `_reset` honest about fields added to one
## path and not the other.
func _start_run() -> void:
	run = Run.new()
	# ⚠⚠ **THE TITLE GOES DOWN HERE, AND UNTIL 티켓 12 IT WENT DOWN INSIDE `_enter_pick_screen`.**
	# That was safe only while every run opened on the card round. A run opens on the ISLAND now, and
	# `_open_island` never touched this flag — so left where it was, **the title sat drawn on top of
	# the one screen this week is about.** The press is what ends the title, not whichever screen the
	# press happens to lead to, and this is the line the press owns.
	title_view.visible = false
	# ⚠ **`_show_state()` and not a hard-wired screen** — the run decides, and the run opens on the
	# island (티켓 12). Hard-wiring `_open_island()` here would put the screen choice in two places.
	_show_state()


## The three cards go up (`Rules.CARDS_PER_WIN`). The island stops being drawable and the panel goes
## with it, so a card press can never land on an invisible roster underneath.
##
## ⚠ **This said "six cards" and named `_enter_map_screen` until 2026-08-27.** Six was the count
## before 2026-08-24 and `_enter_map_screen` was deleted with the map.
func _enter_pick_screen() -> void:
	battle = null
	field_view.setup(null, null, [])
	_disarm()
	hud_view.bind(null)
	panel_view.bind(run, null)
	reward_view.bind(run)
	# ⚠ **The title is NOT taken down here any more** (티켓 12). It moved to `_start_run`, which is the
	# only way onto any of these screens — and this screen stopped being the first one a run opens on,
	# so a line here would have covered the card round and left the island uncovered.


## The two taken cards are ready to be laid into a board.
func _enter_refit_screen() -> void:
	battle = null
	field_view.setup(null, null, [])
	_disarm()
	hud_view.bind(null)
	panel_view.bind(run, null)
	refit_view.bind(run)


## The panel is asked first, and it is asked through `panel_active()` rather than through a state
## check written out again here. Its rectangle exists whether it is drawn or not, so routing a click
## into the panel during a battle would press an invisible button.
##
## Then, in this order and the order is not arbitrary:
##
##  1. **the start button**, which is HUD chrome and therefore sits ON TOP of the island — at
##     `ZOOM_MIN` the island band and the button's rectangle overlap in one corner, and chrome that
##     loses to what it is drawn over is chrome that cannot be pressed;
##  2. **a placed boat's landing ring** (`_ring_hit_at`), which undoes that drop;
##  3. otherwise a camera pan.
##
## ⚠ **There used to be a fourth: a soldier still standing at the harbour, which began a drag.** The
## drag is deleted (*"ㅇㅇ 지워줘"*) and `_soldier_hit_at` with it. The summon consumes the press when a
## slot is armed, so a press that reaches the bottom of this list is always a pan now.
##
## ⚠ **There is no post-commit branch left at all.** The speed chips used to sit between 1 and 2 as
## the one thing pressable after the commit; `speed-off-open-landing` deleted them, so every branch
## above is inside `not battle.committed()` and a committed fight falls straight through to the pan.
##
## ⚠ **2 before 3 is measured, not tidy.** A landing ring can sit on top of the harbour when a player
## drops a boat onto the beach beside it, and undo losing to grab is the worse failure: a grab that
## should have been an undo starts a drag the player then has to cancel, whereas an undo that should
## have been a grab is one press to recover.
##
## ⚠ **Two of the three PLAN BRANCHES the commit gate lives on are here** (1 with 2 and 3), and it is
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
				hud_view.note_chip(HudView.CHIP_START, battle.commit())
				return
			var uid := _ring_hit_at(at)
			if uid >= 0:
				battle.recall(uid)
				return
			# ⚠ **The summon sits between the ring and the soldier because it CONSUMES the press.**
			# With a slot armed, `_begin_summon` answers every press on the field — so anything with a
			# specific target has to be asked first or it can never be reached, and losing an undo is
			# the worse failure, the same argument this file already makes for "2 before 3". Below the
			# harbour stack it would be unreachable wherever the stack sits over the band.
			#
			# ⚠⚠ **The geometric argument that used to stand here was FALSE and is corrected rather
			# than deleted**, because the false number is the shape that has bitten this repo four
			# times (a radius of 8 cited as 8 px, reaching the screen at 38). It read *"a landing ring
			# is 18 px around a LAND tile and can overlap the water beside it"*. It cannot:
			# `_ring_hit_at` converts the press to WORLD px first, `TARGET_RING_R_PX` is 18.0 and
			# `TILE_PX` is 40.0, so the hit circle is **strictly inside its own land tile** (half-width
			# 20) and is disjoint from the nearest water tile by 2 px. The ring and the band cannot
			# overlap at all — the ordering is right, and it was right for a different reason.
			# ⚠ **It CONSUMES the press** (`sea-summon`, question 8): with a slot armed, a press outside
			# the band marks a refusal instead of silently starting a pan. The wheel stays ungated and
			# the same number key disarms, which is what that costs and what pays for it.
			if _armed_slot >= 0:
				_begin_summon(at)
				return
		# ⚠⚠ **THE WALK ORDER, AND IT SITS OUTSIDE THE `not committed()` BLOCK ON PURPOSE.** Everything
		# above is the PLAN — it stops answering the moment the fight starts. Commanding a body is the
		# opposite: it is the whole of the hand during a fight (「손이 논다고 했는데 배드노스 보니까 손이
		# 놀면 안될듯」, 2026-08-25), so it has to answer on both sides of the commit.
		# ⚠ **Below the summon and above the pan.** Below the summon because an armed slot consumes
		# every press; above the pan because the pan is the fall-through that means「the press hit
		# nothing」, and a press that ordered somebody hit something.
		if _order_walk_at(at):
			return
	_panning = true


## Ends whichever gesture was in flight. A soldier drag either sends — `battle.send` is the single
## source of truth `grid.home_harbour_for` already agrees with, and the droppable tint on screen is
## drawn from that same call, so the picture can never promise a tile the sim then refuses — or
## cancels, silently, because the ring under the cursor was already `COL_LOSE` and the refusal was
## readable before the button came up.
##
## ⚠ **`send` returns an int uid and uid 0 is the FIRST boat of every island**, so `if battle.send(…)`
## would refuse the common case. The return is compared `< 0` and NOT read as a bool.
##
## ⚠⚠ **The refusal mark is driven by `send`'s own -1** (`speed-off-open-landing`, 2.5). The green
## coast wash used to be what made the screen's promise honest — it was painted from
## `grid.home_harbour_for(t) >= 0`, the exact call `send` refuses on — and question C deleted it, so
## the mark inherits that guarantee from the other end: it is drawn when and only when the SIM said
## no, never from a predicate this file evaluates for itself. A release off the grid (`tile < 0`)
## marks too — from the player's hand that is the same gesture and the same answer.
##
## ⚠ **This used to hold the drag's release — the third PLAN BRANCH the commit gate lived on.** With
## the drag deleted the only thing left here is ending the summon press and dropping the pan, and both
## are unconditional: there is nothing left that could author a landing on a release.
## Whether the right button is down and the board is being turned by the mouse, and where the last
## motion left it. **Two plain fields and no state machine**: a drag is a button and a previous point.
var _turning := false
var _turn_from := Vector2.ZERO


func _on_left_release(at: Vector2) -> void:
	if _summon_down:
		# **The slot stays ARMED**, so the next press streams again with no key press in between. Only
		# the aim's tile is cleared; the arm is a mode and the press is the gesture.
		_summon_down = false
		_summon_at = -1
		field_view.set_summon_aim(_armed_slot, -1)
	_panning = false


# --- the summon (sea-summon) ----------------------------------------------------------------------

## A number key. `1`..`5` arm a slot; the same key disarms it; anything else falls through.
##
## ⚠⚠ **The `echo` guard is not optional.** OS auto-repeat on a held number key delivers
## `pressed = true, echo = true` many times a second, and without this the arm would toggle on and off
## silently for as long as the key is down.
##
## ⚠ **`battle.committed()` is seam #2 of `sea-summon`'s OPEN question 1** — a live-fire version takes
## this test out and the slot row keeps drawing. It is not padding: after the commit there is nothing
## a slot could place, and an arm that survived would consume every field press for the rest of the
## fight (see `_on_left_press`).
##
## **Unbound and dry are ONE test**, because `slot_reserve_ids` is empty for both — and they are the
## same sentence to the player. The refusal goes to the HUD as a shake on that slot's own box, which
## is the only thing separating "that key did nothing because the slot is empty" from "that key did
## nothing because the game is not listening".
## Q turns the board one notch anticlockwise, E one notch clockwise. **Returns whether it took the
## key**, so the summon keys below never see one that was already spent.
##
## ⚠ **Raw keycodes and no `[input]` action**, the same rule the summon keys keep: there is no
## `[input]` section in `project.godot` and none is added, so what a check drives is this shell rather
## than a settings file.
func _on_turn_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	if key.keycode == KEY_Q:
		field_view.turn_by(-Look.CAM_YAW_STEP_DEG)
		return true
	if key.keycode == KEY_E:
		field_view.turn_by(Look.CAM_YAW_STEP_DEG)
		return true
	# ⚠ **R and F tilt, and they are ungated exactly as Q and E are** (2026-08-24, the user: 「기울기도
	# 조절 되었으면 좋겠네」). R stands the camera up toward looking straight down; F lays it over toward
	# the horizon. Same argument as the turn: it changes what is visible and nothing that happens.
	if key.keycode == KEY_R:
		field_view.tilt_by(Look.CAM_PITCH_STEP_DEG)
		return true
	if key.keycode == KEY_F:
		field_view.tilt_by(-Look.CAM_PITCH_STEP_DEG)
		return true
	return false


func _on_summon_key(key: InputEventKey) -> void:
	if key.echo:
		return
	if battle == null or battle.committed():
		return
	var slot := _slot_of_keycode(key.keycode)
	if slot < 0:
		return
	# ⚠⚠ **A KEY WITH NO BOX BEHIND IT DOES NOTHING AT ALL — not even a refusal mark.** This used to
	# treat 「빈 칸」 and 「마른 칸」 as one case and stamp the refusal on both, which was correct while
	# every slot in the constant table was drawn. The row is as long as the RUN now, so a mark on an
	# unregistered slot lands where there is no box: something on screen shakes that is not there.
	if battle.army == null or slot >= battle.army.slot_count():
		return
	if slot == _armed_slot:
		_disarm()
		return
	if battle.slot_reserve_ids(slot).is_empty():
		hud_view.note_chip(HudView.CHIP_SLOT_BASE + slot, false)
		return
	_arm(slot)


## `KEY_1`..`KEY_5` -> 0..4, and -1 for everything else. A table rather than arithmetic on the
## keycode: the five values are not guaranteed contiguous by anything this file controls.
func _slot_of_keycode(code: int) -> int:
	match code:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
	return -1


## Arms `slot`, or clears the arm. **Two functions, one place each**, and both tell the HUD and the
## field in the same breath — so the box that is drawn green and the band that answers a press can
## never name two different slots.
func _arm(slot: int) -> void:
	# ⚠⚠ **THE DRAG-CANCEL THAT USED TO BE HERE IS GONE WITH THE DRAG ITSELF.** It read
	# `_drag_soldier = -1; field_view.set_drag(-1, -1)`, and it was the fix for a measured signature
	# fake: arming mid-drag froze the candidate ring on one tile while `_on_left_release` handed
	# `battle.send` another (screen 1461, sim 146). **There is no drag to cancel now** — the gesture,
	# its state and its ring are all deleted — so the two lines are removed rather than left as a
	# no-op on a field that no longer exists.
	_armed_slot = slot
	hud_view.set_armed(_armed_slot)
	field_view.set_summon_aim(_armed_slot, _summon_at)


## ⚠ **`_summon_beat_sec` is deliberately NOT reset here**, and it is not an oversight. The beat only
## runs while `_summon_down` is true, and the only thing that sets that is `_begin_summon` — which
## writes the accumulator in the same breath. A `_summon_beat_sec = 0.0` here would also be caught by
## `net_draw_leaf`'s literal scan as a hardcoded duration in the shell, which is exactly the shape the
## explicit type on its declaration exists to keep that scan biting.
func _disarm() -> void:
	_armed_slot = -1
	_summon_down = false
	_summon_at = -1
	hud_view.set_armed(-1)
	field_view.set_summon_aim(-1, -1)


## Begins the stream. **One body leaves on the frame of the press**, not one cadence later — Swink's
## bound on input-to-response is under 100 ms and `SLOT_HOLD_SEC` is 200.
func _begin_summon(at: Vector2) -> void:
	_summon_down = true
	_summon_cursor = at
	_summon_at = _tile_at(at)
	field_view.set_summon_aim(_armed_slot, _summon_at)
	_fire_one_summon()
	_summon_beat_sec = Look.SLOT_HOLD_SEC


## One beat's worth. **The refusal mark is driven by `Battle.summon`'s own -1 and by nothing else** —
## the same guarantee the drag's mark carries, so this file can never deny a tile the sim allows.
##
## ⚠ **Once per BEAT and never once per frame.** 「더 없다」 is a picture, not a silence, and a mark
## fired every frame is a solid disc rather than a blink.
## ⚠ The position comes from the raw cursor point rather than from `_summon_at`: a press off the grid
## is `tile == -1`, which is a refusal that still has to draw its mark somewhere.
func _fire_one_summon() -> void:
	if battle.summon(_armed_slot, _summon_at) >= 0:
		return
	field_view.note_refusal(field_view.screen_to_terrain_px(_summon_cursor))


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
	var world := field_view.screen_to_terrain_px(at)
	var i := battle.boats.size() - 1
	while i >= 0:
		var boat: Dictionary = battle.boats[i]
		var centre := Look.tile_point_px(battle.grid.tile_point(int(boat["target"])))
		if centre.distance_to(world) <= Look.TARGET_RING_R_PX:
			return int(boat["uid"])
		i -= 1
	return -1


## **Sends the body under the player's command to the tile that was pressed.** True when somebody was
## actually ordered, which is what tells the caller the press was consumed.
##
## ⚠⚠ **It orders the body NEAREST THE PRESS and not「the first one ashore」.** With one body the two
## are the same sentence and the difference cannot be seen; with two it is the difference between
## commanding what you are looking at and commanding whatever happens to sit lowest in the roster.
## **The whole cost of getting it right today is this loop**, and getting it wrong would read as a
## random body answering the click.
## ⚠ **This is not a squad.** Squads do not exist (2026-08-27, the user: 「칸단위 부대는 따로 없음
## 아직」) — when they do, this is the function that grows a selection instead of a nearest-body rule.
func _order_walk_at(at: Vector2) -> bool:
	if battle == null:
		return false
	var tile := _tile_at(at)
	if tile < 0:
		return false
	var here := Vector2(float(tile % battle.grid.w), float(tile / battle.grid.w))
	var who := -1
	var best := INF
	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		var d: float = (battle.soldier_pos[i] as Vector2).distance_to(here)
		if d < best:
			best = d
			who = i
	if who < 0:
		return false
	return battle.order_walk(who, tile)


## A screen press converted to the tile it landed on, or -1 off the grid — the one function every
## boat hit-test and every drag update goes through, so a click and the overlay it is compared against
## can never disagree about which tile the cursor is over.
func _tile_at(at: Vector2) -> int:
	if battle == null or battle.grid == null:
		return -1
	var world := field_view.screen_to_terrain_px(at)
	var tv := field_view.world_to_tile(world)
	if tv.x < 0 or tv.y < 0 or tv.x >= battle.grid.w or tv.y >= battle.grid.h:
		return -1
	return battle.grid.tile_index(tv.x, tv.y)


## Zooms the field about `at`, keeping the world point under the cursor fixed
## (`field_view.zoom_at`). Refused while the panel is up, same as the drag.
##
## ⚠ **This is NOT gated on the commit and must not be, and it is not gated on the ARM either.** It
## holds no plan gesture — it reads exactly the same before and after the start button, and with a
## summon slot armed or without one — and gating it turns the "the camera still works during the
## fight" row red, which is the one row that stops the "the hand does nothing after the commit" rows
## from being satisfied by a screen that does nothing at all.
## ⚠⚠ **It is also the whole mitigation for `sea-summon`'s question 8**: an armed slot consumes every
## field press, so a left-drag no longer pans while one is armed. The wheel and the disarming key are
## what a player who armed a slot and then wanted to look around has left.
## `plan-then-watch`, section "Input": **five plan branches are gated, not six** — the drag's press,
## motion and release, plus `sea-summon`'s summon key and summon press.
##
## ⚠ At `ZOOM_MIN` the map is narrower than the visible world on BOTH axes, so a PAN cannot move the
## camera at all — `_clamp_cam` centres both. That is the framing the user asked for (「조금 더 카메라를
## 뒤로 빼야 될」) and not a defect: there is nothing off screen to pan to. The wheel is what unlocks
## the pan, which is also the mitigation for an 18 px tile being a small drop target.
func _on_wheel(at: Vector2, factor: float) -> void:
	if panel_view.panel_active():
		return
	field_view.zoom_at(at, factor)


## Restart, which the panel resolves. `button_hit` is false outside WON/LOST, so this needs no state
## test on this side.
## ⚠⚠ **THE REWARD PICK USED TO BE THE OTHER HALF OF THIS FUNCTION** and is deleted (2026-08-25, the
## user: 「부리 보상 없지 끝나면 카드보상으로 통일했잖아」). With it went the hold this handler took
## before telling the sim — there is nothing left here that has to be shown before it is applied.
func _click_panel(at: Vector2) -> void:
	# `_unhandled_input` already refuses every real press during a hold. This second guard is for the
	# callers that skip it — a net drives this handler directly, because headless the window is 64x64
	# and a pushed click lands thousands of pixels off target.
	if _hold_sec > 0.0:
		return
	if panel_view.button_hit(at):
		# ⚠ **Back to the TITLE, not to a fresh island.** `run == null` IS the title screen, so this is
		# one line — but `battle` must be nulled in the same breath or the island keeps drawing behind
		# it.
		run = null
		battle = null
		field_view.setup(null, null, [])
		hud_view.bind(null)
		panel_view.bind(null, null)
		title_view.visible = true

# ⚠ Three handlers are gone whole and none of them was replaced by an equivalent:
#  - `_click_dock` — a fixed dock stopped existing in `boat-and-landing`;
#  - `_on_key` — the 1/2 summon keys stopped existing in `plan-then-watch`, along with the whole
#    `InputEventKey` branch of `_unhandled_input`. ⚠⚠ **The BRANCH came back with `sea-summon` and
#    that handler did not**: `_on_summon_key` above arms a slot, where `_on_key` put a body straight
#    onto a boat. A key that selects and a key that spawns are not the same handler restored;
#  - `_boat_hit_at` / `_boat_grabbable` — they tested a HUD berth rect and an idle hull rect for a
#    FLEET SLOT, and there is no fleet;
#  - `_soldier_hit_at` — it tested the reserve stack for a DRAG, and the drag is deleted
#    (*"ㅇㅇ 지워줘"*). `_ring_hit_at` above is the only hit test a field press still gets, and the
#    summon consumes the press before it whenever a slot is armed.
