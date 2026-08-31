# -*- coding: utf-8 -*-
"""Two sheets: one wolf alone on the map, and the boat beside the shore for the size check."""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

NAMES = ["installed"]

STAGE = (0x0E, 0x0E, 0x13, 255)
RULE = (0x2b, 0x2b, 0x39, 255)
LABEL = (0xe0, 0xa1, 0x3c, 255)
GAP = 14

SHEETS = {
    # one wolf, alone, in the middle of the glass
    "one": {"cols": [("one", (556, 280, 724, 420)), ("land", (556, 280, 724, 420)), ("boat", (0, 270, 150, 400))], "zoom": 5, "per_row": 1},
    # the deck against the shore, to see whether the two now read the same size
    "size": {"cols": [("boat", (0, 276, 150, 404)), ("land", (556, 288, 724, 416))],
             "zoom": 4, "per_row": 1},
    # the deck alone — does a body sized off the island still fit between the benches
    "boat": {"cols": [("boat", (0, 266, 140, 394))], "zoom": 5, "per_row": 3},
}


def build(key, out_path):
    spec = SHEETS[key]
    cols, zoom, per_row = spec["cols"], spec["zoom"], spec["per_row"]

    tiles = []
    for n in NAMES:
        strip = []
        for shot, b in cols:
            im = Image.open(os.path.join(OUT, "%s_%s.png" % (shot, n))).convert("RGBA")
            strip.append(im.crop(b).resize(((b[2] - b[0]) * zoom, (b[3] - b[1]) * zoom), Image.NEAREST))
        w = sum(s.width for s in strip) + GAP * (len(strip) - 1)
        h = max(s.height for s in strip)
        tile = Image.new("RGBA", (w, h), STAGE)
        x = 0
        for s in strip:
            tile.alpha_composite(s, (x, 0))
            x += s.width + GAP
        tiles.append((n, tile))

    tw = max(t.width for _, t in tiles)
    th = max(t.height for _, t in tiles)
    rows = (len(tiles) + per_row - 1) // per_row
    board = Image.new("RGBA", (per_row * (tw + GAP) + GAP, rows * (th + GAP) + GAP), STAGE)
    d = ImageDraw.Draw(board)

    for i, (n, t) in enumerate(tiles):
        x = GAP + (i % per_row) * (tw + GAP)
        y = GAP + (i // per_row) * (th + GAP)
        board.alpha_composite(t, (x, y))
        d.rectangle([x, y, x + tw - 1, y + th - 1], outline=RULE)
        d.text((x + 6, y + 5), n, fill=LABEL)

    board.save(out_path)
    print("wrote", out_path, board.size)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
