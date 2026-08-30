// **Where this one gets the open water from: A SWELL TRAIN — three wavefronts travelling one way.**
//
// Not an isotropic field. **A direction, three wavelengths and a speed** — the whole sea is one body
// of water moving somewhere, the way open ocean reads from above. The colour comes from where in the
// swell a pixel sits, deep in a trough and pale on a crest.
//
// ⚠⚠ **IT IS THE ONE CANDIDATE A STILL PICTURE CANNOT JUDGE, AND THE SHEET IS STILLS.** In a frozen
// frame this is two very soft light bands across the water; the argument for it is entirely that the
// water MOVES, and 「is it water or is it background」 is a question about the next second, not this
// one. **Read the still for what it costs and run the live lab for what it buys.**
//
// ⚠⚠ **THE WAVELENGTHS ARE THE ANSWER TO 「자글자글」.** 17, 23 and 31 조각 against a frame 42 조각 wide
// means about two crests on screen at the opening framing. **The 2026-08-29 round's five all put their
// structure inside one 조각** and the user's words for the result were 「너무 자글자글함」 and 「멀리서
// 봤을때도 고려해야해서」.
//
// ⚠ **The three bearings differ by a few degrees on purpose.** Parallel fronts of one wavelength are
// wallpaper; three that slowly slide out of phase never repeat inside the frame.
//
// ⚠ **This is NOT `03-swell` from the last round.** That one MOVED THE MESH and read the height off
// the geometry, which needed 1.3 조각 of amplitude before it was distinguishable from a shadow. **This
// touches no vertex.** The sea stays flat — the decision confirmed three times — and only its colour
// carries the swell.
uniform vec4 swell_deep : source_color = vec4(0.387, 0.531, 0.594, 1.0);
uniform vec4 swell_lift : source_color = vec4(0.560, 0.700, 0.760, 1.0);
// **Which way the whole train travels**, in degrees, and how fast in 조각 per second.
uniform float swell_head = 118.0;
uniform float swell_speed = 1.10;
// **The three wavelengths in 조각** and **how far off the train's heading each front lies**, in degrees.
uniform vec3 swell_len = vec3(17.0, 23.0, 31.0);
uniform vec3 swell_bear = vec3(8.0, 0.0, -11.0);
// How much of the swing each front carries. ⚠ They are meant to sum to about one.
uniform vec3 swell_mix = vec3(0.45, 0.35, 0.20);
// **The pale on the top of a crest**: where in the swing it starts, and how strong it is.
uniform float swell_crest_at = 0.72;
uniform float swell_crest = 0.30;

// ⚠⚠ **THE LAB'S OWN CLOCK AND NOT `TIME`.** See `06-fleck`.
uniform float lab_t = 0.0;

// One travelling front. Returns −1 in the trough and +1 on the crest.
float swell_front(vec2 p, float len, float bear_deg, float speed, float clock) {
	float a = radians(swell_head + bear_deg);
	vec2 k = vec2(cos(a), sin(a));
	return sin((dot(p, k) - speed * clock) * 6.2831853 / max(len, 0.5));
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	// ⚠ **The three speeds differ slightly too.** One speed for three wavelengths makes a train that
	// repeats its whole shape every few seconds, and a repeat is the thing that reads as a texture.
	float s = swell_mix.x * swell_front(p, swell_len.x, swell_bear.x, swell_speed, lab_t)
			+ swell_mix.y * swell_front(p, swell_len.y, swell_bear.y, swell_speed * 0.86, lab_t)
			+ swell_mix.z * swell_front(p, swell_len.z, swell_bear.z, swell_speed * 1.13, lab_t);
	vec3 c = mix(swell_deep.rgb, sea.rgb, clamp(s * 0.5 + 0.5, 0.0, 1.0));
	float top = smoothstep(swell_crest_at, 1.0, s);
	return mix(c, swell_lift.rgb, top * swell_crest);
}
