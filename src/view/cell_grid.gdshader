shader_type canvas_item;
render_mode unshaded;

// Cell grid rendering. **The CPU does not make colors** — the `_mat` and `_flag` byte arrays are L8 textures
//  as-is, and all that happens here is a palette lookup.
//
// **Do not write color literals for materials.** The palette is baked from `cell_materials.gd`'s `DEFS` and injected.
//  Pin a color here and the sim table and the rendering diverge (duplication instead of derivation).
// Fire colors and bit positions are likewise **injected** (`fx_tuning.gd` and `cell_materials.gd`).

uniform vec4 palette[16];

// The `_flag` texture. The only axis carrying what changes state while the material stays the same (= burning).
uniform sampler2D flag_tex : filter_nearest, repeat_disable;
uniform int flag_burning;
uniform vec4 fire_lo;
uniform vec4 fire_hi;
uniform float fire_hz;

// Shallow water. The deep water color is **not here** — that is a material and already arrives via `palette`.
uniform int flag_shallow;
uniform vec4 water_shallow;

// **Empty cells are pulled out as transparent — the only path by which the background reaches the screen.**
//  Before, empty cells were painted **opaquely** with `palette`'s `#0E0E13` too. The grid sprite covers
//   the whole world with no gaps, so **whatever was put behind it was 100% hidden** —
//   the seat `docs/design/background.md` wrote down as "what has to come first: not the art, the code".
//  **The path of putting alpha in the material table was not taken** — it touches `src/sim/`'s "integers only"
//   contract, and since `rgb` is 24-bit there is no alpha channel in the table at all. => **The shader side is cheap.**
//  The color of `palette[EMPTY]` stays as it is — **on a stage with no background that color shows through**
//   (pass -1 for `empty_id` and you get the old behavior).
uniform int empty_id;

// L8 -> integer restore. The reason values are kept below 16 is this rounding —
//  0 to 15 is safe even on a machine where precision drops to mediump.
//
// **That the argument is an already-read texel rather than a sampler is the whole point of this function.**
//  Take a sampler as an argument and the same function cannot be called with both a built-in (`TEXTURE`)
//  and a uniform (`flag_tex`)
//  (`Sampler argument 0 ... called more than once using both built-ins and uniform textures`).
//  => Written that way, **compilation fails outright while the game does not stop and only the screen goes black** —
//   the grid is drawn with the raw L8 byte values (stone 1, wood 2), and only the character drawn via `_draw()`
//   keeps its real color.
//  Measured: in that state all 534 nets were green. That is why `net_render` exists.
//  It is a parser rule, so **it is independent of backend and headless** (a verifier compiled 4 variants to narrow it).
int l8_to_int(vec4 texel) {
	return clamp(int(texel.r * 255.0 + 0.5), 0, 15);
}

void fragment() {
	int mat_id = l8_to_int(texture(TEXTURE, UV));
	int flags = l8_to_int(texture(flag_tex, UV));

	vec4 c = palette[mat_id];

	// **Empty cells get alpha 0. They do not escape via `return`.**
	//  It was once written as `if (…) { COLOR = vec4(0.0); return; }` and **`net_render` caught it** —
	//   an early `return` inside `fragment()` breaks compilation.
	//  And that symptom is **exactly the same** as the `l8_to_int` comment above: compilation fails outright
	//   while the game does not stop and only the screen goes black. **It was caught because `net_render` exists.**
	//  => The state branches below (shallow water, fire) cannot stand on an empty cell (water is a material,
	//   fire needs fuel), so setting alpha alone to 0 and letting it flow through gives the same result.
	float a = (mat_id == empty_id) ? 0.0 : 1.0;

	// **Looked at before fire.** Water does not burn, so the two bits cannot stand on the same cell
	//  (water has 0 fuel), but fixing an order means **not having to decide "which one wins" again
	//  when the next state color arrives.**
	//  The fire branch below overwrites `c` wholesale, so the day the two do overlap, **fire wins.**
	if ((flags & flag_shallow) != 0) {
		c = water_shallow;
	}

	if ((flags & flag_burning) != 0) {
		// **Scatter the phase per cell.** Without it the whole fire blinks together as one lump and reads as
		//  "a blinking rectangle" rather than "a burning surface".
		// Do not pin the grid size here — `TEXTURE_PIXEL_SIZE` already holds that value, and written by hand
		//  it goes silently stale the day W/H change.
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
		float ph = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		c = mix(fire_lo, fire_hi, 0.5 + 0.5 * sin(TIME * fire_hz + ph * 6.2831853));
	}

	// Alpha is multiplied last — the branches above overwrite `c` wholesale, so this is the only safe seat.
	c.a *= a;
	COLOR = c;
}
