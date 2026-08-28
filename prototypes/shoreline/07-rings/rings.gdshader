// The strips of 07. ⚠ **Everything that moves happens in `vertex()`** — the shore is a thing being
// pushed, not a threshold being animated.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 foam : source_color = vec4(0.900, 0.945, 0.950, 1.0);
uniform float travel = 0.55;
uniform float speed = 0.22;
uniform float alpha = 0.85;

varying float v_fade;

void vertex() {
	// UV.x is this strip's place in the cycle; COLOR.rg is which way「out」is at this vertex.
	float ph = fract(TIME * speed + UV.x);
	vec2 outw = COLOR.rg * 2.0 - 1.0;
	VERTEX.xz += outw * (ph * travel);
	// It leaves the rock at full strength and is gone by the time it is a tile out, and it thins as it
	// goes — a strip that keeps its width the whole way reads as a hoop, not as water.
	v_fade = (1.0 - ph) * (1.0 - ph);
}

void fragment() {
	// Across the strip: full in the middle, nothing at the two edges.
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = foam.rgb;
	ALPHA = clamp(v_fade * smoothstep(0.0, 0.55, across) * alpha, 0.0, 1.0);
}
