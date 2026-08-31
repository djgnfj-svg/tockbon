# -*- coding: utf-8 -*-
"""Put every candidate on the SAME canvas the shipped wolf uses, at the same ink size.

⚠ The game sizes a body by the WIDTH OF ITS FRAME, not by the animal inside it, and the shipped
wolf's frame is 92 px with the animal filling about three quarters of it. A 64 px candidate whose
animal fills the whole canvas therefore draws roughly a third bigger than the wolf it is being
compared against — which is a difference in a NUMBER, not in the art, and it would decide the
round if it were left in the picture.

So: scale each candidate until its ink is exactly as wide as the shipped wolf's ink, and paste it
at the shipped wolf's own ink position on a 92 x 92 canvas. Feet land where the game expects feet.
"""
import os, glob
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "..", "assets", "beast", "wolf_h", "east.png")
SRC = os.path.join(HERE, "pics")
DST = os.path.join(HERE, "pics_fit")

os.makedirs(DST, exist_ok=True)

ref = Image.open(REF).convert("RGBA")
rb = ref.getbbox()
ref_w, ref_h = rb[2] - rb[0], rb[3] - rb[1]
print("shipped wolf: canvas %dx%d, ink %dx%d at (%d,%d)" % (ref.width, ref.height, ref_w, ref_h, rb[0], rb[1]))

for p in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    im = Image.open(p).convert("RGBA")
    bb = im.getbbox()
    ink = im.crop(bb)
    k = ref_w / ink.width
    w = max(1, round(ink.width * k))
    h = max(1, round(ink.height * k))
    ink = ink.resize((w, h), Image.LANCZOS)

    out = Image.new("RGBA", (ref.width, ref.height), (0, 0, 0, 0))
    # left edge and BOTTOM of the ink both land where the shipped wolf's do — the bottom, because
    # the game measures a body's feet off the lowest opaque row.
    out.alpha_composite(ink, (rb[0], rb[3] - h))
    name = os.path.basename(p)
    out.save(os.path.join(DST, name))
    print("%-10s ink %dx%d -> %dx%d" % (name, bb[2] - bb[0], bb[3] - bb[1], w, h))
