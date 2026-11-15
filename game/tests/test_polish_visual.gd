extends SceneTree
## Run: tools/godot.sh --headless --path game --script res://tests/test_polish_visual.gd
## Checks: exit switch prop exists on every level, no ceil.sky mesh, lights carry look_kind metadata.

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for n in range(1, 7):
		var id: String = "e1m%d" % n
		var b: LevelBuilder = LevelBuilder.new()
		root.add_child(b)
		_check(b.build_level(id), id + " builds")
		_check(b.find_child("ExitSwitchProp", true, false) != null, id + " has exit switch prop")
		_check(b.find_child("Mesh_ceil_sky", true, false) == null, id + " has no sky ceiling mesh")
		for l: Node in b.find_children("*", "OmniLight3D", true, false):
			_check(l.has_meta("look_kind"), id + " light " + l.name + " tagged")
		b.queue_free()
	print("PASS" if failures == 0 else "FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
