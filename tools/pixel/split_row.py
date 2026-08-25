"""Cuts one generated sprite-sheet row into registered `f*.png` frames.

    python tools/pixel/split_row.py out/wolf_walk_sheet/wolf_walk_sheet_02_seed608559085.png \
        out/anim_wolf_walk --frames 4 --height 40

**Why this file exists**: FLUX draws the whole walk cycle in one wide image, which is what keeps the
style, the lighting and the body proportions identical across frames (`README.md` — the texture comes
from the preset, and one image is one preset applied once). What it does **not** give is registration:
the four wolves sit at slightly different heights and are not evenly spaced, so cutting the row into
equal quarters makes the beast **jump around between frames**, and an animation that jumps reads as a
glitch rather than as motion.

⚠ **The split is by gap, not by equal quarters.** The generator spaces the frames unevenly — measured on
every batch so far — so `width / 4` slices a leg off. Columns with no beast in them are found first and
the row is cut down the middle of the widest gaps.

⚠⚠ **Registration is the whole point and `--align feet` is the default.** Three anchors were considered:
 - `bbox` centres each frame's bounding box. **Wrong for a bite**: the head thrusting forward widens the
   box on one side only, so centring it slides the whole body backwards on the strike frame.
 - `mass` uses the alpha centroid. Better, but a tail lifting still drags it.
 - `feet` uses the centroid of the bottom quarter of the frame. **The feet are what the eye locks onto**,
   which is the same reason `anim_sheet.py` anchors its padding to the bottom.
The vertical anchor is not a choice: every frame is pinned to **one common ground line**, the lowest
opaque row across the whole set.

The frames come out **all on one canvas of the same size**, so `anim_sheet.py`'s own padding becomes a
no-op and the relative placement this script computed survives into the sheet and the GIF.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cutbg import cut  # noqa: E402  — the same chroma-green test the monsters use


def column_bands(alpha, want, min_gap=4):
    """Splits the row into `want` bands at its emptiest columns."""
    occupied = alpha.max(axis=0) > 8
    bands, start = [], None
    for x, on in enumerate(occupied):
        if on and start is None:
            start = x
        elif not on and start is not None:
            bands.append((start, x))
            start = None
    if start is not None:
        bands.append((start, len(occupied)))
    # Blobs separated by a hairline gap are one frame's paws, not two frames.
    merged = []
    for b in bands:
        if merged and b[0] - merged[-1][1] < min_gap:
            merged[-1] = (merged[-1][0], b[1])
        else:
            merged.append(list(b))
    merged = [tuple(b) for b in merged]
    if len(merged) == want:
        return merged
    # Fallback: the frames touched, so cut at the `want-1` emptiest interior columns instead.
    # No `⚠` in a printed string: this console is cp949 and that character raises UnicodeEncodeError,
    #  which killed the run outright on two of six sheets. Warning marks stay in comments.
    print(f"  [!] 덩어리가 {len(merged)}개다 (원한 것 {want}). 가장 빈 열에서 자른다")
    density = alpha.sum(axis=0).astype(float)
    w = len(density)
    cuts = []
    for i in range(1, want):
        lo, hi = int(w * i / want) - w // (want * 4), int(w * i / want) + w // (want * 4)
        cuts.append(lo + int(np.argmin(density[lo:hi])))
    edges = [0] + cuts + [w]
    return [(edges[i], edges[i + 1]) for i in range(want)]


def facing(alpha):
    """Which way the beast looks — **decided by the ears, because they are the highest thing on it.**

    A quadruped in profile has its tail low and its ears at the top of the silhouette, so the mean x of
    the topmost band of opaque pixels sits over the head. Comparing that against the body's own centroid
    gives the direction without knowing anything about the animal."""
    ys, xs = np.nonzero(alpha > 8)
    if len(xs) == 0:
        return "right"
    top, bottom = ys.min(), ys.max()
    ear = ys <= top + max(1, (bottom - top) // 8)
    return "right" if xs[ear].mean() > xs.mean() else "left"


def anchor_x(alpha, mode):
    ys, xs = np.nonzero(alpha > 8)
    if len(xs) == 0:
        return alpha.shape[1] / 2
    if mode == "bbox":
        return (xs.min() + xs.max()) / 2
    if mode == "feet":
        floor = ys.max()
        keep = ys >= floor - max(2, (ys.max() - ys.min()) // 4)
        if keep.any():
            return xs[keep].mean()
    return xs.mean()


def main():
    p = argparse.ArgumentParser(description="생성된 시트 한 줄을 정렬된 프레임들로 자른다")
    p.add_argument("src", help="2048x512 같은 가로 시트 한 장")
    p.add_argument("dst", help="f0.png.. 를 쓸 폴더")
    p.add_argument("--frames", type=int, default=4)
    p.add_argument("--height", type=int, default=0, help="최종 높이 px (0이면 원본 크기 그대로)")
    p.add_argument("--align", default="feet", choices=["feet", "mass", "bbox"])
    p.add_argument("--desat", type=float, default=0.0,
                   help="0..1. 생성마다 다르게 끼는 색조를 걷어낸다. 출하된 늑대에 맞추려면 0.7 근처")
    p.add_argument("--face", default="auto", choices=["auto", "left", "right", "none"],
                   help="뒤집힌 프레임을 바로잡는다. auto 는 다수결을 따른다")
    p.add_argument("--no-norm", dest="norm", action="store_false",
                   help="프레임마다 크기를 맞추지 않는다 (기본은 맞춘다)")
    p.add_argument("--pad", type=int, default=6, help="정렬 후 좌우 여백 (px, 최종 크기 기준 아님)")
    a = p.parse_args()

    im = cut(Image.open(a.src))

    # ⚠ **Each generation lights the wolf a different colour.** Measured against the shipped
    #  `assets/beast/wolf_r.png`, whose mean saturation is **7.6**: candidates came back at 5.1 (a match)
    #  but also at 14.9 teal, 17.1 teal and 21.0 blue, and one bite row at 13.6 pink. On the stage's
    #  `#0E0E13` a tinted wolf does not read as the same animal as the one already in the game.
    # => Pulling each pixel toward its own luminance removes the cast **without touching the shading**,
    #  which is what a flat desaturate or a hue shift would wreck.
    if a.desat > 0:
        px = np.asarray(im).astype(np.float32)
        lum = (px[:, :, 0] * 0.299 + px[:, :, 1] * 0.587 + px[:, :, 2] * 0.114)[:, :, None]
        px[:, :, :3] += (lum - px[:, :, :3]) * a.desat
        im = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGBA")

    arr = np.asarray(im)
    alpha = arr[:, :, 3]

    bands = column_bands(alpha, a.frames)
    print(f"  {len(bands)} bands: {bands}")

    crops = [im.crop((x0, 0, x1, im.height)) for x0, x1 in bands]

    # ⚠⚠ **The generator mirrors some frames.** Measured on a four-frame walk row: three wolves faced
    #  left and the fourth faced right, and the onion overlay showed it at once as two heads in two
    #  places. Nothing about the prompt fixes it — `facing right` was in the prompt and was ignored.
    #  => It is detected and undone here instead.
    if a.face != "none":
        sides = [facing(np.asarray(c)[:, :, 3]) for c in crops]
        want = a.face if a.face in ("left", "right") else (
            "right" if sum(1 for s in sides if s == "right") * 2 >= len(sides) else "left")
        flipped = [i for i, s in enumerate(sides) if s != want]
        if flipped:
            print(f"  facing {sides} -> {want}, 뒤집은 프레임 {flipped}")
            crops = [c.transpose(Image.FLIP_LEFT_RIGHT) if i in flipped else c
                     for i, c in enumerate(crops)]

    # ⚠⚠ **The generator draws each frame at a slightly different size.** Measured with an onion-skin
    #  overlay of a four-frame walk: aligning the feet still left one frame visibly larger than the rest,
    #  and on screen that reads as the wolf breathing in and out rather than walking.
    # **Silhouette area is the scale estimate, not bounding-box height.** A lifted paw or a raised head
    #  changes the box by a lot and the number of opaque pixels by very little, so area is the one
    #  measure of "how big is this wolf" that a pose does not move.
    if a.norm:
        areas = [float((np.asarray(c)[:, :, 3] > 8).sum()) for c in crops]
        target = float(np.median(areas))
        floor_to = max(int(np.nonzero(np.asarray(c)[:, :, 3] > 8)[0].max()) for c in crops)
        scaled, factors = [], []
        for c, area in zip(crops, areas):
            s = (target / area) ** 0.5 if area > 0 else 1.0
            s = min(max(s, 1 / 1.4), 1.4)  # a wilder correction than this means the split was wrong
            factors.append(s)
            r = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
            ra = np.asarray(r)[:, :, 3]
            # Scaling moves the wolf's own floor, so the paste puts **the lowest paw** back on the
            #  common ground line. Anchoring the canvas bottom instead would let the empty sky above
            #  the wolf decide where it stands.
            floor_now = int(np.nonzero(ra > 8)[0].max())
            pane = Image.new("RGBA", (max(c.width, r.width), im.height), (0, 0, 0, 0))
            pane.alpha_composite(r, (0, floor_to - floor_now))
            scaled.append(pane)
        print("  scale x" + " ".join(f"{s:.3f}" for s in factors))
        crops = scaled

    masks = [np.asarray(c)[:, :, 3] for c in crops]

    # One ground line for the whole set. Taking each frame's own floor is what makes a lifted paw
    #  shove the beast a pixel upward every frame.
    floors = [int(np.nonzero(m > 8)[0].max()) for m in masks]
    tops = [int(np.nonzero(m > 8)[0].min()) for m in masks]
    ground = max(floors)
    head = min(tops)

    anchors = [anchor_x(m, a.align) for m in masks]
    lefts = [int(round(anc)) for anc in anchors]
    span_l = max(lefts)
    span_r = max(c.width - l for c, l in zip(crops, lefts))
    cw = span_l + span_r + a.pad * 2
    ch = (ground - head) + a.pad * 2

    out = Path(a.dst)
    out.mkdir(parents=True, exist_ok=True)
    for i, (c, l, m) in enumerate(zip(crops, lefts, masks)):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        # The crops were cut in x only, so **the generator's own vertical placement is already correct** —
        #  a paw lifted off the ground must stay lifted. All this offset does is trim the empty sky above.
        canvas.alpha_composite(c, (a.pad + span_l - l, a.pad - head))
        if a.height:
            scale = a.height / ch
            canvas = canvas.resize((max(1, round(cw * scale)), a.height), Image.LANCZOS)
        canvas.save(out / f"f{i}.png")
    # ⚠ **`_onion.png` is the only honest check that the registration worked.** Four frames laid on top
    #  of one another at low opacity: if the wolf is registered, the overlay is one wolf with a blur of
    #  legs; if it is not, two heads show up in different places. Looking at the frames one at a time
    #  hides exactly the jitter this script exists to remove. It is a diagnostic, never an asset.
    frames = [Image.open(out / f"f{i}.png").convert("RGBA") for i in range(len(crops))]
    fw, fh = frames[0].size
    z = max(1, 240 // max(fw, fh))
    strip = Image.new("RGB", (fw * len(frames) * z, fh * z), (0x0E, 0x0E, 0x13))
    onion = Image.new("RGB", (fw * z, fh * z), (0x0E, 0x0E, 0x13))
    for i, f in enumerate(frames):
        big = f.resize((fw * z, fh * z), Image.NEAREST)
        strip.paste(big, (i * fw * z, 0), big)
        faint = np.asarray(big).copy()
        faint[:, :, 3] = (faint[:, :, 3] * 0.4).astype(np.uint8)
        faint = Image.fromarray(faint)
        onion.paste(faint, (0, 0), faint)
    strip.save(out / "_zoom.png")
    onion.save(out / "_onion.png")

    # The colour cast, as one number, so `--desat` is aimed rather than guessed. **The shipped
    #  `assets/beast/wolf_r.png` reads 7.6**; saturation scales with `1 - desat`, so the value that
    #  lands on the shipped wolf is `1 - 7.6/<the number printed at --desat 0>` and it differs per
    #  candidate — one generation came in at 9.8 and another at 21.0.
    px = np.asarray(frames[0])
    body = px[:, :, :3][px[:, :, 3] > 8].astype(int)
    if len(body):
        print(f"  meanSat {(body.max(1) - body.min(1)).mean():.1f}  (출하된 늑대는 7.6)")

    print(f"  {len(crops)} frames {cw}x{ch}"
          f"{f' -> {round(cw * a.height / ch)}x{a.height}' if a.height else ''} -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
