# Background — what is behind the grid

**One line**: nothing, currently. **The black that reads as "sky" is not a background — it is the empty material's color.**

**Implemented**: partial — **the layer stands up.** Empty cells are punched to transparent (`empty_id` in
`cell_grid.gdshader`) and `SkyBackground` sits **in front of** `CellRenderer` in `stage.tscn`.
What it draws now is a **night-sky gradient + stars.** **There is no art yet** — no parallax, no layers.
**Accepted**: unseen — **never confirmed on screen.**

**Three pieces are one set; drop one and nothing shows, silently:**
1. `src/view/cell_grid.gdshader` — `mat_id == empty_id` ⇒ `COLOR = vec4(0.0)`
2. `src/view/cell_renderer.gd` — derives `empty_id` from `Mat.EMPTY` and injects it
3. `src/stage/stage.tscn` — `SkyBackground` **before** `CellRenderer` (scene order = draw order)

Values live in `BG_*` in `src/view/fx_tuning.gd`.

**A concept stays alive and never changes folders.** The two header lines are only "how much runs now" —
format per [README.md](README.md).

**The user opened this with "shouldn't there be a background too".** Until then
**the word "background" appeared zero times across the GDD and all of `docs/design/`.**

**Stage 1's background is a farm — and not now** (decided by the user).
Night sky + stars is **placeholder**, not the stage-1 look: the theme is a farm (GDD, "the stage template"),
so what stands behind the grid is **fields, fences, a barn, a horizon.** ⇒ **What this doc is waiting for is art,
not code** — the three-piece layer above already works and needs nothing further to show a farm.
**The user explicitly deferred it**; do not start it because it reads as an obvious gap.
**It is also the first thing that will need a second variant** — `town.md` needs a bright room.

---

## The current "sky" is not a background

**`#0E0E13` is not a background color; it is the `EMPTY` material color from `cell_materials.gd`.**

`CellRenderer` (a `Sprite2D`) **lays the whole grid down as a texture** and `cell_grid.gdshader` looks up
the palette by material id. ⇒ **Empty cells are painted too.**

**And that paint is opaque:**
- `_rgb_to_color` in `cell_renderer.gd` is `Color8(r,g,b)`, so **alpha is 255**
- The material table's `rgb` is a **24-bit integer — there is no alpha channel in the table at all**
- `setup()` sets `centered = false · position = ZERO · scale = 4`, so the sprite
  **covers all 16,384×4,032px of world without a gap**

**`CellRenderer` is the bottom visual node** — `stage.tscn` order is
`Camera2D → CellRenderer → MonsterView → CharacterView → SpellView → BlastFx`.
**⇒ Anything behind it is 100% hidden.**

**And the repo has no `ParallaxBackground` or `Parallax2D` at all** (the one `CanvasLayer` is the HUD, and that is on top).

---

## What has to happen first — code, not art

**Both were done.** Below is the record of what was chosen and why.

1. ~~**Punch empty cells to transparent in the shader**~~ → **done.** An `empty_id` uniform and `COLOR = vec4(0.0)`.
   **Finish this before the shallow-water and fire branches** — neither can stand on an empty cell, so going first is safe.
   Passing `empty_id` as -1 restores the old behavior (empty painted), so **the undo handle remains.**
   **Putting alpha in the material table is possible but touches `src/sim/`'s integers-only contract.**
   **The shader side is cheaper** — there is already a pattern injecting `flag_burning` and `fire_lo`
2. ~~**Put a background node in front of `CellRenderer`**~~ → **done.** `SkyBackground` (`src/view/sky_background.gd`).
   **It does not draw the whole world** — only screen-size around the camera center. Drawing 16,384×4,032px
   every frame wastes 99% off-screen
   **Stars are sampled from a world-space lattice** — sample in screen space and they follow the camera,
   becoming "dots stuck to the window"

**Without these two, no amount of good background art puts a single pixel on screen.**
**This repo has already had that accident** — water was finished, the game launched, and not one cell of water appeared
(CLAUDE.md, "is there a path for the thing you want to see to reach the screen").

---

## Size — one image can't cover it

```
grid 4096 × 1008 cells × CELL_PX 4  =  world 16,384 × 4,032 px
one screen 960 × 540 (project.godot)
⇒ 17.1 screens wide · 7.5 screens tall
```

**⇒ There is no option but horizontal repetition + parallax.**
The 4,032px height is absorbed by one image at a low scroll ratio (around 0.1).

**Generative models will not match seams.** Remove them with **mirrored copies** (flip every other tile) —
built and verified.

---

## Picking candidates — judging a background alone makes the judgment false

**Candidates were generated as whole screens (960×540), not tiles.** Two reasons:

