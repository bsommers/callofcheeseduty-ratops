extends "res://tests/test_case.gd"
## Game state machine, lives/score rules and level flow (headless: no scene is spawned
## because the level parent is set to a detached node).

var _holder: Node3D


func before_each() -> void:
	_holder = Node3D.new()
	tree.root.add_child(_holder)
	Game.set_level_parent(_holder)
	Game.quit_to_title()


func after_each() -> void:
	Game.quit_to_title()
	Game.set_level_parent(null)
	tree.paused = false
	_holder.queue_free()


func test_starts_at_title_and_new_game() -> void:
	eq(Game.state, Game.State.TITLE, "title")
	Game.new_game("e1m2")
	eq(Game.state, Game.State.PLAYING, "playing")
	eq(Game.level_id, "e1m2", "level id")
	eq(Game.level_index, 1, "level index")
	eq(Game.lives, 9, "lives")
	eq(Game.score, 0, "score")
	check(Game.current_level() != null, "level node spawned under parent")


func test_unknown_level_rejected() -> void:
	Game.new_game("e1m1")
	check(not Game.start_level("zzz"), "unknown id returns false")
	eq(Game.level_id, "e1m1", "level unchanged")


func test_illegal_transitions() -> void:
	check(not Game.set_state(Game.State.PAUSED), "title -> paused illegal")
	check(not Game.set_state(Game.State.VICTORY), "title -> victory illegal")
	eq(Game.state, Game.State.TITLE, "still title")


func test_pause_toggle() -> void:
	Game.new_game("e1m1")
	var seen: Array = []
	var cb: Callable = func(p: bool) -> void: seen.append(p)
	Events.paused_changed.connect(cb)
	Game.toggle_pause()
	eq(Game.state, Game.State.PAUSED, "paused")
	check(tree.paused, "tree paused")
	Game.toggle_pause()
	eq(Game.state, Game.State.PLAYING, "resumed")
	check(not tree.paused, "tree unpaused")
	Events.paused_changed.disconnect(cb)
	eq(seen, [true, false], "paused_changed emitted")


func test_kills_and_treasure_score() -> void:
	Game.new_game("e1m1")
	Events.enemy_killed.emit("mouse", Vector3.ZERO)
	eq(Game.score, int(Defs.enemy("mouse")["score"]), "kill score")
	Events.pickup_taken.emit("brie_wheel", 1)
	eq(Game.score, int(Defs.enemy("mouse")["score"]) + int(Defs.item("brie_wheel")["score"]), "treasure score")
	eq(int(Game.stats["kills"]), 1, "kill stat")
	eq(int(Game.stats["treasure"]), 1, "treasure stat")
	Events.pickup_taken.emit("fish_treat", 10)
	eq(int(Game.stats["treasure"]), 1, "health is not treasure")


func test_death_restores_level_start_score() -> void:
	Game.new_game("e1m1")
	Game.add_score(1234)
	Game.complete_level()
	eq(Game.state, Game.State.INTERMISSION, "intermission")
	Game.next_level()
	eq(Game.level_id, "e1m2", "next level")
	var start_score: int = Game.score
	Game.loadout["owned"][2] = true
	Game.loadout["weapon"] = 2
	var start_loadout: Dictionary = Game.loadout.duplicate(true)
	Game._level_start_loadout = start_loadout.duplicate(true)  # as if picked up before the level began
	Game.add_score(500)
	Game.loadout["owned"][3] = true
	Events.player_died.emit()
	eq(Game.lives, 8, "life lost")
	eq(Game.score, start_score, "score restored")
	eq(Game.loadout["owned"], start_loadout["owned"], "weapons restored")
	eq(Game.state, Game.State.PLAYING, "still playing")


func test_game_over_at_zero_lives() -> void:
	Game.new_game("e1m1")
	Game.lives = 1
	Events.player_died.emit()
	eq(Game.lives, 0, "no lives")
	eq(Game.state, Game.State.GAME_OVER, "game over")


func test_victory_after_last_level() -> void:
	Game.new_game("e1m6")
	Events.level_completed.emit({"kills_total": 1, "kills": 1})
	eq(Game.state, Game.State.VICTORY, "victory after e1m6")
	check(int(Game.stats["bonus"]) >= int(Defs.SCORING["kill_ratio_100"]), "bonus applied")
