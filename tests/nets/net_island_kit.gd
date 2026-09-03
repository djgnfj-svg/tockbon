extends RefCounted
## **Every land 칸 of a board gets exactly one kit block, and it is the block the board's own shape
## asks for.** Ticket 08-01, stage 1.
##
## The claim under test is one sentence: **`IslandKit.plan(grid)` answers one block per land 칸, named
## for that 칸's 눈금 and for which of its four sides are open, placed on that 칸's centre — on the
## drawn island, on hundreds of generated ones, and on a 칸 hanging off the board's rim — and it
## answers the same thing the second time it is asked.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE EXCEPT TO READ THE KIT'S NAMES.** `Grid.new()` and
## `IslandGen.board()` are the fixture, which is the `src/sim/` seam `GLOSSARY.md` names. The one
## exception is `_kit_names`, which instantiates `pieces.glb` to read what is actually in it — see
## the row that uses it for why a hard-coded list there would be a false green.
##
## ⚠⚠ **THE MASK IS RE-DERIVED HERE AND NEVER READ OUT OF `IslandKit`.** A row that asked
## `IslandKit.open_sides` what the mask was and then checked the name against that mask would be
## asking the subject to grade itself: the two would agree on a chooser that had the whole rule
## backwards. `_open_sides_here` walks the board's own letters and heights, and `_mask_in_name`
## reads the mask back out of the kit's table — **the two meet at the name, which is the only place
## they can disagree.**
##
## ⚠ **The labels are Korean because they are printed output**; the prose is English.

## **How many generated boards every rule is asserted over.** ⚠ **An island costs about 20 ms to
## generate** (`net_island_gen`), so this row is most of this net's runtime — and one island proves
## one island.
const SEEDS := 80


func run(t) -> void:
	_the_four_sides_are_the_four_sides(t)
	_the_table_covers_every_shape(t)
	_every_name_is_really_in_the_kit(t)
	_every_block_is_carved_on_the_sides_the_table_calls_open(t)
	_every_stair_mesh_falls_away_on_the_side_the_table_names(t)
	_the_drawn_island_is_covered_block_for_block(t)
	_the_drawn_island_stair_climbs_the_way_the_board_climbs(t)
	_the_same_board_gives_the_same_plan(t)
	_generated_boards_are_covered_too(t)
	_a_kan_on_the_rim_is_open_on_every_side_that_hangs_off(t)
	_a_drop_opens_the_high_side_and_not_the_low_one(t)
	_a_stair_is_named_for_the_way_it_climbs(t)
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the vocabulary ===================================================================================

## **`IslandKit`'s four side bits name the four directions `Grid.STAIR_MOUTH_ORDER` actually holds.**
##
## ⚠⚠ **THIS IS THE ROW EVERY OTHER ONE RESTS ON.** `IslandKit` writes its bits as `1 <<` an index
## into that list rather than keeping its own copy of west/east/north/south. **Reorder the list and
## every block in the kit silently turns 90 degrees** — the island would still assemble, still be one
## walking piece, and still be wrong in every frame. Nothing else in the suite would say a word.
func _the_four_sides_are_the_four_sides(t) -> void:
	var order: Array = Grid.STAIR_MOUTH_ORDER
	t.eq(order[0], Vector2i(-1, 0), "서쪽 비트가 진짜 서쪽이다 — 조각 x 가 하나 작다")
	t.eq(order[1], Vector2i(1, 0), "동쪽 비트가 진짜 동쪽이다 — 조각 x 가 하나 크다")
	t.eq(order[2], Vector2i(0, -1), "북쪽 비트가 진짜 북쪽이다 — 조각 y 가 하나 작다")
	t.eq(order[3], Vector2i(0, 1), "남쪽 비트가 진짜 남쪽이다 — 조각 y 가 하나 크다")


# == the table ========================================================================================

