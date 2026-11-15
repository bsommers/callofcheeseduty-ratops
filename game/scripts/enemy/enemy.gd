class_name RatEnemy
extends CharacterBody3D
## RAT OPS enemy (owner: enemy-ai). One script for every kind in res://data/enemies.json
## (mouse, trooper = SMG rat, officer, sewer, panzer, boss "Der Große Käse").
## Behaviour port of reference/kasekrieg/sim/enemies.js made 3D and cover-aware:
##   state machine idle / patrol / alert / chase / attack / take_cover / retreat / dead
##   (+ pain flinch and laser stun as timers that pause the machine),
##   vision cone + LOS raycast, hearing via Events.noise, NavigationAgent3D on the level navmesh
##   (direct steering fallback), cover selection, skill-scaled reaction delay and accuracy,
##   melee (sewer), cheeseball projectiles (panzer, boss), boss phase 2 (volleys, speed, summons).
## Damage seam: take_damage(amount, source, hitbox) -> int. Hitbox "head" (Area3D named "Head",
## group hitbox_head, plus meta head_y). Emits Events.enemy_alerted / enemy_hurt / enemy_killed.
## Hurts the player through player.take_damage(dmg, self, "") (group `player`).
## Model seam: set_model(path | PackedScene | Node3D); clips played by name with fallbacks.

signal state_changed(new_state: int, old_state: int)
signal died(kind: String)
signal model_ready(model: Node3D)

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, TAKE_COVER, RETREAT, DEAD }
const STATE_NAMES: PackedStringArray = ["idle", "patrol", "alert", "chase", "attack", "take_cover", "retreat", "dead"]

const DATA_PATH: String = "res://data/enemies.json"
const MODEL_FMT: String = "res://assets/models/rat_%s.glb"
const PICKUP_SCRIPT: String = "res://scripts/level/rat_pickup.gd"
const PROJECTILE_SCRIPT: String = "res://scripts/enemy/enemy_projectile.gd"
const LAYER_ENEMY: int = 4
const MASK_MOVE: int = 1 | 2 | 4 | 64      # world, player, enemy, door
const MASK_LOS: int = 1 | 64               # world, door
const LOOP_CLIPS: PackedStringArray = ["idle", "walk", "run", "aim_idle", "charge", "take_cover"]
const ANIM_FALLBACK: Dictionary = {
	"idle": ["aim_idle"], "walk": ["run", "idle"], "run": ["walk", "idle"], "aim_idle": ["idle"],
	"fire": ["aim_idle", "idle"], "reload": ["aim_idle", "idle"], "hurt": ["idle"],
	"death_a": ["death_b", "hurt", "idle"], "death_b": ["death_a", "hurt", "idle"],
	"take_cover": ["aim_idle", "idle"], "melee": ["fire", "aim_idle", "idle"], "taunt": ["aim_idle", "idle"],
}
const TINT: Dictionary = {
	"mouse": Color(0.55, 0.55, 0.58), "trooper": Color(0.42, 0.47, 0.38), "officer": Color(0.15, 0.15, 0.17),
	"sewer": Color(0.12, 0.11, 0.1), "panzer": Color(0.35, 0.36, 0.4), "boss": Color(0.9, 0.85, 0.7),
}

static var _data: Dictionary = {}

@export var kind: String = "mouse"
@export var patrol: bool = false
## Skip the brain (tests drive tick() by hand).
@export var auto_tick: bool = true

var def: Dictionary = {}
var hp: int = 1
var max_hp: int = 1
var state: int = State.IDLE
var alerted: bool = false
var target: Node3D = null
var last_seen: Vector3 = Vector3.INF
var phase: int = 1
var summoned: bool = false
var boss: RatEnemy = null
var minions: Array[RatEnemy] = []
var skill: int = 2
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Multiplier applied here to "head" hits. 1.0 because RatWeapons already multiplies (x2.5) before calling.
var head_receive_mult: float = 1.0
var height: float = 1.7
var radius: float = 0.4
var speed: float = 2.0
var pref_dist: float = 12.0
var cover_point: Vector3 = Vector3.INF
var model: Node3D = null
var nav: NavigationAgent3D = null
var head_area: Area3D = null
var last_attack: Dictionary = {}
var debug_log: PackedStringArray = []

var _configured: bool = false
var _fixed_yaw: float = NAN
var _killed: bool = false
var _t: float = 0.0
var _react_t: float = 0.0
var _cooldown: float = 0.0
var _pain_t: float = 0.0
var _pain_sfx_t: float = 0.0
var _stun_t: float = 0.0
var _stun_immune: float = 0.0
var _sense_t: float = 0.0
var _lost_t: float = 0.0
var _target_t: float = 0.0
var _summon_t: float = 0.0
var _muzzle_t: float = 0.0
var _windup_t: float = 0.0
var _shots_left: int = 0
var _shot_t: float = 0.0
var _atk_count: int = 0
var _hold_t: float = 0.0
var _patrol_a: Vector3 = Vector3.ZERO
var _patrol_b: Vector3 = Vector3.ZERO
var _patrol_to_b: bool = true
var _patrol_ready: bool = false
var _sees: bool = false
var _anim: AnimationPlayer = null
var _clips: Dictionary = {}
var _anim_cur: String = ""
var _flash: OmniLight3D = null
var _body: CollisionShape3D = null


