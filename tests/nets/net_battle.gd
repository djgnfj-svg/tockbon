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
	_beak_adds_one_tile(t)
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


# -- the one bark this file owns -------------------------------------------------------------------

func _setup_barks_on_empty_grid(t) -> void:
	t.expect_error("battle.setup: 격자가 비어 있다")
	var dud := Battle.new()
	dud.setup(Grid.new(), _army_of([Rules.CELL_MELEE]), [_spawn(1, Rules.BISON, 0, 0)], 10.0)
	t.eq(dud.soldier_state.size(), 0, "빈 격자로 setup 하면 짖고 병사 열을 세우지 않는다")
	t.eq(dud.enemy_alive.size(), 0, "빈 격자로 setup 하면 적 열도 세우지 않는다")


# -- reservation, seen from outside ----------------------------------------------------------------

## Four soldiers funnelling through a one-tile neck at a lion that never leaves its post (detect 2).
##
## **The check reads POSITIONS, not `grid.reserved`.** Deleting `step_toward`'s "skip a tile someone else
## holds" test leaves the reservation table looking sane — `_hold` still refuses to overwrite — while the
## units walk straight through each other. Only where they ARE catches that.
func _no_two_units_share_a_tile(t) -> void:
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE, Rules.CELL_MELEE, Rules.CELL_MELEE])
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
	var army := _army_of([Rules.CELL_RANGED])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [
		_spawn(ARENA_W, Rules.BISON, 12, 1),   # 4 tiles up
		_spawn(ARENA_W, Rules.BISON, 12, 7),   # 2 tiles down
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

	var tie_army := _army_of([Rules.CELL_RANGED])
	var tied := _battle_of(_open(ARENA_W, ARENA_H), tie_army, [
		_spawn(ARENA_W, Rules.BISON, 12, 3),
		_spawn(ARENA_W, Rules.BISON, 12, 7),
	], 999.0)
	_ashore(tied, 0, Vector2(12, 5))
	tied.begin_frame()
	tied.step(TICK_ONE)
	t.eq(tied.soldier_target[0], 0, "거리가 같으면 id 가 작은 쪽을 고른다")


# -- reach -------------------------------------------------------------------------------------

## Melee range is 0, so its reach is exactly `Rules.REACH_BONUS`. 1.0 is an orthogonal neighbour,
## 1.41421 a diagonal one, and 2.0 is the first distance that must not reach.
func _reach_is_range_plus_bonus(t) -> void:
	var full := Rules.hp_of(Rules.BISON)
	var hit := full - Rules.damage_of(Rules.CELL_MELEE)
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
	var full := Rules.hp_of(Rules.BISON)
	var hit := full - Rules.damage_of(Rules.CELL_MELEE)
	var inside := _reach_probe(Rules.REACH_BONUS + 0.5 * Rules.EPS)
	t.eq(inside["hp"], hit, "사거리+엡실론 절반 안쪽은 때린다")
	t.eq(inside["moved"], 0.0, "그리고 한 발짝도 안 걸었다 — 이미 사거리 안이라는 뜻이다")

	var outside := _reach_probe(Rules.REACH_BONUS + 3.0 * Rules.EPS)
	t.ok(float(outside["moved"]) > 0.0,
			"사거리+엡실론 세 배 바깥은 사거리 밖이다 — 때리기 전에 걸어야 했다 (%.4f칸)"
			% float(outside["moved"]))
	# The ceiling: it walked ONE sub-step's worth and not to the target. Without it, "moved" is also
	# satisfied by a unit that teleported.
	t.ok(float(outside["moved"]) <= Rules.speed_of(Rules.CELL_MELEE) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
			"그리고 딱 한 서브스텝만큼만 걸었다")
	t.eq(outside["hp"], hit,
			"바깥이어도 그 한 발짝이 사거리 안으로 데려다줘서 같은 서브스텝에 때렸다 — 이동이 공격보다 먼저 돈다")
	t.eq(full - Rules.damage_of(Rules.CELL_MELEE), hit, "때린 값은 근접 한 방이다 (자가 점검)")


## One melee soldier `gap` tiles west of one bison, driven exactly one sub-step. Returns the bison's HP
## and how far the soldier moved — the two halves `_within` decides between.
func _reach_probe(gap: float) -> Dictionary:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.BISON, 12, 5)], 999.0)
	var start := Vector2(12.0 - gap, 5.0)
	_ashore(b, 0, start)
	b.begin_frame()
	b.step(TICK_ONE)
	return {"hp": b.enemy_hp[0], "moved": start.distance_to(b.soldier_pos[0])}


