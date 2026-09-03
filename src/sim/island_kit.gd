class_name IslandKit
extends RefCounted
## **Which block of the kit stands on each 칸 of a board, and where it stands.** Ticket 08-01, the
## first stage of standing a generated island: a board in, one block name and one place per 칸 out.
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE AND NOTHING HERE OPENS A FILE.** It answers with the NAME of a
## block; loading `pieces.glb` and standing the mesh is the view's half. That is what lets a net drive
## hundreds of generated boards through this with `.new()` in seconds, which is the `src/sim/` seam
## `GLOSSARY.md` names.
##
## **THE WHOLE RULE IS ONE SENTENCE: a side of a 칸 is OPEN when the 칸 beyond it is a whole storey or
## more below, or is not land, or is off the board.** Which of the four sides are open, together with
## the 칸's 눈금, names exactly one block — sixteen masks over two storeys, and **all thirty-two were
## baked in Blender so the game looks a name up and turns nothing at run time.** The deleted bake
## stamped rotated blocks instead and the coast ring opened in six places; the risk is spent in
## Blender rather than carried into the frame.
##
## ⚠⚠ **「A WHOLE STOREY OR MORE BELOW」 AND NOT MERELY 「LOWER」, AND THE DIFFERENCE IS THE STAIRCASE.**
## A stair 칸 stands one 눈금 above the ground it comes off and one 눈금 below the plateau it enters,
## and **the kit holds no half-storey cliff** — every open level-2 side drops the full 1.0 from 1.21
## to 0.21. So a 칸 next to a staircase must be CLOSED on that side, or a sculpted cliff face would
## stand across the only door up, and the coast skirt of an open level-0 block would push into the
## treads. **The threshold is `Rules.MAX_CLIMB_LEVELS`**, which is the same statement seen from the
## walking side: the cliff is drawn exactly where a body may not step down.
##
## ⚠⚠ **A STAIR IS NOT CHOSEN THAT WAY AT ALL.** It is chosen by the direction it CLIMBS, and that
## direction is read out of `Grid.stair_run_of` rather than worked out here. **The two orders that
## pick a stair's mouth disagree the moment two of its neighbours are raised** — 티켓 08-01 carries
## the measurement, and the symptom is a staircase drawn climbing one way while the feet climb
## another. A second opinion in this file is that defect, made fresh every run.
##
## ⚠ **A block carries its own storey and is never lifted.** Measured off `pieces.glb`: a level-0
## block spans −0.12..0.21 and a level-2 block −0.12..1.21, and `Islands.ground_h` answers 0.21 and
## 1.21 for those two levels. **So every block stands at ground zero** and the two height numbers of
## the board never enter this file — which is why there is no height in what `plan` answers.
##
## ⚠ **A staircase longer than one 칸 is not handled and cannot be.** Each stair block climbs a whole
## storey by itself, so two of them in a line would climb two. The drawn island's staircase is one 칸
## and `IslandGen` picks a single 칸 for each of its doors; **the day a stair is drawn two 칸 long,
## this file will place two full climbs and the mesh is what has to change.**


## **The file the names below live in.** ⚠ **This file never opens it.** It is written here because
## the names are, so whatever stands the meshes and whatever checks the names ask one place for both.
const KIT_PATH := "res://assets/terrain/pieces.glb"

## **The bit each side of a 칸 sets in its open-sides mask.**
##
## ⚠⚠ **THE INDEX IS `Grid.STAIR_MOUTH_ORDER`'s AND THE BIT IS `1 <<` IT** — west, east, north, south.
## The four directions have exactly one owner and it is `Grid`; these names are a reading of that list,
## never a second copy of it, and **`net_island_kit` asserts the list has not moved under them.**
## Reorder it with these left alone and every block in the kit turns 90 degrees in silence.
const SIDE_WEST := 1 << 0
const SIDE_EAST := 1 << 1
const SIDE_NORTH := 1 << 2
const SIDE_SOUTH := 1 << 3

## **What a 칸 that is not land at all answers.** ⚠ **A real state and not an error**: most of any
## board is sea, and `plan` simply places nothing there.
const NOT_LAND := -1

