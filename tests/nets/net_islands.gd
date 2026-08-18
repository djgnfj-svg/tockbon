extends RefCounted
## The three island grids at their new 48 x 32 shape, and whether the game's own walker can actually
## get from every coast a fleet can reach to every enemy on the island.
##
## **Every literal below was cross-checked against a from-scratch reimplementation of `grid.gd`'s
## algorithm, run outside Godot, before being written in here** — the harbour tiles, the start
## harbour, every per-harbour sendable count, the narrowest cut, the coast count and the wave-1
## crossing bounds all reproduced `boat-and-landing` section 5's own measured table exactly, which is
## the strongest evidence this file has that `grid.gd` matches the plan it was written from.
##
## **`boat-and-landing`'s "steady state" crossing bounds (section 4.6) ARE pinned here, resolved.**
## The earlier gap ("island 1's max comes out 24.60, not 14.56") was measuring the wrong domain: the
## plan's own figure is `distance(harbour_tiles[home_harbour_for(t)], t)` over tiles the START harbour
## can reach (`sendable[start_harbour]`), never the union across all three harbours. The union includes
## tiles that are only reachable AFTER a relocation — they are not wave-1 landings at all, so folding
## them into "steady state" measures something the plan never claimed. Verified by an independent
## reimplementation against `islands.gd`'s own rows: restricted to start-sendable tiles, the figures
## and the relocation counts reproduce the plan's table exactly (`EXPECT_STEADY`, `EXPECT_RELOCATES`).
##
## **This net drives `grid.flow_field` and `grid.step_toward` and never carries a walker of its own** —
## the same reason the first-slice plan gives: a walker with its own BFS measures the walker, not
## whether the real game's units can cross this ground.


const LEGEND := "~H.#^/BCL"

const EXPECT_ROWS := 32
const EXPECT_COLS := 48

## Every one of these was reproduced by an independent reimplementation, not merely read back off
## `Grid` — see the header.
const EXPECT_HARBOUR_TILES := [[1337, 1398, 1512], [1382, 1402, 1514], [1303, 1432, 1512]]
const EXPECT_START_TILE := [1512, 1514, 1512]
## Per-harbour sendable counts, in harbour-index order (0, 1, 2 — the start harbour is index 2 on all
## three islands, which is exactly why 미정/section 5 warns against pinning the INDEX instead of the
## tile: "harbour 0" would stay green on these three islands by accident).
const EXPECT_SENDABLE := [[24, 29, 47], [23, 21, 38], [29, 33, 46]]
const EXPECT_SENDABLE_UNION := [50, 44, 48]
const EXPECT_COAST := [82, 76, 80]
const EXPECT_CUTS := [15, 2, 10]
## ⚠ **RAISED by `plan-then-watch` stage 4 — 4 · 6 · 5 became 8 · 12 · 14**, by adding characters to
## `islands.gd` rows and nothing else (`spawns_of` is a scan, so an added `B` is an added enemy with
## no table to widen). The old counts could not lose an island: the probe's baseline plan won all
## fifteen island-runs, and its worst island spent under a third of its limit.
const EXPECT_SPAWNS := [8, 12, 14]
## Wave-1 crossing distance, tiles: min/max over every tile the START harbour can reach.
const EXPECT_WAVE1 := [[11.70, 24.60], [11.00, 26.40], [13.00, 24.60]]
## Steady-state crossing distance, tiles: min/max of `distance(harbour_tiles[home_harbour_for(t)], t)`
## over the SAME start-sendable tiles as `EXPECT_WAVE1` — never the union over all harbours, which
## includes tiles unreachable until after a relocation and so is not "the next crossing to a landing
## you already hold". See the header for how this was resolved.
const EXPECT_STEADY := [[7.00, 14.56], [8.00, 12.04], [7.00, 14.32]]
## How many of the start-sendable tiles relocate the fleet away from the start harbour (i.e.
## `home_harbour_for(t) != start_harbour`), out of the start-sendable count itself (47, 38, 46).
const EXPECT_RELOCATES := [30, 32, 32]
## The strict walker's own count — every enemy reserved simultaneously, matching a live
## `battle.setup`. Only island 2 has any (bison sitting close enough together jam the walker on each
## other's tiles); see the comment above that check for why this is a real but different, weaker
## property than the terrain-only walker above it.
## ⚠ **RE-MEASURED at 8 · 12 · 14: island 2 went 14 -> 63**, which is what doubling its bison does to
## a walker that has to route around all of them at once. **The prose that used to certify the 14 by
## hand is deleted, not scaled up** — 63 cases are not something a comment can verify. What replaced
## it is a CHECK on the property that made those 14 benign, run over all 63.
const EXPECT_STRICT_UNREACHED := [0, 63, 0]

