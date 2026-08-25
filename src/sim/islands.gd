class_name Islands
## The maps, and the lookups that turn one into a fight. **Three hand-authored islands and one
## generated long map** — `count()` is 4, `ISLAND_ROWS.size()` is 3, and they are different questions.
##
## Format: every row of one map is the same length, and that length is the map's own. **The three
## hand-authored islands are 32 strings of exactly 48 characters** — 48 x 32 = 1536 tiles, 40 px each
## = 1920 x 1280 canvas px, deliberately larger than the 1280x720 viewport, which is the whole reason
## `boat-and-landing` adds a camera (section 7.1). There is no multiplier hidden anywhere else.
##
## ⚠ **48 x 32 is NOT the format any more, it is those three maps' size.** The long map at the bottom
## of this file is 144 x 32, and `field_view` reads `battle.grid.w` / `h` rather than `Look.GRID_W` /
## `GRID_H` so that both can exist. A reader who takes "48 characters" as a rule will write the next
## map wrong.
##
## Legend (`boat-and-landing`, section 3.1):
##   `~` water — impassable to a soldier. It is what a boat SAILS OVER: `grid.water_fields` is a BFS
##       across these tiles, and a land tile is sendable iff one of its eight neighbours is water a
##       harbour's boat can reach
##   `H` harbour — water, AND a tile a boat may sail from and return to. **Several per island, no
##       single exact launch point** — the user's own correction to the first draft of the plan.
##   `.` land
##   `#` hole — impassable land, inland. Attacks pass over it; only movement is blocked
##   `^` cliff — impassable land, AT THE COAST. Exactly as impassable as `#`; it differs only in the
##       character the view reads to colour it. There is no elevation axis this round: a cliff blocks
##       simply by being impassable, so `sendable` refuses it on its FIRST test and the land behind it
##       on the second (no water neighbour) — no code has to remember that separately. ⚠ Since
##       `speed-off-open-landing` the cliff face is also the ONLY standing 「여긴 못 내린다」 mark on
##       screen: the green coast wash that used to say the same thing from the other side is deleted.
##   `/` ramp — passable land, the only doorway through a cliff wall. A doorway, not a climb.
##   `S` `A` `L` land, with a shieldbearer / archer / lion starting there. ⚠ **The letters are NOT
##       listed here twice** — `SPAWN_ROWS` at the bottom of this file is what binds each one to a
##       unit row, and `grid.land_chars()` reads that same table for walkability
##
## **`D` (dock) is gone.** The old fixed-dock legend is deleted along with `Grid.DOCK_CHAR` and
## `grid.dock_tiles` — an open coastline replaces it, and `grid.gd`'s `water_fields` / `sendable` /
## `can_land_at` / `water_route` are what decide where a boat may go and what it sails to get there.
## ⚠ **`landable` is gone too** (`speed-off-open-landing`): landing is a DENYLIST now, and what is
## refused on these three grids is exactly cliff plus inland — 84 · 76 · 82 of the 744 · 760 · 716
## land tiles are sendable, which is every tile touching water on any of eight sides.
##
## Harbour index is the order an `H` is met scanning row-major, top-left first. Nothing chooses a
## harbour by hand any more — `grid.home_harbour_for(landing)` picks the nearest one that can still
## see the landing — but the ORDER is still what `harbour_tiles` and `start_harbour` are indexed by;
## `grid.gd` is what records it, and this file only holds the characters.
##
## Enemy placement here is measured, not eyeballed: see `boat-and-landing`, section 5, for the coast
## counts, the narrowest column cut, and the crossing distances measured off these exact rows.


