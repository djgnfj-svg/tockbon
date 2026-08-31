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
## ⚠⚠ **THE WHOLE SUMMON GESTURE WAS DELETED HERE** (2026-08-28, the user: 「게임플레이에서 시작버튼
## 하고 1은 왜있음? 이거 전 게임의 유산인듯 지워줘」). The start button, the 1~5 arming keys, the
## press-on-water that streamed bodies out of a slot, and the landing ring that undid one — all four
## belonged to the shape the game had **before the sides swapped**: the player authored a landing out
## of boats, pressed 시작, and then watched.
## ⚠ **They were not merely unused — they could not work.** `Battle.commit` refuses while `boats` is
## empty and the only thing that ever filled `boats` was `Battle.summon`, driven by those very keys.
## **The beasts arrive by boat now** and nothing in `src/` builds one yet (티켓 10).
## ⚠⚠ **`sim`'s boat and landing machinery is untouched on purpose** — it is what the beasts' own
## boats will drive, and deleting a working phase to re-type it in a fortnight is the trade this repo
## has already lost once.
##
## ⇒ **What the hand does on the island is command bodies**, and that is the one branch left in
## `_begin_press`. ⚠ **The island stays UNCOMMITTED** — a `commit()` was put in `_open_island` to
## replace the button and it won the island before its first frame; the reason is written there.
##
## ⚠⚠ **TAB REVEALS THE 판 WHILE IT IS HELD** (2026-08-28, the user: 「마우스올리면 호버되도록해주고
## 특정버튼 눌러야 그 뜨게해줘 판이」). It is the only key here read on BOTH edges, because a
## press-only branch would latch the board on — and what was asked for is a key you hold.


## Session state. **`null` IS the title screen** — there is no separate scene and no autoload, and
## `project.godot`'s `run/main_scene` is still `game.tscn`. Built by 시작하기, dropped by the panel's
## restart button.
var run: Run = null

## The island being fought, or the last island fought once it is over. **It is deliberately not
## cleared when an island ends**: on the reward pick, the win and the loss the field stays on screen
## behind the panel, and the loss screen has to keep showing enemies-left to say *why* it was lost.
var battle: Battle = null

## **What the player has hold of.** ⚠⚠ **The shell owns the object and decides NOTHING about it** —
## every rule about who may be picked, where they may go and what route they would walk lives in
## `Hand`, which is in `sim/` and drivable with `.new()`. This file only turns presses into its three
## verbs. **A selection rule written here would be a rule no net can reach.**
var hand := Hand.new()

## ⚠⚠ **`_pan_keys` STOOD HERE AND IT IS DELETED** (2026-08-31, the user: 「wasd 도 지워줘」). It was
## the WASD direction held down, written on each key's two edges and spent by `_process` against the
## frame's own delta — **held state and never one step per event**, because a key that panned per
## event moves at the OS's auto-repeat rate.
## ⚠ **The left-button drag is the only thing that moves the camera now.** The edge band went the
## same day, and the keys followed it.

## ⚠⚠ **`reward_view` AND `refit_view` STOOD HERE AND BOTH ARE DELETED** (2026-08-28, the user:
## 「고르는 창도 이제 필요 없는데 왜있지? 이것도 제거」 · 「둘 다 지우면 돼」) — the three-card screen
## and the board the taken cards were laid into. `Run.State.PICK` and `Run.State.REFIT` went with
## them, and so did the two whole input tables below.
var field_view: FieldView = null
var hud_view: HudView = null
var title_view: TitleView = null

## True while a left-button drag on the FIELD is moving the camera. ⚠ **It used to be mutually
## exclusive with `_drag_soldier`** — a press grabbed a soldier XOR began a pan — and the soldier drag
## is deleted, so a press that orders nobody is now always a pan.
##
## ⚠ **The pan is NOT gated on the commit.** Camera pan and zoom stay live for the whole fight on
## purpose: they change nothing about what happens, and watching is the entire activity — removing
## them would turn 결정 4's 「pausing doesn't let me do anything more」 into 「and you cannot even
## look」. It is also the row that stops the post-commit checks from being satisfied by a dead screen.
var _panning := false
## Where the left button went down, and whether it is still down with nothing decided yet.
##
## ⚠⚠ **THE ORDER MOVED FROM THE PRESS TO THE RELEASE, AND THAT IS THE WHOLE FIX.** It used to be
## issued the instant the button went down, and a press on land therefore never became a pan — see
## `Look.DRAG_PAN_THRESHOLD_PX` for what that measured as on screen. **A press cannot know yet which
## gesture it is**, so it decides nothing and waits: travel past the threshold makes it a pan, a release
## in place makes it the order it always was.
var _press_at := Vector2.ZERO
var _press_open := false
## ⚠⚠ **`_press_orders` STOOD HERE AND IT IS DELETED** (2026-08-30, the same round that put the yaw
## drag back on the right button). It said whether the press in flight commands a body on a release in
## place, and it existed for exactly one reason: **both buttons opened the same press**, so something
## had to tell them apart without keeping a button index.
## ⚠ **The right button no longer opens a press at all** — it turns the board — so this flag could
## only ever be `true`, and a gate that can only be true is not a gate, it is a deleted branch waiting
## to be noticed. **What kept the right button from commanding is now the wiring itself.**

