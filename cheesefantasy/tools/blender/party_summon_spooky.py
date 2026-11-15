"""summon_spooky — Nine Lives spirit: black cat with glowing gold eyes, shadow tendrils and a tiny crescent
moon on the forehead (SHADE "Midnight Walker").
Run: blender -b -P tools/blender/party_summon_spooky.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from party_catlib import *  # noqa

b = Builder("summon_spooky")
tail = skeleton(b)


def fur(P, N):
    Q = P / F
    col = mixc(np.tile(hexc("17151c"), (len(P), 1)), hexc("2a2533"), fbm(Q, 6, 3, 1))
    sheen = smoothstep(0.4, 0.9, N[:, 2]) * 0.35
    col = mixc(col, hexc("4a4266"), sheen)               # blue-violet sheen on the back
    return fur_detail(P, col, F, 0.18, 3)


b.material("fur", fur, rough=0.55, ao=0.6,
           emit_fn=lambda P, N: mixc(np.tile(hexc("000000"), (len(P), 1)), hexc("6a3cc8"), smoothstep(0.62, 0.85, fbm(P / F, 8, 4, 5)) * 0.6),
           emit_strength=1.2)
b.material("skin", lambda P, N: np.tile(hexc("2a2026"), (len(P), 1)), rough=0.4, ao=0.3)
b.material("skin_ear", lambda P, N: np.tile(hexc("3a2a3c"), (len(P), 1)), rough=0.6, ao=0.3)
b.material("eye", eye_fn("ffc21a", (-0.25, 1, 0.05), (0.25, 1, 0.05), pupil="slit", iris2="f08a00"), rough=0.05, ao=0.0,
           emit_fn=eye_fn("ffc21a", (-0.25, 1, 0.05), (0.25, 1, 0.05), pupil="slit", iris2="f08a00"), emit_strength=4.0)
b.material("whisker", lambda P, N: np.tile(hexc("3a3446"), (len(P), 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("8a6ae0"), (len(P), 1)), emit_strength=0.8)
b.material("aura", lambda P, N: np.tile(hexc("2a1840"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.18, cull=True,
           emit_fn=lambda P, N: mixc(np.tile(hexc("3a1a6a"), (len(P), 1)), hexc("8a5aff"), smoothstep(0.55, 0.8, fbm(P / F, 5, 3, 6))), emit_strength=1.0)
b.material("cloth_shadow", lambda P, N: np.tile(hexc("120c1a"), (len(P), 1)), rough=0.6, ao=0.0, alpha=0.75, cull=False,
           emit_fn=lambda P, N: mixc(np.tile(hexc("1a0c30"), (len(P), 1)), hexc("7a48ff"), smoothstep(0.5, 0.75, fbm(P / F, 12, 3, 9))), emit_strength=1.6)
b.material("emblem", lambda P, N: np.tile(hexc("fff2b0"), (len(P), 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("ffe48a"), (len(P), 1)), emit_strength=6.0)

body(b, "fur", 0.012 * F, fluff=1.15)
body(b, "aura", 0.022 * F, grow=0.016, fluff=1.25)
b.allow["fur"] = None
ears(b, "fur", "skin_ear")
face(b, "eye", "skin", "whisker")
# tiny crescent moon on the forehead
C = f(0, 0.512, 0.722)
pts = [C + V((math.cos(math.radians(a)) * 0.024 * F, 0.0, math.sin(math.radians(a)) * 0.024 * F)) for a in range(-60, 241, 20)]
rad = [0.0085 * F * math.sin(math.pi * i / (len(pts) - 1)) ** 0.8 for i in range(len(pts))]
rad[0] = rad[-1] = 0.0
b.add(tube("moon", "emblem", pts, rad, sides=8, flat=0.5), "Head")
# shadow tendrils: rising smoke off the back + low tendrils trailing from each paw
paw_trails(b, "cloth_shadow", 0.03, bones=("Tail1", "Chest", "Spine"))
for bone in ("FrontPaw.R", "FrontPaw.L", "HindPaw.R", "HindPaw.L"):
    h, t, _, _ = b.J[bone]
    sx = 1 if h.x > 0 else -1
    ctrl = [h + V((0, 0, -0.03 * F)), h + V((sx * 0.08 * F, -0.12 * F, -0.04 * F)), h + V((sx * 0.05 * F, -0.26 * F, 0.0)),
            h + V((sx * 0.12 * F, -0.36 * F, 0.06 * F))]
    p = bezier_pts(ctrl, 10)
    b.add(tube("tendril_" + bone, "cloth_shadow", p, [0.03 * F * (1 - i / 9) ** 0.6 for i in range(10)], sides=8, flat=0.5), bone)
motes(b, "emblem", n=8, seed=23, r=0.006)  # tiny stars

finish(b, bg=(0.05, 0.05, 0.08))
