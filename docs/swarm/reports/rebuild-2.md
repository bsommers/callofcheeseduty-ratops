# rebuild-2 report
## Results
1. tools/run_tests.sh: 90 passed, 0 failed.
2. Rebuilt + packaged (all under /datanapps/ratops/dist; export_presets no longer drops model PNGs):
   - Linux: tar.gz 218,671,980 B; deb 218,818,090 B; install.sh 218,672,846 B (binary 73.5 MB + pck 239.1 MB)
   - Windows: setup zip 232,036,656 B (exe 348 MB)
   - macOS: dmg 263,734,558 B (zip 250,127,863 B); launched on M4 Pro, Metal 4.0
   Note: dist/SHA256SUMS (02:55) is stale; not regenerated.
3. Packaged Linux build, headless `-- --level=e1m1/e1m4/e1m6`: rc 0, zero "No loader found"/"Failed loading"/SCRIPT ERROR lines.
4. Windows verify (tools/win/verify_screens.ps1 updated: AppActivate + mouse click on New Game, 4 shots at 30 s intervals): New Game reaches e1m1 "The Cheese Cellar" (HUD, hero, fur, brick/wood PBR, warm lighting render fine on WARP/D3D12). Level load takes ~2-3 min under software WARP in the VM (window frozen meanwhile); SendKeys Enter alone did not work. 0 loader errors in game-level.log. Screens: /datanapps/ratops/out/win-verify/. Rendering is dark/low-contrast with large flat orange emissive panels (art/lighting judgement for owner).
5. tools/qa.sh all --god: all 6 levels exit reached, 0 deaths, 0 errors, rc 0.
## Cleanup
Windows VM autologon reverted: AutoAdminLogon=0, DefaultPassword removed (DefaultUserName=dev remains, harmless), scheduled task rv deleted, ~/ratops removed. Not committed/pushed.
