# model-rats report

## What I built
- `tools/blender/rats.py` builds all six enemy models from a script. Run it with `blender -b -P tools/blender/rats.py -- [kind|all] [--preview] [--clips] [--no-export]`. It writes `game/assets/models/rat_<kind>.glb` for mouse, trooper, officer, sewer, panzer and boss. The output is the same on every run because all seeds are fixed.
- **How the bodies are made:** each body is a union of capsules and ellipsoids. It is voxel-remeshed, smoothed and decimated into one organic fur mesh. Each head has:
  - a long snout and a separate jaw region
  - cheeks and a pink nose
  - glossy eyes (red for the sewer rat, albino red for the officer)
  - big cupped two-sided ears
  - 12 whiskers and orange incisors
  
  Hands have clawed fingers and a thumb. Feet are long, with four clawed toes. The tail is hairless, tapered, with scale rings and cylindrical UVs.
- **Clothes:** these are shells offset from the body: tunic, trousers, cuffs, belt, armband and bandolier. Body faces that are fully covered are deleted. Coats are lofted skirts with a front slit.
- **Per-kind props:**
  - mouse: oversized "coal-scuttle" helmet with chinstrap, rifle, pouches. 1.4 m, big head and ears.
  - trooper: field-grey greatcoat, helmet, diagonal bandolier with cartridges, SMG.
  - officer: lean white rat in a black leather coat, peaked cap with cheese badge and gold cord, monocle, shoulder boards, holster, pistol.
  - sewer: no uniform. Mangy, matted fur displacement, spiked collar with a cheese-wedge tag, hunched stance, claws.
  - panzer: 2.2 m, bulky. Riveted breastplate and backplate, layered pauldrons, welding goggles, a shoulder cheese cannon with dripping cheese and a hopper.
  - boss Der Große Käse: 3.2 m with a huge belly. White uniform, cheese breastplate and pauldrons with gold trim and fringe, aiguillette, medals, red cape, cheese-wheel crown, cigar with an ember, twin gold gatlings.
  
  No real-world insignia: the only emblem is the cheese wedge in a white disc on red.
- **Shared rig:** 35 bones, identical names and hierarchy in all six files. The names match `tools/blender/hero.py` (Godot SkeletonProfileHumanoid style): `Root, Hips, Spine, Chest, Neck, Head, Jaw, Left/RightEar, Left/RightShoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes, Tail1..Tail8`. There are also two non-deform bones, `LeftMuzzle` and `RightMuzzle`, placed at the weapon muzzle and pointing along the barrel. Skinning weights are computed from the distance to each bone segment (normalised by limb radius), with a mouth-line split for the jaw. Hard props are rigid-bound.
- **Clips:** stored as separate actions, which become AnimationPlayer animations: idle, walk, run, aim_idle, fire, reload, hurt, death_a (falls on its back), death_b (crumples forward), take_cover (crouch), melee, taunt. The boss also has charge and slam. Each weapon type has its own stance: rifle, SMG at the hip, one-handed pistol with the other hand behind the back, claws, shoulder cannon, twin gatlings. The sewer rat bites instead of firing and scratches instead of reloading.
- **Nodes in each glb:** `rat_<kind>_LOD0` (skinned), `rat_<kind>_LOD1` (decimated to about 10k triangles, skinned to the same rig) and `weapon` (`weapon_R`/`weapon_L` for the boss). The panzer's cannon is bound to `Chest`.

| kind | LOD0 tris | LOD1 | weapon | height incl. headgear |
|---|---|---|---|---|
| mouse | 34,403 | 9,999 | 480 | 1.53 m (1.40 m without the helmet) |
| trooper | 36,667 | 9,995 | 444 | 1.76 |
| officer | 36,093 | 9,987 | 356 | 1.83 (cap) |
| sewer | 30,126 | 10,000 | 0 | 1.60 |
| panzer | 35,669 | 9,990 | 2,308 | 2.26 |
| boss | 56,507 | 9,959 | 1,024 | 3.31 (crown) |

- **Materials:** PBR, with textures generated in numpy and embedded in the glb: tileable albedo, normal, and ORM (roughness in G, metallic in B). The slot names are `fur`, `skin`, `eye`, `teeth`, `whisker`, `cloth_tunic`, `cloth_pants`, `cloth_cape`, `leather`, `metal`, `metal_gun`, `metal_gold`, `wood`, `emblem`, `cheese`, `glass`, `ember`.
- `game/tests/test_rat_models.gd` checks, for every kind:
  - all 35 bones and every clip, each with a non-zero length
  - one skeleton and one AnimationPlayer
  - the LOD0 budget (40k, or 60k for the boss, counting the weapon) and LOD1 within 12k
  - height within -8% to +15% of the contract
  - the `fur` and `skin` slots exist
  - the model faces -Z

