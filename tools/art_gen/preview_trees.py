#!/usr/bin/env python3
"""나무 3종 + 덤불을 **실제 낮 풀밭 위에** 나란히 놓고 본다 (세100 · takbon-art).

🔴 왜 이게 필요한가: 어두운/투명 배경에서 고르면 뭘 올려도 잘 보여 **도구가 거짓말한다.**
   이 방(boss_room)의 바닥은 tileset_ground.png의 GRASS_PLAIN(1,4) = 바탕 #468232이고
   CanvasModulate Daylight(1, 0.99, 0.96)를 먹는다. 여기까지 재현해서 본다.
   플레이어(56px)도 같이 세워 **비율**을 눈으로 검산한다.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIELD = os.path.join(ROOT, "assets", "sprites", "field")
SHEET = os.path.join(FIELD, "tileset_ground.png")
DAYLIGHT = (1.0, 0.99, 0.96)

SCALE = int(sys.argv[1]) if len(sys.argv) > 1 else 2
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.environ.get("TMP", "."), "trees_on_grass.png")


def grass_bg(w, h):
    sheet = Image.open(SHEET).convert("RGBA")
    tiles = [sheet.crop((tx * 64, 4 * 64, tx * 64 + 64, 5 * 64)) for tx in (1, 2, 3)]
    bg = Image.new("RGBA", (w, h))
    for ty in range(0, h, 64):
        for tx in range(0, w, 64):
            bg.paste(tiles[(tx // 64 + ty // 64 * 2) % 3], (tx, ty))
    return bg


def daylight(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * DAYLIGHT[0])),
                        min(255, int(g * DAYLIGHT[1])),
                        min(255, int(b * DAYLIGHT[2])), a)
    return im


def player():
    """플레이어 idle 첫 프레임(64x64 칸) — 🔴 비율 검산의 자다. 화면 키 56px."""
    p = os.path.join(ROOT, "assets", "sprites", "player", "player_hood_sheet.png")
    if not os.path.exists(p):
        return None
    return Image.open(p).convert("RGBA").crop((0, 0, 64, 64))


def main():
    names = ["tree_round", "tree_pine", "tree_dead", "bush"]
    imgs = {n: Image.open(os.path.join(FIELD, n + ".png")).convert("RGBA") for n in names}

    W, H = 640, 192
    bg = grass_bg(W, H)

    # 접지선을 한 줄에 맞춰 세운다 (나무 row 120 / 덤불 row 33)
    base_y = 150
    spots = [("tree_round", 70, 120), ("tree_pine", 190, 120), ("tree_dead", 300, 120),
             ("bush", 400, 33), ("bush", 440, 33), ("tree_round", 520, 120)]
    for name, cx, gline in spots:
        im = imgs[name]
        bg.alpha_composite(im, (cx - im.width // 2, base_y - gline))

    pl = player()
    if pl is not None:
        bg.alpha_composite(pl, (600 - pl.width // 2, base_y - 58))

    bg = daylight(bg)
    bg = bg.resize((W * SCALE, H * SCALE), Image.NEAREST)
    bg.convert("RGB").save(OUT)
    print("wrote", OUT, bg.size)


if __name__ == "__main__":
    main()
