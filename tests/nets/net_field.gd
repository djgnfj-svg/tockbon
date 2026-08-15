extends RefCounted
## The creature table: what is on the field at `t = 0`, what a spawn writes, what a removal carries down,
## and the two axes that replaced `threat`.
##
## **The shape this file exists for is the flat-table swap.** `_remove_critter()` moves the last row down
## over the dead one; a column it does not know about lands a stranger's number on a survivor with no error
## and nothing on screen. It only shows when the row removed is **not** the last one — killing the only
## creature never enters the swap branch and every missing line stays green.
##
## `boss_index` is the seventh thing that removal repairs and it is not a column, so it needs its own
## assertions on **both** halves: the boss dying, and the boss being the last row swapped down over someone
## else. One of them alone leaves an index pointing at a stranger.
##
## Seeds 400–419 are this file's own block, so two nets can never share a world by accident.

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)
const BOSS := int(Parts.Species.BOSS)


func run(t) -> void:
	_c1_opening_field(t)
	_c2_spawn_writes_every_column(t)
	_c3_removal_swap(t)
	_c4_disposition(t)
	_c5_the_horse_flees_a_clone(t)
	_c21_drop_rate(t)
	_u7a_only_droppable_parts_roll(t)
	_u7b_a_swap_cannot_drop_a_clone_below_the_floor(t)
	_c29_instruments(t)
	_c30_size_never_inverts(t)
	_f1b_a_crow_does_not_one_shot(t)
	_f2_boss_placement(t)
	_u12_where_the_boss_opens(t)
	_f2b_the_boss_dies(t)
	_f3_nothing_spawns_in_a_rock(t)
	_f4_spawn_species_roll(t)
	_f5_each_creature_walks_once_per_frame(t)
	_g1_wandering_is_a_column(t)
	_g2_the_lion_is_the_only_hunter(t)
	_g3_a_herd_is_born_together(t)


# -- 1: the field at t = 0 -------------------------------------------------------------------------------
## Counted by species against literals, never against `Rules.CRITTER_START_*` read back — read through the
## constants this check passes at every value including the zero that would open an empty field.
func _c1_opening_field(t) -> void:
	var w := World.new()
	w.setup(400)
	# ⚠ **Seven counters, because the opening is now `SPECIES_START × SPECIES_HERD` and a `match` over three
	# names silently counts a four-species field as three.** The literals below are that product written out
	# per species — a herd count read as a head count is the exact bug this check exists to catch.
	var per := [0, 0, 0, 0, 0, 0, 0]
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		per[s] = int(per[s]) + 1
	t.eq(int(per[CROW]), 8, "런은 까마귀 여덟으로 연다")
	t.eq(int(per[HORSE]), 8, "그리고 말 두 무리 — 네 마리씩 여덟")
	t.eq(int(per[Parts.Species.SQUIRREL]), 6, "다람쥐 세 무리 — 두 마리씩 여섯")
	t.eq(int(per[Parts.Species.ELEPHANT]), 3, "코끼리는 한 무리 셋뿐이다")
	t.eq(int(per[Parts.Species.CHEETAH]), 2, "치타 둘 — 무리를 짓지 않는다")
	t.eq(int(per[Parts.Species.LION]), 4, "사자 두 무리 — 둘씩 넷")
	t.eq(int(per[BOSS]), 1, "보스는 정확히 하나다 — 주기적 스폰은 보스를 굴리지 않는다")
	t.eq(w.critter_count, 32, "합쳐서 서른두 마리다")
	t.ok(w.critter_count < Rules.CRITTER_MAX,
			"그리고 그 서른둘은 상한 아래다 — 상한에 닿으면 이후의 도착은 전부 조용히 무시된다 (%d < %d)"
					% [w.critter_count, Rules.CRITTER_MAX])
	t.ok(w.boss_index >= 0 and int(w.critter_species[w.boss_index]) == BOSS,
			"boss_index가 실제 보스 줄을 가리킨다 (%d)" % w.boss_index)

	# The periodic spawn never rolls the boss, over enough calls that a one-in-three roll could not hide.
	var w2 := World.new()
	w2.setup(401)
	var rolled_boss := 0
	for _n in 60:
		w2.critter_count = 0
		w2.boss_index = -1
		w2._spawn_critter()
		if int(w2.critter_species[0]) == BOSS:
			rolled_boss += 1
	t.eq(rolled_boss, 0, "예순 번을 더 굴려도 두 번째 보스는 나오지 않는다")


# -- 2: `_spawn_at` writes all eight columns ------------------------------------------------------------
## ⚠ **`resize()` zero-fills**, so a dropped line is not an error — it is a creature that walks the field as
## species CROW at force 0 with hp 0, or one whose direction is `Vector2.ZERO` and therefore never wanders
## and is drawn at rotation 0. Every one of the eight is asserted, because "any one of six" left `dir` and
## `counter` uncovered.
func _c2_spawn_writes_every_column(t) -> void:
	var w := World.new()
	w.setup(402)
	_silence_food(w)
	# The opening field is cleared so the row this check reads is the one the TIMER made, not one of the
	# twelve `setup()` placed. `boss_index` goes with it — an index into an emptied table is a stranger.
	w.critter_count = 0
	w.boss_index = -1
	# 20 steps at dt = 1.0 is exactly `CRITTER_INTERVAL`, and the spawn fires on the step that reaches zero.
	# Stepping the real clock rather than calling `_spawn_critter()` by hand is what keeps the timer itself
	# in the check: a spawner nothing ever calls is the same picture as one that writes nothing.
	#
	# ⚠ **An arrival is a HERD, so the count is a range and not 1.** Pinned at 1 this check would red for
	# every species whose `SPECIES_HERD` row is above one — which is four of the six that can be rolled.
	for _s in 20:
		w.step(1.0)
	var s := int(w.critter_species[0])
	t.ok(w.critter_count >= 1 and w.critter_count <= int(Rules.SPECIES_HERD[s]),
			"설정: 20초에 무리 하나가 통째로 들어왔다 (%d마리, %d종의 무리는 %d)"
					% [w.critter_count, s, int(Rules.SPECIES_HERD[s])])
	t.ok(s != BOSS and int(Rules.SPECIES_SPAWN_WEIGHT[s]) > 0,
			"20초에 들어온 것은 가중치가 있는 종이다 — 보스는 굴려지지 않는다 (%d)" % s)
	var lo := int(Rules.SPECIES_FORCE_MIN[s])
	var hi := int(Rules.SPECIES_FORCE_MAX[s])
	var f := int(w.critter_force[0])
	t.ok(f >= lo and f <= hi, "그 힘은 제 종의 범위 안이다 (%d ∈ [%d, %d])" % [f, lo, hi])
	t.eq(int(w.critter_hp[0]), f * 3, "체력은 힘 × 3이다 (리터럴 3) — 0이면 첫 대에 시체가 된다")
	t.eq(int(w.critter_flees[0]), int(Rules.SPECIES_FLEES[s]), "성향은 제 종의 것으로 태어난다")
	t.eq(w.critter_atk_cd[0], 0.0, "공격 시계는 0에서 — 모든 몸과 모든 생물이 준비된 채로 연다")
	t.eq(w.critter_counter[0], 0.0, "반격 시계는 0에서 연다")
	var d: Vector2 = w.critter_dir[0]
	t.ok(absf(d.length() - 1.0) < 0.001,
			"방향은 길이 1짜리 단위 벡터다 — 0이면 영영 안 움직이고 회전 0으로 그려진다 (%.4f)" % d.length())

	# Off camera, never in your lap. Ten seeds, because one spawn landing outside the zone by luck is about
	# a two-in-three coin flip on a single seed.
	var worst := INF
	for n in 10:
		var w3 := World.new()
		w3.setup(403 + n)
		for k in w3.critter_count:
			worst = minf(worst, w3.critter_pos[k].distance_to(w3.swarm.pos[0]))
	t.ok(worst >= 900.0, "열 판을 돌려도 스폰은 화면 밖에서 일어난다 (%.0f, 리터럴 900)" % worst)


