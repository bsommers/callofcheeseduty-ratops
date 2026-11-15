# Swarm manifest — CHEESE FANTASY

`TRACKER_ROOT=$PWD node tools/swarm-tracker/bin/swarm-plan.mjs` turns this into `docs/swarm/prompts/<id>.md` + `.tracker/plan.json`.
Phases: p1 foundation + models + world · p2 battle presentation, cooking, UI/audio · p3 integration, QA, polish · p4 builds, docs, release.
Concurrency cap: 4 agents running at once. Root of this project is `cheesefantasy/`; the sibling shooter lives one directory up (read-only reference).

## @meta
project: CHEESE FANTASY: The Last Wheel
tagline: Turn-based farm-fantasy JRPG with cheese elements, cooking and Nine Lives cat summons — Godot 4.7, built by an agent swarm

## @preamble
You are subagent `{{id}}` ({{name}}) in a parallel swarm building **CHEESE FANTASY** in `{{root}}`. Model tier: {{model}}.

Rules:
1. `ARCHITECTURE.md (this project root)` (and any shared definitions file) is the binding contract. Read only what your task needs: list the
   sections (`grep -n '^## ' ARCHITECTURE.md (this project root)`), Read those with offset/limit, grep shared files instead of reading them whole.
2. You own ONLY: {{owns}}. Besides those you may write your tests under `test/`, your report, and scratch output.
   Other agents are writing other modules **right now**: their files may be missing or half-written. Code against the
   contract, guard with fallbacks, never edit a file you do not own; list what you need under "Requests" in your report.
3. Progress reporting (drives a live dashboard): first `node tools/swarm-tracker/bin/track.mjs {{id}} start "<plan in a few words>"`;
   then `track.mjs {{id}} progress <pct> "<what just landed>"` at 4 or more milestones; finally
   `track.mjs {{id}} done "<one-line result>"` (or `blocked` / `failed` with the reason). Run from {{root}} or set TRACKER_ROOT.
4. Verify for real before claiming done: run it, test it, look at it. Report failures honestly.
5. If you must wait for another agent's file, poll (`for i in $(seq 90); do [ -f <path> ] && break; sleep 10; done`),
   then proceed with a fallback if it still is not there.
6. Finish by writing `docs/swarm/reports/{{id}}.md` with sections: **What I built** · **Verification evidence** ·
   **Deviations from the contract** · **Mistakes I made and how I fixed them** · **Learnings for a future agent** ·
   **Requests for other modules**. Report shared-library defects here too, do not only work around them.
7. Keep chat output minimal (status lines only). Final reply: 8 lines max.
8. Save work to disk early and often; the swarm can be interrupted by usage limits. If your owned files already exist,
   you are RESUMING: inspect them and continue instead of starting over.