## **All 32 shapes have a block, and so do all four stair directions.**
##
## ⚠⚠ **A HOLE HERE IS A HOLE IN THE GROUND.** `IslandKit.plan` places nothing on a combination it
## has no block for, so a missing row is an island with a 칸 of sea in the middle of it. The kit was
## finished in Blender precisely so the count below could be 32 and the code could turn nothing.
func _the_table_covers_every_shape(t) -> void:
	var covered := 0
	var storeys := [0, 2]
	for level in storeys:
		for mask in 16:
			if not IslandKit.blocks_for(int(level), mask).is_empty():
				covered += 1
	t.eq(covered, storeys.size() * 16, "0층과 2층의 열여섯 모양이 전부 블록을 갖는다 — 32 개")
	var stairs := 0
	for side in [IslandKit.SIDE_WEST, IslandKit.SIDE_EAST, IslandKit.SIDE_NORTH, IslandKit.SIDE_SOUTH]:
		if IslandKit.stair_for_low_side(int(side)) != "":
			stairs += 1
	t.eq(stairs, 4, "계단은 네 방향 전부 블록을 갖는다")
	# **The controls, and they are what says the two rows above measured a lookup at all.** A table
	# that answered SOMETHING for every question would satisfy both counts perfectly.
	t.ok(IslandKit.blocks_for(4, 0).is_empty(), "자가 점검 — 3층은 블록이 없다, 빈손으로 답한다")
	t.ok(IslandKit.blocks_for(0, 16).is_empty(), "자가 점검 — 없는 모양은 빈손으로 답한다")
	t.ok(IslandKit.stair_for_low_side(IslandKit.SIDE_WEST | IslandKit.SIDE_EAST) == "",
		"자가 점검 — 두 방향을 한꺼번에 내려가는 계단은 없다")


## **Every name the table holds is really a node in `pieces.glb`.**
##
## ⚠⚠ **READ OUT OF THE FILE, NEVER LISTED HERE.** A list of 41 names typed into this net would go
## green on a kit that had been re-baked without half of them — the table would name meshes that no
## longer exist and the island would come up full of holes with nothing said. **The file is the
## authority and this row asks it.**
func _every_name_is_really_in_the_kit(t) -> void:
	var kit := _kit_names()
	t.ok(kit.size() > 0, "자가 점검 — 키트 파일이 열리고 이름이 나온다 (실측 %d)" % [kit.size()])
	var named := _table_names()
	var missing := 0
	for one in named:
		if not kit.has(one):
			missing += 1
	t.eq(missing, 0, "표의 이름 %d 개가 전부 키트 안에 있다" % [named.size()])
	# **The control.** A reader that answered 「yes」 to everything would pass the row above.
	t.ok(not kit.has("KIT_0_solid_999"), "자가 점검 — 키트에 없는 이름은 못 찾는다")


## **Every block really is carved on the sides the table says are open, and flat on the rest.**
##
## ⚠⚠ **WITHOUT THIS ROW THE TABLE IS ONLY A CLAIM.** Every other row asks whether the chooser picked
## the name the table holds for a shape; **none of them asks whether that name is the right mesh.**
## Swap two masks and the island assembles perfectly out of the wrong blocks — cliffs facing inland,
## coast skirts pointing at the plateau — and nothing goes red. The meshes are the only witness that
## is not the table, so the table is put in front of them.
##
## **The measure is one number per side: how many of that side's vertices sit between the block's
## bottom and the top of a 2층.** A flat seam between two 칸 is a plain wall and has almost none; a
## sculpted cliff or a coast skirt is dense with them.
##
## ⚠ **NO THRESHOLD IS CHOSEN, AND THAT IS DELIBERATE.** A number picked here would rot the first time
## the kit was re-baked at another density. **What is asserted is that the two groups do not overlap**
## — the busiest side the table calls flat is quieter than the quietest side it calls carved — which
## is a claim about the table, not about the mesh's resolution. One wrong row drops a carved side into
## the flat group and the two groups collide.
func _every_block_is_carved_on_the_sides_the_table_calls_open(t) -> void:
	var lib := _kit_root()
	if lib == null:
		t.ok(false, "자가 점검 — 키트 파일이 안 열린다")
		return
	var busiest_flat := -1
	var quietest_carved := 1 << 30
	var flat := 0
	var carved := 0
	for level in [0, 2]:
		for mask in 16:
			for one in IslandKit.blocks_for(int(level), mask):
				var counts := _side_detail_of(lib, String(one))
				if counts.is_empty():
					continue
				for k in counts.size():
					if (mask & (1 << k)) != 0:
						quietest_carved = mini(quietest_carved, int(counts[k]))
						carved += 1
					else:
						busiest_flat = maxi(busiest_flat, int(counts[k]))
						flat += 1
	lib.free()
	t.ok(flat > 0 and carved > 0,
		"자가 점검 — 잰 면이 있다 — 막힌 면 %d · 열린 면 %d" % [flat, carved])
	t.ok(busiest_flat < quietest_carved,
		"표가 막혔다는 면은 전부 밋밋하고 열렸다는 면은 전부 깎여 있다 — 막힌 쪽 최대 %d · 열린 쪽 최소 %d"
			% [busiest_flat, quietest_carved])


