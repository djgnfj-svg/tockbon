// **04 — the band comes from a BAKED SEABED HEIGHT.**
//
// A field baked on the CPU holds, per texel, **how deep the water is there** — the sea's height minus
// the ground's, in world space. It is the same number 02 reads off the depth buffer, with one difference
// that decides everything: **it is not a picture of the screen.** It knows the ground behind the camera,
// it knows the ground off the edge of the frame, and the CPU can read it too.
//
// This is what Crest bakes ("stores the terrain height, which can then be differenced with the sea
// level") and what Unity's own Boat Attack water bakes for its shore foam.
//
// ⚠ **The difference from 01 is one word.** 01 bakes DISTANCE, so its band is a fixed width everywhere.
// This bakes HEIGHT, so the band is wide where the bottom rises gently and narrow where it drops.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 deep : source_color = vec4(0.255, 0.375, 0.410, 1.0);
uniform vec4 pale : source_color = vec4(0.560, 0.700, 0.690, 1.0);
uniform vec4 foam : source_color = vec4(0.800, 0.880, 0.895, 1.0);
// How much water, in tiles, the colour pales over.
uniform float pale_m = 0.45;
// How much water, in tiles, the shoreline lives inside. ⚠ A depth, never a distance.
uniform float foam_m = 0.09;
uniform float foam_soft = 0.55;
uniform float foam_alpha = 0.85;
// The swash rides on the depth: a wave running up a slope really does make the water briefly shallower.
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
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	float d = texture(depth_field, clamp(uv, vec2(0.0), vec2(1.0))).r * field_span;

	float w = (vnoise(p * swash_scale + vec2(t * swash_speed, 0.0)) - 0.5) * 2.0;
	d = max(d + w * swash, 0.0);

	vec3 col = mix(pale.rgb, deep.rgb, clamp(d / max(pale_m, 0.001), 0.0, 1.0));
	float f = 1.0 - smoothstep(max(foam_m, 0.001) * foam_soft, max(foam_m, 0.001), d);
	ALBEDO = mix(col, foam.rgb, clamp(f * foam_alpha, 0.0, 1.0));

	float n = vnoise(p * ripple_scale + vec2(t * 0.10, -t * 0.07));
	float n2 = vnoise(p * ripple_scale * 2.1 - vec2(t * 0.07, 0.0));
	vec3 nrm = normalize(vec3((n - n2) * ripple, 9.0, (n2 - n) * ripple));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.3));
	ROUGHNESS = mix(0.70, 0.42, f);
	SPECULAR = mix(0.28, 0.05, f);
}
