class_name ActorRig
extends Node3D
## Wrapper around a spawned character model (owner rpg-core). Created by ActorFactory.spawn().
## play(anim) resolves clip names tolerant of glTF prefixes ("Armature|idle", "lib/idle") and falls back to
## idle (then the first clip) so callers can ask for any ARCHITECTURE clip on any model.

signal anim_finished(anim: String)

const LOOPED: Array = ["idle", "walk", "run", "defend"]

var model_id: String = ""
var placeholder: bool = false
var player: AnimationPlayer
var model: Node3D
var height: float = 1.0
var _clips: Dictionary = {}   ## short name -> full animation name
var current: String = ""


func setup(id: String, root: Node3D, is_placeholder: bool) -> void:
	model_id = id
	placeholder = is_placeholder
	model = root
	add_child(root)
	player = find_player(root)
	_index_clips()
	if player != null and not player.animation_finished.is_connected(_on_finished):
		player.animation_finished.connect(_on_finished)


static func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c: Node in n.get_children():
		var p: AnimationPlayer = find_player(c)
		if p != null:
			return p
	return null


func _index_clips() -> void:
	_clips.clear()
	if player == null:
		return
	for full: String in player.get_animation_list():
		var short: String = full.get_slice("/", full.get_slice_count("/") - 1)
		short = short.get_slice("|", short.get_slice_count("|") - 1).to_lower()
		if not _clips.has(short):
			_clips[short] = full
		var anim: Animation = player.get_animation(full)
		if anim != null and short in LOOPED:
			anim.loop_mode = Animation.LOOP_LINEAR


func clips() -> Array:
	return _clips.keys()


func has_anim(anim: String) -> bool:
	return _clips.has(anim.to_lower())


## Plays `anim` (fallback chain: anim -> idle -> first clip). Returns the clip actually played ("" if none).
func play(anim: String, blend: float = 0.15, speed: float = 1.0) -> String:
	if player == null or _clips.is_empty():
		return ""
	var key: String = anim.to_lower()
	if not _clips.has(key):
		key = "idle" if _clips.has("idle") else str(_clips.keys()[0])
	current = key
	player.play(_clips[key], blend, speed)
	return key


## Plays a one-shot clip then returns to idle (or `then`).
func play_once(anim: String, then: String = "idle") -> void:
	var got: String = play(anim)
	if got == "" or got in LOOPED:
		return
	await player.animation_finished
	if current == got:
		play(then)


func clip_length(anim: String) -> float:
	if player == null or not _clips.has(anim.to_lower()):
		return 0.0
	return player.get_animation(_clips[anim.to_lower()]).length


## Multiplies the model's colours by `c` (enemy variants share one glb).
func set_tint(c: Color) -> void:
	if c == Color.WHITE:
		return
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = c
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for g: Node in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = mat


func _on_finished(full: StringName) -> void:
	for k: String in _clips:
		if _clips[k] == String(full):
			anim_finished.emit(k)
			return
