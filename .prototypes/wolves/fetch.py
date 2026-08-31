# -*- coding: utf-8 -*-
"""Pull the shortlisted candidates down beside the runner.

`.prototypes/` is not imported by Godot, so these PNGs are read with
Image.load at an absolute path — never with load("res://...").
"""
import os, requests

JOB = "7ec9455a-84a3-46af-9046-1469caa1663d"
URL = "https://api.pixellab.ai/mcp/images/%s/download?index=%d"
HERE = os.path.dirname(os.path.abspath(__file__))

# Chosen for the spread that decides at 42 px: how far the back is from the
# chest, and how light the animal sits against the stage's near-black.
PICKS = {"c04": 3, "c09": 8, "c10": 9, "c13": 12, "c15": 14}

for name, idx in PICKS.items():
    r = requests.get(URL % (JOB, idx), timeout=90)
    r.raise_for_status()
    out = os.path.join(HERE, "pics", name + ".png")
    with open(out, "wb") as f:
        f.write(r.content)
    print("wrote", out, len(r.content), "bytes")
