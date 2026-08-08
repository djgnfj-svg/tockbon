"""Lays animation frames into one horizontal sheet, plus a zoomed GIF to judge the motion by.

**The sheet is horizontal because that is what the game already reads** — `fx_tuning.CHAR_SHEET` is one row
and the state -> frame table indexes into it. A grid would need a second index for no gain.

**Every frame is padded to the widest/tallest of the set.** A generator returns frames trimmed to their own
content, so a leg lifting shrinks that frame by two pixels — laid straight into a sheet **the beast twitches
sideways every frame.** Padding is bottom-anchored and horizontally centered: the ground line is what the eye
locks onto, so it is the thing that must not move.

**The GIF is not an asset.** It exists so the motion can be judged before any of this reaches the game —
looking at a sheet still frame by frame hides exactly the stutter this script is padding against.

Usage:
    python tools/pixel/anim_sheet.py tools/pixel/out/anim_bull assets/monster/bull_walk.png [--fps 10]
"""
import argparse
import re
import sys
from pathlib import Path

from PIL import Image


def load_frames(folder):
    # `f0, f1, ... f10` must sort numerically. Plain name sort puts f10 before f2 and the walk plays scrambled.
    paths = sorted(Path(folder).glob("f*.png"), key=lambda p: int(re.sub(r"\D", "", p.stem) or 0))
    if not paths:
        print(f"{folder} 에 f*.png 가 없다")
        sys.exit(1)
    return [Image.open(p).convert("RGBA") for p in paths]


def pad(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    out = []
    for f in frames:
        c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        c.alpha_composite(f, ((w - f.width) // 2, h - f.height))  # bottom-anchored: the ground line holds
        out.append(c)
    return out, w, h


def main():
    p = argparse.ArgumentParser()
    p.add_argument("folder")
    p.add_argument("dst")
    p.add_argument("--fps", type=int, default=10)
    a = p.parse_args()

    frames, w, h = pad(load_frames(a.folder))
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * w, 0))
    Path(a.dst).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(a.dst)

    # The GIF is drawn on the stage's empty-cell color, not on transparency — GIF's 1-bit alpha turns a soft
    #  edge into a halo, and judging the motion against white is judging a different picture
    #  (`cell_materials.DEFS[EMPTY]` = #0E0E13).
    z = 4
    gif = [f.resize((w * z, h * z), Image.NEAREST) for f in frames]
    flat = []
    for g in gif:
        bg = Image.new("RGBA", g.size, (0x0E, 0x0E, 0x13, 255))
        bg.alpha_composite(g)
        flat.append(bg.convert("P", palette=Image.ADAPTIVE))
    # **The GIF lands beside the frames, never in `assets/`.** Only what the game loads belongs there;
    #  a preview sitting in `assets/` gets imported by the editor and starts looking like an asset.
    gif_path = str(Path(a.folder) / "_preview.gif")
    flat[0].save(gif_path, save_all=True, append_images=flat[1:], duration=1000 // a.fps, loop=0)

    print(f"{len(frames)} frames {w}x{h} -> {a.dst}  ·  {gif_path}")


if __name__ == "__main__":
    main()