## `const X := PackedInt32Array([...])` is a parse error in GDScript 4.7, so this is a plain const
## Array of const Arrays and every read casts.
const ISLAND_ROWS := [
	# Island 1 -- open, one bay, 4 shieldbearers. Narrowest cut 15. Deliberately no headland: a draft put two
	# cliff promontories on it and they shadowed 50 of its 74 coast tiles, which is not a baseline.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~..S........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~................S...........S...............~~",
		"~~.....S.................................S....~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~.................S..........................~~",
		"~~..................~~~~~~~~..................~~",
		"~~..................~~~~~~~~..................~~",
		"~~.....S............~~~~~~~~.....S............~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~",
	],
	# Island 2 -- a cliff ridge into the sea, one 2-tile ramp. Narrowest cut 2. The ridge shadows
	# columns 20-21, splitting the shore into a west beach (2-19) and an east beach (24-45): the
	# island where plural harbours pay for themselves, because the start harbour sees both shores and
	# the west/east harbours each see only their own side.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~........A...........^^......................~~",
		"~~....................^^......................~~",
		"~~....S...............^^..........S...........~~",
		"~~....................^^......................~~",
		"~~....................^^..S...................~~",
		"~~....................^^.....S................~~",
		"~~............S.......//......................~~",
		"~~....................//......................~~",
		"~~....................^^..S.............S.....~~",
		"~~....................^^......S...............~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~......A.......A.....^^......................~~",
		"~~....................^^......A...............~~",
		"~~....................^^......................~~",
		"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~^^~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~",
		"~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~",
	],
	# Island 3 -- a cliff ring with two ramp doors, behind a bay. Narrowest cut 10. Lion at the centre,
	# an archer and a shieldbearer inside, a shieldbearer and an archer outside. Under "nearest harbour, full stop"
	# landing at (18,18) or (17,19) would strand the beachhead -- Grid.home_harbour_for visibility
	# filter is what fixes it.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~........S...........................S.......~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~.............^.................^............~~",
		"~~.............^...SA........A...^............~~",
		"~~.............^.................^............~~",
		"~~............./........L......../............~~",
		"~~............./................./............~~",
		"~~....A........^.................^..S.........~~",
		"~~.............^............SS...^............~~",
		"~~.............^.................^............~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~............................................~~",
		"~~......S...S.......A...................A.....~~",
		"~~............................................~~",
		"~~................~~~~~~~~~~~~~...............~~",
		"~~................~~~~~~~~~~~~~...............~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~H~~~~~~~~~~~~~~~~~~~~~~~",
	],]

## Seconds per island. **The clock starts at the start button, and planning is free.** Structural,
## not a rule anyone has to honour: `Battle._phase_clock` is the only writer of `elapsed`, and an
## uncommitted `Battle.step` returns before it. The line that used to stand here — "the clock starts
## when the island OPENS, so waiting for a full boat costs the same as a bad landing does" — died with
## 결정 3, 「배는 언제든지 … 시작하기 전에 어디서든지」: there is no boat to wait for and thinking costs
## nothing. `plan-then-watch` is where that reversal is recorded.
## ⚠⚠ **MEASURED 2026-08-18: this clock has never once bound.** The probe ran five landing policies over
## all three islands — **15 wins out of 15**, the worst plan finishing at **49%** of its limit, and island
## 3's entire spread between best and worst plan is **1.50 s** (30.30 vs 31.80). To discriminate there,
## the limit would have to sit inside a window narrower than the error on the next untried plan.
## ⇒ **Lowering these numbers cannot make the landing point a decision** — that is a level-design problem,
## not a constant. Numbers and consequences: `plan-then-watch`.
## ⚠ **That 49% is a PRE-SUB-STEP number and is not comparable to anything measured after it.**
## `Battle.step` now runs whole `Rules.SIM_SUBSTEP_SEC` passes, so the probe's own `DT` became three
## passes instead of one and every per-step quantity in the fight was re-discretised. **Re-measure the
## baseline at the OLD enemy counts before judging any new count against it**, or the round books a
## design win that is a discretisation artefact.
const TIME_LIMITS := [60.0, 60.0, 90.0]


# ---------------------------------------------------------------------------------------------
# The long map — **the deliverable is the CAPABILITY, not a set of maps**
# ---------------------------------------------------------------------------------------------
#
# Decided by the user 2026-08-19 (`idea-inbox` row 52): *"긴 맵 하나 하고 한 칸짜리 맵만 있으면 돼있듯
# … 추후에 확장 가능하게 코딩만 해주고"*. What was blocking it was not this file — `Look.GRID_W` /
# `GRID_H` were `const 48` / `32` and `field_view._draw` and `_clamp_cam` read those constants instead
# of `battle.grid.w` / `h`, so **two maps of different sizes were unrepresentable.** That is fixed in
# `field_view`; this is the first map that exercises it.
#
# ⚠ **It is NOT wired into `Rules.MAP_NODES` and no node opens it.** Reaching it is a fixture and
# probe path only. `title-and-map`'s step 5 is paused and is being replaced; deciding which node opens
# which grid is that plan's business, not this one's.
#
# ⚠ **144 is one edit, here.** The user asked for 「너무 크게 만들지 마」 and 「천천히 늘리자」, so the
# width is a constant on its own line and nothing below it repeats the number: the rows, the enemy
# spacing and the time limit are all derived from it.

