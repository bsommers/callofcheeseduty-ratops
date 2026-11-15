# Fixes pass
- set_quest accepts int/string stages (state.gd compares via str()); test added (test_state).
- farm mob/roll encounter ids now real (meadow_grunts, meadow_pair, crop_crows, crop_mixed, pond_blobs, coop_raid); test_data.test_world_encounter_ids_valid.
- pond_blobs has 2 enemies by data: not a bug.
- Rat King: brighter tint, boss fill light, wider boss/escort spacing (all enemies use boss slots when engine.is_boss()), hp mult 6.0->5.4, atk 1.1 (win ~80%).
- Summon: name card ribbon moved to top (y=150); damage popups staggered 0.18s with alternating x / rising y.
- BattleEngine.result() clamps gold/xp >= 0; test_result_never_negative.
- Balance (data only): encounter levels lowered (crop_mixed 2, coop_raid 3, pond_blobs 3, pasture_rats 4, barn_sappers 5, orchard_weasels 7, hill_ninjas 20); dropped 3rd enemy from pasture_rats, barn_sappers, orchard_weasels, hill_ninjas. Normal overall 94.8%, weakest 90%. Fresh unleveled party at L3+ still needs leveling by design.
