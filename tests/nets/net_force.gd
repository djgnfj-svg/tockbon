extends RefCounted
## Force, splitting, absorbing — and the swap that has to carry force with a body when it dies.
##
## **The rule this file exists for is the swap.** `remove_at()` moves the last row down, and a missing
## `force[i] = force[last]` line lands a dead clone's force on a survivor with no error and nothing on
## screen. It only shows when the row being removed is NOT the last one, so the check below kills the
## middle of three clones — killing the only clone never runs the swap branch at all and the missing line
## stays green.
##
## **The second is conservation.** `total_force()` ships for these checks alone: a split conserves the
## total, and a hand-rolled sum in every check would be the second copy `CLAUDE.md` forbids. But a total is
## conserved under EVERY order, so the cap check pins WHICH rows halved, not only the sum.
##
## `sim/` only. Loading a view file here would let a broken panel take the force checks down with it — the
## one exception is `look.gd`'s constant map in check 17, which is read as data, not instantiated.

const DT := 1.0 / 60.0


func run(t) -> void:
	_c1_opening(t)
	_c2_to_c6_split(t)
	_c7_to_c9_hold(t)
	_c10_cap_order(t)
	_c11_child_of_a_clone(t)
	_c12_to_c14_absorb(t)
	_c15_c16_death(t)
	_c15b_clone_kill_is_carried(t)
	_c17_constants(t)
	_c18_clear_beat(t)
	_c22_wearing_a_second_part(t)
	_c23_worn_survives_the_swap(t)
	_f1_splitting_is_not_power_through_damage(t)
	_f4_absorbing_is_not_wearing(t)
	_f5_a_clone_fires_what_it_wears(t)
	_f6_nothing_goes_negative(t)
	_f7_hp_is_conserved_across_the_split(t)
	_f8_a_body_at_one_hp_does_not_split(t)
	_f9_the_hp_column_is_maintained(t)
	_f10_hp_moves_with_the_part(t)
	_f11_damage_writes_the_hit_and_knocks_back(t)
	_f12_level_fires_a_display_clock(t)
	_f13_split_shove_matches_the_formula(t)
	_f14_split_shove_survives_a_rock(t)
	_u16b_the_peak_is_a_high_water_mark(t)


# -- 1: the run opens alone, at force 10 ---------------------------------------------------------------
## Driven off a real `World.setup()`, not a bare `Swarm`: putting `START_CLONES` back and looping it in
## `World::setup()` is the mutation, and only a `World` sees that line. The 10 is a literal — read through
## `Rules.FORCE_START` this check passes at every value, including the 1 the design rejected.
func _c1_opening(t) -> void:
	var w := World.new()
	w.setup(1)
	t.eq(w.swarm.count, 1, "런은 호스트 하나로 열린다 — 분열해서 만들지 않은 몸은 없다")
	t.eq(w.swarm.total_force(), 10, "호스트의 시작 힘은 10이다")
	t.eq(w.peak_swarm, 0, "최대 무리도 0에서 시작한다")


# -- 2..6: what one full hold does ---------------------------------------------------------------------
func _c2_to_c6_split(t) -> void:
	# 2: an even value halves into two equal halves and the total is untouched.
	var sw := Swarm.new()
	sw.setup(2, Vector2(1000.0, 1000.0))
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 2, "한 번 다 감으면 몸이 둘이 된다")
	t.eq(sw.force[0], 5, "부모에게 5")
	t.eq(sw.force[1], 5, "아이에게 5")
	t.eq(sw.total_force(), 10, "나눠도 힘의 총합은 그대로다 — 분열이 힘을 만들지 않는다")

	# 3: odd, so the halves are DIFFERENT and swapping them is visible. An even value cannot see that
	# mutation at all.
	var sw3 := Swarm.new()
	sw3.setup(3, Vector2(1000.0, 1000.0))
	sw3.force[0] = 5
	sw3.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw3.force[0], 3, "홀수는 부모가 큰 쪽을 갖는다 (5 → 3)")
	t.eq(sw3.force[1], 2, "아이는 작은 쪽을 갖는다 (5 → 2)")

	# 4: cargo is something a body is HOLDING, not what it is made of. Force-only checks pass with the
	# cargo written either way, so both rows are read.
	var sw4 := Swarm.new()
	sw4.setup(4, Vector2(1000.0, 1000.0))
	sw4.carried[0] = 6.0
	sw4.hit_show[0] = 0.0
	sw4.hit_dir[0] = Vector2(1.0, 0.0)
	sw4.swing_show[0] = 0.0
	sw4.swing_dir[0] = Vector2(0.0, 1.0)
	sw4.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw4.carried[0], 6.0, "나눠도 싣고 있던 것은 부모가 전부 갖는다")
	t.eq(sw4.carried[1], 0.0, "아이는 빈 몸으로 나온다")
	# ⚠ **`add_clone()`이 상수를 무조건 쓰는 것이 `_split_fire()`를 네 번째 유지 지점으로 만들지 않는 이유다.**
	# 부모는 방금 맞은 채로(0.0) 갈라지는데, 갓 태어난 아이는 `INF`다 — 「갓 태어난 몸은 안 맞았다」가 기억이
	# 아니라 구조로 참이다.
	t.eq(sw4.hit_show[0], 0.0, "부모의 피격 시계는 그대로다")
	t.eq(sw4.hit_show[1], INF, "아이는 INF로 열린다 — 부모의 방금 맞은 시계를 물려받지 않는다")
	t.eq(sw4.hit_dir[1], Vector2.ZERO, "아이의 피격 방향도 물려받지 않는다")
	t.eq(sw4.swing_show[1], INF, "휘두름 시계도 마찬가지다")
	t.eq(sw4.swing_dir[1], Vector2.ZERO, "휘두른 방향도 물려받지 않는다 — 갓 태어난 몸은 휘두른 적이 없다")

	# 5: the split is simultaneous across EVERY body, not the host alone. Looping over index 0 only leaves
	# the clone's 3 whole and the total at 9.
	var sw5 := Swarm.new()
	sw5.setup(5, Vector2(1000.0, 1000.0))
	sw5.force[0] = 5
	sw5.add_clone(0, 3)
	sw5.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw5.count, 4, "호스트도 분신도 함께 갈라져 넷이 된다")
	t.eq([sw5.force[0], sw5.force[1], sw5.force[2], sw5.force[3]], [3, 2, 2, 1],
			"힘이 3·2·2·1로 나뉜다")
	t.eq(sw5.total_force(), 8, "총합은 5+3 그대로다")

	# 6: the loop bound is read ONCE. ⚠ **The mutation this catches is `while i < count`, not
	# `for i in count`** — measured on 4.7.1, `for i in <int>` evaluates its bound once, so dropping the
	# `snapshot` local changes nothing and this check would stay green against it. Rewritten as a `while`
	# that reads `count` live, the `2` that came out of a `5` is split again inside the same press and one
	# keypress walks force 10 down to a swarm of 1s.
	var sw6 := Swarm.new()
	sw6.setup(6, Vector2(1000.0, 1000.0))
	sw6.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw6.count, 2, "한 번 누름에 나온 아이는 그 자리에서 다시 갈라지지 않는다 (정확히 둘)")


# -- 7..9: the wind-up itself --------------------------------------------------------------------------
func _c7_to_c9_hold(t) -> void:
	# 7: force 1 cannot halve, and that is not an error.
	var sw := Swarm.new()
	sw.setup(7, Vector2(1000.0, 1000.0))
	sw.force[0] = 1
	sw.split_hold(Rules.SPLIT_HOLD_TIME * 2.0)
	t.eq(sw.count, 1, "힘 1짜리는 아무리 눌러도 갈라지지 않는다")
	t.eq(sw.force[0], 1, "그리고 힘도 줄지 않는다")

	# 8: an incomplete charge is dropped, not banked.
	var sw8 := Swarm.new()
	sw8.setup(8, Vector2(1000.0, 1000.0))
	sw8.split_hold(Rules.SPLIT_HOLD_TIME * 0.9)
	t.ok(sw8.split_charge > 0.0, "설정: 실제로 감기고 있었다 — 0이면 아래 검사는 아무것도 재지 않는다")
	t.eq(sw8.count, 1, "90%에서는 아직 갈라지지 않았다")
	sw8.split_release()
	t.eq(sw8.split_charge, 0.0, "손을 떼면 감긴 것이 버려진다")
	t.eq(sw8.count, 1, "떼는 것만으로 갈라지지도 않는다")

	# 9: **one split per hold.** Holding four times as long without ever releasing must add ONE body.
	# Mutation: zero the charge on firing and nothing else, and the key ratchets — the charge simply winds
	# again from zero and the swarm doubles every SPLIT_HOLD_TIME for as long as the finger is down.
	#
	# ⚠ The second half is not decoration. "One split per hold" is enforced by a latch, and a latch that is
	# never cleared satisfies the first assertion perfectly while making `F` a once-per-run key — measured:
	# with the clear removed from `split_release()` the first assertion alone stays green. The rule is one
	# split per hold, so the check has to see the NEXT hold split.
	var sw9 := Swarm.new()
	sw9.setup(9, Vector2(1000.0, 1000.0))
	var frames := int(4.0 * Rules.SPLIT_HOLD_TIME / DT)
	# ⚠ **The charge zeroing on FIRING was measured by nothing.** Every existing assertion about
	# `split_charge` exercises `split_release()`; `_hold_fired` latches the count either way, so deleting
	# `split_charge = 0.0` from the firing path left the whole round green while `field_view.gd` drew the
	# wind-up ring pinned FULL for as long as the finger stayed down — the split already landed and the
	# only feedback the hold has says it has not. Captured at the frame the body appeared, not at the end.
	var charge_at_fire := -1.0
	for _f in frames:
		var count_before := sw9.count
		sw9.split_hold(DT)
		if sw9.count > count_before and charge_at_fire < 0.0:
			charge_at_fire = sw9.split_charge
	t.eq(charge_at_fire, 0.0, "갈라진 그 순간 감김이 0으로 비워진다 (떼기를 기다리지 않는다)")
	t.eq(sw9.count, 2, "떼지 않고 네 배로 눌러도 몸은 하나만 늘어난다")
	sw9.split_release()
	for _f in int(Rules.SPLIT_HOLD_TIME / DT) + 1:
		sw9.split_hold(DT)
	t.eq(sw9.count, 4, "손을 뗐다가 다시 누르면 두 몸이 다시 갈라진다")


