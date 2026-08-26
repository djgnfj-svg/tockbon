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
## ⚠⚠ **EVERY NUMBER IN THIS FILE WAS RE-MEASURED BY `speed-off-open-landing`, INCLUDING THE ROWS
## THAT WERE NOT MAKING A DRAMATIC CLAIM.** Landing became a denylist and `home_harbour_for` stopped
## ranking by straight-line distance, so BOTH the domain these figures are defined over and the metric
## they are measured in moved on the same day. Re-measuring only the rows that failed is this repo's
## own named failure — one table once shipped a quiet row off by a factor of twenty-four because it
## was not the row anybody was arguing about.
##
## What moved, and why:
##  · `EXPECT_SENDABLE` / `_UNION` / `EXPECT_DROPPABLE` / `EXPECT_START_SENDABLE` — the DOMAIN. Every
##    8-way coast tile is sendable now and all three harbours agree, because all water on all three
##    islands is one connected body
##  · `EXPECT_COAST` — was the ORTHO coast under the old `landable`; it is the 8-WAY coast now, and
##    `EXPECT_COAST_ORTHO` is kept beside it as a second literal so the two can be shown to DIFFER
##  · `EXPECT_WAVE1` / `EXPECT_STEADY` — the METRIC. A crossing is the length of the water route the
##    boat actually sails, not the Euclidean line it no longer takes
##  · `EXPECT_RELOCATES` — both at once: more tiles, ranked by hops instead of distance
##  · `EXPECT_STRICT_UNREACHED` — the walker runs over 1.7x the tiles, so island 2 went 0 -> 128
##
## **"Steady state" is still `route(home_harbour_for(t), t)` over tiles the START harbour can reach**,
## never the union across all three harbours — the union includes tiles only reachable after a
## relocation, which are not wave-1 landings at all. That distinction survived the rewrite; on these
## three islands the two sets now happen to coincide, and the code still says which one it means.
##
## **This net drives `grid.flow_field` and `grid.step_toward` and never carries a walker of its own** —
## the same reason the first-slice plan gives: a walker with its own BFS measures the walker, not
## whether the real game's units can cross this ground.


## ⚠ **`B` and `C` became `S` (방패병) and `A` (궁수)** when 소 and 까마귀 moved to the player's side.
## The letters changed WITH the meaning rather than being re-pointed under the same name: this repo
## has paid twice for a name that outlived its sense (「부위」 and 「다리」).
const LEGEND := "~H.#^/SAL"

const EXPECT_ROWS := 32
const EXPECT_COLS := 48

