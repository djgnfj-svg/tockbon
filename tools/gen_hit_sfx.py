#!/usr/bin/env python3
"""🔊 룬 피격음 합성기 — BOLT·EARTH·GRASS 세 장을 만든다.

    python tools/gen_hit_sfx.py            # assets/audio/sfx/ 에 3장 생성 + 규격 표 출력
    python tools/gen_hit_sfx.py --dry-run  # 파일을 안 쓰고 규격만 재본다

기존 SFX와 마찬가지로 **합성 플레이스홀더**다. 외부 패키지 없이 표준 라이브러리만 쓴다.
규격(22050Hz·16bit·mono·피크 0.85 정규화)은 추측이 아니라 기존 SFX 실측값이다.

🔴 셋이 기존 피격음과 안 뭉개지게 구분 축을 일부러 갈랐다 — ⓐ 스펙트럼 무게중심(75Hz↔7kHz)
ⓑ 어택(0ms 즉발 ↔ 18ms 스웰) ⓒ 엔벨로프 결(매끈한 감쇠 ↔ 계단형 크랙 ↔ 톱니형 그레인).

⚠ 길이는 기존 최장(hit_wind 0.200s)을 넘기지 않는다 — 연타되고 피치가 흔들려 길면 겹쳐 뭉갠다.
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

SR = 22050          # 기존 17종 전부 22050Hz (실측)
PEAK = 0.85         # 기존 4장의 피크가 정확히 이 값으로 정규화돼 있다 (실측 0.8499)
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")


# ── DSP 조각 (표준 라이브러리만) ──────────────────────────────────

def _n(seconds: float) -> int:
    return int(round(seconds * SR))


def silence(seconds: float) -> list[float]:
    return [0.0] * _n(seconds)


def noise(buf: list[float], rng: random.Random) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in buf]


def biquad(xs: list[float], kind: str, f0: float, q: float) -> list[float]:
    """RBJ 쿡북 바이쿼드. Chamberlin SVF와 달리 22050Hz에서 8kHz까지 안정적이라
    고역(번개)과 저역(흙)을 같은 코드로 다룰 수 있다."""
    f0 = max(20.0, min(f0, SR * 0.45))
    w0 = 2.0 * math.pi * f0 / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "lp":
        b0, b1, b2 = (1.0 - cw) / 2.0, 1.0 - cw, (1.0 - cw) / 2.0
    elif kind == "hp":
        b0, b1, b2 = (1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0
    elif kind == "bp":                      # 0dB 피크
        b0, b1, b2 = alpha, 0.0, -alpha
    else:
        raise ValueError(kind)
    a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in xs:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def exp_decay(buf: list[float], tau: float, start: int = 0) -> list[float]:
    """start 샘플부터 시작하는 지수 감쇠를 곱한다 (그 앞은 0)."""
    out = []
    for i, v in enumerate(buf):
        out.append(0.0 if i < start else v * math.exp(-(i - start) / (tau * SR)))
    return out


def sine_sweep(seconds: float, f_start: float, f_end: float, tau: float, curve: float = 1.0) -> list[float]:
    """지수적으로 피치가 내려가는 사인 + 지수 감쇠. 번개의 'zzt'와 흙의 '쿵'이 같은 도구다."""
    out = []
    phase = 0.0
    total = _n(seconds)
    for i in range(total):
        t = i / total
        f = f_end + (f_start - f_end) * math.exp(-curve * t * 5.0)
        phase += 2.0 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-(i / SR) / tau))
    return out


def raised_cosine(length: int) -> list[float]:
    """0→1→0 부드러운 창 (클릭 방지 · 그레인 엔벨로프)."""
    if length <= 1:
        return [0.0] * max(0, length)
    return [0.5 - 0.5 * math.cos(2.0 * math.pi * i / (length - 1)) for i in range(length)]


def mix(dst: list[float], src: list[float], at: float = 0.0, gain: float = 1.0) -> None:
    off = _n(at)
    for i, v in enumerate(src):
        j = off + i
        if 0 <= j < len(dst):
            dst[j] += v * gain


def fade_edges(xs: list[float], head: float = 0.0015, tail: float = 0.008) -> list[float]:
    """머리·꼬리를 0으로 붙인다 — 안 하면 잘린 파형이 '틱' 하고 튄다."""
    h, t = _n(head), _n(tail)
    out = list(xs)
    for i in range(min(h, len(out))):
        out[i] *= i / h
    for i in range(min(t, len(out))):
        out[len(out) - 1 - i] *= i / t
    return out


def soft_clip(xs: list[float], drive: float = 1.0) -> list[float]:
    """tanh 새추레이션. 튀는 트랜지언트를 둥글려 **크레스트를 낮춘다**.

    피크를 0.85로 고정하는 이 파이프라인에선 크레스트가 곧 체감 볼륨이다 — 그레인 하나가
    튀면 그것만 크고 전체는 기존 셋보다 조용해진다. 덤으로 결이 부드러워져 GRASS에 맞는다."""
    return [math.tanh(v * drive) / math.tanh(drive) for v in xs]


def normalize(xs: list[float], peak: float = PEAK) -> list[float]:
    m = max((abs(v) for v in xs), default=0.0)
    if m <= 0.0:
        return xs
    k = peak / m
    return [v * k for v in xs]


# ── 소리 셋 ──────────────────────────────────────────────────────

def make_bolt() -> list[float]:
    """⚡ BOLT — 짧고 날카로운 전기 크랙 '따-닥'.

    hit_fire도 노이즈 버스트라 뭉갤 위험이 크다 — 길이 0.070s(가장 짧다) · 3500Hz 하이패스로
    무게중심을 fire(3955Hz) 위로 · 임펄스 셋(0·11·26ms)이라 엔벨로프가 계단 · 5200→1400Hz
    하강 처프로 '음정'을 실어 넷으로 갈랐다.
    """
    rng = random.Random(1041)
    buf = silence(0.070)

    for at, amp, tau in ((0.000, 1.00, 0.0055), (0.011, 0.52, 0.0038), (0.026, 0.26, 0.0030)):
        n = noise(silence(0.030), rng)
        n = biquad(n, "hp", 3500.0, 0.8)
        n = exp_decay(n, tau)
        mix(buf, n, at, amp)

    # 전기 'zzt' — 노이즈만으론 번개가 아니라 그냥 잡음이 된다.
    zap = sine_sweep(0.045, 5200.0, 1400.0, 0.012, curve=1.4)
    mix(buf, zap, 0.0, 0.26)

    # 아주 얕은 저역 몸통(때린 느낌) — 흙과 겹치지 않게 아주 작게만.
    body = sine_sweep(0.040, 420.0, 190.0, 0.010)
    mix(buf, body, 0.0, 0.10)

    buf = biquad(buf, "hp", 900.0, 0.7)   # 저역을 걷어 EARTH와 확실히 갈라놓는다
    return fade_edges(buf, 0.0005, 0.010)


def make_earth() -> list[float]:
    """🪨 EARTH — 낮고 둔탁한 흙 임팩트 '퍼억'.

    기본음 hit(188Hz)과 겹칠 위험이 크다 — 지배음 ~75Hz(한 옥타브 아래) · 그릿(350Hz 대역
    노이즈 급감쇠) · 1600Hz 로우패스(BOLT의 정반대 자리) 셋으로 갈랐다.
    """
    rng = random.Random(1042)
    buf = silence(0.140)

    # 몸통: 190→72Hz로 떨어지는 처프 = 무거운 '쿵'
    # ⚠ 바닥을 55Hz까지 내리지 마라 — 0-200Hz에 90%가 몰려 노트북 스피커에서 안 들린다.
    #   72Hz로 올리고 아래 배음·그릿을 키워 200-500Hz에 들을 거리를 남긴다.
    mix(buf, sine_sweep(0.130, 190.0, 72.0, 0.046, curve=1.8), 0.0, 1.00)
    # 2배음 — 작은 스피커는 기음을 못 내도 이 배음으로 피치를 복원해 듣는다
    mix(buf, sine_sweep(0.080, 380.0, 150.0, 0.026, curve=1.8), 0.0, 0.42)

    # 그릿: 흙·자갈이 부서지는 결
    grit = biquad(noise(silence(0.060), rng), "bp", 350.0, 0.8)
    mix(buf, exp_decay(grit, 0.026), 0.0, 0.72)

    # 어택 트랜지언트 '퍽' — 없으면 임팩트가 아니라 그냥 저음이 된다
    tick = biquad(noise(silence(0.012), rng), "lp", 900.0, 0.7)
    mix(buf, exp_decay(tick, 0.0035), 0.0, 0.34)

    buf = normalize(buf, 1.0)
    # 새추레이션은 여기선 볼륨뿐 아니라 **가청성**이다 — 75Hz 기음에 배음을 얹어
    # 저역을 못 내는 작은 스피커에서도 '쿵'이 살아남는다.
    buf = soft_clip(buf, 1.9)
    buf = biquad(buf, "lp", 1600.0, 0.7)
    return fade_edges(buf, 0.0008, 0.014)


def make_grass() -> list[float]:
    """🌿 GRASS — 부드럽게 바스락 '사삭'.

    hit_wind(매끈한 스웰)와 겹칠 위험이 크다 — 그레인 26개(엔벨로프가 톱니) · 5200Hz 로우패스
    ('쉭'이 아닌 '사삭') · 길이 0.150s·어택 ~18ms 셋으로 갈랐다.
    """
    rng = random.Random(1043)
    buf = silence(0.150)

    # 잎이 스치는 입자들 — 위치·길이·세기를 흩어 기계적인 반복감을 없앤다
    for _ in range(26):
        at = rng.uniform(0.0, 0.108)
        dur = rng.uniform(0.003, 0.006)
        g = noise(silence(dur), rng)
        g = biquad(g, "bp", rng.uniform(1900.0, 3600.0), 0.7)
        win = raised_cosine(len(g))
        g = [v * w for v, w in zip(g, win)]
        # 앞쪽 그레인이 더 세다 — 맞은 순간이 가장 크게 스친다.
        # ⚠ 진폭 편차를 좁게(0.5~0.9) 잡는 이유는 볼륨이다: 피크를 0.85로 정규화하므로
        #   튀는 그레인 하나가 있으면 그것만 크고 전체 RMS가 기존 셋보다 조용해진다.
        mix(buf, g, at, rng.uniform(0.5, 0.9) * math.exp(-at / 0.090))

    # 바탕 러슬 — 그레인만 있으면 '틱틱'거려서 잎 두께가 없다
    bed = biquad(noise(silence(0.130), rng), "bp", 2400.0, 0.5)
    bed = exp_decay(bed, 0.055)
    mix(buf, bed, 0.004, 1.00)

    # 낮은 몸통 — 풀이 눌리는 두께
    low = biquad(noise(silence(0.090), rng), "bp", 700.0, 0.9)
    mix(buf, exp_decay(low, 0.038), 0.006, 0.45)

    buf = normalize(buf, 1.0)
    buf = soft_clip(buf, 2.2)          # 그레인 튐을 둥글려 hit_wind와 볼륨을 맞춘다
    buf = biquad(buf, "lp", 5200.0, 0.7)

    # 부드러운 어택 — 즉발이면 BOLT 쪽으로 읽힌다
    a = _n(0.018)
    for i in range(min(a, len(buf))):
        buf[i] *= (i / a) ** 1.5
    return fade_edges(buf, 0.0005, 0.016)


SOUNDS = {
    "hit_bolt": make_bolt,
    "hit_earth": make_earth,
    "hit_grass": make_grass,
}


# ── 쓰기 · 실측 ───────────────────────────────────────────────────

def write_wav(path: str, xs: list[float]) -> None:
    """22050Hz·16bit·mono·캐논 44바이트 헤더 (기존 17종과 동일).

    ⚠ 스케일이 32768이 아니라 **32767**이다 — 기존 4장의 정수 피크가 전부 정확히 27851
    (= int(0.85 * 32767))이라 같은 관례를 따랐다. 32768로 쓰면 27852가 나와 1LSB 어긋난다."""
    frames = struct.pack("<%dh" % len(xs), *[max(-32768, min(32767, int(v * 32767.0))) for v in xs])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def measure(path: str) -> dict:
    with wave.open(path, "rb") as w:
        nch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    xs = [s / 32768.0 for s in struct.unpack("<%dh" % (len(raw) // 2), raw)]
    peak = max(abs(v) for v in xs)
    r = math.sqrt(sum(v * v for v in xs) / len(xs))
    zc = sum(1 for i in range(1, len(xs)) if (xs[i - 1] < 0) != (xs[i] < 0))
    atk = 0.0
    for i, v in enumerate(xs):
        if abs(v) >= peak * 0.9:
            atk = i / sr * 1000.0
            break
    return dict(sr=sr, bits=sw * 8, ch=nch, frames=n, dur=n / sr,
                peak=peak, rms=r, zcr=zc / (n / sr), attack_ms=atk)


def main() -> None:
    # ⚠ 윈도 콘솔 기본 코드페이지가 cp949라 한국어 주석·이모지가 UnicodeEncodeError로 죽는다
    #   (파일은 이미 다 쓴 뒤에 마지막 print에서 터져서 "실패한 줄 알았는데 됐다"가 된다).
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    ap = argparse.ArgumentParser(description="룬 피격음 3종(BOLT·EARTH·GRASS) 합성")
    ap.add_argument("--dry-run", action="store_true", help="파일을 쓰지 않고 규격만 잰다")
    ap.add_argument("--out", default=OUT_DIR, help="출력 디렉터리")
    args = ap.parse_args()

    print("%-11s %-6s %-5s %-4s %-7s %-7s %-7s %-7s %-8s"
          % ("id", "sr", "bits", "ch", "dur(s)", "peak", "rms", "zcr/s", "attack"))
    for name, fn in SOUNDS.items():
        xs = normalize(fn())
        path = os.path.normpath(os.path.join(args.out, name + ".wav"))
        if args.dry_run:
            tmp = path + ".probe"
            write_wav(tmp, xs)
            m = measure(tmp)
            os.remove(tmp)
        else:
            write_wav(path, xs)
            m = measure(path)
        print("%-11s %-6d %-5d %-4d %-7.3f %-7.4f %-7.4f %-7.0f %-8.1fms"
              % (name, m["sr"], m["bits"], m["ch"], m["dur"], m["peak"], m["rms"],
                 m["zcr"], m["attack_ms"]))
    if not args.dry_run:
        print("\n→ %s 에 3장 기록했다." % os.path.normpath(args.out))
        print("🔴 리드 몫: `--import`로 .import 사이드카 생성 + audio.gd `match` 3줄 + test_audio_auto.IDS")


if __name__ == "__main__":
    main()
