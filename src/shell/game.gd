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
## `_begin_press`. ⚠ **Since 2026-09-02 (03-11) that is two buttons**: the left picks a 부대 or lets
## it go (`_press_the_island`), the right sends it (`_begin_order`, on the press). ⚠ **The island
## stays UNCOMMITTED** — a `commit()` was put in `_open_island` to replace the button and it won the
## island before its first frame; the reason is written there.
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

## **The four pan keys and the SCREEN direction each one asks for.** ⚠⚠ **`_pan_keys` STOOD HERE, WAS
## DELETED, AND THE KEYS ARE BACK IN A DIFFERENT SHAPE** (2026-08-31, the user: 「wasd 도 지워줘」;
## restored 2026-09-02 because the selection box takes the left drag and there is then no hand left to
## push the board with). **The deletion is kept rather than erased** — this repo records a flip.
##
## ⚠⚠ **THE SIGNS ARE THE MOUSE DRAG'S, NOT THE CAMERA'S.** `pan_by` takes the delta a DRAG would
## deliver, and dragging the ground rightwards moves the view LEFT — so 「look right」 is a negative x
## and 「look north」 is a positive y. Getting this backwards is a control that works and feels wrong,
## which no check catches; the one thing that pins it is that a key, the band and a drag all go
## through the same call.
##
## ⚠ **One table and not four branches**: a fifth key is one row here, and the direction lives beside
## the key rather than in a handler that has to be kept in step with a list of fields.
var _pan_dirs := {
	KEY_W: Vector2(0.0, 1.0),
	KEY_S: Vector2(0.0, -1.0),
	KEY_A: Vector2(1.0, 0.0),
	KEY_D: Vector2(-1.0, 0.0),
}

## **Which of those keys are down right now** — one held flag per key, and the pan direction is
## DERIVED from them every frame.
##
## ⚠⚠ **HELD STATE AND NOT ONE STEP PER EVENT, AND THE DIFFERENCE IS THE WHOLE FEATURE.** A key that
## panned once per event would move the camera at the OS's auto-repeat rate — a pause, then a stutter,
## then a speed nobody chose and that differs per machine. **Panning is continuous or it is not
## panning**, and 「looking around for a boat」 is the one thing the camera has to be good at
## (2026-08-30, the user: 「마우스 돌리다가 보이면 그때 가는 걸로」).
##
## ⚠⚠ **FLAGS, AND NEITHER `+=`/`-=` NOR A WHOLE WRITTEN VECTOR.** Writing the vector whole loses the
## other axis the moment two keys are held and one is let go; **adding and subtracting cannot be
## cleared**, and a release swallowed by a closed door then leaves the camera travelling for the life
## of the process. A flag is SET, so a repeat writes the same `true` twice and **an OS auto-repeat
## echo cannot stack a second direction** — which is why there is no `echo` branch in `_on_pan_key`.
##
## ⚠⚠ **A NET CAN DRIVE THIS AND COULD NOT DRIVE `Input.is_key_pressed`.** The alternative was polling
## the input singleton from `_process`; headless, nothing can put a key down in it, so the whole
## feature would be unmeasurable — and `tests/README` already records half an input suite going green
## while the other half was dead.
##
## ⚠ **Diagonals are NOT normalised**, deliberately: W and D together move the camera 1.41 times as
## fast, which is what a drag already does — a mouse moving diagonally covers more ground too.
var _pan_held := {}

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
## ⚠ **「orders」 is the right button's word since 2026-09-02** (03-11): a left press that TRAVELS is a
## pan, and one that does not picks or lets go. The left button orders nobody, ever.
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
## ⚠ **「the order it always was」 stopped being true on 2026-09-02** (ticket 03-11): a left release in
## place is a PICK or a LET-GO now, and the walk order is the right button's — fired on its press, see
## `_begin_order`. The paragraph above is kept because the pan-vs-click split it argues for stands.
## ⚠ **This pair is the LEFT button's alone.** The right button's flag sits below it, on its own.
var _press_at := Vector2.ZERO
var _press_open := false
## ⚠⚠ **`_press_orders` STOOD HERE AND IT IS DELETED** (2026-08-30, the same round that put the yaw
## drag back on the right button). It said whether the press in flight commands a body on a release in
## place, and it existed for exactly one reason: **both buttons opened the same press**, so something
## had to tell them apart without keeping a button index.
## ⚠ **The right button no longer opens a press at all** — it turned the board — so this flag could
## only ever be `true`, and a gate that can only be true is not a gate, it is a deleted branch waiting
## to be noticed. **What kept the right button from commanding is now the wiring itself.**
## ⚠⚠ **AND SINCE 2026-09-02 THE RIGHT BUTTON DOES NOTHING AT ALL** — the yaw drag went to Q and E, so
## it is not that the button is busy turning, it is that the shell has no right-button branch left.
## **03-11 is what picks it up**, and the flag it needs is this one.
## ⚠⚠ **03-11 DID NOT REVIVE IT** (2026-09-02, the same day). The line above was right about the ticket
## and wrong about the flag: the right button got `_order_open` below, its own, and never this one —
## **both buttons can be down at once**, and one slot shared between them would let a right press in
## the middle of a left drag overwrite `_press_at` and `_panning`. The right button does not go through
## `_begin_press` / `_end_press` at all.

## **True from a right press to its release, and the only thing the release touches.**
##
## ⚠⚠ **THE ORDER DOES NOT WAIT FOR THE RELEASE** (2026-09-02, ticket 03-11, read from the user's
## StarCraft reference — the move goes out on the right button's DOWN edge). It fires in `_begin_order`,
## so this flag carries no 칸 and no point from one edge to the other: there is nobody left to read one,
## and a field kept for nobody to read is the shape the `at` tombstone on `_end_press` names.
## **What it holds is the edge band still** (`_edge_pan_dir`), because a held button does not travel
## the board; it is dropped with the left pair by `_drop_the_gestures` when a board is lost or left.
var _order_open := false

