extends Node2D
## The only place that reads `Input`, and the only place that wires `sim` to `view`.
##
## **Children are built here in code rather than sitting in the scene**, so that a net which calls
## `_ready()` on a bare instance is exercising the same wiring the game runs. `CLAUDE.md` measured the
## opposite shape: a net that hand-wires the nodes it needs lets you delete the real `setup()` call and
## stay green while the game shows nothing.
##
## **This file owns a `Run`, not a `World`.** Every phase's node is built once in `_ready()` — `FieldView`,
## `Camera2D`, `CanvasLayer`, `Hud`, `CardPanel`, `BodyPanel`, `TitleScreen`, `EndingScreen` — and only
## `visible` moves between phases. Adding or removing nodes per phase means a `_ready()` that runs more than once and
## fields that go stale between calls; `CLAUDE.md` records a panel that shipped without ever setting
## `visible` under 5,576 green checks.

const CAMERA_LAG := 9.0

var run := Run.new()
var view: FieldView = null
var hud: Hud = null
var cards: CardPanel = null
var body: BodyPanel = null
var title: TitleScreen = null
var ending: EndingScreen = null
var cam: Camera2D = null
var _zoom := Look.ZOOM_NEAR


func _ready() -> void:
	view = FieldView.new()
	add_child(view)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Hud.new()
	layer.add_child(hud)

	cards = CardPanel.new()
	cards.picked.connect(_on_card_picked)
	layer.add_child(cards)

	# Same `CanvasLayer` as the cards, and built here for the same reason everything else is: a net that
	# calls `_ready()` on a bare instance is exercising the wiring the game runs.
	body = BodyPanel.new()
	body.bind_requested.connect(_on_bind_requested)
	layer.add_child(body)

	title = TitleScreen.new()
	title.start_pressed.connect(_start)
	title.quit_pressed.connect(get_tree().quit)
	layer.add_child(title)

	ending = EndingScreen.new()
	ending.restart_pressed.connect(_restart)
	ending.title_pressed.connect(_to_title)
	layer.add_child(ending)

	_apply_phase()


## **`_apply_phase()` runs LAST, not first.** `run.step()` can flip PLAY → ENDING inside this same call —
## calling `_apply_phase()` before it would paint this frame with the PREVIOUS phase's visibility, one
## frame stale on the exact frame the death or the clear happens. Measured: `net_shell.gd`'s phase-visible
## check went red on that ordering (hud still shown, ending still hidden, the frame the run actually ended).
func _process(delta: float) -> void:
	if run.phase == Run.Phase.PLAY:
		_sync_cards()
		if _panel_open():
			# **Not merely "skip the input"**: a poll left alone keeps its last value, so the host would
			# drift on the frame the panel closes, and an `F` charge would sit half-wound across a menu.
			# Both are dropped here — resuming a wind-up the player did not choose to resume is a decision
			# nobody made.
			run.world.swarm.host_input = Vector2.ZERO
			run.world.swarm.split_release()
		else:
			_read_input(delta)     ## Input is read in PLAY with no panel open, and nowhere else
		# Derived every frame from the one panel that pauses, so the shell keeps no copy of its own — see
		# `run.gd`'s header on why one flag has one owner.
		run.paused = body.visible
		run.step(delta)
		if run.phase == Run.Phase.ENDING:
			# The frame the beat finishes, `run.result` becomes the snapshot the ending screen has to
			# show. A visibility flip repaints `EndingScreen` on its own — the live risk is this
			# assignment being forgotten, not the repaint. Same identity shape as `_bind_world()` below.
			ending.result = run.result
		_follow_camera(delta)
		_apply_zoom(delta)
		view.view_rect = _camera_rect()
	_apply_phase()


func _start() -> void:
	run.start(_new_seed())
	_bind_world()


func _restart() -> void:
	run.restart(_new_seed())
	_bind_world()


func _to_title() -> void:
	run.to_title()
	_bind_world()


## Called after start(), restart() AND to_title() — all three, not two. `to_title()` drops the world too,
## and leaving `view.world`/`hud.world` pointed at a dropped `World` is the exact stale-reference shape
## this exists to prevent.
func _bind_world() -> void:
	view.world = run.world
	# The view outlives the run and its harvest pop is driven off a high-water mark of `banked`. Left
	# standing, run two's bank never passes run one's and the host stops scaling on eating — see
	# `FieldView.reset_pop()`.
	view.reset_pop()
	hud.world = run.world
	body.swarm = run.world.swarm if run.world != null else null
	if run.world != null:
		cam.position = run.world.swarm.pos[0]
		_zoom = Look.ZOOM_NEAR      ## snap, never lerp: a restart opens alone and must open tight
		cam.zoom = Vector2(_zoom, _zoom)


## Monotonic microseconds, NOT int(Time.get_unix_time_from_system()) — that truncates to WHOLE SECONDS, so
## two restarts inside the same second would hand out the same seed and 다시 하기 would replay the
## identical field.
func _new_seed() -> int:
	return int(Time.get_ticks_usec())


