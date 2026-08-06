"""탄 머리만 잘라낸다 — 32×16 (머리+꼬리) → 16×16 (머리만).

    python crop_head.py out/fire_head/fire_head_08_seed1407674110_32px.png --out assets/spell/bolt_fire.png

🔴🔴 **꼬리를 버리는 것이 이 도구의 전부다.** 꼬리는 코드가 그린다(`spell_view._draw_trail`) —
 근거는 `docs/design/진-룬-문양.md` 의 「탄 머리 그림」이고 요점은 속도다:
 탄이 1600px/s 라 **한 프레임에 26.7px** 을 간다. 그림 꼬리(16px)는 그보다 짧아서
 **움직이는 동안 자취에 통째로 묻힌다.** 정지 화면에서만 보인다.

🔴🔴 **코어를 칸 한가운데에 앉히는 것이 나머지 전부다.**
 `spell_view._draw_head` 가 `head_px()` 를 **중심**으로 그리므로, 코어가 칸 중심에서 벗어나면
 **탄이 실제 위치와 어긋난 자리에 그려진다** — 그리고 그건 에러가 아니라 「좀 안 맞는다」로만 보인다.
 ⚠ 그래서 눈으로 자르지 않고 **밝기 무게중심**으로 잡는다.

⚠ **알파를 안 뺀다.** `spell_view` 가 가산 합성이라(`BLEND_MODE_ADD`) 검은 픽셀은 더해도 0이다 —
 **검은 배경이 그대로 투명 노릇을 한다.** 알파를 만들면 오히려 임포트 설정이 하나 늘어난다.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

SIZE = 16  ## 최종 한 변(px). `fx_tuning.FX_SIZES.bolt_px` 세대0 = 반경 8 ⇒ 지름 16


def core_center(img, search_from_x):
    """밝기의 제곱을 가중치로 한 무게중심. 🔴 **제곱인 것이 요점이다** —
    선형 가중이면 어둡고 넓은 꼬리가 표를 이겨서 중심이 왼쪽으로 끌려간다(실측으로 확인했다)."""
    px = img.load()
    sw = sx = sy = 0.0
    for y in range(img.height):
        for x in range(search_from_x, img.width):
            r, g, b = px[x, y]
            w = float(r + g + b) ** 2
            sw += w
            sx += w * (x + 0.5)
            sy += w * (y + 0.5)
    if sw <= 0.0:
        return None
    return sx / sw, sy / sw


def main():
    p = argparse.ArgumentParser(description="탄 머리만 16×16 으로 자른다")
    p.add_argument("src")
    p.add_argument("--out", required=True)
    p.add_argument("--size", type=int, default=SIZE)
    # ⚠ 코어가 오른쪽에 있다는 전제가 프리셋 `bolt` 의 계약이다(오른쪽으로 나는 그림).
    #  무게중심을 그림 전체에서 재면 꼬리가 끌어당기므로 **오른쪽 절반만** 본다.
    p.add_argument("--from-frac", type=float, default=0.5, help="무게중심을 재기 시작할 가로 위치")
    args = p.parse_args()

    src = Path(args.src)
    img = Image.open(src).convert("RGB")

    c = core_center(img, int(img.width * args.from_frac))
    if c is None:
        print(f"불투명 픽셀이 하나도 없다: {src}")
        return 1
    cx, cy = c

    half = args.size / 2.0
    # 🔴 반올림해서 **정수 경계**로 자른다. 소수로 자르면 PIL 이 보간해 픽셀이 흐려지고,
    #  그건 픽셀아트가 아니다.
    x0 = int(round(cx - half))
    y0 = int(round(cy - half))

    out = Image.new("RGB", (args.size, args.size), (0, 0, 0))
    # ⚠ 원본 밖으로 나가는 만큼은 검정으로 남는다 — 가산 합성에서 그건 「없는 것」이다.
    out.paste(img.crop((x0, y0, x0 + args.size, y0 + args.size)), (0, 0))

    dst = Path(args.out)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"{src.name}  코어 ({cx:.1f}, {cy:.1f}) -> 자른 자리 ({x0}, {y0})  =>  {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