1. **There is no layer to attach to yet** ⇒ deciding layer count, scroll ratio and tile width now is **all guesswork**
2. **Direction separates only at whole-scene scale** — you **cannot** choose "farm or forest" from a 480px seam fragment

⇒ **Once the direction is set, split into layers and make seams then.**

**And build a judgment mockup** — put **real game-color terrain** on the candidate (dirt `#6B4524` · stone `#5C574F` ·
bedrock `#232228` · pit `#0E0E13`) and **the player and monster sprites at real size.**
**Judge the background alone and you pick by "pretty"; what actually matters is "does the character read on it".**

**Learned by measurement**: on a 960×540 screen, **a 32px character is very small.**
Zoomed sheets don't convey it — the mockup does.

---

## The night palette is forced

The stage's empty cells are `#0E0E13` (nearly black), so **a bright background kills every character and monster silhouette.**
⇒ The `backdrop` preset in `tools/pixel/gen.py` forces a night palette in its clause.

**The `monster` preset can't be reused** — that one seats one beast in a box, so it carries chroma-green background,
`facing right` and `no background`. This is a **scene.**
**Generation factors differ too** — `monster` is **4×** (to protect thin legs and tusks),
`backdrop` is **2×** (backgrounds have nothing thin, so nothing is lost by a larger factor, and 2× clumps colors into pixel-art texture).

---

## Twelve candidates already exist

Under `tools/pixel/out/`. **Gitignored, so not in commits, but they stay on disk.**

| Direction | Folder | Count |
|---|---|---|
| **A sky / distance** (clouds · stars · dusk band) | `bgA_sky/` | 3 |
| **B distant farm** (barn · windmill · fence · fields) | `bgB_farm/` | 3 |
| **C forest silhouette** (layered conifer/broadleaf, mist) | `bgC_forest/` | 3 |
| **D large moon · hills** (one dead tree on the ridge) | `bgD_moon/` | 3 |

Each folder has two — **`*_960px.png` is the one to use** (960×544, downscaled to pixel art with k_centroid);
the suffix-less one is the 1920×1088 original (only for re-downscaling).

**The user has seen only A's three. Mockups for B, C and D's nine were never made.**

### Making mockups — `tools/pixel/bgmock.py`

```
python tools/pixel/bgmock.py [output-folder]
```

Makes individual mockups for all 12 plus `bg_compare.png` (a 2-column sheet) in one pass.
With no argument it writes to `tools/pixel/out/_bgmock/`.
**Sprites are read from the repo's `assets/`** — it once pointed at a scratchpad, and the next session
nearly couldn't run it because that folder was gone.
What it does is **lay real game-color terrain on the candidate and stand the player, `pig_body` and `chicken_body` at real size.**
**Judging the background alone makes the judgment false** — whether silhouettes die is only visible with things standing on it.

### Regenerating — the `backdrop` preset

```powershell
powershell -File tools\pixel\serve.ps1   # server. Does nothing if already up

$py = "C:\Users\djgnf\Desktop\window_project\CompyUI_2DPixel\ComfyUI_windows_portable\python_embeded\python.exe"
$neg = "text, watermark, ui, hud, characters, people, animals, bright daylight, foreground objects"

& $py tools\pixel\gen.py "<scene description>" --name bgX_name --preset backdrop `
    --width 1920 --height 1088 --batch 3 --negative $neg
```

**The four prompts actually used:**

```
A  empty night sky over a far horizon, layered clouds and faint stars,
   a band of dusk light low on the horizon, nothing else
B  a distant farm at night, silhouettes of a barn, a windmill and a fence line
   on low rolling hills, ploughed fields
C  a dense forest treeline at night seen from a distance,
   layered silhouettes of pine and oak, mist between the trunks
D  a huge low moon behind bare rolling hills at night, long soft haze,
   one dead tree on the ridge
```

**Always pass `--width 1920 --height 1088`.** The preset's `size` is **interpreted as square, so omitting height
gives 1920×1920.** 1088 because one screen is **960×540** and it is drawn at 2× then downscaled.
**45–57 seconds per image** — 12 images is 10 minutes. Run it in the background.
**Do not use `--preset monster`** — it carries chroma green, `facing right` and `no background`, so no scene comes out.

---

## TBD

**Do not force these full.**

- **Direction** — sky/distance · distant farm · forest silhouette · large moon and hills. **Candidates are generated; the user picks**
- **How many layers** and **each layer's scroll ratio** — after the direction is set
- **Tile width** — where the seam breaks
- **Backgrounds for stages 2 and 3** — only stage 1 (farm) opens
- **Does punching empty to transparent break anything else** — **nobody checked whether anything relies on
  the shader painting `EMPTY`.** That is the first question when implementing