# ───────────────────────────── data ─────────────────────────────
static func data() -> Dictionary:
	if _data.is_empty():
		var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var j: Variant = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_data = j
		if _data.is_empty():
			push_warning("RatEnemy: %s missing/invalid, using built-in fallback" % DATA_PATH)
			_data = {"kinds": {"mouse": {"hp": 25, "speed": 1.94, "height": 1.4, "pain_chance": 0.85, "reaction": [0.5, 1.0],
				"pref_dist": 20.0, "head_frac": 0.8, "attack": {"kind": "hitscan", "dmg": [3, 9], "shots": 1, "gap": 0.0,
				"windup": 0.4, "cooldown": [1.2, 2.0], "range": 56.0}, "cover": true, "drop": "ammo_clip", "sfx": {}}}}
	return _data


static func kind_def(k: String) -> Dictionary:
	var kinds: Dictionary = data().get("kinds", {})
	return kinds.get(k, kinds.get("mouse", {}))


static func tuning(section: String) -> Dictionary:
	return data().get(section, {})


static func ensure_signals() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var ev: Node = loop.root.get_node_or_null("Events") if loop != null else null
	if ev == null:
		return
	for s: String in ["enemy_alerted", "enemy_hurt"]:
		if not ev.has_signal(s):
			ev.add_user_signal(s, [{"name": "kind", "type": TYPE_STRING}, {"name": "pos", "type": TYPE_VECTOR3}])
	if not ev.has_signal("noise"):
		ev.add_user_signal("noise", [{"name": "pos", "type": TYPE_VECTOR3}, {"name": "radius", "type": TYPE_FLOAT}])


static func _events() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Events") if loop != null else null


static func _emit(sig: String, args: Array) -> void:
	var ev: Node = _events()
	if ev != null and ev.has_signal(sig):
		ev.callv("emit_signal", [sig] + args)


func _sfx(key: String) -> void:
	var name_: String = str((def.get("sfx", {}) as Dictionary).get(key, ""))
	if name_ != "":
		_emit("sfx", [name_, global_position if is_inside_tree() else Vector3.ZERO])


# ───────────────────────────── setup ─────────────────────────────
## Configure for a kind before (or after) entering the tree. opts: patrol, alerted, summoned, boss, skill, seed, model.
func configure(k: String, opts: Dictionary = {}) -> void:
	kind = k
	def = kind_def(k)
	patrol = bool(opts.get("patrol", patrol))
	summoned = bool(opts.get("summoned", false))
	if opts.get("boss", null) is RatEnemy:
		boss = opts["boss"]
	if opts.has("yaw"):
		_fixed_yaw = float(opts["yaw"])
		rotation.y = _fixed_yaw
	if opts.has("seed"):
		rng.seed = int(opts["seed"])
	else:
		rng.randomize()
	skill = int(opts.get("skill", _game_skill()))
	var sk: Dictionary = _skill_def()
	max_hp = maxi(1, roundi(float(def.get("hp", 25)) * float(sk.get("enemy_hp", 1.0))))
	hp = max_hp
	height = float(def.get("height", 1.7))
	radius = float(def.get("radius", 0.4))
	speed = float(def.get("speed", 2.0))
	pref_dist = float(def.get("pref_dist", 12.0))
	phase = 1
	_killed = false
	_build_nodes()
	set_meta("head_y", height * float(def.get("head_frac", 0.82)))
	set_meta("enemy_kind", kind)
	_configured = true
	var mp: Variant = opts.get("model", null)
	set_model(mp if mp != null else MODEL_FMT % str(def.get("model", "rat_" + k)).trim_prefix("rat_"))
	if bool(opts.get("alerted", false)):
		alerted = true
		_set_state(State.CHASE)


func _ready() -> void:
	if not _configured and _demo_requested():
		var d: Node = (load("res://scripts/enemy/enemy_demo.gd") as Script).new() as Node
		d.name = "EnemyDemo"
		get_parent().add_child.call_deferred(d)
		queue_free()
		return
	ensure_signals()
	add_to_group("enemy")
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_MOVE
	if not _configured:
		configure(kind)
	var ev: Node = _events()
	if ev != null and ev.has_signal("noise") and not ev.is_connected("noise", _on_noise):
		ev.connect("noise", _on_noise)
	set_physics_process(auto_tick)
	if patrol and state == State.IDLE:
		_set_state(State.PATROL)
	call_deferred("_face_open_direction")


## shot.sh demo: enemy.tscn loaded as a bare scene with --enemy_demo=<level> in the user args.
func _demo_requested() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--enemy_demo="):
			return true
	return false


func _exit_tree() -> void:
	var ev: Node = _events()
	if ev != null and ev.has_signal("noise") and ev.is_connected("noise", _on_noise):
		ev.disconnect("noise", _on_noise)


