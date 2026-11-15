// gold_foil.gdshader — crinkled metallic foil for treasure (wrapped cheese, chocolate coins, medals)
// and polished gold/brass (owner: shaders-materials). Crinkles: faceted 3D Worley cells, each facet
// gets its own flat normal tilt, so highlights break into sharp sparkles. crinkle = 0 → smooth gold.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 foil_color : source_color = vec4(1.0, 0.78, 0.34, 1.0);
uniform vec4 foil_color_2 : source_color = vec4(0.92, 0.62, 0.22, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float crinkle : hint_range(0.0, 1.0) = 0.6;
uniform float crinkle_scale = 30.0; // facets per meter (object space)
uniform float crease_darkening : hint_range(0.0, 1.0) = 0.4;
uniform float tarnish : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tarnish_color : source_color = vec4(0.30, 0.22, 0.10, 1.0);
uniform float sparkle_emission : hint_range(0.0, 2.0) = 0.15; // keeps treasure readable in the dark

varying vec3 v_obj_pos;
varying vec3 v_obj_nrm;

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_nrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(v_obj_nrm);
	vec3 p = v_obj_pos * crinkle_scale;
	vec3 wf = rat_worley3_f12(p);
	float crand = wf.z;
	// Facet normal: random tilt per cell, flat within the cell.
	vec3 tilt = vec3(crand, fract(crand * 7.7), fract(crand * 31.3)) - 0.5;
	tilt -= dot(tilt, n) * n;
	vec3 nf = normalize(n + tilt * crinkle * 1.4);
	// Creases where neighbouring facets meet (F2 - F1 small).
	float crease = (1.0 - smoothstep(0.0, 0.08, wf.y - wf.x)) * crinkle;

	vec3 col = mix(foil_color.rgb, foil_color_2.rgb, fract(crand * 3.1));
	col *= 1.0 - crease * crease_darkening;
	float tn = rat_fbm3(v_obj_pos * 8.0, 4);
	float tm = smoothstep(0.5, 0.8, tn) * tarnish;
	col = mix(col, tarnish_color.rgb, tm);

	ALBEDO = col;
	METALLIC = 1.0 - tm * 0.6;
	ROUGHNESS = clamp(roughness + crease * 0.15 + tm * 0.4, 0.03, 1.0);
	SPECULAR = 0.5;
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, normalize((MODEL_MATRIX * vec4(nf, 0.0)).xyz));
	// Cheap rim sparkle so gold still reads in dark corridors.
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = col * sparkle_emission * pow(1.0 - ndv, 3.0);
}
