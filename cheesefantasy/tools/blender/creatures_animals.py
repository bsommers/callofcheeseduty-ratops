"""Farm animals: blender -b -P tools/blender/creatures_animals.py [-- id ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lib_common import *

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def quad(name, L, W, H, leg, legr, headr, body, snout=None, neck=0.0, head_h=None):
    """Quadruped skeleton + body, legs, head. Returns Model. L=body length, W=width, H=body depth, leg=leg length."""
    m = Model(name)
    hz = leg + H * 0.5
    hy = L * 0.5
    head_h = head_h if head_h is not None else hz + H * 0.15
    m.bone("root", None, (0, 0, 0), (0, 0.1, 0.05))
    m.bone("body", "root", (0, -hy * 0.6, hz), (0, hy * 0.6, hz))
    m.bone("head", "body", (0, hy * 0.7, head_h - 0.05), (0, hy * 0.7 + headr * 1.4, head_h))
    m.bone("tail", "body", (0, -hy * 0.95, hz + H * 0.2), (0, -hy * 1.3, hz + H * 0.1))
    lx, fy, by = W * 0.36, hy * 0.62, -hy * 0.62
    for nm, x, y in (("leg_fl", lx, fy), ("leg_fr", -lx, fy), ("leg_bl", lx, by), ("leg_br", -lx, by)):
        m.bone(nm, "body", (x, y, leg + 0.02), (x, y, 0.02))
        m.add(nm, cyl((x, y, leg / 2 + 0.02), (legr * 2, legr * 2, leg + 0.02), body, r1=0.8, r2=1.0))
        m.add(nm, cyl((x, y + legr * 0.4, 0.04), (legr * 2.3, legr * 3, 0.09), "hoof" if False else mat("hoof", PAL["black"], 0.5)))
    m.add("body", sphere((0, 0, hz), (W, L, H), body))
    m.add("head", sphere((0, hy * 0.7 + headr * 0.5, head_h), (headr * 1.7, headr * 1.9, headr * 1.6), body))
    if neck:
        m.add("body", sphere((0, hy * 0.55, hz + H * 0.25), (W * 0.55, L * 0.25, H * 0.8), body, rot=(-25, 0, 0)))
    # eyes
    for s in (1, -1):
        m.add("head", sphere((s * headr * 0.62, hy * 0.7 + headr * 0.95, head_h + headr * 0.3), (0.05, 0.05, 0.05), mat("eye", PAL["black"], 0.2)))
        m.add("head", sphere((s * headr * 0.66, hy * 0.7 + headr * 0.98, head_h + headr * 0.34), (0.015, 0.015, 0.015), mat("eyeshine", PAL["white"], 0.1)))
    m.hz, m.hy, m.hh, m.headr, m.leg = hz, hy, head_h, headr, leg
    return m


def quad_anims(m, swing=28, bob=0.02, hz=None, tailw=10, gait=1.0):
    def idle(t):
        return {"body": (sin(t) * 1.2, 0, 0, 0, 0, sin(t) * 0.006), "head": (sin(t, 0.2) * 6, sin(t, .5) * 5, 0),
                "tail": (0, 0, sin(t, .3) * tailw)}

    def walk(amp, b, g):
        def f(t):
            a = sin(t) * amp
            d = {"leg_fl": (a, 0, 0), "leg_br": (a, 0, 0), "leg_fr": (-a, 0, 0), "leg_bl": (-a, 0, 0),
                 "body": (0, 0, sin(t * 2) * 2, 0, 0, abs(sin(t)) * b), "head": (sin(t * 2) * 4, 0, 0),
                 "tail": (0, 0, sin(t * 2) * tailw * 1.5)}
            return d
        return f
    m.clip("idle", 48, idle, samples=12)
    m.clip("walk", 24, walk(swing, bob, 1), samples=12)
    m.clip("run", 14, walk(swing * 1.5, bob * 2.2, 1), samples=8)
    m.clip("hurt", 14, lambda t: {"body": (-18 * math.sin(t * math.pi), 0, 0), "head": (-25 * math.sin(t * math.pi), 0, 0)}, loop=False, samples=6)


def cow():
    m = quad("animal_cow", 1.7, 0.95, 0.9, 0.55, 0.1, 0.27, "white", neck=1)
    wh = m.parts[0][1].data.materials[0]
    for x, y, z, s in ((0.28, 0.2, 1.25, .42), (-0.3, -0.35, 1.15, .5), (0.25, -0.5, 1.0, .35), (-0.2, 0.45, 1.1, .3)):
        m.add("body", sphere((x, y, z), (s, s * 0.9, s * 0.75), mat("patch", PAL["cow_dk"], 0.7), seg=10))
    m.add("head", sphere((0, m.hy * 0.7 + 0.5, m.hh - 0.07), (0.34, 0.26, 0.22), mat("muzzle", PAL["pink"], 0.5)))
    for s in (1, -1):
        m.add("head", cone((s * 0.2, m.hy * 0.7 + 0.05, m.hh + 0.27), (0.07, 0.07, 0.2), mat("horn", PAL["cream"], 0.4), rot=(0, s * 35, 0)))
        m.add("head", sphere((s * 0.3, m.hy * 0.7 + 0.05, m.hh + 0.12), (0.2, 0.08, 0.1), "white", rot=(0, 0, s * 20)))
    m.add("body", sphere((0, -0.4, 0.8), (0.3, 0.35, 0.18), mat("udder", PAL["pink"], 0.5)))
    m.add("tail", cyl((0, -m.hy * 1.1, m.hz - 0.1), (0.04, 0.04, 0.6), "white", rot=(-15, 0, 0)))
    m.add("tail", sphere((0, -m.hy * 1.2, m.hz - 0.4), (0.12, 0.12, 0.2), mat("patch")))
    m.build(); quad_anims(m); return m


def pig():
    m = quad("animal_pig", 1.1, 0.7, 0.65, 0.24, 0.085, 0.22, mat("pig", PAL["pink"], 0.55), head_h=0.62)
    m.add("head", cyl((0, m.hy * 0.7 + 0.37, m.hh - 0.04), (0.2, 0.2, 0.12), mat("snout", (0.98, 0.5, 0.52), 0.5), rot=(90, 0, 0)))
    for s in (1, -1):
        m.add("head", cone((s * 0.14, m.hy * 0.7 + 0.12, m.hh + 0.19), (0.12, 0.05, 0.16), "pig", rot=(15, 0, s * 35)))
        m.add("head", sphere((s * 0.04, m.hy * 0.7 + 0.43, m.hh - 0.04), (0.03, 0.03, 0.03), mat("nostril", PAL["cow_dk"])))
    m.add("tail", torus((0, -m.hy * 1.05, m.hz + 0.1), 0.06, 0.015, "pig", rot=(0, 90, 0)))
    m.build(); quad_anims(m, swing=30, bob=0.015, tailw=25); return m


def goat():
    m = quad("animal_goat", 1.0, 0.5, 0.52, 0.45, 0.055, 0.17, mat("goat", PAL["cream"], 0.8), neck=1, head_h=0.98)
    for s in (1, -1):
        m.add("head", cone((s * 0.07, m.hy * 0.7 - 0.02, m.hh + 0.2), (0.05, 0.05, 0.3), mat("horn", PAL["wood_lt"], 0.5), rot=(-35, s * 12, 0)))
        m.add("head", sphere((s * 0.19, m.hy * 0.7, m.hh + 0.03), (0.22, 0.06, 0.08), "goat", rot=(0, 0, s * -15)))
    m.add("head", cone((0, m.hy * 0.7 + 0.26, m.hh - 0.22), (0.09, 0.07, 0.2), "goat", rot=(180, 0, 0)))
    m.add("tail", cone((0, -m.hy * 1.08, m.hz + 0.12), (0.08, 0.08, 0.2), "goat", rot=(-70, 0, 0)))
    m.build(); quad_anims(m, swing=30, tailw=12); return m


def sheep():
    m = quad("animal_sheep", 1.05, 0.65, 0.6, 0.3, 0.05, 0.16, mat("sheepface", PAL["rat_dk"], 0.8), head_h=0.68)
    wool = mat("wool", PAL["white"], 0.95)
    import random
    random.seed(4)
    for i in range(14):
        x = random.uniform(-0.25, 0.25); y = random.uniform(-0.4, 0.4); z = m.hz + random.uniform(-0.1, 0.22)
        m.add("body", ico((x, y, z), (0.36, 0.36, 0.34), wool, sub=1))
    m.add("body", ico((0, 0.0, m.hz), (0.75, 1.0, 0.65), wool, sub=2))
    m.add("head", ico((0, m.hy * 0.7 + 0.05, m.hh + 0.18), (0.26, 0.2, 0.17), wool, sub=1))
    for s in (1, -1):
        m.add("head", sphere((s * 0.17, m.hy * 0.7 + 0.04, m.hh + 0.03), (0.16, 0.06, 0.08), "sheepface", rot=(0, 0, s * -25)))
    m.build(); quad_anims(m, swing=22, tailw=6); return m


def dog():
    m = quad("animal_dog", 0.85, 0.36, 0.38, 0.3, 0.055, 0.14, mat("dogfur", (0.72, 0.5, 0.25), 0.85), head_h=0.6)
    m.add("head", sphere((0, m.hy * 0.7 + 0.28, m.hh - 0.04), (0.13, 0.2, 0.11), mat("dogmuzzle", PAL["cream"], 0.8)))
    m.add("head", sphere((0, m.hy * 0.7 + 0.38, m.hh - 0.0), (0.06, 0.05, 0.05), mat("nose", PAL["black"], 0.3)))
    for s in (1, -1):
        m.add("head", sphere((s * 0.14, m.hy * 0.7 + 0.05, m.hh + 0.0), (0.07, 0.12, 0.2), mat("ear", (0.4, 0.26, 0.13), 0.8), rot=(0, 0, s * 15)))
    m.add("body", sphere((0, 0.1, m.hz - 0.1), (0.3, 0.4, 0.22), "dogmuzzle"))
    m.add("tail", cone((0, -m.hy * 1.1, m.hz + 0.2), (0.07, 0.07, 0.45), "dogfur", rot=(-45, 0, 0)))
    m.build(); quad_anims(m, swing=34, bob=0.03, tailw=30); return m


def bird(name, body, beak, comb, bw, neckh, duck=False):
    m = Model(name)
    hz = 0.32 if not duck else 0.2
    sz = bw
    m.bone("root", None, (0, 0, 0), (0, 0.1, 0.05))
    m.bone("body", "root", (0, -0.1, hz), (0, 0.1, hz))
    m.bone("head", "body", (0, 0.12 * sz / 0.3, hz + neckh * 0.5), (0, 0.15, hz + neckh))
    m.bone("tail", "body", (0, -0.2 * sz / 0.3, hz), (0, -0.3 * sz / 0.3, hz + 0.05))
    m.bone("wing_l", "body", (0.14 * sz / 0.3, 0, hz + 0.06), (0.2 * sz / 0.3, -0.12, hz + 0.02))
    m.bone("wing_r", "body", (-0.14 * sz / 0.3, 0, hz + 0.06), (-0.2 * sz / 0.3, -0.12, hz + 0.02))
    lh = hz - 0.06
    for n, x in (("leg_l", 0.06), ("leg_r", -0.06)):
        m.bone(n, "body", (x, 0, hz - 0.06), (x, 0.0, 0.01))
        m.add(n, cyl((x, 0, lh / 2), (0.025, 0.025, lh), beak))
        m.add(n, cube((x, 0.04, 0.012), (0.07 if duck else 0.05, 0.12, 0.025), beak))
    s = sz / 0.3
    m.add("body", sphere((0, 0, hz), (0.3 * s, 0.42 * s, 0.34 * s), body, rot=(-12, 0, 0)))
    m.add("tail", cone((0, -0.25 * s, hz + 0.1), (0.2 * s, 0.1, 0.25 * s), body, rot=(-60 if not duck else -20, 0, 0)))
    hz2 = hz + neckh
    m.add("head", sphere((0, 0.15, hz2), (0.15 * s, 0.16 * s, 0.16 * s), body))
    if neckh > 0.2:
        m.add("body", cyl((0, 0.13, hz + neckh * 0.45), (0.1 * s, 0.1 * s, neckh), body, rot=(-5, 0, 0)))
    if duck:
        m.add("head", cube((0, 0.27, hz2 - 0.02), (0.1, 0.14, 0.04), beak, bevel=0.01))
    else:
        m.add("head", cone((0, 0.26, hz2 - 0.01), (0.06, 0.06, 0.1), beak, rot=(-90, 0, 0)))
        m.add("head", cube((0, 0.15, hz2 + 0.11), (0.025, 0.1, 0.06), comb, bevel=0.01))
        m.add("head", sphere((0, 0.24, hz2 - 0.1), (0.04, 0.03, 0.07), comb))
    for sd in (1, -1):
        m.add("head", sphere((sd * 0.07, 0.24, hz2 + 0.03), (0.035, 0.035, 0.035), mat("eye", PAL["black"], 0.2)))
        m.add("wing_l" if sd > 0 else "wing_r", sphere((sd * 0.17 * s, -0.02, hz + 0.02), (0.06 * s, 0.3 * s, 0.2 * s), body, rot=(8, 0, sd * -10)))
    m.build()

    def idle(t):
        return {"body": (sin(t) * 1.5, 0, 0, 0, 0, sin(t) * 0.004), "head": (sin(t * 2) * 12 - 4, 0, sin(t * 2, .3) * 6), "tail": (sin(t) * 4, 0, 0)}

    def walk(t):
        a = sin(t) * 30
        return {"leg_l": (a, 0, 0), "leg_r": (-a, 0, 0), "body": (0, 0, sin(t) * 3, 0, 0, abs(sin(t)) * 0.02), "head": (sin(t * 2) * 6, 0, 0)}

    def run(t):
        a = sin(t) * 45
        return {"leg_l": (a, 0, 0), "leg_r": (-a, 0, 0), "body": (6, 0, 0, 0, 0, abs(sin(t)) * 0.05), "wing_l": (0, 0, -35 + sin(t * 2) * 15), "wing_r": (0, 0, 35 - sin(t * 2) * 15)}
    m.clip("idle", 48, idle, samples=12); m.clip("walk", 24, walk, samples=12); m.clip("run", 12, run, samples=8)
    m.clip("hurt", 14, lambda t: {"body": (-20 * math.sin(t * math.pi), 0, 0), "wing_l": (0, 0, -40 * math.sin(t * math.pi)), "wing_r": (0, 0, 40 * math.sin(t * math.pi))}, loop=False, samples=6)
    return m


def chicken():
    m = bird("animal_chicken", mat("feather", PAL["white"], 0.8), mat("beak", PAL["orange"], 0.5), mat("comb", PAL["red"], 0.5), 0.3, 0.17)
    return m


def duck():
    return bird("animal_duck", mat("duckfeather", (0.95, 0.88, 0.35), 0.8), mat("duckbill", PAL["orange"], 0.5), None, 0.3, 0.14, duck=True)


ALL = dict(cow=cow, pig=pig, goat=goat, sheep=sheep, dog=dog, chicken=chicken, duck=duck)
for k, fn in ALL.items():
    if ONLY and k not in ONLY and ("animal_" + k) not in ONLY:
        continue
    finish(fn())
