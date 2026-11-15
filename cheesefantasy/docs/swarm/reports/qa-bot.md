# qa-bot report (stage A: stable modules only)

## What I built
- `game/scripts/qa/qa_validate.gd`: headless validator (encounters, recipes, summons, L1-party survivability).
  Run: `tools/godot.sh --headless --path game --script res://scripts/qa/qa_validate.gd -- 20`
- Screenshot gallery in `out/qa/` (battle idle/menu/summon, pond_blobs, crop_mixed, pasture_rats, boss_rat_king) via `game/scripts/battle_view/shot.sh`.
- Not yet done (waiting for integ-lead stage B): full main-quest playthrough bot, title/menus/shops/save/ending checks.

## Verification evidence
- `tools/run_tests.sh`: all test_battle/test_data/test_actors PASS. Boot prints
  `Failed to load script res://scripts/integration/director.gd (Parse error)` (autoload) - integ-lead WIP.
- 28 encounters x 20-30 seeds all terminate, deterministic; 40 recipes resolve to their own dish (match_recipe), 4 summons castable at full gauge and cast beat produced; mystery_mush fallback works.
- balance_report (20 seeds): normal overall 88.8%; weakest: orchard_weasels 60%, barn_sappers 60% (hp_left 42%), pasture_rats 65%, hill_ninjas 65%, boss_rat_king 60%, boss_crow_baron 70%.
- Level-1 party (new-game gear/kit): meadow_grunts, meadow_pair, crop_crows 20/20; crop_mixed (L3), coop_raid (L4), pond_blobs (L4), pasture_rats (L5) 0/20.

## Defects
1. **Negative gold in result** (owner: battle-engine / `battle_engine.gd` `result()` line ~282 `gold - stolen_gold`): thief enemies (orchard_magpies, hill_ninjas) yield e.g. gold -136 and xp 0 on a "won" battle. Clamp gold to >= 0 (and decide whether stolen gold should reduce party gold, not the reward). Seen in ~25 of 120 seeds.
2. **Level-1 party "lost 3 of 5" confirmed as a difficulty cliff, not a crash** (owner: rpg-core balance, `data/world.gd` ENCOUNTERS levels / enemy curve): L1 party wins 100% at L1-2 encounters but 0% at L3+ (crop_mixed L3, 3 foes). Enemies scale to encounter level so there is no slack; progression must guarantee leveling (or XP gains) before crop_mixed/coop_raid/pond_blobs roaming encounters; integ-lead/rpg-world should gate those areas or lower levels.
3. **pond_blobs "2 of 3 enemies" NOT a bug**: `world.gd` defines pond_blobs with 2 enemies (mold_blob, curd_slime); engine spawns 2 and the scene renders 2 (out/qa/battle_pond_blobs_0.png). If 3 were intended, owner rpg-core must add an enemy to the list. Note Curd Slime shows Lv6 in an L4 encounter (per-enemy level offset).
4. Balance dips (rpg-core): barn_sappers 60% with 42% HP left; orchard_weasels (L8) 60% vs neighbours 85-100%.
5. `director.gd` autoload parse error (integ-lead, expected WIP).

## Deviations from the contract
None found in battle API (result shape won/fled/xp/gold/drops present).

## Mistakes I made and how I fixed them
- First summon check called step() without start(); fixed. First boss check used recommended level without the +1 the balance tools use; fixed.

## Learnings for a future agent
- `T.simulate(id, seed, level_bonus)` in `tests/test_battle.gd` is the easiest engine harness; stderr leak warnings at exit are noise (filter with grep).
- shot.sh needs absolute `--out=` prefixes; files are `<prefix>_<i>.png`.

## Requests for other modules
- battle-engine: clamp result gold (defect 1). rpg-core: encounter level gating/balance (2, 4). integ-lead: director.gd parse fix, then ping qa-bot for stage B playthrough.

---
# Stage B (full game)

## What I added
- `game/tests/qa_playthrough.gd` + runner `game/tests/qa_run.gd`: `tools/godot.sh --headless --path game --script res://tests/qa_run.gd` (~10 s). Drives main.tscn (GameRoot) title -> New Game -> farm, Gouda (dialogue_finished + quest_started -> main stage 1), 10 field encounters in order (grinding only when avg level < encounter level), shops (all 4 shops, gold math), auto-equip best gear, every start recipe through the real cooking UI (pick/start_stir/stir_press), shrine `_complete()` for all 4 summons, each summon cast in a real engine battle, save/load round trip (slot 8, deleted after), Crow Baron (+cave_key, main stage 2), CaveDelve 6 floors, Rat King, `game_complete` flag + main quest done (99). Battles are real BattleEngine runs (auto commands) fed through Events.battle_finished -> Director.
- `qa_validate.gd`: healer-summon check (Samantha heals, power 0) so it no longer false-flags.
- Gallery `out/qa/`: farm_0/90/180/270, menu_{party,items,bestiary,summons,save,settings,shop,title}, story_{shrine,cave,boss,ending}, title, cooking_*, battle_* + contact sheets sheet_farm/menus/story.png.

## Verification evidence
- Earlier defects FIXED: negative gold (clamped; no `negative gold` in 200 fights), balance cliff (encounters re-levelled; auto-party now wins every field encounter on-curve). qa_validate: 28 enc / 40 recipes / 4 summons OK; only remaining validator flag is L1 party vs crop_mixed 2/20 (fresh party must level first; the bot gets there after 3 fights).
- Playthrough: 0 defects, ending flag set. Bot needed over-levelling: Mold Dragon (L17) beaten at party L21 (5 tries), Rat King (L26) at L28 (3 tries), king_guard L24 at L23; auto-battle bot does not cook/use items mid-fight, so a human is probably 2-3 levels ahead of this. Pacing note for rpg-core: floors 3->4 and 5->6 are the spikes, cave floor 1 (L10) is soft when the player arrives ~L13 after the Baron.
- Performance: cannot read in-game FPS (shot.sh hides the log). Wall-clock proxy: farm at 1280x720 on the RX 7900 XTX under Xvfb (CPU-copy present) renders 600 frames in 3.8 s = ~160 fps. Headless logic is not a perf test. No measurement on low-end hardware or in battle scenes; treat perf as unverified beyond "no stalls on the dev GPU".

## Visual defects (viewed sheets)
1. Menus (menus-audio): panels are ~90% empty dark space, tiny 10-12 px text at 1280x720; Save tab and Summons tab nearly blank; Summons shows 4 identical "???" rows with no art/silhouette.
2. Cooking (cooking-ui): result card overlaps the pantry list and the "This will make" line; plate dish is three orange discs, not recognisable as Grilled Cheese.
3. Ending (integ-lead): black screen, plain typewriter text, no art/music cue visible; weakest screen in the game.
4. Farm (rpg-world): farm_180 view (south) is bare path + trees; HUD control hint text is ~8 px and unreadable. No campfire/shop-in-world modal shot (needs interactive driver; shop menu and cooking shots stand in).
5. Cave (integ-lead): floor model sits on empty gradient; party level shown as 10 in the harness (harness, not bug).

## Mistakes
- Autoloads are not compile-time identifiers in a `--script` SceneTree; the bot is a RefCounted loaded via load() from a tiny runner (same trick as run_all.gd).
- First bot read "save/load differs" from dict key order in `equip` (false positive); first cooking failures were depleted pantry. Both fixed in the bot.

## Requests
- rpg-core: smooth cave pacing (floor 4 boss, floor 6). menus-audio/cooking-ui/integ-lead: items above. Someone with an interactive driver: campfire modal shot and an FPS counter in the debug HUD.
