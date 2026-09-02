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
// ⚠⚠ **EVERY 판 CARRIES ITS 조각's INDEX IN `UV.x`**, written by the Blender run as `ty * W + tx` —
// the same number `field_view._wash_cells` computes for a tile. **That is the whole mechanism**: one
// mesh, one draw call, and a `hover_cell` uniform picks out exactly one 조각 without the game having
// to split this into hundreds of nodes.
// ⚠ **It was the 칸's index until 2026-08-29** (the user: 「판이 조각단위로 뜨고 그것으로 이동할 수
// 있는게 좋을 것 같아」). One 판 per 조각 is four times as many marks, and that is the trade taken.
//
// ⚠ **The lift is in the VERTEX stage and it is a real displacement.** A hovered 조각 rises; it does
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
// How far from the ground's own tone a 판 is drawn, and how far again the hovered one is.
// ⚠⚠ **SIGNED SINCE 2026-08-29** (the user: 「밝게해보자 어둡게도 해서 프로토 타입으로 보는게 목적」).
// **Positive is toward white, negative is toward black**, and zero is the bare ground. It was a
// 0..1 lighten before, so every old value means exactly what it meant.
uniform float all_lighten : hint_range(-1.0, 1.0) = 0.25;
uniform float hover_lighten : hint_range(-1.0, 1.0) = 0.55;
// How far the hovered 조각 rises, in world units (one unit is one tile).
uniform float hover_lift = 0.06;
// ⚠⚠ **HOW FAR THE 판 HAVE MERGED**, 0 one-per-조각 and 1 one-per-칸 (2026-08-29, the user: 「멀면
// 칸단위로 하려고함 줌에따라」). `field_view.pad_merge()` works it out from the zoom and pushes it here.
uniform float merge : hint_range(0.0, 1.0) = 0.0;
// The board's width in 조각, so a 판's index can be turned back into a position and from there into
// which 칸 it belongs to. ⚠ **Pushed from the grid, never a literal** -- the island's size changes.
uniform float board_w = 30.0;

// ⚠⚠ **WHICH 조각 THE PICKED BODIES MAY STAND ON, ONE TEXEL EACH** (2026-08-31, the user: 「캐릭터를
// 누르면 이동할 수 있는 칸들이 뜨고 눌러서 이동하는거임」). Red is 「stand here」, black is not, and the
// texel is at `(index % board_w, index / board_w)` — the very same arithmetic the merge below already
// does, so a lit 판 and the 조각 `Hand.can_reach` admits can never come apart.
// ⚠ **A texture and not an array uniform.** An island is up to 48x32 조각; a `uniform float[]` big
// enough is past what a shader may declare, and one that was not would silently clip the board.
uniform sampler2D reach_tex : filter_nearest, repeat_disable, hint_default_black;
// 1 while the hand is holding somebody, 0 while it is empty. **This is what replaced needing TAB** —
// the board no longer has to be revealed for the player to see where a body may go.
uniform float show_reach : hint_range(0.0, 1.0) = 0.0;
// What a reachable 판 is worth, and how far it is pulled from the ground's own tone. **Both live in
// `look.gd`.** ⚠ Kept clear of the hover's own pair so 「where I may go」 and 「the one under the
// cursor」 stay two readable states rather than one wash.
uniform float reach_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float reach_lighten : hint_range(-1.0, 1.0) = 0.30;

// **Whether one 조각 index is in the reach set.** ⚠ `board_w` is the row stride and the texture is
// exactly the board's size, so no clamping is needed for an index the mesh actually carries.
float reach_at(float index) {
	vec2 xy = vec2(mod(index, board_w), floor(index / board_w));
	return texelFetch(reach_tex, ivec2(int(xy.x), int(xy.y)), 0).r;
}

