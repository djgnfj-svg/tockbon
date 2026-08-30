// **THE ONE MECHANISM THE 04 SHEET IS MADE OF, AND THERE IS EXACTLY ONE COPY OF IT.**
//
// The water shader draws the wake itself out of the boat's own history. No buffer, no geometry,
// nothing with a resolution and nothing with an extent. Every `04x` folder includes this file and
// changes only numbers — see `kelvin.gd` for where those numbers live.
//
// **What it evaluates is a Kelvin wake.** Every moment the hull throws off a ring that spreads at
// `sin(19.47°)` of the boat's own speed. The transverse crests ARE those rings; the two straight arms
// are the line the rings are all tangent to.
//
// ⚠⚠ **AN ARM IS NOT A LINE DRAWN FROM A SAMPLE, AND THAT COST A ROUND.** Written that way — each
// remembered moment drawing its own V — the picture is a dozen nested Vs, because two samples a boat's
// length apart draw two parallel arms rather than the same arm. **The envelope touches each ring at
// exactly two points**, at `acos(c/v)` off the heading, and the arm is the run of those points.
//
// ⚠⚠ **AND THE ARM IS THE SEGMENT BETWEEN TWO OF THOSE POINTS, NOT A DOT AT EACH.** Dots left a fine
// beading along both arms — a dot's falloff reaches nothing exactly where the next one starts, whatever
// its radius, so widening it thickened the arm without closing the gaps. **Measuring to the segment
// joining consecutive envelope points removes it outright** and makes `wake_arm_w` an honest stroke
// half-width rather than a dot radius that has to be tuned against the sample rate.
const int WAKE_MAX = 96;
// **xy is where, z is when, w is the heading in radians.** Oldest first.
uniform vec4 wake_hist[WAKE_MAX];
uniform int wake_n;
uniform float wake_t;
uniform float wake_speed;
// The sine of the Kelvin half angle: how fast a ring spreads, as a fraction of the boat's speed.
uniform float wake_sin;

// --- the dials, and every one of them is what this sheet is choosing between --------------------
// **How long a mark lives, in seconds.** The whole length of the tail.
uniform float wake_life;
// **The two arms**: how bright, how wide (a stroke HALF-width, in 조각), and where the soft edge starts
// as a fraction of that width — 1.0 is a hard edge, 0.0 fades the whole way in.
uniform float wake_arm_amt;
uniform float wake_arm_w;
uniform float wake_arm_hard;
// **The transverse crests**: how bright, how thick, and which samples draw one. `wake_crest_hz` and
// `wake_crest_pick` are derived from one dial, `crest_every` — see `kelvin.gd`. **At amount 0 there
// are no crests at all**, which is the first thing 「simpler」 means.
uniform float wake_crest_amt;
uniform float wake_crest_w;
uniform float wake_crest_hz;
uniform float wake_crest_pick;
// **One line straight down the track**, instead of or as well as the V. Half-width in 조각.
uniform float wake_centre_amt;
uniform float wake_centre_w;
// The noise that breaks the white up, so this candidate is judged on its shape and not on being clean.
uniform float wake_froth_scale;
uniform float wake_froth_amt;
// **Overall opacity lives in the colour's alpha.** ⚠ It is the dial that makes a picture quieter
// without taking any shape out of it.
uniform vec4 wake_col : source_color;

float wake_seg(vec2 p, vec2 a, vec2 b) {
	vec2 e = b - a;
	float l2 = dot(e, e);
	float u = l2 > 1e-8 ? clamp(dot(p - a, e) / l2, 0.0, 1.0) : 0.0;
	return length(p - (a + e * u));
}

vec3 wake(vec3 base, vec2 p, float t) {
	float a = 0.0;
	float sphi = sqrt(max(1.0 - wake_sin * wake_sin, 0.0));
	// The previous sample's two envelope points and its own place, carried across the loop so the
	// heading's trig is done once per sample rather than twice.
	vec2 pq0 = vec2(0.0);
	vec2 pq1 = vec2(0.0);
	vec2 ppos = vec2(0.0);
	bool have = false;
	for (int i = 0; i < wake_n; i++) {
		vec4 h = wake_hist[i];
		float age = wake_t - h.z;
		bool live = age >= 0.0 && age <= wake_life;
		vec2 fwd = vec2(cos(h.w), sin(h.w));
		vec2 perp = vec2(-fwd.y, fwd.x);
		// The ring this moment threw off, and the two points the envelope touches it at. **At age zero
		// they are the hull itself**, which is why the V has its apex on the transom.
		float r = wake_sin * wake_speed * age;
		vec2 q0 = h.xy + r * (wake_sin * fwd + sphi * perp);
		vec2 q1 = h.xy + r * (wake_sin * fwd - sphi * perp);
		if (live) {
			float fade = 1.0 - age / wake_life;
			if (have && wake_arm_amt > 0.0) {
				float d = min(wake_seg(p, pq0, q0), wake_seg(p, pq1, q1));
				a = max(a, wake_arm_amt * fade
						  * (1.0 - smoothstep(wake_arm_w * wake_arm_hard, wake_arm_w, d)));
			}
			if (have && wake_centre_amt > 0.0) {
				float d = wake_seg(p, ppos, h.xy);
				a = max(a, wake_centre_amt * fade
						  * (1.0 - smoothstep(wake_centre_w * wake_arm_hard, wake_centre_w, d)));
			}
			// **The rear arc of this ring, and only the rear arc.**
			//
			// ⚠⚠ **A WEDGE TEST CANNOT CUT THIS RING AND THAT COST A ROUND.** The ring is tangent to
			// the arms from the inside, so ALL of it is inside the V and a "keep what is inside the V"
			// mask keeps the whole circle — which put full circles across open water either side of the
			// wake. **The cut is the tangency angle itself.**
			if (wake_crest_amt > 0.0 && fract(h.z * wake_crest_hz) < wake_crest_pick) {
				vec2 rel = p - h.xy;
				float c = 1.0 - smoothstep(0.0, wake_crest_w, abs(length(rel) - r));
				c *= 1.0 - smoothstep(wake_sin - 0.18, wake_sin + 0.04,
									  dot(normalize(rel + vec2(1e-5)), fwd));
				a = max(a, wake_crest_amt * fade * c);
			}
		}
		pq0 = q0;
		pq1 = q1;
		ppos = h.xy;
		have = live;
	}
	a *= mix(1.0, vnoise(p * wake_froth_scale), wake_froth_amt);
	return mix(base, wake_col.rgb, clamp(a, 0.0, 1.0) * wake_col.a);
}
