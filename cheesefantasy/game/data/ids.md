# CHEESE FANTASY — id lists (owner: rpg-core)

Authoritative data lives in `game/autoload/data.gd` (autoload `Data`), which re-exports the
const tables in `game/data/*.gd`. All ids are lowercase snake_case strings. Regenerate the
"live" list at any time: `tools/godot.sh --headless --path game -s res://tests/dump_ids.gd`.

## Autoload names
`Data`, `Events`, `GameState` (file state.gd), `Settings`, `Audio`.

## Elements (`Data.ELEMENTS`)
none, fire, ice, wind, earth, rot, light, shade

## Statuses (`Data.STATUSES`)
melted, frozen, chilled, aerated, rinded, moldy, sated, spicy, stinky, taunting

## Characters (`Data.CHARACTERS`)  model = hero_<id>
fennel (FIRE, hero), brie (WIND, healer), clover (EARTH, tank), maple (ICE, support)

## Summons (`Data.SUMMONS`)  model = summon_<id>
jesse, tripper, samantha, spooky

## Skills (`Data.SKILLS`)
Fire: melt_slash, raclette_blaze, fondue_flare, toasty_aura, welsh_rarebit_rain, grilled_cheese_inferno, flambe_finale
Ice: chill_touch, brie_freeze, cave_frost, cellar_draft, cold_storage, frost_rind, parmesan_blizzard, permafrost_wheel
Wind: whey_whirl, swiss_gale, omelette_mend, herb_poultice, smoked_breeze, souffle_rise, holey_cyclone, feather_frenzy, sunny_side_up
Earth: skillet_bash, cheddar_crush, rind_wall, stinky_stance, aged_bulwark, parmesan_pound, gouda_quake, cast_iron_cover
Light/cooking/support: curd_cure, taste_test, pinch_of_salt, chefs_kiss, mise_en_place, second_helping
Enemy: gnaw, tail_whip, sap_bomb, sling_pebble, brute_smash, shaman_hex, shaman_mend, rally_squeak, peck, caw_screech, shiny_snatch, hex_feather, blue_spore, mold_spread, gorgonzola_gas, spore_cloud, toadstool_nap, weasel_swipe, sneak_bite, smoke_bomb, shuriken_rind, rind_slam, rot_roll, curd_splash, whey_wail, scare_stare, beetle_burrow, web_wrap, tick_drain
Boss: baron_dive, feather_storm, murder_of_crows, baron_preen, dragon_rot_breath, wing_of_blight, spore_nova, dragon_regrow, crown_crush, roquefort_roar, royal_decree, rot_tide, last_wheel_drain

## Enemies (`Data.ENEMIES`)  (model field names one of the enemy_*/boss_* glbs)
rat_grunt, rat_sapper, rat_slinger, rat_brute, rat_shaman, rat_captain,
crow, crow_scout, magpie_thief, raven_hexer,
mold_blob, blue_rot_blob, fuzzy_spore, rot_toadstool,
weasel, weasel_bandit, stoat_ninja, ferret_rogue,
wheel_golem, rotten_wheel_golem, curd_slime, whey_wisp, moldy_scarecrow, rot_beetle, cellar_spider, rind_tick
Bosses: crow_baron, mold_dragon, rat_king

## Ingredients (`Data.INGREDIENTS`)  (also stack in inventory like items)
milk, cream, butter, curd, egg, honey, wheat, garlic, onion, thyme, basil, sage, chive, mint,
rosemary, lavender, chili_pepper, black_pepper, apple, pear, fig, cranberry, tomato, potato,
pumpkin, corn, carrot, mushroom, truffle, wine, cider, walnut, olive, sea_salt, trout
Cheese wheels (tag "cheese"): cheddar, brie_wheel, swiss, gouda, parmesan, blue_cheese, mozzarella

