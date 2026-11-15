// Soft round additive/blended billboard particle. Vertex COLOR drives tint + alpha (ParticleProcessMaterial color ramp).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float softness : hint_range(0.05, 1.0) = 0.6;
uniform float energy = 2.2;
uniform sampler2D tex : source_color, hint_default_white;
uniform bool use_tex = false;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 1.0 - softness, d);
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	ALBEDO = COLOR.rgb * t.rgb * energy;
	ALPHA = a * COLOR.a * t.a;
}
