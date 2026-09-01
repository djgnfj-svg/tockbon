// **GENERATED — do not edit. Edit `mech.gdshader` beside it and run `.prototypes/sea/build.py`.**
//
// Everything outside the mechanism block is `src/view/water.gdshader` verbatim: the shipped shoreline,
// spliced in so it cannot differ from any other candidate's. **The only thing this file decides is the
// colour of the open water**, and it decides it in `open_sea()`.
// The sea. **No texture anywhere** — nothing here is bought, downloaded or painted, which is the whole
// reason it is a shader and not an asset.
//
// ⚠ **Every colour and every number arrives as a uniform from `look.gd`.** That file is where this repo
// keeps presentation values and a literal written here would be the one that nobody can find.
//
// ⚠⚠ **THIS FILE WAS REPLACED WHOLE FOR THE SECOND TIME ON 2026-08-29.** On 08-28 forty dials of swell,
// ripple, drawn crests, travelling foam and shallows were thrown away for **a flat sea and one border**
// — Bad North's own answer, stated by its designer at Konsoll 2018: *"most of the water is just
// completely flat, but then at the edge when something meets the water I highlight that instead."*
// **That decision stands and this file does not touch it.** What changed is the border itself:
// **twenty-seven versions of it were built side by side in `.prototypes/swash/` and the user chose
// `27-gaps`.**
//
// **What the chosen border is, and every line of it is something the user judged by eye:**
//
//   1. **Two whites, not one.** A line on the rock, and a second stroke standing about `second_at`
//      tiles off it with dark water between. ⚠⚠ **The second one is a LINE, not a band** — every 거품
//      drawn before it was a soft wash fading outward, and the reference frames have a hard stroke
//   2. **Thin because it is HARD, not because it is narrow.** ⚠⚠ `line_hard` 0.85 is the real answer
//      to 「좀더 얇으면」: a soft edge spends most of its width fading, so it reads thick however narrow
//      it is set. Thinning a soft line makes it faint; hardening it makes it thin
//   3. **Slow** (the user: 「너무 자주 하는데 파형이 좀더 느리게」) — a run about every six seconds
//   4. **A resting width and a surge, kept apart.** `rest_frac` of the line sits on the rock doing
//      nothing and the wave ADDS `surge` on top. ⚠ The version with one width left a trace on screen
//      before any wave arrived (the user: 「미리 흔적이 너무 남아있는느낌이야 기본값이 너무 있어」)
//   5. **It breaks up.** The outer stroke is cut two ways at once — a slow drifting noise gate AND the
//      coast's own curvature — so it is missing off some stretches and absent inside the coves
//   6. **Bays are quiet because they are bays.** The refraction reads the bend of the coast, and the
//      pattern crawls ALONG the shore so a quiet stretch does not stay quiet forever
//
// ⚠⚠ **IT ARGUES WITH THE GLOSSARY AND THAT IS THE DECISION.** `GLOSSARY.md` defined 해안선 as ringing
// the island **without a gap, because the water is always touching the land**. `first_cut` is how much
// of that rule is given up: at 0 the rule holds, at 1 the coast can go bare. **It is deliberately
// partial — the inner line THINS where the outer one is missing and never disappears.** If even that
// reads as a hole in the island, the glossary was right and the answer was `25-broken` or `26-tips`.
shader_type spatial;
// **Unshaded on purpose.** A flat sea that still catches a highlight is not flat, and that highlight was
// the single loudest thing on the sea this replaced.
render_mode unshaded;

// ⚠⚠ **The field is SIGNED**: 0.5 is the baked waterline, below it is land, above it is open sea.
// `shore_offset` is ADDED — it says how far INSIDE the baked line the water plane actually meets the
// rock, and it is 0 now that the bake measures its waterline at the game's own sea height.
uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;
uniform float shore_offset;

uniform vec4 sea : source_color;
uniform vec4 foam : source_color;

// **해안선 at rest**, in tiles, how hard its outer edge is, and how opaque it is.
uniform float line_tiles;
uniform float line_hard;
uniform float line_alpha;

