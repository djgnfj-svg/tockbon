shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

// **The 판, and what makes one of them stand out from the rest.**
//
// ⚠⚠ **THE 판 IS ITS OWN OBJECT AGAIN** (2026-08-28, the user: 「마우스올리면 호버되도록해주고
// 특정버튼 눌러야 그 뜨게해줘 판이」). It spent one day baked into the island's own mesh, where it
// could be neither hidden nor lit one at a time — there was no node to touch, which is why the hover
// mark went missing for a whole round. `tools/blender/island_build.py` exports it beside the island
// now, and this shader is what decides when any of it is visible.
//
// ⚠⚠ **EVERY 판 CARRIES ITS 칸's INDEX IN `UV.x`**, written by the Blender run as `py * PW + px` —
// the same number `field_view._wash_cells` computes for a tile. **That is the whole mechanism**: one
// mesh, one draw call, and a `hover_cell` uniform picks out exactly one 칸 without the game having
// to split this into forty-eight nodes.
//
// ⚠ **The lift is in the VERTEX stage and it is a real displacement.** A hovered 칸 rises; it does
// not merely brighten. Two channels rather than one, because a brightness alone was what the old
// two-quad mark did and the user's word on that was 「위에 노드만 살짝 얹은 느낌이어서 너무 별로」.
//
// ⚠ **Vertex colour is the ground's own tone**, baked by Blender off the height the 판 sits at. The
// tint below lightens THAT rather than replacing it, so a lit 판 still reads as the ground it stands
// on instead of as a white sticker.

// Which 칸 the cursor is on, as the same index the UV carries. **-1 is 「nowhere」** and is what an
// off-island cursor produces, so there is no second "is the mouse on the ground" test anywhere.
uniform float hover_cell = -1.0;
// 0 while the board is at rest, 1 while the player is holding the reveal key. **A float and not a
// bool** so the shell can fade it if it ever wants to; today it is driven to 0 or 1 outright.
uniform float show_all : hint_range(0.0, 1.0) = 0.0;
// What the resting 판 is worth when the whole board is revealed, and what the hovered one is worth
// at any time. **Both live in `look.gd`** and are pushed in from `field_view`.
uniform float all_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float hover_alpha : hint_range(0.0, 1.0) = 0.85;
// How much lighter than the ground a 판 is drawn, and how much lighter again the hovered one is.
uniform float all_lighten : hint_range(0.0, 1.0) = 0.25;
uniform float hover_lighten : hint_range(0.0, 1.0) = 0.55;
// How far the hovered 칸 rises, in world units (one unit is one tile).
uniform float hover_lift = 0.06;

varying float v_is_hover;
varying vec3 v_tone;

void vertex() {
	// ⚠ **A tolerance and not `==`.** The index arrives as a float through glTF's TEXCOORD_0 and the
	// uniform is written from an int; both are exact for the values in play, but an equality on
	// floats is the shape that fails silently on the one machine nobody tested.
	//
	// ⚠⚠ **THE HOVER IS GATED ON THE REVEAL AND THAT IS THE USER'S CALL** (2026-08-28: 「탭을 눌러서
	// 떳을때만 오버가 되야 의미가 있을듯 한데?」). For one round the hovered 칸 rose on a board that
	// was otherwise invisible — a single tile lifting out of blank ground, with nothing around it to
	// say what it was one of. **A hover means 「this one, of these」**, and without the rest of the
	// board on screen there is no 「these」.
	// ⇒ `show_all` multiplies the hover as well as the resting alpha, so with TAB up this whole
	// object is transparent and flat.
	//
	// ⚠⚠ **BOTH UV CHANNELS ARE 칸 INDICES** (2026-08-28). A pad carries its own index in both; a
	// BRIDGE — the sloped strip between two 칸 a body may actually cross between — carries the two it
	// joins. Matching on either is what makes a bridge light **from both ends**: standing on the low
	// 칸 you see the way up, standing on the high one you see the way down.
	// ⚠ **This is the answer to 「판정이 애매해」** (the user, 2026-08-28). A pad alone says 「you may
	// stand here」 and says nothing about the wall beside it; the bridge is the half that says 「you may
	// GO」, and its absence is what says you may not.
	float on_cell = max(step(abs(UV.x - hover_cell), 0.25), step(abs(UV.y - hover_cell), 0.25));
	v_is_hover = on_cell * step(0.5, show_all);
	v_tone = COLOR.rgb;
	VERTEX.y += v_is_hover * hover_lift;
}

void fragment() {
	// **Everything here is the reveal key's.** With TAB up the 판 is fully transparent — which is the
	// state the user asked for: an island with nothing drawn on it.
	float a = show_all * all_alpha;
	a = max(a, v_is_hover * hover_alpha);
	float lighten = mix(all_lighten, hover_lighten, v_is_hover);
	ALBEDO = mix(v_tone, vec3(1.0), lighten);
	ALPHA = a;
}
