extends SceneTree
## The LEVEL, photographed. **A fourth capture tool, not an edit to the other three.** `capture.gd` shoots one
## body, `capture_bodies.gd` shoots a crowd, `probe_field.gd` and `probe_run.gd` read no pixels at all — and
## none of them answers the question the user asked after playing: 「그냥 몬스터가 내 주변에 없어」. That is a
## question about **what stands on the opening screen and what arrives after it**, so it needs the field at
## t = 0, the field as the clock runs, and a fight in the middle of it.
##
## Usage (from the repo root, and the `--` matters):
##   .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_level.gd -- <dir>
##
## ⚠ Read `tools/look/README.md` before changing anything here. Its three rules bind this file too and each
## one fails silently:
##  · **never `--headless`** — no swapchain, `root.get_texture()` comes back blank, every PNG is a black
##    rectangle and no error is raised anywhere. Refused outright in `_initialize()`, the way the crowd tool
##    refuses it, because under the dummy renderer the first shot does not merely come back black: it waits
##    for a `frame_post_draw` that never arrives and the run hangs.
##  · **never the user's mouse or keyboard.** The one input this tool has is a left click on the title's own
##    시작하기 button and it goes through `root.push_input()`, inside the engine.
##  · **`RenderingServer.frame_post_draw` before every read**, or `get_texture()` hands back the PREVIOUS
##    frame — which here would be the previous SECOND of a ramp, silently.
##
## ⚠ **The hand that plays the ramp is a camera driver and NOT a verdict.** `probe_run` owns the question of
## whether a person can play this field, and it owns the three rules that decide what is worth attacking;
## `_policy()` below is the same shape on purpose — a camera that follows a run has to walk like the hand that
## measured it — but nothing here counts anything or concludes anything. If the two ever diverge, the verdict
## is that file's and this one is still only a lens.
##
## **This file judges nothing.** It writes frames and a console line beside each one saying what was in the
## world when the shutter opened. Whether the picture is good is the user's call.

## The one seed every sequence is built from, so the ramp is one run rather than five fields.
const SEED := 20260816
## The active slot the hand clicks. Left click is slot 0 and 물기 is what a fresh run has bound there — the
## three slots are empty squares a player binds an active into, so this is the opening binding and not a
## constant of the game.
const BITE_KEY := 0
const FRAME_BUDGET := 6000
const STEP_DT := 1.0 / 60.0
## How many simulation frames the ramp may run between two yields to the engine. Nothing is drawn in between,
## so a rendered frame per stepped frame would put the whole 150 seconds on the wall clock.
const YIELD_EVERY := 600

## `00_known_answer`'s zoom, and the whole shot is built around it being a number the answer can be computed
## from before the shutter. Inherited from the crowd tool deliberately: the trap it catches — `_apply_zoom()`
## rewriting `cam.zoom` from the shell's own field, so a camera set from outside is undone before the shutter —
## is a property of the shell, not of that file.
const KNOWN_ZOOM := 4.0
## And **away from the host's own start point**, which is where `main._bind_world()` leaves `_cam_base`. Shot
## on top of it, the camera-position half of the check proves nothing: the stale value happens to be right.
const KNOWN_AT := Vector2(700.0, 420.0)
const KNOWN_TOLERANCE := 0.15
const COLOR_EPS := 0.02
const KNOWN_WINDOW := 800

## The ramp's shutter times, in seconds of `World.elapsed`. The last one is `Rules.BOSS_HUNT_AT` and it is not
## written here — it is read, so a retune of the hunt moves the picture with it.
const RAMP_AT := [0.0, 30.0, 60.0, 90.0, 120.0]
## How long after the hunt starts the boss is given to actually arrive, before this file says it did not.
## `Rules.SPECIES_SPEED_MUL[BOSS]` is under `HOST_SPEED`, which that table's own comment names as the reason
## the arena may never close on its own — so a cap here is not impatience, it is the documented case.
const BOSS_WAIT := 90.0

## The fight: the host's force before it splits, and how many times it splits. Both are numbers a run reaches
## — `probe_run` ends at force 97 by the hunt — and the split is `Swarm.split_hold`/`split_release`, the two
## calls `F` makes, so the eight bodies in the picture are eight bodies the game can produce.
const FIGHT_FORCE := 80
const FIGHT_SPLITS := 3
const FIGHT_ZOOM := 2.2
## Simulation frames between two shots of the fight, and the most shots it may take.
const FIGHT_EVERY := 4
const FIGHT_SHOTS := 46
## How many shots keep being taken after the thing dies — the corpse and the swarm turning off it are part of
## what a kill looks like.
const FIGHT_TAIL := 8

