extends RatTestCase
## Audio layer tests (owner: audio). Headless: streams load, buses exist, pool bounded, signals wired, no errors.

const SCENE: String = "res://scenes/audio_manager.tscn"
var _mgr: AudioManager


func before_each() -> void:
	_mgr = (load(SCENE) as PackedScene).instantiate() as AudioManager
	tree.root.add_child(_mgr)


func after_each() -> void:
	if _mgr != null:
		_mgr.stop_all()
		_mgr.queue_free()


func test_buses_exist() -> void:
	for b: String in ["Master", "Music", "SFX", "UI", "Ambience"]:
		check(AudioServer.get_bus_index(b) >= 0, "bus " + b)


func test_bus_volume_follows_settings() -> void:
	var st: Node = autoload("Settings")
	var old: Variant = st.get_value("audio", "music")
	st.set_value("audio", "music", 0.5, false)
	_mgr.apply_volumes()
	var db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	check(absf(db - (linear_to_db(0.5) + AudioManager.BUS_TRIM_DB["Music"])) < 0.01, "music bus db %f" % db)
	st.set_value("audio", "music", old, false)


func test_all_streams_load() -> void:
	var names: Array[String] = ["pistol", "gatling", "yarn", "laser", "claws", "reload_pistol", "reload_gatling", "reload_yarn", "reload_laser",
		"ricochet_1", "hit_flesh", "headshot", "door_open", "door_close", "door_locked", "pickup_health", "pickup_key", "ui_click", "ui_hover", "explosion"]
	for s: String in ["stone", "wood", "metal", "wet"]:
		for v: int in range(1, 5):
			names.append("step_%s_%d" % [s, v])
	for k: String in AudioManager.KINDS:
		for p: String in ["bark_", "hurt_", "death_"]:
			names.append(p + k)
	for n: String in names:
		check(_mgr.get_stream(n) != null, "sfx " + n)
	for n2: String in ["music_boss", "music_title", "music_victory", "music_cellar_combat", "music_sewer_combat", "music_hall_combat"]:
		var ms: AudioStream = _mgr.get_stream(n2, AudioManager.MUSIC_DIR, true)
		check(ms is AudioStreamWAV and (ms as AudioStreamWAV).loop_end > 300000, "music " + n2)
	for n3: String in ["taunt_mouse", "taunt_boss", "cat_growl", "cat_meow_1", "cat_meow_2", "cat_meow_3", "cat_purr"]:
		check(_mgr.get_stream(n3) != null, "sfx " + n3)
	for m: String in ["cellar", "sewer", "hall"]:
		var a: AudioStream = _mgr.get_stream("amb_" + m, AudioManager.AMB_DIR, true)
		var mu: AudioStream = _mgr.get_stream("music_" + m, AudioManager.MUSIC_DIR, true)
		check(a != null and mu != null, "loops " + m)
		if a is AudioStreamWAV:
			check((a as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "amb loop " + m)
			check((mu as AudioStreamWAV).loop_end > 300000, "music loop_end " + m)


func test_pool_is_bounded() -> void:
	for i: int in 200:
		_mgr.play("step_stone_1" if i % 2 == 0 else "pistol", Vector3(i, 0, 0))
	check(_mgr.active_voices() <= _mgr.pool_size(), "voices %d" % _mgr.active_voices())
	check(_mgr.get_child_count() == AudioManager.POOL_3D + AudioManager.POOL_2D + 5, "no node growth %d" % _mgr.get_child_count())


func test_events_drive_playback() -> void:
	var ev: Node = autoload("Events")
	ev.enemy_killed.emit("sewer", Vector3(1, 0, 1))
	ev.pickup_taken.emit("key", 1)
	ev.player_hurt.emit(5)
	ev.door_opened.emit("d1")
	ev.sfx.emit("footstep", Vector3.ZERO)
	check(_mgr.active_voices() >= 1, "events produced voices")


func test_footstep_surface_and_unknown() -> void:
	_mgr.set_surface("metal")
	check(_mgr.resolve("footstep").begins_with("step_metal_"), "metal footstep")
	check(_mgr.play("no_such_sound") == null, "unknown sound ignored")
	check(not _mgr.has_sound("claws_reload"), "claws has no reload sound")


func test_mood_and_zone() -> void:
	_mgr.set_mood("sewer")
	eq(_mgr.surface, "wet", "sewer surface")
	eq(_mgr.zone, "sewer", "sewer zone")
	autoload("Events").level_loaded.emit("e1m5")
	eq(_mgr.mood, "hall", "mood from level id")


func test_combat_layer_crossfade() -> void:
	_mgr.set_mood("hall")
	check(_mgr._has_combat, "hall has a combat layer")
	_mgr._process(0.1)
	check(_mgr.combat_mix == 0.0, "calm at start")
	var ev: Node = autoload("Events")
	ev.enemy_alerted.emit("mouse", Vector3.ZERO)
	for i: int in 20:
		_mgr._process(0.1)
	check(_mgr.combat_mix > 0.99, "combat after alert %f" % _mgr.combat_mix)
	for i: int in 200:
		_mgr._process(0.1)
	check(_mgr.combat_mix < 0.01, "back to calm %f" % _mgr.combat_mix)
	ev.player_hurt.emit(3)
	check(_mgr._combat_timer > 5.0, "player_hurt triggers combat")
	_mgr.play_music("boss")
	check(not _mgr._has_combat, "boss is a single full-intensity track")