# -- 10: over the cap, the LOWEST indices split ---------------------------------------------------------
## ⚠ **Attack the check first.** With every body at the same force, "which rows halved" is unfalsifiable —
## reversing the order leaves an identical array. So every body gets a different force and the setup
## asserts that before anything else. The total is asserted too, but it is the weaker half: a total is
## conserved under every order.
func _c10_cap_order(t) -> void:
	var sw := Swarm.new()
	sw.setup(10, Vector2(1000.0, 1000.0))
	sw.force[0] = 4
	for i in Rules.CLONE_CAP - 3:
		sw.add_clone(0, 6 + 2 * i)
	var bodies := sw.count
	t.eq(bodies, Rules.CLONE_CAP - 2, "설정: 상한 세 자리를 남기고 채웠다")

	var before: Array = []
	var distinct := {}
	var sum_before := 0
	for i in bodies:
		before.append(sw.force[i])
		distinct[sw.force[i]] = true
		sum_before += sw.force[i]
	t.eq(distinct.size(), bodies, "설정: 몸마다 힘이 다르다 — 같으면 순서 주장은 반증 불가능해진다")

	sw.split_hold(Rules.SPLIT_HOLD_TIME)

	var moved: Array = []
	for i in bodies:
		if sw.force[i] != before[i]:
			moved.append(i)
	t.eq(moved, [0, 1, 2], "상한에 걸리면 낮은 번호부터 갈라진다 (0·1·2만 반으로 줄었다)")
	t.eq(sw.force[bodies - 1], before[bodies - 1], "가장 높은 번호는 힘을 통째로 지킨다")
	t.eq(sw.count - 1, Rules.CLONE_CAP, "분신 수가 상한에서 정확히 멈춘다")
	t.eq(sw.total_force(), sum_before, "상한에 걸려도 힘의 총합은 보존된다")


# -- 11: a clone's child is born at ITS parent ----------------------------------------------------------
## The parent sits 900px from the host on purpose: `add_clone()` used to spawn from `pos[0]` with
## `state[0]`, and reusing it unchanged puts every child of every clone on the host — invisible to any
## check that only ever splits the host.
func _c11_child_of_a_clone(t) -> void:
	var sw := Swarm.new()
	sw.setup(11, Vector2(1000.0, 1000.0))
	var p := sw.add_clone(0, 6)
	sw.pos[p] = sw.pos[0] + Vector2(900.0, 0.0)
	sw.state[p] = Swarm.SCATTER
	sw.force[0] = 1   ## the host cannot split, so the only new body is the clone's
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 3, "설정: 분신 하나만 갈라졌다")
	var child := 2
	# §F-10: 갈라진 두 몸은 그 자리에서 서로 반대로 한 번 더 밀린다 — `CLONE_SPAWN_RING`만이 아니라 그 위에
	# `2 × 아이의 힘 × KNOCKBACK_PER_FORCE`가 더 벌어진다 (부모가 뒤로, 아이가 앞으로, 같은 축을 따라).
	var shove := 2.0 * float(sw.force[child]) * Rules.KNOCKBACK_PER_FORCE
	t.ok(sw.pos[child].distance_to(sw.pos[p]) <= Rules.CLONE_SPAWN_RING + shove + 0.01,
			"아이는 제 부모 곁에 나온다 — 밀림까지 합쳐 (%.1f, 기대 상한 %.1f)"
					% [sw.pos[child].distance_to(sw.pos[p]), Rules.CLONE_SPAWN_RING + shove])
	t.ok(sw.pos[child].distance_to(sw.pos[0]) > 800.0, "호스트 위에 나오지 않는다")
	t.eq(sw.state[child], Swarm.SCATTER, "아이는 부모의 상태를 물려받는다")


# -- 12..14: V ------------------------------------------------------------------------------------------
func _c12_to_c14_absorb(t) -> void:
	# 12: reach is ABSORB_RADIUS_BODIES × BODY_RADIUS = 56px. Two inside, one at 300px outside.
	var sw := Swarm.new()
	sw.setup(12, Vector2(1000.0, 1000.0))
	var near_a := sw.add_clone(0, 4)
	sw.pos[near_a] = sw.pos[0] + Vector2(30.0, 0.0)
	sw.carried[near_a] = 3.0
	var near_b := sw.add_clone(0, 6)
	sw.pos[near_b] = sw.pos[0] + Vector2(0.0, 50.0)
	sw.carried[near_b] = 2.0
	var far := sw.add_clone(0, 7)
	sw.pos[far] = sw.pos[0] + Vector2(300.0, 0.0)
	sw.carried[far] = 5.0

	t.eq(sw.absorb(), 2, "반경 안 둘만 흡수된다")
	t.eq(sw.count, 2, "흡수된 몸은 사라진다")
	# The literal 20 is 10 + 4 + 6, written out rather than read back from the clones: summing the same
	# fields the code summed would pass against a routine that adds nothing at all.
	t.eq(sw.force[0], 20, "흡수한 힘이 호스트에 정확히 더해진다")
	t.eq(sw.banked, 5.0, "싣고 있던 것도 함께 들어온다")
	t.eq(sw.force[1], 7, "반경 밖 분신의 힘은 건드리지 않는다")
	t.eq(sw.carried[1], 5.0, "반경 밖 분신의 화물도 그대로다")

	# 13: nothing in range is a real 0, not a silent success.
	var sw13 := Swarm.new()
	sw13.setup(13, Vector2(1000.0, 1000.0))
	var away := sw13.add_clone(0, 5)
	sw13.pos[away] = sw13.pos[0] + Vector2(400.0, 0.0)
	sw13.carried[away] = 2.0
	t.eq(sw13.absorb(), 0, "닿는 게 없으면 0을 돌려준다")
	t.eq(sw13.count, 2, "아무 몸도 사라지지 않는다")
	t.eq(sw13.force[0], 10, "호스트의 힘도 그대로다")
	t.eq(sw13.banked, 0.0, "은행도 그대로다")

	# 14: V MOVES cargo, it does not find it. Routed through `eat()` the same mouthful would be counted
	# twice and walking a clone home would be worth double.
	var sw14 := Swarm.new()
	sw14.setup(14, Vector2(1000.0, 1000.0))
	var loaded := sw14.add_clone(0, 3)
	sw14.pos[loaded] = sw14.pos[0] + Vector2(10.0, 0.0)
	sw14.eat(loaded, 4.0)   ## picked up in the field: `eaten` was already paid here
	var eaten_before := sw14.eaten
	var banked_before := sw14.banked
	t.eq(sw14.absorb(), 1, "설정: 실제로 하나를 흡수했다")
	t.ok(sw14.banked > banked_before, "V로 돌아온 화물은 은행에 들어온다")
	t.eq(sw14.eaten, eaten_before, "V는 먹은 총량을 올리지 않는다")


# -- 15/16: a body that dies takes its force with it ----------------------------------------------------
func _c15_c16_death(t) -> void:
	# 15: the one rule the whole build rests on, now with force alongside cargo. Neither reaches the host.
	var w := World.new()
	w.setup(15)
	_silence_food(w)
	var k := w.swarm.add_clone(0, 9)
	w.swarm.pos[k] = Vector2(500.0, 500.0)
	w.swarm.carried[k] = 9.0
	var banked_before: float = w.swarm.banked
	var force0_before: int = w.swarm.force[0]
	_clear_terrain(w)
	w.critter_count = 1
	w.critter_pos[0] = Vector2(500.0, 500.0)
	_crow_row(w, 0, 10)
	w.critter_dir[0] = Vector2.ZERO
	# 결정: a clone has hp, so a body dies when it is brought to zero and not when it is touched. Written
	# down to five so one force-10 crow hit finishes it — this check is about what a DEATH costs, and
	# spending three attack periods getting there would only make it flakier.
	w.swarm.hp[k] = 5
	w.step(DT)
	t.eq(w.swarm.count, 1, "설정: 물린 분신이 실제로 사라졌다")
	t.eq(w.swarm.banked, banked_before, "밖에서 죽은 분신의 화물은 은행에 들어오지 않는다")
	t.eq(w.swarm.force[0], force0_before, "그 힘도 호스트로 돌아오지 않는다")
	t.eq(w.swarm.total_force(), force0_before, "죽은 몸의 힘은 무리 어디에도 남지 않는다")

	# 16: ⚠ the row removed is NOT the last one. Killing the only clone hits `i == last`, the swap branch
	# never runs, and a missing `force[i] = force[last]` line stays green.
	var sw := Swarm.new()
	sw.setup(16, Vector2(1000.0, 1000.0))
	var c1 := sw.add_clone(0, 3)
	sw.carried[c1] = 1.0
	var c2 := sw.add_clone(0, 5)
	sw.carried[c2] = 2.0
	var c3 := sw.add_clone(0, 7)
	sw.carried[c3] = 4.0
	t.eq(sw.count, 4, "설정: 분신 셋을 세웠다")
	sw.remove_at(1)
	t.eq(sw.count, 3, "가운데 하나가 사라졌다")
	t.eq(sw.force[1], 7, "마지막 줄이 내려오면서 제 힘을 그대로 들고 왔다")
	t.eq(sw.carried[1], 4.0, "제 화물도 그대로 들고 왔다")
	t.eq(sw.force[2], 5, "건드리지 않은 줄은 그대로다")
	t.eq(sw.total_force(), 10 + 7 + 5, "사라진 몸의 힘 3만 총합에서 빠졌다")