func _build_nodes() -> void:
	_body = get_node_or_null("Body") as CollisionShape3D
	if _body == null:
		_body = CollisionShape3D.new()
		_body.name = "Body"
		add_child(_body)
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0 + 0.01)
	_body.shape = cap
	_body.position = Vector3(0, height * 0.5, 0)
	head_area = get_node_or_null("Head") as Area3D
	if head_area == null:
		head_area = Area3D.new()
		head_area.name = "Head"
		add_child(head_area)
		var hs: CollisionShape3D = CollisionShape3D.new()
		hs.name = "HeadShape"
		hs.shape = SphereShape3D.new()
		head_area.add_child(hs)
	head_area.collision_layer = LAYER_ENEMY
	head_area.collision_mask = 0
	head_area.monitoring = false
	head_area.monitorable = true
	head_area.add_to_group("hitbox_head")
	head_area.set_meta("hitbox", "head")
	head_area.set_meta("enemy", self)
	var hr: float = clampf(height * 0.11, 0.13, 0.4)
	head_area.position = Vector3(0, height - hr * 1.1, -radius * 0.25)
	for c: Node in head_area.get_children():
		if c is CollisionShape3D:
			var hs2: SphereShape3D = SphereShape3D.new()   # per instance: scene sub-resources are shared
			hs2.radius = hr
			(c as CollisionShape3D).shape = hs2
	nav = get_node_or_null("Nav") as NavigationAgent3D
	if nav == null:
		nav = NavigationAgent3D.new()
		nav.name = "Nav"
		add_child(nav)
	nav.radius = radius
	nav.height = height
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.8
	nav.avoidance_enabled = false
	_flash = get_node_or_null("MuzzleFlash") as OmniLight3D
	if _flash == null:
		_flash = OmniLight3D.new()
		_flash.name = "MuzzleFlash"
		add_child(_flash)
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.light_energy = 4.0
	_flash.omni_range = 5.0
	_flash.shadow_enabled = false
	_flash.position = Vector3(0.25, height * 0.68, -radius - 0.45)
	_flash.visible = false


func _game() -> Node:
	return get_node_or_null("/root/Game") if is_inside_tree() else _autoload("Game")


static func _autoload(n: String) -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(n) if loop != null else null


func _game_skill() -> int:
	var g: Node = _autoload("Game")
	if g != null and "skill" in g:
		return int(g.get("skill"))
	return 2


func _skill_def() -> Dictionary:
	var skills: Array = Defs.SKILLS
	return skills[clampi(skill, 0, skills.size() - 1)] if not skills.is_empty() else {}


# ───────────────────────────── model / animation ─────────────────────────────
## Swap the visual model: res path (.glb/.tscn), PackedScene or Node3D. Missing -> capsule placeholder.
func set_model(m: Variant) -> void:
	if model != null and is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = null
	_anim = null
	_clips.clear()
	_anim_cur = ""
	var n: Node3D = null
	if m is String and str(m) != "" and ResourceLoader.exists(str(m)):
		var ps: PackedScene = load(str(m)) as PackedScene
		if ps != null:
			n = ps.instantiate() as Node3D
	elif m is PackedScene:
		n = (m as PackedScene).instantiate() as Node3D
	elif m is Node3D:
		n = m
	if n == null:
		n = _placeholder()
	n.name = "Model"
	add_child(n)
	model = n
	for mi: Node in n.find_children("*_LOD1", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	_anim = n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for a: String in _anim.get_animation_list():
			var base: String = a.get_slice("|", a.get_slice_count("|") - 1).get_slice("/", a.get_slice_count("/") - 1).to_lower()
			if not _clips.has(base):
				_clips[base] = a
			if base in LOOP_CLIPS:
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play_anim("idle")
	model_ready.emit(n)


func is_placeholder() -> bool:
	return model != null and model.has_meta("placeholder")


func _placeholder() -> Node3D:
	var root: Node3D = Node3D.new()
	root.set_meta("placeholder", true)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = TINT.get(kind, Color(0.5, 0.5, 0.5))
	mat.roughness = 0.8
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = radius
	cm.height = height * 0.86
	body.mesh = cm
	body.position.y = height * 0.43
	body.material_override = mat
	root.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = clampf(height * 0.11, 0.13, 0.4)
	sm.height = sm.radius * 2.0
	head.mesh = sm
	head.position = Vector3(0, height - sm.radius * 1.1, -radius * 0.25)
	head.material_override = mat
	root.add_child(head)
	var gun: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.08, 0.1, 0.6)
	gun.mesh = bm
	gun.position = Vector3(0.25, height * 0.62, -radius - 0.15)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.1, 0.1, 0.1)
	gm.metallic = 0.8
	gun.material_override = gm
	root.add_child(gun)
	return root


func has_clip(clip: String) -> bool:
	return _clips.has(clip)


## Play a clip by name; walks ANIM_FALLBACK when the model lacks it. Returns the clip actually played ("" if none).
func play_anim(clip: String, restart: bool = false, blend: float = 0.15) -> String:
	if _anim == null:
		_anim_cur = clip
		return ""
	var pick: String = clip
	if not _clips.has(pick):
		pick = ""
		for alt: String in ANIM_FALLBACK.get(clip, []):
			if _clips.has(alt):
				pick = alt
				break
	if pick == "":
		return ""
	if pick == _anim_cur and not restart and _anim.is_playing():
		return pick
	_anim_cur = pick
	_anim.play(str(_clips[pick]), blend)
	if restart:
		_anim.seek(0.0, true)
	return pick


func current_anim() -> String:
	return _anim_cur


# ───────────────────────────── state machine ─────────────────────────────
func state_name() -> String:
	return STATE_NAMES[state]


func _set_state(s: int) -> void:
	if s == state:
		return
	var old: int = state
	state = s
	_t = 0.0
	if s != State.ATTACK:
		_windup_t = 0.0
		_shots_left = 0
	debug_log.append("%s->%s" % [STATE_NAMES[old], STATE_NAMES[s]])
	if debug_log.size() > 64:
		debug_log.remove_at(0)
	state_changed.emit(s, old)


