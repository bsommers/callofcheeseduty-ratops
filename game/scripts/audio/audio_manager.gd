class_name AudioManager
extends Node
## AudioManager — buses, pooled 3D one-shots, ambience, music, zone reverb (ARCHITECTURE sections 4 and 6).
## Instance res://scenes/audio_manager.tscn once (it can replace the minimal `Audio` autoload).
## Listens ONLY to `Events` signals; every signal is connected defensively (missing ones are skipped).
## Sounds live in res://assets/audio/{sfx,amb,music}/ and are produced by tools/gen_audio.py.

const SFX_DIR: String = "res://assets/audio/sfx/"
const AMB_DIR: String = "res://assets/audio/amb/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const BUSES: Array[String] = ["Music", "SFX", "UI", "Ambience"]
const POOL_3D: int = 24
const POOL_2D: int = 8
const MAX_DISTANCE: float = 45.0
const XFADE: float = 1.5
const SURFACES: Array[String] = ["stone", "wood", "metal", "wet"]
const LEVEL_MOOD: Dictionary = {"e1m1": "cellar", "e1m2": "cellar", "e1m3": "sewer", "e1m4": "sewer", "e1m5": "hall", "e1m6": "hall"}
const MOOD_SURFACE: Dictionary = {"cellar": "stone", "sewer": "wet", "hall": "wood"}
## Reverb preset per zone type: room_size, damp, wet, pre-delay ms
const ZONES: Dictionary = {
	"room": [0.35, 0.6, 0.12, 10.0], "cellar": [0.55, 0.5, 0.2, 20.0], "sewer": [0.8, 0.35, 0.3, 30.0],
	"hall": [0.9, 0.3, 0.28, 45.0], "corridor": [0.45, 0.45, 0.15, 12.0], "outdoor": [0.2, 0.7, 0.05, 5.0],
}
## Settings key per bus (UI and Ambience follow "sfx"); trim in dB on top of the Settings volume
const BUS_KEY: Dictionary = {"Master": "master", "Music": "music", "SFX": "sfx", "UI": "sfx", "Ambience": "sfx"}
const BUS_TRIM_DB: Dictionary = {"Master": 0.0, "Music": -8.0, "SFX": 0.0, "UI": -2.0, "Ambience": -8.0}
## Per-sound extra gain (dB) and random pitch spread
const GAIN_DB: Dictionary = {"footstep_sprint": 2.0, "footstep_crouch": -8.0, "laser": -2.0, "explosion": 0.0}
const PICKUP_SOUND: Dictionary = {
	"health": "pickup_health", "fish_treat": "pickup_health", "tuna": "pickup_health", "catnip": "pickup_catnip", "ammo": "pickup_ammo",
	"ammo_clip": "pickup_ammo", "ammo_box": "pickup_ammo", "yarn_ammo": "pickup_ammo", "battery": "pickup_ammo", "weapon": "pickup_weapon",
	"gatling": "pickup_weapon", "yarn_launcher": "pickup_weapon", "laser": "pickup_weapon", "key": "pickup_key", "key_gold": "pickup_key",
	"key_silver": "pickup_key", "treasure": "pickup_treasure", "cheddar_wedge": "pickup_treasure", "brie_wheel": "pickup_treasure",
	"cheese_crown": "pickup_treasure", "extra_life": "extra_life", "life": "extra_life",
}

## When false the manager ignores Events.sfx (use if another node already plays it).
@export var handle_sfx_signal: bool = true
@export var enable_playback: bool = true

var mood: String = "cellar"
var zone: String = "room"
var surface: String = "stone"
var _cache: Dictionary = {}          # name -> AudioStream (null if missing)
var _variants: Dictionary = {}       # base name -> Array[String] of stream names
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var _music_track: String = ""
var _music_c: Array[AudioStreamPlayer] = []   # combat layer, played in sync with _music
var _slot_db: Array[float] = [-80.0, -80.0]  # per-slot fade (dB), driven by the track crossfade
var _has_combat: bool = false
var combat_mix: float = 0.0                  # 0 = exploration layer, 1 = combat layer (smoothed)
var _combat_timer: float = 0.0
var _amb: AudioStreamPlayer
var _amb_track: String = ""
var _reverb: AudioEffectReverb
var _tween_music: Tween
var _last_played: Dictionary = {}    # name -> msec, anti-spam
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	ensure_buses()
	_build_pools()
	_connect_events()
	apply_volumes()
	set_zone(zone)


