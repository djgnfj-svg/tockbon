extends SceneTree
## The crowd, photographed once per body candidate. **A second capture tool, not an edit to the first** —
## `capture.gd`'s seven shots are a bare host, a worn body, a close-up of it, the internal slots, the `Tab`
## panel, a card pick and the ending, and **not one of them is a crowd**. The crowd is the entire subject of
## `melee-legibility-ko`'s fork, and those seven still have to keep answering plan 3's questions, so this
## file joins that one rather than changing it.
##
## Usage (from the repo root, and the `--` matters):
##   .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/capture_bodies.gd -- <dir> <style> [mode]
##
## `[mode]` is `scenes` (the default, the nine staged stills below) or **`push`, which is a different kind of
## picture entirely**: five FRAME SEQUENCES of the separation pass, several consecutive simulation frames
## each. A push happens over time and a still cannot hold one — a body already standing at the surface of a
## creature and a body that was never inside it produce the identical frame, so a single shot of the fix
## answers nothing about it. The two modes share every staging helper in this file and differ in exactly one
## thing: `scenes` writes a world and photographs it without advancing, `push` advances it and photographs
## every few frames. See `_push()`.
##
## `<style>` is `fill` · `line` · `rim`, the three members of `Look.BodyStyle`. **One style per process**, and
## that is not a limitation: the switch is a process-global `static var`, and one folder per process is what
## makes "the pair differs only in the drawing path" checkable from outside by hashing the two files.
## `<dir>/<style>/<name>.png` is where a frame lands, so `fill/03_host_in_pile.png` pairs with
## `line/03_host_in_pile.png` with nothing to look up.
##
## ⚠ Read `tools/look/README.md` before changing anything here. Its three rules bind this file too, and each
## one fails silently:
##  · **never `--headless`** — no swapchain, `root.get_texture()` comes back blank, every PNG is a black
##    rectangle and no error is raised anywhere. `00_known_answer` below is what turns that into a red.
##  · **never the user's mouse or keyboard.** The one input this tool has is a left click on the title's own
##    시작하기 button and it goes through `root.push_input()`, inside the engine. Nothing reaches the OS.
##  · **`RenderingServer.frame_post_draw` before every read**, or `get_texture()` hands back the PREVIOUS
##    frame — which here would be the previous SCENE, and the run would produce correctly named,
##    silently-swapped pictures.
##
## **Nothing in it ever waits for a person**, and every wait is counted against `FRAME_BUDGET` rather than a
## clock, so a stalled frame source ends the run instead of holding the user's screen.

const SEED := 20260816
## The layout die, re-seeded at the top of every scene. **Local to this file**, so where a body stands
## depends on nothing outside it and two runs of two styles lay the same crowd down.
const LAYOUT_SEED := 7311
const FRAME_BUDGET := 3000

## What every clone in every scene is worth. A number rather than a roll: it is printed under the swarm by
## `FieldView._force_labels`, and a label that moved between two halves of a pair would be a second axis.
const CLONE_FORCE := 2
## How many bodies are mid-swing in `06_mid_strike`.
const STRIKE_CLONES := 8

## `00_known_answer`'s zoom, and the whole shot is built around it being a number the answer can be computed
## from before the shutter. See `_known_answer()`.
const KNOWN_ZOOM := 4.0
## And **away from the host's own start point**, which is where `main._bind_world()` leaves `_cam_base`. Shot
## on top of it, the camera-position half of `_look()` proves nothing: deleting `_cam_base = at` outright
## still lands the picture in the right place, because the stale value happens to be the right one. Measured —
## that is exactly what the first version of this shot did.
const KNOWN_AT := Vector2(700.0, 420.0)
## How far the measured body may sit from the computed one. It has to be loose enough to hold all three
## candidates — a filled body's silhouette is its radius, 갈래 ㄱ's stroke straddles it and reads ~7% wider,
## 갈래 ㄴ's dark rim eats the outermost pixels and reads ~8% narrower — and tight enough that a camera left
## at play scale (1.6 against 4.0) is nowhere near it.
const KNOWN_TOLERANCE := 0.15
## Colour match for the same measurement. The bodies are flat-filled polygons and unantialiased polylines, so
## an interior pixel is exact; this is slack for the 8-bit round trip, not for blending.
const COLOR_EPS := 0.02
## The measurement window, centred. `Image.get_pixel` in GDScript over two million pixels costs seconds, and
## the one body this is ever asked about is the one standing at the camera's own centre.
const KNOWN_WINDOW := 800

## How far from every edge of `Rules.FIELD` the terrain shot's centre has to sit. The closest pond↔rock pair
## in this seed is 22px apart and 184px from the north edge, and a camera there fills the top of the frame
## with off-field background — which answers nothing about a body over ground. The inset is one screen's
## half-height at that shot's zoom, so the whole frame is field.
const TERRAIN_INSET := 500.0

## The dt every stepped frame is handed — the simulation's and both views'. **A literal, never the real frame
## delta**: one shot costs several rendered frames while the sim is meant to have advanced by one, so a run
## driven off `process_frame`'s own delta would photograph a sequence whose spacing is the machine's load.
## 1/60 is the rate every duration in `Rules` and `Look` was tuned at.
const STEP_DT := 1.0 / 60.0

## The herding sequence's corridor: how long it has to be clear for, how far in from the field's edge it may
## start, and the two scan resolutions `_clear_run()` walks it at. `CORRIDOR` covers the host's own walk as
## well as the horse's, so nothing in the picture crosses a pond or a rock.
const CORRIDOR := 760.0
## How many clones the herding arc holds.
const WALL_CLONES := 26
const CORRIDOR_INSET := 400.0
const CORRIDOR_STEP := 160.0
const CORRIDOR_SAMPLE := 40.0

