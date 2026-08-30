// **The Bad North package**: one plane, turned to the camera in the VERTEX shader, unlit, and its
// outline is a second darker copy pushed back and out rather than an inverted hull.
//
// Oskar Stalberg, Konsoll 2018, 19:10 -- "they are just billboarding planes, and we do that
// billboarding in the vertex shader instead of doing it in C# because that would be quite slow."
shader_type spatial;
render_mode cull_disabled, unshaded;

#include "res://.prototypes/bush/wind.gdshaderinc"

uniform sampler2D card : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
// The dark copy: pushed AWAY from the camera and swollen a little, so what survives around the
// picture is a rim. **`silhouette` turns the whole thing into that copy.**
uniform bool silhouette = false;
uniform vec3 ink : source_color = vec3(0.115, 0.095, 0.080);
uniform float back_push = 0.035;
uniform float swell = 0.055;

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Y-billboard: face the camera around the upright axis only, so the bush never lies down.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	vec3 v = VERTEX;
	if (silhouette) {
		v.x *= 1.0 + swell;
		v.y = v.y * (1.0 + swell);
		v.z -= back_push;
	}
	// WARNING **The push is a WORLD vector and this vertex is in billboard space**, whose x is the
	// camera's right. Projecting it is the difference between a bush leaning downwind and a bush
	// leaning whichever way the camera happens to be looking.
	vec3 pushw = wind_push(anchor, 1.0 - UV.y);
	v.x += dot(pushw, INV_VIEW_MATRIX[0].xyz);
	VERTEX = v;
}

void fragment() {
	vec4 c = texture(card, UV);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = silhouette ? ink : c.rgb * tint;
}
