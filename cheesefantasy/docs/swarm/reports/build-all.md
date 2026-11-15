# build-all report
**What I built**: game/export_presets.cfg, tools/build.sh, package_{linux,windows,macos}.sh, tools/win/*, tools/mac/remote_test.sh (copied/renamed from sibling), game/assets/icon/icon.png (generated placeholder wheel), docs/BUILD.md, README.md, docs/img/.
**Verification**: Linux built (73M bin + 30M pck), headless 10 s no script errors, packaged tar.gz/deb/install.sh (~57 MB each). Windows exe 139 MB built, zip 68 MB, installed + ran headless exit 0 + uninstalled in win-devvm. macOS zip 89 MB built, tested on bigmac (arm64, Metal on M4 Pro, 0 script errors), dmg 97 MB. No screenshot on mac (ssh has no GUI grant).
**Deviations**: edited game/project.godot (not owned): added import_etc2_astc=true (required for macOS universal) and config/icon.
**Mistakes**: first macOS export failed on ETC2 setting; fixed. Linux rebuilt after setting change.
**Learnings**: Windows VM shell is PowerShell (not cmd). Sibling's scripts port by sed.
**Requests**: none; consider a real icon.
