class_name DB
extends RefCounted
## Static game rules + table access (owner rpg-core). Works without autoloads (headless tests, BattleEngine).
## The `Data` autoload re-exports every table here; gameplay code may use either `Data.X` or `DB.X`.
##
## FORMULAS (documented here, used by Data and BattleEngine):
##   Character stat at level L:  round(base + per*(L-1) + curve*(L-1)^2)            (characters.gd growth)
##   Enemy stat at level L:      ENEMY_CURVE[stat] = [a, b, c] -> (a + b*L + c*L^2) * mult[stat]
##   XP to next level:           20*L + 6*L^2     (L = current level)
##   Element multiplier:         DB.element_mult(attack_elem, defender) -> 1.5 weak, 0.5 resist (ARCHITECTURE wheel
##                               FIRE>ICE>WIND>EARTH>FIRE plus defender weak/resist lists; ROT weak to FIRE/LIGHT; LIGHT<->SHADE)
##   Cooking quality:            stir (0..3 from timing) + pairing (+1 perfect cheese, +1 "balanced" = all slot flavours
##                               distinct, max +1 total) + cook perks, clamped to 0..3 (burnt, plain, tasty, gourmet)

const ElementsList: Array = ["none", "fire", "ice", "wind", "earth", "rot", "light", "shade"]

const ELEMENTS: Dictionary = {
	"none": {"name": "Plain", "pun": "", "color": Color(0.9, 0.9, 0.85)},
	"fire": {"name": "Fire", "pun": "Melt", "color": Color(1.0, 0.45, 0.15)},
	"ice": {"name": "Ice", "pun": "Cave Chill", "color": Color(0.55, 0.8, 1.0)},
	"wind": {"name": "Wind", "pun": "Whey Gust", "color": Color(0.75, 1.0, 0.7)},
	"earth": {"name": "Earth", "pun": "Rind", "color": Color(0.75, 0.55, 0.3)},
	"rot": {"name": "Rot", "pun": "Blue Rot", "color": Color(0.3, 0.7, 0.6)},
	"light": {"name": "Light", "pun": "Halo", "color": Color(1.0, 0.95, 0.65)},
	"shade": {"name": "Shade", "pun": "Spooky", "color": Color(0.45, 0.3, 0.6)},
}

## attack element -> elements it is strong against (x1.5); the reverse direction is x0.5.
const ELEMENT_BEATS: Dictionary = {"fire": ["ice", "rot"], "ice": ["wind"], "wind": ["earth"], "earth": ["fire"],
	"light": ["shade", "rot"], "shade": ["light"]}

## Statuses. dot/regen = fraction of max HP per turn end. stat mults apply while active.
const STATUSES: Dictionary = {
	"melted": {"name": "Melted", "bad": true, "dot": 0.06, "mult": {"def": 0.85}, "desc": "Burning and gooey: loses HP each turn, defence down."},
	"frozen": {"name": "Frozen", "bad": true, "skip": true, "desc": "Frozen solid in a wheel of ice: loses turns."},
	"chilled": {"name": "Chilled", "bad": true, "mult": {"spd": 0.6}, "desc": "Cave-cold: acts slower."},
	"aerated": {"name": "Aerated", "bad": false, "evade": 0.3, "desc": "Full of holes like a Swiss: evasion up."},
	"rinded": {"name": "Rinded", "bad": false, "mult": {"def": 1.4, "res": 1.4}, "desc": "Hard rind: defence and resistance up."},
	"moldy": {"name": "Moldy", "bad": true, "dot": 0.05, "spread": 0.25, "desc": "The Rot: loses HP and may spread to allies."},
	"sated": {"name": "Sated", "bad": false, "regen": 0.06, "desc": "Well fed: regains HP each turn."},
	"spicy": {"name": "Spicy", "bad": false, "mult": {"atk": 1.3, "mag": 1.3}, "desc": "Fired up: attack and magic up."},
	"stinky": {"name": "Stinky", "bad": true, "accuracy": 0.7, "desc": "Eyes watering: accuracy down."},
	"taunting": {"name": "Taunting", "bad": false, "taunt": true, "desc": "Smells so strong every enemy must attack this one."},
}

