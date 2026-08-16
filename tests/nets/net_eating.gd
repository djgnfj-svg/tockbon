extends RefCounted
## The corpse and the beat: a kill leaves a body, the body has to be stood over, and the meal takes as long
## as the thing was big.
##
## **Two rules here would each delete the beat on their own and neither is visible in final state.**
## Progress advances ONCE PER FRAME rather than once per eater — forty clones on the boss would otherwise
## finish a six-second meal in 0.15s, and forty on one point is precisely what `1` and `V` produce. And a
## body eats ONE corpse at a time, the nearest in reach — walking corpses and collecting eaters per corpse
## lets one clone in a pile advance every corpse in it at once.
##
## ⚠ **`_step_corpses(dt)` is driven directly almost everywhere.** `world.step()` moves bodies, and every
## fixture here is about a body standing still on a corpse; a frame where nobody is in reach stalls progress
## and the two runs of check 17 would differ on a correct build.
##
## Seeds 420–449 are this file's own block.
##
## ⚠ **EVERY `while` in this file is bounded by `BOUND` and every one of them asserts its own iteration
## count.** Six were unbounded, and the single most obvious mutation of the beat — zeroing the
## `corpse_progress` increment in `World::_step_corpses` — made this net **hang forever** rather than go
## red: killed at 148.7 seconds with zero checks reported and no verdict printed at all. `run_nets.ps1`
## launches each net with `Start-Process -Wait` and no timeout, so a hang is indistinguishable from work
## and every check downstream of the first unbounded loop was unverifiable by mutation. **A bound alone is
## not enough** — a loop that reaches its ceiling and is then only compared against another loop that also
## reached it is CLAUDE.md's runaway-ceiling shape, which is why each count is pinned to a literal.
const BOUND := 3000
## The three meals, as literals, because they are what every bound in this file is measured against.
## A force-10 crow is `10 × EAT_TIME_PER_FORCE 0.05` = 0.5s = 30 frames, a force-30 horse 1.5s = 90, a
## force-120 boss 6.0s = 360 — **the WHOLE meal, summed across every bite**, unchanged by §C's split.
## **All three are the ideal plus the one frame it takes to cross the last bite's 1.0.** §C divides the meal
## by `corpse_bites_total()` (3 for the crow and the horse, 9 for the boss) and a bite that finishes CARRIES
## its overshoot into the next one — so the drift is paid once per corpse, not once per bite.
##
## ⚠ **This block used to read "the boss's is 369 and the extra nine are measured rather than tolerated".**
## Nine frames of meal had been invented by `corpse_progress = 0.0` throwing away each bite's leftover
## fraction, and the net wrote the loss down as a property instead of catching it — a number that moves with
## the bug is not a measurement. `-= 1.0` is what makes "the total is unchanged" true by construction.
const CROW_MEAL := 30
const HORSE_MEAL := 90
const BOSS_MEAL := 361

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)
const BOSS := int(Parts.Species.BOSS)


func run(t) -> void:
	_c14_a_kill_leaves_a_corpse(t)
	_c14b_the_corpse_is_copied_before_the_swap(t)
	_c15_eating_is_not_instant(t)
	_c16_the_meal_is_proportional(t)
	_c17_forty_take_as_long_as_one(t)
	_c18_progress_is_kept(t)
	_c19_who_gets_paid(t)
	_c20_the_host_wears_nothing(t)
	_c28_the_boss_corpse_ends_the_run(t)
	_c34_first_eaten_order(t)
	_c36_bite_count_derives_from_force(t)
	_c37_each_bite_pays_its_share(t)
	_c38_quitting_keeps_the_bites_already_eaten(t)
	_c39_species_eaten_and_stage_cleared_wait_for_the_last_bite(t)
	_c40_the_part_roll_waits_for_the_last_bite(t)
	_e1_removal_swap(t)
	_e2_the_cap_evicts_nothing(t)
	_e3_reach_carries_the_corpse_size(t)
	_e4_one_corpse_per_body(t)
	_u6a_the_host_eats_first(t)
	_u6b_the_nearest_corpse_first(t)
	_u6c_a_clone_eats_at_the_clones_own_reach(t)


# -- 14: the corpse is where it FELL ---------------------------------------------------------------------
## Driven through a real `strike()` rather than `_damage_critter` by hand, and the position is a literal the
## host is nowhere near — writing `swarm.pos[0]` as the corpse's position is the mutation, and it is
## invisible against any coordinate the host happens to be standing on.
func _c14_a_kill_leaves_a_corpse(t) -> void:
	var w := World.new()
	w.setup(420)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1060.0, 1000.0), 10)
	t.eq(int(w.critter_hp[0]), 30, "설정: 힘 10짜리 까마귀는 체력 30으로 선다")
	var hits := w.strike(Vector2(1000.0, 1000.0), Vector2.RIGHT, Parts.BITE, 30)
	t.eq(hits, 1, "설정: 한 방에 실제로 맞혔다")
	t.eq(w.critter_count, 0, "죽은 생물은 생물 표에서 사라진다")
	t.eq(w.corpse_count, 1, "그리고 시체가 하나 남는다")
	# ⚠ **§A-3 이후 죽는 자리 자체가 밀려난다.** 힘 30의 한 방은 죽기 전에 `KNOCKBACK_PER_FORCE`만큼 밀고,
	# 시체는 그 뒤에 남으므로 원래 섰던 1060이 아니라 1060 + 30 × KNOCKBACK_PER_FORCE다.
	var fell_at := Vector2(1060.0 + 30.0 * Rules.KNOCKBACK_PER_FORCE, 1000.0)
	t.eq(w.corpse_pos[0], fell_at, "시체는 밀려나 쓰러진 그 자리에 남는다 — 호스트 자리도, 원래 서 있던 자리도 아니다")
	t.eq(int(w.corpse_species[0]), CROW, "제 종을 복사해 들고 있다")
	t.eq(int(w.corpse_force[0]), 10, "제 힘도 복사해 들고 있다 — 죽은 줄을 다시 읽지 않는다")
	t.eq(w.corpse_progress[0], 0.0, "아무도 아직 먹지 않았다")