func _apply_phase() -> void:
	title.visible = run.phase == Run.Phase.TITLE
	view.visible = run.phase != Run.Phase.TITLE
	hud.visible = run.phase == Run.Phase.PLAY
	ending.visible = run.phase == Run.Phase.ENDING
	if run.phase != Run.Phase.PLAY:
		cards.visible = false
		# Without this the body panel survives the run ending and sits over the ending screen, still
		# holding `run.paused` — which `Run._open()` then has to undo on the next 다시 하기. Assigned
		# rather than `close()`d, exactly like `cards` above: this runs every frame outside PLAY, and
		# `close()` would queue a redraw of an invisible Control sixty times a second. `open()` is what
		# clears the panel's own state, so nothing is lost.
		body.visible = false


## Opening the panel is driven off the sim's own state every frame rather than from a one-shot signal at
## the moment of level-up. A missed signal is a level the player never gets to spend, and the sim would
## sit frozen forever with nothing on screen explaining why.
func _sync_cards() -> void:
	if run.world.pending_levels > 0 and not run.world.offer.is_empty():
		if not cards.visible or cards.offer != run.world.offer:
			cards.show_offer(run.world.offer)
	elif cards.visible:
		cards.close()


## **A polled action is not consumed by a `Control`.** No `mouse_filter`, no `set_input_as_handled()` stops
## `Input.is_action_just_pressed` from seeing the click that picked a level-up card or bound an active — so
## clicking a card would also fire slot 0. This is the whole gate, and it replaced a narrower one that
## named `pending_levels`: that was the same idea written for one of the two panels.
func _panel_open() -> bool:
	return cards.visible or body.visible


func _read_input(delta: float) -> void:
	var sw := run.world.swarm
	# `get_vector` normalises — diagonal is (0.707, 0.707), not (1, 1). That is correct behaviour and the
	# reason the host is not faster on the diagonal.
	sw.host_input = Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")

	# All three slots go through `fire()`. A key that reaches into the simulation on its own would be a
	# fourth code path the gate above has to know about separately. Left and right on the same frame both
	# fire — the slots are independent and share no cooldown.
	var aim := get_global_mouse_position()
	for slot in Swarm.SLOT_COUNT:
		if Input.is_action_just_pressed("fire_%d" % slot):
			sw.fire(slot, aim)

	# Held, not tapped: the wind-up is what makes the split read as an act. `split_release()` also runs in
	# the panel-open branch above, which is how the charge gets dropped rather than paused.
	if Input.is_action_pressed("split"):
		sw.split_hold(delta)
	elif Input.is_action_just_released("split"):
		sw.split_release()

	if Input.is_action_just_pressed("absorb"):
		sw.absorb()
	if Input.is_action_just_pressed("cmd_rally"):
		sw.command_rally()
	if Input.is_action_just_pressed("cmd_scatter"):
		sw.command_scatter()
	if Input.is_action_just_pressed("cmd_strike"):
		sw.command_strike(aim)


## The only place `Tab`, `Esc` and `R` are read. They are events rather than polls because a panel toggle
## that fires once per press cannot be expressed as "is the key down this frame".
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if run.phase == Run.Phase.ENDING:
		if key.keycode == KEY_R:
			_restart()
		elif key.keycode == KEY_ESCAPE:
			_to_title()
		return
	if run.phase != Run.Phase.PLAY:
		return
	if key.is_action_pressed("body_panel"):
		# Ignored while the cards are up. One panel at a time: the cards are not dismissable, and a stack
		# of two pauses has no owner.
		if cards.visible:
			return
		if body.visible:
			body.close()
		else:
			body.open()
	elif key.keycode == KEY_ESCAPE:
		# PLAY: Esc closes the body panel and does nothing else — not a pause, not a quit, not a menu.
		body.close()


func _follow_camera(delta: float) -> void:
	cam.position = cam.position.lerp(run.world.swarm.pos[0], 1.0 - pow(0.001, delta * CAMERA_LAG / 9.0))


## Frame-rate independent, `1.0 - exp(-ZOOM_LERP * delta)`. Target read from `swarm.count` (bodies, host
## included) against `Look.ZOOM_FULL_AT` — see look.gd.
func _apply_zoom(delta: float) -> void:
	var target: float = lerpf(Look.ZOOM_NEAR, Look.ZOOM_FAR,
			clampf(float(run.world.swarm.count) / Look.ZOOM_FULL_AT, 0.0, 1.0))
	_zoom = lerpf(_zoom, target, 1.0 - exp(-Look.ZOOM_LERP * delta))
	cam.zoom = Vector2(_zoom, _zoom)


## **Divides by zoom.** At `ZOOM_FAR` (0.8) the real visible width is `vp / 0.8 = 1.25 × vp`, while an
## un-divided rect only covers `1.2 × vp` — things inside the screen would stop being drawn at the exact
## moment the zoom starts doing its job.
func _camera_rect() -> Rect2:
	var vp := get_viewport_rect().size / cam.zoom.x
	return Rect2(cam.position - vp * 0.5 - vp * 0.1, vp * 1.2)


func _on_card_picked(card: int) -> void:
	run.world.take_card(card)
	_sync_cards()


## The panel asks, the sim decides, the panel reports. `Swarm.bind()` owns the rule that `space` takes
## movement actives only — the panel greying the row out in advance would be a second copy of it.
func _on_bind_requested(slot: int, active: int) -> void:
	if run.world == null:
		return
	if not run.world.swarm.bind(slot, active):
		body.refuse()
