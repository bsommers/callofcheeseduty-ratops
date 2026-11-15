# Building and packaging RAT OPS

Godot 4.7.2 (`tools/godot.sh`). Export templates live in `/datanapps/ratops/godot-export-templates/4.7.2.stable`
(`~/.local/share/godot/export_templates` symlinks to that dir). They come from
`https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
(SHA512 checked against the release's `SHA512-SUMS.txt`: `ca4d71c4...`). Unzip, rename `templates/` to `4.7.2.stable/`.

Presets are in `game/export_presets.cfg` (Linux x86_64, Windows x86_64 with embedded PCK, macOS universal).
Excluded from every pack: `tests/*`, `scripts/qa/*`, `*.md`, `*.blend*`. Icon: `res://assets/models/hero_emblem.png`.
Product name: `KÄSEKRIEG: RAT OPS`.

## Commands

    tools/build.sh linux|windows|macos|all [--debug]   # -> build/<platform>/ (symlink to /datanapps/ratops/build)
    tools/package_linux.sh [--no-build]                # -> dist/ .tar.gz, .deb, self-extracting -install.sh

Equivalent raw export: `tools/godot.sh --headless --path game --export-release "Windows x86_64" ../build/windows/KasekriegRatOps.exe`
(preset names: `Linux x86_64`, `Windows x86_64`, `macOS universal`).

## Linux (done)
Output `build/linux/kasekrieg-ratops.x86_64` + `.pck` (PCK is NOT embedded: ~196 MB after trim). Package outputs go to `dist/`.
Smoke test: `build/linux/kasekrieg-ratops.x86_64 --headless --quit-after 120`; windowed check inside a private Xvfb
(`Xvfb -displayfd`, never `:0`) with `MESA_VK_WSI_DEBUG=sw ... --display-driver x11 --rendering-driver vulkan`, wait ~30 s
for the 650 MB PCK, then `import -window root out.png`.

## Windows (not built here)
Run `tools/build.sh windows` on any host with the templates (Linux can cross-export). Output
`build/windows/KasekriegRatOps.exe` (PCK embedded, plus `_console.exe` wrapper). `application/modify_resources=false`
because `rcedit` (and wine) is not installed, so the exe keeps the default Godot icon/version info; to fix, install
rcedit+wine and set `export/windows/rcedit` in editor settings, then enable `modify_resources`. Test on a Windows VM.
Unsigned: SmartScreen will warn.

## macOS (not built here)
`tools/build.sh macos` produces an unsigned universal `build/macos/KasekriegRatOps.zip` containing the .app (Linux can
export it; signing/notarization is off: `codesign/codesign=0`). On a Mac: `xattr -dr com.apple.quarantine KasekriegRatOps.app`
before first launch, or right-click > Open. For a dmg: `hdiutil create -volname "RAT OPS" -srcfolder KasekriegRatOps.app -ov -format UDZO RatOps.dmg`.
Real distribution needs an Apple Developer ID: set `codesign/identity`, `notarization/*` in the preset.

## Icon and size trim
- Icon: `game/assets/icon/icon.svg` (source), `icon.png` (512, used as `config/icon` and all presets), `icon.ico` (multi-size, for rcedit later; not applied to the Windows exe since wine/rcedit are absent). macOS: Godot builds the .icns from icon.png at export; no standalone .icns tool installed.
- Pack trim (650 MB -> 196 MB PCK, Linux total ~269 MB): texture imports VRAM-compressed (mode 2), 1K for ao/normal/roughness, albedo stays 2K; export filters drop `displacement.jpg`, unused HDRI `bloem_hill_01_2k.hdr` (only material_studio.gd), and unreferenced `models/*.png` duplicates (GLBs embed them). Audio WAVs left as is (15 MB).
