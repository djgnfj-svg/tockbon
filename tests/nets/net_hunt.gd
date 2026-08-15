extends RefCounted
## Hitting and being hit: the cone, the two directions damage runs in, and the three hands the field is
## made of.
##
## **The threat model is gone from this file entirely.** A creature no longer becomes prey or hunter by
## comparison; its disposition comes from its species and its damage is its own force, both ways. What is
## left to measure is the geometry (does the cone reach it, does the target's own size count) and the
## exchange (how many hits, in which direction, on whose clock).
##
## ⚠ **The six dash and walk checks that used to open this file moved to `net_hands`.** They contain no
## creature and they are the last thing that would still hold this file to its old subject.
##
## ⚠ **The speed ordering is the one thing here that is not a fixture.** It is six literals against six
## literals, because the chain is what the whole stage rests on: nothing sustained catches the horse, an
## abandoned clone never gets home, and the boss is the ONE creature below the host — which is what "you can
## walk away from it, until the arena closes" means. `rules.gd` states the chain in prose and nothing was
## watching the numbers.

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)
const BOSS := int(Parts.Species.BOSS)


func run(t) -> void:
	_c7_the_speed_ordering(t)
	_h1_the_gallop_stays_under_the_horse(t)
	_c6_the_horse_cannot_be_caught(t)
	_c8_the_crow_stands_and_counters(t)
	_c9_the_cone_hits_everything(t)
	_c10_reach_carries_the_target_size(t)
	_c11_damage_is_the_attackers_force(t)
	_h2_the_boss_out_reaches_the_bite(t)
	_c12_a_clone_is_damaged_not_deleted(t)
	_c12b_the_cargo_is_read_before_the_swap(t)
	_c12c_a_clones_hp_is_its_own(t)
	_c13_a_clone_attacks_on_its_own_clock(t)
	_h3_a_clone_is_a_wall(t)
	_h3b_an_overlapped_creature_can_still_leave(t)
	_h4_the_boss_walks_through_the_ring(t)
	_h5_the_key_reaches_the_world(t)
	_h6_a_clone_reaches_only_as_far_as_what_it_wears(t)
	_h7_a_dead_centre_target_does_not_open_the_cone(t)
	_h8_a_bystanders_death_is_not_the_touchers(t)
	_h9_the_cone_has_a_ceiling(t)
	_h10_the_clones_swing_is_aimed_at_what_it_touched(t)
	_u14_the_host_can_only_be_hit_once_a_second(t)


# -- 7: the chain, literal to literal --------------------------------------------------------------------
func _c7_the_speed_ordering(t) -> void:
	var horse := Rules.HOST_SPEED * float(Rules.SPECIES_SPEED_MUL[HORSE])
	var boss := Rules.HOST_SPEED * float(Rules.SPECIES_SPEED_MUL[BOSS])
	var crow := Rules.HOST_SPEED * float(Rules.SPECIES_SPEED_MUL[CROW])
	t.ok(absf(horse - 230.0) < 0.01, "말은 230px/s다 (%.2f)" % horse)
	t.ok(absf(Rules.CLONE_SPEED_FOLLOW - 215.0) < 0.01, "따라오는 분신은 215px/s다")
	t.ok(absf(Rules.HOST_SPEED - 200.0) < 0.01, "호스트는 200px/s다")
	t.ok(absf(boss - 150.0) < 0.01, "보스는 150px/s다 (%.2f)" % boss)
	t.ok(absf(Rules.CLONE_SPEED_SCATTER - 125.0) < 0.01, "흩어진 분신은 125px/s다")
	t.ok(absf(crow - 110.0) < 0.01, "까마귀는 110px/s다 (%.2f)" % crow)
	t.ok(horse > Rules.CLONE_SPEED_FOLLOW and Rules.CLONE_SPEED_FOLLOW > Rules.HOST_SPEED,
			"말 > 따라오는 분신 > 호스트 — 지속 속도로는 아무도 말을 못 잡는다")
	t.ok(Rules.HOST_SPEED > boss and boss > Rules.CLONE_SPEED_SCATTER
			and Rules.CLONE_SPEED_SCATTER > crow,
			"호스트 > 보스 > 흩어진 분신 > 까마귀")
	# ⚠ **Read left to right the chain hides which side of the host each number sits on**, and the boss's
	# side is the whole of "you can walk away from it". It gets its own line for that reason.
	t.ok(boss < Rules.HOST_SPEED,
			"보스는 호스트보다 느린 유일한 생물이다 — 그래서 걸어서 달아날 수 있고, 아레나가 그 선택지를 뺏는다")
	t.ok(Rules.CLONE_SPEED_SCATTER < Rules.HOST_SPEED, "흩어진 분신은 호스트보다 느리다 — 흩어짐은 값을 치른다")


# -- H1: 갤럽 stays under the horse ----------------------------------------------------------------------
## The stage's central mechanic is that nothing sustained catches the horse, and the stage's own first
## reward is a speed part. At `SELF_MUL` 1.8 the gallop is 360 and the mechanic is deleted by the reward.
func _h1_the_gallop_stays_under_the_horse(t) -> void:
	var gallop := Rules.HOST_SPEED * float(Parts.SELF_MUL[Parts.HORSE_LEGS])
	var horse := Rules.HOST_SPEED * float(Rules.SPECIES_SPEED_MUL[HORSE])
	t.ok(absf(gallop - 220.0) < 0.01, "갤럽을 다 켜도 220px/s다 (%.2f)" % gallop)
	t.ok(gallop < horse, "그리고 그것도 말의 230보다 느리다 — 말은 몰아야지 쫓아서는 못 잡는다")