func _physics_process(delta: float) -> void:
	tick(delta)


## One brain + movement step (called from _physics_process; tests may call it directly).
func tick(dt: float) -> void:
	if not is_inside_tree():
		return
	if state == State.DEAD:
		_apply_gravity(dt)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_t += dt
	_react_t -= dt
	_cooldown -= dt
	_pain_sfx_t -= dt
	_stun_immune -= dt
	_sense_t -= dt
	_target_t -= dt
	_muzzle_t -= dt
	if _flash != null:
		_flash.visible = _muzzle_t > 0.0
	if _target_t <= 0.0 or target == null or not is_instance_valid(target):
		_target_t = 0.5
		target = _find_player()
	if _sense_t <= 0.0:
		_sense_t = float(tuning("perception").get("sense_interval", 0.1))
		_sense()
	var want: Vector3 = Vector3.ZERO
	if _stun_t > 0.0:
		_stun_t -= dt
		play_anim("hurt")
	elif _pain_t > 0.0:
		_pain_t -= dt
		play_anim("hurt")
	else:
		want = _think(dt)
	if kind == "boss" and phase == 2:
		_boss_tick(dt)
	_apply_gravity(dt)
	velocity.x = want.x
	velocity.z = want.z
	move_and_slide()
	_anim_tick(want)


func _apply_gravity(dt: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 18.0 * dt


func _think(dt: float) -> Vector3:
	match state:
		State.IDLE:
			return Vector3.ZERO
		State.PATROL:
			return _patrol_step()
		State.ALERT:
			if last_seen.is_finite():
				_face_towards(last_seen, dt)
			if _react_t <= 0.0:
				_set_state(State.CHASE)
			return Vector3.ZERO
		State.CHASE:
			return _chase_step(dt)
		State.ATTACK:
			return _attack_step(dt)
		State.TAKE_COVER:
			return _cover_step(dt)
		State.RETREAT:
			return _retreat_step(dt)
	return Vector3.ZERO


# ───────────────────────────── perception ─────────────────────────────
func _find_player() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var bd: float = INF
	for p: Node in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D) or (p as Node).get("dead") == true:
			continue
		var d: float = global_position.distance_squared_to((p as Node3D).global_position)
		if d < bd:
			bd = d
			best = p as Node3D
	return best


func eye_position() -> Vector3:
	return global_position + Vector3.UP * height * float(tuning("perception").get("eye_height_frac", 0.88))


static func target_point(t: Node3D) -> Vector3:
	var h: float = 1.9
	if t != null and t.has_meta("height"):
		h = float(t.get_meta("height"))
	return t.global_position + Vector3.UP * h * 0.7


func forward() -> Vector3:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Clear line between two points (world + doors block; characters do not).
func has_los(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS, [get_rid()])
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Vision: range, facing cone (unless alerted / very close / ignore_cone), LOS.
func can_see(t: Node3D, ignore_cone: bool = false) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return false
	var per: Dictionary = tuning("perception")
	var eye: Vector3 = eye_position()
	var tp: Vector3 = target_point(t)
	var d: float = eye.distance_to(tp)
	if d > float(per.get("sight_range", 96.0)):
		return false
	if not ignore_cone and not alerted and d > float(per.get("feel_range", 6.0)):
		var to: Vector3 = tp - eye
		to.y = 0.0
		if to.length() > 0.001 and forward().dot(to.normalized()) < cos(deg_to_rad(float(per.get("fov_deg", 70.0)))):
			return false
	return has_los(eye, tp)


func _sense() -> void:
	_sees = target != null and can_see(target)
	if _sees:
		last_seen = target.global_position
		_lost_t = 0.0
		if not alerted or state in [State.IDLE, State.PATROL]:
			alert(target.global_position, true)


## Noise at pos audible within radius (Events.noise from weapons). Walls halve the radius.
func hear(pos: Vector3, radius_m: float) -> bool:
	if state == State.DEAD or radius_m <= 0.0:
		return false
	var d: float = global_position.distance_to(pos)
	var r: float = radius_m * 1.25
	if d > r:
		return false
	if not has_los(eye_position(), pos + Vector3.UP * 0.5):
		if d > r * float(tuning("perception").get("hearing_wall_mul", 0.5)):
			return false
	alert(pos, false)
	return true


func _on_noise(pos: Vector3, radius_m: float) -> void:
	hear(pos, radius_m)


## Become alerted (first time: skill-scaled reaction delay, alert sfx + Events.enemy_alerted, shout to friends).
func alert(pos: Vector3 = Vector3.INF, loud: bool = true) -> void:
	if state == State.DEAD:
		return
	var first: bool = not alerted
	alerted = true
	if pos.is_finite():
		last_seen = pos
	if first:
		var r: Array = def.get("reaction", [0.4, 0.8])
		var skm: float = float(_skill_def().get("reaction", 1.0))
		# Grace on first sight (loud) or staggered wake-up when shouted awake by a friend,
		# so ambush clusters do not open fire in one volley. Scaled by skill (skill 3 stays tight).
		var grace: float = rng.randf_range(0.35, 0.7) if loud else rng.randf_range(0.5, 1.6)
		_react_t = (rng.randf_range(float(r[0]), float(r[1])) + grace) * skm
		_sfx("alert")
		_emit("enemy_alerted", [kind, global_position])
		if kind == "boss":
			var evb: Node = _autoload("Events")
			if evb != null and evb.has_signal("music"):
				evb.emit_signal("music", "boss")
		if loud:
			_alert_friends(float(tuning("perception").get("shout_range", 24.0)))
	if state == State.IDLE or state == State.PATROL:
		_set_state(State.ALERT)


