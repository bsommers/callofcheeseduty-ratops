class_name LevelBuilder
extends Node3D
## Builds a RAT OPS level at runtime from game/data/levels/eXmY.json (schema: see tools/convert_levels.mjs).
## World mapping: X = cellx*cell, Z = celly*cell (cell centre = (x+.5, y+.5)*cell), Y up, 1 unit = 1 m.

signal built(stats: Dictionary)

const LEVEL_DIR := "res://data/levels/"
const MATERIAL_MAP := "res://data/material_map.json"
const MAX_SHADOW_LIGHTS := 6

@export var shadow_lights: int = MAX_SHADOW_LIGHTS
@export var zone_light_spacing: int = 4
## Optional node whose position decides which lights cast shadows (camera/player).
var focus: Node3D

var data: Dictionary = {}
var cell: float = 4.0
var player_start: Transform3D = Transform3D.IDENTITY
var enemy_spawns: Array[Dictionary] = []
var exit_cell: Vector2i = Vector2i(-1, -1)
var exit_area: Area3D
var nav_region: NavigationRegion3D
var keys_held: Dictionary = {}
var stats: Dictionary = {}

var _grid: Array = []
var _zone_grid: Array = []
var _zones: Dictionary = {}
var _w: int = 0
var _h: int = 0
var _mat_map: Dictionary = {}
var _mat_cache: Dictionary = {}
var _door_cells: Dictionary = {}
var _push_cells: Dictionary = {}
var _lights: Array[OmniLight3D] = []
var _light_timer: float = 0.0
var _root_geo: Node3D
var _things_root: Node3D

static func load_level_json(id: String) -> Dictionary:
	var path := LEVEL_DIR + id + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelBuilder: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("LevelBuilder: bad json %s" % path)
	return {}

func build_level(id: String) -> bool:
	var d := load_level_json(id)
	if d.is_empty():
		return false
	return build(d)

func build(level: Dictionary) -> bool:
	clear()
	data = level
	cell = float(level.get("cellSize", 4.0))
	_grid = level.get("grid", [])
	_zone_grid = level.get("zoneGrid", [])
	_zones = level.get("zones", {})
	_h = _grid.size()
	_w = (_grid[0] as String).length() if _h > 0 else 0
	if _w == 0:
		push_error("LevelBuilder: empty grid")
		return false
	_load_material_map()
	for dd in level.get("doors", []):
		_door_cells[Vector2i(int(dd["x"]), int(dd["y"]))] = dd
	for pw in level.get("pushwalls", []):
		_push_cells[Vector2i(int(pw["x"]), int(pw["y"]))] = pw
	_root_geo = Node3D.new()
	_root_geo.name = "Geometry"
	add_child(_root_geo)
	_things_root = Node3D.new()
	_things_root.name = "Things"
	add_child(_things_root)
	_build_surfaces()
	_build_collision()
	_build_doors()
	_build_pushwalls()
	_build_things()
	_build_zone_lights()
	_build_navigation()
	_build_exit()
	_build_environment()
	var s := level.get("start", {}) as Dictionary
	var yaw := atan2(-cos(float(s.get("angle", 0.0))), -sin(float(s.get("angle", 0.0))))
	player_start = Transform3D(Basis(Vector3.UP, yaw), cell_center(int(s.get("x", 1)), int(s.get("y", 1)), 0.1))
	stats = (level.get("stats", {}) as Dictionary).duplicate()
	built.emit(stats)
	LevelEvents.emit(self, &"level_loaded", [str(level.get("id", ""))])
	return true

func clear() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	_lights.clear()
	enemy_spawns.clear()
	_door_cells.clear()
	_push_cells.clear()
	keys_held.clear()
	_mat_cache.clear()

# ---------------------------------------------------------------- helpers
func cell_center(cx: int, cy: int, y: float = 0.0) -> Vector3:
	return Vector3((cx + 0.5) * cell, y, (cy + 0.5) * cell)

func _ch(cx: int, cy: int) -> String:
	if cx < 0 or cy < 0 or cx >= _w or cy >= _h:
		return "#"
	return (_grid[cy] as String)[cx]

func _is_solid(cx: int, cy: int) -> bool:
	var c := _ch(cx, cy)
	if c == ".":
		return false
	var v := Vector2i(cx, cy)
	return not (_door_cells.has(v) or c == "D")