var _dir := ""
var _style_name := ""
var _mode := "scenes"
var _main: Node = null
var _rng := RandomNumberGenerator.new()
var _home := Rules.FIELD * 0.5
var _spent := 0
## Set by `_on_drawn()`; see `_grab()` for why the post-draw wait is polled rather than awaited bare.
var _drawn := false
## The creature `06_mid_strike` stages a hit on. Written by `_crowd()`, read by `_strike()`.
var _lion := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("[찍기] 인자가 모자란다: <출력 폴더> <fill|line|rim> [scenes|push]")
		quit(1)
		return
	# **Refused, not documented.** `tools/look/README.md` names `--headless` as the trap that produces a
	# folder of black rectangles with no error anywhere — and measured here, it is worse than that: the dummy
	# renderer never emits `RenderingServer.frame_post_draw`, so the first shot waits for a draw that will
	# never come and the run hangs instead of finishing. The one rule this folder cannot merely write down.
	if DisplayServer.get_name() == "headless":
		printerr("[찍기] --headless 로는 못 찍는다 — 스왑체인이 없어 텍스처가 빈 채로 돌아온다")
		quit(1)
		return
	_dir = args[0]
	_style_name = String(args[1]).to_lower()
	var table := {"fill": Look.BodyStyle.FILL, "line": Look.BodyStyle.LINE, "rim": Look.BodyStyle.RIM}
	if not table.has(_style_name):
		printerr("[찍기] 모르는 갈래: %s (fill·line·rim 중 하나)" % _style_name)
		quit(1)
		return
	if args.size() >= 3:
		_mode = String(args[2]).to_lower()
	if _mode != "scenes" and _mode != "push":
		printerr("[찍기] 모르는 모드: %s (scenes·push 중 하나)" % _mode)
		quit(1)
		return
	# **Set before a single frame is drawn.** `FieldView` reads it inside `_paint_cell` on every body, so a
	# flip made after the first shot would leave one PNG in the previous candidate with nothing saying so.
	Look.BODY_STYLE = int(table[_style_name])
	DirAccess.make_dir_recursive_absolute(_dir.path_join(_style_name))
	print("[찍기] 갈래 %s · 모드 %s -> %s" % [_style_name, _mode, _dir.path_join(_style_name)])
	if not await _boot():
		return
	if _mode == "push":
		await _push()
	else:
		await _scenes()
	root.remove_child(_main)
	_main.queue_free()
	quit(0)


## Everything both modes need before a single picture: the shell, the real click on 시작하기, a seeded field,
## the freeze, and the instrument's own frame. **Returns false when nothing after it would be evidence.**
func _boot() -> bool:
	var main: Node = load("res://src/shell/main.gd").new()
	root.add_child(main)
	_main = main
	# Four, not two: the title lays itself out from `size`, which a full-rect preset only fills in on the
	# next layout pass, and the click below is aimed at a rectangle computed from it.
	await _frames(4)

	# **The real path in, and it is a real click.** `capture.gd` emits `start_pressed` directly; this pushes
	# the event instead, because the rule this whole folder exists under is that every input goes through
	# `root.push_input()` and a click is the one input this run has. Screen coordinates, so the viewport's
	# own transform maps it back exactly the way a real click arrives at `TitleScreen._gui_input`.
	var at: Vector2 = root.get_screen_transform() * main.title._rect_of(0).get_center()
	root.push_input(_click(at, true))
	root.push_input(_click(at, false))
	await _frames(4)
	if main.run.phase != Run.Phase.PLAY:
		# Reported, never worked around. A tool that quietly fell back to emitting the signal would hide the
		# fact that the button it aims at is no longer where it computed.
		printerr("[찍기] 시작하기 버튼을 못 눌렀다 — 좌표 %s 가 버튼 밖이다" % str(at))
		quit(1)
		return false

	# `main._start()` seeds from `Time.get_ticks_usec()`, so the field it just built is a different one every
	# launch — terrain, rocks and ponds included. The restart with a literal seed is what pins the ground, and
	# it is the same call 다시 하기 makes.
	main.run.restart(SEED)
	main._bind_world()

	# -- the freeze, and why `Engine.time_scale = 0` alone is NOT it -----------------------------------
	# Two things in `sim` are not scaled by delta and both would move a staged frame:
	#  · `Swarm._separate()` corrects positions by a flat `Rules.SEPARATION_MIN` every frame it runs, so a
	#    staged pile spreads a little on every frame between the write and the shutter — and a pile is the
	#    subject of six of these nine shots.
	#  · `World._contact()` fires on `atk_cd == 0.0`, which every freshly added clone opens at, so the first
	#    stepped frame lands a hit nobody staged; with dt at zero the flash it writes never turns off again
	#    and every crowd shot would carry a permanent white creature.
	# `main._process` is the one caller of `run.step()`, and `Node.set_process` is per-node rather than
	# inherited, so `FieldView._process` keeps advancing its own burst list and calling `queue_redraw()`:
	# the picture is still produced by the game's own `_draw()`, on the game's own frame.
	# `time_scale` stays at zero as the second half of it — the HUD's legend fades on `world.elapsed` and its
	# level bar chases on delta, so without it two shots taken seconds apart would differ in the corners.
	Engine.time_scale = 0.0
	main.set_process(false)
	# The other half of "it never takes the user's keyboard": `_unhandled_key_input` is a separate flag, and
	# `Tab` arriving from the user's own keyboard would open the body panel over the shot.
	main.set_process_unhandled_key_input(false)
	# **The two views come off the engine's clock as well, in BOTH modes.** They consume one-frame lists that
	# `World.begin_frame()` clears, so a `_process` still running on the engine's own frame appends the same
	# death burst once per RENDERED frame — and a shot costs several of those. In `push` mode `_tick()` calls
	# them by hand with the simulation's own dt, which is also what keeps a burst's fade and the sim in step;
	# in `scenes` mode nothing advances at all and `_grab()`'s own `queue_redraw()` is what draws the picture.
	main.view.set_process(false)
	main.hud.set_process(false)

	# **The instrument's own frame, and it is first.** If it fails nothing after it is evidence, so nothing
	# after it is taken.
	if not await _known_answer():
		printerr("[찍기] 기준 컷이 틀렸다. 나머지는 안 찍는다 — 계기가 거짓말하면 사진은 답이 아니다.")
		quit(1)
		return false
	return true


