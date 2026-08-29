// **01 — WHAT THE GAME SHIPS TODAY.** The baseline, and it is here so that every other candidate is
// judged against the real thing rather than against a memory of it.
//
// **Four motions run at once and none is in step with the others**: the line's shape is bent by three
// octaves of noise, its width breathes on a phase that varies along the coast, once a cycle a line
// lets go and travels seaward, and a wide slow patch map keeps some stretches quiet.
//
// ⚠⚠ **NOTHING HERE KNOWS WHICH WAY THE LAND IS.** Every one of the four reads noise at a world
// position and nothing else — the field is sampled once, for a distance, and its gradient is never
// taken. **That is why the motion is a shimmer in place rather than water going somewhere**: a phase
// that varies from spot to spot is not a wave that travels, it is a row of spots each on its own clock.
shader_type spatial;
render_mode unshaded;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 sea : source_color = vec4(0.430, 0.590, 0.660, 1.0);
uniform vec4 foam : source_color = vec4(0.900, 0.940, 0.950, 1.0);

uniform float line_tiles = 0.075;
uniform float line_hard = 0.45;
uniform float line_alpha = 0.90;

uniform float warp_a = 0.055;
uniform float warp_a_scale = 0.45;
uniform float warp_a_speed = 0.055;
uniform float warp_b = 0.030;
uniform float warp_b_scale = 1.30;
uniform float warp_b_speed = 0.130;
uniform float warp_c = 0.014;
uniform float warp_c_scale = 3.60;
uniform float warp_c_speed = 0.260;

uniform float swing = 0.75;
uniform float swing_rate = 0.55;
uniform float along_scale = 0.55;
uniform float swing_floor = 0.18;

uniform float peel = 0.55;
uniform float peel_tiles = 0.42;
uniform float peel_gate_scale = 0.85;

uniform float calm = 0.45;
uniform float calm_scale = 0.38;
uniform float calm_speed = 0.035;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float sdf(vec2 p) {
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	return (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float d = sdf(p);

	float w = (vnoise(p * warp_a_scale + vec2(t * warp_a_speed, t * warp_a_speed * 0.35)) - 0.5)
			  * 2.0 * warp_a
			+ (vnoise(p * warp_b_scale - vec2(t * warp_b_speed * 0.4, t * warp_b_speed)) - 0.5)
			  * 2.0 * warp_b
			+ (vnoise(p * warp_c_scale + vec2(-t * warp_c_speed, t * warp_c_speed * 0.8)) - 0.5)
			  * 2.0 * warp_c;
	d += w;

	float live = mix(1.0 - calm, 1.0,
					 smoothstep(0.25, 0.75,
								vnoise(p * calm_scale + vec2(t * calm_speed, -t * calm_speed))));

	float along = vnoise(p * along_scale + vec2(11.0, 5.0));
	float ph = t * swing_rate + along * 6.2831853;
	float breathe = mix(swing_floor, 1.0 + swing,
						(sin(ph) * 0.5 + 0.5) * live + (1.0 - live) * 0.5);
	float bw = max(line_tiles, 0.0001) * breathe;
	float band = 1.0 - smoothstep(bw * line_hard, bw, d);

	if (peel > 0.001) {
		float age = fract(ph / 6.2831853);
		float away = age * peel_tiles;
		float pw = max(line_tiles, 0.0001) * 1.1;
		float hump = exp(-pow((d - away) / pw, 2.0)) * (1.0 - age);
		float where = smoothstep(0.35, 0.72, vnoise(p * peel_gate_scale + vec2(3.0, 17.0)));
		band = max(band, hump * where * peel * live);
	}

	ALBEDO = mix(sea.rgb, foam.rgb, clamp(band * line_alpha, 0.0, 1.0));
}