## Cells the player can stand in (open + door); pushwalls count as solid.
func _is_walkable(cx: int, cy: int) -> bool:
	var v := Vector2i(cx, cy)
	if _push_cells.has(v):
		return false
	return not _is_solid(cx, cy)

## Cells that need floor/ceiling geometry (walkable + pushwall).
func _has_floor(cx: int, cy: int) -> bool:
	return _is_walkable(cx, cy) or _push_cells.has(Vector2i(cx, cy))

func _zone(cx: int, cy: int) -> Dictionary:
	var key := "."
	if cy >= 0 and cy < _zone_grid.size() and cx >= 0 and cx < (_zone_grid[cy] as String).length():
		key = (_zone_grid[cy] as String)[cx]
	return _zones.get(key, _zones.get(".", {}))

func _ceil_h(cx: int, cy: int) -> float:
	return float(_zone(cx, cy).get("ceilH", 3.6))

func _load_material_map() -> void:
	_mat_map = {}
	var f := FileAccess.open(MATERIAL_MAP, FileAccess.READ)
	if f:
		var p: Variant = JSON.parse_string(f.get_as_text())
		if p is Dictionary:
			_mat_map = p

func get_material(mat_name: String) -> Material:
	if _mat_cache.has(mat_name):
		return _mat_cache[mat_name]
	var m: Material = null
	var entry: Dictionary = _mat_map.get(mat_name, {}) as Dictionary
	var paths: Array[String] = []
	if entry.has("res"):
		paths.append(str(entry["res"]))
	paths.append("res://assets/materials/%s.tres" % mat_name.replace(".", "_"))
	for p in paths:
		if ResourceLoader.exists(p):
			var r: Resource = load(p)
			if r is Material:
				m = r
				break
	if m == null:
		var sm := StandardMaterial3D.new()
		var col: Array = entry.get("color", [0.6, 0.6, 0.6])
		sm.albedo_color = Color(col[0], col[1], col[2])
		sm.roughness = float(entry.get("rough", 0.85))
		sm.metallic = float(entry.get("metal", 0.0))
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		if entry.has("emit"):
			var e: Array = entry["emit"]
			sm.emission_enabled = true
			sm.emission = Color(e[0], e[1], e[2])
			sm.emission_energy_multiplier = float(e[3]) if e.size() > 3 else 1.0
		m = sm
	_mat_cache[mat_name] = m
	return m

# ---------------------------------------------------------------- surfaces
class _Batch:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
		# a,b,c,d counter-clockwise (reversed to clockwise indices for Godot) seen from the normal side
		var i := verts.size()
		verts.append_array([a, b, c, d])
		for k in 4:
			norms.append(n)
		uvs.append_array([uv_a, uv_b, uv_c, uv_d])
		idx.append_array([i, i + 2, i + 1, i, i + 3, i + 2])

func _batch(map: Dictionary, mat_name: String) -> _Batch:
	if not map.has(mat_name):
		map[mat_name] = _Batch.new()
	return map[mat_name]

func _build_surfaces() -> void:
	var batches: Dictionary = {}
	var defs := data.get("defaults", {}) as Dictionary
	var legend := data.get("wallLegend", {}) as Dictionary
	var c := cell
	for cy in _h:
		for cx in _w:
			if _has_floor(cx, cy):
				var z := _zone(cx, cy)
				var fm: String = str(z.get("floor", defs.get("floor", "floor.stone")))
				var cm: String = str(z.get("ceil", defs.get("ceil", "ceil.stone")))
				var ch := _ceil_h(cx, cy)
				var x0 := cx * c
				var x1 := x0 + c
				var z0 := cy * c
				var z1 := z0 + c
				# floor, normal +Y
				_batch(batches, fm).quad(Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3.UP,
					Vector2(x0, z1), Vector2(x1, z1), Vector2(x1, z0), Vector2(x0, z0))
				# ceiling, normal -Y (open sky: no ceiling)
				if cm != "ceil.sky":
					_batch(batches, cm).quad(Vector3(x0, ch, z0), Vector3(x1, ch, z0), Vector3(x1, ch, z1), Vector3(x0, ch, z1), Vector3.DOWN,
						Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1))
			if _is_walkable(cx, cy) or _push_cells.has(Vector2i(cx, cy)):
				continue
			if not _is_solid(cx, cy):
				continue
			var wm: String = str(legend.get(_ch(cx, cy), defs.get("wall", "wall.cheddar_brick")))
			# faces toward each walkable neighbour (pushwalls and doors have their own bodies)
			var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
			for dv in dirs:
				var nx: int = cx + dv.x
				var ny: int = cy + dv.y
				if not _is_walkable(nx, ny):
					continue
				var hh := _ceil_h(nx, ny)
				_wall_face(_batch(batches, wm), cx, cy, dv, hh)
	for mat_name in batches.keys():
		var b: _Batch = batches[mat_name]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b.verts
		arr[Mesh.ARRAY_NORMAL] = b.norms
		arr[Mesh.ARRAY_TEX_UV] = b.uvs
		arr[Mesh.ARRAY_INDEX] = b.idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, get_material(mat_name))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + str(mat_name).replace(".", "_")
		mi.mesh = mesh
		_root_geo.add_child(mi)

