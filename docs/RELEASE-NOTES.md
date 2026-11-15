# KÄSEKRIEG: RAT OPS 0.1.0 release notes (2026-11-15)

Photoreal third-person rat-versus-rat shooter (Godot 4.7, Forward+). Unsigned, unnotarised builds.

## What is in the game
- 6 levels (e1m1 to e1m6), 4 difficulty skills (0 Kitten to 3), keys and locked doors, secrets (pushwalls), treasure, exit switch.
- Hero rat with over-the-shoulder camera (shoulder swap), 5 weapon slots plus claws, reload, aim, sprint, crouch, jump.
- Enemy rats with patrol, cover and perception AI, boss with stun; techno-metal music layers, character voices, HUD, menus, minimap/map.

## Controls (defaults)
| Action | Keyboard / mouse | Pad |
|---|---|---|
| Move | WASD or arrows | left stick |
| Look | mouse | right stick |
| Fire / Aim | LMB / RMB | triggers |
| Reload / Use | R / E | face buttons |
| Jump / Crouch / Sprint | Space / C or Ctrl / Shift | buttons |
| Weapons | 1-5, mouse wheel | bumpers |
| Swap shoulder | Q | stick click |
| Map | M or Tab | |
| Pause | Esc or P | Start |

## Requirements
- Linux x86_64: Vulkan 1.2 GPU and driver (Mesa RADV/ANV or NVIDIA), glibc 2.31+, about 1 GB disk, 4 GB RAM.
- Windows 10/11 x64: Vulkan or D3D12 capable GPU, about 1 GB disk, 4 GB RAM.
- macOS 12+ (universal; tested on Apple M4 Pro, Metal 4.0): about 1 GB disk, 8 GB RAM recommended.

## Install and open (unsigned)
- Linux: `tar xzf kasekrieg-ratops-0.1.0-linux-x86_64.tar.gz` and run the launcher inside; or `sudo dpkg -i kasekrieg-ratops_0.1.0_amd64.deb`; or `sh kasekrieg-ratops-0.1.0-linux-x86_64-install.sh`.
- Windows: unzip `KasekriegRatOps-windows-x64-setup.zip`, run `install.cmd` (per user, no admin; `install.ps1 -AllUsers` for Program Files). SmartScreen warns: More info > Run anyway. Uninstall via Apps & Features or `uninstall.ps1`; saves in %APPDATA%\Godot are kept.
- macOS: open the dmg and copy the app to Applications (do not run from the dmg). Then either `xattr -dr com.apple.quarantine "/Applications/KÄSEKRIEG- RAT OPS.app"`, or right-click > Open > Open, or on macOS 15+ open once, then System Settings > Privacy & Security > Open Anyway.
- Verify downloads with `sha256sum -c SHA256SUMS` (`shasum -a 256 -c` on macOS).

## Known issues
- Windows: only a headless boot (exit 0) was verified on the VM; D3D12/Vulkan rendering and title screen were never seen. The exe has the default Godot icon.
- macOS: Metal boot verified (Apple M4 Pro) but no screenshot (ssh has no display grant). `codesign --verify --deep --strict` reports a sealed-resource problem (non-ASCII app name, large PCK in Resources); the app still launches.
- Balance: at skill 2 the QA bot only clears e1m1; at skill 0 it dies repeatedly at ambush clusters on e1m3, e1m5, e1m6. Expect a hard game.
- QA bot (no cover logic) oscillates at the e1m3 exit next to an adjacent trooper; looping clip name mismatch for take_cover.
- Exit switch material may look flat green (placeholder look); runs are not bit-reproducible (enemy RNG unseeded).
- Textures are trimmed/compressed to cut package size (about 190 MB per OS); expect lower texture fidelity than the source assets.
- Windows uninstall.ps1 leaves its folder if the launching session ends within 3 s (delete the folder by hand).
