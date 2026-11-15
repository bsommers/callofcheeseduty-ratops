// Nine Lives Spirit overlay: glowing fresnel rim + drifting shimmer bands; used as material_overlay on summon meshes.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float intensity = 1.6;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bands = 0.5 + 0.5 * sin(wp.y * 9.0 - TIME * 4.0);
	ALBEDO = glow_color.rgb * intensity * (fres * 1.4 + bands * 0.25 + 0.12);
	ALPHA = fade;
}