## Emit the face of solid cell (cx,cy) that looks toward direction dv.
func _wall_face(b: _Batch, cx: int, cy: int, dv: Vector2i, hh: float) -> void:
	var c := cell
	var x0 := cx * c
	var x1 := x0 + c
	var z0 := cy * c
	var z1 := z0 + c
	if dv == Vector2i(0, -1):    # north face, normal -Z
		b.quad(Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(x0, hh, z0), Vector3(x1, hh, z0), Vector3(0, 0, -1),
			Vector2(x1, 0), Vector2(x0, 0), Vector2(x0, hh), Vector2(x1, hh))
	elif dv == Vector2i(0, 1):   # south face, normal +Z
		b.quad(Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, hh, z1), Vector3(x0, hh, z1), Vector3(0, 0, 1),
			Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, hh), Vector2(x0, hh))
	elif dv == Vector2i(-1, 0):  # west face, normal -X
		b.quad(Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x0, hh, z1), Vector3(x0, hh, z0), Vector3(-1, 0, 0),
			Vector2(z0, 0), Vector2(z1, 0), Vector2(z1, hh), Vector2(z0, hh))
	else:                        # east face, normal +X
		b.quad(Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x1, hh, z0), Vector3(x1, hh, z1), Vector3(1, 0, 0),
			Vector2(z1, 0), Vector2(z0, 0), Vector2(z0, hh), Vector2(z1, hh))

# ---------------------------------------------------------------- collision
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	_root_geo.add_child(body)
	var top := 8.0
	# solid cells merged into horizontal runs
	for cy in _h:
		var cx := 0
		while cx < _w:
			if _is_solid(cx, cy) and not _push_cells.has(Vector2i(cx, cy)):
				var start := cx
				while cx < _w and _is_solid(cx, cy) and not _push_cells.has(Vector2i(cx, cy)):
					cx += 1
				_add_box(body, Vector3((start + cx) * 0.5 * cell, top * 0.5, (cy + 0.5) * cell), Vector3((cx - start) * cell, top, cell))
			else:
				cx += 1
	# floor and ceiling slabs for the whole map
	_add_box(body, Vector3(_w * cell * 0.5, -0.5, _h * cell * 0.5), Vector3(_w * cell, 1.0, _h * cell))
	_add_box(body, Vector3(_w * cell * 0.5, top + 0.5, _h * cell * 0.5), Vector3(_w * cell, 1.0, _h * cell))

func _add_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)

# ---------------------------------------------------------------- doors / pushwalls
func has_key(color: String) -> bool:
	return keys_held.has(color)

func _on_key_taken(color: String) -> void:
	keys_held[color] = true