# -- 3: the removal swap, all eight columns and `boss_index` ---------------------------------------------
## ⚠ **The row removed is NOT the last one.** `_remove_critter(k)` only enters its swap branch when
## `k != last`; removing the only creature leaves every missing line green.
##
## The last row is the BOSS on purpose, so one fixture measures the swap and the `last == boss_index` half
## of the repair at once — and the eight values it carries down are literals written before the removal,
## never read back off the table afterwards.
func _c3_removal_swap(t) -> void:
	var w := World.new()
	w.setup(404)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(100.0, 100.0), 10)
	w._write_critter(HORSE, Vector2(200.0, 200.0), 30)
	var b := w._write_critter(BOSS, Vector2(1234.0, 567.0), 120)
	w.boss_index = b
	t.eq(w.critter_count, 3, "설정: 세 줄을 세웠다")
	t.eq(b, 2, "설정: 보스가 마지막 줄이다 — 이 검사는 그 줄이 내려오는 것을 잰다")
	# Written by hand so every value below is a literal rather than whatever `_write_critter` rolled.
	# ⚠ **`flees` is 1, and it is the one column here whose value had to be CHOSEN rather than picked.**
	# The boss's own disposition is 0 and so is the crow's, so `= 0` / expect `0` was a value the
	# DESTINATION row already held: dropping `critter_flees[k] = critter_flees[last]` from
	# `_remove_critter` left this whole check green while its seven siblings reddened. Every other column
	# here is distinctive by luck; this one is distinctive on purpose. A dead creature's disposition
	# landing on a survivor is a horse that stops fleeing and a crow that starts running.
	w.critter_dir[b] = Vector2(0.0, 1.0)
	w.critter_hp[b] = 361
	w.critter_flees[b] = 1
	w.critter_atk_cd[b] = 0.75
	w.critter_counter[b] = 1.25

	w._remove_critter(0)
	t.eq(w.critter_count, 2, "가운데가 아니라 첫 줄을 지웠고 두 줄이 남았다")
	t.eq(w.critter_pos[0], Vector2(1234.0, 567.0), "자리를 그대로 들고 내려왔다")
	t.eq(w.critter_dir[0], Vector2(0.0, 1.0), "방향도 제 것이다")
	t.eq(int(w.critter_species[0]), BOSS, "종도 제 것이다")
	t.eq(int(w.critter_force[0]), 120, "힘도 제 것이다")
	t.eq(int(w.critter_hp[0]), 361, "체력도 제 것이다")
	t.eq(int(w.critter_flees[0]), 1, "성향도 제 것이다 — 목적지가 이미 들고 있던 0이 아니다")
	t.eq(w.critter_atk_cd[0], 0.75, "공격 시계도 제 것이다")
	t.eq(w.critter_counter[0], 1.25, "반격 시계도 제 것이다")
	t.eq(w.boss_index, 0, "그리고 boss_index가 따라 내려왔다 — 열이 아니라 인덱스라 따로 고쳐야 한다")


# -- 4: disposition comes from the species and damage does not change it ---------------------------------
## **Replaces the plan's "step a horse for 10s and it still flees"**, which measures the absence of code
## nobody wrote and can never fail. What CAN go wrong is `_damage_critter` arming the counter for every
## species instead of the crow's, or clearing `flees` on damage — so the check damages a horse and reads
## both columns back.
func _c4_disposition(t) -> void:
	var w := World.new()
	w.setup(414)
	var seen := {}
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		var right: bool = int(w.critter_flees[k]) == int(Rules.SPECIES_FLEES[s])
		seen[s] = bool(seen.get(s, true)) and right
	t.eq(seen.size(), 7, "설정: 일곱 종이 다 필드에 있다")
	var all_right := true
	for s: int in seen:
		all_right = all_right and bool(seen[s])
	t.ok(all_right, "일곱 종 모두 제 종의 성향을 들고 태어난다")

	var w2 := World.new()
	w2.setup(415)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(HORSE, Vector2(1500.0, 1000.0), 30)
	w2.critter_hp[0] = 900
	for _n in 5:
		w2._damage_critter(0, 1)
		for _s in 120:
			w2._step_critters(DT)
	t.eq(int(w2.critter_flees[0]), 1, "열 초 동안 다섯 번 맞아도 말은 여전히 도망치는 쪽이다")
	t.eq(w2.critter_counter[0], 0.0, "그리고 말에게는 반격 시계가 걸리지 않는다 — 그건 까마귀의 것이다")

	var w3 := World.new()
	w3.setup(416)
	w3.critter_count = 0
	w3.boss_index = -1
	w3._write_critter(CROW, Vector2(1500.0, 1000.0), 10)
	w3._damage_critter(0, 1)
	t.eq(w3.critter_counter[0], Rules.CROW_COUNTER_TIME,
			"대조: 같은 한 대가 까마귀에게는 반격 시계를 건다 — 아무에게도 안 걸리는 검사가 아니다")


