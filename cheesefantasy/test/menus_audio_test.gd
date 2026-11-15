extends SceneTree
## tools/godot.sh --headless --path game --script res://../test/... ; run via: tools/godot.sh --headless --path game --script <abs path>
func _init() -> void:
	for n: String in []:
		if root.get_node_or_null(n) == null:
			var f: String = {"Events": "events", "Data": "data", "Settings": "settings", "Audio": "audio", "GameState": "state"}[n]
			var node: Node = (load("res://autoload/%s.gd" % f) as GDScript).new()
			node.name = n
			root.add_child(node)
	await process_frame
	var fails: int = 0
	var gs: Node = root.get_node("GameState")
	var menus: GameMenus = load("res://scenes/ui/menus.tscn").instantiate()
	root.add_child(menus)
	var shop: ShopMenu = load("res://scenes/ui/menus_shop.tscn").instantiate()
	root.add_child(shop)
	var title: Control = load("res://scenes/ui/menus_title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	menus.open()
	for t: int in GameMenus.TABS.size():
		menus._set_tab(t, false)
		await process_frame
	print("tabs ok")
	gs.party["fennel"].hp = 10
	menus._use_item("milk_bottle", "fennel")
	if int(gs.party["fennel"].hp) <= 10: fails += 1; print("FAIL use item")
	menus._on_battle_finished({"encounter": "meadow_grunts"})
	if not gs.flag("seen_rat_grunt"): fails += 1; print("FAIL bestiary")
	menus._set_tab(2, false)
	menus._do_save(3)
	if not gs.has_save(3): fails += 1; print("FAIL save")
	menus.close()
	gs.gold = 1000
	shop.open_shop("cheesemonger_shop")
	var g0: int = gs.gold
	shop._transact("milk_bottle")
	if gs.gold >= g0: fails += 1; print("FAIL buy")
	shop._set_mode(1)
	shop._transact("milk_bottle")
	await process_frame
	shop.close()
	var a: Node = root.get_node("Audio")
	for id: String in ["ui_select", "ui_confirm", "ui_cancel", "cooking_sizzle", "summon_sting", "dialogue_blip"]:
		if not a.has_sfx(id): fails += 1; print("FAIL sfx ", id)
	DirAccess.remove_absolute(gs.save_path(3))
	print("RESULT fails=", fails)
	quit(fails)
