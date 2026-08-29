// **11 — 10 WITH THE TWO MEASUREMENTS THE USER GAVE, AND NOTHING ELSE CHANGED.** The baseline for this
// second round, and it exists so that 12..15 are each judged against 10-plus-the-corrections rather
// than against 10.
//
// **The two corrections** (2026-08-29, on the island lab):
//   · 「거품하고 해안 라인 흰색이 너무 거리가 멀어 저렇게 멀 필요없음」 — *"the foam and the shoreline
//     are too far apart; they do not need to be that far"* ⇒ `reach` 1.10 → 0.40 tiles. **The foam is
//     now born within half a tile of the rock** instead of out where the sea is open.
//   · 「흰색선은 더 얇아도 무방할듯」 — *"the white line could be thinner"* ⇒ `line_tiles` 0.075 →
//     0.045, which is under one texel of the game's own field at its resting width.
//
// ⚠⚠ **0.045 IS BELOW ONE TEXEL** (the field is 16 per tile, so a texel is 0.0625). The line does not
// break up, because the field is sampled with linear filtering and the smoothstep straddles the
// interpolation — but **this is the floor.** Thinner than this and the coast starts coming out dashed
// on the diagonals, which is exactly the failure that pushed the bake from 4 to 16 in the first place.
//
// ⚠ **Nothing else here differs from 10.** The refraction, the travel, the drain and the incoming
// lines are the same code with the same numbers.
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
uniform float reach = 0.40;
uniform float count = 2.2;
uniform float wave_w = 0.30;

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

	float bw = max(line_tiles, 0.0001) * energy
			 * (1.0 + draining * drain_spread * (1.0 - up));
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.55, draining * (1.0 - up));

	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g))
		 * clamp(energy, 0.0, 1.4) * live;

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0));
}
