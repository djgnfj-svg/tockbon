extends RefCounted
## The shell — phases, rebinding, the camera zoom, and the seed. Driven treed, through the real
## `main.gd`, never with fields poked by hand: `CLAUDE.md` records that wiring a node by hand in a net
## hides the line that wires it in the shell, so every run here opens through `title.start_pressed.emit()`
## the same way a real click would, not through a private starter.
##
## **Two identity checks, not two field comparisons.** `_bind_world()`'s job is that `view.world` and
## `hud.world` ARE `run.world` — comparing fields would pass on two different `World`s that happen to
## start alike, which is every fresh `World`. Same shape for `ending.result` and `run.result`: a visibility
## flip repaints `EndingScreen` for free, so the live risk is the shell forgetting the assignment, not the
## repaint — and forgetting it reads as "run two draws run one's numbers", invisible to any check that only
## asks whether SOME headline was drawn.

const DT := 1.0 / 60.0


## ⚠ **`corner` is the seventh argument now.** Bone sharpens the host's corners, so it is a per-body value
## and `_blob()` may not read `Look.CORNER` internally; Godot rejects an override whose signature does not
## match the parent, which is why this had to move with it.
class FieldSpy extends FieldView:
	var seen: Array = []

	func _paint_cell(c: CanvasItem, p: Vector2, r: float, col: Color, squash: Vector2, rot: float = 0.0,
			corner: float = Look.CORNER) -> void:
		seen.append({"p": p, "r": r, "col": col})
		super._paint_cell(c, p, r, col, squash, rot, corner)


## Real wiring runs unmodified — `super._ready()` is `main.gd`'s own `_ready()`, building the real
## `FieldView` and adding it exactly as the game does. This only swaps a spy in AFTER, so a net can
## capture `_paint_cell`; it never skips or replaces the line that does the real wiring.
class MainSpy extends "res://src/shell/main.gd":
	var field_spy: FieldSpy = null

	func _ready() -> void:
		super._ready()
		remove_child(view)
		view.queue_free()
		field_spy = FieldSpy.new()
		add_child(field_spy)
		view = field_spy


## Every ring `FieldView` draws, for the two checks below. `_paint_ring` forwards to `_paint_arc` and draws
## nothing itself, so this sees both of its circles rather than only learning the ring hook was called.
class RingSpy extends FieldView:
	var arcs: Array = []

	func _paint_arc(c: CanvasItem, p: Vector2, r: float, from: float, to: float, col: Color,
			width: float) -> void:
		arcs.append({"p": p, "r": r})
		super._paint_arc(c, p, r, from, to, col, width)


## **A shell whose INPUT PHASE produces sim events, which is the one thing no other fixture in the round
## could do.** `F` and the three attack keys are read in `_read_input()`, which runs BEFORE `run.step()`;
## `split_this_frame` and `critters_died_this_frame` are filled from there. Every existing check on those
## two lists called `split_hold()`/`_damage_critter()` by hand and read the list back with no `step()` in
## between, so the frame the real game actually runs was never measured — and on that frame the sim's own
## clear (at the top of `step()`, where it used to live) erased the event before `view` ever saw it.
##
## ⚠ **`super._read_input(delta)` runs first and unmodified.** This adds to the real input phase; it does not
## replace it, so the ordering being measured is the game's own.
class InputMain extends "res://src/shell/main.gd":
	var ring_spy: RingSpy = null
	var split_now := false
	var kill_now := -1

	func _ready() -> void:
		super._ready()
		remove_child(view)
		view.queue_free()
		ring_spy = RingSpy.new()
		add_child(ring_spy)
		view = ring_spy

	func _read_input(delta: float) -> void:
		super._read_input(delta)
		if split_now:
			split_now = false
			run.world.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
		if kill_now >= 0:
			run.world._damage_critter(kill_now, 9999)
			kill_now = -1


