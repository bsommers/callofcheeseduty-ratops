class_name RatDoor
extends AnimatableBody3D
## Sliding door. Opens by proximity (player, or enemies for unlocked doors) and by `interact(by)`.
## Locked doors open only when `has_key` (set by the builder) returns true for `lock`.

signal opened(door_id: String)

var door_id: String = ""
var lock: String = ""          # "" | "gold" | "silver"
var slide_axis: Vector3 = Vector3.RIGHT
var slide_dist: float = 3.9
var has_key: Callable = Callable()
var is_open: bool = false
var close_delay: float = 3.5

var _occupants: int = 0
var _tween: Tween
var _closed_pos: Vector3
var _hint_cd: float = 0.0
var _close_timer: float = 0.0

func setup(id: String, lock_name: String, passage: String, size: Vector3, mesh_mat: Material) -> void:
	door_id = id
	lock = lock_name
	collision_layer = 1 | 64
	collision_mask = 0
	sync_to_physics = true
	add_to_group("door")
	# passage 'ns': player walks along Z, slab spans X, slides along X
	slide_axis = Vector3.RIGHT if passage == "ns" else Vector3.BACK
	var slab := Vector3(size.x, size.y, 0.4) if passage == "ns" else Vector3(0.4, size.y, size.z)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = slab
	mi.mesh = bm
	mi.material_override = mesh_mat
	mi.position.y = slab.y * 0.5
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = slab
	cs.shape = bs
	cs.position.y = slab.y * 0.5
	add_child(cs)
	var sensor := Area3D.new()
	sensor.name = "Sensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 2 | 4
	sensor.monitorable = false
	var ss := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(size.x + 3.0, 2.5, size.z + 3.0)
	ss.shape = sb
	ss.position.y = 1.25
	sensor.add_child(ss)
	add_child(sensor)
	sensor.body_entered.connect(_on_enter)
	sensor.body_exited.connect(_on_exit)

func _ready() -> void:
	_closed_pos = position

func _process(delta: float) -> void:
	_hint_cd = maxf(0.0, _hint_cd - delta)
	if is_open and _occupants <= 0:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_slide(false)

func _on_enter(body: Node3D) -> void:
	var player: bool = LevelEvents.is_player(body)
	if not (player or LevelEvents.is_enemy(body)):
		return
	_occupants += 1
	if lock == "":
		_slide(true)
	elif player:
		if _key_ok():
			_slide(true)
		elif _hint_cd <= 0.0:
			_hint_cd = 2.0
			LevelEvents.emit(self, &"message", ["Need the %s key" % lock])
			LevelEvents.emit(self, &"sfx", ["door_locked", global_position])

func _on_exit(body: Node3D) -> void:
	if LevelEvents.is_player(body) or LevelEvents.is_enemy(body):
		_occupants = maxi(0, _occupants - 1)
		_close_timer = close_delay

func _key_ok() -> bool:
	return lock == "" or (has_key.is_valid() and bool(has_key.call(lock)))

## Called by the player's "use" ray.
func interact(_by: Node = null) -> void:
	if lock != "" and not _key_ok():
		LevelEvents.emit(self, &"message", ["Need the %s key" % lock])
		LevelEvents.emit(self, &"sfx", ["door_locked", global_position])
		return
	_slide(not is_open)

func _slide(open: bool) -> void:
	if open == is_open:
		if open:
			_close_timer = close_delay
		return
	is_open = open
	_close_timer = close_delay
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target: Vector3 = _closed_pos + (slide_axis * slide_dist if open else Vector3.ZERO)
	_tween.tween_property(self, "position", target, 0.7).set_trans(Tween.TRANS_SINE)
	if open:
		LevelEvents.emit(self, &"door_opened", [door_id])
		LevelEvents.emit(self, &"sfx", ["door_open", global_position])
		opened.emit(door_id)
	else:
		LevelEvents.emit(self, &"sfx", ["door_close", global_position])
