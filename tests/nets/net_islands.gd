extends RefCounted
## The three island grids, and whether the game's own walker can actually get at every enemy on them.
##
## **This net drives `grid.flow_field` and `grid.step_toward` and never carries a walker of its own.**
## A net with its own BFS measures the net: greedy 8-way descent was measured stalling on five of
## twenty-six dock-to-enemy pairs on these exact grids while a flood-fill connectivity check called
## them all reachable, so "the tiles are connected" and "a unit can walk it" are different claims and
## only the second one matters. The first slice plan records that measurement under "What two
## adversarial passes broke".
##
## **The enemy's own tile is reserved before the walk, exactly the way `battle.setup` reserves it.**
## The criterion is therefore "within attack reach of the enemy", never "standing on the enemy" —
## a walk that had to end on the target tile would be unreachable in the real game and green here.
##
## Every scanner below is fed a synthetic case that must FAIL it, in `_self_check`. A scanner that
## never matches reads exactly like a clean tree, and three of this repo's checks have shipped that
## way; the sealed-enemy fixture is the walker's half of that, and it is sealed rather than merely
## twisty on purpose — a greedy dead end would not bite a BFS walker at all.

## Legend from islands.gd's header. Anything else in a row is a typo that grid.gd silently loads as
## an impassable hole, which is a wall nobody drew.
const LEGEND := "~.#DBCL"

const EXPECT_ROWS := 18
const EXPECT_COLS := 32
## Narrowest cut, defined as: for each column, count the passable tiles; take the minimum over the
## columns that have at least one. Pinned to this definition because a minimum vertex cut is a
## max-flow, and the net would then carry a second graph algorithm and start measuring itself.
const EXPECT_CUTS := [9, 2, 9]
const EXPECT_SPAWNS := [4, 6, 5]

## Seconds per island, written out here as literals rather than read back off `Islands`. A mutation
## sweep put the boss island on 5 seconds and **the whole round stayed green**: the only three checks
## that touched the limits all compared `battle.time_limit` against `Islands.time_limit_of(i)`, which
## is the value's own source, and one of them was labelled "셋째 섬의 제한 시간은 90초다" while
## measuring nothing of the kind. A check whose bounds come from the thing it checks proves nothing.
const EXPECT_LIMITS := [60.0, 60.0, 90.0]
## 2 docks x 4 enemies + 2 x 6 + 2 x 5. Asserted so a scan that walked nothing cannot read as clean.
const EXPECT_PAIRS := 30

## Ceiling on tiles crossed in one walk. Each step strictly lowers the field value and the grid is
## 576 tiles, so this can only be reached by a step_toward that stopped making progress — and a net
## that hangs prints no verdict at all, which disarms mutation testing on the whole file.
const WALK_STEPS_MAX := 600

## Disjoint from both soldier ids (small) and enemy uids (Battle.ENEMY_UID_BASE and up), so the
## walker can never release a tile an enemy is standing on.
const WALKER_ID := 999_999


