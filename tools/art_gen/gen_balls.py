# -*- coding: utf-8 -*-
"""탁본 마법 볼 6종 스프라이트 시트 생성기.

- 프레임 92x48 x 6 = 552x48 가로 스트립
- 실루엣 56x28, 머리 중심 = 프레임 (74, 24) = 히트박스 중심
  (ring_carrier: RADIUS_PX 12 / SPRITE_FRAME_RADIUS 14 = 0.857배 → 화면 48x24)
- Apollo 46색만, 알파는 0 아니면 255 (하드 엣지)
- 룬마다 실루엣이 다르다: 혜성 / 물방울 / 빈 소용돌이 / 지그재그 선 / 각진 돌 / 잎다발
  → 흑백으로 봐도 여섯이 구분되는 것이 성공 기준
"""
import math, os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))

# ── Apollo 46 (assets/aseprite/apollo.gpl) ─────────────────────────────────
A = {
    "b0": (23, 32, 56),    "b1": (37, 58, 94),    "b2": (60, 94, 139),
    "b3": (79, 143, 186),  "b4": (115, 190, 211), "b5": (164, 221, 219),
    "g0": (25, 51, 45),    "g1": (37, 86, 46),    "g2": (70, 130, 50),
    "g3": (117, 167, 67),  "g4": (168, 202, 88),  "g5": (208, 218, 145),
    "t0": (77, 43, 50),    "t1": (122, 72, 65),   "t2": (173, 119, 87),
    "t3": (192, 148, 115), "t4": (215, 181, 148), "t5": (231, 213, 179),
    "o0": (52, 28, 39),    "o1": (96, 44, 44),    "o2": (136, 75, 43),
    "o3": (190, 119, 43),  "o4": (222, 158, 65),  "o5": (232, 193, 112),
    "r0": (36, 21, 39),    "r1": (65, 29, 49),    "r2": (117, 36, 56),
    "r3": (165, 48, 48),   "r4": (207, 87, 60),   "r5": (218, 134, 62),
    "p0": (30, 29, 57),    "p1": (64, 39, 81),    "p2": (122, 54, 123),
    "p3": (162, 62, 140),  "p4": (198, 81, 151),  "p5": (223, 132, 165),
    "n0": (9, 10, 20),     "n1": (16, 20, 31),    "n2": (21, 29, 40),
    "n3": (32, 46, 55),    "n4": (57, 74, 80),    "n5": (87, 114, 119),
    "n6": (129, 151, 150), "n7": (168, 181, 178), "n8": (199, 207, 204),
    "n9": (235, 237, 233),
    # ── 보강 14색 (takbon.gpl — Apollo 46을 부분집합으로 품는다) ──────────
    "k0": (22, 40, 28),     # 16281C 숲 그늘·최암 초록 (윤곽)
    "k1": (47, 97, 82),     # 2F6152 청록빛 초록
    "k2": (122, 140, 46),   # 7A8C2E 올리브 (잔디와 다른 따뜻한 풀)
    "y0": (201, 150, 46),   # C9962E 황토 (번개 그늘)
    "y1": (242, 203, 63),   # F2CB3F 쨍한 노랑 (번개가 불과 갈리는 색)
    "y2": (251, 239, 168),  # FBEFA8 연노랑
    "s0": (42, 44, 50),     # 2A2C32 어두운 무채
    "s1": (78, 82, 89),     # 4E5259 중간 무채
    "s2": (46, 31, 24),     # 2E1F18 따뜻한 최암부 (갈색 계열 윤곽)
    "v0": (139, 95, 191),   # 8B5FBF 밝은 보라
    "v1": (224, 163, 232),  # E0A3E8 연보라
    "c0": (63, 169, 160),   # 3FA9A0 청록 (바람 마법 몸)
    "c1": (200, 245, 238),  # C8F5EE 밝은 시안
    "w": (247, 247, 242),   # F7F7F2 마법 코어 흰 (EBEDE9는 회색빛이라 빛이 안 산다)
}

FW, FH, NF = 92, 48, 6
CX, CY = 74.0, 24.0          # 머리 중심 = 히트박스 중심 (프레임 좌표)

