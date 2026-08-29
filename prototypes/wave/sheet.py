"""Put every candidate on ONE sheet, two cameras side by side.

⚠⚠ **The right-hand column is the whole point.** The left is the island in frame, which is what every
earlier water round was judged on; the right is the same shader with **no land anywhere in the picture**,
which is the question actually asked (2026-08-29: 「먼 바다까지 생각했을 때의 바다를 어떻게 할지」).
A mechanism can win the left column and be blank in the right, and that has to be visible in one look.

    python prototypes/wave/sheet.py [frame]

`frame` picks which of the four shots per version to use; it defaults to 1.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
NEAR = HERE / "out" / "island"
WIDE = HERE / "out" / "wide"
FAR = HERE / "out" / "far"
OUT = HERE / "out" / "sheet.png"

W, H = 420, 236
PAD, GAP, ROW_H = 34, 12, 30
TOP = 122
INK = (28, 30, 34)
GREY = (110, 116, 126)
BG = (247, 246, 243)


def font(size, bold=False):
    for name in (("arialbd.ttf", "segoeuib.ttf") if bold else ("arial.ttf", "segoeui.ttf")):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def versions():
    out = ["shipped"]
    for d in sorted(HERE.iterdir()):
        if d.is_dir() and (d / "mech.gdshader").exists():
            out.append(d.name)
    return out


def main():
    frame = sys.argv[1] if len(sys.argv) > 1 else "1"
    rows = versions()
    sheet = Image.new("RGB", (PAD * 2 + W * 3 + GAP * 2, TOP + len(rows) * (H + ROW_H) + PAD), BG)
    draw = ImageDraw.Draw(sheet)

    draw.text((PAD, 26), "the sea with light on it", font=font(30, True), fill=INK)
    draw.text((PAD, 64), "row 0 is the sea as it ships and takes no light at all. every other row carries the island's shadow.",
              font=font(15), fill=GREY)
    for i, label in enumerate(("THE OPENING VIEW", "FAR OUT — ZOOMED BACK", "OPEN WATER — NO LAND")):
        draw.text((PAD + i * (W + GAP), TOP - 24), label, font=font(13, True), fill=GREY)

    y = TOP
    for name in rows:
        draw.text((PAD, y + 5), name, font=font(18, True), fill=INK)
        y += ROW_H
        for k, folder in enumerate((NEAR, WIDE, FAR)):
            path = folder / ("%s_%s.png" % (name, frame))
            box = (PAD + k * (W + GAP), y)
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS), box)
            else:
                draw.rectangle([box, (box[0] + W, box[1] + H)], outline=GREY)
                draw.text((box[0] + 16, box[1] + 16), "missing", font=font(16), fill=GREY)
        y += H

    sheet.save(OUT)
    print("wrote %s  (%d x %d)" % (OUT, sheet.width, sheet.height))


main()