# -- 5: the horse flees a CLONE as readily as the host ---------------------------------------------------
## The host is 3000px away and outside `CRITTER_SENSE` entirely, so the only body this horse can see is a
## clone. A flee scan written against `swarm.pos[0]` finds nothing at all and the horse stands still.
func _c5_the_horse_flees_a_clone(t) -> void:
	var w := World.new()
	w.setup(405)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var c := w.swarm.add_clone(0, 2)
	w.swarm.pos[c] = Vector2(3000.0, 1000.0)
	w.swarm.command_strike(Vector2(3000.0, 1000.0))
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, Vector2(3300.0, 1000.0), 30)
	w.critter_dir[0] = Vector2.ZERO
	var host_gap: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	t.ok(host_gap > Rules.CRITTER_SENSE,
			"설정: 호스트는 감지 범위 밖이다 — 볼 수 있는 몸은 분신뿐이다 (%.0f)" % host_gap)
	var before: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(absf(before - 300.0) < 0.01, "설정: 분신과 300px 떨어져 섰다 (%.2f)" % before)
	for _s in 60:
		w._step_critters(DT)
	var after: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(after > before + 100.0,
			"말은 호스트가 아니라 분신에게서도 똑같이 도망친다 (%.0f → %.0f)" % [before, after])
	t.ok(w.critter_pos[0].x > 3300.0, "그리고 도망친 방향은 분신의 반대편이다")


# -- 21: `PART_DROP_CHANCE` as a RATIO -------------------------------------------------------------------
## ⚠ **Ten seeds × twenty DISTINCT clones, each alone on its own corpse.** `swarm.worn[eater] = p`
## overwrites and `_step_corpses` picks the lowest clone index in reach, so twenty corpses in one pile feed
## the same clone twenty times and "clones wearing something" undercounts every run.
##
## ⚠ **`_step_corpses` is driven directly.** Two hundred real meals through `world.step()` is ~21,000
## frames; seeding `progress` one frame short is the same measurement at a two-hundredth of the cost.
func _c21_drop_rate(t) -> void:
	var trials := 0
	var wins := 0
	for n in 10:
		var w := World.new()
		w.setup(406 + n)
		_silence_food(w)
		_clear_terrain(w)
		w.critter_count = 0
		w.boss_index = -1
		w.corpse_count = 20
		for i in 20:
			var at := Vector2(200.0 + float(i) * 150.0, 500.0)
			var c := w.swarm.add_clone(0, 4)
			# Written straight into `pos`, not through `place()`: this fixture is about the roll and a body
			# nudged off its corpse by anything would simply not eat.
			w.swarm.pos[c] = at
			w.corpse_pos[i] = at
			w.corpse_species[i] = CROW
			w.corpse_force[i] = 10
			w.corpse_progress[i] = 0.999
		if n == 0:
			t.eq(w.swarm.count, 21, "설정: 분신 스무 마리를 각자 제 시체 위에 세웠다")
		w._step_corpses(DT)
		if n == 0:
			t.eq(w.corpse_count, 0, "설정: 그 스무 구가 한 프레임에 전부 끝났다")
		for i in range(1, w.swarm.count):
			trials += 1
			if w.swarm.worn[i] >= 0:
				wins += 1
	t.eq(trials, 200, "설정: 시행 횟수가 200이다 — 분모를 먼저 못 박는다")
	var rate := float(wins) / float(trials)
	t.ok(rate >= 0.35 and rate <= 0.65,
			"부품이 떨어지는 비율은 0.5 언저리다 — 「가끔」이 아니라 비율이다 (%.3f)" % rate)


# -- U7a: the corpse roll obeys `Parts.DROPS` ------------------------------------------------------------
## ⚠ **`_c21_drop_rate` measures the RATE and never the pool.** Its callers roll until a wanted part appears
## and nothing anywhere says a `DROPS == 0` row may not come out, so dropping the
## `and int(Parts.DROPS[p]) == 1` term left the round green while `Cards.roll`'s identical term reddened.
## What that costs in play: 말 갈기 and 말 폐활량 — the two rows 결정 5 removed from BOTH pools — come back
## onto clones off horse corpses, so the deferral written into `HORSE_TRAIT_COUNT`'s own comment is false.
##
## ⚠ **`worn` is reset to -1 before every call and the successes are COUNTED.** Left set, the swap branch
## runs and the loop measures the last roll only; uncounted, a pool that produced nothing at all would pass
## with `bad == 0` for free.
func _u7a_only_droppable_parts_roll(t) -> void:
	var w := World.new()
	w.setup(452)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var c := w.swarm.add_clone(0, 4)
	var rolls := 0
	var bad := 0
	for _n in 200:
		w.swarm.worn[c] = -1
		w._roll_part(c, HORSE)
		var p := int(w.swarm.worn[c])
		if p >= 0:
			rolls += 1
			if p != Parts.HORSE_LEGS:
				bad += 1
	t.ok(rolls >= 70 and rolls <= 130,
			"설정: 200번을 굴려 절반쯤은 실제로 떨어졌다 — 빈 풀이면 아래가 공짜로 통과한다 (%d)" % rolls)
	t.eq(bad, 0, "말 시체에서 나오는 부품은 말 다리뿐이다 — DROPS 0인 갈기와 폐활량은 굴러 나오지 않는다")

	# The other side of the same column: a BOSS corpse has no droppable row at all, so the pool is empty and
	# the roll returns having written nothing. Without this the check above passes on a filter that simply
	# rejects everything.
	w.swarm.worn[c] = -1
	for _n in 50:
		w._roll_part(c, BOSS)
	t.eq(int(w.swarm.worn[c]), -1, "대조: 보스 시체는 쉰 번을 굴려도 아무것도 남기지 않는다")


# -- U7b: a swap may not put a clone under `BODY_HP_MIN` -------------------------------------------------
## ⚠ **The `maxi(0, ...)` on the FORCE line one statement above reddens and this one did not**, because no
## fixture anywhere damages a clone before swapping its part — which is the exact state the floor's own
## two-line comment describes. A clone at 0 or negative hp is alive until something touches it.
##
## The loop rolls until a part with `HP 0` (날개 or 부리) replaces 까마귀 발 (`HP 3`); its count is asserted
## so a pool that never produced one cannot pass this as a zero-iteration walk.
func _u7b_a_swap_cannot_drop_a_clone_below_the_floor(t) -> void:
	var w := World.new()
	w.setup(453)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var c := w.swarm.add_clone(0, 4)
	var tries := 0
	while tries < 400:
		w.swarm.worn[c] = Parts.CROW_FOOT
		w.swarm.hp[c] = 2
		w.swarm.force[c] = 20
		w._roll_part(c, CROW)
		tries += 1
		if int(w.swarm.worn[c]) != Parts.CROW_FOOT:
			break
	t.ok(tries > 0 and tries < 400, "설정: 까마귀 발이 아닌 부품이 실제로 굴러 나왔다 (%d번째)" % tries)
	t.eq(int(Parts.HP[int(w.swarm.worn[c])]), 0, "설정: 갈아 낀 그 부품의 HP는 0이다 (날개거나 부리)")
	t.eq(int(w.swarm.hp[c]), 1,
			"체력 2에서 HP 3짜리를 벗어도 1로 멈춘다 — 소화가 몸을 0 아래로 데려가지 않는다")
	t.eq(int(w.swarm.hp[c]), Rules.BODY_HP_MIN, "그리고 그 1은 BODY_HP_MIN 그 자체다")


