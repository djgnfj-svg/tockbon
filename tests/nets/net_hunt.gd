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
const LION := int(Parts.Species.LION)
const ELEPHANT := int(Parts.Species.ELEPHANT)

## Every literal the separation checks stand on, written out once so a reader can check the arithmetic
## rather than trust it. **None of them is read back off the code under test** — that is the whole point.
##
## A force-10 crow is `SPECIES_RADIUS[CROW] 12 × (1 + 0.5 × (10−8)/(12−8))` = **15.0**.
## A force-55 lion sits at its species' minimum, so the ramp is zero and it is **26.0** exactly.
const CROW10_R := 15.0
const LION55_R := 26.0
## Where a body comes to rest against one: the two radii summed, less `SEPARATION_CONTACT_MARGIN` 1.0.
const CROW10_CLONE_REST := 22.0    ## 15 + 8 − 1
const LION55_CLONE_REST := 33.0    ## 26 + 8 − 1
const LION55_HOST_REST := 39.0     ## 26 + 14 − 1
## And the band the rest distance has to stay inside: `critter_radius + CLONE_BODY_RADIUS`, no margin.
const CROW10_CLONE_BAND := 23.0    ## 15 + 8


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
	_b5_bare_clone_swing_is_aimed_too(t)
	_u14_the_host_can_only_be_hit_once_a_second(t)
	_u15_host_hit_force_is_the_landing_hit_and_knocks_the_host_back(t)
	_s1_a_body_is_pushed_out_of_a_creature(t)
	_s2_forty_bodies_never_move_the_lion(t)
	_s3_a_body_wedged_against_a_rock(t)
	_s4_a_separated_clone_still_lands_every_hit(t)
	_m1_one_blow_never_takes_more_than_half(t)
	_m2_three_species_land_one_hit_through_a_real_frame(t)
	_m3_how_many_blows_the_host_survives(t)
	_m4_a_level_moves_survivability_one_way_only(t)
	_m5_the_cap_is_symmetric_and_one_directional(t)


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
	# ⚠ **이 줄은 -90이었다.** `MAX_HIT_FRACTION`이 들어오면서 옮겨진 초록이고, 느슨해진 것이 아니라
	# 다시 잰 것이다 — 한 방의 크기는 이제 「최대 체력의 절반」이고 보스는 거기서 예외가 아니다.
	t.eq(w.host_hp, 15, "보스가 닿아도 한 방은 최대 체력 30의 절반까지다 (30 → 15)")
	t.eq(w.host_hit_force, 120, "그래도 그 한 방의 크기는 120이다 — 화면 흔들림의 세기는 깎인 피해가 아니라 힘을 읽는다")


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
	# ⚠ **999 한 방으로는 이제 안 죽는다.** 힘 4짜리 분신의 최대 체력은 12이고 `MAX_HIT_FRACTION`이 한 방을
	# 6으로 자른다 — 두 방이 필요하다. 느슨하게 고친 것이 아니라 규칙이 바뀐 만큼 다시 잰 것이다.
	t.ok(not w._damage_clone(1, 999), "설정: 상한 때문에 첫 방으로는 안 죽는다 (최대 12의 절반 6)")
	t.ok(w._damage_clone(1, 999), "설정: 두 방째에 가운데 하나가 실제로 죽었다")
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
## ⚠ **The half of `_clearance()` that is not the wall.** A predicate on the destination alone freezes any
## creature that is already overlapping a body — which happens the instant a clone walks onto a standing
## crow, and to forty at once when the arena's summon teleports them. Comparing clearances instead of
## flags is what lets this horse leave while H3's crow is still stopped dead one function up.
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
	# 300 = 150px/s × 2.0s, by hand.
	# ⚠ **Since §A-3 the wall is not inert.** Each bare clone the boss touches retaliates — its own force
	# (2) — and every landed retaliation also knocks the boss a little off its line
	# (`force × KNOCKBACK_PER_FORCE`). Forty of those along a 300px walk add a few real pixels of drift; the
	# tolerance widens for that. The claim under test is unchanged: nothing here meaningfully SLOWS the boss.
	t.ok(absf((before - after) - 300.0) < 10.0,
			"보스는 몸의 벽에 밀리긴 해도 그대로 지나가며 2초에 300px 가까이 좁힌다 (%.1f → %.1f)" % [before, after])
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
## included. Reachable in play: `_contact()` runs before both separation passes, so the arena summon's forty
## arrivals and any clone that walked onto a creature are dead centre for the length of that one frame.
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
	t.eq(w.swarm.swing_show[c], INF, "설정: 아직 이 분신은 휘두른 적이 없다")
	w._contact(0, w.critter_pos[0])
	t.eq(int(w.critter_hp[0]), 25, "닿은 쪽 — 북쪽의 까마귀가 분신의 힘 5만큼 맞는다")
	t.eq(int(w.critter_hp[1]), 30,
			"정반대편의 까마귀는 한 점도 안 맞는다 — 휘두름은 +x가 아니라 닿은 쪽을 겨눈다")
	t.ok(w.swarm.atk_cd[c] > 0.0, "그리고 그 휘두름에는 쿨다운이 붙었다")
	# ⚠ **같은 검사, 밀림의 방향에 대해서.** 상수 `Vector2.RIGHT`로는 두 까마귀 다 못 가른다 — `_h10`
	# 자신의 주석이 이미 이유를 댄다. 여기서는 북쪽 까마귀만 맞았으니 그 방향이 실제로 (0,-1)인지가 유일한
	# 증거다.
	t.eq(w.critter_hit_dir[0], Vector2(0.0, -1.0), "맞은 까마귀의 피격 방향은 실제로 닿은 쪽이다 — 상수가 아니다")
	t.eq(w.critter_hit_dir[1], Vector2.ZERO, "안 맞은 까마귀의 피격 방향은 열린 값 그대로다")
	# §B-5: 분신 쪽의 `swing_show`/`swing_dir`도 이 실제 접촉에서 함께 쓰인다 — 같은 `aim`을 재사용하므로
	# 맞은 쪽과 정확히 같은 방향이다.
	t.eq(w.swarm.swing_show[c], 0.0, "휘두른 분신의 시계도 0으로 열린다")
	t.eq(w.swarm.swing_dir[c], Vector2(0.0, -1.0), "휘두른 방향도 실제로 닿은 쪽이다 — strike()가 문 aim과 같다")


