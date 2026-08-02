#!/usr/bin/env python3
"""🐺 늑대 인지음 합성기 — `growl`(경계)·`howl`(발견) 두 장을 만든다.

    python tools/gen_alert_sfx.py            # assets/audio/sfx/ 에 2장 생성 + 규격 표 출력
    python tools/gen_alert_sfx.py --dry-run  # 파일을 안 쓰고 규격만 재본다
    python tools/gen_alert_sfx.py --compare  # 기존 20종을 같이 재서 겹치는 자리를 확인한다

기존 SFX와 마찬가지로 **합성 플레이스홀더**다. 외부 패키지 없이 표준 라이브러리만 쓴다.

🔴 **둘이 뚜렷이 달라야 한다.** 인지는 경계(한 박자) → 발견(짖음) 2단계인데, 같게 들리면
플레이어가 지금 어느 단계인지 몰라 「피할 틈」이 있다는 걸 알 방법이 없다. 게다가 시야 밖의 적은
몸이 통째로 안 보여 **이 wav가 유일한 통보**인 경우가 있다.
길이·지배음·피치곡선·결·어택·대역 여섯 축을 전부 갈랐고, main()이 그 갈림을 스스로 검산한다.
**피치 곡선이 심장이다** — 올랐다 내려오는 윤곽은 다른 SFX에 없어서, 멀어서 감쇠해도·작은
스피커에서도 윤곽만으로 「짖었다」가 읽힌다.

⚠ 길이는 기존 최장(`death` 0.700s)을 안 넘긴다 — 늑대 다섯이 동시에 울 수 있어 길면 뭉갠다.
⚠ 이 스크립트는 결정적이다 — 시드가 고정이라 다시 돌려도 같은 파일이 나온다.
"""

from __future__ import annotations

import argparse
import math
import os
import random
import struct
import sys
import wave

# 🔴 규격·DSP는 **기존 생성기에서 그대로 빌린다.** 22050Hz·16bit·0.85 정규화·32767 스케일을
#   여기 다시 적으면 규격이 두 벌이 되어, 한쪽만 고쳐도 아무도 못 알아챈다.
#   ⚠ `gen_hit_sfx`는 `if __name__ == "__main__"` 가드가 있어 import해도 아무것도 실행되지 않는다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_hit_sfx import (  # noqa: E402
    SR, PEAK, OUT_DIR, _n,
    silence, noise, biquad, exp_decay, raised_cosine, mix,
    fade_edges, soft_clip, normalize, write_wav, measure,
)


# ── 목소리 합성 (인지음 전용 — 피격음엔 없던 도구) ────────────────

def voiced(
    seconds: float,
    pitch: "list[tuple[float, float]]",
    harmonics: "list[float]",
    vibrato_hz: float = 0.0,
    vibrato_cents: float = 0.0,
    rng: "random.Random | None" = None,
) -> "list[float]":
    """배음이 있는 「목소리」 — 피치가 시간에 따라 자유롭게 움직인다.

    🔴 `sine_sweep`을 안 쓰는 이유: 그건 단조 하강만 만든다. 짖음의 「올랐다 내려오는」 윤곽은
    브레이크포인트(pitch = [(시간비 0~1, Hz), …] · 사이는 smoothstep)를 이어야 나온다.

    위상을 **적분**으로 누적하는 게 중요하다 — 매 샘플 `sin(2π·f·t)`로 계산하면 f가 바뀔 때마다
    위상이 튀어 '지직'거린다(주파수 변조의 고전적 함정).
    @param harmonics 배음 진폭 [기음, 2배, 3배, …] · @param vibrato_cents 비브라토 깊이(센트).
    """
    total = _n(seconds)
    out = [0.0] * total
    phases = [0.0] * len(harmonics)
    vib_phase = 0.0
    for i in range(total):
        t = i / max(1, total - 1)

        # 브레이크포인트 보간 — smoothstep이라 이음매에서 피치가 꺾이지 않는다
        f = pitch[-1][1]
        for j in range(len(pitch) - 1):
            t0, f0 = pitch[j]
            t1, f1 = pitch[j + 1]
            if t0 <= t <= t1:
                u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
                u = u * u * (3.0 - 2.0 * u)
                f = f0 + (f1 - f0) * u
                break

        if vibrato_cents > 0.0:
            vib_phase += 2.0 * math.pi * vibrato_hz / SR
            f *= 2.0 ** (vibrato_cents * math.sin(vib_phase) / 1200.0)

        v = 0.0
        for h, amp in enumerate(harmonics):
            if amp == 0.0:
                continue
            phases[h] += 2.0 * math.pi * f * (h + 1) / SR
            v += math.sin(phases[h]) * amp
        out[i] = v
    return out


