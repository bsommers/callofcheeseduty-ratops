class_name RatPlayer
extends CharacterBody3D
## Major Marmalade, the playable hero (ARCHITECTURE sections 4 and 6). Owner: player-controller.
## CS-style ground movement (accel/friction, sprint, crouch, jump; no fall damage, no head bob),
## over-the-shoulder camera (RatPlayerCamera), weapons (RatWeapons), `use` interaction
## (doors, pushwalls, exit switch), pickups (applies Events.pickup_taken from the level's Area3Ds),
## health/lives with exactly one Events.player_died per death. Reads Game.loadout on spawn.
## Device input is read only when `use_device_input`; tests drive the `cmd_*` fields instead.

const SCENE_PATH: String = "res://scenes/player.tscn"
const HERO_MODEL: String = "res://assets/models/hero.glb"

# Reference sim/player.js: WALK 3.4, RUN 5.6 cells/s, ACCEL 16, FRICTION 12. Cells are 4 m in this
# game, which would give 13.6 m/s; retuned to character scale (run/walk ratio 1.65 kept).
const WALK_SPEED: float = 4.4
const SPRINT_SPEED: float = 7.25
const CROUCH_SPEED: float = 2.2
const ADS_SPEED_MULT: float = 0.6
const ACCEL: float = 16.0
const FRICTION: float = 12.0
const AIR_ACCEL: float = 2.5
const JUMP_VELOCITY: float = 4.6
const STAND_HEIGHT: float = 1.9
const CROUCH_HEIGHT: float = 1.3
const RADIUS: float = 0.4
const STRIDE_WALK: float = 0.95
const STRIDE_SPRINT: float = 1.35
const USE_REACH: float = 2.6
const RESPAWN_DELAY: float = 2.5

const LAYER_PLAYER: int = 2
const MASK_MOVE: int = 1 | 4 | 64          # world, enemy, door
const MASK_USE: int = 1 | 32 | 64          # world, trigger, door

@export var use_device_input: bool = true
@export var capture_mouse: bool = true

var health: int = 100
var max_health: int = 100
var dead: bool = false
var crouching: bool = false
var sprinting: bool = false
## Emitted deaths in this player's lifetime (test hook; must rise by exactly 1 per death).
var deaths: int = 0

# Command inputs (written from devices each physics frame, or directly by tests/AI).
var cmd_move: Vector2 = Vector2.ZERO       # x = right, y = forward
var cmd_sprint: bool = false
var cmd_crouch: bool = false
var cmd_jump: bool = false
var cmd_fire: bool = false
var cmd_fire_pressed: bool = false
var cmd_aim: bool = false

var rig: RatPlayerCamera = null
var weapons: RatWeapons = null
var model: Node3D = null

var _shape: CapsuleShape3D = null
var _shape_node: CollisionShape3D = null
var _anim: AnimationPlayer = null
var _step_acc: float = 0.0
var _start_xform: Transform3D = Transform3D.IDENTITY
var _respawn_t: float = -1.0
var _was_on_floor: bool = true


func _ready() -> void:
	add_to_group("player")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_MOVE
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	_shape_node = get_node_or_null("Collision") as CollisionShape3D
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		_shape_node.name = "Collision"
		add_child(_shape_node)
	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape.height = STAND_HEIGHT
	_shape_node.shape = _shape
	_shape_node.position = Vector3(0.0, STAND_HEIGHT * 0.5, 0.0)
	rig = get_node_or_null("CameraRig") as RatPlayerCamera
	if rig == null:
		rig = RatPlayerCamera.new()
		rig.name = "CameraRig"
		rig.body = self
		add_child(rig)
	rig.body = self
	rig.yaw = rotation.y
	weapons = get_node_or_null("Weapons") as RatWeapons
	if weapons == null:
		weapons = RatWeapons.new()
		weapons.name = "Weapons"
		add_child(weapons)
	weapons.position = Vector3(0.35, 1.35, -0.55)
	weapons.player = self
	weapons.aim_camera = rig.camera
	if model == null:
		_load_default_model()
	Events.pickup_taken.connect(_on_pickup_taken)
	Events.level_completed.connect(_on_level_completed)
	if Events.has_signal("paused_changed"):
		Events.paused_changed.connect(_on_paused)
	_start_xform = global_transform
	apply_loadout(_game_loadout())
	if use_device_input and capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Spawn the hero into a built level at its `player_start` (LevelBuilder) and return it.
