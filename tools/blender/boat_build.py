# **The beasts' boat — eight seats.** One run writes `assets/props/boat.glb`.
#
# WARNING **THE FILE EXISTED FOR DAYS WITH NO SCRIPT BEHIND IT.** `boat.glb` was made by hand in a
# session that kept nothing, so it could not be re-baked at all. This file is that missing half. See
# `boat_small_build.py` for the smaller craft — it is a different KIND of boat, not this one scaled.
#
# WARNING **Bow is +X, up is +Z, origin dead centre at the keel.** The game places a boat by that origin
# and takes its standoff from the hull's half-length, and `net_boats` reads the half-length, the beam,
# the centring and the keel height straight back off this mesh's own box. `assert_box` below pins all
# four HERE, so a change that would move them goes red in the bake rather than on the sea.
#
# WARNING **THE FOUR BENCHES ARE UNIT CUBES CARRYING THEIR SIZE IN THE NODE TRANSFORM, AND THAT IS NOT
# A STYLE.** `net_boats` derives every seat in `Look.BOAT_DECK_SLOTS` from `bench.position` and
# `bench.scale` — seat height is `position.y + scale.y / 2`, seat offset is `scale.z / 4`. Bake a bench
# as baked-in geometry and the net can no longer see where the seats are; move one and eight riders
# stand in mid-air. **`BENCHES` below is the one place those numbers live.**
#
# Run:  python tools/blender/send.py tools/blender/boat_build.py
import bmesh
import bpy
import os

from mathutils import Vector

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props"
PREFIX = "boat"

# --- colour -------------------------------------------------------------------------------------------
# sRGB, and **the same six the small boat is painted with, so the two read as one fleet.** The luma
# beside each is what the spread is judged on; nothing reads it.
#
# WARNING **THE OLD BOAT'S FIVE WOOD TONES ALL SAT BETWEEN 0.495 AND 0.672** — a hull-to-gunwale ratio
# of 1.36, which the sun closes entirely: on screen the whole boat was one cream tone and the dark hull
# was not there at all. This spread is 2.55. **On flat-shaded art the colour IS the information** —
# ticket 01, six rejected rounds of it.
HULL = (0.375, 0.268, 0.192)   # 0.285
BENCH = (0.500, 0.365, 0.245)  # 0.385
MAST = (0.560, 0.415, 0.275)   # 0.436
DECK = (0.655, 0.505, 0.355)   # 0.526
RIM = (0.820, 0.715, 0.560)    # 0.727
SAIL = (0.945, 0.915, 0.835)   # 0.916

# --- the stations ---------------------------------------------------------------------------------------
# **(x, the gunwale's outboard half-beam, the height of the top of the gunwale).**
#
# WARNING **EVERY RING IN THIS FILE SHARES THESE x VALUES AND DIFFERS ONLY IN HALF-BEAM, AND THE SHEER
# IS A FUNCTION OF x ALONE. THAT PAIR IS WHAT MAKES A RISING SHEER PLANAR.** A cap spanning two rings
# has its four corners at two x values and takes its height from x, so it lies on the plane z = a*x + c
# and its planarity does not depend on the beam at all. Let a ring carry its own x — the usual way to
# inset a hull — and the same cap goes out of plane the moment the sheer stops being flat, which is the
# bright/dark wedge banding `how-nets-lie` records. **Measured on the old `boat.glb`: 24 hull polygons
# and 38 sail polygons split out of plane, the worst by 20.4 and 35.8 degrees.**
#
# WARNING **THREE STATIONS IN A ROW ARE COLLINEAR IN PLAN ON PURPOSE, TWICE.** S0-S1-S2 lie on one line
# and so do S3-S4-S5, so the bow and the aft run are each ONE flat panel with no seam down the middle,
# and the sheer still kinks over them because the sheer is carried by the stations. **Two panels four
# degrees apart do not read as a curve; they read as a seam.** ⇒ either exactly one plane, or a chine
# worth seeing. What is left is 8 plan faces in all: stem, bow x2, midbody x2, aft x2, transom.
#
# ⚠ **The midbody run is exactly parallel** — S2 and S3 share a half-beam, so 2.20 조각 of the side is
# one flat rectangle. That is where the hard-chine read comes from, and it is WHERE the stations sit
# rather than how many there are.
# WARNING **CUT 5.20 -> 4.20 조각 LONG AND THE SHEER DROPPED 0.710 -> 0.560 AMIDSHIPS** (2026-08-31,
# the user at the screen: 「the boat's left and right sides are too big and too high, lower them so the
# wolf shows more. Cut the useless part of the boat right down and make the monsters stand out」).
#
# **What was measured before the cut, and it is what the two numbers come from:**
#  · **The benches span x -1.55 to 1.45 — 3.00 조각 — and the hull was 5.20.** The other **2.20 조각 was
#    bow and stern with nobody on them**: 1.15 forward of the front bench and 1.05 aft of the back one.
#    ⇒ **The stem and the transom came in to +/-2.10**, which leaves 0.65 at each end. Nothing that
#    carries a wolf moved, and `BENCHES` is untouched.
#  · **The gunwale stood 0.273 조각 above the seat amidships** (sheer 0.710, seat top 0.4375) and 0.311
#    at the forward bench. A wolf's ink is about 0.5 조각 tall, so **the side hid roughly half of it.**
#    ⇒ **0.560 amidships puts the freeboard at 0.123** — the wolf clears the rail by about three
#    quarters of its height instead of half.
#
# ⚠⚠ **THE RISING SHEER IS KEPT, JUST SHORTER.** It was 0.310 proud of midships at the stem and 0.220 at
# the transom; it is now 0.260 and 0.160. **A flat sheer reads as a box, not a boat** — the rise is what
# the planarity argument above is protecting and it is not what was making the sides tall.
#
# ⚠ **COLLINEARITY WAS RECOMPUTED, NOT ASSUMED.** S1 sits on the new S0-S2 line and S4 on the new
# S3-S5 line, both re-solved for the moved ends — the two flat panels the comment above depends on.
# ⚠ **`Rules.BOAT_HULL_HALF_TILES` must move 2.6 -> 2.1 with this.** The sim measures its standoff, its
# wake and its arrival off that number, and a hull shorter than the constant beaches short of the sand.
STATIONS = [
    (2.100, 0.070, 0.820),   # S0 the stem face
    (1.700, 0.444, 0.716),   # S1 on the S0-S2 line
    (1.100, 1.005, 0.560),   # S2 full beam
    (-1.100, 1.005, 0.560),  # S3 full beam -- S2..S3 is the parallel run
    (-1.780, 0.648, 0.669),  # S4 on the S3-S5 line
    (-2.100, 0.480, 0.720),  # S5 the transom
]

