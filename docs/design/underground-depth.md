# Underground depth — what is behind a dug hole

**One line**: below the ground line the grid is one flat `#5C574F`, and **every hole punched through it shows
the farm's blue sky.** This doc owns **behind and below** the terrain; the material's own surface belongs to
[terrain-look.md](terrain-look.md) and is not repeated here.

**Implemented**: **none.** Not one line
**Accepted**: **unseen** — there is nothing built to look at

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**Opened by the user**: the area under the surface "is a completely featureless grey slab", and it
**fights the parallax art above it.**

---

## What is actually behind a hole today — measured, not guessed

`sky_background._layer_y(screen_top, anchor, ratio) = anchor + (screen_top - anchor) * (1 - ratio)`.
With `BG_FAR_ANCHOR_Y = 300` and **`BG_FAR_SCROLL_Y = 0.08`** the far picture is **92% glued to the window**:

```
screen_top    far picture spans      screen spans        what fills a hole
     0         300 .. 844              0 ..  540         sky + hills            (correct)
  1000         944 .. 1488          1000 .. 1540         sky + hills            (bedrock floor is here)
```

**The picture never leaves the screen.** The map's floor is at world y 1440-1536
(`terrain_map_generated.gd`, 48 tiles x `TILE_CELLS` 8 x `CELL_PX` 4), and at that depth the farm's
**blue sky band is still drawn across the top of the screen.**

And below the picture, `_bottom_fill` is sampled from the far picture's own bottom row —
**measured `#7EB356`, a bright grass green.** That is what fills the rest of the fall.

⇒ **The background layer has no notion of depth at all.** Two separate things are wrong and they are
independent: the picture follows the camera down, and the fill under it is a lawn.

**Second measurement, because it changes what "underground" even means here**: the grid is 4096x1008 cells
but the map is **217x48 tiles = 1736x384 cells**, seated at (0,0) (400 wide until the left run's 100 flat
columns were cut — `left-run-clumps-and-platforms` — then 300 until zone ② was deleted, `burn-out-of-the-bull-room`; **the height, which is the only part this
measurement uses, did not move**). ⇒ **Everything below world y 1536 is
`EMPTY`** — 2,496px, **62% of the world's height, is not underground, it is off the bottom of the map.**
Any depth ramp tuned against `CellGrid.H` is tuned against a number the player never reaches.

---

## How other games answer this

| Game | Behind a dug hole | How depth reads |
|---|---|---|
| **Terraria · Starbound** | A **separate background-wall tile layer**, generated with the world (dirt walls in the underground, stone walls in the caverns). Drawn behind blocks and darker | The wall **and** the biome backdrop behind it both swap with depth |
| **Noita** (closest to us — pixel granularity) | A parallax cave backdrop | **Darkness.** Unlit is black, a light reveals a radius; whole biomes carry a darkness modifier. It does not need the material to be interesting — you cannot see far |
| **Motherload · SteamWorld Dig · Dome Keeper** | The ground itself, no wall layer | **Strata bands** — the ground changes color in horizontal layers, and the band *is* the depth readout. The cheapest cue that exists |
| **Tile-art practice** | The standard cheap wall is literally **a second copy of the tile layer at ~40% opacity over flat grey** | Background tiles get **less contrast, darker, fewer details** so the foreground stays readable |

**The one thing all four share**: a dug hole is **never** the same picture as open sky. That distinction —
*this was carved out of rock* vs *this was always air* — is the whole effect, and it is the one we do not draw.

---

## The options

Ranked by payoff / cost. **They compose** — none of them excludes another.

### ① Depth fill — the background stops pretending to be sky · **`sky_background.gd` only**

**Where**: `src/view/sky_background.gd::_draw()` and new `BG_UNDER_*` constants in `fx_tuning.gd`.
**No shader change. No material table change. No art.**

