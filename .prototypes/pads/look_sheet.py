"""Lays the six tones x two gutters on one sheet.

    python .prototypes/pads/look_sheet.py
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TONES = ["light3", "light2", "light1", "dark1", "dark2", "dark3"]
ROWS = [("narrow", "near"), ("wide", "near"), ("narrow", "far"), ("wide", "far")]
SCALE = 0.42
PAD = 8
HEAD = 22

ims = {}
for tag, which in ROWS:
    for t in TONES:
        p = os.path.join(OUT, "look_%s_%s_%s.png" % (tag, t, which))
        im = Image.open(p).convert("RGB")
        ims[(tag, which, t)] = im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS)

cw = ims[(ROWS[0][0], ROWS[0][1], TONES[0])].width
ch = ims[(ROWS[0][0], ROWS[0][1], TONES[0])].height
sheet = Image.new("RGB", (PAD + (cw + PAD) * len(TONES),
                          HEAD + (ch + HEAD) * len(ROWS)), (24, 24, 26))
d = ImageDraw.Draw(sheet)
for r, (tag, which) in enumerate(ROWS):
    y = HEAD + r * (ch + HEAD)
    for c, t in enumerate(TONES):
        x = PAD + c * (cw + PAD)
        d.text((x + 3, y - HEAD + 5), "%s  %s  %s" % (t, tag, which), fill=(230, 230, 230))
        sheet.paste(ims[(tag, which, t)], (x, y))
path = os.path.join(OUT, "look_sheet.png")
sheet.save(path)
print(path, sheet.size)
