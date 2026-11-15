# print-models report

## What I built
`tools/blender/print_export.py` (build|verify|contact), `tools/print_levels.mjs`, `game/tests/test_print_models.py`, `docs/PRINTING.md`.
Output in `dist/print/`: hero + 6 rats, squad plate (200x200), 5 weapons, ~20 props, castle (e1m6) full + 4 peg tiles, 2 rooms (e1m1, e1m5). OBJ+MTL+STL.

## Verification evidence
Blender headless re-import of every OBJ: 47 models, all single-shell manifold, volume>0 (`dist/print/verify_table.md`, copied into docs/PRINTING.md). Test script: 0 failures. Contact sheets in `out/previews/print-models/` (characters, levels, squad, weapons_props, boss_front).

## Deviations from the contract
Boss uses spec height 3.2 m scaling (rest pose is hunched). Levels use 2x wall-height exaggeration. Some thin features (rat estimates 1.0-1.2 mm min wall) remain near the limit.

## Mistakes I made and how I fixed them
Voxel remesh dropped thin disjoint parts (pillar etc.): added closing-radius fuse(). Zero-thickness sheets (capes) vanished: added thicken_open().

## Learnings for a future agent
Builds take >2 min; use `--only` and `--skip-existing`. Another session was rebuilding the boss concurrently while I verified (files vanished briefly): check pgrep before verifying.

## Requests for other modules
Boss rig rest pose is exploded/hunched; boss print shows thin blade artefacts (see boss_front.png). A cleaner rest-pose export would help.