## How many landable coast tiles sit inside NO enemy's detect circle (`plan-then-watch`, 8.3).
## Hand-measured off the shipped rows, one literal per island. ⚠ **Not a bound** — a greedy cover
## reaches zero on all three at these counts and deletes the 「quiet shore」 plan with it.
const EXPECT_UNCOVERED_COAST := [13, 14, 4]
## ⚠ **The old floor read `max over b of Rules.cap_of(b) + 1`, and `Rules.BOATS` no longer exists.**
## The silent stall it guards against is unchanged: `_try_unload` never lands part of a load, so a boat
## whose cargo does not fit waits forever and the island runs to LOST/TIMEOUT with nothing in the sim
## saying why. What changed is the DEMAND. With boats created per drag (`plan-then-watch`, 4.2) every
## living soldier can aim at one region on one sub-step, so the bound is the largest roster a run can
## field, plus a tile of margin for a neighbour already occupied when the last boat arrives — see
## `_min_region_floor()`.
## ⚠ **「1 + 1 = 2, because a boat carries one soldier」 is the trap here**: it shrinks the bound while
## the real simultaneous demand went UP.

## How many tiles `grid.home_harbour_for(t) >= 0` answers yes to — **the exact predicate `battle.send`
## refuses on and the exact predicate the droppable overlay is drawn from**, so the screen can never
## promise a tile the sim refuses. Hand-measured off the shipped rows, one literal per island.
## ⚠ It is bounded below by the START harbour's own sendable count and above by `EXPECT_COAST`; both
## bounds are asserted as well as the literal, so a `home_harbour_for` that collapsed to one harbour or
## opened to every tile would be caught even if the literal were mis-transcribed.
const EXPECT_DROPPABLE := [50, 44, 48]
const EXPECT_START_SENDABLE := [47, 38, 46]

## Seconds per island — unchanged by this plan (decided #9).
const EXPECT_LIMITS := [60.0, 60.0, 90.0]

## Ceiling on tiles crossed in one walk, matching `battle.gd`'s `WALK_TILES_MAX` order of magnitude on
## a grid 2.67x the old one's tile count.
const WALK_STEPS_MAX := 900
const WALKER_ID := 999_999


