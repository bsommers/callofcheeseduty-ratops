"""party_catlib — shared Nine-Lives summon cat (large ~3 m, ethereal) for party_summon_*.py.
Design space: a unit cat (head top ~1.0) scaled by F to metres. Pattern fns get Q = P / F."""
import math
import numpy as np
from party_lib import *  # noqa

F = 3.4          # unit cat -> metres (ear/tail top ~3 m)
H = 3.0


def f(*v):
    if len(v) == 1:
        v = v[0]
    return V((v[0] * F, v[1] * F, v[2] * F))


TAIL = [(0, -0.38, 0.42), (0, -0.52, 0.45), (0, -0.64, 0.55), (0, -0.69, 0.70), (0.03, -0.65, 0.83), (0.07, -0.57, 0.88)]


def skeleton(b):
    b.bone("Root", f(0, 0, 0), f(0, 0, 0.2), deform=False)
    b.bone("Hips", f(0, -0.30, 0.40), f(0, -0.10, 0.42), "Root")
    b.bone("Spine", f(0, -0.10, 0.42), f(0, 0.10, 0.43), "Hips")
    b.bone("Chest", f(0, 0.10, 0.43), f(0, 0.24, 0.47), "Spine")
    b.bone("Neck", f(0, 0.24, 0.47), f(0, 0.32, 0.60), "Chest")
    b.bone("Head", f(0, 0.32, 0.60), f(0, 0.48, 0.63), "Neck")
    b.bone("FrontUpper.R", f(0.09, 0.21, 0.40), f(0.09, 0.25, 0.22), "Chest")
    b.bone("FrontLower.R", f(0.09, 0.25, 0.22), f(0.09, 0.25, 0.06), "FrontUpper.R")
    b.bone("FrontPaw.R", f(0.09, 0.25, 0.06), f(0.09, 0.31, 0.02), "FrontLower.R")
    b.bone("HindUpper.R", f(0.10, -0.28, 0.40), f(0.10, -0.18, 0.24), "Hips")
    b.bone("HindLower.R", f(0.10, -0.18, 0.24), f(0.10, -0.31, 0.11), "HindUpper.R")
    b.bone("HindPaw.R", f(0.10, -0.31, 0.11), f(0.10, -0.27, 0.02), "HindLower.R")
    b.bone("Ear.R", f(0.075, 0.37, 0.72), f(0.10, 0.36, 0.82), "Head")
    names, prev = [], "Hips"
    for i in range(len(TAIL) - 1):
        n = "Tail%d" % (i + 1); b.bone(n, f(TAIL[i]), f(TAIL[i + 1]), prev); prev = n; names.append(n)
    b.mirror_bones()
    return names


def body(b, mat, res, grow=0.0, fluff=1.0):
    """Cat body as one metaball group. grow adds to every radius (unit space) for the aura shell."""
    m = b.mb(mat, mat, res)
    g = grow

    def E(c, sx, sy, sz, rot=None):
        m.ellip(f(c), (sx + g) * F, (sy + g) * F, (sz + g) * F, rot=rot)

    def Pth(pts, radii):
        m.path([f(p) for p in pts], [(r + g) * F for r in radii])
    E((0, 0.40, 0.65), 0.14, 0.13, 0.12)                            # skull (big, kittenish-wise)
    for s in (1, -1):
        E((s * 0.075, 0.45, 0.60), 0.065, 0.06, 0.055)              # cheeks
        E((s * 0.13, 0.37, 0.60), 0.045 * fluff, 0.055, 0.065 * fluff)  # ruff
    E((0, 0.50, 0.60), 0.052, 0.042, 0.036)                         # muzzle
    E((0, 0.475, 0.57), 0.036, 0.036, 0.024)                        # chin
    E((0, 0.29, 0.52), 0.10, 0.09, 0.11, rot=(30, 0, 0))            # neck
    E((0, 0.21, 0.42), 0.13 * fluff, 0.12, 0.14)                    # chest / ruff
    E((0, 0.02, 0.40), 0.125, 0.22, 0.115)                          # belly / ribcage
    E((0, -0.26, 0.40), 0.13, 0.13, 0.12)                           # hips
    for s in (1, -1):
        Pth([(s * 0.09, 0.22, 0.36), (s * 0.09, 0.25, 0.22), (s * 0.09, 0.25, 0.06)], [0.055, 0.042, 0.038])
        E((s * 0.09, 0.28, 0.03), 0.048, 0.062, 0.032)              # front paws
        E((s * 0.10, -0.23, 0.31), 0.065, 0.11, 0.12)               # thighs
        Pth([(s * 0.10, -0.19, 0.24), (s * 0.10, -0.31, 0.11), (s * 0.10, -0.28, 0.04)], [0.048, 0.034, 0.034])
        E((s * 0.10, -0.25, 0.025), 0.044, 0.068, 0.028)            # hind paws
    Pth(bezier_pts(TAIL, 12), [0.05 + 0.01 * fluff - 0.002 * i for i in range(12)])
    return m


