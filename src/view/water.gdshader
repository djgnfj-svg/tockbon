// The sea. **No texture anywhere** — nothing here is bought, downloaded or painted, which is the whole
// reason it is a shader and not an asset.
//
// ⚠ **Every colour and every number arrives as a uniform from `look.gd`.** That file is where this repo
// keeps presentation values and a literal written here would be the one that nobody can find.
//
// ⚠⚠ **THIS FILE WAS REPLACED WHOLE ON 2026-08-28, AND THE SEA IT REPLACED IS NOT COMING BACK BY
// ACCIDENT.** What stood here painted swell, ripples, drawn crests, travelling foam, a shallows tint and
// a shoreline — about forty dials, every one of them picked by eye, and a day of rounds spent turning
// them. Seven ways of drawing a shoreline were then built side by side on one block
// (`prototypes/shoreline/`) and the user chose the one that does the least: **a flat sea and a border,
// and nothing else at all.**
//
// It is Bad North's own answer, stated by its designer at Konsoll 2018: *"most of the water is just
// completely flat, but then at the edge when something meets the water I highlight that instead… it also
// ties into the idea of expressing things in borders and not in… textures, not in field."*
//
// ⚠⚠ **What that means for this file**: there is no swell, no ripple, no drawn crest, no travelling foam
// and no shallows in it. **Their constants still stand in `look.gd`, parked** — they are measurements and
// deleting them throws away what they cost — but **nothing reads them and turning one changes nothing on
// screen.** The old shader is recoverable from git; it is `water.gdshader` before this commit.
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

// --- 1. THE SHAPE OF THE LINE -------------------------------------------------------------------
// ⚠⚠ **Three octaves, three sizes, three drifts, and they never line up** (2026-08-28, the user:
// 「단순하게 원이 아니라 이제 복합적으로 움직이는걸 원한 진짜 물처럼」). One long enough to bend a whole
// stretch of coast, one that puts a bay inside that bend, one fine enough to fray the edge. **A single
// octave, however strong, reads as a wobble.** ⚠ Each drifts a different WAY as well as at a different
// rate — three layers all sliding along +x is one layer with extra steps.
uniform float warp_a;
uniform float warp_a_scale;
uniform float warp_a_speed;
uniform float warp_b;
uniform float warp_b_scale;
uniform float warp_b_speed;
uniform float warp_c;
uniform float warp_c_scale;
uniform float warp_c_speed;

// --- 2. HOW THICK IT IS, STRETCH BY STRETCH -----------------------------------------------------
// ⚠⚠ **The phase is read ALONG the coast**, so one stretch runs up while the next draws back. **This is
// the layer that stops it being a ring** — on one clock every point on the island swells at the same
// instant, which is nothing water does.
uniform float swing;
uniform float swing_rate;
uniform float along_scale;
uniform float swing_floor;

// --- 3. THE ONE THAT LETS GO --------------------------------------------------------------------
// ⚠ Once a cycle, over patches of coast only, a line separates and travels seaward, fading as it goes.
// **Two lines on screen are the same line at two ages**, which is what backwash looks like.
// ⚠⚠ **거품 — THE LINE THAT COMES IN — WAS PUT BACK ON 2026-08-29 AND TAKEN STRAIGHT OUT AGAIN.**
// One band, starting 0.7 tiles out and closing on the rim half a cycle out of phase with `peel`. The
// user saw it and said 「별로다... 그 거품없애봐」. **The measurement stands: a flat sea with one
// border is still what this island wants**, which is what seven candidates said on 2026-08-28 and what
// a second attempt has now confirmed from the other side.
uniform float peel;
uniform float peel_tiles;
uniform float peel_gate_scale;

// --- 4. WHERE THE COAST IS QUIET ----------------------------------------------------------------
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

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	float d = (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span
			  + shore_offset;

	// 1. Bend the line itself.
	float w = (vnoise(p * warp_a_scale + vec2(t * warp_a_speed, t * warp_a_speed * 0.35)) - 0.5)
			  * 2.0 * warp_a
			+ (vnoise(p * warp_b_scale - vec2(t * warp_b_speed * 0.4, t * warp_b_speed)) - 0.5)
			  * 2.0 * warp_b
			+ (vnoise(p * warp_c_scale + vec2(-t * warp_c_speed, t * warp_c_speed * 0.8)) - 0.5)
			  * 2.0 * warp_c;
	d += w;

	// 4. How lively this stretch of coast is at all, and it drifts so the quiet places move.
	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	// 2. This stretch's own place in the cycle, and the width that comes out of it.
	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float ph = t * swing_rate + along * 6.2831;
	float breathe = mix(swing_floor, 1.0 + swing,
						(sin(ph) * 0.5 + 0.5) * live + (1.0 - live) * 0.5);
	float bw = max(line_tiles, 0.0001) * breathe;
	float band = 1.0 - smoothstep(bw * line_hard, bw, d);

	// 3. The one that has let go: a soft hump travelling out, over patches only.
	if (peel > 0.001) {
		float age = fract(ph / 6.2831);
		float away = age * peel_tiles;
		float pw = max(line_tiles, 0.0001) * 1.1;
		float hump = exp(-pow((d - away) / pw, 2.0)) * (1.0 - age);
		float where = smoothstep(0.35, 0.72, vnoise(p * peel_gate_scale + vec2(3.0, 17.0)));
		band = max(band, hump * where * peel * live);
	}

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
