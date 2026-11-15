// Expanding ground ring / shockwave / magic circle on a flat quad. `radius` 0..0.5, `width`, tint.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float radius = 0.4;
uniform float width = 0.05;
uniform float energy = 2.5;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform bool runes = false;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float ring = smoothstep(width, 0.0, abs(r - radius));
	if (runes) {
		float a = atan(p.y, p.x);
		ring += smoothstep(width * 0.6, 0.0, abs(r - radius * 0.78)) * 0.7;
		ring += step(0.6, sin(a * 12.0 + TIME * 2.0)) * smoothstep(0.03, 0.0, abs(r - radius * 0.89)) * 0.9;
		ring += smoothstep(radius * 0.8, 0.0, r) * 0.12;
	}
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(ring * fade, 0.0, 1.0);
}
