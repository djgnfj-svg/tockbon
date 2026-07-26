#!/usr/bin/env python3
"""스프라이트 규격 검사기 (세91) — 「선언만 있고 지켜지는지 아무도 안 쟀다」를 고치는 그물.

왜 이게 있나:
  `docs/ART_SPEC.md`가 *"모든 에셋을 Apollo 46색으로"*라 적어 둔 채 세18부터 살았는데,
  세91에 실측하니 **실제로 지키는 에셋은 잔디 타일 하나뿐**이었다(주인공·마법은 0%).
  원인은 세69 relight 후처리가 HSV 색조를 밀어 팔레트 밖 색을 만든 것. 아무도 재지 않아서
  세 세션 동안 몰랐다. → **규격은 문서가 아니라 이 파일이 정본이다.**

  정본 설계 = `docs/takbon-design/visual_language_design.md` §9~§11.

무엇을 재나 (§11-3 자가 검증 5항목):
  ① Apollo 46 밖의 색 개수      ② 실루엣 크기(프레임이 아니라 그림 자체)
  ③ 색 수(캐릭터 38~46 / 마법 8~14)  ④ 반투명 픽셀 수(하드 엣지 계약)
  ⑤ 디테일 밀도(색/100불투명px) — 이 게임의 캐릭터 기준선은 5 언저리다

⚠ 이 도구는 **「보인다」를 못 잰다** — 색이 예쁜지·실루엣이 읽히는지는 사람이 봐야 한다.
   여기 통과는 「규격 위반이 없다」는 뜻이지 「좋다」가 아니다.

사용:
  python tools/check_sprite_spec.py --kind char  assets/sprites/player/player_mage_sheet.png --frame 64x64
  python tools/check_sprite_spec.py --kind spell assets/sprites/effects/*.png --frame 92x48
  python tools/check_sprite_spec.py --kind any   assets/sprites/base/*.png          # 팔레트만 본다
"""
import argparse
import glob
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow가 필요하다: pip install pillow")

# 🔴 정본 = TAKBON 60 (세91 사용자 확정). Apollo 46은 이 60색의 **부분집합**이라 옛 에셋도 그대로 잰다.
#   apollo.gpl은 출처 기록으로 남겨 뒀을 뿐 — 새 에셋의 기준이 아니다.
PALETTE_PATH = os.path.join("assets", "aseprite", "takbon.gpl")

# 종류별 기대치 — 정본은 visual_language_design.md §9~§10.
# ⚠ 값을 여기서 고칠 땐 그 문서도 같이 고쳐라(둘로 갈리면 이 도구가 거짓말을 시작한다).
# silhouette = (폭, 높이). 🔴 폭이 None이면 안 잰다 — 캐릭터 폭은 자세마다 달라야 정상이고,
# 박아두면 팔을 벌린 run 프레임에서 거짓 빨강이 난다(리드가 실제로 한 번 박았다가 걷었다).
KINDS = {
    "char":  dict(colors=(38, 46), silhouette=(None, 56), density=(3.5, 7.0), tol=2),
    "spell": dict(colors=(8, 14),  silhouette=(56, 28),   density=(None, None), tol=2),
    "any":   dict(colors=(None, None), silhouette=None,   density=(None, None), tol=0),
}


def load_palette(path):
    cols = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 3 and parts[0].isdigit():
                cols.add((int(parts[0]), int(parts[1]), int(parts[2])))
    return cols


def frame_boxes(im, fw, fh):
    """시트를 프레임으로 자른다. fw/fh가 없으면 통째로 한 장."""
    if not fw or not fh:
        return [(0, 0, im.width, im.height)]
    return [(x, y, x + fw, y + fh)
            for y in range(0, im.height, fh)
            for x in range(0, im.width, fw)]


def measure(im):
    px = list(im.getdata())
    opaque = [p for p in px if p[3] > 0]
    semi = sum(1 for p in px if 0 < p[3] < 255)
    cols = set((p[0], p[1], p[2]) for p in opaque)
    dens = len(cols) / (len(opaque) / 100.0) if opaque else 0.0
    return cols, semi, len(opaque), dens


