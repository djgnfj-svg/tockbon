class_name Islands
## The three islands, and the lookups that turn one into a fight.
##
## Format: each island is 32 strings of EXACTLY 48 characters. 48 x 32 = 1536 tiles, 40 px each =
## 1920 x 1280 canvas px — deliberately larger than the 1280x720 viewport, which is the whole reason
## `boat-and-landing` adds a camera (section 7.1). There is no multiplier hidden anywhere else.
##
## Legend (`boat-and-landing`, section 3.1):
##   `~` water — impassable to a soldier, not landable
##   `H` harbour — water, AND a tile a boat may sail from and return to. **Several per island, no
##       single exact launch point** — the user's own correction to the first draft of the plan.
##   `.` land
##   `#` hole — impassable land, inland. Attacks pass over it; only movement is blocked
##   `^` cliff — impassable land, AT THE COAST. Exactly as impassable as `#`; it differs only in the
##       character the view reads to colour it. There is no elevation axis this round: a cliff blocks
##       simply by making the land behind it not orthogonally adjacent to water, so it is never
##       landable — no code has to remember that separately.
##   `/` ramp — passable land, the only doorway through a cliff wall. A doorway, not a climb.
##   `B` `C` `L` land, with a bison / crow / lion starting there
##
## **`D` (dock) is gone.** The old fixed-dock legend is deleted along with `Grid.DOCK_CHAR` and
## `grid.dock_tiles` — an open coastline replaces it, and `grid.gd`'s `landable` / `sendable` /
## `can_land_at` are what decide where a boat may go now.
##
## Harbour index is the order an `H` is met scanning row-major, top-left first, so `battle.launch(0,
## tile)` means "the boat sitting at the first harbour met in that order" — `grid.gd` is what records
## it; this file only holds the characters.
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
		"~~...........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~...........####..............####...........~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~................B...........B...............~~",
		"~~.....B.................................B....~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~............................................~~",
		"~~..................~~~~~~~~..................~~",
		"~~..................~~~~~~~~..................~~",
		"~~..................~~~~~~~~..................~~",
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
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~....................^^..B...................~~",
		"~~....................^^.....B................~~",
		"~~....................//......................~~",
		"~~....................//......................~~",
		"~~....................^^..B...................~~",
		"~~....................^^......B...............~~",
		"~~....................^^......................~~",
		"~~....................^^......................~~",
		"~~......C.......C.....^^......................~~",
		"~~....................^^......................~~",
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
		"~~............................................~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~.............^.................^............~~",
		"~~.............^....C............^............~~",
		"~~.............^.................^............~~",
		"~~............./........L......../............~~",
		"~~............./................./............~~",
		"~~.............^.................^............~~",
		"~~.............^............B....^............~~",
		"~~.............^.................^............~~",
		"~~.............^^^^^^^^^^^^^^^^^^^............~~",
		"~~............................................~~",
		"~~......B...............................C.....~~",
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

## Seconds per island. The clock starts when the island OPENS, not on the first landing, so waiting
## for a full boat costs the same as a bad landing does. **Unchanged by `boat-and-landing`** — an open
## coastline having a cost is not proven by that plan's round (its section 1), so nobody edits this
## here.
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
