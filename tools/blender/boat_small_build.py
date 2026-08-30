# **The small boat — four seats.** One run writes `assets/props/boat_small.glb`.
#
# WARNING **This is a smaller KIND of boat, not `boat.glb` seen from further away.** Length is 0.58 of
# the big one but beam is 0.75 of it, so length/beam drops from 2.59 to 2.00 — the proportion is what
# says "small craft", and a uniform shrink would say nothing at all.
#
# WARNING **Every face in this file is planar BY CONSTRUCTION, and `check()` proves it before export.**
# glTF carries quads as triangle pairs. A quad whose four corners are not coplanar arrives in the
# engine as two triangles with two different normals, and flat shading then paints them two different
# tones that meet at the diagonal — the bright/dark wedge banding `how-nets-lie` records on the outer
# hull. Blender never shows it, because Blender shades the n-gon with one normal. ⇒ **the check has to
# be here, not on the screen.** Three shapes are used and all three are planar for a reason:
#
#   · `prism`  — one plan polygon at two heights. Side quads are vertical planes
#   · `band`   — two plan polygons at two heights. Walls vertical, caps at constant z
#   · `taper`  — the plan polygon scaled about (0, 0) between the two heights, which puts every side
#                quad on ONE cone with its apex on the Z axis. **A loft that scales each station
#                separately does NOT do this** and is where the non-planar hull comes from
#
# WARNING **The colours are spread across a real value range** — hull 0.29 luma against rim 0.73, a
# ratio of 2.5. `boat.glb`'s five wood tones live between 0.50 and 0.67, a ratio of 1.36, and the sun
# closes that gap entirely: on screen the whole boat reads as one cream tone and the dark hull the
# ticket describes is not visible. See ticket 01 — on flat-shaded art the colour IS the information.
#
# WARNING **Bow is +X, up is +Z, origin dead centre at the keel** — the same frame `boat.glb` is in,
# because the game places a boat by that origin and takes its standoff from the hull half-length.
#
# Run:  python tools/blender/send.py tools/blender/boat_small_build.py
import bmesh
import bpy
import math
import os

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props"
NAME = "boat_small"

# --- colour ------------------------------------------------------------------------------------------
# sRGB. The luma beside each one is what the spread is judged on; nothing reads it.
HULL = (0.375, 0.268, 0.192)   # 0.285
BENCH = (0.500, 0.365, 0.245)  # 0.385
MAST = (0.560, 0.415, 0.275)   # 0.436
DECK = (0.655, 0.505, 0.355)   # 0.526
RIM = (0.820, 0.715, 0.560)    # 0.727
SAIL = (0.945, 0.915, 0.835)   # 0.916
PALETTE = [("hull", HULL), ("bench", BENCH), ("mast", MAST), ("deck", DECK), ("rim", RIM),
           ("sail", SAIL)]

# --- plan ---------------------------------------------------------------------------------------------
# (x, half-beam) from the stem aft. **The midbody stations share a half-beam on purpose**: two
# identical values make the sides of the boat exactly parallel there, which is the straight flat panel
# that reads as a hard-chine hull instead of the ellipse `boat.glb` has. The count is the same six
# stations the big boat uses — **angular is where the stations sit, not how many there are.**
OUTER = [(1.455, 0.075), (0.780, 0.560), (0.190, 0.705),
         (-0.430, 0.705), (-1.030, 0.585), (-1.455, 0.400)]
# The inside of the planking. Inset ~0.075 across, ~0.11 fore and aft.
INNER = [(1.290, 0.030), (0.700, 0.490), (0.170, 0.628),
         (-0.400, 0.628), (-0.955, 0.512), (-1.350, 0.330)]
# The gunwale's outboard edge — 0.045 proud of the hull, and it is what sets the overall 3.00 x 1.50.
RIM_OUT = [(1.500, 0.120), (0.800, 0.605), (0.195, 0.750),
           (-0.440, 0.750), (-1.055, 0.630), (-1.500, 0.445)]

Z_KEEL = 0.0
Z_FLOOR = 0.215    # inside of the bottom planking
Z_DECK = 0.245     # what a rider stands on
Z_SHEER = 0.500    # top of the hull, under the gunwale
Z_RIM0, Z_RIM1 = 0.475, 0.565
KEEL_SCALE = 0.72  # the plan at the keel, as a fraction of the plan at the sheer -- 21 degrees of flare