# -- 29: the threat model is GONE, on four instruments ---------------------------------------------------
## ⚠ **This check was written inverted and the deletion step flipped it**, which is the only reason it can
## be trusted: every `not` below was once a `true` that passed against the live symbol, so each instrument is
## already proven to discriminate rather than merely to answer.
##
## **Four instruments, because no one of them sees all four kinds**: a `const` lives in the script's constant
## map, a method answers `has_method`, a `var` is invisible to both and only appears in
## `get_property_list()`, and `look.gd` has no `class_name` so its constants are reached through `load()`. A
## grep would measure a file's letters instead, and five greps shipped on this repo in one feature and every
## one of them was evaded.
##
## ⚠ **An absence check passes for free the day its instrument breaks.** An empty constant map, a `World`
## that failed to construct, an empty property list — each turns every `not` here into a green that measures
## nothing. So every instrument carries a **positive control naming a symbol that must still be there**, and
## `CRITTER_SENSE` is deliberately the surviving NEIGHBOUR of the deleted block: it proves the sweep took
## eight named constants and not the whole `# -- critters ---` section.
func _c29_instruments(t) -> void:
	var consts: Dictionary = Rules.new().get_script().get_script_constant_map()
	t.ok(consts.has("HP_PER_FORCE"), "설정: 상수 계기가 실제로 Rules를 읽었다 — 비면 아래가 저절로 통과한다")
	# The whole threat model's constant list, named one by one — `rules.gd`'s own comment points here rather
	# than repeating it. ⚠ **The size is pinned first**, because an absence check shrinks silently: drop a
	# name from this array and the round stays green while covering one symbol less, which is the same shape
	# as a loop whose condition is false from the start.
	var dead_names := ["FORCE_PER_THREAT", "CRITTER_THREAT_MIN", "CRITTER_THREAT_MAX", "CRITTER_RADIUS_BASE",
			"CRITTER_RADIUS_PER_THREAT", "CRITTER_MEAT", "CRITTER_SPEED", "CRITTER_START"]
	t.eq(dead_names.size(), 8, "설정: 지운 상수 여덟 개를 전부 이름으로 세운다 — 분모를 먼저 못 박는다")
	for dead in dead_names:
		t.ok(not consts.has(dead), "상수 계기: Rules.%s는 사라졌다" % dead)
	t.ok(not consts.has("FORCE_PER_NOTHING"), "대조: 없는 상수는 없다고 답한다")
	t.ok(consts.has("CRITTER_SENSE"),
			"대조: 이웃한 CRITTER_SENSE는 남아 있다 — 블록째 지운 게 아니라 여덟 개를 골라 지웠다")
	t.ok(consts.has("SPECIES_START") and consts.has("SPECIES_SPEED_MUL"),
			"대조: 지운 둘을 대신하는 종별 표는 실제로 있다")
	t.ok(not consts.has("CRITTER_START_CROW") and not consts.has("SPAWN_CROW_CHANCE"),
			"그리고 두 종만 알던 상수 둘은 표에 자리를 내주고 사라졌다")

	var w := World.new()
	t.ok(w.has_method("strike"), "설정: 메서드 계기가 실제로 World를 읽었다")
	t.ok(not w.has_method("is_hunter_of"), "메서드 계기: World.is_hunter_of는 사라졌다")
	t.ok(not w.has_method("is_hunter_of_nothing"), "대조: 없는 메서드는 없다고 답한다")

	# ⚠ **A `var` is invisible to both instruments above**, and a dead column surviving as a second source of
	# truth is exactly what the deletion exists to prevent. Revision 1 of the build spec used only the first
	# two instruments and would have let both of these through.
	var props := {}
	for p: Dictionary in w.get_property_list():
		props[String(p["name"])] = true
	t.ok(props.has("critter_species"), "설정: 속성 계기가 실제로 목록을 읽었다")
	t.ok(not props.has("critter_threat"), "속성 계기: World.critter_threat은 사라졌다")
	t.ok(not props.has("critters_eaten"), "속성 계기: World.critters_eaten도 사라졌다")
	t.ok(not props.has("critter_nothing"), "대조: 없는 속성은 없다고 답한다")

	var look_consts: Dictionary = (load("res://src/look.gd") as GDScript).get_script_constant_map()
	t.ok(look_consts.has("CROW_COLOR"), "설정: 색 계기가 실제로 look.gd를 읽었다")
	t.ok(not look_consts.has("CRITTER_COLOR"), "색 계기: Look.CRITTER_COLOR는 사라졌다")
	t.ok(not look_consts.has("CRITTER_PREY_COLOR"),
			"색 계기: 사냥감 파란색도 사라졌다 — 뒤집을 색이 없으니 남길 상수도 없다")
	t.ok(not look_consts.has("CRITTER_NOTHING_COLOR"), "대조: 없는 색은 없다고 답한다")


# -- 30: size never inverts ------------------------------------------------------------------------------
## ⚠ **Driven through `_radius_of`, not written as three bare literals.** The mutation this exists for is
## the missing `maxi(1, MAX - MIN)` span guard, and the boss's `120 / 0` NaN is only observable through the
## function: `18.0 < 22.0 < 48.0` as literals is true forever and measures nothing at all.
func _c30_size_never_inverts(t) -> void:
	var w := World.new()
	var crow_max := w._radius_of(CROW, 12)
	var horse_min := w._radius_of(HORSE, 30)
	var boss := w._radius_of(BOSS, 120)
	t.ok(is_finite(crow_max) and is_finite(horse_min) and is_finite(boss),
			"세 반지름 모두 실수다 — 보스의 span 0이 NaN을 만들지 않는다 (%.2f / %.2f / %.2f)"
					% [crow_max, horse_min, boss])
	t.ok(absf(crow_max - 18.0) < 0.001, "가장 센 까마귀도 18px다 (리터럴) (%.3f)" % crow_max)
	t.ok(absf(horse_min - 22.0) < 0.001, "가장 약한 말이 22px다 (%.3f)" % horse_min)
	t.ok(absf(boss - 48.0) < 0.001, "보스는 48px다 — 힘이 최소이자 최대라 램프가 0이다 (%.3f)" % boss)
	t.ok(crow_max < horse_min and horse_min < boss, "그래서 종의 순서는 뒤집히지 않는다")
	t.ok(absf(w._radius_of(-1, 100)) < 0.0001,
			"종이 없으면 반지름은 0이다 — -1은 GDScript에서 마지막 줄을 읽는 합법적인 인덱스다")


