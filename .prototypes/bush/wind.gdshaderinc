// **One wind for all three candidates.**
//
// WARNING **The time is a uniform, not `TIME`.** Every candidate is photographed at the same
// `wind_t`, so the three strips of the moving picture are the same instant three times. With `TIME`
// they would each be at whatever phase the shoot happened to reach, and the sheet would compare
// phases instead of mechanisms.
//
// The weight is the thing each mechanism supplies differently: the mesh reads it out of the baked
// vertex alpha, the quads read it off the UV. **0 at the roots** -- every source names the base
// lifting off the ground as the one gotcha, and a zero weight is the whole cure.

uniform float wind_t = 0.0;
uniform vec2 wind_dir = vec2(0.83, 0.56);
uniform float wind_strength = 0.075;
uniform float wind_speed = 2.1;

// `anchor` is the bush's own world origin, which is what keeps two bushes from moving in lockstep.
vec3 wind_push(vec3 anchor, float weight) {
	float phase = dot(anchor.xz, vec2(0.73, 0.41)) * 2.7;
	float gust = 0.55 + 0.45 * sin(wind_t * 0.41 + phase * 0.19);
	float s = sin(wind_t * wind_speed + phase) * 0.62
			+ sin(wind_t * wind_speed * 1.87 + phase * 1.7) * 0.38;
	float w = weight * weight;
	return vec3(wind_dir.x, 0.0, wind_dir.y) * (s * gust * wind_strength * w);
}