func run(t) -> void:
	# -- 11 / 11b: view.world / hud.world / ending.result, all by IDENTITY -----------------------------
	var a := MainSpy.new()
	t.root.add_child(a)
	await t.pump_frames(2)
	a.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(a.run.phase, Run.Phase.PLAY, "start_pressed로 실제 PLAY에 들어간다")
	# `_bind_world()`'s `_start()` call site, checked directly rather than only through 21b — a check
	# whose own label is about camera culling, not identity. If 21b's setup ever changes shape, this site
	# would otherwise go unwatched.
	t.ok(a.view.world == a.run.world, "start() 직후 view.world가 이미 run.world와 동일 인스턴스다")

	# Guarded: a broken start_pressed wiring already failed the two checks above by name. Without this,
	# every line below still runs and crashes on `a.run.world` being null, burying that diagnosis and
	# losing every other check in this file to the same crash — `run(t)` is one function.
	if a.run.phase == Run.Phase.PLAY:
		a.run.world.host_hp = 0
		await t.pump_frames(1)
		t.eq(a.run.phase, Run.Phase.ENDING, "설정: 죽음으로 ENDING에 들어갔다")
		t.ok(a.ending.result == a.run.result, "ending.result가 run.result와 동일 인스턴스다")

		a.ending.restart_pressed.emit()
		await t.pump_frames(1)
		t.eq(a.run.phase, Run.Phase.PLAY, "restart_pressed로 다시 PLAY에 들어간다")
		t.ok(a.view.world == a.run.world, "view.world가 run.world와 동일 인스턴스다")
		t.ok(a.hud.world == a.run.world, "hud.world가 run.world와 동일 인스턴스다")

	t.root.remove_child(a)
	a.queue_free()

	# -- 12: visible per phase, driven TITLE → PLAY → ENDING → TITLE -----------------------------------
	var b := MainSpy.new()
	t.root.add_child(b)
	await t.pump_frames(2)

	t.ok(b.title.visible, "TITLE: title이 보인다")
	t.ok(not b.view.visible, "TITLE: view가 안 보인다")
	t.ok(not b.hud.visible, "TITLE: hud가 안 보인다")
	t.ok(not b.cards.visible, "TITLE: cards가 안 보인다")
	t.ok(not b.ending.visible, "TITLE: ending이 안 보인다")

	b.title.start_pressed.emit()
	await t.pump_frames(1)
	t.ok(not b.title.visible, "PLAY: title이 안 보인다")
	t.ok(b.view.visible, "PLAY: view가 보인다")
	t.ok(b.hud.visible, "PLAY: hud가 보인다")
	t.ok(not b.ending.visible, "PLAY: ending이 안 보인다")

	# Guarded — see the identical note on group `a`. `b.run.phase` is what start_pressed was just
	# supposed to move; if it didn't, `b.run.world` below is null.
	if b.run.phase == Run.Phase.PLAY:
		b.run.world.host_hp = 0
		await t.pump_frames(1)
		t.ok(not b.title.visible, "ENDING: title이 안 보인다")
		t.ok(b.view.visible, "ENDING: view가 보인다 (얼어붙은 채로 뒤에)")
		t.ok(not b.hud.visible, "ENDING: hud가 안 보인다")
		t.ok(not b.cards.visible, "ENDING: cards가 안 보인다")
		t.ok(b.ending.visible, "ENDING: ending이 보인다")

		b.ending.title_pressed.emit()
		await t.pump_frames(1)
		t.ok(b.title.visible, "다시 TITLE: title이 보인다")
		t.ok(not b.view.visible, "다시 TITLE: view가 안 보인다")
		t.ok(not b.ending.visible, "다시 TITLE: ending이 안 보인다")
		# `view`/`hud` staying hidden does not prove `_bind_world()` ran on this path — a missing call
		# here is invisible to every visibility check above, since `view.world` being stale changes
		# nothing on screen while `view.visible` is false. Measured: removing `_bind_world()` from
		# `_to_title()` left every check above this line green.
		t.eq(b.run.world, null, "설정: to_title() 후 run.world는 없다")
		t.eq(b.view.world, null, "다시 TITLE: view.world도 함께 비워진다 (죽은 World를 계속 물고 있지 않는다)")
		t.eq(b.hud.world, null, "다시 TITLE: hud.world도 함께 비워진다")

	t.root.remove_child(b)
	b.queue_free()

	# -- 12b / 20b: across 다시 하기 — title never shows, view.world changes, seeds differ ---------------
	var c := MainSpy.new()
	t.root.add_child(c)
	await t.pump_frames(2)
	c.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(c.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see group `a`'s note. `c.run.world` is dereferenced on the very next line otherwise.
	if c.run.phase == Run.Phase.PLAY:
		var world1 := c.run.world
		var title_ever_visible := c.title.visible

		c.run.world.host_hp = 0
		await t.pump_frames(1)
		title_ever_visible = title_ever_visible or c.title.visible
		c.ending.restart_pressed.emit()
		await t.pump_frames(1)
		title_ever_visible = title_ever_visible or c.title.visible
		var seed_a: int = c.run.seed_used

		t.ok(not title_ever_visible, "다시 하기로 가는 동안 title이 한 번도 보이지 않는다")
		t.ok(c.view.world != world1, "다시 하기 후 view.world가 다른 World 인스턴스다")

		c.run.world.host_hp = 0
		await t.pump_frames(1)
		c.ending.restart_pressed.emit()
		await t.pump_frames(1)
		var seed_b: int = c.run.seed_used
		t.ok(seed_a != seed_b, "restart()를 두 번 연달아 해도 seed_used가 서로 다르다")

	t.root.remove_child(c)
	c.queue_free()

	# -- 21a: the zoom moves as the swarm grows ---------------------------------------------------------
	var d := MainSpy.new()
	t.root.add_child(d)
	await t.pump_frames(2)
	d.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(d.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see group `a`'s note.
	if d.run.phase == Run.Phase.PLAY:
		for _i in 30:
			d.run.world.swarm.add_clone()
		var zoom_before: float = d.cam.zoom.x
		for _f in 30:
			await t.pump_frames(1)
		t.ok(d.cam.zoom.x < zoom_before,
				"무리가 커지면 줌이 멀어지는 쪽(더 작은 값)으로 움직인다 (%.3f → %.3f)" % [zoom_before, d.cam.zoom.x])

	t.root.remove_child(d)
	d.queue_free()

	# -- 21b / 21c: the camera rect survives the zoom — one bite does not prove the range --------------
	# Silenced food, or _paint_cell arrives ~500 times and the specific point being looked for is buried.
	# Host and camera pinned at the literal (1920, 1080); the target coordinates are derived from the
	# viewport (1280x720) and the two zoom levels — see the run shell plan's stage 3 implementation notes
	# for the derivation. `_zoom`/`cam.zoom` are seeded directly rather than pumped to convergence: with
	# ZOOM_LERP 2.0 the lerp needs ~200 frames to settle, and seeding is not faking the value as long as
	# the NATURAL target already equals what is seeded (30 clones → ZOOM_FAR naturally; one body →
	# ZOOM_NEAR naturally) — check 21a above is what proves the lerp itself runs.
	var e := MainSpy.new()
	t.root.add_child(e)
	await t.pump_frames(2)
	e.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(e.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see group `a`'s note.
	if e.run.phase == Run.Phase.PLAY:
		_silence_food(e.run.world)
		_clear_terrain(e.run.world)
		e.run.world.critter_count = 0
		e.run.world.swarm.pos[0] = Vector2(1920.0, 1080.0)
		e.cam.position = Vector2(1920.0, 1080.0)
		for _i in 30:
			e.run.world.swarm.add_clone()
		e._zoom = Look.ZOOM_FAR
		e.cam.zoom = Vector2(Look.ZOOM_FAR, Look.ZOOM_FAR)
		var edge_clone := e.run.world.swarm.add_clone()
		e.run.world.swarm.pos[edge_clone] = Vector2(2705.0, 1080.0)
		# One `run.step()` runs before the paint capture — a FOLLOW clone walks at the host every frame,
		# and the edge clone would drift a few px off the literal before it is ever drawn, failing an
		# exact-position check for a reason that is not culling. `3` is the freeze now that `1` gathers at
		# the host: a STRIKE clone standing ON its strike point is already arrived
		# (`to.length() == 0 <= rally_radius()`), so `desired` stays zero and the position is exact.
		e.run.world.swarm.command_strike(Vector2(2705.0, 1080.0))
		e.field_spy.seen.clear()
		await t.pump_frames(1)
		t.ok(_painted_at(e.field_spy.seen, Vector2(2705.0, 1080.0)),
				"ZOOM_FAR에서 화면 구석 바로 안쪽 좌표가 실제로 그려진다 (2705,1080)")

	t.root.remove_child(e)
	e.queue_free()

	var f := MainSpy.new()
	t.root.add_child(f)
	await t.pump_frames(2)
	f.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(f.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see group `a`'s note.
	if f.run.phase == Run.Phase.PLAY:
		_silence_food(f.run.world)
		_clear_terrain(f.run.world)
		f.run.world.critter_count = 0
		f.run.world.swarm.pos[0] = Vector2(1920.0, 1080.0)
		f.cam.position = Vector2(1920.0, 1080.0)
		f._zoom = Look.ZOOM_NEAR
		f.cam.zoom = Vector2(Look.ZOOM_NEAR, Look.ZOOM_NEAR)
		var far_clone := f.run.world.swarm.add_clone()
		f.run.world.swarm.pos[far_clone] = Vector2(2520.0, 1080.0)
		f.run.world.swarm.command_strike(Vector2(2520.0, 1080.0))   ## frozen too — see the note above
		f.field_spy.seen.clear()
		await t.pump_frames(1)
		t.ok(not _painted_at(f.field_spy.seen, Vector2(2520.0, 1080.0)),
				"ZOOM_NEAR에서는 그 좌표가 여전히 화면 밖이라 걸러진다 (2520,1080)")

		# A positive control, same MainSpy, one frame later. Without it, "the far point is absent from
		# `seen`" is satisfied just as well by nothing being drawn at all as by real culling — the host
		# alone (always drawn, unconditionally, in FieldView._paint, and since plan 3 by way of
		# `_paint_body`, which still calls `_paint_cell` for the base blob) kept `seen` non-empty and hid
		# that gap. This clone sits well inside the ZOOM_NEAR rect (x:[1440,2400], y:[810,1350]) and must
		# actually reach `_paint_cell`. The strike point is re-pinned to ITS position, not `far_clone`'s —
		# one shared `strike_point` cannot freeze two clones at two different places in the same capture,
		# so this runs as its own capture instead. `add_clone()` inherits row 0's state, which is FOLLOW,
		# so the command has to come after it or this clone walks at the host on the very frame captured.
		var near_clone := f.run.world.swarm.add_clone()
		f.run.world.swarm.pos[near_clone] = Vector2(2000.0, 1080.0)
		f.run.world.swarm.command_strike(Vector2(2000.0, 1080.0))
		f.field_spy.seen.clear()
		await t.pump_frames(1)
		t.ok(_painted_at(f.field_spy.seen, Vector2(2000.0, 1080.0)),
				"ZOOM_NEAR에서 사각형 안쪽 좌표는 실제로 그려진다 (2000,1080) — 부정 대조의 짝")

	t.root.remove_child(f)
	f.queue_free()

	# -- the harvest pop survives 다시 하기 --------------------------------------------------------------
	# `FieldView` is built once in `_ready()` and only re-pointed, and its `_last_banked` is a HIGH-WATER
	# MARK of the bank. Left standing across `_bind_world()`, `banked > _last_banked` is false for the
	# whole of run two and the host stops scaling on eating — the file's own header calls that the only
	# readability requirement in the build. Nothing errors and the HUD bar still moves, so the screen does
	# not even look dead. **The second run banks far LESS than the first**, which is the only shape that
	# tells a reset apart from a mark that simply got passed again.
	var g := MainSpy.new()
	t.root.add_child(g)
	await t.pump_frames(2)
	g.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(g.run.phase, Run.Phase.PLAY, "설정: start_pressed로 PLAY에 들어갔다")

	# Guarded — see group `a`'s note.
	if g.run.phase == Run.Phase.PLAY:
		g.run.world.swarm.banked = 300.0
		await t.pump_frames(2)
		t.ok(g.view._absorb_pop > 0.0,
				"설정: 첫 런에서 수확 반응이 실제로 일어났다 (%.3f)" % g.view._absorb_pop)

		g.run.world.host_hp = 0
		await t.pump_frames(1)
		g.ending.restart_pressed.emit()
		await t.pump_frames(2)
		t.eq(g.run.phase, Run.Phase.PLAY, "설정: 다시 하기로 두 번째 런이 열렸다")
		g.view._absorb_pop = 0.0
		g.run.world.swarm.banked = 20.0   ## 첫 런의 300보다 한참 적다
		await t.pump_frames(2)
		t.ok(g.view._absorb_pop > 0.0,
				"두 번째 런에서도 수확이 화면에 뜬다 — 첫 런의 최고치를 넘길 필요가 없다 (%.3f)"
						% g.view._absorb_pop)

	t.root.remove_child(g)
	g.queue_free()

	await _b2_screen_shake(t)
	await _b2b_the_shake_never_accumulates(t)
	await _d1_the_hunt_shakes_too(t)
	await _events_from_the_input_phase_reach_the_view(t)
	await _a_frozen_sim_does_not_repeat_its_last_frame(t)


# -- the input phase is a producer, and the frame boundary has to be before it -----------------------------
## §F-10's split ring and §B-4's monster burst, both driven from `_read_input()` — see `InputMain`. Nothing
## else in the round runs a sim event through the shell's own input phase, and the two lists these draw from
## were cleared at the top of `step()`, which runs AFTER it: the ring and the burst were erased on the frame
## they were written, 100% of the time, in the real game and nowhere else.
##
## *Mutation: move `died_this_frame`/`split_this_frame`/`critters_died_this_frame`'s clear back to the top of
## `Swarm.step()`/`World.step()`. Both checks below go red; every other check on those lists stays green.*
func _events_from_the_input_phase_reach_the_view(t) -> void:
	var m := InputMain.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: PLAY에 들어갔다")

	if m.run.phase == Run.Phase.PLAY:
		var w: World = m.run.world
		_silence_food(w)
		_clear_terrain(w)
		w.critter_count = 0
		w.boss_index = -1
		# The host cannot split (force 1), so the one clone is the only body that halves and its position is
		# the only split point on screen.
		w.swarm.force[0] = 1
		var c := w.swarm.add_clone(0, 20)
		var split_at: Vector2 = w.swarm.pos[c]
		var crow := w._write_critter(Parts.Species.CROW, w.swarm.pos[0] + Vector2(-400.0, 0.0), 10)
		var crow_at: Vector2 = w.critter_pos[crow]
		var crow_r: float = w.critter_radius(crow)

		m.ring_spy.arcs.clear()
		m.split_now = true
		m.kill_now = crow
		await t.pump_frames(1)
		t.eq(w.swarm.count, 3, "설정: 입력 단계에서 실제로 갈라졌다")
		t.eq(w.critter_count, 0, "설정: 입력 단계에서 실제로 까마귀를 죽였다")

		var split_ring := 0
		var death_ring := 0
		for e: Dictionary in m.ring_spy.arcs:
			if _near(e["p"], split_at) and absf(float(e["r"]) - Look.SPLIT_POP_R0) < 1.0:
				split_ring += 1
			if _near(e["p"], crow_at) \
					and absf(float(e["r"]) - crow_r * Look.MONSTER_DEATH_R_MUL) < 1.5:
				death_ring += 1
		t.ok(split_ring > 0,
				"입력 단계에서 F가 터진 그 프레임에 갈라진 자리의 링이 실제로 화면에 닿는다 %s"
						% str(m.ring_spy.arcs))
		t.ok(death_ring > 0,
				"그리고 내 키로 죽인 몬스터의 파열도 같은 프레임에 화면에 닿는다 — 분신이 죽인 것만 뜨지 않는다")

	t.root.remove_child(m)
	m.queue_free()


# -- a frozen sim may not re-fire the last frame it ran ---------------------------------------------------
## `Tab` freezes `Run.step()` outright, so nothing refills the one-frame event lists — and `FieldView`'s
## `_process` keeps running. With the clear anywhere inside `step()`, the last advancing frame's entries sit
## there and the view appends a FRESH burst from them every frame for as long as the panel is open: the same
## ring at the same spot, forever, over a visibly stopped world. `run.begin_frame()` is called outside the
## phase branch for exactly this, and this is what says so.
##
## *Mutation: move `run.begin_frame()` inside the `if run.phase == PLAY:` branch below `run.paused = ...`,
## or delete it. `_deaths` climbs instead of draining.*
func _a_frozen_sim_does_not_repeat_its_last_frame(t) -> void:
	var m := InputMain.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: PLAY에 들어갔다")

	if m.run.phase == Run.Phase.PLAY:
		var w: World = m.run.world
		_silence_food(w)
		_clear_terrain(w)
		w.critter_count = 0
		w.boss_index = -1
		var crow := w._write_critter(Parts.Species.CROW, w.swarm.pos[0] + Vector2(-400.0, 0.0), 10)

		m.kill_now = crow
		await t.pump_frames(1)
		t.eq(m.ring_spy._deaths.size(), 1, "설정: 죽음 하나가 파열 목록에 하나로 들어갔다")

		# The panel freezes the sim on the very next frame. Nothing refills the list; nothing may re-read it.
		m.body.open()
		# ⚠ **Ninety, not thirty.** A headless pumped frame runs nearer 135fps than 60 here (measured in
		# `net_paint._b3_b4_death_bursts_persist_and_fade`), so thirty frames is 0.22s against
		# `Look.BURST_TIME`'s 0.4 and the entry has not expired yet — the drain half of this check would be
		# reading a burst that is simply still alive.
		var worst := 0
		for _f in 90:
			await t.pump_frames(1)
			worst = maxi(worst, m.ring_spy._deaths.size())
		t.eq(worst, 1,
				"몸 패널로 멈춘 동안 파열이 한 개를 넘지 않는다 — 멈춘 프레임을 매번 새로 읽지 않는다 (%d)" % worst)
		t.eq(m.ring_spy._deaths.size(), 0,
				"그리고 멈춰 있는 동안에도 그 하나는 제 시간이 지나 사라진다 — 영원히 남지 않는다")

	t.root.remove_child(m)
	m.queue_free()


# -- B-2: the shake is APPLIED to the camera, never accumulated into it ------------------------------------
## `_apply_shake()` used to `+=` its offset onto `cam.position`, which `_follow_camera()` then took as the
## base of the next frame's lerp — so the impulse was added every frame while the follow pulled back ~10.9%
## of it, converging on `offset / 0.109` ≈ 9× the intended displacement. `Look.SHAKE_MAX` bounded the impulse
## and nothing bounded the picture.
##
## ⚠ **`_b2_screen_shake` above structurally cannot see this**: it re-assigns `cam.position = origin` before
## each single pumped frame, which is the one shape that erases accumulation before it can be measured. This
## one seeds the camera ONCE and then never touches it again.
##
## The body panel is what makes the reading exact: `Run.step()` returns while `paused`, so `hit_show[0]`
## stops advancing and the shake offset is the SAME vector every frame — a constant impulse, which is the
## worst case for accumulation and the easiest one to bound.
func _b2b_the_shake_never_accumulates(t) -> void:
	var m := MainSpy.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: PLAY에 들어갔다")

	if m.run.phase == Run.Phase.PLAY:
		var origin := Vector2(1920.0, 1080.0)
		_clear_terrain(m.run.world)
		_silence_food(m.run.world)
		m.run.world.critter_count = 0
		m.run.world.boss_index = -1
		m.run.world.swarm.pos[0] = origin
		m._cam_base = origin
		m.cam.position = origin
		# Force 200 → amplitude capped at `SHAKE_MAX`, the loudest hit the game can produce.
		m.run.world.host_hit_force = 200
		m.run.world.swarm.hit_show[0] = 0.05
		m.body.open()   ## freezes the sim, so the same offset is asked for every frame below

		var worst := 0.0
		for _f in 40:
			await t.pump_frames(1)
			worst = maxf(worst, m.cam.position.distance_to(origin))
		t.ok(worst > 1.0, "설정: 마흔 프레임 내내 실제로 흔들리고 있었다 (%.2f)" % worst)
		t.ok(worst <= Look.SHAKE_MAX + 0.01,
				"흔들림은 마흔 프레임이 지나도 SHAKE_MAX(28px)를 넘지 않는다 — 카메라에 쌓이지 않는다 (%.2f)"
						% worst)
		# The exact value, so "bounded" cannot be satisfied by a shake that decayed to nothing instead.
		var dir := Vector2(sin(0.05 * Look.SHAKE_FREQ_X), sin(0.05 * Look.SHAKE_FREQ_Y))
		var expect := dir * Look.SHAKE_MAX * (1.0 - 0.05 / Look.SHAKE_TIME)
		t.ok(m.cam.position.distance_to(origin + expect) < 0.5,
				"그리고 마흔 프레임째의 자리는 첫 프레임과 같은 공식 그대로다 (%s / 기대 %s)"
						% [str(m.cam.position - origin), str(expect)])

	t.root.remove_child(m)
	m.queue_free()


# -- D-1: the announcement's own shake, the shared machinery's SECOND caller ------------------------------
## `_shake_offset()` was factored out so §D-1 could drive it off `elapsed - Rules.BOSS_HUNT_AT`, and that
## factoring is what made the gap invisible: `_b2_screen_shake` proves the formula thoroughly and drives only
## the hit. The whole `if run.world.boss_hunting():` branch could be deleted with the round green.
func _d1_the_hunt_shakes_too(t) -> void:
	var m := MainSpy.new()
	t.root.add_child(m)
	await t.pump_frames(2)
	m.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(m.run.phase, Run.Phase.PLAY, "설정: PLAY에 들어갔다")

	if m.run.phase == Run.Phase.PLAY:
		var origin := Vector2(1920.0, 1080.0)
		_clear_terrain(m.run.world)
		_silence_food(m.run.world)
		m.run.world.critter_count = 0
		m.run.world.boss_index = -1
		m.run.world.swarm.pos[0] = origin
		m._cam_base = origin
		m.cam.position = origin
		# **No hit at all** — `hit_show[0]` at INF and the force at 0, so anything that moves the camera below
		# came from the hunt branch and from nothing else.
		m.run.world.host_hit_force = 0
		m.run.world.swarm.hit_show[0] = INF
		m.body.open()   ## freezes `elapsed`, so the instant sampled is the instant written

		# One frame BEFORE the threshold: nothing.
		m.run.world.elapsed = Rules.BOSS_HUNT_AT - 0.1
		await t.pump_frames(1)
		t.ok(m.cam.position.distance_to(origin) < 0.01,
				"사냥이 시작되기 전엔 카메라가 흔들리지 않는다 (%s)" % str(m.cam.position - origin))

		# Just past it: the same formula, on `elapsed - BOSS_HUNT_AT`, at the full `SHAKE_MAX`.
		m.run.world.elapsed = Rules.BOSS_HUNT_AT + 0.1
		await t.pump_frames(1)
		var dir := Vector2(sin(0.1 * Look.SHAKE_FREQ_X), sin(0.1 * Look.SHAKE_FREQ_Y))
		var expect := dir * Look.SHAKE_MAX * (1.0 - 0.1 / Look.SHAKE_TIME)
		t.ok(expect.length() > 1.0, "설정: 그 순간의 기대 오프셋은 0이 아니다 (%.2f)" % expect.length())
		t.ok(m.cam.position.distance_to(origin + expect) < 0.5,
				"사냥이 시작되면 맞지 않아도 화면이 한 번 흔들린다 — §B-2와 같은 공식, elapsed를 시계로 (%s / 기대 %s)"
						% [str(m.cam.position - origin), str(expect)])

		# And it ends: past `SHAKE_TIME` the branch contributes exactly zero again.
		m.run.world.elapsed = Rules.BOSS_HUNT_AT + Look.SHAKE_TIME + 0.01
		await t.pump_frames(1)
		t.ok(m.cam.position.distance_to(origin) < 0.01,
				"그리고 SHAKE_TIME이 지나면 정확히 0으로 돌아온다 — 사냥 내내 흔들리지 않는다")

	t.root.remove_child(m)
	m.queue_free()


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.6


# -- B-2: the screen shake — deterministic, proportional to force, exactly 0 past SHAKE_TIME, on position --
## `Swarm.hit_show[0]` is the host's own up-counting hit clock (§A), so nothing here drives a real hit
## through `_contact()` — the two fields the shake reads are set by hand, the same idiom the sim-side checks
## use for `corpse_progress`. **Two `MainSpy`s pumped in lockstep**, so both receive the exact same engine
## `delta` this frame: a shake proven deterministic against a `t` read back off each instance's OWN clock is
## proven against real frame jitter, not against a dt this test happens to also assume.
func _b2_screen_shake(t) -> void:
	var h1 := MainSpy.new()
	var h2 := MainSpy.new()
	t.root.add_child(h1)
	t.root.add_child(h2)
	await t.pump_frames(2)
	h1.title.start_pressed.emit()
	h2.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(h1.run.phase, Run.Phase.PLAY, "설정: 첫 번째가 PLAY로 들어갔다")
	t.eq(h2.run.phase, Run.Phase.PLAY, "설정: 두 번째도 PLAY로 들어갔다")

	if h1.run.phase == Run.Phase.PLAY and h2.run.phase == Run.Phase.PLAY:
		var origin := Vector2(1920.0, 1080.0)
		_clear_terrain(h1.run.world)
		h1.run.world.critter_count = 0
		h1.run.world.boss_index = -1
		h1.run.world.swarm.pos[0] = origin
		h1.cam.position = origin
		_clear_terrain(h2.run.world)
		h2.run.world.critter_count = 0
		h2.run.world.boss_index = -1
		h2.run.world.swarm.pos[0] = origin
		h2.cam.position = origin

		# -- rest: no hit at all, cam.position does not move off the host --------------------------------
		h1.run.world.host_hit_force = 0
		h1.run.world.swarm.hit_show[0] = INF
		await t.pump_frames(1)
		t.ok(h1.cam.position.distance_to(origin) < 0.01,
				"설정: 안 맞은 채로는 흔들리지 않는다 (%s)" % str(h1.cam.position))

		# -- the same instant, two different forces: proportional AND deterministic ----------------------
		h1.run.world.host_hit_force = 20     ## amp = 20 * 0.35 = 7.0, under SHAKE_MAX
		h2.run.world.host_hit_force = 200    ## amp would be 70.0 — capped at SHAKE_MAX 28
		h1.run.world.swarm.hit_show[0] = 0.0
		h2.run.world.swarm.hit_show[0] = 0.0
		h1.cam.position = origin
		h2.cam.position = origin
		await t.pump_frames(1)     ## both nodes advance by the SAME engine delta this frame

		var t1: float = h1.run.world.swarm.hit_show[0]
		var t2: float = h2.run.world.swarm.hit_show[0]
		t.ok(absf(t1 - t2) < 0.0001,
				"설정: 같은 프레임이므로 두 흔들림 시계가 같은 값으로 올랐다 (%.5f / %.5f)" % [t1, t2])
		t.ok(t1 > 0.0 and t1 < Look.SHAKE_TIME, "설정: 그 값은 아직 SHAKE_TIME 안이다 (%.5f)" % t1)

		var dir := Vector2(sin(t1 * Look.SHAKE_FREQ_X), sin(t1 * Look.SHAKE_FREQ_Y))
		var decay := 1.0 - t1 / Look.SHAKE_TIME
		var expect1 := dir * minf(20.0 * Look.SHAKE_PER_FORCE, Look.SHAKE_MAX) * decay
		var expect2 := dir * minf(200.0 * Look.SHAKE_PER_FORCE, Look.SHAKE_MAX) * decay
		var off1: Vector2 = h1.cam.position - origin
		var off2: Vector2 = h2.cam.position - origin
		t.ok(off1.distance_to(expect1) < 0.5,
				"결정적 함수: 힘 20의 흔들림이 공식(sin(t×FREQ)×힘×0.35×decay)과 일치한다 (%s / %s)"
						% [str(off1), str(expect1)])
		t.ok(off2.distance_to(expect2) < 0.5,
				"힘 200(상한 넘음)도 공식과 일치한다 — SHAKE_MAX에서 잘린다 (%s / %s)" % [str(off2), str(expect2)])
		t.ok(off2.length() > off1.length() + 0.5,
				"힘이 셀수록 흔들림이 커진다 — 20보다 200이 크다 (%.2f > %.2f)" % [off2.length(), off1.length()])
		t.eq(h1.cam.offset, Vector2.ZERO, "흔들림은 cam.offset을 전혀 쓰지 않는다 (h1)")
		t.eq(h2.cam.offset, Vector2.ZERO, "흔들림은 cam.offset을 전혀 쓰지 않는다 — 힘이 세도 그대로다 (h2)")

		# -- past SHAKE_TIME: exactly zero, whatever the stale host_hit_force still says -------------------
		h1.run.world.swarm.hit_show[0] = Look.SHAKE_TIME
		h1.cam.position = origin
		await t.pump_frames(1)
		t.ok(h1.cam.position.distance_to(origin) < 0.001,
				"SHAKE_TIME이 지나면 흔들림은 정확히 0이다 (%s)" % str(h1.cam.position))

	t.root.remove_child(h1)
	h1.queue_free()
	t.root.remove_child(h2)
	h2.queue_free()


func _painted_at(seen: Array, p: Vector2) -> bool:
	for e: Dictionary in seen:
		if e["p"] == p:
			return true
	return false


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## ⚠ **Every check below that pins a body at a LITERAL coordinate needs this, and it is not optional here.**
## `Swarm.place()` pushes a body out of any rock it overlaps, and the shell rolls a **fresh seed** on every
## `start()` — so a hand-placed clone lands a few px off its literal on the runs where a rock happens to be
## there and stays exact on the runs where one does not. Measured: this file went red on one round and
## green on the next with nothing but the ground under it changing.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
