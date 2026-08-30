// **Three standing quads crossed through each other**, each wearing the picture of the same clump.
// WARNING **They do NOT turn.** That is the whole point of this candidate: the bush has a real
// footprint on the ground, so it can throw a real shadow and the camera may orbit past it.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://.prototypes/bush/wind.gdshaderinc"

uniform sampler2D card : source_color, filter_linear;

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// **The weight comes off the UV**: v is 0 at the top of the card and 1 at its foot.
	vec3 push = wind_push(anchor, 1.0 - UV.y);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
}

void fragment() {
	vec4 c = texture(card, UV);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	// A flat plane has one normal, so lit straight it reads as a wall. Facing it up softens that.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.55));
}
