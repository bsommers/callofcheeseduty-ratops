class_name WorldNPC
extends WorldInteractable
## Talkable villager or farm animal. mode: "idle" | "patrol" | "wander".

@export var npc_id: String = ""
@export var display_name: String = ""
@export var model_id: String = "npc_farmer"
@export var dialogue_id: String = ""
@export var model_height: float = 0.0
@export_enum("idle", "patrol", "wander") var mode: String = "idle"
@export var wander_radius: float = 5.0
@export var speed: float = 1.1
@export var patrol_points: PackedVector3Array = PackedVector3Array()

var model: Node3D
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 0.0
var _patrol_i := 0
var _talking := false
var _anim := ""
var _bob := 0.0

func _ready() -> void:
	if dialogue_id == "":
		dialogue_id = npc_id
	prompt = "Talk to %s" % display_name if display_name != "" else "Talk"
	model = WorldModels.spawn_actor(model_id, model_height)
	add_child(model)
	_home = position
	_target = position
	_wait = randf_range(0.5, 3.0)
	rotation.y = randf() * TAU
	snap_to_ground()
	# Solid blocker so the player cannot walk through people.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45 if model_height == 0.0 or model_height > 0.9 else 0.3
	cyl.height = 1.4
	cs.shape = cyl
	cs.position.y = 0.7
	body.add_child(cs)
	add_child(body)
	_play("idle")
	WorldBus.listen(&"dialogue_finished", _on_dialogue_finished)

func _exit_tree() -> void:
	WorldBus.unlisten(&"dialogue_finished", _on_dialogue_finished)

func _play(a: String) -> void:
	if a != _anim:
		_anim = a
		WorldModels.play(model, a)

func interact(player: Node3D) -> void:
	_talking = true
	face_toward(player.global_position)
	_play("idle")
	var box := get_tree().get_first_node_in_group("dialogue_box")
	if box != null and box.has_method("start"):
		box.call("start", dialogue_id, self)
	else:
		WorldBus.toast("%s: ..." % display_name)
		_talking = false

func _on_dialogue_finished(_id: Variant = null) -> void:
	_talking = false

func _process(delta: float) -> void:
	if _talking or mode == "idle":
		return
	if _wait > 0.0:
		_wait -= delta
		_play("idle")
		if _wait <= 0.0:
			_pick_target()
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.25:
		_wait = randf_range(1.5, 5.0)
		return
	var step := to.normalized() * speed * delta
	position += step
	snap_to_ground()
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 6.0, 0.0, 1.0))
	_play("walk")

func _pick_target() -> void:
	if mode == "patrol" and patrol_points.size() > 0:
		_patrol_i = (_patrol_i + 1) % patrol_points.size()
		_target = patrol_points[_patrol_i]
	else:
		var a := randf() * TAU
		_target = _home + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, wander_radius)
