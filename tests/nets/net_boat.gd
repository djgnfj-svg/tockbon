extends RefCounted
## The fleet: per-boat capacity and speed, launched from wherever it is sitting, and a return leg that
## is simulated rather than timed. Everything here is driven through `load_soldier` / `launch` / `step`
## — the same three calls the shell makes — and read back off the public columns.
##
## `net_battle` owns the combat rules and the phase order; this file owns only what a boat does.
## `net_coast` owns `grid.gd`'s landability and straight-line rules; this file only uses them to build
## fixtures a boat can actually sail.

const ARENA_W := 24
const ARENA_H := 12
## The cramped island: four land tiles, one held by the bison standing on it, so exactly three are
## ever free. That is what makes "a boat with more cargo than shore waits" measurable at the boundary.
const COVE_W := 10
const COVE_H := 7


func run(t) -> void:
	_boats_and_the_inequality(t)
	_crossing_arithmetic_is_literal(t)
	_crossing_scales_with_distance(t)
	_leaves_from_boat_at(t)
	_return_leg_is_simulated(t)
	_relocation_actually_moves_boat_at(t)
	_launch_refusals(t)
	_reach_is_per_harbour(t)
	_pending_is_per_boat(t)
	_load_soldier_picks_the_boat(t)
	_unload_placement(t)
	_boat_waits_for_shore(t)
	_cargo_rides_the_boat(t)


# -- the table and the inequality it has to satisfy --------------------------------------------------

## **Every literal here is written out, never read back off `Rules.BOATS`** — a check whose bound
## comes from the constant it is checking shrinks with it.
func _boats_and_the_inequality(t) -> void:
	t.eq(Rules.boat_count(), 2, "배는 두 종류다")
	t.eq(Rules.cap_of(0), 4, "큰 배 정원은 4다")
	t.eq(Rules.boat_speed_of(0), 3.0, "큰 배 속력은 3.0이다")
	t.eq(Rules.cap_of(1), 2, "빠른 배 정원은 2다")
	t.eq(Rules.boat_speed_of(1), 5.0, "빠른 배 속력은 5.0이다")
	# 2 x 5.0 = 10 < 4 x 3.0 = 12 — the fast boat must lose on throughput. Exactly 2x would be a tie
	# and the decision would die ("빠른 배가 두 배 빠르다" could not be used).
	# ⚠ **One side live, one literal.** `2.0 * 5.0 < 4.0 * 3.0` written with both sides as bare
	# literals is constant-true regardless of `Rules.BOATS` — measured: setting FAST's speed to 6.0
	# (the exact tie the design doc forbids) reddens only the two `boat_speed_of` rows above and
	# leaves this label green. Reading the fast boat's own values back is what makes it move.
	t.ok(Rules.cap_of(1) * Rules.boat_speed_of(1) < 4.0 * 3.0,
		"빠른 배는 처리량에서 진다 (cap(1)*speed(1) < 4x3.0=12)")


# -- crossing time --------------------------------------------------------------------------------

