extends Node
## GameState autoload (owner rpg-core): the save-game. Party levels/xp/hp/mp/equipment, inventory, gold, flags,
## quests, unlocked recipes/summons, play time. Save/load JSON at user://save_<slot>.json.
## Party member record: {level, xp, hp, mp, equip {weapon, armor, charm}}. Stats are derived (member_stats()).
## Quest state: int stage index (0..stages-1) or "done". Missing = not started.

const DB = preload("res://data/db.gd")

const SAVE_VERSION: int = 1
const START_GOLD: int = 200
const START_ITEMS: Dictionary = {"milk_bottle": 4, "herb_salve": 1, "smelling_salts": 1, "rot_cure": 2,
	"wheat": 3, "butter": 2, "cheddar": 2, "milk": 2, "garlic": 1, "tomato": 2, "onion": 1, "cream": 1, "egg": 2}

var party: Dictionary = {}
var active: Array = []          ## char ids in battle order (max 4)
var inventory: Dictionary = {}  ## id -> count (items, dishes, ingredients, key items)
var gold: int = 0
var flags: Dictionary = {}
var quests: Dictionary = {}
var recipes: Array = []
var summons: Array = []
var play_time: float = 0.0
var area: String = "farmhouse"
var position: Vector3 = Vector3.ZERO
var fondue_gauge: int = 0
var slot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	new_game()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func new_game() -> void:
	party.clear()
	for cid: String in DB.PARTY_ORDER:
		var lv: int = 1
		var st: Dictionary = DB.char_stats(cid, lv)
		party[cid] = {"level": lv, "xp": 0, "hp": st.hp, "mp": st.mp, "equip": DB.CHARACTERS[cid].equip.duplicate()}
	for cid: String in party:
		var ms: Dictionary = member_stats(cid)
		party[cid].hp = ms.hp
		party[cid].mp = ms.mp
	active = DB.PARTY_ORDER.duplicate()
	inventory = START_ITEMS.duplicate()
	gold = START_GOLD
	flags = {}
	quests = {"main_last_wheel": 0}
	recipes = []
	for rid: String in DB.RECIPES:
		if DB.RECIPES[rid].learn == "start":
			recipes.append(rid)
	summons = []
	play_time = 0.0
	area = "farmhouse"
	position = Vector3.ZERO
	fondue_gauge = 0


# ------------------------------------------------------------------ party
## Derived stats incl. equipment: {hp, mp, atk, def, mag, res, spd, lck, element, resist[], immune[]}.
func member_stats(cid: String) -> Dictionary:
	var m: Dictionary = party.get(cid, {"level": 1, "equip": {}})
	var st: Dictionary = DB.char_stats(cid, int(m.level))
	var resist: Array = DB.CHARACTERS.get(cid, {}).get("resist", []).duplicate()
	var immune: Array = []
	var weapon_elem: String = "none"
	for slot_id: String in m.get("equip", {}):
		var it: Dictionary = DB.item(str(m.equip[slot_id]))
		for k: String in it.get("stats", {}):
			st[k] = int(st.get(k, 0)) + int(it.stats[k])
		for r: String in it.get("resist", []):
			if not r in resist:
				resist.append(r)
		immune.append_array(it.get("immune", []))
		if slot_id == "weapon" and it.has("element"):
			weapon_elem = it.element
	st["resist"] = resist
	st["immune"] = immune
	st["weapon_element"] = weapon_elem
	return st


func member_skills(cid: String) -> Array:
	return DB.char_skills(cid, int(party.get(cid, {}).get("level", 1)))


## Records for BattleEngine.setup(): [{id, level, hp, mp, equip}] for the active party.
func battle_party() -> Array:
	var out: Array = []
	for cid: String in active:
		var m: Dictionary = party[cid]
		out.append({"id": cid, "level": m.level, "hp": m.hp, "mp": m.mp, "equip": m.equip.duplicate()})
	return out