func _alert_friends(range_m: float) -> void:
	if not is_inside_tree():
		return
	for o: Node in get_tree().get_nodes_in_group("enemy"):
		if o == self or not (o is RatEnemy):
			continue
		var e: RatEnemy = o as RatEnemy
		if e.state == State.DEAD or e.alerted:
			continue
		if e.global_position.distance_to(global_position) <= range_m:
			e.alert(last_seen if last_seen.is_finite() else global_position, false)


# ───────────────────────────── movement ─────────────────────────────
func _nav_ready() -> bool:
	if nav == null or not nav.is_inside_tree():
		return false
	var m: RID = nav.get_navigation_map()
	return m.is_valid() and NavigationServer3D.map_get_iteration_id(m) > 0 and not NavigationServer3D.map_get_regions(m).is_empty()


## Desired horizontal velocity towards p (navmesh path when available, else straight line).
func _steer(p: Vector3, spd: float, dt: float) -> Vector3:
	var next: Vector3 = p
	if _nav_ready():
		if nav.target_position.distance_to(p) > 0.3:
			nav.target_position = p
		var n: Vector3 = nav.get_next_path_position()
		if n.distance_to(global_position) > 0.05 or global_position.distance_to(p) < 1.0:
			next = n
	var dir: Vector3 = next - global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		return Vector3.ZERO
	dir = dir.normalized()
	_face_dir(dir, dt)
	return dir * spd


func _face_dir(dir: Vector3, dt: float) -> void:
	if dir.length() < 0.001:
		return
	var yaw: float = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(dt * 10.0, 0.0, 1.0))


func _face_towards(p: Vector3, dt: float) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	_face_dir(d.normalized() if d.length() > 0.001 else Vector3.ZERO, dt)


## Snap a point to the navmesh when one exists.
func _snap(p: Vector3) -> Vector3:
	if _nav_ready():
		return NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), p)
	return p


func _cur_speed() -> float:
	var mul: float = 1.0
	if kind == "boss" and phase == 2:
		mul = float((def.get("phase2", {}) as Dictionary).get("speed_mul", 1.3))
	return speed * mul


func _ray_len(dir: Vector3, max_d: float) -> float:
	var from: Vector3 = global_position + Vector3.UP * 0.8
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * max_d, MASK_LOS, [get_rid()])
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return max_d if r.is_empty() else from.distance_to(r["position"])


## Reference longestRunAngle: face the longest open corridor; patrols walk it back and forth.
func _face_open_direction() -> void:
	if not is_inside_tree() or state == State.DEAD:
		return
	var best: Vector3 = forward()
	var bl: float = -1.0
	for d: Vector3 in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		var l: float = _ray_len(d, 24.0)
		if l > bl + 0.01:
			bl = l
			best = d
	if not is_nan(_fixed_yaw):
		rotation.y = _fixed_yaw
	elif not alerted:
		rotation.y = atan2(-best.x, -best.z)
	_patrol_a = global_position
	_patrol_b = global_position + best * maxf(0.0, bl - 1.5)
	_patrol_ready = true


func _patrol_step() -> Vector3:
	if not _patrol_ready:
		return Vector3.ZERO
	var goal: Vector3 = _patrol_b if _patrol_to_b else _patrol_a
	var flat: Vector3 = goal - global_position
	flat.y = 0.0
	if flat.length() < 0.8:
		_patrol_to_b = not _patrol_to_b
		return Vector3.ZERO
	return _steer(goal, speed * float(data().get("patrol_mul", 0.55)), 1.0 / 60.0)


func _attack_def() -> Dictionary:
	return def.get("attack", {})


func is_melee() -> bool:
	return str(_attack_def().get("kind", "")) == "melee"


func _chase_step(dt: float) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if not _sees:
		_lost_t += dt
		if _lost_t > float(tuning("perception").get("lose_target_s", 6.0)):
			alerted = false
			_set_state(State.PATROL if patrol else State.IDLE)
			_patrol_ready = false
			_fixed_yaw = rotation.y
			call_deferred("_face_open_direction")
			return Vector3.ZERO
		if last_seen.is_finite() and global_position.distance_to(last_seen) > 1.0:
			return _steer(last_seen, _cur_speed(), dt)
		return Vector3.ZERO
	var tp: Vector3 = target.global_position
	var d: float = global_position.distance_to(tp)
	var atk: Dictionary = _attack_def()
	var rng_m: float = float(atk.get("range", 40.0))
	if is_melee():
		if d <= rng_m + radius + 0.4:
			if _cooldown <= 0.0:
				_begin_attack()
			_face_towards(tp, dt)
			return Vector3.ZERO
		return _steer(tp, _cur_speed(), dt)
	if _cooldown <= 0.0 and d <= rng_m and _react_t <= 0.0:
		_begin_attack()
		return Vector3.ZERO
	if d > pref_dist:
		return _steer(tp, _cur_speed(), dt)
	if bool(def.get("cover", false)) and d < pref_dist * 0.35 and hp < max_hp * 0.5 and kind != "boss":
		_set_state(State.RETREAT)
		return Vector3.ZERO
	# in the comfort band: strafe a little while the gun cycles
	_face_towards(tp, dt)
	var side: Vector3 = forward().cross(Vector3.UP) * (1.0 if int(_t * 0.7) % 2 == 0 else -1.0)
	if _ray_len(side, 1.5) < 1.4:
		return Vector3.ZERO
	return side * speed * 0.45


