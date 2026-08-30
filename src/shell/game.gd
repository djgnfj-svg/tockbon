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

## **Which pan keys are down right now**, as a screen-space direction. Written by `_unhandled_input`
## on the key's two edges, spent by `_process` against the frame's own delta.
##
## ⚠⚠ **HELD STATE AND NOT ONE STEP PER EVENT, AND THE DIFFERENCE IS THE WHOLE FEATURE.** A key that
## panned once per event would move the camera at the OS's auto-repeat rate — a pause, then a stutter,
## then a speed nobody chose and that differs per machine. **Panning is continuous or it is not
## panning**, and 「looking around for a boat」 is the one thing the camera now has to be good at
## (2026-08-30, the user: 「마우스 돌리다가 보이면 그때 가는 걸로」).
##
## ⚠⚠ **A NET CAN DRIVE THIS AND COULD NOT DRIVE `Input.is_key_pressed`.** The alternative was polling
## the input singleton from `_process`; headless, nothing can put a key down in it, so the whole
## feature would be unmeasurable — and `tests/README` already records half an input suite going green
## while the other half was dead. **The events come in through `_unhandled_input` like every other
## input this shell reads**, and a net hands it the same events the OS would.
##
## ⚠ **Diagonals are NOT normalised**, deliberately: W and D together move the camera 1.41 times as
## fast, which is what every drag already does — `pan_by` takes a screen delta and a mouse moving
## diagonally covers more ground too. Normalising here would make the keys disagree with the mouse.
var _pan_keys := Vector2.ZERO

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
## Whether the press in flight commands a body on a release in place. **The left button does; the
## right button only ever looks around.** ⚠ **It is not「which button」** — nothing below this line
## needs to know which one, and a button index kept here would be a second name for one bit.
var _press_orders := false

## **Where the pointer last was, in screen px** — read by the edge pan and by nothing else.
##
## ⚠⚠ **IT STARTS OFF-SCREEN AND THAT IS THE SAFE DIRECTION.** `(-1, -1)` is outside every band, so a
## shell that has never seen a motion pans nowhere. The alternative — starting at the middle — would
## be a made-up pointer position that happens to be harmless on one screen size.
var _pointer_at := Vector2(-1.0, -1.0)

