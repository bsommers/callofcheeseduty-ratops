class_name FarmTerrain
extends Node3D
## Heightmapped + noise terrain for Curdlewick Farm, painted with vertex colours
## (grass, dirt paths, tilled fields, rock, shore sand). Builds mesh + collision in code.

const HALF := 100.0
const RES := 160
const WATER_LEVEL := -0.55

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var paths: Array = []            # Array[PackedVector2Array]
var field_rects: Array = []      # Array[Rect2]
var pond_center := Vector2(34.0, -34.0)
var cave_pos := Vector2(0.0, -62.0)
var _cave_h := 0.0
var grass_rects: Array = []      # tall-grass encounter zones (Rect2)

func _init() -> void:
	noise.seed = 1337
	noise.frequency = 0.018
	noise.fractal_octaves = 3
	detail.seed = 77
	detail.frequency = 0.09

func setup(p_paths: Array, p_fields: Array) -> void:
	paths = p_paths
	field_rects = p_fields
	_cave_h = _raw_height(cave_pos.x, cave_pos.y)

func _raw_height(x: float, z: float) -> float:
	var d0 := Vector2(x, z).length()
	var flat := smoothstep(70.0, 38.0, d0) # 1 near farm centre
	var n := noise.get_noise_2d(x, z)
	var h := n * (0.5 + 3.5 * (1.0 - flat)) + detail.get_noise_2d(x, z) * 0.15
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(66.0, 96.0, edge) * (11.0 + 5.0 * n)
	h += smoothstep(-44.0, -84.0, z) * (15.0 + 5.0 * n)
	var dp := Vector2(x, z).distance_to(pond_center)
	h -= (1.0 - smoothstep(5.0, 13.0, dp)) * 2.4
	return h

func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	var dc := Vector2(x, z).distance_to(cave_pos)
	return lerpf(_cave_h, h, smoothstep(7.0, 15.0, dc))

func normal_at(x: float, z: float) -> Vector3:
	var e := 0.6
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

func _dist_to_paths(p: Vector2) -> float:
	var best := 1e9
	for poly in paths:
		var pts: PackedVector2Array = poly
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best

func _color_at(x: float, z: float, nrm: Vector3, h: float) -> Color:
	var g1 := Color(0.36, 0.62, 0.22)
	var g2 := Color(0.47, 0.72, 0.27)
	var g3 := Color(0.28, 0.50, 0.20)
	var t := detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var c := g1.lerp(g2, t).lerp(g3, clampf(noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.2, 0.0, 1.0) * 0.6)
	var p := Vector2(x, z)
	for r: Rect2 in grass_rects:
		if r.has_point(p):
			c = c.lerp(Color(0.25, 0.55, 0.16), 0.7)
	for r: Rect2 in field_rects:
		var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		var dd := sqrt(dx * dx + dz * dz)
		var soil := Color(0.40, 0.26, 0.15).lerp(Color(0.33, 0.21, 0.12), t)
		c = c.lerp(soil, 1.0 - smoothstep(0.0, 1.2, dd))
	var dp := _dist_to_paths(p)
	if dp < 2.6:
		var dirt := Color(0.62, 0.48, 0.30).lerp(Color(0.54, 0.41, 0.26), t)
		c = c.lerp(dirt, 1.0 - smoothstep(1.3, 2.6, dp + detail.get_noise_2d(x * 2.3, z * 2.3) * 0.5))
	var dpond := p.distance_to(pond_center)
	c = c.lerp(Color(0.74, 0.68, 0.45), (1.0 - smoothstep(9.0, 13.5, dpond)) * 0.85)
	var rock := 1.0 - smoothstep(0.62, 0.84, nrm.y)
	c = c.lerp(Color(0.52, 0.50, 0.46).lerp(Color(0.40, 0.38, 0.36), t), rock)
	if h > 14.0:
		c = c.lerp(Color(0.60, 0.62, 0.58), smoothstep(14.0, 22.0, h) * 0.6)
	return c

func build(parent_for_water: Node3D = null) -> void:
	var cell := (HALF * 2.0) / float(RES)
	var n := RES + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var hm := PackedFloat32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	uvs.resize(n * n)
	hm.resize(n * n)
	for iz in range(n):
		for ix in range(n):
			var x := -HALF + ix * cell
			var z := -HALF + iz * cell
			var h := height_at(x, z)
			var idx := iz * n + ix
			var nr := normal_at(x, z)
			verts[idx] = Vector3(x, h, z)
			norms[idx] = nr
			cols[idx] = _color_at(x, z, nr, h)
			uvs[idx] = Vector2(x, z) * 0.25
			hm[idx] = h
	var inds := PackedInt32Array()
	for iz in range(RES):
		for ix in range(RES):
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			inds.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = inds
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED if false else BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic_specular = 0.15
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)
	# Collision: heightmap shape, scaled to cell size.
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = hm
	cs.shape = shape
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	add_child(body)
	# Water
	var water := MeshInstance3D.new()
	water.name = "Pond"
	var pm := PlaneMesh.new()
	pm.size = Vector2(32, 32)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.20, 0.52, 0.72, 0.72)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	wm.metallic = 0.3
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = wm
	water.position = Vector3(pond_center.x, WATER_LEVEL, pond_center.y)
	# Clip the square plane into a disc via a circle mesh instead.
	var disc := CylinderMesh.new()
	disc.top_radius = 11.5
	disc.bottom_radius = 11.5
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 1
	water.mesh = disc
	add_child(water)
