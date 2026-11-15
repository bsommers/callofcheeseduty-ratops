# audio report

## What I built
- `tools/gen_audio.py`: deterministic numpy generator (crc32-seeded), 32 kHz mono 16-bit. Writes 79 one-shots to `game/assets/audio/sfx/`, 3 ambience loops (`amb/`), 3 music loops (`music/`), plus `manifest.json` with peak/RMS/loop-edge numbers. Total about 8 MB.
  Footsteps stone/wood/metal/wet x4; pistol, gatling, yarn, laser, claws; reloads; dry_fire, weapon_switch, explosion; flesh/headshot/ricochet x3/impacts; bark/hurt/death for mouse, trooper, officer, sewer, panzer, boss; doors; pickups; UI; player; exit/pushwall/secret; level_complete.
- `game/scripts/audio/audio_manager.gd` (`class_name AudioManager`) + `game/scenes/audio_manager.tscn`: creates buses Music/SFX/UI/Ambience (Master exists), volumes from `Settings` audio section (UI and Ambience follow `sfx`), refreshed on `Events.settings_changed`. Pool of 24 AudioStreamPlayer3D + 8 2D players (steal-oldest, bounded), reverb on the SFX bus with presets per zone (room/cellar/sewer/hall/corridor/outdoor), music crossfade, ambience, mood per level id (e1m1-2 cellar, 3-4 sewer, 5-6 hall) via `level_loaded`/`level_started`.
- Connects defensively to Events: sfx, music, player_hurt, player_died, enemy_killed, pickup_taken, key_taken, weapon_changed, door_opened, secret_found, level_completed, level_loaded, settings_changed; and optional `enemy_alerted`, `enemy_hurt`, `door_closed`, `door_locked`, `level_started`, `shot_fired`, `hit` if they get added.
- `game/tests/test_audio.gd`: 7 tests.

## Verification evidence
- `tools/godot.sh --headless --path game --script res://tests/run_all.gd`: 54 passed, 0 failed (7 are test_audio). Parse check clean.
- manifest.json: SFX peaks -1 dB (explosion) to -16 dB; footsteps -12 dB; ambience peak -9 dB, RMS -20..-26 dB; music peak -6 dB, RMS -18..-20 dB. Loop edge sample delta: amb 0.002-0.017, music 0.006-0.007 (full scale 1.0), i.e. no audible click. Nothing clips (all normalised, int16 range checked).
- Not listened to by ear (headless); levels judged numerically only.

## Deviations from the contract
- Did not edit the `Audio` autoload (not mine). Existing `autoload/audio.gd` also handles `Events.sfx` / `Events.music` from `assets/audio/sfx/`; running both double-plays. Set `handle_sfx_signal = false` or remove the old autoload.
- Events has no shot/hit/enemy_alerted signals; shots/hits/footsteps arrive through `Events.sfx(name, pos)`, which the manager maps by name (weapon ids, `reload_<id>`, `footstep*`, `ricochet`, `hit_flesh`, `headshot`, `claw_*`, ...).

## Mistakes I made and how I fixed them
- First generator run crashed on array-length mismatches when summing sounds; added a `mix()` helper that pads to the longest.

## Learnings for a future agent
- Loop flags are set in code on a duplicated AudioStreamWAV, so no `.import` editing is needed.
- Use `bp()/lp()` FFT filters; wrapped placement (`add(..., wrap=True)`) keeps loops seamless.

## Requests for other modules
- godot-core: instance `res://scenes/audio_manager.tscn` (replace the Audio autoload, or keep the autoload name `Audio` pointing at it).
- godot-core: add optional Events signals `enemy_alerted(kind,pos)`, `enemy_hurt(kind,pos)`, `door_locked(id)`; enemy-ai can otherwise emit `Events.sfx("bark_<kind>", pos)`, `hurt_<kind>`.
- level-builder: call `AudioManager.set_zone(...)`/`set_surface(...)` per room if finer than per-level mood is wanted.

---
# audio-v2 update (techno-metal music, aggressive-cute voices)

