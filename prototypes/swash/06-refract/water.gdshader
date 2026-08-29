// **06 — IT BREAKS HARD ON THE POINTS AND GOES QUIET IN THE BAYS.** The third thing the gradient
// gives away for free: take it a second time and the answer is which way the coast BENDS.
//
// **The physics being copied has a name — wave refraction.** A wave slows as it reaches shallow water,
// so the part of a crest that meets a headland first slows first and the rest of the crest swings
// round to follow. Energy that arrived spread across open water is delivered concentrated onto the
// point, and the bays between get what is left. **Every coast photograph shows it**: white on the
// headlands, calm in the coves, and it is the same swell in both places.
//
// ⚠⚠ **THIS IS THE ONE CANDIDATE THAT CANNOT BE FAKED WITH NOISE.** 01's quiet patches are quiet in
// places that have nothing to do with the island's shape, and no seed makes a noise field agree with a
// coastline. **This term is computed FROM the coastline**, so a bay is quiet because it is a bay.
//
// ⚠ **The second derivative is noisy** — it is a difference of differences of a texture read. Sampled
// too tightly it reads texel edges rather than the coast, which is why `curve_step` is a good deal
// wider than the gradient step in 02 and 05.
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

/// **How wide a stencil the bend is measured with, in tiles.** ⚠⚠ Wide on purpose: at the gradient's
/// own step this term measures the bake's texels, not the island.
uniform float curve_step = 0.30;
/// **How much the bend is allowed to matter.** At 0 this file is 04 with extra maths; at 1 the bays go
/// nearly still and the points are twice as loud as anything the game has shown.
uniform float refract_amt = 0.85;
/// What a point gets at most, and what a bay keeps at least, as multiples of the resting width.
uniform float point_gain = 2.1;
uniform float bay_floor = 0.35;

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

/// **How the coast bends here**, positive off a point and negative inside a bay. This is the field's
/// own divergence: on a signed distance field it is exactly the curvature of the outline.
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

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);

	// **Energy delivered here**: 1 on a straight stretch, up on a point, down in a bay.
	float k = clamp(bend(p) * 0.5, -1.0, 1.0);
	float energy = mix(1.0, mix(bay_floor, point_gain, k * 0.5 + 0.5), refract_amt);

	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);

	float ds = d - up * swash * energy;

	float bw = max(line_tiles, 0.0001) * energy;
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);

	float g = clamp(ds / max(reach, 0.001), 0.0, 1.0);
	float lines = fract(g * count - t * rate);
	float inc = smoothstep(1.0 - wave_w, 1.0, lines);
	inc *= smoothstep(0.0, 0.22, g) * (1.0 - smoothstep(0.55, 1.0, g)) * clamp(energy, 0.0, 1.4);

	float f = clamp(max(band, inc * 0.85) * line_alpha, 0.0, 1.0);
	ALBEDO = mix(sea.rgb, foam.rgb, f);
}
