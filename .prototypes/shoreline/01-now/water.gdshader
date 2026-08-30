// **01 — the band comes from DISTANCE TO THE OUTLINE.** This is what the game ships today, cut down to
// the mechanism: the shipped shader carries about forty dials and none of them is the thing being
// judged here.
//
// A field baked on the CPU holds, per texel, the signed distance to the waterline. The shoreline is
// drawn where that distance is small. ⚠ **Nothing here knows how deep the water is** — the band is a
// fixed distance from the outline, so **its width is the same everywhere on the coast whatever the
// ground under it does.**
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;

uniform vec4 deep : source_color = vec4(0.255, 0.375, 0.410, 1.0);
uniform vec4 foam : source_color = vec4(0.800, 0.880, 0.895, 1.0);
// The band's width, in TILES from the outline. ⚠ This is the whole shoreline, and it is a distance.
uniform float band_tiles = 0.25;
uniform float band_alpha = 0.34;
// The hairline that is there whatever the band is doing.
uniform float line_tiles = 0.045;
uniform float line_alpha = 0.30;
// How much the band's width swings, and how slowly it changes along the coast.
uniform float swing = 0.80;
uniform float swing_scale = 0.25;
uniform float swing_speed = 0.11;
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
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	// Signed: negative inland, positive out to sea, in tiles.
	float d = (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;

	float w = (vnoise(p * swing_scale + vec2(TIME * swing_speed, 0.0)) - 0.5) * 2.0;
	float bw = max(band_tiles, 0.001) * max(1.0 + swing * w, 0.12);
	float band = 1.0 - smoothstep(0.0, bw, d);
	float line = 1.0 - smoothstep(max(line_tiles, 0.0001) * 0.55, max(line_tiles, 0.0001), d);

	float f = clamp(band * band_alpha + line * line_alpha, 0.0, 1.0);
	ALBEDO = mix(deep.rgb, foam.rgb, f);

	float t = TIME;
	float n = vnoise(p * ripple_scale + vec2(t * 0.10, -t * 0.07));
	float n2 = vnoise(p * ripple_scale * 2.1 - vec2(t * 0.07, 0.0));
	vec3 nrm = normalize(vec3((n - n2) * ripple, 9.0, (n2 - n) * ripple));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nrm, 0.0)).xyz, 0.3));
	ROUGHNESS = mix(0.70, 0.42, f);
	SPECULAR = mix(0.28, 0.05, f);
}
