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
	_the_gate_itself(t)
	# -- ticket 11: the status table reaches the fight ---------------------------------------------
	# -- 티켓 15: the passives that are still ON THE BOARD ---------------------------------------------
	# ⚠⚠ **THREE ROWS WERE DELETED HERE 2026-08-27 AND ALL THREE HAD STOPPED MEASURING.**
	# 「까마귀는 장비 없이도 문다」, 「늑대가 무리로 사냥한다」 and 「까마귀 제 종의 출혈이 장비를 안
	# 덮어쓴다」 went with `Rules.SPECIES_STATUS` and `Rules.SPECIES_PACK`. Both tables are looked up
	# against the PLAYER's roster and **both held a single beast row that became an ENEMY on 2026-08-26**,
	# so `species_status_of` answered `{}` and `pack_radius_of` answered 0.0 on every call in the game.
	# ⇒ **What survived the cut did so by moving to a live source**: the bleed CEILING is now driven off
	# the equipment tag (`_the_bleed_stops_when_its_tier_runs_out`), and the kind-dependent strength
	# comparison is now labelled as the arithmetic it is
	# (`_a_status_tier_is_strong_the_way_its_kind_reads`). The reasoning each deleted row carried is
	# written where the row stood.
	_the_bear_sweeps(t)
	# ⚠⚠ **THREE SHOVE ROWS WERE DELETED HERE 2026-08-27, AND THEY HAD ALREADY STOPPED MEASURING.**
	# 「다람쥐 끌어당김 · 소 돌진」, 「막힌 밀치기는 충전을 안 태운다」 and 「밀치기가 목표와 예약을 함께
	# 옮긴다」 went with `Rules.SPECIES_SHOVE`. The table emptied on 2026-08-26 when 다람쥐 and 소 left
	# `UNITS`, and the three had been rewritten to pass `Rules.SWORDSMAN` where those two stood — so
	# they asked a swordsman for a shove distance, got 0.0, and asserted it was positive. **Red for a
	# reason that had nothing to do with the behaviour they were named after.**
	#
	# What they held: the sign convention (positive pulls the victim TOWARD the attacker, negative
	# pushes it away), the 「once per island」 column that told a charge from a pull, that a blocked
	# shove must not spend the charge, and that `enemy_pos` alone undoes itself within one sub-step
	# unless `_enemy_goal` and `grid.reserved` move with it.
	# ⇒ **The full reasoning is in `battle.gd` where `_shove` stood**, including the user's 티켓 19
	# decision that a body never changes tier by being pushed.




func _with_char(row: String, at: int, ch: String) -> String:
	return row.substr(0, at) + ch + row.substr(at + 1)
# -- 무리사냥: 「늑대가 무리로 사냥한다」 삭제됨 2026-08-27 --------------------------------------------
## ⚠⚠ **THIS ROW AND ITS HELPER `_max_pair` ARE DELETED WITH `Rules.SPECIES_PACK`, `Rules.pack_radius_of`
## AND `Battle._seek_point_of`.** It asked `pack_radius_of(Rules.WOLF)` for a radius of 6.0 and then
## drove five fixtures through it; the table was read against the PLAYER's roster and the wolf has been
## an ENEMY since 2026-08-26, so **the rule under test had not run once in a real fight since that day.**
##
## ⚠⚠ **WHAT IT CAUGHT, WHICH IS THE ONLY REASON THIS PARAGRAPH EXISTS.** An earlier version of the same
## row had ONE enemy on the board, and `_nearest_enemy` answers the same id from any point at all — so
## three bodies walking at one target converge whatever the rule says. **Forcing the radius to 0.0 left
## it green and pack-on and pack-off printed the identical decimal**, which `tools/probe/pack_spread.gd`
## then measured properly and `how-nets-lie` records. ⇒ **A row about a rule that CHOOSES
## between things must put at least two things in front of it to choose between**, and the rewrite that
## fixed it — two enemies placed so a lone hunter SPLITS, plus a control species that demonstrably does
## split — is the shape to copy, not the wolf.
##
## ⚠ **Two more things it knew.** The bound on 「도착했을 때 서로 얼마나 가까운가」 was DERIVED and never
## guessed: three bodies all inside one enemy's reach are at most twice that reach from each other, by
## the triangle inequality. And its far target had to be a **LION**: `REACH_BONUS` went 1.5 -> 1.75 and a
## 20 HP body then died before the third attacker was inside reach, so the loop broke with the
## measurement never taken — **a target that outlives the arrival is what lets the arrival be measured.**
##
## ⇒ **The rule itself, why it was hollow as well as dead, and the reverted cohesion throttle are in
## `rules.gd` where `SPECIES_PACK` stood.** Do not rebuild this row from this comment alone.


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
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 1.0 from the bear
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.WOLF, 13, 6),   # 1.41421 from the primary
		_spawn(ARENA_W, Rules.WOLF, 12, 8),   # 3.0 from the primary — outside
	])
	_ashore(b, 0, Vector2(11, 5))
	b.begin_frame()
	b.step(TICK_ONE)

	var full := Rules.hp_of(Rules.WOLF)
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
		_spawn(ARENA_W, Rules.WOLF, 12, 5),
		_spawn(ARENA_W, Rules.WOLF, 13, 5),
	])
	_ashore(w, 0, Vector2(11, 5))
	w.begin_frame()
	w.step(TICK_ONE)
	t.ok(w.enemy_hp[0] < full, "늑대도 주 표적은 때렸다 (자가 점검)")
	t.eq(w.enemy_hp[1], full, "그러나 형제는 멀쩡하다 — 휘두르는 것은 이 종이지 아무 타격이나가 아니다")