## 3x the shipped islands' 48 columns. The height is deliberately UNCHANGED — a long map is long, and
## a taller one is a different question with different arithmetic behind it (`push-inland` measured
## that its own height "cross-check" was an identity in t and demoted the paragraph).
const LONG_ISLAND_W := 144
const LONG_ISLAND_H := 32

## Where the long map sits in the island index. `count()` includes it, so `rows_of` / `spawns_of` /
## `time_limit_of` all answer for it exactly as they do for the hand-authored three, and `net_islands`
## validates its rows with the same legend loop.
const LONG_ISLAND_INDEX := 3

## Row bands, as fractions of the height, so the shape survives `LONG_ISLAND_H` moving. They mirror
## the three shipped islands: two rows of open sea, a cliff wall along the north shore, the land body,
## then the southern sea the harbours sit in.
const LONG_CLIFF_ROW := 2
const LONG_LAND_TOP := 3
const LONG_LAND_BOTTOM := 20      # inclusive. 21..31 is open water, as on all three shipped islands
const LONG_SEA_EDGE := 2        # columns of water down each side, the same as the shipped rows

## One defender every this many columns of land, and one harbour every this many columns of sea. Both are
## SPACINGS rather than counts, so widening the map adds enemies and harbours instead of stretching
## the same few further apart — a 144-column map with island 1's eight defenders is an empty walk.
const LONG_ENEMY_PITCH := 6
const LONG_HARBOUR_PITCH := 24


## --- the compact islands ---------------------------------------------------------------------------
## ⚠⚠ **GENERATED, like the long map and NOT typed into `ISLAND_ROWS`** — and that is a decision about
## the CHECKS, not about the maps. `net_islands` carries a per-island table of measured literals for
## every hand-written grid (coast, sendable, passable, water, crossings). Typing four more grids in
## would have meant four more measured rows in ten tables before a single one could be played; born
## here they are outside that suite exactly as the long map is, and the suite's own literal `3` stays
## true. **The cost is real and is written down: nothing measures these four.**
##
## ⚠ **They are SMALL on purpose** (2026-08-24). The shipped three are 48 x 32 = 1536 tiles carrying
## eighteen bodies, and 「멀리서 봤을때 너무작네」 is what that empties out to. These run 22 x 14 to
## 28 x 18 — a quarter of the area — and `Look.survey_zoom_of` opens them at a zoom that fills the
## screen instead of at one constant measured against 48 x 32.
##
## ⚠⚠ **THE SEA BELOW THE LAND IS NOT DECORATION AND THE FIRST DRAFT OF THIS TABLE HAD NONE.** A boat
## may only be placed at least `Rules.SUMMON_BAND_MIN_TILES` = **6 water hops from any shore**, and the
## first four maps here left a four-row strip: **0 placeable tiles on all four**, measured. They loaded,
## they drew, and the plan could not be authored — the exact shape of code that pretends to work.
## ⇒ **Every row below leaves 8 or 9 rows of open water under the land**, and the harbours sit on the
## last row of it. The land itself is what shrank, not the grid.
##
## Columns: 0 width · 1 height · 2 cliff row (-1 = no wall) · 3 first land row · 4 last land row ·
## 5 enemy pitch in columns · 6 harbour pitch · 7 ramp stride through the wall (0 = no ramp) ·
## 8 water columns down each side.
## ⚠⚠ **THE FIRST ISLAND WAS UNWINNABLE AND THAT IS WHY THE PITCHES NOW RISE.** Every row started
## at a pitch of 4-6 and the first fight came out at **twelve defenders against ten landing bodies** --
## measured twice, once with the force split over four beaches and once landed whole. Both lost.
## **A first island nobody wins is a game whose card screen nobody ever sees.**
## => The pitch falls as the run climbs. The hand-written islands sit at 8 defenders for the same ten
## bodies and are winnable, which is where the first row's number comes from.
## ⚠⚠ **THE FIRST ISLAND'S GENERATOR ROW IS GONE — it is typed out by hand below.** The row that used
## to sit here was `[26, 20, -1, 3, 11, 9, 8, 0, 3]`, and what it produced was **a rectangle**: nine
## full-width rows of land with a straight coast on all four sides. 「그냥 땅땅한 판에 아무것도 없는
## 너무 휑해」 is a description of that shape and not of what is drawn on it. **A generator that takes
## a width and a height cannot make a bay**, and a bay is what splits one landing choice from another.
const SMALL_ISLANDS := [
	[28, 21,  2, 3, 12, 7, 9, 5, 3],
	[24, 19, -1, 3, 10, 4, 7, 0, 3],
	[30, 22,  2, 3, 12, 5, 9, 7, 4],
]

