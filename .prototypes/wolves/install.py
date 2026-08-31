# -*- coding: utf-8 -*-
"""Put the chosen wolf into the game, mapping the rotation's compass words onto SCREEN directions.

⚠⚠ **THE TWO SETS OF COMPASS WORDS DO NOT LINE UP AND THE FILE NAMES ARE THE GAME'S.** `wolf_h/`'s
east/west/south/north mean screen-right, screen-left, coming-at-the-camera and going-away — that is
what `_facing_index` resolves against the camera's own ground axes. The generator's words are its own,
and the pictures were LOOKED AT to find which is which:

    generator "south"       right profile          -> east.png   (screen-right)
    generator "west"        left profile           -> west.png   (screen-left)
    generator "south-west"  head on, facing out    -> south.png  (coming at the camera)
    generator "north-east"  rear, tail to camera   -> north.png  (going away)

⚠ Taking the generator's east/north on their names would have put two rear views on the board.
"""
import io, os, requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "..", "..", "assets", "beast", "wolf_h")
BASE = ("https://backblaze.pixellab.ai/file/pixellab-characters/"
        "7c04dcee-4865-4cd5-8de8-994829722e50/35a190ca-ef0a-4894-bf46-ea5820777ec1/"
        "rotations/%s.png?t=1788154752")

MAP = {"east": "south", "west": "west", "south": "south-west", "north": "north-east"}

for game_name, gen_name in MAP.items():
    r = requests.get(BASE % gen_name, timeout=90)
    r.raise_for_status()
    im = Image.open(io.BytesIO(r.content)).convert("RGBA")
    p = os.path.join(DST, game_name + ".png")
    im.save(p)
    bb = im.getbbox()
    print("%-6s <- %-11s  canvas %dx%d  ink %dx%d"
          % (game_name, gen_name, im.width, im.height, bb[2] - bb[0], bb[3] - bb[1]))

# the normal maps belonged to the wolf that just left, and nothing has ever read them
for n in ("east_n", "west_n", "south_n", "north_n"):
    for ext in (".png", ".png.import"):
        p = os.path.join(DST, n + ext)
        if os.path.exists(p):
            os.remove(p)
            print("removed", n + ext)