## The nine staged stills — one written world per picture, nothing advancing between the write and the
## shutter. See `_push()` for the other mode.
func _scenes() -> void:
	# The crowd, and the two shots plus the strike that are all ONE staged instant. They are taken together
	# rather than in name order precisely so that nothing is re-rolled between them: `02` is `01` with the
	# camera moved and `06` is `01` with a swing written onto it.
	_crowd(_home)
	_look(0.93, _home)
	await _shot("01_crowd_play")
	_look(3.0, _home)
	await _shot("02_crowd_close")
	_strike()
	_look(3.0, _home)
	await _shot("06_mid_strike")

	_host_in_pile()
	_look(4.0, _home)
	await _shot("03_host_in_pile")

	_big_over_swarm(Parts.Species.ELEPHANT, 60.0, 20)
	_look(2.5, _home)
	await _shot("04_elephant_over_swarm")

	_big_over_swarm(Parts.Species.BOSS, 120.0, 30)
	_look(2.0, _home)
	await _shot("05_boss_in_swarm")

	_seven_species()
	_look(1.2, _home)
	await _shot("07_seven_species")

	# The one shot that exists for 갈래 ㄱ's sake rather than 갈래 ㄴ's: `melee-legibility-ko` records that
	# nobody has ever seen a hollow body over this field's forty rocks and twelve ponds, and a comparison
	# that only stresses one branch is a pitch.
	var ground := _terrain_spot()
	_crowd(ground)
	_look(1.2, ground)
	await _shot("08_terrain_crowd")


# -- the instrument's own frame ---------------------------------------------------------------------------
## One 사자 at `SPECIES_FORCE_MIN`, alone, at the camera's centre, at a zoom this file chose. Every number in
## the answer is known before the shutter: `World._radius_of()` returns exactly `Rules.SPECIES_RADIUS` at the
## minimum force, so the body is 26px in the world and `2 × 26 × zoom × scale` px on the frame.
##
## **Two failures are otherwise invisible and either would make every other shot look like a real answer**
## (the third, `--headless`, is refused in `_initialize()` before a frame is drawn):
##  · a body at play scale — the camera was set from outside and `_apply_zoom()` undid it, which is the trap
##    `tools/look/README.md` was written around after it cost plan 3's one close-up
##  · a body that is not where the camera was pointed — `_cam_base` unset, so `_apply_shake()` reassigns
##    `cam.position` from a stale one on the very next frame
func _known_answer() -> bool:
	_reset(_home)
	var w: World = _main.run.world
	var spot := _home + KNOWN_AT
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
		# `_uniform()` picks the WORDING and makes no claim of its own — a blank texture and a camera pointed
		# at empty ground both arrive here as "no lion", and the two are fixed in completely different places.
		# It is deliberately not a second check: with the HUD drawn over every frame, nothing a windowed run
		# can do makes the framebuffer one colour, so a check that could never fire would read as coverage.
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


# -- the scenes -------------------------------------------------------------------------------------------
## `01`/`02`/`06`: the complaint verbatim. A pile of clones with a 사자 standing INSIDE it, and crows and
## horses straddling the pile's edge so the shot carries more than one species' size against the swarm.
func _crowd(centre: Vector2) -> void:
	_reset(centre)
	for n in 24:
		# A third of them fully loaded: `Look.CLONE_LOAD_GROWTH` makes those the bodies that are brighter than
		# the host and over 90% of its size, which is the half of the complaint the user called
		# 「나하고 내 분신하고」.
		_clone(centre + _disc(140.0), Look.CLONE_LOAD_FULL if n % 3 == 0 else 0.0)
	_lion = _critter(Parts.Species.LION, centre + Vector2(10.0, 0.0))
	for n in 3:
		var a := deg_to_rad(20.0 + 120.0 * float(n))
		_critter(Parts.Species.CROW, centre + Vector2(cos(a), sin(a)) * 145.0)
	for n in 2:
		var a := deg_to_rad(70.0 + 130.0 * float(n))
		_critter(Parts.Species.HORSE, centre + Vector2(cos(a), sin(a)) * 155.0)