func _build_doors() -> void:
	var legend_mat := func(n: String) -> Material: return get_material(n)
	for v in _door_cells.keys():
		var dd: Dictionary = _door_cells[v]
		var door := RatDoor.new()
		door.name = "Door_" + str(dd["id"])
		var h := _ceil_h(v.x, v.y)
		h = minf(h, 4.0)
		door.setup(str(dd["id"]), str(dd.get("lock", "") if dd.get("lock") != null else ""), str(dd.get("passage", "ns")),
			Vector3(cell, h, cell), legend_mat.call(str(dd.get("mat", "door.wood"))))
		door.has_key = Callable(self, "has_key")
		door.position = cell_center(v.x, v.y)
		_things_root.add_child(door)
		# lintel above the door so the opening does not leak up to the ceiling
		var full := _ceil_h(v.x, v.y)
		if full > h + 0.01:
			var lintel := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(cell, full - h, cell)
			lintel.mesh = bm
			lintel.material_override = get_material(str(data.get("defaults", {}).get("wall", "wall.cheddar_brick")))
			lintel.position = cell_center(v.x, v.y, h + (full - h) * 0.5)
			_things_root.add_child(lintel)
	var bus := LevelEvents.bus(self)
	if bus and bus.has_signal("key_taken") and not bus.is_connected("key_taken", _on_key_taken):
		bus.connect("key_taken", _on_key_taken)

func _build_pushwalls() -> void:
	for v in _push_cells.keys():
		var pw: Dictionary = _push_cells[v]
		var allowed: Array[Vector3] = []
		for dname in pw.get("dirs", []):
			match str(dname):
				"n": allowed.append(Vector3(0, 0, -1))
				"s": allowed.append(Vector3(0, 0, 1))
				"e": allowed.append(Vector3(1, 0, 0))
				"w": allowed.append(Vector3(-1, 0, 0))
		var node := RatPushwall.new()
		node.name = "Pushwall_" + str(pw["id"])
		node.setup(str(pw["id"]), allowed, Vector3(cell, _ceil_h(v.x, v.y), cell), get_material(str(pw.get("mat", "wall.cheddar_brick"))), cell)
		node.position = cell_center(v.x, v.y)
		_things_root.add_child(node)

# ---------------------------------------------------------------- things
func _build_things() -> void:
	for t in data.get("things", []):
		var d := t as Dictionary
		var cx := int(d["x"])
		var cy := int(d["y"])
		match str(d.get("kind", "")):
			"enemy":
				var m := Marker3D.new()
				m.name = "EnemySpawn_%d_%d" % [cx, cy]
				m.position = cell_center(cx, cy)
				m.add_to_group("enemy_spawn")
				m.set_meta("enemy_type", str(d.get("type", "mouse")))
				m.set_meta("patrol", bool(d.get("patrol", false)))
				_things_root.add_child(m)
				enemy_spawns.append({"type": str(d.get("type", "mouse")), "patrol": bool(d.get("patrol", false)), "pos": m.position, "node": m})
			"item":
				_make_pickup(d)
			"decor":
				_make_decor(d)
			"light":
				var r := float(d.get("range", 6.0))
				var col: Array = d.get("color", [1, 0.85, 0.6])
				_add_light(Vector3((cx + 0.5) * cell, float(d.get("height", 3.0)), (cy + 0.5) * cell), Color(col[0], col[1], col[2]), 1.5, r, float(d.get("flicker", 0.0)))

func _make_pickup(d: Dictionary) -> void:
	var p := RatPickup.new()
	var id := str(d.get("id", ""))
	var color := Color(0.95, 0.85, 0.3)
	var shape := "box"
	if d.has("key"):
		color = Color(1, 0.85, 0.2) if str(d["key"]) == "gold" else Color(0.8, 0.85, 0.95)
		shape = "long"
	elif d.has("weapon"):
		color = Color(0.3, 0.5, 1.0)
		shape = "long"
	elif d.has("ammo"):
		color = Color(0.9, 0.5, 0.2)
	elif d.has("heal"):
		color = Color(0.9, 0.2, 0.25)
		shape = "cyl"
	elif d.has("life"):
		color = Color(0.4, 1.0, 0.4)
		shape = "sphere"
	elif d.has("treasure"):
		color = Color(1.0, 0.8, 0.2)
		shape = "sphere"
	p.name = "Pickup_%s_%d_%d" % [id, int(d["x"]), int(d["y"])]
	p.setup(d, color, shape)
	p.position = cell_center(int(d["x"]), int(d["y"]))
	_things_root.add_child(p)
	if d.has("light"):
		var l: Array = d["light"]
		_add_light(p.position + Vector3(0, 1.2, 0), Color(l[0], l[1], l[2]), 0.8, float(l[3]), 0.0)

