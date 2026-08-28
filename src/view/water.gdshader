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
// ⚠ **Where the field's corner sits in world tiles.** It is not the grid's corner: the field is built
// with a margin of open water round the island so that clamping outside it repeats open sea.
uniform vec2 field_origin;
uniform float field_span;
// ⚠⚠ **How far OUTSIDE the tile grid the mesh's real waterline sits, in tiles.** The coast the bake
// exports is the square tile outline; the mesh's shore is a skirt hung outward and down from it, so the
// water meets rock about half a tile further out than the field says. Everything measured from the
// shore was therefore measured from a line under the island. ⚠ Subtracting it here also ROUNDS the
// convex corners — a distance field pushed outward curves where a polyline turns — which is much nearer
// the bake's chamfered corners than the right angle it had.
uniform float shore_offset;
// ⚠⚠ **THE SAMPLE POINT IS DRAGGED ABOUT BEFORE THE DISTANCE IS READ, and this is what stops the band
// being a drawing** (2026-08-28, the user: 「이게 뭔가 흐름처럼 곡선이어야 되는데 이게 전혀 그런 게
// 없으니까」). A band at a fixed distance from a line is that line's parallel offset — geometry, however
// soft its edge and however its width swings. **Warping where the distance is measured FROM makes the
// band wander off that offset curve**, and it is the standard move: A Thief's Melody adds a scrolling
// world-space noise to its sample point for exactly this. In tiles.
uniform float shore_warp;
uniform float shore_warp_scale;
uniform float shore_warp_speed;
uniform float foam_tiles;    // how far out the travelling lines live
uniform float foam_speed;    // how fast they come in
uniform float foam_bands;    // how many lines are inside that reach at once
uniform float foam_sharp;    // how thin each line is
uniform float foam_break;    // how far apart the phase drifts ALONG the shore
uniform float foam_break_scale;
uniform float foam_lip_tiles;
// ⚠⚠ **How HARD the lip's outer edge is, and 0 is the gradient it was born with.** `1 - smoothstep(0,
// w, d)` starts falling the instant it leaves the rock, so the lip is a fade rather than a line and it
// reads as a glow around the island. At 1 the band is flat to nearly its full width and then stops.
uniform float foam_lip_hard;
// How opaque the lip is at its strongest. ⚠ It was a literal in the mix below, which is exactly the
// number nobody can find when the shore reads as a sticker.
uniform float foam_lip_alpha;
// How opaque the TRAVELLING lines are at their strongest. ⚠ It was a literal `0.95` — very nearly the
// foam colour undiluted, which is what made a line read as a stroke laid on the water rather than as
// water. In the reference the user supplied, the surf is barely lighter than the sea it sits on.
uniform float foam_alpha;
// ⚠⚠ **How much the lip's WIDTH swings, and a still lip is the whole problem it fixes** (2026-08-28,
// the user: 「물가가 유동적으로 움직여야 좀 제대로 보이고, 얇아졌다가 약간 두꺼워졌다가 떨어져 나갔다가
// 하는 게 중요할 듯」). A line of constant width round an island is a drawn outline no matter how thin
// or how faint it is; **water is recognised by the fact that it will not hold still.** At 1 the width
// swings from nothing — a real gap, the 「떨어져 나갔다가」 — to double.
uniform float foam_lip_wob;
// How long a stretch of coast shares one width, in inverted tiles, and how fast that width changes.
uniform float foam_lip_wob_scale;
uniform float foam_lip_wob_speed;
// ⚠⚠ **THE LINE THAT PEELS OFF AND DIES ON ITS WAY OUT** (2026-08-28, the user: 「가끔씩 두 줄이 되기도
// 하면 좋을 거 같은데 ... 그리고 멀어지면서 사라지는 거 있잖아. 진짜인 것처럼」). Real backwash leaves a
// line behind: it separates from the rock, travels seaward and fades as it goes. **The two lines on
// screen at once are the same line at two ages** — the shore's current one and the one it let go a
// moment ago — which is why this is one dial and not a second shoreline.
uniform float foam_lip_peel;
// How far a peeled line gets before it is gone, in tiles.
uniform float foam_lip_peel_tiles;
// ⚠⚠ **THE HAIRLINE THAT NEVER GOES**, in tiles (2026-08-28, the user: 「해안선에 붙어있는 라인은 꼭
// 있어야 돼 ... 진짜 얇게 하나는 꼭 유지됐음 좋겠어」). Everything above can thin a stretch of shore to
// nothing, and on the frames where it did the coast lost its edge entirely. **This width is held back
// from the swash and the peel and is drawn whatever they are doing** — water touches rock at every
// moment, everywhere, and that fact is not something to animate.
uniform float foam_lip_min_tiles;
// How opaque that hairline is. ⚠⚠ **Its OWN number, not the soft wash's.** Folding it into the wash's
// alpha was the mistake: the wash is deliberately faint so it does not read as a stroke, and a line
// that is meant to be seen cannot borrow the opacity of something meant not to be.
uniform float foam_lip_edge_alpha;
// ⚠⚠ **Where inside its reach the travelling lines live, as fractions of `foam_tiles`.** These two were
// literals -- 0.18 and 0.35 -- which put every line between 0.47 and 0.91 tiles off the coast: a ring
// one third of a tile thick, out of a reach of 2.6. **The lines were being drawn and then faded out
// almost everywhere they were drawn.** ⚠ A presentation number written here is one nobody can find;
// both live in `look.gd` now.
uniform float foam_fade_in;
uniform float foam_fade_out;
// ⚠⚠ **The GATE's own scale, and it used to borrow the phase noise's** (measured 2026-08-28). The gate
// switches the travelling lines off over stretches of coast, and it was sampled at `foam_break_scale *
// 0.55` -- features about eight tiles across. **This island is sixteen tiles wide**, so the gate held
// roughly two features in total and simply turned the surf off down the whole west and south side. A
// probe that painted the foam red found the lines living only off the north-east arm.
uniform float foam_gate_scale;
// ⚠⚠ **How much surf a gated-off stretch still keeps.** At 0 the gate can empty a stretch completely,
// which is what left most of this coast bare; at 1 the gate does nothing at all.
uniform float foam_gate_floor;
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
// ⚠⚠ **How strongly the shallows show, and it exists because they NEVER SHOWED AT ALL.** Found
// 2026-08-28: `shallow` was declared, handed over from `look.gd`, commented at length — and `shallow.rgb`
// appears nowhere in this file's whole history. The colour was wired end to end and never painted. The
// only thing `shallow_tiles` ever did was steepen the ripple near the shore.
uniform float shallow_strength;

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
// ⚠⚠ **A SECOND WAY OF DRAWING THE SAME RIPPLE, and 0 is the old one exactly.** Everything above bends
// the NORMAL and lets the light find it, which on this game's flat cartoon island reads as an
// airbrushed smudge: six candidates were rendered at six settings of those dials and all six were the
// same soft haze. This instead lays the ripple's crests into the COLOUR as hard-edged lines, the way a
// stylised sea is drawn rather than lit. **At 0 not one pixel changes**; at 1 the crests are a firm
// pale line on the water.
uniform float ripple_crisp;
// Where along the ripple a line starts, and it is the whole difference between "a few crests" and "the
// sea is white". The ripple's own value sits around 0.4 to 0.7, so a threshold near the top of that
// picks out the sharpest crests only.
uniform float ripple_crisp_edge;
// ⚠⚠ **How UNEVENLY the drawn crests are spread, and it is the whole reason this candidate was picked**
// (2026-08-28, the user: 「계속 막 뭐랄까 일관적이면 안 되고 랜덤해야함 넓게」). An even field of crests
// is a texture; a sea has stretches that are working and stretches that are almost still. 0 spreads them
// evenly, 1 empties the quiet stretches completely.
uniform float ripple_crisp_patch;
// How WIDE one such stretch is, in inverted tiles. ⚠ Small: the patches have to be many tiles across or
// they read as the chop that is already in the ripple, and the two just make speckle together.
uniform float ripple_crisp_patch_scale;

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

