#!/usr/bin/env python3
"""Procedural audio for CHEESE FANTASY. Deterministic, numpy only.
usage: python3 tools/gen_audio.py [outdir]   (default game/assets/audio) -> sfx/*.wav, music/*.wav, manifest.json"""
import json, os, sys, wave, zlib
import numpy as np

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio")


def rng(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def tt(d):
    return np.arange(int(d * SR)) / SR


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def adsr(n, a=0.005, d=0.15):
    t = np.arange(n) / SR
    return np.exp(-t / max(d, 1e-4)) * np.minimum(1, t / max(a, 1e-4))


def tone(f, d, kind="tri", a=0.005, dec=0.2, vib=0.0):
    t = tt(d)
    ph = 2 * np.pi * f * t + (vib * np.sin(2 * np.pi * 5 * t) if vib else 0)
    if kind == "sq":
        w = np.sign(np.sin(ph)) * 0.5
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == "saw":
        w = 2 * ((f * t) % 1) - 1
    elif kind == "pluck":
        w = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
        w *= 0.6
    else:
        w = np.sin(ph)
    return w * adsr(len(t), a, dec)


def put(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i]


def lp(x, k):
    k = max(1, int(k))
    return np.convolve(x, np.ones(k) / k, "same") if k > 1 else x


def save(path, x, loop=False):
    x = np.asarray(x, dtype=np.float64)
    if loop:
        n = int(0.02 * SR)
        x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n) * 0  # fade-in only; tail faded below
        x[-n:] *= np.linspace(1, 0, n)
        x[:n] += 0
    pk = np.max(np.abs(x)) + 1e-9
    x = x / pk * 0.8 if pk > 0.8 else x
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    return {"peak_db": round(20 * np.log10(np.max(np.abs(x)) + 1e-9), 1), "rms_db": round(20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9), 1), "sec": round(len(x) / SR, 2)}


# ------------------------------------------------------------------ sfx
def seq(notes, step, kind="sq", dec=0.12, gain=0.5, length=None):
    n = int((len(notes) * step + 0.5) * SR)
    b = np.zeros(n)
    for i, m in enumerate(notes):
        if m:
            put(b, tone(hz(m), step * 2.5, kind, 0.004, dec), i * step)
    return b * gain


def sfx_all():
    S = {}
    S["ui_select"] = seq([79], 0.05, "sq", 0.04, 0.35)
    S["ui_confirm"] = seq([72, 79], 0.06, "sq", 0.09, 0.4)
    S["ui_cancel"] = seq([71, 64], 0.06, "tri", 0.1, 0.5)
    S["ui_open"] = seq([60, 64, 67], 0.04, "tri", 0.08, 0.5)
    S["ui_buy"] = seq([84, 88, 91, 96], 0.05, "sq", 0.1, 0.3)
    S["ui_error"] = seq([55, 55], 0.09, "saw", 0.07, 0.3)
    S["ui_save"] = seq([60, 67, 72, 76, 79], 0.07, "pluck", 0.25, 0.5)
    S["heal"] = seq([72, 76, 79, 84, 88], 0.06, "tri", 0.2, 0.5)
    S["dialogue_blip"] = tone(520, 0.045, "sq", 0.002, 0.03) * 0.3
    S["dialogue_blip_low"] = tone(330, 0.05, "sq", 0.002, 0.035) * 0.3
    r = rng("sizzle")
    t = tt(1.6)
    n = r.standard_normal(len(t))
    hp = n - lp(n, 6)
    crack = (r.random(len(t)) > 0.9985).astype(float)
    crack = np.convolve(crack, np.exp(-np.arange(200) / 25) * r.standard_normal(200), "same")
    S["cooking_sizzle"] = (hp * 0.25 * np.minimum(1, t / 0.1) * np.minimum(1, (1.6 - t) / 0.4) * (0.7 + 0.3 * np.sin(t * 17)) + crack * 1.5)
    S["summon_sting"] = summon()
    S["coin"] = seq([83, 90], 0.07, "sq", 0.12, 0.3)
    S["equip"] = seq([55, 62], 0.05, "saw", 0.08, 0.3)
    return S


def summon():
    b = np.zeros(int(2.4 * SR))
    for k, m in enumerate([48, 55, 60, 64, 67, 72, 79]):
        put(b, tone(hz(m), 1.6, "sin", 0.25, 0.8, vib=3) * 0.4, k * 0.12)
    t = tt(2.4)
    sw = np.sin(2 * np.pi * (200 * t + 300 * t ** 2)) * np.exp(-t / 0.9) * np.minimum(1, t / 0.5) * 0.3
    return b + sw


