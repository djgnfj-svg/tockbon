// **10 — 06 AND 08, WHICH IS WHAT THE USER PICKED** (2026-08-29, on the island lab: 「6번 8번을 합친게
// 좋다 거품이 없다가 가끔씩 없어지는게 너무 조흔데」 — *"6 and 8 combined is the good one; the foam
// being absent and then vanishing now and then is really good"*).
//
// ⚠⚠ **READ THAT SENTENCE BEFORE TURNING ANY DIAL HERE.** What was praised is **not** a line that
// moves nicely — it is a line that **is not everywhere**, and that **goes away in places.** Every value
// below that makes the shore more uniform is a value working against the thing that was chosen.
//
// **Where the absence comes from, and it is two different mechanisms:**
//   · **06's refraction** — the bays get `bay_floor` of the energy, so the line genuinely thins to
//     almost nothing inside a cove and stays thin, because a cove is a cove. **This is the permanent
//     absence.**
//   · **08's travel** — the pattern crawls along the coast, so a thin stretch is not thin forever;
//     it drifts. **This is the "now and then".**
// ⚠ Take either one out and half the sentence stops being true.
//
// **What is inherited without being the point**: the rush-and-drain curve from 04, and the incoming
// lines from 03. They arrive because 06 sits on top of both.
//
// ⚠⚠ **05's wind is deliberately NOT here.** 09 runs it and 09 was not what was picked; a heading that
// keeps one shore permanently loud fights directly with the two absences above.
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

// --- from 08: the travel along the coast --------------------------------------------------------
/// How fast the pattern runs along the shore, in tiles per second, and how long one copy travels
/// before it restarts. ⚠ `cycle` too long brings the shear back; too short makes the crossfade throb.
uniform float run = 0.30;
uniform float cycle = 2.6;
uniform float grad_step = 0.06;
uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;
uniform float along_scale = 0.55;

// --- from 06: the coast's own shape decides the energy -------------------------------------------
uniform float curve_step = 0.30;
uniform float refract_amt = 0.85;
uniform float point_gain = 2.1;
/// ⚠⚠ **THE NUMBER THE PICK WAS ABOUT.** How much of the line survives inside a bay, as a fraction of
/// its resting width. **This is what「없다」 means on screen.** Raising it toward 1 gives back the
/// even ring the user has now rejected three times.
uniform float bay_floor = 0.35;

// --- inherited through 06: 04's curve and 03's incoming lines ------------------------------------
uniform float rate = 0.42;
uniform float swash = 0.16;
uniform float rise_frac = 0.22;
uniform float drain_spread = 0.85;
uniform float reach = 1.10;
uniform float count = 2.2;
uniform float wave_w = 0.30;

// --- the quiet patches ---------------------------------------------------------------------------
/// ⚠ **Low on purpose, and it is not 01's 0.45.** The refraction is already taking stretches out; a
/// second, unrelated mask on top of it was quietening coast that the coast's own shape had quietened,
/// and the line broke up into dashes. **This one only damps the MOVEMENT**, never the resting width.
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

/// How the coast bends here: positive off a point, negative inside a bay.
float bend(vec2 p) {
	float e = max(curve_step, 0.01);
	float c = sdf(p);
	float s = sdf(p + vec2(e, 0.0)) + sdf(p - vec2(e, 0.0))
			+ sdf(p + vec2(0.0, e)) + sdf(p - vec2(0.0, e)) - 4.0 * c;
	return s / (e * e);
}

/// One wash: steep up, long down, eased at both ends.
float wash(float x, float r) {
	r = clamp(r, 0.05, 0.95);
	float u = x < r ? x / r : 1.0 - (x - r) / (1.0 - r);
	return smoothstep(0.0, 1.0, u);
}

/// One travelling copy of the pattern, read `age` seconds down the tangent.
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

	// **08 — two copies travelling along the coast, crossfaded so neither ever shears.**
	float c = max(cycle, 0.1);
	float k = abs(1.0 - 2.0 * fract(t / c));
	vec2 l0 = layer(p, tang, fract(t / c) * c);
	vec2 l1 = layer(p, tang, fract(t / c + 0.5) * c);
	float w = mix(l0.x, l1.x, k);
	float along = mix(l0.y, l1.y, k);

	// **06 — what this stretch of coast is owed, from its own curvature.**
	float kb = clamp(bend(p) * 0.5, -1.0, 1.0);
	float energy = mix(1.0, mix(bay_floor, point_gain, kb * 0.5 + 0.5), refract_amt);

	// ⚠ **Damps the movement only.** Multiplying the width by this as well is what turned the line
	// into dashes — the bays were being emptied twice, once by their shape and once by a noise field
	// that knows nothing about them.
	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// **04 — up fast, drain slow, on a phase that travelled here along the shore.**
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);
	float draining = step(rise_frac, x);

	float ds = d + w - up * swash * energy * live;

	float bw = max(line_tiles, 0.0001) * energy
			 * (1.0 + draining * drain_spread * (1.0 - up));
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.55, draining * (1.0 - up));

	// **03 — the lines still on their way in.**
	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g))
		 * clamp(energy, 0.0, 1.4) * live;

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0));
}
