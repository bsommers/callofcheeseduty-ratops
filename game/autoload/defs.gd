extends Node
## Defs — canonical game data, a port of reference/kasekrieg/defs.js (same numbers).
## Units from the reference are in grid CELLS; multiply distances/speeds by CELL_SIZE for metres.
## Read-only: treat every table as constant. Owner: godot-core.

const CELL_SIZE: float = 4.0          ## metres per reference grid cell (ARCHITECTURE section 4)
const WALL_HEIGHT: float = 3.6        ## default wall height in metres
const TITLE: String = "KÄSEKRIEG: RAT OPS"

## Physics layer bit values (layer N -> 1 << (N-1)).
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_PROJECTILE: int = 8
const LAYER_PICKUP: int = 16
const LAYER_TRIGGER: int = 32
const LAYER_DOOR: int = 64

## Character heights in metres (ARCHITECTURE section 4); capsule radius 0.4 m.
const CHARACTER_HEIGHT: Dictionary = {
	"player": 1.9, "mouse": 1.4, "trooper": 1.7, "officer": 1.8, "sewer": 1.5, "panzer": 2.2, "boss": 3.2,
}
const CAPSULE_RADIUS: float = 0.4

# ───────────────────────────── enemies ─────────────────────────────
## Distances (speed, radius, range) in cells. dmg = [min, max]; reaction/cooldown = [min, max] seconds.
const ENEMIES: Dictionary = {
	"mouse": {
		"title": "Maus Schütze", "hp": 25, "speed": 1.5, "radius": 0.28, "size": 0.9, "score": 100,
		"pain_chance": 0.85, "reaction": [0.5, 1.0],
		"attack": {"kind": "hitscan", "dmg": [3, 9], "shots": 1, "gap": 0.0, "windup": 0.4, "cooldown": [1.2, 2.0], "range": 14.0},
		"drop": "ammo_clip",
		"sfx": {"alert": "mouse_alert", "pain": "mouse_pain", "die": "mouse_die", "fire": "enemy_pistol"},
	},
	"trooper": {
		"title": "Sturmratte", "hp": 50, "speed": 1.9, "radius": 0.3, "size": 1.0, "score": 300,
		"pain_chance": 0.6, "reaction": [0.4, 0.8],
		"attack": {"kind": "hitscan", "dmg": [3, 8], "shots": 3, "gap": 0.11, "windup": 0.35, "cooldown": [1.4, 2.2], "range": 16.0},
		"drop": "gatling|ammo_clip",
		"sfx": {"alert": "trooper_alert", "pain": "rat_pain", "die": "trooper_die", "fire": "enemy_smg"},
	},
	"officer": {
		"title": "Ratten-Offizier", "hp": 40, "speed": 3.0, "radius": 0.28, "size": 1.0, "score": 400,
		"pain_chance": 0.5, "reaction": [0.2, 0.5],
		"attack": {"kind": "hitscan", "dmg": [4, 11], "shots": 1, "gap": 0.0, "windup": 0.28, "cooldown": [0.7, 1.3], "range": 16.0},
		"drop": "ammo_clip",
		"sfx": {"alert": "officer_alert", "pain": "rat_pain", "die": "officer_die", "fire": "enemy_pistol"},
	},
	"sewer": {
		"title": "Kanalratte", "hp": 14, "speed": 3.6, "radius": 0.26, "size": 0.7, "score": 150,
		"pain_chance": 0.9, "reaction": [0.1, 0.3],
		"attack": {"kind": "melee", "dmg": [3, 8], "shots": 1, "gap": 0.0, "windup": 0.18, "cooldown": [0.5, 0.8], "range": 0.95},
		"drop": "",
		"sfx": {"alert": "sewer_alert", "pain": "rat_pain", "die": "sewer_die", "fire": "sewer_bite"},
	},
	"panzer": {
		"title": "Panzerratte", "hp": 120, "speed": 1.2, "radius": 0.34, "size": 1.0, "score": 700,
		"pain_chance": 0.3, "reaction": [0.6, 1.0],
		"attack": {"kind": "projectile", "projectile": "cheeseball", "shots": 1, "gap": 0.0, "windup": 0.6, "cooldown": [2.0, 3.0], "range": 18.0},
		"drop": "yarn_ammo",
		"sfx": {"alert": "panzer_alert", "pain": "rat_pain", "die": "panzer_die", "fire": "panzer_fire"},
	},
	"boss": {
		"title": "Der Große Käse", "hp": 1100, "speed": 1.7, "radius": 0.5, "size": 1.6, "score": 10000,
		"pain_chance": 0.08, "reaction": [0.3, 0.5],
		"attack": {"kind": "hitscan", "dmg": [3, 7], "shots": 8, "gap": 0.08, "windup": 0.5, "cooldown": [1.4, 2.2], "range": 20.0},
		"phase2": {"below": 0.5, "projectile": "cheeseball", "volley": 3, "spread_deg": 14.0, "speed_mul": 1.3, "summon": "sewer"},
		"drop": "cheese_crown",
		"sfx": {"alert": "boss_alert", "pain": "boss_pain", "die": "boss_die", "fire": "boss_fire"},
	},
}

