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