# -- 15b: a clone attacks what it touches, and its KILL is carried home, never banked ---------------------
## ⚠ **This check's old subject was deleted with the threat model and its claim is now back on a different
## mechanism.** It used to drive `World._contact()`'s hunter branch, where the swarm ate a creature on
## contact and `eat(0, ...)` would have banked a clone's kill from anywhere on the map. Contact pays
## nothing at all now; **the corpse pays**, and `_step_corpses()` calls `eat(eater, ...)` — so the payout is
## where the one-character mutation lives, and this is the check that sees it.
##
## Two halves, one fixture, and neither covers the other: a clone damages what it touches with **its own
## force**, and when it finishes the corpse the 경험치 lands in `carried` 1000px from home, where losing
## the clone on the way back still costs it.
func _c15b_clone_kill_is_carried(t) -> void:
	var w := World.new()
	w.setup(151)
	_silence_food(w)
	_clear_terrain(w)
	var c := w.swarm.add_clone(0, 7)
	var out := Vector2(500.0, 500.0)
	w.swarm.pos[c] = out
	# STRIKE standing on its own strike point: `desired` is zero, so the clone is exactly where it was put
	# when contact is tested, rather than a frame's walk toward the host.
	w.swarm.command_strike(out)
	w.critter_count = 1
	w.critter_pos[0] = out
	_crow_row(w, 0, 10)
	w.critter_dir[0] = Vector2.ZERO
	t.ok(w.swarm.pos[0].distance_to(out) > 1000.0, "설정: 호스트는 1000px 넘게 떨어져 있다")
	t.eq(w.critter_hp[0], 30, "설정: 힘 10짜리 까마귀는 체력 30으로 선다")
	var banked_before: float = w.swarm.banked
	var eaten_before: float = w.swarm.eaten
	w.step(DT)
	# 7, not the host's 10 and not a constant: the damage a body deals is the force written on THAT row.
	t.eq(w.critter_hp[0], 23, "닿은 분신이 제 힘 7만큼 깎았다")
	t.eq(w.swarm.banked, banked_before, "접촉만으로는 은행에 아무것도 들어오지 않는다")
	t.eq(w.swarm.eaten, eaten_before, "먹은 총량도 움직이지 않는다 — 값은 시체를 다 먹어야 나온다")

	# The other half: the same clone, still 1000px from home, finishes a corpse. The corpse is written by
	# hand rather than killed for, so the force it pays on is a literal and not the 8–12 roll.
	#
	# ⚠ **The crow is walked off the spot first, and that is not tidying.** `World._separate_from_critters()`
	# pushes a body out of a LIVE creature every frame, and the crow this fixture just struck is countering —
	# it follows the clone, so the clone is driven off the coordinate the corpse is written at and the meal
	# stalls at one bite. The half being measured here is a CORPSE, which the pass deliberately does not
	# touch; a live creature standing on it is a different rule and belongs to whoever measures that one.
	w.critter_pos[0] = Vector2(700.0, 300.0)
	w.critter_counter[0] = 0.0
	t.eq(w.swarm.carried[c], 0.0, "설정: 분신은 아직 아무것도 싣고 있지 않다")
	w.corpse_count = 1
	w.corpse_pos[0] = out
	w.corpse_species[0] = Parts.Species.CROW
	w.corpse_force[0] = 10
	w.corpse_bites_left[0] = w._bites_for(10)
	# One frame short of the FIRST bite, so the step that follows starts paying immediately. §C floors a
	# force-10 crow at three bites (`CORPSE_BITES_MIN`) regardless of `corpse_progress`, so finishing the
	# whole corpse now takes a short loop (30 frames total, measured) rather than the single frame it used
	# to take when one crossing of 1.0 finished the meal outright.
	w.corpse_progress[0] = 0.999
	var meal_frames := 0
	while w.corpse_count > 0 and meal_frames < 60:
		w.step(DT)
		meal_frames += 1
	t.eq(w.corpse_count, 0, "설정: 시체를 실제로 다 먹었다 (%d프레임)" % meal_frames)
	# 30 = 힘 10 × EXP_PER_FORCE 3. Literal, because reading it back off `corpse_force` passes at any rate.
	# **세 입의 합**이다 — 한 입에 10씩, 셋을 다 넘겨야 30이다.
	t.eq(w.swarm.carried[c], 30.0, "분신이 다 먹은 값은 그 분신이 싣는다 (10 × 3)")
	t.eq(w.swarm.banked, banked_before, "멀리 있는 분신의 값은 은행에 바로 들어오지 않는다")
	t.eq(w.swarm.eaten, eaten_before + 30.0, "먹은 총량은 시체를 다 먹은 그때까지 세 입의 합으로 딱 30만큼 움직인다")

	# And the link the two halves above both stand on: a kill leaves a corpse, **where it died**, carrying
	# copies of what it was. The death position is pinned by hand — the mutation this catches (writing
	# `swarm.pos[0]` as the corpse's position) is only visible against a coordinate the host is nowhere near,
	# and the same coordinate has to be re-stated here because the crow is free to walk between the two.
	# ⚠ This is the ONLY thing in the round that reads `_add_corpse` at all until `net_eating` exists.
	w.critter_pos[0] = Vector2(700.0, 300.0)
	w._damage_critter(0, 999)
	t.eq(w.critter_count, 0, "설정: 까마귀가 실제로 죽었다")
	t.eq(w.corpse_count, 1, "죽으면 시체가 하나 남는다")
	t.eq(w.corpse_pos[0], Vector2(700.0, 300.0), "시체는 쓰러진 그 자리에 남는다")
	t.eq(w.corpse_species[0], int(Parts.Species.CROW), "시체는 제 종을 그대로 들고 있다")
	t.eq(w.corpse_force[0], 10, "시체는 제 힘을 그대로 들고 있다 — 죽은 줄을 다시 읽지 않는다")
	t.eq(w.corpse_progress[0], 0.0, "새 시체는 아무도 안 먹은 상태로 시작한다")


# -- 17: constants against constants --------------------------------------------------------------------
## A reach smaller than the body it belongs to is the bug the user caught on the first play. Written
## constant-against-constant so it holds however either is tuned.
##
## The third assertion is the one-owner rule. **`Look.HOST_RADIUS` no longer exists**, so it cannot be
## compared against `Rules.BODY_RADIUS`; what is left to protect is that a second copy never comes back.
## Read as `look.gd`'s runtime constant map rather than as file text — a grep measures a file's letters,
## this measures what the class actually declares.
func _c17_constants(t) -> void:
	t.ok(Rules.EAT_RADIUS_HOST > Rules.BODY_RADIUS, "호스트의 먹는 거리는 제 몸보다 넓다")
	t.ok(Rules.EAT_RADIUS_CLONE > Rules.CLONE_BODY_RADIUS, "분신의 먹는 거리는 제 몸보다 넓다")

	var look_script: GDScript = load("res://src/look.gd")
	var consts: Dictionary = look_script.get_script_constant_map()
	t.ok(consts.has("CLONE_LOAD_GROWTH"),
			"설정: 상수 목록을 실제로 읽었다 — 비어 있으면 아래 검사는 저절로 통과한다")
	t.ok(not consts.has("HOST_RADIUS") and not consts.has("CLONE_RADIUS"),
			"몸 반지름은 rules.gd 한 곳에만 있다 (look.gd에 사본이 없다)")