# -- B-5, the bare-hand case: no worn ARC part, `_contact` pass 1's OTHER branch ----------------------------
## The same fixture shape as `_h10`, deliberately — the only difference is `worn == -1`, so this drives the
## `else` branch (`kb_dir` computed by hand, no `strike()` dispatch) rather than the `swings` one.
func _b5_bare_clone_swing_is_aimed_too(t) -> void:
	var w := World.new()
	w.setup(84)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(100.0, 100.0)
	var at := Vector2(1500.0, 1000.0)
	var c := w.swarm.add_clone(0, 5)
	w.swarm.pos[c] = at
	w.swarm.worn[c] = -1
	w.swarm.atk_cd[c] = 0.0
	w.critter_count = 0
	w.boss_index = -1
	# The bare-hand band is `critter_radius(k) + CLONE_BODY_RADIUS` (no `RANGE`), so the pair sits much
	# closer than `_h10`'s — still off-axis (north/south), never the trivial `Vector2.RIGHT`.
	w._write_critter(CROW, at - Vector2(0.0, 20.0), 10)
	w._write_critter(CROW, at + Vector2(0.0, 20.0), 10)
	w.critter_atk_cd[0] = 99.0
	w.critter_atk_cd[1] = 99.0
	t.ok(w.critter_pos[0].distance_to(at) <= w.critter_radius(0) + Rules.CLONE_BODY_RADIUS,
			"설정: 맨손 접촉 밴드 안에 있다 (%.1f)" % w.critter_pos[0].distance_to(at))
	t.eq(w.swarm.swing_show[c], INF, "설정: 아직 이 분신은 휘두른 적이 없다")
	w._contact(0, w.critter_pos[0])
	t.eq(int(w.critter_hp[0]), 25, "닿은 쪽 — 북쪽의 까마귀가 분신의 힘 5만큼 맞는다")
	t.eq(int(w.critter_hp[1]), 30, "정반대편의 까마귀는 안 맞는다")
	t.eq(w.swarm.swing_show[c], 0.0, "맨손으로 때려도 휘두름 시계는 0으로 열린다")
	t.eq(w.swarm.swing_dir[c], Vector2(0.0, -1.0), "방향도 실제로 닿은 쪽이다 — kb_dir과 같은 값을 재사용한다")


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