// ⚠⚠ **The crest MASK, and it is not `ripple` thresholded** (measured 2026-08-28). Cutting the ripple
// value at a level put every drawn line into one corner of the sea and left the rest bare: the coarse
// first layer carries most of that value and it is a slow blob many tiles wide, so a threshold on the
// sum is really a threshold on the blob. **The two fine layers alone are evenly spread**, which is what
// a field of crests has to be. The chop still gates them, so a line is a dash and not a wire.
float ripple_crest(vec2 p, float t) {
	float a = radians(ripple_wind_deg);
	vec2 w = vec2(cos(a), sin(a));
	vec2 q = vec2(dot(p, w), dot(p, vec2(-w.y, w.x)));
	q.x *= ripple_stretch;
	float travel = t * ripple_speed;
	float b = ridge((q + vec2(travel * 1.7, travel * 0.21)) * ripple_scale * 2.13) * 0.45
			+ ridge((q + vec2(travel * 2.6, -travel * 0.13)) * ripple_scale * 4.37) * 0.55;
	float chop = vnoise(vec2(q.x * ripple_chop, q.y * 0.22) + vec2(travel * 0.6, 0.0));
	return b * (0.55 + 0.45 * smoothstep(0.22, 0.78, chop));
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
	// ⚠ **One warp, used by everything that reads the shore**, so the lip, the lines and the shallows all
	// wander together. Two noises rather than one, or the offset only ever moves along one diagonal.
	vec2 shore_p = p + (vec2(vnoise(p * shore_warp_scale + vec2(TIME * shore_warp_speed, 0.0)),
							 vnoise(p * shore_warp_scale * 1.13
									+ vec2(0.0, -TIME * shore_warp_speed * 0.8)))
						- vec2(0.5)) * 2.0 * shore_warp;
	vec2 uv0 = (shore_p - field_origin) / max(field_size, vec2(1.0));
	// ⚠⚠ **NOT clamped at zero, and clamping it was a bug that could not be turned off** (2026-08-28).
	// `max(d - offset, 0.0)` makes every point within the offset read as EXACTLY at the shore, so the
	// lip was full strength across a third of a tile **whatever its thickness was set to** — setting the
	// thickness to zero left the band untouched, which is what the user hit: 「없음 하면 흰색이 없어야
	// 되는 거 아니야?」. Letting it go negative puts the band where the water actually starts.
	float d0 = texture(land_field, clamp(uv0, vec2(0.0), vec2(1.0))).r * field_span - shore_offset;
	float shore = 1.0 - smoothstep(0.0, max(shallow_tiles, 0.001), d0);
	// **The shallows themselves.** Real water does not arrive at a shore at one colour: it pales over a
	// stretch as the bottom comes up, and this is that stretch. ⚠ It goes under the foam, not over it —
	// the lines and the lip are drawn ON the water, and this is the water.
	ALBEDO = mix(ALBEDO, shallow.rgb, clamp(shore * shallow_strength, 0.0, 1.0));
	float rs = ripple_strength * (1.0 + shore * 1.4);

	vec3 n = normalize(vec3(-dx - rx * rs, 9.0, -dy - ry * rs));

	// ⚠ **The drawn crests.** `ripple_crest` is a separate read of the same field, not the ripple value
	// itself -- see the note on that function for the measurement that forced the split.
	if (ripple_crisp > 0.001) {
		float rv = ripple_crest(p, t);
		// ⚠ **The wide stretches, and they DRIFT.** A still patch map would pin the busy water to one
		// place on the board forever, which is the giveaway the whole ripple set exists to avoid.
		float patch = vnoise(p * ripple_crisp_patch_scale + vec2(t * 0.05, -t * 0.03));
		float amount = ripple_crisp * mix(1.0 - ripple_crisp_patch, 1.0,
										  smoothstep(0.22, 0.78, patch));
		// ⚠ Two steps rather than one: a single hard cut aliases into a crawling stipple the moment the
		// board turns. The inner step is the line, the outer a thinner brighter core inside it.
		float line = smoothstep(ripple_crisp_edge, ripple_crisp_edge + 0.06, rv);
		float core = smoothstep(ripple_crisp_edge + 0.08, ripple_crisp_edge + 0.16, rv);
		vec3 sheen = clamp(crest.rgb * 1.30, vec3(0.0), vec3(1.0));
		ALBEDO = mix(ALBEDO, sheen, clamp((line * 0.55 + core * 0.45) * amount, 0.0, 1.0));
	}
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.34));

	// --- the wash ---------------------------------------------------------------------------------
	// The field covers the island's own tile box. Outside it the sampler clamps to the border, which is
	// open water, so the foam simply does not appear out there.
	vec2 uv = (shore_p - field_origin) / max(field_size, vec2(1.0));
	float d = texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * field_span - shore_offset;

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
	float gate = smoothstep(0.34, 0.68, vnoise(p * foam_gate_scale + vec2(37.0, 11.0)));
	band *= mix(foam_gate_floor, 1.0, gate);
	// Gone by the time the gradient reaches open water, and thickest a little off the land.
	float fade = (1.0 - smoothstep(foam_fade_out, 1.0, g)) * smoothstep(0.0, foam_fade_in, g);

	// ⚠ **A thin permanent lip right AT the land**, separate from the travelling lines. Water always
	// touches the shore; the lines are what runs up over it. The user asked for exactly this shape:
	// 「그런 선은 얇게 있고, 그게 아니라 파도 같은 게 살짝」.
	// ⚠⚠ **SWASH — the width swings IN PHASE WITH THE ARRIVING LINES**, which is the named technique and
	// not a wobble invented here (2026-08-28, researched: Cyanilux ties the swash to the incoming waves
	// with a phase offset; A Thief's Melody gets the same by clipping a travelling sine at a fixed
	// threshold, so the boundary sweeps in and out by construction). ⚠ **`jitter` is the SAME noise the
	// travelling lines take their phase from**, so a stretch of coast swells exactly as its own line
	// runs up it — and the stretch beside it, being out of phase, is drawing back.
	// ⚠⚠ **The swing is not a bare cosine.** A pure sine reads as a machine — A Thief's Melody adds a
	// noise-warped term for exactly this reason — so the phase is dragged about by a slow noise as well.
	float swash_warp = (vnoise(p * foam_lip_wob_scale * 1.7
							   + vec2(0.0, TIME * foam_lip_wob_speed * 0.8)) - 0.5) * 2.4;
	float swash = cos(TIME * foam_speed * 6.2831 + jitter + swash_warp);
	// ⚠ And how far it swings is itself uneven and slow, so some stretches barely move and others go to
	// nothing — the 「떨어져 나갔다가」. Verdant's shoreline swings in unison and says so; this does not.
	float swash_amp = mix(0.35, 1.0, vnoise(p * foam_lip_wob_scale
										   + vec2(TIME * foam_lip_wob_speed, 0.0)));
	// ⚠⚠ **The width RECEDES, it does not switch off.** `reach` goes negative for part of every cycle;
	// the old code cut the line dead the instant it did, so a stretch **blinked** instead of drawing
	// back — which is most of what read as 「딱딱하게」. Now the width bottoms out and the strength fades
	// with it, so the line thins away and returns.
	float lip_phase = TIME * foam_speed * 6.2831 + jitter + swash_warp;
	float reach = 1.0 + foam_lip_wob * swash * swash_amp;
	float lw = max(foam_lip_tiles, 0.001) * max(reach, 0.12);
	float lip_live = smoothstep(-0.15, 0.30, reach);

	// ⚠ **`foam_lip_hard` raises the INNER edge**, so the band holds its strength further out and then
	// falls quickly. ⚠⚠ It was written the other way round and 0 gave a hard step rather than the
	// gradient its own comment promised — the two ends of the dial were swapped.
	float lip = (1.0 - smoothstep(lw * foam_lip_hard * 0.85, lw, d)) * lip_live;
	// ⚠⚠ **A LINE, and drawn separately from everything else at the shore** (2026-08-28, the user:
	// 「딱붙어있는 얇은선이 필요하다는건디」). The first attempt made the floor un-killable but left it
	// inside the soft wash — same faint alpha, same gradient falling away from the rock — so what came
	// out was a permanent GLOW and not a permanent line. ⚠ **Flat to most of its width and then a quick
	// fall**, which is what makes a line a line; the wash beside it is the thing that fades.
	float edge = 1.0 - smoothstep(max(foam_lip_min_tiles, 0.0001) * 0.55,
								  max(foam_lip_min_tiles, 0.0001), d);

	// ⚠ **One cycle, one peel.** `age` runs 0 to 1 over the same cycle the swash swings through, so the
	// line lets go exactly as the shore's own line draws back — and because the phase carries the same
	// along-coast noise, one stretch is releasing while the next is still holding.
	if (foam_lip_peel > 0.001) {
		float age = fract(lip_phase / 6.2831);
		float away = age * foam_lip_peel_tiles;
		float pw = max(foam_lip_tiles, 0.001) * 0.9;
		// ⚠ A soft hump rather than a step: a peeled line has no edge to speak of by the time it is a
		// tile out, and a hard one crawls when the board turns.
		float hump = exp(-pow((d - away) / max(pw, 0.0001), 2.0));
		// ⚠ **Only over patches of coast**, or every stretch peels every cycle and the island wears two
		// concentric rings — the diagram this whole shape exists to avoid.
		float where = smoothstep(0.34, 0.70, vnoise(p * foam_gate_scale * 0.8 + vec2(11.0, 5.0)));
		lip = max(lip, hump * (1.0 - age) * where * foam_lip_peel);
	}

	// ⚠ **The lip is NOT exposed-gated.** Water touches the shore all the way round whatever the wind
	// does; it is the running-up waves that arrive from one side.
	float f = clamp(band * fade * expose * foam_alpha
					+ lip * foam_lip_alpha
					+ edge * foam_lip_edge_alpha, 0.0, 1.0);

	ALBEDO = mix(ALBEDO, foam.rgb, f);

	// ⚠ **Smoother than the flat sea was.** The old numbers were measured down to kill one enormous
	// blown-out streak on a 400-tile mirror; that streak was a problem because the surface was FLAT and
	// had one highlight. A rippled surface scatters the same light into thousands of small ones, so it
	// can afford to be shinier — and it has to be, or the ripple has nothing to catch.
	ROUGHNESS = mix(0.74, 0.45, k) * (1.0 - f * 0.45);
	SPECULAR = mix(0.28, 0.04, f);
}