# -- F1b: the crow does not one-shot the host ------------------------------------------------------------
## ⚠ **Nothing asserted the entire justification for the ×10.** "It does not one-shot the host" was a
## sentence in a design doc, and `HOST_HP` at 12 satisfies every other check in the round.
func _f1b_a_crow_does_not_one_shot(t) -> void:
	t.eq(Rules.HOST_HP, 30, "호스트의 체력은 30이다 (리터럴)")
	t.eq(int(Rules.SPECIES_FORCE_MAX[CROW]), 12, "가장 센 까마귀의 힘은 12다 (리터럴)")
	t.ok(Rules.HOST_HP >= int(Rules.SPECIES_FORCE_MAX[CROW]) * 2,
			"가장 센 까마귀라도 한 대로는 못 죽인다 — 체력은 그 두 배 이상이다")


# -- F2: boss placement, and the OTHER half of the index repair ------------------------------------------
## ⚠ **`Rules.BOSS_PLACE_TRIES` alone is NOT what this measures, and that was measured.** Dropping it to 1
## leaves this check green, because the sampler falls back to a deterministic inset corner — the backstop
## is what makes the distance provable rather than green seven times in ten. The two cover for each other
## here by design; **`_u12_where_the_boss_opens` below is what separates them.**
##
## ⚠ **The floor is a hand-written 1800.0 and it was `Rules.BOSS_SPAWN_MIN_DIST` on both sides.** Read off
## the constant under test, the check shrinks with it: at 900 the boss can open inside `MINIMAP_SHOW_DIST`
## and "it is out there, visible on the map, and it is a walk" is silently deleted with this green.
func _f2_boss_placement(t) -> void:
	var worst := INF
	for n in 10:
		var w := World.new()
		w.setup(417 + n)
		if w.boss_index < 0:
			worst = -1.0
			break
		worst = minf(worst, w.critter_pos[w.boss_index].distance_to(w.swarm.pos[0]))
	t.ok(worst >= 1800.0,
			"열 판을 돌려도 보스는 1800px 밖에 놓인다 — 미니맵에 보이고 걸어갈 거리다 (%.0f)" % worst)

	# The `last == boss_index` half: the boss is the last row, so removing anyone else swaps it down.
	var w2 := World.new()
	w2.setup(427)
	var b := w2.boss_index
	t.eq(b, w2.critter_count - 1, "설정: 보스는 마지막 줄에 놓인다")
	w2._remove_critter(5)
	t.eq(w2.boss_index, 5, "보스가 아닌 줄이 죽으면 boss_index가 새 자리를 따라간다")
	t.eq(int(w2.critter_species[w2.boss_index]), BOSS, "그리고 그 자리에 실제로 보스가 있다")
	# And it still walks: a stale index is a boss that stops moving with nothing on screen to say so.
	_silence_food(w2)
	_clear_terrain(w2)
	w2.elapsed = Rules.BOSS_HUNT_AT
	var gap: float = w2.critter_pos[w2.boss_index].distance_to(w2.swarm.pos[0])
	w2._step_critters(DT)
	t.ok(w2.critter_pos[w2.boss_index].distance_to(w2.swarm.pos[0]) < gap - 2.0,
			"고쳐진 인덱스의 보스는 여전히 걸어온다")


# -- U12: the sampler and the backstop, one at a time ----------------------------------------------------
## **They covered for each other and neither was measured alone.** Three verifiers found this independently
## and every one of these was green: `BOSS_PLACE_TRIES` 200 → 0 (the sampler dead, the backstop still
## satisfying F2's floor), the guard → `if false:` (the backstop dead), the backstop rewritten to
## `best = host` — **the boss opens on top of the player** — and its four corner comparisons inverted.
##
## `_boss_spot` takes its try count as an argument for exactly this: at 200 the backstop is a 1-in-10¹¹
## branch and cannot be driven, at 0 it is the only branch there is.
func _u12_where_the_boss_opens(t) -> void:
	var w := World.new()
	w.setup(430)
	_clear_terrain(w)
	var mid := Rules.FIELD * 0.5

	# (a) The backstop, four quadrants, literal corners. `inset` is 200 and the field is 3840×2160.
	t.eq(w._boss_backstop(Vector2(100.0, 100.0)), Vector2(3640.0, 1960.0),
			"호스트가 왼쪽 위에 있으면 보스는 오른쪽 아래 구석이다")
	t.eq(w._boss_backstop(Vector2(3700.0, 100.0)), Vector2(200.0, 1960.0),
			"오른쪽 위면 왼쪽 아래다")
	t.eq(w._boss_backstop(Vector2(100.0, 2000.0)), Vector2(3640.0, 200.0),
			"왼쪽 아래면 오른쪽 위다")
	t.eq(w._boss_backstop(Vector2(3700.0, 2000.0)), Vector2(200.0, 200.0),
			"오른쪽 아래면 왼쪽 위다 — 네 비교가 뒤집혀도 초록이었다")
	# The middle is the case `setup()` actually opens in, and it must not be the host's own square.
	t.ok(w._boss_backstop(mid).distance_to(mid) >= 1800.0,
			"필드 한가운데서도 그 구석은 1800px 밖이다 (%.0f)"
					% w._boss_backstop(mid).distance_to(mid))

	# (b) With no samples allowed the backstop is the whole answer, and it is NOT the host.
	var none := w._boss_spot(mid, 0)
	t.eq(none, w._boss_backstop(mid), "뽑기를 0번 하면 남는 것은 그 구석뿐이다")
	t.ok(none != mid, "그리고 그것은 호스트 자리가 아니다 — 보스가 플레이어 위에 태어나지 않는다")

	# (c) With the real count the SAMPLER answers, and its answer moves with the seed. A backstop-only
	# placer puts every run's boss on one of four fixed corners; ten seeds and four corners cannot fill
	# ten distinct points.
	var seen := {}
	var corners := 0
	for n in 10:
		var wn := World.new()
		wn.setup(500 + n)
		var p: Vector2 = wn.critter_pos[wn.boss_index]
		seen[str(p.round())] = true
		if p.distance_to(wn._boss_backstop(wn.swarm.pos[0])) < 1.0:
			corners += 1
	t.ok(seen.size() >= 8,
			"열 씨앗이 보스를 여덟 자리 이상에 놓는다 — 뽑기가 죽으면 네 구석뿐이다 (%d)" % seen.size())
	t.eq(corners, 0, "그 열 판 중 구석으로 떨어진 판은 하나도 없다 — 200번 뽑기는 실제로 통한다")


