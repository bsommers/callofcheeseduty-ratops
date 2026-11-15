extends RefCounted
## QA bot: scripted main-quest playthrough through GameRoot + Director + real BattleEngine.
## usage: tools/godot.sh --headless --path game --script res://tests/qa_playthrough.gd
var tree: SceneTree
var defects: Array = []
var notes: Array = []
var lost: int = 0
var fought: int = 0


func ck(c: bool, m: String) -> void:
	if not c:
		defects.append(m)
		print("  DEFECT ", m)


func _avg_level() -> float:
	var t: float = 0.0
	for c: String in GameState.active:
		t += float(GameState.party[c].level)
	return t / maxf(1.0, float(GameState.active.size()))


## Fights `enc` with the real engine (auto commands + summon when the gauge allows), then pushes the result
## through Events.battle_finished like the battle scene does. Returns won.
func _fight(enc: String, use_summon: String = "") -> bool:
	Events.battle_requested.emit(enc)
	await tree.process_frame
	var e: BattleEngine = BattleEngine.new()
	e.setup(enc, GameState.battle_party(), {"seed": randi() % 100000, "inventory": GameState.inventory, "recipes": GameState.recipes,
		"summons": GameState.summons, "gauge": 100 if use_summon != "" else GameState.fondue_gauge, "gold": GameState.gold})
	e.start()
	var n: int = 0
	var cast: bool = false
	while not e.is_over() and n < 600:
		var cmd: Dictionary = e.auto_command(e.current_uid)
		if use_summon != "" and not cast and e.can_summon(use_summon):
			cmd = {"type": "summon", "summon": use_summon}
			cast = true
		e.step(cmd)
		n += 1
	var res: Dictionary = e.result()
	res["encounter"] = enc
	if use_summon != "":
		ck(cast, "summon %s never cast in %s" % [use_summon, enc])
	fought += 1
	Events.battle_finished.emit(res)
	await tree.process_frame
	await tree.process_frame
	if not res.get("won", false):
		lost += 1
		if OS.get_environment("QA_VERBOSE") != "":
			var info: Array = []
			for c: String in GameState.active:
				info.append("%s L%d %s hp%d" % [c, GameState.party[c].level, str(GameState.party[c].equip), GameState.party[c].get("max_hp", 0)])
			print("   LOST %s actions=%d | %s | inv=%s summons=%s" % [enc, e.actions, "; ".join(info), GameState.inventory, GameState.summons])
	ck(GameState.gold >= 0, "negative gold after %s" % enc)
	return bool(res.get("won", false))


func _gear_up() -> void:
	GameState.add_gold(0)
	for shop_id: String in Data.SHOPS:
		for id: String in GameState.shop_stock(shop_id):
			var it: Dictionary = Data.item(id)
			if it.has("slot") and GameState.count(id) == 0:
				GameState.spend_gold(int(it.get("price", 0)))
				if GameState.gold >= 0:
					GameState.add_item(id, 1, false)
	for cid: String in GameState.active:
		for slot: String in ["weapon", "armor", "charm"]:
			var best: String = ""
			var bs: int = -1
			for id: String in GameState.inventory:
				var it2: Dictionary = Data.item(id)
				if it2.get("slot", "") != slot or GameState.count(id) <= 0:
					continue
				if not it2.get("who", []).is_empty() and not cid in it2.who:
					continue
				var sc: int = 0
				for k: String in it2.get("stats", {}):
					sc += int(it2.stats[k])
				if sc > bs:
					bs = sc
					best = id
			if best != "":
				GameState.equip(cid, best)


func _grind_to(target: int, pool: Array) -> void:
	var guard: int = 0
	while _avg_level() < target and guard < 60:
		GameState.heal_all()
		if guard % 6 == 0:
			_gear_up()
		await _fight(pool[guard % pool.size()])
		guard += 1
	if guard > 0:
		notes.append("grind to L%d took %d fights" % [target, guard])


