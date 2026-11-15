extends Node
## Preview harness for tools/shot.sh: start("party"|"items"|"bestiary"|"summons"|"save"|"settings"|"shop"|"title").

func start(arg: String = "party") -> void:
	var gs: Node = MenuStyle.auto("GameState")
	gs.add_item("chef_ladle", 1, false)
	gs.add_item("cheese_knife", 1, false)
	gs.party["fennel"].hp = 40
	gs.set_flag("seen_rat_grunt", true)
	gs.set_flag("seen_rat_brute", true)
	if arg == "title":
		add_child(load("res://scenes/ui/menus_title.tscn").instantiate())
	elif arg == "shop":
		var s: ShopMenu = load("res://scenes/ui/menus_shop.tscn").instantiate()
		add_child(s)
		s.open_shop("cheesemonger_shop")
	else:
		var m: GameMenus = load("res://scenes/ui/menus.tscn").instantiate()
		add_child(m)
		var tabs: Array = ["party", "items", "bestiary", "summons", "save", "settings"]
		m._sel_enemy = "rat_brute"
		m._sel_item = "milk_bottle"
		m.open(tabs.find(arg) if arg in tabs else 0)
	get_tree().paused = false  # shot harness polls in _process; a paused tree never captures
