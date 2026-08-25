extends RefCounted
## What one island's fight actually does, measured **through `battle.step(dt)`** and never by calling a
## helper on its own.
##
## Every check below builds a `Battle`, drives it with `step`, and reads the public columns afterwards.
## Calling `grid.step_toward` or `_within` directly would prove a pure function correct and prove nothing
## about whether `step` ever reaches it — that hole is why `net_grid` was folded into this net in the
## first slice plan, and it is the same shape that once shipped a notice painting at zero size under a
## green round.
##
## **The grids here are hand-built, not the three real islands.** A fixture that moves when someone edits
## an island measures the island; `net_islands` owns the real grids and this net owns the rules.
##
## ⚠ **`step` runs whole `Rules.SIM_SUBSTEP_SEC` sub-steps and carries the leftover** (`plan-then-watch`,
## 5.2), so there is no longer any such thing as a step too small to do anything: `step(1e-5)` runs ZERO
## phases and every column stays at its fixture value, which reads as "the rule did not fire" on every
## check in this file at once. That is exactly what the old `TICK_ONE` became the day sub-stepping
## landed. ⇒ **One sub-step is the smallest thing that happens**, and it is what every "measure the
## blow at the distance the fixture wrote" row is driven with now.
##
## A unit already inside its reach does not walk (`_phase_movement` returns before `_walk` for it), so
## one sub-step still leaves those fixtures standing exactly where they were written — which is the
## property those rows actually needed. A unit OUTSIDE its reach closes `speed / 60` of a tile, and no
## row in this file is bounded tightly enough for that to matter.
##
## A real 0.1 s frame (six sub-steps) is used wherever the thing being measured IS movement.


## One whole sub-step — the smallest amount of simulated time that exists. See the header.
const TICK_ONE := Rules.SIM_SUBSTEP_SEC

const ARENA_W := 24
const ARENA_H := 12
const LANE_W := 24
const LANE_H := 5
const CORR_W := 12
const CORR_H := 9


func run(t) -> void:
	_setup_barks_on_empty_grid(t)
	_no_two_units_share_a_tile(t)
	_nearest_first(t)
	_reach_is_range_plus_bonus(t)
	_epsilon_edge(t)
	_area_splash(t)
	_no_friendly_fire(t)
	_stops_when_target_is_in_range(t)
	_death_is_permanent(t)
	_phase_order(t)
	_in_transit_is_hit_but_cannot_hit(t)
	_reserves_do_not_hold_the_run_open(t)
	_a_soldier_at_sea_does_hold_it_open(t)
	_the_gate_itself(t)
	_wiped_wins_when_both_are_true(t)
	# -- ticket 11: the status table reaches the fight ---------------------------------------------
	_bleed_drips_after_the_blow(t)
	_bleed_off_below_threshold(t)
	_bleed_refreshes_and_never_stacks(t)
	_bleed_death_passes_the_same_substep(t)
	_status_rides_the_splash(t)
	_slow_makes_the_hit_enemy_walk_less(t)
	_slow_expires_back_to_full_speed(t)
	_slow_refreshes_and_never_stacks(t)
	_enemy_blows_carry_no_status(t)
	# -- 티켓 15: the five passives ------------------------------------------------------------------
	_the_bear_sweeps(t)
	_the_squirrel_pulls_and_the_cow_charges(t)
	_the_crow_bleeds_with_no_equipment(t)
	_the_wolves_hunt_as_one(t)
	_a_crows_own_bleed_never_weakens_its_equipment(t)
	_a_blocked_shove_does_not_spend_the_charge(t)
	_the_shove_moves_the_goal_and_the_reservation(t)


