extends RefCounted
## **Height: the tier board, the stair rule, and the one island that has been given a plateau.**
## 티켓 19, first slice.
##
## The claim under test is one sentence: **a body may cross a level gap of at most
## `Rules.MAX_CLIMB_LEVELS`, so a tier boundary is a wall and a stair is the only door.** Everything
## below is either that sentence measured, or the island where it is supposed to be felt.
##
## ⚠⚠ **EVERY LITERAL HERE WAS DERIVED OUTSIDE GODOT** from a from-scratch re-implementation of
## `grid.gd`'s BFS, `_water_step_open`, the sendable fill and `step_toward`'s descent, before being
## typed in — the same discipline `net_coast` and `net_islands` state at the top of themselves. A
## hand-picked coordinate on a flood fill is exactly the thing that looks right and is not.
##
## ⚠ **THE CONTROLS ARE THE POINT, NOT DECORATION.** "The wolf cannot get up there" is true of a map
## with no route at all, so every claim about the climb rule is made TWICE on the same fixture — once
## with the tier board and once with `load_rows(rows)` and nothing else. The pair is what separates
## *the height refused it* from *the shape of the map refused it*, and this repo has a written case
## where a pack-hunting check passed on a board with one enemy on it because any point gave the same
## answer.
##
## ⚠⚠ **AND THE INSTRUMENT IS INVERTED TOO.** `_unreachable_pairs` is the check that is supposed to
## stop an island where an enemy on a plateau can never be reached — a fight that never ends, on a
## board with no time limit left in it, with every net still green. A helper that always returns 0
## would pass that duty silently, so it is run on a fixture built to FAIL it. See
## `_the_reach_check_can_actually_fail`.
##
## ⚠⚠ **WHAT THIS FILE MISSED THE FIRST TIME, WRITTEN DOWN BECAUSE THE SHAPE WILL RECUR.** Every row
## below the rule section measured a PIECE — the field extends, one `step_toward` call turns away, HP
## does not cross a wall — and **not one of them ran the real walker at a boundary a body is meant to
## cross.** So a build in which every body froze solid at every tier boundary passed 3177 checks: the
## reachability row saw a field with values in it, the walking rows drove the grid instead of the
## fight, and 「the enemy on the wall is never hit」 was satisfied just as well by a frozen wolf.
## ⇒ **`_a_wolf_climbs_the_stair_and_kills_what_is_up_there` is the row that closes it**, and the rule
## it came from is: *when a check says a thing cannot happen, there must be a neighbouring check that
## the thing DOES happen where it should.*
##
## **What this slice still does NOT contain**: the other seven islands. `Islands.tiers_of` answers `[]`
## for all seven and `[]` means flat.


## The fixture every rule row is measured on. Land is x 1..7, y 1..4; the plateau is x 5..7 and the
## single stair is (4,3), which is one tile of level 1 in an otherwise two-level board.
const FIXTURE_ROWS := [
	"~~~~~~~~~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~~~~~~~~~",
]
const FIXTURE_TIERS := [
	".........",
	".....111.",
	".....111.",
	"..../111.",
	".....111.",
	".........",
]
const FIXTURE_W := 9

## The same board with the door bricked up — the stair character replaced by low ground. **Not
## generated from the one above by string surgery**: a mutation written as a replacement has silently
## matched zero times in this repo twice, and a fixture that quietly stayed identical would make the
## sharpest row here green for no reason.
const FIXTURE_TIERS_NO_STAIR := [
	".........",
	".....111.",
	".....111.",
	".....111.",
	".....111.",
	".........",
]

## Hand-counted off the board above: 3 columns x 4 rows of plateau, one stair, and the 16 land tiles
## minus the stair.
const FIXTURE_HIGH := 12
const FIXTURE_STAIR := 1
const FIXTURE_LOW := 15
## ⚠ **Sixteen, not fifteen, and the difference is the point.** Bricking the door up does not delete a
## tile — the stair BECOMES low ground. Land is 7 x 4 = 28 either way: 12 + 1 + 15 with the door, and
## 12 + 16 without it.
const FIXTURE_LOW_NO_STAIR := 16

## The board `_the_reach_check_can_actually_fail` runs the reachability helper on: an INLAND plateau
## with no stair and one defender on top of it. The plateau is inland so that no landing tile is on it
## — otherwise a boat parked on the plateau reaches that defender and the failure is only partial,
## which is a weaker bite than the one this fixture exists to prove.
const SEALED_ROWS := [
	"~~~~~~~~~~~",
	"~.........~",
	"~.........~",
	"~.........~",
	"~....S....~",
	"~.........~",
	"~.........~",
	"~~~~H~~~~~~",
]
const SEALED_TIERS := [
	"...........",
	"...........",
	"...........",
	"....111....",
	"....111....",
	"....111....",
	"...........",
	"...........",
]
## 9 x 6 of land, so the 8-way coast is its perimeter: 2 x (9 + 6) - 4 = 26.
const SEALED_LANDINGS := 26

## The island `Rules.MAP_NODES[0]` opens — the first fight of every run, and the only island with a
## tier board today.
const FIRST_ISLAND := 4

## Island 4, **re-derived by hand when the island stopped being generated** (2026-08-25). The rows used
## to come out of `_small_rows` — a rectangle of land — and they are typed out in `ISLAND_4_ROWS` now,
## with a bay cutting the south shore. **Every figure below is a fact about that drawing**, and each was
## worked out from the letters before the nets were run, not read back off a red row:
##
##  · **15 plateau tiles.** The plateau is 4 x 4 at x 18-21, y 3-6, and one of its sixteen tiles is the
##    stair. It is smaller than the 62 it replaces because a slab that size cannot sit on this coast
##    without touching water, and `_the_first_island_carries_a_real_plateau` refuses that.
##  · **68 landing tiles**, up from 54. Land went 180 tiles to 165, but a bay is nearly all shore: of
##    the 165, only 97 have land on all eight sides. **A rectangle has the least coast a given area
##    can have** — that is the same fact as 「휑하다」, counted.
##    ⚠ It was 72 for one draft, and **that draft's coast was thrown away for looking like a comb**
##    (see `ISLAND_4_ROWS`): stepping the shore back a column per row buys coast tiles by hanging a
##    separate wall off every one of them.
##  · **6 defenders, 3 up top** — unchanged, and the letters were placed to keep it so.
const ISLAND_HIGH := 15
const ISLAND_STAIR := 1
const ISLAND_LANDINGS := 68
const ISLAND_ENEMIES := 6
const ISLAND_ENEMIES_HIGH := 3

const WALKER_ID := 777_001


func run(t) -> void:
	_an_empty_tier_board_is_flat(t)
	_a_short_tier_board_is_flat_where_it_ends(t)
	_the_climb_rule_itself(t)
	_the_field_climbs_only_by_the_stair(t)
	_bricking_up_the_stair_seals_the_plateau(t)
	_a_walker_refuses_the_wall_and_takes_the_stair(t)
	_distance_carries_the_height(t)
	_a_wolf_cannot_bite_across_a_tier_and_a_crow_can(t)
	_a_swing_does_not_sweep_over_the_wall(t)
	_a_wolf_climbs_the_stair_and_kills_what_is_up_there(t)
	_melee_reaches_a_diagonal_one_level_up(t)
	_an_enemy_posted_high_holds_its_tier(t)
	_a_pack_aims_from_where_its_bodies_stand(t)
	_a_shove_never_changes_a_bodys_tier(t)
	_a_landing_never_puts_a_body_on_the_plateau(t)
	_the_first_island_carries_a_real_plateau(t)
	_every_landing_reaches_every_enemy_on_the_first_island(t)
	_the_reach_check_can_actually_fail(t)
	_no_tier_board_is_a_different_shape_from_its_island(t)
	_an_island_number_is_loaded_through_one_door(t)


# == the datum ========================================================================================

## ⚠⚠ **THE REGRESSION GUARD FOR THE WHOLE REPO, AND IT IS ONE LINE OF CODE.** Every fixture in every
## other net calls `load_rows(rows)` with no second argument. If the default meant anything but flat,
## all of them would quietly start measuring a climb rule as well as their own subject — which is how
## a suite comes to be green about something nobody wrote.
func _an_empty_tier_board_is_flat(t) -> void:
	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS)
	t.eq(g.level.size(), g.w * g.h, "단 배열은 격자와 같은 크기다")
	var raised := 0
	for tile in g.level.size():
		if g.level[tile] != 0:
			raised += 1
	t.eq(raised, 0, "단 판을 안 넘기면 섬 전체가 0단이다 — 기존 픽스처 전부가 평지로 남는 자리")
	t.ok(g.can_step(g.tile_index(4, 1), g.tile_index(5, 1)),
		"그리고 평지에서는 can_step 이 passable 그대로다")