# WARNING **Stacked parts are sunk into what they stand on.** Two faces at the same height z-fight, and
# on flat-shaded art that reads as wedges of wrong shading that swim as the camera turns -- the same
# symptom as a non-planar quad, from a different cause.
SINK = 0.012

BENCH_X = 0.42          # fore bench at +, aft bench at -
BENCH_HALF_X = 0.0675
BENCH_Z0, BENCH_Z1 = 0.305, 0.360
BENCH_HALF_Y_FORE = 0.535   # each thwart stops just inside INNER at its own station
BENCH_HALF_Y_AFT = 0.600


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat_mat(name, rgb):
    m = bpy.data.materials.get("bs_" + name)
    if m:
        return m
    m = bpy.data.materials.new("bs_" + name)
    m.use_nodes = True
    # WARNING **Blender 5.1 does NOT name this node "Principled BSDF".** Find it by TYPE.
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (to_lin(rgb[0]), to_lin(rgb[1]), to_lin(rgb[2]), 1.0)
    b.inputs["Roughness"].default_value = 1.0
    return m


# --- rings --------------------------------------------------------------------------------------------

def ccw(pts):
    """The ring wound anticlockwise seen from +Z, so every builder below can assume one direction."""
    a = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        a += x0 * y1 - x1 * y0
    return list(pts) if a > 0.0 else list(reversed(pts))


def hull_ring(stations):
    """Half a hull, given bow to stern, closed into a full ring down one side and back up the other."""
    return ccw([(x, hb) for x, hb in stations] + [(x, -hb) for x, hb in reversed(stations)])


def rect(cx, cy, hx, hy):
    return ccw([(cx - hx, cy - hy), (cx + hx, cy - hy), (cx + hx, cy + hy), (cx - hx, cy + hy)])


# --- the three planar shapes ---------------------------------------------------------------------------

def prism(bm, ring, z0, z1, col):
    lo = [bm.verts.new((x, y, z0)) for x, y in ring]
    hi = [bm.verts.new((x, y, z1)) for x, y in ring]
    out = []
    for i in range(len(ring)):
        j = (i + 1) % len(ring)
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    out.append((bm.faces.new(lo), col))
    out.append((bm.faces.new(hi), col))
    return out


def taper(bm, ring, z0, z1, k, col):
    """`ring` at z1, the same ring scaled by k about (0, 0) at z0.

    ⚠ The scale is about the ORIGIN and nothing else, which is what puts every side quad on one cone
    and keeps all four of its corners in one plane. Scaling each station by its own factor breaks that.
    """
    lo = [bm.verts.new((x * k, y * k, z0)) for x, y in ring]
    hi = [bm.verts.new((x, y, z1)) for x, y in ring]
    out = []
    for i in range(len(ring)):
        j = (i + 1) % len(ring)
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    out.append((bm.faces.new(lo), col))
    out.append((bm.faces.new(hi), col))
    return out


def band(bm, outer, inner, z0, z1, col):
    """A closed ring with a hole through it. `outer` and `inner` correspond index for index."""
    olo = [bm.verts.new((x, y, z0)) for x, y in outer]
    ohi = [bm.verts.new((x, y, z1)) for x, y in outer]
    ilo = [bm.verts.new((x, y, z0)) for x, y in inner]
    ihi = [bm.verts.new((x, y, z1)) for x, y in inner]
    out = []
    for i in range(len(outer)):
        j = (i + 1) % len(outer)
        out.append((bm.faces.new((olo[i], olo[j], ohi[j], ohi[i])), col))
        out.append((bm.faces.new((ilo[i], ilo[j], ihi[j], ihi[i])), col))
        out.append((bm.faces.new((ohi[i], ohi[j], ihi[j], ihi[i])), col))
        out.append((bm.faces.new((olo[i], olo[j], ilo[j], ilo[i])), col))
    return out