# --- the rings ------------------------------------------------------------------------------------------
# Each is derived from the one outboard of it. **Nothing here is typed twice**: the plan shape is
# `STATIONS` and everything else is an inset of it.
#
# WARNING **AN INSET PULLS THE TWO END STATIONS BACK IN x AS WELL AS IN BEAM, AND IT HAS TO.** Left at
# the same x, the stem face and the transom of every ring land in ONE vertical plane -- the planking's
# inside and outside then z-fight over their whole overlap. **Measured: the first build raised four
# such pairs at x = +/-2.600.**
# ⚠ **The pull-back is bounded by the sheer's own linear pieces.** The planarity argument on `STATIONS`
# needs all four corners of a cap to take their height from ONE straight run of the sheer; a station
# shifted inside its own run keeps that, a station shifted past the next one does not.
RIM_PROUD = 0.050     # the gunwale stands this far outboard of the hull
PLANK = 0.100         # thickness of the planking amidships
PLANK_END = 0.130     # and fore and aft, where a plan inset alone would turn the stem inside out
RIM_LIP = 0.030       # how far the gunwale's inboard face is pulled in past the planking

# --- the heights ------------------------------------------------------------------------------------------
Z_KEEL = 0.0
Z_FLOOR = 0.250       # inside of the bottom planking
Z_DECK = 0.300        # what the benches stand on
RAIL_H = 0.155        # the gunwale's own height, hung under the sheer
HULL_LIP = 0.115      # the hull's top edge, below the sheer -- 0.040 up inside the gunwale, so the
                      # hull's open rim is buried in solid rather than left as a hole to see through

# WARNING **Stacked parts are sunk into what they stand on.** Two faces at the same height z-fight, and
# on flat-shaded art that reads as wedges of wrong shading that swim as the camera turns -- the same
# symptom as a non-planar quad, from a different cause.
SINK = 0.012

# --- the benches --------------------------------------------------------------------------------------
# **(x, half-width across the beam).** ⚠⚠ **These eight numbers ARE `Look.BOAT_DECK_SLOTS`** — the seat
# is `(x, BENCH_Z + BENCH_T/2, +/- half/2)` and `net_boats` recomputes exactly that off the exported
# node. **Change one and say so**, because the constant in `look.gd` does not follow on its own.
BENCHES = [(-1.55, 0.292), (-0.55, 0.406), (0.45, 0.410), (1.45, 0.310)]
BENCH_Z = 0.410       # the plank's middle
BENCH_T = 0.055       # the plank's thickness
BENCH_HALF_X = 0.080  # half its fore-and-aft width
LEG_HALF = 0.040
LEG_INSET = 0.055     # a leg stands this far in from the end of its own plank