# -- 티켓 15 fix: two sources, one blow, the STRONGER stands -------------------------------------------
## ⚠⚠ **MEASURED AS A REAL DEFECT, not a worry.** 까마귀 has a bleed row of its own AND reads the
## horde's bleed tag count like every other species. Written as two writes in a row the species value
## landed last, so a full bleed set (tier 2, 1.5 a second for 3 s) reached a crow's target as
## **0.5 / 2.0** — 22% of what the same set gives a wolf. **Equipment fitted anywhere on the board
## penalised the crow specifically**, since `tag_count` sums every board.
##
## ⚠ **Five copies, because tier 2's threshold is five.** Nothing else in this file drives more than
## three, which is why nothing caught it.
##
## ⚠ Mutation: write the species tier after the tag tier instead of resolving them; compare two DOT
## tiers with `<` instead of `>`.
func _a_crows_own_bleed_never_weakens_its_equipment(t) -> void:
	var lit := Rules.tag_status_tier_at(_bleed_row(), 5)
	t.ok(not lit.is_empty(), "출혈 딱지 다섯이면 2층이 켜진다 (자가 점검)")
	t.eq(float(lit["mag"]), 1.5, "그 2층의 세기가 초당 1.5 다 (리터럴)")
	t.eq(float(lit["sec"]), 3.0, "지속은 3초다 (리터럴)")
	var own := Rules.species_status_of(Rules.CROW)
	t.ok(float(own["mag"]) < float(lit["mag"]),
		"까마귀 제 종의 출혈은 그 2층보다 약하다 (자가 점검 — 이게 뒤집히면 아래가 공허하다)")

	# The crow, wearing the same five a wolf would wear.
	var crow_army := _army_of([Rules.CROW])
	_worn(crow_army, ITEM_BLEED, 5, Rules.COW)
	var cb := _battle_of(_open(ARENA_W, ARENA_H), crow_army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(cb, 0, Vector2(9, 5))
	cb.begin_frame()
	cb.step(TICK_ONE)
	t.ok(cb.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "까마귀가 실제로 때렸다 (자가 점검)")
	t.eq(cb.status_mag_of(Rules.Status.BLEED, 0), float(lit["mag"]),
		"까마귀가 문 적의 출혈 세기가 장비 2층 그대로다 — 제 종 줄이 장비를 덮어쓰지 않는다")
	# ⚠ One sub-step of ageing is already off it: `_phase_status` runs after `_phase_attacks` inside
	# the same sub-step. The species row's own 2.0 would read 1.983 here, so this still separates them.
	# ⚠ Compared with a tolerance, not with `eq`: `status_time` is a `PackedFloat32Array` and the
	# 32-bit round trip puts the value a few 1e-8 off the 64-bit expectation.
	t.ok(absf(cb.status_left(Rules.Status.BLEED, 0)
			- (float(lit["sec"]) - Rules.SIM_SUBSTEP_SEC)) < 1e-4,
		"지속도 2층 그대로다 — 세기만 살리고 시간을 깎지도 않는다 (%.4f)"
			% cb.status_left(Rules.Status.BLEED, 0))

	# The CONTROL: a wolf wearing the identical five reads the identical numbers.
	var wolf_army := _army_of([Rules.WOLF])
	_worn(wolf_army, ITEM_BLEED, 5, Rules.COW)
	var wb := _battle_of(_open(ARENA_W, ARENA_H), wolf_army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(wb, 0, Vector2(11, 5))
	wb.begin_frame()
	wb.step(TICK_ONE)
	t.eq(wb.status_mag_of(Rules.Status.BLEED, 0), cb.status_mag_of(Rules.Status.BLEED, 0),
		"같은 다섯을 낀 늑대와 까마귀가 정확히 같은 세기로 물린다 — 종이 벌을 안 받는다")

	# The other direction: with NO equipment the species row is the only source and stands on its own.
	var bare := _army_of([Rules.CROW])
	var bb := _battle_of(_open(ARENA_W, ARENA_H), bare,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(bb, 0, Vector2(9, 5))
	bb.begin_frame()
	bb.step(TICK_ONE)
	t.eq(bb.status_mag_of(Rules.Status.BLEED, 0), float(own["mag"]),
		"딱지가 하나도 없으면 제 종의 세기가 그대로 선다 — 강한 쪽을 고르는 것이지 장비만 보는 게 아니다")

	# ⚠ And the SLOW kind is compared the other way round: a smaller multiplier is the stronger one.
	var slow_a := {"mag": 0.5, "sec": 2.0}
	var slow_b := {"mag": 0.7, "sec": 2.0}
	t.eq(float(Rules.stronger_status_tier(Rules.Status.SLOW, slow_a, slow_b)["mag"]), 0.5,
		"감속은 배율이 작은 쪽이 강하다 — DOT 과 반대로 읽는다")
	t.eq(float(Rules.stronger_status_tier(Rules.Status.BLEED, slow_a, slow_b)["mag"]), 0.7,
		"출혈은 큰 쪽이 강하다 — 같은 두 값을 종류에 따라 반대로 고른다 (계기 자가 점검)")


## The `TAG_STATUS_TIERS` row that carries 출혈, found rather than written as an index.
func _bleed_row() -> int:
	for r in Rules.tag_status_row_count():
		if Rules.tag_status_status_of(r) == Rules.Status.BLEED:
			return r
	return -1


# -- 티켓 15 fix: a charge is spent by the MOVE, not by the attempt ------------------------------------
## ⚠⚠ **MEASURED: 소 burnt its whole island on a target that never moved.** The flag was set before
## `_shove` ran, and `_shove` correctly refuses to put a body on a blocked tile — so an enemy with its
## back to a wall ate the charge and every later blow was refused for a charge nobody ever got.
##
## ⚠ Mutation: set `_charged` before the shove again.
func _a_blocked_shove_does_not_spend_the_charge(t) -> void:
	# A hole one tile behind the enemy, so the push has nowhere to go.
	var rows := _open(ARENA_W, ARENA_H)
	rows[5] = _with_char(str(rows[5]), 14, "#")
	var army := _army_of([Rules.COW])
	var b := _battle_of(rows, army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	var start: Vector2 = b.enemy_pos[0]
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "소가 실제로 때렸다 (자가 점검)")
	t.eq(b.enemy_pos[0], start, "벽에 등을 댄 적은 안 밀린다 (자가 점검)")

	# ⚠ **Neither body moves on its own here** — both are inside their own reach, so the enemy would
	# stand against that wall for the whole island. It is moved to open ground by hand, which is the
	# only thing that lets the NEXT blow ask for the charge at all.
	var open_at := Vector2(11, 5)
	b.enemy_pos[0] = open_at
	b._enemy_goal[0] = open_at
	b._settle(Battle.ENEMY_UID_BASE + 0, open_at)

	# A shove is a JUMP — a whole tile inside one sub-step — and a walk can never exceed
	# `speed * SIM_SUBSTEP_SEC`, so the two are separable.
	var walk_cap := Rules.speed_of(Rules.SHIELDBEARER) * Rules.SIM_SUBSTEP_SEC + 0.01
	var jumped := false
	for _k in 400:
		var was: Vector2 = b.enemy_pos[0]
		b.begin_frame()
		b.step(TICK_ONE)
		if was.distance_to(b.enemy_pos[0]) > walk_cap:
			jumped = true
			break
	t.ok(jumped, "막힌 타격이 지나간 뒤에도 돌진이 남아 있다 — 안 일어난 밀치기가 충전을 안 태운다")


## `row` with one character replaced. The island rows are strings, so a fixture wall is one splice.
func _with_char(row: String, at: int, ch: String) -> String:
	return row.substr(0, at) + ch + row.substr(at + 1)


# -- 티켓 15 fix: the shove's other two writes, each measured on its own -------------------------------
## ⚠⚠ **THE FOUR-THINGS-MOVE-TOGETHER CLAIM WAS MEASURED FOR ONE OF THE FOUR.** In the squirrel
## fixture the enemy had already WALKED, so `_walk` had moved `_enemy_goal` onto exactly the tile the
## pull lands on — deleting the goal write and deleting `_settle` both stayed green. This fixture
## makes the two diverge: the enemy STANDS (it is a 궁수 and the squirrel is inside its reach), so its
## goal is still its spawn tile and its reservation is still the tile it is standing on.
##
## ⚠ Mutation: drop `_enemy_goal[e] = best` (the body glides back); drop `_settle` (the OLD tile stays
## held, so one body holds two tiles and a doorway is half as wide — the plan's own named risk).
func _the_shove_moves_the_goal_and_the_reservation(t) -> void:
	var army := _army_of([Rules.SQUIRREL])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army,
		[_spawn(ARENA_W, Rules.ARCHER, 13, 5)], 999.0)
	_ashore(b, 0, Vector2(11, 5))
	var uid := Battle.ENEMY_UID_BASE + 0
	var start: Vector2 = b.enemy_pos[0]
	var start_tile := int(round(start.y)) * b.grid.w + int(round(start.x))
	t.eq(int(b.grid.reserved[start_tile]), uid, "적이 제 칸을 쥐고 있다 (자가 점검)")
	t.eq(Vector2(b._enemy_goal[0]), start, "그리고 목표도 그 칸이다 — 아직 한 걸음도 안 걸었다 (자가 점검)")

	b.begin_frame()
	b.step(TICK_ONE)
	var after: Vector2 = b.enemy_pos[0]
	t.ok(after.distance_to(start) > 0.5, "다람쥐가 끌었다 (자가 점검)")

	# (1) the GOAL moved with the body — otherwise the standing branch glides it straight back.
	t.eq(Vector2(b._enemy_goal[0]), after, "목표가 끌려간 자리로 같이 옮겨졌다")
	# (2) the RESERVATION moved with it — the old tile is free and the new one is held.
	var new_tile := int(round(after.y)) * b.grid.w + int(round(after.x))
	t.ok(new_tile != start_tile, "옮긴 칸이 원래 칸과 다르다 (자가 점검)")
	t.ok(int(b.grid.reserved[start_tile]) != uid,
		"떠난 칸을 더는 안 쥐고 있다 — 안 놓으면 몸 하나가 두 칸을 쥐고 문이 반쯤 막힌다")
	t.eq(int(b.grid.reserved[new_tile]), uid, "그리고 새 칸을 쥔다")
	# (3) and it stays: the archer is in reach, so it STANDS — a stale goal would show up here.
	for _k in 20:
		b.begin_frame()
		b.step(TICK_ONE)
	t.ok(b.enemy_pos[0].distance_to(start) > 0.5,
		"서 있는 적도 원래 자리로 안 미끄러져 돌아간다 — 「서 있는」 가지가 목표를 다시 집는다")


# -- 티켓 15: 늑대 — 무리사냥 -------------------------------------------------------------------------
## **A wolf picks its target from the centre of mass of the wolves NEAR IT, itself included.**
##
## ⚠⚠ **ONE LINE BUYS BOTH HALVES.** Picking from a shared point makes them bite the same enemy
## (티켓 06's own sentence), and `_phase_movement` then walks each of them at that enemy — so they
## arrive as one body. **There is no formation code and there must not be**: a second rule for the
## shape would be a second thing to keep in step with the first.
##
## ⚠ **Nearby and never GLOBAL.** A global centre drags a wolf that landed on the far beach toward one
## point, which deletes 「어디에 내리느냐」 — the decision this whole game is.
##
## ⚠ Mutation: `_nearest_enemy(_seek_point_of(i))` back to `_nearest_enemy(soldier_pos[i])` (the floor
## bites); make `_seek_point_of` ignore the radius and average every wolf (the ceiling bites).
func _the_wolves_hunt_as_one(t) -> void:
	var radius := Rules.pack_radius_of(Rules.WOLF)
	t.ok(radius > 0.0, "늑대에게 무리 반경이 있다")
	t.eq(radius, 6.0, "그 반경이 6칸이다 (리터럴 — 첫 값이고 잰 값이 아니다)")
	t.eq(Rules.pack_radius_of(Rules.CROW), 0.0, "까마귀에게는 없다 — 표가 둘을 가른다")

	# -- the FLOOR: two wolves 4 apart, each with its OWN nearer enemy, bite the same one -------------
	# A(5,5) and B(9,5) are 4.0 apart, so the centre is (7,5).
	#   P(7,9)  — 4.00 from the centre, 4.47 from each wolf: the PACK's pick
	#   Q(2,5)  — 3.00 from A, 5.00 from the centre: A's own pick without the rule
	#   R(12,5) — 3.00 from B, 5.00 from the centre: B's own pick without the rule
	var pack := _army_of([Rules.WOLF, Rules.WOLF])
	var pb := _battle_of(_open(ARENA_W, ARENA_H), pack, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 7, 9),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 2, 5),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),
	], 999.0)
	_ashore(pb, 0, Vector2(5, 5))
	_ashore(pb, 1, Vector2(9, 5))
	pb.begin_frame()
	pb.step(TICK_ONE)
	t.eq(int(pb.soldier_target[0]), 0, "늑대 A 가 무리의 표적을 문다 — 제 최근접이 아니라")
	t.eq(int(pb.soldier_target[1]), 0, "늑대 B 도 같은 놈을 문다")

	# -- the CEILING: the same three enemies, but the wolves are 12 apart -----------------------------
	# Outside the radius each wolf's centre is itself, so each takes its own nearest. **Without this
	# row 「전부 한 놈만 문다」 would pass the floor above.**
	var apart := _army_of([Rules.WOLF, Rules.WOLF])
	var ab := _battle_of(_open(ARENA_W, ARENA_H), apart, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 2, 9),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 14, 9),
	], 999.0)
	_ashore(ab, 0, Vector2(2, 5))
	_ashore(ab, 1, Vector2(14, 5))
	t.ok(ab.soldier_pos[0].distance_to(ab.soldier_pos[1]) > radius,
		"두 늑대가 반경 밖이다 (자가 점검)")
	ab.begin_frame()
	ab.step(TICK_ONE)
	t.eq(int(ab.soldier_target[0]), 0, "반경 밖 늑대는 제 최근접을 문다")
	t.eq(int(ab.soldier_target[1]), 1, "다른 쪽도 제 것을 문다 — 둘이 다르다")

	# -- the CONTROL: two crows in the pack arrangement each take their own --------------------------
	var crows := _army_of([Rules.CROW, Rules.CROW])
	var cb := _battle_of(_open(ARENA_W, ARENA_H), crows, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 7, 9),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 2, 5),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),
	], 999.0)
	_ashore(cb, 0, Vector2(5, 5))
	_ashore(cb, 1, Vector2(9, 5))
	cb.begin_frame()
	cb.step(TICK_ONE)
	t.eq(int(cb.soldier_target[0]), 1, "같은 배치의 까마귀 A 는 제 최근접을 문다")
	t.eq(int(cb.soldier_target[1]), 2, "까마귀 B 도 제 것을 문다 — 무는 점을 나누는 것은 이 종이다")

	# -- the SHAPE, on TWO enemies far apart -------------------------------------------------------
	# ⚠⚠ **THE OLD FIXTURE HERE MEASURED NOTHING AND THAT WAS MEASURED.** It had ONE enemy, so
	# `_nearest_enemy` answers the same id from any point at all and three bodies walking at one
	# target converge whatever the pack rule says: killing the radius to 0.0 left it green, and
	# pack-on and pack-off produced **the identical decimal**. `tightest > 0.0` was true forever,
	# since two bodies cannot share a tile.
	#
	# ⇒ **Two enemies, placed so a lone hunter SPLITS.** Every soldier stands closer to a different
	# one than the pack's own centre does, so pack-off sends them to two corners of the island and
	# pack-on sends all three to one body.
	#
	# ⚠ **The bound is DERIVED, not guessed**: three bodies all inside one enemy's reach are, by the
	# triangle inequality, at most twice that reach from each other.
	# ⚠⚠ **ENEMY 0 IS A LION AND IT WAS A SHIELDBEARER UNTIL 2026-08-25.** Nothing about the pack claim
	# moved; the WINDOW to observe it closed. `REACH_BONUS` went 1.5 -> 1.75 (티켓 19: melee could not
	# hit a diagonal one tier up), so the first wolves to arrive open fire from further out and a
	# 20 HP shieldbearer **died before the third wolf was inside reach** — the loop below broke on
	# `enemy_alive[0] == 0` with `together` never set. A target that outlives the arrival is what lets
	# the arrival be measured; 140 HP does, and the lion's detect of 2.0 is the smallest on the table,
	# so it also does not walk out from under the measurement. **The claim, the layout and the bound
	# are untouched.**
	var three := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var mb := _battle_of(_open(ARENA_W, ARENA_H), three, [
		_spawn(ARENA_W, Rules.LION, 2, 2),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 21, 10),
	], 999.0)
	_ashore(mb, 0, Vector2(11, 4))
	_ashore(mb, 1, Vector2(12, 6))
	_ashore(mb, 2, Vector2(11, 8))
	t.ok(_max_pair(mb, 3) <= radius, "셋이 서로 무리 반경 안에 있다 (자가 점검)")
	mb.begin_frame()
	mb.step(TICK_ONE)
	t.eq(int(mb.soldier_target[0]), 0, "셋이 무리의 표적을 문다 — A")
	t.eq(int(mb.soldier_target[1]), 0, "셋이 무리의 표적을 문다 — B")
	t.eq(int(mb.soldier_target[2]), 0, "셋이 무리의 표적을 문다 — C")

	# ⚠ The CONTROL, in the SAME layout: crows have no pack row, and they demonstrably split.
	var trio := _army_of([Rules.CROW, Rules.CROW, Rules.CROW])
	var sp := _battle_of(_open(ARENA_W, ARENA_H), trio, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 2, 2),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 21, 10),
	], 999.0)
	_ashore(sp, 0, Vector2(11, 4))
	_ashore(sp, 1, Vector2(12, 6))
	_ashore(sp, 2, Vector2(11, 8))
	sp.begin_frame()
	sp.step(TICK_ONE)
	var split := {}
	for i in 3:
		split[int(sp.soldier_target[i])] = true
	t.eq(split.size(), 2, "같은 배치의 까마귀 셋은 두 갈래로 갈린다 — 이 배치가 실제로 가른다 (자가 점검)")

	# And the pack ARRIVES as one body: every wolf inside the SAME enemy's reach at the same moment.
	var reach := Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
	var together := -1.0
	for _k in 700:
		mb.begin_frame()
		mb.step(TICK_ONE)
		if mb.enemy_alive[0] == 0:
			break
		var all_in := true
		for i in 3:
			if mb.soldier_pos[i].distance_to(mb.enemy_pos[0]) > reach + Rules.EPS:
				all_in = false
				break
		if all_in:
			together = _max_pair(mb, 3)
			break
	t.ok(together >= 0.0, "셋이 같은 적의 사거리 안에 동시에 들어간다 — 한 덩어리로 도착한다")
	t.ok(together <= 2.0 * reach + Rules.EPS,
		"그 순간 셋의 최대 상호 거리가 사거리의 두 배 안이다 (%.2f <= %.2f) — 삼각부등식이 주는 상한이다"
			% [together, 2.0 * reach])

	# The other end: the crows in the same layout never manage it, because two of them left for the
	# other corner. **Without this the row above would pass on any three bodies that happen to meet.**
	var crow_reach := Rules.range_of(Rules.CROW) + Rules.REACH_BONUS
	var crows_together := false
	for _k in 700:
		sp.begin_frame()
		sp.step(TICK_ONE)
		if sp.enemy_alive[0] == 0 or sp.enemy_alive[1] == 0:
			break
		var all_in := true
		for i in 3:
			if sp.soldier_pos[i].distance_to(sp.enemy_pos[0]) > crow_reach + Rules.EPS:
				all_in = false
				break
		if all_in:
			crows_together = true
			break
	t.ok(not crows_together, "까마귀 셋은 한 적 앞에 다 모이지 않는다 — 갈라진 채로 간다")

	# -- the WAY BACK: one wolf alone picks exactly as it did before ----------------------------------
	var lone := _army_of([Rules.WOLF])
	var lb := _battle_of(_open(ARENA_W, ARENA_H), lone, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 6, 5),
	], 999.0)
	_ashore(lb, 0, Vector2(3, 5))
	lb.begin_frame()
	lb.step(TICK_ONE)
	t.eq(int(lb.soldier_target[0]), 1, "혼자인 늑대는 무게중심이 제 자리라 예전과 똑같이 고른다")