## `06`: the same instant with a swing written onto it. **The shot must have a hit in frame** — 갈래 ㄱ paints
## the hit flash into a 2px stroke instead of a filled body, so the cost it charges against the second half of
## the complaint (「내 분신들이 때리는지도 모르겠음」) cannot be judged from a frame with nothing striking in it.
func _strike() -> void:
	var w: World = _main.run.world
	var sw: Swarm = w.swarm
	var target: Vector2 = w.critter_pos[_lion]
	# The clones nearest the creature, which is the same set `World._contact()` would have picked — its band
	# is a distance test from the creature's own centre.
	var order := []
	for i in range(1, sw.count):
		order.append([sw.pos[i].distance_to(target), i])
	order.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var attacker := -1
	for n in mini(STRIKE_CLONES, order.size()):
		var i := int(order[n][1])
		var aim: Vector2 = target - sw.pos[i]
		if aim.length_squared() < 0.0001:
			continue
		sw.swing_show[i] = 0.0
		sw.swing_dir[i] = aim.normalized()
		# Moving, not standing. `_squash()` and `_heading()` both read `vel`, and a body at rest is drawn
		# unsquashed and unrotated — which would leave the rim that traces it indistinguishable from one
		# handed `Vector2.ONE`, the exact hole `net_body_rim`'s own fixture was built to close.
		sw.vel[i] = aim.normalized() * Rules.CLONE_SPEED_FOLLOW
		attacker = i
	if attacker >= 0:
		# `critter_hit_dir` points AWAY from the attacker — `World._damage_critter()` owns that convention and
		# `FieldView._paint_critter` puts the spark at `-hit_dir` from the centre, on the struck side.
		var away: Vector2 = target - sw.pos[attacker]
		w.critter_hit_dir[_lion] = away.normalized() if away.length_squared() > 0.0001 else Vector2.RIGHT
		w.critter_hit_show[_lion] = 0.0
	var to_target: Vector2 = target - sw.pos[0]
	if to_target.length_squared() > 0.0001:
		sw.bite_aim = to_target.normalized()
	# 물기's own numbers, off `Parts`. The cone drawn is the cone `Swarm.bite()` would have stored, never a
	# pair tuned to photograph well — a picture of a hit that did not happen is the signature fake.
	sw.bite_range = float(Parts.RANGE[Parts.BITE])
	sw.bite_arc = float(Parts.ARC[Parts.BITE])
	sw.bite_show = 0.0


## `03`: 「어느 것이 나인가」 at its hardest — twelve clones on a ring barely wider than the host, half of them
## loaded, and the host at the exact centre with nothing but its own mark to say so.
func _host_in_pile() -> void:
	_reset(_home)
	for n in 12:
		var a := TAU * float(n) / 12.0
		_clone(_home + Vector2(cos(a), sin(a)) * 26.0, 0.0 if n % 2 == 0 else Look.CLONE_LOAD_FULL)


## `04`/`05`: one large body with the swarm inside its footprint. The host is written a little NORTH of the
## creature on purpose — under 갈래 ㄴ the sort puts the creature in front of it and under the other two the
## host is always on top, so the pair is the axis the shot is about. Written as one function because the two
## scenes differ in exactly three numbers.
func _big_over_swarm(species: int, spread: float, clones: int) -> void:
	_reset(_home)
	var sw: Swarm = _main.run.world.swarm
	sw.pos[0] = sw.place(_home + Vector2(0.0, -18.0), Rules.BODY_RADIUS)
	_critter(species, _home)
	for n in clones:
		_clone(_home + _disc(spread), Look.CLONE_LOAD_FULL if n % 4 == 0 else 0.0)


## `07`: seven colours and one silhouette on one screen. Every creature is at its species' minimum force, so
## every radius on the frame is exactly its `Rules.SPECIES_RADIUS` row and the picture is measurable.
func _seven_species() -> void:
	_reset(_home)
	# A herd, born at one spot the way `World._spawn_herd()` makes one.
	for n in 4:
		_critter(Parts.Species.HORSE, _home + Vector2(-300.0, -150.0) + _disc(70.0))
	_critter(Parts.Species.SQUIRREL, _home + Vector2(300.0, -180.0))
	_critter(Parts.Species.SQUIRREL, _home + Vector2(355.0, -135.0))
	# The two species with `Rules.SPECIES_SPEED_MUL > 1.0` are the two that trail afterimages, so both are in
	# frame: the ghosts are part of what a body reads as, and they carry no rim in any candidate.
	_critter(Parts.Species.CHEETAH, _home + Vector2(-350.0, 170.0))
	_critter(Parts.Species.LION, _home + Vector2(280.0, 160.0))
	_critter(Parts.Species.CROW, _home + Vector2(-120.0, -220.0))
	_critter(Parts.Species.CROW, _home + Vector2(140.0, 230.0))
	for n in 15:
		_clone(_home + _disc(150.0), Look.CLONE_LOAD_FULL if n % 3 == 0 else 0.0)


## `08`: the pond and the rock that stand closest to each other in this seeded field, and the point between
## them. **Scanned, never a literal** — the ground comes from `SEED` and a coordinate written here would
## quietly stop being terrain the day that number moves.
func _terrain_spot() -> Vector2:
	var g: Terrain = _main.run.world.terrain
	var best := INF
	var out := _home
	for a in g.water_pos.size():
		for b in g.rock_pos.size():
			var mid: Vector2 = g.water_pos[a].lerp(g.rock_pos[b], 0.5)
			# See `TERRAIN_INSET`: a pair near an edge photographs half a frame of nothing.
			if mid.x < TERRAIN_INSET or mid.y < TERRAIN_INSET:
				continue
			if mid.x > Rules.FIELD.x - TERRAIN_INSET or mid.y > Rules.FIELD.y - TERRAIN_INSET:
				continue
			var d: float = g.water_pos[a].distance_to(g.rock_pos[b])
			if d < best:
				best = d
				out = mid
	print("[찍기] 물↔바위 최단 %.0fpx, 그 사이 %s" % [best, str(out)])
	return out


# -- push: five sequences, several consecutive frames each ------------------------------------------------
## **The mode that exists because a push happens over time.** A body resting at a creature's surface and a
## body that was never inside it are the same picture; only consecutive frames say which of the two the
## simulation just did, and only consecutive frames say whether the CREATURE moved while it happened — which
## is the half the herding rule stands on. See 「근접전이 안 읽힌다」's A-2 for the pairs being photographed.
##
## Five sequences, one folder each, frames numbered in the order they were taken.
func _push() -> void:
	await _seq_host_into_lion()
	await _seq_rally()
	await _seq_arena_summon()
	await _seq_horse_into_wall()
	await _seq_play_zoom()