# --- the rig ---------------------------------------------------------------------------------------------
MAST_X = -0.05        # in the gap between the two middle benches
MAST_TOP = 2.100      # ⚠ **the whole model's height, and it is pinned by `assert_box`**
YARD_Z0, YARD_Z1 = 1.845, 1.905
YARD_HALF_Y = 0.610
# WARNING **THE SAIL USED TO SPAN 1.77 OF A 2.01 BEAM AND YOU ONLY EVER SEE IT EDGE-ON.** From the
# game's camera it read as a narrow blade, and its shadow landed as a grey stain across the upper half
# of the deck -- which at survey zoom is what the eye actually reads. This one is 1.10 across, half the
# area, and bellied so a panel faces the camera instead of an edge.
SAIL_HALF_Y = 0.550
SAIL_Z0, SAIL_Z1 = 0.870, 1.870
SAIL_BELLY = 0.135
SAIL_THICK = 0.025

# The stem and the stern post, as (bottom centre x, top centre x, z0, z1, half-x, half-y). **Both are
# sheared boxes**: bottom rectangle at z0, top rectangle at z1, offset in x. Every face of a sheared box
# is planar -- the two beam-side faces lie in planes of constant y, the two end faces in planes tilted
# in x and z, and the cap and floor are level.
# ⚠⚠ **BOTH ARE `BENCH`, NOT `RIM`.** The small boat measured this: a post painted the gunwale's own
# colour reads as a NOTCH CUT INTO the gunwale, which is the opposite of telling the two ends apart, and
# telling the ends apart is the only reason either of them exists.
#
# ⚠⚠ **THESE TWO POSTS SET THE BOAT'S LENGTH, NOT THE HULL, AND THAT IS WHY THE FIRST CUT DID NOTHING**
# (2026-08-31). `STATIONS` was pulled in to +/-2.10 and `assert_box` still reported **[-2.5500 2.5750]**:
# the stem's top centre 2.440 plus its own half-x 0.135 is 2.575, and the tail's -2.400 minus 0.150 is
# -2.550. **The hull was already shorter than the box the whole time.**
# ⇒ **Both were shifted the same 0.500 the hull moved**, so the rake and the gap to the planking are
# what they were. **Shortening this boat means moving three things, and the box guard is what says so.**
#
# ⚠ **Their tops came down with the sheer** — the stem stood 1.520 against a 0.710 sheer, more than
# twice the side it grows out of, and it read as mast-like clutter at the bow rather than as a stem.
# **1.150 keeps it the tallest thing forward of the mast without being a second mast.**
STEM = (1.660, 1.940, 0.290, 1.150, 0.135, 0.048)
TAIL = (-1.720, -1.900, 0.290, 0.920, 0.150, 0.085)

# **What the box has to come out as.** ⚠ `Rules.BOAT_HULL_HALF_TILES` (2.1 since 2026-08-31) and
# `BOAT_HULL_BEAM_TILES` (2.01) are that box read back, and 61 beaches are placed off the standoff
# built on them. ⚠⚠ **CHANGE THIS AND `rules.gd` IN THE SAME EDIT** — the sim beaches the boat at a
# standoff computed from the constant, so a hull shorter than the constant stops short of the sand.
BOX_LO = (-2.100, -1.005, 0.0)
BOX_HI = (2.100, 1.005, MAST_TOP)


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat_mat(name, rgb):
    """⚠⚠ **Rebuilt every run, never reused.** `how-nets-lie` has a colour that landed wrong twice
    because `flat_mat` handed back the material a PREVIOUS run had made: the fix for the maths appeared
    to do nothing, and the next attempt went off converting twice and produced black."""
    key = PREFIX + "_" + name
    old = bpy.data.materials.get(key)
    if old:
        bpy.data.materials.remove(old)
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    # WARNING **Blender 5.1 does NOT name this node "Principled BSDF".** Find it by TYPE.
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (to_lin(rgb[0]), to_lin(rgb[1]), to_lin(rgb[2]), 1.0)
    b.inputs["Roughness"].default_value = 1.0
    return m


# --- plan and sheer ---------------------------------------------------------------------------------

def sheer(x):
    """The top of the gunwale at `x`, linear between stations.

    ⚠ Every ring vertex sits exactly on a station, so this returns a station's own number and the
    interpolation only ever runs for the parts that are placed by x (the mast step, the posts).
    """
    if x >= STATIONS[0][0]:
        return STATIONS[0][2]
    for k in range(len(STATIONS) - 1):
        x0, _b0, h0 = STATIONS[k]
        x1, _b1, h1 = STATIONS[k + 1]
        if x1 <= x <= x0:
            return h0 + (h1 - h0) * (x0 - x) / (x0 - x1)
    return STATIONS[-1][2]


def ccw(pts):
    """The ring wound anticlockwise seen from +Z, so every builder below can assume one direction."""
    a = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        a += x0 * y1 - x1 * y0
    return list(pts) if a > 0.0 else list(reversed(pts))


