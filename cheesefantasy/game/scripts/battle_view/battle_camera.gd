class_name BattleCamera
extends Camera3D
## Battle camera (owner battle-presentation): named shots with smooth moves or hard cuts, gentle idle drift, shake.
## The camera always looks at `focus`; moves tween `rig_pos` + `focus` together.

var rig_pos: Vector3 = Vector3(0.6, 3.0, 8.4)
var focus: Vector3 = Vector3(0, 0.9, 0)
var drift: float = 1.0
var _shake: float = 0.0
var _shake_t: float = 0.0
var _time: float = 0.0
var _tw: Tween
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const WIDE_POS: Vector3 = Vector3(0.6, 3.0, 8.4)
const WIDE_FOCUS: Vector3 = Vector3(0, 0.9, 0)


func _ready() -> void:
	fov = 50.0
	far = 400.0
	_apply()


func _process(delta: float) -> void:
	_time += delta
	if _shake_t > 0.0:
		_shake_t -= delta
	_apply()


func _apply() -> void:
	var d: Vector3 = Vector3(sin(_time * 0.37) * 0.25, sin(_time * 0.53) * 0.08, cos(_time * 0.29) * 0.15) * drift
	var s: Vector3 = Vector3.ZERO
	if _shake_t > 0.0:
		var k: float = _shake * clampf(_shake_t * 3.0, 0.0, 1.0)
		s = Vector3(_rng.randf_range(-k, k), _rng.randf_range(-k, k), _rng.randf_range(-k, k) * 0.3)
	global_position = rig_pos + d + s
	if not global_position.is_equal_approx(focus):
		look_at(focus + s * 0.5, Vector3.UP)


func shake(strength: float, duration: float) -> void:
	_shake = maxf(strength, _shake if _shake_t > 0.0 else 0.0)
	_shake_t = maxf(duration, _shake_t)


## Move to a shot. dur <= 0 = hard cut.
func move_to(pos: Vector3, look: Vector3, dur: float = 0.5, p_fov: float = 50.0) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if dur <= 0.0:
		rig_pos = pos
		focus = look
		fov = p_fov
		_apply()
		return
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "rig_pos", pos, dur)
	_tw.tween_property(self, "focus", look, dur)
	_tw.tween_property(self, "fov", p_fov, dur)


func wide(dur: float = 0.6) -> void:
	move_to(WIDE_POS, WIDE_FOCUS, dur, 50.0)


## 3/4 view from behind an actor's side that keeps BOTH sides of the field in frame (command menu, enemy turns).
func over_shoulder(actor_pos: Vector3, side: String, dur: float = 0.45) -> void:
	var s: float = 1.0 if side == "party" else -1.0
	move_to(Vector3(actor_pos.x * 0.5 + 1.4 * s, 3.1, actor_pos.z * 0.4 + 7.8), Vector3(-0.5 * s, 0.35, actor_pos.z * 0.25), dur, 52.0)


## Side-on two-shot of attacker and target (both in frame).
func two_shot(a: Vector3, b: Vector3, dur: float = 0.35) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var d: float = Vector2(a.x - b.x, a.z - b.z).length()
	move_to(mid + Vector3(0, 2.2, maxf(5.5, d * 1.05)), mid + Vector3(0, 1.0, 0), dur, 50.0)


## Close-up on someone being hit / acting.
func close_on(p: Vector3, side: String, h: float, dur: float = 0.35) -> void:
	var s: float = 1.0 if side == "party" else -1.0
	move_to(p + Vector3(-2.6 * s, h * 0.75 + 0.6, 3.2), p + Vector3(0, h * 0.55, 0), dur, 40.0)


## Look across a whole side (for all-target spells).
func side_view(side: String, dur: float = 0.45) -> void:
	var x: float = 3.6 if side == "party" else -3.6
	move_to(Vector3(x * 0.1, 3.0, 8.0), Vector3(x, 0.9, 0), dur, 48.0)


## Orbit around a point (summon sweep). Tweened via the returned Tween.
func orbit(center: Vector3, radius: float, height: float, from_deg: float, to_deg: float, dur: float, p_fov: float = 55.0) -> Tween:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	fov = p_fov
	_tw = create_tween()
	_tw.tween_method(func(a: float) -> void:
		var r: float = deg_to_rad(a)
		rig_pos = center + Vector3(sin(r) * radius, height, cos(r) * radius)
		focus = center + Vector3(0, 1.2, 0), from_deg, to_deg, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _tw
