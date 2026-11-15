class_name BattleArena
extends Node3D
## Farm-themed 3D battle backdrop built in code (owner battle-presentation). `build(bg)` picks one of the encounter
## backgrounds (fields, coop, pond, orchard, pasture, barn, silo, windmill, cave, rot, throne): environment + sky + sun,
## noise-shaded ground with a trampled dirt ring, instanced grass, distant hills and real world glb props.
## Party stands on +X (screen right), enemies on -X (screen left), camera looks from +Z.

const SH_GROUND: Shader = preload("res://assets/vfx/arena_ground.gdshader")

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var bg: String = "fields"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _base_ambient: float = 1.0
var _base_sun: float = 1.0

const LOOKS: Dictionary = {
	# sky top, horizon, ground grass a, grass b, sun color, sun energy, fog color, fog density, rot amount
	"fields": [Color(0.32, 0.55, 0.9), Color(0.85, 0.8, 0.65), Color(0.33, 0.55, 0.2), Color(0.55, 0.7, 0.28), Color(1.0, 0.93, 0.8), 1.25, Color(0.85, 0.82, 0.72), 0.004, 0.0],
	"pasture": [Color(0.35, 0.6, 0.92), Color(0.82, 0.86, 0.75), Color(0.3, 0.58, 0.22), Color(0.48, 0.72, 0.3), Color(1.0, 0.95, 0.85), 1.2, Color(0.8, 0.86, 0.8), 0.004, 0.0],
	"coop": [Color(0.4, 0.55, 0.85), Color(0.95, 0.78, 0.6), Color(0.38, 0.52, 0.22), Color(0.6, 0.62, 0.3), Color(1.0, 0.85, 0.65), 1.2, Color(0.95, 0.82, 0.65), 0.005, 0.0],
	"pond": [Color(0.3, 0.52, 0.85), Color(0.75, 0.85, 0.85), Color(0.26, 0.5, 0.26), Color(0.4, 0.62, 0.3), Color(0.95, 0.95, 0.9), 1.1, Color(0.75, 0.85, 0.85), 0.006, 0.0],
	"orchard": [Color(0.38, 0.55, 0.88), Color(0.98, 0.82, 0.62), Color(0.32, 0.5, 0.2), Color(0.55, 0.62, 0.25), Color(1.0, 0.82, 0.6), 1.15, Color(0.95, 0.8, 0.65), 0.005, 0.0],
	"barn": [Color(0.4, 0.5, 0.8), Color(1.0, 0.75, 0.5), Color(0.4, 0.5, 0.22), Color(0.62, 0.58, 0.3), Color(1.0, 0.78, 0.55), 1.1, Color(0.95, 0.75, 0.55), 0.006, 0.0],
	"silo": [Color(0.42, 0.5, 0.75), Color(0.95, 0.75, 0.55), Color(0.4, 0.5, 0.24), Color(0.6, 0.6, 0.32), Color(1.0, 0.8, 0.6), 1.1, Color(0.9, 0.75, 0.6), 0.006, 0.0],
	"windmill": [Color(0.3, 0.5, 0.9), Color(0.9, 0.88, 0.75), Color(0.35, 0.58, 0.24), Color(0.6, 0.75, 0.3), Color(1.0, 0.95, 0.85), 1.25, Color(0.85, 0.88, 0.8), 0.004, 0.0],
	"rot": [Color(0.18, 0.25, 0.32), Color(0.4, 0.55, 0.5), Color(0.25, 0.38, 0.22), Color(0.3, 0.42, 0.28), Color(0.7, 0.85, 0.8), 0.7, Color(0.3, 0.5, 0.45), 0.02, 0.85],
	"cave": [Color(0.05, 0.05, 0.08), Color(0.12, 0.1, 0.1), Color(0.3, 0.28, 0.25), Color(0.35, 0.3, 0.26), Color(1.0, 0.75, 0.45), 0.35, Color(0.12, 0.1, 0.09), 0.03, 0.0],
	"throne": [Color(0.05, 0.04, 0.08), Color(0.15, 0.1, 0.18), Color(0.3, 0.28, 0.25), Color(0.35, 0.3, 0.26), Color(0.7, 0.6, 1.0), 0.4, Color(0.18, 0.12, 0.22), 0.03, 0.7],
}


