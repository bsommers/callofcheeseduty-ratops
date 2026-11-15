extends "res://tests/test_case.gd"
## integ-lead: main.tscn wiring, boot -> level -> player spawn, hero setup, Events additions.

var _main: Node = null


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await tree.process_frame
	_main = null
	autoload("Game").call("_reset_run")


func _boot() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_main = ps.instantiate()
	tree.root.add_child(_main)
	await tree.process_frame


func test_events_signals() -> void:
	var ev: Node = autoload("Events")
	for s: String in ["hit_marker", "crosshair_spread", "enemy_alerted", "enemy_hurt", "door_locked", "noise"]:
		check(ev.has_signal(s), "Events." + s)


func test_main_scene_children() -> void:
	await _boot()
	check(_main.get_node_or_null("UIRoot") != null, "UIRoot")
	check(_main.get_node_or_null("AudioManager") != null, "AudioManager")
	check(_main.get_node_or_null("LevelRoot") != null, "LevelRoot")


func test_new_game_spawns_player() -> void:
	await _boot()
	autoload("Game").call("new_game", "e1m1")
	for i: int in 30:
		await tree.process_frame
	var lvl: Node = autoload("Game").call("current_level")
	check(lvl != null, "level exists")
	var ps: Array[Node] = tree.get_nodes_in_group("player")
	check(ps.size() == 1, "exactly one player, got %d" % ps.size())
	if ps.size() == 1:
		var p: RatPlayer = ps[0] as RatPlayer
		check(p.model != null, "hero model present")
		check(lvl.is_ancestor_of(p), "player under level")
		var sk: Skeleton3D = p.model.find_child("Skeleton3D", true, false) as Skeleton3D
		check(sk != null and sk.get_node_or_null("WeaponHand") != null, "WeaponHand attachment")
		var ap: AnimationPlayer = p.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if check(ap != null, "animation player"):
			var loops: int = 0
			for a: String in ap.get_animation_list():
				if ap.get_animation(a).loop_mode == Animation.LOOP_LINEAR:
					loops += 1
			check(loops >= 8, "looping clips flagged: %d" % loops)
		for mi: Node in p.model.find_children("*_LOD1", "MeshInstance3D", true, false):
			check(not (mi as MeshInstance3D).visible, "LOD1 hidden " + mi.name)
		var furs: int = 0
		for mi: Node in p.model.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			for s: int in m.mesh.get_surface_count():
				if m.get_surface_override_material(s) is ShaderMaterial:
					furs += 1
		check(furs >= 1, "fur applied to hero (%d surfaces)" % furs)
		check(absf(p.model.rotation.y) < 0.01, "hero model faces -Z (no extra yaw)")
		check(sk != null and sk.get_node_or_null("WeaponHand") != null and sk.get_node("WeaponHand").get_node_or_null("WeaponModel") != null, "weapon model in hand")
		var enemies: Array[Node] = tree.get_nodes_in_group("enemy")
		check(enemies.size() >= 10, "enemies spawned: %d" % enemies.size())
		var withmodel: int = 0
		var flashes: int = 0
		for e: Node in enemies:
			var re: RatEnemy = e as RatEnemy
			if re.model != null and not re.is_placeholder():
				withmodel += 1
				if re.model.find_child("Flash_RightMuzzle", true, false) != null:
					flashes += 1
		check(withmodel == enemies.size(), "all enemies use rat glb (%d/%d)" % [withmodel, enemies.size()])
		check(flashes >= 1, "muzzle flash attachments: %d" % flashes)
		var props: int = 0
		for d: Node in lvl.find_children("Decor_*", "Node3D", true, false):
			if d.has_meta("prop_done"):
				props += 1
		check(props >= 1, "decor replaced by prop models: %d" % props)


func test_restart_no_double_player() -> void:
	await _boot()
	autoload("Game").call("new_game", "e1m1")
	for i: int in 30:
		await tree.process_frame
	autoload("Game").call("restart_level")
	for i: int in 30:
		await tree.process_frame
	check(tree.get_nodes_in_group("player").size() == 1, "one player after restart, got %d" % tree.get_nodes_in_group("player").size())