# -- 14b: the corpse copies the row it came from, BEFORE the removal swaps a stranger into it -------------
## ⚠ **`_c14` kills the ONLY creature, so `_remove_critter` never enters its swap branch** — and moving
## `_add_corpse` below `_remove_critter` leaves the whole round green. Here the dead row is index 0 and the
## LAST row is a boss with a different species, a different force and a position 1500px away, so a corpse
## built after the swap is a **boss corpse worth 360 경험치** standing where the boss stood, and eating it
## sets `stage_cleared`. This is `_damage_clone`'s reading-order bug in a second place; that one has `_c12b`
## and this one had nothing.
func _c14b_the_corpse_is_copied_before_the_swap(t) -> void:
	var w := World.new()
	w.setup(444)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1060.0, 1000.0), 10)
	var b := w._write_critter(BOSS, Vector2(2500.0, 400.0), 120)
	w.boss_index = b
	var crow_r: float = w.critter_radius(0)
	t.eq(w.critter_count, 2, "설정: 죽일 줄은 마지막 줄이 아니다 — 스왑이 실제로 일어난다")
	t.eq(w.critters_died_this_frame.size(), 0, "설정: 아직 아무도 죽지 않았다")
	t.ok(w._damage_critter(0, 100), "설정: 첫 줄의 까마귀를 실제로 죽였다 (체력 30)")
	t.eq(w.critter_count, 1, "설정: 마지막 줄의 보스가 0번으로 내려왔다")
	t.eq(int(w.critter_species[0]), BOSS, "설정: 그 자리에 실제로 보스가 있다")
	t.eq(w.corpse_count, 1, "시체는 하나다")
	t.eq(w.corpse_pos[0], Vector2(1060.0, 1000.0),
			"시체는 까마귀가 쓰러진 자리에 있다 — 내려온 보스의 자리가 아니다")
	t.eq(int(w.corpse_species[0]), CROW, "종도 까마귀다")
	t.eq(int(w.corpse_force[0]), 10, "힘도 10이다 — 360 경험치짜리 보스 시체로 바뀌지 않는다")
	t.eq(w.corpse_progress[0], 0.0, "그리고 아무도 아직 먹지 않았다")
	# §B-4: `critters_died_this_frame`도 같은 함정이다 — 죽은 줄이 마지막이 아닌 이 픽스처가 바로 그것을 잰다.
	t.eq(w.critters_died_this_frame.size(), 1, "그리고 critters_died_this_frame에 죽음이 하나 기록된다")
	if w.critters_died_this_frame.size() == 1:
		var d: Dictionary = w.critters_died_this_frame[0]
		t.eq(d["pos"], Vector2(1060.0, 1000.0), "기록된 자리도 까마귀가 쓰러진 자리다 — 내려온 보스의 자리가 아니다")
		t.eq(int(d["species"]), CROW, "기록된 종도 까마귀다 — 내려온 보스가 아니다")
		t.ok(absf(float(d["r"]) - crow_r) < 0.01,
				"기록된 반지름도 까마귀 제 것이다 (%.2f, 기대 %.2f)" % [float(d["r"]), crow_r])
	# ⚠ **`begin_frame()`이 비운다 — `step()`의 맨 앞이 아니다.** 플레이어의 키(`fire()` → `strike()`)는 셸의
	# 입력 단계에서, 즉 `step()`보다 먼저 이 목록을 채운다. `step()`의 맨 앞에서 비우면 바로 그 프레임에
	# 지워지므로 자기 키로 죽인 몬스터만 파열이 안 뜬다 — `view`가 아니라 여전히 `sim` 스스로 비운다.
	w.step(1.0 / 60.0)
	t.eq(w.critters_died_this_frame.size(), 1,
			"step()은 이 목록을 비우지 않는다 — 그 자리에서 비우면 키로 낸 죽음이 그 프레임에 지워진다")
	w.begin_frame()
	t.eq(w.critters_died_this_frame.size(), 0, "프레임이 새로 시작하면(begin_frame) 목록은 비어 있다")


# -- 15: at half the FIRST BITE, half its progress — and NOTHING has been paid ----------------------------
## ⚠ **§C shrank the unit from "the whole meal" to "one bite".** A force-10 crow's meal is still 30 frames,
## but it is now three 10-frame bites, so "halfway" for THIS check is half of the first bite (5 frames), not
## half of the meal (15) — at 15 frames the first bite has already landed and `eaten` would have moved.
func _c15_eating_is_not_instant(t) -> void:
	var w := _standing_clone(421, CROW, 10)
	var eaten_before: float = w.swarm.eaten
	# The crow's first bite is 10 frames (measured), so five is half of IT.
	for _s in 5:
		w._step_corpses(DT)
	t.eq(w.corpse_count, 1, "절반 시점에 시체는 아직 거기 있다")
	t.ok(absf(w.corpse_progress[0] - 0.5) < 0.05,
			"그리고 첫 입의 진행도는 0.5 언저리다 — 물기는 즉시 끝나지 않는다 (%.3f)" % w.corpse_progress[0])
	t.eq(w.swarm.eaten, eaten_before, "그때까지 경험치는 한 점도 움직이지 않았다 — 첫 입도 아직 안 넘어갔다")


