class_name MaterialStudio
extends Node3D
## Material test studio (owner: shaders-materials), used by res://scenes/material_test.tscn.
## Builds HDRI-lit rows of sample meshes for every library material in code.
## Camera presets for tools/shot.sh --cam (x,y,z,yaw,pitch):
##   overview 0,2.0,5.0,0,-14   cheese close -2.0,1.2,2.4,0,-20   fur at 2 m -2.5,1.0,0.4,0,-10

const SPACING: float = 1.25
const HDRI: String = "res://assets/hdri/bloem_hill_01_2k.hdr"

## Rows (front to back). Each entry: [material name, mesh kind].
var rows: Array = [
	[["cheese_cheddar_rind", "wedge"], ["cheese_swiss_rind", "wedge"], ["cheese_blue_rind", "wedge"], ["cheese_swiss", "cube"],
		["cheese_cheddar", "sphere"], ["cheese_wax_red", "wheel"]],
	[["fur_cat_tabby", "fur_sphere"], ["fur_rat_grey", "fur_capsule"], ["fur_rat_brown", "fur_sphere"],
		["fur_mouse", "fur_sphere"], ["fur_cat_tabby_lod", "sphere"], ["skin_ear", "ear"], ["skin_nose", "sphere"]],
	[["cloth_uniform_grey", "sphere"], ["cloth_officer_red", "cube"], ["cloth_burlap", "sphere"], ["emblem_flag", "flag"],
		["emblem_crate", "cube"], ["gold_foil", "sphere"], ["gold_smooth", "sphere"], ["glass_window", "pane"],
		["glass_bottle_green", "sphere"]],
	[["wet_stone_sewer", "slab"], ["wet_stone_rain", "slab"], ["wet_metal_pipe", "pipe"], ["wet_metal_painted", "cube"],
		["tri_brick_wall_001", "wall"], ["tri_mossy_stone_wall", "wall"], ["tri_metal_plate", "wall"],
		["tri_painted_plaster_wall", "wall"], ["tri_placeholder", "wall"]],
]


func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_floor()
	for r: int in rows.size():
		var row: Array = rows[r]
		var z: float = -float(r) * 1.6
		var x0: float = -float(row.size() - 1) * SPACING * 0.5
		for i: int in row.size():
			var entry: Array = row[i]
			_spawn(String(entry[0]), String(entry[1]), Vector3(x0 + float(i) * SPACING, 0.0, z))
	if get_viewport().get_camera_3d() == null:
		var cam := Camera3D.new()
		cam.position = Vector3(0.0, 2.0, 5.0)
		cam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
		cam.fov = 60.0
		add_child(cam)
		cam.make_current()


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var tex: Texture2D = load(HDRI) as Texture2D if ResourceLoader.exists(HDRI) else null
	if tex != null:
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = tex
		sky.sky_material = pm
	else:
		sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_color = Color(0.05, 0.05, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	add_child(sun)
	# Back/rim light so SSS (ears, cheese) and fur rims show.
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-20.0, 160.0, 0.0)
	back.light_energy = 0.9
	back.light_color = Color(1.0, 0.92, 0.8)
	add_child(back)


func _build_floor() -> void:
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0, 40.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0.0, 0.0, -2.5)
	floor_mi.material_override = RatMaterials.get_material("tri_concrete_floor_01")
	add_child(floor_mi)


