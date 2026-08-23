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
##   `B` `C` `L` land, with a bison / crow / lion starting there
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
	# Island 1 -- open, one bay, 4 bison. Narrowest cut 15. Deliberately no headland: a draft put two
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
		"~~..B........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~................B...........B...............~~",
		"~~.....B.................................B....~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~.................B..........................~~",
		"~~..................~~~~~~~~..................~~",
		"~~..................~~~~~~~~..................~~",
		"~~.....B............~~~~~~~~.....B............~~",
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
		"~~........C...........^^......................~~",
		"~~....................^^......................~~",
		"~~....B...............^^..........B...........~~",
		"~~....................^^......................~~",
		"~~....................^^..B...................~~",
		"~~....................^^.....B................~~",
		"~~............B.......//......................~~",
		"~~....................//......................~~",
		"~~....................^^..B.............B.....~~",
		"~~....................^^......B...............~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~......C.......C.....^^......................~~",
		"~~....................^^......C...............~~",
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
	# a crow and a bison inside, a bison and a crow outside. Under "nearest harbour, full stop"
	# landing at (18,18) or (17,19) would strand the beachhead -- Grid.home_harbour_for visibility
	# filter is what fixes it.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~........B...........................B.......~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~.............^.................^............~~",
		"~~.............^...BC........C...^............~~",
		"~~.............^.................^............~~",
		"~~............./........L......../............~~",
		"~~............./................./............~~",
		"~~....C........^.................^..B.........~~",
		"~~.............^............BB...^............~~",
		"~~.............^.................^............~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~............................................~~",
		"~~......B...B.......C...................C.....~~",
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

## One bison every this many columns of land, and one harbour every this many columns of sea. Both are
## SPACINGS rather than counts, so widening the map adds enemies and harbours instead of stretching
## the same few further apart — a 144-column map with island 1's eight bison is an empty walk.
const LONG_ENEMY_PITCH := 6
const LONG_HARBOUR_PITCH := 24


static func count() -> int:
	# ⚠ `ISLAND_ROWS.size() + 1` and not a literal 4: the long map is generated rather than typed out,
	# so it is not in that array and cannot be counted by it.
	return ISLAND_ROWS.size() + 1


static func rows_of(i: int) -> Array:
	if i == LONG_ISLAND_INDEX:
		return _long_rows()
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
	if i == LONG_ISLAND_INDEX:
		var base_w := str((ISLAND_ROWS[0] as Array)[0]).length()
		return float(TIME_LIMITS[0]) / float(base_w) * float(LONG_ISLAND_W)
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
				# The bison sit on the LAND, spaced by column, and the first one is a full pitch in
				# from the west edge so nothing spawns on the corner a boat lands at.
				var on_pitch := (x % LONG_ENEMY_PITCH) == 0 and x > 0
				land += "B" if (on_pitch and y == _enemy_row(x)) else "."
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


## Which land row column `x`'s bison stands on. A single `sin`-free stagger — three rows walked in
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
			var type_id := _spawn_type_at(row[x])
			if type_id >= 0:
				out.append({"type_id": type_id, "tile": y * w + x})
	return out


## -1 means "this character spawns nothing". Terrain is grid.gd's business, not this file's.
static func _spawn_type_at(ch: String) -> int:
	match ch:
		"B":
			return Rules.BISON
		"C":
			return Rules.CROW
		"L":
			return Rules.LION
		_:
			return -1
