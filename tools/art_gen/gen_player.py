# -*- coding: utf-8 -*-
"""탁본 주인공 「후드 마법사」 스프라이트 생성기 (TAKBON 60 팔레트 전용).

- 손으로 authored한 부위 마스크 + 부위별 램프 셰이딩(광원 = 왼쪽 위·앞).
- 출력: 512x192 시트 (64x64 프레임 · 8열 x 3행 · row0 idle2 / row1 run8 / row2 hurt1)
- 실루엣 56px, 프레임 안에서 발밑을 아래에서 4px 위에 맞춘다.
- 🔴 팔레트 정본 = assets/aseprite/takbon.gpl (60색). apollo.gpl(46)은 그 부분집합이다.
"""
import math, os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
GPL = os.path.join(OUT, '..', '..', '..', '..', '..', '..',
                   'Desktop', 'godot_games', 'tockbon', 'assets', 'aseprite', 'takbon.gpl')
GPL = r'C:\Users\djgnf\Desktop\godot_games\tockbon\assets\aseprite\takbon.gpl'


def load_gpl(path):
    cols = []
    for line in open(path, encoding='utf-8'):
        p = line.split()
        if len(p) >= 3 and p[0].isdigit():
            cols.append('%02x%02x%02x' % (int(p[0]), int(p[1]), int(p[2])))
    return cols


TAKBON = load_gpl(GPL)
APSET = set(TAKBON)
assert len(TAKBON) == 60, len(TAKBON)


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# ------------------------------------------------------------------ 램프
# 🔴 TAKBON 60 확장분에서 얻은 것: 따뜻한 최암부 2e1f18 · 어두운 무채 2a2c32/4e5259 ·
#    숲 최암 16281c · 흰 f7f7f2(마법 코어) · 보라 8b5fbf/e0a3e8 · 황토 c9962e·쨍노랑 f2cb3f.
RED = ['2e1f18', '411d31', '752438', 'a53030', 'cf573c']             # 후드·로브 겉감
REDR = ['2e1f18', '411d31', '752438', 'a53030', 'cf573c', 'da863e']  # 말린 앞테(빛 받는 곳)
REDD = ['2e1f18', '411d31', '752438']                                # 후드 안쪽 그늘
TRIM = ['1e1d39', '402751', '7a367b', '8b5fbf', 'e0a3e8']            # 망토·앞섶(마법사 자수)
SKIN = ['7a4841', 'ad7757', 'c09473', 'd7b594', 'e7d5b3']
SKIND = ['2e1f18', '4d2b32', '7a4841']                               # 후드 그늘 속 얼굴
BLUE = ['253a5e', '3c5e8b', '4f8fba', '73bed3']                      # 속옷
GEM = ['3c5e8b', '4f8fba', '73bed3', 'a4dddb', 'c8f5ee']             # 마법 보석
GREEN = ['16281c', '25562e', '468232', '75a743', 'a8ca58', 'd0da91']
BELT = ['341c27', '602c2c', '884b2b', 'be772b']
GOLD = ['884b2b', 'c9962e', 'de9e41', 'f2cb3f']                      # 버클·소맷부리
HEM = ['341c27', '884b2b', 'be772b', 'e8c170']                       # 밑단 금박
GREY = ['090a14', '151d28', '172038', '2a2c32', '394a50', '4e5259']  # 남색 가죽 장화
SILV = ['4e5259', '577277', '819796', 'a8b5b2', 'c7cfcc', 'f7f7f2']  # 여밈쇠·목걸이 금속
CYAN = 'a4dddb'

RAMP = {'H': RED, 'F': REDR, 'L': REDD, 'D': SKIND, 'S': SKIN,
        'R': RED, 'M': TRIM, 'V': BLUE, 'C': SILV, 'G': GEM, 'W': TRIM,
        'a': RED, 'b': RED, 'c': GOLD, 'd': GOLD, 'e': SKIN, 'f': SKIN,
        'E': BELT, 'U': GOLD, 'K': RED, 'N': HEM, 'P': GREEN, 'Q': GREEN,
        'O': GREY}

