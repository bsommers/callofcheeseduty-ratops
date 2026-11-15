# Late-game tuning (data only)

Root cause: the balance harness (`test_battle.gd` GEAR table) gave the party Rind Mail / Wheel Plate / Golden Cleaver tiers
that the shops only sell AFTER the Mold Dragon / Rat King, so bosses looked easy (dragon 100% at L18) while the real bot
fought them in Chef Whites gear. Also Rat King base level was 26 (enemy scales to max(base, encounter level)), and some
enemies had base levels above their encounter (weasel 5 in a L3 raid, rind_tick 15 in L14).

## Changes
- Harness: post-dragon gear starts at L18 and the dragon + pre-dragon cave fights cap gear at the L17 tier; Golden Cleaver tier removed.
- enemies.gd: Mold Dragon hp 6.5->3.8, atk 1.25->1.05, mag 1.3->1.1, def 1.1->1.0; Rat King level 26->24, hp 5.4->4.2, atk 1.1->1.0, mag/def/res 1.15->1.05;
  Crow Baron hp 6.0->4.4, atk 1.15->1.05, mag 1.1->1.0; weasel lvl 5->3, rat_sapper 3->2, rind_tick 15->12 (hp 0.8->0.7);
  cellar_spider hp 0.95->0.8, weasel_bandit/ferret_rogue softened, rat_brute atk 1.25->1.15, rat_shaman hp 0.85->0.75, moldy_scarecrow hp 1.2->0.9.
- world.gd: boss_rat_king level 26->24; cellar_ticks 4->3 enemies, king_guard 4->3, cave_spiders 3->2, windmill_weasels 3->2, scarecrow_patch 3->2.
- Test: `test_battle.gd:test_late_game_win_bands` (40 seeds: normals >=90% and bosses >=75% at intended level; dragon at L17, Rat King at L25 >=75%).
  `qa_run.gd` prints party/inventory on a loss when `QA_VERBOSE=1`.

## Before / after (40 seeds, balance_report)
| fight | before | after |
|---|---|---|
| normal overall | 94.3% (coop_raid 77, cave_spiders 80, cellar_ticks 77, king_guard 85, scarecrow 82) | 98.9%, every encounter >=95% |
| Crow Baron (L10) | 75% | 80% |
| Mold Dragon, realistic gear: L17 / L18 | 0% / 30% (L20 ~90%) | 97% / 100% (L16 ~72%) |
| Rat King, realistic gear: L24 / L25 / L26 | 5% / 8% / 33% (L28 ~90%) | ~60% / 95% / 95% |

qa_run.gd, 10 consecutive runs after: no defects, floor 4 won in 1-4 tries every run (6 allowed), typically at party L18 (was L21, 5 tries); Rat King at L24 encounter, bot party L24-27 (was L28).
Bot remains ~1 level weaker than the harness (no mid-fight cooking), so a human at L17/L25 should do better.
