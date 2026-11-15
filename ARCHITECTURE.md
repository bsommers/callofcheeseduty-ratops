# ARCHITECTURE — RAT OPS (working title; repo `callofcheeseduty-ratops`)

Binding contract for all agents. Short on purpose; deviations go in your report's "Deviations" section.

## 1. What this is
A **third-person, CS:GO-style tactical shooter** with **photoreal, modern graphics**, built on the *same game* as KÄSEKRIEG
(`reference/kasekrieg/`, the 2.5D ray-traced predecessor): same hero (Major Marmalade, big orange tabby, nine lives), same
enemy faction (Das Rattenreich: rats and mice in WWII-style uniforms), same cat- and cheese-themed world, same six
levels (layouts in `reference/kasekrieg/levels/e1m1..e1m6.js`), same weapons, items, keys, doors, secrets, boss, scoring.
What changes: full 3D, third-person over-the-shoulder camera, CS:GO-flavoured gunplay (recoil/spray patterns, accuracy
penalty while moving, crouch, hold-to-ADS, reload, weapon swap, headshot multiplier, footstep audio), and photoreal rendering.
Enemy emblem = black cheese wedge in a white disc on red. **No swastikas or real Nazi insignia, ever.**
Title text in-game: `KÄSEKRIEG: RAT OPS`. Do not use third-party trademarks in game text or assets.

## 2. Engine and tools (decided)
- **Godot 4.7.2** (MIT), GDScript, Forward+ (Vulkan) renderer. Editor binary: `tools/godot.sh` (project-local, `.tools/`, not in git).
  Project root = `game/` (`game/project.godot`). Exports: Linux x86_64, Windows x86_64, macOS universal (templates installed later by the build agents).
- **Blender 5.3** (snap, headless: `blender -b -P script.py`) authors meshes/rigs/animations as **glTF (.glb)** into `game/assets/models/`.
  Source scripts live in `tools/blender/` so every model is reproducible from text.
- **Textures/HDRIs**: only CC0 sources (Poly Haven, ambientCG), fetched by `tools/fetch_assets.mjs` from a manifest into `assets-cache/`
  then copied (resized) into `game/assets/`; every file recorded in `docs/ASSETS.md` with source URL and license. Disk: `/` is nearly full, so heavy/regenerable data lives on `<big-disk>/` via symlinks in the repo (`assets-cache`, `out`, `build`, `dist`, and `~/.local/share/godot/export_templates`). Put any new large output (previews, exports, caches, downloads) there; budget 6 GB for committed-path assets (`game/assets/`), 2K textures max.
- **No other dependencies.** Node 26 for tooling (zero npm deps). Blender and Godot only.
- Real-time hardware ray tracing is not available in Godot; "ray-traced look" = SDFGI/VoxelGI + SSR + SSAO + SSIL + volumetric fog + reflection probes + contact shadows.

## 3. Repo layout and ownership
```
game/                  Godot project (res://)
  project.godot        owner: godot-core
  autoload/            Game, Events, Settings, Audio  (godot-core)
  scenes/              main.tscn, player.tscn, enemy_*.tscn, level_base.tscn
  scripts/player/      player controller, camera, weapons   (player-controller)
  scripts/enemies/     AI, perception, animation glue       (enemy-ai)
  scripts/level/       level_builder.gd, doors, pickups     (level-builder)
  scripts/ui/          HUD, menus                           (ui)
  assets/models|textures|audio|hdri|materials|fonts|shaders
  data/levels/*.json   converted from reference levels      (level-builder)
tools/                 godot.sh, shot.sh, fetch_assets.mjs, blender/, swarm-tracker/
reference/kasekrieg/   READ-ONLY predecessor code (rules, balance numbers, level grids)
docs/                  ARCHITECTURE (this file), ASSETS.md, swarm/ (manifest, prompts, reports, progress), LEARNINGS.md, CHECKPOINT.md
```
Only the owner of a path edits it. Shared defs live in `game/autoload/defs.gd` (godot-core) — a port of `reference/kasekrieg/defs.js`
(weapon table, enemy table, item table, scoring). Gameplay NUMBERS come from the reference (hit points, damage, speeds); do not retune
unless the third-person format forces it, and note it.