# ───────────────────────────── items (pickups) ─────────────────────────────
## ammo = [type, amount]; light = [r, g, b, radius_cells]; weapon = slot index into WEAPONS.
const ITEMS: Dictionary = {
	"fish_treat": {"heal": 10, "max": 100, "msg": "Fish treat", "sfx": "pickup_health"},
	"tuna": {"heal": 25, "max": 100, "msg": "Tuna!", "sfx": "pickup_health"},
	"catnip": {"heal": 60, "max": 150, "msg": "CATNIP!!", "sfx": "pickup_catnip", "light": [0.4, 1.6, 0.4, 2.5]},
	"extra_life": {"life": 1, "msg": "Extra life!", "sfx": "extra_life", "light": [1.6, 1.3, 0.4, 2.5]},
	"ammo_clip": {"ammo": ["hair", 8], "msg": "Hairballs", "sfx": "pickup_ammo"},
	"ammo_box": {"ammo": ["hair", 25], "msg": "Box of hairballs", "sfx": "pickup_ammo"},
	"yarn_ammo": {"ammo": ["yarn", 3], "msg": "Yarn balls", "sfx": "pickup_ammo"},
	"battery": {"ammo": ["cell", 40], "msg": "Laser battery", "sfx": "pickup_ammo"},
	"gatling": {"weapon": 2, "ammo": ["hair", 12], "msg": "The PURR-FORATOR!", "sfx": "pickup_weapon"},
	"yarn_launcher": {"weapon": 3, "ammo": ["yarn", 4], "msg": "The YARN BOMBER!", "sfx": "pickup_weapon"},
	"laser": {"weapon": 4, "ammo": ["cell", 60], "msg": "DER ROTE PUNKT!", "sfx": "pickup_weapon", "light": [1.4, 0.2, 0.2, 2.0]},
	"key_gold": {"key": "gold", "msg": "Gold key", "sfx": "pickup_key", "light": [1.2, 1.0, 0.3, 2.0]},
	"key_silver": {"key": "silver", "msg": "Silver key", "sfx": "pickup_key", "light": [0.8, 0.9, 1.2, 2.0]},
	"cheddar_wedge": {"score": 100, "treasure": true, "msg": "Cheddar", "sfx": "pickup_treasure"},
	"brie_wheel": {"score": 500, "treasure": true, "msg": "Brie wheel", "sfx": "pickup_treasure"},
	"cheese_crown": {"score": 1000, "treasure": true, "msg": "The Cheese Crown!", "sfx": "pickup_treasure", "light": [1.6, 1.3, 0.4, 2.5]},
}
const AMMO_MAX: Dictionary = {"hair": 99, "yarn": 20, "cell": 200}
const START: Dictionary = {
	"health": 100, "lives": 9, "ammo": {"hair": 16, "yarn": 0, "cell": 0},
	"owned": [true, true, false, false, false], "weapon": 1,
}

# ───────────────────────────── weapons ─────────────────────────────
## Slot order = index. range in cells, period = seconds between shots, spread in radians.
const WEAPONS: Array = [
	{"id": "claws", "name": "Claws", "kind": "melee", "dmg": [10, 26], "range": 1.15, "period": 0.34, "ammo": "", "use": 0, "auto": true, "loud": 0},
	{"id": "pistol", "name": "Hairball Pistol", "kind": "hitscan", "dmg": [9, 24], "spread": 0.012, "range": 24.0, "period": 0.36, "ammo": "hair", "use": 1, "auto": false, "loud": 12},
	{"id": "gatling", "name": "Purr-forator", "kind": "hitscan", "dmg": [8, 19], "spread": 0.045, "range": 24.0, "period": 0.095, "ammo": "hair", "use": 1, "auto": true, "loud": 14},
	{"id": "yarn", "name": "Yarn Bomber", "kind": "projectile", "projectile": "yarnball", "period": 0.9, "ammo": "yarn", "use": 1, "auto": false, "loud": 10},
	{"id": "laser", "name": "Der Rote Punkt", "kind": "beam", "dps": 55, "range": 16.0, "period": 0.0, "ammo": "cell", "use_per_sec": 14, "auto": true, "loud": 3, "stun": 0.6},
]

