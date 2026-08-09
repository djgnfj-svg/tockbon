"""Turn a cream-ground line-art generation into the ink-on-alpha asset this repo already ships.

**The existing `assets/circle/socket_glyph_*.png` were measured, and this matches them by construction**:
one flat colour (26,24,22) everywhere, and **the picture lives entirely in the alpha channel** — a stroke is
alpha 255, the cream ground is 0, and the ring's inner hole is ~9. Nothing about the drawing is in the RGB.

That structure is what lets the art sit on any window colour, which matters here: `circle-art.md` records
that the assembly window is still dark navy in code while every sigil is generated on cream paper. Keyed this
way the art does not carry its own ground onto the screen.

**Resampled with LANCZOS, not k_centroid.** `gen.py`'s `sigil` preset carries `down: 0` precisely because
line art loses its thin strokes to k_centroid's dominant-colour blocks — the triangle circle was adopted as
the 1024 original for that reason. A plain area resample keeps a thinning stroke as partial alpha instead of
dropping it.

Usage: python ink.py <src.png> <dst.png> <size> [--keep-hole]
"""
import sys
from pathlib import Path

from PIL import Image

INK = (26, 24, 22)

src, dst, size = sys.argv[1], sys.argv[2], int(sys.argv[3])

im = Image.open(src).convert("L")
im = im.resize((size, size), Image.LANCZOS)
# Darkness *is* coverage. Inverting luminance gives a stroke's antialiased edge partial alpha for free,
# which is the same soft edge the shipped assets have (their alpha histogram is not two-valued).
alpha = im.point(lambda v: 255 - v)

out = Image.new("RGBA", (size, size), INK + (0,))
out.putalpha(alpha)
Path(dst).parent.mkdir(parents=True, exist_ok=True)
out.save(dst)

lo, hi = alpha.getextrema()
print(f"{src} -> {dst}  {size}x{size}  alpha {lo}..{hi}")
