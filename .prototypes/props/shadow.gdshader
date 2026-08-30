// **The blob a tree sits in.**
//
// The reference the user handed over shows one wide, soft, dark pool under a clump — not a sharp
// cast shadow of a plane. So this is not a shadow at all: it is a disc lying on the grass, darkening
// what is already drawn there, fading to nothing at its rim.
//
// WARNING **Multiply, not alpha.** A dark translucent disc over yellow grass goes grey; multiplying
// keeps the grass its own colour and only takes light out of it.
shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength = 0.42;
// How much of the disc is solid before the fade starts.
uniform float core = 0.15;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	// smoothstep from the solid middle out to a rim that reaches zero exactly at the quad's edge.
	float a = 1.0 - smoothstep(core, 1.0, r);
	// squared, so the pool has a soft shoulder rather than a linear ramp.
	a *= a;
	ALBEDO = vec3(1.0 - strength * a);
	ALPHA = 1.0;
}
