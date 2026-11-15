# integ-lead report
Stages done: **A**. Stage B not started (model-rats / model-weapons-props / enemy-ai reports absent).

## What I built
- `Events`: hit_marker, crosshair_spread, enemy_alerted, enemy_hurt, door_locked, noise.
- `Settings.apply()` now calls `SettingsMenu.apply_display()` (fullscreen/resolution).
- `autoload/audio.gd` reduced to an empty stub (project.godot not owned, so the autoload name stays); `AudioManager` is instanced in main.tscn.
- `main.tscn` + `scripts/integration/main.gd` (RatMain): instances UIRoot + AudioManager, spawns `RatPlayer.spawn_in_level` on the level's `built` signal, applies HeroSetup, lifts dim lighting (ambient x3, exposure 1.6, shadowless fill light on the hero).
- `scripts/integration/hero_setup.gd` (HeroSetup): loop flags, hide `*_LOD1`, fur shells on `fur` slot (length mask + albedo colour map), `WeaponHand` BoneAttachment3D on RightHand, `equip()` helper for stage B.
- Texture imports: mipmaps on for all 131 `assets/textures/**/*.import`.
- `tests/test_integration.gd` (4 tests).
- Level materials: level_builder already maps via material_map.json to library .tres; nothing needed.

## Verification evidence
- `tools/run_tests.sh`: 64 passed, 0 failed (one expected 'unknown level zzz' ERROR line from a game-state test). Parse check clean.
- Screenshots (looked at): out/shots/integ_title.png (title menu), integ_e1m1.png (very dark), integ_e1m1c.png (after lighting lift: HUD, level card, furry hero visible).

## Deviations from the contract
- Lighting tweak lives in main.gd rather than the level builder.
- Audio autoload kept as stub rather than removed.

## Mistakes I made and how I fixed them
- First parse check failed on HeroSetup: class cache stale; fixed with `--import`.

## Learnings for a future agent
- Game calls build_level deferred; wait for the level's `built` signal before spawning.
- shot.sh works with res://scenes/main.tscn and `--user-arg --level=e1m1`.

## Requests for other modules
- level-builder: raise ambient/fill lighting in level data, then delete `_brighten` in main.gd.
- player-controller: emit hit_marker/crosshair_spread/noise now that Events has them; hero is rendered by the shell-fur chain on a skinned mesh, check the pose in the first-person-ish camera.
- project.godot owner: remove the `Audio` autoload line.

## Stage B (done)
- main.gd: after build -> `RatPlayer.spawn_in_level`, `HeroSetup.apply`, `PropSetup.apply(lvl)`, `RatEnemySpawner.spawn_in_level(lvl)` + `RatModelSetup.hook` per enemy; weapon model swap on `Events.weapon_changed`.
- `scripts/integration/rat_setup.gd`: rat fur shells (LOD0) / single-pass fur (LOD1 beyond 16 m via visibility_range), skin/cheese slot materials, loop flags, flash light+sphere on Right/LeftMuzzle bones synced to enemy's MuzzleFlash.
- `scripts/integration/prop_setup.gd`: decor placeholders -> prop_*.glb (15 ids mapped; unmapped ids like plant/puddle/alarm_light/fish_bones keep placeholders).
- `HeroSetup.equip_weapon(model,id)`: weapon_<id>.glb under WeaponHand, Grip at hand. Weapon orientation relative to hand bone not visually verified (hero seen from behind).
- hero.glb already faces -Z: player.gd rotates it by PI (player-controller's file); HeroSetup.apply resets model yaw to 0. Player-controller should remove that PI line.
- Audio autoload + autoload/audio.gd removed. main.tscn now instances look_rig.tscn; the ambient/exposure hack was removed (fill light kept).
- Tests: integration 4/4; full suite only fails test_audio all_streams_load (music_boss/title/victory streams missing, audio/assets-fetch issue).
- NOT done: scripted full e1m1 playthrough to the exit.
