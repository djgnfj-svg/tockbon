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
## ⚠⚠ **AND THE INSTRUMENT WAS INVERTED TOO — UNTIL 02-08 DELETED BOTH HALVES OF IT.**
## `_unreachable_pairs` was the check that stopped an island where an enemy on a plateau can never be
## reached — a fight that never ends, on a board with no time limit left in it, with every net still
## green — and it was run on a fixture built to FAIL it. **Neither the helper nor that fixture is here
## any more**, and the deletion blocks below say why. ⚠ **The rule the pair stood for is untouched by
## their going**: an instrument that cannot be seen to fail is not an instrument.
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
	".....222.",
	".....222.",
	"..../222.",
	".....222.",
	".........",
]
const FIXTURE_W := 9

## **A board built for ONE question: may a body cut a diagonal past a blocked corner?** Flat on
## purpose — the height rule already refuses a diagonal across a tier, and mixing the two would leave
## a row that cannot say which rule refused it.
##
## Land is `.`, water is `~`. The two squeezes are hand-placed and the coordinates are named where
## they are used:
##  · **both shoulders blocked** — (2,1) to (3,2), with (3,1) and (2,2) both water
##  · **one shoulder blocked** — (1,2) to (2,1), with (2,2) water and (1,1) land
const SQUEEZE_ROWS := [
	"~~~~~~",
	"~..~.~",
	"~.~..~",
	"~....~",
	"~~~~~~",
]
const SQUEEZE_W := 6