# -- 16: the meal is PROPORTIONAL to what died -----------------------------------------------------------
## ⚠ **`corpse_force` is written by hand on both sides.** A crow rolls 8–12, so a rolled one would make this
## ratio 15× or 10× by seed. A flat `EAT_TIME` constant is the mutation, and it makes the two counts equal.
##
## ⚠ **The boss takes 361 frames against an ideal 360, and that ONE frame is the whole tolerance.** A bite
## carries its overshoot into the next, so nine bites cost what one meal costs; the band below is one frame
## wide for that reason. It was nine frames wide while the overshoot was being discarded per bite — a
## tolerance sized to fit a defect. A flat constant (no proportionality at all) is still 300+ frames out.
func _c16_the_meal_is_proportional(t) -> void:
	var crow_frames := _frames_to_finish(422, CROW, 10)
	var boss_frames := _frames_to_finish(423, BOSS, 120)
	t.eq(crow_frames, CROW_MEAL, "힘 10짜리 까마귀는 서른 프레임(0.5초) 만에 다 먹힌다")
	t.eq(boss_frames, BOSS_MEAL, "보스는 361프레임(6초 + 마지막 한 입을 넘기는 한 프레임)이다")
	t.ok(boss_frames >= crow_frames * 12 and boss_frames <= crow_frames * 12 + 1,
			"딱 열두 배다 — 입을 아홉으로 쪼개도 총 시간은 그대로다 (%d / %d)" % [boss_frames, crow_frames])


# -- 17: forty on one corpse take exactly as long as one -------------------------------------------------
## ⚠ **The whole beat lives on this.** `progress += dt * eater_count` is one plausible character and it makes
## `1` and `V` — the two keys that put forty bodies on one point — delete the six-second meal they were
## built for.
func _c17_forty_take_as_long_as_one(t) -> void:
	# ⚠ **Pinned to a literal, not left as "whatever one body took".** Both loops cap at `BOUND`, so
	# `t.eq(frames, one)` alone would pass at 3000 == 3000 with the beat deleted in both directions.
	var one := _frames_to_finish(424, HORSE, 30)
	t.eq(one, HORSE_MEAL, "설정: 한 마리는 90프레임 걸린다 (%d)" % one)
	var w := World.new()
	w.setup(425)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1500.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = HORSE
	w.corpse_force[0] = 30
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = w._bites_for(30)
	for _i in 40:
		var c := w.swarm.add_clone(0, 4)
		w.swarm.pos[c] = at
	t.eq(w.swarm.count, 41, "설정: 분신 마흔이 한 시체 위에 섰다")
	var frames := 0
	var always_in_reach := true
	while w.corpse_count > 0 and frames < BOUND:
		var reach := w.corpse_reach(0, false)
		var any := false
		for i in range(1, w.swarm.count):
			if w.swarm.pos[i].distance_to(w.corpse_pos[0]) <= reach:
				any = true
				break
		if not any:
			always_in_reach = false
		w._step_corpses(DT)
		frames += 1
	t.ok(always_in_reach, "설정: 매 프레임 최소 한 분신이 사정거리 안에 있었다")
	t.eq(frames, one, "마흔이 달라붙어도 한 마리가 먹을 때와 정확히 같은 시간이 걸린다 (%d)" % frames)


# -- 18: progress is KEPT when the eater walks away ------------------------------------------------------
## ⚠ **§C shrank the unit `corpse_progress` measures.** 0.6 used to be 60% of the whole 30-frame meal (18
## frames); it is now 60% of the FIRST 10-frame BITE (6 frames) — `corpse_progress` resets every bite, so it
## never again reaches 0.6 of the whole meal on the way to 1.0.
func _c18_progress_is_kept(t) -> void:
	var straight := _frames_to_finish(426, CROW, 10)
	var w := _standing_clone(427, CROW, 10)
	var at: Vector2 = w.corpse_pos[0]
	var spent := 0
	while w.corpse_progress[0] < 0.6 and spent < BOUND:
		w._step_corpses(DT)
		spent += 1
	# The crow's first bite is 10 frames (measured), so 0.6 of IT is the sixth.
	t.eq(spent, 6, "설정: 첫 입의 0.6까지 여섯 프레임이 들었다 — 도는 횟수도 못 박는다 (%d)" % spent)
	t.ok(w.corpse_progress[0] >= 0.6 and w.corpse_count == 1,
			"설정: 첫 입의 60%%까지 먹고 멈췄다 (%.3f)" % w.corpse_progress[0])
	var paused: float = w.corpse_progress[0]
	w.swarm.pos[1] = at + Vector2(1000.0, 0.0)
	for _s in 30:
		w._step_corpses(DT)
	t.eq(w.corpse_progress[0], paused, "걸어가 버려도 진행도는 0으로 돌아가지 않는다")
	t.eq(w.corpse_count, 1, "그리고 시체도 그대로 있다")
	w.swarm.pos[1] = at
	while w.corpse_count > 0 and spent < BOUND:
		w._step_corpses(DT)
		spent += 1
	t.eq(spent, straight, "돌아와 마저 먹으면 서 있은 시간의 합은 처음부터 서 있은 것과 같다 (%d)" % spent)