def ring(pts):
    """A half-hull given bow to stern as (x, half-beam), closed into a full ring down one side and
    back up the other."""
    return ccw([(x, b) for x, b in pts] + [(x, -b) for x, b in reversed(pts)])


def rect(cx, cy, hx, hy):
    return ccw([(cx - hx, cy - hy), (cx + hx, cy - hy), (cx + hx, cy + hy), (cx - hx, cy + hy)])


def inset(pts, beam, end):
    """`pts` narrowed by `beam` and, at the bow and the stern station only, pulled `end` back in x."""
    n = len(pts)
    out = []
    for k, (x, b) in enumerate(pts):
        dx = -end if k == 0 else (end if k == n - 1 else 0.0)
        out.append((x + dx, beam(b)))
    return out


RIM_OUT = [(x, b) for x, b, _h in STATIONS]
HULL_OUT = inset(RIM_OUT, lambda b: max(b - RIM_PROUD, 0.018), RIM_PROUD)
# ⚠ **Proportional near the ends, a constant thickness amidships.** A flat inset alone turns the plan
# inside out at the stem, where the hull is 0.02 of half-beam.
INNER = inset(HULL_OUT, lambda b: max(0.86 * b, b - PLANK), PLANK_END)
RIM_IN = inset(INNER, lambda b: b - min(RIM_LIP, 0.35 * b), 0.030)
DECK_PLAN = inset(INNER, lambda b: max(0.80 * b, b - 0.030), 0.040)


# --- the planar shapes ------------------------------------------------------------------------------
# ⚠ Each returns a list of (face, colour). **A vertical wall is planar whatever its two rings' heights
# are** — its four corners share one vertical plane. **A cap is planar because the height comes from x
# alone**, see the note on `STATIONS`.

def wall(bm, plan, z_lo, z_hi, col):
    """A skirt around `plan`. `z_lo` and `z_hi` are called with x."""
    lo = [bm.verts.new((x, y, z_lo(x))) for x, y in plan]
    hi = [bm.verts.new((x, y, z_hi(x))) for x, y in plan]
    out = []
    for i in range(len(plan)):
        j = (i + 1) % len(plan)
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    return out, lo, hi


def cap(bm, outer, inner, z, col):
    """The annulus between two rings, at `z(x)`. The two rings correspond index for index."""
    o = [bm.verts.new((x, y, z(x))) for x, y in outer]
    n = [bm.verts.new((x, y, z(x))) for x, y in inner]
    out = []
    for i in range(len(outer)):
        j = (i + 1) % len(outer)
        out.append((bm.faces.new((o[i], o[j], n[j], n[i])), col))
    return out, o, n


def prism(bm, plan, z0, z1, col):
    lo = [bm.verts.new((x, y, z0)) for x, y in plan]
    hi = [bm.verts.new((x, y, z1)) for x, y in plan]
    out = []
    for i in range(len(plan)):
        j = (i + 1) % len(plan)
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    out.append((bm.faces.new(lo), col))
    out.append((bm.faces.new(hi), col))
    return out


def taper(bm, plan, z0, z1, k, cx, cy, col):
    """`plan` at z0, the same plan scaled by k about (cx, cy) at z1.

    ⚠ The scale is about ONE point, which puts every side quad on one cone whose apex stands on the
    vertical line through that point and keeps all four of its corners in one plane. Scaling each
    corner by its own factor breaks that, and that is where a non-planar hull comes from.
    ⚠ **`cx, cy` is the part's own axis and not the world origin.** Scaled about (0, 0) a mast that
    does not stand at the origin leans toward it as it rises.
    """
    lo = [bm.verts.new((x, y, z0)) for x, y in plan]
    hi = [bm.verts.new((cx + (x - cx) * k, cy + (y - cy) * k, z1)) for x, y in plan]
    out = []
    for i in range(len(plan)):
        j = (i + 1) % len(plan)
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    out.append((bm.faces.new(lo), col))
    out.append((bm.faces.new(hi), col))
    return out


def sheared_box(bm, x0, x1, z0, z1, hx, hy, col):
    """A box whose top rectangle is centred at x1 and whose bottom is centred at x0 — a raked post."""
    lo = ccw([(x0 - hx, -hy), (x0 + hx, -hy), (x0 + hx, hy), (x0 - hx, hy)])
    hi = [(x + (x1 - x0), y) for x, y in lo]
    vl = [bm.verts.new((x, y, z0)) for x, y in lo]
    vh = [bm.verts.new((x, y, z1)) for x, y in hi]
    out = []
    for i in range(4):
        j = (i + 1) % 4
        out.append((bm.faces.new((vl[i], vl[j], vh[j], vh[i])), col))
    out.append((bm.faces.new(vl), col))
    out.append((bm.faces.new(vh), col))
    return out


