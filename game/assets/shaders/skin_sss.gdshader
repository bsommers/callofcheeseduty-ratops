// skin_sss.gdshader — thin, translucent skin for ears, paw pads, noses, rat tails (owner: shaders-materials).
// Strong subsurface + backlight (ears glow red when lit from behind), pore/bump noise, optional
// albedo texture and a moistness term (shinier nose leather).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 skin_color : source_color = vec4(0.86, 0.52, 0.52, 1.0);
uniform vec4 blotch_color : source_color = vec4(0.62, 0.30, 0.32, 1.0);
uniform float blotch_amount : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float moistness : hint_range(0.0, 1.0) = 0.0; // 1 = wet nose
uniform float pore_scale = 90.0; // per meter, object space
uniform float pore_strength : hint_range(0.0, 1.0) = 0.35;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec4 transmission_color : source_color = vec4(0.95, 0.25, 0.15, 1.0);
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.6;

varying vec3 v_obj_pos;
varying vec3 v_obj_nrm;

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_nrm = NORMAL;
}

void fragment() {
	vec3 p = v_obj_pos;
	float b = rat_fbm3(p * 12.0, 4);
	vec3 col = mix(skin_color.rgb, blotch_color.rgb, smoothstep(0.45, 0.8, b) * blotch_amount);
	col *= texture(albedo_texture, UV).rgb;

	// Pore bump via finite-difference of 3D noise, projected to the tangent plane.
	vec3 n = normalize(v_obj_nrm);
	float e = 0.5 / pore_scale;
	float n0 = rat_vnoise3(p * pore_scale);
	vec3 g = vec3(rat_vnoise3((p + vec3(e, 0, 0)) * pore_scale), rat_vnoise3((p + vec3(0, e, 0)) * pore_scale),
			rat_vnoise3((p + vec3(0, 0, e)) * pore_scale)) - n0;
	g -= dot(g, n) * n;
	vec3 nb = normalize(n - g * pore_strength * 3.0);
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, normalize((MODEL_MATRIX * vec4(nb, 0.0)).xyz));

	ALBEDO = col * mix(1.0, 0.75, moistness);
	ROUGHNESS = mix(roughness, 0.12, moistness) + (n0 - 0.5) * 0.1;
	SPECULAR = 0.45;
	CLEARCOAT = moistness * 0.6;
	CLEARCOAT_ROUGHNESS = 0.1;
	SSS_STRENGTH = sss_strength;
	BACKLIGHT = transmission_color.rgb * backlight_amount;
}
