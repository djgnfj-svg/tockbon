// **Where this one gets the open water from: THE MESH ACTUALLY MOVES, AND THE COLOUR IS READ OFF THE
// HEIGHT IT MOVED TO.**
//
// This is the shape Sea of Thieves ships (SIGGRAPH 2018, Rare): the surface is simulated, and the
// water's colour is **a blend between a deep tone and a lighter one whose mixing weight comes off the
// wave peaks** — the geometry makes a number and the colour spends it. It is also what Bad North's own
// sea is, in Oskar Stalberg's words at Konsoll 2018: *a mesh here that plays this sort of looping wavy
// shader*.
// ⚠ **Sines, not Gerstner, and that is a measured choice somebody else already paid for.** DREDGE
// started on Gerstner waves and went back to sine waves — *they had the unfortunate side effect of
// turning most of our waves into ramps, which launched the boat into the sky*.
//
// ⚠⚠ **The swell is faded out near the rock.** Without it the sea rises through the shore and drops
// below it, and the border — the one thing that must be identical in every picture in this lab — moves.
uniform float swell_h = 0.16;
uniform float swell_len = 8.0;
uniform float swell_len2 = 4.6;
uniform float swell_speed = 0.55;
uniform vec2 swell_dir = vec2(0.80, 0.60);
// **How far the two tones are pushed apart between trough and crest.**
uniform float swell_tone = 0.065;
uniform vec4 swell_deep : source_color = vec4(0.360, 0.510, 0.585, 1.0);
// **Tiles out from the rock over which the swell is allowed to come up to its full height.**
// ⚠⚠ **THE TWO NUMBERS THAT DECIDE WHETHER THIS IS WATER OR FOG.** The first shot ran the tone across
// almost the whole height (0.30 to 0.85) and the sea came out as soft cloud. **Sea of Thieves does not
// fade between its two tones, it masks the PEAKS** — so the window is narrow and sits high.
uniform float swell_edge_a = 0.46;
uniform float swell_edge_b = 0.63;
uniform float swell_hold = 0.7;
uniform float swell_free = 3.2;

// ⚠ `sdf()` samples with `texture()`, which has no gradients in a vertex shader. This is the same read
// with an explicit LOD.
float swell_sdf(vec2 pp) {
	vec2 uv = (pp - field_origin) / max(field_size, vec2(1.0));
	return (textureLod(land_field, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r * 2.0 - 1.0) * field_span
		   + shore_offset;
}

float swell_at(vec2 pp, float t) {
	vec2 d1 = normalize(swell_dir);
	vec2 d2 = normalize(vec2(-d1.y, d1.x) + d1 * 0.45);
	float a = sin(dot(pp, d1) * 6.2831853 / max(swell_len, 0.5) + t * swell_speed);
	float b = sin(dot(pp, d2) * 6.2831853 / max(swell_len2, 0.5) - t * swell_speed * 0.73);
	return a * 0.65 + b * 0.35;
}

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float hold = smoothstep(swell_hold, swell_free, swell_sdf(wp));
	VERTEX.y += swell_at(wp, TIME) * swell_h * 0.5 * hold;
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	float h = swell_at(p, t) * 0.5 + 0.5;
	return mix(swell_deep.rgb, sea.rgb + vec3(swell_tone), smoothstep(swell_edge_a, swell_edge_b, h));
}