func _begin_attack() -> void:
	var atk: Dictionary = _attack_def()
	_set_state(State.ATTACK)
	_windup_t = float(atk.get("windup", 0.4))
	_shots_left = int(atk.get("shots", 1))
	_shot_t = 0.0
	play_anim("aim_idle")


func _attack_step(dt: float) -> Vector3:
	if target == null:
		_set_state(State.CHASE)
		return Vector3.ZERO
	_face_towards(target.global_position, dt * 2.0)
	if _windup_t > 0.0:
		_windup_t -= dt
		return Vector3.ZERO
	_shot_t -= dt
	if _shots_left > 0 and _shot_t <= 0.0:
		_fire_once()
		_shots_left -= 1
		_shot_t = float(_attack_def().get("gap", 0.0))
	if _shots_left <= 0 and _shot_t <= 0.0:
		var cd: Array = _attack_def().get("cooldown", [1.0, 2.0])
		_cooldown = rng.randf_range(float(cd[0]), float(cd[1]))
		_atk_count += 1
		_after_attack()
	return Vector3.ZERO


func _after_attack() -> void:
	if bool(def.get("cover", false)) and not is_melee() and target != null:
		var hurt: bool = hp < max_hp * 0.6
		if (hurt and rng.randf() < 0.6) or rng.randf() < 0.15:
			var c: Vector3 = find_cover(target)
			if c.is_finite():
				cover_point = c
				_hold_t = rng.randf_range(1.5, 3.0)
				_set_state(State.TAKE_COVER)
				return
	_set_state(State.CHASE)


## Nearest reachable point within ~10 m where the threat cannot see a crouched rat (LOS to +1.0 m blocked).
func find_cover(threat: Node3D) -> Vector3:
	if threat == null or not is_inside_tree():
		return Vector3.INF
	var teye: Vector3 = target_point(threat) + Vector3.UP * 0.3
	var best: Vector3 = Vector3.INF
	var bs: float = INF
	var my_eye: Vector3 = global_position + Vector3.UP * 0.8
	for r: float in [2.5, 4.0, 6.0, 8.0, 10.0]:
		for i: int in 12:
			var a: float = TAU * float(i) / 12.0
			var p: Vector3 = _snap(global_position + Vector3(cos(a), 0.0, sin(a)) * r)
			if p.distance_to(threat.global_position) < 4.0:
				continue
			if not has_los(my_eye, p + Vector3.UP * 0.8):
				continue   # not directly reachable along a clear line (cheap reachability check)
			if has_los(teye, p + Vector3.UP * 1.0):
				continue
			var s: float = global_position.distance_to(p) - 0.3 * p.distance_to(threat.global_position)
			if s < bs:
				bs = s
				best = p
		if best.is_finite():
			return best
	return best


func _cover_step(dt: float) -> Vector3:
	if not cover_point.is_finite():
		_set_state(State.CHASE)
		return Vector3.ZERO
	var flat: Vector3 = cover_point - global_position
	flat.y = 0.0
	if flat.length() > 0.7:
		if _t > 6.0:
			_set_state(State.CHASE)
			return Vector3.ZERO
		return _steer(cover_point, _cur_speed() * 1.2, dt)
	_hold_t -= dt
	if target != null:
		_face_towards(target.global_position, dt)
	if _hold_t <= 0.0:
		cover_point = Vector3.INF
		_set_state(State.CHASE)
	return Vector3.ZERO


func _retreat_step(dt: float) -> Vector3:
	if target == null or _t > 2.5:
		var c: Vector3 = find_cover(target) if target != null else Vector3.INF
		if c.is_finite():
			cover_point = c
			_hold_t = rng.randf_range(1.5, 3.0)
			_set_state(State.TAKE_COVER)
		else:
			_set_state(State.CHASE)
		return Vector3.ZERO
	var away: Vector3 = global_position - target.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -forward()
	if _ray_len(away, 1.5) < 1.4:
		_t = 99.0
		return Vector3.ZERO
	var v: Vector3 = away * _cur_speed()
	_face_towards(target.global_position, dt)
	return v


# ───────────────────────────── attacks ─────────────────────────────
## Reference hitChance(dist, playerSpeed) in cells, times the skill accuracy multiplier.
func hit_chance(dist_m: float, target_speed: float) -> float:
	var a: Dictionary = tuning("accuracy")
	var cell: float = float(data().get("cell", 4.0))
	var dc: float = dist_m / cell
	var base: float = clampf(float(a.get("base", 0.95)) - float(a.get("per_cell", 0.05)) * dc, float(a.get("min_base", 0.1)), float(a.get("base", 0.95)))
	var pen: float = clampf(target_speed / float(a.get("run_speed_ref", 7.25)), 0.0, 1.2) * float(a.get("move_pen", 0.45))
	var muls: Array = a.get("skill_mul", [1.0])
	var sm: float = float(muls[clampi(skill, 0, muls.size() - 1)]) if not muls.is_empty() else 1.0
	return clampf(base * (1.0 - pen) * sm, float(a.get("min", 0.04)), float(a.get("max", 0.95)))


