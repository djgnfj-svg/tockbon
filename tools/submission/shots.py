"""Takes the submission screenshots, then composes the paired figures.

    python tools/submission/shots.py

Two steps, and the second is the reason this file exists rather than the .gd alone:

1. `shot.tscn` runs the real game in a window and writes parts into docs/submission/img/.
2. Each order gets **one** figure — the magic circle that was assembled on the left, what
   that circle did to the world on the right. Two separate pictures side by side in the
   markdown would let the page break between them, and then the claim ("this circle makes
   that hole") is split across a page boundary with nothing tying the halves together.

The parts stay on disk (gitignored) so `--compose-only` can re-crop without re-running the engine.
"""

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
IMG = ROOT / "docs" / "submission" / "img"
GODOT = ROOT / "Godot_v4.7.1-stable_win64.exe"
SCENE = "res://tools/submission/shot.tscn"

ORDERS = ["spread-blast", "blast-spread"]

# The assembly window's left pane, in the 1920x1080 capture. The circle is drawn centred in
# it, so the crop is a square around the circle rather than the pane's own rectangle —
# cropping the pane would carry its empty right half into a figure that is already wide.
CIRCLE_CROP = (125, 80, 905, 860)
# The world half. **Its left edge is past x=430 deliberately** — the health gauge sits in the
# bottom-left of every capture, and a gauge inside a figure about terrain is noise.
FX_CROP = (560, 400, 1700, 960)

GAP = 24
BG = (22, 24, 29)


def capture() -> None:
    if not GODOT.exists():
        sys.exit("[shots] no engine at %s" % GODOT)
    r = subprocess.run([str(GODOT), "--path", str(ROOT), SCENE],
                       capture_output=True, text=True, timeout=600,
                       encoding="utf-8", errors="replace")
    print(r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr[-2000:], file=sys.stderr)
        sys.exit("[shots] engine exited %d" % r.returncode)


def compose(name: str) -> Path:
    circle_src = IMG / ("part-circle-%s.png" % name)
    fx_src = IMG / ("part-fx-%s.png" % name)
    for f in (circle_src, fx_src):
        if not f.exists():
            sys.exit("[shots] capture did not write %s" % f)

    circle = Image.open(circle_src).convert("RGB").crop(CIRCLE_CROP)
    fx = Image.open(fx_src).convert("RGB").crop(FX_CROP)
    # Match heights so neither half is letterboxed against the other.
    h = min(circle.height, fx.height)
    circle = circle.resize((round(circle.width * h / circle.height), h), Image.LANCZOS)
    fx = fx.resize((round(fx.width * h / fx.height), h), Image.LANCZOS)

    out = Image.new("RGB", (circle.width + GAP + fx.width, h), BG)
    out.paste(circle, (0, 0))
    out.paste(fx, (circle.width + GAP, 0))
    # A hairline down the seam, so the two halves read as two pictures and not one wide one.
    ImageDraw.Draw(out).line(
        [(circle.width + GAP // 2, 0), (circle.width + GAP // 2, h)],
        fill=(90, 96, 106), width=2)

    dst = IMG / ("order-%s.png" % name)
    out.save(dst)
    print("[shots] %s  %dx%d" % (dst.name, out.width, out.height))
    # **The parts are kept, not deleted.** Cropping is what actually gets iterated on, and
    # deleting them made every crop tweak cost a full engine run. They are gitignored.
    return dst


def main() -> None:
    # `--compose-only` reuses the parts already on disk. Cropping is the part that gets
    # iterated on, and re-running the engine for every pixel of it is a minute each time.
    if "--compose-only" not in sys.argv:
        capture()
    for name in ORDERS:
        compose(name)


if __name__ == "__main__":
    main()