## ⚠⚠ **`_pointer_inside` AND `_window_focused` STOOD HERE AND BOTH ARE DELETED**
## (2026-08-31, the user: 「화면 끝에 마우스 뒀을 때 이동되는 로직 ... 그것도 지워줘」). They were the two
## flags that stopped the camera sliding while the player alt-tabbed away, and they existed for the
## edge pan and for nothing else. **The edge pan is gone, so what read them is gone** — the
## left-button drag and the right-button turn are the whole camera now.

## **Where the pointer was last seen.** ⚠⚠ **IT WENT WITH THE EDGE PAN ON 2026-08-31 AND CAME BACK ON
## 2026-09-01**, when `pick-then-move` merged onto the branch that had deleted it. It is not the edge
## pan's field any more: **`_process` rebuilds the 이동선 from it every frame**, because the picked body
## walks and the board slides under a cursor that never moved. ⚠ **The motion handler is its only
## writer**, exactly as before.
var _pointer_at := Vector2.ZERO

## ⚠⚠ **`_hold_sec` STOOD HERE AND IT IS DELETED** (2026-08-29) with the verdict. It held the last
## frame of a finished island on screen before the next `setup()` emptied the view's effect drawers —
## **without it the last death ring never got a frame at all.** It also cancelled any gesture in
## flight, rather than merely suppressing it: suppression leaves the pan flag set, and the very next
## motion after the hold resumes a gesture that was supposed to be cancelled.

func _ready() -> void:
	field_view = FieldView.new()
	hud_view = HudView.new()
	title_view = TitleView.new()
	add_child(field_view)
	add_child(hud_view)
	add_child(title_view)

	# ⚠ **No `Run` is built here and no island is opened.** The game opens on the title, and the two
	# lines that used to be here are exactly what 「켜면 섬이 떵하니 나온다」 named.
	run = null


## Opens the island `run` is standing on and re-points all three views at it.
##
## ⚠ **`begin_island()` used to answer null on a screen that was not the island, and this function
## left the last island drawable in that case.** There are no other screens; it answers a `Battle`
## every time now, and the null arm is kept as a guard rather than as a state.
func _open_island() -> void:
	var opened := run.begin_island()
	if opened != null:
		battle = opened
		# ⚠ **A hand holding bodies from the last island would light a reach built on the last GRID.**
		# The ids survive an island; the 조각 they were measured against do not.
		_let_go()
		# ⚠⚠ **A `battle.commit()` STOOD HERE FOR ONE ROUND AND IT WAS WRONG** (2026-08-28), and the
		# commit itself is deleted now (2026-08-29) with the fight. **What it cost is worth keeping:**
		# launched with the commit here, the island was **won before the first frame reached the
		# screen** — the verdict sat behind that gate, the island file has no beasts, and 「every beast
		# is dead」 is true of an island that never had one.
		# A fresh `Grid` and a fresh `Battle`, but the SAME `Army` — the army handed to the field is
		# `run.army`, the same object `begin_island` just gave the battle; rebuilding it anywhere would
		# heal the run while a check that only counted soldiers stayed green.
		#
		# The field is handed the island's legend ROWS as well, because `grid.passable` is one byte and
		# water and a hole are both 0 in it: coloured from passability alone the sea and the pits come
		# out the same tone and the map reads as one shape.
		field_view.setup(battle, run.army, Islands.rows())
		hud_view.bind(battle)


