extends RefCounted
## **The ONE island, measured against the board the user actually drew** — its shape, its legend, how
## much ground and how much water it lays out, the narrowest place on it, and whether the game's own
## walker can cross it from every coast tile.
##
## ⚠⚠ **THE THREE 48 x 32 BOARDS AND THE 144 x 32 ONE ARE DELETED, AND MOST OF THIS FILE WENT WITH
## THEM** (2026-08-27, the user: 「애초에 노드 개념이 없어지다 보니까 다 지워주면 돼」). The island is
## ONE and it is **26 x 20**, baked out of Blender into `assets/terrain/island.json`. Every literal
## below is measured against THAT file and nothing else.
##
## **WHAT WAS DELETED, WHAT IT MEASURED, AND WHAT IT KNEW THAT OUTLIVES IT** — this block is the whole
## record and nothing above it is a summary of anything else:
##
##  · **`EXPECT_HARBOUR_TILES` / `EXPECT_START_TILE`** — the three tile indices each 48-wide island put
##    its `H` characters on, and which of the three the fleet opened at (*the harbour whose nearest
##    reachable coast tile is FARTHEST away*, ties to the lowest index). ⚠ **`start_harbour` itself is
##    deleted from `grid.gd`** with the drag that read it; **nothing chooses a starting harbour now**,
##    a summon is pressed inside a ring about the middle of the grid. The `H` characters survive and
##    are still measured below — on this board they are the whole border ring, 88 of them.
##
##  · **`EXPECT_SENDABLE` / `_UNION` / `EXPECT_DROPPABLE` / `EXPECT_START_SENDABLE` / `EXPECT_COAST`
##    (84 · 76 · 82)** — the per-harbour landing denylist and its union. ⚠⚠ **The user's own line is
##    what shaped it and it is worth more than the numbers**: *"상륙 못하는 데가 있는 거지 상륙 가능한
##    데가 있는 게 아니야"* — the rule was *passable AND some 8-WAY neighbour is water this harbour can
##    reach*, so what was left refused was only cliff and inland. ⚠ **8-way and not 4-way, and the
##    numbers were the argument**: island 0's ortho coast was 82 and its 8-way coast 84 — two corner
##    beaches — and 「어디든지」 is what put them in. **That set survives under a second name**: the
##    coastal band `_summon_field` seeds from is the same set, and this file still counts it (72 here)
##    and still shows the 8-way and 4-way answers differ.
##
##  · **`EXPECT_WAVE1` / `EXPECT_STEADY` / `EXPECT_RELOCATES` / `_route_length`** — min/max WATER ROUTE
##    length from a harbour over every tile it could reach, and how many tiles relocated the fleet.
##    ⚠⚠ **The knowledge in them is the metric, not the numbers: a crossing is the length of the water
##    route the boat actually SAILS, never the Euclidean line** — a boat rounds a headland, so the
##    straight line prices a crossing nobody makes. `water_route` and `home_harbour_for` are both
##    deleted; `summon_route` is the one route left and `net_summon` prices it.
##
##  · **`EXPECT_UNCOVERED_COAST` (13 · 14 · 4) and the 「조용한 해안」 pair** — how many coast tiles sat
##    inside NO enemy's detect circle, plus 「the cheapest beach must not also be the quietest one」.
##    ⚠⚠ **That second one is the shape that killed this repo's second game — an advantage with no
##    cost is not a decision** — and it is worth rebuilding the day beasts stand on this board. It
##    cannot be measured today: **the board carries no spawn characters at all**, so every coast tile
##    is uncovered and 「조용한 해안이 남아 있다」 passes while 「해안 전부가 조용하지는 않다」 cannot.
##
##  · **The strict walker (`EXPECT_STRICT_UNREACHED`, `_reserve_all`, `_a_nearer_enemy_exists`)** — it
##    reserved every enemy tile at once, the way a live `battle.setup` does, and reported the (tile,
##    enemy) pairs that jammed. ⚠ **Its finding outlives it and is the reason a jam is not a stall**:
##    soldiers carry `Rules.NO_DETECT`, so `_nearest_enemy` always targets the CLOSEST living enemy —
##    a blocker nearer than the target is fought first, dies, frees its tile, and the path opens.
##    ⚠⚠ **It had ZERO subjects the moment the spawns went** and both of its rows would have passed
##    on empty loops, which is this repo's named false green.
##
##  · **`EXPECT_OLD_SENDABLE` (50 · 44 · 48) and `EXPECT_COAST_ADJACENCY_DROPPED` (97 · 83 · 94)** —
##    the wrong answers pinned so nobody re-derived them. ⚠ **97 > 84 was the trap and it is worth
##    keeping in words: a BIGGER number can be the WRONG set** — its extra tiles were one tile INLAND
##    while it still refused 40% of the actual shore.
##
##  · **`EXPECT_SPAWNS` (8 · 12 · 14) and the enemy-density rows** — the pitch each island was written
##    at. **This board has no enemies on it yet**, so what is left of `_every_spawn_is_an_enemy` is
##    measured off the spawn TABLE instead of off the rows.
##
## ⚠⚠ **The one discipline that is not deleted with them: every literal in this file was derived
## OUTSIDE the engine, from a from-scratch reimplementation of `grid.gd`'s own loops, and never read
## back off the `Grid` under test.** A check that asks its subject for its expectation measures
## nothing, and re-measuring only the rows that failed is this repo's own named failure — one table
## once shipped a quiet row off by a factor of twenty-four because it was not the row anybody was
## arguing about.


