extends Node2D
## The only place that reads `Input`, and the only place that wires `sim` to `view`.
##
## **Children are built here in code rather than sitting in the scene**, so that a net which calls
## `_ready()` on a bare instance is exercising the same wiring the game runs. `CLAUDE.md` measured the
## opposite shape: a net that hand-wires the nodes it needs lets you delete the real `setup()` call and
## stay green while the game shows nothing.
##
## **This file owns a `Run`, not a `World`.** Every phase's node is built once in `_ready()` — `FieldView`,
## `Camera2D`, `CanvasLayer`, `Hud`, `CardPanel`, `TitleScreen`, `EndingScreen` — and only `visible` moves
## between phases. Adding or removing nodes per phase means a `_ready()` that runs more than once and
## fields that go stale between calls; `CLAUDE.md` records a panel that shipped without ever setting
## `visible` under 5,576 green checks.

const CAMERA_LAG := 9.0

var run := Run.new()
var view: FieldView = null
var hud: Hud = null
var cards: CardPanel = null
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
		if run.world.pending_levels == 0:
			_read_input()          ## Input is read in PLAY and nowhere else
		run.step(delta)            ## Run owns the pause; the shell keeps no copy of its own
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
	hud.world = run.world
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


## Opening the panel is driven off the sim's own state every frame rather than from a one-shot signal at
## the moment of level-up. A missed signal is a level the player never gets to spend, and the sim would
## sit frozen forever with nothing on screen explaining why.
func _sync_cards() -> void:
	if run.world.pending_levels > 0 and not run.world.offer.is_empty():
		if not cards.visible or cards.offer != run.world.offer:
			cards.show_offer(run.world.offer)
	elif cards.visible:
		cards.close()


func _read_input() -> void:
	# `get_vector` normalises — diagonal is (0.707, 0.707), not (1, 1). That is correct behaviour and the
	# reason the host is not faster on the diagonal.
	run.world.swarm.host_input = Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	if Input.is_action_just_pressed("dash"):
		run.world.swarm.try_dash()
	if Input.is_action_just_pressed("cmd_rally"):
		run.world.swarm.command_rally(get_global_mouse_position())
	if Input.is_action_just_pressed("cmd_scatter"):
		run.world.swarm.command_scatter()


## The only place either key is read.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if run.phase == Run.Phase.ENDING:
		if key.keycode == KEY_R:
			_restart()
		elif key.keycode == KEY_ESCAPE:
			_to_title()
	# PLAY: Esc does nothing — not a pause, not a quit. A decision made here rather than a menu invented.


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
