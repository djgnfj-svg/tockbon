// **A prop drawn as one turning card, with its own wind and its own ink.**
//
// ⚠⚠ **THE WHOLE BAD NORTH PACKAGE OR NONE OF IT.** A billboard gets away with being flat only
// alongside the rest of what that game does: the card turns in the VERTEX shader, it is unlit, it
// casts no shadow, and **its outline is a second darker copy pushed back and swollen — never an
// inverted hull.** Take the card without the package and you get the two things its own developer
// named: clipping to fight, and outlines that stop being clean.
//
// Oskar Stalberg, Konsoll 2018, 19:10 — "they are just billboarding planes, and we do that
// billboarding in the vertex shader instead of doing it in C# because that would be quite slow."
//
// ⚠ **Grown out of `.prototypes/bush/`**, where it was one of three candidates and the wind lived in
// a shared include. The include is folded in here because the other two candidates stayed behind.
shader_type spatial;
render_mode cull_disabled, unshaded;

// ⚠⚠ **`repeat_disable` AND IT IS NOT TIDINESS.** A sampler that repeats wraps UV.y = 0 round to the
// texture's LAST row, which on a bush picture is the one solid row of plant — so a thin black bar
// drew across the top edge of every card, a full 0.18 조각 clear of the plant it belonged to.
uniform sampler2D card : source_color, filter_nearest, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

// **The dark copy.** `silhouette` turns the whole draw into it: swollen a little and pushed away
// from the camera, so what survives around the picture is a rim.
uniform bool silhouette = false;
uniform vec3 ink : source_color = vec3(0.115, 0.095, 0.080);
uniform float back_push = 0.035;
uniform float swell = 0.055;

// ⚠⚠ **THE CLOCK IS A UNIFORM, NOT `TIME`.** The meshes lean off `field_view`'s own wind clock, and
// a card reading `TIME` would drift out of step with the bush standing next to it. **One clock, set
// from one place**, is also what lets a probe photograph a chosen instant twice and get one picture.
uniform float wind_t = 0.0;
uniform vec2 wind_dir = vec2(0.83, 0.56);
uniform float wind_strength = 0.075;
uniform float wind_speed = 2.1;
// What the camera's pitch takes off an upright card, paid back (개발지식 01 기법 22). ⚠ **It cannot
// be the node's scale**: the billboard below rebuilds the basis from the VIEW matrix and throws the
// model basis — and with it any node scale — away.
uniform float stretch = 1.0;

// `anchor` is the card's own world origin, which is what keeps two of them from moving in lockstep.
vec3 wind_push(vec3 anchor, float weight) {
	float phase = dot(anchor.xz, vec2(0.73, 0.41)) * 2.7;
	float gust = 0.55 + 0.45 * sin(wind_t * 0.41 + phase * 0.19);
	float s = sin(wind_t * wind_speed + phase) * 0.62
			+ sin(wind_t * wind_speed * 1.87 + phase * 1.7) * 0.38;
	// ⚠ **Squared, so the weight is 0 at the roots.** Every source names the base lifting off the
	// ground as the one gotcha of this technique, and a zero weight is the whole cure.
	float w = weight * weight;
	return vec3(wind_dir.x, 0.0, wind_dir.y) * (s * gust * wind_strength * w);
}

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Y-billboard: face the camera about the upright axis only, so the card never lies down.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	vec3 v = VERTEX;
	// the quad is authored with its foot on y = 0, so the stretch lifts the top and never the base
	v.y *= stretch;
	if (silhouette) {
		v.x *= 1.0 + swell;
		v.y *= 1.0 + swell;
		v.z -= back_push;
	}
	// ⚠⚠ **The push is a WORLD vector and this vertex is in BILLBOARD space**, whose x is the
	// camera's right. Projecting it is the difference between a card leaning downwind and a card
	// leaning whichever way the camera happens to be pointing.
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
