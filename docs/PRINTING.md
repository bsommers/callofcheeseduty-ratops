# Printing RAT OPS models

All files live in `dist/print/` (symlink to a large-disk directory): `characters/`, `weapons/`, `props/`, `levels/`.
Each model is an `.obj` (+ `.mtl`, per-material flat colours, no textures) and a binary `.stl`.
**Units: 1 file unit = 1 millimetre.** The scale is in every file name (`_1toN`); heights are in `_h75mm`.

## Regenerate
```
blender -b -P tools/blender/print_export.py -- build      # characters, weapons, props, squad plate (~1 min)
node tools/print_levels.mjs                               # level dioramas (seconds)
blender -b -P tools/blender/print_export.py -- verify     # re-import every OBJ, measure, write dist/print/manifest.json
blender -b -P tools/blender/print_export.py -- contact    # contact sheets -> out/previews/print-models/
python3 game/tests/test_print_models.py                   # asserts manifold/volume/bed size/coverage
```

## Scales
- Characters: hero 75 mm tall (1:25.3 of 1.9 m); rats use the same mm-per-metre, so mouse is about 58 mm, trooper 69, officer 72, sewer 62, panzer about 91, boss scaled to its 3.2 m spec (about 125 mm, fits the 220 mm bed). Square-ish plinth is round, 3 mm. Squad plate: figures at 80 % (1:32) so all 7 fit on 200x200 mm.
- Weapons and props: 1:35. Anything whose longest side would be under 25 mm (keys, pistol, ammo clip, mousetrap...) is scaled up to 25-30 mm; the real ratio is in the file name.
- Level dioramas: castle = e1m6 "Throne of the Big Cheese" (most castle-like: throne hall, flag stands, pillars) whole level on one 200x200 plate at 1:640 (cell 6.25 mm); the same level as 4 tiles at 1:320 (cell 12.5 mm, 200x200 mm each) with alignment tabs on the east/south edges and matching slots on west/north edges (tab 10x6 mm, slot 12.5x7.5 mm; print all four, tabs drop into slots); rooms: `e1m1_room_cellar` and `e1m5_room_vault` at 1:250 (cell 16 mm). Walls are exaggerated 2x in height so they read at this scale. Open roof, doorways (brown floor) cut through walls, crates/barrels/pillars as simple solids in the tiles and rooms. Every wall is at least one cell thick (6.25 mm or more) and the floor slab is at least 2.5 mm. All fit 220x220x250 mm.

## How the characters/props are made
Source: exported GLBs, authored pose. Armature, LOD1 copies, eyes, whiskers and decal patches dropped. Parts are joined, a plinth added, then voxel remesh (0.5 mm) fuses everything into ONE shell; the surface is dilated 0.6 mm per side (so no feature is thinner than about 1.2 mm; the model is pre-shrunk to compensate) and remeshed again. Zero-thickness sheets (capes) are solidified to 1 mm first. Models made of loosely stacked parts (pillar, boss) get a closing radius (grow, remesh, shrink) until they are one solid. Colour comes from the nearest source face.

## Thick variants (rat_officer, rat_trooper, rat_boss)
`characters/<name>_h..._thick.{obj,stl}` are sturdier copies for FDM/resin with a 2.0 mm minimum wall; the originals are unchanged. Build: `blender -b -P tools/blender/print_export.py -- build --thick --only rat_officer,rat_trooper,rat_boss`. Differences: 1.05 mm dilation per side (originals 0.6), capes solidified to 2.2 mm, closing radius at least 1 mm, then a morphological opening (erode 1.0 mm, dilate 1.0 mm) that deletes anything thinner than 2 mm. This also removes the boss's blade-like spikes (cape/crown/rest-pose slivers); tips and the crown are rounded, fine detail is softer. Min-wall estimates are 4.4 / 4.5 / 2.6 mm (officer / trooper / boss).

## Print advice
Characters 0.12 mm layers, supports for arms and tails; the boss and squad are large (400k+ triangles); slicers cope, but decimate if needed. Weapons and tiny props are best printed on their plinth. Min wall estimate is a 1st percentile inward ray test; sharp tips (tail ends, ear points) read low and are normal tapers.

