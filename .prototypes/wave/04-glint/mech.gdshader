// **THE WATER STAYS FLAT AND ONLY THE SUN'S GLINT MOVES.**
//
// The diffuse light is untouched — the sea is the same colour it ships with, corner to corner. The only
// thing added is a **specular highlight so narrow that it appears on almost nothing**: the handful of
// slopes that happen to face the sun back at the camera. Everywhere else there is no wave at all.
//
// ⚠⚠ **IT IS THE ONLY CANDIDATE THAT IS SILENT BY DEFAULT AND LOUD IN A FEW PLACES**, which is what
// 「살짝」 actually looks like on water. Every other version here changes every pixel of the sea a
// little; this one changes almost none of it a lot.
// ⚠ **A highlight on the sea was deleted once and this is not that.** What went on 2026-08-28 was the
// broad sheen of a lit flat plane — one soft bright region covering a third of the water. A glint at
// `gl_tight` 220 is a scatter of sparks a few pixels across.
uniform float gl_len = 11.0;
uniform float gl_len2 = 6.2;
uniform float gl_speed = 0.38;
uniform vec2 gl_dir = vec2(0.82, 0.57);
uniform float gl_steep = 1.5;
// **How tight the highlight is.** ⚠⚠ The whole dial between 「반짝인다」 and 「기름막」. Below about 60 it
// stops being sparks and becomes the sheen this replaced.
uniform float gl_tight = 90.0;
uniform float gl_amt = 0.55;
// ⚠ **Where the sparks are allowed to be at all** — a wide slow patch map, so the sun's road is a
// stretch of the sea rather than the whole of it.
uniform float gl_patch = 0.72;
uniform float gl_patch_scale = 0.035;

float gl_h(vec2 pp, float t) {
	vec2 a = normalize(gl_dir);
	vec2 b = normalize(vec2(-a.y, a.x) + a * 0.40);
	return sin(dot(pp, a) * 6.2831853 / max(gl_len, 0.3) + t * gl_speed) * 0.60
		 + sin(dot(pp, b) * 6.2831853 / max(gl_len2, 0.3) - t * gl_speed * 0.77) * 0.40;
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	return sea.rgb;
}

// ⚠⚠ **THE PATCH MAP IS FOLDED INTO THE SLOPE, NOT PASSED TO `light()`.** A varying cannot be assigned
// inside a called function — Godot refuses it outright — and `light()` never learns the world position.
// **Flattening the water where the patch is quiet has the same effect for free**: a level surface
// cannot catch a glint, so the sparks stop without the highlight term knowing anything about it.
vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm) {
	float e = 0.09;
	float patch = mix(1.0 - gl_patch, 1.0,
					  smoothstep(0.30, 0.72,
								 vnoise(p * gl_patch_scale + vec2(t * 0.02, -t * 0.015))));
	float k = away(sdf(p)) * patch;
	float gx = gl_h(p + vec2(e, 0.0), t) - gl_h(p - vec2(e, 0.0), t);
	float gy = gl_h(p + vec2(0.0, e), t) - gl_h(p - vec2(0.0, e), t);
	return to_view(vec3(-gx * gl_steep * k, 2.0 * e, -gy * gl_steep * k), vm);
}

void light() {
	// **The diffuse is the flat sea, exactly as it ships.** No slope changes it.
	DIFFUSE_LIGHT += vec3(shade_of(ATTENUATION));
	vec3 h = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), max(gl_tight, 4.0));
	SPECULAR_LIGHT += vec3(s * gl_amt * ATTENUATION) * LIGHT_COLOR;
}