# -- 19: who gets paid, and `eaten` moves exactly once ---------------------------------------------------
func _c19_who_gets_paid(t) -> void:
	# The clone's half: 1000px from home, so the payout lands where losing it on the way back still costs.
	var w := _standing_clone(428, HORSE, 30)
	var banked_before: float = w.swarm.banked
	var eaten_before: float = w.swarm.eaten
	t.ok(w.swarm.pos[1].distance_to(w.swarm.pos[0]) > 1000.0, "설정: 그 분신은 집에서 1000px 넘게 떨어져 있다")
	var horse_frames := 0
	while w.corpse_count > 0 and horse_frames < BOUND:
		w._step_corpses(DT)
		horse_frames += 1
	t.eq(horse_frames, HORSE_MEAL, "설정: 말 한 구는 90프레임 만에 끝났다 (%d)" % horse_frames)
	# 90 = 힘 30 × EXP_PER_FORCE 3, a literal — read back off `corpse_force` this passes at any rate.
	t.eq(w.swarm.carried[1], 90.0, "분신이 다 먹으면 그 값은 그 분신이 싣는다 (30 × 3)")
	t.eq(w.swarm.banked, banked_before, "은행에는 바로 들어오지 않는다")
	t.eq(w.swarm.eaten, eaten_before + 90.0, "먹은 총량은 딱 한 번, 90만큼 움직인다")

	# The host's half: the host banks instantly, because `eat(0, ...)` is what `banked` means.
	var w2 := World.new()
	w2.setup(429)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2.corpse_count = 1
	w2.corpse_pos[0] = w2.swarm.pos[0]
	w2.corpse_species[0] = CROW
	w2.corpse_force[0] = 10
	w2.corpse_progress[0] = 0.0
	w2.corpse_bites_left[0] = w2._bites_for(10)
	var eaten2: float = w2.swarm.eaten
	var host_frames := 0
	while w2.corpse_count > 0 and host_frames < BOUND:
		w2._step_corpses(DT)
		host_frames += 1
	t.eq(host_frames, CROW_MEAL, "설정: 호스트도 서른 프레임을 서 있었다 — 입이 빨라서 끝난 게 아니다 (%d)"
			% host_frames)
	t.eq(w2.swarm.banked, 30.0, "호스트가 다 먹으면 그 값은 곧바로 은행에 들어간다 (10 × 3)")
	t.eq(w2.swarm.eaten, eaten2 + 30.0, "그리고 먹은 총량도 딱 한 번 움직인다")


# -- 20: the part roll is the CLONE's path only ----------------------------------------------------------
## The host's parts come from cards and only from there. Ten horse corpses at `PART_DROP_CHANCE` 0.5 is a
## one-in-1024 coin flip if the guard is gone, so a single meal would not have been a check.
##
## ⚠ **§C's bite floor means one `_step_corpses()` call no longer finishes a corpse.** A force-30 horse is
## floored at three bites regardless of `corpse_progress`, so each meal now needs a loop through to
## `corpse_count == 0` rather than one call — `_add_corpse()` is used instead of hand-set rows, which is
## also the production path and sets `corpse_bites_left` for free.
func _c20_the_host_wears_nothing(t) -> void:
	var w := World.new()
	w.setup(430)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	for _n in 10:
		w._add_corpse(w.swarm.pos[0], HORSE, 30)
		var n := 0
		while w.corpse_count > 0 and n < BOUND:
			w._step_corpses(DT)
			n += 1
	t.eq(w.swarm.worn[0], -1, "호스트는 시체를 열 구 먹어도 아무것도 걸치지 않는다 — 호스트의 부품은 카드뿐이다")
	t.ok(w.swarm.banked >= 900.0, "설정: 그 열 구는 실제로 다 먹혔다 (%.0f)" % w.swarm.banked)


# -- 28: the BOSS's corpse ends the run ------------------------------------------------------------------
func _c28_the_boss_corpse_ends_the_run(t) -> void:
	var w := _standing_clone(431, CROW, 10)
	var n1 := 0
	while w.corpse_count > 0 and n1 < BOUND:
		w._step_corpses(DT)
		n1 += 1
	t.eq(n1, CROW_MEAL, "설정: 까마귀 한 구는 서른 프레임이다 (%d)" % n1)
	t.eq(w.stage_cleared, false, "까마귀를 다 먹어도 런은 끝나지 않는다")
	var w2 := _standing_clone(432, HORSE, 30)
	var n2 := 0
	while w2.corpse_count > 0 and n2 < BOUND:
		w2._step_corpses(DT)
		n2 += 1
	t.eq(n2, HORSE_MEAL, "설정: 말 한 구는 90프레임이다 (%d)" % n2)
	t.eq(w2.stage_cleared, false, "말을 다 먹어도 끝나지 않는다")
	var w3 := _standing_clone(433, BOSS, 120)
	t.eq(w3.stage_cleared, false, "설정: 보스 시체를 다 먹기 전에는 아직 열려 있다")
	var n3 := 0
	while w3.corpse_count > 0 and n3 < BOUND:
		w3._step_corpses(DT)
		n3 += 1
	t.eq(n3, BOSS_MEAL, "설정: 보스 한 구는 361프레임(아홉 입)이다 (%d)" % n3)
	t.eq(w3.stage_cleared, true, "보스 시체를 다 먹은 그때 런이 끝난다 — 죽인 순간이 아니라 먹은 순간이다")


# -- 34: `species_eaten` is in FIRST-EATEN order ---------------------------------------------------------
## Horse first on purpose: a snapshot that walked `Parts.SPECIES_NAME` instead of this array would come back
## in enum order and look right.
func _c34_first_eaten_order(t) -> void:
	var w := World.new()
	w.setup(434)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	_eat_one(w, HORSE, 30)
	_eat_one(w, CROW, 10)
	_eat_one(w, CROW, 12)
	# ⚠ **The label used to read 「집합이지 목록이 아니다」**, which states the reading `world.gd` explicitly
	# rejects: `_step_corpses`'s own comment says "First-eaten ORDER, not a set", and the two assertions
	# below measure the order. A future reader greps the label, not the code.
	t.eq(w.species_eaten.size(), 2, "같은 종은 두 번 적히지 않는다 — 중복 없는 목록이지 집합이 아니다")
	t.eq(int(w.species_eaten[0]), HORSE, "먼저 먹은 것이 먼저다 (말)")
	t.eq(int(w.species_eaten[1]), CROW, "그 다음이 까마귀다 — 순서가 곧 기록이다")


