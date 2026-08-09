# Terrain look — making stone and wood read as material

**One line**: the terrain is **one flat color per material**. Give it a **material grain** and a lit face —
**both in `src/view/cell_grid.gdshader` alone**, with nothing in `src/sim/` touched.

**The order was settled by a mockup, not by argument** (see "order" below): **grain first, lit face second,
the per-cell mottle dropped.**

**Implemented**: **none.** Not one line. The shader still does a straight palette lookup
**Accepted**: **unseen**

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**The user opened this with "is there no way to make the stone and the wood look prettier — I just want to
raise the quality".** It is a look problem, not a system one: **nothing here changes what the sim computes.**

---

## Why — digging is the whole game and a dug hole is a color block

`spell-carves-terrain` made the terrain destructible, so **the player is looking at a cut face all the time.**
And a cut face right now is:

```
stone  #5C574F   one flat color, every cell, forever
wood   #6B4524   one flat color
dirt   #6B4524   ← the same value as wood in the mockup palette
bedrock #232228
```

⇒ **A blast leaves a rectangle of the same color it was before.** Nothing says "this is a fresh break",
nothing says "this is a top surface", and stone and wood differ only in hue.
**Which is why the terrain reads as UI, not as ground.**

**The background landing made this louder, not quieter.** `background.md` put a daylit farm behind the grid,
so the terrain now sits against **a picture with depth in it** — and a flat block in front of depth looks flatter
than the same block against black.

---

## What the shader already knows — and it is enough for two of the three

`cell_grid.gdshader` is a palette lookup over two L8 textures (`_mat` and `_flag`). It already computes,
for the fire flicker:

```glsl
vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
float ph  = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
```

**That line is the whole toolbox.** `UV / TEXTURE_PIXEL_SIZE` is **the cell coordinate as a continuous value** —
`floor` is which cell, and **`fract` is where inside the cell**, which is what a material texture needs.
⇒ **Neither of the two cheap wins needs a new uniform, a new texture or a CPU change.**

---

## ① The lit face — **the big one**

**A cell whose neighbour above is empty is a top surface. Lighten its top row; darken the cell under it.**

This is the single move that turns a block into ground, and it costs **four extra texture reads**
(up · down · left · right of `_mat`).

```
        ▁▁▁▁▁▁▁▁      ← neighbour above is empty  => top row +brightness
        ████████
        ████████      ← neighbour above is solid  => untouched
```

**Why it beats a texture**: the light face is **computed from the neighbours, so a hole blasted at runtime grows
its own lit rim in the same frame.** A baked texture cannot do that — it would keep painting the old surface
on a face that no longer exists.

**And it costs nothing on the sim side.** The sim already stores exactly what this needs (material per cell);
this only reads it.

### The traps — all four are silent

- **Off-grid neighbours read as material 0.** `flag_tex` is `repeat_disable`, and sampling past the edge returns
  the clamped or zero texel. Material 0 is `EMPTY` ⇒ **the outermost ring of the world grows a lit rim
  along the whole map border.** Clamp the UV **before** sampling, or treat out-of-range as solid
- **Where it goes relative to the fire and shallow-water branches decides whether burning cells get a rim.**
  The fire branch overwrites `c` wholesale, so **placed before it, the rim vanishes on burning cells; placed
  after, fire gets a rim too.** Pick one deliberately — the file already has a written rule for this ordering
- **Bedrock is `#232228` against empty `#0E0E13`.** verify-look measured those two as **21 per channel apart
  and invisible to the eye.** A rim on bedrock is the one place this feature matters most; do not tune the
  brightness against stone alone
- **An early `return` inside `fragment()` breaks compilation, and the game does not stop — the screen just goes
  black.** `net_render` exists because that happened. **Do not write `if (…) return;`** in the new branch

---

## ~~② The per-cell mottle~~ — **dropped. It makes a checkerboard** (measured; see "order")

Vary each cell's brightness by ±5% off a hash of its cell coordinate. Stone stops being a printed swatch.

**Do not reuse the fire hash's value.** The same `ph` drives the flame phase, so reusing it makes the mottle and
the flicker **the same pattern**, and burning stone would visibly pulse in step with its own speckle.
⇒ **A different constant vector, not a different variable name.**

**Keep it small.** At ±5% it reads as material; at ±15% it reads as noise, and **on 4px cells noise reads as
compression artefacts.**

