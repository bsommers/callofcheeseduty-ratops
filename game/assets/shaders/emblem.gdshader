// emblem.gdshader — the Rattenreich emblem: black cheese wedge in a white disc on a red field
// (owner: shaders-materials). Fully procedural in UV space (0..1 square = one emblem), antialiased
// with fwidth so it stays crisp on flags, armbands, banners, posters and painted metal at any size.
// fabric = 1 adds a woven normal + sheen (banners); fabric = 0 gives a painted/printed surface.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 field_color : source_color = vec4(0.62, 0.04, 0.04, 1.0);
uniform vec4 disc_color : source_color = vec4(0.95, 0.94, 0.90, 1.0);
uniform vec4 wedge_color : source_color = vec4(0.03, 0.03, 0.03, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0); // e.g. (2,1) for a banner with the emblem centred on a 2:1 cloth
uniform vec2 emblem_center = vec2(0.5, 0.5);
uniform bool box_mesh_uv = false; // Godot BoxMesh packs 6 faces in a 3x2 atlas: one emblem per face
uniform float disc_radius : hint_range(0.05, 0.5) = 0.34;
uniform float wedge_size : hint_range(0.1, 1.0) = 0.62; // relative to the disc
uniform float fabric : hint_range(0.0, 1.0) = 1.0;
uniform float weave_scale = 120.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float wear : hint_range(0.0, 1.0) = 0.15;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0; // backlit banners / neon signs

// Signed distance to a triangle (Inigo Quilez).
float sd_triangle(vec2 p, vec2 a, vec2 b, vec2 c) {
	vec2 e0 = b - a, e1 = c - b, e2 = a - c;
	vec2 v0 = p - a, v1 = p - b, v2 = p - c;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
			vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
			vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

// Cheese wedge seen from the side, slightly in perspective: a tall triangle with a thick rind edge
// and three round holes. Returns signed distance (negative = wedge ink).
float sd_wedge(vec2 q) {
	// q in disc-local units, disc radius = 1, y up.
	float s = wedge_size;
	vec2 a = vec2(-0.78, -0.48) * s;
	vec2 b = vec2(0.82, -0.48) * s;
	vec2 c = vec2(0.70, 0.62) * s;
	float tri = sd_triangle(q, a, b, c);
	// Rounded corners.
	tri -= 0.03 * s;
	// Holes (white): subtract circles.
	float h1 = length(q - vec2(0.30, -0.12) * s) - 0.15 * s;
	float h2 = length(q - vec2(0.52, 0.26) * s) - 0.09 * s;
	float h3 = length(q - vec2(-0.12, -0.30) * s) - 0.08 * s;
	float h4 = length(q - vec2(0.78, -0.48) * s) - 0.12 * s; // bite from the bottom edge
	float holes = min(min(h1, h2), min(h3, h4));
	return max(tri, -holes);
}

void fragment() {
	vec2 base_uv = box_mesh_uv ? fract(UV * vec2(3.0, 2.0)) : UV;
	vec2 uv = base_uv * uv_scale;
	vec2 cen = emblem_center * uv_scale;
	vec2 q = (uv - cen) / disc_radius;
	q.y = -q.y; // UV v grows downward
	// AA width from the continuous UV: fwidth of the fract()'d atlas UV explodes on BoxMesh face seams
	// (the 2x2 pixel quad straddles the wrap), which blurred the disc into a 1-px light edge line (look-dev fix).
	vec2 cuv = (box_mesh_uv ? UV * vec2(3.0, 2.0) : UV) * uv_scale / disc_radius;
	float aa = fwidth(cuv.x) + fwidth(cuv.y) + 1e-4;
	float disc_d = length(q) - 1.0;
	float disc = 1.0 - smoothstep(-aa, aa, disc_d);
	float ring = (1.0 - smoothstep(-aa, aa, abs(disc_d + 0.06) - 0.015)); // thin dark keyline
	float wedge = 1.0 - smoothstep(-aa, aa, sd_wedge(q));

	vec3 col = field_color.rgb;
	col = mix(col, disc_color.rgb, disc);
	col = mix(col, wedge_color.rgb, max(wedge * disc, ring * disc * 0.85));

	// Wear: faded, dusty patches.
	float wn = rat_fbm3(vec3(uv * 9.0, 0.0), 4);
	float worn = smoothstep(0.55, 0.85, wn) * wear;
	col = mix(col, col * 0.7 + vec3(0.08, 0.07, 0.06), worn);

	float rough = roughness;
	vec3 nm = vec3(0.5, 0.5, 1.0);
	if (fabric > 0.0) {
		vec2 wv = base_uv * weave_scale * uv_scale;
		vec2 f = fract(wv);
		float sel = mod(floor(wv.x) + floor(wv.y), 2.0);
		float across = sel < 0.5 ? f.x : f.y;
		float th = sin(across * 3.14159);
		vec2 g = sel < 0.5 ? vec2(cos(f.x * 3.14159), 0.0) : vec2(0.0, cos(f.y * 3.14159));
		nm = normalize(vec3(g * 0.5 * fabric, 1.0)) * 0.5 + 0.5;
		col *= mix(1.0, 0.85 + 0.15 * th, fabric);
		RIM = 0.4 * fabric;
		RIM_TINT = 0.5;
	} else {
		rough = mix(0.45, 0.8, worn);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	NORMAL_MAP = nm;
	EMISSION = col * emission_strength;
	BACKLIGHT = col * 0.35 * fabric; // light through thin banner cloth
}
