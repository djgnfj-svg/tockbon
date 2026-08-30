// **Where this one gets the open water from: THE SCREEN, NOT THE WORLD.**
//
// A Short Hike draws the whole world into a **low-resolution render texture** — its author's own words,
// *the pixellated look is achieved by rendering the world to a low-res RenderTexture* — so its sea is
// stepped by the screen's own grid rather than by anything in the water. This does that to the sea
// alone: the tone is quantised on a fixed pixel lattice and dithered between the steps, so the water
// reads as **printed** rather than as simulated.
//
// ⚠⚠ **IT IS STUCK TO THE SCREEN AND THAT IS ITS WHOLE FAILURE MODE.** Turn the board or zoom and the
// lattice does not turn with the water — it crawls under it. A Short Hike can afford that because
// everything on its screen is stepped by the same grid; here only the sea would be.
uniform float paper_px = 4.0;
uniform float paper_tones = 3.0;
uniform float paper_spread = 0.10;
uniform float paper_scale = 0.09;
uniform float paper_drift = 0.05;

// The 4x4 ordered matrix — the cheapest dither there is.
float paper_dither(vec2 c) {
	vec2 m = mod(c, 4.0);
	int i = int(m.y) * 4 + int(m.x);
	float v = 5.0;
	if (i == 0) { v = 0.0; } else if (i == 1) { v = 8.0; } else if (i == 2) { v = 2.0; }
	else if (i == 3) { v = 10.0; } else if (i == 4) { v = 12.0; } else if (i == 5) { v = 4.0; }
	else if (i == 6) { v = 14.0; } else if (i == 7) { v = 6.0; } else if (i == 8) { v = 3.0; }
	else if (i == 9) { v = 11.0; } else if (i == 10) { v = 1.0; } else if (i == 11) { v = 9.0; }
	else if (i == 12) { v = 15.0; } else if (i == 13) { v = 7.0; } else if (i == 14) { v = 13.0; }
	return v / 16.0;
}

vec3 open_sea(vec2 p, float d, float t, vec2 sxy) {
	vec2 cell = floor(sxy / max(paper_px, 1.0));
	float n = vnoise(p * paper_scale + vec2(t * paper_drift, -t * paper_drift * 0.8)) * 0.6
			+ vnoise(p * paper_scale * 3.3 + vec2(5.0, 2.0)) * 0.4;
	float lvl = floor(n * paper_tones + paper_dither(cell)) / max(paper_tones - 1.0, 1.0);
	return sea.rgb + vec3((clamp(lvl, 0.0, 1.0) - 0.5) * paper_spread);
}
