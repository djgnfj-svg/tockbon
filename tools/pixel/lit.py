"""Turn a white-line-on-black generation into a tintable alpha asset. **`ink.py`'s mirror image.**

`ink.py` exists for line art drawn dark on cream — it INVERTS luminance, so darkness is coverage. This one
is for the cell game, where the body is generated as a **white outline on pure black**, and there luminance
is coverage directly. Running the wrong one of the two gives a perfectly plausible negative: a solid square
with a hole where the body should be.

**The RGB is flat white, and that is the whole point.** The body is drawn once and every species, every
clone and the host are the same picture with a different `modulate` — white × colour = colour, so one file
carries the lot. Bake any tint into the RGB and that stops being true.

**No resample by default.** The generation is already 256px and the game scales it per body (a clone is
16px, the boss 96, and force leans on both), so a fixed downscale here would only throw pixels away before
the engine does its own scaling. Pass a size when a specific box is wanted.

**LANCZOS when it does resample**, not k_centroid — same reason `ink.py` says so. k_centroid takes a
block's dominant colour and eats a thinning stroke outright; an area resample keeps it as partial alpha.

Usage: python lit.py <src.png> <dst.png> [size]
"""
import sys
from pathlib import Path

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 0

im = Image.open(src).convert("L")
if size > 0:
    im = im.resize((size, size), Image.LANCZOS)

# Brightness *is* coverage here. The antialiased edge of a stroke arrives as partial alpha for free.
out = Image.new("RGBA", im.size, (255, 255, 255, 0))
out.putalpha(im)
Path(dst).parent.mkdir(parents=True, exist_ok=True)
out.save(dst)

lo, hi = im.getextrema()
# Histogram rather than a walk over getdata() — same number, and getdata() is deprecated as of Pillow 11.
total = im.size[0] * im.size[1]
opaque = sum(im.histogram()[128:])
print(f"{src} -> {dst}  {im.size[0]}x{im.size[1]}  alpha {lo}..{hi}  "
      f"opaque {opaque}/{total} px ({100.0 * opaque / total:.1f}%)")