## speed in cells/s, radius/size/splash in cells, fuse in seconds, light = [r, g, b, radius_cells].
const PROJECTILES: Dictionary = {
	"yarnball": {"speed": 9.0, "radius": 0.15, "size": 0.3, "bounces": 2, "fuse": 2.2, "dmg": [55, 95], "splash": 1.7, "light": [1.6, 0.4, 1.4, 3.5], "boom": "explosion", "sfx": "explosion"},
	"cheeseball": {"speed": 5.5, "radius": 0.18, "size": 0.4, "bounces": 0, "fuse": 6.0, "dmg": [14, 28], "splash": 1.1, "light": [2.2, 1.3, 0.3, 3.5], "boom": "splash", "sfx": "cheese_splat"},
}

# ───────────────────────────── decor ─────────────────────────────
## block: fills its cell for movement. hang: hangs from the ceiling. light = [r,g,b,radius,height,flicker]. trap = one-shot damage.
const DECOR: Dictionary = {
	"barrel": {"block": true}, "cheese_stack": {"block": true}, "table_cheese": {"block": true},
	"chandelier": {"hang": true, "light": [2.2, 1.8, 1.2, 5.5, 0.8, 0.06]},
	"floor_lamp": {"block": true, "light": [2.0, 1.7, 1.0, 5.0, 0.75, 0.03]},
	"candelabra": {"block": true, "light": [2.2, 1.3, 0.5, 4.5, 0.7, 0.3]},
	"rat_armor": {"block": true}, "plant": {"block": true}, "pillar": {"block": true}, "flag_stand": {"block": true},
	"fish_bones": {}, "mousetrap": {"trap": 8}, "cheese_cart": {"block": true}, "cage_kitten": {"hang": true},
	"puddle_milk": {}, "crate": {"block": true},
	"cauldron": {"block": true, "light": [2.6, 1.5, 0.3, 5.0, 0.5, 0.15]},
	"scratch_post": {"block": true}, "bunk": {"block": true}, "radio_desk": {"block": true}, "hanging_cheese": {"hang": true},
	"glow_cheese": {"light": [0.5, 2.2, 0.4, 3.5, 0.2, 0.2]},
	"alarm_light": {"hang": true, "light": [2.8, 0.25, 0.2, 5.0, 0.85, 1.0]},
}

# ───────────────────────────── walls / doors / flats ─────────────────────────────
## Legend char -> wall material name. Lowercase legend char in a level = secret pushwall with that texture.
const WALLS: Dictionary = {
	"A": "wall.cheddar_brick", "B": "wall.swiss_block", "C": "wall.blue_stone", "D": "wall.parmesan_block",
	"E": "wall.wax_rind", "N": "wall.gold_foil", "S": "wall.fondue_fall", "Q": "wall.cheese_glass",
	"Y": "wall.moldy_brick", "W": "wall.crate_stack", "F": "wall.fort_stone", "G": "wall.fort_banner",
	"H": "wall.wood_panel", "I": "wall.wood_portrait", "J": "wall.steel_plate", "K": "wall.pipes",
	"L": "wall.bookshelf", "M": "wall.mouse_hole", "R": "wall.poster", "O": "wall.mirror",
	"U": "wall.cell_bars", "V": "wall.war_map", "T": "wall.trophy", "X": "wall.exit_switch",
}
## Legend char -> {tex, lock} ("" = unlocked).
const DOORS: Dictionary = {
	"+": {"tex": "door.wood", "lock": ""}, "=": {"tex": "door.steel", "lock": ""},
	"1": {"tex": "door.gold", "lock": "gold"}, "2": {"tex": "door.silver", "lock": "silver"},
}
## Flat name -> hazard damage per second.
const FLAT_HAZARD: Dictionary = {
	"flat.floor_dirt": 0, "flat.floor_stone": 0, "flat.floor_checker": 0, "flat.floor_cheese_tile": 0,
	"flat.floor_wood": 0, "flat.floor_carpet": 0, "flat.floor_grate": 0, "flat.floor_gold": 0,
	"flat.floor_blue": 0, "flat.floor_fondue": 22, "flat.ceil_stone": 0, "flat.ceil_wood": 0,
	"flat.ceil_cheese": 0, "flat.ceil_panel": 0, "flat.ceil_lamp_panel": 0,
}
const SKY_FLAT: String = "flat.sky"