## Two identical melee soldiers 2.2 tiles from one bison, one of them wearing the beak. Reach without it
## is 1.5 and with it 2.5, so exactly one blow may land.
func _beak_adds_one_tile(t) -> void:
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	army.has_beak[1] = 1
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.BISON, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(12.0 - 2.2, 5.0))
	_ashore(b, 1, Vector2(12.0 + 2.2, 5.0))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.BISON) - Rules.damage_of(Rules.CELL_MELEE),
			"2.2 칸에서 부리 단 병사만 때렸다 — 부리는 사거리에 1.0 을 더한다")
	# Without this the silence of soldier 0 could just as well be "it never picked a target".
	t.eq(b.soldier_target[0], 0, "부리 없는 병사도 표적은 잡았다 — 못 때린 이유는 사거리다")


# -- area ------------------------------------------------------------------------------------------

## **Two sibling tiles, not one.** The orthogonal neighbour is 1.0 away and the diagonal one 1.41421, and
## the two area values in the table are 1.0 and 1.5 — a case with only one kind of sibling cannot tell
## them apart, so an area silently widened from 1.0 to 1.5 would stay green.
func _area_splash(t) -> void:
	# area 1.0 (the ranged cell): the orthogonal sibling burns, the diagonal one does not.
	var small := _army_of([Rules.CELL_RANGED])
	var b := _battle_of(_open(ARENA_W, ARENA_H), small, [
		_spawn(ARENA_W, Rules.BISON, 12, 5),   # primary, 4.0 from the soldier
		_spawn(ARENA_W, Rules.BISON, 13, 5),   # 1.0 from the primary
		_spawn(ARENA_W, Rules.BISON, 13, 6),   # 1.41421 from the primary
	], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	var full := Rules.hp_of(Rules.BISON)
	var splash := full - Rules.damage_of(Rules.CELL_RANGED)
	t.eq(b.soldier_target[0], 0, "광역 공격의 주 표적은 최근접이다")
	t.eq(b.enemy_hp[0], splash, "주 표적이 맞았다")
	t.eq(b.enemy_hp[1], splash, "반경 1.0 — 직교 1.0 칸의 형제도 맞았다")
	t.eq(b.enemy_hp[2], full, "반경 1.0 — 대각 1.41421 칸의 형제는 안 맞았다")

	# area 1.5 (the lion): now the diagonal sibling burns too.
	#
	# ⚠ **The lion declares before it strikes**, so one frame measures the telegraph and not the blow —
	# this block used to read the splash off a single `step` and went red the day `LION_WINDUP_SEC`
	# landed. Waiting the wind-up out is only sound because nobody walks while it runs: all three are
	# already inside their 1.5 reach and the lion is inside its own, so the distances the splash is
	# measured at are still the ones written below. The position checks after the wait are what hold
	# that — without them a soldier could drift and the two area values stop being distinguishable.
	var wide := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE, Rules.CELL_MELEE])
	var w := _battle_of(_open(ARENA_W, ARENA_H), wide, [_spawn(ARENA_W, Rules.LION, 12, 6)], 999.0)
	_ashore(w, 0, Vector2(12, 5))   # 1.0 from the lion
	_ashore(w, 1, Vector2(13, 5))   # 1.0 from soldier 0
	_ashore(w, 2, Vector2(13, 6))   # 1.41421 from soldier 0
	var whole := Rules.hp_of(Rules.CELL_MELEE)
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
	var army := _army_of([Rules.CELL_RANGED, Rules.CELL_MELEE])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.BISON, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(8, 5))
	_ashore(b, 1, Vector2(13, 5))
	b.begin_frame()
	b.step(TICK_ONE)
	t.eq(b.enemy_hp[0],
			Rules.hp_of(Rules.BISON) - Rules.damage_of(Rules.CELL_RANGED) - Rules.damage_of(Rules.CELL_MELEE),
			"원거리와 근접이 둘 다 들소를 때렸다 — 광역이 실제로 터졌다")
	t.eq(army.hp[1], Rules.hp_of(Rules.CELL_MELEE) - Rules.damage_of(Rules.BISON),
			"아군 오사 없음 — 광역 반경 안에 선 아군은 들소 몫만 잃었다")
	t.eq(army.hp[0], Rules.hp_of(Rules.CELL_RANGED), "쏜 병사 자신도 안 다쳤다")


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
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	army.hp[0] = 1.0
	var b := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.BISON, 13, 2)], 999.0)
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
	var next_island := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.BISON, 18, 9)], 999.0)
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
	var ferry_army := _army_of([Rules.CELL_MELEE])
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
	var first_army := _army_of([Rules.CELL_RANGED])
	var first := _battle_of(_lane(), first_army, [_spawn(LANE_W, Rules.LION, 18, 2)], 999.0)
	_ashore(first, 0, Vector2(2, 2))
	first.begin_frame()
	first.step(0.1)
	t.eq(first.soldier_target[0], 0, "첫 프레임에 표적을 잡았다")
	t.ok(first.soldier_pos[0].x > 2.0, "그리고 같은 프레임에 걸었다 — 타겟팅이 이동보다 먼저 돈다")

	# movement BEFORE attacks: the first blow lands the instant movement brings the target into reach.
	var full := Rules.hp_of(Rules.LION)
	t.eq(_lane_march(TICK_ONE), full, "처음엔 4.0 칸이라 못 때린다")
	t.eq(_lane_march(0.7), full - Rules.damage_of(Rules.CELL_MELEE),
			"걸어 들어간 그 프레임에 첫 발이 나간다 — 이동이 공격보다 먼저 돈다")

	# attacks BEFORE deaths: two units that finish each other off both land the blow.
	var trade_army := _army_of([Rules.CELL_MELEE])
	trade_army.hp[0] = Rules.damage_of(Rules.BISON)
	var trade := _battle_of(_lane(), trade_army, [_spawn(LANE_W, Rules.BISON, 13, 2)], 999.0)
	trade.enemy_hp[0] = Rules.damage_of(Rules.CELL_MELEE)
	_ashore(trade, 0, Vector2(12, 2))
	trade.begin_frame()
	trade.step(TICK_ONE)
	t.eq(trade.enemy_alive[0], 0, "동시에 끝난 교환 — 들소가 죽었다")
	t.eq(trade_army.alive[0], 0, "그리고 들소도 마지막 한 방을 쳤다 — 공격이 사망보다 먼저 돈다")

	# deaths BEFORE the clock, and WON before either loss: an island cleared on the expiring frame is a win.
	var wire_army := _army_of([Rules.CELL_MELEE])
	var wire := _battle_of(_lane(), wire_army, [_spawn(LANE_W, Rules.BISON, 13, 2)], 0.5)
	wire.enemy_hp[0] = Rules.damage_of(Rules.CELL_MELEE)
	_ashore(wire, 0, Vector2(12, 2))
	wire.begin_frame()
	wire.step(0.5)
	t.eq(wire.outcome(), Battle.Outcome.WON, "타이머가 끝나는 그 프레임에 비운 섬은 승리다")
	t.eq(wire.lose_reason(), Battle.Lose.NONE, "승리에는 패배 사유가 없다")

	# ... and the timeout arm is live, so the win above is not "the clock never fires".
	var late_army := _army_of([Rules.CELL_MELEE])
	var late := _battle_of(_lane(), late_army, [_spawn(LANE_W, Rules.BISON, 13, 2)], 0.5)
	_ashore(late, 0, Vector2(12, 2))
	late.begin_frame()
	late.step(0.5)
	t.eq(late.outcome(), Battle.Outcome.LOST, "적이 남은 채 시간이 끝나면 패배다")
	t.eq(late.lose_reason(), Battle.Lose.TIMEOUT, "패배 사유는 시간 초과다")


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
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], limit)
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
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 90.0)
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
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 90.0)
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
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	var b := _planning_battle_of(_port(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 90.0)
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
	var army := _army_of([Rules.CELL_RANGED, Rules.CELL_RANGED])
	var b := _planning_battle_of(_port(), army, [
		_spawn(ARENA_W, Rules.CROW, 3, 2),    # ~3.0 tiles from the boat 0.3s into a 1.33s crossing
		_spawn(ARENA_W, Rules.BISON, 7, 4),   # sees BOTH the boat and the ashore soldier below
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
	t.eq(army.hp[0], Rules.hp_of(Rules.CELL_RANGED) - Rules.damage_of(Rules.CROW),
			"까마귀가 배 위의 병사를 실제로 쐈다")
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.CROW), "배 위의 병사는 사거리 안이어도 못 때린다")
	t.ok(b.enemy_pos[1].distance_to(bison_start) > 0.1,
			"그리고 들소는 실제로 움직였다 (%.2f칸) — 배를 쫓다 얼어붙은 게 아니라는 증거다"
			% b.enemy_pos[1].distance_to(bison_start))
	t.ok(b.enemy_pos[1].distance_to(ashore_target) < ashore_target.distance_to(bison_start) - 0.3,
			"움직인 방향이 상륙한 병사 쪽이다 (남은 거리 %.2f칸, 시작 5.00칸) — 배 쪽으로 얼어붙지 않고 이름 붙은 그 칸을 향해 실제로 걸었다는 뜻이다"
			% b.enemy_pos[1].distance_to(ashore_target))


# -- fixtures --------------------------------------------------------------------------------------

## One melee soldier `offset` tiles from one bison, stepped once. Returns the bison's HP.
func _melee_probe(offset: Vector2, dt: float) -> float:
	var army := _army_of([Rules.CELL_MELEE])
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.BISON, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(12, 5) + offset)
	b.begin_frame()
	b.step(dt)
	return b.enemy_hp[0]


## A ranged soldier walking the lane at the lion from 16 tiles out. Returns where it ended up.
func _lane_approach(dt: float, frames: int) -> Dictionary:
	var army := _army_of([Rules.CELL_RANGED])
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
	var army := _army_of([Rules.CELL_MELEE])
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


func _army_of(types: Array) -> Army:
	var a := Army.new()
	for raw in types:
		a.add(int(raw))
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