## **Whether the pointer is over this window, and whether this window has the focus.** ⚠⚠ **BOTH WERE
## DELETED WITH THE EDGE BAND ON 2026-08-31** (the user: 「화면 끝에 마우스 뒀을 때 이동되는 로직 ...
## 그것도 지워줘」) **and both come back with it** (2026-09-02). The old line said they existed for the
## edge pan and for nothing else; **that is no longer true of the focus flag** — see below.
##
## ⚠⚠ **A CAMERA THAT KEEPS SLIDING WHILE THE USER ALT-TABS IS THE CLASSIC VERSION OF THIS BUG.** The
## pointer's last known position stays in the band for as long as the player is away, so without these
## two the island would still be travelling when they came back.
##
## ⚠⚠ **THE TWO ARE READ AT DIFFERENT HEIGHTS, AND THAT IS THE 2026-09-02 CORRECTION.** The band alone
## read both when they were deleted, so **a held W kept panning through an alt-tab** — a focus loss
## delivers no key-up, and 「nothing moves while the window is away」 was simply not what the flags did.
## ⇒ **`_window_focused` gates the WHOLE summed velocity** in `_pan_the_board`, and it also drops every
## held key, because the release that ends a hold arrives at a window that is not listening.
## **`_pointer_inside` stays the band's own**: a pointer off the window says nothing about a keyboard.
##
## ⚠ **TWO FLAGS AND NOT ONE**, because the two causes end independently: alt-tab back with the
## pointer still outside the window must not resume the band, and one flag would let a focus event
## clear a mouse-exit it knows nothing about.
## ⚠ **Both start true**, which is safe only because `_pointer_at` starts off-screen — nothing pans
## until a real motion arrives and says where the pointer is.
var _pointer_inside := true
var _window_focused := true