def am(xs: "list[float]", rate_hz: float, depth: float, shape: float = 1.0) -> "list[float]":
    """진폭 변조 — 「그르렁」의 정체. 성대가 불규칙하게 떨리는 결을 만든다.

    depth 1.0이면 완전히 끊기고, 0.5면 절반까지만 줄어든다.
    shape > 1이면 골이 넓고 마루가 뾰족해져 더 거칠게 들린다."""
    out = []
    for i, v in enumerate(xs):
        m = 0.5 + 0.5 * math.sin(2.0 * math.pi * rate_hz * i / SR)
        m = m ** shape
        out.append(v * (1.0 - depth + depth * m))
    return out


def ad_envelope(xs: "list[float]", attack: float, release: float, curve: float = 1.0) -> "list[float]":
    """어택-릴리즈 엔벨로프. 어택 곡선이 두 소리를 가르는 축 하나다
    (growl은 느리게 스며들고 howl은 빠르게 터진다)."""
    n = len(xs)
    a, r = _n(attack), _n(release)
    out = list(xs)
    for i in range(min(a, n)):
        out[i] *= (i / a) ** curve
    for i in range(min(r, n)):
        out[n - 1 - i] *= (i / r) ** 0.8
    return out


# ── 소리 둘 ──────────────────────────────────────────────────────

def make_growl() -> "list[float]":
    """🔈 GROWL — 낮게 그르렁 (ALERT 진입 · 「나를 눈치챘다」).

    **작고 낮고 가까운** 소리 — 위협의 절정(`howl`) 앞의 한 박자다.
    ⚠ 겹칠 위험이 가장 큰 상대는 `hit_earth`(dom ~75Hz) — AM 24Hz(임팩트엔 없는 지속하는 떨림) ·
    길이 0.30s(한 방이 아니라 이어지는 소리) · 어택 70ms(즉발이 아니다) 셋으로 갈랐다.
    """
    rng = random.Random(2051)
    dur = 0.30

    # 목소리 — 105Hz에서 아주 살짝 내려온다. 평평함 자체가 howl의 곡선과 대비된다.
    # 배음을 홀수 쪽에 실어(1·3배) 가슴에서 나는 어두운 소리를 만든다.
    body = voiced(
        dur,
        pitch=[(0.0, 112.0), (0.55, 105.0), (1.0, 96.0)],
        harmonics=[1.0, 0.34, 0.46, 0.16, 0.08],
        vibrato_hz=7.5, vibrato_cents=22.0, rng=rng,
    )
    # 🔴 성대 떨림 — 이 한 줄이 "낮은 톤"을 "그르렁"으로 바꾼다.
    body = am(body, 24.0, 0.55, shape=1.6)

    buf = silence(dur)
    mix(buf, body, 0.0, 1.00)

    # 그릿 — 목 안쪽이 거칠게 긁히는 결. 톤만 있으면 악기처럼 들린다.
    grit = biquad(noise(silence(dur), rng), "bp", 520.0, 0.75)
    grit = am(grit, 24.0, 0.72, shape=1.6)          # 몸통과 **같은 위상**으로 떨어야 한 몸이 된다
    mix(buf, grit, 0.0, 0.30)

    # 아주 얕은 숨 — 짐승의 호흡. 없으면 신시사이저 같다.
    breath = biquad(noise(silence(dur), rng), "bp", 1500.0, 0.5)
    mix(buf, exp_decay(breath, 0.14), 0.010, 0.075)

    buf = normalize(buf, 1.0)
    buf = soft_clip(buf, 1.5)
    buf = biquad(buf, "lp", 1200.0, 0.7)            # 위를 잘라 **어둡게** — howl의 정반대 자리
    buf = ad_envelope(buf, attack=0.070, release=0.085, curve=1.4)
    return fade_edges(buf, 0.0015, 0.012)


