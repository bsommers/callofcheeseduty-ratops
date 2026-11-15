extends RefCounted
## Data integrity: cross references, counts, growth curves, recipe matching.

const Rules = preload("res://data/db.gd")
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_cross_references() -> void:
	for e: String in Rules.validate():
		failures.append(e)


func test_counts() -> void:
	check(Rules.CHARACTERS.size() == 4, "4 party members")
	check(Rules.SKILLS.size() >= 60, "60+ skills (%d)" % Rules.SKILLS.size())
	var normal: int = Rules.ENEMIES.values().filter(func(e: Dictionary) -> bool: return not e.get("boss", false)).size()
	check(normal >= 25, "25+ enemies (%d)" % normal)
	check(Rules.ENEMIES.size() - normal == 3, "3 bosses")
	check(Rules.BASE_ITEMS.size() >= 40, "40+ items (%d)" % Rules.BASE_ITEMS.size())
	check(Rules.INGREDIENTS.size() >= 35, "35+ ingredients (%d)" % Rules.INGREDIENTS.size())
	check(Rules.RECIPES.size() >= 40, "40 recipes (%d)" % Rules.RECIPES.size())
	check(Rules.SUMMONS.size() == 4, "4 summons")
	for id: String in ["meadow_grunts", "boss_rat_king"]:
		check(Rules.ENCOUNTERS.has(id), "encounter " + id)


func test_ids_are_snake_case() -> void:
	var re: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for t: Dictionary in [Rules.SKILLS, Rules.ENEMIES, Rules.items(), Rules.INGREDIENTS, Rules.RECIPES, Rules.SUMMONS,
			Rules.ENCOUNTERS, Rules.SHOPS, Rules.QUESTS, Rules.AREAS, Rules.CHARACTERS]:
		for k: String in t:
			check(re.search(k) != null, "bad id " + k)


func test_growth_monotonic() -> void:
	for cid: String in Rules.CHARACTERS:
		var prev: Dictionary = Rules.char_stats(cid, 1)
		for lv: int in range(2, Rules.MAX_LEVEL + 1):
			var st: Dictionary = Rules.char_stats(cid, lv)
			for k: String in Rules.STAT_KEYS:
				check(int(st[k]) >= int(prev[k]), "%s %s drops at L%d" % [cid, k, lv])
			prev = st
		check(Rules.char_skills(cid, 30).size() >= 7, "%s learns 7+ skills" % cid)
	check(Rules.xp_for_level(30) > Rules.xp_for_level(29), "xp curve grows")


func test_recipe_matching() -> void:
	check(Rules.match_recipe(["butter", "cheddar", "wheat"]) == "grilled_cheese", "grilled cheese any order")
	check(Rules.match_recipe(["wheat", "butter", "gouda"]) == "grilled_cheese", "any cheese slot")
	check(Rules.match_recipe(["wheat", "butter", "swiss"]) == "croque_monsieur", "specific beats wildcard")
	check(Rules.match_recipe(["truffle", "trout"]) == "mystery_mush", "nonsense -> mush")
	check(Rules.match_recipe(["wheat", "butter", "cheddar", "egg"]) == "mystery_mush", "extra ingredient fails")
	check(Rules.cook_quality("grilled_cheese", ["wheat", "butter", "cheddar"], 1.0) == 3, "perfect gourmet")
	check(Rules.cook_quality("grilled_cheese", ["wheat", "butter", "gouda"], 0.0) == 0, "burnt")
	check(Rules.cook_quality("grilled_cheese", ["wheat", "butter", "cheddar"], 0.0) == 1, "pairing lifts burnt")
	check(Rules.cook_quality("grilled_cheese", ["wheat", "butter", "gouda"], 0.0, "clover") >= 1, "clover never burns")
	var e0: Dictionary = Rules.dish_effect("grilled_cheese", 0)
	var e3: Dictionary = Rules.dish_effect("grilled_cheese", 3)
	check(int(e3.heal) > int(e0.heal), "quality scales heal")
	check(int(e3.gauge) > 0, "gourmet gives gauge")


func test_element_wheel() -> void:
	check(Rules.element_mult("fire", "ice") == 1.5, "fire > ice")
	check(Rules.element_mult("ice", "fire") == 0.5, "ice < fire")
	check(Rules.element_mult("earth", "fire") == 1.5, "earth > fire")
	check(Rules.element_mult("fire", "rot") == 1.5, "rot weak to fire")
	check(Rules.element_mult("light", "shade") == 1.5 and Rules.element_mult("shade", "light") == 1.5, "light/shade mutual")
	check(Rules.element_mult("fire", "none", ["fire"]) == 1.5, "weak list")
	check(Rules.element_mult("fire", "ice", [], ["fire"]) == 0.5, "resist list wins")


func test_models_named() -> void:
	for cid: String in Rules.CHARACTERS:
		check(str(Rules.CHARACTERS[cid].model) == "hero_" + cid, "model id hero_" + cid)
	for sid: String in Rules.SUMMONS:
		check(str(Rules.SUMMONS[sid].model) == "summon_" + sid, "model id summon_" + sid)
	for eid: String in Rules.ENEMIES:
		var m: String = str(Rules.ENEMIES[eid].model)
		check(m.begins_with("enemy_") or m.begins_with("boss_") or m.begins_with("npc_"), "enemy model " + m)


func test_world_encounter_ids_valid() -> void:
	var re: RegEx = RegEx.create_from_string("\"([a-z][a-z0-9_]+)\"")
	var dirs: Array = ["res://scenes/world", "res://scripts/world"]
	for d: String in dirs:
		for f: String in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			var src: String = FileAccess.get_file_as_string(d + "/" + f)
			for line: String in src.split("\n"):
				if line.contains("encounter_id") or line.contains("_mob(") or line.contains("resolve_encounter("):
					for m: RegExMatch in re.search_all(line):
						var id: String = m.get_string(1)
						if id.begins_with("farm_") or id.begins_with("meadow_") or id.begins_with("crop_") or id.begins_with("coop_") or id.begins_with("pond_"):
							check(Rules.ENCOUNTERS.has(id), "world encounter id " + id)
	for id: String in ["meadow_grunts", "meadow_pair", "crop_crows", "crop_mixed", "coop_raid", "pond_blobs"]:
		check(Rules.ENCOUNTERS.has(id), "farm mob encounter " + id)
