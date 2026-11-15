// cheese.gdshader — the signature material of RAT OPS (owner: shaders-materials).
// One shader, three looks via parameters (see materials/cheese_*.tres):
//   cheddar: orange, small sparse holes, tyrosine crystal specks
//   swiss:   pale yellow, large eyes
//   blue:    off-white paste with blue-green veins, crumbly
// Holes: 3D Worley spheres in object space (no UVs needed, no tiling seams). A hole exists where the
// mesh surface cuts through a sphere; inside it the normal follows the spherical cavity wall and the
// fragment depth is pushed into the surface (depth-correct), so holes occlude/intersect correctly.
// Rind: waxy, hole-free; mask from vertex color R (rind_source = 1) or whole surface (2).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

group_uniforms paste;
uniform vec4 paste_color : source_color = vec4(0.98, 0.62, 0.16, 1.0);
uniform vec4 paste_color_deep : source_color = vec4(0.90, 0.48, 0.08, 1.0);
uniform float paste_mottle : hint_range(0.0, 1.0) = 0.35;
uniform float paste_roughness : hint_range(0.0, 1.0) = 0.32;
uniform float crystal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_clearcoat : hint_range(0.0, 1.0) = 0.45;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.25;

group_uniforms holes;
uniform float hole_density = 9.0; // cells per meter (object space)
uniform float hole_radius : hint_range(0.0, 0.7) = 0.32; // in cell units
uniform float hole_size_variation : hint_range(0.0, 1.0) = 0.6;
uniform float hole_coverage : hint_range(0.0, 1.0) = 0.55; // fraction of cells with a hole
uniform float hole_depth_scale : hint_range(0.0, 2.0) = 1.0;
uniform float hole_ao : hint_range(0.0, 1.0) = 0.75;
uniform vec4 hole_tint : source_color = vec4(0.85, 0.75, 0.6, 1.0);
uniform bool depth_offset = true;

group_uniforms veins;
uniform float vein_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vein_scale = 14.0;
uniform vec4 vein_color : source_color = vec4(0.18, 0.32, 0.36, 1.0);

group_uniforms rind;
uniform int rind_source : hint_range(0, 2) = 1; // 0 none, 1 vertex color R, 2 whole surface
uniform vec4 rind_color : source_color = vec4(0.78, 0.38, 0.06, 1.0);
uniform float rind_roughness : hint_range(0.0, 1.0) = 0.42;
uniform float rind_wax : hint_range(0.0, 1.0) = 0.6;
uniform float rind_bumps : hint_range(0.0, 1.0) = 0.35;

group_uniforms subsurface;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 sss_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_obj_pos;
varying vec3 v_obj_nrm;

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_nrm = NORMAL;
}