## ⚠⚠ **`_close_island` AND `_show_state` STOOD HERE AND BOTH ARE DELETED** (2026-08-29) with the
## verdict. One asked the battle whether the island was won and told the run; the other was the single
## mapping from a run state to a screen. **There is one screen and no verdict**, so `_start_run` opens
## the island directly.
## ⚠ **When waves arrive, the mapping comes back as a function and not as a branch at each call site**
## — that was the whole reason `_show_state` survived its last two arms being deleted.


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
	# ⚠⚠ **A PAN WAS SPENT HERE EVERY FRAME AND IT IS DELETED** (2026-08-31). Two screen-space
	# velocities — the WASD keys and the window's edge band — were summed and pushed through ONE
	# `field_view.pan_by` above the `battle == null` guard, so the camera kept working on a frame the
	# sim was not running. **Both sources are gone**, and the drag that replaced them moves the camera
	# from `_unhandled_input` rather than from the clock, so nothing needs a per-frame call.
	# ⚠ **`pan_by` still ends in the clamp** — that is the drag's bound too, and it is untouched.
	# ⚠⚠ **THE 이동선 IS REBUILT EVERY FRAME AND NOT ONLY ON MOTION.** Its first point is the picked
	# body's OWN position, and that body walks — built once on hover, the line stayed anchored where he
	# used to be and trailed behind him across the island.
	# ⚠⚠ **THIS IS WHY `_pointer_at` CAME BACK** (2026-09-01, merging `pick-then-move` onto the branch
	# that deleted the edge pan). The pan deleted above was its only other reader, and the tombstone
	# beside it says so — but a still cursor over a walking body is still a changing route, and the
	# left-button drag moves the board under a still cursor too. **「the pointer has not moved」 never
	# meant 「the route has not changed」.**
	# ⚠ **It is cheap**: `Hand.routes` caches the 조각 list per destination, so this re-reads positions
	# rather than rebuilding a flow field.
	_show_route(_pointer_at)
	# ⚠ **No multiplier is handed down any more.** `speed-off-open-landing` deleted the ladder, so the
	# sim and both views run on the bare frame delta — which is what every duration in `look.gd` was
	# budgeted against in the first place. `set_time_scale` and `set_speed` are gone rather than being
	# called with a constant 1.0: a leaf handed a constant is the shape 「No fake code」 names.
	if battle == null:
		return
	# ⚠ **A BARE delta, and the call keeps taking one.** `speed-off-open-landing`'s 「what does NOT
	# come out」 pins this: do not inline a constant anywhere, because the seam a multiplier plugs back
	# into is the thing worth preserving. `Battle.step` still consumes whole `Rules.SIM_SUBSTEP_SEC`
	# sub-steps and carries the leftover, so `step(dt)` and `step(dt/k)` k times still land on
	# identical state — which is the property the restored multiplier would stand on.
	battle.step(delta)


