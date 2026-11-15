// Battle arena ground: noisy grass field with a trampled dirt ring in the middle; `rot` blends in blue-green mold.
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 grass_a : source_color = vec4(0.32, 0.55, 0.2, 1.0);
uniform vec4 grass_b : source_color = vec4(0.5, 0.68, 0.25, 1.0);
uniform vec4 dirt : source_color = vec4(0.55, 0.42, 0.28, 1.0);
uniform vec4 rot_col : source_color = vec4(0.2, 0.42, 0.42, 1.0);
uniform float dirt_radius = 7.5;
uniform float rot = 0.0;
uniform float stone = 0.0;   // 1 = cave floor
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.35);
	float fine = noise(p * 6.0);
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.7, n)) * (0.85 + fine * 0.3);
	float r = length(p * vec2(0.8, 1.15)) + (fbm(p * 0.8) - 0.5) * 2.0;
	float dm = smoothstep(dirt_radius, dirt_radius - 2.0, r);
	vec3 d = dirt.rgb * (0.8 + fbm(p * 2.5) * 0.4);
	vec3 c = mix(g, d, dm * 0.85);
	float rm = rot * smoothstep(0.35, 0.65, fbm(p * 0.5 + 3.0));
	c = mix(c, rot_col.rgb * (0.7 + fine * 0.5), rm);
	vec3 st = vec3(0.32, 0.29, 0.26) * (0.6 + fbm(p * 1.3) * 0.7);
	c = mix(c, st, stone);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.75, stone);
	EMISSION = rot_col.rgb * rm * 0.15;
}