# ------------------------------------------------------------------ buses
static func ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var sfx: int = AudioServer.get_bus_index("SFX")
	var has_rev: bool = false
	for i: int in AudioServer.get_bus_effect_count(sfx):
		if AudioServer.get_bus_effect(sfx, i) is AudioEffectReverb:
			has_rev = true
	if not has_rev:
		var rv: AudioEffectReverb = AudioEffectReverb.new()
		AudioServer.add_bus_effect(sfx, rv)


func apply_volumes() -> void:
	var st: Node = get_node_or_null("/root/Settings")
	for b: String in BUS_KEY.keys():
		var idx: int = AudioServer.get_bus_index(b)
		if idx < 0:
			continue
		var v: float = 1.0
		if st != null:
			v = clampf(float(st.get_value("audio", BUS_KEY[b])), 0.0, 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)) + float(BUS_TRIM_DB[b]))


func set_zone(z: String) -> void:
	if not ZONES.has(z):
		z = "room"
	zone = z
	var sfx: int = AudioServer.get_bus_index("SFX")
	for i: int in AudioServer.get_bus_effect_count(sfx):
		var e: AudioEffect = AudioServer.get_bus_effect(sfx, i)
		if e is AudioEffectReverb:
			var p: Array = ZONES[z]
			var rv: AudioEffectReverb = e as AudioEffectReverb
			rv.room_size = float(p[0])
			rv.damping = float(p[1])
			rv.wet = float(p[2])
			rv.dry = 1.0 - float(p[2]) * 0.5
			rv.predelay_msec = float(p[3])
			_reverb = rv


func _build_pools() -> void:
	for i: int in POOL_3D:
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.max_distance = MAX_DISTANCE
		p.unit_size = 6.0
		p.max_polyphony = 1
		add_child(p)
		_pool3d.append(p)
	for i: int in POOL_2D:
		var q: AudioStreamPlayer = AudioStreamPlayer.new()
		q.bus = "SFX"
		add_child(q)
		_pool2d.append(q)
	for i: int in 2:
		var m: AudioStreamPlayer = AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
		var c: AudioStreamPlayer = AudioStreamPlayer.new()
		c.bus = "Music"
		c.volume_db = -80.0
		add_child(c)
		_music_c.append(c)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	_amb.volume_db = -80.0
	add_child(_amb)


# ------------------------------------------------------------------ streams
func get_stream(sound: String, dir: String = SFX_DIR, looped: bool = false) -> AudioStream:
	var key: String = dir + sound
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for ext: String in [".wav", ".ogg"]:
		var path: String = key + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		if looped:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))  # sample count (data.size() is wrong for QOA-compressed imports)
		s = w
	_cache[key] = s
	return s


## Resolve a logical sound name to a concrete stream name (picks a random variant); "" when unknown.
func resolve(sound: String) -> String:
	match sound:
		"footstep", "footstep_sprint", "footstep_crouch":
			return "step_%s_%d" % [surface, _rng.randi_range(1, 4)]
		"ricochet":
			return "ricochet_%d" % _rng.randi_range(1, 3)
		"hit_flesh", "headshot", "player_hurt", "player_die":
			return sound
		"player_hurt_sfx":
			return "player_hurt"
	return sound


func has_sound(sound: String) -> bool:
	var n: String = resolve(sound)
	return n != "" and get_stream(n) != null


# ------------------------------------------------------------------ playback
## Play a one-shot. `pos == Vector3.INF` -> non-positional. Returns the player used (or null).
func play(sound: String, pos: Vector3 = Vector3.INF, vol_db: float = 0.0, pitch: float = 1.0) -> Node:
	if not enable_playback or sound == "":
		return null
	var name: String = resolve(sound)
	var st: AudioStream = get_stream(name)
	if st == null:
		return null
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 25 and not name.begins_with("step_"):
		return null  # identical sound within 25 ms: drop (gatling stacking)
	_last_played[name] = now
	var db: float = vol_db + float(GAIN_DB.get(sound, 0.0))
	var spread: float = 0.04 if name.begins_with("ui_") else 0.07
	var pt: float = pitch * (1.0 + _rng.randf_range(-spread, spread))
	var bus: String = _bus_for(name)
	if pos == Vector3.INF or bus == "UI":
		var q: AudioStreamPlayer = _take_2d()
		q.stream = st
		q.bus = bus
		q.volume_db = db
		q.pitch_scale = pt
		q.play()
		return q
	var p: AudioStreamPlayer3D = _take_3d()
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pt
	if p.is_inside_tree():
		p.global_position = pos
	p.play()
	return p