# -- U15: `host_hit_force` is the force that ACTUALLY landed, and the host is knocked back by it ----------
## ⚠ **Two SEPARATE worlds, not one with two attackers.** `_u14` already shows that among several admitted
## attackers only ONE lands per window, and it is always the lowest row (grace and every cooldown here cycle
## in lockstep, so the same index wins every window). Testing two forces inside one world would measure that
## ordering, not "the value tracks whichever hit actually landed" — two independent landings, two different
## forces, is what actually separates "records the force of THE hit" from "records a fixed row's force".
func _u15_host_hit_force_is_the_landing_hit_and_knocks_the_host_back(t) -> void:
	var w := World.new()
	w.setup(84)
	_silence_food(w)
	_clear_terrain(w)
	var host: Vector2 = w.swarm.pos[0]
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, host + Vector2(20.0, 0.0), 10)
	t.eq(w.host_hit_force, 0, "설정: 아직 아무도 안 맞았다")
	t.eq(w.swarm.hit_show[0], INF, "설정: 호스트도 아직 안 맞았다")
	w.step(DT)
	t.eq(w.host_hp, 20, "설정: 힘 10짜리 까마귀가 붙어서 열을 깎았다")
	t.eq(w.host_hit_force, 10, "그 한 방의 세기는 10이다 — 맞은 만큼이다")
	t.eq(w.swarm.hit_show[0], 0.0, "그리고 호스트의 피격 시계도 그 순간 0으로 열린다")
	# 까마귀는 host의 +x쪽에 있으니, 밀리는 방향은 -x다.
	t.ok(w.swarm.hit_dir[0].x < -0.9, "밀리는 방향은 때린 쪽의 반대다 (%.2f)" % w.swarm.hit_dir[0].x)
	var moved: float = w.swarm.pos[0].distance_to(host)
	t.ok(absf(moved - 10.0 * Rules.KNOCKBACK_PER_FORCE) < 0.05,
			"호스트도 맞은 힘 × KNOCKBACK_PER_FORCE만큼 밀린다 (%.2f, 기대 %.2f)"
					% [moved, 10.0 * Rules.KNOCKBACK_PER_FORCE])

	# 대조: 힘 35짜리 하나만 있는 독립된 세상에서, 첫 접촉이 남기는 값도 35다 — 10에 눌어붙지 않는다.
	var w2 := World.new()
	w2.setup(85)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(int(Parts.Species.HORSE), w2.swarm.pos[0] + Vector2(20.0, 0.0), 35)
	w2.critter_flees[0] = 0   ## a fleeing creature never retaliates in pass 2 — force it to stand and hit
	var host2: Vector2 = w2.swarm.pos[0]
	w2.step(DT)
	# ⚠ **이 줄은 -5였다.** `MAX_HIT_FRACTION`이 들어오면서 옮겨진 초록이다.
	t.eq(w2.host_hp, 15, "대조: 힘 35짜리 한 방도 최대 체력의 절반 15에서 멈춘다 (30 → 15)")
	t.eq(w2.host_hit_force, 35, "그리고 세기는 35다 — 값은 깎인 피해가 아니라 때린 힘을 따라간다, 고정된 행이 아니다")
	# ⚠ **밀림은 상한을 안 읽는다.** 피해 15가 아니라 힘 35 × 0.8 = 28px이다. 이 한 줄이 「연출은 힘,
	# 규칙은 상한」을 가른다 — 밀림까지 15로 계산했다면 12px이 나오고, 두 숫자는 두 배 넘게 차이난다.
	var moved2: float = w2.swarm.pos[0].distance_to(host2)
	t.ok(absf(moved2 - 35.0 * Rules.KNOCKBACK_PER_FORCE) < 0.05,
			"밀린 거리는 깎인 피해 15가 아니라 힘 35 × KNOCKBACK_PER_FORCE다 (%.2f, 기대 %.2f)"
					% [moved2, 35.0 * Rules.KNOCKBACK_PER_FORCE])


