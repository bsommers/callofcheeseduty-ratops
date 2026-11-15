class_name WorldMob
extends WorldInteractable
## Visible roaming enemy: patrols near home, chases when the player gets close,
## emits Events.battle_requested(encounter_id) on touch.

@export var mob_id: String = ""
@export var model_id: String = "enemy_rat_grunt"
@export var encounter_id: String = "meadow_grunts"
@export var model_height: float = 0.0
@export var patrol_radius: float = 6.0
@export var aggro_radius: float = 9.0
@export var patrol_speed: float = 1.4
@export var chase_speed: float = 3.6
@export var touch_radius: float = 1.3

var model: Node3D
var player: Node3D
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 1.0
var _anim := ""
var _fired := false
var _cooldown := 0.0
var _exclaim: Label3D

func _ready() -> void:
	remove_from_group("interactable")
	if WorldBus.get_flag("defeated_" + mob_id, false):
		queue_free()
		return
	model = WorldModels.spawn_actor(model_id, model_height, Color(0.45, 0.5, 0.35))
	add_child(model)
	_home = position
	_target = position
	snap_to_ground()
	_exclaim = Label3D.new()
	_exclaim.text = "!"
	_exclaim.font_size = 96
	_exclaim.pixel_size = 0.006
	_exclaim.modulate = Color(1, 0.3, 0.2)
	_exclaim.outline_size = 16
	_exclaim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exclaim.no_depth_test = true
	_exclaim.position.y = 2.2
	_exclaim.visible = false
	add_child(_exclaim)
	WorldBus.listen(&"battle_finished", _on_battle_finished)

func _exit_tree() -> void:
	WorldBus.unlisten(&"battle_finished", _on_battle_finished)

func _play(a: String) -> void:
	if a != _anim:
		_anim = a
		WorldModels.play(model, a)

func _on_battle_finished(result: Variant = null) -> void:
	if not _fired:
		return
	_fired = false
	var won := true
	if result is Dictionary:
		won = str(result.get("outcome", result.get("result", "win"))) in ["win", "victory", "won"] or result.get("won", true)
	elif result is String:
		won = result in ["win", "victory", "won"]
	elif result is bool:
		won = result
	if won:
		WorldBus.set_flag("defeated_" + mob_id, true)
		queue_free()
	else:
		_cooldown = 6.0
		position = _home

func _process(delta: float) -> void:
	if _fired or model == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	var chasing := false
	if player != null and _cooldown <= 0.0 and not WorldBus.locked:
		var dv := player.global_position - global_position
		dv.y = 0.0
		var dist := dv.length()
		if dist < aggro_radius:
			chasing = true
			position += dv.normalized() * chase_speed * delta
			rotation.y = lerp_angle(rotation.y, atan2(dv.x, dv.z) + PI, clampf(delta * 8.0, 0.0, 1.0))
			_play("run")
			if dist < touch_radius:
				_fired = true
				_play("attack")
				WorldBus.locked = true
				WorldBus.emit(&"battle_requested", [WorldBus.resolve_encounter(encounter_id)])
	_exclaim.visible = chasing
	if not chasing and not _fired:
		_patrol(delta)
	snap_to_ground()

func _patrol(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_play("idle")
		if _wait <= 0.0:
			var a := randf() * TAU
			_target = _home + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, patrol_radius)
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.3:
		_wait = randf_range(1.0, 3.5)
		return
	position += to.normalized() * patrol_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z) + PI, clampf(delta * 6.0, 0.0, 1.0))
	_play("walk")