func _make_decor(d: Dictionary) -> void:
	var cx := int(d["x"])
	var cy := int(d["y"])
	var id := str(d.get("id", "decor"))
	var hang := bool(d.get("hang", false))
	var node := Node3D.new()
	node.set_meta("decor_id", id)
	node.name = "Decor_%s_%d_%d" % [id, cx, cy]
	node.position = cell_center(cx, cy)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.35
	cm.height = 1.6
	mi.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.5, 0.45, 0.4)
	sm.roughness = 0.9
	if d.has("light"):
		var l: Array = d["light"]
		sm.emission_enabled = true
		sm.emission = Color(l[0], l[1], l[2])
		sm.emission_energy_multiplier = 0.5
	mi.material_override = sm
	mi.position.y = (_ceil_h(cx, cy) - 0.8) if hang else 0.8
	node.add_child(mi)
	if bool(d.get("block", false)):
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.4
		sh.height = 2.0
		cs.shape = sh
		cs.position.y = 1.0
		sb.add_child(cs)
		node.add_child(sb)
	_things_root.add_child(node)
	if d.has("light"):
		var l2: Array = d["light"]
		var fl := float(l2[5]) if l2.size() > 5 else 0.0
		var hy := (_ceil_h(cx, cy) - 1.0) if hang else (float(l2[4]) + 1.0 if l2.size() > 4 else 2.0)
		_add_light(Vector3(node.position.x, hy, node.position.z), Color(l2[0], l2[1], l2[2]) / maxf(maxf(l2[0], l2[1]), maxf(l2[2], 1.0)), 1.2, float(l2[3]) if l2.size() > 3 else 5.0, fl, "practical", "", id)

