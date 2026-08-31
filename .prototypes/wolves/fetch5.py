# -*- coding: utf-8 -*-
"""The grey round — and a check that throws out the ones with ground stuck to them.

⚠⚠ **「no ground」 IN THE PROMPT IS NOT ENOUGH.** Three of the last twelve came back with a patch of
orange dirt or a painted shadow blob under the paws, and on a billboard that patch is drawn as part
of the animal — it slides over the grass and sits on top of the disc the game already draws.

The check is measurable rather than a judgement: **a wolf's bottom rows are PAWS, which are a few
narrow runs with gaps between them.** Ground is one wide unbroken run. So the widest continuous run
of opaque pixels in the bottom rows, as a fraction of the animal's own width, separates them.
"""
import os, time, requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")
URL = "https://api.pixellab.ai/mcp/images/%s/download"

JOBS = {
    "g1_black_line": "bfd60325-c0e4-425b-89ed-d725018ee944",
    "g2_selective": "0de7b806-249f-4cc4-b92b-9d23343965fd",
    "g3_few_colours": "cb39b06e-731c-4788-9122-2489cfeaa59a",
    "g4_dark_back": "97bcc785-c4a5-468c-a649-be8a50265a94",
    "g5_two_greys": "17c76351-218c-4399-a685-499d93a12b63",
    "g6_white_chest": "e4693073-b4d1-4b78-a685-f55a9f163c85",
    "g7_three_tones": "8289f0c4-8690-45c4-bc0f-15d667eac444",
    "g8_pale_legs": "985dc09a-a58d-43cb-8d0a-216e120dc330",
}

BOTTOM_ROWS = 4
GROUND_AT = 0.62      # widest bottom run this wide, or wider, is ground and not paws


def get(url, tries=30):
    for _ in range(tries):
        r = requests.get(url, timeout=90)
        if r.status_code == 423:
            time.sleep(6)
            continue
        r.raise_for_status()
        return r
    raise RuntimeError("still locked: " + url)


def widest_bottom_run(im):
    bb = im.getbbox()
    ink_w = bb[2] - bb[0]
    worst = 0
    for y in range(bb[3] - BOTTOM_ROWS, bb[3]):
        run = 0
        for x in range(bb[0], bb[2]):
            if im.getpixel((x, y))[3] > 128:
                run += 1
                worst = max(worst, run)
            else:
                run = 0
    return worst / ink_w, ink_w


kept, tossed = [], []
for name, job in JOBS.items():
    r = get(URL % job)
    p = os.path.join(DST, name + ".png")
    with open(p, "wb") as f:
        f.write(r.content)
    im = Image.open(p).convert("RGBA")
    frac, ink_w = widest_bottom_run(im)
    ok = frac < GROUND_AT
    (kept if ok else tossed).append(name)
    print("%-16s ink %2d wide   bottom run %4.0f%%   %s"
          % (name, ink_w, frac * 100, "paws" if ok else "GROUND — tossed"))

print("\nkept  : %s" % ", ".join(kept))
print("tossed: %s" % (", ".join(tossed) if tossed else "none"))
