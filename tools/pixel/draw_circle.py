"""Draws the circle — with code, not AI.

**Simple geometry is drawn, not generated** (user judgment:
"it's just a circle. I'm only asking for layers you can put glyphs into").

**AI generation cannot do this.** Asking for "three circles with no ornament" gives something different every time,
and the socket size and band radii do not match the spec (368 · 288 · 192) — four batches still did not match.
=> What needs art is only the **pattern** (glyph rings, rune symbols); **the frame is coordinates.**

The spec reference is `docs/design/circle-art.md`. This is the code that uses those values.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).parent / "out" / "drawn"
S = 1024
SS = 4  # Supersample factor. PIL's ellipse does no antialiasing, so without this it stairsteps
BG = (250, 248, 240)   # cream paper
FG = (26, 24, 22)      # black

W_OUTER = 10   # outer ring weight
W_DIV = 4      # divider line separating layers
W_SOCKET = 7   # socket border


def circ(d, p, r, w):
    """A circle centered on point p. The coordinates are already at SS scale."""
    x, y = p
    d.ellipse([x - r, y - r, x + r, y + r], outline=FG, width=w * SS)


def disc(d, p, r, color):
    """A filled circle. **Used to erase the connecting band inside a socket** — draw the band first,
    cover the socket's spot with the background color, then redraw the ring and the line never invades the socket."""
    x, y = p
    d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def band(d, a, b, half_w, w):
    """Joins two points with **two parallel lines**. The adopted candidate's connection is a band, not a single line."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * half_w, dx / L * half_w
    for s in (1, -1):
        d.line([ax + nx * s, ay + ny * s, bx + nx * s, by + ny * s], fill=FG, width=w * SS)


def at(angle_deg, dist):
    """A point taken by angle and distance from the circle's center (SS-scale coordinates)."""
    c = S * SS / 2
    a = math.radians(angle_deg)
    return c + math.cos(a) * dist * SS, c + math.sin(a) * dist * SS


def ring(d, r, w):
    circ(d, at(0, 0), r * SS, w)


def socket(d, angle_deg, dist, r, w=W_SOCKET):
    """An empty socket of diameter 2r, `dist` away from the circle's center."""
    circ(d, at(angle_deg, dist), r * SS, w)


def new():
    im = Image.new("RGB", (S * SS, S * SS), BG)
    return im, ImageDraw.Draw(im)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / f"{name}.png"
    im.resize((S, S), Image.LANCZOS).save(p)
    print(p)


# --- plain circle — 1 rune slot · 2 shared layers ------------------
# One outer ring with two layer bands inside it. **The bands are left empty** — glyphs go in there.
def plain(layers=2, band_out=480, band_in=210, socket_r=96):
    im, d = new()
    ring(d, 506, W_OUTER)          # outer ring
    ring(d, band_out, W_DIV)       # band outer boundary
    for k in range(1, layers):     # divider lines between layers
        ring(d, band_out - (band_out - band_in) * k / layers, W_DIV)
    ring(d, band_in, W_DIV)        # band inner boundary
    socket(d, 0, 0, socket_r)      # rune socket — center
    return im


# --- fusion circle — 2 rune slots · 1 shared layer -----------------
def fusion(band_out=480, band_in=300, socket_r=96):
    im, d = new()
    ring(d, 506, W_OUTER)
    ring(d, band_out, W_DIV)
    ring(d, band_in, W_DIV)
    for ang in (180, 0):           # left · right
        socket(d, ang, 110, socket_r)
    return im


# --- triangle circle — 3 rune slots · 1 layer per rune -------------
# One band per socket. The center is ornament (not a glyph).
def triangle(socket_r=144, band_gap=48, dist=368, center_r=112, link_half=26,
             ring_r=420):
    """**These defaults are the triangle circle the user settled on** ("number 4 came out great, that's the one").
    **Change an argument and it is no longer the settled image.** If different values are needed, pass them at the call site.

    **`band_gap` 34 -> 48 (decided by the user).** Not for composition but because of an **equation**:

        288 - 48x2 = 192      <- **exactly the same** as the round circle's rune symbol slot
        288 - 34x2 = 220      <- the old value. Not 192, so **the assets become two sets**

    By eye the difference is only a slightly thicker band. **The worth is that ten runes need ten images instead of twenty.**
    That is why this one line had to be settled **before generating** — change it afterward and you regenerate that many images.

    `ring_r` is the outer ring that wraps the triangle circle.

    **The point is that the sockets overflow this ring** (user request: "make the triangle overflow the ring").
     They overflow when `dist + socket_r > ring_r`, and the sockets are drawn **after** the ring so they cover it —
     swap the order and the ring runs over the sockets, turning "punching through" into "overlapping".
    """
    im, d = new()
    pts = [at(ang, dist) for ang in (-90, 30, 150)]   # 12 o'clock · 4 o'clock · 8 o'clock

    # (1) Draw the connecting bands **first**. They are the triangle's edges joining the three sockets.
    for i in range(3):
        band(d, pts[i], pts[(i + 1) % 3], link_half * SS, W_DIV)

    # (2) The wrapping ring
    if ring_r:
        ring(d, ring_r, W_OUTER)

    # (3) Cover each socket's spot with the background and redraw the ring => neither the bands nor the outer ring enter the socket
    for p in pts:
        disc(d, p, socket_r * SS, BG)
        circ(d, p, socket_r * SS, W_OUTER)                 # socket outer border
        circ(d, p, (socket_r - band_gap) * SS, W_DIV)      # glyph band inner boundary

    # (3) Center ornament — not a glyph (one layer per rune, so there is no layer in the center)
    ctr = at(0, 0)
    disc(d, ctr, center_r * SS, BG)
    circ(d, ctr, center_r * SS, W_OUTER)
    circ(d, ctr, (center_r - band_gap) * SS, W_DIV)
    return im


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "plain"):
        save(plain(), "plain")
    if which in ("all", "fusion"):
        save(fusion(), "fusion")
    if which in ("all", "triangle"):
        save(triangle(), "triangle")