# -- 6: the gap GROWS ------------------------------------------------------------------------------------
## A clone sent at the horse every frame walks at `CLONE_SPEED_FOLLOW`, which is the fastest sustained speed
## any body has. Five seconds of it and the horse is further away than it started.
func _c6_the_horse_cannot_be_caught(t) -> void:
	var w := World.new()
	w.setup(51)
	_silence_food(w)
	_clear_terrain(w)
	# The host sits outside `CRITTER_SENSE` of the horse, so the body the horse runs from is the clone.
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var c := w.swarm.add_clone(0, 2)
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, Vector2(1300.0, 1000.0), 30)
	w.critter_dir[0] = Vector2.ZERO
	var before: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(absf(before - 300.0) < 0.01, "설정: 300px 뒤에서 쫓기 시작한다 (%.2f)" % before)
	for _s in 300:
		# Re-aimed every frame, so this is a chase and not a walk toward where the horse used to be.
		w.swarm.command_strike(w.critter_pos[0])
		w.step(DT)
	var after: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(after > before,
			"가장 빠른 몸으로 5초를 쫓아도 사이는 오히려 벌어진다 (%.0f → %.0f)" % [before, after])
	t.ok(w.swarm.pos[c].distance_to(Vector2(1000.0, 1000.0)) > 500.0,
			"설정: 그동안 분신은 실제로 쫓아 달렸다 (%.0f px)"
					% w.swarm.pos[c].distance_to(Vector2(1000.0, 1000.0)))


# -- 8: it stands, it is hit, it comes, it stops ---------------------------------------------------------
## Three phases in one fixture, because "it never moves" and "it moves when hit" and "it stops again" each
## pass against the others' bug.
func _c8_the_crow_stands_and_counters(t) -> void:
	var w := World.new()
	w.setup(52)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1000.0, 1300.0), 10)
	# ⚠ **A UNIT direction, and `Vector2.ZERO` here made this unfalsifiable once**: a crow is born with a
	# random heading, so zeroing it in the fixture makes "it did not move" the setup's doing.
	w.critter_dir[0] = Vector2.RIGHT
	w.critter_hp[0] = 900
	var stood: Vector2 = w.critter_pos[0]
	for _s in 120:
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(stood) < 0.001,
			"맞기 전의 까마귀는 2초를 서 있어도 한 발짝도 움직이지 않는다")

	w._damage_critter(0, 1)
	t.eq(w.critter_counter[0], Rules.CROW_COUNTER_TIME, "설정: 한 대 맞자 반격 시계가 걸렸다")
	var gap0: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	for _s in 60:
		w._step_critters(DT)
	var gap1: float = w.critter_pos[0].distance_to(w.swarm.pos[0])
	t.ok(gap1 < gap0 - 100.0, "맞은 까마귀는 가장 가까운 몸을 향해 걸어온다 (%.0f → %.0f)" % [gap0, gap1])

	# Past `CROW_COUNTER_TIME` and a tenth of a second more, then long enough that a still-running counter
	# could not hide.
	for _s in 66:
		w._step_critters(DT)
	t.eq(w.critter_counter[0], 0.0, "설정: 2.1초가 지나 반격 시계가 실제로 꺼졌다")
	var stopped: Vector2 = w.critter_pos[0]
	for _s in 60:
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(stopped) < 0.001,
			"시계가 꺼지면 다시 선다 — 한 번 맞았다고 영영 쫓아오지 않는다")


# -- 9: the cone hits EVERY creature in it ---------------------------------------------------------------
## A cone that hits one target is a different weapon, and *how many it hits* is the axis the next habitat's
## parts vary. `return` after the first hit is the mutation.
func _c9_the_cone_hits_everything(t) -> void:
	var w := World.new()
	w.setup(53)
	_silence_food(w)
	_clear_terrain(w)
	var origin := Vector2(1000.0, 1000.0)
	w.swarm.pos[0] = origin
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1040.0, 1000.0), 10)
	w._write_critter(CROW, Vector2(1050.0, 1010.0), 10)
	w._write_critter(CROW, Vector2(1055.0, 990.0), 10)
	# Behind the host: inside the reach, outside the arc. The angle is the skill.
	w._write_critter(CROW, Vector2(940.0, 1000.0), 10)
	var hits := w.strike(origin, Vector2.RIGHT, Parts.BITE, 5)
	t.eq(hits, 3, "원뿔 안의 셋을 전부 맞힌다 — 가장 가까운 하나가 아니다")
	t.eq(int(w.critter_hp[0]), 25, "앞의 첫 마리가 깎였다")
	t.eq(int(w.critter_hp[1]), 25, "둘째도 깎였다")
	t.eq(int(w.critter_hp[2]), 25, "셋째도 깎였다")
	t.eq(int(w.critter_hp[3]), 30, "뒤에 선 놈은 사거리 안이어도 한 점도 안 깎인다")


# -- 10: reach includes the TARGET's radius --------------------------------------------------------------
## ⚠ **Literal coordinates, never `Parts.RANGE[BITE] + critter_radius(k)` read back.** A bound taken from
## the thing under test shrinks with it. 110px is `RANGE 70 + 40`: the boss's own 48 covers it and the
## crow's 15 does not.
func _c10_reach_carries_the_target_size(t) -> void:
	var origin := Vector2(1000.0, 1000.0)
	var w := World.new()
	w.setup(54)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = origin
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, Vector2(1110.0, 1000.0), 120)
	t.eq(w.strike(origin, Vector2.RIGHT, Parts.BITE, 5), 1,
			"110px 앞의 보스는 물린다 — 70px 사거리에 제 몸 48px가 더해진다")

	var w2 := World.new()
	w2.setup(55)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = origin
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, Vector2(1110.0, 1000.0), 10)
	t.eq(w2.strike(origin, Vector2.RIGHT, Parts.BITE, 5), 0,
			"같은 110px 앞의 까마귀는 안 물린다 — 제 몸이 15px뿐이다")
	t.eq(int(w2.critter_hp[0]), 30, "그래서 체력도 그대로다")


# -- 11: damage is the attacker's force, in BOTH directions ----------------------------------------------
## ⚠ **Three attacker forces in one check, and that is what makes it bite.** The natural hardcode is 10 and
## it satisfies "three hits on a 30-hp crow" perfectly; 15 and 5 are what tell a constant from the row.
func _c11_damage_is_the_attackers_force(t) -> void:
	t.eq(_hits_to_kill(56, 10), 3, "힘 10이 체력 30짜리 까마귀를 죽이는 데 세 번 든다")
	t.eq(_hits_to_kill(57, 15), 2, "힘 15면 두 번이다")
	t.eq(_hits_to_kill(58, 5), 6, "힘 5면 여섯 번이다 — 상수 하나로는 셋을 다 만족시킬 수 없다")

	# The other direction, and it is the whole of "the boss is not gated": one touch ends the run.
	# ⚠ The swarm is pinned at one body, so the host is unambiguously what `_contact`'s second pass reaches.
	var w := World.new()
	w.setup(59)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, w.swarm.pos[0], 120)
	t.eq(w.swarm.count, 1, "설정: 무리는 호스트 하나뿐이다")
	t.eq(w.host_hp, 30, "설정: 호스트는 체력 30으로 서 있다")
	w._contact(0, w.critter_pos[0])
	t.eq(w.host_hp, -90, "보스가 닿으면 제 힘 120이 그대로 들어온다 — 한 번 닿으면 런이 끝난다")