## The largest distance between any two of the first `n` ashore soldiers.
func _max_pair(b: Battle, n: int) -> float:
	var worst := 0.0
	for i in n:
		for j in range(i + 1, n):
			worst = maxf(worst, b.soldier_pos[i].distance_to(b.soldier_pos[j]))
	return worst


# -- 티켓 15: 까마귀 — 출혈 ---------------------------------------------------------------------------
## ⚠⚠ **EVERY ROW HERE RUNS ON A BOARD WITH NOTHING FITTED, AND THAT IS THE ROW.** The 출혈 tag needs
## three copies of a bleed item before its tier lights, so on an empty board `_apply_statuses`' old
## path cannot turn bleed on at all — which makes 「the SPECIES is the source」 provable by itself
## rather than by argument.
##
## ⚠ Mutation: drop the species walk from `_apply_statuses`; give the bear a `SPECIES_STATUS` row (the
## control bites).
func _the_crow_bleeds_with_no_equipment(t) -> void:
	var army := _army_of([Rules.CROW])
	t.eq(army.loadout.tag_count(Rules.Tag.BLEED), 0, "판에 출혈 딱지가 하나도 없다 (자가 점검)")
	var b := _battle_of(_open(ARENA_W, ARENA_H), army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 6, 5)], 999.0)
	_ashore(b, 0, Vector2(3, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "까마귀가 실제로 때렸다 (자가 점검)")
	t.ok(b.status_left(Rules.Status.BLEED, 0) > 0.0,
		"딱지 하나 없이도 까마귀가 때린 적에게 출혈이 걸린다 — 출처는 장비가 아니라 종이다")

	# ⚠⚠ **The enemy is PARKED far away rather than the soldier being pulled off the island.** Sending
	# the crow back to RESERVE ends the island on the spot (`_the_landing_force_is_gone`), `step`
	# returns before `_phase_status`, and the bleed clock then freezes instead of expiring — measured:
	# the ceiling below read 1.97 of its 2.00 seconds with the whole fixture looking correct.
	var parked := Vector2(ARENA_W - 2, 5)
	b.enemy_pos[0] = parked
	b._enemy_goal[0] = parked
	b._settle(Battle.ENEMY_UID_BASE + 0, parked)
	var hp_before := b.enemy_hp[0]
	for _k in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < hp_before,
		"손이 떨어진 뒤에도 피가 계속 흐른다 (%.3f -> %.3f) — 바닥" % [hp_before, b.enemy_hp[0]])

	# The CEILING: it stops when the table's own duration runs out, and never before.
	var secs: float = float(Rules.species_status_of(Rules.CROW).get("sec", 0.0))
	t.ok(secs > 0.0, "표가 지속 시간을 갖고 있다 (자가 점검)")
	var settle := int(ceil(float(secs) / Rules.SIM_SUBSTEP_SEC)) + 4
	for _k in settle:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.status_left(Rules.Status.BLEED, 0), 0.0, "표의 지속 시간이 지나면 멎는다 — 천장")
	var hp_stopped := b.enemy_hp[0]
	for _k in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.enemy_hp[0], hp_stopped, "그리고 그 뒤로는 한 방울도 안 흐른다")
	# The fixture's own floor: the crow never got back into reach, so nothing above was re-applied.
	t.ok(b.soldier_pos[0].distance_to(b.enemy_pos[0])
			> Rules.range_of(Rules.CROW) + Rules.REACH_BONUS,
		"그동안 까마귀는 사거리 밖에 머물렀다 — 재적용이 아니라 만료다 (자가 점검)")

	# The CONTROL: the bear hits just as hard on the same empty board and leaves nothing behind.
	var bear := _army_of([Rules.BEAR])
	var bb := _battle_of(_open(ARENA_W, ARENA_H), bear,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(bb, 0, Vector2(11, 5))
	bb.begin_frame()
	bb.step(TICK_ONE)
	t.ok(bb.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "곰도 실제로 때렸다 (자가 점검)")
	t.eq(bb.status_left(Rules.Status.BLEED, 0), 0.0,
		"그런데 곰이 때린 적에게는 출혈이 안 걸린다 — 무는 것은 이 종이지 아무 타격이나가 아니다")
	t.ok(Rules.species_status_of(Rules.BEAR).is_empty(), "표에 곰 줄이 없다")


# -- 티켓 15: 다람쥐 — 끌어당김 · 소 — 돌진 ----------------------------------------------------------
## ⚠⚠ **THE TRAP THIS ROW EXISTS FOR IS NOT THE MOVE, IT IS THE MOVE COMING UNDONE.** Writing
## `enemy_pos` alone puts the body back where it was on the very next sub-step: `_phase_movement`'s
## standing branch glides it toward `_enemy_goal`, `_walk` re-picks that same goal, and
## `grid.reserved` still holds the OLD tile. **A check that reads final state after one sub-step
## cannot see any of that** — so this one runs ten more sub-steps and reads the position again.
##
## ⚠ Mutation: drop the `_enemy_goal` write (the body walks back); drop the `_settle` (two bodies end
## up holding one tile, and a doorway is half as wide with nothing on screen to say so).
func _the_squirrel_pulls_and_the_cow_charges(t) -> void:
	var pull_tiles := Rules.shove_tiles_of(Rules.SQUIRREL)
	t.ok(pull_tiles > 0.0, "다람쥐의 밀치기 값이 양수다 — 때린 쪽으로 당긴다 (리터럴 부호)")
	t.eq(pull_tiles, 1.0, "그 거리가 1칸이다 (리터럴 — 첫 값이고 잰 값이 아니다)")

	# -- 다람쥐: the enemy comes TOWARD it, and stays -----------------------------------------------
	var s_army := _army_of([Rules.SQUIRREL])
	var sb := _battle_of(_open(ARENA_W, ARENA_H), s_army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5)], 999.0)
	var squirrel_at := Vector2(11, 5)
	_ashore(sb, 0, squirrel_at)
	var before: Vector2 = sb.enemy_pos[0]
	sb.begin_frame()
	sb.step(TICK_ONE)
	var after: Vector2 = sb.enemy_pos[0]
	t.ok(sb.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "다람쥐가 실제로 때렸다 (자가 점검)")
	# The DIRECTION, as the sign of a dot product — never as a coordinate, which would pin the fixture
	# rather than the rule.
	t.ok((after - before).dot(squirrel_at - before) > 0.0, "맞은 적이 다람쥐 쪽으로 움직였다")
	t.ok(absf(before.distance_to(after) - pull_tiles) < 0.01,
		"그리고 표의 값만큼 움직였다 (%.2f칸)" % before.distance_to(after))
	# ⚠⚠ **The whole point of the row.** Ten more sub-steps with nobody else touching it.
	for _k in 10:
		sb.begin_frame()
		sb.step(TICK_ONE)
	t.ok(sb.enemy_pos[0].distance_to(before) >= pull_tiles - 0.01,
		"서브스텝을 열 번 더 돌려도 원래 자리로 안 되돌아간다 — 끌었다가 한 프레임 반짝하고 마는 것이 아니다")
	# And it never lands where a body cannot stand, nor past the puller.
	t.ok(sb.grid.is_passable(int(round(sb.enemy_pos[0].x)), int(round(sb.enemy_pos[0].y))),
		"끌려간 자리가 걸을 수 있는 칸이다")
	t.ok(sb.enemy_pos[0].x > squirrel_at.x,
		"그리고 다람쥐를 지나쳐 넘어가지 않는다 — 여전히 그 오른쪽이다")

	# -- 소: the enemy goes the OTHER way, and only on the first blow --------------------------------
	var charge_tiles := Rules.shove_tiles_of(Rules.COW)
	t.ok(charge_tiles < 0.0, "소의 밀치기 값은 음수다 — 반대쪽으로 민다 (리터럴 부호)")
	t.ok(Rules.shove_once_of(Rules.COW), "그리고 몸당 섬당 한 번뿐이라고 표가 말한다")
	t.ok(not Rules.shove_once_of(Rules.SQUIRREL), "다람쥐는 매번이다 — 표가 둘을 가른다 (자가 점검)")
	var c_army := _army_of([Rules.COW])
	var cb := _battle_of(_open(ARENA_W, ARENA_H), c_army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5)], 999.0)
	var cow_at := Vector2(12, 5)
	_ashore(cb, 0, cow_at)
	var c_before: Vector2 = cb.enemy_pos[0]
	cb.begin_frame()
	cb.step(TICK_ONE)
	var c_after: Vector2 = cb.enemy_pos[0]
	t.ok(cb.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "소가 실제로 때렸다 (자가 점검)")
	t.ok((c_after - c_before).dot(cow_at - c_before) < 0.0, "맞은 적이 소의 반대쪽으로 갔다")
	# ⚠⚠ **The second blow is measured as the LARGEST SINGLE SUB-STEP DISPLACEMENT after the first
	# one, not as a position.** Both bodies keep walking once the charge has opened the gap, so a
	# position comparison would be reading the walk. **A shove is a JUMP** — a whole tile inside one
	# sub-step — and a walk can never exceed `speed * SIM_SUBSTEP_SEC`, so the two are separable.
	var walk_cap := Rules.speed_of(Rules.SHIELDBEARER) * Rules.SIM_SUBSTEP_SEC + 0.01
	t.ok(c_before.distance_to(c_after) > walk_cap,
		"첫 타격의 이동은 걷기로 설명이 안 된다 (%.3f > %.3f) — 자가 점검이자 아래 줄의 바닥"
			% [c_before.distance_to(c_after), walk_cap])
	var hp_seen := cb.enemy_hp[0]
	var biggest := 0.0
	var hits := 0
	for _k in 400:
		var was: Vector2 = cb.enemy_pos[0]
		cb.begin_frame()
		cb.step(TICK_ONE)
		biggest = maxf(biggest, was.distance_to(cb.enemy_pos[0]))
		if cb.enemy_hp[0] < hp_seen:
			hits += 1
			hp_seen = cb.enemy_hp[0]
			if hits >= 2:
				break
	t.ok(hits >= 2, "두 번째·세 번째 타격이 실제로 들어갔다 (자가 점검)")
	t.ok(biggest <= walk_cap,
		"그 뒤로는 한 서브스텝에 걷는 거리 이상 안 움직인다 — 「첫 충돌」의 반쪽이다 (%.3f <= %.3f)"
			% [biggest, walk_cap])

	# -- 늑대: the control. Some blow does NOT move anything -----------------------------------------
	t.eq(Rules.shove_tiles_of(Rules.WOLF), 0.0, "늑대는 표에 밀치기 줄이 없다")
	var w_army := _army_of([Rules.WOLF])
	var wb := _battle_of(_open(ARENA_W, ARENA_H), w_army,
		[_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5)], 999.0)
	_ashore(wb, 0, Vector2(12, 5))
	var w_before: Vector2 = wb.enemy_pos[0]
	wb.begin_frame()
	wb.step(TICK_ONE)
	t.ok(wb.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "늑대도 실제로 때렸다 (자가 점검)")
	t.eq(wb.enemy_pos[0], w_before,
		"그런데 적은 한 칸도 안 움직였다 — 미는 것은 이 종이지 아무 타격이나가 아니다")


