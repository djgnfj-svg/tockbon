shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// **The whole mechanism is two lines in the vertex stage.**
//
// `UV2` is the delta from where this ring point rests to where it stands when the 칸 has closed up, so
// the merge is a walk along it. ⚠ **The mesh never changes** — only where its points are.

uniform float merge : hint_range(0.0, 1.0) = 0.0;

#include "res://prototypes/merge/hover.gdshaderinc"

varying float v_hov;

void vertex() {
	VERTEX.x += UV2.x * merge;
	VERTEX.z += UV2.y * merge;
	v_hov = hover_of(UV, merge);
	VERTEX.y += v_hov * hover_lift;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0), v_hov * hover_light);
	ALPHA = mix(COLOR.a, hover_alpha, v_hov);
}
