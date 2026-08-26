# **What is scattered on the island** -- trees, rocks, bushes. One run writes `assets/props/props.glb`
# (what the game draws) and `assets/props/props.json` (the list of kinds).
#
# WARNING **Same rule as the island and the buildings: this script is the SOURCE.** The game reads what
# comes out and owns neither the shape nor the list.
#
# WARNING **A prop is not a building.** It stands on the ground, it is never placed by a player, and
# nothing about it is decided at run time -- where each one goes is worked out by `island_build.py` from
# the tile it sits on, so the same island always dresses itself the same way.
#
# WARNING **Style: flat shading, one flat material per part, no texture.** The buildings settled this
# after their vertex colours came out white; there is no reason to relearn it here.
#
# Run:  python tools/blender/send.py tools/blender/props_build.py
import bmesh
import bpy
import math

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props"

# One tile is one metre. A prop is deliberately SMALL against that: the game looks down from a distance
# and a tree the size of a house stops being scenery and starts being terrain.
TRUNK = (0.352, 0.263, 0.192)
LEAF = (0.318, 0.435, 0.278)
LEAF_D = (0.243, 0.345, 0.216)
ROCK = (0.545, 0.545, 0.525)
ROCK_D = (0.430, 0.432, 0.418)
BUSH = (0.372, 0.470, 0.310)

PALETTE = [("trunk", TRUNK), ("leaf", LEAF), ("leaf_d", LEAF_D),
           ("rock", ROCK), ("rock_d", ROCK_D), ("bush", BUSH)]


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat_mat(name, rgb):
    m = bpy.data.materials.get("p_" + name)
    if m:
        return m
    m = bpy.data.materials.new("p_" + name)
    m.use_nodes = True
    nt = m.node_tree
    # WARNING Blender 5.1 does NOT name this node "Principled BSDF". Find it by TYPE.
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    bsdf.inputs["Base Color"].default_value = (to_linear(rgb[0]), to_linear(rgb[1]), to_linear(rgb[2]), 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return m


# WARNING **Stacked parts are sunk into what they stand on.** Two coplanar faces drawn at the same
# height z-fight, which on flat-shaded art reads as wedges of wrong shading that move with the camera.
SINK = 0.012


def box(bm, x0, y0, z0, x1, y1, z1, col):
    if z0 > 0.001:
        z0 -= SINK
    v = [
        bm.verts.new((x0, y0, z0)), bm.verts.new((x1, y0, z0)),
        bm.verts.new((x1, y1, z0)), bm.verts.new((x0, y1, z0)),
        bm.verts.new((x0, y0, z1)), bm.verts.new((x1, y0, z1)),
        bm.verts.new((x1, y1, z1)), bm.verts.new((x0, y1, z1)),
    ]
    quads = ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0))
    return [(bm.faces.new((v[a], v[b], v[c], v[d])), col) for a, b, c, d in quads]


def cone(bm, cx, cy, z0, z1, r, sides, col, twist=0.0):
    """A pyramid on `sides` sides. WARNING **Five or six sides, never twenty.** The island is flat-shaded;
    a high-sided cone reads as a smooth blob and stops matching the ground it stands on."""
    if z0 > 0.001:
        z0 -= SINK
    ring = []
    for i in range(sides):
        a = twist + 2.0 * math.pi * i / sides
        ring.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z0)))
    tip = bm.verts.new((cx, cy, z1))
    out = []
    for i in range(sides):
        out.append((bm.faces.new((ring[i], ring[(i + 1) % sides], tip)), col))
    out.append((bm.faces.new(list(reversed(ring))), col))
    return out


def drum(bm, cx, cy, z0, z1, r0, r1, sides, col, twist=0.0):
    """A tapered ring -- a rock's body, or a bush. Same rule on sides."""
    if z0 > 0.001:
        z0 -= SINK
    lo, hi = [], []
    for i in range(sides):
        a = twist + 2.0 * math.pi * i / sides
        lo.append(bm.verts.new((cx + math.cos(a) * r0, cy + math.sin(a) * r0, z0)))
        hi.append(bm.verts.new((cx + math.cos(a) * r1, cy + math.sin(a) * r1, z1)))
    out = []
    for i in range(sides):
        j = (i + 1) % sides
        out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), col))
    out.append((bm.faces.new(hi), col))
    out.append((bm.faces.new(list(reversed(lo))), col))
    return out


