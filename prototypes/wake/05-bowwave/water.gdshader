// **GENERATED — do not edit. Edit `mech.gdshader` beside it and run `prototypes/wake/build.py`.**
//
// Everything outside the mechanism block is `src/view/water.gdshader` verbatim: the shipped flat sea
// and the shipped 해안선, spliced in so they cannot differ from any other candidate's. **The only
// thing this file decides is what happens to the water behind the boat**, in `wake()`.
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
// **twenty-seven versions of it were built side by side in `prototypes/swash/` and the user chose
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
// ⚠⚠ **IT ARGUES WITH THE GLOSSARY AND THAT IS THE DECISION.** `CONTEXT.md` defined 해안선 as ringing
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


// --- THE WAKE: the one thing this candidate decides ---
// **05-bowwave draws nothing in the water.** Everything it has is a mesh on the boat, so the sea it
// sits on has to be the untouched one.
vec3 wake(vec3 base, vec2 p, float t) { return base; }


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

	vec3 base = mix(sea.rgb, foam.rgb, clamp(max(band, line2) * line_alpha, 0.0, 1.0));
	ALBEDO = wake(base, p, t);
}