varying float v_is_hover;
varying float v_in_reach;
varying vec3 v_tone;
// **1 on a side wall that the merge buries inside the 칸, 0 on everything the player can see.**
// Written in the vertex stage, read as a straight alpha kill in the fragment. **See the block above
// `VERTEX.x` for what it is for and what was measured.**
varying float v_inner_wall;

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
	// ⚠⚠ **WHAT LIGHTS IS WHATEVER THE 판 IS AT THIS DISTANCE** (2026-08-29). Up close a 판 is one
	// 조각, so one 조각 lights; far out the four have closed into one 칸, so the whole 칸 lights.
	// **The mark that rises is the mark that was lying there** -- the user's own rule, and the merge
	// is what carries it across.
	// ⚠ **`UV.y` is not read any more.** glTF flips V, so the second channel arrives as `1 - cell`
	// and never matched anything; it was the bridges' second index and the bridges are gone.
	float on_cell = step(abs(UV.x - hover_cell), 0.25);
	vec2 mine = vec2(mod(UV.x, board_w), floor(UV.x / board_w));
	vec2 theirs = vec2(mod(hover_cell, board_w), floor(hover_cell / board_w));
	float on_block = step(abs(floor(mine.x * 0.5) - floor(theirs.x * 0.5))
						+ abs(floor(mine.y * 0.5) - floor(theirs.y * 0.5)), 0.1);
	float lit = max(on_cell * (1.0 - merge), on_block * merge) * step(0.0, hover_cell);
	// ⚠⚠ **THE REACH LIGHTS THE SAME 판 THE MERGE IS ALREADY LIGHTING.** Up close a 판 is one 조각 and
	// its own texel answers; far out the four have closed into one 칸, so the 칸 lights when ANY of its
	// four 조각 is reachable — the alternative is a merged lump lit a quarter of the way through.
	vec2 mine_block = floor(mine * 0.5) * 2.0;
	float block_reach = max(
		max(reach_at(mine_block.y * board_w + mine_block.x),
			reach_at(mine_block.y * board_w + mine_block.x + 1.0)),
		max(reach_at((mine_block.y + 1.0) * board_w + mine_block.x),
			reach_at((mine_block.y + 1.0) * board_w + mine_block.x + 1.0)));
	v_in_reach = mix(reach_at(UV.x), block_reach, merge) * show_reach;
	// ⚠⚠ **THE HOVER IS GATED ON 「IS THIS 판 SHOWING AT ALL」 AND NOT ON TAB ANY MORE.** The rule it
	// was written for is untouched — 「a hover means 『this one, of these』, and without the rest of the
	// board on screen there is no 『these』」 — but the reach is now a second, better 「these」: the 판
	// the picked body may stand on. ⇒ hovering an unreachable 조각 with a body picked lights nothing,
	// which is the same sentence the old gate made about an unrevealed board.
	v_is_hover = lit * step(0.5, max(show_all, v_in_reach));
	v_tone = COLOR.rgb;
	// ⚠⚠ **THE MERGE IS A REAL DISPLACEMENT AND `UV2` IS WHERE EACH POINT GOES.** The bake stores it
	// as `0.5 + delta`; **both axes come back straight** -- glTF flips V and Blender's +Y is Godot's
	// -Z, and the two cancel. **Measured off the imported mesh on 2026-08-29**, not assumed.
	VERTEX.x += (UV2.x - 0.5) * merge;
	VERTEX.z += (UV2.y - 0.5) * merge;
	VERTEX.y += v_is_hover * hover_lift;
	// ⚠⚠ **A 판 IS A 0.02-THICK SLAB, NOT A QUAD, AND THE MERGE PARKS FOUR OF ITS SIDE WALLS ON THE
	// 칸's TWO MIDLINES** (2026-09-01). That is the whole of the dark hairline that split every merged
	// mark in half. **Measured off `assets/terrain/island.glb`**: each 판 is a rounded outline at
	// y 0.230 with a skirt dropping to y 0.210, and after the displacement above the four 판 of a 칸
	// meet at exactly x = 0 and z = 0 — the tops abut with no overlap at all, but each pad's two
	// INNER walls land on those midlines, where the pad opposite has parked its own two. The material
	// is `cull_disabled` and `blend_mix` over `depth_draw_opaque`, so nothing is culled and nothing
	// writes depth: **both walls blend on top of the tops, three layers of the same colour where
	// there should be one.**
	// ⚠ **A wall is 0.02 world units tall, so it lands on `0.02 * cos(pitch) * px-per-tile` of
	// screen — under half a pixel far out and wider every step the camera comes in**, which is why
	// it read as a 1-3 px hairline that got worse with the zoom.
	// ⚠⚠ **THE VERTICAL JOIN HAS EXACTLY THE SAME DEFECT AND YAW 0 HIDES IT.** A wall standing in the
	// plane x = const projects to zero screen width when the camera is not turned, so only the join
	// between the near and far halves showed. **Measured on the turned board**: at yaw 0 the seam is
	// on 93% of the marks scanned down and 1% scanned across; at yaw 45 it is on 69% and 61%, at the
	// same 2.06x strength both ways.
	// ⚠⚠ **THE HAND CANNOT REACH YAW 45 ANY MORE** (2026-09-02): Q and E turn a quarter and the
	// free-rotating right drag is deleted, so a player's board stands at 0, 90, 180 or 270.
	// **The measurement stands and the angle is now an instrument's** — the two pad shooters turn 45°
	// on purpose to photograph exactly this. It is written on rather than deleted: a number measured
	// at an angle is still a measurement when the angle stops being walkable.
	// ⇒ **The two walls that the merge buries are given up.** `inward` is the way this 판 has to grow
	// to reach its 칸's middle — +1 on an even index, -1 on an odd one — and a wall whose normal
	// leans that way is a wall the merge is about to hide. **Checked against all 280 판 of the baked
	// island**: the rule kills 2800 wall quads, of which 2240 are already zero-area after the merge
	// and the other 560 are exactly the two midline walls of each 판. **It kills nothing that has
	// area anywhere else, and it leaves no midline wall standing.**
	// ⚠ **`* merge` IS WHAT KEEPS THE 조각 LOOK.** At merge 0 the four 판 stand apart and every one of
	// those walls is the mark's own visible rim — this line must not touch them, and at merge 0 it
	// does not. **The 조각 decision has flipped twice and this fix does not vote.**
	// ⚠ **It rests on a 칸 being whole.** A 판 whose block-partner was never baked would lose the rim
	// on that side — sub-pixel, and the outline of the island only bends by 칸, so all 280 판 have
	// both partners. **Counted, not assumed.**
	vec2 inward = 1.0 - 2.0 * mod(floor(mine), 2.0);
	float is_wall = 1.0 - step(0.5, abs(NORMAL.y));
	v_inner_wall = is_wall * step(0.0001, dot(NORMAL.xz, inward)) * merge;
}

