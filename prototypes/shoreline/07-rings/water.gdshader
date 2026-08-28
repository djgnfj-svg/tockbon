// **07 — the sea draws NO shoreline at all.** It is a plain surface; the shoreline is real geometry
// laid on top of it by `scene.gd`. See that file for the mechanism.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.255, 0.375, 0.410, 1.0);
uniform float ripple = 0.5;
uniform float ripple_scale = 2.6;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	ALBEDO = deep.rgb;
	float n = vnoise(p * ripple_scale + vec2(t * 0.10, -t * 0.07));
	float n2 = vnoise(p * ripple_scale * 2.1 - vec2(t * 0.07, 0.0));
	vec3 nrm = normalize(vec3((n - n2) * ripple, 9.0, (n2 - n) * ripple));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.3));
	ROUGHNESS = 0.70;
	SPECULAR = 0.28;
}