# ---------------------------------------------------------------- lights
func _add_light(pos: Vector3, color: Color, energy: float, range_m: float, flicker: float, kind: String = "practical", zone: String = "", decor_id: String = "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.set_meta("look_kind", kind)
	if zone != "":
		l.set_meta("zone", zone)
	if decor_id != "":
		l.set_meta("decor_id", decor_id)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	if flicker > 0.0:
		l.set_meta("flicker", flicker)
	_things_root.add_child(l)
	_lights.append(l)
	return l

func _ch_zone(cx: int, cy: int) -> String:
	var zg: Array = data.get("zoneGrid", []) as Array
	if cy >= 0 and cy < zg.size() and cx >= 0 and cx < str(zg[cy]).length():
		return str(zg[cy])[cx]
	return ""

func _build_zone_lights() -> void:
	var sp := maxi(2, zone_light_spacing)
	for cy in _h:
		for cx in _w:
			if not _is_walkable(cx, cy) or cx % sp != sp / 2 or cy % sp != sp / 2:
				continue
			var lz := (_zone(cx, cy).get("light", {}) as Dictionary)
			var col: Array = lz.get("color", [1, 0.85, 0.6])
			_add_light(Vector3((cx + 0.5) * cell, _ceil_h(cx, cy) - 0.6, (cy + 0.5) * cell), Color(col[0], col[1], col[2]),
				float(lz.get("energy", 0.7)), float(lz.get("range", 8.0)), 0.0, "zone", _ch_zone(cx, cy))

func _process(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0 or _lights.is_empty():
		return
	_light_timer = 0.25
	var fpos := Vector3.ZERO
	if focus and is_instance_valid(focus):
		fpos = focus.global_position
	elif get_viewport() and get_viewport().get_camera_3d():
		fpos = get_viewport().get_camera_3d().global_position
	var order: Array = _lights.duplicate()
	order.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return a.global_position.distance_squared_to(fpos) < b.global_position.distance_squared_to(fpos))
	for i in order.size():
		(order[i] as OmniLight3D).shadow_enabled = i < shadow_lights

# ---------------------------------------------------------------- navigation
## Polygon-per-walkable-cell navmesh on a shared vertex grid (edges merge in the nav server).
func _build_navigation() -> void:
	var nm := NavigationMesh.new()
	var verts := PackedVector3Array()
	var vi: Dictionary = {}
	var polys: Array[PackedInt32Array] = []
	for cy in _h:
		for cx in _w:
			if not _is_walkable(cx, cy):
				continue
			var ids := PackedInt32Array()
			for corner in [Vector2i(cx, cy), Vector2i(cx + 1, cy), Vector2i(cx + 1, cy + 1), Vector2i(cx, cy + 1)]:
				if not vi.has(corner):
					vi[corner] = verts.size()
					verts.append(Vector3(corner.x * cell, 0.0, corner.y * cell))
				ids.append(vi[corner])
			polys.append(ids)
	nm.vertices = verts
	for p in polys:
		nm.add_polygon(p)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	nav_region.navigation_mesh = nm
	add_child(nav_region)

# ---------------------------------------------------------------- exit / env
func _build_exit() -> void:
	var e := data.get("exit", {}) as Dictionary
	if e.is_empty():
		return
	exit_cell = Vector2i(int(e["x"]), int(e["y"]))
	exit_area = Area3D.new()
	exit_area.name = "ExitSwitch"
	exit_area.collision_layer = 32
	exit_area.collision_mask = 2
	exit_area.add_to_group("exit_switch")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(cell, 3.0, cell)
	cs.shape = bs
	cs.position.y = 1.5
	exit_area.add_child(cs)
	var dv := Vector3.ZERO
	match str(e.get("facing", "s")):
		"n": dv = Vector3(0, 0, -1)
		"s": dv = Vector3(0, 0, 1)
		"e": dv = Vector3(1, 0, 0)
		"w": dv = Vector3(-1, 0, 0)
	exit_area.position = cell_center(exit_cell.x, exit_cell.y) + dv * cell * 0.75
	_things_root.add_child(exit_area)
	_build_switch_prop(dv)
	exit_area.body_entered.connect(func(b: Node3D) -> void:
		if LevelEvents.is_player(b):
			LevelEvents.emit(self, &"message", ["Press USE at the exit switch"]))

## Physical wall switch: dark metal plate, rod lever and a small emissive status lamp (not a lit wall).
func _build_switch_prop(dv: Vector3) -> void:
	var root := Node3D.new()
	root.name = "ExitSwitchProp"
	root.set_meta("no_em_mul", true)
	var face := cell_center(exit_cell.x, exit_cell.y) + dv * cell * 0.5
	root.position = Vector3(face.x, 1.3, face.z)
	root.rotation.y = atan2(-dv.x, -dv.z)  # local -Z points into the room (along dv)
	var plate_m := StandardMaterial3D.new()
	plate_m.albedo_color = Color(0.55, 0.58, 0.56)
	plate_m.metallic = 0.15
	plate_m.roughness = 0.45
	var lamp_m := StandardMaterial3D.new()
	lamp_m.albedo_color = Color(0.05, 0.2, 0.08)
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(0.1, 1.0, 0.25)
	lamp_m.emission_energy_multiplier = 0.25
	var lever_m := StandardMaterial3D.new()
	lever_m.albedo_color = Color(0.75, 0.1, 0.08)
	lever_m.roughness = 0.4
	lever_m.metallic = 0.3
	var parts: Array = [
		[Vector3(0.7, 1.0, 0.08), Vector3(0, 0, -0.04), plate_m],
		[Vector3(0.12, 0.12, 0.05), Vector3(0, 0.34, -0.1), lamp_m],
		[Vector3(0.08, 0.4, 0.08), Vector3(0, -0.05, -0.14), lever_m],
		[Vector3(0.2, 0.2, 0.2), Vector3(0, -0.22, -0.12), plate_m],
	]
	for pr: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pr[0]
		mi.mesh = bm
		mi.position = pr[1]
		mi.material_override = pr[2]
		root.add_child(mi)
	var l := _add_light(root.position + root.transform.basis * Vector3(0, 0.3, -0.7), Color(0.5, 1.0, 0.6), 1.5, 5.0, 0.0, "practical", "", "exit_switch")
	l.reparent(root)
	_things_root.add_child(root)

## Call from the player's "use" ray / exit trigger to finish the level.
func complete_level(extra: Dictionary = {}) -> void:
	var s := stats.duplicate()
	s.merge(extra, true)
	s["id"] = str(data.get("id", ""))
	LevelEvents.emit(self, &"level_completed", [s])

func _build_environment() -> void:
	var amb := data.get("ambient", [0.05, 0.05, 0.05]) as Array
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var fog := data.get("fog", {}) as Dictionary
	var fc: Array = fog.get("color", [0.02, 0.02, 0.02])
	env.background_color = Color(fc[0], fc[1], fc[2])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(amb[0], amb[1], amb[2])
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "LevelEnvironment"
	we.environment = env
	add_child(we)
