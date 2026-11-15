# model-weapons-props report

## What I built
`tools/blender/props.py` (run `blender -b -P tools/blender/props.py -- all [--preview] [--no-export]`) procedurally builds and exports 37 glbs to `game/assets/models/`:
5 weapons (`weapon_claws|pistol|gatling|yarn|laser`, each with `Muzzle` and `Grip` empties, barrel along -Y which exports as -Z) and 32 props (cheese wheel/wedge/brie/crown/stack, ammo box/clip, battery, yarn ammo, fish treat, tuna, catnip, gold/silver keys, crate, barrel, shelf, table, chair, lamp, torch, banner, sandbags, pipes, rug, statue, pillar, doorway, chandelier, candelabra, cauldron, mousetrap). Props: origin at floor centre, front -Y.
Materials are named slots (wood, metal, iron, brass, gold, silver, stone, cloth_*, leather, fur, cheese, cheese_rind, cheese_hole, glow_*, emblem...) with numpy-generated embedded textures; UVs via smart project.

## Verification evidence
All models under 15k tris (max weapon_gatling 14.1k, prop_chandelier 10.5k). `tools/godot.sh --headless --path game --import` imported all; `tools/run_tests.sh prop_models`: 2 passed, 0 failed. Contact sheet `out/previews/model-weapons-props/contact.png` inspected.

## Deviations from the contract
Everything authored procedurally; no Poly Haven bases used. Textures are albedo-only (no normal maps), so "wear" is texture-level (rust, grain), not geometric. Materials are plain flat-ish PBR; photoreal level is modest. Extra props beyond the list were added (crown, stack, cauldron, etc.).

## Mistakes I made and how I fixed them
Yarn weapon and yarn ammo exceeded 15k tris from many winding tori; reduced counts/segments. First contact sheet camera overlapped rows; switched to front orthographic grid.

## Learnings for a future agent
Workbench preview needs `color_type='TEXTURE'`. Blender 5.3 has `shade_smooth_by_angle`. Several dead `if False` expressions remain in props.py (harmless leftovers).

## Requests for other modules
Fur/cheese shaders may want to replace `cheese*` and `fur*` materials by slot name at load time. Weapon models are not yet scaled/oriented for the viewmodel rig; the consumer should position via Grip.
