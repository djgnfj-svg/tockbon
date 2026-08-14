extends RefCounted
## The level-up pick, driven through the real shell.
##
## ⚠ **The failure this net is built around is a panel that never becomes visible.** `CLAUDE.md` measured
## exactly that shipping under 5,576 green checks. So the panel is not constructed here — the shell's own
## `_ready()` builds it, and the assertions are on `visible` at both edges. **Wiring it by hand in the net
## would hide the line that wires it in the game**: delete the shell's `add_child(cards)` and a
## hand-wired net stays green while the player sees nothing.
##
## ⚠ **The freeze is now conditional and that is check 14.** A level with nothing to offer BANKS and the
## world keeps turning — the card pool is empty until the first horse is eaten, which is long after the
## first level, and a guard on `pending_levels` alone freezes six behaviours from the first level of every
## run. **That failure is a frozen game, and it is completely silent in every other check in the round.**
## The freeze that survives is the one with cards actually on screen: a level-up that does not stop the
## world is a notification, and a notification is something you watch happen.
##
## **The five `*_mul` fields the old cards moved are gone**, and so are the checks that drove them. What
## replaced them is not a smaller number — it is a part, and `Body`'s own net is where wearing one is
## measured. Here: that a card can only ever BE a part, that taking one consumes a level, and that force
## moves by the part and by nothing else.

const DT := 1.0 / 60.0

## Every field the level-up cards used to move on `Swarm`. Asserted per name against the instance's own
## property list — a count of five survives deleting one and adding another.
const DEAD_MULS := ["host_speed_mul", "host_eat_mul", "clone_eat_mul", "sense_mul", "dash_cd_mul"]


## The card face is the one thing about this panel worth asserting by value, and it has to reach the
## SCREEN: `face_of()` asserted as a pure function is a function nobody has to call.
class CardSpy extends CardPanel:
	var texts: Array[String] = []

	func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
		texts.append(text)
		super._paint_text(c, p, text, font_size, col)


## The real wiring runs first and unmodified — `super._ready()` is `main.gd`'s own, building and parenting
## the real `CardPanel` exactly as the game does. Only afterwards is a spy swapped onto the same parent.
##
## ⚠ **The `picked` connections are COPIED off the real panel, never re-made here.** Written as
## `card_spy.picked.connect(_on_card_picked)` this class supplies the very wire it is watching, and
## `main.gd`'s own `cards.picked.connect(...)` line could be replaced with `pass` with the round green.
class MainSpy extends "res://src/shell/main.gd":
	var card_spy: CardSpy = null

	func _ready() -> void:
		super._ready()
		var layer := cards.get_parent()
		card_spy = CardSpy.new()
		for con: Dictionary in cards.picked.get_connections():
			card_spy.picked.connect(con["callable"] as Callable)
		layer.remove_child(cards)
		cards.queue_free()
		layer.add_child(card_spy)
		cards = card_spy


func run(t) -> void:
	_c14_levels_bank(t)
	_c_no_healing(t)
	_c8_pool(t)
	_c_cost(t)
	_c10_take(t)
	_c9_only_parts(t)
	await _shell(t)