# ───────────────────────────── level things legend ─────────────────────────────
## angle in radians in the reference's 2D frame (x right, y down). Uppercase enemy = patrols.
const THINGS: Dictionary = {
	"^": {"kind": "start", "angle": -PI / 2.0}, ">": {"kind": "start", "angle": 0.0},
	"v": {"kind": "start", "angle": PI / 2.0}, "<": {"kind": "start", "angle": PI},
	"m": {"kind": "enemy", "type": "mouse"}, "M": {"kind": "enemy", "type": "mouse", "patrol": true},
	"r": {"kind": "enemy", "type": "trooper"}, "R": {"kind": "enemy", "type": "trooper", "patrol": true},
	"o": {"kind": "enemy", "type": "officer"}, "O": {"kind": "enemy", "type": "officer", "patrol": true},
	"s": {"kind": "enemy", "type": "sewer"}, "S": {"kind": "enemy", "type": "sewer", "patrol": true},
	"p": {"kind": "enemy", "type": "panzer"}, "P": {"kind": "enemy", "type": "panzer", "patrol": true},
	"Z": {"kind": "enemy", "type": "boss"},
	"f": {"kind": "item", "id": "fish_treat"}, "u": {"kind": "item", "id": "tuna"}, "n": {"kind": "item", "id": "catnip"},
	"9": {"kind": "item", "id": "extra_life"}, "a": {"kind": "item", "id": "ammo_clip"}, "b": {"kind": "item", "id": "ammo_box"},
	"y": {"kind": "item", "id": "yarn_ammo"}, "e": {"kind": "item", "id": "battery"}, "3": {"kind": "item", "id": "gatling"},
	"4": {"kind": "item", "id": "yarn_launcher"}, "5": {"kind": "item", "id": "laser"}, "G": {"kind": "item", "id": "key_gold"},
	"K": {"kind": "item", "id": "key_silver"}, "$": {"kind": "item", "id": "cheddar_wedge"}, "&": {"kind": "item", "id": "brie_wheel"},
	"*": {"kind": "item", "id": "cheese_crown"},
	"B": {"kind": "decor", "id": "barrel"}, "C": {"kind": "decor", "id": "cheese_stack"}, "T": {"kind": "decor", "id": "table_cheese"},
	"H": {"kind": "decor", "id": "chandelier"}, "L": {"kind": "decor", "id": "floor_lamp"}, "c": {"kind": "decor", "id": "candelabra"},
	"A": {"kind": "decor", "id": "rat_armor"}, "t": {"kind": "decor", "id": "plant"}, "I": {"kind": "decor", "id": "pillar"},
	"F": {"kind": "decor", "id": "flag_stand"}, "x": {"kind": "decor", "id": "fish_bones"}, "w": {"kind": "decor", "id": "mousetrap"},
	"k": {"kind": "decor", "id": "cheese_cart"}, "j": {"kind": "decor", "id": "cage_kitten"}, "d": {"kind": "decor", "id": "puddle_milk"},
	"W": {"kind": "decor", "id": "crate"}, "Q": {"kind": "decor", "id": "cauldron"}, "i": {"kind": "decor", "id": "scratch_post"},
	"l": {"kind": "decor", "id": "bunk"}, "D": {"kind": "decor", "id": "radio_desk"}, "h": {"kind": "decor", "id": "hanging_cheese"},
	"g": {"kind": "decor", "id": "glow_cheese"}, "q": {"kind": "decor", "id": "alarm_light"},
	"!": {"kind": "light", "light": [1.8, 1.5, 1.1, 5.0, 0.8, 0.0]},
}

# ───────────────────────────── audio ─────────────────────────────
const SFX: PackedStringArray = [
	"claw_swipe", "claw_hit", "pistol", "gatling", "yarn_launch", "yarn_bounce", "laser", "no_ammo", "weapon_switch",
	"explosion", "cheese_splat", "ricochet", "hit_wall",
	"door_open", "door_close", "door_locked", "pushwall", "switch",
	"pickup_health", "pickup_catnip", "pickup_ammo", "pickup_weapon", "pickup_treasure", "pickup_key", "extra_life", "secret_found",
	"player_hurt", "player_die", "meow", "purr", "fondue_sizzle", "trap_snap",
	"mouse_alert", "mouse_pain", "mouse_die", "trooper_alert", "trooper_die", "officer_alert", "officer_die",
	"sewer_alert", "sewer_bite", "sewer_die", "panzer_alert", "panzer_fire", "panzer_die", "rat_pain",
	"boss_alert", "boss_fire", "boss_pain", "boss_die", "enemy_pistol", "enemy_smg",
	"menu_move", "menu_select", "menu_back", "level_complete", "tally_tick", "game_over",
]
const MUSIC: PackedStringArray = ["title", "level_a", "level_b", "level_c", "boss", "intermission", "victory", "gameover"]

