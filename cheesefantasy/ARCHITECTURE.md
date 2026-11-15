# CHEESE FANTASY: The Last Wheel — Architecture contract

Turn-based JRPG (Final Fantasy / Pokémon feel) in the cat-vs-rat world of KÄSEKRIEG: RAT OPS. Godot 4.7.2 (`tools/godot.sh`), GDScript, Forward+, project dir `game/`.
Stylised-but-lit 3D (think a polished FF9/Pokémon-Legends look: chunky readable shapes, PBR, warm light, soft shadows) — NOT photoreal. Every character is a real 3D model made in Blender.

## 1. Story / world (for names, dialogue, flavour)
Curdlewick Farm lies in the Whey Valley. The **Last Wheel** (a mythic 100-year cave-aged cheese that keeps the valley fed) was stolen by the **Rat King Gorgonzolo**, whose blue-green **Rot** (mold blight) is creeping over the fields. Open-air farm: farmhouse with kitchen, big red barn, silo, windmill, chicken coop, pig pen, cow pasture, sheep meadow, pond, orchard, crop rows, fences, a cheese cave on the hill (dungeon-ish side area is fine, but the hub is OUTDOORS). NPCs: farmer, cook, cheesemonger, blacksmith-ish tinker, kids, scarecrow, wandering barn animals (cows, pigs, chickens, goats, sheep, a dog) — many talkable.
Party (4 members, each one element + a cooking role):
- **Fennel** — ginger tabby kitten apprentice cheesemonger-chef, hero. FIRE ("Melt"). Weapon: cheese knife / ladle.
- **Madame Brie** — grand speckled hen, wizard. WIND ("Whey Gust"). Heals/buffs with eggs & herbs.
- **Clover** — stout goat knight with a cast-iron skillet shield. EARTH ("Rind"). Tank.
- **Maple** — farmer's daughter, cellar-keeper. ICE ("Cave Chill"). Support/debuff.
Enemies: Rat Grunts, Rat Sappers, Crows, Mold Blobs ("Blue Rot"), Weasels, Rotten Wheel golems, bosses incl. Rat King Gorgonzolo (+ Mold Dragon, Crow Baron).

## 2. Elements and cheese
Elements: FIRE=Melt, ICE=Chill (cave-aging), WIND=Whey (aeration/smoke/Swiss), EARTH=Rind (cheddar/parmesan), plus ROT (mold; enemy only), LIGHT (Samantha/healing), SHADE (Spooky). Wheel: FIRE>ICE>WIND>EARTH>FIRE (x1.5 / x0.5 reverse), ROT weak to FIRE and LIGHT, LIGHT/SHADE weak to each other.
Spells are named cheese-fantasy puns, e.g. Fire: *Raclette Blaze, Fondue Flare, Grilled Cheese Inferno*; Ice: *Brie Freeze, Cave Frost, Parmesan Blizzard*; Wind: *Swiss Gale, Whey Whirl, Holey Cyclone*; Earth: *Cheddar Crush, Rind Wall, Gouda Quake*; Rot: *Blue Spore, Gorgonzola Gas*. Enemy mold smells etc.
Status: Melted (burn dot), Frozen/Chilled (skip, slow), Aerated (evade up), Rinded (def up), Moldy (poison + spreads), Sated (regen), Spicy (atk up), Stinky (enemy accuracy down).

