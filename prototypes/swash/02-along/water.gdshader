// **02 — THE PHASE TRAVELS ALONG THE COAST.** One change from 01, and it is the smallest change that
// makes the shore go somewhere.
//
// **Where the gradient comes in.** The field is sampled twice more, a step either side, and the
// difference is which way the land is. Turn that normal ninety degrees and it points **along** the
// shore. The noise that carries the breathing phase is then read at a position sliding down that
// tangent, so **the pattern crawls around the island instead of sitting still and blinking.**
//
// ⚠ **This is flow-map advection in its simplest form and it has that form's flaw**: the tangent turns
// as the coast turns, so a pattern dragged along it stretches and smears where the coast bends hardest.
// 08 is the same idea done properly, at twice the cost. **Compare the two at the point, not on a
// straight stretch** — on a straight stretch they are identical.
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

uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;
uniform float warp_c = 0.014;
uniform float warp_c_scale = 3.60;

uniform float swing = 0.75;
uniform float swing_rate = 0.55;
uniform float along_scale = 0.55;
uniform float swing_floor = 0.18;

/// **How fast the pattern runs along the shore, in tiles per second.** ⚠ This is the whole candidate.
/// At 0 it is 01 with fewer dials; at 1 the coast is a conveyor belt.
uniform float run = 0.35;
/// How far apart the two extra samples are taken, in tiles. ⚠ Under a texel and the gradient is noise;
/// over a quarter tile and it stops following the corners the outline actually has.
uniform float grad_step = 0.06;

uniform float calm = 0.45;
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

/// **Which way is out to sea**, unit length. The field's own gradient — nothing is baked for this.
vec2 seaward(vec2 p) {
	float e = max(grad_step, 0.001);
	vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)),
				  sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
	return length(g) < 1e-5 ? vec2(0.0, 1.0) : normalize(g);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);
	vec2 n = seaward(p);
	// Ninety degrees off the normal: the direction the water runs, not the direction it comes from.
	vec2 tang = vec2(-n.y, n.x);
	// **The one line that matters.** Everything downstream reads noise HERE instead of at `p`.
	vec2 q = p - tang * (t * run);

	float w = (vnoise(q * warp_a_scale) - 0.5) * 2.0 * warp_a
			+ (vnoise(q * warp_b_scale + vec2(37.0, 11.0)) - 0.5) * 2.0 * warp_b
			+ (vnoise(q * warp_c_scale + vec2(5.0, 91.0)) - 0.5) * 2.0 * warp_c;
	d += w;

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	float along = vnoise(q * along_scale + vec2(11.0, 5.0));
	float ph = t * swing_rate + along * 6.2831853;
	float breathe = mix(swing_floor, 1.0 + swing,
						(sin(ph) * 0.5 + 0.5) * live + (1.0 - live) * 0.5);
	float bw = max(line_tiles, 0.0001) * breathe;
	float band = 1.0 - smoothstep(bw * line_hard, bw, d);

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