## ⚠ **`_release_hold` stood here and it is deleted** with the hold. It closed the island that had
## been left standing on screen while the last death ring played out.


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
	# ⚠⚠ **The `PICK` and `REFIT` branches sit ABOVE the `battle != null` block.** Below it, a click on
	# a card or a cell falls through to `_panning = true` — the field is `null` on both these screens,
	# but `_begin_press` does not know that until it gets there.
	# ⚠⚠ **THE `PICK` AND `REFIT` BRANCHES STOOD HERE AND BOTH ARE DELETED** (2026-08-28) with the
	# screens they routed to. They sat ABOVE the `battle != null` block on purpose — below it, a click
	# on a card fell through to `_panning = true`.
	# ⚠⚠ **THE 1~5 ARMING KEYS ARE DELETED AND THE CAMERA KEYS ARE ALL THAT IS LEFT** (2026-08-28).
	# They armed a summon slot, and the slot boxes they named are gone with the start button.
	# ⚠ Raw keycodes off the event and no `[input]` action: there is no `[input]` section in
	# `project.godot` and none is added, so what a net drives is the shell rather than a settings
	# file. Numpad keycodes and rebinding are out of scope.
	if event is InputEventKey:
		var key := event as InputEventKey
		# ⚠⚠ **THE REVEAL KEY IS READ ON BOTH EDGES AND IT IS THE ONLY KEY HERE THAT IS**
		# (2026-08-28, the user: 「특정버튼 눌러야 그 뜨게해줘 판이」). Holding TAB shows the whole 판;
		# letting go hides it again. **A press-only branch would latch the board on**, which is a
		# toggle and not what was asked for.
		# ⚠ **The echo guard matters here too**: OS auto-repeat delivers a stream of `pressed` events
		# while the key is held, and each one would re-write the same uniform every few milliseconds.
		if key.keycode == KEY_TAB and not key.echo:
			field_view.set_pads_revealed(key.pressed)
			return
		# ⚠⚠ **ESC LETS GO OF THE HAND** (2026-08-31, the user: 「esc누르면 선택 취소되니?」 — it did
		# not). ⚠ **Pressed edge only, unlike TAB**: this is one action and not a state held for as
		# long as a key is, so the release edge has nothing to undo.
		# ⚠ **It sits above the turn keys** so a press cannot both let go and move the board, and above
		# the `not key.pressed` return so the branch is reached at all.
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			_let_go()
			return
		# ⚠⚠ **THE WASD BRANCH STOOD HERE AND IT IS DELETED** (2026-08-31). It was read on BOTH edges,
		# like TAB and unlike everything left in this handler, and it sat ABOVE the `not key.pressed`
		# return for that reason — a held key never told it was released pans forever. **TAB is the
		# only two-edged key left.**
		if not key.pressed:
			return
		# ⚠⚠ **Tilting is not gated on anything**, on purpose — 티켓 07 asks whether a hand may move
		# the board mid-fight, and gating it before the question is decided would answer it by
		# omission (2026-08-24, the user: 「3D 회전 회전 버튼이 내가 돌려봐야 될 듯」).
		# ⚠ **The turn keys stood beside the tilt here and are deleted** — see `_on_tilt_key`.
		_on_tilt_key(key)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# ⚠⚠ **THE WHEEL TURNED THE BOARD FOR ONE ROUND AND IT IS THE ZOOM AGAIN** (2026-08-30 morning,
		# the user: 「마우스 휠이 회전 오른쪽이 끌어서 이동으로 해야할듯」; the same day at the screen,
		# reversing it: 「마우스 휠이 확대 축소가 맞고, 오른쪽 버튼은 카메라 회전으로 이해했어」).
		# **The later word wins and the earlier one is kept here rather than erased.**
		# ⚠ **The yaw drag went back onto the right button** — see `_turning`. Q and E turned by a notch
		# beside it for one week and are deleted (2026-08-31); the drag is the only turn left.
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			_on_wheel(click.position, 1)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			_on_wheel(click.position, -1)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			# **The left button commands on a release in place, and it is the only button that opens a
			# press at all** — see the tombstone where `_press_orders` stood.
			if click.pressed:
				_begin_press(click.position)
			else:
				_end_press()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# ⚠⚠ **RIGHT-DRAG TURNS THE BOARD. IT PANNED FOR ONE ROUND AND THAT IS REVERSED**
			# (2026-08-30 morning, the user: 「오른쪽이 끌어서 이동으로 해야할듯」; the same day at the
			# screen: 「오른쪽 버튼은 카메라 회전으로 이해했어」). **The later word wins.**
			# ⚠ **It does not go through `_begin_press` at all**, which is what makes 「a right drag
			# over the island never commands a body」 true by construction rather than by a flag: the
			# right button opens no press, so there is no release in place for `_end_press` to turn
			# into a walk order.
			_turning = click.pressed
			_turn_from = click.position
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# ⚠⚠ **THE POINTER IS RECORDED HERE, AND THE 이동선 IS ITS ONLY READER NOW.** It was the edge
		# pan's line and was deleted with it (2026-08-31); it came back on 2026-09-01 for the route,
		# which `_process` rebuilds every frame because the picked body walks. **It sits above the
		# turn's early return** so a yaw drag does not leave the route reading a stale cursor.
		_pointer_at = motion.position
		# ⚠⚠ **THE YAW DRAG SITS ABOVE EVERYTHING ELSE**, because a turning drag is neither a hover
		# nor a pan.
		# ⚠ **Horizontal travel only.** Adding the vertical axis to the tilt here was tried on paper
		# and dropped: R and F step the tilt, and a drag that changed two things at once made every
		# accidental diagonal a lost camera the user then had to fix by hand.
		# ⚠ **Measured from the LAST motion and not from the press point**, so the yaw follows the hand
		# continuously — a delta taken from the press would re-apply the whole travel on every event.
		if _turning:
			var dx := motion.position.x - _turn_from.x
			_turn_from = motion.position
			field_view.turn_by(dx * Look.CAM_YAW_PER_PX_DEG)
			return
		# The panel is asked here too, and not only on press: a drag begun on the field before the
		# panel opened must not keep panning (or sending) behind it once it does — `panel_active()`
		# becoming true mid-drag is what `_begin_press` alone cannot catch.
		# ⚠⚠ **THE HOVER PLATE, AND IT IS ASKED ON EVERY MOTION.** `_tile_at` answers -1 off the island,
		# which is exactly the value that hides the plate, so there is no second test for "is the mouse
		# on the ground". **It is set here and not inside the summon branch below** — the plate says
		# where the cursor is, which is true whether or not a slot is armed.
		field_view.set_hover_tile(_tile_at(motion.position))
		# ⚠⚠ **THE 이동선 IS BUILT ON HOVER AND NOT ON PRESS** (2026-08-31, the user: 「이동할때
		# 이동선이 미리 보였으면 좋겠네」). 미리 means before the press, so the only event that can carry
		# it is the motion — a line drawn on the press would appear at the same instant the walk does
		# and would be a picture of a decision already made.
		_show_route(motion.position)
		# ⚠ **The summon aim used to sit above the pan and consume every motion while a slot was
		# armed** (deleted 2026-08-28). With it gone a motion on the field is a pan or it is nothing.
		# **The threshold, and it is measured from the press point rather than accumulated per motion.**
		# ⚠ A sum of `relative` would let a hand that wanders out and back cross the threshold without
		# ever being far from where it started, which is a click that turns into a pan under the user.
		if _press_open and not _panning 				and motion.position.distance_to(_press_at) > Look.DRAG_PAN_THRESHOLD_PX:
			_panning = true
		if _panning:
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


