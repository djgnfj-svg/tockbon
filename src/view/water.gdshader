// The sea. **No texture anywhere** — nothing here is bought, downloaded or painted, which is the whole
// reason it is a shader and not an asset.
//
// ⚠ **Every colour and every number arrives as a uniform from `look.gd`.** That file is where this repo
// keeps presentation values and a literal written here would be the one that nobody can find.
//
// ⚠⚠ **THE SWELL IS NOISE, NOT SINES** (2026-08-26, the user: ***"바다에 랜덤한 파도도 있어야 하고
// 줌을 뒤로 땡겼을 때 바다에 패턴이 보이는 문제가 있음"***). Three sine layers were used first, on the
// reasoning that three at different angles never line up into stripes. **They do — from far enough
// away.** Every sine has one period, and once the screen holds several of them the eye reads the grid
// they make. Noise has no period, so there is nothing to find at any distance.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 trough : source_color;
uniform vec4 crest : source_color;
uniform float wave_scale;
uniform float wave_speed;
uniform float contrast;

// --- the wash at the shore ---------------------------------------------------------------------
// ⚠⚠ **The shoreline belongs to the WATER, not to a mesh laid on it.** A bright ring was built as
// geometry once and read as a white plate, because that is exactly what it was. `land_field` is a
// distance-to-land map built on the CPU when the island loads: 0 at the shore, 1 at `field_span` tiles
// out, measured to the island's REAL coastline and not to its tile grid.
uniform sampler2D land_field : filter_linear, repeat_disable;
uniform vec4 foam : source_color;
uniform vec2 field_size;
uniform float field_span;
uniform float foam_tiles;    // how far out the travelling lines live
uniform float foam_speed;    // how fast they come in
uniform float foam_bands;    // how many lines are inside that reach at once
uniform float foam_sharp;    // how thin each line is
uniform float foam_break;    // how far apart the phase drifts ALONG the shore
uniform float foam_break_scale;
uniform float foam_lip_tiles;
// ⚠⚠ **How hard the sheltered side is spared** (2026-08-26, the user: 「이것도 전체에 적용되는 건 조금
// 그런데」). Waves arrive FROM somewhere. A coast that faces into the wind takes them; the lee side of
// the same island is nearly flat, and a ring of identical surf all the way round is the giveaway that
// nothing is actually arriving. 1 is a gentle lean, 4 leaves the far shore almost bare.
uniform float foam_lee;
// ⚠⚠ **The SHALLOWS: a wide, soft gradient in the water itself, and the thing that joins the land to
// the sea** (2026-08-26, the user: 「땅하고 바다하고 부드럽게 이어져서」). The island's side is a
// straight wall and stays one — the user threw out the sloped beach on purpose. What was missing is
// that real water does not arrive at a shore at one colour: it pales over a stretch as the bottom comes
// up. **This is that stretch, and it is many times wider than the foam.** The foam is the last hand's
// width; this is the approach.
uniform vec4 shallow : source_color;
uniform float shallow_tiles;

// --- the ripple ---------------------------------------------------------------------------------
// **This is the normal map, written out instead of painted.** Sea of Thieves scrolls four noise normal
// maps — two coarse, two fine — in opposing directions with the fine pair travelling slower, so the
// pattern never lines up twice. It is a texture there because a texture is cheaper than evaluating
// noise; here it is evaluated, because this repo buys nothing and the sea is one quad.
uniform float ripple_scale;
uniform float ripple_speed;
uniform float ripple_strength;
// ⚠ **How far out the ripple fades to nothing.** Detail smaller than a pixel does not read as detail,
// it reads as fizz — and the far sea is exactly where a repeating pattern would be spotted.
uniform float ripple_fade_tiles;
// Which way the wind runs, in degrees, and how far the ripples are drawn out along it.
uniform float ripple_wind_deg;
uniform float ripple_stretch;
// ⚠⚠ **How hard the streaks are CHOPPED into lengths** (2026-08-26, the user: 「파도 주름이 너무
// 연결되어 있네, 끊어져도 될 것 같은데」). Stretching the noise along the wind made it read as water
// instead of as fog — and then made every ripple a line running the whole width of the sea. Real
// ripples are short: they build, break and die within a few metres. This is a second noise varying
// ALONG the streak that fades it out in patches, so a streak becomes a run of dashes.
uniform float ripple_chop;