## Every one of these was reproduced by an independent reimplementation, not merely read back off
## `Grid` — see the header.
const EXPECT_HARBOUR_TILES := [[1337, 1398, 1512], [1382, 1402, 1514], [1303, 1432, 1512]]
const EXPECT_START_TILE := [1512, 1514, 1512]
## Per-harbour sendable counts, in harbour-index order. ⚠ **All three harbours now agree on every
## island**, because all water on all three is ONE connected body — that is the finding that made the
## whole coast landable, and it is asserted rather than assumed (`EXPECT_WATER` below plus the
## byte-for-byte equality check).
const EXPECT_SENDABLE := [[84, 84, 84], [76, 76, 76], [82, 82, 82]]
const EXPECT_SENDABLE_UNION := [84, 76, 82]
## ⚠ **The 8-WAY coast**, which is what the denylist opens. `speed-off-open-landing` 2.1's own table.
const EXPECT_COAST := [84, 76, 82]
## The ORTHO coast, kept as a SECOND literal for one job only: proving the two are different numbers
## on islands 0 and 2. Under the old `landable` this WAS `EXPECT_COAST`; a suite that dropped it could
## not tell an 8-way rule from a 4-way one on island 1, where they coincide at 76.
const EXPECT_COAST_ORTHO := [82, 76, 80]
## From `speed-off-open-landing` 2.1, typed in by hand and never read off the grid under test.
## `EXPECT_PASSABLE` minus the sendable count is the INLAND refusal set — 660 · 684 · 634 — which is
## what pins the denylist by SIZE and not only by membership.
const EXPECT_PASSABLE := [744, 760, 716]
const EXPECT_WATER := [724, 690, 726]
## What the rule used to give, and what merely dropping coast-adjacency would have given. Neither is
## the answer, and the second is the trap: 97 > 84 is a BIGGER number that is the WRONG set — its
## extra tiles are one tile INLAND while it still refuses 40% of the actual shore.
const EXPECT_OLD_SENDABLE := [50, 44, 48]
const EXPECT_COAST_ADJACENCY_DROPPED := [97, 83, 94]
const EXPECT_CUTS := [15, 2, 10]
## ⚠ **RAISED by `plan-then-watch` stage 4 — 4 · 6 · 5 became 8 · 12 · 14**, by adding characters to
## `islands.gd` rows and nothing else (`spawns_of` is a scan, so an added `B` is an added enemy with
## no table to widen). The old counts could not lose an island: the probe's baseline plan won all
## fifteen island-runs, and its worst island spent under a third of its limit.
const EXPECT_SPAWNS := [8, 12, 14]
## Wave-1 crossing, tiles: min/max **WATER ROUTE LENGTH** from the START harbour over every tile it
## can reach. ⚠ **These were Euclidean distances and that is now the wrong metric** — a boat sails a
## polyline around headlands, so the straight line prices a crossing nobody makes. Re-measured, not
## adjusted.
## ⚠⚠ **RE-MEASURED AGAIN by the route smoother** (round 3): `water_route` now string-pulls the BFS
## waypoints, dropping every one whose removal leaves a straight segment entirely over water. Every
## crossing on every island got shorter and none got longer. **All 242 routes were re-derived outside
## Godot from a from-scratch reimplementation of the smoother — including GDScript's own
## round-half-away-from-zero, which Python's banker's rounding does not share — and compared tile for
## tile against the engine: 242 of 242 agree to 1e-3.** That cross-check is the whole warrant for
## typing new numbers into a table this file's own header warns about re-measuring by halves.
const EXPECT_WAVE1 := [[11.85, 42.99], [11.20, 44.83], [13.08, 42.99]]
## Steady-state crossing: min/max route length from `home_harbour_for(t)` over the SAME start-sendable
## tiles as `EXPECT_WAVE1` — never the union over all harbours, which includes tiles unreachable until
## after a relocation and so is not "the next crossing to a landing you already hold".
## ⚠ Moved by the smoother too, and by different amounts per island: 9.49/29.31 -> 7.41/27.98,
## 10.90/30.97 -> 8.41/30.14, 9.49/29.73 -> 7.41/28.23.
const EXPECT_STEADY := [[7.41, 27.98], [8.41, 30.14], [7.41, 28.23]]
## How many of the start-sendable tiles relocate the fleet away from the start harbour (i.e.
## `home_harbour_for(t) != start_harbour`), out of the start-sendable count itself (84, 76, 82).
## ⚠ Re-measured twice over: the domain grew AND the ranking became hop count instead of distance.
const EXPECT_RELOCATES := [66, 73, 76]
## The strict walker's own count — every enemy reserved simultaneously, matching a live
## `battle.setup`. Only island 2 has any (bison sitting close enough together jam the walker on each
## other's tiles); see the comment above that check for why this is a real but different, weaker
## property than the terrain-only walker above it.
## ⚠ **RE-MEASURED AGAIN by `speed-off-open-landing`: 0 · 63 · 0 became 0 · 119 · 128.** Nothing about
## the walker changed; the DOMAIN did. It runs over every sendable tile, and that set went from
## 50 · 44 · 48 to 84 · 76 · 82, so island 3's whole east shore entered the scan for the first time and
## brought its bison jams with it. **The number is reported, not judged** — what makes these benign is
## the check one line below it (`strict_with_no_nearer_blocker == 0`), which still holds on all three.
const EXPECT_STRICT_UNREACHED := [0, 119, 128]

## How many SENDABLE coast tiles sit inside NO enemy's detect circle (`plan-then-watch`, 8.3).
## ⚠ Re-measured over the wider 8-way coast and it did not move — the two tiles islands 0 and 2 gained
## are both already covered. **That it did not move is a measurement, not a reason to have skipped
## it.**
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
## refuses on**, so the shell's refusal mark can never deny a tile the sim allows. ⚠ It is no longer
## "the predicate the droppable overlay is drawn from": that overlay is deleted (question C — the
## screen marks what is BLOCKED and nothing else), so `send` is the only other reader.
##
## **These three literals come from `speed-off-open-landing` 2.1's measurement table, typed by hand.**
## They are never read back off the grid under test — a ceiling whose bound comes from the thing it
## checks measures nothing.
const EXPECT_DROPPABLE := [84, 76, 82]
const EXPECT_START_SENDABLE := [84, 76, 82]