## Flavor Chain: consecutive party element casts (key "prev>next"). Named combos add bonus damage and gauge.
const CHAINS: Dictionary = {
	"fire>wind": {"name": "Smoked", "mult": 1.3, "gauge": 10},
	"ice>earth": {"name": "Aged", "mult": 1.3, "gauge": 10},
	"earth>fire": {"name": "Grilled", "mult": 1.25, "gauge": 8},
	"wind>ice": {"name": "Whipped", "mult": 1.25, "gauge": 8},
	"fire>earth": {"name": "Baked", "mult": 1.2, "gauge": 8},
	"ice>fire": {"name": "Flash-Thawed", "mult": 1.2, "gauge": 8},
	"wind>earth": {"name": "Holey", "mult": 1.2, "gauge": 8},
	"earth>ice": {"name": "Cave-Aged", "mult": 1.2, "gauge": 8},
	"light>fire": {"name": "Golden", "mult": 1.2, "gauge": 8},
	"fire>ice": {"name": "Fondue Shock", "mult": 1.2, "gauge": 8},
}
const CHAIN_STEP_MULT: float = 0.1     ## +10% per extra link (different element than the previous cast)
const CHAIN_MAX: int = 5
const GAUGE_PER_CAST: int = 8
const GAUGE_PER_HIT: int = 3
const GAUGE_WEAKNESS: int = 4
const GAUGE_MAX: int = 100

const QUALITY: Array = [
	{"id": "burnt", "name": "Burnt", "mult": 0.5, "gauge": 0, "color": Color(0.35, 0.25, 0.2)},
	{"id": "plain", "name": "Plain", "mult": 1.0, "gauge": 0, "color": Color(0.85, 0.85, 0.8)},
	{"id": "tasty", "name": "Tasty", "mult": 1.35, "gauge": 5, "color": Color(0.55, 0.85, 0.4)},
	{"id": "gourmet", "name": "Gourmet", "mult": 1.75, "gauge": 20, "color": Color(1.0, 0.8, 0.25)},
]

const ENEMY_CURVE: Dictionary = {
	"hp": [40.0, 46.0, 1.6], "mp": [10.0, 3.0, 0.0], "atk": [16.0, 8.1, 0.0], "def": [6.0, 2.2, 0.0],
	"mag": [16.0, 7.5, 0.0], "res": [6.0, 2.2, 0.0], "spd": [8.0, 0.9, 0.0], "lck": [5.0, 0.5, 0.0],
	"xp": [8.0, 6.0, 0.4], "gold": [6.0, 4.0, 0.05],
}

const STAT_KEYS: Array = ["hp", "mp", "atk", "def", "mag", "res", "spd", "lck"]

const _Chars: GDScript = preload("res://data/characters.gd")
const _Skills: GDScript = preload("res://data/skills.gd")
const _Enemies: GDScript = preload("res://data/enemies.gd")
const _Items: GDScript = preload("res://data/items.gd")
const _Recipes: GDScript = preload("res://data/recipes.gd")
const _World: GDScript = preload("res://data/world.gd")

const CHARACTERS: Dictionary = _Chars.CHARACTERS
const PARTY_ORDER: Array = _Chars.PARTY_ORDER
const MAX_LEVEL: int = _Chars.MAX_LEVEL
const SKILLS: Dictionary = _Skills.SKILLS
const ENEMIES: Dictionary = _Enemies.ENEMIES
const BASE_ITEMS: Dictionary = _Items.ITEMS
const INGREDIENTS: Dictionary = _Items.INGREDIENTS
const RECIPES: Dictionary = _Recipes.RECIPES
const MYSTERY_MUSH: Dictionary = _Recipes.MYSTERY_MUSH
const SUMMONS: Dictionary = _World.SUMMONS
const ENCOUNTERS: Dictionary = _World.ENCOUNTERS
const SHOPS: Dictionary = _World.SHOPS
const QUESTS: Dictionary = _World.QUESTS
const AREAS: Dictionary = _World.AREAS

