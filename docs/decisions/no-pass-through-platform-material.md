# The shelves are ordinary `STONE` — there is no sixth, pass-through material

**Status**: valid

## What was decided

A platform you can jump up through and stand on was considered for the left run's shelves and dropped.
Shelves are `STONE`, like everything else, and filling them solid to the ground is what makes that survivable —
there is no under-space for the solid/pass-through distinction to matter in.

## What wasn't chosen

| Rejected | Why |
|---|---|
| **A one-way platform material** | **`is_solid()` is binary and derived** — `cell_grid.gd` is `_behavior[mat_at(x,y)] == BEHAVIOR_STATIC`. One-way is not binary: solid to feet falling, empty to a body rising or passing sideways. That needs a third behavior **and every physics reader to learn the direction of travel** — grounding, `box_free`, `move_x`/`move_y`, `monster_placement.resolve`, `monster_bolts`, `staff`. **A sim-wide axis inside the integer-determinism folder, for one platform** |
| The same, on authoring cost | `terrain_baker.gd`'s `CHAR_BY_MAT`/`NAME_BY_MAT` both grow (the baked map's own header names them as the two tables to extend), plus rebuilds of the terrain atlas and tileset and an `--import` pass |
| **"There are no palette slots"** — the reason an earlier draft gave | **Wrong, and recorded so it is not repeated.** `cell_grid.gdshader` fixes `uniform vec4 palette[16]` and `cell_materials.ALL` uses **5**. Eleven slots are free. The cost was never the palette |

## What's tied to it

- **Shelves must be filled solid to the ground.** A floating one-tile slab is what would have needed
  pass-through to be tolerable
- `src/sim/` stays untouched by the left-run work — no new material, no new integer axis

## Conditions to reopen

A feature that needs one-way terrain **in more than one place**. One platform never pays for a sim-wide axis.
