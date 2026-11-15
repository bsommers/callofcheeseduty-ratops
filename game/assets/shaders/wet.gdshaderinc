// Shared triplanar + wetness helpers (owner: shaders-materials). Requires noise.gdshaderinc first.

// Triplanar blend weights from a world normal.
vec3 rat_tri_weights(vec3 n, float sharpness) {
	vec3 w = pow(abs(n), vec3(sharpness));
	return w / max(w.x + w.y + w.z, 1e-5);
}

// Macro, not a function: Godot rejects one sampler parameter bound to textures with different hints.
#define rat_tri_sample(tex, p, w) (texture(tex, (p).zy) * (w).x + texture(tex, (p).xz) * (w).y + texture(tex, (p).xy) * (w).z)

// Whiteout-blended triplanar normal map (tangent-space GL maps) -> world normal.
vec3 rat_tri_normal(sampler2D ntex, vec3 p, vec3 n, vec3 w, float strength) {
	vec3 tx = texture(ntex, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(ntex, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(ntex, p.xy).xyz * 2.0 - 1.0;
	// Rebuild z: normal maps may be imported RG-compressed (B channel unusable).
	tx.z = sqrt(max(1.0 - dot(tx.xy, tx.xy), 0.0));
	ty.z = sqrt(max(1.0 - dot(ty.xy, ty.xy), 0.0));
	tz.z = sqrt(max(1.0 - dot(tz.xy, tz.xy), 0.0));
	tx.xy *= strength;
	ty.xy *= strength;
	tz.xy *= strength;
	// Swizzle tangent normals into world space per projection (whiteout blend).
	vec3 nx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	vec3 ny = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	vec3 nz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
}

// Wetness mask: puddles collect on up-facing surfaces below puddle_level (world Y), broken up by noise.
// Returns vec2(wet, puddle): wet = darkened damp surface, puddle = standing water (mirror-flat).
vec2 rat_wet_mask(vec3 wp, vec3 n_world, float wetness, float puddle_amount, float puddle_level,
		float puddle_scale) {
	float up = smoothstep(0.6, 0.95, n_world.y);
	float low = 1.0 - smoothstep(puddle_level - 0.02, puddle_level + 0.08, wp.y);
	float nz = rat_fbm3(vec3(wp.x, 0.0, wp.z) * puddle_scale, 4);
	float puddle = smoothstep(1.0 - puddle_amount * 0.75, 1.05 - puddle_amount * 0.75, nz) * up * low;
	// Damp patches and drips down walls.
	float damp = rat_fbm3(wp * puddle_scale * 2.3 + 5.0, 3);
	float streak = rat_vnoise3(vec3(wp.x * 9.0, wp.y * 0.8, wp.z * 9.0));
	float wet = clamp(wetness * (0.55 + 0.6 * damp) + streak * wetness * 0.35 * (1.0 - up), 0.0, 1.0);
	wet = max(wet, puddle);
	return vec2(wet, puddle);
}

// Expanding ripple rings for rain on puddles (world xz). Returns a 2D normal perturbation.
vec2 rat_ripples(vec2 xz, float t, float scale) {
	vec2 uv = xz * scale;
	vec2 c = floor(uv);
	vec2 acc = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = c + vec2(float(x), float(y));
			vec2 h = rat_hash22(g);
			vec2 centre = g + h;
			float phase = fract(t * (0.6 + h.x * 0.5) + h.y);
			vec2 d = uv - centre;
			float r = length(d);
			float ring = sin((r - phase) * 40.0) * smoothstep(0.0, 0.05, phase) * (1.0 - phase);
			ring *= 1.0 - smoothstep(phase - 0.08, phase + 0.08, abs(r - phase) + phase);
			acc += (r > 1e-4 ? d / r : vec2(0.0)) * ring;
		}
	}
	return acc * 0.25;
}
