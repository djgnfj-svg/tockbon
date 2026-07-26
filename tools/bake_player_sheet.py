#!/usr/bin/env python3
"""플레이어 스프라이트 시트를 굽는다 (세90).

    python tools/bake_player_sheet.py [배율]        # 기본 2

🔴 **왜 스크립트인가**: 캐릭터 크기는 사용자가 걸어보고 정하는 감각 축이다. 배율을 바꿔 다시
굽는 일이 한 줄이어야 실험을 할 수 있다(손으로 시트를 재조립하면 배율마다 몇십 분이 든다).

## 소스가 둘인 이유 (실측 · 세90)

- **idle 2프레임 + hurt 1프레임 = 기존 시트**(`player_hood_sheet.png`)에서 가져온다.
  세69 relight(`tools/relight_sprites.lua`)가 **이미 적용된** 그림이라, 원본에서 다시 뽑으면
  음영이 조용히 퇴행한다(그 memory의 함정: *"익스포트 후처리라 재익스포트하면 음영이 사라진다"*).
- **run 8프레임 = penzilla 원본**(`assets/_source/penzilla_hooded/AnimationSheet_Character.png` row3).
  기존 시트에 **애초에 없던 애니**다 — 세76은 원본 row0(idle) 2장을 걷기 칸에 넣어 썼고,
  그래서 **걸어도 idle 두 장이 번갈아 나와 뻣뻣했다**(사용자가 지적한 그것).
  ⚠ 이 8장엔 **relight가 안 걸려 있다** — 다음에 `takbon-relight`로 한 번에 맞출 자리다.

## 원본 시트 판독 (32px 그리드 · 9행)

    row0 idle(2) · row1 blink(2) · row2 walk(4) · **row3 run(8)** · row4 dash/구르기(6)
    row5 jump?(8) · row6 vanish(4) · row7 death(8) · **row8 attack(8 — 흰 마법 궤적)**
    → row8은 「마법 쏠 때 자세」로 쓸 값이 크다(이 게임이 마법을 쏜다). 아직 안 썼다.

## 출력 계약 (player.tscn이 이 레이아웃을 읽는다 — 바꾸면 거기도 같이 고쳐라)

프레임 = `32 * 배율` 정사각. 8열 × 3행:

    row0: idle  2프레임 (col 0~1)
    row1: run   8프레임 (col 0~7)
    row2: hurt  1프레임 (col 0)

🔴 **발밑을 프레임 하단에서 `2 * 배율`px 위로 정렬한다** — 소스 둘의 그림 위치가 달라(48 프레임 vs
32 프레임) 그대로 붙이면 idle↔run 전환 때 캐릭터가 **위아래로 튄다**. bbox로 트림해 하단 정렬한다.
그 값이 `player.tscn`의 `Sprite.offset`·`Shadow.position` 계산 근거다(아래 print가 찍어 준다).
"""
import sys
from PIL import Image

SCALE = int(sys.argv[1]) if len(sys.argv) > 1 else 2

# 🔴🔴 **소스와 산출물을 반드시 가른다.** 처음엔 CUR을 산출물과 같은 경로로 뒀는데, 그러면
#   한 번 실행하는 순간 **입력이 파괴되고**(레이아웃이 바뀌므로) 재실행이 쓰레기를 굽는다.
#   `_source/player_hood_relit_48.png` = 세69 relight가 적용된 옛 48px 시트의 **보존본**이다.
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
    # run = 원본 row3
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
