# Asset generation — local ComfyUI

Generates magic circle UI · glyphs · runes · circles **on this PC's GPU**, without spending pixellab credits.

## Where things are

| What | Where | Why |
|---|---|---|
| Scripts (this folder) | `tools/pixel/` | committed to the repo |
| ComfyUI itself · 12GB of models | `comfy_root` in `config.json` | **Not in the repo.** When the machine changes, fix that one line |
| Generated candidates | `tools/pixel/out/` | gitignored. **Only the chosen ones** move to `assets/` |

The original pipeline is `CompyUI_2DPixel/pixel_pipeline/` and it is **for character 4-direction walk sheets only.**
This borrows only its models and lays out a new workflow.

## How to use

```powershell
powershell -File tools\pixel\serve.ps1          # server (once; leave it running)

$py = "C:\Users\djgnf\Desktop\window_project\CompyUI_2DPixel\ComfyUI_windows_portable\python_embeded\python.exe"
& $py tools\pixel\gen.py "eight straight rays radiating from a center point inside a hexagon" `
    --name glyph_spread --preset glyph --batch 8

& $py tools\pixel\sheet.py tools\pixel\out\glyph_spread --cols 4 --zoom 3
```

One `_sheet.png` comes out; pick from it and move the choice to `assets/`.

**`monster` preset output cannot be moved as-is** — it carries a chroma-green ground. Cut it first:

```powershell
& $py tools\pixel\cutbg.py tools\pixel\out\boss_bull\boss_bull_05_seed1882469963_96px.png assets\beast\bull_body.png
```

**Why a script and not "erase the background color"**: downscaling blends the edge into the ground, so an
exact-color match leaves a **green fringe**, and on the stage's `#0E0E13` that fringe is the brightest thing
on screen. `cutbg.py` cuts by "green dominates" and then pulls the cast out of the surviving edge pixels.

