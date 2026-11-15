"""hero_fennel — ginger tabby kitten chef (apron, toque, red neckerchief, cheese knife).
Run: blender -b -P tools/blender/party_fennel.py   (PARTY_SAMPLES / PARTY_POSES env tune previews)"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from party_lib import *  # noqa

b = Builder("hero_fennel")
H = 1.18

# ---------------------------------------------------------------- skeleton
TAIL = [(0, -0.10, 0.44), (0, -0.20, 0.43), (0, -0.28, 0.50), (0.02, -0.31, 0.62), (0.05, -0.29, 0.74)]
tail, ears = biped_skeleton(
    b, hip=0.42, spine=0.50, chest=0.60, neck=0.71, head=0.76, top=1.02,
    sh=(0.115, 0, 0.665), el=(0.185, 0.01, 0.545), wr=(0.215, 0.04, 0.435), hd=(0.22, 0.06, 0.38),
    hipx=0.07, knee=0.24, ankle=0.07, toe=0.13, tail=TAIL, ears=((0.095, 0.0, 0.95), (0.135, -0.005, 1.04)))

# ---------------------------------------------------------------- materials
ORANGE = hexc("dc761f"); DARK = hexc("86380c"); CREAM = hexc("f6e7d2")


def fur(P, N):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    base = mixc(ORANGE, hexc("e9953f"), fbm(P, 5.0, 3, 2))
    # stripes: horizontal bands on torso/limbs, around the tail, forehead lines on head
    s_body = stripes(P, 75, (0.15, 0.2, 1.0), 1.6, 1, 0.34)
    s_tail = stripes(P, 60, (0.0, 0.6, 0.8), 1.0, 4, 0.5)
    s_head = stripes(P, 70, (1.0, 0.0, 0.25), 1.2, 5, 0.38) * smoothstep(0.86, 0.93, z) * smoothstep(0.02, 0.10, y)
    s_cheek = stripes(P, 80, (0.0, 0.3, 1.0), 0.8, 6, 0.35) * smoothstep(0.07, 0.13, np.abs(x)) * (z > 0.74)
    head = z > 0.74
    tailr = (y < -0.165) & (z > 0.36)
    s = np.where(head, np.maximum(s_head, s_cheek), np.where(tailr, s_tail, s_body))
    col = mixc(base, DARK, s * 0.85)
    # white muzzle, chest, belly, paws, tail tip
    muzzle = smoothstep(0.075, 0.035, np.hypot(x * 0.8, z - 0.80)) * smoothstep(0.06, 0.11, y) * head
    chin = smoothstep(0.06, 0.02, np.abs(x)) * smoothstep(0.78, 0.74, z) * smoothstep(0.05, 0.1, y) * (z > 0.68)
    chest = smoothstep(0.085, 0.04, np.abs(x)) * smoothstep(0.03, 0.09, y) * (z > 0.44) * (z < 0.74)
    paws = smoothstep(0.075, 0.05, z) + smoothstep(0.40, 0.37, z) * smoothstep(0.17, 0.2, np.abs(x)) * (z > 0.3)
    tip = smoothstep(0.70, 0.74, z) * tailr
    w = np.clip(muzzle + chin + chest + paws + tip, 0, 1)
    col = mixc(col, CREAM, w)
    return fur_detail(P, col, 1.0, 0.16)


b.material("fur", fur, rough=0.85, ao=0.7)
b.material("skin", lambda P, N: np.tile(hexc("e8939a"), (len(P), 1)), rough=0.5, ao=0.4)
b.material("eye", eye_fn("7fbf3f", (-0.18, 1, 0.02), (0.18, 1, 0.02), pupil="round", iris2="3a6e1c"), rough=0.08, ao=0.0)


def apron(P, N):
    base = np.tile(hexc("f3efe6"), (len(P), 1))
    pin = smoothstep(0.75, 0.95, 0.5 + 0.5 * np.sin(np.arctan2(P[:, 0], P[:, 1]) * 46))
    col = mixc(base, hexc("8fb0d8"), pin * 0.55)
    stain = smoothstep(0.62, 0.72, fbm(P, 9.0, 4, 8)) * 0.35
    col = mixc(col, hexc("d9b26a"), stain)  # cheese smudges
    return fur_detail(P, col, 1.0, 0.06, 9)


b.material("cloth_apron", apron, rough=0.9, ao=0.6)
b.material("cloth_hat", lambda P, N: fur_detail(P, mixc(np.tile(hexc("fbfaf6"), (len(P), 1)), hexc("e4e0d6"), fbm(P, 14, 3, 3)), 1, 0.05), rough=0.85, ao=0.7)
b.material("cloth_scarf", lambda P, N: mixc(np.tile(hexc("c8322b"), (len(P), 1)), hexc("f1e4c8"),
                                            smoothstep(0.82, 0.9, 0.5 + 0.5 * np.sin(P[:, 0] * 160) * np.sin(P[:, 2] * 160))), rough=0.8, ao=0.5)
b.material("metal", lambda P, N: mixc(np.tile(hexc("cfd3d6"), (len(P), 1)), hexc("8d9396"), fbm(P, 40, 3, 1)), rough=0.28, metal=1.0, ao=0.2)
b.material("leather", lambda P, N: mixc(np.tile(hexc("6b3d1e"), (len(P), 1)), hexc("3f2210"), fbm(P * np.array([1, 8, 1]), 30, 3, 2)), rough=0.6, ao=0.4)
b.material("emblem", lambda P, N: mixc(np.tile(hexc("f2c230"), (len(P), 1)), hexc("c98d12"), smoothstep(0.5, 0.7, fbm(P, 60, 2, 5))), rough=0.5, ao=0.3)
b.material("whisker", lambda P, N: np.tile(hexc("f4f1ea"), (len(P), 1)), rough=0.4, ao=0.0)

# ---------------------------------------------------------------- body (metaballs)
m = b.mb("fur", "fur", 0.011)
m.ellip((0, 0.01, 0.865), 0.175, 0.155, 0.148)                 # big kitten head
for s in (1, -1):
    m.ball((s * 0.085, 0.065, 0.815), 0.078)                   # cheeks
    m.ellip((s * 0.155, 0.02, 0.82), 0.035, 0.03, 0.045, stiff=1.6)  # cheek ruff
m.ellip((0, 0.115, 0.80), 0.058, 0.042, 0.036)                  # muzzle
m.ellip((0, 0.105, 0.775), 0.036, 0.03, 0.02)                   # chin
m.ellip((0, 0.0, 0.70), 0.07, 0.065, 0.05)                      # neck
m.ellip((0, 0.0, 0.615), 0.125, 0.105, 0.105)                   # chest
m.ellip((0, 0.012, 0.525), 0.138, 0.118, 0.10)                  # tummy
m.ellip((0, -0.01, 0.445), 0.125, 0.11, 0.08)                   # hips
for s in (1, -1):
    m.path([(s * 0.10, 0, 0.665), (s * 0.185, 0.01, 0.545), (s * 0.215, 0.04, 0.435)], [0.05, 0.04, 0.037])
    m.ellip((s * 0.222, 0.055, 0.395), 0.042, 0.046, 0.045)      # paw
    m.path([(s * 0.07, 0, 0.43), (s * 0.075, 0.01, 0.24), (s * 0.075, 0.0, 0.08)], [0.068, 0.05, 0.043])
    m.ellip((s * 0.075, 0.045, 0.04), 0.052, 0.085, 0.04)       # hind paw
m.path(bezier_pts(TAIL, 9), [0.042, 0.04, 0.038, 0.037, 0.036, 0.035, 0.034, 0.033, 0.03])
b.allow["fur"] = None

# ears (rigid to Ear bones), inner ear skin
for s, sd in ((1, "R"), (-1, "L")):
    rot = (0, s * 22, s * -8)
    b.add(cone("ear" + sd, "fur", (s * 0.092, -0.005, 0.935), 0.062, 0.006, 0.12, rot=rot, seg=12, scale=(1, 0.45, 1)), "Ear." + sd)
    b.add(cone("earin" + sd, "skin", (s * 0.092, 0.012, 0.94), 0.042, 0.004, 0.095, rot=rot, seg=10, scale=(1, 0.25, 1)), "Ear." + sd)

make_eyes(b, "eye", [(0.066, 0.118, 0.875), (-0.066, 0.118, 0.875)], 0.047, [(0.18, 1, 0.02), (-0.18, 1, 0.02)])
b.add(sphere("nose", "skin", (0, 0.158, 0.822), 0.018, scale=(1.25, 0.8, 0.8), seg=12, rings=8), "Head")
for s in (1, -1):  # mouth line
    b.add(tube("mouth%d" % s, "leather", [(0, 0.152, 0.797), (s * 0.016, 0.153, 0.788), (s * 0.03, 0.146, 0.792)], [0.003, 0.003, 0.002], sides=4), "Head")
whiskers(b, "whisker", [(0.045, 0.15, 0.805), (0.045, 0.148, 0.795), (-0.045, 0.15, 0.805), (-0.045, 0.148, 0.795)],
         [(1, 0.15, 0.08), (1, 0.1, -0.12), (-1, 0.15, 0.08), (-1, 0.1, -0.12)], 0.13, r=0.0025)

# ---------------------------------------------------------------- outfit
def torso_r(z):
    # outer apron radius following the metaball torso (plus clearance), flaring into a skirt
    if z > 0.56:
        rx = 0.125 + 0.02 * (0.66 - z) / 0.1
    elif z > 0.44:
        rx = 0.15
    else:
        rx = 0.15 + (0.44 - z) * 0.35
    return rx, rx * 0.88


b.add(shell("apron_bib", "cloth_apron", (0.55, 0.665), -38, 38, lambda z: (torso_r(z)[0] - 0.005 + max(0, 0.6 - z) * 0.1, torso_r(z)[1] + 0.012), 0.006, 6, 10))
b.add(shell("apron_skirt", "cloth_apron", (0.30, 0.56), -80, 80, lambda z: (torso_r(z)[0] + 0.006, torso_r(z)[1] + 0.012), 0.006, 12, 22))
b.allow["cloth_apron"] = ["Hips", "Spine", "Chest", "Thigh"]
b.add(ring_band("belt", "cloth_apron", 0.545, lambda z: (0.148, 0.135), 0.022, 0.006), None)
for s in (1, -1):  # neck straps
    b.add(tube("strap%d" % s, "cloth_apron", [(s * 0.055, 0.115, 0.665), (s * 0.07, 0.06, 0.70), (s * 0.05, -0.04, 0.715)], [0.008, 0.008, 0.008], sides=5, flat=0.4))
# apron bow at the back
for s in (1, -1):
    b.add(sphere("bow%d" % s, "cloth_apron", (s * 0.03, -0.13, 0.545), 0.03, scale=(1.2, 0.35, 0.7), seg=10, rings=6), "Spine")
    b.add(tube("tie%d" % s, "cloth_apron", [(s * 0.01, -0.13, 0.54), (s * 0.03, -0.135, 0.47), (s * 0.045, -0.13, 0.41)], [0.01, 0.01, 0.004], sides=4, flat=0.3), "Hips")
# cheese wedge emblem on the bib + pocket
b.add(box("emblem", "emblem", (0, 0.122, 0.615), (0.05, 0.01, 0.035), rot=(0, 18, 0), bevel=0.003), "Chest")
b.add(box("pocket", "cloth_apron", (0.07, 0.15, 0.40), (0.07, 0.012, 0.055), rot=(0, 0, 28), bevel=0.004), "Hips")

# neckerchief
b.add(torus("scarf", "cloth_scarf", (0, 0.0, 0.715), 0.075, 0.022, rot=(-8, 0, 0), seg=24, sides=8, scale=(1, 0.9, 1)), "Chest")
b.add(cone("scarf_knot", "cloth_scarf", (0, 0.085, 0.705), 0.035, 0.0, 0.07, rot=(160, 0, 0), seg=8, scale=(1, 0.4, 1)), "Chest")

# chef toque (tilted back)
hat_rot = (10, 0, 6)
b.add(lathe("hat_band", "cloth_hat", [(0.0, 0.0), (0.082, 0.0), (0.085, 0.05), (0.0, 0.05)], loc=(0, -0.01, 0.985), rot=hat_rot, seg=24), "Head")
b.add(sphere("hat_puff", "cloth_hat", (0.006, -0.03, 1.085), 0.108, scale=(1.0, 1.0, 0.72), seg=20, rings=12), "Head")
for k in range(5):
    a = k / 5 * 2 * math.pi
    b.add(sphere("hat_pleat%d" % k, "cloth_hat", (0.006 + 0.07 * math.cos(a), -0.03 + 0.07 * math.sin(a), 1.10), 0.06, scale=(1, 1, 0.8), seg=12, rings=8), "Head")

# cheese knife: leather-wrapped wood handle, wide holed blade with forked tip
HX, HY, HZ = 0.222, 0.05, 0.395
b.add(tube("knife_handle", "leather", [(HX, HY - 0.05, HZ), (HX, HY + 0.02, HZ), (HX, HY + 0.07, HZ)], [0.014, 0.016, 0.014], sides=8), "Hand.R")
b.add(sphere("knife_pommel", "metal", (HX, HY - 0.055, HZ), 0.017, seg=10, rings=6), "Hand.R")
b.add(box("knife_bolster", "metal", (HX, HY + 0.078, HZ), (0.02, 0.014, 0.034), bevel=0.003), "Hand.R")
blade_pts = [(HX, HY + 0.085, HZ + 0.005), (HX, HY + 0.19, HZ + 0.005), (HX, HY + 0.26, HZ + 0.01)]
b.add(tube("knife_blade", "metal", blade_pts, [0.026, 0.024, 0.018], sides=8, flat=0.12, twist_up=(1, 0, 0)), "Hand.R")
for s in (1, -1):
    b.add(cone("knife_fork%d" % s, "metal", (HX, HY + 0.255, HZ + 0.01 + s * 0.01), 0.005, 0.0, 0.035, rot=(-90, 0, 0), seg=5, scale=(0.4, 1, 1)), "Hand.R")

# ---------------------------------------------------------------- build / animate / export / preview


def extra(name, t, p):
    if name == "idle":  # the knife hand rests forward, tail curls
        add(p, "UpperArm.R", 14, 0, 0); add(p, "ForeArm.R", 18)


b.build(H, budget=29000)
b.clips(biped_clips(H, tail=tail, ears=ears, extra=extra))
b.export()
b.previews(BIPED_POSES, frame_h=H * 1.2)