void fragment() {
	vec3 n_obj = normalize(v_obj_nrm);
	// Rind mask.
	float rind = 0.0;
	if (rind_source == 1) {
		rind = smoothstep(0.4, 0.6, COLOR.r);
	} else if (rind_source == 2) {
		rind = 1.0;
	}

	// --- Paste base colour: low-frequency mottling + optional crystals + veins.
	vec3 p = v_obj_pos;
	float mott = rat_fbm3(p * 6.0, 4);
	vec3 paste = mix(paste_color.rgb, paste_color_deep.rgb, smoothstep(0.3, 0.75, mott) * paste_mottle);
	float rough = paste_roughness + (mott - 0.5) * 0.12;

	if (crystal_amount > 0.0) {
		float c = rat_vnoise3(p * 180.0);
		float spec = smoothstep(0.93 - crystal_amount * 0.08, 0.99, c);
		paste = mix(paste, vec3(1.0, 0.93, 0.78), spec * 0.8);
		rough = mix(rough, 0.6, spec);
	}

	float vein = 0.0;
	if (vein_amount > 0.0) {
		vec3 q = p * vein_scale + vec3(rat_fbm3(p * 3.0, 3)) * 2.0;
		float r1 = 1.0 - abs(rat_fbm3(q, 4) * 2.0 - 1.0); // ridged
		float r2 = rat_fbm3(p * vein_scale * 3.0 + 11.0, 3);
		vein = smoothstep(0.82 - vein_amount * 0.25, 0.97, r1) * smoothstep(0.25, 0.6, r2);
		vein = clamp(vein + smoothstep(0.88, 0.97, rat_vnoise3(p * vein_scale * 6.0)) * vein_amount * 0.6, 0.0, 1.0);
		paste = mix(paste, vein_color.rgb * (0.6 + 0.6 * r2), vein);
		rough = mix(rough, 0.75, vein);
	}

	// --- Holes (paste only).
	vec3 n_out_obj = n_obj;
	float hole_ao_term = 1.0;
	float hole_h = 0.0;
	float in_hole = 0.0;
	if (hole_coverage > 0.0 && hole_radius > 0.0) {
		vec3 off;
		float crand;
		float d = rat_worley3_id(p * hole_density, 0.85, off, crand);
		float present = step(1.0 - hole_coverage, fract(crand * 7.13));
		float r = hole_radius * mix(1.0 - hole_size_variation, 1.0, crand) * present * (1.0 - rind);
		if (r > 0.001) {
			// Tangential offset (towards sphere centre) and normal-direction component.
			vec3 t = off - dot(off, n_obj) * n_obj;
			float tl = length(t);
			float aa = fwidth(d) * 1.5 + 1e-4;
			in_hole = 1.0 - smoothstep(r - aa, r + aa, d);
			if (in_hole > 0.0) {
				// Radius of the circle where the surface plane cuts the sphere.
				float hn = dot(off, n_obj);
				float rc = sqrt(max(r * r - hn * hn, 1e-6));
				float u = clamp(tl / rc, 0.0, 0.999);
				// Cavity wall normal: tilts towards the hole centre near the rim.
				vec3 tilt = (tl > 1e-5) ? t / tl : vec3(0.0);
				vec3 wall = normalize(n_obj * sqrt(1.0 - u * u) + tilt * u);
				n_out_obj = normalize(mix(n_obj, wall, in_hole));
				hole_h = sqrt(max(rc * rc - tl * tl, 0.0)) * hole_depth_scale / hole_density;
				float depth01 = clamp(1.0 - u * u, 0.0, 1.0);
				hole_ao_term = mix(1.0, 1.0 - hole_ao * (0.35 + 0.65 * depth01), in_hole);
				paste = mix(paste, paste * hole_tint.rgb * mix(1.0, 0.55, depth01), in_hole);
				rough = mix(rough, rough * 0.7, in_hole);
			}
			// Slight raised lip just outside the hole.
			float lip = smoothstep(r + aa * 4.0 + 0.06, r + aa, d) * (1.0 - in_hole);
			paste *= 1.0 + lip * 0.06;
		}
	}

	// --- Rind.
	vec3 rind_col = rind_color.rgb;
	float rb = rat_fbm3(p * 40.0, 3);
	rind_col *= 0.85 + 0.3 * rb;
	vec3 rind_n = n_obj;
	if (rind_bumps > 0.0) {
		float e = 0.004;
		vec3 g = vec3(rat_fbm3((p + vec3(e, 0, 0)) * 40.0, 3), rat_fbm3((p + vec3(0, e, 0)) * 40.0, 3),
				rat_fbm3((p + vec3(0, 0, e)) * 40.0, 3)) - rb;
		g -= dot(g, n_obj) * n_obj;
		rind_n = normalize(n_obj - g * rind_bumps * 6.0);
	}
	vec3 n_final_obj = normalize(mix(n_out_obj, rind_n, rind));

	ALBEDO = mix(paste, rind_col, rind);
	ROUGHNESS = clamp(mix(rough, rind_roughness + (rb - 0.5) * 0.15, rind), 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	AO = hole_ao_term;
	AO_LIGHT_AFFECT = 0.6;
	CLEARCOAT = mix(gloss_clearcoat * (1.0 - vein), rind_wax, rind);
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	SSS_STRENGTH = sss_strength * (1.0 - rind * 0.6);
	BACKLIGHT = sss_color.rgb * backlight_amount * (1.0 - rind * 0.7);

	vec3 n_world = normalize((MODEL_MATRIX * vec4(n_final_obj, 0.0)).xyz);
	NORMAL = rat_world_to_view_n(VIEW_MATRIX, n_world);

	{
		// Push the fragment into the surface by the cavity depth (world units → view space).
		float scale = length(MODEL_MATRIX[0].xyz);
		vec3 n_view_geom = normalize((VIEW_MATRIX * vec4(normalize((MODEL_MATRIX * vec4(n_obj, 0.0)).xyz), 0.0)).xyz);
		vec3 pos_v = VERTEX - n_view_geom * hole_h * scale * in_hole * (depth_offset ? 1.0 : 0.0);
		vec4 clip = PROJECTION_MATRIX * vec4(pos_v, 1.0);
		DEPTH = clip.z / clip.w;
	}
}
