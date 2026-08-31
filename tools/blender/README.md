# tools/blender — the scripts that FIRST build a mesh, and `blend/` is where it lives afterwards

## ⚠⚠ **THE `.blend` IS THE ORIGINAL. THIS FOLDER IS NOT.** (2026-08-31, the user)

> ***"We have to work while saving the Blender original files too. It makes no sense. I have told you
> not to use the tool dozens of times. You have always ignored it and kept this going. It cannot keep
> going like this. You make a model and use it WITH an original file present — you leaving it as code
> on your own is completely unreasonable."***

**Every mesh now has a `.blend` in `blend/` and that file is the source of truth.** `boat.blend`,
`island.blend`, `buildings.blend`, `props.blend`, `boat_small.blend` were all saved 2026-08-31 out of
the very scripts below, so the two agree today and the `.blend` is the one that carries on.

⚠⚠ **THIS PAGE SAID THE OPPOSITE FOR FIVE DAYS AND THAT LINE IS WHY THE INSTRUCTION KEPT BEING
IGNORED.** It read *"Every mesh in this game is generated. No `.blend` exists"*, so every session that
opened it re-derived the same wrong behaviour from the doc rather than from the user. **A rule the user
has overturned is deleted from the page, not argued with in it.**

### What this changes about how a shape is edited

| | Before | **Now** |
|---|---|---|
| **Change a boat's length** | edit a number in `boat_build.py`, re-run it | **open `blend/boat.blend` and move it** |
| **Who can do it** | ⚠ only a session with the MCP | **the user, with a mouse** |
| **What is exported** | the script exports on its way past | **export the `.glb` out of the `.blend`** |

⚠⚠ **THE COST THE USER NAMED, IN THEIR WORDS**: *"if I can't touch it with a mouse that's a disaster —
are you going to do it all? You can't do it all, and in the end I'll be the one touching the detail."*
**A mesh only a script can change is a mesh only the model can change**, and the detail work is the
user's.

⚠ **The scripts are kept and are still true.** They are how each of these was first built and they hold
the measured reasons for the numbers — the sheer's planarity argument, the collinear stations, the
winding rules. **Read them to understand a shape. Do not re-run one to edit a shape**, because that
overwrites whatever the user did by hand in the `.blend`.

⚠ **One mesh genuinely still needs its script: the island.** `island_build.py` writes `island.json`
beside the mesh — the passability, the levels, the harbours and the coast the game reads — and no
`.blend` carries that. **Say this rather than quietly regenerating.**

⚠⚠ **This folder used to be an agent's** (`sculpt`, 2026-08-27 to 2026-08-29). **The main session does
Blender work again** — the agent did the work and twice sent back no result, so it was measured by hand
anyway. **What it knew is this page**, and reading it is the step that used to be delegated.

| Script | What it builds |
|---|---|
| `island_build.py` | **The island** — blocks, stair, coastline, and the `island.json` the game reads |
| `buildings_build.py` | Keep, house, tower, store, wall |
| `props_build.py` | Trees, rocks, bushes |
| `blocks_explode.py` | The ten blocks laid out side by side, for looking at one at a time |
| `send.py` | ⚠⚠ **The MCP path. Read the trap below before using anything else** |
| `bake_island.ps1` | **Bake · clear the cache · re-import · verify.** The only supported way to bake |

## The five traps, all measured, each one cost a round

⚠⚠ **1. The `mcp__blender__*` tools WORK. Use them first.**
**Measured 2026-08-30**: `get_scene_info` came back with 29 objects and 56 materials, and
`execute_blender_code` ran Python and returned its stdout — **Blender 5.1.1, Python 3.13.9.**
⚠⚠ **This paragraph said the opposite for four days and it was wrong.** The port-9876 protocol clash was
real on 2026-08-26 and **the user fixed it**; nobody re-tested, so the warning outlived the fault and a
session went on hand-rolling what the tools already did. **A doc saying a tool is broken is a doc to
re-test, not to quote.**
⇒ **`send.py` is the fallback**, and it now speaks the same protocol the tools do.

⚠⚠ **2. Godot serves a CACHED island and says nothing.**
Blender writes `assets/terrain/island.glb`; Godot reads its own converted copy under `.godot/imported/`,
and a `--script` run does **not** re-convert a changed source. **Three bakes in a row came back identical
on 2026-08-27** and the third was investigated as a modelling bug — the source was minutes old and the
screen was drawing the previous evening's island.
⇒ **Always bake with `.\tools\blender\bake_island.ps1`.** It bakes, clears the cache, re-imports, and
**errors out if Godot's copy is older than the source.** A bake that skipped it is not evidence.

⚠ **3. Winding decides whether a face exists at all.**
The materials cull back faces, so a quad wound the wrong way is simply not drawn — a stair looked like an
empty notch for a whole round. Winding also decides COLOUR: `_paint` calls a face steep when its normal's
z is low, so a floor facing down comes out as rock.
**After any new face: render it and look. A face you did not see is a face that is not there.**

⚠⚠ **4. Never swallow a geometry failure.**
`try: bm.faces.new(...) except ValueError: pass` hid a missing wall and left a hole you could see the sea
through. **Nothing pretends to work.** Prefer plain quads over n-gons — they cannot fail the way a profile
polygon can.

⚠ **5. `island_build.py` rebinds `ax, ay = corner_xy(...)` deep inside `build_island`.**
**Do not name a local `ax`.** The file already carries a comment about this exact trap for a different
name, and it was walked into anyway.

## The mirror rule

**`stair_runs()` here and `Grid._build_runs()` in `src/sim/grid.gd` compute the same thing** — which tiles
form a stair, which way it climbs, how long the run is. One draws the surface; one tells the game where a
body's feet go. ⚠⚠ **If they disagree, bodies walk through the staircase.** Change one, change the other
in the same edit.

## The loop

1. **Read the ticket** if one is named. The user's own words about the look are a measurement.
2. **Change the script, not the scene.** The scene is thrown away every bake.
3. **Bake through `bake_island.ps1`.**
4. **Look at it** under the GAME's light, never Blender's — `tools/look/piece_viewer.gd`. Its sun,
   ambient, camera and outline pass are copied from `field_view.gd` line for line, because **a value that
   reads correctly in Blender goes wrong in the game** and ticket 01 records six rejected rounds of it.
   ```
   .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/look/piece_viewer.gd -- --glb res://assets/terrain/island.glb --at X,Z --zoom N --shot1
   ```
   ⚠ **Aim wide before you zoom.** A close-up of the wrong tile has been mistaken for a failed bake.
5. **Measure, do not assume.** A render is evidence of a picture; a number is evidence of a shape.
6. **Run the nets** and compare the pass count to what it was before you started.

## The numbers

- The island is **one mesh, 1100 vertices, 1224 triangles, one draw call.** Nothing here is a performance
  problem, and optimisation is not a reason to change the approach.
- **A notch is half a tile · a storey is two notches · a stair is one notch.** Storeys are the EVEN levels,
  stairs the ODD, and a body crosses one notch and no more.
- **A stair run spans exactly one storey however many tiles long it is.** One tile of run is 45°, two is
  26.6°, and a real staircase is 30 to 37.
- Tier characters: `.` and `0` are level 0 · `1` is the stair · `2` is the plateau · `/` is an old spelling
  of level 1. ⚠ **Writing the plateau as `1` makes it climbable from anywhere and raises no error.**

⚠ **Gameplay rules are not built here.** `src/sim/` decides what a body may do; this folder decides what it
looks like. The one overlap is the mirror rule above.