## The island the first map node opens, **typed out rather than generated** (2026-08-25, the user:
## ***「저 맵부터 가다구를 잡자」*** and ***「손으로 그리는게 맞지 않을까?」***).
##
## ⚠⚠ **THE TERRAIN AND THE HEIGHT ARE ONE DRAWING AND THEY WERE TWO.** The rows came out of a
## generator and `ISLAND_4_TIERS` was typed by hand against a shape nobody had drawn — the two were
## held in step by nothing but being the same size. **A plateau can only be placed where the land
## actually is**, so the moment height became real the terrain had to be authorable too.
##
## Same **26 x 20** as the generated row it replaces: `Look.survey_zoom_of` opens an island against its
## own size, `net_shell` names 26 x 20, and the crossing figures every timing literal in this repo is
## measured against are that grid's. **The shape changed; the frame did not.**
##
## What is drawn, and why each piece is there:
##  · **A bay splitting the south shore.** The land is one body — you can walk from the west spur to
##    the east one across the north — but a fleet landing west and a fleet landing east arrive at
##    opposite ends of a walk. **That is the landing choice the rectangle did not have.**
##  · **A plateau at x 18-21, y 3-6, with its one stair at (18, 4).** Set inland on purpose: `net_tiers`
##    asserts no plateau tile touches water on any of eight sides (so nothing can land on it while
##    「상륙은 낮은 층에만」 is still unbuilt) and that no landing tile sits beside the stair (so a boat
##    cannot be parked at the door).
##  · **Six defenders, three of them up top** — an empty plateau teaches nothing, and the first island
##    is where a player learns that high ground has to be climbed.
##  · **Eight rows of open sea below the land, harbours on the last one.** A boat may only be placed
##    `Rules.SUMMON_BAND_MIN_TILES` = 6 water hops from any shore; the first draft of the generated
##    table left four rows and measured **0 placeable tiles**. That failure is not repeatable here.
## ⚠⚠ **THE COAST IS DRAWN IN STRAIGHT RUNS AND THE FIRST DRAFT WAS NOT.** That draft stepped the
## south shore back one column per row — a smooth diagonal on paper. On screen every tile hangs a
## `_skirt` down to the sea, so a staircase coast shows **every one of those skirts edge-on at once**
## and the island reads as a torn sheet of paper. Photographed and thrown away. **A shore that changes
## in runs of three or more columns hangs one wall, not a comb.**
const ISLAND_4_ROWS := [
	"~~~~~~~~~~~~~~~~",
	"~~~..........~~~",
	"~~..S......A..~~",
	"~~.........A..~~",
	"~~........A...~~",
	"~~....~~......~~",
	"~~~.S.~~...S.~~~",
	"~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~",
	"~~~H~~~~H~~~~H~~",
]


## **The island index the hand-drawn map holds.** `Rules.MAP_NODES[0]` opens it, and `net_tiers`
## asserts that — the island a player sees first and the island carrying the plateau are the same
## island by check, not by coincidence.
const HAND_ISLAND_INDEX := 4

## Where the compact islands start in the index. **After the long map and after the hand-drawn one**,
## so `LONG_ISLAND_INDEX` and every literal measured against the hand-written three keep meaning what
## they meant.
const SMALL_ISLAND_BASE := 5


