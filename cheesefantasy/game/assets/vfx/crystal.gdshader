// Frosty cave crystal: icy fresnel glow, inner sparkle, translucent.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 1.4;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float spark = step(0.985, fract(sin(dot(floor(UV * 40.0), vec2(12.9898, 78.233)) + floor(TIME * 6.0)) * 43758.5453));
	ALBEDO = mix(tint.rgb * 0.5, vec3(0.95, 1.0, 1.0), fres);
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
	SPECULAR = 1.0;
	EMISSION = tint.rgb * glow * (0.35 + fres * 1.6) + vec3(spark) * 3.0;
	ALPHA = clamp((0.55 + fres * 0.45) * fade, 0.0, 1.0);
}
