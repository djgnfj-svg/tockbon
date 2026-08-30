shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// **Alpha only.** Whoever uses this hands it two meshes and says which one belongs to the merged
// board; the other is the resting one, and they cross over.
//
// `mode`: 0 = always on · 1 = fades IN as the camera pulls back · 2 = fades OUT as it does.

uniform float merge : hint_range(0.0, 1.0) = 0.0;
uniform int mode = 0;

#include "res://.prototypes/merge/hover.gdshaderinc"

varying float v_hov;

void vertex() {
	v_hov = hover_of(UV, merge);
	VERTEX.y += v_hov * hover_lift;
}

void fragment() {
	float a = COLOR.a;
	if (mode == 1) { a *= merge; }
	if (mode == 2) { a *= 1.0 - merge; }
	// ⚠ **The hover cannot bring back a board that has faded out.** It brightens what is being
	// drawn; a mesh at zero alpha stays at zero, which is why the lit 칸 hands over cleanly.
	ALBEDO = mix(COLOR.rgb, vec3(1.0), v_hov * hover_light);
	ALPHA = mix(a, min(hover_alpha, a * 2.4), v_hov);
}
