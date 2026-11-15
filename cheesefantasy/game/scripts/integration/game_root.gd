class_name GameRoot
extends Node
## Boot/session root (owner integ-lead; main.tscn instantiates this script).
## Title (menus_title.tscn) -> New Game / Continue -> farm under a `world_root` container.
## Owns the single pause menu (menus.tscn, opened on the `menu` action, saving disallowed outside
## campfire/cauldron) and the shop menu (menus_shop.tscn).

const FARM: String = "res://scenes/world/farm.tscn"
const MENUS: String = "res://scenes/ui/menus.tscn"
const SHOP: String = "res://scenes/ui/menus_shop.tscn"
const TITLE: String = "res://scenes/ui/menus_title.tscn"

var world: Node3D = null
var menus: Node = null
var shop: Node = null
var title: Control = null
var _title_layer: CanvasLayer = null
var _loading: bool = false


func _ready() -> void:
	add_to_group("game_root")
	Director.reset()
	menus = (load(MENUS) as PackedScene).instantiate()
	menus.set("enabled", false)
	menus.add_to_group("game_menus")
	add_child(menus)
	shop = (load(SHOP) as PackedScene).instantiate()
	shop.add_to_group("shop_menu")
	add_child(shop)
	Events.game_loaded.connect(_on_game_loaded)
	go_title()


func go_title() -> void:
	Director.reset()
	get_tree().paused = false
	if world != null:
		world.queue_free()
		world = null
	if _title_layer != null:
		_title_layer.queue_free()
	_title_layer = CanvasLayer.new()
	_title_layer.layer = 20
	add_child(_title_layer)
	title = (load(TITLE) as PackedScene).instantiate()
	_title_layer.add_child(title)
	title.connect("new_game_requested", _on_new_game)
	title.connect("continue_requested", _on_continue)


func _on_new_game() -> void:
	GameState.new_game()
	start_world()


func _on_continue(slot: int) -> void:
	if not GameState.load_game(slot):
		GameState.new_game()
	# load_game emits game_loaded -> _on_game_loaded starts/reloads the world.
	if world == null:
		start_world()


func start_world() -> void:
	if _loading:
		return
	_loading = true
	if _title_layer != null:
		_title_layer.queue_free()
		_title_layer = null
		title = null
	if world != null:
		world.queue_free()
		world = null
		await get_tree().process_frame
	Director.reset()
	world = Node3D.new()
	world.name = "World"
	world.add_to_group("world_root")
	add_child(world)
	var farm: Node = (load(FARM) as PackedScene).instantiate()
	world.add_child(farm)
	var pos: Vector3 = GameState.position
	if pos != Vector3.ZERO:
		var pl: Variant = farm.get("player")
		if pl != null:
			(pl as Node3D).global_position = pos + Vector3(0, 0.5, 0)
	menus.set("enabled", false)
	_loading = false


func _on_game_loaded(_slot: int) -> void:
	# Loading from the in-game pause menu: rebuild the world so the state matches.
	if world != null and not _loading:
		call_deferred("start_world")


func _unhandled_input(e: InputEvent) -> void:
	if world == null or menus == null:
		return
	if InputMap.has_action("menu") and e.is_action_pressed("menu") and not get_tree().paused \
			and not WorldBus.locked and not Director.battling and not Director.cooking_open:
		menus.call("open", 0, false)
		get_viewport().set_input_as_handled()