# -- 36: bite count derives from FORCE, floored at CORPSE_BITES_MIN ---------------------------------------
## The task's own four example forces, each inside a different species' range: crow 10, horse 35 (not the
## fixture's usual 30, so this is read off the formula and not copied from another check), elephant 80,
## boss 120.
func _c36_bite_count_derives_from_force(t) -> void:
	var w := World.new()
	w.setup(440)
	t.eq(w._bites_for(10), 3, "까마귀 힘 10 → 세 입 (바닥 CORPSE_BITES_MIN)")
	t.eq(w._bites_for(35), 3, "말 힘 35 → 세 입 (바닥에 걸린다 — 35 × 0.08 = 2.8)")
	t.eq(w._bites_for(80), 6, "코끼리 힘 80 → 여섯 입 (80 × 0.08 = 6.4)")
	t.eq(w._bites_for(120), 9, "보스 힘 120 → 아홉 입 (120 × 0.08 = 9.6)")


# -- 37: each bite pays exactly force × EXP_PER_FORCE / bites, not the whole meal --------------------------
## Driven to the FIRST bite's own rollover (`corpse_bites_left` ticking down once), not to a hand-picked
## frame count — the state change itself is the stopping condition, so this does not depend on knowing the
## bite's exact duration in frames.
func _c37_each_bite_pays_its_share(t) -> void:
	var w := _standing_clone(441, HORSE, 30)
	var eaten_before: float = w.swarm.eaten
	var start_bites: int = w.corpse_bites_left[0]
	t.eq(start_bites, 3, "설정: 말 시체는 세 입이다")
	var n := 0
	while w.corpse_count > 0 and w.corpse_bites_left[0] == start_bites and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.eq(w.corpse_bites_left[0], start_bites - 1, "설정: 첫 입이 넘어갔다")
	t.ok(absf(w.swarm.eaten - eaten_before - 30.0) < 0.001,
			"한 입은 전체 90의 3분의 1인 30을 지불한다 — 90 전부가 아니다 (%.3f)" % (w.swarm.eaten - eaten_before))
	while w.corpse_count > 0 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.ok(absf(w.swarm.eaten - eaten_before - 90.0) < 0.001,
			"세 입을 다 넘기면 합은 그대로 90이다 — 나눠 줘도 총량은 안 바뀐다 (%.3f)"
					% (w.swarm.eaten - eaten_before))


# -- 38: quitting mid-corpse KEEPS the bites already eaten ---------------------------------------------------
## **§C's actual rule change, driven end to end.** Two of the boss's nine bites are eaten, then the eater
## walks 5000px away — permanently out of reach, which is what "quitting the hunt" means in the sim. The old
## rule paid nothing until the whole meal finished; this one has already paid twice before the walk.
func _c38_quitting_keeps_the_bites_already_eaten(t) -> void:
	var w := _standing_clone(442, BOSS, 120)
	var at: Vector2 = w.corpse_pos[0]
	var n := 0
	while w.corpse_bites_left[0] > 7 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.eq(w.corpse_bites_left[0], 7, "설정: 아홉 입 중 둘을 먹었다")
	var paid: float = w.swarm.carried[1]
	t.ok(absf(paid - 80.0) < 0.001, "설정: 두 입이면 이미 80을 실었다 (120 × 3 / 9 × 2) (%.3f)" % paid)
	w.swarm.pos[1] = at + Vector2(5000.0, 0.0)
	for _s in 120:
		w._step_corpses(DT)
	t.eq(w.swarm.carried[1], paid, "물러나도 이미 먹은 두 입의 값은 그대로 실려 있다 — 중단이 전부를 잃게 하지 않는다")
	t.eq(w.corpse_bites_left[0], 7, "시체도 두 입 먹힌 채 그대로 남는다 — 되돌아가지 않는다")
	t.eq(w.corpse_count, 1, "그리고 아직 사라지지 않았다 — 남은 일곱 입은 나중에도 그대로다")


# -- 39: species_eaten AND stage_cleared wait for the LAST bite --------------------------------------------
## The task's own case: eat eight of the boss's nine bites and show the run has not ended.
func _c39_species_eaten_and_stage_cleared_wait_for_the_last_bite(t) -> void:
	var w := _standing_clone(443, BOSS, 120)
	var n := 0
	while w.corpse_bites_left[0] > 1 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.eq(w.corpse_bites_left[0], 1, "설정: 아홉 입 중 여덟을 먹었다 — 마지막 한 입만 남았다")
	t.eq(w.corpse_count, 1, "그리고 시체는 아직 있다 — 런이 끝나지 않았다")
	t.ok(not w.species_eaten.has(BOSS), "species_eaten엔 아직 보스가 없다 — 여덟 입은 마지막이 아니다")
	t.eq(w.stage_cleared, false, "여덟 입을 먹어도 런은 아직 끝나지 않는다")
	while w.corpse_count > 0 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.ok(w.species_eaten.has(BOSS), "아홉 번째 입에서 비로소 보스가 species_eaten에 오른다")
	t.eq(w.stage_cleared, true, "그리고 그 순간 런이 끝난다 — 죽인 순간이 아니라 마지막 입을 삼킨 순간이다")


