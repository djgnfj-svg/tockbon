shader_type spatial;
render_mode unshaded, cull_disabled;

// **The white rim on the body the player has hold of** (2026-08-31, the user: 「캐릭터 눌렀을때 살짝
// 내가 누른 캐릭에 흰색 테두리 같이 내가 누른 캐릭이 티가 나야할듯함」).
//
// ⚠⚠ **IT IS THE BODY'S OWN PICTURE, FLOODED TO ONE COLOUR AND DRAWN SLIGHTLY LARGER BEHIND IT.**
// The rim is therefore the exact silhouette of whatever is standing there — it needs no second
// drawing, it costs one sprite, and it cannot go stale when the body's art is redone. **A rim built
// by sampling neighbours inside the quad could not reach past the quad's own edge**, which is where an
// outline has to live.
//
// ⚠ **`modulate` cannot do this.** A `Sprite3D`'s modulate MULTIPLIES the picture, so a dark body
// stays a dark body; making it white takes replacing the colour, which takes a shader.
//
// ⚠⚠ **The cut is what makes this a silhouette and not a white box.** The body pictures are pixel art
// with hard alpha, so a single threshold is exact — there is no soft edge to preserve.
//
// ⚠⚠ **NOTHING WRITES `ALPHA` AND THAT IS LOAD-BEARING, MEASURED 2026-08-31.** Writing it — even
// `ALPHA = 1.0` — puts the material on Godot's TRANSPARENT path, where it draws after the opaque pass
// and writes no depth. The rim then rendered nothing at all on screen while every field this file
// could be asked about (visible, shader, texture, scale, position) was correct. **The body sprites are
// opaque with a discard (`ALPHA_CUT_DISCARD`), and the rim has to be the same kind of thing to sit
// behind them.** ⇒ discard, `ALBEDO`, and no `ALPHA` line.

// The body's own picture. **Pushed in per sprite** — a facing and an animation frame are different
// textures, so one shared material would put one body's silhouette around another.
uniform sampler2D body_tex : filter_nearest, source_color, hint_default_transparent;
// What the rim is worth. **Lives in `look.gd`** like every other colour in this project.
uniform vec4 line_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Below this the picture is nothing and the rim is not drawn there.
uniform float cut : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// ⚠ **Discard rather than `ALPHA = 0`.** This writes depth, and a transparent-but-drawn rim would
	// stamp the whole quad into the depth buffer and punch a body-shaped hole in whatever is behind.
	// ⚠ **Discard and not `ALPHA = 0`** — see the note above about the transparent path.
	if (texture(body_tex, UV).a < cut) {
		discard;
	}
	ALBEDO = line_col.rgb;
}