def make(name, build_fn):
    bm = bmesh.new()
    painted = build_fn(bm)
    slot = {}
    for i, (_n, rgb) in enumerate(PALETTE):
        slot[rgb] = i
    for f, c in painted:
        f.material_index = slot.get(c, 0)
    # WARNING **normal_update BEFORE to_mesh.** Without it the faces carry whatever normals bmesh
    # happened to leave behind, and the shading is not the shading of the shape that was built.
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for n, rgb in PALETTE:
        ob.data.materials.append(flat_mat(n, rgb))
    # WARNING **`use_smooth = False` IS NOT ENOUGH IN BLENDER 4.1+**, and this is what made the keep's
    # walls wrong (2026-08-26, the user: "건물 벽면이 이상함"). Flat shading moved to a `sharp_face`
    # attribute, and the glTF exporter reads THAT; the old per-polygon flag was written, exported as
    # nothing, and every box came into the game with smoothed vertex normals. A cube shaded that way
    # gives each face a gradient from corner to corner and a hard crease down the middle of the
    # silhouette -- which is exactly what the walls were doing.
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.shade_flat()
    return ob


# --- the props ------------------------------------------------------------------------------------
# Every one is centred on (0, 0) and stands ON z = 0.

def _pine(bm):
    """Two stacked cones on a short trunk. The tallest prop, and the one that gives the island a skyline."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.20, 0.045, 0.038, 5, TRUNK)
    out += cone(bm, 0.0, 0.0, 0.16, 0.52, 0.20, 6, LEAF_D)
    out += cone(bm, 0.0, 0.0, 0.38, 0.72, 0.14, 6, LEAF, twist=0.5)
    return out


def _tree(bm):
    """A round-headed tree: a trunk with one wide, low crown. WARNING **A second silhouette, on purpose.**
    An island planted with one tree shape is a texture; two shapes read as woodland."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.24, 0.05, 0.042, 5, TRUNK)
    out += drum(bm, 0.0, 0.0, 0.20, 0.44, 0.20, 0.23, 6, LEAF)
    out += cone(bm, 0.0, 0.0, 0.40, 0.60, 0.22, 6, LEAF_D, twist=0.4)
    return out


def _rock(bm):
    """A boulder: a tapered five-sided drum with a cap, leaning. Its lean is what stops a field of them
    from reading as a row of buttons."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.17, 0.20, 0.15, 5, ROCK)
    out += cone(bm, 0.02, 0.01, 0.15, 0.27, 0.155, 5, ROCK_D, twist=0.7)
    return out


def _stone(bm):
    """A small flat stone, half sunk. It exists to fill the ground between the bigger props without
    adding another skyline."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.075, 0.13, 0.10, 5, ROCK_D, twist=0.3)
    return out


def _bush(bm):
    """A low blob. The cheapest thing that makes bare ground look tended rather than empty."""
    out = []
    out += drum(bm, 0.0, 0.0, 0.0, 0.13, 0.16, 0.145, 6, BUSH)
    out += cone(bm, 0.0, 0.0, 0.12, 0.24, 0.15, 6, BUSH, twist=0.5)
    return out


PROPS = [
    ("pine", _pine),
    ("tree", _tree),
    ("rock", _rock),
    ("stone", _stone),
    ("bush", _bush),
]


def build():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    # WARNING **Materials too.** Blender keeps datablocks between runs, so an edited colour silently
    # keeps the previous run's value and two rebuilds produce an identical file.
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    names = []
    for name, fn in PROPS:
        make(name, fn)
        names.append(name)
    export(names)


def export(names):
    import json
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/props.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    with open(OUT_DIR + "/props.json", "w", encoding="utf-8") as fh:
        json.dump({"props": [n for n, _f in PROPS]}, fh, ensure_ascii=False, indent=1)
    print("exported %d props" % len(PROPS))


build()