Two edits: **(a)** stop the far picture at the horizon — clamp `far_y` so its bottom never falls past the
ground line, instead of letting ratio 0.08 carry it down the whole map. **(b)** replace the single
`_bottom_fill` rect with **banded rects darkening with world y**, ending near bedrock's `#232228`
(the Motherload answer, and banding is on-style for pixel art — a smooth gradient is not).

**Cost**: ~20 lines and three or four constants. Draw cost is a handful of `draw_rect` where there are
already two.
**What breaks**: `net_background._far_and_near_use_different_parallax_ratios` and
`_horizon_anchor_is_pinned_by_value` **pin those values by number** — move `BG_FAR_SCROLL_Y` or the anchor
and that net moves **in the same edit**. Nothing else in the repo touches them.
**Payoff**: the largest change per line available. Every hole underground stops showing sky, and depth
becomes readable, in one file.

### ② Depth dim in the shader — **`UV.y` is already world depth, for free**

**Where**: `src/view/cell_grid.gdshader`, one new uniform injected from `cell_renderer.setup()`.

The grid sprite is the whole world, so **`UV.y` is normalized world depth with no new texture read and no
CPU work at all** — `c.rgb *= mix(1.0, deep_dim, depth)`. Stone at the surface stops being the same value as
stone at the floor.

**Do not normalize against `CellGrid.H`** — the map ends at cell y 384 of 1008, so `UV.y` at the bedrock
floor is **0.38**, and the effect lands at a third of whatever was tuned. Normalize against the map's own
depth and inject that.
**Ordering is the trap [terrain-look.md](terrain-look.md) already names**: the fire branch overwrites `c`
wholesale, so where the dim sits decides whether fire and shallow water dim too. Pick it deliberately.
**What breaks**: `net_render._injection_matches_shader` sweeps **every** uniform the shader declares against
every `set_shader_parameter()` call — a new uniform without an injector goes red, and an injector without a
uniform goes red. That is the rule to follow, not an obstacle. `net_background`'s two pinned shader strings
are the empty-alpha lines and are untouched by this.
**Payoff**: real but small — it kills "one value across the whole lower half" and does **nothing** for a hole.
**Cost**: near zero. Worth doing in the same pass as ①, not on its own.

### ③ The background wall — the Terraria answer, **baked from the map that already exists**

**Where**: a new `WallRenderer` (`Sprite2D`) between `SkyBackground` and `CellRenderer` in `stage.tscn`,
a small `cell_wall.gdshader`, and one static L8 texture built **once at boot** from
`terrain_map_generated.MAP`.

**Why this is cheap here and expensive in Terraria**: a background wall has to know **what used to be there**,
and we do not store that — **but the map never regenerates.** The baked array *is* "what was here at level
start". Player-carved holes reveal the darkened original material; sky stays sky (originally `EMPTY` ⇒
alpha 0). That is Terraria's natural-wall rule with none of Terraria's placement system.

**Cost**: one extra 4,128,768-byte texture, **uploaded once, not per tick** — it adds **zero** to
`cell_renderer.gd`'s measured 157.5MB/s, which is per-tick uploads of the two live textures. Plus one
full-screen sprite draw per frame. The palette comes from `CellRenderer.bake_palette()`, so the single
source holds.
**What breaks**:
- **Do not reuse `cell_grid.gdshader` for the wall pass** — its fire and shallow-water branches would run on
  the wall too, and a burning wall would glow behind an empty hole. A separate small shader (palette lookup ·
  alpha 0 on empty · multiply by `wall_dim`) is the cheap answer.