## What I built
- Music (`tools/gen_audio.py`, `music_stems`/`music_render`): 8-bar seamless loops, all stems placed circularly. Palm-muted double-tracked power-chord guitar (band-limited saws, tanh waveshaper, 90-4200 Hz cab), four-on-the-floor kick with sidechain pump on bass/guitar/lead/pad, snare on 2 and 4, offbeat open hats, reese bass (acid 16th line with swept resonant filter for sewer/boss), industrial clangs, noise riser into the loop point, crashes, 16th arpeggio lead. BPM: cellar 128 (E phrygian, dark), sewer 140 (D, acid + clangs), hall 150 (A minor epic), boss 160, title 138, victory 146 (major lead).
  Files: `music_{cellar,sewer,hall}.wav` = calm/exploration layer (pad, low-passed bass, soft kick on 1 and 3, filtered lead, LP 3.2 kHz); `music_{cellar,sewer,hall}_combat.wav` = full intensity, same length so they sync; `music_boss/title/victory.wav` single full tracks. Old file names kept.
- Voices: `rat_voice(kind, action)` for bark/hurt/death plus new `taunt_<kind>`: pitch lowered (mouse 300 Hz ... boss 58 Hz), glottal saw source with jitter, formant filter, growl rattle AM, soft distortion, 2.5 ms attack, hiss snarl onset, a faint high squeak on top. Hurt/death have playful vibrato wobble, death ends with a deflating "pip". Officer barks 3 rising syllables; panzer/boss have a sub rumble, boss rumble ends in a loud-ish squeak. Hero: `cat_growl`, `cat_meow_1..3`, `cat_purr`, new `player_hurt`/`player_die` (meow yelp / falling meow), purr layered on health/catnip/treasure/extra_life pickups.
- Manager: `alert_combat(seconds)`, `combat_mix` (equal-power crossfade calm<->combat, 0.7 s up, 3 s down), driven by `enemy_alerted` (14 s), `player_hurt` (10 s), `enemy_hurt`/`enemy_killed` (8 s), `noise` with radius >= 10 (8 s); all connected defensively. Level complete now plays `music_victory`; `Events.music("boss"|"title"|"victory")` works through `play_music`. 25% of alerts play `taunt_<kind>`; 15% of kills play a hero meow. Music bus trim -6 -> -8 dB (below SFX).

## Verification evidence
- `run_all.gd`: 86 passed, 0 failed (new tests: extra music/voice streams, combat crossfade). Parse check clean.
- Manifest (peak / RMS / approx LUFS): cellar -6.9/-17.0/-20.1, cellar_combat -3.9/-14.0/-15.6, sewer -5.1/-17.0/-17.7, sewer_combat -4.2/-14.0/-14.4, hall -6.2/-17.0/-18.7, hall_combat -4.0/-14.0/-14.6, boss -4.3/-14.0/-14.3, title -4.1/-14.0/-14.8, victory -4.0/-14.0/-14.6. Combat peaks stay under -3 dB. Voices: peak -4..-6 dB, RMS -17..-22 dB. Full per-file list: `game/assets/audio/manifest.json` (music entries now carry `lufs_approx`).
- Loop seams: first/last sample delta is within the normal sample-to-sample delta (p99), loops are circular by construction.
- Sheets looked at: `out/previews/audio-v2/{music,voices_a,voices_b,cat}.png` (`python3 tools/gen_audio.py --sheet`). They show beat grid, syllables, wobble and the squeak lines. Not listened to by ear.

## Deviations from the contract
- None to the manifest API; added keys: `music_*_combat`, `music_boss/title/victory`, `taunt_*`, `cat_*`.

## Mistakes I made and how I fixed them
- Array length mismatches in `+` of generated parts: used `mix()`.
- Godot imports WAV as QOA, so `loop_end = data.size()/2` was far too short and the loop would have cut early; now `get_length()*mix_rate`.
- Spectrogram colour overflow in the PNG writer; clamped.

## Learnings for a future agent
- Normalise music by RMS then tanh-limit to the ceiling (`finalize_music`) rather than peak-normalise.
- numpy FFT is multithreaded here; `OMP_NUM_THREADS=2` keeps generation polite.

## Requests for other modules
- enemy-ai/player: emit `Events.noise(pos, radius)` for gunshots (radius >= 10) and `enemy_alerted`; boss fight code: `Events.music.emit("boss")`, title screen: `Events.music.emit("title")`.
