# godot-core report (2026-11-15T03:48:15Z)

## What I built
- `game/project.godot`: Godot 4.7 Forward+ (Vulkan), 1920x1080 resizable, `canvas_items` stretch, vsync on, Jolt physics @60 Hz,
  physics layer names 1-7 (world..door), full InputMap (section 4 + look_*, shoulder_swap; keyboard/mouse + gamepad), quality knobs
  (4K directional shadows, soft shadows, SSAO/SSIL/SSR quality, volumetric fog volume, SDFGI convergence, TAA + debanding).
- Autoloads: `Defs` (port of reference defs.js: enemies, items, weapons, projectiles, decor, walls, doors, things, skills, levels+par, start, scoring),
  `Events` (all 11 contract signals + state_changed, level_loaded, level_requested, score_changed, key_taken, settings_changed, paused_changed, sfx, music),
  `Settings` (ConfigFile at user://settings.cfg; presets Low/Medium/High/Ultra apply SDFGI/SSR/SSAO/SSIL/fog/shadow size+filter/MSAA/TAA/FSR scale;
  `apply_to_environment(env)`, `apply_to_viewport`, `apply_to_light`), `Game` (state machine TITLE/PLAYING/PAUSED/INTERMISSION/GAME_OVER/VICTORY
  with legal-transition table, lives 9, score, level index, death restores level-start score+loadout, intermission bonus, level load by id).
  `Audio` is listed in project.godot but owned by another agent.
- `Game.start_level(id)` instantiates `res://scenes/level_base.tscn` (fallback: `scripts/level/level_builder.gd`, then an empty Node3D),
  sets meta/property `level_id` and defers `build_level(id)` (or `load_level(id)`). Levels are parented under the node given to `Game.set_level_parent()`.
- `game/scenes/main.tscn`: LevelRoot + placeholder title (level buttons built in code). `-- --level=e1m1` skips the title.
- Tests: `game/tests/run_all.gd` (SceneTree runner, PASS/FAIL per method, non-zero exit), `test_case.gd` base, `test_defs.gd`
  (compares hp/score/speed/heal against reference defs.js text), `test_settings.gd`, `test_game_state.gd`; `tools/run_tests.sh [filter]`.
- Screenshots: `tools/shot.sh <scene.tscn|level-id> <out.png> [--cam x,y,z,yaw,pitch] [--size WxH] [--frames N] [--fov deg] [--user-arg --k=v]`
  with harness `game/tests/shot.tscn`; `game/tests/img_stats.gd` (numeric mean/stddev/diff of PNGs); demo `game/tests/demo_room.tscn`.

## Screenshot method (and limits)
Private `Xvfb -displayfd` server (picks a free display, never :0; WAYLAND_DISPLAY unset), Godot X11 + Vulkan. Xvfb has no DRI3, so RADV
reports no present queue and Godot silently falls back to **llvmpipe**; fixed with `MESA_VK_WSI_DEBUG=sw` (Mesa presents via CPU copy)
plus `--gpu-index ${SHOT_GPU:-0}` (device 0 = RX 7900 XTX; 1 = R9700, 2 = iGPU). All rendering is on the GPU; the frame is read back
from the viewport after N frames (default 90, lets SDFGI/fog/TAA converge) and saved by Godot. shot.sh warns if llvmpipe is used.
Limits: presentation is a CPU copy (fine for stills, not for fps measurement); no weston/cage on this machine; --cam yaw/pitch in degrees,
yaw 0 looks -Z; the shot camera is re-made current every frame so a level's player camera cannot steal it.

## Verification evidence
- `tools/run_tests.sh` -> `RESULT 17 passed, 0 failed` (the one ERROR line is the intentional unknown-level test).
- `tools/godot.sh --headless --path game --quit` and a 120-frame headless boot of main.tscn with `--level=e1m1`: no errors/warnings.
- Demo room on RX 7900 XTX (`out/demo_on.png`, 1280x720, looked at: sun shaft through window in fog, red/blue colour bleed, glossy floor
  reflecting the emissive cube and chrome sphere). Mean abs diff vs feature-off renders: SDFGI off 0.058, fog off 0.067, SSR off 0.0025
  (localised floor reflections); identical rerun diff 0.0000, so the deltas are real. `out/shot_e1m1.png` (level-id path) lum stddev 0.12.

## Deviations from the contract
- Intermission bonuses (`Defs.SCORING`: 10000 per 100% kills/secrets/treasure, 500/s under par) are NOT in the reference; invented Wolfenstein-style.
- Extra InputMap actions: look_up/down/left/right (gamepad stick), shoulder_swap. Extra Events signals listed above (additive).
- Tests extend `"res://tests/test_case.gd"` by path, not class_name (global class cache is cold in fresh checkouts); run_tests.sh runs `--import` first.

## Mistakes I made and how I fixed them
- First shot rendered on llvmpipe without error (only the device line showed it) -> sw WSI + explicit gpu index + llvmpipe warning.
- Game first deferred `build(id)`, but LevelBuilder.build takes a Dictionary -> now calls `build_level(id)`.
- Settings persistence test initially could have written the user's real settings.cfg -> writes only to a temp path with persist toggled.

## Learnings for a future agent
- Autoloads ARE available in `--script` SceneTree runs (after one process_frame).
- Always grep shot.sh output for the "Using Device" line; llvmpipe fallback is silent.
- Compare renders numerically with img_stats.gd instead of viewing every PNG.

## Requests for other modules
- level-builder: keep `build_level(id) -> bool` stable (Game calls it deferred); emit `Events.level_completed(stats)` at the exit switch and
  fill kills_total/secrets_total/treasure_total so Game's bonus works.
- ui: replace the placeholder title in main.tscn by connecting to `Events.state_changed`; call `Game.new_game(id, skill)`, `Game.next_level()`, `Game.quit_to_title()`.
- player-controller: emit `player_died` once per death; Game restarts the level and restores `Game.loadout` (read it on spawn).