# ── 램프: index 0 = 가장 밝은 코어, 7 = 가장 어두운 테두리 ───────────────────
## 0~7 = 밝음→어두움 본 램프. 8 이상은 그 룬 전용 악센트(불티·가시 등).
## 🔴 코어 흰은 전부 `w`(F7F7F2) — Apollo 최명부 EBEDE9는 회색빛이라 빛이 안 산다.
RAMPS = {
    #             0(코어) 1      2      3      4      5      6      7(테)  8~(악센트)
    "fireball":  ["w",   "o5",  "o4",  "r5",  "r4",  "r3",  "r2",  "s2",  "r1"],
    "waterball": ["w",   "n8",  "b5",  "b4",  "b3",  "b2",  "b1",  "b0",  "n7"],
    # 바람 = 청록(c1/c0/k1). 회색 잡탕이면 「바람 마법 몸」이 안 생긴다
    "windball":  ["w",   "c1",  "b5",  "b4",  "c0",  "n5",  "k1",  "s0",  "n6"],
    # 🔴 번개 = F2CB3F — Apollo엔 없는 색이다. E8C170으로 두면 불과 안 갈린다
    "boltball":  ["w",   "y1",  "y0",  "y2",  "o2",  "s1",  "s2",  "s2",  "o5"],
    "earthball": ["t5",  "t4",  "t3",  "t2",  "o3",  "t1",  "t0",  "s2",  "o2"],
    # 🔴 풀 윤곽 = k0(16281C). Apollo 최암 초록(19332D)보다 어두워 잔디에 안 묻힌다
    "grassball": ["g5",  "g4",  "g3",  "k2",  "g2",  "g1",  "k0",  "k0",  "t2", "t5"],
}


# ── 레벨맵 헬퍼 ────────────────────────────────────────────────────────────
def put(lv, x, y, level):
    """더 밝은(작은) 레벨이 이긴다."""
    if 0 <= x < FW and 0 <= y < FH:
        cur = lv.get((x, y))
        if cur is None or level < cur:
            lv[(x, y)] = level


def over(dst, src):
    """src를 dst 위에 그대로 덮는다 (앞에 있는 요소용)."""
    for p, l in src.items():
        if 0 <= p[0] < FW and 0 <= p[1] < FH:
            dst[p] = l


def under(dst, src):
    """src를 dst 아래에 깐다 (뒤에 있는 요소용)."""
    for p, l in src.items():
        if p not in dst and 0 <= p[0] < FW and 0 <= p[1] < FH:
            dst[p] = l