## Every character the board is allowed to hold. ⚠⚠ **NARROWED 2026-08-27: it read `"~H.#^/SAL"` and
## `S`/`A` were 방패병 and 궁수 — the PLAYER's letters from the season the sides were swapped the other
## way.** The sides swapped back: the player is one swordsman who is never written on the board at all,
## and the letters that put a body on the ground are the beasts' — `W` `B` `C` `L`, `Islands.SPAWN_ROWS`
## in full. ⚠ **A superset legend is green for the wrong reason**: this board holds only `.`, `~` and
## `H`, so a legend containing letters nothing writes would pass whatever the letters were.
const LEGEND := "~H.#^/WBCL"

## The board's shape. **Literals, and they are the user's own drawing** — `tools/blender/island_build.py`
## bakes 26 x 20 and the game reads it back.
const EXPECT_ROWS := 20
const EXPECT_COLS := 26

## ⚠ **The whole border ring is `H`.** 26 + 26 across the top and bottom, 18 + 18 down the two sides =
## **88**, and that is where the beasts' boats come from — off the edge of the board, not from three
## docks somebody placed. The count and the ring are asserted separately: 88 characters scattered
## anywhere in the middle would satisfy the first alone.
const EXPECT_HARBOUR_CHARS := 88

## Ground and water, counted off the rows. ⚠ **`H` counts as WATER** (`Grid.WATER_CHARS` is `"~H"`),
## so 176 `~` plus 88 `H` is 264, and 264 + 256 is the whole 520-tile board — which is what makes
## these two a partition rather than two loose numbers.
const EXPECT_PASSABLE := 256
const EXPECT_WATER := 264

## The coast, both ways of counting it. ⚠⚠ **The 4-way answer is kept beside the 8-way one for ONE
## job: proving they are different numbers.** A suite that dropped it could not tell an 8-way rule
## from a 4-way one, and 「어디든지」 is exactly the ten tiles between them.
const EXPECT_COAST := 72
const EXPECT_COAST_ORTHO := 62

## The narrowest cut, per the definition the first slice plan pinned under "The islands": the fewest
## passable tiles in any column that has one at all.
const EXPECT_CUT := 4

## **The island is ONE connected walkable region** — every tile of it. ⚠ **The count is asserted as
## well as the count of regions, and neither alone is enough**: 「there is one component」 is satisfied
## by an island that lost half its ground to a wall, and 「256 tiles」 is satisfied by two islands of
## 128 with a channel between them.
const EXPECT_LAND_REGION := 256

## Ceiling on tiles crossed in one walk. **Generous on purpose** — the longest crossing on a 520-tile
## board is under 40 tiles, so a walk that hits this ceiling is stuck rather than long, which is the
## only thing the number has to be able to say.
const WALK_STEPS_MAX := 900
const WALKER_ID := 999_999


