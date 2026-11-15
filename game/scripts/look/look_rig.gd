class_name LookRig
extends Node3D
## Data-driven per-level look (owner: look-dev). ARCHITECTURE section 5.
## Reads res://data/look/default.json deep-merged with res://data/look/<levelid>.json and builds:
##   Environment (HDRI sky, ACES/filmic tonemap, exposure, auto-exposure, SDFGI, SSAO/SSIL, SSR, volumetric
##   fog, glow, colour grading via a generated 3D LUT + adjustments), a sun/moon DirectionalLight3D, a
##   shadowless fill light, a film/lens finish (grain, vignette, CA; no lens dirt), reflection probes,
##   and retunes the level builder's OmniLights (energy/range/colour per zone, torch flicker).
## Quality: Settings (Low/Med/High/Ultra) switches the expensive features; this rig re-applies on
## Events.settings_changed and adds its own degradation (probes, post finish, fog/shadow tiers).
##
## Use in game: instance res://scenes/look_rig.tscn anywhere in the tree (e.g. under Main). It follows
## Events.level_loaded and applies itself to Game.current_level(). Direct use: LookRig.apply_to(level, id).
## Preview / screenshots: tools/shot.sh res://scenes/look_rig.tscn out.png --user-arg --look-level=e1m1
##   [--user-arg --look-quality=0..3] [--user-arg --look-off=1] [--cam ...]

const LOOK_DIR: String = "res://data/look/"
const POST_SHADER: String = "res://scripts/look/post_fx.gdshader"
const LEVEL_SCENE: String = "res://scenes/level_base.tscn"
const LUT_SIZE: int = 32

@export var preview_level: String = ""
## When true (in game), follow Events.level_loaded automatically.
@export var auto_follow: bool = true

var look: Dictionary = {}
var level_id: String = ""
var level: Node = null
var env: Environment = null
var cam_attr: CameraAttributesPractical = null
var sun: DirectionalLight3D = null
var fill: DirectionalLight3D = null

var _we: WorldEnvironment = null
var _post_layer: CanvasLayer = null
var _post_rect: ColorRect = null
var _probes: Array[ReflectionProbe] = []
var _flicker: Array[Dictionary] = []  # {light, base, amp, phase}
var _noise: FastNoiseLite = FastNoiseLite.new()
var _t: float = 0.0
var _preview_cam: Camera3D = null
var _measure_frames: int = 0
var _gpu_ms: Array[float] = []
var _cpu_ms: Array[float] = []


# ───────────────────────────── lifecycle ─────────────────────────────
func _ready() -> void:
	_noise.frequency = 3.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var bus: Node = get_node_or_null("/root/Events")
	if bus != null:
		if auto_follow and bus.has_signal("level_loaded"):
			bus.connect("level_loaded", _on_level_loaded)
		if bus.has_signal("settings_changed"):
			bus.connect("settings_changed", _on_settings_changed)
	var args: Dictionary = _user_args()
	var pid: String = String(args.get("look-level", preview_level))
	if pid != "":
		_preview(pid, args)


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in _flicker:
		var l: Light3D = f["light"] as Light3D
		if is_instance_valid(l):
			var n: float = _noise.get_noise_1d(_t * float(f["speed"]) + float(f["phase"]))
			l.light_energy = float(f["base"]) * (1.0 + float(f["amp"]) * n)
	if _measure_frames > 0:
		var vp_rid: RID = get_viewport().get_viewport_rid()
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
		_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
		_measure_frames -= 1
		if _measure_frames == 0:
			_report_timing()


# ───────────────────────────── public API ─────────────────────────────
## One-call helper: create a rig under `lvl`, apply the look for `id`. Returns the rig.
static func apply_to(lvl: Node, id: String) -> LookRig:
	var rig: LookRig = LookRig.new()
	rig.name = "LookRig"
	rig.auto_follow = false
	lvl.add_child(rig)
	rig.apply(lvl, id)
	return rig


## Load the merged look dictionary for a level id (default.json <- <id>.json).
static func load_look(id: String) -> Dictionary:
	var base: Dictionary = _read_json(LOOK_DIR + "default.json")
	var lv: Dictionary = _read_json(LOOK_DIR + id + ".json")
	return deep_merge(base, lv)