## The island's clock. ⚠ **Nothing loses by it** — the user deleted the time-limit loss on 2026-08-24.
const EXPECT_LIMIT := 20.0

## Ceiling on tiles crossed in one walk, matching `battle.gd`'s `WALK_TILES_MAX` order of magnitude on
## a grid 2.67x the old one's tile count.
const WALK_STEPS_MAX := 900
const WALKER_ID := 999_999


## ⚠⚠ **THERE IS ONE ISLAND** (2026-08-26). Seven were deleted with the node map — three hand-authored
## rectangles, one generated 144-wide map and four generated compact ones — because the user could not
## draw eight. Every 48 x 32 expectation that used to live here went with them.
const ROW_COUNT := 12
const ROW_WIDTH := 16


func run(t) -> void:
	# ⚠ **Read through the accessors, because the board is a FILE now** (2026-08-26) — the letter grid
	# left `islands.gd` when Blender became the source of the island. A net naming the old consts would
	# not just fail; it would be asserting that the board still lives in the game.
	var rows := Islands.rows()
	var tiers := Islands.tiers()
	t.eq(rows.size(), ROW_COUNT, "섬은 열두 줄이다")
	t.eq(tiers.size(), ROW_COUNT, "층 판도 같은 줄 수다")
	for y in rows.size():
		t.eq(str(rows[y]).length(), ROW_WIDTH, "%d 번째 줄이 %d 칸이다" % [y, ROW_WIDTH])
		t.eq(str(tiers[y]).length(), ROW_WIDTH, "층 판 %d 번째 줄도 같다" % y)
	t.eq(Islands.time_limit(), EXPECT_LIMIT, "섬의 제한 시간은 %.0f초다" % EXPECT_LIMIT)

	var min_region_floor := _min_region_floor()
	# ⚠ The 27 is a LITERAL on purpose. Writing the formula on both sides would let the roster grow and
	# the expectation grow with it, which is the shape that proves nothing.
	# ⚠⚠ **38 -> 26** (2026-08-26): the node rewards are deleted with the map, so a run grows on cards
	# alone — 10 in the opening slot plus four species arriving with `SPECIES_CARD_BODIES` each.
	t.eq(min_region_floor, 27, "가장 좁아도 되는 상륙지 바닥은 27칸이다 (최대 병력 26 + 여유 1) — 자가 점검")
	t.eq(_max_roster(), 26, "그 최대 병력 26이 10 + 짐승 카드 넷 x 4 다 (자가 점검)")
	_the_floor_actually_rejects_something(t, min_region_floor)

	var walker_pairs := 0
	var walker_steps := 0
	for i in 1:
		# ⚠⚠ **Named `board`, not `rows`.** A second `var rows` here shadowed the one declared at the
		# top of this function, and GDScript refuses to parse a shadowed local — so THE WHOLE FILE
		# failed to compile and the round reported `islands 통과 0`. A net that cannot be parsed is the
		# loudest kind of nothing: it asserts nothing at all while looking like one line of red.
		var board := Islands.rows()
		var shape := _shape_errors(board, EXPECT_ROWS, EXPECT_COLS)
		t.eq(shape.size(), 0, "섬 %d 은 %d행 x %d자다 %s" % [i + 1, EXPECT_ROWS, EXPECT_COLS, str(shape)])
		var illegal := _illegal_chars(board)
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

		# ⚠ **The 8-way coast, built locally from `passable` + `water`, and NOT read off `sendable`.**
		# `grid.landable` is deleted; recomputing the set here from the two primitive tables is what
		# makes the next check ("every one of them is sendable") a real claim instead of a tautology.
		var coast8 := PackedByteArray()
		coast8.resize(grid.passable.size())
		var coast := 0
		var coast_ortho := 0
		for tile in grid.passable.size():
			if grid.passable[tile] == 0:
				continue
			var tx := tile % grid.w
			var ty := tile / grid.w
			var touch8 := false
			var touch4 := false
			for k in Grid.NEIGHBOURS.size():
				var nx := tx + int(Grid.NEIGHBOURS[k][0])
				var ny := ty + int(Grid.NEIGHBOURS[k][1])
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				if grid.water[ny * grid.w + nx] == 0:
					continue
				touch8 = true
				if int(Grid.NEIGHBOURS[k][0]) == 0 or int(Grid.NEIGHBOURS[k][1]) == 0:
					touch4 = true
			if touch8:
				coast8[tile] = 1
				coast += 1
			if touch4:
				coast_ortho += 1
		t.eq(coast, int(EXPECT_COAST[i]), "섬 %d — 8방향으로 물에 닿은 땅이 %d칸이다" % [i + 1, int(EXPECT_COAST[i])])
		t.eq(coast_ortho, int(EXPECT_COAST_ORTHO[i]),
			"섬 %d — 직교로만 세면 %d칸이다" % [i + 1, int(EXPECT_COAST_ORTHO[i])])

		var passable_n := 0
		var water_n := 0
		for tile in grid.passable.size():
			if grid.passable[tile] != 0:
				passable_n += 1
			if grid.water[tile] != 0:
				water_n += 1
		t.eq(passable_n, int(EXPECT_PASSABLE[i]), "섬 %d 의 땅은 %d칸이다" % [i + 1, int(EXPECT_PASSABLE[i])])
		t.eq(water_n, int(EXPECT_WATER[i]), "섬 %d 의 물은 %d칸이다" % [i + 1, int(EXPECT_WATER[i])])

		var cut := _cut_of(grid)
		t.eq(cut, int(EXPECT_CUTS[i]), "섬 %d 의 최협 절단" % (i + 1))

		var union := PackedByteArray()
		union.resize(grid.passable.size())
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

		# ⚠⚠ **The three harbours see the SAME coast, byte for byte** — that is what "all water on
		# this island is one connected body" looks like from the outside, and it is the finding the
		# whole denylist stands on. Compared as whole arrays rather than as counts: three harbours
		# reaching 84 tiles EACH could still be three different 84s.
		for hb2 in range(1, grid.harbour_tiles.size()):
			t.eq(grid.sendable[hb2], grid.sendable[0],
				"섬 %d — 항구 %d 가 항구 0 과 완전히 같은 해안을 본다 (물이 하나로 이어져 있다)" % [i + 1, hb2])
		# And every water tile really is reachable from every harbour — the floor under the equality
		# above, because three EMPTY sendable tables are also byte-for-byte equal.
		var unreachable_water := 0
		for hb3 in grid.harbour_tiles.size():
			var wf: PackedInt32Array = grid.water_fields[hb3]
			for tile_w in grid.water.size():
				if grid.water[tile_w] != 0 and int(wf[tile_w]) == Grid.UNREACHABLE:
					unreachable_water += 1
		t.eq(unreachable_water, 0,
			"섬 %d — 어느 항구에서 출발해도 물 %d칸 전부에 닿는다" % [i + 1, int(EXPECT_WATER[i])])

		# ⚠ **Counted through `home_harbour_for`, not through `sendable`.** They agree today and that is
		# the point: `send` refuses on `home_harbour_for(tile) < 0` and the droppable overlay is painted
		# from the same call, so this is the number the PLAYER is offered. Reading `sendable` again here
		# would be the row above under a second name, and a `home_harbour_for` that collapsed to one
		# harbour would leave it green.
		var droppable := 0
		for tile in grid.passable.size():
			if grid.home_harbour_for(tile) >= 0:
				droppable += 1
		t.eq(droppable, int(EXPECT_DROPPABLE[i]),
			"섬 %d — 배를 보낼 수 있는 칸이 정확히 %d칸이다" % [i + 1, int(EXPECT_DROPPABLE[i])])

		# ⚠⚠ **THE FLOOR — 「어디든지」의 절반.** Without it a rule that opened only HALF the coast
		# would still hit the count above by opening inland tiles instead. The misses are collected so
		# a failure names the tiles rather than only the size.
		var coast_misses: Array = []
		for tile in coast8.size():
			if coast8[tile] != 0 and grid.home_harbour_for(tile) < 0:
				coast_misses.append(tile)
		t.eq(coast_misses.size(), 0,
			"섬 %d — 8방향으로 물에 닿은 땅은 전부 보낼 수 있다, 한 칸도 안 빠진다 %s" % [i + 1, str(coast_misses)])
		t.eq(coast, int(EXPECT_DROPPABLE[i]),
			"섬 %d — 그리고 그 해안 칸 수가 보낼 수 있는 칸 수와 같다 (두 집합이 정확히 겹친다)" % (i + 1))

		# ⚠⚠ **THE CEILING.** Without it the whole island going sendable passes every count-based
		# check above by inflating both sides at once. Pinned by SIZE as well as by membership.
		var inland_open: Array = []
		var inland_refused := 0
		for tile in grid.passable.size():
			if grid.passable[tile] == 0 or coast8[tile] != 0:
				continue
			inland_refused += 1
			if grid.home_harbour_for(tile) >= 0:
				inland_open.append(tile)
		t.eq(inland_open.size(), 0,
			"섬 %d — 물에 안 닿은 내륙 칸은 여전히 전부 거절된다 %s" % [i + 1, str(inland_open)])
		t.eq(inland_refused, int(EXPECT_PASSABLE[i]) - int(EXPECT_DROPPABLE[i]),
			"섬 %d — 거절되는 내륙이 %d칸이다 (%d - %d)"
			% [i + 1, int(EXPECT_PASSABLE[i]) - int(EXPECT_DROPPABLE[i]),
				int(EXPECT_PASSABLE[i]), int(EXPECT_DROPPABLE[i])])

		# Cliffs, from the ROWS rather than from `passable`, so the check names the legend character
		# the design argues about. The fixture floor first: an island with no cliffs proves nothing.
		var cliff_n := 0
		var cliff_open: Array = []
		for y in rows.size():
			var crow := str(rows[y])
			for x in crow.length():
				if crow[x] != "^":
					continue
				cliff_n += 1
				var ct := y * grid.w + x
				if grid.passable[ct] != 0 or grid.home_harbour_for(ct) >= 0:
					cliff_open.append(ct)
		t.ok(cliff_n > 0, "섬 %d 에 절벽이 실제로 있다 (%d칸, 자가 점검)" % [i + 1, cliff_n])
		t.eq(cliff_open.size(), 0,
			"섬 %d — 절벽 칸은 지나갈 수도 없고 배도 못 받는다 %s" % [i + 1, str(cliff_open)])

		# ⚠ **Neither the old rule's answer nor the coast-adjacency one.** 97 > 84 and it is the WRONG
		# set — the plan says so in as many words, so the wrong-bigger-number is pinned as a literal
		# rather than left to be re-derived by whoever reads the table next.
		t.ok(droppable != int(EXPECT_OLD_SENDABLE[i]),
			"섬 %d — 예전 직선 규칙의 %d칸이 아니다" % [i + 1, int(EXPECT_OLD_SENDABLE[i])])
		t.ok(droppable != int(EXPECT_COAST_ADJACENCY_DROPPED[i]),
			"섬 %d — 해안 인접만 버린 %d칸도 아니다 (더 큰 수지만 틀린 집합이다)"
			% [i + 1, int(EXPECT_COAST_ADJACENCY_DROPPED[i])])

		# ⚠ Route length against the straight line it replaced. The floor is 「strictly longer
		# SOMEWHERE」: a polyline that is everywhere equal to the straight line IS the straight line.
		var strictly_longer := 0
		var shorter: Array = []
		var worst_ratio := 0.0
		for tile in grid.passable.size():
			var hb_r := grid.home_harbour_for(tile)
			if hb_r < 0:
				continue
			var rlen := _route_length(grid, hb_r, tile)
			var straight: float = grid.tile_point(int(grid.harbour_tiles[hb_r])).distance_to(
				grid.tile_point(tile))
			if rlen < straight - Rules.EPS:
				shorter.append(tile)
			elif rlen > straight + Rules.EPS:
				strictly_longer += 1
			if straight > Rules.EPS:
				worst_ratio = maxf(worst_ratio, rlen / straight)
		t.eq(shorter.size(), 0,
			"섬 %d — 항로가 직선보다 짧은 칸은 하나도 없다 %s" % [i + 1, str(shorter)])
		t.ok(strictly_longer > 0,
			"섬 %d — 그리고 %d칸에서는 실제로 더 길다 (최대 %.3f배) — 전부 같으면 그건 직선이다"
			% [i + 1, strictly_longer, worst_ratio])

		var start_hb := grid.start_harbour
		var start_sendable: PackedByteArray = grid.sendable[start_hb]
		var start_n := 0
		var wave1_min := -1.0
		var wave1_max := -1.0
		for tile in start_sendable.size():
			if start_sendable[tile] == 0:
				continue
			start_n += 1
			# ⚠ **The WATER ROUTE the boat sails, not the straight line.** Pricing wave 1 by a line no
			# boat takes is the same defect the probe's `_crossing_of` carried until this round.
			var d := _route_length(grid, start_hb, tile)
			if wave1_min < 0.0 or d < wave1_min:
				wave1_min = d
			if d > wave1_max:
				wave1_max = d
		t.eq(start_n, int(EXPECT_START_SENDABLE[i]),
			"섬 %d — 시작 항구 혼자 닿는 칸이 %d칸이다" % [i + 1, int(EXPECT_START_SENDABLE[i])])
		t.ok(absf(wave1_min - float(EXPECT_WAVE1[i][0])) <= 0.02,
			"섬 %d — 1파 최단 항로가 %.2f칸이다 (재측정: 직선이 아니라 물길 길이)" % [i + 1, wave1_min])
		t.ok(absf(wave1_max - float(EXPECT_WAVE1[i][1])) <= 0.02,
			"섬 %d — 1파 최장 항로가 %.2f칸이다 (재측정)" % [i + 1, wave1_max])

		# -- steady state: the SAME start-sendable tiles, distance from wherever the fleet relocates to
		var steady_min := -1.0
		var steady_max := -1.0
		var relocates := 0
		for tile in start_sendable.size():
			if start_sendable[tile] == 0:
				continue
			var home := grid.home_harbour_for(tile)
			var d2 := _route_length(grid, home, tile)
			if steady_min < 0.0 or d2 < steady_min:
				steady_min = d2
			if d2 > steady_max:
				steady_max = d2
			if home != start_hb:
				relocates += 1
		t.ok(absf(steady_min - float(EXPECT_STEADY[i][0])) <= 0.02,
			"섬 %d — 정착 후 최단 항로가 %.2f칸이다 (재측정)" % [i + 1, steady_min])
		t.ok(absf(steady_max - float(EXPECT_STEADY[i][1])) <= 0.02,
			"섬 %d — 정착 후 최장 항로가 %.2f칸이다 (재측정)" % [i + 1, steady_max])
		t.eq(relocates, int(EXPECT_RELOCATES[i]),
			"섬 %d — 1파 상륙지 중 함대가 항구를 옮기는 곳의 수" % (i + 1))

		var spawns := Islands.spawns()
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
		for tile_u in coast8.size():
			if coast8[tile_u] == 0:
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
		var start_send: PackedByteArray = grid.sendable[grid.start_harbour]
		for tile_c in start_send.size():
			if start_send[tile_c] == 0:
				continue
			# Priced by the route, the same way the probe's own policies price a beach — otherwise
			# "the cheapest beach" here and "the cheapest beach" there are two different tiles.
			var dc := _route_length(grid, grid.start_harbour, tile_c)
			if cheap_tile == -1 or dc < cheap_d - Rules.EPS:
				cheap_tile = tile_c
				cheap_d = dc
		t.ok(absf(cheap_d - float(EXPECT_WAVE1[i][0])) <= 0.02,
			"섬 %d — 가장 싼 상륙지의 항로가 %.2f칸이다 (자가 점검 — EXPECT_WAVE1 의 최솟값과 같다)"
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
		var reach := Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
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

	_every_spawn_is_an_enemy(t)
	_self_check(t)


# -- the long map ----------------------------------------------------------------------------------

## ⚠⚠ **This map exists to prove the CAPABILITY, not to be played** (`idea-inbox` row 52, the user:
## *"긴 맵 하나 하고 한 칸짜리 맵만 있으면 돼있듯 … 추후에 확장 가능하게 코딩만 해주고"*). It is not in
## `Rules.MAP_NODES` and no node opens it; what it has to do is LOAD, be sailed to, and be drawable.
##
## **Every literal here was derived outside Godot** from a from-scratch reimplementation of the same
## generator and of `grid.gd`'s water BFS — the same discipline the rest of this file's numbers were
## written under, and the only honest way to get a bound that is not read back off the thing it checks.
##
## ⚠ **The check that matters most is the last one**: every 8-way coast tile is sendable, exactly as
## on the three shipped islands. That is the denylist's own property, and it is what says the water
## rules did not quietly stop meaning anything at three times the width.
## **The net that says the move actually happened.** 소 and 까마귀 were the enemy's rows and are the
## player's now, so a leftover spawn character would put a beast back on the island fighting for the
## humans — and it would look completely ordinary on screen.
##
## ⚠ **Derived from the SIDE COLUMN, never from a list of names.** A roll call would have to be edited
## the day a row is added, and the row nobody edited is the one that gets through.
##
## ⚠ Mutation: put `Rules.WOLF` in `Islands.SPAWN_ROWS`; leave one `B` in a hand-written row (that one
## reddens the legend check above instead, which is the point of having both).
func _every_spawn_is_an_enemy(t) -> void:
	var seen := 0
	for i in 1:
		var rows := Islands.rows()
		var grid := Grid.new()
		grid.load_rows(rows)
		var allied := 0
		var off_land := 0
		for raw in Islands.spawns():
			var s: Dictionary = raw
			seen += 1
			if Rules.side_of(int(s["type_id"])) != Rules.Side.ENEMY:
				allied += 1
			var p := grid.tile_point(int(s["tile"]))
			if not grid.is_passable(int(p.x), int(p.y)):
				off_land += 1
		t.eq(allied, 0, "섬 %d 에서 아군 편 종이 하나도 안 나온다" % i)
		# ⚠ **모르는 글자는 조용히 구멍이 된다** (`grid.gd`) — 적이 못 걷는 벽 위에 서고 아무도 안 짖는다.
		# 이 줄이 새 글자가 `LAND_CHARS` 에 도착했는지를 정면으로 잰다.
		t.eq(off_land, 0, "섬 %d 의 적은 전부 걸을 수 있는 땅에 서 있다 — 새 글자가 구멍이 아니다" % i)
	t.ok(seen > 0, "섬들이 적을 실제로 내놓았다 — 0마리면 위 두 줄이 공허하다 (자가 점검)")


# -- the instrument's own failing cases -------------------------------------------------------------

func _self_check(t) -> void:
	var short_rows := ["....", "...", "...."]
	t.ok(_shape_errors(short_rows, 3, 4).size() >= 1, "모양 검사기는 짧은 행을 잡는다 (자가 점검)")
	t.ok(_shape_errors(short_rows, 4, 4).size() >= 2, "모양 검사기는 행 수도 센다 (자가 점검)")
	t.eq(_shape_errors(["....", "...."], 2, 4).size(), 0,
			"모양 검사기는 멀쩡한 격자를 잡지 않는다 — 전부 빨개지는 검사기가 아니다 (자가 점검)")

	t.ok(_illegal_chars(["~H.#^/,SAL"]).size() == 1, "범례 검사기는 쉼표를 잡는다 (자가 점검)")
	t.eq(_illegal_chars(["~H.#^/SAL"]).size(), 0, "범례 안의 글자는 안 잡는다 (자가 점검)")
	t.ok(_illegal_chars(["~H.#^/BCL"]).size() == 2, "그리고 옛 짐승 글자 B·C 는 이제 범례 밖이다 — 하나라도 남으면 여기가 문다 (자가 점검)")

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
		{"type_id": Rules.WOLF, "tile": 3 * 12 + 3},
		{"type_id": Rules.CROW, "tile": 3 * 12 + 9},
	]
	var reach := Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
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
## ⚠⚠ **AND THE BEAST CARDS ARE IN IT NOW** (티켓 15). A run registers up to `SUMMON_SLOT_MAX`
## species and every one after the opening table arrives with `SPECIES_CARD_BODIES` bodies, so the
## largest roster grew by four times four. Leaving them out would have left this floor's own label —
## 「최대 병력 + 여유 1」 — claiming more than the number measures, which is this repo's false green.
func _min_region_floor() -> int:
	return _max_roster() + 1


## The largest roster a run can ever field: the opening table, plus every `Reward.COUNT` node a single
## route can step on, plus a body count for every species a card can still register.
func _max_roster() -> int:
	var from_cards := (Rules.SUMMON_SLOT_MAX - Rules.START_SLOTS.size()) * Rules.SPECIES_CARD_BODIES
	return Rules.roster_start_count() \
\
		+ from_cards


## The length of the water route from harbour `hb` to `landing`, in tiles — what a crossing actually
## costs now. **Summed from `grid.water_route`'s own points**, never re-derived from the endpoints: a
## straight line between the same two ends is exactly the number this round replaced, and computing it
## here would put it back under the new name.
func _route_length(grid: Grid, hb: int, landing: int) -> float:
	var route := grid.water_route(hb, landing)
	var total := 0.0
	for k in range(1, route.size()):
		total += route[k - 1].distance_to(route[k])
	return total


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
