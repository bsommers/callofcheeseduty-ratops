# player-controller report (2026-11-15T04:09:10Z)

## What I built
- `game/scenes/player.tscn`: CharacterBody3D `RatPlayer` (layer 2, mask world|enemy|door), capsule r 0.4 / h 1.9 (crouch 1.3), CameraRig, Weapons.
  Model seam `set_model(PackedScene|Node3D)`: loads `res://assets/models/hero.glb` (rotated 180°, clip names idle/walk/run/sprint/crouch_*/jump/fall/aim_*/death_a matched by suffix) else an orange capsule placeholder.
- `scripts/player/player.gd`: CS-style movement (walk 4.4, sprint 7.25, crouch 2.2 m/s, ADS x0.6, ACCEL 16 / FRICTION 12 exponential like the reference, air control, jump 4.6 m/s, no fall damage, no head bob), crouch with stand-up ceiling check,
  footsteps as `Events.sfx("footstep"|"footstep_sprint"|"footstep_crouch", pos)` per stride, land/jump sfx. Health/skill-scaled `take_damage(amount, source, hitbox)`,
  `player_hurt`, `health_changed(hp, lives)`, `player_died` exactly once per death (+ fallback `respawn()` after 2.5 s if nobody restarts the level). Reads `Game.loadout` on spawn,
  writes it back at the exit. Pickups: applies `Events.pickup_taken` (heal/overheal cap, extra life -> Game.lives, ammo, weapon); `can_take(kind)` for the reference refuse-when-full rule.
  `use()`: view ray (+ flat fallback ray, + exit trigger overlap) -> `interact(self)` on groups door/pushwall, exit_switch -> ancestor `LevelBuilder.complete_level()`.
  `RatPlayer.spawn_in_level(level)` places the hero at `level.player_start`. Tests/AI drive `cmd_*` fields with `use_device_input = false`.
- `scripts/player/player_camera.gd`: pivot -> SpringArm3D (sphere probe 0.22, mask world|door, excludes the player) -> Camera3D. Shoulder swap (`shoulder_swap`, default from Settings game/shoulder), hold-ADS (arm 2.6->1.7 m, FOV 70->48, slower look),
  mouse look (Settings input/mouse_sensitivity, invert_y), gamepad look (look_* actions, gamepad_sensitivity), recoil view offset.
- `scripts/weapons/weapon_system.gd` (`RatWeapons`) + `game/data/weapons.json` (reference numbers kept verbatim as dmg/period/spread/ammo/use/auto/loud/dps/stun; ref_* fields record the cell values):
  claws (cone 35°, 2 m, LOS), pistol/gatling hitscan (spread + move/air penalty, crouch/ADS bonus, CS spray pattern recoil with recovery, falloff after 40 m like the reference 10 cells,
  headshot x2.5, camera-centre aim + muzzle obstruction check, tracer, muzzle-flash OmniLight, impact spark, Decal bullet holes capped at 64), yarn bomber (`RatYarnBall` RigidBody on layer 4, 2 bounces, 2.2 s fuse, splash 3.5 m with LOS and falloff),
  Der Rote Punkt beam (55 dps, 14 cells/s, `stun(0.6)` if the enemy has it). Magazines (pistol 12, gatling 60) with reload; ammo pools per type shared like the reference; weapon_1..5/next/prev, auto-switch to best weapon when dry.
  Emits `weapon_changed(id)`, `ammo_changed(cur, reserve)`, sfx names = weapon ids, reload_<id>, dry_fire, claw_hit/claw_swipe, hit_flesh/headshot, ricochet/hit_wall, yarn_launch, explosion.
- `scripts/weapons/weapon_fx.gd` (tracer/flash/decal/explosion helpers). `game/tests/test_player.gd` (15 tests), `game/tests/player_walk.tscn` (scripted walk demo for shot.sh).

