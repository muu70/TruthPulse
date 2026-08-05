#!/usr/bin/env python3
"""
TruthPulse 効果音ジェネレータ

音源ファイルを外部から持ち込まず、すべてこのスクリプトで合成します。
理由:
  - ライセンスの心配がない
  - 定数を変えるだけで全体のトーンを調整できる（リポジトリで差分が追える）
  - 嘘発見器という題材に「合成音」が素直に合う

使い方:
    python3 tools/generate_sounds.py

出力先: TruthPulse/Resources/sfx_<セット>_<名前>.wav

セットは 2 種類:
  variety  … バラエティ番組風。ピンポーン / ブブー など、周りを巻き込む音
  clinical … 計測器ライク。無機質な電子音だけ
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "TruthPulse", "Resources"
)

# ---------------------------------------------------------------- primitives

def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def sine(freq, duration, amp=1.0, phase=0.0):
    n = int(SAMPLE_RATE * duration)
    w = 2 * math.pi * freq / SAMPLE_RATE
    return [amp * math.sin(w * i + phase) for i in range(n)]


def square(freq, duration, amp=1.0, harmonics=7):
    """奇数倍音を足した擬似矩形波。生の矩形波よりエイリアスが少ない。"""
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    k = 1
    while k <= harmonics * 2:
        w = 2 * math.pi * freq * k / SAMPLE_RATE
        gain = amp / k
        for i in range(n):
            out[i] += gain * math.sin(w * i)
        k += 2
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def sweep(f0, f1, duration, amp=1.0):
    """線形の周波数スイープ。位相を積分して連続させる。"""
    n = int(SAMPLE_RATE * duration)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SAMPLE_RATE
        out.append(amp * math.sin(phase))
    return out


def noise(duration, amp=1.0, seed=1):
    """線形合同法の疑似乱数。numpy に依存しないため自前。"""
    n = int(SAMPLE_RATE * duration)
    out = []
    state = seed
    for _ in range(n):
        state = (1103515245 * state + 12345) % (1 << 31)
        out.append(amp * ((state / (1 << 30)) - 1.0))
    return out


# ---------------------------------------------------------------- shaping

def envelope(samples, attack=0.005, decay=None, sustain=0.0, release=0.05):
    """attack / decay / release だけの簡易エンベロープ。"""
    n = len(samples)
    a = max(1, int(SAMPLE_RATE * attack))
    r = max(1, int(SAMPLE_RATE * release))
    d = int(SAMPLE_RATE * decay) if decay is not None else max(0, n - a - r)

    out = []
    for i, v in enumerate(samples):
        if i < a:
            g = i / a
        elif i < a + d:
            t = (i - a) / max(1, d)
            g = 1.0 - (1.0 - sustain) * t
        elif i >= n - r:
            t = (i - (n - r)) / r
            g = max(0.0, (sustain if d > 0 else 1.0) * (1.0 - t))
        else:
            g = sustain if d > 0 else 1.0
        out.append(v * g)
    return out


def exp_decay(samples, tau=0.25):
    """鐘のような自然減衰。"""
    return [v * math.exp(-i / SAMPLE_RATE / tau) for i, v in enumerate(samples)]


def tremolo(samples, rate, depth=0.5):
    out = []
    for i, v in enumerate(samples):
        m = 1.0 - depth * 0.5 * (1 - math.cos(2 * math.pi * rate * i / SAMPLE_RATE))
        out.append(v * m)
    return out


def lowpass(samples, cutoff):
    """1次 IIR。ノイズをざらつかせすぎないため。"""
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = []
    prev = 0.0
    for v in samples:
        prev = prev + alpha * (v - prev)
        out.append(prev)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def join(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def loopable(samples, fade=0.02):
    """先頭と末尾をクロスフェードして、繰り返しても継ぎ目が出ないようにする。"""
    f = int(SAMPLE_RATE * fade)
    if f * 2 >= len(samples):
        return samples
    out = list(samples)
    for i in range(f):
        g = i / f
        out[i] = out[i] * g + out[len(out) - f + i] * (1 - g)
    return out[: len(out) - f]


def normalize(samples, peak=0.85):
    m = max(abs(v) for v in samples) or 1.0
    return [v / m * peak for v in samples]


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples
    )
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(frames)
    kb = os.path.getsize(path) / 1024
    print(f"  {name}.wav  {len(samples)/SAMPLE_RATE:.2f}s  {kb:.0f}KB")


# ---------------------------------------------------------------- variety set

def variety():
    print("variety（バラエティ番組風）")

    # 選択：やわらかいポップ
    write_wav("sfx_variety_select", normalize(
        exp_decay(sine(760, 0.06), tau=0.02), 0.5))

    # 開始：上昇3音
    start = join(
        exp_decay(sine(523, 0.09), tau=0.05),
        exp_decay(sine(659, 0.09), tau=0.05),
        exp_decay(sine(784, 0.16), tau=0.10),
    )
    write_wav("sfx_variety_start", normalize(start, 0.7))

    # 心拍：低くて短い「ドクン」
    beat = mix(
        exp_decay(sine(52, 0.16), tau=0.05),
        exp_decay(sine(78, 0.10, amp=0.5), tau=0.03),
        exp_decay(lowpass(noise(0.02, 0.3, seed=7), 900), tau=0.008),
    )
    write_wav("sfx_variety_heartbeat", normalize(beat, 0.75))

    # 計測中ループ：ドラムロール風の緊張感（2秒シームレス）
    roll = mix(
        lowpass(noise(2.0, 0.55, seed=3), 420),
        sine(48, 2.0, amp=0.35),
    )
    roll = tremolo(roll, rate=13, depth=0.6)
    write_wav("sfx_variety_scan", normalize(loopable(roll), 0.42))

    # ロック成立：上昇2音
    lock = join(
        exp_decay(sine(880, 0.07), tau=0.04),
        exp_decay(sine(1320, 0.14), tau=0.07),
    )
    write_wav("sfx_variety_lock", normalize(lock, 0.6))

    # 警告：短いブザー
    write_wav("sfx_variety_alert", normalize(
        envelope(square(196, 0.22), attack=0.004, release=0.06), 0.6))

    # 解析中ループ：上昇スイープの繰り返し
    an = sweep(320, 1150, 0.75, amp=0.6)
    an = envelope(an, attack=0.05, release=0.12)
    write_wav("sfx_variety_analyzing", normalize(loopable(an, 0.03), 0.5))

    # 正解：ピンポーン（高→低の鐘）
    bell1 = mix(exp_decay(sine(1318, 0.55), tau=0.30),
                exp_decay(sine(2637, 0.55, amp=0.28), tau=0.16))
    bell2 = mix(exp_decay(sine(1046, 1.10), tau=0.48),
                exp_decay(sine(2093, 1.10, amp=0.26), tau=0.24))
    write_wav("sfx_variety_truth", normalize(join(bell1, bell2), 0.8))

    # 不正解：ブブー（低い矩形波2発）
    buzz = square(165, 0.28, amp=0.9)
    buzz = envelope(buzz, attack=0.004, release=0.05)
    write_wav("sfx_variety_lie", normalize(
        join(buzz, silence(0.06), buzz), 0.8))


# ---------------------------------------------------------------- clinical set

def clinical():
    print("clinical（計測器ライク）")

    write_wav("sfx_clinical_select", normalize(
        envelope(sine(1200, 0.028), attack=0.002, release=0.012), 0.35))

    write_wav("sfx_clinical_start", normalize(
        envelope(sine(880, 0.13), attack=0.004, release=0.04), 0.5))

    beat = mix(
        exp_decay(sine(44, 0.13), tau=0.035),
        exp_decay(lowpass(noise(0.012, 0.22, seed=11), 1600), tau=0.005),
    )
    write_wav("sfx_clinical_heartbeat", normalize(beat, 0.55))

    hum = mix(
        sine(100, 2.0, amp=0.5),
        sine(201, 2.0, amp=0.12),
        lowpass(noise(2.0, 0.10, seed=5), 220),
    )
    hum = tremolo(hum, rate=2, depth=0.35)
    write_wav("sfx_clinical_scan", normalize(loopable(hum), 0.30))

    lock = join(
        envelope(sine(1500, 0.05), attack=0.002, release=0.02),
        silence(0.04),
        envelope(sine(1500, 0.05), attack=0.002, release=0.02),
    )
    write_wav("sfx_clinical_lock", normalize(lock, 0.5))

    blip = envelope(sine(700, 0.07), attack=0.003, release=0.025)
    write_wav("sfx_clinical_alert", normalize(
        join(blip, silence(0.05), blip, silence(0.05), blip), 0.55))

    an = join(
        envelope(sine(420, 0.14), attack=0.01, release=0.05),
        silence(0.10),
        envelope(sine(620, 0.14), attack=0.01, release=0.05),
        silence(0.10),
    )
    write_wav("sfx_clinical_analyzing", normalize(loopable(an, 0.015), 0.40))

    ok = envelope(sine(1000, 0.10), attack=0.003, release=0.03)
    write_wav("sfx_clinical_truth", normalize(
        join(ok, silence(0.06), ok), 0.6))

    ng = mix(sine(196, 0.65, amp=0.8), sine(98, 0.65, amp=0.4))
    write_wav("sfx_clinical_lie", normalize(
        envelope(ng, attack=0.005, release=0.15), 0.65))


if __name__ == "__main__":
    variety()
    clinical()
    print(f"\n出力先: {OUT_DIR}")