## Verification (re-imported from OBJ in Blender headless)
| file | triangles | bbox mm (x y z) | volume mm3 | manifold | min wall mm (est) | STL MB |
|---|---|---|---|---|---|---|
| characters/hero_h75mm_1to26.obj | 71252 | 27.4 x 55.9 x 77.8 | 17226 | yes | 3.37 | 3.6 |
| characters/rat_boss_h125mm_1to27.obj | 440104 | 83.3 x 150.1 x 128.5 | 133496 | yes | 1.70 | 22.0 |
| characters/rat_boss_h125mm_1to27_thick.obj | 420392 | 83.0 x 150.6 x 129.4 | 166714 | yes | 2.61 | 21.0 |
| characters/rat_mouse_h60mm_1to26.obj | 64732 | 27.5 x 77.6 x 63.0 | 10519 | yes | 2.25 | 3.2 |
| characters/rat_officer_h72mm_1to26.obj | 87320 | 34.3 x 75.5 x 75.0 | 16367 | yes | 2.28 | 4.4 |
| characters/rat_officer_h72mm_1to26_thick.obj | 94708 | 35.2 x 75.9 x 76.2 | 23849 | yes | 4.43 | 4.7 |
| characters/rat_panzer_h93mm_1to26.obj | 180452 | 56.9 x 107.5 x 96.1 | 49983 | yes | 2.69 | 9.0 |
| characters/rat_sewer_h59mm_1to26.obj | 72328 | 31.6 x 65.9 x 62.6 | 12060 | yes | 2.28 | 3.6 |
| characters/rat_trooper_h69mm_1to26.obj | 90132 | 35.5 x 78.2 x 72.2 | 17565 | yes | 2.27 | 4.5 |
| characters/rat_trooper_h69mm_1to26_thick.obj | 98212 | 36.5 x 78.7 x 73.4 | 25134 | yes | 4.48 | 4.9 |
| characters/squad_plate_200x200mm_1to32.obj | 414812 | 200.7 x 200.7 x 88.0 | 197814 | yes | 0.59 | 20.7 |
| levels/e1m1_room_cellar_1to250.obj | 105600 | 192.0 x 192.0 x 51.2 | 614400 | yes | 3.20 | 5.3 |
| levels/e1m5_room_vault_1to250.obj | 119072 | 192.0 x 208.0 x 51.2 | 741507 | yes | 3.20 | 6.0 |
| levels/e1m6_castle_full_1to640.obj | 156440 | 200.0 x 200.0 x 21.2 | 341992 | yes | 2.50 | 7.8 |
| levels/e1m6_castle_tile_r0c0_1to320.obj | 144336 | 206.2 x 206.2 x 40.0 | 665344 | yes | 2.50 | 7.2 |
| levels/e1m6_castle_tile_r0c1_1to320.obj | 147376 | 200.0 x 206.2 x 40.0 | 670338 | yes | 2.50 | 7.4 |
| levels/e1m6_castle_tile_r1c0_1to320.obj | 183496 | 206.2 x 200.0 x 40.0 | 548434 | yes | 2.50 | 9.2 |
| levels/e1m6_castle_tile_r1c1_1to320.obj | 174224 | 200.0 x 200.0 x 40.0 | 452652 | yes | 2.50 | 8.7 |
| props/prop_ammo_box_1to21.obj | 18732 | 25.9 x 19.1 x 16.4 | 6074 | yes | 9.56 | 0.9 |
| props/prop_ammo_clip_1to7.obj | 29932 | 29.0 x 29.0 x 24.3 | 10326 | yes | 3.17 | 1.5 |
| props/prop_barrel_1to35.obj | 22928 | 21.2 x 21.4 x 27.1 | 8064 | yes | 18.60 | 1.1 |
| props/prop_battery_1to10.obj | 16404 | 16.1 x 16.1 x 26.0 | 5505 | yes | 4.65 | 0.8 |
| props/prop_brie_wheel_1to28.obj | 13280 | 25.6 x 25.6 x 6.2 | 2630 | yes | 3.14 | 0.7 |
| props/prop_candelabra_1to35.obj | 13288 | 16.1 x 15.1 x 42.7 | 1377 | yes | 2.60 | 0.7 |
| props/prop_catnip_1to19.obj | 16896 | 16.2 x 16.2 x 27.1 | 2190 | yes | 2.30 | 0.8 |
| props/prop_cauldron_1to35.obj | 33908 | 33.2 x 29.6 x 25.2 | 11911 | yes | 3.51 | 1.7 |
| props/prop_chair_1to35.obj | 15452 | 14.7 x 14.7 x 29.7 | 1829 | yes | 2.69 | 0.8 |
| props/prop_cheese_crown_1to18.obj | 26276 | 25.6 x 25.6 x 15.9 | 4677 | yes | 3.19 | 1.3 |
| props/prop_cheese_stack_1to34.obj | 22360 | 25.9 x 25.9 x 18.0 | 8359 | yes | 16.22 | 1.1 |
| props/prop_cheese_wedge_1to26.obj | 18624 | 28.9 x 28.9 x 8.7 | 3543 | yes | 3.17 | 0.9 |
| props/prop_cheese_wheel_1to23.obj | 15636 | 25.9 x 25.9 x 9.2 | 4330 | yes | 8.66 | 0.8 |
| props/prop_crate_1to35.obj | 36204 | 27.1 x 29.1 x 26.8 | 19368 | yes | 26.59 | 1.8 |
| props/prop_fish_treat_1to12.obj | 18280 | 27.3 x 25.5 x 11.8 | 3667 | yes | 3.18 | 0.9 |
| props/prop_key_gold_1to13.obj | 9516 | 27.2 x 9.6 x 10.7 | 1287 | yes | 3.03 | 0.5 |
| props/prop_key_silver_1to14.obj | 7444 | 28.9 x 7.2 x 8.5 | 909 | yes | 2.91 | 0.4 |
| props/prop_lamp_1to35.obj | 14240 | 16.3 x 16.3 x 51.2 | 1719 | yes | 2.99 | 0.7 |
| props/prop_mousetrap_1to9.obj | 13712 | 28.9 x 18.1 x 8.3 | 2871 | yes | 3.48 | 0.7 |
| props/prop_pillar_1to35.obj | 102660 | 34.6 x 34.6 x 103.8 | 42948 | yes | 3.86 | 5.1 |
| props/prop_sandbags_1to35.obj | 41876 | 72.3 x 11.8 x 19.2 | 8975 | yes | 7.58 | 2.1 |
| props/prop_shelf_1to35.obj | 102760 | 46.9 x 13.3 x 58.1 | 17466 | yes | 2.71 | 5.1 |
| props/prop_statue_1to35.obj | 53484 | 31.0 x 30.3 x 62.4 | 17088 | yes | 2.90 | 2.7 |
| props/prop_table_1to35.obj | 30544 | 32.9 x 32.9 x 27.1 | 4536 | yes | 3.18 | 1.5 |
| props/prop_torch_1to26.obj | 6952 | 9.5 x 11.7 x 27.2 | 810 | yes | 3.26 | 0.3 |
| props/prop_tuna_1to8.obj | 28908 | 28.4 x 28.4 x 20.6 | 9132 | yes | 3.19 | 1.4 |
| props/prop_yarn_ammo_1to21.obj | 34840 | 25.7 x 26.6 x 17.3 | 6397 | yes | 3.14 | 1.7 |
| weapons/weapon_claws_1to18.obj | 9164 | 11.5 x 27.1 x 10.6 | 1441 | yes | 2.00 | 0.5 |
| weapons/weapon_gatling_1to35.obj | 10820 | 19.0 x 29.0 x 13.5 | 1531 | yes | 2.69 | 0.5 |
| weapons/weapon_laser_1to17.obj | 6152 | 7.2 x 28.9 x 5.8 | 787 | yes | 3.30 | 0.3 |
| weapons/weapon_pistol_1to14.obj | 8424 | 7.8 x 27.3 x 19.2 | 1085 | yes | 3.30 | 0.4 |
| weapons/weapon_yarn_1to35.obj | 9016 | 7.2 x 31.8 x 11.5 | 1120 | yes | 2.03 | 0.5 |

All files: single connected shell, zero non-manifold edges/vertices, positive volume.