---

## ③ The material texture — **the largest effect** (measured), and the only one needing art

Sample a stone-grain / wood-grain tile in **world space** and multiply it into the palette color.

```glsl
vec2 cell_uv = UV / TEXTURE_PIXEL_SIZE;   // continuous cell coordinate
vec2 t_uv    = cell_uv / float(TEX_CELLS); // TEX_CELLS = how many cells one tile spans
```

**It is sampled per screen pixel, not per cell** — that is the whole reason it works. A cell is 4x4 screen px,
so a 128px tile spans 32 cells and carries grain **across a wall**, which is exactly where stage 1 lives
(the map's left half is 185 tiles of unbroken ground, where ① has nothing to work with).

**Keep the tile's own color out of it.** It multiplies into the palette color, so what is wanted is a
light-dark pattern; a tile with strong color of its own fights `cell_materials.gd`. The `texture` preset in
`gen.py` asks for muted colors for that reason, and the mockup used the tiles **as grayscale.**

**Strength measured on the mockup: `0.78 + gray * 0.44`.** Stronger and the wall reads as photo texture rather
than pixel art; weaker and it disappears.

**Art**: mirrored 2x2 tiles (the same trick as the backdrops — generative models will not match seams).
Stone · wood · dirt, one tile each. **Nine candidates are generated under `tools/pixel/out/tex_stone` ·
`tex_wood` · `tex_dirt`** — the mockup used `tex_stone_02` · `tex_wood_01` · `tex_dirt_01`,
**not picked by the user yet.**

---

## Order — **③ first. The ranking above was a prediction and the mockup reversed it**

**Measured, not guessed.** All three were rendered at real scale (4px cells, real palette colors, a blasted
crater, a stone pillar, a wood platform) in a Python mockup before any shader was touched:

| | Predicted | Measured |
|---|---|---|
| ① lit face | **the big one** | **real but small** — at 4px a cell it is a 1px line; it reads as a clean edge, not as depth |
| ② mottle | cheap win | **worse than nothing.** `sin(dot(cell, …))` on an integer lattice is **periodic**, and at ±10% the whole wall turns into a visible **checkerboard**. At ±5% it is invisible. There is no window where it helps |
| ③ grain | **the smallest effect** | **by far the largest.** Wood gets planks, stone gets fracture lines. It is the only one that changes what the material *is* |

⇒ **Do ③ first, keep ①, drop ②.** ② is left written down only so the next person does not rediscover the
checkerboard.

**Why the prediction was wrong**: it assumed the grain would be invisible at 4px cells. **The grain is not
sampled per cell — it is sampled per screen pixel**, and one cell is 4x4 of them (`fract` of the cell
coordinate). So a 128px tile carries real detail across a wall while a cell still holds a flat-enough color.

**The cost ③ adds is a sampler uniform and three tiles of art.** That is the whole difference.

---

## How this gets verified — **the nets cannot see it**

**This is a shader. `load()` succeeding proves nothing and 500 green nets proved nothing before**
(`net_render`'s whole reason: a compile failure left every net green and only the screen black).

- **`net_render` must stay green** — it is the one net that catches "the shader stopped compiling"
- **Everything else is verify-look.** A screenshot of a dug hole, of a bedrock face, and of a burning wall
- **The one thing a net can measure** is that the shader still compiles and that the uniforms the CPU injects
  match the ones the shader declares — an injected uniform the shader does not declare is silently ignored

---

## Boundary — what this doc is not

- **Nothing in `src/sim/`.** No new material, no new flag, no change to what the sim computes
- **The burn effect** — the user raised it and **deferred it in the same breath** ("let's do that later").
  It is a different doc when its turn comes
- **The terrain tileset** (`assets/stage/terrain_tiles.png`) — that is the **editor-side painting** tool
  (`terrain-baking.md`), not what is drawn at runtime. **They are two different pictures**; do not fix one
  expecting the other to follow
- **Lighting as a system** (normal maps, a light node). `render_mode unshaded` is deliberate

---

## TBD

- **How strong the lit face is** — one row or two, and how many percent
- **Where the rim sits relative to fire and shallow water** (see the traps)
- **Does the bottom face get a dark rim too**, or only the top a light one
- **③'s uniform shape** — one sampler per material, or one atlas indexed by material id
- **Tile scale for ③** — how many cells one tile spans
