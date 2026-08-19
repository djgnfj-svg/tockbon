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
##
## ⚠⚠ **A BOAT IS A POLYLINE NOW** (`speed-off-open-landing`, 2.3). `from` / `to` are deleted keys;
## the crossing is `path` + `cum` + `leg`, and `dist` is the path's total length rather than a
## straight-line distance. **Every literal below was re-measured against the new geometry, including
## the ones on fixtures whose bays are open water** — a hop-count BFS does not produce the straight
## line even where one exists, so `_bay()`'s 4.0-tile crossing became 4 x sqrt(2) = 5.656854.
## Re-measured, never relaxed: the literals are still literals.

const ARENA_W := 24
const ARENA_H := 12
## The cramped island: four land tiles, one held by the bison standing on it, so exactly three are
## ever free. With one soldier per boat that makes "a fourth boat waits rather than landing on top of
## somebody" measurable at the boundary.
const COVE_W := 10
const COVE_H := 7

## ⚠⚠ **`_bay()`'s crossing is NOT 4.0 tiles any more and the reason is worth reading.** Harbour (2,5)
## to landing (6,5) is 4.0 tiles as the crow flies, and the whole bay between them is OPEN WATER — but
## `water_route` walks down a hop-count BFS, where a diagonal step and an orthogonal step both cost 1,
## so among the many equal-hop paths the fixed `NEIGHBOURS` tie-break picks one that is not the
## straight one. The route it produces is `(2,5) (3,4) (4,3) (5,4) (6,5)` — four DIAGONAL steps —
## which is `4 x sqrt(2) = 5.656854` tiles. At `Rules.BOAT_SPEED` 4.0 that is 84.853 sub-steps, so
## `_arrived` first fires on sub-step **85**.
##
## ⚠ **This is measured, and it is reported rather than tuned away.** The bound is `sqrt(2)` — a route
## can be up to 41% longer than the straight line, on open water, and on the three shipped islands the
## worst ratio really is 1.414. `grid.water_route`'s own comment carries the finding.
const BAY_DIST := 5.656854
const BAY_SUBSTEPS := 85
## `_far_bay()`'s crossing: the same harbour to (16,5). Two diagonal steps out, eleven straight, two
## diagonal in = `13 + 2 * sqrt(2) = 15.656854` tiles = 234.853 sub-steps, so arrival is on **235**.
const FAR_DIST := 15.656854
const FAR_SUBSTEPS := 235

const FULL_ROSTER := 13


func run(t) -> void:
	_the_one_surviving_number(t)
	_crossing_arithmetic_is_literal(t)
	_crossing_scales_with_distance(t)
	_boats_do_not_share(t)
	_the_boat_really_sails_on_water(t)
	_leg_only_goes_forward(t)
	_return_leg_is_the_outbound_path_reversed(t)
	_return_leg_is_simulated(t)
	_relocation_sends_the_boat_to_the_right_harbour(t)
	_send_refusals(t)
	_a_refused_drop_makes_no_boat(t)
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
	t.ok(absf(float(b.boats[0]["dist"]) - BAY_DIST) <= 1e-5,
			"이 항구에서 이 상륙지까지 항로가 정확히 4 x sqrt(2) = 5.656854칸이다 (자가 점검)")
	var path0: PackedVector2Array = b.boats[0]["path"]
	t.eq(path0.size(), 5, "그 항로는 5점짜리 폴리라인이다 (직선이면 2점이다)")
	t.eq(path0[0], Vector2(2.0, 5.0), "0번 지점은 항구다")
	t.eq(path0[path0.size() - 1], Vector2(6.0, 5.0), "마지막 지점은 상륙 칸이다")

	# 30 sub-steps is 0.5 s, so the boat has sailed `0.5 * 4.0 = 2.0` tiles ALONG THE ROUTE. The route's
	# vertices sit at 0, 1.414, 2.828, 4.243, 5.657, so 2.0 falls inside segment 1 at
	# `f = (2.0 - sqrt(2)) / sqrt(2) = sqrt(2) - 1 = 0.4142136`, giving
	# `(3,4).lerp((4,3), f) = (3.4142136, 3.5857864)`. **Computed by hand from the fixture, never read
	# back off `cum`** — this is the one check in the file whose numbers are bare literals.
	_drive(b, 30)
	var half: Vector2 = b.boats[0]["pos"]
	t.ok(Vector2(3.4142136, 3.5857864).distance_to(half) <= Rules.EPS,
			"0.5초(30 서브스텝) 뒤 배는 항로를 2.0칸 지나 (3.4142136, 3.5857864)에 있다 — 손으로 센 리터럴이다")
	t.eq(int(b.boats[0]["leg"]), 1, "그 지점은 1번 구간 위다 — leg 도 1이다")

	_drive(b, BAY_SUBSTEPS - 30 - 1)
	t.eq(b.soldier_state[0], Battle.SoldierState.TRANSIT,
			"84 서브스텝에는 아직 안 도착했다 — 5.656854/4.0 = 1.41421초 = 84.853 서브스텝이다")
	_drive(b, 1)
	t.eq(b.soldier_state[0], Battle.SoldierState.ASHORE, "85 서브스텝에는 도착해 있다")


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

	t.eq(near_steps, BAY_SUBSTEPS, "가까운 해안은 85 서브스텝 걸린다")
	t.eq(far_steps, FAR_SUBSTEPS, "먼 해안일수록 오래 걸린다 — 235 서브스텝이다")
	# ⚠ The ratio is asserted against the two hand-measured ROUTE lengths, not against the two `dist`
	# fields — the boats are gone by the time this reads them, and reading the thing under test for the
	# expectation is what the check above this one exists to avoid.
	t.ok(absf(float(far_steps) / float(near_steps) - FAR_DIST / BAY_DIST) <= 0.01,
			"걸린 시간의 비가 항로 길이의 비와 같다 (%.4f배)" % (FAR_DIST / BAY_DIST))


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


