# -*- coding: utf-8 -*-
"""Pull the 64 px round down, and build the control that goes beside it.

⚠ The frame is now 64 px on screen, so a 64 px candidate is drawn one texture pixel to one screen
pixel — nothing is thrown away. The wolf standing in the game today is 92 px and was drawn at a
41.9 px frame, so to keep the CONTROL honest it is padded onto a 141 px canvas: 66 / 141 of a 64 px
frame is the same 30 px of animal it draws in the shipped game.
"""
import os, requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")
REF = os.path.join(HERE, "..", "..", "assets", "beast", "wolf_h", "east.png")
URL = "https://api.pixellab.ai/mcp/images/%s/download"

JOBS = {
    "b01_black_line": "456e97b2-e96a-474d-b3fc-d42dadabe0bc",
    "b02_selective": "d469a3d2-2c9b-45c1-b3ea-d4a490154295",
    "b03_lineless": "aea41ded-9a2d-454f-91e7-c4cb08170ce9",
    "b04_pale_chest": "db0e6e69-5f57-4d6d-81a6-b2cf52ce17ab",
    "b05_brown": "e62d9ea2-6cf0-4c37-a24f-effe484abbae",
    "b06_medium": "c55000a9-51e6-4119-b43e-522c610963bc",
    "b07_black": "a0f4e4ea-481a-4eee-bdc5-eb79b4b54afe",
    "b08_ruff": "0876f013-7e0e-440c-b5e5-f557fd5968cf",
}

os.makedirs(DST, exist_ok=True)

for name, job in JOBS.items():
    r = requests.get(URL % job, timeout=90)
    r.raise_for_status()
    p = os.path.join(DST, name + ".png")
    with open(p, "wb") as f:
        f.write(r.content)
    im = Image.open(p).convert("RGBA")
    bb = im.getbbox()
    print("%-16s canvas %dx%d  ink %dx%d" % (name, im.width, im.height, bb[2] - bb[0], bb[3] - bb[1]))

# the control, kept at the size it actually ships at
ref = Image.open(REF).convert("RGBA")
pad = Image.new("RGBA", (141, 141), (0, 0, 0, 0))
pad.alpha_composite(ref, ((141 - ref.width) // 2, 141 - ref.height))
pad.save(os.path.join(DST, "now.png"))
b = pad.getbbox()
print("%-16s canvas 141x141  ink %dx%d  -> draws %.1f px" % ("now", b[2] - b[0], b[3] - b[1],
                                                             64.0 * (b[2] - b[0]) / 141.0))
