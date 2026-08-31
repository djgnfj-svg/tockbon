# -*- coding: utf-8 -*-
"""Does this candidate have ground stuck to it? — and the fixture that says the check works.

⚠⚠ **THE FIRST VERSION OF THIS CHECK MEASURED THE BOTTOM FOUR ROWS AND CAUGHT NOTHING.** It called
all three known-dirty candidates clean, and the round nearly went on believing eight pulls were fine.
**The bottom rows are the wrong place to look**: a painted patch of dirt is a slanted quad, so at its
very last row it is a narrow corner, exactly like a paw.

Measured off the six fixture images, band by band: the separation is at the **seventh of eight bands**
— the height of the animal's shins. There a wolf is legs with gaps between them and ground is one
unbroken bar.

    known dirty   84%  57%  59%
    known clean   25%  16%  18%

⚠ **Six images set this threshold, so it is a screen and not a proof.** It goes red on the three it
was built from; anything new it clears still gets looked at.
"""
import os, sys
from PIL import Image

BANDS = 8
BAND = 6          # seventh of eight, counting from the top
GROUND_AT = 0.40


def bottom_bar_fraction(im):
    """Widest unbroken run of opaque pixels across the shin band, over the animal's own width."""
    bb = im.getbbox()
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    y0 = bb[1] + h * BAND // BANDS
    y1 = bb[1] + h * (BAND + 1) // BANDS
    worst = 0
    for y in range(y0, max(y1, y0 + 1)):
        run = 0
        for x in range(bb[0], bb[2]):
            if im.getpixel((x, y))[3] > 128:
                run += 1
                worst = max(worst, run)
            else:
                run = 0
    return worst / w


def has_ground(path):
    return bottom_bar_fraction(Image.open(path).convert("RGBA")) >= GROUND_AT


DIRTY = ["c04_brown", "c07_slate", "c12_ash"]
CLEAN = ["c01_light_grey", "c03_black", "c06_tan"]


def fixture(folder):
    bad = 0
    for names, want in ((DIRTY, True), (CLEAN, False)):
        for n in names:
            f = bottom_bar_fraction(Image.open(os.path.join(folder, n + ".png")).convert("RGBA"))
            got = f >= GROUND_AT
            bad += 0 if got == want else 1
            print("  %-16s %4.0f%%  %-6s  %s" % (n, f * 100, "GROUND" if got else "paws",
                                                 "ok" if got == want else "WRONG"))
    return bad


if __name__ == "__main__":
    folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pics_fit")
    print("FIXTURE — three known dirty, three known clean")
    bad = fixture(folder)
    print("  -> %s\n" % ("separates all six" if bad == 0 else "WRONG on %d of 6" % bad))

    print("THE GREY ROUND")
    for n in sys.argv[1:]:
        f = bottom_bar_fraction(Image.open(os.path.join(folder, n + ".png")).convert("RGBA"))
        print("  %-16s %4.0f%%  %s" % (n, f * 100, "GROUND — toss" if f >= GROUND_AT else "clean"))