## 3. Cooking system (the signature twist)
- **Ingredients** (milk, curd, herbs, eggs, honey, peppers, wheat, garlic, apples, tomatoes, truffle, wine, ...) are found in the world/farm patches/shops/drops.
- **Recipes** (in `Data.RECIPES`): 2–3 ingredient slots (+ any cheese wheel) → a **Dish** (item). Discovering recipes by experimenting at campfires/the farmhouse kitchen/cauldron, or learning them from NPCs. Dishes heal, revive, buff, or hit enemies (thrown). Quality tiers: Burnt, Plain, Tasty, Gourmet (by a timing stir mini-game and ingredient pairing).
- **In-battle "Cook" command**: spend a turn to cook a field dish from carried ingredients (3-slot pot, quick stir timing) — quality scales effect.
- **Flavor Chain / Fondue Gauge**: each spell cast adds element-flavour to the party gauge; chaining different elements in order (e.g. FIRE then WIND = *Smoked*, ICE then EARTH = *Aged*) gives bonus damage multipliers and fills the **Fondue Gauge** (0-100). Eating a Gourmet dish gives bonus gauge.
- At 100 gauge the party can call a **Nine Lives Spirit** (summon).

## 4. Summons — Nine Lives Spirits (previous house cats, ethereal, large, glowing)
Earned at the **Rainbow Orchard** shrine in the story (each given by a memory quest); each is a big translucent-glow 3D cat model with cinematic intro (name card, camera sweep) then a signature attack, then departs. One summon per battle (or two at max gauge).
- **Jesse** — gray cat. WIND+ICE "Silver Stalker": *Misty Pounce* — all-enemy gale, evade-up buff.
- **Tripper** — American tabby (brown with black stripes). EARTH "Stripe Quake": *Tabby Tremor* — heavy all-enemy earth damage, party Rinded.
- **Samantha** — white cat. LIGHT/ICE "Snow Angel": *Halo Lick* — full party heal + revive + cleanse.
- **Spooky** — black cat. SHADE "Midnight Walker": *Eclipse Claw* — massive single-target shade damage, ignores defence.
Data in `Data.SUMMONS`. Model ids `summon_jesse`, `summon_tripper`, `summon_samantha`, `summon_spooky`.

## 5. Battle (turn-based, FF-style active-time-lite)
Pure logic in `game/scripts/battle/battle_engine.gd` (`class_name BattleEngine`, RefCounted, deterministic given seed, headless-testable). Turn order by speed (`Data` stat `spd`); commands: Attack, Skill (elements), Cook, Item, Summon (when gauge full), Guard, Flee. Party max 4, enemies max 5. Formulas documented in the engine header comment. Events surfaced as Array of Dictionary "beats" (type, actor, target, amount, element, text) which the battle scene plays back: `engine.step(command)` → Array[Dictionary].
Battle scene: `game/scenes/battle/battle_scene.tscn` root script `BattleScene` — 3D arena (farm-themed backdrop), models placed by `ActorFactory`, party right/enemies left, camera cuts, spell VFX, floating damage numbers, command menu UI. API: `BattleScene.start(encounter_id: String)`; emits `Events.battle_finished(result: Dictionary)` (`{won:bool, fled:bool, xp:int, gold:int, drops:Array}`).

