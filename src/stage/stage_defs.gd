extends RefCounted
## **The room table — one row per room the shell can build.** `stage.gd._apply_room()` reads a row and
## nothing else; every `if _in_town` that used to pick between two rooms is a lookup here now.
##
## **Why this file exists**: before it, "which map · where you land · which monsters · where the gate is ·
##  what the clear screen is titled" were five constants in five files, each selected by one `bool`. Adding
##  a second stage meant finding all five. **Now it is one row.**
##
## **Map height is global at 48 tiles. Width is per-stage.** That is a decision, not an accident — the town's
##  own dimensions, `fx_tuning.BG_UNDER_BOTTOM_Y`/`CELL_DEPTH_SPAN` and `stage1_monsters.FLOOR_CY` all hang
##  off `TerrainMap.MAP_H`, and 48 tiles is deep enough for a water stage. `stage.build_map_into()`'s height
##  guard **enforces** it; that guard's own comment carries the rest.
##
## **`src/actor/` never learns a stage's name.** Everything here is *pushed* into the machine by the shell —
##  `WorldStep.set_placement(rows, floor_cy)` is the model, and `StageGate.set_geometry()` (added for this
##  table) is the second one. The folder contract stays exactly as it was.
##
## **`const`, not `static var`** — this is map content, the same shelf `terrain_map_generated.gd` and
##  `stage1_monsters.gd` sit on, and being `const` is why `net_pick`'s no-inventory scan (anchored on
##  column-0 `var`) never has to carry an exemption for it.

