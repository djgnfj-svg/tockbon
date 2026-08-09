extends RefCounted
## **The town — one walkable room, all bedrock** (`docs/design/town.md`, "Form — you walk. One room").
##
## **The same shape as `terrain_map_generated.gd`, and read by the same builder** (`stage.build_map_into`).
##  The stage's map is painted in the editor and re-exported; this one is written by hand, because a room of
##  four straight walls has nothing for the mouse to add and going through the baking tool would mean the
##  town could not be edited without opening the editor.
##
## **Every cell is bedrock.** That is the design's own answer to "the town gets dug up and would need repair
##  every run" — **not a new rule**: stage 1's pit ① is already a bedrock bowl that blasts cannot breach.
##  ⇒ **Casting in town is not blocked.** Messing around is fine; nothing changes shape.
## **There is nothing burnable.** Bedrock has no fuel, and the moment a wooden decoration goes in, "repair per
##  run" has to be decided (`town.md`'s own open TBD). Do not paint a `=` into this map before that.
##
## **The room is the same tile size as the stage map on purpose.** The camera clamps to the grid, not to the
##  map (`stage.world_size`), so a smaller map would put the room in a corner of a much larger empty world and
##  the player would walk off the drawn area into nothing. Filling the rest with bedrock costs 48 commands —
##  `build_map_into` bundles runs of the same character, so a solid row is one command, not 400.

const TerrainMap := preload("res://src/stage/terrain_map_generated.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")

## **Taken from the stage map, not written again.** `net_town` measures that the two agree — the reason is in
##  the header (the camera clamps to the grid and a mismatch puts the room somewhere the player can leave).
const MAP_W: int = TerrainMap.MAP_W
const MAP_H: int = TerrainMap.MAP_H
## **`B` only.** The stage's table has `#`/`=`/`~` as well; the town's does not, and that is the
##  "nothing burnable, nothing diggable" rule made unwritable rather than merely undone.
const MAP_CHARS: Dictionary = {"B": Mat.BEDROCK}

## The hollow room, in tiles. **The floor is `ROOM_Y1 + 1`** — the room's rows are the empty ones.
##
## **The floor sits exactly on `fx_tuning.BG_NEAR_GROUND_Y` (640px = tile row 20), and that is not a
##  coincidence — it is the whole reason the town has a sky.**
##  The room was first cut at rows 30-41 and the town rendered as a **black box with the backdrop swapped in
##  and doing nothing.** `sky_background` clamps the far picture at `BG_UNDER_TOP_Y` (the same 640) and fills
##  everything below it with `BG_UNDER_BANDS` — the underground depth fill. A room at row 30 is **underground
##  by that definition**, so the town's own two pictures were drawn and then covered by rock-coloured bands.
##  **Nothing barked**: the art loaded, `set_backdrop` ran, the constants were right, and the screen was black.
##  ⇒ **Move this and the sky goes away again.** If the room ever needs to be deeper, `background.md` has to
##  answer "what is behind a town below the ground line" first.
const ROOM_X0 := 6
const ROOM_X1 := 45
const ROOM_Y0 := 8
const ROOM_Y1 := 19

## Where the character lands when they arrive. **Left end of the room, on the floor** — the same idiom as
##  `stage.SPAWN_TILE`, and it faces the three fixtures, which stand to the right.
## **The value is a tile, and the room is a hand-written constant above, so this cannot drift the way
##  `SPAWN_TILE` did** (that constant's own story: the map was repainted and the spawn fell into a sealed
##  cave). `net_town` measures that this tile is inside the room anyway.
const SPAWN_TILE := Vector2i(ROOM_X0 + 2, ROOM_Y1)

## **Fixture seats, in tiles.** Level content, so it lives with the map and not with the machine that reads it
##  (`fixtures.gd`'s own header).
##
## **Spread across the room, not lined up by the door.** Walking between them is the point — a town whose
##  three fixtures are within one screen-width of the spawn is a menu with a floor
##  (`town.md`, "if a roguelike's home is a menu, the space between runs is just a loading screen").
## **The gate is at the far end**, so leaving is a decision you walk to. The order along the room —
##  research, assembly, gate — is the order of a run's preparation.
const FIXTURE_TILES: Dictionary = {
	Fixtures.KIND_RESEARCH: 14,
	Fixtures.KIND_ASSEMBLY: 26,
	Fixtures.KIND_GATE: 42,
}


## The map rows, built once. **A function and not a `const` array**: writing 48 rows of 400 characters by
##  hand is exactly the kind of thing that gets one row wrong and is never noticed, and the room is four
##  numbers, not a picture.
static func rows() -> Array[String]:
	var out: Array[String] = []
	for ty in MAP_H:
		if ty < ROOM_Y0 or ty > ROOM_Y1:
			out.append("B".repeat(MAP_W))
			continue
		out.append("B".repeat(ROOM_X0)
			+ ".".repeat(ROOM_X1 - ROOM_X0 + 1)
			+ "B".repeat(MAP_W - ROOM_X1 - 1))
	return out


## Fixture seats as **world px centres**, which is what `Fixtures.at()` takes. The `+ 0.5` puts the seat at
##  the middle of its tile rather than its left edge — off by half a tile, the prompt appears a step before
##  the fixture looks reached.
static func fixture_seats() -> Dictionary:
	var out: Dictionary = {}
	var tile_px := float(Tuning.TILE_CELLS * Tuning.CELL_PX)
	for kind: int in FIXTURE_TILES:
		out[kind] = (float(FIXTURE_TILES[kind]) + 0.5) * tile_px
	return out