# -- the one bark this file owns -------------------------------------------------------------------

func _setup_barks_on_empty_grid(t) -> void:
	t.expect_error("battle.setup: 격자가 비어 있다")
	var dud := Battle.new()
	dud.setup(Grid.new(), _army_of([Rules.WOLF]), [_spawn(1, Rules.WOLF, 0, 0)])
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
	var b := _battle_of(_corridor(), army, [_spawn(CORR_W, Rules.LION, 9, 4)])
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
		_spawn(ARENA_W, Rules.WOLF, 12, 1),   # 4 tiles up
		_spawn(ARENA_W, Rules.WOLF, 12, 7),   # 2 tiles down
	])
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
		_spawn(ARENA_W, Rules.WOLF, 12, 3),
		_spawn(ARENA_W, Rules.WOLF, 12, 7),
	])
	_ashore(tied, 0, Vector2(12, 5))
	tied.begin_frame()
	tied.step(TICK_ONE)
	t.eq(tied.soldier_target[0], 0, "거리가 같으면 id 가 작은 쪽을 고른다")


# -- reach -------------------------------------------------------------------------------------

## Melee range is 0, so its reach is exactly `Rules.REACH_BONUS`. 1.0 is an orthogonal neighbour,
## 1.41421 a diagonal one, and 2.0 is the first distance that must not reach.
func _reach_is_range_plus_bonus(t) -> void:
	var full := Rules.hp_of(Rules.WOLF)
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
	var full := Rules.hp_of(Rules.WOLF)
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
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
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
		_spawn(ARENA_W, Rules.WOLF, 12, 5),   # primary, 4.0 from the soldier
		_spawn(ARENA_W, Rules.WOLF, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.WOLF, 13, 6),   # 1.41421 from the primary
	])
	_ashore(b, 0, Vector2(8, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var full := Rules.hp_of(Rules.WOLF)
	var splash := full - Rules.damage_of(Rules.CROW)
	t.eq(b.soldier_target[0], 0, "광역 공격의 주 표적은 최근접이다")
	# ⚠⚠ **AN EQUALITY AGAIN SINCE 2026-08-27, AND THE LOOSENING IS WORTH REMEMBERING.** This read
	# `t.ok(hp <= expected + EPS)` for two days: 까마귀 carried an innate bleed (`Rules.SPECIES_STATUS`)
	# that rode its own blow, and `_phase_status` took its first sip inside the SAME sub-step — so the
	# exact figure carried a tick of drip on top. **That table is deleted and the drip with it**, so the
	# blow is once more the only thing that touches this number. ⇒ **A bound loosened to admit a second
	# effect is tightened back the day that effect goes**, or the row quietly stops pinning the blow.
	t.eq(b.enemy_hp[0], splash, "주 표적이 타격 몰만큼 정확히 깎였다")
	t.eq(b.enemy_hp[1], splash, "반경 1.0 — 직교 1.0 칸의 형제도 같은 몴만큼 맞았다")
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
	var w := _battle_of(_open(ARENA_W, ARENA_H), wide, [_spawn(ARENA_W, Rules.LION, 12, 6)])
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
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(8, 5))
	_ashore(b, 1, Vector2(13, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	# ⚠⚠ **AN EQUALITY AGAIN SINCE 2026-08-27, AND THE LOOSENING IS WORTH REMEMBERING.** This read
	# `t.ok(hp <= expected + EPS)` for two days: 까마귀 carried an innate bleed (`Rules.SPECIES_STATUS`)
	# that rode its own blow, and `_phase_status` took its first sip inside the SAME sub-step — so the
	# exact figure carried a tick of drip on top. **That table is deleted and the drip with it**, so the
	# blow is once more the only thing that touches this number. ⇒ **A bound loosened to admit a second
	# effect is tightened back the day that effect goes**, or the row quietly stops pinning the blow.
	t.eq(b.enemy_hp[0],
			Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.CROW) - Rules.damage_of(Rules.WOLF),
			"원거리와 근접의 몴이 정확히 둘 다 들어갔다 — 광역이 실제로 터졌다")
	t.eq(army.hp[1], Rules.hp_of(Rules.WOLF) - Rules.damage_of(Rules.WOLF),
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



# -- the phase order is a contract -----------------------------------------------------------------



# -- the run ends when nobody is left in the fight -------------------------------------------------







## ⚠⚠ **THE GATE, driven directly, because `step` hides it.** `step` returns before `_phase_clock`
## while uncommitted, so the `_committed` test inside `_the_landing_force_is_gone` is unreachable
## through the public path today — and an unreachable guard is exactly the kind that gets deleted as
## dead code by the next person. Every soldier is RESERVE during planning, so without it an island is
## lost on the frame it opens.
func _the_gate_itself(t) -> void:
	var army := _army_of([Rules.WOLF, Rules.WOLF])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.WOLF, 20, 1)])
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



