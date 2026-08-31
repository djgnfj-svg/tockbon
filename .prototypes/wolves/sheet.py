# -*- coding: utf-8 -*-
"""Crop the boat and the shore out of the shots and lay them on one sheet.

Both columns are one instant from one camera, so the crop boxes are fixed: the same rectangle of the
same sea and the same slope in every row, and the wolf is the only thing that changes down a column.
"""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

NAMES = ["now", "b01_black_line", "b02_selective", "b03_lineless", "b04_pale_chest",
         "b05_brown", "b06_medium", "b07_black", "b08_ruff"]
# (which shot, crop box) — the boat is pinned to the left edge because the camera's roam ring stops
# the pan before the boat reaches the middle.
COLS = [("boat", (0, 280, 140, 400)), ("land", (548, 288, 732, 416))]
ZOOM = 4
GAP = 14
STAGE = (0x0E, 0x0E, 0x13, 255)
RULE = (0x2b, 0x2b, 0x39, 255)
LABEL = (0xe0, 0xa1, 0x3c, 255)


def build(out_path):
    cells = []
    for n in NAMES:
        row = []
        for shot, b in COLS:
            im = Image.open(os.path.join(OUT, "%s_%s.png" % (shot, n))).convert("RGBA")
            row.append(im.crop(b).resize(((b[2] - b[0]) * ZOOM, (b[3] - b[1]) * ZOOM), Image.NEAREST))
        cells.append(row)

    cw = [max(c[i].width for c in cells) for i in range(len(COLS))]
    ch = max(c[i].height for c in cells for i in range(len(COLS)))
    board = Image.new("RGBA",
                      (sum(cw) + GAP * (len(COLS) + 1), len(NAMES) * (ch + GAP) + GAP), STAGE)
    d = ImageDraw.Draw(board)

    for r, n in enumerate(NAMES):
        y = GAP + r * (ch + GAP)
        x = GAP
        for i in range(len(COLS)):
            board.alpha_composite(cells[r][i], (x, y))
            d.rectangle([x, y, x + cw[i] - 1, y + ch - 1], outline=RULE)
            x += cw[i] + GAP
        d.text((GAP + 6, y + 5), n, fill=LABEL)

    board.save(out_path)
    print("wrote", out_path, board.size)


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "_sheet.png"))
