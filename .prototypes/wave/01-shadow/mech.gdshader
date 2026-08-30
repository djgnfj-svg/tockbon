// **THE SHADOW AND NOTHING ELSE. This is the floor of the sheet, not a candidate.**
//
// The water keeps the flat colour it ships with, keeps its normal pointing straight up, and the only
// thing that ever changes it is **the island standing between it and the sun**. Every other version in
// this lab is this plus one idea, so this is what「그림자만으로 충분한가」 is answered against.
//
// ⚠⚠ **It is also the cheapest true statement about the sea that this game can make.** Nothing here is
// a pattern, a noise or a wave; it is one fact — the island is a solid object sitting in the light.

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	return sea.rgb;
}

vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm) {
	return n;
}

void light() {
	DIFFUSE_LIGHT += vec3(shade_of(ATTENUATION));
}
