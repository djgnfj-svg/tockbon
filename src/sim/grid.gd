class_name Grid
extends RefCounted
## The island's tiles: passability, water, harbours, landing reach, per-unit tile reservation, and the
## BFS flow field every unit walks down. Pure data — no Node, no tree, `.new()` is the whole
## construction.
##
## **Movement is a flow field and never a greedy descent.** Greedy 8-way descent was measured stalling
## on five of twenty-six dock-to-enemy pairs on these three grids, so a walker that "obviously works"
## silently freezes on island 2's north-east crow and everything inside island 3's ring. The first-slice
## plan records the measurement under "What two adversarial passes broke".
##
## **The coastline is open, not docked, and landing is a DENYLIST.** `boat-and-landing`, section 3,
## replaced the old fixed-dock legend with harbours (`H`, plural, water tiles a boat sails from and
## returns to). `speed-off-open-landing` then replaced the permit list with the refusal list the user
## actually asked for: ***"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"***.
##
## ⚠⚠ **What the old rule cost, measured on all three shipped islands before it was replaced**: it
## refused **39% · 42% · 40%** of each island's own coastline, because `water_line_clear` sampled a
## STRAIGHT line from the harbour and any headland blocked it. That is what read as *the landing spots
## are fixed*. The replacement is a BFS over WATER — `_water_field` — so a boat sails AROUND the
## headland, and since all water on all three islands is one connected body (724 / 690 / 726 tiles,
## every one reachable from every harbour) **the refused set is now exactly `cliff + inland`, with
## nothing left over**. Sendable went 50 -> 84, 44 -> 76, 48 -> 82.
##
## ⚠ **A bigger number is not the same as the right set.** Merely dropping the coast-adjacency test
## would have given 97 / 83 / 94 — MORE tiles than the water route gives — by letting a boat land one
## tile INLAND while still refusing 40% of the actual shore. `speed-off-open-landing` 2.1 records the
## whole table; do not read that middle column as better.
##
## `can_land_at(harbour, tile)` is the one rule that decides where a boat may go, and
## `home_harbour_for` — which is `can_land_at` filtered and then nearest BY WATER ROUTE — is what
## `Battle.send` answers to, so the screen cannot promise a tile the sim refuses.


## Unreachable tiles carry this instead of a sentinel like -1, so a caller comparing field values with
## `<` treats them as the worst option rather than the best one.
const UNREACHABLE := 1 << 30

## Row legend. Anything not listed is loaded as an impassable hole: validating the legend is
## `net_islands`' job, and a `push_error` here would have to be forgiven by every net that hands this
## function a hand-written fixture.
##
## `.` land, `/` ramp (a doorway through a cliff wall — both walkable).
##
## ⚠⚠ **THE SPAWN LETTERS ARE NOT LISTED HERE ANY MORE, and that was two lists nobody kept in step.**
## This constant used to spell them out (`"./BCL"`) while `islands.gd` bound them to unit rows in a
## `match`, so a letter added to one and missed in the other was a body standing on an impassable
## hole with nothing barking. `land_chars()` appends `Islands.spawn_chars()` instead, which makes
## walkability a CONSEQUENCE of being a spawn letter rather than a second fact about it.
const BARE_LAND_CHARS := "./"
## `~` water, `H` harbour — a water tile a boat may sail from and return to.
const WATER_CHARS := "~H"
const HARBOUR_CHAR := "H"