func run(t) -> void:
	t.eq(Islands.count(), 3, "섬은 셋이다")
	t.eq(Islands.TIME_LIMITS.size(), 3, "제한 시간도 섬마다 하나씩 있다")
	for i in EXPECT_LIMITS.size():
		t.eq(Islands.time_limit_of(i), float(EXPECT_LIMITS[i]),
			"섬 %d 의 제한 시간은 %.0f초다" % [i + 1, float(EXPECT_LIMITS[i])])

	var pairs := 0
	var total_steps := 0
	for i in Islands.count():
		var rows := Islands.rows_of(i)
		var shape := _shape_errors(rows, EXPECT_ROWS, EXPECT_COLS)
		t.eq(shape.size(), 0, "섬 %d 은 18행 x 32자다 %s" % [i + 1, str(shape)])
		var illegal := _illegal_chars(rows)
		t.eq(illegal.size(), 0, "섬 %d 에 범례 밖 글자가 없다 %s" % [i + 1, str(illegal)])

		var grid := Grid.new()
		grid.load_rows(rows)
		t.eq(_cut_of(grid), int(EXPECT_CUTS[i]), "섬 %d 의 최협 절단" % (i + 1))

		var dry := _docks_not_touching_water(rows)
		t.eq(dry.size(), 0, "섬 %d 의 부두는 모두 물에 접해 있다 %s" % [i + 1, str(dry)])
		t.eq(grid.dock_tiles.size(), 2, "섬 %d 의 부두는 둘이다" % (i + 1))

		var spawns := Islands.spawns_of(i)
		t.eq(spawns.size(), int(EXPECT_SPAWNS[i]), "섬 %d 의 적 수" % (i + 1))
		var off_land := 0
		for e in spawns.size():
			if grid.passable[int(spawns[e]["tile"])] == 0:
				off_land += 1
		t.eq(off_land, 0, "섬 %d 의 적은 전부 걸을 수 있는 칸에 서 있다" % (i + 1))

		_reserve_enemies(grid, spawns)
		var unreserved := 0
		for e in spawns.size():
			if grid.reserved[int(spawns[e]["tile"])] == -1:
				unreserved += 1
		t.eq(unreserved, 0, "섬 %d 의 적 칸은 전부 예약돼 있다 — 걷기의 전제다" % (i + 1))

		var reach := Rules.range_of(Rules.CELL_MELEE) + Rules.REACH_BONUS
		var unreached: Array = []
		for d in grid.dock_tiles.size():
			for e in spawns.size():
				var tile := int(spawns[e]["tile"])
				var res := _reaches(grid, int(grid.dock_tiles[d]), tile, reach)
				pairs += 1
				total_steps += int(res["steps"])
				if not bool(res["ok"]):
					unreached.append("부두%d→적%d" % [d, e])
		t.eq(unreached.size(), 0,
				"섬 %d — 모든 부두에서 모든 적의 사거리 안까지 실제로 걸어간다 %s" % [i + 1, str(unreached)])

		# The reservation half, measured rather than assumed: with reach 0 the only way to "arrive" is
		# to stand on the enemy, and the reservation is what must forbid it. Without this the reach
		# check above passes at 1.0 tiles away whether the enemy's tile is enterable or not.
		var first := int(spawns[0]["tile"])
		var onto := _reaches(grid, int(grid.dock_tiles[0]), first, 0.0)
		t.ok(not bool(onto["ok"]), "섬 %d — 예약된 적의 칸 위로는 끝내 못 들어간다" % (i + 1))
		t.ok(int(onto["tile"]) != first, "섬 %d — 워커가 멈춘 칸은 적의 칸이 아니다" % (i + 1))
		t.ok(int(onto["steps"]) > 0, "섬 %d — 그 워커는 실제로 움직였다 (%d칸)" % [i + 1, int(onto["steps"])])

	t.eq(pairs, EXPECT_PAIRS, "걸어본 부두-적 짝의 수")
	t.ok(total_steps > 0, "그 걷기들은 실제로 칸을 넘었다 (총 %d칸)" % total_steps)

	_self_check(t)


# -- the instrument's own failing cases -------------------------------------------------------------
## Every scanner above gets a case that must fail IT. A regex that never matches, a walker that always
## says yes and a cut that counts empty columns all read identically to a clean tree from the outside.
func _self_check(t) -> void:
	var short_rows := ["....", "...", "...."]
	t.ok(_shape_errors(short_rows, 3, 4).size() >= 1, "모양 검사기는 짧은 행을 잡는다 (자가 점검)")
	t.ok(_shape_errors(short_rows, 4, 4).size() >= 2, "모양 검사기는 행 수도 센다 (자가 점검)")
	t.eq(_shape_errors(["....", "...."], 2, 4).size(), 0,
			"모양 검사기는 멀쩡한 격자를 잡지 않는다 — 전부 빨개지는 검사기가 아니다 (자가 점검)")

	t.ok(_illegal_chars(["~..,~"]).size() == 1, "범례 검사기는 쉼표를 잡는다 (자가 점검)")
	t.eq(_illegal_chars(["~.#DBCL"]).size(), 0, "범례 안의 글자는 안 잡는다 (자가 점검)")

	var dock_inland := ["....", ".D..", "...."]
	t.ok(_docks_not_touching_water(dock_inland).size() == 1,
			"부두 검사기는 물에서 떨어진 부두를 잡는다 (자가 점검)")
	t.eq(_docks_not_touching_water(["~...", ".D..", "...."]).size(), 0,
			"대각선으로라도 물에 닿으면 안 잡는다 (자가 점검)")

	# Column 0 is all water. Counting it would make every island's cut 0 and the three numbers above
	# would be unfalsifiable.
	var cut_grid := Grid.new()
	cut_grid.load_rows(["~...", "~#..", "~#..", "~..."])
	t.eq(_cut_of(cut_grid), 2, "절단 계산기는 통과 가능 칸이 0인 열을 건너뛴다 (자가 점검)")

	# Column 6 is water top to bottom, so the crow behind it is sealed off — not merely awkward to
	# reach. A greedy dead end would not bite a BFS walker, which is why the fixture is a wall.
	var fx := Grid.new()
	fx.load_rows([
		"~~~~~~~~~~~~",
		"~D....~....~",
		"~.....~....~",
		"~..B..~..C.~",
		"~.....~....~",
		"~~~~~~~~~~~~",
	])
	var fx_spawns := [
		{"type_id": Rules.BISON, "tile": 3 * 12 + 3},
		{"type_id": Rules.CROW, "tile": 3 * 12 + 9},
	]
	_reserve_enemies(fx, fx_spawns)
	var reach := Rules.range_of(Rules.CELL_MELEE) + Rules.REACH_BONUS
	var near := _reaches(fx, 1 * 12 + 1, int(fx_spawns[0]["tile"]), reach)
	var sealed := _reaches(fx, 1 * 12 + 1, int(fx_spawns[1]["tile"]), reach)
	t.ok(bool(near["ok"]), "픽스처에서 벽 이쪽의 적에게는 걸어간다 (자가 점검)")
	t.ok(int(near["steps"]) > 0, "그 걷기는 실제로 칸을 넘었다 (%d칸, 자가 점검)" % int(near["steps"]))
	t.ok(not bool(sealed["ok"]), "벽 저쪽에 갇힌 적에게는 못 간다고 말한다 (자가 점검)")


