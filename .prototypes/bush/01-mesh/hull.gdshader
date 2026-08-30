// **The island's own outline, on the bush**: the mesh again, inside out and swollen, in near-black.
// WARNING **It has to sway with the same wind or the ink slides off the leaves.** A plain
// `StandardMaterial3D` shell cannot, which is why this is a shader and not four lines of setup.
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

#include "res://.prototypes/bush/wind.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.115, 0.095, 0.080);
uniform float grow = 0.022;

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX += NORMAL * grow;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wind_push(anchor, COLOR.a);
}

void fragment() {
	ALBEDO = ink;
}