void fragment() {
	// **Everything here is the reveal key's.** With TAB up the 판 is fully transparent — which is the
	// state the user asked for: an island with nothing drawn on it.
	float a = max(show_all * all_alpha, v_in_reach * reach_alpha);
	a = max(a, v_is_hover * hover_alpha);
	// ⚠ **Three states and they are read in the order they were earned**: the resting board, then the
	// reach laid over it, then the one 조각 under the cursor. A hovered 조각 outside the reach cannot
	// reach this line at all — `v_is_hover` is already zero for it.
	float tone = mix(all_lighten, reach_lighten, v_in_reach);
	tone = mix(tone, hover_lighten, v_is_hover);
	// ⚠ **Toward white or toward black, never both.** Mixing to a grey midpoint instead would wash a
	// dark 판 out at exactly the strength where it starts to read.
	vec3 target = tone >= 0.0 ? vec3(1.0) : vec3(0.0);
	ALBEDO = mix(v_tone, target, abs(tone));
	// ⚠ **The kill is on the ALPHA and not a `discard`.** A wall quad's four corners all carry the
	// same normal — the skirt is flat-shaded, one quad per outline segment, so the varying is
	// constant across the quad and there is nothing for the interpolator to smear onto the top face.
	ALPHA = a * (1.0 - v_inner_wall);
}
