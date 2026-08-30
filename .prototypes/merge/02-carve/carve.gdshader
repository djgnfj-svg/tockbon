shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// **The 판 is not a shape at all — it is a whole 조각, and the shader cuts the shape out of it.**
//
// The gutter stops being geometry and becomes a NUMBER this shader owns, so it can go to zero without
// anything moving. ⚠⚠ **That is the trade**: the mesh is the dumbest possible thing (one quad per
// 조각) and every edge on screen is an `fwidth`-wide cut rather than a triangle.
//
// `COLOR.rgba` carries the resting inset on the four sides — **west, east, north, south** — and the
// tone comes from a uniform instead, because the four channels are spent.

uniform float merge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 pad_tone = vec4(1.0, 1.0, 0.93, 0.42);
uniform float radius = 0.16;

#include "res://.prototypes/merge/hover.gdshaderinc"

varying float v_hov;
varying vec2 v_local;   // where in the 조각 this fragment is, 0..1
varying vec4 v_inset;   // the resting inset per side
varying vec2 v_inner;   // 1 where the side facing the rest of the 칸 is the EAST / SOUTH one

void vertex() {
	v_local = UV;
	v_inset = COLOR;
	// **Which quarter of its 칸 this 조각 is**, written on the CPU as the tile index's parity.
	// ⚠ **Not derived from the vertex position**: a quad's corners sit exactly on the tile boundary,
	// so half of them would floor into the neighbouring 조각 and the shape would close the wrong side.
	// ⚠ **`UV2` is the tile index here**, so the quarter of the 칸 is its parity.
	v_inner = mod(UV2, 2.0);
	v_hov = hover_of(UV2, merge);
	VERTEX.y += v_hov * hover_lift;
}

void fragment() {
	// The side that faces into the 칸 closes; the three others stay where they rest.
	// `v_inner.x == 0` means this 조각 is the WEST half of its 칸, so its EAST side is the inner one.
	float in_w = v_inner.x > 0.5 ? 1.0 : 0.0;
	float in_e = 1.0 - in_w;
	float in_n = v_inner.y > 0.5 ? 1.0 : 0.0;
	float in_s = 1.0 - in_n;
	vec4 inner = vec4(in_w, in_e, in_n, in_s);
	vec4 ins = mix(v_inset, v_inset * (1.0 - inner), merge);

	vec2 lo = vec2(ins.x, ins.z);
	vec2 hi = vec2(1.0 - ins.y, 1.0 - ins.w);
	vec2 mid = (lo + hi) * 0.5;
	vec2 half_size = (hi - lo) * 0.5;

	// The corner this fragment is nearest, and whether either of its two sides is the closing one.
	vec2 q = step(mid, v_local);            // 1 on the east / south side of the middle
	float corner_inner = max(mix(in_w, in_e, q.x), mix(in_n, in_s, q.y));
	float r = radius * (1.0 - merge * corner_inner);
	r = min(r, min(half_size.x, half_size.y));

	vec2 d = abs(v_local - mid) - half_size + vec2(r);
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
	float fw = max(fwidth(dist), 0.0005);
	float a = 1.0 - smoothstep(-fw, fw, dist);

	ALBEDO = mix(pad_tone.rgb, vec3(1.0), v_hov * hover_light);
	ALPHA = mix(pad_tone.a, hover_alpha, v_hov) * a;
}
