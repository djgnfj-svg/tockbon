"""Generate every candidate's `water.gdshader` from the SHIPPED one plus a snippet.

⚠⚠ **This exists so the SEA cannot drift between two pictures.** The question this lab asks is what
draws the wake behind a boat; the water it is drawn on is the control. Hand-copying
`src/view/water.gdshader` into five folders is five chances for a line to differ, and the eye finds a
difference in the water before it finds a difference in the wake. **Here the sea is not copied by a
person: it is spliced in by this script**, so it is byte-identical by construction and re-splices the
day the shipped one changes.

**What a candidate folder holds**

    prototypes/wake/NN-name/
        mech.gdshader   <- ONLY the wake's own uniforms and `wake()`
        wake.gd         <- the CPU half: history, geometry, whatever this mechanism needs
        NOTES.md        <- what it buys / what it costs / what it CANNOT do
        water.gdshader  <- generated, never edited by hand

The one function a `mech.gdshader` must define:

    vec3 wake(vec3 base, vec2 p, float t)

`base` is the sea colour the shipped shader arrived at, `p` is the world XZ of the pixel and `t` is
TIME. **A candidate that draws nothing in the water returns `base` unchanged** — three of the five do,
because their wake is geometry, and they still go through this script so their sea is the same sea.

    python prototypes/wake/build.py
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
SHIPPED = HERE.parent.parent / "src" / "view" / "water.gdshader"

HEAD = """// **GENERATED — do not edit. Edit `mech.gdshader` beside it and run `prototypes/wake/build.py`.**
//
// Everything outside the mechanism block is `src/view/water.gdshader` verbatim: the shipped flat sea
// and the shipped 해안선, spliced in so they cannot differ from any other candidate's. **The only
// thing this file decides is what happens to the water behind the boat**, in `wake()`.
"""

HAND_OFF = "ALBEDO = mix(sea.rgb,"
MARK = "\n// --- THE WAKE: the one thing this candidate decides ---\n"


def build(folder, ship):
    mech = (folder / "mech.gdshader").read_text(encoding="utf-8")
    if ship.count(HAND_OFF) != 1:
        sys.exit("build.py: expected one `%s` in the shipped shader, found %d"
                 % (HAND_OFF, ship.count(HAND_OFF)))
    at = ship.index(HAND_OFF)
    end = ship.index(";", at) + 1
    expr = ship[at + len("ALBEDO = "):end - 1]
    tail = "vec3 base = %s;\n\tALBEDO = wake(base, p, t);" % expr

    top = ship.index("void fragment()")
    out = (HEAD + ship[:top] + MARK + mech.rstrip() + "\n\n\n"
           + ship[top:at] + tail + ship[end:])
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
