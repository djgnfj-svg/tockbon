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
## Two step sizes recur and both are deliberate:
##  · `TICK_STILL` (1e-5 s) is below `Rules.EPS`, so `_walk`'s `remaining > EPS` loop never turns and
##    **nobody moves at all** — an attack measured at that step size happened at the distance the fixture
##    wrote, not at some distance movement produced on the way.
##  · a real 0.1 s frame is used wherever the thing being measured IS movement.


## Below Rules.EPS on purpose. See the header.
const TICK_STILL := 1e-5

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
	b.step(TICK_STILL)
	t.eq(b.soldier_target[0], 1, "더 가까운 적을 고른다 (2칸 대 4칸)")

	# The near one dies; the next frame must hand the soldier the far one.
	b.enemy_hp[1] = 0.0
	b.begin_frame()
	b.step(TICK_STILL)
	t.eq(b.enemy_alive[1], 0, "가까운 적이 죽었다")
	b.begin_frame()
	b.step(TICK_STILL)
	t.eq(b.soldier_target[0], 0, "표적이 죽으면 남은 최근접으로 다시 고른다")

	var tie_army := _army_of([Rules.CELL_RANGED])
	var tied := _battle_of(_open(ARENA_W, ARENA_H), tie_army, [
		_spawn(ARENA_W, Rules.BISON, 12, 3),
		_spawn(ARENA_W, Rules.BISON, 12, 7),
	], 999.0)
	_ashore(tied, 0, Vector2(12, 5))
	tied.begin_frame()
	tied.step(TICK_STILL)
	t.eq(tied.soldier_target[0], 0, "거리가 같으면 id 가 작은 쪽을 고른다")


# -- reach -------------------------------------------------------------------------------------

## Melee range is 0, so its reach is exactly `Rules.REACH_BONUS`. 1.0 is an orthogonal neighbour,
## 1.41421 a diagonal one, and 2.0 is the first distance that must not reach.
func _reach_is_range_plus_bonus(t) -> void:
	var full := Rules.hp_of(Rules.BISON)
	var hit := full - Rules.damage_of(Rules.CELL_MELEE)
	t.eq(_melee_probe(Vector2(-1, 0), TICK_STILL), hit, "정확히 1.0 칸에서 때린다")
	t.eq(_melee_probe(Vector2(-1, -1), TICK_STILL), hit, "정확히 1.41421 칸(대각)에서도 때린다")
	t.eq(_melee_probe(Vector2(-2, 0), TICK_STILL), full, "2.0 칸에서는 못 때린다")


## The comparison is `<=` with `Rules.EPS` of slack, so half an epsilon past the reach still lands and
## three epsilons past it does not. Without the slack a diagonal — exactly sqrt(2) — is a coin flip.
func _epsilon_edge(t) -> void:
	var full := Rules.hp_of(Rules.BISON)
	var hit := full - Rules.damage_of(Rules.CELL_MELEE)
	var inside := Rules.REACH_BONUS + 0.5 * Rules.EPS
	var outside := Rules.REACH_BONUS + 3.0 * Rules.EPS
	t.eq(_melee_probe(Vector2(-inside, 0), TICK_STILL), hit, "사거리+엡실론 절반 안쪽은 때린다")
	t.eq(_melee_probe(Vector2(-outside, 0), TICK_STILL), full, "사거리+엡실론 세 배 바깥은 못 때린다")