**`sigil` output takes a third path — `ink.py`.** A sigil is black line art on cream, and the magic-circle
game's `socket_glyph_*.png` were measured — **before that game and its whole sigil folder were deleted** —
to be **one flat colour `(26,24,22)` with the entire drawing in the alpha channel.** `ink.py` reproduces
that: invert luminance into alpha, resample with LANCZOS (never k_centroid — the `sigil` preset carries
`down: 0` because k_centroid's dominant-colour blocks eat thin lines).

⚠ **Nothing sigil-shaped ships today**, so the destination below is whichever `assets/` folder the caller
is filling; the folders that exist are `beast`, `human`, `item`, `terrain` and `font`.

```powershell
& $py tools\pixel\ink.py tools\pixel\out\ring2_spread_c\ring2_spread_c_02_seed920739551.png assets\<folder>\ring_spread.png 288
```

Neither `cutbg.py` (chroma green, monsters) nor `cut_white_bg.py` (flood from the border, UI panels) fits:
a ring's **inner hole** is cream too and is not reachable from the border, so a flood leaves it opaque.

## Animation — ⚠ **this section said "local cannot do it" and that was measured false on 2026-08-25**

**What was true**: the original pipeline's walk LoRA is for **human** characters, so there is no local
path to an animal walk *through the LoRA*. The old game's boss walks were made with pixellab
`animate_image`, one generation each.

**What is true now**: the beasts of this game are **low-poly 3D renders**, not pixel art, and FLUX.2
klein will draw a **whole four-frame row in one image**. Local does animation. Measured on the wolf.

```powershell
# 1. one wide image = four frames. **One image is one style applied once**, which is what keeps the
#    body, the lighting and the polygon size identical across frames.
& $py tools\pixel\gen.py "<the sheet prompt, below>" --name wolf_walk_sheet --preset raw `
    --batch 8 --width 2048 --height 512 --negative "extra legs, six legs, duplicated limbs"

# 2. cut the row into registered frames (chroma green removed, ground line pinned)
& $py tools\pixel\split_row.py tools\pixel\out\wolf_walk_sheet\<pick>.png `
    tools\pixel\out\anim_wolf_walk --frames 4 --height 40 --face right

# 3. the horizontal sheet plus a GIF to judge the motion by
& $py tools\pixel\anim_sheet.py tools\pixel\out\anim_wolf_walk tools\pixel\out\anim_wolf_walk\_row.png

# 4. every candidate on one board, each row ending in its onion-skin registration check
& $py tools\pixel\anim_board.py walk,walk2 --title "WOLF WALK" --out _BOARD_wolf_walk.png
```

### What the sheet prompt has to say, and why

**Say the row, the spacing and the sameness, then name each frame's pose one at a time.** The wording
that worked: *"a sprite sheet of one low poly grey wolf walking, four separate frames in a single
horizontal row, evenly spaced with a wide empty gap between frames, each frame shows the same wolf at
the same size seen from the same camera on the same ground line, in the first frame ... in the second
frame ..."* followed by the beast style phrasing.

- ⚠ **Shape words, not action verbs.** *"lunging"* · *"biting"* · *"leaping"* were **ignored every time**
  and came back as a wolf walking with its mouth open. *"its head pulled back and its neck arched"* ·
  *"its front paws lifted high off the ground"* moved the body. **Describe the silhouette, not the verb.**
- ⚠⚠ **`square` summons a front view.** *"stands square with its mouth shut"* produced a wolf **facing
  the camera** in frame 1 of five sheets out of eight, and a front view cannot be registered against
  side views at all — the whole candidate dies. Say **`stands in profile`** and put
  `front view, facing the camera, head on view` in the negative.
- ⚠ **`all four legs gathered close under the body` grows extra legs.** Four of six sheets came back with
  a **six-legged** middle frame. `extra legs, six legs, duplicated limbs` in the negative fixed it
  outright — eight of eight clean on the next batch.
- ⚠ **A mouth opens pink.** The shipped beasts are one flat grey, and an open jaw arrives with a pink
  tongue that is the brightest thing in the frame. `pink, red tongue, bright saturated colors` in the
  negative.
- **`--cfg 7.5` is worse, not better.** Tried to force the pose through guidance: the poses did not move
  and the body picked up pink and purple blotches. **Stay at the preset's 5.0 and fix it in the prompt.**

### ⚠⚠ What this route **cannot** do — measured, not guessed

**A big pose change does not come out.** Across 22 bite candidates the model reliably gives
**"the same wolf with its jaws open"** and reliably refuses **"the wolf leaves the ground and lunges"**.
Exactly one candidate (`wolf_bite2_sheet_02_seed726115173`) produced a genuinely coiled lunge frame.
⇒ **A bite that reads as a bite is available; a bite that reads as a leap is not.** If the leap is
required, that is the thing to spend a paid generation on — and **only when the user asks.**

### The reference route — **strong registration, almost no pose range**

`genref.py` conditions on an actual image through FLUX.2's `ReferenceLatent`, so the wolf comes back
**identical** — same camera, same scale, same ground line.

```powershell
& $py tools\pixel\genref.py --ref tools\pixel\out\beast_wolf\beast_wolf_03_seed675153149.png `
    --name bite_ref --seed 675153149 --frames "<pose A>|<pose B>|<pose C>"
```

⚠ **The reference wins over the prompt.** Asked to gallop, to rear up and to leap, the wolf **stood
still** in all three; only the jaws opened. ⇒ Use it for **small** changes (a mouth, a head turn, an
ear) and use the one-image sheet for anything that moves a leg. **It is not the walk-cycle tool.**

### The frames still need fixing after the split — that is what `split_row.py` is for

Three defects show up in raw output and **all three are invisible until the frames are laid on top of
one another**, which is why `split_row.py` writes `_onion.png` beside the frames. **Two heads in the
onion means the candidate is dead however good each frame looks alone.**

| Defect | Measured | What the script does |
|---|---|---|
| **The frames are not evenly spaced** | every batch | Splits at the **empty columns**, not at `width / 4` |
| **Some frames come out mirrored** | 1 of 4 in a walk row, with `facing right` in the prompt | The **ears are the highest point**, so their x against the body centroid gives the facing; the minority is flipped |
| **Each frame is a slightly different size** | up to 3% in a walk row | Rescales by **silhouette area** — a lifted paw moves the bounding box a lot and the opaque pixel count almost not at all |

**The vertical anchor is the lowest paw, never the bounding box**, and the horizontal anchor is the
centroid of the bottom quarter (`--align feet`). Centring the bounding box **slides the body backwards
on the strike frame**, because a thrust head widens the box on one side only.

### ⚠⚠ The fourth defect is a colour cast, and it is the one that breaks the style match

**Every generation lights the wolf a different colour**, and the beast prompt cannot hold it — the phrase
already says `plain light grey material`. Measured as mean saturation over the opaque pixels:

| | meanSat |
|---|---|
| **shipped `assets/beast/wolf_r.png`** | **7.6** |
| candidates, as generated | **5.1** (a match) · **9.8** pink · **14.9** teal · **16.0** teal · **21.0** blue |

On the stage's `#0E0E13` a teal wolf does not read as the same animal as the one already in the game.
`split_row.py --desat` pulls each pixel toward its own luminance, which **removes the cast without
touching the shading** — a flat desaturate or a hue rotate wrecks the facets, which are the whole look.

⚠ **There is no one right value; it is per candidate.** Saturation scales with `1 - desat`, so run at
`--desat 0` first, read the `meanSat` the script prints, and use **`1 - 7.6 / that number`**. Measured:
21.0 -> `--desat 0.64` -> **7.5**, and 9.8 -> `--desat 0.22` -> **7.6**.

**What `--desat` does not fix**: the shipped wolf is **warmer, stockier and cut from bigger facets**;
the new frames are cooler, slimmer and finer-faceted. That gap is in the geometry, not the colour, and
**only the user can say whether it matters.**

⚠⚠ **And matching saturation is not matching colour.** Both installed sets hit the shipped wolf's
meanSat 7.6 and still measured **16 and 13 points heavier in blue** — the renders are lit cool, the
shipped wolf is lit warm, and `--desat` fixes how strong a cast is, never which way it points.
`install_anim.py --tint assets/beast/wolf_r.png` applies a **per-channel gain onto the reference's
mean**, which brought every channel inside ±3.7. It is multiplicative on purpose: **an additive shift
flattens the dark facets**, and the facets are the whole look.

## Installing frames into `assets/` — `install_anim.py`

```powershell
& $py tools\pixel\install_anim.py --dst assets\beast --beast wolf `
    --tint assets\beast\wolf_r.png `
    --set walk=tools\pixel\out\full_walk --set bite=tools\pixel\out\full_bite
```

⚠⚠ **Every frame it writes shares ONE canvas, across every set named in one call.** That is the whole
job, and the reason is `src/view/field_view.gd`'s `_beast_rect`: the sprite's **width is fixed by the
body radius, never by the texture**, the height follows the texture's own aspect ratio, and the rect is
**centred on the body, not stood on the ground.** So a texture 4 px wider does not draw wider — it draws
the same width with **the wolf inside it shrunk** — and one 2 px taller **lifts the animal off the
ground.** ⇒ Two frames of one animation on two canvas sizes is a wolf that pulses and floats.

- **The canvas is the union of every frame's bounding box** — the smallest that clips nothing.
- **The sets are scaled to each other by silhouette area first**, so the body in a bite frame is the
  same body as in a walk frame. A raised head then honestly makes the canvas taller.
- **The standing frame joins the set as one more `--set`, and it must.** Left out, `wolf_l/r.png` stayed
  trimmed to its own pose (57x40) while the frames were 74x40, and since `_beast_rect` takes height from
  the aspect ratio, **idle -> walk made the animal 40% taller.** Measured, in units of the constant rect
  width: idle **0.702W** against walk frame 0's **0.500W**. Bringing it onto the shared canvas took that
  to **0.541W vs 0.500W — 8%**, and the 8% that remains is the pose (a walking wolf carries its head
  lower), not a defect.
- ⚠ **No regeneration was needed.** The shipped wolf's 512px original is
  `out/beast_wolf/beast_wolf_03_seed675153149.png`; running **that** through `split_row.py --frames 1`
  registers it exactly, because working from the original beats padding the 57x40 downscale — padding
  cannot change how much of the canvas the animal fills, and that fraction is what decides its rendered
  size. **Regenerate only if the original is gone.**
- ⚠ **`--no-tint <set>` on the standing frame.** It is the colour every other set was matched to; a gain
  over the target moves the target and leaves nothing anchored.

**Godot needs the `.import` sidecars.** `godot --headless --import` writes them without opening the
editor; it also imports everything under `tools/pixel/out/`, which is noise but harmless since that
folder is gitignored.

## Presets — the place that stops the style from splitting

One entry in `gen.py`'s `PRESETS` holds the style phrasing, the LoRA strength and the size together.

| Preset | What | Generate -> final |
|---|---|---|
| `glyph` | geometric pattern that goes into a layer | 512 -> 64px |
| `frame` | the circle — the concentric frame whose layers read apart | 512 -> 256px |
| `rune` | the rune — **it does not need to be geometric** | 512 -> 96px |
| `ui` | the assembly window (an open grimoire) | 512 -> unchanged |
| `raw` | with no style phrasing | 512 -> unchanged |

### ⚠⚠ The shipped game's art is **two styles**, and neither is a preset in this table

Recovered 2026-08-25 by regenerating `beast_wolf_03_seed675153149` and matching it against the shipped
`assets/beast/wolf_l.png`. **Both ride the `raw` preset**, so the style lives in the prompt and nothing
in `gen.py` protects it — write the phrase, do not invent one.

| What | Preset | The phrase that carries the style |
|---|---|---|
| **Beasts** | `raw` | `low poly 3d render, faceted flat shaded polygons, plain light grey material, on a plain solid bright chroma green background` — ⚠ **this is not pixel art** |
| **Humans** | `monster` | `oversized round bald head, small stubby body, thick black outline` — chibi pixel art |

**They do not match each other on purpose** — the user delegated the choice. ⚠ **The ticket that
recorded it was deleted with the old planning maps on 2026-08-26, so this row is the only copy.**
One realistic-cartoon batch was thrown away whole before this split was found.

**`--lora` is 0 everywhere.** Turn on the 4-walk LoRA and even a UI prompt yields **a human spritesheet**
(measured in the original `PROMPTS.md`). It is 1.0 only when generating characters, and that is the original pipeline's job.

## Sizes — read before generating

⚠⚠ **The reference document is gone.** `docs/design/circle-art.md` held why these sizes and what was
unresolved, and it is **in no branch** — lost before the archive branch was cut. **The sizes survive only in
`draw_circle.py` and `gen.py`**, and the reasoning behind them survives nowhere. ⇒ **Write it down again the
first time this tool is used on the new game**, before the numbers become folklore a second time.
This holds **only the numbers** used when generating.

| What | File size | Generate -> downscale |
|---|---|---|
| Glyph layer 1 (2-layer circle) | **112** | 768 -> 112 |
| Glyph layer 2 (2-layer circle) | **224** | 768 -> 224 |
| Rune (circle border) | **96** | 768 -> 96 |
| Circle | **560** | **1120 -> 560** |
| Assembly window | 864x372 | generate at 864x376 and trim 4px |

**Avoid non-integer downscales.** 1024 -> 560 is 1.83x, so **the lines break up and go jagged** (measured).
Generate at **1120 -> 560 (exactly 2x)** and they do not break.

**A glyph is not "a dot attached to a layer" but "a ring that fills a layer".** Generate it as a donut, and because
the inner hole ratio differs per layer (layer 1: 0 · layer 2: 1/2 · layer 3: 2/3), **cut away what falls outside the band** before laying it on.

**Terrain is not here.** It is destroyed in 4px cell units and the shader colors each cell
(`cell_materials.DEFS`) — there is no place for a tile image to go.

## ⚠⚠ DEAD — what the magic game was going to generate next

⚠⚠ **Do not work this list.** Every destination in it is gone: `assets/fx/`, `assets/stage/`,
`assets/circle/`, `blast_fx.gd` and `cell_grid.gdshader` were deleted with the magic game, and so were the
two design docs it cites. **The folders that exist are `beast`, `human`, `item`, `terrain` and `font`.**
It is kept only as the record of what that pipeline cost and what came out of it — **the next thing to
generate is decided on the live map, not here.**

Right now the only things on screen that are **art are the character body, the staff and the bolt head — four items**;
everything else is a shape drawn by code.
**The order follows the GDD's "where the fun comes from"** — magic presentation first, precision of the world last.

| Bundle | What | Why now · what blocks it |
|---|---|---|
| ~~**Blast**~~ | ~~72x72~~ | **Generated** — `assets/fx/blast_flash.png`, 72px, seed 1982300549. **Still one still frame, not the 6-8 the row asked for**: `blast_fx` already animates radius and alpha per frame, so a sheet needs a code change first |
| **Impact / spread moment** | 64x64 4 frames | "8 blasts vs 1" has to read apart on screen (the GDD thesis) |
| ~~**Destruction debris / dust**~~ | ~~16x16~~ | **Generated** — `assets/fx/debris.png`, **32px** (a blast carves `rd` 2..8 cells x 4px, so 16 was too small), seed 1337920495 |
| ~~**Fire cell**~~ | ~~16x16~~ | **Generated** — `assets/fx/fire_cell.png`, 16px, seed 885673263 |
| ~~**Backdrop layer**~~ | ~~512x288~~ | **Shipped and wired** — `assets/stage/bg_*.png`, four of them (`docs/design/background.md`) |
| ~~**Floor pickups**~~ | ~~16x16~~ | **Generated** — `assets/fx/pickup_scroll.png`, 16px, seed 854854407. **One scroll, not three**: circle/rune/glyph are told apart by what is drawn *on* the scroll, and those sigils now exist (`assets/circle/`) |
| **Slot 1/2 frames · health bar frame** | — | `slot_row.png` already covers the slots, lock included. The bar frame is generated |
| Extra character frames | being raised · wet · on fire | **the behavior does not exist yet** — there is no water sim and no co-op, so drawing them now has nowhere to go |
| ~~Monsters~~ | — | **Done.** Five kinds, ten states each (`docs/design/monsters.md`) |

**⚠ Everything in `assets/fx/` is generated and wired to nothing.** `blast_fx.gd` still draws additive circles,
the fire cells are still `cell_grid.gdshader`'s colour-plus-sine, and **nothing in `src/` mentions debris or a
pickup at all** — those two have no code to attach to, not even a wrong one. The art is ahead of the code on
purpose (the user asked for it); **do not read the files' existence as a feature.**

**They are `bolt`-preset assets, so they are additive-only.** Black is transparent for free and **dark colours
do not appear at all** — that is why they look like glowing shapes on black rather than sprites. Draw them with
`BLEND_MODE_ADD` or they arrive as black rectangles.

**Terrain is not on this list, and it will never arrive as a "tileset".**
Destruction happens **in 4px cell units**, so a hole dug by magic cuts across a 32px tile image => it must be
**a tileable material pattern laid on the cell grid**, not a tileset, and `src/view/cell_grid.gdshader` has to be fixed first.
This is the same point as "terrain is not here" in the Sizes section above.

## Traps — what the original pipeline left as measurements

`CompyUI_2DPixel/pixel_pipeline/PROMPTS.md` is the reference. Rather than copying it, this points at the key points.

- **Button states (normal/hover/pressed) do not come out.** All five come out nearly identical — generate one and make the rest by hand
- **Stretching with 9-slice misaligns the corners.** The four corner ornaments are all different
- **A reference image nearly replicates the art itself.** Do not feed someone else's art in as a style reference
- **Icons need `no slots no frames` and `evenly spaced apart`** to come out as separate pieces

---

# What generating for two games measured — moved here from `CLAUDE.md` on 2026-08-19

`tools/pixel/` runs a local ComfyUI (FLUX.2 klein) — **no credits, 6-25 seconds an image.** It survived the
reset because it is the one asset from the old project that knows nothing about the game.

**The user decides art by looking at real candidates, never by discussion.** Every settled art decision in
the old project came from generating a board and pointing at one. **Paid generation only when the user asks
for it.**

Two things it measured that outlive the old game:

- **Generate at the size you will use.** Upscaling cannot invent pixels; a ring made at 448 and stretched to
  896 was judged "low pixel", and generating at 896 directly fixed it
- **Texture comes from the preset, not the seed.** Six seeds on one preset gave six compositions with
  identical texture; five prompts on one seed gave five pictures that matched. Parts drawn from *different*
  presets can never be made to match, however the prompt is tuned.
  ⚠ **This is the constraint the cell game escaped, and it is worth knowing how**: a part is worn **in the
  host's own colour**, so there is only ever one tone and nothing has to match. **It bought back the cap on
  how many species a habitat can have** — the fork doc that recorded it, `the-body-is-a-line-drawn-by-code.md`,
  was deleted 2026-08-29 with the cell game's last papers.
  The rule still binds anything that keeps its own colours

**And three things measured on 2026-08-13, generating for the cell game:**

- **Naming an animal overrides the view.** Six species asked for top-down came out in front view. Forcing
  the view back made the animal leave — a top-down lion is an orange square, because **a mane is surface and
  surface does not show from above.** ⇒ On a top-down body, **only what sticks out reads**
- **A part generates well only if it survives being cut off a body.** Jaws do. **A leg does not** — detached
  it is a brown stick
- **Do not generate what is a shape.** An outline, a dot and a limb are a radius, a thickness and a length;
  code draws them, squash and stretch are free on numbers and destructive on pixels