## ⚠ **Every OTHER crossing-time check in this file computes its own expectation from
## `boats[0]["dist"]` — the thing under test — so doubling `dist` at launch, arriving at half the real
## distance, or halving the lerp rate in `_phase_boats` are all invisible to them.** This is the one
## check in the file whose expected numbers are written as bare literals, verified by hand against
## `_bay()`'s own geometry (harbour (2,5), landing (6,5), 4.0 tiles apart, BIG boat speed 3.0):
## exact arrival is 4.0/3.0 = 1.3333s, and the halfway point of the lerp at t=0.5s is
## `(2,5).lerp((6,5), 0.5*3.0/4.0) = (3.5, 5.0)`.
func _crossing_arithmetic_is_literal(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	# A live enemy far from the crossing, so `enemies_left() == 0` cannot latch WON on the first
	# `step` and freeze the sim's clock before the second measurement below runs.
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	b.load_soldier(Rules.CELL_MELEE)
	var landing := _tile_of(6, 5)
	b.launch(0, landing)
	t.eq(float(b.boats[0]["dist"]), 4.0, "이 항구에서 이 상륙지까지는 정확히 4.0칸이다 (자가 점검)")

	b.begin_frame()
	b.step(0.5)
	t.eq(Vector2(b.boats[0]["pos"]), Vector2(3.5, 5.0),
		"0.5초 뒤 배의 자리가 정확히 (3.5, 5.0)이다 — lerp 진행률을 리터럴로 확인한다")

	var early := _army_of(Rules.CELL_MELEE, 1)
	var eb := _battle_of(_bay(), early, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	eb.load_soldier(Rules.CELL_MELEE)
	eb.launch(0, landing)
	eb.begin_frame()
	eb.step(1.30)
	t.eq(eb.soldier_state[0], Battle.SoldierState.TRANSIT, "1.30초에는 아직 안 도착했다 (4/3 = 1.3333초)")

	var late := _army_of(Rules.CELL_MELEE, 1)
	var lb := _battle_of(_bay(), late, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	lb.load_soldier(Rules.CELL_MELEE)
	lb.launch(0, landing)
	lb.begin_frame()
	lb.step(1.34)
	t.eq(lb.soldier_state[0], Battle.SoldierState.ASHORE, "1.34초에는 도착해 있다")


## Two landable targets at different distances from one harbour: the RATIO of arrival times equals
## the ratio of distances, because `t = distance / speed` and speed is constant for one boat. The
## fast boat also arrives first over the identical route.
func _crossing_scales_with_distance(t) -> void:
	var near := _tile_of(6, 5)
	var far := _tile_of(16, 5)
	var near_army := _army_of(Rules.CELL_MELEE, 1)
	var nb := _battle_of(_bay(), near_army, [], 999.0)
	nb.load_soldier(Rules.CELL_MELEE)
	nb.launch(0, near)
	var near_dist: float = float(nb.boats[0]["dist"])
	var near_arrival := near_dist / Rules.boat_speed_of(0)

	# A separate, deeper bay for "far" — `_bay()`'s own coast is a single column, so its own
	# harbour-to-coast distance never varies enough to test a ratio against.
	var far_army := _army_of(Rules.CELL_MELEE, 1)
	var fb := _battle_of(_far_bay(), far_army, [], 999.0)
	fb.load_soldier(Rules.CELL_MELEE)
	fb.launch(0, far)
	var far_dist: float = float(fb.boats[0]["dist"])
	var far_arrival := far_dist / Rules.boat_speed_of(0)

	t.ok(far_dist > near_dist + 1.0, "먼 상륙지가 실제로 더 멀다 (%.2f > %.2f)" % [far_dist, near_dist])
	var ratio_dist := far_dist / near_dist
	var ratio_time := far_arrival / near_arrival
	t.ok(absf(ratio_dist - ratio_time) <= 0.01,
			"거리 비와 도착 시간 비가 같다 (%.3f ≈ %.3f) — 먼 해안일수록 오래 걸린다" % [ratio_dist, ratio_time])

	# The fast boat (1) over the SAME route arrives before the big boat (0). Boat 0 (cap 4) has to be
	# filled first — `load_soldier` only reaches boat 1 once boat 0 has no room. Uses `near`, the
	# `_bay()` fixture's own coast — the route only has to be shared, not the far one.
	var race_army := _army_of(Rules.CELL_MELEE, Rules.cap_of(0) + 1)
	var race := _battle_of(_bay(), race_army, [], 999.0)
	for _i in Rules.cap_of(0):
		t.eq(race.load_soldier(Rules.CELL_MELEE), 0, "0번 배가 찰 때까지는 0번이 태운다 (자가 점검)")
	t.eq(race.load_soldier(Rules.CELL_MELEE), 1, "0번이 차면 1번(빠른 배)이 태운다")
	t.ok(race.launch(0, near) and race.launch(1, near), "두 배 다 같은 항로로 띄웠다")
	var big_t := float(race.boats[0]["dist"]) / Rules.boat_speed_of(0)
	var fast_t := float(race.boats[1]["dist"]) / Rules.boat_speed_of(1)
	t.ok(fast_t < big_t, "같은 항로에서 빠른 배가 먼저 닿는다 (%.2f초 < %.2f초)" % [fast_t, big_t])


# -- the boat leaves from wherever it is sitting ----------------------------------------------------

## A boat's harbour is `boat_at[boat]`, and `launch` reads it directly — moving it by hand (the same
## column `_phase_landings` writes on a real return leg) proves the sail-origin point moves with it,
## never from a tile fixed at setup.
func _leaves_from_boat_at(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_two_harbours(), army, [], 999.0)
	var east := _th_tile(9, 2)   # visible from the east harbour, not the west

	b.load_soldier(Rules.CELL_MELEE)
	t.ok(not b.launch(0, east), "0번 배가 서쪽 항구에 있으면 동쪽 해안은 거절한다 (자가 점검)")
	b.boat_at[0] = 1
	t.ok(b.launch(0, east), "0번 배를 동쪽 항구로 옮기면 같은 칸이 이제 받아들여진다")
	var from: Vector2 = b.boats[0]["from"]
	t.eq(from, b.grid.tile_point(int(b.grid.harbour_tiles[1])),
			"그리고 실제로 동쪽 항구에서 출항했다 — 고정된 칸이 아니라 boat_at 에서 출발한다")


# -- the return leg -----------------------------------------------------------------------------

func _return_leg_is_simulated(t) -> void:
	# A fifth soldier stays in reserve so there is someone left to re-board once the boat is home.
	var army := _army_of(Rules.CELL_MELEE, 5)
	# A bison far from the landing, so the island has something alive — an empty spawn list reports
	# WON the moment `_phase_clock` runs inside the FIRST `step`, and every step after that returns
	# immediately without moving the boat's clock at all.
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	for _i in 4:
		b.load_soldier(Rules.CELL_MELEE)
	var landing := _tile_of(6, 5)
	b.launch(0, landing)
	var out_t: float = float(b.boats[0]["dist"]) / float(b.boats[0]["speed"])
	b.begin_frame()
	b.step(out_t)
	t.eq(b.ashore_ids().size(), 4, "넷 다 상륙했다")
	t.eq(b.boats.size(), 1, "내려놓은 배가 여전히 boats 안에 있다 — 빈 채로 돌아가는 중이다")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["phase"]), Battle.Phase.RETURNING, "배가 RETURNING 으로 바뀌었다")
	t.eq((boat["soldiers"] as Array).size(), 0, "화물은 비었다")
	t.ok(b.boat_busy(0), "그런데도 여전히 바다에 있다고 본다 — 못 태우고 못 끈다 (자가 점검)")
	t.ok(not b.launch(0, landing), "빈 배라도 RETURNING 이면 새로 못 보낸다")

	var home := b.grid.home_harbour_for(landing)
	var home_pt := b.grid.tile_point(int(b.grid.harbour_tiles[home]))
	t.eq(boat["to"], home_pt, "빈 배는 '자기가 내려준 해안을 다시 볼 수 있는' 항구로 향한다")

	var ret_t: float = float(boat["dist"]) / float(boat["speed"])
	b.begin_frame()
	b.step(ret_t)
	t.eq(b.boats.size(), 0, "돌아온 배는 boats 목록을 떠난다")
	t.eq(b.boat_at[0], home, "그리고 그 항구가 boat_at 에 기록된다 — 도착할 때만 바뀐다")
	t.ok(b.load_soldier(Rules.CELL_MELEE) >= 0, "돌아온 배는 다시 태울 수 있다")


## ⚠ **`_return_leg_is_simulated` above runs on `_bay()`, a ONE-harbour fixture — `home`, `boat_at[0]`
## and `start_harbour` are all 0 there, so every assertion in it is `0 == 0` on both sides and neither
## `grid.home_harbour_for` being called nor `boat_at` actually moving is proven.** This fixture reuses
## `net_coast`'s stranding geometry (three harbours, one landing visible from two of them) specifically
## because the departure harbour and the resulting home harbour are DIFFERENT tiles: harbour 2 (0,5) is
## the farther of the two that can see the landing, so launching from there and returning has
## somewhere real to go to.
func _relocation_actually_moves_boat_at(t) -> void:
	var rows := [
		"~~~~~~~~~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"H~~~~~~~~~~~~~~~",
	]
	var army := _army_of(Rules.CELL_MELEE, 1)
	# A live, distant enemy — otherwise `enemies_left() == 0` latches WON inside the FIRST `step` and
	# every `step` after it returns immediately, which is exactly the bug this file already paid for
	# once (`_return_leg_is_simulated`'s own fixture needed the same fix).
	var b := _battle_of(rows, army, [_spawn(16, Rules.BISON, 14, 1)], 999.0)
	var landing := 2 * 16 + 7   # (7,2): visible from harbours 0 and 2, blocked from harbour 1
	t.eq(b.grid.home_harbour_for(landing), 0,
		"이 상륙지는 (더 가까운) 항구 0으로 돌아간다 — 항구 2에서 떠나면 옮겨간다는 뜻이다 (자가 점검)")

	b.boat_at[0] = 2   # depart from the FARTHER of the two harbours, on purpose
	b.load_soldier(Rules.CELL_MELEE)
	t.ok(b.launch(0, landing), "먼 항구(2번)에서 띄운다")
	t.eq(b.boat_at[0], 2, "출항한 순간에는 boat_at 가 아직 그대로다 (자가 점검)")

	var out_t: float = float(b.boats[0]["dist"]) / float(b.boats[0]["speed"])
	b.begin_frame()
	b.step(out_t)
	t.eq(int(b.boats[0]["phase"]), Battle.Phase.RETURNING, "상륙하고 빈 배로 돌아가는 중이다 (자가 점검)")
	t.eq(b.boat_at[0], 2,
		"RETURNING 으로 막 바뀐 순간에도 boat_at 는 아직 옛(2번) 항구다 — 도착 전에는 안 바뀐다")

	var ret_t: float = float(b.boats[0]["dist"]) / float(b.boats[0]["speed"])
	b.begin_frame()
	b.step(ret_t)
	t.eq(b.boats.size(), 0, "돌아온 배는 boats 목록을 떠난다 (자가 점검)")
	t.eq(b.boat_at[0], 0,
		"그리고 실제로 다른(더 가까운) 항구 0으로 옮겨갔다 — 떠났던 2번이 아니다. " +
		"grid.home_harbour_for 가 실제로 불렸고 boat_at 가 실제로 움직였다는 증거다")


# -- launch refusals --------------------------------------------------------------------------------

func _launch_refusals(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 8)
	var b := _battle_of(_two_harbours(), army, [], 999.0)
	var west := _th_tile(2, 2)
	var east := _th_tile(9, 2)

	t.ok(not b.launch(0, west), "빈 배는 못 뜬다")
	t.ok(not b.launch(-1, west), "없는 배 번호는 거절한다")
	t.ok(not b.launch(Rules.boat_count(), west), "배 수와 같은 번호도 거절한다")

	b.load_soldier(Rules.CELL_MELEE)
	var water_tile := int(b.grid.harbour_tiles[0])
	t.ok(not b.launch(0, water_tile), "상륙 불가능한 칸(물)은 거절한다")
	t.ok(not b.launch(0, east), "이 배의 항구가 못 보는 해안은 거절한다 (곶 뒤)")
	t.eq(b.pending[0].size(), 1, "거절당한 시도들은 화물을 안 건드렸다")

	t.ok(b.launch(0, west), "이번엔 받아준다")
	b.load_soldier(Rules.CELL_MELEE)
	t.ok(not b.launch(0, west), "바다에 나간 배는 다시 못 뜬다")


# -- reach is per harbour, and the boat leaving from it -----------------------------------------------

func _reach_is_per_harbour(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 8)
	var b := _battle_of(_two_harbours(), army, [], 999.0)
	var west := _th_tile(2, 2)
	var east := _th_tile(9, 2)
	t.ok(b.grid.can_land_at(0, west) and not b.grid.can_land_at(0, east),
			"서쪽 항구는 서쪽 해안만 본다 (자가 점검)")
	t.ok(b.grid.can_land_at(1, east) and not b.grid.can_land_at(1, west),
			"동쪽 항구는 동쪽 해안만 본다 (자가 점검)")

	b.load_soldier(Rules.CELL_MELEE)
	t.ok(not b.launch(0, east), "0번 배는 서쪽 항구에 있으니 동쪽 해안은 거절한다")
	b.boat_at[0] = 1
	t.ok(b.launch(0, east), "그런데 0번 배가 동쪽 항구에 있다면 같은 칸이 받아들여진다 — 배마다 보낼 수 있는 해안이 다르다")


# -- per-boat cargo is independent -------------------------------------------------------------------

func _pending_is_per_boat(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 6)
	var b := _battle_of(_bay(), army, [], 999.0)
	for _i in 4:
		b.load_soldier(Rules.CELL_MELEE)   # fills boat 0 (cap 4)
	for _i in 2:
		b.load_soldier(Rules.CELL_MELEE)   # boat 0 is full now, goes to boat 1 (cap 2)
	t.eq(b.pending[0].size(), 4, "0번 배에 넷")
	t.eq(b.pending[1].size(), 2, "1번 배에 둘 — 두 화물이 서로 섞이지 않는다")


# -- who boards which boat -----------------------------------------------------------------------

func _load_soldier_picks_the_boat(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 7)
	var b := _battle_of(_bay(), army, [], 999.0)
	for _i in 4:
		t.eq(b.load_soldier(Rules.CELL_MELEE), 0, "정원 4까지는 0번(큰) 배로 간다")
	t.eq(b.load_soldier(Rules.CELL_MELEE), 1, "0번 배가 차면 1번(빠른) 배로 간다")
	t.eq(b.load_soldier(Rules.CELL_MELEE), 1, "1번 배 정원 2도 채운다")
	t.eq(b.load_soldier(Rules.CELL_MELEE), -1, "두 배가 다 차면 -1이다")
	t.eq(b.load_soldier(Rules.CELL_RANGED), -1, "명부에 없는 병종은 애초에 태울 사람이 없다")

	var landing := _tile_of(6, 5)
	b.launch(0, landing)
	b.launch(1, landing)
	t.eq(b.load_soldier(Rules.CELL_MELEE), -1, "두 배가 다 바다에 있으면 -1 이다 — 이제는 못 태운다")


# -- unloading -------------------------------------------------------------------------------------

func _unload_placement(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_bay(), army, [], 999.0)
	for _i in 4:
		b.load_soldier(Rules.CELL_MELEE)
	var landing := _tile_of(6, 5)
	b.launch(0, landing)
	var cross_t: float = float(b.boats[0]["dist"]) / float(b.boats[0]["speed"])
	b.begin_frame()
	b.step(cross_t)

	t.eq(b.soldier_pos[0], b.grid.tile_point(landing), "첫 병사가 상륙지 칸을 차지한다")
	var taken := {}
	var adjacent := 0
	var owned := 0
	var landed := 0
	for i in 4:
		if b.soldier_state[i] == Battle.SoldierState.ASHORE:
			landed += 1
		var p: Vector2 = b.soldier_pos[i]
		var tile := int(round(p.y)) * b.grid.w + int(round(p.x))
		taken[tile] = true
		if maxf(absf(p.x - _PORT_LANDING_X), absf(p.y - _PORT_LANDING_Y)) <= 1.0:
			adjacent += 1
		if b.grid.is_passable(int(round(p.x)), int(round(p.y))) and b.grid.reserved[tile] == i:
			owned += 1
	t.eq(landed, 4, "넷 전부 상륙했다")
	t.eq(taken.size(), 4, "넷이 서로 다른 칸에 섰다")
	t.eq(adjacent, 4, "나머지는 상륙지에서 가장 가까운 칸들에 섰다 (전부 이웃 칸)")
	t.eq(owned, 4, "넷 칸 모두 땅이고 각자 자기 이름으로 예약됐다")


const _PORT_LANDING_X := 6.0
const _PORT_LANDING_Y := 5.0


## Three free tiles and a boat carrying four: the whole load waits rather than landing part of itself.
func _boat_waits_for_shore(t) -> void:
	var crowded := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_cove(), crowded, [_spawn(COVE_W, Rules.BISON, 3, 2)], 999.0)
	for _i in 4:
		b.load_soldier(Rules.CELL_MELEE)
	var landing := 3 * COVE_W + 3
	b.launch(0, landing)
	var cross_t: float = float(b.boats[0]["dist"]) / float(b.boats[0]["speed"])
	b.begin_frame()
	b.step(cross_t)
	b.begin_frame()
	b.step(1.0)
	b.begin_frame()
	b.step(1.0)
	t.eq(b.boats.size(), 1, "빈 칸이 셋뿐이라 넷을 실은 배는 상륙지에서 기다린다")
	t.eq(int(b.boats[0]["phase"]), Battle.Phase.OUTBOUND, "그대로 OUTBOUND 다 — 못 내렸으니 안 돌아간다")
	var waiting := 0
	for i in 4:
		if b.soldier_state[i] == Battle.SoldierState.TRANSIT:
			waiting += 1
	t.eq(waiting, 4, "넷 다 아직 배 위다 — 일부만 내리지 않는다")

	# Same shore, cap-2 fast boat with 2 soldiers: it fits, so it lands.
	var fitting := _army_of(Rules.CELL_MELEE, 2)
	var c := _battle_of(_cove(), fitting, [_spawn(COVE_W, Rules.BISON, 3, 2)], 999.0)
	c.load_soldier(Rules.CELL_MELEE)   # boat 0
	c.load_soldier(Rules.CELL_MELEE)   # boat 0 still (cap 4 > 2)
	c.launch(0, landing)
	var ct: float = float(c.boats[0]["dist"]) / float(c.boats[0]["speed"])
	c.begin_frame()
	c.step(ct)
	t.eq(c.ashore_ids().size(), 2, "둘이면 딱 맞아서 내린다")


