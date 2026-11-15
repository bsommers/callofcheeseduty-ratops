"""Enemies: blender -b -P tools/blender/creatures_enemies.py [-- name ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from creatures_common import *

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def rat_body(m, fur, belly, cloth, H):
    hz = m.hipz
    m.add("hips", sphere((0, 0, hz + 0.02), (0.34 * H * 0.8, 0.28 * H * 0.8, 0.3 * H * 0.7), cloth))
    m.add("chest", sphere((0, 0.01, 0.66 * H), (m.sw * 2.3, m.sw * 1.7, 0.34 * H), fur))
    m.add("chest", sphere((0, 0.05, 0.64 * H), (m.sw * 1.7, m.sw * 1.2, 0.26 * H), belly))


def rat_grunt():
    H = 1.2
    m = Biped("enemy_rat_grunt", H, sw=0.22, hw=0.1, hip=0.45)
    fur = mat("fur", PAL["rat"], 0.9)
    skin = mat("skin", PAL["pink"], 0.6)
    leather = mat("leather", PAL["brown"], 0.7)
    cloth = mat("cloth_rot", (0.25, 0.3, 0.28), 0.9)
    metal = mat("metal", PAL["metal"], 0.35, 0.9)
    rat_body(m, fur, mat("belly", (0.7, 0.62, 0.55), 0.9), cloth, H)
    m.arms(fur, fur, skin, r=0.05)
    m.legs(cloth, fur, leather, r=0.065)
    m.add("chest", cube((0, 0.0, 0.68 * H), (0.55 * H * 0.5, 0.3 * H * 0.5, 0.26 * H), leather, bevel=0.02))   # vest
    rat_head(m, "head", 0.07, 0.88 * H, 0.3, fur, snout=1.0, buck=True)
    # pot-helmet
    m.add("head", sphere((0, 0.04, 0.88 * H + 0.08), (0.36, 0.36, 0.24), metal))
    m.add("head", cyl((0, 0.04, 0.88 * H + 0.03), (0.4, 0.4, 0.03), metal))
    rat_tail(m, "tail", H, m.hipz)
    # club in right hand
    m.add("fore_r", cyl((m.sw, 0.1, 0.33 * H + 0.1), (0.07, 0.07, 0.5), mat("wood", PAL["wood"], 0.8), rot=(-20, 0, 0)))
    m.add("fore_r", sphere((m.sw, 0.2, 0.33 * H + 0.35), (0.14, 0.14, 0.2), mat("wood"), rot=(-20, 0, 0)))
    for i in range(3):
        m.add("fore_r", cone((m.sw + (i - 1) * 0.06, 0.25, 0.33 * H + 0.38), (0.03, 0.03, 0.07), metal, rot=(-60, 0, (i - 1) * 40)))
    m.build()
    std_anims(m, walk_swing=28, arm_swing=22, attack="swing", lean=14, tail_w=14)
    return m


def rat_sapper():
    H = 1.1
    m = Biped("enemy_rat_sapper", H, sw=0.2, hw=0.1, hip=0.45)
    fur = mat("fur", (0.5, 0.42, 0.36), 0.9)
    skin = mat("skin", PAL["pink"], 0.6)
    leather = mat("leather", (0.3, 0.2, 0.12), 0.7)
    cloth = mat("cloth_rot", (0.55, 0.35, 0.12), 0.9)
    metal = mat("metal", PAL["metal"], 0.35, 0.9)
    rat_body(m, fur, mat("belly", (0.72, 0.64, 0.55), 0.9), cloth, H)
    m.arms(cloth, fur, skin, r=0.05)
    m.legs(cloth, fur, leather, r=0.06)
    rat_head(m, "head", 0.07, 0.88 * H, 0.28, fur, snout=0.9)
    # goggles
    for s in (1, -1):
        m.add("head", cyl((s * 0.08, 0.2, 0.88 * H + 0.04), (0.11, 0.11, 0.05), metal, rot=(90, 0, 0)))
        m.add("head", cyl((s * 0.08, 0.225, 0.88 * H + 0.04), (0.08, 0.08, 0.02), mat("glass", PAL["rot_lt"], 0.1, emit="rot_lt", emit_strength=0.8), rot=(90, 0, 0)))
    m.add("head", cyl((0, 0.05, 0.88 * H + 0.06), (0.3, 0.3, 0.05), leather, rot=(0, 0, 0)))
    rat_tail(m, "tail", H, m.hipz)
    # bomb backpack on chest bone
    bm = mat("bomb", PAL["black"], 0.4, 0.5)
    m.add("chest", cube((0, -0.2, 0.68 * H), (0.34, 0.14, 0.34), leather, bevel=0.02))
    for i, (x, z) in enumerate(((-0.08, 0.76), (0.1, 0.72), (0.0, 0.6))):
        m.add("chest", sphere((x, -0.3, z * H), (0.17, 0.17, 0.17), bm))
        m.add("chest", sphere((x, -0.3, z * H + 0.1), (0.04, 0.04, 0.04), mat("fuse", PAL["orange"], 0.3, emit="orange", emit_strength=4)))
    # lit bomb held in right hand
    m.add("fore_r", sphere((m.sw, 0.12, 0.33 * H + 0.1), (0.22, 0.22, 0.22), bm))
    m.add("fore_r", cyl((m.sw, 0.12, 0.33 * H + 0.25), (0.02, 0.02, 0.07), mat("fusecord", PAL["wood_lt"], 0.8)))
    m.add("fore_r", sphere((m.sw, 0.12, 0.33 * H + 0.3), (0.06, 0.06, 0.06), mat("fuse")))
    m.build()
    std_anims(m, walk_swing=30, arm_swing=22, attack="stab", lean=10, tail_w=14)
    return m


def crow():
    m = Model("enemy_crow")
    z = 1.1
    black = mat("feather", (0.07, 0.08, 0.1), 0.35)
    sheen = mat("feather_rot", PAL["rot_dk"], 0.3, emit="rot", emit_strength=0.25)
    beak = mat("beak", (0.3, 0.28, 0.25), 0.4)
    m.bone("root", None, (0, 0, 0), (0, 0.1, 0))
    m.bone("body", "root", (0, -0.2, z), (0, 0.2, z))
    m.bone("head", "body", (0, 0.2, z + 0.1), (0, 0.4, z + 0.12))
    m.bone("tail", "body", (0, -0.25, z), (0, -0.55, z - 0.05))
    for s, n in ((1, "r"), (-1, "l")):
        m.bone("wing_" + n, "body", (s * 0.12, 0, z + 0.07), (s * 0.55, 0, z + 0.07))
        m.bone("wingtip_" + n, "wing_" + n, (s * 0.55, 0, z + 0.07), (s * 1.0, -0.05, z + 0.07))
        m.bone("leg_" + n, "body", (s * 0.07, 0.05, z - 0.1), (s * 0.07, 0.1, z - 0.38))
        m.add("leg_" + n, cyl((s * 0.07, 0.08, z - 0.25), (0.03, 0.03, 0.28), beak))
        for k in (-1, 0, 1):
            m.add("leg_" + n, cone((s * 0.07 + k * 0.03, 0.15, z - 0.38), (0.02, 0.02, 0.12), beak, rot=(-90, 0, k * 20)))
        m.add("wing_" + n, sphere((s * 0.33, -0.02, z + 0.07), (0.55, 0.32, 0.06), black))
        m.add("wingtip_" + n, sphere((s * 0.78, -0.06, z + 0.07), (0.5, 0.24, 0.04), sheen))
        for k in range(4):
            m.add("wingtip_" + n, cone((s * (0.92 + k * 0.01), -0.12 - k * 0.04, z + 0.07), (0.05, 0.05, 0.28), black, rot=(0, 90 * s, 0)))
    m.add("body", sphere((0, 0, z), (0.38, 0.56, 0.38), black, rot=(10, 0, 0)))
    m.add("body", sphere((0, 0.05, z - 0.04), (0.28, 0.4, 0.26), sheen))
    m.add("head", sphere((0, 0.3, z + 0.12), (0.26, 0.26, 0.26), black))
    m.add("head", cone((0, 0.5, z + 0.1), (0.12, 0.3, 0.1), beak, rot=(-90, 0, 0)))
    for s in (1, -1):
        m.add("head", sphere((s * 0.1, 0.38, z + 0.17), (0.06, 0.05, 0.06), mat("eye_glow", PAL["rot_lt"], 0.2, emit="rot_lt", emit_strength=3)))
    m.add("tail", cone((0, -0.42, z - 0.03), (0.22, 0.4, 0.04), black, rot=(-90, 0, 0)))
    m.build()

    def flap(rate, amp, base=0):
        def f(t):
            a = sin(t * rate) * amp
            return {"wing_r": (0, 0, -(a + base)), "wing_l": (0, 0, a + base), "wingtip_r": (0, 0, -a * 0.8), "wingtip_l": (0, 0, a * 0.8),
                    "body": (sin(t * rate, .25) * 4, 0, 0, 0, 0, sin(t * rate, .25) * 0.04), "head": (sin(t) * 5, 0, 0), "tail": (sin(t * rate) * 8, 0, 0),
                    "leg_r": (-25, 0, 0), "leg_l": (-25, 0, 0)}
        return f
    m.clip("idle", 36, flap(2, 28), samples=12)
    m.clip("walk", 20, flap(2, 28, 4), samples=10)
    m.clip("run", 12, flap(2, 38), samples=8)

    def attack(t):
        w = min(t / 0.35, 1); s = max(0, min((t - 0.35) / 0.2, 1)) * (1 - max(0, (t - 0.6) / 0.4))
        return {"body": (30 * w * (1 - s) - 40 * s, 0, 0, 0, 0.9 * s - 0.25 * w, -0.4 * s), "wing_r": (0, 0, -60 * w + 20 * s), "wing_l": (0, 0, 60 * w - 20 * s),
                "head": (-20 * s, 0, 0), "root": (0, 0, 0, 0, 0.0, 0), "leg_r": (-60 * s, 0, 0), "leg_l": (-60 * s, 0, 0)}
    m.clip("attack", 20, attack, loop=False, samples=10)
    m.clip("cast", 30, lambda t: {"wing_r": (0, 0, -50), "wing_l": (0, 0, 50), "body": (-25 * min(t * 2, 1), 0, 0, 0, 0, 0.15), "head": (-20, sin(t * 3) * 15, 0)}, loop=False, samples=8)
    m.clip("hurt", 14, lambda t: {"body": (-35 * math.sin(t * math.pi), 0, 0, 0, -0.3 * math.sin(t * math.pi), 0), "wing_r": (0, 0, 60 * math.sin(t * math.pi)), "wing_l": (0, 0, -60 * math.sin(t * math.pi))}, loop=False, samples=7)

    def down(t):
        k = min(1, t * 1.5); k = k * k
        return {"root": (0, 0, 180 * k * 0.5, 0, 0, -z * 0.8 * k), "body": (0, 0, 70 * k), "wing_r": (0, 0, 50 * k), "wing_l": (0, 0, -50 * k), "head": (30 * k, 0, 0)}
    m.clip("down", 30, down, loop=False, samples=10)
    m.clip("defend", 30, lambda t: {"wing_r": (0, 0, 70 + sin(t) * 3), "wing_l": (0, 0, -70 - sin(t) * 3), "wingtip_r": (0, 0, 40), "wingtip_l": (0, 0, -40), "head": (25, 0, 0)}, samples=6)
    m.clip("victory", 24, flap(3, 35, 6), samples=12)
    return m


def mold_blob():
    m = Model("enemy_mold_blob")
    rot = mat("rot_slime", PAL["rot"], 0.25, emit="rot_dk", emit_strength=0.6)
    lite = mat("rot_spore", PAL["rot_lt"], 0.3, emit="rot_lt", emit_strength=1.2)
    dark = mat("rot_deep", PAL["rot_dk"], 0.4)
    m.bone("root", None, (0, 0, 0), (0, 0.1, 0))
    m.bone("body", "root", (0, 0, 0.05), (0, 0, 0.6))
    m.bone("eyes", "body", (0, 0.3, 0.5), (0, 0.4, 0.5))
    for i in range(3):
        m.bone("bump_%d" % i, "body", (0, 0, 0.5), (0, 0, 0.7))
    m.add("body", sphere((0, 0, 0.36), (0.85, 0.85, 0.72), rot, seg=24))
    m.add("body", sphere((0, 0, 0.06), (1.0, 1.0, 0.18), dark, seg=20))
    import random
    random.seed(11)
    for i in range(3):
        a = i * 2.1
        m.add("bump_%d" % i, sphere((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.64 + i * 0.03), (0.28, 0.28, 0.26), lite, seg=12))
    for i in range(9):
        a = random.uniform(0, 6.28); r = random.uniform(0.25, 0.36); z = random.uniform(0.15, 0.55)
        m.add("body", sphere((math.cos(a) * r * 1.2, math.sin(a) * r * 1.2, z), (0.14, 0.14, 0.12), lite, seg=8))
    for s in (1, -1):
        m.add("eyes", sphere((s * 0.17, 0.33, 0.5), (0.22, 0.14, 0.26), mat("eyewhite", (0.95, 1, 0.9), 0.2, emit=(0.8, 1, 0.7), emit_strength=0.8)))
        m.add("eyes", sphere((s * 0.17, 0.4, 0.5), (0.09, 0.06, 0.12), mat("pupil", PAL["black"], 0.2)))
    m.add("eyes", cube((0, 0.38, 0.28), (0.3, 0.05, 0.07), mat("mouth", PAL["black"], 0.4), bevel=0.02))
    m.build()

    def S(sx, sy, sz, dz=0):
        return (0, 0, 0, 0, 0, dz, sx, sy, sz)
    idle = lambda t: {"body": S(1 + sin(t) * 0.04, 1 + sin(t) * 0.04, 1 - sin(t) * 0.06), "bump_0": (sin(t) * 6, sin(t, .3) * 6, 0), "bump_1": (sin(t, .3) * 6, 0, sin(t) * 6), "eyes": (sin(t, .4) * 3, 0, 0)}

    def hop(h, a):
        def f(t):
            k = abs(sin(t * 0.5)); sq = 1 - k
            return {"body": S(1 + (sq * 0.15 - k * 0.08), 1 + (sq * 0.15 - k * 0.08), 1 - sq * 0.25 + k * 0.15, k * h), "eyes": (0, 0, 0, 0, 0, 0), "root": (-a * k * 0.5, 0, 0)}
        return f
    m.clip("idle", 48, idle, samples=12)
    m.clip("walk", 28, hop(0.18, 14), samples=14)
    m.clip("run", 16, hop(0.28, 20), samples=8)

    def attack(t):
        w = min(t / 0.35, 1); s = max(0, min((t - 0.35) / 0.15, 1)) * (1 - max(0, (t - 0.55) / 0.45))
        return {"body": S(1 + 0.2 * w - 0.2 * s, 1 + 0.2 * w - 0.2 * s, 1 - 0.3 * w + 0.3 * s, 0.1 * s), "root": (0, 0, 0, 0, 0.8 * s, 0)}
    m.clip("attack", 20, attack, loop=False, samples=10)
    m.clip("cast", 30, lambda t: {"body": S(1 - 0.15 * math.sin(t * 6), 1 - 0.15 * math.sin(t * 6), 1 + 0.25 * math.sin(min(t * 1.4, 1) * math.pi * 0.5), 0.05)}, loop=False, samples=12)
    m.clip("hurt", 14, lambda t: {"body": S(1 + 0.3 * math.sin(t * math.pi), 1 + 0.3 * math.sin(t * math.pi), 1 - 0.4 * math.sin(t * math.pi)), "root": (0, 0, 0, 0, -0.2 * math.sin(t * math.pi), 0)}, loop=False, samples=7)
    m.clip("down", 30, lambda t: {"body": S(1 + 0.6 * min(t * 1.5, 1), 1 + 0.6 * min(t * 1.5, 1), 1 - 0.85 * min(t * 1.5, 1))}, loop=False, samples=10)
    m.clip("victory", 24, hop(0.4, 0), samples=12)
    m.clip("defend", 24, lambda t: {"body": S(1.15 + sin(t) * 0.02, 1.15, 0.7)}, samples=6)
    return m


def weasel():
    H = 1.35
    m = Biped("enemy_weasel", H, sw=0.16, hw=0.09, hip=0.42)
    fur = mat("fur", (0.62, 0.4, 0.2), 0.85)
    belly = mat("belly", PAL["cream"], 0.85)
    cloth = mat("cloth_rot", (0.2, 0.2, 0.26), 0.9)
    leather = mat("leather", PAL["black"], 0.6)
    metal = mat("metal", PAL["metal"], 0.25, 0.95)
    skin = mat("skin", (0.8, 0.55, 0.45), 0.6)
    hz = m.hipz
    m.add("hips", sphere((0, 0, hz + 0.05), (0.3, 0.26, 0.3), cloth))
    m.add("chest", sphere((0, 0, 0.62 * H), (0.34, 0.26, 0.5), fur, rot=(8, 0, 0)))
    m.add("chest", sphere((0, 0.05, 0.62 * H), (0.22, 0.18, 0.42), belly, rot=(8, 0, 0)))
    m.arms(fur, fur, skin, r=0.042)
    m.legs(cloth, fur, leather, r=0.055)
    # long neck + weasel head
    m.add("head", cyl((0, 0.02, 0.8 * H), (0.13, 0.13, 0.12), fur))
    m.add("head", sphere((0, 0.09, 0.92 * H), (0.22, 0.3, 0.2), fur))
    m.add("head", cone((0, 0.3, 0.9 * H), (0.13, 0.22, 0.12), belly, rot=(-90, 0, 0)))
    m.add("head", sphere((0, 0.4, 0.9 * H), (0.05, 0.05, 0.05), mat("nose", PAL["black"], 0.3)))
    for s in (1, -1):
        m.add("head", sphere((s * 0.1, 0.0, 1.0 * H), (0.08, 0.04, 0.09), fur))
        m.add("head", sphere((s * 0.07, 0.24, 0.94 * H), (0.04, 0.03, 0.045), mat("eye_glow", PAL["rot_lt"], 0.2, emit="rot_lt", emit_strength=2)))
    # bandana
    m.add("head", cyl((0, 0.02, 0.8 * H), (0.18, 0.18, 0.05), mat("cloth_red", PAL["red"], 0.8)))
    # long bushy tail
    for i, (y, z, r) in enumerate(((-0.1, hz, 0.1), (-0.25, hz - 0.03, 0.12), (-0.42, hz - 0.06, 0.12), (-0.58, hz - 0.08, 0.08))):
        m.add("tail", sphere((0, y, z), (r * 2, r * 2.4, r * 2), fur))
    # dagger
    m.add("fore_r", cube((m.sw, 0.15, 0.33 * H + 0.05), (0.02, 0.05, 0.3), metal, rot=(-70, 0, 0)))
    m.add("fore_r", cube((m.sw, 0.06, 0.33 * H + 0.03), (0.02, 0.12, 0.03), leather))
    m.build()
    std_anims(m, walk_swing=34, arm_swing=26, attack="stab", lean=16, tail_w=20)
    return m


def wheel_golem():
    H = 2.0
    m = Biped("enemy_wheel_golem", H, sw=0.62, hw=0.28, hip=0.4, tail=False)
    rind = mat("rind", (0.82, 0.55, 0.15), 0.55)
    cheese = mat("cheese", PAL["cheddar"], 0.4)
    rot = mat("rot_slime", PAL["rot"], 0.3, emit="rot_dk", emit_strength=0.7)
    stone = mat("stone", PAL["stone"], 0.8)
    hz = m.hipz
    # big wheel on its side facing front (axis Y)
    m.add("chest", cyl((0, 0, 0.98 * H * 0.7 + 0.12), (1.3, 1.3, 0.55), rind, rot=(90, 0, 0), verts=32))
    m.add("chest", cyl((0, 0.285, 0.98 * H * 0.7 + 0.12), (1.12, 1.12, 0.03), cheese, rot=(90, 0, 0), verts=32))
    for x, z, r in ((0.35, 0.35, 0.28), (-0.4, -0.2, 0.22), (0.1, -0.35, 0.18), (-0.15, 0.4, 0.15)):
        m.add("chest", sphere((x, 0.3, 0.98 * H * 0.7 + 0.12 + z), (r * 1.2, 0.08, r * 1.2), rot, seg=10))
    m.add("chest", sphere((0.6, 0.0, 1.35 + 0.12), (0.4, 0.4, 0.3), rot, seg=10))
    m.add("hips", sphere((0, 0, hz + 0.05), (0.55, 0.45, 0.35), stone))
    for s in (1, -1):  # glowing eyes in the wheel face, mouth wedge
        m.add("head", sphere((s * 0.22, 0.32, 1.3), (0.2, 0.08, 0.14), mat("eye_glow", PAL["rot_lt"], 0.2, emit="rot_lt", emit_strength=3)))
        m.add("head", cube((s * 0.22, 0.34, 1.38), (0.28, 0.05, 0.06), mat("brow", PAL["rot_dk"], 0.5), rot=(0, 0, s * -18)))
    m.add("head", cube((0, 0.33, 1.02), (0.5, 0.04, 0.12), mat("mouth", PAL["black"], 0.5)))
    for k in range(6):
        m.add("head", cone((-0.2 + k * 0.08, 0.34, 1.06 - (k % 2) * 0.1), (0.06, 0.03, 0.09), mat("tooth", PAL["cream"], 0.4), rot=(0, 0, 180 if k % 2 else 0)))
    m.arms(rind, stone, rot, r=0.11, hand=0.16)
    m.legs(stone, stone, mat("foot", PAL["stone"], 0.9), r=0.15, foot=(0.3, 0.45, 0.16))
    m.build()
    std_anims(m, walk_swing=18, arm_swing=14, attack="swing", lean=0, down_roll=-0.0)
    return m


ALL = dict(rat_grunt=rat_grunt, rat_sapper=rat_sapper, crow=crow, mold_blob=mold_blob, weasel=weasel, wheel_golem=wheel_golem)
for k, fn in ALL.items():
    if ONLY and k not in ONLY:
        continue
    finish(fn())