## **Where the pointer was last seen.** ⚠⚠ **IT WENT WITH THE EDGE PAN ON 2026-08-31 AND CAME BACK ON
## 2026-09-01**, when `pick-then-move` merged onto the branch that had deleted it. **It has two readers
## now**: `_process` rebuilds the 이동선 from it every frame, because the picked body walks and the
## board slides under a cursor that never moved, and the edge band asks where the cursor is parked.
## ⚠ **The motion handler is its only writer**, exactly as before.
##
## ⚠⚠ **IT STARTS OFF-SCREEN AND THAT IS THE SAFE DIRECTION, AND IT SPENT A DAY AT THE ORIGIN**
## (2026-09-01 to 2026-09-02). `(0, 0)` is harmless to a route and is **1.0 deep on BOTH band axes**,
## so a shell that had never seen a motion pans north-west at 1.41 x the top speed from its first
## frame. `(-1, -1)` is outside every band, and the band's own guard is 「off the glass is nothing」.
## The alternative — starting at the middle — would be a made-up pointer position that happens to be
## harmless on one screen size.
var _pointer_at := Vector2(-1.0, -1.0)

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
	# ⚠⚠ **A PAN WAS SPENT HERE EVERY FRAME, IT WAS DELETED ON 2026-08-31, AND IT IS BACK**
	# (2026-09-02). The old line said 「both sources are gone ... nothing needs a per-frame call」;
	# **both sources are back**, and the drag that replaced them is being taken away by the selection
	# box. ⚠ **It stays ABOVE the `battle == null` guard**, so the camera keeps working on a frame the
	# sim is not running — looking around is exactly the thing that must not stop being possible.
	# ⚠ **`pan_by` still ends in the clamp** — that is the drag's bound too, and it is untouched.
	_pan_the_board(delta)
	# ⚠⚠ **THE 이동선 IS REBUILT EVERY FRAME AND NOT ONLY ON MOTION.** Its first point is the picked
	# body's OWN position, and that body walks — built once on hover, the line stayed anchored where he
	# used to be and trailed behind him across the island.
	# ⚠⚠ **THIS IS WHY `_pointer_at` CAME BACK** (2026-09-01, merging `pick-then-move` onto the branch
	# that deleted the edge pan). The edge band had been its only reader and it went with the band —
	# but a still cursor over a walking body is still a changing route, and the left-button drag moves
	# the board under a still cursor too. **「the pointer has not moved」 never meant 「the route has not
	# changed」.** ⚠ **The band is back above this line and reads it again** (2026-09-02), which is why
	# the field starts off the glass rather than at the origin — see where it is declared.
	# ⚠ **The route is rebuilt AFTER the pan and not before it**, so the line is drawn against the
	# camera this frame ends on rather than the one it began on.
	# ⚠⚠ **IT IS CHEAP, AND THE REASON IS NOT THE ONE THIS COMMENT GAVE UNTIL 2026-09-01.** It read
	# 「`Hand.routes` caches the 조각 list per destination」 — a cache keyed on the destination 칸 alone,
	# which is exactly the defect measured and closed that day: the seats move under a still cursor.
	# **`Hand.routes` now recomputes the seating every call and remembers the LINES against it**, so a
	# frame where nothing moved costs 0.04 ms and a frame where something did costs 3.9 ms — measured on
	# the real island with a 부대 of nine.
	_show_route(_pointer_at)
	# ⚠⚠ **AND THE HOVER PLATE IS RE-ASKED EVERY FRAME TOO, SINCE 2026-09-02.** `set_hover_tile` had
	# exactly one call site — the motion branch — and **a keyboard turn produces no motion event**, so
	# one press of E left the white plate sitting on the 조각 the cursor used to be over, a quarter of
	# the board away, until the hand moved. The 이동선 above never had that problem because it is built
	# from the remembered pointer every frame; this is the plate joining it.
	# ⚠ **It is a different thing from a plate under a HELD right button**, which is a stream of real
	# motion events and was frozen by an early `return` instead.
	# ⚠ **Below the pan and not above it**, so the plate answers for the camera this frame ends on.
	field_view.set_hover_tile(_tile_at(_pointer_at))
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
	# ⚠⚠ **THE LOSS REACHES THE SCREEN HERE AND NOWHERE ELSE** (2026-09-01, the user: 「엔딩씬을
	# 생각해봤는데 그냥 게임 오버 뜨면 될 거 같은데? 게임 오버 빨간 글씨고 딱 뜨고. 끝」 — *"I thought
	# about the ending scene — I think just showing GAME OVER is enough. Red letters, it just appears,
	# and that is the end."*).
	# ⚠ **BELOW `step` and not above it**, so the frame the 성채 falls in is the frame the words go up.
	# Read before the step, the screen would trail the sim by one frame forever — the shape 「screen
	# changes but the sim doesn't」 names, wearing its inverse.
	# ⚠ **The shell reads `lost`; the view never does.** `hud_view` holds a bool it was handed, so
	# there is one reader of the loss condition and no pair to keep in step.
	hud_view.set_over(battle.lost)


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
	# ⚠⚠ **THE BOARD STOPS ANSWERING WHEN THE 성채 FALLS** (2026-09-01, the user: 「딱 뜨고. 끝」 — *"it
	# just appears, and that is the end"*). `Battle.step` already returns early while `lost`, so the
	# sim is frozen with no help from here; **the camera was not**, and a player left able to tilt,
	# zoom, turn and pan a dead island is 「끝」 saying one thing while the hand is told another.
	# ⚠ **One line above every branch rather than a test inside each**, the same argument the deleted
	# hold guard made in this position: TAB, ESC, the tilt keys, the wheel and both drags each waved a
	# press through on their own terms, and five guards are five chances to miss one.
	# ⚠ **「both drags」 is ONE drag since 2026-09-02** — the right button's yaw drag is deleted and the
	# turn keys took it — and the argument is unchanged: one line above every branch.
	# ⚠ **It is NOT a return in `_process`.** The views keep their own clocks and the island keeps
	# drawing behind the words — that is the ticket's answer (「뒤에는 섬이 그대로 남고」), and a shell
	# that stopped processing would freeze the picture rather than the play.
	if battle != null and battle.lost:
		# ⚠⚠ **ONE THING STILL PRESSES ON A LOST BOARD, AND IT IS THE WAY BACK** (2026-09-01, the user
		# after seeing the words on the glass: 「그 게임오버 하고 타이틀로 돌아가는 버튼도 만들어줘」).
		# **This reverses 티켓 02-03's own 「끝」**, which put a way back in its Out of scope.
		# ⚠ **Inside the closed door and not above it.** Above, it would be one more branch competing
		# with TAB, the wheel and the left drag for a press on a LIVE board; here the board is already
		# dead and this is the only sentence left that means anything. ⚠ **It read 「both drags」 until
		# 2026-09-02**, when the right button's yaw drag was deleted.
		# ⚠ **The rect comes from the view that drew it** — see `HudView.back_rect_px`, which is zero
		# until the words are up, so there is no second 「is the screen showing」 test here.
		if event is InputEventMouseButton:
			var over_click := event as InputEventMouseButton
			if over_click.pressed and over_click.button_index == MOUSE_BUTTON_LEFT 					and hud_view.back_rect_px().has_point(over_click.position):
				_back_to_title()
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
		# ⚠⚠ **THE WASD BRANCH STOOD HERE, WAS DELETED ON 2026-08-31, AND IT IS BACK** (2026-09-02).
		# The old line closed with 「TAB is the only two-edged key left」; **it is not — this is the
		# other one**, and it is read on BOTH edges for the reason that line already gave: a held key
		# never told it was released pans forever. **That is why it sits ABOVE the `not key.pressed`
		# return** — below it, only the press would ever be seen.
		if _on_pan_key(key):
			return
		if not key.pressed:
			return
		# ⚠⚠ **Tilting is not gated on anything**, on purpose — 티켓 07 asks whether a hand may move
		# the board mid-fight, and gating it before the question is decided would answer it by
		# omission (2026-08-24, the user: 「3D 회전 회전 버튼이 내가 돌려봐야 될 듯」).
		# ⚠⚠ **THE TURN KEYS STOOD BESIDE THE TILT HERE, WERE DELETED, AND ARE BACK** (2026-08-31, the
		# user: 「QE 이거 기능제거해줘」; restored 2026-09-02 turning a QUARTER instead of 15°). **They
		# are their own handler again** rather than living inside the tilt's, which is the shape they
		# had before the deletion — see `_on_turn_key`.
		if _on_turn_key(key):
			return
		_on_tilt_key(key)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# ⚠⚠ **THE WHEEL TURNED THE BOARD FOR ONE ROUND AND IT IS THE ZOOM AGAIN** (2026-08-30 morning,
		# the user: 「마우스 휠이 회전 오른쪽이 끌어서 이동으로 해야할듯」; the same day at the screen,
		# reversing it: 「마우스 휠이 확대 축소가 맞고, 오른쪽 버튼은 카메라 회전으로 이해했어」).
		# **The later word wins and the earlier one is kept here rather than erased.**
		# ⚠⚠ **THE YAW DRAG WENT BACK ONTO THE RIGHT BUTTON AND IS NOW DELETED** (2026-09-02, the
		# user: 「오른쪽 마우스로 회전을 하면 뭔가 장점이 별로 없어서」). Q and E turned by a notch
		# beside it for one week, were deleted with it in between, and **are the only turn now** — the
		# right button carries no camera at all, which is what frees it for the move order.
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			_on_wheel(click.position, 1)
		elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			_on_wheel(click.position, -1)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			# **The left button picks or lets go on a release in place, and it is the only button that
			# opens a PRESS at all** — see the tombstone where `_press_orders` stood. ⚠ The right button
			# opens an ORDER, not a press (2026-09-02, 03-11), and it has its own two functions below.
			if click.pressed:
				_begin_press(click.position)
			else:
				_end_press()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# **The right button carries the move order, on its DOWN edge** (2026-09-02, ticket 03-11,
			# read from the user's StarCraft reference) — see `_begin_order`, where the walk goes out.
			# The release closes the gesture and reads nothing, which is why it is handed no position.
			if click.pressed:
				_begin_order(click.position)
			else:
				_end_order()
		# ⚠⚠ **THE RIGHT BUTTON'S TWO ARMS STOOD HERE AND BOTH ARE DELETED** (2026-09-02, the user:
		# 「오른쪽 마우스로 회전을 하면 뭔가 장점이 별로 없어서」). **The two reversals they carried are
		# kept rather than erased**, because deleting this branch is itself reversing a reversal:
		#
		#  - 2026-08-26, the user: 「회전은 오른쪽 마우스 누르고 돌릴 수 있었으면 좋겠음」 — the yaw drag is born;
		#  - 2026-08-30 morning: 「오른쪽이 끌어서 이동으로 해야할듯」 — it becomes a pan;
		#  - 2026-08-30 at the screen: 「오른쪽 버튼은 카메라 회전으로 이해했어」 — the turn is re-taken;
		#  - 2026-09-02 — **the turn moves onto Q and E and the button carries nothing.**
		#  - 2026-09-02, ticket 03-11 — **the button carries the move order, on its DOWN edge** (the
		#    `MOUSE_BUTTON_RIGHT` branch above; StarCraft, which the user named, orders on the press).
		#
		# ⚠ **What it made true by construction is now true by there being no branch**: the right
		# button opens no press, so there is no release in place for `_end_press` to turn into a walk
		# order. **That stops being an argument the day 03-11 puts the order on it.**
		# ⚠ **That day is this one** (2026-09-02). What keeps the right button out of `_end_press` now is
		# that it has its own branch — `_begin_order` / `_end_order` — and never enters `_begin_press`.
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# ⚠⚠ **THE POINTER IS RECORDED HERE, AND IT HAS TWO READERS.** It was the edge pan's line and
		# was deleted with it (2026-08-31); it came back on 2026-09-01 for the 이동선, which `_process`
		# rebuilds every frame because the picked body walks, and the band reads it again (2026-09-02).
		# **It used to sit above the turn's early return** so a yaw drag did not leave the route
		# reading a stale cursor; that return is gone with the drag.
		_pointer_at = motion.position
		# ⚠⚠ **THE YAW DRAG STOOD HERE, ABOVE EVERYTHING ELSE, AND IT IS DELETED** (2026-09-02, the
		# user: 「오른쪽 마우스로 회전을 하면 뭔가 장점이 별로 없어서」). It read the HORIZONTAL travel
		# only — a drag that changed two things at once made every accidental diagonal a lost camera —
		# and it measured from the LAST motion rather than from the press point, so the yaw followed
		# the hand continuously.
		# ⚠⚠ **IT ENDED IN AN EARLY `return`, AND FOUR THINGS BELOW WERE FROZEN FOR THE LENGTH OF A
		# TURN**: the hover plate, the 이동선, the left drag's pan threshold, and a left pan already in
		# flight. **The first two coming back is a fix this ticket gets for free.** ⚠ **The fourth is
		# new behaviour nobody asked for** — a left pan and a right press can now run together. It is
		# harmless while the right button does nothing, **and it stops being harmless the day 03-11
		# puts the move order on it**, which is why it is written here rather than found there.
		# ⚠ **03-11 answered it the same day** (2026-09-02): the order goes out on the right PRESS,
		# before any motion can arrive, so a left pan under a held right button re-aims nothing — the
		# release has nothing left to aim — and the band holds still through it (`_edge_pan_dir`).
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