static func deep_merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate(true)
	for k: Variant in b:
		if out.has(k) and out[k] is Dictionary and b[k] is Dictionary:
			out[k] = deep_merge(out[k] as Dictionary, b[k] as Dictionary)
		else:
			out[k] = b[k]
	return out


## Apply the look for `id` to a built level node (a LevelBuilder or anything with lights/a WorldEnvironment).
func apply(lvl: Node, id: String) -> void:
	level = lvl
	level_id = id
	look = load_look(id)
	_build_environment()
	_build_sun_and_fill()
	_tune_level_lights()
	_remap_materials()
	_hide_meshes()
	_build_probes()
	_build_post()
	_apply_quality()
	# Other modules may poke the environment right after the level is built (see Requests); re-assert once.
	_reassert.call_deferred()


func quality() -> int:
	var s: Node = get_node_or_null("/root/Settings")
	if s != null and "quality" in s:
		return int(s.get("quality"))
	return 2


# ───────────────────────────── following the game ─────────────────────────────
func _on_level_loaded(id: String) -> void:
	var g: Node = get_node_or_null("/root/Game")
	var lvl: Node = g.call("current_level") as Node if g != null and g.has_method("current_level") else null
	if lvl == null or not is_instance_valid(lvl):
		return
	if lvl == level and id == level_id and _we != null and is_instance_valid(_we):
		return
	# Game emits level_loaded before the deferred build; the builder emits it again after building.
	if lvl.find_child("Geometry", false, false) == null and lvl.has_signal("built"):
		if not lvl.is_connected("built", _on_built):
			lvl.connect("built", _on_built.bind(lvl, id), CONNECT_ONE_SHOT)
		return
	apply(lvl, id)


func _on_built(_stats: Dictionary, lvl: Node, id: String) -> void:
	if is_instance_valid(lvl):
		apply(lvl, id)


func _on_settings_changed() -> void:
	if env != null:
		_apply_quality()


func _reassert() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if env == null:
		return
	if _we != null and is_instance_valid(_we) and _we.environment != env:
		_we.environment = env
	_apply_env_values()
	_apply_quality()


# ───────────────────────────── environment ─────────────────────────────
func _build_environment() -> void:
	env = Environment.new()
	cam_attr = CameraAttributesPractical.new()
	_we = null
	if level != null:
		_we = level.find_child("LevelEnvironment", true, false) as WorldEnvironment
		if _we == null:
			var any: Array[Node] = level.find_children("*", "WorldEnvironment", true, false)
			if not any.is_empty():
				_we = any[0] as WorldEnvironment
	if _we == null:
		_we = WorldEnvironment.new()
		_we.name = "LookEnvironment"
		add_child(_we)
	_we.environment = env
	_we.camera_attributes = cam_attr
	_apply_env_values()


