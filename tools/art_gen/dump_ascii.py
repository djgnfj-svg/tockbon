# -*- coding: utf-8 -*-
"""생성한 픽셀을 ASCII 맵 + 색 범례로 떨군다 (aseprite Lua가 읽어 원본을 만든다)."""
import os, io
from gen_balls import BUILDERS, RAMPS, A, FW, FH, NF, ORDER

HERE = os.path.dirname(os.path.abspath(__file__))
CHARS = "".join(chr(c) for c in range(33, 33 + 40) if chr(c) != '.')

for name in ORDER:
    ramp = [A[c] for c in RAMPS[name]]
    frames = [BUILDERS[name](f) for f in range(NF)]
    used = sorted({max(0, min(len(ramp) - 1, l)) for fr in frames for l in fr.values()})
    idx = {lvl: i for i, lvl in enumerate(used)}
    out = [f"PALETTE {len(used)}"]
    for lvl in used:
        r, g, b = ramp[lvl]
        out.append("%02X%02X%02X" % (r, g, b))
    out.append(f"SIZE {FW} {FH}")
    out.append(f"FRAMES {NF}")
    for f, fr in enumerate(frames):
        out.append(f"FRAME {f}")
        for y in range(FH):
            row = []
            for x in range(FW):
                l = fr.get((x, y))
                row.append('.' if l is None else CHARS[idx[max(0, min(len(ramp) - 1, l))]])
            out.append("".join(row))
    io.open(os.path.join(HERE, name + ".txt"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(name, "levels", len(used))
