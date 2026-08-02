# -*- coding: utf-8 -*-
"""탁본 마법 볼 6종 스프라이트 시트 생성기 v1.

- 프레임 92x48 x 6 = 552x48 가로 스트립
- 실루엣 56x28, 머리 중심 = 프레임 (74, 24) = 히트박스 중심 (RADIUS_PX 12 / SPRITE_FRAME_RADIUS 14)
- Apollo 46색만, 알파는 0 아니면 255 (하드 엣지)
- 룬마다 실루엣이 다르다: 혜성 / 물방울 / 빈 소용돌이 / 지그재그 선 / 각진 돌 / 잎다발
"""
import math, os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))

# ── Apollo 46 (assets/aseprite/apollo.gpl) ─────────────────────────────────
A = {
    "b0": (23, 32, 56),    "b1": (37, 58, 94),   "b2": (60, 94, 139),
    "b3": (79, 143, 186),  "b4": (115, 190, 211), "b5": (164, 221, 219),
    "g0": (25, 51, 45),    "g1": (37, 86, 46),   "g2": (70, 130, 50),
    "g3": (117, 167, 67),  "g4": (168, 202, 88), "g5": (208, 218, 145),
    "t0": (77, 43, 50),    "t1": (122, 72, 65),  "t2": (173, 119, 87),
    "t3": (192, 148, 115), "t4": (215, 181, 148), "t5": (231, 213, 179),
    "o0": (52, 28, 39),    "o1": (96, 44, 44),   "o2": (136, 75, 43),
    "o3": (190, 119, 43),  "o4": (222, 158, 65), "o5": (232, 193, 112),
    "r0": (36, 21, 39),    "r1": (65, 29, 49),   "r2": (117, 36, 56),
    "r3": (165, 48, 48),   "r4": (207, 87, 60),  "r5": (218, 134, 62),
    "p0": (30, 29, 57),    "p1": (64, 39, 81),   "p2": (122, 54, 123),
    "p3": (162, 62, 140),  "p4": (198, 81, 151), "p5": (223, 132, 165),
    "n0": (9, 10, 20),     "n1": (16, 20, 31),   "n2": (21, 29, 40),
    "n3": (32, 46, 55),    "n4": (57, 74, 80),   "n5": (87, 114, 119),
    "n6": (129, 151, 150), "n7": (168, 181, 178), "n8": (199, 207, 204),
    "n9": (235, 237, 233),
}

FW, FH, NF = 92, 48, 6
CX, CY = 74.0, 24.0          # 머리 중심 = 히트박스 중심 (프레임 좌표)

# ── 램프: index 0 = 가장 밝은 코어, 마지막 = 가장 어두운 테두리 ──────────────
RAMPS = {
    "fireball":  ["n9", "o5", "o4", "r5", "r4", "r3", "r2", "o0"],
    "waterball": ["n9", "n8", "b5", "b4", "b3", "b2", "b1", "b0"],
    "windball":  ["n9", "n8", "b5", "n7", "b4", "n6", "n5", "n4"],
    "boltball":  ["n9", "g5", "o5", "o4", "o3", "o2", "o0", "r0"],
    "earthball": ["t5", "t4", "t3", "t2", "o3", "t1", "t0", "o0"],
    "grassball": ["t5", "g5", "g4", "g3", "g2", "g1", "g0", "g0"],
}


def put(lv, x, y, level):
    """레벨 맵에 찍는다 — 더 밝은(작은) 레벨이 이긴다."""
    if 0 <= x < FW and 0 <= y < FH:
        cur = lv.get((x, y))
        if cur is None or level < cur:
            lv[(x, y)] = level


def rim(lv, dark, only_outer=True):
    """실루엣 가장자리를 한 단계 어둡게 — 균일 검정이 아니라 색 외곽선."""
    edge = []
    for (x, y), l in lv.items():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in lv:
                edge.append((x, y, l))
                break
    for x, y, l in edge:
        lv[(x, y)] = dark if only_outer else max(l, dark)