# -- 40: the part roll waits for the LAST bite ---------------------------------------------------------------
## ⚠ **A BOSS corpse cannot measure this at all** — `Parts.DROPS` has no droppable row for the boss, so
## `_roll_part(eater, BOSS)` writes nothing whether it is gated to the last bite or fires on every one; the
## check would be blind by construction. A HORSE corpse (말 다리 droppable at `PART_DROP_CHANCE` 0.5) can.
##
## `worn` staying `-1` after ONE non-last bite is not itself a coin flip — `_roll_part` is structurally never
## CALLED before the last bite, so a single trial already proves the call didn't happen. What IS a coin flip
## is whether a MUTATION that fires the roll on every bite would be caught: with one trial it would only be
## caught half the time. Twenty corpses, all built and stepped TOGETHER (so a swap from an early finisher
## cannot desync a later index — nothing finishes here at all, every one stops after its first bite), make
## that miss chance `0.5^20`, effectively zero.
func _c40_the_part_roll_waits_for_the_last_bite(t) -> void:
	var w := World.new()
	w.setup(444)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var clones := PackedInt32Array()
	for i in 20:
		var at := Vector2(200.0 + float(i) * 150.0, 500.0)
		var c := w.swarm.add_clone(0, 4)
		w.swarm.pos[c] = at
		clones.append(c)
		w._add_corpse(at, HORSE, 30)
		t.eq(w.corpse_bites_left[i], 3, "설정: 말 시체 %d는 세 입이다" % i)
	var n := 0
	while w.corpse_bites_left[0] == 3 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	for i in 20:
		t.eq(w.corpse_bites_left[i], 2, "설정: 스무 구 모두 첫 입만 넘어갔다 (%d)" % i)
		t.eq(int(w.swarm.worn[clones[i]]), -1,
				"굴림은 마지막 입에서만 — 첫 입에서는 스무 구 전부 아직 아무것도 안 걸친다 (%d)" % i)


# -- E1: `_remove_corpse`'s FIVE-column swap ---------------------------------------------------------------
## ⚠ **The row removed is not the last one.** The plan writes this function's justification and gives it no
## check at all; a missing column lands a consumed corpse's progress or worth on a survivor, and the number
## it keeps is the one that just paid out, so the next meal is free.
##
## ⚠ **`corpse_bites_left[2]` is written 7, deliberately NOT `_bites_for(120)` (9).** The destination row's
## zero-fill is 0 either way, so a plain finite value would already have teeth — but a wrong swap that
## silently RECOMPUTES the count from force instead of copying the stored one would read back 9 and pass a
## `!= 0` check. 7 catches that specific shape too: `_bites_for` never returns 7 for any of the three forces
## on this table.
func _e1_removal_swap(t) -> void:
	var w := World.new()
	w.setup(435)
	w.corpse_count = 3
	w.corpse_pos[0] = Vector2(10.0, 10.0)
	w.corpse_species[0] = CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.1
	w.corpse_bites_left[0] = 2
	w.corpse_pos[1] = Vector2(20.0, 20.0)
	w.corpse_species[1] = HORSE
	w.corpse_force[1] = 30
	w.corpse_progress[1] = 0.2
	w.corpse_bites_left[1] = 1
	w.corpse_pos[2] = Vector2(30.0, 30.0)
	w.corpse_species[2] = BOSS
	w.corpse_force[2] = 120
	w.corpse_progress[2] = 0.3
	w.corpse_bites_left[2] = 7
	w._remove_corpse(0)
	t.eq(w.corpse_count, 2, "설정: 마지막이 아닌 줄을 지웠다")
	t.eq(w.corpse_pos[0], Vector2(30.0, 30.0), "마지막 줄이 제 자리를 들고 내려왔다")
	t.eq(w.corpse_bites_left[0], 7, "남은 입 수도 제 것을 들고 내려왔다 — 힘에서 다시 굴린 9가 아니라 저장된 7이다")
	t.eq(int(w.corpse_species[0]), BOSS, "제 종도 들고 왔다")
	t.eq(int(w.corpse_force[0]), 120, "제 힘도 들고 왔다")
	t.ok(absf(w.corpse_progress[0] - 0.3) < 0.0001, "제 진행도도 들고 왔다 — 남의 식사를 이어받지 않는다")


# -- E2: at `CORPSE_MAX` a kill leaves nothing, and NOTHING is evicted ------------------------------------
## "I came back and my kill was gone" is a bug report; a kill in the middle of a pile of sixty-four that
## quietly paid nothing is one confused frame.
func _e2_the_cap_evicts_nothing(t) -> void:
	var w := World.new()
	w.setup(436)
	w.corpse_count = 0
	for i in 65:
		w._add_corpse(Vector2(float(i), 0.0), CROW, 8 + i)
	t.eq(w.corpse_count, 64, "시체는 CORPSE_MAX(64)에서 멈춘다 (리터럴)")
	t.eq(int(w.corpse_force[0]), 8, "가장 오래된 시체는 제 힘 그대로 남아 있다 — 밀려나지 않는다")
	t.eq(w.corpse_pos[0], Vector2(0.0, 0.0), "그 자리도 그대로다")
	t.eq(int(w.corpse_force[63]), 71, "예순네 번째까지는 들어왔다 (8 + 63)")


