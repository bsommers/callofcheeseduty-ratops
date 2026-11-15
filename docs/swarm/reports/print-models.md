# print-models report
## What I built
- tools/blender/print_export.py: GLB -> watertight OBJ/MTL/STL (mm). Hero + 6 rats (75 mm hero scale, boss at 3.2 m spec), 5 weapons, 27 props (1:35, min 25 mm), squad plate 200x200. Modes build/verify/contact.
- tools/print_levels.mjs: voxel-based cutaway dioramas: e1m6 castle (full plate 1:640 + 4 peg/slot tiles 1:320) and 2 rooms (e1m1, e1m5), OBJ+MTL+STL.
- docs/PRINTING.md (scales, regenerate, table), game/tests/test_print_models.py.
## Verification evidence
- verify re-imports all 47 OBJ in Blender: all single-shell, 0 non-manifold, volume > 0; test script passes. Contact sheets in out/previews/print-models/ (characters, squad, weapons_props, levels) viewed.
## Deviations from the contract
- Squad plate figures at 80% so 7 fit 200 mm. Props/weapons under 25 mm scaled up (ratio in name). Wall height 2x exaggerated on dioramas. No name embossing (plain plinth). No 28 mm heroic variants. Whiskers dropped. Weapons: rat-held weapons are fused into rat figures; hero's gear fused.
- Min wall estimate (1st percentile inward ray) is low (0.8-1.2 mm) on a few models (claws, chair, pillar, catnip) at tapered tips; dilation targets 1.2 mm.
## Mistakes I made and how I fixed them
- Forcing armature REST pose exploded the boss rig: use importer's authored pose. Disjoint-part props (pillar) were silently cut to the largest piece: added closing-radius loop and stray-component logging. Open sheets (cape) ragged: split + Solidify modifier (even offset gave huge spikes; fixed thickness works). bmesh dissolve+beauty triangulate on 400k-vert plate hung for 10+ min: removed. Two concurrent builds clobbered build_records.json: never run two.
## Learnings for a future agent
- Voxel Remesh does not fuse separated parts; bridge with grow/shrink. Run long Blender jobs with nohup + log file, not through a pipe.
## Requests for other modules
- None. Source models made of many loose boxes (pillar, crate, boss) would print better as fused meshes in hero.py/props.py.