// --- 1. THE SHAPE OF THE LINE, AND IT TRAVELS ---------------------------------------------------
// ⚠⚠ **The warp is read in a frame that slides ALONG the coast** (`run` tiles per second), and two
// copies of it are crossfaded so the pattern never restarts visibly (`cycle` seconds a lap). **This is
// what stops the shore being a ring**: a stretch that is quiet now is a stretch the pattern has not
// reached yet. ⚠ `grad_step` is the stencil the seaward direction is measured with.
uniform float run;
uniform float cycle;
uniform float grad_step;
uniform float warp_a;
uniform float warp_a_scale;
uniform float warp_b;
uniform float warp_b_scale;
uniform float along_scale;

// --- 2. WHERE THE COAST BENDS -------------------------------------------------------------------
// ⚠⚠ **The bend of the coast is measured and the water is given more energy off a point than inside a
// cove.** `curve_step` is the stencil it is measured with, and **it cannot see a bend smaller than
// about that many tiles** — which is why it is the first number to re-judge whenever the island's
// outline starts turning on a different unit.
uniform float curve_step;
uniform float refract_amt;
uniform float point_gain;
uniform float bay_floor;

// --- 3. THE RUN, AND THE WIDTH IT ADDS ----------------------------------------------------------
// ⚠ `rate` is how often a run comes and `rise_frac` is how much of that cycle is the water coming UP;
// the rest is it draining back. `swash` is how far up the rock it reaches, in tiles.
uniform float rate;
uniform float swash;
uniform float rise_frac;
// ⚠⚠ **`rest_frac` IS THE WHOLE POINT OF THIS SET.** It is what fraction of `line_tiles` is on the rock
// when nothing is happening; `surge` is what the arriving wave ADDS on top, in multiples of the same.
// **Below `rest_frac` there is no line at all**, and `surge` rides the run so it is zero for most of
// the cycle. `rest_shape` is how much the bay/point energy is allowed to thin the RESTING line.
uniform float rest_frac;
uniform float surge;
uniform float rest_shape;

// --- 4. THE SECOND WHITE ------------------------------------------------------------------------
// ⚠ `second_w` is a STROKE width, not a band: keep it at or under the resting line or the two whites
// stop reading as two.
uniform float second_at;
uniform float second_w;
uniform float second_amt;

// --- 5. THE CUTS --------------------------------------------------------------------------------
// **How long a surviving piece is** (`cut_scale` is inverted tiles — bigger is shorter), how fast the
// pattern of gaps drifts, and where it switches. ⚠ `cut_shut` and `cut_open` close together is a clean
// break; far apart is a fade, and a fade is a dimming rather than a gap.
uniform float cut_scale;
uniform float cut_drift;
uniform float cut_shut;
uniform float cut_open;
// **Where the second line is allowed to exist at all**, in units of the refraction's energy. Energy
// runs from `bay_floor` in a cove to `point_gain` off a headland, so raising `tip_at` walks the second
// white back toward the points and out of the bays.
uniform float tip_at;
uniform float tip_full;
// ⚠⚠ **How much the drifting gate is allowed to thin the line ON THE ROCK.** See the head of this file
// before raising it — this is the number that argues with the glossary.
uniform float first_cut;

// --- 6. WHERE THE COAST IS QUIET ----------------------------------------------------------------
// ⚠ A wide, slow patch map, so some stretches are busy and others nearly still. Without it every part of
// the shore is equally lively, which is its own kind of ring.
uniform float calm;
uniform float calm_scale;
uniform float calm_speed;

