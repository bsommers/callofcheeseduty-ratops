// cloth.gdshader — woven fabric for uniforms, flags, sacks (owner: shaders-materials).
// Procedural weave normal (plain or twill) in UV space + optional normal/albedo/roughness textures,
// sheen via rim lighting, fibre fuzz, wear/dirt.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 cloth_color : source_color = vec4(0.32, 0.34, 0.26, 1.0); // field-grey/olive default
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D normal_texture : hint_normal;
uniform bool use_normal_texture = false;
uniform sampler2D roughness_texture : hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float weave_scale = 160.0; // threads per UV unit
uniform int weave_pattern : hint_range(0, 1) = 1; // 0 plain, 1 twill
uniform float weave_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sheen : hint_range(0.0, 1.0) = 0.45;
uniform float sheen_tint : hint_range(0.0, 1.0) = 0.5;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.2;
uniform vec4 dirt_color : source_color = vec4(0.22, 0.18, 0.13, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.12;

// Weave height in [0,1] and the active thread direction (0 = warp, 1 = weft).
float weave_height(vec2 uv, out float which) {
	vec2 c = floor(uv);
	vec2 f = fract(uv);
	float sel;
	if (weave_pattern == 0) {
		sel = mod(c.x + c.y, 2.0);
	} else {
		sel = step(1.5, mod(c.x + c.y, 4.0)); // 2/2 twill: diagonal ribs
	}
	which = sel;
	float across = (sel < 0.5) ? f.x : f.y;
	float along = (sel < 0.5) ? f.y : f.x;
	float thread = sin(across * 3.14159); // round thread cross-section
	float bulge = sin(along * 3.14159); // thread rises over / dives under
	return thread * (0.55 + 0.45 * bulge);
}

void fragment() {
	vec2 uv = UV * weave_scale;
	float which;
	float h = weave_height(uv, which);
	float e = 0.08;
	float w2;
	float hx = weave_height(uv + vec2(e, 0.0), w2);
	float hy = weave_height(uv + vec2(0.0, e), w2);
	vec3 nm = normalize(vec3((h - hx) * weave_strength * 4.0, (h - hy) * weave_strength * 4.0, 1.0));
	if (use_normal_texture) {
		vec3 tn = texture(normal_texture, UV).xyz * 2.0 - 1.0;
		nm = normalize(vec3(tn.xy + nm.xy, tn.z));
	}
	NORMAL_MAP = nm * 0.5 + 0.5;

	float big = rat_vnoise2(UV * 6.0);
	float fuzz = rat_vnoise2(UV * weave_scale * 3.0);
	vec3 col = cloth_color.rgb * texture(albedo_texture, UV).rgb;
	col *= 1.0 + (big - 0.5) * color_variation + (which - 0.5) * 0.06;
	col *= 0.82 + 0.18 * h; // crevices between threads are darker
	float dirt = smoothstep(0.55, 0.9, rat_vnoise2(UV * 3.0 + 7.0) * 0.7 + fuzz * 0.3) * dirt_amount;
	col = mix(col, dirt_color.rgb, dirt);

	ALBEDO = col;
	ROUGHNESS = clamp(roughness * texture(roughness_texture, UV).r + (fuzz - 0.5) * 0.1, 0.3, 1.0);
	SPECULAR = 0.35;
	AO = 0.75 + 0.25 * h;
	RIM = sheen;
	RIM_TINT = sheen_tint;
}