# -- ticket 11: statuses — the table rows reach the fight, measured through step -------------------

## ⚠⚠ **THE STATUS SUITE STOOD HERE AND IT IS DELETED** (2026-08-29) with the statuses themselves —
## bleed refreshing without stacking, bleed killing inside the same sub-step, bleed riding the splash,
## slow expiring back to full speed, slow never stacking, and enemy blows carrying nothing. **Every
## one of them armed a body through `army.loadout`, and nothing in the game could fit an item.**
## ⚠ **The fixture discipline is the part to carry back**: the items were fitted onto species the
## fight does not use, so their own stat columns could not move the arithmetic the expectations were
## built from, and the rows doubled as 「the count is army-wide」 measured through a real fight.


























# -- fixtures --------------------------------------------------------------------------------------

## One melee soldier `offset` tiles from one bison, stepped once. Returns the bison's HP.
func _melee_probe(offset: Vector2, dt: float) -> float:
	var army := _army_of([Rules.WOLF])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.WOLF, 12, 5)])
	_ashore(b, 0, Vector2(12, 5) + offset)
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## A ranged soldier walking the lane at the lion from 16 tiles out. Returns where it ended up.
func _lane_approach(dt: float, frames: int) -> Dictionary:
	var army := _army_of([Rules.CROW])
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)])
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
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.LION, 18, 2)])
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


## The open arena with a bay on its west side: rows 3-7 are open water for the first six columns, and
## the coast begins at column 6. **This is the one fixture in this file a boat can sail on**, and every
## row that summons uses it.
##
## ⚠⚠ **BOTH OF THIS FIXTURE'S TILE CONSTANTS ARE DELETED (2026-08-27) AND NEITHER HAS A SUCCESSOR.**
## `_PORT_HARBOUR` (2,5) named the `H` tile a boat departed from and `_PORT_LANDING` (6,5) named the
## beach `send` was handed; the pair was 4.0 tiles apart in a straight line and the boat sailed
## 4.576491 of `grid.water_route`'s smoothed polyline. **`send`, `water_route` and `home_harbour_for`
## are all deleted**: a summon names ONE tile, the water the player pressed, and the grid derives the
## other end from it. ⇒ **Neither end of a crossing is a fixture constant any more** — the origin comes
## out of `_summonable_water_on` and the landing out of `grid.summon_landing_of`, and a row that wants
## the length asks the boat.
##
## ⚠ **The `H` tile at (2,5) STAYS, and it is decoration now.** `grid.harbour_tiles` is still filled
## from it and nothing in `summon`'s path reads that table — which makes this bay the fixture that
## would catch a harbour creeping back into a departure, not the one that proves it has not.
##
## ⚠⚠ **THE BAND THIS BAY HOLDS IS TWO TILES WIDE AND THAT IS WORTH KNOWING BEFORE EDITING IT.**
## `Rules.SUMMON_BAND_MIN_TILES` is 3 hops off the shore and `Grid.summon_radius()` is
## `max(w, h) * 0.46 = 11.04` about the centre (12,6), and the only water satisfying both is **(2,5)
## and (3,5)** — (1,5) misses the ring by 0.005 of a tile. **Narrowing the bay or moving the coast east
## empties the band**, and then every summon row in this file reddens at once;
## `_death_is_permanent` carries the one line that says so out loud.
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
func _battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := _planning_battle_of(rows, army, spawns)
	b._committed = true
	return b


## The same island, left in the planning state, so a check can drive `send` and `commit` for real.
func _planning_battle_of(rows: Array, army: Army, spawns: Array) -> Battle:
	var b := Battle.new()
	# load_rows first, always: setup writes a reservation per enemy and load_rows clears the table.
	b.setup(_grid_of(rows), army, spawns)
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