## **Each stair mesh's ground really does fall away on the side the table names.**
##
## ⚠⚠ **THE ROW THAT STOPS THE STAIR TABLE GRADING ITSELF.** Every other stair row compares the name
## the chooser picked against the name the table holds for a direction — swap two rows of the table
## and both sides of that comparison move together and stay green. **The mesh cannot move with them.**
##
## ⚠ **The axis names are anchored by the drawn island and not assumed here.** That board's letters
## say its staircase climbs west to east; the row above picks `SIDE_WEST` off the letters alone; this
## row measures that same block falling away on −x. **The three together are what make −x west.**
func _every_stair_mesh_falls_away_on_the_side_the_table_names(t) -> void:
	var lib := _kit_root()
	if lib == null:
		t.ok(false, "자가 점검 — 키트 파일이 안 열린다")
		return
	var sides := [IslandKit.SIDE_WEST, IslandKit.SIDE_EAST, IslandKit.SIDE_NORTH, IslandKit.SIDE_SOUTH]
	var labels := ["서쪽", "동쪽", "북쪽", "남쪽"]
	var lowest_seen := {}
	for i in sides.size():
		var one := IslandKit.stair_for_low_side(int(sides[i]))
		var tops := _side_tops_of(lib, one)
		if tops.is_empty():
			t.ok(false, "자가 점검 — %s 계단 블록을 키트에서 못 찾는다" % [labels[i]])
			continue
		var lowest := 0
		for k in tops.size():
			if float(tops[k]) < float(tops[lowest]):
				lowest = k
		lowest_seen[lowest] = true
		t.eq(1 << lowest, int(sides[i]),
			"%s 계단 블록은 정말 %s 끝이 낮다 — 메시가 그렇게 깎여 있다" % [labels[i], labels[i]])
	lib.free()
	# **The control.** Four names all falling away on the same side would satisfy nothing above if the
	# table were right, but it is what a table wired to one block four times would look like.
	t.eq(lowest_seen.size(), 4, "자가 점검 — 계단 넷이 서로 다른 네 방향으로 내려간다")


# == the drawn island =================================================================================

## **Every land 칸 of the drawn island gets exactly one block, on its own centre, named for its own
## shape — and no 칸 that is not land gets one.**
##
## ⚠⚠ **THE DRAWN ISLAND IS THE YARDSTICK BOARD** and it is loaded through `Islands.load_into`, which
## is the door the game itself walks through. A board opened any other way would skip the outline and
## the resource 칸 and stop being the island the player sees.
func _the_drawn_island_is_covered_block_for_block(t) -> void:
	var grid := Grid.new()
	Islands.load_into(grid)
	var plan: Array = IslandKit.plan(grid)
	var land := _land_blocks(grid)
	t.ok(land.size() > 0, "자가 점검 — 그린 섬에 땅 칸이 있다 (실측 %d 칸)" % [land.size()])
	t.eq(plan.size(), land.size(), "그린 섬의 땅 칸마다 블록이 하나씩, 하나도 안 빠진다")
	var placed := {}
	var off_land := 0
	for raw in plan:
		var row: Dictionary = raw
		var block := int(row["block"])
		placed[block] = true
		if not land.has(block):
			off_land += 1
	t.eq(placed.size(), plan.size(), "한 칸에 블록이 둘 서지 않는다")
	t.eq(off_land, 0, "땅이 아닌 칸에는 아무것도 안 선다")
	t.eq(_shape_mismatches(grid, plan), 0, "블록 이름이 판이 말하는 열린 면과 하나도 안 어긋난다")
	t.eq(_centre_mismatches(grid, plan), 0, "블록은 제 칸의 한가운데에 선다")


