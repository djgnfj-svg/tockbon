extends RefCounted
## **The generated island obeys every rule the user gave, over hundreds of seeds — and the same seed
## gives the same island.** Ticket 08-01.
##
## The claim under test is one sentence: **`IslandGen.board(seed)` answers a board that is ONE walking
## piece, carries 1~2 plateaus with a climbable stair into every one of them and 1~3 stairs in total,
## stands the 성채 on a plateau at least 3 칸 from every coast, holds 1~3 tree 칸 · 1~3 rock 칸 · 1~2 ore
## 칸 that all block, writes no harbour and no third storey — and does it identically the second time
## it is asked.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `IslandGen.board()` and `Grid.new()` are the whole fixture,
## which is the `src/sim/` seam `GLOSSARY.md` names.
##
## ⚠⚠ **THE WALK IS MEASURED WITH `Grid.can_step` AND NEVER WITH ARITHMETIC WRITTEN HERE.** A second
## notion of 「walkable」 in a net is the failure `how-nets-lie` collects: it goes green on a generator
## that has drifted away from the walker, which is the one thing this net exists to catch. **The
## generator asks the same function**, so the two agree by construction — and the rows below are what
## says the generator actually asked it rather than skipping the check on a board it had already made.
##
## ⚠⚠ **A GENERATOR IS MEASURED OVER MANY SEEDS OR NOT AT ALL.** One island proves one island. The
## ticket's own bar says 「a net drives the generator with `.new()` and asserts this over hundreds of
## seeds, not one」, and `SEEDS` below is that number.
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## **How many seeds every rule is asserted over.** ⚠ **The prototype measured about 20 ms an island**,
## so this row is the slowest in the suite by design — the alternative is a rule that holds for seed 1.
const SEEDS := 200
## Seeds the repeat check re-generates. **Fewer, because it doubles the cost of every one it takes.**
const REPEAT_SEEDS := 24