func _roll_dmg(dmg: Variant) -> int:
	if dmg is Array and (dmg as Array).size() >= 2:
		return rng.randi_range(int(dmg[0]), int(dmg[1]))
	return int(dmg) if dmg != null else 0


func _fire_once() -> void:
	var atk: Dictionary = _attack_def()
	var k: String = str(atk.get("kind", "hitscan"))
	if kind == "boss" and phase == 2 and _atk_count % 2 == 0:
		k = "volley"
	_sfx("fire")
	last_attack = {"kind": k, "hit": false, "dmg": 0}
	match k:
		"melee":
			play_anim("melee", true)
			if target != null and global_position.distance_to(target.global_position) <= float(atk.get("range", 1.7)) + radius + 0.6 \
					and has_los(eye_position(), target_point(target)):
				_hurt_target(_roll_dmg(atk.get("dmg", [3, 8])))
		"projectile":
			play_anim("fire", true)
			_muzzle_t = 0.08
			_launch(str(atk.get("projectile", "cheeseball")), 0.0)
		"volley":
			play_anim("fire", true)
			_muzzle_t = 0.08
			var p2: Dictionary = def.get("phase2", {})
			var n: int = int(p2.get("volley", 3))
			var spread: float = float(p2.get("spread_deg", 14.0))
			for i: int in n:
				_launch(str(p2.get("projectile", "cheeseball")), spread * (float(i) - float(n - 1) * 0.5))
			_shots_left = 0
		_:
			play_anim("fire", true)
			_muzzle_t = 0.06
			if target != null and has_los(eye_position(), target_point(target)):
				var tv: float = 0.0
				if target is CharacterBody3D:
					var v: Vector3 = (target as CharacterBody3D).velocity
					tv = Vector2(v.x, v.z).length()
				var chance: float = hit_chance(global_position.distance_to(target.global_position), tv)
				last_attack["chance"] = chance
				if rng.randf() < chance:
					_hurt_target(_roll_dmg(atk.get("dmg", [3, 8])))
	_alert_friends(float(tuning("perception").get("gunfire_range", 28.0)) if k != "melee" else 0.0)


func _hurt_target(dmg: int) -> void:
	if target == null or dmg <= 0:
		return
	last_attack["hit"] = true
	last_attack["dmg"] = dmg
	if target.has_method("take_damage"):
		target.call("take_damage", dmg, self, "")
	else:
		_emit("player_hurt", [dmg])


func _launch(proj: String, yaw_off_deg: float) -> Node3D:
	if not ResourceLoader.exists(PROJECTILE_SCRIPT) or target == null:
		return null
	var scr: Script = load(PROJECTILE_SCRIPT) as Script
	var b: Node3D = scr.new() as Node3D
	var from: Vector3 = global_position + Vector3.UP * height * 0.7 + forward() * (radius + 0.4)
	var dir: Vector3 = (target_point(target) - from).normalized()
	dir = dir.rotated(Vector3.UP, deg_to_rad(yaw_off_deg))
	var pd: Dictionary = (tuning("projectiles") as Dictionary).get(proj, {})
	get_parent().add_child(b)
	b.global_position = from
	b.call("setup", dir, pd, self)
	return b


# ───────────────────────────── damage / death ─────────────────────────────
## Damage seam used by RatWeapons (amount already includes the weapon's headshot multiplier).
## hitbox: "head" | "body" | "splash" | "". Returns damage applied (0 if dead).
func take_damage(amount: float, source: Node = null, hitbox: String = "") -> int:
	if state == State.DEAD or _killed or amount <= 0.0:
		return 0
	var mult: float = head_receive_mult if hitbox.to_lower() == "head" else 1.0
	var dmg: int = maxi(1, roundi(amount * mult))
	hp -= dmg
	_emit("enemy_hurt", [kind, global_position])
	var src_pos: Vector3 = (source as Node3D).global_position if source is Node3D and (source as Node3D).is_inside_tree() else Vector3.INF
	if source is Node3D and source.is_in_group("player"):
		target = source as Node3D
	if hp <= 0:
		hp = 0
		_die(false)
		return dmg
	alert(src_pos, true)
	if kind == "boss" and phase == 1 and hp < max_hp * float((def.get("phase2", {}) as Dictionary).get("below", 0.5)):
		_enter_phase2()
		return dmg
	if rng.randf() < float(def.get("pain_chance", 0.5)) and _pain_t <= 0.0 and _stun_t <= 0.0:
		_pain_t = 0.35 if kind == "boss" else 0.24
		if state == State.ATTACK:
			_set_state(State.CHASE)
		play_anim("hurt", true)
		if _pain_sfx_t <= 0.0:
			_sfx("pain")
			_pain_sfx_t = 0.25
	return dmg


## Laser "mesmerise". Boss: shortened and briefly immune afterwards.
func stun(sec: float) -> void:
	if state == State.DEAD or sec <= 0.0:
		return
	if kind == "boss":
		if _stun_immune > 0.0:
			return
		sec *= float(data().get("boss_stun_mul", 0.3))
		_stun_immune = sec + float(data().get("boss_stun_immune", 2.0))
	_stun_t = maxf(_stun_t, sec)
	if state == State.ATTACK:
		_set_state(State.CHASE)