# -- 티켓 15: 곰 — 휘두르기 ---------------------------------------------------------------------------
## **The bear's whole passive is one number in `UNITS`' `area` column** — `_phase_attacks` already
## hands `Rules.area_of(st)` to `_hit_enemies`, and `_hit_enemies` already walks a radius. `battle.gd`
## is not opened for it.
##
## ⚠⚠ **The floor and the ceiling are in ONE fixture**: three enemies inside the radius all lose HP,
## and one outside it does not. A ceiling alone (「반경 밖은 안 맞는다」) is green when the bear never
## swings at all, which is `how-nets-lie`'s own four-at-once finding from the presentation round.
##
## ⚠ Mutation: `BEAR`'s `area` back to 0.0 (the floor bites); widen it past the outside enemy (the
## ceiling bites).
func _the_bear_sweeps(t) -> void:
	var army := _army_of([Rules.BEAR])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),   # primary, 1.0 from the bear
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 6),   # 1.41421 from the primary
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 8),   # 3.0 from the primary — outside
	], 999.0)
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)

	var full := Rules.hp_of(Rules.SHIELDBEARER)
	t.eq(b.soldier_target[0], 0, "곰의 주 표적은 최근접이다 (자가 점검)")
	t.ok(b.enemy_hp[0] < full, "주 표적이 맞았다 — 바닥")
	t.ok(b.enemy_hp[1] < full, "반경 안 직교 형제도 같이 맞았다 — 바닥")
	t.ok(b.enemy_hp[2] < full, "반경 안 대각 형제도 같이 맞았다 — 바닥")
	t.eq(b.enemy_hp[3], full, "반경 밖 하나는 그대로다 — 천장")
	# The radius itself, so 「휘두른다」 is a number and not a direction.
	t.ok(Rules.area_of(Rules.BEAR) > 0.0, "곰의 area 칸이 0 보다 크다")
	t.eq(Rules.area_of(Rules.BEAR), 1.5, "그 값이 1.5 다 (리터럴 — 첫 값이고 잰 값이 아니다)")
	# The CONTROL: the wolf has no area, so the same arrangement leaves the siblings whole.
	var lone := _army_of([Rules.WOLF])
	var w := _battle_of(_open(ARENA_W, ARENA_H), lone, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5),
	], 999.0)
	_ashore(w, 0, Vector2(11, 5))
	w.begin_frame()
	w.step(TICK_ONE)
	t.ok(w.enemy_hp[0] < full, "늑대도 주 표적은 때렸다 (자가 점검)")
	t.eq(w.enemy_hp[1], full, "그러나 형제는 멀쩡하다 — 휘두르는 것은 이 종이지 아무 타격이나가 아니다")


# -- the one bark this file owns -------------------------------------------------------------------

func _setup_barks_on_empty_grid(t) -> void:
	t.expect_error("battle.setup: 격자가 비어 있다")
	var dud := Battle.new()
	dud.setup(Grid.new(), _army_of([Rules.WOLF]), [_spawn(1, Rules.SHIELDBEARER, 0, 0)], 10.0)
	t.eq(dud.soldier_state.size(), 0, "빈 격자로 setup 하면 짖고 병사 열을 세우지 않는다")
	t.eq(dud.enemy_alive.size(), 0, "빈 격자로 setup 하면 적 열도 세우지 않는다")


# -- reservation, seen from outside ----------------------------------------------------------------

## Four soldiers funnelling through a one-tile neck at a lion that never leaves its post (detect 2).
##
## **The check reads POSITIONS, not `grid.reserved`.** Deleting `step_toward`'s "skip a tile someone else
## holds" test leaves the reservation table looking sane — `_hold` still refuses to overwrite — while the
## units walk straight through each other. Only where they ARE catches that.
func _no_two_units_share_a_tile(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _battle_of(_corridor(), army, [_spawn(CORR_W, Rules.LION, 9, 4)], 999.0)
	_ashore(b, 0, Vector2(2, 3))
	_ashore(b, 1, Vector2(2, 4))
	_ashore(b, 2, Vector2(2, 5))
	_ashore(b, 3, Vector2(3, 4))

	var observations := 0
	var clashes := 0
	var through := {}
	for _f in 100:
		b.begin_frame()
		b.step(0.1)
		var seen := {}
		for raw in b.ashore_ids():
			var i := int(raw)
			var k := _tile_key(b.soldier_pos[i], CORR_W)
			if seen.has(k):
				clashes += 1
			seen[k] = true
			observations += 1
			if b.soldier_pos[i].x > 5.5:
				through[i] = true
		for e in b.enemy_alive.size():
			if b.enemy_alive[e] == 0:
				continue
			var ke := _tile_key(b.enemy_pos[e], CORR_W)
			if seen.has(ke):
				clashes += 1
			seen[ke] = true
			observations += 1

	# A loop whose body never ran would report zero clashes just as loudly.
	t.ok(observations >= 300, "좁은 목 100프레임에서 유닛 위치를 %d번 읽었다 (최소 300)" % observations)
	t.eq(clashes, 0, "살아 있는 유닛 둘이 한 칸을 같이 쓰지 않는다")
	t.ok(through.size() >= 3, "네 병사 중 %d명이 좁은 목을 통과했다 — 줄서기가 실제로 일어났다" % through.size())
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.LION), "통과한 병사가 사자를 실제로 때렸다 — 검사가 빈 채로 초록이 아니다")


# -- targeting -------------------------------------------------------------------------------------

func _nearest_first(t) -> void:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 1),   # 4 tiles up
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 7),   # 2 tiles down
	], 999.0)
	_ashore(b, 0, Vector2(12, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_target[0], 1, "더 가까운 적을 고른다 (2칸 대 4칸)")

	# The near one dies; the next frame must hand the soldier the far one.
	b.enemy_hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_alive[1], 0, "가까운 적이 죽었다")
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_target[0], 0, "표적이 죽으면 남은 최근접으로 다시 고른다")

	var tie_army := _army_of([Rules.CROW])
	var tied := _battle_of(_open(ARENA_W, ARENA_H), tie_army, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 3),
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 7),
	], 999.0)
	_ashore(tied, 0, Vector2(12, 5))
	tied.begin_frame()
	tied.step(TICK_ONE)
	t.eq(tied.soldier_target[0], 0, "거리가 같으면 id 가 작은 쪽을 고른다")


# -- reach -------------------------------------------------------------------------------------

## Melee range is 0, so its reach is exactly `Rules.REACH_BONUS`. 1.0 is an orthogonal neighbour,
## 1.41421 a diagonal one, and 2.0 is the first distance that must not reach.
func _reach_is_range_plus_bonus(t) -> void:
	var full := Rules.hp_of(Rules.SHIELDBEARER)
	var hit := full - Rules.damage_of(Rules.WOLF)
	t.eq(_melee_probe(Vector2(-1, 0), TICK_ONE), hit, "정확히 1.0 칸에서 때린다")
	t.eq(_melee_probe(Vector2(-1, -1), TICK_ONE), hit, "정확히 1.41421 칸(대각)에서도 때린다")
	t.eq(_melee_probe(Vector2(-2, 0), TICK_ONE), full, "2.0 칸에서는 못 때린다")


## The comparison is `<=` with `Rules.EPS` of slack, so half an epsilon past the reach is inside and
## three epsilons past it is outside. Without the slack a diagonal — exactly sqrt(2) — is a coin flip.
##
## ⚠ **The OUTSIDE half cannot be read off damage any more, and pretending it can is a fake green.**
## One sub-step is the smallest amount of time there is, and a melee cell walks `4 / 60` = 0.067 tiles
## in it — three epsilons is 0.0003 — so a soldier outside its reach closes the gap and lands the blow
## in the very same sub-step, `_phase_movement` running before `_phase_attacks`. ⇒ **`_within` is read
## through the OTHER decision it makes**: it is also the test that decides whether to walk at all, so
## the outside case is "it had to walk first" and the inside case is "it never moved."
func _epsilon_edge(t) -> void:
	var full := Rules.hp_of(Rules.SHIELDBEARER)
	var hit := full - Rules.damage_of(Rules.WOLF)
	var inside := _reach_probe(Rules.REACH_BONUS + 0.5 * Rules.EPS)
	t.eq(inside["hp"], hit, "사거리+엡실론 절반 안쪽은 때린다")
	t.eq(inside["moved"], 0.0, "그리고 한 발짝도 안 걸었다 — 이미 사거리 안이라는 뜻이다")

	var outside := _reach_probe(Rules.REACH_BONUS + 3.0 * Rules.EPS)
	t.ok(float(outside["moved"]) > 0.0,
			"사거리+엡실론 세 배 바깥은 사거리 밖이다 — 때리기 전에 걸어야 했다 (%.4f칸)"
			% float(outside["moved"]))
	# The ceiling: it walked ONE sub-step's worth and not to the target. Without it, "moved" is also
	# satisfied by a unit that teleported.
	t.ok(float(outside["moved"]) <= Rules.speed_of(Rules.WOLF) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
			"그리고 딱 한 서브스텝만큼만 걸었다")
	t.eq(outside["hp"], hit,
			"바깥이어도 그 한 발짝이 사거리 안으로 데려다줘서 같은 서브스텝에 때렸다 — 이동이 공격보다 먼저 돈다")
	t.eq(full - Rules.damage_of(Rules.WOLF), hit, "때린 값은 근접 한 방이다 (자가 점검)")


## One melee soldier `gap` tiles west of one bison, driven exactly one sub-step. Returns the bison's HP
## and how far the soldier moved — the two halves `_within` decides between.
func _reach_probe(gap: float) -> Dictionary:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	var start := Vector2(12.0 - gap, 5.0)
	_ashore(b, 0, start)
	b.begin_frame()
	b.step(TICK_ONE)
	return {"hp": b.enemy_hp[0], "moved": start.distance_to(b.soldier_pos[0])}


# -- area ------------------------------------------------------------------------------------------

## **Two sibling tiles, not one.** The orthogonal neighbour is 1.0 away and the diagonal one 1.41421, and
## the two area values in the table are 1.0 and 1.5 — a case with only one kind of sibling cannot tell
## them apart, so an area silently widened from 1.0 to 1.5 would stay green.
func _area_splash(t) -> void:
	# area 1.0 (the ranged cell): the orthogonal sibling burns, the diagonal one does not.
	var small := _army_of([Rules.CROW])
	var b := _battle_of(_open(ARENA_W, ARENA_H), small, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),   # primary, 4.0 from the soldier
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 6),   # 1.41421 from the primary
	], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var full := Rules.hp_of(Rules.SHIELDBEARER)
	var splash := full - Rules.damage_of(Rules.CROW)
	t.eq(b.soldier_target[0], 0, "광역 공격의 주 표적은 최근접이다")
	# ⚠ **A `<=` and not an equality since 티켓 15**: 까마귀's own bleed rides its blow and
	# `_phase_status` takes its first sip in the SAME sub-step, so the exact figure carries a tick of
	# drip on top. The claim is about the BLOW landing; the drip is `_the_crow_bleeds_with_no_equipment`'s.
	t.ok(b.enemy_hp[0] <= splash + Rules.EPS, "주 표적이 맞았다")
	t.ok(b.enemy_hp[1] <= splash + Rules.EPS, "반경 1.0 — 직교 1.0 칸의 형제도 맞았다")
	t.eq(b.enemy_hp[2], full, "반경 1.0 — 대각 1.41421 칸의 형제는 안 맞았다")

	# area 1.5 (the lion): now the diagonal sibling burns too.
	#
	# ⚠ **The lion declares before it strikes**, so one frame measures the telegraph and not the blow —
	# this block used to read the splash off a single `step` and went red the day `LION_WINDUP_SEC`
	# landed. Waiting the wind-up out is only sound because nobody walks while it runs: all three are
	# already inside their 1.5 reach and the lion is inside its own, so the distances the splash is
	# measured at are still the ones written below. The position checks after the wait are what hold
	# that — without them a soldier could drift and the two area values stop being distinguishable.
	var wide := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var w := _battle_of(_open(ARENA_W, ARENA_H), wide, [_spawn(ARENA_W, Rules.LION, 12, 6)], 999.0)
	_ashore(w, 0, Vector2(12, 5))   # 1.0 from the lion
	_ashore(w, 1, Vector2(13, 5))   # 1.0 from soldier 0
	_ashore(w, 2, Vector2(13, 6))   # 1.41421 from soldier 0
	var whole := Rules.hp_of(Rules.WOLF)
	w.begin_frame()
	w.step(TICK_ONE)
	t.eq(w.enemy_target[0], 0, "사자의 주 표적은 id 가 작은 쪽이다 (1.0 동점)")
	t.eq(wide.hp[0], whole, "예고 프레임에는 광역이 아직 안 터졌다")
	# Break on the first blow: the next one is a whole `period + windup` away, and reading after two
	# would double every expectation below without changing which siblings were caught.
	var burst := false
	for _f in 40:
		w.begin_frame()
		w.step(0.05)
		if wide.hp[0] < whole:
			burst = true
			break
	t.ok(burst, "예고가 끝나자 사자의 광역이 실제로 터졌다")
	t.eq(w.soldier_pos[0], Vector2(12, 5), "기다리는 동안 주 표적은 안 걸었다 — 잰 거리는 fixture 의 것이다")
	t.eq(w.soldier_pos[1], Vector2(13, 5), "직교 형제도 안 걸었다")
	t.eq(w.soldier_pos[2], Vector2(13, 6), "대각 형제도 안 걸었다")
	var left := whole - Rules.damage_of(Rules.LION)
	t.eq(wide.hp[0], left, "주 표적이 맞았다")
	t.eq(wide.hp[1], left, "반경 1.5 — 직교 1.0 칸의 형제도 맞았다")
	t.eq(wide.hp[2], left, "반경 1.5 — 대각 1.41421 칸의 형제까지 맞았다")