func _bus_for(name: String) -> String:
	if name.begins_with("ui_"):
		return "UI"
	return "SFX"


func _take_3d() -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = _pool3d[0]
	for p: AudioStreamPlayer3D in _pool3d:
		if not p.playing:
			return p
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	oldest.stop()
	return oldest


func _take_2d() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = _pool2d[0]
	for p: AudioStreamPlayer in _pool2d:
		if not p.playing:
			return p
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	oldest.stop()
	return oldest


func active_voices() -> int:
	var n: int = 0
	for p: AudioStreamPlayer3D in _pool3d:
		n += 1 if p.playing else 0
	for q: AudioStreamPlayer in _pool2d:
		n += 1 if q.playing else 0
	return n


func pool_size() -> int:
	return _pool3d.size() + _pool2d.size()


func play_music(track: String) -> void:
	if track == "" or track == "stop":
		_fade_music(null, "")
		return
	var name: String = track if track.begins_with("music_") else "music_" + track
	if name == _music_track:
		return
	var st: AudioStream = get_stream(name, MUSIC_DIR, true)
	if st == null:
		return
	_fade_music(st, name)


func _fade_music(st: AudioStream, name: String) -> void:
	_music_track = name
	if _tween_music != null and _tween_music.is_valid():
		_tween_music.kill()
	var oi: int = _music_cur
	_music_cur = 1 - _music_cur
	var ni: int = _music_cur
	_tween_music = create_tween().set_parallel(true)
	var from_old: float = _slot_db[oi]
	_tween_music.tween_method(func(v: float) -> void: _slot_db[oi] = v, from_old, -80.0, XFADE)
	if st != null:
		var cst: AudioStream = get_stream(name + "_combat", MUSIC_DIR, true)
		_has_combat = cst != null
		_music[ni].stream = st
		_music_c[ni].stream = cst
		_slot_db[ni] = -80.0
		_music[ni].play()
		if cst != null:
			_music_c[ni].play()  # started on the same frame as the calm layer: the loops stay in sync
		_tween_music.tween_method(func(v: float) -> void: _slot_db[ni] = v, -80.0, 0.0, XFADE)
	_tween_music.chain().tween_callback(func() -> void:
		if _slot_db[oi] <= -79.0:
			_music[oi].stop()
			_music_c[oi].stop())


## Switch the music to its full-intensity layer for `seconds` (extends, never shortens, a running combat).
func alert_combat(seconds: float = 14.0) -> void:
	_combat_timer = maxf(_combat_timer, seconds)


func _process(delta: float) -> void:
	_combat_timer = maxf(_combat_timer - delta, 0.0)
	combat_mix = move_toward(combat_mix, 1.0 if _combat_timer > 0.0 else 0.0, delta / (0.7 if _combat_timer > 0.0 else 3.0))
	if _music.is_empty():
		return
	var calm_db: float = 0.0
	var combat_db: float = -80.0
	if _has_combat:
		calm_db = linear_to_db(maxf(cos(combat_mix * PI * 0.5), 0.0001))
		combat_db = linear_to_db(maxf(sin(combat_mix * PI * 0.5), 0.0001))
	for i: int in 2:
		_music[i].volume_db = maxf(_slot_db[i] + calm_db, -80.0)
		_music_c[i].volume_db = maxf(_slot_db[i] + combat_db, -80.0)


func play_ambience(track: String) -> void:
	var name: String = track if track.begins_with("amb_") else "amb_" + track
	if track == "" or name == _amb_track:
		return
	var st: AudioStream = get_stream(name, AMB_DIR, true)
	if st == null:
		return
	_amb_track = name
	_amb.stream = st
	_amb.volume_db = -80.0
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", 0.0, XFADE)


func set_mood(m: String) -> void:
	if not MOOD_SURFACE.has(m):
		return
	mood = m
	surface = MOOD_SURFACE[m]
	set_zone(m)
	play_ambience(m)
	play_music(m)