def ears(b, fur, inner, fur_ear_scale=1.0):
    for s, sd in ((1, "R"), (-1, "L")):
        rot = (-8, s * 24, s * -12)
        b.add(cone("ear" + sd, fur, f(s * 0.075, 0.375, 0.70), 0.075 * F * fur_ear_scale, 0.008 * F, 0.125 * F * fur_ear_scale, rot=rot, seg=14, scale=(1, 0.62, 1)), "Ear." + sd)
        b.add(cone("earin" + sd, inner, f(s * 0.075, 0.39, 0.705), 0.052 * F, 0.004 * F, 0.10 * F, rot=rot, seg=10, scale=(1, 0.35, 1)), "Ear." + sd)


def face(b, eye_mat, nose_mat, whisk_mat):
    make_eyes(b, eye_mat, [f(0.056, 0.488, 0.668), f(-0.056, 0.488, 0.668)], 0.04 * F,
              [(0.25, 1, 0.05), (-0.25, 1, 0.05)], scale=(1, 0.8, 0.9))
    b.add(cone("nose", nose_mat, f(0, 0.542, 0.622), 0.016 * F, 0.0, 0.014 * F, rot=(180, 0, 0), seg=3, scale=(1.3, 0.8, 1)), "Head")
    b.add(sphere("nosep", nose_mat, f(0, 0.539, 0.622), 0.014 * F, scale=(1.2, 0.7, 0.6), seg=10, rings=6), "Head")
    whiskers(b, whisk_mat, [f(0.035, 0.530, 0.60), f(0.035, 0.528, 0.592), f(0.035, 0.525, 0.585),
                            f(-0.035, 0.530, 0.60), f(-0.035, 0.528, 0.592), f(-0.035, 0.525, 0.585)],
             [(1, 0.25, 0.12), (1, 0.15, 0.0), (1, 0.1, -0.12), (-1, 0.25, 0.12), (-1, 0.15, 0.0), (-1, 0.1, -0.12)],
             0.17 * F, r=0.0022 * F)


def wisps(b, mat, n=6, seed=1, spread=1.0, bones=("Spine", "Hips", "Chest", "Tail3", "Tail5")):
    """Flowing glowing ribbons that trail backwards off the body."""
    rng = np.random.default_rng(seed)
    for k in range(n):
        bone = bones[k % len(bones)]
        h, t, _, _ = b.J[bone]
        base = h.lerp(t, rng.uniform(0.2, 0.8)) + V((rng.uniform(-0.08, 0.08) * F, 0, rng.uniform(0.02, 0.10) * F))
        L = rng.uniform(0.13, 0.24) * F * spread
        side = rng.choice([-1, 1]) * rng.uniform(0.2, 0.6)
        ctrl = [base, base + V((side * 0.25 * L, -0.25 * L, 0.45 * L)), base + V((-side * 0.1 * L, -0.6 * L, 0.8 * L)),
                base + V((side * 0.3 * L, -0.95 * L, 1.15 * L))]
        pts = bezier_pts(ctrl, 10)
        rr = 0.035 * F * rng.uniform(0.7, 1.2)
        b.add(tube("wisp%d" % k, mat, pts, [rr * (1 - i / 9) ** 0.7 for i in range(10)][:-1] + [0.0], sides=8, flat=0.7), bone)


def motes(b, mat, n=14, seed=3, r=0.012):
    rng = np.random.default_rng(seed)
    bones = ("Spine", "Chest", "Hips", "Head", "Tail4")
    for k in range(n):
        bone = bones[k % len(bones)]
        h, t, _, _ = b.J[bone]
        c = h.lerp(t, rng.uniform(0, 1)) + V(rng.normal(size=3) * np.array([0.22, 0.15, 0.15]) * F)
        c.z = max(c.z, 0.2 * F)
        b.add(sphere("mote%d" % k, mat, c, r * F * rng.uniform(0.6, 1.4), seg=8, rings=6), bone)


def finish(b, poses=None, extra=None, bg=(0.07, 0.08, 0.12)):
    b.build(H, budget=29500)
    tail = ["Tail%d" % i for i in range(1, len(TAIL))]
    b.clips(cat_clips(H, tail, extra=extra))
    b.export()
    b.previews(poses or SUMMON_POSES, frame_h=H * 2.3, look_z=H * 0.38, bg=bg, dark=True)


def paw_trails(b, mat, width=0.03, bones=("FrontPaw.R", "FrontPaw.L", "HindPaw.R", "HindPaw.L", "Tail1", "Chest")):
    """Low trailing mist/shadow tendrils flowing backwards off the paws (and optionally body)."""
    for bone in bones:
        h, t, _, _ = b.J[bone]
        sx = 1 if h.x > 0 else -1
        low = h.z < 0.2 * F
        h = V(h) if low else V((h.x, h.y, h.z - 0.10 * F))
        ctrl = [h + V((0, 0, -0.02 * F)), h + V((sx * 0.08 * F, -0.12 * F, -0.03 * F)), h + V((sx * 0.05 * F, -0.26 * F, 0.0)),
                h + V((sx * 0.12 * F, -0.36 * F, 0.06 * F))]
        p = bezier_pts(ctrl, 10)
        b.add(tube("trail_" + bone, mat, p, [width * F * (1 - i / 9) ** 0.6 for i in range(10)], sides=8, flat=0.5), bone)
