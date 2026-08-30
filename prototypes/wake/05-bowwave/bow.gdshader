// **The bow wave's own look.** The same foam white as the other candidates, soft across, broken by a
// noise read in the mesh's own coordinates — which here means it is fixed to the boat and travels with
// it. ⚠ **That is a property of the mechanism, not an oversight**: this wake belongs to the hull, not
// to the water.
shader_type spatial;
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
	float across = abs(UV.x * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.25, 1.0, across);
	float n = mix(1.0, vnoise(vec2(UV.y, UV.x * 2.0) * froth_scale), froth_amt);
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a * COLOR.a * edge * n, 0.0, 1.0);
}
