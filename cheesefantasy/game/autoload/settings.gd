extends Node
## Settings autoload (owner rpg-core): user preferences persisted to user://settings.cfg.
## Keys: master/music/sfx (0..1 linear), fullscreen, vsync, text_speed (chars/s, 0 = instant), battle_speed (0.5..3),
## quality (0 low .. 3 ultra), cam_sensitivity, invert_cam, auto_battle_confirm.

signal changed(key: String, value: Variant)

const PATH: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {"master": 0.8, "music": 0.7, "sfx": 0.8, "fullscreen": false, "vsync": true,
	"text_speed": 45.0, "battle_speed": 1.0, "quality": 2, "cam_sensitivity": 1.0, "invert_cam": false}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	apply_all()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v: Variant, save: bool = true) -> void:
	values[key] = v
	_apply(key)
	changed.emit(key, v)
	if save:
		save_settings()


func load_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k: String in DEFAULTS:
		values[k] = cf.get_value("settings", k, DEFAULTS[k])


func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	for k: String in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


func apply_all() -> void:
	for k: String in values:
		_apply(k)


func _apply(key: String) -> void:
	match key:
		"master", "music", "sfx":
			var bus_name: String = "Master" if key == "master" else key.capitalize()
			var idx: int = AudioServer.get_bus_index(bus_name)
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, float(values[key]))))
		"fullscreen":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values[key] else DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values[key] else DisplayServer.VSYNC_DISABLED)
