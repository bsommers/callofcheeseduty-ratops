"""summon_jesse — Nine Lives spirit: gray cat wreathed in silvery mist (WIND+ICE "Silver Stalker").
Run: blender -b -P tools/blender/party_summon_jesse.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from party_catlib import *  # noqa

b = Builder("summon_jesse")
tail = skeleton(b)


def fur(P, N):
    Q = P / F
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]
    col = mixc(np.tile(hexc("7d838c"), (len(P), 1)), hexc("9aa0a8"), fbm(Q, 6, 3, 1))
    tick = smoothstep(0.55, 0.75, vnoise(Q * np.array([1, 1, 3]), 90, 2))
    col = mixc(col, hexc("4f545c"), tick * 0.45)                                   # agouti ticking
    ring = stripes(Q, 70, (0, 0.7, 0.7), 0.6, 4, 0.35) * (y < -0.40)
    col = mixc(col, hexc("555a63"), ring * 0.6)                                    # faint tail rings
    pale = smoothstep(-0.2, -0.6, N[:, 2]) * (z < 0.42) \
        + smoothstep(0.07, 0.03, np.abs(x)) * smoothstep(0.26, 0.33, y) * (z < 0.60) * (z > 0.30)
    col = mixc(col, hexc("d4d8de"), np.clip(pale, 0, 1) * 0.8)                     # silver belly + bib
    return fur_detail(P, col, F, 0.16, 3)


def fur_emit(P, N):
    Q = P / F
    mist = smoothstep(0.55, 0.8, fbm(Q, 7, 4, 9))
    return mixc(np.tile(hexc("1c2430"), (len(P), 1)), hexc("b8d4ff"), mist * 0.55)


b.material("fur", fur, rough=0.75, ao=0.65, emit_fn=fur_emit, emit_strength=1.0)
b.material("skin", lambda P, N: np.tile(hexc("8c6a70"), (len(P), 1)), rough=0.45, ao=0.3)
b.material("skin_ear", lambda P, N: mixc(np.tile(hexc("c79aa0"), (len(P), 1)), hexc("dfe8ff"), 0.3), rough=0.6, ao=0.3,
           emit_fn=lambda P, N: np.tile(hexc("8faee0"), (len(P), 1)), emit_strength=0.6)
b.material("eye", eye_fn("b9d36a", (-0.25, 1, 0.05), (0.25, 1, 0.05), pupil="slit", iris2="6f9a2e"), rough=0.05, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("3a4a1c"), (len(P), 1)), emit_strength=1.0)
b.material("whisker", lambda P, N: np.tile(hexc("f2f6ff"), (len(P), 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("c8dcff"), (len(P), 1)), emit_strength=1.5)
b.material("aura", lambda P, N: np.tile(hexc("c9dcff"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.09, cull=True,
           emit_fn=lambda P, N: mixc(np.tile(hexc("9cc0ff"), (len(P), 1)), hexc("ffffff"), smoothstep(0.5, 0.8, fbm(P / F, 5, 3, 2))), emit_strength=1.6)
b.material("wisp", lambda P, N: np.tile(hexc("e2ecff"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.3, cull=False,
           emit_fn=lambda P, N: np.tile(hexc("bcd4ff"), (len(P), 1)), emit_strength=3.0)

body(b, "fur", 0.012 * F, fluff=1.25)
body(b, "aura", 0.022 * F, grow=0.014, fluff=1.3)
b.allow["fur"] = None
ears(b, "fur", "skin_ear")
face(b, "eye", "skin", "whisker")
paw_trails(b, "wisp", 0.03)
motes(b, "wisp", n=16, seed=5)
# a silver ice-crystal collar charm
b.add(sphere("charm", "whisker", f(0, 0.33, 0.47), 0.025 * F, scale=(0.7, 0.5, 1.2), seg=6, rings=4), "Chest")

finish(b)
