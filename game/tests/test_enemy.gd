extends "res://tests/test_case.gd"
## Enemy AI tests (owner: enemy-ai): data port, scene seam, damage/headshot/death-once, LOS + cone,
## hearing, state transitions, hitscan / melee / projectile attacks, cover, boss phase 2, real e1m1 spawn.

const DT: float = 1.0 / 60.0

class MockPlayer extends CharacterBody3D:
	var hits: Array = []
	var dead: bool = false
	func _init() -> void:
		add_to_group("player")
		collision_layer = 2
		collision_mask = 1
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.9
		cs.shape = cap
		cs.position.y = 0.95
		add_child(cs)
	func take_damage(amount: float, source: Node = null, hitbox: String = "") -> int:
		hits.append({"amount": amount, "source": source, "hitbox": hitbox})
		return int(amount)
	func total() -> int:
		var t: int = 0
		for h: Dictionary in hits:
			t += int(h["amount"])
		return t

var _root: Node3D
var _player: MockPlayer
var _killed: Array = []
var _hurt: int = 0
var _alerted: int = 0


func before_each() -> void:
	RatEnemy.ensure_signals()
	_root = Node3D.new()
	_root.name = "EnemyTestArena"
	tree.root.add_child(_root)
	var floor_b: StaticBody3D = _box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	floor_b.name = "Floor"
	_player = MockPlayer.new()
	_player.name = "MockPlayer"
	_root.add_child(_player)
	_killed.clear()
	_hurt = 0
	_alerted = 0
	var ev: Node = autoload("Events")
	ev.connect("enemy_killed", _on_killed)
	ev.connect("enemy_hurt", _on_hurt)
	ev.connect("enemy_alerted", _on_alerted)
	await _phys(2)


func after_each() -> void:
	var ev: Node = autoload("Events")
	for pair: Array in [["enemy_killed", _on_killed], ["enemy_hurt", _on_hurt], ["enemy_alerted", _on_alerted]]:
		if ev.is_connected(pair[0], pair[1]):
			ev.disconnect(pair[0], pair[1])
	if is_instance_valid(_root):
		_root.queue_free()
	await tree.process_frame


func _on_killed(kind: String, _pos: Vector3) -> void:
	_killed.append(kind)


func _on_hurt(_kind: String, _pos: Vector3) -> void:
	_hurt += 1


func _on_alerted(_kind: String, _pos: Vector3) -> void:
	_alerted += 1


