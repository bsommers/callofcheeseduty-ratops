extends SceneTree
## Headless QA runner: boots main.tscn, starts a New Game on one level, lets QaBot play it and prints one
## `QA_RESULT {json}` line. usage:
##   tools/godot.sh --headless --fixed-fps 60 --path game --script res://scripts/qa/qa_run.gd -- --level=e1m1 [--limit=300] [--seed=1234] [--secrets]

const MAIN_SCENE: String = "res://scenes/main.tscn"


func _initialize() -> void:
	var level: String = "e1m1"
	var limit: float = 300.0
	var seed_value: int = 1234
	var secrets: bool = false
	var skill: int = -1
	var god: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.trim_prefix("--level=")
		elif a.begins_with("--limit="):
			limit = float(a.trim_prefix("--limit="))
		elif a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--skill="):
			skill = int(a.trim_prefix("--skill="))
		elif a == "--god":
			god = true
		elif a == "--secrets":
			secrets = true
	_run.call_deferred(level, limit, seed_value, secrets, skill, god)


func _run(level: String, limit: float, seed_value: int, secrets: bool, skill: int, god: bool) -> void:
	await process_frame
	var res: Dictionary = await run_level(self, level, limit, seed_value, secrets, skill, god)
	print("QA_RESULT " + JSON.stringify(res))
	quit(0 if bool(res.get("reached_exit", false)) else 1)


## Shared with tests/test_playthrough.gd. Boots main.tscn, New Game on `level`, returns the bot result.
static func run_level(tree: SceneTree, level: String, limit: float, seed_value: int, secrets: bool, skill: int = -1, god: bool = false) -> Dictionary:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	# loaded lazily: QaBot's dependencies reference autoload names, which only exist once the tree runs
	var bot: Node = (load("res://scripts/qa/qa_bot.gd") as GDScript).new()
	tree.root.add_child(bot)
	bot.set("god", god)
	bot.call("start", level, limit, seed_value, secrets)
	var game: Node = tree.root.get_node("Game")
	game.call("new_game", level, skill)  # same call the title menu's New Game button makes
	var res: Dictionary = await bot.finished
	bot.queue_free()
	main.queue_free()
	await tree.process_frame
	return res
