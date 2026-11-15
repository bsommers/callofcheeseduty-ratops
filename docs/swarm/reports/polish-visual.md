# polish-visual report

## What I built
- Exit switch: `ExitSwitchProp` (steel plate, red lever, small green emissive lamp, green practical light) built in `level_builder.gd::_build_switch_prop`; `wall.exit_switch` material is now a plain warm-grey wall (the old emissive green wall is gone).
- Level builder: no ceiling quads for `ceil.sky`; lights tagged `look_kind` (zone/practical), `zone`, `decor_id`; decor nodes carry `decor_id` meta.
- Look rig: per-decor overrides via `practicals.decor.<id>` (e1m1 `glow_cheese` now warm yellow, 0.5x energy); `no_em_mul` meta skips emission scaling; e1m1 `emission_mul` 5.0 -> 1.5.
- `tests/shot.tscn` level-id mode now instances the look rig and runs `PropSetup.apply`, so shots match the game (e1m3 is lit).
- `tests/test_polish_visual.gd` (passes), `test_level_builder` still passes.

## Verification evidence
Screenshots in out/shots/pv_*.png: exit switch (e1m1), glow cheese room, e1m3, e1m4. Parse check clean.

## Deviations from the contract
None. The look rig still infers zone lights by height as a fallback.

## Mistakes I made and how I fixed them
- Assumed the exit cell was a floor cell; it is the X wall cell, the switch goes on its +facing face.
- The "bright green wall" was the wall.exit_switch emission (look rig exposure amplifies emission heavily), not an unlit material; removed emission from the wall.

## Learnings for a future agent
- Emission values above ~0.1 blow out under the rig's exposure; use albedo + small lamp emission.
- Metallic surfaces render black (no reflections probes near them).

## Requests for other modules
- integ-lead: none needed; main.gd already calls PropSetup.
- Not done: AO decals, and a full z-fighting sweep of all 6 levels (only e1m1/e1m3/e1m4 viewed).

## Pass 2: six-level sweep + contact shading
- Shots (out/shots/pv2_*, pv3_*, pv4_*, pv5_*): e1m1-e1m6 from start; e1m2/e1m5/e1m6 examined in detail, e1m4 before/after.
- Found: (1) blown-out white floor blobs in e1m4 and e1m6: level `light` things placed at floor height (<1.5 m) next to the start, treated as practicals with 1.5x energy and high specular. Fix in `look_rig.gd::_tune_level_lights`: non-decor, non-zone lights below 1.5 m are capped at `low_cap` (default 0.8) energy and specular 0.1. Confirmed on e1m4 and e1m6.
- (2) e1m2 flat light-grey wall slab: `wall.poster/war_map/trophy/mouse_hole/mirror/cell_bars/cheese_glass/exit_switch` had no look material (flat placeholder). Mapped to library textures in `data/look/default.json`; confirmed textured on e1m2.
- (3) e1m6 over-hot: lights energy_mul 2.4 -> 1.0, zone n/f capped 1.3, specular 0.2, exposure 0.85, glow 0.5.
- Contact shading: SSAO retuned in default.json (radius 1.1, intensity 3.0, power 1.7, detail 0.7, light_affect 0.25). SSAO was already on, so extra GPU cost is ~0 (parameter change only; no decals added, no new passes). Not measured with a profiler.
- No z-fighting or black voids seen in the 6 shots. e1m5 reads as dark blue but not unlit. e1m6 glow_cheese still reads slightly green (only e1m1 has a warm override).
- Tests: parse check clean, test_polish_visual PASS. Not re-run: e1m3 (checked in pass 1).
