extends RefCounted
## The level-up pick, driven through the real shell.
##
## ⚠ **The failure this net is built around is a panel that never becomes visible.** `CLAUDE.md` measured
## exactly that shipping under 5,576 green checks. So the panel is not constructed here — the shell's own
## `_ready()` builds it, and the assertions are on `visible` at both edges. **Wiring it by hand in the net
## would hide the line that wires it in the game**: delete the shell's `add_child(cards)` and a
## hand-wired net stays green while the player sees nothing.
##
## The freeze is asserted too. A level-up that does not stop the world is a notification, and a
## notification is something you watch happen — which is the one thing this whole direction rejects.

const DT := 1.0 / 60.0


func run(t) -> void:
	# -- the rule, without the shell --------------------------------
	var w := World.new()
	w.setup(6)
	t.eq(w.pending_levels, 0, "시작할 때는 고를 게 없다")

	# A pinned literal, not `Rules.LEVEL_COST_BASE`: reading the constant through the thing it gates makes
	# the check scale with it, and the threshold could be moved to 1000 with this net still green. The
	# FIRST level costs the base exactly (`pow(GROWTH, 0)` is 1), which is what keeps this literal honest
	# now that the cost rises.
	w.swarm.banked = 10.0
	var force_before: int = w.swarm.force[0]
	w.step(DT)
	t.eq(w.pending_levels, 1, "은행이 한 칸 차면 레벨이 하나 생긴다")
	t.eq(w.offer.size(), 3, "카드는 셋이다")

	# **The whole payout of a level**, and the literal 10 is the check: read through
	# `Rules.FORCE_PER_LEVEL` this passes at every value, 0 included — a level that pays nothing.
	t.eq(w.swarm.force[0], force_before + 10, "레벨은 호스트의 힘을 10 올린다")
	t.eq(w.swarm.count, 1, "레벨이 무리를 늘리지는 않는다 — 몸은 F로만 늘어난다")

	# The two split cards are deleted, so `roll()` now draws three from one pool and the only guarantee
	# left is that they are three DIFFERENT cards.
	var distinct := {}
	for card in w.offer:
		distinct[card] = true
	t.eq(distinct.size(), 3, "제시된 카드 셋은 서로 다르다")

	# **The cost RISES, and nothing measured that.** `LEVEL_COST_GROWTH` set to 1.0, or the `pow(...)`
	# factor deleted from `level_cost()`, left every check in the round green — the first level costs the
	# base at any growth value (`pow(g, 0)` is 1), and the later `pending_before >= 2` below is a floor
	# that 2 and 3 both satisfy. A flat cost at the ×10 force scale hands out a level every few seconds by
	# the midgame, and the HUD's progress bar divides by it. Literals, not `pow` restated here.
	t.ok(absf(w.level_cost(0) - 10.0) < 0.01, "첫 레벨은 10이다 (%.3f)" % w.level_cost(0))
	t.ok(absf(w.level_cost(1) - 13.5) < 0.01, "둘째 레벨은 13.5로 오른다 (%.3f)" % w.level_cost(1))
	t.ok(absf(w.level_cost(2) - 18.225) < 0.01, "셋째 레벨은 18.225다 (%.3f)" % w.level_cost(2))
	# The one divisor the bar reads. Level 1 is granted and 10 is already charged, so 6.75 of the next
	# 13.5 is exactly half.
	w.swarm.banked = 10.0 + 6.75
	t.ok(absf(w.level_progress() - 0.5) < 0.001,
			"진행 막대의 분모가 오른 비용이다 — 반쯤 찼다 (%.3f)" % w.level_progress())
	w.swarm.banked = 10.0

	var frozen := w.elapsed
	w.step(DT)
	w.step(DT)
	t.eq(w.elapsed, frozen, "고르기 전에는 세상이 멈춘다")

	t.ok(not w.take_card(Cards.TOUGH + 99), "제시되지 않은 카드는 먹히지 않는다")
	t.eq(w.pending_levels, 1, "빗나간 선택으로 레벨이 사라지지 않는다")

	var before := w.swarm.count
	var picked: int = w.offer[0]
	t.ok(w.take_card(picked), "제시된 카드는 골라진다")
	t.eq(w.pending_levels, 0, "고르면 대기 레벨이 줄어든다")
	t.eq(w.swarm.count, before, "어떤 카드도 분신을 만들어내지 않는다 — 그건 없는 데서 힘을 찍어내는 것이다")

	w.step(DT)
	t.ok(w.elapsed > frozen, "고른 뒤에는 다시 흐른다")

	# -- and the multipliers actually reach behaviour ----------------
	# **Asserting that `take_card` moved a field is not asserting that the field does anything.** Measured:
	# every one of the five `* mul` factors could be deleted from `swarm.gd` with all 91 checks green —
	# six of the eight cards would have been silently inert.
	var m := Swarm.new()
	m.setup(51, Vector2(1000.0, 1000.0))
	m.host_input = Vector2.RIGHT
	m.step(DT)
	var base_walk := m.pos[0].x - 1000.0
	m.host_speed_mul = 2.0
	var mark := m.pos[0].x
	m.step(DT)
	var fast_walk := m.pos[0].x - mark
	t.ok(fast_walk > base_walk * 1.9, "속도 카드가 실제 이동에 반영된다 (%.2f > %.2f)" % [fast_walk, base_walk])

	t.ok(m.try_dash(), "첫 대시")
	m.dash_left = 0.0
	m.dash_cd_mul = 0.0
	m.dash_cd = 0.0
	t.ok(m.try_dash(), "쿨다운 배율이 0이면 곧바로 또 나간다 — 배율이 죽어 있으면 여기서 걸린다")

	var e := Swarm.new()
	e.setup(52, Vector2(1000.0, 1000.0))
	e.host_eat_mul = 0.5
	var f := Food.new()
	f.pos = PackedVector2Array([Vector2(1004.0, 1000.0), Vector2(1006.0, 1000.0)])
	f.alive = PackedInt32Array([1, 1])
	f.timer = PackedFloat32Array([0.0, 0.0])
	f.alive_count = 2
	e.step(DT, f)
	t.eq(e.banked, 1.0, "한 입 먹었다")
	# Half the base period, so the second mouthful lands inside a window the unmultiplied rate cannot hit.
	for _s in int(Rules.EAT_PERIOD_HOST * 0.75 * 60.0):
		e.step(DT, f)
	t.eq(e.banked, 2.0, "먹는 속도 카드가 실제 섭취 주기를 줄인다")

	# -- and now through the shell that has to show it --------------
	var main: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(main)
	await t.pump_frames(2)

	t.ok(main.cards != null and main.cards.is_inside_tree(), "셸이 카드 패널을 실제로 붙였다")
	t.ok(not main.cards.visible, "레벨이 없을 때는 떠 있지 않다")

	# Opened through the real path — the shell's own start_pressed → _start() → Run.start() chain, not a
	# private starter called directly. Calling something else would hide the shell's own `connect()` line,
	# the same failure this file's own header is written about.
	main.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(main.run.phase, Run.Phase.PLAY, "start_pressed로 실제 PLAY에 들어갔다")

	# Guarded, not just asserted: without it, the phase check above can fail and every line after it still
	# runs and crashes on `main.run.world` being null — the failure is real either way, but the crash
	# buries the ONE assertion that actually named the problem under a wall of stderr, and truncates
	# every check below it instead of letting them report their own (unrelated) state honestly.
	if main.run.phase == Run.Phase.PLAY:
		# **The camera and the culling rectangle, which nothing measured.** Blank out `_camera_rect()` and
		# every food spot, clone and predator fails `view_rect.has_point()` and stops being drawn — only
		# the host survives, drawn unconditionally — while the camera sits at the spawn point forever. 91
		# checks stayed green through exactly that.
		t.ok(main.view.view_rect.has_point(main.run.world.swarm.pos[0]),
				"카메라가 보는 사각형이 호스트를 담고 있다 — 비면 화면에서 전부 사라진다")
		var cam_start: Vector2 = main.cam.position
		main.run.world.swarm.pos[0] += Vector2(600.0, 0.0)
		# **Fixed simulated steps, not `pump_frames`.** `_follow_camera`'s lerp reads real wall-clock
		# `delta` from whatever the engine measured between pumped frames, and `_camera_rect()`'s half-rect
		# is shrinking through the same delta via `_apply_zoom` at the same time — measured across 8 trials,
		# the margin between "caught up enough" and "still outside" was 30-48px on a ~485px quantity, under
		# 10%, and a busier machine crosses it. Calling `_process()` directly with a known `1/60` each time
		# makes the outcome depend only on the maths, never on how fast this machine happened to run.
		for _s in 40:
			main._process(1.0 / 60.0)
		t.ok(main.cam.position.x > cam_start.x + 5.0, "카메라가 호스트를 따라간다")
		t.ok(main.view.view_rect.has_point(main.run.world.swarm.pos[0]), "따라간 뒤에도 호스트를 담는다")

		main.run.world.swarm.banked = 30.0
		await t.pump_frames(3)
		t.ok(main.cards.visible, "레벨업하면 카드 창이 화면에 뜬다")
		t.eq(main.cards.offer.size(), 3, "패널이 든 카드도 셋이다")

		# **`visible` was not enough.** The panel came up in the top-left corner on the first play, because
		# a Control added to a bare CanvasLayer keeps `size == (0, 0)` unless the preset sets offsets too —
		# and every card rectangle is computed from `size`. Visible, wired, and in the wrong place.
		var screen: Vector2 = main.get_viewport().get_visible_rect().size
		t.eq(main.cards.size, screen, "카드 패널이 화면 전체 크기를 갖는다")
		t.ok(main.hud.size == screen, "HUD 도 화면 전체 크기를 갖는다")
		var first: Rect2 = main.cards._rect_of(0)
		var last: Rect2 = main.cards._rect_of(2)
		t.ok(first.position.x > 0.0 and last.end.x < screen.x, "카드 셋이 화면 안에 들어 있다")
		t.ok(absf((first.position.x + last.end.x) * 0.5 - screen.x * 0.5) < 1.0, "카드가 가운데 놓인다")

		# **The shell half.** No card grows the swarm any more, so what proves
		# `picked` → `_on_card_picked` → `take_card` reaches the simulation is the level being spent.
		# Left unasserted, the signal could be disconnected outright and every check above — all of them
		# driving `World` directly — would stay green.
		var pending_before: int = main.run.world.pending_levels
		t.ok(pending_before >= 2, "설정: 아직 고를 레벨이 둘 이상 남아 있다 (%d)" % pending_before)
		main.cards.picked.emit(main.run.world.offer[0])
		await t.pump_frames(2)
		t.eq(main.run.world.pending_levels, pending_before - 1,
				"패널에서 고른 것이 실제 시뮬레이션의 레벨을 하나 썼다")
		t.ok(main.cards.visible, "남은 레벨이 있으면 창은 계속 떠 있다")

		while main.run.world.pending_levels > 0:
			main.cards.picked.emit(main.run.world.offer[0])
			await t.pump_frames(1)
		await t.pump_frames(2)
		t.ok(not main.cards.visible, "다 고르면 창이 닫힌다")

	t.root.remove_child(main)
	main.queue_free()
