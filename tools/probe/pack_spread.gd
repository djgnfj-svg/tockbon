extends SceneTree
## **How spread out is a landed group while it crosses the island?** 티켓 19, 2026-08-25.
##
## The user, watching a fight: ***"좀더 배드노스 같이 합쳐져야할듯"***. There IS a pack-cohesion
## mechanism in the sim (`Rules.SPECIES_PACK` — a wolf looks for its target from the centre of mass of
## its own kind within 6 tiles), and **nobody has ever measured whether it does anything.**
##
## ⚠⚠ **`how-nets-lie` records why that matters**: the check labelled 「무리가 한 덩어리로
## 움직인다」 was measured on a board with ONE enemy, where every point gives the same answer, and it
## **passed to the same decimal with the pack radius forced to zero.** So this probe exists to answer
## the question that check never asked.
##
## It reports NUMBERS and judges nothing:
##   · spread — mean distance of each ashore body from the group's centre, sampled over the crossing
##   · widest — the largest distance between any two ashore bodies
##   · touching — what share of bodies have another body within one tile
##
## To compare pack-on against pack-off, edit `Rules.SPECIES_PACK`'s radius and run it again — a `const`
## Array cannot be changed from here, and pretending otherwise is how a probe measures nothing.
##
## Run:
##   Godot_v*.exe --headless --path <project> --script res://tools/probe/pack_spread.gd

const DT := 0.05
const MAX_STEPS := 4000
const SAMPLE_EVERY := 5          # 0.25 s
const ISLAND := 4
const SEEDS := [1, 7, 99]


func _initialize() -> void:
	print("[무리] 상륙한 무리가 섬을 건너는 동안 얼마나 흩어져 있나")
	print("  무리 반경(늑대) %.1f 타일 · 몸 그림 폭 %.1f px · 한 칸 %.0f px"
			% [Rules.pack_radius_of(Rules.WOLF),
				Look.sprite_half_px(Rules.WOLF) * 2.0, Look.TILE_PX])
	print("  ⇒ 두 몸의 중심이 %.3f 타일보다 가까우면 그림이 겹친다"
			% (Look.sprite_half_px(Rules.WOLF) * 2.0 / Look.TILE_PX))
	print("")
	for s in SEEDS:
		_one(int(s))
	print("")
	print("[무리] 끝.")
	quit(0)


func _one(seed: int) -> void:
	var run := Run.new()
	run.seed_cards(seed)
	if run.state() == Run.State.PICK:
		run.take_card(0)
	if not run.enter_node(0):
		print("  [!!] 섬을 못 열었다")
		return
	var battle := run.begin_island()
	var names := []
	for i in battle.army.type_id.size():
		names.append(Rules.name_of(int(battle.army.type_id[i])))

	# One landing tile for everybody, so what is measured is the group coming apart rather than the
	# plan spreading it out on purpose.
	var tile := -1
	for t in battle.grid.passable.size():
		if battle.grid.home_harbour_for(t) >= 0:
			tile = t
			break
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			battle.send(i, tile)
	battle.commit()

	var spread_sum := 0.0
	var widest_sum := 0.0
	var touch_sum := 0.0
	var widest_ever := 0.0
	var tgt_sum := 0.0
	var face_split := 0.0
	var samples := 0
	var steps := 0
	while steps < MAX_STEPS and battle.outcome() == Battle.Outcome.RUNNING:
		battle.begin_frame()
		battle.step(DT)
		steps += 1
		if steps % SAMPLE_EVERY != 0:
			continue
		var here := []
		for i in battle.soldier_state.size():
			if battle.soldier_state[i] == Battle.SoldierState.ASHORE:
				here.append(battle.soldier_pos[i])
		# Under three ashore there is no group to be spread out, and averaging those in would drag
		# every number toward zero at both ends of the fight.
		if here.size() < 3:
			continue
		var centre := Vector2.ZERO
		for raw in here:
			centre += raw as Vector2
		centre /= float(here.size())
		var spread := 0.0
		for raw2 in here:
			spread += (raw2 as Vector2).distance_to(centre)
		spread /= float(here.size())
		var widest := 0.0
		var touching := 0
		for a in here.size():
			var near := false
			for b in here.size():
				if a == b:
					continue
				var d: float = (here[a] as Vector2).distance_to(here[b] as Vector2)
				widest = maxf(widest, d)
				if d <= 1.0 + Rules.EPS:
					near = true
			if near:
				touching += 1
		# ⚠ **How many different things the group is doing** — the other candidate for 「scattered」.
		# Position spread says the bodies are close; this says whether they are one unit or fourteen
		# individuals standing near each other.
		var targets := {}
		var facings := {}
		for i in battle.soldier_state.size():
			if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
				continue
			var tg := int(battle.soldier_target[i])
			targets[tg] = true
			if tg >= 0:
				var d: Vector2 = battle.enemy_pos[tg] - battle.soldier_pos[i]
				facings["r" if d.x >= 0.0 else "l"] = true
		tgt_sum += float(targets.size())
		face_split += 1.0 if facings.size() > 1 else 0.0
		spread_sum += spread
		widest_sum += widest
		touch_sum += float(touching) / float(here.size())
		widest_ever = maxf(widest_ever, widest)
		samples += 1

	if samples == 0:
		print("  씨앗 %d — 잰 표본이 없다" % seed)
		return
	print("  씨앗 %d · %d명 %s" % [seed, names.size(), str(names)])
	print("    흩어짐(중심까지 평균) %.2f 타일 · 제일 먼 두 몸 평균 %.2f · 최대 %.2f · 한 칸 안에 짝이 있는 몸 %.0f%%"
			% [spread_sum / float(samples), widest_sum / float(samples), widest_ever,
				touch_sum / float(samples) * 100.0])
	print("    서로 다른 표적 수 평균 %.1f개 · 좌우가 갈린 표본 %.0f%%"
			% [tgt_sum / float(samples), face_split / float(samples) * 100.0])
	print("    판정 %s · %.1fs · 표본 %d개"
			% ["승" if battle.outcome() == Battle.Outcome.WON else str(battle.outcome()),
				float(steps) * DT, samples])
