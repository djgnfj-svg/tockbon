// **Where this one gets the open water from: A LATTICE OF FLAT CELLS, EACH ONE FLAT TONE.**
//
// Nothing is drawn ON the water; the water is **made of** pieces, the way the island is. Every cell is
// one tone, two cells meet at a hard edge, and a cell drifts slowly between two tones of its own. The
// whole board is already faceted — the island is flat-shaded blocks — so this is the sea answering in
// the island's own language rather than in a shader's.
//
// ⚠ **The cell is split on its diagonal**, so the lattice reads as triangles and not as tiles. A square
// grid laid on water reads as a chessboard, which is the one thing it must not read as.
// ⚠⚠ **THE LATTICE IS TURNED OFF THE ISLAND'S OWN AXES, AND THE FIRST SHOT PROVES WHY.** Square on,
// the cells lined up with the coast and the sea read as a **tiled floor** — the exact chessboard this
// was supposed to avoid. The turn and the skew below are what stop a row of cells ever running parallel
// to an edge of the island.
// ⚠⚠ **AND TURNING IT WAS NOT ENOUGH.** Turned 24 degrees the cells still ran in dead-straight rows and
// the sea read as graph paper on the diagonal. **A lattice has to be BENT before it stops being a
// lattice**: `facet_warp` pushes the lookup around with a slow noise before it is floored, so a row of
// cells wanders instead of running.
uniform float facet_warp = 0.55;
uniform float facet_warp_scale = 0.11;
uniform float facet_turn = 0.42;
uniform float facet_skew = 0.30;
uniform float facet_tiles = 2.6;
// **How far apart the tones are pushed.** ⚠ The whole dial between 「물결이 좀 있다」 and 「대리석」.
uniform float facet_spread = 0.085;
uniform float facet_speed = 0.55;
// **A darker hairline where two cells meet**, in cell units. 0 is no seam at all.
uniform float facet_seam = 0.045;
uniform float facet_seam_amt = 0.5;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	float ca = cos(facet_turn);
	float sa = sin(facet_turn);
	vec2 pr = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
	pr.x += pr.y * facet_skew;
	pr += vec2(vnoise(pr * facet_warp_scale) - 0.5,
			   vnoise(pr * facet_warp_scale + vec2(23.0, 9.0)) - 0.5) * 2.0 * facet_warp
		  * max(facet_tiles, 0.05);
	vec2 g = pr / max(facet_tiles, 0.05);
	vec2 c = floor(g);
	vec2 f = fract(g);
	float lower = step(f.x + f.y, 1.0);
	float r = h21(c + vec2(lower * 37.0, lower * 11.0));
	float wob = sin(t * facet_speed + r * 6.2831853) * 0.5 + 0.5;
	float tone = (r * 0.6 + wob * 0.4 - 0.5) * facet_spread;
	vec3 col = sea.rgb + vec3(tone);
	float border = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float diag = abs(f.x + f.y - 1.0) * 0.70710678;
	float edge = 1.0 - smoothstep(0.0, max(facet_seam, 0.0005), min(border, diag));
	return col - vec3(edge * facet_seam_amt * facet_spread);
}