static func spawn_in_level(level: Node, xform: Variant = null) -> RatPlayer:
	var ps: PackedScene = load(SCENE_PATH) as PackedScene
	var p: RatPlayer = ps.instantiate() as RatPlayer if ps != null else RatPlayer.new()
	var t: Transform3D = Transform3D.IDENTITY
	if xform is Transform3D:
		t = xform
	elif level != null and "player_start" in level:
		t = level.get("player_start")
	p.transform = t
	if level != null:
		level.add_child(p)
	if p.rig != null:
		p.rig.yaw = t.basis.get_euler().y
	p._start_xform = t
	return p


# ───────────────────────────── model seam ─────────────────────────────
## Swap the visual model (PackedScene or Node3D). The capsule collision never changes.
func set_model(m: Variant) -> void:
	if model != null and is_instance_valid(model):
		model.queue_free()
	model = null
	_anim = null
	var n: Node3D = null
	if m is PackedScene:
		n = (m as PackedScene).instantiate() as Node3D
	elif m is Node3D:
		n = m
	if n == null:
		return
	n.name = "Model"
	add_child(n)
	model = n
	_anim = n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_set_shadow_casting(n)


func _set_shadow_casting(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c: Node in n.get_children():
		_set_shadow_casting(c)


func _load_default_model() -> void:
	if ResourceLoader.exists(HERO_MODEL):
		var ps: PackedScene = load(HERO_MODEL) as PackedScene
		if ps != null:
			set_model(ps)
			if model != null:
				model.rotation.y = 0.0   # hero.glb already faces -Z
				return
	set_model(_placeholder())


func _placeholder() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = RADIUS
	cm.height = STAND_HEIGHT
	mi.mesh = cm
	mi.position.y = STAND_HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.52, 0.16)
	mat.roughness = 0.85
	mi.material_override = mat
	root.add_child(mi)
	var nose := MeshInstance3D.new()
	nose.name = "Facing"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.18, 0.25)
	nose.mesh = bm
	nose.position = Vector3(0.0, 1.6, -0.38)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.98, 0.9, 0.8)
	nose.material_override = m2
	root.add_child(nose)
	return root


# ───────────────────────────── loadout / state ─────────────────────────────
func _game() -> Node:
	return get_node_or_null("/root/Game")


func _game_loadout() -> Dictionary:
	var g: Node = _game()
	if g != null and g.get("loadout") is Dictionary and not (g.get("loadout") as Dictionary).is_empty():
		return g.get("loadout")
	return {"health": int(Defs.START["health"]), "ammo": (Defs.START["ammo"] as Dictionary).duplicate(true),
		"owned": (Defs.START["owned"] as Array).duplicate(), "weapon": int(Defs.START["weapon"])}


func lives() -> int:
	var g: Node = _game()
	return int(g.get("lives")) if g != null else int(Defs.START["lives"])


func apply_loadout(lo: Dictionary) -> void:
	health = clampi(int(lo.get("health", Defs.START["health"])), 1, 999)
	max_health = maxi(100, health)
	dead = false
	if weapons != null:
		weapons.apply_loadout(lo)
	Events.health_changed.emit(health, lives())


func export_loadout() -> Dictionary:
	var d: Dictionary = weapons.export_loadout() if weapons != null else {}
	d["health"] = health
	return d


func _on_level_completed(_stats: Dictionary) -> void:
	var g: Node = _game()
	if g != null and not dead:
		g.set("loadout", export_loadout())