# -- S1: a body does not stand inside a creature, and the creature is not what moved -----------------------
## The user's sentence — *"적하고 나하고 내 분신하고 겹치는 게 좀 너무 별로고"* — with the half that decides the
## design attached: **the body moves and the creature does not.** Herding is the stage's hand, so a swarm
## that could shove a creature would turn 「말은 몰이로 잡는다」 into pushing.
##
## Both branches of the push are here and they are different code: **exactly coincident** (the deterministic
## angle, `l` forced to 0.0) and **partly overlapped** (the ordinary direction). The coincident half is not
## contrived — the arena summon teleports up to forty clones onto whatever is under them.
##
## ⚠ **Both attack clocks are wound forward in the second half.** Damage carries knockback, and knockback
## moves the creature — a check that let it fire could not tell a separation push from a hit.
func _s1_a_body_is_pushed_out_of_a_creature(t) -> void:
	var at := Vector2(500.0, 500.0)
	var w := World.new()
	w.setup(910)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(2000.0, 2000.0)
	var c := w.swarm.add_clone(0, 10)
	w.swarm.pos[c] = at
	w.swarm.command_strike(at)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at, 10)
	w.critter_hp[0] = 100000
	t.eq(w.swarm.pos[c], at, "설정: 분신이 까마귀 한가운데에 정확히 겹쳐 서 있다")
	t.ok(absf(w.critter_radius(0) - CROW10_R) < 0.001,
			"설정: 힘 10짜리 까마귀의 반지름은 15다 (%.3f)" % w.critter_radius(0))

	w.step(DT)
	t.eq(w.critter_pos[0], at, "한 프레임 뒤에도 까마귀는 그 좌표 그대로다 — 밀리는 것은 몸뿐이다")
	var gap: float = w.swarm.pos[c].distance_to(at)
	t.ok(absf(gap - CROW10_CLONE_REST) < 0.001,
			"완전히 겹쳐 있던 분신은 한 프레임 만에 22px 밖으로 나온다 (%.3f)" % gap)

	# -- the ordinary branch, with nothing but separation allowed to move anything --
	var w2 := World.new()
	w2.setup(911)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = Vector2(2000.0, 2000.0)
	var c2 := w2.swarm.add_clone(0, 10)
	w2.swarm.pos[c2] = at
	w2.swarm.command_strike(at)
	w2.swarm.atk_cd[c2] = 1000.0
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, at + Vector2(5.0, 0.0), 10)
	w2.critter_atk_cd[0] = 1000.0
	w2.critter_hp[0] = 100000
	var stood: Vector2 = w2.critter_pos[0]
	w2.step(DT)
	t.eq(w2.critter_pos[0], stood, "5px만 파고든 경우에도 까마귀는 한 걸음도 안 움직인다")
	var gap2: float = w2.swarm.pos[c2].distance_to(stood)
	t.ok(absf(gap2 - CROW10_CLONE_REST) < 0.001,
			"분신은 겹친 만큼만 밀려 22px에 선다 (%.3f)" % gap2)
	t.ok(w2.swarm.pos[c2].x < stood.x,
			"밀린 방향은 까마귀의 반대쪽이다 — 파고든 쪽으로 더 들어가지 않는다")

	# -- and the beat that must NOT separate --
	var w3 := World.new()
	w3.setup(912)
	_silence_food(w3)
	_clear_terrain(w3)
	w3.swarm.pos[0] = Vector2(2000.0, 2000.0)
	var c3 := w3.swarm.add_clone(0, 10)
	w3.swarm.pos[c3] = at
	w3.critter_count = 0
	w3.boss_index = -1
	w3.swarm.atk_cd[c3] = 1000.0
	w3._write_critter(CROW, at, 10)
	w3.critter_atk_cd[0] = 1000.0
	w3.critter_hp[0] = 100000
	# `clear_pull` alone, `beat_frozen` left false: the great absorption's own guard, isolated from the
	# ecosystem freeze that normally rides with it.
	w3.swarm.clear_pull = true
	w3.step(DT)
	var pulled: float = w3.swarm.pos[c3].distance_to(at)
	# 15px is `Rules.CLEAR_ABSORB_PULL` 900 × DT, and it is ALL of the movement: under the beat the pull is
	# the only thing allowed to move a body, so this is both "the frame really advanced" and "nothing else
	# touched it".
	t.ok(absf(pulled - 15.0) < 0.01,
			"대흡수 중에는 끌려간 15px가 전부다 — 밀어내기는 안 돈다 (%.3f)" % pulled)
	t.ok(pulled < CROW10_CLONE_REST,
			"화면은 빨려 들어가는데 심은 밀어내는 어긋남을 안 만든다 (%.3f < 22)" % pulled)


