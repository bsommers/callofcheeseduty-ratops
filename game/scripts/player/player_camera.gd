class_name RatPlayerCamera
extends Node3D
## Over-the-shoulder camera rig: yaw is applied to the player body (CS-style strafing), pitch to this pivot.
## Pivot -> SpringArm3D (collision-safe, sphere probe) -> Camera3D. Shoulder swap mirrors the lateral offset;
## hold-to-ADS shortens the arm, tightens the offset and narrows the FOV. No head bob.
## Mouse look (Settings.mouse_sensitivity, invert_y) and gamepad look (look_* actions, gamepad_sensitivity).

const PITCH_MIN: float = deg_to_rad(-75.0)
const PITCH_MAX: float = deg_to_rad(70.0)

@export var pivot_height: float = 1.62
@export var shoulder_offset: float = 0.7
@export var arm_length: float = 2.6
@export var ads_arm_length: float = 1.7
@export var ads_shoulder_offset: float = 0.8
@export var fov: float = 70.0
@export var ads_fov: float = 48.0
@export var crouch_drop: float = 0.5
@export var blend_speed: float = 12.0

## Body that receives the yaw (the player). Set by the player.
var body: Node3D = null
var yaw: float = 0.0
var pitch: float = 0.0
var shoulder_side: float = 1.0       # +1 right shoulder, -1 left
var aiming: bool = false
var crouch_amount: float = 0.0       # 0..1, fed by the player
## Recoil offset (x = pitch up, y = yaw), radians; added to the view without changing the stored aim.
var recoil: Vector2 = Vector2.ZERO
## When false, device input is ignored (tests / cutscenes).
var accept_input: bool = true

var spring: SpringArm3D = null
var camera: Camera3D = null
var _side_cur: float = 1.0
var _ads_cur: float = 0.0
var _excluded: bool = false


func _ready() -> void:
	position = Vector3(0.0, pivot_height, 0.0)
	spring = SpringArm3D.new()
	spring.name = "SpringArm"
	spring.spring_length = arm_length
	spring.collision_mask = 1 | 64
	spring.margin = 0.15
	var probe := SphereShape3D.new()
	probe.radius = 0.22
	spring.shape = probe
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = fov
	camera.near = 0.05
	camera.far = 400.0
	spring.add_child(camera)
	var s: Variant = _setting("game", "shoulder")
	if s != null and str(s) == "left":
		shoulder_side = -1.0
	_side_cur = shoulder_side
	_apply(0.0)


func _setting(section: String, key: String) -> Variant:
	var st: Node = get_node_or_null("/root/Settings")
	if st != null and st.has_method("get_value"):
		return st.call("get_value", section, key)
	return null


func mouse_sensitivity() -> float:
	var v: Variant = _setting("input", "mouse_sensitivity")
	return float(v) if v != null else 0.0025


func _unhandled_input(event: InputEvent) -> void:
	if not accept_input:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens: float = mouse_sensitivity() * (0.6 if aiming else 1.0)
		var inv: float = -1.0 if bool(_setting("input", "invert_y")) else 1.0
		add_look(-mm.relative.x * sens, -mm.relative.y * sens * inv)
	elif event.is_action_pressed("shoulder_swap"):
		swap_shoulder()


func add_look(d_yaw: float, d_pitch: float) -> void:
	yaw = wrapf(yaw + d_yaw, -PI, PI)
	pitch = clampf(pitch + d_pitch, PITCH_MIN, PITCH_MAX)


func swap_shoulder() -> void:
	shoulder_side = -shoulder_side


func _process(delta: float) -> void:
	if accept_input:
		var g: Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up")
		if g.length() > 0.0:
			var gs: Variant = _setting("input", "gamepad_sensitivity")
			var rate: float = (float(gs) if gs != null else 3.0) * (0.5 if aiming else 1.0)
			var inv: float = -1.0 if bool(_setting("input", "invert_y")) else 1.0
			add_look(-g.x * rate * delta, g.y * rate * delta * inv)
	_apply(delta)


## Push yaw to the body and pitch/offsets to the rig. delta 0 = snap.
func _apply(delta: float) -> void:
	var k: float = 1.0 if delta <= 0.0 else clampf(blend_speed * delta, 0.0, 1.0)
	_side_cur = lerpf(_side_cur, shoulder_side, k)
	_ads_cur = lerpf(_ads_cur, 1.0 if aiming else 0.0, k)
	sync_rotation()
	if body != null:
		if not _excluded and spring != null and body is CollisionObject3D:
			spring.add_excluded_object((body as CollisionObject3D).get_rid())
			_excluded = true
	position = Vector3(0.0, pivot_height - crouch_drop * crouch_amount, 0.0)
	if spring != null:
		spring.spring_length = lerpf(arm_length, ads_arm_length, _ads_cur)
		spring.position = Vector3(lerpf(shoulder_offset, ads_shoulder_offset, _ads_cur) * _side_cur, 0.0, 0.0)
	if camera != null:
		camera.fov = lerpf(fov, ads_fov, _ads_cur)


## Apply yaw (to the body) and pitch + recoil (to the pivot) immediately; the player calls this before
## firing so the aim ray matches the current look even when physics runs ahead of _process.
func sync_rotation() -> void:
	if body != null:
		body.rotation.y = yaw
	rotation = Vector3(pitch + recoil.x, recoil.y, 0.0)


## Horizontal forward of the view (for movement).
func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func flat_right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))