## Up to this many play-scale frames are lifted out of the RAMP run at moments the host is actually swinging.
## A staged fight is shot close so the gestures are legible; this is the same event at the scale it is played
## at, and it is taken from the real run rather than staged twice.
const PLAY_FIGHT_SHOTS := 3
## Not before this second — the opening frames are their own sequence and would be photographed twice.
const PLAY_FIGHT_AFTER := 20.0

## The species shots frame the GESTURE, not the body: every one of them reaches further than the creature
## does (보스 내려찍기 is 2.2× its radius) and a zoom picked off the radius alone clips the largest ones.
## `zoom = SPECIES_FIT / <the pair's own extent>`, clamped, so a 들쥐 is visible and a 보스 fits.
const SPECIES_FIT := 300.0
const SPECIES_ZOOM_MIN := 1.6
const SPECIES_ZOOM_MAX := 5.0
## ⚠ **The creature is staged FURTHER than contact, and the reason is the lunge.** At the distance
## `World._contact()` actually fires at — the two radii touching — `Look.SPECIES_LUNGE_MUL` carries the lion
## 42px forward and the elephant 28, which is the whole gap: the first version of this sequence photographed a
## 사자 standing inside the host and a 보스 with the host inside IT, and a frame where two bodies are one blob
## cannot answer 「종마다 다르게 때린다」. The lunge distance is added back so the gesture is drawn in open
## ground, and this margin is on top of it.
const SPECIES_GAP_MARGIN := 40.0
## Roughly how far past its own radius a gesture reaches, as a multiple of it. `Look.SWING_STOMP_RING` is the
## largest at 2.2 and this is the framing allowance, not a claim about any one gesture.
const SPECIES_GESTURE_REACH := 2.4
## Where in the swing window the frame is taken. `Look.SWING_LUNGE_TIME` and `Look.CRITTER_SWING_TIME` are the
## same number, and the lunge curve peaks at the halfway point — so one value puts every gesture and the body's
## own lunge at their fullest at once.
const SPECIES_SWING_T := 0.5

## How far from every pond and every rock a staged spot has to be, and the grid the field is scanned on.
## **Scanned, never a literal** — the ground comes from `SEED` and a coordinate written here quietly stops
## being open the day that number moves, with the run still producing plausible frames.
const OPEN_STEP := 120.0
const OPEN_INSET := 700.0

var _dir := ""
var _main: Node = null
var _spent := 0
var _drawn := false
## Written by `_ramp()`, read by `_ramp_shot()` — how many play-scale fight frames have been lifted so far.
var _play_fight := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		printerr("[찍기] 인자가 모자란다: <출력 폴더>")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("[찍기] --headless 로는 못 찍는다 — 스왑체인이 없어 텍스처가 빈 채로 돌아온다")
		quit(1)
		return
	_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	print("[찍기] 씨앗 %d · 몸 갈래 %d -> %s" % [SEED, Look.BODY_STYLE, _dir])
	if not await _boot():
		return
	await _opening()
	await _ramp()
	await _fight()
	await _species()
	root.remove_child(_main)
	_main.queue_free()
	quit(0)


## The shell, the real click on 시작하기, and the instrument's own frame. **Returns false when nothing after it
## would be evidence.**
func _boot() -> bool:
	var main: Node = load("res://src/shell/main.gd").new()
	root.add_child(main)
	_main = main
	# Four, not two: the title lays itself out from `size`, which a full-rect preset only fills in on the next
	# layout pass, and the click below is aimed at a rectangle computed from it.
	await _frames(4)
	var at: Vector2 = root.get_screen_transform() * main.title._rect_of(0).get_center()
	root.push_input(_click(at, true))
	root.push_input(_click(at, false))
	await _frames(4)
	if main.run.phase != Run.Phase.PLAY:
		printerr("[찍기] 시작하기 버튼을 못 눌렀다 — 좌표 %s 가 버튼 밖이다" % str(at))
		quit(1)
		return false
	# The shell's own `_process` is the one caller of `run.step()`, and every sequence here decides its own
	# stepping. `_unhandled_key_input` goes with it: `Tab` arriving from the user's own keyboard would open the
	# body panel over a shot.
	main.set_process(false)
	main.set_process_unhandled_key_input(false)
	# **Both views come off the engine's clock too.** They consume one-frame lists that `World.begin_frame()`
	# clears, so on the engine's own clock they append the same death burst once per RENDERED frame — and one
	# shot costs several of those. `_tick()` calls them by hand with the simulation's dt instead.
	main.view.set_process(false)
	main.hud.set_process(false)

	# **The instrument's own frame, and it is first.** If it fails nothing after it is evidence, so nothing
	# after it is taken.
	if not await _known_answer():
		printerr("[찍기] 기준 컷이 틀렸다. 나머지는 안 찍는다 — 계기가 거짓말하면 사진은 답이 아니다.")
		quit(1)
		return false
	return true