# -- F2b: the boss's own death ---------------------------------------------------------------------------
## ⚠ **F2 never reaches this half.** `k == boss_index` fires only when the boss itself dies, and that is the
## one place the run's ending walks through — `_step_arena()` then reads `critter_pos` of whatever swapped
## in, or a row past `critter_count`, with no error because the arrays are sized to the cap.
func _f2b_the_boss_dies(t) -> void:
	var w := World.new()
	w.setup(428)
	_silence_food(w)
	var b := w.boss_index
	t.ok(b >= 0, "설정: 보스가 있다")
	var was_closed: bool = w.terrain.arena_closed
	t.ok(not was_closed, "설정: 아레나는 아직 열려 있다")
	t.ok(w._damage_critter(b, 400), "설정: 보스를 실제로 죽였다 (체력 360)")
	t.eq(w.boss_index, -1, "보스가 죽으면 boss_index는 -1이 된다")
	# ⚠ **Past `BOSS_HUNT_AT`, or the frame below is quiet for the wrong reason.** `_step_arena` returns
	# before it reads `boss_index` at all while the hunt has not started, so at `elapsed = 0` this passes
	# with the `boss_index < 0` guard deleted.
	w.elapsed = Rules.BOSS_HUNT_AT
	w.step(DT)
	t.eq(w.terrain.arena_closed, false, "죽은 보스는 아레나를 닫지 못한다 — 다음 프레임도 조용히 지나간다")


# -- F3: nothing spawns inside a rock --------------------------------------------------------------------
## ⚠ **The precondition is not decoration.** `push_out` is the identity on an empty rock array and
## `Terrain.setup()`'s rejection can legitimately skip every rock, so without the floor this check passes
## perfectly on a field with no ground at all.
##
## ⚠ **It takes BOTH of `_spawn_at`'s rock tests to redden this, and that was measured, not assumed.**
## Deleting the trailing `push_out` alone leaves the round GREEN — the in-loop rejection almost always
## accepts a clear point, so the fall-through never fires. Deleting the in-loop test alone is green too:
## the trailing push cleans up after it. The two are redundant with each other on purpose and this check is
## what says the protection exists at all; its named mutation is **the pair**.
func _f3_nothing_spawns_in_a_rock(t) -> void:
	var rocks := INF
	var inside := 0
	var checked := 0
	for n in 10:
		var w := World.new()
		w.setup(429 + n)
		rocks = minf(rocks, float(w.terrain.rock_pos.size()))
		for k in w.critter_count:
			checked += 1
			var r := w.critter_radius(k)
			if w.terrain.push_out(w.critter_pos[k], r) != w.critter_pos[k]:
				inside += 1
	t.ok(rocks >= 30.0, "설정: 바위가 서른 개 이상 놓였다 (%.0f) — 빈 땅에서는 이 검사가 공짜로 통과한다" % rocks)
	t.eq(checked, 320, "설정: 열 판 × 서른두 마리를 다 봤다")
	t.eq(inside, 0, "바위 안에서 태어나는 생물은 하나도 없다")


# -- F4: `SPECIES_SPAWN_WEIGHT`, as a ratio --------------------------------------------------------------
## Round 3 named the constant this replaced in its "nothing checks it" list. Check 1 counts the opening
## field, which comes from `SPECIES_START` and never touches the roll at all.
##
## ⚠ **`_roll_species()` is driven, not the creature rows counted afterwards.** Counting bodies measures the
## roll multiplied by `SPECIES_HERD` — a horse is rolled half as often as a squirrel and arrives four at a
## time — so a body count is a check on two tables at once and pins neither. It was written that way for the
## two-species build, where every herd was 1 and the distinction did not exist.
func _f4_spawn_species_roll(t) -> void:
	var w := World.new()
	w.setup(439)
	var rolls := 2000
	var per := {}
	var total_weight := 0
	for weight in Rules.SPECIES_SPAWN_WEIGHT:
		total_weight += int(weight)
	for _i in rolls:
		var s := w._roll_species()
		per[s] = int(per.get(s, 0)) + 1
	t.eq(total_weight, 84, "설정: 가중치의 합은 84다 (리터럴) — 분모를 먼저 못 박는다")

	# Every species with a weight must actually appear, and the boss must not. A roll that can never reach
	# the last row is a bug that looks exactly like bad luck, which is why the ZERO rows are asserted too.
	for s in Rules.SPECIES_SPAWN_WEIGHT.size():
		var weight := int(Rules.SPECIES_SPAWN_WEIGHT[s])
		var got := int(per.get(s, 0))
		if weight == 0:
			t.eq(got, 0, "가중치 0인 %d종은 한 번도 굴려지지 않는다" % s)
			continue
		var want := float(weight) / float(total_weight)
		var rate := float(got) / float(rolls)
		t.ok(absf(rate - want) < 0.04,
				"%d종은 가중치대로 나온다 (%.3f, 기대 %.3f)" % [s, rate, want])
	t.ok(int(per.get(CROW, 0)) > int(per.get(HORSE, 0)),
			"까마귀는 말보다 흔하다 — 말은 사건이고 까마귀는 일상이다")


# -- F5: one frame is one step, per creature -------------------------------------------------------------
## ⚠ **The loop BOUND, not the swap.** `_c3` covers what a removal carries down; this covers who the walk
## visits afterwards. A range materialises its index list once, and a clone's cone kills **every** creature
## it covers — including rows below the one being stepped. `_remove_critter` then copies the last row down
## over the dead one, and a BACKWARDS walk has already stepped that row: it is reached a second time and
## takes two steps in one frame. The tail of the frozen list also indexes rows past the new
## `critter_count`, which are stale, never cleared, and still contact and damage.
##
## ⚠ **The horse is found by SPECIES, not by index.** After the crow dies the horse IS row 0, so an
## index-keyed assertion would have to know where the swap left it — and that is the thing under test.
##
## ⚠ **The two `설정` lines pass either way on purpose.** The kill and the swap are identical under both
## walks; only the distance separates them, and 3.8333 is `230px/s × 1/60` written by hand.
func _f5_each_creature_walks_once_per_frame(t) -> void:
	var w := World.new()
	w.setup(450)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1500.0, 1000.0)
	var c := w.swarm.add_clone(0, 40)
	w.swarm.pos[c] = at
	w.swarm.worn[c] = Parts.CROW_WING
	w.swarm.atk_cd[c] = 0.0
	w.critter_count = 0
	w.boss_index = -1
	# The crow is the BYSTANDER and it is written first, so the row the cone kills sits below the horse's.
	w._write_critter(CROW, at + Vector2(40.0, 0.0), 10)
	w._write_critter(HORSE, at + Vector2(25.0, 0.0), 30)
	var start: Vector2 = w.critter_pos[1]
	t.eq(w.critter_count, 2, "설정: 까마귀 한 마리와 말 한 마리가 분신의 원뿔 안에 섰다")
	w._step_critters(DT)
	t.eq(w.critter_count, 1, "설정: 날개 한 번이 까마귀만 죽였다 (말은 체력 90)")
	t.eq(int(w.critter_species[0]), HORSE, "설정: 빈 줄로 마지막 줄의 말이 내려왔다")
	var walked: float = w.critter_pos[0].distance_to(start)
	t.ok(absf(walked - 3.8333) < 0.05,
			"곁의 까마귀가 죽어도 말은 한 프레임에 한 걸음만 걷는다 (%.4f — 두 걸음은 7.67)" % walked)

	# ⚠ **The bound is RE-READ, and that half was free while the direction was pinned.** The fix's own
	# comment claims two things — forwards, over a bound re-read every iteration — and only the first is
	# measured above. Freeze the bound at entry and the walk direction stays correct, so the check above
	# still passes: `_remove_critter(0)` swaps the horse down and shrinks the count, and the loop then runs
	# one more iteration at the old bound over row 1, which the swap left holding the horse's own stale
	# copy. That ghost flees the clone and walks 3.83px out of a row nobody is supposed to be in.
	# **`start` is the horse's position on entry and row 1 must still be sitting on it.**
	t.eq(w.critter_pos[1], start,
			"줄어든 셈은 그 자리에서 읽힌다 — 스와프가 남긴 1번 줄은 걷지 않는다 (기대 %s)" % str(start))

	_f5b_the_row_past_the_end_does_not_act(t)


