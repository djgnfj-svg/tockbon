"""Crops out the bolt head only — 32x16 (head+tail) -> 16x16 (head only).

    python crop_head.py out/fire_head/fire_head_08_seed1407674110_32px.png --out assets/<folder>/bolt_fire.png

⚠ **No spell folder ships any more** — the bolt was the magic-circle game's and went with it. The
 destination is whichever `assets/` folder the caller is filling.

**Discarding the tail is the whole of this tool.** The tail is drawn by code (`spell_view._draw_trail`) —
 the grounds are "the bolt head image" in `docs/design/circle-rune-glyph.md` and the point is speed:
 the bolt is 1600px/s, so it covers **26.7px per frame.** The drawn tail (16px) is shorter than that, so
 **it is buried whole in the trail while moving.** It is visible only on a still screen.

**Seating the core at the dead center of the slot is all the rest.**
 `spell_view._draw_head` draws `head_px()` as the **center**, so if the core is off the slot's center
 **the bolt is drawn at a position offset from its real one** — and that is not an error, it only looks "a bit off".
 So it is not cropped by eye but located by the **brightness centroid.**

**Alpha is not pulled.** `spell_view` uses additive blending (`BLEND_MODE_ADD`), so black pixels add to 0 —
 **the black background acts as transparency as-is.** Making an alpha would only add one more import setting.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

SIZE = 16  ## Final side length (px). `fx_tuning.FX_SIZES.bolt_px` generation 0 = radius 8 => diameter 16


def core_center(img, search_from_x):
    """Centroid weighted by the square of brightness. **The square is the point** —
    with linear weighting the dark wide tail outvotes the core and drags the center left (confirmed by measurement)."""
    px = img.load()
    sw = sx = sy = 0.0
    for y in range(img.height):
        for x in range(search_from_x, img.width):
            r, g, b = px[x, y]
            w = float(r + g + b) ** 2
            sw += w
            sx += w * (x + 0.5)
            sy += w * (y + 0.5)
    if sw <= 0.0:
        return None
    return sx / sw, sy / sw


def main():
    p = argparse.ArgumentParser(description="탄 머리만 16×16 으로 자른다")
    p.add_argument("src")
    p.add_argument("--out", required=True)
    p.add_argument("--size", type=int, default=SIZE)
    # The premise that the core is on the right is preset `bolt`'s contract (an image flying right).
    #  Measuring the centroid over the whole image lets the tail pull it, so only **the right half** is looked at.
    p.add_argument("--from-frac", type=float, default=0.5, help="무게중심을 재기 시작할 가로 위치")
    args = p.parse_args()

    src = Path(args.src)
    img = Image.open(src).convert("RGB")

    c = core_center(img, int(img.width * args.from_frac))
    if c is None:
        print(f"불투명 픽셀이 하나도 없다: {src}")
        return 1
    cx, cy = c

    half = args.size / 2.0
    # Round and crop on an **integer boundary**. Cropping on fractions makes PIL interpolate and blur the pixels,
    #  and that is not pixel art.
    x0 = int(round(cx - half))
    y0 = int(round(cy - half))

    out = Image.new("RGB", (args.size, args.size), (0, 0, 0))
    # Whatever falls outside the original stays black — under additive blending that is "nothing".
    out.paste(img.crop((x0, y0, x0 + args.size, y0 + args.size)), (0, 0))

    dst = Path(args.out)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"{src.name}  코어 ({cx:.1f}, {cy:.1f}) -> 자른 자리 ({x0}, {y0})  =>  {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
