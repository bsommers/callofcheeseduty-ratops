// wet_stone.gdshader — sewer/rainy stone with puddles (owner: shaders-materials).
// Procedural flagstones (world-space Worley cells, no seams) or an optional triplanar texture set,
// darkened where damp, mirror-flat puddles on up-facing surfaces below puddle_level (world Y) broken
// up by noise, slime/grease film, optional rain ripples.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"
#include "res://assets/shaders/wet.gdshaderinc"

group_uniforms stone;
uniform bool use_textures = false;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_scale = 0.5;
uniform vec4 stone_color : source_color = vec4(0.42, 0.40, 0.37, 1.0);
uniform vec4 stone_color_2 : source_color = vec4(0.30, 0.29, 0.27, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.18, 0.17, 0.15, 1.0);
uniform float stone_scale = 2.2; // stones per meter
uniform float mortar_width : hint_range(0.0, 0.3) = 0.08;
uniform float bump_strength : hint_range(0.0, 2.0) = 1.0;
uniform float stone_roughness : hint_range(0.0, 1.0) = 0.85;

group_uniforms wetness;
uniform float wetness : hint_range(0.0, 1.0) = 0.7;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.6;
uniform float puddle_level = 0.05;
uniform float puddle_scale = 0.7;
uniform float rain_ripples : hint_range(0.0, 1.0) = 0.0;
uniform vec4 water_tint : source_color = vec4(0.33, 0.34, 0.28, 1.0);
uniform float slime_amount : hint_range(0.0, 1.0) = 0.25;
uniform vec4 slime_color : source_color = vec4(0.16, 0.20, 0.08, 1.0);

varying vec3 v_wpos;
varying vec3 v_wnrm;

// Stone height field: cell interior raised, mortar lines sunk.
float stone_height(vec3 wp, vec3 w, out float cell_id) {
	vec2 uv = (wp.xz * w.y + wp.zy * w.x + wp.xy * w.z) * stone_scale;
	vec2 f = rat_worley2(uv);
	float edge = f.y - f.x;
	cell_id = rat_vnoise2(uv * 0.9 + 3.7); // smooth per-region tone (no per-cell id from F1/F2)
	float h = smoothstep(0.0, mortar_width * 2.0, edge);
	h *= 0.85 + 0.15 * rat_vnoise2(uv * 6.0);
	return h;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 w = rat_tri_weights(n, 8.0);
	vec3 alb;
	float rough;
	vec3 nw;
	float mortar = 0.0;
	if (use_textures) {
		vec3 p = v_wpos * texture_scale;
		alb = rat_tri_sample(albedo_texture, p, w).rgb;
		rough = rat_tri_sample(roughness_texture, p, w).r;
		nw = rat_tri_normal(normal_texture, p, n, w, bump_strength);
	} else {
		float cid;
		float h = stone_height(v_wpos, w, cid);
		mortar = 1.0 - h;
		float grain = rat_fbm3(v_wpos * 9.0, 4);
		alb = mix(stone_color.rgb, stone_color_2.rgb, cid) * (0.8 + 0.4 * grain);
		alb = mix(mortar_color.rgb, alb, h);
		rough = mix(0.95, stone_roughness, h) + (grain - 0.5) * 0.1;
		float e = 0.004;
		float c2;
		float hx = stone_height(v_wpos + vec3(e, 0.0, 0.0), w, c2);
		float hy = stone_height(v_wpos + vec3(0.0, e, 0.0), w, c2);
		float hz = stone_height(v_wpos + vec3(0.0, 0.0, e), w, c2);
		vec3 g = vec3(hx - h, hy - h, hz - h) / e * 0.004;
		g += (vec3(rat_vnoise3(v_wpos * 30.0 + 1.0), rat_vnoise3(v_wpos * 30.0 + 2.0), rat_vnoise3(v_wpos * 30.0 + 3.0)) - 0.5) * 0.15;
		g -= dot(g, n) * n;
		nw = normalize(n - g * bump_strength * 2.5);
	}

	vec2 wm = rat_wet_mask(v_wpos, n, wetness, puddle_amount, puddle_level, puddle_scale);
	// Water fills mortar first.
	float puddle = clamp(wm.y + mortar * wetness * 0.6 * step(0.6, n.y), 0.0, 1.0);
	float slime = smoothstep(0.55, 0.8, rat_fbm3(v_wpos * 1.7 + 9.0, 4)) * slime_amount
			* (1.0 - smoothstep(0.0, 0.8, v_wpos.y - puddle_level));
	alb = mix(alb, slime_color.rgb, slime);
	alb = mix(alb, alb * alb * 0.85, wm.x * 0.85);
	alb = mix(alb, alb * water_tint.rgb, puddle);
	rough = mix(rough, 0.15, wm.x * 0.85);
	rough = mix(rough, 0.25, slime * 0.5);
	rough = mix(rough, 0.02, puddle);
	vec3 flat_n = n;
	if (rain_ripples > 0.0) {
		vec2 r = rat_ripples(v_wpos.xz, TIME, 3.0) * rain_ripples;
		flat_n = normalize(n + vec3(r.x, 0.0, r.y));
	}
	nw = normalize(mix(nw, flat_n, puddle));

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.6, wm.x);
	AO = mix(0.55, 1.0, 1.0 - mortar * (1.0 - puddle));
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, nw);
}
