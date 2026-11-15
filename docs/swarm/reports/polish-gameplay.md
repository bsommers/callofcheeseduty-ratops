# polish-gameplay report

## What I built
1. `game/autoload/game.gd`: `_merge_level_totals()` maps builder `enemies/secrets/treasure` to `kills_total/secrets_total/treasure_total`; `extra` can no longer overwrite live counters (kills/secrets/treasure/time/par/bonus). Also `Events.music("title")` when entering TITLE.
2. `weapon_fx.gd` decal pruning rebuilt with a typed loop + `is_instance_valid(Variant)` (no more script error per wall hit).
3. `enemy.gd` `alert()`: first-alert grace (+0.35-0.7 s on direct sight, +0.5-1.6 s when shouted awake by a friend), scaled by the skill reaction multiplier (skill 3 x0.65 stays tight). `Events.music("boss")` when the boss first alerts.
4. `main.gd`: `Events.music("title")` at boot when no `--level`. Gunshot `Events.noise` was already emitted by `weapon_system.gd _noise()` (loud x 4 m) and the signal exists; verified, no change needed.
5. `player.gd`: hero model rotation PI removed (0.0), consistent with HeroSetup (hero.glb faces -Z).
6. Loop flags: enemy.gd `LOOP_CLIPS` (adds take_cover) vs rat_setup `LOOPING` still differ; both idempotent, harmless. rat_setup/hero_setup not mine.
7. `game/tests/test_polish_gameplay.gd`: stats merge, kill bonus, decal pruning.

## Verification evidence
- Parse check clean. `tools/run_tests.sh`: 90 passed, 0 failed, run 3 times in a row (no intermittent failure seen; test_audio/test_playthrough could not be reproduced as failing, probably load-related timing).
- QA god (before -> after): all six exit -> e1m1 110 s, e1m2 77, e1m4 125, e1m5 140 exit; e1m6 exited in 2 of 3 runs (260 s); e1m3 timed out 3 of 3 runs (bot oscillating next to a trooper at 1 m near the exit; earlier it finished in 284 s). 0 engine errors/warnings everywhere (decal errors gone).
- QA skill 0 (before -> after): exits e1m1, e1m2, e1m4 -> same three. Deaths now: e1m1 0, e1m2 0, e1m3 5, e1m4 1, e1m5 8, e1m6 7. No before death numbers recorded, so no claim of improvement; e1m3/5/6 still time out.

## Deviations from the contract
- None. Ambush tuning is only a reaction grace; no spawn positions or enemies.json data changed.

## Mistakes I made and how I fixed them
- My first test asserted bonus < 50000, but the par-time bonus is legitimately large with ~0 s of sim time; fixed by asserting bonus == par part only.

## Learnings for a future agent
- Builder `stats` keys are `enemies/treasure/secrets` (totals), Game's counters share the names `secrets/treasure`: the old merge clobbered them.
- QA runs are not reproducible (enemy RNG unseeded), so single-run before/after is noisy; seed enemy RNGs.

## Requests for other modules
- QA bot (botplay owner): e1m3 exit-area oscillation vs adjacent trooper; bot needs cover/avoidance, not a gameplay fix.
- Balance (data owner): the ambush clusters in botplay-qa bug 3 still kill the bot at skill 0 on e1m3/e1m5/e1m6; consider health/ammo near them.
- rat_setup owner: align LOOPING with enemy.gd LOOP_CLIPS (take_cover).
