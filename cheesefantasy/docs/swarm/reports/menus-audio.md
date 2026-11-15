# menus-audio report

## What I built
- `tools/gen_audio.py` (deterministic numpy, 22.05 kHz mono wav): 11 sfx (ui_select, ui_confirm, ui_cancel, ui_open, ui_buy, ui_error, ui_save, heal, coin, equip, dialogue_blip, dialogue_blip_low, cooking_sizzle, summon_sting) and 15 music loops/jingles (title, farm_day, fields, pond, orchard, silo, cave, rot, shrine, throne, battle, boss, final_boss, victory, game_over) in `game/assets/audio/{sfx,music}`, plus manifest.json. ~12 MB.
- `GameMenus` (`scenes/ui/menus.tscn`): Party (stats, equip), Items (use on ally), Bestiary, Summons gallery, Save/Load (3 slots), Settings, Quit to title. Opens on `menu` action, pauses tree.
- `ShopMenu` (`menus_shop.tscn`, `open_shop(id)`), `TitleMenu` (`menus_title.tscn`, signals new_game_requested / continue_requested(slot)), `SettingsPanel`, `MenuStyle`, `menus_preview` (shot harness).
## Verification evidence
- `test/menus_audio_test.gd` (run with tools/godot.sh --headless --script): all tabs build, item use, bestiary flag, save, buy/sell, sfx ids present: fails=0.
- Screenshots via tools/shot.sh of party/items/bestiary looked right.
## Deviations from the contract
- None. Bestiary uses GameState flags `seen_<enemy_id>` set from Events.battle_finished (encounter id).
## Mistakes I made and how I fixed them
- Autowrapped labels collapsed to 1-char width inside grids; wrapping is now opt-in.
- Paused tree prevents tools/shot.sh capture (its node polls _process); preview harness unpauses.
## Learnings for a future agent
- Autoloads are fetched by name at runtime (MenuStyle.auto) so scripts parse without registration.
## Requests for other modules
- integ/rpg-core: instantiate ONE `menus.tscn` under main (it listens for `menu`), a `menus_shop.tscn` for shop NPCs, `menus_title.tscn` for the title and wire its signals; call `GameMenus.open(0, false)` when saving is not allowed.
- rpg-core: `GameState.add_dish(...)` requested by cooking-ui is still MISSING from state.gd. No unequip API either.
- Use `Audio.play_music("<id>")` with ids above; ids "title", "victory", "game_over", "battle" are new beyond area music.