## 1. The host walks east into a 사자. Before contact, the contact frame, and the frames after it — the pair
## the table calls host↔creature, where the HOST is the one that moves.
##
## The lion is the species that hunts, so it walks west into the host at the same time and the closing speed
## is both of them; that is the real encounter and not a staged one. What it must show after contact is the
## host failing to get any further in **while the stick is still held east**, which is why `host_input` never
## lets up for the whole sequence.
func _seq_host_into_lion() -> void:
	var seq := "1_host_into_lion"
	_fresh(_home)
	var w: World = _main.run.world
	var k := _critter(Parts.Species.LION, _home + Vector2(160.0, 0.0))
	# Written, never rolled — see `_known_answer()` on why a rotated body's bounding box is not its radius.
	w.critter_dir[k] = Vector2.LEFT
	var eye := _home + Vector2(80.0, 0.0)
	# Two frames a shot, evenly, for the whole thing. The closing speed is both bodies' walks summed
	# (200 + 190 px/s), so a shot is 13px of gap and the ten shots before contact and the eight after it are
	# the same distance apart — uneven spacing reads as the sim having sped up, which is the one thing a
	# sequence about a push must not say.
	for n in 18:
		if n > 0:
			await _step(2, Vector2.RIGHT, true)
		_look(3.0, eye)
		_gap(seq, n, k)
		await _shot("%s/%02d" % [seq, n])


## 2. Forty clones rallied onto the host with `1`. **`Swarm.command_rally()` is called directly and the key
## is not pressed**, for the reason `_tick()` gives: `main._read_input()` polls the real `Input` singleton, so
## driving the rally through the key would mean photographing the user's own keyboard. It is the same function
## the key calls and it takes no argument — the swarm comes to the host.
##
## What the sequence has to show is the arrival AND what happens after it: forty bodies steering at one point
## is the state that used to end as a stack, and the frames after the last one lands are the ones where the
## clone↔clone and clone↔host pairs turn it into a ring.
func _seq_rally() -> void:
	var seq := "2_rally_forty"
	_fresh(_home)
	var sw: Swarm = _main.run.world.swarm
	for n in 40:
		_clone(_home + _disc(260.0), Look.CLONE_LOAD_FULL if n % 3 == 0 else 0.0)
	sw.command_rally()
	for n in 16:
		if n > 0:
			await _step(5, Vector2.ZERO, true)
		_look(1.3, _home)
		_spread(seq, n)
		await _shot("%s/%02d" % [seq, n])


## 3. The arena summon — `World._step_arena()` teleporting a scattered swarm onto a 300px ring around the
## host, which is the one line in the game that manufactures forty overlaps in a single frame.
##
## Frame `00` is taken BEFORE anything is stepped, so the scatter it starts from is in the sequence rather
## than being described. The summon then fires on the first stepped frame: `elapsed` is written past
## `Rules.BOSS_HUNT_AT` and a boss is written inside `Rules.ARENA_RADIUS`, which are exactly the two
## conditions that function tests.
func _seq_arena_summon() -> void:
	var seq := "3_arena_summon"
	_fresh(_home)
	var w: World = _main.run.world
	# Past `BOSS_HUNT_AT` by enough that `main._apply_shake()`'s hunt shake — which times off
	# `elapsed - BOSS_HUNT_AT` — has already run out at `Look.SHAKE_TIME`. A camera still shaking would move
	# every body on the frame together, which is the one thing this sequence may not do.
	w.elapsed = Rules.BOSS_HUNT_AT + 5.0
	_critter(Parts.Species.BOSS, _home + Vector2(300.0, 0.0))
	for n in 40:
		_clone(_home + _disc(600.0), Look.CLONE_LOAD_FULL if n % 3 == 0 else 0.0)
	# One frame each through the arrival and the first of the resolution, then three at a time once it is
	# spreading rather than exploding. A pile resolves fastest on the frame after it is made.
	for n in 14:
		if n > 0:
			await _step(1 if n <= 7 else 3, Vector2.ZERO, true)
		_look(0.9, _home)
		_spread(seq, n)
		await _shot("%s/%02d" % [seq, n])


## 4. A 말 driven into a wall of clones. **The picture that matters is the horse's own path**: it is stopped
## by the wall (`World._enters_a_body()` refuses the move) and it is never displaced by the separation pass,
## so the clones it is pressed against are the bodies that give way. If forty clones could shove it, herding
## would have become pushing — see 「말은 몰이로 잡는다」.
##
## The horse flees whichever body is nearest, so the host is staged closer to it than the wall is: it runs
## east because the host is west, and it out-runs the host the whole way, which is the hunt this stage has.
func _seq_horse_into_wall() -> void:
	var seq := "4_horse_into_wall"
	# **Not `_home`, and that is a measurement and not a preference.** Run at the field's centre in this seed
	# the horse crossed a pond and `Rules.WATER_SLOW` cut it to 60% for most of the sequence — measured, 11.5px
	# a shot against the 19.2 its own speed says. A picture of a body being stopped by other BODIES may not
	# have terrain as a second cause, so the corridor is scanned for one that has neither pond nor rock in it.
	# `_fresh()` first and `_reset()` again after: the scan has to read THIS sequence's terrain, and the world
	# it reads is the one `restart()` just built.
	_fresh(_home)
	var start := _clear_run(CORRIDOR)
	_reset(start)
	var w: World = _main.run.world
	var sw: Swarm = w.swarm
	var spot := start + Vector2(300.0, 0.0)
	var k := _critter(Parts.Species.HORSE, spot)
	w.critter_dir[k] = Vector2.RIGHT
	# **A closing ARC east of the horse, not a parked line, and that is a measurement.** A horse flees whichever
	# body is nearest and it out-runs the host by 30px/s, so a stationary wall is nearer than the player long
	# before the horse arrives at it and the horse turns away every time: measured twice, at two different
	# spacings, and it never once made contact. **The wall turning it is the design working** — 「말은 몰이로
	# 잡는다」 — so the picture of a horse actually STOPPED needs the swarm sent at it, which is what `3` does
	# and what `command_strike()` is. The arc faces the host, so wherever it breaks east there is a body.
	for n in WALL_CLONES:
		var a := deg_to_rad(-100.0 + 200.0 * float(n) / float(WALL_CLONES - 1))
		_clone(spot + Vector2(cos(a), sin(a)) * 260.0, 0.0)
	sw.command_strike(spot)
	var eye := spot + Vector2(20.0, 0.0)
	# Longer than the other four. The arc closes 260px at the clones' own walk and the last of it is the
	# slowest — twenty-six bodies arriving at one point spend their last frames spreading sideways against each
	# other rather than advancing, so the frames where the wall actually touches the horse are the late ones.
	for n in 26:
		if n > 0:
			await _step(4, Vector2.RIGHT, true)
		_look(1.3, eye)
		_gap(seq, n, k)
		await _shot("%s/%02d" % [seq, n])