def make_howl() -> "list[float]":
    """🔊 HOWL — 「아우—」 (CHASE 진입 · 발견 확정 · 무리를 부른다).

    **크고 높고 멀리 가는** 소리 — 무리 전파의 통로라 「여럿에게 들린다」가 소리로 읽혀야 한다.
    🔴 **피치 곡선이 정체성이다**: 380 → 640 → 470Hz. 올랐다 내려오는 윤곽은 다른 SFX에 없어서
    거리 감쇠로 작아져도 윤곽만으로 구별된다 — 볼륨으로 구별하게 만들면 그때 growl과 뭉갠다.
    ⚠ `night`(0.600s)와 길이가 비슷하지만 그쪽은 밤 전환음이라 같은 순간에 안 난다.
    """
    rng = random.Random(2052)
    dur = 0.62

    # 🔴 올랐다 내려오는 목소리 — 마루를 앞쪽(0.42)에 두어 '아—우' 가 아니라 '아우—'가 된다.
    #   마루가 한가운데면 대칭이라 기계적으로 들린다.
    body = voiced(
        dur,
        pitch=[(0.0, 380.0), (0.18, 590.0), (0.42, 640.0), (0.72, 560.0), (1.0, 470.0)],
        harmonics=[1.0, 0.52, 0.26, 0.14, 0.07, 0.04],
        vibrato_hz=5.5, vibrato_cents=34.0, rng=rng,
    )
    buf = silence(dur)
    mix(buf, body, 0.0, 1.00)

    # 숨결 — 목소리에 실린 바람. 피치를 따라가지 않아 '살아있음'을 더한다.
    breath = biquad(noise(silence(dur), rng), "bp", 2600.0, 0.6)
    win = raised_cosine(len(breath))
    breath = [v * w for v, w in zip(breath, win)]
    mix(buf, breath, 0.0, 0.085)

    # 낮은 몸통 — 가슴 울림. 없으면 휘파람처럼 얇다.
    chest = voiced(dur, pitch=[(0.0, 190.0), (0.42, 320.0), (1.0, 235.0)],
                   harmonics=[1.0, 0.3], rng=rng)
    mix(buf, chest, 0.0, 0.26)

    buf = normalize(buf, 1.0)
    buf = soft_clip(buf, 1.7)
    buf = biquad(buf, "bp", 1150.0, 0.34)           # 500~3000을 살려 **멀리 가는 대역**에 앉힌다
    # 빠른 어택 — growl(70ms)의 정반대. 「터진다」가 「스며든다」와 갈리는 자리다.
    buf = ad_envelope(buf, attack=0.025, release=0.150, curve=0.85)
    return fade_edges(buf, 0.0010, 0.020)


SOUNDS = {
    "growl": make_growl,
    "howl": make_howl,
}


# ── 실측 · 검수 ───────────────────────────────────────────────────

