extends Node
## Screenshot harness: user arg --start=<shrine|cave|boss|ending|farm> (shot.sh --start).
func _ready() -> void:
	GameState.new_game()
	var mode: String = "shrine"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--start="):
			mode = a.substr(8)
	for s: String in ["jesse", "tripper", "samantha", "spooky"]:
		GameState.unlock_summon(s)
		Story.setq(Data.SUMMONS[s].unlock_quest, "done")
	match mode:
		"shrine":
			var u: ShrineUI = ShrineUI.new()
			add_child(u)
			u._sel = "spooky"
			u._refresh()
		"cave", "boss":
			GameState.set_flag("cave_floor", 5 if mode == "boss" else 1)
			add_child(CaveDelve.new())
		"ending":
			add_child(EndingScreen.new())
		_:
			add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