# -- the instrument's own frame ---------------------------------------------------------------------------
## One 사자 at `Rules.SPECIES_FORCE_MIN`, alone, at the camera's centre, at a zoom this file chose. Every
## number in the answer is known before the shutter: `World._radius_of()` returns exactly `Rules.SPECIES_RADIUS`
## at the minimum force, so the body is 26px in the world and `2 × 26 × zoom × scale` px on the frame.
##
## Two failures are otherwise invisible and either would make every other shot look like a real answer: a body
## photographed at play scale because `_apply_zoom()` undid a camera set from outside, and a body that is not
## where the camera was pointed because `_cam_base` was never written.
func _known_answer() -> bool:
	_fresh(Rules.FIELD * 0.5)
	var w: World = _main.run.world
	w.critter_count = 0
	w.boss_index = -1
	var spot: Vector2 = Rules.FIELD * 0.5 + KNOWN_AT
	var k := _critter(Parts.Species.LION, spot)
	# Facing east, written rather than rolled. `World._write_critter()` gives every creature a random unit
	# direction and `_paint_critter` turns it into a rotation — and a rotated square's bounding box is up to
	# √2 wider than the body. The one shot whose answer is known in advance may not depend on a die roll.
	w.critter_dir[k] = Vector2.RIGHT
	_look(KNOWN_ZOOM, w.critter_pos[k])

	var img := await _grab()
	var content: Vector2 = _main.get_viewport_rect().size
	# **Derived from the frame that came back, never from `project.godot`.** The window is a stretch of the
	# 1280×720 viewport and the OS may hand back neither size; `_camera_rect()` divides by exactly this
	# `content`, so the two agree by construction whatever the window turned out to be.
	var scale := float(img.get_width()) / content.x
	var want := 2.0 * float(Rules.SPECIES_RADIUS[Parts.Species.LION]) * KNOWN_ZOOM * scale
	var box := _box_of(img, Look.LION_COLOR, KNOWN_WINDOW)
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	print("[기준] 프레임 %dx%d · 내용 %s · 배율 %.3f · 기대 폭 %.1fpx" % [
			img.get_width(), img.get_height(), str(content), scale, want])
	print("[기준] 사자 상자 %s" % str(box))

	var ok := true
	if box.size.x <= 0:
		printerr("[기준] 사자 색 픽셀이 한 개도 없다 — %s" % ("프레임이 통째로 한 색이다, 텍스처가 빈 채로 왔다" \
				if _uniform(img) else "카메라가 딴 데를 보고 있다"))
		ok = false
	else:
		if absf(float(box.size.x) - want) > want * KNOWN_TOLERANCE:
			printerr("[기준] 폭이 %d px 다. %.1f ± %.0f%% 여야 한다 — 줌이 되돌려졌다" % [
					box.size.x, want, KNOWN_TOLERANCE * 100.0])
			ok = false
		if absf(float(box.size.y) - want) > want * KNOWN_TOLERANCE:
			printerr("[기준] 높이가 %d px 다. %.1f ± %.0f%% 여야 한다" % [
					box.size.y, want, KNOWN_TOLERANCE * 100.0])
			ok = false
		var got := Vector2(box.position) + Vector2(box.size) * 0.5
		if got.distance_to(centre) > 10.0:
			printerr("[기준] 몸의 한가운데가 %s 인데 화면 한가운데는 %s 다 — 카메라 자리가 틀렸다" % [
					str(got), str(centre)])
			ok = false
	_save(img, "00_known_answer")
	return ok


# -- 1. the opening ---------------------------------------------------------------------------------------
## **t = 0, nothing stepped, the shell's own camera.** This is the frame the whole complaint is about, so
## nothing is staged into it and nothing is stepped out of it: `restart(SEED)` builds the field the game builds
## and the shutter opens on it.
##
## Two frames, and the second is not a duplicate: the first is what a player sees (`Look.ZOOM_NEAR`, which
## `_bind_world()` snaps to on every restart), the second pulls back far enough to show where the nearest
## creatures actually are — 「무엇을 향해 걸어가면 되는가」 is a question about ground the play camera cannot
## show at once.
func _opening() -> void:
	_fresh(Rules.FIELD * 0.5)
	_census("여는 화면")
	_shell_camera()
	await _shot("1_opening/00_t0_play_zoom")
	_look(0.35, _main.run.world.swarm.pos[0])
	await _shot("1_opening/01_t0_wide")