## The basic Attack command expressed as a skill.
const ATTACK_SKILL: Dictionary = {"name": "Attack", "element": "none", "kind": "physical", "power": 100, "mp": 0,
	"target": "enemy", "anim": "attack", "vfx": "slash", "desc": "A plain hit."}

static var _items_cache: Dictionary = {}


## ITEMS + dishes (every recipe as kind "dish", plus mystery_mush). Ingredients are NOT included (see item()).
static func items() -> Dictionary:
	if _items_cache.is_empty():
		var d: Dictionary = BASE_ITEMS.duplicate(true)
		for rid: String in RECIPES:
			var r: Dictionary = RECIPES[rid]
			var it: Dictionary = r.effect.duplicate(true)
			it.merge({"name": r.name, "kind": "dish", "price": r.price, "desc": r.desc, "recipe": rid,
				"element": r.get("element", r.effect.get("element", "none"))}, true)
			if it.has("damage"):
				it["throwable"] = true
			d[rid] = it
		var mm: Dictionary = MYSTERY_MUSH.effect.duplicate(true)
		mm.merge({"name": MYSTERY_MUSH.name, "kind": "dish", "price": MYSTERY_MUSH.price, "desc": MYSTERY_MUSH.desc}, true)
		d["mystery_mush"] = mm
		_items_cache = d
	return _items_cache


## Any inventory id: item, dish or ingredient (ingredients get kind "ingredient"). {} if unknown.
static func item(id: String) -> Dictionary:
	var all: Dictionary = items()
	if all.has(id):
		return all[id]
	if INGREDIENTS.has(id):
		var ing: Dictionary = INGREDIENTS[id].duplicate()
		ing["kind"] = "ingredient"
		return ing
	return {}


static func item_name(id: String) -> String:
	return str(item(id).get("name", id.capitalize()))


static func skill(id: String) -> Dictionary:
	if id == "attack":
		return ATTACK_SKILL
	return SKILLS.get(id, {})


static func is_cheese(id: String) -> bool:
	return INGREDIENTS.has(id) and "cheese" in INGREDIENTS[id].tags


# ------------------------------------------------------------------ stats
static func char_stats(char_id: String, level: int) -> Dictionary:
	var c: Dictionary = CHARACTERS.get(char_id, {})
	var out: Dictionary = {}
	var l: float = float(clampi(level, 1, MAX_LEVEL) - 1)
	for k: String in STAT_KEYS:
		var g: Array = c.get("growth", {}).get(k, [10, 1.0, 0.0])
		out[k] = int(round(float(g[0]) + float(g[1]) * l + float(g[2]) * l * l))
	return out


## Skills known at `level` (in learn order).
static func char_skills(char_id: String, level: int) -> Array:
	var out: Array = []
	var learn: Dictionary = CHARACTERS.get(char_id, {}).get("learn", {})
	var lvls: Array = learn.keys()
	lvls.sort()
	for lv: int in lvls:
		if lv <= level:
			for s: String in learn[lv]:
				if not s in out:
					out.append(s)
	return out


static func xp_to_next(level: int) -> int:
	return 20 * level + 6 * level * level


## Total xp needed to REACH `level` from level 1.
static func xp_for_level(level: int) -> int:
	var t: int = 0
	for l: int in range(1, level):
		t += xp_to_next(l)
	return t


static func enemy_stats(enemy_id: String, level: int = -1) -> Dictionary:
	var e: Dictionary = ENEMIES.get(enemy_id, {})
	var lv: int = level if level > 0 else int(e.get("level", 1))
	var mult: Dictionary = e.get("mult", {})
	var out: Dictionary = {"level": lv}
	for k: String in ENEMY_CURVE:
		var c: Array = ENEMY_CURVE[k]
		var v: float = (c[0] + c[1] * lv + c[2] * lv * lv) * float(mult.get(k, 1.0))
		out[k] = maxi(1, int(round(v)))
	return out


## Element damage multiplier of `elem` against a defender with `weak`/`resist` lists and own `def_elem`.
static func element_mult(elem: String, def_elem: String, weak: Array = [], resist: Array = [], immune: Array = []) -> float:
	if elem == "none" or elem == "":
		return 1.0
	if elem in immune:
		return 0.0
	var m: float = 1.0
	if elem in weak:
		m = 1.5
	elif elem in resist:
		m = 0.5
	elif def_elem in ELEMENT_BEATS.get(elem, []):
		m = 1.5
	elif elem in ELEMENT_BEATS.get(def_elem, []) and def_elem != elem:
		m = 0.5
	return m


