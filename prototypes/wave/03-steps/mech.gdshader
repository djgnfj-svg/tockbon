// **THE SAME SLOPES, BUT THE LIGHT IS CUT INTO STEPS BEFORE IT LANDS.**
//
// The surface is bent exactly as `02-ripple` bends it. What changes is the READING: the lambert term is
// quantised to a handful of levels, so a smooth slope produces a **hard-edged shape** instead of a
// gradient. This is cel shading applied to water rather than to a character, and it is the one thing
// that turns a normal-mapped sea from a haze into a drawing.
//
// ⚠⚠ **THIS IS THE ANSWER TO WHY 티켓 05 FAILED.** That round found the ripple *"reads as an airbrushed
// smudge at every setting"* on a board of flat cartoon blocks — and every setting it tried was a
// SMOOTH one. **A step is not a dial on smoothness; it is a different reading of the same number.**
// ⚠ Alexander Ameye's stylised-water breakdown reaches for `Posterize` for the same reason, one stage
// earlier: the depth fade only reads as stylised once it is cut.
uniform float st_len = 15.0;
uniform float st_len2 = 8.6;
uniform float st_speed = 0.30;
uniform vec2 st_dir = vec2(0.82, 0.57);
uniform float st_steep = 0.85;
uniform float st_gain = 0.55;
// **How many levels the light is allowed.** ⚠⚠ Two is a hard cartoon sea; above about five the steps
// fall under a pixel at the opening zoom and it is `02-ripple` again with extra cost.
uniform float st_levels = 3.0;
// **How hard each step's edge is**, as a fraction of one level. 0 is a cut.
uniform float st_soft = 0.10;

float st_h(vec2 pp, float t) {
	vec2 a = normalize(st_dir);
	vec2 b = normalize(vec2(-a.y, a.x) + a * 0.40);
	return sin(dot(pp, a) * 6.2831853 / max(st_len, 0.3) + t * st_speed) * 0.62
		 + sin(dot(pp, b) * 6.2831853 / max(st_len2, 0.3) - t * st_speed * 0.81) * 0.38;
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	return sea.rgb;
}

vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm) {
	float e = 0.12;
	float k = away(sdf(p));
	float gx = st_h(p + vec2(e, 0.0), t) - st_h(p - vec2(e, 0.0), t);
	float gy = st_h(p + vec2(0.0, e), t) - st_h(p - vec2(0.0, e), t);
	return to_view(vec3(-gx * st_steep * k, 2.0 * e, -gy * st_steep * k), vm);
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lv = max(st_levels, 1.0);
	// ⚠ The step is taken on the term AFTER the flat sea has been divided out, so level boundaries sit
	// around the flat water rather than around an arbitrary lambert value.
	float x = nl / max(flat_nl, 0.05);
	float q = floor(x * lv);
	float f = fract(x * lv);
	float stepped = (q + smoothstep(0.5 - max(st_soft, 0.001), 0.5 + max(st_soft, 0.001), f)) / lv;
	DIFFUSE_LIGHT += vec3(mix(1.0, stepped, st_gain) * shade_of(ATTENUATION));
}
