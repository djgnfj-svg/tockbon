"""Puts every selection-box candidate's two shots on one sheet, so they are compared rather than
remembered.

    python .prototypes/selection_box/sheet.py

One row per candidate: the yaw-0 shot, the yaw-90 shot, and beside them the candidate's name and
the three NOTES lines (buys / costs / cannot) read from `<NN-name>/NOTES.md`. The question sits
across the top in the user's own words.

The lab writes `out/<name>_yaw0.png` and `out/<name>_yaw90.png`; this only lays them out. A
candidate folder with no shots is skipped and said so, rather than crashing the sheet.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SCALE = 0.5
PAD = 12
TEXT_W = 520
TITLE_H = 76
NAME_H = 30
LINE_H = 24
BG = (24, 24, 26)
FG = (235, 235, 235)
DIM = (170, 170, 175)

QUESTION_KO = "「땅에 깔리는 거랑 그냥 사각형이랑 둘 다 해야할듯? 그렇게 프로토타입으로 보는거지 해보면서」"
QUESTION_EN = ("\"the ground-laid one and the plain rectangle both have to be tried; "
               "that is what a prototype is for, you see it by trying.\"")
COLS = ("yaw0", "yaw90")
COL_LABEL = {"yaw0": "yaw 0 — the opening camera", "yaw90": "after one Q — a quarter turn"}


def _font(size):
    # A Korean-capable face, because the question is Korean. Falls back to the default bitmap font
    # rather than dying — an unlabelled sheet is still a sheet.
    for path in (r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\malgunbd.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _notes(name):
    """The three NOTES lines: every line beginning with `- ` in `<name>/NOTES.md`, or the first
    three non-heading lines when the file was written another way."""
    path = os.path.join(HERE, name, "NOTES.md")
    if not os.path.exists(path):
        return ["(no NOTES.md)"]
    with open(path, encoding="utf-8") as f:
        raw = [ln.rstrip() for ln in f]
    bullets = [ln[2:].strip() for ln in raw if ln.startswith("- ")]
    if bullets:
        return bullets[:3]
    body = [ln.strip() for ln in raw if ln.strip() and not ln.startswith("#")]
    return body[:3] or ["(NOTES.md is empty)"]


def _wrap(draw, text, font, width):
    words = text.split(" ")
    lines, cur = [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=font) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


names = sorted(d for d in os.listdir(HERE)
               if os.path.isdir(os.path.join(HERE, d)) and d != "out" and d[0].isdigit())

rows = []
for n in names:
    shots = []
    for which in COLS:
        p = os.path.join(OUT, "%s_%s.png" % (n, which))
        if not os.path.exists(p):
            print("skip %s: no %s" % (n, os.path.basename(p)))
            shots = None
            break
        im = Image.open(p).convert("RGB")
        shots.append(im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.LANCZOS))
    if shots:
        rows.append((n, shots, _notes(n)))

if not rows:
    print("nothing to lay out — run the lab with -- shoot first")
    sys.exit(1)

cw = rows[0][1][0].width
ch = rows[0][1][0].height
font_q = _font(20)
font_name = _font(20)
font_line = _font(15)
font_col = _font(14)

width = PAD + (cw + PAD) * len(COLS) + TEXT_W + PAD
height = PAD + TITLE_H + NAME_H + (ch + PAD) * len(rows) + PAD
sheet = Image.new("RGB", (width, height), BG)
d = ImageDraw.Draw(sheet)

# The question across the top, Korean then the translation.
d.text((PAD, PAD), QUESTION_KO, fill=FG, font=font_q)
d.text((PAD, PAD + 30), QUESTION_EN, fill=DIM, font=font_line)

# Column labels over the two picture columns.
y0 = PAD + TITLE_H
for j, which in enumerate(COLS):
    d.text((PAD + j * (cw + PAD) + 4, y0), COL_LABEL[which], fill=DIM, font=font_col)

for i, (n, shots, notes) in enumerate(rows):
    y = y0 + NAME_H + i * (ch + PAD)
    for j, im in enumerate(shots):
        sheet.paste(im, (PAD + j * (cw + PAD), y))
    tx = PAD + (cw + PAD) * len(COLS)
    d.text((tx, y), n, fill=FG, font=font_name)
    ty = y + NAME_H
    for line in notes:
        for part in _wrap(d, line, font_line, TEXT_W - PAD):
            d.text((tx, ty), part, fill=DIM, font=font_line)
            ty += LINE_H

path = os.path.join(OUT, "_SHEET_selection_box.png")
sheet.save(path)
print(path, sheet.size, "%d candidates" % len(rows))
