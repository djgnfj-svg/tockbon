# The town is a second map inside the stage shell, not a scene of its own

**Status**: valid

## What was decided

`stage.gd` grew one flag (`_in_town`) and `build_terrain_into` was split into `build_map_into(g, map, chars)`.
The town is the same scene, the same camera, the same character, the same grid — with a different map built
into it and one extra view node.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A `town.tscn` of its own** | It would duplicate the camera, the HUD, the character view, the input node and the tick loop. `stage.gd` is 1000 lines and **the shell will not survive into the real game** (its own first line) — building a second copy of a thing already marked for deletion doubles what has to be thrown away, and the two would drift in the meantime |
| **A smaller town map** (a 40x14 room, not 400x48) | The camera clamps to **the grid**, not the map (`stage.world_size`), so a small map leaves the player able to walk off the drawn area into nothing. Filling the rest with bedrock costs 48 `cmd_fill` commands, because a solid row bundles into one |
| **Painting the town in the editor** like the stage map | A room of four straight walls has nothing for the mouse to add, and going through `bake_terrain.gd` would mean the town could not be edited without opening the editor. It is four numbers generating its rows instead |
| **Research and assembly as real windows** | Both need tables that do not exist (the point budget, material counts, prices — all open TBDs in `town.md`). A window with buttons that spend nothing would be "reporting a stub as finished" |

## What's tied to it

- **`build_map_into` is the shared builder.** Anything that adds a room goes through it, and the run-bundling
  optimisation lives in one place
- **`stage.build_terrain_into` keeps its old name** because `net_tables` and `net_water_rain` call it to stand
  up the real stage 1; a net that had to pass a map in could be handed the wrong one
- **`_in_town` is the only latch.** Which map builds, where the character lands, whether the fixtures draw and
  what E does are all derived from it. A second copy anywhere means "the town is drawn over stage 1"
- If this reverses, `_build_room()` and `_interact()` are what move out of the shell

## Conditions to reopen

**When the shell is replaced.** `stage.gd` is explicitly temporary; whatever replaces it decides scene layout
from scratch, and this decision does not survive that. Also reopen if the town stops being one room — a town
with buildings you enter is a scene-per-place problem, not a map-per-mode one.
