# -*- coding: utf-8 -*-
"""Point the ground check at the three that ARE known to carry ground, and at three that are clean.

A check nobody has seen fail is not a check. These six are the fixture: c04, c07 and c12 came back
with dirt or a painted shadow under the paws and were rejected by eye; c01, c03 and c06 did not.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")

BOTTOM_ROWS = 4
GROUND_AT = 0.62

DIRTY = ["c04_brown", "c07_slate", "c12_ash"]
CLEAN = ["c01_light_grey", "c03_black", "c06_tan"]


def widest_bottom_run(im):
    bb = im.getbbox()
    ink_w = bb[2] - bb[0]
    worst = 0
    for y in range(bb[3] - BOTTOM_ROWS, bb[3]):
        run = 0
        for x in range(bb[0], bb[2]):
            if im.getpixel((x, y))[3] > 128:
                run += 1
                worst = max(worst, run)
            else:
                run = 0
    return worst / ink_w


bad = 0
for group, names, want_ground in (("KNOWN DIRTY", DIRTY, True), ("KNOWN CLEAN", CLEAN, False)):
    print(group)
    for n in names:
        im = Image.open(os.path.join(DST, n + ".png")).convert("RGBA")
        frac = widest_bottom_run(im)
        says_ground = frac >= GROUND_AT
        ok = says_ground == want_ground
        bad += 0 if ok else 1
        print("  %-16s %4.0f%%  check says %-6s  %s"
              % (n, frac * 100, "GROUND" if says_ground else "paws", "ok" if ok else "WRONG"))

print("\n%s" % ("the check separates all six" if bad == 0 else "the check is wrong on %d of 6" % bad))
