#!/usr/bin/env python3
"""Original bed + SFX for Keyboard Filter promo. No third-party samples."""
from pathlib import Path
import math
import numpy as np
from numpy.fft import rfft, irfft

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "media" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def w(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    import wave
    with wave.open(str(path), "w") as f:
        f.setnchannels(1 if x.ndim == 1 else x.shape[1])
        f.setsampwidth(2)
        f.setframerate(sr)
        if x.ndim == 1:
            f.writeframes(pcm.tobytes())
        else:
            f.writeframes(pcm.reshape(-1, x.shape[1]).tobytes())


def env(n, a=0.01, r=0.2):
    e = np.ones(n)
    na, nr = int(a * n), int(r * n)
    if na > 0:
        e[:na] = np.linspace(0, 1, na)
    if nr > 0:
        e[-nr:] = np.linspace(1, 0, nr)
    return e


def sine(f, t, p=0.0):
    return np.sin(2 * math.pi * f * t + p)


def noise(n):
    return np.random.default_rng(7).standard_normal(n).astype(np.float64)


def lp(x, cutoff, sr=SR):
    # one-pole
    rc = 1 / (2 * math.pi * cutoff)
    dt = 1 / sr
    a = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def pad_tone(freq, dur, amp=0.12):
    t = np.arange(int(dur * SR)) / SR
    det = sine(freq * 1.003, t, 0.2) + sine(freq * 0.997, t)
    fifth = sine(freq * 1.5, t, 0.4) * 0.35
    octv = sine(freq * 2.0, t, 1.1) * 0.18
    slow = 0.5 + 0.5 * sine(0.07, t)
    x = (det * 0.55 + fifth + octv) * amp * slow * env(len(t), 0.12, 0.22)
    return x


def make_music(dur=34.0):
    n = int(dur * SR)
    bed = np.zeros(n)
    # A minor-ish dark pad: A2, E3, C4, G3
    parts = [
        (110.00, 0.10),
        (164.81, 0.08),
        (196.00, 0.05),
        (261.63, 0.045),
        (329.63, 0.03),
    ]
    for f, a in parts:
        p = pad_tone(f, dur, a)
        bed[: len(p)] += p
    # sparse high shimmer
    t = np.arange(n) / SR
    shimmer = sine(1318.5, t) * 0.012 * (0.5 + 0.5 * sine(0.11, t, 1.2))
    shimmer *= env(n, 0.2, 0.25)
    bed += lp(shimmer, 2400)
    # very soft pulse every 2s
    pulse = np.zeros(n)
    for k in range(int(dur / 2)):
        i0 = int(k * 2 * SR)
        length = int(0.18 * SR)
        tt = np.arange(length) / SR
        hit = np.sin(2 * math.pi * 48 * tt) * np.exp(-tt * 18) * 0.07
        pulse[i0 : i0 + length] += hit[: max(0, min(length, n - i0))]
    bed += pulse
    # stereo-ish by slight delay (keep mono for mix simplicity)
    bed = lp(bed, 5200)
    peak = np.max(np.abs(bed)) or 1
    bed = bed / peak * 0.28
    return bed


def click(f=1900, dur=0.045, amp=0.45):
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * math.pi * f * t) * np.exp(-t * 90)
    thump = np.sin(2 * math.pi * 90 * t) * np.exp(-t * 40) * 0.6
    tick = noise(n) * np.exp(-t * 180) * 0.15
    return (body + thump + tick) * amp * env(n, 0.002, 0.4)


def whoosh(dur=0.55, amp=0.22):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = noise(n)
    # rising cutoff via exponential envelope on highpassed noise
    hp = x - lp(x, 400)
    sweep = hp * (t / dur) ** 0.7 * np.exp(-((t - 0.22) ** 2) / 0.04)
    return sweep * amp * env(n, 0.05, 0.35)


def block_tock():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * math.pi * 240 * t) * np.exp(-t * 50)
    x += np.sin(2 * math.pi * 180 * t) * np.exp(-t * 38) * 0.5
    x += noise(n) * np.exp(-t * 70) * 0.08
    return x * 0.32


def chime():
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * math.pi * 659.25 * t) * np.exp(-t * 4)
    x += np.sin(2 * math.pi * 987.77 * t) * np.exp(-t * 5) * 0.55
    x += np.sin(2 * math.pi * 1318.5 * t) * np.exp(-t * 6) * 0.25
    return x * 0.22 * env(n, 0.01, 0.3)


def main():
    rng_state = np.random.default_rng
    music = make_music(34)
    w(OUT / "music.wav", music)
    w(OUT / "click.wav", click())
    w(OUT / "click_soft.wav", click(1600, 0.04, 0.28))
    w(OUT / "whoosh.wav", whoosh())
    w(OUT / "block.wav", block_tock())
    w(OUT / "chime.wav", chime())
    print("wrote", list(OUT.glob("*.wav")))


if __name__ == "__main__":
    main()