func run(t) -> void:
	# ⚠ **Read through the accessors, because the board is a FILE now** (2026-08-26) — the letter grid
	# left `islands.gd` when Blender became the source of the island. A net naming the old consts would
	# not just fail; it would be asserting that the board still lives in the game.
	var rows := Islands.rows()
	var tiers := Islands.tiers()
	t.eq(rows.size(), EXPECT_ROWS, "섬은 스무 줄이다")
	t.eq(tiers.size(), EXPECT_ROWS, "층 판도 같은 줄 수다")
	var shape := _shape_errors(rows, EXPECT_ROWS, EXPECT_COLS)
	t.eq(shape.size(), 0, "섬이 %d행 x %d자다 %s" % [EXPECT_ROWS, EXPECT_COLS, str(shape)])
	var tier_shape := _shape_errors(tiers, EXPECT_ROWS, EXPECT_COLS)
	t.eq(tier_shape.size(), 0, "층 판도 같은 모양이다 %s" % str(tier_shape))

	# -- the legend ---------------------------------------------------------------------------------
	var illegal := _illegal_chars(rows)
	t.eq(illegal.size(), 0, "섬에 범례 밖 글자가 없다 %s" % str(illegal))
	# ⚠⚠ **THE FLOOR UNDER THE LINE ABOVE, and without it 「짐승 글자가 합법이다」 passes on a board
	# that holds no beasts at all** — which is exactly this board. The scanner is shown to ACCEPT every
	# letter the spawn table currently writes, so a letter added to `Islands.SPAWN_ROWS` without being
	# added here reddens instead of quietly becoming an illegal character on the first island that uses it.
	var spawn_chars := Islands.spawn_chars()
	t.ok(spawn_chars.length() > 0, "짐승 글자 표가 비어 있지 않다 (자가 점검 — 비면 아래 줄이 공허하다)")
	t.eq(_illegal_chars([spawn_chars]).size(), 0,
		"오늘의 짐승 글자 %s 는 전부 범례 안이다 — 표에 글자를 더하면 여기가 먼저 문다" % spawn_chars)

	# -- the harbours -------------------------------------------------------------------------------
	var grid := Grid.new()
	Islands.load_into(grid)
	t.eq(_count_char(rows, "H"), EXPECT_HARBOUR_CHARS, "판의 항구 글자가 %d 개다" % EXPECT_HARBOUR_CHARS)
	t.eq(grid.harbour_tiles.size(), EXPECT_HARBOUR_CHARS,
		"격자가 읽어낸 항구 칸 수도 같다 — 글자와 표가 어긋나지 않는다")
	# ⚠ **WHERE, and not only how many.** `harbour_tiles` is the only record in the sim of where an `H`
	# sits now that everything which used to read it is deleted, and 88 `H` scattered through the middle
	# of the board would satisfy the count above on its own.
	var off_ring: Array = []
	for raw_h in grid.harbour_tiles:
		var hx := int(raw_h) % grid.w
		var hy := int(raw_h) / grid.w
		if hx != 0 and hy != 0 and hx != grid.w - 1 and hy != grid.h - 1:
			off_ring.append(int(raw_h))
	t.eq(off_ring.size(), 0, "항구는 전부 판 가장자리 한 줄이다 — 배는 지도 밖에서 온다 %s" % str(off_ring))
	t.eq(EXPECT_HARBOUR_CHARS, 2 * EXPECT_COLS + 2 * (EXPECT_ROWS - 2),
		"그리고 그 88은 가장자리 한 바퀴 그대로다 (26x2 + 18x2 — 자가 점검)")

	# -- ground and water ---------------------------------------------------------------------------
	var passable_n := 0
	var water_n := 0
	for tile in grid.passable.size():
		if grid.passable[tile] != 0:
			passable_n += 1
		if grid.water[tile] != 0:
			water_n += 1
	t.eq(passable_n, EXPECT_PASSABLE, "섬의 땅은 %d칸이다" % EXPECT_PASSABLE)
	t.eq(water_n, EXPECT_WATER, "물은 %d칸이다 (항구 글자도 물이다)" % EXPECT_WATER)
	t.eq(passable_n + water_n, EXPECT_ROWS * EXPECT_COLS,
		"땅과 물이 판 전부다 — 어느 쪽도 아닌 칸이 없다 (자가 점검)")

	# -- the coast ----------------------------------------------------------------------------------
	# ⚠ **Built locally from `passable` + `water`.** The per-harbour `sendable` table it used to be read
	# off is deleted; recomputing the set from the two primitive tables is what keeps this a claim about
	# the BOARD rather than a read-back of whatever the grid decided.
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
	t.eq(coast, EXPECT_COAST, "8방향으로 물에 닿은 땅이 %d칸이다" % EXPECT_COAST)
	t.eq(coast_ortho, EXPECT_COAST_ORTHO, "직교로만 세면 %d칸이다" % EXPECT_COAST_ORTHO)
	t.ok(coast > coast_ortho,
		"그리고 둘이 실제로 다르다 — 모서리로만 물에 닿은 해변 %d칸이 8방향 규칙의 전부다" % (coast - coast_ortho))

	# -- the narrowest place ------------------------------------------------------------------------
	t.eq(_cut_of(grid), EXPECT_CUT, "섬의 최협 절단이 %d칸이다" % EXPECT_CUT)

	# -- one island, and it is big enough to land on ------------------------------------------------
	var min_region_floor := _min_region_floor()
	# ⚠ The 11 is a LITERAL on purpose. Writing the formula on both sides would let the roster grow and
	# the expectation grow with it, which is the shape that proves nothing.
	# ⚠⚠ **38 -> 26 -> 10** (2026-08-27): 38 fell to 26 when the node rewards died with the map, and 26
	# fell to 10 when the BEAST CARD was deleted. `Rules.SPECIES_CARD_BODIES` stood here as the four
	# bodies each of the four card-filled summon slots arrived with; **there is no card that can fill a
	# summon slot any more**, so a run cannot gain a single body after `setup` and the largest roster it
	# can ever field IS the opening table. ⚠ The SUMMON SLOT system itself is untouched — what died is
	# the only thing that used to write into it, so the term is worth zero rather than absent in spirit.
	t.eq(min_region_floor, 11, "가장 좁아도 되는 상륙지 바닥은 11칸이다 (최대 병력 10 + 여유 1) — 자가 점검")
	t.eq(_max_roster(), 10, "그 최대 병력 10이 개막 표 그대로다 — 회차 중에 병력이 느는 길이 없다 (자가 점검)")

	var comp_id := PackedInt32Array()
	comp_id.resize(grid.passable.size())
	comp_id.fill(-1)
	var comp_size: Array = []
	for tile0 in grid.passable.size():
		if grid.passable[tile0] == 0 or comp_id[tile0] != -1:
			continue
		var members := 0
		var stack := PackedInt32Array()
		stack.append(tile0)
		comp_id[tile0] = comp_size.size()
		while not stack.is_empty():
			var tt: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			members += 1
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
		comp_size.append(members)
	t.eq(comp_size.size(), 1, "섬은 걸어서 하나로 이어져 있다 — 땅덩이가 하나다")
	t.eq(int(comp_size[0]), EXPECT_LAND_REGION, "그 땅덩이가 %d칸 전부다" % EXPECT_LAND_REGION)

	# **4.5**: every tile a boat can beach on sits in a region big enough to unload into. ⚠ It reads the
	# COAST now and not the deleted `sendable` union — the two were the same set on every island this
	# repo has shipped, and the coast is the one that still exists.
	var too_small: Array = []
	var min_region := -1
	for tile in coast8.size():
		if coast8[tile] == 0:
			continue
		var sz: int = comp_size[comp_id[tile]]
		if min_region < 0 or sz < min_region:
			min_region = sz
		if sz < min_region_floor:
			too_small.append(tile)
	t.eq(too_small.size(), 0,
		"상륙할 수 있는 모든 해안 칸이 %d칸 이상인 땅에 있다 (배 하나를 못 내려주는 좁은 곶이 없다) %s"
		% [min_region_floor, str(too_small)])
	t.ok(min_region >= min_region_floor, "가장 좁은 상륙지의 땅이 %d칸이다" % min_region)
	_the_floor_actually_rejects_something(t, min_region_floor)

	# -- the walker ---------------------------------------------------------------------------------
	# ⚠⚠ **THIS WALKED TO EVERY ENEMY AND IT WALKS TO ONE GROUND TILE NOW.** The board carries no spawn
	# characters, so 「every coast reaches every enemy」 had zero pairs to walk and would have reported
	# `unreached.size() == 0` over an empty loop — a green measuring nothing, which is the exact shape
	# this repo keeps paying for. What survives is the half that is about the ISLAND: from every tile a
	# boat can beach on, the game's OWN `flow_field` / `step_toward` really do cross the ground.
	# ⚠ **It drives the game's functions and never carries a walker of its own** — the first-slice plan's
	# reason, unchanged: a walker with its own BFS measures the walker, not whether the real game's units
	# can cross this ground. `flow_field` honours `can_step`, so this is also the only row here that
	# would notice a body that could walk up the plateau without using the stair.
	var target := grid.tile_index(5, 10)
	t.ok(grid.passable[target] != 0, "걸어갈 목표 칸이 실제로 땅이다 (자가 점검)")
	t.eq(grid.level_of(target), 0, "그리고 0층이다 — 해안과 같은 층이라 계단을 안 거쳐도 된다 (자가 점검)")
	var reach := Rules.range_of(Rules.SWORDSMAN) + Rules.REACH_BONUS
	var field := grid.flow_field(target)
	var walker_pairs := 0
	var walker_steps := 0
	var unreached: Array = []
	for tile in coast8.size():
		if coast8[tile] == 0:
			continue
		var res := _reaches(grid, tile, target, reach, field)
		walker_pairs += 1
		walker_steps += int(res["steps"])
		if not bool(res["ok"]):
			unreached.append(tile)
	t.eq(unreached.size(), 0, "배로 닿는 모든 해안에서 섬 안쪽까지 실제로 걸어간다 %s" % str(unreached))
	t.eq(walker_pairs, EXPECT_COAST, "그 걷기를 해안 %d칸에서 전부 해 봤다 (자가 점검)" % EXPECT_COAST)
	t.ok(walker_steps > 0, "그리고 그 걷기들은 실제로 칸을 넘었다 (총 %d칸)" % walker_steps)

	_every_spawn_letter_is_a_beast(t)
	_self_check(t)


