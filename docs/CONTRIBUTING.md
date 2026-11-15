# Contributing

Thanks for looking. This is a small experimental project; issues and pull requests are welcome.

## Setup

1. Install Godot 4.7.x (a Vulkan-capable GPU is needed for Forward+). Optional: Blender 5.3 (model and print scripts), Node.js (tooling, no npm packages needed), Python 3 with numpy (audio).
2. Clone the repo. All assets are committed, so `godot --path game` runs the game.
3. `tools/godot.sh` expects a project-local binary at `.tools/godot/Godot_v4.7.2-stable_linux.x86_64`. Edit it to point at your install if you want the scripts to work unchanged.

## Before you open a pull request

```sh
tools/godot.sh --headless --path game --import    # refresh the class cache after adding a class_name
tools/godot.sh --headless --path game --quit      # parse check: no errors or warnings from your files
tools/run_tests.sh                                # all headless tests must pass
tools/qa.sh e1m1 --god                            # if you touched gameplay, level or AI code
```

For visual changes, attach a render: `tools/shot.sh <level-id> out.png` (renders offscreen; do not commit large images, and keep committed PNG/JPG under about 300 KB).

## Conventions

- **Read [ARCHITECTURE.md](../ARCHITECTURE.md) and [docs/ARCHITECTURE.md](ARCHITECTURE.md).** Modules talk through the `Events` autoload; avoid hard references across modules.
- **GDScript is typed**, with `class_name` for reusable nodes. Keep scenes small and build repetitive structure in code. Never commit `.godot/`.
- **Data over code.** Balance goes in `game/data/*.json` and `Defs`; level moods in `game/data/look/`. Do not hard-code numbers that a data file already owns.
- **Models, audio and levels are generated.** Change the source (`tools/blender/*.py`, `tools/gen_audio.py`, `tools/convert_levels.mjs`) and regenerate, rather than editing the output in place.
- **Assets must be CC0 or your own**, and recorded in [ASSETS.md](ASSETS.md) with source and licence. No third-party trademarks, and no real-world hate symbols (the enemy emblem is a cheese wedge).
- **Tests.** Logic tests are `game/tests/test_*.gd`; a new module should come with one. Headless runs use a dummy renderer: it cannot compile shaders or read back textures, so use `tools/shot.sh` for those.
- **Commits.** Short imperative subject, one logical change.

## Known gotchas

- After adding a `class_name`, run the `--import` command above or lookups fail on a cold `.godot/`.
- Godot emits `Events.level_loaded` twice per level; key on the level builder's `built` signal.
- Use `is_instance_valid()` for nodes that may have been freed; `!= null` is not enough for a Variant.
- More in [swarm/LEARNINGS.md](swarm/LEARNINGS.md) and the "Learnings" section of each [agent report](swarm/reports/).

## Working with agents

The project was built by AI agents against a manifest; if you want to do the same, read [HOW-IT-WAS-MADE.md](HOW-IT-WAS-MADE.md) and the
[game-factory](https://github.com/bsommers/game-factory) repo, which collects the reusable tooling.

## Licence

Contributions are licensed under [Apache-2.0](../LICENSE), the repository licence.
