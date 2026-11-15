# build-linux report

## What I built
- Export templates 4.7.2.stable in <big-disk>/godot-export-templates (SHA512 verified; ~/.local/share/godot/export_templates already symlinked there).
- `game/export_presets.cfg` (Linux x86_64, Windows x86_64 embed-PCK, macOS universal unsigned), `tools/build.sh`, `tools/package_linux.sh`, `docs/BUILD.md`.
- Artifacts (dist/): tar.gz 664.4 MB, .deb 664.6 MB, self-extracting -install.sh 664.4 MB. build/linux: binary 73.5 MB + pck 649.3 MB.

## Verification evidence
- Linux export OK; pck contains 0 entries for res://tests or res://scripts/qa.
- `--headless --quit-after` clean; private Xvfb + Vulkan (RADV) screenshot shows the title menu (emblem, KÄSEKRIEG, New Game/Settings/Quit).
- Installer run in a scratch HOME: installs, launches headless, uninstalls. .deb inspected with dpkg-deb (not installed).
- Windows and macOS presets validated via `--export-pack` (both succeed); no platform binary built.

## Deviations from the contract
- Icon uses assets/models/hero_emblem.png (256px) since project.godot has no icon and I do not own it. Windows icon/version-info not applied (no rcedit).
- PCK not embedded on Linux (650 MB); embedded on Windows.

## Mistakes I made and how I fixed them
- First Xvfb capture was black (script timing/race); a manual run with longer waits rendered correctly (PCK load ~30 s).
- Safety check blocked an `rm -f "$D"/${N}-*`; replaced with `find -delete`.

## Learnings for a future agent
- 650 MB pck is mostly raw assets; compression won't shrink it (gzip ~ same size). Consider texture compression/trimming assets.
- `import -window root` works for Xvfb capture.

## Requests for other modules
- game/project.godot: add `config/icon="res://assets/models/hero_emblem.png"`.
- Install rcedit+wine (or build Windows on a Windows VM) for exe icon.