# -- 18: the clear beat still ends, ends EARLY, and conserves force ---------------------------------------
## `_clear_arrivals()` removing a body on arrival is the only thing that ever makes `swarm.count <= 1`
## true. **Deleting it does not hang the run** — `Run._finish_clear()`'s fallback still fires when
## `absorb_beat` runs out — so "the phase reached ENDING" alone is not the check.
##
## ⚠ **The tick bound comes from the beat's own clock, not a bare literal.** Written as 40 against a
## 72-tick beat, retuning `CLEAR_ABSORB_TIME` to 0.5 would put the fallback path at 30 ticks — under 40 —
## and this check would have reported "it ended the instant everyone arrived" with nothing having arrived
## early at all. The staggered arrivals are pinned separately, and that half cannot be satisfied by one
## lump removal at any beat length.
##
## **And the total force is asserted across the beat.** Three functions bring a body home and only
## `absorb()` used to move force; the other two dropped it, so `total_force()` was silently not conserved
## through the one moment the whole swarm comes back. This one assertion pins all three paths.
func _c18_clear_beat(t) -> void:
	var r := Run.new()
	r.start(18)
	_silence_food(r.world)
	r.world.critter_count = 0
	# Staggered radii, not one shared ring: six bodies at the same distance arrive on the SAME frame, and
	# then "several distinct frames" is unfalsifiable no matter how the removal is written.
	for i in 6:
		var c := r.world.swarm.add_clone(0, 1)
		var a := float(i) * 1.05
		r.world.swarm.pos[c] = r.world.swarm.pos[0] + Vector2(cos(a), sin(a)) * (100.0 + float(i) * 40.0)
	t.eq(r.world.swarm.count, 7, "설정: 분신 여섯을 세웠다")
	var force_before: int = r.world.swarm.total_force()
	t.eq(force_before, 16, "설정: 호스트 10 + 분신 여섯의 1 = 16")
	r.world.stage_cleared = true
	r.step(DT)
	t.eq(r.phase, Run.Phase.PLAY, "설정: 클리어를 감지했고 아직 박동 중이다")
	var ticks := 0
	var drops := 0
	var prev_count: int = r.world.swarm.count
	while r.phase == Run.Phase.PLAY and ticks < 300:
		r.step(DT)
		if r.world.swarm.count < prev_count:
			drops += 1
		prev_count = r.world.swarm.count
		ticks += 1
	t.eq(r.phase, Run.Phase.ENDING, "박동이 끝나고 ENDING에 도달한다")
	t.eq(r.world.swarm.count, 1, "박동이 끝나면 호스트만 남는다")
	t.ok(ticks < int(Rules.CLEAR_ABSORB_TIME / DT) / 2,
			"다 도착한 순간 끝난다 — 박동의 시계를 절반도 못 채운다 (%d틱)" % ticks)
	t.ok(drops >= 3, "몸이 한 덩어리로가 아니라 여러 프레임에 걸쳐 하나씩 도착한다 (%d번 줄었다)" % drops)
	t.eq(r.world.swarm.total_force(), force_before,
			"돌아온 몸의 힘이 호스트에 남는다 — 박동을 건너며 총합이 새지 않는다")


# -- 19f: DELETED with the threat model, and its claim moved rather than vanished ------------------------
## ⚠ **Do not write this check again.** It drove `World.is_hunter_of()`: `F` conserves the total and
## multiplies the rows, so the build's one strength comparison flipped for free the moment it read
## `swarm.count`, and every conservation check in this file stayed green through it because the total
## really was conserved. The comparison itself is now deleted — nothing in the sim compares two strengths —
## so the check has no subject left to drive, and a port that read `swarm.count` somewhere else would be
## measuring a rule the design threw away.
##
## **The claim survives in `_f1_splitting_is_not_power_through_damage`**, on the mechanism that replaced
## it: two halves deal the same total damage as the unsplit body. Splitting is still not a power-up; what
## measures it is damage rather than a comparison.


# -- 22: a second part SUBTRACTS the first before it adds itself -----------------------------------------
## The written-never-derived rule, on a clone. Ghost force from a digested part is force `F` then multiplies,
## and it is invisible to every conservation check in this file because the total really is conserved — the
## row simply carries a number nothing paid for.
func _c22_wearing_a_second_part(t) -> void:
	var w := World.new()
	w.setup(220)
	_silence_food(w)
	var c := w.swarm.add_clone(0, 6)
	# A clone at force 6 already wearing 까마귀 부리 (FORCE 4): 6 + 4 = 10, written by hand so the numbers
	# below are literals rather than whatever a first roll happened to produce.
	w.swarm.worn[c] = Parts.CROW_BEAK
	w.swarm.force[c] = 10
	t.eq(int(Parts.FORCE[Parts.CROW_BEAK]), 4, "설정: 까마귀 부리의 힘은 4다 (리터럴)")
	t.eq(int(Parts.FORCE[Parts.HORSE_LEGS]), 5, "설정: 말 다리의 힘은 5다 (리터럴)")
	# ⚠ `_roll_until_keeping`, not `_roll_until`: the second helper clears `worn` between attempts, which is
	# exactly the precondition this check is about, and it made the check read 15 instead of 11.
	t.ok(_roll_until_keeping(w, c, int(Parts.Species.HORSE), Parts.HORSE_LEGS),
			"설정: 말 시체에서 말 다리가 실제로 나왔다")
	t.eq(int(w.swarm.force[c]), 11,
			"두 번째 부품은 첫 번째의 힘을 먼저 빼고 제 힘을 더한다 — 10 − 4 + 5 = 11 (리터럴)")
	t.eq(w.swarm.worn[c], Parts.HORSE_LEGS, "그리고 걸치고 있는 것은 새 부품 하나다")


# -- 23: `worn` survives the swap, and a split child wears -1 --------------------------------------------
func _c23_worn_survives_the_swap(t) -> void:
	var sw := Swarm.new()
	sw.setup(230, Vector2(1000.0, 1000.0))
	var a := sw.add_clone(0, 4)
	var b := sw.add_clone(0, 4)
	var c := sw.add_clone(0, 4)
	sw.worn[a] = Parts.CROW_WING
	sw.worn[b] = Parts.CROW_BEAK
	sw.worn[c] = Parts.HORSE_LEGS
	# `hit_show`/`hit_dir`/`swing_show`는 셋 다 `INF`/`ZERO`로 태어나므로, 같은 값이면 스왑이 없어도 초록이다
	# — `flees`의 주석이 이미 이름 붙인 함정이다. 세 줄 모두 서로 다른, 유한한 값을 손으로 써서 구분한다.
	sw.hit_show[a] = 1.0
	sw.hit_dir[a] = Vector2(1.0, 0.0)
	sw.swing_show[a] = 1.5
	sw.swing_dir[a] = Vector2(1.0, 1.0).normalized()
	sw.hit_show[b] = 2.0
	sw.hit_dir[b] = Vector2(0.0, 1.0)
	sw.swing_show[b] = 2.5
	sw.swing_dir[b] = Vector2(-1.0, 1.0).normalized()
	sw.hit_show[c] = 3.0
	sw.hit_dir[c] = Vector2(-1.0, 0.0)
	sw.swing_show[c] = 3.5
	sw.swing_dir[c] = Vector2(1.0, -1.0).normalized()
	t.eq(sw.count, 4, "설정: 서로 다른 부품을 걸친 분신 셋을 세웠다")
	# ⚠ The row removed is NOT the last one — `remove_at` only enters its swap branch then.
	sw.remove_at(b)
	t.eq(sw.count, 3, "가운데 하나가 사라졌다")
	t.eq(sw.worn[1], Parts.CROW_WING, "건드리지 않은 줄은 제 부품 그대로다")
	t.eq(sw.worn[2], Parts.HORSE_LEGS, "내려온 줄도 제 부품을 들고 왔다 — 죽은 놈의 것을 물려받지 않는다")
	t.eq(sw.worn[0], -1, "호스트는 언제나 -1이다 — 호스트의 부품은 Body의 열한 칸에 있다")
	t.eq(sw.hit_show[1], 1.0, "건드리지 않은 줄의 피격 시계도 제 것이다")
	t.eq(sw.hit_show[2], 3.0, "내려온 줄은 제 피격 시계를 들고 왔다 — 죽은 놈의 2.0이 아니다")
	t.eq(sw.hit_dir[2], Vector2(-1.0, 0.0), "피격 방향도 제 것을 들고 왔다")
	t.eq(sw.swing_show[2], 3.5, "휘두름 시계도 제 것을 들고 왔다")
	t.eq(sw.swing_dir[1], Vector2(1.0, 1.0).normalized(), "건드리지 않은 줄의 휘두른 방향도 제 것이다")
	t.eq(sw.swing_dir[2], Vector2(1.0, -1.0).normalized(),
			"내려온 줄은 휘두른 방향도 제 것을 들고 왔다 — 죽은 놈의 것이 아니다")

	# The split writes nothing into `worn`: `add_clone()` hardcodes -1, which is exactly why the split is not
	# a fourth maintenance point for this column.
	var child := sw.add_clone(2, 5)
	t.eq(sw.worn[child], -1, "나눠서 태어난 아이는 부모의 부품을 물려받지 않는다")


# -- F1: splitting is not a power-up, measured through DAMAGE --------------------------------------------
## ⚠ **This replaces `_c19f`'s measurement, not its claim.** The old one watched the build's one strength
## comparison; there is no comparison left. What is left is that two halves hit for what one whole hit for.
##
## ⚠ **`_contact()` is driven directly and both clocks are zeroed by hand.** A split child cannot attack for
## a full `CLONE_ATTACK_PERIOD` otherwise, and over that period the crow's own counter fires and moves it.
func _f1_splitting_is_not_power_through_damage(t) -> void:
	var at := Vector2(500.0, 500.0)
	var whole := World.new()
	whole.setup(240)
	_silence_food(whole)
	_clear_terrain(whole)
	whole.critter_count = 0
	whole.boss_index = -1
	whole._write_critter(Parts.Species.CROW, at, 10)
	whole.critter_hp[0] = 900
	whole.critter_atk_cd[0] = 99.0
	var c := whole.swarm.add_clone(0, 10)
	whole.swarm.pos[c] = at
	whole.swarm.atk_cd[c] = 0.0
	var hp0: int = int(whole.critter_hp[0])
	whole._contact(0, at)
	var one_hit := hp0 - int(whole.critter_hp[0])
	t.eq(one_hit, 10, "설정: 힘 10짜리 분신 하나가 한 번에 10을 깎는다")

	var split := World.new()
	split.setup(241)
	_silence_food(split)
	_clear_terrain(split)
	split.critter_count = 0
	split.boss_index = -1
	split._write_critter(Parts.Species.CROW, at, 10)
	split.critter_hp[0] = 900
	split.critter_atk_cd[0] = 99.0
	var c2 := split.swarm.add_clone(0, 10)
	split.swarm.pos[c2] = at
	# The host is left at force 1 so `F` divides the clone and nothing else — one subject per fixture.
	split.swarm.force[0] = 1
	split.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(split.swarm.count, 3, "설정: 그 분신이 실제로 둘로 나뉘었다")
	for i in range(1, split.swarm.count):
		split.swarm.pos[i] = at
		split.swarm.atk_cd[i] = 0.0
	t.eq(split.swarm.force[1] + split.swarm.force[2], 10, "설정: 두 쪽의 힘 합은 그대로 10이다")
	var hp1: int = int(split.critter_hp[0])
	split._contact(0, at)
	t.eq(hp1 - int(split.critter_hp[0]), one_hit,
			"나눈 뒤 두 쪽이 함께 깎는 양은 나누기 전 하나가 깎던 양과 같다 — 분열은 힘을 만들지 않는다")


