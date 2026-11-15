# cooking-ui report

## What I built
- `game/scripts/cooking/cooking_logic.gd` (`CookingLogic`, pure): order-independent recipe matching (exact > tag > cheese, max-score assignment), stir tier from beat accuracies, pairing bonus (perfect cheese or all-distinct flavours), final tier 0..3 (Burnt/Plain/Tasty/Gourmet, mult .5/1/1.35/1.75).
- `game/scripts/cooking/dish_visual.gd` (`DishVisual`): procedural juicy dish sprite (plate, seeded blobs, highlights, steam, sparkles at Tasty+, charred when Burnt, flat silhouette for undiscovered).
- `game/scripts/cooking/cooking_ui.gd` (`CookingUI`) + `game/scenes/ui/cooking.tscn`: pantry list, 3-slot pot, live "this will make" hint (silhouette if recipe unknown), stir timing mini-game (4 beats field / 2 in battle, shrinking zone, accelerating marker, Space/Enter/click), result card, cookbook grid with silhouettes + hints, cook-role perks (clover never Burnt, brie egg dishes >= Tasty, fennel fire dishes +1).
- API: `open("field"|"battle", cook_char_id)`, signals `finished(result)`, `closed`. Result: `{ok, dish_id, tier, tier_name, mult, new_recipe, ingredients, mode, effect}`. Field mode adds the dish to inventory; battle mode only consumes ingredients (battle applies dish with `mult`). New recipes call `GameState.learn_recipe`.

## Verification evidence
- `test/cooking_logic_test.gd`: all 40 recipes match themselves, stir tiers correct (0 mismatches).
- `test/cooking_ui_test.gd`: full headless pick -> stir -> result flow with real autoloads, inventory deltas, battle mode, cookbook build: PASS. No parse errors/warnings from my files.
- Screenshots via xvfb: `out/qa/cooking_{pick,stir,result,book}.png` (viewed pick and book).
- Both tests are copied into `game/tests/` to run (`--script res://tests/<name>.gd`); remove after.

## Deviations from the contract
- Dish quality is not stored on inventory items (inventory is id->count); quality is only in the result dict.
- Autoloads accessed by node lookup (duck-typed), not hard identifiers.

## Mistakes I made and how I fixed them
- Used nonexistent `item_count`; GameState uses `count`. Test assumed empty inventory (new_game seeds some). Cookbook card labels were hidden under the dish visual; moved to bottom label.

## Learnings for a future agent
- `class_name` is not resolvable in `--script` runs before an import; use preload in tests.
- tools/shot.sh did not exist; `xvfb-run -a` with godot works for screenshots.

## Requests for other modules
- rpg-core: optional `GameState.add_dish(id, tier)` so quality persists; Events signal e.g. `cooking_requested(mode, cook_char)`.
- rpg-world: instantiate `scenes/ui/cooking.tscn` at campfire/cauldron, call `open("field")`.
- battle-presentation: Cook command instantiates it with `open("battle", actor_id)`, listen to `finished`, apply `effect` scaled by `mult`.
- menus-audio: sfx ids used: ui_select, ui_confirm, ui_cancel.
