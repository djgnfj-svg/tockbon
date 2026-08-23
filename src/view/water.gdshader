// The sea. **Three sine layers moving over one quad, and no texture anywhere** — nothing here is
// bought, downloaded or painted, which is the whole reason it is a shader and not an asset.
//
// ⚠ **Every colour and every number arrives as a uniform from `look.gd`.** That file is where this
// repo keeps presentation values and a literal written here would be the one that nobody can find.
//
// ⚠⚠ **It is deliberately quiet.** The sea is the background ten fighting bodies are read against;
// water that draws the eye is water that competes with the game. The two tones it moves between are a
// few percent apart, and the movement is slow enough to plan on top of.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec4 trough : source_color;
uniform vec4 crest : source_color;
uniform float wave_scale;
uniform float wave_speed;

// The swell at a world point. Three waves at different angles and rates so the pattern never lines up
// into stripes — two would beat visibly, and one is a corrugated roof.
float swell(vec2 p, float t) {
	float a = sin(p.x * wave_scale + t);
	float b = sin((p.x * 0.6 + p.y * 0.8) * wave_scale * 1.7 - t * 1.3);
	float c = sin(p.y * wave_scale * 0.9 + t * 0.7);
	return (a * 0.5 + b * 0.3 + c * 0.2);
}

void fragment() {
	// `VERTEX` is view space in a fragment shader; the sea has to move in WORLD space or it slides
	// under the camera whenever the board is panned or turned.
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME * wave_speed;
	float k = clamp(swell(p, t) * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(trough.rgb, crest.rgb, k);

	// A slope read straight off the same function, so the glint sits on the face of a wave rather than
	// anywhere the light happens to fall. The two offsets are a finite difference in world tiles.
	float e = 0.35;
	float dx = swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t);
	float dy = swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t);
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(normalize(vec3(-dx, 9.0, -dy)), 0.0)).xyz, 0.22));

	// Rougher in the troughs, smoother on the crests: a crest catches the sun and a trough does not,
	// and that difference is most of what tells a viewer they are looking at water at all.
	//
	// ⚠⚠ **MEASURED DOWN from 0.55 specular and 0.18 roughness.** At those values the sun laid **one
	// blown-out white streak across a quarter of the sea** — a 400-tile mirror has one highlight and it
	// is enormous. The sea has to shimmer, not glare: it is the background ten fighting bodies are read
	// against, and the first capture of it is what said so.
	ROUGHNESS = mix(0.92, 0.62, k);
	SPECULAR = 0.12;
}