# -- the spawn letters ------------------------------------------------------------------------------

## **The net that says the side swap actually happened.** The four beasts are the enemy's rows and the
## player is one swordsman who is never written on a board at all; a spawn letter bound to a PLAYER row
## would put a body on the island fighting for the humans, and it would look completely ordinary on
## screen. ⚠ This repo has swapped these sides twice — 「부위」 and 「다리」 are what it cost the last
## time a name outlived its sense — so the binding is measured rather than assumed.
##
## ⚠ **Derived from the SIDE COLUMN, never from a list of names.** A roll call would have to be edited
## the day a row is added, and the row nobody edited is the one that gets through.
##
## ⚠⚠ **IT READS THE TABLE AND NOT THE BOARD, AND THAT IS THE CHANGE 2026-08-27 MADE.** It used to walk
## `Islands.spawns()` over three islands and count 8 · 12 · 14 bodies. **The board the user drew carries
## no spawn character at all**, so every one of those rows would now pass on an empty loop — 「아군 편
## 종이 하나도 안 나온다」 is trivially true of nothing. `Islands.SPAWN_ROWS` is where the binding
## actually lives, so that is what is walked; the board's own spawns are checked underneath it and the
## row that says how many there are today is the floor, not a silence.
##
## ⚠ Mutation: put `Rules.SWORDSMAN` in `Islands.SPAWN_ROWS`; drop a letter out of `land_chars()`.
func _every_spawn_letter_is_a_beast(t) -> void:
	t.ok(Islands.SPAWN_ROWS.size() > 0, "몸을 세우는 글자 표가 비어 있지 않다 (자가 점검)")
	var allied: Array = []
	var not_land: Array = []
	var land := Grid.land_chars()
	for r in Islands.SPAWN_ROWS.size():
		var row: Array = Islands.SPAWN_ROWS[r]
		var ch := str(row[0])
		var type_id := int(row[1])
		if Rules.side_of(type_id) != Rules.Side.ENEMY:
			allied.append(ch)
		# ⚠ **모르는 글자는 조용히 구멍이 된다** (`grid.gd`) — 적이 못 걷는 벽 위에 서고 아무도 안 짖는다.
		# `land_chars()` 가 이 표를 읽어서 만들어지므로 새 글자는 구조상 땅이어야 하고, 이 줄이 그것을 잰다.
		if land.find(ch) == -1:
			not_land.append(ch)
		t.eq(Islands.spawn_type_of_char(ch), type_id, "글자 %s 는 제 줄을 가리킨다" % ch)
		t.eq(Islands.spawn_char_of(type_id), ch, "그 줄도 제 글자를 가리킨다 — 표가 양방향으로 맞는다")
	t.eq(allied.size(), 0, "몸을 세우는 글자 중에 아군 편 종이 하나도 없다 %s" % str(allied))
	t.eq(not_land.size(), 0, "그리고 그 글자들은 전부 걸을 수 있는 땅이다 %s" % str(not_land))

	# The board's own spawns. ⚠⚠ **This is VACUOUS TODAY and it is written down rather than dressed up**:
	# the island holds zero spawn characters, so the loop below runs zero times. It is kept because it
	# costs nothing and reddens the day a beast is drawn onto a wall — and the count beside it is what
	# stops its silence being read as 「전부 멀쩡하다」.
	var g := Grid.new()
	Islands.load_into(g)
	var off_land := 0
	for raw in Islands.spawns():
		var s: Dictionary = raw
		var p := g.tile_point(int(s["tile"]))
		if not g.is_passable(int(p.x), int(p.y)):
			off_land += 1
	t.eq(off_land, 0, "판 위에 실제로 선 짐승은 전부 걸을 수 있는 땅에 있다 (오늘은 0마리다 — 위 줄들이 그 바닥이다)")