# ------------------------------------------------------------------ cooking
static func _slot_ok(slot: String, ing: String) -> bool:
	if slot == ing:
		return true
	if slot == "cheese":
		return is_cheese(ing)
	if slot.begins_with("tag:"):
		return INGREDIENTS.has(ing) and slot.substr(4) in INGREDIENTS[ing].tags
	return false


static func _slot_rank(slot: String) -> int:
	if slot == "cheese":
		return 2
	if slot.begins_with("tag:"):
		return 1
	return 0


## Does this ingredient list (order-free) fill exactly the recipe's slots?
static func recipe_fits(recipe_id: String, ingredients: Array) -> bool:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	if r.is_empty() or ingredients.size() != r.slots.size():
		return false
	var slots: Array = r.slots.duplicate()
	slots.sort_custom(func(a: String, b: String) -> bool: return _slot_rank(a) < _slot_rank(b))
	var pool: Array = ingredients.duplicate()
	for s: String in slots:
		var found: int = -1
		for i: int in pool.size():
			if _slot_ok(s, pool[i]):
				found = i
				break
		if found < 0:
			return false
		pool.remove_at(found)
	return true


## Recipe id matching the ingredients, or "mystery_mush". Most specific recipe (fewest wildcard slots) wins.
static func match_recipe(ingredients: Array) -> String:
	var best: String = "mystery_mush"
	var best_score: int = 1 << 20
	var ids: Array = RECIPES.keys()
	ids.sort()
	for rid: String in ids:
		if recipe_fits(rid, ingredients):
			var score: int = 0
			for s: String in RECIPES[rid].slots:
				score += _slot_rank(s)
			if score < best_score:
				best_score = score
				best = rid
	return best


## Pairing bonus 0..1 for the dish (see header). Exposed so the cooking UI can hint "perfect pairing!".
static func pairing_bonus(recipe_id: String, ingredients: Array) -> int:
	var r: Dictionary = RECIPES.get(recipe_id, {})
	if r.is_empty():
		return 0
	if r.pair != "" and r.pair in ingredients:
		return 1
	var flavors: Dictionary = {}
	for ing: String in ingredients:
		flavors[INGREDIENTS.get(ing, {}).get("flavor", ing)] = true
	return 1 if flavors.size() == ingredients.size() and ingredients.size() >= 3 else 0


## stir: 0..1 timing accuracy from the stir mini-game (1 = perfect). Returns tier index 0..3.
static func cook_quality(recipe_id: String, ingredients: Array, stir: float, cook_char: String = "", boost: bool = false) -> int:
	if recipe_id == "mystery_mush":
		return 0
	var q: int = 0
	if stir >= 0.9:
		q = 3
	elif stir >= 0.65:
		q = 2
	elif stir >= 0.3:
		q = 1
	q += pairing_bonus(recipe_id, ingredients)
	if boost:
		q += 1
	var r: Dictionary = RECIPES[recipe_id]
	match cook_char:
		"clover":
			q = maxi(q, 1)  # never Burnt
		"brie":
			if "egg" in r.slots:
				q = maxi(q, 2)
		"fennel":
			if r.get("element", "") == "fire" and q >= 2:
				q += 1
	return clampi(q, 0, 3)


## Effect dictionary of a dish at a quality tier: numeric heal/damage/mp scaled; revive/pct capped at 1.0.
static func dish_effect(dish_id: String, quality: int) -> Dictionary:
	var base: Dictionary = item(dish_id)
	var m: float = QUALITY[clampi(quality, 0, 3)].mult
	var e: Dictionary = base.duplicate(true)
	for k: String in ["heal", "mp", "damage"]:
		if e.has(k):
			e[k] = int(round(float(e[k]) * m))
	for k: String in ["heal_pct", "mp_pct", "revive"]:
		if e.has(k):
			e[k] = minf(1.0, float(e[k]) * m)
	e["gauge"] = int(e.get("gauge", 0)) + int(QUALITY[clampi(quality, 0, 3)].gauge)
	e["quality"] = quality
	return e


