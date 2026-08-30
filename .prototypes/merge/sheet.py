"""Four mechanisms across three distances, on one sheet.

    python .prototypes/merge/sheet.py
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DIST = ["near", "mid", "far"]
SCALE = 0.46
PAD = 8
HEAD = 22

names = sorted(d for d in os.listdir(HERE)
               if os.path.isdir(os.path.join(HERE, d)) and d[0].isdigit())
ims = {}
for n in names:
    for w in DIST:
        im = Image.open(os.path.join(OUT, "%s_%s.png" % (n, w))).convert("RGB")
        ims[(n, w)] = im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS)

cw = ims[(names[0], DIST[0])].width
ch = ims[(names[0], DIST[0])].height
sheet = Image.new("RGB", (PAD + (cw + PAD) * len(names), HEAD + (ch + HEAD) * len(DIST)), (24, 24, 26))
d = ImageDraw.Draw(sheet)
for r, w in enumerate(DIST):
    y = HEAD + r * (ch + HEAD)
    for c, n in enumerate(names):
        x = PAD + c * (cw + PAD)
        d.text((x + 3, y - HEAD + 5), "%s  —  %s" % (n, w), fill=(230, 230, 230))
        sheet.paste(ims[(n, w)], (x, y))
path = os.path.join(OUT, "sheet.png")
sheet.save(path)
print(path, sheet.size)