// --- 7. THE HULLS: the trail behind one and the mark round it, AND THEY ARE ONE SHAPE -----------
// **Chosen by eye out of nine candidates** (2026-08-30, `.prototypes/wake/`): **one fading line
// straight down the track, no V.** The water draws it itself out of where the boat has been — there
// is no buffer, no trail geometry, nothing with a resolution and nothing with an extent, so a hull
// that sails off the side of the world costs exactly what one standing still costs.
//
// ⚠⚠ **ONE BLOCK OF `WAKE_SLOTS` PER HULL, AND EVERY SLOT IS A POINT ON THE TRANSOM'S OWN TRACK.**
// Slot 0 is where that transom is NOW and carries the hull's heading in `w`; the rest are where it
// has been, newest first. **A slot with a negative time was never written** — the view's clock never
// goes below zero — and the trail loop stops at the first one, because the view fills them upward.
// ⚠ **The contact marks read slot 0 and step FORWARD off it** to find the hull's middle, which is
// the one place this file turns a transom back into a boat.
// ⚠ The remembered points carry no heading because the chosen candidate needs none. **The V does** —
// see `look.gd`'s note about the player's own boat — and it would want the yaw back in `w`.
//
// ⚠⚠ **THE TWO LENGTHS ARE WRITTEN HERE AND IN `look.gd` AND CANNOT BE DERIVED FROM ONE PLACE.** A
// GLSL array's length is a compile-time number, so it cannot arrive as a uniform. **`net_wake` reads
// this file's own text and compares the two**, which is the whole of what keeps them together.
const int WAKE_HULLS = 12;
const int WAKE_SLOTS = 8;
const int WAKE_MAX = 96;
uniform vec4 wake_hull[WAKE_MAX];
// ⚠⚠ **THE VIEW'S OWN CLOCK, AND NOT `TIME`.** Every slot is stamped against it, so a trail aged
// against the engine's clock instead would fade by however far the two happen to stand apart — which
// is however long the game sat on the title screen.
uniform float wake_t;
uniform float wake_life;
// How far astern of the hull's middle a trail is born. **Negative.**
uniform float wake_stern;
uniform float wake_w;
uniform float wake_hard;
uniform float wake_alpha;
uniform float wake_froth_scale;
uniform float wake_froth_amt;

// The hull's own footprint in 조각: half its length along the bow, and half its beam across.
uniform float hull_half;
uniform float hull_beam;
// **1. The shadow in the water the hull displaces**, thickest at the beam and wider toward the bow.
uniform float hull_shadow_w;
uniform float hull_shadow_bow;
uniform vec4 hull_shadow_col : source_color;
// **2. The thin bright break standing just outside it**, and how much brighter it is at the bow.
uniform float hull_break_at;
uniform float hull_break_w;
uniform float hull_break_amt;
uniform float hull_break_bow;
// **3. The shallow-looking halo**, and how much further it reaches astern than forward.
uniform float hull_halo_tiles;
uniform float hull_halo_amt;
uniform float hull_halo_aft;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

// **Distance to the coast in tiles**, negative on land. ⚠ `shore_offset` is added here and nowhere else,
// so every reader below — both whites and the run — moves together when it moves.
float sdf(vec2 p) {
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	return (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span
		   + shore_offset;
}

vec2 seaward(vec2 p) {
	float e = max(grad_step, 0.001);
	vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)),
				  sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
	return length(g) < 1e-5 ? vec2(0.0, 1.0) : normalize(g);
}

float bend(vec2 p) {
	float e = max(curve_step, 0.01);
	float c = sdf(p);
	float s = sdf(p + vec2(e, 0.0)) + sdf(p - vec2(e, 0.0))
			+ sdf(p + vec2(0.0, e)) + sdf(p - vec2(0.0, e)) - 4.0 * c;
	return s / (e * e);
}

// The shape of one run: up fast, back slowly.
float wash(float x, float r) {
	r = clamp(r, 0.05, 0.95);
	float u = x < r ? x / r : 1.0 - (x - r) / (1.0 - r);
	return smoothstep(0.0, 1.0, u);
}

vec2 layer(vec2 p, vec2 tang, float age) {
	vec2 q = p - tang * (age * run);
	float w = (vnoise(q * warp_a_scale) - 0.5) * 2.0 * warp_a
			+ (vnoise(q * warp_b_scale + vec2(37.0, 11.0)) - 0.5) * 2.0 * warp_b;
	float along = vnoise(q * along_scale + vec2(11.0, 5.0));
	return vec2(w, along);
}

// Distance from `p` to the segment `a`..`b`, with where along it the nearest point fell.
//
// ⚠⚠ **THE TRAIL IS THE SEGMENT BETWEEN TWO REMEMBERED POINTS AND NOT A DOT AT EACH, AND THAT COST A
// ROUND IN THE LAB.** A dot's falloff reaches nothing exactly where the next one starts, whatever its
// radius, so widening it thickened the line without closing the gaps and left a fine beading down it.
float wake_seg(vec2 p, vec2 a, vec2 b, out float u) {
	vec2 e = b - a;
	float l2 = dot(e, e);
	u = l2 > 1e-8 ? clamp(dot(p - a, e) / l2, 0.0, 1.0) : 0.0;
	return length(p - (a + e * u));
}

