# The boring walk is cut out of the map — the spawn does not move east

**Status**: valid

## What was decided

Stage 1's left run is too long and flat (**"불의 룬을 얻으러 가는 과정이 재미없다"**), so **100 columns of
uniform flat are deleted from the terrain itself** and everything east of the cut shifts with it.
`Stage.SPAWN_TILE` stays where it is.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **Moving `SPAWN_TILE` east** instead of redrawing | Same walk, same seconds — and it leaves ~100 tiles of drawn, walkable, empty map **behind** the player. Nothing forbids walking back into it |
| Moving the spawn as the *cheap* option | **There is no net that asks what is under the spawn.** `stage.gd`'s own `SPAWN_TILE` comment records the map being repainted 312x126 → 400x48 while the constant stayed put, the character starting inside a sealed cave, and **"not one line of error is raised. The nets can't catch it either"**. The cheap edit is the one with no check on it |
| Calling the redraw "a day's work" | The user rejected that estimate outright. It is 100 columns of one repeated tile through the ASCII door (`tools/stage/paint_terrain_from_map.gd`), a bake, and re-typing ~20 `tx` numbers |

## What's tied to it

- **Every hardcoded stage-1 coordinate shifts −100 tiles.** `MAP_W`/`MAP_H` come from `get_used_rect()`, so
  erasing columns on the left re-origins the whole bake — game code and net literals alike.
  **The list below is the one the edit actually needed, not the one written before it.** The first draft of
  this row named six sites and there were ten; the four it missed are marked ⚠, and the reason each was
  missed is the useful part:

  | Site | |
  |---|---|
  | `stage.gd` `ROOM1_WATER_X0/X1` — room ①'s reward pour | game code |
  | `stage_gate.gd` `WALL_TILE_X0/X1` — room ③'s east wall | game code |
  | ⚠ `stage_gate.gd` **`SEAT_TILE_X`** — the ending arch's own column | game code. **Missed because the row above says "east wall"** and the seat is a different constant three lines up. Left alone it puts the arch **3,200px past the map's right edge** — the run's last square, unreachable |
  | `net_water_rain` `_MOUTH_X0/X1` | the constants are documented there, so it is the one everybody finds |
  | ⚠ `net_water_rain_cap` · ⚠ `net_water_rain_speed` | **Each keeps its own copy** of those two constants. Searching for where they are *explained* finds one file; searching for the values finds three |
  | ⚠ `net_monster_slam` | Pins room ①'s left wall **in cells** (1840/1900/1800), not tiles — a `tx`-shaped search does not see it |
  | `net_gate` · `net_monster_placement` | tile literals throughout |

  ⇒ **A hand-written blast radius is a guess until the edit is made.** Every one of the four surfaced as a
  red net or a wrong value, which is the system working — but the list claimed to be complete and was not.
- **The stairs are the water vessel's walls, not scenery.** The cut must translate them, never reshape them
- The floating bedrock slab at the old `tx149-150` is pinned twice as the proof `resolve()` scans **up**;
  it survives the cut and lands 100 tiles west

## Conditions to reopen

None. The reverse — restoring length — is a level-design question, not this fork.
