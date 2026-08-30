// **08 — THE SAME TRAVEL AS 02, DONE WITHOUT THE SMEAR.** Two copies of the pattern, each dragged
// along the coast for half a cycle and then restarted, crossfaded so that whichever copy is freshest
// is the one on screen.
//
// **Why 02 needs fixing at all.** Dragging a noise field along a direction that itself changes from
// place to place stretches the field wherever the direction turns — and on this island the direction
// turns hardest exactly at the points, which are the places being looked at. Left running, 02 does not
// drift; it **shears**, further every second, because the offset grows without bound.
//
// **The fix is the standard flow-map one** and it is what Waterways bakes into a river: never let one
// copy travel more than half a cycle. Sample twice, at phases half a period apart, weight each by how
// far it is from its own restart, and add. **The seam is spread across the whole surface instead of
// building up in one place** — the cost is a second set of samples and a slight softness that never
// goes away.
//
// ⚠ **Judge this one against 02 and nothing else.** Side by side on a straight stretch they are the
// same picture; at the point, 02 is the one whose foam is being pulled into streaks.
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

/// **How fast the pattern runs along the shore, in tiles per second**, and how long one copy is
/// allowed to travel before it restarts. ⚠ `cycle` too long and the shear is back; too short and the
/// crossfade is a visible throb.
uniform float run = 0.35;
uniform float cycle = 2.6;
uniform float grad_step = 0.06;

uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;

uniform float swing = 0.75;
uniform float swing_rate = 0.55;
uniform float along_scale = 0.55;
uniform float swing_floor = 0.18;

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

vec2 seaward(vec2 p) {
	float e = max(grad_step, 0.001);
	vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)),
				  sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
	return length(g) < 1e-5 ? vec2(0.0, 1.0) : normalize(g);
}

/// **One copy of everything the flow carries**, sampled at a position that has travelled `age`
/// seconds down the tangent. Returned as the two numbers the band is built from.
vec2 layer(vec2 p, vec2 tang, float age, float t) {
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

	// **Two ages, half a cycle apart**, each restarting before it has travelled far enough to shear.
	float c = max(cycle, 0.1);
	float a0 = fract(t / c) * c;
	float a1 = fract(t / c + 0.5) * c;
	// Each copy is loudest in the middle of its own life and silent at its restart, so the restart is
	// never the thing on screen.
	float k = abs(1.0 - 2.0 * fract(t / c));
	vec2 l0 = layer(p, tang, a0, t);
	vec2 l1 = layer(p, tang, a1, t);
	float w = mix(l0.x, l1.x, k);
	float along = mix(l0.y, l1.y, k);

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	float ph = t * swing_rate + along * 6.2831853;
	float breathe = mix(swing_floor, 1.0 + swing,
						(sin(ph) * 0.5 + 0.5) * live + (1.0 - live) * 0.5);
	float bw = max(line_tiles, 0.0001) * breathe;
	float band = 1.0 - smoothstep(bw * line_hard, bw, d + w);

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
