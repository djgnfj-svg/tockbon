"""tockbon asset generator — calls a local ComfyUI (FLUX.2 klein base 4B).

    python gen.py "prompt" --name glyph_spread --preset glyph --batch 8

What this repo makes is not characters but **magic circle UI · glyphs · runes · circles**.
  => The default is `--lora 0`. Turning on the 4-walk LoRA yields **a human spritesheet even for a UI prompt**
   (measured in the original pipeline's PROMPTS.md). That one fact is why the preset carries that value.
"""

import argparse
import io
import json
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from itertools import product
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).parent
CFG = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
SERVER = CFG["server"].rstrip("/")
WORKFLOW = ROOT / "workflows" / "base_api.json"
OUT = ROOT / "out"

# --- style presets ------------------------------------------------
# **This is the place that stops the art from splitting apart within one game.** Writing the style phrasing
#  by hand for every prompt guarantees a split — that is the second TODO item of the original pipeline.
#
# **But keeping several presets causes the same thing** (measured).
#  Things that get laid on the assembly window **together** were being generated with different presets:
#   · `frame` (circle) = concentric rings · `glyph` = bold simple shapes
#   · `rune`          = **pixel art game icon, 16-bit shading** <- only the rune was pixel art
#  => It was right that no amount of prompt fiddling made them match. The user's judgment was "nothing like what I wanted".
#
# **Things that appear on one screen together are generated with one preset** — circle, rune and glyph are all `sigil`.
#  **The seed is not this axis.** Generating the same prompt with 6 seeds gave six compositions and
#   six identical textures => the seed decides **composition**, the preset decides **texture**.
#  Detail is in `docs/design/circle-art.md`, "matching texture is the seed's job — it was not one big piece".
#
# `style` is appended **after** the prompt. Put it in front and the model draws only style and drops the content.
# `size` is the **generation resolution** and `down` is the **final pixel size**. They are different axes —
#  drawing at 512 and downscaling to 32px is completely different from drawing at 32px from the start
#  (FLUX breaks down in form below 512). => **Draw big and downscale.**
PRESETS = {
    # Geometric pattern that goes into a layer. On screen it is 31px across, so **detail cannot fit in principle.**
    "glyph": {
        "style": "solid black flat geometric line art on a plain white background, "
                 "bold simple shapes, perfectly symmetrical, centered, "
                 "no shading, no gradient, no color, no text",
        "lora": 0.0, "size": 512, "down": 64, "steps": 28, "cfg": 5.0,
    },
    # The circle — a concentric frame whose layers read apart by eye.
    "frame": {
        "style": "solid black line art on a plain white background, "
                 "concentric rings with clear gaps between layers, "
                 "perfectly round and symmetrical, flat top-down view, "
                 "no shading, no color, no text",
        "lora": 0.0, "size": 512, "down": 256, "steps": 28, "cfg": 5.0,
    },
    # The circle, one piece — **this is what makes the three circles (plain, fusion, triangle) read as one set.**
    #
    # There is one reason it is kept apart from `frame`: `frame`'s style contains `perfectly round`, so
    #  **the triangle circle comes out as a circle.** Let the preset speak the silhouette and every circle needs
    #  its own preset => **the prompt speaks the silhouette, and the preset holds only the texture**
    #  (line weight, ground, the character of the ornament).
    #
    # **`down` being 0 is deliberate.** The adopted candidate (`docs/mockups/fusion-circle-ref.png`) is
    #  the 1024 **original as-is**, not the `_560px` downscaled version — it is line art, so passing it through
    #  k_centroid breaks thin lines. The size reference is **circle 1024** in `docs/design/circle-art.md`.
    #
    # **`size` is 1024, so one image is 4x heavier than a 512 one.** Measure one image before queuing a big batch.
    "sigil": {
        # **It started as `thin even line weight` and was changed** (measured). The lines came out thin
        #  and the contrast did not match the adopted candidate. And `no border` does not go into style —
        #  it is removed via negative (put in style, the word "border" actually summons one into the image).
        # **The preset holds only texture. Density is decided by the prompt** (user judgment).
        #  This once held `ornate intricate geometric ornament, bands of repeating diamond and
        #   chevron pattern`, and with it **even the circle filled up with pattern.**
        #  If the circle is ornate there is **no room to lay a glyph on it** — laid on, it drowns in the circle's
        #   pattern and the GDD's "if the order is not visible on screen the player will never learn the rule" dies.
        #   => **The glyph carries the ornateness. The circle gives up an empty band** (`docs/design/circle-art.md`).
        #  So do not put a density word back into this string — the preset applies to circle, rune and glyph
        #   **all three**, and one word here makes all three ornate at once.
        # **`bold` is weight, not density.** Removing the density words (`ornate` · `repeating pattern`) also
        #  removed `bold`, and the lines went thread-thin — what was restored was weight alone.
        "style": "bold black line art on a cream white paper background, "
                 "strong contrast, clean confident thick lines, "
                 "flat top-down view, perfectly symmetrical, centered, "
                 "no shading, no gradient, no color, no text",
        "lora": 0.0, "size": 1024, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # The rune — it does not need to be geometric (decided by the user). All that matters is that the element reads at a glance.
    "rune": {
        "style": "pixel art game icon, bold readable silhouette, centered, "
                 "plain white background, 16-bit shading",
        "lora": 0.0, "size": 512, "down": 96, "steps": 28, "cfg": 5.0,
    },
    # The bolt head — **the thing that flies.** The only preset whose background color differs from the four above.
    #  Glyph, rune and circle sit **on the assembly window (bright paper)**, but the bolt flies **over the dark stage.**
    #   Generated on a white background, the bright core does not separate from the ground and alpha cannot be pulled —
    #   sheet.py's comment "the background color changes the judgment" applies at the generation stage too.
    #
    # **Only one pose, flying right, is generated.** The bolt flies through 360 degrees so code rotates it
    #  (`spell_view` knows the velocity vector). Generating per direction would mean 10 runes x N directions.
    #
    # **No glow in the image.** `fx_tuning.BOLT_GLOW_RATIO` already draws the halo —
    #  put it in the image too and there are two places, and when a generation shrinks the halo alone fails to follow.
    #  => What the prompt asks for is **the core silhouette.**
    #
    # Grounds for `down` 16: `fx_tuning.FX_SIZES.bolt_px` is **radius 8px** at generation 0 = 16px diameter.
    #  Change that value and the image must be regenerated — matching it by downscaling breaks the pixels.
    # **Additive blending is the whole of this preset.** `spell_view._ready()` sets BLEND_MODE_ADD =>
    #  black pixels are transparent for free but **dark colors do not appear on screen at all.**
    #  => Neither outline nor shading can be used in principle. The image must be **"light"**, not "a lump".
    #  The first batch (18 images), generated without knowing this, all had shading and were out of spec.
    #
    # **The absence of `centered` is deliberate.** The core sits not at the slot's center but **8px to the right** —
    #  the rotation pivot is the core, so centering it leaves no room for the tail, and putting it left makes the head
    #  swing around in a circle.
    #  => The prompt speaks the placement.
    #
    # `down` 32 · generated 512x256 (2:1) => final **32x16**. The grounds are `fx_tuning.FX_SIZES.bolt_px` 8
    #  (radius 8 = head diameter 16), and the head alone fills 16x16, leaving **0 room for the tail**, so the left was extended by 16px.
    "bolt": {
        "style": "pixel art projectile, only bright glowing hot colors, "
                 "on a pure solid black background, "
                 "no dark outline, no shading, no gradient background, "
                 "no text, no character, no frame, no border",
        "lora": 0.0, "size": 512, "down": 32, "steps": 28, "cfg": 5.0,
    },
    # The monster — **the thing that stands on one screen with the player.** That one fact is why it is kept apart from the five above.
    #  Circle, rune and glyph lie on the assembly window (bright paper) and the bolt is light, but the monster
    #  **stands next to the player on the stage.**
    #  => The standard to match is not "does it suit the assembly window" but **"does it live in the same world as
    #   `assets/character/wizard_body.png`"**. That image was actually measured:
    #   the darkest color is **`(79,52,76)` — a dark purple, not pure black** — and it has 35 colors.
    #  That is why style carries `dark desaturated outline` and not `black outline` —
    #   a pure black outline **disappears** on the sky `#0e0e13` (sum 41), leaving the fill to carry the silhouette alone.
    #
    # **`lora` being 0 has a different reason here.** The five above are 0 because "humans show up";
    #  this one is a beast so that worry does not apply — it is still 0 because the 4-walk LoRA puts out
    #  **a 4-direction walk sheet.** What is needed now is **one still frame** (design stages 1-4), and code flips left/right.
    #  => Raise this value the day walk animation is generated. **On that day `down` becomes the sheet width too.**
    #
    # **The preset does not hold `size` and `down`.** That differs from the five above, and it is deliberate —
    #  every monster has a different box (`docs/design/monsters.md`: pig 44x32 · chicken 24x28).
    #  => **The caller supplies `--width/--height/--down`.** The ratio must match the generation size exactly for
    #   `run_one`'s `dh = down * h / w` to produce the design's height.
    #
    # **The generation size is 4x the target.** That is the opposite of the presets above ("draw big and downscale"),
    #  and there is a reason — the same prompt was generated at **704x512 (16x) · 352x256 (8x) · 176x128 (4x)**
    #  and compared. 16x and 8x **do not fill the box** (41x24 comes out in a 44x32 slot) and the form mushes.
    #  **Only 4x filled 44x32.** k_centroid picks a block's dominant color, so the larger the factor the more
    #  thin things (legs, outlines) vanish wholesale.
    #  Measured: pig `--width 176 --height 128 --down 44` -> 44x32. Chicken `--width 96 --height 112 --down 24` -> 24x28.
    #  The `size` 640 below is a placeholder that fits neither. Recompute the ratio when generating a new monster.
    #
    # **The chroma green background is this preset's one trap.** Generated on a white background,
    #  **the white chicken's body was punched right through** (measured) — the fill bleeding in from the edge
    #  takes the white body for background and walks through it. Cutting by color fails for the same reason.
    #  => Use **a color no beast has** as the background and cut by hue. A black boar and a white chicken both survive.
    #  This is a different problem from `bolt`'s black background — there, additive blending makes black transparent for free.
    #
    # **The outline was given up on.** Putting `thick black outline` in style and raising cfg to 7.5 still leaves
    #  nothing once downscaled to 44px (all four measured). The player (`wizard_body.png`) wears a darkest color of
    #  **`(79,52,76)` — a dark purple outline** — so **this preset's output differs from the player.**
    #  => If it shows once placed side by side, open this back up then. **Written down so nobody walks past it unaware.**
    "monster": {
        "style": "pixel art game sprite of a single animal, side view, full body, "
                 "standing on the ground, facing right, "
                 "bold readable silhouette, flat cel shading, "
                 "muted low-saturation dusty colors, "
                 "on a plain solid bright chroma green background, "
                 "no text, no frame, no border, no shadow",
        "lora": 0.0, "size": 640, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # The backdrop — **behind the stage. The game today has no place to attach this at all** (investigated).
    #  The `#0E0E13` that looks like sky is not a background layer but **`cell_materials.DEFS[EMPTY].rgb`**, and
    #  `cell_renderer` paints the whole grid **opaquely** (`_rgb_to_color` is `Color8`, so alpha 255).
    #  => **Whatever you put behind CellRenderer is 100% hidden.** Putting in a backdrop requires a code change
    #   in the shader first, pulling empty cells out as transparent. **The art waits on that decision.**
    #
    # **The `monster` preset cannot be used as-is.** That one is "seat one beast in a box", so it carries
    #  `no_background` · `facing right` · chroma green throughout. This is **a scene.**
    #
    # **Generate at 2x -> downscale.** That differs from `monster`'s 4x too — a backdrop has no thin things
    #  (legs, tusks) so nothing is lost by a bigger factor, and at 2x the colors clump into a pixel art texture
    #  while the form holds.
    #  One screen is **960x540** (the viewport in `project.godot`), so draw at 1920x1088 and downscale to 960x544.
    #
    # **It must be dark.** The stage's empty cells are `#0E0E13` and the character and monsters stand on it —
    #  a bright backdrop **kills every silhouette.** That is why style calls for a night palette.
    #
    # **It is not a horizontally repeating tile.** FLUX does not match seams => once a direction is settled,
    #  either **kill the seam with a mirrored copy** or split it into layers. For now it is **one whole screen** and only the direction is chosen.
    "backdrop": {
        "style": "pixel art side-scroller game background, distant scenery only, "
                 "dark night palette, muted low-saturation dusty colors, "
                 "simple flat shapes with a clear horizon line, "
                 "no characters, no animals, no text, no frame, no border, no ui",
        "lora": 0.0, "size": 1920, "down": 960, "steps": 28, "cfg": 5.0,
    },
    # The daylight backdrop — **the same layer as `backdrop`, the opposite palette.** Used by **both** the town
    #  and stage 1: `docs/design/town.md` calls for "one room. **Bright**", and **the user rejected the night sky
    #  for stage 1 too** — "a greener farm feel, not a night sky".
    #  => The night clause is dropped and daylight put in its place. **Everything else is kept identical**
    #   (2x -> downscale, distant scenery only, no characters), because it hangs on the same `SkyBackground` node.
    #
    # **Bright does not mean saturated.** The character (`wizard_body.png`) is a dark purple silhouette, and on a
    #  washed-out bright field it disappears just as it does at night. `muted` is kept for exactly that reason.
    "daylight": {
        "style": "pixel art side-scroller game background, distant scenery only, "
                 "bright daylight palette, soft haze, "
                 "muted low-saturation dusty colors, "
                 "simple flat shapes with a clear horizon line, "
                 "no characters, no animals, no text, no frame, no border, no ui",
        "lora": 0.0, "size": 1920, "down": 960, "steps": 28, "cfg": 5.0,
    },
    # The cell — **the new game's one body.** Everything in the cell game is this shape: the host, a clone,
    #  and every animal that walks the habitat. The cell GDD's *Screen* calls it a rounded square blob.
    #
    # **It is kept apart from `monster` for one reason: that preset says `side view`.** The old game was
    #  side-on and this one is top-down (the decision *Top-down, not side-view floors*), so reusing it
    #  yields a beast standing in profile with nowhere to put the six part anchors.
    #
    # What is **inherited from `monster` deliberately**, because both were paid for in measurement there:
    #  - **chroma green ground, never white.** A white animal generated on white gets punched through by the
    #    fill bleeding in from the edge (measured on a chicken). Cut with `cutbg.py`, which cuts by hue.
    #  - **generate at 4x the target, not 8x or 16x.** Larger factors do not fill the box and thin things
    #    vanish, because k_centroid takes a block's dominant colour.
    #  - **no outline in the prompt.** Four attempts left nothing at 44px in the old game. If it matters once
    #    two sprites sit side by side, reopen it then.
    #
    # ⚠ **The cell game decided against images for the body on 2026-08-13** — it is an outline and a dot,
    #  drawn by code (the decision *The body is an outline drawn by code*). **This preset is kept for the
    #  parts that survive being cut off a body** — jaws, horns, wings — and for looking at candidates before
    #  committing. A leg generated on its own is a brown stick; that was measured here.
    #
    # **`down` 64 is a guess.** Nothing in `src/` draws from an image, so there is no measured box to match.
    #  Regenerate, do not rescale, when a number is chosen.
    #
    # **The style says nothing about which animal.** One preset has to carry the host, the clones and every
    #  species in the habitat, or they cannot stand in the same picture — parts drawn from different presets
    #  can never be made to match however the prompt is tuned (`CLAUDE.md`, measured).
    #  => **The prompt speaks the creature. The preset holds only the texture.**
    "cell": {
        "style": "pixel art game sprite, flat top-down view seen from directly above, "
                 "a single small creature with a rounded square body, "
                 "bold readable silhouette, flat cel shading, chunky simple shapes, "
                 "muted low-saturation colors, "
                 "on a plain solid bright chroma green background, "
                 "no text, no frame, no border, no shadow, no ui",
        "lora": 0.0, "size": 256, "down": 64, "steps": 28, "cfg": 5.0,
    },
    # A material grain tile for the terrain (`docs/design/terrain-look.md` (3)). **It is multiplied into the
    #  palette color, so what matters is the light-dark pattern, not the hue** — the color still comes from
    #  `cell_materials.gd`, and a tile with its own strong color would fight it.
    #
    # **Seamlessness is not asked for in the prompt.** FLUX will not match edges however it is worded
    #  (measured on the backdrops), so the tile is **mirrored into a 2x2 after generation** — the same trick.
    #
    # **A cell is 4 screen px.** A 128px tile spans 32 cells, so the grain only reads across a wall,
    #  never inside one cell. Generating larger buys nothing.
    "texture": {
        "style": "seamless pixel art material texture, flat top down, even lighting, "
                 "fine grain detail, muted low-saturation dusty colors, "
                 "no text, no frame, no border, no objects",
        "lora": 0.0, "size": 512, "down": 128, "steps": 28, "cfg": 5.0,
    },
    # The assembly window — an open grimoire. Stretching it with 9-slice misaligns the corners (measured in the original PROMPTS.md).
    "ui": {
        "style": "pixel art RPG UI panel, 16-bit game interface, "
                 "clean edges, no text, no characters",
        "lora": 0.0, "size": 512, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # As-is, with no preset. No style phrasing is appended either.
    "raw": {"style": "", "lora": 0.0, "size": 512, "down": 0, "steps": 28, "cfg": 5.0},
}


def api_post(path, payload):
    req = urllib.request.Request(
        f"{SERVER}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def api_get(path):
    with urllib.request.urlopen(f"{SERVER}{path}") as r:
        return json.loads(r.read())


def fetch_image(info):
    q = urllib.parse.urlencode(
        {"filename": info["filename"], "subfolder": info["subfolder"], "type": info["type"]}
    )
    with urllib.request.urlopen(f"{SERVER}/view?{q}") as r:
        return Image.open(io.BytesIO(r.read())).convert("RGB")


def k_centroid(image, width, height, centroids=2):
    """Picks the dominant color per block with k-means. The point is that it is the **dominant** color, not the mean —
    with a mean, the black line and the white paper mix into a gray border, and that is not pixel art."""
    out = Image.new("RGB", (width, height))
    wf = image.width / width
    hf = image.height / height
    for x, y in product(range(width), range(height)):
        tile = image.crop((int(x * wf), int(y * hf), int((x + 1) * wf), int((y + 1) * hf)))
        tile = tile.quantize(colors=centroids, method=1, kmeans=centroids).convert("RGB")
        dominant = max(tile.getcolors(), key=lambda c: c[0])[1]
        out.putpixel((x, y), dominant)
    return out


def build(base_wf, text, negative, steps, cfg, seed, w, h, lora):
    wf = json.loads(json.dumps(base_wf))
    wf["5"]["inputs"]["text"] = text
    wf["6"]["inputs"]["text"] = negative
    wf["4"]["inputs"]["strength_model"] = lora
    wf["7"]["inputs"]["cfg"] = cfg
    wf["9"]["inputs"].update(steps=steps, width=w, height=h)
    wf["10"]["inputs"].update(width=w, height=h)
    wf["11"]["inputs"]["noise_seed"] = seed
    # Nodes 15 and 16 (the engine-side 4x downscale) are **not used.** The size is decided here, so
    #  letting the workflow downscale to a fixed 128px would put that value in two places and split them.
    #  => Python does the downscale (`down` below). The nodes are left in place but their output is not read.
    return wf


def run_one(base_wf, args, seed, index, outdir, preset):
    text = args.prompt if not preset["style"] else f"{args.prompt}. {preset['style']}"
    wf = build(base_wf, text, args.negative, args.steps, args.cfg,
               seed, args.width, args.height, args.lora)

    prompt_id = api_post("/prompt", {"prompt": wf})["prompt_id"]
    print(f"  [{index}] seed={seed} ...", flush=True)

    started = time.time()
    while True:
        hist = api_get(f"/history/{prompt_id}")
        if prompt_id in hist:
            entry = hist[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                for msg in status.get("messages", []):
                    if msg[0] == "execution_error":
                        raise RuntimeError(msg[1].get("exception_message", msg[1]))
                raise RuntimeError("execution failed")
            if status.get("completed"):
                break
        if time.time() - started > 900:
            raise TimeoutError("900초 넘게 안 끝났다")
        time.sleep(1.0)

    raw = fetch_image(entry["outputs"]["14"]["images"][0])
    stem = f"{args.name}_{index:02d}_seed{seed}"
    raw.save(outdir / f"{stem}.png")

    if args.down > 0:
        # Take the aspect ratio from the original. Assuming square squashes a non-square UI.
        dh = max(1, round(args.down * raw.height / raw.width))
        k_centroid(raw, args.down, dh).save(outdir / f"{stem}_{args.down}px.png")

    print(f"  [{index}] {time.time() - started:.1f}s -> {stem}.png", flush=True)
    return stem


def main():
    p = argparse.ArgumentParser(description="tockbon 에셋 생성 (로컬 ComfyUI)")
    p.add_argument("prompt")
    p.add_argument("--name", default="asset", help="출력 폴더/파일 이름")
    p.add_argument("--preset", default="glyph", choices=sorted(PRESETS), help="스타일 프리셋")
    p.add_argument("--batch", type=int, default=4, help="후보 몇 장")
    p.add_argument("--seed", type=int, default=-1, help="-1이면 무작위")
    p.add_argument("--width", type=int, default=0, help="생성 폭 (0이면 프리셋 값)")
    p.add_argument("--height", type=int, default=0, help="생성 높이 (0이면 프리셋 값)")
    p.add_argument("--down", type=int, default=-1, help="최종 픽셀 폭 (0이면 안 내림, -1이면 프리셋 값)")
    p.add_argument("--steps", type=int, default=0)
    p.add_argument("--cfg", type=float, default=0.0)
    p.add_argument("--lora", type=float, default=-1.0, help="4-walk LoRA 강도. UI/문양은 0이다")
    p.add_argument("--negative", default="")
    args = p.parse_args()

    preset = PRESETS[args.preset]
    if args.width <= 0:
        args.width = preset["size"]
    if args.height <= 0:
        args.height = args.width
    if args.down < 0:
        args.down = preset["down"]
    if args.steps <= 0:
        args.steps = preset["steps"]
    if args.cfg <= 0:
        args.cfg = preset["cfg"]
    if args.lora < 0:
        args.lora = preset["lora"]

    try:
        api_get("/system_stats")
    except (urllib.error.URLError, OSError):
        print(f"ComfyUI 서버가 {SERVER} 에 없다. tools/pixel/serve.ps1 을 먼저 돌려라.")
        return 1

    base_wf = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    outdir = OUT / args.name
    outdir.mkdir(parents=True, exist_ok=True)

    print(f'"{args.prompt}"')
    print(f"  preset={args.preset} {args.width}x{args.height} steps={args.steps} "
          f"cfg={args.cfg} lora={args.lora} down={args.down or '-'} x{args.batch}")

    for i in range(1, args.batch + 1):
        seed = random.randint(0, 2**31 - 1) if args.seed < 0 else args.seed + i - 1
        run_one(base_wf, args, seed, i, outdir, preset)

    print(f"\n=> {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