func run(t) -> void:
	t.eq(Islands.count(), 3, "섬은 셋이다")
	t.eq(Islands.TIME_LIMITS.size(), 3, "제한 시간도 섬마다 하나씩 있다")
	for i in EXPECT_LIMITS.size():
		t.eq(Islands.time_limit_of(i), float(EXPECT_LIMITS[i]),
			"섬 %d 의 제한 시간은 %.0f초다" % [i + 1, float(EXPECT_LIMITS[i])])

	var min_region_floor := _min_region_floor()
	# ⚠ The 20 is a LITERAL on purpose. Writing the formula on both sides would let the roster grow and
	# the expectation grow with it, which is the shape that proves nothing.
	t.eq(min_region_floor, 20, "가장 좁아도 되는 상륙지 바닥은 20칸이다 (최대 병력 19 + 여유 1) — 자가 점검")
	t.eq(Rules.START_MELEE + Rules.START_RANGED
		+ Rules.map_max_count_nodes_on_a_route() * (Rules.REWARD_MELEE + Rules.REWARD_RANGED), 19,
		"그 최대 병력 19가 10 + 세포 칸 셋 x 3 이다 — look.gd 의 명부 정원과 같은 셈이다 (자가 점검)")
	_the_floor_actually_rejects_something(t, min_region_floor)

	var walker_pairs := 0
	var walker_steps := 0
	for i in Islands.count():
		var rows := Islands.rows_of(i)
		var shape := _shape_errors(rows, EXPECT_ROWS, EXPECT_COLS)
		t.eq(shape.size(), 0, "섬 %d 은 %d행 x %d자다 %s" % [i + 1, EXPECT_ROWS, EXPECT_COLS, str(shape)])
		var illegal := _illegal_chars(rows)
		t.eq(illegal.size(), 0, "섬 %d 에 범례 밖 글자가 없다 %s" % [i + 1, str(illegal)])

		var h_count := _count_char(rows, "H")
		t.eq(h_count, 3, "섬 %d 의 항구는 셋이다" % (i + 1))

		var grid := Grid.new()
		grid.load_rows(rows)

		var got_harbours: Array = []
		for hb in grid.harbour_tiles:
			got_harbours.append(int(hb))
		t.eq(got_harbours, EXPECT_HARBOUR_TILES[i], "섬 %d 의 항구 타일" % (i + 1))
		t.eq(int(grid.harbour_tiles[grid.start_harbour]), int(EXPECT_START_TILE[i]),
			"섬 %d — 함대는 자기 해안에서 가장 먼 항구에서 시작한다" % (i + 1))

		var coast := 0
		for tile in grid.landable.size():
			if grid.landable[tile] != 0:
				coast += 1
		t.eq(coast, int(EXPECT_COAST[i]), "섬 %d 의 상륙 가능 칸 수" % (i + 1))

		var cut := _cut_of(grid)
		t.eq(cut, int(EXPECT_CUTS[i]), "섬 %d 의 최협 절단" % (i + 1))

		var union := PackedByteArray()
		union.resize(grid.landable.size())
		for hb in grid.harbour_tiles.size():
			var got_send := 0
			var arr: PackedByteArray = grid.sendable[hb]
			for tile in arr.size():
				if arr[tile] != 0:
					got_send += 1
					union[tile] = 1
			t.eq(got_send, int(EXPECT_SENDABLE[i][hb]),
				"섬 %d 의 항구 %d 에서 보낼 수 있는 해안 칸 수" % [i + 1, hb])
		var union_n := 0
		for v in union:
			if v != 0:
				union_n += 1
		t.eq(union_n, int(EXPECT_SENDABLE_UNION[i]), "섬 %d — 항구 셋을 합쳐 닿는 해안 칸 수" % (i + 1))

		# ⚠ **Counted through `home_harbour_for`, not through `sendable`.** They agree today and that is
		# the point: `send` refuses on `home_harbour_for(tile) < 0` and the droppable overlay is painted
		# from the same call, so this is the number the PLAYER is offered. Reading `sendable` again here
		# would be the row above under a second name, and a `home_harbour_for` that collapsed to one
		# harbour would leave it green.
		var droppable := 0
		for tile in grid.passable.size():
			if grid.home_harbour_for(tile) >= 0:
				droppable += 1
		t.eq(droppable, int(EXPECT_DROPPABLE[i]), "섬 %d — 배를 보낼 수 있는 칸 수" % (i + 1))
		t.ok(droppable >= int(EXPECT_START_SENDABLE[i]),
			"섬 %d — 그 수는 시작 항구 혼자 닿는 %d칸보다 작지 않다 — 한 항구로 오그라들지 않았다"
			% [i + 1, int(EXPECT_START_SENDABLE[i])])
		t.ok(droppable <= int(EXPECT_COAST[i]),
			"섬 %d — 그리고 상륙 가능한 %d칸을 넘지 않는다 — 모든 칸으로 열리지도 않았다"
			% [i + 1, int(EXPECT_COAST[i])])

		var start_hb := grid.start_harbour
		var origin := grid.tile_point(int(grid.harbour_tiles[start_hb]))
		var start_sendable: PackedByteArray = grid.sendable[start_hb]
		var wave1_min := -1.0
		var wave1_max := -1.0
		for tile in start_sendable.size():
			if start_sendable[tile] == 0:
				continue
			var d := origin.distance_to(grid.tile_point(tile))
			if wave1_min < 0.0 or d < wave1_min:
				wave1_min = d
			if d > wave1_max:
				wave1_max = d
		t.ok(absf(wave1_min - float(EXPECT_WAVE1[i][0])) <= 0.02,
			"섬 %d — 1파 최단 항해가 %.2f칸이다" % [i + 1, wave1_min])
		t.ok(absf(wave1_max - float(EXPECT_WAVE1[i][1])) <= 0.02,
			"섬 %d — 1파 최장 항해가 %.2f칸이다" % [i + 1, wave1_max])

		# -- steady state: the SAME start-sendable tiles, distance from wherever the fleet relocates to
		var steady_min := -1.0
		var steady_max := -1.0
		var relocates := 0
		for tile in start_sendable.size():
			if start_sendable[tile] == 0:
				continue
			var home := grid.home_harbour_for(tile)
			var home_pt := grid.tile_point(int(grid.harbour_tiles[home]))
			var d2 := home_pt.distance_to(grid.tile_point(tile))
			if steady_min < 0.0 or d2 < steady_min:
				steady_min = d2
			if d2 > steady_max:
				steady_max = d2
			if home != start_hb:
				relocates += 1
		t.ok(absf(steady_min - float(EXPECT_STEADY[i][0])) <= 0.02,
			"섬 %d — 정착 후 최단 항해가 %.2f칸이다" % [i + 1, steady_min])
		t.ok(absf(steady_max - float(EXPECT_STEADY[i][1])) <= 0.02,
			"섬 %d — 정착 후 최장 항해가 %.2f칸이다" % [i + 1, steady_max])
		t.eq(relocates, int(EXPECT_RELOCATES[i]),
			"섬 %d — 1파 상륙지 중 함대가 항구를 옮기는 곳의 수" % (i + 1))

		var spawns := Islands.spawns_of(i)
		t.eq(spawns.size(), int(EXPECT_SPAWNS[i]), "섬 %d 의 적 수" % (i + 1))
		var off_land := 0
		for e in spawns.size():
			if grid.passable[int(spawns[e]["tile"])] == 0:
				off_land += 1
		t.eq(off_land, 0, "섬 %d 의 적은 전부 걸을 수 있는 칸에 서 있다" % (i + 1))

		# -- 8.3: the coast the enemy cannot see, and the cheap beach ---------------------------------
		# ⚠⚠ **This is the row that stops the cheapest beach ALSO being the quietest one.** With
		# unlimited free boats (`plan-then-watch`, OPEN 0) the cheapest beach is where everything goes,
		# so 「the shortest crossing is also the one nobody is watching」 is an advantage with no cost —
		# the exact shape that killed the second game. **It was asserted in prose for one round and a
		# sentence in a plan cannot redden; this is that sentence as two literals.**
		# ⚠ **Do NOT maximise the cover.** A greedy cover reaches zero uncovered tiles on all three
		# islands at these counts, but only by putting every enemy on the shore — which deletes the
		# 「quiet shore」 plan outright and with it one of the probe's discriminating axes. **The number
		# is a design choice, not a bound**, so it is pinned exactly rather than bounded above.
		var uncovered := 0
		for tile_u in grid.landable.size():
			if grid.landable[tile_u] == 0:
				continue
			if not _seen_by_any(grid, spawns, tile_u):
				uncovered += 1
		t.eq(uncovered, int(EXPECT_UNCOVERED_COAST[i]),
			"섬 %d 의 아무 적에게도 안 걸리는 해안 칸 수" % (i + 1))
		t.ok(uncovered > 0,
			"섬 %d — 그래도 조용한 해안이 남아 있다 (바닥 — 0이면 「적 없는 곳」 정책이 없어진다)"
			% (i + 1))
		t.ok(uncovered < int(EXPECT_COAST[i]),
			"섬 %d — 그리고 해안 전부가 조용하지는 않다 (천장)" % (i + 1))
		# The half with the plan in it: the single cheapest tile a boat can be sent to from the start
		# harbour has to be inside SOME detect circle. `EXPECT_WAVE1[i][0]` is that crossing.
		var cheap_tile := -1
		var cheap_d := 0.0
		var start_origin := grid.tile_point(int(grid.harbour_tiles[grid.start_harbour]))
		var start_send: PackedByteArray = grid.sendable[grid.start_harbour]
		for tile_c in start_send.size():
			if start_send[tile_c] == 0:
				continue
			var dc: float = start_origin.distance_to(grid.tile_point(tile_c))
			if cheap_tile == -1 or dc < cheap_d - Rules.EPS:
				cheap_tile = tile_c
				cheap_d = dc
		t.ok(absf(cheap_d - float(EXPECT_WAVE1[i][0])) <= 0.02,
			"섬 %d — 가장 싼 상륙지의 항해가 %.2f칸이다 (자가 점검 — EXPECT_WAVE1 의 최솟값과 같다)"
			% [i + 1, cheap_d])
		t.ok(_seen_by_any(grid, spawns, cheap_tile),
			"섬 %d — 가장 싼 상륙지가 어느 적의 탐지 원 안에 있다 (싼 해안과 조용한 해안이 같은 곳이면 안 된다)"
			% (i + 1))

		# -- 4.5: every sendable (union) tile sits in a big enough passable region -------------------
		var comp_id := PackedInt32Array()
		comp_id.resize(grid.passable.size())
		comp_id.fill(-1)
		var comp_size: Array = []
		for tile0 in grid.passable.size():
			if grid.passable[tile0] == 0 or comp_id[tile0] != -1:
				continue
			var members := PackedInt32Array()
			var stack := PackedInt32Array()
			stack.append(tile0)
			comp_id[tile0] = comp_size.size()
			while not stack.is_empty():
				var tt: int = stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				members.append(tt)
				var ttx := tt % grid.w
				var tty := tt / grid.w
				for k in Grid.NEIGHBOURS.size():
					var nx := ttx + int(Grid.NEIGHBOURS[k][0])
					var ny := tty + int(Grid.NEIGHBOURS[k][1])
					if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
						continue
					var nt := ny * grid.w + nx
					if grid.passable[nt] != 0 and comp_id[nt] == -1:
						comp_id[nt] = comp_size.size()
						stack.append(nt)
			comp_size.append(members.size())
		var too_small: Array = []
		var min_region := -1
		for tile in union.size():
			if union[tile] == 0:
				continue
			var sz: int = comp_size[comp_id[tile]]
			if min_region < 0 or sz < min_region:
				min_region = sz
			if sz < min_region_floor:
				too_small.append(tile)
		t.eq(too_small.size(), 0,
			"섬 %d — 상륙 가능한 모든 칸이 %d칸 이상인 땅에 있다 (배 하나를 못 내려주는 좁은 곶이 없다) %s"
			% [i + 1, min_region_floor, str(too_small)])
		t.ok(min_region >= min_region_floor,
			"섬 %d 에서 가장 좁은 상륙지의 땅이 %d칸이다" % [i + 1, min_region])

		# -- the walker: every union-sendable tile reaches every enemy's attack range ------------------
		# ⚠ **Only the enemy being walked to is reserved for that pair — never the whole spawn list at
		# once.** This is `net_islands`' own prior version (the plan's dock-to-enemy version) and it
		# measures whether the ISLAND can be crossed — pure terrain, not a transient occupancy claim.
		var reach := Rules.range_of(Rules.CELL_MELEE) + Rules.REACH_BONUS
		var unreached: Array = []
		var fields: Array = []
		for e in spawns.size():
			fields.append(grid.flow_field(int(spawns[e]["tile"])))
		for tile in union.size():
			if union[tile] == 0:
				continue
			for e in spawns.size():
				var res := _reaches(grid, tile, int(spawns[e]["tile"]), reach, fields[e])
				walker_pairs += 1
				walker_steps += int(res["steps"])
				if not bool(res["ok"]):
					unreached.append("칸%d→적%d" % [tile, e])
		t.eq(unreached.size(), 0,
			"섬 %d — 배로 닿는 모든 해안에서 모든 적의 사거리 안까지 실제로 걸어간다 %s" % [i + 1, str(unreached)])

		# -- the STRICT walker: every enemy reserved at once, the way a live `battle.setup` does -------
		# This is a genuinely different, weaker property, and it is checked separately rather than
		# folded into the check above so that trading it away is visible, not silent. Bison standing
		# close together make the flow-field-optimal route from some (tile, enemy) pairs run through
		# ANOTHER bison's own tile, and the walker jams there.
		#
		# ⚠⚠ **Why that is not a stall, as a CHECK rather than as a paragraph.** Soldiers carry
		# `Rules.NO_DETECT`, so `_nearest_enemy` has no radius to respect and always targets the
		# closest living enemy: if the blocker is NEARER to the walk's start than the target is, a real
		# soldier is sent at the blocker first, the blocker dies, `reserved` frees its tile and the
		# path opens. **The previous round certified that by hand over 14 pairs and wrote the finding
		# in a comment. There are 63 now** — and a comment cannot redden, so the property is measured
		# on every blocked pair instead. A pair where the target is the nearest enemy of all is the
		# one that would really stall, and there must be none.
		var strict_unreached := 0
		var strict_with_no_nearer_blocker := 0
		for tile in union.size():
			if union[tile] == 0:
				continue
			for e in spawns.size():
				# Reserved fresh before EVERY walk: `_reaches` releases the bare `Battle.ENEMY_UID_BASE`
				# tag it adds for its own target on the way out, so leaving this outside the inner loop
				# would silently drop the previous target's reservation before the next enemy is tried.
				_reserve_all(grid, spawns)
				var res2 := _reaches(grid, tile, int(spawns[e]["tile"]), reach, fields[e])
				if not bool(res2["ok"]):
					strict_unreached += 1
					if not _a_nearer_enemy_exists(grid, spawns, tile, e):
						strict_with_no_nearer_blocker += 1
			for e in spawns.size():
				grid.release_all(Battle.ENEMY_UID_BASE + e)
		t.eq(strict_unreached, int(EXPECT_STRICT_UNREACHED[i]),
			"섬 %d — 적을 전부 동시에 예약해도 못 닿는 짝의 수 (엄격판, 참고용)" % (i + 1))
		t.eq(strict_with_no_nearer_blocker, 0,
			"섬 %d — 그 짝들은 전부 더 가까운 적이 따로 있다 — 병사는 막은 쪽을 먼저 치고 길이 열린다" % (i + 1))

	t.ok(walker_pairs > 0, "걸어본 칸-적 짝이 실제로 있다 (%d개)" % walker_pairs)
	t.ok(walker_steps > 0, "그 걷기들은 실제로 칸을 넘었다 (총 %d칸)" % walker_steps)

	_self_check(t)


