// Shared procedural noise for RAT OPS shaders (owner: shaders-materials).
// All noise is 3D / world- or object-space so it never shows tiling seams.

float rat_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float rat_hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 rat_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 rat_hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Value noise 3D, range [0,1].
float rat_vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = rat_hash33(i).x;
	float n100 = rat_hash33(i + vec3(1.0, 0.0, 0.0)).x;
	float n010 = rat_hash33(i + vec3(0.0, 1.0, 0.0)).x;
	float n110 = rat_hash33(i + vec3(1.0, 1.0, 0.0)).x;
	float n001 = rat_hash33(i + vec3(0.0, 0.0, 1.0)).x;
	float n101 = rat_hash33(i + vec3(1.0, 0.0, 1.0)).x;
	float n011 = rat_hash33(i + vec3(0.0, 1.0, 1.0)).x;
	float n111 = rat_hash33(i + vec3(1.0, 1.0, 1.0)).x;
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

float rat_fbm3(vec3 p, int octaves) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < octaves; i++) {
		s += a * rat_vnoise3(p);
		p = p * 2.03 + vec3(17.1, 9.7, 3.3);
		a *= 0.5;
	}
	return s;
}

// Value noise 2D, range [0,1].
float rat_vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(rat_hash21(i), rat_hash21(i + vec2(1.0, 0.0)), u.x),
			mix(rat_hash21(i + vec2(0.0, 1.0)), rat_hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 3D Worley. Returns vec4(F1 distance, cell-local offset to nearest feature point xyz).
// The offset (feature - p) lets callers build a spherical crater normal.
vec4 rat_worley3(vec3 p, float jitter) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	vec3 best_off = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = g + (rat_hash33(i + g) - 0.5) * jitter + 0.5;
				vec3 d = o - f;
				float dd = dot(d, d);
				if (dd < best) {
					best = dd;
					best_off = d;
				}
			}
		}
	}
	return vec4(sqrt(best), best_off);
}

// Same as rat_worley3 but also returns a per-cell random value (w) for size variation.
// Output: xyz = offset to feature, w = F1 dist; seed via out param.
float rat_worley3_id(vec3 p, float jitter, out vec3 off, out float cell_rand) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	off = vec3(0.0);
	cell_rand = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 h = rat_hash33(i + g);
				vec3 o = g + (h - 0.5) * jitter + 0.5;
				vec3 d = o - f;
				float dd = dot(d, d);
				if (dd < best) {
					best = dd;
					off = d;
					cell_rand = rat_hash33(i + g + vec3(41.0, 7.0, 13.0)).x;
				}
			}
		}
	}
	return sqrt(best);
}

// 3D Worley F1 / F2 plus nearest-cell random. Returns vec3(F1, F2, cell_rand).
vec3 rat_worley3_f12(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = g + rat_hash33(i + g);
				float dd = length(o - f);
				if (dd < f1) {
					f2 = f1;
					f1 = dd;
					id = rat_hash33(i + g + vec3(41.0, 7.0, 13.0)).x;
				} else if (dd < f2) {
					f2 = dd;
				}
			}
		}
	}
	return vec3(f1, f2, id);
}

// 2D Worley F1 / F2 (for foil facets, stone cells). Returns vec2(F1, F2).
vec2 rat_worley2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + rat_hash22(i + g);
			float d = length(o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f1, f2);
}

// Convert a world-space normal to view space (for writing NORMAL directly).
vec3 rat_world_to_view_n(mat4 view_matrix, vec3 n_world) {
	return normalize((view_matrix * vec4(n_world, 0.0)).xyz);
}