# -- S2: forty bodies and a lion, and the LION is the one that does not move -------------------------------
## **The single most important check in the separation run.** `the-horse-is-herded-not-outrun` and CLAUDE.md
## both say a creature is stopped by rocks, clones and the edge — stopped, never shoved. If the swarm could
## displace a creature, herding would silently become pushing and the whole hunt changes.
##
## ⚠ **The first half calls the pass directly**, and that is deliberate: a lion HUNTS, so inside a whole
## frame its own walk is mixed into any displacement and "it did not move" stops being an exact claim. The
## second half then pays that back by driving the real frame and pinning the walk to a literal.
func _s2_forty_bodies_never_move_the_lion(t) -> void:
	var at := Vector2(1500.0, 1500.0)
	var w := World.new()
	w.setup(920)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(LION, at, 55)
	t.ok(absf(w.critter_radius(0) - LION55_R) < 0.001,
			"설정: 힘 55짜리 사자의 반지름은 26이다 (%.3f)" % w.critter_radius(0))
	w.swarm.pos[0] = at
	for _i in 40:
		var j := w.swarm.add_clone(0, 5)
		w.swarm.pos[j] = at
	t.eq(w.swarm.count, 41, "설정: 호스트와 분신 마흔이 전부 사자 한가운데 서 있다")

	w._separate_from_critters()
	t.eq(w.critter_pos[0], at, "마흔한 몸이 안에서 밀어내도 사자는 제자리다 — 몰이는 미는 것이 아니다")
	var worst := INF
	var worst_i := -1
	for i in range(1, w.swarm.count):
		var d: float = w.swarm.pos[i].distance_to(at)
		if d < worst:
			worst = d
			worst_i = i
	t.ok(worst >= LION55_CLONE_REST - 0.001,
			"분신 마흔이 전부 33px 밖으로 나온다 — 가장 안쪽이 %d번, %.3f" % [worst_i, worst])
	var host_gap: float = w.swarm.pos[0].distance_to(at)
	t.ok(host_gap >= LION55_HOST_REST - 0.001,
			"호스트도 제 반지름만큼 더 멀리 나온다 — 39px다 (%.3f)" % host_gap)

	# -- the real frame: the lion moves EXACTLY its own walk and not one pixel more --
	var w2 := World.new()
	w2.setup(921)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(LION, at, 55)
	w2.critter_hp[0] = 1000000
	w2.critter_atk_cd[0] = 1000.0
	w2.swarm.pos[0] = at
	for _i in 40:
		var j := w2.swarm.add_clone(0, 5)
		w2.swarm.pos[j] = at
		# Muted for the same reason S1's second half mutes them: a hit knocks the creature back, and this
		# check is about the ONE displacement that is not allowed to exist.
		w2.swarm.atk_cd[j] = 1000.0
	var before: Vector2 = w2.critter_pos[0]
	w2.step(DT)
	var walked: float = w2.critter_pos[0].distance_to(before)
	# 190px/s is `HOST_SPEED 200 × SPECIES_SPEED_MUL[LION] 0.95`, the number `_c7` already pins.
	t.ok(absf(walked - 190.0 / 60.0) < 0.01,
			"한 프레임을 통째로 돌려도 사자가 움직인 것은 제 걸음 3.17px뿐이다 (%.3f)" % walked)


# -- S3: a body wedged between a creature and a rock -------------------------------------------------------
## **The one place this rule cannot deliver what its name promises, written honestly rather than hidden.**
## `Swarm.place()` runs after the push, so a push aimed into a rock is cancelled or slid along the rock's
## face — the body ends the frame still inside the creature. That is a wedge, and it is accepted: every
## chasing species is slower than the host, and `1` walks a clone home at 215px/s.
##
## What the check refuses to accept is the two ways a wedge goes wrong: **teleporting** (the body driven
## through the rock, or thrown by an epsilon divisor) and **oscillating** (two corrections fighting frame to
## frame, which reads as a body vibrating in place).
func _s3_a_body_wedged_against_a_rock(t) -> void:
	var w := World.new()
	w.setup(930)
	_silence_food(w)
	_clear_terrain(w)
	# One rock, written by hand. Literal centre and literal radius, so the bounds below do not come from the
	# thing under test.
	w.terrain.rock_pos.append(Vector2(600.0, 500.0))
	w.terrain.rock_radius.append(60.0)
	var rock := Vector2(600.0, 500.0)
	w.swarm.pos[0] = Vector2(2500.0, 2500.0)
	# 68px from the rock's centre = 60 + CLONE_BODY_RADIUS 8: already touching it, on the far side.
	var pinned := Vector2(532.0, 500.0)
	var c := w.swarm.add_clone(0, 10)
	w.swarm.pos[c] = pinned
	w.swarm.command_strike(pinned)
	w.swarm.atk_cd[c] = 1000000.0
	w.critter_count = 0
	w.boss_index = -1
	# Off-axis on purpose: the push the crow asks for points INTO the rock and sideways at once, so the
	# frame is the wedge — a straight-out push would simply be cancelled and prove nothing about sliding.
	w._write_critter(CROW, Vector2(525.0, 495.0), 10)
	w.critter_atk_cd[0] = 1000000.0
	w.critter_hp[0] = 1000000
	t.ok(absf(pinned.distance_to(rock) - 68.0) < 0.001,
			"설정: 분신은 바위 표면에 딱 붙어 있다 (중심에서 68px = 60 + 8)")
	t.ok(pinned.distance_to(w.critter_pos[0]) < CROW10_CLONE_REST,
			"설정: 그런데 까마귀 안에도 들어가 있다 — 밀 곳이 바위뿐인 자리다 (%.3f < 22)"
					% pinned.distance_to(w.critter_pos[0]))

	w.step(DT)
	var moved: float = w.swarm.pos[c].distance_to(pinned)
	t.ok(moved > 0.5, "밀어내기는 실제로 일어난다 — 바위 면을 따라 미끄러진다 (%.3f)" % moved)
	t.ok(moved < CROW10_CLONE_REST,
			"그리고 순간이동은 없다 — 한 프레임 이동이 밀어내는 거리 22px 자체를 못 넘는다 (%.3f)" % moved)

	var deepest := INF
	for _s in 59:
		w.step(DT)
		deepest = minf(deepest, w.swarm.pos[c].distance_to(rock))
	var settled: Vector2 = w.swarm.pos[c]
	for _s in 60:
		w.step(DT)
		deepest = minf(deepest, w.swarm.pos[c].distance_to(rock))
	# ⚠ **68 − `Terrain.TOUCH_EPS`, not 68.** `push_out()` accepts a candidate whose deepest penetration is
	# within `TOUCH_EPS` — that tolerance is the rock's own contract and it existed before this pass. Written
	# as a bare 68 the check reds at 67.997 and measures the rock, not the separation.
	t.ok(deepest >= 68.0 - Terrain.TOUCH_EPS,
			"두 초 어느 프레임에도 분신이 바위 안으로 들어간 적이 없다 (가장 깊었던 순간 %.3f)" % deepest)
	t.eq(w.swarm.pos[c], settled, "60프레임 뒤와 120프레임 뒤가 같은 좌표다 — 끼인 몸은 떨지 않는다")


