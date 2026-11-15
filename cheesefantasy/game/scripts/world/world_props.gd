class_name WorldProps
extends RefCounted
## Procedural placeholder props (used until res://assets/models/world_*.glb exist).

static var _mats: Dictionary = {}

static func mat(c: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, 0.85, emit)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(parent, m, pos, c, rot)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return _mi(parent, m, pos, c, rot, emit)

static func sph(parent: Node3D, r: float, pos: Vector3, c: Color, squash: float = 1.0, emit: float = 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 14
	m.rings = 8
	return _mi(parent, m, pos, c, Vector3.ZERO, emit)

static func prism(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	# Gable roof: ridge along Z, triangular ends. Built by hand, double-sided (PrismMesh rendered inside-out here).
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y0 := -size.y * 0.5
	var y1 := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [
		[Vector3(-hx, y0, hz), Vector3(0, y1, hz), Vector3(0, y1, -hz), Vector3(-hx, y0, -hz)],
		[Vector3(0, y1, hz), Vector3(hx, y0, hz), Vector3(hx, y0, -hz), Vector3(0, y1, -hz)],
		[Vector3(hx, y0, hz), Vector3(-hx, y0, hz), Vector3(-hx, y0, -hz), Vector3(hx, y0, -hz)],
	]
	for q: Array in quads:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[i])
	for zz in [hz, -hz]:
		for v: Vector3 in [Vector3(-hx, y0, zz), Vector3(hx, y0, zz), Vector3(0, y1, zz)]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := _mi(parent, st.commit(), pos, c)
	var m2 := mat(c, 0.85).duplicate() as StandardMaterial3D
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m2
	return mi

static func torus(parent: Node3D, r_in: float, r_out: float, pos: Vector3, c: Color, rot: Vector3, emit: float = 0.0) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = r_in
	m.outer_radius = r_out
	m.rings = 32
	m.ring_segments = 8
	return _mi(parent, m, pos, c, rot, emit)

static func label(parent: Node3D, text: String, pos: Vector3, size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.position = pos
	l.modulate = Color(0.2, 0.1, 0.05)
	l.outline_size = 0
	parent.add_child(l)
	return l

## Returns {node, footprint(Vector3 size for collision or ZERO)}.
static func build(kind: String, text: String = "") -> Dictionary:
	var n := Node3D.new()
	var fp := Vector3.ZERO
	match kind:
		"farmhouse":
			var wall := Color(0.95, 0.86, 0.68)
			box(n, Vector3(9, 3.6, 7), Vector3(0, 1.8, 0), wall)
			prism(n, Vector3(10.2, 3.0, 8), Vector3(0, 5.1, 0), Color(0.55, 0.22, 0.16)).rotation_degrees.y = 0
			box(n, Vector3(1.3, 2.3, 0.15), Vector3(0, 1.15, 3.55), Color(0.4, 0.22, 0.1))
			for wx in [-3.0, 3.0]:
				box(n, Vector3(1.4, 1.2, 0.15), Vector3(wx, 2.0, 3.55), Color(0.55, 0.78, 0.9))
				box(n, Vector3(1.6, 0.18, 0.3), Vector3(wx, 1.35, 3.6), Color(0.4, 0.22, 0.1))
			box(n, Vector3(1.0, 2.6, 1.0), Vector3(2.8, 5.6, -1.5), Color(0.5, 0.45, 0.4))
			box(n, Vector3(3.5, 0.2, 1.8), Vector3(0, 0.1, 4.4), Color(0.45, 0.3, 0.18))
			fp = Vector3(9, 5, 7)
		"barn":
			var red := Color(0.68, 0.14, 0.1)
			box(n, Vector3(10, 5.5, 13), Vector3(0, 2.75, 0), red)
			prism(n, Vector3(11.2, 4.2, 14), Vector3(0, 7.5, 0), Color(0.34, 0.2, 0.16))
			box(n, Vector3(4.0, 4.0, 0.2), Vector3(0, 2.0, 6.55), Color(0.95, 0.92, 0.85))
			box(n, Vector3(4.0, 0.25, 0.25), Vector3(0, 2.0, 6.7), red, Vector3(0, 0, 45))
			box(n, Vector3(4.0, 0.25, 0.25), Vector3(0, 2.0, 6.7), red, Vector3(0, 0, -45))
			box(n, Vector3(1.6, 1.6, 0.2), Vector3(0, 6.2, 6.55), Color(0.95, 0.92, 0.85))
			fp = Vector3(10, 8, 13)
		"silo":
			cyl(n, 2.2, 2.3, 10, Vector3(0, 5, 0), Color(0.72, 0.76, 0.8))
			sph(n, 2.25, Vector3(0, 10, 0), Color(0.55, 0.62, 0.7), 0.7)
			for by in [2.0, 5.0, 8.0]:
				cyl(n, 2.35, 2.35, 0.2, Vector3(0, by, 0), Color(0.45, 0.5, 0.56))
			fp = Vector3(4.6, 10, 4.6)
		"windmill":
			cyl(n, 1.5, 2.6, 9, Vector3(0, 4.5, 0), Color(0.92, 0.88, 0.78))
			cyl(n, 0.1, 2.0, 2.4, Vector3(0, 10.1, 0), Color(0.6, 0.2, 0.15))
			box(n, Vector3(1.0, 2.0, 0.15), Vector3(0, 1.0, 2.55), Color(0.4, 0.22, 0.1))
			var blades := Node3D.new()
			blades.name = "Blades"
			blades.position = Vector3(0, 8.8, 2.1)
			n.add_child(blades)
			for i in range(4):
				var arm := Node3D.new()
				arm.rotation_degrees.z = i * 90.0
				blades.add_child(arm)
				box(arm, Vector3(0.15, 6.5, 0.1), Vector3(0, 3.25, 0), Color(0.45, 0.3, 0.18))
				box(arm, Vector3(1.2, 4.2, 0.06), Vector3(0.7, 4.0, 0.05), Color(0.97, 0.94, 0.88))
			cyl(n, 0.3, 0.3, 0.8, Vector3(0, 8.8, 1.9), Color(0.3, 0.2, 0.15), Vector3(90, 0, 0))
			fp = Vector3(5, 9, 5)
		"coop":
			box(n, Vector3(3.4, 2.0, 2.8), Vector3(0, 1.2, 0), Color(0.78, 0.55, 0.3))
			prism(n, Vector3(4.0, 1.3, 3.2), Vector3(0, 2.85, 0), Color(0.6, 0.2, 0.15))
			box(n, Vector3(0.7, 0.9, 0.1), Vector3(0, 0.6, 1.45), Color(0.25, 0.15, 0.08))
			box(n, Vector3(0.7, 0.08, 1.6), Vector3(0, 0.3, 2.1), Color(0.5, 0.35, 0.2), Vector3(-18, 0, 0))
			box(n, Vector3(3.6, 0.5, 0.2), Vector3(0, 0.5, 1.4), Color(0.6, 0.4, 0.2))
			fp = Vector3(3.4, 3.5, 2.8)
		"tree_oak":
			cyl(n, 0.28, 0.45, 3.2, Vector3(0, 1.6, 0), Color(0.38, 0.26, 0.16))
			var g := Color(0.22, 0.5, 0.18)
			sph(n, 2.1, Vector3(0, 4.4, 0), g, 0.9)
			sph(n, 1.5, Vector3(1.3, 3.7, 0.4), g.lightened(0.05), 0.9)
			sph(n, 1.4, Vector3(-1.2, 3.9, -0.5), g.darkened(0.05), 0.9)
			fp = Vector3(0.9, 3, 0.9)
		"tree_apple":
			cyl(n, 0.22, 0.38, 2.4, Vector3(0, 1.2, 0), Color(0.42, 0.28, 0.18))
			var g2 := Color(0.3, 0.6, 0.22)
			sph(n, 1.8, Vector3(0, 3.3, 0), g2, 0.85)
			sph(n, 1.2, Vector3(1.1, 2.9, 0.3), g2.lightened(0.06), 0.85)
			for p in [Vector3(0.9, 3.3, 1.4), Vector3(-1.0, 3.0, 1.0), Vector3(0.3, 4.0, -1.2), Vector3(-1.4, 3.5, -0.4), Vector3(1.5, 3.7, -0.5)]:
				sph(n, 0.16, p, Color(0.9, 0.12, 0.1))
			fp = Vector3(0.7, 3, 0.7)
		"haybale":
			cyl(n, 0.7, 0.7, 1.2, Vector3(0, 0.7, 0), Color(0.88, 0.72, 0.3), Vector3(0, 0, 90))
			fp = Vector3(1.4, 1.4, 1.4)
		"crate":
			box(n, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0), Color(0.7, 0.5, 0.28))
			box(n, Vector3(0.95, 0.12, 0.95), Vector3(0, 0.1, 0), Color(0.5, 0.34, 0.18))
			box(n, Vector3(0.95, 0.12, 0.95), Vector3(0, 0.8, 0), Color(0.5, 0.34, 0.18))
			fp = Vector3(0.9, 0.9, 0.9)
		"well":
			cyl(n, 0.95, 1.0, 0.9, Vector3(0, 0.45, 0), Color(0.6, 0.6, 0.62))
			cyl(n, 0.7, 0.7, 0.05, Vector3(0, 0.82, 0), Color(0.1, 0.2, 0.35))
			box(n, Vector3(0.15, 2.0, 0.15), Vector3(-0.9, 1.5, 0), Color(0.4, 0.26, 0.15))
			box(n, Vector3(0.15, 2.0, 0.15), Vector3(0.9, 1.5, 0), Color(0.4, 0.26, 0.15))
			prism(n, Vector3(2.4, 0.9, 1.6), Vector3(0, 2.9, 0), Color(0.55, 0.22, 0.16))
			fp = Vector3(2, 3, 2)
		"dock":
			box(n, Vector3(1.8, 0.15, 7.0), Vector3(0, 0.3, 0), Color(0.55, 0.4, 0.25))
			for pz in [-3.0, 0.0, 3.0]:
				for px in [-0.8, 0.8]:
					cyl(n, 0.08, 0.08, 1.4, Vector3(px, 0.0, pz), Color(0.35, 0.24, 0.14))
		"cave":
			var rock := Color(0.5, 0.48, 0.45)
			sph(n, 9.0, Vector3(0, 2.0, -5.0), rock, 0.9)
			sph(n, 5.5, Vector3(-6.5, 1.5, -1.0), rock.darkened(0.08), 0.9)
			sph(n, 5.0, Vector3(6.5, 1.3, -1.5), rock.lightened(0.05), 0.9)
			box(n, Vector3(4.4, 4.0, 3.0), Vector3(0, 2.0, -0.5), Color(0.04, 0.03, 0.03))
			box(n, Vector3(0.45, 4.6, 0.45), Vector3(-2.3, 2.3, 1.1), Color(0.4, 0.26, 0.15))
			box(n, Vector3(0.45, 4.6, 0.45), Vector3(2.3, 2.3, 1.1), Color(0.4, 0.26, 0.15))
			box(n, Vector3(5.2, 0.5, 0.5), Vector3(0, 4.6, 1.1), Color(0.4, 0.26, 0.15))
			cyl(n, 0.9, 0.9, 0.35, Vector3(0, 5.6, 1.1), Color(0.98, 0.8, 0.2), Vector3(90, 0, 0))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.75, 0.35)
			l.light_energy = 2.0
			l.omni_range = 9.0
			l.position = Vector3(0, 2.2, 1.2)
			n.add_child(l)
		"shrine":
			cyl(n, 1.7, 1.9, 0.5, Vector3(0, 0.25, 0), Color(0.62, 0.6, 0.58))
			cyl(n, 0.5, 0.6, 1.3, Vector3(0, 1.1, 0), Color(0.75, 0.73, 0.7))
			sph(n, 0.32, Vector3(0, 1.95, 0), Color(1.0, 0.85, 0.5), 1.0, 2.0)
			var cols := [Color(0.95, 0.2, 0.2), Color(0.98, 0.55, 0.15), Color(0.98, 0.88, 0.2), Color(0.3, 0.8, 0.3), Color(0.25, 0.6, 0.95), Color(0.35, 0.3, 0.85), Color(0.7, 0.3, 0.85)]
			for i in range(7):
				var R := 3.4 - i * 0.22
				torus(n, R - 0.11, R + 0.11, Vector3(0, 0.1, -1.3), cols[i], Vector3(90, 0, 0), 1.2)
			var l2 := OmniLight3D.new()
			l2.light_color = Color(1.0, 0.9, 0.8)
			l2.light_energy = 1.2
			l2.omni_range = 7.0
			l2.position = Vector3(0, 2.4, 0)
			n.add_child(l2)
			fp = Vector3(3.4, 2, 3.4)
		"wheel":
			cyl(n, 0.6, 0.6, 0.3, Vector3(0, 0.15, 0), Color(0.98, 0.8, 0.25))
		"cauldron":
			sph(n, 0.85, Vector3(0, 0.85, 0), Color(0.12, 0.12, 0.14), 0.85)
			torus(n, 0.62, 0.78, Vector3(0, 1.45, 0), Color(0.2, 0.2, 0.22), Vector3.ZERO)
			cyl(n, 0.7, 0.7, 0.04, Vector3(0, 1.4, 0), Color(0.5, 0.85, 0.3), Vector3.ZERO, 0.8)
			for a in [0.0, 2.1, 4.2]:
				cyl(n, 0.08, 0.06, 0.4, Vector3(cos(a) * 0.55, 0.2, sin(a) * 0.55), Color(0.1, 0.1, 0.1))
			fp = Vector3(1.8, 1.6, 1.8)
		"campfire":
			for i in range(6):
				var a := i * TAU / 6.0
				sph(n, 0.2, Vector3(cos(a) * 0.8, 0.12, sin(a) * 0.8), Color(0.45, 0.45, 0.47), 0.7)
			cyl(n, 0.09, 0.09, 1.1, Vector3(0, 0.2, 0), Color(0.3, 0.19, 0.1), Vector3(0, 0, 70))
			cyl(n, 0.09, 0.09, 1.1, Vector3(0, 0.2, 0), Color(0.3, 0.19, 0.1), Vector3(70, 40, 0))
			cyl(n, 0.0, 0.3, 0.9, Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.1), Vector3.ZERO, 3.0)
			cyl(n, 0.0, 0.16, 0.55, Vector3(0, 0.55, 0), Color(1.0, 0.85, 0.3), Vector3.ZERO, 4.0)
			var fl := OmniLight3D.new()
			fl.name = "Flicker"
			fl.light_color = Color(1.0, 0.6, 0.25)
			fl.light_energy = 2.2
			fl.omni_range = 9.0
			fl.position = Vector3(0, 1.0, 0)
			n.add_child(fl)
		"sign":
			box(n, Vector3(0.18, 1.8, 0.18), Vector3(0, 0.9, 0), Color(0.4, 0.27, 0.15))
			box(n, Vector3(1.8, 0.7, 0.1), Vector3(0, 1.6, 0.1), Color(0.78, 0.6, 0.35))
			label(n, text, Vector3(0, 1.6, 0.17), 36)
		"tractor":
			box(n, Vector3(1.6, 1.0, 2.6), Vector3(0, 1.1, 0.4), Color(0.8, 0.12, 0.08))
			box(n, Vector3(1.5, 1.3, 1.2), Vector3(0, 2.1, -0.6), Color(0.85, 0.15, 0.1))
			box(n, Vector3(1.4, 0.8, 0.05), Vector3(0, 2.3, 0.0), Color(0.6, 0.8, 0.9))
			for wz in [[-0.95, -0.6, 0.7], [0.95, -0.6, 0.7], [-0.9, 1.3, 0.45], [0.9, 1.3, 0.45]]:
				cyl(n, wz[2], wz[2], 0.45, Vector3(wz[0], wz[2], wz[1]), Color(0.1, 0.1, 0.1), Vector3(0, 0, 90))
			fp = Vector3(2.2, 2.6, 3.4)
		_:
			box(n, Vector3(1, 1, 1), Vector3(0, 0.5, 0), Color(0.8, 0.3, 0.8))
	return {"node": n, "fp": fp}