# ------------------------------------------------------------------ music
SCALES = {"maj": [0, 2, 4, 5, 7, 9, 11], "min": [0, 2, 3, 5, 7, 8, 10], "dor": [0, 2, 3, 5, 7, 9, 10], "pen": [0, 2, 4, 7, 9], "phr": [0, 1, 3, 5, 7, 8, 10], "hmin": [0, 2, 3, 5, 7, 8, 11]}
# name: root midi, scale, bpm, bars, progression (scale degrees), lead kind, bass style, density, drums
TRACKS = {
    "title": (57, "maj", 84, 8, [0, 4, 5, 3], "pluck", "root", 0.6, 0),
    "farm_day": (62, "maj", 104, 8, [0, 3, 4, 0], "pluck", "bounce", 0.75, 1),
    "fields": (60, "dor", 112, 8, [0, 6, 3, 4], "pluck", "bounce", 0.8, 1),
    "pond": (59, "pen", 76, 8, [0, 5, 3, 4], "sin", "root", 0.45, 0),
    "orchard": (65, "maj", 92, 8, [0, 2, 3, 4], "pluck", "arp", 0.7, 0),
    "silo": (55, "dor", 118, 8, [0, 0, 5, 6], "sq", "drive", 0.85, 2),
    "cave": (50, "min", 70, 8, [0, 5, 3, 4], "sin", "root", 0.35, 0),
    "rot": (48, "phr", 96, 8, [0, 1, 0, 6], "saw", "drive", 0.6, 2),
    "shrine": (62, "pen", 66, 8, [0, 3, 4, 0], "sin", "arp", 0.4, 0),
    "throne": (50, "hmin", 112, 8, [0, 5, 3, 4], "saw", "drive", 0.8, 2),
    "battle": (57, "min", 150, 8, [0, 5, 6, 4], "sq", "drive", 0.9, 2),
    "boss": (52, "hmin", 160, 8, [0, 5, 3, 4], "saw", "drive", 0.95, 2),
    "final_boss": (47, "hmin", 172, 8, [0, 6, 5, 4], "saw", "drive", 1.0, 2),
}


def degree(root, scale, deg):
    sc = SCALES[scale]
    return root + sc[deg % len(sc)] + 12 * (deg // len(sc))


def track(name, spec):
    root, scale, bpm, bars, prog, lead, bass, dens, drums = spec
    r = rng(name)
    beat = 60 / bpm
    total = bars * 4 * beat
    b = np.zeros(int(total * SR) + SR)
    for bar in range(bars):
        d0 = prog[bar % len(prog)]
        base = bar * 4 * beat
        triad = [degree(root, scale, d0 + k) for k in (0, 2, 4)]
        # pad
        for m in triad:
            put(b, tone(hz(m), 4 * beat, "tri", 0.08, 2.0) * 0.12, base)
        # bass
        for s in range(8):
            at = base + s * beat / 2
            if bass == "root" and s % 4 == 0:
                put(b, tone(hz(triad[0] - 12), beat * 1.8, "sin", 0.01, 0.8) * 0.4, at)
            elif bass == "bounce" and s % 2 == 0:
                put(b, tone(hz(triad[0 if s % 4 == 0 else 2] - 12), beat * 0.8, "tri", 0.01, 0.25) * 0.4, at)
            elif bass == "arp":
                put(b, tone(hz(triad[s % 3] - 12), beat * 0.9, "sin", 0.01, 0.4) * 0.3, at)
            elif bass == "drive":
                put(b, tone(hz(triad[0] - 12), beat * 0.45, "saw", 0.005, 0.18) * 0.25, at)
        # lead melody: random walk on the scale
        pos = 4 + int(r.integers(0, 4))
        for s in range(8):
            if r.random() < dens:
                step = int(r.choice([-2, -1, -1, 0, 1, 1, 2]))
                pos = int(np.clip(pos + step, 2, 11))
                m = degree(root, scale, d0 + pos) + 12
                if s % 4 == 0:
                    m = triad[int(r.integers(0, 3))] + 12
                dur = beat * (1.0 if r.random() < 0.3 else 0.5)
                put(b, tone(hz(m), dur * 1.4, lead, 0.01, 0.25, vib=0.4 if lead == "sin" else 0) * 0.22, base + s * beat / 2)
        # drums
        if drums:
            for s in range(8):
                at = base + s * beat / 2
                if s % 4 == 0:
                    t = tt(0.18)
                    put(b, np.sin(2 * np.pi * (45 + 90 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.08) * 0.7, at)
                if (s % 4 == 2) or (drums == 2 and s % 2 == 1):
                    n = r.standard_normal(int(0.08 * SR))
                    put(b, (n - lp(n, 4)) * np.exp(-np.arange(len(n)) / SR / 0.025) * (0.35 if s % 4 == 2 else 0.12), at)
    b = b[:int(total * SR)]
    # light echo for space
    d = int(0.25 * SR)
    b[d:] += b[:-d] * 0.25
    return b


def jingle(name):
    if name == "victory":
        b = np.zeros(int(4.5 * SR))
        for i, m in enumerate([72, 72, 72, 72, 68, 70, 72, 70, 72]):
            at = [0, .15, .3, .45, .9, 1.2, 1.5, 1.8, 2.0][i]
            put(b, tone(hz(m), 0.6 if i > 3 else 0.2, "sq", 0.005, 0.25) * 0.3, at)
        for m in (60, 64, 67, 72):
            put(b, tone(hz(m), 2.4, "tri", 0.02, 1.4) * 0.3, 2.0)
        return b
    b = np.zeros(int(4.0 * SR))  # game_over
    for i, m in enumerate([67, 63, 60, 55]):
        put(b, tone(hz(m), 1.2, "tri", 0.02, 0.9) * 0.4, i * 0.55)
    return b


def main():
    man = {}
    for k, x in sfx_all().items():
        man["sfx/" + k] = save(os.path.join(OUT, "sfx", k + ".wav"), x)
    for k, spec in TRACKS.items():
        man["music/" + k] = save(os.path.join(OUT, "music", k + ".wav"), track(k, spec), loop=True)
    for k in ("victory", "game_over"):
        man["music/" + k] = save(os.path.join(OUT, "music", k + ".wav"), jingle(k))
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(man, f, indent=1)
    print(len(man), "files ->", OUT)


main()
