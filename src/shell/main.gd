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
## Where the camera would be with no shake on it. **`cam.position` is `_cam_base` plus this frame's shake,
## recomputed whole every frame and never accumulated** — the shake used to be `+=`'d straight onto
## `cam.position`, which made it the base of the NEXT frame's lerp: an offset added every frame while the
## follow pulled back only ~10.9% of it, converging on ~9× the intended displacement. `Look.SHAKE_MAX` then
## bounded the impulse and nothing bounded the picture (67.9px at 60fps, 160.4px at 144fps), and a sim frozen
## mid-shake by the body panel parked the camera 158px off the host until the panel closed. Every check was
## green: each reset `cam.position` by hand before pumping ONE frame, which is the one shape that
## structurally cannot see accumulation across frames.
var _cam_base := Vector2.ZERO


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
	# **The frame starts here, before anything can produce an event.** `_read_input()` below fires keys and
	# splits, both of which fill the one-frame lists `FieldView` draws bursts from, and it runs BEFORE
	# `run.step()` — so the sim cannot clear those lists at the top of its own step without erasing the
	# player's own kill and the `F` ring on the frame they happened. Outside the phase branch on purpose: the
	# lists must also be cleared while paused and on the ending screen, where nothing refills them.
	run.begin_frame()
	if run.phase == Run.Phase.PLAY:
		_sync_cards()
		if _panel_open():
			# **Not merely "skip the input"**: a poll left alone keeps its last value, so the host would
			# drift on the frame the panel closes, and an `F` charge would sit half-wound across a menu.
			# Both are dropped here — resuming a wind-up the player did not choose to resume is a decision
			# nobody made.
			run.world.swarm.host_input = Vector2.ZERO
			run.world.swarm.split_release()
			# **The third poll, and it is the one plan 3 added.** A SUSTAINED active runs off `held`, not
			# off an edge, so leaving the array alone keeps whatever `is_action_pressed` last saw — a
			# gallop latched on across a menu, invisible while `run.paused` holds it, and still running the
			# frame the panel closes. Same sentence as the `F` wind-up on the line above.
			run.world.body.held.fill(0)
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
		_apply_shake()
		_apply_zoom(delta)
		view.view_rect = _camera_rect()
		# **Two rects, two callers, and they are deliberately different.** `_camera_rect()` is padded 20%
		# so a body just off screen keeps being drawn while it walks back on; the HUD's copy is what a
		# minimap paints a camera box from, and a padded box is a box a fifth too big — wrong in a way the
		# screen never announces. Assigned AFTER `_apply_zoom`, so both rects are this frame's zoom and not
		# the previous one's.
		hud.camera_rect = _true_camera_rect()
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
	# Cleared with the world it describes. `_process` only writes it inside the PLAY branch, so a rect left
	# standing from the previous run is what the HUD would draw on TITLE and ENDING and on the first frame
	# of the next run — the same stale-reference shape the line above exists to prevent, one field over.
	hud.camera_rect = Rect2()
	# ⚠ **The panel holds the whole `World` now, and `cards` holds the `Body`.** `main.gd`'s own `body`
	# field is the PANEL and `World.body` is the `Body` — the same word for two things, on purpose, so
	# `body.world` reads as "the panel's world" and `run.world.body` as "the world's body". Miss either
	# line and the panel draws nothing on every `Tab` while the pause and toggle checks all stay green.
	body.world = run.world
	# The card face says `말 다리 → Lv2` when the part is already worn, and the level comes from here.
	cards.body = run.world.body if run.world != null else null
	if run.world != null:
		# **Both, or the next frame's `_apply_shake()` snaps the camera back to the previous run's base.**
		# `cam.position` is derived from `_cam_base` every frame, so seeding one and not the other leaves the
		# picture on the old run's ground for exactly as long as the follow lerp takes to close.
		_cam_base = run.world.swarm.pos[0]
		cam.position = _cam_base
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

	# All three keys go through `World.fire()`. A key that reaches into the simulation on its own would be a
	# fourth code path the gate above has to know about separately. Left and right on the same frame both
	# fire — the keys are independent and share no cooldown.
	#
	# ⚠ **`World.fire()`, not `Body.fire()`, and the difference is invisible from here.** Both return a
	# bool, both put the key on cooldown, both make the bite arc appear on screen; what only the `World`
	# one does is dispatch the ARC branch's `strike()`, which is the entire damage path for every key the
	# player will ever press. Written as `body.fire(key, aim)` the game draws a cone that hurts nothing and
	# no check about keys, cooldowns or drawing notices — `Body` may not hold a `World` (see body.gd's own
	# doc), so the delegation has to happen on this side. `held` still goes to the `Body` because a
	# SUSTAINED active never reaches `fire()` at all.
	#
	# ⚠ **Both the edge and the hold, every frame.** `fire()` is the one-shot; `held` is what a SUSTAINED
	# active runs off, and 갤럽 is "while held, draining breath". Wired to `just_pressed` alone it is a
	# one-frame gallop, which reads exactly like a dead key. `is_action_pressed` is also true on the frame
	# `just_pressed` fires, so a burst and a sustain never need different keys.
	var aim := get_global_mouse_position()
	var b := run.world.body
	for key in Body.KEY_COUNT:
		var action := "fire_%d" % key
		if Input.is_action_just_pressed(action):
			run.world.fire(key, aim)
		b.held[key] = 1 if Input.is_action_pressed(action) else 0

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
	_cam_base = _cam_base.lerp(run.world.swarm.pos[0], 1.0 - pow(0.001, delta * CAMERA_LAG / 9.0))


