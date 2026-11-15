# rpg-world report

## What I built
- `game/scenes/world/farm.tscn` + `farm.gd` (class `Farm`): builds the whole overworld in code: FarmTerrain (noise heightmap, vertex-colour grass/paths/fields/shore, hills, collision, pond), procedural sky + sun + soft shadows + fog + SSAO + glow, SDFGI at quality >= 2; farmhouse, barn, silo, windmill, coop, well, tractor, hay, crates, dock, cheese cave (hill), Rainbow Orchard shrine ringed by apple trees, fenced pasture / pig pen / chicken yard, 4 crop fields (MultiMesh), tall-grass encounter zones, ~130 oaks, campfire (save), cauldron (cook), signposts, a chest.
- World pieces: uses `res://assets/models/world_*.glb` automatically when present (they are now), else `WorldProps` placeholders.
- 11 NPCs, 10 animals (+3 extra chickens) with idle/wander, 7 patrolling enemy mobs that fire `battle_requested`, grass random encounters, third-person WorldPlayer with orbit cam, DialogueBox (portrait, name plate, typewriter, choices, flags, quests), 22 dialogues in `game/data/dialogue/*.json` incl. Farmer Gouda's Last Wheel intro.
- Also edited own files: `world_props.gd` (hand-built gable prism), `farm_terrain.gd` (sRGB vertex colours), `dialogue_box.gd` (typed vars, top margin).
- `scenes/world/farm_shot.gd/.tscn`: dev harness for camera screenshots.

## Verification evidence
- Headless run of farm scene: no script errors. `test/rpg_world_test.gd`: 31 interactables, player + dialogue box present, 22 dialogues parse with no dangling gotos: PASS.
- Rendered screenshots on GPU via Xvfb from 6 angles (overview, farmhouse, orchard side, cave, dialogue open with Farmer Gouda); looked at them.
- No fps number measured.

## Deviations from the contract
- `tools/shot.sh` in cheesefantasy does not exist (the parent repo's one targets another game), so I used my own Xvfb harness from a scratch copy of game/ without autoloads.
- Autoloads/ActorFactory did not exist yet; WorldBus/WorldModels fall back gracefully.

## Mistakes I made and how I fixed them
- Scene looked washed out: vertex colours were read as linear; set `vertex_color_is_srgb`, lowered fog/ambient.
- Untyped inference parse errors in dialogue_box.gd fixed.

## Learnings for a future agent
- Test without autoloads by mirroring game/ into a scratch project with a stripped project.godot.
- Xvfb + `MESA_VK_WSI_DEBUG=sw` + `--rendering-driver vulkan` renders on GPU.

## Requests for other modules
- models-world: farmhouse/barn/well roofs from the glbs render as an odd "V" (inverted/missing roof faces?); cheese cave glb looks like a plain boulder, entrance not visible; windmill needs a node named `Blades` to spin.
- models-party: `hero_fennel.glb` missing (placeholder pink capsule).
- rpg-core: autoloads, `actor_factory.gd`, Events signals `save_requested`, `cook_requested`, `shrine_requested`; encounter ids `farm_rats_1/2`, `farm_crows_1`, `farm_mold_1`, `farm_weasel_1`.