## **The drawn island's one stair 칸 gets a stair, and it is the one whose LOW end faces west —
## which is the way that board actually climbs.**
##
## ⚠⚠ **THE DIRECTION IS TAKEN OFF THE TIER LETTERS HERE, NOT OFF `Grid.stair_run_of`.** The chooser
## reads the run because the walking rule does; a net that read the same run would go green on a
## stair drawn climbing one way while the ground rose the other. **The board says 2층 is EAST of the
## staircase and 0층 is WEST of it**, so the low end faces west and nothing but the letters was asked.
##
## ⚠ **The staircase has 0층 on THREE sides** — west, north and south — so 「the side the ground is
## lower on」 does not pick one on its own. What does is the pair: the low end is the side whose
## OPPOSITE side is the storey above, and on this board that is west and only west.
func _the_drawn_island_stair_climbs_the_way_the_board_climbs(t) -> void:
	var grid := Grid.new()
	Islands.load_into(grid)
	var plan: Array = IslandKit.plan(grid)
	var stairs: Array = []
	for raw in plan:
		var row: Dictionary = raw
		if Grid.is_stair_level(_storey_here(grid, int(row["block"]))):
			stairs.append(row)
	t.eq(stairs.size(), 1, "그린 섬에 계단 칸이 하나다")
	if stairs.is_empty():
		return
	var stair: Dictionary = stairs[0]
	var block := int(stair["block"])
	t.eq(_climb_low_side_by_letters(grid, block), IslandKit.SIDE_WEST,
		"자가 점검 — 판의 글자가 말하는 오르는 쪽은 서쪽에서 동쪽 하나뿐이다")
	t.eq(String(stair["name"]), IslandKit.stair_for_low_side(IslandKit.SIDE_WEST),
		"계단 칸은 낮은 끝이 서쪽인 계단 블록을 받는다")


## **The same board gives the same plan twice — the same names in the same order on the same 칸.**
##
## ⚠⚠ **THE JITTERED SHAPES ARE WHAT THIS ROW IS FOR.** Several blocks answer one mask, and a chooser
## that picked among them with a random number would make an island that changed every time it was
## looked at, while every other row in this net stayed green.
func _the_same_board_gives_the_same_plan(t) -> void:
	var grid := Grid.new()
	Islands.load_into(grid)
	var first: Array = IslandKit.plan(grid)
	var again: Array = IslandKit.plan(grid)
	t.eq(first, again, "같은 판은 같은 배치를 준다 — 이름 · 칸 · 자리까지")
	# **The control.** Two empty answers are equal for free.
	t.ok(first.size() > 0, "자가 점검 — 비교한 배치가 비어 있지 않다")


# == the generated boards =============================================================================

## **Every land 칸 of every generated island gets exactly one block, named for its own shape, and
## every name is one the kit really holds.**
##
## ⚠⚠ **THIS IS THE ROW THAT WOULD CATCH A HOLE IN THE TABLE.** The drawn island uses a handful of
## the 32 shapes; a generated coastline turns in every direction and lands on the rest. A combination
## with no block is a 칸 that gets nothing, so the count below is what says every combination was
## handled — no separate 「unhandled」 list is kept, because a list nobody reads is how the last one
## went quiet.
func _generated_boards_are_covered_too(t) -> void:
	var kit := _kit_names()
	var covered := 0
	var shapes_ok := 0
	var in_kit := 0
	var stairs_ok := 0
	var shapes_seen := {}
	var made := 0
	for seed_value in range(1, SEEDS + 1):
		var board: Dictionary = IslandGen.board(seed_value)
		if board.is_empty():
			continue
		made += 1
		var grid := Grid.new()
		Islands.load_board(grid, board)
		var plan: Array = IslandKit.plan(grid)
		var land := _land_blocks(grid)
		if plan.size() == land.size() and land.size() > 0:
			covered += 1
		if _shape_mismatches(grid, plan) == 0:
			shapes_ok += 1
		var stray := 0
		var stairs := 0
		var stairs_wrong := 0
		for raw in plan:
			var row: Dictionary = raw
			var one := String(row["name"])
			shapes_seen[one] = true
			if not kit.has(one):
				stray += 1
			if not Grid.is_stair_level(_storey_here(grid, int(row["block"]))):
				continue
			stairs += 1
			if _low_side_of_name(one) != _run_low_side(grid, int(row["block"])):
				stairs_wrong += 1
		if stray == 0:
			in_kit += 1
		if stairs > 0 and stairs_wrong == 0:
			stairs_ok += 1
	t.eq(made, SEEDS, "자가 점검 — 시드 %d 개가 전부 섬을 만든다" % [SEEDS])
	t.eq(covered, SEEDS, "생성된 섬도 땅 칸마다 블록이 하나씩이다 — 표에 구멍이 없다")
	t.eq(shapes_ok, SEEDS, "생성된 섬의 블록 이름이 판이 말하는 열린 면과 안 어긋난다")
	t.eq(in_kit, SEEDS, "생성된 섬이 쓰는 이름이 전부 키트 안에 있다")
	t.eq(stairs_ok, SEEDS, "생성된 섬의 계단은 발이 오르는 쪽으로 놓인다 — 걷기 규칙이 말하는 그 쪽이다")
	# **The control, and it is not decoration.** A generator that only ever made one shape of island
	# would satisfy every count above while leaving most of the table untouched.
	t.ok(shapes_seen.size() >= 20,
		"자가 점검 — 생성된 섬들이 서로 다른 블록을 스무 가지 넘게 쓴다 (실측 %d)" % [shapes_seen.size()])


