"""Puts chosen animation frames into `assets/` under the roster's naming, on **one shared canvas**.

    python tools/pixel/install_anim.py --dst assets/beast --beast wolf \
        --set walk=tools/pixel/out/full_walk --set bite=tools/pixel/out/full_bite

⚠⚠ **Every frame this writes shares one canvas, across all the sets named in one call.** That is not
tidiness, it is the whole job, and the reason is in `src/view/field_view.gd`:

    func _beast_rect(centre, radius, squash, tex) -> Rect2:
        var w := radius * Look.BEAST_SPRITE_W_RATIO * squash.x
        var h := w * tex.get_height() / tex.get_width() * squash.y
        return Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))

**The sprite's width is fixed by the body radius, never by the texture**, the height follows the
texture's own aspect ratio, and the rect is **centred on the body, not stood on the ground.** So a
texture that is 4 px wider than the last one does not draw 4 px wider — it draws **the same width with
the wolf inside it shrunk**, and a texture 2 px taller lifts the whole animal off the ground. ⇒ **Two
frames of one animation on two canvas sizes is a wolf that pulses and floats.** One canvas, always.

**The canvas is the union of every frame's bounding box**, which is the smallest one that holds them
all: any tighter and a frame gets clipped, any looser and the wolf renders smaller than the roster for
no reason.

**The two sets are scaled to each other by silhouette area** before the union is taken, so the body in
a bite frame is the same body as in a walk frame. A raised head then genuinely makes the canvas taller,
which is what should happen — the height is the honest consequence of the pose.

⚠ **What this cannot match is the standing `wolf_l.png` already shipped.** That one is trimmed tight to
a single pose (57x40), so its aspect is not this set's aspect and switching idle -> walk will change the
animal's height slightly. Regenerating the standing frame into the same set is the fix, and it is the
user's call, not this script's.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load_set(folder):
    paths = sorted(Path(folder).glob("f*.png"), key=lambda p: int("".join(c for c in p.stem if c.isdigit()) or 0))
    if not paths:
        print(f"{folder} 에 f*.png 가 없다")
        sys.exit(1)
    return [Image.open(p).convert("RGBA") for p in paths]


def bbox_of(im):
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    return xs.min(), ys.min(), xs.max(), ys.max()


def feet_x(im):
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    floor = ys.max()
    keep = ys >= floor - max(2, (ys.max() - ys.min()) // 4)
    return float(xs[keep].mean()), int(floor)


def main():
    p = argparse.ArgumentParser(description="고른 프레임들을 assets/ 에 한 캔버스로 설치한다")
    p.add_argument("--dst", required=True)
    p.add_argument("--beast", required=True, help="파일 이름의 앞머리. 기존 규칙은 wolf")
    p.add_argument("--set", action="append", required=True, metavar="NAME=FOLDER",
                   help="walk=tools/pixel/out/full_walk 처럼. 여러 번 줄 수 있다")
    p.add_argument("--height", type=int, default=40, help="최종 캔버스 높이. 기존 짐승들이 전부 40이다")
    p.add_argument("--tint", default="", metavar="REF.PNG",
                   help="이 그림의 평균 색으로 화이트밸런스를 맞춘다. 보통 assets/beast/wolf_h/east.png")
    p.add_argument("--no-tint", action="append", default=[], metavar="NAME",
                   help="이 묶음은 화이트밸런스를 건드리지 않는다. 색 기준이 되는 묶음에 쓴다")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()

    sets = {}
    for spec in a.set:
        name, _, folder = spec.partition("=")
        sets[name] = load_set(folder)

    # One scale per set, so the body in a bite frame is the same body as in a walk frame. Area, not
    #  bounding-box height: a raised head moves the box a lot and the opaque pixel count almost not.
    areas = {n: float(np.median([(np.asarray(f)[:, :, 3] > 8).sum() for f in fs])) for n, fs in sets.items()}
    target = float(np.median(list(areas.values())))
    scaled = {}
    for n, fs in sets.items():
        s = (target / areas[n]) ** 0.5
        scaled[n] = [f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.LANCZOS)
                     for f in fs] if abs(s - 1) > 1e-3 else list(fs)
        print(f"  {n}: {len(fs)} frames, scale x{s:.4f}")

    # ⚠ **Matching saturation is not matching colour.** `split_row --desat` pulls each pixel toward its
    #  own luminance, which fixes how *strong* the cast is but not which way it points: both sets came
    #  out at the shipped wolf's meanSat 7.6 and still measured **16 and 13 points heavier in blue**,
    #  because the low-poly renders are lit cool and the shipped wolf is lit warm.
    # => A per-channel gain onto the reference's mean. **Multiplicative, so the shading survives** — an
    #  additive shift would flatten the dark facets, and those facets are the whole look.
    if a.tint:
        ref = np.asarray(Image.open(a.tint).convert("RGBA"))
        rm = ref[:, :, :3][ref[:, :, 3] > 8].astype(float).mean(0)
        for n, fs in scaled.items():
            # ⚠ **The set the others were matched TO must not be corrected.** The idle frame is the
            #  colour target; running a gain over it would move the target and leave nothing anchored.
            if n in a.no_tint:
                print(f"  {n}: tint skipped (이 묶음이 색 기준이다)")
                continue
            allpx = np.concatenate([np.asarray(f)[:, :, :3][np.asarray(f)[:, :, 3] > 8] for f in fs])
            gain = rm / np.maximum(allpx.astype(float).mean(0), 1e-6)
            print(f"  {n}: tint gain {gain.round(3)}")
            out = []
            for f in fs:
                px = np.asarray(f).astype(np.float32).copy()
                px[:, :, :3] = np.clip(px[:, :, :3] * gain[None, None, :], 0, 255)
                out.append(Image.fromarray(px.astype(np.uint8), "RGBA"))
            scaled[n] = out

    # Register everything against one ground line and one feet anchor, then take the union box.
    placed = []
    for n, fs in scaled.items():
        for i, f in enumerate(fs):
            fx, floor = feet_x(f)
            x0, y0, x1, y1 = bbox_of(f)
            placed.append({"set": n, "i": i, "im": f, "fx": fx, "floor": floor,
                           "l": fx - x0, "r": x1 - fx, "up": floor - y0})
    span_l = max(q["l"] for q in placed)
    span_r = max(q["r"] for q in placed)
    span_up = max(q["up"] for q in placed)
    cw, chh = int(round(span_l + span_r)) + 1, int(round(span_up)) + 1

    out_h = a.height
    out_w = max(1, round(cw * out_h / chh))
    print(f"  공용 캔버스 {cw}x{chh} -> {out_w}x{out_h}")

    dst = Path(a.dst)
    written = []
    for q in placed:
        canvas = Image.new("RGBA", (cw, chh), (0, 0, 0, 0))
        canvas.alpha_composite(q["im"], (int(round(span_l - q["fx"])), int(round(span_up - q["floor"]))))
        small = canvas.resize((out_w, out_h), Image.LANCZOS)
        for facing, img in (("r", small), ("l", small.transpose(Image.FLIP_LEFT_RIGHT))):
            name = f"{a.beast}_{q['set']}_{q['i']}_{facing}.png"
            written.append(name)
            if not a.dry_run:
                dst.mkdir(parents=True, exist_ok=True)
                img.save(dst / name)

    print(f"  {len(written)} files -> {dst}" + ("  (dry run)" if a.dry_run else ""))
    for n in written:
        print(f"    {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
