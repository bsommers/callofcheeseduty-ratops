# fix-gameplay2

## e1m3 QA bot
- Root cause: bot nav paths (zero-radius funnel) hugged wall-cell corners, e.g. door d_26_5 corner at (108.4, 24.1); capsule snagged on WorldCollision repeatedly (~150 s lost, exit at 400/420 s).
- Fix (game/scripts/qa/qa_bot.gd): `_clear_corners()` pushes intermediate waypoints on grid vertices 0.9 m away from adjacent blocked cells. e1m3 now exits in ~160-270 s.
- Also found e1m6 flaky (boss arena fought with claws after ammo ran out, blocked by sewer minions): in --god mode the bot restocks "hair" ammo when dry; non-god bot also detours 4x for ammo pickups when dry.

## Anim loop flags
- rat_setup.gd `LOOPING` now aliases `RatEnemy.LOOP_CLIPS` (single source: idle, walk, run, aim_idle, charge, take_cover); attacks/death/hurt do not loop.
- hero_setup.gd `set_loops` parsed clip names in the wrong order (and without lowercasing), so hero loop flags could be missed; now parses `|` then `/` and lowercases like enemy.gd.

## Results
- tools/run_tests.sh: 90 passed, 0 failed.
- tools/qa.sh all --god: e1m1-e1m6 all exit (64-203 s sim).
- Not committed. No art/assets touched.