# -- the instrument's own failing cases -------------------------------------------------------------

func _self_check(t) -> void:
	var short_rows := ["....", "...", "...."]
	t.ok(_shape_errors(short_rows, 3, 4).size() >= 1, "모양 검사기는 짧은 행을 잡는다 (자가 점검)")
	t.ok(_shape_errors(short_rows, 4, 4).size() >= 2, "모양 검사기는 행 수도 센다 (자가 점검)")
	t.eq(_shape_errors(["....", "...."], 2, 4).size(), 0,
			"모양 검사기는 멀쩡한 격자를 잡지 않는다 — 전부 빨개지는 검사기가 아니다 (자가 점검)")

	t.eq(_illegal_chars([LEGEND]).size(), 0, "범례 안의 글자는 안 잡는다 (자가 점검)")
	t.eq(_illegal_chars([","]).size(), 1, "범례 검사기는 쉼표를 잡는다 (자가 점검)")
	# ⚠⚠ **THE ROW THAT MEASURES THE NARROWING**: `S`(방패병) 와 `A`(궁수) 는 사람이 짐승이던 시절의
	# 글자다. 편이 되돌아가면서 판에서 사람 글자는 사라졌고, 둘 다 이제 범례 밖이다 — 하나라도 남으면
	# 여기가 문다.
	t.eq(_illegal_chars(["SA"]).size(), 2,
			"옛 사람 글자 S·A 는 이제 범례 밖이다 (자가 점검)")
	t.eq(_illegal_chars(["WBCL"]).size(), 0, "그리고 짐승 넷의 글자는 범례 안이다 (자가 점검)")

	# Column 0 is all water. Counting it would make the cut 0 and the number above would be
	# unfalsifiable.
	var cut_grid := Grid.new()
	cut_grid.load_rows(["~...", "~#..", "~#..", "~..."])
	t.eq(_cut_of(cut_grid), 2, "절단 계산기는 통과 가능 칸이 0인 열을 건너뛴다 (자가 점검)")

	# A wall sealing off one goal entirely — not merely awkward to reach. A greedy dead end would not
	# bite a BFS walker, which is why the fixture is a sealed wall rather than a twisty corridor.
	# ⚠ **The two goals used to be a wolf and a crow standing there.** They are bare tiles now: the
	# walker's question is about GROUND, and a spawn dictionary in a fixture was one more thing to keep
	# in step with a table this row does not measure.
	var fx := Grid.new()
	fx.load_rows([
		"~~~~~~~~~~~~",
		"~.....~....~",
		"~.....~....~",
		"~.....~....~",
		"~.....~....~",
		"~~~~~~~~~~~~",
	])
	var near_goal := fx.tile_index(3, 3)
	var sealed_goal := fx.tile_index(9, 3)
	var reach := Rules.range_of(Rules.SWORDSMAN) + Rules.REACH_BONUS
	var f0 := fx.flow_field(near_goal)
	var f1 := fx.flow_field(sealed_goal)
	var near := _reaches(fx, fx.tile_index(1, 1), near_goal, reach, f0)
	var sealed := _reaches(fx, fx.tile_index(1, 1), sealed_goal, reach, f1)
	t.ok(bool(near["ok"]), "픽스처에서 벽 이쪽의 칸에는 걸어간다 (자가 점검)")
	t.ok(int(near["steps"]) > 0, "그 걷기는 실제로 칸을 넘었다 (%d칸, 자가 점검)" % int(near["steps"]))
	t.ok(not bool(sealed["ok"]), "벽 저쪽에 갇힌 칸에는 못 간다고 말한다 (자가 점검)")


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