def hull_shell(bm, outer, inner, col):
    """Outside, gunwale-top, inside and bottom as one closed shell.

    ⚠ The outside is a `taper` and the inside is straight up and down, so the planking thickens toward
    the keel. Nothing looks at it and the alternative -- tapering the inside too -- puts the two
    surfaces on different cones and stops the top ring from being flat.
    """
    k = KEEL_SCALE
    olo = [bm.verts.new((x * k, y * k, Z_KEEL)) for x, y in outer]
    ohi = [bm.verts.new((x, y, Z_SHEER)) for x, y in outer]
    ihi = [bm.verts.new((x, y, Z_SHEER)) for x, y in inner]
    ilo = [bm.verts.new((x, y, Z_FLOOR)) for x, y in inner]
    out = []
    for i in range(len(outer)):
        j = (i + 1) % len(outer)
        out.append((bm.faces.new((olo[i], olo[j], ohi[j], ohi[i])), col))
        out.append((bm.faces.new((ohi[i], ohi[j], ihi[j], ihi[i])), col))
        out.append((bm.faces.new((ihi[i], ihi[j], ilo[j], ilo[i])), col))
    out.append((bm.faces.new(olo), col))
    out.append((bm.faces.new(ilo), col))
    return out


def scaled(ring, s):
    return [(x * s, y * s) for x, y in ring]


# --- the boat -------------------------------------------------------------------------------------------

def build_boat(bm):
    outer = hull_ring(OUTER)
    inner = hull_ring(INNER)
    rim_o = hull_ring(RIM_OUT)
    out = []

    out += hull_shell(bm, outer, inner, HULL)
    # The gunwale sits 0.025 down into the hull top, so their two horizontal faces never meet.
    # ⚠ **Its inboard wall is pulled 0.018 further in than the hull's**, which is the same problem
    # standing up: both walls are vertical on the same ring, they overlap over the 0.025 the gunwale is
    # sunk, and left flush they were 12 z-fighting pairs. The lip that buys it is what a gunwale is.
    out += band(bm, rim_o, scaled(inner, 0.982), Z_RIM0, Z_RIM1, RIM)
    # The deck floats 0.007 clear of the inside of the bottom planking, back to back with it.
    out += prism(bm, scaled(inner, 0.985), Z_FLOOR + 0.007, Z_DECK, DECK)

    # Two thwarts. **Each one stops just inside the hull at its OWN station** -- the boat narrows
    # forward, so a shared half-width would put the fore thwart through the planking.
    out += prism(bm, rect(BENCH_X, 0.0, BENCH_HALF_X, BENCH_HALF_Y_FORE), BENCH_Z0, BENCH_Z1, BENCH)
    out += prism(bm, rect(-BENCH_X, 0.0, BENCH_HALF_X, BENCH_HALF_Y_AFT), BENCH_Z0, BENCH_Z1, BENCH)

    # A post at the stem and a low block at the stern, so which end is the front reads from above.
    # ⚠⚠ **Both are BENCH, not RIM.** `boat.glb` paints its two the gunwale's colour and gets away
    # with it because its gunwale is thin. This one's is wide at the ends, so rim-on-rim made the post
    # and the block read as two notches CUT INTO the gunwale — the opposite of telling the ends apart,
    # which is the only reason either of them exists. Joinery colour separates them from the rim.
    # ⚠ Both are pulled inboard of the gunwale's inner line at their own station for the same reason.
    out += prism(bm, rect(1.130, 0.0, 0.085, 0.065), Z_FLOOR - SINK, 0.790, BENCH)
    out += prism(bm, rect(-1.190, 0.0, 0.075, 0.135), Z_DECK - SINK, 0.520, BENCH)

    # Mast: a square section tapering about its own axis, so its four sides stay planar.
    m_cx, m_cy = -0.110, 0.0
    m_lo = rect(0.0, 0.0, 0.045, 0.045)
    m_hi = rect(0.0, 0.0, 0.030, 0.030)
    lo = [bm.verts.new((m_cx + x, m_cy + y, Z_DECK - SINK)) for x, y in m_lo]
    hi = [bm.verts.new((m_cx + x, m_cy + y, 1.260)) for x, y in m_hi]
    for i in range(4):
        j = (i + 1) % 4
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), MAST))
    out.append((bm.faces.new(lo), MAST))
    out.append((bm.faces.new(hi), MAST))

    # Yard across the beam, sunk onto the head of the sail.
    out += prism(bm, rect(-0.110, 0.0, 0.035, 0.310), 1.213, 1.265, MAST)

    # **A square sail 0.60 across against a 1.50 beam.** `boat.glb`'s is 1.77 across a 2.01 beam and
    # ticket 47 already records that it hides the deck from the game's angle; a small boat seen from
    # above has less deck to hide. The belly is a single crease forward, and both panels are planar
    # because the foot and the head run the same plan line at two heights.
    sail_ring = ccw([(-0.045, -0.300), (0.030, 0.0), (-0.045, 0.300),
                     (-0.067, 0.300), (0.008, 0.0), (-0.067, -0.300)])
    out += prism(bm, sail_ring, 0.500, 1.225, SAIL)
    return out