## A board shorter than the island — fewer rows, or a short row inside it — reads as level 0 where it
## runs out, the same silence the terrain loop keeps for a short row. **Measured rather than assumed**:
## a board that ran off the end reading garbage would put a stair somewhere nobody authored one.
func _a_short_tier_board_is_flat_where_it_ends(t) -> void:
	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, ["..1"])
	t.eq(g.level_at(2, 0), 2, "짧은 단 판도 적힌 자리는 읽힌다 (자가 점검)")
	t.eq(g.level_at(5, 0), 0, "줄이 끝난 뒤는 0단이다")
	t.eq(g.level_at(5, 3), 0, "판이 끝난 뒤의 행도 전부 0단이다")


# == the rule =========================================================================================

## `can_step` on its own, on all four pairs the two-tier board can make. **Read the numbers, not the
## names**: `MAX_CLIMB_LEVELS` is what decides, and a stair is level 1 only because a tier is two.
func _the_climb_rule_itself(t) -> void:
	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, FIXTURE_TIERS)
	var low := g.tile_index(3, 1)      # level 0
	var low2 := g.tile_index(2, 1)     # level 0
	var high := g.tile_index(5, 1)     # level 2
	var high2 := g.tile_index(6, 1)    # level 2
	var stair := g.tile_index(4, 3)    # level 1
	var low_by_stair := g.tile_index(3, 3)
	var high_by_stair := g.tile_index(5, 3)
	var sea := g.tile_index(0, 0)

	t.eq(g.level_of(low), 0, "낮은 땅은 0단이다 (자가 점검)")
	t.eq(g.level_of(stair), 1, "계단은 1단이다 (자가 점검)")
	t.eq(g.level_of(high), 2, "높은 땅은 2단이다 (자가 점검)")

	t.ok(g.can_step(low, low2), "같은 층끼리는 걸을 수 있다")
	t.ok(g.can_step(high, high2), "높은 층끼리도 걸을 수 있다")
	t.ok(not g.can_step(g.tile_index(4, 1), high), "층 경계는 못 넘는다 — 단이 2 벌어져 있다")
	t.ok(not g.can_step(high, g.tile_index(4, 1)), "반대 방향으로도 못 넘는다 — 밀려서 떨어지는 문이 아니다")
	t.ok(g.can_step(low_by_stair, stair), "계단은 아래에서 오른다")
	t.ok(g.can_step(stair, high_by_stair), "그리고 계단에서 위층으로 이어진다")
	t.ok(g.can_step(high_by_stair, stair), "계단은 위에서 내려오기도 한다")

	# ⚠ The DIAGONAL. `_water_step_open` refuses a boat a squeeze between two land corners and the land
	# half has never carried that rule — but the level gap binds on all eight neighbours, so a wall
	# cannot be cut at its corner either. Without this row a plateau leaks at every corner tile.
	t.ok(not g.can_step(g.tile_index(4, 2), g.tile_index(5, 1)),
		"대각선으로도 층 경계를 못 넘는다 — 벽은 모서리에서도 벽이다")
	t.ok(g.can_step(g.tile_index(3, 2), stair), "계단으로는 대각선으로도 들어간다")

	t.ok(not g.can_step(low, sea), "물은 여전히 못 걷는다 — passable 이 먼저다")
	t.ok(not g.can_step(low, -1), "격자 밖은 거절이다")


# == the field ========================================================================================

## **The flow field is where "walk to the stair" has to come out**, and the pair of measurements is
## what makes it a claim about height. The high tile (5,1) sits one tile east of the low tile (4,1):
##
##   · flat board — cost(5,1) is exactly cost(4,1) + 1. It walked straight over
##   · tier board — cost(5,1) is 5 against cost(4,1) of 3, so it did NOT walk straight over, and the
##     cheapest tile on the whole plateau costs exactly one more than the stair does
##
## **Mutation**: make `can_step` return `passable[to_tile] != 0` and the tiered numbers collapse onto
## the flat ones.
func _the_field_climbs_only_by_the_stair(t) -> void:
	var flat := Grid.new()
	flat.load_rows(FIXTURE_ROWS)
	var seed := flat.tile_index(1, 1)
	var ff := flat.flow_field(seed)
	t.eq(int(ff[flat.tile_index(4, 1)]), 3, "평지 대조군 — (4,1) 은 세 걸음이다")
	t.eq(int(ff[flat.tile_index(5, 1)]), 4, "평지 대조군 — 그 옆 (5,1) 은 벽을 넘어 네 걸음이다")

	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, FIXTURE_TIERS)
	var tf := g.flow_field(g.tile_index(1, 1))
	t.eq(int(tf[g.tile_index(4, 1)]), 3, "층이 있어도 낮은 땅 (4,1) 은 그대로 세 걸음이다")
	t.eq(int(tf[g.tile_index(5, 1)]), 5,
		"그런데 벽 너머 (5,1) 은 다섯 걸음이다 — 옆으로 한 걸음이 아니라 계단을 돌아온 값이다")

	var stair_cost := int(tf[g.tile_index(4, 3)])
	t.eq(stair_cost, 3, "계단까지는 세 걸음이다")
	var cheapest_high := Grid.UNREACHABLE
	var high_count := 0
	var unreached_high := 0
	for tile in g.level.size():
		if g.level_of(tile) != 2:
			continue
		high_count += 1
		if int(tf[tile]) == Grid.UNREACHABLE:
			unreached_high += 1
		else:
			cheapest_high = mini(cheapest_high, int(tf[tile]))
	t.eq(high_count, FIXTURE_HIGH, "고원은 열두 칸이다 (자가 점검)")
	t.eq(unreached_high, 0, "계단이 있으면 고원 열두 칸이 전부 닿는다")
	t.eq(cheapest_high, stair_cost + 1,
		"그리고 고원에서 제일 싼 칸이 계단보다 정확히 한 걸음 비싸다 — 문이 하나라는 것의 값")


## **The sharpest row in the file.** Take the one stair away and the plateau is not merely expensive,
## it is `UNREACHABLE` — while every low tile stays exactly as reachable as it was. A board that broke
## outright would redden the second half, so the two counts are read together.
func _bricking_up_the_stair_seals_the_plateau(t) -> void:
	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, FIXTURE_TIERS_NO_STAIR)
	var stairs := 0
	for tile in g.level.size():
		if g.level_of(tile) == 1:
			stairs += 1
	t.eq(stairs, 0, "문을 막은 판에는 계단이 하나도 없다 (자가 점검)")

	var f := g.flow_field(g.tile_index(1, 1))
	var high_unreached := 0
	var high_seen := 0
	var low_unreached := 0
	var low_seen := 0
	for tile in g.level.size():
		if g.passable[tile] == 0:
			continue
		if g.level_of(tile) == 2:
			high_seen += 1
			if int(f[tile]) == Grid.UNREACHABLE:
				high_unreached += 1
		else:
			low_seen += 1
			if int(f[tile]) == Grid.UNREACHABLE:
				low_unreached += 1
	t.eq(high_seen, FIXTURE_HIGH, "고원 열두 칸을 셌다 (자가 점검)")
	t.eq(high_unreached, FIXTURE_HIGH, "계단이 없으면 고원 열두 칸이 전부 UNREACHABLE 이다")
	t.eq(low_seen, FIXTURE_LOW_NO_STAIR, "낮은 땅은 열여섯 칸이다 — 계단이 낮은 땅이 됐다 (자가 점검)")
	t.eq(low_unreached, 0, "그리고 낮은 땅은 한 칸도 안 잃었다 — 판이 통째로 망가진 게 아니다")
	t.eq(high_seen + low_seen, FIXTURE_HIGH + FIXTURE_STAIR + FIXTURE_LOW,
		"두 판의 걸을 수 있는 칸 수가 같다 — 문을 막았다고 땅이 사라지지 않았다 (자가 점검)")