## The narrowest cut, per the definition pinned in the first slice plan under "The islands".
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


## The smallest passable region a landing tile may sit in without risking a silent stall. **Demand,
## not cargo**: every living soldier can aim at ONE region on one sub-step, so the floor is the largest
## roster a run can ever field plus one tile of margin for a neighbour already occupied when the last
## boat arrives.
##
## ⚠⚠ **THE STALL IT GUARDS AGAINST IS UNCHANGED AND IT IS SILENT**: `_try_unload` never lands part of
## a load, so a boat whose cargo does not fit waits forever and the island runs to a loss with nothing
## in the sim saying why.
## ⚠ **「1 + 1 = 2, because a boat carries one soldier」 is the trap here**: it shrinks the bound while
## the real simultaneous demand goes UP.
## ⚠ **Read off `Rules`, never hardcoded**, so a bigger roster moves the floor instead of leaving it
## behind — and never derived from the thing it checks, which is the shape that shrinks with its subject.
## ⚠⚠ **THE BEAST CARDS WERE IN IT AND ARE NOT ANY MORE** (2026-08-27, and this line replaces 티켓 15's
## own). The term read `(SUMMON_SLOT_MAX - START_SLOTS.size()) * SPECIES_CARD_BODIES` — four card-filled
## summon slots, four bodies each — and **every symbol in it is deleted**. ⚠ **This is NOT the summon
## slot system being written off**: `SUMMON_SLOT_MAX` and `START_SLOTS` are both alive and
## `register_species` still works. What died is the only thing that ever filled a slot mid-run, so the
## arithmetic that priced those bodies has nothing left to price — the term is zero, not forgotten.
## ⚠⚠ **A THIRD TERM DIED BEFORE EITHER OF THOSE and its lesson is the one worth keeping**: the count
## used to be per-NODE, and the plan's fix was applied to `look.gd`'s twin and not to this one — this
## repo's named 「the plan's own fix gets applied to one value and not to its siblings」.
func _min_region_floor() -> int:
	return _max_roster() + 1