# -- H2: the boss out-reaches 물기 -----------------------------------------------------------------------
## ⚠ **The relation is the half that matters.** Written as literals alone, 70 is a second copy of
## `Parts.RANGE[BITE]` stated only in prose, and retuning 물기 to 80 silently re-opens a band in which a
## force-10 host kills a 360-hp boss backpedalling, damage-free.
func _h2_the_boss_out_reaches_the_bite(t) -> void:
	t.ok(float(Rules.SPECIES_REACH_BONUS[BOSS]) >= float(Parts.RANGE[Parts.BITE]),
			"보스의 덤 사거리는 물기의 사거리 이상이다 — 리터럴이 아니라 관계로 못 박는다 (%.1f >= %.1f)"
					% [float(Rules.SPECIES_REACH_BONUS[BOSS]), float(Parts.RANGE[Parts.BITE])])
	var w := World.new()
	w.setup(60)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, Vector2(1000.0, 1000.0), 120)
	# 132 = 48 + 70 + BODY_RADIUS 14; 118 = 70 + 48. Both by hand.
	t.ok(absf(w.critter_reach(0) + Rules.BODY_RADIUS - 132.0) < 0.01,
			"보스는 132px에서 호스트에 닿는다 (48 + 70 + 14, 리터럴) (%.2f)"
					% (w.critter_reach(0) + Rules.BODY_RADIUS))
	t.ok(w.critter_reach(0) + Rules.BODY_RADIUS > float(Parts.RANGE[Parts.BITE]) + w.critter_radius(0),
			"그건 물기가 닿는 118px보다 멀다 — 공짜로 때릴 수 있는 띠가 없다")


# -- 12: a creature reaching a clone DAMAGES it ----------------------------------------------------------
## ⚠ **The plan said it kills it outright and the user said otherwise.** A clone has hp like anything else,
## and it loses its cargo, its force and its worn part only when that hp reaches zero.
##
## The crow's own hp is written up to 300 on purpose: the clone hits back on the same 1.2s clock, so at the
## crow's real 30 the crow would die first and this exchange would never reach its third round. What a bite
## does to a crow is check 9's and check 11's subject.
func _c12_a_clone_is_damaged_not_deleted(t) -> void:
	var w := World.new()
	w.setup(61)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(500.0, 500.0)
	var c := w.swarm.add_clone(0, 10)
	w.swarm.pos[c] = at
	w.swarm.carried[c] = 5.0
	w.swarm.worn[c] = Parts.CROW_FOOT
	var far := w.swarm.add_clone(0, 3)
	w.swarm.pos[far] = Vector2(2500.0, 2500.0)
	w.swarm.command_strike(at)
	# The far clone is sent to its own spot so nothing walks; STRIKE stops inside `rally_radius`.
	w.swarm.state[far] = Swarm.FOLLOW
	w.swarm.pos[far] = Vector2(2500.0, 2500.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at + Vector2(5.0, 0.0), 10)
	w.critter_hp[0] = 300
	t.eq(int(w.swarm.hp[c]), 30, "설정: 힘 10짜리 분신은 체력 30으로 태어난다")
	var lost_before: int = w.clones_lost

	w.step(DT)
	t.eq(int(w.swarm.hp[c]), 20, "까마귀에게 닿은 분신은 제 힘만큼 깎일 뿐 죽지 않는다 (30 → 20)")
	t.eq(w.swarm.count, 3, "무리의 수도 그대로다")
	t.eq(w.cargo_lost, 0.0, "잃은 화물도 아직 0이다")
	t.eq(w.clones_lost, lost_before, "잃은 분신 수도 아직 그대로다")

	for _s in 80:
		w.step(DT)
	t.eq(int(w.swarm.hp[c]), 10, "한 주기 뒤 두 번째 대에 10이 된다")
	t.eq(w.swarm.count, 3, "그래도 아직 살아 있다")

	for _s in 80:
		w.step(DT)
	t.eq(w.swarm.count, 2, "세 번째 대에 비로소 죽는다")
	t.eq(w.cargo_lost, 5.0, "그리고 그때서야 싣고 있던 것이 손실로 잡힌다")
	t.eq(w.clones_lost, lost_before + 1, "잃은 분신도 그때 하나 는다")
	var still_worn := false
	for i in range(1, w.swarm.count):
		if w.swarm.worn[i] == Parts.CROW_FOOT:
			still_worn = true
	t.ok(not still_worn, "죽은 분신이 걸치고 있던 부품은 살아남은 어느 줄에도 남지 않는다")
	t.eq(w.swarm.total_force(), Rules.FORCE_START + 3, "그 힘도 무리 어디에도 남지 않는다")


# -- 12b: the cargo is read BEFORE the swap --------------------------------------------------------------
## ⚠ **The row removed is index 1, not the last one.** `remove_at()` swaps the last row into `i`, so a
## `carried[i]` read after the call credits a SURVIVOR's haul to the dead clone — 3.0 instead of 2.0, which
## is a perfectly plausible number and that is exactly why it needs its own check.
func _c12b_the_cargo_is_read_before_the_swap(t) -> void:
	var w := World.new()
	w.setup(62)
	_silence_food(w)
	for _i in 3:
		w.swarm.add_clone(0, 4)
	# ⚠ **The dead row's cargo and the LAST row's cargo are different numbers on purpose.** With the two the
	# same, reading `carried[i]` after the swap gives the right answer for the wrong reason.
	w.swarm.carried[1] = 2.0
	w.swarm.carried[2] = 1.0
	w.swarm.carried[3] = 3.0
	t.eq(w.swarm.count, 4, "설정: 화물 2 · 1 · 3을 실은 분신 셋을 세웠다")
	t.ok(w._damage_clone(1, 999), "설정: 가운데 하나를 실제로 죽였다")
	t.eq(w.cargo_lost, 2.0, "죽은 그 분신이 싣고 있던 2가 손실로 잡힌다 — 내려온 줄의 3이 아니다")
	t.eq(w.clones_lost, 1, "잃은 분신은 하나다")