func is_dead() -> bool:
	return state == State.DEAD


func _die(quiet: bool) -> void:
	if _killed:
		return
	_killed = true
	hp = 0
	_set_state(State.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if head_area != null:
		head_area.collision_layer = 0
	if _flash != null:
		_flash.visible = false
	play_anim("death_a" if rng.randf() < 0.5 else "death_b", true)
	if not quiet:
		_sfx("die")
		_emit("enemy_killed", [kind, global_position])
		drop_loot()
	if kind == "boss":
		for m: RatEnemy in minions:
			if is_instance_valid(m) and not m.is_dead():
				m._die(true)
	died.emit(kind)


## Reference dropLoot: first weapon option the player lacks, else the last option.
func drop_loot() -> Node3D:
	var drop: String = str(def.get("drop", ""))
	if drop == "" or not is_inside_tree() or get_parent() == null:
		return null
	var opts: PackedStringArray = []
	for s: String in drop.split("|", false):
		if not Defs.item(s).is_empty():
			opts.append(s)
	if opts.is_empty():
		return null
	var id: String = opts[opts.size() - 1]
	for i: int in opts.size() - 1:
		var it: Dictionary = Defs.item(opts[i])
		if it.has("weapon") and not _player_owns(int(it["weapon"])):
			id = opts[i]
			break
	if not ResourceLoader.exists(PICKUP_SCRIPT):
		return null
	var d: Dictionary = Defs.item(id).duplicate(true)
	d["id"] = id
	d["kind"] = "item"
	d["drop"] = true
	var color: Color = Color(0.9, 0.5, 0.2)
	var shape: String = "box"
	if d.has("weapon"):
		color = Color(0.3, 0.5, 1.0)
		shape = "long"
	elif d.has("treasure"):
		color = Color(1.0, 0.8, 0.2)
		shape = "sphere"
	var p: Node3D = (load(PICKUP_SCRIPT) as Script).new() as Node3D
	p.name = "Drop_%s_%s" % [id, name]
	p.call("setup", d, color, shape)
	get_parent().add_child(p)
	p.global_position = global_position + forward() * 0.4
	return p


func _player_owns(slot: int) -> bool:
	var p: Node3D = target if target != null else _find_player()
	if p != null and "weapons" in p:
		var w: Object = p.get("weapons")
		if w != null and "owned" in w:
			var o: Array = w.get("owned")
			return slot < o.size() and bool(o[slot])
	var g: Node = _autoload("Game")
	if g != null and "loadout" in g:
		var lo: Dictionary = g.get("loadout")
		var o2: Array = lo.get("owned", [])
		return slot < o2.size() and bool(o2[slot])
	return false


# ───────────────────────────── boss ─────────────────────────────
func _enter_phase2() -> void:
	phase = 2
	var p2: Dictionary = def.get("phase2", {})
	_pain_t = float(p2.get("pain", 0.9))
	_cooldown = 0.4
	_atk_count = 0
	_summon_t = 7.0
	if state == State.ATTACK:
		_set_state(State.CHASE)
	play_anim("taunt", true)
	_sfx("pain")
	_emit("message", ["Der Große Käse is enraged!"])
	summon(int(p2.get("summon_first", 2)))


func _boss_tick(dt: float) -> void:
	if target == null:
		return
	_summon_t -= dt
	if _summon_t <= 0.0:
		var p2: Dictionary = def.get("phase2", {})
		_summon_t = float(p2.get("summon_every", 9.0))
		var alive: int = 0
		for m: RatEnemy in minions:
			if is_instance_valid(m) and not m.is_dead():
				alive += 1
		if alive < int(p2.get("max_minions", 3)):
			summon(1)


## Spawn n alerted minions (phase2.summon kind) on free spots around the boss.
func summon(n: int) -> Array[RatEnemy]:
	var out: Array[RatEnemy] = []
	if not is_inside_tree() or get_parent() == null:
		return out
	var k: String = str((def.get("phase2", {}) as Dictionary).get("summon", "sewer"))
	var tries: int = 0
	while out.size() < n and tries < 16:
		var a: float = rng.randf() * TAU
		tries += 1
		var p: Vector3 = _snap(global_position + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(2.5, 5.0))
		if not has_los(global_position + Vector3.UP, p + Vector3.UP):
			continue
		var e: RatEnemy = RatEnemySpawner.spawn(get_parent(), k, p, {"alerted": true, "summoned": true, "boss": self, "skill": skill})
		if e != null:
			minions.append(e)
			out.append(e)
	return out


# ───────────────────────────── animation glue ─────────────────────────────
func _anim_tick(v: Vector3) -> void:
	if state == State.DEAD or _pain_t > 0.0 or _stun_t > 0.0:
		return
	if _anim_cur in ["fire", "melee", "hurt", "taunt"] and _anim != null and _anim.is_playing():
		return
	var spd: float = Vector2(v.x, v.z).length()
	if spd > speed * 0.75:
		play_anim("run")
	elif spd > 0.1:
		play_anim("walk")
	elif state == State.TAKE_COVER:
		play_anim("take_cover")
	elif state in [State.ATTACK, State.CHASE, State.ALERT, State.RETREAT]:
		play_anim("aim_idle")
	else:
		play_anim("idle")
