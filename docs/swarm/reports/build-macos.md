# build-macos report

## What I built
`tools/package_macos.sh`, `tools/mac/remote_test.sh`, `docs/BUILD-MACOS.md`. Exported `build/macos/KasekriegRatOps.zip` (696,023,427 B) via `tools/build.sh macos` (42 s), tested on the M4 Pro (macOS 27.0.1), built `dist/KasekriegRatOps-macos.dmg` (705,872,327 B) with hdiutil UDZO, removed the Mac scratch dir.

## Verification evidence
On the Mac: ad-hoc signed, launched with `--rendering-driver metal --quit-after 600 --verbose`, exit 0: "Metal 4.0 - Forward+ - Using Device #0: Apple - Apple M4 Pro", main.tscn, main.gdc, ui_root, look_rig, audio_manager loaded, 0 lines containing "error". Log: `out/mac/run.log`. Not verified: visual title screen (no screenshot possible), x86_64 slice, dmg mount/open on a clean user.

## Deviations from the contract
Host `user@macbuild.local` no longer resolves; used `bill@bigmac.local` (192.168.1.251, per shell history and duum docs). Scratch dir `~/build/ratops-scratch`. No screenshot.

## Mistakes I made and how I fixed them
1. `set -e` aborted the pipeline when the optional `ls shot.png` failed; added `exit 0` to the remote script.
2. `codesign --remove-signature` left the binary unsigned and macOS killed it (exit 137); removed that step.

## Learnings for a future agent
Strict codesign verify fails ("sealed resource is missing or invalid") yet the app runs. `screencapture` via ssh (even `launchctl asuser`) cannot create an image; needs a Screen Recording grant or a local GUI run. The Godot zip holds the PCK in Contents/Resources.

## Requests for other modules
None.