## **THE TABLE — which block covers which open-sides mask.** Every row is `[mask, name]`.
##
## ⚠⚠ **A ROW SAYS THE MASK AND NOTHING ELSE.** The 눈금 and the kind are already spelled inside
## `KIT_<level>_<kind>_<n>`, so a column for either would be the same fact written twice, and the two
## copies would drift on the first re-bake. `_lookup` reads them back out of the name.
##
## ⚠ **Several names against one mask are one shape jittered differently.** Which one a 칸 wears is
## `_variant_index`, off the 칸's own place on the board — never off a random number, or the same seed
## would stop giving the same island.
const BLOCKS := [
	[0, "KIT_0_solid_4"],
	[0, "KIT_0_solid_19"],
	[0, "KIT_0_solid_25"],
	[SIDE_WEST, "KIT_0_edge_3"],
	[SIDE_EAST, "KIT_0_edge_8"],
	[SIDE_NORTH, "KIT_0_edge_1"],
	[SIDE_SOUTH, "KIT_0_edge_18"],
	[SIDE_SOUTH, "KIT_0_edge_20"],
	[SIDE_SOUTH, "KIT_0_edge_21"],
	[SIDE_WEST | SIDE_EAST, "KIT_0_strait_23"],
	[SIDE_NORTH | SIDE_SOUTH, "KIT_0_strait_26"],
	[SIDE_NORTH | SIDE_SOUTH, "KIT_0_strait_27"],
	[SIDE_WEST | SIDE_NORTH, "KIT_0_corner_0"],
	[SIDE_EAST | SIDE_NORTH, "KIT_0_corner_2"],
	[SIDE_WEST | SIDE_SOUTH, "KIT_0_corner_17"],
	[SIDE_EAST | SIDE_SOUTH, "KIT_0_corner_22"],
	[SIDE_WEST | SIDE_NORTH | SIDE_SOUTH, "KIT_0_cape_24"],
	[SIDE_EAST | SIDE_NORTH | SIDE_SOUTH, "KIT_0_cape_28"],
	[SIDE_WEST | SIDE_EAST | SIDE_SOUTH, "KIT_0_cape_29"],
	[SIDE_WEST | SIDE_EAST | SIDE_NORTH, "KIT_0_cape_32"],
	[SIDE_WEST | SIDE_EAST | SIDE_NORTH | SIDE_SOUTH, "KIT_0_islet_30"],

	[0, "KIT_2_solid_10"],
	[SIDE_WEST, "KIT_2_edge_9"],
	[SIDE_EAST, "KIT_2_edge_11"],
	[SIDE_NORTH, "KIT_2_edge_6"],
	[SIDE_SOUTH, "KIT_2_edge_33"],
	[SIDE_WEST | SIDE_EAST, "KIT_2_strait_15"],
	[SIDE_NORTH | SIDE_SOUTH, "KIT_2_strait_34"],
	[SIDE_WEST | SIDE_NORTH, "KIT_2_corner_5"],
	[SIDE_EAST | SIDE_NORTH, "KIT_2_corner_7"],
	[SIDE_WEST | SIDE_SOUTH, "KIT_2_corner_13"],
	[SIDE_EAST | SIDE_SOUTH, "KIT_2_corner_14"],
	[SIDE_WEST | SIDE_EAST | SIDE_SOUTH, "KIT_2_cape_16"],
	[SIDE_EAST | SIDE_NORTH | SIDE_SOUTH, "KIT_2_cape_35"],
	[SIDE_WEST | SIDE_EAST | SIDE_NORTH, "KIT_2_cape_36"],
	[SIDE_WEST | SIDE_NORTH | SIDE_SOUTH, "KIT_2_cape_37"],
	[SIDE_WEST | SIDE_EAST | SIDE_NORTH | SIDE_SOUTH, "KIT_2_islet_12"],
]

## **THE STAIRS — which block climbs which way.** Every row is `[the side the LOW end faces, name]`.
##
## ⚠ **The low end and not the climb**, because that is the half a caller can point at: the 칸 the
## body walks in from. The mesh was cut the same way round — `KIT_1_stair_31`'s treads reach 0.39 at
## its west edge and 1.21 at its east one.
const STAIRS := [
	[SIDE_WEST, "KIT_1_stair_31"],
	[SIDE_EAST, "KIT_1_stair_39"],
	[SIDE_NORTH, "KIT_1_stair_40"],
	[SIDE_SOUTH, "KIT_1_stair_38"],
]

## The two tables above, turned into the lookups `plan` asks. **Built once on the first ask** — the
## tables are constants, so the answer cannot change, and rebuilding it per board would be a walk of
## forty-one names per island.
static var _by_shape := {}
static var _by_low_side := {}
static var _built := false


