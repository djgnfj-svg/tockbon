extends RefCounted
## What a boat does. **There is no fleet any more** — `plan-then-watch`'s 결정 14R deletes the boat
## table whole, and a boat is created by one drop, carries the one soldier that was dropped, sails,
## unloads and sails home to nothing. So this file measures a crossing, a landing and a round trip,
## and nothing about capacity, boat identity or a count.
##
## Everything is driven through `send` / `commit` / `step` — the same calls the shell makes — and read
## back off the public columns. `net_plan` owns the planning state and the speed ladder; `net_battle`
## owns the combat rules and the phase order; `net_coast` owns `grid.gd`'s landability. This file only
## uses those to build fixtures a boat can actually sail.
##
## ⚠ **Every crossing here is driven one `Rules.SIM_SUBSTEP_SEC` at a time and counted.** A single
## `step(dist / speed)` looks tidier and is a worse instrument: `step` consumes whole sub-steps and
## carries the leftover, so the number of phase passes one coarse call makes is itself a thing under
## test — and a loop with a counter is the only shape that can say a crossing took the time it did
## rather than that it eventually happened.

const ARENA_W := 24
const ARENA_H := 12
## The cramped island: four land tiles, one held by the bison standing on it, so exactly three are
## ever free. With one soldier per boat that makes "a fourth boat waits rather than landing on top of
## somebody" measurable at the boundary.
const COVE_W := 10
const COVE_H := 7

## The bay's crossing, by hand off `_bay()`'s own geometry: harbour (2,5) to landing (6,5) is 4.0
## tiles, `Rules.BOAT_SPEED` is 4.0 tiles/s, so arrival is at exactly 1.0 s = 60 sub-steps.
const BAY_DIST := 4.0
const BAY_SUBSTEPS := 60
## `_far_bay()`'s crossing: the same harbour to (16,5) is 14.0 tiles = 210 sub-steps, and 210 / 60 is
## exactly 3.5, the same ratio as 14.0 / 4.0.
const FAR_DIST := 14.0
const FAR_SUBSTEPS := 210

const FULL_ROSTER := 13


func run(t) -> void:
	_the_one_surviving_number(t)
	_crossing_arithmetic_is_literal(t)
	_crossing_scales_with_distance(t)
	_boats_do_not_share(t)
	_return_leg_is_simulated(t)
	_relocation_sends_the_boat_to_the_right_harbour(t)
	_send_refusals(t)
	_reach_is_per_harbour(t)
	_unload_placement(t)
	_boat_waits_for_shore(t)
	_cargo_rides_the_boat(t)


# -- the one number left of the old table ------------------------------------------------------------

## `Rules.BOATS` and its four accessors are deleted whole (`plan-then-watch`, 3.1): with unlimited
## boats there is no capacity column, no name column and no count. **The literal is written out, never
## read back off the constant it checks.**
func _the_one_surviving_number(t) -> void:
	t.eq(Rules.BOAT_SPEED, 4.0, "배 속력은 4.0 이다")


# -- crossing time ----------------------------------------------------------------------------------

## ⚠ **Every other crossing check in this file computes its expectation from `boats[0]["dist"]` — the
## thing under test — so doubling `dist` at `send`, arriving at half the real distance, or halving the
## lerp rate in `_phase_boats` are all invisible to them.** This is the one check whose numbers are
## bare literals, verified by hand against `_bay()`'s geometry.
func _crossing_arithmetic_is_literal(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	# A live enemy far from the crossing, or `enemies_left() == 0` latches WON on the first sub-step
	# and every step after it returns before the boat has moved.
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	var landing := _tile_of(6, 5)
	t.ok(b.send(0, landing) >= 0 and b.commit(), "한 척을 보내고 확정했다 (자가 점검)")
	t.eq(float(b.boats[0]["dist"]), BAY_DIST, "이 항구에서 이 상륙지까지는 정확히 4.0칸이다 (자가 점검)")

	_drive(b, BAY_SUBSTEPS / 2)
	var half: Vector2 = b.boats[0]["pos"]
	t.ok(Vector2(4.0, 5.0).distance_to(half) <= Rules.EPS,
			"0.5초(30 서브스텝) 뒤 배의 자리가 정확히 (4.0, 5.0)이다 — lerp 진행률을 리터럴로 확인한다")

	_drive(b, BAY_SUBSTEPS / 2 - 1)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT,
			"59 서브스텝(0.9833초)에는 아직 안 도착했다 — 4.0/4.0 = 1.0초다")
	_drive(b, 1)
	t.eq(b.soldier_state[0], Battle.SoldierState.ASHORE, "60 서브스텝(1.0초)에는 도착해 있다")


