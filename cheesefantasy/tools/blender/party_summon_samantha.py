"""summon_samantha — Nine Lives spirit: snow-white cat with a golden halo and soft light (LIGHT/ICE "Snow Angel").
Run: blender -b -P tools/blender/party_summon_samantha.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from party_catlib import *  # noqa

b = Builder("summon_samantha")
tail = skeleton(b)


def fur(P, N):
    Q = P / F
    col = mixc(np.tile(hexc("f6f4f0"), (len(P), 1)), hexc("e6ddd0"), fbm(Q, 5, 3, 1) * 0.8)
    under = smoothstep(-0.1, -0.7, N[:, 2])
    col = mixc(col, hexc("d9d4e2"), under * 0.35)       # cool lilac shade underneath
    return fur_detail(P, col, F, 0.08, 3)


b.material("fur", fur, rough=0.8, ao=0.55,
           emit_fn=lambda P, N: mixc(np.tile(hexc("5a554c"), (len(P), 1)), hexc("fff4d8"), smoothstep(0.5, 0.8, fbm(P / F, 6, 3, 2)) * 0.4),
           emit_strength=0.8)
b.material("skin", lambda P, N: np.tile(hexc("f1a3ab"), (len(P), 1)), rough=0.45, ao=0.3)
b.material("skin_ear", lambda P, N: np.tile(hexc("f7c0c4"), (len(P), 1)), rough=0.6, ao=0.3,
           emit_fn=lambda P, N: np.tile(hexc("ffd8d8"), (len(P), 1)), emit_strength=0.5)
b.material("eye", eye_fn("4f9be8", (-0.25, 1, 0.05), (0.25, 1, 0.05), pupil="slit", iris2="1f4fa0"), rough=0.05, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("1a3a6a"), (len(P), 1)), emit_strength=1.2)
b.material("whisker", lambda P, N: np.tile(hexc("ffffff"), (len(P), 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("fff6e0"), (len(P), 1)), emit_strength=1.5)
b.material("aura", lambda P, N: np.tile(hexc("fff4dc"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.12, cull=True,
           emit_fn=lambda P, N: np.tile(hexc("fff0cc"), (len(P), 1)), emit_strength=2.0)
b.material("emblem", lambda P, N: mixc(np.tile(hexc("ffd968"), (len(P), 1)), hexc("fff3c0"), fbm(P / F, 40, 2, 1)), rough=0.25, metal=0.6, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("ffd768"), (len(P), 1)), emit_strength=6.0)
b.material("wisp", lambda P, N: np.tile(hexc("fff8e6"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.22, cull=False,
           emit_fn=lambda P, N: np.tile(hexc("fff0c8"), (len(P), 1)), emit_strength=3.0)

body(b, "fur", 0.012 * F, fluff=1.35)
body(b, "aura", 0.022 * F, grow=0.016, fluff=1.4)
b.allow["fur"] = None
ears(b, "fur", "skin_ear")
face(b, "eye", "skin", "whisker")
# the halo floats above the head, tilted back
b.add(torus("halo", "emblem", f(0, 0.36, 0.86), 0.075 * F, 0.009 * F, rot=(-18, 0, 0), seg=40, sides=10), "Head")
# soft light: a sparkle crown of motes + gentle rising light ribbons from the tail
motes(b, "emblem", n=14, seed=11, r=0.008)
paw_trails(b, "wisp", 0.022, bones=("FrontPaw.R", "FrontPaw.L", "HindPaw.R", "HindPaw.L"))
# a little snowflake charm at the chest
for k in range(3):
    b.add(box("flake%d" % k, "emblem", f(0, 0.335, 0.47), (0.004 * F, 0.002 * F, 0.04 * F), rot=(0, 60 * k, 0)), "Chest")

finish(b, bg=(0.10, 0.11, 0.16))
