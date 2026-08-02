#!/usr/bin/env python3
"""플레이어 스프라이트 시트를 굽는다 — idle 2 + run 8 + hurt 1 (8열 x 3행 · 프레임 32*배율).

    python tools/bake_player_sheet.py [배율]        # 기본 2

🔴 배율은 걸어보고 정하는 감각 축이다 — 다시 굽는 일이 한 줄이어야 실험을 할 수 있다.
⚠ idle·hurt는 relight가 적용된 보존본에서 가져온다 — 원본에서 다시 뽑으면 음영이 조용히
퇴행한다. run 8프레임만 penzilla 원본 row3에서 가져온다(기존 시트엔 없던 애니다).
🔴 player.tscn이 이 레이아웃을 읽는다 — 바꾸면 거기도 같이 고쳐라(수치는 아래 print가 찍는다).
🔴 발밑을 프레임 하단에서 `2 * 배율`px 위로 정렬한다 — 소스 둘의 그림 위치가 달라(48 vs 32 프레임)
그대로 붙이면 idle↔run 전환 때 캐릭터가 위아래로 튄다. bbox로 트림해 하단 정렬한다.
"""
import sys
from PIL import Image

SCALE = int(sys.argv[1]) if len(sys.argv) > 1 else 2

# 🔴 소스와 산출물을 반드시 가른다 — CUR을 OUT과 같은 경로로 두면 첫 실행이 입력을 파괴한다.
CUR = "assets/_source/player_hood_relit_48.png"                       # relight 적용본 (48px 프레임)
SRC = "assets/_source/penzilla_hooded/AnimationSheet_Character.png"   # penzilla 원본 (32px 프레임)
OUT = "assets/sprites/player/player_hood_sheet.png"

RUN_ROW = 3          # 원본 row3 = 뛰기 8프레임
COLS, ROWS = 8, 3


def trim(im: Image.Image):
    bb = im.getbbox()
    return im.crop(bb) if bb else None


def main() -> None:
    cur = Image.open(CUR).convert("RGBA")
    src = Image.open(SRC).convert("RGBA")

    # idle·hurt = 기존 시트(relight 적용본). 기존 레이아웃: 48px 프레임, row0 = 걷기(실은 idle), (96,96) = hurt
    idle = [trim(cur.crop((c * 48, 0, c * 48 + 48, 48))) for c in range(2)]
    hurt = trim(cur.crop((96, 96, 144, 144)))
    run = [trim(src.crop((c * 32, RUN_ROW * 32, c * 32 + 32, RUN_ROW * 32 + 32))) for c in range(8)]

    frames = [f for f in idle + run + [hurt] if f is None]
    if frames:
        raise SystemExit("빈 프레임이 있다 — 소스 좌표를 확인해라")

    f = 32 * SCALE                 # 프레임 한 칸
    foot_pad = 2 * SCALE           # 발밑과 프레임 하단 사이 여백
    sheet = Image.new("RGBA", (COLS * f, ROWS * f), (0, 0, 0, 0))

    def place(img: Image.Image, col: int, row: int) -> None:
        w, h = img.size
        big = img.resize((w * SCALE, h * SCALE), Image.NEAREST)
        x = col * f + (f - big.width) // 2                  # 가로 중앙
        y = row * f + f - foot_pad - big.height             # 발밑 정렬
        sheet.alpha_composite(big, (x, y))

    for i, img in enumerate(idle):
        place(img, i, 0)
    for i, img in enumerate(run):
        place(img, i, 1)
    place(hurt, 0, 2)

    sheet.save(OUT)

    # 🔴 player.tscn이 필요한 수치를 그대로 찍어 준다 (손으로 계산하다 어긋나는 자리)
    foot_y_in_frame = f - foot_pad
    sprite_offset_y = 10 - (foot_y_in_frame - f // 2)   # 발밑이 노드 +10에 오게 (Shadow.position.y와 일치)
    print("배율 %d → 프레임 %dx%d · 시트 %dx%d" % (SCALE, f, f, sheet.width, sheet.height))
    print("  캐릭터 실측: idle %dx%d → %dx%d" % (idle[0].width, idle[0].height,
                                              idle[0].width * SCALE, idle[0].height * SCALE))
    print("  player.tscn 넣을 값: Sprite.offset = Vector2(0, %d)" % sprite_offset_y)
    print("  AtlasTexture region: idle=(col*%d, 0) · run=(col*%d, %d) · hurt=(0, %d) 크기 %dx%d"
          % (f, f, f, f * 2, f, f))
    print("  Shadow.radius_px 권장 = %d (그림 폭의 절반 + 2)" % (idle[0].width * SCALE // 2 + 2))


if __name__ == "__main__":
    main()