func _on_paused(is_paused: bool) -> void:
	if use_device_input and capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED


# ───────────────────────────── damage / death ─────────────────────────────
## Enemy attacks call this. Skill scales damage (reference dmgTaken). Returns damage applied.
func take_damage(amount: float, _source: Node = null, _hitbox: String = "") -> int:
	if dead or amount <= 0.0:
		return 0
	var g: Node = _game()
	var sk: int = int(g.get("skill")) if g != null else int(Defs.DEFAULT_SKILL)
	var mult: float = float(Defs.SKILLS[clampi(sk, 0, Defs.SKILLS.size() - 1)].get("dmg_taken", 1.0))
	var dmg: int = maxi(1, roundi(amount * mult))
	health = maxi(0, health - dmg)
	Events.player_hurt.emit(dmg)
	Events.health_changed.emit(health, lives())
	Events.sfx.emit("player_hurt", global_position)
	if health <= 0:
		_die()
	return dmg


func _die() -> void:
	if dead:
		return
	dead = true
	deaths += 1
	velocity = Vector3.ZERO
	if weapons != null:
		weapons._stop_beam()
	Events.sfx.emit("player_die", global_position)
	_play_anim(["death_a", "death_b", "death"])
	_respawn_t = RESPAWN_DELAY
	Events.player_died.emit()


## Fallback when nobody restarts the level (Game not PLAYING / player outside the level root):
## back to the spawn point with the level-start loadout Game restored.
func respawn() -> void:
	global_transform = _start_xform
	velocity = Vector3.ZERO
	if rig != null:
		rig.yaw = _start_xform.basis.get_euler().y
		rig.pitch = 0.0
	set_crouch(false)
	apply_loadout(_game_loadout())


func heal(n: int, cap: int = 100) -> bool:
	if dead or health >= cap:
		return false
	health = mini(cap, health + n)
	max_health = maxi(max_health, cap)
	Events.health_changed.emit(health, lives())
	return true


# ───────────────────────────── pickups ─────────────────────────────
## Reference rule: health items are refused at full health, ammo at the cap. Pickups may ask before taking.
func can_take(kind: String) -> bool:
	if dead:
		return false
	var it: Dictionary = Defs.item(kind)
	if it.has("heal") and not (it.has("ammo") or it.has("weapon") or it.has("life")):
		return health < int(it.get("max", 100))
	if it.has("ammo") and not it.has("weapon") and weapons != null:
		var t: String = str((it["ammo"] as Array)[0])
		var held: int = int(weapons.ammo.get(t, 0))
		for i: int in weapons.defs.size():
			if weapons.ammo_type(i) == t and weapons.has_mag(i):
				held += weapons.mags[i]
		return held < weapons.ammo_max(t)
	return true


## The level's pickup Area3D emits Events.pickup_taken(item_id, amount) and frees itself; apply the effect.
func _on_pickup_taken(kind: String, amount: int) -> void:
	if dead or not is_inside_tree():
		return
	var it: Dictionary = Defs.item(kind)
	if it.is_empty():
		return
	if it.has("heal"):
		heal(int(it["heal"]), int(it.get("max", 100)))
	if it.has("life"):
		var g: Node = _game()
		if g != null:
			g.set("lives", int(g.get("lives")) + int(it["life"]))
		Events.health_changed.emit(health, lives())
	if it.has("ammo") and weapons != null:
		var a: Array = it["ammo"]
		weapons.add_ammo(str(a[0]), int(a[1]) if amount <= 0 else amount)
	if it.has("weapon") and weapons != null:
		weapons.give_weapon(int(it["weapon"]))


# ───────────────────────────── crouch ─────────────────────────────
func set_crouch(on: bool) -> bool:
	if on == crouching:
		return true
	if not on and not _can_stand():
		return false
	crouching = on
	var h: float = CROUCH_HEIGHT if on else STAND_HEIGHT
	_shape.height = h
	_shape_node.position.y = h * 0.5
	return true