def rim(lv, dark):
    """실루엣 가장자리를 한 단계 어둡게 — 균일 검정이 아니라 색 외곽선."""
    edge = [p for p in lv
            if any((p[0] + d[0], p[1] + d[1]) not in lv
                   for d in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in edge:
        lv[p] = dark


def outline(lv, level):
    """실루엣 바깥으로 1px 윤곽을 두른다 (잔디 배경 대비용)."""
    add = {}
    for (x, y) in lv:
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
    return math.hypot(wx - t * vx, wy - t * vy)


def poly_dist(px, py, pts):
    return min(seg_dist(px, py, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
               for i in range(len(pts) - 1))


def in_poly(px, py, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]; xj, yj = pts[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def blob(cx, cy, r, core_lvl, edge_lvl, rim_lvl):
    """작은 덩어리 하나 (부스러기·자갈·불티 공용) — 2px 이상만 쓴다."""
    s = {}
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                s[(x, y)] = core_lvl if d < r * 0.5 else edge_lvl
    rim(s, rim_lvl)
    return s


# ══════════════════════════════════════════════════════════════════════════
# 불 — 꼬리 긴 혜성 + 둥근 머리
# ══════════════════════════════════════════════════════════════════════════
def fireball(f):
    ph = f / float(NF) * 2 * math.pi
    R = 12.6
    lv = {}

    # ── 꼬리: 머리 쪽이 굵고 끝으로 얇아지는 물결 스파인
    #    (본류 + 갈래 2 + 머리 뒤에서 위아래로 피어오르는 짧은 불꽃 혀 2)
    tail = {}
    strands = [(0.0, 11.0, 26.0, 2.6, 1.00, 1),
               (2.3, 5.6, 30.0, 5.4, 0.80, 2),
               (4.3, 4.6, 22.0, -5.0, 0.72, 2),
               (1.1, 6.4, 17.0, 9.6, 0.42, 1),     # 위로 솟는 혀
               (5.0, 5.8, 15.0, -9.2, 0.40, 2)]    # 아래로 솟는 혀
    for sph, tw, wl, amp, reach, base in strands:
        x0 = CX - 33.5 * reach
        for x in range(int(x0), int(CX + 3)):
            u = (x + 0.5 - x0) / (CX + 2 - x0)
            if u <= 0:
                continue
            spine = CY + amp * math.sin(2 * math.pi * (x - CX) / wl + ph + sph) * (1.0 - u * 0.5)
            half = tw * (u ** 0.9) * 0.5
            if half < 0.5:
                continue
            for y in range(int(spine - half) - 1, int(spine + half) + 2):
                d = abs(y + 0.5 - spine)
                if d > half:
                    continue
                s = (u ** 1.4) * 0.80 + (1.0 - d / max(half, 0.6)) * 0.40
                put(tail, x, y, max(base, min(5, 5 - int(s * 4.2))))
    rim(tail, 6)

    # ── 떨어져 나간 불티 (2px 이상 덩어리 — 낱픽셀 노이즈 금지)
    for i, (ex, ey, rr) in enumerate([(-36, -8, 1.9), (-31, 7, 1.6), (-41, 1, 1.8)]):
        under(tail, blob(CX + ex + 1.1 * math.sin(ph + i * 2.0),
                         CY + ey + 1.8 * math.cos(ph * 1.3 + i), rr, 1, 3, 8))

    # ── 머리: 둥근 구 — 안쪽 링만 맥동(실루엣 고정 = 팝핑 없음)
    head = {}
    pulse = 0.85 * math.sin(ph)
    for y in range(int(CY - R - 1), int(CY + R + 2)):
        for x in range(int(CX - R - 1), int(CX + R + 2)):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            d = math.hypot(dx, dy)
            if d > R:
                continue
            # 좌상단 광원: 코어를 약간 앞·위로 밀어 구면감을 준다
            dc = math.hypot(dx - 1.4, dy + 1.2)
            if dc < 3.2 + pulse:
                l = 0
            elif dc < 5.6 + pulse:
                l = 1
            elif dc < 7.6:
                l = 2
            elif dc < 9.4:
                l = 3
            elif d < R - 1.4:
                l = 4
            else:
                l = 5
            head[(x, y)] = l
    rim(head, 7)

    over(lv, tail)
    over(lv, head)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 물 — 둥근 물방울 덩어리 + 뒤에 방울 부스러기
# ══════════════════════════════════════════════════════════════════════════
def waterball(f):
    ph = f / float(NF) * 2 * math.pi
    wob = math.sin(ph)
    rx, ry = 12.6 + 0.8 * wob, 12.6 - 0.8 * wob
    lv = {}

    body = {}
    for y in range(int(CY - ry - 2), int(CY + ry + 3)):
        for x in range(int(CX - rx - 7), int(CX + rx + 2)):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            k = 1.0 if dx >= 0 else 1.0 + 0.16 * (-dx / rx) ** 2   # 뒤만 살짝 늘여 물방울
            d = math.hypot(dx / (rx * k), dy / ry)
            if d > 1.0:
                continue
            # 좌상단 광원 구면 음영
            sh = (dx * 0.55 + dy * 0.75) / max(rx, ry)
            if d < 0.55:
                l = 2 if sh < 0.05 else 3
            elif d < 0.82:
                l = 3 if sh < 0.05 else 4
            else:
                l = 4 if sh < -0.15 else 5
            if sh > 0.62:
                l = 6                      # 아랫배 그늘
            body[(x, y)] = l
    rim(body, 7)

    # 표면 하이라이트: 좌상단 초승달 1 + 아래 반사 1 (spec: 1~2점)
    for y in range(int(CY - ry), int(CY + 2)):
        for x in range(int(CX - rx), int(CX + 2)):
            if (x, y) not in body:
                continue
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            d = math.hypot(dx / rx, dy / ry)
            a = math.atan2(dy, dx)
            if not (-2.62 < a < -1.02):
                continue
            if 0.60 < d < 0.80:
                body[(x, y)] = 0
            elif 0.52 < d < 0.88:
                body[(x, y)] = 1
    for y in range(int(CY + 3), int(CY + 8)):
        for x in range(int(CX + 1), int(CX + 8)):
            if (x, y) in body and math.hypot((x + 0.5 - (CX + 3.8)) / 2.4,
                                             (y + 0.5 - (CY + 5.0)) / 1.4) < 1.0:
                body[(x, y)] = 1
    over(lv, body)

    # 뒤에 흩어진 방울 부스러기 (자기 테두리를 갖는다)
    drops = [(-20, -11, 3.2), (-26, 7, 2.7), (-32, -4, 2.3), (-37, 10, 2.0), (-41, -8, 1.8)]
    for i, (ex, ey, dr) in enumerate(drops):
        under(lv, blob(CX + ex - 1.6 * math.sin(ph + i * 1.1),
                       CY + ey + 1.4 * math.sin(ph * 1.4 + i * 2.0), dr, 8, 4, 7))
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 바람 — 속이 빈 열린 소용돌이 (가운데가 뚫린 것이 다른 다섯과 가르는 축)
# ══════════════════════════════════════════════════════════════════════════
def arc_band(lv, cx, cy, radius, a0, a1, w0, w1, lb, taper=True, radius1=None):
    """중심 반지름이 radius→radius1로 줄어드는 띠 호. 폭은 w0→w1."""
    r1 = radius if radius1 is None else radius1
    rmax = max(radius, r1) + max(w0, w1) + 2
    for y in range(int(cy - rmax), int(cy + rmax + 1)):
        for x in range(int(cx - rmax), int(cx + rmax + 1)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            while a < a0:
                a += 2 * math.pi
            if a > a1:
                continue
            t = (a - a0) / (a1 - a0)
            w = w0 + (w1 - w0) * t
            if taper:
                w *= (0.45 + 0.55 * math.sin(math.pi * t) ** 0.45)
            rr = radius + (r1 - radius) * t
            if abs(d - rr) > w:
                continue
            e = abs(d - rr) / max(w, 0.5)
            put(lv, x, y, max(0, min(6, lb + int(e * 2.0) + int(t * 1.4))))


def wisp(lv, pts, wmax, lb, dy=0.0):
    """끝으로 갈수록 얇아지는 바람 자락 한 줄 (폴리라인 — 좌표를 직접 쥔다)."""
    ps = [(x, y + dy) for x, y in pts]
    seglen = [math.hypot(ps[i + 1][0] - ps[i][0], ps[i + 1][1] - ps[i][1])
              for i in range(len(ps) - 1)]
    total = sum(seglen)
    xs = [p[0] for p in ps]; ys = [p[1] for p in ps]
    for y in range(int(min(ys)) - 4, int(max(ys)) + 5):
        for x in range(int(min(xs)) - 4, int(max(xs)) + 5):
            px, py = x + 0.5, y + 0.5
            best, bt = 1e9, 0.0
            acc = 0.0
            for i in range(len(ps) - 1):
                ax, ay = ps[i]; bx, by = ps[i + 1]
                vx, vy = bx - ax, by - ay
                L2 = vx * vx + vy * vy
                t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
                d = math.hypot(px - ax - t * vx, py - ay - t * vy)
                if d < best:
                    best, bt = d, (acc + t * seglen[i]) / max(total, 1e-6)
                acc += seglen[i]
            w = wmax * math.sin(math.pi * bt) ** 0.80
            if best > w:
                continue
            put(lv, x, y, min(6, lb + int(best / max(w, 0.4) * 1.8) + int(bt * 1.2)))


def windball(f):
    spin = f / float(NF) * 2 * math.pi
    ring = {}

    # 나선 바깥 감김 — 반지름 고정(실루엣이 회전에 안 흔들린다) · 앞쪽이 열린 C
    arc_band(ring, CX, CY, 11.0, spin - 0.15, spin + 5.35, 2.6, 2.0, 0)
    # 같은 나선이 안으로 말려 들어간다 (바깥 감김이 끝난 각도에서 이어 붙는다)
    arc_band(ring, CX, CY, 7.6, spin + 5.20, spin + 8.70, 2.0, 1.3, 2, radius1=3.0)
    # 🔴 테두리는 **고리에만** 두른다 — 자락은 2~3px라 rim을 걸면 전부 테두리색이 되어
    #    "회색 실뭉치"로 뭉갠다.
    rim(ring, 7)

    lv = dict(ring)
    # 뒤로 흘리는 바람 자락 3줄 — 좌표를 직접 쥐어 프레임마다 실루엣이 안 흔들린다
    wisp(lv, [(32, 16.0), (45, 12.1), (61, 19.5)], 1.7, 3, 0.5 * math.sin(spin))
    wisp(lv, [(30, 32.0), (45, 35.9), (60, 28.5)], 1.6, 4, -0.5 * math.sin(spin))
    wisp(lv, [(39, 22.0), (47, 24.6), (55, 21.5)], 1.2, 6, 0.7 * math.sin(spin + 2.1))
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 번개 — 구체 없는 각진 지그재그 선
# ══════════════════════════════════════════════════════════════════════════
## 지그재그 경로 — 프레임마다 통째로 다시 그어지는 것이 번개의 언어다.
## 앞 끝은 늘 (82, 24) 근처 = 히트박스 중심 쪽으로 모인다.
BOLT_PATHS = [
    [(34, 20), (45, 13), (53, 34), (64, 14), (72, 33), (82, 23)],
    [(34, 34), (44, 15), (54, 33), (63, 13), (73, 30), (82, 17)],
    [(33, 13), (45, 33), (55, 13), (65, 34), (74, 15), (82, 31)],
    [(34, 32), (43, 13), (54, 30), (63, 13), (74, 34), (82, 18)],
    [(34, 13), (44, 33), (53, 13), (65, 31), (74, 14), (82, 30)],
    [(34, 34), (45, 13), (55, 33), (65, 15), (75, 32), (82, 19)],
]
BOLT_FORKS = [
    [(53, 34), (61, 31)], [(63, 13), (71, 16)], [(55, 13), (63, 16)],
    [(54, 30), (62, 34)], [(65, 31), (72, 33)], [(65, 15), (73, 13)],
]
BOLT_SPARKS = [(-26, -9), (-18, 10), (-32, 3), (-12, -10)]


def boltball(f):
    lv = {}
    ph = f / float(NF) * 2 * math.pi
    path = BOLT_PATHS[f]
    fork = BOLT_FORKS[f]

    # 잔가지·본줄 모두 얇게 — 두꺼우면 낙서로 읽힌다 (코어 2px + 노랑 1px)
    def stroke(pts, core, mid, glow, hot):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        for y in range(min(ys) - 3, max(ys) + 4):
            for x in range(min(xs) - 3, max(xs) + 4):
                d = poly_dist(x + 0.5, y + 0.5, pts)
                if d <= core:
                    put(lv, x, y, hot)
                elif d <= mid:
                    put(lv, x, y, 1)
                elif d <= glow:
                    put(lv, x, y, 2)

    stroke(path, 0.75, 1.55, 2.15, 0)
    stroke(fork, 0.45, 1.05, 1.55, 3)

    # 앞 끝 충격점 — 구체가 아니라 각진 마름모 (히트박스 중심 쪽)
    tipx, tipy = 79.5, path[-1][1] * 0.25 + CY * 0.75
    for y in range(int(tipy) - 7, int(tipy) + 8):
        for x in range(int(tipx) - 7, int(tipx) + 8):
            m = abs(x + 0.5 - tipx) * 0.80 + abs(y + 0.5 - tipy)
            if m <= 1.8:
                put(lv, x, y, 0)
            elif m <= 3.0:
                put(lv, x, y, 1)
            elif m <= 4.0:
                put(lv, x, y, 3)

    rim(lv, 4)

    # 튀는 불꽃 (2px 덩어리 — 낱픽셀 금지)
    for i, (ex, ey) in enumerate(BOLT_SPARKS):
        under(lv, blob(CX + ex + 1.6 * math.sin(ph + i * 1.9),
                       CY + ey + 1.4 * math.cos(ph + i * 2.3), 1.5, 8, 3, 5))

    outline(lv, 6)
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 흙 — 각진 돌덩어리, 프레임마다 회전 (광원은 좌상단 고정)
# ══════════════════════════════════════════════════════════════════════════
ROCK = [(0.05, 14.6), (0.72, 10.4), (1.38, 14.4), (2.05, 10.0), (2.80, 14.2),
        (3.55, 10.2), (4.20, 14.5), (4.95, 10.1), (5.62, 13.8)]
CHIPS = [(0.30, 7.4, 2.6), (2.30, 4.4, 1.5), (4.55, 7.8, 1.2)]  # 각도, 반경, 크기


def earthball(f):
    rot = f / float(NF) * 2 * math.pi
    lv = {}
    pts = [(CX + r * math.cos(a + rot), CY + r * math.sin(a + rot)) for a, r in ROCK]
    ring = pts + [pts[0]]
    for y in range(int(CY - 15), int(CY + 16)):
        for x in range(int(CX - 15), int(CX + 16)):
            px, py = x + 0.5, y + 0.5
            if not in_poly(px, py, pts):
                continue
            edge = poly_dist(px, py, ring)
            # 좌상단 고정 광원 + 4단 계단 음영 (면이 살아 보이게)
            shade = (-(px - CX) - (py - CY)) / 15.0 + 0.5
            l = [4, 3, 2, 1][int(max(0.0, min(3.99, shade * 4.0)))]
            if edge < 1.4:
                l = min(6, l + 2)
            elif edge < 2.8:
                l = min(6, l + 1)
            lv[(x, y)] = l

    # 팬 자국(움푹한 홈) — 돌과 같이 돈다. 룬처럼 안 보이게 둥근 점으로
    for a, r, sz in CHIPS:
        ox = CX + r * math.cos(a + rot)
        oy = CY + r * math.sin(a + rot)
        for y in range(int(oy - sz - 1), int(oy + sz + 2)):
            for x in range(int(ox - sz - 1), int(ox + sz + 2)):
                if (x, y) not in lv:
                    continue
                d = math.hypot(x + 0.5 - ox, y + 0.5 - oy)
                if d <= sz:
                    lv[(x, y)] = 8                    # 홈 바닥 (따뜻한 그늘)
                elif d <= sz + 1.0 and lv[(x, y)] > 1:
                    lv[(x, y)] = 1                    # 홈 아래턱 하이라이트
    rim(lv, 7)
    # 🔴 테두리를 균일하게 어둡게 두지 않는다 — 좌상단 광원 쪽 모서리만 최명부로 되받는다
    #    (「색 외곽선」: 검정 한 겹이 아니라 빛 받는 면과 그늘 면이 갈린다)
    for (x, y) in [p for p in lv if lv[p] == 7]:
        d = (x + 0.5 - CX) + (y + 0.5 - CY)
        if d < -12.0:
            lv[(x, y)] = 0
        elif d < -8.5:
            lv[(x, y)] = 2

    # 뒤로 흩날리는 자갈 (2px 이상 덩어리 + 자기 테두리)
    grit = [(-20, -11.2, 2.5, 0.0), (-26, 9, 2.1, 0.9), (-32, -3, 2.4, 0.9),
            (-36, 11.2, 2.2, 0.0), (-41, -8, 1.9, 0.9)]
    for i, (ex, ey, rr, osc) in enumerate(grit):
        under(lv, blob(CX + ex - 1.4 * math.sin(rot + i),
                       CY + ey + osc * math.cos(rot * 1.2 + i * 1.7), rr, 2, 4, 7))
    return lv


# ══════════════════════════════════════════════════════════════════════════
# 풀 — 잎·가시 다발 (잔디에 안 묻히게 어두운 윤곽)
# ══════════════════════════════════════════════════════════════════════════
## 앞(오른쪽)으로 갈수록 잎이 길다 = 날아가는 방향이 실루엣으로 읽힌다
LEAVES = [   # (각도, 길이, 반폭, 시작 반경)
    (-0.32, 14.5, 3.5, 0.5), (0.30, 14.0, 3.4, 0.5), (-1.30, 12.5, 3.0, 1.0),
    (1.32, 12.0, 2.9, 1.0), (-2.25, 9.5, 2.7, 1.0), (2.28, 9.5, 2.7, 1.0),
    (3.14, 8.0, 2.4, 1.5),
]
THORNS = [(-0.72, 13.0), (0.70, 12.5), (-0.02, 14.5)]


def _leaf(dst, bx, by, a, L, hw, lit_lvl, body_lvl, shade_lvl):
    ca, sa = math.cos(a), math.sin(a)
    for y in range(int(by - L - 2), int(by + L + 3)):
        for x in range(int(bx - L - 2), int(bx + L + 3)):
            px, py = x + 0.5 - bx, y + 0.5 - by
            u = px * ca + py * sa
            v = -px * sa + py * ca
            if u < 0 or u > L:
                continue
            w = hw * math.sin(math.pi * (u / L)) ** 0.60
            if abs(v) > w:
                continue
            # 잎맥(밝은 중심선) + 좌상단 광원 쪽 밝게
            world_up = -math.sin(a) * 0 + (-v * ca - u * sa)   # 잎 픽셀의 화면 y 성분
            l = body_lvl if world_up < 0 else shade_lvl
            if abs(v) < w * 0.34 and u < L * 0.80:
                l = lit_lvl
            if u > L * 0.84:
                l = min(shade_lvl + 1, 6)   # 잎 끝은 한 단계 더 어둡게
            put(dst, x, y, l)


def grassball(f):
    ph = f / float(NF) * 2 * math.pi
    lv = {}
    # 가시 — 뾰족한 삼각, 나무빛(잎과 다른 색)이라 다발 속에서 읽힌다
    for i, (ang, L) in enumerate(THORNS):
        a = ang + 0.11 * math.sin(ph + i * 1.6)
        ca, sa = math.cos(a), math.sin(a)
        for y in range(int(CY - 16), int(CY + 17)):
            for x in range(int(CX - 16), int(CX + 17)):
                px, py = x + 0.5 - CX, y + 0.5 - CY
                u = px * ca + py * sa
                v = -px * sa + py * ca
                if u < 1.0 or u > L:
                    continue
                w = 2.2 * (1.0 - u / L) ** 0.80
                if abs(v) > w:
                    continue
                put(lv, x, y, 9 if u > L * 0.66 else 8)

    for i, (ang, L, hw, r0) in enumerate(LEAVES):
        a = ang + 0.15 * math.sin(ph + i * 0.9)
        _leaf(lv, CX + r0 * math.cos(a), CY + r0 * math.sin(a), a, L, hw, 0, 2, 4)

    # 중심 씨앗 뭉치
    for y in range(int(CY - 4), int(CY + 5)):
        for x in range(int(CX - 4), int(CX + 5)):
            d = math.hypot(x + 0.5 - CX, y + 0.5 - CY)
            if d < 3.4:
                lv[(x, y)] = 1 if d < 1.7 else 4

    # 뒤로 날리는 낱잎 3장
    for i, (ex, ey, ll) in enumerate([(-20, -9, 8.5), (-27, 8, 7.5), (-34, -4, 6.5)]):
        a = 0.55 * math.sin(ph + i * 2.1) + 2.9
        sub = {}
        _leaf(sub, CX + ex, CY + ey + 1.5 * math.sin(ph + i), a, ll, 2.4, 1, 2, 3)
        under(lv, sub)

    outline(lv, 6)   # 🔴 k0(16281C) 최암 초록 — 잔디에 안 묻히는 윤곽
    return lv


BUILDERS = {
    "fireball": fireball, "waterball": waterball, "windball": windball,
    "boltball": boltball, "earthball": earthball, "grassball": grassball,
}
ORDER = ["fireball", "waterball", "windball", "boltball", "earthball", "grassball"]


def render(name):
    ramp = [A[c] for c in RAMPS[name]]
    im = Image.new("RGBA", (FW * NF, FH), (0, 0, 0, 0))
    px = im.load()
    for f in range(NF):
        for (x, y), l in BUILDERS[name](f).items():
            if 0 <= x < FW and 0 <= y < FH:
                r, g, b = ramp[max(0, min(len(ramp) - 1, l))]
                px[f * FW + x, y] = (r, g, b, 255)
    return im


if __name__ == "__main__":
    for n in ORDER:
        im = render(n)
        im.save(os.path.join(OUT, n + "_sheet.png"))
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(
            os.path.join(OUT, "prev_" + n + ".png"))
    print("done")
