extends SceneTree
## Regenerates the material library (owner: shaders-materials). Deterministic: re-running rewrites
## identical .tres files. Run:  tools/godot.sh --headless --path game --script res://assets/materials/build_materials.gd
## Edit the tables below, never the generated .tres by hand.

const SH: String = "res://assets/shaders/"
const OUT: String = "res://assets/materials/"
const TEX: String = "res://assets/textures/"

# name -> [shader file, {param: value}]
var lib: Dictionary = {
	# --- Cheese (signature) ---------------------------------------------------------------
	"cheese_cheddar": ["cheese", {
		"paste_color": Color(0.98, 0.58, 0.12), "paste_color_deep": Color(0.90, 0.45, 0.06),
		"paste_mottle": 0.35, "paste_roughness": 0.30, "crystal_amount": 0.5, "gloss_clearcoat": 0.5,
		"hole_density": 10.0, "hole_radius": 0.22, "hole_coverage": 0.22, "hole_size_variation": 0.7,
		"rind_color": Color(0.80, 0.36, 0.05), "sss_color": Color(1.0, 0.5, 0.1), "sss_strength": 0.6}],
	"cheese_swiss": ["cheese", {
		"paste_color": Color(1.0, 0.88, 0.45), "paste_color_deep": Color(0.96, 0.80, 0.36),
		"paste_mottle": 0.25, "paste_roughness": 0.34, "crystal_amount": 0.0, "gloss_clearcoat": 0.45,
		"hole_density": 7.0, "hole_radius": 0.42, "hole_coverage": 0.85, "hole_size_variation": 0.55,
		"hole_tint": Color(0.80, 0.66, 0.40),
		"rind_color": Color(0.88, 0.70, 0.30), "sss_color": Color(1.0, 0.8, 0.35), "sss_strength": 0.55}],
	"cheese_blue": ["cheese", {
		"paste_color": Color(0.93, 0.91, 0.82), "paste_color_deep": Color(0.86, 0.84, 0.72),
		"paste_mottle": 0.4, "paste_roughness": 0.5, "crystal_amount": 0.15, "gloss_clearcoat": 0.15,
		"hole_density": 16.0, "hole_radius": 0.18, "hole_coverage": 0.3, "hole_size_variation": 0.8,
		"hole_tint": Color(0.55, 0.62, 0.60),
		"vein_amount": 0.75, "vein_scale": 12.0, "vein_color": Color(0.16, 0.30, 0.34),
		"rind_color": Color(0.78, 0.74, 0.62), "rind_wax": 0.1, "rind_roughness": 0.7,
		"sss_color": Color(0.95, 0.92, 0.8), "sss_strength": 0.4}],
	"cheese_wax_red": ["cheese", { # wax-dipped wheel (whole surface = rind)
		"rind_source": 2, "rind_color": Color(0.62, 0.04, 0.03), "rind_wax": 0.9, "rind_roughness": 0.25,
		"rind_bumps": 0.15, "sss_strength": 0.3, "sss_color": Color(0.8, 0.1, 0.05)}],
	# --- Fur (shell 0 materials; RatMaterials.build_fur makes the chain) ---------------------
	"fur_cat_tabby": ["fur", {
		"fur_length": 0.04, "density": 260.0, "root_color": Color(0.50, 0.20, 0.05),
		"tip_color": Color(1.0, 0.62, 0.24), "stripe_color": Color(0.42, 0.14, 0.03), "stripe_amount": 0.75,
		"stripe_frequency": 7.0, "stripe_axis": Vector3(0, 1, 0), "color_variation": 0.25, "clump": 0.35}],
	"fur_rat_grey": ["fur", {
		"fur_length": 0.03, "density": 320.0, "root_color": Color(0.34, 0.32, 0.30),
		"tip_color": Color(0.74, 0.71, 0.68), "color_variation": 0.3, "clump": 0.5, "roughness": 0.55,
		"gravity_strength": 0.35}],
	"fur_rat_brown": ["fur", {
		"fur_length": 0.032, "density": 300.0, "root_color": Color(0.28, 0.18, 0.10),
		"tip_color": Color(0.66, 0.48, 0.32), "color_variation": 0.3, "clump": 0.55, "gravity_strength": 0.4}],
	"fur_mouse": ["fur", {
		"fur_length": 0.016, "density": 360.0, "root_color": Color(0.30, 0.24, 0.20),
		"tip_color": Color(0.72, 0.64, 0.56), "color_variation": 0.2, "clump": 0.25}],
	"fur_cat_tabby_lod": ["fur_lod", {
		"density": 260.0, "root_color": Color(0.50, 0.20, 0.05), "tip_color": Color(1.0, 0.62, 0.24),
		"stripe_color": Color(0.42, 0.14, 0.03), "stripe_amount": 0.75, "stripe_frequency": 7.0,
		"stripe_axis": Vector3(0, 1, 0)}],
	"fur_rat_grey_lod": ["fur_lod", {
		"density": 320.0, "root_color": Color(0.34, 0.32, 0.30), "tip_color": Color(0.74, 0.71, 0.68)}],
	# --- Skin -------------------------------------------------------------------------------
	"skin_ear": ["skin_sss", {"skin_color": Color(0.90, 0.58, 0.56), "sss_strength": 0.9, "backlight_amount": 0.8}],
	"skin_pawpad": ["skin_sss", {"skin_color": Color(0.35, 0.22, 0.22), "blotch_color": Color(0.20, 0.12, 0.12),
		"roughness": 0.65, "pore_strength": 0.6, "sss_strength": 0.5, "backlight_amount": 0.2}],
	"skin_nose": ["skin_sss", {"skin_color": Color(0.85, 0.45, 0.45), "moistness": 0.8, "sss_strength": 0.7}],
	"skin_rat_tail": ["skin_sss", {"skin_color": Color(0.80, 0.62, 0.60), "blotch_color": Color(0.55, 0.42, 0.42),
		"blotch_amount": 0.5, "pore_scale": 160.0, "pore_strength": 0.5, "sss_strength": 0.6}],
	# --- Cloth ------------------------------------------------------------------------------
	"cloth_uniform_grey": ["cloth", {"cloth_color": Color(0.33, 0.35, 0.30), "weave_pattern": 1}],
	"cloth_uniform_black": ["cloth", {"cloth_color": Color(0.06, 0.06, 0.065), "weave_pattern": 1,
		"sheen": 0.6, "roughness": 0.75}],
	"cloth_officer_red": ["cloth", {"cloth_color": Color(0.45, 0.05, 0.05), "weave_pattern": 0, "sheen": 0.5}],
	"cloth_burlap": ["cloth", {"cloth_color": Color(0.55, 0.44, 0.30), "weave_pattern": 0, "weave_scale": 60.0,
		"weave_strength": 0.9, "roughness": 0.95, "dirt_amount": 0.4}],
	# --- Wet surfaces -----------------------------------------------------------------------
	"wet_stone_sewer": ["wet_stone", {"wetness": 0.8, "puddle_amount": 0.7, "slime_amount": 0.4}],
	"wet_stone_rain": ["wet_stone", {"wetness": 0.6, "puddle_amount": 0.5, "rain_ripples": 1.0,
		"stone_color": Color(0.46, 0.44, 0.42), "slime_amount": 0.0}],
	"wet_stone_cobble_tex": ["wet_stone", {"use_textures": true, "_tex": "cobblestone_floor_01",
		"wetness": 0.7, "puddle_amount": 0.6}],
	"wet_metal_pipe": ["wet_metal", {"rust_amount": 0.4, "grease_amount": 0.25}],
	"wet_metal_painted": ["wet_metal", {"paint_amount": 0.7, "paint_color": Color(0.18, 0.22, 0.18), "rust_amount": 0.3}],
	"wet_metal_grate_tex": ["wet_metal", {"use_textures": true, "_tex": "metal_grate_rusty", "rust_amount": 0.1}],
	# --- Glass / gold / emblem ----------------------------------------------------------------
	"glass_window": ["glass", {"dirt_amount": 0.2}],
	"glass_bottle_green": ["glass", {"glass_tint": Color(0.35, 0.65, 0.35), "base_opacity": 0.15, "refraction": 0.06,
		"dirt_amount": 0.05}],
	"glass_frosted": ["glass", {"frost": 0.8, "base_opacity": 0.2, "dirt_amount": 0.0}],
	"gold_foil": ["gold_foil", {}],
	"gold_smooth": ["gold_foil", {"crinkle": 0.0, "roughness": 0.12, "sparkle_emission": 0.1}],
	"silver_foil": ["gold_foil", {"foil_color": Color(0.92, 0.92, 0.94), "foil_color_2": Color(0.80, 0.82, 0.86)}],
	"emblem_banner": ["emblem", {"uv_scale": Vector2(1.0, 2.0), "emblem_center": Vector2(0.5, 0.6)}],
	"emblem_flag": ["emblem", {"uv_scale": Vector2(1.6, 1.0), "emblem_center": Vector2(0.5, 0.5)}],
	"emblem_armband": ["emblem", {"uv_scale": Vector2(3.0, 1.0), "emblem_center": Vector2(0.5, 0.5), "disc_radius": 0.42}],
	"emblem_painted": ["emblem", {"fabric": 0.0, "wear": 0.35}],
	"emblem_crate": ["emblem", {"fabric": 0.0, "wear": 0.35, "box_mesh_uv": true}],
}

