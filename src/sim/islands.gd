class_name Islands
## **The island — READ FROM A FILE, not written here.**
##
## ⚠⚠ **The letter grid is gone from this file** (2026-08-26, the user: ***"기존에 있던 거 때문에
## 네가 맵을 제대로 못 만든다. 지워버리자 일단 기존 거 좀"***). It used to be typed out as a `const`
## here and Blender read it to build the mesh — which is backwards the moment **the user is the one
## drawing islands.** The shape lived in the game and the picture only decorated it, so a shape the
## user changed in Blender could never reach the board.
##
## ⇒ **`tools/blender/island_build.py` is the source.** One run of it writes both
## `assets/terrain/island.glb` (what the game DRAWS) and `assets/terrain/island.json` (what the game
## WALKS ON). **They cannot disagree**, because nothing writes one without the other.
##
## ⚠ **Seven islands were deleted before this** — three hand-authored rectangles, one generated
## 144-wide map, four generated compact ones. The user could not draw eight, and that is why this game
## stands on one island.
##
## Legend (unchanged — `grid.gd` reads these same characters):
##   `~` water · `H` harbour (water a boat may sail from) · `.` land · `#` inland hole ·
##   `^` coastal cliff · `/` ramp · `W` `B` `C` `L` land with a wolf / bear / crow / lion on it
##
## ⚠⚠ **TIER BOARD — THE CHARACTER IS A NOTCH, NOT A STOREY, AND WRITING THE PLATEAU AS `1` BREAKS
## THE ISLAND IN SILENCE.** `grid.gd` reads these through `TIER_CHARS` / `TIER_LEVELS`:
##   `.` and `0` → level 0 (ground) · `1` → level 1 (**the stair**) · `2` → level 2 (**the plateau**)
##   `3` → level 3 (a stair to a third storey) · `4` → level 4 (a third storey) · and so on.
##   `/` is the OLD spelling of level 1 and still parses; the baked board no longer contains one.
##
## **One notch is half a tile. A storey is two notches. A stair is one notch** (2026-08-26, the user).
## So the storeys are the EVEN levels and the stairs are the ODD ones, and `Rules.MAX_CLIMB_LEVELS`
## is 1: a body crosses one notch and no more.
##
## ⚠⚠ **THIS IS WHAT "THE STAIR IS THE ONLY WAY UP" RESTS ON.** Write the plateau as `1` and it
## becomes one notch above the ground, a body walks up it anywhere along the cliff, no error is
## raised, no net goes red, and the second storey quietly stops being a place you have to earn.
## **This legend said `1` was the high ground until 2026-08-27 and it was wrong the whole time.**

const BOARD_PATH := "res://assets/terrain/island.json"

## ⚠ **Loaded once and cached.** `rows()` is called per island load and by a handful of nets; parsing
## the file each time would be work nobody asked for, and a `static var` is the only place a static
## class can keep it.
static var _board: Dictionary = {}
## **The two height numbers of the file, read out once beside it.** `ground_h` is asked per 조각 the
## press walk crosses and per sample the selection box takes — a few thousand times a second under a
## drag — and each ask was two dictionary reads through two more calls (measured 2026-09-02 at ~1 µs
## a call, most of a box sample's cost). Filled by `_load`, and by nothing else.
static var _base_h := 0.0
static var _level_h := 1.0


## ⚠⚠ **A missing or broken file is a HARD failure, not a silent fallback.** A default board here would
## let the game run on an island nobody authored while every check stayed green — and the whole point
## of this file is that the board the user drew is the board that is played.
static func _load() -> Dictionary:
	if not _board.is_empty():
		return _board
	var text := FileAccess.get_file_as_string(BOARD_PATH)
	assert(text != "", "island.json is missing — run tools/blender/island_build.py")
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "island.json is not an object")
	_board = parsed as Dictionary
	_base_h = float(_board.get("base_h", 0.0))
	_level_h = float(_board.get("level_h", 1.0))
	return _board


## The island's rows.
static func rows() -> Array:
	return _load()["rows"] as Array


## **The real coastline**, as flat `[ax, ay, bx, by]` quads in tile units. ⚠⚠ **Not the tile grid.**
## Coastal corners are cut and pushed when the island is built, so the line the mesh actually ends on
## stopped being the line between a land tile and a water tile. Anything drawing the shore reads THIS.
static func coast() -> Array:
	return _load().get("coast", []) as Array


