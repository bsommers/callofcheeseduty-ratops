extends SceneTree
## QA bot: headless validation of encounters, recipes, summons, and level-1 survivability.
## usage: tools/godot.sh --headless --path game --script res://scripts/qa/qa_validate.gd -- [seeds]
const Rules = preload("res://data/db.gd")
const Eng = preload("res://scripts/battle/battle_engine.gd")
const T = preload("res://tests/test_battle.gd")

var defects: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if args.size() > 0 else 20
	_encounters(seeds)
	_recipes()
	_summons()
	_level_one(seeds)
	print("QA DEFECTS: %d" % defects.size())
	for d: String in defects:
		print("DEFECT ", d)
	quit(1 if defects.size() > 0 else 0)


func _encounters(seeds: int) -> void:
	var n: int = 0
	for id: String in Rules.ENCOUNTERS:
		var enc: Dictionary = Rules.ENCOUNTERS[id]
		n += 1
		var en: Array = enc.get("enemies", [])
		if en.is_empty() or en.size() > 5:
			defects.append("encounter %s enemy count %d" % [id, en.size()])
		for e: String in en:
			if not Rules.ENEMIES.has(e):
				defects.append("encounter %s unknown enemy %s" % [id, e])
		var e1: Eng = Eng.new()
		e1.setup(id, T.party_at(int(enc.level)), {"seed": 7})
		if e1.enemies().size() != en.size():
			defects.append("encounter %s engine spawned %d of %d enemies" % [id, e1.enemies().size(), en.size()])
		var wins: int = 0
		for s: int in seeds:
			var e: RefCounted = T.simulate(id, 9000 + s, 1 if enc.get("boss", false) else 0)
			if e.timed_out or not e.is_over():
				defects.append("encounter %s seed %d did not terminate" % [id, s])
			var r: Dictionary = e.result()
			for k: String in ["won", "fled", "xp", "gold", "drops"]:
				if not r.has(k):
					defects.append("encounter %s result missing %s" % [id, k])
			if e.won:
				wins += 1
				if int(r.get("gold", 0)) < 0:
					defects.append("encounter %s result gold negative (%d) after thief steal" % [id, int(r.gold)])
		if wins == 0:
			defects.append("encounter %s unwinnable at recommended level (0/%d)" % [id, seeds])
	print("encounters checked: %d" % n)


func _recipes() -> void:
	var items: Dictionary = Rules.items()
	var ing_ids: Array = Rules.INGREDIENTS.keys()
	for id: String in Rules.RECIPES:
		var r: Dictionary = Rules.RECIPES[id]
		if not items.has(id):
			defects.append("recipe %s has no dish item" % id)
		var pick: Array = []
		var ok: bool = true
		for slot: String in r.slots:
			var found: String = ""
			for cand: String in ing_ids:
				if Rules._slot_ok(slot, cand) and (not cand in pick or true):
					found = cand
					if slot == "cheese" and r.get("pair", "") != "":
						found = r.pair
					break
			if found == "":
				ok = false
				defects.append("recipe %s slot %s has no ingredient" % [id, slot])
			pick.append(found)
		if ok:
			var m: String = Rules.match_recipe(pick)
			if m != id and not Rules.recipe_fits(id, pick):
				defects.append("recipe %s: ingredients %s match %s" % [id, pick, m])
			for q: int in 4:
				var d: Dictionary = Rules.dish_effect(id, q)
				if d.is_empty():
					defects.append("recipe %s dish_effect empty at quality %d" % [id, q])
	if Rules.match_recipe(["wheat", "wheat", "wheat", "wheat"]) != "mystery_mush":
		defects.append("junk combination does not give mystery_mush")
	print("recipes checked: %d" % Rules.RECIPES.size())


func _summons() -> void:
	for sid: String in Rules.SUMMONS:
		var s: Dictionary = Rules.SUMMONS[sid]
		for k: String in ["name", "element", "model", "power", "target", "cost", "intro"]:
			if not s.has(k):
				defects.append("summon %s missing field %s" % [sid, k])
		if s.get("unlock_quest", "") != "" and not Rules.QUESTS.has(s.unlock_quest):
			defects.append("summon %s unlock_quest %s unknown" % [sid, s.unlock_quest])
		var e: Eng = Eng.new()
		e.setup("king_guard", T.party_at(26), {"seed": 3, "summons": [sid], "gauge": 100})
		if not e.can_summon(sid):
			defects.append("summon %s not castable with full gauge" % sid)
			continue
		e.start()
		if not e.needs_input():
			defects.append("summon %s: engine not awaiting input after start" % sid)
			continue
		var healer: bool = int(s.get("power", 1)) == 0 and float(s.get("heal_pct", 0.0)) > 0.0
		if healer:
			e.party()[0].hp = 1
		var hp0: int = 0
		for a: Dictionary in (e.party() if healer else e.enemies()):
			hp0 += int(a.hp)
		var beats: Array = e.step({"type": "summon", "summon": sid})
		var cast: bool = false
		for b: Dictionary in beats:
			if b.get("type", "") == "summon" and not b.get("failed", false):
				cast = true
		if not cast:
			defects.append("summon %s produced no summon beat" % sid)
		var hp1: int = 0
		for a: Dictionary in (e.party() if healer else e.enemies()):
			hp1 += int(a.hp)
		if healer and hp1 <= hp0:
			defects.append("summon %s healed nobody (%d -> %d)" % [sid, hp0, hp1])
		elif not healer and hp1 >= hp0:
			defects.append("summon %s dealt no damage (%d -> %d)" % [sid, hp0, hp1])
	print("summons checked: %d" % Rules.SUMMONS.size())


func _level_one(seeds: int) -> void:
	## Fresh new-game party (L1, GameState.START_ITEMS-like kit) against every non-boss encounter up to level 5.
	var kit: Dictionary = {"milk_bottle": 4, "herb_salve": 1, "smelling_salts": 1, "rot_cure": 2, "wheat": 2, "butter": 2, "cheddar": 2}
	for id: String in Rules.ENCOUNTERS:
		var enc: Dictionary = Rules.ENCOUNTERS[id]
		if enc.get("boss", false) or int(enc.level) > 5:
			continue
		var w: int = 0
		for s: int in seeds:
			var e: Eng = Eng.new()
			e.setup(id, T.party_at(1), {"seed": 100 + s, "inventory": kit, "recipes": ["grilled_cheese"]})
			e.run_auto()
			if e.won:
				w += 1
		print("L1 party vs %-16s (L%d, %d foes): %d/%d" % [id, int(enc.level), enc.enemies.size(), w, seeds])
		if int(enc.level) <= 2 and w < seeds * 0.8:
			defects.append("level-1 party wins only %d/%d vs %s (L%d)" % [w, seeds, id, int(enc.level)])
