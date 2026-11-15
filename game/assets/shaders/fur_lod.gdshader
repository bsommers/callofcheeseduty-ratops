// fur_lod.gdshader — single-pass fur fallback for distant characters / Low preset (owner: shaders-materials).
// Same colour parameters as fur.gdshader so a material can swap between them; fakes the coat with
// strand-noise albedo, a combed normal, soft rim light and backlight.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform float density = 220.0;
uniform vec4 root_color : source_color = vec4(0.55, 0.22, 0.05, 1.0);
uniform vec4 tip_color : source_color = vec4(0.98, 0.62, 0.25, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.45, 0.16, 0.03, 1.0);
uniform float stripe_amount : hint_range(0.0, 1.0) = 0.0;
uniform float stripe_frequency = 9.0;
uniform vec3 stripe_axis = vec3(0.0, 0.0, 1.0);
uniform float color_variation : hint_range(0.0, 1.0) = 0.25;
uniform sampler2D color_map : source_color, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.6;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.25;
uniform float strand_bump : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_obj_pos;

void vertex() {
	v_obj_pos = VERTEX;
}

void fragment() {
	vec2 uv = UV * density;
	float n1 = rat_vnoise2(uv * vec2(1.0, 0.25));
	float n2 = rat_vnoise2(uv * vec2(2.0, 0.5) + 13.0);
	float strand = n1 * 0.65 + n2 * 0.35;
	vec3 col = mix(root_color.rgb, tip_color.rgb, smoothstep(0.2, 0.8, strand));
	col *= 1.0 + (rat_hash21(floor(uv)) - 0.5) * color_variation;
	if (stripe_amount > 0.0) {
		vec3 sp = v_obj_pos;
		float warp = rat_fbm3(sp * 3.0, 3) * 1.6;
		float s = sin((dot(sp, normalize(stripe_axis)) * stripe_frequency + warp) * 6.2831853);
		col = mix(col, stripe_color.rgb, smoothstep(0.25, 0.75, s) * stripe_amount);
	}
	col *= texture(color_map, UV).rgb;
	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
	AO = mix(0.6, 1.0, strand);
	NORMAL_MAP = normalize(vec3(0.5 + (n1 - 0.5) * strand_bump, 0.5 + (n2 - 0.5) * strand_bump * 0.3, 1.0));
	RIM = rim_strength;
	RIM_TINT = rim_tint;
	BACKLIGHT = tip_color.rgb * backlight_amount;
	SSS_STRENGTH = 0.1;
}
