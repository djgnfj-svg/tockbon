# Working in Blender — read this before touching a shape

**Every mesh in this game has a saved `.blend` in `blend/`, and that file is the original.**
Open it, change it, export from it. **There is no build script to re-run** — `tools/blender/` was
deleted 2026-08-31 once the originals existed.

> ***"We have to work while saving the Blender original files too. You make a model and use it WITH an
> original file present — you leaving it as code on your own is completely unreasonable."***
> (2026-08-31, the user)

⚠⚠ **The reason the rule is written here and not in a folder of scripts**: the old
`tools/blender/README.md` asserted the opposite — *"Every mesh in this game is generated. No `.blend`
exists"* — and every session re-derived that behaviour from the doc instead of from the user. **One
page, and it says the true thing.**

## The originals

| File | What is in it |
|---|---|
| `blend/island.blend` | The island as one mesh, **plus its 32 block parts standing separately** |
| `blend/boat.blend` | Hull · gunwale · deck · mast · yard · sail · stem · stern post · four benches |
| `blend/buildings.blend` | Keep · house · tower · store · wall |
| `blend/props.blend` | Pine · tree · rock · stone · bush |
| `blend/boat_small.blend` | The small boat |

## The loop

1. **Open the `.blend`** — `bpy.ops.wm.open_mainfile(filepath=...)` through the MCP, or by hand.
2. **Change the shape.** ⚠ The user does detail work here with a mouse; leave the file in a state they
   can open.
3. **Export the `.glb`** into `assets/` over the file that is already there. Keep the same name —
   `assets/props/boat.glb`, `assets/terrain/island.glb`, `assets/buildings/buildings.glb`,
   `assets/props/props.glb`.
4. **Save the `.blend` back.** ⚠⚠ **An export is not a save.** A shape that only exists in a `.glb`
   is a shape nobody can edit again, which is the whole failure this page exists to stop.
5. **Re-import, or Godot draws yesterday's mesh** — see the trap below.
6. **Look at it under the GAME's light**, never Blender's: `tools/look/piece_viewer.gd`. Its sun,
   ambient, camera and outline pass are copied from `field_view.gd` line for line, because **a value
   that reads correctly in Blender goes wrong in the game.**

## Reaching Blender

**The `mcp__blender__*` tools work.** `execute_blender_code` runs Python inside the running Blender and
returns its stdout; `get_scene_info` lists the scene. Measured 2026-08-31 on **Blender 5.1**.

⚠ **A doc that says a tool is broken is a doc to re-test, not to quote.** This page said the MCP was
unusable for four days after the user had already fixed it, and a session hand-rolled what the tools
already did.

## The four traps, each one measured and each one cost a round

⚠⚠ **1. Godot serves a CACHED mesh and says nothing.**
Blender writes the `.glb`; Godot reads its own converted copy under `.godot/imported/`, and running the
game does **not** re-convert a changed source. **Three bakes in a row came back identical on
2026-08-27** and the third was investigated as a modelling bug — the screen was drawing the previous
evening's island.
⇒ **Re-import before believing anything you see:**
```
.\Godot_v4.7.1-stable_win64.exe --headless --path . --import
```

⚠⚠ **2. TWO `.json` FILES SIT BESIDE THE MESHES AND NO `.blend` CARRIES THEM.**

| File | What it holds | Who reads it |
|---|---|---|
| `assets/terrain/island.json` | passability · levels · harbours · the coast | `Islands` — **the game's whole idea of the ground** |
| `assets/buildings/buildings.json` | each building's kind, footprint in 조각, and name | `Builds` — how many 조각 a keep covers |

**Move a block in `island.blend` and the mesh changes while the game's idea of the ground does not** —
bodies will walk through walls or refuse open ground. **Resize a building and its footprint still says
the old size.**
⇒ **Say this out loud before reshaping either.** ⚠ `Builds` treats a missing `buildings.json` as a hard
failure by design, so it will not silently limp.
⇒ The deleted `island_build.py` and `buildings_build.py` are recoverable from git at **`16e2e2fa`** if
a data file ever has to be rebuilt.

⚠ **3. Winding decides whether a face exists at all.**
The materials cull back faces, so a quad wound the wrong way is simply not drawn — a stair looked like
an empty notch for a whole round. Winding also decides COLOUR: a face is called steep when its normal's
z is low, so a floor facing down comes out as rock.
⇒ **After any new face: render it and look. A face you did not see is a face that is not there.**

⚠ **4. The stair is computed twice and the two must agree.**
`Grid._build_runs()` in `src/sim/grid.gd` works out which tiles form a stair, which way it climbs and
how long the run is — **the same thing the island's geometry says.** One draws the surface; one tells
the game where a body's feet go. **If they disagree, bodies walk through the staircase.**

## The numbers that constrain a shape

- **A notch is half a 조각 · a storey is two notches · a stair is one notch.** Storeys are the EVEN
  levels, stairs the ODD, and a body crosses one notch and no more.
- **A stair run spans exactly one storey however many 조각 long it is.** One 조각 of run is 45°, two is
  26.6°, and a real staircase is 30 to 37.
- **The island is one mesh, ~1100 vertices, one draw call.** Nothing here is a performance problem, and
  optimisation is never a reason to change the approach.
- **The boat's length and beam are a RULE, not a picture** — `Rules.BOAT_HULL_HALF_TILES` (2.1) and
  `BOAT_HULL_BEAM_TILES` (2.01) are the mesh's own box read back, and the sim beaches every boat off
  them. ⚠ **Change the hull's length and change that constant in the same edit**, or the boat stops
  short of the sand.