func _phys(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	_root.add_child(b)
	b.global_position = pos
	return b


func _enemy(kind: String, pos: Vector3 = Vector3.ZERO, opts: Dictionary = {}) -> RatEnemy:
	var o: Dictionary = {"seed": 7, "skill": 2, "auto_tick": false, "yaw": 0.0}
	o.merge(opts, true)
	var e: RatEnemy = RatEnemySpawner.spawn(_root, kind, pos, o)
	e.rotation.y = 0.0   # face -Z
	return e


func _ticks(e: RatEnemy, n: int) -> void:
	for i: int in n:
		e.tick(DT)


func _nums(a: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = []
	if a is Array:
		for v: Variant in a:
			out.append(float(v))
	return out


# ───────────────────────────── data / scene ─────────────────────────────
func test_data_matches_reference_defs() -> void:
	for k: String in Defs.ENEMIES:
		var ref: Dictionary = Defs.ENEMIES[k]
		var d: Dictionary = RatEnemy.kind_def(k)
		if not check(not d.is_empty() and RatEnemy.data()["kinds"].has(k), "kind %s in enemies.json" % k):
			continue
		for f: String in ["hp", "score", "pain_chance"]:
			eq(float(d[f]), float(ref[f]), "%s.%s" % [k, f])
		eq(str(d["drop"]), str(ref["drop"]), "%s.drop" % k)
		var ra: Dictionary = ref["attack"]
		var da: Dictionary = d["attack"]
		eq(str(da["kind"]), str(ra["kind"]), "%s.attack.kind" % k)
		for f: String in ["shots", "gap", "windup"]:
			eq(float(da[f]), float(ra[f]), "%s.attack.%s" % [k, f])
		eq(_nums(da.get("cooldown")), _nums(ra.get("cooldown")), "%s cooldown" % k)
		if ra.has("dmg"):
			eq(_nums(da["dmg"]), _nums(ra["dmg"]), "%s dmg" % k)
		eq(float(da["ref_range"]), float(ra["range"]), "%s ref range" % k)
		eq(float(d["ref_speed"]), float(ref["speed"]), "%s ref speed" % k)
		check(absf(float(d["speed"]) - float(ref["speed"]) * 1.294) < 0.02, "%s speed scaled" % k)
	eq(str(RatEnemy.kind_def("boss")["phase2"]["below"]), "0.5", "boss phase2 threshold")


func test_scene_structure_and_model_seam() -> void:
	var e: RatEnemy = _enemy("trooper", Vector3(0, 0, 0))
	await _phys(1)
	check(e.is_in_group("enemy"), "group enemy")
	eq(e.collision_layer, 4, "layer 3 bit")
	var head: Area3D = e.get_node_or_null("Head") as Area3D
	check(head != null and head.collision_layer == 4 and head.is_in_group("hitbox_head"), "Head hitbox on layer 3")
	check(e.has_meta("head_y") and float(e.get_meta("head_y")) > 1.2, "head_y meta")
	check(e.nav != null, "NavigationAgent3D")
	var glb: bool = ResourceLoader.exists("res://assets/models/rat_trooper.glb")
	eq(e.is_placeholder(), not glb, "glb model used when present")
	if glb:
		eq(e.play_anim("run"), "run", "run clip")
		eq(e.play_anim("death_b"), "death_b", "death_b clip")
		eq(e.play_anim("no_such_clip"), "", "unknown clip -> no-op")
		var ap: AnimationPlayer = e.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		eq(ap.get_animation(str(e._clips["walk"])).loop_mode, Animation.LOOP_LINEAR, "walk loops")
	e.set_model("res://assets/models/does_not_exist.glb")
	check(e.is_placeholder(), "missing model -> capsule placeholder")
	eq(e.play_anim("run"), "", "placeholder: animation no-op")
	for k: String in ["mouse", "officer", "sewer", "panzer", "boss"]:
		var o: RatEnemy = _enemy(k, Vector3(randf() * 20 - 10, 0, 20))
		check(o.model != null, "%s model" % k)
		eq(o.hp, int(Defs.ENEMIES[k]["hp"]), "%s hp at Alley Cat" % k)


# ───────────────────────────── damage ─────────────────────────────
func test_damage_headshot_and_hitbox() -> void:
	var e: RatEnemy = _enemy("trooper", Vector3(0, 0, 0))
	await _phys(2)
	eq(e.take_damage(10, _player, "body"), 10, "body dmg")
	eq(e.hp, 40, "hp after body")
	eq(_hurt, 1, "enemy_hurt emitted")
	check(e.alerted, "damage alerts")
	eq(e.take_damage(10, _player, "head"), 10, "weapons pre-multiply: no double headshot")
	e.head_receive_mult = 2.5
	eq(e.take_damage(4, _player, "Head"), 10, "head multiplier when enabled")
	# real ray at head height hits the Head Area / head_y -> weapon classifies "head"
	var from: Vector3 = Vector3(0, float(e.get_meta("head_y")) + 0.1, -5)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, 10), 1 | 4 | 64)
	q.collide_with_areas = true
	var r: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(q)
	if check(not r.is_empty(), "head ray hits"):
		check(RatWeapons.find_enemy(r["collider"]) == e, "find_enemy from hit")
		eq(RatWeapons.hitbox_of(r, e), "head", "weapon hitbox classification")
	from = Vector3(0, 0.8, -5)
	q = PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, 10), 1 | 4 | 64)
	q.collide_with_areas = true
	r = e.get_world_3d().direct_space_state.intersect_ray(q)
	if check(not r.is_empty(), "body ray hits"):
		eq(RatWeapons.hitbox_of(r, e), "body", "body classification")


func test_death_once_and_drop() -> void:
	var e: RatEnemy = _enemy("mouse", Vector3(0, 0, 0))
	await _phys(1)
	for i: int in 4:
		e.take_damage(30, _player, "body")
	eq(_killed.size(), 1, "enemy_killed exactly once")
	eq(e.state, RatEnemy.State.DEAD, "dead state")
	eq(e.take_damage(30, _player, "body"), 0, "no damage when dead")
	eq(e.collision_layer, 0, "corpse not shootable")
	_ticks(e, 5)
	eq(e.state, RatEnemy.State.DEAD, "stays dead")
	var drops: int = 0
	for p: Node in tree.get_nodes_in_group("pickup"):
		if _root.is_ancestor_of(p) and str(p.get("item_id")) == "ammo_clip":
			drops += 1
	eq(drops, 1, "mouse drops one ammo_clip")
	# trooper: weapon the player lacks first
	var t: RatEnemy = _enemy("trooper", Vector3(5, 0, 0))
	var drop: Node = null
	t.take_damage(999, _player, "body")
	for p: Node in tree.get_nodes_in_group("pickup"):
		if _root.is_ancestor_of(p) and str(p.name).contains(t.name):
			drop = p
	check(drop != null and str(drop.get("item_id")) == "gatling", "trooper drops gatling when not owned")


