class_name WorldInteractable
extends Node3D
## Base for everything the player can press [interact] on.

static var ground: FarmTerrain = null

@export var prompt: String = "Interact"
@export var interact_radius: float = 2.6

func _enter_tree() -> void:
	add_to_group("interactable")

func interact(_player: Node3D) -> void:
	pass

func snap_to_ground(extra: float = 0.0) -> void:
	if ground != null:
		position.y = maxf(ground.height_at(position.x, position.z), FarmTerrain.WATER_LEVEL - 0.05) + extra

func face_toward(target: Vector3, instant: bool = true, delta: float = 0.0) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var want := atan2(d.x, d.z) + PI  # glb models face -Z
	rotation.y = want if instant else lerp_angle(rotation.y, want, clampf(delta * 8.0, 0.0, 1.0))
