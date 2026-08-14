extends SceneTree
## The game screenshots itself. **This is the bridge-less half of verify-look**, and `CLAUDE.md` names it
## in one line ("without the bridge the game can `save_png()` itself") without anything implementing it.
##
## ⚠ **It must NOT be run with `--headless`.** A headless run has no swapchain, `root.get_texture()` comes
## back blank, and every PNG is a black rectangle with no error anywhere — the exact shape this repo calls
## the signature fake. Measured: the runner (`tests/run_nets.gd`) pumps real frames headless and `_draw()`
## genuinely runs, so a net can assert *arguments*; what headless cannot do is hand back *pixels*.
##
## ⚠ **It takes the user's screen for as long as it runs.** A window opens and holds focus. That is why it
## quits by itself on the last shot and why every wait below is counted in frames rather than seconds —
## nothing here may block waiting for a person. It injects nothing into the OS: every input goes through
## `root.push_input()`, inside the engine, so the user's mouse and keyboard are untouched
## (`agents/verify-look.md` — the rule that forbids the Win32 route).
##
## Usage (from the repo root, and the `--` matters):
##   .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture.gd -- <output-dir>
##
## The shell is built the same way every net builds it — `main.gd`'s own `_ready()`, never hand-wired —
## so what is photographed is the wiring the game runs.

## Real frames, not seconds. The camera lerps toward its target and the zoom eases with it, so a shot
## taken too early photographs the ease rather than the game. 90 is past both.
const SETTLE := 90
const BEAT := 40

var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "look_out"
	DirAccess.make_dir_recursive_absolute(_dir)
	print("[look] -> %s" % _dir)
	await _run()
	quit(0)


func _run() -> void:
	var main: Node = load("res://src/shell/main.gd").new()
	root.add_child(main)
	await _frames(2)

	# The real path in, exactly as `net_cards` and `net_hands` take it: the title's own signal. A private
	# starter called directly would hide the shell's `connect()` line.
	main.title.start_pressed.emit()
	await _frames(SETTLE)
	var w: World = main.run.world

	# 1 — a bare host. The baseline every other shot is read against: no parts, so no limbs, no outline,
	# no eyes, and the plain corner radius.
	await _shot("01_bare_host")

	# 2 — the whole August table worn, and a swarm to read it against. `wear()` rather than a card, so the
	# picture is of the body and not of the panel that filled it.
	for p in [Parts.HORSE_LEGS, Parts.HORSE_MANE, Parts.HORSE_LUNG]:
		w.body.wear(p)
	w.swarm.force[0] = 80
	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	w.swarm.split_release()
	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	w.swarm.split_release()
	await _frames(SETTLE)
	await _shot("02_horse_body")

	# 3 — the same body zoomed to fill the frame. The host is ~14px against 1280 and the question the plan
	# actually asks ("did the body visibly become a horse") cannot be answered at that size; this is the
	# same picture, large enough to judge. Camera only — nothing in the simulation moves.
	#
	# ⚠ **`main._zoom` too, not `cam.zoom` alone.** `_apply_zoom()` runs every frame in PLAY and rewrites
	# `cam.zoom` from its own `_zoom`, so a camera set from outside is undone before the shot and the
	# picture comes back at play scale — silently, and it looks like the zoom simply had no effect.
	await _zoom_to(main, 6.0)
	await _shot("03_horse_close")

	# 4 — the internal slots, which **no card in the August table can reach**: BONE, HIDE and EYES have no
	# part, so their drawing is unreachable in play and only a net has ever driven it. Written straight
	# into `slot_part` to see what plan 4 will be turning on.
	w.body.slot_part[Parts.Slot.BONE] = Parts.HORSE_MANE
	w.body.slot_level[Parts.Slot.BONE] = 2
	w.body.slot_part[Parts.Slot.HIDE] = Parts.HORSE_MANE
	w.body.slot_level[Parts.Slot.HIDE] = 2
	w.body.slot_part[Parts.Slot.EYES] = Parts.HORSE_MANE
	w.body.slot_level[Parts.Slot.EYES] = 3
	await _zoom_to(main, 6.0)
	await _shot("04_internal_slots")

	w.body.slot_part[Parts.Slot.BONE] = -1
	w.body.slot_level[Parts.Slot.BONE] = 0
	w.body.slot_part[Parts.Slot.HIDE] = -1
	w.body.slot_level[Parts.Slot.HIDE] = 0
	w.body.slot_part[Parts.Slot.EYES] = -1
	w.body.slot_level[Parts.Slot.EYES] = 0
	await _zoom_to(main, Look.ZOOM_NEAR)

	# 5 — `Tab`, filled. Through the shell's own key handler, so the panel is opened the way a player opens
	# it and `run.paused` moves with it.
	main._unhandled_key_input(_key(KEY_TAB))
	await _frames(BEAT)
	await _shot("05_body_panel")
	main._unhandled_key_input(_key(KEY_TAB))
	await _frames(2)

	# 6 — three part cards, one of them a level-up. The pool is locked on what has been eaten and plan 4 is
	# what puts a horse on the field, so the unlock is written here directly — that lock is the subject of
	# `net_cards`, not of this shot.
	if not w.species_eaten.has(Parts.Species.HORSE):
		w.species_eaten.append(Parts.Species.HORSE)
	w.swarm.banked = 400.0
	await _frames(BEAT)
	await _shot("06_card_pick")

	# 7 — the ending, with the eleven squares carrying what the body actually finished wearing. Picked
	# through the panel first so the run is not sitting frozen on an unspent level when the beat starts.
	while main.run.world.pending_levels > 0 and not main.run.world.offer.is_empty():
		main.cards.picked.emit(main.run.world.offer[0])
		await _frames(2)
	main.run.world.stage_cleared = true
	await _frames(SETTLE)
	await _shot("07_ending")

	root.remove_child(main)
	main.queue_free()


## `RenderingServer.frame_post_draw` is the whole trick: `root.get_texture()` read at any other moment
## hands back the PREVIOUS frame, so a shot taken right after a state change photographs the state before
## it — silently, and it looks like the change never landed.
func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	var err := img.save_png(path)
	print("[look] %s %s" % [name, "ok" if err == OK else "FAILED %d" % err])


## Both halves, and the second one is the load-bearing half — see the call site.
func _zoom_to(main: Node, z: float) -> void:
	main.cam.position = main.run.world.swarm.pos[0]
	main._zoom = z
	main.cam.zoom = Vector2(z, z)
	await _frames(2)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
