"""Biped rig + standard clip set shared by enemies, NPCs and bosses.
Bone axes (see lib_common): +rx swings a down-pointing limb FORWARD; +rx on up-pointing bones (spine/head) leans BACK.
+X is the character's right side ('_r'); character faces +Y.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lib_common import *


class Biped(Model):
    def __init__(self, name, H=1.5, sw=0.2, hw=0.1, hip=0.5, tail=True):
        super().__init__(name)
        self.H, self.sw, self.hw, self.hipz = H, sw, hw, hip * H
        h = self
        hz = hip * H
        ch = hz + 0.12 * H
        sh = 0.74 * H
        h.bone("root", None, (0, 0, 0), (0, 0.1, 0))
        h.bone("hips", "root", (0, 0, hz), (0, 0, ch))
        h.bone("chest", "hips", (0, 0, ch), (0, 0, 0.78 * H))
        h.bone("head", "chest", (0, 0, 0.78 * H), (0, 0, H))
        for s, n in ((1, "r"), (-1, "l")):
            h.bone("arm_" + n, "chest", (s * sw, 0, sh), (s * sw, 0, 0.52 * H))
            h.bone("fore_" + n, "arm_" + n, (s * sw, 0, 0.52 * H), (s * sw, 0, 0.32 * H))
            h.bone("leg_" + n, "hips", (s * hw, 0, hz), (s * hw, 0, 0.27 * H))
            h.bone("shin_" + n, "leg_" + n, (s * hw, 0, 0.27 * H), (s * hw, 0, 0.02))
        if tail:
            h.bone("tail", "hips", (0, -0.04 * H, hz), (0, -0.3 * H, hz - 0.03 * H))

    # shape helpers ---------------------------------------------------------
    def limb(self, bone, x, z0, z1, r0, r1, material, y=0.0, verts=10):
        """Tapered cylinder from (z0, radius r0) to (z1, radius r1)."""
        big = max(r0, r1)
        lo, hi = (r1, r0) if z1 < z0 else (r0, r1)
        o = cyl((x, y, (z0 + z1) / 2), (big * 2, big * 2, abs(z1 - z0)), material, r1=lo / big, r2=hi / big, verts=verts)
        return self.add(bone, o)

    def arms(self, upper_mat, fore_mat, hand_mat, r=0.045, hand=0.06):
        H = self.H
        for s, n in ((1, "r"), (-1, "l")):
            x = s * self.sw
            self.add("arm_" + n, sphere((x, 0, 0.74 * H), (r * 2.6, r * 2.6, r * 2.6), upper_mat))
            self.limb("arm_" + n, x, 0.74 * H, 0.52 * H, r, r * 0.85, upper_mat)
            self.limb("fore_" + n, x, 0.52 * H, 0.34 * H, r * 0.85, r * 0.75, fore_mat)
            self.add("fore_" + n, sphere((x, 0.0, 0.31 * H), (hand * 2, hand * 2, hand * 2), hand_mat))

    def legs(self, mat_up, mat_low, foot_mat, r=0.06, foot=(0.12, 0.2, 0.07)):
        H = self.H
        for s, n in ((1, "r"), (-1, "l")):
            x = s * self.hw
            self.limb("leg_" + n, x, self.hipz, 0.27 * H, r, r * 0.85, mat_up)
            self.limb("shin_" + n, x, 0.27 * H, 0.06, r * 0.85, r * 0.7, mat_low)
            self.add("shin_" + n, sphere((x, 0.05, 0.035), foot, foot_mat))


def std_anims(m, walk_swing=30, arm_swing=25, attack="swing", lean=0, tail_w=10, crouch=0.0, down_roll=1):
    """Adds idle/walk/run/attack/cast/hurt/down/victory/defend."""
    def tl(t):
        return {"tail": (sin(t * 2, .2) * 4, 0, sin(t, .1) * tail_w)}

    def idle(t):
        d = {"chest": (sin(t) * 2.0 + lean, 0, 0, 0, 0, 0), "hips": (0, 0, 0, 0, 0, sin(t, .1) * 0.008),
             "head": (sin(t, .3) * 3, sin(t, .6) * 4, 0), "arm_r": (sin(t, .2) * 4, 0, -3 + sin(t) * 2),
             "arm_l": (-sin(t, .2) * 4, 0, 3 - sin(t) * 2), "fore_r": (-10, 0, 0), "fore_l": (-10, 0, 0)}
        d.update(tl(t)); return d

    def walk(sw, asw, bob):
        def f(t):
            a = sin(t)
            d = {"leg_r": (a * sw, 0, 0), "leg_l": (-a * sw, 0, 0),
                 "shin_r": (max(0, -sin(t + 0.25)) * sw * 1.3, 0, 0), "shin_l": (max(0, sin(t + 0.25)) * sw * 1.3, 0, 0),
                 "arm_r": (-a * asw, 0, -3), "arm_l": (a * asw, 0, 3), "fore_r": (-15 - max(0, -a) * 20, 0, 0), "fore_l": (-15 - max(0, a) * 20, 0, 0),
                 "hips": (0, sin(t) * 4, 0, 0, 0, abs(sin(t)) * bob - bob * 0.5 - crouch * 0.05),
                 "chest": (lean + (6 if bob > 0.05 else 0), -sin(t) * 5, 0), "head": (0, sin(t) * 3, 0)}
            d.update(tl(t * 2)); return d
        return f

    def attack(t):
        # 0..0.3 wind up, 0.3..0.5 strike, then recover
        if t < 0.3:
            k = t / 0.3; w, s = k, 0
        elif t < 0.5:
            w, s = 1 - (t - 0.3) / 0.2, (t - 0.3) / 0.2
        else:
            w, s = 0, 1 - (t - 0.5) / 0.5
        if attack == "swing":
            return {"arm_r": (-70 * w + 130 * s - 10, 0, -10 * w), "fore_r": (-40 * w - 30 * s, 0, 0), "chest": (6 * w - 14 * s, 0, -20 * w + 25 * s), "arm_l": (-20 * w + 30 * s, 0, 0),
                    "hips": (0, 0, 0, 0, 0.4 * s, 0), "root": (0, 0, 0, 0, 0.35 * s, 0), "leg_r": (-20 * s, 0, 0), "leg_l": (25 * s, 0, 0)}
        if attack == "stab":
            return {"arm_r": (-40 * w + 100 * s, 0, 0), "fore_r": (-80 * w - 5 * s, 0, 0), "chest": (10 * w - 12 * s, 0, 0), "root": (0, 0, 0, 0, 0.45 * s, 0), "leg_r": (-25 * s, 0, 0), "leg_l": (25 * s, 0, 0)}
        # bite / lunge: lean whole body
        return {"chest": (12 * w - 28 * s, 0, 0), "head": (-10 * w - 25 * s, 0, 0), "arm_r": (40 * s, 0, -20 * s), "arm_l": (40 * s, 0, 20 * s),
                "root": (0, 0, 0, 0, 0.5 * s, 0.05 * s), "leg_r": (-25 * s, 0, 0), "leg_l": (25 * s, 0, 0)}

    def cast(t):
        up = math.sin(min(t * 1.6, 1) * math.pi * 0.5)
        pul = math.sin(t * math.pi * 3) * 3
        return {"arm_r": (150 * up, 0, -15 * up + pul), "arm_l": (150 * up, 0, 15 * up - pul), "fore_r": (-15, 0, 0), "fore_l": (-15, 0, 0),
                "chest": (-8 * up, 0, 0), "head": (-12 * up, 0, 0), "hips": (0, 0, 0, 0, 0, 0.02 * up)}

    def hurt(t):
        k = math.sin(t * math.pi)
        return {"chest": (28 * k, 0, 8 * k), "head": (20 * k, 0, 0), "root": (0, 0, 0, 0, -0.2 * k, 0), "arm_r": (30 * k, 0, -30 * k), "arm_l": (30 * k, 0, 30 * k), "hips": (0, 0, 0, 0, 0, -0.06 * k)}

    def down(t):
        k = min(1.0, t * 1.6)
        k = k * k * (3 - 2 * k)
        return {"root": (-88 * k * down_roll, 0, 0, 0, -0.1 * k, 0.07 * k), "arm_r": (-20 * k, 0, -40 * k), "arm_l": (-20 * k, 0, 40 * k),
                "leg_r": (10 * k, 0, -8 * k), "leg_l": (-5 * k, 0, 10 * k), "head": (15 * k, 8 * k, 0)}

    def victory(t):
        a = abs(sin(t))
        return {"arm_r": (165 + sin(t * 2) * 8, 0, -12), "arm_l": (20, 0, 10), "fore_r": (-10, 0, 0), "hips": (0, 0, 0, 0, 0, a * 0.12), "root": (0, 0, 0, 0, 0, a * 0.1),
                "chest": (-6, sin(t) * 6, 0), "head": (-10, sin(t) * 8, 0), "leg_r": (-a * 12, 0, 0), "leg_l": (-a * 12, 0, 0), "shin_r": (a * 25, 0, 0), "shin_l": (a * 25, 0, 0)}

    def defend(t):
        b = sin(t) * 1.5
        return {"arm_r": (70, 0, 40), "arm_l": (70, 0, -40), "fore_r": (-80, 0, 0), "fore_l": (-80, 0, 0), "chest": (-14 + b, 0, 0), "head": (-12, 0, 0),
                "hips": (0, 0, 0, 0, -0.04, -0.14), "leg_r": (35, 0, 0), "leg_l": (-15, 0, 0), "shin_r": (-35, 0, 0), "shin_l": (30, 0, 0)}

    m.clip("idle", 48, idle, samples=12)
    m.clip("walk", 24, walk(walk_swing, arm_swing, 0.03), samples=12)
    m.clip("run", 16, walk(walk_swing * 1.5, arm_swing * 1.7, 0.08), samples=8)
    m.clip("attack", 20, attack, loop=False, samples=10)
    m.clip("cast", 30, cast, loop=False, samples=10)
    m.clip("hurt", 14, hurt, loop=False, samples=7)
    m.clip("down", 30, down, loop=False, samples=10)
    m.clip("victory", 30, victory, samples=10)
    m.clip("defend", 36, defend, samples=8)


def eyes(m, bone, x, y, z, r=0.04, color="black", shine=True, spread=None):
    for s in (1, -1):
        m.add(bone, sphere((s * x, y, z), (r * 2, r * 1.6, r * 2), mat("eye_" + color, PAL.get(color, color), 0.2)))
        if shine:
            m.add(bone, sphere((s * x + 0.01, y + r * 0.7, z + r * 0.5), (r * 0.7, r * 0.5, r * 0.7), mat("eyeshine", PAL["white"], 0.1)))


def rat_head(m, bone, y, z, size, fur, ear_in=None, eye_col="rot_lt", snout=1.0, buck=False):
    """Rat head centred at (0,y,z); size ~ skull diameter."""
    ear_in = ear_in or mat("ear_in", PAL["pink"], 0.6)
    m.add(bone, sphere((0, y, z), (size, size * 1.05, size * 0.95), fur))
    m.add(bone, cone((0, y + size * 0.75 * snout, z - size * 0.12), (size * 0.55, size * 0.7 * snout, size * 0.5), fur, rot=(-90, 0, 0)))
    m.add(bone, sphere((0, y + size * 1.1 * snout, z - size * 0.1), (size * 0.2, size * 0.18, size * 0.18), mat("nose", PAL["pink"], 0.4)))
    if buck:
        for s in (1, -1):
            m.add(bone, cube((s * size * 0.06, y + size * 0.85 * snout, z - size * 0.36), (size * 0.09, size * 0.04, size * 0.2), mat("tooth", PAL["cream"], 0.4), bevel=0.005))
    for s in (1, -1):
        m.add(bone, cyl((s * size * 0.48, y - size * 0.15, z + size * 0.4), (size * 0.62, size * 0.1 * 2.2, size * 0.62), fur, rot=(0, s * 70, 0), verts=16))
        m.add(bone, cyl((s * size * 0.5, y - size * 0.1, z + size * 0.4), (size * 0.44, size * 0.1 * 1.8, size * 0.44), ear_in, rot=(0, s * 70, 0), verts=16))
        m.add(bone, sphere((s * size * 0.26, y + size * 0.42, z + size * 0.14), (size * 0.17, size * 0.12, size * 0.17), mat("eye_" + eye_col, PAL[eye_col], 0.3, emit=eye_col, emit_strength=1.5)))


def rat_tail(m, bone, H, hipz, material=None):
    material = material or mat("tail_skin", PAL["pink"], 0.6)
    pts = [(0, -0.06 * H, hipz), (0, -0.16 * H, hipz - 0.02 * H), (0, -0.26 * H, hipz - 0.04 * H), (0, -0.34 * H, hipz - 0.03 * H)]
    for i, p in enumerate(pts):
        m.add(bone, sphere(p, (0.045 * H * (1 - i * 0.18),) * 3, material))