# -- the instrument's own failing cases -------------------------------------------------------------

func _self_check(t) -> void:
	var short_rows := ["....", "...", "...."]
	t.ok(_shape_errors(short_rows, 3, 4).size() >= 1, "모양 검사기는 짧은 행을 잡는다 (자가 점검)")
	t.ok(_shape_errors(short_rows, 4, 4).size() >= 2, "모양 검사기는 행 수도 센다 (자가 점검)")
	t.eq(_shape_errors(["....", "...."], 2, 4).size(), 0,
			"모양 검사기는 멀쩡한 격자를 잡지 않는다 — 전부 빨개지는 검사기가 아니다 (자가 점검)")

	t.ok(_illegal_chars(["~H.#^/,BCL"]).size() == 1, "범례 검사기는 쉼표를 잡는다 (자가 점검)")
	t.eq(_illegal_chars(["~H.#^/BCL"]).size(), 0, "범례 안의 글자는 안 잡는다 (자가 점검)")

	# Column 0 is all water. Counting it would make every island's cut 0 and the number above would be
	# unfalsifiable.
	var cut_grid := Grid.new()
	cut_grid.load_rows(["~...", "~#..", "~#..", "~..."])
	t.eq(_cut_of(cut_grid), 2, "절단 계산기는 통과 가능 칸이 0인 열을 건너뛴다 (자가 점검)")

	# A wall sealing off one enemy entirely — not merely awkward to reach. A greedy dead end would not
	# bite a BFS walker, which is why the fixture is a sealed wall rather than a twisty corridor.
	var fx := Grid.new()
	fx.load_rows([
		"~~~~~~~~~~~~",
		"~H....~....~",
		"~.....~....~",
		"~..B..~..C.~",
		"~.....~....~",
		"~~~~~~~~~~~~",
	])
	var fx_spawns := [
		{"type_id": Rules.BISON, "tile": 3 * 12 + 3},
		{"type_id": Rules.CROW, "tile": 3 * 12 + 9},
	]
	var reach := Rules.range_of(Rules.CELL_MELEE) + Rules.REACH_BONUS
	var f0 := fx.flow_field(int(fx_spawns[0]["tile"]))
	var f1 := fx.flow_field(int(fx_spawns[1]["tile"]))
	var near := _reaches(fx, 1 * 12 + 1, int(fx_spawns[0]["tile"]), reach, f0)
	var sealed := _reaches(fx, 1 * 12 + 1, int(fx_spawns[1]["tile"]), reach, f1)
	t.ok(bool(near["ok"]), "픽스처에서 벽 이쪽의 적에게는 걸어간다 (자가 점검)")
	t.ok(int(near["steps"]) > 0, "그 걷기는 실제로 칸을 넘었다 (%d칸, 자가 점검)" % int(near["steps"]))
	t.ok(not bool(sealed["ok"]), "벽 저쪽에 갇힌 적에게는 못 간다고 말한다 (자가 점검)")