## **What is already standing when the island opens**, as `{"kind": String, "x": int, "y": int}` with
## `x`/`y` the LOW corner of the building's footprint in tile coordinates.
##
## ⚠ Right now that is one keep and nothing else — the user: 「처음 집만 지어져 있고 나머지는 유저가
## 지을 거야」. Placed by the same run that shapes the ground, on the block of land nearest the middle.
static func builds() -> Array:
	return _load().get("builds", []) as Array


## **The tile the company already lives on** — the first building's low corner — or -1 when the island
## has no building at all.
static func home_tile() -> int:
	var b := builds()
	if b.is_empty():
		return -1
	var first := b[0] as Dictionary
	var stride := int(_load().get("w", 0))
	if stride <= 0:
		return -1
	return int(first.get("y", 0)) * stride + int(first.get("x", 0))


## **A tile just OUTSIDE the first building's footprint** — the doorstep — or -1 when there is no
## building. ⚠⚠ **Nothing marks a building's tiles impassable**, so anything placed on `home_tile`
## stands inside the house and cannot be seen; this is the wish a caller that wants somewhere to STAND
## should hand to a free-tile search.
## ⚠ `stride` comes from the caller's grid rather than the file, so a board and a grid that disagree
## fail here rather than silently naming a different tile.
static func beside_home_tile(stride: int) -> int:
	var b := builds()
	if b.is_empty() or stride <= 0:
		return -1
	var first := b[0] as Dictionary
	var span := Builds.footprint_of(str(first.get("kind", "")))
	var x := int(first.get("x", 0))
	var y := int(first.get("y", 0)) + maxi(span.y, 1)
	var rows_in := rows()
	if y >= rows_in.size():
		y = int(first.get("y", 0)) - 1
	if y < 0:
		return -1
	return y * stride + x


## **Every 조각 the 성채 covers**, empty when the island carries none.
##
## ⚠⚠ **FOUND BY KIND AND NOT BY BEING FIRST IN THE LIST.** `home_tile` above takes the first building
## because it is the doorstep of whatever the island opens with; **the thing the run is LOST with is the
## 성채 specifically**, and `Builds.KEEP` is the one place that word is spelled. The day a second
## building stands before it in the file, this keeps answering and that one moves.
##
## ⚠ **The whole footprint and not the corner**, because a 늑대 walks up to whichever side of it is
## nearest — a reach measured to the low corner alone would let one stand inside the far half of the
## house and swing at nothing.
## ⚠ `stride` is the file's own width here and not a caller's grid, unlike `beside_home_tile`: this
## answers 조각 numbers for the board the file describes, and a caller holding a different board has a
## bigger problem than a wrong index.
static func keep_tiles() -> PackedInt32Array:
	var out := PackedInt32Array()
	var stride := int(_load().get("w", 0))
	var tall := rows().size()
	if stride <= 0 or tall <= 0:
		return out
	for raw in builds():
		var row := raw as Dictionary
		if str(row.get("kind", "")) != Builds.KEEP:
			continue
		var span := Builds.footprint_of(Builds.KEEP)
		var x0 := int(row.get("x", 0))
		var y0 := int(row.get("y", 0))
		for dy in maxi(span.y, 1):
			for dx in maxi(span.x, 1):
				var x := x0 + dx
				var y := y0 + dy
				# Off the board is dropped rather than clamped: a clamped 조각 is a real 조각 somewhere
				# else, and a 성채 that could be hit from the wrong corner of the island is worse than
				# one that is a 조각 smaller than it is drawn.
				if x < 0 or y < 0 or x >= stride or y >= tall:
					continue
				out.append(y * stride + x)
		break
	return out


## **What is scattered on the ground** — trees, rocks, bushes — as
## `{"kind", "x", "y", "ox", "oy", "yaw", "scale"}`.
##
## ⚠ **Decided when the island is built, never at run time.** The same island always dresses itself the
## same way, so a screenshot is repeatable and a player who leaves and comes back finds it unchanged.
static func props() -> Array:
	return _load().get("props", []) as Array


## The island's height board.
static func tiers() -> Array:
	return _load()["tiers"] as Array