def outline(lv, level):
    """실루엣 바깥으로 1px 윤곽을 두른다 (잔디 배경 대비용)."""
    add = {}
    for (x, y) in lv.keys():
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in lv and 0 <= p[0] < FW and 0 <= p[1] < FH:
                    add[p] = level
    lv.update(add)


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / L2))
    dx, dy = wx - t * vx, wy - t * vy
    return math.hypot(dx, dy)


def poly_dist(px, py, pts):
    return min(seg_dist(px, py, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
               for i in range(len(pts) - 1))


def in_poly(px, py, pts):
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]; xj, yj = pts[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


# ══════════════════════════════════════════════════════════════════════════
# 불 — 꼬리 긴 혜성 + 둥근 머리
# ══════════════════════════════════════════════════════════════════════════
def fireball(f):
    lv = {}
    ph = f / float(NF) * 2 * math.pi
    R = 11.6

    # 꼬리: 굵기가 머리 쪽에서 넓고 끝으로 갈수록 얇아지는 물결 스파인 3가닥
    strands = [
        (0.0, 9.0, 30.0, 3.4, 1.00),      # 본류
        (2.1, 5.0, 40.0, 4.6, 0.72),      # 위 갈래
        (4.2, 4.4, 36.0, -4.2, 0.66),     # 아래 갈래
    ]
    for sph, tw, wl, amp, reach in strands:
        x_end = CX - 43.0 * reach
        for x in range(int(x_end), int(CX + 4)):
            u = (x + 0.5 - x_end) / (CX + 2 - x_end)
            if u <= 0:
                continue
            spine = CY + amp * math.sin(2 * math.pi * (x - CX) / wl + ph + sph) * (1.0 - u * 0.55)
            half = tw * (u ** 0.85) * 0.5
            if half < 0.5:
                continue
            for y in range(int(spine - half), int(spine + half) + 1):
                d = abs(y + 0.5 - spine)
                if d > half:
                    continue
                heat = u * u                       # 머리에 가까울수록 뜨겁다
                core = 1.0 - (d / max(half, 0.6))  # 스파인 중심일수록 뜨겁다
                s = heat * 0.75 + core * 0.35
                level = 6 - int(s * 5.4)
                put(lv, x, y, max(1, min(6, level)))

    # 떨어져 나간 불티 (2x2 이상 — 낱픽셀 노이즈 금지)
    for i, (ex, ey, es) in enumerate([(-46, -6, 2), (-41, 5, 2), (-50, 1, 2)]):
        ox = int(CX + ex + 3 * math.sin(ph + i * 2.0))
        oy = int(CY + ey + 2 * math.cos(ph * 1.3 + i))
        for dx in range(es):
            for dy in range(es):
                put(lv, ox + dx, oy + dy, 5 if i else 4)

    # 머리: 둥근 구 — 안쪽 링만 프레임마다 맥동(실루엣은 고정 = 팝핑 없음)
    pulse = 0.9 * math.sin(ph)
    for y in range(int(CY - R - 1), int(CY + R + 2)):
        for x in range(int(CX - R - 1), int(CX + R + 2)):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            d = math.hypot(dx, dy * 1.02)
            if d > R:
                continue
            if d < 3.1 + pulse:
                level = 0
            elif d < 5.4 + pulse:
                level = 1
            elif d < 7.4:
                level = 2
            elif d < 9.2:
                level = 3
            elif d < 10.6:
                level = 4
            else:
                level = 5
            put(lv, x, y, level)

    rim(lv, 7)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 물 — 둥근 물방울 덩어리 + 뒤에 방울 부스러기
# ══════════════════════════════════════════════════════════════════════════
def waterball(f):
    lv = {}
    ph = f / float(NF) * 2 * math.pi
    wob = math.sin(ph)
    rx, ry = 11.4 + 0.9 * wob, 11.4 - 0.9 * wob

    # 덩어리: 앞은 둥글고 뒤로 살짝 뾰족한 물방울
    for y in range(int(CY - ry - 2), int(CY + ry + 3)):
        for x in range(int(CX - rx - 8), int(CX + rx + 2)):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            k = 1.0 if dx >= 0 else 1.0 + 0.30 * (-dx / rx) ** 2   # 뒤쪽만 늘여 물방울 꼬리
            d = math.hypot(dx / (rx * k), dy / ry)
            if d > 1.0:
                continue
            if d < 0.42:
                level = 3
            elif d < 0.66:
                level = 4
            elif d < 0.86:
                level = 5
            else:
                level = 6
            put(lv, x, y, level)

    # 표면 하이라이트 2점 (좌상단 광원)
    hx, hy = CX - 4.6, CY - 5.2
    for y in range(int(hy - 3), int(hy + 4)):
        for x in range(int(hx - 4), int(hx + 5)):
            d = math.hypot((x + 0.5 - hx) / 3.3, (y + 0.5 - hy) / 2.2)
            if d < 1.0 and (x, y) in lv:
                put(lv, x, y, 0 if d < 0.5 else 1)
    for y in range(int(CY + 2), int(CY + 5)):
        for x in range(int(CX - 9), int(CX - 5)):
            d = math.hypot((x + 0.5 - (CX - 7.2)) / 2.0, (y + 0.5 - (CY + 3.2)) / 1.2)
            if d < 1.0 and (x, y) in lv:
                put(lv, x, y, 2)

    # 아랫배 그늘
    for (x, y) in list(lv.keys()):
        dx, dy = x + 0.5 - CX, y + 0.5 - CY
        if dy > 4.5 and math.hypot(dx / rx, dy / ry) > 0.55 and lv[(x, y)] >= 4:
            lv[(x, y)] = 6

    rim(lv, 7)

    # 뒤에 흩어진 방울 부스러기 (덩어리 뒤 — 자기 테두리를 갖는다)
    drops = [(-20, -7, 3.0), (-27, 3, 2.6), (-34, -3, 2.2), (-41, 5, 1.9), (-45, -6, 1.7)]
    for i, (ex, ey, dr) in enumerate(drops):
        ox = CX + ex - 2.0 * math.sin(ph + i * 1.1)
        oy = CY + ey + 1.6 * math.sin(ph * 1.4 + i * 2.0)
        sub = {}
        for y in range(int(oy - dr - 1), int(oy + dr + 2)):
            for x in range(int(ox - dr - 1), int(ox + dr + 2)):
                d = math.hypot(x + 0.5 - ox, y + 0.5 - oy)
                if d <= dr:
                    sub[(x, y)] = 3 if d < dr * 0.45 else 5
        rim(sub, 7)
        for p, l in sub.items():
            put(lv, p[0], p[1], l)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 바람 — 속이 빈 열린 소용돌이 (가운데가 뚫려 있는 게 다른 다섯과 가르는 축)
# ══════════════════════════════════════════════════════════════════════════
def windball(f):
    lv = {}
    spin = f / float(NF) * 2 * math.pi

    def arc(cx, cy, r_in, r_out, a0, a1, taper=True, lvl_base=2):
        for y in range(int(cy - r_out - 2), int(cy + r_out + 3)):
            for x in range(int(cx - r_out - 2), int(cx + r_out + 3)):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                while a < a0:
                    a += 2 * math.pi
                if a > a1:
                    continue
                t = (a - a0) / (a1 - a0)
                # 끝으로 갈수록 얇아지는 띠
                w = (r_out - r_in) * (1.0 if not taper else (0.35 + 0.65 * math.sin(math.pi * t) ** 0.6))
                mid = (r_in + r_out) * 0.5
                if abs(d - mid) > w * 0.5:
                    continue
                edge = abs(d - mid) / max(w * 0.5, 0.5)
                lvl = lvl_base + int(edge * 2.2) + int(t * 1.6)
                put(lv, x, y, max(0, min(6, lvl)))

    # 바깥 소용돌이 — 앞쪽이 열린 C. 가운데는 비운다.
    arc(CX, CY, 8.6, 13.0, spin - 0.35, spin + 4.55, lvl_base=1)
    # 안쪽 소용돌이 — 반대편에서 시작해 안으로 말린다
    arc(CX + 0.5, CY, 3.6, 7.0, spin + 2.4, spin + 6.2, lvl_base=2)
    # 코어 근처 밝은 짧은 호 (회오리 눈)
    arc(CX + 0.5, CY, 1.4, 3.2, spin + 3.6, spin + 5.4, taper=False, lvl_base=0)

    # 뒤로 흘리는 바람 자락 3줄 (초승달 슬리버)
    for i, (ox, oy, rr, a0, a1, lb) in enumerate([
            (CX - 21, CY - 5, 12.0, 5.05, 6.30, 2),
            (CX - 30, CY + 4, 13.5, 0.10, 1.25, 3),
            (CX - 40, CY - 3, 11.0, 5.30, 6.15, 4)]):
        sh = 1.6 * math.sin(spin + i * 1.7)
        for y in range(int(oy - rr - 2), int(oy + rr + 3)):
            for x in range(int(ox - rr - 2), int(ox + rr + 3)):
                dx, dy = x + 0.5 - ox, y + 0.5 - oy + sh
                d = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                while a < a0:
                    a += 2 * math.pi
                if a > a1:
                    continue
                t = (a - a0) / (a1 - a0)
                w = 1.1 + 1.5 * math.sin(math.pi * t)
                if abs(d - rr) > w:
                    continue
                put(lv, x, y, min(6, lb + int(abs(d - rr) / max(w, 0.5) * 2)))

    rim(lv, 7)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 번개 — 구체 없는 각진 지그재그 선
# ══════════════════════════════════════════════════════════════════════════
BOLT_PATHS = [
    [(31, 21), (41, 12), (48, 25), (59, 14), (67, 27), (77, 18), (86, 24)],
    [(31, 27), (40, 17), (50, 28), (58, 13), (69, 23), (76, 12), (86, 22)],
    [(32, 14), (42, 26), (51, 13), (61, 26), (70, 15), (78, 26), (86, 20)],
    [(31, 24), (39, 12), (49, 22), (58, 11), (68, 25), (78, 14), (86, 25)],
    [(31, 12), (41, 24), (49, 11), (60, 22), (68, 12), (77, 24), (86, 19)],
    [(32, 26), (43, 15), (52, 27), (62, 16), (71, 26), (79, 15), (86, 23)],
]
BOLT_FORKS = [
    [(59, 14), (63, 6), (67, 10)],
    [(58, 13), (52, 5), (55, 9)],
    [(61, 26), (66, 34), (63, 30)],
    [(58, 11), (64, 4), (61, 8)],
    [(60, 22), (54, 31), (58, 28)],
    [(62, 16), (57, 7), (61, 11)],
]


def boltball(f):
    lv = {}
    path = BOLT_PATHS[f]
    fork = BOLT_FORKS[f]
    for pts, wide in ((path, 1.0), (fork, 0.35)):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        for y in range(min(ys) - 4, max(ys) + 5):
            for x in range(min(xs) - 4, max(xs) + 5):
                d = poly_dist(x + 0.5, y + 0.5, pts)
                if d <= 0.95 * wide + 0.2:
                    put(lv, x, y, 0)
                elif d <= 1.85 * wide + 0.4:
                    put(lv, x, y, 1 if wide > 0.5 else 2)
                elif d <= 2.8 * wide + 0.5:
                    put(lv, x, y, 2 if wide > 0.5 else 3)
                elif d <= 3.7 * wide + 0.5:
                    put(lv, x, y, 4)

    # 앞 끝 충격점 — 구체가 아니라 각진 마름모 (여기가 히트박스 중심 쪽)
    tipx, tipy = 80.0, path[-1][1] * 0.35 + CY * 0.65
    for y in range(int(tipy) - 6, int(tipy) + 7):
        for x in range(int(tipx) - 6, int(tipx) + 7):
            m = abs(x + 0.5 - tipx) + abs(y + 0.5 - tipy)
            if m <= 2.2:
                put(lv, x, y, 0)
            elif m <= 3.8:
                put(lv, x, y, 1)
            elif m <= 5.2:
                put(lv, x, y, 3)

    rim(lv, 6)
    outline(lv, 7)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 흙 — 각진 돌덩어리, 프레임마다 회전 (광원은 좌상단 고정)
# ══════════════════════════════════════════════════════════════════════════
ROCK = [(0.15, 12.4), (0.85, 10.2), (1.45, 12.0), (2.25, 9.6), (2.95, 11.8),
        (3.70, 9.9), (4.30, 12.3), (5.05, 10.0), (5.70, 11.6)]
CRACKS = [[(0.9, 3.0), (2.2, 6.5), (3.9, 4.0)], [(4.6, 5.5), (5.6, 8.0)]]


def earthball(f):
    lv = {}
    rot = f / float(NF) * 2 * math.pi
    pts = [(CX + r * math.cos(a + rot), CY + r * math.sin(a + rot)) for a, r in ROCK]
    for y in range(int(CY - 14), int(CY + 15)):
        for x in range(int(CX - 14), int(CX + 15)):
            px, py = x + 0.5, y + 0.5
            if not in_poly(px, py, pts):
                continue
            edge = poly_dist(px, py, pts + [pts[0]])
            # 좌상단 고정 광원 + 4단 계단 음영 (면이 살아 보이게)
            shade = (-(px - CX) - (py - CY)) / 16.0 + 0.5
            band = int(max(0.0, min(3.99, shade * 4.0)))
            level = [4, 3, 2, 1][band]
            if edge < 1.3:
                level = min(6, level + 2)
            elif edge < 2.6:
                level = min(6, level + 1)
            put(lv, x, y, level)

    # 결(크랙) — 돌과 같이 돈다
    for cr in CRACKS:
        cpts = [(CX + r * math.cos(a + rot), CY + r * math.sin(a + rot)) for a, r in cr]
        for y in range(int(CY - 14), int(CY + 15)):
            for x in range(int(CX - 14), int(CX + 15)):
                if (x, y) not in lv:
                    continue
                if poly_dist(x + 0.5, y + 0.5, cpts) < 0.9:
                    lv[(x, y)] = 6

    rim(lv, 7)

    # 뒤로 흩날리는 자갈 + 흙먼지 (2px 이상 덩어리)
    grit = [(-19, -6, 3), (-25, 4, 2), (-32, -2, 3), (-39, 6, 2), (-43, -5, 2), (-48, 1, 2)]
    for i, (ex, ey, sz) in enumerate(grit):
        ox = int(CX + ex - 1.5 * math.sin(rot + i))
        oy = int(CY + ey + 1.5 * math.cos(rot * 1.2 + i * 1.7))
        sub = {}
        for dy in range(sz):
            for dx in range(sz):
                sub[(ox + dx, oy + dy)] = 3 if i % 2 == 0 else 4
        rim(sub, 7)
        for p, l in sub.items():
            put(lv, p[0], p[1], l)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 풀 — 잎·가시 다발 (잔디에 안 묻히게 어두운 윤곽)
# ══════════════════════════════════════════════════════════════════════════
LEAVES = [   # (각도, 길이, 반폭, 시작 반경)
    (-0.30, 14.0, 3.3, 1.0), (0.42, 13.0, 3.1, 1.0), (-1.15, 11.5, 2.7, 1.5),
    (1.25, 11.0, 2.6, 1.5), (2.55, 12.5, 3.0, 1.0), (-2.45, 11.5, 2.8, 1.0),
    (3.14, 10.0, 2.4, 2.0),
]
THORNS = [(-1.85, 11.0), (1.90, 10.5), (0.05, 12.5)]


def grassball(f):
    lv = {}
    ph = f / float(NF) * 2 * math.pi
    for i, (ang, L, hw, r0) in enumerate(LEAVES):
        a = ang + 0.16 * math.sin(ph + i * 0.9)
        ca, sa = math.cos(a), math.sin(a)
        bx, by = CX + r0 * ca, CY + r0 * sa
        for y in range(int(CY - 16), int(CY + 17)):
            for x in range(int(CX - 16), int(CX + 17)):
                px, py = x + 0.5 - bx, y + 0.5 - by
                u = px * ca + py * sa
                v = -px * sa + py * ca
                if u < 0 or u > L:
                    continue
                w = hw * math.sin(math.pi * (u / L)) ** 0.62
                if abs(v) > w:
                    continue
                # 잎맥 밝은 쪽(광원 위) / 아래 그늘
                edge = 1.0 - abs(v) / max(w, 0.4)
                lvl = 4 if v < -w * 0.25 else 5
                if edge > 0.72 and u < L * 0.72:
                    lvl = 3
                if u > L * 0.80:
                    lvl = 5
                put(lv, x, y, lvl)

    # 가시 — 뾰족한 삼각 (잎보다 밝은 끝)
    for i, (ang, L) in enumerate(THORNS):
        a = ang + 0.12 * math.sin(ph + i * 1.6)
        ca, sa = math.cos(a), math.sin(a)
        for y in range(int(CY - 16), int(CY + 17)):
            for x in range(int(CX - 16), int(CX + 17)):
                px, py = x + 0.5 - CX, y + 0.5 - CY
                u = px * ca + py * sa
                v = -px * sa + py * ca
                if u < 1.0 or u > L:
                    continue
                w = 2.0 * (1.0 - u / L)
                if abs(v) > w:
                    continue
                put(lv, x, y, 2 if u > L * 0.65 else 4)

    # 중심 씨앗 뭉치
    for y in range(int(CY - 4), int(CY + 5)):
        for x in range(int(CX - 4), int(CX + 5)):
            d = math.hypot(x + 0.5 - CX, y + 0.5 - CY)
            if d < 3.6:
                put(lv, x, y, 1 if d < 1.9 else 3)

    # 뒤로 날리는 낱잎 2장
    for i, (ex, ey, ll) in enumerate([(-22, -6, 7.0), (-31, 5, 6.0), (-40, -2, 5.0)]):
        a = 0.5 * math.sin(ph + i * 2.1) - 0.2
        ca, sa = math.cos(a), math.sin(a)
        bx, by = CX + ex, CY + ey + 1.5 * math.sin(ph + i)
        sub = {}
        for y in range(int(by - 8), int(by + 9)):
            for x in range(int(bx - 8), int(bx + 9)):
                px, py = x + 0.5 - bx, y + 0.5 - by
                u = px * ca + py * sa
                v = -px * sa + py * ca
                if u < -ll / 2 or u > ll / 2:
                    continue
                w = 1.9 * math.cos(math.pi * (u / ll))
                if abs(v) <= w:
                    sub[(x, y)] = 4 if v < 0 else 5
        for p, l in sub.items():
            put(lv, p[0], p[1], l)

    outline(lv, 7)   # 어두운 윤곽 (잔디 배경 대비)
    return lv


BUILDERS = {
    "fireball": fireball, "waterball": waterball, "windball": windball,
    "boltball": boltball, "earthball": earthball, "grassball": grassball,
}


def render(name):
    ramp = [A[c] for c in RAMPS[name]]
    im = Image.new("RGBA", (FW * NF, FH), (0, 0, 0, 0))
    px = im.load()
    for f in range(NF):
        lv = BUILDERS[name](f)
        for (x, y), l in lv.items():
            if 0 <= x < FW and 0 <= y < FH:
                r, g, b = ramp[max(0, min(len(ramp) - 1, l))]
                px[f * FW + x, y] = (r, g, b, 255)
    return im


if __name__ == "__main__":
    for n in BUILDERS:
        im = render(n)
        im.save(os.path.join(OUT, n + "_sheet.png"))
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(
            os.path.join(OUT, "prev_" + n + ".png"))
    print("done")
