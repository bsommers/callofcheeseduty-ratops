shader_type canvas_item;
// Full-screen lens/film finish drawn over the 3D view (owner: look-dev).
// Subtle chromatic aberration (radial), vignette, animated film grain. Lens dirt intentionally absent.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain : hint_range(0.0, 0.3) = 0.035;
uniform float grain_size : hint_range(0.5, 4.0) = 1.4;
uniform float vignette : hint_range(0.0, 1.5) = 0.35;
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.65;
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float ca : hint_range(0.0, 4.0) = 0.6; // pixels at the frame corner
uniform float time_seed = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d) * 2.0; // 0 centre .. 1 corner
	vec3 col;
	if (ca > 0.001) {
		vec2 off = (d / max(length(d), 1e-4)) * r2 * ca * px;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	// vignette (smooth, aspect aware)
	vec2 dv = d * vec2(px.y / px.x, 1.0);
	float v = smoothstep(0.85 - vignette_softness * 0.5, 0.85 + vignette_softness, length(dv) * 1.414);
	col = mix(col, vignette_color, clamp(v * vignette, 0.0, 1.0));
	// film grain: luminance-weighted (stronger in mids, never lifts blacks much)
	float t = fract(time_seed + TIME * 0.37) * 97.0;
	float n = hash12(floor(FRAGCOORD.xy / grain_size) + t * 13.1) - 0.5;
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float w = grain * (0.35 + 0.65 * smoothstep(0.0, 0.5, lum) * (1.0 - smoothstep(0.6, 1.0, lum) * 0.5));
	col += n * w;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