func set_surface(s: String) -> void:
	if SURFACES.has(s):
		surface = s


func stop_all() -> void:
	for p: AudioStreamPlayer3D in _pool3d:
		p.stop()
	for q: AudioStreamPlayer in _pool2d:
		q.stop()


# ------------------------------------------------------------------ Events wiring
func _connect_events() -> void:
	var ev: Node = get_node_or_null("/root/Events")
	if ev == null:
		return
	_link(ev, "sfx", _on_sfx)
	_link(ev, "music", play_music)
	_link(ev, "player_hurt", func(_d: int) -> void:
		play("player_hurt")
		alert_combat(10.0))
	_link(ev, "noise", func(_p: Vector3, radius: float) -> void:
		if radius >= 10.0:
			alert_combat(8.0))
	_link(ev, "player_died", func() -> void: play("player_die"))
	_link(ev, "enemy_killed", _on_enemy_killed)
	_link(ev, "enemy_alerted", _on_enemy_alerted)
	_link(ev, "enemy_hurt", _on_enemy_hurt)
	_link(ev, "pickup_taken", _on_pickup)
	_link(ev, "key_taken", func(_c: String) -> void: play("pickup_key"))
	_link(ev, "weapon_changed", func(_id: String) -> void: play("weapon_switch"))
	_link(ev, "door_opened", func(_id: String) -> void: play("door_open"))
	_link(ev, "door_closed", func(_id: String) -> void: play("door_close"))
	_link(ev, "door_locked", func(_id: String) -> void: play("door_locked"))
	_link(ev, "secret_found", func() -> void: play("secret"))
	_link(ev, "level_completed", func(_s: Dictionary) -> void:
		play("level_complete")
		play_music("victory"))
	_link(ev, "level_loaded", _on_level)
	_link(ev, "level_started", _on_level)
	_link(ev, "settings_changed", apply_volumes)
	_link(ev, "shot_fired", _on_shot)
	_link(ev, "hit", _on_hit)


func _link(ev: Node, sig: String, cb: Callable) -> void:
	if ev.has_signal(sig):
		# Tolerate differing argument counts from other modules' signal definitions.
		var arity: int = 0
		for s: Dictionary in ev.get_signal_list():
			if s["name"] == sig:
				arity = (s["args"] as Array).size()
		ev.connect(sig, cb if cb.get_argument_count() == arity else cb.unbind(maxi(arity - cb.get_argument_count(), 0)))


func _on_sfx(sound: String, pos: Vector3) -> void:
	if handle_sfx_signal:
		play(sound, pos)


func _on_level(id: String) -> void:
	set_mood(String(LEVEL_MOOD.get(id, "cellar")))


func _on_enemy_killed(kind: String, pos: Vector3) -> void:
	play("death_" + _kind(kind), pos)
	alert_combat(8.0)
	if _rng.randf() < 0.15:
		play("cat_meow_%d" % _rng.randi_range(1, 3))  # confident hero quip


func _on_enemy_alerted(kind: Variant = "mouse", pos: Variant = Vector3.INF) -> void:
	alert_combat()
	var snd: String = "taunt_" if _rng.randf() < 0.25 else "bark_"
	play(snd + _kind(str(kind)), pos if pos is Vector3 else Vector3.INF)


func _on_enemy_hurt(kind: Variant = "mouse", pos: Variant = Vector3.INF) -> void:
	alert_combat(8.0)
	play("hurt_" + _kind(str(kind)), pos if pos is Vector3 else Vector3.INF)


func _on_pickup(kind: String, _amount: int) -> void:
	play(String(PICKUP_SOUND.get(kind, "pickup_ammo")))


func _on_shot(weapon: Variant = "pistol", pos: Variant = Vector3.INF) -> void:
	play(str(weapon), pos if pos is Vector3 else Vector3.INF)


func _on_hit(kind: Variant = "flesh", pos: Variant = Vector3.INF) -> void:
	var k: String = str(kind)
	play(k if k in ["hit_flesh", "headshot", "ricochet"] else ("hit_flesh" if k == "flesh" else "impact_" + k), pos if pos is Vector3 else Vector3.INF)


func _kind(k: String) -> String:
	return k if KINDS.has(k) else "mouse"


const KINDS: Array[String] = ["mouse", "trooper", "officer", "sewer", "panzer", "boss"]
