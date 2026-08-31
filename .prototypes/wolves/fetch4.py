# -*- coding: utf-8 -*-
"""The colourful round — twelve coats, one flat style, the same 64 px canvas."""
import os, time, requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(HERE, "pics_fit")
URL = "https://api.pixellab.ai/mcp/images/%s/download"

JOBS = {
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
}


def get(url, tries=30):
    """423 Locked just means the job has not finished — wait it out rather than failing the run."""
    for _ in range(tries):
        r = requests.get(url, timeout=90)
        if r.status_code == 423:
            time.sleep(6)
            continue
        r.raise_for_status()
        return r
    raise RuntimeError("still locked: " + url)


for name, job in JOBS.items():
    r = get(URL % job)
    p = os.path.join(DST, name + ".png")
    with open(p, "wb") as f:
        f.write(r.content)
    im = Image.open(p).convert("RGBA")
    bb = im.getbbox()
    print("%-16s ink %2dx%2d" % (name, bb[2] - bb[0], bb[3] - bb[1]))
