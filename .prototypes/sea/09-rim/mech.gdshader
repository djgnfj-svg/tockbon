// **Where this one gets the open water from: HOW FAR OUT FROM THE ISLAND IT IS.**
//
// **The sea's surface is not touched at all.** What is added is an EDGE: the water deepens over a long
// slow reach as it leaves the island, and one pale stroke stands far out where it finishes.
//
// **The hypothesis it is here to test**: the open sea may not read as empty because it has no texture
// but because **it has no size**. A flat colour that goes on identically forever gives the eye nothing
// to measure a crossing against — the boat is not getting anywhere. An edge is a somewhere.
//
// ⚠⚠ **THE DISTANCE IS FROM THE ISLAND AND NOT FROM THE CAMERA, AND THAT IS THE WHOLE DIFFERENCE.**
// The camera here is ORTHOGONAL and sits ninety 조각 back; under it every pixel is the same distance
// from the eye in the only sense that matters, so anything written as 「fade with distance from
// camera」 multiplies to nothing. **This repo has paid a round for exactly that.** The island's own
// middle is a fixed point in the world and it is what this reads.
//
// ⚠ **The middle is derived and not written down.** `field_origin + field_size * 0.5` is the centre of
// the baked field, which `field_view` builds as the board grown by `field_span` on every side — so it
// is the board's own middle and it moves the day a different island is loaded. **A literal here would
// be right until the next island.**
//
// ⚠ **It is radial and not the island's outline.** Following the coast makes a halo — a mark ABOUT the
// island. A circle at a distance is a horizon, which is what is being asked for.
uniform vec4 rim_deep : source_color = vec4(0.330, 0.462, 0.545, 1.0);
// **Where the deepening starts and where it has finished**, in 조각 from the island's middle.
// ⚠ 12 is outside the coast on every side; 52 is past the corner of the roamed frame.
uniform float rim_near = 12.0;
uniform float rim_far = 52.0;
uniform float rim_deep_amt = 1.0;
// **The horizon**: how far out it stands in 조각, how wide the stroke is, and how strong.
// ⚠⚠ **31 IS CHOSEN AGAINST THE TWO CAMERAS.** The opening frame's own corner is 27.9 조각 from the
// middle, so the stroke is **not in the opening picture at all** and appears only when the camera
// roams out — which is the frame this whole round exists for.
uniform float rim_line_at = 31.0;
uniform float rim_line_w = 1.40;
uniform float rim_line_amt = 0.22;
uniform vec4 rim_line_col : source_color = vec4(0.700, 0.790, 0.830, 1.0);

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	vec2 heart = field_origin + field_size * 0.5;
	float r = length(p - heart);
	vec3 c = mix(sea.rgb, rim_deep.rgb,
				 smoothstep(rim_near, max(rim_far, rim_near + 1.0), r) * rim_deep_amt);
	float line = 1.0 - smoothstep(0.0, max(rim_line_w, 0.05), abs(r - rim_line_at));
	return mix(c, rim_line_col.rgb, line * rim_line_amt);
}