# -- E3: the reach carries the CORPSE's own size ---------------------------------------------------------
## ⚠ **Against literals, not against `Rules.BODY_RADIUS`.** `EAT_RADIUS_HOST` is already 26 and the body is
## 14, so `corpse_reach(i, true) > BODY_RADIUS` is true with the corpse's size dropped from the sum entirely
## — the second term would be free and this would be a third copy of a constant check wearing a corpse's
## name.
func _e3_reach_carries_the_corpse_size(t) -> void:
	var w := World.new()
	w.setup(437)
	w.corpse_count = 2
	w.corpse_pos[0] = Vector2(100.0, 100.0)
	w.corpse_species[0] = BOSS
	w.corpse_force[0] = 120
	w.corpse_progress[0] = 0.0
	w.corpse_pos[1] = Vector2(200.0, 200.0)
	w.corpse_species[1] = CROW
	w.corpse_force[1] = 8
	w.corpse_progress[1] = 0.0
	t.ok(absf(w.corpse_radius(0) - 38.4) < 0.001,
			"보스 시체의 반지름은 48 × 0.8 = 38.4다 (%.3f)" % w.corpse_radius(0))
	t.ok(absf(w.corpse_reach(0, true) - 64.4) < 0.001,
			"호스트는 보스 시체를 64.4px에서 먹는다 (26 + 38.4, 리터럴) (%.3f)" % w.corpse_reach(0, true))
	t.ok(absf(w.corpse_reach(0, false) - 54.4) < 0.001,
			"분신은 54.4px에서 먹는다 (16 + 38.4) (%.3f)" % w.corpse_reach(0, false))
	t.ok(absf(w.corpse_reach(1, true) - 35.6) < 0.001,
			"까마귀 시체는 그보다 훨씬 좁다 — 35.6px (26 + 9.6) (%.3f)" % w.corpse_reach(1, true))
	t.ok(absf(w.corpse_reach(1, false) - 25.6) < 0.001,
			"분신에게는 25.6px다 (16 + 9.6) (%.3f)" % w.corpse_reach(1, false))


# -- E4: one corpse per BODY -----------------------------------------------------------------------------
## Two corpses 20px apart with one clone in reach of both. Iterating corpses and finding eaters per corpse
## advances both, so a pile finishes in the time of its slowest member instead of one at a time.
func _e4_one_corpse_per_body(t) -> void:
	var w := World.new()
	w.setup(438)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var mid := Vector2(1500.0, 1000.0)
	w.corpse_count = 2
	w.corpse_pos[0] = mid + Vector2(-10.0, 0.0)
	w.corpse_species[0] = CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	w.corpse_pos[1] = mid + Vector2(10.0, 0.0)
	w.corpse_species[1] = CROW
	w.corpse_force[1] = 10
	w.corpse_progress[1] = 0.0
	var c := w.swarm.add_clone(0, 4)
	w.swarm.pos[c] = mid
	t.ok(w.corpse_reach(0, false) > 10.0 and w.corpse_reach(1, false) > 10.0,
			"설정: 그 분신은 두 시체 모두의 사정거리 안이다 (%.1f)" % w.corpse_reach(0, false))
	w._step_corpses(DT)
	var moved := 0
	if w.corpse_progress[0] > 0.0:
		moved += 1
	if w.corpse_progress[1] > 0.0:
		moved += 1
	t.eq(moved, 1, "한 몸은 한 번에 한 구만 먹는다 — 더미 위에 서서 전부를 갉지 않는다")


# -- U6a: the HOST eats it, whoever else is standing there ------------------------------------------------
## ⚠ **The `break` in `for bi in swarm.count: if pick[bi] == ci: eater = bi; break` was free.** Deleting it
## keeps the LAST body in reach instead of the first, and row 0 is the host — so you stand on your own kill
## and the 경험치 lands in a clone's `carried` instead of `banked`, where losing the clone on the way home
## costs you the meal. `_roll_part` fires too, because `eater > 0`. Nothing in final state says which body
## ate; only the two accounts do.
func _u6a_the_host_eats_first(t) -> void:
	var w := World.new()
	w.setup(445)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at := Vector2(1500.0, 1000.0)
	w.swarm.pos[0] = at
	var c := w.swarm.add_clone(0, 4)
	w.swarm.pos[c] = at
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = w._bites_for(10)
	t.eq(w.swarm.count, 2, "설정: 호스트와 분신이 같은 시체 위에 함께 섰다")
	t.eq(c, 1, "설정: 그 분신은 1번 줄이다 — 첫 일치와 마지막 일치가 서로 다른 줄이다")
	var n := 0
	while w.corpse_count > 0 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.eq(n, CROW_MEAL, "설정: 서른 프레임에 다 먹혔다 (%d)" % n)
	t.eq(w.swarm.banked, 30.0, "둘 다 닿아 있으면 먹는 것은 호스트다 — 30이 곧바로 은행에 들어간다 (10 × 3)")
	t.eq(w.swarm.carried[c], 0.0, "분신의 화물은 한 점도 움직이지 않는다")
	t.eq(int(w.swarm.worn[c]), -1, "그리고 분신은 부품도 굴리지 않는다 — 굴림은 분신이 먹었을 때만이다")


# -- U6b: the NEAREST corpse in reach, not the lowest row -------------------------------------------------
## ⚠ **The near corpse is the LATER row on purpose.** With the near one at index 0, `if best < 0 or
## d < best_d:` → `if best < 0:` picks the same corpse and the check is green on the mutation it exists for.
## Runtime: a body standing in a pile eats whichever carcass happens to sit lowest in the table.
func _u6b_the_nearest_corpse_first(t) -> void:
	var w := World.new()
	w.setup(446)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at := Vector2(1500.0, 1000.0)
	w.swarm.pos[0] = at
	var far := at + Vector2(30.0, 0.0)
	var near := at + Vector2(5.0, 0.0)
	w.corpse_count = 2
	w.corpse_pos[0] = far
	w.corpse_species[0] = CROW
	w.corpse_force[0] = 10
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = w._bites_for(10)
	w.corpse_pos[1] = near
	w.corpse_species[1] = CROW
	w.corpse_force[1] = 10
	w.corpse_progress[1] = 0.0
	w.corpse_bites_left[1] = w._bites_for(10)
	# 38.0 = EAT_RADIUS_HOST 26 + a force-10 crow corpse's 12.0, by hand: both 5 and 30 sit inside it.
	t.ok(absf(w.corpse_reach(0, true) - 38.0) < 0.001,
			"설정: 호스트는 이 시체를 38px에서 먹는다 — 두 구 다 사정거리 안이다 (%.2f)"
					% w.corpse_reach(0, true))
	w._step_corpses(DT)
	t.ok(w.corpse_progress[1] > 0.0, "가까운 쪽(늦은 줄)이 먹히기 시작한다 (%.4f)" % w.corpse_progress[1])
	t.eq(w.corpse_progress[0], 0.0, "그리고 먼 쪽(첫 줄)은 한 점도 안 줄었다 — 표의 순서가 아니라 거리다")
	var n := 1
	while w.corpse_count > 1 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	t.eq(n, CROW_MEAL, "설정: 서른 프레임에 한 구가 끝났다 (%d)" % n)
	t.eq(w.corpse_pos[0], far, "먼저 사라진 것은 가까운 쪽이고, 남은 것은 먼 쪽이다")
	t.eq(w.corpse_progress[0], 0.0, "남은 그 구는 여전히 손도 안 댄 채다")


