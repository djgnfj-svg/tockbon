"""Lays every shot in out/ on ONE sheet — five arrangements across, two body sizes down.

    python .prototypes/nine/sheet.py

The user reads a sheet, not a folder of shots. A round that ends at out/ has not ended.
"""
import glob
import os
import re

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SHEET = os.path.join(OUT, "sheet.png")

PAD = 14
HEAD = 74
COL_LABEL = 110
BG = (26, 28, 32)
INK = (238, 238, 238)
DIM = (150, 152, 158)

# ⚠ **A SECOND COPY OF EACH VERSION'S NAME, AND IT IS SAID OUT LOUD.** The name every version really
# owns is `scene.gd`'s `title()`, and Python cannot call GDScript. **Keep this short** — the long
# statement of what a version buys and cannot do lives in its own `NOTES.md`, which is the one place.
WHAT = {
    "01-now": "조각이 자리를 갖는다 (지금 것)",
    "02-grid": "블록 3x3 격자 — 안 돈다",
    "03-ranks": "보는 쪽 3열 — 앞뒤가 좁다",
    "04-stagger": "줄마다 엇갈린 벌집",
    "05-spiral": "해바라기 나선",
    "06-ranks-wide": "보는 쪽 3열 — 앞뒤도 어깨만큼",
}

# The rows of the sheet, in order. ⚠ **These are the lab's `FACE_NAMES`** — a name that is not in this
# list is not laid out at all, which is what keeps a stale shot out of the sheet.
ROWS = ["south", "east"]
ROW_LABEL = {"south": "남쪽을 본다", "east": "동쪽을 본다"}


def _font(size):
    # A Korean-capable face, because every arrangement's name is Korean. Falls back to the default
    # bitmap font rather than dying — an unlabelled sheet is still a sheet.
    for path in (r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\malgunbd.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    shots = {}
    for f in sorted(glob.glob(os.path.join(OUT, "*_*.png"))):
        m = re.match(r"(.+)_(%s)\.png$" % "|".join(ROWS), os.path.basename(f))
        if m:
            shots.setdefault(m.group(1), {})[m.group(2)] = f
    if not shots:
        raise SystemExit("no shots in %s — run the lab with `-- shoot` first" % OUT)

    names = sorted(shots)
    sizes = [r for r in ROWS if any(r in v for v in shots.values())]
    w, h = Image.open(shots[names[0]][sizes[0]]).size

    sheet_w = COL_LABEL + len(names) * (w + PAD) + PAD
    sheet_h = HEAD + len(sizes) * (h + PAD) + PAD
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    d = ImageDraw.Draw(sheet)
    big, small = _font(20), _font(16)

    d.text((PAD, 11), "한 블록(칸)에 아홉 — 「돈다」가 무엇인가 (같은 아홉, 보는 쪽만 바꿈)",
           font=big, fill=INK)

    for ci, name in enumerate(names):
        x = COL_LABEL + ci * (w + PAD) + PAD
        # The user calls these by number — "2 or 3", "let's go with 6" — so the number leads.
        d.text((x, 47), "%d번  %s" % (ci + 1, WHAT.get(name, name)), font=small, fill=INK)
        for ri, size in enumerate(sizes):
            y = HEAD + ri * (h + PAD) + PAD
            sheet.paste(Image.open(shots[name][size]).convert("RGB"), (x, y))

    for ri, size in enumerate(sizes):
        y = HEAD + ri * (h + PAD) + PAD
        d.text((PAD, y + h // 2 - 10), ROW_LABEL.get(size, size), font=small, fill=INK)

    sheet.save(SHEET)
    print("[sheet] %s  %dx%d" % (SHEET, sheet_w, sheet_h))


if __name__ == "__main__":
    main()