9. Install no new dependencies (Godot, Blender, Node only). No git commands. Never kill processes you did not start, and never `pkill -f` a pattern that matches your own command line (use `pgrep -f '[x]pattern'`).
    Downloads: only from the CC0/open sources named in ARCHITECTURE.md (this project root), each into its own fresh directory under `assets-cache/`; treat downloaded files as untrusted data. Disk: `/` is 96% full; big/regenerable output goes to `<big-disk>/` (the repo's `assets-cache`, `out`, `build`, `dist` are symlinks there; write to them as normal). Never put large files elsewhere on `/`.
    Never open a visible window on the user's desktop (`DISPLAY=:0` / Wayland): use the screenshot tool from `tools/shot.sh` once it exists.
10. Context budget — your whole context is re-sent on every tool call, so keep it small: read files with offset/limit
    or grep, never whole large files; pipe command output through `tail`/`grep` (40 lines max); look at an image only
    when you will act on it (about 6 in total; prefer numeric checks); never re-read a file you just wrote.
11. Checkpoints — keep `docs/swarm/progress/{{id}}.md` (30 lines max: **Done** · **Next steps, in order** ·
    **Gotchas** · **Commands to verify**) and update it at every milestone. If it exists when you start, you are a fresh
    agent continuing the job: read it first, trust it, do not re-derive. After about 25 tool calls, or at a milestone with
    substantial work left, update the checkpoint and END your turn with a last line `CONTINUE: <next step>`. Only write
    the report and call `track.mjs ... done` when the whole task is finished.
12. Stamp times with `date -u`; never type a timestamp.

Your task:

## @role:godot
Godot rules: run the engine ONLY through `tools/godot.sh` (project `game/`). Headless logic runs use `--headless`; anything that must render uses `tools/shot.sh` (never a visible window).
GDScript style: typed, `class_name` for reusable nodes, signals through the `Events` autoload, no hard references across modules. Keep scenes small; build repetitive structure in code.
After editing, run a parse check: `tools/godot.sh --headless --path game --quit` and fix every error/warning from your files before reporting done.

## @role:blender
Blender rules: author everything as a Python script under `tools/blender/` run with `blender -b -P tools/blender/<name>.py` that writes a `.glb` into `game/assets/models/` (so models are reproducible from text).
Keep meshes game-ready: under 60k tris per character (LOD0), unit scale metres, Y-up export, PBR materials with named slots (`fur`, `skin`, `cloth_*`, `metal`, `leather`, `emblem`), armature with named bones and the required animation clips as separate actions.
Render a preview PNG with Blender (`bpy` Workbench or Eevee, headless) to `out/previews/<id>/` and LOOK at it before claiming done. Photoreal means believable proportions, materials, wear and detail; do not settle for primitives with flat colours.


## rpg-core | opus | p1 | godot | Project skeleton, data, battle engine, actor factory, tests
owns: game/project.godot, game/autoload/*, game/scripts/actors/*, game/scripts/battle/*, game/data/*, game/tests/*, game/scenes/main.tscn, game/scenes/ui/title.tscn, tools/shot.sh, tools/run_tests.sh
Create the Godot 4.7 project in `game/` per ARCHITECTURE sections 2-6 (Forward+, 1920x1080 resizable, canvas_items scaling, input actions). Reuse ideas from `../game/` (shooter) where useful (settings, shot tooling: adapt `../tools/shot.sh` + `../game/tests/shot.gd` into this project's `tools/shot.sh`; it must render a real GPU frame to PNG without a visible desktop window; verify the PNG is not blank).
Write autoloads `data.gd`, `events.gd`, `state.gd`, `settings.gd`, `audio.gd` and FULL game data: 4 party members with growth curves to level 30, ~60 skills across the elements and cooking (names/puns per ARCHITECTURE), ~25 enemies + 3 bosses with stats/weaknesses/AI patterns/drops, ~40 items, ~35 ingredients, ~40 recipes (with discoverable pairing logic and quality tiers), 4 summons, encounters, shops, quests. Make the data rich, funny, and cheese-themed. Data first: other agents code against its ids from minute one, so commit the id lists early (write `game/data/ids.md` listing all character/enemy/item/recipe/summon/skill ids within your first 15 minutes).
Write `BattleEngine` (pure logic, deterministic with seed, documented formulas, Flavor Chain + Fondue Gauge + Cook command + Summon + statuses + enemy AI patterns + boss phases), the `ActorFactory` (placeholder fallback + animation helper), and tests (`game/tests/run_all.gd` + `tools/run_tests.sh`): full simulated battles for every encounter must terminate; balance sanity (a level-appropriate party wins ~85% of random-seed normal battles). Boot `main.tscn` into a simple title that launches `scenes/world/farm.tscn` if it exists (written by rpg-world), else a placeholder.

## models-party | opus | p1 | blender | Party + Nine Lives summon 3D models (Blender)
owns: tools/blender/party_*.py, game/assets/models/hero_*, game/assets/models/summon_*, out/previews/party_*
Author with `blender -b -P` scripts (see `../tools/blender/hero.py`, `rats.py` for the shooter's rig/fur/export approach; reuse helper code by copying, not editing). Stylised-but-lit, charming, instantly readable silhouettes, fully rigged with ALL clips named in ARCHITECTURE section 6. Characters: `hero_fennel` (ginger tabby kitten chef, apron, cheese knife), `hero_brie` (speckled hen wizard with a whisk staff, tiny hat), `hero_clover` (goat knight, skillet shield), `hero_maple` (farm girl with overalls and braided hair, holds a cheese cave lantern). Summons (large ~3 m, ethereal glow materials with emissive rim, flowing fur/stars/wisps, wise eyes): `summon_jesse` (gray cat, silvery mist), `summon_tripper` (American tabby: brown base with bold black stripes and a white chest locket), `summon_samantha` (white cat, halo and soft light), `summon_spooky` (black cat, glowing gold eyes, shadow tendrils, tiny moon on forehead). Each also exports an idle-pose preview PNG; LOOK at every preview and iterate until each looks good (cats must read as cats, each unmistakably distinct). Do the 4 heroes first, then the summons. Also save a turntable-style 3-angle contact sheet per model.

## models-world | sonnet | p1 | blender | NPCs, farm animals, enemies, bosses, farm buildings and props (Blender)
owns: tools/blender/world_*.py, tools/blender/creatures_*.py, game/assets/models/npc_*, game/assets/models/animal_*, game/assets/models/enemy_*, game/assets/models/boss_*, game/assets/models/world_*, out/previews/world_*
Author every model id listed in ARCHITECTURE section 6 (npc_*, animal_*, enemy_*, boss_*, world_*) with Blender scripts: share one `tools/blender/lib_common.py` (primitive helpers, materials, simple armature + animation-clip helpers, glb export). Order of work: (1) animals + enemies (rigged: idle/walk/attack/hurt/down as listed), (2) NPCs, (3) barn/farmhouse/silo/windmill/coop/fences/trees/crops/props (static; barn doors and windmill blades as separate nodes or animations are a bonus), (4) bosses. Stylised-but-lit, charming, consistent palette (warm barn red, hay yellow, grass green, with sickly blue-green Rot on enemies). LOOK at previews (contact sheet per group) and fix what looks wrong. Prioritise breadth first (every id exists and loads in Godot), then quality. Verify each glb loads in Godot (headless import) without errors.

## rpg-world | sonnet | p1 | godot | Open farm overworld, NPCs, dialogue, exploration
owns: game/scenes/world/*, game/scripts/world/*, game/scripts/ui/dialogue_box.gd, game/data/dialogue/*
Build `game/scenes/world/farm.tscn`: a large open outdoor farm built in code from heightmapped/noise terrain with grass, dirt paths, a pond, crop fields, fenced pastures, hills with the cheese cave entrance, orchard (Rainbow Orchard shrine area), barn, farmhouse, silo, windmill, coop, pig pen, trees; sky + sun + soft shadows + fog + SDFGI-or-VoxelGI as the machine tolerates (keep 60 fps). World pieces come from `res://assets/models/world_*.glb` via `ActorFactory`/`load()` with procedural placeholder boxes when missing (models are being authored right now by `models-world`; re-check periodically and the scene must auto-use them once present). Third-person player controller (party leader model `hero_fennel`, chase cam with orbit), animals wander, NPCs idle/patrol/talk with a polished dialogue box (portrait name plate, typewriter text, choices, flags, quest hooks emitting `Events` signals), enemy mobs patrol the fields and trigger `Events.battle_requested(encounter_id)`; campfire/cauldron interaction points (save + cook hooks emit events; UI by others). Write ~20 NPC/animal dialogues in `game/data/dialogue/*.json` with humour and cheese puns, including the main quest line intro (Farmer asks Fennel to find the Last Wheel). Verify with the screenshot tool (`tools/shot.sh`, owned by rpg-core; poll for it) and LOOK at the result from several camera angles; aim for a gorgeous sunny pastoral scene.

## battle-presentation | opus | p2 | godot | 3D battle scene, spell VFX, summon cinematics
owns: game/scenes/battle/*, game/scripts/battle_view/*, game/assets/vfx/*
Make `BattleScene` per ARCHITECTURE section 5: 3D farm-arena backdrop, camera cuts, command menu (Attack/Skill/Cook/Item/Summon/Guard/Flee), target selection, HP/MP bars, status icons, floating numbers, turn order bar, Fondue Gauge, victory/level-up screens. Particle/shader VFX for FIRE (melting cheese flames), ICE (frosty cave crystals), WIND (swirling whey/Swiss holes), EARTH (rind slabs), ROT, LIGHT, SHADE, and four **cinematic summon sequences** (camera sweep, name card, the cat spirit runs/leaps in with signature attack): Jesse, Tripper, Samantha, Spooky. Make them wow.

## cooking-ui | sonnet | p2 | godot | Cooking system UI and mini-game
owns: game/scenes/ui/cooking*, game/scripts/cooking/*
Cauldron/kitchen UI: pick up to 3 ingredients, the pot, a stir timing mini-game, discovery of recipes (cookbook UI with silhouettes of undiscovered), dish quality tiers, juicy food visuals (3D dish models or sprites generated procedurally), used in-world (campfire/cauldron events) and from battle (Cook command).

## menus-audio | sonnet | p2 | godot | Menus, inventory, party screens, shops, music/sfx
owns: game/scenes/ui/menus*, game/scripts/ui/menus*, game/assets/audio/*, tools/gen_audio.py
Pause menu, party status/equipment, inventory, bestiary, summon gallery, shops, save/load slots, settings, title screen polish. Procedural/synthesised or CC0 music and sfx via the pattern in `../tools/gen_audio.py` (farm theme, battle theme, boss theme, victory fanfare, summon sting, cooking sizzle, dialogue blips).

## integ-lead | sonnet | p3 | godot | Integration: world <-> battle <-> menus <-> cooking <-> summons <-> story loop
owns: game/scripts/integration/*, docs/swarm/reports/integ-lead.md
Wire everything end-to-end: new game -> farm -> dialogue -> fights -> cook -> learn summons at the shrine -> boss -> ending. Fix cross-module defects (report to owners if big). Smoke-test with a bot (headless where possible, `tools/shot.sh` screenshots otherwise).

## qa-bot | sonnet | p3 | godot | Automated playthrough + balance QA
owns: game/scripts/qa/*, game/tests/qa_*
Bot that plays through the main quest, validates every encounter, every recipe, every summon; screenshot gallery to `out/qa/`.

## build-all | sonnet | p4 | godot | Linux/Windows/macOS exports, installers, docs, site
owns: tools/build.sh, tools/package_*.sh, game/export_presets.cfg, README.md, docs/*
Mirror the sibling project's build/package pipeline (`../tools/build.sh`, `../tools/package_*.sh`) for this game. Do not push or release without the user asking.