## **Whether the pointer is over this window, and whether this window has the focus.**
##
## ⚠⚠ **A CAMERA THAT KEEPS SLIDING WHILE THE USER ALT-TABS IS THE CLASSIC VERSION OF THIS BUG.** The
## pointer's last known position stays in the band for as long as the player is away, so without these
## two the island would still be travelling when they came back.
##
## ⚠ **TWO FLAGS AND NOT ONE**, because the two causes end independently: alt-tab back with the
## pointer still outside the window must not resume the pan, and one flag would let a focus event
## clear a mouse-exit it knows nothing about.
## ⚠ **Both start true**, which is safe only because `_pointer_at` starts off-screen — nothing pans
## until a real motion arrives and says where the pointer is.
var _pointer_inside := true
var _window_focused := true

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
	# ⚠⚠ **THE PAN IS SPENT ABOVE THE `battle == null` GUARD, DELIBERATELY.** Below it the camera would
	# freeze on any frame the sim is not running, and looking around is exactly the thing that must not
	# stop being possible. ⚠ **`field_view.pan_by` ends in the clamp**, so a key held into the edge of
	# the roam ring stops there rather than running off — one path to the camera, the same one the drag
	# uses, and no second bound to keep in step.
	# ⚠⚠ **TWO SOURCES, ONE `pan_by`.** The keys and the edge band are added as screen-space
	# velocities and spent once — a second `pan_by` call in the same frame would clamp twice, and a
	# camera already sitting on the roam edge would then eat one of the two inputs silently.
	var vel := _pan_keys * Look.CAM_PAN_KEY_PX_PER_SEC + _edge_pan_dir() * Look.CAM_EDGE_PAN_PX_PER_SEC
	if vel != Vector2.ZERO:
		field_view.pan_by(vel * delta)
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
		# ⚠⚠ **READ ON BOTH EDGES, LIKE TAB AND UNLIKE EVERY OTHER KEY HERE**, because a held key that
		# is never told it was released pans forever. It sits ABOVE the `not key.pressed` return for
		# exactly that reason — below it, only the press would ever be seen.
		# ⚠ **The echo guard is what makes a hold one press.** OS auto-repeat delivers `pressed` many
		# times a second while a key is down; without this, each repeat would re-add the same direction
		# and W held for a second would read as a dozen W keys at once.
		if _on_pan_key(key):
			return
		if not key.pressed:
			return
		# ⚠⚠ **Turning is not gated on anything**, on purpose — 티켓 07 asks whether a hand may move
		# the board mid-fight, and gating it before the question is decided would answer it by
		# omission (2026-08-24, the user: 「3D 회전 회전 버튼이 내가 돌려봐야 될 듯」).
		_on_turn_key(key)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# ⚠⚠ **THE WHEEL TURNS THE BOARD AND NO LONGER ZOOMS** (2026-08-30, the user: 「마우스 휠이
		# 회전 오른쪽이 끌어서 이동으로 해야할듯」). Q and E stay and go through the same `turn_by` with
		# the same `CAM_YAW_STEP_DEG` notch — a second path to one state, never a second state.
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			_on_wheel(click.position, click.shift_pressed, 1)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			_on_wheel(click.position, click.shift_pressed, -1)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			# **The left button commands on a release in place** — that is the `true`.
			if click.pressed:
				_begin_press(click.position, true)
			else:
				_end_press()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# ⚠⚠ **RIGHT-DRAG PANS, AND IT USED TO TURN** (2026-08-30, the user: 「오른쪽이 끌어서
			# 이동으로 해야할듯」), which is why the turn moved onto the wheel above.
			# **It is the left button's own gesture with the order switched off** — the same
			# `_press_at`, the same `Look.DRAG_PAN_THRESHOLD_PX`, the same `pan_by`. A second drag path
			# would be a second threshold to keep in step, and the two would disagree the first time
			# either moved.
			if click.pressed:
				_begin_press(click.position, false)
			else:
				_end_press()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# ⚠⚠ **WHERE THE POINTER IS, AND IT IS RECORDED FOR THE EDGE PAN AND NOTHING ELSE.** It is
		# written here rather than polled from `Input` in `_process` for the reason `_pan_keys` gives:
		# headless, nothing can move the input singleton's cursor, so the whole feature would be
		# unmeasurable. **A net hands this method the same motion the OS would.**
		_pointer_at = motion.position
		# The panel is asked here too, and not only on press: a drag begun on the field before the
		# panel opened must not keep panning (or sending) behind it once it does — `panel_active()`
		# becoming true mid-drag is what `_begin_press` alone cannot catch.
		# ⚠⚠ **THE HOVER PLATE, AND IT IS ASKED ON EVERY MOTION.** `_tile_at` answers -1 off the island,
		# which is exactly the value that hides the plate, so there is no second test for "is the mouse
		# on the ground". **It is set here and not inside the summon branch below** — the plate says
		# where the cursor is, which is true whether or not a slot is armed.
		field_view.set_hover_tile(_tile_at(motion.position))
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
## is the same discipline `_order_walk_at` keeps today by driving off `battle.order_walk`'s own bool.


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
## ⚠ **`orders` is the ONLY thing that tells the two buttons apart.** Both open the same gesture, both
## cross the same threshold into the same pan; only the left one has anything to do with a release
## that never travelled.
func _begin_press(at: Vector2, orders: bool) -> void:
	# ⚠ **Nothing is ordered and nothing is panned here.** Both are decided by what happens next — see
	# `_press_open`. A press that resolves to neither (no battle, no walkable 조각 under it) still ends
	# as a pan, which is what a press on open water has always done.
	_press_at = at
	_press_open = true
	_press_orders = orders
	_panning = false


## ⚠⚠ **`_turning` AND `_turn_from` STOOD HERE AND BOTH ARE DELETED** (2026-08-30). They were the
## right button's own yaw drag (2026-08-26, the user: 「회전은 오른쪽 마우스 누르고 돌릴 수
## 있었으면 좋겠음」) and **the same user moved that gesture onto the wheel**: 「마우스 휠이 회전
## 오른쪽이 끌어서 이동으로 해야할듯」. ⚠ **`Look.CAM_YAW_PER_PX_DEG` was their only reader and it is
## now read by nothing** — left standing rather than deleted, because it is the measured feel of a
## per-pixel yaw and re-deriving it costs a round.


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
	# ⚠⚠ **`_press_orders` is what keeps the right button from commanding.** Without it a right click
	# in place would send a body, which is the one thing this gesture must never do.
	if _press_open and not _panning and _press_orders and battle != null:
		_order_walk_at(_press_at)
	_press_open = false
	_press_orders = false
	_panning = false