# --- the parts ---------------------------------------------------------------------------------------

def build_hull(bm):
    """One closed shell: the outside, the top of the planking, the inside and the floor.

    ⚠⚠ **The sides are straight walls, not flared.** A flare needs the keel ring to be the sheer ring
    scaled about a point, and that construction stops being planar the moment the sheer varies — the
    two cannot both be had, and the rising sheer is what stops the boat reading as a dish. **Straight
    walls are also what the island is made of** (ticket 01: 옆면은 곧은 벽), so the boat and the ground
    it lands on are now saying the same thing.
    ⚠ **A chine ledge was built here and taken out.** With the hull flaring outward the ledge is an
    UNDERSIDE, not a lit edge — and to stay outboard of the planking it could only be 0.03 wide, about
    a pixel at the opening framing. It cost geometry and drew nothing.
    """
    out_ = ring(HULL_OUT)
    inn = ring(INNER)
    top = lambda x: sheer(x) - HULL_LIP
    faces = []
    f, out_bot, _t = wall(bm, out_, lambda _x: Z_KEEL, top, HULL)
    faces += f
    faces.append((bm.faces.new(out_bot), HULL))
    f, _o, _n = cap(bm, out_, inn, top, HULL)
    faces += f
    f, in_bot, _t = wall(bm, inn, lambda _x: Z_FLOOR, top, HULL)
    faces += f
    faces.append((bm.faces.new(in_bot), HULL))
    return faces


def build_rim(bm):
    """The gunwale — the bright line that draws the boat's outline at survey zoom.

    ⚠ **Its inboard face is pulled `RIM_LIP` further in than the planking's.** Left flush, the two are
    vertical faces on the same ring overlapping over the height the gunwale is sunk, and that is a
    column of z-fighting all the way round. The lip that buys it is what a gunwale is.
    """
    out_ = ring(RIM_OUT)
    inn = ring(RIM_IN)
    lo = lambda x: sheer(x) - RAIL_H
    faces = []
    f, _a, _b = wall(bm, out_, lo, sheer, RIM)
    faces += f
    f, _a, _b = wall(bm, inn, lo, sheer, RIM)
    faces += f
    f, _a, _b = cap(bm, out_, inn, sheer, RIM)
    faces += f
    f, _a, _b = cap(bm, out_, inn, lo, RIM)
    faces += f
    return faces


def build_deck(bm):
    """The floor a rider stands on, and the legs the benches stand on.

    ⚠ **The legs live here and not on the bench** only because a bench has to export as a unit cube
    carrying its size in its node transform — see the note at the top of the file. They are placed off
    `BENCHES`, so there is still one table deciding where a bench is.
    """
    plan = ring(DECK_PLAN)
    faces = prism(bm, plan, Z_FLOOR + 0.008, Z_DECK, DECK)
    for bx, half in BENCHES:
        for s in (-1, 1):
            ly = s * (half - LEG_INSET)
            faces += prism(bm, rect(bx, ly, LEG_HALF, LEG_HALF),
                           Z_DECK - SINK, BENCH_Z - BENCH_T * 0.5 + 0.006, BENCH)
    return faces


def build_mast(bm):
    return taper(bm, rect(MAST_X, 0.0, 0.075, 0.075), Z_DECK - SINK, MAST_TOP, 0.60,
                 MAST_X, 0.0, MAST)


def build_yard(bm):
    return prism(bm, rect(MAST_X, 0.0, 0.050, YARD_HALF_Y), YARD_Z0, YARD_Z1, MAST)


def build_sail(bm):
    """A square sail with a belly forward. Foot and head run the same plan line at two heights, so
    every panel is a vertical plane."""
    f = MAST_X + SAIL_BELLY
    b = MAST_X + SAIL_BELLY - SAIL_THICK
    plan = ccw([(MAST_X + 0.020, -SAIL_HALF_Y), (f, 0.0), (MAST_X + 0.020, SAIL_HALF_Y),
                (MAST_X - 0.005, SAIL_HALF_Y), (b, 0.0), (MAST_X - 0.005, -SAIL_HALF_Y)])
    return prism(bm, plan, SAIL_Z0, SAIL_Z1, SAIL)


def post_local(spec):
    """A post's geometry around its own centre, and where that centre goes.

    ⚠⚠ **`boat_stem` and `boat_tail` MUST carry their place in the node transform, not baked into the
    mesh.** `net_boats` asks which end is the bow by comparing the two nodes' `position.x` — built at
    the origin they both read 0.0, the check cannot tell them apart, and a re-export that turned the
    hull round would sail every boat backwards.
    """
    x0, x1, z0, z1, hx, hy = spec
    cx = (x0 + x1) * 0.5
    cz = (z0 + z1) * 0.5
    return (x0 - cx, x1 - cx, z0 - cz, z1 - cz, hx, hy), (cx, 0.0, cz)


