"""Keys a pulled picture's white paper to alpha and crops it to its ink — **run once per picture.**

    python tools/pixel/keywhite.py <in.png> <out.png>

The selection-box candidates were pulled as mint ink on OPAQUE WHITE paper, RGB with no alpha. A box
drawn on the glass has to show the island through it, so the paper has to become alpha before the
picture is any use — this is the selection-box lab's `common.load_ink` formula, line for line, applied
once here instead of at every mount, so the game loads a finished RGBA file and keys nothing at runtime.

  alpha     = clamp(1 - whiteness, 0, 1)
  whiteness = (min(r, g, b) / 255 - 158 / 255) / (1 - 158 / 255)

so pure white reads alpha 0, the full ink (158, 245, 212) reads alpha 1, and the anti-aliased edge
lands in between. **Every pixel's RGB is then set to the mint**, so the shape lives in the alpha alone.
The picture is cropped to the bounding box of alpha > INK_ALPHA — the candidate's own `_ink_box`, once.

No alpha normalisation: the 64 px downsample never reaches the full ink and peaks around 0.72, and the
user saw the candidate at that strength. The asset is that picture, not a brighter one.

The README's `ink.py` is cited and is not on disk, and `cutbg.py` keys chroma green only — neither does
this, which is why a third one-off exists.
"""

import sys
from pathlib import Path

from PIL import Image

INK = (158, 245, 212)
# Alpha above which a pixel counts as ink when the crop box is found.
INK_ALPHA = 0.3


def key_white(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    ink_min = min(INK) / 255.0
    span = 1.0 - ink_min
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, _ = px[x, y]
            whiteness = (min(r, g, b) / 255.0 - ink_min) / span
            a = max(0.0, min(1.0, 1.0 - whiteness))
            px[x, y] = (INK[0], INK[1], INK[2], int(round(a * 255.0)))
    return img


def ink_box(img: Image.Image):
    """The bounding box of every pixel over INK_ALPHA — (x0, y0, x1, y1), end exclusive."""
    px = img.load()
    cut = INK_ALPHA * 255.0
    xs, ys = [], []
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] > cut:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def report(img: Image.Image, box) -> None:
    """The five numbers the ticket records: box, size, ink count, peak alpha, interior alpha."""
    px = img.load()
    cut = INK_ALPHA * 255.0
    over = 0
    peak = 0
    for y in range(img.height):
        for x in range(img.width):
            a = px[x, y][3]
            peak = max(peak, a)
            if a > cut:
                over += 1
    # The interior: everything at least 4 px inside the crop, where a frame has no ink at all.
    interior = 0
    for y in range(4, img.height - 4):
        for x in range(4, img.width - 4):
            interior = max(interior, px[x, y][3])
    mid = img.height // 2
    edge = [round(px[x, mid][3] / 255.0, 2) for x in range(0, min(4, img.width))]
    print(f"ink box at ({box[0]}, {box[1]}), {img.width} x {img.height}")
    print(f"{over} px over alpha {INK_ALPHA}")
    print(f"peak alpha {peak / 255.0:.3f}")
    print(f"interior alpha <= {interior / 255.0:.3f}")
    print(f"mid-row left edge alphas {edge} (the stroke is the pixels before the first drop)")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: keywhite.py <in.png> <out.png>")
        return 2
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    img = key_white(Image.open(src))
    box = ink_box(img)
    if box is None:
        print(f"{src}: no ink over alpha {INK_ALPHA}")
        return 1
    img = img.crop(box)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst)
    report(img, box)
    print(f"wrote {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