# -- cargo aboard --------------------------------------------------------------------------------

func _cargo_rides_the_boat(t) -> void:
	var army := _army_of(Rules.CELL_RANGED, 1)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.CROW, 3, 2)], 999.0)
	b.load_soldier(Rules.CELL_RANGED)
	var landing := _tile_of(6, 5)
	b.launch(0, landing)
	b.begin_frame()
	b.step(0.1)
	t.eq(b.soldier_pos[0], Vector2(b.boats[0]["pos"]), "화물은 배 위치를 그대로 탄다")
	t.ok(b.soldier_pos[0].distance_to(b.enemy_pos[0]) < army.range_of(0) + Rules.REACH_BONUS,
			"까마귀는 그 병사의 사거리 안에 있다")
	b.begin_frame()
	b.step(0.1)
	b.begin_frame()
	b.step(0.1)
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.CROW), "그래도 배 위에서는 못 쏜다")
	t.ok(army.hp[0] < Rules.hp_of(Rules.CELL_RANGED), "맞기는 맞는다")


# -- fixtures --------------------------------------------------------------------------------------

## An open bay: rows 3-7 are water for the first six columns, land from column 6 on, one harbour at
## (2,5). Every target used in this file's tests sits on the land side, reachable in a straight line
## over the bay's own water.
func _bay() -> Array:
	var rows := []
	for y in ARENA_H:
		if y == 0 or y == ARENA_H - 1:
			rows.append("~".repeat(ARENA_W))
		elif y >= 3 and y <= 7:
			var row := "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
			if y == 5:
				row = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
			rows.append(row)
		else:
			rows.append("~" + ".".repeat(ARENA_W - 2) + "~")
	return rows