# -- scanners ---------------------------------------------------------------------------------------

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


## A dock a boat cannot be sailed to is a dock that does nothing. The characters are read rather than
## `grid.passable`, because grid.gd loads water and holes as the same thing and only water floats.
func _docks_not_touching_water(rows: Array) -> Array:
	var out: Array = []
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			if row[x] != Grid.DOCK_CHAR:
				continue
			var wet := false
			for k in Grid.NEIGHBOURS.size():
				var nx := x + int(Grid.NEIGHBOURS[k][0])
				var ny := y + int(Grid.NEIGHBOURS[k][1])
				if ny < 0 or ny >= rows.size():
					continue
				var nrow := str(rows[ny])
				if nx < 0 or nx >= nrow.length():
					continue
				if nrow[nx] == "~":
					wet = true
			if not wet:
				out.append("(%d,%d)" % [x, y])
	return out


## The narrowest cut, per the definition pinned in the first slice plan under "The islands".
func _cut_of(grid: Grid) -> int:
	var best := -1
	for x in grid.w:
		var n := 0
		for y in grid.h:
			if grid.passable[y * grid.w + x] != 0:
				n += 1
		# A column with nothing passable in it is not a cut, it is the sea. Counting it would make
		# every answer 0.
		if n == 0:
			continue
		if best == -1 or n < best:
			best = n
	return best


# -- the walk ---------------------------------------------------------------------------------------

## Reserves every spawn tile the way `battle.setup` does, with the same disjoint uid range — using a
## second numbering here would let the walker release a tile an enemy is standing on.
func _reserve_enemies(grid: Grid, spawns: Array) -> void:
	var claimed := grid.reserved
	for e in spawns.size():
		var tile := int(spawns[e]["tile"])
		if tile >= 0 and tile < claimed.size():
			claimed[tile] = Battle.ENEMY_UID_BASE + e
	grid.reserved = claimed


## Walks the game's own functions from `start_tile` toward `enemy_tile` and reports whether the walker
## ever got within `reach`. Returns `{ok, steps, tile}`.
##
## The reach test runs BEFORE each step, so arriving means "stopped because the target is in range",
## which is what `battle._phase_movement` does. Testing after the step would let a walker that stepped
## onto the target tile report success.
func _reaches(grid: Grid, start_tile: int, enemy_tile: int, reach: float) -> Dictionary:
	grid.release_all(WALKER_ID)
	var field := grid.flow_field(enemy_tile)
	var goal := Vector2(enemy_tile % grid.w, enemy_tile / grid.w)
	var pos := Vector2(start_tile % grid.w, start_tile / grid.w)
	var steps := 0
	var arrived := pos.distance_to(goal) <= reach + Rules.EPS
	while not arrived and steps < WALK_STEPS_MAX:
		var next_pos: Vector2 = grid.step_toward(WALKER_ID, pos, field)
		if next_pos.distance_to(pos) <= Rules.EPS:
			# Every candidate blocked, or nothing closer: the walker stands. That is a real stall and
			# it is what this net exists to catch.
			break
		pos = next_pos
		steps += 1
		arrived = pos.distance_to(goal) <= reach + Rules.EPS
	grid.release_all(WALKER_ID)
	return {
		"ok": arrived,
		"steps": steps,
		"tile": int(round(pos.y)) * grid.w + int(round(pos.x)),
	}
