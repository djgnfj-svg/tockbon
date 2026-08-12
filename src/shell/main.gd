extends Node2D
## The only place that reads `Input`, and the only place that wires `sim` to `view`.
##
## **Children are built here in code rather than sitting in the scene**, so that a net which calls
## `_ready()` on a bare instance is exercising the same wiring the game runs. `CLAUDE.md` measured the
## opposite shape: a net that hand-wires the nodes it needs lets you delete the real `setup()` call and
## stay green while the game shows nothing.

const CAMERA_LAG := 9.0

var world := World.new()
var view: FieldView = null
var hud: Hud = null
var cards: CardPanel = null
var cam: Camera2D = null


func _ready() -> void:
	world.setup(int(Time.get_unix_time_from_system()))

	view = FieldView.new()
	view.world = world
	add_child(view)

	cam = Camera2D.new()
	cam.position = world.swarm.pos[0]
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Hud.new()
	hud.world = world
	layer.add_child(hud)

	cards = CardPanel.new()
	cards.picked.connect(_on_card_picked)
	layer.add_child(cards)


func _process(delta: float) -> void:
	_sync_cards()
	if world.pending_levels == 0 and not world.over:
		_read_input()
		world.step(delta)
	_follow_camera(delta)
	view.view_rect = _camera_rect()


## Opening the panel is driven off the sim's own state every frame rather than from a one-shot signal at
## the moment of level-up. A missed signal is a level the player never gets to spend, and the sim would
## sit frozen forever with nothing on screen explaining why.
func _sync_cards() -> void:
	if world.pending_levels > 0 and not world.offer.is_empty():
		if not cards.visible or cards.offer != world.offer:
			cards.show_offer(world.offer)
	elif cards.visible:
		cards.close()


func _read_input() -> void:
	# `get_vector` normalises — diagonal is (0.707, 0.707), not (1, 1). That is correct behaviour and the
	# reason the host is not faster on the diagonal.
	world.swarm.host_input = Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	if Input.is_action_just_pressed("dash"):
		world.swarm.try_dash()
	if Input.is_action_just_pressed("cmd_rally"):
		world.swarm.command_rally(get_global_mouse_position())
	if Input.is_action_just_pressed("cmd_scatter"):
		world.swarm.command_scatter()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R and world.over:
		get_tree().reload_current_scene()


func _follow_camera(delta: float) -> void:
	cam.position = cam.position.lerp(world.swarm.pos[0], 1.0 - pow(0.001, delta * CAMERA_LAG / 9.0))


func _camera_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(cam.position - vp * 0.5 - vp * 0.1, vp * 1.2)


func _on_card_picked(card: int) -> void:
	world.take_card(card)
	_sync_cards()