# ───────────────────────────── skills / levels ─────────────────────────────
const SKILLS: Array = [
	{"id": 0, "name": "Kitten", "blurb": "Can I play, Daddy-cat?", "dmg_taken": 0.45, "enemy_hp": 0.8, "reaction": 1.4},
	{"id": 1, "name": "House Cat", "blurb": "Don't hurt my whiskers.", "dmg_taken": 0.75, "enemy_hp": 1.0, "reaction": 1.15},
	{"id": 2, "name": "Alley Cat", "blurb": "Bring on the rats!", "dmg_taken": 1.0, "enemy_hp": 1.0, "reaction": 1.0},
	{"id": 3, "name": "Nine Lives Nightmare", "blurb": "I am fur incarnate.", "dmg_taken": 1.5, "enemy_hp": 1.25, "reaction": 0.65},
]
const DEFAULT_SKILL: int = 2

## [id, name, par seconds]. Par times come from reference/kasekrieg/levels/e1mN.js.
const LEVELS: Array = [
	["e1m1", "The Cheese Cellar", 240], ["e1m2", "Rat Barracks", 300], ["e1m3", "The Fondue Works", 420],
	["e1m4", "Moonlit Hall of Mirrors", 300], ["e1m5", "The Blue Vault", 360], ["e1m6", "Throne of the Big Cheese", 360],
]

# ───────────────────────────── scoring ─────────────────────────────
## Per-kill and per-treasure scores are ENEMIES[*].score / ITEMS[*].score (reference numbers).
## Intermission bonuses are NOT in the reference defs; these are new (Wolfenstein-style), see godot-core report.
const SCORING: Dictionary = {
	"kill_ratio_100": 10000,    ## all enemies killed
	"secret_ratio_100": 10000,  ## all secrets found
	"treasure_ratio_100": 10000,## all treasure taken
	"par_bonus_per_sec": 500,   ## per second under par
	"extra_life_every": 0,      ## 0 = no score-based extra lives (reference has none)
}

# ───────────────────────────── helpers ─────────────────────────────
func weapon_index(id: String) -> int:
	for i: int in WEAPONS.size():
		if WEAPONS[i]["id"] == id:
			return i
	return -1

func weapon(id_or_index: Variant) -> Dictionary:
	var i: int = id_or_index if id_or_index is int else weapon_index(str(id_or_index))
	return WEAPONS[i] if i >= 0 and i < WEAPONS.size() else {}

func enemy(kind: String) -> Dictionary:
	return ENEMIES.get(kind, {})

func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

func level_index(id: String) -> int:
	for i: int in LEVELS.size():
		if LEVELS[i][0] == id:
			return i
	return -1

func level_name(id: String) -> String:
	var i: int = level_index(id)
	return LEVELS[i][1] if i >= 0 else id

func level_par(id: String) -> int:
	var i: int = level_index(id)
	return LEVELS[i][2] if i >= 0 else 0

## Cells -> metres.
func cells(v: float) -> float:
	return v * CELL_SIZE

## Intermission bonus for a stats dict {kills, kills_total, secrets, secrets_total, treasure, treasure_total, time, par}.
func intermission_bonus(stats: Dictionary) -> int:
	var b: int = 0
	if int(stats.get("kills_total", 0)) > 0 and int(stats.get("kills", 0)) >= int(stats.get("kills_total", 0)):
		b += SCORING["kill_ratio_100"]
	if int(stats.get("secrets_total", 0)) > 0 and int(stats.get("secrets", 0)) >= int(stats.get("secrets_total", 0)):
		b += SCORING["secret_ratio_100"]
	if int(stats.get("treasure_total", 0)) > 0 and int(stats.get("treasure", 0)) >= int(stats.get("treasure_total", 0)):
		b += SCORING["treasure_ratio_100"]
	var par: float = float(stats.get("par", 0))
	var t: float = float(stats.get("time", 0.0))
	if par > 0.0 and t < par:
		b += int(floor(par - t)) * int(SCORING["par_bonus_per_sec"])
	return b