# -- S4: the rest distance stays INSIDE the attack band ----------------------------------------------------
## ⚠ **The failure this exists for is silent and total.** Separation and `_contact()`'s bare-clone band are
## the same sum; rest a body ON it and half of all pairs land a float ulp outside, and **nothing steers a
## clone toward a creature**, so it never closes the gap again. Melee simply stops, with every other check
## in this file still green. `Rules.SEPARATION_CONTACT_MARGIN` is what holds the rest position inside, and
## this is the check that drives it rather than reasoning about it.
##
## Five seconds, `Rules.CLONE_ATTACK_PERIOD` 1.2s: hits at 0.017 · 1.217 · 2.417 · 3.617 · 4.817 — five of
## them, each for the clone's own force 10.
func _s4_a_separated_clone_still_lands_every_hit(t) -> void:
	var at := Vector2(1500.0, 1500.0)
	var w := World.new()
	w.setup(940)
	_silence_food(w)
	_clear_terrain(w)
	w.swarm.pos[0] = Vector2(300.0, 300.0)
	var c := w.swarm.add_clone(0, 10)
	w.swarm.pos[c] = at
	w.swarm.hp[c] = 1000000
	w.swarm.command_strike(at)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(CROW, at + Vector2(5.0, 0.0), 10)
	w.critter_hp[0] = 1000000
	var hp_before: int = int(w.critter_hp[0])

	for _s in 300:
		w.step(DT)
	t.eq(hp_before - int(w.critter_hp[0]), 50,
			"밀려난 뒤에도 분신은 5초 동안 다섯 번 전부 문다 — 쉬는 거리가 때리는 띠 안에 있다")
	var gap: float = w.swarm.pos[c].distance_to(w.critter_pos[0])
	t.ok(gap < CROW10_CLONE_BAND,
			"그 거리는 맨몸 판정 띠 23px보다 짧다 (%.3f)" % gap)
	t.ok(gap > CROW10_CLONE_REST - 1.001,
			"그런데 21px보다는 멀다 — 붙어 있는 것이 아니라 딱 밖에 서 있는 것이다 (%.3f)" % gap)


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


# ========================================================================================================
# M: 한 방의 상한 — `Rules.MAX_HIT_FRACTION`
# ========================================================================================================
## 사자 · 코끼리 · 보스가 체력 30짜리 호스트를 첫 접촉에 죽이던 것이 사라진 자리다. 사용자가 보스까지
## 가지 못한 이유가 이것이었고, 그래서 여기서 재는 것은 「한 방이 얼마인가」 하나뿐이다 — 몇 초 만에 죽는가는
## `_u14`(무적 시간)와 `_c13`(공격 주기)이 이미 잰다.


# -- M1: 한 방은 맞는 쪽 최대 체력의 절반을 넘지 않는다 ---------------------------------------------------
## ⚠ **네 종을 한 함수에서 재는 것이 이 검사를 물게 한다.** 까마귀는 상한 **아래**라 안 바뀌고 나머지 셋은
## 잘리므로, 「전부 15」로도 「전부 제 힘」으로도 만족시킬 수 없다. 15는 손으로 계산한 값이다 — 최대 30의 절반.
func _m1_one_blow_never_takes_more_than_half(t) -> void:
	t.eq(_one_blow(700, CROW, 10, 0), 10,
			"까마귀 10은 상한 15 아래라 그대로 10이 들어온다 — 세 방이라는 초반의 약속이 안 깨진다")
	t.eq(_one_blow(701, LION, 62, 0), 15, "사자 62는 15에서 잘린다")
	t.eq(_one_blow(702, ELEPHANT, 78, 0), 15,
			"코끼리 78도 똑같이 15다 — 상한을 정하는 것은 때리는 쪽의 힘이 아니라 맞는 쪽의 최대 체력이다")
	t.eq(_one_blow(703, BOSS, 120, 0), 15, "보스 120도 예외가 없다 — 종별 면제 칸은 만들지 않았다")


