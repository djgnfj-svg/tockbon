"""Cuts an opaque near-white background off a UI asset, by flooding in from the border.

**`cutbg.py` is the monster path and this is not it.** That file cuts *chroma green* and its header says
plainly why a flood fill is wrong there: a white chicken generated on a white ground got walked straight
through. **The UI assets are the case where a fill is safe** — `research_panel.png`'s interior is warm
parchment (255,249,205) and its frame is warm stone (254,239,192), while the background is neutral white
(255,254,255). Neutral-and-bright is a test no part of the art can accidentally satisfy, and flooding from
the border means an enclosed neutral highlight *inside* the frame survives even if one existed.

**Why this exists at all**: `research_panel.png` shipped with an opaque white background and was drawn into
the game with it — on screen the panel wore a white rectangle around its rounded stone frame. The art was
never wrong; it simply had never been keyed.

**The edge is feathered, not hard.** Cutting on a boolean leaves the frame's antialiased rim standing on
nothing, which reads as a jagged white fringe — the same fringe `cutbg.py` describes fixing a different way.
Pixels that are *partly* background get partial alpha instead.

Usage:
    python tools/pixel/cut_white_bg.py assets/<folder>/research_panel.png

⚠ **There is no UI asset folder any more** — `research_panel.png` belonged to the deleted game and the
path above is whichever `assets/` folder the caller is filling. The measurement stands; the file is gone.
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image

## How neutral and how bright a pixel has to be to count as background.
## Neutrality is the load-bearing half — the parchment is 50 points of chroma away from white and only ~6
## points of luminance, so a brightness test alone would eat the middle of the panel.
MAX_CHROMA = 14
MIN_BRIGHT = 232
## The band over which alpha ramps from 0 to 255, in brightness. Pixels between the background and the art
## are part one and part the other; a hard cut leaves their colour standing with full alpha.
FEATHER = 26


def _neutral_bright(px):
    r, g, b = px[0], px[1], px[2]
    return max(r, g, b) - min(r, g, b) <= MAX_CHROMA and min(r, g, b) >= MIN_BRIGHT - FEATHER


def cut(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        p = px[x, y]
        if not _neutral_bright(p):
            continue
        seen[y][x] = True
        # Fully background at MIN_BRIGHT and above; fading in over FEATHER below it.
        lo = min(p[0], p[1], p[2])
        alpha = 0 if lo >= MIN_BRIGHT else int(255 * (MIN_BRIGHT - lo) / FEATHER)
        px[x, y] = (p[0], p[1], p[2], min(p[3], alpha))
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im, sum(row.count(True) for row in seen)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for arg in sys.argv[1:]:
        path = Path(arg)
        out, n = cut(Image.open(path))
        out.save(path)
        total = out.width * out.height
        print("%s: %d/%d px cut (%.1f%%)" % (path.name, n, total, 100.0 * n / total))
