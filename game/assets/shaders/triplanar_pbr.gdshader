// triplanar_pbr.gdshader — world-space triplanar PBR for level walls/floors/ceilings (owner: shaders-materials).
// Texture sets come from game/assets/textures/<id>/{albedo,normal,roughness,ao,metallic}.jpg (assets-fetch).
// No UVs needed, no seams across modular wall pieces. use_textures = false gives a procedural placeholder.
// Optional wetness/puddles (sewers) via the shared wet helpers. Per-material tint + macro variation
// break repetition on long corridors.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"
#include "res://assets/shaders/wet.gdshaderinc"

group_uniforms textures;
uniform bool use_textures = true;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_texture : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float texture_scale = 0.5; // texture repeats per meter
uniform float blend_sharpness = 6.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms surface;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.2; // large-scale colour breakup
uniform float grime_amount : hint_range(0.0, 1.0) = 0.15; // darkening near the floor
uniform vec4 placeholder_color : source_color = vec4(0.55, 0.52, 0.48, 1.0);

group_uniforms wetness;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_level = 0.05; // world Y below which puddles may form
uniform float puddle_scale = 0.6;
uniform float rain_ripples : hint_range(0.0, 1.0) = 0.0;
uniform vec4 water_tint : source_color = vec4(0.35, 0.33, 0.28, 1.0);

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 p = v_wpos * texture_scale;
	vec3 w = rat_tri_weights(n, blend_sharpness);
	vec3 alb;
	float rough;
	float metal;
	float ao;
	vec3 nw;
	if (use_textures) {
		alb = rat_tri_sample(albedo_texture, p, w).rgb;
		rough = rat_tri_sample(roughness_texture, p, w).r;
		metal = rat_tri_sample(metallic_texture, p, w).r;
		ao = rat_tri_sample(ao_texture, p, w).r;
		nw = rat_tri_normal(normal_texture, p, n, w, normal_strength);
	} else {
		// Placeholder: blocky stone/plaster from 3D noise.
		float c = rat_fbm3(v_wpos * 3.0, 5);
		vec2 cells = rat_worley2(v_wpos.xz * 2.0 + v_wpos.y * 1.3);
		float mortar = smoothstep(0.04, 0.12, cells.y - cells.x);
		alb = placeholder_color.rgb * (0.7 + 0.5 * c) * mix(0.6, 1.0, mortar);
		rough = 0.8;
		metal = 0.0;
		ao = mix(0.6, 1.0, mortar);
		float e = 0.01;
		vec3 g = vec3(rat_fbm3((v_wpos + vec3(e, 0, 0)) * 3.0, 3), rat_fbm3((v_wpos + vec3(0, e, 0)) * 3.0, 3),
				rat_fbm3((v_wpos + vec3(0, 0, e)) * 3.0, 3)) - rat_fbm3(v_wpos * 3.0, 3);
		g -= dot(g, n) * n;
		nw = normalize(n - g * normal_strength * 8.0);
	}
	float macro = rat_fbm3(v_wpos * 0.15, 3);
	alb *= tint.rgb * (1.0 + (macro - 0.5) * macro_variation * 2.0);
	// Grime gathers at the base of walls (first 0.6 m above the floor plane of each storey).
	float floor_h = fract(v_wpos.y / 3.6) * 3.6;
	float grime = (1.0 - smoothstep(0.0, 0.6, floor_h)) * grime_amount * (1.0 - smoothstep(0.6, 0.9, n.y));
	alb *= 1.0 - grime * 0.5;
	rough = clamp(rough * roughness_scale, 0.03, 1.0);
	metal *= metallic_scale;

	if (wetness > 0.0 || puddle_amount > 0.0) {
		vec2 wm = rat_wet_mask(v_wpos, n, wetness, puddle_amount, puddle_level, puddle_scale);
		// Porous darkening, then water film.
		alb = mix(alb, alb * alb * 0.9, wm.x * (1.0 - metal) * 0.8);
		alb = mix(alb, alb * water_tint.rgb, wm.y);
		rough = mix(rough, 0.12, wm.x * 0.8);
		rough = mix(rough, 0.02, wm.y);
		vec3 flat_n = n;
		if (rain_ripples > 0.0) {
			vec2 r = rat_ripples(v_wpos.xz, TIME, 3.0) * rain_ripples;
			flat_n = normalize(n + vec3(r.x, 0.0, r.y));
		}
		nw = normalize(mix(nw, flat_n, wm.y));
		ao = mix(ao, 1.0, wm.y * 0.5);
	}

	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = mix(1.0, ao, ao_strength);
	AO_LIGHT_AFFECT = 0.4;
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, nw);
}