# -- M2: 까마귀 · 말 · 사자가 진짜 프레임 안에서 한 대씩 때린다 -------------------------------------------
## ⚠ **`_contact`를 손으로 부르는 대신 `step(DT)`를 돌린다.** M1은 규칙을, 이쪽은 그 규칙이 실제 프레임
## 경로에 실려 있는지를 잰다. 그리고 세 종의 답이 셋 다 달라야 한다: 까마귀는 안 잘리고, 사자는 잘리고,
## **말은 아예 안 때린다** — 도망치는 종은 `_contact` 2패스 첫 줄에서 돌아선다.
func _m2_three_species_land_one_hit_through_a_real_frame(t) -> void:
	t.eq(_one_hit_through_step(710, CROW, 10), 10, "까마귀 한 대는 10이다")
	t.eq(_one_hit_through_step(711, LION, 62), 15, "사자 한 대는 15다 — 62가 아니라")
	t.eq(_one_hit_through_step(712, HORSE, 35), 0, "말은 붙어 있어도 한 대도 안 때린다")
	t.eq(int(Rules.SPECIES_FLEES[HORSE]), 1,
			"그게 상한 때문이 아니라 말이 도망치는 종이기 때문이라는 것까지 못 박는다")
	# ⚠ **계기 자신을 뒤집는 줄이다.** 위의 0은 「사거리 밖에 세웠다」로도 나온다 — 같은 자리에서 도망 칸만
	# 눕혀 15가 들어오는 것을 보여야 0이 도망 때문이라는 증거가 된다.
	t.eq(_one_hit_through_step(713, HORSE, 35, true), 15,
			"같은 자리에서 도망 칸만 눕히면 15가 들어온다 — 그 자리는 사거리 안이었다")


# -- M3: 그래서 호스트가 몇 방을 견디는가 ------------------------------------------------------------------
## 방 수는 손으로 계산한 것이다: 최대 30, 상한 15. 까마귀 10 → 10·10·10, 나머지 셋 → 15·15.
func _m3_how_many_blows_the_host_survives(t) -> void:
	t.eq(_blows(720, CROW, 10, 0), 3, "레벨 0에서 까마귀는 세 방이다 (30 ÷ 10)")
	t.eq(_blows(721, LION, 62, 0), 2, "사자는 두 방이다 (15 + 15) — 한 방이 아니다")
	t.eq(_blows(722, ELEPHANT, 78, 0), 2, "코끼리도 두 방이다")
	t.eq(_blows(723, BOSS, 120, 0), 2,
			"보스도 두 방이다 — 즉사는 사라졌지만 두 번 닿으면 그대로 끝난다")


# -- M4: 레벨은 한쪽으로만 산다 ----------------------------------------------------------------------------
## ⚠ **상한이 비율이라는 것이 여기서만 보인다.** 레벨 10에서 사자 한 방은 15가 아니라 30으로 **커지고**,
## 그래서 견디는 방 수는 그대로 둘이다. 레벨이 실제로 사 주는 것은 상한에 안 닿는 작은 것들뿐이다.
func _m4_a_level_moves_survivability_one_way_only(t) -> void:
	t.eq(_blows(730, CROW, 10, 10), 6, "레벨 10(최대 60)이면 까마귀는 여섯 방이다 — 세 방에서 두 배로 늘었다")
	t.eq(_one_blow(731, LION, 62, 10), 30, "그런데 사자 한 방은 15가 아니라 30이 된다 — 최대 60의 절반이다")
	t.eq(_blows(732, LION, 62, 10), 2, "그래서 사자는 레벨 10에서도 여전히 두 방이다")
	# ⚠ **레벨 11의 최대 체력 63은 홀수다.** `int(63 × 0.5)`는 내림이라 31이고, 두 방 뒤에 1이 남는다.
	# 보스전이 실제로 벌어지는 레벨이 이것이므로 세 방이 진짜 숫자다.
	t.eq(_blows(733, BOSS, 120, 11), 3,
			"레벨 11(최대 63)에서 보스는 세 방이다 — 상한 31이 내림이라 두 방 뒤에 1이 남는다")


