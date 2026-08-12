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

	# -- and now through the shell that has to show it --------------
	var main: Node = load("res://src/shell/main.gd").new()
	t.root.add_child(main)
	await t.pump_frames(2)

	t.ok(main.cards != null and main.cards.is_inside_tree(), "셸이 카드 패널을 실제로 붙였다")
	t.ok(not main.cards.visible, "레벨이 없을 때는 떠 있지 않다")

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
