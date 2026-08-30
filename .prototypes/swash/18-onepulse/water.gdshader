// **18 — THERE IS NO SEPARATE FOAM. THE SURGE IS THE LINE.**
//
// **The most literal reading of** 「얇게 있다가 파형이 왔을떄만 두꺼워야하는데」 — *"it should be thin
// and only thicken when the wave arrives"*. A hairline on the rock, and when a wave runs up, that same
// line swells and then goes back to being a hairline. **Nothing else is drawn at all.**
//
// ⚠⚠ **THE INCOMING BANDS ARE DELETED, NOT DAMPED.** 03's `fract` train — inherited by every candidate
// from 04 through 17 — is simply not in this file. **That train is 거품**, which this island has
// removed twice; 16 and 17 keep it only because it was in the picture that was praised.
// ⇒ **If 18 is enough, 거품 has now been rejected a third time and the sea is one line that breathes.**
//
// ⚠ `reach`, `count` and `wave_w` are gone with it — there is no second thing for them to describe.
// **The whole shader is a width and a phase.**
shader_type spatial;
render_mode unshaded;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 sea : source_color = vec4(0.430, 0.590, 0.660, 1.0);
uniform vec4 foam : source_color = vec4(0.900, 0.940, 0.950, 1.0);

/// ⚠ **The user's number.** See the head of this file.
uniform float line_tiles = 0.045;
uniform float line_hard = 0.45;
uniform float line_alpha = 0.90;

uniform float run = 0.30;
uniform float cycle = 2.6;
uniform float grad_step = 0.06;
uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;
uniform float along_scale = 0.55;

uniform float curve_step = 0.30;
uniform float refract_amt = 0.85;
uniform float point_gain = 2.1;
uniform float bay_floor = 0.35;

uniform float rate = 0.42;
uniform float swash = 0.16;
uniform float rise_frac = 0.22;
uniform float drain_spread = 0.85;
/// ⚠⚠ **The user's other number.** How far out the incoming foam is born, in tiles.

/// ⚠⚠ **THE RESTING WIDTH, AND IT IS THE WHOLE POINT OF THIS SET** (2026-08-29, the user: 「얇게
/// 있다가 파형이 왔을떄만 두꺼워야하는데 미리 흔적이 너무 남아있는느낌이야 기본값이 너무 있어」 —
/// *"it should be thin and only thicken when the wave arrives; there is too much trace left in
/// advance, the base value is too much"*). What fraction of `line_tiles` is on the rock when nothing
/// is happening. **Below this number there is no line at all.**
uniform float rest_frac = 0.45;
/// How much width the arriving wave ADDS, as multiples of `line_tiles`. ⚠ This rides on `up`, so it
/// is zero for most of the cycle and full only at the top of a run.
uniform float surge = 1.6;
/// How much the bay/point energy is allowed to thin the RESTING line. At 0 the hairline is the same
/// all round the island; at 1 the bays lose it too.
uniform float rest_shape = 0.7;
uniform float calm = 0.25;
uniform float calm_scale = 0.38;
uniform float calm_speed = 0.035;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
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

	float c = max(cycle, 0.1);
	float k = abs(1.0 - 2.0 * fract(t / c));
	vec2 l0 = layer(p, tang, fract(t / c) * c);
	vec2 l1 = layer(p, tang, fract(t / c + 0.5) * c);
	float w = mix(l0.x, l1.x, k);
	float along = mix(l0.y, l1.y, k);

	float kb = clamp(bend(p) * 0.5, -1.0, 1.0);
	float energy = mix(1.0, mix(bay_floor, point_gain, kb * 0.5 + 0.5), refract_amt);

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);
	float draining = step(rise_frac, x);

	float ds = d + w - up * swash * energy * live;

	// **One line, and its width is the whole shader.**
	float rest = max(line_tiles, 0.0001) * rest_frac * mix(1.0, energy, rest_shape);
	float bw = rest + max(line_tiles, 0.0001) * surge * up * energy * live;
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	// The mark left while the water is going back: narrower and fainter, and gone within the cycle.
	band *= mix(1.0, 0.72, draining * (1.0 - up));

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