# == the rim and the drop =============================================================================

## **A side that hangs off the board is OPEN** — measured on a board that is one 칸 and nothing else,
## and on a two-칸 strip, so the rim case is measured rather than assumed.
func _a_kan_on_the_rim_is_open_on_every_side_that_hangs_off(t) -> void:
	var alone := _board_of(["..", ".."], ["..", ".."])
	var plan: Array = IslandKit.plan(alone)
	t.eq(plan.size(), 1, "판 전체가 한 칸이면 블록도 하나다")
	if plan.size() == 1:
		t.eq(_mask_in_name(String((plan[0] as Dictionary)["name"])),
			IslandKit.SIDE_WEST | IslandKit.SIDE_EAST | IslandKit.SIDE_NORTH | IslandKit.SIDE_SOUTH,
			"판 밖으로만 둘러싸인 칸은 네 면이 다 열린다")
	var strip := _board_of(["....", "...."], ["....", "...."])
	var two: Array = IslandKit.plan(strip)
	t.eq(two.size(), 2, "두 칸짜리 판은 블록이 둘이다")
	if two.size() == 2:
		t.eq(_mask_in_name(String((two[0] as Dictionary)["name"])),
			IslandKit.SIDE_WEST | IslandKit.SIDE_NORTH | IslandKit.SIDE_SOUTH,
			"서쪽 끝 칸은 동쪽만 닫힌다 — 옆에 땅이 있으니까")
		t.eq(_mask_in_name(String((two[1] as Dictionary)["name"])),
			IslandKit.SIDE_EAST | IslandKit.SIDE_NORTH | IslandKit.SIDE_SOUTH,
			"동쪽 끝 칸은 서쪽만 닫힌다")
	# **Water is not land and gets nothing**, which is what says the two rows above measured land.
	var sea := _board_of(["~~~~", "~~~~"], ["....", "...."])
	t.eq((IslandKit.plan(sea) as Array).size(), 0, "물뿐인 판에는 블록이 하나도 안 선다")


## **A drop opens the HIGH 칸's side and leaves the LOW one closed** — the cliff is drawn on the 칸
## that has the cliff, never on the one at the bottom of it.
##
## ⚠⚠ **THIS IS THE INVERTED CASE FOR THE WHOLE RULE.** A chooser that compared the two heights the
## other way round would still give every 칸 exactly one block, still repeat, and still use only names
## that are in the kit — every other row in this net would stay green while every cliff on every
## island faced inward.
func _a_drop_opens_the_high_side_and_not_the_low_one(t) -> void:
	var grid := _board_of(["....", "...."], ["..22", "..22"])
	var plan: Array = IslandKit.plan(grid)
	t.eq(plan.size(), 2, "자가 점검 — 낮은 칸과 높은 칸 둘이다")
	if plan.size() != 2:
		return
	var low := String((plan[0] as Dictionary)["name"])
	var high := String((plan[1] as Dictionary)["name"])
	t.eq(IslandKit.level_of_name(low), 0, "자가 점검 — 서쪽이 0층이다")
	t.eq(IslandKit.level_of_name(high), 2, "자가 점검 — 동쪽이 2층이다")
	t.eq(_mask_in_name(low), IslandKit.SIDE_WEST | IslandKit.SIDE_NORTH | IslandKit.SIDE_SOUTH,
		"낮은 칸은 높은 이웃 쪽이 닫힌다 — 절벽은 그쪽 것이 아니다")
	t.eq(_mask_in_name(high),
		IslandKit.SIDE_WEST | IslandKit.SIDE_EAST | IslandKit.SIDE_NORTH | IslandKit.SIDE_SOUTH,
		"높은 칸은 낮은 이웃 쪽이 열린다 — 절벽이 그쪽에 선다")


