// **02 — the band comes from the DEPTH BUFFER.**
//
// The sea reads the scene depth behind it, subtracts its own, and gets **how deep the water is at this
// pixel, in metres**. Everything else is that one number: the water pales where it is small, and foam
// draws where it is smaller still. ⚠ **Nothing here knows where the coastline is** — no baked field, no
// outline, no distance. The band is wide where the bottom rises gently and narrow where it drops.
//
// This is the technique Rare's Sea of Thieves talk names for objects breaking the water surface, and the
// one Godot, Unity and Unreal all document.
shader_type spatial;
// ⚠ **Transparent on purpose, and it is not about seeing through.** `DEPTH_TEXTURE` holds the OPAQUE
// pass; a sea that writes into it reads itself and every depth comes out zero.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 deep : source_color = vec4(0.255, 0.375, 0.410, 1.0);
uniform vec4 pale : source_color = vec4(0.560, 0.700, 0.690, 1.0);
uniform vec4 foam : source_color = vec4(0.800, 0.880, 0.895, 1.0);
// How much water, in metres, the colour pales over. One tile is one metre.
uniform float pale_m = 0.45;
// How much water, in metres, the foam lives inside. ⚠ This is the whole shoreline: no other dial places it.
uniform float foam_m = 0.09;
uniform float foam_soft = 0.55;
uniform float foam_alpha = 0.85;
uniform float swash = 0.045;
uniform float swash_speed = 0.35;
uniform float swash_scale = 0.9;
uniform float ripple = 0.5;
uniform float ripple_scale = 2.6;

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

	// **How deep the water is here.** The whole prototype is this block.
	float raw = texture(depth_tex, SCREEN_UV).x;
	// ⚠⚠ **`raw * 2.0 - 1.0`, AND THE GAME'S RENDERER IS WHY.** In GL Compatibility the clip-space z
	// runs -1..1 while the depth texture stores 0..1, so feeding `raw` straight in reports every
	// depth as a fraction of what it is — measured here as a white disc covering the whole submerged
	// shore instead of a band a tenth of a tile wide. **Nothing errors; the picture is simply wrong.**
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw * 2.0 - 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float depth_m = max(-view.z - (-VERTEX.z), 0.0);

	// ⚠ **The swash rides ON the depth**, not on a distance: adding a wobble here makes the water
	// briefly deeper or shallower, which is what a wave running up a slope actually does.
	float w = (vnoise(p * swash_scale + vec2(t * swash_speed, 0.0)) - 0.5) * 2.0;
	float d = depth_m + w * swash;

	vec3 col = mix(pale.rgb, deep.rgb, clamp(d / max(pale_m, 0.001), 0.0, 1.0));
	float f = 1.0 - smoothstep(max(foam_m, 0.001) * foam_soft, max(foam_m, 0.001), d);
	ALBEDO = mix(col, foam.rgb, clamp(f * foam_alpha, 0.0, 1.0));
	ALPHA = 1.0;

	float n = vnoise(p * ripple_scale + vec2(t * 0.1, -t * 0.07));
	float n2 = vnoise(p * ripple_scale * 2.1 - vec2(t * 0.07, 0.0));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(normalize(vec3((n - n2) * ripple, 9.0,
																	  (n2 - n) * ripple)), 0.0)).xyz, 0.3));
	ROUGHNESS = mix(0.70, 0.42, f);
	SPECULAR = mix(0.28, 0.05, f);
}
