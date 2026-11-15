class_name RatCheeseball
extends Node3D
## Enemy projectile (owner: enemy-ai): molten cheeseball from panzer rats and the boss.
## Swept ray each physics step against world | player | door; explodes on contact or when the fuse ends.
## Splash hurts the player (group `player`) with LOS and linear falloff via take_damage(dmg, shooter, "splash").

const MASK: int = 1 | 2 | 64

var dir: Vector3 = Vector3.FORWARD
var speed: float = 14.7
var fuse: float = 6.0
var dmg: Array = [14, 28]
var splash: float = 2.3
var sfx_name: String = "cheese_splat"
var shooter: Node = null
var exploded: bool = false
var hit_player: bool = false
var _age: float = 0.0


func setup(d: Vector3, def: Dictionary, src: Node) -> void:
	dir = d.normalized()
	shooter = src
	speed = float(def.get("speed", speed))
	fuse = float(def.get("fuse", fuse))
	dmg = def.get("dmg", dmg)
	splash = float(def.get("splash", splash))
	sfx_name = str(def.get("sfx", sfx_name))
	var r: float = float(def.get("radius", 0.18))
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.7, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.1)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	add_child(mi)
	var l: Array = def.get("light", [2.2, 1.3, 0.3, 3.5])
	var ol: OmniLight3D = OmniLight3D.new()
	ol.light_color = Color(float(l[0]), float(l[1]), float(l[2])).clamp(Color(0, 0, 0), Color(1, 1, 1))
	ol.light_energy = 2.0
	ol.omni_range = float(l[3]) if l.size() > 3 else 3.5
	ol.shadow_enabled = false
	add_child(ol)
	add_to_group("enemy_projectile")


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if exploded or not is_inside_tree():
		return
	_age += delta
	var from: Vector3 = global_position
	var to: Vector3 = from + dir * speed * delta
	var ex: Array[RID] = []
	if shooter is CollisionObject3D and is_instance_valid(shooter):
		ex.append((shooter as CollisionObject3D).get_rid())
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK, ex)
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"]
		var c: Object = r.get("collider", null)
		explode(c as Node if c is Node else null)
		return
	global_position = to
	if _age >= fuse:
		explode(null)


func explode(direct: Node) -> void:
	if exploded:
		return
	exploded = true
	var ev: Node = get_node_or_null("/root/Events")
	if ev != null and ev.has_signal("sfx"):
		ev.emit_signal("sfx", sfx_name, global_position)
	var lo: int = int(dmg[0]) if dmg.size() > 0 else 14
	var hi: int = int(dmg[1]) if dmg.size() > 1 else lo
	for p: Node in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D) or not p.has_method("take_damage"):
			continue
		var pn: Node3D = p as Node3D
		var amount: int = 0
		if direct != null and (direct == pn or pn.is_ancestor_of(direct)):
			amount = hi
		else:
			var c: Vector3 = pn.global_position + Vector3.UP * 0.9
			var d: float = global_position.distance_to(c)
			if d > splash:
				continue
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + (c - global_position).normalized() * 0.05, c, 1 | 64)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				continue
			amount = roundi(lerpf(float(hi), float(lo), clampf(d / maxf(splash, 0.01), 0.0, 1.0)))
		if amount > 0:
			hit_player = true
			p.call("take_damage", amount, shooter if is_instance_valid(shooter) else null, "splash")
	queue_free()
