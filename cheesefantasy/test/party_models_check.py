"""Re-import each party/summon GLB and check contract: clips, armature, tris, height, materials.
Run: blender -b -P test/party_models_check.py   (exit 1 on failure)"""
import bpy, os, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
M = os.path.join(REPO, "game", "assets", "models")
HERO = ["idle", "walk", "run", "attack", "cast", "hurt", "down", "victory", "defend"]
SUM = ["idle", "summon_intro", "special", "outro"]
ids = {"hero_fennel": HERO, "hero_brie": HERO, "hero_clover": HERO, "hero_maple": HERO,
       "summon_jesse": SUM, "summon_tripper": SUM, "summon_samantha": SUM, "summon_spooky": SUM}
bad = 0
for cid, clips in ids.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(M, cid + ".glb"))
    acts = {a.name.split("|")[-1] for a in bpy.data.actions} | {a.name for a in bpy.data.actions}
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent and o.parent.type == "ARMATURE"]  # skip importer bone-shape Icosphere
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    zs = [(o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices]
    mats = sorted({s.material.name for o in meshes for s in o.material_slots if s.material})
    missing = [c for c in clips if c not in acts]
    bones = len(arms[0].data.bones) if arms else 0
    h = max(zs) - min(zs)
    ok = not missing and arms and tris < 30000 and min(zs) > (-0.05 if cid.startswith("hero") else -0.1) and (1.0 <= h <= 1.9 if cid.startswith("hero") else 2.6 <= h <= 3.6)
    bad += not ok
    print("CHECK %-16s %s tris=%d bones=%d h=%.2f minz=%.2f missing=%s mats=%s" % (cid, "OK" if ok else "FAIL", tris, bones, h, min(zs), missing, ",".join(mats)))
sys.exit(1 if bad else 0)
