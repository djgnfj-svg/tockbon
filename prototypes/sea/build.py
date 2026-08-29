"""Generate every candidate's `water.gdshader` from the SHIPPED one plus a snippet.

⚠⚠ **This exists so the shoreline cannot drift between two pictures.** The question this lab asks is
what the OPEN water is made of, and the white border is the control. Hand-copying
`src/view/water.gdshader` into five folders is five chances for a line to differ, and a difference in
the border is the first thing the eye finds. **Here the border is not copied by a person: it is spliced
in by this script**, so it is byte-identical by construction and re-splices the day the shipped one
changes.

**What a candidate folder holds**

    prototypes/sea/NN-name/
        mech.gdshader   <- ONLY the open water: its own uniforms and `open_sea()`
        NOTES.md        <- what it buys / what it costs / what it CANNOT do
        water.gdshader  <- generated, never edited by hand

The one function a `mech.gdshader` must define:

    vec3 open_sea(vec2 p, float d, float t, vec2 sxy)

`p` is the world XZ of the pixel, `d` is signed tiles to the coast (negative on land), `t` is TIME, and
`sxy` is FRAGCOORD.xy — the pixel on the screen, which one candidate needs and the rest ignore.

A `mech.gdshader` may also declare its own `void vertex()`. It is spliced in above `fragment()`, so
everything the shipped file defines — the field uniforms, `sdf`, `vnoise`, `h21` — is already in scope.

    python prototypes/sea/build.py
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
SHIPPED = HERE.parent.parent / "src" / "view" / "water.gdshader"

HEAD = """// **GENERATED — do not edit. Edit `mech.gdshader` beside it and run `prototypes/sea/build.py`.**
//
// Everything outside the mechanism block is `src/view/water.gdshader` verbatim: the shipped shoreline,
// spliced in so it cannot differ from any other candidate's. **The only thing this file decides is the
// colour of the open water**, and it decides it in `open_sea()`.
"""

HAND_OFF = "mix(sea.rgb,"
CALL = "mix(open_sea(p, d, t, FRAGCOORD.xy),"
MARK = "\n// --- THE OPEN WATER: the one thing this candidate decides ---\n"


def build(folder, ship):
    mech = (folder / "mech.gdshader").read_text(encoding="utf-8")
    at = ship.index("void fragment()")
    # ⚠ **The hand-off is spliced into the SHIPPED half only.** A candidate is free to write
    # `mix(sea.rgb, ...)` in its own block — several do — and counting over both halves turns that into
    # a false "the shipped shader changed under us".
    body = ship[at:]
    n = body.count(HAND_OFF)
    if n != 1:
        sys.exit("build.py: expected one `%s` in the shipped fragment, found %d" % (HAND_OFF, n))
    out = HEAD + ship[:at] + MARK + mech.rstrip() + "\n\n\n" + body.replace(HAND_OFF, CALL)
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