## A ranged soldier splashing an enemy with a friendly standing 1.0 tile away — inside its own area.
## The friendly loses exactly the bison's blow and not a tile more.
func _no_friendly_fire(t) -> void:
	var army := _army_of([Rules.CROW, Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	_ashore(b, 1, Vector2(13, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	# ⚠ **A `<=` and not an equality since 티켓 15**: 까마귀's own bleed rides its blow and
	# `_phase_status` takes its first sip in the SAME sub-step, so the exact figure carries a tick of
	# drip on top. The claim is about the BLOW landing; the drip is `_the_crow_bleeds_with_no_equipment`'s.
	t.ok(b.enemy_hp[0]
			<= Rules.hp_of(Rules.SHIELDBEARER) - Rules.damage_of(Rules.CROW)
				- Rules.damage_of(Rules.WOLF) + Rules.EPS,
			"원거리와 근접이 둘 다 방패병을 때렸다 — 광역이 실제로 터졌다")
	t.eq(army.hp[1], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.SHIELDBEARER),
			"아군 오사 없음 — 광역 반경 안에 선 아군은 들소 몫만 잃었다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CROW), "쏜 병사 자신도 안 다쳤다")


# -- movement --------------------------------------------------------------------------------------

## A ranged soldier walking a one-tile-wide lane at a lion whose detect is 2, so the lion never moves and
## the distance measured at the end is the soldier's own doing. Reach is 5.5; without the stop rule it
## walks all the way into contact and the ranged type stops existing.
##
## ⚠ **Measured at two frame sizes, because the rule is enforced twice.** The frame gate in the movement
## phase and the per-tile break inside the walk are redundant at 0.1 s — a soldier covers 0.4 tiles, so
## deleting the inner break moves the stopping point by nothing at all and a single-frame-size check
## stays green about it. At 0.5 s the same soldier covers two tiles in one call, and only the inner break
## can stop it inside the frame.
func _stops_when_target_is_in_range(t) -> void:
	var fine := _lane_approach(0.1, 60)
	t.eq(fine["lion"], Vector2(18, 2), "탐지 2인 사자는 제자리에 있었다 — 거리는 병사가 만든 것이다")
	t.ok(float(fine["x"]) > 10.0, "병사가 실제로 걸어왔다 (x=%.2f)" % float(fine["x"]))
	t.ok(float(fine["d"]) >= 4.5, "0.1초 프레임 — 사거리에 들어오자 멈췄다 (%.2f칸)" % float(fine["d"]))
	t.ok(float(fine["d"]) <= 6.0, "0.1초 프레임 — 그렇다고 사거리 밖에 멈추지도 않았다 (%.2f칸)" % float(fine["d"]))
	t.ok(float(fine["hp"]) < Rules.hp_of(Rules.LION), "멈춘 자리에서 실제로 쐈다")

	var coarse := _lane_approach(0.5, 12)
	t.ok(float(coarse["d"]) >= 4.9,
			"0.5초 프레임 — 한 프레임에 두 칸을 가도 사거리를 지나치지 않는다 (%.2f칸)" % float(coarse["d"]))
	t.ok(float(coarse["d"]) <= 6.0, "0.5초 프레임 — 그리고 사거리 밖에 서 있지도 않다 (%.2f칸)" % float(coarse["d"]))


# -- death -----------------------------------------------------------------------------------------

## A dead soldier's row stays and never boards again, on this island or the next one.
func _death_is_permanent(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	army.hp[0] = 1.0
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.SHIELDBEARER, 13, 2)], 999.0)
	_ashore(b, 0, Vector2(12, 2))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(army.alive[0], 0, "1 HP 병사가 들소의 3 을 맞고 죽었다")
	t.eq(army.hp[0], 0.0, "죽은 병사의 HP 는 0 으로 잘린다 — 음수 잔액이 남지 않는다")
	t.eq(army.type_id.size(), 2, "죽어도 명부의 줄은 남는다")
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "이번 섬에서 DEAD 로 바뀌었다")
	t.eq(army.living_count(), 1, "살아 있는 병사는 한 명이다")

	# The next island is left in the PLANNING state on purpose: 「a dead soldier never boards again」 is
	# a `send` refusal now, and `send` is the only call that can be asked it. It is also `_port()` and
	# not `_lane()`, because `_lane()` has no harbour and `send` would refuse both soldiers for a
	# reason that has nothing to do with death — a check that passes for the wrong reason.
	var next_island := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 18, 9)], 999.0)
	var next_landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	t.eq(next_island.soldier_state[0], Battle.SoldierState.DEAD, "다음 섬에서도 예비가 아니라 DEAD 로 선다")
	t.ok(next_island.send(1, next_landing) >= 0, "살아남은 병사는 보낼 수 있다")
	var aboard: Array = (next_island.boats[0] as Dictionary)["soldiers"]
	t.eq(int(aboard[0]), 1, "배에 탄 것은 살아남은 1번이다")
	t.eq(next_island.send(0, next_landing), -1, "죽은 병사는 다시 못 보낸다")
	t.eq(next_island.boats.size(), 1, "그 거절은 배를 한 척도 안 늘렸다")


# -- the phase order is a contract -----------------------------------------------------------------

## boats -> landings -> targeting -> movement -> attacks -> deaths -> clock, each seam measured by a
## consequence that only that order produces.
func _phase_order(t) -> void:
	# boats BEFORE landings: a crossing that completes this frame unloads this frame, not next.
	var ferry_army := _army_of([Rules.WOLF])
	var ferry := _planning_battle_of(_port(), ferry_army, [_spawn(ARENA_W, Rules.LION, 20, 9)], 999.0)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	t.ok(ferry.send(0, landing) >= 0, "부두 없는 항구에서도 배가 뜬다")
	t.ok(ferry.commit(), "그리고 시작 버튼이 그 배를 실제로 출발시킨다 (자가 점검)")
	# ⚠ **Driven one sub-step at a time, never as one coarse `step(dist / speed)`.** A coarse call
	# stops a sub-step short: `_substep_acc` subtracts the sub-step repeatedly and the last residue
	# lands a hair under it in IEEE double, so this row would read as "it did not unload" when what it
	# measured was floating point.
	#
	# ⚠⚠ **RE-MEASURED TWICE.** `speed-off-open-landing` moved it off 4.0: `_port()`'s bay is open
	# water, but `water_route` descends a HOP-COUNT field where a diagonal and an orthogonal step both
	# cost 1, so it picked four diagonals — `4 x sqrt(2) = 5.656854` tiles, arriving on sub-step 85.
	# The route SMOOTHER then string-pulled that V out: the route is `(2,5) (5,4) (6,5)` and the
	# crossing is `sqrt(10) + sqrt(2) = 4.576491` tiles = `68.647` sub-steps, arrival on **69**.
	# ⚠ It is still not the 4.0 straight line, and that is `_entry_water_tile` choosing (5,4) over
	# (5,5) as the tile to beach from — a one-tile dogleg at the very end, not a smoothing failure.
	# The literal moved twice; it did not become a formula.
	t.ok(absf(float(ferry.boats[0]["dist"]) - 4.576491) <= 1e-5,
			"이 항로는 정확히 sqrt(10) + sqrt(2) = 4.576491칸이다 (자가 점검)")
	t.ok(absf(float(ferry.boats[0]["dist"]) / float(ferry.boats[0]["speed"]) * 60.0 - 68.647) <= 0.01,
			"곧 68.647 서브스텝이다 — 도착은 그 다음 서브스텝인 69에 걸린다 (자가 점검)")
	for _i in 68:
		ferry.begin_frame()
		ferry.step(TICK_ONE)
	t.eq(ferry.soldier_state[0], Battle.SoldierState.TRANSIT, "68 서브스텝에는 아직 배 위다 (자가 점검)")
	ferry.begin_frame()
	ferry.step(TICK_ONE)
	t.eq(ferry.soldier_state[0], Battle.SoldierState.ASHORE,
			"배가 도착한 그 서브스텝에 내린다 — 보트가 상륙보다 먼저 돈다")

	# targeting BEFORE movement: a soldier picks a target and walks on its very first frame.
	var first_army := _army_of([Rules.CROW])
	var first := _battle_of(_lane(), first_army, [_spawn(LANE_W, Rules.LION, 18, 2)], 999.0)
	_ashore(first, 0, Vector2(2, 2))
	first.begin_frame()
	first.step(0.1)
	t.eq(first.soldier_target[0], 0, "첫 프레임에 표적을 잡았다")
	t.ok(first.soldier_pos[0].x > 2.0, "그리고 같은 프레임에 걸었다 — 타겟팅이 이동보다 먼저 돈다")

	# movement BEFORE attacks: the first blow lands the instant movement brings the target into reach.
	var full := Rules.hp_of(Rules.LION)
	t.eq(_lane_march(TICK_ONE), full, "처음엔 4.0 칸이라 못 때린다")
	t.eq(_lane_march(0.7), full - Rules.damage_of(Rules.WOLF),
			"걸어 들어간 그 프레임에 첫 발이 나간다 — 이동이 공격보다 먼저 돈다")

	# attacks BEFORE deaths: two units that finish each other off both land the blow.
	var trade_army := _army_of([Rules.WOLF])
	trade_army.hp[0] = Rules.damage_of(Rules.SHIELDBEARER)
	var trade := _battle_of(_lane(), trade_army, [_spawn(LANE_W, Rules.SHIELDBEARER, 13, 2)], 999.0)
	trade.enemy_hp[0] = Rules.damage_of(Rules.WOLF)
	_ashore(trade, 0, Vector2(12, 2))
	trade.begin_frame()
	trade.step(TICK_ONE)
	t.eq(trade.enemy_alive[0], 0, "동시에 끝난 교환 — 들소가 죽었다")
	t.eq(trade_army.alive[0], 0, "그리고 들소도 마지막 한 방을 쳤다 — 공격이 사망보다 먼저 돈다")

	# deaths BEFORE the clock, and WON before either loss: an island cleared on the expiring frame is a win.
	var wire_army := _army_of([Rules.WOLF])
	var wire := _battle_of(_lane(), wire_army, [_spawn(LANE_W, Rules.SHIELDBEARER, 13, 2)], 0.5)
	wire.enemy_hp[0] = Rules.damage_of(Rules.WOLF)
	_ashore(wire, 0, Vector2(12, 2))
	wire.begin_frame()
	wire.step(0.5)
	t.eq(wire.outcome(), Battle.Outcome.WON, "타이머가 끝나는 그 프레임에 비운 섬은 승리다")
	t.eq(wire.lose_reason(), Battle.Lose.NONE, "승리에는 패배 사유가 없다")

	# ... and the timeout arm is live, so the win above is not "the clock never fires".
	var late_army := _army_of([Rules.WOLF])
	var late := _battle_of(_lane(), late_army, [_spawn(LANE_W, Rules.SHIELDBEARER, 13, 2)], 0.5)
	_ashore(late, 0, Vector2(12, 2))
	late.begin_frame()
	late.step(0.5)
	# ⚠⚠ **INVERTED, 2026-08-24** (the user: 「제한 시간 안에 클리어 조건은 일단 지워」). This pair used
	# to assert the timeout arm was live. It is gone, and the check is kept POINTING THE OTHER WAY
	# rather than deleted: 「the clock does not decide」 is a rule, and a rule with nothing measuring it
	# comes back by accident.
	t.eq(late.outcome(), Battle.Outcome.RUNNING, "시간이 다 가도 지지 않는다 — 시계는 판정하지 않는다")
	t.eq(late.lose_reason(), Battle.Lose.NONE, "그러므로 패배 사유도 없다")


