extends "res://tests/test_case.gd"
## Settings: presets, ConfigFile persistence (to a temp path) and apply-to-environment.

const TMP: String = "user://test_settings_tmp.cfg"
var _saved_quality: int


func before_each() -> void:
	Settings.persist = false
	_saved_quality = Settings.quality


func after_each() -> void:
	Settings.quality = _saved_quality
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	Settings.load_settings()
	Settings.persist = true


func test_four_presets() -> void:
	eq(Settings.PRESETS.size(), 4, "Low/Medium/High/Ultra")
	eq(Array(Settings.QUALITY_NAMES), ["Low", "Medium", "High", "Ultra"], "names")
	for p: Dictionary in Settings.PRESETS:
		for k: String in ["sdfgi", "ssr", "ssao", "ssil", "fog", "msaa", "dir_shadow_size"]:
			check(p.has(k), "preset has %s" % k)
	check(not bool(Settings.PRESETS[0]["sdfgi"]), "Low has no SDFGI")
	check(bool(Settings.PRESETS[3]["sdfgi"]) and bool(Settings.PRESETS[3]["fog"]), "Ultra has SDFGI+fog")


func test_quality_clamped() -> void:
	Settings.quality = 99
	eq(Settings.quality, 3, "clamp high")
	Settings.quality = -5
	eq(Settings.quality, 0, "clamp low")


func test_apply_to_environment_follows_preset() -> void:
	var env: Environment = Environment.new()
	Settings.quality = 0
	Settings.apply_to_environment(env)
	check(not env.sdfgi_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled, "Low disables GI/SSR/fog")
	Settings.quality = 3
	Settings.apply_to_environment(env)
	check(env.sdfgi_enabled and env.ssr_enabled and env.volumetric_fog_enabled, "Ultra enables GI/SSR/fog")


func test_persist_roundtrip() -> void:
	Settings.set_value("input", "mouse_sensitivity", 0.0123, false)  # persist=false: no write to the real file
	Settings.persist = true
	eq(Settings.save(TMP), OK, "save")
	Settings.persist = false
	Settings.reset_to_defaults()
	eq(Settings.mouse_sensitivity, 0.0025, "defaults restored")
	Settings.load_settings(TMP)
	eq(Settings.mouse_sensitivity, 0.0123, "loaded value")
