# look-dev report (2026-11-15T04:36Z)

## What I built
- **`game/scripts/look/look_rig.gd`** (`class_name LookRig`, Node3D). Data-driven per-level look. It reads `res://data/look/default.json`, deep-merges `res://data/look/<levelid>.json` over it, and builds or applies:
  - **Environment**, installed on the builder's `LevelEnvironment` (or its own node if there is none): CC0 HDRI panorama sky (`game/assets/hdri/`) for reflections, plus a visible sky background where a level wants one; ACES tonemap (filmic/agx/linear selectable), exposure and white point; auto-exposure through `CameraAttributesPractical`; SDFGI with occlusion; SSAO and SSIL; SSR; volumetric fog (density, albedo, emission, anisotropy, GI and ambient inject); glow (softlight, per-level levels); colour grading through a **generated 32³ 3D LUT** (lift/gamma/gain, shadow and highlight split-toning, tint) plus brightness/contrast/saturation.
  - **Sun/moon** DirectionalLight3D (PSSM, from the level's `moonDir`) and a faint shadowless **fill**.
  - **Film finish** (`post_fx.gdshader`, CanvasLayer -1, so it sits under the HUD): luminance-weighted film grain, a tinted vignette and radial chromatic aberration. Lens dirt is deliberately off.
  - **The level's own lights, retuned at runtime** (the "small hook"; `level_builder.gd` is not edited): zone ceiling lights and practicals (decor torches) get energy, range, colour, attenuation, soft-shadow size, fog energy and per-zone overrides from the look data. Torch flicker runs on a noise function, and emissive decor glow is rescaled.
  - **RatMaterials remap**: the builder's flat placeholder surfaces (`Mesh_<mat>`) are swapped for library materials (`tri_*`, `wet_*`, `gold_foil`) with tint and parameters from the `materials` section. Surfaces that already use a `.tres` are left alone, so this does nothing once integ-lead maps `material_map.json`.
  - **Other level fixes**: the `Mesh_ceil_sky` ceilings are hidden so the e1m4 courts open to the night sky. Level shells cast shadows double-sided when a sun exists (without this the moon leaked through every one-sided ceiling). ReflectionProbes are placed every 6 cells (UPDATE_ONCE, box-projected).
  - **Quality**: calls `Settings.apply_to_environment`/`apply_to_light`, then adds per-tier settings from `quality` in the JSON. Low and Medium have no probes. Low has no volumetric fog, so depth fog stands in for the haze, and ambient is lifted when SDFGI is off. CA is off below High, and the number of shadowed lights is set per tier. It re-applies on `Events.settings_changed`.
  - **In game**: instance `res://scenes/look_rig.tscn` once (for example under Main). It follows `Events.level_loaded`, waits for the builder's `built` signal, applies the look, then re-asserts it 2 frames later because main.gd's `_brighten` overwrites ambient and exposure. `LookRig.apply_to(level, id)` is the direct API.
  - **Preview/evidence harness**: `tools/shot.sh res://scenes/look_rig.tscn out.png --user-arg --look-level=e1m1 [--user-arg --look-quality=0..3] [--user-arg --look-off=1]` builds the level itself and prints `SHOT_LOOK ... gpu_ms_median=`.
- **`game/data/look/`**: `default.json` plus one mood per level:
  - e1m1 Cheese Cellar: torchlit amber pools, dusty warm haze, flickering torches, a cool blue-cheese room.
  - e1m2 Rat Barracks: cold institutional bulbs with a faint buzz flicker, grey-green, desaturated, harsh contrast.
  - e1m3 Fondue Works: molten-orange furnace zones, orange emissive steam haze, sodium work lights, stronger bloom.
  - e1m4 Moonlit Hall of Mirrors: shadowed blue moon, starry HDRI sky over the open courts, glossy marble (low roughness) for SSR, warm candelabra halls.
  - e1m5 Blue Vault: teal mould haze, wet cobbles and stone (wet_* shaders), gold vault glowing warm.
  - e1m6 Throne: crimson haze, golden throne zone, heavy red vignette.
- **`game/tests/test_look.gd`**: 6 tests covering data and assets, distinct moods, the merge, LUT identity and split-toning, applying to built e1m1/e1m4 (env installed, ACES, LUT, auto-exposure, lights brightened, post layer, moon plus hidden sky ceiling), and quality degradation (Low to Ultra).
- **`game/assets/shaders/emblem.gdshader`** (edit allowed by the prompt): fixed the 1-px light edge line on `emblem_crate`.

## Verification evidence
- Parse check `tools/godot.sh --headless --path game --quit`: no errors or warnings. `run_all.gd`: all 6 `test_look.gd` tests PASS. The other modules' failures I saw (`test_audio::test_all_streams_load`, `test_playthrough::test_bot_plays_e1m1_short`) are intermittent and not in my files.
- **e1m1 brightness**: the same camera with builder lighting only (`--look-off=1`) has mean RGB (0.051, 0.023, 0.008), i.e. near black. With the look it is about (0.37, 0.13, 0.04): warm and readable, with the dark corners kept (lum std 0.20).
- **Renders**: 960x540 on the GPU (RX 7900 XTX), at 3 to 4 camera positions per level. Files are in `out/shots/look/` (`v2_*`, `v3_*`, `v4_*`, `v5_*`, `final_*`; contact sheets `sheet_v2..v5.png`, `sheet_final.png`). I looked at every sheet and iterated 5 times. In the final pass each level reads as a different place: amber cellar, cold barracks, orange furnace haze, moonlit court with stars and moon shadows, teal wet vault with warm gold, crimson throne.
- **Frame time** (GPU, `viewport_get_measured_render_time_gpu`, median of 60 frames, 1920x1080; e1m1 / e1m4 court): Low 0.79/0.72 ms, Medium 2.58/2.34, High 3.93/3.59, Ultra 5.68/5.82. High is far inside the 16.6 ms budget. These rooms are still mostly empty of characters and props, so expect more once they are filled. The renders go through Xvfb with a software present, but GPU time is measured on the GPU.
- **Quality**: Low and Ultra side by side (`sheet_q.png`) keep the same mood. Low e1m4 is about 1.8x brighter because there is no SSAO or GI occlusion and auto-exposure reacts to the open sky. That is acceptable.
- **Auto-follow** (scratch SceneTree script): `Game.new_game("e1m3")` makes the rig apply (`env_is_rig=true`). A forced `ambient=3.0` plus `Settings.apply()` is restored to 1.0, and `start_level("e1m4")` re-applies with the moon.
- **Emblem**: `out/shots/look/emblem_fix.png` (close-up of the `emblem_crate` in `material_test.tscn`) shows clean face edges with no light seam. I did not capture a before-fix close-up.

## Deviations from the contract
- No per-level `.tscn`/WorldEnvironment resources. The look is JSON applied at runtime to the builder's `LevelEnvironment`, which keeps level-builder untouched and the looks diffable.
- FSR2/TAA/MSAA stay with `Settings` (viewport-level). I did not change them.
- The material remap belongs to integ-lead's "map level materials via material_map.json" task. Mine is a look-side fallback, inactive once real `.tres` materials are mapped. I also edited `emblem.gdshader` (shaders-materials), as the prompt permitted.

## Mistakes I made and how I fixed them
- I used the `LookRig` class name before the global class cache knew it, so the first shots silently rendered a grey screen. Fixed by running `tools/godot.sh --headless --path game --import` after adding the class_name.
- Fog density 0.025 and practicals with fog energy 1 gave blown-out haze blobs. Reduced the fog and gave practicals a lower fog energy.
- The moon flooded interiors because one-sided ceilings do not cast shadows from above. Fixed with double-sided shadow casting.
- `ceil.lamp_panel` (an emissive ceiling of 0.8 over whole rooms) washed e1m3/e1m4 to beige. Remapped it to a dim metal plate. The zone lights now carry the light.
- Auto-exposure lifted dark scenes to grey, which killed the mood. Capped `max_sensitivity` at 420.
- A LUT test used `ImageTexture3D.get_data()`, which is empty headless. Split the work into a static `lut_images()`.
- Preview cameras at cell centres sat inside decor cylinders and produced white blobs. Offset the cameras.

## Learnings for a future agent
- `fwidth()` of a `fract()`ed UV explodes on atlas seams; take derivatives from the continuous UV.
- Headless (dummy renderer) texture readback is empty, so test the CPU-side images.
- Godot fires `Events.level_loaded` twice per level (Game before the deferred build, the builder after it), so key on the builder's `built` signal.
- `shot.sh` only echoes lines matching `SHOT_|ERROR|Vulkan`, so print evidence lines prefixed with `SHOT_`. The default 90 frames is too few for a 40-frame warm-up plus a 60-frame measurement: use `--frames 160`.

## Requests for other modules
- **integ-lead**:
  - Instance `res://scenes/look_rig.tscn` once in `main.tscn` (sibling of LevelRoot). It auto-applies on every level load and settings change.
  - Then delete `RatMain._brighten`'s environment edits (ambient 3.0 / exposure 1.6). The rig re-asserts after them, but they fight it for 2 frames and double-light the hero's area. The hero `FillLight` can stay; 0.4 energy is enough now.
  - When you map `material_map.json` to real `.tres` files, see `materials` in `game/data/look/default.json` for my suggested library pairs.
- **godot-core**: `tests/shot.tscn` level-id mode (`Game.new_game`) has no look rig. Either instance `res://scenes/look_rig.tscn` there, or use the `look_rig.tscn` target as above.
- **level-builder**:
  - Do not emit ceilings for `ceil.sky` zones; the rig currently hides `Mesh_ceil_sky`.
  - Tag lights: `set_meta("look_kind", "zone"|"practical")` and `set_meta("zone", ch)`. The rig currently infers this from height (ceil-0.6) and the flicker meta.
  - Decor nodes could carry their `id` in meta so per-prop light tweaks (for example the green `glow_cheese` light in e1m1) can be addressed.
- **model-weapons-props**: the decor placeholders are emissive cylinders that read as white blobs. Real candelabra/torch/lamp meshes will matter most for the torchlit cellar.
- **shaders-materials**: FYI, I changed `emblem.gdshader` (AA width now comes from the continuous UV, one line plus a comment).