func _apply_env_values() -> void:
	var sky_d: Dictionary = _d("sky")
	var sky_tex: Texture2D = null
	var hdri: String = String(sky_d.get("hdri", ""))
	if hdri != "" and ResourceLoader.exists(hdri):
		sky_tex = load(hdri) as Texture2D
	if sky_tex != null:
		var pm: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
		pm.panorama = sky_tex
		pm.energy_multiplier = float(sky_d.get("energy", 1.0))
		var sk: Sky = Sky.new()
		sk.sky_material = pm
		sk.radiance_size = Sky.RADIANCE_SIZE_256
		env.sky = sk
		env.sky_rotation = Vector3(0.0, deg_to_rad(float(sky_d.get("rotation_deg", 0.0))), 0.0)
	var bg: String = String(sky_d.get("background", "color"))
	if bg == "sky" and sky_tex != null:
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = _c(sky_d.get("bg_color", [0.0, 0.0, 0.0]))
	env.background_energy_multiplier = float(sky_d.get("bg_energy", 1.0))
	# ambient + reflections
	var amb: Dictionary = _d("ambient")
	var src: String = String(amb.get("source", "color"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if (src == "sky" and sky_tex != null) else Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _c(amb.get("color", [0.05, 0.05, 0.05]))
	env.ambient_light_energy = float(amb.get("energy", 1.0))
	env.ambient_light_sky_contribution = float(amb.get("sky_contribution", 1.0))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if sky_tex != null else Environment.REFLECTION_SOURCE_DISABLED
	# tonemap / exposure
	var tm: Dictionary = _d("tonemap")
	match String(tm.get("mode", "aces")):
		"filmic": env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		"agx": env.tonemap_mode = Environment.TONE_MAPPER_AGX
		"linear": env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_: env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(tm.get("exposure", 1.0))
	env.tonemap_white = float(tm.get("white", 6.0))
	var ae: Dictionary = _d("auto_exposure")
	cam_attr.auto_exposure_enabled = bool(ae.get("enabled", true))
	cam_attr.auto_exposure_scale = float(ae.get("scale", 0.4))
	cam_attr.auto_exposure_speed = float(ae.get("speed", 0.6))
	cam_attr.auto_exposure_min_sensitivity = float(ae.get("min_sensitivity", 50.0))
	cam_attr.auto_exposure_max_sensitivity = float(ae.get("max_sensitivity", 800.0))
	cam_attr.exposure_multiplier = float(ae.get("multiplier", 1.0))
	# SDFGI
	var gi: Dictionary = _d("sdfgi")
	env.sdfgi_use_occlusion = bool(gi.get("occlusion", true))
	env.sdfgi_read_sky_light = bool(gi.get("read_sky", false))
	env.sdfgi_bounce_feedback = float(gi.get("bounce", 0.6))
	env.sdfgi_min_cell_size = float(gi.get("min_cell", 0.2))
	env.sdfgi_energy = float(gi.get("energy", 1.0))
	env.sdfgi_normal_bias = float(gi.get("normal_bias", 1.1))
	env.sdfgi_probe_bias = float(gi.get("probe_bias", 1.1))
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	# SSAO / SSIL / SSR
	var ao: Dictionary = _d("ssao")
	env.ssao_radius = float(ao.get("radius", 1.2))
	env.ssao_intensity = float(ao.get("intensity", 2.0))
	env.ssao_power = float(ao.get("power", 1.5))
	env.ssao_detail = float(ao.get("detail", 0.5))
	env.ssao_light_affect = float(ao.get("light_affect", 0.1))
	env.ssao_ao_channel_affect = float(ao.get("channel_affect", 0.3))
	var il: Dictionary = _d("ssil")
	env.ssil_radius = float(il.get("radius", 5.0))
	env.ssil_intensity = float(il.get("intensity", 1.0))
	env.ssil_normal_rejection = float(il.get("normal_rejection", 1.0))
	var sr: Dictionary = _d("ssr")
	env.ssr_fade_in = float(sr.get("fade_in", 0.15))
	env.ssr_fade_out = float(sr.get("fade_out", 2.0))
	env.ssr_depth_tolerance = float(sr.get("depth_tolerance", 0.2))
	# volumetric fog
	var fog: Dictionary = _d("fog")
	env.volumetric_fog_density = float(fog.get("density", 0.02))
	env.volumetric_fog_albedo = _c(fog.get("albedo", [0.8, 0.8, 0.8]))
	env.volumetric_fog_emission = _c(fog.get("emission", [0.0, 0.0, 0.0]))
	env.volumetric_fog_emission_energy = float(fog.get("emission_energy", 1.0))
	env.volumetric_fog_anisotropy = float(fog.get("anisotropy", 0.5))
	env.volumetric_fog_length = float(fog.get("length", 64.0))
	env.volumetric_fog_detail_spread = float(fog.get("detail_spread", 2.0))
	env.volumetric_fog_gi_inject = float(fog.get("gi_inject", 1.0))
	env.volumetric_fog_ambient_inject = float(fog.get("ambient_inject", 0.0))
	env.volumetric_fog_sky_affect = float(fog.get("sky_affect", 0.3))
	env.volumetric_fog_temporal_reprojection_enabled = true
	var dfog: Dictionary = _d("depth_fog")
	env.fog_enabled = bool(dfog.get("enabled", false))
	env.fog_light_color = _c(dfog.get("color", [0.1, 0.1, 0.1]))
	env.fog_light_energy = float(dfog.get("energy", 1.0))
	env.fog_density = float(dfog.get("density", 0.005))
	env.fog_sky_affect = float(dfog.get("sky_affect", 0.5))
	env.fog_aerial_perspective = float(dfog.get("aerial", 0.0))
	# glow
	var gl: Dictionary = _d("glow")
	env.glow_intensity = float(gl.get("intensity", 0.8))
	env.glow_strength = float(gl.get("strength", 1.0))
	env.glow_bloom = float(gl.get("bloom", 0.03))
	env.glow_hdr_threshold = float(gl.get("hdr_threshold", 1.0))
	env.glow_hdr_scale = float(gl.get("hdr_scale", 2.0))
	match String(gl.get("blend", "softlight")):
		"additive": env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		"screen": env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		"mix": env.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX
		_: env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var levels: Array = gl.get("levels", [0.0, 0.0, 1.0, 0.8, 0.5, 0.25, 0.0]) as Array
	for i: int in mini(levels.size(), 7):
		env.set_glow_level(i, float(levels[i]))
	# colour grading
	var gr: Dictionary = _d("grade")
	env.adjustment_enabled = true
	env.adjustment_brightness = float(gr.get("brightness", 1.0))
	env.adjustment_contrast = float(gr.get("contrast", 1.0))
	env.adjustment_saturation = float(gr.get("saturation", 1.0))
	env.adjustment_color_correction = make_lut(gr)


## Build a 3D colour-grading LUT from lift/gamma/gain, split toning and a global tint.
static func make_lut(gr: Dictionary) -> ImageTexture3D:
	var tex: ImageTexture3D = ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, LUT_SIZE, LUT_SIZE, LUT_SIZE, false, lut_images(gr))
	return tex


## The LUT slices (one Image per blue level; x = red, y = green).
static func lut_images(gr: Dictionary) -> Array[Image]:
	var lift: Vector3 = _v3(gr.get("lift", [0.0, 0.0, 0.0]))
	var gamma: Vector3 = _v3(gr.get("gamma", [1.0, 1.0, 1.0]))
	var gain: Vector3 = _v3(gr.get("gain", [1.0, 1.0, 1.0]))
	var shadows: Vector3 = _v3(gr.get("shadow_tint", [0.0, 0.0, 0.0]))
	var highs: Vector3 = _v3(gr.get("highlight_tint", [0.0, 0.0, 0.0]))
	var tint: Vector3 = _v3(gr.get("tint", [1.0, 1.0, 1.0]))
	var n: int = LUT_SIZE
	var images: Array[Image] = []
	for bz: int in n:
		var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGB8)
		for gy: int in n:
			for rx: int in n:
				var c: Vector3 = Vector3(rx, gy, bz) / float(n - 1)
				var lum: float = c.dot(Vector3(0.2126, 0.7152, 0.0722))
				# split toning: push shadows/highlights toward tints, weighted by luminance
				c += shadows * (1.0 - smoothstep(0.0, 0.55, lum)) * 0.5
				c += highs * smoothstep(0.45, 1.0, lum) * 0.5
				# ASC-CDL-ish lift/gamma/gain
				c = Vector3(_lgg(c.x, lift.x, gamma.x, gain.x), _lgg(c.y, lift.y, gamma.y, gain.y), _lgg(c.z, lift.z, gamma.z, gain.z))
				c *= tint
				img.set_pixel(rx, gy, Color(clampf(c.x, 0.0, 1.0), clampf(c.y, 0.0, 1.0), clampf(c.z, 0.0, 1.0)))
		images.append(img)
	return images


