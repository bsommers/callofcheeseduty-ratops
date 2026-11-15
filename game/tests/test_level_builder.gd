extends SceneTree
## Run: tools/godot.sh --headless --path game --script res://tests/test_level_builder.gd
## Builds e1m1..e1m6, checks geometry/things/nav/doors, prints PASS/FAIL, exits non-zero on failure.

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for n in range(1, 7):
		var id := "e1m%d" % n
		var d := LevelBuilder.load_level_json(id)
		_check(not d.is_empty(), id + " json loads")
		if d.is_empty():
			continue
		var b := LevelBuilder.new()
		root.add_child(b)
		var ok := b.build(d)
		_check(ok, id + " builds")
		var geo := b.get_node("Geometry")
		var meshes := 0
		for c in geo.get_children():
			if c is MeshInstance3D:
				meshes += 1
		_check(meshes >= 3, id + " has merged meshes (%d)" % meshes)
		_check(get_nodes_in_group("door").size() >= (d["doors"] as Array).size(), id + " doors %d" % get_nodes_in_group("door").size())
		_check(b.enemy_spawns.size() == int(d["stats"].get("enemies", b.enemy_spawns.size())), id + " enemy spawns %d vs stats %d" % [b.enemy_spawns.size(), int(d["stats"].get("enemies", -1))])
		_check(b.nav_region != null and b.nav_region.navigation_mesh.get_polygon_count() > 10, id + " navmesh")
		_check(b.exit_area != null, id + " exit")
		var sp := b.player_start.origin
		var sx := int(sp.x / b.cell)
		var sz := int(sp.z / b.cell)
		_check(b._is_walkable(sx, sz), id + " player start walkable")
		# every enemy spawn on a walkable cell
		for e in b.enemy_spawns:
			var p: Vector3 = e["pos"]
			if not b._is_walkable(int(p.x / b.cell), int(p.z / b.cell)):
				_check(false, id + " enemy on solid cell %s" % str(p))
		print("%s ok: meshes=%d doors=%d pushwalls=%d enemies=%d navpolys=%d" % [id, meshes, (d["doors"] as Array).size(), (d["pushwalls"] as Array).size(), b.enemy_spawns.size(), b.nav_region.navigation_mesh.get_polygon_count()])
		root.remove_child(b)
		b.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
