// wet_metal.gdshader — pipes, grates, bunker doors with rust, grease and water (owner: shaders-materials).
// Procedural brushed steel + rust patches (world-space noise) or an optional triplanar texture set;
// wet streaks run down (world -Y), puddles collect on up-facing surfaces below puddle_level.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"
#include "res://assets/shaders/wet.gdshaderinc"

group_uniforms metal;
uniform bool use_textures = false;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float texture_scale = 0.5;
uniform vec4 metal_color : source_color = vec4(0.56, 0.57, 0.58, 1.0);
uniform float metal_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float brush_strength : hint_range(0.0, 1.0) = 0.4;
uniform vec4 rust_color : source_color = vec4(0.36, 0.15, 0.06, 1.0);
uniform float rust_amount : hint_range(0.0, 1.0) = 0.35;
uniform float rust_scale = 2.5;
uniform vec4 paint_color : source_color = vec4(0.20, 0.24, 0.20, 1.0);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0; // chipped paint over the steel

group_uniforms wetness;
uniform float wetness : hint_range(0.0, 1.0) = 0.6;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.3;
uniform float puddle_level = 0.05;
uniform float puddle_scale = 0.8;
uniform float grease_amount : hint_range(0.0, 1.0) = 0.2;
uniform vec4 grease_color : source_color = vec4(0.05, 0.045, 0.035, 1.0);

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 w = rat_tri_weights(n, 6.0);
	vec3 alb;
	float rough;
	float metal;
	vec3 nw = n;
	if (use_textures) {
		vec3 p = v_wpos * texture_scale;
		alb = rat_tri_sample(albedo_texture, p, w).rgb;
		rough = rat_tri_sample(roughness_texture, p, w).r;
		metal = rat_tri_sample(metallic_texture, p, w).r;
		nw = rat_tri_normal(normal_texture, p, n, w, 1.0);
	} else {
		// Brushed streaks along world Y (vertical) and X.
		vec3 bp = v_wpos * vec3(60.0, 1.5, 60.0);
		float brush = rat_vnoise3(bp) * 0.6 + rat_vnoise3(bp * 2.7) * 0.4;
		alb = metal_color.rgb * (0.9 + 0.2 * brush * brush_strength);
		rough = metal_roughness + (brush - 0.5) * 0.2 * brush_strength;
		metal = 1.0;
		// Chipped paint.
		if (paint_amount > 0.0) {
			float chip = rat_fbm3(v_wpos * 6.0, 4);
			float painted = smoothstep(0.62 - paint_amount * 0.5, 0.66 - paint_amount * 0.5, 1.0 - chip);
			alb = mix(alb, paint_color.rgb, painted);
			rough = mix(rough, 0.6, painted);
			metal = mix(metal, 0.0, painted);
		}
	}
	// Rust: blotches, worse low down and along drip lines.
	float rn = rat_fbm3(v_wpos * rust_scale, 5);
	float drip = rat_vnoise3(vec3(v_wpos.x * 14.0, v_wpos.y * 0.7, v_wpos.z * 14.0));
	float rust = smoothstep(0.55, 0.75, rn + drip * 0.25 + (0.5 - clamp(v_wpos.y * 0.15, 0.0, 0.5)) * 0.3)
			* rust_amount * 1.6;
	rust = clamp(rust, 0.0, 1.0);
	float rgrain = rat_vnoise3(v_wpos * 80.0);
	alb = mix(alb, rust_color.rgb * (0.6 + 0.8 * rgrain), rust);
	rough = mix(rough, 0.9, rust);
	metal = mix(metal, 0.0, rust);
	{
		float e = 0.003;
		vec3 g = vec3(rat_vnoise3((v_wpos + vec3(e, 0, 0)) * 80.0), rat_vnoise3((v_wpos + vec3(0, e, 0)) * 80.0),
				rat_vnoise3((v_wpos + vec3(0, 0, e)) * 80.0)) - rgrain;
		g -= dot(g, n) * n;
		nw = normalize(nw - g * rust * 0.8);
	}

	// Grease smears.
	float grease = smoothstep(0.6, 0.8, rat_fbm3(v_wpos * 3.3 + 17.0, 4)) * grease_amount;
	alb = mix(alb, grease_color.rgb, grease * 0.8);
	rough = mix(rough, 0.18, grease);

	vec2 wm = rat_wet_mask(v_wpos, n, wetness, puddle_amount, puddle_level, puddle_scale);
	alb = mix(alb, alb * 0.75, wm.x * (1.0 - metal) * 0.8);
	rough = mix(rough, 0.08, wm.x * 0.75);
	rough = mix(rough, 0.02, wm.y);
	nw = normalize(mix(nw, n, wm.y));

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = clamp(metal, 0.0, 1.0);
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, nw);
}