# -- the run ends when nobody is left in the fight -------------------------------------------------

## ⚠⚠ **THE USER SAT WATCHING AN EMPTY ISLAND UNTIL THE TIMER RAN OUT**, and reported it:
## ***"실패조건은 시작하기하고 못깨면 이지 제한시간을 계속 기다리고 있길래"***.
##
## `_phase_clock` lost on `army.living_count() == 0`, and `living_count` counts every soldier that is
## not dead — **reserves at the harbour included.** After the commit `send` refuses everything, so a
## reserve can never be landed: hold anyone back, lose everyone you sent, and the run is decided and
## cannot end. The old test could not fire at all.
##
## ⚠ **The margin is the whole check.** `elapsed <= time_limit` is also true of the behaviour being
## fixed — that is `how-nets-lie`'s *a ceiling with no floor* exactly — so the limit here is 90 s
## against a crossing of about 1.2, and the assertion is on the GAP.
##
## ⚠ **And `living_count() == 2` is the floor under it.** Two soldiers are still alive when the island
## is lost. Restore the old condition and that is the line that cannot be satisfied.
func _reserves_do_not_hold_the_run_open(t) -> void:
	var limit := 90.0
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 20, 1)], limit)
	var landing := _tile_key(_PORT_LANDING, ARENA_W)
	t.ok(b.send(0, landing) >= 0, "셋 중 한 명만 보냈다 (자가 점검)")
	t.ok(b.commit(), "그리고 시작을 눌렀다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.RESERVE, "1번은 항구에 남았다 (자가 점검)")
	t.eq(b.soldier_state[2], Battle.SoldierState.RESERVE, "2번도 남았다 (자가 점검)")
	# The premise, asserted rather than assumed: a reserve can never join the fight after the commit,
	# which is what makes holding one back a decision that is already over.
	t.eq(b.send(1, landing), -1, "확정 뒤에는 남은 병사를 못 내린다 — 이 검사의 전제다")

	var n := 0
	while n < 400 and b.soldier_state[0] != Battle.SoldierState.ASHORE:
		b.begin_frame()
		b.step(TICK_ONE)
		n += 1
	t.eq(b.soldier_state[0], Battle.SoldierState.ASHORE, "보낸 한 명이 상륙했다 (%d 서브스텝)" % n)
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "아직 굴러간다 (자가 점검)")

	# It dies. `army.hp = 0` and one sub-step, so `_phase_deaths` writes DEAD the way the fight does —
	# never by poking `soldier_state` here, which would make this a check about the poke.
	army.hp[0] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "그리고 죽었다 (자가 점검)")

	t.eq(b.outcome(), Battle.Outcome.LOST, "상륙한 병사가 다 죽으면 그 자리에서 진다")
	t.eq(b.lose_reason(), Battle.Lose.LANDING_LOST,
		"패인은 전멸이 아니라 상륙 실패다 — 항구에 산 병사가 남아 있다")
	t.ok(b.enemies_left() > 0, "적은 아직 남아 있다 — 승리와 헷갈릴 여지가 없다 (%d마리)" % b.enemies_left())
	# ⚠⚠ **THE LINE THE OLD RULE CANNOT PASS.**
	t.eq(army.living_count(), 2, "그런데 병사는 아직 둘이 살아 있다 — 항구에 선 예비 병력이다")
	# The margin. Both ends: the fight really ran, and it ended nowhere near the clock.
	t.ok(b.elapsed > 0.0, "시계는 실제로 돌았다 (%.4f초)" % b.elapsed)
	t.ok(b.elapsed < 2.0, "그런데 2초도 안 걸렸다 (%.4f초) — 건너는 데 약 1.2초다" % b.elapsed)
	t.ok(limit - b.elapsed > 85.0,
		"제한 시간 90초까지 %.2f초를 남기고 끝났다 — 기다릴 것이 없어졌으면 기다리지 않는다"
			% (limit - b.elapsed))


## ⚠⚠ **THE COUNTER-CASE, and it is where the fix breaks silently if it is written as ASHORE-only.**
## A soldier aboard an OUTBOUND boat has not landed and has not lost. Collapse the rule to "nobody
## ashore" and the last crossing on an island whose beachhead just died is thrown away one sub-step
## before it resolves — a fake failure, and one the player would read as the game giving up on them.
func _a_soldier_at_sea_does_hold_it_open(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 20, 1)], 90.0)
	var landing := _tile_key(_PORT_LANDING, ARENA_W)
	t.ok(b.send(0, landing) >= 0 and b.send(1, landing) >= 0, "둘을 보냈다 (자가 점검)")
	t.ok(b.commit(), "2번은 항구에 남긴 채 시작했다 (자가 점검)")

	# Five sub-steps in, both are still at sea — the crossing is about seventy.
	for _f in 5:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "0번은 아직 바다 위다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.TRANSIT, "1번도 바다 위다 (자가 점검)")

	army.hp[0] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "0번이 바다에서 죽었다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.TRANSIT, "1번은 여전히 건너는 중이다")
	t.eq(b.outcome(), Battle.Outcome.RUNNING,
		"아무도 뭍에 없어도 배 위에 한 명이 있으면 아직 안 졌다 — 마지막 항해가 남았다")

	# And then it lands, so the RUNNING above is not "this fixture can never end".
	var n := 0
	while n < 400 and b.soldier_state[1] != Battle.SoldierState.ASHORE:
		b.begin_frame()
		b.step(TICK_ONE)
		n += 1
	t.eq(b.soldier_state[1], Battle.SoldierState.ASHORE, "1번이 상륙했다 (%d 서브스텝 더)" % n)
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "상륙한 뒤에도 계속 굴러간다")

	army.hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.outcome(), Battle.Outcome.LOST, "그 마지막 한 명까지 죽고 나서야 진다")
	t.eq(b.lose_reason(), Battle.Lose.LANDING_LOST, "패인은 상륙 실패다 — 2번이 아직 살아 있다")
	t.eq(army.living_count(), 1, "항구의 2번은 그때도 살아 있다")


## ⚠⚠ **BOTH LOSS REASONS ARE TRUE AT ONCE HERE, AND THE PRECEDENCE IS THE CHECK.** Send everybody,
## kill everybody: the landing force is gone AND every soldier is dead. `WIPED` wins, because "every
## soldier is dead" is the stronger claim and the more useful one to read. **An unstated precedence is
## what diverges later** — a reader of `_phase_clock` who reordered the two would break nothing that
## anyone could see, because both arms end the island.
##
## ⚠ The floor beside it is the round-4 fixture two functions up, which reaches the SAME condition and
## must answer `LANDING_LOST`. Neither reason is reachable-by-default: one holds reserves back and one
## does not, and that single difference is the whole of what the screen now says.
func _wiped_wins_when_both_are_true(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 20, 1)], 90.0)
	var landing := _tile_key(_PORT_LANDING, ARENA_W)
	t.ok(b.send(0, landing) >= 0 and b.send(1, landing) >= 0, "둘 다 보냈다 — 항구에 아무도 안 남는다 (자가 점검)")
	t.ok(b.commit(), "그리고 시작을 눌렀다 (자가 점검)")
	for _f in 5:
		b.begin_frame()
		b.step(TICK_ONE)
	army.hp[0] = 0.0
	army.hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_ONE)

	t.eq(army.living_count(), 0, "병사가 하나도 안 남았다 (자가 점검)")
	t.eq(b.outcome(), Battle.Outcome.LOST, "그래서 졌다 (자가 점검)")
	t.eq(b.lose_reason(), Battle.Lose.WIPED,
		"두 조건이 다 참일 때는 전멸이 이긴다 — 「병사가 다 죽었다」가 「상륙 부대가 없어졌다」보다 큰 말이다")


## ⚠⚠ **THE GATE, driven directly, because `step` hides it.** `step` returns before `_phase_clock`
## while uncommitted, so the `_committed` test inside `_the_landing_force_is_gone` is unreachable
## through the public path today — and an unreachable guard is exactly the kind that gets deleted as
## dead code by the next person. Every soldier is RESERVE during planning, so without it an island is
## lost on the frame it opens.
func _the_gate_itself(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 20, 1)], 90.0)
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "계획 중에는 전원이 RESERVE 다 (자가 점검)")
	t.eq(b.soldier_state[1], Battle.SoldierState.RESERVE, "둘 다 그렇다 (자가 점검)")
	t.ok(not b._the_landing_force_is_gone(),
		"확정 전에는 전원이 RESERVE 여도 '병력이 없어졌다'가 아니다 — 게이트가 없으면 섬이 열리자마자 진다")

	# The same roster with the flag flipped: now it IS gone. Without this line the row above would
	# also be green if the function simply always answered false.
	b._committed = true
	t.ok(b._the_landing_force_is_gone(),
		"같은 명부라도 확정 뒤에는 '병력이 없어졌다'가 된다 — 게이트가 읽는 것은 _committed 하나다")


# -- the boat is cargo, not a fighting position ----------------------------------------------------