- **A second shader is a second thing that can stop compiling while every net stays green.** That is the
  exact accident `net_render` exists for (`cell_grid.gdshader`'s own header: 534 nets green, screen black).
  `_injection_matches_shader` only covers the shader `CellRenderer.SHADER_PATH` names — **the new one needs
  its own coverage in the same edit.**
- The pit is **a bedrock bowl that is `EMPTY` in the baked map**, so it gets no wall. That is correct — it is
  a cavern, not a tunnel — but write it down or it reads as a bug.

**Payoff**: the largest of the four. It is the single move that makes a tunnel read as a tunnel.
**Cost**: a new node, a new shader, a new net. Real, but bounded, and **nothing in `src/sim/` is touched.**

### ④ A `DIRT` band and mineral speckles — **new material, new art**

**Where**: a new id in `src/sim/cell_materials.gd` (behavior · fuel · `rgb`), then `terrain_palette.gd`,
`terrain_baker.gd`'s `CHAR_BY_MAT`/`NAME_BY_MAT`, **the map redrawn in the editor and re-baked.**

A dirt band over stone is how every reference game says "you are near the surface", and it is genuinely good.
**But it is the only option that touches `src/sim/`**, it costs a map re-bake, and **the art budget is already
claimed**: [terrain-look.md](terrain-look.md) **measured** the grain tile as by far the largest of the three
looks it ranked, and that needs three tiles first. **Ranked last on ratio, not on merit.**

---

## Which one — ① first, and look at it before deciding anything else

**① is the only one of the four that fixes a defect rather than adding a feature.** The far layer's vertical
ratio of 0.08 means the picture is 92% glued to the window, so it is still drawing blue sky behind the
bedrock floor, and the fill below it is a lawn — and **until that stops, the grey slab cannot be judged,
because the thing it is being compared against is wrong.** It costs one file, no shader, no sim change and no
art, and it answers with banded rects both of the questions the reference games answer with far more
machinery: what is behind a hole (dark earth, not sky) and how depth reads (the band you are in). ② is a
two-line follow-up in the same pass and should ride along. **③ is the real answer and the biggest payoff and
is worth doing** — but it should be judged *after* ①, because a background wall drawn against a blue sky is
still wrong, and once ① lands, part of what ③ buys may already be bought. ④ waits for
[terrain-look.md](terrain-look.md)'s grain to go in first.

---

## Boundary — what this doc is not

- **The material's own surface** — grain, the lit face, the mottle. That is [terrain-look.md](terrain-look.md),
  and it is **measured**: grain wins, the mottle makes a checkerboard. Do not re-derive it here
- **The backdrop art and its layers** — [background.md](background.md). Stage 1 is a daylit farm and the town
  a burnt village, **both decided by the user.** Nothing here changes either picture
- **Lighting as a system** (Noita's answer). `render_mode unshaded` is deliberate, and a light map is a
  different order of work than any of the four above
- **Nothing in `src/sim/`** except option ④, which is flagged as exactly that

## TBD

- **How many bands and where they break** — ①'s only real question
- **Where the map's floor should sit** relative to the 1008-cell grid. 62% of the world is below the map
  today; whether that is deliberate headroom or an accident is **not recorded anywhere**
- **Whether the far picture is clamped or faded out** at the horizon — a hard clamp is one line and may read
  as a seam
- **Whether ③'s wall is one dim factor or a per-material one** (dirt wall vs stone wall, Terraria's split)

---

## Sources

- [Background walls — Terraria Wiki](https://terraria.wiki.gg/wiki/Background_walls)
- [Light — Noita Wiki](https://noita.fandom.com/wiki/Light) · [Dark Cave — Noita Wiki](https://noita.wiki.gg/wiki/Dark_Cave)
- [Dome Keeper on Steam](https://store.steampowered.com/app/1637320/Dome_Keeper/) (the Motherload lineage)
- [How to make 2D ground more alive/dynamic — GameDev.net](https://gamedev.net/forums/topic/681401-how-to-make-2d-ground-more-alivedynamic/5311815/)
- [A cool technique to create a pixel-art texture for your Godot terrain — Miximum](https://www.miximum.fr/blog/godot-pixel-art-texture/)
- [Procedural Pixel Art Tilemaps — DEV](https://dev.to/jhmciberman/procedural-pixel-art-tilemaps-57e2)