# -- F4: `V` takes force and cargo, NOT the part ---------------------------------------------------------
## ⚠ **This one has NO writable mutation and that is a property of the design, not a hole in the check.**
## `absorb()` lives on `Swarm`, and `Swarm` holds no `Body` — the folder contract forbids the reference, so
## "route `worn` into `Body.wear()` on absorb" cannot be written as a one-line edit at all. What is asserted
## is the two halves that DO move (force and cargo) plus the one that must never start moving, and it is a
## guard for the day someone gives `Swarm` a way to reach the host's slots. Said out loud rather than
## claimed as a mutation that was tried.
func _f4_absorbing_is_not_wearing(t) -> void:
	var w := World.new()
	w.setup(242)
	_silence_food(w)
	var c := w.swarm.add_clone(0, 6)
	w.swarm.pos[c] = w.swarm.pos[0]
	w.swarm.carried[c] = 12.0
	w.swarm.worn[c] = Parts.HORSE_MANE
	var force_before: int = w.swarm.force[0]
	var banked_before: float = w.swarm.banked
	t.ok(not w.body.is_worn(Parts.HORSE_MANE), "설정: 호스트는 아직 갈기를 걸치지 않았다")
	t.eq(w.swarm.absorb(), 1, "설정: V가 그 분신을 실제로 삼켰다")
	t.eq(w.swarm.force[0], force_before + 6, "삼킨 분신의 힘은 호스트에게 온다")
	t.eq(w.swarm.banked, banked_before + 12.0, "그 화물도 은행에 들어온다")
	t.ok(not w.body.is_worn(Parts.HORSE_MANE),
			"하지만 그 부품은 오지 않는다 — 삼키는 것은 입는 것이 아니고, 호스트의 칸은 카드가 채운다")


# -- F5: a clone FIRES what it wears, and the roll never leaves the crow's rows ---------------------------
## ⚠ **Two halves, because the crow's roll is a uniform pick over THREE parts** and a check that waits for
## one of them by name is a seed lottery. (a) asserts a PROPERTY of what came out over twenty seeds; (b)
## pins the arithmetic with the part written by hand.
func _f5_a_clone_fires_what_it_wears(t) -> void:
	var arcs := 0
	var rolls := 0
	var stray := 0
	for n in 20:
		var w := World.new()
		w.setup(243 + n)
		_silence_food(w)
		_clear_terrain(w)
		w.critter_count = 0
		w.boss_index = -1
		var at := Vector2(600.0, 600.0)
		var c := w.swarm.add_clone(0, 4)
		w.swarm.pos[c] = at
		w.corpse_count = 1
		w.corpse_pos[0] = at
		w.corpse_species[0] = Parts.Species.CROW
		w.corpse_force[0] = 10
		w.corpse_bites_left[0] = w._bites_for(10)
		# §C floors a force-10 crow at three bites regardless of `corpse_progress`, so one call no longer
		# finishes the corpse — loop to completion instead (30 frames, measured).
		w.corpse_progress[0] = 0.999
		var m := 0
		while w.corpse_count > 0 and m < 60:
			w._step_corpses(DT)
			m += 1
		var worn: int = w.swarm.worn[c]
		if worn < 0:
			continue
		rolls += 1
		if worn != Parts.CROW_WING and worn != Parts.CROW_BEAK and worn != Parts.CROW_FOOT:
			stray += 1
		if int(Parts.SHAPE[worn]) == int(Parts.Shape.ARC):
			arcs += 1
	t.ok(rolls > 0, "설정: 스무 판 중 실제로 부품이 나온 판이 있다 (%d)" % rolls)
	t.eq(stray, 0, "까마귀 시체에서 나온 것은 전부 까마귀의 줄이다 — 말 부품은 한 번도 안 나온다")
	t.ok(arcs > 0,
			"그중 적어도 하나는 ARC다 — 접촉 공격의 ARC 갈래가 실제 플레이에서 닿는다 (%d/%d)" % [arcs, rolls])

	# (b) The ARC branch itself, with the part pinned by hand so the arithmetic is a literal.
	var w2 := World.new()
	w2.setup(263)
	_silence_food(w2)
	_clear_terrain(w2)
	var at2 := Vector2(700.0, 700.0)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(Parts.Species.CROW, at2, 10)
	w2.critter_atk_cd[0] = 99.0
	# ⚠ **20px off the crow, not dead centre on it.** A clone standing exactly on its target hands
	# `strike()` a zero-length aim, which is the ONE case that has no cone at all — the swing this check is
	# about would then be measured through the full-circle bug rather than through the wing's 100°.
	var c2 := w2.swarm.add_clone(0, 4)
	w2.swarm.pos[c2] = at2 - Vector2(20.0, 0.0)
	w2.swarm.worn[c2] = Parts.CROW_WING
	w2.swarm.atk_cd[c2] = 0.0
	t.eq(int(Parts.SHAPE[Parts.CROW_WING]), int(Parts.Shape.ARC), "설정: 까마귀 날개는 ARC다")
	w2._contact(0, at2)
	t.eq(int(w2.critter_hp[0]), 26, "걸친 날개로 제 힘 4만큼 휘두른다 (30 → 26)")

	# And the death half: `strike()` returns a HIT COUNT, never "row k died", so a kill through the ARC
	# branch leaves `_contact` reading a stranger's row unless the count is compared.
	var w3 := World.new()
	w3.setup(264)
	_silence_food(w3)
	_clear_terrain(w3)
	w3.critter_count = 0
	w3.boss_index = -1
	w3._write_critter(Parts.Species.CROW, at2, 10)
	w3.critter_atk_cd[0] = 99.0
	# 20px off, for the reason (b) is: dead centre there is no aim and therefore no swing.
	var c3 := w3.swarm.add_clone(0, 30)
	w3.swarm.pos[c3] = at2 - Vector2(20.0, 0.0)
	w3.swarm.worn[c3] = Parts.CROW_WING
	w3.swarm.atk_cd[c3] = 0.0
	t.eq(int(w3.critter_hp[0]), 30, "설정: 그 까마귀는 체력 30이다")
	t.ok(w3._contact(0, at2), "힘 30짜리 분신의 날개 한 번이 죽인다 — 그리고 _contact이 죽었다고 답한다")
	t.eq(w3.critter_count, 0, "생물 표에서 실제로 빠졌다")
	t.eq(w3.corpse_count, 1, "그리고 시체가 남았다")


