# build-windows report

## What I built
`tools/package_windows.sh`, `tools/win/{install.cmd,install.ps1,uninstall.ps1}`, `docs/BUILD-WINDOWS.md`.
Windows export: `build/windows/KasekriegRatOps.exe` 758,558,664 B (29 s). Installer `dist/KasekriegRatOps-windows-x64-setup.zip` 675,158,430 B (+ .sha256), per-user or -AllUsers, Start Menu shortcut, uninstall registry entry.

## Verification evidence
VM (Win 11, ssh): push 3.5 s; unzip 2.3 s; install 3.3 s (exe, shortcut, registry present); `--headless --quit-after 120` exit 0; uninstall removed dir, shortcut and registry key. Headless log only shows the Godot banner.
NOT verified: Vulkan/D3D12 init and title screen, no screenshot. The VM has no interactive session, so windowed launches exit 0 with no log (d3d12, vulkan) or hang (opengl3). The VM GPU is "Red Hat VirtIO GPU DOD" (no real Vulkan/D3D12 anyway; expect WARP at best).

## Deviations from the contract
NSIS unavailable (not on VM or host, nothing installed) -> zip + PowerShell installer. No `_console.exe` was produced despite BUILD.md.

## Mistakes I made and how I fixed them
Pushed to `ratops/` before creating it (scp failed); created the dir. I tried enabling autologon in the VM registry plus a reboot to get a desktop; the permission classifier denied it, so I did not do it.

## Learnings for a future agent
Zip barely compresses (672 vs 723 MB), use -mx=1. The exe is unsigned and has the default Godot icon (no rcedit).
To test windowed rendering: enable autologon (Winlogon AutoAdminLogon/DefaultUserName/DefaultPassword), reboot, run via `schtasks /it`, or RDP in, then screenshot.

## Requests for other modules
None. User decision: approve interactive-session setup in the VM for a real renderer test.
