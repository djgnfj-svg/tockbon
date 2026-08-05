"""후보를 한 장에 붙여 눈으로 고르게 한다.

    python sheet.py out/glyph_spread --cols 4 --zoom 3

🔴🔴 **이 도구가 있는 이유는 「그림은 말로 안 갈린다」다.** 후보를 하나씩 열어 보면
 서로 비교가 안 되고, 비교가 안 되면 「이게 나은가」를 판정할 수가 없다.
⚠ 배경색이 판정을 바꾼다 — 흰 종이 위에서 볼 그림을 검은 배경에서 고르면 그 판정은 거짓이다.
 ⇒ `--bg` 기본이 **조립창 종이색**인 것이 그 이유고, 어두운 무대 위에 얹을 것만 `--bg 0E0E13` 으로 본다.
"""

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
SHEET_NAME = "_sheet.png"  ## 이 도구의 산출물 이름. 🔴 아래 필터가 이 값 하나로 자기를 뺀다


def hexcolor(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def main():
    p = argparse.ArgumentParser(description="후보 png 들을 격자 한 장으로")
    p.add_argument("folder", help="png 가 든 폴더 (또는 png 여러 개)")
    p.add_argument("--cols", type=int, default=4)
    p.add_argument("--zoom", type=int, default=3, help="Nearest 정수 확대")
    p.add_argument("--bg", default="F2EFE6", help="시트 바탕 (기본: 조립창 종이색)")
    p.add_argument("--cell", default="FFFFFF", help="칸 바탕")
    p.add_argument("--out", default="", help="저장 경로 (기본: <folder>/_sheet.png)")
    p.add_argument("--glob", default="*.png")
    args = p.parse_args()

    src = Path(args.folder)
    if src.is_dir():
        # ⚠ 자기가 만든 시트만 뺀다. 다시 붙이면 시트의 시트가 된다.
        #  🔴 **`_` 로 시작하는 것을 다 빼면 안 된다** — 이름이 `_smoke` 인 폴더의 파일이
        #   통째로 사라져 「png 가 없다」가 났다(실측). 라벨보다 넓은 필터의 실물이다.
        files = sorted(f for f in src.glob(args.glob) if f.name != SHEET_NAME)
    else:
        files = [Path(args.folder)]
    if not files:
        print(f"png 가 없다: {src}")
        return 1

    tiles = [Image.open(f).convert("RGBA") for f in files]
    tw = max(t.width for t in tiles)
    th = max(t.height for t in tiles)
    cw, ch = tw * args.zoom, th * args.zoom

    pad, labh = 12, 18
    cols = min(args.cols, len(tiles))
    rows = math.ceil(len(tiles) / cols)
    sheet = Image.new("RGB", (cols * (cw + pad) + pad, rows * (ch + pad + labh) + pad),
                      hexcolor(args.bg))
    d = ImageDraw.Draw(sheet)

    for i, (t, f) in enumerate(zip(tiles, files)):
        x = pad + (i % cols) * (cw + pad)
        y = pad + (i // cols) * (ch + pad + labh)
        d.rectangle([x, y, x + cw - 1, y + ch - 1], fill=hexcolor(args.cell))
        # 🔴 NEAREST 다. BILINEAR 로 늘리면 픽셀 경계가 흐려져 **없는 안티에일리어싱이 보인다** —
        #  그 상태로 고른 판정은 실제 화면과 다르다.
        big = t.resize((t.width * args.zoom, t.height * args.zoom), Image.NEAREST)
        sheet.paste(big, (x + (cw - big.width) // 2, y + (ch - big.height) // 2), big)
        d.text((x + 2, y + ch + 3), f"{i}: {f.stem[-14:]}", fill=(70, 70, 80))

    out = Path(args.out) if args.out else (src if src.is_dir() else src.parent) / SHEET_NAME
    sheet.save(out)
    print(f"{len(tiles)}장 -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
