// **THE CONTROL, AND IT IS THE SHAPE THAT WAS ALREADY REJECTED.**
//
// **A fine noise field over the whole sea.** Nothing here is new: this is what `01-crests`,
// `02-facets` and `05-paper` all were underneath, and on 2026-08-29 the user's words for the result
// were **「니가 만드는게 너무 자글자글함 이게 멀리서 봤을때도 고려해야해서」** and then **「암... 너무 별로네」**.
//
// ⚠⚠ **IT IS IN THIS SHEET ON PURPOSE AND IT IS NOT A CANDIDATE.** A sheet whose four real entries
// are all large and slow proves nothing on its own — it could be that any of them beats flat, or that
// none does. **This row is the reason to believe the other four are being judged on their own
// mechanism and not on being calmer than what came before.**
//
// ⚠ **If this one wins, the 2026-08-29 round was wrong about something and the finding is that**, not
// this shader. Nothing here is worth rebuilding on its own.
uniform vec4 grain_col : source_color = vec4(0.855, 0.905, 0.930, 1.0);
// **Noise cells per 조각.** ⚠ **Above 1.0 is FINE**, which is the whole character of this row.
uniform float grain_scale = 3.20;
// Where a stroke starts in the noise, how hard its edge is, and how strong it is.
uniform float grain_at = 0.45;
uniform float grain_to = 0.85;
uniform float grain_amt = 0.075;
uniform float grain_drift = 0.05;

// ⚠⚠ **THE LAB'S OWN CLOCK AND NOT `TIME`.** See `06-fleck`.
uniform float lab_t = 0.0;

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	vec2 q = p * grain_scale + vec2(lab_t * grain_drift, -lab_t * grain_drift * 0.7);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + vec2(11.0, 5.0)) * 0.4;
	return mix(sea.rgb, grain_col.rgb,
			   smoothstep(grain_at, max(grain_to, grain_at + 0.01), n) * grain_amt);
}
