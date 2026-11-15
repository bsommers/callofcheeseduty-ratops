"""party_lib — shared builder for CHEESE FANTASY party heroes + Nine Lives summons.

Used by tools/blender/party_<id>.py (run: blender -b -P tools/blender/party_<id>.py).
Pipeline (deterministic, text-only source):
  skeleton (named bones) -> metaball/primitive parts per material -> decimate -> join per material
  -> smart UV -> Python raster texture painter (pattern fn(P, N) + noise + ray AO) -> PBR materials
  -> distance-falloff skin weights (rigid parts pinned to one bone) -> procedural clips as actions
  -> GLB (Y-up, metres, character faces Blender +Y == glTF -Z, origin at feet) -> Cycles previews.
"""
import bpy, bmesh, math, os, sys, time
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree

V = Vector
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(REPO, "game", "assets", "models")
PREV_ROOT = os.path.join(REPO, "out", "previews")
FPS = 30
MB_K = 0.575  # metaball surface radius / element radius (stiffness 2, threshold 0.6) — from hero.py
T0 = time.time()


def log(*a):
    print("[party %5.1fs]" % (time.time() - T0), *a, flush=True)


def lin2srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# --------------------------------------------------------------------------- noise (numpy, deterministic)
def _hash(ix, iy, iz, seed):
    h = np.sin(ix * 127.1 + iy * 311.7 + iz * 74.7 + seed * 19.19) * 43758.5453
    return h - np.floor(h)


def vnoise(P, scale=1.0, seed=0):
    p = P * scale
    i = np.floor(p); f = p - i
    f = f * f * (3 - 2 * f)
    x, y, z = i[:, 0], i[:, 1], i[:, 2]
    fx, fy, fz = f[:, 0], f[:, 1], f[:, 2]
    out = 0.0
    for dx in (0, 1):
        wx = fx if dx else 1 - fx
        for dy in (0, 1):
            wy = fy if dy else 1 - fy
            for dz in (0, 1):
                wz = fz if dz else 1 - fz
                out = out + wx * wy * wz * _hash(x + dx, y + dy, z + dz, seed)
    return out