## `step_toward` is asked the same question as the field, one step at a time, and it is asked with a
## CONTROL: the same tile, the same target, the same field-building code — one board flat and one
## tiered. **The flat walker steps east onto (5,1); the tiered one turns away to (3,2).** Then the
## whole walk is run and the stair is asserted to be on the path, which is what "the wolf goes round"
## looks like from the sim's side.
##
## **Mutation**: drop `can_step` out of `step_toward` and the tiered walker steps east like the flat
## one, because the field it descends still knows the way round.
func _a_walker_refuses_the_wall_and_takes_the_stair(t) -> void:
	var flat := Grid.new()
	flat.load_rows(FIXTURE_ROWS)
	var flat_field := flat.flow_field(flat.tile_index(7, 1))
	var flat_step := flat.step_toward(WALKER_ID, Vector2(4, 1), flat_field)
	t.eq(flat_step, Vector2(5, 1),
		"평지 대조군 — 벽이 없으면 (4,1) 에 선 몸은 동쪽 (5,1) 로 곧장 간다")
	flat.release_all(WALKER_ID)

	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, FIXTURE_TIERS)
	var field := g.flow_field(g.tile_index(7, 1))
	var step := g.step_toward(WALKER_ID, Vector2(4, 1), field)
	t.eq(step, Vector2(3, 2),
		"층이 있으면 같은 자리에서 (3,2) 로 돌아선다 — 벽으로 안 올라간다")
	t.eq(g.level_at(int(step.x), int(step.y)), 0, "돌아선 칸은 낮은 층이다")
	g.release_all(WALKER_ID)

	# The whole walk. The target's own tile is reserved the way a live fight reserves an enemy's, so
	# the walker approaches rather than standing on it.
	var claimed := g.reserved
	claimed[g.tile_index(7, 1)] = Battle.ENEMY_UID_BASE
	g.reserved = claimed
	var pos := Vector2(1, 1)
	var visited := [pos]
	for _k in 60:
		var next_pos: Vector2 = g.step_toward(WALKER_ID, pos, field)
		if next_pos.distance_to(pos) <= Rules.EPS:
			break
		pos = next_pos
		visited.append(pos)
	g.release_all(WALKER_ID)
	g.release_all(Battle.ENEMY_UID_BASE)
	t.ok(visited.has(Vector2(4, 3)),
		"낮은 땅에서 고원의 적까지 걸으면 계단 (4,3) 을 밟고 지나간다 %s" % str(visited))
	t.ok(pos.distance_to(Vector2(7, 1)) <= sqrt(2.0) + Rules.EPS,
		"그리고 고원의 적 옆에 도착한다 (%s)" % str(pos))


# == the distance =====================================================================================

## **The two-pair board, and the pairing is what makes it a measurement.** Two pairs a plane tile
## apart sit on one island: one on the flat west end, one across the tier boundary at the east end.
## Everything else about them is identical, so the ONLY thing that can separate their answers is the
## height. ⚠⚠ **Without the flat pair, "the wolf did not bite" is equally explained by the pathfinder,
## by a targeting bug, or by the fixture being broken** — that is the exact shape that let 「무리가 한
## 덩어리로 움직인다」 pass on a board with one enemy on it.
##
## ⚠ **The pairs sit 12 tiles apart and that number is load-bearing.** `Rules.pack_radius_of(WOLF)` is
## 6.0, so two wolves any closer would average into one seek point and each pair would stop being its
## own experiment. **The pack radius is itself one of the readers moving to the height metric**, which
## is why it cannot be waved off as a detail of the fixture.
const PAIR_ROWS := [
	"~~~~~~~~~~~~~~~~~~~~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~~~~~~~~~~~~~~~~~~~~",
]
## The plateau is x 15..17 and there is deliberately NO stair: this board measures who can HIT whom,
## and a door would let both sides walk out of the arrangement being measured. With the plateau sealed
## every flow field across the boundary is `UNREACHABLE`, so both bodies stand exactly where they were
## put and the only thing that changes over the stepped seconds is HP.
const PAIR_TIERS := [
	"....................",
	"...............111..",
	"...............111..",
	"...............111..",
	"...............111..",
	"...............111..",
	"....................",
]
const PAIR_W := 20
## Plane 1 tile, two tiers of height: sqrt(1 + 2^2) = 2.2360679...
const ACROSS_THE_WALL := 2.2360679775


## The arithmetic, stated once. A tier is two tiles tall, so the neighbour across a boundary is 2.236
## away — **past a melee reach of 1.5 and inside a crow's 5.5.** ⚠ That is not a bonus and must not be
## read as one: it is the distance being measured in the space the bodies are actually standing in.
## The user refused 숫자 보너스 and this is a different object.
func _distance_carries_the_height(t) -> void:
	var b := _pair_battle([Rules.WOLF], [])
	var low_a := Vector2(2, 3)
	var low_b := Vector2(3, 3)
	var below := Vector2(14, 3)
	var above := Vector2(15, 3)
	t.eq(b.grid.level_at(14, 3), 0, "(14,3) 은 낮은 층이다 (자가 점검)")
	t.eq(b.grid.level_at(15, 3), 2, "(15,3) 은 높은 층이다 (자가 점검)")
	t.ok(absf(b.grid.height_at(above) - Rules.TIER_RISE_TILES) < 1e-4,
		"높은 층 타일의 높이가 한 층(%.2f 타일)이다" % Rules.TIER_RISE_TILES)
	t.ok(absf(b.grid.height_at(below)) < 1e-4, "낮은 층 타일의 높이는 0이다")

	t.ok(absf(b._dist(low_a, low_b) - 1.0) < 1e-4,
		"같은 층에서 한 칸 옆은 여전히 1.00 이다 — 평지 리터럴이 하나도 안 움직이는 이유")
	t.ok(absf(b._dist(below, above) - ACROSS_THE_WALL) < 1e-4,
		"층 경계를 사이에 둔 한 칸 옆은 %.4f 다 (얻은 값 %.4f)" % [ACROSS_THE_WALL, b._dist(below, above)])
	t.ok(absf(b._dist(above, below) - b._dist(below, above)) < 1e-6,
		"그리고 재는 방향이 답을 안 바꾼다")

	var melee: float = Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
	var ranged: float = Rules.range_of(Rules.CROW) + Rules.REACH_BONUS
	t.ok(b._within(low_a, low_b, melee), "늑대는 같은 층의 한 칸 옆을 문다")
	t.ok(not b._within(below, above, melee),
		"그런데 층 경계 너머는 못 문다 — %.2f 는 늑대의 %.2f 밖이다" % [ACROSS_THE_WALL, melee])
	t.ok(b._within(below, above, ranged),
		"까마귀는 넘어간다 — %.2f 는 %.2f 안이다. 벽이 모두를 막는 게 아니다" % [ACROSS_THE_WALL, ranged])


## The same claim driven as a FIGHT, because arithmetic being right is not the same as anything asking
## it. Two seconds of real `step`, HP read off both sides.
##
## ⚠ **Both halves are asserted in both runs.** The wolf run needs the flat pair to bleed (otherwise
## "no damage anywhere" passes as "the wall works"), and the crow run needs the high enemy to bleed
## (otherwise a wall that blocks everything passes too). **A ceiling with no floor is what this repo
## found on four presentation rows at once.**
func _a_wolf_cannot_bite_across_a_tier_and_a_crow_can(t) -> void:
	var wolves := _pair_battle([Rules.WOLF, Rules.WOLF], [Vector2(2, 3), Vector2(14, 3)])
	var w_before := [float(wolves.enemy_hp[0]), float(wolves.enemy_hp[1])]
	_step_for(wolves, 2.0)
	t.ok(float(wolves.enemy_hp[0]) < w_before[0] - Rules.EPS,
		"늑대는 같은 층의 적을 실제로 깎는다 (%.1f → %.1f)" % [w_before[0], float(wolves.enemy_hp[0])])
	t.ok(absf(float(wolves.enemy_hp[1]) - w_before[1]) < Rules.EPS,
		"그런데 벽 위의 적은 한 대도 못 맞는다 (%.1f → %.1f)" % [w_before[1], float(wolves.enemy_hp[1])])

	var crows := _pair_battle([Rules.CROW, Rules.CROW], [Vector2(2, 3), Vector2(14, 3)])
	var c_before := [float(crows.enemy_hp[0]), float(crows.enemy_hp[1])]
	_step_for(crows, 2.0)
	t.ok(float(crows.enemy_hp[0]) < c_before[0] - Rules.EPS,
		"까마귀도 같은 층의 적을 깎고 (%.1f → %.1f)" % [c_before[0], float(crows.enemy_hp[0])])
	t.ok(float(crows.enemy_hp[1]) < c_before[1] - Rules.EPS,
		"벽 위의 적도 깎는다 (%.1f → %.1f) — 대조군이 없으면 「벽이 막는다」와 「아무도 못 때린다」가 안 갈린다"
			% [c_before[1], float(crows.enemy_hp[1])])


## ⚠ **Splash rides `_within`, so it follows for free — and what follows for free also disappears
## quietly.** The bear's swing is an `area` around the tile it bit; the row exists so that a day when
## someone gives splash its own distance function, this reddens instead of the swing silently reaching
## over the wall again.
##
## The board: the bear bites the low enemy at (14,3), a second low enemy stands a diagonal away at
## (13,3) — **1.414, inside the 1.5 swing** — and the high enemy at (15,3) is a plane tile away but
## 2.236 in the space it stands in. **The low neighbour is the floor and the high one is the ceiling.**
func _a_swing_does_not_sweep_over_the_wall(t) -> void:
	var b := _pair_battle([Rules.BEAR], [Vector2(14, 4)], [Vector2(14, 3), Vector2(13, 3), Vector2(15, 3)])
	var area: float = Rules.area_of(Rules.BEAR)
	t.ok(area > 1.0, "곰의 휘두르기 반경이 실제로 있다 (%.2f 타일, 자가 점검)" % area)
	t.ok(area < ACROSS_THE_WALL, "그리고 그 반경이 층 경계 거리보다 짧다 (자가 점검)")
	var before := [float(b.enemy_hp[0]), float(b.enemy_hp[1]), float(b.enemy_hp[2])]
	_step_for(b, 2.0)
	t.ok(float(b.enemy_hp[0]) < before[0] - Rules.EPS, "곰이 (14,3) 의 적을 문다 (자가 점검)")
	t.ok(float(b.enemy_hp[1]) < before[1] - Rules.EPS,
		"휘두르기가 대각선 옆 (13,3) 까지 쓸어낸다 — 바닥. 이게 없으면 「아무것도 안 쓸었다」가 통과한다")
	t.ok(absf(float(b.enemy_hp[2]) - before[2]) < Rules.EPS,
		"그런데 벽 위 (15,3) 은 안 쓸린다 (%.1f → %.1f)" % [before[2], float(b.enemy_hp[2])])