# -- F5b: the walk's UPPER edge, which nothing touched --------------------------------------------------
## ⚠ **F5 above measures the direction of the walk and its lower end; `while k < critter_count` has another
## end and it was free.** Every critter table is `resize(Rules.CRITTER_MAX)` at setup and **never cleared**,
## so index `critter_count` is not empty — it holds whatever creature died there last, complete with
## species, force, hp, position, direction and disposition. One character (`<` → `<=`) makes that row a
## live creature again: it walks, it senses, it contacts, it damages a clone or the host, and it can itself
## be "killed", at which point `_remove_critter(count)` copies the row at `last` — **a real, living
## creature** — into the ghost slot and decrements the count, deleting that creature from the field.
## At the cap (`critter_count == CRITTER_MAX` 24) it is a straight out-of-range read on a 24-element array.
##
## Nothing in the round could see it, because no fixture ever looks at a row it did not write. This one
## writes the ghost **on purpose** and then asserts it is inert — three ways, so a mutation cannot be half
## caught: the per-frame clocks the loop decrements before anything else, the walk, and the retaliation.
func _f5b_the_row_past_the_end_does_not_act(t) -> void:
	var w := World.new()
	w.setup(451)
	_silence_food(w)
	_clear_terrain(w)
	var host := Vector2(1500.0, 1000.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	# Row 0, the only creature the world knows about: far away, standing, harmless.
	w._write_critter(CROW, host + Vector2(2000.0, 0.0), 10)
	# Row 1, the GHOST — written through the same door and then hidden by winding the count back. It is
	# armed to do every single thing a stepped creature does: its counter is up so it CHASES rather than
	# standing, it is 300px away (inside `CRITTER_SENSE` 520) so it has a target, and it is close enough
	# that one step plus its own reach would put it on the host.
	w._write_critter(CROW, host + Vector2(300.0, 0.0), 10)
	w.critter_counter[1] = 5.0
	w.critter_atk_cd[1] = 0.0
	var ghost_at: Vector2 = w.critter_pos[1]
	w.critter_count = 1
	t.eq(w.critter_count, 1, "설정: 세상은 생물이 하나라고 알고 있다")
	t.eq(int(w.critter_species[1]), CROW, "설정: 그런데 1번 줄에는 죽은 까마귀의 값이 그대로 남아 있다")

	w._step_critters(DT)

	# The clocks are the first thing the loop touches, before any geometry — so this bites even on a ghost
	# that would not have moved anyway. `_write_critter` leaves `critter_counter` at 0 for a fresh creature,
	# which is why it is wound up by hand here: 5.0 is a value only this row holds.
	t.eq(w.critter_counter[1], 5.0,
			"끝 너머의 줄은 제 시계조차 돌지 않는다 — 걸어 보기 전에 이미 안 밟히는 줄이다")
	t.eq(w.critter_pos[1], ghost_at,
			"그리고 걷지 않는다 — 표는 CRITTER_MAX만큼 잡혀 있고 지워지지 않으니 그 줄은 비어 있지 않다")
	t.eq(w.host_hp, 30, "설정 겸 확인: 300px 밖의 까마귀는 어차피 호스트를 못 때린다")

	# **The damage half, and it needs its own fixture**: the check above passes on a ghost that acts and
	# simply cannot reach. Here the ghost stands ON the host, so a single stepped frame costs 10 hp.
	var w2 := World.new()
	w2.setup(452)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = host
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, host + Vector2(2000.0, 0.0), 10)
	w2._write_critter(CROW, host, 10)
	w2.critter_atk_cd[1] = 0.0
	w2.critter_count = 1
	t.eq(w2.host_hp, 30, "설정: 호스트는 체력 30으로 서 있다")
	w2._step_critters(DT)
	t.eq(w2.host_hp, 30,
			"호스트 위에 겹쳐 선 유령 줄도 반격하지 않는다 — 없는 생물에게 맞을 수는 없다")
	t.eq(w2.critter_atk_cd[1], 0.0, "그 줄의 공격 쿨다운도 그대로다 — 때린 적이 없으니 물 것도 없다")

	# The control, and without it every assertion above passes on a `_step_critters` that does nothing at
	# all: the same creature, one row lower, IS stepped and DOES take the host's health.
	var w3 := World.new()
	w3.setup(453)
	_silence_food(w3)
	_clear_terrain(w3)
	w3.swarm.pos[0] = host
	w3.critter_count = 0
	w3.boss_index = -1
	w3._write_critter(CROW, host, 10)
	w3.critter_atk_cd[0] = 0.0
	w3._step_critters(DT)
	t.eq(w3.host_hp, 20, "대조: 셈에 들어 있는 같은 까마귀는 제 힘 10만큼 그대로 깎는다")


