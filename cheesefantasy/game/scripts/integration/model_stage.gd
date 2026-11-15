class_name ModelStage
extends SubViewportContainer
## Rotating 3D model on a transparent stage. The camera is auto-framed from the model's measured AABB,
## so any model size (3.3 m Rat King, 3 m summons, 1.2 m heroes) is fully visible.

var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _model: Node3D
var _t: float = 0.0
var spin: float = 0.5
var tint: Color = Color(1, 1, 1)


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(420, 420)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(420, 420)
	add_child(_vp)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.75)
	env.ambient_light_energy = 0.8
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 1.4
	_vp.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.7, 0.8, 1.0)
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 40.0
	_vp.add_child(_cam)


func show_model(model_id: String) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	_model = ActorFactory.spawn(model_id)
	_pivot.add_child(_model)
	_pivot.rotation = Vector3.ZERO
	var rig: Object = _model
	if rig.has_method("play"):
		rig.call("play", "idle")
	var box: AABB = ActorFactory.measure(_model)
	var size: float = maxf(box.size.y, maxf(box.size.x, box.size.z))
	if size < 0.1:
		size = 2.0
	var center: Vector3 = box.position + box.size * 0.5
	var dist: float = (size * 0.5) / tan(deg_to_rad(_cam.fov * 0.5)) * 1.25 + box.size.z * 0.5
	_cam.position = center + Vector3(0, size * 0.08, dist)
	_cam.look_at(center)
	_pivot.position = Vector3.ZERO
	_pivot.set_meta("center", center)


func _process(delta: float) -> void:
	if _model == null or not visible:
		return
	_t += delta
	var c: Vector3 = _pivot.get_meta("center", Vector3.ZERO)
	# Rotate around the model's own centre column.
	var a: float = PI + sin(_t * spin) * 0.9  # models face -Z; turn them to the camera and sway
	_pivot.position = Vector3(c.x, 0, c.z) - Basis(Vector3.UP, a) * Vector3(c.x, 0, c.z)
	_pivot.rotation.y = a