# 밝기 구간 — 「기본색이 넓고 하이라이트는 얇게」. 6단 램프의 맨 위(주황)는
# 0.965 위에서만 나오게 밀어 후드가 붉게 읽히도록 한다.
BANDS = {3: [0.44, 0.72], 4: [0.40, 0.60, 0.82],
         5: [0.36, 0.52, 0.70, 0.90], 6: [0.36, 0.52, 0.68, 0.86, 0.965]}
AMB = 0.32

# ------------------------------------------------------------------ 마스크
BASE = [
    ".............HHHHHH.............",  # 0
    "...........HHHHHHHHHH...........",  # 1
    ".........HHHHHHHHHHHHHH.........",  # 2
    "........HHHHHHHHHHHHHHHH........",  # 3
    ".......HHHHHHHHHHHHHHHHHH.......",  # 4
    "......HHHHHHHHHHHHHHHHHHHH......",  # 5
    "......HHHHHHHHHHHHHHHHHHHH......",  # 6
    ".....HHHHHHHHHHHHHHHHHHHHHH.....",  # 7
    ".....HHHHHHHHHHHHHHHHHHHHHH.....",  # 8
    ".....HHHHHHHHHHHHHHHHHHHHHH.....",  # 9
    ".....HHHHHHHDDDDDDDDHHHHHHH.....",  # 10 이마 = 후드 그늘
    ".....HHHHHHDDDDDDDDDDHHHHHH.....",  # 11
    ".....HHHHHDDDDDDDDDDDDHHHHH.....",  # 12
    ".....HHHHHSSSSSSSSSSSSHHHHH.....",  # 13
    ".....HHHHHSSSSSSSSSSSSHHHHH.....",  # 14 눈
    ".....HHHHHSSSSSSSSSSSSHHHHH.....",  # 15 눈
    ".....HHHHHSSSSSSSSSSSSHHHHH.....",  # 16
    ".....HHHHHHSSSSSSSSSSHHHHHH.....",  # 17 코
    ".....HHHHHHSSSSSSSSSSHHHHHH.....",  # 18 입
    ".....HHHHHHHSSSSSSSSHHHHHHH.....",  # 19
    ".....HHHHHHHHSSSSSSHHHHHHHH.....",  # 20 턱
    "......HHHHHHHHHHHHHHHHHHHH......",  # 21
    "......HHHHHHHHHHHHHHHHHHHH......",  # 22
    "......WWWWWWWWWWWWWWWWWWWW......",  # 23 어깨 망토
    ".....WWWWWWWWWWWWWWWWWWWWWW.....",  # 24
    ".....WWWWWWWWWWWWWWWWWWWWWW.....",  # 25
    ".....WWWWWWWWWWWWWWWWWWWWWW.....",  # 26 망토 아랫단
    "....aaaaaRRRRMVVVVMRRRRbbbbb....",  # 27 소매 + 속옷 V
    "....aaaaaRRRRMVVVVMRRRRbbbbb....",  # 28
    "....aaaaaRRRRRMVVMRRRRRbbbbb....",  # 29
    "....aaaaaRRRRRRMMRRRRRRbbbbb....",  # 30
    ".....aaaaRRRRRRCCRRRRRRbbbb.....",  # 31 목걸이
    ".....aaaaRRRRRCGGCRRRRRbbbb.....",  # 32
    ".....aaaaRRRRRRCCRRRRRRbbbb.....",  # 33
    "......cccRRRRRRRRRRRRRRddd......",  # 34 소맷부리(금박)
    "......cccRRRRRRRRRRRRRRddd......",  # 35
    "......eeeRRRRRRRRRRRRRRfff......",  # 36 손
    "......eeeRRRRRRRRRRRRRRfff......",  # 37
    ".........EEEEEUUUUEEEEE.........",  # 38 허리끈 + 버클
    ".........EEEEEUUUUEEEEE.........",  # 39
    ".........EEEEEUUUUEEEEE.........",  # 40
    "........KKKKKKKKKKKKKKKK........",  # 41 로브 자락
    "........KKKKKKKKKKKKKKKK........",  # 42
    ".......KKKKKKKKKKKKKKKKKK.......",  # 43
    ".......KKKKKKKKKKKKKKKKKK.......",  # 44
    "......KKKKKKKKKKKKKKKKKKKK......",  # 45
    "......KKKKKKKKKKKKKKKKKKKK......",  # 46
    "......KKKKKKKKKKKKKKKKKKKK......",  # 47
    ".....KKKKKKKKKKKKKKKKKKKKKK.....",  # 48
    ".....KKKKKKKKKKKKKKKKKKKKKK.....",  # 49
    "....NNNNNNNNNNNNNNNNNNNNNNNN....",  # 50 밑단 금박
    "....KKKKKKKKKKKKKKKKKKKKKKKK....",  # 51
    "..........OOOOO..OOOOO..........",  # 52 장화
    "..........OOOOO..OOOOO..........",  # 53
    "..........OOOOO..OOOOO..........",  # 54
    "..........OOOOO..OOOOO..........",  # 55
]
for i, r in enumerate(BASE):
    assert len(r) == 32, (i, len(r))