func run(p_tree: SceneTree) -> int:
	tree = p_tree
	await tree.process_frame
	var root: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.name = "GameRoot"
	tree.root.add_child(root)
	await tree.process_frame
	ck(root.get("title") != null, "title not shown on boot")
	root._on_new_game()
	for i in 20:
		await tree.process_frame
	ck(tree.get_first_node_in_group("farm") != null, "farm not loaded after New Game")
	await tree.create_timer(0.8).timeout
	# --- Gouda / main quest
	Events.dialogue_started.emit("farmer_gouda")
	GameState.set_flag("quest_started", true)
	Events.dialogue_finished.emit("farmer_gouda")
	await tree.process_frame
	ck(Story.qstage(Story.MAIN) == 1, "main quest not at stage 1 after Gouda")
	# --- progression through the field encounters (grind only as needed)
	var path: Array = ["meadow_grunts", "meadow_pair", "crop_crows", "crop_mixed", "coop_raid", "pond_blobs", "pasture_rats",
		"barn_sappers", "orchard_magpies", "orchard_weasels"]
	var easy: Array = ["meadow_grunts", "meadow_pair", "crop_crows"]
	for enc: String in path:
		var lvl: int = int(Data.ENCOUNTERS[enc].level)
		if _avg_level() + 0.5 < lvl:
			await _grind_to(lvl, easy if lvl < 4 else [path[mini(3, path.find(enc) - 1)], enc])
		GameState.heal_all()
		var w: bool = await _fight(enc)
		print("  %-16s L%-2d party L%.1f %s" % [enc, lvl, _avg_level(), "WIN" if w else "LOSS"])
	# --- shop: buy every starter-shop item we can afford, sell one
	GameState.add_gold(2000)
	var bought: int = 0
	for shop_id: String in Data.SHOPS:
		for id: String in GameState.shop_stock(shop_id):
			var price: int = int(Data.item(id).get("price", Data.INGREDIENTS.get(id, {}).get("price", 5)))
			var g0: int = GameState.gold
			if GameState.spend_gold(price):
				GameState.add_item(id, 1)
				bought += 1
				ck(GameState.gold == g0 - price, "shop %s gold math" % shop_id)
	ck(bought > 20, "shops sold too little (%d)" % bought)
	notes.append("shop bought %d items across %d shops" % [bought, Data.SHOPS.size()])
	_gear_up()
	# --- cooking through the real cooking UI: every start recipe
	var cooked: int = 0
	for rid: String in GameState.recipes.duplicate():
		var r: Dictionary = Data.RECIPES[rid]
		for slot0: String in r.slots:
			GameState.add_item(slot0, 1, false)
		var ui: Node = Director.open_cooking("field")
		if ui == null:
			ck(false, "open_cooking returned null")
			break
		var ok: bool = true
		for slot: String in r.slots:
			var got: bool = false
			for ing: String in GameState.ingredients_held():
				if ing == slot or CookingLogic.slot_score(slot, ing, Data.INGREDIENTS) > 0:
					if ui.pick(ing):
						got = true
						break
			ok = ok and got
			if not got:
				notes.append("cook %s: no ingredient for slot %s" % [rid, slot])
		if ok and ui.start_stir():
			for k in 8:
				if int(ui.phase) != int(ui.Phase.STIR):
					break
				ui.marker = ui.zone_center
				ui.stir_press()
			if ui.last_result.get("dish_id", "") == rid:
				cooked += 1
			else:
				notes.append("cook %s produced %s" % [rid, ui.last_result.get("dish_id", "?")])
		elif ok:
			notes.append("cook %s: start_stir failed" % rid)
		ui.close()
		await tree.process_frame
	notes.append("cooked %d/%d start recipes through the cooking UI" % [cooked, GameState.recipes.size()])
	ck(cooked >= GameState.recipes.size() - 3, "cooking UI produced only %d of %d recipes" % [cooked, GameState.recipes.size()])
	# --- shrine: unlock all 4 summons via the memory quests
	for s: String in ["jesse", "tripper", "samantha", "spooky"]:
		var ui2: ShrineUI = ShrineUI.new()
		tree.root.add_child(ui2)
		ui2._sel = s
		if s == "spooky":
			GameState.add_item("memory_yarn", 1)
		ui2._complete()
		ui2.queue_free()
		ck(s in GameState.summons, "summon %s not unlocked" % s)
	# --- each summon in a real engine battle
	for s: String in ["jesse", "tripper", "samantha", "spooky"]:
		GameState.heal_all()
		await _fight("orchard_weasels", s)
	# --- save/load round trip
	var before: Dictionary = {"gold": GameState.gold, "inv": GameState.inventory.size(), "flags": GameState.flags.size(),
		"rec": GameState.recipes.size(), "sum": GameState.summons.size(), "lv": GameState.party["fennel"].level,
		"eq": str(GameState.party["fennel"].equip), "q": GameState.quests.size()}
	ck(GameState.save_game(8), "save_game failed")
	GameState.add_gold(777)
	GameState.summons.clear()
	ck(GameState.load_game(8), "load_game failed")
	var after: Dictionary = {"gold": GameState.gold, "inv": GameState.inventory.size(), "flags": GameState.flags.size(),
		"rec": GameState.recipes.size(), "sum": GameState.summons.size(), "lv": GameState.party["fennel"].level,
		"eq": str(GameState.party["fennel"].equip), "q": GameState.quests.size()}
	ck(str(before.get("eq")).length() == str(after.get("eq")).length() and before.erase("eq") == after.erase("eq") and before == after, "save/load round trip differs: %s vs %s" % [before, after])
	DirAccess.remove_absolute(GameState.save_path(8))
	# --- Crow Baron
	await _grind_to(int(Data.ENCOUNTERS.boss_crow_baron.level) - 1, ["orchard_weasels", "pasture_rats"])
	_gear_up()
	GameState.heal_all()
	var baron: bool = await _fight("boss_crow_baron")
	if not baron:
		GameState.heal_all()
		baron = await _fight("boss_crow_baron")
	ck(baron, "Crow Baron lost twice")
	ck(GameState.has_item("cave_key"), "no cave_key after Crow Baron")
	ck(Story.qstage(Story.MAIN) == 2, "main stage != 2 after baron")
	# --- cave
	Director.open_cave()
	await tree.process_frame
	var d: CaveDelve = Director.delve
	ck(d != null, "cave delve not opened")
	var ended: Array = [false]
	if d != null:
		d.ending_requested.connect(func() -> void: ended[0] = true)
		for i in CaveDelve.FLOORS.size():
			var enc2: String = CaveDelve.FLOORS[CaveDelve.floor_index()].enc
			var lv2: int = int(Data.ENCOUNTERS[enc2].level)
			await _grind_to(lv2 - 1, ["orchard_weasels", "pasture_rats"])
			d._fight()
			var tries: int = 0
			var extra: int = 0
			var won: bool = false
			while not won and tries < 6:
				_gear_up()
				GameState.heal_all()
				won = await _fight(enc2)
				tries += 1
				if not won:
					extra += 1
					await _grind_to(lv2 + extra, ["cave_mixed", "cave_golems"])
					d._fight()
			print("  cave floor %d %-18s L%d party L%.1f %s (tries %d)" % [i + 1, enc2, lv2, _avg_level(), "WIN" if won else "LOSS", tries])
			if not won:
				ck(false, "cave floor %d (%s) unbeatable in 6 tries at party L%.1f" % [i + 1, enc2, _avg_level()])
				break
	ck(ended[0], "ending not requested after Rat King")
	ck(GameState.flag("game_complete", false), "game_complete flag unset")
	ck(Story.qstage(Story.MAIN) == 99, "main quest not done")
	print("QA PLAYTHROUGH: fights=%d lost=%d final party L%.1f gold=%d" % [fought, lost, _avg_level(), GameState.gold])
	for n: String in notes:
		print("  note: ", n)
	print("QA PLAYTHROUGH DEFECTS: ", defects.size())
	return defects.size()