const TownMap := preload("res://src/stage/town_map.gd")
const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const Stage1Monsters := preload("res://src/stage/stage1_monsters.gd")
const StageGate := preload("res://src/actor/stage_gate.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## Room ids. **The town is row 0 and the stages start at 1**, so "which stage am I on" reads as itself and
##  `ROOM_TOWN` is not a stage that happens to be numbered.
const ROOM_TOWN := 0
const STAGE_1 := 1

## **The character's starting position for stage 1 (tiles). On the ground at the left end of the map.**
##
## **Redraw the map and this value must be fixed with it — nobody barks.**
## It actually happened: the map was redrawn 312x126 -> 400x48 while this constant stayed `(3, 30)`, so
##  **y30 fell below the ground surface (y20)** and the character started by **dropping onto the floor of a
##  sealed underground cave (y44).** The reachable range confirmed by BFS was **a single row of cave floor**,
##  and a 6-tile crust cannot be pierced with `carve_r` (2 cells).
##  => **Launch the game and the surface is never seen at all. Not one line of error is raised.**
## `net_tables._the_stage_spawn_is_on_ground_and_connected_to_the_bull` is what catches it now — it was
##  written the day that accident was written down.
const STAGE1_SPAWN_TILE := Vector2i(3, 19)

## **The floor row every placement scan starts from, in cells. Global, not per-stage** — it derives from the
##  map height, and the height is the global above. Re-exported rather than re-derived, so the two cannot
##  diverge (`stage.gd`'s own `MAP_W`/`MAP_H` re-exports are the same idiom).
const FLOOR_CY: int = Stage1Monsters.FLOOR_CY

## **A typed empty, not a bare `[]`.** `WorldStep.set_placement()` takes `Array[Dictionary]`, and a const
##  Dictionary cannot carry the `as Array[Dictionary]` cast the old `_build_room()` line used.
const NO_MONSTERS: Array[Dictionary] = []

## **No gate.** The town has none; a stage without one would say so the same way. `_apply_room()` reads
##  `is_empty()` and pushes nothing — see its own comment for what that leaves standing.
const NO_GATE: Dictionary = {}

## **One row per room. Every key below is read by `stage.gd._apply_room()` and nowhere else.**
##
## | key | what it is |
## |---|---|
## | `map` | a script exposing `static func rows() -> Array[String]`. Both map scripts have one |
## | `chars` | that map's character -> material table |
## | `spawn` | where the character lands, in tiles |
## | `monsters` | the `(tx, kind)` placement table (`stage1_monsters.gd`'s shape) |
## | `gate` | the six tile numbers of the stage's exit, or `NO_GATE` |
## | `title` | what the settlement screen is titled when this room is cleared |
##
## **Adding a stage is adding a row.** If that ever stops being true — if one more file has to be touched —
##  that is the bug this table exists to prevent, and `net_stages` is where it gets caught: it drives
##  `_apply_room()` with a **synthetic row** whose every field differs from stage 1's and asserts every one of
##  them actually reached the world. A field left reading stage 1's constant does not follow the synthetic
##  row, and that check goes red.
##
## **The gate numbers still live in `stage_gate.gd` for stage 1 only**, referenced here rather than copied —
##  see that file's `STAGE1_*` block for why they could not simply move, and what it costs.
const ROWS: Array[Dictionary] = [
	{
		"map": TownMap,
		"chars": TownMap.MAP_CHARS,
		"spawn": TownMap.SPAWN_TILE,
		"monsters": NO_MONSTERS,
		"gate": NO_GATE,
		# **The town is never "cleared"** — you walk back into it, you do not finish it. The settlement
		#  screen cannot open here at all (`_sync_settlement`'s own `not _in_town` term).
		"title": "",
	},
	{
		"map": TerrainMap,
		"chars": TerrainMap.MAP_CHARS,
		"spawn": STAGE1_SPAWN_TILE,
		"monsters": Stage1Monsters.ROWS,
		"gate": {
			"seat_tx": StageGate.STAGE1_SEAT_TILE_X,
			"floor_ty": StageGate.STAGE1_FLOOR_TILE_Y,
			"wall_tx0": StageGate.STAGE1_WALL_TILE_X0,
			"wall_tx1": StageGate.STAGE1_WALL_TILE_X1,
			"wall_ty0": StageGate.STAGE1_WALL_TILE_Y0,
			"wall_ty1": StageGate.STAGE1_WALL_TILE_Y1,
		},
		# **The stage's name on the clear screen comes from here, not from `fx_tuning`.** The constant is
		#  still where the string lives (it is presentation text), but *which* stage's string the panel shows
		#  is a property of the stage — `SETTLEMENT_NOTICE_2` deliberately stays out of this table, because
		#  "stage 2 does not exist yet" is a statement about the build, not about stage 1.
		"title": Fx.SETTLEMENT_TITLE_CLEAR,
	},
]

## Every key a row must carry. **Named here so a row that forgets one is caught by name** rather than by a
##  null deref three files away — `net_stages` walks this against every row.
const REQUIRED_KEYS: Array[String] = ["map", "chars", "spawn", "monsters", "gate", "title"]

## Every key a `gate` must carry when it is not `NO_GATE`.
const GATE_KEYS: Array[String] = ["seat_tx", "floor_ty", "wall_tx0", "wall_tx1", "wall_ty0", "wall_ty1"]


## **The one door.** An id outside the table barks and falls back to the town rather than returning an empty
##  Dictionary — an empty row would build no map at all and read on screen as "R did nothing", which is the
##  exact silent shape this repo keeps getting bitten by.
## The bark's text is matched by `net_stages`' own `t.expect_error` — the two are one unit (CLAUDE.md).
static func row(id: int) -> Dictionary:
	if id < 0 or id >= ROWS.size():
		push_error("no room %d in the table - it has %d rows" % [id, ROWS.size()])
		return ROWS[ROOM_TOWN]
	return ROWS[id]


## The row's map, as the builder wants it. **Both map scripts expose `rows()`** — the town's builds its four
##  numbers into 48 strings, the stage's returns its baked `MAP` verbatim (the baker emits that function).
##  Without the shared name this would be a `match` on the id, which is one more place to edit per stage.
static func map_rows(room: Dictionary) -> Array[String]:
	var src: Variant = room["map"]
	return src.call("rows")
