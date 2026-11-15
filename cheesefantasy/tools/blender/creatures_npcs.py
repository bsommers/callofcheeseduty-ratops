"""NPCs: blender -b -P tools/blender/creatures_npcs.py [-- name ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from creatures_common import *

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def human(name, H, skin, shirt, pants, shoes, sw=0.2, hw=0.095, belly=0.0, headr=1.0, hair=None, hair_style="short", eye=0.03, skirt=None, arm_r=0.045):
    m = Biped(name, H, sw=sw, hw=hw, hip=0.5, tail=False)
    sk = mat("skin", skin, 0.6)
    hz = m.hipz
    chest_z = 0.66 * H
    w = sw * 2.1
    m.add("hips", sphere((0, 0, hz + 0.03), (w * 0.85 + belly * 0.4, 0.23 * H * 0.8 + belly, 0.2 * H), pants))
    m.add("chest", sphere((0, 0, chest_z), (w + 0.04, 0.24 * H * 0.7 + belly, 0.3 * H), shirt))
    if belly:
        m.add("chest", sphere((0, 0.04 + belly * 0.5, chest_z - 0.12 * H), (w * 0.9 + belly, 0.22 * H + belly, 0.22 * H), shirt))
    m.arms(shirt, shirt, sk, r=arm_r, hand=0.05)
    if skirt is None:
        m.legs(pants, pants, shoes, r=0.065 * H / 1.7 + 0.015, foot=(0.11, 0.22, 0.08))
    else:
        m.legs(skirt, sk, shoes, r=0.055 * H / 1.7 + 0.015, foot=(0.1, 0.2, 0.07))
        m.add("hips", cyl((0, 0, hz - 0.02), (w * 1.25, w * 1.1, 0.3 * H), skirt, r1=1.0, r2=0.6, verts=20))
    hr = 0.115 * H * headr
    hc = 0.9 * H
    m.add("chest", cyl((0, 0, 0.78 * H), (0.11, 0.11, 0.07), sk))
    m.add("head", sphere((0, 0.0, hc), (hr * 2, hr * 2.1, hr * 2.15), sk))
    m.add("head", sphere((0, hr * 0.95, hc - 0.01), (0.04, 0.05, 0.05), mat("nose", tuple(min(1, c * 1.05) for c in skin), 0.6)))
    for s in (1, -1):
        m.add("head", sphere((s * hr * 0.42, hr * 0.85, hc + 0.015), (eye * 1.6, eye * 1.0, eye * 1.7), mat("eyewhite", PAL["white"], 0.3)))
        m.add("head", sphere((s * hr * 0.42, hr * 0.92, hc + 0.015), (eye * 1.0, eye * 0.6, eye * 1.2), mat("eye", PAL["black"], 0.2)))
        m.add("head", sphere((s * hr * 1.0, 0.0, hc), (0.03, 0.05, 0.06), sk))
    m.add("head", cube((0, hr * 0.8, hc - hr * 0.42), (hr * 0.45, 0.02, 0.012), mat("mouth", (0.6, 0.25, 0.22), 0.6)))
    if hair:
        hm = mat("hair", hair, 0.7)
        if hair_style == "short":
            m.add("head", sphere((0, -0.015, hc + hr * 0.25), (hr * 2.1, hr * 2.15, hr * 1.8), hm))
        elif hair_style == "pigtails":
            m.add("head", sphere((0, -0.015, hc + hr * 0.25), (hr * 2.1, hr * 2.15, hr * 1.8), hm))
            for s in (1, -1):
                m.add("head", sphere((s * hr * 1.1, -0.02, hc - hr * 0.2), (hr * 0.6, hr * 0.6, hr * 1.5), hm))
        elif hair_style == "bun":
            m.add("head", sphere((0, -0.015, hc + hr * 0.2), (hr * 2.1, hr * 2.15, hr * 1.8), hm))
            m.add("head", sphere((0, -hr * 0.4, hc + hr * 1.1), (hr * 0.9, hr * 0.9, hr * 0.9), hm))
        elif hair_style == "wild":
            m.add("head", sphere((0, -0.02, hc + hr * 0.3), (hr * 2.3, hr * 2.3, hr * 1.9), hm))
    m.hr, m.hc = hr, hc
    return m


def hat_straw(m, color=None):
    c = mat("hat_straw", color or PAL["hay"], 0.8)
    m.add("head", cyl((0, 0, m.hc + m.hr * 0.95), (m.hr * 4.2, m.hr * 4.2, 0.02), c, verts=24))
    m.add("head", cyl((0, 0, m.hc + m.hr * 1.4), (m.hr * 2.2, m.hr * 2.2, m.hr * 0.9), c, verts=20))
    m.add("head", cyl((0, 0, m.hc + m.hr * 1.1), (m.hr * 2.25, m.hr * 2.25, 0.05), mat("cloth_red", PAL["red"], 0.8), verts=20))


def toque(m):
    c = mat("cloth_white", PAL["white"], 0.9)
    m.add("head", cyl((0, 0, m.hc + m.hr * 1.2), (m.hr * 2.0, m.hr * 2.0, m.hr * 0.9), c, verts=20))
    m.add("head", sphere((0, 0, m.hc + m.hr * 1.85), (m.hr * 2.5, m.hr * 2.5, m.hr * 1.2), c))


def finish_npc(m, **kw):
    m.build()
    std_anims(m, **kw)
    return m


def farmer():
    m = human("npc_farmer", 1.8, PAL["skin"], mat("cloth_shirt", (0.75, 0.2, 0.15), 0.85), mat("cloth_denim", PAL["blue"], 0.8), mat("leather", PAL["brown"], 0.6),
              sw=0.26, hw=0.11, belly=0.1, hair=(0.3, 0.2, 0.1))
    hat_straw(m)
    # overall straps + pocket + moustache
    m.add("chest", cube((0, 0.14, 1.2), (0.38, 0.06, 0.34), mat("cloth_denim"), bevel=0.01))
    for s in (1, -1):
        m.add("chest", cube((s * 0.1, 0.08, 1.4), (0.06, 0.07, 0.35), mat("cloth_denim"), rot=(-8, 0, 0)))
    m.add("head", sphere((0, m.hr * 0.9, m.hc - m.hr * 0.3), (m.hr * 1.2, 0.05, 0.05), mat("hair")))
    # pitchfork in right hand
    wood = mat("wood", PAL["wood_lt"], 0.8)
    m.add("fore_r", cyl((m.sw, 0.12, 0.6 * 1.8 * 0.5 + 0.35), (0.035, 0.035, 1.7), wood, rot=(-5, 0, 0)))
    for k in (-1, 0, 1):
        m.add("fore_r", cone((m.sw + k * 0.07, 0.07, 1.78), (0.02, 0.02, 0.3), mat("metal", PAL["metal"], 0.35, 0.9)))
    m.add("fore_r", cube((m.sw, 0.07, 1.62), (0.2, 0.03, 0.03), mat("metal")))
    return finish_npc(m, walk_swing=24, arm_swing=18, attack="swing")


def cook():
    m = human("npc_cook", 1.65, (0.85, 0.62, 0.48), mat("cloth_white", PAL["white"], 0.85), mat("cloth_check", (0.3, 0.3, 0.35), 0.85), mat("leather", PAL["black"], 0.6),
              sw=0.24, hw=0.1, belly=0.14, hair=(0.15, 0.1, 0.08), hair_style="short")
    toque(m)
    m.add("chest", cube((0, 0.2, 0.95), (0.5, 0.06, 0.6), mat("cloth_apron", PAL["cream"], 0.9), bevel=0.01))
    m.add("head", sphere((0, m.hr * 0.9, m.hc - m.hr * 0.3), (m.hr * 1.0, 0.05, 0.05), mat("hair")))
    m.add("fore_r", cyl((m.sw, 0.14, 0.33 * 1.65 + 0.1), (0.03, 0.03, 0.4), mat("wood", PAL["wood"], 0.8), rot=(-70, 0, 0)))
    m.add("fore_r", sphere((m.sw, 0.36, 0.33 * 1.65 + 0.14), (0.14, 0.17, 0.06), mat("metal", PAL["metal"], 0.3, 0.9), rot=(-20, 0, 0)))
    return finish_npc(m, walk_swing=22, arm_swing=16, attack="swing")


def cheesemonger():
    m = human("npc_cheesemonger", 1.7, (0.78, 0.55, 0.4), mat("cloth_vest", (0.5, 0.2, 0.15), 0.8), mat("cloth_pants", (0.25, 0.22, 0.2), 0.85), mat("leather", PAL["brown"], 0.6),
              sw=0.23, hw=0.1, belly=0.05, hair=(0.85, 0.85, 0.82), hair_style="short")
    m.add("chest", cube((0, 0.13, 1.1), (0.46, 0.05, 0.5), mat("cloth_apron", PAL["white"], 0.9), bevel=0.01))
    m.add("head", sphere((0, m.hr * 0.9, m.hc - m.hr * 0.35), (m.hr * 1.6, 0.07, 0.1), mat("hair", (0.85, 0.85, 0.82), 0.8)))
    m.add("head", cyl((0, m.hr * 0.5, m.hc + m.hr * 1.0), (m.hr * 3, m.hr * 2.6, 0.04), mat("cloth_beret", PAL["barn"], 0.9), verts=20))
    # wheel of cheese on the left arm
    m.add("fore_l", cyl((-m.sw, 0.15, 0.33 * 1.7 + 0.12), (0.4, 0.4, 0.12), mat("rind", PAL["cheddar"], 0.5), rot=(90, 0, 0), verts=24))
    m.add("fore_l", cyl((-m.sw, 0.215, 0.33 * 1.7 + 0.12), (0.34, 0.34, 0.01), mat("cheese", PAL["cream"], 0.4), rot=(90, 0, 0), verts=24))
    return finish_npc(m, walk_swing=22, arm_swing=14)


def tinker():
    m = human("npc_tinker", 1.4, (0.7, 0.5, 0.4), mat("cloth_coat", (0.2, 0.4, 0.38), 0.8), mat("cloth_pants", (0.3, 0.25, 0.2), 0.85), mat("leather", PAL["brown"], 0.6),
              sw=0.2, hw=0.09, hair=(0.5, 0.3, 0.12), hair_style="wild", headr=1.15)
    metal = mat("metal", PAL["metal"], 0.3, 0.9)
    # goggles on forehead
    for s in (1, -1):
        m.add("head", cyl((s * 0.06, m.hr * 0.5, m.hc + m.hr * 1.0), (0.09, 0.09, 0.05), metal, rot=(70, 0, 0)))
    m.add("head", cyl((0, m.hr * 0.4, m.hc + m.hr * 0.95), (m.hr * 2.1, m.hr * 2.1, 0.03), mat("leather"), rot=(0, 0, 0), verts=16))
    # big backpack of gadgets
    m.add("chest", cube((0, -0.2, 0.95), (0.4, 0.22, 0.48), mat("leather"), bevel=0.02))
    m.add("chest", cyl((0.12, -0.32, 1.28), (0.1, 0.1, 0.34), metal))
    m.add("chest", sphere((-0.1, -0.35, 1.2), (0.18, 0.18, 0.18), mat("gold", PAL["gold"], 0.3, 0.9)))
    m.add("chest", cube((0, 0.12, 0.85), (0.34, 0.04, 0.1), mat("leather")))
    # spanner
    m.add("fore_r", cyl((m.sw, 0.1, 0.33 * 1.4 + 0.1), (0.035, 0.035, 0.35), metal, rot=(-30, 0, 0)))
    m.add("fore_r", torus((m.sw, 0.2, 0.33 * 1.4 + 0.27), 0.05, 0.015, metal, rot=(60, 0, 0)))
    return finish_npc(m, walk_swing=26, arm_swing=18)


def kid():
    m = human("npc_kid", 1.05, PAL["skin"], mat("cloth_shirt", (0.9, 0.8, 0.2), 0.85), mat("cloth_shorts", PAL["blue"], 0.8), mat("leather", PAL["red"], 0.6),
              sw=0.14, hw=0.07, hair=(0.9, 0.55, 0.15), hair_style="short", headr=1.5, eye=0.034, arm_r=0.03)
    m.add("head", cyl((0, 0.0, m.hc + m.hr * 1.0), (m.hr * 2.2, m.hr * 2.2, 0.06), mat("cloth_cap", PAL["red"], 0.8), verts=20))
    m.add("head", cube((0, m.hr * 1.15, m.hc + m.hr * 0.95), (m.hr * 1.5, 0.12, 0.02), mat("cloth_cap")))
    # freckles + toy cheese in hand
    m.add("fore_r", cone((m.sw, 0.08, 0.33 * 1.05 + 0.04), (0.12, 0.12, 0.07), mat("cheese", PAL["cheddar"], 0.5), rot=(0, 0, 0)))
    return finish_npc(m, walk_swing=30, arm_swing=26)


def granny():
    m = human("npc_granny", 1.4, (0.9, 0.75, 0.65), mat("cloth_dress", (0.5, 0.3, 0.55), 0.85), mat("cloth_pants", PAL["white"], 0.9), mat("leather", PAL["brown"], 0.6),
              sw=0.19, hw=0.08, hair=(0.9, 0.9, 0.92), hair_style="bun", skirt=mat("cloth_skirt", (0.45, 0.25, 0.5), 0.85), belly=0.03)
    for s in (1, -1):
        m.add("head", torus((s * 0.04, m.hr * 0.9, m.hc + 0.01), 0.032, 0.005, mat("metal", PAL["gold"], 0.3, 0.9), rot=(90, 0, 0)))
    m.add("chest", cube((0, 0.16, 0.95), (0.34, 0.04, 0.3), mat("cloth_apron", PAL["cream"], 0.9), bevel=0.01))
    m.add("fore_r", cyl((m.sw, 0.05, 0.33 * 1.4 - 0.1), (0.035, 0.035, 0.85), mat("wood", PAL["wood"], 0.7), rot=(0, 0, 0)))
    m.add("fore_r", torus((m.sw, 0.05, 0.33 * 1.4 + 0.35), 0.05, 0.015, mat("wood"), rot=(0, 90, 0)))
    return finish_npc(m, walk_swing=14, arm_swing=8, lean=12)


def scarecrow():
    H = 1.8
    m = Biped("npc_scarecrow", H, sw=0.28, hw=0.1, hip=0.5, tail=False)
    straw = mat("straw", PAL["hay"], 0.95)
    sack = mat("cloth_sack", (0.72, 0.6, 0.4), 0.95)
    shirt = mat("cloth_plaid", (0.55, 0.18, 0.15), 0.9)
    pants = mat("cloth_patch", (0.3, 0.4, 0.55), 0.9)
    wood = mat("wood", PAL["wood"], 0.9)
    hz = m.hipz
    m.add("hips", sphere((0, 0, hz + 0.05), (0.38, 0.26, 0.28), pants))
    m.add("chest", sphere((0, 0, 1.2), (0.5, 0.3, 0.5), shirt))
    m.arms(shirt, shirt, straw, r=0.06, hand=0.07)
    m.legs(pants, pants, wood, r=0.075, foot=(0.12, 0.22, 0.08))
    for s in (1, -1):  # straw tufts at wrists/ankles
        for k in range(4):
            m.add("fore_" + ("r" if s > 0 else "l"), cone((s * 0.28 + (k - 1.5) * 0.02, 0.0, 0.58 - 0.0), (0.02, 0.02, 0.18), straw, rot=(180, 0, (k - 1.5) * 15)))
    m.add("chest", cyl((0, 0, 0.9), (0.2, 0.2, 0.15), straw))
    # sack head with stitched face
    m.add("head", sphere((0, 0, 1.55), (0.4, 0.38, 0.44), sack))
    m.add("head", cone((0, -0.02, 1.8), (0.14, 0.14, 0.16), sack))
    for s in (1, -1):
        m.add("head", cube((s * 0.09, 0.18, 1.58), (0.08, 0.02, 0.08), mat("stitch", PAL["black"], 0.9), rot=(0, 0, 45)))
        m.add("head", cube((s * 0.09, 0.18, 1.58), (0.08, 0.02, 0.02), mat("stitch"), rot=(0, 0, -45)))
    for k in range(5):
        m.add("head", cube((-0.1 + k * 0.05, 0.18, 1.45 + (0.02 if k % 2 else 0)), (0.02, 0.02, 0.05), mat("stitch")))
    m.add("head", cone((0, 0.2, 1.52), (0.06, 0.06, 0.1), mat("carrot", PAL["orange"], 0.6), rot=(-90, 0, 0)))
    hat_straw_like = mat("hat_felt", (0.22, 0.17, 0.12), 0.9)
    m.add("head", cyl((0, 0, 1.72), (0.62, 0.62, 0.025), hat_straw_like, verts=24))
    m.add("head", cyl((0, 0, 1.82), (0.34, 0.34, 0.22), hat_straw_like, verts=20))
    m.add("head", cyl((0, 0, 1.75), (0.35, 0.35, 0.04), mat("cloth_red", PAL["red"], 0.8), verts=20))
    # pole behind
    m.add("chest", cyl((0, -0.18, 0.9), (0.06, 0.06, 1.8), wood))
    m.add("chest", cyl((0, -0.18, 1.35), (0.05, 0.05, 1.3), wood, rot=(0, 90, 0)))
    m.build()
    std_anims(m, walk_swing=10, arm_swing=6)
    return m


ALL = dict(farmer=farmer, cook=cook, cheesemonger=cheesemonger, tinker=tinker, kid=kid, granny=granny, scarecrow=scarecrow)
for k, fn in ALL.items():
    if ONLY and k not in ONLY:
        continue
    finish(fn())