# -- 2. the ramp ------------------------------------------------------------------------------------------
## One run, from the same seed, played by `_policy()`, with the shutter opening at 0·30·60·90·120 seconds and
## again at `Rules.BOSS_HUNT_AT`. **Every frame is at play zoom and driven by the shell's own three camera
## writers**, because the ramp is a claim about what a player has on screen and a camera this file invented
## would answer about a camera the game does not have.
##
## After the hunt starts the hand stops walking at things and stands. That is written down rather than hidden:
## `Rules.SPECIES_SPEED_MUL[BOSS]` is under `HOST_SPEED` — the table says so itself — so a hand that keeps
## chasing the next crow is never caught, and a photograph of the boss arriving would never be taken. What the
## frames after 150초 show is therefore **a player who stopped**, not a player who was run down.
func _ramp() -> void:
	_fresh(Rules.FIELD * 0.5)
	var w: World = _main.run.world
	_shell_camera()
	var next := 0
	var cap := int((Rules.BOSS_HUNT_AT + BOSS_WAIT) / STEP_DT)
	var frames := 0
	var shot_hunt := false
	var shot_arrive := false
	var shot_arena := false
	while _main.run.phase == Run.Phase.PLAY and frames < cap:
		if next < RAMP_AT.size() and w.elapsed >= float(RAMP_AT[next]):
			await _ramp_shot("2_ramp/%02d_%03ds" % [next, int(RAMP_AT[next])])
			next += 1
			continue
		if not shot_hunt and w.boss_hunting():
			shot_hunt = true
			await _ramp_shot("2_ramp/05_%03ds_boss_hunt_starts" % int(Rules.BOSS_HUNT_AT))
			continue
		if shot_hunt and not shot_arrive and _boss_on_screen():
			shot_arrive = true
			await _ramp_shot("2_ramp/06_boss_on_screen")
			continue
		if not shot_arena and w.terrain.arena_closed:
			shot_arena = true
			await _ramp_shot("2_ramp/07_arena_closed")
			continue
		# The hand stops once the hunt is on — see this function's own note on why that is the only way the
		# boss is ever in a frame.
		_tick(not w.boss_hunting())
		frames += 1
		if _swinging() and w.elapsed >= PLAY_FIGHT_AFTER and _play_fight < PLAY_FIGHT_SHOTS:
			var n := _play_fight
			_play_fight += 1
			await _ramp_shot("3_fight/play_zoom/%02d_%03ds" % [n, int(w.elapsed)])
		if frames % YIELD_EVERY == 0:
			await process_frame
	if _main.run.phase != Run.Phase.PLAY:
		print("[찍기] 램프: %.0f초에 런이 끝났다 (%s) — 그 뒤 컷은 없다" % [
				w.elapsed, "죽었다" if _main.run.outcome == Run.Outcome.DIED else "끝났다"])
	if not shot_arrive:
		print("[찍기] 램프: 보스는 %.0f초까지 화면에 안 들어왔다 — 도착 컷 없음" % w.elapsed)
	if not shot_arena:
		print("[찍기] 램프: 투기장은 %.0f초까지 안 닫혔다 — 투기장 컷 없음" % w.elapsed)


## One ramp frame: the camera the shell would have, the census beside it, the shutter.
func _ramp_shot(name: String) -> void:
	_shell_camera()
	_census(name)
	await _shot(name)


# -- 3. the fight -----------------------------------------------------------------------------------------
## The host and eight clones killing a 멧돼지, shot close enough that a gesture is legible. **멧돼지 because it
## is the smallest thing on the field that hits back**: `Rules.SPECIES_FLEES` is 0 for it, so it swings, and
## `Rules.SPECIES_HUNTS` is 0, so it is not a creature that walked at you — both halves of a fight are in
## frame. A fleeing species would produce a sequence of the swarm hitting something that never answers.
##
## The eight clones are made by **holding and releasing `F`**, three times: `Swarm.split_hold()` and
## `split_release()` are the two calls that key makes, so the swarm in the picture is a swarm the game
## produces rather than eight rows written by this file.
##
## **No `host_grace`.** The crowd tool suppresses it because its subject is separation and a knockback is a
## second force moving the picture; here the boar hitting back IS the subject, so the hit, the flash, the
## knockback and the shell's own shake all stay in.
func _fight() -> void:
	var spot := _open_ground()
	_fresh(spot)
	var w: World = _main.run.world
	var sw: Swarm = w.swarm
	w.critter_count = 0
	w.boss_index = -1
	sw.force[0] = FIGHT_FORCE
	for _n in FIGHT_SPLITS:
		sw.split_hold(Rules.SPLIT_HOLD_TIME)
		sw.split_release()
	var target := spot + Vector2(240.0, 0.0)
	var k := _critter(Parts.Species.BOAR, target)
	w.critter_dir[k] = Vector2.LEFT
	sw.command_strike(w.critter_pos[k])
	print("[싸움] 몸 %d · 힘 %s · 멧돼지 hp %d" % [sw.count, str(_forces(sw)), w.critter_hp[k]])

	var dead_at := -1
	for n in FIGHT_SHOTS:
		if n > 0:
			for _i in FIGHT_EVERY:
				_tick(true)
		var alive := k < w.critter_count and int(w.critter_species[k]) == Parts.Species.BOAR
		if not alive and dead_at < 0:
			dead_at = n
		var mid := sw.pos[0]
		if alive:
			mid = (sw.pos[0] + w.critter_pos[k]) * 0.5
		_look(FIGHT_ZOOM, mid)
		print("[싸움] %02d · 멧돼지 %s · 호스트 hp %d/%d · 시체 %d · 휘두르는 몸 %d" % [
				n, ("hp %d" % w.critter_hp[k]) if alive else "죽었다", w.host_hp,
				w.body.hp_max(w.level), w.corpse_count, _swingers(sw)])
		await _shot("3_fight/%02d" % n)
		if dead_at >= 0 and n - dead_at >= FIGHT_TAIL:
			break
	if dead_at < 0:
		print("[싸움] %d컷 안에 멧돼지가 안 죽었다" % FIGHT_SHOTS)


