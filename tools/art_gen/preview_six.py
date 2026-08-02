#!/usr/bin/env python3
"""여섯 장을 **한 장에 나란히** 놓고 결이 맞나 본다.

🔴 합격선 = 음영 두께·외곽선·채도가 한 결로 읽히나 — 낱장으로는 안 보이고 여섯이 같은 바닥
   위에 서야 드러난다. 바닥은 실제 `tileset_ground.png` GRASS_PLAIN + `Daylight(1, 0.99, 0.96)`.
   접지선을 한 줄로 맞춰 세운다(그래야 「같은 땅에 서 있나」가 보인다).
   플레이어(화면 키 56px)를 자로 같이 세운다.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIELD = os.path.join(ROOT, "assets", "sprites", "field")
DAYLIGHT = (1.0, 0.99, 0.96)

# (파일, 접지선 row) — 접지선 = 그림이 땅에 닿는 행
ITEMS = [
    ("tree_round", 122), ("tree_pine", 122), ("tree_dead", 122),
    ("rock_big", 56), ("bush", 41), ("rock", 19),
]

OUT = sys.argv[1] if len(sys.argv) > 1 else "six.png"
SCALE = int(sys.argv[2]) if len(sys.argv) > 2 else 2


def main():
    sheet = Image.open(os.path.join(FIELD, "tileset_ground.png")).convert("RGBA")
    tile = sheet.crop((64, 256, 128, 320))
    imgs = [(n, g, Image.open(os.path.join(FIELD, n + ".png")).convert("RGBA")) for n, g in ITEMS]

    gap = 12
    W = sum(im.width for _, _, im in imgs) + gap * (len(imgs) + 1) + 80
    H = 176
    base = 150
    bg = Image.new("RGBA", (W, H))
    for ty in range(0, H + 64, 64):
        for tx in range(0, W + 64, 64):
            bg.paste(tile, (tx, ty))

    x = gap
    for _, gl, im in imgs:
        bg.alpha_composite(im, (x, base - gl))
        x += im.width + gap

    pl = Image.open(os.path.join(ROOT, "assets", "sprites", "player",
                                 "player_hood_sheet.png")).convert("RGBA").crop((0, 0, 64, 64))
    bg.alpha_composite(pl, (x, base - 58))

    px = bg.load()
    for y in range(H):
        for xx in range(W):
            r, g, b, a = px[xx, y]
            px[xx, y] = (min(255, int(r * DAYLIGHT[0])), min(255, int(g * DAYLIGHT[1])),
                         min(255, int(b * DAYLIGHT[2])), a)
    bg.resize((W * SCALE, H * SCALE), Image.NEAREST).convert("RGB").save(OUT)
    print("wrote", OUT, (W * SCALE, H * SCALE))


if __name__ == "__main__":
    main()
