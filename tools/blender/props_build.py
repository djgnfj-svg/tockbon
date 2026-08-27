# **What is scattered on the island** -- trees, rocks, bushes. One run writes `assets/props/props.glb`.
#
# WARNING **Nothing is standing on the island right now** (2026-08-27, the user: 「바위랑 나무는 다
# 지워주고 집만 남겨」). `island_build.py` writes an empty `props` list, so these are built and exported
# and placed nowhere. They come back one kind at a time, chosen by hand.
#
# WARNING **A prop is not a building.** It stands on the ground, it is never placed by a player, and
# nothing about it is decided at run time.
#
# WARNING **Style: flat shading, one flat material per part, no texture.** Same reasoning as the
# buildings; there is no reason to relearn it here.
#
# WARNING **A prop is deliberately SMALL against a one-metre tile.** The game looks down from a distance
# and a tree the size of a house stops being scenery and starts being terrain.
#
# Run:  python tools/blender/send.py tools/blender/props_build.py
import bmesh
import bpy
import math
import os

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props"

TRUNK = (0.372, 0.278, 0.202)
TRUNK_D = (0.290, 0.215, 0.155)
LEAF = (0.345, 0.470, 0.295)
LEAF_D = (0.255, 0.360, 0.225)
LEAF_L = (0.430, 0.545, 0.330)
ROCK = (0.575, 0.572, 0.552)
ROCK_D = (0.445, 0.447, 0.432)
BUSH = (0.392, 0.495, 0.325)
PALETTE = [("trunk", TRUNK), ("trunk_d", TRUNK_D), ("leaf", LEAF), ("leaf_d", LEAF_D),
           ("leaf_l", LEAF_L), ("rock", ROCK), ("rock_d", ROCK_D), ("bush", BUSH)]

# WARNING **Stacked parts are sunk into what they stand on.** Two coplanar faces drawn at the same
# height z-fight, which on flat-shaded art reads as wedges of wrong shading that move with the camera.
SINK = 0.012


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat_mat(name, rgb):
    m = bpy.data.materials.get("p_" + name)
    if m:
        return m
    m = bpy.data.materials.new("p_" + name)
    m.use_nodes = True
    # WARNING Blender 5.1 does NOT name this node "Principled BSDF". Find it by TYPE.
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (to_lin(rgb[0]), to_lin(rgb[1]), to_lin(rgb[2]), 1.0)
    b.inputs["Roughness"].default_value = 1.0
    return m


def drum(bm, cx, cy, z0, z1, r0, r1, sides, col, twist=0.0, sx=1.0, sy=1.0):
    if z0 > 0.001:
        z0 -= SINK
    lo, hi = [], []
    for k in range(sides):
        a = 2 * math.pi * k / sides
        lo.append(bm.verts.new((cx + math.cos(a) * r0 * sx, cy + math.sin(a) * r0 * sy, z0)))
        b = a + twist
        hi.append(bm.verts.new((cx + math.cos(b) * r1 * sx, cy + math.sin(b) * r1 * sy, z1)))
    out = []
    for k in range(sides):
        j = (k + 1) % sides
        out.append((bm.faces.new((lo[k], lo[j], hi[j], hi[k])), col))
    out.append((bm.faces.new(list(reversed(lo))), col))
    out.append((bm.faces.new(hi), col))
    return out


def cone(bm, cx, cy, z0, z1, r, sides, col, twist=0.0):
    if z0 > 0.001:
        z0 -= SINK
    ring = []
    for k in range(sides):
        a = 2 * math.pi * k / sides + twist
        ring.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z0)))
    tip = bm.verts.new((cx, cy, z1))
    out = [(bm.faces.new((ring[k], ring[(k + 1) % sides], tip)), col) for k in range(sides)]
    out.append((bm.faces.new(list(reversed(ring))), col))
    return out


# --- the five. Every one is centred on (0, 0) and stands ON z = 0 ------------------------------------