# ------------------------------------------------------------------ checks
## Returns a list of human-readable problems with cross references (used by tests).
static func validate() -> Array:
	var errs: Array = []
	var all: Dictionary = items()
	for cid: String in CHARACTERS:
		var c: Dictionary = CHARACTERS[cid]
		for lv: int in c.learn:
			for s: String in c.learn[lv]:
				if not SKILLS.has(s):
					errs.append("char %s learns unknown skill %s" % [cid, s])
		for slot: String in c.equip:
			var e: String = c.equip[slot]
			if e != "" and not all.has(e):
				errs.append("char %s equips unknown %s" % [cid, e])
	for eid: String in ENEMIES:
		var e: Dictionary = ENEMIES[eid]
		var pools: Array = [e.skills]
		for p: Dictionary in e.get("phases", []):
			pools.append(p.skills)
		for pool: Array in pools:
			for pair: Array in pool:
				if pair[0] != "attack" and not SKILLS.has(pair[0]):
					errs.append("enemy %s uses unknown skill %s" % [eid, pair[0]])
		for d: Array in e.get("drops", []):
			if item(d[0]).is_empty():
				errs.append("enemy %s drops unknown %s" % [eid, d[0]])
	for sid: String in SKILLS:
		var s: Dictionary = SKILLS[sid]
		for k: String in ["status", "self_status"]:
			if s.has(k) and not STATUSES.has(s[k].id):
				errs.append("skill %s unknown status %s" % [sid, s[k].id])
		if s.has("summon_ally") and not ENEMIES.has(s.summon_ally):
			errs.append("skill %s summons unknown %s" % [sid, s.summon_ally])
		if not ELEMENTS.has(s.element):
			errs.append("skill %s unknown element %s" % [sid, s.element])
	for rid: String in RECIPES:
		var r: Dictionary = RECIPES[rid]
		for sl: String in r.slots:
			if sl != "cheese" and not sl.begins_with("tag:") and not INGREDIENTS.has(sl):
				errs.append("recipe %s unknown ingredient %s" % [rid, sl])
		if r.pair != "" and not INGREDIENTS.has(r.pair):
			errs.append("recipe %s unknown pair %s" % [rid, r.pair])
		# the canonical combination must map back to this recipe
		var sample: Array = []
		for sl: String in r.slots:
			sample.append(r.pair if sl == "cheese" and r.pair != "" else ("cheddar" if sl == "cheese" else sl))
		var got: String = match_recipe(sample)
		if got != rid:
			errs.append("recipe %s canonical ingredients match %s instead" % [rid, got])
	for enc: String in ENCOUNTERS:
		for en: String in ENCOUNTERS[enc].enemies:
			if not ENEMIES.has(en):
				errs.append("encounter %s unknown enemy %s" % [enc, en])
		if ENCOUNTERS[enc].enemies.size() > 5:
			errs.append("encounter %s has >5 enemies" % enc)
	for sh: String in SHOPS:
		var ids: Array = SHOPS[sh].stock.duplicate()
		for f: String in SHOPS[sh].get("unlock", {}):
			ids.append_array(SHOPS[sh].unlock[f])
		for i: String in ids:
			if item(i).is_empty():
				errs.append("shop %s sells unknown %s" % [sh, i])
	for q: String in QUESTS:
		var rw: Dictionary = QUESTS[q].reward
		for i: String in rw.get("items", {}):
			if item(i).is_empty():
				errs.append("quest %s rewards unknown %s" % [q, i])
		if rw.has("recipe") and not RECIPES.has(rw.recipe):
			errs.append("quest %s unknown recipe %s" % [q, rw.recipe])
		if rw.has("summon") and not SUMMONS.has(rw.summon):
			errs.append("quest %s unknown summon %s" % [q, rw.summon])
	for a: String in AREAS:
		for enc: String in AREAS[a].encounters:
			if not ENCOUNTERS.has(enc):
				errs.append("area %s unknown encounter %s" % [a, enc])
	return errs
