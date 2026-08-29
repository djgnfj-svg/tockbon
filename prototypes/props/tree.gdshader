// **A standing card that turns with the camera and is LIT.**
//
// Two things a `Sprite3D` could not do, which is why this exists instead of one:
//   - it carries a NORMAL MAP, so the card's crown bulges toward the sun instead of reading flat;
//   - it billboards in the VERTEX shader, which is where Bad North does it too (its own developer,
//     on the forests: "they are just billboarding planes, and we do that billboarding in the vertex
//     shader instead of doing it in C# because that would be quite slow").
//
// WARNING **Y-locked on purpose.** A fully free billboard lies down when the camera tilts, and this
// game's camera tilts on R/F.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D card : source_color, filter_linear, repeat_disable;
uniform sampler2D card_n : hint_normal, filter_linear, repeat_disable;
uniform float normal_depth = 1.0;
// WARNING **The card is already a FINISHED colour, not an albedo.** Handing it to the renderer raw
// and letting this game's sun plus ambient multiply it turned a dark sage crown into pale mint. This
// scales it back down so the light only carves shape into the card instead of washing it out.
uniform float tint = 0.8;
// **The ink pass** — the same card drawn dark, swollen and pushed away from the camera.
uniform bool silhouette = false;
uniform vec4 ink : source_color = vec4(0.115, 0.095, 0.080, 1.0);

// **The wind, lifted from `prototypes/bush/wind.gdshaderinc`.**
// WARNING **The weight is ZERO at the roots.** Every source on foliage sway names the base lifting
// off the ground as the one gotcha, and a zero weight at the foot is the whole cure -- so the crown
// leans and the trunk stays planted.
uniform vec2 wind_dir = vec2(0.83, 0.56);
uniform float wind_strength = 0.075;
uniform float wind_speed = 2.1;

vec3 wind_push(vec3 anchor, float weight) {
	// The anchor is the tree's own world origin, which is what keeps two trees off lockstep.
	float phase = dot(anchor.xz, vec2(0.73, 0.41)) * 2.7;
	float gust = 0.55 + 0.45 * sin(TIME * 0.41 + phase * 0.19);
	float s = sin(TIME * wind_speed + phase) * 0.62
			+ sin(TIME * wind_speed * 1.87 + phase * 1.7) * 0.38;
	float w = weight * weight;
	return vec3(wind_dir.x, 0.0, wind_dir.y) * (s * gust * wind_strength * w);
}

void vertex() {
	// The standard Y-locked billboard: keep the world up axis, take right and forward from the view.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, up));
	mat4 b = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	// WARNING **The scale has to be carried across by hand.** The billboard basis above is unit
	// length, so a card built at 3.2 metres comes out one metre without these two lines.
	b[0] *= length(MODEL_MATRIX[0]);
	b[1] *= length(MODEL_MATRIX[1]);
	MODELVIEW_MATRIX = VIEW_MATRIX * b;
	// **The sway.** UV.y is 0 at the TOP of a QuadMesh, so the weight is its complement: the crown
	// takes the whole push and the foot none of it.
	// WARNING **It leans the VERTEX, not the card's origin.** Pushing `b[3]` slides the whole card
	// sideways, trunk and all, which is the one thing every source on foliage sway warns against.
	// Only the world push that lies along the card's own right axis can be seen, so that is what is
	// taken -- and it is divided by the card's scale because VERTEX is still in local space.
	vec3 blow = wind_push(MODEL_MATRIX[3].xyz, 1.0 - UV.y);
	VERTEX.x += dot(blow, right) / max(length(MODEL_MATRIX[0]), 0.0001);
	// WARNING **Without this the lighting keeps the node's ORIGINAL rotation** while the quad turns,
	// and the sun appears to swing around the tree as the camera orbits.
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(card, UV);
	// **Cut, not blended**, so cards behind cards sort on the depth buffer instead of on draw order.
	if (c.a < 0.5) {
		discard;
	}
	if (silhouette) {
		ALBEDO = ink.rgb;
		// The ink is a solid shape: no normal map, and it is not lit.
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else {
		ALBEDO = c.rgb * tint;
		NORMAL_MAP = texture(card_n, UV).xyz;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
