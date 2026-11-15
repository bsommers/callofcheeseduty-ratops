extends "res://tests/test_case.gd"
## Defs must be a faithful port of reference/kasekrieg/defs.js (same numbers).

const REF: String = "res://../reference/kasekrieg/defs.js"


func _ref_text() -> String:
	var p: String = ProjectSettings.globalize_path("res://").path_join("../reference/kasekrieg/defs.js").simplify_path()
	return FileAccess.get_file_as_string(p)


func _ref_num(src: String, key: String, field: String) -> float:
	var start: int = src.find("\n  %s: {" % key)
	if start < 0:
		return NAN
	var re: RegEx = RegEx.create_from_string("\\b%s: (-?[0-9.]+)" % field)
	var m: RegExMatch = re.search(src, start)
	return float(m.get_string(1)) if m != null else NAN


func test_enemies_match_reference() -> void:
	var src: String = _ref_text()
	if not check(src.length() > 1000, "reference defs.js readable"):
		return
	check(Defs.ENEMIES.size() >= 6, "6 enemy kinds")
	for kind: String in Defs.ENEMIES:
		var e: Dictionary = Defs.ENEMIES[kind]
		eq(float(e["hp"]), _ref_num(src, kind, "hp"), "%s.hp" % kind)
		eq(float(e["score"]), _ref_num(src, kind, "score"), "%s.score" % kind)
		eq(float(e["speed"]), _ref_num(src, kind, "speed"), "%s.speed" % kind)


func test_items_scores_match_reference() -> void:
	var src: String = _ref_text()
	for id: String in Defs.ITEMS:
		var it: Dictionary = Defs.ITEMS[id]
		if it.has("score"):
			eq(float(it["score"]), _ref_num(src, id, "score"), "%s.score" % id)
		if it.has("heal"):
			eq(float(it["heal"]), _ref_num(src, id, "heal"), "%s.heal" % id)


func test_weapons_table() -> void:
	var ids: Array = Defs.WEAPONS.map(func(w: Dictionary) -> String: return w["id"])
	eq(ids, ["claws", "pistol", "gatling", "yarn", "laser"], "weapon slot order")
	eq(Defs.weapon("pistol")["dmg"], [9, 24], "pistol dmg")
	eq(Defs.weapon(0)["id"], "claws", "weapon by index")
	eq(Defs.weapon("nope"), {}, "unknown weapon")
	eq(Defs.weapon_index("laser"), 4, "laser index")


func test_start_and_levels() -> void:
	eq(int(Defs.START["lives"]), 9, "start lives")
	eq(int(Defs.START["health"]), 100, "start health")
	eq(Defs.LEVELS.size(), 6, "6 levels")
	eq(Defs.level_index("e1m6"), 5, "e1m6 index")
	eq(Defs.level_index("e9m9"), -1, "unknown level")
	check(Defs.level_par("e1m1") > 0, "par time")
	eq(Defs.cells(2.5), 10.0, "cells to metres")


func test_intermission_bonus() -> void:
	var s: Dictionary = {"kills": 10, "kills_total": 10, "secrets": 0, "secrets_total": 3,
		"treasure": 1, "treasure_total": 2, "time": 100.0, "par": 110}
	var expect: int = int(Defs.SCORING["kill_ratio_100"]) + 10 * int(Defs.SCORING["par_bonus_per_sec"])
	eq(Defs.intermission_bonus(s), expect, "bonus = full kills + 10 s under par")
	s["time"] = 500.0
	s["kills"] = 9
	eq(Defs.intermission_bonus(s), 0, "no bonus")