// --- noise --------------------------------------------------------------------------------------
// Value noise: a hash at each lattice point, smoothstepped between. No texture, no lookup table.

float hash21(vec2 i) {
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Four octaves, each **not quite** double the last. ⚠ Exactly 2.0 stacks every octave's lattice on the
// same lines and the noise grows a faint square grid of its own — the thing this was written to avoid.
float fbm(vec2 p, float t) {
	float sum = 0.0;
	float amp = 0.5;
	vec2 q = p;
	for (int i = 0; i < 4; i++) {
		// Each octave drifts its own way, so they slide over one another instead of moving as a sheet.
		vec2 drift = vec2(t * (0.31 + 0.17 * float(i)), -t * (0.23 + 0.11 * float(i)));
		sum += amp * (vnoise(q + drift) - 0.5);
		q *= 2.07;
		amp *= 0.5;
	}
	return sum * 2.2;
}

// The swell: the big slow shape, **domain-warped** so its own features are not laid out on a lattice
// either. The warp is what turns "noise" into "waves that wander".
float swell(vec2 p, float t) {
	vec2 sp = p * wave_scale;
	vec2 warp = vec2(vnoise(sp * 0.45 + vec2(t * 0.07, 0.0)),
					 vnoise(sp * 0.45 - vec2(0.0, t * 0.06))) - 0.5;
	return fbm(sp + warp * 1.7, t);
}

// The ripple. ⚠⚠ **Three things separate this from "noise on water"**, and the first version had none
// of them (2026-08-26, the user: 「물주름 좀 더 리얼하게 해볼래?」):
//
//  1. **It is STRETCHED.** Wind-driven ripples are long across the wind and short along it. Round noise
//     reads as fog or as marble; it never reads as water.
//  2. **The crests are RIDGED, not rounded.** `1 - |2n-1|` folds the noise about its middle, which puts
//     a crease where value noise puts a hill. A real ripple has a sharp top and a wide trough, and that
//     asymmetry is most of what the eye recognises.
//  3. **It TRAVELS.** The layers drift along the wind rather than wandering, so the surface moves the
//     way a wind-blown sheet of water moves instead of boiling in place.
float ridge(vec2 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

float ripple(vec2 p, float t) {
	// Into wind space: x runs along the wind, y across it.
	float a = radians(ripple_wind_deg);
	vec2 w = vec2(cos(a), sin(a));
	vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	// Squashed along the wind — this is the stretch, and `ripple_stretch` is how long the ripples get.
	q.x *= ripple_stretch;

	float travel = t * ripple_speed;
	// ⚠ Three layers at rates that are not multiples of one another: equal ratios beat visibly and the
	// whole surface pulses together once a cycle.
	float a1 = ridge((q + vec2(travel, 0.0)) * ripple_scale);
	float a2 = ridge((q + vec2(travel * 1.7, travel * 0.21)) * ripple_scale * 2.13);
	float a3 = ridge((q + vec2(travel * 2.6, -travel * 0.13)) * ripple_scale * 4.37);
	float body = a1 * 0.52 + a2 * 0.31 + a3 * 0.17;
	// ⚠ Sampled with the OPPOSITE anisotropy — fine along the streak, coarse across it — so it cuts the
	// streaks into lengths instead of dissolving them into speckle.
	float chop = vnoise(vec2(q.x * ripple_chop, q.y * 0.22) + vec2(travel * 0.6, 0.0));
	return body * (0.30 + 0.70 * smoothstep(0.22, 0.78, chop));
}

void fragment() {
	// `VERTEX` is view space in a fragment shader; the sea has to move in WORLD space or it slides under
	// the camera whenever the board is panned or turned.
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME * wave_speed;

	// ⚠ **Pushed away from the middle, not scaled.** Multiplying would clip; bending about 0.5 keeps
	// every value in range and puts more of the surface at one tone or the other, which is what makes a
	// wave read as a wave instead of as a gradient.
	float raw = clamp(swell(p, t) * 0.5 + 0.5, 0.0, 1.0);
	float k = clamp((raw - 0.5) * contrast + 0.5, 0.0, 1.0);
	ALBEDO = mix(trough.rgb, crest.rgb, k);

	// A slope read straight off the same function, so the glint sits on the face of a wave rather than
	// anywhere the light happens to fall.
	float e = 0.35;
	float dx = (swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t)) / (2.0 * e);
	float dy = (swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t)) / (2.0 * e);

	// ⚠⚠ **The ripple's slope is read at a MUCH smaller step, and DIVIDED by it.** Sampling fine noise
	// with the swell's step averages it away; forgetting the division leaves a number near zero, which
	// bent the surface by about a third of a degree and looked exactly like no ripple at all.
	float re = 0.055;
	float rx = (ripple(p + vec2(re, 0.0), t) - ripple(p - vec2(re, 0.0), t)) / (2.0 * re);
	float ry = (ripple(p + vec2(0.0, re), t) - ripple(p - vec2(0.0, re), t)) / (2.0 * re);

	// ⚠⚠ **THE DISTANCE FADE IS GONE, AND IT WAS ERASING THE RIPPLE ENTIRELY** (measured 2026-08-26).
	// It faded the ripple out beyond `ripple_fade_tiles` of `length(VERTEX)` — distance from the camera.
	// **This camera is ORTHOGONAL and sits far back**, so every point on the sea was past the fade and
	// the ripple was multiplied by zero. Four candidates were rendered at four strengths and all four
	// came out identically flat; the dial could not reach the screen. ⚠ **On an orthogonal camera,
	// distance-from-camera is not a stand-in for "far away on screen"** — the projection has no
	// perspective, so a near tile and a far tile are drawn at exactly the same size.
	// The reason the fade was added — a repeating pattern showing when zoomed out — was fixed at the
	// source instead: the swell is noise now and has no period to spot.

	// ⚠⚠ **Stronger in the shallows, and that is not decoration.** A wave steepens as the bottom rises
	// under it — it is the one place a sea visibly has texture, and it is exactly where this game's eye
	// is. Computing the shore distance here costs one sample that the foam below needs anyway.
	vec2 uv0 = p / max(field_size, vec2(1.0));
	float d0 = texture(land_field, clamp(uv0, vec2(0.0), vec2(1.0))).r * field_span;
	float shore = 1.0 - smoothstep(0.0, max(shallow_tiles, 0.001), d0);
	float rs = ripple_strength * (1.0 + shore * 1.4);

	vec3 n = normalize(vec3(-dx - rx * rs, 9.0, -dy - ry * rs));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.34));

	// --- the wash ---------------------------------------------------------------------------------
	// The field covers the island's own tile box. Outside it the sampler clamps to the border, which is
	// open water, so the foam simply does not appear out there.
	vec2 uv = p / max(field_size, vec2(1.0));
	float d = texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * field_span;

	// --- the shore waves --------------------------------------------------------------------------
	// ⚠⚠ **Travelling LINES, not one breathing ring** (2026-08-26, the user: 「저 흰색 선을 리얼하게
	// 하고 싶음, 뭔가 지금 다 똑같이 움직이니까 이상함」). The band used to widen and narrow as a whole,
	// so every stretch of coast did the same thing at the same instant — which is the one thing a real
	// shore never does. The shape below is the standard one for this and it is three parts:
	//
	//  1. **A gradient off the shore, run through a cosine.** `cos(d*k + t*w)` puts a line every 2π and
	//     moves each line INWARD as `t` grows — waves approaching the land rather than sitting still.
	//  2. **A noise offset added to the PHASE, sampled along the coast.** This is what breaks the ring:
	//     each stretch crests at its own moment, so one place is running up while another is drawing
	//     back. Without it the lines are concentric and read as a diagram.
	//  3. **A power, to make each line thin**, and a fade so the lines die out before the open sea.
	// ⚠⚠ **Which way this piece of coast FACES, read from the field itself.** The distance-to-land map
	// grows away from the island, so its gradient at any point is the outward normal of the shore there
	// — no extra data, no per-tile table. Dotted against the wind, it says whether this stretch is
	// windward or sheltered.
	float ge = 0.35;
	vec2 duv = vec2(ge, 0.0) / max(field_size, vec2(1.0));
	vec2 dvv = vec2(0.0, ge) / max(field_size, vec2(1.0));
	float gx = texture(land_field, clamp(uv + duv, vec2(0.0), vec2(1.0))).r
			 - texture(land_field, clamp(uv - duv, vec2(0.0), vec2(1.0))).r;
	float gy = texture(land_field, clamp(uv + dvv, vec2(0.0), vec2(1.0))).r
			 - texture(land_field, clamp(uv - dvv, vec2(0.0), vec2(1.0))).r;
	vec2 outward = normalize(vec2(gx, gy) + vec2(1e-6));
	float wa = radians(ripple_wind_deg);
	// The wind blows one way; the shore that MEETS it is the one whose outward normal opposes it.
	float expose = clamp(dot(outward, -vec2(cos(wa), sin(wa))) * 0.5 + 0.5, 0.0, 1.0);
	expose = pow(expose, foam_lee);

	float g = clamp(d / max(foam_tiles, 0.001), 0.0, 1.0);
	float jitter = (vnoise(p * foam_break_scale) - 0.5) * foam_break;
	float ph = g * foam_bands * 6.2831 + TIME * foam_speed * 6.2831 + jitter;
	float band = pow(cos(ph) * 0.5 + 0.5, foam_sharp);

	// ⚠⚠ **A GATE, not just a phase shift** (2026-08-26, the user: 「너무 파도가 연결되어 있는 느낌이
	// 있네」). Offsetting the phase along the coast makes the lines bend, but every stretch still has a
	// line — so they still read as one continuous thing threading round the island. This second noise
	// switches the lines OFF entirely over patches of shore, which is what a real coast does: surf here,
	// flat water twenty metres along. ⚠ Coarser than the phase noise on purpose, so a gap is a stretch
	// rather than a speckle.
	float gate = smoothstep(0.34, 0.68, vnoise(p * foam_break_scale * 0.55 + vec2(37.0, 11.0)));
	band *= gate;
	// Gone by the time the gradient reaches open water, and thickest a little off the land.
	float fade = (1.0 - smoothstep(0.35, 1.0, g)) * smoothstep(0.0, 0.18, g);

	// ⚠ **A thin permanent lip right AT the land**, separate from the travelling lines. Water always
	// touches the shore; the lines are what runs up over it. The user asked for exactly this shape:
	// 「그런 선은 얇게 있고, 그게 아니라 파도 같은 게 살짝」.
	float lip = 1.0 - smoothstep(0.0, max(foam_lip_tiles, 0.001), d);

	// ⚠ **The lip is NOT exposed-gated.** Water touches the shore all the way round whatever the wind
	// does; it is the running-up waves that arrive from one side.
	float f = clamp(band * fade * expose * 0.95 + lip * 0.85, 0.0, 1.0);

	ALBEDO = mix(ALBEDO, foam.rgb, f);

	// ⚠ **Smoother than the flat sea was.** The old numbers were measured down to kill one enormous
	// blown-out streak on a 400-tile mirror; that streak was a problem because the surface was FLAT and
	// had one highlight. A rippled surface scatters the same light into thousands of small ones, so it
	// can afford to be shinier — and it has to be, or the ripple has nothing to catch.
	ROUGHNESS = mix(0.74, 0.45, k) * (1.0 - f * 0.45);
	SPECULAR = mix(0.28, 0.04, f);
}
