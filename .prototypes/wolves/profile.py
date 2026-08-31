# -*- coding: utf-8 -*-
"""Print what the six fixture images actually look like, band by band, before guessing a rule again."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")
BANDS = 8

NAMES = ["c04_brown", "c07_slate", "c12_ash", "c01_light_grey", "c03_black", "c06_tan"]


def widest_run(im, y):
    bb = im.getbbox()
    run = worst = 0
    for x in range(bb[0], bb[2]):
        if im.getpixel((x, y))[3] > 128:
            run += 1
            worst = max(worst, run)
        else:
            run = 0
    return worst


for n in NAMES:
    im = Image.open(os.path.join(DST, n + ".png")).convert("RGBA")
    bb = im.getbbox()
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    prof = []
    for b in range(BANDS):
        y0 = bb[1] + h * b // BANDS
        y1 = bb[1] + h * (b + 1) // BANDS
        prof.append(max(widest_run(im, y) for y in range(y0, y1)))
    print("%-16s w=%2d  bands(top->bottom): %s" % (n, w, " ".join("%2d" % p for p in prof)))