func _can_stand() -> bool:
	if not is_inside_tree():
		return true
	var probe := CapsuleShape3D.new()
	probe.radius = RADIUS - 0.02
	probe.height = STAND_HEIGHT - CROUCH_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = 1 | 64
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (CROUCH_HEIGHT + probe.height * 0.5 + 0.02))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ───────────────────────────── per-frame ─────────────────────────────
func _read_device_input() -> void:
	cmd_move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	cmd_sprint = Input.is_action_pressed("sprint")
	cmd_crouch = Input.is_action_pressed("crouch")
	cmd_jump = Input.is_action_just_pressed("jump")
	cmd_fire = Input.is_action_pressed("fire")
	cmd_fire_pressed = Input.is_action_just_pressed("fire")
	cmd_aim = Input.is_action_pressed("aim")
	if weapons != null:
		for i: int in 5:
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				weapons.select(i)
		if Input.is_action_just_pressed("next_weapon"):
			weapons.cycle(1)
		if Input.is_action_just_pressed("prev_weapon"):
			weapons.cycle(-1)
		if Input.is_action_just_pressed("reload"):
			weapons.start_reload()
	if Input.is_action_just_pressed("use"):
		use()


func _unhandled_input(event: InputEvent) -> void:
	if use_device_input and capture_mouse and event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if dead:
		_respawn_t -= delta
		if _respawn_t <= 0.0 and _respawn_t > -1.0e6:
			_respawn_t = -1.0e7
			respawn()
		if not is_on_floor():
			velocity.y -= _gravity() * delta
			move_and_slide()
		return
	if use_device_input:
		_read_device_input()
	if cmd_crouch != crouching:
		set_crouch(cmd_crouch)
	var aiming: bool = cmd_aim
	sprinting = cmd_sprint and not crouching and not aiming and cmd_move.y > 0.1
	var top: float = SPRINT_SPEED if sprinting else (CROUCH_SPEED if crouching else WALK_SPEED)
	if aiming and not crouching:
		top *= ADS_SPEED_MULT
	var fwd: Vector3 = rig.flat_forward() if rig != null else -global_transform.basis.z
	var right: Vector3 = rig.flat_right() if rig != null else global_transform.basis.x
	var mv: Vector2 = cmd_move.limit_length(1.0)
	var wish: Vector3 = (right * mv.x + fwd * mv.y) * top
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var on_floor: bool = is_on_floor()
	if on_floor:
		var rate: float = ACCEL if mv.length() > 0.01 else FRICTION
		hv = hv.lerp(wish, 1.0 - exp(-rate * delta))
		if cmd_jump and not crouching:
			velocity.y = JUMP_VELOCITY
			Events.sfx.emit("jump", global_position)
	else:
		hv = hv.lerp(wish, 1.0 - exp(-AIR_ACCEL * delta)) if mv.length() > 0.01 else hv
		velocity.y -= _gravity() * delta
	cmd_jump = false
	velocity.x = hv.x
	velocity.z = hv.z
	var before: Vector3 = global_position
	move_and_slide()
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_footsteps(moved, on_floor)
	if on_floor and not _was_on_floor:
		Events.sfx.emit("land", global_position)
	_was_on_floor = is_on_floor()
	if rig != null:
		rig.aiming = aiming
		rig.crouch_amount = 1.0 if crouching else 0.0
	if weapons != null:
		weapons.move_fraction = Vector2(velocity.x, velocity.z).length() / WALK_SPEED
		weapons.crouched = crouching
		weapons.airborne = not is_on_floor()
		weapons.aiming = aiming
		if rig != null:
			rig.sync_rotation()
		weapons.tick(delta, cmd_fire, cmd_fire_pressed)
		if rig != null:
			rig.recoil = weapons.recoil
	cmd_fire_pressed = false
	_animate()


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _footsteps(moved: float, on_floor: bool) -> void:
	if not on_floor or moved <= 0.0:
		return
	_step_acc += moved
	var stride: float = STRIDE_SPRINT if sprinting else STRIDE_WALK
	if _step_acc >= stride:
		_step_acc -= stride
		var n: String = "footstep_sprint" if sprinting else ("footstep_crouch" if crouching else "footstep")
		Events.sfx.emit(n, global_position)


