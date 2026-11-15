# enemy-ai report (2026-11-15T04:22:18Z)

## What I built
- `game/data/enemies.json`: the six kinds (mouse, trooper = SMG rat, officer, sewer, panzer, boss "Der Große Käse") ported from `reference/kasekrieg/defs.js` (hp, score, pain chance, reaction, attack kind/dmg/shots/gap/windup/cooldown, drop, sfx, boss phase2), plus the tuning from `sim/enemies.js` (sight 24 cells, ±70° cone, feel/shout/gunfire ranges, hitChance formula, patrol x0.55, boss stun x0.3 with 2 s immunity, cheeseball projectile). Reference values are kept as `ref_*`; metre values sit next to them.
- `game/scripts/enemy/enemy.gd` (`RatEnemy`, CharacterBody3D, group `enemy`, layer 3, mask world|player|enemy|door): a state machine with idle, patrol, alert, chase, attack, take_cover, retreat and dead. Pain flinch and laser `stun(sec)` are timers that pause it. It has:
  - a vision cone, feel range and a LOS raycast (world and doors block; characters do not)
  - hearing through `Events.noise(pos, radius)` (walls halve the radius); the first alert shouts to friends, and gunfire alerts friends too
  - a skill-scaled reaction delay (`Defs.SKILLS.reaction`) and accuracy (the reference hitChance times skill_mul 0.7/0.85/1.0/1.15)
  - a NavigationAgent3D path on the level navmesh, with straight steering as a fallback
  - cover search over rings of 2.5 to 10 m, keeping points the player cannot see at crouch height; troopers strafe inside their preferred distance and retreat when badly hurt
  - sewer melee, the panzer cheeseball, and boss phase 2 below 50% (0.9 s taunt, speed x1.3, 3-ball 14° volleys alternating with 8-shot bursts, summons 2 sewer rats and then 1 every 9 s up to 3; on the boss's death they die quietly)
  - `take_damage(amount, source, hitbox) -> int`, which emits `enemy_hurt`, `enemy_alerted` and `enemy_killed` (the kill exactly once) and drops the reference loot as a RatPickup (a weapon the player lacks first, else the last option)
  - a `set_model(path|PackedScene|Node3D)` seam: it loads `rat_<kind>.glb` and falls back to a tinted capsule; LOD1 meshes are hidden; clips are played by name with a fallback chain; idle, walk, run, aim_idle, charge and take_cover are set to loop
- `enemy_projectile.gd` (`RatCheeseball`): a swept ray, with direct hit or splash (LOS and falloff) into `player.take_damage(dmg, shooter, "splash")`.
- `enemy_spawner.gd` (`RatEnemySpawner`): `create`, `spawn`, and `spawn_in_level(level)`, which reads `LevelBuilder.enemy_spawns` (or Marker3D nodes in group `enemy_spawn`). It is idempotent per level.
- `game/scenes/enemy.tscn`: root, Body capsule, `Head` Area3D (layer 3, group hitbox_head) and `Nav`. Sizes are set per kind in code.
- `enemy_demo.gd`: a scripted encounter for `tools/shot.sh`, started by loading `enemy.tscn` with `--user-arg --enemy_demo=<level>`, plus optional `--demo_kind`, `--demo_view=shoulder|close` and `--demo_dist`.
- `game/tests/test_enemy.gd`: 13 tests.

## Verification evidence
- `tools/godot.sh --headless --path game --script res://tests/run_all.gd -- test_enemy` → 13 passed, 0 failed, with no warnings or errors in the log. The full suite gives `RESULT 79 passed, 0 failed`. `--quit` parse check: 0 errors or warnings.
- The tests cover:
  - the json matching Defs.ENEMIES
  - the scene seam (layer, Head, head_y, glb clips, loop flag, placeholder fallback)
  - body and head damage, and RatWeapons.hitbox_of/find_enemy on real rays
  - one death signal and no damage after death; mouse drops ammo_clip and trooper drops gatling
  - the vision cone, feel range and a wall blocking LOS
  - noise heard near and ignored far
  - idle→alert→chase→attack, then lost→idle, the shout alerting a friend, and patrol walking
  - hit chance by distance, speed and skill; the trooper hurting a mock player through take_damage
  - the sewer rat closing in and biting
  - the panzer cheeseball splash dealing 14..28
  - cover hidden from the player, then take_cover→chase
  - boss phase 2: 2 minions, a shortened stun, a volley, one kill signal with minions dying quietly
  - real e1m1: 19 enemies, one per marker, idempotent, nav map ready, a nav path between spawns
- Screenshots (RX 7900 XTX), which I looked at:
  - `out/shots/enemy-ai/e1m1_shoulder.png`: a sewer rat charging the hero in the e1m1 start area (run clip)
  - `e1m1_mouse_close.png`: the mouse rifleman in aim_idle aiming at the hero
  - `e1m6_boss.png`: Der Große Käse in his hall, facing the hero

## Deviations from the contract
- Scripts live in `game/scripts/enemy/` (the task prompt) rather than `scripts/enemies/` (ARCHITECTURE section 3).
- Distances use 1 cell = 4 m; move speeds use x1.294, the same scale as the player, so the mouse moves at 1.94 m/s and the sewer rat at 4.66. Melee reach is 0.95 cells → 1.7 m. The cheeseball moves at 5.5 cells/s → 14.7 m/s with a 1.1 cells → 2.3 m splash. Preferred distances are x4.
- The headshot multiplier is applied by the caller: RatWeapons already multiplies by 2.5 before calling take_damage. `RatEnemy.head_receive_mult` defaults to 1.0 to avoid doubling it (set it to 2.5 for callers that do not pre-multiply).
- New behaviour beyond the reference: cover, retreat, and strafing in the comfort band.
- No ragdoll yet. Kills play death_a or death_b and the corpse loses its collision layers.
- Hearing uses a simple LOS-halved radius, not the reference's flood-fill sound mask.

## Mistakes I made and how I fixed them
- I resized the Head SphereShape3D from enemy.tscn in place. Scene sub-resources are shared, so every enemy's head changed size. I now create a new shape per instance.
- `_nav_ready()` returned true for the default world map with no regions. Every cover candidate then snapped to (0,0,0) and cover was never found. It now also requires at least one region.
- The deferred "face the longest corridor" call overrode the yaw set by the tests. I added a `yaw` option to configure().
- The test compared JSON numbers as strings (`1.0` vs `1`). It now compares numbers.

## Learnings for a future agent
- `tools/shot.sh` only echoes lines with SHOT_, ERROR or Vulkan, so print() output from a demo is invisible. Look at the PNG.
- `NavigationAgent3D.get_current_navigation_path()` stays empty until `get_next_path_position()` is called once after setting target_position.
- Driving `RatEnemy.tick(dt)` by hand with `auto_tick=false` (a spawn option) makes AI tests deterministic. Seed with opts.seed.

## Requests for other modules
- **godot-core / integ-lead:** nothing spawns enemies in the game flow yet. In `scripts/integration/main.gd` `_spawn_player` (on LevelBuilder.built), also call `RatEnemySpawner.spawn_in_level(lvl)`. Optionally apply rat fur/materials on `RatEnemy.model_ready` and attach muzzle flashes to the `RightMuzzle` bone (my flash is a fixed OmniLight near the gun).
- **player-controller / model-hero:** in the demo shots the hero model faces the camera even though the body yaw looks at the enemy (-Z forward). `set_model` rotates hero.glb by PI, but model-rats reports their glbs already face -Z. Please check whether hero.glb also faces -Z now.
- **audio:** sfx names used: the per-kind alert/pain/die/fire names from Defs, plus `cheese_splat`.
- **level-builder:** spawn markers have no facing angle. Enemies face their longest open corridor, as the reference longestRunAngle does.