# -- 14: a level with nothing to offer BANKS, and the world keeps running -------------------------------
## *Mutation: keep `World::step()`'s unconditional `pending_levels` guard.* **This one freezes the game**,
## from the first level of every run, and nothing else in the round can see it — `swarm.step`, `food.step`,
## `_step_critters`, `_grow`, `host_grace` and the critter timer all sit behind those two lines.
func _c14_levels_bank(t) -> void:
	var w := World.new()
	w.setup(6)
	_silence(w)
	t.eq(w.pending_levels, 0, "시작할 때는 고를 게 없다")
	t.ok(w.species_eaten.is_empty(), "설정: 아직 아무 종도 먹지 않았다 — 카드 풀은 비어 있다")
	t.eq(w.host_hp, 3, "설정: 체력은 3으로 연다")

	# 45 covers three levels exactly: 10 + 13.5 + 18.225 = 41.725, and the fourth costs 24.6 more.
	w.swarm.banked = 45.0
	var e0 := w.elapsed
	for _s in 60:
		w.step(DT)
	t.eq(w.pending_levels, 3, "고를 수 없는 레벨은 쌓인다 — 셋이 밀려 있다")
	t.ok(w.offer.is_empty(), "그동안 카드는 한 장도 뜨지 않는다")
	t.ok(absf(w.elapsed - (e0 + 60.0 * DT)) < 0.001,
			"그리고 세상은 60프레임 내내 멈추지 않고 흘렀다 (%.4f / 1.0000)" % w.elapsed)
	# A level raises the CURRENT hearts too — `질긴 껍질` was the only thing that ever did, and it is gone.
	# Without this line `hp_max()` climbs while the row stays as full as it was, which reads as decoration.
	t.eq(w.host_hp, 6, "레벨 셋이 현재 체력도 셋 올린다 (3 → 6)")
	t.eq(w.body.hp_max(w.level), 6, "그리고 최대 체력도 6이다 — 둘이 같이 움직인다")

	# The moment the pool opens, the whole stack arrives at once. That cascade is the rhythm, and it is
	# also what proves the banking above was not simply a level that got lost.
	w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
	w.step(DT)
	t.eq(w.offer.size(), 3, "말을 먹은 순간 밀려 있던 카드가 한꺼번에 깔린다")
	t.eq(w.pending_levels, 3, "쌓인 레벨은 그대로 셋이다 — 못 쓴 레벨이 사라지지 않았다")

	# And NOW the world stops, because there is something on screen to answer.
	var frozen := w.elapsed
	w.step(DT)
	w.step(DT)
	t.eq(w.elapsed, frozen, "카드가 실제로 떠 있을 때는 세상이 멈춘다")


# -- there is no healing in this plan, and both places that could be one are DAMAGED here ---------------
## ⚠ **"Raising the maximum raises the current by the same amount, and there is no other source of
## healing" is written in the plan and in `world.gd`'s own comment, and nothing measured it.** Every check
## that reads `host_hp` after a level or a card grants it from FULL health — `_c14_levels_bank` levels a
## 3/3 host and `_c10_take` runs at 6/6 — so `host_hp += HP_PER_LEVEL` replaced by `host_hp =
## hp_max(level)` is arithmetically indistinguishable, and both sites measured green at 811. In play a
## host at one heart crosses a level threshold and is silently restored to full: the entire cost of taking
## a hit evaporates. **So the host is damaged first, which is the only state that can tell them apart.**
func _c_no_healing(t) -> void:
	var w := World.new()
	w.setup(66)
	_silence(w)
	w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
	w.host_hp = 1                       ## one heart left, and it stays lost
	w.swarm.banked = 45.0               ## three levels' worth: 10 + 13.5 + 18.225
	w.step(DT)
	t.eq(w.pending_levels, 3, "설정: 레벨 셋이 한꺼번에 올랐다")
	t.eq(w.body.hp_max(w.level), 6, "설정: 그래서 최대 체력은 6이다")
	t.eq(w.host_hp, 4, "다친 몸은 레벨만큼만 오른다 — 1에서 정확히 셋 올라 4다 (6으로 채워지지 않는다)")

	# The other site: `take_card` moves the current hearts by the DIFFERENCE in `hp_max()`, not to it.
	w.offer = PackedInt32Array([Parts.HORSE_MANE])
	t.ok(w.take_card(Parts.HORSE_MANE), "설정: 말 갈기를 골랐다")
	t.eq(w.body.hp_max(w.level), 7, "설정: 갈기가 최대를 7로 올렸다")
	t.eq(w.host_hp, 5, "카드도 차이만큼만 올린다 — 4에서 하나 올라 5다 (7로 채워지지 않는다)")

	# And a card worth no HP moves nothing at all, which is what says the line above is a difference and
	# not "any card heals a bit".
	w.offer = PackedInt32Array([Parts.HORSE_LUNG])
	t.ok(w.take_card(Parts.HORSE_LUNG), "설정: 체력을 안 주는 부품도 골랐다")
	t.eq(w.host_hp, 5, "체력을 안 주는 카드는 현재 체력도 건드리지 않는다 — 여전히 5다")


