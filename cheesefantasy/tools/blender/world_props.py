"""Static world props: blender -b -P tools/blender/world_props.py [-- name ...]  (names without 'world_')"""
import sys, os, random
sys.path.insert(0, os.path.dirname(__file__))
from lib_common import *

ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def prism(w, h, d, loc, material, apex=None):
    """Triangular prism (gable end): base width w (X), height h (Z), depth d (Y). loc = base centre."""
    me = bpy.data.meshes.new("prism")
    ax = w / 2 if apex is None else apex
    x0, y0, z0 = 0, 0, 0
    v = [(-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (ax - w / 2 + 0, -d / 2, h), (-w / 2, d / 2, 0), (w / 2, d / 2, 0), (ax - w / 2, d / 2, h)]
    v = [(x - (0 if apex is None else 0), y, z) for x, y, z in v]
    f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    me.from_pydata(v, [], f)
    me.update()
    o = bpy.data.objects.new("prism", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    me.materials.append(mat_of(material))
    return o


def poly_extrude(pts, d, loc, material):
    """Closed polygon in the XZ plane (x,z) extruded along Y (depth d, centred). Normals recalculated outward."""
    bm = bmesh.new()
    a = [bm.verts.new((x, -d / 2, z)) for x, z in pts]
    b = [bm.verts.new((x, d / 2, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("poly")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("poly", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    me.materials.append(mat_of(material))
    return o


def roof_chevron(top, t, d, loc, material):
    """Thick roof shell: top = outer outline (eave..ridge..eave) as (x,z); t = thickness (vertical)."""
    pts = list(top) + [(x, z - t) for x, z in reversed(top)]
    return poly_extrude(pts, d, loc, material)


def gable_pts(hw, h, over):
    """Gable outline over half-width hw / rise h, extended by `over` of eave overhang along the slope."""
    sl = h / hw
    return [(-(hw + over), -over * sl), (0, h), (hw + over, -over * sl)]


def gambrel_pts(hw, kx, kz, h, over):
    s1 = kz / (hw - kx)
    return [(-(hw + over), -over * s1), (-kx, kz), (0, h), (kx, kz), (hw + over, -over * s1)]


def clip_ground(o):
    """Remove everything below z=0 (applies transforms first)."""
    apply_all(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    g = bm.verts[:] + bm.edges[:] + bm.faces[:]
    r = bmesh.ops.bisect_plane(bm, geom=g, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.contextual_create(bm, geom=[e for e in r["geom_cut"] if isinstance(e, bmesh.types.BMEdge)])
    bm.to_mesh(o.data)
    bm.free()
    return o


def B(S, loc, size, material, rot=(0, 0, 0), group="body", bevel=0.0):
    return S.add(cube(loc, size, material, rot, bevel=bevel), group)


def Cy(S, loc, size, material, rot=(0, 0, 0), group="body", verts=16, **kw):
    return S.add(cyl(loc, size, material, rot, verts=verts, **kw), group)


def planks(S, x0, x1, y, z0, z1, mt, n=None, t=0.03, group="body", axis="x"):
    """Vertical board siding on a wall facing +/-Y between x0..x1 and z0..z1."""
    n = n or int(abs(x1 - x0) / 0.22)
    w = (x1 - x0) / n
    for i in range(n):
        B(S, ((x0 + w * (i + 0.5)), y, (z0 + z1) / 2), (w * 0.94, t, z1 - z0), mt, group=group)


M = lambda n, c=None, r=0.7, m=0.0, **k: mat(n, PAL[c] if isinstance(c, str) else c, r, m, **k)


def barn():
    S = Static("world_barn")
    red, trim, wood, dk = M("paint_red", "barn", 0.8), M("paint_white", "white", 0.8), M("wood", "wood", 0.85), M("roof", (0.22, 0.2, 0.2), 0.7)
    W, D, WH = 8.0, 10.0, 4.0
    B(S, (0, 0, WH / 2), (W, D, WH), red, bevel=0.02)
    B(S, (0, 0, 0.1), (W + 0.3, D + 0.3, 0.2), M("stone", "stone", 0.9))
    # gambrel roof: steep lower slope + shallow upper slope, thick shell with overhang, solid gable-end walls
    hw, kx, kz, hh = W / 2, 2.7, 2.1, 3.7
    S.add(poly_extrude([(-hw, 0), (-kx, kz), (0, hh), (kx, kz), (hw, 0)], D, (0, 0, WH), red))
    S.add(roof_chevron(gambrel_pts(hw, kx, kz, hh, 0.35), 0.2, D + 0.9, (0, 0, WH + 0.04), dk))
    for s in (1, -1):
        B(S, (s * (W / 2 + 0.02), 0, WH / 2), (0.1, D + 0.1, 0.18), trim)
    B(S, (0, 0, WH + hh + 0.04), (0.5, D + 0.95, 0.14), dk)
    # white trim and door frame
    for s in (1, -1):
        B(S, (s * W / 2, D / 2 + 0.02, WH / 2), (0.18, 0.08, WH), trim)
        B(S, (s * W / 2, -D / 2 - 0.02, WH / 2), (0.18, 0.08, WH), trim)
    DW, DH = 3.2, 3.0
    B(S, (0, D / 2 + 0.02, DH + 0.1), (DW + 0.5, 0.1, 0.2), trim)
    for s in (1, -1):
        B(S, (s * (DW / 2 + 0.12), D / 2 + 0.02, DH / 2), (0.2, 0.1, DH), trim)
    B(S, (0, D / 2 - 0.05, DH / 2), (DW, 0.1, DH), M("dark", (0.08, 0.05, 0.04), 1))
    # doors (separate nodes, pivot at outer hinge)
    for s, g in ((1, "door_r"), (-1, "door_l")):
        B(S, (s * DW / 4, D / 2 + 0.08, DH / 2), (DW / 2 - 0.02, 0.1, DH), red, group=g)
        for sg in (1, -1):
            B(S, (s * DW / 4, D / 2 + 0.14, DH / 2), (0.14, 0.04, math.hypot(DW / 2, DH) * 0.98), trim, rot=(0, sg * math.degrees(math.atan2(DW / 2, DH)), 0), group=g)
        B(S, (s * DW / 4, D / 2 + 0.14, DH), (DW / 2, 0.05, 0.12), trim, group=g)
        B(S, (s * DW / 4, D / 2 + 0.14, 0.0), (DW / 2, 0.05, 0.12), trim, group=g)
        B(S, (s * DW / 4, D / 2 + 0.14, DH / 2), (DW / 2, 0.05, 0.12), trim, group=g)
        S.pivots[g] = (s * DW / 2, D / 2 + 0.08, 0)
    # hayloft door
    B(S, (0, D / 2 + 0.05, WH + 1.2), (1.3, 0.06, 1.3), trim)
    B(S, (0, D / 2 + 0.09, WH + 1.2), (1.1, 0.06, 1.1), M("dark"))
    B(S, (0, D / 2 + 0.15, WH + 2.05), (0.15, 0.15, 0.15), M("hay", "hay", 0.9))
    # side windows
    for y in (-2.5, 2.5):
        for s in (1, -1):
            B(S, (s * (W / 2 + 0.03), y, 2.2), (0.06, 0.9, 0.9), trim)
            B(S, (s * (W / 2 + 0.06), y, 2.2), (0.06, 0.72, 0.72), M("glass", (0.5, 0.65, 0.7), 0.1, emit=(0.4, 0.5, 0.5), emit_strength=0.3))
    # weathervane
    Cy(S, (0, 0, WH + 4.3), (0.05, 0.05, 1.0), M("metal", "metal", 0.4, 0.9))
    B(S, (0, 0, WH + 4.7), (0.08, 0.6, 0.25), M("metal"))
    # plank lines
    for i in range(-3, 4):
        B(S, (i * 1.1, D / 2 + 0.005, 1.4), (0.03, 0.02, 2.4), M("paint_dark", "barn_dk", 0.9))
    return S


def farmhouse():
    S = Static("world_farmhouse")
    wall, trim, roof = M("plaster", (0.93, 0.85, 0.68), 0.9), M("paint_white", "white", 0.8), M("roof_tile", "barn_dk", 0.7)
    wood, stone = M("wood", "wood", 0.85), M("stone", "stone", 0.9)
    W, D, WH = 6.0, 5.0, 2.8
    B(S, (0, 0, 0.15), (W + 0.3, D + 0.3, 0.3), stone)
    B(S, (0, 0, WH / 2 + 0.15), (W, D, WH), wall, bevel=0.02)
    S.add(poly_extrude([(-W / 2, 0), (0, 2.1), (W / 2, 0)], D, (0, 0, WH + 0.15), wall))
    S.add(roof_chevron(gable_pts(W / 2, 2.1, 0.45), 0.2, D + 1.0, (0, 0, WH + 0.17), roof))
    B(S, (0, 0, WH + 2.3), (0.3, D + 1.1, 0.14), roof)
    # chimney
    B(S, (1.8, -1.0, WH + 2.2), (0.7, 0.7, 2.4), stone)
    B(S, (1.8, -1.0, WH + 3.45), (0.85, 0.85, 0.12), M("stone"))
    # beams
    for x in (-W / 2, W / 2):
        B(S, (x, D / 2 + 0.02, WH / 2 + 0.15), (0.16, 0.08, WH), wood)
        B(S, (x, -D / 2 - 0.02, WH / 2 + 0.15), (0.16, 0.08, WH), wood)
    B(S, (0, D / 2 + 0.02, WH + 0.1), (W, 0.1, 0.16), wood)
    # door + porch
    B(S, (-1.2, D / 2 + 0.04, 1.2), (1.1, 0.08, 2.1), wood)
    B(S, (-0.95, D / 2 + 0.1, 1.15), (0.1, 0.1, 0.1), M("gold", "gold", 0.3, 0.9))
    B(S, (-1.2, D / 2 + 0.6, 0.2), (1.8, 1.0, 0.1), wood)
    for sx in (-2.0, -0.4):
        B(S, (sx, D / 2 + 1.0, 1.0), (0.1, 0.1, 1.8), wood)
    B(S, (-1.2, D / 2 + 0.6, 1.9), (2.0, 1.2, 0.08), roof, rot=(8, 0, 0))
    # windows with shutters + flower box
    for x in (1.2, 2.3):
        B(S, (x, D / 2 + 0.03, 1.7), (0.8, 0.06, 0.9), trim)
        B(S, (x, D / 2 + 0.06, 1.7), (0.64, 0.06, 0.74), M("glass", (0.5, 0.65, 0.7), 0.1, emit=(0.9, 0.75, 0.4), emit_strength=0.6))
        B(S, (x - 0.5, D / 2 + 0.05, 1.7), (0.22, 0.04, 0.9), M("shutter", "blue", 0.8))
        B(S, (x + 0.5, D / 2 + 0.05, 1.7), (0.22, 0.04, 0.9), M("shutter"))
        B(S, (x, D / 2 + 0.2, 1.15), (0.8, 0.22, 0.14), wood)
        for k in range(4):
            S.add(sphere((x - 0.28 + k * 0.19, D / 2 + 0.2, 1.3), (0.15, 0.15, 0.15), M("flower", ["red", "gold", "pink", "white"][k], 0.7)))
    for s in (1, -1):
        for y in (-1.2, 1.2):
            B(S, (s * (W / 2 + 0.03), y, 1.7), (0.06, 0.8, 0.9), trim)
            B(S, (s * (W / 2 + 0.06), y, 1.7), (0.06, 0.64, 0.74), M("glass"))
    return S


def silo():
    S = Static("world_silo")
    st = M("metal_silo", (0.62, 0.64, 0.66), 0.45, 0.7)
    Cy(S, (0, 0, 0.15), (3.5, 3.5, 0.3), M("stone", "stone", 0.9), verts=24)
    Cy(S, (0, 0, 4.2), (3.2, 3.2, 8.0), st, verts=28)
    S.add(sphere((0, 0, 8.2), (3.2, 3.2, 2.4), M("roof_dome", "barn_dk", 0.5, 0.3), seg=28))
    Cy(S, (0, 0, 9.5), (0.2, 0.2, 0.5), M("metal", "metal", 0.4, 0.9))
    for z in range(1, 8):
        S.add(torus((0, 0, z * 1.0), 1.6, 0.03, M("band", (0.35, 0.37, 0.4), 0.5, 0.8)))
    B(S, (0, 1.62, 0.9), (0.9, 0.1, 1.8), M("wood", "wood", 0.85))
    B(S, (0, 1.58, 4.0), (0.12, 0.1, 7.5), M("metal"))
    for z in range(1, 8):
        B(S, (0, 1.7, z * 1.0), (0.5, 0.08, 0.06), M("metal"))
    return S


def windmill():
    S = Static("world_windmill")
    wall, wood, roof = M("plaster", (0.9, 0.8, 0.6), 0.9), M("wood", "wood", 0.85), M("roof_tile", "barn_dk", 0.7)
    Cy(S, (0, 0, 0.2), (4.2, 4.2, 0.4), M("stone", "stone", 0.9), verts=24)
    Cy(S, (0, 0, 3.6), (3.2, 3.2, 6.8), wall, verts=24, r1=1.0, r2=0.62)
    S.add(cone((0, 0, 7.9), (2.6, 2.6, 2.0), roof, verts=24))
    B(S, (0, 1.55, 0.95), (0.9, 0.1, 1.7), wood)
    for z in (3.0, 5.0):
        B(S, (0, 1.25 - (z - 3) * 0.12, z), (0.5, 0.1, 0.6), M("glass", (0.5, 0.65, 0.7), 0.1))
    for k in range(6):
        S.add(torus((0, 0, 0.8 + k * 1.1), 1.55 - k * 0.1, 0.025, wood))
    # hub axle + blades (separate node, rotates around Y through the hub)
    hub = (0, 1.3, 7.0)
    Cy(S, (0, 0.95, 7.0), (0.3, 0.3, 1.0), M("metal", "metal", 0.4, 0.9), rot=(90, 0, 0), group="Blades")
    for i in range(4):
        a = i * 90
        Cy(S, (0, 1.5, 7.0), (0.1, 0.1, 5.4), wood, rot=(0, 0, 0), group="Blades").rotation_euler = (0, math.radians(0), 0)
    S.objs = [(o, g) for o, g in S.objs if g != "Blades"]
    for i in range(4):
        a = math.radians(i * 90)
        sp = bpy.data.objects.new("e", None)
        spar = cube((0, 1.5, 7.0), (0.12, 0.1, 5.6), wood, group_rot(a))
        cl = cube((0.0, 1.55, 7.0), (0.9, 0.05, 2.9), M("sail", (0.95, 0.92, 0.82), 0.95), group_rot(a))
        # shift the sail outward along the spar direction
        off = Vector((0.55 * math.cos(a + math.pi / 2) * 0 - 0, 0, 0))
        d = Vector((-math.sin(a), 0, math.cos(a)))
        cl.location = Vector((0.0, 1.55, 7.0)) + d * 1.6 + Vector((math.cos(a) * 0.5, 0, math.sin(a) * 0.5))
        S.add(spar, "Blades"); S.add(cl, "Blades")
    S.add(sphere((0, 1.5, 7.0), (0.5, 0.5, 0.5), M("metal")), "Blades")
    S.pivots["Blades"] = hub
    return S


def group_rot(a):
    return (0, math.degrees(a) * -1, 0)


def coop():
    S = Static("world_coop")
    wood, red, roof = M("wood", "wood_lt", 0.85), M("paint_red", "barn", 0.8), M("roof_tile", "barn_dk", 0.7)
    for x in (-0.9, 0.9):
        for y in (-0.8, 0.8):
            B(S, (x, y, 0.3), (0.12, 0.12, 0.6), M("wood_dk", "wood", 0.9))
    B(S, (0, 0, 0.65), (2.1, 1.9, 0.1), wood)
    B(S, (0, 0, 1.25), (2.0, 1.8, 1.1), red, bevel=0.02)
    S.add(poly_extrude([(-1.0, 0), (0, 0.8), (1.0, 0)], 1.8, (0, 0, 1.8), red))
    S.add(roof_chevron(gable_pts(1.0, 0.8, 0.25), 0.1, 2.2, (0, 0, 1.82), roof))
    B(S, (0, 0.92, 1.2), (0.5, 0.06, 0.55), M("dark", (0.08, 0.05, 0.04), 1))
    B(S, (0, 0.96, 1.2), (0.62, 0.04, 0.67), M("paint_white", "white", 0.8)).scale = (1, 1, 1)
    B(S, (0, 1.4, 0.45), (0.5, 1.0, 0.04), wood, rot=(-25, 0, 0))
    for k in range(5):
        B(S, (0, 1.2 + k * 0.1, 0.35 + k * -0.03), (0.4, 0.03, 0.03), M("wood_dk"))
    B(S, (0.95, 0, 1.3), (0.1, 0.5, 0.5), M("paint_white"))
    return S


def fence():
    S = Static("world_fence")
    wood = M("wood", "wood_lt", 0.85)
    for x in (-1.0, 1.0):
        B(S, (x, 0, 0.55), (0.14, 0.14, 1.1), wood, bevel=0.015)
        S.add(cone((x, 0, 1.13), (0.15, 0.15, 0.1), wood))
    for z in (0.4, 0.85):
        B(S, (0, 0, z), (2.1, 0.06, 0.14), wood, bevel=0.01)
    return S


def tree_oak():
    S = Static("world_tree_oak")
    bark, leaf, leaf2 = M("bark", (0.3, 0.2, 0.12), 0.95), M("leaf", "leaf", 0.8), M("leaf2", "leaf2", 0.8)
    Cy(S, (0, 0, 1.2), (0.7, 0.7, 2.4), bark, r1=1.3, r2=0.7, verts=10)
    for a in (0, 120, 240):
        r = math.radians(a)
        Cy(S, (math.cos(r) * 0.25, math.sin(r) * 0.25, 2.5), (0.25, 0.25, 1.4), bark, rot=(math.degrees(math.sin(r)) * 0.4, -math.degrees(math.cos(r)) * 0.4, 0), r1=1.0, r2=0.5, verts=8)
    random.seed(3)
    for i, (x, y, z, r) in enumerate(((0, 0, 4.2, 2.8), (1.4, 0.3, 3.5, 1.9), (-1.3, 0.5, 3.7, 2.0), (0.2, -1.3, 3.6, 1.9), (-0.3, 1.2, 4.9, 1.8), (0.9, -0.5, 5.2, 1.5))):
        S.add(ico((x, y, z), (r, r, r * 0.85), leaf if i % 2 == 0 else leaf2, sub=2))
    return S


def tree_apple():
    S = Static("world_tree_apple")
    bark, leaf, leaf2 = M("bark", (0.35, 0.22, 0.13), 0.95), M("leaf", "leaf", 0.8), M("leaf2", "leaf2", 0.8)
    Cy(S, (0, 0, 0.8), (0.4, 0.4, 1.6), bark, r1=1.3, r2=0.7, verts=10)
    for i, (x, y, z, r) in enumerate(((0, 0, 2.5, 2.2), (0.9, 0.2, 2.1, 1.5), (-0.9, 0.4, 2.2, 1.6), (0.1, -1.0, 2.2, 1.5), (-0.2, 0.7, 3.2, 1.4))):
        S.add(ico((x, y, z), (r, r, r * 0.85), leaf if i % 2 == 0 else leaf2, sub=2))
    random.seed(5)
    ap = M("apple", "red", 0.4)
    for i in range(14):
        a = random.uniform(0, 6.28); r = random.uniform(0.9, 1.5); z = random.uniform(1.7, 3.0)
        S.add(sphere((math.cos(a) * r, math.sin(a) * r, z), (0.2, 0.2, 0.19), ap, seg=10))
    return S


def haybale():
    S = Static("world_haybale")
    hay = M("hay", "hay", 0.95)
    Cy(S, (0, 0, 0.5), (1.0, 1.0, 1.2), hay, rot=(0, 90, 0), verts=20)
    for x in (-0.3, 0.3):
        S.add(torus((x, 0, 0.5), 0.5, 0.02, M("twine", "wood", 0.9), rot=(0, 90, 0)))
    random.seed(2)
    for i in range(18):
        a = random.uniform(0, 6.28); x = random.uniform(-0.6, 0.6)
        S.add(cone((x, math.sin(a) * 0.52, 0.5 + math.cos(a) * 0.52), (0.03, 0.03, 0.18), hay, rot=(math.degrees(a), random.uniform(-20, 20), 0), verts=4))
    return S


def crate():
    S = Static("world_crate")
    wood, dk = M("wood", "wood_lt", 0.85), M("wood_dk", "wood", 0.9)
    B(S, (0, 0, 0.5), (0.9, 0.9, 0.9), dk)
    for z in (0.14, 0.38, 0.62, 0.86):
        for s in (1, -1):
            B(S, (s * 0.46, 0, z), (0.04, 0.96, 0.2), wood)
            B(S, (0, s * 0.46, z), (0.96, 0.04, 0.2), wood)
    for sx in (1, -1):
        for sy in (1, -1):
            B(S, (sx * 0.45, sy * 0.45, 0.5), (0.1, 0.1, 1.0), dk)
    B(S, (0, 0, 0.96), (0.95, 0.95, 0.06), wood)
    return S


def well():
    S = Static("world_well")
    st, wood, roof = M("stone", "stone", 0.9), M("wood", "wood", 0.85), M("roof_tile", "barn_dk", 0.7)
    Cy(S, (0, 0, 0.5), (1.6, 1.6, 1.0), st, verts=16)
    Cy(S, (0, 0, 0.96), (1.1, 1.1, 0.12), M("water", "water", 0.1), verts=16)
    S.add(torus((0, 0, 1.0), 0.72, 0.1, st))
    for s in (1, -1):
        B(S, (s * 0.75, 0, 1.6), (0.12, 0.12, 1.5), wood)
    B(S, (0, 0, 2.3), (1.7, 0.12, 0.1), wood)
    S.add(roof_chevron(gable_pts(0.8, 0.55, 0.2), 0.08, 1.4, (0, 0, 2.4), roof))
    Cy(S, (0, 0, 2.05), (0.12, 0.12, 0.7), wood, rot=(0, 90, 0))
    Cy(S, (0, 0, 1.5), (0.3, 0.3, 0.3), wood, verts=12)
    Cy(S, (0, 0, 1.8), (0.015, 0.015, 0.5), M("rope", "wood_lt", 0.9), verts=6)
    return S


def pond_dock():
    S = Static("world_pond_dock")
    wood, dk = M("wood", "wood_lt", 0.85), M("wood_dk", "wood", 0.9)
    for i in range(14):
        B(S, (0, i * 0.3 - 2, 0.55), (1.6, 0.27, 0.08), wood if i % 2 else dk, rot=(0, 0, 0))
    for s in (1, -1):
        B(S, (s * 0.75, 0, 0.45), (0.1, 4.2, 0.1), dk)
        for y in (-2.0, 0.0, 2.0):
            Cy(S, (s * 0.75, y, 0.1), (0.16, 0.16, 1.0), dk, verts=8)
    Cy(S, (0.75, 2.1, 1.0), (0.1, 0.1, 0.5), dk, verts=8)
    S.add(torus((0.75, 2.1, 1.2), 0.08, 0.012, M("rope", "wood_lt", 0.9), rot=(90, 0, 0)))
    return S


def cheese_cave():
    S = Static("world_cheese_cave")
    rock, rock2 = M("rock", (0.45, 0.42, 0.38), 0.95), M("rock2", (0.55, 0.5, 0.44), 0.95)
    grass = M("grass_hill", (0.3, 0.5, 0.2), 0.95)
    dk = M("dark", (0.02, 0.015, 0.015), 1)
    rind = M("rind", "cheddar", 0.5)
    holes = M("cheese_hole", (0.75, 0.55, 0.15), 0.6)
    random.seed(9)
    # hill: big flattened dome, carved with a tunnel (boolean) so the mouth is a real opening
    hill = clip_ground(sphere((0, -3.2, 0.0), (12.0, 9.0, 11.0), rock, seg=32))
    bpy.context.view_layer.objects.active = hill
    tun = bpy.data.objects.new("tun", None)
    tb = cube((0, 2.9, 1.6), (3.0, 7.0, 3.2), dk)
    tc = cyl((0, 2.9, 3.2), (3.0, 3.0, 7.0), dk, rot=(-90, 0, 0), verts=24)
    tc.rotation_euler = (math.radians(90), 0, 0)
    face = cube((0, 0.3, 2.6), (8.0, 3.8, 5.2), rock2, bevel=0.3)
    for tgt in (hill, face):
        for t in (tb, tc):
            bpy.context.view_layer.objects.active = tgt
            bm_ = tgt.modifiers.new("bool", "BOOLEAN")
            bm_.operation, bm_.object, bm_.solver = "DIFFERENCE", t, "EXACT"
            bpy.ops.object.modifier_apply(modifier=bm_.name)
        for p_ in tgt.data.polygons:
            p_.use_smooth = tgt is hill
    for t in (tb, tc):
        bpy.data.objects.remove(t)
    S.add(face)
    S.add(hill)
    # grass-covered top and lumpy outcrops
    S.add(clip_ground(sphere((0, -4.6, 0.2), (11.6, 8.4, 11.2), grass, seg=28)))
    for i, (x, y, z, r) in enumerate(((-4.0, 0.2, 0.5, 1.6), (4.0, 0.1, 0.4, 1.7), (-2.2, -1.3, 4.6, 1.0), (2.3, -1.4, 4.4, 1.1), (-5.2, -2.0, 0.9, 1.5), (5.2, -2.0, 1.0, 1.6))):
        S.add(ico((x, y, z), (r * 1.1, r * 0.9, r * 0.9), rock if i % 2 else rock2, sub=2))
    # dark interior: back wall + floor so the opening reads black
    S.add(cube((0, -0.6, 1.6), (3.1, 0.3, 3.4), dk))
    S.add(cyl((0, -0.6, 3.2), (3.1, 3.1, 0.3), dk, rot=(90, 0, 0), verts=24))
    S.add(cube((0, 1.2, 0.03), (3.0, 3.6, 0.06), dk))
    # cheese-wheel arch framing the mouth: wedge blocks around a half circle + stacked wheel posts
    n = 9
    for i in range(n):
        a = math.pi * (i + 0.5) / n
        x, z = -math.cos(a) * 1.85, 3.2 + math.sin(a) * 1.85
        ang = math.degrees(a)
        S.add(cube((x, 2.3, z), (0.62, 0.9, 0.62), rind if i % 2 else M("rind2", (0.95, 0.72, 0.18), 0.5), rot=(0, -(ang - 90), 0), bevel=0.06))
        S.add(sphere((x, 2.78, z), (0.2, 0.1, 0.2), holes, seg=8))
    for sx in (1, -1):
        for k in range(4):
            S.add(cyl((sx * 1.85, 2.35, 0.35 + k * 0.78), (1.15, 1.15, 0.72), rind if k % 2 else M("rind2"), verts=20, rot=(0, 0, 0)))
            S.add(sphere((sx * 1.85 + 0.25, 2.89, 0.35 + k * 0.78), (0.22, 0.1, 0.22), holes, seg=8))
    # keystone wheel on top + lanterns + rot veins
    S.add(cyl((0, 2.45, 5.45), (1.1, 1.1, 0.4), M("rind"), rot=(90, 0, 0), verts=24))
    for sx in (1, -1):
        S.add(sphere((sx * 2.9, 2.85, 1.7), (0.3, 0.3, 0.35), M("lantern", "gold", 0.3, emit="gold", emit_strength=3)))
        B(S, (sx * 2.9, 2.85, 1.0), (0.1, 0.1, 1.3), M("wood", "wood", 0.85))
    for i in range(7):
        S.add(sphere((-2.4 + i * 0.8, 3.4 + (i % 2) * 0.3, 0.1), (0.35, 0.25, 0.14), M("rot_slime", "rot", 0.3, emit="rot_dk", emit_strength=0.5), seg=8))
    return S


def shrine():
    S = Static("world_shrine")
    st, dk = M("stone", "stone", 0.85), M("stone_dk", (0.35, 0.34, 0.33), 0.9)
    Cy(S, (0, 0, 0.1), (3.0, 3.0, 0.2), dk, verts=24)
    Cy(S, (0, 0, 0.35), (2.2, 2.2, 0.3), st, verts=24)
    Cy(S, (0, 0, 0.7), (1.0, 1.0, 0.5), st, verts=8)
    gl = M("cheese_glow", "cheddar", 0.3, emit="cheddar", emit_strength=3)
    S.add(cyl((0, 0, 1.2), (0.7, 0.7, 0.4), gl, verts=24))
    for s in (1, -1):
        B(S, (s * 1.0, -0.4, 1.4), (0.35, 0.35, 2.8), st, bevel=0.03)
        S.add(cone((s * 1.0, -0.4, 3.0), (0.4, 0.4, 0.5), st, verts=4, rot=(0, 0, 45)))   # cat ears
        S.add(sphere((s * 1.0, -0.4, 0.1), (0.5, 0.5, 0.2), dk))
    B(S, (0, -0.4, 2.6), (2.4, 0.3, 0.3), st, bevel=0.03)
    for s in (1, -1):
        for k in range(3):
            S.add(sphere((s * (0.5 + k * 0.15), 0.6 - k * 0.3, 0.5 + k * 0.0), (0.12, 0.12, 0.12), M("rune", "gold", 0.3, emit="gold", emit_strength=2), seg=6))
    return S


def cheese_shape(S, kind):
    ch = {"cheddar": ("cheddar", (0.98, 0.66, 0.12), (0.8, 0.5, 0.1)), "brie": ("brie", (0.97, 0.94, 0.82), (0.95, 0.9, 0.7)),
          "swiss": ("swiss", (0.98, 0.85, 0.35), (0.85, 0.65, 0.2)), "gouda": ("gouda", (0.95, 0.75, 0.25), (0.75, 0.2, 0.12)),
          "blue": ("blue", (0.88, 0.88, 0.82), (0.85, 0.85, 0.8)), "gorgonzola": ("blue", (0.88, 0.88, 0.82), (0.85, 0.85, 0.8)),
          "parmesan": ("parmesan", (0.9, 0.78, 0.45), (0.7, 0.55, 0.25)), "mozzarella": ("mozzarella", (0.97, 0.96, 0.9), (0.95, 0.94, 0.88)),
          "camembert": ("camembert", (0.96, 0.93, 0.8), (0.95, 0.92, 0.78)), "feta": ("feta", (0.98, 0.98, 0.94), (0.95, 0.95, 0.9))}
    n, inner, outer = ch[kind]
    cm, rm = M("cheese_" + n, inner, 0.45), M("rind_" + n, outer, 0.6)
    if kind in ("mozzarella",):
        S.add(sphere((0, 0, 0.2), (0.4, 0.4, 0.36), cm))
        return
    if kind == "feta":
        for i, (x, y, r) in enumerate(((-0.1, 0, 5), (0.12, 0.05, -8), (0.0, -0.15, 30))):
            B(S, (x, y, 0.1 + i * 0.001 if i == 0 else 0.1 + i * 0.12), (0.22, 0.22, 0.16), cm, rot=(0, 0, r), bevel=0.02)
        return
    if kind in ("camembert",):
        Cy(S, (0, 0, 0.06), (0.4, 0.4, 0.12), rm, verts=24)
        Cy(S, (0, 0, 0.125), (0.34, 0.34, 0.02), cm, verts=24)
        return
    h = 0.32 if kind in ("brie", "swiss", "blue", "gorgonzola") else 0.4
    r = 0.55 if kind != "gouda" else 0.45
    # wheel with a wedge cut out of the front-right quarter
    Cy(S, (0, 0, h / 2), (r * 2, r * 2, h), rm, verts=32).rotation_euler = (0, 0, 0)
    Cy(S, (0, 0, h / 2 + 0.01), (r * 1.9, r * 1.9, h * 0.97), cm, verts=32)
    # cut face: dark wedge notch
    prism_obj = prism(r, h * 0.99, r * 0.9, (r * 0.3, r * 0.45, 0.0), M("cut_" + n, tuple(c * 0.9 for c in inner), 0.5))
    S.add(prism_obj)
    random.seed(7)
    if kind == "swiss":
        for i in range(8):
            S.add(sphere((random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), h + 0.005), (0.12, 0.12, 0.03), M("hole", (0.7, 0.5, 0.15), 0.8)))
    if kind in ("blue", "gorgonzola"):
        for i in range(10):
            S.add(sphere((random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), h + 0.005), (0.12, 0.08, 0.03), M("rot_veins", "rot", 0.5, emit="rot_dk", emit_strength=0.6), seg=8))
    if kind == "gouda":
        S.add(torus((0, 0, h * 0.5), r, 0.04, M("wax", "red", 0.3)))
    if kind == "parmesan":
        for i in range(6):
            S.add(cone((math.cos(i) * r * 0.6, math.sin(i) * r * 0.6, h + 0.01), (0.03, 0.03, 0.02), rm, verts=4))


def cheese_model(kind):
    def f():
        S = Static("world_cheese_" + kind)
        cheese_shape(S, kind)
        return S
    return f


def wheel_cheese():
    S = Static("world_wheel_cheese")
    # the big Last Wheel: huge aged wheel on a stand with a mold bloom
    rm, cm = M("rind", (0.7, 0.45, 0.12), 0.6), M("cheese", "cheddar", 0.4)
    Cy(S, (0, 0, 0.9), (1.8, 1.8, 0.6), rm, verts=36)
    Cy(S, (0, 0, 1.0), (1.7, 1.7, 0.05), cm, verts=36)
    for i in range(7):
        a = i * 0.9
        S.add(sphere((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.22), (0.2, 0.2, 0.06), M("rot_slime", "rot", 0.3, emit="rot_dk", emit_strength=0.5), seg=8))
    for s in (1, -1):
        B(S, (s * 0.6, 0, 0.3), (0.2, 1.4, 0.6), M("wood", "wood", 0.85))
    B(S, (0, 0, 0.62), (1.7, 1.4, 0.05), M("wood"))
    S.add(prism(0.8, 0.55, 0.9, (0.45, 0.6, 0.62), M("cut", (0.95, 0.65, 0.2), 0.4)))
    return S


def cauldron():
    S = Static("world_cauldron")
    iron = M("iron", (0.12, 0.12, 0.14), 0.45, 0.9)
    S.add(sphere((0, 0, 0.75), (1.2, 1.2, 0.95), iron, seg=20))
    S.add(torus((0, 0, 1.18), 0.55, 0.06, iron))
    Cy(S, (0, 0, 1.15), (1.0, 1.0, 0.05), M("fondue", "cheddar", 0.15, emit="cheddar", emit_strength=1.5), verts=24)
    for i in range(3):
        a = math.radians(i * 120 + 30)
        Cy(S, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.3), (0.08, 0.08, 0.7), iron, rot=(math.degrees(math.sin(a)) * 0.35, -math.degrees(math.cos(a)) * 0.35, 0), verts=8)
        S.add(sphere((math.cos(a) * 0.52, math.sin(a) * 0.52, 0.04), (0.14, 0.14, 0.08), iron))
    S.add(torus((0, 0, 1.7), 0.5, 0.025, iron, rot=(90, 0, 0)).__class__ and sphere((0.55, 0, 1.0), (0.1, 0.1, 0.1), iron))
    for i, (x, y) in enumerate(((0.2, 0.1), (-0.2, -0.15), (0.0, 0.25))):
        S.add(sphere((x, y, 1.25 + i * 0.03), (0.2, 0.2, 0.12), M("bubble", "cream", 0.2, emit="cream", emit_strength=1.0), seg=8))
    # ladle
    Cy(S, (0.4, 0.2, 1.55), (0.05, 0.05, 1.0), M("wood", "wood", 0.8), rot=(25, 25, 0), verts=8)
    return S


def campfire():
    S = Static("world_campfire")
    st, log = M("stone", "stone", 0.9), M("log", (0.3, 0.18, 0.1), 0.95)
    random.seed(4)
    for i in range(9):
        a = i * 40 * math.pi / 180
        S.add(ico((math.cos(a) * 0.7, math.sin(a) * 0.7, 0.12), (0.34, 0.3, 0.24), st, sub=1))
    for i in range(5):
        a = i * 72
        Cy(S, (0, 0, 0.25), (0.14, 0.14, 0.95), log, rot=(70, 0, a), verts=8).location = (math.cos(math.radians(a)) * 0.0, math.sin(math.radians(a)) * 0.0, 0.2)
    fl = M("flame", "orange", 0.2, emit="orange", emit_strength=6)
    fl2 = M("flame2", "gold", 0.2, emit="gold", emit_strength=8)
    S.add(cone((0, 0, 0.6), (0.5, 0.5, 1.0), fl, verts=10))
    S.add(cone((0.12, 0.05, 0.5), (0.3, 0.3, 0.7), fl2, verts=8))
    S.add(cone((-0.15, -0.1, 0.45), (0.25, 0.25, 0.55), fl, verts=8))
    return S


def crops(kind):
    def f():
        S = Static("world_crop_" + kind)
        random.seed(8)
        soil = M("soil", (0.28, 0.18, 0.1), 1.0)
        S.add(cube((0, 0, 0.04), (1.4, 1.4, 0.08), soil))
        leaf = M("leaf", "leaf", 0.8)
        pos = [(-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4), (0, 0)]
        for (x, y) in pos:
            if kind == "corn":
                S.add(cyl((x, y, 0.9), (0.07, 0.07, 1.7), M("stalk", "leaf2", 0.8), verts=6))
                for k in range(4):
                    a = k * 90 + random.uniform(0, 40)
                    S.add(cube((x + math.cos(math.radians(a)) * 0.2, y + math.sin(math.radians(a)) * 0.2, 0.7 + k * 0.3), (0.34, 0.06, 0.02), leaf, rot=(0, -25, a)))
                S.add(sphere((x + 0.08, y, 1.05), (0.12, 0.12, 0.4), M("corn_cob", "hay", 0.5), rot=(0, 10, 0), seg=10))
                S.add(cone((x, y, 1.75), (0.1, 0.1, 0.3), M("tassel", "hay", 0.8), verts=5))
            elif kind == "wheat":
                for k in range(7):
                    ox, oy = random.uniform(-0.18, 0.18), random.uniform(-0.18, 0.18)
                    S.add(cyl((x + ox, y + oy, 0.45), (0.025, 0.025, 0.85), M("stalk_w", (0.8, 0.7, 0.3), 0.8), verts=4))
                    S.add(sphere((x + ox, y + oy, 0.95), (0.06, 0.06, 0.24), M("wheat_ear", "hay", 0.6), seg=6))
            else:
                S.add(cyl((x, y, 0.55), (0.03, 0.03, 1.1), M("stake", "wood", 0.9), verts=6))
                S.add(sphere((x, y, 0.4), (0.5, 0.5, 0.5), M("leaf2", "leaf2", 0.8), seg=8))
                for k in range(3):
                    a = random.uniform(0, 6.28)
                    S.add(sphere((x + math.cos(a) * 0.17, y + math.sin(a) * 0.17, 0.3 + k * 0.2), (0.2, 0.2, 0.2), M("tomato", "red", 0.35), seg=10))
        return S
    return f


def signpost():
    S = Static("world_signpost")
    wood, dk = M("wood", "wood_lt", 0.85), M("wood_dk", "wood", 0.9)
    B(S, (0, 0, 0.9), (0.14, 0.14, 1.8), dk, bevel=0.02)
    for i, (z, ang, dx) in enumerate(((1.6, -8, 0.4), (1.2, 6, -0.4))):
        B(S, (dx, 0.09, z), (1.2, 0.06, 0.3), wood, rot=(0, 0, ang))
        S.add(cone((dx + (0.6 if dx > 0 else -0.6), 0.09, z), (0.3, 0.06, 0.3), wood, rot=(90, 0, -90 if dx > 0 else 90), verts=3))
        for k in range(3):
            B(S, (dx - 0.3 + k * 0.3, 0.13, z), (0.18, 0.02, 0.05), M("ink", "black", 0.9))
    S.add(cone((0, 0, 1.85), (0.2, 0.2, 0.12), dk, verts=6))
    return S


def tractor():
    S = Static("world_tractor")
    red, dk, metal, tire = M("paint_red", (0.75, 0.1, 0.08), 0.35, 0.1), M("paint_dark", "barn_dk", 0.7), M("metal", "metal", 0.4, 0.9), M("tire", (0.07, 0.07, 0.08), 0.95)
    B(S, (0, 0.5, 0.95), (1.0, 1.7, 0.9), red, bevel=0.06)   # hood
    B(S, (0, 1.4, 0.8), (0.9, 0.2, 0.7), dk, bevel=0.03)    # grill
    for i in range(4):
        B(S, (-0.3 + i * 0.2, 1.51, 0.8), (0.06, 0.03, 0.55), metal)
    B(S, (0, -0.55, 1.0), (1.0, 0.9, 0.7), red, bevel=0.05)
    Cy(S, (0.3, 0.8, 1.75), (0.1, 0.1, 0.8), metal, verts=8)
    for sx in (1, -1):
        Cy(S, (sx * 0.8, -0.65, 0.7), (1.4, 1.4, 0.45), tire, rot=(0, 90, 0), verts=24)
        Cy(S, (sx * 0.8, -0.65, 0.7), (0.7, 0.7, 0.47), M("rim", "hay", 0.5), rot=(0, 90, 0), verts=16)
        Cy(S, (sx * 0.78, 1.0, 0.42), (0.85, 0.85, 0.3), tire, rot=(0, 90, 0), verts=20)
        Cy(S, (sx * 0.78, 1.0, 0.42), (0.4, 0.4, 0.32), M("rim"), rot=(0, 90, 0), verts=12)
    Cy(S, (0, 1.0, 0.42), (0.1, 0.1, 1.6), metal, rot=(0, 90, 0), verts=8)
    B(S, (0, -0.6, 1.5), (0.9, 0.04, 0.04), metal)
    for sx in (1, -1):
        Cy(S, (sx * 0.42, -0.65, 1.55), (0.06, 0.06, 1.0), metal, verts=6)
    B(S, (0, -0.65, 2.1), (1.0, 1.0, 0.07), red)
    B(S, (0, -0.6, 1.4), (0.5, 0.45, 0.1), dk)    # seat
    Cy(S, (0, -0.25, 1.35), (0.25, 0.25, 0.04), dk, rot=(20, 0, 0), verts=16)
    S.add(sphere((0.3, 1.5, 0.95), (0.2, 0.1, 0.2), M("lamp", "gold", 0.2, emit="gold", emit_strength=2)))
    S.add(sphere((-0.3, 1.5, 0.95), (0.2, 0.1, 0.2), M("lamp")))
    return S


ALL = dict(barn=barn, farmhouse=farmhouse, silo=silo, windmill=windmill, coop=coop, fence=fence, tree_oak=tree_oak, tree_apple=tree_apple,
           haybale=haybale, crate=crate, well=well, pond_dock=pond_dock, cheese_cave=cheese_cave, shrine=shrine, wheel_cheese=wheel_cheese,
           cauldron=cauldron, campfire=campfire, crop_corn=crops("corn"), crop_wheat=crops("wheat"), crop_tomato=crops("tomato"),
           signpost=signpost, tractor=tractor)
for k in ("cheddar", "brie", "swiss", "gouda", "blue", "gorgonzola", "parmesan", "mozzarella", "camembert", "feta"):
    ALL["cheese_" + k] = cheese_model(k)

for k, fn in ALL.items():
    if ONLY and k not in ONLY:
        continue
    try:
        finish(fn(), yaw=35, pitch=24)
    except Exception as e:
        import traceback
        traceback.print_exc()
        print("FAIL", k, e)
        reset(); clear_mats()
