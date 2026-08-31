# -*- coding: utf-8 -*-
"""Move this session's pulls into `.candidates/wolf/`, where nothing is ever deleted.

⚠ `.prototypes/` throws its losers away and `.candidates/` never does — the two folders disagree on
purpose, and this script is the bridge between them. Every candidate pulled tonight goes across,
winner and loser alike, under the date it was pulled.

⚠ The pixen tool does not hand back a seed, so the job id is written into a sidecar instead: that is
what makes the same picture reachable again.
"""
import os, glob, shutil, json

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "pics_fit")
DST = os.path.join(HERE, "..", "..", ".candidates", "wolf")
DATE = "2026-08-31"

JOB_IDS = {
    "c04": "e04d3f53-2ab1-4238-8fa3-9f9407e1d4be (pixen, the 128 px round)",
    "b01_black_line": "456e97b2-e96a-474d-b3fc-d42dadabe0bc",
    "b02_selective": "d469a3d2-2c9b-45c1-b3ea-d4a490154295",
    "b03_lineless": "aea41ded-9a2d-454f-91e7-c4cb08170ce9",
    "b04_pale_chest": "db0e6e69-5f57-4d6d-81a6-b2cf52ce17ab",
    "b05_brown": "e62d9ea2-6cf0-4c37-a24f-effe484abbae",
    "b06_medium": "c55000a9-51e6-4119-b43e-522c610963bc",
    "b07_black": "a0f4e4ea-481a-4eee-bdc5-eb79b4b54afe",
    "b08_ruff": "0876f013-7e0e-440c-b5e5-f557fd5968cf",
    "s1_flat_grey": "da2fd710-1ef2-4d67-b729-5934f5cf2040",
    "s2_two_tone": "eb1a9eae-17f7-4dd8-bdb8-edc567ebed93",
    "s3_lineless": "33109dde-67e4-4ff7-ac41-34e09ef063d7",
    "s4_brown": "9b55e5ea-4d93-4b66-a850-9367b5fb7d19",
    "s5_blocky": "d8d63be0-6907-4947-95e9-f8c57c8df8fb",
    "s6_pale_belly": "951fcdc8-3516-430c-99a2-c54f79aa9349",
    "s7_cream": "bca66f8e-6f2b-4bce-b88b-3d7fbf3f25aa",
    "s8_minimal": "8b780d71-167b-4d6e-9c97-76655c597634",
    "c01_light_grey": "de397530-61ea-48bd-8cb6-11256db6418e",
    "c02_white": "b44e14a4-6fc7-4721-9f06-b6a1291ff98c",
    "c03_black": "4cbd3ad2-e17a-4540-a117-8dbcd60f6ac9",
    "c04_brown": "592ca8cb-e1f2-48e0-a4fa-3f7024283f41",
    "c05_rust": "43139473-54e1-4346-9c0f-1b3bec055bbe",
    "c06_tan": "aacd52e4-6200-4913-9c85-311bb056ebba",
    "c07_slate": "bba1bde0-7c5f-4daf-8563-81e1761bb234",
    "c08_silver": "3a0b701d-3251-4993-ac51-60b27b068726",
    "c09_cream": "de10207a-771f-4936-8e4e-6641fd6a9155",
    "c10_chocolate": "36c34b92-d480-4bfb-9669-777798cf2e3d",
    "c11_charcoal": "78479d75-9ba0-4493-aca7-e2b08b163a68",
    "c12_ash": "196371e2-ef5e-4b9f-9cf2-a5a9429a9e84",
    "g1_black_line": "bfd60325-c0e4-425b-89ed-d725018ee944",
    "g2_selective": "0de7b806-249f-4cc4-b92b-9d23343965fd",
    "g3_few_colours": "cb39b06e-731c-4788-9122-2489cfeaa59a",
    "g4_dark_back": "97bcc785-c4a5-468c-a649-be8a50265a94",
    "g5_two_greys": "17c76351-218c-4399-a685-499d93a12b63  <- CHOSEN, rotated as "
                    "35a190ca-ef0a-4894-bf46-ea5820777ec1",
    "g6_white_chest": "e4693073-b4d1-4b78-a685-f55a9f163c85",
    "g7_three_tones": "8289f0c4-8690-45c4-bc0f-15d667eac444",
    "g8_pale_legs": "985dc09a-a58d-43cb-8d0a-216e120dc330",
}

moved = 0
for p in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    name = os.path.splitext(os.path.basename(p))[0]
    if name == "now":
        continue                      # the shipped wolf padded for the control — not a candidate
    shutil.copyfile(p, os.path.join(DST, "%s-%s.png" % (DATE, name)))
    moved += 1

with open(os.path.join(DST, "%s-job-ids.md" % DATE), "w", encoding="utf-8") as f:
    f.write("# 2026-08-31 night — pixellab job ids for that evening's wolf pulls\n\n")
    f.write("The pixen tool returns no seed, so the job id is the handle: it is what fetches the\n"
            "exact picture again from `https://api.pixellab.ai/mcp/images/<id>/download`.\n\n")
    for k in sorted(JOB_IDS):
        f.write("- `%s` — %s\n" % (k, JOB_IDS[k]))

print("copied %d candidates into .candidates/wolf/" % moved)
