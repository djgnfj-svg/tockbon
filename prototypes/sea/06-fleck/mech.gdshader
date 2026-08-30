// **Where this one gets the open water from: DISCRETE THINGS YOU CAN COUNT.**
//
// Not a field and not a pattern — **a lattice with at most one object per cell**, each at its own
// jittered spot with its own size, and the whole scatter sliding as one current. The eye is given
// something to measure the boat against rather than something to look at.
//
// ⚠⚠ **THIS IS THE ONE THING THE 2026-08-29 ROUND NEVER TRIED.** All ten of those were continuous —
// noise, facets, bands, dither, light. The user's word for what came back was **「자글자글」**, which is
// what a continuous field at any scale eventually reads as. **A countable object cannot be 자글자글:
// there are sixteen of them in the frame and you can point at one.**
//
// ⚠ **`fleck_fill` is what keeps it sparse.** Every cell that draws one is a cell whose hash fell
// under it, so at 0.55 nearly half the lattice is bare water and the scatter has no visible grid.
// **At 1.0 it IS a grid** and that is the failure to watch for.
//
// ⚠ **The radius is in 조각 and not in cells.** At the opening framing one 조각 is 30 screen px, so the
// smallest of these is ten px across and the largest a third of a 조각 — legible from the far camera,
// which is the axis the last round died on.
uniform vec4 fleck_col : source_color = vec4(0.855, 0.905, 0.930, 1.0);
// **조각 per lattice cell** — one object's worth of room. 7.0 puts about sixteen in the frame.
uniform float fleck_cell = 7.0;
// **What fraction of cells carry one.** See above: this is the dial that stops it being a grid.
uniform float fleck_fill = 0.55;
// **How big one is, in 조각**, and where its soft edge starts as a fraction of that.
uniform float fleck_r_min = 0.35;
uniform float fleck_r_max = 1.10;
uniform float fleck_hard = 0.25;
uniform float fleck_amt = 0.11;
// **The whole scatter drifts as one body of water**, in 조각 per second.
uniform vec2 fleck_current = vec2(-0.055, -0.030);

// ⚠⚠ **THE LAB'S OWN CLOCK AND NOT `TIME`.** `TIME` keeps running between one candidate's photograph
// and the next, so six pictures would be six different instants. `open_lab.gd` writes this.
uniform float lab_t = 0.0;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	float cell = max(fleck_cell, 0.5);
	vec2 q = (p - fleck_current * lab_t) / cell;
	vec2 c = floor(q);
	float v = 0.0;
	// The nine cells around this pixel — an object near a cell edge reaches into its neighbour.
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cc = c + vec2(float(i), float(j));
			if (h21(cc) > fleck_fill) {
				continue;
			}
			vec2 off = vec2(h21(cc + vec2(3.7, 1.1)), h21(cc + vec2(9.2, 4.4)));
			float rad = mix(fleck_r_min, fleck_r_max, h21(cc + vec2(17.0, 23.0)));
			float dd = length((q - (cc + off)) * cell);
			v = max(v, 1.0 - smoothstep(rad * fleck_hard, rad, dd));
		}
	}
	return mix(sea.rgb, fleck_col.rgb, clamp(v, 0.0, 1.0) * fleck_amt);
}