## 5. The same mechanism at the scale it is played at. **The shell's own camera drives itself here** — follow,
## shake and zoom, every frame, off the real functions — because `main._apply_zoom()` pulls all the way to
## `Look.ZOOM_FAR` once the swarm passes `Look.ZOOM_FULL_AT`, and 「근접전이 안 읽힌다」's A-6 records that this
## halves every melee mark on screen. A separation judged at 3× and never at play scale is judged at a scale
## nobody plays at.
##
## `main._zoom` is seeded at `ZOOM_FAR` rather than lerped down from `ZOOM_NEAR` so that the whole sequence is
## at that scale instead of the first third of it being an approach.
func _seq_play_zoom() -> void:
	var seq := "5_play_zoom"
	_fresh(_home)
	var w: World = _main.run.world
	for n in 40:
		_clone(_home + _disc(170.0), Look.CLONE_LOAD_FULL if n % 3 == 0 else 0.0)
	var k := _critter(Parts.Species.LION, _home + Vector2(260.0, 0.0))
	w.critter_dir[k] = Vector2.LEFT
	_critter(Parts.Species.CROW, _home + Vector2(120.0, -170.0))
	_critter(Parts.Species.HORSE, _home + Vector2(340.0, 150.0))
	_critter(Parts.Species.ELEPHANT, _home + Vector2(-260.0, 120.0))
	_main._zoom = Look.ZOOM_FAR
	_shell_camera()
	for n in 18:
		if n > 0:
			await _step(4, Vector2.RIGHT, true)
			_shell_camera()
		_gap(seq, n, k)
		await _shot("%s/%02d" % [seq, n])


# -- push: the machinery ----------------------------------------------------------------------------------
## A clean world for every sequence, from the same literal seed, and one host standing at `centre`.
## `restart()` builds a new `World`; `_bind_world()` is what re-points the two views at it, and leaving it out
## is the stale-reference shape `main.gd` names at that function. The terrain comes back with it, which is
## what lets the arena sequence close an arena without the sequences after it inheriting a closed one.
func _fresh(centre: Vector2) -> void:
	_main.run.restart(SEED)
	_main._bind_world()
	_reset(centre)
	DirAccess.make_dir_recursive_absolute(_dir.path_join(_style_name))


## `n` simulation frames, all with the same held stick.
func _step(n: int, host_input: Vector2, grace: bool) -> void:
	for _i in n:
		_tick(host_input, grace)
		# One rendered frame per stepped frame, so the engine never batches a whole sequence behind one draw.
		await _frames(1)


## ONE simulation frame, in the shell's own order and out of the shell's own calls. `main._process` is off for
## the whole run (see `_boot()`), so nothing else advances anything.
##
## ⚠ **`main._read_input()` is deliberately not called.** It polls the real `Input` singleton, and a window
## holding focus while a person types would put their hands in the picture — the second of the three rules
## `tools/look/README.md` is built on. `host_input` is the one field that function writes into `sim`, so it is
## written here instead, and every command a sequence issues goes to the `Swarm` function the key would have
## reached (`command_rally`, `command_strike`).
##
## ⚠ **The two views are stepped by hand with the SIMULATION's dt**, for the reason `_boot()` gives where it
## switches their `_process` off: on the engine's clock they would consume each one-frame list once per
## rendered frame, and their own fades would run at the wall clock while the sim ran at `STEP_DT`.
func _tick(host_input: Vector2, grace: bool) -> void:
	var w: World = _main.run.world
	_main.run.begin_frame()
	w.swarm.host_input = host_input
	if grace:
		# **Only hp and knockback are suppressed, and only where they would be a second cause.**
		# `World._contact()` reads `host_grace` for exactly two things — the host's hp and `Swarm.damage()`'s
		# knockback — so the contact itself, the attack clocks and every separation call still happen. What
		# it removes is the other force that moves the host (knockback) and the camera shake `_apply_shake()`
		# drives off the same hit; both would move the picture for a reason that is not the pass being
		# photographed, and both are named out of scope by the change this run exists to show.
		w.host_grace = 1.0
	_main.run.step(STEP_DT)
	_main.view._process(STEP_DT)
	_main.hud._process(STEP_DT)


## The shell's own three camera writers, in the shell's own order, for the one sequence taken at play scale.
## Driving the real functions rather than copying them is what keeps `00_known_answer` able to catch a camera
## that was undone — see `_look()`.
func _shell_camera() -> void:
	var main := _main
	main._follow_camera(STEP_DT)
	main._apply_shake()
	main._apply_zoom(STEP_DT)
	main.view.view_rect = main._camera_rect()
	main.hud.camera_rect = main._true_camera_rect()


