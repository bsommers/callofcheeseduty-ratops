extends "res://tests/test_case.gd"
## player-controller tests: movement, damage, ammo/reload, death-once, pickups, headshots, splash, use.

const PlayerScene: String = "res://scenes/player.tscn"

var _world: Node3D = null
var _died: int = 0
var _hurt: Array = []
var _ammo_events: int = 0


class MockEnemy extends StaticBody3D:
	var hits: Array = []
	var stunned: float = 0.0
	func take_damage(amount: int, source: Node, hitbox: String) -> void:
		hits.append({"amount": amount, "source": source, "hitbox": hitbox})
	func stun(t: float) -> void:
		stunned = t
	func total() -> int:
		var s: int = 0
		for h: Dictionary in hits:
			s += int(h["amount"])
		return s


class MockDoor extends StaticBody3D:
	var used: int = 0
	func interact(_by: Node = null) -> void:
		used += 1


class MockLevel extends Node3D:
	var completed: int = 0
	func complete_level(_extra: Dictionary = {}) -> void:
		completed += 1


func before_each() -> void:
	_died = 0
	_hurt = []
	_ammo_events = 0
	var g: Node = autoload("Game")
	g.call("_reset_run")
	g.set("skill", 2)
	_world = Node3D.new()
	_world.name = "PlayerTestWorld"
	tree.root.add_child(_world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	_world.add_child(floor_body)
	var ev: Node = autoload("Events")
	ev.connect("player_died", _on_died)
	ev.connect("player_hurt", _on_hurt)
	ev.connect("ammo_changed", _on_ammo)


func after_each() -> void:
	var ev: Node = autoload("Events")
	ev.disconnect("player_died", _on_died)
	ev.disconnect("player_hurt", _on_hurt)
	ev.disconnect("ammo_changed", _on_ammo)
	if _world != null:
		_world.free()
	autoload("Game").call("_reset_run")


func _on_died() -> void:
	_died += 1


func _on_hurt(d: int) -> void:
	_hurt.append(d)


func _on_ammo(_c: int, _r: int) -> void:
	_ammo_events += 1


func _spawn(at: Vector3 = Vector3.ZERO) -> RatPlayer:
	var p: RatPlayer = (load(PlayerScene) as PackedScene).instantiate() as RatPlayer
	p.use_device_input = false
	p.capture_mouse = false
	p.position = at
	_world.add_child(p)
	return p


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


func _enemy(at: Vector3, width: float = 2.0) -> MockEnemy:
	var e := MockEnemy.new()
	e.collision_layer = 4
	e.add_to_group("enemy")
	var body := CollisionShape3D.new()
	body.name = "Body"
	var bb := BoxShape3D.new()
	bb.size = Vector3(width, 1.4, 0.6)
	body.shape = bb
	body.position.y = 0.7
	e.add_child(body)
	var head := CollisionShape3D.new()
	head.name = "Head"
	var hb := BoxShape3D.new()
	hb.size = Vector3(width, 0.6, 0.6)
	head.shape = hb
	head.position.y = 1.7
	e.add_child(head)
	e.position = at
	_world.add_child(e)
	return e


# ───────────────────────────── tests ─────────────────────────────
func test_scene_structure() -> void:
	var p := _spawn()
	await _frames(2)
	eq(p.collision_layer, 2, "player on layer 2")
	check(p.is_in_group("player"), "group player")
	var cap := (p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	eq(cap.radius, 0.4, "capsule radius")
	eq(cap.height, 1.9, "capsule height")
	check(p.rig != null and p.rig.camera != null, "camera rig built")
	check(p.model != null, "model or placeholder present")
	eq(p.weapons.defs.size(), 5, "five weapons loaded from weapons.json")


func test_movement_walk_sprint_friction() -> void:
	var p := _spawn()
	await _frames(10)
	var z0: float = p.global_position.z
	p.cmd_move = Vector2(0, 1)
	await _frames(60)
	var walked: float = z0 - p.global_position.z
	var walk_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	check(walked > 2.5, "walked forward along -Z (%.2f m)" % walked)
	check(walk_speed <= RatPlayer.WALK_SPEED * 1.02 and walk_speed > RatPlayer.WALK_SPEED * 0.9, "walk speed %.2f" % walk_speed)
	p.cmd_sprint = true
	await _frames(60)
	var sprint_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	check(sprint_speed > RatPlayer.WALK_SPEED * 1.4, "sprint faster (%.2f)" % sprint_speed)
	p.cmd_sprint = false
	p.cmd_move = Vector2.ZERO
	await _frames(40)
	check(Vector2(p.velocity.x, p.velocity.z).length() < 0.1, "friction stops the hero")
	# strafe follows camera yaw
	p.rig.yaw = PI * 0.5   # facing -X
	var x0: float = p.global_position.x
	p.cmd_move = Vector2(0, 1)
	await _frames(30)
	check(p.global_position.x < x0 - 1.0, "forward follows camera yaw")


func test_crouch_and_jump() -> void:
	var p := _spawn()
	await _frames(10)
	p.cmd_crouch = true
	await _frames(2)
	check(p.crouching, "crouched")
	eq(((p.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D).height, 1.3, "crouch capsule 1.3 m")
	p.cmd_move = Vector2(0, 1)
	await _frames(45)
	check(Vector2(p.velocity.x, p.velocity.z).length() <= RatPlayer.CROUCH_SPEED * 1.02, "crouch speed capped")
	p.cmd_move = Vector2.ZERO
	p.cmd_crouch = false
	await _frames(2)
	check(not p.crouching, "stood up")
	await _frames(20)
	p.cmd_jump = true
	await _frames(12)
	check(p.global_position.y > 0.3, "jumped (y=%.2f)" % p.global_position.y)
	await _frames(60)
	check(p.is_on_floor(), "landed")
	eq(p.health, 100, "no fall damage")


func test_damage_and_skill() -> void:
	var p := _spawn()
	await _frames(2)
	eq(p.take_damage(10.0), 10, "alley cat takes full damage")
	eq(p.health, 90, "health 90")
	eq(_hurt, [10], "player_hurt emitted with dmg")
	autoload("Game").set("skill", 0)
	eq(p.take_damage(20.0), 9, "kitten skill dmg_taken 0.45")


func test_death_exactly_once() -> void:
	var p := _spawn()
	await _frames(2)
	p.take_damage(60.0)
	p.take_damage(60.0)
	p.take_damage(60.0)
	p.take_damage(500.0)
	eq(_died, 1, "player_died emitted once")
	check(p.dead, "dead flag")
	eq(p.deaths, 1, "death counter")
	eq(p.take_damage(10.0), 0, "no damage after death")
	# fallback respawn restores the level-start loadout and allows exactly one more death
	p.respawn()
	eq(p.health, 100, "respawn restores health")
	check(not p.dead, "alive again")
	p.take_damage(999.0)
	eq(_died, 2, "second life -> second death signal")


func test_ammo_fire_reload() -> void:
	var p := _spawn()
	await _frames(2)
	var w: RatWeapons = p.weapons
	eq(w.current, 1, "starts with pistol")
	eq(w.loaded(), 12, "pistol mag 12")
	eq(w.reserve(), 4, "reserve 4 (16 hair)")
	check(w.fire(), "fired")
	eq(w.loaded(), 11, "mag 11")
	check(_ammo_events > 0, "ammo_changed emitted")
	check(not w.fire(), "cooldown blocks immediate refire")
	check(w.start_reload(), "reload started")
	await _frames(int(1.3 * 60) + 10)
	w.tick(0.0, false, false)
	eq(w.loaded(), 12, "mag refilled")
	eq(w.reserve(), 3, "reserve 3")
	var lo: Dictionary = p.export_loadout()
	eq(int(lo["ammo"]["hair"]), 15, "export folds mag into pool")
	# empty everything -> auto-switch to claws
	w.mags[1] = 0
	w.ammo["hair"] = 0
	w._cooldown = 0.0
	w.fire()
	eq(w.current, 0, "out of ammo switches to claws")
	check(not w.select(1), "cannot select empty pistol")
	check(w.select(0, true) or w.current == 0, "claws always available")


func test_switch_and_cycle() -> void:
	var p := _spawn()
	await _frames(2)
	var w: RatWeapons = p.weapons
	var ids: Array = []
	var cb := func(id: String) -> void: ids.append(id)
	autoload("Events").connect("weapon_changed", cb)
	check(not w.select(2), "gatling not owned")
	Events.pickup_taken.emit("gatling", 12)
	eq(w.current, 2, "weapon pickup switches up")
	check(w.select(0), "weapon_1 -> claws")
	check(w.cycle(1), "next weapon")
	eq(w.current, 1, "next = pistol")
	check(w.cycle(-1), "prev weapon")
	eq(w.current, 0, "prev = claws")
	w.cycle(-1)
	eq(w.current, 2, "prev wraps to gatling")
	autoload("Events").disconnect("weapon_changed", cb)
	check(ids.has("gatling") and ids.has("claws"), "weapon_changed ids emitted")


func test_hitscan_head_and_body() -> void:
	var p := _spawn()
	var e := _enemy(Vector3(0.5, 0, -10))
	await _frames(4)
	var w: RatWeapons = p.weapons
	p.rig.pitch = 0.0
	w._cooldown = 0.0
	check(w.fire(), "fired at head height")
	check(e.hits.size() == 1, "enemy hit (%d)" % e.hits.size())
	if e.hits.size() == 1:
		eq(e.hits[0]["hitbox"], "head", "head hitbox")
		check(int(e.hits[0]["amount"]) >= roundi(9 * 2.5), "headshot multiplier applied (%d)" % int(e.hits[0]["amount"]))
		check(e.hits[0]["source"] == p, "source is the player")
	p.rig.pitch = -0.09
	await _frames(2)
	w._cooldown = 0.0
	w.fire()
	check(e.hits.size() == 2 and e.hits[1]["hitbox"] == "body", "body hit when aiming lower %s cam=%s" % [str(w.last_shot.get("pos")), str(p.rig.camera.global_position)])
	if e.hits.size() == 2:
		check(int(e.hits[1]["amount"]) <= 24, "body damage within reference range")
	# wall hit leaves a decal
	e.queue_free()
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(10, 6, 0.5)
	cs.shape = bs
	wall.add_child(cs)
	wall.position = Vector3(0, 1, -8)
	_world.add_child(wall)
	await _frames(3)
	w._cooldown = 0.0
	w.fire()
	check(bool(w.last_shot.get("wall", false)), "wall hit")
	check(_world.find_children("BulletDecal", "Decal", true, false).size() >= 1, "bullet decal placed")


func test_melee_claws() -> void:
	var p := _spawn()
	var e := _enemy(Vector3(0, 0, -1.4), 0.8)
	await _frames(3)
	p.weapons.select(0)
	p.weapons._cooldown = 0.0
	check(p.weapons.fire(), "swing")
	eq(e.hits.size(), 1, "claws hit enemy in front")
	if e.hits.size() == 1:
		check(int(e.hits[0]["amount"]) >= 10 and int(e.hits[0]["amount"]) <= 26, "claw dmg 10..26")


func test_yarn_projectile_splash() -> void:
	var p := _spawn()
	var e := _enemy(Vector3(0, 0, -12))
	await _frames(3)
	Events.pickup_taken.emit("yarn_launcher", 4)
	var w: RatWeapons = p.weapons
	eq(w.current, 3, "yarn bomber selected")
	eq(w.loaded(), 4, "4 yarn")
	w._cooldown = 0.0
	check(w.fire(), "launched")
	var ball: Node = w.last_shot.get("projectile", null)
	check(ball is RatYarnBall, "projectile spawned")
	if ball is RatYarnBall:
		eq((ball as RatYarnBall).collision_layer, 8, "projectile on layer 4")
	await _frames(90)
	check(e.hits.size() >= 1, "splash damaged enemy (%d hits)" % e.hits.size())
	if e.hits.size() >= 1:
		eq(e.hits[0]["hitbox"], "splash", "splash hitbox")
		check(int(e.hits[0]["amount"]) >= 13 and int(e.hits[0]["amount"]) <= 95, "splash dmg in range")
	eq(w.loaded(), 3, "yarn spent")


func test_laser_beam() -> void:
	var p := _spawn()
	var e := _enemy(Vector3(0.5, 0, -10))
	await _frames(3)
	Events.pickup_taken.emit("laser", 60)
	var w: RatWeapons = p.weapons
	eq(w.current, 4, "laser selected")
	for i: int in 60:
		w.tick(1.0 / 60.0, true, i == 0)
	check(e.total() >= 50 and e.total() <= 85, "beam 55 dps x head 1.5 (%d)" % e.total())
	check(e.stunned > 0.0, "beam stuns")
	check(w.loaded() <= 47 and w.loaded() >= 45, "14 cells/s used (%d left)" % w.loaded())


func test_pickups() -> void:
	var p := _spawn()
	await _frames(2)
	p.take_damage(50.0)
	Events.pickup_taken.emit("tuna", 25)
	eq(p.health, 75, "tuna heals 25")
	Events.pickup_taken.emit("catnip", 60)
	eq(p.health, 135, "catnip overheals to <=150")
	var before: int = p.weapons.reserve()
	Events.pickup_taken.emit("ammo_box", 25)
	eq(p.weapons.reserve(), before + 25, "ammo box adds 25 hair")
	var g: Node = autoload("Game")
	var lives0: int = int(g.get("lives"))
	Events.pickup_taken.emit("extra_life", 1)
	eq(int(g.get("lives")), lives0 + 1, "extra life")


func test_use_door_and_exit() -> void:
	var lvl := MockLevel.new()
	_world.add_child(lvl)
	var p: RatPlayer = RatPlayer.spawn_in_level(lvl, Transform3D.IDENTITY)
	p.use_device_input = false
	var door := MockDoor.new()
	door.add_to_group("door")
	door.collision_layer = 1 | 64
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 4, 0.3)
	cs.shape = bs
	door.add_child(cs)
	door.position = Vector3(0, 2, -1.5)
	lvl.add_child(door)
	await _frames(4)
	eq(p.use(), "door", "use ray hits door")
	eq(door.used, 1, "door.interact called")
	door.queue_free()
	var exit_area := Area3D.new()
	exit_area.collision_layer = 32
	exit_area.collision_mask = 2
	exit_area.add_to_group("exit_switch")
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(4, 3, 4)
	cs2.shape = bs2
	exit_area.add_child(cs2)
	exit_area.position = Vector3(0, 1.5, -3)
	lvl.add_child(exit_area)
	await _frames(4)
	eq(p.use(), "exit", "use reaches exit switch")
	eq(lvl.completed, 1, "LevelBuilder.complete_level called")


func test_real_level_door_and_exit() -> void:
	var lvl: Node = (load("res://scenes/level_base.tscn") as PackedScene).instantiate()
	_world.add_child(lvl)
	if not check(bool(lvl.call("build_level", "e1m1")), "e1m1 builds"):
		return
	var p: RatPlayer = RatPlayer.spawn_in_level(lvl)
	p.use_device_input = false
	await _frames(4)
	var start: Transform3D = lvl.get("player_start")
	check(p.global_position.distance_to(start.origin) < 0.5, "spawned at player_start")
	# a real door: stand 2 m from it on each side until the use ray hits it
	var used_door: bool = false
	var doors: Array = tree.get_nodes_in_group("door")
	check(doors.size() > 0, "e1m1 has doors")
	for d: Node in doors:
		if (d.get("lock") as String) != "":
			continue
		var dp: Vector3 = (d as Node3D).global_position
		for off: Vector3 in [Vector3(0, 0, 2), Vector3(0, 0, -2), Vector3(2, 0, 0), Vector3(-2, 0, 0)]:
			p.global_position = Vector3(dp.x, start.origin.y, dp.z) + off
			p.rig.yaw = atan2(off.x, off.z)
			p.rig.pitch = 0.0
			await _frames(2)
			if p.use() == "door":
				used_door = true
				break
		break
	check(used_door, "use opens a real RatDoor")
	var done: Array = []
	var cb := func(s: Dictionary) -> void: done.append(s)
	Events.level_completed.connect(cb)
	var ex: Node3D = lvl.get("exit_area")
	if check(ex != null, "exit area exists"):
		p.global_position = Vector3(ex.global_position.x, start.origin.y, ex.global_position.z)
		await _frames(3)
		eq(p.use(), "exit", "use at real exit switch")
	Events.level_completed.disconnect(cb)
	eq(done.size(), 1, "Events.level_completed emitted once via LevelBuilder.complete_level")
	if done.size() == 1:
		eq(str(done[0].get("id", "")), "e1m1", "stats carry level id")
	var lo: Dictionary = autoload("Game").get("loadout")
	check(lo.has("ammo") and lo.has("owned"), "loadout written to Game at exit")


func test_can_take() -> void:
	var p := _spawn()
	await _frames(2)
	check(not p.can_take("tuna"), "full health refuses tuna")
	check(p.can_take("catnip"), "catnip allowed up to 150")
	check(p.can_take("ammo_box"), "ammo below cap")
	p.weapons.ammo["hair"] = 99
	check(not p.can_take("ammo_clip"), "ammo at cap refused")
	check(p.can_take("cheddar_wedge"), "treasure always")
