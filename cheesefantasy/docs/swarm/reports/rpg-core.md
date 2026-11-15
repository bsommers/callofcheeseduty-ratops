# rpg-core report

## What I built
- `game/project.godot`: Forward+, 1920x1080 resizable, canvas_items stretch, all input actions, 5 autoloads.
- Data (`game/data/`): `characters.gd` (4 heroes, growth to L30, learn tables), `skills.gd` (80), `enemies.gd` (26 + 3 bosses with phases),
  `items.gd` (47 items + 42 ingredients incl. 7 cheese wheels), `recipes.gd` (40 recipes + mystery_mush), `world.gd` (4 summons,
  28 encounters, 4 shops with flag unlocks, 10 quests, 13 areas). `db.gd` (`class_name DB`) holds rules/formulas, lookups, recipe
  matching, cook quality, dish effects, and `validate()`. `ids.md` lists every id and the APIs.
- Autoloads: `Data` (re-exports DB, adds dishes to ITEMS, loads DIALOGUE json), `Events` (contract signals + level_up/game_loaded/game_saved),
  `GameState` (party/inventory/gold/flags/quests/recipes/summons, apply_battle_result, shop_stock, JSON save/load + save_info),
  `Settings` (user://settings.cfg), `Audio` (sfx/music by id, silent fallback, creates Music/Sfx buses).
- `BattleEngine` (`scripts/battle/battle_engine.gd`): pure, seeded, CT turn order, Attack/Skill/Cook/Item/Summon/Guard/Flee, Flavor Chain,
  Fondue Gauge, 10 statuses, 10 enemy AI patterns, boss phases, spawns, gold theft, party auto-AI (`auto_command`, `run_auto`). Formulas are in the header.
- `ActorFactory` + `ActorRig` (`scripts/actors/`): glb loader with clip-name normalisation, idle fallback, tint, height normalising, and a procedural
  placeholder that has every clip.
- Tests: `tests/run_all.gd`, `test_data/test_battle/test_state/test_actors.gd`, `balance_report.gd`, `dump_ids.gd`; `tools/run_tests.sh`.
- `tools/shot.sh` + `tests/shot.gd/.tscn`: private Xvfb, Vulkan on the real GPU. Targets: scene path, `model:<id>`, or `title`; `--start <arg>` calls root.start(arg).
  Prints mean/std luminance so you can spot a blank frame.
- `scenes/main.tscn` (boot -> title -> farm.tscn, or a placeholder farm if that file is missing) and `scenes/ui/title.tscn` (code-built title with a turning cheese wheel).

## Verification evidence
- `tools/run_tests.sh`: **21 passed, 0 failed** (1.8 s). All 28 encounters x 12 seeds end with no timeouts. Same seed gives the same result.
- Balance (40 seeds, party at the encounter's level, tier gear): normal battles win **89.2%** overall, lowest is 65% (pasture_rats, hill_ninjas).
  At level+1 (20 seeds): Crow Baron 9/20, Mold Dragon 19/20, Rat King 12/20.
- Shots: `out/shots/title.png` (1280x720, std 0.136, I looked at it and it reads well), `out/shots/fennel.png` (model stage, std 0.075), `out/shots/main.png`.
  All three rendered on the RX 7900 XTX (RADV) through Xvfb. No desktop window was opened.
- The existing glbs (heroes, enemies, bosses) load through ActorFactory and have every contract clip.

## Deviations from the contract
- The rules live in `DB` (static class). `Data` re-exports them so the engine and tests run without autoloads. `Data.ITEMS` is a `var`, not a `const`, because it merges in the dishes.
- I added Events signals `level_up`, `game_loaded`, `game_saved`.
- `moldy_scarecrow` uses the `npc_scarecrow` model.
- The title and main scripts are built into their .tscn files, because `scripts/ui/` is not mine.
- result() also includes `party`, `used_items`, `gauge`, `discovered`, `encounter`, `turns`. `drops` is an Array of id strings.

## Mistakes I made and how I fixed them
- I used the global `DB` class before the class cache existed, and the autoloads failed to parse. I switched to `preload("res://data/db.gd")` everywhere I own.
- The first balance pass gave 100% wins. Raising enemy attack alone made fights bimodal: fast "aggressive" focus-fire enemies and fire AoE sappers wiped the party while everything else stayed trivial.
  I fixed it with three changes:
  - more enemy HP;
  - a 0.7x multiplier on enemy multi-target damage;
  - focus-fire on only 60% of turns.
  Then I tuned the weasel family, the sappers and four encounter lists one at a time.
- Two enemy drops used placeholder ids (`*_dummy`). The validate() test caught them.

## Learnings for a future agent
- Use `tests/balance_report.gd` (`-- seeds bonus`) to tune. Check win% and HP left together: if both are high the fight is trivial, and if win% is low while HP left is high the party is being wiped in bursts.
- `godot --quit` does not parse unreferenced scripts. Run `tools/run_tests.sh`, which loads every test and the engine.
- An instant `--quit` reports 2 leaked objects for `title.wav` (the AudioServer still holds the playback). This is harmless and does not happen in normal play.

## Requests for other modules
- battle-presentation: drive `BattleEngine` beats. Use `beat.anim`/`vfx`/`targets` from "action" beats, and `ActorRig.play_once()`. Bosses use the `special` anim.
- rpg-world: emit `Events.battle_requested(enc_id)` using `Data.AREAS[area].encounters`. Call `GameState.apply_battle_result()` after battles. Dialogue quest hooks use `GameState.set_quest(id, stage|"done")`.
- cooking-ui: use `Data.match_recipe`, `cook_quality(stir 0..1)`, `pairing_bonus` (for a "perfect pairing!" hint) and `dish_effect`. The in-battle Cook command takes `{type:"cook", ingredients, stir, target}`.
- menus-audio: `Settings.set_value(key, v)`. `Audio` looks up `assets/audio/{sfx,music}/<id>.(ogg|wav|mp3)`.
