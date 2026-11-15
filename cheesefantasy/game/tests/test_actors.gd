extends RefCounted
## ActorFactory: placeholder fallback, real glb loading, clip fallbacks.

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_placeholder_has_all_clips() -> void:
	var rig: ActorRig = ActorFactory.spawn("does_not_exist_xyz", 1.5) as ActorRig
	check(rig != null and rig.placeholder, "placeholder used for missing model")
	for c: String in ActorFactory.ALL_CLIPS:
		check(rig.has_anim(c), "placeholder clip " + c)
	check(rig.play("nonsense_clip") == "idle", "unknown clip falls back to idle")
	check(absf(rig.height - 1.5) < 0.05, "height normalised (%f)" % rig.height)
	rig.free()


func test_real_models_load() -> void:
	var n: int = 0
	for f: String in DirAccess.get_files_at("res://assets/models"):
		if not f.ends_with(".glb") or n >= 6:
			continue
		n += 1
		var id: String = f.get_basename()
		var rig: ActorRig = ActorFactory.spawn(id) as ActorRig
		check(not rig.placeholder, "glb loads: " + id)
		check(rig.height > 0.05, "%s has size" % id)
		rig.free()