def spectral_centroid(path: str) -> float:
    """스펙트럼 무게중심(Hz) — 「밝기」의 한 수치. 두 소리가 실제로 갈렸는지 재는 데 쓴다.

    외부 패키지 없이 재려고 **Goertzel 대신 소박한 DFT를 32밴드에만** 돌린다
    (전체 FFT가 필요 없다 — 무게중심은 거친 밴드로도 충분히 안정적이다)."""
    with wave.open(path, "rb") as w:
        n, sr = w.getnframes(), w.getframerate()
        raw = w.readframes(n)
    xs = [s / 32768.0 for s in struct.unpack("<%dh" % (len(raw) // 2), raw)]
    # 밴드 중심을 로그로 흩어 저역 해상도를 확보한다(50Hz~9kHz)
    bands = [50.0 * (9000.0 / 50.0) ** (k / 31.0) for k in range(32)]
    num = den = 0.0
    step = max(1, len(xs) // 4096)          # 길면 솎아낸다 — 무게중심엔 영향이 미미하다
    sub = xs[::step]
    eff_sr = sr / step
    for f in bands:
        re = im = 0.0
        for i, v in enumerate(sub):
            a = 2.0 * math.pi * f * i / eff_sr
            re += v * math.cos(a)
            im -= v * math.sin(a)
        mag = math.sqrt(re * re + im * im)
        num += f * mag
        den += mag
    return num / den if den > 0 else 0.0


def main() -> None:
    # ⚠ 윈도 콘솔 기본 코드페이지가 cp949라 한국어·이모지가 UnicodeEncodeError로 죽는다
    #   (파일은 이미 다 쓴 뒤 마지막 print에서 터져 "실패한 줄 알았는데 됐다"가 된다).
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    ap = argparse.ArgumentParser(description="늑대 인지음 2종(growl·howl) 합성")
    ap.add_argument("--dry-run", action="store_true", help="파일을 쓰지 않고 규격만 잰다")
    ap.add_argument("--compare", action="store_true", help="기존 SFX도 같이 재서 겹치는 자리를 본다")
    ap.add_argument("--out", default=OUT_DIR, help="출력 디렉터리")
    args = ap.parse_args()

    hdr = "%-11s %-6s %-5s %-4s %-7s %-7s %-7s %-7s %-9s %-9s"
    row = "%-11s %-6d %-5d %-4d %-7.3f %-7.4f %-7.4f %-7.0f %-9.1f %-9.0f"
    print(hdr % ("id", "sr", "bits", "ch", "dur(s)", "peak", "rms", "zcr/s", "attack(ms)", "centroid"))

    made = {}
    for name, fn in SOUNDS.items():
        xs = normalize(fn())
        path = os.path.normpath(os.path.join(args.out, name + ".wav"))
        probe = path + ".probe" if args.dry_run else path
        write_wav(probe, xs)
        m = measure(probe)
        c = spectral_centroid(probe)
        if args.dry_run:
            os.remove(probe)
        made[name] = (m, c)
        print(row % (name, m["sr"], m["bits"], m["ch"], m["dur"], m["peak"], m["rms"],
                     m["zcr"], m["attack_ms"], c))

    if args.compare:
        print("\n── 기존 SFX (겹치는 자리 확인) " + "─" * 40)
        d = os.path.normpath(args.out)
        for f in sorted(os.listdir(d)):
            if not f.endswith(".wav") or f[:-4] in SOUNDS:
                continue
            p = os.path.join(d, f)
            m = measure(p)
            c = spectral_centroid(p)
            print(row % (f[:-4], m["sr"], m["bits"], m["ch"], m["dur"], m["peak"], m["rms"],
                         m["zcr"], m["attack_ms"], c))

    # 🔴 「둘이 뚜렷이 다른가」를 스크립트가 스스로 검산한다.
    if len(made) == 2:
        g, h = made["growl"], made["howl"]
        dur_ratio = h[0]["dur"] / g[0]["dur"]
        cen_ratio = h[1] / g[1] if g[1] > 0 else 0.0
        atk_ratio = g[0]["attack_ms"] / max(0.1, h[0]["attack_ms"])
        print("\n── 갈림 검산 (설계 §8-6: 「둘이 뚜렷이 달라야 한다」) " + "─" * 16)
        print("  길이비        howl/growl = %.2f배   (목표 ≥ 1.8)  %s"
              % (dur_ratio, "OK" if dur_ratio >= 1.8 else "!! 너무 비슷하다"))
        print("  무게중심비    howl/growl = %.2f배   (목표 ≥ 2.0)  %s"
              % (cen_ratio, "OK" if cen_ratio >= 2.0 else "!! 너무 비슷하다"))
        print("  어택비        growl/howl = %.2f배   (목표 ≥ 2.0)  %s"
              % (atk_ratio, "OK" if atk_ratio >= 2.0 else "!! 너무 비슷하다"))

    if not args.dry_run:
        print("\n→ %s 에 2장 기록했다." % os.path.normpath(args.out))
        print("🔴 리드 몫: `--import`로 .import 사이드카 생성 + test_audio_auto.IDS 2줄")
        print("🔴 귀로만 확정되는 것: 둘이 실제로 구별되나 · 다섯 마리가 동시에 울 때 뭉개지나 (F5)")


if __name__ == "__main__":
    main()
