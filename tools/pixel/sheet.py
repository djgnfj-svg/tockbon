"""Pastes candidates onto one sheet so they can be chosen by eye.

    python sheet.py out/glyph_spread --cols 4 --zoom 3

**This tool exists because "art cannot be settled in words".** Opening candidates one at a time
 gives nothing to compare against, and without comparison "is this one better" cannot be judged.
The background color changes the judgment — choosing art meant for white paper against a black background makes that judgment false.
 => That is why the `--bg` default is **the assembly window's paper color**, and only things that go on the dark stage are viewed with `--bg 0E0E13`.
"""

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
SHEET_NAME = "_sheet.png"  ## This tool's output name. The filter below excludes itself by this one value


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
        # Only the sheet it made itself is excluded. Paste it again and you get a sheet of a sheet.
        #  **Excluding everything starting with `_` is wrong** — the files in a folder named `_smoke`
        #   vanished wholesale and gave "there are no pngs" (measured). A filter wider than its label, in the flesh.
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
        # NEAREST. Scaling with BILINEAR blurs the pixel boundaries and **shows antialiasing that isn't there** —
        #  a judgment made in that state differs from the real screen.
        big = t.resize((t.width * args.zoom, t.height * args.zoom), Image.NEAREST)
        sheet.paste(big, (x + (cw - big.width) // 2, y + (ch - big.height) // 2), big)
        d.text((x + 2, y + ch + 3), f"{i}: {f.stem[-14:]}", fill=(70, 70, 80))

    out = Path(args.out) if args.out else (src if src.is_dir() else src.parent) / SHEET_NAME
    sheet.save(out)
    print(f"{len(tiles)}장 -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