# -- 12c: a clone's hp is its OWN force × HP_PER_FORCE ---------------------------------------------------
func _c12c_a_clones_hp_is_its_own(t) -> void:
	var sw := Swarm.new()
	sw.setup(63, Vector2(1000.0, 1000.0))
	var a := sw.add_clone(0, 4)
	var b := sw.add_clone(0, 10)
	var c := sw.add_clone(0, 30)
	t.eq(int(sw.hp[a]), 12, "힘 4짜리 분신은 체력 12로 태어난다 (4 × 3, 리터럴)")
	t.eq(int(sw.hp[b]), 30, "힘 10이면 30이다")
	t.eq(int(sw.hp[c]), 90, "힘 30이면 90이다 — 호스트의 체력에서 나오는 숫자가 아니다")
	t.eq(int(sw.hp[0]), -1, "그리고 0번 줄은 -1 표식이다 — 호스트의 체력은 World가 들고 있다")
	t.ok(not sw.damage(0, 5), "damage()는 0번을 아예 거절한다 — 두 번째 체력 게이지를 만들지 않는다")
	t.eq(int(sw.hp[0]), -1, "거절당한 뒤에도 표식은 그대로다")


# -- 13: a clone attacks what it touches, with NO key pressed --------------------------------------------
## ⚠ **2.0s, not 1.2s.** Every body opens at `atk_cd = 0`, so the hits land at t ≈ 0.017 and t ≈ 1.217 and a
## 1.2s window holds exactly ONE of them. 2.0s sits between the second and the third with ~0.4s of margin
## either side.
func _c13_a_clone_attacks_on_its_own_clock(t) -> void:
	var w := _touching_pair(64)
	var hp0: int = int(w.critter_hp[0])
	for _s in 120:
		w.step(DT)
	t.eq(hp0 - int(w.critter_hp[0]), 20,
			"키를 하나도 안 눌러도 2초 동안 분신이 두 번 문다 (제 힘 10씩)")

	var w2 := _touching_pair(65)
	var hp1: int = int(w2.critter_hp[0])
	for _s in 30:
		w2.step(DT)
	t.eq(hp1 - int(w2.critter_hp[0]), 10, "갓 태어난 분신은 0.5초 안에 정확히 한 번 문다 — 매 프레임이 아니다")


# -- H3: a clone is a WALL -------------------------------------------------------------------------------
## `the-horse-is-herded-not-outrun` says clones must physically block and that it is new sim work. Without
## it, "stops dead against a rock, a clone or the field edge" is false for the middle third and herding has
## no mechanism at all.
func _h3_a_clone_is_a_wall(t) -> void:
	var w := World.new()
	w.setup(66)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(1306.0, 1200.0)
	var c := w.swarm.add_clone(0, 2)
	w.swarm.pos[c] = Vector2(1330.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1306.0, 1000.0), 10)
	w.critter_hp[0] = 900
	var gap: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	t.ok(gap > 23.0 and gap < 30.0,
			"설정: 까마귀는 분신 바로 앞, 아직 겹치지는 않은 자리에 섰다 (%.1f, 막히는 거리는 23px)" % gap)
	var stood: Vector2 = w.critter_pos[0]
	for _s in 30:
		w.critter_counter[0] = 5.0
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(stood) < 0.001,
			"분신 쪽으로 걸어가던 까마귀가 그 자리에서 멈춘다 — 몸도 벽이다 (%.4f)"
					% w.critter_pos[0].distance_to(stood))

	w.swarm.remove_at(c)
	t.eq(w.swarm.count, 1, "설정: 그 분신을 치웠다")
	for _s in 30:
		w.critter_counter[0] = 5.0
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(stood) > 20.0,
			"벽을 치우면 다시 걷는다 — 얼어붙은 것이 아니라 막혀 있던 것이다 (%.1f)"
					% w.critter_pos[0].distance_to(stood))


# -- H3b: an ALREADY overlapping creature can still walk out ---------------------------------------------
## ⚠ **The `and not _blocked(p, k)` half.** A predicate on the destination alone freezes any creature that
## is already overlapping a body — which happens the instant a clone walks onto a standing crow, and to
## forty at once when the arena's summon teleports them. H3 stays green throughout.
func _h3b_an_overlapped_creature_can_still_leave(t) -> void:
	var w := World.new()
	w.setup(67)
	_silence_food(w)
	_clear_terrain(w)
	var c := w.swarm.add_clone(0, 2)
	w.swarm.pos[c] = Vector2(1500.0, 1000.0)
	w.swarm.command_strike(Vector2(1500.0, 1000.0))
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, Vector2(1505.0, 1000.0), 30)
	w.critter_hp[0] = 900
	w.critter_dir[0] = Vector2.ZERO
	var start: Vector2 = w.critter_pos[0]
	t.ok(start.distance_to(w.swarm.pos[c]) < 30.0,
			"설정: 말과 분신은 이미 겹쳐 있다 (%.1f < 막히는 30px)" % start.distance_to(w.swarm.pos[c]))
	for _s in 60:
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(start) > 100.0,
			"이미 겹쳐 있던 말도 1초면 빠져나간다 — 막는 것은 「더 가까워지는 걸음」뿐이다 (%.0f)"
					% w.critter_pos[0].distance_to(start))


