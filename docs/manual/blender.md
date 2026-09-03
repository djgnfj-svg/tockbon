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
| `blend/island.blend` | `island` (22,075 verts) · `pads` (11,480 verts) · **the 31-block kit standing separately** — see the section below. **33 objects in all** |
| `blend/boat.blend` | Hull · gunwale · deck · mast · yard · sail · stem · stern post · four benches |
| `blend/buildings.blend` | Keep · house · tower · store · wall |
| `blend/props.blend` | Six trees · a stump · rock · stone (a pebble) · the 철광석. ⚠⚠ **The bush is NOT here** — it is a picture, `assets/props/flat/lp_bush_v*.png`, drawn by `src/view/prop_card.gdshader`. **A prop kind is a node in this file OR a PNG in that folder, and the mesh wins**, so moving a thing from 3D to 2D is deleting it from here |
| `blend/boat_small.blend` | The small boat |

## The block kit — **31 blocks in `island.blend`, and this is where they are**

**They are objects in `blend/island.blend`, standing beside `island` and `pads`.** The name is the
address: **`KIT_<level>_<kind>_<n>`** — `KIT_0_edge_18`, `KIT_2_corner_5`. ⚠ **`<n>` is a running index
over the whole kit (0..30), not a count within its kind**, so `KIT_0_solid_25` is the 26th object and
not the 26th solid.

| Kind | level 0 | level 2 |
|---|---|---|
| `solid` | 3 | 1 |
| `edge` | 6 | 3 |
| `corner` | 4 | 4 |
| `strait` | 3 | 1 |
| `cape` | 3 | 1 |
| `islet` | 1 | 1 |
| **total** | **20** | **11** |

**What every one of them shares**: it sits at the ORIGIN, spans **±1.0** (one 칸), and carries a
vertex-colour layer named `Col`.

⚠ **The coastal skirt out to ±1.25 is on SEVENTEEN of the thirty-one and not on all of them** —
measured 2026-09-03. It is on every level-0 block that has a water-facing edge (`edge` · `corner` ·
`strait` · `cape` · `islet`), and on nothing else: **the three level-0 `solid` and all eleven level-2
blocks stop dead at ±1.0.** A plateau ends in a cliff and has no hem running down into the water, which
is the deleted bake's own rule — the skirt hangs on coastal sides only.

⚠⚠ **There is NO STAIR in the kit.** The six kinds are all flat floors, and a generated island needs
one to three stairs because **a stair is the only way up between storeys**. The drawn island's stair
is welded inside the `island` mesh — the deleted bake built it in place, tread by tread — so there is
no block to stand. **Cutting one out of `island` is the cheapest way to get it, and it keeps the shape
the user already passed.** ⚠⚠ **None has a UV layer and none has
a material** — the colour is on the vertices and nothing else. `pads` is the opposite and carries two
UV layers, `UVMap` and `UVMap.001`.

**Height**: level 0 spans z **−0.12 .. 0.21**, level 2 spans z **−0.12 .. 1.21**.

**Vertices per block**, and they rise with how much coast the block has:

| | `solid` | `edge` | `strait` | `corner` | `cape` | `islet` |
|---|---|---|---|---|---|---|
| level 0 | 33 | 105 | 177 | 225 | 345 | 513 |
| level 2 | 65 | 147 | 229 | 291 | 435 | 641 |

⇒ **`assets/terrain/pieces.glb` is these 31 blocks exported**, and it is what `tools/look/piece_viewer.gd`
opens by default. ⚠ **It is re-bakeable** — export the `KIT_*` objects out of `island.blend` again.

## ⚠⚠ Four rules the code pairs with GEOMETRY, and nothing can check them but an eye

**The bake used to be a Python file and `src/` cited it by name in fourteen places.** Those citations
were repointed here on 2026-09-03; the rules themselves did not move, they simply stopped being code.
**Each of these is a number or an order written down in `src/` whose other half is the way a part is
actually CUT in `blend/island.blend`** — change one side and the game and the picture disagree with
nothing going red.

| The code says | The geometry has to match |
|---|---|
| `Grid.STAIR_MOUTH_ORDER` — west, east, north, south, lowest 조각 index first | Which side of a corner staircase is its MOUTH. Get it wrong and the body walks ACROSS the treads instead of up them — 2026-08-28, the user: 「계단 이동할때 뚫는거 같은데」 |
| `Rules.STAIR_TREADS` = 6 | How many steps are cut into the staircase part |
| `Rules.TIER_STEP_TILES`, and `level_h` in `island.json` | How tall one 눈금 is in the mesh. Disagree and every body sinks into the ground |
| `Rules.BLOCK_TILES` = 2, and the outline turning on even tiles only | The parts are 2.0 wide. **The day a part stops being 2x2, `Grid.block_of` is wrong and nothing else is** |

