"""Bosses: blender -b -P tools/blender/creatures_bosses.py [-- name ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from creatures_common import *

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def strut(a, b, d1, d2, material, verts=10):
    """Tapered cylinder from point a (diameter d1) to point b (diameter d2)."""
    a, b = Vector(a), Vector(b)
    v = b - a
    big = max(d1, d2)
    o = cyl(tuple((a + b) / 2), (big, big, v.length), material, r1=d1 / big, r2=d2 / big, verts=verts)
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(v).to_euler()
    return o


def tris(tri_list, material, name="mem"):
    """Free-form triangle mesh from [(p0,p1,p2), ...] (double-sided via material default)."""
    verts, faces = [], []
    for t in tri_list:
        i = len(verts)
        verts += [tuple(p) for p in t]
        faces.append((i, i + 1, i + 2))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat_of(material))
    for p in me.polygons:
        p.use_smooth = False
    return o


def mx(p, s):
    return (p[0] * s, p[1], p[2])


def boss_extra(m, intro_arms=150):
    def intro(t):
        k = math.sin(min(1, t) * math.pi / 2)
        return {"arm_r": (intro_arms * k, 0, -20 * k), "arm_l": (intro_arms * k, 0, 20 * k), "chest": (-12 * k, 0, 0), "head": (-14 * k, 0, 0),
                "root": (0, 0, 0, 0, 0, 0.1 * k)}

    def special(t):
        k = math.sin(t * math.pi)
        return {"arm_r": (-40 - 120 * k, 0, -30), "arm_l": (-40 - 120 * k, 0, 30), "chest": (-18 * k, 0, 0), "head": (-20 * k, 0, 0),
                "root": (0, 0, 0, 0, 0, 0.15 * k), "tail": (0, 0, sin(t * 4) * 15)}
    m.clip("intro", 48, intro, loop=False, samples=12)
    m.clip("special", 48, special, loop=False, samples=12)


def rat_king():
    H = 3.3
    m = Biped("boss_rat_king", H, sw=1.08, hw=0.26, hip=0.42)
    fur = mat("fur", (0.38, 0.33, 0.3), 0.9)
    furdk = mat("fur_dk", (0.26, 0.22, 0.2), 0.9)
    belly = mat("belly", (0.72, 0.62, 0.52), 0.9)
    skin = mat("skin", PAL["pink"], 0.6)
    gold = mat("metal_gold", PAL["gold"], 0.25, 1.0)
    cloth = mat("cloth_royal", (0.45, 0.08, 0.2), 0.8)
    ermine = mat("cloth_ermine", PAL["white"], 0.9)
    spot = mat("ermine_spot", (0.05, 0.05, 0.06), 0.9)
    rotm = mat("emblem", PAL["rot"], 0.3, emit="rot", emit_strength=1.4)
    leather = mat("leather", PAL["brown"], 0.7)
    hz = m.hipz
    m.add("hips", sphere((0, 0, hz + 0.05), (1.4, 1.1, 1.0), cloth))
    m.add("chest", sphere((0, -0.05, 0.62 * H), (1.9, 1.3, 1.5), fur))
    m.add("chest", sphere((0, 0.28, 0.56 * H), (1.5, 1.0, 1.35), belly))     # huge belly
    m.add("chest", sphere((0, 0.3, 0.47 * H), (1.6, 1.0, 0.7), cloth))
    m.add("chest", torus((0, 0.3, 0.47 * H), 0.62, 0.07, gold, rot=(0, 0, 0)))   # belt
    m.add("chest", sphere((0, 0.75, 0.47 * H), (0.34, 0.12, 0.3), rotm))        # emblem buckle
    m.arms(fur, furdk, skin, r=0.2, hand=0.3)
    m.legs(cloth, furdk, leather, r=0.24, foot=(0.5, 0.8, 0.28))
    # pauldrons: fur-lined gold shoulder plates with spikes
    for s in (1, -1):
        m.add("arm_" + ("r" if s > 0 else "l"), sphere((s * m.sw, 0, 0.77 * H), (0.78, 0.78, 0.52), gold))
        m.add("arm_" + ("r" if s > 0 else "l"), torus((s * m.sw, 0, 0.75 * H), 0.34, 0.1, ermine))
        for k, (dx, dz) in enumerate(((0.0, 0.35), (0.28 * s, 0.22), (-0.28 * s, 0.22))):
            m.add("arm_" + ("r" if s > 0 else "l"), cone((s * m.sw + dx, 0, 0.77 * H + dz), (0.16, 0.16, 0.42), gold))
        # claws
        for c in (-1, 0, 1):
            m.add("fore_" + ("r" if s > 0 else "l"), cone((s * m.sw + c * 0.09, 0.2, 0.25 * H), (0.05, 0.05, 0.2), mat("claw", PAL["cream"], 0.4), rot=(-100, 0, 0)))
    zh = 0.9 * H
    rat_head(m, "head", 0.12, zh, 1.05, fur, snout=1.0, buck=True)
    # ermine fur collar sitting on the shoulders (flat ring around the neck, below the head)
    col = torus((0, 0.0, 0.78 * H), 0.78, 0.2, ermine)
    col.scale = (1.0, 0.85, 0.7)
    m.add("chest", col)
    for i in range(10):
        a_ = i / 10 * 6.283
        m.add("chest", sphere((math.sin(a_) * 0.78, math.cos(a_) * 0.66, 0.78 * H + 0.07), (0.09, 0.09, 0.05), spot))
    # crown on top of the skull: band, 7 points, jewels
    zc = zh + 0.5
    m.add("head", cyl((0, 0.1, zc), (0.95, 0.95, 0.2), gold, verts=20))
    for i in range(7):
        a_ = i / 7 * 6.283
        x, y = math.sin(a_) * 0.4, 0.1 + math.cos(a_) * 0.4
        m.add("head", cone((x, y, zc + 0.3), (0.16, 0.16, 0.42), gold))
        m.add("head", sphere((x, y, zc + 0.54), (0.09, 0.09, 0.09), rotm if i % 2 else mat("gem_blue", (0.2, 0.4, 0.9), 0.2)))
    m.add("head", sphere((0, 0.52, zc), (0.17, 0.1, 0.17), rotm))
    # royal cape: tall back panel with ermine hem, flares from the shoulders
    m.add("chest", cube((0, -0.72, 0.5 * H), (2.7, 0.1, 0.58 * H), cloth, rot=(6, 0, 0), bevel=0.03))
    m.add("chest", cube((0, -0.76, 0.5 * H - 0.29 * H), (2.8, 0.14, 0.3), ermine, rot=(6, 0, 0), bevel=0.03))
    for sx in (1, -1):
        m.add("chest", sphere((sx * 1.2, -0.4, 0.8 * H - 0.25), (0.8, 0.5, 0.7), cloth))
    # cheese-wedge sceptre (big)
    m.add("fore_r", cyl((m.sw, 0.3, 0.3 * H + 0.6), (0.12, 0.12, 2.0), mat("wood", PAL["wood"], 0.6), rot=(0, 0, 0)))
    m.add("fore_r", cone((m.sw, 0.35, 0.3 * H + 1.8), (0.55, 0.55, 0.6), mat("cheese", PAL["cheddar"], 0.4), rot=(0, 0, 0)))
    m.add("fore_r", sphere((m.sw, 0.3, 0.3 * H + 1.45), (0.22, 0.22, 0.22), gold))
    rat_tail(m, "tail", H, hz)
    m.build()
    std_anims(m, walk_swing=20, arm_swing=16, attack="swing", lean=6, tail_w=12)
    boss_extra(m)
    return m


def crow_baron():
    H = 2.4
    m = Biped("boss_crow_baron", H, sw=0.28, hw=0.1, hip=0.45)
    black = mat("feather", (0.06, 0.07, 0.1), 0.35)
    sheen = mat("feather_rot", PAL["rot_dk"], 0.3, emit="rot", emit_strength=0.3)
    beak = mat("beak", (0.85, 0.65, 0.2), 0.4)
    gold = mat("metal_gold", PAL["gold"], 0.25, 1.0)
    cloth = mat("cloth_coat", (0.1, 0.12, 0.3), 0.7)
    leather = mat("leather", (0.12, 0.08, 0.06), 0.6)
    glow = mat("eye_glow", PAL["rot_lt"], 0.2, emit="rot_lt", emit_strength=3)
    hz = m.hipz
    # wings: horizontal bones from the shoulders (pose +rx raises the right wing tip, lowers the left)
    for s, n in ((1, "r"), (-1, "l")):
        sz = 0.72 * H
        m.bone("wing_" + n, "chest", (s * 0.4, -0.25, sz), (s * 1.9, -0.25, sz))
        m.add("wing_" + n, sphere((s * 0.4, -0.25, sz), (0.55, 0.55, 0.55), black))             # shoulder joint
        m.add("wing_" + n, strut((s * 0.4, -0.25, sz), (s * 1.9, -0.3, sz + 0.1), 0.26, 0.14, black))
        for k in range(8):
            f = k / 7
            base = (s * (0.7 + 1.2 * f), -0.3 - 0.1 * f, sz - 0.08)
            tip = (s * (1.3 + 2.4 * f + 0.8), -0.5 - 1.6 * f, sz - 0.5 - 1.5 * f * 0.4 - 1.0 + 0.5 * f)
            m.add("wing_" + n, strut(base, tip, 0.3, 0.03, black if k % 2 else sheen, verts=6))
        m.add("wing_" + n, sphere((s * 1.3, -0.4, sz - 0.15), (1.5, 0.7, 0.18), black))
    m.add("hips", sphere((0, 0, hz + 0.05), (0.5, 0.4, 0.4), cloth))
    m.add("chest", sphere((0, 0.0, 0.64 * H), (0.7, 0.5, 0.7), cloth))
    m.add("chest", sphere((0, 0.12, 0.66 * H), (0.5, 0.3, 0.55), sheen))
    for i in range(5):
        m.add("chest", sphere((0, 0.22, 0.52 * H + i * 0.12), (0.07, 0.04, 0.07), gold))   # buttons
    m.arms(cloth, cloth, black, r=0.09, hand=0.12)
    m.legs(black, black, beak, r=0.07, foot=(0.2, 0.3, 0.06))
    # head
    hz2 = 0.88 * H
    m.add("head", sphere((0, 0.05, hz2), (0.55, 0.55, 0.55), black))
    m.add("head", cone((0, 0.42, hz2 - 0.04), (0.28, 0.6, 0.22), beak, rot=(-90, 0, 0)))
    for s in (1, -1):
        m.add("head", sphere((s * 0.17, 0.28, hz2 + 0.1), (0.1, 0.07, 0.1), glow))
    # monocle + top hat
    m.add("head", torus((0.17, 0.33, hz2 + 0.1), 0.1, 0.012, gold, rot=(90, 0, 0)))
    m.add("head", cyl((0, 0.04, hz2 + 0.28), (0.8, 0.8, 0.04), black))
    m.add("head", cyl((0, 0.04, hz2 + 0.5), (0.5, 0.5, 0.42), black))
    m.add("head", cyl((0, 0.04, hz2 + 0.34), (0.52, 0.52, 0.06), mat("cloth_band", PAL["red"], 0.6)))
    m.add("head", cone((0.0, -0.1, hz2 + 0.75), (0.1, 0.1, 0.4), black, rot=(-20, 0, 0)))
    # cane
    m.add("fore_r", cyl((m.sw, 0.15, 0.33 * H + 0.1), (0.04, 0.04, 1.3), leather, rot=(-8, 0, 0)))
    m.add("fore_r", sphere((m.sw, 0.2, 0.33 * H + 0.78), (0.12, 0.12, 0.12), gold))
    m.add("tail", cone((0, -0.3, hz), (0.35, 0.5, 0.05), black, rot=(-110, 0, 0)))
    m.build()
    std_anims(m, walk_swing=20, arm_swing=16, attack="swing", lean=6, tail_w=6)
    def flap(t):
        k = sin(t * 4) * 30
        return {"wing_r": (k, 0, 0), "wing_l": (-(-k), 0, 0)}
    def idle_w(t):
        k = sin(t) * 8
        return {"wing_r": (k, 0, 0), "wing_l": (-(-k), 0, 0)}
    def intro(t):
        k = math.sin(min(1, t) * math.pi / 2)
        return {"wing_r": (35 * k, 0, 0), "wing_l": (-(-35 * k), 0, 0), "arm_r": (140 * k, 0, -10), "chest": (-10 * k, 0, 0)}
    def special(t):
        k = math.sin(t * math.pi)
        return {"wing_r": (sin(t * 3) * 40 + 20, 0, 0), "wing_l": (-(-sin(t * 3) * 40 - 20), 0, 0), "chest": (-14 * k, 0, 0),
                "arm_r": (-60 * k, 0, 0), "root": (0, 0, 0, 0, 0, 0.3 * k)}
    m.clip("wing_flap", 16, flap, samples=8)
    m.clip("wing_idle", 48, idle_w, samples=12)
    m.clip("intro", 48, intro, loop=False, samples=12)
    m.clip("special", 48, special, loop=False, samples=12)
    return m


def mold_dragon():
    m = Model("boss_mold_dragon")
    rotc = mat("skin_rot", PAL["rot"], 0.55, emit="rot_dk", emit_strength=0.25)
    dark = mat("skin_rot_dk", PAL["rot_dk"], 0.6)
    lt = mat("emblem", PAL["rot_lt"], 0.3, emit="rot_lt", emit_strength=1.5)
    cheese = mat("cheese", (0.8, 0.75, 0.35), 0.5)
    tooth = mat("tooth", PAL["cream"], 0.4)
    wing = mat("wing", (0.12, 0.45, 0.45), 0.5, emit="rot_dk", emit_strength=0.3)
    eye = mat("eye_glow", PAL["rot_lt"], 0.2, emit="rot_lt", emit_strength=4)
    m.bone("root", None, (0, 0, 0), (0, 0.2, 0))
    m.bone("body", "root", (0, -0.6, 1.4), (0, 0.8, 1.5))
    m.bone("neck", "body", (0, 0.9, 1.6), (0, 1.7, 2.7))
    m.bone("head", "neck", (0, 1.7, 2.7), (0, 2.5, 2.7))
    m.bone("jaw", "head", (0, 1.9, 2.45), (0, 2.8, 2.4))
    m.bone("tail1", "body", (0, -0.8, 1.4), (0, -2.0, 1.1))
    m.bone("tail2", "tail1", (0, -2.0, 1.1), (0, -3.2, 0.7))
    for s, n in ((1, "r"), (-1, "l")):
        # wing (+rx raises the tip on both sides): shoulder joint sits ON the back of the body; bones horizontal (pose +rx raises right tip / lowers left)
        S_, E_, W_ = (s * 0.7, 0.1, 2.3), (s * 2.6, -0.1, 3.2), (s * 4.4, -0.6, 3.0)
        T1, T2, T3 = (s * 7.0, 0.1, 2.9), (s * 6.4, -1.6, 1.9), (s * 5.0, -2.8, 1.4)
        E2, B_ = (s * 2.9, -2.1, 1.9), (s * 0.7, -1.7, 1.6)
        m.bone("wing_" + n, "body", S_, (E_[0], S_[1], S_[2]))
        m.bone("wingtip_" + n, "wing_" + n, (E_[0], S_[1], S_[2]), (s * 6.0, S_[1], S_[2]))
        m.add("wing_" + n, sphere(S_, (1.05, 1.1, 1.0), rotc))                                # shoulder ball joint
        m.add("wing_" + n, sphere((s * 0.45, 0.0, 2.0), (1.0, 1.1, 0.9), rotc))              # shoulder muscle blending into the back
        m.add("wing_" + n, strut(S_, E_, 0.5, 0.34, rotc))
        m.add("wing_" + n, sphere(E_, (0.45, 0.45, 0.45), dark))
        m.add("wing_" + n, tris([(S_, E_, E2), (S_, E2, B_)], wing, "memb_in"))
        m.add("wingtip_" + n, strut(E_, W_, 0.34, 0.24, dark))
        m.add("wingtip_" + n, tris([(W_, T1, T2), (W_, T2, T3), (W_, T3, E2), (W_, E2, E_)], wing, "memb_out"))
        for T in (T1, T2, T3):
            m.add("wingtip_" + n, strut(W_, T, 0.2, 0.05, dark, verts=8))
        m.add("wingtip_" + n, cone((W_[0], W_[1] + 0.2, W_[2] + 0.3), (0.16, 0.16, 0.5), tooth, rot=(-30, 0, 0)))   # wing claw
        for fb, y in (("f", 0.8), ("b", -0.7)):
            ln = "leg%s_%s" % (fb, n)
            m.bone(ln, "body", (s * 0.8, y, 1.4), (s * 0.8, y + 0.1, 0.1))
            m.add(ln, cyl((s * 0.8, y + 0.05, 0.75), (0.7, 0.7, 1.4), rotc, r1=0.65, r2=1.0))
            m.add(ln, sphere((s * 0.8, y + 0.3, 0.16), (0.8, 1.1, 0.34), dark))
            for k in (-1, 0, 1):
                m.add(ln, cone((s * 0.8 + k * 0.24, y + 0.85, 0.14), (0.12, 0.12, 0.36), tooth, rot=(-90, 0, 0)))
        # swept-back curved horns (two segments) and glowing eyes
        m.add("head", strut((s * 0.38, 2.1, 3.0), (s * 0.55, 1.6, 3.6), 0.3, 0.2, tooth))
        m.add("head", strut((s * 0.55, 1.6, 3.6), (s * 0.5, 0.9, 4.0), 0.2, 0.03, tooth))
        m.add("head", sphere((s * 0.42, 2.45, 2.85), (0.24, 0.16, 0.24), eye))
        m.add("head", cone((s * 0.55, 2.2, 3.2), (0.16, 0.16, 0.5), tooth, rot=(-30, 0, s * 15)))
        m.add("head", sphere((s * 0.28, 3.35, 2.6), (0.1, 0.1, 0.1), lt))        # nostril glow
    m.add("body", sphere((0, 0.1, 1.55), (2.3, 3.2, 2.0), rotc))
    m.add("body", sphere((0, 0.4, 1.25), (1.6, 2.6, 1.3), cheese))      # moldy cheese belly
    m.add("body", sphere((0, 0.9, 1.9), (2.0, 1.6, 1.8), rotc))           # chest
    for i in range(9):  # dorsal spore spikes
        z = 2.45 - abs(i - 3) * 0.05
        m.add("body", cone((0, -1.0 + i * 0.3, z + 0.15), (0.3, 0.3, 0.7 - abs(i - 3) * 0.04), lt))
    for i in range(6):
        m.add("neck", cone((0, 1.0 + i * 0.16, 2.0 + i * 0.12 + 0.35), (0.22, 0.22, 0.5), lt, rot=(-25, 0, 0)))
    m.add("neck", strut((0, 0.8, 1.7), (0, 1.8, 2.7), 1.5, 1.0, rotc, verts=16))
    m.add("head", sphere((0, 2.1, 2.75), (1.3, 1.5, 1.1), rotc))
    m.add("head", sphere((0, 2.75, 2.65), (0.85, 1.1, 0.65), dark))     # snout
    m.add("jaw", cube((0, 2.55, 2.38), (0.8, 1.4, 0.2), dark, bevel=0.04))
    for k in range(6):
        m.add("head", cone((-0.3 + k * 0.12, 2.95, 2.5), (0.07, 0.07, 0.26), tooth, rot=(180, 0, 0)))
        m.add("jaw", cone((-0.28 + k * 0.11, 2.85, 2.47), (0.07, 0.07, 0.22), tooth))
    m.add("tail1", strut((0, -0.5, 1.4), (0, -2.0, 1.1), 1.4, 0.9, rotc, verts=14))
    m.add("tail2", strut((0, -2.0, 1.1), (0, -3.3, 0.7), 0.9, 0.35, rotc, verts=12))
    for i in range(5):
        m.add("tail1" if i < 3 else "tail2", cone((0, -0.8 - i * 0.55, 1.65 - i * 0.12), (0.22, 0.22, 0.5), lt))
    m.add("tail2", sphere((0, -3.5, 0.65), (0.6, 0.6, 0.6), lt))
    m.build()

    def idle(t):
        return {"body": (sin(t) * 1.5, 0, 0, 0, 0, sin(t) * 0.03), "neck": (sin(t, .5) * 3, sin(t) * 3, 0), "tail1": (0, 0, sin(t, .3) * 6), "tail2": (0, 0, sin(t, .6) * 10),
                "wing_r": (sin(t) * 4, 0, 0), "wing_l": (-(-sin(t) * 4), 0, 0), "wingtip_r": (sin(t, .2) * 6, 0, 0), "wingtip_l": (-(-sin(t, .2) * 6), 0, 0)}

    def walk(sw):
        def f(t):
            d = {"body": (0, 0, sin(t * 2) * 2, 0, 0, abs(sin(t)) * 0.06), "tail1": (0, 0, sin(t) * 10), "tail2": (0, 0, sin(t, .5) * 14)}
            for n, ph in (("legf_r", 0), ("legb_l", 0), ("legf_l", .5), ("legb_r", .5)):
                d[n] = (sin(t, ph) * sw, 0, 0)
            return d
        return f

    def attack(t):
        k = math.sin(t * math.pi)
        return {"neck": (-35 * k, 0, 0), "head": (-15 * k, 0, 0), "jaw": (35 * k, 0, 0), "body": (0, 0, 0, 0, 0.5 * k, 0), "tail1": (0, 0, 20 * k)}

    def hurt(t):
        k = math.sin(t * math.pi)
        return {"body": (-8 * k, 0, 0, 0, -0.3 * k, 0), "neck": (25 * k, 0, 0), "head": (20 * k, 0, 0), "jaw": (30 * k, 0, 0), "wing_r": (25 * k, 0, 0), "wing_l": (-(-25 * k), 0, 0)}

    def down(t):
        k = min(1, t * 1.5); k = k * k * (3 - 2 * k)
        return {"body": (0, 0, 0, 0, 0, -0.9 * k), "neck": (40 * k, 0, 0), "head": (30 * k, 0, 0), "jaw": (20 * k, 0, 0),
                "wing_r": (-45 * k, 0, 0), "wing_l": (-(45 * k), 0, 0), "tail2": (0, 0, 20 * k)}

    def intro(t):
        k = math.sin(min(1, t) * math.pi / 2)
        return {"neck": (-40 * k, 0, 0), "head": (-10 * k, 0, 0), "jaw": (40 * k, 0, 0), "wing_r": (50 * k, 0, 0), "wing_l": (-(-50 * k), 0, 0), "wingtip_r": (-20 * k, 0, 0), "wingtip_l": (-(20 * k), 0, 0), "body": (10 * k, 0, 0)}

    def special(t):
        k = math.sin(t * math.pi)
        return {"neck": (-45 * k, 0, 0), "jaw": (45 * k, 0, 0), "head": (-20 * k, 0, 0), "wing_r": (sin(t * 3) * 30 + 30 * k, 0, 0), "wing_l": (-(-sin(t * 3) * 30 - 30 * k), 0, 0), "wingtip_r": (sin(t * 3, .1) * 25, 0, 0), "wingtip_l": (-(-sin(t * 3, .1) * 25), 0, 0),
                "body": (8 * k, 0, 0, 0, 0, 0.1 * k)}
    m.clip("idle", 60, idle, samples=12)
    m.clip("walk", 36, walk(18), samples=12)
    m.clip("run", 24, walk(28), samples=8)
    m.clip("attack", 28, attack, loop=False, samples=10)
    m.clip("cast", 36, special, loop=False, samples=10)
    m.clip("hurt", 16, hurt, loop=False, samples=7)
    m.clip("down", 48, down, loop=False, samples=10)
    def victory(t):
        a = abs(sin(t))
        k = sin(t * 2)
        return {"body": (-14 - a * 4, 0, 0, 0, 0, 0.2 + a * 0.1), "neck": (-30 + k * 6, sin(t) * 12, 0), "head": (-18, 0, 0), "jaw": (30 + k * 12, 0, 0),
                "wing_r": (28 + k * 18, 0, 0), "wing_l": (-(-28 - k * 18), 0, 0), "wingtip_r": (k * 14, 0, 0), "wingtip_l": (-(-k * 14), 0, 0),
                "tail1": (0, 0, sin(t) * 14), "tail2": (0, 0, sin(t, .3) * 20), "legf_r": (-25, 0, 0), "legf_l": (-25, 0, 0)}
    m.clip("victory", 48, victory, samples=12)
    m.clip("defend", 30, lambda t: {"neck": (20, 0, 0), "head": (15, 0, 0), "wing_r": (-60, 0, 0), "wing_l": (-(60), 0, 0), "wingtip_r": (-30, 0, 0), "wingtip_l": (-(30), 0, 0)}, samples=4)
    m.clip("intro", 60, intro, loop=False, samples=12)
    m.clip("special", 48, special, loop=False, samples=12)
    return m


ALL = dict(rat_king=rat_king, mold_dragon=mold_dragon, crow_baron=crow_baron)
for k, fn in ALL.items():
    if ONLY and k not in ONLY:
        continue
    try:
        finish(fn(), yaw=35, pitch=18)
    except Exception as e:
        import traceback
        traceback.print_exc(); print("FAIL", k, e)
        reset(); clear_mats()