# -- H4: the boss walks THROUGH a ring of clones ---------------------------------------------------------
## ⚠ **It does not assert that the arena closed**, and it must not: the boss ships slower than the host and
## self-closure was deferred to the first play session. What is asserted is that the distance FELL, through
## forty bodies, at the full 150px/s.
func _h4_the_boss_walks_through_the_ring(t) -> void:
	var w := World.new()
	w.setup(68)
	_silence_food(w)
	_clear_terrain(w)
	for k in range(w.critter_count - 1, -1, -1):
		if k != w.boss_index:
			w._remove_critter(k)
	var host: Vector2 = w.swarm.pos[0]
	var b := w.boss_index
	# ⚠ **1800px, not 2000.** The host opens at the field's centre and the field is 3840 wide, so a boss
	# written 2000px to its right lands OUTSIDE the world and `_clamp_field` yanks it 77.5px back on the
	# first frame — a travel measurement that would have read as the boss walking half again too fast.
	w.critter_pos[b] = host + Vector2(1800.0, 0.0)
	w.critter_dir[b] = Vector2.LEFT
	w.elapsed = Rules.BOSS_HUNT_AT
	t.ok(w.critter_pos[b].x < Rules.FIELD.x, "설정: 보스는 필드 안에 서 있다 (%.0f)" % w.critter_pos[b].x)
	for i in 40:
		var c := w.swarm.add_clone(0, 2)
		w.swarm.pos[c] = host + Vector2(400.0 + float(i) * 30.0, 0.0)
	t.eq(w.swarm.count, 41, "설정: 보스와 호스트 사이에 분신 마흔을 줄지어 세웠다")
	var before: float = w.critter_pos[b].distance_to(host)
	for _s in 120:
		w._step_critters(DT)
	var after: float = w.critter_pos[b].distance_to(host)
	# 300 = 150px/s × 2.0s, by hand. Within a pixel, because the walk is 120 float32 additions.
	t.ok(absf((before - after) - 300.0) < 1.0,
			"보스는 몸의 벽을 그대로 통과해 2초에 300px를 좁힌다 (%.1f → %.1f)" % [before, after])
	t.ok(after > Rules.ARENA_RADIUS,
			"설정: 그 2초로는 아직 아레나 거리에 닿지 않는다 — 이 검사는 아레나를 기다리지 않는다 (%.0f)"
					% after)


# -- H5: the KEY reaches the world -----------------------------------------------------------------------
## ⚠ **Nothing drove `fire()` at all before this.** Every damage check called `strike()` by hand, so the
## shell's one-line rewiring could be forgotten with the whole round green and left click would draw a cone
## that deals nothing in play — the five-minutes-of-play class of bug.
func _h5_the_key_reaches_the_world(t) -> void:
	var w := World.new()
	w.setup(69)
	_silence_food(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, host + Vector2(40.0, 0.0), 10)
	t.eq(w.body.bound[0], Parts.BITE, "설정: 좌클릭은 물기를 들고 열린다")
	t.eq(w.swarm.force[0], 10, "설정: 호스트의 힘은 10이다")
	t.ok(w.fire(0, host + Vector2(400.0, 0.0)), "설정: 좌클릭이 실제로 나갔다")
	t.eq(int(w.critter_hp[0]), 20, "키 한 번이 그대로 피해가 된다 — 호스트의 힘 10만큼 깎인다")
	t.ok(not w.fire(0, host + Vector2(400.0, 0.0)), "설정: 쿨다운 안의 두 번째 클릭은 거부된다")
	t.eq(int(w.critter_hp[0]), 20, "그리고 거부당한 클릭은 아무것도 깎지 않는다")


# -- H6: a clone swings at ITS OWN reach, never at the creature's ----------------------------------------
## ⚠ **The band that lets a clone attack and the band `strike()` actually hits in are two different numbers,
## and only one of them is the clone's.** `critter_reach()` carries `SPECIES_REACH_BONUS`, which exists so
## the BOSS out-reaches 물기 — reading it here admits a clone at 126px and then swings a 88px beak, so the
## cooldown is burned every period for nothing and wearing the stage's own reward makes a clone strictly
## worse than a bare one in the fight it was dropped for.
##
## 110 and 80 are literals on purpose: 126 = 48 + 70 + 8 and 88 = `RANGE[부리]` 40 + 48, and 110 is the one
## band between them.
func _h6_a_clone_reaches_only_as_far_as_what_it_wears(t) -> void:
	var w := World.new()
	w.setup(70)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, at, 120)
	# The boss's own clock is stopped, so pass 2 cannot end the run mid-check.
	w.critter_atk_cd[0] = 99.0
	var c := w.swarm.add_clone(0, 20)
	w.swarm.pos[c] = at - Vector2(110.0, 0.0)
	w.swarm.worn[c] = Parts.CROW_BEAK
	w.swarm.atk_cd[c] = 0.0
	t.eq(int(w.critter_hp[0]), 360, "설정: 보스는 체력 360으로 서 있다")
	w._contact(0, at)
	t.eq(int(w.critter_hp[0]), 360, "110px의 부리는 보스에 닿지 않는다")
	t.eq(w.swarm.atk_cd[c], 0.0,
			"그리고 닿지도 않은 휘두름에 쿨다운을 물지 않는다 — 부리를 낀 분신이 맨몸보다 약해지지 않는다")

	w.swarm.pos[c] = at - Vector2(80.0, 0.0)
	w._contact(0, at)
	t.eq(int(w.critter_hp[0]), 340, "대조: 부리가 닿는 80px에서는 제 힘 20이 그대로 들어간다")
	t.ok(w.swarm.atk_cd[c] > 0.0, "대조: 그때는 쿨다운을 문다")

	_h6b_a_bare_clone_reaches_only_its_own_body(t)


