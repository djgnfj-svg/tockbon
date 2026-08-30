// **One foam blob.** A soft-edged oval broken by a noise that is seeded per stamp, so no two are the
// same shape. ⚠ `COLOR.a` is the stamp's own fade and `COLOR.r` is its seed, both written per vertex.
shader_type spatial;
// ⚠⚠ **`blend_mix` is the honest setting and it is what costs this candidate.** Where two stamps
// overlap their alphas compound and the pair reads brighter than either — which is what turns a run of
// blobs into a lumpy stripe. **A spatial shader has no max blend mode to escape it with.**
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 col : source_color;
uniform float froth_scale;
uniform float froth_amt;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float disc = 1.0 - smoothstep(0.42, 1.0, length(q));
	float n = mix(1.0, vnoise(UV * froth_scale + vec2(COLOR.r * 41.0, COLOR.r * 17.0)), froth_amt);
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a * COLOR.a * disc * n, 0.0, 1.0);
}