# -- F6: nothing goes negative, in FOUR places -----------------------------------------------------------
## ⚠ **Negative damage HEALS**, and negative force is genuinely reachable: `F` halves a body's force but not
## the FORCE column of what it wears, so a swap to a smaller part can drive the row under zero.
func _f6_nothing_goes_negative(t) -> void:
	var w := World.new()
	w.setup(270)
	_silence_food(w)
	var c := w.swarm.add_clone(0, 2)
	t.ok(_roll_until(w, c, int(Parts.Species.HORSE), Parts.HORSE_LEGS, 2, 6),
			"설정: 힘 2짜리 분신이 말 다리(힘 5)를 걸쳤다")
	t.eq(int(w.swarm.force[c]), 7, "설정: 그래서 힘 7이 됐다")
	w.swarm.force[0] = 1
	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(int(w.swarm.force[c]), 4, "설정: F가 그 줄을 반으로 갈라 4가 됐다 — 걸친 부품의 5는 안 줄었다")
	t.eq(w.swarm.worn[c], Parts.HORSE_LEGS, "설정: 부품은 부모 쪽에 남아 있다")
	# 까마귀 발 (FORCE 2), not 말 폐활량: the only FORCE-0 droppable left both pools, so the reachable case
	# is a SMALLER part rather than a free one.
	t.ok(_roll_until_keeping(w, c, int(Parts.Species.CROW), Parts.CROW_FOOT),
			"설정: 그 다음 까마귀 시체에서 까마귀 발(힘 2)이 나왔다")
	t.eq(int(w.swarm.force[c]), 2,
			"4 − 5는 0에서 멈추고 거기에 2가 더해진다 — 힘은 음수가 되지 않는다 (리터럴 2, 안 막으면 1)")

	# The other two `maxi(0, amount)` pairs. Negative damage on either side heals, and healing is invisible
	# to every check that only ever passes a positive number.
	var w2 := World.new()
	w2.setup(271)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(Parts.Species.CROW, Vector2(100.0, 100.0), 10)
	t.ok(not w2._damage_critter(0, -5), "설정: 음수 피해로는 생물이 죽지 않는다")
	t.eq(int(w2.critter_hp[0]), 30, "음수 피해는 생물의 체력을 올리지 않는다")
	var sw := Swarm.new()
	sw.setup(272, Vector2(500.0, 500.0))
	var k := sw.add_clone(0, 10)
	t.ok(not sw.damage(k, -5), "설정: 음수 피해로는 분신도 죽지 않는다")
	t.eq(int(sw.hp[k]), 30, "그리고 분신의 체력도 올라가지 않는다")

	# The FOURTH place, and the only one on the HOST: `Body.wear()`'s digestion loop. The clone's identical
	# path is `World::_roll_part`, which carries the floor and is pinned above; the host's had neither. The
	# host reaches it from a level-up card, which cannot be declined, so a negative here is permanent.
	#
	# ⚠ **까마귀 발 and 말 다리 share `Slot.HINDLIMBS`** — the one square two parts share. That displacement
	# is the whole of 결정 5, and it is also the only path in the game that digests a part off the host.
	var w4 := World.new()
	w4.setup(273)
	_silence_food(w4)
	_clear_terrain(w4)
	t.eq(int(w4.swarm.force[0]), 10, "설정: 호스트는 힘 10으로 연다")
	w4.body.wear(Parts.HORSE_LEGS)
	t.eq(int(w4.swarm.force[0]), 15, "설정: 말 다리(힘 5)를 입어 10 → 15")
	# Four `F` holds take 15 down to 1. Written straight in: the split itself is pinned by F2..F6 above and
	# re-driving it here would measure the halving rather than the floor.
	w4.swarm.force[0] = 1
	var digested: Array = w4.body.wear(Parts.CROW_FOOT)
	t.eq(digested.size(), 1, "설정: 까마귀 발이 같은 칸의 말 다리를 소화시켰다")
	t.eq(int(w4.swarm.force[0]), 2,
			"1 − 5는 0에서 멈추고 거기에 2가 더해진다 — 호스트의 힘도 음수가 되지 않는다 (리터럴 2, 안 막으면 -2)")
	t.eq(w4.swarm.total_force(), 2, "무리의 힘도 2다 — 몸 패널이 음수를 읽지 않는다")

	# And the consequence, driven rather than reasoned: `strike()` hands `swarm.force[0]` to
	# `_damage_critter`, whose own `maxi(0, amount)` turns a negative into a **zero**. Without the floor the
	# host's bite does nothing at all, for the rest of the run, and every arithmetic check above stays green.
	w4.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w4.critter_count = 0
	w4.boss_index = -1
	w4._write_critter(Parts.Species.CROW, Vector2(1040.0, 1000.0), 10)
	t.eq(int(w4.critter_hp[0]), 30, "설정: 40px 앞의 까마귀는 체력 30이다")
	t.eq(w4.body.bound[0], Parts.BITE, "설정: 왼쪽 클릭은 아직 물기다")
	t.ok(w4.fire(0, Vector2(1100.0, 1000.0)), "설정: 물기가 나갔다")
	t.eq(int(w4.critter_hp[0]), 28, "그 물기는 2만큼 깎는다 — 힘이 음수면 0이 되어 아무 일도 안 난다 (30 → 28)")


# -- F7: hp is CONSERVED across `F`, never recomputed ----------------------------------------------------
## ⚠ **The undamaged case alone cannot see the mutation.** A body at hp 30 splits into 15 + 15 under both
## implementations; a body written down to 7 splits into 3 + 4 under conservation and into 15 + 15 under a
## recompute, and the recompute is `F` as a heal button.
func _f7_hp_is_conserved_across_the_split(t) -> void:
	var sw := Swarm.new()
	sw.setup(280, Vector2(1000.0, 1000.0))
	var c := sw.add_clone(0, 10)
	sw.hp[c] = 7
	# The host is left under 2 so `F` divides the clone and nothing else.
	sw.force[0] = 1
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 3, "설정: 다친 분신이 실제로 둘로 나뉘었다")
	t.eq(int(sw.hp[c]), 4, "부모는 나머지 4를 갖는다")
	t.eq(int(sw.hp[2]), 3, "아이는 바닥 쪽 절반 3을 갖는다")
	t.eq(int(sw.hp[c]) + int(sw.hp[2]), 7,
			"둘의 합은 나누기 전의 7 그대로다 — F는 회복 버튼이 아니다")

	var sw2 := Swarm.new()
	sw2.setup(281, Vector2(1000.0, 1000.0))
	var d := sw2.add_clone(0, 10)
	sw2.force[0] = 1
	sw2.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(int(sw2.hp[d]), 15, "대조: 안 다친 몸은 15와")
	t.eq(int(sw2.hp[2]), 15, "15로 갈린다 — 이쪽만으로는 위의 변이를 볼 수 없다")


# -- F8: a body that cannot be halved is not halved ------------------------------------------------------
## Without the refusal a body at 1 hp splits into a 1-hp child and a **0-hp parent that is alive**: hp only
## kills at the moment damage is applied, so a zombie never dies of its own accord.
func _f8_a_body_at_one_hp_does_not_split(t) -> void:
	var sw := Swarm.new()
	sw.setup(282, Vector2(1000.0, 1000.0))
	var c := sw.add_clone(0, 10)
	sw.hp[c] = 1
	sw.force[0] = 1
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 2, "체력 1짜리 몸은 나뉘지 않는다 — 반으로 갈라 아무것도 안 남는 것은 가르지 않는다")
	t.eq(int(sw.force[c]), 10, "그 힘도 건드려지지 않는다")
	t.eq(int(sw.hp[c]), 1, "그 체력도 그대로다")

	var sw2 := Swarm.new()
	sw2.setup(283, Vector2(1000.0, 1000.0))
	var d := sw2.add_clone(0, 10)
	sw2.hp[d] = 2
	sw2.force[0] = 1
	sw2.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw2.count, 3, "대조: 체력 2면 나뉜다 — 아무것도 못 나누는 검사가 아니다")
	t.eq(int(sw2.hp[d]) + int(sw2.hp[2]), 2, "그리고 그 2도 보존된다")

	# ⚠ **The host must still split at hp -1.** Row 0 carries the sentinel, so a refusal written without its
	# `i > 0` guard reads `-1 < 2` and deletes the tutorial keystroke outright.
	var sw3 := Swarm.new()
	sw3.setup(284, Vector2(1000.0, 1000.0))
	t.eq(int(sw3.hp[0]), -1, "설정: 호스트의 체력 칸은 -1 표식이다")
	sw3.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw3.count, 2, "호스트는 그 표식에도 불구하고 나뉜다 — 첫 키가 사라지지 않는다")


# -- F9: the two maintenance points nothing else reaches -------------------------------------------------
func _f9_the_hp_column_is_maintained(t) -> void:
	var sw := Swarm.new()
	sw.setup(285, Vector2(1000.0, 1000.0))
	var a := sw.add_clone(0, 4)
	var b := sw.add_clone(0, 10)
	var c := sw.add_clone(0, 30)
	t.eq(int(sw.hp[a]), 12, "설정: 체력 12 · 30 · 90짜리 분신 셋을 세웠다")
	t.eq(int(sw.hp[b]), 30, "설정: 가운데는 30이다")
	t.eq(int(sw.hp[c]), 90, "설정: 마지막은 90이다")
	sw.remove_at(b)
	t.eq(int(sw.hp[1]), 12, "건드리지 않은 줄의 체력은 그대로다")
	t.eq(int(sw.hp[2]), 90, "내려온 줄은 제 체력을 들고 왔다 — 죽은 놈의 것을 물려받지 않는다")

	# ⚠ **`add_clone()` with no arguments** is what every steering net in the round calls. Without the floor
	# each of those builds bodies at 0 hp: alive, drawn, and dead to the first touch, with nothing red.
	var sw2 := Swarm.new()
	sw2.setup(286, Vector2(1000.0, 1000.0))
	var d := sw2.add_clone()
	t.eq(int(sw2.force[d]), 0, "설정: 인자 없는 add_clone()은 힘 0짜리 몸을 만든다")
	t.eq(int(sw2.hp[d]), Rules.BODY_HP_MIN, "그래도 체력은 바닥값 아래로 내려가지 않는다")
	t.eq(Rules.BODY_HP_MIN, 1, "그 바닥값은 1이다 (리터럴)")


# -- F10: hp moves with the part exactly as force does ---------------------------------------------------
func _f10_hp_moves_with_the_part(t) -> void:
	var w := World.new()
	w.setup(287)
	_silence_food(w)
	var c := w.swarm.add_clone(0, 4)
	t.eq(int(Parts.FORCE[Parts.CROW_FOOT]), 2, "설정: 까마귀 발은 힘 2에")
	t.eq(int(Parts.HP[Parts.CROW_FOOT]), 3, "설정: 체력 3짜리 부품이다 (리터럴)")
	t.ok(_roll_until(w, c, int(Parts.Species.CROW), Parts.CROW_FOOT, 4, 12),
			"설정: 까마귀 시체에서 까마귀 발이 나왔다")
	t.eq(int(w.swarm.force[c]), 6, "걸친 만큼 힘이 오른다 (4 + 2)")
	t.eq(int(w.swarm.hp[c]), 15, "그리고 체력도 오른다 (12 + 3) — HP 열이 분신에게도 실제로 쓰인다")

	t.eq(int(Parts.HP[Parts.HORSE_LEGS]), 0, "설정: 말 다리는 체력을 주지 않는다 (리터럴 0)")
	t.ok(_roll_until_keeping(w, c, int(Parts.Species.HORSE), Parts.HORSE_LEGS),
			"설정: 다음 시체에서 말 다리로 갈아탔다")
	t.eq(int(w.swarm.force[c]), 9, "발의 2를 먼저 빼고 다리의 5를 더한다 (6 − 2 + 5)")
	t.eq(int(w.swarm.hp[c]), 12, "체력도 발의 3을 먼저 뺀다 (15 − 3 + 0) — 유령 체력은 남지 않는다")


