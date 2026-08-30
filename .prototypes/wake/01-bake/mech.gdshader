// **01-bake — the boat PAINTS into a texture and the water reads it.**
//
// This is an extension of the one thing in this repo that already works this way: `FieldView` bakes a
// signed distance field of the coastline into an `ImageTexture` and this same shader samples it every
// frame. The wake buffer is the same idea with the boat as the brush.
//
// ⚠⚠ **The buffer does not hold ALPHA, it holds WHEN and HOW FAR OFF THE CENTRELINE.** A texel keeps
// the moment the stern passed it (`r`) and its own distance from the boat's track at that moment (`g`).
// **That is what lets a static bake widen.** Storing a finished alpha would freeze the trail at the
// width it was stamped, and a wake that does not open out astern reads as a painted stripe.
uniform sampler2D wake_field : filter_linear;
uniform vec2 wake_org;
uniform vec2 wake_size;
uniform float wake_t;
uniform float wake_life;
// Half the trail's width where it leaves the stern, and how fast that half-width opens, in 조각/second.
uniform float wake_half_w;
uniform float wake_open;
// ⚠ **The froth is here so the sheet compares MECHANISMS.** Two of the five draw their wake as
// geometry and a textured strip of foam is part of what those are; a shader candidate handed a flat
// gradient instead would be losing on a difference nobody chose. `vnoise` is the shipped shader's own,
// already in scope — see the head of this file.
uniform float wake_froth_scale;
uniform float wake_froth_amt;
uniform vec4 wake_col : source_color;

vec3 wake(vec3 base, vec2 p, float t) {
	vec2 uv = (p - wake_org) / max(wake_size, vec2(0.001));
	// ⚠ **The edge of the buffer is a hard edge and it is not hidden.** That is the thing this
	// mechanism cannot do, and a picture that fades it out would be a picture of a different mechanism.
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return base; }
	vec2 s = texture(wake_field, uv).rg;
	if (s.r <= 0.0) { return base; }
	float age = wake_t - s.r;
	if (age < 0.0 || age > wake_life) { return base; }
	float w = wake_half_w + wake_open * age;
	float a = (1.0 - smoothstep(w * 0.45, w, s.g)) * (1.0 - age / wake_life);
	a *= mix(1.0, vnoise(p * wake_froth_scale), wake_froth_amt);
	return mix(base, wake_col.rgb, clamp(a, 0.0, 1.0) * wake_col.a);
}
