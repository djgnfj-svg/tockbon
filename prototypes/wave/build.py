"""Generate every candidate's `water.gdshader` from the SHIPPED one, made LIT, plus a snippet.

⚠⚠ **This is the sea lab's splicer with one thing changed: the light is turned on.** The shipped sea is
`render_mode unshaded`, which is why the island's shadow has nothing to land on and why every candidate
in `prototypes/sea/` had to paint in ALBEDO. Here `unshaded` is swapped for `ambient_light_disabled` and
each candidate writes its own `light()`, so **the only light on the water is the one the candidate asks
for** — no ambient leaking in from the environment, no specular unless a candidate writes one.

**What a candidate folder holds**

    prototypes/wave/NN-name/
        mech.gdshader   <- its own uniforms and the three hooks below
        NOTES.md        <- what it buys / what it costs / what it CANNOT do
        water.gdshader  <- generated, never edited by hand

**The three hooks, and a candidate must define all three even if two of them do nothing:**

    vec3 open_sea(vec2 p, float d, float t, vec2 sxy)   the water's colour, as in the sea lab
    vec3 sea_normal(vec2 p, float t, vec3 n, mat4 vm)   the surface normal, in VIEW space, or `n` unchanged
    void light()                                        how the sun is allowed to touch it

**What the prelude hands every candidate** (spliced in above the hooks, identical in all of them):

    uniform float shade         how dark the island's shadow is on the water, 0 = black, 1 = no shadow
    uniform float calm_tiles    tiles from the rock over which the normal bend comes up to full
    float away(float d)         0 on the rock, 1 out at `calm_tiles` — ⚠ MULTIPLY EVERY NORMAL BEND BY IT
    vec3 to_view(vec3 nw, mat4 vm)  a world-space normal turned into the view-space one Godot wants
    float shade_of(float att)   the shared shadow term, so the shadow is the same in all six pictures

⚠⚠ **`away()` is not optional.** The shipped border is the control in this lab; if one candidate bends
the normal right up to the rock, its white line is lit differently from everyone else's and the
comparison is no longer about the open water.

    python prototypes/wave/build.py
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
SHIPPED = HERE.parent.parent / "src" / "view" / "water.gdshader"

HEAD = """// **GENERATED — do not edit. Edit `mech.gdshader` beside it and run `prototypes/wave/build.py`.**
//
// Everything outside the mechanism block is `src/view/water.gdshader`, with `unshaded` swapped out so
// the sea can take light and the island's shadow has somewhere to land. **The shoreline is untouched
// and identical in every candidate.**
"""

PRELUDE = """
// --- WHAT EVERY CANDIDATE IS HANDED, AND IT IS THE SAME IN ALL OF THEM -------------------------
// ⚠⚠ **The shadow lives here, not in a candidate.** It is the shared floor of this whole lab — the one
// thing the user asked for outright — so it is spliced in rather than written five times and drifting.
uniform float shade = 0.74;
// **Tiles from the rock over which a candidate's normal bend comes up to full.** ⚠ The border is the
// control; a bend that reaches the rock re-lights the white line and breaks the comparison.
uniform float calm_tiles = 1.6;

float away(float d) { return smoothstep(0.15, max(calm_tiles, 0.2), d); }

// ⚠⚠ **`VIEW_MATRIX` HAS TO BE HANDED IN.** Godot's built-ins belong to the function they are
// declared for; a global helper that names `VIEW_MATRIX` fails to compile with "Unknown identifier"
// and the shader silently falls back to a magenta default. That is why `sea_normal` takes a `mat4`.
vec3 to_view(vec3 nw, mat4 vm) { return normalize((vm * vec4(normalize(nw), 0.0)).xyz); }

float shade_of(float att) { return mix(clamp(shade, 0.0, 1.0), 1.0, att); }

// ⚠⚠ **What `dot(NORMAL, LIGHT)` reads on water that is perfectly flat**, and it is not 1. The sun
// stands 52 degrees up, so a level surface returns sin(52) = 0.788 and lighting the sea straight off the
// lambert term would darken the whole thing by a fifth before any wave existed. **Every candidate
// divides by this**, so a flat stretch of water comes out exactly the colour it ships with and only the
// SLOPE is visible. ⚠ If the sun's pitch moves in `look.gd`, this moves.
uniform float flat_nl = 0.788;

// The shared relief term: `gain` 0 is the flat sea, 1 is the full lambert swing.
float relief(float nl, float gain) { return mix(1.0, nl / max(flat_nl, 0.05), gain); }

"""

HAND_OFF = "mix(sea.rgb,"
CALL = "mix(open_sea(p, d, t, FRAGCOORD.xy),"
MARK = "\n// --- THIS CANDIDATE: the colour, the normal, and how the sun may touch it ---\n"
NORMAL_LINE = "\tNORMAL = sea_normal(p, t, NORMAL, VIEW_MATRIX);\n"


def build(folder, ship):
    mech = (folder / "mech.gdshader").read_text(encoding="utf-8")
    at = ship.index("void fragment()")
    body = ship[at:]
    if body.count(HAND_OFF) != 1:
        sys.exit("build.py: expected one `%s` in the shipped fragment" % HAND_OFF)
    body = body.replace(HAND_OFF, CALL)
    # ⚠ The normal is set at the END of `fragment()`. The shipped fragment is the last function in the
    # file, so its closing brace is the last one there is.
    cut = body.rstrip().rfind("}")
    body = body[:cut] + NORMAL_LINE + body[cut:]

    top = ship[:at]
    if "render_mode unshaded;" not in top:
        sys.exit("build.py: the shipped sea is no longer `render_mode unshaded` — re-read this splice")
    top = top.replace("render_mode unshaded;",
                      "// ⚠ **`unshaded` swapped out by `prototypes/wave/build.py`.** Ambient is off so the\n"
                      "// only light on this water is the one the candidate's own `light()` asks for.\n"
                      "render_mode ambient_light_disabled;")

    out = HEAD + top + PRELUDE + MARK + mech.rstrip() + "\n\n\n" + body
    (folder / "water.gdshader").write_text(out, encoding="utf-8")
    print("built %s" % folder.name)


def main():
    ship = SHIPPED.read_text(encoding="utf-8")
    made = 0
    for folder in sorted(HERE.iterdir()):
        if folder.is_dir() and (folder / "mech.gdshader").exists():
            build(folder, ship)
            made += 1
    if made == 0:
        print("build.py: no candidate folder has a mech.gdshader yet")


main()
