# -*- coding: utf-8 -*-
"""Measure the colours this game actually puts on the glass, and draw them as a strip.

⚠ Two sources, and they are not interchangeable:
  · colours WRITTEN DOWN as numbers (the outline, the sea, the sky) are read from the source, exact.
    Sampling those off a screenshot picks up the sun and comes back wrong.
  · colours that arrive through a LIT MESH (the island, the cliffs, the buildings, the hull) have no
    single true value — the same green is two colours on screen, one sunlit and one shaded — so those
    are measured off a real frame, and BOTH faces are kept.

The body row is deliberately empty: a body palette taken from art that has been rejected would
enshrine the mess. It gets filled from the wolf that wins.
"""
import os, re, sys
from collections import Counter
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
LOOK = os.path.join(HERE, "..", "..", "src", "look.gd")
FRAME = os.path.join(HERE, "out", "land_now.png")

# the written-down colours that are part of the WORLD, not the interface
WORLD_CONSTS = {"COL_OUTLINE", "COL_SKY", "COL_WATER", "COL_WATER_FOAM",
                "COL_WATER_SHALLOW", "COL_WATER_FLECK"}


def written():
    out = []
    src = open(LOOK, encoding="utf-8").read()
    for m in re.finditer(r"^const (COL_\w+) := Color\(([^)]*)\)", src, re.M):
        name, args = m.group(1), [a.strip() for a in m.group(2).split(",")]
        if name not in WORLD_CONSTS:
            continue
        r, g, b = (float(a) for a in args[:3])
        out.append((name, (round(r * 255), round(g * 255), round(b * 255))))
    return out


def measured(n=14):
    im = Image.open(FRAME).convert("RGB")
    # 5-bit buckets: enough to separate a sunlit face from a shaded one, coarse enough that the
    # renderer's gradient does not come back as four hundred greens.
    c = Counter((p[0] >> 3 << 3, p[1] >> 3 << 3, p[2] >> 3 << 3) for p in im.getdata())
    total = sum(c.values())
    return [(rgb, v / total) for rgb, v in c.most_common(n)]


def strip(colours, path, cell=32):
    im = Image.new("RGB", (cell * len(colours), cell))
    for i, rgb in enumerate(colours):
        for x in range(cell):
            for y in range(cell):
                im.putpixel((i * cell + x, y), rgb)
    im.save(path)


if __name__ == "__main__":
    print("WRITTEN DOWN — exact, taken from the source")
    w = written()
    for name, rgb in w:
        print("  %-20s #%02X%02X%02X" % (name, *rgb))

    print("\nMEASURED off a real frame — lit meshes, both faces")
    m = measured()
    for rgb, share in m:
        print("  #%02X%02X%02X  %5.1f%%" % (*rgb, share * 100))

    cols = [rgb for _, rgb in w] + [rgb for rgb, _ in m]
    out = os.path.join(HERE, "out", "_palette_world.png")
    strip(cols, out)
    print("\nwrote %s  (%d colours)" % (out, len(cols)))