# -- 4. one frame per species -----------------------------------------------------------------------------
## **Every species that can attack, mid-swing, one frame each.** `Rules.SPECIES_FLEES` is what decides the
## list: a fleeing creature never attacks anything ever — `World._contact()`'s second pass returns on that
## column before it looks at a distance — so 말·다람쥐·치타·토끼 have no attack to photograph and staging one
## would be a picture of something the game cannot do. They get one frame together instead, standing, named for
## what they are.
##
## The swing is written the way `World._contact()` writes it (`critter_swing_show` and `critter_swing_dir`) and
## then nothing is stepped, so the frame is exactly `SPECIES_SWING_T` through the window.
func _species() -> void:
	# **The file name is romanised and the console line is not.** Korean is what the user reads, and it is in
	# every `print` here; a folder of Korean file names is a folder the user's own shell has to quote.
	var order := [[Parts.Species.MOUSE, "mouse"], [Parts.Species.CROW, "crow"],
			[Parts.Species.DOG, "dog"], [Parts.Species.BOAR, "boar"], [Parts.Species.LION, "lion"],
			[Parts.Species.ELEPHANT, "elephant"], [Parts.Species.BOSS, "boss"]]
	var spot := _open_ground()
	var n := 0
	for row in order:
		var s := int(row[0])
		if int(Rules.SPECIES_FLEES[s]) == 1:
			# Refused rather than skipped quietly: a species that gained a gesture and a flee flag at once
			# would otherwise vanish from this sequence with nothing saying so.
			printerr("[종] %s 는 도망가는 종이라 공격을 못 한다 — 이 목록에 있으면 안 된다" % Parts.SPECIES_NAME[s])
			continue
		_fresh(spot)
		var w: World = _main.run.world
		var sw: Swarm = w.swarm
		w.critter_count = 0
		w.boss_index = -1
		var r := float(Rules.SPECIES_RADIUS[s])
		# Contact distance plus this species' own lunge plus a margin — see `SPECIES_GAP_MARGIN`.
		var gap := r + Rules.BODY_RADIUS \
				+ Look.SWING_LUNGE_PUSH * float(Look.SPECIES_LUNGE_MUL[s]) \
				+ maxf(SPECIES_GAP_MARGIN, r)
		var k := _critter(s, spot + Vector2(gap, 0.0))
		var aim: Vector2 = (sw.pos[0] - w.critter_pos[k]).normalized()
		w.critter_dir[k] = aim
		w.critter_swing_dir[k] = aim
		w.critter_swing_show[k] = Look.CRITTER_SWING_TIME * SPECIES_SWING_T
		var extent := gap * 0.5 + r * SPECIES_GESTURE_REACH
		var zoom := clampf(SPECIES_FIT / extent, SPECIES_ZOOM_MIN, SPECIES_ZOOM_MAX)
		_look(zoom, (sw.pos[0] + w.critter_pos[k]) * 0.5)
		print("[종] %s · 반지름 %.0f · 힘 %d · 사이 %.0fpx · 줌 %.2f" % [
				Parts.SPECIES_NAME[s], r, w.critter_force[k], gap, zoom])
		await _shot("4_species/%02d_%s_attack" % [n, String(row[1])])
		n += 1

	# The four that never attack, standing together, so the claim「종마다 다르게 때린다」can be read against the
	# four it does not cover.
	_fresh(spot)
	var w2: World = _main.run.world
	w2.critter_count = 0
	w2.boss_index = -1
	# **A wide ellipse, not a circle, and it is a measurement.** On a 190px ring at zoom 2.4 the two bodies at
	# the top and bottom of the ring landed off the frame — the viewport is 16:9 and the ring was not — so the
	# shot named "the four that never attack" held two of them. The x radius is the one that has room.
	var flee := [Parts.Species.HORSE, Parts.Species.SQUIRREL, Parts.Species.CHEETAH, Parts.Species.RABBIT]
	for i in flee.size():
		var a := TAU * float(i) / float(flee.size())
		_critter(int(flee[i]), spot + Vector2(cos(a) * 300.0, sin(a) * 150.0))
	_look(1.8, spot)
	await _shot("4_species/%02d_fleeing_four_never_attack" % n)


