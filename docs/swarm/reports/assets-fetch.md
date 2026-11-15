# assets-fetch report

## What I built
- `tools/fetch_assets.mjs` (zero-dep Node, uses fetch + system `unzip`): reads `tools/assets.manifest.json` (30 entries: 26 texture sets, 4 HDRIs; fields id/source/assetId/kind/license/maxRes/use), downloads from Poly Haven API and ambientCG, md5-verifies Poly Haven files, writes `game/assets/textures/<id>/{albedo,normal,roughness,ao,displacement,metallic}.jpg` (whichever exist; normal is GL convention) and `game/assets/hdri/<id>_2k.hdr`, keeps `assets-cache/state.json`, regenerates `docs/ASSETS.md` (every file: name, source URL, license, size). Flags: `--only id,id`, `--docs-only`. Idempotent (re-run printed only "skip"), resumable (per-asset state), 3 GB budget guard.
- Coverage: brick (2, one mossy), mossy stone, floor boards, planks, parquet, marble tiles + polished marble, metal plate/rusted steel/grating, concrete, 2 plasters, denim + wool + leather + rug, 2 tiles, 2 cobbles, dirt, gold, brass, leather_white (waxy rind stand-in). HDRIs: bloem_hill_01 (overcast), dikhololo_night, comfy_cafe (warm interior), aarfontein_dusk.
- 135 files, 291 MB in game/assets; assets-cache duplicates ~293 MB (safe to delete except state.json).

## Verification evidence
- Full run: 30 ok, 0 FAIL, 42 s. Second run: all skip. `identify`: sampled maps are 2048x2048.
- Not run: Godot import/parse check (no GDScript written; no game/project import done by me).

## Deviations from the contract
- No resize step needed: Poly Haven and ambientCG both serve native 2K JPG, so no ImageMagick/Blender use. JPG only (no PNG).
- No exact "waxy rind" CC0 material found on either site; leather_white is a placeholder. Cheese should be procedural per ARCHITECTURE section 5.
- "Checker marble" is covered by marble_tiles and checkered_pavement_tiles; verify visually when used.

## Mistakes I made and how I fixed them
- None hit; ambientCG search for "brass/wax/canvas" returned nothing, so I used Metal048A/Metal042A (gold-ish metals; not visually checked) and Poly Haven denim for canvas.

## Learnings for a future agent
- Poly Haven: `GET /files/<id>` -> `{Diffuse,nor_gl,Rough,AO,Displacement,Metal,arm}["2k"].jpg.{url,md5,size}`; HDRIs under `.hdri["2k"].hdr`. ambientCG: `https://ambientcg.com/get?file=<Id>_2K-JPG.zip`, files `<Id>_2K-JPG_{Color,NormalGL,Roughness,AmbientOcclusion,Displacement,Metalness}.jpg`.
- Poly Haven `arm` (AO/Rough/Metal packed) exists for ORM use; I did not fetch it.
- Gold/brass ambientCG IDs are guesses from "popular metal" search; confirm look.

## Model scouting
Verified (Poly Haven API, CC0, glTF/blend available, polycount from API; no rigs):
| Need | Asset | URL | Poly | Rigged | Recommendation |
|---|---|---|---|---|---|
| Rat | Street Rat (Sean Buckley) | https://polyhaven.com/a/street_rat | 14,286 | no | use-as-base: static fur-textured pose; re-rig in Blender, drive fur shader |
| Cat statue (not usable as cat) | concrete_cat_statue | https://polyhaven.com/a/concrete_cat_statue | 11,950 | no | prop only; author the cat in Blender |
| Mouse trap | mousetrap | https://polyhaven.com/a/mousetrap | 5,136 | no | use-as-is |
| Cheese crate | CheeseBox_01 | https://polyhaven.com/a/CheeseBox_01 | 884 | no | use-as-is |
| Rifle | bolt_action_rifle_7_62 | https://polyhaven.com/a/bolt_action_rifle_7_62 | 19,985 | no | use-as-is (scale 1:1; rat-scale rescale) |
| Pistol | service_pistol | https://polyhaven.com/a/service_pistol | 27,548 | no (detachable mags) | use-as-is or decimate |
| Props | wooden_military_crate (22,986), old_military_crate (10,476), ammo_box (4,382), metal_jerrycan (20,022), barrel_stove (11,404), vintage_radio_transceiver (42,350), rubber_boots (35,004) | https://polyhaven.com/a/<name> | as listed | no | use-as-is; decimate heavy ones |
Poly Haven also has 520+ models total (`https://api.polyhaven.com/assets?t=models`), all CC0.

Unverified (my sites could not be fetched, 403 from kenney.nl/opengameart/poly.pizza; from memory, confirm before use):
- Quaternius (https://quaternius.com, CC0): Ultimate Animated Animals / Animated Animal packs (cat-like animals, rigged and animated, low poly); Ultimate Guns pack (generic firearms, unrigged). Recommend use-as-base for the cat if style fits, otherwise author in Blender.
- Kenney (https://kenney.nl/assets, CC0): Blaster Kit, Weapon pack, Prototype/Furniture kits (low poly, stylised, unrigged); likely too stylised for photoreal target.
- OpenGameArt (https://opengameart.org): mixed CC0/CC-BY/GPL; check per-asset license. Sketchfab: CC0 downloads need login in practice; skipped.
- Uniforms/clothing/WWII-specific: nothing suitable verified as CC0; recommend author in Blender (helmet, tunic, webbing) with the cloth/leather textures fetched here.
- Cat (realistic, rigged): author in Blender; no verified CC0 source.

## Requests for other modules
- Godot import settings (normal map flag on normal.jpg, sRGB off for roughness/ao/displacement) belong to the material/importer owner.
- Someone with `tools/shot.sh` should contact-sheet-check gold/brass/leather_white looks.