## Recipes (`Data.RECIPES`)  dish item id = recipe id
grilled_cheese, mac_and_cheese, cheese_omelette, fondue_pot, raclette_potatoes, caprese_salad,
mushroom_risotto, truffle_fondue, apple_cheddar_pie, honey_brie_bake, fig_and_blue_tart,
pear_gorgonzola_salad, pumpkin_soup, corn_chowder, tomato_soup, garlic_bread, herb_scones,
cheese_souffle, quiche_lorraine, pizza_margherita, cheese_curd_poutine, welsh_rarebit,
smoked_trout_melt, walnut_pesto_pasta, croque_monsieur, spicy_queso, chili_cheese_corn,
mint_curd_cooler, lavender_cheesecake, cranberry_brie_bites, olive_tapenade_toast, cider_cheddar_soup,
baked_apple_crumble, carrot_cake, mulled_wine_fondue, sage_butter_gnocchi, frozen_yogurt_bomb,
stinky_bomb, rot_away_tonic, gourmet_last_wheel_feast
Failure dish: mystery_mush (any combination that matches no recipe)

## Items (`Data.ITEMS`)  (dishes above are ALSO items, kind "dish")
Consumables: milk_bottle, cream_flask, whey_tonic, curd_elixir, herb_salve, mega_salve,
smelling_salts, catnip_tincture, rot_cure, warm_cocoa, defrost_mitten, fresh_bread, ether_cheese,
throwing_pebble, firecracker, ice_cube, pepper_spray, smoke_pellet
Weapons: cheese_knife, chef_ladle, flambe_knife, golden_cleaver, feather_wand, egg_scepter, cyclone_whisk,
iron_skillet, cast_iron_wok, ancient_griddle, cellar_lantern, frost_tongs, ice_cellar_key_staff
Armor: farm_apron, quilted_vest, chef_whites, rind_mail, wheel_plate
Charms: lucky_bell, curd_amulet, whisker_charm, smoke_ring, chill_pendant
Key items: cave_key, shrine_bell, rat_badge, last_wheel_shard, recipe_book, memory_yarn

## Encounters (`Data.ENCOUNTERS`)
Normal: meadow_grunts, meadow_pair, crop_crows, crop_mixed, coop_raid, pond_blobs, orchard_magpies,
orchard_weasels, pasture_rats, pasture_mixed, barn_sappers, barn_mixed, silo_crows, silo_ravens,
windmill_weasels, cave_mouth_blobs, cave_golems, cave_spiders, cave_mixed, rot_fields_spores,
rot_fields_mixed, hill_ninjas, cellar_ticks, king_guard, scarecrow_patch
Boss: boss_crow_baron, boss_mold_dragon, boss_rat_king

## Shops (`Data.SHOPS`)
cheesemonger_shop, cook_pantry, tinker_wares, granny_stall

## Quests (`Data.QUESTS`)
main_last_wheel, memory_jesse, memory_tripper, memory_samantha, memory_spooky,
lost_chickens, scarecrow_hat, cook_recipe_book, pond_frog_cheese, tinker_parts

## Areas (`Data.AREAS`, ids for Events.area_entered)
farmhouse, barnyard, crop_fields, pasture, coop, pond, orchard, windmill, silo, rainbow_orchard, cheese_cave, rot_fields, rat_throne

## Rules, tables and APIs (rpg-core, final)
- `DB` (res://data/db.gd, class_name DB; also `preload` it) = static rules usable without autoloads; `Data` re-exports it.
  `DB.item(id)` looks up ANY inventory id (items, dishes, ingredients). `Data.ITEMS` includes every dish (= recipe id) + `mystery_mush`.
- Cooking: `Data.match_recipe(ingredients)` -> recipe id or "mystery_mush"; `Data.cook_quality(rid, ings, stir 0..1, cook_char, boost)`
  -> 0..3 (`Data.QUALITY[q]` = burnt/plain/tasty/gourmet); `Data.pairing_bonus(rid, ings)`; `Data.dish_effect(rid, q)`.
- Flavor Chain combos: `Data.CHAINS` keys "fire>wind" (Smoked), "ice>earth" (Aged), "earth>fire" (Grilled), "wind>ice" (Whipped), ...
- Battle: `BattleEngine` (res://scripts/battle/battle_engine.gd) - setup(enc_id, GameState.battle_party(), opts) / start() / step(cmd)
  / auto_command(uid) / available_commands() / skill_list() / valid_targets() / result(). Beat types documented in its header.
- `GameState.apply_battle_result(engine.result())` applies hp/mp, used items, gold, drops, xp (emits level_up), boss flags.
- Actors: `ActorFactory.spawn(model_id, height) -> ActorRig` (play(anim), play_once(anim), set_tint(color), height, placeholder).
- Extra Events signals: `level_up(char_id, level)`, `game_loaded(slot)`, `game_saved(slot)`.
