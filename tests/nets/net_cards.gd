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

	# A pinned literal, not `Rules.SPLIT_PER_BANKED`: reading the constant through the thing it gates makes
	# the check scale with it, and the threshold could be moved to 1000 with this net still green.
	w.swarm.banked = 10.0
	w.step(DT)
	t.eq(w.pending_levels, 1, "은행이 한 칸 차면 레벨이 하나 생긴다")
	t.eq(w.offer.size(), 3, "카드는 셋이다")

	var splits := 0
	for card in w.offer:
		if card == Cards.SPLIT_1 or card == Cards.SPLIT_3:
			splits += 1
	t.ok(splits >= 1, "셋 중 하나는 반드시 무리를 늘린다 — 안 그러면 실험의 변수가 사라진다")

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
	if picked == Cards.SPLIT_1:
		t.eq(w.swarm.count, before + 1, "분열 카드는 분신을 하나 늘린다")
	else:
		t.eq(w.swarm.count, before + 3, "삼중 분열 카드는 셋을 늘린다")

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

	# **The camera and the culling rectangle, which nothing measured.** Blank out `_camera_rect()` and
	# every food spot, clone and predator fails `view_rect.has_point()` and stops being drawn — only the
	# host survives, drawn unconditionally — while the camera sits at the spawn point forever. 91 checks
	# stayed green through exactly that.
	t.ok(main.view.view_rect.has_point(main.world.swarm.pos[0]),
			"카메라가 보는 사각형이 호스트를 담고 있다 — 비면 화면에서 전부 사라진다")
	var cam_start: Vector2 = main.cam.position
	main.world.swarm.pos[0] += Vector2(600.0, 0.0)
	await t.pump_frames(6)
	t.ok(main.cam.position.x > cam_start.x + 5.0, "카메라가 호스트를 따라간다")
	t.ok(main.view.view_rect.has_point(main.world.swarm.pos[0]), "따라간 뒤에도 호스트를 담는다")

	main.world.swarm.banked = 30.0
	await t.pump_frames(3)
	t.ok(main.cards.visible, "레벨업하면 카드 창이 화면에 뜬다")
	t.eq(main.cards.offer.size(), 3, "패널이 든 카드도 셋이다")

	var shell_before: int = main.world.swarm.count
	var shell_pick: int = main.world.offer[0]
	main.cards.picked.emit(shell_pick)
	await t.pump_frames(2)
	t.ok(main.world.swarm.count > shell_before, "패널에서 고른 것이 실제 무리를 늘렸다")
	t.ok(main.cards.visible, "남은 레벨이 있으면 창은 계속 떠 있다")

	while main.world.pending_levels > 0:
		main.cards.picked.emit(main.world.offer[0])
		await t.pump_frames(1)
	await t.pump_frames(2)
	t.ok(not main.cards.visible, "다 고르면 창이 닫힌다")

	t.root.remove_child(main)
	main.queue_free()
