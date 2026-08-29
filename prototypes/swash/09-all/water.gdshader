// **09 — FOUR OF THEM AT ONCE.** The travel of 08, the rush-and-drain of 04, the weather side of 05
// and the refraction of 06, in one shader, so that the question *"do these fight each other?"* is
// answered by looking rather than by argument.
//
// ⚠⚠ **THIS IS NOT A RECOMMENDATION AND IT IS NOT THE PROPOSED SEA.** It is the ceiling: everything
// found, turned on together. **The island has twice chosen the sea that does LESS** — seven candidates
// on one block, and 거품 put back and removed the same day. If this one wins outright that is a real
// reversal and worth having on record; the likelier useful outcome is *"that, but only the refraction."*
//
// ⚠ **07's clumps are wired but OFF** (`clump` at 0). They change what the foam is made of rather than
// how it moves, and the sea this island keeps is *"expressing things in borders and not in… textures."*
// Turn it up if the borders alone come out too clean.
//
// **What each term is doing, in one line each**:
//   · the pattern crawls along the coast without shearing at the points          (08)
//   · the water goes up fast and drains slowly, and drains wider and fainter     (04)
//   · the windward shore stays windward instead of the calm patch wandering      (05)
//   · the points break and the bays stay quiet, computed from the outline itself (06)
shader_type spatial;
render_mode unshaded;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 sea : source_color = vec4(0.430, 0.590, 0.660, 1.0);
uniform vec4 foam : source_color = vec4(0.900, 0.940, 0.950, 1.0);

uniform float line_tiles = 0.075;
uniform float line_hard = 0.45;
uniform float line_alpha = 0.90;

// --- travel (08) ---
uniform float run = 0.30;
uniform float cycle = 2.6;
uniform float grad_step = 0.06;
uniform float warp_a = 0.050;
uniform float warp_a_scale = 0.45;
uniform float warp_b = 0.026;
uniform float warp_b_scale = 1.30;
uniform float along_scale = 0.55;

// --- rush and drain (04) ---
uniform float rate = 0.42;
uniform float swash = 0.16;
uniform float rise_frac = 0.22;
uniform float drain_spread = 0.85;
uniform float reach = 1.10;
uniform float count = 2.2;
uniform float wave_w = 0.30;

// --- weather (05) ---
uniform float wind_deg = 35.0;
uniform float shelter = 0.55;
uniform float lee_floor = 1.0;

// --- refraction (06) ---
uniform float curve_step = 0.30;
uniform float refract_amt = 0.70;
uniform float point_gain = 1.9;
uniform float bay_floor = 0.45;

// --- clumping (07), off by default ---
uniform float clump = 0.0;
uniform float cell_scale = 5.5;
uniform float cell_speed = 0.30;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float voro(vec2 p, float t) {
	vec2 i = floor(p), f = fract(p);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			o = 0.5 + 0.5 * sin(t * cell_speed * 6.2831853 + 6.2831853 * o);
			best = min(best, length(g + o - f));
		}
	}
	return best;
}

float sdf(vec2 p) {
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	return (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;
}

vec2 seaward(vec2 p) {
	float e = max(grad_step, 0.001);
	vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)),
				  sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
	return length(g) < 1e-5 ? vec2(0.0, 1.0) : normalize(g);
}

float bend(vec2 p) {
	float e = max(curve_step, 0.01);
	float c = sdf(p);
	float s = sdf(p + vec2(e, 0.0)) + sdf(p - vec2(e, 0.0))
			+ sdf(p + vec2(0.0, e)) + sdf(p - vec2(0.0, e)) - 4.0 * c;
	return s / (e * e);
}

float wash(float x, float r) {
	r = clamp(r, 0.05, 0.95);
	float u = x < r ? x / r : 1.0 - (x - r) / (1.0 - r);
	return smoothstep(0.0, 1.0, u);
}

vec2 layer(vec2 p, vec2 tang, float age) {
	vec2 q = p - tang * (age * run);
	float w = (vnoise(q * warp_a_scale) - 0.5) * 2.0 * warp_a
			+ (vnoise(q * warp_b_scale + vec2(37.0, 11.0)) - 0.5) * 2.0 * warp_b;
	float along = vnoise(q * along_scale + vec2(11.0, 5.0));
	return vec2(w, along);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);
	vec2 n = seaward(p);
	vec2 tang = vec2(-n.y, n.x);

	// 08 — two travelling copies, crossfaded.
	float c = max(cycle, 0.1);
	float k = abs(1.0 - 2.0 * fract(t / c));
	vec2 l0 = layer(p, tang, fract(t / c) * c);
	vec2 l1 = layer(p, tang, fract(t / c + 0.5) * c);
	float w = mix(l0.x, l1.x, k);
	float along = mix(l0.y, l1.y, k);

	// 05 — which side of the island this is.
	float a = radians(wind_deg);
	vec2 runv = vec2(cos(a), sin(a));
	float face = clamp(dot(n, -runv), -1.0, 1.0) * 0.5 + 0.5;
	float exposed = mix(1.0 - shelter, 1.0, smoothstep(0.20, 0.85, face));

	// 06 — how much energy the coast's own shape delivers here.
	float kb = clamp(bend(p) * 0.5, -1.0, 1.0);
	float energy = mix(1.0, mix(bay_floor, point_gain, kb * 0.5 + 0.5), refract_amt);

	// 04 — up fast, down slow, on this stretch's own phase.
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);
	float draining = step(rise_frac, x);

	float live = exposed * energy;
	float ds = d + w - up * swash * live;

	float bw = max(line_tiles, 0.0001) * max(lee_floor, live)
			 * (1.0 + draining * drain_spread * (1.0 - up));
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.55, draining * (1.0 - up));

	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g)) * clamp(live, 0.0, 1.4);

	float f = max(band, inc * 0.85);

	// 07 — off unless asked for.
	if (clump > 0.001) {
		float cells = 1.0 - smoothstep(0.10, 0.62, voro(p * cell_scale, t));
		f *= mix(1.0, cells, clump);
		f = max(f, (1.0 - smoothstep(bw * line_hard, bw, ds)) * 0.55);
	}

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(f * line_alpha, 0.0, 1.0));
}
