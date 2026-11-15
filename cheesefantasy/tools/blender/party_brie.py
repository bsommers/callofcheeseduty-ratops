"""hero_brie — speckled hen wizard: tiny star hat, purple capelet, whisk-topped staff.
Run: blender -b -P tools/blender/party_brie.py"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from party_lib import *  # noqa

b = Builder("hero_brie")
H = 1.12

TAIL = [(0, -0.17, 0.52), (0, -0.24, 0.62), (0, -0.27, 0.74)]
tail, ears = biped_skeleton(
    b, hip=0.36, spine=0.45, chest=0.56, neck=0.68, head=0.80, top=0.98,
    sh=(0.15, 0.0, 0.62), el=(0.235, 0.0, 0.50), wr=(0.26, 0.04, 0.40), hd=(0.265, 0.06, 0.34),
    hipx=0.075, knee=0.22, ankle=0.06, toe=0.12, tail=TAIL)

# ---------------------------------------------------------------- materials
MAHOG = hexc("7c3210"); MAHOG2 = hexc("53200a")


def feathers(P, N):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    base = mixc(MAHOG, hexc("94431a"), fbm(P, 4.0, 3, 1))
    # scalloped feather rows
    sc = 0.5 + 0.5 * np.sin(z * 150 + np.sin(np.arctan2(x, y) * 14) * 1.6)
    base = mixc(base, MAHOG2, smoothstep(0.75, 0.98, sc) * 0.6)
    # Sussex speckles: white tip with black crescent
    n = vnoise(P * np.array([1.0, 1.0, 1.4]), 120.0, 3)
    blk = smoothstep(0.72, 0.75, n) * (1 - smoothstep(0.78, 0.80, n))
    wht = smoothstep(0.79, 0.83, n)
    col = mixc(base, hexc("1c1410"), blk * 0.9)
    col = mixc(col, hexc("ece4d6"), wht)
    # paler, finer speckle on the face; golden hackles on the neck
    head = smoothstep(0.74, 0.79, z)
    col = mixc(col, mixc(hexc("b8702e"), hexc("ece4d6"), smoothstep(0.8, 0.88, vnoise(P, 150, 6))), head * 0.7)
    neck = smoothstep(0.62, 0.68, z) * (1 - head)
    col = mixc(col, hexc("c7782f"), neck * 0.55)
    return fur_detail(P, col, 1.0, 0.14, 2)


b.material("fur", feathers, rough=0.8, ao=0.7)
b.material("skin", lambda P, N: mixc(np.tile(hexc("e9b03a"), (len(P), 1)), hexc("c2801f"),
                                     smoothstep(0.6, 0.9, 0.5 + 0.5 * np.sin(P[:, 2] * 260))), rough=0.55, ao=0.5)
b.material("skin_comb", lambda P, N: fur_detail(P, mixc(np.tile(hexc("d4262a"), (len(P), 1)), hexc("9e1418"), fbm(P, 30, 3, 4)), 1, 0.1), rough=0.45, ao=0.4)
b.material("beak", lambda P, N: mixc(np.tile(hexc("f2b324"), (len(P), 1)), hexc("c47a12"), smoothstep(0.86, 0.95, P[:, 1] / 0.2)), rough=0.35, ao=0.3)
b.material("eye", eye_fn("e09a1c", (-0.6, 0.8, 0.05), (0.6, 0.8, 0.05), pupil="round", iris2="a0560c"), rough=0.08, ao=0.0)


def robe(P, N):
    col = mixc(np.tile(hexc("5b2f8e"), (len(P), 1)), hexc("3d1d66"), fbm(P, 8, 4, 5))
    # gold trim near the lower hem + scattered tiny stars
    hem = smoothstep(0.022, 0.012, np.abs(P[:, 2] - 0.405))
    st = smoothstep(0.86, 0.9, vnoise(P, 70, 9))
    col = mixc(col, hexc("e7b93b"), np.clip(hem + st, 0, 1))
    return fur_detail(P, col, 1, 0.05, 7)


b.material("cloth_cape", robe, rough=0.75, ao=0.6)


def hat(P, N):
    col = mixc(np.tile(hexc("5b2f8e"), (len(P), 1)), hexc("3d1d66"), fbm(P, 10, 3, 2))
    st = smoothstep(0.84, 0.88, vnoise(P, 80, 4))
    band = smoothstep(0.012, 0.006, np.abs(P[:, 2] - 0.985))
    return mixc(col, hexc("f1c74a"), np.clip(st + band, 0, 1))


b.material("cloth_hat", hat, rough=0.75, ao=0.5)
b.material("metal", lambda P, N: mixc(np.tile(hexc("d7dadc"), (len(P), 1)), hexc("9aa0a4"), fbm(P, 50, 3, 1)), rough=0.25, metal=1.0, ao=0.2)
b.material("leather", lambda P, N: mixc(np.tile(hexc("7a4a24"), (len(P), 1)), hexc("4b2a12"),
                                        smoothstep(0.3, 0.7, fbm(P * np.array([6, 6, 0.6]), 30, 4, 2))), rough=0.65, ao=0.5)
b.material("emblem", lambda P, N: np.tile(hexc("ffd65a"), (len(P), 1)), rough=0.3, metal=0.0, ao=0.0,
           emit_fn=lambda P, N: np.tile(hexc("ffcf5a"), (len(P), 1)), emit_strength=2.5)

# ---------------------------------------------------------------- body
m = b.mb("fur", "fur", 0.011)
m.ellip((0, 0.01, 0.50), 0.185, 0.205, 0.215)          # plump egg body
m.ellip((0, 0.08, 0.56), 0.13, 0.12, 0.13)             # puffed breast
m.ellip((0, -0.06, 0.46), 0.15, 0.15, 0.15)            # fluffy rear
m.ellip((0, 0.03, 0.70), 0.075, 0.075, 0.09)           # neck
m.ellip((0, 0.05, 0.84), 0.105, 0.11, 0.105)           # head
for s in (1, -1):
    m.ellip((s * 0.06, 0.09, 0.82), 0.05, 0.05, 0.05)  # cheeks
    m.ellip((s * 0.085, 0.02, 0.33), 0.065, 0.065, 0.07)  # feathered thighs ("pantaloons")
    # wings along the arm chain (flattened, feathers fan down)
    m.ellip((s * 0.17, -0.005, 0.57), 0.04, 0.10, 0.075, rot=(0, s * -20, 0))
    m.ellip((s * 0.215, 0.0, 0.48), 0.035, 0.085, 0.075, rot=(0, s * -12, 0))
    m.ellip((s * 0.245, 0.03, 0.40), 0.03, 0.06, 0.05)
b.allow["fur"] = None
# primary feathers (rigid to hands) and tail feathers
for s, sd in ((1, "R"), (-1, "L")):
    for k in range(3):
        b.add(cone("prim%s%d" % (sd, k), "fur", (s * 0.255, 0.06 - 0.03 * k, 0.40), 0.045, 0.0, 0.11 + 0.015 * k,
                   rot=(180 - 12 * k, s * 8, 0), seg=6, scale=(0.35, 1, 1)), "Hand." + sd)
for k in range(5):
    a = -40 + 20 * k
    b.add(cone("tailf%d" % k, "fur", (0, -0.20, 0.58), 0.065, 0.0, 0.26 - abs(a) * 0.0015,
               rot=(30 + abs(a) * 0.15, a * 0.8, 0), seg=6, scale=(1, 0.25, 1)), "Tail2")

# legs: scaly yellow shins and toes (rigid)
for s, sd in ((1, "R"), (-1, "L")):
    b.add(tube("shin" + sd, "skin", [(s * 0.075, 0.008, 0.26), (s * 0.075, 0.004, 0.15), (s * 0.075, 0.0, 0.05)], [0.022, 0.018, 0.017], sides=8), "Shin." + sd)
    for k, a in enumerate((-28, 0, 28)):
        d = V((math.sin(math.radians(a)), math.cos(math.radians(a)), 0))
        p0 = V((s * 0.075, 0.0, 0.03)); p1 = p0 + d * 0.07 + V((0, 0, -0.012)); p2 = p0 + d * 0.11 + V((0, 0, -0.022))
        b.add(tube("toe%s%d" % (sd, k), "skin", [p0, p1, p2], [0.016, 0.012, 0.0], sides=6), "Foot." + sd)
    b.add(tube("toeb" + sd, "skin", [(s * 0.075, 0.0, 0.03), (s * 0.075, -0.05, 0.012)], [0.012, 0.0], sides=6), "Foot." + sd)

# face: beak, comb, wattle, eyes
b.add(cone("beak_u", "beak", (0, 0.135, 0.845), 0.045, 0.0, 0.095, rot=(-100, 0, 0), seg=10, scale=(1, 0.75, 1)), "Head")
b.add(cone("beak_l", "beak", (0, 0.13, 0.822), 0.032, 0.0, 0.065, rot=(-106, 0, 0), seg=8, scale=(0.9, 0.6, 1)), "Head")
for k, (yy, zz, r) in enumerate(((0.135, 0.925, 0.036), (0.105, 0.955, 0.042), (0.07, 0.968, 0.04), (0.035, 0.96, 0.034))):
    b.add(sphere("comb%d" % k, "skin_comb", (0, yy, zz), r, scale=(0.45, 1, 1.15), seg=12, rings=8), "Head")
for s in (1, -1):
    b.add(sphere("wattle%d" % s, "skin_comb", (s * 0.014, 0.125, 0.775), 0.024, scale=(0.7, 0.7, 1.4), seg=10, rings=8), "Head")
make_eyes(b, "eye", [(0.072, 0.115, 0.865), (-0.072, 0.115, 0.865)], 0.033, [(0.55, 0.83, 0.05), (-0.55, 0.83, 0.05)])

# ---------------------------------------------------------------- wizard outfit


def body_r(z):
    t = (z - 0.50) / 0.215
    rx = 0.185 * math.sqrt(max(0.0, 1 - t * t))
    return max(rx, 0.085)


b.add(shell("capelet", "cloth_cape", (0.40, 0.70), -100, 100,
            lambda z: (body_r(z) + 0.03 + (0.70 - z) * 0.12, (body_r(z) + 0.03) * 1.12 + (0.70 - z) * 0.12), 0.007, 10, 26, cy=0.0))
b.allow["cloth_cape"] = ["Spine", "Chest", "Neck"]
# cape faces backwards: rotate the shell 180 deg about Z
cap = b.parts[-1][0]
cap.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
b.add(torus("collar", "cloth_cape", (0, 0.025, 0.70), 0.085, 0.02, rot=(-12, 0, 0), seg=24, sides=8), "Chest")
b.add(sphere("clasp", "emblem", (0, 0.115, 0.685), 0.02, scale=(1, 0.5, 1), seg=10, rings=6), "Chest")
# tiny wizard hat, jauntily tilted
hrot = (8, 14, 0)
b.add(lathe("hat_brim", "cloth_hat", [(0.0, 0.0), (0.085, 0.0), (0.09, 0.008), (0.0, 0.012)], loc=(0.02, -0.045, 0.945), rot=hrot, seg=24), "Head")
b.add(tube("hat_cone", "cloth_hat", bezier_pts([(0.025, -0.05, 0.95), (0.04, -0.065, 1.05), (0.075, -0.09, 1.12), (0.12, -0.12, 1.14)], 8),
           [0.055, 0.048, 0.038, 0.028, 0.019, 0.011, 0.005, 0.0], sides=12), "Head")
b.add(sphere("hat_star", "emblem", (0.125, -0.122, 1.14), 0.016, seg=8, rings=6), "Head")

# whisk staff in the right wing
SX, SY = 0.265, 0.06
b.add(tube("staff", "leather", [(SX, SY, 0.02), (SX, SY, 0.5), (SX, SY + 0.005, 1.0)], [0.014, 0.015, 0.013], sides=8), "Hand.R")
b.add(tube("staff_grip", "cloth_cape", [(SX, SY, 0.30), (SX, SY, 0.44)], [0.018, 0.018], sides=8), "Hand.R")
b.add(tube("whisk_neck", "metal", [(SX, SY + 0.005, 0.98), (SX, SY + 0.005, 1.06)], [0.019, 0.016], sides=10), "Hand.R")
for k in range(6):
    a = math.pi * k / 6
    d = V((math.cos(a), math.sin(a), 0))
    pts = bezier_pts([V((SX, SY + 0.005, 1.06)), V((SX, SY + 0.005, 1.10)) + d * 0.05, V((SX, SY + 0.005, 1.20)) + d * 0.068,
                      V((SX, SY + 0.005, 1.27)) + d * 0.03, V((SX, SY + 0.005, 1.285)),
                      V((SX, SY + 0.005, 1.27)) - d * 0.03, V((SX, SY + 0.005, 1.20)) - d * 0.068,
                      V((SX, SY + 0.005, 1.10)) - d * 0.05, V((SX, SY + 0.005, 1.06))], 26)
    b.add(tube("wire%d" % k, "metal", pts, [0.0035] * len(pts), sides=5, cap=False), "Hand.R")
b.add(sphere("whisk_glow", "emblem", (SX, SY + 0.005, 1.17), 0.03, seg=12, rings=8), "Hand.R")  # magic spark in the cage


def extra(name, t, p):
    if name in ("idle", "walk", "defend"):
        add(p, "Hand.R", -14, 0, 0)
    for s in ("R", "L"):  # wings flare a little when casting
        if name == "cast":
            add(p, "UpperArm." + s, 0, 0, 0)


b.build(H, budget=29000)
b.clips(biped_clips(H, tail=tail, extra=extra))
b.export()
b.previews(BIPED_POSES, frame_h=H * 1.35, look_z=H * 0.6)