## The same board with the door bricked up — the stair character replaced by low ground. **Not
## generated from the one above by string surgery**: a mutation written as a replacement has silently
## matched zero times in this repo twice, and a fixture that quietly stayed identical would make the
## sharpest row here green for no reason.
const FIXTURE_TIERS_NO_STAIR := [
	".........",
	".....222.",
	".....222.",
	".....222.",
	".....222.",
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

## ⚠⚠ **`SEALED_ROWS`, `SEALED_TIERS` AND `SEALED_LANDINGS` ARE DELETED WITH THEIR FUNCTION** (02-08,
## 2026-09-01, the user choosing deletion over repair: 「3번 빼고 진행」). Their board was never reached:
## it wrote its defender as `S`, the shieldbearer, and `Islands.SPAWN_ROWS` binds only `W`, so the
## function died on an empty spawn list. **Repairing the letter is what showed the fixture could not be
## repaired**: `SEALED_LANDINGS` (26) was hand-derived from a `_is_landing` that tested adjacency to
## water, and the predicate was re-aimed on 2026-08-29 to mean 「could a body be stood here at all」.
## Under it a plateau 조각 IS a landing, so the fixture's own design sentence — 「the plateau is inland
## so that no landing tile is on it」 — is false and **one constant can no longer serve both rows**.
## ⇒ Repaired it would be a net whose comment says one thing and whose numbers measure another, which
## is the shape `how-nets-lie` collects.
##
## **What stopped being measured**: 「the reachability check can actually fail」 — that a defender sealed
## on a stairless plateau is reported unreachable from every landing. ⚠⚠ **Nothing else in the repo
## asserts it**, and the helper that made the claim went with the board — see where it stood.

## The island `Rules.MAP_NODES[0]` opens — the first fight of every run, and the only island with a
## tier board today.
const FIRST_ISLAND := 4

## ⚠⚠ **THE FIVE ISLAND LITERALS THAT STOOD HERE ARE DELETED** (02-08, 2026-09-01, the user:
## 「about the stale tests — I asked you to delete them, not fit them to the current island」). They were
## hand-derived off a drawing that is three islands ago, and **not one of them could be re-derived and
## left alone**: task 06 widens the island again.
##
## **What stopped being measured, one line each:**
##  · `ISLAND_HIGH` (16) — how much plateau the island has. It loads 48
##  · `ISLAND_STAIR` (1) — how many doors lead onto it. It loads 4
##  · `ISLAND_LANDINGS` (68) — how much of the shore a boat may beach on. It loads 280
##  · `ISLAND_ENEMIES` (6) / `ISLAND_ENEMIES_HIGH` (3) — that the island stands beasts on its own
##    plateau, so the plateau teaches something. **The board carries no spawn character at all now**
##    and the beasts arrive by boat
## ⚠ **`FIRST_ISLAND` stays**: nothing reads it as a count.

const WALKER_ID := 777_001


func run(t) -> void:
	_an_empty_tier_board_is_flat(t)
	_a_short_tier_board_is_flat_where_it_ends(t)
	_the_climb_rule_itself(t)
	_the_feet_land_on_the_treads(t)
	_a_corner_stair_picks_one_mouth_and_keeps_it(t)
	_a_stair_is_entered_at_its_ends_only(t)
	_a_diagonal_needs_both_shoulders(t)
	_the_walker_will_not_cut_a_corner(t)
	_the_real_island_still_has_a_route(t)
	_the_field_climbs_only_by_the_stair(t)
	_bricking_up_the_stair_seals_the_plateau(t)
	# ⚠⚠ **「밀려도 층이 안 바뀐다」 IS A LIVE USER DECISION WHOSE MECHANISM WAS DELETED 2026-08-27.**
	# 티켓 19, the user's own words: ***"높은 데서 밀리면 안 떨어져. 안 떨어지는 걸로."*** This row
	# measured it, and measured each direction against its own FLAT control on the same board — because
	# 「the enemy did not move」 is equally true of a shove that is simply broken, and this file has a
	# written case of exactly that shape passing.
	# ⇒ **`Rules.SPECIES_SHOVE` emptied on 2026-08-26 and was deleted on 2026-08-27**, so there is no
	# longer anything in the game that moves a body without it walking. **The decision outlives the
	# code**: the day one is built, this row and its flat controls come back before it ships.
	_a_landing_never_puts_a_body_on_the_plateau(t)
	_the_first_island_carries_a_real_plateau(t)
	# ⚠⚠ **`_the_reach_check_can_actually_fail` IS DELETED** (02-08) — see the block where
	# `SEALED_ROWS` stood for why it could not be repaired instead.
	_no_tier_board_is_a_different_shape_from_its_island(t)
	_an_island_number_is_loaded_through_one_door(t)


# == the datum ========================================================================================
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies
	# half way still reports every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


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
	g.load_rows(FIXTURE_ROWS, ["..2"])
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


## ⚠⚠ **WHERE A BODY'S FEET REST ON A STAIR, AND NOTHING MEASURED IT UNTIL 2026-08-28.** `surface_h`
## had **no reader in any net at all**, which is how it came to disagree with the mesh it is supposed
## to trace: it returned a straight RAMP while `island_build.py` cut `Rules.STAIR_TREADS` steps into
## the 칸. A body walked the average of the steps — into every tread, over every riser — and the user
## saw it: 「계단을 캐릭이 뚫고감 이건 근본적인문제인데 왜그럴까?」
##
## ⚠ **This measures the STEP, not the ramp.** Every height on a stair has to be a whole number of
## treads above the floor below it; a returned value between two treads is the defect this row exists
## for, and it is what a mutation back to `(i + f) / n` produces on the first sample.
##
## ⚠ **It is a VIEW height and this net drives the SIM** — that is allowed and is the point: the
## function lives in `Grid` so one arithmetic serves the bake and the picture, and `Grid` is the seam
## a net may drive with `.new()`.
## ⚠⚠ **IT USES ITS OWN BOARD BECAUSE `FIXTURE_TIERS` WAS BROKEN, AND THAT IS NOW HISTORY.**
## **The record worth keeping**: `1` meant level 2 when the fixtures here were written, and has meant
## **level 1** since `TIER_CHARS` was widened on 2026-08-26 — so every board still spelling its plateau
## `1` had its plateau and its stair at the SAME level, built no run at all, and left seventeen of this
## file's rows red for five days. **02-08 was the round that re-read them** and they are all `2` today.
## ⇒ **The reason this board stands apart is spent.** `TREAD_ROWS` and `TREAD_TIERS` are now character
## for character what `FIXTURE_ROWS` and `FIXTURE_TIERS` hold, and **one of the two pairs should go** —
## 02-08 was told not to touch this one, so it is left for whoever folds them.
## ⚠ Here `2` is the plateau and `/` is the stair, which is what the legend says today.
const TREAD_ROWS := [
	"~~~~~~~~~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~.......~",
	"~~~~~~~~~",
]
const TREAD_TIERS := [
	".........",
	".....222.",
	".....222.",
	"..../222.",
	".....222.",
	".........",
]

func _the_feet_land_on_the_treads(t) -> void:
	var g := Grid.new()
	g.load_rows(TREAD_ROWS, TREAD_TIERS)
	var stair := g.tile_index(4, 3)
	t.eq(g.level_of(stair), 1, "계단 조각을 잡았다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(5, 3)), 2, "그 옆이 2층이다 (자가 점검 — 눈금표가 오늘 뜻으로 읽혔다)")
	t.ok(not g.stair_run_of(stair).is_empty(), "그리고 그것이 계단 런에 속한다 (자가 점검)")

	# Flat ground: the drawn height and the rule height are the same number. Without this row every
	# claim below is equally true of a function that returns garbage everywhere.
	var flat := Vector2(2.0, 1.0)
	t.ok(absf(g.surface_h(flat) - g.height_at(flat)) < 0.001,
		"평지에서는 발 높이가 규칙 높이와 같다 (자가 점검)")

	# ⚠⚠ **THE ROW.** Walk the stair from its downhill edge to its uphill edge and every height must
	# sit on a tread — a whole number of risers above the floor the run starts from.
	var run: Array = g.stair_run_of(stair)
	var floor_h := float(g.level_of(stair) - 1) * Rules.TIER_STEP_TILES
	var riser := 2.0 * Rules.TIER_STEP_TILES / float(Rules.STAIR_TREADS)
	var off := 0
	var seen := {}
	var last := -1e9
	var rose := 0
	for k in 21:
		var f := float(k) / 20.0 - 0.5
		var p := Vector2(4.0 + f * float(int(run[0].x)), 3.0 + f * float(int(run[0].y)))
		var hgt := g.surface_h(p)
		var steps := (hgt - floor_h) / riser
		if absf(steps - round(steps)) > 0.001:
			off += 1
		seen[int(round(steps))] = true
		if hgt > last + 0.001:
			rose += 1
		last = hgt
	t.eq(off, 0, "계단 위 스물한 지점의 발 높이가 전부 단 위다 — 단 사이에 뜨거나 잠긴 곳이 없다")
	# The floor under that zero: a function returning ONE constant would also have 0 off-tread samples.
	t.ok(seen.size() >= 3, "그 사이에 서로 다른 단이 셋 이상 나왔다 (%d) — 한 높이만 돌려주는 게 아니다"
		% seen.size())
	t.ok(rose >= 3, "그리고 올라가면서 높이가 실제로 올랐다 (%d번)" % rose)

	# ⚠ **Neither end escapes the storey the stair joins.** A tread index past the last one lifts the
	# body a whole riser above the floor it is stepping onto — the `min` in `surface_h` is what stops
	# it, and this is the row that bites if it goes.
	var top := floor_h + 2.0 * Rules.TIER_STEP_TILES
	for k2 in 9:
		var f2 := float(k2) / 8.0 - 0.5
		var p2 := Vector2(4.0 + f2 * float(int(run[0].x)), 3.0 + f2 * float(int(run[0].y)))
		var h2 := g.surface_h(p2)
		t.ok(h2 > floor_h - 0.001 and h2 < top + 0.001,
			"계단 위 발 높이가 아래층과 위층 사이에 있다 (%.3f, %.3f~%.3f)" % [h2, floor_h, top])


## ⚠⚠ **A CORNER STAIR MEETS THE FLOOR ON TWO SIDES, AND WHICH ONE WINS DECIDES WHICH WAY THE BODY
## CLIMBS** (2026-08-28, the user: 「계단 이동할때 뚫는거 같은데」). The island's own stair is exactly
## that shape — floor to the west AND to the south, plateau to the east and north — and the two files
## that have to agree about it picked differently: `island_build.py` cut the staircase climbing
## west-to-east, `_build_runs` kept whichever mouth its loops found last and answered south-to-north.
## **A body then walked ACROSS the treads instead of up them**, which is what 「뚫는다」 looks like.
##
## ⚠ **The order itself is arbitrary and the agreement is not.** `Grid.STAIR_MOUTH_ORDER` puts west
## first, and the bake walked the same four sides and kept the FIRST hit. This row pins the sim's half.
## ⚠⚠ **THE OTHER HALF IS NO LONGER CODE** (2026-09-03). The bake was a Python file until 2026-08-31,
## when it was deleted in favour of the `.blend` originals — so **what this row has to agree with is now
## the way the staircase is actually CUT in `blend/island.blend`, and nothing can diff that but an eye.**
## `docs/manual/blender.md` carries the pair as a table.
##
## ⚠ Mutation: keep the LAST mouth instead of the first, or drop the lowest-tile tie-break, and the
## axis flips on this board.
func _a_corner_stair_picks_one_mouth_and_keeps_it(t) -> void:
	# Floor to the west and to the south, plateau to the east and north — the island's own shape.
	var rows := ["~~~~~~~", "~.....~", "~.....~", "~.....~", "~.....~", "~~~~~~~"]
	var tiers := [".......", "...222.", "...222.", "../222.", ".......", "......."]
	var g := Grid.new()
	g.load_rows(rows, tiers)
	var st := g.tile_index(2, 3)
	t.eq(g.level_of(st), 1, "계단 조각을 잡았다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(1, 3)), 0, "서쪽이 1층이다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(2, 4)), 0, "남쪽도 1층이다 — 모서리 계단이다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(3, 3)), 2, "동쪽이 2층이다 (자가 점검)")

	var run: Array = g.stair_run_of(st)
	t.ok(not run.is_empty(), "계단 런이 만들어졌다")
	if run.is_empty():
		return
	t.eq(run[0], Vector2i(1, 0),
		"그리고 오르는 축이 서쪽 입에서 동쪽으로다 — STAIR_MOUTH_ORDER 가 서쪽을 먼저 고른다")

	# ⚠ **The same board, built twice, must answer the same axis.** `_build_runs` walks its group off a
	# stack; without the lowest-tile tie-break, which tile came last — and therefore which side won —
	# was not stable between two runs on identical rows.
	var g2 := Grid.new()
	g2.load_rows(rows, tiers)
	t.eq(g2.stair_run_of(st), run, "같은 판을 두 번 읽으면 같은 축이 나온다 — 순회 순서에 안 기댄다")

	# And the feet climb ALONG that axis: west edge low, east edge high.
	var west := g.surface_h(Vector2(1.5, 3.0))
	var east := g.surface_h(Vector2(2.5, 3.0))
	t.ok(east > west + 0.05,
		"그 축을 따라 발 높이가 실제로 오른다 (%.3f -> %.3f)" % [west, east])


## ⚠⚠ **A BODY WALKED UP THE STAIRCASE'S FLANK** (2026-08-28, the user: 「계단 옆면으로 오르는게 살짝
## 마음에 안드네?」). A stair carries an ODD notch, so it is within `MAX_CLIMB_LEVELS` of the floor on
## every side — and a body stepping onto it sideways skipped the treads entirely and climbed the wall
## of the staircase. **The mesh already presents a solid flank there; the rule did not agree with it.**
##
## ⚠ **Along the run's axis is the whole test.** Sideways is refused, along is allowed, and a DIAGONAL
## that keeps an axis component is allowed — its own shoulders are what decide it after that.
## ⚠ **Stair-to-stair stays free**, so a two-wide staircase is one staircase and two bodies can shuffle
## across it.
##
## ⚠ Mutation: return `true` from `_stair_face_open` and the sideways rows below go green.
func _a_stair_is_entered_at_its_ends_only(t) -> void:
	# ⚠ **The corner board, not `TREAD_TIERS`** — this needs floor on BOTH flanks of the stair, which is
	# where a body was climbing the staircase's wall. `TREAD_TIERS` wraps its stair in plateau.
	var g := Grid.new()
	g.load_rows(["~~~~~~~", "~.....~", "~.....~", "~.....~", "~.....~", "~~~~~~~"],
		[".......", "...222.", "...222.", "../222.", ".......", "......."])
	# The stair is (2,3); it climbs west-to-east, so (1,3) is its mouth and (3,3) its head.
	var st := g.tile_index(2, 3)
	t.eq(g.level_of(st), 1, "계단 조각을 잡았다 (자가 점검)")
	t.ok(not g.stair_run_of(st).is_empty(), "계단 런이 만들어졌다 (자가 점검)")
	t.eq(g.stair_run_of(st)[0], Vector2i(1, 0), "이 계단은 서에서 동으로 오른다 (자가 점검)")

	# Along the axis: both ends stay open, or the stair stops being a door at all.
	t.ok(g.can_step(g.tile_index(1, 3), st), "서쪽 입으로는 들어간다")
	t.ok(g.can_step(st, g.tile_index(1, 3)), "그리고 도로 나온다")
	t.ok(g.can_step(st, g.tile_index(3, 3)), "동쪽 머리로 올라간다")
	t.ok(g.can_step(g.tile_index(3, 3), st), "그리고 내려온다")

	# ⚠ **The row.** Both flanks are floor one notch below — inside the climb rule, and refused anyway
	# because they are the staircase's sides.
	t.eq(g.level_of(g.tile_index(2, 2)), 0, "계단 북쪽은 1층이다 (자가 점검)")
	t.eq(g.level_of(g.tile_index(2, 4)), 0, "계단 남쪽도 1층이다 (자가 점검)")
	t.ok(not g.can_step(g.tile_index(2, 4), st), "남쪽 옆면으로는 계단에 못 올라탄다")
	t.ok(not g.can_step(st, g.tile_index(2, 4)), "계단에서 옆으로 내려서지도 못한다")
	t.ok(not g.can_step(g.tile_index(2, 2), st), "북쪽 옆면으로도 못 들어온다")

	# A wide stair has to stay one staircase: two tiles at the same step, side by side.
	var wide := Grid.new()
	wide.load_rows(["~~~~~~~", "~.....~", "~.....~", "~.....~", "~.....~", "~~~~~~~"],
		[".......", "...222.", "../222.", "../222.", "...222.", "......."])
	var a := wide.tile_index(2, 2)
	var b2 := wide.tile_index(2, 3)
	t.eq(wide.level_of(a), 1, "넓은 계단의 두 조각이 다 계단이다 (자가 점검)")
	t.eq(wide.level_of(b2), 1, "둘째 조각도 계단이다 (자가 점검)")
	t.ok(wide.can_step(a, b2), "같은 계단 안에서는 옆으로 움직인다 — 두 몸이 나란히 오른다")


## ⚠⚠ **A DIAGONAL NEEDS BOTH SHOULDERS, AND THE LAND HALF DID NOT HAVE THIS RULE UNTIL 2026-08-28**
## (티켓 19; the user, on the game screen: 「이동할때 그냥 벽을 뚫는 문제도 있는상태」). Two blocked
## tiles touching corner to corner were one step apart, so a body walked straight through the seam.
##
## ⚠⚠ **BOTH shoulders and not 「both blocked」, and that is the decision this row pins.** The ticket
## asked for the weaker rule — refuse only when BOTH shoulders are blocked — and the stronger one is
## taken because **a body moves continuously**: `Battle._walk` slides it from tile centre to tile
## centre, so on a diagonal it is physically over the shoulder tiles on the way. `_straight_is_all_water`
## one file over requires both shoulders for exactly this reason and says so in its own header.
## ⇒ **Nothing is cut off by it**: a refused diagonal is still two orthogonal steps, and
## `_the_real_island_still_has_a_route` is the floor that proves the island did not seal itself.
##
## ⚠ **Flat board on purpose.** The height rule already refuses a diagonal across a tier, so a tiered
## fixture could not say which of the two rules did the refusing.
##
## ⚠ Mutation: drop either shoulder test and its own row goes green-to-red on its own.
func _a_diagonal_needs_both_shoulders(t) -> void:
	var g := Grid.new()
	g.load_rows(SQUEEZE_ROWS)
	var here := g.tile_index(2, 1)
	var across := g.tile_index(3, 2)
	# The self-check first: the two ENDS are walkable and the two shoulders are not. Without this the
	# refusals below are equally true of a board where nothing is walkable at all.
	t.ok(g.is_passable(2, 1) and g.is_passable(3, 2), "대각선 양 끝이 걸을 수 있는 조각이다 (자가 점검)")
	t.ok(not g.is_passable(3, 1) and not g.is_passable(2, 2), "그리고 어깨 둘 다 막혀 있다 (자가 점검)")
	t.ok(not g.can_step(here, across), "양 어깨가 막힌 대각선은 못 지나간다 — 벽 모서리를 안 뚫는다")
	t.ok(not g.can_step(across, here), "반대 방향으로도 못 지나간다 — 한쪽만 막는 문이 아니다")

	# One shoulder open is still refused, and this is the row the ticket's weaker rule would have left
	# green. (1,2) -> (2,1): (2,2) is water, (1,1) is land.
	var low := g.tile_index(1, 2)
	var up := g.tile_index(2, 1)
	t.ok(g.is_passable(1, 1) and not g.is_passable(2, 2), "어깨 하나만 막힌 자리를 잡았다 (자가 점검)")
	t.ok(not g.can_step(low, up), "어깨 하나만 막혀도 대각선은 거절이다 — 몸은 그 어깨 위를 실제로 지난다")

	# The control: a diagonal with BOTH shoulders open still walks. Without it every row above is
	# equally true of a `can_step` that refuses all eight diagonals.
	# (3,3) -> (4,2): the shoulders are (4,3) and (3,2), both land. ⚠ **(2,3) -> (3,2) is NOT the
	# control** and was tried first: its shoulder (2,2) is the very water this fixture is built around,
	# so it is refused for the right reason and says nothing about diagonals in general.
	t.ok(g.is_passable(4, 3) and g.is_passable(3, 2), "대조군의 어깨가 둘 다 열려 있다 (자가 점검)")
	t.ok(g.can_step(g.tile_index(3, 3), g.tile_index(4, 2)),
		"어깨가 둘 다 열린 대각선은 그대로 걸린다 (대조군 — 대각선을 전부 막은 게 아니다)")
	# And the orthogonal steps across the very same seam are untouched.
	t.ok(g.can_step(g.tile_index(3, 2), g.tile_index(4, 2)), "직교 걸음은 그대로다")
	t.ok(g.can_step(g.tile_index(1, 1), g.tile_index(1, 2)), "세로 직교도 그대로다")


## **The rule reaching the WALKER, and not only the predicate.** `flow_field` and `step_toward` both
## ask `can_step`, so one function carries it to both — but a check on the predicate alone would stay
## green if either caller grew its own copy of the neighbour walk.
##
## ⚠ The field is built from the far side of the squeeze and the body is put on the near side: if the
## corner were still cuttable the descent would take the diagonal in one step.
func _the_walker_will_not_cut_a_corner(t) -> void:
	var g := Grid.new()
	g.load_rows(SQUEEZE_ROWS)
	var goal := g.tile_index(4, 1)
	var field := g.flow_field(goal)
	var start := g.tile_index(2, 1)
	t.ok(int(field[start]) != Grid.UNREACHABLE, "막힌 모서리를 돌아가는 길이 있다 (자가 점검)")
	# ⚠ **The COST is what says it went AROUND.** The straight-line diagonal shortcut is two diagonal
	# steps ((2,1)->(3,2)->(4,1)); refused, the walk has to drop to (2,3)... and back up, which is dearer.
	# ⚠⚠ **It was `> 2` while a step cost one hop** (before 티켓 37). The claim is unchanged — the unit is
	# not — and a literal 2 here would silently become 「dearer than a fifth of one diagonal」.
	t.ok(int(field[start]) > 2 * Rules.STEP_COST_DIAG,
		"그리고 그 길이 대각선 지름길보다 비싸다 (%d) — 모서리를 안 자른다" % int(field[start]))
	var step := g.step_toward(1, Vector2(2.0, 1.0), field)
	t.ok(step != Vector2(3.0, 2.0), "걸음도 그 대각선을 안 고른다")
	t.ok(step != Vector2(2.0, 1.0), "그렇다고 선 채로 멈추지도 않는다 — 갈 데가 있다 (%s)" % str(step))


## ⚠⚠ **THE FLOOR UNDER THE WHOLE RULE: the real island did not seal itself.** A stricter step rule
## can turn a working board into one where a body cannot reach anything, and every row above would
## still be green. **This walks the actual island** — the one the game loads — and asks that every
## walkable tile is still reachable from the tile the roster stands on.
##
## ⚠ It compares against the SAME field before and after by construction: `flow_field` is the only
## thing asked, so a rule that cut the island in two shows up as unreachable land.
func _the_real_island_still_has_a_route(t) -> void:
	var g := Grid.new()
	g.load_rows(Islands.rows(), Islands.tiers())
	var from := -1
	for tile in g.passable.size():
		if g.passable[tile] != 0:
			from = tile
			break
	t.ok(from >= 0, "섬에 걸을 수 있는 조각이 있다 (자가 점검)")
	var walkable := 0
	for tile in g.passable.size():
		if g.passable[tile] != 0:
			walkable += 1
	t.ok(walkable > 50, "섬에 걸을 수 있는 조각이 %d 개다 (자가 점검 — 빈 섬을 재고 있지 않다)" % walkable)
	# ⚠⚠ **THE FLOOR ROW ITSELF IS DELETED, AND THE `flow_field` CALL WITH IT** (02-08, 2026-09-01,
	# the user: 「about the stale tests — I asked you to delete them, not fit them to the current
	# island」). It asked that no walkable 조각 be cut off from the first one, and **the island has a
	# satellite 2x2 block that nothing walks to** — 설계 31 settled that block is the island rather
	# than a defect, and GLOSSARY.md says the 철광석 on it cannot be reached.
	# ⚠⚠ **What stopped being measured is this function's whole subject**: a stricter step rule that
	# seals the real island now shows up nowhere. The header's own warning — 「every row above would
	# still be green」 — is true of this file again, and the count above is all that is left.


# == the field ========================================================================================

## **The cheapest an 8-connected walk between two 조각 can cost**, in the flow field's own units. Derived
## and never typed: such a walk takes exactly `min(|dx|,|dy|)` diagonal steps and the rest orthogonal, so
## the two `Rules` constants are the whole of it. ⚠ It is what lets this file state a claim about a route
## without a single number read off a run.
static func _octile(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := absi(bx - ax)
	var dy := absi(by - ay)
	return Rules.STEP_COST_ORTHO * maxi(dx, dy) + (Rules.STEP_COST_DIAG - Rules.STEP_COST_ORTHO) * mini(dx, dy)

## **The flow field is where "walk to the stair" has to come out**, and the pair of measurements is
## what makes it a claim about height. The high tile (5,1) sits one tile east of the low tile (4,1):
##
##   · flat board — cost(5,1) is exactly cost(4,1) + 1. It walked straight over
##   · tier board — cost(5,1) is 5 against cost(4,1) of 3, so it did NOT walk straight over, and the
##     cheapest tile on the whole plateau costs exactly one more than the stair does
##
## **Mutation**: make `can_step` return `passable[to_tile] != 0` and the tiered numbers collapse onto
## the flat ones.
##
## ⚠⚠ **EVERY NUMBER HERE WAS A HOP COUNT AND IS NOW A COST** (티켓 37). A step stopped costing 1 the day
## a diagonal stopped being free, so every literal in this function had to be restated — **the claims are
## word for word what they were**, and each is written as `_octile(...)` against the fixture's own
## coordinates rather than as a number typed by hand or read off a run.
## ⚠ **THE ASSERTIONS HERE WERE RED FOR FIVE DAYS AND THE BOARD WAS WHY, NOT THE CLAIMS.**
## `FIXTURE_TIERS` spelled its plateau `1`, which has meant level **1** since the tier legend was
## widened — so the board held no level-2 조각 at all and no wall for the stair to be the door through.
## **02-08 corrected the letter and every one of them went green with its expected value untouched**,
## which is the evidence that the claims were right the whole time. ⚠ **The temptation that was refused
## is the record worth keeping**: turning one of them into an inequality so it passed would have been a
## green measuring nothing, and it would have hidden the board rather than fixing it.
func _the_field_climbs_only_by_the_stair(t) -> void:
	var flat := Grid.new()
	flat.load_rows(FIXTURE_ROWS)
	var seed := flat.tile_index(1, 1)
	var ff := flat.flow_field(seed)
	t.eq(int(ff[flat.tile_index(4, 1)]), _octile(1, 1, 4, 1), "평지 대조군 — (4,1) 은 곧장 세 걸음 값이다")
	t.eq(int(ff[flat.tile_index(5, 1)]), _octile(1, 1, 5, 1),
		"평지 대조군 — 그 옆 (5,1) 은 벽을 넘어 곧장 네 걸음 값이다")

	var g := Grid.new()
	g.load_rows(FIXTURE_ROWS, FIXTURE_TIERS)
	var tf := g.flow_field(g.tile_index(1, 1))
	t.eq(int(tf[g.tile_index(4, 1)]), _octile(1, 1, 4, 1), "층이 있어도 낮은 땅 (4,1) 은 그대로 곧장 온 값이다")
	# The claim, unchanged: (5,1) is not one step sideways from (4,1) — it is the seed's cost to the STAIR
	# plus the stair's own cost out to (5,1). Two legs, each the cheapest its two 조각 allow.
	t.eq(int(tf[g.tile_index(5, 1)]), _octile(1, 1, 4, 3) + _octile(4, 3, 5, 1),
		"그런데 벽 너머 (5,1) 은 계단을 돌아온 값이다 — 옆으로 한 걸음이 아니다")

	var stair_cost := int(tf[g.tile_index(4, 3)])
	t.eq(stair_cost, _octile(1, 1, 4, 3), "계단까지는 곧장 간 값이다")
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
	# One ORTHOGONAL step off the stair's head, which is the cheapest a plateau 조각 can be — the diagonal
	# neighbours of the same head cost more.
	t.eq(cheapest_high, stair_cost + Rules.STEP_COST_ORTHO,
		"그리고 고원에서 제일 싼 칸이 계단보다 정확히 직교 한 걸음 비싸다 — 문이 하나라는 것의 값")


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




# == the distance =====================================================================================

## **The two-pair board, and the pairing is what makes it a measurement.** Two pairs a plane tile
## apart sit on one island: one on the flat west end, one across the tier boundary at the east end.
## Everything else about them is identical, so the ONLY thing that can separate their answers is the
## height. ⚠⚠ **Without the flat pair, "the wolf did not bite" is equally explained by the pathfinder,
## by a targeting bug, or by the fixture being broken** — that is the exact shape that let 「무리가 한
## 덩어리로 움직인다」 pass on a board with one enemy on it.
##
## ⚠⚠ **The pairs sit 12 tiles apart, and the reason is now HISTORY — read this before closing the gap.**
## It was load-bearing against `Rules.pack_radius_of(WOLF)`, which was 6.0: two wolves any closer averaged
## into one seek point and each pair stopped being its own experiment. **무리사냥 is deleted (2026-08-27)
## and nothing reads across bodies any more**, so today the spacing does one smaller job — it keeps the
## two pairs from targeting into each other. ⇒ **The day anything cross-body lands again — formation,
## cohesion, a shared aim — this number is re-derived against ITS radius and never inherited from here.**
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
	"...............222..",
	"...............222..",
	"...............222..",
	"...............222..",
	"...............222..",
	"....................",
]
const PAIR_W := 20
## Plane 1 tile, two tiers of height: sqrt(1 + 2^2) = 2.2360679...
const ACROSS_THE_WALL := 2.2360679775








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
## ⚠⚠ **THIS SAID 「the enemy is a LION because its detect is the smallest on the table」 AND IT WAS
## STALE BEFORE THE LION WAS DELETED** (2026-08-31). `Rules.LION` appears nowhere in this file's code
## — the fixture below is built with an EMPTY enemy list, and **that emptiness is the whole of what
## keeps it a climb measurement.** Since 2026-09-02 (ticket 07-01) every row of `UNITS` carries a live
## detect radius — 검사 3.0, 늑대 6.0, read by `Battle._phase_targeting` — and a 늑대 walks at the
## 검사 it notices, so the day a body of the other side stands on this board the row measures a chase
## rather than the climb. ⚠ **The fixture is safe only while its enemy list stays empty**, which is
## why it stays green; it is not safe because detection is narrow, and it never was.
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
	"......222222..",
	"......222222..",
	"......222222..",
	"......222222..",
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
	"............222222..",
	"............222222..",
	"............222222..",
	"............222222..",
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
	".2222222.",
	".........",
	".........",
]
const CLIMB_ENEMY := Vector2(6, 3)
const CLIMB_START := [Vector2(5, 2), Vector2(5, 3), Vector2(5, 4)]








## --- 「무리는 제 몸이 선 자리에서 조준한다」 삭제됨 2026-08-27 ------------------------------------------
## ⚠⚠ **DELETED WITH `Rules.SPECIES_PACK`, `Rules.pack_radius_of` AND `Battle._seek_point_of`.** The row
## drove `b._seek_point_of(k)` directly on a board built so the pack's mean landed on a plateau tile
## **nobody was standing on** — wolves at (5,3), (5,4) and (8,3) average to (6, 3.33), which rounds to
## (6,3), level 2. The table it needed was looked up against the PLAYER's roster and the wolf has been an
## ENEMY since 2026-08-26, so **the function it called returned on its first line in every real fight.**
##
## ⚠⚠ **THE BUG IT CAUGHT IS STILL LIVE AS A SHAPE, AND IS RECORDED WHERE THE CODE IS.** `_dist` read
## `a`'s height off whatever tile `a` rounds onto, so **two wolves on the ground with one packmate on the
## plateau were all aiming from a tier up**, preferring the enemy above and walking into the wall. That
## is the whole reason `_nearest_enemy` ever took a separate `from_h`. **Both that argument and
## `_dist_from_height` are folded away now that every `from` is a place a body stands** — see the
## deletion blocks on `Battle._dist` and `Battle._nearest_enemy`. ⇒ **Anything that ever measures from a
## mean, a formation anchor or a cursor puts the height back, and does not let it be rounded off the
## ground.**
##
## ⚠ **AND THE FIXTURE SHAPE IS THE PART WORTH COPYING.** The claim was a PAIR read off ONE seek point:
## two enemies at almost the same distance from the mean, the low one nearer from the ground (2.54
## against 3.28) and the high one nearer from the plateau (2.61 against 3.23) — **same mean, three
## bodies, two answers.** Read the height off the mean instead and all three choose the same enemy, which
## is exactly the outcome the row existed to refuse. **A row that asserts ONE answer cannot tell a right
## answer from a stuck one.**


func _a_landing_never_puts_a_body_on_the_plateau(t) -> void:
	# ⚠⚠ **THE HALF THAT RAN ON THE LOADED ISLAND IS DELETED** (02-08): four rows and the `landing`
	# 조각 they all read, hand-picked as (22,2) back when the island was a rectangle. **On today's
	# island (22,2) is water**, so the self-check naming it a landing went red — and the three rows
	# under it kept passing anyway, because `_free_tiles_from` starting in the sea cheerfully hands
	# back ten land 조각 and none of them are high. **A row that passes from a 조각 nobody can stand
	# on measures nothing.** The `Grid` and the `Battle` built for them go with them.
	#
	# **What stopped being measured**: that a real landing 조각 on the loaded island hands back free
	# tiles and not one of them is on the plateau. ⚠ The two synthetic boards below still measure
	# both guards the search has, and they are the reason this function is kept.
	#
	# ⚠⚠ **NEITHER BOARD ALONE PROVES BOTH GUARDS, AND THAT WAS MEASURED.** The search has two: it
	# will not WALK across a wall, and it will not COLLECT a tile off the landing's own tier. For a
	# plateau tile either one is enough, so **deleting either alone reddened nothing.** Two boards
	# follow, each built so only one guard can answer.

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

	# ⚠⚠ **`ISLAND_HIGH` (16) AND `ISLAND_STAIR` (1) ARE DELETED** (02-08). The island loads 48 plateau
	# 조각 and 4 stairs. **What stopped being measured: how much high ground the island has and how many
	# doors lead onto it** — the two numbers the user's 「전략적인 요소」 condition is actually about.
	# ⚠ **The three rows below are kept and they carry no literal**: a stair or a plateau written over
	# a 조각 nobody can walk on, and a plateau touching the sea, are still refused.
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
	# ⚠⚠ **BOTH ENEMY ROWS ARE DELETED** (02-08). They said the island carries six beasts and three of
	# them stand on the plateau. **The island's letters are `H`, `~` and `.` only and it carries none** —
	# beasts arrive by boat, which is what task 02 built. **What stopped being measured: that the
	# plateau is not empty**, i.e. the island teaches by itself that high ground has to be climbed.
	# ⚠ That claim has no subject to be made against today, so nothing replaces it rather than a
	# green over an empty loop — this file's own header names that failure.

	# ⚠ The user's own condition on this island: 「전략적인 요소」. A stair a boat can be parked next to
	# is not a decision, so the door is asserted to be off the coast entirely.
	var stair_tile := -1
	for tile in g.level.size():
		if g.level_of(tile) == 1:
			stair_tile = tile
			break
	t.ok(stair_tile >= 0, "계단 칸을 찾았다 (자가 점검)")
	t.ok(not _is_landing(g, stair_tile), "계단 칸 자체는 상륙지가 아니다")
	# ⚠⚠ **THE EIGHT-NEIGHBOUR SWEEP AND ITS ROW ARE DELETED** (02-08): 「계단 옆 여덟 칸에도 상륙지가
	# 없다 — 문 앞에 바로 못 내린다」. The island carries 4 stairs now and there are landings beside the
	# one this loop found first.
	# ⚠⚠ **This is the deletion in this file with the largest cost, and it is a DESIGN claim rather
	# than a number.** It was the user's own condition on this island — 「전략적인 요소」, a stair a boat
	# can park beside is not a decision — and **nothing measures that the door onto the plateau is off
	# the coast any more.** ⚠ The row above still refuses a landing on the stair 조각 itself, which is
	# the weaker half: one 조각 instead of nine.


# ⚠⚠ **`_every_landing_reaches_every_enemy_on_the_first_island` IS DELETED WHOLE** (02-08),
#  and its header called it the check the plan calls MANDATORY. Its three rows were two reds and one
#  green that could not survive them: 「첫 섬의 상륽지는 68 칸이다」 (the island has 280),
#  「그리고 적은 6 이다」 (it has none), and `_unreachable_pairs(...) == 0` — which over zero
#  defenders is the empty loop its own comment called 「the emptiest green there is」.
#  ⚠⚠ **What stopped being measured**: that no defender is unreachable from a landing — i.e. that an
#  island cannot spin forever with the player stuck and every net green, because nothing here watches
#  a fight for a hundred simulated seconds. **The beasts arrive by boat now**, so the claim needs a
#  live fight rather than the island's letters, and no net in this file can make it.
#  ⚠ `_unreachable_pairs` itself is gone as well — see the block where it stood.


## ⚠⚠ **`_the_reach_check_can_actually_fail` IS DELETED WHOLE** (02-08). It was the inversion of the
## INSTRUMENT rather than of the subject: `_unreachable_pairs` returning a constant 0 would pass its
## neighbour forever, and this repo has shipped exactly that twice in one night. **The reason it goes
## rather than being repaired is written where its board stood.**
## ⚠ **`_spawns_of_rows`, `_landings_of` and `_unreachable_pairs` went with it** — see where they stood.


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
	# ⚠ **The floor was 20 and eight files were deleted on 2026-08-28** — the card screen, the refit
	# board, two of their tools and the three that drove the summon. It is the SELF-CHECK for the walk,
	# so it only has to be above 「the walk found nothing」.
	t.ok(scanned > 12, "src 와 tools 에서 .gd 를 %d 개 훑었다 (자가 점검)" % scanned)
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

## Whether ANY summon puts a body down on this tile. **The game's own rule, never a second definition
## here** — a copy is the one that rots.
##
## ⚠⚠ **IT ASKED THE HARBOURS UNTIL 2026-08-27.** It was `for hb in harbour_tiles: can_land_at(hb, tile)`
## — did any harbour's boat have permission to unload here. **The harbour system is deleted**, and the
## only thing that puts a body ashore now is a summon, so the question became: is this tile the landing
## of any legal summon press?
##
## ⚠ **The shape of the answer changed with it.** A harbour's permission table was a per-harbour SET of
## allowed beaches; a summon has exactly ONE landing per press. So a tile is a landing here iff some
## band tile beaches on it — which is why this walks the band rather than the harbours.
## ⚠⚠ **RE-AIMED 2026-08-29, and the subject narrowed with the code.** It asked whether some water
## tile in the summon band beached on `tile`; **the band and the beaching are deleted with the boats.**
## What is left of the question that this file actually uses is *「could a body be stood here at all」*,
## which is the same predicate `Battle.place_ashore` searches on.
func _is_landing(g: Grid, tile: int) -> bool:
	if tile < 0 or tile >= g.w * g.h:
		return false
	if g.passable[tile] == 0 or g.water[tile] != 0:
		return false
	return not Grid.is_stair_level(g.level_of(tile))


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
	b.setup(g, army, spawns)
	for k in at.size():
		_ashore(b, k, at[k])
	return b


func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	# ⚠⚠ **`Grid.hold` AND NOT A WRITE INTO `reserved`.** That array holds `Rules.TILE_CAPACITY` slots
	# per 조각 since 2026-08-30, so a raw `reserved[tile] = i` writes a slot of some other 조각 —
	# **silently**, and this fixture would stand bodies that hold nothing.
	b.grid.hold(i, b.grid.tile_index(int(round(p.x)), int(round(p.y))))


## Real seconds through the real `step`, a frame at a time. **Not one big `step(2.0)`** — the sim runs
## whole `Rules.SIM_SUBSTEP_SEC` passes and a single huge delta is a different discretisation from the
## one the game runs on.
func _step_for(b: Battle, seconds: float) -> void:
	var left := seconds
	while left > Rules.EPS:
		var dt: float = minf(left, 1.0 / 60.0)
		b.step(dt)
		left -= dt


## ⚠⚠ **`_spawns_of_rows`, `_landings_of` AND `_unreachable_pairs` ARE DELETED** (02-08). All three
## existed for `_the_reach_check_can_actually_fail` and went with it — **nothing else in the repo
## called any of them.** ⚠ `_unreachable_pairs` in particular was the one instrument here that had a
## board built to break it; with that board gone it was a measuring tool nothing measured, which is
## the same false-green shape this ticket was opened to remove.