func _play_anim(names: Array) -> void:
	if _anim == null:
		return
	for want: String in names:
		for a: String in _anim.get_animation_list():
			if a == want or a.ends_with("|" + want) or a.ends_with("/" + want):
				if _anim.current_animation != a:
					_anim.play(a, 0.15)
				return


func _animate() -> void:
	if _anim == null:
		return
	var sp: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_play_anim(["jump", "fall"] if velocity.y > 0.0 else ["fall", "jump"])
	elif crouching:
		_play_anim(["crouch_walk"] if sp > 0.3 else ["crouch_idle"])
	elif cmd_aim:
		_play_anim(["aim_walk", "walk"] if sp > 0.3 else ["aim_idle", "idle"])
	elif sp > SPRINT_SPEED * 0.8:
		_play_anim(["sprint", "run"])
	elif sp > WALK_SPEED * 0.6:
		_play_anim(["run", "walk"])
	elif sp > 0.3:
		_play_anim(["walk"])
	else:
		_play_anim(["idle"])


# ───────────────────────────── interaction ─────────────────────────────
## Press `use`: ray along the view from chest height; doors/pushwalls get interact(self); the exit
## switch completes the level. Standing inside the exit trigger also counts. Returns what was used.
func use() -> String:
	if dead or not is_inside_tree():
		return ""
	var origin: Vector3 = global_position + Vector3.UP * (1.0 if crouching else 1.4)
	var dir: Vector3 = -global_transform.basis.z
	if rig != null and rig.camera != null and rig.camera.is_inside_tree():
		dir = -rig.camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * USE_REACH, MASK_USE, [get_rid()])
	q.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var r: Dictionary = space.intersect_ray(q)
	if not r.is_empty():
		var got: String = _use_node(r["collider"] as Node)
		if got != "":
			return got
	# flat probe at chest height (camera pitched far up/down still opens the door in front)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	if flat.length() > 0.1:
		q = PhysicsRayQueryParameters3D.create(origin, origin + flat * USE_REACH, MASK_USE, [get_rid()])
		q.collide_with_areas = true
		r = space.intersect_ray(q)
		if not r.is_empty():
			var got2: String = _use_node(r["collider"] as Node)
			if got2 != "":
				return got2
	# inside the exit trigger volume?
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.5
	sq.shape = sph
	sq.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP)
	sq.collision_mask = 32
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	for hit: Dictionary in space.intersect_shape(sq, 8):
		var got3: String = _use_node(hit["collider"] as Node)
		if got3 == "exit":
			return got3
	Events.sfx.emit("use_nothing", global_position)
	return ""


func _use_node(n: Node) -> String:
	var cur: Node = n
	var depth: int = 0
	while cur != null and depth < 6:
		if cur.is_in_group("exit_switch"):
			_trigger_exit(cur)
			return "exit"
		if (cur.is_in_group("door") or cur.is_in_group("pushwall")) and cur.has_method("interact"):
			cur.call("interact", self)
			return "door" if cur.is_in_group("door") else "pushwall"
		cur = cur.get_parent()
		depth += 1
	return ""


func _trigger_exit(sw: Node) -> void:
	var cur: Node = sw
	while cur != null:
		if cur.has_method("complete_level") and cur != _game():
			Events.sfx.emit("exit_switch", global_position)
			var g: Node = _game()
			if g != null:
				g.set("loadout", export_loadout())
			cur.call("complete_level")
			return
		cur = cur.get_parent()
	# no LevelBuilder ancestor: fall back to the signal Game listens to
	Events.level_completed.emit({})
