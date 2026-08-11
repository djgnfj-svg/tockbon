"""Labels the magic-circle diagram that `plan.md` prints.

    python tools/submission/diagram.py

`circle-diagram-base.png` is AI generated and carries **no text** — image models write
Korean as decoration-shaped garbage, and a judged document cannot ship a label that is not
a word. So the picture is generated bare and the three names are drawn here, in the same
Noto Sans KR the game bundles.

**The artwork is re-mounted on a wider canvas first.** Labels drawn onto the square base
land on top of the rings — measured, unreadable. Gutters are cheaper than leader lines that
cross the thing they point at.

Output: `circle-diagram.png`.

**The preliminary round is over and `docs/archive/nan2026/` is sealed** (its README).
Running this overwrites the record of what was submitted. **Re-point the output before
running it for the final round** — the drawing itself is round-agnostic, which is why it is kept.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
IMG = ROOT / "docs" / "archive" / "nan2026" / "img"
BASE = IMG / "circle-diagram-base.png"
DST = IMG / "circle-diagram.png"
FONT = ROOT / "assets" / "font" / "NotoSansKR-Regular.otf"

INK = (238, 233, 222)
DIM = (162, 172, 188)
LEADER = (196, 164, 96)

# The circle's bounding box in the generated base, and where it goes on the wide canvas.
ART_CROP = (300, 20, 1230, 1000)
CANVAS = (1800, 900)
ART_BOX = (510, 40, 780, 820)      # x, y, width, height

# Radii of the three parts, as a fraction of the mounted artwork's half-height. Measured on
# the base: gem 75/490, sigil band 300/490, outer rim 430/490.
R_RUNE = 0.15
R_GLYPH = 0.61
R_FRAME = 0.88

NOTE = "안쪽 층부터 바깥으로 해석한다 — 그림이 곧 순서다"


def _point(cx: float, cy: float, half: float, r: float, deg: float) -> tuple:
    from math import cos, radians, sin
    return (cx + half * r * cos(radians(deg)), cy - half * r * sin(radians(deg)))


def main() -> None:
    if not BASE.exists():
        sys.exit("[diagram] no base image at %s" % BASE)
    art = Image.open(BASE).convert("RGB").crop(ART_CROP).resize(
        (ART_BOX[2], ART_BOX[3]), Image.LANCZOS)

    # **The canvas takes the artwork's own background colour, sampled.** Guessing it left a
    # visible rectangle around the pasted art — the seam is the eye's first stop.
    im = Image.new("RGB", CANVAS, art.getpixel((3, 3)))
    im.paste(art, (ART_BOX[0], ART_BOX[1]))
    d = ImageDraw.Draw(im)

    cx = ART_BOX[0] + ART_BOX[2] / 2
    cy = ART_BOX[1] + ART_BOX[3] / 2
    half = ART_BOX[3] / 2

    name_f = ImageFont.truetype(str(FONT), 48)
    gloss_f = ImageFont.truetype(str(FONT), 26)
    note_f = ImageFont.truetype(str(FONT), 28)

    labels = [
        ("룬", "무엇이 나가는가", R_RUNE, 215, (60, 600), "left"),
        ("문양", "층마다 하나. 맞으면 무엇을 하는가", R_GLYPH, 152, (60, 210), "left"),
        ("진", "그릇. 층 수와 룬 슬롯을 정한다", R_FRAME, 26, (1740, 210), "right"),
    ]

    for name, gloss, r, deg, at, align in labels:
        point = _point(cx, cy, half, r, deg)
        anchor = "la" if align == "left" else "ra"
        d.text(at, name, font=name_f, fill=INK, anchor=anchor)
        d.text((at[0], at[1] + 62), gloss, font=gloss_f, fill=DIM, anchor=anchor)
        w = d.textlength(gloss, font=gloss_f)
        edge_x = at[0] + w + 26 if align == "left" else at[0] - w - 26
        d.line([(edge_x, at[1] + 44), point], fill=LEADER, width=3)
        d.ellipse([point[0] - 7, point[1] - 7, point[0] + 7, point[1] + 7], fill=LEADER)

    d.text((CANVAS[0] / 2, CANVAS[1] - 60), NOTE, font=note_f, fill=DIM, anchor="ma")
    im.save(DST)
    print("[diagram] %s  %dx%d" % (DST.name, im.width, im.height))


if __name__ == "__main__":
    main()