# ───────────────────────────── perception ─────────────────────────────
func test_line_of_sight_and_cone() -> void:
	var e: RatEnemy = _enemy("mouse", Vector3(0, 0, 0))
	_player.global_position = Vector3(0, 0, -12)
	await _phys(2)
	check(e.can_see(_player), "sees player ahead")
	_player.global_position = Vector3(0, 0, 12)
	await _phys(1)
	check(not e.can_see(_player), "unalerted: player behind is outside the cone")
	check(e.can_see(_player, true), "ignore cone")
	_player.global_position = Vector3(0, 0, 3)
	await _phys(1)
	check(e.can_see(_player), "feel range: very close behind")
	_player.global_position = Vector3(0, 0, -12)
	_box(Vector3(0, 2, -6), Vector3(6, 4, 0.5))
	await _phys(2)
	check(not e.can_see(_player), "wall blocks LOS")
	check(not e.has_los(e.eye_position(), RatEnemy.target_point(_player)), "has_los false through wall")


func test_hearing_noise() -> void:
	var e: RatEnemy = _enemy("officer", Vector3(0, 0, 0))
	_player.global_position = Vector3(0, 0, 30)
	await _phys(2)
	var ev: Node = autoload("Events")
	ev.emit_signal("noise", Vector3(0, 0, 150), 40.0)
	check(not e.alerted, "far noise ignored")
	ev.emit_signal("noise", Vector3(0, 0, 30), 40.0)
	check(e.alerted, "gunshot heard")
	eq(e.state, RatEnemy.State.ALERT, "idle -> alert on noise")
	eq(_alerted, 1, "enemy_alerted emitted once")


func test_state_transitions() -> void:
	var e: RatEnemy = _enemy("trooper", Vector3(0, 0, 0))
	var friend: RatEnemy = _enemy("mouse", Vector3(8, 0, 6))
	friend.rotation.y = PI   # facing away
	friend._fixed_yaw = PI
	_player.global_position = Vector3(0, 0, -14)
	await _phys(2)
	eq(e.state, RatEnemy.State.IDLE, "starts idle")
	_ticks(e, 2)
	eq(e.state, RatEnemy.State.ALERT, "sees -> alert")
	check(friend.alerted, "shout alerts nearby friend")
	var seen: Dictionary = {}
	for i: int in 240:
		e.tick(DT)
		seen[e.state_name()] = true
	check(seen.has("chase") and seen.has("attack"), "alert -> chase -> attack: %s" % str(e.debug_log))
	check(_player.hits.size() > 0 or e._atk_count > 0, "attacked")
	# lose the player behind a wall long enough -> back to idle
	_player.global_position = Vector3(0, 0, 40)
	_box(Vector3(0, 2, 6), Vector3(30, 4, 0.5))
	await _phys(2)
	for i: int in 60 * 8:
		e.tick(DT)
	eq(e.state, RatEnemy.State.IDLE, "lost target -> idle (%s)" % str(e.debug_log.slice(-4)))
	var p: RatEnemy = _enemy("officer", Vector3(-20, 0, 0), {"patrol": true})
	await _phys(2)
	eq(p.state, RatEnemy.State.PATROL, "patrol spawn -> patrol")
	var start: Vector3 = p.global_position
	for i: int in 90:
		p.tick(DT)
		await tree.physics_frame
	check(p.global_position.distance_to(start) > 1.0, "patrol walks")


func test_hitscan_attack_hurts_player() -> void:
	var e: RatEnemy = _enemy("trooper", Vector3(0, 0, 0), {"skill": 3, "alerted": true})
	_player.global_position = Vector3(0, 0, -6)
	await _phys(2)
	check(e.hit_chance(6.0, 0.0) > 0.9, "close + still target: high hit chance")
	check(e.hit_chance(60.0, 7.0) < 0.15, "far + running target: low hit chance")
	var easy: RatEnemy = _enemy("trooper", Vector3(30, 0, 30), {"skill": 0})
	check(easy.hit_chance(20.0, 0.0) < e.hit_chance(20.0, 0.0), "skill scales accuracy")
	for i: int in 60 * 6:
		e.tick(DT)
	check(_player.hits.size() >= 2, "trooper hit the player %d times" % _player.hits.size())
	if not _player.hits.is_empty():
		check(_player.hits[0]["source"] == e and int(_player.hits[0]["amount"]) >= 3 and int(_player.hits[0]["amount"]) <= 8, "dmg in ref range via take_damage(dmg, self, \"\")")


func test_sewer_melee() -> void:
	var e: RatEnemy = _enemy("sewer", Vector3(0, 0, 0), {"alerted": true})
	_player.global_position = Vector3(0, 0, -8)
	await _phys(2)
	var d0: float = e.global_position.distance_to(_player.global_position)
	for i: int in 60 * 4:
		e.tick(DT)
		await tree.physics_frame
	check(e.global_position.distance_to(_player.global_position) < d0 - 4.0, "sewer rat closes in")
	check(_player.hits.size() > 0, "melee hits")
	eq(str(e.last_attack.get("kind", "")), "melee", "melee attack kind")