def build_stem(bm):
    return sheared_box(bm, *post_local(STEM)[0], BENCH)


def build_tail(bm):
    return sheared_box(bm, *post_local(TAIL)[0], BENCH)


# --- the checks --------------------------------------------------------------------------------------

def planarity(me):
    """The worst distance any corner stands off its own polygon's plane."""
    worst = 0.0
    worst_i = -1
    for p in me.polygons:
        n = p.normal
        c = p.center
        for vi in p.vertices:
            d = abs((me.vertices[vi].co - c).dot(n))
            if d > worst:
                worst, worst_i = d, p.index
    return worst, worst_i


def overlaps(me):
    """Pairs of faces sharing a plane AND actually covering each other. **These z-fight.**

    ⚠⚠ **TOUCHING EDGE TO EDGE IS NOT OVERLAPPING, AND A DISTANCE TEST CANNOT TELL THEM APART.** A
    first version compared centre distance against the faces' own radius and reddened on four pairs
    that were correct: the two halves of a cap either side of the stem, and the two panels of the
    collinear bow run, which this file builds coplanar ON PURPOSE. **A check that reddens on the thing
    it was built to permit gets relaxed until it measures nothing.** ⇒ project both faces into the
    plane they share and ask whether their footprints really cross, with a hair of margin so a shared
    edge does not count as a crossing.
    """
    ps = list(me.polygons)
    co = [[me.vertices[i].co for i in p.vertices] for p in ps]
    bad = []
    for a in range(len(ps)):
        fa = ps[a]
        n = fa.normal
        axis = min(range(3), key=lambda i: abs(n[i]))
        u = n.cross(Vector((1.0 if axis == 0 else 0.0, 1.0 if axis == 1 else 0.0,
                            1.0 if axis == 2 else 0.0))).normalized()
        v = n.cross(u)
        for b in range(a + 1, len(ps)):
            fb = ps[b]
            if abs(n.dot(fb.normal)) < 0.999:
                continue
            if abs((fb.center - fa.center).dot(n)) >= 0.004:
                continue
            pa = [(p.dot(u), p.dot(v)) for p in co[a]]
            pb = [(p.dot(u), p.dot(v)) for p in co[b]]
            if _cross(pa, pb):
                bad.append((fa.index, fb.index))
    return bad


def _convex(poly):
    sign = 0
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n], poly[(i + 2) % n]
        z = (x1 - x0) * (y2 - y1) - (y1 - y0) * (x2 - x1)
        if abs(z) < 1e-12:
            continue
        s = 1 if z > 0 else -1
        if sign and s != sign:
            return False
        sign = s
    return True