## Verification evidence
- `tools/run_tests.sh` -> `RESULT 54 passed, 0 failed` before the last test was added; `test_player` now 15/15, stable over 3 reruns. Covers structure, walk/sprint/friction/yaw-relative strafing, crouch/jump/no fall damage,
  skill-scaled damage, death-once (4 overkill hits -> 1 signal; respawn -> 2nd death -> 2nd signal), mag/reserve/reload/export, switch/cycle/pickup switch-up, head vs body hitbox + multiplier, wall decal,
  claws, yarn splash (layer 8 body, real physics flight), beam dps/stun/ammo, pickups, can_take, mock door/exit, and the REAL e1m1: spawn at player_start, use opens a real RatDoor, use at the real exit emits level_completed once with id e1m1.
- `tools/godot.sh --headless --path game --quit`: no errors/warnings.
- Screenshots (RX 7900 XTX): `out/shots/pc_e1m1_start.png` (over-right-shoulder view in e1m1 start room), `pc_e1m1_walk_fire.png` (ADS), `pc_e1m1_fire_123.png` (after walking 100 frames, gatling firing: muzzle flash rim-lights the hero;
  mean abs diff vs no-fire frame 0.013). Headless walk log: 3.6 m in the first second, gatling mag drained and shot hit the wall ahead.

## Deviations from the contract
- Speeds retuned: reference 3.4/5.6 cells/s would be 13.6/22.4 m/s at 4 m/cell; used 4.4/7.25 m/s (ratio 1.65 kept). Melee reach 1.15 cells -> 2.0 m, yarn splash 1.7 cells -> 3.5 m, speed 9 cells/s -> 24 m/s with light gravity (character scale, see weapons.json comment).
- Magazines/reload (pistol 12, gatling 60) are new (CS format); yarn and laser draw straight from the pool. Headshot multiplier 2.5 (laser 1.5) is new. No self-damage from the yarn splash (the reference projectile code was not checked for it).
- Player does NOT re-emit `pickup_taken`: RatPickup already emits it (Game scores treasure from it); the player only applies the effect.
- Extra life increments `Game.lives` from the player (Game ignores the item).

## Mistakes I made and how I fixed them
- Unowned weapons' magazines were filled from the shared pool on spawn (pistol reserve 0) -> only top up owned slots.
- Beam head multiplier applied per integer tick doubled damage -> multiplier applied to the accumulator.
- Aim used the pivot rotation from the last _process; in headless physics-heavy runs the pitch was stale -> `sync_rotation()` before every fire.
- First ADS framing hid the screen behind the body -> wider shoulder offsets (0.7 / ADS 0.8 m).
- Decal texture cached in a static var leaked at exit -> cached as meta on the level node.

## Learnings for a future agent
- In --script SceneTree tests, don't rely on _process having run between physics frames; apply transforms you query explicitly.
- Use inner classes (MockEnemy/MockDoor/MockLevel) in tests to exercise cross-module hooks without waiting for other agents.
- shot.sh renders the level's current camera when --cam is omitted, so a scripted demo scene is the easy way to show gameplay.

## Requests for other modules
- godot-core / level-builder: NOTHING SPAWNS THE PLAYER YET. After `build_level(id)` succeeds call `RatPlayer.spawn_in_level(level)` (or `load("res://scripts/player/player.gd").spawn_in_level(level)`) and keep it a child of the level root so Game's restart frees it.
- level-builder: RatPickup takes items even at full health / full ammo; call `body.can_take(item_id)` (if present) before emitting. Exit switch works via use() inside the trigger. e1m1 renders very dark from the player view.
- enemy-ai: implement `take_damage(amount: int, source: Node, hitbox: String)` on the node in group `enemy` (hitbox "head"/"body"/"splash"); mark heads with a collision shape/Area named "Head", group `hitbox_head`, or meta `head_y`; hitbox Areas must be on layer 3; optional `stun(sec)`. Hurt the player with `player.take_damage(dmg, self, "")` (group `player`).
  Weapon noise: RatWeapons emits `Events.noise(pos, radius_m)` if that signal exists (radius = reference loud x 4 m) — godot-core could add it.
- audio: Audio autoload leaks AudioStreamPlaybackWAV/AudioStreamWAV at exit when sfx are still playing ("3 resources still in use" in headless tests).
- ui: crosshair at screen centre (shots follow it); show `ammo_changed(cur, reserve)` (reserve 0 for pool-only weapons).