## Printed beside every frame of the two sequences that are about a creature: where the host is, where the
## creature is, and how far the gap is from the distance `World._separate_from_critters()` settles at.
## **The console is the measurement and the PNG is the picture** — this file may not draw over the game's own
## `_draw()`, and a number burned into the frame would be a second drawing path (see `net_draw_leaf`).
func _gap(seq: String, n: int, k: int) -> void:
	var w: World = _main.run.world
	var host: Vector2 = w.swarm.pos[0]
	var cp: Vector2 = w.critter_pos[k]
	var rest := w.critter_radius(k) + Rules.BODY_RADIUS - Rules.SEPARATION_CONTACT_MARGIN
	# The nearest CLONE as well, because the herding sequence's whole question is whether the creature stopped
	# at the wall or went through it, and the host is not the wall.
	var near := INF
	for i in range(1, w.swarm.count):
		near = minf(near, cp.distance_to(w.swarm.pos[i]))
	var clone_rest := w.critter_radius(k) + Rules.CLONE_BODY_RADIUS - Rules.SEPARATION_CONTACT_MARGIN
	print("[밀기] %s %02d · 호스트 %s · 상대 %s · 사이 %.1f (쉬는 자리 %.1f) · 제일 가까운 분신 %.1f (%.1f)" % [
			seq, n, _p(host), _p(cp), host.distance_to(cp), rest, near, clone_rest])


## Printed beside every frame of the two pile sequences: how far the furthest clone stands from the host, and
## how close the closest PAIR of bodies is. The second number is the whole of "the pile resolved" — a stack is
## a nearest pair of zero and a ring is a nearest pair at `Rules.SEPARATION_MIN`.
func _spread(seq: String, n: int) -> void:
	var sw: Swarm = _main.run.world.swarm
	var far := 0.0
	var near := INF
	for i in range(1, sw.count):
		far = maxf(far, sw.pos[i].distance_to(sw.pos[0]))
		near = minf(near, sw.pos[i].distance_to(sw.pos[0]))
		for j in range(i + 1, sw.count):
			near = minf(near, sw.pos[i].distance_to(sw.pos[j]))
	print("[밀기] %s %02d · 몸 %d · 제일 먼 분신 %.1f · 제일 가까운 두 몸 %.1f (닿는 거리 %.1f)" % [
			seq, n, sw.count, far, near, Rules.SEPARATION_MIN])


func _p(v: Vector2) -> String:
	return "(%.1f, %.1f)" % [v.x, v.y]


## The west end of a clear horizontal corridor `length` long: the point whose corridor has the largest
## clearance from every pond and every rock in this seeded field.
##
## **Scanned, never a literal** — the same reason `_terrain_spot()` scans for the opposite thing. The ground
## comes from `SEED` and a coordinate written here quietly stops being clear the day that number moves, with
## the sequence still producing fourteen plausible frames.
func _clear_run(length: float) -> Vector2:
	var g: Terrain = _main.run.world.terrain
	var out := _home
	var best := -INF
	var x := CORRIDOR_INSET
	while x < Rules.FIELD.x - CORRIDOR_INSET - length:
		var y := CORRIDOR_INSET
		while y < Rules.FIELD.y - CORRIDOR_INSET:
			# The clearance of the WORST point on the corridor, not of its start: a run that begins in the
			# open and ends in a pond is not a clear run, and scoring one point cannot tell the two apart.
			var worst := INF
			var s := 0.0
			while s <= length:
				var p := Vector2(x + s, y)
				for j in g.water_pos.size():
					worst = minf(worst, p.distance_to(g.water_pos[j]) - g.water_radius[j])
				for j in g.rock_pos.size():
					worst = minf(worst, p.distance_to(g.rock_pos[j]) - g.rock_radius[j])
				s += CORRIDOR_SAMPLE
			if worst > best:
				best = worst
				out = Vector2(x, y)
			y += CORRIDOR_STEP
		x += CORRIDOR_STEP
	print("[밀기] 빈 복도 %s, 제일 가까운 지형까지 %.0fpx" % [_p(out), best])
	return out


# -- staging ----------------------------------------------------------------------------------------------
## Every scene starts here: one host at `centre`, nothing else alive, every one-frame event list emptied
## through the shell's own frame boundary, and the view's own burst list cleared.
##
## **Nothing advances after this call** — `main._process` is off and `Engine.time_scale` is zero — so what is
## written here is exactly what is photographed. Everything is written rather than evolved for the same
## reason: a comparison of two fields is not a comparison.
func _reset(centre: Vector2) -> void:
	var w: World = _main.run.world
	var sw: Swarm = w.swarm
	_rng.seed = LAYOUT_SEED
	w.critter_count = 0
	w.boss_index = -1
	w.corpse_count = 0
	# Well under `Rules.BOSS_HUNT_AT`, so `World.boss_hunting()` is false: no hunt wash, no screen-edge arrow,
	# and `main._apply_shake()` contributes exactly zero offset. Otherwise the camera moves between two halves
	# of a pair for a reason nothing on screen explains.
	w.elapsed = 0.0
	w.host_hp = Rules.HOST_HP
	w.host_grace = 0.0
	w.host_hit_force = 0
	w.level_show = INF
	w.pending_levels = 0
	w.offer = PackedInt32Array()
	sw.count = 1
	sw.pos[0] = sw.place(centre, Rules.BODY_RADIUS)
	sw.vel[0] = Vector2.ZERO
	sw.force[0] = Rules.FORCE_START
	sw.carried[0] = 0.0
	sw.hit_show[0] = INF
	sw.hit_dir[0] = Vector2.ZERO
	sw.swing_show[0] = INF
	sw.swing_dir[0] = Vector2.ZERO
	sw.bite_show = INF
	sw.split_charge = 0.0
	sw.host_input = Vector2.ZERO
	sw.clear_pull = false
	# The real frame boundary, not a hand-written clear: `FieldView._process` reads those lists every frame
	# and appends a burst for each entry, so one left standing paints the same ring forever at `time_scale 0`.
	_main.run.begin_frame()
	_main.view.reset_pop()