## **Back to the title from a lost island.** The exact inverse of `_start_run`, line for line.
##
## ⚠⚠ **`run = null` IS THE ONE THAT MATTERS.** `_unhandled_input` routes to `_title_input` on it and
## `_process` returns on it, so nulling the run is what actually hands the machine back to the title —
## the two `visible` lines are only what the player sees. **Set the flag and forget the screens and the
## title is live under a drawn island; set the screens and forget the flag and a dead board keeps
## eating presses behind a title nobody can press.**
##
## ⚠ **`bind(null)` and not `set_over(false)`.** `bind` already clears `_over` — that is its own
## header's promise — so calling both would be two writers for one flag.
##
## ⚠⚠ **THE RUN IS DISCARDED AND NOTHING IS CARRIED OVER.** 시작하기 makes a fresh `Run`, so pressing it
## after this is a new game and not a resumed one. **That is what 「타이틀로」 was asked for**, and if a
## continue is ever wanted it is a different button with a different word on it.
##
## ⚠ **One line here has no twin in `_start_run`, and 「line for line」 above is written onto for it**
## (2026-09-02, 03-11): the button gestures are dropped. A run that ends with a button down must not
## hand its flag to the next run — the blanket `return` in `_unhandled_input` guarantees the release
## never arrives — and `_start_run` needs no twin because the only way into it is through here.
func _back_to_title() -> void:
	run = null
	battle = null
	hud_view.bind(null)
	field_view.show_board(false)
	title_view.visible = true
	_drop_the_gestures()


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
	# ⚠⚠ **AND THE BOARD COMES BACK UP HERE** (2026-09-01). `_back_to_title` takes it down, and
	# `field_view.setup` cannot put it back on its own — `_build_world` returns early once the world
	# exists, so a second run would open onto a hidden island with every check about it green.
	# ⚠ **Both visibility lines sit in this file and face each other**, which is what makes the pair
	# readable: the shell owns which screen is up, and neither view decides it.
	field_view.show_board(true)
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
## them opened this same gesture; **the right button turned the board and never got here**, so the
## only caller left is the left press and the only value it ever passed was `true`.
## ⚠ **The right button turns nothing since 2026-09-02** and still never gets here — what changed is
## the reason, not the fact.
## ⚠ **And since 03-11 (2026-09-02) it ORDERS, and still never gets here**: it has its own
## `_begin_order`, so a right press in the middle of a left drag cannot overwrite `_press_at`.
func _begin_press(at: Vector2) -> void:
	# ⚠ **Nothing is ordered and nothing is panned here.** Both are decided by what happens next — see
	# `_press_open`. A press that resolves to neither (no battle, no walkable 조각 under it) still ends
	# as a pan, which is what a press on open water has always done.
	_press_at = at
	_press_open = true
	_panning = false


## ⚠⚠ **`_turning` AND `_turn_from` STOOD HERE, WERE DELETED ONCE, CAME BACK, AND ARE DELETED AGAIN.**
## Every line is kept because this repo records a flip and does not erase the old one:
##
##  - 2026-08-26, the user: 「회전은 오른쪽 마우스 누르고 돌릴 수 있었으면 좋겠음」 — the yaw drag is born;
##  - 2026-08-30 morning, the user: 「마우스 휠이 회전 오른쪽이 끌어서 이동으로 해야할듯」 — the turn
##    moves onto the wheel and these two fields are deleted;
##  - 2026-08-30 at the screen, the user: 「마우스 휠이 확대 축소가 맞고, 오른쪽 버튼은 카메라 회전으로
##    이해했어」 — reversed, and they come back;
##  - 2026-09-02, the user: 「오른쪽 마우스로 회전을 하면 뭔가 장점이 별로 없어서」 — **the drag is
##    deleted and Q and E carry the turn.** ⚠ **Deleting it is reversing a reversal**, which is why
##    the three lines above are not cut.
##
## ⚠ **`Look.CAM_YAW_PER_PX_DEG` is left standing again**, and no longer for this file: the piece
## viewer drags a piece around by it, and that reader is live.


## Ends whichever gesture was in flight, and **dropping the pan is all that is left**.
##
## ⚠ **Two gestures ended here before it and both are deleted**: the soldier drag that authored a
## landing (2026-08-25), and the held summon press (2026-08-28).
## ⚠⚠ **THE `at` PARAMETER IS GONE** (2026-08-30). It was kept unread as the shell's own release
## signature; **the right button ended the same gesture and its release position was unread too**, so
## the parameter had become a value two callers had to invent for nobody to read.
## ⚠ **The right button ends nothing now** (2026-09-02) — there is one caller and it is the left
## release.
## ⚠ **Written onto the same day** (03-11): the right button ends its own flag, in `_end_order`, and
## still has no caller here.
func _end_press() -> void:
	# **A press that never travelled is a click, and a click commands.** ⚠ **Ordered from the point the
	# button went DOWN and not from where it came up** — a hand that shifts two pixels while clicking
	# would otherwise command a different 조각 than the one it pressed on.
	# ⚠ **「commands」 meant a walk until 2026-09-02** (03-11); the walk is the right button's, and what
	# a left click does here is pick a body or let go — resolved from the DOWN point for the same reason.
	# ⚠⚠ **NOTHING HERE ASKS WHICH BUTTON, AND THAT IS WHAT KEEPS THE RIGHT ONE FROM COMMANDING.**
	# Only the left press ever reaches `_begin_press`, so `_press_open` is already the answer to
	# 「was this a press that may command」 — see the tombstone where `_press_orders` stood.
	# ⚠ **Still true on 2026-09-02, for a changed reason** (03-11): the right button commands now, but on
	# its own branch — `_begin_order` — and it never enters this function or `_begin_press`, so nothing
	# here has to ask which button it is.
	if _press_open and not _panning and battle != null:
		_press_the_island(_press_at)
	_press_open = false
	_panning = false


