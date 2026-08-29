// **THE SURFACE IS BENT AND THE SUN FINDS IT. Nothing is drawn.**
//
// Two crossed sine trains, long and slow, tilt the water's normal. **The colour is never touched** —
// every light and dark on this sea is the sun landing on a slope. It is the plainest true way to make
// water look like water and it is what the old shader did before 2026-08-28.
//
// ⚠⚠ **THIS ONE HAS ALREADY BEEN JUDGED ONCE AND IT LOST** (티켓 05). Seven ripples were rendered side
// by side and *"the four that only moved the old dials could not be told apart: they are all the same
// soft haze, because the ripple only ever bent the surface normal and left the light to find it."*
// **It is in this set anyway, because that round ran on a sea that took no light at all** — the smudge
// it produced was a fake highlight painted in albedo, not the sun on a slope. This is the honest
// version of the thing that lost, and the sheet says whether the verdict survives being done properly.
uniform float rip_len = 15.0;
uniform float rip_len2 = 8.6;
uniform float rip_speed = 0.30;
uniform vec2 rip_dir = vec2(0.82, 0.57);
// **How steep the slopes are.** ⚠ This is the whole dial between glassy and choppy.
uniform float rip_steep = 0.85;
// **How much of the lambert swing is allowed through.** 0 is the flat sea; 1 is the full range.
uniform float rip_gain = 0.55;


float rip_h(vec2 pp, float t) {
	vec2 a = normalize(rip_dir);
	vec2 b = normalize(vec2(-a.y, a.x) + a * 0.40);
	return sin(dot(pp, a) * 6.2831853 / max(rip_len, 0.3) + t * rip_speed) * 0.62
		 + sin(dot(pp, b) * 6.2831853 / max(rip_len2, 0.3) - t * rip_speed * 0.81) * 0.38;
}

vec3 rip_world_normal(vec2 pp, float t, float k) {
	float e = 0.12;
	float gx = rip_h(pp + vec2(e, 0.0), t) - rip_h(pp - vec2(e, 0.0), t);
	float gy = rip_h(pp + vec2(0.0, e), t) - rip_h(pp - vec2(0.0, e), t);
	return vec3(-gx * rip_steep * k, 2.0 * e, -gy * rip_steep * k);
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	return sea.rgb;
}

vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm) {
	vec3 nw = rip_world_normal(p, t, away(sdf(p)));
	return to_view(nw, vm);
}

void light() {
	DIFFUSE_LIGHT += vec3(relief(clamp(dot(NORMAL, LIGHT), 0.0, 1.0), rip_gain)
						  * shade_of(ATTENUATION));
}
