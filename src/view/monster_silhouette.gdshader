shader_type canvas_item;

// **Keep only the body sprite's alpha and fill it with a flat color. There are two users.**
//
//      flash     a hit monster as a white silhouette      strength = modulate alpha
//      outline   the body laid out in 8 directions        strength = 1
//
// **That the two share one shader is not a coincidence** — "silhouette in a flat color" is exactly the same job.
//  The file was originally named `monster_flash` and was renamed when the outline was added. **Why it stays one file**:
//   split it and "keep only the alpha" lives in two places, and the day only one is fixed, the flash and the
//   outline drift apart in shape.
//  **The color is a per-node uniform, so the two hang on different nodes** (`monster_view`'s layer boxes).
//
// **This was originally a `draw_rect` and it failed on screen** (acceptance 13):
//  a white rectangle covered the sprite **wholesale**, so it read as "a shape blinking".
//  **The value of having attached sprites was cut in half right here** — the body is a pig but a hit makes it a square.
//
// **The strength comes in as vertex color (modulate), not as a uniform. That is the point of this shader.**
//  A uniform is **per node**, so when one node draws several monsters **only the last value survives** —
//   three pigs flashing at different strengths becomes impossible in principle.
//  => The alpha of `draw_texture_rect(tex, r, false, Color(1,1,1, strength))` arrives here as `v_tint.a`.
//
// **Why pass it through a `varying`**: fragment's `COLOR` has already been multiplied by the texture on entry,
//  so **strength and sprite alpha cannot be separated.** Taking the vertex color as-is in vertex keeps the two apart.
//
// **A `draw_rect` with no texture is safe too** — `TEXTURE` is then a white 1x1 so `a = 1`, and the result is
//  "white rectangle x strength", i.e. **the old behavior exactly.** The fallback path is kept for free.
// **Color as a uniform, strength as vertex color — splitting the two is this file's design.**
//  The color is safe as a per-node uniform because **every monster shares it.**
//   The strength **differs per monster**, so as a uniform only the last value would survive and it breaks in principle.
//  `monster_view` puts the color in here — `MONSTER_FLASH_COLOR` for the flash layer,
//   `MONSTER_OUTLINE_COLOR` for the outline layer. **Not a false knob** (CLAUDE.md).
uniform vec4 flash_color : source_color = vec4(1.0);

varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(flash_color.rgb, a * v_tint.a);
}