# -- the machinery ----------------------------------------------------------------------------------------
## A clean world from the literal seed, with the host at `centre`. `restart()` builds a new `World` and
## `_bind_world()` is what re-points the two views at it — leaving it out is the stale-reference shape the
## shell names at that function, and it is also what snaps the camera back to `Look.ZOOM_NEAR`.
func _fresh(centre: Vector2) -> void:
	_main.run.restart(SEED)
	_main._bind_world()
	var w: World = _main.run.world
	w.swarm.pos[0] = w.swarm.place(centre, Rules.BODY_RADIUS)
	w.swarm.vel[0] = Vector2.ZERO
	# The camera follows the host and `_bind_world()` seeded it at the host's ORIGINAL spot, so moving the host
	# afterwards leaves the camera a field away with nothing saying so.
	_main._cam_base = w.swarm.pos[0]
	_main._zoom = Look.ZOOM_NEAR
	_shell_camera()


## ONE simulation frame, in the shell's own order and out of the shell's own calls.
##
## ⚠ **`main._read_input()` is deliberately not called.** It polls the real `Input` singleton, and a window
## holding focus while a person types would put their hands in the picture. Everything it writes into `sim` is
## written by `_policy()` instead, through the same two entry points a key reaches.
func _tick(play: bool) -> void:
	var w: World = _main.run.world
	_main.run.begin_frame()
	# The shell's `_sync_cards()` puts an offer on screen and the player clicks it; `_on_card_picked` is the far
	# side of that click. **Before `step()`**, because `World.step()` refuses to advance while an offer stands —
	# the run would freeze here forever.
	if w.pending_levels > 0 and not w.offer.is_empty():
		_main._on_card_picked(w.offer[0])
	if play:
		_policy(w)
	else:
		w.swarm.host_input = Vector2.ZERO
	_main.run.paused = false
	_main.run.step(STEP_DT)
	if _main.run.phase == Run.Phase.PLAY:
		_shell_camera()
	# **The two views are stepped by hand with the SIMULATION's dt**, for the reason `_boot()` gives where it
	# switches their `_process` off.
	_main.view._process(STEP_DT)
	_main.hud._process(STEP_DT)


## The whole hand. Three rules, in this order, and nothing else — see this file's header on why it is the same
## shape as `probe_run`'s and why it is still not a verdict.
func _policy(w: World) -> void:
	var host: Vector2 = w.swarm.pos[0]
	# 1 — back away from anything one touch of which would take the host out. Driven through `World`'s own
	# `_capped_hit()` rather than compared against raw force: raw force is not what arrives.
	var away := Vector2.ZERO
	for k in w.critter_count:
		if _one_touch(w, k) < w.host_hp:
			continue
		var d := host.distance_to(w.critter_pos[k])
		if d > 300.0:
			continue
		var v: Vector2 = host - w.critter_pos[k]
		if v.length_squared() > 0.0001:
			away += v.normalized() / maxf(1.0, d)
	if away.length_squared() > 0.000001:
		w.swarm.host_input = away.normalized()
		return
	# 2 — stand on a corpse in reach. `World._step_corpses()` advances a meal on proximity alone.
	for i in w.corpse_count:
		if host.distance_to(w.corpse_pos[i]) <= w.corpse_reach(i, true):
			w.swarm.host_input = Vector2.ZERO
			return
	# 3 — walk at the nearest thing worth fighting and bite it inside 물기's own reach.
	var target := _nearest_takeable(w)
	if target < 0:
		w.swarm.host_input = Vector2.ZERO
		return
	var to: Vector2 = w.critter_pos[target] - host
	# **Computed before the strike and used after it.** `fire()` can kill, and `_remove_critter()` swaps a
	# stranger into row `target` on that same call.
	var aim: Vector2 = w.critter_pos[target]
	if to.length() <= float(Parts.RANGE[Parts.BITE]) + w.critter_radius(target):
		w.fire(BITE_KEY, aim)
	w.swarm.host_input = to.normalized() if to.length_squared() > 0.0001 else Vector2.ZERO