## `Swarm.hit_show[0]` is the host's own up-counting hit clock — the same shape `critter_hit_show` uses —
## so this owns no clock of its own, only the two `Look` numbers that turn it into an offset. A pure
## function of elapsed time and the landing hit's force, so two frames at the same `t` and the same force
## produce the SAME offset, which is what lets a net assert it rather than trusting `Math.random`.
##
## ⚠ **`cam.position`, never `cam.offset`.** `_camera_rect()` and `_true_camera_rect()` both derive from
## `position`, and the minimap's camera box and `view_rect` culling both read those two — an offset shake
## would move the picture while leaving the culled rectangle and the minimap box exactly where they were,
## which is a body flickering at the screen's edge for a reason nothing on screen explains.
##
## §D-1 reuses this exact machinery for the boss-hunt announcement — "흔들림 한 번, §B-2의 기계장치를
## 그대로 쓴다" — through the shared `_shake_offset()` below rather than by writing `host_hit_force`/
## `hit_show[0]` for a moment that is not an actual hit: those two are read by nets that pin them to real
## combat (`net_hunt`'s host-damage checks), and overloading them here would make "the host was just hit"
## and "the boss just started hunting" the same signal with no way to tell them apart.
## ⚠ **It ASSIGNS `cam.position` from `_cam_base`, it does not add to it** — see that field for the measured
## cost of adding.
func _apply_shake() -> void:
	var t: float = run.world.swarm.hit_show[0]
	var amp := minf(float(run.world.host_hit_force) * Look.SHAKE_PER_FORCE, Look.SHAKE_MAX)
	var offset := _shake_offset(t, amp)
	if run.world.boss_hunting():
		var since := run.world.elapsed - Rules.BOSS_HUNT_AT
		offset += _shake_offset(since, Look.SHAKE_MAX)
	cam.position = _cam_base + offset


## The shake's shape alone, pulled out of `_apply_shake()` so §D-1 can drive it off a second, unrelated
## clock without a second copy of the formula. Zero past `Look.SHAKE_TIME`, so a caller need not guard its
## own `t` before adding the result in.
func _shake_offset(t: float, amp: float) -> Vector2:
	if t >= Look.SHAKE_TIME:
		return Vector2.ZERO
	var decay := 1.0 - t / Look.SHAKE_TIME
	return Vector2(sin(t * Look.SHAKE_FREQ_X), sin(t * Look.SHAKE_FREQ_Y)) * amp * decay


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


## **The same rectangle without the culling pad** — exactly what the player can see, for `Hud.camera_rect`.
##
## ⚠ **It is a second function and not an argument to the one above.** `_camera_rect()`'s 1.2 exists so
## `FieldView` keeps drawing a body that is about to walk on screen; a camera box on a minimap drawn from
## it is 20% too large in both axes, which reads as "the map is roughly right" rather than as a bug. One
## function with a flag would put the two rects one boolean apart and nothing would say which caller
## wanted which.
func _true_camera_rect() -> Rect2:
	var vp := get_viewport_rect().size / cam.zoom.x
	return Rect2(cam.position - vp * 0.5, vp)


func _on_card_picked(card: int) -> void:
	run.world.take_card(card)
	_sync_cards()


## The panel asks, the sim decides, the panel reports. `Body.can_bind()` owns the rule that `space` takes
## movement parts only — the panel greying the row out in advance would be a second copy of it.
##
## ⚠ **`(part, key)`, matching `Body.bind()`.** Plan 2's signal and call were `(slot, active)` — both ints,
## both orders compile, and the wrong one binds backwards with nothing to catch it. The parameter names
## here are the only place the order is written down on this side of the signal.
func _on_bind_requested(part: int, key: int) -> void:
	if run.world == null:
		return
	if not run.world.body.bind(part, key):
		body.refuse()
