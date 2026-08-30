// **The wafer's top face, cut out of a plane by the same field the water reads.**
//
// ⚠⚠ **THIS EXISTS BECAUSE `triangulate_polygon` RETURNED ZERO TRIANGLES.** The island's outline is
// 280 points and closes cleanly, and the triangulator still refused it — the island touches itself
// corner to corner in at least one place, which is a legal shape for a coastline and not a legal one
// for a simple polygon. **The failure was silent**: a mesh with a skirt and no top, through which the
// sea was visible, so several candidates painted the island's whole interior white and the lab looked
// like it had found a difference between shaders.
//
// **Cutting the same field the water cuts has a second virtue**: land and water agree on where the
// coast is to the texel, because it is one number read twice. A triangulated outline and a baked field
// agree only to whatever the bake's resolution is.
shader_type spatial;
render_mode unshaded;

uniform sampler2D land_field : filter_linear;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float field_span;
uniform vec4 land : source_color = vec4(0.760, 0.735, 0.520, 1.0);

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 uv = (p - field_origin) / max(field_size, vec2(1.0));
	float d = (texture(land_field, clamp(uv, vec2(0.0), vec2(1.0))).r * 2.0 - 1.0) * field_span;
	// Everything seaward of the outline is not this surface.
	if (d > 0.0) {
		discard;
	}
	ALBEDO = land.rgb;
}