# -- M5: 분신도 같은 상한을 받고, 무리가 때리는 쪽에는 상한이 없다 -----------------------------------------
## ⚠ **두 방향을 한 함수에 둔 것은 상한이 한 방향짜리이기 때문이다.** 맞는 쪽에만 걸고 때리는 쪽에 안 거는
## 것이 규칙이고, 양쪽에 거는 것은 그럴듯한 오답이다 — 그러면 필드의 모든 생물이 절대 두 방 안에 안 죽는다.
func _m5_the_cap_is_symmetric_and_one_directional(t) -> void:
	var w := World.new()
	w.setup(740)
	_silence_food(w)
	_clear_terrain(w)
	var c := w.swarm.add_clone(0, 10)
	t.eq(int(w.swarm.hp_max_of(c)), 30, "설정: 힘 10짜리 분신의 최대 체력은 30이다 (10 × 3)")
	t.eq(int(w.swarm.hp[c]), 30, "설정: 그리고 그 최대치로 태어난다")
	t.ok(not w._damage_clone(c, 62), "사자 힘 62짜리 한 방으로 분신이 지워지지 않는다")
	t.eq(int(w.swarm.hp[c]), 15, "들어간 것은 62가 아니라 15다 — 상한은 호스트 전용이 아니다")
	t.eq(w.swarm.count, 2, "무리의 수도 그대로다")
	t.ok(w._damage_clone(c, 62), "두 방째에 죽는다 — 상한은 무적이 아니다")

	# 반대 방향. 힘 10짜리 까마귀의 체력은 30이고, 그 절반은 15다 — 20짜리 한 방이 15로 잘리면 10이 아니라
	# 15가 남는다. 다섯의 차이가 「때리는 쪽에는 상한이 없다」의 전부다.
	var w2 := World.new()
	w2.setup(741)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.critter_count = 0
	w2.boss_index = -1
	var k := w2._write_critter(CROW, Vector2(2000.0, 2000.0), 10)
	t.eq(int(w2.critter_hp[k]), 30, "설정: 힘 10짜리 까마귀의 체력은 30이다")
	w2._damage_critter(k, 20, Vector2.ZERO)
	t.eq(int(w2.critter_hp[k]), 10,
			"생물에게 넣은 20은 20 그대로 들어간다 — 제 최대 체력의 절반 15로 잘리지 않는다")


# -- M의 계기 ---------------------------------------------------------------------------------------------
## 한 마리를 호스트 위에 정확히 세우고 접촉 한 번을 돌려, 깎인 체력을 돌려준다. **좌표가 같으므로 밀림
## 방향이 0이고 호스트는 안 움직인다** — 재려는 것이 거리가 아니라 한 방의 크기이기 때문이다.
## `critter_flees`를 0으로 눕히는 것은 도망치는 종도 「한 방이 얼마인가」를 물을 수 있게 하기 위해서다.
func _one_blow(seed_value: int, species: int, force_value: int, level_value: int) -> int:
	var w := _host_at_level(seed_value, level_value)
	w._write_critter(species, w.swarm.pos[0], force_value)
	w.critter_flees[0] = 0
	var before := w.host_hp
	w._contact(0, w.critter_pos[0])
	return before - w.host_hp


## 같은 것을 손으로 `_contact`를 부르지 않고 진짜 한 프레임으로 잰다. 20px 앞은 세 종 모두의 판정 띠 안이다
## (까마귀 29 · 말 41.5 · 사자 40, 전부 손으로 계산).
func _one_hit_through_step(seed_value: int, species: int, force_value: int,
		stand_and_fight: bool = false) -> int:
	var w := _host_at_level(seed_value, 0)
	w._write_critter(species, w.swarm.pos[0] + Vector2(20.0, 0.0), force_value)
	if stand_and_fight:
		w.critter_flees[0] = 0
	var before := w.host_hp
	w.step(DT)
	return before - w.host_hp


## 호스트가 그 종의 한 방을 몇 번 견디는가. 매번 무적 시간과 공격 시계를 도로 풀고 생물을 호스트 자리에
## 다시 세운다 — 이 함수는 시간이 아니라 방 수를 센다.
## ⚠ **한 대도 안 들어오면 -1을 돌려준다.** 0을 돌려주면 「맞자마자 죽었다」와 구별이 안 된다.
func _blows(seed_value: int, species: int, force_value: int, level_value: int) -> int:
	var w := _host_at_level(seed_value, level_value)
	w._write_critter(species, w.swarm.pos[0], force_value)
	w.critter_flees[0] = 0
	var n := 0
	while w.host_hp > 0 and n < 200:
		w.critter_pos[0] = w.swarm.pos[0]
		w.host_grace = 0.0
		w.critter_atk_cd[0] = 0.0
		var before := w.host_hp
		w._contact(0, w.critter_pos[0])
		if w.host_hp >= before:
			return -1
		n += 1
	return n


func _host_at_level(seed_value: int, level_value: int) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w.level = level_value
	# 최대 체력은 `Body`가 쓰는 그 함수에서 가져온다 — 여기 30 + 3 × level을 다시 적으면 두 번째 사본이다.
	w.host_hp = w.body.hp_max(level_value)
	return w
