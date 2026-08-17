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
const EXPECT_SPAWNS := [4, 6, 5]
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
## `battle.setup`. Only island 2 has any (four bison sit close enough together to jam the walker on
## each other's tiles); see the comment above that check for why this is a real but different, weaker
## property than the terrain-only walker above it.
const EXPECT_STRICT_UNREACHED := [0, 14, 0]
## ⚠ **A flat 4 is not the rule — it happened to equal `Rules.cap_of(0)` by coincidence and hid a real
## silent stall.** Runtime measurement: a 4-tile region with ONE soldier already landed on it (from an
## earlier boat, or a companion landing this same frame) leaves 3 tiles free, and a BIG boat's full
## cargo of 4 then waits forever — `_try_unload` never partially lands, the island runs to
## LOST/TIMEOUT with the boat still at sea, and nothing in the sim says why. The floor has to clear
## the worst boat's capacity WITH a tile of margin for exactly that occupied-neighbour case, so it is
## computed from `Rules.BOATS`, never hardcoded — see `_min_region_floor()`.

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
	t.eq(min_region_floor, 5, "가장 좁아도 되는 상륙지 바닥은 5칸이다 (BIG 정원 4 + 여유 1) — 자가 점검")

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
		# folded into the check above so that trading it away is visible, not silent. On island 2, four
		# bison sit close enough together that the flow-field-optimal route from 14 (tile, enemy) pairs
		# runs through ANOTHER bison's own tile and the walker jams there. Verified (not merely argued):
		# in every one of the 14 the blocking bison is NEARER to the walk's start than the target enemy
		# is, and soldiers carry `Rules.NO_DETECT` — `_nearest_enemy` has no radius to respect and always
		# targets the closest living enemy — so a real soldier there is sent at the BLOCKER first, not
		# the farther target; the blocker dies, `reserved` frees its tile, and the path opens. That is
		# the actual mechanism, not "the blocker happens to be in melee reach of the start" (measured
		# false: the nearest other enemy in all 14 cases is 5.00-15.81 tiles away).
		var strict_unreached := 0
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
			for e in spawns.size():
				grid.release_all(Battle.ENEMY_UID_BASE + e)
		t.eq(strict_unreached, int(EXPECT_STRICT_UNREACHED[i]),
			"섬 %d — 적을 전부 동시에 예약해도 못 닿는 짝의 수 (엄격판, 참고용)" % (i + 1))

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


## The smallest passable region a sendable tile may sit in without risking the silent stall the
## header names: the largest single boat's capacity, plus one tile of margin for a neighbour already
## occupied when that boat arrives. Computed from `Rules.BOATS` rather than hardcoded, so raising a
## boat's capacity moves this floor with it instead of quietly falling behind.
func _min_region_floor() -> int:
	var worst := 0
	for b in Rules.boat_count():
		worst = maxi(worst, Rules.cap_of(b))
	return worst + 1


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