# --- the camera keys ------------------------------------------------------------------------------

## **WASD, held, as a screen direction.** True when the key was one of the four, which is what tells
## `_unhandled_input` the event is spent.
##
## ⚠⚠ **THE SIGNS ARE THE MOUSE DRAG'S, NOT THE CAMERA'S.** `pan_by` takes the delta a DRAG would
## deliver, and dragging the ground rightwards moves the view LEFT — so 「look right」 is a negative x.
## Getting this backwards is a control that works and feels wrong, which no check catches; the one
## thing that pins it is that a key and a drag go through the same call.
## ⚠ **A key going down ADDS its direction and going up SUBTRACTS it**, rather than either one writing
## the whole vector. Writing it whole loses the other axis: A and W held together, then A released,
## would stop the pan entirely instead of leaving W running.
func _on_pan_key(key: InputEventKey) -> bool:
	if key.echo:
		# ⚠ **`true` and not `false`.** A repeat is still a pan key, and letting it fall through would
		# hand it to `_on_turn_key` — which ignores echoes too, so nothing would happen, but the event
		# would be reported unhandled for a key this shell very much handles.
		return true
	var dir := Vector2.ZERO
	if key.keycode == KEY_W:
		dir = Vector2(0.0, 1.0)
	elif key.keycode == KEY_S:
		dir = Vector2(0.0, -1.0)
	elif key.keycode == KEY_A:
		dir = Vector2(1.0, 0.0)
	elif key.keycode == KEY_D:
		dir = Vector2(-1.0, 0.0)
	else:
		return false
	if key.pressed:
		_pan_keys += dir
	else:
		_pan_keys -= dir
	return true


## Q turns the board one notch anticlockwise, E one notch clockwise. **Returns whether it took the
## key** — a leftover from when the summon keys were asked next, kept because it is the honest answer
## to 「did this handler consume the event」 and because every net that drives a key reads it.
##
## ⚠⚠ **The `echo` guard is not optional.** OS auto-repeat on a held key delivers
## `pressed = true, echo = true` many times a second, and a turn per repeat spins the board.
##
## ⚠ **Raw keycodes and no `[input]` action**: there is no `[input]` section in `project.godot` and
## none is added, so what a check drives is this shell rather than a settings file.
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


# --- the edge pan ---------------------------------------------------------------------------------

## **The pointer parked against a side of the window pans the camera that way, for as long as it stays
## there** (2026-08-30, the user: 「wasd 보다는 마우스가 끝으로 가면 자동으로 이동이 맞을듯」).
##
## Answers a SCREEN-space direction whose axes each run 0..1, spent by `_process` against the frame's
## own delta exactly as `_pan_keys` is. **Zero means the edge is asking for nothing.**
##
## ⚠⚠ **THE SIGNS ARE `_on_pan_key`'S, WHICH ARE THE MOUSE DRAG'S.** `pan_by` takes the delta a DRAG
## would deliver, so 「look east」 is a NEGATIVE x — the pointer on the right edge therefore answers
## -1, the same number D answers. Getting this backwards is a control that works and feels wrong, and
## the one thing that pins it is that all three inputs go through the one call.
##
## ⚠⚠ **A CORNER IS TWO EDGES AND THE RESULT IS NOT NORMALISED**, so a corner travels 1.41 times as
## fast as a side. **That matches `_pan_keys` and it matches a mouse drag**, both of which are
## deliberately un-normalised — a diagonal drag covers more ground and so does this.
##
## ⚠⚠ **IT ANSWERS ZERO WHILE A BUTTON GESTURE IS IN FLIGHT, AND THAT IS THE WALK ORDER'S PROTECTION.**
## The band overlaps ground a body gets ordered onto; with the camera sliding between the press and the
## release, `_end_press` would resolve `_press_at` against a camera that had moved and command a
## different 조각 than the one under the finger. **Holding still for the length of a press is what
## keeps a click near the edge a click.** ⚠ It costs nothing a drag wanted: a drag is already panning.
func _edge_pan_dir() -> Vector2:
	if not _pointer_inside or not _window_focused:
		return Vector2.ZERO
	if _press_open or _panning:
		return Vector2.ZERO
	# ⚠ **The window's own constants and not `get_viewport_rect()`.** Headless the window is 64x64 and
	# every screen position this shell is driven with is in `look.gd`'s 1280x720 — asking the real
	# viewport would put the whole band in a place nothing ever points at.
	var w := Look.VIEWPORT_W_PX
	var h := Look.VIEWPORT_H_PX
	# **Off the glass entirely is not「as deep as it goes」, it is nothing.** A pointer dragged out past
	# the frame still delivers motions, and clamping its depth instead would pan at full speed for as
	# long as it stayed out there.
	if _pointer_at.x < 0.0 or _pointer_at.y < 0.0 or _pointer_at.x > w or _pointer_at.y > h:
		return Vector2.ZERO
	var band := Look.CAM_EDGE_PAN_BAND_PX
	var dir := Vector2.ZERO
	if _pointer_at.x < band:
		dir.x = _edge_ramp((band - _pointer_at.x) / band)
	elif _pointer_at.x > w - band:
		dir.x = -_edge_ramp((_pointer_at.x - (w - band)) / band)
	if _pointer_at.y < band:
		dir.y = _edge_ramp((band - _pointer_at.y) / band)
	elif _pointer_at.y > h - band:
		dir.y = -_edge_ramp((_pointer_at.y - (h - band)) / band)
	return dir