func build(p_bg: String) -> void:
	bg = p_bg if LOOKS.has(p_bg) else "fields"
	_rng.seed = hash(bg)
	var L: Array = LOOKS[bg]
	var indoor: bool = bg == "cave" or bg == "throne"
	_environment(L, indoor)
	_ground(L, indoor)
	if indoor:
		_cave(bg == "throne")
	else:
		_hills(L)
		_grass(L)
		_props()
	if bg == "rot" or bg == "throne":
		_rot_spores()


func _environment(L: Array, indoor: bool) -> void:
	env = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = L[0]
	sm.sky_horizon_color = L[1]
	sm.ground_horizon_color = L[1]
	sm.ground_bottom_color = (L[2] as Color).darkened(0.5)
	sm.sun_angle_max = 30.0
	sm.sky_energy_multiplier = 1.0 if not indoor else 0.2
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9 if not indoor else 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = L[6]
	env.fog_density = float(L[7])
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.light_color = L[4]
	sun.light_energy = float(L[5])
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-48, 35, 0)
	add_child(sun)
	_base_ambient = env.ambient_light_energy
	_base_sun = sun.light_energy
	var fill: DirectionalLight3D = DirectionalLight3D.new()   # cool rim/fill from behind-left
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-25, -150, 0)
	add_child(fill)


func _ground(L: Array, indoor: bool) -> void:
	var g: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(160, 160)
	g.mesh = pm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_GROUND
	m.set_shader_parameter("grass_a", L[2])
	m.set_shader_parameter("grass_b", L[3])
	m.set_shader_parameter("rot", float(L[8]))
	m.set_shader_parameter("stone", 1.0 if indoor else 0.0)
	g.material_override = m
	add_child(g)


func _hills(L: Array) -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = (L[2] as Color).darkened(0.1)
	m.roughness = 1.0
	for i: int in 9:
		var h: MeshInstance3D = MeshInstance3D.new()
		var s: SphereMesh = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		h.mesh = s
		h.material_override = m
		var a: float = lerpf(-2.6, -0.5, float(i) / 8.0)   # arc behind the arena (negative z)
		var r: float = _rng.randf_range(55.0, 70.0)
		h.position = Vector3(cos(a) * r, -2.0, sin(a) * r)
		h.scale = Vector3(_rng.randf_range(14, 24), _rng.randf_range(5, 10), _rng.randf_range(10, 16))
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)


