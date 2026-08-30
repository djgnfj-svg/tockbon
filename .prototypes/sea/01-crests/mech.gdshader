// **Where this one gets the open water from: A NOISE FIELD IN WORLD SPACE, CUT WITH A THRESHOLD.**
//
// The nearest thing to it that shipped is Alba (ustwo games). Their tech artist' own description: the
// stylised foam is a tiling greyscale texture, *thresholded to a specific range of that wave* — a
// pattern sampled and then STEPPED, not faded. **No texture is bought anywhere in this project**, so
// the greyscale is `vnoise` and the threshold is the same idea. Alexander Ameye's stylised-water
// write-up cuts its surface foam the same way: pan the coordinates, sample, `Step`.
//
// ⚠⚠ **FIRST SHOT: `crest_scale` 0.55 AND IT WAS AN OIL SLICK.** One noise cell was near two tiles,
// which at the opening zoom is sixty screen pixels — a pale continent drifting over the water, not a
// crest. **2.2 puts a stroke inside half a tile** and the threshold has something small to cut.
//
// ⚠ **The strokes are HARD.** A soft blob of pale is haze; the whole point of the threshold is that the
// water either has a crest at this pixel or it does not.
uniform vec4 crest_col : source_color = vec4(0.86, 0.91, 0.93, 1.0);
// **Strokes per tile**, and how far they are drawn out across the wind.
uniform float crest_scale = 2.20;
uniform float crest_stretch = 0.34;
// **Where in the noise a stroke starts, and how hard its edge is.** `crest_hard` near 0 is a cut.
uniform float crest_at = 0.70;
uniform float crest_hard = 0.028;
uniform float crest_amt = 0.42;
uniform vec2 crest_wind = vec2(0.85, 0.53);
uniform float crest_drift = 0.55;
// ⚠ **A wide slow map so some stretches of sea work and others lie almost still** — the user asked for
// exactly this on 2026-08-28 (「일관적이면 안 되고 랜덤해야함 넓게」). Without it every part of the water
// is equally busy, which reads as a texture rather than as a sea.
uniform float crest_patch = 0.75;
uniform float crest_patch_scale = 0.055;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	vec2 q = vec2(p.x, p.y * crest_stretch) * crest_scale - crest_wind * (t * crest_drift);
	float n = vnoise(q) * 0.65 + vnoise(q * 2.1 + vec2(19.0, 7.0)) * 0.35;
	float s = smoothstep(crest_at, crest_at + max(crest_hard, 0.001), n);
	float patch = mix(1.0 - crest_patch, 1.0,
					  smoothstep(0.30, 0.70,
								 vnoise(p * crest_patch_scale + vec2(t * 0.012, -t * 0.009))));
	return mix(sea.rgb, crest_col.rgb, s * crest_amt * patch);
}