# -- scanners ------------------------------------------------------------------------------------

func _shape_errors(rows: Array, want_h: int, want_w: int) -> Array:
	var out: Array = []
	if rows.size() != want_h:
		out.append("행 수 %d" % rows.size())
	for y in rows.size():
		var n := str(rows[y]).length()
		if n != want_w:
			out.append("%d행 %d자" % [y, n])
	return out


func _illegal_chars(rows: Array) -> Array:
	var out: Array = []
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			if LEGEND.find(row[x]) == -1:
				out.append("(%d,%d)='%s'" % [x, y, row[x]])
	return out


func _count_char(rows: Array, ch: String) -> int:
	var n := 0
	for y in rows.size():
		n += str(rows[y]).count(ch)
	return n


## The narrowest cut, per the definition pinned in the first slice plan under "The islands", now over
## 48-wide rows.
func _cut_of(grid: Grid) -> int:
	var best := -1
	for x in grid.w:
		var n := 0
		for y in grid.h:
			if grid.passable[y * grid.w + x] != 0:
				n += 1
		if n == 0:
			continue
		if best == -1 or n < best:
			best = n
	return best


## The smallest passable region a sendable tile may sit in without risking the silent stall the header
## names. **Demand, not cargo**: with boats created per drag (`plan-then-watch`, 4.2) every living
## soldier can aim at ONE region on one sub-step, so the floor is the largest roster a run can ever
## field plus one tile of margin for a neighbour already occupied when the last boat arrives.
##
## ⚠ **Read off `Rules`, never hardcoded**, so a bigger roster moves the floor instead of leaving it
## behind — and never derived from the thing it checks, which is the shape that shrinks with its
## subject.
## ⚠⚠ **Every count node on the route, not one.** This counted a SINGLE reward application while the
## map lets a route step on `map_max_count_nodes_on_a_route()` of them — the same arithmetic
## `look.gd`'s roster comment already states as `10 + 3 * 3 = 19`. The plan's fix was applied to
## `look.gd` and not to its sibling here, which is this repo's named "the plan's own fix gets applied
## to one value and not to its siblings": it does not bite on the three shipped grids (smallest region
## is in the hundreds) and a new grid with a 15-tile landing region would pass green and stall a boat
## forever.
func _min_region_floor() -> int:
	return Rules.START_MELEE + Rules.START_RANGED \
		+ Rules.map_max_count_nodes_on_a_route() * (Rules.REWARD_MELEE + Rules.REWARD_RANGED) + 1