## **Loads the island into `grid` — terrain and height together.** ⚠⚠ **This exists because loading an
## island became TWO calls and five callers were still making one**: a grid loaded without its tier
## board comes up flat, draws, plays, and says nothing.
static func load_into(grid: Grid) -> void:
	grid.load_rows(rows(), tiers())
	# ⚠⚠ **THE DRAWN SHORE GOES IN WITH THE BOARD.** `load_rows` builds the 조각 tables and knows nothing
	# about where the mesh was actually cut; **the boats stop against the outline, not against the
	# 조각**, so the rule needs both and this is the one place that has both. ⚠ Set AFTER `load_rows`,
	# which does not clear it — see `Grid.coast`.
	grid.coast = coast()


## ⚠⚠ **THE ISLAND'S TIME LIMIT WAS DELETED 2026-08-27.** The loss it fed died on 2026-08-24 and the
## number stayed alive for three days on one argument: *`battle.setup` still takes one.* It took one
## because this existed. **Two dead things holding each other up is not a dependency, it is a loop**,
## and `setup` lost the parameter in the same commit that deleted this.
##
## ⚠ **A timer that DOES decide is coming and it is not this one**: 「제한 시간이 지나면 보스가 온다」.
## That clock belongs to the run, not to one island, and it produces a BOSS rather than a defeat — so
## it gets a fresh number when it is built, and reviving 20.0 would be reviving the wrong shape.

## The walking height of level `l`, in world units. **Read from the same file as the mesh**, because
## the mesh is authored: the game does not get to pick these, it has to agree with what was built.
## ⚠ Disagree and every body sinks into the ground — which is exactly what happened the first time the
## mesh was loaded.
static func ground_h(level: int) -> float:
	_load()
	return _base_h + float(level) * _level_h


## **How far the mesh's level-0 top sits above y = 0.** Not a design value — it is whatever the Blender
## run wrote, and it is here so the picture can stop guessing it.
##
## ⚠⚠ **`Grid.surface_h` does NOT include this and must not.** The sim measures heights in tiers off
## zero, and adding a mesh's offset to a walking rule would make the rule depend on how the art was
## authored. Anything that puts a THING ON the drawn ground adds this on top — see `field_view._stand_h`.
static func base_h() -> float:
	_load()
	return _base_h


## Every enemy on the island, as `{"type_id": int, "tile": int}` with `tile` a row-major index.
static func spawns() -> Array:
	var r := rows()
	# The stride comes from row 0, never from each row's own length: a short row would otherwise
	# renumber every tile below it into a plausible-looking index instead of failing loudly.
	var w := str(r[0]).length()
	var out := []
	for y in r.size():
		var row := str(r[y])
		for x in row.length():
			var type_id := spawn_type_of_char(row[x])
			if type_id >= 0:
				out.append({"type_id": type_id, "tile": y * w + x})
	return out


## --- the spawn characters ---------------------------------------------------------------------
## **One row per letter that puts a body on the ground: the character, and the `Rules.UNITS` row it
## is.** ⚠⚠ **THIS IS THE ONE PLACE A SPAWN LETTER IS BOUND TO ANYTHING.** `grid.land_chars()` reads
## this table, so **a letter that spawns a body is walkable ground by construction**.
## ⚠⚠ **`B` · `C` · `L` STOOD HERE AND ALL THREE ARE DELETED** (2026-08-31) with the rows they bound
## to — 곰 · 까마귀 · 사자. **The shipped island never used any of them**: its own letters are `H`,
## `~` and `.`, and even `W` is unused because the beasts come by boat.
## ⚠ **A letter here makes its tile walkable by construction** (`grid.land_chars()` reads this), so
## three letters leaving means three characters that no longer make ground. **Nothing on the board
## used them, so nothing on the board changed.**
const SPAWN_ROWS := [
	["W", Rules.WOLF],
]

const _SPAWN_COL_CHAR := 0
const _SPAWN_COL_TYPE := 1


## The `Rules.UNITS` row `ch` spawns, or **-1 for "this character spawns nothing"**.
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
static func spawn_char_of(type_id: int) -> String:
	for r in SPAWN_ROWS.size():
		if int((SPAWN_ROWS[r] as Array)[_SPAWN_COL_TYPE]) == type_id:
			return str((SPAWN_ROWS[r] as Array)[_SPAWN_COL_CHAR])
	return "."
