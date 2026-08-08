"""Cuts the `monster` preset's chroma-green ground and trims to the beast.

**Why hue and not "equal to the background color"**: `k_centroid` downscaling averages a block, so the
edge pixels come out as **green mixed with the body** — an exact-color match leaves a green fringe one
pixel wide all the way around, and on the stage's `#0E0E13` that fringe is the brightest thing on screen.
=> Cut by "green dominates", then **kill the leftover green cast on the surviving edge pixels** by pulling
green down to the max of the other two channels.

**Why not flood fill from the edge**: `docs/design/monsters.md` — a white chicken generated on a white
ground got walked straight through. Chroma green exists so that a *color* test is safe; a fill is not needed.

Usage:
    python tools/pixel/cutbg.py <in.png> <out.png> [--pad 0]
"""
import argparse
import sys
from pathlib import Path

from PIL import Image


def is_chroma(r, g, b):
    # The generated ground is near (26,246,6). "Green dominates and is bright" catches the ground and
    #  the blend band, and **no beast color reaches it** — the preset asks for muted dusty colors.
    return g > 90 and g > r * 1.25 and g > b * 1.25


def cut(im):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if is_chroma(r, g, b):
                px[x, y] = (0, 0, 0, 0)
            elif g > max(r, b):
                # Surviving edge pixel still carrying a green cast. Pulling green down to the other two
                #  keeps the pixel's brightness while removing the tint.
                px[x, y] = (r, max(r, b), b, a)
    return im


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--pad", type=int, default=0, help="트림 후 사방 여백")
    a = p.parse_args()

    im = cut(Image.open(a.src))
    box = im.getbbox()
    if box is None:
        print("전부 배경으로 잘렸다. is_chroma 를 의심해라")
        return 1
    x0, y0, x1, y1 = box
    x0, y0 = max(0, x0 - a.pad), max(0, y0 - a.pad)
    x1, y1 = min(im.width, x1 + a.pad), min(im.height, y1 + a.pad)
    out = im.crop((x0, y0, x1, y1))

    Path(a.dst).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.dst)
    print(f"{im.size} -> {out.size}  {a.dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