## **Which block stands on each land 칸 of `grid`, and where.** One `Dictionary` per placed 칸,
## ascending by 칸:
##
##   `name`   — the node to clone out of `KIT_PATH`
##   `block`  — the 칸, in `Grid.block_of`'s own numbering
##   `centre` — where the block's origin stands, in 조각 units. **A 조각 at `(n, m)` has its centre
##              half a 조각 in from there**, the same offset `Grid.coast` is calibrated against, so a
##              칸's centre lands on a whole number.
##
## **There is no height**, and that is the answer rather than an omission — see the note at the head
## of this file about a block carrying its own storey.
##
## ⚠⚠ **A 칸 THE TABLE HAS NO BLOCK FOR GETS NOTHING AND BARKS.** A plausible substitute would put the
## wrong cliff on an island nobody would think to check; a hole in the ground with nothing said is
## worse. **The bark is what the runner turns red on**, and `net_island_kit` is what proves it never
## fires on a board the generator can make.
static func plan(grid: Grid) -> Array:
	_lookup()
	var out: Array = []
	var half := float(Rules.BLOCK_TILES) * 0.5
	for block in _blocks_of(grid):
		var level := level_of_block(grid, block)
		if level == NOT_LAND:
			continue
		var tiles := grid.tiles_of_block(block)
		var low := int(tiles[0])
		var block_name := ""
		if Grid.is_stair_level(level):
			block_name = stair_for_low_side(_stair_low_side(grid, tiles))
		else:
			var choices := blocks_for(level, _open_sides(grid, block, level))
			if not choices.is_empty():
				block_name = String(choices[_variant_index(grid, low, choices.size())])
		if block_name == "":
			push_error("island kit has no block for 칸 %d at 눈금 %d" % [block, level])
			continue
		out.append({
			"name": block_name,
			"block": block,
			"centre": grid.tile_point(low) + Vector2(half, half),
		})
	return out


## **Every block the kit offers for one 눈금 and one open-sides mask**, in table order. **Empty is a
## real answer** — see `plan` for what is done with it.
static func blocks_for(level: int, open_sides: int) -> PackedStringArray:
	_lookup()
	return _by_shape.get(Vector2i(level, open_sides), PackedStringArray())


## **The staircase whose LOW end faces `side`**, or `""` when there is none.
static func stair_for_low_side(side: int) -> String:
	_lookup()
	return str(_by_low_side.get(side, ""))


## **The 눈금 a block's own name says it stands at** — `KIT_<level>_<kind>_<n>` — or `NOT_LAND` for
## anything that is not a kit name.
##
## ⚠ **The name is the ONLY place a block's 눈금 and kind are written**, which is why this exists
## rather than a column beside every row of `BLOCKS`.
static func level_of_name(block_name: String) -> int:
	var parts := block_name.split("_")
	if parts.size() < 3 or String(parts[0]) != "KIT" or not String(parts[1]).is_valid_int():
		return NOT_LAND
	return int(parts[1])


## **The 눈금 a 칸 stands at, or `NOT_LAND` when it is not land.**
##
## 「높이는 덮는 조각 넷 중 짝수 눈금의 최대다」 — an odd 눈금 is a stair tread and never sets a 칸's
## floor. ⚠ **A 칸 whose dry 조각 are ALL treads is the staircase itself** and answers the odd 눈금 it
## carries, so a caller tells the two apart with `Grid.is_stair_level` and no second word is needed.
##
## ⚠ **LAND IS DRY, NOT WALKABLE.** A 자원 칸 is impassable and dry and it is still island — the same
## reading `net_island_gen` measures the 성채's depth with. Read it as 「walkable」 and every resource
## 칸 on every generated island becomes a hole in the ground.
static func level_of_block(grid: Grid, block: int) -> int:
	var floor_level := NOT_LAND
	var tread_level := NOT_LAND
	for raw in grid.tiles_of_block(block):
		var tile := int(raw)
		if grid.water[tile] != 0:
			continue
		var level := grid.level_of(tile)
		if Grid.is_stair_level(level):
			tread_level = maxi(tread_level, level)
		else:
			floor_level = maxi(floor_level, level)
	return floor_level if floor_level != NOT_LAND else tread_level