## ⚠⚠ **THE ROW THIS FILE WAS MISSING, AND ITS ABSENCE IS WHY A FROZEN GAME PASSED 3177 CHECKS.**
##
## Everything above measures a PIECE: the flow field extends, one `step_toward` call turns away, HP does
## not move across a wall. **None of them runs the real walker at a boundary a body is supposed to
## cross.** So when `_walk`'s arrival test stayed planar — leaving a band where a body is "arrived"
## and cannot attack — nothing went red: the reachability row saw a field with values in it, the
## walking rows drove the grid's own step function instead of the fight, and the fight fixtures have no
## stair, so **「the enemy on the wall is never hit」 was equally satisfied by a wolf that had frozen.**
##
## ⇒ **This row runs the whole loop on a board where the stair works, and asks for the ticket's own
## sentence back: a wolf walks round, climbs, and takes HP off what is standing up there.**
##
## ⚠⚠ **TWO OF THE THREE WOLVES START INSIDE THE BAND, AND THE FIRST DRAFT OF THIS ROW DID NOT — SO IT
## PASSED AGAINST THE BROKEN CODE.** The band is not at the destination; it is any LOW tile within the
## planar reach of a body standing a tier up. The first board put the stair on the wolves' own line, so
## the flow field steered them round the band and out the other side and nothing ever froze. **A row
## that reproduces the bug only when the pathfinder happens to walk into it is not a measurement.**
## ⇒ **ALL THREE wolves start inside it**: (5,2), (5,3), (5,4), planar 1.41 / 1.00 / 1.41 from the enemy
## at (6,3) — every one inside a wolf's 1.5 — and 2.45 / 2.24 / 2.45 in the space the bodies stand in.
##
## ⚠⚠ **A DRAFT PUT ONE WOLF OUTSIDE THE BAND AS A CONTROL AND THAT ALONE MADE THE ROW GREEN.** The
## outsider walked the long way, climbed, and engaged — and the moment it did, the enemy stirred, its
## position moved, and the two frozen wolves fell OUT of the planar band and unfroze. **A standoff that
## a third body can break is not the standoff that was measured.** With all three inside it, nothing on
## the board can disturb anything: driven for 12 seconds against today's code the three do not move one
## pixel and the enemy stays at full HP.
##
## The stair is at (6,6), on the plateau's far side, so leaving the band means walking AWAY from the
## enemy first — which is the ticket's own sentence and the thing that cannot happen while `_walk`
## exits on its first line.
##
## ⚠ **The enemy is a LION for one reason: `Rules.detect_of` is 2.0, the smallest on the table.** A
## shieldbearer (6.0) would start walking down the stair to meet the wolves and the row would be
## measuring which of them moved. At 2.24 the lion does not wake, so what the row watches is the wolves.
const CLIMB_ROWS := [
	"~~~~~~~~~~~~~~",
	"~............~",
	"~............~",
	"~............~",
	"~............~",
	"~............~",
	"~............~",
	"~~~~~~~~~~~~~~",
]
const CLIMB_TIERS := [
	"..............",
	"..............",
	"......111111..",
	"......111111..",
	"......111111..",
	"......111111..",
	"....../.......",
	"..............",
]
const CLIMB_W := 14

## ⚠⚠ **A WIDE BOARD, AND THE WIDTH IS THE WHOLE FIXTURE.** The holding rule was first measured on the
## climb board and **both mutations against it reddened nothing**: the wolves are fast (4.0 tiles/s) and
## the stair was four tiles from them, so a wolf stood on the plateau within one second and the
## defender never had any reason to leave in the first place. **A defender that was never going to walk
## cannot demonstrate that it refused to.**
## ⇒ Here the attackers start **eleven tiles from the stair** and the defender is three from it, so
## without the rule it is off the plateau at about 3 seconds and the attackers do not arrive until
## well after. Measured both ways on this board: **with the rule, 0 frames off the plateau in 5
## seconds; without it, it steps onto the stair.**
const HOLD_ROWS := [
	"~~~~~~~~~~~~~~~~~~~~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~..................~",
	"~~~~~~~~~~~~~~~~~~~~",
]
const HOLD_TIERS := [
	"....................",
	"....................",
	"............111111..",
	"............111111..",
	"............111111..",
	"............111111..",
	"............/.......",
	"....................",
]
const HOLD_W := 20

## A plateau one row deep straight across the island, with no stair anywhere. **The north strip is
## 7 x 2 = 14 tiles and the south strip is unreachable from it** — the board that gives the landing
## search's WALK guard something only it can answer.
const SPLIT_ROWS := [
	"~~~~~~~~~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~~~~~~~~~",
]
const SPLIT_TIERS := [
	".........",
	".........",
	".........",
	".1111111.",
	".........",
	".........",
]
const CLIMB_ENEMY := Vector2(6, 3)
const CLIMB_START := [Vector2(5, 2), Vector2(5, 3), Vector2(5, 4)]


func _a_wolf_climbs_the_stair_and_kills_what_is_up_there(t) -> void:
	var b := _battle_on(CLIMB_ROWS, CLIMB_TIERS, [Rules.WOLF, Rules.WOLF, Rules.WOLF],
		CLIMB_START, [{"type_id": Rules.LION,
			"tile": int(CLIMB_ENEMY.y) * CLIMB_W + int(CLIMB_ENEMY.x)}])
	t.eq(b.grid.level_at(6, 3), 2, "적은 고원 서쪽 끝에 선다 (자가 점검)")
	t.eq(b.grid.level_at(5, 3), 0, "그 바로 옆 (5,3) 은 낮은 층이다 — 얼어붙는 자리 (자가 점검)")
	t.eq(b.grid.level_at(6, 6), 1, "계단은 고원 반대편 (6,6) 이다 (자가 점검)")
	var melee: float = Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
	t.ok(Vector2(5, 3).distance_to(CLIMB_ENEMY) <= melee,
		"(5,3) 은 평면으로는 늑대 사거리 안이다 — 띠가 실제로 있다는 자가 점검")
	t.ok(b._dist(Vector2(5, 3), CLIMB_ENEMY) > melee,
		"그런데 실제 거리로는 사거리 밖이다 — 이 둘이 같이 참인 자리가 얼어붙는 띠다")

	var hp_before := float(b.enemy_hp[0])
	var start: Array = []
	var moved: Array = []
	for k in CLIMB_START.size():
		start.append(b.soldier_pos[k])
		moved.append(false)
	var climbed := 0
	var climbed_seen: Array = [false, false, false]
	var enemy_left_high := 0
	var left := 12.0
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt
		var ep: Vector2 = b.enemy_pos[0]
		if b.grid.level_at(int(round(ep.x)), int(round(ep.y))) != 2:
			enemy_left_high += 1
		for k in CLIMB_START.size():
			var p: Vector2 = b.soldier_pos[k]
			if p.distance_to(start[k]) > 0.5:
				moved[k] = true
			if b.grid.level_at(int(round(p.x)), int(round(p.y))) == 2:
				climbed_seen[k] = true
	for k in climbed_seen.size():
		if bool(climbed_seen[k]):
			climbed += 1

	# ⚠⚠ **PER BODY, AND THE FIRST DRAFT WAS NOT.** It OR'd 「somebody moved」 across all three, and the
	# one wolf that started outside the band did the whole journey by itself — **so the row was green
	# with two wolves frozen solid.** That is this file's own named failure (「재려는 것 말고 다른 것이
	# 같은 답을 낼 수 없는 판을 만든다」) arriving in the check written to catch it.
	for k in CLIMB_START.size():
		t.ok(bool(moved[k]),
			"늑대 %d (%s 출발) 이 실제로 움직인다 — 벽 앞에서 얼어붙지 않는다" % [k, str(CLIMB_START[k])])
	t.ok(climbed >= 2,
		"셋 중 둘 이상이 계단을 밟고 고원에 올라선다 (%d 마리) — 티켓이 약속한 「돌아서 올라간다」" % climbed)
	# ⚠⚠ **THE PAIR, ASSERTED TOGETHER, AND THAT IS THE WHOLE GUARD.** Holding enemies and a fight that
	# ends are the two halves of one risk: **there is no time limit**, so an enemy that stays up there
	# and cannot be reached is a board that spins forever. Neither row means anything alone — 「it held
	# its ground」 is also true of an unreachable enemy, and 「it died」 is also true of one that walked
	# down to be killed on the flat, which is the inversion this ticket exists to remove.
	t.eq(enemy_left_high, 0,
		"그 적은 12초 동안 고원을 한 프레임도 안 떠난다 — 내려와서 죽어 준 게 아니다")
	t.ok(float(b.enemy_hp[0]) < hp_before - Rules.EPS,
		"그런데도 실제로 깎인다 (%.1f → %.1f) — 버티는 적과 끝나는 싸움이 같이 성립한다"
			% [hp_before, float(b.enemy_hp[0])])