## ⚠⚠ **THE ISLANDS ARE MADE ONCE AND HANDED DOWN.** Every row below asks the same `SEEDS` boards, and
## a row that generated its own would multiply the cost of the slowest net in the suite by the number
## of rows — measured in the prototype at about 20 ms an island, so eight rows is eight times 4 s for
## an answer that cannot differ. **The repeat row is the exception and generates on purpose.**
func run(t) -> void:
	var made := _all_islands()
	_every_seed_makes_an_island(t, made)
	_every_island_is_one_walking_piece(t, made)
	_the_plateaus_and_their_stairs_are_within_the_ranges(t, made)
	_every_plateau_has_a_stair_a_body_can_climb(t, made)
	_the_keep_stands_on_a_plateau_three_blocks_in(t, made)
	_the_resource_blocks_are_counted_and_they_block(t, made)
	_no_harbour_and_no_third_storey(t, made)
	_the_resource_blocks_become_gatherable(t, made)
	_the_same_seed_gives_the_same_island(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the island exists at all =========================================================================

## **Every seed answers a board, and the board is the size the rules fix.**
##
## ⚠⚠ **THIS IS THE FLOOR AND WITHOUT IT EVERY ROW BELOW IS VACUOUS.** `IslandGen.board` answers an
## EMPTY dictionary when it cannot satisfy the rules, and a loop that skipped those would assert
## 「every island obeys the rules」 over the islands that happened to work. **The count is asserted, not
## the survivors.**
func _every_seed_makes_an_island(t, made: Array) -> void:
	var built := 0
	var land_ok := 0
	var b_size := Rules.BLOCK_TILES
	for row in made:
		var board: Dictionary = row["board"]
		built += 1
		if int(board["land_blocks"]) == IslandGen.LAND_BLOCKS:
			land_ok += 1
		if built == 1:
			t.eq(int(board["w"]), IslandGen.BLOCKS_W * b_size, "자가 점검 — 판 너비가 칸 수 x 조각이다")
			t.eq(int(board["h"]), IslandGen.BLOCKS_H * b_size, "자가 점검 — 판 높이가 칸 수 x 조각이다")
			t.eq((board["rows"] as PackedStringArray).size(), int(board["h"]),
				"자가 점검 — 글자줄 수가 판 높이와 같다")
			t.eq((board["tiers"] as PackedStringArray).size(), int(board["h"]),
				"자가 점검 — 높이줄 수가 판 높이와 같다")
	t.eq(built, SEEDS, "시드 %d 개가 전부 섬을 만든다" % [SEEDS])
	t.eq(land_ok, SEEDS, "섬마다 땅이 %d 칸이다 — 크기는 판마다 같다" % [IslandGen.LAND_BLOCKS])


# == the walk =========================================================================================

## **Every generated island is ONE walking piece.**
##
## ⚠⚠ **THIS IS 03-14's FIRST DEFECT MADE FRESH EVERY RUN IF IT FAILS.** A 부대 split across two walking
## components lights nothing and can be ordered nowhere; an island that comes out in two halves builds
## that state into the board itself. **The flood is `Grid.can_step`'s**, so it carries the level rule,
## the stair's axis and the diagonal shoulders with it.
## ⚠ **A stair is crossed and not counted** — it is walked across and never stood on, the same split
## `Hand._standable` makes.
func _every_island_is_one_walking_piece(t, made: Array) -> void:
	var joined := 0
	var least := 1 << 30
	for row in made:
		var grid: Grid = row["grid"]
		var got := _reached(grid)
		var want := _standable_count(grid)
		if got == want and want > 0:
			joined += 1
		least = mini(least, want)
	t.eq(joined, SEEDS, "섬은 언제나 한 덩어리다 — 갈라진 섬이 하나도 없다")
	# **The control.** A board with nothing to stand on would satisfy 「all of it is joined」 for free.
	t.ok(least >= IslandGen.LAND_BLOCKS * 2,
		"자가 점검 — 가장 좁은 섬도 설 자리가 %d 조각은 된다 (실측 최소 %d)" % [IslandGen.LAND_BLOCKS * 2, least])


# == the storeys ======================================================================================

## **Plateaus 1~2, stairs 1~3, and never fewer stairs than plateaus** (rows 12 and 13 of the spec).
func _the_plateaus_and_their_stairs_are_within_the_ranges(t, made: Array) -> void:
	var plateaus_ok := 0
	var stairs_ok := 0
	var enough := 0
	var seen_two := false
	var seen_one := false
	for row in made:
		var board: Dictionary = row["board"]
		var p := int(board["plateaus"])
		var s := int(board["stairs"])
		if p >= IslandGen.PLATEAUS_MIN and p <= IslandGen.PLATEAUS_MAX:
			plateaus_ok += 1
		if s >= IslandGen.STAIRS_MIN and s <= IslandGen.STAIRS_MAX:
			stairs_ok += 1
		if s >= p:
			enough += 1
		if p == 2:
			seen_two = true
		if p == 1:
			seen_one = true
	t.eq(plateaus_ok, SEEDS, "고원은 언제나 1~2 개다")
	t.eq(stairs_ok, SEEDS, "계단은 언제나 1~3 개다")
	t.eq(enough, SEEDS, "계단은 고원 수보다 적지 않다")
	# **The control, and it is not decoration.** A generator that always made exactly one plateau would
	# pass all three counts above — the range would be 「obeyed」 by never being used.
	t.ok(seen_one and seen_two, "자가 점검 — 고원이 하나인 섬도 둘인 섬도 나온다")


## **Every plateau is reachable: some stair enters from the ground and leaves onto that plateau.**
##
## ⚠⚠ **A STAIR CAN BE A DOOR THAT LEADS NOWHERE AND NOTHING SAYS SO.** A stair's axis is the line from
## its mouth, and `Grid._build_runs` picks that mouth by lowest 조각 index and then west, east, north,
## south — so a stair with ground on three sides can come out with an axis ACROSS its own climb, and
## `Grid._stair_face_open` then refuses every step onto it. **The stair still shows on the board, the
## island still walks through some OTHER stair, and the count still says 3.**
## ⚠ **Measured through `Grid.can_step` from a level-0 조각 to a level-2 조각 across the stair**, which
## is the only question that distinguishes a stair from a decoration.
func _every_plateau_has_a_stair_a_body_can_climb(t, made: Array) -> void:
	var climbable := 0
	var total_stairs := 0
	for row in made:
		var board: Dictionary = row["board"]
		var grid: Grid = row["grid"]
		var works := 0
		var stairs: PackedInt32Array = board["stair_blocks"]
		for k in stairs.size():
			total_stairs += 1
			if _stair_climbs(grid, int(stairs[k])):
				works += 1
		if works == stairs.size() and works >= int(board["plateaus"]):
			climbable += 1
	t.eq(climbable, SEEDS, "섬마다 계단이 전부 오를 수 있는 계단이다")
	t.ok(total_stairs >= SEEDS, "자가 점검 — 잰 계단이 시드 수보다 많다 (총 %d)" % [total_stairs])


# == the 성채 =========================================================================================

## **The 성채 stands on a plateau 조각, three 칸 in from every coast** (rows 5 and 6).
##
## ⚠ **The distance is measured on the FINISHED board and not on the number the generator kept.** A
## generator that wrote its own answer into the dictionary would pass a row that read the dictionary.
func _the_keep_stands_on_a_plateau_three_blocks_in(t, made: Array) -> void:
	var on_plateau := 0
	var deep := 0
	for row in made:
		var board: Dictionary = row["board"]
		var grid: Grid = row["grid"]
		var builds: Array = board["builds"]
		if builds.is_empty():
			continue
		var keep_tile := grid.tile_index(int(builds[0]["x"]), int(builds[0]["y"]))
		if grid.level_of(keep_tile) == 2:
			on_plateau += 1
		if _coast_blocks_from(grid, keep_tile) >= IslandGen.KEEP_COAST_BLOCKS:
			deep += 1
	t.eq(on_plateau, SEEDS, "성채는 언제나 2층에 선다")
	t.eq(deep, SEEDS, "성채는 언제나 모든 해안에서 %d 칸 이상 안쪽이다" % [IslandGen.KEEP_COAST_BLOCKS])


# == the resource 칸 ==================================================================================

## **1~3 tree 칸 · 1~3 rock 칸 · 1~2 ore 칸, each a whole 칸, each blocking, each on the island**
## (rows 8 ~ 11).
##
## ⚠⚠ **「IT BLOCKS」 IS THE HALF THAT COULD ROT SILENTLY.** A resource written as a prop on walkable
## ground would satisfy every count below and change nothing about the board. **The 조각 under a
## resource is asserted impassable, and asserted NOT water** — impassable-and-wet is the sea, which
## would pass a bare 「not walkable」 test from anywhere off the island.
func _the_resource_blocks_are_counted_and_they_block(t, made: Array) -> void:
	var counted := 0
	var blocking := 0
	for row in made:
		var board: Dictionary = row["board"]
		var grid: Grid = row["grid"]
		var blocks := {}
		var kinds := {"tree_pine": {}, "rock": {}, "ore": {}}
		var stands := true
		for raw in board["props"] as Array:
			var prop: Dictionary = raw
			var tile := grid.tile_index(int(prop["x"]), int(prop["y"]))
			if grid.passable[tile] != 0 or grid.water[tile] != 0:
				stands = false
			blocks[grid.block_of(tile)] = true
			if kinds.has(prop["kind"]):
				(kinds[prop["kind"]] as Dictionary)[grid.block_of(tile)] = true
		var trees := (kinds["tree_pine"] as Dictionary).size()
		var rocks := (kinds["rock"] as Dictionary).size()
		var ores := (kinds["ore"] as Dictionary).size()
		if trees >= IslandGen.TREES_MIN and trees <= IslandGen.TREES_MAX \
				and rocks >= IslandGen.ROCKS_MIN and rocks <= IslandGen.ROCKS_MAX \
				and ores >= IslandGen.ORE_MIN and ores <= IslandGen.ORE_MAX \
				and blocks.size() == trees + rocks + ores:
			counted += 1
		if stands:
			blocking += 1
	t.eq(counted, SEEDS, "자원 칸은 언제나 나무 1~3 · 돌 1~3 · 철 1~2 이고 서로 다른 칸이다")
	t.eq(blocking, SEEDS, "자원 칸의 조각은 전부 못 지나가고, 물도 아니다")


# == the legend =======================================================================================

## **No harbour letter, and no storey above the second** (row 7, and 용어집: 「3층은 없다」).
func _no_harbour_and_no_third_storey(t, made: Array) -> void:
	var clean := 0
	var flat := 0
	for row in made:
		var board: Dictionary = row["board"]
		var harbour := false
		var high := false
		for row in board["rows"] as PackedStringArray:
			if String(row).find("H") >= 0:
				harbour = true
		for row in board["tiers"] as PackedStringArray:
			var line := String(row)
			for i in line.length():
				if "./12".find(line[i]) < 0:
					high = true
		if not harbour:
			clean += 1
		if not high:
			flat += 1
	t.eq(clean, SEEDS, "생성된 섬에 항구 글자가 하나도 없다")
	t.eq(flat, SEEDS, "높이 글자는 0층 · 계단 · 2층 셋뿐이다 — 3층은 없다")


## **A generated board's props, handed to `Grid.set_resources`, come back as the resource 칸 a body can
## gather from.** Tickets 08-02 and 05-05.
##
## ⚠⚠ **THIS IS THE SEAM BETWEEN THE TWO HALVES AND NOTHING ELSE MEASURES IT.** The generator stands
## its props on `#` 조각 and `Grid.set_resources` reads a resource 칸 as 「impassable, dry, carrying a
## prop」 — **two files agreeing on a convention neither one states.** Change either side and the
## generator keeps making islands, the gathering keeps working on a hand-made fixture, and a generated
## island quietly has nothing to gather on it.
##
## ⚠ **The counts are re-derived from the letters here**, not read out of the generator's own answer:
## a board that wrote its resource count into the dictionary would pass a row that read the dictionary.
func _the_resource_blocks_become_gatherable(t, made: Array) -> void:
	var matched := 0
	var gatherable := 0
	for row in made:
		var board: Dictionary = row["board"]
		var grid: Grid = row["grid"]
		grid.set_resources(board["props"] as Array)
		# **The 칸 the letters say are blocked**, counted off the board itself.
		var blocked := {}
		for tile in grid.w * grid.h:
			if grid.passable[tile] == 0 and grid.water[tile] == 0:
				blocked[grid.block_of(tile)] = true
		var named := {}
		for tile in grid.w * grid.h:
			var kind := grid.resource_at(tile)
			if kind == "":
				continue
			named[grid.block_of(tile)] = true
			if kind != "wood" and kind != "rock" and kind != "ore":
				named[-1] = true
		if blocked.size() == named.size() and not named.has(-1) and blocked.size() >= 3:
			matched += 1
		# **And a body could actually stand somewhere and gather it** — every resource 칸 has at least
		# one walkable 조각 touching it, or it is a pile nobody can reach.
		var reachable := 0
		for b in named:
			var open := false
			for raw in grid.tiles_of_block(int(b)):
				var seat := int(raw)
				var tx := seat % grid.w
				var ty := seat / grid.w
				for k in Grid.NEIGHBOURS.size():
					var nx: int = tx + int(Grid.NEIGHBOURS[k][0])
					var ny: int = ty + int(Grid.NEIGHBOURS[k][1])
					if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
						continue
					if grid.passable[ny * grid.w + nx] == 1:
						open = true
			if open:
				reachable += 1
		if reachable == named.size() and named.size() > 0:
			gatherable += 1
	t.eq(matched, SEEDS, "막힌 칸과 자원 칸이 하나도 안 어긋난다 — 셋 이상, 전부 나무·돌·철이다")
	t.eq(gatherable, SEEDS, "자원 칸마다 옆에 설 자리가 있다 — 못 가는 자원 칸이 없다")


# == the seed =========================================================================================

## **The same seed gives the same island, letter for letter.**
##
## ⚠⚠ **THIS IS THE ROW EVERY OTHER ONE RESTS ON.** The rows above ask for one seed's board more than
## once, and if the answer moved between calls they would each be measuring a different island.
## ⚠ **Rows AND tiers AND the 성채 AND the props**, because a generator can be repeatable in its shape
## and not in what it scatters — the props draw last and from the same stream.
func _the_same_seed_gives_the_same_island(t) -> void:
	var same := 0
	for seed_value in range(1, REPEAT_SEEDS + 1):
		var first: Dictionary = IslandGen.board(seed_value)
		var again: Dictionary = IslandGen.board(seed_value)
		if first.is_empty() or again.is_empty():
			continue
		if String("\n").join(first["rows"] as PackedStringArray) == String("\n").join(again["rows"] as PackedStringArray) \
				and String("\n").join(first["tiers"] as PackedStringArray) == String("\n").join(again["tiers"] as PackedStringArray) \
				and first["builds"] == again["builds"] \
				and first["props"] == again["props"]:
			same += 1
	t.eq(same, REPEAT_SEEDS, "같은 시드는 같은 섬을 준다 — 글자 · 높이 · 성채 · 물건까지")
	# **The control.** A generator that ignored the seed would pass the row above perfectly.
	var one := IslandGen.board(1)
	var two := IslandGen.board(2)
	t.ok(String("\n").join(one["rows"] as PackedStringArray) != String("\n").join(two["rows"] as PackedStringArray),
		"자가 점검 — 시드가 다르면 섬도 다르다")


# == fixtures =========================================================================================

## **Every island this net measures, made once**, each with the `Grid` the rest of the rows walk.
## ⚠ **A seed that answered nothing is kept out of the list and counted by the row above** — the size
## of what comes back is itself the first assertion.
func _all_islands() -> Array:
	var out: Array = []
	for seed_value in range(1, SEEDS + 1):
		var board: Dictionary = IslandGen.board(seed_value)
		if board.is_empty():
			continue
		out.append({"seed": seed_value, "board": board, "grid": _grid_of(board)})
	return out


## **A real `Grid` over a generated board** — the same call `Islands.load_into` makes, so what this net
## walks is what the game would walk.
func _grid_of(board: Dictionary) -> Grid:
	var grid := Grid.new()
	grid.load_rows(Array(board["rows"] as PackedStringArray), Array(board["tiers"] as PackedStringArray))
	return grid


## Every 조각 a body may stand on: passable, and not a stair.
func _standable_count(grid: Grid) -> int:
	var n := 0
	for t in grid.w * grid.h:
		if grid.passable[t] == 1 and not Grid.is_stair_level(grid.level_of(t)):
			n += 1
	return n


## **How many standable 조각 one `Grid.can_step` flood reaches from the first one.** ⚠ Stairs ride the
## flood and are not counted, which is what `Hand._build_reach` does with them.
func _reached(grid: Grid) -> int:
	var n := grid.w * grid.h
	var start := -1
	for t in n:
		if grid.passable[t] == 1 and not Grid.is_stair_level(grid.level_of(t)):
			start = t
			break
	if start < 0:
		return 0
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	seen[start] = 1
	queue.append(start)
	var head := 0
	var got := 0
	while head < queue.size():
		var cur := int(queue[head])
		head += 1
		if not Grid.is_stair_level(grid.level_of(cur)):
			got += 1
		var cx := cur % grid.w
		var cy := cur / grid.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = cx + int(dx)
				var ny: int = cy + int(dy)
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := ny * grid.w + nx
				if seen[nt] == 1 or not grid.can_step(cur, nt):
					continue
				seen[nt] = 1
				queue.append(nt)
	return got


## **Whether a body can climb the stair standing on this 칸** — step onto it from level 0, and off it
## onto level 2. See the row that calls this for why the question has to be asked this way.
func _stair_climbs(grid: Grid, block: int) -> bool:
	var entered := false
	var exited := false
	for raw in grid.tiles_of_block(block):
		var tile := int(raw)
		var tx := tile % grid.w
		var ty := tile / grid.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = tx + int(dx)
				var ny: int = ty + int(dy)
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := ny * grid.w + nx
				if grid.passable[nt] != 1:
					continue
				if grid.level_of(nt) == 0 and grid.can_step(nt, tile):
					entered = true
				if grid.level_of(nt) == 2 and grid.can_step(tile, nt):
					exited = true
	return entered and exited


## **How many 칸 this 조각 stands from the nearest 칸 that is not land** — Chebyshev over the 칸 board,
## by a flood, so a diagonal counts as one. ⚠ **Re-derived here from the letters** rather than read out
## of the generator's own answer, which is the whole point of the row that calls it.
func _coast_blocks_from(grid: Grid, tile: int) -> int:
	var b_size := Rules.BLOCK_TILES
	var bw := (grid.w + b_size - 1) / b_size
	var bh := (grid.h + b_size - 1) / b_size
	# **Land is anything DRY** — walkable ground and a resource 칸 both. A resource 칸 is impassable
	# and dry, and it is still island: counting it as coast would move the 성채's measured depth for
	# a reason that has nothing to do with the sea.
	var land := {}
	for t in grid.w * grid.h:
		if grid.water[t] == 0:
			land[grid.block_of(t)] = true
	var here := grid.block_of(tile)
	var best := 1 << 30
	# **Every 칸 that is NOT land is a coast for this measure**, including the board's own rim.
	for by in bh:
		for bx in bw:
			var b := by * bw + bx
			if land.has(b):
				continue
			var d: int = maxi(absi(bx - here % bw), absi(by - here / bw))
			best = mini(best, d)
	return best