# -- H6b: the OTHER branch of the same band, and every crow/horse fixture measures them as identical ------
## ⚠ **H6's fix split one expression into two branches and only the swinging one is pinned above.**
## `Rules.SPECIES_REACH_BONUS` is 0 for the crow and the horse, so `critter_radius(k) + CLONE_BODY_RADIUS`
## and `critter_reach(k) + CLONE_BODY_RADIUS` are **the same number** on every other fixture in this round —
## the same blindness that hid H6 itself, one `else` away. Only the boss's 70px bonus separates them:
## 48 + 8 = **56** is the bare clone's band, 48 + 70 + 8 = **126** is the creature's.
##
## 110 is the one distance between them, exactly as it is above, so this case and the beak case sit at the
## same spot and differ only in what the clone is wearing. In play the mutation lets a bare clone chip the
## boss from 70px of open ground, which is "clones attack on contact" contradicted in the run's last fight.
func _h6b_a_bare_clone_reaches_only_its_own_body(t) -> void:
	var w := World.new()
	w.setup(74)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(BOSS, at, 120)
	w.critter_atk_cd[0] = 99.0
	var c := w.swarm.add_clone(0, 20)
	w.swarm.pos[c] = at - Vector2(110.0, 0.0)
	w.swarm.worn[c] = -1
	w.swarm.atk_cd[c] = 0.0
	t.eq(int(w.critter_hp[0]), 360, "설정: 보스는 체력 360으로 서 있다 (맨몸 분신)")
	t.eq(w.swarm.worn[c], -1, "설정: 이 분신은 아무것도 안 입었다 — 휘두르는 쪽이 아니라 미는 쪽이다")
	w._contact(0, at)
	t.eq(int(w.critter_hp[0]), 360,
			"110px의 맨몸 분신은 보스에 닿지 않는다 — 재는 것은 보스의 손길이 아니라 제 몸이다")
	t.eq(w.swarm.atk_cd[c], 0.0, "닿지 않았으니 쿨다운도 물지 않는다")

	# The control, and without it the check above passes on a clone that simply never attacks: 50px is inside
	# 56 and outside nothing else, so it separates "the band is the clone's" from "the band is gone".
	w.swarm.pos[c] = at - Vector2(50.0, 0.0)
	w._contact(0, at)
	t.eq(int(w.critter_hp[0]), 340, "대조: 제 몸이 닿는 50px에서는 제 힘 20이 그대로 들어간다")
	t.ok(w.swarm.atk_cd[c] > 0.0, "대조: 그때는 쿨다운을 문다")


# -- H7: a zero-length aim is not a full circle ----------------------------------------------------------
## ⚠ `Vector2.ZERO.angle_to(to)` is `atan2(0, 0)`, which is **0 for every target** — so a creature standing
## exactly on a clone turns its cone into a circle and the swing lands on everything in range, 180° behind
## included. Reachable in play: `_blocked()` deliberately lets an already-overlapped creature stand, and the
## arena's summon teleports up to forty clones onto whatever is underneath them.
func _h7_a_dead_centre_target_does_not_open_the_cone(t) -> void:
	var w := World.new()
	w.setup(71)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(1000.0, 1000.0)
	var c := w.swarm.add_clone(0, 5)
	w.swarm.pos[c] = at
	w.swarm.worn[c] = Parts.CROW_BEAK
	w.swarm.atk_cd[c] = 0.0
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at, 10)
	w._write_critter(CROW, at - Vector2(45.0, 0.0), 10)
	w.critter_atk_cd[0] = 99.0
	w.critter_atk_cd[1] = 99.0
	t.ok(absf(float(Parts.ARC[Parts.CROW_BEAK]) - deg_to_rad(40.0)) < 0.0001,
			"설정: 부리는 40°짜리 원뿔이다 — 뒤쪽은 그 밖이다")
	w._contact(0, at)
	t.eq(int(w.critter_hp[1]), 30,
			"겹쳐 선 까마귀를 겨눈 휘두름이 180° 뒤의 까마귀까지 때리지는 않는다")
	t.eq(w.swarm.atk_cd[c], 0.0, "겨눌 방향이 없으면 휘두르지 않고, 쿨다운도 물지 않는다")

	# The control, and without it the check above passes on a clone that simply never swings.
	w.critter_pos[0] = at + Vector2(3.0, 0.0)
	w._contact(0, w.critter_pos[0])
	t.eq(int(w.critter_hp[0]), 25, "대조: 3px만 어긋나면 방향이 생기고 앞의 까마귀는 제 힘 5만큼 맞는다")
	t.eq(int(w.critter_hp[1]), 30, "그래도 뒤의 까마귀는 여전히 한 점도 안 깎인다")


# -- H8: "somebody died" is not "creature k died" --------------------------------------------------------
## ⚠ `strike()` returns a HIT COUNT, so a count delta reads as identity — and a clone's cone kills every
## creature it covers, bystanders included. `_contact` then answers "k died", `_step_critters` skips the
## rest of the row, and **pass 2 never runs**: the creature that walked into a clone gets a free frame with
## no retaliation, in a build where the boss reaching the host is the run's last act.
func _h8_a_bystanders_death_is_not_the_touchers(t) -> void:
	var w := World.new()
	w.setup(72)
	_silence_food(w)
	_clear_terrain(w)
	var host := Vector2(1000.0, 1000.0)
	w.swarm.pos[0] = host
	w.critter_count = 0
	w.boss_index = -1
	# The TOUCHER: 14px off the host, written up so the cone cannot kill it too.
	w._write_critter(CROW, host + Vector2(14.0, 0.0), 10)
	w.critter_hp[0] = 900
	# The BYSTANDER: behind it, inside the same 날개 cone, at its real 30 hp.
	w._write_critter(CROW, host - Vector2(10.0, 0.0), 10)
	# ⚠ **16px from the toucher, not 36.** The band a clone is admitted at is the thing H6 widens, and a
	# fixture that only fits inside the WIDE one measures H6 instead of this: it has to sit inside both.
	var c := w.swarm.add_clone(0, 50)
	w.swarm.pos[c] = host + Vector2(30.0, 0.0)
	w.swarm.worn[c] = Parts.CROW_WING
	w.swarm.atk_cd[c] = 0.0
	t.eq(w.host_hp, 30, "설정: 호스트는 체력 30으로 서 있다")
	var died: bool = w._contact(0, w.critter_pos[0])
	t.eq(w.critter_count, 1, "설정: 원뿔이 곁의 까마귀를 죽였다")
	t.eq(int(w.critter_hp[0]), 850, "설정: 닿아 있던 까마귀 자신은 살아남았다")
	t.ok(not died, "곁의 놈이 죽었다고 해서 닿은 놈이 죽은 것이 되지는 않는다")
	t.eq(w.host_hp, 20, "그래서 그 까마귀는 반격을 그대로 한다 — 호스트가 제 힘 10만큼 깎인다")

	# **The other half, and it is a second bug exactly the way `boss_index`'s two halves are.** Here the
	# toucher is the LAST row, so the bystander's removal swaps the toucher DOWN over it: the row the caller
	# is holding is now past `critter_count` entirely. Unrepaired, the second pass runs on that ghost — the
	# arrays are sized to the cap and never cleared, so it reads the creature's own stale copy, hits the
	# host from a row that no longer exists, and writes the cooldown there, where it stops nothing.
	# ⚠ **Written in the opposite order to the block above**, which is the whole difference between them.
	var w2 := World.new()
	w2.setup(73)
	_silence_food(w2)
	_clear_terrain(w2)
	var host2 := Vector2(1000.0, 1000.0)
	w2.swarm.pos[0] = host2
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, host2 - Vector2(10.0, 0.0), 10)
	w2._write_critter(CROW, host2 + Vector2(14.0, 0.0), 10)
	w2.critter_hp[1] = 900
	var c2 := w2.swarm.add_clone(0, 50)
	w2.swarm.pos[c2] = host2 + Vector2(30.0, 0.0)
	w2.swarm.worn[c2] = Parts.CROW_WING
	w2.swarm.atk_cd[c2] = 0.0
	var moved: bool = w2._contact(1, w2.critter_pos[1])
	t.eq(w2.critter_count, 1, "설정: 원뿔이 곁의 까마귀를 죽였다")
	t.eq(int(w2.critter_hp[0]), 850, "설정: 마지막 줄이던 그놈이 빈 줄로 내려왔다")
	t.ok(moved, "제 줄이 옮겨진 것도 「이 줄은 더 이상 그 생물이 아니다」다 — 호출자는 손을 뗀다")
	t.eq(w2.host_hp, 30, "그래서 사라진 줄에서 반격이 날아오지 않는다 (%d)" % w2.host_hp)


