extends Node
## Audio autoload (owner rpg-core; streams/mixing by menus-audio). play_sfx(id) / play_music(id) look for
## res://assets/audio/sfx/<id>.(ogg|wav) and res://assets/audio/music/<id>.(ogg|wav); silently do nothing if missing.
## Creates "Music" and "Sfx" buses when the project has none.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const EXTS: Array = ["ogg", "wav", "mp3"]
const SFX_VOICES: int = 8

var _music: AudioStreamPlayer
var _sfx: Array = []
var _next_voice: int = 0
var _cache: Dictionary = {}
var current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b: String in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i: int in SFX_VOICES:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_sfx.append(p)


func _find(dir: String, id: String) -> AudioStream:
	var key: String = dir + id
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for e: String in EXTS:
		var path: String = "%s%s.%s" % [dir, id, e]
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	_cache[key] = s
	return s


func has_sfx(id: String) -> bool:
	return _find(SFX_DIR, id) != null


func play_sfx(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var s: AudioStream = _find(SFX_DIR, id)
	if s == null or _sfx.is_empty():
		return
	var p: AudioStreamPlayer = _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_music(id: String, fade: float = 0.6) -> void:
	if id == current_music and _music.playing:
		return
	current_music = id
	var s: AudioStream = _find(MUSIC_DIR, id)
	if s == null:
		_music.stop()
		return
	_music.stream = s
	_music.volume_db = -30.0 if fade > 0.0 else 0.0
	_music.play()
	if fade > 0.0:
		create_tween().tween_property(_music, "volume_db", 0.0, fade)


func _exit_tree() -> void:
	# release streams so a quick quit does not report leaked AudioStream instances
	if _music != null:
		_music.stop()
		_music.stream = null
	for p: AudioStreamPlayer in _sfx:
		p.stop()
		p.stream = null
	_cache.clear()


func stop_music() -> void:
	current_music = ""
	_music.stop()