func _grass(L: Array) -> void:
	var blade: CylinderMesh = CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.035
	blade.height = 0.38
	blade.radial_segments = 3
	blade.rings = 1
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	blade.material = m
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	var n: int = 5000
	mm.instance_count = n
	var placed: int = 0
	for i: int in n:
		var p: Vector3 = Vector3(_rng.randf_range(-26, 26), 0, _rng.randf_range(-22, 3.5))
		if Vector2(p.x * 0.8, p.z * 1.15).length() < 6.5:   # keep the dirt ring clear
			p.x += 9.0 * signf(p.x if p.x != 0.0 else 1.0)
		var b: Basis = Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25))
		var s: float = _rng.randf_range(0.6, 1.5)
		mm.set_instance_transform(placed, Transform3D(b.scaled(Vector3(s, s, s)), p + Vector3(0, 0.17 * s, 0)))
		mm.set_instance_color(placed, (L[2] as Color).lerp(L[3], _rng.randf()).lightened(_rng.randf_range(-0.1, 0.15)))
		placed += 1
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Props per background: [model, x, z, yaw_deg, scale]. Behind the fight (negative z) so they never block the camera.
func _prop_list() -> Array:
	var fence: Array = []
	for i: int in 9:
		fence.append(["world_fence", -16.0 + i * 4.0, -11.0, 0.0, 1.0])
	match bg:
		"fields":
			var a: Array = [["world_barn", -20, -26, 25, 1.0], ["world_windmill", 22, -34, -20, 1.0], ["world_silo", -11, -30, 0, 1.0],
				["world_haybale", 9, -9, 30, 1.0], ["world_haybale", 10.5, -8, 70, 1.0], ["world_signpost", -9, -6, 15, 1.0], ["world_tractor", 14, -15, -35, 1.0]]
			for i: int in 7:
				a.append(["world_crop_corn", -6.0 + i * 1.6, -14.0, 0.0, 1.0])
				a.append(["world_crop_wheat", -5.0 + i * 1.6, -16.0, 0.0, 1.0])
			return a + fence
		"pasture":
			return [["world_tree_oak", -14, -16, 0, 1.2], ["world_tree_oak", 16, -19, 40, 1.4], ["world_haybale", 8, -9, 10, 1.0],
				["world_barn", 4, -32, -10, 1.0], ["world_well", -9, -8, 0, 1.0]] + fence
		"coop":
			return [["world_coop", -7, -13, 20, 1.0], ["world_haybale", 6, -9, 40, 1.0], ["world_haybale", 7, -10, 5, 1.0],
				["world_crate", -10, -7, 15, 1.0], ["world_farmhouse", 14, -28, -25, 1.0]] + fence
		"pond":
			return [["world_pond_dock", -2, -14, 0, 1.0], ["world_tree_oak", -15, -17, 0, 1.3], ["world_tree_oak", 13, -18, 0, 1.1]]
		"orchard":
			var o: Array = []
			for i: int in 8:
				o.append(["world_tree_apple", -18.0 + i * 5.0 + _rng.randf_range(-1, 1), -12.0 - _rng.randf_range(0, 6), _rng.randf() * 360.0, _rng.randf_range(0.9, 1.3)])
			return o + [["world_shrine", 0, -26, 0, 1.0]]
		"barn":
			return [["world_barn", 0, -18, 0, 1.2], ["world_haybale", -8, -9, 20, 1.0], ["world_haybale", -9, -10.5, 80, 1.0],
				["world_tractor", 9, -11, -30, 1.0], ["world_crate", 7, -8, 10, 1.0]] + fence
		"silo":
			return [["world_silo", -6, -16, 0, 1.2], ["world_silo", 2, -19, 0, 1.0], ["world_crate", 8, -9, 20, 1.0],
				["world_crate", 9, -8, 50, 1.0], ["world_barn", 18, -26, -30, 1.0]]
		"windmill":
			return [["world_windmill", 0, -20, 0, 1.3], ["world_haybale", 8, -9, 20, 1.0], ["world_tree_oak", -14, -15, 0, 1.2]] + fence
		"rot":
			return [["world_barn", -18, -24, 25, 1.0], ["world_tree_oak", 12, -16, 0, 1.2], ["world_cheese_blue", -6, -9, 0, 1.0],
				["world_cheese_gorgonzola", 7, -10, 30, 1.0], ["world_signpost", -10, -7, 40, 1.0]] + fence
	return fence


func _props() -> void:
	for p: Array in _prop_list():
		_place(str(p[0]), Vector3(float(p[1]), 0, float(p[2])), float(p[3]), float(p[4]))
	if bg == "pond":
		var w: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(30, 10)
		w.mesh = pm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.45, 0.55)
		m.metallic = 0.3
		m.roughness = 0.05
		w.material_override = m
		w.position = Vector3(0, 0.03, -16)
		add_child(w)


func _place(id: String, pos: Vector3, yaw: float, scl: float) -> Node3D:
	var path: String = "res://assets/models/%s.glb" % id
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * scl
	return n