def fbm(P, scale=1.0, octaves=4, seed=0):
    tot, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        tot = tot + amp * vnoise(P, scale * (2.03 ** o), seed + o * 7)
        norm += amp; amp *= 0.5
    return tot / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mixc(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


def fur_detail(P, base, scale_m=1.0, strength=0.12, seed=3):
    """Fine strand-like variation: anisotropic noise (vertical streaks) multiplies the base colour."""
    Q = P / scale_m
    s1 = vnoise(Q * np.array([90.0, 90.0, 22.0]), 1.0, seed)
    s2 = fbm(Q, 9.0, 3, seed + 11)
    k = 1.0 + strength * ((s1 - 0.5) * 1.2 + (s2 - 0.5) * 0.8)
    return base * k[:, None]


# --------------------------------------------------------------------------- scene helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.unit_settings.system = "METRIC"; sc.unit_settings.scale_length = 1.0
    return sc


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def set_active(ob):
    bpy.context.view_layer.update()
    for o in list(bpy.context.view_layer.objects):
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def bm_to_obj(bm, name, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob["_mat"] = mat
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def nrm(v):
    v = V(v); return v.normalized() if v.length > 1e-9 else V((0, 0, 1))


def frame_from(z_axis):
    """Matrix whose local +Z points along z_axis."""
    z = nrm(z_axis)
    x = V((1, 0, 0)) if abs(z.x) < 0.9 else V((0, 1, 0))
    y = z.cross(x).normalized(); x = y.cross(z).normalized()
    return Matrix((x, y, z)).transposed()


# --------------------------------------------------------------------------- primitive mesh builders
def _xform(bm, loc=(0, 0, 0), rot=None, scale=(1, 1, 1)):
    M = Matrix.Translation(V(loc))
    if rot is not None:
        if isinstance(rot, Matrix):
            M = M @ rot.to_4x4()
        elif isinstance(rot, Quaternion):
            M = M @ rot.to_matrix().to_4x4()
        else:
            M = M @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    M = M @ Matrix.Diagonal(V(scale)).to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)


def sphere(name, mat, loc, r, scale=(1, 1, 1), rot=None, seg=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    _xform(bm, loc, rot, scale)
    return bm_to_obj(bm, name, mat)


def cone(name, mat, loc, r1, r2, depth, rot=None, seg=12, scale=(1, 1, 1), cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)
    bmesh.ops.translate(bm, vec=V((0, 0, depth / 2)), verts=bm.verts)  # base at origin, tip +Z
    _xform(bm, loc, rot, scale)
    return bm_to_obj(bm, name, mat)


def box(name, mat, loc, size, rot=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    _xform(bm, (0, 0, 0), None, size)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES", profile=0.5)
    _xform(bm, loc, rot)
    return bm_to_obj(bm, name, mat)


def lathe(name, mat, profile, loc=(0, 0, 0), rot=None, seg=24, scale=(1, 1, 1)):
    """profile: list of (radius, z) from bottom to top. Caps closed when radius==0 at ends."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        if r <= 1e-6:
            ring = [bm.verts.new((0, 0, z))]
        else:
            for i in range(seg):
                a = 2 * math.pi * i / seg
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(seg):
                bm.faces.new((a[0], b[i], b[(i + 1) % seg]))
        elif len(b) == 1:
            for i in range(seg):
                bm.faces.new((a[i], b[0], a[(i + 1) % seg]))
        else:
            for i in range(seg):
                bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _xform(bm, loc, rot, scale)
    return bm_to_obj(bm, name, mat)


def tube(name, mat, pts, radii, sides=8, cap=True, flat=1.0, twist_up=None):
    """Swept tube through pts with per-point radius (radius 0 at an end = pointed tip). flat scales the
    cross-section along the frame's second axis (ribbons, ears, tendrils)."""
    pts = [V(p) for p in pts]
    n = len(pts)
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * n
    bm = bmesh.new()
    rings = []
    up0 = V(twist_up) if twist_up else None
    prev_x = None
    for i, p in enumerate(pts):
        t = nrm((pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]))
        if prev_x is None:
            ref = up0 if up0 is not None else (V((0, 0, 1)) if abs(t.z) < 0.9 else V((1, 0, 0)))
            x = nrm(ref.cross(t))
        else:
            x = nrm(prev_x - t * prev_x.dot(t))
        y = t.cross(x)
        prev_x = x
        r = radii[i]
        if r <= 1e-6:
            rings.append([bm.verts.new(p)])
            continue
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + x * (math.cos(a) * r) + y * (math.sin(a) * r * flat)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        if len(a) == 1:
            for k in range(sides):
                bm.faces.new((a[0], b[(k + 1) % sides], b[k]))
        elif len(b) == 1:
            for k in range(sides):
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
        else:
            for k in range(sides):
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if cap and len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if cap and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_to_obj(bm, name, mat)


def torus(name, mat, loc, R, r, rot=None, seg=32, sides=10, scale=(1, 1, 1)):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        ring = []
        for k in range(sides):
            b = 2 * math.pi * k / sides
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * c, rr * s, r * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for k in range(sides):
            bm.faces.new((a[k], b[k], b[(k + 1) % sides], a[(k + 1) % sides]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _xform(bm, loc, rot, scale)
    return bm_to_obj(bm, name, mat)


def bezier_pts(ctrl, n):
    """Catmull-Rom through control points -> n points."""
    c = [V(p) for p in ctrl]
    c = [c[0] + (c[0] - c[1])] + c + [c[-1] + (c[-1] - c[-2])]
    out = []
    segs = len(c) - 3
    for i in range(n):
        u = i / (n - 1) * segs
        k = min(int(u), segs - 1); t = u - k
        p0, p1, p2, p3 = c[k], c[k + 1], c[k + 2], c[k + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return out


# --------------------------------------------------------------------------- metaball groups
class MB:
    def __init__(self, name, mat, res):
        self.data = bpy.data.metaballs.new("MB_" + name)
        self.data.resolution = res; self.data.render_resolution = res; self.data.threshold = 0.6
        self.ob = link(bpy.data.objects.new("MB_" + name, self.data))  # distinct family per group
        self.mat = mat
        self.name = name

    def ball(self, c, r, neg=False, stiff=2.0):
        e = self.data.elements.new(type="BALL"); e.co = V(c); e.radius = r / MB_K; e.stiffness = stiff
        e.use_negative = neg
        return e

    def ellip(self, c, sx, sy, sz, rot=None, stiff=2.0, neg=False):
        r = max(sx, sy, sz)
        e = self.data.elements.new(type="ELLIPSOID"); e.co = V(c); e.radius = r / MB_K; e.stiffness = stiff
        e.size_x, e.size_y, e.size_z = sx / r, sy / r, sz / r
        e.use_negative = neg
        if rot is not None:
            e.rotation = rot if isinstance(rot, Quaternion) else Euler([math.radians(a) for a in rot], "XYZ").to_quaternion()
        return e

    def sweep(self, a, b, ra, rb, step=0.4):
        a, b = V(a), V(b)
        L = (b - a).length
        n = max(2, int(math.ceil(L / (step * min(ra, rb)))) + 1)
        for i in range(n):
            t = i / (n - 1)
            self.ball(a.lerp(b, t), ra + (rb - ra) * t)

    def path(self, pts, radii, step=0.4):
        for i in range(len(pts) - 1):
            self.sweep(pts[i], pts[i + 1], radii[i], radii[i + 1], step)

    def to_mesh(self):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.ob.evaluated_get(dg))
        ob = link(bpy.data.objects.new("P_" + self.name, me))
        ob["_mat"] = self.mat
        bpy.data.objects.remove(self.ob)
        return ob


# --------------------------------------------------------------------------- the builder
class Builder:
    def __init__(self, cid, kind="biped"):
        self.sc = reset()
        self.cid = cid
        self.kind = kind
        self.J = {}           # bone -> (head, tail, parent, deform)
        self.mbs = []         # MB groups
        self.parts = []       # (obj, mat, rigid_bone or None)
        self.mats = {}        # name -> spec
        self.allow = {}       # mat -> list of bone-name prefixes allowed for soft weights
        self.prev = os.path.join(PREV_ROOT, "party_" + cid)
        os.makedirs(self.prev, exist_ok=True); os.makedirs(MODELS, exist_ok=True)
        self.ACT = {}
        self.extra_render = []

    # ---- skeleton
    def bone(self, n, h, t, parent=None, deform=True):
        self.J[n] = (V(h), V(t), parent, deform)

    def mirror_bones(self):
        for n in list(self.J):
            if n.endswith(".R"):
                h, t, p, d = self.J[n]
                m = lambda v: V((-v.x, v.y, v.z))
                self.J[n[:-2] + ".L"] = (m(h), m(t), (p[:-2] + ".L") if p and p.endswith(".R") else p, d)

    # ---- materials
    def material(self, name, fn, rough=0.6, metal=0.0, res=1024, emit_fn=None, emit_strength=1.0,
                 alpha=1.0, ao=0.6, unlit_ao=False, cull=True):
        self.mats[name] = dict(fn=fn, rough=rough, metal=metal, res=res, emit_fn=emit_fn,
                               emit_strength=emit_strength, alpha=alpha, ao=ao, cull=cull)

    def mb(self, name, mat, res):
        g = MB(name, mat, res); self.mbs.append(g); return g

    def add(self, ob, bone=None):
        """Register a primitive part. bone=None -> soft-skinned; else rigidly bound to that bone."""
        self.parts.append((ob, ob["_mat"], bone))
        return ob

    # ---- build steps
    def _armature(self):
        ad = bpy.data.armatures.new("Armature")
        arm = link(bpy.data.objects.new("Armature", ad))
        set_active(arm)
        bpy.ops.object.mode_set(mode="EDIT")
        order = []

        def visit(n):
            if n in order:
                return
            p = self.J[n][2]
            if p:
                visit(p)
            order.append(n)
        for n in self.J:
            visit(n)
        for n in order:
            h, t, p, d = self.J[n]
            eb = ad.edit_bones.new(n)
            eb.head, eb.tail = h, t
            dirv = nrm(t - h)
            eb.align_roll(V((0, 1, 0)) if abs(dirv.y) < 0.8 else V((0, 0, 1)))
            if p:
                eb.parent = ad.edit_bones[p]
                eb.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        for b in ad.bones:
            b.use_deform = self.J[b.name][3]
        self.arm = arm
        self.REST = {b.name: b.matrix_local.to_3x3().to_quaternion() for b in ad.bones}
        log("armature bones", len(ad.bones))

    def _collect(self, budget):
        objs = []
        for g in self.mbs:
            ob = g.to_mesh()
            objs.append((ob, g.mat, None))
        objs += self.parts
        # tag rigid parts with a vertex group, then join per material
        per = {}
        for ob, mat, bone in objs:
            if bone:
                vg = ob.vertex_groups.new(name="__rigid__" + bone)
                vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
            per.setdefault(mat, []).append(ob)
        # decimate metaball meshes so the total fits the budget
        mbtot = sum(tri_count(o) for o, m, b in objs if b is None and o.name.startswith("P_"))
        rest = sum(tri_count(o) for o, m, b in objs if not o.name.startswith("P_"))
        room = max(4000, budget - rest)
        if mbtot > room:
            ratio = room / mbtot
            for o, m, b in objs:
                if o.name.startswith("P_"):
                    dm = o.modifiers.new("dec", "DECIMATE"); dm.ratio = ratio
                    set_active(o); bpy.ops.object.modifier_apply(modifier="dec")
        self.objs = {}
        for mat, lst in per.items():
            set_active(lst[0])
            for o in lst:
                o.select_set(True)
            bpy.context.view_layer.objects.active = lst[0]
            if len(lst) > 1:
                bpy.ops.object.join()
            ob = bpy.context.view_layer.objects.active
            ob.name = "%s_%s" % (self.cid, mat); ob.data.name = ob.name
            for p in ob.data.polygons:
                p.use_smooth = True
            # weld coincident verts from metaball seams
            bm = bmesh.new(); bm.from_mesh(ob.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
            bm.to_mesh(ob.data); bm.free()
            self.objs[mat] = ob
        self.tris = {m: tri_count(o) for m, o in self.objs.items()}
        log("tris", sum(self.tris.values()), self.tris)

    def _uv(self, ob):
        set_active(ob)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")

    def _vertex_ao(self, ob, bvh, rays=20, dist=None):
        me = ob.data
        nv = len(me.vertices)
        co = np.empty(nv * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
        no = np.empty(nv * 3); me.vertices.foreach_get("normal", no); no = no.reshape(-1, 3)
        H = self.height
        dist = dist or H * 0.18
        rng = np.random.default_rng(7)
        dirs = rng.normal(size=(rays, 3)); dirs /= np.linalg.norm(dirs, axis=1)[:, None]
        ao = np.zeros(nv)
        for i in range(nv):
            n = no[i]; p = V(co[i] + n * H * 0.004)
            occ = 0.0; tot = 0.0
            for d in dirs:
                c = float(np.dot(d, n))
                if c < 0:
                    d = -d; c = -c
                hit = bvh.ray_cast(p, V(d), dist)
                tot += c
                if hit[0] is not None:
                    occ += c * (1.0 - hit[3] / dist)
            ao[i] = 1.0 - occ / max(tot, 1e-6)
        return ao

    def _paint(self, ob, spec, bvh):
        me = ob.data
        me.calc_loop_triangles()
        nt = len(me.loop_triangles)
        tl = np.empty(nt * 3, dtype=np.int64); me.loop_triangles.foreach_get("loops", tl); tl = tl.reshape(-1, 3)
        tv = np.empty(nt * 3, dtype=np.int64); me.loop_triangles.foreach_get("vertices", tv); tv = tv.reshape(-1, 3)
        uv = np.empty(len(me.loops) * 2); me.uv_layers.active.data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
        nv = len(me.vertices)
        co = np.empty(nv * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
        no = np.empty(nv * 3); me.vertices.foreach_get("normal", no); no = no.reshape(-1, 3)
        ao = self._vertex_ao(ob, bvh) if spec["ao"] > 0 else np.ones(nv)
        R = spec["res"]
        if spec.get("auto_res", True):
            area = sum(p.area for p in me.polygons)
            R = int(min(R, max(128, 2 ** round(math.log2(max(1.0, math.sqrt(area) * 1400))))))
        T = uv[tl] * R - 0.5  # (nt,3,2) in pixel coords (pixel centres at integers)
        pix, bary, tri = [], [], []
        for k in range(nt):
            t = T[k]
            x0, y0 = np.floor(t.min(0)).astype(int); x1, y1 = np.ceil(t.max(0)).astype(int)
            x0 = max(x0 - 1, 0); y0 = max(y0 - 1, 0); x1 = min(x1 + 1, R - 1); y1 = min(y1 + 1, R - 1)
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            xs = xs.ravel(); ys = ys.ravel()
            a, b, c = t
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-12:
                continue
            l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
            l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
            l3 = 1 - l1 - l2
            eps = -0.6 / max(1.0, abs(d) ** 0.5)  # conservative: include edge texels
            m = (l1 >= eps) & (l2 >= eps) & (l3 >= eps)
            if not m.any():
                continue
            pix.append(ys[m] * R + xs[m])
            bary.append(np.clip(np.stack([l1[m], l2[m], l3[m]], 1), 0, 1))
            tri.append(np.full(m.sum(), k))
        pix = np.concatenate(pix); bary = np.concatenate(bary); tri = np.concatenate(tri)
        bary /= bary.sum(1, keepdims=True)
        vids = tv[tri]
        P = (co[vids] * bary[:, :, None]).sum(1)
        N = (no[vids] * bary[:, :, None]).sum(1); N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-9
        A = (ao[vids] * bary).sum(1)

        def raster(vals, ch):
            img = np.zeros((R * R, ch)); cnt = np.zeros(R * R)
            np.add.at(img, pix, vals); np.add.at(cnt, pix, 1)
            filled = cnt > 0
            img[filled] /= cnt[filled][:, None]
            img = img.reshape(R, R, ch); filled = filled.reshape(R, R)
            for _ in range(8):  # dilate into gutters
                acc = np.zeros_like(img); n = np.zeros((R, R))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    acc += np.roll(np.roll(img * filled[..., None], dy, 0), dx, 1)
                    n += np.roll(np.roll(filled, dy, 0), dx, 1)
                new = (~filled) & (n > 0)
                img[new] = acc[new] / n[new][:, None]
                filled = filled | new
            return img

        col = np.asarray(spec["fn"](P, N), dtype=np.float64)
        aok = 1.0 - spec["ao"] * (1.0 - A)
        col = col * aok[:, None]
        albedo = raster(np.clip(col, 0, 1), 3)
        emis = None
        if spec["emit_fn"] is not None:
            emis = raster(np.clip(np.asarray(spec["emit_fn"](P, N), dtype=np.float64), 0, 1), 3)
        return albedo, emis

    def _image(self, name, arr):
        R = arr.shape[0]
        img = bpy.data.images.new(name, R, R, alpha=True)
        rgba = np.ones((R, R, 4)); rgba[..., :3] = arr
        img.pixels.foreach_set(rgba.astype(np.float32).ravel())
        img.filepath_raw = os.path.join(self.prev, "tex", name + ".png")
        os.makedirs(os.path.dirname(img.filepath_raw), exist_ok=True)
        img.file_format = "PNG"; img.save()
        img.pack()
        return img

    def _material(self, mname, spec, albedo, emis):
        m = bpy.data.materials.new(mname)
        m.use_nodes = True
        nt = m.node_tree; nodes = nt.nodes
        bs = nodes.get("Principled BSDF")
        tx = nodes.new("ShaderNodeTexImage"); tx.image = self._image("%s_%s_albedo" % (self.cid, mname), albedo)
        tx.location = (-400, 200)
        nt.links.new(tx.outputs[0], bs.inputs["Base Color"])
        bs.inputs["Roughness"].default_value = spec["rough"]
        bs.inputs["Metallic"].default_value = spec["metal"]
        if emis is not None:
            te = nodes.new("ShaderNodeTexImage"); te.image = self._image("%s_%s_emit" % (self.cid, mname), emis)
            te.location = (-400, -200)
            nt.links.new(te.outputs[0], bs.inputs["Emission Color"])
            bs.inputs["Emission Strength"].default_value = spec["emit_strength"]
        if spec["alpha"] < 1.0:
            bs.inputs["Alpha"].default_value = spec["alpha"]
            for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
                try:
                    setattr(m, attr, val)
                except Exception:
                    pass
        m.use_backface_culling = spec["cull"]
        return m

    def _weights(self, ob, mat):
        me = ob.data
        nv = len(me.vertices)
        co = np.empty(nv * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
        rigid = np.full(nv, -1)
        rnames = []
        for vg in list(ob.vertex_groups):
            if vg.name.startswith("__rigid__"):
                rnames.append(vg.name[9:])
                idx = len(rnames) - 1
                for v in me.vertices:
                    for g in v.groups:
                        if g.group == vg.index and g.weight > 0.5:
                            rigid[v.index] = idx
                ob.vertex_groups.remove(vg)
        allow = self.allow.get(mat)
        dbones = [n for n, j in self.J.items() if j[3] and (allow is None or any(n.startswith(a) for a in allow))]
        H = np.array([self.J[n][0] for n in dbones]); T = np.array([self.J[n][1] for n in dbones])
        D = np.empty((nv, len(dbones)))
        for k in range(len(dbones)):
            ab = T[k] - H[k]
            t = np.clip(((co - H[k]) @ ab) / max(ab @ ab, 1e-12), 0, 1)
            D[:, k] = np.linalg.norm(co - (H[k] + t[:, None] * ab), axis=1)
        sigma = self.height * 0.022
        groups = {n: ob.vertex_groups.new(name=n) for n in set(dbones) | set(rnames)}
        for i in range(nv):
            if rigid[i] >= 0:
                groups[rnames[rigid[i]]].add([i], 1.0, "REPLACE"); continue
            d = D[i]
            order = np.argsort(d)[:3]
            w = np.exp(-(d[order] - d[order[0]]) / sigma)
            w = w[w > 0.02 * w[0]] if len(w) else w
            w = w / w.sum()
            for k, ww in zip(order, w):
                groups[dbones[k]].add([i], float(ww), "REPLACE")
        mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = self.arm
        ob.parent = self.arm

    # ---- animation
    def q_char(self, bone, rx=0.0, ry=0.0, rz=0.0):
        R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_quaternion()
        M = self.REST[bone]
        return M.inverted() @ R @ M

    def clips(self, CLIPS):
        """CLIPS: list of (name, fn(t)->dict, length_s, loop). fn returns {bone: (rx,ry,rz)} in character
        axes (X right, Y forward, Z up; degrees) plus optional '@loc': (x,y,z) and '@scale': s for Root."""
        arm = self.arm
        arm.animation_data_create()
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        Mroot = self.REST["Root"]
        for name, fn, length, loop in CLIPS:
            act = bpy.data.actions.new(name); act.use_fake_user = True
            arm.animation_data.action = act
            nfr = max(2, int(round(length * FPS)))
            prev = {}
            for fr in range(nfr + 1):
                t = fr / FPS
                if loop and fr == nfr:
                    t = 0.0
                pose = fn(t)
                for pb in arm.pose.bones:
                    r = pose.get(pb.name, (0, 0, 0))
                    q = self.q_char(pb.name, *r)
                    if pb.name in prev:
                        q.make_compatible(prev[pb.name])
                    prev[pb.name] = q
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("rotation_quaternion", frame=fr, group=pb.name)
                rp = arm.pose.bones["Root"]
                loc = V(pose.get("@loc", (0, 0, 0)))
                rp.location = Mroot.inverted() @ loc
                rp.keyframe_insert("location", frame=fr, group="Root")
                s = pose.get("@scale", 1.0)
                rp.scale = (s, s, s)
                rp.keyframe_insert("scale", frame=fr, group="Root")
            act.use_frame_range = True
            act.frame_start, act.frame_end = 0, nfr
            act.use_cyclic = loop
            self.ACT[name] = act
            tr = arm.animation_data.nla_tracks.new(); tr.name = name
            tr.strips.new(name, 0, act); tr.mute = True
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = Quaternion(); pb.location = V((0, 0, 0)); pb.scale = V((1, 1, 1))
        log("clips", list(self.ACT))

    def pose(self, name, t):
        act = self.ACT[name]
        self.arm.animation_data.action = act
        if hasattr(self.arm.animation_data, "action_slot") and len(getattr(act, "slots", [])):
            self.arm.animation_data.action_slot = act.slots[0]
        self.sc.frame_set(int(round(t * FPS)))

    # ---- main
    def build(self, height, budget=29000):
        self.height = height
        self._armature()
        self._collect(budget)
        # BVH of everything for AO (rest pose)
        verts, polys, off = [], [], 0
        for ob in self.objs.values():
            me = ob.data
            verts += [tuple(v.co) for v in me.vertices]
            polys += [tuple(i + off for i in p.vertices) for p in me.polygons]
            off += len(me.vertices)
        bvh = BVHTree.FromPolygons(verts, polys)
        for mat, ob in self.objs.items():
            spec = self.mats[mat]
            self._uv(ob)
            alb, emi = self._paint(ob, spec, bvh)
            ob.data.materials.clear(); ob.data.materials.append(self._material(mat, spec, alb, emi))
            self._weights(ob, mat)
            log("material", mat, "done")

    def export(self):
        sc = self.sc
        glb = os.path.join(MODELS, self.cid + ".glb")
        props = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
        kw = dict(filepath=glb, export_format="GLB", use_selection=False, export_yup=True, export_apply=False,
                  export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                  export_frame_range=False, export_skins=True, export_morph=False, export_texcoords=True,
                  export_normals=True, export_tangents=False, export_vertex_color="NONE",
                  export_image_format="AUTO", export_extras=False, export_cameras=False, export_lights=False,
                  export_optimize_animation_size=False, export_anim_single_armature=True,
                  export_reset_pose_bones=True, export_def_bones=False, export_rest_position_armature=True,
                  export_nla_strips=False)
        kw = {k: v for k, v in kw.items() if k == "filepath" or k in props}
        for o in self.extra_render:
            o.hide_render = True
            bpy.data.objects.remove(o)
        self.extra_render = []
        set_active(self.arm)
        bpy.ops.export_scene.gltf(**kw)
        log("exported", glb, os.path.getsize(glb) // 1024, "KB tris", sum(self.tris.values()))

    # ---- previews
    def previews(self, poses, frame_h=None, look_z=None, samples=None, bg=(0.30, 0.33, 0.38), dark=False):
        sc = self.sc
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = int(samples or os.environ.get("PARTY_SAMPLES", "32"))
        sc.cycles.use_denoising = True
        sc.render.resolution_x, sc.render.resolution_y = 520, 640
        try:
            sc.view_settings.view_transform = "AgX"
        except Exception:
            sc.view_settings.view_transform = "Filmic"
        sc.view_settings.look = "None"
        sc.view_settings.exposure = -0.8 if dark else 0.0
        for lk in ("AgX - Medium High Contrast", "AgX - Punchy"):
            try:
                sc.view_settings.look = lk; break
            except Exception:
                pass
        w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.45 if dark else 0.7
        H = self.height
        fl = sphere("floor", "floor", (0, 0, 0), 1.0, scale=(H * 4, H * 4, 0.001), seg=24, rings=6)
        fm = bpy.data.materials.new("floor"); fm.use_nodes = True
        fb = fm.node_tree.nodes["Principled BSDF"]
        fb.inputs["Base Color"].default_value = (0.20, 0.25, 0.14, 1) if not dark else (0.06, 0.06, 0.09, 1)
        fb.inputs["Roughness"].default_value = 0.9
        fl.data.materials.append(fm)
        self.extra_render.append(fl)
        for nm, loc, en, sz, col in (("key", (2.2, 3.0, 3.4), 1100, 2.0, (1.0, 0.93, 0.82)),
                                     ("fill", (-3.2, 1.8, 1.8), 320, 3.0, (0.78, 0.86, 1.0)),
                                     ("rim", (0.6, -3.6, 3.2), 900, 1.6, (1.0, 0.96, 0.9))):
            ld = bpy.data.lights.new(nm, "AREA"); ld.energy = en * (H / 1.3) ** 2; ld.size = sz * H / 1.3
            ld.color = col
            lo = link(bpy.data.objects.new(nm, ld)); lo.location = V(loc) * (H / 1.3)
            lo.rotation_euler = (V((0, 0, H * 0.5)) - lo.location).to_track_quat("-Z", "Y").to_euler()
        cd = bpy.data.cameras.new("cam"); cd.lens = 50
        cam = link(bpy.data.objects.new("cam", cd)); sc.camera = cam
        fh = frame_h or H * 1.25
        tz = look_z if look_z is not None else H * 0.5
        dist = fh / (36.0 / 50.0) * 1.05 * (640 / 520) * 0.62 + H * 0.2
        tmp = os.path.join(self.prev, "tiles"); os.makedirs(tmp, exist_ok=True)

        def shoot(path, yaw, elev=8.0):
            a = math.radians(yaw); e = math.radians(elev)
            cam.location = (math.sin(a) * dist * math.cos(e), math.cos(a) * dist * math.cos(e), tz + math.sin(e) * dist)
            cam.rotation_euler = (V((0, 0, tz)) - cam.location).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(path)
            arr = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
            bpy.data.images.remove(img)
            return arr

        def montage(tiles, cols, path):
            h, w_ = tiles[0].shape[:2]
            rows = (len(tiles) + cols - 1) // cols
            out = np.ones((rows * h, cols * w_, 4), dtype=np.float32)
            for k, t in enumerate(tiles):
                r, c = rows - 1 - k // cols, k % cols
                out[r * h:(r + 1) * h, c * w_:(c + 1) * w_] = t
            img = bpy.data.images.new("montage", cols * w_, rows * h, alpha=False)
            img.pixels.foreach_set(out.ravel()); img.filepath_raw = path; img.file_format = "PNG"; img.save()
            bpy.data.images.remove(img)

        idle = "idle"
        self.pose(idle, 0.0)
        pv = shoot(os.path.join(self.prev, self.cid + ".png"), 28)
        tiles = [pv, shoot(os.path.join(tmp, "side.png"), 90), shoot(os.path.join(tmp, "back.png"), 200)]
        montage(tiles, 3, os.path.join(self.prev, self.cid + "_contact.png"))
        if os.environ.get("PARTY_POSES", "1") != "0":
            sc.cycles.samples = 12
            sc.render.resolution_x, sc.render.resolution_y = 260, 320
            tiles = []
            for nm, t in poses:
                self.pose(nm, t)
                tiles.append(shoot(os.path.join(tmp, "pose_%s.png" % nm), 35))
            montage(tiles, min(len(tiles), 5), os.path.join(self.prev, self.cid + "_poses.png"))
        self.pose(idle, 0.0)
        log("previews ->", self.prev)


# --------------------------------------------------------------------------- shared clip libraries
def S(t, period, phase=0.0):
    return math.sin(2 * math.pi * (t / period + phase))


def env(t, a, b):
    """0 before a, ramps to 1 at b (smooth)."""
    if t <= a:
        return 0.0
    if t >= b:
        return 1.0
    x = (t - a) / (b - a)
    return x * x * (3 - 2 * x)


def pulse(t, a, b, c, d):
    return env(t, a, b) * (1 - env(t, c, d))


def add(p, bone, rx=0.0, ry=0.0, rz=0.0):
    o = p.get(bone, (0.0, 0.0, 0.0))
    p[bone] = (o[0] + rx, o[1] + ry, o[2] + rz)


def biped_clips(H, tail=(), ears=(), extra=None, arm_rest=12.0, weapon_hand="R", shield_hand=None, stride=1.0):
    """Generic party clip set. H = height (m). extra(name, t, pose) lets a character add bespoke motion."""
    sx = {"R": 1, "L": -1}

    def base(t, name):
        p = {}
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, 0, -k * arm_rest * -1 if False else k * -arm_rest * -1, 0)
        return p

    def arms_rest(p):
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, 4, 0, 0)
            add(p, "ForeArm." + s, 10, 0, 0)

    def tail_sway(p, t, amp=12, period=2.0):
        for i, b in enumerate(tail):
            add(p, b, 4 * S(t, period, -0.12 * i), 0, amp * S(t, period, -0.15 * i))

    def ear_flick(p, t):
        for b in ears:
            add(p, b, 3 * S(t, 2.0), 0, 0)

    def finish(name, t, p):
        if extra:
            extra(name, t, p)
        return p

    def idle(t):
        p = {}; arms_rest(p)
        b = S(t, 2.0)
        add(p, "Spine", 1.5 * b); add(p, "Chest", 1.5 * b); add(p, "Neck", -1.0 * b)
        add(p, "Head", 0, 0, 5 * S(t, 2.0, 0.25))
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, -1.5 * b, 0, 0)
        tail_sway(p, t); ear_flick(p, t)
        p["@loc"] = (0, 0, H * 0.004 * b)
        return finish("idle", t, p)

    def gait(t, T, amp, knee, lean, bob, armamp, name):
        p = {}; arms_rest(p)
        ph = t / T
        for s, k in (("R", 0.0), ("L", 0.5)):
            sw = S(ph, 1.0, k)
            add(p, "Thigh." + s, amp * sw * stride)
            lift = max(0.0, S(ph, 1.0, k + 0.25))
            add(p, "Shin." + s, -knee * lift - 6)
            add(p, "Foot." + s, -0.4 * amp * sw + knee * 0.25 * lift)
            add(p, "UpperArm." + s, -armamp * sw)
            add(p, "ForeArm." + s, armamp * 0.6 + 8)
        add(p, "Spine", -lean); add(p, "Chest", -lean * 0.3)
        add(p, "Hips", 0, 0, 6 * S(ph, 1.0)); add(p, "Chest", 0, 0, -8 * S(ph, 1.0))
        add(p, "Head", lean * 0.8)
        tail_sway(p, t, amp=18, period=T)
        p["@loc"] = (0, 0, bob * H * abs(S(ph, 0.5)))
        return finish(name, t, p)

    def walk(t):
        return gait(t, 1.0, 26, 40, 3, 0.018, 20, "walk")

    def run(t):
        return gait(t, 0.6, 42, 75, 14, 0.04, 40, "run")

    w = weapon_hand

    def attack(t):
        p = {}; arms_rest(p)
        wind = pulse(t, 0.0, 0.28, 0.36, 0.52)
        strike = pulse(t, 0.3, 0.48, 0.62, 1.0)
        add(p, "UpperArm." + w, 150 * wind + 55 * strike, 0, 0)
        add(p, "ForeArm." + w, 40 * wind + 5 * strike)
        add(p, "Spine", 6 * wind - 14 * strike, 0, -18 * sx[w] * wind + 22 * sx[w] * strike)
        add(p, "Chest", 0, 0, -10 * sx[w] * wind + 12 * sx[w] * strike)
        o = "L" if w == "R" else "R"
        add(p, "UpperArm." + o, 30 * strike, 0, 0)
        add(p, "Thigh." + o, 28 * strike); add(p, "Shin." + o, -20 * strike)
        add(p, "Thigh." + w, -14 * strike)
        tail_sway(p, t, amp=20, period=1.0)
        p["@loc"] = (0, H * 0.18 * strike, -H * 0.02 * strike)
        return finish("attack", t, p)

    def cast(t):
        p = {}; arms_rest(p)
        up = pulse(t, 0.0, 0.45, 0.85, 1.4)
        push = pulse(t, 0.8, 0.95, 1.1, 1.4)
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, 95 * up + 20 * push, -k * 25 * up, 0)
            add(p, "ForeArm." + s, 25 * up)
            add(p, "Hand." + s, -20 * up)
        add(p, "Spine", 8 * up - 12 * push); add(p, "Head", 10 * up - 8 * push)
        tail_sway(p, t, amp=25, period=0.7)
        ear_flick(p, t * 3)
        p["@loc"] = (0, 0, H * 0.03 * up)
        return finish("cast", t, p)

    def hurt(t):
        p = {}; arms_rest(p)
        k_ = pulse(t, 0.0, 0.08, 0.2, 0.6)
        add(p, "Spine", 16 * k_); add(p, "Chest", 8 * k_); add(p, "Head", 18 * k_, 0, 8 * k_)
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, -20 * k_, -k * 30 * k_, 0)
        add(p, "Thigh.R", -10 * k_); add(p, "Shin.R", -15 * k_)
        for b in ears:
            add(p, b, 30 * k_)
        p["@loc"] = (0, -H * 0.06 * k_, 0)
        return finish("hurt", t, p)

    def down(t):
        p = {}; arms_rest(p)
        k1 = env(t, 0.0, 0.35); k2 = env(t, 0.3, 0.9)
        add(p, "Spine", 18 * k1); add(p, "Head", 15 * k1)
        add(p, "Thigh.R", 40 * k1 + 30 * k2); add(p, "Shin.R", -70 * k1)
        add(p, "Thigh.L", 30 * k1 + 40 * k2); add(p, "Shin.L", -60 * k1)
        for s, k in (("R", 1), ("L", -1)):
            add(p, "UpperArm." + s, 20 * k2, -k * 50 * k2, 0)
        p["Root"] = (72 * k2, 0, 0)
        p["@loc"] = (0, -H * 0.05 * k2, -H * 0.12 * k1 * (1 - k2) + H * 0.03 * k2)
        for b in ears:
            add(p, b, 25 * k2)
        for i, b in enumerate(tail):
            add(p, b, -10 * k2)
        return finish("down", t, p)

    def victory(t):
        p = {}; arms_rest(p)
        hop = max(0.0, S(t, 1.0))
        add(p, "UpperArm." + w, 165, 0, 0); add(p, "ForeArm." + w, 10 + 15 * S(t, 0.5))
        o = "L" if w == "R" else "R"
        add(p, "UpperArm." + o, 20, -sx[o] * 40, 0); add(p, "ForeArm." + o, 60)
        add(p, "Spine", -4 + 4 * hop); add(p, "Head", 8 + 6 * S(t, 1.0))
        add(p, "Thigh.R", 15 * hop); add(p, "Shin.R", -25 * hop); add(p, "Thigh.L", 15 * hop); add(p, "Shin.L", -25 * hop)
        tail_sway(p, t, amp=25, period=0.5); ear_flick(p, t * 2)
        p["@loc"] = (0, 0, H * 0.08 * hop)
        return finish("victory", t, p)

    def defend(t):
        p = {}; arms_rest(p)
        b = S(t, 1.0)
        g = shield_hand or ("L" if w == "R" else "R")
        add(p, "UpperArm." + g, 75, sx[g] * 20, 0); add(p, "ForeArm." + g, 60, 0, 0)
        add(p, "UpperArm." + w, 40, 0, 0); add(p, "ForeArm." + w, 50)
        for s in ("R", "L"):
            add(p, "Thigh." + s, 22); add(p, "Shin." + s, -38); add(p, "Foot." + s, 16)
        add(p, "Spine", -10 + 1.5 * b); add(p, "Head", 8)
        tail_sway(p, t, amp=6, period=1.0)
        p["@loc"] = (0, 0, -H * 0.045 + H * 0.003 * b)
        return finish("defend", t, p)

    return [("idle", idle, 2.0, True), ("walk", walk, 1.0, True), ("run", run, 0.6, True),
            ("attack", attack, 1.0, False), ("cast", cast, 1.4, False), ("hurt", hurt, 0.6, False),
            ("down", down, 1.2, False), ("victory", victory, 2.0, True), ("defend", defend, 1.0, True)]


BIPED_POSES = [("idle", 0.0), ("walk", 0.25), ("run", 0.15), ("attack", 0.2), ("attack", 0.5), ("cast", 0.7),
               ("hurt", 0.15), ("down", 1.2), ("victory", 0.25), ("defend", 0.3)]
SUMMON_POSES = [("idle", 0.0), ("summon_intro", 0.6), ("summon_intro", 2.2), ("special", 0.5), ("special", 0.9),
                ("special", 1.3), ("outro", 0.6), ("outro", 1.3)]


def cat_clips(H, tail, extra=None):
    """Quadruped Nine-Lives summon clips: idle, summon_intro, special (pounce + swipe), outro (bow + ascend)."""
    legs = ("Front", "Hind")

    def tail_wave(p, t, amp=14, period=3.0, lift=0.0):
        for i, b in enumerate(tail):
            add(p, b, lift + 6 * S(t, period, -0.1 * i), 0, amp * S(t, period, -0.13 * i))

    def fin(name, t, p):
        if extra:
            extra(name, t, p)
        return p

    def idle(t):
        p = {}
        b = S(t, 3.0)
        add(p, "Spine", 1.5 * b); add(p, "Chest", -1.5 * b)
        add(p, "Neck", 2 * S(t, 3.0, 0.2)); add(p, "Head", 3 * S(t, 3.0, 0.4), 0, 8 * S(t, 3.0, 0.1))
        for s in ("L", "R"):
            add(p, "Ear." + s, 4 * S(t, 1.5, 0.3 if s == "L" else 0.0))
        tail_wave(p, t)
        p["@loc"] = (0, 0, H * 0.006 * b)
        return fin("idle", t, p)

    def intro(t):
        p = {}
        fall = 1 - env(t, 0.0, 1.0)
        land = pulse(t, 0.9, 1.1, 1.2, 1.6)
        roar = pulse(t, 1.4, 1.7, 2.1, 2.5)
        p["@loc"] = (0, 0, H * 0.9 * fall - H * 0.05 * land)
        p["@scale"] = 0.35 + 0.65 * env(t, 0.0, 1.0)
        for s in ("L", "R"):
            add(p, "FrontUpper." + s, 25 * fall - 10 * land); add(p, "FrontLower." + s, -30 * fall)
            add(p, "HindUpper." + s, -25 * fall + 15 * land); add(p, "HindLower." + s, 30 * fall - 20 * land)
            add(p, "Ear." + s, -20 * roar)
        add(p, "Chest", 10 * roar); add(p, "Neck", 25 * roar); add(p, "Head", 20 * roar)
        add(p, "Spine", -8 * land)
        tail_wave(p, t, amp=22, period=1.2, lift=10 * roar)
        return fin("summon_intro", t, p)

    def special(t):
        p = {}
        crouch = pulse(t, 0.0, 0.45, 0.6, 0.75)
        leap = pulse(t, 0.6, 0.8, 1.0, 1.2)
        swipe = pulse(t, 1.0, 1.15, 1.35, 1.6)
        back = env(t, 1.4, 2.0)
        fwd = H * 1.2 * (env(t, 0.6, 1.1) - back)
        p["@loc"] = (0, fwd, -H * 0.12 * crouch + H * 0.35 * leap)
        for s in ("L", "R"):
            add(p, "HindUpper." + s, 30 * crouch - 35 * leap); add(p, "HindLower." + s, -40 * crouch + 30 * leap)
            add(p, "FrontUpper." + s, -20 * crouch + 55 * leap); add(p, "FrontLower." + s, 35 * crouch - 20 * leap)
            add(p, "Ear." + s, -25 * crouch)
        add(p, "FrontUpper.R", 85 * swipe, 0, -30 * swipe); add(p, "FrontLower.R", -40 * swipe)
        add(p, "Spine", 8 * crouch - 10 * leap); add(p, "Chest", 10 * swipe)
        add(p, "Head", -10 * crouch + 8 * swipe, 0, 10 * swipe)
        tail_wave(p, t, amp=28, period=0.8, lift=-12 * crouch + 15 * leap)
        return fin("special", t, p)

    def outro(t):
        p = {}
        bow = pulse(t, 0.0, 0.4, 0.7, 0.9)
        up = env(t, 0.7, 1.5)
        add(p, "Neck", -18 * bow); add(p, "Head", -15 * bow)
        for s in ("L", "R"):
            add(p, "FrontUpper." + s, -12 * bow + 20 * up); add(p, "HindUpper." + s, -15 * up)
        p["@loc"] = (0, 0, H * 1.1 * up)
        p["@scale"] = 1.0 - 0.9 * up
        tail_wave(p, t, amp=18, period=1.0, lift=20 * up)
        return fin("outro", t, p)

    return [("idle", idle, 3.0, True), ("summon_intro", intro, 2.5, False), ("special", special, 2.0, False),
            ("outro", outro, 1.5, False)]


# --------------------------------------------------------------------------- shared eye pattern
def eye_fn(iris, gaze_l, gaze_r, pupil="slit", iris2=None, glow=False):
    """Sphere-eye albedo from normals. gaze_* = unit gaze vector per side (x<0 left / x>0 right)."""
    iris = hexc(iris) if isinstance(iris, str) else np.asarray(iris)
    iris2 = (hexc(iris2) if isinstance(iris2, str) else np.asarray(iris2)) if iris2 is not None else iris * 0.55
    gl = np.asarray(gaze_l) / np.linalg.norm(gaze_l); gr = np.asarray(gaze_r) / np.linalg.norm(gaze_r)

    def fn(P, N):
        g = np.where((P[:, 0] < 0)[:, None], gl, gr)
        c = np.clip((N * g).sum(1), -1, 1)
        ang = np.degrees(np.arccos(c))
        up = np.array([0, 0, 1.0])
        right = np.cross(g, up); right /= np.linalg.norm(right, axis=1, keepdims=True)
        u = (N * right).sum(1); v = N[:, 2] - c * g[:, 2]
        col = np.tile(np.array([0.93, 0.92, 0.88]), (len(P), 1))
        ir = smoothstep(52, 46, ang)
        icol = mixc(iris, iris2, smoothstep(10, 42, ang))
        ring = smoothstep(36, 44, ang) * 0.6
        icol = icol * (1 - ring[:, None])
        col = mixc(col, icol, ir)
        if pupil == "slit":
            pm = smoothstep(0.11, 0.07, np.abs(u)) * smoothstep(0.62, 0.5, np.abs(v)) * (ang < 46)
        elif pupil == "hbar":  # goat: horizontal rectangular pupil
            pm = smoothstep(0.13, 0.09, np.abs(v)) * smoothstep(0.62, 0.5, np.abs(u)) * (ang < 46)
        else:
            pm = smoothstep(24, 19, ang).astype(float)
        col = mixc(col, np.array([0.02, 0.02, 0.03]), pm)
        hl = smoothstep(0.16, 0.08, np.hypot(u + 0.22, v - 0.28)) + 0.6 * smoothstep(0.08, 0.04, np.hypot(u - 0.18, v + 0.2))
        col = mixc(col, np.array([1.0, 1.0, 1.0]), np.clip(hl, 0, 1))
        return col
    return fn


def make_eyes(b, mat, centers, r, gaze, scale=(1, 1, 1), bone="Head", seg=20, rings=14):
    for i, c in enumerate(centers):
        g = V(gaze[i]) if isinstance(gaze[0], (list, tuple, V)) else V(gaze)
        rot = V((0, 0, 1)).rotation_difference(nrm(g))
        b.add(sphere("eye%d" % i, mat, c, r, scale=scale, rot=rot.to_matrix() @ Matrix.Rotation(0, 3, "Z"), seg=seg, rings=rings), bone)


def whiskers(b, mat, root_pts, side_dirs, length, r=0.004, bone="Head"):
    for i, (p, d) in enumerate(zip(root_pts, side_dirs)):
        p = V(p); d = nrm(d)
        pts = [p, p + d * length * 0.5 + V((0, 0, -0.08 * length)), p + d * length + V((0, -0.05 * length, -0.2 * length))]
        b.add(tube("wh%d" % i, mat, pts, [r, r * 0.6, 0.0], sides=4), bone)


# --------------------------------------------------------------------------- shared skeleton + cloth helpers
def biped_skeleton(b, hip, spine, chest, neck, head, top, sh, el, wr, hd, hipx, knee, ankle, toe,
                   tail=None, ears=None, extra=None):
    """Standard party biped. Right side = +X (character faces +Y). Points for the .R side only."""
    b.bone("Root", (0, 0, 0), (0, 0, hip * 0.4), deform=False)
    b.bone("Hips", (0, 0, hip), (0, 0, spine), "Root")
    b.bone("Spine", (0, 0, spine), (0, 0, chest), "Hips")
    b.bone("Chest", (0, 0, chest), (0, 0, neck), "Spine")
    b.bone("Neck", (0, 0, neck), (0, 0.005, head), "Chest")
    b.bone("Head", (0, 0.005, head), (0, 0.01, top), "Neck")
    b.bone("UpperArm.R", sh, el, "Chest")
    b.bone("ForeArm.R", el, wr, "UpperArm.R")
    b.bone("Hand.R", wr, hd, "ForeArm.R")
    b.bone("Thigh.R", (hipx, 0, hip), (hipx, 0.008, knee), "Hips")
    b.bone("Shin.R", (hipx, 0.008, knee), (hipx, 0, ankle), "Thigh.R")
    b.bone("Foot.R", (hipx, 0, ankle), (hipx, toe, 0.015), "Shin.R")
    names = []
    if tail:
        prev = "Hips"
        for i in range(len(tail) - 1):
            n = "Tail%d" % (i + 1); b.bone(n, tail[i], tail[i + 1], prev); prev = n; names.append(n)
    ear_names = []
    if ears:
        b.bone("Ear.R", ears[0], ears[1], "Head"); ear_names = ["Ear.R", "Ear.L"]
    if extra:
        for n, h, t, p in extra:
            b.bone(n, h, t, p)
    b.mirror_bones()
    return names, ear_names


def shell(name, mat, zs, a0, a1, rfn, thick=0.006, nz=10, na=18, cy=0.0, cx=0.0):
    """Cloth panel wrapped around the vertical axis. rfn(z) -> (rx, ry); angle 0 = front (+Y)."""
    bm = bmesh.new()
    grid = []
    for i in range(nz + 1):
        z = zs[0] + (zs[1] - zs[0]) * i / nz
        rx, ry = rfn(z)
        row = []
        for j in range(na + 1):
            a = math.radians(a0 + (a1 - a0) * j / na)
            row.append(bm.verts.new((cx + rx * math.sin(a), cy + ry * math.cos(a), z)))
        grid.append(row)
    for i in range(nz):
        for j in range(na):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # outward normals: flip if the first face points inward
    bm.faces.ensure_lookup_table(); f = bm.faces[len(bm.faces) // 2]
    c = f.calc_center_median()
    if f.normal.dot(V((c.x - cx, c.y - cy, 0))) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thick)
    return bm_to_obj(bm, name, mat)


def ring_band(name, mat, z, rfn, h, thick=0.008, seg=28):
    return shell(name, mat, (z - h / 2, z + h / 2), -180, 180, rfn, thick, nz=2, na=seg)


def stripes(P, freq, axis_w=(0, 0, 1), warp=2.5, seed=0, width=0.5):
    """Tabby stripe mask (1 = dark) along a weighted axis with noise warp."""
    w = np.asarray(axis_w, dtype=float)
    s = P @ w * freq + warp * (fbm(P, 6.0, 3, seed) - 0.5) * 2 * math.pi
    v = 0.5 + 0.5 * np.sin(s)
    return smoothstep(1 - width + 0.12, 1 - width + 0.28, v)