# -- the boat is really on the water ---------------------------------------------------------------

## ⚠⚠ **「배가 도착했다」는 「배가 물 위로 갔다」가 아니다.** Endpoint-only checks pass a boat that
## teleports across the island, and that is `how-nets-lie`'s *a ceiling with no floor* in its exact
## shape. This drives the crossing one sub-step at a time and reads the hull's position on every one.
##
## The fixture is `_shadow_bay()` — a beach the OLD straight-line rule REFUSED, which is the whole
## point of the round. Measured: the route is 8 points, `(2,4) (3,3) (4,3) (5,4) (6,3) (7,3) (8,3)`
## then the beach at `(9,2)`, and the dip to `(5,4)` is the boat going around the `#` at `(5,3)`.
func _the_boat_really_sails_on_water(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(_shadow_bay(), army, [_spawn(12, Rules.BISON, 2, 1)], 999.0)
	var beach := 2 * 12 + 9
	t.eq(b.grid.home_harbour_for(beach), 0, "그 해안의 집 항구는 하나뿐인 0번이다 (자가 점검)")
	# ⚠ **The label says only what this line asserts.** It used to read 「예전 규칙이 거절하던 해안으로
	# 보냈다」, and the old straight-line rule is DELETED — it cannot be consulted from in here, so that
	# was a claim about code no net can run. What the fixture being a shadowed beach buys is recorded
	# where it can be checked: in `_shadow_bay()`'s own comment.
	t.ok(b.send(0, beach) >= 0 and b.commit(), "그 해안으로 보내고 확정했다 (자가 점검)")
	var path: PackedVector2Array = b.boats[0]["path"]
	t.eq(path.size(), 8, "항로가 8점짜리 폴리라인이다 (바깥에서 검증됨)")

	var dry: Array = []
	var still := 0
	var tiles := {}
	var prev: Vector2 = b.boats[0]["pos"]
	var n := 0
	while n < 400 and b.soldier_state[0] != Battle.SoldierState.ASHORE:
		_drive(b, 1)
		n += 1
		if b.boats.is_empty():
			break
		var here: Vector2 = b.boats[0]["pos"]
		if here.distance_to(prev) <= Rules.EPS:
			still += 1
		prev = here
		var tile := b.grid.tile_index(int(round(here.x)), int(round(here.y)))
		tiles[tile] = true
		# ⚠ **The LANDING tile itself is exempt and nothing else is.** The route's last waypoint IS the
		# beach, so the final segment legitimately carries the hull over it — that is the boat arriving,
		# not the boat sailing over land. Every other tile it rounds onto must be water, and this
		# exemption is one tile wide rather than "the last few sub-steps" precisely so a route that cut
		# a corner across the island two tiles earlier still reddens.
		if tile != beach and b.grid.water[tile] == 0:
			dry.append("%s -> 칸 %d" % [str(here), tile])
	t.ok(n > 1 and n < 400, "%d 서브스텝 만에 건넜다 (자가 점검)" % n)
	t.eq(dry.size(), 0, "건너는 내내 배 밑은 물이었다 — 물 밖에 있던 자리: %s" % str(dry))
	# The floor. A boat parked at its harbour for the whole crossing satisfies "every position was
	# water" perfectly.
	t.eq(still, 0, "배는 매 서브스텝 실제로 움직였다 (한 번도 안 선다)")
	t.ok(tiles.size() > 2,
		"그리고 %d개의 서로 다른 칸을 지났다 — 2칸이면 그건 출발점과 도착점, 곧 직선이다" % tiles.size())


## `leg` is the sim's own bookmark into `path`, and the view draws the remaining route off it. It must
## be monotone: a `leg` that never advances leaves the hull on segment 0 while `t` runs out, and a
## `leg` that jumps backwards redraws water the boat has already crossed.
func _leg_only_goes_forward(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(_shadow_bay(), army, [_spawn(12, Rules.BISON, 2, 1)], 999.0)
	var beach := 2 * 12 + 9
	t.ok(b.send(0, beach) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	var path: PackedVector2Array = b.boats[0]["path"]
	t.eq(int(b.boats[0]["leg"]), 0, "출발할 때 leg 는 0이다")
	t.eq(Vector2(b.boats[0]["pos"]), path[0], "그리고 배는 항구에 있다")

	# ⚠ **Only OUTBOUND sub-steps are read.** `_phase_boats` runs BEFORE `_phase_landings` inside one
	# sub-step, so on the arrival sub-step `leg` reaches its last segment and is then reset to 0 by the
	# turn to RETURNING — reading past that point measures the return leg's own fresh bookmark and
	# reports it as `leg` going backwards.
	var went_back := 0
	var last := 0
	var n := 0
	var top_leg := -1
	while n < 400 and b.soldier_state[0] != Battle.SoldierState.ASHORE:
		_drive(b, 1)
		n += 1
		if b.boats.is_empty() or int((b.boats[0] as Dictionary)["phase"]) != Battle.Phase.OUTBOUND:
			break
		var leg := int(b.boats[0]["leg"])
		if leg < last:
			went_back += 1
		last = leg
		top_leg = maxi(top_leg, leg)
	t.eq(went_back, 0, "leg 는 한 번도 뒤로 안 갔다")
	t.eq(top_leg, path.size() - 2,
		"나가는 다리 끝에서 leg 는 마지막 구간(%d)이다 — 끝을 지나쳐 색인하지 않는다" % (path.size() - 2))
	t.ok(top_leg > 0, "그리고 실제로 전진했다 (0에 머물러 있지 않다)")


## ⚠⚠ **돌아가는 배는 왔던 항로를 그대로 뒤집는다 — 다시 계산하지 않는다.** `home` was decided by
## `send` off the same `home_harbour_for` call the refusal used, and `path` came out of that same
## harbour, so recomputing the route at the beach would be one fact in two places — free to disagree
## the day the route's tie-break moves. `dist` is not recomputed either: a reversed polyline is exactly
## as long as the polyline.
func _return_leg_is_the_outbound_path_reversed(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(_shadow_bay(), army, [_spawn(12, Rules.BISON, 2, 1)], 999.0)
	var beach := 2 * 12 + 9
	t.ok(b.send(0, beach) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	var out_path := PackedVector2Array(b.boats[0]["path"])
	var out_dist := float(b.boats[0]["dist"])
	t.ok(out_path.size() >= 3, "나갈 때 항로가 %d점이다 (자가 점검)" % out_path.size())

	_drive_until_ashore(t, b, 0, "뒤집기 시험")
	t.eq(b.boats.size(), 1, "내려놓은 배가 아직 있다 (자가 점검)")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["phase"]), Battle.Phase.RETURNING, "RETURNING 으로 바뀌었다")

	var back: PackedVector2Array = boat["path"]
	t.eq(back.size(), out_path.size(), "돌아가는 항로의 점 수가 나갈 때와 같다")
	var mismatched: Array = []
	for k in back.size():
		if back[k].distance_to(out_path[out_path.size() - 1 - k]) > Rules.EPS:
			mismatched.append(k)
	t.eq(mismatched.size(), 0,
		"점 하나하나가 나갈 때 항로를 정확히 뒤집은 것이다 %s — 항구에서 다시 계산하면 문다" % str(mismatched))
	t.ok(absf(float(boat["dist"]) - out_dist) <= 1e-5,
		"dist 는 그대로다 — 뒤집은 폴리라인의 길이는 원래 길이와 같다")
	t.eq(float(boat["t"]), 0.0, "t 는 0으로 돌아갔다")
	t.eq(int(boat["leg"]), 0, "leg 도 0으로 돌아갔다")
	var cum: PackedFloat32Array = boat["cum"]
	t.eq(cum.size(), back.size(), "cum 도 새 항로만큼 다시 쌓였다")
	t.ok(absf(float(cum[0])) <= 1e-5, "cum[0] 은 0이다")
	t.ok(absf(float(cum[cum.size() - 1]) - float(boat["dist"])) <= 1e-4,
		"그리고 cum 의 끝이 dist 와 같다 — 접두 합이 항로와 안 맞으면 배가 순간이동한다")


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
	var back_path: PackedVector2Array = boat["path"]
	t.eq(back_path[back_path.size() - 1], b.grid.tile_point(int(b.grid.harbour_tiles[home])),
			"빈 배의 항로 끝은 '자기가 내려준 해안에 닿을 수 있는' 항구다")

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
## and 0 are all the same number and every comparison reads `0 == 0`.** This one has two harbours and
## a landing whose home harbour is **not** the nearest one in a straight line.
##
## ⚠⚠ **The old fixture for this row is DELETED, not re-pointed.** It was a `#` peninsula and it worked
## because a straight LINE was blocked; an 8-connected water route sails around any peninsula, so on
## that shape all three harbours now reach the landing and the check would have gone green while
## measuring nothing at all. What still discriminates is a land BAR that makes one harbour's water
## route long. Verified outside Godot for the beach at (2,3):
##   harbour 0 (10,0), open sea — straight **8.544**, **7 hops**   <- the answer
##   harbour 1 (2,6),  in the bay — straight **3.000**, **24 hops** <- nearest, and wrong
func _relocation_sends_the_boat_to_the_right_harbour(t) -> void:
	var rows := [
		"~~~~~~~~~~H~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"..............~~",
		"..............~~",
		"~~~~~~~~~~~~~~~~",
		"~~H~~~~~~~~~~~~~",
	]
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(rows, army, [_spawn(16, Rules.BISON, 10, 4)], 999.0)
	var landing := 3 * 16 + 2   # (2,3), on the bar's seaward edge
	var home := b.grid.home_harbour_for(landing)
	t.eq(home, 0, "이 상륙지의 집 항구는 물길이 짧은 0번이다 (자가 점검)")
	# The self-check that makes the row discriminating: the straight-line rule really would answer 1.
	var straight_best := -1
	var straight_d := 0.0
	for hb in b.grid.harbour_tiles.size():
		var d: float = b.grid.tile_point(int(b.grid.harbour_tiles[hb])).distance_to(
			b.grid.tile_point(landing))
		if straight_best == -1 or d < straight_d - Rules.EPS:
			straight_best = hb
			straight_d = d
	t.eq(straight_best, 1, "직선으로는 1번이 더 가깝다 — 픽스처가 실제로 갈린다 (자가 점검)")

	t.ok(b.send(0, landing) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	t.eq(int(b.boats[0]["home"]), home, "출항할 때 이미 돌아갈 항구가 적혀 있다")
	var out_first: Vector2 = (b.boats[0]["path"] as PackedVector2Array)[0]
	t.eq(out_first, b.grid.tile_point(int(b.grid.harbour_tiles[home])), "그 항구에서 출항했다")
	_drive_until_ashore(t, b, 0, "육지 둑 너머 상륙")
	var home_path: PackedVector2Array = (b.boats[0] as Dictionary)["path"]
	t.eq(home_path[home_path.size() - 1], b.grid.tile_point(int(b.grid.harbour_tiles[home])),
			"그리고 빈 배는 실제로 그 항구로 향한다")


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


## ⚠⚠ **거절된 놓기는 배를 만들지 않는다 — 아무것도 안 바뀐다.** This is the sim end of the shell's
## refusal mark: the mark is drawn off THIS `-1`, so if `send` ever refused *after* touching state the
## screen would say no about a drop that half happened.
func _a_refused_drop_makes_no_boat(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	# An inland tile with no water 8-neighbour at all — the denylist's own refusal case, not a tile
	# that happens to be off the grid.
	var inland := _tile_of(12, 5)
	var touches_water := false
	for k in Grid.NEIGHBOURS.size():
		var nx := 12 + int(Grid.NEIGHBOURS[k][0])
		var ny := 5 + int(Grid.NEIGHBOURS[k][1])
		if b.grid.water[ny * ARENA_W + nx] != 0:
			touches_water = true
	t.ok(not touches_water, "(12,5)는 여덟 방향 어디로도 물에 안 닿는다 (자가 점검)")
	t.eq(int(b.grid.passable[inland]), 1, "그래도 걸을 수 있는 땅이다 (자가 점검 — 절벽 때문이 아니다)")
	t.eq(b.grid.home_harbour_for(inland), -1, "그래서 어느 항구도 못 간다 (자가 점검)")

	t.eq(b.send(0, inland), -1, "내륙으로는 배가 안 생긴다")
	t.ok(b.boats.is_empty(), "boats 가 그대로 비어 있다")
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "병사는 여전히 RESERVE 다 — 아무것도 안 바뀌었다")
	t.eq(b.soldier_pos[0], Battle.OFFMAP, "자리도 안 옮겨졌다")


# -- reach is per harbour ----------------------------------------------------------------------------

## ⚠⚠ **This row's OLD claim is now false and it was rewritten rather than deleted.** It read "the east
## coast is unreachable from the west harbour and vice versa" — true of a straight LINE past a `#`
## peninsula, false of an 8-connected water route, which sails around it. All water on this fixture is
## one body, so BOTH harbours reach BOTH shores.
##
## What survives, and is the thing that actually decides a departure point: `send` goes through
## `home_harbour_for`, which picks the harbour with the SHORTEST water route — so a west landing still
## leaves from the west harbour and an east landing from the east one.
func _reach_is_per_harbour(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_two_harbours(), army, [], 999.0)
	var west := _th_tile(2, 2)
	var east := _th_tile(9, 2)
	t.ok(b.grid.can_land_at(0, west) and b.grid.can_land_at(0, east),
			"서쪽 항구는 두 해안 모두에 닿는다 — 물이 곶을 돌아 이어져 있다 (자가 점검)")
	t.ok(b.grid.can_land_at(1, west) and b.grid.can_land_at(1, east),
			"동쪽 항구도 두 해안 모두에 닿는다 (자가 점검)")

	t.ok(b.send(0, west) >= 0, "서쪽 해안은 보낼 수 있다")
	t.ok(b.send(1, east) >= 0, "동쪽 해안도 보낼 수 있다")
	t.eq(int(b.boats[0]["home"]), 0,
			"서쪽으로 간 배는 서쪽 항구에서 뜬다 — 둘 다 닿지만 물길이 짧은 쪽이 고른다")
	t.eq(int(b.boats[1]["home"]), 1, "동쪽으로 간 배는 동쪽 항구에서 뜬다")
	t.ok(int(b.boats[0]["home"]) != int(b.boats[1]["home"]),
			"두 상륙지가 서로 다른 항구를 골랐다 — home_harbour_for 를 상수로 만들면 문다")


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
## (2,5). Every target used in this file sits on the land side.
## ⚠ The crossing over this OPEN water is still not the straight line — see `BAY_DIST`.
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


## Two harbours on opposite sides of a single-tile `#` peninsula. ⚠ **Under the OLD straight-line rule
## each harbour saw only its own shore; under a water route both reach both**, and what the fixture
## measures now is which harbour `home_harbour_for` picks — see `_reach_is_per_harbour`.
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


## The same `#` peninsula with only ONE harbour, at (2,4). The beach at (9,2) is a tile the OLD
## straight-line rule REFUSED from this harbour — the sample at (5,3) landed on the peninsula — and
## with one harbour `home_harbour_for` has no choice, so a `send` there really does drive the long way
## round. Measured route: `(2,4) (3,3) (4,3) (5,4) (6,3) (7,3) (8,3) (9,2)`, **8 points, 8.656854
## tiles** against a 7.280110-tile straight line.
func _shadow_bay() -> Array:
	return [
		"~~~~~~~~~~~~",
		"~..........~",
		"~....#.....~",
		"~~~~~#~~~~~~",
		"~~H~~~~~~~~~",
	]


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