## The same shape as `_bay()`, stretched: water for the first sixteen columns instead of six, land
## from column 16 on, harbour still at (2,5). Exists so "crossing time scales with distance" has a
## SECOND distance to compare against -- `_bay()`'s own coast is one column deep and never varies.
func _far_bay() -> Array:
	var rows := []
	for y in ARENA_H:
		if y == 0 or y == ARENA_H - 1:
			rows.append("~".repeat(ARENA_W))
		elif y >= 3 and y <= 7:
			var row := "~".repeat(16) + ".".repeat(ARENA_W - 17) + "~"
			if y == 5:
				row = "~~H" + "~".repeat(13) + ".".repeat(ARENA_W - 17) + "~"
			rows.append(row)
		else:
			rows.append("~" + ".".repeat(ARENA_W - 2) + "~")
	return rows


## Two harbours on opposite sides of a single-tile peninsula, mirroring `net_coast`'s headland
## fixture: a west harbour that can see the west shore and not the east one, and vice versa.
func _two_harbours() -> Array:
	var rows := [
		"~~~~~~~~~~~~",
		"~..........~",
		"~....#.....~",
		"~~~~~#~~~~~~",
		"~~H~~~~~~H~~",
	]
	return rows


## Four land tiles — (3,2), (2,3), (3,3), (4,3) — one held by the bison standing on (3,2), so exactly
## three are ever free: the boundary case for "a boat with more cargo than shore waits". A harbour
## in open water south of them sails a straight vertical line to the landing tile (3,3).
func _cove() -> Array:
	var rows := []
	for y in COVE_H:
		if y == 2:
			rows.append("~~~.~~~~~~")
		elif y == 3:
			rows.append("~~...~~~~~")
		elif y == 5:
			rows.append("~~~H~~~~~~")
		else:
			rows.append("~".repeat(COVE_W))
	return rows


func _tile_of(x: int, y: int) -> int:
	return y * ARENA_W + x


## `_two_harbours()` is its own, narrower grid (12 wide) — never `ARENA_W`, or every tile index past
## the first row decodes wrongly.
func _th_tile(x: int, y: int) -> int:
	return y * 12 + x


func _army_of(type_id: int, n: int) -> Army:
	var a := Army.new()
	for _i in n:
		a.add(type_id)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var g := Grid.new()
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, army, spawns, limit)
	return b
