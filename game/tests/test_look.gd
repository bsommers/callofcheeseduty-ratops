extends "res://tests/test_case.gd"
## LookRig (owner: look-dev): per-level look data, LUT, applying to a built level, quality degradation.

const LEVELS: Array[String] = ["e1m1", "e1m2", "e1m3", "e1m4", "e1m5", "e1m6"]
var _saved_quality: int = 2


func before_each() -> void:
	var s: Node = autoload("Settings")
	if s != null:
		s.set("persist", false)
		_saved_quality = int(s.get("quality"))


func after_each() -> void:
	var s: Node = autoload("Settings")
	if s != null:
		s.set("quality", _saved_quality)
		s.set("persist", true)


func test_look_data_parses_and_assets_exist() -> void:
	check(FileAccess.file_exists("res://data/look/default.json"), "default.json exists")
	for id: String in LEVELS:
		check(FileAccess.file_exists("res://data/look/%s.json" % id), id + " look json exists")
		var lk: Dictionary = LookRig.load_look(id)
		check(lk.has("tonemap") and lk.has("fog") and lk.has("lights"), id + " merged look has core sections")
		var hdri: String = String((lk.get("sky", {}) as Dictionary).get("hdri", ""))
		check(hdri != "" and ResourceLoader.exists(hdri), "%s hdri exists: %s" % [id, hdri])
		for mk: Variant in lk.get("materials", {}) as Dictionary:
			var lib: String = String(((lk["materials"] as Dictionary)[mk] as Dictionary).get("lib", ""))
			check(ResourceLoader.exists("res://assets/materials/%s.tres" % lib), "%s material lib %s exists" % [id, lib])


func test_levels_have_distinct_moods() -> void:
	var seen: Dictionary = {}
	for id: String in LEVELS:
		var lk: Dictionary = LookRig.load_look(id)
		var sig: String = var_to_str((lk["lights"] as Dictionary).get("color", [])) + var_to_str((lk["fog"] as Dictionary).get("albedo", []))
		check(not seen.has(sig), id + " look differs from " + String(seen.get(sig, "")))
		seen[sig] = id


func test_deep_merge() -> void:
	var m: Dictionary = LookRig.deep_merge({"a": {"x": 1, "y": 2}, "b": 3}, {"a": {"y": 5}, "c": 4})
	eq(int((m["a"] as Dictionary)["x"]), 1, "keeps base key")
	eq(int((m["a"] as Dictionary)["y"]), 5, "override nested")
	eq(int(m["b"]), 3, "keeps top")
	eq(int(m["c"]), 4, "adds key")


func test_neutral_lut_is_identity() -> void:
	var imgs: Array[Image] = LookRig.lut_images({})
	var n: int = LookRig.LUT_SIZE
	eq(imgs.size(), n, "lut depth")
	check(LookRig.make_lut({}) is ImageTexture3D, "make_lut returns a 3D texture")
	var c: Color = imgs[n - 1].get_pixel(0, n / 2)
	check(absf(c.r - 0.0) < 0.02 and absf(c.g - float(n / 2) / (n - 1)) < 0.02 and absf(c.b - 1.0) < 0.02, "identity texel %s" % c)
	var w: Color = LookRig.lut_images({"highlight_tint": [0.1, 0.0, -0.1]})[n - 1].get_pixel(n - 1, n - 1)
	check(w.b < 0.99, "highlight tint cools blue in whites")


func test_apply_to_built_level() -> void:
	for id: String in ["e1m1", "e1m4"]:
		var lvl: Node3D = (load("res://scenes/level_base.tscn") as PackedScene).instantiate() as Node3D
		tree.root.add_child(lvl)
		check(bool(lvl.call("build_level", id)), id + " builds")
		var omni: Array[Node] = lvl.find_children("*", "OmniLight3D", true, false)
		var before: float = 0.0
		for l: Node in omni:
			before += (l as OmniLight3D).light_energy
		var rig: LookRig = LookRig.apply_to(lvl, id)
		var we: WorldEnvironment = lvl.find_child("LevelEnvironment", true, false) as WorldEnvironment
		check(we != null and we.environment == rig.env, id + " rig env installed on LevelEnvironment")
		check(rig.env.tonemap_mode == Environment.TONE_MAPPER_ACES, id + " ACES")
		check(rig.env.adjustment_color_correction != null, id + " LUT set")
		check(we.camera_attributes is CameraAttributesPractical, id + " auto exposure attrs")
		var after: float = 0.0
		for l: Node in omni:
			after += (l as OmniLight3D).light_energy
		check(after > before * 1.5, "%s lights brightened (%.1f -> %.1f)" % [id, before, after])
		check(rig.find_child("LookPost", true, false) != null, id + " post finish layer")
		if id == "e1m4":
			check(rig.sun != null and rig.sun.shadow_enabled, "e1m4 has a shadowed moon")
			var sky: Node = lvl.find_child("Mesh_ceil_sky", true, false)
			check(sky == null or not (sky as Node3D).visible, "e1m4 sky ceiling hidden")
		else:
			check(rig.sun == null, "e1m1 interior: no sun")
		lvl.free()


func test_quality_degrades() -> void:
	var s: Node = autoload("Settings")
	if not check(s != null, "Settings autoload"):
		return
	var lvl: Node3D = (load("res://scenes/level_base.tscn") as PackedScene).instantiate() as Node3D
	tree.root.add_child(lvl)
	lvl.call("build_level", "e1m3")
	s.set("quality", 0)
	var rig: LookRig = LookRig.apply_to(lvl, "e1m3")
	check(not rig.env.sdfgi_enabled and not rig.env.volumetric_fog_enabled, "Low: no SDFGI/vol fog")
	check(rig.env.fog_enabled, "Low: depth-fog fallback keeps the haze")
	var low_amb: float = rig.env.ambient_light_energy
	s.set("quality", 3)
	rig._apply_quality()
	check(rig.env.sdfgi_enabled and rig.env.volumetric_fog_enabled and rig.env.ssil_enabled, "Ultra: SDFGI/fog/SSIL")
	check(not rig.env.fog_enabled, "Ultra: depth-fog fallback off")
	check(low_amb > rig.env.ambient_light_energy, "Low lifts ambient to compensate for missing GI")
	lvl.free()