## Crop mesh (single plant) for MultiMesh fields.
static func crop_mesh(kind: String) -> Mesh:
	if WorldModels.has_model("world_crop_" + kind):
		var ps: PackedScene = WorldModels._load_scene("world_crop_" + kind)
		if ps != null:
			var inst := ps.instantiate()
			var found := inst.find_children("*", "MeshInstance3D", true, false)
			if found.size() > 0:
				var m: Mesh = (found[0] as MeshInstance3D).mesh
				inst.free()
				return m
			inst.free()
	match kind:
		"corn":
			var c := CylinderMesh.new()
			c.top_radius = 0.18
			c.bottom_radius = 0.3
			c.height = 1.8
			c.radial_segments = 6
			c.rings = 1
			c.material = mat(Color(0.55, 0.7, 0.2))
			return c
		"wheat":
			var w := CylinderMesh.new()
			w.top_radius = 0.28
			w.bottom_radius = 0.1
			w.height = 0.95
			w.radial_segments = 6
			w.rings = 1
			w.material = mat(Color(0.9, 0.75, 0.3))
			return w
		_:
			var t := SphereMesh.new()
			t.radius = 0.38
			t.height = 0.65
			t.radial_segments = 8
			t.rings = 4
			t.material = mat(Color(0.25, 0.55, 0.2))
			return t
