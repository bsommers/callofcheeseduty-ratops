class_name RatMain
extends Node
## Main boot scene script (owner: integ-lead). Wires the modules: UI root, audio manager, level parent,
## player spawn after a level is built, hero visual setup. Command line `-- --level=e1m1` skips the title.

@onready var _level_root: Node3D = $LevelRoot

var player: RatPlayer = null


func _ready() -> void:
	Game.set_level_parent(_level_root)
	Events.level_loaded.connect(_on_level_loaded)
	var direct: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			direct = true
			Game.new_game(arg.trim_prefix("--level="))
	if not direct:
		Events.music.emit("title")


func _on_level_loaded(_id: String) -> void:
	var lvl: Node = Game.current_level()
	if lvl == null:
		return
	# Game calls build_level deferred; wait for the builder's `built` signal, else a couple of frames.
	if lvl.has_signal("built"):
		lvl.connect("built", _spawn_player.bind(lvl), CONNECT_ONE_SHOT)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_spawn_player({}, lvl)


func _spawn_player(_stats: Dictionary, lvl: Node) -> void:
	if not is_instance_valid(lvl) or lvl != Game.current_level():
		return
	for old: Node in get_tree().get_nodes_in_group("player"):
		if lvl.is_ancestor_of(old):
			return  # already spawned
	player = RatPlayer.spawn_in_level(lvl)
	if player != null:
		HeroSetup.apply(player)
		if not Events.weapon_changed.is_connected(_on_weapon_changed):
			Events.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(str(player.weapons.def().get("id", "pistol")) if player.weapons != null else "pistol")
	PropSetup.apply(lvl)
	for e: RatEnemy in RatEnemySpawner.spawn_in_level(lvl):
		RatModelSetup.hook(e)
	if player != null:
		_brighten(lvl)


func _on_weapon_changed(id: String) -> void:
	if is_instance_valid(player) and player.model != null:
		HeroSetup.equip_weapon(player.model, id)


## Environment/exposure now come from look-dev's LookRig (instanced in main.tscn). Only a small hero fill light stays here.
func _brighten(_lvl: Node) -> void:
	if player.get_node_or_null("FillLight") == null:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "FillLight"
		l.position = Vector3(0.0, 1.9, 0.0)
		l.light_color = Color(1.0, 0.86, 0.62)
		l.light_energy = 0.8
		l.omni_range = 9.0
		l.shadow_enabled = false
		player.add_child(l)
