// **Where this one gets the open water from: THE THINGS THAT ARE IN IT, AND NOWHERE ELSE.**
//
// The sea has no surface of its own. It reacts — it lifts against the island, and every hull sends
// rings out across it. **Away from land and away from a boat it is the shipped flat colour, exactly.**
//
// **The hypothesis it is here to test**: the complaint 「물이 좀 너무 없긴하다」 was made watching a boat
// cross an empty sea, and it may be that the water does not need filling so much as it needs to
// ANSWER the things on it. If that is right, this is the whole fix and it costs nothing anywhere else.
//
// ⚠⚠ **AND IT IS THE ONE CANDIDATE BUILT TO FAIL IN THE `out` FRAME.** Twenty 조각 out with no boat in
// shot it draws nothing at all, because there is nothing for it to be near. **That is not a bug to fix
// — it is the measurement.** If the sheet says the `out` frame is fine anyway, presence was enough.
//
// ⚠⚠ **THE LAND HALF CANNOT REACH PAST FOUR 조각 AND THAT IS THE SHIPPED FIELD'S OWN LIMIT.** `sdf`
// clamps at ±`field_span`, so `d` is 4.0 everywhere from four 조각 out to the horizon. Widening it is
// not a dial: it is a change to how the island is baked. `04-bands` died here on 2026-08-29 and this
// one is deliberately built INSIDE that limit rather than against it.
uniform vec4 near_col : source_color = vec4(0.855, 0.905, 0.930, 1.0);
// **How far the water lifts off the rock, in 조각, and how much.** ⚠ See above: 4.0 is the ceiling.
uniform float near_land_reach = 3.6;
uniform float near_land_amt = 0.10;
// **The rings a hull sends out**: how far they reach in 조각, how far apart they stand, how many leave
// the hull each second, and how strong they are.
uniform float near_ring_reach = 9.0;
uniform float near_ring_len = 2.6;
uniform float near_ring_speed = 0.45;
uniform float near_ring_amt = 0.13;

// ⚠⚠ **THE LAB'S OWN CLOCK AND NOT `TIME`.** See `06-fleck`.
uniform float lab_t = 0.0;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	// **1. The island pushes the water out.** Outside the 해안선 and dying where the field does.
	float g = 1.0 - smoothstep(0.0, max(near_land_reach, 0.01), max(d, 0.0));
	vec3 c = mix(sea.rgb, near_col.rgb, g * near_land_amt);

	// **2. Every hull sends rings across the sea.** ⚠ Read off slot 0 of each block and stepped
	// forward off the transom to the hull's middle — the same turn `hulls()` makes, for the same
	// reason: the rings leave the boat, not its wake.
	float m = 0.0;
	for (int h = 0; h < WAKE_HULLS; h++) {
		vec4 now = wake_hull[h * WAKE_SLOTS];
		if (now.z < 0.0) {
			continue;
		}
		vec2 fwd = vec2(cos(now.w), sin(now.w));
		vec2 mid = now.xy - fwd * wake_stern;
		float r = length(p - mid);
		float ph = r / max(near_ring_len, 0.05) - lab_t * near_ring_speed;
		float ring = 0.5 - 0.5 * cos(ph * 6.2831853);
		m = max(m, ring * (1.0 - smoothstep(0.0, max(near_ring_reach, 0.01), r)));
	}
	return mix(c, near_col.rgb, clamp(m, 0.0, 1.0) * near_ring_amt);
}
