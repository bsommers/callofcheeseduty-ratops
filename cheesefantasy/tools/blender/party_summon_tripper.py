"""summon_tripper — Nine Lives spirit: American (brown classic/mackerel) tabby with bold black stripes and a
white chest locket; warm earthen glow (EARTH "Stripe Quake").
Run: blender -b -P tools/blender/party_summon_tripper.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from party_catlib import *  # noqa

b = Builder("summon_tripper")
tail = skeleton(b)
BROWN = hexc("6e4a24"); BLACK = hexc("17110b"); WARM = hexc("c9a066"); WHITE = hexc("f4efe4")


def fur(P, N):
    Q = P / F
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]
    col = mixc(np.tile(BROWN, (len(P), 1)), hexc("85602f"), fbm(Q, 6, 3, 1))
    under = smoothstep(-0.1, -0.6, N[:, 2]) * (z < 0.45)
    col = mixc(col, WARM, under * 0.7)
    body = (y > -0.40) & (y < 0.30) & (z > 0.22)
    s_body = stripes(Q, 50, (0, 1, 0.25), 1.6, 1, 0.62)                  # bold vertical mackerel bands
    swirl = smoothstep(0.035, 0.02, np.abs(np.hypot(y + 0.24, z - 0.36) * 1.0 - 0.07)) * (np.abs(x) > 0.08)  # classic hip swirl
    dorsal = smoothstep(0.035, 0.015, np.abs(x)) * (N[:, 2] > 0.5) * (y < 0.33)
    legs = stripes(Q, 80, (0, 0, 1), 0.6, 2, 0.6) * (z < 0.26)
    tailr = stripes(Q, 60, (0, -0.55, 0.85), 0.5, 3, 0.6) * (y < -0.40)
    head = (z > 0.62) & (y > 0.28)
    s_head = stripes(Q, 95, (1, 0, 0.15), 0.8, 5, 0.5) * smoothstep(0.69, 0.74, z) * head
    cheek = smoothstep(0.012, 0.004, np.abs(z - 0.62 - 0.25 * (np.abs(x) - 0.06))) * (np.abs(x) > 0.07) * (y > 0.36) * (z > 0.55)
    s = np.clip(np.where(body, s_body, 0) + swirl + dorsal + legs + tailr + s_head + cheek, 0, 1)
    col = mixc(col, BLACK, s * 0.92)
    tip = smoothstep(0.84, 0.88, z) * (y < -0.45)
    col = mixc(col, BLACK, tip)
    locket = smoothstep(0.055, 0.035, np.hypot(x * 1.2, (z - 0.42) * 0.8)) * (y > 0.26) \
        + smoothstep(0.05, 0.03, np.abs(x)) * smoothstep(0.30, 0.34, y) * (z < 0.56) * (z > 0.3)
    muzzle = smoothstep(0.05, 0.03, np.hypot(x, z - 0.585)) * (y > 0.47)
    col = mixc(col, WHITE, np.clip(locket + muzzle, 0, 1))
    return fur_detail(P, col, F, 0.16, 3)


def fur_emit(P, N):
    Q = P / F
    vein = smoothstep(0.62, 0.8, fbm(Q, 9, 4, 11))
    return mixc(np.tile(hexc("1a1206"), (len(P), 1)), hexc("ffb648"), vein * 0.25)


b.material("fur", fur, rough=0.8, ao=0.65, emit_fn=fur_emit, emit_strength=1.0)
b.material("skin", lambda P, N: np.tile(hexc("b9675a"), (len(P), 1)), rough=0.45, ao=0.3)
b.material("skin_ear", lambda P, N: np.tile(hexc("d79a88"), (len(P), 1)), rough=0.6, ao=0.3)
b.material("eye", eye_fn("9cc23a", (-0.25, 1, 0.05), (0.25, 1, 0.05), pupil="slit", iris2="c79a1c"), rough=0.05, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("3a3a0c"), (len(P), 1)), emit_strength=1.0)
b.material("whisker", lambda P, N: np.tile(hexc("fff2dc"), (len(P), 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("ffd59a"), (len(P), 1)), emit_strength=1.2)
b.material("wisp", lambda P, N: np.tile(hexc("ffe2a8"), (len(P), 1)), rough=0.4, ao=0.0, alpha=0.25, cull=False,
           emit_fn=lambda P, N: np.tile(hexc("ffbb55"), (len(P), 1)), emit_strength=3.0)
b.material("emblem", lambda P, N: np.tile(hexc("e9b84a"), (len(P), 1)), rough=0.3, metal=1.0, ao=0.2,
           emit_fn=lambda P, N: np.tile(hexc("ffc860"), (len(P), 1)), emit_strength=1.5)

body(b, "fur", 0.012 * F, fluff=1.1)
# no aura shell: the earth spirit reads solid so its bold stripes stay crisp
b.allow["fur"] = None
ears(b, "fur", "skin_ear")
face(b, "eye", "skin", "whisker")
motes(b, "emblem", n=12, seed=8, r=0.01)   # floating amber pebbles (earth)
# glowing amber stones orbiting low around the paws
rng = np.random.default_rng(4)
for k in range(8):
    a = k / 8 * 2 * math.pi
    c = V((math.cos(a) * 0.32 * F, math.sin(a) * 0.5 * F - 0.02 * F, rng.uniform(0.03, 0.12) * F))
    b.add(sphere("stone%d" % k, "emblem", c, 0.022 * F, scale=(1.2, 0.9, 0.7), seg=6, rings=4), "Root" if False else "Hips")

finish(b)