## A soldier still aboard is shot at and cannot shoot back, and the enemies that CAN walk stay put,
## because chasing a target standing on water asks `flow_field` for a path to an impassable tile.
##
## ⚠ **Pinned from both sides, per `boat-and-landing` 4.7 / 8.6 — and pinned so the two sides cannot
## collapse into the same final state.** An earlier version of this fixture gave the bison ONLY the
## boat in range: under the correct rule it has no valid target and stands; under an
## `ashore_only = true -> false` mutation it targets the boat, asks `flow_field` for a path to a water
## tile, gets `UNREACHABLE` everywhere, and `step_toward` returns its own position — so it ALSO stands,
## at the exact same tile. "Excluded from the scan" and "frozen by an unreachable field" read
## identically in final position, and the mutation stayed green.
##
## The bison below has BOTH a boat (nearer, moving) and a real ashore soldier (farther, at a NAMED
## tile) inside its detect radius at once. Under the correct rule it can only ever see the ashore
## soldier and walks toward THAT tile. Under the mutation the boat is nearer than the ashore soldier
## from the very first frame (measured: ~4.8 tiles against the ashore soldier's constant 5.0), so the
## bison targets it instead, asks `flow_field` for a path to water, and freezes at its start tile for
## the whole window — two different, checkable outcomes, not the same one twice.
##
## ⚠ **The ashore soldier is RANGED, not melee, and that is load-bearing.** A melee ashore soldier
## advances on ITS OWN nearest enemy — this bison — independent of anything under test here, which
## moves the "static, named tile" the assertions below are built on and corrupted an earlier draft of
## this fixture (measured: a melee stand-in closed enough distance in 0.3s to occasionally overtake the
## boat as nearest even under the CORRECT rule, and the check passed by accident). Placed within its
## own 5.5-tile reach of the bison, a ranged soldier stops and shoots instead of walking, so it never
## moves at all — the fixed point the rest of this test needs.
func _in_transit_is_hit_but_cannot_hit(t) -> void:
	var army := _army_of([Rules.CROW, Rules.CROW])
	var b := _planning_battle_of(_port(), army, [
		_spawn(ARENA_W, Rules.ARCHER, 3, 2),    # ~3.0 tiles from the boat 0.3s into a 1.33s crossing
		_spawn(ARENA_W, Rules.SHIELDBEARER, 7, 4),   # sees BOTH the boat and the ashore soldier below
	], 999.0)
	var ashore_target := Vector2(7, 9)   # 5.0 tiles from the bison, inside its detect 6 and the
	                                      # ranged soldier's own 5.5-tile reach of the bison — it stops
	_ashore(b, 1, ashore_target)
	var bison_start: Vector2 = b.enemy_pos[1]
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	b.send(0, landing)
	b.commit()
	for _f in 3:
		b.begin_frame()
		b.step(0.1)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT, "병사는 아직 배 위다")
	t.ok(b.is_hittable(0), "배 위의 병사는 맞을 수 있다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CROW) - Rules.damage_of(Rules.ARCHER),
			"까마귀가 배 위의 병사를 실제로 쐈다")
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.ARCHER), "배 위의 병사는 사거리 안이어도 못 때린다")
	t.ok(b.enemy_pos[1].distance_to(bison_start) > 0.1,
			"그리고 들소는 실제로 움직였다 (%.2f칸) — 배를 쫓다 얼어붙은 게 아니라는 증거다"
			% b.enemy_pos[1].distance_to(bison_start))
	t.ok(b.enemy_pos[1].distance_to(ashore_target) < ashore_target.distance_to(bison_start) - 0.3,
			"움직인 방향이 상륙한 병사 쪽이다 (남은 거리 %.2f칸, 시작 5.00칸) — 배 쪽으로 얼어붙지 않고 이름 붙은 그 칸을 향해 실제로 걸었다는 뜻이다"
			% b.enemy_pos[1].distance_to(ashore_target))


# -- ticket 11: statuses — the table rows reach the fight, measured through step -------------------

## Fixture item ids, pinned with what each is for and asserted below to carry that tag.
## ⚠ **The boards they land on are BEAR's and COW's** — player species nobody summons yet — so the items' own
## stat columns cannot move the melee/ranged arithmetic every expectation below is built from, and the
## rows double as "the count is army-wide" measured through the fight.
const ITEM_BLEED := 7    # 부싯돌 이빨 — 출혈 딱지, 문턱 3 (0.5/초 · 2초)
const ITEM_SLOW := 1     # 돌 목걸이 — 디버프(감속) 딱지, 문턱 2 (이동속도 70% · 2초)


## `n` copies of `item` onto `beast_type`'s board, through the real take/fit path.
func _worn(a: Army, item: int, n: int, beast_type: int) -> void:
	for _i in n:
		a.loadout.take_card(item)
		a.loadout.fit(beast_type, 0)


## One melee soldier adjacent to one bison, with `bleed_items` copies of the bleed item on the crow's
## board, driven exactly one sub-step — the blow lands (and, when the tier is lit, the bleed with it).
func _bled_bison_battle(bleed_items: int) -> Battle:
	var army := _army_of([Rules.WOLF])
	_worn(army, ITEM_BLEED, bleed_items, Rules.BEAR)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	return b


## 「층이 켜진 채 한 대 맞은 적은 손이 떨어져도 피가 흐른다」. Mutation: delete the DOT arm of
## `_phase_status`. ⚠ 기대값 0.5/초는 리터럴이다 — 표를 되읽으면 검사가 표와 같이 움직인다.
func _bleed_drips_after_the_blow(t) -> void:
	var b := _bled_bison_battle(3)
	t.eq(b.army.loadout.tag_count(Rules.Tag.BLEED), 3, "출혈 딱지가 셋이다 (자가 점검)")
	var after_blow := b.enemy_hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.SHIELDBEARER), "첫 타격이 실제로 들어갔다 (자가 점검)")
	# 30 sub-steps with the hand off: the cooldown is 1.0 s, so no second blow can land inside them.
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained := after_blow - b.enemy_hp[0]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"손이 떨어진 30 서브스텝 동안 피가 초당 0.5 로 흘렀다 (%.4f칸)" % drained)
	t.eq(b.enemy_alive[0], 1, "그리고 그 출혈로는 아직 안 죽었다 (자가 점검)")


## 「층이 꺼져 있으면 출혈 0」 — 딱지 둘은 문턱 셋 미달이고, 전투를 지나도 아무것도 흐르지 않는다.
func _bleed_off_below_threshold(t) -> void:
	var b := _bled_bison_battle(2)
	t.eq(b.army.loadout.tag_count(Rules.Tag.BLEED), 2, "출혈 딱지가 둘뿐이다 (자가 점검)")
	var after_blow := b.enemy_hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.SHIELDBEARER), "타격 자체는 들어갔다 (자가 점검)")
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.enemy_hp[0], after_blow, "문턱 미달이면 타격 뒤에 아무것도 흐르지 않는다")


## 「두 대 맞아도 크기가 안 는다」 — 갱신이지 누적이 아니다. 두 번째 타격(약 61 서브스텝) 뒤의 흐름이
## 여전히 초당 0.5 다. Mutation: make the status write ADD the magnitude instead of overwriting it.
func _bleed_refreshes_and_never_stacks(t) -> void:
	var b := _bled_bison_battle(3)
	# through sub-step 70 — the second blow lands at ~61, the third at ~121.
	for _f in 69:
		b.begin_frame()
		b.step(TICK_ONE)
	var hits := Rules.hp_of(Rules.SHIELDBEARER) - b.enemy_hp[0]
	t.ok(hits > 2.0 * Rules.damage_of(Rules.WOLF),
		"두 번째 타격이 실제로 들어갔다 (자가 점검 — 깎인 피 %.3f > 직격 두 방)" % hits)
	var at70 := b.enemy_hp[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained := at70 - b.enemy_hp[0]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"두 대 맞은 뒤에도 흐름은 초당 0.5 그대로다 — 크기는 갱신이지 누적이 아니다 (%.4f칸)" % drained)


## 「출혈로 죽은 적이 같은 서브스텝의 죽음 처리를 지난다」 — alive 가 그 서브스텝에 꺼지고 DEATH 가
## 그 프레임의 events 에 실린다. Mutation: move `_phase_status` after `_phase_deaths`.
func _bleed_death_passes_the_same_substep(t) -> void:
	var b := _bled_bison_battle(3)
	# under one sub-step's drip (0.5/60 ≈ 0.0083), and the soldier's cooldown blocks a direct blow.
	b.enemy_hp[0] = 0.004
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_alive[0], 0, "출혈만으로 그 서브스텝에 죽었다 — 지속피해가 죽음 처리보다 먼저 돈다")
	var saw := false
	for ev in b.events:
		if int(ev["kind"]) == Battle.Event.DEATH and bool(ev["is_enemy"]) and int(ev["id"]) == 0:
			saw = true
	t.ok(saw, "그리고 그 프레임의 events 에 DEATH 가 실렸다")


## 「상태는 광역의 형제에게도 실린다」 — both status fixtures above are single-target, so the splash
## arm of the apply walk had no row of its own. A ranged blow catches an orthogonal sibling inside its
## 1.0 area, and the sibling bleeds like the primary. Mutation: delete the splash loop in
## `_apply_statuses`.
## ⚠⚠ **THE SHOOTER IS THE BEAR AND THAT IS THE WHOLE OF WHY THIS ROW MEASURES ANYTHING.** It was the
## crow — the one player species that bleeds by ITSELF (`Rules.SPECIES_STATUS`) — so deleting the
## splash arm of the tag loop entirely left this green: the species table re-supplied identical values
## through the other door. **Measured: the named mutation did not bite.** The bear splashes (`area`
## 1.5) and carries no status row of its own, so the equipment tag is the only source left.
func _status_rides_the_splash(t) -> void:
	var army := _army_of([Rules.BEAR])
	t.ok(Rules.species_status_of(Rules.BEAR).is_empty(),
		"곰은 제 종의 상태이상이 없다 (자가 점검 — 이게 무너지면 이 줄은 다시 아무것도 안 재다)")
	_worn(army, ITEM_BLEED, 3, Rules.COW)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),   # primary, 1.0 from the soldier
		_spawn(ARENA_W, Rules.SHIELDBEARER, 13, 5),   # orthogonal sibling — inside the 1.5 splash
	], 999.0)
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var sib: float = b.enemy_hp[1]
	t.ok(sib < Rules.hp_of(Rules.SHIELDBEARER), "광역이 형제도 실제로 때렸다 (자가 점검)")
	# 30 sub-steps with the hand off: the bear's cooldown is 1.8 s, so no second blow lands.
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
	var drained: float = sib - b.enemy_hp[1]
	t.ok(absf(drained - 0.5 * 30.0 / 60.0) <= 1e-3,
		"광역에 맞은 형제에게도 출혈이 흐른다 (%.4f칸) — 상태는 주 표적만의 것이 아니다" % drained)