# --- the check ---------------------------------------------------------------------------------------

def check(me):
    """Every polygon flat, and no two faces sharing a plane. Raises rather than exporting a lie."""
    worst = 0.0
    worst_i = -1
    for p in me.polygons:
        n = p.normal
        c = p.center
        for vi in p.vertices:
            d = abs((me.vertices[vi].co - c).dot(n))
            if d > worst:
                worst, worst_i = d, p.index
    if worst > 1e-5:
        raise RuntimeError("NON-PLANAR face %d, %.6f off its own plane -- it will band in the engine"
                           % (worst_i, worst))
    # Coplanar-and-overlapping pairs z-fight. Cheap stand-in: two faces with the same normal whose
    # centres differ by less than SINK along that normal and by little across it.
    bad = 0
    ps = list(me.polygons)
    for a in range(len(ps)):
        for b in range(a + 1, len(ps)):
            fa, fb = ps[a], ps[b]
            if fa.normal.dot(fb.normal) < 0.999:
                continue
            d = fb.center - fa.center
            if abs(d.dot(fa.normal)) < 0.004 and d.length < 0.35:
                bad += 1
    print("check: worst planarity %.2e  ·  near-coplanar face pairs %d" % (worst, bad))
    return worst, bad


def build():
    old = bpy.data.objects.get(NAME)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    # ⚠ **The mesh datablock has to go too, or the next run is `boat_small.001`.** Blender keeps the
    # orphan, the new one takes the next free name, and the glTF writes THAT as the mesh name -- so a
    # file rebuilt twice stops matching a file rebuilt once, over nothing.
    for me in list(bpy.data.meshes):
        if me.name == NAME or me.name.startswith(NAME + "."):
            bpy.data.meshes.remove(me)
    bm = bmesh.new()
    painted = build_boat(bm)
    slot = {rgb: i for i, (_n, rgb) in enumerate(PALETTE)}
    for f, c in painted:
        f.material_index = slot[c]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # WARNING **normal_update BEFORE to_mesh**, or the faces carry whatever normals bmesh left behind.
    bm.normal_update()
    me = bpy.data.meshes.new(NAME)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME, me)
    bpy.context.collection.objects.link(ob)
    for n, rgb in PALETTE:
        ob.data.materials.append(flat_mat(n, rgb))
    # WARNING **`use_smooth = False` IS NOT ENOUGH IN BLENDER 4.1+.** Flat shading moved to a
    # `sharp_face` attribute and the glTF exporter reads THAT -- writing only the old per-polygon flag
    # is what sent the keep into the game with smoothed vertex normals.
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.shade_flat()

    worst, bad = check(ob.data)

    lo = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
    print("%s: faces=%d verts=%d" % (NAME, len(ob.data.polygons), len(ob.data.vertices)))
    print("  blender x[%.3f %.3f] y[%.3f %.3f] z[%.3f %.3f]" % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    print("  size L=%.3f W=%.3f H=%.3f" % (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
    # The four seats, in the frame `Look.BOAT_DECK_SLOTS` is written in: glTF Y-up, so a Blender
    # (x, y, z) lands as (x, z, -y), and a seat sits a quarter of its thwart's width either side.
    for bx, hy in ((BENCH_X, BENCH_HALF_Y_FORE), (-BENCH_X, BENCH_HALF_Y_AFT)):
        for s in (-1, 1):
            print("  slot Vector3(%.3f, %.4f, %.3f)" % (bx, BENCH_Z1, s * hy * 0.5))

    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/boat_small.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    print("wrote " + OUT_DIR + "/boat_small.glb")


build()