def _cross(pa, pb):
    """Do two polygons in one plane cover each other? **Sharing an edge is not covering.**

    ⚠ Separating axes, which is exact for convex outlines and is why the bow's cap and the stem's cap
    stopped being reported — the edge they share separates them. **A non-convex outline falls back to
    boxes**, which over-reports rather than under-reports: a check may not go quiet on a shape it
    cannot reason about.
    """
    eps = 1e-4
    if _convex(pa) and _convex(pb):
        for poly in (pa, pb):
            n = len(poly)
            for i in range(n):
                (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
                mx, my = -(y1 - y0), (x1 - x0)
                m = (mx * mx + my * my) ** 0.5
                if m < 1e-12:
                    continue
                mx, my = mx / m, my / m
                qa = [x * mx + y * my for x, y in pa]
                qb = [x * mx + y * my for x, y in pb]
                if min(qa) > max(qb) - eps or min(qb) > max(qa) - eps:
                    return False
        return True
    for i in (0, 1):
        qa = [p[i] for p in pa]
        qb = [p[i] for p in pb]
        if min(qa) > max(qb) - eps or min(qb) > max(qa) - eps:
            return False
    return True


def check(me, name):
    worst, worst_i = planarity(me)
    if worst > 1e-5:
        raise RuntimeError("%s: NON-PLANAR face %d, %.3e off its own plane -- it will band in the engine"
                           % (name, worst_i, worst))
    bad = overlaps(me)
    if bad:
        raise RuntimeError("%s: %d coplanar overlapping face pairs, first %s -- these z-fight"
                           % (name, len(bad), bad[0]))
    # WARNING **Flat shading does NOT live on `polygon.use_smooth` any more; the exporter reads the
    # `sharp_face` attribute.** Measured on this Blender (5.1.1): writing the old per-polygon flag DOES
    # set the attribute, so the two are the same thing here -- but `buildings_build.py` records a
    # version where it did not, and a mesh that exports with smoothed normals is the keep's old defect.
    # ⇒ **assert the thing the exporter actually reads**, not the thing the script wrote.
    sf = me.attributes.get("sharp_face")
    if sf is None or not all(d.value for d in sf.data):
        raise RuntimeError("%s: not flat-shaded where the exporter looks (sharp_face)" % name)
    return worst


def assert_box(lo, hi):
    for i, axis in enumerate("xyz"):
        if abs(lo[i] - BOX_LO[i]) > 1e-4 or abs(hi[i] - BOX_HI[i]) > 1e-4:
            raise RuntimeError("box moved on %s: [%.4f %.4f], wanted [%.4f %.4f] -- "
                               "Rules.BOAT_HULL_HALF_TILES and BOAT_HULL_BEAM_TILES are this box"
                               % (axis, lo[i], hi[i], BOX_LO[i], BOX_HI[i]))


def prove_the_checks_bite():
    """⚠⚠ **A check nobody has seen fail is not a check.** Both of the two above are run here against a
    mesh built to break them, and this raises if either comes back clean."""
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in ((0, 0, 0), (1, 0, 0), (1, 1, 0.3), (0, 1, 0))]
    bm.faces.new(v)
    me = bpy.data.meshes.new("boat_probe_bent")
    bm.to_mesh(me)
    bm.free()
    if planarity(me)[0] <= 1e-5:
        raise RuntimeError("the planarity check does not see a quad 0.3 out of plane")
    bpy.data.meshes.remove(me)

    bm = bmesh.new()
    for dz in (0.0, 0.001):
        v = [bm.verts.new((x, y, dz)) for x, y in ((0, 0), (1, 0), (1, 1), (0, 1))]
        bm.faces.new(v)
    me = bpy.data.meshes.new("boat_probe_stacked")
    bm.to_mesh(me)
    bm.free()
    if not overlaps(me):
        raise RuntimeError("the overlap check does not see two faces 0.001 apart on one plane")
    bpy.data.meshes.remove(me)

    # **Half on top of each other still counts.** Without this, a check that only saw exact duplicates
    # would pass everything the hull actually does wrong.
    bm = bmesh.new()
    for ox, dz in ((0.0, 0.0), (0.5, 0.001)):
        v = [bm.verts.new((ox + x, y, dz)) for x, y in ((0, 0), (1, 0), (1, 1), (0, 1))]
        bm.faces.new(v)
    me = bpy.data.meshes.new("boat_probe_half")
    bm.to_mesh(me)
    bm.free()
    if not overlaps(me):
        raise RuntimeError("the overlap check does not see two faces half on top of each other")
    bpy.data.meshes.remove(me)

    # And the other way round: two coplanar faces merely SIDE BY SIDE must NOT be reported, or the
    # check reddens on the collinear bow panels this file builds on purpose. ⚠ **The second pair is
    # the shape that actually caught it out** — a wedge sharing one edge with a long panel, which is
    # every cap around the stem, and whose bounding boxes overlap although the faces do not.
    bm = bmesh.new()
    for ox in (0.0, 1.0):
        v = [bm.verts.new((ox + x, y, 0.0)) for x, y in ((0, 0), (1, 0), (1, 1), (0, 1))]
        bm.faces.new(v)
    for quad in (((1.0, -1.0), (1.0, 1.0), (1.6, 0.4), (1.6, -0.4)),
                 ((1.6, 0.4), (1.6, -0.4), (2.2, -0.2), (2.2, 0.2))):
        bm.faces.new([bm.verts.new((x, y, 1.0)) for x, y in quad])
    me = bpy.data.meshes.new("boat_probe_side")
    bm.to_mesh(me)
    bm.free()
    if overlaps(me):
        raise RuntimeError("the overlap check reports faces that only touch along an edge")
    bpy.data.meshes.remove(me)


# --- building ------------------------------------------------------------------------------------------

PALETTE = [("hull", HULL), ("bench", BENCH), ("mast", MAST), ("deck", DECK), ("rim", RIM),
           ("sail", SAIL)]

# **Every part is built in the boat's own coordinates and its node sits at the origin.** ⚠ The four
# benches are the exception and the reason is at the top of the file.
# ⚠ `boat_stem` and `boat_tail` are named because `net_boats` asks which end is the bow by comparing
# their two node positions — so those two DO carry a location, set from `STEM` and `TAIL`.
ORIGIN = (0.0, 0.0, 0.0)
PARTS = [
    ("boat_hull", build_hull, ORIGIN),
    ("boat_rim", build_rim, ORIGIN),
    ("boat_deck", build_deck, ORIGIN),
    ("boat_mast", build_mast, ORIGIN),
    ("boat_yard", build_yard, ORIGIN),
    ("boat_sail", build_sail, ORIGIN),
    ("boat_stem", build_stem, post_local(STEM)[1]),
    ("boat_tail", build_tail, post_local(TAIL)[1]),
]


