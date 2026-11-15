# package-trim report
## What I built
App icon (SVG/PNG/ICO) in game/assets/icon, config/icon + presets pointing at it; texture imports set to VRAM compressed (1K for normal/ao/roughness, 2K albedo); export_filter exclusions (displacement maps, bloem_hill HDRI, unreferenced model PNGs) in all 3 presets; BUILD.md notes.
## Verification evidence
PCK 649 MB -> 196 MB (build 723 -> 269 MB). Screenshots e1m1 same camera before (out/shots/look/final_e1m1_1.png) vs after (out/shots/trim_after.png): visually equivalent. tools/run_tests.sh: 90 passed, 0 failed. Linux build + package_linux (tar.gz/.deb/install.sh ~176 MB) ok; headless boot of the built binary: no errors.
## Deviations from the contract
No .icns produced (no tool); Windows exe icon not applied (no rcedit/wine). WAV->Ogg skipped (only 15 MB, loop-end risk). HDR 2K kept except unused one. Windows/macOS not rebuilt (dist still holds old 675 MB windows zip).
## Mistakes I made and how I fixed them
First icon wedge overflowed the disc; shrank and re-rendered. "Before" screenshot was taken from a pre-existing shot, since imports were changed before I captured one.
## Learnings for a future agent
Textures were imported lossless (mode 0) which made the PCK huge; mode 2 is the main win. Exclusions in export_filter shrink the PCK without touching sources.
## Requests for other modules
None.