static func _lgg(x: float, lift: float, gamma: float, gain: float) -> float:
	var v: float = clampf(x * gain + lift * (1.0 - x), 0.0, 1.0)
	return pow(v, 1.0 / maxf(gamma, 0.01))


# ───────────────────────────── lights ─────────────────────────────
func _build_sun_and_fill() -> void:
	for old: Node in [sun, fill]:
		if old != null and is_instance_valid(old):
			old.queue_free()
	sun = null
	fill = null
	var s: Dictionary = _d("sun")
	if bool(s.get("enabled", false)):
		sun = DirectionalLight3D.new()
		sun.name = "LookSun"
		_orient(sun, s.get("dir", [0.4, 0.8, 0.3]))
		sun.light_color = _c(s.get("color", [1, 1, 1]))
		sun.light_energy = float(s.get("energy", 1.0))
		sun.light_angular_distance = float(s.get("angular_deg", 0.5))
		sun.shadow_enabled = bool(s.get("shadow", true))
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.0
		sun.shadow_blur = float(s.get("shadow_blur", 1.0))
		sun.directional_shadow_max_distance = float(s.get("shadow_distance", 80.0))
		sun.light_volumetric_fog_energy = float(s.get("fog_energy", 1.0))
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		add_child(sun)
	var f: Dictionary = _d("fill")
	if bool(f.get("enabled", false)):
		fill = DirectionalLight3D.new()
		fill.name = "LookFill"
		_orient(fill, f.get("dir", [-0.3, 0.6, -0.5]))
		fill.light_color = _c(f.get("color", [0.6, 0.7, 1.0]))
		fill.light_energy = float(f.get("energy", 0.05))
		fill.light_specular = float(f.get("specular", 0.1))
		fill.shadow_enabled = false
		fill.light_volumetric_fog_energy = 0.0
		fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		add_child(fill)


