extends RefCounted
## End-to-end story loop through GameRoot (title -> new game -> farm -> quests -> shrine -> cave -> ending).
## Battles are completed by emitting Events.battle_finished (the battle scene itself is covered elsewhere).

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _win(tree: SceneTree, enc: String) -> void:
	Events.battle_requested.emit(enc)
	await tree.process_frame
	var res: Dictionary = {"won": true, "fled": false, "xp": 50, "gold": 10, "drops": [], "encounter": enc}
	var e: Dictionary = Data.ENCOUNTERS.get(enc, {})
	if e.has("flag"):
		res["flag"] = e.flag
	Events.battle_finished.emit(res)
	await tree.process_frame
	await tree.process_frame


func test_full_loop() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(root)
	await tree.process_frame
	check(root.title != null, "title shown on boot")
	root._on_new_game()
	for i in 20:
		await tree.process_frame
	check(root.world != null and tree.get_first_node_in_group("farm") != null, "farm loaded under world_root")
	await tree.create_timer(0.8).timeout
	var st: Story = Director.story
	check(st.farm != null, "story bound to farm")
	# main quest
	GameState.set_flag("quest_started", true)
	st.sync_main()
	check(Story.qstage(Story.MAIN) == 1, "main quest started at stage 1")
	check(tree.get_first_node_in_group("farm").find_child("StoryPoint_silo_door", true, false) != null, "silo point exists")
	# memory quests: Jesse
	Story.setq("memory_jesse", 1)
	st._on_interaction("memory", "memory_jesse:windowsill")
	check(Story.qstage("memory_jesse") == 2, "jesse windowsill -> stage 2")
	# Tripper: loft then battle
	Story.setq("memory_tripper", 0)
	st._on_interaction("memory", "memory_tripper:barn_loft")
	check(Story.qstage("memory_tripper") == 1, "tripper loft")
	Story.setq("memory_samantha", 0)
	st._on_interaction("memory", "memory_samantha:frozen_pool")
	check(Story.qstage("memory_samantha") == 0, "samantha needs cocoa")
	GameState.add_item("warm_cocoa", 1)
	st._on_interaction("memory", "memory_samantha:frozen_pool")
	st._on_interaction("memory", "memory_samantha:white_feather")
	check(Story.qstage("memory_samantha") == 2, "samantha chain")
	# shrine completes
	var ui: ShrineUI = ShrineUI.new()
	tree.root.add_child(ui)
	ui._sel = "jesse"
	ui._complete()
	check("jesse" in GameState.summons, "jesse summon unlocked")
	ui._sel = "samantha"
	ui._complete()
	check("samantha" in GameState.summons, "samantha summon unlocked")
	ui.queue_free()
	# silo boss -> cave key
	await _win(tree, "boss_crow_baron")
	check(GameState.has_item("cave_key"), "cave key after crow baron")
	check(Story.qstage(Story.MAIN) == 2, "main stage 2")
	# cave delve
	Director.open_cave()
	check(Director.delve != null, "delve opened")
	var d: CaveDelve = Director.delve
	var ended: Array = [false]
	d.ending_requested.connect(func() -> void: ended[0] = true)
	for i in CaveDelve.FLOORS.size():
		d._fight()
		var enc: String = CaveDelve.FLOORS[CaveDelve.floor_index()].enc
		await _win(tree, enc)
	check(ended[0], "ending requested after the Rat King")
	check(Story.qstage(Story.MAIN) == 99, "main quest done")
	check(GameState.flag("game_complete", false), "game_complete flag")
	root.queue_free()
	await tree.process_frame
