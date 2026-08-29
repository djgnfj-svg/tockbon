// **The hover, shared by all four versions so it cannot be four different answers.**
//
// ⚠⚠ **What lights is whatever the 판 IS at this distance.** Up close the 판 is a 조각, so one 조각
// lights. Far out the four have become one 칸, so the whole 칸 lights. **The mark that rises is the
// mark that was lying there** — the rule the user set on 2026-08-29 (「조각에 판을 올리고 왜 뜨는 판은
// 또 다른데 뜨네... 니가 개념이 좀 잘못된듯?」), and the merge is exactly what carries it across.

uniform vec2 hover_tile = vec2(-1.0, -1.0);
uniform float hover_lift = 0.10;
uniform float hover_light : hint_range(0.0, 1.0) = 0.55;
uniform float hover_alpha : hint_range(0.0, 1.0) = 0.85;

// `tile` is this vertex's own 조각, carried in an attribute rather than read off the position: once
// the merge closes an inner side those points sit exactly on the tile boundary.
// ⚠ **The argument is `m`, not `merge`.** Every version already declares a `merge` uniform, and a
// parameter of that name is a redefinition the compiler refuses.
float hover_of(vec2 tile, float m) {
	if (hover_tile.x < 0.0) {
		return 0.0;
	}
	float on_tile = step(abs(tile.x - hover_tile.x) + abs(tile.y - hover_tile.y), 0.1);
	vec2 b = floor(tile * 0.5);
	vec2 hb = floor(hover_tile * 0.5);
	float on_block = step(abs(b.x - hb.x) + abs(b.y - hb.y), 0.1);
	return max(on_tile * (1.0 - m), on_block * m);
}
