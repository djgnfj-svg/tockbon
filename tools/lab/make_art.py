"""실험대가 쓰는 자리표시 그림을 만든다. 의존성 없음 — 표준 라이브러리만.

    python tools/lab/make_art.py

⚠ 이 그림들은 게임에 안 들어간다. 실험대에서 기법을 눈으로 보려고 세워 둔 자리표시다.
   게임에 들어가는 것은 블렌더나 픽셀 도구로 만든다 — CLAUDE.md 의 규칙.

⚠ 음영을 안 넣는다. 이 게임의 그림은 단색이다 (2026-08-29, 사용자: 「그림에 음영이 없어」).
"""

import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "art")

CLEAR = (0, 0, 0, 0)
INK = (28, 26, 32, 255)          # 외곽선. 거의 검정
SKIN = (232, 198, 164, 255)
BLUE = (86, 132, 178, 255)       # 플레이어
BLUE_D = (58, 94, 132, 255)
GREY = (128, 126, 130, 255)      # 짐승
GREY_D = (92, 90, 96, 255)
WHITE = (244, 244, 238, 255)
SPARK = (255, 226, 150, 255)


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    head = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)   # 8비트 RGBA
    blob = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head)
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(blob)
    return len(blob)


def blank(w, h):
    return [[CLEAR for _ in range(w)] for _ in range(h)]


def fill_rect(img, x0, y0, x1, y1, col):
    for y in range(max(0, y0), min(len(img), y1)):
        for x in range(max(0, x0), min(len(img[0]), x1)):
            img[y][x] = col


def fill_disc(img, cx, cy, r, col):
    for y in range(len(img)):
        for x in range(len(img[0])):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                img[y][x] = col


def ring(img, cx, cy, r_out, r_in, col):
    for y in range(len(img)):
        for x in range(len(img[0])):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if r_in * r_in <= d <= r_out * r_out:
                img[y][x] = col


def outline(img, col=INK):
    """칠해진 자리의 바깥 테두리를 한 픽셀 두른다."""
    h, w = len(img), len(img[0])
    out = [row[:] for row in img]
    for y in range(h):
        for x in range(w):
            if img[y][x][3] != 0:
                continue
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and img[ny][nx][3] != 0:
                    out[y][x] = col
                    break
    return out


# --- 몸 -------------------------------------------------------------------
# 24 x 40. 한 조각이 40 픽셀이므로 키가 딱 한 조각이다.
# ⚠ 위아래가 분명해야 한다. 빌보드 축을 틀리면 이 그림이 눕는 게 보여야 하기 때문이다.

def body(front=True, side=False):
    img = blank(24, 40)
    fill_rect(img, 8, 30, 11, 39, BLUE_D)          # 왼다리
    fill_rect(img, 13, 30, 16, 39, BLUE_D)         # 오른다리
    if side:
        fill_rect(img, 9, 16, 16, 31, BLUE)        # 몸통 (옆은 좁다)
        fill_rect(img, 16, 18, 20, 21, SKIN)       # 앞으로 뻗은 팔
    else:
        fill_rect(img, 7, 16, 18, 31, BLUE)        # 몸통
        fill_rect(img, 4, 17, 7, 27, SKIN)         # 왼팔
        fill_rect(img, 18, 17, 21, 27, SKIN)       # 오른팔
    fill_disc(img, 12, 10, 6, SKIN)                # 머리
    fill_rect(img, 5, 4, 19, 8, BLUE_D)            # 투구 — 실루엣을 정하는 것
    if front:
        img[9][9] = INK                            # 눈 둘
        img[9][14] = INK
    return outline(img)


# --- 짐승 -----------------------------------------------------------------
def beast():
    img = blank(34, 22)
    fill_rect(img, 6, 6, 26, 15, GREY)             # 몸통
    fill_rect(img, 24, 3, 32, 11, GREY)            # 머리
    fill_rect(img, 30, 6, 33, 9, GREY_D)           # 주둥이
    fill_rect(img, 7, 15, 10, 21, GREY_D)          # 다리 넷
    fill_rect(img, 12, 15, 15, 21, GREY_D)
    fill_rect(img, 18, 15, 21, 21, GREY_D)
    fill_rect(img, 23, 15, 26, 21, GREY_D)
    fill_rect(img, 1, 4, 7, 7, GREY_D)             # 꼬리
    fill_rect(img, 25, 0, 27, 4, GREY_D)           # 귀
    img[6][29] = INK                               # 눈
    return outline(img)


# --- 효과 -----------------------------------------------------------------
def spark():
    img = blank(8, 8)
    for y in range(8):
        for x in range(8):
            if abs(x - 3.5) + abs(y - 3.5) <= 3.2:
                img[y][x] = SPARK
    return img


def dot():
    img = blank(8, 8)
    fill_disc(img, 3.5, 3.5, 2.6, WHITE)
    return img


def selection_ring():
    img = blank(40, 40)
    ring(img, 19.5, 19.5, 18.5, 15.0, WHITE)
    return img


def click_mark():
    img = blank(40, 40)
    ring(img, 19.5, 19.5, 18.5, 14.0, SPARK)
    fill_rect(img, 18, 18, 22, 22, SPARK)
    return img


def slash():
    """때린 자리에 뜨는 호 하나."""
    img = blank(40, 40)
    ring(img, 6.0, 20.0, 30.0, 25.0, WHITE)
    for y in range(40):                            # 위아래를 잘라 호로 만든다
        for x in range(40):
            if y < 6 or y > 33:
                img[y][x] = CLEAR
    return img


PIECES = [
    ("body_front.png", lambda: body(front=True)),
    ("body_back.png", lambda: body(front=False)),
    ("body_side.png", lambda: body(front=False, side=True)),
    ("beast.png", beast),
    ("spark.png", spark),
    ("dot.png", dot),
    ("ring.png", selection_ring),
    ("click.png", click_mark),
    ("slash.png", slash),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in PIECES:
        img = fn()
        size = write_png(os.path.join(OUT, name), len(img[0]), len(img), img)
        print("  %-16s %2d x %2d   %5d 바이트" % (name, len(img[0]), len(img), size))
    print("\n%d 장을 %s 에 썼다." % (len(PIECES), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