## **A stair is named for the way it climbs, in all four directions.**
##
## ⚠⚠ **FOUR BOARDS AND NOT ONE.** The drawn island climbs west-to-east and only west-to-east; a
## chooser that answered `KIT_1_stair_31` to every stair on earth would pass the drawn-island row and
## every generated board that happened to climb the same way. **Each board below is the previous one
## turned round**, so a swapped pair fails here and nowhere else.
func _a_stair_is_named_for_the_way_it_climbs(t) -> void:
	var flat := ["......", "......"]
	var tall := ["..", "..", "..", "..", "..", ".."]
	_one_stair_climbs(t, _board_of(flat, ["001122", "001122"]), IslandKit.SIDE_WEST, "서쪽")
	_one_stair_climbs(t, _board_of(flat, ["221100", "221100"]), IslandKit.SIDE_EAST, "동쪽")
	_one_stair_climbs(t, _board_of(tall, ["00", "00", "11", "11", "22", "22"]),
		IslandKit.SIDE_NORTH, "북쪽")
	_one_stair_climbs(t, _board_of(tall, ["22", "22", "11", "11", "00", "00"]),
		IslandKit.SIDE_SOUTH, "남쪽")


## One board, three 칸 in a line, and the middle one is the staircase.
func _one_stair_climbs(t, grid: Grid, low_side: int, label: String) -> void:
	var plan: Array = IslandKit.plan(grid)
	var got := ""
	for raw in plan:
		var row: Dictionary = raw
		if Grid.is_stair_level(IslandKit.level_of_block(grid, int(row["block"]))):
			got = String(row["name"])
	t.eq(got, IslandKit.stair_for_low_side(low_side),
		"낮은 끝이 %s인 계단에는 %s으로 내려가는 블록이 선다" % [label, label])


# == fixtures =========================================================================================

## **A board built from letters and nothing else** — the smallest `Grid` this net can hold in its head.
func _board_of(rows: Array, tiers: Array) -> Grid:
	var grid := Grid.new()
	grid.load_rows(rows, tiers)
	return grid


## **Every 칸 of `grid` that is land**, as a set. ⚠ **Land is DRY, never 「walkable」** — a 자원 칸 is
## impassable and dry and it is still island, and a 칸 of it still needs a block to stand on.
func _land_blocks(grid: Grid) -> Dictionary:
	var out := {}
	for t in grid.w * grid.h:
		if grid.water[t] == 0:
			out[grid.block_of(t)] = true
	return out


## **Which sides of a 칸 this NET says are open**, walked off the board's own letters and heights.
##
## ⚠⚠ **A SECOND OPINION ON PURPOSE, AND THE ONLY REASON THE SHAPE ROWS MEAN ANYTHING.** It asks
## `Grid.block_of` and `Grid.tiles_of_block` for 칸 identity — a third notion of which 조각 belong to
## which 칸 is the failure `how-nets-lie` collects — but it works out the OPEN-ness itself.
func _open_sides_here(grid: Grid, block: int) -> int:
	var here := _storey_here(grid, block)
	var tiles := grid.tiles_of_block(block)
	if tiles.is_empty():
		return 0
	var p := grid.tile_point(int(tiles[0]))
	var mask := 0
	for k in Grid.STAIR_MOUTH_ORDER.size():
		var d: Vector2i = Grid.STAIR_MOUTH_ORDER[k]
		var nx := int(p.x) + d.x * Rules.BLOCK_TILES
		var ny := int(p.y) + d.y * Rules.BLOCK_TILES
		var beyond := -1
		if nx >= 0 and ny >= 0 and nx < grid.w and ny < grid.h:
			beyond = _storey_here(grid, grid.block_of(grid.tile_index(nx, ny)))
		if beyond < 0 or here - beyond > Rules.MAX_CLIMB_LEVELS:
			mask |= 1 << k
	return mask


## **The 눈금 of a 칸 as this net reads it, or -1 when the 칸 is not land at all.** The maximum EVEN
## 눈금 over its dry 조각, and the odd one when every dry 조각 it has is a stair tread.
func _storey_here(grid: Grid, block: int) -> int:
	var floor_lv := -1
	var tread_lv := -1
	for raw in grid.tiles_of_block(block):
		var t := int(raw)
		if grid.water[t] != 0:
			continue
		var lv := grid.level_of(t)
		if Grid.is_stair_level(lv):
			tread_lv = maxi(tread_lv, lv)
		else:
			floor_lv = maxi(floor_lv, lv)
	return floor_lv if floor_lv >= 0 else tread_lv