func _one_touch(w: World, k: int) -> int:
	# A fleeing creature never attacks anything, ever — `World._contact()`'s second pass returns on this column
	# before it looks at a distance.
	if int(w.critter_flees[k]) == 1:
		return 0
	return w._capped_hit(int(w.critter_force[k]), w.body.hp_max(w.level))


## Nearest creature a lone host can actually take, or -1. Faster-than-the-host species are refused: 말 and 치타
## are herded with the swarm and never chased, and this hand has no swarm.
func _nearest_takeable(w: World) -> int:
	var best := -1
	var best_d := INF
	var host: Vector2 = w.swarm.pos[0]
	for k in w.critter_count:
		if _one_touch(w, k) >= w.host_hp:
			continue
		if float(Rules.SPECIES_SPEED_MUL[int(w.critter_species[k])]) > 1.0:
			continue
		var d := host.distance_to(w.critter_pos[k])
		if d < best_d:
			best_d = d
			best = k
	return best


## Is anything in the swarm mid-swing, or the host's own bite cone up. What a "fight" frame is picked on.
func _swinging() -> bool:
	var sw: Swarm = _main.run.world.swarm
	if sw.bite_show < Look.BITE_SHOW_TIME:
		return true
	return _swingers(sw) > 0


func _swingers(sw: Swarm) -> int:
	var n := 0
	for i in sw.count:
		if sw.swing_show[i] < Look.SWING_LUNGE_TIME:
			n += 1
	return n


func _forces(sw: Swarm) -> Array:
	var out := []
	for i in sw.count:
		out.append(sw.force[i])
	return out


## Is the boss inside what the camera actually shows.
func _boss_on_screen() -> bool:
	var w: World = _main.run.world
	if w.boss_index < 0:
		return false
	return _main._true_camera_rect().has_point(w.critter_pos[w.boss_index])


## What stood in the world when the shutter opened: everything on screen by species, and where the nearest
## creature of any kind is. **The console is the measurement and the PNG is the picture** — a number burned
## into the frame would be a second drawing path.
func _census(label: String) -> void:
	var w: World = _main.run.world
	var box: Rect2 = _main._true_camera_rect()
	var host: Vector2 = w.swarm.pos[0]
	var on := []
	on.resize(Parts.SPECIES_NAME.size())
	on.fill(0)
	var near := INF
	var near_s := -1
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		if box.has_point(w.critter_pos[k]):
			on[s] = int(on[s]) + 1
		var d := host.distance_to(w.critter_pos[k])
		if d < near:
			near = d
			near_s = s
	var parts := []
	var total := 0
	for s in on.size():
		if int(on[s]) > 0:
			parts.append("%s %d" % [Parts.SPECIES_NAME[s], int(on[s])])
			total += int(on[s])
	print("[현황] %s · %.0f초 · 화면 %.0fx%.0f월드px · 화면 안 %d마리 (%s) · 필드 %d마리 · 제일 가까운 것 %s %.0fpx · 호스트 hp %d/%d 힘 %d 몸 %d" % [
			label, w.elapsed, box.size.x, box.size.y, total,
			", ".join(PackedStringArray(parts)) if total > 0 else "없음",
			w.critter_count, Parts.SPECIES_NAME[near_s] if near_s >= 0 else "-", near,
			w.host_hp, w.body.hp_max(w.level), w.swarm.force[0], w.swarm.count])


## The most open point in the middle of this seeded field — furthest from every pond and every rock. Scanned,
## never a literal, for the reason the constants above give.
func _open_ground() -> Vector2:
	var g: Terrain = _main.run.world.terrain
	var out: Vector2 = Rules.FIELD * 0.5
	var best := -INF
	var x := OPEN_INSET
	while x < Rules.FIELD.x - OPEN_INSET:
		var y := OPEN_INSET
		while y < Rules.FIELD.y - OPEN_INSET:
			var p := Vector2(x, y)
			var worst := INF
			for j in g.water_pos.size():
				worst = minf(worst, p.distance_to(g.water_pos[j]) - g.water_radius[j])
			for j in g.rock_pos.size():
				worst = minf(worst, p.distance_to(g.rock_pos[j]) - g.rock_radius[j])
			if worst > best:
				best = worst
				out = p
			y += OPEN_STEP
		x += OPEN_STEP
	print("[찍기] 빈 땅 %s, 제일 가까운 지형까지 %.0fpx" % [str(out), best])
	return out


## One creature, **always at its species' minimum force**, so `World._radius_of()`'s ramp is exactly zero and
## the drawn radius is exactly the `Rules.SPECIES_RADIUS` row.
func _critter(species: int, at: Vector2) -> int:
	var w: World = _main.run.world
	var force_v := int(Rules.SPECIES_FORCE_MIN[species])
	var k := w._write_critter(species, w.terrain.push_out(at, float(Rules.SPECIES_RADIUS[species])), force_v)
	if species == Parts.Species.BOSS:
		# `boss_index` is a real column with a real reader — the minimap's own dot.
		w.boss_index = k
	return k