def unit_cube(bm):
    lo = ccw([(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)])
    return prism(bm, lo, -0.5, 0.5, BENCH)


def make(name, builder, mats):
    bm = bmesh.new()
    painted = builder(bm)
    slot = {rgb: i for i, (_n, rgb) in enumerate(PALETTE)}
    for f, c in painted:
        f.material_index = slot[c]
    # WARNING **WELD FIRST, OR `recalc_face_normals` HAS NOTHING TO REASON FROM.** Every builder above
    # makes its own vertices, so before this the part is a heap of disconnected faces and "which way is
    # out" is undecidable — recalc leaves them however they were built. **Winding decides whether a
    # face is drawn at all** (the materials cull back faces), and a stair once looked like an empty
    # notch for a whole round because of it. Welding turns each part into a closed shell, and then
    # outward is a fact rather than a hope.
    # ⚠ It does not soften anything: `sharp_face` below makes the exporter split every corner again.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # WARNING **normal_update BEFORE to_mesh**, or the faces carry whatever normals bmesh left behind.
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for m in mats:
        ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.shade_flat()
    check(ob.data, name)
    return ob


def build():
    prove_the_checks_bite()
    names = [n for n, _b, _l in PARTS] + ["boat_bench_%d" % k for k in range(len(BENCHES))]
    for n in names:
        old = bpy.data.objects.get(n)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
    # ⚠ **The mesh datablock has to go too, or the next run is `boat_hull.001`.** Blender keeps the
    # orphan, the new one takes the next free name, and the glTF writes THAT as the mesh name — so a
    # file rebuilt twice stops matching a file rebuilt once, over nothing.
    for me in list(bpy.data.meshes):
        if me.name in names or any(me.name.startswith(n + ".") for n in names):
            bpy.data.meshes.remove(me)

    mats = [flat_mat(n, rgb) for n, rgb in PALETTE]
    obs = []
    for name, builder, loc in PARTS:
        ob = make(name, builder, mats)
        ob.location = loc
        obs.append(ob)
    for k, (bx, half) in enumerate(BENCHES):
        ob = make("boat_bench_%d" % k, unit_cube, mats)
        ob.location = (bx, 0.0, BENCH_Z)
        ob.scale = (BENCH_HALF_X * 2.0, half * 2.0, BENCH_T)
        obs.append(ob)
    # ⚠ `matrix_world` is stale until the depsgraph catches up, and the box below is read through it.
    bpy.context.view_layer.update()

    lo = [1e9] * 3
    hi = [-1e9] * 3
    faces = 0
    tris = 0
    for ob in obs:
        faces += len(ob.data.polygons)
        for p in ob.data.polygons:
            tris += len(p.vertices) - 2
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    assert_box(lo, hi)

    # **Every bench inside its own station's planking.** A plank poking through the side is the kind of
    # thing that reads as「the wolves are floating」and gets blamed on the sprite.
    for k, (bx, half) in enumerate(BENCHES):
        room = inner_half_beam(bx)
        if half + LEG_HALF > room:
            raise RuntimeError("bench %d is %.3f wide at x=%.2f and the planking leaves %.3f"
                               % (k, half, bx, room))

    print("boat: objects=%d faces=%d tris=%d" % (len(obs), faces, tris))
    print("  blender x[%.3f %.3f] y[%.3f %.3f] z[%.3f %.3f]"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("  glTF size L=%.3f H=%.3f W=%.3f" % (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]))
    # The eight seats in the frame `Look.BOAT_DECK_SLOTS` is written in: glTF is Y-up, so a Blender
    # (x, y, z) lands as (x, z, -y), and a seat sits a quarter of its plank's width either side.
    for bx, half in BENCHES:
        for s in (-1, 1):
            print("  slot Vector3(%.3f, %.4f, %.3f)" % (bx, BENCH_Z + BENCH_T * 0.5, s * half * 0.5))
    for bx, half in BENCHES:
        print("  bench x=%.2f  freeboard above the seat %.3f  planking half-beam %.3f"
              % (bx, sheer(bx) - (BENCH_Z + BENCH_T * 0.5), inner_half_beam(bx)))

    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o in obs)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/boat.glb", export_format="GLB",
                              use_selection=True, export_apply=False, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    print("wrote " + OUT_DIR + "/boat.glb")


def inner_half_beam(x):
    """How much room the planking leaves at `x`. Same interpolation the sheer uses."""
    if x >= INNER[0][0]:
        return INNER[0][1]
    for k in range(len(INNER) - 1):
        x0, b0 = INNER[k]
        x1, b1 = INNER[k + 1]
        if x1 <= x <= x0:
            return b0 + (b1 - b0) * (x0 - x) / (x0 - x1)
    return INNER[-1][1]


build()
