extends Node
## Director (autoload, owner integ-lead): glues world <-> battle <-> cooking.
## - Events.battle_requested -> hides the farm, runs BattleScene (or a headless BattleEngine auto-resolve stub),
##   on Events.battle_finished applies the result via GameState and restores the farm.
## - farm.interaction_triggered(cauldron|campfire) -> cooking.tscn (field mode).

const BATTLE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const COOKING_SCENE: String = "res://scenes/ui/cooking.tscn"

const SHOPS_BY_NPC: Dictionary = {"cheesemonger": "cheesemonger_shop", "tinker": "tinker_wares", "cook": "cook_pantry", "granny": "granny_stall"}
const AREA_ZONES: Array = [["rainbow_orchard", Vector2(-52, -36), 14.0], ["pond", Vector2(34, -34), 13.0], ["barnyard", Vector2(22, 4), 14.0]]

var story: Story = null
var delve: CaveDelve = null
var shrine: ShrineUI = null
var music_hold: bool = false
var ending_active: bool = false
var _music: String = ""
var _tick: float = 0.0
var battling: bool = false
var cooking_open: bool = false
var last_applied: Dictionary = {}
var battles_done: int = 0
var _battle_node: Node = null
var _cook_layer: CanvasLayer = null
var _hidden: Array = []
var _farm: Node = null
var _scan: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.battle_requested.connect(_on_battle_requested)
	Events.battle_finished.connect(_on_battle_finished)
	Events.dialogue_finished.connect(_on_dialogue_finished)
	story = Story.new()
	story.name = "Story"
	add_child(story)


## Called by GameRoot when a fresh session (title) starts.
func reset() -> void:
	battling = false
	cooking_open = false
	music_hold = false
	ending_active = false
	_farm = null
	_music = ""
	WorldBus.locked = false
	for n: Node in [delve, shrine]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	delve = null
	shrine = null


func _process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.4
	var f: Node = get_tree().get_first_node_in_group("farm")
	if f != _farm:
		_farm = f if (f != null and is_instance_valid(f)) else null
		if _farm != null:
			if f.has_signal("interaction_triggered") and not f.is_connected("interaction_triggered", _on_interaction):
				f.connect("interaction_triggered", _on_interaction)
			story.bind_farm(f)
			_music = ""
	if _farm == null:
		return
	_track_player()


## Keeps GameState.area/position current and picks the area music (farm theme by default).
func _track_player() -> void:
	var pl: Variant = _farm.get("player")
	if pl == null or not is_instance_valid(pl) or battling or music_hold:
		return
	var p3: Vector3 = (pl as Node3D).global_position
	GameState.position = p3
	var p2: Vector2 = Vector2(p3.x, p3.z)
	var area: String = "farmhouse"
	var terr: Variant = _farm.get("terrain")
	if terr != null and p2.distance_to(terr.get("cave_pos")) < 16.0:
		area = "cheese_cave"
	else:
		for z: Array in AREA_ZONES:
			if p2.distance_to(z[1]) < float(z[2]):
				area = str(z[0])
				break
	GameState.area = area
	var want: String = str(Data.AREAS.get(area, {}).get("music", "farm_day"))
	if want != _music:
		_music = want
		Audio.play_music(want)


# ------------------------------------------------------------------ battle
func _on_battle_requested(enc_id: String) -> void:
	if battling:
		return
	battling = true
	WorldBus.locked = true
	_hide_world()
	var ps: Variant = load(BATTLE_SCENE) if ResourceLoader.exists(BATTLE_SCENE) else null
	if ps is PackedScene:
		var node: Node = (ps as PackedScene).instantiate()
		if node != null and node.has_method("start"):
			_battle_node = node
			get_tree().root.add_child(_battle_node)
			_battle_node.call("start", enc_id)
			return
		if node != null:
			node.free()
	# Stub: headless auto-resolve through the engine.
	call_deferred("_stub_battle", enc_id)


func _stub_battle(enc_id: String) -> void:
	var eng: BattleEngine = BattleEngine.new()
	eng.setup(enc_id, GameState.battle_party(), {"inventory": GameState.inventory, "recipes": GameState.recipes, "summons": GameState.summons, "gauge": GameState.fondue_gauge})
	eng.start()
	eng.run_auto()
	Events.battle_finished.emit(eng.result())


func _on_battle_finished(result: Dictionary) -> void:
	if not battling:
		return
	battling = false
	if _battle_node != null and is_instance_valid(_battle_node):
		_battle_node.queue_free()
	_battle_node = null
	var gained: Dictionary = {} if bool(result.get("applied", false)) else GameState.apply_battle_result(result)
	last_applied = result
	battles_done += 1
	if not result.get("won", false) and not result.get("fled", false):
		GameState.heal_all()
		Events.toast.emit("The party wakes up back on the farm...")
	elif result.get("won", false):
		Events.toast.emit("Victory! +%d XP, +%d gold" % [int(result.get("xp", 0)), int(result.get("gold", 0))])
	_show_world()
	_music = ""
	WorldBus.locked = delve != null and is_instance_valid(delve)
	Events.party_changed.emit()
	if not gained.is_empty():
		pass