## **The right button went down: the 부대 is sent, now.**
##
## ⚠⚠ **THE ORDER FIRES HERE, ON THE DOWN EDGE, AND NOT ON THE RELEASE** (2026-09-02, ticket 03-11,
## read from the user's StarCraft reference — the game the user named issues the move on the right
## button's press). What that makes true by construction: **the 칸 the 이동선 was drawn to at the
## instant of the press is the 칸 ordered** — `_show_route` and this function walk the identical
## `_tile_at` → `Grid.block_of` → `can_reach_block` chain on the identical camera, in the same frame —
## and **nothing between the two edges can re-aim anything, because the release has nothing left to
## aim.** A 60 px drag, a D pan, a band slide: all arrive after the walk has gone out.
##
## ⚠⚠ **THE WALK IS AIMED AT A 칸 AND IT WAS A 조각 UNTIL 2026-09-01** (the user: "let us do it by the
## block"). **`_tile_at` still answers a 조각 and is not re-pointed** — the 칸 is made right here with
## `Grid.block_of`, because `_tile_at`'s other callers, the hover among them, still want the square
## metre. **Both are bare `int`s and passing the wrong one goes nowhere near red**, so the conversion
## lives on one line with the name `block` on it. (This paragraph moved here from `_press_the_island`
## with the arm it describes.)
##
## ⚠ **`_order_open` is set FIRST, before the battle guard**: the band holds still for the length of any
## right press, water included, exactly as it does for any left press — see `_edge_pan_dir`.
## ⚠ **ESC needs no line here.** A right press that ordered has already let go; one that ordered nobody
## (a 칸 the hand cannot reach) kept the hand, and ESC empties it exactly as before.
func _begin_order(at: Vector2) -> void:
	_order_open = true
	if battle == null:
		return
	var tile := _tile_at(at)
	# **The 조각 is a stop on the way to the 칸 and nothing more.** `_tile_at` says where the cursor
	# is; this one line says what the order is aimed at, and every name below it is 칸.
	var block := battle.grid.block_of(tile) if tile >= 0 else -1
	# ⚠ **The bool is not read and not stored.** 「consumed」 told `_end_press` a left press was not a
	# pan; the right button has no second gesture competing for its press, so nobody would read it.
	_order_the_island(block)


## **The right button came up: the gesture closes, and nothing else happens.**
##
## ⚠⚠ **IT ORDERS NOTHING, BECAUSE THE ORDER WENT OUT ON THE PRESS** — see `_begin_order`. It reads no
## position (which is why the nets' `_rrelease()` carries none), no `_panning` and no threshold:
## **the right button's motion is read by nothing**, which is how 「no travel gate on the right
## button」 is true by construction rather than by a constant nobody consulted.
func _end_order() -> void:
	_order_open = false


## **Sends the 부대 the hand is holding onto `block`, and lets go.** True when somebody actually went.
##
## **This is the full-hand arm of `_press_the_island`, moved out whole** (2026-09-02, ticket 03-11) —
## it is the right button's only job, and the left button no longer has it.
## ⚠ **An empty hand answers false through `can_reach_block`**: the right button never picks and never
## lets go of nothing. **`body_at_px` is not called here** — a body drawn on the destination does not
## intercept the order, which is the split itself.
## ⚠ **A 칸 the hand cannot reach keeps the hand.** That is the 2026-08-31 rule surviving on the button
## the order moved to; it is not re-decided here (ticket 03-11, Out of scope).
func _order_the_island(block: int) -> bool:
	if battle == null:
		return false
	if not hand.can_reach_block(block):
		return false
	var sent := hand.order(battle, block)
	# ⚠⚠ **THE ORDER LETS GO, AND IT KEPT HOLD FOR ONE ROUND** (2026-08-31, the user: 「이동하면 그러면
	# 그 이동관 관련은 꺼져야지」). The earlier line is kept because this repo records a flip: **it
	# re-picked the same bodies** so a second command needed no second pick, reasoning from 「the hand
	# never stops moving」. **What that ignored is that the board then stays lit with nothing left to
	# decide.**
	_let_go()
	return sent > 0


## **Every button gesture, dropped at once** — the left pair and the right flag.
##
## ⚠⚠ **TWO CALLERS AND NOT THREE.** The lost branch of `_pan_the_board`, because 「끝」 swallows every
## release edge and a flag left set kills the band for the life of the process through the gate in
## `_edge_pan_dir`; and `_back_to_title`, because a run that ends with a button down must not hand its
## flag to the next run. ⚠ **`_start_run` gets no call**: the only path into it is the title, and the
## only path from a run to the title is `_back_to_title` — a third call for symmetry would be a second
## writer for one fact.
## ⚠ **What a latched `_order_open` costs is not a stale order** — the release orders nothing — **it
## is the band**, exactly the way a latched `_press_open` already could cost it.
func _drop_the_gestures() -> void:
	_press_open = false
	_panning = false
	_order_open = false


# --- the camera keys ------------------------------------------------------------------------------

## **WASD, held, as a screen direction.** True when the key was one of the four, which is what tells
## `_unhandled_input` the event is spent.
##
## ⚠⚠ **`_on_pan_key` STOOD HERE, WAS DELETED ON 2026-08-31, AND IT IS BACK** (the user: 「wasd 도
## 지워줘」; restored 2026-09-02). **Its old shape is not restored with it**: it added on the press and
## subtracted on the release, and the tombstone's reason for that — a whole written vector loses the
## other axis — is right about the whole write and wrong about the sum. ⇒ **A flag per key**, which
## loses no axis AND can be dropped in one line when a run ends or the window goes away. See
## `_pan_held`, where both failures are written down.
##
## ⚠ **There is no `echo` branch and there does not need to be.** A repeat writes the same `true` a
## second time; the old `+=` form needed the guard because a repeat added a second direction.
## ⚠ **The keycode is asked BEFORE anything else**, so an echoing R is not swallowed here on its way
## to the tilt.
func _on_pan_key(key: InputEventKey) -> bool:
	if not _pan_dirs.has(key.keycode):
		return false
	if key.pressed:
		_pan_held[key.keycode] = true
	else:
		_pan_held.erase(key.keycode)
	return true


