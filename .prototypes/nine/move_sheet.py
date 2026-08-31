"""Lays the photographed walk on ONE sheet, in reading order, with the clock on each frame.

    python .prototypes/nine/move_sheet.py

A folder of `move_###.png` is not a picture of a move; a strip in time order is.
"""
import glob
import os
import re

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SHEET = os.path.join(OUT, "move-sheet.png")

PAD = 12
HEAD = 62
COLS = 4
FPS = 60.0
BG = (26, 28, 32)
INK = (238, 238, 238)
DIM = (150, 152, 158)
SCALE = 0.62


def _font(size):
    for path in (r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\malgunbd.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    shots = []
    for f in sorted(glob.glob(os.path.join(OUT, "move_*.png"))):
        m = re.match(r"move_(\d+)\.png$", os.path.basename(f))
        if m:
            shots.append((int(m.group(1)), f))
    shots.sort()
    if not shots:
        raise SystemExit("no move_*.png in %s — run the lab with `-- move` first" % OUT)

    w, h = Image.open(shots[0][1]).size
    w, h = int(w * SCALE), int(h * SCALE)
    rows = (len(shots) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * (w + PAD) + PAD, HEAD + rows * (h + PAD + 22) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    big, small = _font(20), _font(15)

    d.text((PAD, 10), "아홉이 한 블록으로 간다 — 명령부터 자리에 앉을 때까지", font=big, fill=INK)
    d.text((PAD, 36), "왼쪽 블록으로 한 번 명령. 걷는 동안은 제자리, 서면 3x3 자리로 미끄러진다.",
           font=small, fill=DIM)

    for i, (frame, path) in enumerate(shots):
        cx = PAD + (i % COLS) * (w + PAD)
        cy = HEAD + (i // COLS) * (h + PAD + 22)
        sheet.paste(Image.open(path).convert("RGB").resize((w, h), Image.LANCZOS), (cx, cy))
        d.text((cx, cy + h + 4), "%.2f 초" % (frame / FPS), font=small, fill=INK)

    sheet.save(SHEET)
    print("[sheet] %s  %dx%d" % (SHEET, sheet.width, sheet.height))


if __name__ == "__main__":
    main()
