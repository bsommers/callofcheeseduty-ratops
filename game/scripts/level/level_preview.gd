class_name LevelPreview
extends Node3D
## Preview helper. User args (after `--`): --level=e1m1 --mode=top|fly|walk --out=/path.png
## top: orthographic top-down camera over the whole map. fly: camera follows the player start -> exit path loop.

var builder: LevelBuilder
var cam: Camera3D
var _t: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var mode: String = "top"

static func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return def

func _ready() -> void:
	mode = _arg("mode", "top")
	builder = LevelBuilder.new()
	add_child(builder)
	if not builder.build_level(_arg("level", "e1m1")):
		push_error("LevelPreview: build failed")
		return
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	builder.focus = cam
	var w := builder._w * builder.cell
	var h := builder._h * builder.cell
	if mode == "top":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(w, h) * 1.02
		cam.far = 200.0
		cam.position = Vector3(w * 0.5, 100.0, h * 0.5)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		# ceilings would hide the layout: hide ceiling meshes
		for m in builder.get_node("Geometry").get_children():
			if m is MeshInstance3D and str(m.name).begins_with("Mesh_ceil"):
				m.visible = false
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-90, 0, 0)
		add_child(sun)
		(builder.get_node("LevelEnvironment") as WorldEnvironment).environment.ambient_light_energy = 6.0
	else:
		_path = _make_path()
		cam.position = _path[0]

func _make_path() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var a := builder.cell_center(int(builder.data["start"]["x"]), int(builder.data["start"]["y"]), 1.7)
	var b := builder.cell_center(builder.exit_cell.x, builder.exit_cell.y, 1.7)
	# BFS over walkable cells (doors open) start -> exit neighbour
	var s := Vector2i(int(builder.data["start"]["x"]), int(builder.data["start"]["y"]))
	var prev := {s: s}
	var q: Array[Vector2i] = [s]
	var goal := Vector2i(-1, -1)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if absi(c.x - builder.exit_cell.x) + absi(c.y - builder.exit_cell.y) <= 1:
			goal = c
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and (builder._is_walkable(n.x, n.y) or builder._push_cells.has(n)):
				prev[n] = c
				q.append(n)
	if goal.x < 0:
		return PackedVector3Array([a, b])
	var cells: Array[Vector2i] = []
	var cur := goal
	while cur != s:
		cells.push_front(cur)
		cur = prev[cur]
	cells.push_front(s)
	for c in cells:
		pts.append(builder.cell_center(c.x, c.y, 1.7))
	return pts

func path_length() -> int:
	return _path.size()

func _process(delta: float) -> void:
	if mode != "fly" or _path.size() < 2:
		return
	_t += delta * 6.0
	var i := int(_t) % (_path.size() - 1)
	var f := _t - floorf(_t)
	cam.position = _path[i].lerp(_path[i + 1], f)
	var look := _path[mini(i + 2, _path.size() - 1)]
	if look.distance_to(cam.position) > 0.1:
		cam.look_at(look)