# Triplanar wall/floor materials: tri_<texture id> for every texture set; per-set overrides here.
var tri_overrides: Dictionary = {
	"mossy_stone_wall": {"wetness": 0.3},
	"brick_moss_001": {"wetness": 0.2},
	"metal_plate": {"texture_scale": 0.75},
	"metal_grate_rusty": {"texture_scale": 1.0},
	"floor_tiles_02": {"texture_scale": 0.5},
	"marble_tiles": {"texture_scale": 0.35},
	"herringbone_parquet": {"texture_scale": 0.4},
}


func _init() -> void:
	var made: int = 0
	var failed: int = 0
	for mat_name: String in lib:
		var spec: Array = lib[mat_name]
		var params0: Dictionary = (spec[1] as Dictionary).duplicate()
		var is_paste_cheese: bool = String(spec[0]) == "cheese" and not params0.has("rind_source")
		if is_paste_cheese:
			# Base cheese works on ANY mesh (no vertex colours needed): holes everywhere, no rind.
			params0["rind_source"] = 0
		if _save(mat_name, String(spec[0]), params0):
			made += 1
		else:
			failed += 1
		if is_paste_cheese:
			# <name>_rind: rind where vertex colour R = 1 (wedges/wheels built with a rind mask).
			var pr: Dictionary = (spec[1] as Dictionary).duplicate()
			pr["rind_source"] = 1
			if _save(mat_name + "_rind", "cheese", pr):
				made += 1
			else:
				failed += 1
	var tex_ids: PackedStringArray = []
	for d: String in DirAccess.get_directories_at(TEX):
		if FileAccess.file_exists(TEX + d + "/albedo.jpg"):
			tex_ids.append(d)
	tex_ids.sort()
	for id: String in tex_ids:
		var params: Dictionary = {"_tex": id, "use_textures": true}
		params.merge(tri_overrides.get(id, {}) as Dictionary, true)
		if _save("tri_" + id, "triplanar_pbr", params):
			made += 1
		else:
			failed += 1
	# Procedural placeholder for levels whose texture set is missing.
	if _save("tri_placeholder", "triplanar_pbr", {"use_textures": false}):
		made += 1
	print("BUILD_MATERIALS made=%d failed=%d" % [made, failed])
	quit(1 if failed > 0 else 0)


