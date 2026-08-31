# -*- coding: utf-8 -*-
"""The simple round — flat colour, no fur texture. Same 64 px canvas as before."""
import os, time, requests
from PIL import Image


def get(url, tries=20):
    """423 Locked just means the job has not finished — wait it out rather than failing the run."""
    for _ in range(tries):
        r = requests.get(url, timeout=90)
        if r.status_code == 423:
            time.sleep(6)
            continue
        r.raise_for_status()
        return r
    raise RuntimeError("still locked: " + url)

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")
URL = "https://api.pixellab.ai/mcp/images/%s/download"

JOBS = {
    "s1_flat_grey": "da2fd710-1ef2-4d67-b729-5934f5cf2040",
    "s2_two_tone": "eb1a9eae-17f7-4dd8-bdb8-edc567ebed93",
    "s3_lineless": "33109dde-67e4-4ff7-ac41-34e09ef063d7",
    "s4_brown": "9b55e5ea-4d93-4b66-a850-9367b5fb7d19",
    "s5_blocky": "d8d63be0-6907-4947-95e9-f8c57c8df8fb",
    "s6_pale_belly": "951fcdc8-3516-430c-99a2-c54f79aa9349",
    "s7_cream": "bca66f8e-6f2b-4bce-b88b-3d7fbf3f25aa",
    "s8_minimal": "8b780d71-167b-4d6e-9c97-76655c597634",
}

for name, job in JOBS.items():
    r = get(URL % job)
    p = os.path.join(DST, name + ".png")
    with open(p, "wb") as f:
        f.write(r.content)
    im = Image.open(p).convert("RGBA")
    bb = im.getbbox()
    # how many distinct colours survived — the whole point of this round
    cols = len({px[:3] for px in im.getdata() if px[3] > 128})
    print("%-14s ink %2dx%2d  %3d colours" % (name, bb[2] - bb[0], bb[3] - bb[1], cols))
