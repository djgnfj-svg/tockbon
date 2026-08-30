// **05 — nothing but a BORDER, on water that does nothing at all.**
//
// Bad North's own answer, as its designer stated it at Konsoll 2018: *"most of the water is just
// completely flat, but then at the edge when something meets the water I highlight that instead… it also
// ties into the idea of expressing things in borders and not in… textures, not in field."*
//
// So: one flat colour, no ripple, no swell, no shading of any kind — and one line where the land meets
// it. ✅ **Chosen 2026-08-28** from the seven on this sheet.
//
// ⚠⚠ **THE MOVEMENT IS THE WHOLE REST OF THE FILE, AND IT IS COMPOUND ON PURPOSE** (the user:
// 「단순하게 원이 아니라 이제 복합적으로 움직이는걸 원한 진짜 물처럼」). A border that breathes on one
// clock is a ring pulsing; what reads as water is **several motions of different sizes and speeds
// running at once, none of them in step with the others.** Four are layered here, and each one is
// listed where it is built. **Take any of them out and it goes back to a ring.**
shader_type spatial;
// Unshaded on purpose: a flat sea that still catches a highlight is not flat.
render_mode unshaded;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 sea : source_color = vec4(0.430, 0.590, 0.660, 1.0);
uniform vec4 foam : source_color = vec4(0.900, 0.940, 0.950, 1.0);

// **The line at rest**, in tiles, and how hard its outer edge is.
uniform float line_tiles = 0.075;
uniform float line_hard = 0.45;
uniform float line_alpha = 0.90;

// --- 1. THE SHAPE OF THE LINE ------------------------------------------------------------------
// ⚠ **Three octaves, three sizes, three drifts, and they never line up.** One long enough to bend a
// whole stretch of coast, one that puts a bay inside that bend, one fine enough to fray the edge.
// A single octave, however strong, reads as a wobble; three read as water.
uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_a_speed = 0.055;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;
uniform float warp_b_speed = 0.130;
uniform float warp_c = 0.014;
uniform float warp_c_scale = 3.60;
uniform float warp_c_speed = 0.260;

// --- 2. HOW THICK IT IS, STRETCH BY STRETCH ----------------------------------------------------
// ⚠⚠ **The phase is read ALONG the coast**, so one stretch is running up while the next is drawing
// back. **This is the layer that stops it being a ring** — with one clock every point on the island
// swells at the same instant, which nothing in water does.
uniform float swing = 0.75;
uniform float swing_rate = 0.55;
uniform float along_scale = 0.55;
// How far the swing can take a stretch: at 1 it goes to nothing and comes back.
uniform float swing_floor = 0.18;

// --- 3. THE ONE THAT LETS GO -------------------------------------------------------------------
// ⚠ Once a cycle, over patches of coast, a line separates and travels seaward, fading as it goes.
// **Two lines on screen are the same line at two ages**, which is what backwash looks like.
uniform float peel = 0.55;
uniform float peel_tiles = 0.42;
uniform float peel_gate_scale = 0.85;

// --- 4. WHERE THE COAST IS QUIET ---------------------------------------------------------------
// ⚠ A wide, slow patch map, so some stretches are busy and others nearly still. Without it every part
// of the shore is equally lively, which is its own kind of ring.
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

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	// Signed: negative inland, positive out to sea, in tiles.
	float d = (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;

	// 1. Bend the line itself. ⚠ **Each octave drifts a different WAY as well as at a different rate** —
	// three layers all sliding along +x is one layer with extra steps.
	float w = (vnoise(p * warp_a_scale + vec2(t * warp_a_speed, t * warp_a_speed * 0.35)) - 0.5) * 2.0 * warp_a
			+ (vnoise(p * warp_b_scale - vec2(t * warp_b_speed * 0.4, t * warp_b_speed)) - 0.5) * 2.0 * warp_b
			+ (vnoise(p * warp_c_scale + vec2(-t * warp_c_speed, t * warp_c_speed * 0.8)) - 0.5) * 2.0 * warp_c;
	d += w;

	// 4. How lively this stretch of coast is at all, and it drifts so the quiet places move.
	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75, vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// 2. This stretch's own place in the cycle, and the width that comes out of it.
	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float ph = t * swing_rate + along * 6.2831;
	float breathe = mix(swing_floor, 1.0 + swing, (sin(ph) * 0.5 + 0.5) * live + (1.0 - live) * 0.5);
	float bw = max(line_tiles, 0.0001) * breathe;
	float band = 1.0 - smoothstep(bw * line_hard, bw, d);

	// 3. The one that has let go: a soft hump travelling out, over patches only.
	if (peel > 0.001) {
		float age = fract(ph / 6.2831);
		float away = age * peel_tiles;
		float pw = max(line_tiles, 0.0001) * 1.1;
		float hump = exp(-pow((d - away) / pw, 2.0)) * (1.0 - age);
		float where = smoothstep(0.35, 0.72, vnoise(p * peel_gate_scale + vec2(3.0, 17.0)));
		band = max(band, hump * where * peel * live);
	}

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
