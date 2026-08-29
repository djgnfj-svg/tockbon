// **07 — THE LINE IS MADE OF CLUMPS, NOT OF A BAND.** The one candidate here that changes what the
// foam IS rather than how it moves.
//
// **Where it comes from.** Both of the stylised-water writeups found for this round build their foam
// the same way: a warped, animated Voronoi, masked by depth — organic clumps with bubbles inside them
// and darker edges, rather than a width. Crest does the same thing from the other end, generating foam
// where the water is shallow and where crests are steep.
//
// **The claim being tested.** 01's line is a distance thresholded — geometrically a perfect offset
// curve, and **an offset curve is the one shape water never makes.** Break the band up with cells that
// are born, spread and dissolve and the line stops reading as traced even when it barely moves.
//
// ⚠⚠ **THIS IS THE CANDIDATE MOST LIKELY TO LOSE ON THE GAME'S OWN GROUND, AND IT IS HERE ANYWAY.**
// The island already rejected a busier sea twice — seven candidates on one block, then 거품 added back
// and removed the same day (「별로다... 그 거품없애봐」). Clumps are texture, and *"expressing things in
// borders and not in… textures"* is the sentence the whole sea was rebuilt around. **A candidate that
// loses for a reason already on record is still worth photographing once**, because the reason is
// about the shipped sea and this is a different mechanism.
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

/// **How wide the clumping band is**, in tiles — the stretch of water the cells may live in.
uniform float clump_tiles = 0.34;
/// How big one cell is, in inverted tiles. Bigger number, smaller clumps.
uniform float cell_scale = 5.5;
/// How fast the cells churn, and how far the noise warp drags them off a regular lattice.
uniform float cell_speed = 0.30;
uniform float warp = 0.55;
uniform float warp_scale = 1.6;
/// **How much of the band is eaten by the cells.** At 0 this is a plain band; at 1 only the cell cores
/// survive and the line is a string of islands.
uniform float bite = 0.80;
/// The hairline that survives whatever the cells do. ⚠ Never 0: water is always touching the rock.
uniform float keep_line = 0.55;

uniform float rate = 0.42;
uniform float swash = 0.16;
uniform float rise_frac = 0.22;
uniform float along_scale = 0.55;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

/// **Distance to the nearest cell centre**, with the centres drifting on their own clocks. This is the
/// clumping; everything else in this file is the band it is cut out of.
float voro(vec2 p, float t) {
	vec2 i = floor(p), f = fract(p);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			// Each centre wanders its own way, so cells are born and swallowed rather than sliding.
			o = 0.5 + 0.5 * sin(t * cell_speed * 6.2831853 + 6.2831853 * o);
			best = min(best, length(g + o - f));
		}
	}
	return best;
}

float sdf(vec2 p) {
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	return (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;
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

	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float up = wash(fract(t * rate + along), rise_frac);
	float ds = d - up * swash;

	// The band the clumps may live in: widest at the rock, gone by `clump_tiles` out.
	float in_band = 1.0 - smoothstep(0.0, max(clump_tiles, 0.001), ds);

	// The clumps themselves, on a warped lattice so they are not a grid.
	vec2 q = p + vec2(vnoise(p * warp_scale + vec2(t * 0.05, 0.0)) - 0.5,
					  vnoise(p * warp_scale + vec2(9.0, 4.0) - vec2(0.0, t * 0.05)) - 0.5) * warp;
	float v = voro(q * cell_scale, t);
	// Cores bright, edges dark — the second Voronoi sample the writeups use for thickness, folded in.
	float cells = 1.0 - smoothstep(0.10, 0.62, v);

	float clumped = in_band * mix(1.0, cells, bite);

	// The hairline that is always there, whatever the cells are doing.
	float bw = max(line_tiles, 0.0001);
	float line = (1.0 - smoothstep(bw * line_hard, bw, ds)) * keep_line;

	float f = clamp(max(clumped, line) * line_alpha, 0.0, 1.0);
	ALBEDO = mix(sea.rgb, foam.rgb, f);
}