# -- H9: the arc has a CEILING, not only a floor ---------------------------------------------------------
## ⚠ **`half_arc := Parts.ARC[part] * 0.5` → `* 1.0` was green while deleting the arc test outright
## reddened.** `_c9`'s one "outside the arc" creature sits at `Vector2(940, 1000)` — **180° behind** a
## `Vector2.RIGHT` facing — so any widening short of a full circle still misses it. What that costs: 부리's
## 40° jab and 날개's 100° sweep are the design difference that makes binding a key a decision, and at the
## point of use they were interchangeable.
##
## **Two targets, 35° and 60° off the facing, both 50px out**, so each part answers them differently:
## 부리 (half 20°) misses both, 날개 (half 50°) takes the near one and misses the far one. Double the arc
## and 부리 takes 35° while 날개 takes 60°; halve it and 날개 loses the 35°. **One bite does not prove the
## range** — this is the pair that does.
##
## Both radii are hand-written: a force-10 crow is 15px, so 부리 reaches 40 + 15 = 55 and 날개 55 + 15 = 70.
## 50px is inside both, which is what leaves the ANGLE as the only thing separating the four answers.
func _h9_the_cone_has_a_ceiling(t) -> void:
	var origin := Vector2(1000.0, 1000.0)
	var a35 := origin + Vector2(cos(deg_to_rad(35.0)), sin(deg_to_rad(35.0))) * 50.0
	var a60 := origin + Vector2(cos(deg_to_rad(60.0)), sin(deg_to_rad(60.0))) * 50.0

	var w := _two_off_axis_crows(80, origin, a35, a60)
	t.ok(absf(float(Parts.ARC[Parts.CROW_BEAK]) - deg_to_rad(40.0)) < 0.0001,
			"설정: 부리는 40°짜리 원뿔이라 반각이 20°다")
	t.eq(w.strike(origin, Vector2.RIGHT, Parts.CROW_BEAK, 5), 0, "부리는 35°도 60°도 못 맞힌다")
	t.eq(int(w.critter_hp[0]), 30, "35°의 까마귀는 한 점도 안 깎인다 — 20°짜리 원뿔 밖이다")
	t.eq(int(w.critter_hp[1]), 30, "60°의 까마귀도 그대로다")

	var w2 := _two_off_axis_crows(81, origin, a35, a60)
	t.ok(absf(float(Parts.ARC[Parts.CROW_WING]) - deg_to_rad(100.0)) < 0.0001,
			"설정: 날개는 100°짜리 원뿔이라 반각이 50°다")
	t.eq(w2.strike(origin, Vector2.RIGHT, Parts.CROW_WING, 5), 1, "날개는 그 둘 중 하나만 맞힌다")
	t.eq(int(w2.critter_hp[0]), 25, "35°는 날개의 50° 안이라 맞는다")
	t.eq(int(w2.critter_hp[1]), 30,
			"60°는 그 밖이라 안 맞는다 — 원뿔에는 바닥만이 아니라 천장도 있다")

	# The reach is the control: without it "it missed" is satisfied by a swing that reaches nothing at all.
	var w3 := _two_off_axis_crows(82, origin, a35, a60)
	t.eq(w3.strike(origin, (a60 - origin).normalized(), Parts.CROW_BEAK, 5), 1,
			"대조: 60°를 똑바로 겨누면 부리도 거기에 닿는다 — 사거리가 아니라 각도가 막고 있었다")
	t.eq(int(w3.critter_hp[1]), 25, "대조: 그때는 그 까마귀가 제대로 깎인다")