def check_one(path, kind, fw, fh, palette):
    spec = KINDS[kind]
    im = Image.open(path).convert("RGBA")
    problems = []
    notes = []

    boxes = frame_boxes(im, fw, fh)
    cols, semi, n_opaque, _ = measure(im)
    if not n_opaque:
        return [f"{path}: 불투명 픽셀이 0개다 (빈 이미지)"], []

    # 🔴 밀도는 **프레임 하나** 기준이다 — 시트 통째로 재면 불투명 픽셀이 프레임 수만큼 불어나
    # 밀도가 그만큼 나눠져 **멀쩡한 그림이 FAIL로 찍힌다**(리드가 실제로 밟았다: 44색 시트가
    # 11프레임이라 4.07 → 0.37로 보였다). 색 수·팔레트는 시트 전체로 재는 게 맞다(그림이 쓰는 총량).
    dens_list = []
    for box in boxes:
        fr = im.crop(box)
        f_cols, _, f_opaque, f_dens = measure(fr)
        if f_opaque:
            dens_list.append(f_dens)
    dens_list.sort()
    dens = dens_list[len(dens_list) // 2] if dens_list else 0.0

    outside = sorted(c for c in cols if c not in palette)
    if outside:
        shown = ", ".join("%02X%02X%02X" % c for c in outside[:6])
        more = f" 외 {len(outside) - 6}색" if len(outside) > 6 else ""
        problems.append(f"팔레트 밖 색 {len(outside)}개 ({shown}{more})")

    if semi:
        problems.append(f"반투명 픽셀 {semi}개 — 알파는 0 아니면 255다 (하드 엣지 계약)")

    lo, hi = spec["colors"]
    if lo is not None and not (lo <= len(cols) <= hi):
        problems.append(f"색 수 {len(cols)} — 기대 {lo}~{hi}")

    dlo, dhi = spec["density"]
    if dlo is not None and not (dlo <= dens <= dhi):
        problems.append(f"디테일 밀도 {dens:.2f} — 기대 {dlo}~{dhi} (색/100불투명px)")

    # 실루엣: 프레임마다 그림 자체의 바운딩박스를 잰다.
    # 🔴 프레임 크기가 아니다 — 그 둘을 헷갈린 것이 세90 사고의 원인이다.
    if spec["silhouette"]:
        want_w, want_h = spec["silhouette"]
        tol = spec["tol"]
        mw = mh = 0
        for box in boxes:
            bb = im.crop(box).getbbox()
            if bb:
                mw = max(mw, bb[2] - bb[0])
                mh = max(mh, bb[3] - bb[1])
        if abs(mh - want_h) > tol:
            problems.append(f"실루엣 높이 {mh}px — 기대 {want_h}±{tol}")
        if want_w and abs(mw - want_w) > tol:
            problems.append(f"실루엣 폭 {mw}px — 기대 {want_w}±{tol}")
        notes.append(f"실루엣 {mw}x{mh}")

    notes.append(f"{len(cols)}색")
    notes.append(f"밀도 {dens:.2f}")
    return problems, notes


def main():
    ap = argparse.ArgumentParser(description="스프라이트 규격 검사 (탁본 세91)")
    ap.add_argument("paths", nargs="+", help="PNG 경로 (glob 가능)")
    ap.add_argument("--kind", choices=sorted(KINDS), default="any",
                    help="char=캐릭터 · spell=마법 볼 · any=팔레트/알파만")
    ap.add_argument("--frame", default="", help="프레임 크기 WxH (시트일 때). 없으면 통째로 잰다")
    ap.add_argument("--palette", default=PALETTE_PATH)
    args = ap.parse_args()

    if not os.path.exists(args.palette):
        sys.exit(f"팔레트를 못 찾았다: {args.palette}")
    palette = load_palette(args.palette)

    fw = fh = None
    if args.frame:
        try:
            fw, fh = (int(v) for v in args.frame.lower().split("x"))
        except ValueError:
            sys.exit("--frame 은 64x64 형식이다")

    targets = []
    for p in args.paths:
        targets.extend(sorted(glob.glob(p)) if any(c in p for c in "*?[") else [p])
    targets = [t for t in targets if t.lower().endswith(".png")]
    if not targets:
        sys.exit("검사할 PNG가 없다")

    print(f"팔레트 {len(palette)}색 · 종류 {args.kind}" + (f" · 프레임 {fw}x{fh}" if fw else ""))
    failed = 0
    for t in targets:
        if not os.path.exists(t):
            print(f"  [없음] {t}")
            failed += 1
            continue
        problems, notes = check_one(t, args.kind, fw, fh, palette)
        name = os.path.basename(t)
        tail = "  (" + " · ".join(notes) + ")" if notes else ""
        if problems:
            failed += 1
            print(f"  [FAIL] {name}{tail}")
            for pr in problems:
                print(f"         - {pr}")
        else:
            print(f"  [ OK ] {name}{tail}")

    print(f"\n{len(targets) - failed}/{len(targets)} 통과")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
