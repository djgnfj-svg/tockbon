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
| **Blast** | 72x72 6-8 frames + 32x32 | `flash_px` 72/36 is **exactly 2x**, so **generating the small one and doubling it** covers both with one set. Downscaling breaks the pixels |
| **Impact / spread moment** | 64x64 4 frames | "8 blasts vs 1" has to read apart on screen (the GDD thesis) |
| **Destruction debris / dust** | 16x16 4 frames | there is no presentation at all right now when a wall is punched through |
| **Fire cell** | 16x16 4-6 frames | currently cell color plus a sine flicker |
| **Backdrop layer** | 512x288 | behind a dug-out hole it is currently black |
| **Floor pickups** (circle · rune · glyph scrolls) | 16x16 | the roguelike's "you gain something" is not on screen |
| **Slot 1/2 frames · health bar frame** | — | the equip slots are not on screen at all |
| Extra character frames | being raised · wet · on fire | **the behavior does not exist yet** — there is no water sim and no co-op, so drawing them now has nowhere to go |
| Monsters | — | the GDD left **kinds and behavior entirely undecided.** Generate now and it goes stale |

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