func _save(mat_name: String, shader_file: String, params: Dictionary) -> bool:
	var sh: Shader = load(SH + shader_file + ".gdshader") as Shader
	if sh == null:
		push_error("missing shader " + shader_file)
		return false
	var m := ShaderMaterial.new()
	m.resource_name = mat_name
	m.shader = sh
	var known: Dictionary = {}
	for u: Dictionary in sh.get_shader_uniform_list(true):
		known[String(u["name"])] = true
	for k: String in params:
		if k == "_tex":
			_bind_textures(m, String(params[k]), known)
		elif known.has(k):
			m.set_shader_parameter(k, params[k])
		else:
			push_error("%s: shader %s has no uniform '%s'" % [mat_name, shader_file, k])
			return false
	var err: Error = ResourceSaver.save(m, OUT + mat_name + ".tres")
	if err != OK:
		push_error("save failed %s: %d" % [mat_name, err])
		return false
	return true


func _bind_textures(m: ShaderMaterial, id: String, known: Dictionary) -> void:
	var slots: Dictionary = {"albedo": "albedo_texture", "normal": "normal_texture",
		"roughness": "roughness_texture", "ao": "ao_texture", "metallic": "metallic_texture"}
	for k: String in slots:
		var p: String = TEX + id + "/" + k + ".jpg"
		if ResourceLoader.exists(p) and known.has(String(slots[k])):
			m.set_shader_parameter(String(slots[k]), load(p))
	if not ResourceLoader.exists(TEX + id + "/metallic.jpg") and known.has("metallic_scale"):
		m.set_shader_parameter("metallic_scale", 0.0)