## ⚠⚠ **THE STAIR IS ONE TILE WIDE, SO A BODY ON IT THAT CANNOT SWING BLOCKS EVERYTHING BEHIND IT.**
## Measured in play: a melee body stood on the island's only stair for 163 seconds without landing a
## blow, because the enemy it was chasing stood DIAGONALLY above it. From a stair (level 1) to the
## plateau (level 2) the orthogonal neighbour is `sqrt(1 + 1)` = 1.414 and the diagonal is
## `sqrt(2 + 1)` = **1.732** — and melee reach was 1.500. **26 of 162 fights were lost to it.**
##
## Both bodies are pinned every frame, the way the verifier's own probe does it, so nothing here
## measures walking — only whether the blow lands.
##
## ⚠ **Three cases, and the middle one is the fix.** The orthogonal case is the POSITIVE CONTROL: if it
## ever stops landing, this fixture is broken rather than the sim. The flat two-tile case is the
## CEILING: the new reach sits in `(sqrt(3), 2.0)` and must not have swallowed the next distance up.
func _melee_reaches_a_diagonal_one_level_up(t) -> void:
	var stair := Vector2(6, 6)
	var g := Grid.new()
	g.load_rows(CLIMB_ROWS, CLIMB_TIERS)
	t.eq(g.level_at(6, 6), 1, "때리는 몸은 계단(1단) 위에 선다 (자가 점검)")
	t.eq(g.level_at(6, 5), 2, "정직교 위 (6,5) 는 고원이다 (자가 점검)")
	t.eq(g.level_at(7, 5), 2, "대각 위 (7,5) 도 고원이다 (자가 점검)")

	var ortho := _pinned_damage(stair, Vector2(6, 5))
	var diag := _pinned_damage(stair, Vector2(7, 5))
	var flat_two := _pinned_damage(Vector2(2, 3), Vector2(4, 3))
	t.ok(ortho > 0.0,
		"양성 대조군 — 계단에서 정직교로 한 단 위(1.414)는 맞는다 (%.1f 피해). 이게 0이면 픽스처가 고장이다"
			% ortho)
	t.ok(diag > 0.0,
		"그리고 대각으로 한 단 위(1.732)도 맞는다 (%.1f 피해) — 사거리 1.50 에서는 20초 동안 0이었다" % diag)
	t.ok(flat_two <= 0.0,
		"그런데 평지에서 두 칸 떨어진(2.000) 몸은 여전히 못 맞힌다 (%.1f 피해) — 창이 (1.732, 2.000) 안이다"
			% flat_two)

	var melee: float = Rules.range_of(Rules.WOLF) + Rules.REACH_BONUS
	t.ok(melee > sqrt(3.0) and melee < 2.0,
		"근접 사거리 %.3f 가 sqrt(3)=%.3f 와 2.000 사이에 있다 — 양쪽이 다 필요하다" % [melee, sqrt(3.0)])


## ⚠⚠ **A DEFENDER POSTED ON HIGH GROUND MUST NOT WALK OFF IT, AND THAT IS THE WHOLE POINT OF THE
## TICKET.** Measured in play: **most WON fights never sent anyone up the stairs at all** — the plateau
## archers walked down and died on the flat, so the side doing the walking was the defender and 티켓
## 19's answer («the advantage is positional, the enemy has to come round») was inverted.
##
## ⚠ **The control is the other half of the rule and it is not optional.** Holding must be NARROW — an
## enemy on the low ground still advances, or the fight stops coming to the player at all.
func _an_enemy_posted_high_holds_its_tier(t) -> void:
	var high := _battle_on(HOLD_ROWS, HOLD_TIERS, [Rules.WOLF, Rules.WOLF],
		[Vector2(1, 3), Vector2(1, 4)],
		[{"type_id": Rules.WOLF, "tile": 3 * HOLD_W + 13}])
	t.eq(high.grid.level_of(3 * HOLD_W + 13), 2, "그 방패병은 고원 위에서 시작한다 (자가 점검)")
	t.ok(Rules.detect_of(Rules.WOLF) > 3.0,
		"그리고 탐지 반경이 늑대들을 실제로 본다 (%.1f 타일, 자가 점검) — 안 보이면 안 움직이는 게 당연해진다"
			% Rules.detect_of(Rules.WOLF))
	# ⚠⚠ **THE SELF-CHECK THAT STOPS THIS ROW BEING VACUOUS.** 「It never left the plateau」 is also true
	# of a plateau nothing can leave. The route down has to EXIST for the refusal to mean anything, so
	# the game's own field is asked whether the enemy's tile is reachable from where the wolves stand —
	# it is, through the stair at (6,6), and the enemy declines to use it.
	var down := high.grid.flow_field(high.grid.tile_index(1, 3))
	t.ok(int(down[3 * HOLD_W + 13]) != Grid.UNREACHABLE,
		"늑대가 선 자리에서 그 적의 칸까지 길이 실제로 있다 (자가 점검) — 막혀 있으면 아래가 공허하다")

	var left_high := 0
	var start_high: Vector2 = high.enemy_pos[0]
	var t_left := 5.0
	while t_left > Rules.EPS:
		var dt: float = minf(t_left, 1.0 / 60.0)
		high.step(dt)
		t_left -= dt
		var p: Vector2 = high.enemy_pos[0]
		if high.grid.level_at(int(round(p.x)), int(round(p.y))) != 2:
			left_high += 1
	t.eq(left_high, 0, "5초 동안 한 프레임도 고원을 안 떠난다 — 길이 있는데도 제 계단으로 안 내려간다")
	# ⚠ **It is free to move ON its tier and it does.** The rule is 「does not leave its tier」, not
	# 「stands still」 — a defender that shuffles along the plateau edge to face the attackers is exactly
	# what holding ground looks like. A draft of this row asserted it never moved at all and reddened,
	# which is the row claiming more than the rule says.
	t.ok(high.enemy_pos[0].distance_to(start_high) > 0.0,
		"그 안에서 움직이는 것은 자유다 (%.2f 타일 이동) — 「제자리에 못 박힌다」가 아니라 「층을 안 떠난다」이다"
			% high.enemy_pos[0].distance_to(start_high))

	# The other end. Same species, same board, posted on the LOW ground: it must still come.
	var low := _battle_on(HOLD_ROWS, HOLD_TIERS, [Rules.WOLF, Rules.WOLF],
		[Vector2(1, 3), Vector2(1, 4)],
		[{"type_id": Rules.WOLF, "tile": 3 * HOLD_W + 5}])
	t.eq(low.grid.level_of(3 * HOLD_W + 5), 0, "대조군의 방패병은 낮은 층에서 시작한다 (자가 점검)")
	var start_low: Vector2 = low.enemy_pos[0]
	var moved_low := false
	t_left = 5.0
	while t_left > Rules.EPS:
		var dt2: float = minf(t_left, 1.0 / 60.0)
		low.step(dt2)
		t_left -= dt2
		if low.enemy_pos[0].distance_to(start_low) > 0.5:
			moved_low = true
	t.ok(moved_low,
		"낮은 층의 적은 여전히 다가온다 — 「전부 제자리를 지킨다」로 만들면 싸움이 플레이어에게 안 온다")
	var lp: Vector2 = low.enemy_pos[0]
	t.eq(low.grid.level_at(int(round(lp.x)), int(round(lp.y))), 0,
		"그 적은 낮은 층에 머문다 — 붙들려서가 아니라 거기 있는 적을 쫓아서다 (자가 점검)")