## Is tile `t` inside any spawned enemy's detect circle? Read off `Rules.detect_of` rather than a
## number written down here — a second copy of the radius is a second thing to keep in step, and the
## one that is not the rule is the one that rots.
func _seen_by_any(grid: Grid, spawns: Array, t: int) -> bool:
	if t < 0:
		return false
	var p := grid.tile_point(t)
	for raw in spawns:
		var s: Dictionary = raw
		var d := Rules.detect_of(int(s["type_id"]))
		if d <= 0.0:
			continue
		if p.distance_to(grid.tile_point(int(s["tile"]))) <= d:
			return true
	return false


## Is some OTHER enemy strictly nearer to `from_tile` than enemy `e` is? That is the whole of why a
## strict-walker jam is not a stall: `_nearest_enemy` picks the closest living enemy and soldiers have
## no detect radius, so the blocker is fought first and its tile frees.
func _a_nearer_enemy_exists(grid: Grid, spawns: Array, from_tile: int, e: int) -> bool:
	var p := grid.tile_point(from_tile)
	var target_d := p.distance_to(grid.tile_point(int((spawns[e] as Dictionary)["tile"])))
	for k in spawns.size():
		if k == e:
			continue
		if p.distance_to(grid.tile_point(int((spawns[k] as Dictionary)["tile"]))) < target_d - Rules.EPS:
			return true
	return false