## ⚠⚠ **`_pick_input` AND `_refit_input` STOOD HERE AND BOTH ARE DELETED** (2026-08-28, the user:
## 「고르는 창도 이제 필요 없는데 왜있지? 이것도 제거」 · 「둘 다 지우면 돼」), with the two screens
## they drove.
##
## ⚠ **One rule in them is worth keeping and is written down here rather than lost**: *whether a card
## may be taken was asked of the SIM* — `reward_view.is_card_pressable` called the same predicate
## `run.take_card` refused on, so the picture could never offer a card the sim would then reject. That
## is the same discipline `_press_the_island` keeps today by driving off the sim's own answer.


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
	# ⚠ **It was `_show_state()` until 2026-08-29**, so the run decided which screen a press led to.
	# **There is one screen**, and the indirection went with the states it chose between.
	_open_island()


## ⚠⚠ **`_enter_pick_screen` AND `_enter_refit_screen` STOOD HERE AND BOTH ARE DELETED**
## (2026-08-28). Each nulled the battle, emptied the field and bound its own screen; with the screens
## gone the only way off the island is `_open_island`, and `_start_run` calls it directly.


## The panel is asked first, and it is asked through `panel_active()` rather than through a state
## check written out again here. Its rectangle exists whether it is drawn or not, so routing a click
## into the panel during a battle would press an invisible button.
##
## Then, in this order and the order is not arbitrary:
##
##  1. **the walk order**, which is the whole of the hand on the island;
##  2. otherwise a camera pan.
##
## ⚠⚠ **THREE BRANCHES STOOD ABOVE THE WALK ORDER AND ALL THREE ARE DELETED** (2026-08-28): the start
## button, a placed boat's landing ring (which undid that drop), and the summon that consumed the
## press while a slot was armed. **They were the plan**, and the plan belonged to the game before the
## sides swapped — see this file's header.
## ⚠ **A fourth died before them**: a soldier standing at the harbour, which began a drag
## (*"ㅇㅇ 지워줘"*).
##
## ⇒ **The commit gate went with them and no branch here reads it any more.** The island commits
## itself at open, so `not battle.committed()` would now be false on every press this handler ever
## sees — a gate that can only be true is not a gate, it is a deleted branch waiting to be noticed.
##
## ⚠ **The walk order answers on both sides of the commit and always did** (「손이 논다고 했는데
## 배드노스 보니까 손이 놀면 안될듯」, 2026-08-25). It sits above the pan because the pan is the
## fall-through that means 「the press hit nothing」, and a press that ordered somebody hit something.
## ⚠⚠ **THE `orders` PARAMETER IS GONE** (2026-08-30). It told the two buttons apart while both of
## them opened this same gesture; **the right button turns the board now and never gets here**, so the
## only caller left is the left press and the only value it ever passed was `true`.
func _begin_press(at: Vector2) -> void:
	# ⚠ **Nothing is ordered and nothing is panned here.** Both are decided by what happens next — see
	# `_press_open`. A press that resolves to neither (no battle, no walkable 조각 under it) still ends
	# as a pan, which is what a press on open water has always done.
	_press_at = at
	_press_open = true
	_panning = false


