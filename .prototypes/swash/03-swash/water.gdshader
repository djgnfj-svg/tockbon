// **03 — LINES COME IN AND THE WHOLE SHORE RUNS UP AND DRAWS BACK.** Cyanilux's shoreline breakdown,
// stated as a mechanism: the distance to shore is a gradient, repeating lines are cut out of it with
// `fract`, and time SUBTRACTED from that gradient marches them landward. A second wave, on the same
// clock, slides the shore itself in and out — the swash.
//
// ⚠⚠ **THE MOTION IS PERPENDICULAR TO THE COAST, NOT ALONG IT.** That is the whole difference from
// 02, and the two answer different halves of the question: 02 makes the pattern travel around the
// island, this makes the water arrive at it. **They are not rivals** — 09 runs both.
//
// ⚠ **The rise and the fall take the same length of time here**, because a cosine is symmetric.
// Cyanilux says so outright about this exact shader: *"it's not entirely accurate to real life, where
// the flow of water up the shore tends to have a shorter duration than when it retreats, but I think
// it's good enough."* **04 is that sentence taken as a to-do.**
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

/// **How far out the incoming lines are born, in tiles**, and how many are on their way at once.
uniform float reach = 1.10;
uniform float count = 2.2;
/// Cycles per second. ⚠ The swash below is locked to this — two clocks is two seas.
uniform float rate = 0.42;
/// How thick an incoming line is, as a fraction of one repeat.
uniform float wave_w = 0.30;
/// **How far the shore itself runs up and back, in tiles.**
uniform float swash = 0.16;
/// Where in the cycle the run-up sits relative to the arriving line. ⚠ By hand: a line landing exactly
/// as the shore retreats is the one thing that never happens in water.
uniform float swash_phase = 0.35;

/// How much of the coast is quiet at any moment, and how big a quiet stretch is.
uniform float calm = 0.40;
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

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// **The swash: the shore itself, in and out.** Subtracted from the distance, so at the top of the
	// cycle every point on the coast is measured from a waterline that has climbed onto the rock.
	float up = cos((t * rate + swash_phase) * 6.2831853) * 0.5 + 0.5;
	float ds = d - up * swash * live;

	// The resting line, riding on that.
	float bw = max(line_tiles, 0.0001);
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);

	// **The lines on their way in.** `g` is 0 at the shore and 1 out at `reach`; time is subtracted so
	// the repeats march down it toward the land.
	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	// Born faint far out, gone by the time they reach the rock — a line that arrives and then simply
	// stops existing is a line the eye reads as a seam.
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g)) * live;

	float f = clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0);
	ALBEDO = mix(sea.rgb, foam.rgb, f);
}