# -- H10: the clone's swing is aimed at what it TOUCHED ---------------------------------------------------
## ⚠ **Replacing the clone's facing with a constant `Vector2.RIGHT` was green.** Nothing in the round ever
## called `_contact` with an ARC-wearing clone positioned off-axis: `_h7`'s control aims 3px along +x and
## `_h8`'s cone points the same way, so a hardcoded facing answered every fixture correctly.
##
## Here the toucher is due NORTH of the clone and a second crow is due SOUTH, both 40px out and both inside
## the 55px admission band (`RANGE[부리]` 40 + a force-10 crow's 15) — so the aim is the only thing that can
## separate them, and a constant `Vector2.RIGHT` misses **both**.
func _h10_the_clones_swing_is_aimed_at_what_it_touched(t) -> void:
	var w := World.new()
	w.setup(83)
	_silence_food(w)
	_clear_terrain(w)
	# The host is nowhere near, so pass 2 cannot reach it and the swarm's only swinger is the clone.
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var at := Vector2(1500.0, 1000.0)
	var c := w.swarm.add_clone(0, 5)
	w.swarm.pos[c] = at
	w.swarm.worn[c] = Parts.CROW_BEAK
	w.swarm.atk_cd[c] = 0.0
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at - Vector2(0.0, 40.0), 10)
	w._write_critter(CROW, at + Vector2(0.0, 40.0), 10)
	# Both clocks stopped, so pass 2 cannot chip the clone and confuse the two hp readings.
	w.critter_atk_cd[0] = 99.0
	w.critter_atk_cd[1] = 99.0
	t.eq(int(w.critter_hp[0]), 30, "설정: 북쪽의 까마귀는 체력 30이다")
	t.eq(int(w.critter_hp[1]), 30, "설정: 남쪽의 까마귀도 체력 30이다")
	w._contact(0, w.critter_pos[0])
	t.eq(int(w.critter_hp[0]), 25, "닿은 쪽 — 북쪽의 까마귀가 분신의 힘 5만큼 맞는다")
	t.eq(int(w.critter_hp[1]), 30,
			"정반대편의 까마귀는 한 점도 안 맞는다 — 휘두름은 +x가 아니라 닿은 쪽을 겨눈다")
	t.ok(w.swarm.atk_cd[c] > 0.0, "그리고 그 휘두름에는 쿨다운이 붙었다")


# -- fixtures ---------------------------------------------------------------------------------------------
## Two force-10 crows at hand-written off-axis points, on cleared ground with nothing else on the field.
func _two_off_axis_crows(seed_value: int, origin: Vector2, a: Vector2, b: Vector2) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = origin
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, a, 10)
	w._write_critter(CROW, b, 10)
	return w


## How many strikes at `attacker_force` it takes to kill a hand-written force-10 crow (hp 30).
func _hits_to_kill(seed_value: int, attacker_force: int) -> int:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	var origin := Vector2(1000.0, 1000.0)
	w.swarm.pos[0] = origin
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, Vector2(1040.0, 1000.0), 10)
	var n := 0
	while w.critter_count > 0 and n < 50:
		w.strike(origin, Vector2.RIGHT, Parts.BITE, attacker_force)
		n += 1
	return n


## One clone standing on one crow, both far from the host, both held still. The crow's hp is written up so
## the exchange never ends inside the window a hit count is being measured over.
func _touching_pair(seed_value: int) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	var at := Vector2(500.0, 500.0)
	var c := w.swarm.add_clone(0, 10)
	w.swarm.pos[c] = at
	w.swarm.hp[c] = 100000
	w.swarm.command_strike(at)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at + Vector2(5.0, 0.0), 10)
	w.critter_hp[0] = 100000
	return w


# -- U14: the host's incoming-damage rate limit -----------------------------------------------------------
## **`Rules.HOST_HIT_GRACE` had zero hits in `tests/` and `host_grace` had one, inside a comment.** Four
## independent mutations were green: `if host_grace <= 0.0:` → `if true:`; the constant 1.0 → 0.01; the
## countdown deleted; and the host-path `critter_atk_cd[k] = CLONE_ATTACK_PERIOD` → 0.0.
##
## ⚠ **It takes THREE crows, and that is the whole finding.** Grace (1.0s) is shorter than
## `CLONE_ATTACK_PERIOD` (1.2s), so with a single attacker the creature's own cooldown already governs and
## grace is redundant — the two mechanisms cover for each other and each is individually deletable. Grace
## only bites when two or more creatures reach the host in the same second, which is the boss fight and is
## exactly the case no fixture built.
##
## `w.step()` rather than `_step_critters()`: the countdown lives in `step`, and deleting it is one of the
## four mutations.
func _u14_the_host_can_only_be_hit_once_a_second(t) -> void:
	var w := World.new()
	w.setup(460)
	_silence_food(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	# A force-10 crow is radius 15 and reach 15, so contact is 15 + BODY_RADIUS 14 = 29px. Three of them at
	# 20px, on three sides, are all inside it — and each hits for its own force, 10.
	for v in [Vector2(20.0, 0.0), Vector2(-20.0, 0.0), Vector2(0.0, 20.0)]:
		w._write_critter(CROW, host + v, 10)
	t.eq(w.critter_count, 3, "설정: 힘 10짜리 까마귀 셋이 호스트에 붙어 있다")
	t.eq(w.host_hp, 30, "설정: 호스트의 체력은 30이다 (리터럴)")

	w.step(DT)
	# **All three were admitted**, or "only 10 damage" would be measuring one crow instead of the rule.
	var ready := 0
	for k in 3:
		if w.critter_atk_cd[k] > 0.0:
			ready += 1
	t.eq(ready, 3, "첫 프레임에 셋 다 사거리 안이었다 — 셋 다 제 공격 시계를 걸었다")
	t.eq(w.host_hp, 20, "그런데 체력은 10만 깎였다 — 셋이 동시에 때리지는 못한다")

	# 119 more frames: 1.983s in total, so the second window has opened (grace runs out at 1.0) and every
	# crow's own 1.2s cooldown has come back, but the third window (2.4s) has not.
	for _s in 119:
		w.step(DT)
	t.ok(w.elapsed > 1.9 and w.elapsed < 2.0, "설정: 2초 직전까지 돌렸다 (%.3f)" % w.elapsed)
	t.eq(w.host_hp, 10,
			"2초 동안 호스트가 잃은 것은 20이다 — 무적 시간이 없으면 셋 × 두 번 = 60이고 호스트는 죽는다")
	t.ok(w.host_grace > 0.0, "그리고 마지막 한 방의 무적 시간이 아직 돌고 있다 (%.3f)" % w.host_grace)

	# The countdown itself: it has to reach zero, or the host becomes immortal after the first hit.
	for _s in 90:
		w.step(DT)
	t.eq(w.host_hp, 0, "2.4초를 넘기면 세 번째 한 방이 들어온다 — 무적은 끝나는 것이지 면제가 아니다")


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks now sit wherever a fixture writes a coordinate, and `push_out` moves a hand-placed creature
## off one by up to a rock's radius. A check that is not about the ground removes the ground first.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
