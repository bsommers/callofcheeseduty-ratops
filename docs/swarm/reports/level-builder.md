# level-builder report
## What I built
- tools/convert_levels.mjs (zero-dep, deterministic; schema in header) -> game/data/levels/e1m1..6.json; game/data/material_map.json (name -> res or placeholder triplanar StandardMaterial3D).
- game/scripts/level/: level_builder.gd (LevelBuilder: merged per-material ArrayMesh walls/floors/ceilings with metre UVs, run-merged box collision, doors, pushwalls, pickups, decor, enemy_spawn markers, zone + thing lights with shadows on nearest N, per-cell polygon NavigationMesh, exit Area3D, WorldEnvironment), rat_door/rat_pushwall/rat_pickup/level_events.gd, level_preview.gd (top-down ortho / fly path).
- game/scenes/level_base.tscn, level_preview.tscn; game/tests/test_level_builder.gd.
## Verification evidence
- Headless test builds all 6 levels, PASS (meshes, doors, enemy counts vs stats, navpolys, exit, start walkable). Parse check clean.
- tools/shot.sh res://scenes/level_preview.tscn out/shots/lb_e1m1_top.png: top-down layout matches e1m1 grid (rooms, doors, pushwall rooms). Only e1m1 was viewed.
## Deviations from the contract
- Navmesh is generated from the grid (not baked from geometry); no agent-radius erosion.
- Wall heights use the neighbouring zone ceilH; doors capped at 4 m with a lintel.
## Mistakes I made and how I fixed them
- Quad winding was counter-clockwise (Godot front faces are clockwise): floors invisible; reversed indices.
- Test used groups before nodes were in tree; deferred the run.
## Learnings for a future agent
- Run `tools/godot.sh --headless --path game --import` once to build the class_name cache before --script tests.
- Reference JS is ESM without package.json: converter loads via data: URLs.
## Requests for other modules
- Player "use" ray should call interact() on nodes in groups door/pushwall and trigger LevelBuilder.complete_level() at exit_switch.
- shaders-materials: provide res://assets/materials/<name with . -> _>.tres to override placeholders.
