extends "res://tests/test_case.gd"
## Material library (owner: shaders-materials): every named material loads with its shader,
## fur shell chains / LOD fallback build correctly, and the studio scene instantiates.

const REQUIRED: Array[String] = [
	"cheese_cheddar", "cheese_swiss", "cheese_blue", "cheese_cheddar_rind", "cheese_swiss_rind",
	"cheese_blue_rind", "cheese_wax_red", "fur_rat_grey", "fur_rat_brown", "fur_mouse", "fur_cat_tabby",
	"fur_rat_grey_lod", "skin_ear", "skin_nose", "skin_pawpad", "skin_rat_tail", "cloth_uniform_grey",
	"cloth_officer_red", "cloth_burlap", "wet_stone_sewer", "wet_stone_rain", "wet_metal_pipe",
	"wet_metal_painted", "glass_window", "glass_bottle_green", "glass_frosted", "gold_foil", "gold_smooth",
	"emblem_flag", "emblem_armband", "emblem_banner", "emblem_painted", "emblem_crate", "tri_placeholder",
]


func test_required_names_exist_and_load() -> void:
	for n: String in REQUIRED:
		if not check(RatMaterials.has_material(n), "material exists: " + n):
			continue
		var m: ShaderMaterial = RatMaterials.get_material(n) as ShaderMaterial
		check(m != null, "is ShaderMaterial: " + n)
		if m != null:
			check(m.shader != null and m.shader.code.length() > 100, "has shader code: " + n)


func test_every_listed_material_loads() -> void:
	var names: PackedStringArray = RatMaterials.list_names()
	check(names.size() >= 60, "library size >= 60 (got %d)" % names.size())
	for n: String in names:
		check(RatMaterials.get_material(n) is ShaderMaterial, "loads: " + n)


func test_cheese_rind_modes() -> void:
	eq(RatMaterials.get_material("cheese_swiss").get_shader_parameter("rind_source"), 0, "base cheese: no rind mask")
	eq(RatMaterials.get_material("cheese_swiss_rind").get_shader_parameter("rind_source"), 1, "_rind uses vertex colour")
	eq(RatMaterials.get_material("cheese_wax_red").get_shader_parameter("rind_source"), 2, "wax = whole surface")


func test_unknown_name_falls_back() -> void:
	var m: Material = RatMaterials.get_material("no_such_material_xyz")
	check(m is StandardMaterial3D, "unknown name -> magenta fallback, never null")


func test_fur_shell_chain() -> void:
	var base: ShaderMaterial = RatMaterials.get_material("fur_rat_grey") as ShaderMaterial
	var root: Material = RatMaterials.build_fur(base, 8)
	var count: int = 0
	var m: Material = root
	var last_index: int = -1
	while m != null:
		count += 1
		last_index = int((m as ShaderMaterial).get_shader_parameter("shell_index"))
		m = m.next_pass
	eq(count, 9, "base + 8 shells")
	eq(last_index, 8, "tip shell index")
	check(base.next_pass == null, "library material not mutated")


func test_fur_lod_fallback() -> void:
	var base: ShaderMaterial = RatMaterials.get_material("fur_cat_tabby") as ShaderMaterial
	var lod: ShaderMaterial = RatMaterials.build_fur(base, 0) as ShaderMaterial
	check(lod != null and lod.shader.resource_path.ends_with("fur_lod.gdshader"), "shells=0 -> LOD shader")
	check(lod.next_pass == null, "LOD is single pass")
	eq(lod.get_shader_parameter("tip_color"), base.get_shader_parameter("tip_color"), "colour carried over")


func test_apply_fur_on_mesh() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	RatMaterials.apply_fur(mi, "fur_mouse", 4)
	check(mi.material_override is ShaderMaterial, "override set")
	check(mi.material_override.next_pass != null, "shells chained")
	mi.free()


func test_studio_scene_instantiates() -> void:
	var ps: PackedScene = load("res://scenes/material_test.tscn") as PackedScene
	if not check(ps != null, "material_test.tscn loads"):
		return
	var inst: Node = ps.instantiate()
	check(inst is MaterialStudio, "root is MaterialStudio")
	inst.free()