func _orient(l: DirectionalLight3D, dir_v: Variant) -> void:
	# dir = direction TOWARD the light (like the reference's moonDir). The light shines along -Z.
	var to_light: Vector3 = _v3(dir_v).normalized()
	if to_light.length() < 0.01:
		to_light = Vector3.UP
	var up: Vector3 = Vector3.UP if absf(to_light.y) < 0.99 else Vector3.FORWARD
	l.basis = Basis.looking_at(-to_light, up)


## Retune the level builder's OmniLights: zone lights (ceiling grid) and practicals (decor torches/lamps).
func _tune_level_lights() -> void:
	_flicker.clear()
	if level == null:
		return
	var L: Dictionary = _d("lights")
	var P: Dictionary = _d("practicals")
	var zones_over: Dictionary = L.get("zones", {}) as Dictionary
	var cell: float = float(level.get("cell")) if "cell" in level else 4.0
	var ldata: Dictionary = level.get("data") as Dictionary if "data" in level else {}
	var zgrid: Array = ldata.get("zoneGrid", []) as Array
	var zones: Dictionary = ldata.get("zones", {}) as Dictionary
	var defaults: Dictionary = ldata.get("defaults", {}) as Dictionary
	var all_lights: Array[Node] = level.find_children("*", "OmniLight3D", true, false)
	var idx: int = 0
	for n: Node in all_lights:
		var l: OmniLight3D = n as OmniLight3D
		if l == null or l.get_parent() == self or l.name == "FillLight":
			continue
		var cx: int = int(floor(l.global_position.x / cell))
		var cy: int = int(floor(l.global_position.z / cell))
		var zch: String = "."
		if cy >= 0 and cy < zgrid.size() and cx >= 0 and cx < String(zgrid[cy]).length():
			zch = String(zgrid[cy])[cx]
		var zone: Dictionary = zones.get(zch, {}) as Dictionary
		var ceil_h: float = float(zone.get("ceilH", defaults.get("ceilH", 3.6)))
		var is_zone_light: bool = absf(l.position.y - (ceil_h - 0.6)) < 0.05 and not l.has_meta("flicker")
		var cfg: Dictionary = L if is_zone_light else P
		if is_zone_light and zones_over.has(zch):
			cfg = deep_merge(L, zones_over[zch] as Dictionary)
		if not l.has_meta("look_base_energy"):
			l.set_meta("look_base_energy", l.light_energy)
			l.set_meta("look_base_range", l.omni_range)
			l.set_meta("look_base_color", l.light_color)
		var be: float = float(l.get_meta("look_base_energy"))
		var br: float = float(l.get_meta("look_base_range"))
		var bc: Color = l.get_meta("look_base_color") as Color
		var col: Color = _c(cfg["color"]) if cfg.has("color") else bc
		var tint: Color = _c(cfg.get("tint", [1, 1, 1]))
		l.light_color = Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
		l.light_energy = be * float(cfg.get("energy_mul", 1.0)) + float(cfg.get("energy_add", 0.0))
		l.omni_range = br * float(cfg.get("range_mul", 1.0)) + float(cfg.get("range_add", 0.0))
		l.omni_attenuation = float(cfg.get("attenuation", 1.0))
		l.light_size = float(cfg.get("size", 0.15))
		l.light_specular = float(cfg.get("specular", 0.6))
		l.light_indirect_energy = float(cfg.get("indirect", 1.0))
		l.light_volumetric_fog_energy = float(cfg.get("fog_energy", 1.0))
		l.shadow_bias = 0.08
		l.shadow_normal_bias = 1.5
		l.shadow_blur = 1.5
		l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		var amp: float = float(cfg.get("flicker", 0.0))
		if l.has_meta("flicker"):
			amp = maxf(amp, float(l.get_meta("flicker")) * float(P.get("flicker_scale", 1.0)))
		if amp > 0.0:
			_flicker.append({"light": l, "base": l.light_energy, "amp": amp, "speed": float(cfg.get("flicker_speed", 1.0)), "phase": float(idx) * 17.3})
		idx += 1
	# emissive practical meshes (decor lamps): scale their glow so torches read as light sources
	var em_mul: float = float(P.get("emission_mul", 1.0))
	if absf(em_mul - 1.0) > 0.001:
		var things: Node = level.find_child("Things", false, false)
		if things != null:
			for mi_n: Node in things.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = mi_n as MeshInstance3D
				var sm: StandardMaterial3D = mi.material_override as StandardMaterial3D
				if sm != null and sm.emission_enabled:
					if not sm.has_meta("look_base_em"):
						sm.set_meta("look_base_em", sm.emission_energy_multiplier)
					sm.emission_energy_multiplier = float(sm.get_meta("look_base_em")) * em_mul


