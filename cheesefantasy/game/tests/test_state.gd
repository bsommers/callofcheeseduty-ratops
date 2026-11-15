extends RefCounted
## GameState autoload: new game, xp/level-ups, battle result application, save/load round trip.

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")


func test_new_game_and_xp() -> void:
	var gs: Node = _gs()
	check(gs != null, "GameState autoload present")
	if gs == null:
		return
	gs.new_game()
	check(gs.active.size() == 4, "4 active members")
	check(gs.member_stats("fennel").atk > 0, "derived stats")
	check("grilled_cheese" in gs.recipes, "starting recipes")
	var ups: Dictionary = gs.gain_xp(5000)
	check(ups.has("fennel") and int(gs.party.fennel.level) > 5, "level up from xp (L%d)" % int(gs.party.fennel.level))
	check(gs.member_skills("fennel").size() > 2, "skills learned with levels")


func test_apply_result_and_save_roundtrip() -> void:
	var gs: Node = _gs()
	if gs == null:
		return
	gs.new_game()
	var g0: int = gs.gold
	gs.apply_battle_result({"won": true, "xp": 30, "gold": 50, "drops": ["wheat", "cheddar"], "encounter": "boss_crow_baron",
		"party": [{"id": "fennel", "hp": 5, "mp": 1}], "used_items": {"milk_bottle": 1}, "gauge": 40})
	check(gs.gold == g0 + 50, "gold applied")
	check(gs.count("cheddar") == 3, "drop added (cheddar=%d)" % gs.count("cheddar"))
	check(gs.count("milk_bottle") == 3, "used item removed")
	check(gs.flag("beat_crow_baron"), "boss flag set")
	check(gs.fondue_gauge == 40, "gauge kept")
	check("parmesan" in gs.shop_stock("cheesemonger_shop"), "shop unlock by flag")
	gs.set_quest("lost_chickens", "done")
	check(gs.knows_recipe("cheese_omelette"), "quest reward recipe")
	check(gs.save_game(2), "save ok")
	var snapshot: String = JSON.stringify(gs.to_dict().duplicate(true).merged({"saved_at": ""}, true))
	gs.new_game()
	check(gs.load_game(2), "load ok")
	var again: String = JSON.stringify(gs.to_dict().merged({"saved_at": ""}, true))
	check(snapshot == again, "save/load round trip identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path(2)))
	gs.new_game()


func test_set_quest_int_and_string_stages() -> void:
	var gs: Node = GameState
	gs.quests["lost_chickens"] = 0
	gs.set_quest("lost_chickens", 1)
	check(int(gs.quests["lost_chickens"]) == 1, "int stage stored")
	gs.set_quest("lost_chickens", "done")
	gs.set_quest("lost_chickens", 1)
	check(str(gs.quests["lost_chickens"]) == "done", "done is sticky")