# -- F11: `damage()` writes the hit clock, the direction, and knocks the body back through `place()` -------
## ⚠ **`hp` alone cannot see any of the three.** A `damage()` that only ever subtracted hp would leave this
## file's other checks untouched and this column silently dead — the shape `_c15_c16_death` already names
## for `force`.
func _f11_damage_writes_the_hit_and_knocks_back(t) -> void:
	var w := World.new()
	w.setup(290)
	_silence_food(w)
	_clear_terrain(w)
	var c := w.swarm.add_clone(0, 20)
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	t.eq(w.swarm.hit_show[c], INF, "설정: 아직 안 맞은 분신은 INF다")
	var before: Vector2 = w.swarm.pos[c]
	var died := w.swarm.damage(c, 10, Vector2(0.0, 1.0))
	t.ok(not died, "설정: 체력 60짜리가 10을 맞아도 죽지는 않는다")
	t.eq(w.swarm.hit_show[c], 0.0, "맞은 순간 시계가 0으로 열린다")
	t.eq(w.swarm.hit_dir[c], Vector2(0.0, 1.0), "맞은 방향도 그대로 남는다")
	var moved: float = w.swarm.pos[c].distance_to(before)
	t.ok(absf(moved - 10.0 * Rules.KNOCKBACK_PER_FORCE) < 0.01,
			"그리고 그 힘 × KNOCKBACK_PER_FORCE만큼 밀린다 (%.2f, 기대 %.2f)"
					% [moved, 10.0 * Rules.KNOCKBACK_PER_FORCE])

	# push_out survival: a rock sits directly in the knockback's path.
	var w2 := World.new()
	w2.setup(291)
	_silence_food(w2)
	_clear_terrain(w2)
	var c2 := w2.swarm.add_clone(0, 20)
	var at := Vector2(1000.0, 1000.0)
	w2.swarm.pos[c2] = at
	var rock_r := 30.0
	w2.terrain.rock_pos.append(at + Vector2(8.0 + rock_r * 0.5, 0.0))
	w2.terrain.rock_radius.append(rock_r)
	t.ok(w2.terrain.push_out(at + Vector2(8.0, 0.0), Rules.CLONE_BODY_RADIUS) != at + Vector2(8.0, 0.0),
			"설정: 바위를 실제로 그 밀리는 자리에 놓았다")
	w2.swarm.damage(c2, 10, Vector2(1.0, 0.0))
	var final_pos: Vector2 = w2.swarm.pos[c2]
	t.ok(final_pos.distance_to(w2.terrain.rock_pos[0]) >= rock_r - 0.01,
			"밀린 분신도 바위 밖에 선다 — place()를 거치지 않으면 바위 속으로 순간이동한다 (%.2f, 반지름 %.2f)"
					% [final_pos.distance_to(w2.terrain.rock_pos[0]), rock_r])

	# 죽는 순간에도 순서가 맞다: `hit_show`/`hit_dir`는 `remove_at()`이 남의 것을 이 줄에 옮겨 쓰기 전에
	# 이미 쓰여 있어야 한다 — `_damage_critter`와 같은 함정이다.
	var w3 := World.new()
	w3.setup(292)
	_silence_food(w3)
	_clear_terrain(w3)
	var weak := w3.swarm.add_clone(0, 2)
	var strong := w3.swarm.add_clone(0, 20)
	# 구분되는 값 — `INF`는 두 줄 다 이미 들고 있어서 스왑이 빠져도 같아 보인다.
	w3.swarm.hit_show[strong] = 7.0
	w3.swarm.hit_dir[strong] = Vector2(0.0, -1.0)
	# §B-3: `died_this_frame`도 같은 함정이다 — `pos`/`carried`를 죽는 바로 그 줄에서, `remove_at()`이 옮겨
	# 쓰기 전에 읽어야 한다. 구분되는 화물을 손으로 실어 둔다.
	w3.swarm.carried[weak] = 4.5
	var weak_pos: Vector2 = w3.swarm.pos[weak]
	t.eq(w3.swarm.died_this_frame.size(), 0, "설정: 아직 아무도 죽지 않았다")
	t.eq(w3.swarm.count, 3, "설정: 약한 분신과 강한 분신을 세웠다")
	t.ok(w3.swarm.damage(weak, 999, Vector2(1.0, 0.0)), "약한 분신이 죽는다 — swap branch가 이 죽음으로 열린다")
	t.eq(w3.swarm.count, 2, "설정: 실제로 하나가 사라졌다")
	t.eq(w3.swarm.hit_show[weak], 7.0, "죽은 자리에는 마지막 줄의 피격 시계가 내려왔다")
	t.eq(w3.swarm.hit_dir[weak], Vector2(0.0, -1.0), "피격 방향도 마지막 줄의 것이 내려왔다")
	t.eq(w3.swarm.died_this_frame.size(), 1, "그리고 died_this_frame에 죽음이 하나 기록된다")
	if w3.swarm.died_this_frame.size() == 1:
		var d: Dictionary = w3.swarm.died_this_frame[0]
		# 밀림이 먼저 자리를 옮긴 뒤 죽는다 — 기록된 자리는 죽기 직전(맞기 전)이 아니라 밀린 뒤, 죽는 바로 그
		# 줄의 최종 자리다. `(1.0, 0.0)` 방향으로 999 × KNOCKBACK_PER_FORCE만큼 밀린 지점.
		var expect_pos := weak_pos + Vector2(1.0, 0.0) * (999.0 * Rules.KNOCKBACK_PER_FORCE)
		t.eq(d["pos"], expect_pos,
				"기록된 자리는 밀려서 죽은 바로 그 자리다 — 살아남은 줄의 자리가 아니다 (%s)" % str(expect_pos))
		t.eq(d["carried"], 4.5, "실려 있던 화물도 죽기 직전의 제 값이다 (%.1f)" % float(d["carried"]))
	# `begin_frame()`이 비운다 — `step()`의 맨 앞이 아니다. 이유는 `Swarm.begin_frame()`에 적혀 있다.
	w3.swarm.step(1.0 / 60.0)
	t.eq(w3.swarm.died_this_frame.size(), 1, "step()은 이 목록을 비우지 않는다")
	w3.swarm.begin_frame()
	t.eq(w3.swarm.died_this_frame.size(), 0, "프레임이 새로 시작하면(begin_frame) 목록은 비어 있다")


## Roll `species`' corpse pool onto `eater` until `want` comes out, resetting the row to its base before
## every attempt. **The crow's pool is three parts and the roll is uniform**, so a check that named a part
## and stepped once would be a lottery; this leaves exactly one successful roll applied to a known base.
func _roll_until(w: World, eater: int, species: int, want: int, base_force: int, base_hp: int) -> bool:
	for _n in 400:
		w.swarm.worn[eater] = -1
		w.swarm.force[eater] = base_force
		w.swarm.hp[eater] = base_hp
		w._roll_part(eater, species)
		if w.swarm.worn[eater] == want:
			return true
	return false


## The same, for a SECOND part: the row is left exactly as it is between attempts, so the subtract-then-add
## the check is about really runs off whatever the body is already wearing.
func _roll_until_keeping(w: World, eater: int, species: int, want: int) -> bool:
	var had: int = w.swarm.worn[eater]
	var force_was: int = w.swarm.force[eater]
	var hp_was: int = w.swarm.hp[eater]
	for _n in 400:
		w.swarm.worn[eater] = had
		w.swarm.force[eater] = force_was
		w.swarm.hp[eater] = hp_was
		w._roll_part(eater, species)
		if w.swarm.worn[eater] == want:
			return true
	return false


# -- F12: `World.level_show` is a sim-owned up-counting clock, the same shape `bite_show` already uses -----
func _f12_level_fires_a_display_clock(t) -> void:
	var w := World.new()
	w.setup(293)
	_silence_food(w)
	w.critter_count = 0
	w.boss_index = -1
	t.eq(w.level_show, INF, "설정: 아직 레벨업이 없었다 — 표시 시계는 INF로 연다")

	w.swarm.banked = w.level_cost(0) + 1.0
	w.step(DT)
	t.eq(w.level, 1, "설정: 실제로 레벨이 하나 올랐다")
	t.ok(w.species_eaten.is_empty(),
			"설정: 카드 풀이 아직 안 열려 있다 — offer가 안 차야 step()이 다음 걸음에서도 진행한다")
	t.eq(w.level_show, 0.0, "레벨이 오른 바로 그 프레임엔 0으로 열린다")

	w.step(DT)
	t.ok(absf(w.level_show - DT) < 0.0001, "다음 프레임엔 dt만큼 올라간다 (%.4f)" % w.level_show)

	# ⚠ **And it keeps counting while the CARDS are up, which is the only level that ever shows cards.**
	# `_grow()` writes `level_show = 0.0` and rolls the offer in the same call, and `World.step()` returns
	# early while an offer is on screen — so this clock froze at 0.0 for as long as the player deliberated.
	# `field_view` reads it as `1 - level_show / LEVEL_POP_TIME`, `hud` as two `<` windows: the host sat at
	# full `LEVEL_POP_STRENGTH`, fully tinted, with the bar white and the phrase up, until a card was picked.
	# A pop that does not pass is a state. It is the one line above the guard for exactly this reason.
	var wc := World.new()
	wc.setup(295)
	_silence_food(wc)
	wc.critter_count = 0
	wc.boss_index = -1
	# The pool has to be open, or the offer stays empty and the guard this is about never engages.
	wc.species_eaten.append(int(Parts.Species.CROW))
	wc.swarm.banked = wc.level_cost(0) + 1.0
	wc.step(DT)
	t.eq(wc.level_show, 0.0, "설정: 레벨이 올라 표시 시계가 0으로 열렸다")
	t.ok(wc.pending_levels > 0 and not wc.offer.is_empty(),
			"설정: 그 레벨이 실제로 카드를 띄웠다 — step()이 여기서부터 일찍 돌아간다")
	var frozen := wc.elapsed
	for _f in 10:
		wc.step(DT)
	t.eq(wc.elapsed, frozen, "설정: 카드가 떠 있는 동안 세상은 실제로 멈춰 있다 — elapsed는 안 움직인다")
	t.ok(absf(wc.level_show - DT * 10.0) < 0.0001,
			"그래도 레벨 팝의 시계는 흘러간다 — 카드를 고르는 내내 몸이 부풀어 있지 않는다 (%.4f)"
					% wc.level_show)
	t.ok(wc.level_show > Look.LEVEL_POP_TIME * 0.0,
			"설정: 그 시계는 0보다 크다 — 얼어 있으면 팝은 최대 세기에 고정된다")


