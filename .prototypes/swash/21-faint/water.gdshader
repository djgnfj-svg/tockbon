// **21 — 20 WITH THE HINT HALVED AGAIN.** The least foam of anything in this lab that still has any.
//
// ⚠⚠ **AT `hint_amt` 0.20 THE FOAM IS AT THE EDGE OF VISIBILITY** against `COL_WATER`. If this reads as
// "no foam at all" then the answer for this island is 18, and 거품 has been rejected a third time —
// which is worth knowing plainly rather than shipping a band nobody can see.//
// **Two changes from 18, both the user's** (2026-08-29): 「이상태에서 아주 약간의 거품을 추가해주고
// 너무 파형이 두껍다는 생각이 있음」 — *"from this state, add a very small amount of foam, and I think
// the swell is too thick"*.
//   · **the surge is cut** — 18 added 1.6 times the resting width at the top of a run, so the line
//     more than tripled. These add much less.
//   · **a hint of 거품 comes back** — one band, at a third of full strength, born within a third of a
//     tile of the rock and only while a wave is up.
//
// ⚠ **These three differ ONLY in those two numbers.** Nothing else about them is different, from each
// other or from 18 — so what is being chosen here is an amount, not a mechanism.
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
uniform float surge = 0.50;
/// How much the bay/point energy is allowed to thin the RESTING line. At 0 the hairline is the same
/// all round the island; at 1 the bays lose it too.
uniform float rest_shape = 0.7;
/// **The hint of 거품.** How strong it is drawn (1.0 would be a second shoreline), how far out it is
/// born in tiles, and how wide the band is as a fraction of one repeat.
/// ⚠⚠ **`hint_amt` IS THE WHOLE ADDITION.** At 0 this file is 18 with a thinner surge; above about 0.5
/// it stops being a hint and becomes the foam train that has now been removed twice.
uniform float hint_amt = 0.20;
uniform float hint_reach = 0.35;
uniform float hint_w = 0.22;
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

	// **The line, and its width is still most of the shader.**
	float rest = max(line_tiles, 0.0001) * rest_frac * mix(1.0, energy, rest_shape);
	float bw = rest + max(line_tiles, 0.0001) * surge * up * energy * live;
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.72, draining * (1.0 - up));

	// **A HINT of 거품, and hint is the specification** (2026-08-29, the user: 「아주 약간의 거품을
	// 추가해주고」). One band, born inside `hint_reach` of the rock, drawn at `hint_amt` of full
	// strength — so it is a suggestion on the water rather than a second white line.
	// ⚠ It rides `up` and `energy` like everything else here: no wave, no hint; quiet bay, no hint.
	float g = clamp(ds / max(hint_reach, 0.001), 0.0, 1.0);
	float lines = fract(g - t * rate);
	float inc = smoothstep(1.0 - hint_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.25, g) * (1.0 - smoothstep(0.50, 1.0, g))
		 * clamp(energy, 0.0, 1.4) * live * up * hint_amt;

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(max(band, inc) * line_alpha, 0.0, 1.0));
}
