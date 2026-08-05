"""진을 그린다 — AI가 아니라 코드로.

🔴🔴 **단순한 기하학은 뽑지 말고 그린다**(2026-08-05, 사용자 판정
「그냥 원이라고. 그냥 문양을 넣을 수 있는 층만 있으라는 거잖아」).

⚠ **AI 생성이 이걸 못 한다.** 「장식 없이 원 세 개」를 요구해도 매번 다른 것이 나오고,
소켓 크기·띠 반지름이 규격(368 · 288 · 192)과 안 맞는다 — 네 판을 돌려도 안 맞았다.
⇒ 그림이 필요한 것은 **무늬**(문양 링 · 룬 심볼)뿐이고, **틀은 좌표다.**

🔴 규격의 기준은 `docs/design/마법진-그림.md` 다. 여기는 그 값을 쓰는 코드다.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).parent / "out" / "drawn"
S = 1024
SS = 4  # 수퍼샘플 배율. ⚠ PIL 의 ellipse 는 안티앨리어싱을 안 해서 이게 없으면 계단이 진다
BG = (250, 248, 240)   # 크림 종이
FG = (26, 24, 22)      # 검정

W_OUTER = 10   # 바깥 링 굵기
W_DIV = 4      # 층을 가르는 나눔선
W_SOCKET = 7   # 소켓 테두리


def circ(d, p, r, w):
    """점 p 를 중심으로 한 원. 좌표는 이미 SS 배율이다."""
    x, y = p
    d.ellipse([x - r, y - r, x + r, y + r], outline=FG, width=w * SS)


def disc(d, p, r, color):
    """꽉 찬 원. 🔴 **연결 띠를 소켓 안에서 지우는 데 쓴다** — 띠를 먼저 긋고
    소켓 자리를 배경색으로 덮은 뒤 링을 다시 그리면 선이 소켓을 안 침범한다."""
    x, y = p
    d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def band(d, a, b, half_w, w):
    """두 점을 **두 줄 평행선**으로 잇는다. 채용안의 연결이 한 줄이 아니라 띠다."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * half_w, dx / L * half_w
    for s in (1, -1):
        d.line([ax + nx * s, ay + ny * s, bx + nx * s, by + ny * s], fill=FG, width=w * SS)


def at(angle_deg, dist):
    """진 중심에서 각도·거리로 잡은 점 (SS 배율 좌표)."""
    c = S * SS / 2
    a = math.radians(angle_deg)
    return c + math.cos(a) * dist * SS, c + math.sin(a) * dist * SS


def ring(d, r, w):
    circ(d, at(0, 0), r * SS, w)


def socket(d, angle_deg, dist, r, w=W_SOCKET):
    """진 중심에서 `dist` 만큼 떨어진 자리에 지름 2r 의 빈 소켓."""
    circ(d, at(angle_deg, dist), r * SS, w)


def new():
    im = Image.new("RGB", (S * SS, S * SS), BG)
    return im, ImageDraw.Draw(im)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / f"{name}.png"
    im.resize((S, S), Image.LANCZOS).save(p)
    print(p)


# ─── 일반진 — 룬 1자리 · 통합 2층 ──────────────────────────────────
# 바깥 링 하나, 그 안에 층 띠 둘. 🔴 **띠 안은 비운다** — 문양이 거기 들어간다.
def plain(layers=2, band_out=480, band_in=210, socket_r=96):
    im, d = new()
    ring(d, 506, W_OUTER)          # 바깥 링
    ring(d, band_out, W_DIV)       # 띠 바깥 경계
    for k in range(1, layers):     # 층 사이 나눔선
        ring(d, band_out - (band_out - band_in) * k / layers, W_DIV)
    ring(d, band_in, W_DIV)        # 띠 안쪽 경계
    socket(d, 0, 0, socket_r)      # 룬 소켓 — 가운데
    return im


# ─── 융합진 — 룬 2자리 · 통합 1층 ─────────────────────────────────
def fusion(band_out=480, band_in=300, socket_r=96):
    im, d = new()
    ring(d, 506, W_OUTER)
    ring(d, band_out, W_DIV)
    ring(d, band_in, W_DIV)
    for ang in (180, 0):           # 좌 · 우
        socket(d, ang, 110, socket_r)
    return im


# ─── 삼각진 — 룬 3자리 · 룬마다 1층 ───────────────────────────────
# 🔴 소켓마다 띠가 하나씩. 가운데는 장식(문양이 아니다).
def triangle(socket_r=144, band_gap=34, dist=368, center_r=112, link_half=26,
             ring_r=420):
    """🔴🔴 **이 기본값이 사용자가 확정한 삼각진이다** (2026-08-05, 「4번 너무 잘나왔다 이걸로 확정」).
    ⚠ **인자를 바꾸면 확정된 그림이 아니다.** 다른 값이 필요하면 호출할 때 넘겨라.

    🔴 `ring_r` 이 삼각진을 감싸는 바깥 링이다.

    ⚠ **소켓이 이 링을 넘치는 것이 요점이다**(2026-08-05, 사용자 요청 「삼각형이 링을 넘치게」).
     `dist + socket_r > ring_r` 이면 넘치고, 소켓을 **링보다 나중에** 그려서 링을 덮는다 —
     순서를 바꾸면 링이 소켓 위를 지나가 「뚫고 나온다」가 「겹쳐 있다」로 읽힌다.
    """
    im, d = new()
    pts = [at(ang, dist) for ang in (-90, 30, 150)]   # 12시 · 4시 · 8시

    # ① 연결 띠를 **먼저** 긋는다. 소켓 셋을 서로 잇는 삼각 변이다.
    for i in range(3):
        band(d, pts[i], pts[(i + 1) % 3], link_half * SS, W_DIV)

    # ② 감싸는 링
    if ring_r:
        ring(d, ring_r, W_OUTER)

    # ③ 소켓 자리를 배경으로 덮고 링을 다시 그린다 ⇒ 띠도 바깥 링도 소켓 안으로 안 들어간다
    for p in pts:
        disc(d, p, socket_r * SS, BG)
        circ(d, p, socket_r * SS, W_OUTER)                 # 소켓 바깥 테두리
        circ(d, p, (socket_r - band_gap) * SS, W_DIV)      # 문양 띠 안쪽 경계

    # ③ 가운데 장식 — 🔴 문양이 아니다(룬마다 1층이라 가운데에 층이 없다)
    ctr = at(0, 0)
    disc(d, ctr, center_r * SS, BG)
    circ(d, ctr, center_r * SS, W_OUTER)
    circ(d, ctr, (center_r - band_gap) * SS, W_DIV)
    return im


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "plain"):
        save(plain(), "plain")
    if which in ("all", "fusion"):
        save(fusion(), "fusion")
    if which in ("all", "triangle"):
        save(triangle(), "triangle")
