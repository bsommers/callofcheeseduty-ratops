extends "res://tests/test_case.gd"
## Polish gameplay regressions: stats merge at level end, decal pruning, music events.


func test_stats_not_corrupted_on_complete() -> void:
	Game.new_game("e1m1")
	Game.stats["kills"] = 3
	Game.stats["treasure"] = 2
	Game.stats["secrets"] = 1
	Events.level_completed.emit({"id": "e1m1", "enemies": 19, "treasure": 20, "secrets": 3})
	eq(int(Game.stats["kills"]), 3, "kills kept")
	eq(int(Game.stats["treasure"]), 2, "treasure counter kept")
	eq(int(Game.stats["secrets"]), 1, "secrets counter kept")
	eq(int(Game.stats["kills_total"]), 19, "kills_total from builder enemies")
	eq(int(Game.stats["treasure_total"]), 20, "treasure_total")
	eq(int(Game.stats["secrets_total"]), 3, "secrets_total")
	var par_part: int = int(floor(float(Game.stats["par"]) - float(Game.stats["time"]))) * int(Defs.SCORING["par_bonus_per_sec"])
	eq(int(Game.stats["bonus"]), maxi(par_part, 0), "no ratio bonuses with partial counters")


func test_all_kills_bonus() -> void:
	Game.new_game("e1m1")
	Game.stats["kills"] = 19
	Events.level_completed.emit({"enemies": 19, "treasure": 20, "secrets": 3})
	check(int(Game.stats["bonus"]) >= int(Defs.SCORING["kill_ratio_100"]), "kill ratio bonus")


func test_decal_pruning_typed() -> void:
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	for i in 5:
		var d: Decal = RatWeaponFx.decal(root, Vector3(i, 0, 0), Vector3.UP)
		check(d != null, "decal %d" % i)
		d.free()
	RatWeaponFx.decal(root, Vector3.ZERO, Vector3.UP)
	root.queue_free()