## **Which sides of a 칸 are open**, as a mask of `SIDE_*`. See the head of this file for the rule.
##
## ⚠ **The step is one whole 칸 in 조각 units and then `Grid.block_of` names what it landed in.** The
## step size has to be `Rules.BLOCK_TILES` exactly — a shorter one lands back inside this same 칸 —
## but **which 칸 that is remains `Grid`'s answer and not this file's arithmetic**, which is what
## keeps a second notion of 「which 칸 is this」 out of the repo.
static func _open_sides(grid: Grid, block: int, level: int) -> int:
	var tiles := grid.tiles_of_block(block)
	if tiles.is_empty():
		return 0
	var p := grid.tile_point(int(tiles[0]))
	var mask := 0
	for k in Grid.STAIR_MOUTH_ORDER.size():
		var step: Vector2i = Grid.STAIR_MOUTH_ORDER[k]
		var nx := int(p.x) + step.x * Rules.BLOCK_TILES
		var ny := int(p.y) + step.y * Rules.BLOCK_TILES
		var beyond := NOT_LAND
		if nx >= 0 and ny >= 0 and nx < grid.w and ny < grid.h:
			beyond = level_of_block(grid, grid.block_of(grid.tile_index(nx, ny)))
		# ⚠ **The two tests are separate on purpose.** `NOT_LAND` is -1, so a sea 칸 folded into the
		# height comparison would read as one 눈금 below the ground and CLOSE the side — the whole
		# coastline would lose its cliffs and its skirts with nothing said.
		if beyond == NOT_LAND or level - beyond > Rules.MAX_CLIMB_LEVELS:
			mask |= 1 << k
	return mask


## **Which side of a staircase 칸 its LOW end faces**, read out of `Grid.stair_run_of` — see the head
## of this file for why it is read and not worked out. The run's axis points UPHILL, so the low end
## faces the other way.
## ⚠ **0 when `Grid` refused the staircase**, which is a stair no body can climb; `plan` turns that
## into a bark rather than standing a block that faces nowhere.
static func _stair_low_side(grid: Grid, tiles: PackedInt32Array) -> int:
	for raw in tiles:
		var run: Array = grid.stair_run_of(int(raw))
		if run.is_empty():
			continue
		var uphill: Vector2i = run[0]
		var low := Vector2i(-uphill.x, -uphill.y)
		for k in Grid.STAIR_MOUTH_ORDER.size():
			if Grid.STAIR_MOUTH_ORDER[k] == low:
				return 1 << k
	return 0


## **Which of several jittered copies of one shape a 칸 wears.**
##
## ⚠⚠ **OFF THE 칸's OWN PLACE AND NEVER OFF A RANDOM NUMBER**, or the same seed would stop giving the
## same island — which is the one promise that lets an island that looked wrong be brought back.
## ⚠ **The 조각 coordinates are halved to 칸 first.** A 칸's low 조각 is always at an EVEN coordinate,
## so a mask taken off the 조각 numbers collapses to one variant everywhere the count is two.
## ⚠ **5 and 7 are coprime to both 2 and 3**, the only counts the table uses, so neither multiplier
## drops out and the copies do not lay themselves out in stripes.
static func _variant_index(grid: Grid, low_tile: int, count: int) -> int:
	if count <= 1:
		return 0
	var p := grid.tile_point(low_tile)
	var bx := int(p.x) / Rules.BLOCK_TILES
	var by := int(p.y) / Rules.BLOCK_TILES
	return (bx * 5 + by * 7) % count


## **Every 칸 of `grid`, ascending, each named once.** ⚠ **Walked as 조각 and asked `Grid.block_of`**,
## because `Grid` publishes no 칸 count and inventing one here would be exactly the second decode this
## file exists without.
static func _blocks_of(grid: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for tile in grid.w * grid.h:
		var block := grid.block_of(tile)
		if block < 0 or seen.has(block):
			continue
		seen[block] = true
		out.append(block)
	return out


## The two tables read into the lookups, once.
static func _lookup() -> void:
	if _built:
		return
	_built = true
	for raw in BLOCKS:
		var row: Array = raw
		var block_name := String(row[1])
		var key := Vector2i(level_of_name(block_name), int(row[0]))
		var names: PackedStringArray = _by_shape.get(key, PackedStringArray())
		names.append(block_name)
		_by_shape[key] = names
	for raw in STAIRS:
		var row: Array = raw
		_by_low_side[int(row[0])] = String(row[1])
