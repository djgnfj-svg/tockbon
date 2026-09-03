# Cuts a near-BLACK ground out of a `ui`-preset candidate and downscales it to its ship size.
#
# The README names two cutters and neither fits a UI plate on black:
#   `cutbg.py`       cuts by "green dominates"  — that is the `monster` preset's chroma ground.
#   `cut_white_bg.py` is named in the README and **is not in the repo**.
#
# Why a flood and not "erase every dark pixel": a banner has its own shadows, and a plate has dark
# grooves. Only the ground is reachable from the border, so the flood is what tells them apart.
#
# Why premultiply around the resize: LANCZOS on straight RGBA blends the ground's BLACK into the
# edge pixels' colour, so a red banner comes back with a dirty dark rim that is invisible at 1024
# and obvious at ship size. Premultiply -> resize -> un-premultiply keeps the edge the banner's own
# colour. **This is the same failure `cutbg.py` records as a green fringe, in a different colour.**
#
#   python cut_dark_bg.py <in.png> <out.png> <ship_width>

import sys
from collections import deque

from PIL import Image

# A pixel is ground when its brightest channel is at or under this. Measured on the picked banner:
# the ground is (0,0,0)-(0,0,1) and the darkest thing inside the art is far above it.
GROUND_MAX = 28


def cut(src, dst, ship_w):
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    ground = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))

    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if ground[i]:
            continue
        r, g, b, _a = px[x, y]
        if max(r, g, b) > GROUND_MAX:
            continue
        ground[i] = 1
        q.append((x + 1, y))
        q.append((x - 1, y))
        q.append((x, y + 1))
        q.append((x, y - 1))

    for y in range(h):
        row = y * w
        for x in range(w):
            if ground[row + x]:
                px[x, y] = (0, 0, 0, 0)

    ship_h = int(round(ship_w * h / float(w)))

    # premultiply -> resize -> un-premultiply
    src_px = im.load()
    pre = Image.new("RGBA", (w, h))
    pre_px = pre.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src_px[x, y]
            f = a / 255.0
            pre_px[x, y] = (int(r * f), int(g * f), int(b * f), a)

    small = pre.resize((ship_w, ship_h), Image.LANCZOS)
    out = Image.new("RGBA", (ship_w, ship_h))
    s_px = small.load()
    o_px = out.load()
    for y in range(ship_h):
        for x in range(ship_w):
            r, g, b, a = s_px[x, y]
            if a == 0:
                o_px[x, y] = (0, 0, 0, 0)
                continue
            f = 255.0 / a
            o_px[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)

    out.save(dst)
    opaque = sum(1 for y in range(ship_h) for x in range(ship_w) if o_px[x, y][3] > 0)
    print("%s -> %s  %dx%d  opaque %d/%d" % (src, dst, ship_w, ship_h, opaque, ship_w * ship_h))


if __name__ == "__main__":
    cut(sys.argv[1], sys.argv[2], int(sys.argv[3]))
