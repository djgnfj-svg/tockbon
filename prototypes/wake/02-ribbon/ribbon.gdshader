// **The strip's own look.** Foam white, soft at both long edges, broken up by a noise that is read in
// the ribbon's OWN coordinates — so the froth travels with the water it belongs to rather than swimming
// through it. ⚠ `COLOR.a` carries the age fade, written per vertex by `wake.gd`.
shader_type spatial;
// **Unshaded like the sea**, and `cull_disabled` because a sharp turn folds this strip over itself and
// the folded part must not vanish. `depth_draw_never` so overlapping quads of one strip do not clip
// each other into hard edges.
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
	// UV.x runs across the strip, UV.y runs along it in 조각 astern.
	float across = abs(UV.x * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.30, 1.0, across);
	float n = mix(1.0, vnoise(vec2(UV.y, UV.x * 2.0) * froth_scale), froth_amt);
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a * COLOR.a * edge * n, 0.0, 1.0);
}
