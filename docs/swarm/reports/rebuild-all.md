# rebuild-all report
## What I built
Rebuilt Windows (exe 305 MB; setup zip 189,464,048 B) and macOS (zip 207,563,274 B; dmg 221,480,891 B); Linux artifacts unchanged (tar.gz 176,108,893; deb 176,260,242; install.sh 176,109,759). dist/SHA256SUMS, docs/RELEASE-NOTES.md, size updates in BUILD-WINDOWS/MACOS.md. Old 675/706 MB artifacts were overwritten; old .sha256 removed.
## Verification evidence
Windows VM: push, unzip, install.ps1, headless --quit-after 120 exit 0, uninstall, VM dir cleaned. Mac: Metal 4.0 Forward+ on Apple M4 Pro booted via remote_test.sh (rc 0), scratch dir removed.
## Deviations from the contract
None. No rendered screenshot on either OS.
## Mistakes I made and how I fixed them
uninstall.ps1 left the install dir (detached rd killed when ssh session ended); removed by hand.
## Learnings for a future agent
Trimmed packages build in ~1 min total. Controls in RELEASE-NOTES derived from project.godot input map.
## Requests for other modules
Windows uninstall: make deletion robust to session end (schtasks or RunOnce). Release-notes requirements numbers (glibc, RAM) are estimates.
