"""hero_maple — farm girl: auburn twin braids, freckles, red plaid shirt, denim overalls, boots,
glowing cheese-cave lantern in the right hand.
Run: blender -b -P tools/blender/party_maple.py"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from party_lib import *  # noqa

b = Builder("hero_maple")
H = 1.38

tail, ears = biped_skeleton(
    b, hip=0.66, spine=0.76, chest=0.88, neck=1.04, head=1.10, top=1.36,
    sh=(0.125, 0.0, 1.0), el=(0.185, 0.0, 0.82), wr=(0.215, 0.03, 0.665), hd=(0.22, 0.05, 0.59),
    hipx=0.072, knee=0.36, ankle=0.07, toe=0.15)

# ---------------------------------------------------------------- materials
SKIN = hexc("f0c4a0")


def skin(P, N):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    col = mixc(np.tile(SKIN, (len(P), 1)), hexc("e2a888"), fbm(P, 12, 3, 1) * 0.6)
    for s in (1, -1):
        d = np.hypot(x - s * 0.055, z - 1.185) * (y > 0.04)
        col = mixc(col, hexc("ec8f86"), smoothstep(0.04, 0.0, d) * 0.55)  # blush
        fr = smoothstep(0.80, 0.86, vnoise(P, 260, 3 + s)) * smoothstep(0.05, 0.02, np.hypot(x - s * 0.045, z - 1.2)) * (y > 0.04)
        col = mixc(col, hexc("a5603a"), fr * 0.8)                         # freckles
    return fur_detail(P, col, 1, 0.04, 2)


b.material("skin", skin, rough=0.55, ao=0.6)


def hair(P, N):
    col = mixc(np.tile(hexc("7a260a"), (len(P), 1)), hexc("a8401a"), fbm(P * np.array([1, 1, 0.25]), 30, 3, 2))
    strands = 0.5 + 0.5 * np.sin(np.arctan2(P[:, 0], P[:, 1] + 0.02) * 70 + fbm(P, 20, 2, 5) * 3)
    col = mixc(col, hexc("5e1e08"), smoothstep(0.7, 1.0, strands) * 0.45)
    return fur_detail(P, col, 1, 0.12, 6)


b.material("hair", hair, rough=0.6, ao=0.7)
b.material("eye", eye_fn("4f8a3a", (-0.12, 1, 0.02), (0.12, 1, 0.02), pupil="round", iris2="2b4f1e"), rough=0.08, ao=0.0)


def plaid(P, N):
    u = np.arctan2(P[:, 0], P[:, 1]) * 0.12 + P[:, 0] * 0.3
    v = P[:, 2]
    a = smoothstep(0.55, 0.62, 0.5 + 0.5 * np.sin(u * 2 * math.pi / 0.006 * 0.5))
    bnd = smoothstep(0.55, 0.62, 0.5 + 0.5 * np.sin(v * 2 * math.pi / 0.045))
    bu = smoothstep(0.55, 0.62, 0.5 + 0.5 * np.sin(P[:, 0] * 2 * math.pi / 0.045 + P[:, 1] * 2 * math.pi / 0.045))
    col = np.tile(hexc("c0302a"), (len(P), 1))
    col = mixc(col, hexc("7a1612"), np.clip(bnd * 0.6 + bu * 0.6, 0, 1))
    col = mixc(col, hexc("f1e2c4"), (smoothstep(0.96, 0.99, 0.5 + 0.5 * np.sin(v * 2 * math.pi / 0.045 + 1.4))) * 0.8)
    return fur_detail(P, col, 1, 0.06, 4)


b.material("cloth_shirt", plaid, rough=0.85, ao=0.6)


def denim(P, N):
    col = mixc(np.tile(hexc("3d5f8f"), (len(P), 1)), hexc("2b4670"), fbm(P, 9, 4, 3))
    twill = 0.5 + 0.5 * np.sin((P[:, 0] + P[:, 2]) * 900 + P[:, 1] * 900)
    col = col * (0.92 + 0.12 * twill[:, None])
    wear = smoothstep(0.6, 0.75, fbm(P, 6, 3, 9)) * 0.3
    knee = smoothstep(0.05, 0.0, np.abs(P[:, 2] - 0.36)) * 0.35
    col = mixc(col, hexc("8aa7c6"), np.clip(wear + knee, 0, 0.6))
    return col


b.material("cloth_denim", denim, rough=0.9, ao=0.6)
b.material("leather", lambda P, N: mixc(np.tile(hexc("6e4524"), (len(P), 1)), hexc("3e2412"), fbm(P, 18, 4, 4)), rough=0.55, ao=0.6)
b.material("cloth_ribbon", lambda P, N: mixc(np.tile(hexc("5aa04a"), (len(P), 1)), hexc("3d7a30"), fbm(P, 30, 2, 2)), rough=0.7, ao=0.4)
b.material("metal", lambda P, N: mixc(np.tile(hexc("8a6a3a"), (len(P), 1)), hexc("4d3a20"), fbm(P, 30, 4, 7)), rough=0.4, metal=1.0, ao=0.5)  # brass
b.material("emblem", lambda P, N: mixc(np.tile(hexc("ffd75e"), (len(P), 1)), hexc("ffb12e"), fbm(P, 60, 2, 1)), rough=0.3, ao=0.0,
           emit_fn=lambda P, N: mixc(np.tile(hexc("ffd060"), (len(P), 1)), hexc("ff9d2a"), fbm(P, 60, 2, 1)), emit_strength=4.0)
b.material("glass", lambda P, N: np.tile(hexc("fff2c8"), (len(P), 1)), rough=0.05, ao=0.0, alpha=0.35, cull=False)

# ---------------------------------------------------------------- body
sk = b.mb("skin", "skin", 0.008)
sk.ellip((0, 0.012, 1.205), 0.098, 0.102, 0.112)              # head
sk.ellip((0, 0.055, 1.135), 0.055, 0.05, 0.04)                 # jaw/chin
sk.path([(0, 0.0, 1.03), (0, 0.01, 1.12)], [0.042, 0.042])     # neck
for s in (1, -1):
    sk.path([(s * 0.185, 0.0, 0.82), (s * 0.215, 0.03, 0.665)], [0.03, 0.026])   # forearms (sleeves rolled)
    sk.ellip((s * 0.222, 0.05, 0.615), 0.026, 0.032, 0.045)    # hands
    sk.ellip((s * 0.208, 0.075, 0.625), 0.012, 0.018, 0.02)    # thumbs
b.allow["skin"] = None
for s, sd in ((1, "R"), (-1, "L")):
    b.add(sphere("ear" + sd, "skin", (s * 0.097, -0.005, 1.195), 0.022, scale=(0.5, 0.8, 1.15), seg=10, rings=8), "Head")
b.add(sphere("nose", "skin", (0, 0.115, 1.19), 0.016, scale=(0.9, 1, 0.9), seg=10, rings=8), "Head")
make_eyes(b, "eye", [(0.04, 0.088, 1.215), (-0.04, 0.088, 1.215)], 0.026, [(0.12, 1, 0.02), (-0.12, 1, 0.02)])
b.add(tube("smile", "leather", bezier_pts([(-0.025, 0.103, 1.155), (0, 0.108, 1.145), (0.025, 0.103, 1.155)], 6), [0.0035] * 6, sides=5), "Head")

sh = b.mb("shirt", "cloth_shirt", 0.009)
sh.ellip((0, 0.0, 0.93), 0.118, 0.082, 0.11)
sh.ellip((0, 0.0, 0.81), 0.102, 0.078, 0.07)
for s in (1, -1):
    sh.path([(s * 0.10, 0, 1.0), (s * 0.185, 0.0, 0.82)], [0.045, 0.036])
    sh.ellip((s * 0.18, 0.0, 0.83), 0.04, 0.04, 0.03)                 # rolled cuff
b.allow["cloth_shirt"] = ["Spine", "Chest", "Neck", "UpperArm", "ForeArm"]
b.add(torus("collar", "cloth_shirt", (0, 0.0, 1.03), 0.05, 0.016, rot=(-10, 0, 0), seg=20, sides=6, scale=(1.1, 1.0, 1)), "Chest")

dn = b.mb("denim", "cloth_denim", 0.009)
dn.ellip((0, 0.0, 0.71), 0.118, 0.088, 0.09)
dn.ellip((0, 0.005, 0.79), 0.108, 0.082, 0.05)
for s in (1, -1):
    dn.path([(s * 0.07, 0.0, 0.68), (s * 0.075, 0.01, 0.36), (s * 0.075, 0.0, 0.17)], [0.064, 0.052, 0.05])
    dn.ellip((s * 0.075, 0.0, 0.17), 0.056, 0.056, 0.03)              # rolled cuff
b.allow["cloth_denim"] = ["Hips", "Spine", "Thigh", "Shin"]
b.add(shell("bib", "cloth_denim", (0.78, 0.96), -38, 38, lambda z: (0.115 + max(0, z - 0.9) * -0.2, 0.09), 0.008, 6, 10), None)
for s in (1, -1):
    b.add(tube("strap%d" % s, "cloth_denim", bezier_pts([(s * 0.055, 0.085, 0.95), (s * 0.08, 0.06, 1.01), (s * 0.085, -0.02, 1.02),
                                                          (s * 0.07, -0.085, 0.95), (s * 0.04, -0.09, 0.82)], 9),
               [0.012] * 9, sides=5, flat=0.35), None)
    b.add(sphere("button%d" % s, "metal", (s * 0.055, 0.095, 0.945), 0.012, scale=(1, 0.5, 1), seg=10, rings=6), "Chest")
b.add(box("pocket", "cloth_denim", (0, 0.095, 0.85), (0.08, 0.012, 0.06), bevel=0.004), "Spine")
b.add(box("patch", "cloth_shirt", (0.075, 0.07, 0.45), (0.05, 0.02, 0.05), rot=(0, 0, 12), bevel=0.003), "Thigh.R")

# boots (rigid)
for s, sd in ((1, "R"), (-1, "L")):
    b.add(tube("bootshaft" + sd, "leather", [(s * 0.075, 0.0, 0.05), (s * 0.075, 0.0, 0.18)], [0.052, 0.054], sides=14), "Shin." + sd)
    b.add(sphere("boot" + sd, "leather", (s * 0.075, 0.045, 0.045), 0.052, scale=(1, 1.75, 0.9), seg=16, rings=10), "Foot." + sd)
    b.add(box("sole" + sd, "leather", (s * 0.075, 0.045, 0.006), (0.088, 0.17, 0.012), bevel=0.004), "Foot." + sd)

# hair: cap + bangs + twin braids with ribbons
hr = b.mb("hair", "hair", 0.008)
hr.ellip((0, -0.012, 1.245), 0.112, 0.112, 0.108)
for k in range(5):
    a = -0.07 + 0.035 * k
    hr.ellip((a, 0.08 - abs(a) * 0.25, 1.285 - abs(a) * 0.3), 0.03, 0.022, 0.03)
for s in (1, -1):
    hr.ellip((s * 0.09, 0.02, 1.2), 0.03, 0.05, 0.06)   # side locks over the ears
b.allow["hair"] = ["Head", "Neck"]
for s, sd in ((1, "R"), (-1, "L")):
    path = bezier_pts([(s * 0.095, -0.03, 1.17), (s * 0.12, -0.02, 1.06), (s * 0.13, 0.03, 0.97), (s * 0.125, 0.05, 0.88)], 9)
    for k, p in enumerate(path):
        r = 0.032 - k * 0.0016
        side = V((0.012 if k % 2 else -0.012, 0, 0))
        b.add(sphere("braid%s%d" % (sd, k), "hair", p + side, r, scale=(1, 0.8, 1.25), seg=10, rings=8), "Head")
    b.add(sphere("ribbon%s" % sd, "cloth_ribbon", path[-1] + V((0, 0, -0.01)), 0.03, scale=(1.4, 0.5, 0.6), seg=10, rings=6), "Head")
    b.add(cone("tuft%s" % sd, "hair", path[-1] + V((0, 0, -0.015)), 0.024, 0.0, 0.07, rot=(180, 0, 0), seg=8), "Head")
for s in (1, -1):  # eyebrows
    b.add(tube("brow%d" % s, "hair", [(s * 0.022, 0.098, 1.252), (s * 0.04, 0.1, 1.257), (s * 0.058, 0.094, 1.252)], [0.005, 0.006, 0.004], sides=5), "Head")

# cheese-cave lantern hanging from the right hand
LX, LY, LZ = 0.225, 0.06, 0.60
b.add(torus("lan_ring", "metal", (LX, LY, LZ), 0.028, 0.0045, rot=(0, 90, 0), seg=16, sides=6), "Hand.R")
b.add(tube("lan_bail", "metal", [(LX, LY, LZ - 0.03), (LX, LY, LZ - 0.07)], [0.004, 0.004], sides=5), "Hand.R")
b.add(lathe("lan_cap", "metal", [(0.0, 0.0), (0.06, 0.0), (0.05, 0.02), (0.02, 0.04), (0.0, 0.045)], loc=(LX, LY, LZ - 0.115), seg=16), "Hand.R")
b.add(lathe("lan_base", "metal", [(0.0, 0.0), (0.062, 0.0), (0.062, 0.025), (0.05, 0.03), (0.0, 0.03)], loc=(LX, LY, LZ - 0.27), seg=16), "Hand.R")
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    px, py = LX + 0.05 * math.cos(a), LY + 0.05 * math.sin(a)
    b.add(tube("lan_bar%d" % k, "metal", [(px, py, LZ - 0.24), (px, py, LZ - 0.115)], [0.005, 0.005], sides=5), "Hand.R")
b.add(lathe("lan_glass", "glass", [(0.0, 0.0), (0.042, 0.0), (0.048, 0.06), (0.042, 0.125), (0.0, 0.125)], loc=(LX, LY, LZ - 0.24), seg=16), "Hand.R")
b.add(sphere("lan_core", "emblem", (LX, LY, LZ - 0.18), 0.03, scale=(1, 1, 1.25), seg=10, rings=8), "Hand.R")  # glowing cheese crystal
b.add(cone("lan_core2", "emblem", (LX, LY, LZ - 0.22), 0.022, 0.0, 0.09, seg=6), "Hand.R")


def extra(name, t, p):
    if name in ("idle",):
        add(p, "UpperArm.R", 8, 0, 0); add(p, "ForeArm.R", 10); add(p, "Hand.R", -16)
        add(p, "UpperArm.L", 0, 0, 0); add(p, "Hand.L", 0, 0, 0)
    if name in ("walk", "run", "defend"):
        add(p, "Hand.R", -20)


b.build(H, budget=29000)
b.clips(biped_clips(H, extra=extra))
b.export()
b.previews(BIPED_POSES, frame_h=H * 1.15)