W, H = 32, 56


def grid(rows):
    return [list(r) for r in rows]


def carve_hood(g):
    """얼굴 구멍 둘레에 안감(L) 한 겹, 그 밖에 후드 앞테(F) 한 겹을 두른다."""
    hole = set((x, y) for y in range(H) for x in range(W) if g[y][x] in 'DS' and y < 23)
    for tag, src in (('L', hole), ('F', None)):
        pass
    ring1 = set()
    for (x, y) in hole:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in hole and 0 <= p[0] < W and 0 <= p[1] < H and g[p[1]][p[0]] == 'H':
                    ring1.add(p)
    for (x, y) in ring1:
        g[y][x] = 'L'
    ring2 = set()
    for (x, y) in ring1:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in ring1 and p not in hole and 0 <= p[0] < W and 0 <= p[1] < H \
                        and g[p[1]][p[0]] == 'H':
                    ring2.add(p)
    for (x, y) in ring2:
        g[y][x] = 'F'
    return g


def stamp_pouch(g):
    for y in (41, 42):
        for x in (9, 10):
            if g[y][x] != '.':
                g[y][x] = 'E'
    for y in range(43, 48):
        for x in range(7, 11):
            if (y, x) in ((43, 7), (47, 7), (47, 10)):
                continue
            if g[y][x] != '.':
                g[y][x] = 'Q' if y < 45 else 'P'
    return g


def prep(rows=None):
    g = grid(rows or BASE)
    carve_hood(g)
    stamp_pouch(g)
    return g


# ------------------------------------------------------------------ 셰이딩
LIGHT = (-0.53, -0.37, 0.76)
_n = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _n for c in LIGHT)


def sphere_field(cs, ry_mul=1.0):
    xs = [c[0] for c in cs]
    ys = [c[1] for c in cs]
    cx = (min(xs) + max(xs) + 1) / 2.0
    cy = (min(ys) + max(ys) + 1) / 2.0
    rx = max(1.0, (max(xs) - min(xs) + 1) / 2.0)
    ry = max(1.0, (max(ys) - min(ys) + 1) / 2.0) * ry_mul
    f = {}
    for (x, y) in cs:
        nx = (x + 0.5 - cx) / rx
        ny = (y + 0.5 - cy) / ry
        r2 = nx * nx + ny * ny
        if r2 > 1.0:
            s = 1.0 / math.sqrt(r2)
            nx *= s
            ny *= s
            r2 = 1.0
        nz = math.sqrt(max(0.0, 1.0 - r2))
        f[(x, y)] = max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])
    return f


def cyl_field(cs, vfall=0.28):
    rows = {}
    for (x, y) in cs:
        rows.setdefault(y, []).append(x)
    ys = sorted(rows)
    y0, y1 = ys[0], ys[-1]
    f = {}
    for y in ys:
        xs = rows[y]
        lo, hi = min(xs), max(xs)
        cx = (lo + hi + 1) / 2.0
        r = max(1.0, (hi - lo + 1) / 2.0)
        t = 0.0 if y1 == y0 else (y - y0) / float(y1 - y0)
        vf = 1.0 - vfall * t
        for x in xs:
            nx = max(-1.0, min(1.0, (x + 0.5 - cx) / r))
            nz = math.sqrt(max(0.0, 1.0 - nx * nx))
            f[(x, y)] = max(0.0, nx * LIGHT[0] + nz * LIGHT[2]) * vf
    return f