## Swap the builder's placeholder surfaces (flat StandardMaterial3D) for the RatMaterials library, per
## look "materials": {"wall.x": {"lib": "tri_...", "tint": [..], "params": {...}}}. A surface whose material
## already comes from a .tres (real mapping landed in material_map.json) is left alone.
func _remap_materials() -> void:
	var mats: Dictionary = _d("materials")
	if level == null or mats.is_empty():
		return
	var geo: Node = level.find_child("Geometry", false, false)
	if geo == null:
		return
	var lib_dir: String = "res://assets/materials/"
	for n: Node in geo.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with("Mesh_"):
			continue
		var key: String = String(mi.name).trim_prefix("Mesh_")
		var cfg: Dictionary = {}
		for mk: Variant in mats:
			if String(mk).replace(".", "_") == key:
				cfg = mats[mk] as Dictionary
				break
		if cfg.is_empty() or not cfg.has("lib"):
			continue
		var cur: Material = mi.mesh.surface_get_material(0)
		if cur != null and cur.resource_path != "" and not bool(cfg.get("force", false)):
			continue
		var path: String = lib_dir + String(cfg["lib"]) + ".tres"
		if not ResourceLoader.exists(path):
			continue
		var m: Material = (load(path) as Material).duplicate()
		if m is ShaderMaterial:
			var sm: ShaderMaterial = m as ShaderMaterial
			if cfg.has("tint"):
				sm.set_shader_parameter("tint", _c(cfg["tint"]))
			var params: Dictionary = cfg.get("params", {}) as Dictionary
			for pk: Variant in params:
				var pv: Variant = params[pk]
				sm.set_shader_parameter(String(pk), _c(pv) if pv is Array else pv)
		elif m is StandardMaterial3D and cfg.has("tint"):
			(m as StandardMaterial3D).albedo_color = _c(cfg["tint"])
		mi.material_override = m


func _hide_meshes() -> void:
	if level == null:
		return
	# Level shells are single-sided quads: with back-face culling in the shadow pass a sun/moon leaks
	# through every ceiling. Cast shadows double-sided so only real sky openings let it in.
	var geo: Node = level.find_child("Geometry", false, false)
	if geo != null and sun != null:
		for g: Node in geo.get_children():
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	for nm: Variant in look.get("hide_meshes", []) as Array:
		var n: Node = level.find_child(String(nm), true, false)
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visible = false


