# 타일셋 자가 검증 — 팔레트 · 알파 · **이어 붙였을 때 경계가 맞는가**
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PNG = ROOT + "/assets/sprites/field/tileset_ground.png"
GPL = ROOT + "/assets/aseprite/takbon.gpl"

pal = set()
for line in open(GPL, encoding="utf-8"):
    p = line.split()
    if len(p) >= 3 and p[0].isdigit():
        pal.add((int(p[0]), int(p[1]), int(p[2])))
print("팔레트 색 수:", len(pal))

im = Image.open(PNG).convert("RGBA")
W, H = im.size
print("시트 크기:", im.size, "= %dx%d 칸" % (W // 64, H // 64))

bad, alpha_bad, used = set(), 0, set()
for y in range(H):
    for x in range(W):
        r, g, b, a = im.getpixel((x, y))
        if a not in (0, 255):
            alpha_bad += 1
        if a == 255:
            used.add((r, g, b))
            if (r, g, b) not in pal:
                bad.add((r, g, b))
print("팔레트 밖 색:", len(bad), sorted("#%02x%02x%02x" % c for c in bad))
print("반투명 픽셀:", alpha_bad)
print("쓴 색 수:", len(used))

# ── 이어 붙임 검사 ────────────────────────────────────────────────
rgb = im.convert("RGB")


def is_dirt(p):
    return p[0] > p[1]            # 흙·돌 계열은 R>G, 풀 계열은 G>R


KEY = {
    "dirt_TL": (0, 0), "dirt_T_a": (1, 0), "dirt_T_b": (2, 0), "dirt_TR": (3, 0),
    "dirt_L": (4, 0), "dirt_C_a": (5, 0), "dirt_R": (6, 0), "dirt_C_b": (7, 0),
    "dirt_BL": (0, 1), "dirt_B_a": (1, 1), "dirt_B_b": (2, 1), "dirt_BR": (3, 1),
    "in_TL": (4, 1), "in_TR": (5, 1), "in_BL": (6, 1), "in_BR": (7, 1),
    "path_V_a": (0, 2), "path_V_b": (1, 2), "path_H_a": (2, 2), "path_H_b": (3, 2),
    "corner_ES": (4, 2), "corner_WS": (5, 2), "corner_EN": (6, 2), "corner_WN": (7, 2),
    "end_N": (0, 3), "end_S": (1, 3), "end_W": (2, 3), "end_E": (3, 3),
    "cross": (4, 3), "tee_S": (5, 3), "tee_N": (6, 3), "tee_E": (7, 3),
    "tee_W": (0, 4), "g_a": (1, 4), "g_b": (2, 4), "g_c": (3, 4),
    "d_bare": (4, 4), "gravel": (5, 4), "g_leaf": (6, 4), "mottle": (7, 4),
}


def edge(name, side):
    c, r = KEY[name]
    ox, oy = c * 64, r * 64
    if side == "L":  return tuple(is_dirt(rgb.getpixel((ox, oy + i))) for i in range(64))
    if side == "R":  return tuple(is_dirt(rgb.getpixel((ox + 63, oy + i))) for i in range(64))
    if side == "T":  return tuple(is_dirt(rgb.getpixel((ox + i, oy))) for i in range(64))
    return tuple(is_dirt(rgb.getpixel((ox + i, oy + 63))) for i in range(64))


# 가로로 맞닿는 짝: (왼쪽 타일, 오른쪽 타일)
PAIRS_H = [
    ("dirt_T_a", "dirt_T_b"), ("dirt_T_b", "dirt_T_a"), ("dirt_TL", "dirt_T_a"),
    ("dirt_T_b", "dirt_TR"), ("dirt_C_a", "dirt_C_b"), ("dirt_L", "dirt_C_a"),
    ("dirt_C_b", "dirt_R"), ("dirt_BL", "dirt_B_a"), ("dirt_B_a", "dirt_B_b"),
    ("dirt_B_b", "dirt_BR"), ("path_H_a", "path_H_b"), ("path_H_b", "path_H_a"),
    # 🔴 끝·모서리는 **연결되는 쪽**에만 길이 붙는다 (end_W = 서쪽으로 이어지는 막다른 끝)
    ("path_H_a", "end_W"), ("end_E", "path_H_a"), ("corner_ES", "path_H_a"),
    ("path_H_b", "corner_WS"), ("corner_EN", "path_H_a"), ("path_H_b", "corner_WN"),
    ("tee_E", "path_H_a"), ("path_H_b", "tee_W"), ("path_H_a", "cross"),
    ("cross", "path_H_b"), ("tee_S", "path_H_a"), ("path_H_b", "tee_S"),
    ("tee_N", "path_H_a"), ("path_H_b", "tee_N"),
    ("in_TL", "dirt_C_a"), ("dirt_C_a", "in_TR"), ("in_BL", "in_BR"),
    ("dirt_L", "in_TR"), ("in_BL", "dirt_R"),
]
# 세로로 맞닿는 짝: (위 타일, 아래 타일)
PAIRS_V = [
    ("dirt_L", "dirt_BL"), ("dirt_TL", "dirt_L"), ("dirt_C_a", "dirt_C_b"),
    ("dirt_T_a", "dirt_C_a"), ("dirt_C_b", "dirt_B_a"), ("dirt_R", "dirt_BR"),
    ("path_V_a", "path_V_b"), ("path_V_b", "path_V_a"), ("path_V_a", "end_N"),
    ("end_S", "path_V_a"), ("corner_ES", "path_V_a"), ("path_V_a", "corner_EN"),
    ("corner_WS", "path_V_b"), ("path_V_a", "corner_WN"), ("path_V_a", "cross"),
    ("cross", "path_V_b"), ("tee_E", "path_V_a"), ("path_V_b", "tee_E"),
    ("tee_W", "path_V_a"), ("path_V_b", "tee_W"),
    ("tee_S", "path_V_a"), ("path_V_a", "tee_N"), ("in_TL", "in_BL"),
    ("dirt_T_a", "in_BL"), ("in_TR", "dirt_B_a"),
]

fails = 0
for a, b in PAIRS_H:
    if edge(a, "R") != edge(b, "L"):
        d = [i for i in range(64) if edge(a, "R")[i] != edge(b, "L")[i]]
        print("  ✗ 가로 %s | %s  어긋난 행 %s" % (a, b, d[:8]))
        fails += 1
for a, b in PAIRS_V:
    if edge(a, "B") != edge(b, "T"):
        d = [i for i in range(64) if edge(a, "B")[i] != edge(b, "T")[i]]
        print("  ✗ 세로 %s / %s  어긋난 열 %s" % (a, b, d[:8]))
        fails += 1
print("이어 붙임 검사: %d짝 중 어긋남 %d" % (len(PAIRS_H) + len(PAIRS_V), fails))

# 단색 바탕 칸은 네 변이 전부 같은 종류여야 자기끼리 이어진다
for nm in ("g_a", "g_b", "g_c", "d_bare", "gravel", "g_leaf", "dirt_C_a", "dirt_C_b"):
    c, r = KEY[nm]
    ok = all(is_dirt(rgb.getpixel((c * 64, r * 64 + i))) == is_dirt(rgb.getpixel((c * 64 + 63, r * 64 + i)))
             for i in range(64))
    if not ok:
        print("  ✗ %s 자기끼리 안 이어진다" % nm)

# 🔴 얼룩 칸(mottle)은 좌우가 같을 리 없다 — 「감싸서」 이어진다. 그래서 재는 것도 다르다:
#    왼쪽 끝에 접촉 그늘(#4d2b32)이 찍혔다면 **감싼 이웃**(오른쪽 끝)이 풀이어야 앞뒤가 맞는다.
c, r = KEY["mottle"]
SH = (0x4d, 0x2b, 0x32)
wrong = 0
for i in range(64):
    if rgb.getpixel((c * 64, r * 64 + i)) == SH:
        left_wrapped = rgb.getpixel((c * 64 + 63, r * 64 + i))
        up_wrapped = rgb.getpixel((c * 64 + 63, r * 64 + max(i - 1, 0)))
        if is_dirt(left_wrapped) and is_dirt(up_wrapped) and is_dirt(rgb.getpixel((c * 64, r * 64 + max(i - 1, 0)))):
            wrong += 1
print("mottle 감싸기 어긋난 픽셀:", wrong)