## ⚠⚠ **`_turning` AND `_turn_from` WERE DELETED ON 2026-08-30 AND THEY ARE BACK THE SAME DAY.** The
## line that removed them is kept because this repo records a flip and does not erase the old one:
##
##  - 2026-08-26, the user: 「회전은 오른쪽 마우스 누르고 돌릴 수 있었으면 좋겠음」 — the yaw drag is born;
##  - 2026-08-30 morning, the user: 「마우스 휠이 회전 오른쪽이 끌어서 이동으로 해야할듯」 — the turn
##    moves onto the wheel and these two fields are deleted;
##  - 2026-08-30 at the screen, the user: 「마우스 휠이 확대 축소가 맞고, 오른쪽 버튼은 카메라 회전으로
##    이해했어」 — **reversed, and the later word wins.**
##
## ⚠ **`Look.CAM_YAW_PER_PX_DEG` is read again.** Its tombstone said it was left standing rather than
## deleted because re-deriving a measured per-pixel yaw costs a round; one round later that is exactly
## what it saved.
##
## **Two plain fields and no state machine**: a drag is a button and a previous point.
var _turning := false
var _turn_from := Vector2.ZERO


## Ends whichever gesture was in flight, and **dropping the pan is all that is left**.
##
## ⚠ **Two gestures ended here before it and both are deleted**: the soldier drag that authored a
## landing (2026-08-25), and the held summon press (2026-08-28).
## ⚠⚠ **THE `at` PARAMETER IS GONE** (2026-08-30). It was kept unread as the shell's own release
## signature; **the right button now ends the same gesture and its release position is unread too**,
## so the parameter had become a value two callers had to invent for nobody to read.
func _end_press() -> void:
	# **A press that never travelled is a click, and a click commands.** ⚠ **Ordered from the point the
	# button went DOWN and not from where it came up** — a hand that shifts two pixels while clicking
	# would otherwise command a different 조각 than the one it pressed on.
	# ⚠⚠ **NOTHING HERE ASKS WHICH BUTTON, AND THAT IS WHAT KEEPS THE RIGHT ONE FROM COMMANDING.**
	# Only the left press ever reaches `_begin_press`, so `_press_open` is already the answer to
	# 「was this a press that may command」 — see the tombstone where `_press_orders` stood.
	if _press_open and not _panning and battle != null:
		_press_the_island(_press_at)
	_press_open = false
	_panning = false


# --- the camera keys ------------------------------------------------------------------------------

## ⚠⚠ **`_on_pan_key` STOOD HERE AND IT IS DELETED** (2026-08-31, the user: 「wasd 도 지워줘」). It
## turned W/A/S/D into a held screen direction, **adding on the press and subtracting on the release**
## rather than writing the whole vector — writing it whole loses the other axis the moment two keys
## are held and one is let go.
## ⚠ **Its signs were the mouse drag's, not the camera's**, and that is the one thing worth carrying
## forward: `pan_by` takes the delta a DRAG delivers, so 「look right」 is a NEGATIVE x. The drag is
## now the only caller and it never had to convert.


## R stands the camera up toward looking straight down, F lays it over toward the horizon — one notch
## each. **Returns whether it took the key**, which is the honest answer to 「did this handler consume
## the event」 and what every net that drives a key reads.
##
## ⚠⚠ **Q AND E WERE THE KEYBOARD'S TURN AND THEY ARE DELETED** (2026-08-31, the user: 「QE 이거
## 기능제거해줘」). They stood here from 2026-08-24 (「3D 회전 회전 버튼이 내가 돌려봐야 될 듯」) and
## called the same `turn_by` the right-button drag calls. **The drag is untouched and is now the only
## way a player turns the board** — `Look.CAM_YAW_STEP_DEG` is left standing for the shot tool, which
## turns the camera itself. The tilt keys were never asked to go and did not.
##
## ⚠⚠ **The `echo` guard is not optional.** OS auto-repeat on a held key delivers
## `pressed = true, echo = true` many times a second, and a tilt per repeat rolls the camera over.
##
## ⚠ **Raw keycodes and no `[input]` action**: there is no `[input]` section in `project.godot` and
## none is added, so what a check drives is this shell rather than a settings file.
func _on_tilt_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	# ⚠ **R and F are ungated** (2026-08-24, the user: 「기울기도 조절 되었으면 좋겠네」). Same argument
	# the turn had: it changes what is visible and nothing that happens.
	if key.keycode == KEY_R:
		field_view.tilt_by(Look.CAM_PITCH_STEP_DEG)
		return true
	if key.keycode == KEY_F:
		field_view.tilt_by(-Look.CAM_PITCH_STEP_DEG)
		return true
	return false


# --- the edge pan is DELETED ----------------------------------------------------------------------

