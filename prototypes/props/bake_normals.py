# **Turn each flat tree card into a card that can be lit.**
#
# A quad has one normal, so a card lit by the game's own sun comes out uniformly bright and reads as
# a sticker. This writes a tangent-space normal map beside each card: the silhouette is treated as a
# blob of clay, inflated so its middle bulges toward the viewer and its rim turns away.
#
# WARNING **The bulge is per LUMP, not per card.** A distance transform measures the distance to the
# nearest transparent pixel, so a crown made of five leaf clumps inflates into five domes rather than
# one -- which is what the Bad North reference shows.
#
#   python prototypes/props/bake_normals.py
#
# Writes `<name>_n.png` beside every `<n>-*.png` in this folder.
import os
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
# How tall the inflated blob is relative to its width. Higher = a rounder, more strongly shaded card.
BULGE = 1.5
# The height field is smoothed before its slope is read, or every pixel step becomes a facet.
SMOOTH = 1.2


def bake(path: str) -> None:
    img = Image.open(path).convert("RGBA")
    a = np.array(img)[:, :, 3] > 8
    if not a.any():
        return
    # Distance to the nearest empty pixel: 0 on the rim, largest in the middle of a lump.
    d = distance_transform_edt(a)
    # WARNING **Normalised against the card's own size.** The distance transform counts PIXELS, so
    # the same tree drawn at 240px came out with a quarter of the slope of the 64px one and read as
    # flat again. Dividing by the card's size makes the bulge a property of the SHAPE, not the file.
    d = d / max(min(img.size) / 64.0, 1e-6)
    # sqrt turns a cone into a dome -- a linear ramp gives a flat-sided pyramid.
    h = np.sqrt(np.maximum(d, 0.0)) * BULGE
    # The smoothing is in pixels too, so it scales with the card for the same reason.
    h = gaussian_filter(h, SMOOTH * max(min(img.size) / 64.0, 1.0))
    # The slope of the height field IS the normal, once it is flipped and given a z.
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    # Outside the silhouette the normal points straight at the viewer, so a stray texel is neutral.
    flat = np.zeros_like(n)
    flat[:, :, 2] = 1.0
    n = np.where(a[:, :, None], n, flat)
    out = ((n * 0.5 + 0.5) * 255.0).clip(0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(path[:-4] + "_n.png")
    print("baked", os.path.basename(path[:-4] + "_n.png"))


for f in sorted(os.listdir(HERE)):
    if f.endswith(".png") and not f.endswith("_n.png") and not f.endswith("_sheet.png"):
        bake(os.path.join(HERE, f))