## One clone. Through `add_clone()` so every column is written by the sim's own writer, then moved: a bare
## `pos[i] =` after it is the only thing this file decides.
func _clone(at: Vector2, load_v: float) -> int:
	var sw: Swarm = _main.run.world.swarm
	var i := sw.add_clone(0, CLONE_FORCE)
	if i < 0:
		return -1
	# `place()`, not a bare write. A body staged inside a rock is a picture the game cannot produce, and
	# `08_terrain_crowd` stages a whole pile next to one on purpose.
	sw.pos[i] = sw.place(at, Rules.CLONE_BODY_RADIUS)
	sw.vel[i] = Vector2.ZERO
	sw.carried[i] = load_v
	sw.state[i] = Swarm.FOLLOW
	sw.hit_show[i] = INF
	sw.swing_show[i] = INF
	return i


## One creature, **always at its species' minimum force**, so `World._radius_of()`'s ramp is exactly zero and
## the drawn radius is exactly the `Rules.SPECIES_RADIUS` row. That is what makes every shot measurable and
## what makes two scenes comparable; a rolled force would put a different-sized 사자 in each.
func _critter(species: int, at: Vector2) -> int:
	var w: World = _main.run.world
	var force_v := int(Rules.SPECIES_FORCE_MIN[species])
	var k := w._write_critter(species, w.terrain.push_out(at, float(Rules.SPECIES_RADIUS[species])), force_v)
	if species == Parts.Species.BOSS:
		# `boss_index` is a real column with a real reader — the minimap's own dot — and a boss written
		# without it is a boss the map does not know about.
		w.boss_index = k
	return k


func _disc(r: float) -> Vector2:
	var a := _rng.randf() * TAU
	# `sqrt`, so the points are uniform over the AREA rather than piled at the centre — a pile that is dense
	# in the middle and empty at the rim is not the crowd the user was looking at.
	var d := sqrt(_rng.randf()) * r
	return Vector2(cos(a), sin(a)) * d


# -- the camera -------------------------------------------------------------------------------------------
## **The shell's own two camera writers, called in the shell's own order.** Setting `cam.position` and
## `cam.zoom` from outside is exactly the trap `tools/look/README.md` exists for: in PLAY `_apply_zoom()`
## rewrites `cam.zoom` from `main._zoom` and `_apply_shake()` ASSIGNS `cam.position` from `main._cam_base`,
## so a tool that writes the camera and not the two fields behind it photographs at play scale.
##
## Driving the real functions rather than copying what they do is what keeps `00_known_answer` able to catch
## it — a copy here would be right in this file and wrong in the game.
func _look(z: float, at: Vector2) -> void:
	var main := _main
	main._cam_base = at
	main._zoom = z
	# Zero delta: `_apply_zoom`'s weight is `1 - exp(0)`, so `_zoom` is not lerped toward the swarm-size
	# target and `cam.zoom` comes out at exactly what was asked for.
	main._apply_zoom(0.0)
	main._apply_shake()
	# The two rects the shell assigns every frame, and they are deliberately different — the view's is padded
	# so a body about to walk on screen keeps being drawn, the HUD's is what the minimap draws a camera box
	# from. `main._process` is off, so this is their only writer.
	main.view.view_rect = main._camera_rect()
	main.hud.camera_rect = main._true_camera_rect()


# -- frames, files and pixels -----------------------------------------------------------------------------
func _shot(name: String) -> void:
	_save(await _grab(), name)


## `RenderingServer.frame_post_draw` is the whole trick — `root.get_texture()` read at any other moment hands
## back the PREVIOUS frame, which in this tool is the previous SCENE.
##
## ⚠ **Waited on through the frame budget rather than awaited bare.** A bare `await` on that signal is the one
## wait in this file that nothing bounds, and a renderer that never draws makes it wait forever: measured
## under `--headless`, which the guard in `_initialize()` now refuses outright. Two bounds on one hang is not
## a duplicate — the refusal names the cause anybody will actually hit, this catches the rest.
func _grab() -> Image:
	# **Asked for explicitly rather than relied on.** In `push` mode both views are off the engine's clock
	# (see `_boot()`), so the `queue_redraw()` at the end of their own `_process` is the only one there is —
	# and a shot taken after staging that stepped nothing at all (`00_known_answer`, and frame `00` of a
	# sequence) would otherwise photograph whatever was last drawn, which is the PREVIOUS scene.
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
	var path := _dir.path_join(_style_name).path_join(name + ".png")
	# `name` carries a folder in `push` mode — one per sequence, so a run's five sequences do not arrive as
	# seventy files in one list with only their prefix saying which is which.
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("[찍기] %s %s" % [path, "ok" if err == OK else "실패 %d" % err])


## The bounding box of every pixel matching one colour, over a centred window. See `KNOWN_WINDOW` for why it
## is a window and not the frame.
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


## Is the whole frame one colour — the difference between a blank texture and a camera pointed at nothing.
## **It decides a message, never a verdict**; see its one call site for why it is not a check of its own.
## Sampled on a coarse grid rather than per pixel, because "every sample is the first sample" is what the
## sentence actually claims.
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