// **How far outside the hull's own outline a point is, in 조각**, negative inside. `q` is in the
// hull's frame: +x along the bow, +y across the beam.
//
// ⚠ **The outline is the ELLIPSE of the hull's box.** The real bow is pointed and this is not; at the
// widths these three marks are drawn the difference is under a tenth of a 조각, and a mark wrong by a
// tenth of a 조각 at the stem is not what「a sticker laid on the sea」 was about.
float hull_out(vec2 q) {
	float a = max(hull_half, 0.001);
	float b = max(hull_beam, 0.001);
	vec2 e = vec2(q.x / a, q.y / b);
	float k = length(e);
	if (k < 1e-4) {
		return -min(a, b);
	}
	// First order: the implicit function over the length of its own gradient.
	vec2 g = vec2(e.x / a, e.y / b) / k;
	return (k - 1.0) / max(length(g), 1e-5);
}

// **Everything the water does about the boats.**
//
// ⚠ `cut` is the coast's own drifting gate, handed in rather than worked out a second time: **the
// same thing that breaks the outer white on the rock breaks the bright line round a hull**, so one
// place decides where a white is missing.
vec3 hulls(vec3 base, vec2 p, float cut) {
	float white = 0.0;
	float dark = 0.0;
	float halo = 0.0;
	for (int h = 0; h < WAKE_HULLS; h++) {
		int at0 = h * WAKE_SLOTS;
		vec4 now = wake_hull[at0];
		// A hull not on the board was never written, and the view's clock never goes negative.
		if (now.z < 0.0) {
			continue;
		}
		vec2 fwd = vec2(cos(now.w), sin(now.w));
		vec2 side = vec2(-fwd.y, fwd.x);
		// Slot 0 is the transom; the hull's middle is one stern offset FORWARD of it.
		vec2 mid = now.xy - fwd * wake_stern;
		vec2 rel = p - mid;
		vec2 q = vec2(dot(rel, fwd), dot(rel, side));

		// --- the bow half: the three marks at the join -------------------------------------------
		float out_d = max(hull_out(q), 0.0);
		// Where along the hull this point lies: -1 at the transom, +1 at the stem.
		float along = clamp(q.x / max(hull_half, 0.001), -1.0, 1.0);
		// **The beam's own profile** — 1 amidships, 0 at both tips. This is what thins the shadow to
		// nothing at the bow and at the stern.
		float beamy = sqrt(max(1.0 - along * along, 0.0));
		float fore = clamp(along, 0.0, 1.0);

		float sw = max(hull_shadow_w * beamy * (1.0 + hull_shadow_bow * fore), 1e-4);
		dark = max(dark, 1.0 - smoothstep(sw * line_hard, sw, out_d));

		// ⚠ Measured off the SHADOW's own edge, so the dark water between the two stays one width
		// wherever the shadow is thick and wherever it is thin.
		float br = 1.0 - smoothstep(hull_break_w * line_hard, hull_break_w,
									abs(out_d - (sw + hull_break_at)));
		white = max(white, br * hull_break_amt * cut * (1.0 + hull_break_bow * fore));

		// ⚠⚠ **THE HALO REACHES FURTHER ASTERN, AND THAT IS WHAT MAKES THIS ONE SHAPE WITH THE
		// TRAIL** rather than two marks that happen to touch.
		float reach = max(hull_halo_tiles
						  * mix(1.0 + hull_halo_aft, 1.0, along * 0.5 + 0.5), 1e-4);
		halo = max(halo, hull_halo_amt * (1.0 - smoothstep(0.0, reach, out_d)));

		// --- the stern half: one line down the track ---------------------------------------------
		vec2 a = now.xy;
		float ta = now.z;
		for (int k = 1; k < WAKE_SLOTS; k++) {
			vec4 s = wake_hull[at0 + k];
			if (s.z < 0.0) {
				break;
			}
			float u;
			float d = wake_seg(p, a, s.xy, u);
			// ⚠⚠ **THE AGE IS READ AT THE POINT AND NOT AT THE SAMPLE, AND IT IS THE ONE PLACE THIS
			// DIFFERS FROM THE LAB.** The lab held ninety-six samples for one boat and could afford
			// one age each; a block of eight cannot, and a per-sample fade ends the tail on a step
			// wherever the oldest live sample happens to sit. **Read along the segment, the trail
			// ends exactly where the age reaches `wake_life`**, whatever the slots are doing.
			float fade = clamp(1.0 - (wake_t - mix(ta, s.z, u)) / max(wake_life, 0.001), 0.0, 1.0);
			white = max(white, fade * (1.0 - smoothstep(wake_w * wake_hard, wake_w, d)));
			a = s.xy;
			ta = s.z;
			// ⚠⚠ **THE EXPIRED SAMPLE IS DRAWN AND THEN THE LOOP STOPS.** Slots are newest-first, so
			// everything past the first expired one is expired too and adds nothing — but the expired
			// one itself is where the tail's fade reaches zero, so breaking BEFORE it would cut the tail
			// off at whatever the last live sample happened to be. **This is cost and not picture**: an
			// arrived hull sits on the beach for the rest of the island and pays two iterations here
			// instead of seven.
			if (wake_t - s.z > wake_life) {
				break;
			}
		}
	}
	// The noise that breaks the white up — the trail and the bright break both, because they are one
	// white and one rule for when it is missing.
	white *= mix(1.0, vnoise(p * wake_froth_scale), wake_froth_amt);
	// Widest and weakest first, then the dark, then the white over both.
	vec3 c = mix(base, foam.rgb, clamp(halo, 0.0, 1.0));
	c = mix(c, hull_shadow_col.rgb, clamp(dark, 0.0, 1.0) * hull_shadow_col.a);
	return mix(c, foam.rgb, clamp(white, 0.0, 1.0) * wake_alpha);
}



