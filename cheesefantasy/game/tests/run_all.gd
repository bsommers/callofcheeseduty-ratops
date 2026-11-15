extends SceneTree
## Headless test runner (owner rpg-core).
## usage: tools/run_tests.sh [filter]   (= tools/godot.sh --headless --path game --script res://tests/run_all.gd -- [filter])
## Runs every `test_*` method of every res://tests/test_*.gd (RefCounted with `var failures: Array`).
## Prints PASS/FAIL per test and exits non-zero on any failure.

const DIR: String = "res://tests"


func _initialize() -> void:
	await process_frame  # autoloads ready
	var filter: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed: int = 0
	var failed: int = 0
	var t0: int = Time.get_ticks_msec()
	for f: String in files:
		var script: GDScript = load(DIR + "/" + f) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s (script failed to load)" % f)
			failed += 1
			continue
		var inst: Object = script.new()
		for m: Dictionary in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (filter != "" and not (f + ":" + name).contains(filter)):
				continue
			inst.set("failures", [])
			var r: Variant = inst.call(name)
			if r is Object and r.get_class() == "GDScriptFunctionState":
				await r.completed
			var fails: Array = inst.get("failures")
			if fails.is_empty():
				passed += 1
				print("PASS %s:%s" % [f, name])
			else:
				failed += 1
				print("FAIL %s:%s" % [f, name])
				for x: Variant in fails.slice(0, 12):
					print("     - %s" % str(x))
	print("TESTS %d passed, %d failed (%.1fs)" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)