## Verification evidence
- `blender -b -P tools/blender/rats.py -- all` printed the triangle and height figures in the table above, plus `bones=35 actions=12` (14 for the boss).
- `tools/godot.sh --headless --path game --import` reported no errors. `tools/godot.sh --headless --path game --script res://tests/run_all.gd -- rat_models` gave `PASS test_rat_models.gd::test_all_rats  RESULT 1 passed, 0 failed`.
- Re-importing a glb into Blender and evaluating `aim_idle` put the officer's right hand at its expected place: the arm extended forward at shoulder height.
- I looked at three Eevee renders in `out/previews/model-rats/`:
  - `lineup_front.png` and `lineup_34.png`: all six side by side in aim_idle. The silhouettes and palettes are distinct (grey mouse, green-grey trooper, black and white officer, black hunched sewer rat, armoured panzer, white, gold and red boss). Weapons point forward.
  - `clips_trooper_34.png`: idle, walk, run, fire, reload, hurt, take_cover, melee, taunt, death_a and death_b, all reading correctly.

## Deviations from the contract
- **Extra material slots:** beyond `fur/skin/cloth_*/metal/leather/emblem` I added `eye`, `teeth`, `whisker`, `metal_gun`, `metal_gold`, `wood`, `cheese`, `glass` and `ember`. They are needed for eyes, teeth, gold and cheese. Each one carries a full embedded PBR material, so nothing breaks if it is left alone.
- **Sewer rat:** it is bipedal but hunched, because the task said bipedal with a shared rig. The reference defs describe it on all fours.
- **Panzer muzzle:** `RightMuzzle` is parented to `Chest` (the cannon sits on the shoulder). In the other five models it hangs off `RightHand`.
- **Heights:** the contract heights are body heights. The helmet, cap and crown add 4 to 13 cm.
- **Loop flags:** looping is not set in the import. idle, walk, run, aim_idle and charge are authored to loop (the first and last keys match). Enemy-ai should set `Animation.loop_mode = LOOP_LINEAR` on them.
- **Texture files:** on import, Godot unpacked each glb's embedded textures into `game/assets/models/rat_<kind>_rat_*.png`. That is about 27 MB, with the shared normal and ORM maps copied once per kind. In total `rat_*` takes 71 MB.

## Mistakes I made and how I fixed them
- **Bad convex hull:** `bmesh.ops.convex_hull` returned the same vertex in both the interior and unused lists, so the delete failed. I de-duplicated the list with a set.
- **Tail crash:** `(1-u)**0.85` produced a complex number when floating-point error made u slightly above 1. I clamped u.
- **Over budget:** the first build had a 70k-triangle LOD0, because the clothing shells were solidified. I dropped solidify on the large shells and lowered the decimation target for the panzer and boss. The panzer then failed the Godot budget check (40,910 triangles including the weapon), so I decimated it further.
- **Officer coat:** it rendered as a wide horizontal "T" because the skirt loft measured its width from vertices that included the hanging arms. I now use only torso and leg vertices.
- **Wrong preview poses:** with several glbs imported, the actions are renamed `.001` and so on, and I had applied the first rig's action to every rig. The preview now takes each rig's own NLA-track action.
- **Wrong facing:** I first authored the rats facing -Y, which becomes Godot +Z. ARCHITECTURE section 4 and hero.py use -Z forward. `to_game_frame()` now rotates the meshes and armature 180° and renames the bones to hero.py's names before animating. The test asserts that the model faces -Z.

## Learnings for a future agent
- Fastest route to an organic creature: a union of capsules and ellipsoids, then a voxel remesh, a smooth, and a decimate. Clothing is offset copies of body regions, with region labels taken from the nearest bone.
- If every roll is set with `align_roll(forward)`, then +X rotation means "tip goes forward" for every bone. Mirroring right-side poses is then just negating Y and Z.
- Blender 5.3's glTF export in `ACTIONS` mode works if each action is pushed to a muted NLA track and has `use_fake_user` set.
- Headless Eevee works in Blender 5.3 (`BLENDER_EEVEE`).

## Requests for other modules
- **enemy-ai / godot-core:**
  - Set loop mode on idle, walk, run, aim_idle and charge.
  - Use `LOD1` through `visibility_range` (hide LOD0 beyond about 15 m), or delete it and rely on Godot's automatic LODs.
  - Attach muzzle flashes with a BoneAttachment3D on `RightMuzzle` (`LeftMuzzle` too for the boss).
  - The `weapon` node can be hidden or detached on death.
- **shaders-materials:**
  - Apply `fur` with `RatMaterials.apply_fur` to surfaces whose material is named `fur`. UVs are world-scale box projection, 1 UV unit = 0.3 m, so there are seams at axis changes, and the tail is cylindrical.
  - Map `skin` to skin_sss, `cheese` to cheese, `emblem` to emblem (its UVs show two emblems around the arm), `cloth_*` to cloth, and `metal*` to wet_metal or gold_foil.
- **model-hero:** the rat rig uses your bone names but has no `UpperChest` and no finger bones, so retargeting between the two has to skip those.
