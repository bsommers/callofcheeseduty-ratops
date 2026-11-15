# models-party report (Sun Nov 15 06:29:38 PM UTC 2026)

## What I built
- `tools/blender/party_lib.py` — shared Builder: metaball + primitive parts per material, budgeted decimate, smart-UV,
  numpy texture painter (pattern fn(P,N) + noise + ray AO, auto texture size), PBR materials (+ emissive / alpha), distance-falloff
  skin weights (rigid props pinned to a bone), procedural clips as separate actions, GLB export (Y-up, metres, origin at feet,
  faces glTF -Z), Cycles previews (idle PNG, 3-angle contact sheet, pose sheet). Helpers: `biped_skeleton`, `shell`, `stripes`, `eye_fn` (slit/round/goat "hbar").
- `tools/blender/party_catlib.py` — shared ~3 m Nine-Lives cat (skeleton, body, ears, face, aura shell, paw trails, motes).
- Heroes (9 clips idle/walk/run/attack/cast/hurt/down/victory/defend): `party_fennel.py` (ginger tabby kitten chef, toque, apron, cheese knife),
  `party_brie.py` (speckled Sussex hen wizard, star hat, capelet, whisk staff), `party_clover.py` (goat knight, curled horns, steel plate,
  blue tabard, sword, cast-iron skillet shield), `party_maple.py` (auburn-braided freckled farm girl, plaid shirt, overalls, boots, glowing cheese-cave lantern).
- Summons (clips idle/summon_intro/special/outro): `party_summon_jesse.py` (gray, silvery mist), `party_summon_tripper.py` (brown tabby, bold
  black stripes, white chest locket, amber stones), `party_summon_samantha.py` (white, golden halo, soft light), `party_summon_spooky.py`
  (black, glowing gold eyes, shadow tendrils, crescent moon on forehead).
- Outputs: `game/assets/models/{hero_*,summon_*}.glb`; previews `out/previews/party_<id>/<id>.png`, `<id>_contact.png` (3-angle), `<id>_poses.png`.

## Verification evidence
- Each script runs clean: `blender -b -P tools/blender/party_<name>.py` (~15–35 s); logs in `out/logs/party_*.log`.
- `blender -b -P test/party_models_check.py` re-imports all 8 GLBs: 8/8 OK — all clips present, armature 18–25 named bones,
  tris 27.0k–29.5k (<30k), heights heroes 1.16–1.35 m, summons 3.16–3.30 m, origin at feet.
- `tools/godot.sh --headless --path game -s ../test/party_models_godot.gd` (after `--import`): 8/8 spawn via ActorFactory as real models with every contract clip.
- Looked at every contact sheet and iterated (hen speckle scale, comb/hat, goat rivets, cat proportions/ears/wisps, Tripper stripes); pose sheets checked for fennel and two summons (rig + clips deform correctly).

## Deviations from the contract
- Previews go to `out/previews/party_<id>/` (my owned path) instead of `out/previews/<id>.png`.
- Extra material slots beyond the named list where it helped readability (`eye`, `whisker`, `hair`, `horn`, `beak`, `skin_comb`, `metal_iron`, `glass`, `aura`, `wisp`, `cheese`).
- Summon aura shells (alpha-blended, emissive) sit up to 8 cm below the floor plane (glow only). Tripper has no aura shell (it washed out his stripes); his glow comes from emissive fur veins and orbiting amber stones.
- `special` summon clip moves Root forward ~3.6 m and back (pounce); `outro` scales Root to 0.1 while rising.

## Mistakes I made and how I fixed them
- Preview floor could leak into export → it is now registered in `extra_render` (and scripts export before previews).
- Indentation bug from a string-replace in `previews` → fixed and parse-checked.
- First cat had dog-like long legs, small head and poor framing → reproportioned (shorter legs, bigger head), reframed, darker exposure for summons.
- Rising wisps read as spikes/horns → replaced with low flowing paw trails.
- A poll loop `pgrep -f '[p]arty_summon'` matched my own shell command line → stopped it; used `wait` instead.
- Re-import check counted the glTF importer's bone-shape "Icosphere" → filter to meshes parented to the armature.

## Learnings for a future agent
- AgX tone mapping desaturates previews; check albedo PNGs in `out/previews/party_<id>/tex/` before boosting colours.
- Translucent emissive shells over a patterned body wash out patterns; keep alpha ≤ 0.1 or skip them.
- Clip rotations are in character axes (X right, Y forward, Z up; degrees), rx>0 swings limbs forward.
- PARTY_POSES=0 skips the pose sheet for fast iteration; PARTY_SAMPLES sets Cycles samples.

## Requests for other modules
- battle-presentation: summons are 3 m and `special` travels ~3.6 m forward; leave room or zero the root motion. Aura/wisp materials are alpha-blended (sorting).
- None blocking.
