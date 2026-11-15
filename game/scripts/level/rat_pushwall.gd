class_name RatPushwall
extends StaticBody3D
## Secret pushwall: slides two cells directly away from the user on `interact(by)`.

signal pushed(wall_id: String)

var wall_id: String = ""
var dirs: Array[Vector3] = []     # allowed slide directions (world, unit)
var travel: float = 8.0
var used: bool = false
var cell_size: float = 4.0

func setup(id: String, allowed: Array[Vector3], size: Vector3, mat: Material, cell: float) -> void:
	wall_id = id
	dirs = allowed
	cell_size = cell
	travel = cell * 2.0
	collision_layer = 1 | 64
	collision_mask = 0
	add_to_group("pushwall")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position.y = size.y * 0.5
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	add_child(cs)

## Called by the player's "use" ray (or any node with a global position).
func interact(by: Node = null) -> void:
	if used or dirs.is_empty():
		return
	var away: Vector3 = Vector3.ZERO
	if by is Node3D:
		away = global_position - (by as Node3D).global_position
		away.y = 0.0
	var best: Vector3 = dirs[0]
	var best_dot: float = -INF
	for d in dirs:
		var dp: float = d.dot(away)
		if dp > best_dot:
			best_dot = dp
			best = d
	used = true
	var t := create_tween()
	t.tween_property(self, "position", position + best * travel, 3.2)
	LevelEvents.emit(self, &"secret_found")
	LevelEvents.emit(self, &"message", ["A secret!"])
	LevelEvents.emit(self, &"sfx", ["pushwall", global_position])
	pushed.emit(wall_id)