func heal_all() -> void:
	for cid: String in party:
		var st: Dictionary = member_stats(cid)
		party[cid].hp = st.hp
		party[cid].mp = st.mp
	Events.party_changed.emit()


func equip(cid: String, item_id: String) -> bool:
	var it: Dictionary = DB.item(item_id)
	if not party.has(cid) or not it.has("slot") or count(item_id) <= 0:
		return false
	if not it.get("who", []).is_empty() and not cid in it.who:
		return false
	var old: String = str(party[cid].equip.get(it.slot, ""))
	if old != "":
		add_item(old, 1, false)
	remove_item(item_id, 1)
	party[cid].equip[it.slot] = item_id
	Events.party_changed.emit()
	return true


## Adds xp to every party member (alive or not, JRPG-friendly). Emits level_up. Returns {cid: levels_gained}.
func gain_xp(amount: int) -> Dictionary:
	var ups: Dictionary = {}
	for cid: String in party:
		var m: Dictionary = party[cid]
		m.xp = int(m.xp) + amount
		var gained: int = 0
		while int(m.level) < DB.MAX_LEVEL and int(m.xp) >= DB.xp_for_level(int(m.level) + 1):
			var before: Dictionary = member_stats(cid)
			m.level = int(m.level) + 1
			gained += 1
			var after: Dictionary = member_stats(cid)
			m.hp = int(m.hp) + after.hp - before.hp
			m.mp = int(m.mp) + after.mp - before.mp
			Events.level_up.emit(cid, int(m.level))
		if gained > 0:
			ups[cid] = gained
	if not ups.is_empty():
		Events.party_changed.emit()
	return ups


## Applies a BattleEngine result: hp/mp, xp, gold, drops, gauge. Returns level-ups.
func apply_battle_result(result: Dictionary) -> Dictionary:
	for p: Dictionary in result.get("party", []):
		if party.has(p.id):
			party[p.id].hp = maxi(1 if result.get("won", false) else 0, int(p.hp))
			party[p.id].mp = int(p.mp)
	for id: String in result.get("used_items", {}):
		remove_item(id, int(result.used_items[id]))
	fondue_gauge = int(result.get("gauge", fondue_gauge))
	if not result.get("won", false):
		return {}
	add_gold(int(result.get("gold", 0)))
	for d: Variant in result.get("drops", []):
		add_item(str(d), 1)
	var enc: Dictionary = DB.ENCOUNTERS.get(str(result.get("encounter", "")), {})
	if enc.has("flag"):
		set_flag(enc.flag, true)
	return gain_xp(int(result.get("xp", 0)))


# ------------------------------------------------------------------ inventory
func count(id: String) -> int:
	return int(inventory.get(id, 0))


func has_item(id: String, n: int = 1) -> bool:
	return count(id) >= n


func add_item(id: String, n: int = 1, notify: bool = true) -> void:
	if n <= 0:
		return
	inventory[id] = count(id) + n
	if notify:
		Events.item_gained.emit(id, n)


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	return true


func add_gold(g: int) -> void:
	gold = maxi(0, gold + g)
	Events.gold_changed.emit(gold)


func spend_gold(g: int) -> bool:
	if gold < g:
		return false
	add_gold(-g)
	return true


## Ingredient ids held (for the cooking UI / battle Cook command).
func ingredients_held() -> Dictionary:
	var out: Dictionary = {}
	for id: String in inventory:
		if DB.INGREDIENTS.has(id):
			out[id] = inventory[id]
	return out


# ------------------------------------------------------------------ progress
func learn_recipe(id: String) -> void:
	if DB.RECIPES.has(id) and not id in recipes:
		recipes.append(id)
		Events.recipe_learned.emit(id)
		Events.toast.emit("New recipe: %s" % DB.RECIPES[id].name)


func knows_recipe(id: String) -> bool:
	return id in recipes


func unlock_summon(id: String) -> void:
	if DB.SUMMONS.has(id) and not id in summons:
		summons.append(id)
		Events.summon_unlocked.emit(id)
		Events.toast.emit("%s, the %s, will answer your call." % [DB.SUMMONS[id].name, DB.SUMMONS[id].title])


