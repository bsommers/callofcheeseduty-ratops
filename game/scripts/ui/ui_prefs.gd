class_name UIPrefs
extends RefCounted
## UI-owned preferences that `Settings` has no defaults for (key bindings, window resolution).
## Stored in user://ui_prefs.cfg. `persist` mirrors Settings.persist so tests never write to disk.

const PATH: String = "user://ui_prefs.cfg"
static var _cfg: ConfigFile = null


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		if Settings.persist:
			_cfg.load(PATH)
	return _cfg


static func get_pref(section: String, key: String, def: Variant = "") -> Variant:
	return _c().get_value(section, key, def)


static func set_pref(section: String, key: String, value: Variant) -> void:
	_c().set_value(section, key, value)
	if Settings.persist:
		_c().save(PATH)


static func reset_cache() -> void:
	_cfg = null
