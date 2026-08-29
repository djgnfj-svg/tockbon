shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// **Patchy turf, keyed off world position and nothing else.**
//
// Two noises: a fine one that makes the individual tufts, and a wide slow one that makes whole
// stretches thin out — without the second the speckle is even, and an even speckle reads as a
// texture the artist put there rather than as ground that grows differently where it is walked.

uniform vec3 turf_col = vec3(0.94, 0.97, 0.86);
uniform float tuft_scale = 5.5;    // tufts per tile
uniform float patch_scale = 0.22;  // one patch is about four tiles
uniform float amount = 0.55;       // how much of the walkable ground is covered
uniform float strength = 0.5;      // how far a tuft is pulled toward `turf_col`

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float tuft = vnoise(p * tuft_scale);
	// The wide patch decides how much of the fine noise survives here.
	float patch = vnoise(p * patch_scale + vec2(19.0, 7.0));
	float cut = mix(0.75, 0.30, patch) * (1.0 - amount) + (1.0 - amount) * 0.15;
	float a = smoothstep(cut, cut + 0.16, tuft);
	ALBEDO = turf_col;
	ALPHA = a * strength;
}