## **The TIER legend — a second board of the same size as the terrain one, and not new terrain
## letters.** 티켓 19, decision 2: a "high ground" letter would need a high twin of every letter that
## can stand on it (`S` · `A` · `L` and every warrior still to come), so the table would square. A
## second board indexes the same tiles and leaves `BARE_LAND_CHARS` untouched — which is why every
## fixture in every net still measures exactly what it measured before.
##
## `.` low ground (level 0) · `/` stair (level 1) · `1` high ground (level 2).
##
## ⚠ **A third tier is levels 3 and 4 and needs no rule change** — only a row here and a colour. That
## is the whole of what decision 2 bought.
## ⚠ **An unlisted character loads as level 0**, matching what the terrain legend does with an unknown
## letter: barking here would have to be forgiven by every net handing this function a fixture, and
## validating the legend is `net_tiers`' job.
## ⚠⚠ **WIDENED 2026-08-26, and the reason is the stair** (the user: 「이점이 안전하고 그래서 농사
## 같은것도 빌드 건물들도 2층이 유리하지 대신 비싸지」). Three levels meant the plateau was ONE step up
## from a stair that was ONE step up from the ground, so the stair was a single knee-high ledge — and
## a plateau whose whole value is「only one way up」cannot afford for that way up to be invisible. With
## the level DIGITS reading as themselves, a stair can be as many treads as it needs.
## ⚠ **`/` still means level 1** so nothing that spells a stair the old way silently becomes ground.
## ⚠⚠ **BUT `1` NOW MEANS LEVEL 1, WHERE IT USED TO MEAN LEVEL 2.** Any fixture still written in the
## old three-character legend measures a different island than it did. **`net_tiers` is the one that
## has to be re-read**, and the nets are red already under the「measure them all once at the end」
## decision, so this is a known cost and not a silent one.
const TIER_CHARS := "./0123456789"
## `TIER_CHARS[k]` is level `TIER_LEVELS[k]`. Two arrays and not a dictionary, for the reason every
## flat table in this file is an Array: `const X := PackedInt32Array([...])` is a parse error on 4.7.
const TIER_LEVELS := [0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


## Every character a soldier may stand on: bare ground plus every letter that spawns a body.
static func land_chars() -> String:
	return BARE_LAND_CHARS + Islands.spawn_chars()

## 8-way, listed in a fixed order so an equal-cost tie always resolves the same way. Plain `const`
## Arrays: `const X := PackedInt32Array([...])` is a parse error on 4.7, so every read casts.
const NEIGHBOURS := [
	[-1, -1], [0, -1], [1, -1],
	[-1, 0], [1, 0],
	[-1, 1], [0, 1], [1, 1],
]

## ⚠ **`ORTHO` is deleted from this file.** It existed for `landable` — "a tile touching water only
## at a corner is not landable" — and `speed-off-open-landing` deleted that predicate whole: the
## denylist opens the 8-WAY coast, so a tile touching water at a corner IS landable now, and that is
## the difference between 82 and 84 tiles on island 0. Its one other reader was `field_view`'s
## cliff-face pass, which walks a cliff tile's seaward EDGES and genuinely needs the four sides; the
## four offsets moved into that file as its own private constant rather than dying.
##
## ⚠ **`Rules.LINE_SAMPLE_STEP` and `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV` are deleted too.** They
## tuned `water_line_clear`, which is gone, and a rule constant nobody reads rots silently.

var w: int = 0
var h: int = 0
var passable := PackedByteArray()      # w*h, 1 = walkable (includes a ramp)
var water := PackedByteArray()         # w*h, 1 = water (includes a harbour)
## w*h, the tier level of each tile. **Every height in this game is derived from this one integer** —
## see `Rules.TIER_STEP_TILES` and `TIER_CHARS` above.
##
## ⚠⚠ **`passable` is NOT folded into this and the two mean different things.** `passable` is still
## "may a body stand here"; whether a body may *cross between* two tiles it could both stand on is
## `can_step`. Folding the height into `passable` would make one byte answer two questions, and this
## repo has already paid for a name whose sense changed under it (티켓 15: four checks became shells
## when 소 and 까마귀 moved sides).
var level := PackedByteArray()
## The stair runs of this board, `tile -> [axis, index, length]`. ⚠ **Derived from `level` and cached,
## never loaded**: it is a restatement of the board, so a second source for it could disagree with the
## first. Built on the first ask rather than during `load_rows`, because most boards are flat and most
## nets never ask. See `_build_runs`.
var _runs := {}
var _runs_built := 0
## Every tile whose board character is `HARBOUR_CHAR`, in row-major order — the append order in
## `load_rows` IS the harbour index, so an index is stable and reproducible across runs.
##
## ⚠⚠ **NOTHING IN `src/` READS THIS ANY MORE and it is kept ON PURPOSE.** The whole harbour system
## that consumed it — the per-harbour water fields, the landing denylist, the routing and the start
## harbour — died with the drag that fed it (see the block below). What still reads it is the picture
## of what the BOARD SAYS: `net_islands`, `net_summon` and `net_tiers` each walk it to assert facts
## about the shipped rows (how many `H` characters an island has, and where). **It is the only record
## in the sim of where a harbour character sits**, so deleting it would delete the board's own text,
## not just the dead rule that used to read it.
var harbour_tiles := PackedInt32Array()

## ⚠⚠ **THE WHOLE HARBOUR SYSTEM IS DELETED FROM HERE AND THIS BLOCK IS ITS RECORD.** What stood here
## was `water_fields`, `sendable`, `start_harbour` and `water_field_builds`, and what killed all four
## was one thing: **the player used to DRAG a soldier onto a boat that departed from a harbour, and
## that drag was deleted.** `Battle.send` has had zero callers in `src/` ever since, so every table
## below it became a fact nobody asked. **Boats still exist — they are SUMMONED now** (`sea-summon`),
## and the summon field beneath this comment is the whole of what replaced these four.
##
## **What each one was, and the knowledge that outlives it:**
##
##  · `water_fields: Array` — one BFS over WATER tiles per harbour, hop count from that harbour,
##    `UNREACHABLE` where a hull could not get. **`summon_hops` is the same shape done once instead of
##    once per harbour**, which is exactly the saving the swap bought: a summon has no harbour, so
##    there is nothing to index a field under.
##
##  · `sendable: Array` of `PackedByteArray`, one per harbour — `sendable[hb][t] == 1` iff a boat at
##    `hb` could be sent to `t`. ⚠⚠ **It was a DENYLIST and that was the user's own line**: *"상륙
##    못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"*. The rule was *passable AND some 8-WAY
##    neighbour is water this harbour's field reached*, so what was left refused was only cliff
##    (impassable) and inland (no water neighbour at all). ⚠ **8-way and not 4-way, and the number is
##    the argument**: the ortho coast of island 0 is 82 tiles and the 8-way coast is 84 — two corner
##    beaches — and the user's 「어디든지」 is what put them in. **The predecessor `landable` (passable
##    AND some ORTHO neighbour is water) died for the same reason and must not come back.**
##    ⚠ **The coastal band the summon field seeds from is that same set**: measured 84 / 76 / 82 on
##    the three shipped islands, which is `sendable[hb]` for every harbour. So nothing was lost.
##
##  · `start_harbour: int` — the harbour whose NEAREST reachable coast tile was FARTHEST away (ties to
##    the lowest tile index, which row-major fill makes the lowest harbour index), -1 on an empty grid.
##    It picked where the player's army began. **Nothing chooses a starting harbour now**; the summon
##    band is a ring about the middle of the grid (`summon_centre`) and the player presses inside it.
##
##  · `water_field_builds: int` — every water BFS ever built, one per harbour per `load_rows`. It was
##    an instrument, and the guarantee it carried is ALIVE in its sibling: **`summon_field_builds`
##    below means the same thing about the one field that is left.** ⚠ It in turn replaced `line_tests`,
##    which counted the deleted straight-line sampler's calls and was the same guarantee about the
##    cheaper thing. ⚠⚠ **The trap it named is still live** — *do not fold a second BFS into a counter
##    to make a red go away, and do not raise a counter's expected value either.* Two facts, two
##    counters.
##
## ⚠⚠ **THE COST THAT FORCED THE CACHING IS UNCHANGED AND STILL APPLIES TO `summon_hops`.** These
## tables were filled ONCE inside `load_rows` and only ever read back, because computed live the ask
## was 1536 tiles x 3 harbours **a FRAME** — a BFS is more expensive than the line test it replaced,
## not less (plan 3.5). `field_view` asks `can_summon_at` once per visible tile per frame today, so a
## per-press BFS there would be the identical wall.

## The summon field, filled ONCE in `load_rows`. **A summon has no harbour** — there is nothing to look
## a summoned boat up under, which is why neither of these is indexed by one. See `sea-summon`.
##
## `summon_hops[t]` — hops of WATER travel from the coast, `UNREACHABLE` on land and on water no boat
## can reach the shore from. ⚠ **The seed layer is 1, never 0**: there is no origin tile here the way
## the deleted `water_route` had its harbour at 0. Every descent in this file tests `<= 1` for that
## reason, and reading it as a 0-seeded field walks one hop too far.
## `summon_landing[t]` — the LAND tile a boat born at `t` sails to, or -1. **Ties go to the LOWEST tile
## index** — the same tie-break the deleted `_entry_water_tile` and `home_harbour_for` used, and it is
## the whole of the determinism: flip the comparison and every landing on every island moves.
var summon_hops := PackedInt32Array()
var summon_landing := PackedInt32Array()

## One per `load_rows`. ⚠ **It had a SIBLING, `water_field_builds`, and the deletion block above holds
## what that one meant and the trap the two shared** — *two facts, two counters; never fold a second
## BFS into one counter to make a red go away.*
## A net asserts it is 1 after a load and still 1 after sixty `can_summon_at` / `summon_landing_of` /
## `summon_route` calls — `field_view` asks the first of those once per visible tile per FRAME while
## aiming, so a per-press BFS here would be the wall.
var summon_field_builds: int = 0

var reserved := PackedInt32Array()     # tile -> unit id, or -1

## unit id -> Array of tiles it currently holds. At most two: the tile it stands on and the tile it is
## walking into. This is only the fast path for releasing — `reserved` is the authority, which is why
## `release_all` rescans it in full instead of trusting this.
var _held := {}


## Loads one island's rows. Safe to call twice: every array is rebuilt, so a `Grid` reused across
## islands cannot inherit the previous island's reservations.
##
## ⚠⚠ **`tiers` DEFAULTS TO EMPTY AND EMPTY MEANS FLAT**, and that default is the whole reason this
## change did not move a single existing fixture. Every net that hands this function rows and nothing
## else gets an island at level 0 everywhere, where `can_step` is `passable` and nothing more — so the
## checks written before height existed keep measuring their own subject rather than quietly measuring
## a climb rule as well.
##
## A short `tiers` board, or a short row inside it, reads as level 0 there — the same silence the
## terrain loop keeps for a short row. **`net_tiers` is what asserts the two boards are the same
## shape**, per island, because two boards that disagree about their size is the one way a stair can
## end up somewhere nobody authored it.
func load_rows(rows: Array, tiers: Array = []) -> void:
	h = rows.size()
	w = 0
	if h > 0:
		w = String(rows[0]).length()
	var n := w * h
	passable = PackedByteArray()
	passable.resize(n)
	water = PackedByteArray()
	water.resize(n)
	level = PackedByteArray()
	level.resize(n)
	reserved = PackedInt32Array()
	reserved.resize(n)
	reserved.fill(-1)
	harbour_tiles = PackedInt32Array()
	_held = {}
	# `water_field_builds = 0` stood here beside its sibling and died with the harbour tables. See the
	# deletion block on `harbour_tiles`: **whatever is added here must be reset here**, because a `Grid`
	# is reused across islands and a counter carried over from the previous island is a number that
	# looks like a measurement and is not one.
	summon_field_builds = 0

	# Built once per load rather than per tile: the string is assembled from a table, and 1536 tiles
	# rebuilding it would be a walk of `SPAWN_ROWS` per tile for an answer that cannot change.
	_runs = {}
	_runs_built = 0
	var land := land_chars()
	for y in h:
		var row := String(rows[y])
		var tier_row := String(tiers[y]) if y < tiers.size() else ""
		for x in w:
			var t := y * w + x
			level[t] = _level_of_char(tier_row[x]) if x < tier_row.length() else 0
			if x >= row.length():
				passable[t] = 0
				water[t] = 0
				continue
			var c := row[x]
			passable[t] = 1 if land.find(c) != -1 else 0
			water[t] = 1 if WATER_CHARS.find(c) != -1 else 0
			# Append order IS harbour index, row-major — the same convention the deleted `dock_tiles`
			# used, so an index is stable and reproducible.
			if c == HARBOUR_CHAR:
				harbour_tiles.append(t)

	# ⚠⚠ **The summon field is the ONLY water field this island builds, and its position used to be
	# structural.** A per-harbour loop ran BELOW it — one `_water_field` BFS per harbour, then a
	# `sendable` denylist byte per tile, then `_derive_start_harbour` — and `_summon_field` was put
	# ABOVE it deliberately so that it *could not* read either table: reading `sendable` was exactly how
	# the harbour rule a summon does not have would have come back in through the back door.
	# ⚠ **That loop is deleted with the rest of the harbour system** (see the block on `harbour_tiles`),
	# so the guard is now vacuous — there is nothing left below to read. **The rule it enforced is
	# not**: whatever water field is added here later, `_summon_field` must stay independent of it, or
	# a summoned boat starts obeying a harbour again. Its own header repeats this.
	_summon_field()


## The level a tier character stands for, or 0 for a character the legend does not list.
static func _level_of_char(c: String) -> int:
	var k := TIER_CHARS.find(c)
	if k < 0:
		return 0
	return int(TIER_LEVELS[k])


## **Whether a level is a stair tread rather than a tier's own floor.** A stair is not a kind of tile —
## it is an ODD level, which is what makes a third tier cost nothing but two more rows in `TIER_CHARS`:
## level 3 would be the stair up to level 4 and this function would already know it.
## ⚠ Its one reader is the picture, which paints a stair its own colour. **Nothing about walking asks
## this** — `can_step` compares levels and never asks what a level means.
static func is_stair_level(lv: int) -> bool:
	return (lv % 2) == 1


## The tier level of a tile. **Off the grid answers 0** — the terrain mesh runs `WATER_MARGIN_TILES`
## wider than the island on every side, and the margin is the sea, which is the bottom of everything.
func level_at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return 0
	return int(level[ty * w + tx])


func level_of(t: int) -> int:
	if t < 0 or t >= level.size():
		return 0
	return int(level[t])


## **How high the ground is under a point, in TILES** — the one place a level becomes a height, so the
## walking rule and the reach rule cannot end up with two ideas of how tall a tier is.
##
## `p` is in tile units with tile centres on integers, the same units `soldier_pos` and `step_toward`
## speak. ⚠ **It ROUNDS to the tile and does not interpolate**, and that is a decision rather than an
## omission: pathfinding is per tile, so a height that slid smoothly between tiles would have the two
## halves of the sim looking at different ground. **A body's height changes in one step as it crosses
## a tile line** — the reach test flips once at a stair mouth, which is intended, and whether that
## reads as a stutter is something only an eye can answer.
func height_at(p: Vector2) -> float:
	return float(level_at(int(round(p.x)), int(round(p.y)))) * Rules.TIER_STEP_TILES


## **Where a body's FEET actually rest, in tiles** — the same surface the Blender bake draws, including
## the slope up a stair.
##
## ⚠⚠ **THIS IS NOT `height_at` AND THE DIFFERENCE IS DELIBERATE.** `height_at` is the RULE height: one
## number per tile, what reach and target choice measure in, and it must stay per-tile or two machines
## running the same island could disagree. **This one is the DRAWN height**, and it slides across a
## stair because the mesh does. ⇒ **Only `src/view/` may call this**; nothing that decides an outcome
## may, or the rounding that keeps the sim reproducible would be quietly undone.
##
## ⚠ **A stair run spans exactly one storey however long it is**, so tile `i` of `n` carries the slice
## from `i/n` to `(i+1)/n` of the climb — the identical arithmetic `island_build.py` uses for the
## treads. **The treads themselves are not modelled here**: a body walking a real staircase steps up
## the line the treads average to, and drawing it on the nose would make the body bob.
func surface_h(p: Vector2) -> float:
	var tx := int(round(p.x))
	var ty := int(round(p.y))
	var t := tx + ty * w
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return 0.0
	var run: Array = stair_run_of(t)
	if run.is_empty():
		return float(level_of(t)) * Rules.TIER_STEP_TILES
	var ax: Vector2i = run[0]
	var i := int(run[1])
	var n := int(run[2])
	var floor_h := float(level_of(t) - 1) * Rules.TIER_STEP_TILES
	var storey := 2.0 * Rules.TIER_STEP_TILES
	# How far across this tile the body has walked, along the run: 0 at the downhill edge, 1 at the top.
	var f := (p.x - float(tx)) * float(ax.x) + (p.y - float(ty)) * float(ax.y) + 0.5
	f = clampf(f, 0.0, 1.0)
	return floor_h + storey * (float(i) + f) / float(n)


## The stair run a tile belongs to, as `[axis, index, length]`, or an empty array when the tile is not
## part of one. **Built once per board and cached**, because it is a fact about the board.
func stair_run_of(t: int) -> Array:
	if _runs_built == 0:
		_build_runs()
	return _runs.get(t, [])


## ⚠⚠ **A STAIR IS A GROUP OF TILES, NOT ONE TILE.** Cut into a plateau, a stair has the storey above
## it on three sides; strung two tiles long, the middle tile has no higher neighbour at all. So the
## MOUTH — the one tile of the group touching the storey below — is what gives the run its direction.
##
## ⚠ **Nothing about this is authored.** The board still says only `1`; the direction falls out of
## which side the ground is on. Dwarf Fortress reads its ramps the same way.
##
## ⚠ **A group that is not a filled RECTANGLE is dropped**, so a mis-drawn board makes the stair fall
## back to flat rather than producing a staircase that climbs through itself.
## ⚠⚠ **A BLOCK MAY BE MORE THAN ONE TILE WIDE, AND THE INDEX IS STILL ALONG THE CLIMB ONLY**
## (2026-08-27, the user: 「계단이라는 블록이 있어야할듯」). Two tiles side by side at the same step
## carry the same index and therefore the same height, which is what makes a wide stair one
## staircase rather than two beside each other. **`surface_h` needed no change for it.**
## ⚠⚠ **This mirrors `stair_runs()` in `tools/blender/island_build.py` and the two must agree** — one
## draws the surface and one says where the feet go. If you change the shape of a run in one, change it
## in the other in the same edit.
func _build_runs() -> void:
	_runs_built = 1
	_runs = {}
	var seen := {}
	for y in h:
		for x in w:
			var t := y * w + x
			var l := level_of(t)
			if l <= 0 or l % 2 == 0 or seen.has(t):
				continue
			var group: Array = []
			var stack: Array = [Vector2i(x, y)]
			var mark := {t: true}
			while stack.size() > 0:
				var pt: Vector2i = stack.pop_back()
				group.append(pt)
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var q: Vector2i = pt + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var qt := q.y * w + q.x
					if mark.has(qt) or level_of(qt) != l:
						continue
					mark[qt] = true
					stack.append(q)
			for k in mark.keys():
				seen[k] = true
			var mouth := Vector2i(-99, -99)
			var mouth_dir := Vector2i.ZERO
			var has_head := false
			for pt: Vector2i in group:
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var q: Vector2i = pt + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var nl := level_of(q.y * w + q.x)
					if nl == l - 1:
						mouth = pt
						mouth_dir = d
					elif nl == l + 1:
						has_head = true
			if mouth_dir == Vector2i.ZERO or not has_head:
				continue
			var ax := Vector2i(-mouth_dir.x, -mouth_dir.y)
			## The cross axis, 90 degrees from the climb — the same one `island_build.py` picks.
			var perp := Vector2i(-ax.y, ax.x)
			## Each tile's place in the block: `x` along the climb, `y` across it.
			var cells := {}
			var jmin := 1 << 30
			var imax := -(1 << 30)
			for pt: Vector2i in group:
				var d: Vector2i = pt - mouth
				var i := d.x * ax.x + d.y * ax.y
				var j := d.x * perp.x + d.y * perp.y
				cells[pt.y * w + pt.x] = Vector2i(i, j)
				if j < jmin:
					jmin = j
				if i > imax:
					imax = i
			var run_n := imax + 1
			var jmax := -(1 << 30)
			for tile in cells.keys():
				var c: Vector2i = cells[tile]
				c.y -= jmin
				cells[tile] = c
				if c.y > jmax:
					jmax = c.y
			var wide := jmax + 1
			# ⚠⚠ **A BLOCK HAS TO BE A FILLED RECTANGLE, AND THIS USED TO DEMAND A SINGLE FILE.** The old
			# test wanted the along-run indices to be exactly `0..n-1`, which a 2-wide stair cannot give —
			# it gives `0,0,1,1` — so the user's 「계단이라는 블록」 was dropped as malformed and every
			# body's feet fell back to the flat plateau height with nothing said. **What actually has to
			# hold is that every step of the climb is the same width.** A negative index is refused by the
			# same test, since the rectangle it is compared against starts at zero.
			var ok := run_n > 0 and wide > 0 and cells.size() == run_n * wide
			if ok:
				var want := {}
				for i in run_n:
					for j in wide:
						want[Vector2i(i, j)] = true
				for c in cells.values():
					if not want.has(c):
						ok = false
						break
			if not ok:
				continue
			for tile in cells.keys():
				_runs[tile] = [ax, int((cells[tile] as Vector2i).x), run_n]


## **Whether a body standing on `from_tile` may walk into `to_tile` — the stair rule, and the only
## place it is written.** The destination must be walkable, and the two levels must be within
## `Rules.MAX_CLIMB_LEVELS` of each other.
##
## ⚠⚠ **This is a NEW name and `passable` is untouched, deliberately.** `passable` used to answer "may
## a body go here" on its own, and the day height arrives that question splits in two. Widening
## `passable`'s meaning in place is exactly the shape that left four checks in 티켓 15 measuring
## nothing while still reading correctly, so the question that changed gets the new word.
##
## ⚠ **The ORIGIN's passability is deliberately not asked**, which is what both existing callers
## already did — they test `passable[nt]` and never `passable[t]`. It is load-bearing rather than lax:
## `flow_field` plants its seed on the target's tile *whatever its passability*, because a target
## still aboard a boat would otherwise give an all-unreachable field and freeze every unit chasing it
## for the rest of the island with nothing logged. Asking the origin here would put that freeze back.
##
## ⚠ **Symmetric in the levels.** `absi` and not a signed test: a wall a body may drop off but not
## climb is a one-way door, and 티켓 19's answer says bodies do not fall.
##
## ⚠ **It binds on DIAGONALS too**, which is what keeps a tier boundary from being cut at a corner —
## `flow_field` and `step_toward` walk all eight neighbours through here. That is a stronger guard
## than `_water_step_open` gives a boat, and it is stated rather than assumed: the note on
## `_water_step_open` says the LAND half still does not refuse a squeeze between two impassable
## corners, and that is unchanged. What this refuses is a HEIGHT gap, not a squeeze.
func can_step(from_tile: int, to_tile: int) -> bool:
	var n := w * h
	if from_tile < 0 or to_tile < 0 or from_tile >= n or to_tile >= n:
		return false
	if passable[to_tile] == 0:
		return false
	return absi(level_of(from_tile) - level_of(to_tile)) <= Rules.MAX_CLIMB_LEVELS


func is_passable(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return false
	return passable[ty * w + tx] != 0


func tile_point(t: int) -> Vector2:
	if w <= 0:
		return Vector2.ZERO
	return Vector2(t % w, t / w)


func tile_index(tx: int, ty: int) -> int:
	return ty * w + tx


## ⚠⚠ **`can_land_at` AND `_water_field` STOOD HERE AND BOTH ARE DELETED WITH THE HARBOUR SYSTEM.**
## Their tables are recorded in full on `harbour_tiles` above; what belongs *here* is the two things
## they knew that the surviving water code still depends on.
##
##  · **`can_land_at(harbour_idx, t)` never ran a BFS — it read the cached `sendable` byte and nothing
##    else**, which is what kept the build counter flat across a pumped frame. Recomputed per call at
##    1536 tiles a frame it would have been a real wall (plan 3.5), and *worse* than the straight-line
##    test it replaced rather than better. ⚠ **`can_summon_at` inherits that discipline exactly** — it
##    is a read of `summon_hops`, never a walk, and `field_view` calls it once per visible tile per
##    frame. **Do not put a traversal behind a predicate in this file.**
##
##  · **`_water_field(seed_tile)` was a DELIBERATE MIRROR of `flow_field` and not a call to it**: same
##    queue, same `UNREACHABLE` sentinel, same fixed `NEIGHBOURS` order, with `water[nt] == 0: continue`
##    in place of `passable[nt] == 0: continue`. ⚠⚠ **Sharing one function through a flag would put the
##    two traversals one typo apart, and a boat that walked the LAND field would sail over the island
##    with every check about reachability still green.** `_summon_field` below is the same mirror for
##    the same reason and must stay one. ⚠ **The mirror is NOT symmetric**: the water half honours
##    `_water_step_open` and `flow_field` has no such guard — see both of their notes.
##  · Its seed was planted on the harbour tile *whatever that tile's own contents*, exactly as
##    `flow_field` still plants its target: an all-unreachable field produces an island with no
##    landings at all and **nothing logged**, which is the failure shape this repo keeps paying for.


## Whether a boat may take the 8-way step `(fx, fy) -> (tx, ty)`. An ORTHOGONAL step always may; a
## DIAGONAL one needs at least one of its two SHOULDER tiles — `(tx, fy)` and `(fx, ty)` — to be water.
##
## ⚠⚠ **Without this a hull slips between two land corners that touch.** The water traversals walked
## `NEIGHBOURS` on the water byte alone, so water at (4,2) and water at (3,3) were one step apart with
## land on BOTH (4,3) and (3,2) — the boat crosses a seam that has no water in it. Reproduced on a
## fixture; **measured 0 occurrences on the three shipped grids**, so it was latent rather than
## visible, and a longer map is exactly where a seam like that turns up.
## ⚠ **It was found on the deleted harbour traversals (`_water_field`, `water_route`) and it is NOT
## about them** — `_summon_field` and `summon_route` walk water the same way and call this for the same
## reason. **Every 8-way water step in this file goes through here, and a new one must too.**
##
## ⚠ **`net_boat`'s water check cannot see this and never could.** It rounds the hull to a tile every
## sub-step, and along a squeeze that rounded tile is always one of the two water endpoints — a ceiling
## with no floor, one layer down. What catches it is `net_coast`, on a fixture whose two pools touch
## ONLY at a squeeze.
##
## ⚠ **`flow_field` and `step_toward` do NOT carry this rule**, and that is stated rather than assumed:
## a walking soldier can still cut a land diagonal between two impassable corners today. Fixing that is
## a movement change with its own measurements (queueing at necks, `_held`'s two-tile swap) and it is
## not this guard's business — but nobody should read this function as evidence that the land half
## already obeys it.
##
## Both shoulders are inside the grid by construction: each shares one coordinate with the start and
## one with the end, and both of those are range-checked by the caller before this is asked.
##
## ⚠⚠ **The BEACHING hop is deliberately not asked, and this survived the harbour deletion because it
## is still true of `summon_route`.** A route's last segment is water -> LAND by definition — the
## descent ends on a water tile and the caller appends the landing after it — so refusing that hop
## diagonally would refuse a corner beach for a reason that has nothing to do with a hull passing
## through anything. (The deleted `_entry_water_tile` picked that last water tile for a harbour route;
## `summon_landing` carries the same fact for a summoned one.)
func _water_step_open(fx: int, fy: int, tx: int, ty: int) -> bool:
	if fx == tx or fy == ty:
		return true
	return water[fy * w + tx] != 0 or water[ty * w + fx] != 0


## ⚠⚠ **`_entry_water_tile` AND `water_route` STOOD HERE AND BOTH DIED WITH THE HARBOUR.** `summon_route`
## below is their replacement in full, and these are the facts they carried that it still obeys:
##
##  · **`_entry_water_tile(field, t)`** picked the water tile a boat aimed at `t` actually stopped on —
##    the 8-neighbour of `t` that was water AND that the harbour's field had reached, cheapest first,
##    **-1 when none, and -1 WAS the refusal**. ⚠ **8-way and not 4-way**, which is the user's
##    「어디든지」: on island 0 that is exactly the two corner beaches between the ortho coast (82) and
##    the 8-way coast (84). `_summon_field`'s seed loop is the same 8-way reach written the other way
##    round — for each WATER tile, its passable 8-neighbours — and it must stay 8-way for this reason.
##    ⚠ Its tie-break was the LOWEST cost, strict `<`, so two runs on identical rows picked the same
##    approach; `summon_landing`'s lowest-tile-index tie-break is that same determinism rule.
##
##  · **`water_route(harbour_idx, landing)`** walked DOWN a harbour's hop field from the landing's entry
##    tile, one **strictly-lower** 8-way water neighbour at a time, then REVERSED so index 0 was the
##    harbour, then smoothed, then appended the landing. ⚠ `summon_route` is not reversed — it descends
##    from where the player pressed, which is already index 0 — and that is the one structural
##    difference between them.
##  · ⚠⚠ **The `<` and not `<=` is load-bearing and `summon_route` still carries it**: a walk that
##    accepts an equal-cost neighbour can sit between two of them forever. `step_toward` carries it too.
##  · ⚠⚠ **The descent terminates because BFS cost drops by exactly 1 a step, and it was guarded at
##    `w * h` ANYWAY.** Keep that guard in every descent added here: **a hung sim prints no verdict at
##    all**, and that is the failure shape that silently disarmed a whole net in this repo once.
##  · The LANDING was appended AFTER the smoother and was never inside the array it saw — it is LAND,
##    and a smoother that could see it would pull a straight line across the beach. `summon_route`
##    repeats the rule and `_smooth_water_path`'s own header states it.


## **The summonable band, and where a boat born in it sails to.** ONE multi-source BFS over water,
## built once per `load_rows`. `sea-summon` is the design.
##
## ⚠⚠ **The structural sentence, and it is now the only water field left: the deleted `water_route`
## picked the DESTINATION and derived the origin from a harbour; this picks the ORIGIN and derives the
## destination.** There is no harbour anywhere in it, and there is no longer one anywhere else either.
##
## **The seed layer.** A `coastal` tile is *passable AND touching water on any of eight sides*, and a
## seed is a water tile 8-adjacent to one. Written the other way round — for each WATER tile, its
## passable 8-neighbours — the two definitions are the same set exactly, because the water tile doing
## the asking IS the water neighbour that makes its passable neighbour coastal. That is why no
## `coastal` array is built here. ⚠⚠ **It is also the measurement that made the harbour deletion free:
## on all three shipped islands `coastal` is 84 / 76 / 82, which was `sendable[hb]` for EVERY harbour**
## — the harbour tables were computing a set this seed loop already produces, per harbour, every load.
##
## **The tie-break is the whole of the determinism.** A seed's landing is the LOWEST-INDEXED coastal
## neighbour, and within each BFS level the frontier is walked in ascending `(landing, tile)` order so
## a tile claimed at level k+1 takes the MINIMUM landing carried by any adjacent level-k tile. That is
## the min over all shortest paths, by induction on k — not "whatever the queue happened to do", which
## changes silently the day `NEIGHBOURS` is reordered. **It is the same tie-break the deleted
## `_entry_water_tile` and `home_harbour_for` used**, and it is now the only place it is written.
##
## ⚠ **`_water_step_open` is honoured here** — a boat may not squeeze a diagonal between two land
## corners — so the band cannot cross a seam a hull cannot. The deleted `_water_field` honoured it the
## same way, and `net_coast`'s squeeze fixture is what catches a traversal that stops.
## ⚠ **The beaching hop is deliberately not asked**: the seed-to-landing step is water -> land by
## definition, and refusing it diagonally would refuse a corner beach for a reason that has nothing to
## do with a hull passing through anything.
func _summon_field() -> void:
	summon_field_builds += 1
	var n := w * h
	summon_hops = PackedInt32Array()
	summon_hops.resize(n)
	summon_hops.fill(UNREACHABLE)
	summon_landing = PackedInt32Array()
	summon_landing.resize(n)
	summon_landing.fill(-1)
	if n <= 0:
		return

	var frontier: Array = []
	for t in n:
		if water[t] == 0:
			continue
		var tx := t % w
		var ty := t / w
		var best := -1
		for k in NEIGHBOURS.size():
			var nx := tx + int(NEIGHBOURS[k][0])
			var ny := ty + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if passable[nt] == 0:
				continue
			# **The lowest tile index wins.** `NEIGHBOURS` happens to visit in ascending index order
			# today, so this only ever fires on the first candidate — but the COMPARISON is what
			# decides the answer, not the visit order: flip it to `>` and every landing on every island
			# moves. The tie-break must not depend on a table that is free to be reordered.
			if best == -1 or nt < best:
				best = nt
		if best < 0:
			continue
		summon_hops[t] = 1
		summon_landing[t] = best
		frontier.append(t)

	var level := 1
	# Terminates: every pass claims at least one previously-`UNREACHABLE` tile or produces an empty
	# frontier, so it cannot run more than `n` times. The guard is here anyway — a hung sim prints no
	# verdict at all, and that is the shape that silently disarmed a whole net in this repo once.
	while not frontier.is_empty() and level <= n:
		frontier.sort_custom(_summon_frontier_before)
		var next: Array = []
		for raw in frontier:
			var t := int(raw)
			var tx := t % w
			var ty := t / w
			for k in NEIGHBOURS.size():
				var nx := tx + int(NEIGHBOURS[k][0])
				var ny := ty + int(NEIGHBOURS[k][1])
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nt := ny * w + nx
				if water[nt] == 0:
					continue
				if not _water_step_open(tx, ty, nx, ny):
					continue
				if summon_hops[nt] != UNREACHABLE:
					continue
				summon_hops[nt] = level + 1
				summon_landing[nt] = summon_landing[t]
				next.append(nt)
		frontier = next
		level += 1


## Ascending by landing, then by tile. **A strict weak ordering** — `sort_custom` is free to return
## anything at all for a comparator that is not one, and `army._hp_desc` carries the same note for the
## same reason.
func _summon_frontier_before(a: int, b: int) -> bool:
	if summon_landing[a] == summon_landing[b]:
		return a < b
	return summon_landing[a] < summon_landing[b]


## Whether a summon may be pressed on tile `t`: it is WATER, and it is inside the band.
##
## ⚠ **There is deliberately no third `summonable` byte array.** It would be a second copy of a fact
## `summon_hops` already holds, and a value counted in two places diverges. `field_view` asks this per
## visible tile per frame — ~2,400 calls against the 4,800 draw calls the same loop already makes.
## ⚠ It must answer `false` outside the grid: the terrain loop runs `WATER_MARGIN_TILES` tiles wider
## than the island.
##
## ⚠⚠ **THE `water[t] == 0` LINE IS REDUNDANT TODAY AND THAT WAS MEASURED, NOT ASSUMED.** Deleting it
## reddens nothing: `_summon_field` writes `summon_hops` on water tiles ONLY, so every land tile
## already carries `UNREACHABLE` and fails the range test one line down. It is kept as the explicit
## statement of the rule — the day somebody changes what the seed loop walks, this is the line that
## still refuses a boat on a beach — but **nobody may read `net_summon`'s 「육지 칸은 소환 지점이
## 아니다」 row as measuring it.** That row measures the invariant, and what bites a seed change is the
## band SIZE row beside it.
## ⚠⚠ **THE TEST INVERTED: it was `<= SUMMON_BAND_TILES` and is `>= SUMMON_BAND_MIN_TILES`.** The band
## used to hug the coast and now keeps away from it, on the user's own sentence — *"해안선에 배를
## 배치하는게 아니라 좀 거리를 둬야함 … 배가 가는게 중요하니까"*. See the constant for the sweep 4 was
## chosen from.
##
## ⚠ **`UNREACHABLE` is tested EXPLICITLY and that line is not padding any more.** Under the old `<=`
## an unreached tile failed by being enormous; under `>=` it would PASS — `UNREACHABLE` is `1 << 30`,
## which is greater than any distance. The sentinel that used to answer this question by accident now
## answers the opposite one, and dropping this line puts the whole open ocean, land-locked lakes
## included, inside the band.
func can_summon_at(t: int) -> bool:
	if t < 0 or t >= summon_hops.size():
		return false
	if water[t] == 0:
		return false
	if summon_hops[t] == UNREACHABLE:
		return false
	if summon_hops[t] < Rules.SUMMON_BAND_MIN_TILES:
		return false
	# ⚠⚠ **The outer edge.** See `Rules.SUMMON_RADIUS_TILES`: without it the band has a floor and no
	# ceiling, and the open ocean out to the edge of the map is all summonable. **The ring the field
	# draws is a circle about this same centre with this same radius** — the picture is not an
	# illustration of the rule, it is the rule's own two numbers.
	return summon_centre().distance_to(tile_point(t)) <= summon_radius()


## The middle of the grid, in tile units. **The one place the centre of the ring is decided**, so the
## predicate above and whatever draws the ring cannot disagree about where it is.
func summon_centre() -> Vector2:
	return Vector2(float(w) * 0.5, float(h) * 0.5)


## How far that ring reaches on THIS grid. See `Rules.SUMMON_RADIUS_RATIO` — it is a ratio of the map
## and not a fixed distance, because a 144-wide island and a 48-wide one do not share a circle.
func summon_radius() -> float:
	return Rules.summon_radius_of(w, h)


## The LAND tile a boat born at `t` sails to, or -1. Answered for any water tile the BFS reached, not
## only for the band — the band is `can_summon_at`'s question, and keeping the two apart is what lets
## a check assert that the band is a subset of what has a landing rather than assuming it.
func summon_landing_of(t: int) -> int:
	if t < 0 or t >= summon_landing.size():
		return -1
	return int(summon_landing[t])


## **The route a summoned boat sails**, the pressed tile at index 0 and the landing last, in TILE
## units. Empty when the press is refused, which is the same test `Battle.summon` refuses on, so the
## drawn line and the boat's own path are one call.
##
## ⚠ **It is NOT reversed, and the deleted `water_route` was.** That one descended from the landing to
## the harbour and had to turn round; this one descends from where the player pressed, which is already
## index 0. **Do not add a `reverse()` here by analogy with a route that no longer exists.**
##
## ⚠⚠ **The descent is restricted to neighbours carrying the SAME landing, and that is not defensive
## padding.** Without it the walk drifts onto a tile whose lex-min landing is a different beach, and
## the drawn line then ends somewhere the appended landing is not. `_summon_field` step 3 guarantees
## such a neighbour always exists: `summon_landing[t]` is the minimum over exactly those neighbours.
##
## ⚠ **The LANDING is appended AFTER `_smooth_water_path` and must never be inside the array it sees.**
## It is land, and a smoother that could see it would be free to pull a straight line across the beach
## — that function's own comment says so.
func summon_route(from_tile: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not can_summon_at(from_tile):
		return out
	var want := int(summon_landing[from_tile])
	if want < 0:
		return out
	var cur := from_tile
	var guard := 0
	var limit := w * h
	while true:
		out.append(tile_point(cur))
		# 1 is the seed layer — the tile the boat beaches from. There is no 0 here.
		if summon_hops[cur] <= 1:
			break
		guard += 1
		if guard > limit:
			break
		var cx := cur % w
		var cy := cur / w
		var step := -1
		var step_cost := int(summon_hops[cur])
		for k in NEIGHBOURS.size():
			var nx := cx + int(NEIGHBOURS[k][0])
			var ny := cy + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if water[nt] == 0:
				continue
			if not _water_step_open(cx, cy, nx, ny):
				continue
			if int(summon_landing[nt]) != want:
				continue
			# Strictly lower, so the walk cannot sit between two equal-cost tiles forever — the same
			# `<` (and not `<=`) `step_toward` carries, and the deleted `water_route` carried too.
			if summon_hops[nt] >= step_cost:
				continue
			step = nt
			step_cost = int(summon_hops[nt])
		if step < 0:
			break
		cur = step
	out = _smooth_water_path(out)
	out.append(tile_point(want))
	return out


## ⚠⚠ **A BFS FIELD GIVES A GRID PATH, NOT A ROUTE, AND THE DIFFERENCE IS WHAT A PLAYER SEES.**
## `summon_route` descends a HOP-COUNT field where a diagonal step and an orthogonal step both cost 1,
## so among the many equal-hop paths the fixed `NEIGHBOURS` tie-break picks one that hugs corners.
## ⚠ **The measurement below was taken on the deleted `water_route` and it is kept because the defect is
## a property of any hop-count descent, this one included** — it is not evidence about a harbour.
## Measured before this pass existed: island 1's bay mouth (24,17) is vertically open from the then
## start harbour (24,31) — nothing at all in between — and the route was a 15-point **V**, seven tiles
## down-left to (17,24) and seven back up-right, **19.80 tiles against a 14.00 straight line**, with
## the hull halfway across heading AWAY from its target. On screen that is not a longer sail, it is
## **a boat that does not know the way**, and it is the first route anybody would draw. The headland
## detour beside it reads correctly, which makes the V worse. After this pass: **3 points, 14.45**.
##
## This is string-pulling: walk the waypoints and drop every one whose removal leaves the straight
## segment entirely over water. **A POST-PASS over a route that is already legal**, never a gate.
##
## ⚠⚠ **`_straight_is_all_water` IS the predicate `speed-off-open-landing` deleted, and it is back for
## a DIFFERENT JOB.** As a sendability test it refused 39–42% of each island's own coastline and that
## is exactly what the user threw out (*"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"*).
## **Nothing here asks it whether a tile may be landed on**, and nothing may. ⚠⚠ **The trap outlives the
## denylist that named it**: where a boat may go is a WATER BFS (`summon_hops`) and nothing else, so if
## a future reader sees a straight-line test in this file and "restores" it to `load_rows` as a
## reachability rule, 39–42% of every island's coastline goes dark again for the second time.
##
## ⚠ **The LANDING is not in `pts` and must not be.** The caller appends it after this returns: it is
## LAND, so a smoother that could see it would be free to pull a straight line across the beach.
## Everything here is water in and water out, which is what keeps `net_boat`'s "every waypoint except
## the last is water" true by construction rather than by luck.
##
## ⚠ **Greedy and not a true funnel, deliberately.** Each index is visited once and each visit costs
## one line test, so this is O(n) tests rather than the O(n^2) a re-anchoring string-pull would be —
## and a route is rebuilt EVERY FRAME while an aim is in flight (`field_view` did it for the deleted
## drag, and does it for `summon_route` now). A funnel would shave a few tiles off a bend; it would not
## change what the bay looks like, which is the whole finding.
## ⚠ Cost, since the tests get longer as the anchor holds: a 30-tile route on the shipped islands is
## roughly 1,900 samples. **On the 144-column map an open route is ~40,000**, which is the one place
## this pass is a real per-frame cost and it is written down rather than guessed at.
func _smooth_water_path(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	var anchor := 0
	var k := 1
	while k < pts.size() - 1:
		# The anchor holds as long as it can still see one waypoint further. The moment it cannot,
		# THIS waypoint becomes the new anchor — never the one that failed, which is unreachable.
		if not _straight_is_all_water(pts[anchor], pts[k + 1]):
			out.append(pts[k])
			anchor = k
		k += 1
	out.append(pts[pts.size() - 1])
	return out


## Whether the straight segment between two TILE points lies entirely over water.
##
## ⚠⚠ **A corner crossing needs BOTH shoulders, and this is deliberately STRICTER than
## `_water_step_open`.** They answer different questions and sharing one rule here would be wrong, not
## tidy:
##   · `_water_step_open` asks *may a boat take this diagonal HOP* — one water shoulder is enough,
##     because the hull rounds the corner through that shoulder
##   · this asks *is every tile a CONTINUOUS segment might sit on water*, and a segment threading the
##     point where four tiles meet can round onto any of the four
## The sampler here steps 0.25 tiles while the sim advances the hull 4.0/60 = 0.067 tiles a sub-step,
## so the boat samples FINER than this does — it can round onto a tile this never looked at, and if
## only one shoulder were required that tile is exactly the dry one. **Requiring both is what makes
## `net_boat`'s 「the hull was over water every sub-step」 true by construction instead of by luck.**
##
## The sample step is `Rules.ROUTE_SMOOTH_SAMPLE_TILES`, and its own comment carries why 0.25 is a
## bound rather than a taste: any coarser and the rounded tile can jump past one nobody looked at.
func _straight_is_all_water(a: Vector2, b: Vector2) -> bool:
	var span := a.distance_to(b)
	if span <= Rules.EPS:
		return true
	var steps := int(ceil(span / Rules.ROUTE_SMOOTH_SAMPLE_TILES))
	var prev := -1
	var px := 0
	var py := 0
	for k in steps + 1:
		var p := a.lerp(b, float(k) / float(steps))
		var tx := int(round(p.x))
		var ty := int(round(p.y))
		if tx < 0 or ty < 0 or tx >= w or ty >= h:
			return false
		var t := ty * w + tx
		if water[t] == 0:
			return false
		if prev >= 0 and t != prev and px != tx and py != ty:
			if water[py * w + tx] == 0 or water[ty * w + px] == 0:
				return false
		prev = t
		px = tx
		py = ty
	return true


## ⚠⚠ **`home_harbour_for` AND `_derive_start_harbour` STOOD HERE AND BOTH ARE DELETED.** They were the
## last two readers of the harbour tables recorded on `harbour_tiles`, and they died the moment nothing
## in `src/` called `Battle.send` any more. **Two measured findings outlive them and must not be
## re-learned the hard way:**
##
##  · **`home_harbour_for(landing)`** answered *which harbour a boat sails from and returns to*: the
##    one with the SHORTEST WATER ROUTE among those that could reach the landing, ties to the lowest
##    index. ⚠⚠ **It was STRAIGHT-LINE distance first and that was WRONG BY MEASUREMENT.** Straight-line
##    ranking picks a harbour on the far side of a headland — near as the crow flies, a long sail — and
##    a beachhead behind that headland strands itself: **2 of 46 beachheads on island 3**. Anything that
##    ever ranks two water origins again must rank them by ROUTE, not by `distance_to`.
##  · ⚠⚠ **Its metric was HOP COUNT and not sailed length, deliberately**, mirroring `flow_field`, which
##    is also hop count. A diagonal hop costs 1 and sqrt(2) tiles of water, so the fewest-hops origin is
##    occasionally not the shortest actual sail; the error is bounded by 41% on an all-diagonal route
##    and every route on these islands is mixed. **The trap is live for `summon_hops`, which is the same
##    kind of field: do not "fix" it with weighted edges while leaving `flow_field` unweighted**, or the
##    two halves of the sim disagree about what "near" means on the same grid. Exact needs Dijkstra with
##    two edge weights, which was judged a bigger change than the rule is worth.
##
##  · **`_derive_start_harbour()`** ran once at the end of `load_rows` and chose where the player's army
##    began: the harbour whose NEAREST reachable coast tile was FARTHEST away — deliberately the most
##    exposed one — ties to the lowest tile index, which row-major fill makes the lowest harbour index.
##    **Nothing picks a starting point on the island now**; the summon band is a ring about
##    `summon_centre` and the player presses inside it.


## Breadth-first from `target_tile` over passable tiles, 8-way. Cost is hop count; unreachable tiles
## keep `UNREACHABLE`.
##
## **Reserved tiles are traversable here on purpose.** If occupancy entered the field, every field
## would have to be rebuilt the moment anybody moved; instead the field is terrain-only and cached,
## and `step_toward` is where occupancy is honoured.
func flow_field(target_tile: int) -> PackedInt32Array:
	var n := w * h
	var field := PackedInt32Array()
	field.resize(n)
	field.fill(UNREACHABLE)
	if target_tile < 0 or target_tile >= n:
		return field
	# The seed is planted whatever the target's own passability. A target standing on an impassable
	# tile — a soldier still aboard a boat — would otherwise produce an all-unreachable field, and
	# every unit asking for it stands still for the rest of the island with nothing logged.
	field[target_tile] = 0
	var queue := PackedInt32Array()
	queue.append(target_tile)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var tx := t % w
		var ty := t / w
		var next_cost := field[t] + 1
		for k in NEIGHBOURS.size():
			var nx := tx + int(NEIGHBOURS[k][0])
			var ny := ty + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			# ⚠ **`can_step` and not `passable[nt]`.** The height gap is refused HERE, in the field
			# itself, and not by the walker afterwards: a field that reached a plateau over its own
			# wall would send every unit to stand under it, which is what "walk to the stair" has to
			# come out of. The plateau is `UNREACHABLE` until a stair is authored.
			if not can_step(t, nt):
				continue
			if field[nt] <= next_cost:
				continue
			field[nt] = next_cost
			queue.append(nt)
	return field


## One step down `field`. `from` is in **tile units, tile centres on integers** — not pixels; the view
## multiplies by the tile size, and mixing the two is the 4.8x error this repo has already paid for.
##
## Picks the neighbour with the lowest field value that is passable and either unreserved or already
## this unit's, reserves it, releases the tile behind, and returns the point to walk toward. **If every
## candidate is taken the unit's own position comes back and it stands** — that is the queue at a neck.
## ⚠ **`keep_level` is -1 for everybody except an enemy holding high ground.** At 0 or more the step
## must also LAND on that level, which is what stops a defender posted on a plateau walking down its
## own stair to meet the attackers — 티켓 19's positional advantage only exists if the side holding it
## stays there. **An optional argument rather than a second walker**: the tie-breaks, the reservation
## swap and the queue-at-a-neck behaviour are the same, and a second copy of them would drift.
func step_toward(unit_id: int, from: Vector2, field: PackedInt32Array,
		keep_level: int = -1) -> Vector2:
	var n := w * h
	if n == 0 or field.size() != n:
		return from
	var cx := clampi(int(round(from.x)), 0, w - 1)
	var cy := clampi(int(round(from.y)), 0, h - 1)
	var cur := cy * w + cx
	_hold(unit_id, cur)
	var best := -1
	var best_cost := field[cur]
	for k in NEIGHBOURS.size():
		var nx := cx + int(NEIGHBOURS[k][0])
		var ny := cy + int(NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var nt := ny * w + nx
		# ⚠ **Asked here as well as in `flow_field`, and that is not a second copy of the rule** — it is
		# the same one function, asked about the tile the unit is actually standing on. The field is
		# built once per target; a unit shoved or landed onto a tier the field never expanded from
		# would otherwise read a neighbour's cost and step over the wall to get at it.
		if not can_step(cur, nt):
			continue
		if keep_level >= 0 and level_of(nt) != keep_level:
			continue
		if reserved[nt] != -1 and reserved[nt] != unit_id:
			continue
		# Strictly better than where it stands. An `<=` here lets a unit already on the target tile
		# step off onto an equal-cost neighbour and oscillate forever, which reads as jitter rather
		# than as a bug.
		if field[nt] >= best_cost:
			continue
		best = nt
		best_cost = field[nt]
	if best == -1:
		_release_except(unit_id, cur, cur)
		return from
	_hold(unit_id, best)
	# The swap: the tile behind is freed only once the unit's rounded position has moved onto the tile
	# it was walking into, so the two-tile hold is never wider than two.
	_release_except(unit_id, cur, best)
	return Vector2(best % w, best / w)


## Every tile this unit holds goes back. Called on death and on boarding.
##
## Rescans `reserved` in full rather than walking `_held`: `battle` may write `reserved` directly when
## it places a landing soldier, and a tile that never entered `_held` would stay locked for the rest of
## the island with no unit standing on it.
func release_all(unit_id: int) -> void:
	for t in reserved.size():
		if reserved[t] == unit_id:
			reserved[t] = -1
	_held.erase(unit_id)


## Claims `tile` unless someone else already holds it. A tile already marked with this unit's id but
## missing from `_held` is adopted, so a direct write by `battle` still gets released later.
func _hold(unit_id: int, tile: int) -> void:
	if reserved[tile] != -1 and reserved[tile] != unit_id:
		return
	reserved[tile] = unit_id
	var held: Array = _held.get(unit_id, [])
	if not held.has(tile):
		held.append(tile)
	_held[unit_id] = held


func _release_except(unit_id: int, keep_a: int, keep_b: int) -> void:
	if not _held.has(unit_id):
		return
	var kept := []
	for raw in _held[unit_id]:
		var tile := int(raw)
		if tile == keep_a or tile == keep_b:
			if not kept.has(tile):
				kept.append(tile)
			continue
		if reserved[tile] == unit_id:
			reserved[tile] = -1
	_held[unit_id] = kept
