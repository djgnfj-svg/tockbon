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
& $py tools\pixel\cutbg.py tools\pixel\out\boss_bull\boss_bull_05_seed1882469963_96px.png assets\monster\bull_body.png
```

**Why a script and not "erase the background color"**: downscaling blends the edge into the ground, so an
exact-color match leaves a **green fringe**, and on the stage's `#0E0E13` that fringe is the brightest thing
on screen. `cutbg.py` cuts by "green dominates" and then pulls the cast out of the surviving edge pixels.

**`sigil` output takes a third path — `ink.py`.** A sigil is black line art on cream, and the shipped
`assets/circle/socket_glyph_*.png` were measured to be **one flat colour `(26,24,22)` with the entire drawing
in the alpha channel.** `ink.py` reproduces that: invert luminance into alpha, resample with LANCZOS (never
k_centroid — the `sigil` preset carries `down: 0` because k_centroid's dominant-colour blocks eat thin lines).

```powershell
& $py tools\pixel\ink.py tools\pixel\out\ring2_spread_c\ring2_spread_c_02_seed920739551.png assets\circle\ring_spread.png 288
```

Neither `cutbg.py` (chroma green, monsters) nor `cut_white_bg.py` (flood from the border, UI panels) fits:
a ring's **inner hole** is cream too and is not reachable from the border, so a flood leaves it opaque.

## Animation — **this is the one thing local cannot do**

The original pipeline's walk LoRA is **for human characters**, so an animal walk cycle has no local path.
The bosses' walks were made with **pixellab `animate_image`** (1 generation each, ~2 minutes) from the
standing frame, and the returned frames go through `anim_sheet.py` into one horizontal sheet plus a
GIF to judge the motion by:

```powershell
& $py tools\pixel\anim_sheet.py tools\pixel\out\anim_bull assets\monster\bull_walk.png
```

**The input must be quantized to 16-32 colors first.** Past roughly 3,000 base64 characters the MCP client
**silently truncates the argument** and the call comes back "could not decode image" — a 88×54 RGBA png is
already twice that. A palette png with a transparent index gets under it; RGBA never does.

## Presets — the place that stops the style from splitting

One entry in `gen.py`'s `PRESETS` holds the style phrasing, the LoRA strength and the size together.

| Preset | What | Generate -> final |
|---|---|---|
| `glyph` | geometric pattern that goes into a layer | 512 -> 64px |
| `frame` | the circle — the concentric frame whose layers read apart | 512 -> 256px |
| `rune` | the rune — **it does not need to be geometric** | 512 -> 96px |
| `ui` | the assembly window (an open grimoire) | 512 -> unchanged |
| `raw` | with no style phrasing | 512 -> unchanged |

**`--lora` is 0 everywhere.** Turn on the 4-walk LoRA and even a UI prompt yields **a human spritesheet**
(measured in the original `PROMPTS.md`). It is 1.0 only when generating characters, and that is the original pipeline's job.

## Sizes — read before generating

**The reference document is `docs/design/circle-art.md`.** Why these sizes and what is unresolved live there.
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

## What to generate next — the user's call

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
  how many species a habitat can have** — see [the body is a line](../../docs/design/the-body-is-a-line-drawn-by-code.md).
  The rule still binds anything that keeps its own colours

**And three things measured on 2026-08-13, generating for the cell game:**

- **Naming an animal overrides the view.** Six species asked for top-down came out in front view. Forcing
  the view back made the animal leave — a top-down lion is an orange square, because **a mane is surface and
  surface does not show from above.** ⇒ On a top-down body, **only what sticks out reads**
- **A part generates well only if it survives being cut off a body.** Jaws do. **A leg does not** — detached
  it is a brown stick
- **Do not generate what is a shape.** An outline, a dot and a limb are a radius, a thickness and a length;
  code draws them, squash and stretch are free on numbers and destructive on pixels
