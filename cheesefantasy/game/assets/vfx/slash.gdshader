// Crescent slash / claw arc on a quad: bright leading edge, fades along the sweep. `progress` 0..1 animates the sweep.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float energy = 3.0;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.0);
	float ang = atan(p.x, p.y) / 3.14159 + 0.5;   // 0..1 across the arc
	float r = length(p);
	float band = smoothstep(0.42, 0.47, r) * smoothstep(0.5, 0.47, r + (1.0 - abs(ang * 2.0 - 1.0)) * -0.03);
	float sweep = smoothstep(progress, progress - 0.5, ang) * step(ang, progress);
	vec3 c = mix(color.rgb, vec3(1.0), smoothstep(progress - 0.12, progress, ang));
	ALBEDO = c * energy;
	ALPHA = band * sweep;
}
