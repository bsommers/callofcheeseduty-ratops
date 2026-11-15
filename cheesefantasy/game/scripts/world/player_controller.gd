class_name WorldPlayer
extends CharacterBody3D
## Third-person party leader with chase camera (orbit with cam_left/cam_right or right-mouse drag).

const WALK := 4.6
const RUN := 8.0
const GRAVITY := 24.0

var model: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := 0.38
var distance := 6.5
var _anim := ""
var _prompt_label: Label
var _prompt_box: Control
var _target: WorldInteractable
var _facing := 0.0
var _steps := 0.0
var area_checks: Array = []   # [{id, pos(Vector2), radius}]
var _in_area := ""
var grass_zones: Array = []
var _dragging := false

signal encounter_roll(zone: String)

func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.0
	cs.shape = cap
	cs.position.y = 0.5
	add_child(cs)
	model = WorldModels.spawn_actor("hero_fennel", 0.95, Color(0.95, 0.6, 0.25))
	add_child(model)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	_build_prompt()
	_snap_camera()

func _build_prompt() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	_prompt_box = HBoxContainer.new()
	_prompt_box.add_theme_constant_override("separation", 16)
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.offset_top = -190
	_prompt_box.offset_bottom = -120
	_prompt_box.offset_left = -500
	_prompt_box.offset_right = 500
	_prompt_box.visible = false
	var key := PanelContainer.new()  # keycap icon
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.9, 0.7)
	sb.border_color = Color(0.55, 0.33, 0.1)
	sb.set_border_width_all(4)
	sb.border_width_bottom = 8
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	key.add_theme_stylebox_override("panel", sb)
	var kl := Label.new()
	kl.text = "E"
	kl.add_theme_font_size_override("font_size", 34)
	kl.add_theme_color_override("font_color", Color(0.3, 0.16, 0.05))
	key.add_child(kl)
	_prompt_box.add_child(key)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 30)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_prompt_label.add_theme_constant_override("outline_size", 10)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompt_label)
	cl.add_child(_prompt_box)
	add_child(cl)

static func _axis(neg: String, pos: String, kneg: Key, kpos: Key, kneg2: Key = KEY_NONE, kpos2: Key = KEY_NONE) -> float:
	if InputMap.has_action(neg) and InputMap.has_action(pos):
		return Input.get_action_strength(pos) - Input.get_action_strength(neg)
	var v := 0.0
	if Input.is_physical_key_pressed(kpos) or (kpos2 != KEY_NONE and Input.is_physical_key_pressed(kpos2)):
		v += 1.0
	if Input.is_physical_key_pressed(kneg) or (kneg2 != KEY_NONE and Input.is_physical_key_pressed(kneg2)):
		v -= 1.0
	return v

static func _pressed(action: String, keys: Array) -> bool:
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		yaw -= (event as InputEventMouseMotion).relative.x * 0.006
		pitch = clampf(pitch + (event as InputEventMouseMotion).relative.y * 0.004, 0.08, 1.1)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.5, 3.0, 12.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.5, 3.0, 12.0)
	var wants := false
	if InputMap.has_action("interact"):
		wants = event.is_action_pressed("interact")
	elif event is InputEventKey:
		wants = event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.physical_keycode == KEY_SPACE)
	if wants and not WorldBus.locked and _target != null:
		get_viewport().set_input_as_handled()
		_target.interact(self)

func _physics_process(delta: float) -> void:
	var locked := WorldBus.locked
	var ix := 0.0 if locked else _axis("move_left", "move_right", KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT)
	var iz := 0.0 if locked else _axis("move_up", "move_down", KEY_W, KEY_S, KEY_UP, KEY_DOWN)
	var orbit := _axis("cam_left", "cam_right", KEY_Q, KEY_C)
	yaw -= orbit * 1.8 * delta
	var dir := Vector3(ix, 0, iz)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var basis_yaw := Basis(Vector3.UP, yaw)
	var world_dir := basis_yaw * dir
	var running := _pressed("run", [KEY_SHIFT])
	var spd := RUN if running else WALK
	var target_v := world_dir * spd
	velocity.x = move_toward(velocity.x, target_v.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, target_v.z, 40.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Vector3(0, 3, 4)
		velocity = Vector3.ZERO
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	if moving:
		_facing = lerp_angle(_facing, atan2(velocity.x, velocity.z), clampf(delta * 12.0, 0.0, 1.0))
		model.rotation.y = _facing
		_steps += Vector2(velocity.x, velocity.z).length() * delta
	var want_anim := "idle"
	if moving:
		want_anim = "run" if running else "walk"
	if want_anim != _anim:
		_anim = want_anim
		WorldModels.play(model, want_anim)
	_check_interactables()
	_check_areas()
	_check_grass()

func _check_interactables() -> void:
	var best: WorldInteractable = null
	var best_d := 1e9
	if not WorldBus.locked:
		for n in get_tree().get_nodes_in_group("interactable"):
			var it := n as WorldInteractable
			if it == null or not it.is_inside_tree():
				continue
			var d := it.global_position.distance_to(global_position)
			if d < it.interact_radius and d < best_d:
				best_d = d
				best = it
	_target = best
	_prompt_box.visible = best != null
	if best != null:
		_prompt_label.text = str(best.prompt)

func _check_areas() -> void:
	var p := Vector2(global_position.x, global_position.z)
	var cur := ""
	for a: Dictionary in area_checks:
		if p.distance_to(a["pos"]) < a["radius"]:
			cur = a["id"]
			break
	if cur != _in_area:
		_in_area = cur
		if cur != "":
			WorldBus.emit(&"area_entered", [cur])

func _check_grass() -> void:
	if WorldBus.locked or _steps < 6.0:
		return
	var p := Vector2(global_position.x, global_position.z)
	for r: Rect2 in grass_zones:
		if r.has_point(p):
			_steps = 0.0
			if randf() < 0.22:
				encounter_roll.emit("grass")
			return
	_steps = minf(_steps, 5.0)

func _snap_camera() -> void:
	cam.global_position = _desired_cam_pos()
	_look()

func _desired_cam_pos() -> Vector3:
	var focus := global_position + Vector3(0, 1.3, 0)
	var off := Basis(Vector3.UP, yaw) * Vector3(0, sin(pitch), cos(pitch)) * distance
	var want := focus + off
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(focus, want, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = hit["position"] + (focus - want).normalized() * 0.3
	return want

func _look() -> void:
	cam.look_at(global_position + Vector3(0, 1.1, 0), Vector3.UP)

func _process(delta: float) -> void:
	var want := _desired_cam_pos()
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 9.0, 0.0, 1.0))
	_look()
