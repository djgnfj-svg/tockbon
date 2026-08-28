// **06 — the SURFACE ITSELF MOVES, and the shoreline is where it lands.**
//
// Every other version on this sheet paints on a plane that never moves: the swash is a band whose WIDTH
// is animated. Here the sea's height is animated instead, and the shoreline follows because **the water
// level really is higher or lower against the slope from one moment to the next.** That is what a swash
// is; the others are drawings of one.
//
// ⚠ **This needs the plane subdivided** — a flat quad has four corners and there is nothing to push.
// The lab subdivides it 160x160 for exactly this version.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;
uniform float sea_y = 0.075;

uniform vec4 deep : source_color = vec4(0.255, 0.375, 0.410, 1.0);
uniform vec4 pale : source_color = vec4(0.560, 0.700, 0.690, 1.0);
uniform vec4 foam : source_color = vec4(0.800, 0.880, 0.895, 1.0);
// **How far the surface actually rises and falls, in tiles.** This is the whole animation.
uniform float lift = 0.055;
uniform float lift_speed = 0.45;
uniform float lift_scale = 0.55;
// Small chop on top, so the sea is not one breathing sheet.
uniform float chop = 0.012;
uniform float chop_scale = 3.4;
uniform float pale_m = 0.45;
uniform float foam_m = 0.075;
uniform float foam_soft = 0.5;
uniform float foam_alpha = 0.85;

varying float v_rise;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
			   mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float swell = (vnoise(p * lift_scale + vec2(TIME * lift_speed, TIME * lift_speed * 0.4)) - 0.5) * 2.0;
	float ch = (vnoise(p * chop_scale - vec2(TIME * 0.6, 0.0)) - 0.5) * 2.0;
	v_rise = swell * lift + ch * chop;
	VERTEX.y += v_rise;
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	// The baked field says how deep the water is when the sea is at rest. **Add how far it has risen and
	// it says how deep the water is NOW** — which is the whole point of moving the surface.
	float d = max(texture(depth_field, clamp(uv, vec2(0.0), vec2(1.0))).r * field_span + v_rise, 0.0);

	vec3 col = mix(pale.rgb, deep.rgb, clamp(d / max(pale_m, 0.001), 0.0, 1.0));
	float f = 1.0 - smoothstep(max(foam_m, 0.001) * foam_soft, max(foam_m, 0.001), d);
	ALBEDO = mix(col, foam.rgb, clamp(f * foam_alpha, 0.0, 1.0));
	ROUGHNESS = mix(0.68, 0.40, f);
	SPECULAR = mix(0.30, 0.06, f);
}
