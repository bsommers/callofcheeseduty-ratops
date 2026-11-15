extends RefCounted
## Facing convention: glb character models face -Z (see docs/swarm/reports/models-party.md). A character that
## "faces toward D" must have its -Z axis pointing at D, or it walks backwards (the 'moonwalk' bug).

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_face_toward_points_minus_z_at_target() -> void:
	var n := WorldInteractable.new()
	for d: Vector3 in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5), Vector3(3, 0, 4)]:
		n.face_toward(d, true)
		var fwd: Vector3 = -n.basis.z
		check(fwd.dot(d.normalized()) > 0.999, "face_toward(%s): -Z is %s, model would face away" % [d, fwd])
	n.free()


## Lint: any atan2() that sets a character yaw in scripts/world must include the +PI correction.
func test_world_yaw_sites_apply_pi_correction() -> void:
	for f: String in ["player_controller.gd", "world_npc.gd", "world_mob.gd", "world_interactable.gd"]:
		var fa := FileAccess.open("res://scripts/world/" + f, FileAccess.READ)
		check(fa != null, "cannot read " + f)
		if fa == null:
			continue
		var ln := 0
		for line: String in fa.get_as_text().split("\n"):
			ln += 1
			if "atan2(" in line and not "PI" in line:
				failures.append("%s:%d yaw from atan2 without +PI (models face -Z): %s" % [f, ln, line.strip_edges()])