## A ranged soldier at (4,5) and a bison at (9,5): the gap 5.0 is inside the soldier's 5.5 reach (the
## blow lands on sub-step 1) and inside the bison's detect 6 (it walks). Distance TRAVELLED is summed
## per sub-step, so a flow-field zigzag cannot shrink what is measured. Returns tiles travelled over
## the 30 sub-steps AFTER the blow landed.
func _slow_probe(slow_items: int) -> float:
	var army := _army_of([Rules.CROW])
	_worn(army, ITEM_SLOW, slow_items, Rules.COW)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 9, 5)], 999.0)
	_ashore(b, 0, Vector2(4, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	return travelled


## 「층이 켜진 채 맞은 적은 한 서브스텝에 덜 걷는다」 — 같은 fixture 를 딱지 0개와 2개로 돌려 겉는
## 거리를 잰다. ⚠ 배율 0.7 은 리터럴이다. Mutation: drop the slow multiplier from `_phase_movement`.
func _slow_makes_the_hit_enemy_walk_less(t) -> void:
	var plain := _slow_probe(0)
	var slowed := _slow_probe(2)
	t.ok(absf(plain - Rules.speed_of(Rules.SHIELDBEARER) * 30.0 / 60.0) <= 0.02,
		"안 맞은 들소는 30 서브스텝에 제 속도 그대로 걷는다 (자가 점검, %.3f칸)" % plain)
	t.ok(absf(slowed - 0.7 * Rules.speed_of(Rules.SHIELDBEARER) * 30.0 / 60.0) <= 0.02,
		"감속 걸린 들소는 그 70%% 만 걷는다 (%.3f칸)" % slowed)


## 「시간이 다하면 원래 속도로 돌아온다」. The shooter dies right after the blow so nothing can
## refresh; a second ranged soldier is parked where the bison keeps walking, and HIS trigger finger is
## pinned on a second bison inside his own reach, so no friendly blow ever lands on the measured one.
## Mutation: make the slow permanent (drop the time check from the multiplier).
func _slow_expires_back_to_full_speed(t) -> void:
	var army := _army_of([Rules.CROW, Rules.CROW])
	_worn(army, ITEM_SLOW, 2, Rules.COW)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5),   # 0 — the measured one, slowed once then left alone
		_spawn(ARENA_W, Rules.SHIELDBEARER, 6, 9),    # 1 — soldier 1's pinned target, 4.0 from him
	], 999.0)
	_ashore(b, 0, Vector2(9, 5))   # the shooter: 3.0 from bison 0 — its nearest, inside 5.5
	_ashore(b, 1, Vector2(6, 5))   # the bait: bison 1 at 4.0 is his nearest and inside his reach
	b.begin_frame()
	b.step(TICK_ONE)
	t.ok(b.enemy_hp[0] < Rules.hp_of(Rules.SHIELDBEARER), "0번 들소가 한 대 맞았다 (자가 점검)")
	b.army.hp[0] = 0.0   # the shooter dies — nothing refreshes the slow again
	# sub-steps 2..89: the shooter's death latches, bison 0 walks west toward soldier 1, slowed.
	for _f in 88:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "쏜 병사는 죽었다 (자가 점검)")
	t.eq(b.soldier_pos[1], Vector2(6, 5), "미끼 병사는 제자리다 (자가 점검 — 제 사거리 안 표적을 쏜다)")
	# slowed window, sub-steps 90..107 (the slow runs out at ~121).
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 18:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - 0.7 * Rules.speed_of(Rules.SHIELDBEARER) * 18.0 / 60.0) <= 0.02,
		"감속이 살아 있는 동안은 70%% 로 걷는다 (자가 점검, %.3f칸)" % travelled)
	# through sub-step 121, where the 2.0 s run out.
	for _f in 14:
		b.begin_frame()
		b.step(TICK_ONE)
	# full-speed window, sub-steps 122..139 — it stops at reach of the bait only past ~145.
	travelled = 0.0
	prev = b.enemy_pos[0]
	for _f in 18:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - Rules.speed_of(Rules.SHIELDBEARER) * 18.0 / 60.0) <= 0.02,
		"시간이 다하면 원래 속도로 돌아온다 (%.3f칸)" % travelled)
	t.eq(b.enemy_alive[1], 1, "미끼의 들소도 창 밖에서 살아 있다 (자가 점검 — 표적이 안 바뀌었다)")


## 「다시 맞아도 배율이 안 겹친다」 — 두 번째 타격(~61 서브스텝) 뒤에도 70% 이지, 70%×70%=49% 가
## 아니다. Mutation: make the status write MULTIPLY the magnitude onto the stored one.
func _slow_refreshes_and_never_stacks(t) -> void:
	var army := _army_of([Rules.CROW])
	_worn(army, ITEM_SLOW, 2, Rules.COW)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 9, 5)], 999.0)
	_ashore(b, 0, Vector2(4, 5))
	# through sub-step 69 — the second blow lands at ~61 and refreshes.
	for _f in 69:
		b.begin_frame()
		b.step(TICK_ONE)
	# ⚠ **A `<=` and not an equality since 티켓 15**: 까마귀's own bleed rides its blow and
	# `_phase_status` takes its first sip in the SAME sub-step, so the exact figure carries a tick of
	# drip on top. The claim is about the BLOW landing; the drip is `_the_crow_bleeds_with_no_equipment`'s.
	t.ok(b.enemy_hp[0] <= Rules.hp_of(Rules.SHIELDBEARER) - 2.0 * Rules.damage_of(Rules.CROW)
			+ Rules.EPS,
		"두 번째 타격이 들어갔다 (자가 점검)")
	var travelled := 0.0
	var prev: Vector2 = b.enemy_pos[0]
	for _f in 30:
		b.begin_frame()
		b.step(TICK_ONE)
		travelled += prev.distance_to(b.enemy_pos[0])
		prev = b.enemy_pos[0]
	t.ok(absf(travelled - 0.7 * Rules.speed_of(Rules.SHIELDBEARER) * 30.0 / 60.0) <= 0.02,
		"두 대 맞아도 배율은 70%% 그대로다 — 겹쳐 곱하면 49%% 가 된다 (%.3f칸)" % travelled)


## 「적의 타격은 병사에게 아무 상태도 못 건다」 — 출혈과 감속 두 층이 다 켜진 무리에서, 맞은 병사의
## 피는 흐르지 않고 총 맞은 병사의 걸음은 그대로다. Mutation: apply statuses inside `_hit_soldiers`.
func _enemy_blows_carry_no_status(t) -> void:
	# the bleed half: a melee soldier adjacent to a bison takes its blow, and nothing drips afterwards.
	var army := _army_of([Rules.WOLF])
	_worn(army, ITEM_BLEED, 3, Rules.BEAR)
	_worn(army, ITEM_SLOW, 2, Rules.COW)
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var after_blow: float = army.hp[0]
	t.ok(after_blow < Rules.hp_of(Rules.WOLF), "들소의 타격이 들어갔다 (자가 점검)")
	# the bison's period is 2.0 s, so 60 sub-steps hold no second blow.
	for _f in 60:
		b.begin_frame()
		b.step(TICK_ONE)
	t.eq(army.hp[0], after_blow, "맞은 병사의 피는 흐르지 않는다 — 적 타격은 출혈을 못 건다")

	# the slow half: soldier 0 trades blows with the crow (enemy 0), so a SLOW is live at enemy
	# index 0; the crow dies and the soldier walks to the far bison — a soldier/enemy index confusion
	# that read the slow onto the walker would bite exactly here, because the indices coincide.
	var walk_army := _army_of([Rules.WOLF])
	_worn(walk_army, ITEM_BLEED, 3, Rules.BEAR)
	_worn(walk_army, ITEM_SLOW, 2, Rules.COW)
	var w := _battle_of(_open(ARENA_W, ARENA_H), walk_army, [
		_spawn(ARENA_W, Rules.ARCHER, 8, 5),     # 0 — adjacent, trades a blow, then dies
		_spawn(ARENA_W, Rules.SHIELDBEARER, 16, 5),   # 1 — the far target the soldier walks to afterwards
	], 999.0)
	_ashore(w, 0, Vector2(7, 5))
	w.begin_frame()
	w.step(TICK_ONE)
	t.ok(walk_army.hp[0] < Rules.hp_of(Rules.WOLF), "까마귀가 실제로 쐈다 (자가 점검)")
	t.ok(w.enemy_hp[0] < Rules.hp_of(Rules.ARCHER), "병사도 까마귀를 때렸다 — 0번 적에 감속이 걸려 있다 (자가 점검)")
	w.enemy_hp[0] = 0.0
	for _f in 2:
		w.begin_frame()
		w.step(TICK_ONE)
	t.eq(w.enemy_alive[0], 0, "까마귀가 죽었다 (자가 점검)")
	var travelled := 0.0
	var prev: Vector2 = w.soldier_pos[0]
	for _f in 20:
		w.begin_frame()
		w.step(TICK_ONE)
		travelled += prev.distance_to(w.soldier_pos[0])
		prev = w.soldier_pos[0]
	t.ok(absf(travelled - Rules.speed_of(Rules.WOLF) * 20.0 / 60.0) <= 0.02,
		"총 맞은 병사의 걸음은 그대로다 — 적 타격은 감속을 못 건다 (%.3f칸)" % travelled)


# -- fixtures --------------------------------------------------------------------------------------

## One melee soldier `offset` tiles from one bison, stepped once. Returns the bison's HP.
func _melee_probe(offset: Vector2, dt: float) -> float:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.SHIELDBEARER, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5) + offset)
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## A ranged soldier walking the lane at the lion from 16 tiles out. Returns where it ended up.
func _lane_approach(dt: float, frames: int) -> Dictionary:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)], 999.0)
	_ashore(b, 0, Vector2(2, 2))
	for _f in frames:
		b.begin_frame()
		b.step(dt)
	return {
		"d": b.soldier_pos[0].distance_to(b.enemy_pos[0]),
		"x": b.soldier_pos[0].x,
		"lion": b.enemy_pos[0],
		"hp": b.enemy_hp[0],
	}


## One melee soldier 4.0 tiles down the lane from the lion, stepped once by `dt`. Returns the lion's HP.
func _lane_march(dt: float) -> float:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)], 999.0)
	_ashore(b, 0, Vector2(14, 2))
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## Water border, land inside, no docks.
func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## One tile tall. The walk down it is forced straight, so "how far did it stop" is not confounded by the
## diagonal drift an open field produces when two neighbours tie on hop count.
func _lane() -> Array:
	var rows := []
	for y in LANE_H:
		if y == 2:
			rows.append("~" + ".".repeat(LANE_W - 2) + "~")
		else:
			rows.append("~".repeat(LANE_W))
	return rows


## The open arena with a bay on its west side: rows 3-7 are open water for the first six columns, one
## harbour tile sitting inside it at (2,5). The coast begins at column 6 — `_PORT_HARBOUR` (2,5) and
## `_PORT_LANDING` (6,5) are 4.0 tiles apart in a straight line, and ⚠ **the boat sails 4.576491**:
## the route smoother pulls the hop-count BFS's four-diagonal V (5.656854) down to `(2,5) (5,4) (6,5)`,
## and the remainder over the straight line is `_entry_water_tile` beaching from (5,4) rather than
## (5,5). `boat.dist` / `boat.speed` is still the right way to time a crossing here — it is the
## POLYLINE's length over the speed.
const _PORT_HARBOUR := Vector2(2, 5)
const _PORT_LANDING := Vector2(6, 5)

func _port() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


## A wall pierced by a single tile at (5,4).
func _corridor() -> Array:
	var rows := []
	for y in CORR_H:
		if y == 0 or y == CORR_H - 1:
			rows.append("~".repeat(CORR_W))
		elif y == 4:
			rows.append("~" + ".".repeat(CORR_W - 2) + "~")
		else:
			rows.append("~....#.....~")
	return rows


func _grid_of(rows: Array) -> Grid:
	var g := Grid.new()
	g.load_rows(rows)
	return g


## `Army.add(type_id)` is gone — a body is `recruit`ed from a SLOT now. Every `type_id` this file passes
## is a PLAYER row, so it is registered into the army's own slots
## here rather than at every call site.
func _army_of(types: Array) -> Army:
	var a := Army.new()
	# ⚠ **The slots are the ARMY's now, so the resolution asks the army rather than a constant table.**
	# `register_species` is idempotent-by-refusal, so asking for the same species twice costs one slot.
	for raw in types:
		var ty := int(raw)
		var slot := a.slot_of_type(ty)
		if slot < 0:
			slot = a.register_species(ty)
		a.recruit(slot)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


## An island already under way. ⚠ **The commit flag is set directly, and that is deliberate.** `step`
## refuses everything until the island is committed (`plan-then-watch`, 4.3) — which is a RULE, and it
## is measured thoroughly by `net_plan`. Calling `commit()` here is not possible anyway: it refuses a
## plan with no boats, and almost every fixture in this file puts its soldiers ashore by hand rather
## than sailing them. This file owns the combat rules, so it starts from an island already under way,
## the same way `_ashore` below starts from a soldier who has already landed.
## **A fixture that has to author a plan uses `_planning_battle_of` and calls the real `commit()`.**
func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var b := _planning_battle_of(rows, army, spawns, limit)
	b._committed = true
	return b


## The same island, left in the planning state, so a check can drive `send` and `commit` for real.
func _planning_battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var b := Battle.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	b.setup(_grid_of(rows), army, spawns, limit)
	return b


## Puts a soldier on the island the way a landing would. **All three of state, position and goal**, plus
## the tile reservation `battle` writes on unload — set only the state and the unit teleports back to its
## stale goal on the first frame it moves.
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[_tile_key(p, b.grid.w)] = i
	b.grid.reserved = claimed


func _tile_key(p: Vector2, w: int) -> int:
	return int(round(p.y)) * w + int(round(p.x))