# -- U6c: a clone eats at a CLONE's reach ------------------------------------------------------------------
## ⚠ **`corpse_reach(ci, bi == 0)` → `corpse_reach(ci, true)` was green.** `corpse_reach` is pinned as a
## pure function by `_e3`, and the forty-clone fixture in `_c17` places every clone at distance **0** from
## the corpse and reads its own bound back off `w.corpse_reach(0, false)` — so nothing in the round could
## tell 16px from 26px. CLAUDE.md's "a check whose bounds come from the thing it checks", verbatim.
##
## 25.6 and 35.6 are `_e3`'s literals for a force-8 crow (radius 12.0 × 0.8 = 9.6). 30px is the one band
## between them, and the host is 1900px away so it cannot be the eater.
func _u6c_a_clone_eats_at_the_clones_own_reach(t) -> void:
	var w := World.new()
	w.setup(447)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var at := Vector2(1500.0, 1000.0)
	var c := w.swarm.add_clone(0, 4)
	w.swarm.pos[c] = at + Vector2(30.0, 0.0)
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = CROW
	w.corpse_force[0] = 8
	w.corpse_progress[0] = 0.0
	t.ok(absf(w.corpse_reach(0, false) - 25.6) < 0.001,
			"설정: 분신의 사정거리는 25.6px다 (16 + 9.6, 리터럴) (%.2f)" % w.corpse_reach(0, false))
	t.ok(absf(w.corpse_reach(0, true) - 35.6) < 0.001,
			"설정: 호스트라면 35.6px다 (26 + 9.6) — 30px는 그 둘 사이다 (%.2f)" % w.corpse_reach(0, true))
	t.ok(w.swarm.pos[0].distance_to(at) > 1000.0, "설정: 호스트는 1000px 밖이라 먹을 후보가 아니다")
	for _s in 60:
		w._step_corpses(DT)
	t.eq(w.corpse_progress[0], 0.0,
			"30px에 선 분신은 1초를 서 있어도 한 점도 못 먹는다 — 분신에게 호스트의 입을 주지 않는다")
	w.swarm.pos[c] = at + Vector2(20.0, 0.0)
	w._step_corpses(DT)
	t.ok(w.corpse_progress[0] > 0.0,
			"대조: 20px로 다가서면 그 자리에서 먹기 시작한다 — 아무도 안 먹는 검사가 아니다 (%.4f)"
					% w.corpse_progress[0])


# -- fixtures ---------------------------------------------------------------------------------------------
## One clone standing on one corpse, 1000px from the host, on cleared ground with no food and no creatures.
## The clone is index 1 and the corpse is index 0 in every caller.
##
## `corpse_bites_left[0]` is set through `_bites_for()`, the SAME call `_add_corpse()` makes — a hand-built
## row that skipped it opened at the zero-fill (0 bites left), which finishes on the very first bite instead
## of the real count and reads back an exp payout a third (or a ninth) of the real meal.
func _standing_clone(seed_value: int, species: int, force_value: int) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	var at := Vector2(500.0, 500.0)
	var c := w.swarm.add_clone(0, 4)
	w.swarm.pos[c] = at
	w.corpse_count = 1
	w.corpse_pos[0] = at
	w.corpse_species[0] = species
	w.corpse_force[0] = force_value
	w.corpse_progress[0] = 0.0
	w.corpse_bites_left[0] = w._bites_for(force_value)
	return w


## How many frames one body standing still takes to finish one corpse. The bound is a runaway guard, not a
## tolerance: a count that reaches it is reported as itself and every literal above goes red by name.
func _frames_to_finish(seed_value: int, species: int, force_value: int) -> int:
	var w := _standing_clone(seed_value, species, force_value)
	var n := 0
	while w.corpse_count > 0 and n < BOUND:
		w._step_corpses(DT)
		n += 1
	return n


## Finish one corpse at the host's own feet, for the checks that only care that a species was recorded.
##
## ⚠ **§C floors every corpse at `CORPSE_BITES_MIN` (3) bites regardless of `corpse_progress`.** One
## `_step_corpses()` call at `progress = 0.999` used to finish the whole corpse; now it only closes the
## FIRST of (at least) three, so this loops to `corpse_count == 0` instead of calling once. `progress =
## 0.999` still fast-forwards that first bite — only the remaining ones take their real duration.
func _eat_one(w: World, species: int, force_value: int) -> void:
	w.corpse_count = 1
	w.corpse_pos[0] = w.swarm.pos[0]
	w.corpse_species[0] = species
	w.corpse_force[0] = force_value
	w.corpse_progress[0] = 0.999
	w.corpse_bites_left[0] = w._bites_for(force_value)
	var n := 0
	while w.corpse_count > 0 and n < BOUND:
		w._step_corpses(DT)
		n += 1


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