# -- F13: `F`'s two halves shove apart, through the exact §A-3 formula ------------------------------------
func _f13_split_shove_matches_the_formula(t) -> void:
	var sw := Swarm.new()
	sw.setup(294, Vector2(1000.0, 1000.0))
	sw.force[0] = 1   ## the host cannot split — isolate the one clone's split
	var c := sw.add_clone(0, 20)
	var parent_pos_before: Vector2 = sw.pos[c]
	t.eq(sw.split_this_frame.size(), 0, "설정: 아직 아무도 갈라지지 않았다")

	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 3, "설정: 그 분신 하나만 갈라졌다")
	var child := 2
	t.eq(sw.force[c], 10, "설정: 짝수라 부모도 반")
	t.eq(sw.force[child], 10, "설정: 아이도 반")

	# §F-10: 두 몸은 그 자리에서 서로 반대로 한 번 더 밀린다 — `CLONE_SPAWN_RING` 위에
	# `2 × (아이의 힘 × KNOCKBACK_PER_FORCE)`가 더 벌어진다 (부모가 뒤로, 아이가 앞으로, 같은 축을 따라).
	var sep := sw.pos[child].distance_to(sw.pos[c])
	var expect_sep := Rules.CLONE_SPAWN_RING + 2.0 * 10.0 * Rules.KNOCKBACK_PER_FORCE
	t.ok(absf(sep - expect_sep) < 0.5,
			"갈라진 두 몸의 간격은 CLONE_SPAWN_RING + 2×(아이의 힘×KNOCKBACK_PER_FORCE)다 (%.2f, 기대 %.2f)"
					% [sep, expect_sep])
	t.ok(sw.pos[c].distance_to(parent_pos_before) > 0.5, "부모도 밀려서 원래 자리에 그대로 남지 않는다")

	t.eq(sw.split_this_frame.size(), 1, "갈라진 자리가 목록에 하나 남는다")
	if sw.split_this_frame.size() == 1:
		t.eq(sw.split_this_frame[0]["pos"], parent_pos_before,
				"기록된 자리는 갈라지기 전, 부모의 원래 자리다 — 밀린 뒤 자리가 아니다")

	# ⚠ **`begin_frame()` clears it, and `step()` explicitly does NOT** (§0-2 still holds: `view` never does).
	# `F` is a KEY — the shell fills this list from `split_hold()` in its input phase, BEFORE `step()` — so a
	# clear at `step()`'s top erased the ring on the very frame it was written, every time, in the real game.
	# This check drove `split_hold()` and read the list back with no `step()` between, which is exactly why it
	# was green through all of it; the frame the shell actually runs is asserted in `net_shell`.
	sw.step(0.0, null)
	t.eq(sw.split_this_frame.size(), 1, "step()은 이 목록을 비우지 않는다 — 비우면 F 링이 그 프레임에 사라진다")
	sw.begin_frame()
	t.eq(sw.split_this_frame.size(), 0, "프레임이 새로 시작하면(begin_frame) 비워진다")


# -- F14: the shove goes through `place()`, the same funnel §A-3's knockback uses --------------------------
## A rock centred exactly where the clone stood, big enough to swallow BOTH halves however the split's
## random axis lands — worst-case travel from that point is `CLONE_SPAWN_RING + 2×(10×KNOCKBACK_PER_FORCE)`
## ≈ 36px either side, so a 90px rock guarantees interference regardless of direction. This is what forces
## the PARENT's shoved position specifically through `push_out`: it starts the split already AT the rock's
## centre and is shoved only a few px from there, deep inside a 90px rock, unless `place()` actually runs.
func _f14_split_shove_survives_a_rock(t) -> void:
	var w := World.new()
	w.setup(295)
	_silence_food(w)
	_clear_terrain(w)
	w.critter_count = 0
	w.boss_index = -1
	w.swarm.force[0] = 1
	var c := w.swarm.add_clone(0, 20)
	var origin: Vector2 = w.swarm.pos[c]
	var rock_r := 90.0
	w.terrain.rock_pos.append(origin)
	w.terrain.rock_radius.append(rock_r)

	w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(w.swarm.count, 3, "설정: 실제로 갈라졌다")
	var child := 2
	t.ok(w.swarm.pos[c].distance_to(origin) >= rock_r - 0.01,
			"밀린 부모도 바위 밖에 선다 — place()를 거치지 않으면 바위 속으로 순간이동한다 (%.2f, 반지름 %.2f)"
					% [w.swarm.pos[c].distance_to(origin), rock_r])
	t.ok(w.swarm.pos[child].distance_to(origin) >= rock_r - 0.01,
			"밀린 아이도 바위 밖에 선다 (%.2f, 반지름 %.2f)"
					% [w.swarm.pos[child].distance_to(origin), rock_r])


# -- U16b: the peak swarm is a HIGH-WATER MARK -----------------------------------------------------------
## `maxi(peak_swarm, ...)` → a plain assignment is green, because `net_run`'s check reads `peak_before24`
## **off the world under test** — a bound taken from the thing it is checking, CLAUDE.md's named trap. The
## ending screen then reports the swarm size at death, which is usually near zero: the run's one number for
## how big you ever got, replaced by how small you were when it ended.
func _u16b_the_peak_is_a_high_water_mark(t) -> void:
	var w := World.new()
	w.setup(470)
	_silence_food(w)
	_clear_terrain(w)
	# §F-10 gives the swarm 90 extra steps to rally before `V` (below) — long enough for a real critter to
	# reach and touch a clone by chance, which this check is not about. Removed the same way the ground is.
	w.critter_count = 0
	w.boss_index = -1
	t.eq(w.peak_swarm, 0, "설정: 최대 무리는 0에서 시작한다")

	# Force 10 → three full holds is 8 bodies, so 7 clones. Every one lands on the spawn ring inside `V`'s
	# reach (`ABSORB_RADIUS_BODIES` 4 × `BODY_RADIUS` 14 = 56 > `CLONE_SPAWN_RING` 20).
	for _h in 3:
		w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
		w.swarm.split_release()
	t.eq(w.swarm.count, 8, "설정: 세 번 나눠서 몸이 여덟이 됐다")
	w.step(DT)
	t.eq(w.peak_swarm, 7, "그 순간의 최대 무리는 분신 일곱이다")

	# §F-10: 세 번 겹쳐 갈라지면 §F-10의 밀림도 세 번 겹친다 — 몇 마리는 `CLONE_SPAWN_RING` 하나만으로는
	# 닿지 않는 56px 밖으로 밀릴 수 있다. FOLLOW 상태는 그 틈을 저절로 좁힌다(모두 호스트를 향해 걷는다) —
	# 플레이어가 `V`를 누르기 전에 실제로 갖는 그 한 박자를, 여기서도 준다.
	for _s in 90:
		w.step(DT)

	# Every clone home again. The LIVE count falls back to zero and the peak must not follow it.
	var taken := w.swarm.absorb()
	t.eq(taken, 7, "설정: V 한 번에 일곱을 다 거뒀다")
	t.eq(w.swarm.count, 1, "설정: 몸은 다시 호스트 하나다")
	w.step(DT)
	t.eq(w.peak_swarm, 7,
			"그래도 최대 무리는 일곱으로 남는다 — 그냥 대입이면 여기서 0이 되고 엔딩은 죽을 때의 크기를 적는다")

	# And it still RISES. A high-water mark that froze at its first value is the other half of the same bug.
	for _h in 4:
		w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
		w.swarm.split_release()
	w.step(DT)
	t.ok(w.peak_swarm > 7, "그리고 더 커지면 따라 올라간다 — 얼어붙은 것이 아니다 (%d)" % w.peak_swarm)


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks now sit between the host and wherever a fixture writes a coordinate, and `push_out` moves a
## hand-placed body or creature off it by up to a rock's radius. **A check that is not about the ground has
## to remove the ground**, or its two fixtures drift apart by seed and the failure reads as a contact bug.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()


## One creature row, every column written by hand. **`critter_force` is pinned rather than rolled**: a crow
## spawns anywhere in 8–12, so a check reading damage off it would pass or fail by seed.
func _crow_row(w: World, k: int, force_value: int) -> void:
	w.critter_species[k] = Parts.Species.CROW
	w.critter_force[k] = force_value
	w.critter_hp[k] = force_value * Rules.HP_PER_FORCE
	w.critter_flees[k] = 0
	w.critter_atk_cd[k] = 0.0
	w.critter_counter[k] = 0.0
