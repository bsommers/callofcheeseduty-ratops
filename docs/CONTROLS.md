# Controls

Defaults come from the `[input]` section of [`game/project.godot`](../game/project.godot). All of them can be rebound in
**Settings** (title or pause menu). Mouse look is the default; sensitivity is in Settings. A gamepad is supported.

| Action (InputMap name) | Keyboard / mouse | Gamepad |
|---|---|---|
| Move (`move_forward/back/left/right`) | W A S D or arrow keys | left stick |
| Look (`look_*`) | mouse | right stick |
| Fire (`fire`) | left mouse button | right trigger |
| Aim down sights (`aim`), hold | right mouse button | left trigger |
| Reload (`reload`) | R | face button |
| Use / open doors / press switches (`use`) | E | face button |
| Jump (`jump`) | Space | A / cross |
| Crouch (`crouch`) | C or Ctrl | button |
| Sprint (`sprint`) | Shift | button |
| Weapon slots 1 to 5 (`weapon_1..5`) | 1, 2, 3, 4, 5 | |
| Next / previous weapon | mouse wheel up / down | bumpers |
| Swap shoulder (`shoulder_swap`) | Q | stick click |
| Map (`map`) | M or Tab | button |
| Pause (`pause`) | Esc or P | Start |

## Tips

- Accuracy drops while moving and in the air, and improves when crouching or aiming (see `spread_move`, `crouch_mult`, `ads_mult` in [`weapons.json`](../game/data/weapons.json)). The automatic Purr-forator has a 12-step recoil pattern that you can learn.
- Headshots do 2.5x damage. Damage falls off beyond 40 m, down to 55 %.
- Gunfire is noise: nearby enemies hear it (walls halve the range). Claws are quiet.
- Doors marked gold or silver need the matching key. Some walls slide when you press Use next to them: those are secrets.
- Death costs one of your nine lives and restores the score and weapons you had at level start.

## Command line

```sh
godot --path game -- --level=e1m3     # skip the title and start a level
```

See [LEVELS-AND-ENEMIES.md](LEVELS-AND-ENEMIES.md) for what you will meet.
