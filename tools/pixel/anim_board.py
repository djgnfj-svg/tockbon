"""Lays every animation candidate on one board — **the thing the choice is actually made from.**

    python tools/pixel/anim_board.py walk2 --title "WOLF WALK" --out _review_wolf_walk2.png

`sheet.py` compares still candidates side by side; this is its animation twin. One row is one candidate:
its frames left to right, and **its onion-skin overlay on the right**.

⚠ **The onion column is the reason this is not just `sheet.py`.** A still frame cannot show whether the
beast jumps between frames, and that is the failure that makes an animation read as a glitch rather than
as motion. Two heads in the onion means the set is unusable however good each frame looks alone.

Rows come from `tools/pixel/out/anim_<prefix>_*/`, which is what `split_row.py` writes.
"""

import argparse
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).parent / "out"
STAGE = (0x0E, 0x0E, 0x13)  # the stage's empty-cell colour: judging on white judges a different picture
PAPER = (0xF2, 0xEF, 0xE6)


def main():
    p = argparse.ArgumentParser(description="애니메이션 후보들을 판 한 장으로")
    p.add_argument("prefix", help="anim_<prefix>_* 폴더들을 모은다. 쉼표로 여러 묶음을 한 판에 올린다")
    p.add_argument("--title", default="")
    p.add_argument("--out", default="")
    p.add_argument("--zoom", type=int, default=5)
    a = p.parse_args()

    # Several prompt attempts at one animation belong on **one** board: the choice is between all the
    #  candidates, not between the batches, and a batch boundary is an accident of how they were made.
    dirs = []
    for prefix in a.prefix.split(","):
        dirs += [x for x in OUT.glob(f"anim_{prefix.strip()}_*") if x.is_dir()]

    rows = []
    for d in sorted(set(dirs)):
        fs = sorted(d.glob("f*.png"), key=lambda q: int(re.sub(r"\D", "", q.stem) or 0))
        onion = d / "_onion.png"
        if fs and onion.exists():
            rows.append((d.name[5:], [Image.open(f).convert("RGBA") for f in fs],
                         Image.open(onion).convert("RGB")))
    if not rows:
        print(f"anim_{a.prefix}_* 폴더가 없다")
        return 1

    z, gap, lab, head = a.zoom, 10, 16, 34
    cw = max(max(f.width for f in ims) for _, ims, _ in rows) * z
    ch = max(max(f.height for f in ims) for _, ims, _ in rows) * z
    ncol = max(len(ims) for _, ims, _ in rows)

    sheet = Image.new("RGB", (gap + (ncol + 1) * (cw + gap) + gap,
                              head + len(rows) * (ch + gap + lab) + gap), PAPER)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 8), a.title or f"anim_{a.prefix}", fill=(30, 30, 40))

    for r, (name, ims, onion) in enumerate(rows):
        y = head + r * (ch + gap + lab)
        for c, f in enumerate(ims + [onion]):
            x = gap + c * (cw + gap)
            d.rectangle([x, y, x + cw - 1, y + ch - 1], fill=STAGE)
            if isinstance(f, Image.Image) and f.mode == "RGBA":
                # NEAREST: a blurred edge shows antialiasing the real screen will not have.
                big = f.resize((f.width * z, f.height * z), Image.NEAREST)
                sheet.paste(big, (x + (cw - big.width) // 2, y + ch - big.height), big)
            else:
                s = min(cw / f.width, ch / f.height)
                big = f.resize((max(1, int(f.width * s)), max(1, int(f.height * s))), Image.NEAREST)
                sheet.paste(big, (x + (cw - big.width) // 2, y + ch - big.height))
        d.text((gap, y + ch + 3), name, fill=(70, 70, 80))
        d.text((gap + ncol * (cw + gap) + 2, y + ch + 3), "onion — 두 마리로 보이면 버린다",
               fill=(70, 70, 80))

    dst = OUT / (a.out or f"_review_{a.prefix}.png")
    sheet.save(dst)
    print(f"{len(rows)}줄 -> {dst}  {sheet.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
