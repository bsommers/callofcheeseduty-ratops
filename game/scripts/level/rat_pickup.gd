class_name RatPickup
extends Area3D
## Pickup placeholder. Touching it (player layer) emits `Events.pickup_taken(item_id, amount)`
## plus `key_taken(color)` for keys, then frees itself. Full item dict is on `item` and in `taken`.

signal taken(item: Dictionary)

var item: Dictionary = {}
var item_id: String = ""
var _t: float = 0.0
var _mesh: MeshInstance3D
var _base_y: float = 0.7

func setup(it: Dictionary, color: Color, shape: String) -> void:
	item = it
	item_id = str(it.get("id", ""))
	collision_layer = 16
	collision_mask = 2
	monitorable = false
	add_to_group("pickup")
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.1
	cs.shape = sp
	cs.position.y = 0.8
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var m: Mesh
	match shape:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.28
			s.height = 0.56
			m = s
		"long":
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.22, 0.28)
			m = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.22
			c.bottom_radius = 0.22
			c.height = 0.4
			m = c
		_:
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.4, 0.4, 0.4)
			m = b2
	_mesh.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.5
	_mesh.material_override = mat
	_mesh.position.y = _base_y
	add_child(_mesh)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	if _mesh:
		_mesh.rotation.y += delta * 1.6
		_mesh.position.y = _base_y + sin(_t * 2.0 + position.x) * 0.08

func _on_body(body: Node3D) -> void:
	if not LevelEvents.is_player(body):
		return
	var amount: int = 1
	for k in ["heal", "score", "weapon", "life"]:
		if item.has(k):
			amount = int(item[k])
			break
	if item.has("ammo"):
		amount = int((item["ammo"] as Array)[1])
	LevelEvents.emit(self, &"pickup_taken", [item_id, amount])
	if item.has("key"):
		LevelEvents.emit(self, &"key_taken", [str(item["key"])])
	if item.has("msg"):
		LevelEvents.emit(self, &"message", [str(item["msg"])])
	LevelEvents.emit(self, &"sfx", ["pickup_" + _sfx_kind(), global_position])
	taken.emit(item)
	queue_free()

func _sfx_kind() -> String:
	if item.has("key"): return "key"
	if item.has("weapon"): return "weapon"
	if item.has("ammo"): return "ammo"
	if item.has("treasure"): return "treasure"
	return "health"