# -- the walk --------------------------------------------------------------------------------------

## Reserves ONE enemy's own tile — see the comment above the (non-strict) walker loop for why this is
## the terrain-only tile, not the whole list at once.
func _reserve_one(grid: Grid, tile: int, uid: int) -> void:
	var claimed := grid.reserved
	if tile >= 0 and tile < claimed.size():
		claimed[tile] = uid
	grid.reserved = claimed


## Reserves every spawn's own tile at once, each under its own id (`Battle.ENEMY_UID_BASE + e`, the
## same convention `battle.setup` uses) — the STRICT walker's fixture, matching a live fight.
func _reserve_all(grid: Grid, spawns: Array) -> void:
	var claimed := grid.reserved
	for e in spawns.size():
		var tile := int(spawns[e]["tile"])
		if tile >= 0 and tile < claimed.size():
			claimed[tile] = Battle.ENEMY_UID_BASE + e
	grid.reserved = claimed


## Walks the game's own functions from `start_tile` toward `enemy_tile`, given that enemy's already-
## built flow field, and reports whether the walker ever got within `reach`. Reserves `enemy_tile` for
## the walk (a unit cannot be walked ONTO, only approached) and releases everything on the way out.
func _reaches(grid: Grid, start_tile: int, enemy_tile: int, reach: float, field: PackedInt32Array) -> Dictionary:
	grid.release_all(WALKER_ID)
	_reserve_one(grid, enemy_tile, Battle.ENEMY_UID_BASE)
	var goal := grid.tile_point(enemy_tile)
	var pos := grid.tile_point(start_tile)
	var steps := 0
	var arrived := pos.distance_to(goal) <= reach + Rules.EPS
	while not arrived and steps < WALK_STEPS_MAX:
		var next_pos: Vector2 = grid.step_toward(WALKER_ID, pos, field)
		if next_pos.distance_to(pos) <= Rules.EPS:
			break
		pos = next_pos
		steps += 1
		arrived = pos.distance_to(goal) <= reach + Rules.EPS
	grid.release_all(WALKER_ID)
	grid.release_all(Battle.ENEMY_UID_BASE)
	return {"ok": arrived, "steps": steps, "tile": grid.tile_index(int(round(pos.x)), int(round(pos.y)))}


