# shaders-materials report

## What I built
- **Shaders** (`game/assets/shaders/`): `cheese` (object-space 3D Worley holes, no UVs/no seams, cavity normal + depth-correct `DEPTH` offset, waxy rind via vertex-colour R or whole surface, SSS/backlight, clearcoat gloss, blue-cheese veins, cheddar crystals), `fur` (shell fur: shell_index/shell_count, length/density/clump/gravity/wind, tabby stripes, colour variation, self-shadow, rim; extrusion after skinning so it works on skinned meshes), `fur_lod` (single-pass fallback), `skin_sss`, `cloth` (weave normal + sheen), `wet_stone` / `wet_metal` (puddles by world-Y + noise), `glass`, `gold_foil`, `emblem` (black cheese wedge in white disc on red, procedural, AA), `triplanar_pbr` (world-space triplanar over `game/assets/textures/<id>/`, procedural placeholder when missing). Shared includes: `noise.gdshaderinc`, `wet.gdshaderinc`.
- **Library** (`game/assets/materials/`): 65 `.tres` made by `build_materials.gd` (rebuild: `tools/godot.sh --headless --path game -s res://assets/materials/build_materials.gd`). One `tri_<id>` per fetched texture set, plus `tri_placeholder`.
- **API** `RatMaterials` (`rat_materials.gd`): `get_material(name)` (cached; unknown -> magenta fallback + warning), `list_names()`, `has_material()`, `apply_fur(mesh, name, shells=-1)` (shell count from `Settings.quality`: 0/8/16/24), `build_fur()`, `make_fur_lod()`, `apply_fur_with_lod()` (visibility-range twin).
- **Studio**: `game/scenes/material_test.tscn` + `material_studio.gd` (`MaterialStudio`): HDRI sky (bloem_hill_01) + sun + rim light, rows of wedges/cubes/spheres/walls for every material family, labelled.
- **Tests**: `game/tests/test_materials.gd` (8 tests).

## Verification evidence
- `tools/run_tests.sh test_materials` -> `RESULT 8 passed, 0 failed`.
- `tools/godot.sh --headless --path game --quit`: no errors/warnings from my files.
- GPU renders via `tools/shot.sh` (Vulkan, RADV), no shader compile errors: `out/shaders/overview2.png`, `cheese2.png`, `fur.png`, `emblem2.png`. Looked at them: swiss wedge and cube show clear dark-walled holes, blue shows veins, cheddar is orange with sparse holes and a rind: unmistakable cheese. Fur spheres at ~2.3 m show fuzzy silhouettes and strand texture (tabby stripes clear). Emblem reads correctly on the flag quad and on all crate faces.

## Deviations from the contract
- Base `cheese_cheddar|swiss|blue` use `rind_source = 0` (holes everywhere, works on any mesh). Rinded variants are `cheese_*_rind` (rind where vertex colour R = 1). Reason: meshes without vertex colours report white, so the whole surface became rind with no holes.
- Added `emblem_crate` (`box_mesh_uv = true`: one emblem per face of a Godot BoxMesh 3x2 UV atlas). `emblem_*` otherwise assume one 0..1 UV square per emblem.

## Mistakes I made and how I fixed them
- Swiss holes were nearly invisible at first (tint too light, coverage too low). Fixed with stronger cavity darkening in the shader, plus larger and more frequent holes.
- Grey/brown rat fur rendered almost black. Lightened the root/tip colours and lengthened the fur.
- Emblem on a BoxMesh appeared off-centre (atlas UVs). Fixed with the `box_mesh_uv` mode and a QuadMesh flag.
- The studio background was a flat colour. Switched to the HDRI sky.

## Learnings for a future agent
- The headless dummy renderer does not fully compile shaders. Use `tools/shot.sh` for a real GPU compile check.
- Sampler function args with different hints are rejected, so `rat_tri_sample` is a `#define`.
- `shader_parameter/x = null` lines in the saved `.tres` are harmless (they fall back to the shader defaults).
- Studio camera presets are in the header of `material_studio.gd`.

## Requests for other modules
- **assets-fetch**: texture `.import` files have mipmaps off. Please enable mipmaps for the albedo/normal/roughness maps, otherwise triplanar walls shimmer at a distance.
- **characters/props**: use `RatMaterials.apply_fur(mesh, "fur_rat_grey")` (or `apply_fur_with_lod`). Use `cheese_*_rind` only on meshes whose vertex colour R marks the rind.
- Minor known issue: a faint 1-px light seam on BoxMesh edges with `emblem_crate` (UV atlas padding). Not fixed.