## ⚠⚠ **THE PACK'S SEEK POINT IS A MEAN, AND A MEAN IS NOT A PLACE ANYBODY STANDS.** 무리사냥 aims from
## the centre of the huddle, and the distance function used to read that point's height off whatever
## tile it rounded onto — so **two wolves on the ground with one packmate on the plateau were aiming
## from two tiles up**, preferring the enemy above and walking into the wall.
##
## The board makes the mean land on a plateau tile on purpose: wolves at (5,3), (5,4) and (8,3) average
## to (6, 3.33), which rounds to (6,3) — level 2, where none of them is standing.
##
## ⚠ **The claim is a PAIR from one seek point, which is what makes it about the height and not about
## the point.** Two enemies sit at almost the same distance from that mean: from the ground the low one
## is nearer (2.54 against 3.28) and from the plateau the high one is (2.61 against 3.23). **So the two
## ground wolves must choose the low enemy and the plateau wolf must choose the high one — same mean,
## three bodies, two answers.** Read the height off the mean and all three choose the same enemy, which
## is the shape this row exists to refuse.
func _a_pack_aims_from_where_its_bodies_stand(t) -> void:
	var b := _battle_on(CLIMB_ROWS, CLIMB_TIERS, [Rules.WOLF, Rules.WOLF, Rules.WOLF],
		[Vector2(5, 3), Vector2(5, 4), Vector2(8, 3)], [
			{"type_id": Rules.CROW, "tile": 1 * CLIMB_W + 5},
			{"type_id": Rules.CROW, "tile": 5 * CLIMB_W + 8},
		])
	t.eq(b.grid.level_at(5, 1), 0, "적 0 은 낮은 층에 선다 (자가 점검)")
	t.eq(b.grid.level_at(8, 5), 2, "적 1 은 고원 위에 선다 (자가 점검)")
	t.eq(b.grid.level_at(5, 3), 0, "늑대 둘은 낮은 층 (자가 점검)")
	t.eq(b.grid.level_at(8, 3), 2, "늑대 하나는 고원 위 (자가 점검)")
	var seek := b._seek_point_of(0)
	t.eq(b.grid.level_at(int(round(seek.x)), int(round(seek.y))), 2,
		"무리의 조준점 %s 이 실제로 고원 칸 위로 떨어진다 — 아무도 안 서 있는 자리다 (자가 점검)" % str(seek))
	for k in 3:
		t.ok(b._seek_point_of(k).distance_to(seek) <= Rules.EPS,
			"늑대 %d 도 같은 조준점을 쓴다 — 셋의 답이 갈리는 이유가 조준점일 수 없다 (자가 점검)" % k)

	b.step(1.0 / 60.0)
	t.eq(int(b.soldier_target[0]), 0, "낮은 층의 늑대는 낮은 층의 적을 고른다")
	t.eq(int(b.soldier_target[1]), 0, "옆의 늑대도 마찬가지다")
	t.eq(int(b.soldier_target[2]), 1, "그런데 고원 위의 늑대는 고원 위의 적을 고른다 — 같은 조준점, 다른 답")


## 티켓 19's answer: ***"높은 데서 밀리면 안 떨어져. 안 떨어지는 걸로."*** **Both shoving species were
## doing the exact opposite** — 소's charge pushed enemies UP onto a plateau and 다람쥐's pull dragged
## them DOWN off one, because the tile search behind both never asked what tier anything was on.
##
## ⚠ **Each direction is measured against its own FLAT control on the same board.** "The enemy did not
## move" is equally true of a shove that is simply broken, and this file has a written case of exactly
## that shape passing.
func _a_shove_never_changes_a_bodys_tier(t) -> void:
	# -- 다람쥐 pulls TOWARD itself: from the low ground it would drag a plateau body down --------------
	var pull := _shove_board([Rules.SWORDSMAN], [Vector2(4, 3)], Vector2(6, 3), CLIMB_TIERS)
	var pull_flat := _shove_board([Rules.SWORDSMAN], [Vector2(4, 3)], Vector2(6, 3), [])
	t.eq(pull.grid.level_at(6, 3), 2, "끌려갈 적이 고원 위에 선다 (자가 점검)")
	t.ok(pull._within(pull.soldier_pos[0], pull.enemy_pos[0], pull._soldier_reach(0)),
		"다람쥐는 벽 너머의 그 적을 실제로 때릴 수 있다 (자가 점검 — 못 때리면 아래가 공허하다)")
	pull_flat._shove_victims(0, 0, PackedInt32Array())
	t.ok(pull_flat.enemy_pos[0].distance_to(Vector2(6, 3)) > Rules.EPS,
		"평지 대조군 — 다람쥐의 끌기는 실제로 몸을 옮긴다 (%s)" % str(pull_flat.enemy_pos[0]))
	pull._shove_victims(0, 0, PackedInt32Array())
	t.eq(pull.grid.level_at(int(round(pull.enemy_pos[0].x)), int(round(pull.enemy_pos[0].y))), 2,
		"그런데 층이 있으면 고원 위의 적은 끌려 내려오지 않는다 (%s)" % str(pull.enemy_pos[0]))

	# -- 소 charges AWAY: from the low ground it would drive a body up onto the plateau ----------------
	var push := _shove_board([Rules.SWORDSMAN], [Vector2(4, 3)], Vector2(5, 3), CLIMB_TIERS)
	var push_flat := _shove_board([Rules.SWORDSMAN], [Vector2(4, 3)], Vector2(5, 3), [])
	t.eq(push.grid.level_at(5, 3), 0, "들이받힐 적은 낮은 층에 서고 (자가 점검)")
	t.eq(push.grid.level_at(6, 3), 2, "그 등 뒤가 고원이다 (자가 점검)")
	push_flat._shove_victims(0, 0, PackedInt32Array())
	t.ok(push_flat.enemy_pos[0].distance_to(Vector2(5, 3)) > Rules.EPS,
		"평지 대조군 — 소의 돌진은 실제로 몸을 밀어낸다 (%s)" % str(push_flat.enemy_pos[0]))
	push._shove_victims(0, 0, PackedInt32Array())
	t.eq(push.grid.level_at(int(round(push.enemy_pos[0].x)), int(round(push.enemy_pos[0].y))), 0,
		"그런데 층이 있으면 벽 위로 안 밀려 올라간다 (%s)" % str(push.enemy_pos[0]))
	# ⚠ The once-per-island charge is spent by the MOVE, never by the attempt — so a charge the wall
	# refused is a charge 소 still has. That rule already existed; this is the row that keeps the tier
	# refusal from quietly eating it.
	t.eq(int(push._charged[0]), 0,
		"그리고 벽에 막힌 돌진은 소의 한 번뿐인 돌진을 안 쓴다 — 안 움직였으면 안 쓴 것이다")