⚠ **The water was baked at 0 and the game raised its sea to `SEA_Y_TILES` = +0.075** (2026-08-28, the
user: 「물 높이를 좀 더 올려줄래?」). The exported waterline and the drawn one are half a tile apart on
purpose; `look.gd` carries the note.

## The loop

1. **Open the `.blend`** — `bpy.ops.wm.open_mainfile(filepath=...)` through the MCP, or by hand.
2. **Change the shape.** ⚠ The user does detail work here with a mouse; leave the file in a state they
   can open.
3. **Export the `.glb`** into `assets/` over the file that is already there. Keep the same name —
   `assets/terrain/island.glb` (`island` + `pads`), `assets/terrain/pieces.glb` (the 31 `KIT_*` blocks),
   `assets/props/boat.glb`, `assets/props/boat_small.glb`, `assets/buildings/buildings.glb`,
   `assets/props/props.glb`. ⚠ **`island.blend` exports TWO files**, and re-baking one does not re-bake
   the other.
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

## ⚠⚠ Why the originals sit in their OWN folder and not beside the `.glb`

**Godot scans the whole project and tries to import every `.blend` it finds.** Measured 2026-08-31,
with the five originals in place:

```
ERROR: Blender path is invalid or not set, check your Editor Settings.
       Cannot configure blender path in headless mode.
```

It caught all five, one at a time, and failed on each. **The only way to stop it is `.gdignore`, and
that marks a WHOLE folder** — so it cannot be used in `assets/props/`, where `boat.glb` has to stay
importable.

⇒ **`blend/` holds the originals and carries a `.gdignore`.** With that file present the import run is
silent again. ⚠ **Do not move a `.blend` into `assets/`**, however tidy it looks to have the original
beside what it exports.

⚠ **There is a third path nobody has taken**: set Blender's executable in Godot's editor settings and
let Godot import `.blend` directly, with no `.glb` at all. **It was not taken because that path is one
machine's absolute path** — the same reason this repo already gitignores its MCP config.

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
| `assets/terrain/island.json` | `rows` (passability, 30x26) · `tiers` (levels) · `coast` · `builds` · `props` | `Islands` — **the game's whole idea of the ground** |
| `assets/buildings/buildings.json` | each building's kind, footprint in 조각, and name | `Builds` — how many 조각 a keep covers |

⚠ **`rows` is 388 `~` · 284 `.` · 108 `H`, and `H` is a BORDER letter and nothing else.** 항구 is a dead
word (2026-09-02) and no code in `src/` launches a boat from an `H`; a page that calls this file's
contents 「harbours」 is re-proposing a thing the user deleted.

**Move a block in `island.blend` and the mesh changes while the game's idea of the ground does not** —
bodies will walk through walls or refuse open ground. **Resize a building and its footprint still says
the old size.**
⇒ **Say this out loud before reshaping either.** ⚠ `Builds` treats a missing `buildings.json` as a hard
failure by design, so it will not silently limp.
⇒ The deleted `island_build.py` and `buildings_build.py` are recoverable from git at **`16e2e2fa`** if
a data file ever has to be rebuilt. ⚠ **Copies of both also survive under `.prototypes/palette/` as
`.orig` files** — left there by a palette round, and easier to reach than git archaeology. **They are
copies, not the source**: nothing keeps them in step with anything.

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
- ⚠⚠ **A block's corners are NOT cut at 45° — they are slightly tilted.** This is a live rule and it
  has been trampled once by a round that opened Blender without reading it first.
- **The island is one mesh and one draw call, and so is `pads` beside it.** Measured 2026-09-03:
  **22,075 verts in Blender, 80,723 in the exported `island.glb`** — the export splits a vertex per face
  for flat shading, so the exported number is the one Godot loads and it is about 3.7x the Blender
  count. `pads` is 11,480 in Blender and 28,176 exported. ⚠ **The old figure here was 「~1100
  vertices」 and it was wrong by a factor of twenty.** The conclusion it was written to carry still
  stands: **nothing here is a performance problem, and optimisation is never a reason to change the
  approach.**
- **The boat's length and beam are a RULE, not a picture** — `Rules.BOAT_HULL_HALF_TILES` (1.5) and
  `BOAT_HULL_BEAM_TILES` (1.5) are read back off **`blend/boat_small.blend` / `assets/props/boat_small.glb`**,
  which is the hull that actually arrives, and the sim beaches every boat off them. ⚠ **Change the hull's
  length and change that constant in the same edit**, or the boat stops short of the sand. ⚠ **This page
  carried 2.1 and 2.01, which were `boat.glb`'s and were replaced on 2026-09-01 when the small boat took
  over** — `blend/boat.blend` is still an original and is not what lands.
