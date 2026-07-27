#!/usr/bin/env python3
"""세99 밀도(화면당 3~4그루)로 **한 화면**을 채워 본다 (세100 · takbon-art).

🔴 왜 따로 있나: 나란히 세운 그림 셋으로는 「복붙으로 보이나」를 못 잰다.
   같은 PNG가 여러 번 반복되고 서로 겹칠 때 비로소 드러난다.
   화면은 뷰포트 960x540 그대로 · 바닥은 실제 타일 · Daylight까지 먹인다.
   `tree.gd`가 north(y<-500)에서 침엽·마른나무를, south에서 활엽·침엽을 고르므로 그 비율을 흉내낸다.
"""
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIELD = os.path.join(ROOT, "assets", "sprites", "field")
DAYLIGHT = (1.0, 0.99, 0.96)
GROUND_ROW = 122          # 나무 밑동 최하단 (세 변형 공통)
BUSH_ROW = 40

OUT = sys.argv[1] if len(sys.argv) > 1 else "forest.png"
SCALE = int(sys.argv[2]) if len(sys.argv) > 2 else 1
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 7


def main():
    sheet = Image.open(os.path.join(FIELD, "tileset_ground.png")).convert("RGBA")
    tiles = [sheet.crop((tx * 64, 256, tx * 64 + 64, 320)) for tx in (1, 2, 3)]
    W, H = 960, 540
    bg = Image.new("RGBA", (W, H))
    rnd = random.Random(SEED)
    for ty in range(0, H + 64, 64):
        for tx in range(0, W + 64, 64):
            bg.paste(tiles[0] if rnd.random() < 0.7 else tiles[rnd.randint(1, 2)], (tx, ty))

    # 접지선 = 그림이 땅에 닿는 행
    GROUND = {"tree_round": GROUND_ROW, "tree_pine": GROUND_ROW, "tree_dead": GROUND_ROW,
              "bush": BUSH_ROW, "rock_big": 56, "rock": 19}
    imgs = {n: Image.open(os.path.join(FIELD, n + ".png")).convert("RGBA") for n in GROUND}

    # y가 클수록 앞 = 나중에 그린다 (보스방엔 y-sort가 없지만 눈으로 재기엔 이 순서가 맞다)
    props = []
    for _ in range(9):
        props.append((rnd.choice(["tree_round", "tree_pine", "tree_round", "tree_pine", "tree_dead"]),
                      rnd.randint(40, W - 40), rnd.randint(150, H - 20)))
    for _ in range(7):
        props.append(("bush", rnd.randint(30, W - 30), rnd.randint(160, H - 10)))
    # 🔴 바닥 층위 — 세99까지 이게 통째로 비어 있어서 나무만 선 「기둥 밭」이었다.
    for _ in range(3):
        props.append(("rock_big", rnd.randint(50, W - 50), rnd.randint(170, H - 10)))
    for _ in range(6):
        props.append(("rock", rnd.randint(20, W - 20), rnd.randint(165, H - 5)))
    props.sort(key=lambda p: p[2])
    for name, cx, gy in props:
        im = imgs[name]
        bg.alpha_composite(im, (cx - im.width // 2, gy - GROUND[name]))

    px = bg.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * DAYLIGHT[0])), min(255, int(g * DAYLIGHT[1])),
                        min(255, int(b * DAYLIGHT[2])), a)
    if SCALE != 1:
        bg = bg.resize((W * SCALE, H * SCALE), Image.NEAREST)
    bg.convert("RGB").save(OUT)
    print("wrote", OUT, bg.size)


if __name__ == "__main__":
    main()