func set_flag(id: String, v: Variant = true) -> void:
	flags[id] = v


func flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


func quest_state(id: String) -> Variant:
	return quests.get(id, -1)


## stage: int stage index or "done". Completing pays the reward once.
func set_quest(id: String, stage: Variant) -> void:
	if not DB.QUESTS.has(id) or str(quests.get(id, "")) == "done":
		return
	quests[id] = stage
	Events.quest_updated.emit(id, stage)
	if str(stage) == "done":
		var rw: Dictionary = DB.QUESTS[id].reward
		add_gold(int(rw.get("gold", 0)))
		for it: String in rw.get("items", {}):
			add_item(it, int(rw.items[it]))
		if rw.has("recipe"):
			learn_recipe(rw.recipe)
		if rw.has("summon"):
			unlock_summon(rw.summon)
		if int(rw.get("xp", 0)) > 0:
			gain_xp(int(rw.xp))


func shop_stock(shop_id: String) -> Array:
	var sh: Dictionary = DB.SHOPS.get(shop_id, {})
	var out: Array = sh.get("stock", []).duplicate()
	for f: String in sh.get("unlock", {}):
		if flag(f):
			out.append_array(sh.unlock[f])
	return out


# ------------------------------------------------------------------ save / load
func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "party": party, "active": active, "inventory": inventory, "gold": gold,
		"flags": flags, "quests": quests, "recipes": recipes, "summons": summons, "play_time": play_time,
		"area": area, "position": [position.x, position.y, position.z], "fondue_gauge": fondue_gauge,
		"saved_at": Time.get_datetime_string_from_system(true)}


func from_dict(d: Dictionary) -> void:
	new_game()
	for cid: String in d.get("party", {}):
		if party.has(cid):
			var m: Dictionary = d.party[cid]
			party[cid] = {"level": int(m.get("level", 1)), "xp": int(m.get("xp", 0)), "hp": int(m.get("hp", 1)),
				"mp": int(m.get("mp", 0)), "equip": m.get("equip", party[cid].equip)}
	active = d.get("active", active)
	inventory = {}
	for k: String in d.get("inventory", {}):
		inventory[k] = int(d.inventory[k])
	gold = int(d.get("gold", gold))
	flags = d.get("flags", {})
	quests = {}
	for q: String in d.get("quests", {}):
		var v: Variant = d.quests[q]
		quests[q] = v if typeof(v) == TYPE_STRING else int(v)
	recipes = d.get("recipes", recipes)
	summons = d.get("summons", [])
	play_time = float(d.get("play_time", 0.0))
	area = str(d.get("area", area))
	var p: Array = d.get("position", [0, 0, 0])
	position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	fondue_gauge = int(d.get("fondue_gauge", 0))


func save_path(s: int) -> String:
	return "user://save_%d.json" % s


func save_game(s: int = slot) -> bool:
	var f: FileAccess = FileAccess.open(save_path(s), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	slot = s
	Events.game_saved.emit(s)
	return true


func load_game(s: int = slot) -> bool:
	if not FileAccess.file_exists(save_path(s)):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(s)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	from_dict(parsed)
	slot = s
	Events.game_loaded.emit(s)
	Events.party_changed.emit()
	return true


func has_save(s: int) -> bool:
	return FileAccess.file_exists(save_path(s))


## Small summary for save-slot menus: {exists, level, play_time, area, saved_at}.
func save_info(s: int) -> Dictionary:
	if not has_save(s):
		return {"exists": false}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(s)))
	if typeof(d) != TYPE_DICTIONARY:
		return {"exists": false}
	return {"exists": true, "level": int(d.get("party", {}).get("fennel", {}).get("level", 1)),
		"play_time": float(d.get("play_time", 0)), "area": str(d.get("area", "")), "saved_at": str(d.get("saved_at", ""))}
