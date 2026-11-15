class_name RatMaterials
extends RefCounted
## Material library access (owner: shaders-materials).
## Other modules reference materials by NAME, never by path:
##   mesh.material_override = RatMaterials.get_material("cheese_swiss")
##   RatMaterials.apply_fur(mesh_instance, "fur_cat_tabby")      # shell fur, shell count from quality
## Names = file stems in res://assets/materials/*.tres (see list_names()). Unknown names return a
## magenta StandardMaterial3D and push a warning instead of crashing.

const DIR: String = "res://assets/materials/"
const FUR_SHADER: String = "res://assets/shaders/fur.gdshader"
const FUR_LOD_SHADER: String = "res://assets/shaders/fur_lod.gdshader"
## Shells per Settings.Quality (LOW, MEDIUM, HIGH, ULTRA). 0 = use the single-pass LOD shader.
const FUR_SHELLS_BY_QUALITY: Array[int] = [0, 8, 16, 24]

static var _cache: Dictionary = {}


static func list_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in ResourceLoader.list_directory(DIR):
		if f.ends_with(".tres"):
			out.append(f.get_basename())
	out.sort()
	return out


static func has_material(mat_name: String) -> bool:
	return ResourceLoader.exists(DIR + mat_name + ".tres")


static func get_material(mat_name: String) -> Material:
	if _cache.has(mat_name):
		return _cache[mat_name] as Material
	var path: String = DIR + mat_name + ".tres"
	var m: Material = null
	if ResourceLoader.exists(path):
		m = load(path) as Material
	if m == null:
		push_warning("RatMaterials: unknown material '%s'" % mat_name)
		var fb := StandardMaterial3D.new()
		fb.albedo_color = Color(1.0, 0.0, 1.0)
		m = fb
	_cache[mat_name] = m
	return m


## Quality-driven shell count (reads the Settings autoload if present, else HIGH).
static func fur_shell_count() -> int:
	var q: int = 2
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null and loop.root.has_node("Settings"):
		q = int(loop.root.get_node("Settings").get("quality"))
	return FUR_SHELLS_BY_QUALITY[clampi(q, 0, FUR_SHELLS_BY_QUALITY.size() - 1)]


## Build a shell chain from a fur base material (shell 0 = fur.gdshader material from the library).
## Each shell is a duplicate with shell_index = i chained through next_pass. Works on skinned meshes
## (extrusion runs after skinning in the vertex shader). shells <= 0 returns the LOD material.
static func build_fur(base: ShaderMaterial, shells: int) -> Material:
	if shells <= 0:
		return make_fur_lod(base)
	var root: ShaderMaterial = base.duplicate() as ShaderMaterial
	root.set_shader_parameter("shell_index", 0)
	root.set_shader_parameter("shell_count", shells)
	var prev: ShaderMaterial = root
	for i: int in range(1, shells + 1):
		var s: ShaderMaterial = base.duplicate() as ShaderMaterial
		s.next_pass = null
		s.set_shader_parameter("shell_index", i)
		s.set_shader_parameter("shell_count", shells)
		s.render_priority = clampi(i, -128, 127)
		prev.next_pass = s
		prev = s
	return root


## Single-pass fallback carrying over the shared colour parameters.
static func make_fur_lod(base: ShaderMaterial) -> ShaderMaterial:
	var lod := ShaderMaterial.new()
	lod.shader = load(FUR_LOD_SHADER) as Shader
	for p: String in ["density", "root_color", "tip_color", "stripe_color", "stripe_amount", "stripe_frequency",
			"stripe_axis", "color_variation", "color_map", "rim_strength", "rim_tint", "backlight_amount"]:
		var v: Variant = base.get_shader_parameter(p)
		if v != null:
			lod.set_shader_parameter(p, v)
	return lod


## Convenience: put shell fur (or its LOD) on a MeshInstance3D / any GeometryInstance3D.
static func apply_fur(target: GeometryInstance3D, fur_name: String, shells: int = -1) -> void:
	var base: ShaderMaterial = get_material(fur_name) as ShaderMaterial
	if base == null:
		target.material_override = get_material(fur_name)
		return
	var n: int = fur_shell_count() if shells < 0 else shells
	target.material_override = build_fur(base, n)


## Shell fur for close-up, LOD shader beyond lod_distance (uses GeometryInstance3D visibility ranges
## on a duplicated instance). Returns the LOD twin so callers can free it with the original.
static func apply_fur_with_lod(target: MeshInstance3D, fur_name: String, lod_distance: float = 12.0) -> MeshInstance3D:
	apply_fur(target, fur_name)
	var base: ShaderMaterial = get_material(fur_name) as ShaderMaterial
	if base == null:
		return null
	target.visibility_range_end = lod_distance
	target.visibility_range_end_margin = 1.0
	target.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var twin: MeshInstance3D = target.duplicate() as MeshInstance3D
	twin.name = target.name + "_FurLOD"
	twin.material_override = make_fur_lod(base)
	twin.visibility_range_begin = lod_distance
	twin.visibility_range_begin_margin = 1.0
	twin.visibility_range_end = 0.0
	target.add_sibling(twin)
	return twin