func test_panzer_cheeseball() -> void:
	var e: RatEnemy = _enemy("panzer", Vector3(0, 0, 0), {"alerted": true})
	_player.global_position = Vector3(0, 0, -10)
	await _phys(2)
	var balls: int = 0
	for i: int in 60 * 3:
		e.tick(DT)
		balls = maxi(balls, tree.get_nodes_in_group("enemy_projectile").size())
		await tree.physics_frame
		if _player.hits.size() > 0:
			break
	check(balls > 0, "cheeseball launched")
	if check(_player.hits.size() > 0, "cheeseball hurt the player"):
		eq(str(_player.hits[0]["hitbox"]), "splash", "splash hitbox")
		check(int(_player.hits[0]["amount"]) >= 14 and int(_player.hits[0]["amount"]) <= 28, "dmg 14..28")


func test_take_cover() -> void:
	var e: RatEnemy = _enemy("trooper", Vector3(0, 0, 0))
	_player.global_position = Vector3(0, 0, -15)
	_box(Vector3(5, 1.5, -3), Vector3(3, 3, 0.6))   # low wall to the right
	await _phys(2)
	var c: Vector3 = e.find_cover(_player)
	if check(c.is_finite(), "cover found"):
		check(not e.has_los(RatEnemy.target_point(_player) + Vector3.UP * 0.3, c + Vector3.UP), "cover hidden from the player")
		check(c.distance_to(e.global_position) <= 10.5, "cover nearby")
	e.alerted = true
	e.cover_point = c
	e._hold_t = 0.5
	e._set_state(RatEnemy.State.TAKE_COVER)
	for i: int in 60 * 4:
		e.tick(DT)
		await tree.physics_frame
		if e.state != RatEnemy.State.TAKE_COVER:
			break
	check(e.debug_log.has("take_cover->chase"), "reached cover then peeked: %s" % str(e.debug_log.slice(-3)))


func test_boss_phases() -> void:
	var b: RatEnemy = _enemy("boss", Vector3(0, 0, 0), {"alerted": true})
	_player.global_position = Vector3(0, 0, -15)
	await _phys(2)
	eq(b.phase, 1, "phase 1")
	b.take_damage(600, _player, "body")
	eq(b.phase, 2, "phase 2 below 50%")
	eq(b.minions.size(), 2, "summoned 2 sewer rats")
	for m: RatEnemy in b.minions:
		check(m.kind == "sewer" and m.summoned and m.alerted, "minion alerted sewer")
	b.stun(5.0)
	check(b._stun_t <= 1.6, "boss stun shortened")
	b._stun_t = 0.0
	b._pain_t = 0.0
	b._cooldown = 0.0
	b._atk_count = 0
	b._begin_attack()
	for i: int in 60:
		b.tick(DT)
		if str(b.last_attack.get("kind", "")) == "volley":
			break
	eq(str(b.last_attack.get("kind", "")), "volley", "phase 2 cheeseball volley")
	b.take_damage(9999, _player, "body")
	eq(_killed.count("boss"), 1, "boss killed once")
	eq(_killed.size(), 1, "minions die quietly (no score)")
	for m: RatEnemy in b.minions:
		check(m.is_dead(), "minion dead with boss")


func test_spawn_e1m1() -> void:
	var lb: LevelBuilder = LevelBuilder.new()
	_root.add_child(lb)
	check(lb.build_level("e1m1"), "e1m1 builds")
	await _phys(3)
	var es: Array[RatEnemy] = RatEnemySpawner.spawn_in_level(lb, {"auto_tick": false})
	eq(es.size(), lb.enemy_spawns.size(), "one enemy per spawn marker")
	check(es.size() > 0, "e1m1 has enemies")
	eq(RatEnemySpawner.spawn_in_level(lb).size(), es.size(), "spawn idempotent")
	var kinds: Dictionary = {}
	for e: RatEnemy in es:
		kinds[e.kind] = true
		check(lb.is_ancestor_of(e), "enemy under level")
	await _phys(4)
	if es.size() > 0:
		var e: RatEnemy = es[0]
		check(e._nav_ready(), "navmesh map ready")
		var start: Vector3 = e.global_position
		var goal: Vector3 = Vector3.INF
		for o: RatEnemy in es:
			if o != e and o.global_position.distance_to(start) > 8.0 and o.global_position.distance_to(start) < 30.0:
				goal = o.global_position
				break
		if goal.is_finite():
			e.nav.target_position = goal
			await _phys(2)
			e.nav.get_next_path_position()
			var path: PackedVector3Array = e.nav.get_current_navigation_path()
			check(path.size() >= 2, "nav path to another spawn (%d pts)" % path.size())
	print("     e1m1 spawned %d enemies: %s" % [es.size(), str(kinds.keys())])