## ⚠⚠ **MEASURED ON THE REAL FIRST ISLAND, from an approved landing the player will actually aim at.**
## The search that picks where landing bodies stand tested passability and nothing else, so a beach
## whose own tiles were taken walked up the wall and handed back a tile ON THE PLATEAU. A body put
## there can never come down and no enemy can ever reach it — **and because the walking step reads a
## body's tier off the tile it stands on, the placement hole hardens into a movement fact.**
##
## The domain is asserted first: a search that returned nothing would satisfy "none of them is high".
func _a_landing_never_puts_a_body_on_the_plateau(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var b := Battle.new()
	b.setup(g, Army.new(), Islands.spawns(), 999.0)
	# ⚠⚠ **The tile moved with the island and the choice is not arbitrary.** (16,3) was a shore on the
	# rectangle and is inland on the drawn coast. (22,2) is picked because it is **the approved landing
	# nearest the plateau** — it touches the plateau's own corner diagonally, so the ten-tile search
	# starting there has the strongest pull up the wall of any beach on this island. A landing far from
	# the plateau would pass this row without ever testing it.
	var landing := g.tile_index(22, 2)
	t.ok(_is_landing(g, landing), "(22,2) 는 실제로 승인된 상륙지다 (자가 점검)")
	t.eq(g.level_of(landing), 0, "그리고 낮은 층이다 (자가 점검)")
	var want := 10
	var tiles := b._free_tiles_from(landing, want)
	t.eq(tiles.size(), want, "그 상륙지에서 설 자리 %d 칸을 실제로 받았다 (자가 점검)" % want)
	var high := 0
	for tile in tiles:
		if g.level_of(tile) != 0:
			high += 1
	t.eq(high, 0, "그중 고원 위인 칸은 하나도 없다 — 배는 벽 위에 몸을 못 내려놓는다")

	# ⚠⚠ **THE ROW ABOVE ALONE PROVES ONE GUARD AND NOT THE OTHER, AND THAT WAS MEASURED.** The search
	# has two: it will not WALK across a wall, and it will not COLLECT a tile off the landing's own
	# tier. For a plateau tile either one is enough, so **deleting either alone reddened nothing.**
	# Two boards follow, each built so only one guard can answer.

	# ① **The STAIR, which the search is right to walk through and wrong to stop on.** Asking from the
	# low tile beside it, only the collect test can refuse it — the walk test lets a level-1 tile
	# through by design.
	var cb := _battle_on(CLIMB_ROWS, CLIMB_TIERS, [], [], [])
	var beside_stair := cb.grid.tile_index(5, 6)
	t.eq(cb.grid.level_of(beside_stair), 0, "계단 옆 (5,6) 은 낮은 층이다 (자가 점검)")
	t.eq(cb.grid.level_at(6, 6), 1, "그리고 (6,6) 이 계단이다 (자가 점검)")
	var near := cb._free_tiles_from(beside_stair, 12)
	t.eq(near.size(), 12, "계단 옆에서 설 자리 12칸을 받았다 (자가 점검)")
	var on_stair := 0
	for tile in near:
		if cb.grid.level_of(tile) != 0:
			on_stair += 1
	t.eq(on_stair, 0, "그중 계단 칸은 없다 — 해변이 꽉 차도 몸이 계단으로 안 올라간다")

	# ② **A plateau that cuts the island in two.** The south strip is level 0, so the collect test
	# cannot refuse it; only the walk test can, and it must — nothing landed on the north strip can
	# ever get there.
	var sb := _battle_on(SPLIT_ROWS, SPLIT_TIERS, [], [], [])
	var north := sb.grid.tile_index(4, 1)
	t.eq(sb.grid.level_of(north), 0, "가른 판의 북쪽 (4,1) 은 낮은 층이다 (자가 점검)")
	t.eq(sb.grid.level_at(4, 3), 2, "가운데 한 줄이 통째로 고원이라 남북이 끊긴다 (자가 점검)")
	var strip := sb._free_tiles_from(north, 30)
	# The north strip is 7 x 2 = 14 tiles and every one of them is free, so a search that stayed on its
	# own side can only ever return 14 — asking for 30 is what makes the number a claim.
	t.eq(strip.size(), 14, "북쪽 띠 14칸만 돌아온다 — 30칸을 물어도 벽 너머로는 안 넘어간다")
	var crossed := 0
	for tile in strip:
		if int(tile) / sb.grid.w > 3:
			crossed += 1
	t.eq(crossed, 0, "남쪽 띠에서 가져온 칸이 하나도 없다 — 걸어갈 수 없는 땅에 몸을 안 내려놓는다")


# == the island ========================================================================================

## The board the user is going to look at. **The floor rows come first**: without them every claim
## below is true of a flat island, and a check that is vacuous is a check that will stay green when
## the plateau is deleted.
func _the_first_island_carries_a_real_plateau(t) -> void:
	var rows := Islands.rows()
	var tiers := Islands.tiers()
	var g := Grid.new()
	g.load_rows(rows, tiers)

	var high := 0
	var stairs := 0
	var high_on_hole := 0
	var stair_on_hole := 0
	var high_touching_water := 0
	for tile in g.level.size():
		var lv := g.level_of(tile)
		if lv == 0:
			continue
		if g.passable[tile] == 0:
			if lv == 1:
				stair_on_hole += 1
			else:
				high_on_hole += 1
		if lv == 1:
			stairs += 1
			continue
		high += 1
		var tx := tile % g.w
		var ty := tile / g.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			if g.water[ny * g.w + nx] != 0:
				high_touching_water += 1
				break

	t.eq(high, ISLAND_HIGH, "첫 섬의 고원은 %d 칸이다" % ISLAND_HIGH)
	t.eq(stairs, ISLAND_STAIR, "그리고 계단은 %d 칸이다" % ISLAND_STAIR)
	# ⚠ A stair written over water or over a cliff is a door that silently is not there: the letter is
	# in the tier board, the eye sees a colour, and the field never expands through it.
	t.eq(stair_on_hole, 0, "계단이 못 걷는 칸 위에 안 적혀 있다")
	t.eq(high_on_hole, 0, "높은 땅도 못 걷는 칸 위에 안 적혀 있다")
	# ⚠⚠ **This is what makes 「상륙은 낮은 층에만」 not being built yet harmless.** The rule is not in
	# the code this slice; the island is authored so that nothing can land on the plateau anyway,
	# because no plateau tile touches the sea. **The day a plateau reaches a shore, the rule has to
	# exist first** — and this row is what will redden and say so.
	t.eq(high_touching_water, 0,
		"고원이 여덟 방향 어디로도 물에 안 닿는다 — 상륙 거절 규칙이 아직 없어도 배가 고원에 못 내리는 이유")

	# The enemies. Half of them stand on the plateau, which is the whole of "the first island teaches
	# that high ground has to be climbed" — an empty plateau teaches nothing.
	var spawns := Islands.spawns()
	t.eq(spawns.size(), ISLAND_ENEMIES, "첫 섬의 적은 여섯이다 (자가 점검)")
	var on_high := 0
	for raw in spawns:
		var s: Dictionary = raw
		if g.level_of(int(s["tile"])) == 2:
			on_high += 1
	t.eq(on_high, ISLAND_ENEMIES_HIGH, "그중 셋이 고원 위에 선다 — 빈 고원은 아무것도 안 가르친다")

	# ⚠ The user's own condition on this island: 「전략적인 요소」. A stair a boat can be parked next to
	# is not a decision, so the door is asserted to be off the coast entirely.
	var stair_tile := -1
	for tile in g.level.size():
		if g.level_of(tile) == 1:
			stair_tile = tile
			break
	t.ok(stair_tile >= 0, "계단 칸을 찾았다 (자가 점검)")
	t.ok(not _is_landing(g, stair_tile), "계단 칸 자체는 상륙지가 아니다")
	var sx := stair_tile % g.w
	var sy := stair_tile / g.w
	var landings_beside := 0
	for k in Grid.NEIGHBOURS.size():
		var nx := sx + int(Grid.NEIGHBOURS[k][0])
		var ny := sy + int(Grid.NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
			continue
		if _is_landing(g, ny * g.w + nx):
			landings_beside += 1
	t.eq(landings_beside, 0, "계단 옆 여덟 칸에도 상륙지가 없다 — 문 앞에 바로 못 내린다")


## ⚠⚠ **THE CHECK THE PLAN CALLS MANDATORY, AND THE REASON IS NOT TIDINESS.** Nothing loses on the
## clock any more. If one enemy on a plateau cannot be reached from where the fleet can land, that
## island never ends — the board spins forever, the player is stuck, and every net in this suite stays
## green because no net watches a fight for a hundred simulated seconds. **A plateau is exactly the
## shape that makes it possible.**
##
## Measured with the game's OWN `flow_field`, one per enemy, against the game's own `can_land_at`.
## Derived outside Godot: 54 landing tiles x 6 defenders = 324 pairs, 0 unreachable.
func _every_landing_reaches_every_enemy_on_the_first_island(t) -> void:
	var g := Grid.new()
	g.load_rows(Islands.rows(), Islands.tiers())
	var spawns := Islands.spawns()
	var landings := _landings_of(g)
	# The domain, first. `0 unreachable` over an empty set is the emptiest green there is.
	t.eq(landings.size(), ISLAND_LANDINGS, "첫 섬의 상륙지는 %d 칸이다" % ISLAND_LANDINGS)
	t.eq(spawns.size(), ISLAND_ENEMIES, "그리고 적은 %d 이다" % ISLAND_ENEMIES)
	t.eq(_unreachable_pairs(g, spawns, landings), 0,
		"어느 상륙지에서 출발해도 적 여섯에 전부 닿는다 — 안 닿으면 그 판은 영원히 안 끝난다")


## ⚠⚠ **Inverting the INSTRUMENT, not the subject.** `_unreachable_pairs` returning a constant 0 would
## pass the row above forever, and this repo has shipped exactly that twice in one night. So the same
## helper is run on a board built to break it: a plateau with no stair, a shore it can be landed on,
## and an enemy standing up top.
func _the_reach_check_can_actually_fail(t) -> void:
	var g := Grid.new()
	g.load_rows(SEALED_ROWS, SEALED_TIERS)
	var spawns := _spawns_of_rows(SEALED_ROWS)
	t.eq(spawns.size(), 1, "합성 섬에 적이 하나 있다 (자가 점검)")
	t.eq(g.level_of(int((spawns[0] as Dictionary)["tile"])), 2,
		"그 적은 고원 위에 선다 (자가 점검)")
	var landings := _landings_of(g)
	# 9 x 6 of land, so the coast is its perimeter: 2 x (9 + 6) - 4 = 26, and the 3 x 3 plateau is
	# inland, so not one landing tile is on it.
	t.eq(landings.size(), SEALED_LANDINGS, "그 섬의 상륙지는 %d 칸이다 (자가 점검)" % SEALED_LANDINGS)
	var on_high := 0
	for tile in landings:
		if g.level_of(tile) == 2:
			on_high += 1
	t.eq(on_high, 0, "그리고 상륙지 중 고원 위인 칸은 없다 (자가 점검)")
	t.eq(_unreachable_pairs(g, spawns, landings), SEALED_LANDINGS,
		"계단 없는 고원에 선 적은 상륙지 %d 칸 전부에서 못 닿는다 — 도달 검사가 실제로 문다"
			% SEALED_LANDINGS)


## The two boards have to be the same shape or a stair lands on a tile nobody authored. Asked for
## **every** island, not only the one that has a board: an empty board is legal and means flat, and a
## board that is present must match its rows row for row.
func _no_tier_board_is_a_different_shape_from_its_island(t) -> void:
	var boarded := 0
	for i in 1:
		var tiers := Islands.tiers()
		if tiers.is_empty():
			continue
		boarded += 1
		var rows := Islands.rows()
		t.eq(tiers.size(), rows.size(), "섬 %d — 단 판의 행 수가 지형 판과 같다" % i)
		var bad_width := 0
		var bad_chars := []
		for y in mini(tiers.size(), rows.size()):
			if String(tiers[y]).length() != String(rows[y]).length():
				bad_width += 1
			for x in String(tiers[y]).length():
				var c := String(tiers[y])[x]
				if Grid.TIER_CHARS.find(c) == -1 and not bad_chars.has(c):
					bad_chars.append(c)
		t.eq(bad_width, 0, "섬 %d — 단 판의 모든 행 길이가 지형 판과 같다" % i)
		t.eq(bad_chars, [], "섬 %d — 단 판에 범례(%s) 밖 글자가 없다" % [i, Grid.TIER_CHARS])
	t.eq(boarded, 1,
		"단 판을 가진 섬은 아직 하나다 — 나머지 일곱은 평지이고, 다 된 게 아니라 아직 안 지은 것이다")


## ⚠⚠ **A TEXT SCAN, AND ITS LABEL SAYS SO** — this repo has measured five scans being evaded inside
## one feature, so nothing here should be read as proving a tool loads an island correctly. What it
## catches is the ONE mistake that actually happened: loading an island became two calls, five callers
## kept making one, and a grid loaded without its board **comes up flat, draws, plays and says
## nothing** — the probe reported a flat island and the shooter photographed one, with the whole round
## green. `Islands.load_into` is the real fix; this is the tripwire on it.
##
## ⚠ **Two files are outside the sweep and both are the door itself**: `grid.gd` declares `load_rows`
## and `islands.gd` is `load_into`, which is a call to it by definition. `tests/` is outside by
## construction — every net builds its own board by hand and must keep calling `load_rows` directly.
const LOADER_FILES := ["sim/grid.gd", "sim/islands.gd"]


func _an_island_number_is_loaded_through_one_door(t) -> void:
	var offenders: Array = []
	var scanned := 0
	for path in _gd_files_under(["res://src", "res://tools"]):
		var is_loader := false
		for tail in LOADER_FILES:
			if path.ends_with(tail):
				is_loader = true
		if is_loader:
			continue
		scanned += 1
		if _calls_load_rows(FileAccess.get_file_as_string(path)):
			offenders.append(path)
	# A sweep over nothing is a green that measured nothing — this repo's settle loop passed at zero
	# iterations once.
	t.ok(scanned > 20, "src 와 tools 에서 .gd 를 %d 개 훑었다 (자가 점검)" % scanned)
	t.eq(offenders, [],
		"grid.gd 밖에서는 아무도 load_rows 를 직접 안 부른다 — 섬 번호는 Islands.load_into 로만 실린다 %s"
			% str(offenders))
	# ⚠ **Inverting the INSTRUMENT.** A scanner that matches nothing passes the row above forever, so
	# it is handed the exact line it exists to find and one it must not fire on.
	t.ok(_calls_load_rows("\tg.load_rows(Islands.rows())"),
		"그 훑기가 실제로 그 호출을 잡는다 (계측기 자가 점검)")
	t.ok(not _calls_load_rows("\tIslands.load_into(g)"),
		"그리고 제대로 된 호출에는 안 문다 (계측기 자가 점검)")


func _calls_load_rows(text: String) -> bool:
	return text.contains(".load_rows(")


func _gd_files_under(roots: Array) -> Array:
	var out: Array = []
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var dir: String = str(stack.pop_back())
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				out.append(dir.path_join(f))
	out.sort()
	return out


# == helpers ==========================================================================================

## Whether ANY harbour may put a boat down on this tile. `can_land_at` is the game's own rule; a
## second definition here would be the one that rots.
func _is_landing(g: Grid, tile: int) -> bool:
	for hb in g.harbour_tiles.size():
		if g.can_land_at(hb, tile):
			return true
	return false


## The two-pair island, with `species` recruited and placed at `at`, and a shieldbearer standing at
## each of `enemies_at` (the flat pair's and the walled pair's tiles by default).
##
## ⚠ **Committed by hand, `net_battle`'s and `net_fx_view`'s own idiom**: an uncommitted battle is
## inert to every driver, and the commit gate is `net_plan`'s subject rather than this file's.
func _pair_battle(species: Array, at: Array, enemies_at: Array = []) -> Battle:
	var where: Array = enemies_at
	if where.is_empty():
		where = [Vector2(3, 3), Vector2(15, 3)]
	var spawns := []
	for raw in where:
		var p: Vector2 = raw
		spawns.append({"type_id": Rules.WOLF, "tile": int(p.y) * PAIR_W + int(p.x)})
	return _battle_on(PAIR_ROWS, PAIR_TIERS, species, at, spawns)


## A committed fight on any board, with `species` recruited and put ashore at `at`, and `spawns` in
## `Islands.spawns_of`'s own shape.
##
## ⚠ **Committed by hand, `net_battle`'s and `net_fx_view`'s own idiom**: an uncommitted battle is
## inert to every driver, and the commit gate is `net_plan`'s subject rather than this file's.
func _battle_on(rows: Array, tiers: Array, species: Array, at: Array, spawns: Array) -> Battle:
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var army := Army.new()
	for raw in species:
		var ty := int(raw)
		var slot := army.slot_of_type(ty)
		if slot < 0:
			slot = army.register_species(ty)
		army.recruit(slot)
	var b := Battle.new()
	b.setup(g, army, spawns, 999.0)
	b._committed = true
	for k in at.size():
		_ashore(b, k, at[k])
	return b


## How much HP a pinned melee body takes off a pinned enemy in 8 seconds on the climb board.
##
## ⚠ **Both bodies are put back every frame** — the verifier's own probe idiom. Nothing here measures
## walking, reservation or pathfinding; only whether the blow lands from exactly that pair of tiles.
func _pinned_damage(attacker: Vector2, victim: Vector2) -> float:
	var b := _battle_on(CLIMB_ROWS, CLIMB_TIERS, [Rules.WOLF], [attacker],
		[{"type_id": Rules.WOLF, "tile": int(victim.y) * CLIMB_W + int(victim.x)}])
	b.enemy_pos[0] = victim
	b.army.hp[0] = 9999.0
	var hp0 := float(b.enemy_hp[0])
	var left := 8.0
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt
		# Pinned, every frame, both sides.
		b.soldier_pos[0] = attacker
		b._soldier_goal[0] = attacker
		b.enemy_pos[0] = victim
		b._enemy_goal[0] = victim
		b.army.hp[0] = 9999.0
	return hp0 - float(b.enemy_hp[0])


## One shoving species ashore at `at`, one shieldbearer at `enemy`, on the climb board with the tier
## board `tiers` — pass `[]` for the flat control.
func _shove_board(species: Array, at: Array, enemy: Vector2, tiers: Array) -> Battle:
	return _battle_on(CLIMB_ROWS, tiers, species, at,
		[{"type_id": Rules.WOLF, "tile": int(enemy.y) * CLIMB_W + int(enemy.x)}])


## Ashore the way a landing leaves a body — state, position, goal AND the tile reservation. State
## alone teleports the body back to its stale goal on the first move (`net_fx`'s measured trap).
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[b.grid.tile_index(int(round(p.x)), int(round(p.y)))] = i
	b.grid.reserved = claimed


## Real seconds through the real `step`, a frame at a time. **Not one big `step(2.0)`** — the sim runs
## whole `Rules.SIM_SUBSTEP_SEC` passes and a single huge delta is a different discretisation from the
## one the game runs on.
func _step_for(b: Battle, seconds: float) -> void:
	var left := seconds
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt


## Every spawn on a hand-written fixture, in `Islands.spawns_of`'s own shape. **Reads
## `Islands.spawn_type_of_char`** rather than naming a unit row here, so a letter that is re-bound
## cannot leave this file spawning something else than the game would.
func _spawns_of_rows(rows: Array) -> Array:
	var w := String(rows[0]).length()
	var out := []
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var type_id := Islands.spawn_type_of_char(row[x])
			if type_id >= 0:
				out.append({"type_id": type_id, "tile": y * w + x})
	return out


func _landings_of(g: Grid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tile in g.passable.size():
		if _is_landing(g, tile):
			out.append(tile)
	return out


## How many (landing, enemy) pairs the game's own flow field cannot connect. **One field per enemy and
## not per landing**: the field is symmetric in reachability and 6 fields is 54 times cheaper than 324.
func _unreachable_pairs(g: Grid, spawns: Array, landings: PackedInt32Array) -> int:
	var bad := 0
	for raw in spawns:
		var s: Dictionary = raw
		var field := g.flow_field(int(s["tile"]))
		for tile in landings:
			if int(field[tile]) == Grid.UNREACHABLE:
				bad += 1
	return bad
