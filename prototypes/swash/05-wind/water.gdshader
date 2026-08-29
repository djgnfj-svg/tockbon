// **05 — THE WAVES COME FROM ONE DIRECTION.** The gradient again, used for the other thing it is good
// for: dot it with a fixed heading and every stretch of coast knows whether it is facing the weather
// or sheltered from it.
//
// **What this buys that no amount of noise can.** 01's quiet stretches are quiet at random and they
// MOVE — the calm patch drifts, so the sheltered side of the island is a different side every minute.
// **Real shelter does not drift.** The lee of a headland is the lee all day, and an island whose
// windward shore stays windward is an island the eye believes is sitting in weather.
//
// ⚠⚠ **THIS CONTRADICTS A LIVE RULE, AND DELIBERATELY.** The glossary says the 해안선 is the line
// **"whose thickness does not change wherever the wind blows from — because the water is always
// touching the land."** That rule was written about the resting line and it is correct about it. What
// this candidate claims is narrower: the resting line stays, and the MOVEMENT on top of it is what
// takes a side. ⚠ If the line disappears anywhere on the lee shore, this candidate has lost and the
// old rule was right — watch the sheltered side, not the exposed one.
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

/// **Which way the weather runs**, as a heading in degrees on the board.
uniform float wind_deg = 35.0;
/// How hard the sheltered side is damped. At 1 the lee has no movement left at all, only the resting
/// line; at 0 this file is 03 with extra maths.
uniform float shelter = 0.75;
/// **The floor under the resting line.** ⚠ Never 0 — see the warning at the top.
uniform float lee_floor = 1.0;
uniform float grad_step = 0.06;

uniform float reach = 1.10;
uniform float count = 2.2;
uniform float rate = 0.42;
uniform float wave_w = 0.30;
uniform float swash = 0.16;
uniform float rise_frac = 0.22;
uniform float along_scale = 0.55;

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

float wash(float x, float r) {
	r = clamp(r, 0.05, 0.95);
	float u = x < r ? x / r : 1.0 - (x - r) / (1.0 - r);
	return smoothstep(0.0, 1.0, u);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);

	vec2 n = seaward(p);
	float a = radians(wind_deg);
	vec2 run = vec2(cos(a), sin(a));
	// **Facing the weather** means the outward normal points back INTO the heading the waves run along.
	float face = clamp(dot(n, -run), -1.0, 1.0) * 0.5 + 0.5;
	// Eased, so the turn from exposed to sheltered happens over a stretch rather than at one point.
	float exposed = mix(1.0 - shelter, 1.0, smoothstep(0.20, 0.85, face));

	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);

	float ds = d - up * swash * exposed;

	float bw = max(line_tiles, 0.0001) * max(lee_floor, exposed);
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);

	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g)) * exposed;

	float f = clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0);
	ALBEDO = mix(sea.rgb, foam.rgb, f);
}
