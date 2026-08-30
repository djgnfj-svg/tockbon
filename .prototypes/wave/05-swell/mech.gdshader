// **THE MESH REALLY MOVES, AND ONLY THE LIGHT SHOWS IT.**
//
// The vertices are displaced by a long low swell and the normal is taken from that same height — so
// unlike every other version here, **there is a real surface to light**, not a flat plane wearing a
// borrowed normal. It is Bad North's own sea in Oskar Stalberg's words at Konsoll 2018: *a mesh here
// that plays this sort of looping wavy shader*.
//
// ⚠⚠ **NOT `.prototypes/sea/03-swell`, WHICH THE USER TURNED DOWN.** That one displaced the mesh and
// then threw the height away, picking between two COLOURS through a hard window — which is why it came
// out as zig-zag corduroy. **Here the height is never read as colour.** The only thing that happens to
// it is the sun.
//
// ⚠ **Sines rather than Gerstner** is a choice DREDGE already paid for and reversed: *they had the
// unfortunate side effect of turning most of our waves into ramps*.
// ⚠⚠ **The swell is faded to nothing near the rock** so the shoreline — the control in this lab — cannot
// move.
// ⚠⚠ **0.30 WAS INVISIBLE AND THE SHEET PROVED IT.** A swell a third of a tile tall spread over twenty
// tiles is a slope of under a degree, and the sun cannot find a slope that shallow — the picture came
// out identical to `01-shadow`. **A long swell has to be TALL to be a swell at all**, which is this
// candidate's real cost and not a tuning slip.
uniform float sw_h = 1.30;
uniform float sw_len = 20.0;
uniform float sw_len2 = 11.5;
uniform float sw_speed = 0.30;
uniform vec2 sw_dir = vec2(0.80, 0.60);
uniform float sw_gain = 0.60;
uniform float sw_hold = 0.7;
uniform float sw_free = 3.2;

// ⚠ `sdf()` samples with `texture()`, which has no gradients in a vertex shader. Same read, explicit LOD.
float sw_sdf(vec2 pp) {
	vec2 uv = (pp - field_origin) / max(field_size, vec2(1.0));
	return (textureLod(land_field, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r * 2.0 - 1.0) * field_span
		   + shore_offset;
}

float sw_h_at(vec2 pp, float t) {
	vec2 a = normalize(sw_dir);
	vec2 b = normalize(vec2(-a.y, a.x) + a * 0.45);
	float u = sin(dot(pp, a) * 6.2831853 / max(sw_len, 0.5) + t * sw_speed) * 0.64
			+ sin(dot(pp, b) * 6.2831853 / max(sw_len2, 0.5) - t * sw_speed * 0.73) * 0.36;
	return u * sw_h * 0.5 * smoothstep(sw_hold, sw_free, sw_sdf(pp));
}

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sw_h_at(wp, TIME);
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	return sea.rgb;
}

vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm) {
	// ⚠⚠ **Taken analytically, not from the mesh.** The sea plane is two tiles a quad; a normal read off
	// that geometry is one value per quad and the swell would come out as facets rather than as a curve.
	float e = 0.25;
	float gx = sw_h_at(p + vec2(e, 0.0), t) - sw_h_at(p - vec2(e, 0.0), t);
	float gy = sw_h_at(p + vec2(0.0, e), t) - sw_h_at(p - vec2(0.0, e), t);
	return to_view(vec3(-gx, 2.0 * e, -gy), vm);
}

void light() {
	DIFFUSE_LIGHT += vec3(relief(clamp(dot(NORMAL, LIGHT), 0.0, 1.0), sw_gain)
						  * shade_of(ATTENUATION));
}