func _build_probes() -> void:
	for p: ReflectionProbe in _probes:
		if is_instance_valid(p):
			p.queue_free()
	_probes.clear()
	var pc: Dictionary = _d("probes")
	if level == null or not bool(pc.get("enabled", true)):
		return
	var cell: float = float(level.get("cell")) if "cell" in level else 4.0
	var ldata: Dictionary = level.get("data") as Dictionary if "data" in level else {}
	var grid: Array = ldata.get("grid", []) as Array
	var zgrid: Array = ldata.get("zoneGrid", []) as Array
	var zones: Dictionary = ldata.get("zones", {}) as Dictionary
	var sp: int = maxi(2, int(pc.get("spacing", 6)))
	var max_n: int = int(pc.get("max", 48))
	for cy: int in range(sp / 2, grid.size(), sp):
		var row: String = String(grid[cy])
		for cx: int in range(sp / 2, row.length(), sp):
			if not level.has_method("_is_walkable") or not bool(level.call("_is_walkable", cx, cy)):
				continue
			if _probes.size() >= max_n:
				return
			var zch: String = String(zgrid[cy])[cx] if cy < zgrid.size() and cx < String(zgrid[cy]).length() else "."
			var ch: float = float((zones.get(zch, {}) as Dictionary).get("ceilH", 3.6))
			var p: ReflectionProbe = ReflectionProbe.new()
			p.name = "LookProbe_%d_%d" % [cx, cy]
			p.size = Vector3(cell * sp, ch + 0.4, cell * sp)
			p.position = Vector3((cx + 0.5) * cell, ch * 0.5, (cy + 0.5) * cell)
			p.origin_offset = Vector3(0.0, 1.6 - ch * 0.5, 0.0)
			p.box_projection = true
			p.interior = String((zones.get(zch, {}) as Dictionary).get("ceil", "")) != "ceil.sky"
			p.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			p.update_mode = ReflectionProbe.UPDATE_ONCE
			p.intensity = float(pc.get("intensity", 1.0))
			p.blend_distance = 2.0
			p.max_distance = cell * sp * 1.5
			add_child(p)
			_probes.append(p)


# ───────────────────────────── post / quality ─────────────────────────────
func _build_post() -> void:
	if _post_layer == null or not is_instance_valid(_post_layer):
		_post_layer = CanvasLayer.new()
		_post_layer.name = "LookPost"
		_post_layer.layer = -1  # over the 3D view, under the HUD (layer >= 0)
		add_child(_post_layer)
		_post_rect = ColorRect.new()
		_post_rect.name = "Finish"
		_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = load(POST_SHADER) as Shader
		_post_rect.material = sm
		_post_layer.add_child(_post_rect)
	var p: Dictionary = _d("post")
	var mat: ShaderMaterial = _post_rect.material as ShaderMaterial
	mat.set_shader_parameter("grain", float(p.get("grain", 0.03)))
	mat.set_shader_parameter("grain_size", float(p.get("grain_size", 1.4)))
	mat.set_shader_parameter("vignette", float(p.get("vignette", 0.35)))
	mat.set_shader_parameter("vignette_softness", float(p.get("vignette_softness", 0.65)))
	mat.set_shader_parameter("vignette_color", _c(p.get("vignette_color", [0, 0, 0])))
	mat.set_shader_parameter("ca", float(p.get("ca", 0.6)))
	# lens dirt: deliberately not implemented (spec: off).


