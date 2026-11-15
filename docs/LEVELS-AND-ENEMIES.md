# Levels, enemies, weapons and items

All numbers on this page are read from the data files, which are the source of truth:
[`game/data/levels/`](../game/data/levels), [`enemies.json`](../game/data/enemies.json),
[`weapons.json`](../game/data/weapons.json) and [`game/autoload/defs.gd`](../game/autoload/defs.gd). Gameplay numbers are ported
from the 2.5D predecessor [KÄSEKRIEG](https://github.com/bsommers/kasekrieg); distances are scaled (1 reference cell = 4 m).

## Levels

Each level is one JSON file: a wall grid, a zone grid (ceiling height, lighting zones), doors, pushwalls, and a list of
things (enemies, items, decor, lights). A runtime builder turns it into 3D ([`level_builder.gd`](../game/scripts/level/level_builder.gd)).
A per-level mood lives in [`game/data/look/`](../game/data/look).

| Id | Name | Grid | Par | Enemies | Treasure | Secrets | Keys | Music | Mood |
|---|---|---|---|---|---|---|---|---|---|
| e1m1 | The Cheese Cellar | 32x32 | 4:00 | 19 | 20 | 3 | gold | level_a | torchlit amber, dusty haze, a cool blue-cheese room |
| e1m2 | Rat Barracks | 36x36 | 5:00 | 28 | 9 | 3 | silver | level_b | cold institutional bulbs, desaturated grey-green |
| e1m3 | The Fondue Works | 38x38 | 7:00 | 22 | 15 | 3 | gold | level_c | molten orange furnace glow, steam haze |
| e1m4 | Moonlit Hall of Mirrors | 42x42 | 5:00 | 24 | 8 | 4 | gold, silver | level_a | blue moonlight, starry open courts, glossy marble |
| e1m5 | The Blue Vault | 42x42 | 6:00 | 26 | 15 | 6 | gold, silver | level_c | teal mould haze, wet cobbles, a gold vault |
| e1m6 | Throne of the Big Cheese | 32x32 | 6:00 | 18 | 5 | 4 | silver | boss | crimson haze, golden throne, boss fight |

Enemy counts are the level's own `stats.enemies`. Each level ends at an exit switch, then an intermission card
(kills, secrets, treasure, time against par). Victory screen after e1m6.

## Enemies (Das Rattenreich)

| Kind | Name | HP | Speed (m/s) | Height (m) | Score | Attack | Drops |
|---|---|---|---|---|---|---|---|
| `mouse` | Maus Schütze | 25 | 1.9 | 1.4 | 100 | pistol, 3 to 9 damage | ammo clip |
| `trooper` | Sturmratte | 50 | 2.5 | 1.7 | 300 | SMG, 3-round burst, 3 to 8 each | Purr-forator or ammo clip |
| `officer` | Ratten-Offizier | 40 | 3.9 | 1.8 | 400 | fast pistol, 4 to 11 | ammo clip |
| `sewer` | Kanalratte | 14 | 4.7 | 1.5 | 150 | melee, 3 to 8 | none |
| `panzer` | Panzerratte | 120 | 1.6 | 2.2 | 700 | lobbed cheeseball with splash, 14 to 28 | yarn ammo |
| `boss` | Der Große Käse | 1100 | 2.2 | 3.2 | 10000 | 8-round burst, 3 to 7 each | cheese crown |

**Behaviour** ([`enemy.gd`](../game/scripts/enemy/enemy.gd)): a state machine of idle, patrol, alert, chase, attack, take cover and retreat.
Enemies see through a 70 degree cone with a line-of-sight ray, feel you at close range, and hear noise events (gunfire alerts friends; walls halve
the hearing range). They navigate on the level navmesh, search for cover points you cannot see, and flinch when hurt. Accuracy falls with
distance and with your movement speed, then is scaled by skill.

**Boss**: below half health Der Große Käse enters phase two, firing three-cheeseball volleys, moving 30 % faster and summoning sewer rats
(up to three at a time). The Der Rote Punkt laser stuns him only briefly (stun time x0.3, then 2 s of stun immunity).

## Weapons

You start with Claws and the Hairball Pistol, 100 health, 9 lives and 16 hairballs.

| Slot | Weapon | Kind | Damage | Magazine | Ammo | Notes |
|---|---|---|---|---|---|---|
| 1 | Claws | melee | 10 to 26 | n/a | none | 2 m reach, 35 degree cone, silent |
| 2 | Hairball Pistol | hitscan | 9 to 24 | 12 | hairballs | semi-auto, 1.3 s reload |
| 3 | Purr-forator | hitscan | 8 to 19 | 60 | hairballs | automatic, 12-step recoil pattern, 2.6 s reload |
| 4 | Yarn Bomber | projectile | 55 to 95 | n/a | yarn | bounces twice, 3.5 m splash, no self-damage |
| 5 | Der Rote Punkt | beam | 55 per second | n/a | cells | 64 m range, stuns enemies |

Headshots multiply damage by 2.5 for the hitscan guns.

## Items

| Item | Effect |
|---|---|
| Fish treat / Tuna / Catnip | heal 10 / 25 / 60 (catnip can overheal to 150) |
| Extra life | +1 life |
| Ammo clip / box | 8 / 25 hairballs |
| Yarn balls / Laser battery | 3 yarn / 40 cells |
| Purr-forator, Yarn Bomber, Der Rote Punkt | the weapon plus ammo |
| Gold key, silver key | open matching locked doors |
| Cheddar wedge / Brie wheel / Cheese crown | treasure: 100 / 500 / 1000 points |

## Skill levels

| Id | Name | Damage taken | Enemy HP | Enemy reaction time |
|---|---|---|---|---|
| 0 | Kitten ("Can I play, Daddy-cat?") | x0.45 | x0.8 | x1.4 |
| 1 | House Cat | x0.75 | x1.0 | x1.15 |
| 2 | Alley Cat (default) | x1.0 | x1.0 | x1.0 |
| 3 | Nine Lives Nightmare | x1.5 | x1.25 | x0.65 |

Balance caveat: the QA bot, which has no cover logic, clears only e1m1 at skill 2. See [RELEASE-NOTES.md](RELEASE-NOTES.md#known-issues).
