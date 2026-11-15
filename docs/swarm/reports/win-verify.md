# win-verify report

## Done (user-approved)
Autologon enabled in the Windows dev VM (Winlogon AutoAdminLogon/DefaultUserName/DefaultPassword from win-devvm config.env, never printed), VM rebooted; `query user` shows `dev` active on console. Autologon is LEFT ENABLED. Installed dist/KasekriegRatOps-windows-x64-setup.zip (built 02:53) via install.ps1, launched via `schtasks /it /ru dev`, screenshotted with CopyFromScreen. Script saved as `tools/win/verify_screens.ps1` (run in the interactive session via schtasks).
Evidence: /datanapps/ratops/out/win-verify/{menu.png,level-1..3.png,game-menu.log,game-level.log}

## Renderer / fonts / UI: OK
- Vulkan fails in the VM (VK_KHR_surface missing, virtio GPU); Godot auto-falls back to D3D12 12_0 Forward+ on "Microsoft Basic Render Driver" (WARP). Window renders fine.
- Main menu renders correctly: fonts (Käsekrieg umlaut), cheese logo, buttons, skill dropdown. Expected VM-only: WASAPI has no audio device -> dummy audio driver.

## BLOCKER: levels do not load (all platforms, not Windows-specific)
New Game (Enter) stays on the menu. game-level.log: 568x `No loader found for resource: res://assets/models/*.png (expected type: Texture2D)` then `Failed loading resource: res://assets/models/{hero,rat_*,prop_*,weapon_*}.glb`.
Cause: `exclude_filter` in game/export_presets.cfg (all 3 presets, from commit e5216fb "trimmed assets") excludes `assets/models/prop_*.png, rat_*.png, weapon_*.png, hero_hero_*.png, hero_eye_albedo.png, hero_gear_*.png`. The imported .glb scenes reference those PNGs as external textures, so excluding them drops their .ctex remaps and the glbs fail to load. build/linux/kasekrieg-ratops.pck has the same defect (no rat_mouse_rat_wood_normal entry) -> Linux/macOS builds are broken too.
Fix needed (not applied: export config + other agents are modifying hero/rat_*.glb in the working tree): remove those PNG patterns from exclude_filter (or embed the textures in the glbs and re-import), rebuild, repackage, re-run tools/win/verify_screens.ps1. Trimming must be validated by loading a level, not just a headless quit.

## Other notes
- Packaged build tested is stale vs working tree; re-verify after rebuild.
- Not committed/pushed.