def _pine(bm):
    """THREE tiers, each turned and shrunk, and the top two lean.

    WARNING **Two clean cones read as one smooth triangle from the game's angle.** Three broken ones
    read as a tree. The tallest prop, and the one that gives the island a skyline.
    """
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.22, 0.050, 0.040, 5, TRUNK_D)
    out += cone(bm, 0.0, 0.0, 0.14, 0.44, 0.215, 6, LEAF_D)
    out += cone(bm, 0.015, -0.01, 0.34, 0.62, 0.160, 6, LEAF, twist=0.5)
    out += cone(bm, -0.01, 0.015, 0.54, 0.80, 0.100, 5, LEAF_L, twist=0.9)
    return out


def _tree(bm):
    """A round head made of THREE overlapping lumps at different heights, not one drum.

    WARNING **Seen from above, one drum is a flat green disc.** Three make a mass with a broken outline,
    and the lightest one on top is what says which way the sun is. A second silhouette beside the pine
    is on purpose: one tree shape planted everywhere is a texture, two are woodland.
    """
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.26, 0.055, 0.045, 5, TRUNK)
    out += drum(bm, -0.06, -0.03, 0.20, 0.44, 0.175, 0.185, 6, LEAF_D, twist=0.3)
    out += drum(bm, 0.07, 0.05, 0.26, 0.50, 0.155, 0.165, 6, LEAF, twist=0.8)
    out += cone(bm, 0.0, 0.0, 0.44, 0.66, 0.175, 6, LEAF_L, twist=0.4)
    return out


def _rock(bm):
    """A boulder with a smaller one at its foot. Its lean and its companion are what stop a field of
    them from reading as a row of buttons."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.16, 0.205, 0.150, 5, ROCK, sx=1.15, sy=0.88)
    out += cone(bm, 0.025, 0.015, 0.14, 0.30, 0.155, 5, ROCK_D, twist=0.7)
    out += drum(bm, -0.17, 0.10, 0.0, 0.085, 0.095, 0.070, 5, ROCK_D, twist=1.1)
    return out


def _stone(bm):
    """A small flat stone, half sunk. It fills bare ground between the bigger props without adding
    another skyline."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.070, 0.135, 0.105, 5, ROCK_D, twist=0.3, sx=1.2, sy=0.85)
    return out


def _bush(bm):
    """Two blobs leaning apart. One blob is a button; two are a bush."""
    out = []
    out += drum(bm, -0.045, 0.0, 0.0, 0.135, 0.135, 0.125, 6, BUSH)
    out += cone(bm, -0.045, 0.0, 0.125, 0.255, 0.125, 6, BUSH, twist=0.5)
    out += drum(bm, 0.075, 0.04, 0.0, 0.10, 0.100, 0.092, 5, LEAF_D, twist=0.9)
    out += cone(bm, 0.075, 0.04, 0.095, 0.195, 0.092, 5, LEAF_D, twist=0.2)
    return out


PROPS = [("pine", _pine), ("tree", _tree), ("rock", _rock), ("stone", _stone), ("bush", _bush)]


def make(name, fn):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    bm = bmesh.new()
    painted = fn(bm)
    slot = {rgb: i for i, (_n, rgb) in enumerate(PALETTE)}
    for f, c in painted:
        f.material_index = slot.get(c, 0)
    # WARNING **normal_update BEFORE to_mesh**, or the faces carry whatever normals bmesh left behind.
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for n, rgb in PALETTE:
        ob.data.materials.append(flat_mat(n, rgb))
    # WARNING **`use_smooth = False` IS NOT ENOUGH IN BLENDER 4.1+.** Flat shading moved to a
    # `sharp_face` attribute and the glTF exporter reads THAT.
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.shade_flat()
    return ob


def build():
    names = []
    for i, (name, fn) in enumerate(PROPS):
        ob = make(name, fn)
        ob.location = (i * 1.2, -25.0, 0.0)
        names.append(name)
    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o.name in names)
    bpy.context.view_layer.objects.active = bpy.data.objects["pine"]
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/props.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    print("props: " + ", ".join(names))


build()