## **How many blocks of `plan` wear a name that disagrees with the board.** A floor 칸's block must
## carry that 칸's 눈금 and exactly the sides the board leaves open; a staircase 칸's block must be a
## staircase. ⚠ **A staircase's DIRECTION is not asked here** — it is chosen a different way and the
## rows that measure it say so.
func _shape_mismatches(grid: Grid, plan: Array) -> int:
	var wrong := 0
	for raw in plan:
		var row: Dictionary = raw
		var block := int(row["block"])
		var one := String(row["name"])
		var storey := _storey_here(grid, block)
		if IslandKit.level_of_name(one) != storey:
			wrong += 1
		elif not Grid.is_stair_level(storey) and _mask_in_name(one) != _open_sides_here(grid, block):
			wrong += 1
	return wrong


## **How many blocks of `plan` stand somewhere other than their own 칸's centre.** The centre is the
## midpoint of the 칸's four 조각, and a 조각 at `(n, m)` has its centre half a 조각 in from there —
## the offset `Grid.coast` is calibrated against.
func _centre_mismatches(grid: Grid, plan: Array) -> int:
	var wrong := 0
	var half := float(Rules.BLOCK_TILES) * 0.5
	for raw in plan:
		var row: Dictionary = raw
		var tiles := grid.tiles_of_block(int(row["block"]))
		if tiles.is_empty():
			wrong += 1
			continue
		var want := grid.tile_point(int(tiles[0])) + Vector2(half, half)
		if (row["centre"] as Vector2) != want:
			wrong += 1
	return wrong


## **Which side of a stair 칸 its low end faces, read off the tier letters alone** — the side whose
## ground is one 눈금 down AND whose OPPOSITE side is the storey up. **The pair is what picks it**: a
## staircase cut into a hillside has lower ground on three sides, and the drawn island's has exactly
## that, so 「the ground is lower here」 on its own names three answers and settles nothing.
##
## ⚠⚠ **DELIBERATELY NOT `Grid.stair_run_of`** — the chooser reads that run, and a net that read it
## too would go green on a staircase drawn climbing one way while the ground rose the other.
## ⚠ **0 when no side or more than one side answers**, so an ambiguous board fails this rather than
## being handed a plausible direction.
func _climb_low_side_by_letters(grid: Grid, block: int) -> int:
	var tiles := grid.tiles_of_block(block)
	if tiles.is_empty():
		return 0
	var here := _storey_here(grid, block)
	var found := 0
	var how_many := 0
	for k in Grid.STAIR_MOUTH_ORDER.size():
		var down := _storey_beside(grid, block, Grid.STAIR_MOUTH_ORDER[k])
		var opposite: Vector2i = -(Grid.STAIR_MOUTH_ORDER[k] as Vector2i)
		if down == here - 1 and _storey_beside(grid, block, opposite) == here + 1:
			found = 1 << k
			how_many += 1
	return found if how_many == 1 else 0


## **The 눈금 of the 칸 one step off `block`**, or -1 off the board and off the land.
func _storey_beside(grid: Grid, block: int, step: Vector2i) -> int:
	var tiles := grid.tiles_of_block(block)
	if tiles.is_empty():
		return -1
	var p := grid.tile_point(int(tiles[0]))
	var nx := int(p.x) + step.x * Rules.BLOCK_TILES
	var ny := int(p.y) + step.y * Rules.BLOCK_TILES
	if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
		return -1
	return _storey_here(grid, grid.block_of(grid.tile_index(nx, ny)))


## **Which side the WALKING RULE says a staircase 칸 is entered from** — `Grid.stair_run_of`'s axis
## points uphill, so the low end faces the other way.
##
## ⚠⚠ **THIS ASKS THE SAME RUN THE CHOOSER ASKS, AND THAT IS THE POINT ON A GENERATED BOARD.** The
## claim it measures is 「the block faces the way the feet climb」, which is the whole contract — the
## table could still be wired to the wrong four names, and the four hand-built boards in
## `_a_stair_is_named_for_the_way_it_climbs` are what catch that, off the letters and nothing else.
##
## ⚠⚠ **IT IS NOT 「the way the ground rises」, AND ON SOME GENERATED BOARDS THOSE DIFFER.** A stair
## two 칸 wide comes back as ONE run four 조각 long, and `Grid` reads its axis ACROSS the climb; the
## measurement is in 티켓 08-01's report for this stage. **Asserting the ground's direction here would
## go red on `Grid`'s reading, not on this file's.**
func _run_low_side(grid: Grid, block: int) -> int:
	for raw in grid.tiles_of_block(block):
		var run: Array = grid.stair_run_of(int(raw))
		if run.is_empty():
			continue
		var low: Vector2i = -(run[0] as Vector2i)
		for k in Grid.STAIR_MOUTH_ORDER.size():
			if Grid.STAIR_MOUTH_ORDER[k] == low:
				return 1 << k
	return 0