func _apply_quality() -> void:
	var s: Node = get_node_or_null("/root/Settings")
	if s != null and s.has_method("apply_to_environment"):
		s.call("apply_to_environment", env)
		for l: DirectionalLight3D in [sun, fill]:
			if l != null and s.has_method("apply_to_light"):
				s.call("apply_to_light", l)
	var q: int = quality()
	var tiers: Dictionary = _d("quality")
	var t: Dictionary = tiers.get(["low", "medium", "high", "ultra"][q], {}) as Dictionary
	# Low has no volumetric fog: approximate it with cheap depth fog so the mood survives.
	if not env.volumetric_fog_enabled and bool(t.get("depth_fog_fallback", true)):
		var fog: Dictionary = _d("fog")
		env.fog_enabled = true
		env.fog_light_color = _c(fog.get("albedo", [0.5, 0.5, 0.5])) * float(fog.get("fallback_light", 0.15))
		env.fog_density = float(fog.get("density", 0.02)) * float(fog.get("fallback_density_mul", 0.6))
		env.fog_sky_affect = float(fog.get("fallback_sky_affect", 0.1))
	elif not bool(_d("depth_fog").get("enabled", false)):
		env.fog_enabled = false
	env.ssao_intensity = float(_d("ssao").get("intensity", 2.0)) * float(t.get("ssao_mul", 1.0))
	if not env.sdfgi_enabled:
		# without GI, lift ambient so shadowed areas do not crush to black
		env.ambient_light_energy = float(_d("ambient").get("energy", 1.0)) * float(t.get("no_gi_ambient_mul", 1.6))
	else:
		env.ambient_light_energy = float(_d("ambient").get("energy", 1.0))
	var probes_on: bool = bool(t.get("probes", q >= 2))
	for p: ReflectionProbe in _probes:
		if is_instance_valid(p):
			p.visible = probes_on
	if _post_layer != null and is_instance_valid(_post_layer):
		_post_layer.visible = bool(t.get("post", true))
		var mat: ShaderMaterial = _post_rect.material as ShaderMaterial
		mat.set_shader_parameter("ca", float(_d("post").get("ca", 0.6)) * (1.0 if q >= 2 else 0.0))
	var shadow_lights: int = int(t.get("shadow_lights", 6))
	if level != null and "shadow_lights" in level:
		level.set("shadow_lights", shadow_lights)
	if sun != null:
		sun.shadow_enabled = bool(_d("sun").get("shadow", true))


# ───────────────────────────── preview harness ─────────────────────────────
func _preview(id: String, args: Dictionary) -> void:
	var s: Node = get_node_or_null("/root/Settings")
	if args.has("look-quality") and s != null:
		if "persist" in s:
			s.set("persist", false)
		s.set("quality", int(args["look-quality"]))
	var lvl: Node = null
	if ResourceLoader.exists(LEVEL_SCENE):
		lvl = (load(LEVEL_SCENE) as PackedScene).instantiate()
	if lvl == null or not lvl.has_method("build_level"):
		push_error("LookRig: no level builder available for preview")
		return
	lvl.name = "Level_" + id
	get_parent().add_child.call_deferred(lvl)
	await lvl.ready
	lvl.call("build_level", id)
	if args.get("look-off", "0") == "1":
		print("SHOT_LOOK off (builder lighting only)")
	else:
		apply(lvl, id)
	if get_viewport().get_camera_3d() == null:
		_preview_cam = Camera3D.new()
		_preview_cam.name = "LookPreviewCam"
		_preview_cam.fov = 70.0
		_preview_cam.far = 400.0
		lvl.add_child(_preview_cam)
		var st: Transform3D = lvl.get("player_start") as Transform3D if "player_start" in lvl else Transform3D.IDENTITY
		_preview_cam.global_transform = st.translated(Vector3(0, 1.7, 0))
		_preview_cam.make_current()
	if args.has("look-fill"):
		var fl: OmniLight3D = OmniLight3D.new()
		fl.light_color = Color(1.0, 0.86, 0.62)
		fl.light_energy = float(args["look-fill"])
		fl.omni_range = 9.0
		var c3: Camera3D = get_viewport().get_camera_3d()
		if c3 != null:
			c3.add_child(fl)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var wait: int = int(args.get("look-measure-after", "40"))
	for i: int in wait:
		await get_tree().process_frame
	_measure_frames = int(args.get("look-measure", "30"))


func _report_timing() -> void:
	var g: Array[float] = _gpu_ms.duplicate()
	var c: Array[float] = _cpu_ms.duplicate()
	g.sort()
	c.sort()
	var q: int = quality()
	print("SHOT_LOOK level=%s quality=%d gpu_ms_median=%.2f cpu_ms_median=%.2f samples=%d" % [level_id, q, g[g.size() / 2], c[c.size() / 2], g.size()])


# ───────────────────────────── helpers ─────────────────────────────
func _d(key: String) -> Dictionary:
	return look.get(key, {}) as Dictionary


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(txt)
	if v is Dictionary:
		return v as Dictionary
	push_warning("LookRig: bad JSON in " + path)
	return {}


static func _c(v: Variant) -> Color:
	if v is Array:
		var a: Array = v as Array
		if a.size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	if v is String:
		return Color(String(v))
	return Color.WHITE


static func _v3(v: Variant) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v as Array
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _user_args() -> Dictionary:
	var out: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
