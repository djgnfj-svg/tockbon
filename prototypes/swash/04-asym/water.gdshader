// **04 — IT RUSHES UP AND DRAINS BACK, AND THOSE TAKE DIFFERENT LENGTHS OF TIME.** 03 with one
// substitution: the cosine that drives the run-up is replaced by a curve that is steep on the way up
// and long on the way down.
//
// **Why this is its own candidate rather than a setting of 03.** Every symmetric oscillator — sine,
// cosine, a triangle wave — spends as long arriving as leaving, and **water does not.** A wave breaks
// and the sheet is up the rock in under a second; the drain back is several times that. It is the one
// asymmetry the eye can name without knowing it is naming it, and Cyanilux's breakdown flags it as the
// thing that shader deliberately does not do.
//
// ⚠ **The drain also leaves a mark.** Water pulling back off rock leaves a thinning film behind it, so
// the line is drawn WIDER and fainter on the way out than on the way in at the same height. Without
// that half the asymmetry is only in the timing and reads as a stutter.
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

uniform float reach = 1.10;
uniform float count = 2.2;
uniform float rate = 0.42;
uniform float wave_w = 0.30;
uniform float swash = 0.16;

/// ⚠⚠ **THE CANDIDATE, IN ONE NUMBER.** What fraction of a cycle the water spends running UP. At 0.5
/// this file is 03 with a different curve shape; at 0.2 the sheet is up the rock in a fifth of the
/// time it takes to drain, which is roughly what a small wave on rock actually does.
uniform float rise_frac = 0.22;
/// How much wider and fainter the line is drawn while draining. 0 turns the second half off.
uniform float drain_spread = 0.85;

/// **How far apart along the coast two stretches are in their cycle.** ⚠ Without this the whole island
/// runs up at the same instant, which is a ring pulsing however good the curve is.
uniform float along_scale = 0.55;

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

/// **The shape of one wash**, 0 at rest and 1 at the top of the rock. Steep up, long down, and eased
/// at both ends so the turn is not a corner.
float wash(float x, float r) {
	r = clamp(r, 0.05, 0.95);
	float u = x < r ? x / r : 1.0 - (x - r) / (1.0 - r);
	return smoothstep(0.0, 1.0, u);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// This stretch's own place in the cycle.
	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);
	// Draining is everything past the peak, and it is most of the cycle.
	float draining = step(rise_frac, x);

	float ds = d - up * swash * live;

	// The line: wider and fainter while the water is pulling back off the rock.
	float bw = max(line_tiles, 0.0001) * (1.0 + draining * drain_spread * (1.0 - up));
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.55, draining * (1.0 - up));

	// The lines still on their way in, marching down the same gradient as in 03.
	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g)) * live;

	float f = clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0);
	ALBEDO = mix(sea.rgb, foam.rgb, f);
}