## **The frame's whole camera travel, summed from the two clocked sources and spent once.**
##
## ⚠⚠ **TWO SOURCES, ONE `pan_by`.** The keys and the edge band are added as screen-space velocities
## and spent once — a second `pan_by` call in the same frame clamps twice, and a camera already
## sitting on the roam edge would then eat one of the two inputs with nothing on screen saying so.
## ⚠ **The left drag still calls `pan_by` from the input handler**, so a hand that drags while W is
## held is genuinely two calls. **This claim is about the two CLOCKED sources**, which is all one
## frame's `_process` has to sum.
##
## ⚠⚠ **IT OBEYS 「끝」, AND THAT IS NOT A NEW DECISION** (2026-09-01, the user: 「딱 뜨고. 끝」).
## `_unhandled_input` closes the whole board on `battle.lost`, so **a key release during GAME OVER is
## swallowed** — and the band needs no event at all, so a cursor left near an edge would slide a dead
## island and still be sliding when the next one opens. ⇒ **the held keys and the press flags are
## dropped wholesale here**, rather than the pan merely being skipped: skipping leaves `_press_open`
## latched, and a latched press kills the band permanently through the gesture gate below.
## ⚠ **The right button's flag goes with them** (2026-09-02, 03-11) — one `_drop_the_gestures` and not
## three flag lines, so a fourth gesture cannot be added to the shell and missed here.
func _pan_the_board(delta: float) -> void:
	if battle != null and battle.lost:
		_pan_held.clear()
		_drop_the_gestures()
		return
	# ⚠⚠ **THE FOCUS FLAG GATES THE WHOLE SUM AND NOT ONLY THE BAND.** A focus loss delivers no
	# key-up, so a held W panned right through an alt-tab while this test lived inside the band alone.
	if not _window_focused:
		return
	var keys := Vector2.ZERO
	for code: int in _pan_held:
		keys += _pan_dirs[code] as Vector2
	var vel := keys * Look.CAM_PAN_KEY_PX_PER_SEC + _edge_pan_dir() * Look.CAM_EDGE_PAN_PX_PER_SEC
	if vel != Vector2.ZERO:
		field_view.pan_by(vel * delta)


## **Q and E turn the board a QUARTER, and the sweep starts on this very frame** (2026-09-02, the user
## on being shown the two choices: 「즉시 돌 거 같아. 도는 것이 보여」 — *"it starts turning right away,
## and the turning is visible."*). ⚠ **The user named Don't Starve for the 90° feel.**
##
## **Returns whether it took the key**, the same contract `_on_tilt_key` has.
##
## ⚠⚠ **IT ASKS FOR A NOTCH RATHER THAN TURNING.** `field_view.turn_notch` adds to what the board still
## owes and the view pays it off frame by frame — **two quick presses turn a half** instead of one of
## them being eaten in the middle of the other's sweep.
## ⚠⚠ **The `echo` guard is not optional.** OS auto-repeat on a held key delivers
## `pressed = true, echo = true` many times a second, and a quarter per repeat spins the board.
## ⚠ **Ungated, exactly as the tilt is** — 티켓 07 asks whether a hand may move the board mid-fight,
## and gating it before that is decided would answer it by omission.
func _on_turn_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	if key.keycode == KEY_Q:
		field_view.turn_notch(-Look.CAM_YAW_SNAP_DEG)
		return true
	if key.keycode == KEY_E:
		field_view.turn_notch(Look.CAM_YAW_SNAP_DEG)
		return true
	return false


## R stands the camera up toward looking straight down, F lays it over toward the horizon — one notch
## each. **Returns whether it took the key**, which is the honest answer to 「did this handler consume
## the event」 and what every net that drives a key reads.
##
## ⚠⚠ **Q AND E WERE THE KEYBOARD'S TURN, THEY WERE DELETED, AND THEY ARE BACK** (2026-08-31, the
## user: 「QE 이거 기능제거해줘」; restored 2026-09-02). They stood here from 2026-08-24 (「3D 회전 회전
## 버튼이 내가 돌려봐야 될 듯」) and called the same `turn_by` the right-button drag called. **The drag
## is what is deleted now, and they are the only way a player turns the board** — see `_on_turn_key`,
## which is where they live rather than inside this function. The tilt keys were never asked to go and
## did not.
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


# --- the edge pan -----------------------------------------------------------------------------------

## **The pointer parked against a side of the window pans the camera that way, for as long as it stays
## there** (2026-08-30, the user: 「wasd 보다는 마우스가 끝으로 가면 자동으로 이동이 맞을듯」).
##
## ⚠⚠ **`_edge_pan_dir` AND `_edge_ramp` STOOD HERE, BOTH WERE DELETED, AND BOTH ARE BACK**
## (2026-08-31, the user: 「그것도 지워줘」; restored 2026-09-02 with the keys, in one reversal, because
## the selection box takes the left drag). **What went with the band came back with it**: the three
## constants in `look.gd`, the off-glass sentinel on the remembered pointer, the alt-tab and
## mouse-exit flags with the `_notification` that sets them, and the rows in `net_shell`.
##
## Answers a SCREEN-space direction whose axes each run 0..1, spent by `_pan_the_board` against the
## frame's own delta exactly as the keys are. **Zero means the edge is asking for nothing.**
##
## ⚠⚠ **THE SIGNS ARE `_on_pan_key`'S, WHICH ARE THE MOUSE DRAG'S.** `pan_by` takes the delta a DRAG
## would deliver, so 「look east」 is a NEGATIVE x — the pointer on the right edge therefore answers
## -1, the same number D answers. Getting this backwards is a control that works and feels wrong, and
## the one thing that pins it is that all three inputs go through the one call.
##
## ⚠⚠ **A CORNER IS TWO EDGES AND THE RESULT IS NOT NORMALISED**, so a corner travels 1.41 times as
## fast as a side. **That matches the keys and it matches a mouse drag**, both of which are
## deliberately un-normalised — a diagonal drag covers more ground and so does this.
##
## ⚠⚠ **IT ANSWERS ZERO WHILE A BUTTON GESTURE IS IN FLIGHT, AND THAT IS THE WALK ORDER'S PROTECTION.**
## The band overlaps ground a body gets ordered onto; with the camera sliding between the press and the
## release, `_end_press` would resolve `_press_at` against a camera that had moved and command a
## different 조각 than the one under the finger. **Holding still for the length of a press is what
## keeps a click near the edge a click.** ⚠ It costs nothing a drag wanted: a drag is already panning.
## ⚠⚠ **THAT GATE IS RESTORED AS IT WAS AND IS NOT RE-DECIDED HERE.** It was written when the left
## button both panned and ordered; 03-04 makes the left drag a box and 03-11 moves the order onto the
## right button, and **whichever of those lands is where this gate is next argued about.**
## ⚠⚠ **ARGUED ABOUT ON 2026-09-02 (03-11): THE GATE STAYS, GROWS ONE FLAG, AND ITS TWO HALVES GUARD
## DIFFERENT THINGS.** A right click near the edge is a click and the band does not slide under it —
## the same rule the left button has, and nothing new on screen.
##  - `_press_open` / `_panning`, the LEFT half, is a defect guard: the `_end_press` example above is
##    the old reason, and the 2026-09-02 reason is that since 03-16 the pick is resolved on the glass at
##    RELEASE, so a band that slid under a held left press would change which body is under the finger.
##  - `_order_open`, the RIGHT half, is a decision and not a defect guard: the order has already fired
##    when the band would slide (`_begin_order`), so what the flag holds still is **the rule that a held
##    button does not travel the board** — a right button held on water or on a dark 칸 (an order that
##    went nowhere) does not push the island out from under the hover plate.
## Deleting either flag from the gate reddens its own band row in `net_shell`, and neither row carries
## the other.
##
## ⚠ **The focus flag is NOT read here** — it gates the whole summed velocity one level up, because a
## focus loss stops the keys too. `_pointer_inside` is this function's own: a cursor that has left the
## window says nothing about a keyboard.
func _edge_pan_dir() -> Vector2:
	if not _pointer_inside:
		return Vector2.ZERO
	if _press_open or _panning or _order_open:
		return Vector2.ZERO
	# ⚠ **The window's own constants and not `get_viewport_rect()`.** Headless the window is 64x64 and
	# every screen position this shell is driven with is in `look.gd`'s 1280x720 — asking the real
	# viewport would put the whole band in a place nothing ever points at.
	var w := Look.VIEWPORT_W_PX
	var h := Look.VIEWPORT_H_PX
	# **Off the glass entirely is not「as deep as it goes」, it is nothing.** A pointer dragged out past
	# the frame still delivers motions, and clamping its depth instead would pan at full speed for as
	# long as it stayed out there. ⚠ **It is also what makes `_pointer_at`'s opening `(-1, -1)` mean
	# 「nothing」** — at the origin this guard passes and both axes read as fully deep.
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


