"""hero_clover — goat knight: curled horns, beard, steel breastplate, blue cheese-crest tabard,
short sword, cast-iron skillet shield (left hand).
Run: blender -b -P tools/blender/party_clover.py"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from party_lib import *  # noqa

b = Builder("hero_clover")
H = 1.32

TAIL = [(0, -0.12, 0.56), (0, -0.17, 0.60), (0, -0.19, 0.66)]
tail, ears = biped_skeleton(
    b, hip=0.52, spine=0.62, chest=0.74, neck=0.88, head=0.95, top=1.16,
    sh=(0.15, 0.0, 0.84), el=(0.225, 0.01, 0.68), wr=(0.255, 0.04, 0.55), hd=(0.26, 0.06, 0.49),
    hipx=0.085, knee=0.30, ankle=0.08, toe=0.13, tail=TAIL, ears=((0.075, 0.03, 1.06), (0.17, 0.02, 1.03)))

# ---------------------------------------------------------------- materials


def fur(P, N):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    base = mixc(hexc("ece6d8"), hexc("d9d0bd"), fbm(P, 5, 3, 1))
    # warm tan "toggenburg" face stripes + saddle, dark lower legs
    face = smoothstep(0.035, 0.02, np.abs(np.abs(x) - 0.05)) * smoothstep(0.98, 1.02, z) * (y > 0.05)
    saddle = smoothstep(0.55, 0.62, fbm(P, 3.0, 3, 7)) * (z < 0.9) * (z > 0.4)
    col = mixc(base, hexc("b0865a"), np.clip(face * 0.8 + saddle * 0.7, 0, 1))
    legs = smoothstep(0.24, 0.16, z)
    col = mixc(col, hexc("6d5038"), legs * 0.8)
    nose = smoothstep(0.17, 0.21, y) * (z > 0.9)
    col = mixc(col, hexc("8b6a5a"), nose * 0.6)
    return fur_detail(P, col, 1.0, 0.18, 4)


b.material("fur", fur, rough=0.9, ao=0.7)
b.material("horn", lambda P, N: mixc(mixc(np.tile(hexc("b39a72"), (len(P), 1)), hexc("6e5a3e"), fbm(P, 12, 3, 2)), hexc("e2d2ae"),
                                     smoothstep(0.7, 0.95, 0.5 + 0.5 * np.sin(np.linalg.norm(P - np.array([0, 0.0, 1.10]), axis=1) * 300))), rough=0.55, ao=0.5)
b.material("skin", lambda P, N: mixc(np.tile(hexc("2c2420"), (len(P), 1)), hexc("4a3a30"), fbm(P, 30, 3, 3)), rough=0.4, ao=0.4)  # hooves, nose
b.material("eye", eye_fn("d9a521", (-0.5, 0.86, 0.0), (0.5, 0.86, 0.0), pupil="hbar", iris2="9a6a10"), rough=0.08, ao=0.0)


def steel(P, N):
    col = mixc(np.tile(hexc("c3c8cc"), (len(P), 1)), hexc("8c949a"), fbm(P, 20, 4, 3))
    scratch = smoothstep(0.82, 0.9, vnoise(P * np.array([1, 1, 12]), 60, 5))
    return mixc(col, hexc("e6eaec"), scratch * 0.5)


b.material("metal", steel, rough=0.32, metal=1.0, ao=0.4)
b.material("metal_iron", lambda P, N: mixc(np.tile(hexc("2b2a29"), (len(P), 1)), hexc("4a4542"), fbm(P, 25, 4, 6)), rough=0.55, metal=0.8, ao=0.5)


def tabard(P, N):
    x, z = P[:, 0], P[:, 2]
    col = mixc(np.tile(hexc("2f5ea8"), (len(P), 1)), hexc("1f4380"), fbm(P, 10, 4, 3))
    trim = smoothstep(0.012, 0.006, np.abs(z - 0.415)) + smoothstep(0.008, 0.004, np.abs(np.abs(x) - 0.105)) * (z < 0.68)
    return fur_detail(P, mixc(col, hexc("e8c24a"), np.clip(trim, 0, 1)), 1, 0.06, 5)


b.material("cloth_tabard", tabard, rough=0.85, ao=0.6)
b.material("leather", lambda P, N: mixc(np.tile(hexc("6a4022"), (len(P), 1)), hexc("402410"), fbm(P, 30, 4, 4)), rough=0.6, ao=0.5)
b.material("emblem", lambda P, N: mixc(np.tile(hexc("f4c43a"), (len(P), 1)), hexc("d8961a"),
                                       smoothstep(0.75, 0.8, vnoise(P, 140, 2))), rough=0.45, ao=0.2)
b.material("cheese", lambda P, N: mixc(np.tile(hexc("f6c64a"), (len(P), 1)), hexc("e09a22"), fbm(P, 20, 3, 8)), rough=0.4, ao=0.4)

# ---------------------------------------------------------------- body
m = b.mb("fur", "fur", 0.012)
m.ellip((0, 0.0, 1.04), 0.095, 0.105, 0.095)                    # cranium
m.ellip((0, 0.115, 0.995), 0.062, 0.10, 0.06, rot=(-18, 0, 0))   # long muzzle
m.ellip((0, 0.195, 0.975), 0.045, 0.035, 0.04)                  # nose pad area
m.ellip((0, 0.03, 0.90), 0.068, 0.07, 0.08)                     # neck
m.ellip((0, 0.0, 0.77), 0.15, 0.12, 0.13)                       # chest
m.ellip((0, 0.01, 0.65), 0.145, 0.125, 0.12)                    # belly
m.ellip((0, -0.01, 0.55), 0.14, 0.12, 0.09)                     # hips
for s in (1, -1):
    m.path([(s * 0.13, 0, 0.84), (s * 0.225, 0.01, 0.68), (s * 0.255, 0.04, 0.55)], [0.055, 0.045, 0.04])
    m.path([(s * 0.085, 0, 0.52), (s * 0.088, 0.01, 0.30), (s * 0.085, 0.0, 0.10)], [0.072, 0.05, 0.038])
m.path(bezier_pts(TAIL, 5), [0.03, 0.032, 0.03, 0.025, 0.018])
b.allow["fur"] = None

# hooves (rigid feet) + gauntlet hands
for s, sd in ((1, "R"), (-1, "L")):
    b.add(cone("hoof" + sd, "skin", (s * 0.085, 0.02, 0.0), 0.05, 0.042, 0.09, seg=12, scale=(1, 1.15, 1)), "Foot." + sd)
    b.add(sphere("cleft" + sd, "skin", (s * 0.085, 0.065, 0.03), 0.015, scale=(0.4, 1, 1.6), seg=8, rings=6), "Foot." + sd)
    b.add(sphere("gaunt" + sd, "metal", (s * 0.26, 0.06, 0.485), 0.05, scale=(0.95, 1.05, 1.1), seg=14, rings=10), "Hand." + sd)
    b.add(tube("cuff" + sd, "metal", [(s * 0.248, 0.035, 0.585), (s * 0.256, 0.05, 0.53)], [0.05, 0.052], sides=12), "ForeArm." + sd)

# head details: horns, ears, beard, eyes, nose
for s, sd in ((1, "R"), (-1, "L")):
    ctrl = [(s * 0.04, 0.03, 1.12), (s * 0.07, -0.02, 1.19), (s * 0.12, -0.10, 1.20), (s * 0.15, -0.15, 1.13), (s * 0.14, -0.12, 1.07)]
    pts = bezier_pts(ctrl, 14)
    b.add(tube("horn" + sd, "horn", pts, [0.032 - 0.0023 * i for i in range(14)][:13] + [0.0], sides=10), "Head")
    b.add(cone("ear" + sd, "fur", (s * 0.085, 0.03, 1.06), 0.04, 0.008, 0.13, rot=(0, s * 100, s * 10), seg=10, scale=(1, 0.4, 1)), "Ear." + sd)
make_eyes(b, "eye", [(0.062, 0.085, 1.055), (-0.062, 0.085, 1.055)], 0.032, [(0.5, 0.86, 0.0), (-0.5, 0.86, 0.0)])
b.add(sphere("nose", "skin", (0, 0.226, 0.985), 0.022, scale=(1.4, 0.6, 0.8), seg=12, rings=8), "Head")
b.add(cone("beard", "fur", (0, 0.15, 0.95), 0.035, 0.0, 0.13, rot=(160, 0, 0), seg=10, scale=(1, 0.7, 1)), "Head")

# ---------------------------------------------------------------- armour + tabard


def body_r(z):
    if z > 0.70:
        rx = 0.15 - max(0, z - 0.80) * 0.9
    else:
        rx = 0.148
    return max(rx, 0.085)


b.add(shell("breastplate", "metal", (0.62, 0.86), -180, 180, lambda z: (body_r(z) + 0.018, (body_r(z) + 0.018) * 0.86), 0.01, 10, 32))
b.allow["metal"] = ["Spine", "Chest", "Neck", "UpperArm", "ForeArm", "Hand"]
b.add(torus("gorget", "metal", (0, 0.02, 0.875), 0.08, 0.022, rot=(-10, 0, 0), seg=24, sides=8), "Chest")
for s, sd in ((1, "R"), (-1, "L")):
    for k in range(3):  # layered pauldrons
        b.add(sphere("pauld%s%d" % (sd, k), "metal", (s * (0.165 + 0.012 * k), 0.0, 0.855 - 0.035 * k), 0.085 - 0.012 * k,
                     scale=(1.0, 1.0, 0.55), rot=(0, s * 28, 0), seg=18, rings=8), "UpperArm." + sd)
b.add(shell("tabard_f", "cloth_tabard", (0.40, 0.70), -40, 40, lambda z: (0.185 + (0.62 - z) * 0.12, 0.155 + max(0, 0.62 - z) * 0.1), 0.006, 12, 12))
b.add(shell("tabard_b", "cloth_tabard", (0.42, 0.70), 140, 220, lambda z: (0.185 + (0.62 - z) * 0.12, 0.155 + max(0, 0.62 - z) * 0.1), 0.006, 12, 12))
b.allow["cloth_tabard"] = ["Hips", "Spine", "Chest", "Thigh"]
b.add(ring_band("belt", "leather", 0.605, lambda z: (0.178, 0.152), 0.035, 0.008), None)
b.allow["leather"] = ["Hips", "Spine"]
b.add(box("buckle", "emblem", (0, 0.158, 0.605), (0.045, 0.012, 0.04), bevel=0.004), "Spine")
# cheese-wedge crest on the tabard
b.add(cone("crest", "cheese", (0, 0.178, 0.53), 0.055, 0.0, 0.01, rot=(-90, 0, 0), seg=3, scale=(1, 1, 1)), "Spine")

# short sword (right) pointing forward/up
X, Y, Z = 0.26, 0.06, 0.485
b.add(tube("grip", "leather", [(X, Y, Z - 0.06), (X, Y, Z + 0.06)], [0.016, 0.016], sides=8), "Hand.R")
b.add(sphere("pommel", "emblem", (X, Y, Z - 0.075), 0.022, seg=10, rings=8), "Hand.R")
b.add(box("guard", "metal", (X, Y, Z + 0.07), (0.16, 0.025, 0.022), bevel=0.006), "Hand.R")
b.add(tube("blade", "metal", [(X, Y, Z + 0.08), (X, Y, Z + 0.35), (X, Y, Z + 0.48)], [0.03, 0.026, 0.0], sides=6, flat=0.22, twist_up=(0, 1, 0)), "Hand.R")

# skillet shield (left hand): cast-iron pan, bottom faces outward (-X), with a cheese splash inside
SX, SY, SZ = -0.29, 0.06, 0.50
srot = Matrix.Rotation(math.radians(90), 3, "Y")  # lathe axis +Z -> +X (bottom faces out)
b.add(lathe("skillet", "metal_iron", [(0.0, 0.0), (0.17, 0.0), (0.195, 0.05), (0.205, 0.055), (0.205, 0.06), (0.185, 0.058),
                                      (0.165, 0.012), (0.0, 0.012)], loc=(SX - 0.09, SY, SZ), rot=srot, seg=32), "Hand.L")
b.add(tube("skillet_handle", "metal_iron", [(SX - 0.03, SY, SZ - 0.19), (SX - 0.03, SY - 0.03, SZ - 0.32), (SX - 0.03, SY - 0.04, SZ - 0.40)],
           [0.018, 0.016, 0.02], sides=8, flat=0.6), "Hand.L")
b.add(sphere("skillet_boss", "emblem", (SX - 0.095, SY, SZ), 0.04, scale=(0.35, 1, 1), seg=14, rings=8), "Hand.L")
b.add(sphere("cheese_in_pan", "cheese", (SX - 0.072, SY, SZ), 0.16, scale=(0.08, 1, 1), seg=20, rings=10), "Hand.L")


def extra(name, t, p):
    if name in ("idle", "walk", "victory"):
        add(p, "UpperArm.L", 6, 0, 0); add(p, "ForeArm.L", 20)


b.build(H, budget=29000)
b.clips(biped_clips(H, tail=tail, ears=ears, extra=extra, shield_hand="L"))
b.export()
b.previews(BIPED_POSES, frame_h=H * 1.2)
