// **03 — THE WATER IS SEE-THROUGH, and the shoreline is what that produces on its own.**
//
// The sea is transparent. How much of the rock below shows through is decided by how far the light has
// to travel through water to reach it — the same depth difference 02 uses, spent on TRANSPARENCY rather
// than on a band. ⚠ **There is no foam dial at all**: the pale edge round the island is the submerged
// rock showing through shallow water, plus a thin line where the two surfaces actually meet.
//
// This is the half of the standard setup that 02 leaves out, and it is why real water reads as water:
// the shore is not painted on, it is what you can see of the bottom.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec4 deep : source_color = vec4(0.200, 0.330, 0.380, 1.0);
uniform vec4 foam : source_color = vec4(0.880, 0.930, 0.940, 1.0);
// How many metres of water hide the bottom completely.
uniform float clarity_m = 0.55;
// How strongly the water tints what shows through.
uniform float tint = 0.80;
// The thin line right where the two surfaces meet, in metres of water.
uniform float line_m = 0.035;
uniform float line_alpha = 0.45;
// How far the see-through is bent, in screen units — the water is not a flat pane of glass.
uniform float refract = 0.010;
uniform float ripple = 0.6;
uniform float ripple_scale = 2.6;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

// ⚠⚠ **THE DEPTH READ IS INLINE, TWICE, AND IT CANNOT BE A FUNCTION.** `INV_PROJECTION_MATRIX` is a
// built-in of `fragment()` and is simply not in scope inside a helper — Godot answers 'Unknown
// identifier' and the whole shader fails to compile, which in the Compatibility renderer means the
// material silently draws as flat white. Measured here on the first run of this lab.

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float own = -VERTEX.z;

	float n = vnoise(p * ripple_scale + vec2(t * 0.10, -t * 0.07));
	float n2 = vnoise(p * ripple_scale * 2.1 - vec2(t * 0.07, 0.0));

	// ⚠ **The bend is clamped by the UNBENT depth.** Bending first lets a pixel sample the sky beyond
	// the island and paint it under the water, which reads as a hole in the shore.
	float raw0 = texture(depth_tex, SCREEN_UV).x;
	// ⚠⚠ **`raw * 2.0 - 1.0`, AND THE GAME'S RENDERER IS WHY.** In GL Compatibility the clip-space z
	// runs -1..1 while the depth texture stores 0..1, so feeding `raw` straight in reports every
	// depth as a fraction of what it is — measured here as a white disc covering the whole submerged
	// shore instead of a band a tenth of a tile wide. **Nothing errors; the picture is simply wrong.**
	vec4 v0 = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw0 * 2.0 - 1.0), 1.0);
	v0.xyz /= v0.w;
	float d_flat = max(-v0.z - own, 0.0);

	vec2 suv = clamp(SCREEN_UV + vec2(n - 0.5, n2 - 0.5) * refract
					 * smoothstep(0.0, 0.15, d_flat), vec2(0.001), vec2(0.999));
	float raw1 = texture(depth_tex, suv).x;
	vec4 v1 = INV_PROJECTION_MATRIX * vec4(vec3(suv * 2.0 - 1.0, raw1 * 2.0 - 1.0), 1.0);
	v1.xyz /= v1.w;
	float d = max(-v1.z - own, 0.0);

	vec3 through = texture(screen_tex, suv).rgb;
	// The further the light travels through water, the more of it the water has taken.
	float murk = 1.0 - exp(-d / max(clarity_m, 0.001) * 3.0);
	vec3 col = mix(mix(through, deep.rgb, tint * murk), deep.rgb, murk);

	float line = 1.0 - smoothstep(max(line_m, 0.0001) * 0.4, max(line_m, 0.0001), d);
	col = mix(col, foam.rgb, clamp(line * line_alpha, 0.0, 1.0));

	ALBEDO = col;
	ALPHA = 1.0;
	vec3 nrm = normalize(vec3((n - n2) * ripple, 9.0, (n2 - n) * ripple));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.30));
	ROUGHNESS = 0.35;
	SPECULAR = 0.35;
}