## How much of the top speed a pointer `depth` of the way through the band gets: 0.0 at the inner lip,
## 1.0 hard against the window's edge. **`Look.CAM_EDGE_PAN_LIP_FACTOR` is the whole shape** — at 1.0
## this returns 1.0 everywhere and the band is flat.
func _edge_ramp(depth: float) -> float:
	var lip := Look.CAM_EDGE_PAN_LIP_FACTOR
	return lip + (1.0 - lip) * clampf(depth, 0.0, 1.0)


## **Alt-tab, and the pointer leaving the window.** Both stop the edge pan, and neither can be seen
## from an input event — they are the two ways a pointer stops being where `_pointer_at` says it is.
##
## ⚠ **This is not a reader of the `Input` singleton**, so a net drives it the same way it drives every
## other input here: by calling the method with the notification the engine would have sent.
## ⚠ **Application focus AND window focus.** They are two different notifications and either one can
## arrive alone; watching only one leaves the other alt-tab still sliding.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer_inside = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


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


## **One wheel notch: it TURNS the board, and with SHIFT held it zooms about `at`.**
##
## ⚠⚠ **THE WHEEL WAS ZOOM AND THE USER MOVED IT TO ROTATE** (2026-08-30: 「마우스 휠이 회전
## 오른쪽이 끌어서 이동으로 해야할듯」). The right button's yaw drag went with it — see the tombstone
## where `_turning` stood.
##
## ⚠⚠ **SHIFT+WHEEL FOR ZOOM IS THE BUILDER'S CALL AND NOBODY ELSE'S.** The user moved the wheel onto
## the turn and **never said where zoom goes** — so this pairing is unowned, it was not measured
## against anything, and **it is cheap to move**: one branch here and one row in `net_shell`. Q/E and
## R/F are the keyboard's turn and tilt and they are untouched, so a hand that dislikes this still has
## the board.
##
## ⚠ **One notch of the wheel is one `Look.CAM_YAW_STEP_DEG`**, the same notch Q and E turn by. A
## per-pixel yaw would need its own constant back, and the wheel has no pixels — it has notches.
## ⚠ **Wheel UP turns the way E does (clockwise).** That is a coin flip and it is written down as one;
## nothing measured it and nothing depends on it.
##
## ⚠ **The zoom keeps the world point under the cursor fixed** (`field_view.zoom_at`).
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
func _on_wheel(at: Vector2, zooming: bool, notch: int) -> void:
	if zooming:
		field_view.zoom_at(at, Look.ZOOM_STEP if notch > 0 else 1.0 / Look.ZOOM_STEP)
		return
	field_view.turn_by(float(notch) * Look.CAM_YAW_STEP_DEG)


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
#    ⇒ **`_order_walk_at` is the only hit test a field press gets now.**
