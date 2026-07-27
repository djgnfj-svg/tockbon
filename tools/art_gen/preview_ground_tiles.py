# 타일을 이어 붙였을 때가 진짜다 — 길 한 장면을 조립해 본다.
from PIL import Image
import sys, subprocess, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
S = os.path.join(ROOT, "docs", "_reports")
os.makedirs(S, exist_ok=True)
SHEET = os.path.join(ROOT, "assets", "sprites", "field", "tileset_ground.png")

KEY = {
    "dirt_TL":(0,0),"dirt_T_a":(1,0),"dirt_T_b":(2,0),"dirt_TR":(3,0),
    "dirt_L":(4,0),"dirt_C_a":(5,0),"dirt_R":(6,0),"dirt_C_b":(7,0),
    "dirt_BL":(0,1),"dirt_B_a":(1,1),"dirt_B_b":(2,1),"dirt_BR":(3,1),
    "in_TL":(4,1),"in_TR":(5,1),"in_BL":(6,1),"in_BR":(7,1),
    "path_V_a":(0,2),"path_V_b":(1,2),"path_H_a":(2,2),"path_H_b":(3,2),
    "corner_ES":(4,2),"corner_WS":(5,2),"corner_EN":(6,2),"corner_WN":(7,2),
    "end_N":(0,3),"end_S":(1,3),"end_W":(2,3),"end_E":(3,3),
    "cross":(4,3),"tee_S":(5,3),"tee_N":(6,3),"tee_E":(7,3),
    "tee_W":(0,4),"g_a":(1,4),"g_b":(2,4),"g_c":(3,4),
    "d_bare":(4,4),"gravel":(5,4),"g_leaf":(6,4),"mottle":(7,4),
}

# (cons, nubs) -> 타일 이름.  cons = 풀이 닿는 변, nubs = 풀 섬이 박히는 모서리
LOOKUP = {
    ("",     ()):"dirt_C_a",
    ("T",    ()):"dirt_T_a", ("B",()):"dirt_B_a", ("L",()):"dirt_L", ("R",()):"dirt_R",
    ("TL",   ()):"dirt_TL",  ("TR",()):"dirt_TR", ("BL",()):"dirt_BL",("BR",()):"dirt_BR",
    ("",     ("TL",)):"in_TL", ("",("TR",)):"in_TR", ("",("BL",)):"in_BL", ("",("BR",)):"in_BR",
    ("LR",   ()):"path_V_a",  ("TB",()):"path_H_a",
    ("TL",   ("BR",)):"corner_ES", ("TR",("BL",)):"corner_WS",
    ("BL",   ("TR",)):"corner_EN", ("BR",("TL",)):"corner_WN",
    ("BLR",  ()):"end_N", ("TLR",()):"end_S", ("TBR",()):"end_W", ("TBL",()):"end_E",
    ("",     ("TL","TR","BL","BR")):"cross",
    ("T",    ("BL","BR")):"tee_S", ("B",("TL","TR")):"tee_N",
    ("L",    ("TR","BR")):"tee_E", ("R",("TL","BL")):"tee_W",
}
ALT = {"dirt_T_a":"dirt_T_b","dirt_B_a":"dirt_B_b","path_V_a":"path_V_b",
       "path_H_a":"path_H_b","dirt_C_a":"dirt_C_b"}


def pick(road, x, y):
    def R(a, b): return (a, b) in road
    n, s, w, e = R(x, y-1), R(x, y+1), R(x-1, y), R(x+1, y)
    nw, ne, sw, se = R(x-1, y-1), R(x+1, y-1), R(x-1, y+1), R(x+1, y+1)
    cons = ("" if n else "T") + ("" if s else "B") + ("" if w else "L") + ("" if e else "R")
    nubs = []
    if n and w and not nw: nubs.append("TL")
    if n and e and not ne: nubs.append("TR")
    if s and w and not sw: nubs.append("BL")
    if s and e and not se: nubs.append("BR")
    k = (cons, tuple(nubs))
    if k in LOOKUP: return LOOKUP[k], True
    if (cons, ()) in LOOKUP: return LOOKUP[(cons, ())], False   # nub 없는 근사
    return "dirt_C_a", False


def main():
    sheet = Image.open(SHEET).convert("RGB")
    COLS, ROWS = 18, 12
    out = Image.new("RGB", (COLS*64, ROWS*64))

    road = set()
    # 남쪽 입구 → 북쪽: 폭 2칸 큰길
    for y in range(6, 12):
        road.add((8, y)); road.add((9, y))
    # 랜드마크 앞 마당 (4x3)
    for y in range(3, 6):
        for x in range(7, 11): road.add((x, y))
    # 동쪽으로 갈라지는 좁은 오솔길
    for x in range(10, 16): road.add((x, 7))
    for y in range(4, 8): road.add((15, y))
    # 서쪽 막다른 갈래
    for x in range(4, 8): road.add((x, 9))

    miss = 0
    for y in range(ROWS):
        for x in range(COLS):
            if (x, y) in road:
                name, exact = pick(road, x, y)
                if not exact: miss += 1
                if (x + y) % 3 == 0 and name in ALT: name = ALT[name]
                # 흙 한복판에만 잔풀 변형을 섞는다 (가장자리 타일은 모양이 정해져 있다)
                if name in ("dirt_C_a", "dirt_C_b") and abs((x*40503) ^ (y*12289)) % 100 < 30:
                    name = "g_leaf"
            else:
                h = abs((x*73856093) ^ (y*19349663)) % 100
                name = "g_c" if h < 8 else ("g_b" if h < 30 else "g_a")
            c, r = KEY[name]
            out.paste(sheet.crop((c*64, r*64, c*64+64, r*64+64)), (x*64, y*64))
    out.save(os.path.join(S, "preview_scene.png"))
    print("근사로 떨어진 칸:", miss)

    # 반복 검사 — 같은 타일만 깐 판
    for nm in ("g_a", "dirt_C_a", "path_H_a"):
        c, r = KEY[nm]
        t = sheet.crop((c*64, r*64, c*64+64, r*64+64))
        rep = Image.new("RGB", (64*6, 64*4))
        for j in range(4):
            for i in range(6): rep.paste(t, (i*64, j*64))
        rep.save(os.path.join(S, "repeat_%s.png" % nm))
    print("ok")

main()