# -- the floor's only bite ---------------------------------------------------------------------------

## ⚠⚠ **The guarded assertion cannot redden on the shipped islands under ANY formula, and that was
## already true before the roster rewrite.** Every island is ONE connected passable component — 744,
## 760 and 716 tiles — so moving the floor between 2, 5, 6 and 14 never crosses 716 and the mutation
## moves nothing but the self-check one line above. ⇒ **The floor is given a bite the way the
## sealed-enemy fixture gives the walker one: a synthetic `Grid` with a pocket of exactly 13 passable
## tiles holding a sendable tile.** The roster floor must REJECT it and the old capacity floor of 5
## must ACCEPT it — which is the whole difference between the two formulas, stated as a number.
func _the_floor_actually_rejects_something(t, floor_now: int) -> void:
	var g := Grid.new()
	g.load_rows([
		"~~~~~~~~~~~~~~~~",
		"~....~~~~~~~~~~~",
		"~....~~~~~~~~~~~",
		"~....~~~~~~~~~~~",
		"~.~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~H~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
	])
	var pocket := 0
	for tile in g.passable.size():
		if g.passable[tile] != 0:
			pocket += 1
	t.eq(pocket, 13, "합성 주머니는 정확히 13칸이다 (자가 점검)")

	var sendable_here := -1
	for tile in g.passable.size():
		if g.home_harbour_for(tile) >= 0:
			sendable_here = tile
			break
	t.ok(sendable_here >= 0, "그 주머니 안에 보낼 수 있는 칸이 실제로 있다 (자가 점검)")
	t.eq(_component_size(g, sendable_here), pocket,
			"그 칸이 든 땅덩이가 주머니 전부다 — 하나의 연결 성분이다 (자가 점검)")

	t.ok(pocket < floor_now,
			"상륙 구역은 최대 병력보다 크다 — 13칸 주머니는 지금 바닥(%d)에 걸린다" % floor_now)
	t.ok(pocket >= 5,
			"그리고 옛 정원 바닥 5는 그 주머니를 통과시켰다 — 두 식의 차이가 여기서 갈린다")


func _component_size(g: Grid, seed_tile: int) -> int:
	var seen := PackedByteArray()
	seen.resize(g.w * g.h)
	var stack := [seed_tile]
	seen[seed_tile] = 1
	var n := 0
	while not stack.is_empty():
		var tile: int = stack.pop_back()
		n += 1
		var tx := tile % g.w
		var ty := tile / g.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			var nt := ny * g.w + nx
			if seen[nt] == 0 and g.passable[nt] != 0:
				seen[nt] = 1
				stack.append(nt)
	return n