## **Which side a staircase block's LOW end faces**, found by asking the kit's own table which
## direction that name answers. ⚠ **0 when the name is not a staircase at all.**
func _low_side_of_name(block_name: String) -> int:
	for side in [IslandKit.SIDE_WEST, IslandKit.SIDE_EAST, IslandKit.SIDE_NORTH, IslandKit.SIDE_SOUTH]:
		if IslandKit.stair_for_low_side(int(side)) == block_name:
			return int(side)
	return 0


## **The mask a block's name stands for**, found by asking the kit's own table which shape that name
## answers. ⚠ **-1 when the table does not hold the name at all**, so a made-up name fails rather
## than reading as the mask 0.
func _mask_in_name(block_name: String) -> int:
	for level in [0, 2]:
		for mask in 16:
			for one in IslandKit.blocks_for(int(level), mask):
				if String(one) == block_name:
					return mask
	return -1


## **Every name the kit's table holds**, stairs included.
func _table_names() -> PackedStringArray:
	var out := PackedStringArray()
	for level in [0, 2]:
		for mask in 16:
			for one in IslandKit.blocks_for(int(level), mask):
				out.append(String(one))
	for side in [IslandKit.SIDE_WEST, IslandKit.SIDE_EAST, IslandKit.SIDE_NORTH, IslandKit.SIDE_SOUTH]:
		out.append(IslandKit.stair_for_low_side(int(side)))
	return out


## **Where a block's own side stands, in the mesh's units.** Every block spans ±1.0 and a coastal
## skirt reaches ±1.25, so a vertex at or past this belongs to that side.
const SIDE_EDGE := 0.97
## **The band between a block's underside and the top of a 2층** — −0.12 and 1.21 are what the meshes
## measure, and this window sits inside both. ⚠ **Vertices in it are what tell a carved face from a
## flat seam**: a plain wall between two 칸 has only its top and bottom rims.
const CARVED_LOW := 0.0
const CARVED_HIGH := 1.1

## **The four sides in `Grid.STAIR_MOUTH_ORDER`'s order, as tests on a mesh vertex.** ⚠ **`x` is the
## board's x and `z` is the board's y**, which is the frame `field_view` already stands everything in.
func _side_tests() -> Array:
	return [
		func(p: Vector3) -> bool: return p.x <= -SIDE_EDGE,
		func(p: Vector3) -> bool: return p.x >= SIDE_EDGE,
		func(p: Vector3) -> bool: return p.z <= -SIDE_EDGE,
		func(p: Vector3) -> bool: return p.z >= SIDE_EDGE,
	]


## **How many vertices each side of one block carries inside the carved band**, four numbers in side
## order, or empty when the kit has no such block.
func _side_detail_of(lib: Node, block_name: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var verts := _verts_of(lib, block_name)
	if verts.is_empty():
		return out
	for test in _side_tests():
		var n := 0
		for p in verts:
			if test.call(p) and p.y > CARVED_LOW and p.y < CARVED_HIGH:
				n += 1
		out.append(n)
	return out


## **How high one block's ground reaches at each of its four sides**, in side order. ⚠ **A staircase's
## LOW end is simply its lowest of these four** — no tread has to be counted to see which way it falls.
func _side_tops_of(lib: Node, block_name: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var verts := _verts_of(lib, block_name)
	if verts.is_empty():
		return out
	for test in _side_tests():
		var top := -1e9
		for p in verts:
			if test.call(p):
				top = maxf(top, p.y)
		out.append(top)
	return out


## Every vertex of one block of the kit, or empty when it is not there.
func _verts_of(lib: Node, block_name: String) -> PackedVector3Array:
	var mi := lib.find_child(block_name, true, false) as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array


## **The kit, instantiated.** ⚠ **The caller frees it** — it is never added to the tree, and this net
## opens no other file.
func _kit_root() -> Node:
	var packed := load(IslandKit.KIT_PATH) as PackedScene
	return packed.instantiate() if packed != null else null


## **Every node name inside `pieces.glb`**, as a set.
func _kit_names() -> Dictionary:
	var out := {}
	var root := _kit_root()
	if root == null:
		return out
	_gather_names(root, out)
	root.free()
	return out


func _gather_names(node: Node, into: Dictionary) -> void:
	into[String(node.name)] = true
	for child in node.get_children():
		_gather_names(child, into)
