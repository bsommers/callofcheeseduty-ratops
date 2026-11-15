// Melting-cheese flame tongue: billboard-Y quad, scrolling noise, white-hot core -> cheese yellow -> orange -> red tip.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float speed = 1.6;
uniform float energy = 2.6;
uniform float seed = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 core : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform vec4 tip : source_color = vec4(0.95, 0.3, 0.05, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
void vertex() {
	// cylindrical billboard (keep Y up)
	vec3 cam = normalize((INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz) * vec3(1, 0, 1));
	vec3 right = normalize(cross(vec3(0, 1, 0), cam));
	float sx = length(MODEL_MATRIX[0].xyz); float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = MODEL_MATRIX[3].xyz + right * VERTEX.x * sx + vec3(0, 1, 0) * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}
void fragment() {
	vec2 uv = UV; uv.y = 1.0 - uv.y;            // 0 = base, 1 = tip
	float t = TIME * speed + seed * 17.0;
	float n = fbm(vec2(uv.x * 3.0 + seed, uv.y * 2.5 - t));
	float w = (1.0 - uv.y) * 0.55 + 0.08;       // flame narrows to the tip
	float dx = abs(uv.x - 0.5 + (n - 0.5) * 0.35 * uv.y);
	float body = smoothstep(w, w * 0.35, dx) * smoothstep(1.0, 0.55, uv.y + n * 0.35);
	body *= smoothstep(0.0, 0.08, uv.y);
	float heat = clamp(body * (1.3 - uv.y), 0.0, 1.0);
	vec3 c = mix(tip.rgb, mid.rgb, smoothstep(0.1, 0.5, heat));
	c = mix(c, core.rgb, smoothstep(0.6, 0.95, heat));
	ALBEDO = c * energy;
	ALPHA = clamp(body * fade, 0.0, 1.0);
}