## How much of the top speed a pointer `depth` of the way through the band gets: the lip's fraction at
## the inner lip, 1.0 hard against the window's edge. **`Look.CAM_EDGE_PAN_LIP_FACTOR` is the whole
## shape** — at 1.0 this returns 1.0 everywhere and the band is flat.
func _edge_ramp(depth: float) -> float:
	var lip := Look.CAM_EDGE_PAN_LIP_FACTOR
	return lip + (1.0 - lip) * clampf(depth, 0.0, 1.0)


## **Alt-tab, and the pointer leaving the window.** Both stop the edge pan, and neither can be seen
## from an input event — they are the two ways a pointer stops being where `_pointer_at` says it is.
##
## ⚠⚠ **THIS IS THE ONLY `_notification` IN THE REPO**, and without it the camera slides while the
## player is alt-tabbed away.
## ⚠ **This is not a reader of the `Input` singleton**, so a net drives it the same way it drives every
## other input here: by calling the method with the notification the engine would have sent.
## ⚠ **Application focus AND window focus.** They are two different notifications and either one can
## arrive alone; watching only one leaves the other alt-tab still sliding.
## ⚠⚠ **A FOCUS LOSS ALSO DROPS EVERY HELD KEY**, because that is the one event a key-up cannot follow:
## the release lands on whatever took the focus, and a flag left set pans the island on the way back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer_inside = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_pan_held.clear()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