## ⚠⚠ **`_edge_pan_dir` AND `_edge_ramp` STOOD HERE AND BOTH ARE DELETED** (2026-08-31, the user:
## 「그것도 지워줘」). The pointer parked in a 28 px band against a side of the window slid the camera
## that way, faster the deeper it sat, and it was the user's own on 2026-08-30 (「wasd 보다는 마우스가
## 끝으로 가면 자동으로 이동이 맞을듯」) — **a week later they asked for it out.**
##
## ⚠ **What it took with it**: the band's three constants in `look.gd`, the remembered pointer, the
## alt-tab and mouse-exit flags with the `_notification` that set them, and the rows in `net_shell`
## that measured all of it. **Nothing about the walk order changed** — the band used to hold itself
## still for the length of a press so a click near the edge still commanded the 조각 under the finger,
## and with no band there is nothing left to hold still.


## **Sends the body under the player's command to the tile that was pressed.** True when somebody was
## actually ordered, which is what tells the caller the press was consumed.
##
## ⚠⚠ **`_order_walk_at` STOOD HERE AND IT IS DELETED** (2026-08-31). It ordered **the body nearest
## the press**, with no selection at all: one press, one walk, and whichever body happened to be
## closest answered it. Its own comment named the day it would die — 「when squads exist, this is the
## function that grows a selection instead of a nearest-body rule」 — and this is that function.
##
## **What the press does is decided by whether the hand is holding anybody, and by nothing else**
## (2026-08-31, the user: 「tab 없이 그냥 캐릭터를 누르면 이동할 수 있는 칸들이 뜨고 눌러서
## 이동하는거임」, then 「esc를 하지 않는 이상 이동 우선으로 해줘야할듯한데」):
##
##  - **empty hand** -> a press on a body picks it, and its reach lights;
##  - **full hand** -> a press on a lit 조각 is a walk, and a body standing there does not intercept it;
##  - **full hand, pressed anywhere else** -> nothing. **ESC is the only thing that lets go.**
##
## ⚠ **True means the press was consumed**, which is what tells `_end_press` it was not a pan — the
## same contract `_order_walk_at` had.
func _press_the_island(at: Vector2) -> bool:
	if battle == null:
		return false
	var tile := _tile_at(at)
	# ⚠⚠ **A FULL HAND MOVES; AN EMPTY HAND PICKS. THE BODY TEST CAME FIRST FOR ONE ROUND AND IT IS
	# REVERSED** (2026-08-31, the user at the screen: 「이게 조각에 옮길 수가 있잖아? 같은 조각으로?
	# 그때 살짝 불편하네? 이게 esc를 하지 않는 이상 이동 우선으로 해줘야할듯한데」).
	#
	# **The old line is kept rather than erased**: it read 「a body first, always」, and its reasoning
	# was that a picked body must stay re-pickable. **What it did on screen** is what killed it — a
	# 조각 with somebody standing on it is a 조각 you may want to send another body TO, and the body
	# test swallowed the press and picked the man already standing there instead. ⇒ **while the hand
	# holds anybody, a press on a lit 조각 is a walk and nothing else looks at it.**
	if not hand.is_empty():
		if tile >= 0 and hand.can_reach(tile):
			var sent := hand.order(battle, tile)
			# ⚠⚠ **THE ORDER LETS GO, AND IT KEPT HOLD FOR ONE ROUND** (2026-08-31, the user:
			# 「이동하면 그러면 그 이동관 관련은 꺼져야지」). The earlier line is kept because this repo
			# records a flip: **it re-picked the same bodies** so a second command needed no second
			# pick, reasoning from 「the hand never stops moving」. **What that ignored is that the board
			# then stays lit with nothing left to decide.**
			_let_go()
			return sent > 0
		# ⚠⚠ **A PRESS THAT CANNOT BE A WALK KEEPS THE HAND, AND ESC IS THE ONLY WAY TO LET GO**
		# (the user, same sentence: 「esc를 하지 않는 이상」). **The sea used to drop the selection here**
		# — which meant a hand aimed a little wide lost the body it had, and the player had to pick him
		# again to try the same order twice.
		return false
	# **An empty hand picks whoever was pressed**, and that is the only thing an empty hand does.
	var who := hand.body_at(battle, _point_at(at), Look.PICK_BODY_TILES)
	if who >= 0:
		var picked := hand.pick(battle, who)
		_tell_the_view()
		return picked
	return false


## **The one place the view is told what the hand is holding.** ⚠ Both halves go together on purpose:
## a reach pushed without clearing the stale route leaves a line pointing at a 조각 that is no longer
## lit, which is the picture disagreeing with the rule.
func _tell_the_view() -> void:
	field_view.set_reach(hand.reach)
	# ⚠⚠ **THE RIM GOES WITH THE REACH AND NOT SEPARATELY** (2026-08-31, the user: 「내가 누른 캐릭이
	# 티가 나야할듯함」). They are two halves of one sentence — 「this body, and these are its places」 —
	# and a rim pushed from anywhere else could outlive a reach that had already gone dark.
	field_view.set_picked(hand.ids)
	field_view.set_move_lines([])