## 6. Shared code contract (owner = rpg-core unless noted)
Autoloads in `game/autoload/`: `data.gd` (Data: ELEMENTS, SKILLS, CHARACTERS, ENEMIES, ITEMS, INGREDIENTS, RECIPES, SUMMONS, ENCOUNTERS, SHOPS, DIALOGUE, QUESTS — plain const Dictionaries keyed by lowercase snake-case string ids, built to be extended), `events.gd` (signals: `battle_requested(encounter_id)`, `battle_finished(result)`, `dialogue_started(npc_id)`, `dialogue_finished(npc_id)`, `item_gained(id,count)`, `recipe_learned(id)`, `quest_updated(id,state)`, `summon_unlocked(id)`, `area_entered(id)`, `gold_changed(g)`, `party_changed()`, `toast(text)`), `state.gd` (GameState: party stats/levels/xp/hp/mp, inventory dict, gold, flags dict, quest states, unlocked recipes/summons, play time, save/load to `user://save_<slot>.json`), `settings.gd`, `audio.gd` (Audio: `play_sfx(id)`, `play_music(id)` — falls back silently when no stream).
`game/scripts/actors/actor_factory.gd` (`class_name ActorFactory`): `static func spawn(model_id: String, height := 0.0) -> Node3D` loads `res://assets/models/<model_id>.glb`, wraps with `AnimationPlayer` access helpers (`play(anim)` with fallbacks idle), returns a **procedural placeholder** (coloured capsule + head + name label) if the glb is missing so the game always runs.
Model ids (glb in `game/assets/models/`): party `hero_fennel`, `hero_brie`, `hero_clover`, `hero_maple`; summons above; NPCs `npc_farmer`, `npc_cook`, `npc_cheesemonger`, `npc_tinker`, `npc_kid`, `npc_granny`, `npc_scarecrow`; animals `animal_cow`, `animal_pig`, `animal_chicken`, `animal_goat`, `animal_sheep`, `animal_dog`, `animal_duck`; enemies `enemy_rat_grunt`, `enemy_rat_sapper`, `enemy_crow`, `enemy_mold_blob`, `enemy_weasel`, `enemy_wheel_golem`, `boss_rat_king`, `boss_mold_dragon`, `boss_crow_baron`; world `world_barn`, `world_farmhouse`, `world_silo`, `world_windmill`, `world_coop`, `world_fence`, `world_tree_oak`, `world_tree_apple`, `world_haybale`, `world_crate`, `world_well`, `world_pond_dock`, `world_cheese_cave`, `world_shrine`, `world_wheel_cheese`, `world_cauldron`, `world_campfire`, `world_crop_corn`, `world_crop_wheat`, `world_crop_tomato`, `world_signpost`, `world_tractor`, `world_cheese_*`.
Animation clips (exact names, looped where natural): characters/animals `idle`, `walk`, `run` (party/NPCs/animals as relevant); party & enemies also `attack`, `cast`, `hurt`, `down`, `victory`, `defend`; summons `idle`, `summon_intro`, `special`, `outro`; bosses add `intro`, `special`.
Each glb: Y-up, metres, character height ≈ 1.0–1.8 for people, animals natural, summons ~3 m tall; <30k tris each; Armature + named bones; PBR materials; origin at feet. Blender scripts under `tools/blender/<name>.py` (reproducible), previews to `out/previews/<id>.png` (LOOK at them).
Scenes: `game/scenes/main.tscn` (boot → title → new/continue), `game/scenes/world/farm.tscn` (overworld), `game/scenes/battle/battle_scene.tscn`, `game/scenes/ui/*` (menus: party status, inventory, cooking, summon shrine, save).
Input actions: `move_*`(WASD+arrows+pad), `interact` (E/Space/A), `confirm`, `cancel`, `menu`, `run`, `cam_left/right`.
Overworld: 3D open farm, third-person follow camera (chase, orbit with cam_*), NPCs with idle/walk schedules, interact → dialogue box (`game/scripts/ui/dialogue_box.gd`, owned by rpg-world), roaming encounters (visible enemies chasing/patrolling in the fields, touch to start battle; some random in tall grass), save at campfires/cauldron.

## 7. Directory ownership map
- rpg-core: `game/project.godot`, `game/autoload/*`, `game/scripts/actors/*`, `game/scripts/battle/*` (engine only), `game/data/*`, `game/tests/*`, `tools/shot.sh`, `tools/run_tests.sh`, `game/scenes/main.tscn` + title.
- models-party: `tools/blender/party_*.py`, `game/assets/models/{hero_*,summon_*}*`
- models-world: `tools/blender/world_*.py`, `tools/blender/creatures_*.py`, `game/assets/models/{npc_*,animal_*,enemy_*,boss_*,world_*}*`
- rpg-world: `game/scenes/world/*`, `game/scripts/world/*`, `game/scripts/ui/dialogue_box.gd`, `game/data/dialogue/*`
- battle-presentation (wave 2): `game/scenes/battle/*`, `game/scripts/battle_view/*`, `game/assets/vfx/*`
- cooking-ui, menus-audio, integ, qa, builds, docs: wave 2/3 (see SWARM.md).
