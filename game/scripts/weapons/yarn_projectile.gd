class_name RatYarnBall
extends RigidBody3D
## Yarn Bomber projectile (layer 4). Bounces off the world up to `bounces` times, explodes on an enemy,
## on the next world hit after the bounces are used, or when the fuse runs out. Splash damage falls off
## linearly with distance and needs line of sight from the blast centre.

const LAYER_PROJECTILE: int = 8   # layer 4
const MASK: int = 1 | 4 | 64      # world, enemy, door

var cfg: Dictionary = {}
var source: Node = null
var _fuse: float = 2.2
var _bounces_left: int = 2
var _exploded: bool = false
var _light: OmniLight3D = null


func setup(conf: Dictionary, src: Node, velocity: Vector3) -> void:
	cfg = conf
	source = src
	_fuse = float(cfg.get("fuse", 2.2))
	_bounces_left = int(cfg.get("bounces", 2))
	linear_velocity = velocity
	gravity_scale = float(cfg.get("gravity_scale", 0.6))


func _ready() -> void:
	name = "YarnBall"
	add_to_group("projectile")
	collision_layer = LAYER_PROJECTILE
	collision_mask = MASK
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	var r: float = float(cfg.get("radius", 0.18))
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.4
	physics_material_override = pm
	mass = 0.4
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.35, 0.7)
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.2, 0.6)
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	add_child(mi)
	var lc: Array = cfg.get("light", [1.6, 0.4, 1.4, 6.0])
	_light = OmniLight3D.new()
	_light.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2])).clamp()
	_light.light_energy = 1.2
	_light.omni_range = float(lc[3]) if lc.size() > 3 else 6.0
	add_child(_light)
	if source is CollisionObject3D:
		add_collision_exception_with(source)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_fuse -= delta
	if _fuse <= 0.0:
		explode()


func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if RatWeapons.find_enemy(body) != null:
		explode()
		return
	_bounces_left -= 1
	if _bounces_left < 0:
		explode()


## Detonate now (idempotent). Returns the number of enemies damaged.
func explode() -> int:
	if _exploded:
		return 0
	_exploded = true
	var pos: Vector3 = global_position
	var radius: float = float(cfg.get("splash", 3.5))
	var dmg_range: Array = cfg.get("dmg", [55, 95])
	var hit: int = 0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group("enemy"):
			if not (n is Node3D) or not n.has_method("take_damage"):
				continue
			var e := n as Node3D
			var target: Vector3 = e.global_position + Vector3.UP * 0.8
			var d: float = pos.distance_to(target)
			if d > radius:
				continue
			if space != null:
				var q := PhysicsRayQueryParameters3D.create(pos, target, 1 | 64)
				q.exclude = [get_rid()]
				var r: Dictionary = space.intersect_ray(q)
				if not r.is_empty():
					continue
			var base: float = float(randi_range(int(dmg_range[0]), int(dmg_range[1])))
			var amount: int = maxi(1, roundi(base * clampf(1.0 - d / radius * 0.75, 0.25, 1.0)))
			e.call("take_damage", amount, source, "splash")
			hit += 1
		RatWeaponFx.explosion(get_parent(), pos, cfg.get("light", null), radius)
		Events.sfx.emit(str(cfg.get("sfx", "explosion")), pos)
	queue_free()
	return hit