## The largest roster a run can ever field. ⚠ **That is now the opening table and nothing else** — the
## `Reward.COUNT` nodes died with the map and the beast card died with the side swap, so no path exists
## from `setup` to one more body. The call still goes through `Rules` rather than a literal, so a bigger
## opening table moves the floor instead of leaving it behind.
func _max_roster() -> int:
	return Rules.roster_start_count()


# -- the walk --------------------------------------------------------------------------------------

## Walks the game's own functions from `start_tile` toward `goal_tile`, given that goal's already-built
## flow field, and reports whether the walker ever got within `reach`. Releases everything on the way
## out so the next walk starts on a clean grid.
##
## ⚠⚠ **IT USED TO RESERVE THE GOAL TILE and it does not any more.** The goal was an ENEMY — a unit
## cannot be walked onto, only approached — and `_reserve_one` existed for exactly that one line. The
## goal is a bare ground tile now, so reserving it would be refusing a walk onto empty ground for a
## reason nothing in the game has.
func _reaches(grid: Grid, start_tile: int, goal_tile: int, reach: float, field: PackedInt32Array) -> Dictionary:
	grid.release_all(WALKER_ID)
	var goal := grid.tile_point(goal_tile)
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
	return {"ok": arrived, "steps": steps, "tile": grid.tile_index(int(round(pos.x)), int(round(pos.y)))}


