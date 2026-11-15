"""Shared Blender helpers for CHEESE FANTASY models (run inside `blender -b -P`).

Facing: models face Blender +Y (exports to glTF -Z = Godot forward). Origin at feet.
Rig: parts are rigidly skinned (vertex group per bone) and joined into one mesh.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT, "game", "assets", "models")
PREVIEWS = os.path.join(ROOT, "out", "previews")

# ---- palette -------------------------------------------------------------
PAL = dict(
    barn=(0.62, 0.12, 0.09), barn_dk=(0.40, 0.07, 0.06), hay=(0.92, 0.74, 0.25), grass=(0.35, 0.58, 0.22),
    wood=(0.45, 0.28, 0.14), wood_lt=(0.66, 0.46, 0.26), stone=(0.52, 0.5, 0.47), white=(0.93, 0.91, 0.85),
    cream=(0.95, 0.86, 0.62), black=(0.05, 0.05, 0.06), pink=(0.93, 0.62, 0.62), cow_dk=(0.12, 0.1, 0.1),
    rot=(0.18, 0.62, 0.56), rot_dk=(0.08, 0.32, 0.36), rot_lt=(0.45, 0.85, 0.75), rat=(0.45, 0.40, 0.38),
    rat_dk=(0.25, 0.22, 0.22), metal=(0.55, 0.57, 0.6), gold=(0.95, 0.75, 0.2), cheddar=(0.98, 0.64, 0.12),
    leaf=(0.25, 0.5, 0.18), leaf2=(0.4, 0.62, 0.2), red=(0.8, 0.12, 0.1), skin=(0.9, 0.7, 0.55),
    blue=(0.25, 0.4, 0.75), brown=(0.35, 0.22, 0.12), water=(0.25, 0.5, 0.7), orange=(0.9, 0.5, 0.12),
)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)


_mats = {}


def mat(name, color=None, rough=0.6, metal=0.0, emit=None, emit_strength=2.0):
    """Named PBR material. color may be a PAL key or an rgb tuple."""
    key = name
    if key in _mats and _mats[key].name in bpy.data.materials:
        return _mats[key]
    if isinstance(color, str):
        color = PAL[color]
    color = color or (0.8, 0.8, 0.8)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        if isinstance(emit, str):
            emit = PAL[emit]
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_strength
    m.diffuse_color = (*color, 1)
    _mats[key] = m
    return m


def clear_mats():
    _mats.clear()


# ---- primitives ----------------------------------------------------------
def _finish(obj, material, loc, rot, scale, smooth=True):
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(r) for r in rot])
    obj.scale = scale
    bpy.context.view_layer.update()
    if material is not None:
        m = mat_of(material)
        obj.data.materials.append(m)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def mat_of(m):
    if isinstance(m, str):
        return mat(m, m if m in PAL else None)
    return m


def sphere(loc=(0, 0, 0), scale=(1, 1, 1), material=None, rot=(0, 0, 0), seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=seg, ring_count=max(6, seg // 2))
    return _finish(bpy.context.object, material, loc, rot, scale)


def cube(loc=(0, 0, 0), scale=(1, 1, 1), material=None, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    if bevel > 0:
        bv = o.modifiers.new("b", "BEVEL")
        bv.width = bevel
        bv.segments = 2
    _finish(o, material, loc, rot, scale, smooth=False)
    if bevel > 0:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="b")
    return o


def cyl(loc=(0, 0, 0), scale=(1, 1, 1), material=None, rot=(0, 0, 0), verts=14, r1=None, r2=None):
    """Cylinder radius 0.5, depth 1 along local Z; r1/r2 give a taper (bottom/top radius factors)."""
    if r1 is None and r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=0.5 * (r1 if r1 is not None else 1), radius2=0.5 * (r2 if r2 is not None else 1),
                                        depth=1, vertices=verts)
    return _finish(bpy.context.object, material, loc, rot, scale)


def cone(loc=(0, 0, 0), scale=(1, 1, 1), material=None, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cone_add(radius1=0.5, radius2=0, depth=1, vertices=verts)
    return _finish(bpy.context.object, material, loc, rot, scale)


def torus(loc=(0, 0, 0), major=0.5, minor=0.05, material=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8)
    return _finish(bpy.context.object, material, loc, rot, (1, 1, 1))


def ico(loc=(0, 0, 0), scale=(1, 1, 1), material=None, rot=(0, 0, 0), sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.5, subdivisions=sub)
    return _finish(bpy.context.object, material, loc, rot, scale)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


def apply_all(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ---- rigged model --------------------------------------------------------
class Model:
    """Collects bones + rigid parts; build() makes armature + one skinned mesh."""

    def __init__(self, name):
        self.name = name
        self.bones = []  # (name,parent,head,tail)
        self.parts = []  # (bone, obj)
        self.clips = {}

    def bone(self, name, parent, head, tail):
        self.bones.append((name, parent, Vector(head), Vector(tail)))

    def add(self, bone, obj):
        """Attach an already-created primitive to a bone."""
        self.parts.append((bone, obj))
        return obj

    def build(self):
        bpy.ops.object.armature_add(enter_editmode=True)
        arm = bpy.context.object
        arm.name = "Armature"
        arm.data.name = "Armature"
        ed = arm.data.edit_bones
        for b in list(ed):
            ed.remove(b)
        for n, p, h, t in self.bones:
            eb = ed.new(n)
            eb.head, eb.tail = h, t
            if (t - h).length < 1e-3:
                eb.tail = h + Vector((0, 0, 0.05))
            if p:
                eb.parent = ed[p]
        bpy.ops.object.mode_set(mode="OBJECT")
        self.arm = arm
        # skin
        objs = []
        for bn, o in self.parts:
            vg = o.vertex_groups.new(name=bn)
            vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
            objs.append(o)
        mesh = join(objs, self.name)
        # merge duplicate material slots
        bpy.context.view_layer.objects.active = mesh
        mesh.parent = arm
        md = mesh.modifiers.new("Armature", "ARMATURE")
        md.object = arm
        mesh.parent = arm
        self.mesh = mesh
        arm.name = "Armature"
        return mesh

    # keyfn(t) -> {bone: (rx,ry,rz[,lx,ly,lz])} degrees / metres; t in [0,1)
    def clip(self, name, frames, keyfn, loop=True, fps=24, samples=None):
        arm = self.arm
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        if not arm.animation_data:
            arm.animation_data_create()
        arm.animation_data.action = act
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)
        n = samples or max(4, frames // 3)
        for i in range(n + 1):
            t = i / n
            fr = 1 + round(t * frames)
            pose = keyfn(min(t, 0.999999) if loop and i == n else t) if not (loop and i == n) else keyfn(0.0)
            for pb in arm.pose.bones:
                v = pose.get(pb.name, (0, 0, 0))
                pb.rotation_euler = (math.radians(v[0]), math.radians(v[1]), math.radians(v[2]))
                pb.location = tuple(v[3:6]) if len(v) >= 6 else (0, 0, 0)
                pb.scale = tuple(v[6:9]) if len(v) >= 9 else (1, 1, 1)
                pb.keyframe_insert("rotation_euler", frame=fr)
                pb.keyframe_insert("location", frame=fr)
                pb.keyframe_insert("scale", frame=fr)
        for pb in arm.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)
        arm.animation_data.action = None
        self.clips[name] = act
        return act

    def export(self, out_id=None):
        out_id = out_id or self.name
        os.makedirs(MODELS, exist_ok=True)
        path = os.path.join(MODELS, out_id + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        self.arm.select_set(True)
        self.mesh.select_set(True)
        bpy.context.view_layer.objects.active = self.arm
        # push every action to an NLA track so all are exported
        ad = self.arm.animation_data or self.arm.animation_data_create()
        for t in list(ad.nla_tracks):
            ad.nla_tracks.remove(t)
        export_glb(path, use_selection=True)
        return path


def export_glb(path, use_selection=False):
    kw = dict(filepath=path, export_format="GLB", use_selection=use_selection, export_yup=True,
              export_apply=False, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(**kw, export_animations=True, export_animation_mode="ACTIONS",
                                  export_force_sampling=True, export_optimize_animation_size=False)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


def tri_count(objs):
    t = 0
    for o in objs:
        if o.type == "MESH":
            t += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return t


# ---- static models -------------------------------------------------------
class Static:
    """Static model. add(obj, group='body'); each group is joined into one node named after it.
    pivots={'group': (x,y,z)} sets that node's origin (for animation); the 'body' group keeps the model origin."""

    def __init__(self, name):
        self.name = name
        self.objs = []
        self.pivots = {}

    def add(self, o, group="body"):
        self.objs.append((o, group))
        return o

    def export(self):
        groups = {}
        for o, g in self.objs:
            groups.setdefault(g, []).append(o)
        self.meshes = []
        for g, lst in groups.items():
            m = join(lst, g if len(groups) > 1 else self.name) if len(lst) > 1 else lst[0]
            m.name = g if len(groups) > 1 else self.name
            apply_all(m)
            if g in self.pivots:
                bpy.context.scene.cursor.location = self.pivots[g]
                bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
            self.meshes.append(m)
        self.mesh = self.meshes[0]
        path = os.path.join(MODELS, self.name + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        for m in self.meshes:
            m.select_set(True)
        export_glb(path, use_selection=True)
        return path


# ---- preview -------------------------------------------------------------
def preview(name, objs, size=(480, 480), yaw=35, pitch=22, dist_mul=2.2):
    """Workbench render of the given objects to out/previews/<name>.png"""
    os.makedirs(PREVIEWS, exist_ok=True)
    pts = []
    for o in objs:
        if o.type == "MESH":
            for c in o.bound_box:
                pts.append(o.matrix_world @ Vector(c))
    if not pts:
        return
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    r = max((mx - mn).length / 2, 0.3)
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = r * 2.1
    yw, pt = math.radians(yaw), math.radians(pitch)
    d = r * 4
    cam.location = c + Vector((math.sin(yw) * math.cos(pt), math.cos(yw) * math.cos(pt), math.sin(pt))) * d
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = False
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    w.color = (0.55, 0.62, 0.7)
    sc.world = w
    sc.render.filepath = os.path.join(PREVIEWS, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


def finish(model, **pv):
    """Export + preview + report tri count. model = Model or Static."""
    path = model.export()
    objs = getattr(model, 'meshes', None) or [model.mesh]
    p = preview(model.name, objs, **pv)
    print("DONE %s tris=%d -> %s" % (model.name, tri_count(objs), os.path.basename(path)))
    reset()
    clear_mats()


# ---- common anim helpers -------------------------------------------------
def sin(t, ph=0.0):
    return math.sin((t + ph) * 2 * math.pi)


def contact_sheet(prefix_list, out, cols=4, cell=240):
    """Combine out/previews/<id>.png into one sheet (run inside blender)."""
    import numpy as np
    imgs = []
    for n in prefix_list:
        p = os.path.join(PREVIEWS, n + ".png")
        if os.path.exists(p):
            im = bpy.data.images.load(p)
            w, h = im.size
            a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
            st = max(1, w // cell)
            imgs.append(a[::st, ::st][:cell, :cell])
    if not imgs:
        return
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * cell, cols * cell, 4), dtype=np.float32)
    sheet[..., 3] = 1
    for i, a in enumerate(imgs):
        r, c = divmod(i, cols)
        h, w = a.shape[:2]
        sheet[(rows - 1 - r) * cell:(rows - 1 - r) * cell + h, c * cell:c * cell + w] = a
    im = bpy.data.images.new("sheet", cols * cell, rows * cell)
    im.pixels = sheet.flatten().tolist()
    im.filepath_raw = out
    im.file_format = "PNG"
    im.save()


reset()
