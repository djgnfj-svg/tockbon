"""Pads every frame of a horizontal sheet up to a target frame size. **Never resamples.**

`anim_sheet.py` lays frames out at whatever size the generator returned — 86x54 for the bull, because a
generator trims to its own content. The game's box (`monster_defs.w_px/h_px`) is 88x56, and
`net_monster_sprite` measures the two as equal. Scaling 86 -> 88 would resize the pixels themselves and the
beast would stop matching every other sprite on screen (`docs/design/monsters.md`, "pad, never resample").

The pad rule is that doc's, verbatim: **bottom pad is 0** (feet stay on the last row or the beast floats),
**left/right pad is symmetric** (the flip idiom depends on `minx + maxx == w - 1`), the rest goes on top.

Usage:
    python tools/pixel/pad_sheet.py assets/monster/bull_walk.png 88 56
"""
import sys
from pathlib import Path

from PIL import Image


def pad_sheet(path: Path, tw: int, th: int) -> str:
    img = Image.open(path).convert("RGBA")
    # The source frame size is read from the sheet, not passed in — the caller knowing the target is enough.
    fw = _guess_fw(img.width, tw)
    fh = img.height
    if fw == tw and fh == th:
        return f"{path.name}: already {tw}x{th} frames - untouched"
    if fw > tw or fh > th:
        return f"{path.name}: frame {fw}x{fh} is BIGGER than {tw}x{th} — refused (padding cannot shrink)"
    n = img.width // fw
    out = Image.new("RGBA", (tw * n, th), (0, 0, 0, 0))
    dx = (tw - fw) // 2      # symmetric left/right
    dy = th - fh             # everything on top, bottom pad 0
    for i in range(n):
        frame = img.crop((i * fw, 0, (i + 1) * fw, fh))
        out.paste(frame, (i * tw + dx, dy))
    out.save(path)
    return f"{path.name}: {n} frames {fw}x{fh} -> {tw}x{th} (pad {dx} each side, {dy} on top)"


def _guess_fw(sheet_w: int, tw: int) -> int:
    """The frame count is unknown, so the frame width is guessed from the sheet width.

    **The candidate closest to the target that divides the sheet evenly wins.** A sheet is always a whole
    number of frames, and the source frame is never more than a few px under the target — 86 vs 88 for the
    bull. Searching downward from `tw` and stopping at the first exact divisor picks 86 for 774 (774/86=9)
    and never 43 (which also divides, but is half a beast).
    """
    for w in range(tw, tw // 2, -1):
        if sheet_w % w == 0:
            return w
    return tw


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    target_w, target_h = int(sys.argv[-2]), int(sys.argv[-1])
    for p in sys.argv[1:-2]:
        print(pad_sheet(Path(p), target_w, target_h))