# -- the floor's only bite ---------------------------------------------------------------------------

## ⚠⚠ **The guarded assertion cannot redden on the shipped island under ANY formula.** The island is ONE
## connected passable component of 256 tiles, so moving the floor between 2, 5, 6 and 14 never crosses
## 256 and the mutation moves nothing but the self-check one line above. ⇒ **The floor is given a bite
## the way the sealed-goal fixture gives the walker one: a synthetic `Grid` with a pocket of exactly 9
## passable tiles holding a coast tile.** The roster floor must REJECT it and the old capacity floor of
## 5 must ACCEPT it — which is the whole difference between the two formulas, stated as a number.
##
## ⚠⚠ **The pocket was 13 tiles and had to SHRINK to 9 when the beast card was deleted** (2026-08-27).
## It was never a claim about 13; it was a claim about a pocket that sits BETWEEN the two formulas, and
## the roster floor fell from 27 to 11 the moment `SPECIES_CARD_BODIES` stopped being reachable — which
## put 13 on the passing side and would have turned this whole fixture green while measuring nothing.
## ⚠ **A fixture whose bite depends on a constant must be re-priced when that constant moves**, and the
## re-pricing is the point: 5 <= 9 < 11 is the same sentence 5 <= 13 < 27 used to say.
##
## ⚠ **The `H` in the fixture is gone with `home_harbour_for`.** It was there so the deleted harbour
## rule had a harbour to answer with; the tile this row needs is a COAST tile, and every tile in the
## pocket is one.
func _the_floor_actually_rejects_something(t, floor_now: int) -> void:
	var g := Grid.new()
	g.load_rows([
		"~~~~~~~~~~~~~~~~",
		"~....~~~~~~~~~~~",
		"~....~~~~~~~~~~~",
		"~.~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~",
	])
	var pocket := 0
	for tile in g.passable.size():
		if g.passable[tile] != 0:
			pocket += 1
	t.eq(pocket, 9, "합성 주머니는 정확히 9칸이다 (자가 점검)")

	var landing_here := -1
	for tile in g.passable.size():
		if g.passable[tile] != 0 and _touches_water(g, tile):
			landing_here = tile
			break
	t.ok(landing_here >= 0, "그 주머니 안에 배가 닿을 수 있는 해안 칸이 실제로 있다 (자가 점검)")
	t.eq(_component_size(g, landing_here), pocket,
			"그 칸이 든 땅덩이가 주머니 전부다 — 하나의 연결 성분이다 (자가 점검)")

	t.ok(pocket < floor_now,
			"상륙 구역은 최대 병력보다 크다 — 9칸 주머니는 지금 바닥(%d)에 걸린다" % floor_now)
	t.ok(pocket >= 5,
			"그리고 옛 정원 바닥 5는 그 주머니를 통과시켰다 — 두 식의 차이가 여기서 갈린다")


func _touches_water(g: Grid, tile: int) -> bool:
	var tx := tile % g.w
	var ty := tile / g.w
	for k in Grid.NEIGHBOURS.size():
		var nx := tx + int(Grid.NEIGHBOURS[k][0])
		var ny := ty + int(Grid.NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
			continue
		if g.water[ny * g.w + nx] != 0:
			return true
	return false


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
