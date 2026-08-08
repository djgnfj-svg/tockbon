"""Tries socket glyph ring candidates **laid on the real triangle circle.**

**A single image cannot be judged.** Acceptance 3, 4 and 5 in `triangle-circle-art.md` all ask about
"when laid on the circle" — does it get cut off · does the rune read · do the two read apart.
Two batches were actually wasted by looking at single images only: a ring with a border circle looks fine alone,
 but because `draw_circle.triangle()` **already draws the socket outer border (r=144) and the band inner boundary (r=96)**,
 laying it on gives a triple line. => All a glyph ring should draw is **the pattern filling between those two circles.**

## The spec does not match by itself — it is matched by measuring

This is the spot `circle-art.md` marked with "it must be measured and checked after generating". The AI does not give
the inner hole ratio the prompt asks for (ask for 2/3 and it wobbles between 0.5 and 0.8) => **measure the ink's radial
distribution and scale it so the outer ink lands exactly at r=144.** Only then does the pattern fill the socket.

**This is not the same as cutting it out** (the document's warning, "gluing pieces is worse than one whole piece").
Cutting breaks the pattern midway; here it is **shrunk whole to fit**, so the pattern does not break.
Outside the socket circle is masked away, though — without that, the ring's white background stays as **a square** (measured).

**Why it is composited by multiplication**: a ring candidate is black line on a cream ground, so it has no alpha.
Cutting by threshold stairsteps the antialiased edges => multiply the brightness straight through and only the lines survive.
The background is cream rather than pure white (255), so multiplying darkens the socket interior slightly — **normalization flattens that.**
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))   # so draw_circle is found even when invoked from the repo root

from draw_circle import S, at, triangle  # noqa: E402

SOCKET_R = 144   # socket radius (diameter 288 = the glyph ring asset size)
BAND_IN = 96     # glyph band inner boundary = 144 - 48
DIST = 368       # radius out to a socket's center
RUNE_D = 192     # rune symbol = 288 - 48x2
INK = 160        # darker than this brightness counts as ink


def _normalize(im):
    """Flattens the background to white. Without it the socket darkens one layer per multiply.

    **Dividing by the maximum brightness is not enough** — if a candidate's background is not uniform
    (generated art almost always isn't), only the single brightest point becomes 255 and **the rest of the
    background stays gray, leaving the square plainly visible** (measured: the rune symbol).
    => Take **the top 2% point** as white and push the whole background up.
    """
    g = im.convert("L")
    a = np.asarray(g)
    hi = int(np.percentile(a, 98))
    if hi <= 0:
        return g
    return Image.eval(g, lambda v: min(255, v * 255 // hi))


def ink_radii(gray):
    """Returns the radial span the ink covers, as a ratio of the image radius.

    **Counted with a radial histogram rather than per row** — if the pattern is star-shaped it reaches far
    at only certain angles, and looking at the maximum radius lets that one spike represent the whole.
    => Only spans where that radial ring's **ink fraction** exceeds a threshold count as "there is a ring here".
    """
    a = np.asarray(gray, dtype=np.int16)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(yy - (h - 1) / 2, xx - (w - 1) / 2) / (min(h, w) / 2)
    bins = np.linspace(0, 1, 101)
    idx = np.clip(np.digitize(r.ravel(), bins) - 1, 0, 99)
    ink = (a.ravel() < INK).astype(np.float64)
    total = np.bincount(idx, minlength=100)
    hit = np.bincount(idx, weights=ink, minlength=100)
    frac = np.divide(hit, total, out=np.zeros(100), where=total > 0)
    live = np.nonzero(frac > 0.06)[0]
    if len(live) == 0:
        return 0.0, 1.0
    return bins[live[0]], bins[min(live[-1] + 1, 100)]


def fit_ring(patch, out_r=SOCKET_R):
    """Fits a ring candidate to socket coordinates — scales it whole so the outer ink lands at `out_r`.

    Returns: (a grayscale image the size of the socket diameter, the inner hole radius). The caller compares the
    inner radius against `BAND_IN` (96) to judge **whether it invades the rune's slot.**
    """
    g = _normalize(patch)
    r_in, r_out = ink_radii(g)
    if r_out <= 0:
        r_out = 1.0
    # In the original, "the outer ink" sits at r_out times the image radius => send that to out_r
    full = int(round(out_r * 2 / r_out))
    big = g.resize((full, full), Image.LANCZOS)
    box = (full - out_r * 2) // 2
    fit = big.crop((box, box, box + out_r * 2, box + out_r * 2))
    return fit, r_in / r_out * out_r


def _paste_masked(base, gray, center, size):
    """Composites by multiplying through a circular mask. Without the mask the candidate's white background
    stays as **a square** (measured). This goes for the rune symbol too, not just the ring — a rune is not round, but its background is square."""
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    x, y = center
    box = (int(x - size / 2), int(y - size / 2))
    region = base.crop((box[0], box[1], box[0] + size, box[1] + size))
    mixed = ImageChops.multiply(region, gray.convert("RGB"))
    base.paste(Image.composite(mixed, region, mask), box)


def paste_socket(base, fit, center, out_r=SOCKET_R):
    _paste_masked(base, fit, center, out_r * 2)


def paste_plain(base, patch, center, size):
    """Lays on something already at spec, such as a rune symbol, as-is."""
    _paste_masked(base, _normalize(patch).resize((size, size), Image.LANCZOS), center, size)


def build(ring_path, rune_path=None, report=False):
    tri = triangle().resize((S, S), Image.LANCZOS).convert("RGB")
    fit, r_in = fit_ring(Image.open(ring_path))
    rune = Image.open(rune_path) if rune_path else None
    for ang in (-90, 30, 150):          # 12 o'clock · 4 o'clock · 8 o'clock
        cx, cy = at(ang, DIST)
        c = (cx / 4, cy / 4)            # at() gives SS (4) scale coordinates
        paste_socket(tri, fit, c)
        if rune is not None:
            paste_plain(tri, rune, c, RUNE_D)
    if report:
        mark = "OK" if r_in >= BAND_IN else "룬 자리 침범"
        print(f"  안쪽 구멍 r={r_in:.0f}  (띠 안쪽 경계 {BAND_IN})  {mark}  <- {Path(ring_path).name}")
    return tri


def save_asset(ring_path, out_path):
    """Freezes the adopted candidate as a **288 alpha png** — this is the file that goes to `assets/`.

    **Why freeze it with alpha**: a candidate is black line on cream paper, so its background is opaque. Laid on as-is,
    the socket interior gets covered by a square (the preview dodged it with multiplication, but **the game has no
    multiply blending**).
    => **Invert brightness into alpha and fix the color to the same ink black as the circle.**
    It is not cut by threshold — that stairsteps the antialiased edges.

    **Outside the socket circle is erased.** 368 + 144 = 512, so the margin is 0 and even one pixel of overflow gets clipped.
    """
    fit, r_in = fit_ring(Image.open(ring_path))
    size = SOCKET_R * 2
    alpha = Image.eval(fit, lambda v: 255 - v)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    alpha = ImageChops.multiply(alpha, mask)
    ink = Image.new("RGB", (size, size), (26, 24, 22))   # the same ink black as draw_circle.FG
    out = ink.convert("RGBA")
    out.putalpha(alpha)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    return r_in


if __name__ == "__main__":
    if sys.argv[1] == "--save":
        r_in = save_asset(sys.argv[2], sys.argv[3])
        print(f"  안쪽 구멍 r={r_in:.1f}  (띠 안쪽 경계 {BAND_IN}) -> {sys.argv[3]}")
    else:
        ring_path = sys.argv[1]
        rune_path = sys.argv[2] if len(sys.argv) > 2 else None
        out = HERE / "out" / "_socket_try.png"
        build(ring_path, rune_path, report=True).save(out)
        print(out)
