# model-hero report (2026-11-15T04:09:36Z)

## What I built
- `tools/blender/hero.py` (one script, ~40 s incl. previews): Major Marmalade, orange tabby, 1.9 m incl. ears, faces Godot -Z, right +X, feet at y=0.
  Body = metaballs (cranium, jowls, whisker pads, nose, brow, broad torso, digitigrade-ish legs with raised hock, 5-digit mitten paws, tail) + cone ears,
  voxel-remeshed (5.5 mm) and decimated; separate eyes (slit pupils), 14 whisker tubes, tactical vest + shoulder straps + belt extracted from the body surface,
  mag/radio/belt pouches, metal snaps/buckles/antenna, cheese-wedge patch on left chest (no real insignia).
- Material slots: `fur`, `skin` (nose, palm/foot pads, inner ears) on Hero_Body; `cloth_vest`, `leather`, `metal` on Hero_Gear; `emblem` on Hero_Patch; extra `eye`, `whisker`.
- Textures in `game/assets/models/`: hero_body_albedo.png (2K baked procedural tabby: distorted body rings, tail rings, forehead stripes, cream chest/muzzle),
  hero_fur_length.png (R = fur length mask for fur.gdshader `length_mask`; 0 under vest/belt and pads, short on face/paws), hero_gear_albedo/normal.png (MOLLE webbing),
  hero_eye_albedo.png, hero_emblem.png. Fur length is also exported as vertex colour COLOR_0 on the body.
- Rig "HeroRig", 64 bones named after Godot SkeletonProfileHumanoid (Root, Hips, Spine, Chest, UpperChest, Neck, Head, Jaw, Left/RightEye, *Shoulder, *UpperArm,
  *LowerArm, *Hand, *Thumb{Metacarpal,Proximal,Distal}, *{Index,Middle,Ring,Little}{Proximal,Intermediate,Distal}, *UpperLeg, *LowerLeg, *Foot, *Toes) + Tail1..Tail6, LeftEar, RightEar.
- 19 clips (actions, in place, every bone keyed): idle, walk, run, sprint, crouch_idle, crouch_walk, jump, fall, land, aim_idle, aim_walk, fire_pistol, fire_rifle, reload,
  melee_slash, hurt, death_a (falls back), death_b (crumples forward), victory. Built from a pose solver with analytic 2-bone IK for arms (hand targets from a gun frame) and legs (ball-of-foot targets).
- LOD0 54.7k tris (Hero_Body 43k, Hero_Gear, Hero_Patch, Hero_Eyes, Hero_Whiskers); LOD1 14.6k tris (meshes suffixed `_LOD1`, same skeleton) in the same glb.
- `game/tests/test_hero_model.gd`: bones, 19 clips with tracks, LOD0/LOD1 budgets, material slots, height/feet.

## Verification evidence
- `blender -b -P tools/blender/hero.py` -> hero.glb 22 MB, log "LOD0 tris 54706 LOD1 tris 14582", 0 verts needed fallback weights.
- `tools/godot.sh --headless --path game --import` OK; `run_all.gd -- hero`: RESULT 4 passed, 0 failed.
- Previews (looked at): out/previews/model-hero/turntable.png, poses.png (12 clips), head.png. Face, eyes, whiskers, vest, patch, tail and all poses read correctly.

## Deviations from the contract
- Extra material slots `eye` and `whisker` (not in the slot list). Gear cloth slot is `cloth_vest`.
- LOD1 lives in hero.glb as `*_LOD1` meshes rather than a separate file (not in my owned paths); the consumer must hide one set.
- Clips do not carry loop flags (names must stay exact); loopers: idle, walk, run, sprint, crouch_idle, crouch_walk, fall, aim_idle, aim_walk, victory.
- Godot extracts embedded glb textures as hero_hero_*.png (duplicates of hero_*.png; harmless).

## Mistakes I made and how I fixed them
- `view_layer.objects` held a None after `bpy.data.objects.remove` -> set_active now updates the view layer and skips None.
- Belt region test caught the tail tip (same height) -> added y > -0.2.
- Head/neck pitch sign was inverted (positive looked up) -> negated in build(); positive now nods down.
- First stripes were regular candy rings and too pale -> stronger noise distortion, thinner stripes, deeper orange.

## Learnings for a future agent
- Metaball surface radius = 0.575 x element radius (stiffness 2, threshold 0.6); metaballs + voxel remesh + decimate gives a clean, auto-weightable creature in seconds.
- Express pose deltas in rest-armature axes and convert with q_local = R^-1 q R: makes IK and readable eulers independent of bone roll.
- Blender 5.3 glTF exporter with export_animation_mode=ACTIONS exports every action as a separate Godot animation.

## Requests for other modules
- player-controller: set loop_mode on the looping clips listed above; hide `*_LOD1` meshes (or use visibility ranges); attach the weapon with BoneAttachment3D on RightHand
  (grip at the hand bone tip, gun forward = character forward); locomotion speed at 1x playback: walk ~1.0 m/s, run ~3.0 m/s, sprint ~4.8 m/s, crouch_walk ~0.6 m/s, aim_walk ~0.8 m/s.
- shaders-materials: fur shell on slot `fur` with length_mask = hero_fur_length.png and color_map/albedo = hero_body_albedo.png (stripes already baked, so stripe_amount 0); body UV is a smart-projected atlas (~1 UV unit = 2 m), so set density for that.
- Known limits: mitten-style paws (fingers blend), slight knock-kneed stance, fur look depends on the shell shader (previews show the bare albedo).
