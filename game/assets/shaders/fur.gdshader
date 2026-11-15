// fur.gdshader — shell-texture fur (owner: shaders-materials).
// One material per shell, chained through next_pass (built by FurShells in fur_shells.gd, or the
// prebuilt materials/fur_*.tres). Shell 0 (shell_index = 0) is the opaque skin/undercoat pass; shells
// 1..N extrude along the normal. Extrusion happens in vertex() after GPU skinning, so it works on
// skinned meshes. Strands come from a jittered cell grid in UV space (uv_scale = strands per UV unit).
// Cheap LOD fallback: fur_lod.gdshader (single pass).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform int shell_index = 0;
uniform int shell_count = 16;

group_uniforms shape;
uniform float fur_length = 0.035; // meters at the tip shell
uniform float density = 220.0; // strand cells per UV unit
uniform float thickness : hint_range(0.05, 1.0) = 0.65; // strand radius at the root, in cell units
uniform float length_variation : hint_range(0.0, 1.0) = 0.45;
uniform float clump : hint_range(0.0, 1.0) = 0.35; // pull strand tips towards clump centres
uniform float clump_scale = 28.0; // clumps per UV unit
uniform sampler2D length_mask : hint_default_white; // R = length multiplier (0 = bald)

group_uniforms motion;
uniform vec3 gravity = vec3(0.0, -1.0, 0.0);
uniform float gravity_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed = 1.7;

group_uniforms color;
uniform vec4 root_color : source_color = vec4(0.55, 0.22, 0.05, 1.0);
uniform vec4 tip_color : source_color = vec4(0.98, 0.62, 0.25, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.45, 0.16, 0.03, 1.0);
uniform float stripe_amount : hint_range(0.0, 1.0) = 0.0; // tabby stripes (object space)
uniform float stripe_frequency = 9.0;
uniform vec3 stripe_axis = vec3(0.0, 0.0, 1.0); // stripes repeat along this object axis
uniform float color_variation : hint_range(0.0, 1.0) = 0.25;
uniform sampler2D color_map : source_color, hint_default_white; // multiplies colour (e.g. belly patch)
uniform float self_shadow : hint_range(0.0, 1.0) = 0.7;

group_uniforms lighting;
uniform float roughness : hint_range(0.0, 1.0) = 0.62;
uniform float spec_strength : hint_range(0.0, 1.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.55;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.25;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.1;

varying float v_h;
varying vec3 v_obj_pos;

void vertex() {
	float h = (shell_count > 0) ? float(shell_index) / float(shell_count) : 0.0;
	v_h = h;
	v_obj_pos = VERTEX;
	float lm = texture(length_mask, UV).r;
	if (shell_index > 0) {
		vec3 n = normalize(NORMAL);
		vec3 disp = n * fur_length * h * lm;
		// Gravity and wind are world-space directions; convert to object space.
		mat3 inv_m = inverse(mat3(MODEL_MATRIX));
		vec3 g = inv_m * normalize(gravity) * gravity_strength;
		float gust = sin(TIME * wind_speed + dot(VERTEX, vec3(3.1, 1.7, 2.3))) * 0.5 + 0.5;
		gust *= 0.6 + 0.4 * sin(TIME * wind_speed * 2.3 + VERTEX.x * 7.0);
		vec3 w = inv_m * normalize(wind_direction + vec3(1e-4)) * wind_strength * gust;
		// Curvature grows with h^2 so roots stay put.
		disp += (g + w) * fur_length * h * h * lm;
		VERTEX += disp;
	}
}

void fragment() {
	float h = v_h;
	vec2 uv = UV * density;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float rnd = rat_hash21(cell + 0.37);
	vec2 jit = (rat_hash22(cell + 5.1) - 0.5) * 0.5;
	// Clumping: tips lean towards the nearest clump centre.
	vec2 cuv = UV * clump_scale;
	vec2 cc = floor(cuv) + 0.5 + (rat_hash22(floor(cuv)) - 0.5) * 0.6;
	vec2 to_clump = (cc - cuv) * (density / clump_scale);
	vec2 centre = vec2(0.5) + jit + to_clump * clump * h * h;
	float strand_len = 1.0 - length_variation * rnd;
	float hn = h / max(strand_len, 0.05); // height along this strand, 0..1
	float radius = thickness * 0.5 * (1.0 - hn); // taper
	float dist = length(f - centre);

	float alpha = 1.0;
	if (shell_index > 0) {
		alpha = (hn < 1.0 && dist < radius) ? 1.0 : 0.0;
		alpha *= texture(length_mask, UV).r > 0.02 ? 1.0 : 0.0;
	}

	// Colour: root→tip gradient, per-strand variation, tabby stripes in object space.
	vec3 col = mix(root_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, h * 1.2));
	col *= 1.0 + (rnd - 0.5) * color_variation;
	if (stripe_amount > 0.0) {
		vec3 sp = v_obj_pos;
		float warp = rat_fbm3(sp * 3.0, 3) * 1.6;
		float s = sin((dot(sp, normalize(stripe_axis)) * stripe_frequency + warp) * 6.2831853);
		float stripe = smoothstep(0.25, 0.75, s) * stripe_amount;
		col = mix(col, stripe_color.rgb * (0.85 + 0.3 * h), stripe);
	}
	col *= texture(color_map, UV).rgb;
	// Self-shadowing: deeper shells are darker (cheap ambient occlusion through the coat).
	float occl = mix(1.0 - self_shadow, 1.0, h);

	ALBEDO = col * occl;
	ROUGHNESS = roughness;
	SPECULAR = (0.35 + 0.25 * h) * spec_strength;
	AO = occl;
	AO_LIGHT_AFFECT = 0.5;
	RIM = rim_strength * h;
	RIM_TINT = rim_tint;
	BACKLIGHT = tip_color.rgb * backlight_amount * h;
	SSS_STRENGTH = sss_strength;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
