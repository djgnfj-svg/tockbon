"""Puts every version's two shots on one sheet, so they are compared rather than remembered.

    python prototypes/pads/sheet.py

⚠ The lab writes `out/<name>_far.png` and `out/<name>_near.png`; this only lays them out.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SCALE = 0.5
PAD = 10
LABEL = 26

names = sorted(d for d in os.listdir(HERE)
               if os.path.isdir(os.path.join(HERE, d)) and d != "out" and d[0].isdigit())

cols = []
for n in names:
    row = []
    for which in ("far", "near"):
        p = os.path.join(OUT, "%s_%s.png" % (n, which))
        im = Image.open(p).convert("RGB")
        row.append(im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS))
    cols.append((n, row))

cw = cols[0][1][0].width
ch = cols[0][1][0].height
sheet = Image.new("RGB", (PAD + (cw + PAD) * len(cols), PAD + LABEL + (ch + PAD) * 2), (24, 24, 26))
d = ImageDraw.Draw(sheet)
for i, (n, row) in enumerate(cols):
    x = PAD + i * (cw + PAD)
    d.text((x + 4, PAD), n, fill=(235, 235, 235))
    for j, im in enumerate(row):
        sheet.paste(im, (x, PAD + LABEL + j * (ch + PAD)))
path = os.path.join(OUT, "sheet.png")
sheet.save(path)
print(path, sheet.size)