# -- 8: the pool is what has been eaten -----------------------------------------------------------------
## *Mutation: roll from the whole table regardless of what was eaten.*
func _c8_pool(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var none := Cards.roll(rng, PackedInt32Array())
	t.eq(none.size(), 0, "아무것도 안 먹었으면 카드는 한 장도 없다 — 0으로 나누지도 않는다")

	# Eating the WRONG species is the half that separates "the pool is locked" from "the pool is empty
	# until something, anything, is eaten". No crow part exists in the August table.
	var crow := Cards.roll(rng, PackedInt32Array([Parts.Species.CROW]))
	t.eq(crow.size(), 0, "까마귀만 먹었으면 아직 낼 부품이 없다 — 자물쇠는 '무엇을' 먹었느냐다")

	var horse := Cards.roll(rng, PackedInt32Array([Parts.Species.HORSE]))
	t.eq(horse.size(), 3, "말을 먹었으면 셋이 나온다")
	var distinct := {}
	for card in horse:
		distinct[card] = true
		t.eq(int(Parts.SPECIES[card]), Parts.Species.HORSE, "뜬 카드가 말의 부품이다 (%s)"
				% str(Parts.NAME[card]))
	t.eq(distinct.size(), 3, "제시된 카드 셋은 서로 다르다 — 같은 것을 두 번 뽑지 않는다")
	t.ok(not horse.has(Parts.BITE) and not horse.has(Parts.DASH),
			"손에 쥐여준 둘(물기·짧은 숨)은 카드로 나오지 않는다")

	# Ten rolls, because "three distinct" from a pool of exactly three is satisfied by any implementation
	# that returns the whole pool; what this pins is that it never reaches outside it, whatever the RNG did.
	var drawn := 0
	var off_species := 0
	for s in 10:
		rng.seed = 800 + s
		for card in Cards.roll(rng, PackedInt32Array([Parts.Species.HORSE])):
			drawn += 1
			if int(Parts.SPECIES[card]) != Parts.Species.HORSE:
				off_species += 1
	t.eq(drawn, 30, "열 번을 굴리면 서른 장이 나온다 (한 번도 안 굴린 채 통과하지 않는다)")
	t.eq(off_species, 0, "그 서른 장 중 말의 것이 아닌 카드는 하나도 없다")


# -- the cost rises, and the bar divides by the risen one ----------------------------------------------
## Literals, never `pow(...)` restated here: the first level costs the base at ANY growth value
## (`pow(g, 0)` is 1), so the opening level alone cannot see a flat cost.
func _c_cost(t) -> void:
	var w := World.new()
	w.setup(61)
	_silence(w)
	w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
	var force_before: int = w.swarm.force[0]
	w.swarm.banked = 10.0
	w.step(DT)
	t.eq(w.pending_levels, 1, "은행이 한 칸 차면 레벨이 하나 생긴다")
	t.eq(w.offer.size(), 3, "카드는 셋이다")
	t.eq(w.swarm.force[0], force_before + 10, "레벨은 호스트의 힘을 10 올린다")
	t.eq(w.swarm.count, 1, "레벨이 무리를 늘리지는 않는다 — 몸은 F로만 늘어난다")

	t.ok(absf(w.level_cost(0) - 10.0) < 0.01, "첫 레벨은 10이다 (%.3f)" % w.level_cost(0))
	t.ok(absf(w.level_cost(1) - 13.5) < 0.01, "둘째 레벨은 13.5로 오른다 (%.3f)" % w.level_cost(1))
	t.ok(absf(w.level_cost(2) - 18.225) < 0.01, "셋째 레벨은 18.225다 (%.3f)" % w.level_cost(2))
	# The one divisor the HUD bar reads. Level 1 is granted and 10 is already charged, so 6.75 of the next
	# 13.5 is exactly half.
	w.swarm.banked = 10.0 + 6.75
	t.ok(absf(w.level_progress() - 0.5) < 0.001,
			"진행 막대의 분모가 오른 비용이다 — 반쯤 찼다 (%.3f)" % w.level_progress())


# -- 10: taking a card consumes a level and moves force by the PART and nothing else --------------------
## *Mutation: return true without decrementing `pending_levels`.* A/B on count and force catches
## "diverged", never "the card was never taken" — so the level and the offer are asserted to have moved.
func _c10_take(t) -> void:
	var w := World.new()
	w.setup(10)
	_silence(w)
	w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
	w.swarm.banked = 45.0
	for _s in 4:
		w.step(DT)
	t.eq(w.pending_levels, 3, "설정: 고를 레벨이 셋 밀려 있다")

	# The offer is pinned rather than rolled, so the force literal below names one part and not whichever
	# card the RNG happened to deal.
	w.offer = PackedInt32Array([Parts.HORSE_LEGS])
	t.ok(not w.take_card(Parts.HORSE_LUNG), "제시되지 않은 카드는 먹히지 않는다")
	t.eq(w.pending_levels, 3, "빗나간 선택으로 레벨이 사라지지 않는다")
	t.eq(w.body.slot_part[Parts.Slot.LUNG], -1, "그리고 몸에 붙지도 않는다")

	var count_before: int = w.swarm.count
	var force_before: int = w.swarm.force[0]
	var hp_before: int = w.host_hp
	t.ok(w.take_card(Parts.HORSE_LEGS), "제시된 카드는 골라진다")
	t.eq(w.pending_levels, 2, "대기 레벨이 하나 줄었다 — 카드가 실제로 쓰였다")
	t.ok(not w.offer.is_empty(), "아직 남은 레벨이 있으니 다음 셋이 깔린다")
	t.eq(w.swarm.count, count_before, "어떤 카드도 분신을 만들어내지 않는다 — 없는 데서 힘을 찍어내는 것이다")
	t.eq(w.swarm.force[0], force_before + 5, "힘은 준 부품의 값 5만큼만 움직인다 (리터럴)")
	t.eq(w.body.slot_part[Parts.Slot.HINDLIMBS], Parts.HORSE_LEGS, "그리고 그 부품이 실제로 몸에 붙었다")
	t.eq(w.host_hp, hp_before, "힘만 주는 부품은 체력을 건드리지 않는다")

	# A part worth no force must move no force. Read through `Parts.FORCE[card]` this and the line above
	# are the same check twice; as two literals, 5 and 0, they are not.
	w.offer = PackedInt32Array([Parts.HORSE_LUNG])
	var force_mid: int = w.swarm.force[0]
	t.ok(w.take_card(Parts.HORSE_LUNG), "힘 0짜리 부품도 골라진다")
	t.eq(w.swarm.force[0], force_mid, "그리고 힘은 한 톨도 움직이지 않는다")
	t.eq(w.pending_levels, 1, "그래도 레벨은 하나 쓰였다")

	# The mane raises the ceiling, so the current hearts follow it up.
	w.offer = PackedInt32Array([Parts.HORSE_MANE])
	var hp_mid: int = w.host_hp
	t.ok(w.take_card(Parts.HORSE_MANE), "말 갈기를 고른다")
	t.eq(w.host_hp, hp_mid + 1, "최대가 오르면 현재 체력도 같이 오른다 (치유는 이 계획에 없다)")
	t.eq(w.pending_levels, 0, "마지막 레벨까지 다 썼다")
	t.ok(w.offer.is_empty(), "다 고르면 제시가 비워진다")

	var flowing := w.elapsed
	w.step(DT)
	t.ok(w.elapsed > flowing, "고른 뒤에는 다시 흐른다")


# -- 9: a card is a PART, and the multipliers it replaced are gone --------------------------------------
## *Mutation: leave one `*_mul` field on `Swarm`.* Asserted per name, not as a count — a count of five
## survives deleting one and adding another.
func _c9_only_parts(t) -> void:
	var w := World.new()
	w.setup(9)
	_silence(w)
	w.species_eaten = PackedInt32Array([Parts.Species.HORSE])
	w.swarm.banked = 30.0
	for _s in 4:
		w.step(DT)
	t.ok(w.offer.size() > 0, "설정: 카드가 실제로 깔렸다")
	for card in w.offer:
		t.ok(card >= 0 and card < Parts.NAME.size(),
				"제시된 id가 전부 부품 표 안에서 풀린다 (%d)" % card)

	var sw := Swarm.new()
	var names := {}
	for p: Dictionary in sw.get_property_list():
		names[str(p["name"])] = true
	t.ok(names.has("force"), "설정: 속성 목록을 실제로 읽었다 — 비면 아래가 저절로 통과한다")
	for gone: String in DEAD_MULS:
		t.ok(not names.has(gone), "Swarm에 %s가 남아 있지 않다" % gone)
	t.ok(names.has("active_speed_mul"),
			"대신 갤럽이 쓰는 배율 하나만 남아 있다 — 배율이 전부 사라진 것은 아니다")

	# The card tables themselves. `card_panel.gd` read `Cards.TITLE`/`DESC` and the face is `Parts.NAME`
	# now; a table left behind is a second owner of the same string.
	var cards_consts: Dictionary = load("res://src/sim/cards.gd").get_script_constant_map()
	var rules_consts: Dictionary = load("res://src/sim/rules.gd").get_script_constant_map()
	t.ok(rules_consts.has("HOST_SPEED"), "설정: 상수 목록을 읽는 방법 자체가 동작한다")
	t.ok(not cards_consts.has("TITLE") and not cards_consts.has("DESC")
			and not cards_consts.has("REST"),
			"cards.gd에 카드 표(TITLE·DESC·REST)가 남아 있지 않다")


# -- through the shell that has to show it --------------------------------------------------------------
func _shell(t) -> void:
	var main := MainSpy.new()
	t.root.add_child(main)
	await t.pump_frames(2)

	t.ok(main.cards != null and main.cards.is_inside_tree(), "셸이 카드 패널을 실제로 붙였다")
	t.ok(not main.cards.visible, "레벨이 없을 때는 떠 있지 않다")

	# Opened through the real path — the shell's own start_pressed → _start() → Run.start() chain, not a
	# private starter called directly. Calling something else would hide the shell's own `connect()` line.
	main.title.start_pressed.emit()
	await t.pump_frames(1)
	t.eq(main.run.phase, Run.Phase.PLAY, "start_pressed로 실제 PLAY에 들어갔다")

	# Guarded, not just asserted: without it, the phase check above can fail and every line after it still
	# runs and crashes on `main.run.world` being null — burying the ONE assertion that named the problem.
	if main.run.phase == Run.Phase.PLAY:
		# **The card panel needs the body to say what LEVEL a card would be**, and that is one line in
		# `_bind_world()`. By identity, not by field: two different `Body`s start alike.
		t.ok(main.cards.body == main.run.world.body,
				"카드 패널이 이 런의 몸을 가리키고 있다 (같은 인스턴스)")

		# **The camera and the culling rectangle, which nothing measured.** Blank out `_camera_rect()` and
		# every food spot, clone and critter fails `view_rect.has_point()` and stops being drawn, while the
		# camera sits at the spawn point forever.
		t.ok(main.view.view_rect.has_point(main.run.world.swarm.pos[0]),
				"카메라가 보는 사각형이 호스트를 담고 있다 — 비면 화면에서 전부 사라진다")
		var cam_start: Vector2 = main.cam.position
		main.run.world.swarm.pos[0] += Vector2(600.0, 0.0)
		# **Fixed simulated steps, not `pump_frames`.** `_follow_camera`'s lerp reads real wall-clock
		# `delta`, and `_camera_rect()`'s half-rect shrinks through the same delta at the same time —
		# measured, the margin between "caught up" and "still outside" was under 10% and a busier machine
		# crosses it. A known 1/60 each time makes the outcome depend only on the maths.
		for _s in 40:
			main._process(1.0 / 60.0)
		t.ok(main.cam.position.x > cam_start.x + 5.0, "카메라가 호스트를 따라간다")
		t.ok(main.view.view_rect.has_point(main.run.world.swarm.pos[0]), "따라간 뒤에도 호스트를 담는다")

		# **The pool has to be opened by hand: nothing in plan 3 writes `species_eaten`.** Corpses are
		# plan 4's, so through this whole plan a real run banks levels forever and no card ever appears.
		# That is reported, not worked around — but the panel still has to be proven to open.
		main.run.world.species_eaten = PackedInt32Array([Parts.Species.HORSE])
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

		# **The face, captured off the leaf.** A card names a part and nothing else; the level suffix is
		# the promise the pick is making, and it is the only place a level says what it is worth on screen.
		main.card_spy.texts.clear()
		main.cards.queue_redraw()
		await t.pump_frames(1)
		var named := 0
		for p in main.cards.offer:
			if main.card_spy.texts.has(str(Parts.NAME[p])):
				named += 1
		t.eq(named, main.cards.offer.size(), "깔린 카드가 저마다 제 부품 이름을 적는다 %s"
				% str(main.card_spy.texts))
		t.ok(not _has_line(main.card_spy.texts, "Lv"),
				"아직 입지 않은 부품에는 레벨 꼬리표가 붙지 않는다")

		# **The shell half.** No card grows the swarm any more, so what proves
		# `picked` → `_on_card_picked` → `take_card` reaches the simulation is the level being spent.
		var pending_before: int = main.run.world.pending_levels
		t.ok(pending_before >= 2, "설정: 아직 고를 레벨이 둘 이상 남아 있다 (%d)" % pending_before)
		main.cards.picked.emit(Parts.HORSE_LEGS if main.run.world.offer.has(Parts.HORSE_LEGS)
				else main.run.world.offer[0])
		await t.pump_frames(2)
		t.eq(main.run.world.pending_levels, pending_before - 1,
				"패널에서 고른 것이 실제 시뮬레이션의 레벨을 하나 썼다")
		t.ok(main.cards.visible, "남은 레벨이 있으면 창은 계속 떠 있다")

		# And now a worn part's card says what it would BECOME. `part_level + 1`, not the level it is —
		# printing the current level reads as "you already have this" on the one card worth taking twice.
		var worn := -1
		for s in main.run.world.body.slot_part.size():
			if main.run.world.body.slot_part[s] >= 0:
				worn = main.run.world.body.slot_part[s]
		t.ok(worn >= 0, "설정: 고른 부품이 실제로 몸에 붙었다")
		if worn >= 0:
			t.eq(main.cards.face_of(worn), "%s → Lv2" % str(Parts.NAME[worn]),
					"이미 입은 부품의 카드는 → Lv2라고 적는다")
			main.cards.show_offer(PackedInt32Array([worn]))
			main.card_spy.texts.clear()
			await t.pump_frames(1)
			t.ok(_has_line(main.card_spy.texts, "→ Lv2"),
					"그리고 그 문구가 실제로 화면에 그려진다 %s" % str(main.card_spy.texts))
			main.cards.show_offer(main.run.world.offer)
			await t.pump_frames(1)

		# ⚠ **Bounded.** Written as a bare `while pending_levels > 0`, an empty offer makes `offer[0]` an
		# out-of-bounds read, `take_card` returns false, the level never decrements — and the net does not
		# go red, it spins forever. Neither the runner nor the wrapper has a per-net timeout.
		var guard := 0
		while main.run.world.pending_levels > 0 and guard < 20:
			guard += 1
			if main.run.world.offer.is_empty():
				break
			main.cards.picked.emit(main.run.world.offer[0])
			await t.pump_frames(1)
		t.ok(guard < 20, "남은 카드를 스무 번 안에 다 골랐다 — 빈 제시로 영원히 돌지 않는다 (%d)" % guard)
		await t.pump_frames(2)
		t.ok(not main.cards.visible, "다 고르면 창이 닫힌다")

	t.root.remove_child(main)
	main.queue_free()


func _has_line(lines: Array, needle: String) -> bool:
	for l: String in lines:
		if l.contains(needle):
			return true
	return false


## Food and critters off, and the spots' cooldowns pinned high so respawn cannot quietly feed the host
## mid-check — every level count below is a literal.
func _silence(w: World) -> void:
	w.critter_count = 0
	for i in w.food.alive.size():
		w.food.alive[i] = 0
		w.food.timer[i] = 999.0
	w.food.alive_count = 0