# -- G1: wandering, and the crow that does not -----------------------------------------------------------
## `SPECIES_WANDER` is the third disposition column and it decides what a creature does with **nothing in
## sight**. Both directions are measured in one fixture because either alone is satisfied by the wrong code:
## a creature that always walks passes the elephant half, and one that never walks passes the crow half.
##
## ⚠ **The host is moved off the field's far corner rather than deleted**, so `target` is genuinely -1 by
## distance (`CRITTER_SENSE`) and not by an empty swarm — an empty swarm is a state play never reaches.
func _g1_wandering_is_a_column(t) -> void:
	var w := World.new()
	w.setup(416)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(3800.0, 2100.0)
	w.critter_count = 0
	w.boss_index = -1
	var start := Vector2(500.0, 500.0)
	w._write_critter(int(Parts.Species.ELEPHANT), start, 80)
	w._write_critter(CROW, start + Vector2(0.0, 400.0), 10)
	var e_at: Vector2 = w.critter_pos[0]
	var c_at: Vector2 = w.critter_pos[1]
	t.ok(e_at.distance_to(w.swarm.pos[0]) > Rules.CRITTER_SENSE,
			"설정: 둘 다 호스트를 감지할 수 없는 거리다 — 이 검사는 「아무것도 안 보일 때」에 관한 것이다")
	for _s in 600:
		w._step_critters(DT)
	var e_moved: float = w.critter_pos[0].distance_to(e_at)
	var c_moved: float = w.critter_pos[1].distance_to(c_at)
	t.ok(e_moved > 100.0,
			"코끼리는 아무것도 안 보여도 10초 동안 100px 넘게 걷는다 — 배회는 표의 한 칸이다 (%.0f)" % e_moved)
	t.ok(c_moved < 0.001,
			"대조: 같은 10초 동안 까마귀는 한 발짝도 안 움직인다 — 걸어가서 치는 것이지 오는 것이 아니다 (%.4f)"
					% c_moved)
	t.eq(int(Rules.SPECIES_WANDER[CROW]), 0, "그 차이는 SPECIES_WANDER의 까마귀 칸이 0이라는 것뿐이다")
	t.eq(int(Rules.SPECIES_WANDER[Parts.Species.ELEPHANT]), 1, "그리고 코끼리 칸이 1이라는 것")

	# ⚠ **Wandering is not vibrating.** `dir` is left alone on the frames that do not turn; re-rolling it
	# every frame produces a creature that moves nowhere while every "it walked" assertion above still
	# passes, because the walk is measured over 600 frames and a vibration's net displacement is ~0.
	# **This is the check that separates the two**, and it is why the one above is not enough.
	var turns := 0
	var prev: Vector2 = w.critter_dir[0]
	for _s in 600:
		w._step_critters(DT)
		if w.critter_dir[0] != prev:
			turns += 1
			prev = w.critter_dir[0]
	t.ok(turns >= 2 and turns <= 40,
			"10초에 방향은 두 번에서 마흔 번 사이로 바뀐다 — 0은 직진이고 600은 제자리 진동이다 (%d)" % turns)


# -- G2: the lion hunts, and it is slower than you ------------------------------------------------------
## The only species whose `SPECIES_HUNTS` row is 1. Two halves, and the second is what keeps it from being
## a death sentence: a hunter above `HOST_SPEED` is an unavoidable chase, which is the boss's job and the
## boss has an arena to make it fair.
func _g2_the_lion_is_the_only_hunter(t) -> void:
	var w := World.new()
	w.setup(417)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	# Inside `CRITTER_SENSE` and outside every reach, so the frames measured are walking and not contact.
	w._write_critter(int(Parts.Species.LION), Vector2(1400.0, 1000.0), 60)
	var gap: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	for _s in 60:
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(w.swarm.pos[0]) < gap - 100.0,
			"사자는 아무 도발 없이 호스트를 향해 걸어온다 (%.0f → %.0f)"
					% [gap, w.critter_pos[0].distance_to(w.swarm.pos[0])])

	var hunters := 0
	for s in Rules.SPECIES_HUNTS.size():
		hunters += int(Rules.SPECIES_HUNTS[s])
	t.eq(hunters, 1, "그리고 사냥하는 종은 정확히 하나다 — 둘이면 필드는 추격전이 된다")
	t.eq(int(Rules.SPECIES_HUNTS[Parts.Species.LION]), 1, "그 하나는 사자다")
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.LION]) < 1.0,
			"사자는 호스트보다 느리다 — 걸어서 떨어지는 것이 언제나 답이다 (%.2f × HOST_SPEED)"
					% float(Rules.SPECIES_SPEED_MUL[Parts.Species.LION]))
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.SQUIRREL]) < 1.0,
			"다람쥐도 호스트보다 느리다 — 쫓아가서 잡을 수 있는 유일한 것이다")
	t.ok(float(Rules.SPECIES_SPEED_MUL[Parts.Species.CHEETAH])
					> float(Rules.SPECIES_SPEED_MUL[HORSE]),
			"치타는 말보다도 빠르다 — 어떤 수단으로도 잡히지 않는 것이다")


# -- G3: a herd is born together -------------------------------------------------------------------------
## "무리 지어 다닌다" is one spawn call and nothing else — no cohesion code, because a herd that is held
## together cannot produce the straggler the design wants you to catch.
##
## ⚠ **The spread is asserted as a CEILING and the count as an equality.** A `_spawn_herd` that fell back to
## placing each member independently would still write four horses; only the distance says they arrived
## together.
func _g3_a_herd_is_born_together(t) -> void:
	var w := World.new()
	w.setup(418)
	_silence_food(w)
	w.critter_count = 0
	w.boss_index = -1
	var born := w._spawn_herd(HORSE)
	t.eq(born, int(Rules.SPECIES_HERD[HORSE]), "말 한 무리는 SPECIES_HERD만큼 태어난다")
	t.eq(w.critter_count, 4, "그리고 그 수는 넷이다 (리터럴)")
	var anchor: Vector2 = w.critter_pos[0]
	var worst := 0.0
	for k in w.critter_count:
		worst = maxf(worst, w.critter_pos[k].distance_to(anchor))
	t.ok(worst <= Rules.SPAWN_HERD_SPREAD,
			"넷은 SPAWN_HERD_SPREAD 안에 모여 태어난다 (%.0f ≤ %.0f)" % [worst, Rules.SPAWN_HERD_SPREAD])
	t.ok(worst > 0.0, "그리고 한 점에 겹쳐 있지는 않다 (%.0f)" % worst)

	# ⚠ **The herd's ANCHOR pays for the spread**, and this is the check that says so. A member does not
	# re-test its distance to the host, so a flat `CRITTER_SPAWN_MIN_DIST` on the anchor puts the far side
	# of the herd inside the guarantee — measured at 865px against the literal 900 the first time this ran.
	var closest := INF
	for n in 12:
		var w2 := World.new()
		w2.setup(460 + n)
		w2.critter_count = 0
		w2.boss_index = -1
		for _h in 3:
			w2._spawn_herd(HORSE)
		for k in w2.critter_count:
			closest = minf(closest, w2.critter_pos[k].distance_to(w2.swarm.pos[0]))
	t.ok(closest >= Rules.CRITTER_SPAWN_MIN_DIST,
			"무리의 어느 한 마리도 화면 안에서 태어나지 않는다 (%.0f ≥ %.0f)"
					% [closest, Rules.CRITTER_SPAWN_MIN_DIST])
	t.ok(w._anchor_min_dist(HORSE) > w._anchor_min_dist(CROW),
			"무리를 짓는 종의 닻은 혼자 오는 종보다 멀리서 굴려진다 — 퍼짐값을 미리 치른다")


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks sit wherever a fixture writes a coordinate, and `push_out` moves a hand-placed body or
## creature off one by up to a rock's radius. **A check that is not about the ground removes the ground.**
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