## 4. World, units, conventions
- 1 grid cell of the reference levels = **4.0 m**. Wall height **3.6 m** (up to 6 m in halls/vaults; `ceilH` per zone). Y up, -Z forward. 1 unit = 1 m.
- Characters: the hero is a bipedal large orange tabby, 1.9 m tall; enemies 1.5–1.8 m (mouse smallest, 1.4 m), panzer rat 2.2 m, boss 3.2 m. Capsule radius 0.4 m, height per above.
- Physics layers: 1 world, 2 player, 3 enemy, 4 projectile, 5 pickup, 6 trigger, 7 door. Collision shapes are simple (box/capsule/trimesh for static).
- Input actions (InputMap names): move_forward/back/left/right, jump, crouch, sprint, fire, aim, reload, use, weapon_1..5, next_weapon, prev_weapon, pause, map.
  Gamepad supported. Mouse look default; sensitivity in Settings.
- Signals are the integration seam: `Events` autoload (`game/autoload/events.gd`) declares every cross-module signal; modules emit/connect there rather than
  holding references to each other. Required signals: `player_hurt(dmg)`, `player_died`, `enemy_killed(kind, pos)`, `pickup_taken(kind, amount)`,
  `weapon_changed(id)`, `ammo_changed(cur, reserve)`, `health_changed(hp, lives)`, `door_opened(id)`, `secret_found`, `level_completed(stats)`, `message(text)`.
- Scenes are text (.tscn); prefer building structure in code when a .tscn would be an unreadable blob. Never commit `.godot/`.

## 5. Rendering target (photoreal)
Forward+; WorldEnvironment per level with: filmic/ACES tonemap, SDFGI (or VoxelGI for small rooms), SSR, SSAO, SSIL, volumetric fog, glow/bloom,
auto-exposure, sky from CC0 HDRI, ReflectionProbes in rooms; DirectionalLight3D with PSSM shadows; OmniLight/SpotLight shadows for practical lights;
FSR2 or TAA, MSAA 4x option. Materials are PBR (albedo/normal/roughness/AO/metallic, parallax where cheap). Fur: shell-texture shader on cat and rats
(`game/assets/shaders/fur.gdshader`), subsurface scattering on ears/skin, cloth with normal/roughness maps for uniforms, wet/greasy surfaces in sewers.
Cheese: dedicated `cheese.gdshader` (holes via noise-driven normal/alpha, waxy rind, SSS glow, gloss) — it is the signature material.
Quality presets Low/Med/High/Ultra in Settings; the game must hold 60 fps at 1080p High on an RX 7900 XTX and run (slower) on Low everywhere.
Target resolution: high-res, native 1080p–4K, UI scaled by `content_scale`.

## 6. Gameplay contract (port, do not reinvent)
6 levels e1m1..e1m6 with the same room structure, keys (gold/silver), locked doors, pushwalls/secrets, pickups, treasure, exit switch, boss on e1m6.
Weapons (ids from reference defs): Claws (melee), Hairball Pistol, Purr-forator, Yarn Bomber, Der Rote Punkt. Enemies: mouse rifleman, SMG rat, officer,
sewer rat, armoured (panzer) rat, boss (Der Große Käse). Lives 9; death restores level-start score/weapons. Intermission stats card. Victory screen after level 6.
New third-person systems: over-shoulder camera with shoulder swap and ADS zoom, cover-aware enemy AI (flank, take cover, suppress), headshots, ragdoll on kill,
bullet decals, muzzle flash lights, tracer, dynamic audio occlusion (reverb zones by room).

## 7. Testing and evidence
- Logic tests run headless: `tools/godot.sh --headless --path game --script res://tests/run_all.gd` (godot-core provides the runner; tests are `tests/test_*.gd`).
- Visual evidence: `tools/shot.sh <scene|level> <out.png> [--cam x,y,z,yaw,pitch]` renders a real frame with the GPU and writes a PNG
  (godot-core implements it; method decided by that agent — must not open a window on the user's desktop). Look at screenshots before claiming a look is done.
- Every agent writes `docs/swarm/reports/<id>.md` and checkpoints in `docs/swarm/progress/<id>.md` (see manifest preamble).
