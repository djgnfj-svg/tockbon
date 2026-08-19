class_name Islands
## The three islands, and the lookups that turn one into a fight.
##
## Format: each island is 32 strings of EXACTLY 48 characters. 48 x 32 = 1536 tiles, 40 px each =
## 1920 x 1280 canvas px — deliberately larger than the 1280x720 viewport, which is the whole reason
## `boat-and-landing` adds a camera (section 7.1). There is no multiplier hidden anywhere else.
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


static func count() -> int:
	return ISLAND_ROWS.size()


static func rows_of(i: int) -> Array:
	return ISLAND_ROWS[i] as Array


static func time_limit_of(i: int) -> float:
	return float(TIME_LIMITS[i])


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