# -- the camera -------------------------------------------------------------------------------------------
## The shell's own three camera writers, in the shell's own order. Driving the real functions rather than
## copying them is what keeps `00_known_answer` able to catch a camera that was undone.
func _shell_camera() -> void:
	var main := _main
	main._follow_camera(STEP_DT)
	main._apply_shake()
	main._apply_zoom(STEP_DT)
	main.view.view_rect = main._camera_rect()
	main.hud.camera_rect = main._true_camera_rect()


## A camera this file chooses, for the staged sequences. **Setting `cam.zoom` from outside is exactly the trap
## `tools/look/README.md` exists for**: in PLAY `_apply_zoom()` rewrites it from the shell's own field and
## `_apply_shake()` ASSIGNS `cam.position` from `_cam_base`, so the two fields behind the camera are what is
## written here and the shell's own functions are what apply them.
func _look(z: float, at: Vector2) -> void:
	var main := _main
	main._cam_base = at
	main._zoom = z
	# Zero delta: `_apply_zoom`'s weight is `1 - exp(0)`, so `_zoom` is not lerped toward the swarm-size target
	# and `cam.zoom` comes out at exactly what was asked for.
	main._apply_zoom(0.0)
	main._apply_shake()
	main.view.view_rect = main._camera_rect()
	main.hud.camera_rect = main._true_camera_rect()


# -- frames, files and pixels -----------------------------------------------------------------------------
func _shot(name: String) -> void:
	_save(await _grab(), name)


## `RenderingServer.frame_post_draw` is the whole trick — `root.get_texture()` read at any other moment hands
## back the PREVIOUS frame, which in this tool is the previous SECOND of a ramp.
func _grab() -> Image:
	# **Asked for explicitly rather than relied on.** Both views are off the engine's clock, so the
	# `queue_redraw()` at the end of their own `_process` is the only one there is — and a shot taken after
	# staging that stepped nothing at all would otherwise photograph the previous scene.
	if _main != null:
		_main.view.queue_redraw()
		_main.hud.queue_redraw()
	await _frames(2)
	_drawn = false
	RenderingServer.frame_post_draw.connect(_on_drawn, CONNECT_ONE_SHOT)
	while not _drawn and _spent <= FRAME_BUDGET:
		await _frames(1)
	return root.get_texture().get_image()


func _on_drawn() -> void:
	_drawn = true


func _save(img: Image, name: String) -> void:
	var path := _dir.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("[찍기] %s %s" % [path, "ok" if err == OK else "실패 %d" % err])


## The bounding box of every pixel matching one colour, over a centred window. A window rather than the frame:
## `Image.get_pixel` in GDScript over two million pixels costs seconds, and the one body this is ever asked
## about stands at the camera's own centre.
func _box_of(img: Image, col: Color, window: int) -> Rect2i:
	var x0 := maxi(0, img.get_width() / 2 - window / 2)
	var x1 := mini(img.get_width(), img.get_width() / 2 + window / 2)
	var y0 := maxi(0, img.get_height() / 2 - window / 2)
	var y1 := mini(img.get_height(), img.get_height() / 2 + window / 2)
	var lo := Vector2i(x1, y1)
	var hi := Vector2i(x0 - 1, y0 - 1)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var p := img.get_pixel(x, y)
			if absf(p.r - col.r) > COLOR_EPS:
				continue
			if absf(p.g - col.g) > COLOR_EPS or absf(p.b - col.b) > COLOR_EPS:
				continue
			lo.x = mini(lo.x, x)
			lo.y = mini(lo.y, y)
			hi.x = maxi(hi.x, x)
			hi.y = maxi(hi.y, y)
	if hi.x < lo.x:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Is the whole frame one colour — the difference between a blank texture and a camera pointed at nothing. It
## decides a MESSAGE, never a verdict.
func _uniform(img: Image) -> bool:
	var first := img.get_pixel(0, 0)
	for y in range(0, img.get_height(), 13):
		for x in range(0, img.get_width(), 13):
			if not img.get_pixel(x, y).is_equal_approx(first):
				return false
	return true


## Real frames, counted against a budget. **Nothing here may wait for a person**, and a frame source that
## stopped emitting would otherwise hold the user's screen for as long as the process lived.
func _frames(n: int) -> void:
	for _i in n:
		_spent += 1
		if _spent > FRAME_BUDGET:
			printerr("[찍기] 프레임 예산 %d 를 넘겼다 — 멈춘 채로 기다리지 않는다" % FRAME_BUDGET)
			quit(1)
			return
		await process_frame


func _click(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	return e
