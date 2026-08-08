"""소켓 문양 링 후보를 **실제 삼각진 위에 얹어** 본다.

🔴🔴 **낱장으로는 판정이 안 난다.** `triangle-circle-art.md` 의 판정 3·4·5 가 전부
「진 위에 얹었을 때」를 묻는다 — 잘리나 · 룬이 읽히나 · 둘이 갈리나.
⚠ 실제로 낱장만 보고 두 판을 헛돌렸다: 링에 테두리 원이 있어도 낱장에선 멀쩡해 보이는데,
 `draw_circle.triangle()` 이 **소켓 바깥 테두리(r=144)와 띠 안쪽 경계(r=96)를 이미 그리므로**
 얹으면 삼중선이 된다. ⇒ 문양 링이 그릴 것은 **그 두 원 사이를 채우는 무늬뿐**이다.

## 🔴 규격은 저절로 안 맞는다 — 재서 맞춘다

`마법진-그림.md` 가 「뽑은 뒤 재서 확인해야 한다」고 적어 둔 자리다. AI 는 안쪽 구멍 비율을
프롬프트대로 안 준다(2/3 을 요구해도 0.5~0.8 로 흔들린다) ⇒ **잉크의 반경 분포를 재서
바깥 잉크가 정확히 r=144 에 오도록 스케일한다.** 그래야 무늬가 소켓을 꽉 채운다.

⚠ **잘라 쓰는 것과 다르다**(문서 「조각을 붙이면 통짜만 못하다」의 경고). 잘라내면 무늬가
중간에서 끊기는데, 여기는 **통째로 줄여 맞추는 것**이라 무늬가 안 끊긴다.
🔴 다만 소켓 원 밖은 마스크로 자른다 — 안 자르면 링의 흰 배경이 **사각으로** 남는다(실측).

**곱하기로 얹는 이유**: 링 후보는 크림 배경에 검은 선이라 알파가 없다. 임계로 자르면
안티앨리어싱된 가장자리가 계단이 진다 ⇒ 밝기를 그대로 곱해 선만 남긴다.
⚠ 배경이 순백(255)이 아니라 크림이라 곱하면 소켓 안이 살짝 어두워진다 — **정규화로 편다.**
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))   # 리포 루트에서 불러도 draw_circle 을 찾게 한다

from draw_circle import S, at, triangle  # noqa: E402

SOCKET_R = 144   # 소켓 반지름 (지름 288 = 문양 링 에셋 크기)
BAND_IN = 96     # 문양 띠 안쪽 경계 = 144 − 48
DIST = 368       # 소켓 중심까지의 반지름
RUNE_D = 192     # 룬 심볼 = 288 − 48×2
INK = 160        # 이 밝기보다 어두우면 잉크로 센다


def _normalize(im):
    """배경을 흰색으로 편다. 안 하면 곱할 때마다 소켓이 한 겹씩 어두워진다.

    🔴 **최대 밝기로 나누면 부족하다** — 후보의 배경이 균일하지 않으면(생성 그림은 거의 늘 그렇다)
    가장 밝은 한 점만 255가 되고 **나머지 배경은 회색으로 남아 사각이 그대로 보인다**(실측: 룬 심볼).
    ⇒ **상위 2% 지점**을 흰색으로 잡아 배경 전체를 민다.
    """
    g = im.convert("L")
    a = np.asarray(g)
    hi = int(np.percentile(a, 98))
    if hi <= 0:
        return g
    return Image.eval(g, lambda v: min(255, v * 255 // hi))


def ink_radii(gray):
    """잉크가 걸쳐 있는 반경 구간을 이미지 반지름 대비 비율로 돌려준다.

    🔴 **행마다 세지 않고 반경 히스토그램으로 센다** — 무늬가 별 모양이면 특정 각도로만
    멀리 뻗어서, 최대 반경만 보면 그 한 가시가 전체를 대표해 버린다.
    ⇒ 그 반경 고리의 **잉크 비율**이 임계를 넘는 구간만 「링이 있다」로 본다.
    """
    a = np.asarray(gray, dtype=np.int16)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(yy - (h - 1) / 2, xx - (w - 1) / 2) / (min(h, w) / 2)
    bins = np.linspace(0, 1, 101)
    idx = np.clip(np.digitize(r.ravel(), bins) - 1, 0, 99)
    ink = (a.ravel() < INK).astype(np.float64)
    total = np.bincount(idx, minlength=100)
    hit = np.bincount(idx, weights=ink, minlength=100)
    frac = np.divide(hit, total, out=np.zeros(100), where=total > 0)
    live = np.nonzero(frac > 0.06)[0]
    if len(live) == 0:
        return 0.0, 1.0
    return bins[live[0]], bins[min(live[-1] + 1, 100)]


def fit_ring(patch, out_r=SOCKET_R):
    """링 후보를 소켓 좌표로 맞춘다 — 바깥 잉크가 `out_r` 에 오도록 통째로 스케일한다.

    돌려주는 것: (소켓 지름 크기의 회색 이미지, 안쪽 구멍 반지름). 안쪽 반지름은 부르는 쪽이
    `BAND_IN`(96) 과 대 봐서 **룬 자리를 침범하는지** 판단한다.
    """
    g = _normalize(patch)
    r_in, r_out = ink_radii(g)
    if r_out <= 0:
        r_out = 1.0
    # 원본에서 「바깥 잉크」가 이미지 반지름의 r_out 배에 있다 ⇒ 그것을 out_r 로 보낸다
    full = int(round(out_r * 2 / r_out))
    big = g.resize((full, full), Image.LANCZOS)
    box = (full - out_r * 2) // 2
    fit = big.crop((box, box, box + out_r * 2, box + out_r * 2))
    return fit, r_in / r_out * out_r


def _paste_masked(base, gray, center, size):
    """원 마스크로 곱해 얹는다. 🔴 마스크가 없으면 후보의 흰 배경이 **사각으로** 남는다(실측).
    ⚠ 링만이 아니라 룬 심볼도 그렇다 — 룬은 원형이 아니지만 배경은 사각이다."""
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    x, y = center
    box = (int(x - size / 2), int(y - size / 2))
    region = base.crop((box[0], box[1], box[0] + size, box[1] + size))
    mixed = ImageChops.multiply(region, gray.convert("RGB"))
    base.paste(Image.composite(mixed, region, mask), box)


def paste_socket(base, fit, center, out_r=SOCKET_R):
    _paste_masked(base, fit, center, out_r * 2)


def paste_plain(base, patch, center, size):
    """룬 심볼처럼 규격이 이미 맞는 것을 그대로 얹는다."""
    _paste_masked(base, _normalize(patch).resize((size, size), Image.LANCZOS), center, size)


def build(ring_path, rune_path=None, report=False):
    tri = triangle().resize((S, S), Image.LANCZOS).convert("RGB")
    fit, r_in = fit_ring(Image.open(ring_path))
    rune = Image.open(rune_path) if rune_path else None
    for ang in (-90, 30, 150):          # 12시 · 4시 · 8시
        cx, cy = at(ang, DIST)
        c = (cx / 4, cy / 4)            # at() 은 SS(4) 배율 좌표를 준다
        paste_socket(tri, fit, c)
        if rune is not None:
            paste_plain(tri, rune, c, RUNE_D)
    if report:
        mark = "OK" if r_in >= BAND_IN else "룬 자리 침범"
        print(f"  안쪽 구멍 r={r_in:.0f}  (띠 안쪽 경계 {BAND_IN})  {mark}  <- {Path(ring_path).name}")
    return tri


def save_asset(ring_path, out_path):
    """채택본을 **288 알파 png** 로 굳힌다 — 이것이 `assets/` 로 가는 파일이다.

    🔴 **알파로 굳히는 이유**: 후보는 크림 종이에 검은 선이라 배경이 불투명하다. 그대로 얹으면
    소켓 안이 사각으로 덮인다(미리보기는 곱하기로 피했지만 **게임에는 곱하기 합성이 없다**).
    ⇒ **밝기를 알파로 뒤집고 색은 진과 같은 먹색으로 고정**한다.
    ⚠ 임계로 자르지 않는다 — 안티앨리어싱된 가장자리가 계단이 진다.

    🔴 **소켓 원 밖은 지운다.** 368 + 144 = 512 라 여유가 0이고, 한 픽셀이라도 넘치면 잘린다.
    """
    fit, r_in = fit_ring(Image.open(ring_path))
    size = SOCKET_R * 2
    alpha = Image.eval(fit, lambda v: 255 - v)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    alpha = ImageChops.multiply(alpha, mask)
    ink = Image.new("RGB", (size, size), (26, 24, 22))   # draw_circle.FG 와 같은 먹색
    out = ink.convert("RGBA")
    out.putalpha(alpha)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    return r_in


if __name__ == "__main__":
    if sys.argv[1] == "--save":
        r_in = save_asset(sys.argv[2], sys.argv[3])
        print(f"  안쪽 구멍 r={r_in:.1f}  (띠 안쪽 경계 {BAND_IN}) -> {sys.argv[3]}")
    else:
        ring_path = sys.argv[1]
        rune_path = sys.argv[2] if len(sys.argv) > 2 else None
        out = HERE / "out" / "_socket_try.png"
        build(ring_path, rune_path, report=True).save(out)
        print(out)
