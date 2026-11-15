class_name RatEnemySpawner
extends RefCounted
## Spawns enemies (owner: enemy-ai). Hook for the game flow, after LevelBuilder.build_level(id) succeeded
## (e.g. on its `built` signal):  RatEnemySpawner.spawn_in_level(level)
## Reads LevelBuilder.enemy_spawns ({type, patrol, pos, node}) or, failing that, Marker3D nodes in group
## `enemy_spawn` (meta enemy_type / patrol) under the level. Enemies are children of the level root, so a
## level restart frees them. Idempotent per level (meta `enemies_spawned`).

const SCENE_PATH: String = "res://scenes/enemy.tscn"


static func create(kind: String, opts: Dictionary = {}) -> RatEnemy:
	var e: RatEnemy = null
	if ResourceLoader.exists(SCENE_PATH):
		var ps: PackedScene = load(SCENE_PATH) as PackedScene
		if ps != null:
			e = ps.instantiate() as RatEnemy
	if e == null:
		e = RatEnemy.new()
	e.name = "Enemy_%s" % kind
	e.configure(kind, opts)
	return e


static func spawn(parent: Node, kind: String, pos: Vector3, opts: Dictionary = {}) -> RatEnemy:
	if parent == null:
		return null
	var e: RatEnemy = create(kind, opts)
	if opts.has("auto_tick"):
		e.auto_tick = bool(opts["auto_tick"])
	parent.add_child(e, true)
	e.global_position = pos
	return e


static func spawn_in_level(level: Node, opts: Dictionary = {}) -> Array[RatEnemy]:
	var out: Array[RatEnemy] = []
	if level == null or not level.is_inside_tree():
		return out
	if level.has_meta("enemies_spawned"):
		for n: Node in level.get_children():
			if n is RatEnemy:
				out.append(n as RatEnemy)
		return out
	level.set_meta("enemies_spawned", true)
	RatEnemy.ensure_signals()
	var list: Array = []
	if "enemy_spawns" in level and level.get("enemy_spawns") is Array and not (level.get("enemy_spawns") as Array).is_empty():
		for d: Variant in level.get("enemy_spawns"):
			if d is Dictionary:
				var dd: Dictionary = d
				var pos: Vector3 = dd.get("pos", Vector3.ZERO)
				if dd.get("node", null) is Node3D and is_instance_valid(dd["node"]):
					pos = (dd["node"] as Node3D).global_position
				elif level is Node3D:
					pos = (level as Node3D).to_global(pos)
				list.append({"type": str(dd.get("type", "mouse")), "patrol": bool(dd.get("patrol", false)), "pos": pos})
	else:
		for m: Node in level.get_tree().get_nodes_in_group("enemy_spawn"):
			if m is Node3D and level.is_ancestor_of(m):
				list.append({"type": str(m.get_meta("enemy_type", "mouse")), "patrol": bool(m.get_meta("patrol", false)),
					"pos": (m as Node3D).global_position})
	for s: Dictionary in list:
		var o: Dictionary = opts.duplicate()
		o["patrol"] = s["patrol"]
		var e: RatEnemy = spawn(level, str(s["type"]), s["pos"], o)
		if e != null:
			out.append(e)
	return out
