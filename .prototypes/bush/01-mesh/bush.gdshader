// **Real geometry.** The clump is the baked mesh; the leaves bend because their vertices move.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://.prototypes/bush/wind.gdshaderinc"

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// COLOR.a is the sway weight the bake wrote: 0 at the roots, 1 at the tips.
	vec3 push = wind_push(anchor, COLOR.a);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