def pick(v, ramp):
    v = AMB + (1.0 - AMB) * max(0.0, min(1.0, v))
    b = BANDS[len(ramp)]
    i = 0
    while i < len(b) and v >= b[i]:
        i += 1
    return ramp[i]


def cells(g, chars, y0=0, y1=H):
    return [(x, y) for y in range(y0, min(y1, H)) for x in range(W) if g[y][x] in chars]


def shade(g):
    col = [[None] * W for _ in range(H)]

    def apply(cs, field, boost=0.0, scale=1.0):
        if not cs:
            return
        f = field(cs)
        for c in cs:
            col[c[1]][c[0]] = pick(f[c] * scale + boost, RAMP[g[c[1]][c[0]]])

    # 머리: 후드 겉감 + 앞테 + 안감을 하나의 구(球) 빛으로
    head = cells(g, 'HFL', 0, 24)
    if head:
        hf = sphere_field(head)
        for c in head:
            ch = g[c[1]][c[0]]
            v = hf[c]
            if ch == 'H':
                v += 0.06
            elif ch == 'F':
                v += 0.10                      # 말린 앞테 = 한 단 밝게
            elif ch == 'L':
                v *= 0.30                      # 후드 안쪽 = 깊은 그늘
            col[c[1]][c[0]] = pick(v, RAMP[ch])
    # 얼굴
    face = cells(g, 'DS', 0, 23)
    if face:
        ff = sphere_field(face, 1.7)
        for c in face:
            ch = g[c[1]][c[0]]
            col[c[1]][c[0]] = pick(ff[c] * (0.42 if ch == 'D' else 1.0), RAMP[ch])
    # 몸통 (소매 제외)
    apply(cells(g, 'W', 22, 28), lambda cs: cyl_field(cs, 0.16), scale=0.62)
    apply(cells(g, 'RCG', 26, 38), lambda cs: cyl_field(cs, 0.22))
    apply(cells(g, 'M', 26, 38), lambda cs: cyl_field(cs, 0.22), scale=0.70)
    apply(cells(g, 'V', 26, 38), lambda cs: cyl_field(cs, 0.22), scale=0.85)
    # 소매 좌/우 따로 — 이래야 몸통과 갈라져 팔로 읽힌다
    apply(cells(g, 'ace'), lambda cs: cyl_field(cs, 0.10))
    apply(cells(g, 'bdf'), lambda cs: cyl_field(cs, 0.10))
    # 허리끈
    apply(cells(g, 'E', 38, 43), lambda cs: cyl_field(cs, 0.05), scale=0.80)
    apply(cells(g, 'U', 38, 43), lambda cs: cyl_field(cs, 0.05))
    # 자락
    apply(cells(g, 'K', 41, 52), lambda cs: cyl_field(cs, 0.30))
    apply(cells(g, 'N', 41, 52), lambda cs: cyl_field(cs, 0.30), scale=0.85)
    # 주머니
    apply(cells(g, 'P'), sphere_field)
    apply(cells(g, 'Q'), sphere_field, scale=0.62)
    # 장화 (발마다)
    boots = cells(g, 'O')
    if boots:
        xs = sorted(set(x for x, _ in boots))
        groups, cur = [], [xs[0]]
        for a, b in zip(xs, xs[1:]):
            if b - a > 1:
                groups.append(cur)
                cur = []
            cur.append(b)
        groups.append(cur)
        for gr in groups:
            cs = [c for c in boots if c[0] in gr]
            f = cyl_field(cs, 0.10)
            for c in cs:
                col[c[1]][c[0]] = pick(f[c] + 0.18, GREY)

    # 외곽선 = 부위 램프의 가장 어두운 색 (빛 받는 위·왼쪽은 한 단 밝게)
    solid = set((x, y) for y in range(H) for x in range(W) if g[y][x] != '.')
    for (x, y) in solid:
        out = None
        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
            if (x + dx, y + dy) not in solid:
                out = (dx, dy) if out is None else out
        if out is None:
            continue
        r = RAMP[g[y][x]]
        col[y][x] = r[1] if (out in ((-1, 0), (0, -1)) and len(r) > 3) else r[0]
    return col


