# Documentation index

Start at the [README](../README.md) for what the game is and how to install and run it.

## Playing

| Doc | What it covers |
|---|---|
| [CONTROLS.md](CONTROLS.md) | Keyboard, mouse and gamepad bindings, tips, command-line flag |
| [LEVELS-AND-ENEMIES.md](LEVELS-AND-ENEMIES.md) | The six levels, six enemy kinds, five weapons, items, skill levels |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | 0.1.0 contents, requirements, install and open steps, known issues |

## Understanding the code

| Doc | What it covers |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Runtime structure, signal bus, level pipeline, rendering, testing |
| [../ARCHITECTURE.md](../ARCHITECTURE.md) | The original binding contract the agents built against |
| [ASSETS.md](ASSETS.md) | Every third-party texture and HDRI with source URL and licence |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Setup, checks before a PR, conventions, gotchas |

## Building and shipping

| Doc | What it covers |
|---|---|
| [BUILD.md](BUILD.md) | Export templates, `tools/build.sh`, Linux packaging, icon and size trim |
| [BUILD-WINDOWS.md](BUILD-WINDOWS.md) | Windows export, setup zip, VM testing |
| [BUILD-MACOS.md](BUILD-MACOS.md) | macOS universal export, dmg, Gatekeeper |
| [PRINTING.md](PRINTING.md) | OBJ/STL export of characters, props and level dioramas, scales, print advice |

## The swarm story

| Doc | What it covers |
|---|---|
| [HOW-IT-WAS-MADE.md](HOW-IT-WAS-MADE.md) | Narrative: manifest, tiers, 4-agent cap, checkpoints, pipelines, lessons, limitations |
| [swarm/SWARM.md](swarm/SWARM.md) | The manifest: preamble, role rules, all 23 agent tasks |
| [swarm/LEARNINGS.md](swarm/LEARNINGS.md) | Running learnings log template |
| [swarm/CHECKPOINT.md](swarm/CHECKPOINT.md) | Orchestrator checkpoint snapshot |
| [swarm/reports/](swarm/reports/) | One report per agent |

Agent reports: [godot-core](swarm/reports/godot-core.md), [assets-fetch](swarm/reports/assets-fetch.md), [shaders-materials](swarm/reports/shaders-materials.md),
[level-builder](swarm/reports/level-builder.md), [model-hero](swarm/reports/model-hero.md), [model-rats](swarm/reports/model-rats.md),
[model-weapons-props](swarm/reports/model-weapons-props.md), [player-controller](swarm/reports/player-controller.md), [ui-hud-menus](swarm/reports/ui-hud-menus.md),
[audio](swarm/reports/audio.md), [enemy-ai](swarm/reports/enemy-ai.md), [integ-lead](swarm/reports/integ-lead.md), [look-dev](swarm/reports/look-dev.md),
[botplay-qa](swarm/reports/botplay-qa.md), [polish-gameplay](swarm/reports/polish-gameplay.md), [polish-visual](swarm/reports/polish-visual.md),
[build-linux](swarm/reports/build-linux.md), [build-windows](swarm/reports/build-windows.md), [build-macos](swarm/reports/build-macos.md),
[package-trim](swarm/reports/package-trim.md), [rebuild-all](swarm/reports/rebuild-all.md), [print-models](swarm/reports/print-models.md).

## Related repositories

- [game-factory](https://github.com/bsommers/game-factory): reusable tooling for building games with agent swarms.
- [KÄSEKRIEG: Claws of Marmalade](https://github.com/bsommers/kasekrieg): the 2.5D predecessor.
- [Project site](https://bsommers.github.io/callofcheeseduty-ratops/) and [Releases](https://github.com/bsommers/callofcheeseduty-ratops/releases).