func _cave(throne: bool) -> void:
	# rocky dome + glowing cheese crystals + torches
	var dome: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = 24.0
	s.height = 30.0
	s.radial_segments = 24
	s.rings = 12
	s.is_hemisphere = true
	dome.mesh = s
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.22, 0.2) if not throne else Color(0.2, 0.17, 0.22)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	dome.mesh = s
	dome.material_override = m
	dome.position = Vector3(0, -0.5, -4)
	add_child(dome)
	for i: int in 14:
		var a: float = lerpf(PI * 1.05, PI * 1.95, float(i) / 13.0)
		var r: float = _rng.randf_range(11.0, 16.0)
		var rock: MeshInstance3D = MeshInstance3D.new()
		var bm: SphereMesh = SphereMesh.new()
		bm.radial_segments = 7
		bm.rings = 4
		rock.mesh = bm
		rock.material_override = m
		rock.position = Vector3(cos(a) * r, 0, sin(a) * r * 0.8 - 2)
		rock.scale = Vector3(_rng.randf_range(2, 4), _rng.randf_range(2, 6), _rng.randf_range(2, 4))
		add_child(rock)
	var glow: Color = Color(1.0, 0.8, 0.35) if not throne else Color(0.35, 0.9, 0.7)
	for i: int in 6:
		var a: float = lerpf(PI * 1.1, PI * 1.9, float(i) / 5.0)
		var p: Vector3 = Vector3(cos(a) * 10.0, 0, sin(a) * 8.0 - 2)
		var cm: MeshInstance3D = MeshInstance3D.new()
		var cy: CylinderMesh = CylinderMesh.new()
		cy.top_radius = 0.0
		cy.bottom_radius = 0.5
		cy.height = _rng.randf_range(1.5, 3.0)
		cy.radial_segments = 6
		cm.mesh = cy
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = glow
		gm.emission_enabled = true
		gm.emission = glow
		gm.emission_energy_multiplier = 2.0
		cm.material_override = gm
		cm.position = p + Vector3(0, cy.height * 0.5, 0)
		cm.rotation = Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
		add_child(cm)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = glow
		l.light_energy = 2.5
		l.omni_range = 9.0
		l.position = p + Vector3(0, 1.5, 0)
		add_child(l)
	_place("world_cheese_parmesan" if not throne else "world_cheese_gorgonzola", Vector3(-8, 0, -6), 20, 1.0)
	_place("world_wheel_cheese", Vector3(8, 0, -7), -30, 1.0)
	_place("world_crate", Vector3(10, 0, -4), 10, 1.0)
	var key: OmniLight3D = OmniLight3D.new()   # warm key over the fight
	key.light_color = Color(1.0, 0.8, 0.6)
	key.light_energy = 2.0
	key.omni_range = 16.0
	key.shadow_enabled = true
	key.position = Vector3(0, 7, 3)
	add_child(key)


func _rot_spores() -> void:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.amount = 160
	gp.lifetime = 8.0
	gp.preprocess = 8.0
	gp.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 12, 40))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 2, 12)
	pm.direction = Vector3.UP
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0.1, 0.05, 0)
	pm.scale_min = 0.04
	pm.scale_max = 0.1
	pm.color = Color(0.5, 1.0, 0.8, 0.7)
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = preload("res://assets/vfx/soft_particle.gdshader")
	q.material = sm
	gp.draw_pass_1 = q
	gp.position = Vector3(0, 1.5, -3)
	add_child(gp)


## Dim the world for cinematics (0 = normal, 1 = near black). Tweened by the caller.
func set_dim(v: float) -> void:
	if env == null:
		return
	env.ambient_light_energy = lerpf(_base_ambient, 0.08, v)
	sun.light_energy = lerpf(_base_sun, 0.05, v)
	env.background_energy_multiplier = lerpf(1.0, 0.15, v)


## Formation slots. Party: right side, staggered toward camera. Enemies: left side, spread by count.
static func party_slot(i: int, n: int) -> Vector3:
	var z: float = -1.6 + float(i) * (3.4 / maxf(1.0, float(maxi(n, 2) - 1)))
	return Vector3(3.3 + float(i) * 0.35, 0, z)


static func enemy_slot(i: int, n: int, boss: bool) -> Vector3:
	if n == 1:
		return Vector3(-3.6 if not boss else -4.4, 0, 0)
	var z: float = -2.8 + float(i) * (3.9 / float(n - 1))
	if boss and n == 2:
		z = -3.0 + float(i) * 5.2   # a 3.3 m boss needs room next to its escort
	return Vector3(-3.4 - absf(float(i) - float(n - 1) * 0.5) * 0.5 - (1.0 if boss else 0.0), 0, z)