// --- THE OPEN WATER: the one thing this candidate decides ---
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


void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);
	vec2 n = seaward(p);
	vec2 tang = vec2(-n.y, n.x);

	// Two copies of the travelling pattern, half a lap apart, crossfaded — so it never restarts.
	float c = max(cycle, 0.1);
	float k = abs(1.0 - 2.0 * fract(t / c));
	vec2 l0 = layer(p, tang, fract(t / c) * c);
	vec2 l1 = layer(p, tang, fract(t / c + 0.5) * c);
	float w = mix(l0.x, l1.x, k);
	float along = mix(l0.y, l1.y, k);

	// How much energy this stretch of coast gets: a cove is quiet, a headland is loud.
	float kb = clamp(bend(p) * 0.5, -1.0, 1.0);
	float energy = mix(1.0, mix(bay_floor, point_gain, kb * 0.5 + 0.5), refract_amt);

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// This stretch's own place in the run, read ALONG the coast so neighbours are out of step.
	float x = fract(t * rate + along);
	float up = wash(x, rise_frac);
	float draining = step(rise_frac, x);

	float ds = d + w - up * swash * energy * live;

	// **The line on the rock.**
	float rest = max(line_tiles, 0.0001) * rest_frac * mix(1.0, energy, rest_shape);
	float bw = rest + max(line_tiles, 0.0001) * surge * up * energy * live;
	float band = 1.0 - smoothstep(bw * line_hard, bw, ds);
	band *= mix(1.0, 0.72, draining * (1.0 - up));

	// **THE SECOND LINE, AND IT IS THE REFERENCE'S OWN SHAPE.** In the frames the user sent, the coast
	// wears two whites: one against the stone and one standing a little way off it, with dark water
	// between them. ⚠⚠ **It is a LINE, not a band** — a crisp stroke at a fixed distance, not a soft
	// wash — which is why it reads as thin at a width the wash would read as thick at.
	// ⚠ It breathes with the wave rather than travelling: the gap opens as the water comes up.
	float at = second_at * mix(0.82, 1.24, up);
	float w2 = max(second_w, 0.0005);
	float line2 = 1.0 - smoothstep(w2 * line_hard, w2, abs(ds - at));
	line2 *= second_amt * clamp(energy, 0.0, 1.3) * live;
	// Both cuts on the outer white: arbitrary drifting gaps, and only off the points.
	float cut = smoothstep(cut_shut, cut_open,
						   vnoise(p * cut_scale + vec2(t * cut_drift, -t * cut_drift * 0.7)));
	line2 *= cut * smoothstep(tip_at, tip_full, energy);
	// ⚠ And the inner line thins with the same gate — never to nothing.
	band *= mix(1.0 - first_cut, 1.0, cut);

	vec3 col = mix(open_sea(p, d, t, FRAGCOORD.xy), foam.rgb, clamp(max(band, line2) * line_alpha, 0.0, 1.0));
	// **And then the boats, because the water knows they are there.** See section 7.
	ALBEDO = hulls(col, p, cut);
}