## --- the tier boards --------------------------------------------------------------------------------
## **A second board per island, the same shape as its rows, holding height and nothing else.**
## `.` low · `/` stair · `1` high — `Grid.TIER_CHARS` is where those letters are bound to levels, and
## this file only holds the characters, exactly as it does for the terrain legend.
##
## ⚠⚠ **ONE ISLAND HAS ONE, AND THE OTHER SEVEN ARE FLAT.** 티켓 19's answer says all eight get tiers;
## the user cut this slice down to the island the first map node opens, so they can look at a real
## plateau before seven more are authored against a shape nobody has judged yet. **The other seven are
## not "done" — they are not started**, and `tiers_of` returning `[]` for them means flat.
##
## ✅ **`Rules.MAP_NODES[0]` opens island 4, and island 4 is now TYPED OUT** (`ISLAND_4_ROWS`). The two
## boards are one drawing by one hand, which is what they were not: the rows used to come out of a
## generator and this board was written against a rectangle nobody had chosen. **`net_tiers` still
## asserts the shape**, and asserts that no stair or high tile lands on a character a body cannot stand
## on — a stair drawn over water is a door that silently is not there.
##
## ⚠⚠ **THE PLATEAU MOVED AND SHRANK, and both are consequences of the coast being drawn.** The old
## board put a 9 x 7 slab across the middle of a full-width rectangle; on a coast with a bay in it that
## slab **touches water**, and `net_tiers` refuses that — nothing may land on a plateau while
## 「상륙은 낮은 층에만」 is unbuilt. What fits inland is **4 wide by 4 deep at x 18-21, y 3-6**, one
## corner of it traded for the stair.
const ISLAND_4_TIERS := [
	"................",
	"................",
	"..........11....",
	"........../1....",
	"..........11....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]




## The tier board for island `i`, or **`[]` for an island with no height in it** — which `Grid.load_rows`
## reads as flat.
##
## ⚠ **Deliberately not a table indexed by island.** A seven-entry table of empty arrays would say
## "these seven were considered and are flat", and what is true is that they have not been authored.
## The day the second one is written this becomes the table; today it is one island and a default.
static func tiers_of(i: int) -> Array:
	if i == HAND_ISLAND_INDEX:
		return ISLAND_4_TIERS
	return []


## **Loads island `i` into `grid` — terrain and height together.** ⚠⚠ **This exists because loading an
## island became TWO calls and five callers were still making one**, which is not a bug anyone would
## have found by reading: a grid loaded without its tier board comes up flat, draws, plays, and says
## nothing. The probe reported a flat island and the screenshot tool photographed one.
##
## ⇒ **Nobody outside a hand-written fixture should call `grid.load_rows` directly.** `load_rows` keeps
## taking rows and an optional board because every net builds its own board by hand; **an island NUMBER
## is loaded through here**, so the day a third table joins the two there is one line to change instead
## of a sweep that has already been missed once.
static func load_into(grid: Grid, i: int) -> void:
	grid.load_rows(rows_of(i), tiers_of(i))


## One compact island, built from its row of `SMALL_ISLANDS`.
##
## ⚠ **Enemies alternate between the two kinds** as they are placed, so no island is eight of one
## thing — which is what island 0 is, and it is why the first fight a player sees has one enemy in it.
static func _small_rows(k: int) -> Array:
	var spec: Array = SMALL_ISLANDS[k]
	var w := int(spec[0])
	var h := int(spec[1])
	var cliff := int(spec[2])
	var top := int(spec[3])
	var bottom := int(spec[4])
	var epitch := int(spec[5])
	var hpitch := int(spec[6])
	var ramp := int(spec[7])
	var sea := int(spec[8])
	var body := w - 2 * sea
	var rows := []
	var placed := 0
	for y in h:
		if cliff >= 0 and y == cliff:
			var wall := ""
			for x in body:
				wall += "/" if (ramp > 0 and (x % ramp) == ramp / 2) else "^"
			rows.append("~".repeat(sea) + wall + "~".repeat(sea))
			continue
		if y >= top and y <= bottom:
			var land := ""
			for x in body:
				var ch := "."
				# Every third land row and every `epitch` column, and never on column 0 — a body on
				# the corner a boat lands at is a body the plan cannot avoid.
				if x > 0 and (x % epitch) == epitch / 2 and ((y - top) % 3) == 1:
					ch = spawn_char_of(Rules.SHIELDBEARER) if (placed % 2) == 0 \
						else spawn_char_of(Rules.ARCHER)
					placed += 1
				land += ch
			rows.append("~".repeat(sea) + land + "~".repeat(sea))
			continue
		if y == h - 1:
			var water := ""
			for x in w:
				water += "H" if (x % hpitch) == hpitch / 2 else "~"
			rows.append(water)
			continue
		rows.append("~".repeat(w))
	return rows


static func count() -> int:
	# ⚠ Not a literal 8: **two of the eight are not in `ISLAND_ROWS`** — the long map is generated, and
	# the first island is typed out in its own constant because it is the one a player sees first.
	# ⚠⚠ **The total did not move when the first island stopped being generated.** One row left
	# `SMALL_ISLANDS` and `ISLAND_4_ROWS` took its place in the index, so the map's seven nodes still
	# open the islands they opened.
	return ISLAND_ROWS.size() + 1 + 1 + SMALL_ISLANDS.size()


static func rows_of(i: int) -> Array:
	if i == LONG_ISLAND_INDEX:
		return _long_rows()
	if i == HAND_ISLAND_INDEX:
		return ISLAND_4_ROWS
	if i >= SMALL_ISLAND_BASE:
		return _small_rows(i - SMALL_ISLAND_BASE)
	return ISLAND_ROWS[i] as Array


## ⚠⚠ **The long map's limit is DERIVED from its width, and the arithmetic is here rather than a
## guessed number.** Everything a run spends its clock on scales with how far across the map things
## are: the crossing (`boat-invasion` measured crossings at ~20% of the clock, and this round's own
## probe re-measured them at 45–49%) and the walk inland afterwards. So the limit is island 1's own
## seconds-per-column, applied to this map's columns:
##
##   `TIME_LIMITS[0] / 48 columns = 60 / 48 = 1.25 s per column`
##   `1.25 * 144 = 180.0 s`
##
## ⚠ **The 48 is READ off island 0's own first row**, never typed: the two numbers in that division
## have to be the same island's, or the day the shipped grids change width the ratio silently rots.
##
## ⚠ **This is not a tuned number and must not be read as one.** The clock has never once bound on the
## shipped islands (15 island-runs, worst plan at 49%), so 180 is a limit derived to be as loose on
## this map as 60 is on island 1 — it is a placeholder that scales, not a balance decision. Retuning
## `TIME_LIMITS` is a decision with the user in it.
static func time_limit_of(i: int) -> float:
	var base_w := str((ISLAND_ROWS[0] as Array)[0]).length()
	var per_column := float(TIME_LIMITS[0]) / float(base_w)
	if i == LONG_ISLAND_INDEX:
		return per_column * float(LONG_ISLAND_W)
	# ⚠ The compact islands take the same seconds-per-column. **Nothing loses by the clock any more**
	# (see `battle._phase_clock`), so this is a number that has to exist rather than one that decides.
	# ⚠⚠ **The hand-drawn island needs its own branch and would otherwise index `TIME_LIMITS`**, which
	# has one entry per island in `ISLAND_ROWS` and would be read out of range. Its width is read off
	# its own first row for the same reason `base_w` is: a number typed twice rots on the day one moves.
	if i == HAND_ISLAND_INDEX:
		return per_column * float(str(ISLAND_4_ROWS[0]).length())
	if i >= SMALL_ISLAND_BASE:
		return per_column * float((SMALL_ISLANDS[i - SMALL_ISLAND_BASE] as Array)[0])
	return float(TIME_LIMITS[i])


## The long map's rows, built rather than typed. **Nothing here repeats `LONG_ISLAND_W`** — every
## span is that constant minus the margins, so widening the map is one edit up top.
##
## ⚠ **No cache.** `rows_of` is called once per island load in the shell and a handful of times by the
## nets; 32 string builds is nothing, and a `static var` holding them would be state this class does
## not otherwise have, invisible to `load_rows`' own "safe to call twice" contract.
static func _long_rows() -> Array:
	var w := LONG_ISLAND_W
	var sea := LONG_SEA_EDGE
	var body := w - 2 * sea
	var rows := []
	for y in LONG_ISLAND_H:
		if y == LONG_CLIFF_ROW:
			rows.append("~".repeat(sea) + "^".repeat(body) + "~".repeat(sea))
			continue
		if y >= LONG_LAND_TOP and y <= LONG_LAND_BOTTOM:
			var land := ""
			for x in body:
				# The defenders sit on the LAND, spaced by column, and the first one is a full pitch
				# in from the west edge so nothing spawns on the corner a boat lands at.
				var on_pitch := (x % LONG_ENEMY_PITCH) == 0 and x > 0
				land += spawn_char_of(Rules.SHIELDBEARER) \
					if (on_pitch and y == _enemy_row(x)) else "."
			rows.append("~".repeat(sea) + land + "~".repeat(sea))
			continue
		# Open sea. The harbours go on the bottom row, spread the width of the map, so a plan can be
		# authored from either end of it rather than from one corner.
		if y == LONG_ISLAND_H - 1:
			var water := ""
			for x in w:
				water += "H" if (x % LONG_HARBOUR_PITCH) == LONG_HARBOUR_PITCH / 2 else "~"
			rows.append(water)
			continue
		rows.append("~".repeat(w))
	return rows


## Which land row column `x`'s defender stands on. A single `sin`-free stagger — three rows walked in
## turn — so the enemies are not one straight line across the map and the pattern is still
## reproducible by hand. **No RNG**: a random layout cannot be measured, and this repo has paid for
## that once already.
static func _enemy_row(x: int) -> int:
	var span := LONG_LAND_BOTTOM - LONG_LAND_TOP
	var step := span / 4
	return LONG_LAND_TOP + step + ((x / LONG_ENEMY_PITCH) % 3) * step


## Every enemy on island `i`, as `{"type_id": int, "tile": int}` with `tile` a row-major index.
static func spawns_of(i: int) -> Array:
	var rows := rows_of(i)
	# The stride comes from row 0, never from each row's own length: a short row would otherwise
	# renumber every tile below it into a plausible-looking index instead of failing loudly.
	var w := str(rows[0]).length()
	var out := []
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var type_id := spawn_type_of_char(row[x])
			if type_id >= 0:
				out.append({"type_id": type_id, "tile": y * w + x})
	return out


## --- the spawn characters ---------------------------------------------------------------------
## **One row per letter that puts a body on the ground: the character, and the `Rules.UNITS` row it
## is.** ⚠⚠ **THIS IS THE ONE PLACE A SPAWN LETTER IS BOUND TO ANYTHING**, and it is new: the letters
## used to live here as a `match` AND in `grid.LAND_CHARS` as a string, two lists nobody kept in step.
## `grid.land_chars()` reads this table, so **a letter that spawns a body is walkable ground by
## construction** — which closes 「모르는 글자는 조용히 구멍이 된다」 at its cause rather than by
## remembering to edit twice.
##
## ⚠⚠ **`B` AND `C` ARE GONE — the letters changed WITH their meaning.** They were 들소 and 까마귀,
## and both species crossed to the player's side, so the rows they named are `SHIELDBEARER` and
## `ARCHER` now. Re-pointing `B` at the shieldbearer would have left this file's legend and
## `grid.gd`'s both lying, and this repo has paid twice for a name that outlived its sense (「부위」
## and 「다리」).
const SPAWN_ROWS := [
	["S", Rules.SHIELDBEARER],
	["A", Rules.ARCHER],
	["L", Rules.LION],
]

const _SPAWN_COL_CHAR := 0
const _SPAWN_COL_TYPE := 1


## The `Rules.UNITS` row `ch` spawns, or **-1 for "this character spawns nothing"**. Terrain is
## `grid.gd`'s business, not this file's.
static func spawn_type_of_char(ch: String) -> int:
	for r in SPAWN_ROWS.size():
		if str((SPAWN_ROWS[r] as Array)[_SPAWN_COL_CHAR]) == ch:
			return int((SPAWN_ROWS[r] as Array)[_SPAWN_COL_TYPE])
	return -1


## Every spawn letter, as one string. `grid.land_chars()` appends it to the bare ground characters.
static func spawn_chars() -> String:
	var out := ""
	for r in SPAWN_ROWS.size():
		out += str((SPAWN_ROWS[r] as Array)[_SPAWN_COL_CHAR])
	return out


## The letter row `type_id` is written with, or `"."` — plain ground — for a row that spawns nowhere.
## **The generators below call THIS and never type a letter**, so the generated maps and the
## hand-written ones cannot drift apart.
static func spawn_char_of(type_id: int) -> String:
	for r in SPAWN_ROWS.size():
		if int((SPAWN_ROWS[r] as Array)[_SPAWN_COL_TYPE]) == type_id:
			return str((SPAWN_ROWS[r] as Array)[_SPAWN_COL_CHAR])
	return "."
