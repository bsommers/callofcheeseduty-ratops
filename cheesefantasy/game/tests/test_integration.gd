extends RefCounted
## Director: battle_requested -> (stub) battle -> battle_finished -> GameState applied; dish tier bookkeeping.

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_battle_loop() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var d: Node = tree.root.get_node_or_null("Director")
	check(d != null, "Director autoload present")
	if d == null:
		return
	var gs: Node = tree.root.get_node("GameState")
	var ev: Node = tree.root.get_node("Events")
	gs.new_game()
	gs.gain_xp(3000)
	var gold0: int = int(gs.gold)
	var n0: int = int(d.battles_done)
	ev.battle_requested.emit("meadow_grunts")
	check(d.battling, "battling flag set")
	await tree.process_frame
	if d.battling:  # real battle scene is waiting for input: finish it with a winning result
		ev.battle_finished.emit({"won": true, "fled": false, "xp": 10, "gold": 5, "drops": [], "encounter": "meadow_grunts"})
	for i in 5:
		await tree.process_frame
	check(not d.battling, "battle resolved")
	check(int(d.battles_done) == n0 + 1, "battle counted")
	check(bool(d.last_applied.get("won", false)), "stub battle won at high level")
	check(int(gs.gold) >= gold0, "gold applied")
	check(not WorldBus.locked, "world unlocked")


func test_dish_tier() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var d: Node = tree.root.get_node_or_null("Director")
	if d == null:
		return
	d.add_dish("grilled_cheese", 2)
	d.add_dish("grilled_cheese", 1)
	check(int(tree.root.get_node("GameState").flag("dish_tier_grilled_cheese", -1)) == 2, "best tier kept")
