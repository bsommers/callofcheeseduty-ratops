# Building CHEESE FANTASY

Presets: `game/export_presets.cfg` (Linux x86_64, Windows x86_64, macOS universal). Templates: `~/.local/share/godot/export_templates/4.7.2.stable`.
`build/` and `dist/` are symlinks to the big disk (`/datanapps/ratops/cf-build`, `cf-dist`); `/` is nearly full.
Project setting `rendering/textures/vram_compression/import_etc2_astc` must stay on (macOS universal export refuses otherwise).

    tools/build.sh linux|windows|macos|all [--debug]   # -> build/<platform>/
    tools/package_linux.sh [--no-build]     # dist/: .tar.gz, .deb, self-extracting -install.sh
    tools/package_windows.sh [--no-build]   # dist/CheeseFantasy-windows-x64-setup.zip (+ .sha256): exe + install.ps1/cmd
    MAC_HOST=user@host tools/package_macos.sh [--no-build]   # export zip, ad-hoc sign + launch test on the Mac, dmg -> dist/

Linux smoke test: `build/linux/cheese-fantasy.x86_64 --headless --quit-after 600` (exit 0).
Windows VM test (`~/src/infra/win-devvm/vm.sh`, guest shell is PowerShell): `push` the zip, `tar -xf`, run `install.ps1`,
launch `--headless --quit-after 300`, `uninstall.ps1 -Quiet`. macOS: `tools/mac/remote_test.sh` runs on the Mac; log in `out/mac/run.log`.
Unsigned builds: Gatekeeper/SmartScreen warn (see the sibling project's docs/BUILD-MACOS.md for the `xattr -dr com.apple.quarantine` workaround).