## **What a LEFT press does on the island: picks the body under it, or lets go.** True when the press
## was consumed — a pick or a let-go — which is what tells `_end_press` it was not a pan.
##
## ⚠⚠ **`_order_walk_at` STOOD HERE AND IT IS DELETED** (2026-08-31). It ordered **the body nearest
## the press**, with no selection at all: one press, one walk, and whichever body happened to be
## closest answered it. Its own comment named the day it would die — 「when squads exist, this is the
## function that grows a selection instead of a nearest-body rule」 — and this is that function.
##
## **Two things and no third** (2026-08-31, the user: 「tab 없이 그냥 캐릭터를 누르면 이동할 수 있는
## 칸들이 뜨고 눌러서 이동하는거임」; 2026-09-02, the glossary's 「빈 땅을 왼쪽으로 누르면 놓는다」):
##
##  - **a press on a drawn body picks him** — on an empty hand and on a full one alike;
##  - **a press on anything else lets go** of whatever the hand holds.
##
## **The walk is the RIGHT button's** — `_order_the_island`, which is the arm that stood in here.
##
## ⚠⚠ **THE OLD TABLE IS KEPT, WRITTEN ONTO** — it stood here from 2026-08-31 to 2026-09-02 (the user:
## 「esc를 하지 않는 이상 이동 우선으로 해줘야할듯한데」):
##
##  - **empty hand** -> a press on a body picks it, and its reach lights;
##  - **full hand** -> a press on a lit 칸 is a walk, and a body standing there does not intercept it;
##  - **full hand, pressed anywhere else** -> nothing. **ESC is the only thing that lets go.**
##
## The first line stands. **The second moved to the right button, on its press** (03-11). **The third is
## REVERSED by the user on 2026-09-02** — a left press on nothing lets go, StarCraft's rule, and ESC
## stays as the second way; ticket 03-04's Answer and `a-left-press-on-nothing-keeps-the-hand` in
## `docs/design/` carry the reversal.
##
## ⚠ **The 조각 → 칸 conversion paragraph moved to `_begin_order`** with the arm that makes the 칸; this
## function reads no 조각 at all now.
##
## ⚠ **True means the press was consumed**, which is what tells `_end_press` it was not a pan — the
## same contract `_order_walk_at` had.
func _press_the_island(at: Vector2) -> bool:
	if battle == null:
		return false
	# ⚠⚠ **A FULL HAND MOVES; AN EMPTY HAND PICKS. THE BODY TEST CAME FIRST FOR ONE ROUND AND IT IS
	# REVERSED** (2026-08-31, the user at the screen: 「이게 조각에 옮길 수가 있잖아? 같은 조각으로?
	# 그때 살짝 불편하네? 이게 esc를 하지 않는 이상 이동 우선으로 해줘야할듯한데」).
	#
	# **The old line is kept rather than erased**: it read 「a body first, always」, and its reasoning
	# was that a picked body must stay re-pickable. **What it did on screen** is what killed it — a
	# 조각 with somebody standing on it is a 조각 you may want to send another body TO, and the body
	# test swallowed the press and picked the man already standing there instead. ⇒ **while the hand
	# holds anybody, a press on a lit 칸 is a walk and nothing else looks at it.**
	#
	# ⚠⚠ **AND ON 2026-09-02 THE FULL HAND'S MOVE LEFT THIS BUTTON** (ticket 03-11): it moves on the
	# RIGHT button, on its press, in `_order_the_island`. What the 2026-08-31 reversal protected — a
	# 조각 with somebody on it is a 조각 you may want to send another body TO — the split protects now:
	# the right button never asks `body_at_px`, so the body standing there cannot intercept an order.
	# **The body test is FIRST again on this button**, and this time nothing stands behind it that it
	# could swallow.
	#
	# **The body is found on the glass and not on the ground** (2026-09-02, the user: 「몸은 화면에서
	# 잡자」 — *"let us pick the body on the glass"*, ticket 03-16). This line read
	# `hand.body_at(battle, _point_at(at), Look.PICK_BODY_TILES)` — the press turned into a ground point
	# and measured against `soldier_pos` — and it missed every chest and head press at yaw 90 and 180,
	# because a body stands UP from its feet and screen-up turns with the board. **The view knows where it
	# drew each body and nothing else does**, so it answers; the pick itself is still `Hand.pick`, a sim
	# fact a net drives with `.new()`.
	var who := field_view.body_at_px(at)
	if who >= 0:
		# **A full hand re-picks here** — `pick_many` calls `clear()` first — so one press swaps the
		# 부대 without ESC in between, and no line is needed for it.
		# ⚠⚠ **THE ARM ORDER IS A RULE, NOT A TIDINESS: `body_at_px` FIRST, THE LET-GO SECOND.** With the
		# let-go below asked first, this same press would drop the 부대 and pick nobody, so a player
		# could never change what the hand holds without ESC in between — and every pick that lands on
		# an EMPTY hand stays green over it. `net_shell`'s full-hand-on-a-body rows (the same body's own
		# foot, then another body's) are what pin the order.
		var picked := hand.pick(battle, who)
		_tell_the_view()
		return picked
	# ⚠⚠ **A PRESS THAT CANNOT BE A WALK KEEPS THE HAND, AND ESC IS THE ONLY WAY TO LET GO** (the user,
	# 2026-08-31, same sentence: 「esc를 하지 않는 이상」). **The sea used to drop the selection here** —
	# which meant a hand aimed a little wide lost the body it had, and the player had to pick him again
	# to try the same order twice.
	#
	# ⚠⚠ **REVERSED BY THE USER ON 2026-09-02** — the glossary's 「ESC 아니면 부대를 안 놓는다」 → 「빈
	# 땅을 왼쪽으로 누르면 놓는다」 (*"a left press on empty ground lets go"*). The rule above existed
	# because ONE button did both jobs; with the walk on the right button a wide press costs nothing,
	# and StarCraft — which the user named — clears on a click on nothing. **ESC stays as the second
	# way.** The old line is kept above rather than erased, because this repo records a flip.
	#
	# ⚠⚠ **NO 칸, NO `_tile_at`, NO `can_reach_block` IN FRONT OF THIS LINE.** 「nothing」 is anything
	# `body_at_px` answers -1 for — lit ground, dark ground, water, off the board — one rule and no
	# special case for the sea. A let-go gated on the reachable 칸 is the 2026-08-31 rule left standing
	# for the one press the reversal exists for, the press that MISSES, and it passes every lit-칸 row;
	# `net_shell`'s two miss rows (off the board, and a 칸 the hand refuses) are what catch it.
	if not hand.is_empty():
		_let_go()
		return true
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
## cursor is off the reach** — a route to a 칸 the press would refuse is a line the game will not
## walk.
##
## ⚠⚠ **IT ASKS THE SAME QUESTION `_begin_order` ASKS, IN THE SAME UNIT.** Both convert the cursor's
## 조각 to a 칸 with `Grid.block_of`, both gate on `can_reach_block`, and both hand that 칸 to `Hand`.
## **The preview drawn from a different unit than the press would be a line to a place the click does
## not go**, and neither side would go red saying so. ⚠ It read `_press_the_island` until 2026-09-02
## (03-11); that function reads no 칸 any more, and the order it asked about is the right button's.
func _show_route(at: Vector2) -> void:
	if battle == null or hand.is_empty():
		return
	var tile := _tile_at(at)
	var block := battle.grid.block_of(tile) if tile >= 0 else -1
	if not hand.can_reach_block(block):
		field_view.set_move_lines([])
		return
	field_view.set_move_lines(hand.route_points(battle, block), hand.ids)


## ⚠⚠ **`_point_at` STOOD HERE AND IT IS DELETED** (2026-09-02, ticket 03-16). It answered a screen
## press in 조각 units with the fractions kept — `screen_to_terrain_px(at) / Look.TILE_PX` — for
## `Hand.body_at` to measure against `soldier_pos`. **Its one caller is gone**: the body is picked on
## the glass by `FieldView.body_at_px`. **What it cost is worth keeping**: in its unit a 조각's centre
## is `(tx + 0.5, ty + 0.5)` while `soldier_pos` puts the centre ON the integer (`Look.tile_point_px`'s
## header is the convention), so every press it answered was already 0.71 조각 from a body standing
## dead under it. Anything that ever converts a ground point to `soldier_pos` units again reads that
## header first.


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
## the tombstone where `_turning` was declared, which carries all four of the user's words in order,
## the 2026-09-02 one that deleted the drag included.
##
## ⚠⚠ **SHIFT+WHEEL IS DELETED AND IT WAS NEVER THE USER'S.** While the bare wheel turned the board,
## a previous builder pinned the zoom to SHIFT+wheel and wrote down that the pairing was **unowned** —
## nobody asked for it and nothing measured it. With the bare wheel zooming again it had nothing left
## to do, and **a second unowned path to one state is exactly what this file refuses to keep**: two
## gestures for one zoom drift apart the first time either is tuned.
##
## ⚠ **R/F is untouched.** It is the keyboard's tilt and goes through the same `tilt_by` the rest of
## the shell does — a second path to one state, never a second state.
## ⚠⚠ **Q/E STOOD BESIDE IT AS THE KEYBOARD'S TURN, WAS DELETED, AND IS BACK** (2026-08-31, the user:
## 「QE 이거 기능제거해줘」; restored 2026-09-02 at a quarter a press). The line that closed this —
## 「the right button's drag is the only turn」 — **is the half that stopped being true**: the drag is
## deleted and Q and E are the only turn.
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
#    ⇒ **`_press_the_island` is the only hit test a field press gets now.** ⚠ A LEFT press, since
#    2026-09-02 (03-11): the right button's `_order_the_island` asks no hit test at all.