func _hide_world() -> void:
	_hidden.clear()
	var cs: Node = get_tree().get_first_node_in_group("world_root")
	if cs == null:
		cs = get_tree().current_scene
	if cs == null:
		return
	cs.process_mode = Node.PROCESS_MODE_DISABLED
	if cs is Node3D:
		(cs as Node3D).visible = false
	_hidden.append(cs)
	for n: Node in cs.find_children("*", "CanvasLayer", true, false):
		var cl: CanvasLayer = n as CanvasLayer
		if cl.visible:
			cl.visible = false
			_hidden.append(cl)


func _show_world() -> void:
	for n: Variant in _hidden:
		if not is_instance_valid(n):
			continue
		if n is CanvasLayer:
			(n as CanvasLayer).visible = true
		elif n is Node3D:
			(n as Node3D).visible = true
			(n as Node).process_mode = Node.PROCESS_MODE_INHERIT
		else:
			(n as Node).process_mode = Node.PROCESS_MODE_INHERIT
	_hidden.clear()


# ------------------------------------------------------------------ cooking
func _on_interaction(kind: String, _pid: String) -> void:
	match kind:
		"cauldron":
			open_cooking()
		"campfire":
			_campfire_menu()
		"shrine":
			_open_shrine_soon()


# ------------------------------------------------------------------ campfire (rest + save + cook)
func _campfire_menu() -> void:
	WorldBus.locked = true
	var m: IntegModal = IntegModal.ask(get_tree().root, "Campfire", "The fire crackles. A good place to rest, save and cook.", ["Rest and save", "Cook a meal", "Step away"])
	m.chosen.connect(_on_campfire_choice)


func _on_campfire_choice(i: int) -> void:
	if i == 0:
		GameState.heal_all()
		Events.party_changed.emit()
		Audio.play_sfx("heal")
		Events.toast.emit("The party rests. HP and MP restored.")
		var menus: Node = get_tree().get_first_node_in_group("game_menus")
		if menus != null:
			menus.call("open", 4, true)
			menus.connect("closed", _unlock_world, CONNECT_ONE_SHOT)
			return
	elif i == 1:
		WorldBus.locked = false
		open_cooking()
		return
	_unlock_world()


func _unlock_world() -> void:
	WorldBus.locked = false


# ------------------------------------------------------------------ shrine
func _open_shrine_soon() -> void:
	await get_tree().process_frame
	var box: Node = get_tree().get_first_node_in_group("dialogue_box")
	if box != null and bool(box.get("active")):
		Events.dialogue_finished.connect(_open_shrine_ui, CONNECT_ONE_SHOT)
	else:
		_open_shrine_ui("")


func _open_shrine_ui(_npc: String = "") -> void:
	if shrine != null and is_instance_valid(shrine):
		return
	WorldBus.locked = true
	music_hold = true
	shrine = ShrineUI.new()
	get_tree().root.add_child(shrine)
	shrine.closed.connect(func() -> void:
		music_hold = false
		_music = ""
		WorldBus.locked = false)


# ------------------------------------------------------------------ shops
func _on_dialogue_finished(npc_id: String) -> void:
	if not SHOPS_BY_NPC.has(npc_id):
		return
	var shop: Node = get_tree().get_first_node_in_group("shop_menu")
	if shop != null and not bool(shop.get("is_open")):
		shop.call_deferred("open_shop", SHOPS_BY_NPC[npc_id])


# ------------------------------------------------------------------ cave / ending
func open_cave() -> void:
	if battling or (delve != null and is_instance_valid(delve)):
		return
	WorldBus.locked = true
	music_hold = true
	delve = CaveDelve.new()
	get_tree().root.add_child(delve)
	delve.left.connect(func() -> void:
		music_hold = false
		_music = ""
		delve = null
		WorldBus.locked = false)
	delve.ending_requested.connect(start_ending)


func start_ending() -> void:
	if ending_active:
		return
	ending_active = true
	music_hold = true
	delve = null
	GameState.set_flag("game_complete", true)
	Story.setq(Story.MAIN, 5)
	Story.setq(Story.MAIN, "done")
	var e: EndingScreen = EndingScreen.new()
	get_tree().root.add_child(e)
	e.finished.connect(func() -> void:
		var gr: Node = get_tree().get_first_node_in_group("game_root")
		if gr != null:
			gr.call("go_title"))


func open_cooking(mode: String = "field") -> Node:
	if cooking_open or battling or not ResourceLoader.exists(COOKING_SCENE):
		return null
	cooking_open = true
	WorldBus.locked = true
	_cook_layer = CanvasLayer.new()
	_cook_layer.layer = 50
	get_tree().root.add_child(_cook_layer)
	var ui: Control = (load(COOKING_SCENE) as PackedScene).instantiate()
	_cook_layer.add_child(ui)
	ui.connect("finished", _on_cook_finished)
	ui.connect("closed", _on_cook_closed)
	var cid: String = str(GameState.active[0]) if GameState.active.size() > 0 else ""
	ui.call("open", mode, cid)
	return ui


func _on_cook_finished(r: Dictionary) -> void:
	add_dish(str(r.get("dish_id", "")), int(r.get("tier", 0)))


func _on_cook_closed() -> void:
	if _cook_layer != null:
		_cook_layer.queue_free()
		_cook_layer = null
	cooking_open = false
	WorldBus.locked = false


## Record the best quality tier achieved per dish (inventory counting is done by the cooking UI itself).
func add_dish(id: String, tier: int) -> void:
	if id == "":
		return
	var key: String = "dish_tier_" + id
	if tier > int(GameState.flag(key, -1)):
		GameState.set_flag(key, tier)
