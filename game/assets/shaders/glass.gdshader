// glass.gdshader — windows, bottles, lamp covers, scopes (owner: shaders-materials).
// Transparent with Fresnel-driven reflection/opacity, screen-space refraction of what's behind,
// tint, optional dirt/grime and cracks. Depth pre-pass off (transparent).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.80, 0.90, 0.88, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.08;
uniform float roughness : hint_range(0.0, 1.0) = 0.03;
uniform float refraction : hint_range(0.0, 0.2) = 0.03;
uniform float ior = 1.5;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.15;
uniform vec4 dirt_color : source_color = vec4(0.45, 0.42, 0.36, 1.0);
uniform float crack_amount : hint_range(0.0, 1.0) = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0; // blurs the refracted image

varying vec3 v_obj_pos;

void vertex() {
	v_obj_pos = VERTEX;
}

void fragment() {
	vec3 nv = normalize(NORMAL);
	float ndv = clamp(dot(nv, VIEW), 0.0, 1.0);
	float f0 = pow((ior - 1.0) / (ior + 1.0), 2.0);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);

	float dirt = smoothstep(0.45, 0.85, rat_fbm3(v_obj_pos * 4.0, 4)) * dirt_amount;
	float crack = 0.0;
	if (crack_amount > 0.0) {
		vec2 cw = rat_worley2(v_obj_pos.xy * 6.0 + v_obj_pos.z * 3.0);
		crack = (1.0 - smoothstep(0.0, 0.03, cw.y - cw.x)) * crack_amount;
	}

	vec2 offs = nv.xy * refraction * (1.0 + crack * 4.0);
	float lod = frost * 6.0;
	vec3 behind = textureLod(screen_tex, SCREEN_UV - offs, lod).rgb;
	vec3 trans = behind * glass_tint.rgb;

	// Emit the refracted background (opaque blend), lighting adds reflections + specular on top.
	float opacity = clamp(base_opacity + dirt * 0.6 + crack * 0.5, 0.0, 1.0);
	ALBEDO = mix(vec3(0.0), dirt_color.rgb, dirt + crack * 0.3);
	EMISSION = trans * (1.0 - fres) * (1.0 - opacity);
	ROUGHNESS = mix(roughness, 0.7, max(dirt, frost * 0.6));
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = 1.0;
}
