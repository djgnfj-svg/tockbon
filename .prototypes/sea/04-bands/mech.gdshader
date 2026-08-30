// **Where this one gets the open water from: HOW FAR THE LAND IS, CUT INTO HARD STEPS.**
//
// Alexander Ameye's stylised-water breakdown builds the sea's colour out of a **world-space depth
// fade** between a shallow tone and a deep one, then runs **Posterize** over it so the fade becomes a
// few hard bands; he names A Short Hike as the shipped example of that look, and A Short Hike's author
// confirms his water reads its shore *using the depth buffer*.
//
// ⚠⚠ **THIS IS THE ONE THAT CANNOT ANSWER THE QUESTION AS ASKED, AND IT IS IN THE SET TO BE SEEN
// FAILING.** The baked field reaches `WATER_FIELD_SPAN_TILES` — four tiles — and then saturates. Past
// that there is no land to be far from, so **every pixel of the open sea falls in the last band and the
// far water is one flat colour again**, which is exactly where the question started.
// ⚠ It is also close to 여울, which was switched on once (2026-08-28) and taken straight back out for
// wearing the island as a halo.
uniform vec4 shoal : source_color = vec4(0.560, 0.700, 0.745, 1.0);
uniform vec4 deep : source_color = vec4(0.355, 0.505, 0.580, 1.0);
uniform float band_reach = 3.6;
uniform float band_steps = 4.0;
// ⚠ **How much a step's edge wanders.** At 0 the bands are rings round the island, and a ring is the
// thing every reference goes out of its way to avoid.
uniform float band_wob = 0.35;
uniform float band_wob_scale = 0.42;
uniform float band_drift = 0.03;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	float dd = d + (vnoise(p * band_wob_scale + vec2(t * band_drift, -t * band_drift)) - 0.5)
					* 2.0 * band_wob;
	float x = clamp(dd / max(band_reach, 0.01), 0.0, 1.0);
	float q = floor(x * band_steps) / max(band_steps - 1.0, 1.0);
	return mix(shoal.rgb, deep.rgb, clamp(q, 0.0, 1.0));
}