## Two landable targets at different distances from one harbour: the ratio of the arrival TIMES equals
## the ratio of the distances, because `t = distance / speed` and there is only one speed now.
func _crossing_scales_with_distance(t) -> void:
	var near_army := _army_of(Rules.CELL_MELEE, 1)
	var nb := _battle_of(_bay(), near_army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	t.ok(nb.send(0, _tile_of(6, 5)) >= 0 and nb.commit(), "가까운 해안으로 보냈다 (자가 점검)")
	var near_steps := _drive_until_ashore(t, nb, 0, "가까운 해안")

	# A separate, deeper bay — `_bay()`'s own coast is a single column, so its harbour-to-coast
	# distance never varies enough to test a ratio against.
	var far_army := _army_of(Rules.CELL_MELEE, 1)
	var fb := _battle_of(_far_bay(), far_army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	t.ok(fb.send(0, _tile_of(16, 5)) >= 0 and fb.commit(), "먼 해안으로 보냈다 (자가 점검)")
	var far_steps := _drive_until_ashore(t, fb, 0, "먼 해안")

	t.eq(float(nb.boats[0]["dist"]) if nb.boats.size() > 0 else BAY_DIST, BAY_DIST,
			"가까운 항로는 4.0칸이다 (자가 점검)")
	t.eq(float(fb.boats[0]["dist"]) if fb.boats.size() > 0 else FAR_DIST, FAR_DIST,
			"먼 항로는 14.0칸이다 (자가 점검)")
	t.eq(near_steps, BAY_SUBSTEPS, "가까운 해안은 60 서브스텝 걸린다")
	t.eq(far_steps, FAR_SUBSTEPS, "먼 해안일수록 오래 걸린다 — 210 서브스텝이다")
	t.ok(absf(float(far_steps) / float(near_steps) - FAR_DIST / BAY_DIST) <= 0.01,
			"걸린 시간의 비가 거리의 비와 같다 (3.5배)")


# -- thirteen boats, one soldier each ------------------------------------------------------------

func _boats_do_not_share(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, FULL_ROSTER)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	var landing := _tile_of(6, 5)
	var made := 0
	for i in FULL_ROSTER:
		if b.send(i, landing) >= 0:
			made += 1
	t.eq(made, FULL_ROSTER, "열세 척을 만들었다")
	t.eq(b.boats.size(), FULL_ROSTER, "열세 척이 동시에 바다에 떠 있다")
	var singles := 0
	var uids := {}
	for raw in b.boats:
		var boat: Dictionary = raw
		if (boat["soldiers"] as Array).size() == 1:
			singles += 1
		uids[int(boat["uid"])] = true
	t.eq(singles, FULL_ROSTER, "배 한 척에 한 명이다")
	t.eq(uids.size(), FULL_ROSTER, "배마다 번호가 다르다")


# -- the return leg -----------------------------------------------------------------------------

func _return_leg_is_simulated(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	var landing := _tile_of(6, 5)
	var uid := b.send(0, landing)
	t.ok(uid >= 0 and b.commit(), "한 척을 보내고 확정했다 (자가 점검)")
	_drive_until_ashore(t, b, 0, "왕복 시험")

	t.eq(b.boats.size(), 1, "내려놓은 배가 여전히 boats 안에 있다 — 빈 채로 돌아가는 중이다")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["phase"]), Battle.Phase.RETURNING, "배가 RETURNING 으로 바뀌었다")
	t.eq((boat["soldiers"] as Array).size(), 0, "화물은 비었다")
	var home := b.grid.home_harbour_for(landing)
	t.eq(Vector2(boat["to"]), b.grid.tile_point(int(b.grid.harbour_tiles[home])),
			"빈 배는 '자기가 내려준 해안을 다시 볼 수 있는' 항구로 향한다")

	# The floor for the leg: it is SAILED, not skipped. Without it "boats is empty at the end" is also
	# satisfied by a boat deleted on the unload sub-step.
	_drive(b, 1)
	t.ok(float((b.boats[0] as Dictionary)["t"]) > 0.0, "돌아가는 다리도 실제로 항해한다")

	var back := 0
	while back < 600 and not b.boats.is_empty():
		_drive(b, 1)
		back += 1
	t.ok(back > 1 and back < 600, "%d 서브스텝 걸려서 돌아왔다 (자가 점검)" % back)
	t.eq(b.boats.size(), 0, "내려놓은 배는 빈 채로 항구까지 돌아가고 나서 사라진다")


## ⚠ **`_return_leg_is_simulated` above runs on a ONE-harbour fixture, where `home`, `start_harbour`
## and 0 are all the same number and every comparison reads `0 == 0`.** This one has three harbours and
## a landing whose home harbour is neither the start harbour nor the nearest harbour outright — the
## `can_land_at` filter is what picks it, and this is what proves the filter runs.
func _relocation_sends_the_boat_to_the_right_harbour(t) -> void:
	var rows := [
		"~~~~~~~~~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"H~~~~~~~~~~~~~~~",
	]
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(rows, army, [_spawn(16, Rules.BISON, 14, 1)], 999.0)
	var landing := 2 * 16 + 7   # (7,2): visible from harbours 0 and 2, blocked from harbour 1
	var home := b.grid.home_harbour_for(landing)
	t.eq(home, 0, "이 상륙지의 집 항구는 0번이다 (자가 점검)")
	t.ok(not b.grid.can_land_at(1, landing), "1번 항구는 이 칸을 못 본다 — 곶 뒤다 (자가 점검)")

	t.ok(b.send(0, landing) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	t.eq(int(b.boats[0]["home"]), home, "출항할 때 이미 돌아갈 항구가 적혀 있다")
	_drive_until_ashore(t, b, 0, "곶 뒤 상륙")
	t.eq(Vector2((b.boats[0] as Dictionary)["to"]),
			b.grid.tile_point(int(b.grid.harbour_tiles[home])),
			"그리고 빈 배는 실제로 그 항구를 향한다")


# -- refusals, from the boat's side ------------------------------------------------------------------

## ⚠ **The assertion is that no BOAT was made.** `net_plan` measures the same six refusals from the
## plan's side (the soldier stays in RESERVE); this file measures that `boats` never grew, which is the
## half that would stay green if `send` refused *after* appending.
func _send_refusals(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_two_harbours(), army, [_spawn(12, Rules.BISON, 8, 1)], 999.0)
	var west := _th_tile(2, 2)

	t.eq(b.send(-1, west), -1, "없는 병사 번호로는 배가 안 생긴다")
	t.eq(b.send(4, west), -1, "명부 크기와 같은 번호로도 배가 안 생긴다")
	t.eq(b.send(0, int(b.grid.harbour_tiles[0])), -1, "상륙 불가능한 칸(물)으로는 배가 안 생긴다")
	t.eq(b.send(0, -1), -1, "격자 밖 칸으로도 배가 안 생긴다")
	t.eq(b.boats.size(), 0, "여기까지 배가 한 척도 안 생겼다")

	t.ok(b.send(0, west) >= 0, "제대로 된 요청은 배를 만든다 (자가 점검)")
	t.eq(b.send(0, west), -1, "이미 배에 탄 병사로는 두 번째 배가 안 생긴다")
	t.eq(b.boats.size(), 1, "그 거절도 배를 안 늘렸다")

	var dead := _army_of(Rules.CELL_MELEE, 2)
	dead.kill(0)
	var db := _battle_of(_two_harbours(), dead, [], 999.0)
	t.eq(db.send(0, west), -1, "죽은 병사로는 배가 안 생긴다")
	t.eq(db.boats.size(), 0, "그 거절도 배를 안 만들었다")

	t.ok(b.commit(), "확정했다 (자가 점검)")
	t.eq(b.send(1, west), -1, "확정한 뒤에는 배가 안 생긴다")
	t.eq(b.boats.size(), 1, "확정 뒤의 거절도 배를 안 늘렸다")


# -- reach is per harbour ----------------------------------------------------------------------------

## The east coast is unreachable from the west harbour and vice versa, and `send` answers to exactly
## the union of the two — `home_harbour_for(t) >= 0` — which is also what the droppable overlay is
## drawn from, so the screen can never promise a tile the sim refuses.
func _reach_is_per_harbour(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_two_harbours(), army, [], 999.0)
	var west := _th_tile(2, 2)
	var east := _th_tile(9, 2)
	t.ok(b.grid.can_land_at(0, west) and not b.grid.can_land_at(0, east),
			"서쪽 항구는 서쪽 해안만 본다 (자가 점검)")
	t.ok(b.grid.can_land_at(1, east) and not b.grid.can_land_at(1, west),
			"동쪽 항구는 동쪽 해안만 본다 (자가 점검)")

	t.ok(b.send(0, west) >= 0, "서쪽 해안은 보낼 수 있다")
	t.ok(b.send(1, east) >= 0, "동쪽 해안도 보낼 수 있다 — 상륙 구역은 항구들의 합집합이다")
	t.eq(int(b.boats[0]["home"]), 0, "서쪽으로 간 배는 서쪽 항구에서 떴다")
	t.eq(int(b.boats[1]["home"]), 1, "동쪽으로 간 배는 동쪽 항구에서 떴다")


# -- unloading -------------------------------------------------------------------------------------

## Four boats aimed at one tile from one harbour arrive on the same sub-step, and every one of them
## asks `_free_tiles_from` for one tile after the one before it has already reserved its own.
func _unload_placement(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	var landing := _tile_of(6, 5)
	for i in 4:
		t.ok(b.send(i, landing) >= 0, "%d번을 같은 칸으로 보냈다 (자가 점검)" % i)
	t.ok(b.commit(), "확정했다 (자가 점검)")
	_drive(b, BAY_SUBSTEPS)

	# ⚠ **Rounded to the tile, never compared as a raw `Vector2`.** `_phase_movement` runs in the SAME
	# sub-step as `_phase_landings`, so a soldier has already taken its first fraction of a step toward
	# the bison by the time this reads it — an exact position comparison here measures the walk speed,
	# not the landing.
	var taken := {}
	var adjacent := 0
	var owned := 0
	var landed := 0
	var front := -1
	for i in 4:
		if b.soldier_state[i] == Battle.SoldierState.ASHORE:
			landed += 1
		var p: Vector2 = b.soldier_pos[i]
		var tx := int(round(p.x))
		var ty := int(round(p.y))
		var tile := ty * b.grid.w + tx
		taken[tile] = true
		if tile == landing:
			front = i
		if maxi(absi(tx - int(_PORT_LANDING_X)), absi(ty - int(_PORT_LANDING_Y))) <= 1:
			adjacent += 1
		if b.grid.is_passable(tx, ty) and b.grid.reserved[tile] == i:
			owned += 1
	t.eq(front, 0, "먼저 놓은 병사가 상륙지 칸을 차지한다")
	t.eq(landed, 4, "넷 전부 상륙했다")
	t.eq(taken.size(), 4, "넷이 서로 다른 칸에 섰다")
	t.eq(adjacent, 4, "나머지는 상륙지에서 가장 가까운 칸들에 섰다 (전부 이웃 칸)")
	t.eq(owned, 4, "넷 칸 모두 땅이고 각자 자기 이름으로 예약됐다")


const _PORT_LANDING_X := 6.0
const _PORT_LANDING_Y := 5.0


## Three free tiles and four boats: three land and the fourth waits at the beach rather than standing
## on somebody. **The floor is the three that DID land** — a boat that never arrives at all satisfies
## "the fourth is still aboard" for the wrong reason.
func _boat_waits_for_shore(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_cove(), army, [_spawn(COVE_W, Rules.BISON, 3, 2)], 999.0)
	var landing := 3 * COVE_W + 3
	for i in 4:
		t.ok(b.send(i, landing) >= 0, "%d번을 좁은 해안으로 보냈다 (자가 점검)" % i)
	t.ok(b.commit(), "확정했다 (자가 점검)")
	_drive(b, 240)

	t.eq(b.ashore_ids().size(), 3, "빈 칸이 셋뿐이라 셋만 내렸다 (자가 점검)")
	t.eq(b.transit_ids().size(), 1, "빈 칸이 모자라면 안 내린다 — 넷째는 배 위에 남는다")
	var waiting := 0
	for raw in b.boats:
		var boat: Dictionary = raw
		if int(boat["phase"]) == Battle.Phase.OUTBOUND and (boat["soldiers"] as Array).size() == 1:
			waiting += 1
	t.eq(waiting, 1, "그 배는 그대로 OUTBOUND 다 — 못 내렸으니 안 돌아간다")


# -- cargo aboard --------------------------------------------------------------------------------

func _cargo_rides_the_boat(t) -> void:
	var army := _army_of(Rules.CELL_RANGED, 1)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.CROW, 3, 2)], 999.0)
	t.ok(b.send(0, _tile_of(6, 5)) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	_drive(b, 6)
	t.eq(b.soldier_pos[0], Vector2(b.boats[0]["pos"]), "화물은 배 위치를 그대로 탄다")
	t.ok(b.soldier_pos[0].distance_to(b.enemy_pos[0]) < army.range_of(0) + Rules.REACH_BONUS,
			"까마귀는 그 병사의 사거리 안에 있다")
	_drive(b, 18)
	t.eq(b.enemy_hp[0], Rules.hp_of(Rules.CROW), "그래도 배 위에서는 못 쏜다")
	t.ok(army.hp[0] < Rules.hp_of(Rules.CELL_RANGED), "맞기는 맞는다")


# -- driving ---------------------------------------------------------------------------------------

## `n` whole sub-steps, one call each. Never one coarse `step(n * h)`: `step` carries a leftover, so a
## coarse call is a different measurement from the one every row here means to make.
func _drive(b: Battle, n: int) -> void:
	for _i in n:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)


