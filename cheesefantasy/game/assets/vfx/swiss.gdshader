// A slice of Swiss cheese: round disc with holes punched through (alpha-scissor), slight emissive rim.
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cheese : source_color = vec4(1.0, 0.88, 0.45, 1.0);
uniform float seed = 0.0;
uniform float glow = 0.6;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > 0.5) discard;
	for (int i = 0; i < 7; i++) {
		float fi = float(i) + seed * 13.0;
		vec2 c = vec2(hash(fi * 1.7), hash(fi * 3.1)) * 0.7 - 0.35;
		float hr = 0.04 + hash(fi * 5.3) * 0.07;
		if (length(p - c) < hr) discard;
	}
	if (hash(seed + floor(FRAGCOORD.x) * 0.01 + floor(FRAGCOORD.y) * 0.013) > fade) discard;
	ALBEDO = cheese.rgb;
	ROUGHNESS = 0.55;
	EMISSION = cheese.rgb * glow * smoothstep(0.35, 0.5, r) + cheese.rgb * glow * 0.3;
}