## **Drops the selection and puts the board back to rest.**
func _let_go() -> void:
	hand.clear()
	_tell_the_view()


## **The 이동선 under the cursor, or nothing.** ⚠ **Nothing is drawn while the hand is empty or the
## cursor is off the reach** — a route to a 조각 the press would refuse is a line the game will not
## walk.
func _show_route(at: Vector2) -> void:
	if battle == null or hand.is_empty():
		return
	var tile := _tile_at(at)
	if tile < 0 or not hand.can_reach(tile):
		field_view.set_move_lines([])
		return
	field_view.set_move_lines(hand.route_points(battle, tile), hand.ids)


## **A screen press in 조각 units, fractions and all.** ⚠ **Not `_tile_at` rounded** — `Hand.body_at`
## measures a real distance to a body standing off the middle of its 조각, and a rounded point would
## throw away exactly the part that decides whether the press hit him.
func _point_at(at: Vector2) -> Vector2:
	return field_view.screen_to_terrain_px(at) / Look.TILE_PX


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


## **One wheel notch: it ZOOMS about `at`, and it does nothing else.**
##
## ⚠⚠ **THE WHEEL WAS MOVED ONTO THE TURN ON 2026-08-30 AND MOVED BACK THE SAME DAY** (the user, at
## the screen: 「마우스 휠이 확대 축소가 맞고」). The right button's yaw drag came back with it — see
## the block where `_turning` is declared, which carries all three of the user's words in order.
##
## ⚠⚠ **SHIFT+WHEEL IS DELETED AND IT WAS NEVER THE USER'S.** While the bare wheel turned the board,
## a previous builder pinned the zoom to SHIFT+wheel and wrote down that the pairing was **unowned** —
## nobody asked for it and nothing measured it. With the bare wheel zooming again it had nothing left
## to do, and **a second unowned path to one state is exactly what this file refuses to keep**: two
## gestures for one zoom drift apart the first time either is tuned.
##
## ⚠ **R/F is untouched.** It is the keyboard's tilt and goes through the same `tilt_by` the rest of
## the shell does — a second path to one state, never a second state.
## ⚠⚠ **Q/E stood beside it as the keyboard's turn and is deleted** (2026-08-31, the user: 「QE 이거
## 기능제거해줘」). **The right button's drag is the only turn.**
##
## ⚠ **The zoom keeps the world point under the cursor fixed** (`field_view.zoom_at`).
## ⚠ **`notch` and not a factor**: the caller has a wheel direction and this is the one place that
## knows a notch is `Look.ZOOM_STEP` in and its reciprocal out, so the two can never disagree.
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
func _on_wheel(at: Vector2, notch: int) -> void:
	field_view.zoom_at(at, Look.ZOOM_STEP if notch > 0 else 1.0 / Look.ZOOM_STEP)


## ⚠⚠ **`_click_panel` STOOD HERE AND IT IS DELETED** (2026-08-29) with the panel. It was the restart
## button, and the one path back to the title: **`run == null` IS the title screen**, so it was one
## line — but `battle` had to be nulled in the same breath or the island kept drawing behind it.
## ⚠ **Nothing returns to the title now.** That is a hole and it is written down rather than papered
## over: the title opens a run, and a run has no end.

# ⚠ Handlers that are gone whole, and none of them was replaced by an equivalent:
#  - `_click_dock` — a fixed dock stopped existing in `boat-and-landing`;
#  - `_on_key` — the 1/2 summon keys stopped existing in `plan-then-watch`. The `InputEventKey`
#    branch came back with `sea-summon` wearing `_on_summon_key`, and **both are deleted now**
#    (2026-08-28); what is left of that branch is the camera keys and nothing else;
#  - `_boat_hit_at` / `_boat_grabbable` — they tested a HUD berth rect and an idle hull rect for a
#    FLEET SLOT, and there is no fleet;
#  - `_soldier_hit_at` — it tested the reserve stack for a DRAG, and the drag is deleted
#    (*"ㅇㅇ 지워줘"*);
#  - `_ring_hit_at` — it undid a placed boat, and there is no boat the player places (2026-08-28);
#  - `_on_summon_key` / `_slot_of_keycode` / `_arm` / `_disarm` / `_begin_summon` / `_fire_one_summon`
#    — the whole summon gesture, deleted with the start button it was authored in front of.
#    ⇒ **`_press_the_island` is the only hit test a field press gets now.**