## Sub-steps until soldier `sid` is ashore, with a budget. Returns the count. ⚠ **A loop whose
## condition is false from the start never runs the check at all**, so the count is asserted, not
## thrown away.
func _drive_until_ashore(t, b: Battle, sid: int, what: String) -> int:
	var n := 0
	while n < 1200 and b.soldier_state[sid] != Battle.SoldierState.ASHORE:
		_drive(b, 1)
		n += 1
	t.ok(n > 0 and n < 1200, "%s: %d 서브스텝 만에 상륙했다 (자가 점검)" % [what, n])
	return n


# -- fixtures --------------------------------------------------------------------------------------

## An open bay: rows 3-7 are water for the first six columns, land from column 6 on, one harbour at
## (2,5). Every target used in this file sits on the land side, reachable in a straight line over the
## bay's own water.
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


## The same shape stretched: water for the first sixteen columns, land from column 16, harbour still
## at (2,5). Exists so "crossing time scales with distance" has a SECOND distance to compare against.
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
## fixture: a west harbour that sees the west shore and not the east one, and vice versa.
func _two_harbours() -> Array:
	return [
		"~~~~~~~~~~~~",
		"~..........~",
		"~....#.....~",
		"~~~~~#~~~~~~",
		"~~H~~~~~~H~~",
	]


## Four land tiles — (3,2), (2,3), (3,3), (4,3) — one held by the bison standing on (3,2), so exactly
## three are ever free: the boundary case for "a fourth boat waits". A harbour in open water south of
## them sails a straight vertical line to the landing tile (3,3).
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