## Two identical melee soldiers 2.2 tiles from one bison, one of them wearing the beak. Reach without it
## is 1.5 and with it 2.5, so exactly one blow may land.
func _beak_adds_one_tile(t) -> void:
	var army := _army_of([Rules.CELL_MELEE, Rules.CELL_MELEE])
	army.has_beak[1] = 1
	var b := _battle_of(_open(ARENA_W, ARENA_H), army, [_spawn(ARENA_W, Rules.BISON, 12, 5)], 999.0)
	_ashore(b, 0, Vector2(12.0 - 2.2, 5.0))
	_ashore(b, 1, Vector2(12.0 + 2.2, 5.0))
	b.begin_frame()
	b.step(TICK_STILL)
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
	b.step(TICK_STILL)
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
	w.step(TICK_STILL)
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
	b.step(TICK_STILL)
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
	b.step(TICK_STILL)
	t.eq(army.alive[0], 0, "1 HP 병사가 들소의 3 을 맞고 죽었다")
	t.eq(army.hp[0], 0.0, "죽은 병사의 HP 는 0 으로 잘린다 — 음수 잔액이 남지 않는다")
	t.eq(army.type_id.size(), 2, "죽어도 명부의 줄은 남는다")
	t.eq(b.soldier_state[0], Battle.SoldierState.DEAD, "이번 섬에서 DEAD 로 바뀌었다")
	t.eq(army.living_count(), 1, "살아 있는 병사는 한 명이다")

	var next_island := _battle_of(_lane(), army, [_spawn(LANE_W, Rules.BISON, 18, 2)], 999.0)
	t.eq(next_island.soldier_state[0], Battle.SoldierState.DEAD, "다음 섬에서도 예비가 아니라 DEAD 로 선다")
	t.ok(next_island.load_soldier(Rules.CELL_MELEE) >= 0, "살아남은 병사는 태워진다")
	var boarded: PackedInt32Array = next_island.pending[0]
	t.eq(int(boarded[0]), 1, "태워진 것은 살아남은 1번이다")
	t.ok(next_island.load_soldier(Rules.CELL_MELEE) < 0, "죽은 병사는 다시 태워지지 않는다")


# -- the phase order is a contract -----------------------------------------------------------------

## boats -> landings -> targeting -> movement -> attacks -> deaths -> clock, each seam measured by a
## consequence that only that order produces.
func _phase_order(t) -> void:
	# boats BEFORE landings: a crossing that completes this frame unloads this frame, not next.
	var ferry_army := _army_of([Rules.CELL_MELEE])
	var ferry := _battle_of(_port(), ferry_army, [_spawn(ARENA_W, Rules.LION, 20, 9)], 999.0)
	ferry.load_soldier(Rules.CELL_MELEE)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	t.ok(ferry.launch(0, landing), "부두 없는 항구에서도 배가 뜬다")
	# `Rules.CROSSING` is gone — a crossing's length is `boat.dist / boat.speed` now, read back off
	# the boat that was just launched rather than assumed.
	var cross_t: float = float(ferry.boats[0]["dist"]) / float(ferry.boats[0]["speed"])
	ferry.begin_frame()
	ferry.step(cross_t)
	t.eq(ferry.soldier_state[0], Battle.SoldierState.ASHORE,
			"배가 도착한 그 프레임에 내린다 — 보트가 상륙보다 먼저 돈다")

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
	t.eq(_lane_march(TICK_STILL), full, "처음엔 4.0 칸이라 못 때린다")
	t.eq(_lane_march(0.7), full - Rules.damage_of(Rules.CELL_MELEE),
			"걸어 들어간 그 프레임에 첫 발이 나간다 — 이동이 공격보다 먼저 돈다")

	# attacks BEFORE deaths: two units that finish each other off both land the blow.
	var trade_army := _army_of([Rules.CELL_MELEE])
	trade_army.hp[0] = Rules.damage_of(Rules.BISON)
	var trade := _battle_of(_lane(), trade_army, [_spawn(LANE_W, Rules.BISON, 13, 2)], 999.0)
	trade.enemy_hp[0] = Rules.damage_of(Rules.CELL_MELEE)
	_ashore(trade, 0, Vector2(12, 2))
	trade.begin_frame()
	trade.step(TICK_STILL)
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
	var b := _battle_of(_port(), army, [
		_spawn(ARENA_W, Rules.CROW, 3, 2),    # ~3.0 tiles from the boat 0.3s into a 1.33s crossing
		_spawn(ARENA_W, Rules.BISON, 7, 4),   # sees BOTH the boat and the ashore soldier below
	], 999.0)
	var ashore_target := Vector2(7, 9)   # 5.0 tiles from the bison, inside its detect 6 and the
	                                      # ranged soldier's own 5.5-tile reach of the bison — it stops
	_ashore(b, 1, ashore_target)
	var bison_start: Vector2 = b.enemy_pos[1]
	b.load_soldier(Rules.CELL_RANGED)
	var landing := int(_PORT_LANDING.y) * ARENA_W + int(_PORT_LANDING.x)
	b.launch(0, landing)
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
## `_PORT_LANDING` (6,5) are 4.0 tiles apart across open water the whole way, which is what makes
## `boat.dist` / `boat.speed` (never `Rules.CROSSING` — that constant is gone) the right way to time
## a crossing here.
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


func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
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
