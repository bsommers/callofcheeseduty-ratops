# botplay-qa report

## What I built
- `game/scripts/qa/qa_bot.gd` (`QaBot`): drives the real RatPlayer (cmd_move, rig yaw/pitch, `weapons.tick` through cmd_fire, `use()`), never fakes state. Follows a navmesh to keys (first), nearby pickups/weapon drops, optional pushwalls (`--secrets`), then the exit; shoots the nearest enemy it has LOS to; strafes while standing off; closes in with claws when out of ammo; stuck detector (1 s window, sidestep/jump/use, fail goal after 5); standoff breaker; per-level result JSON.
  The bot builds its own navmesh from level data exactly like LevelBuilder (cell polygons, shared corners) but treats locked doors without the key as walls, because the game's navmesh ignores locks.
- `game/scripts/qa/qa_run.gd`: `--script` runner. Boots `main.tscn`, calls `Game.new_game(level, skill)` (the call the title's New Game button makes), runs the bot, prints `QA_RESULT {json}`. Args `--level --limit --seed --skill --god --secrets`. Static `run_level()` is shared with the test.
- `game/scripts/qa/qa_log_capture.gd`: `Logger` subclass (OS.add_logger) counting engine errors/warnings and keeping the first 40 messages.
- `tools/qa.sh [e1mN|all] [--limit=S] [--seed=N] [--skill=0..3] [--god] [--secrets] [--shots]`: one Godot process per level (`--headless --fixed-fps 60`, fast and deterministic step), summary table, results in `out/qa/<level>.json|.log`; `--shots` calls `tools/shot.sh` at the exit.
- `game/tests/test_playthrough.gd`: e1m1, 25 simulated seconds at time_scale 4, asserts no engine errors, ran >5 s, made progress, not stuck.
- Result JSON per level: reached_exit, reason, sim_time, wall_s, kills/kills_total, deaths (+positions, nearby enemies), pickups by kind, keys, doors, shots/hits, stuck points (pos, frame, goal, blocker, nearby enemies), errors/warnings (+messages), frame ms avg/max, damage taken, game_stats.
- Modes: `--god` tops health up (flow QA, counts heals); default skill for qa.sh is 0 (Kitten). Bot has no cover logic, so skill 2 is far beyond it.

## Verification evidence
Latest runs (out/qa/god, skill0, skill2 hold the JSON):
- God mode (flow QA), all six levels reach the exit: e1m1 43 s, e1m2 84 s, e1m3 284 s, e1m4 70 s, e1m5 171 s, e1m6 252 s (sim seconds), 0 engine errors, frame time ~1 ms avg / 68 ms max (headless, no rendering).
- Skill 0 normal: exits e1m1, e1m2, e1m4; e1m3/e1m5/e1m6 time out after repeated deaths.
- Skill 2 normal: only e1m1; others game over (9 deaths) at the same ambush clusters.
- `tools/run_tests.sh playthrough`: PASS. Parse check `godot --headless --path game --quit`: clean.
- Looked at 3 exit shots (out/qa/e1m1|e1m3|e1m6_exit.png): see bugs 4 and 5.
- Runs are not bit-reproducible (enemy RNGs are per-instance and unseeded), so outcomes vary a little run to run; the bot seed only fixes the bot.

## Deviations from the contract
- None to ARCHITECTURE.md. Screenshots use `tools/shot.sh <level-id>` which renders the level, not the live run, with the camera put at the bot's final position/yaw.
- The pushwall routine is only exercised with `--secrets`; no level needs a pushwall to finish (flood fill confirms, exits reachable with keys), so I did not validate secret rooms. It uses `use()` on the wall and then stops.

## Bugs found (most severe first)
1. **Game.stats are corrupted at level end** (`game/autoload/game.gd` `complete_level`, line ~157 `stats.merge(extra, true)`; builder passes its static totals via `level_completed`). Observed final stats on e1m1: `treasure: 20.0, secrets: 3.0` (the level TOTALS, with 0 secrets found), `kills_total: 0`, `bonus: 98000`. `kills_total`/`secrets_total`/`treasure_total` are never set anywhere (grep), so "all kills" bonus and the intermission percentages are wrong. Repro: `tools/qa.sh e1m1 --god`, read `game_stats` in out/qa/e1m1.json. Fix: map builder `enemies/secrets/treasure` to `*_total` before merging and do not let `extra` overwrite the counters.
2. **Decals throw script errors** (`game/scripts/weapons/weapon_fx.gd:109`): `_decals = _decals.filter(func(o: Node)...)` returns an untyped Array, assigned to `Array[Node]` ("Trying to assign an array of type Array to Array[Node]"), and the lambda errors with "Cannot convert argument 1 from Object to Object" once a decal has been freed. Repeats on every wall hit (thousands of errors in a few minutes: 8136 in one e1m5 run), and decals stop being tracked. Repro: shoot a wall in a running level. Fix: rebuild with a loop into a typed `Array[Node]`, with an `is_instance_valid` test using a `Variant` parameter.
3. **Enemy density/damage beats the player at skill 2 and even at skill 0** (balance): the bot with a hit rate of ~45% dies 9 times per level at the same clusters at skill 2: e1m2 (56-64, 72-88), e1m3 (88-112, 72-128), e1m4 (24,32)/(56,48), e1m5 (56,88)/(24,120), e1m6 (104-112, 80-112). Groups of 5-8 enemies (mouse+trooper) engage at 15-20 m with hitscan. Not a code defect; the polish wave should check health/ammo placement near those spots and trooper accuracy at range.
4. **Exit switch panel renders as flat, fully bright green** (`wall.exit_switch` in `game/data/material_map.json` line ~196 / material setup): at the exit it fills the frame with an unshaded saturated green rectangle (e1m1, e1m6 shots). Looks like a placeholder, not photoreal. e1m6 also shows pure black beside it.
5. **Level render via `tools/shot.sh <level-id>` is unlit** (e1m3 shot: cream sky/ceiling missing, walls black, primitive pickups). Probably the shot tool path lacks LookRig/ceiling; check whether the real game shows the same (main.tscn LookRig). I did not verify in the live game.
6. **Locked doors are not in the game navmesh** (`level_builder.gd` `_build_navigation`): `NavigationAgent3D` paths of enemies or any future auto-nav cross locked doors. Low severity; the QA bot works around it.
7. Minor: enemy kills exceed `stats.enemies` (e1m3 51/22, e1m6 62/18) after deaths because restarts respawn everything and kills accumulate in `Game.stats` across restarts is not reset (the bot counts events). Check `_reset_stats` is invoked on restart (it is in `start_level`, so this is the bot's cumulative counter; no bug).

## Mistakes I made and how I fixed them
- Referenced autoload names (`Events`, `Game`) and a `class_name` from a `--script` SceneTree script: scripts compiled before autoloads exist. Fix: `load()` the bot lazily after one frame; look autoloads up through the tree.
- Queried the nav server right after creating a map: empty paths. Fix: wait ~8 physics frames after (re)building; add polygons only after setting vertices.
- `freed_node != null` is not a freed test in a Variant; used `is_instance_valid`. A cast of a freed pickup spammed errors and froze navigation for minutes.
- First assumed the game's navmesh could route keys; it routes through locked doors, so keys were never reached. Own navmesh with locks fixed it.
- Standoff loops (bot standing and strafing at an enemy it cannot kill, out of ammo): added claws close-in, ammo range limits and a 12 s standoff breaker.

## Learnings for a future agent
- Fast deterministic sim: `tools/godot.sh --headless --fixed-fps 60 ...`; tests use `Engine.time_scale`.
- `--script` mode: no compile-time autoload names in scripts loaded at startup; load them after a frame.
- The nav server needs several physics frames after creating or changing a region; `map_get_iteration_id` is not enough.
- Player API for bots: `use_device_input=false`, set `cmd_move/cmd_fire/cmd_fire_pressed`, `rig.yaw/pitch` then `rig.sync_rotation()`.
- Level builder exposes `nav_region`, `data`, `keys_held`, `exit_area`, `exit_cell`, `cell`, `_is_walkable()`.

## Requests for other modules
- godot-core: fix bug 1 (Game stats) and expose a `Game.level_stats()` or fixed keys so tests need not guess.
- weapons owner: fix bug 2 (decals).
- level-builder: optional `NavigationRegion3D` that excludes locked doors until the key is held (bug 6), plus a stable `level.pickups()` helper.
- look-dev/materials: exit switch material (bug 4), and confirm bug 5 in the live game.
- Everyone: seed `RandomNumberGenerator` in enemies from a project seed so QA runs are reproducible.