func _spawn(mat_name: String, kind: String, at: Vector3) -> void:
	var pos: Vector3 = at
	var mi := MeshInstance3D.new()
	mi.name = "%s_%s" % [mat_name, kind]
	var lift: float = 0.45
	match kind:
		"wedge":
			mi.mesh = make_wedge(0.6, 0.38, 1.05)
			lift = 0.0
			mi.rotation_degrees = Vector3(0.0, 120.0, 0.0)
			pos.x += 0.25
		"wheel":
			mi.mesh = make_wedge(0.42, 0.3, TAU)
			lift = 0.0
		"flag":
			var qm := QuadMesh.new()
			qm.size = Vector2(0.96, 0.6)
			mi.mesh = qm
			lift = 0.4
		"cube":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.7, 0.7, 0.7)
			mi.mesh = bm
			mi.rotation_degrees = Vector3(0.0, 25.0, 0.0)
			lift = 0.4
		"pane":
			var pb := BoxMesh.new()
			pb.size = Vector3(0.8, 0.8, 0.02)
			mi.mesh = pb
			lift = 0.45
		"slab":
			var sb := BoxMesh.new()
			sb.size = Vector3(1.1, 0.04, 1.1)
			mi.mesh = sb
			lift = 0.02
		"wall":
			var wb := BoxMesh.new()
			wb.size = Vector3(1.0, 1.4, 0.4)
			mi.mesh = wb
			lift = 0.7
		"pipe":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.18
			cm.bottom_radius = 0.18
			cm.height = 1.0
			mi.mesh = cm
			mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			lift = 0.2
		"ear":
			var em := SphereMesh.new()
			em.radius = 0.32
			em.height = 0.64
			mi.mesh = em
			mi.scale = Vector3(1.0, 1.2, 0.15)
		"fur_capsule":
			var cap := CapsuleMesh.new()
			cap.radius = 0.28
			cap.height = 0.9
			mi.mesh = cap
			mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			lift = 0.32
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.35
			sm.height = 0.7
			mi.mesh = sm
			lift = 0.38
	mi.position = pos + Vector3(0.0, lift, 0.0)
	if kind.begins_with("fur_"):
		add_child(mi)
		RatMaterials.apply_fur(mi, mat_name)
	else:
		mi.material_override = RatMaterials.get_material(mat_name)
		add_child(mi)
	var label := Label3D.new()
	label.text = mat_name
	label.font_size = 28
	label.pixel_size = 0.0025
	label.position = pos + Vector3(0.0, 0.02, 0.62)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.modulate = Color(0.9, 0.9, 0.9)
	add_child(label)


## Cheese wedge/wheel: a cylinder sector of `radius`, `height`, spanning `angle` radians.
## Vertex colour R = 1 on the rind (outer curved face, top and bottom near the rim are paste-cut
## faces only for wedges); R = 0 on the cut faces so holes show there. UVs are not needed by cheese.
static func make_wedge(radius: float, height: float, angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = maxi(8, int(angle / TAU * 64.0))
	var full: bool = angle >= TAU - 0.001
	var rind_top: float = 1.0 if full else 0.0
	for i: int in seg:
		var a0: float = angle * float(i) / float(seg)
		var a1: float = angle * float(i + 1) / float(seg)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var up := Vector3(0.0, height, 0.0)
		# Outer rind face (wound so its normal points outward).
		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))
		_tri(st, [[p0, n0, 1.0], [p0 + up, n0, 1.0], [p1 + up, n1, 1.0]])
		_tri(st, [[p0, n0, 1.0], [p1 + up, n1, 1.0], [p1, n1, 1.0]])
		# Top and bottom.
		_tri(st, [[up, Vector3.UP, rind_top], [p1 + up, Vector3.UP, rind_top], [p0 + up, Vector3.UP, rind_top]])
		_tri(st, [[Vector3.ZERO, Vector3.DOWN, 1.0], [p0, Vector3.DOWN, 1.0], [p1, Vector3.DOWN, 1.0]])
	if not full:
		var up2 := Vector3(0.0, height, 0.0)
		var e0 := Vector3(radius, 0.0, 0.0)
		var ea := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var nA := Vector3(0.0, 0.0, -1.0)
		_tri(st, [[Vector3.ZERO, nA, 0.0], [e0 + up2, nA, 0.0], [e0, nA, 0.0]])
		_tri(st, [[Vector3.ZERO, nA, 0.0], [up2, nA, 0.0], [e0 + up2, nA, 0.0]])
		var nB := Vector3(-sin(angle), 0.0, cos(angle))
		_tri(st, [[Vector3.ZERO, nB, 0.0], [ea, nB, 0.0], [ea + up2, nB, 0.0]])
		_tri(st, [[Vector3.ZERO, nB, 0.0], [ea + up2, nB, 0.0], [up2, nB, 0.0]])
	return st.commit()


## Emit a triangle wound clockwise as seen from its normal side (Godot front-face convention).
static func _tri(st: SurfaceTool, v: Array) -> void:
	var a: Vector3 = v[0][0]
	var b: Vector3 = v[1][0]
	var c: Vector3 = v[2][0]
	var n: Vector3 = v[0][1]
	var order: Array = [0, 1, 2] if (b - a).cross(c - a).dot(n) < 0.0 else [0, 2, 1]
	for k: int in order:
		_v(st, v[k][0], v[k][1], float(v[k][2]))


static func _v(st: SurfaceTool, p: Vector3, n: Vector3, rind: float) -> void:
	st.set_color(Color(rind, 0.0, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(p.x, p.z))
	st.add_vertex(p)
