class_name Islands
## The three islands of the first slice, and the lookups that turn one into a fight.
##
## Format: each island is 18 strings of EXACTLY 32 characters. 32 x 18 tiles at 40 px fills a
## 1280 x 720 viewport with no multiplier anywhere, which is the pairing that keeps a tile count and
## a pixel count from drifting apart.
##
## Legend:
##   `~` water — impassable, not landable
##   `.` land
##   `#` hole — impassable land. Attacks pass over it; only movement is blocked
##   `D` dock — land, and the only tile a boat may be sent to
##   `B` `C` `L` land, with a bison / crow / lion starting there
##
## Dock index is the order a `D` is met scanning row-major, top-left first, so `battle.launch(0)` is
## the first `D` in that order. grid.gd is what records it; this file only holds the characters.
##
## Enemy placement here is measured, not eyeballed. Island 2's west crow sits where it can actually
## shoot a boat arriving at the north dock (the first draft put it 6.1 tiles away, where it could
## never fire), and island 3's ring interior was shrunk until the doorway became a front instead of
## a corridor. See the first slice plan, "The islands".


## `const X := PackedInt32Array([...])` is a parse error in GDScript 4.7, so this is a plain const
## Array of const Arrays and every read casts.
const ISLAND_ROWS := [
	# Island 1 — open grassland, 2 docks, 4 bison. Narrowest cut 9.
	# Nothing constrains you here; it is the baseline island 2 is measured against.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~............................~~",
		"~~............................~~",
		"~~............####............~~",
		"~~............####............~~",
		"~~..........B......B..........~~",
		"~~............................~~",
		"~~D..........................D~~",
		"~~............................~~",
		"~~..........B......B..........~~",
		"~~............####............~~",
		"~~............####............~~",
		"~~............................~~",
		"~~............................~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	],
	# Island 2 — a wall at columns 15-16 with a 2-tile neck, open on rows 8 and 9 only.
	# Narrowest cut 2. Four bison are parked just east of the neck, not further east: the garrison
	# has to be able to trade with the width of the front or the bottleneck constrains nobody.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~.............##.............~~",
		"~~.............##.............~~",
		"~~..C..........##.........C...~~",
		"~~.............##.............~~",
		"~~D............##.............~~",
		"~~.............##.B...........~~",
		"~~............................~~",
		"~~.................B..........~~",
		"~~.............##.B...........~~",
		"~~D............##.............~~",
		"~~.............##.B...........~~",
		"~~.............##.............~~",
		"~~.............##.............~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	],
	# Island 3 — a small ring with two 3-tile doorways, one per side. Narrowest cut 9.
	# The second doorway is not decoration: with only the left one the east dock spent 68.7 s of a
	# 90 s limit walking around the ring, a timeout trap nothing in the plan mentioned.
	#
	# Row 14 used to end in a `,` as bait for net_islands' legend-only check. The net was confirmed
	# red on it first — `섬 3 에 범례 밖 글자가 없다 ["(29,14)=','"]` — and only then fixed to `.`.
	# The check keeps a synthetic failing case of its own, so it is still one that has been seen bite.
	[
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~............................~~",
		"~~............................~~",
		"~~............................~~",
		"~~.........########...........~~",
		"~~.........#..C...#...........~~",
		"~~............................~~",
		"~~D...........L..............D~~",
		"~~........................C...~~",
		"~~.........#..B...#...........~~",
		"~~.........########...........~~",
		"~~............................~~",
		"~~..........B.................~~",
		"~~............................~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	],
]

## Seconds per island. The clock starts when the island OPENS, not on the first landing, so waiting
## for a full boat costs the same as a bad landing does.
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