def contact_shadow(col, g):
    """겹친 부위 바로 아래를 한두 단 어둡게 — 후드/허리끈/자락이 「얹혀 있다」로 읽힌다."""
    def darken(x, y, n):
        c = col[y][x]
        r = RAMP[g[y][x]]
        if c in r:
            col[y][x] = r[max(0, r.index(c) - n)]

    for x in range(W):
        for y in (23, 24):                       # 후드 그림자가 망토에 진다
            if g[y][x] == 'W':
                darken(x, y, 2 if y == 23 else 1)
        for y in (27, 28):                       # 망토 그림자가 몸통·소매에
            if g[y][x] in 'RMVab':
                darken(x, y, 2 if y == 27 else 1)
        for y in (41, 42):                       # 허리끈 그림자가 자락에
            if g[y][x] == 'K':
                darken(x, y, 2 if y == 41 else 1)
        if g[52][x] == 'O':                      # 자락 그림자가 장화 위에
            darken(x, 52, 1)
    for y in range(27, 38):                      # 소매가 몸통에 드리우는 그림자
        for x in range(W):
            if g[y][x] in 'R' and (g[y][x - 1] in 'acebdf' if x > 0 else False):
                darken(x, y, 1)
    return col


def folds(col, g):
    """자락과 소매에 세로 주름 — 행마다 실제 폭에서 비율로 잡아 자락이 흔들려도 따라간다."""
    def darken(x, y, n=1):
        c, r = col[y][x], RAMP[g[y][x]]
        if c in r:
            col[y][x] = r[max(0, r.index(c) - n)]

    for y in range(43, 52):
        xs = [x for x in range(W) if g[y][x] in 'KN']
        if len(xs) < 8:
            continue
        lo, w = min(xs), len(xs)
        for t in (0.28, 0.62, 0.86):
            x = lo + int(round(w * t))
            if g[y][x] in 'KN':
                darken(x, y)
    for y in range(29, 36):
        for xs in ([x for x in range(W) if g[y][x] == 'a'],
                   [x for x in range(W) if g[y][x] == 'b']):
            if len(xs) >= 4:
                darken(xs[len(xs) // 2], y)
    return col


def despeckle(col, g):
    """이웃 넷과 전부 다른 고립 1픽셀을 지운다 (자글자글 방지)."""
    out = [row[:] for row in col]
    for y in range(H):
        for x in range(W):
            c = col[y][x]
            if c is None:
                continue
            nb = []
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and col[ny][nx] is not None \
                        and g[ny][nx] == g[y][x]:
                    nb.append(col[ny][nx])
            if len(nb) >= 3 and all(n != c for n in nb):
                out[y][x] = max(set(nb), key=nb.count)
    return out


# ------------------------------------------------------------------ 손그림 디테일
def details(col, g, dy=0, closed=False):
    def put(x, y, c):
        y += dy
        if 0 <= x < W and 0 <= y < H and g[y][x] in 'DS':
            col[y][x] = c

    if closed:
        # 안쪽으로 치켜올라간 눈썹 + 질끈 감은 눈 = 찡그림
        put(11, 13, '4d2b32')
        put(12, 13, '4d2b32')
        put(13, 14, '341c27')
        put(18, 14, '341c27')
        put(19, 13, '4d2b32')
        put(20, 13, '4d2b32')
        for x in (11, 12, 13):
            put(x, 15, '341c27')
        for x in (18, 19, 20):
            put(x, 15, '341c27')
        put(15, 17, 'ad7757')
        put(16, 17, 'ad7757')
        put(15, 19, '341c27')       # 작게 벌린 입
        put(16, 19, '341c27')
        return col
    for x in (11, 12, 13):
        put(x, 14, '151d28')
        put(x, 15, '090a14')
    for x in (18, 19, 20):
        put(x, 14, '151d28')
        put(x, 15, '090a14')
    put(11, 14, CYAN)
    put(18, 14, CYAN)
    put(13, 13, '7a4841')      # 눈썹 그늘
    put(18, 13, '7a4841')
    put(16, 16, 'c09473')      # 코
    put(16, 17, 'ad7757')
    put(11, 17, 'c09473')      # 볼
    put(20, 17, 'ad7757')
    put(14, 19, '7a4841')      # 입
    put(15, 19, '7a4841')
    put(16, 19, '7a4841')
    return col


def trinkets(col, g):
    # 망토 아랫단 자수 테 — 한 단 밝은 보라
    for x in range(W):
        if g[26][x] == 'W' and g[27][x] != 'W':
            c = col[26][x]
            if c in TRIM:
                col[26][x] = TRIM[min(len(TRIM) - 1, TRIM.index(c) + 1)]
    # 망토 여밈쇠(은) + 왼쪽 어깨에 걸리는 빛
    if g[24][15] == 'W':
        col[24][15] = 'c7cfcc'
        col[24][16] = '819796'
        col[25][15] = '4e5259'
        col[25][16] = '4e5259'
    # 목걸이 — 마법 보석(빛나는 코어) + 은테
    if g[32][15] == 'G':
        col[32][15] = 'f7f7f2'
        col[32][16] = 'c8f5ee'
    if g[31][15] == 'C':
        col[31][15] = 'c7cfcc'
        col[31][16] = 'a8b5b2'
        col[33][15] = '4e5259'
        col[33][16] = '4e5259'
    # 버클 광택 (왼쪽 위가 밝다)
    if g[38][14] == 'U':
        col[38][14] = 'f2cb3f'
        col[39][14] = 'de9e41'
        col[40][17] = '884b2b'
    # 후드 안쪽 — 얼굴에 드리운 그늘의 맨 밑은 가장 어둡게(따뜻한 최암부)
    for y in range(19, 23):
        for x in range(W):
            if g[y][x] == 'L':
                col[y][x] = '2e1f18'
    # 주머니 — 뚜껑 아랫단만 한 단 어둡게(가르는 선이 아니라 천이 접힌 자리)
    for x in range(8, 11):
        if g[44][x] == 'Q':
            c = col[44][x]
            if c in GREEN:
                col[44][x] = GREEN[max(0, GREEN.index(c) - 1)]
    if g[43][8] == 'Q':
        col[43][8] = 'a8ca58'
    if g[46][8] == 'P':
        col[46][8] = 'd0da91'
    # 장화 — 맨 아랫줄은 밑창(가장 어둡게)
    ys = [y for y in range(H) if any(g[y][x] == 'O' for x in range(W))]
    if ys:
        for x in range(W):
            if g[ys[-1]][x] == 'O':
                col[ys[-1]][x] = '090a14'
    return col


# ------------------------------------------------------------------ 프레임
def shift_block(g, x0, x1, y0, y1, dy):
    if dy == 0:
        return g
    src = [[g[y][x] for x in range(x0, x1 + 1)] for y in range(y0, y1 + 1)]
    n = len(src)
    for i in range(n):
        j = min(n - 1, max(0, i - dy))
        for k, x in enumerate(range(x0, x1 + 1)):
            g[y0 + i][x] = src[j][k]
    return g


def shift_cols(g, y0, y1, dx):
    """행 구간을 가로로 민다 (가장자리는 잘라낸다)."""
    for y in range(y0, y1 + 1):
        row, new = g[y][:], ['.'] * W
        for x in range(W):
            sx = x - dx
            if 0 <= sx < W:
                new[x] = row[sx]
        g[y] = new
    return g


BOOT_PHASES = [
    ((11, 15, 52, 55), (18, 22, 51, 54)),
    ((10, 14, 52, 55), (18, 22, 50, 53)),
    ((10, 14, 52, 55), (16, 20, 51, 54)),
    ((9, 13, 51, 54), (16, 20, 52, 55)),
]
HEM_DX = [1, 1, 0, -1]


def lower_variant(phase):
    g = prep()
    dx = HEM_DX[phase]
    if dx:
        for y in range(46, 52):
            row = g[y][:]
            new = ['.'] * W
            for x in range(W):
                sx = x - dx
                if 0 <= sx < W:
                    new[x] = row[sx]
            g[y] = new
    for y in range(50, 56):
        for x in range(W):
            if g[y][x] == 'O':
                g[y][x] = '.'
    for (x0, x1, y0, y1) in BOOT_PHASES[phase]:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = 'O'
    return g


def mirror_rows(g, y0, y1):
    for y in range(y0, y1 + 1):
        g[y] = list(reversed(g[y]))
    for y in range(y0, y1 + 1):          # 주머니는 거울을 안 탄다
        for x in range(W):
            if g[y][x] in 'PQ':
                g[y][x] = 'K'
    stamp_pouch(g)
    return g


def finish(g, dy=0, closed=False):
    c = shade(g)
    c = contact_shadow(c, g)
    c = folds(c, g)
    c = despeckle(c, g)
    details(c, g, dy=dy, closed=closed)
    trinkets(c, g)
    return c


def build_frames():
    frames = []
    # idle 0
    frames.append((finish(prep()), 0))
    # idle 1 — 숨 (머리·몸통 1px 내려감, 팔은 반대)
    g = prep()
    shift_block(g, 0, 31, 0, 40, 1)
    shift_block(g, 4, 8, 27, 37, -1)
    shift_block(g, 23, 27, 27, 37, -1)
    frames.append((finish(g, dy=1), 0))
    # run 8
    ARM = [2, 1, -1, -2, -2, -1, 1, 2]
    BOB = [0, -1, -2, -1, 0, -1, -2, -1]
    LEAN = [-1, -1, 0, 0, 1, 1, 0, 0]
    for i in range(8):
        g = lower_variant(i % 4)
        if i >= 4:
            mirror_rows(g, 41, 55)
        shift_block(g, 4, 8, 27, 40, ARM[i])
        shift_block(g, 23, 27, 27, 40, -ARM[i])
        if LEAN[i]:
            shift_cols(g, 0, 40, LEAN[i])   # 상체가 좌우로 실린다
        frames.append((finish(g), BOB[i]))
    # hurt
    g = prep()
    shift_block(g, 0, 31, 0, 22, 1)
    shift_block(g, 4, 8, 27, 37, -1)
    shift_block(g, 23, 27, 27, 37, -1)
    frames.append((finish(g, dy=1, closed=True), 0))
    return frames


LAYOUT = [(0, 0), (1, 0)] + [(i, 1) for i in range(8)] + [(0, 2)]


def render(path):
    frames = build_frames()
    sheet = Image.new('RGBA', (512, 192), (0, 0, 0, 0))
    px = sheet.load()
    heights = []
    for (c, dy), (cx, cy) in zip(frames, LAYOUT):
        ox, oy = cx * 64 + 16, cy * 64 + 4 + dy
        ymin, ymax = 999, -1
        for y in range(H):
            for x in range(W):
                if c[y][x]:
                    r, gg, b = rgb(c[y][x])
                    px[ox + x, oy + y] = (r, gg, b, 255)
                    ymin, ymax = min(ymin, y), max(ymax, y)
        heights.append(ymax - ymin + 1)
    sheet.save(path)
    return heights


def audit(path):
    im = Image.open(path).convert('RGBA')
    cols, semi, opaque = set(), 0, 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a == 0:
                continue
            opaque += 1
            if a != 255:
                semi += 1
            cols.add('%02x%02x%02x' % (r, g, b))
    n0 = sum(1 for y in range(64) for x in range(64) if im.getpixel((x, y))[3] > 0)
    print('colors=%d  outside=%d  semi=%d  opaque=%d' % (
        len(cols), len(cols - APSET), semi, opaque))
    if cols - APSET:
        print('  OUTSIDE:', sorted(cols - APSET))
    print('idle0 opaque=%d  density=%.2f' % (n0, len(cols) / max(1, n0) * 100))
    print('unused:', sorted(APSET - cols))


if __name__ == '__main__':
    p = os.path.join(OUT, 'player_mage_sheet.png')
    print('heights:', render(p))
    audit(p)
