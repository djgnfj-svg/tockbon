# **The buildings that stand on the island.** One run writes `assets/buildings/buildings.glb`, and the
# game clones one node per kind out of it.
#
# WARNING **The node NAMES are the contract.** `field_view.gd` looks each building up by the kind written
# in `island.json` -- `keep`, `house`, `tower`, `store`, `wall`. Rename one here and it silently stops
# being drawn.
#
# WARNING **Style: flat shading, one flat material per part, no texture, no vertex colours.** The island
# is painted with vertex colours and these are not, and that is not an inconsistency: the ground has one
# material because with several every colour boundary landed on a tile edge and drew the grid back. A
# building is its own object -- its boundaries ARE its own edges. The first attempt used vertex colours
# here too and every building came into the game pure white, because the export carried two colour
# attributes and Godot read the empty one.
#
# WARNING **Everything a building has is at an EDGE**, which is where the Bad North talk puts detail: the
# eave that overhangs and the dark band hung off it, the sill the wall stands on, the corner posts. A
# face with detail painted in the middle of it reads as nothing from the game's angle.
#
# Run:  python tools/blender/send.py tools/blender/buildings_build.py
import bmesh
import bpy
import math
import os

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/buildings"

# One tile is one metre, the island's own scale. A 1x1 building is exactly one tile wide.
# WARNING **Lifted for the GAME, not for the render.** A vertical face keeps almost no brightness under
# one sun and an ambient, so a colour that works on a wall has to start much lighter than it looks like
# it should. Ticket 01 carries the rule; these values obey it.
WALL = (0.845, 0.810, 0.740)     # plaster
WALL_D = (0.745, 0.700, 0.630)
WOOD = (0.430, 0.335, 0.250)
WOOD_D = (0.330, 0.250, 0.185)
ROOF = (0.585, 0.310, 0.245)     # fired tile
ROOF_D = (0.455, 0.235, 0.185)   # the shaded pitch
STONE = (0.600, 0.590, 0.565)
STONE_D = (0.480, 0.472, 0.455)
PALETTE = [("wall", WALL), ("wall_d", WALL_D), ("wood", WOOD), ("wood_d", WOOD_D),
           ("roof", ROOF), ("roof_d", ROOF_D), ("stone", STONE), ("stone_d", STONE_D)]

# WARNING **Every stacked part is sunk into the one below it by this much.** A building is boxes on
# boxes, and a box starting exactly where the one below ended shares a plane with it -- both drawn, and
# the renderer with no way to decide which is in front. On a flat white wall that shows as bright and
# dark wedges that shift with the camera, which was read as bad shading and cost two rounds.
SINK = 0.014


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat_mat(name, rgb):
    m = bpy.data.materials.get("b_" + name)
    if m:
        return m
    m = bpy.data.materials.new("b_" + name)
    m.use_nodes = True
    # WARNING Blender 5.1 does NOT name this node "Principled BSDF". Find it by TYPE.
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (to_lin(rgb[0]), to_lin(rgb[1]), to_lin(rgb[2]), 1.0)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Metallic"].default_value = 0.0
    return m


def box(bm, x0, y0, z0, x1, y1, z1, col):
    if z0 > 0.001:
        z0 -= SINK
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = list(r["verts"])
    for v in vs:
        v.co.x = x0 + (v.co.x + 0.5) * (x1 - x0)
        v.co.y = y0 + (v.co.y + 0.5) * (y1 - y0)
        v.co.z = z0 + (v.co.z + 0.5) * (z1 - z0)
    fs = set()
    for v in vs:
        for f in v.link_faces:
            fs.add(f)
    return [(f, col) for f in fs]


def taper(bm, x0, y0, x1, y1, z0, z1, inset, col):
    """A wall that leans in a little.

    WARNING **A corner that is not a right angle is what stops a row of buildings from reading as a row
    of identical cubes** -- the same rule ticket 01 states for the island's corners.
    """
    if z0 > 0.001:
        z0 -= SINK
    lo = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    hi = [(x0 + inset, y0 + inset), (x1 - inset, y0 + inset),
          (x1 - inset, y1 - inset), (x0 + inset, y1 - inset)]
    a = [bm.verts.new((x, y, z0)) for (x, y) in lo]
    b = [bm.verts.new((x, y, z1)) for (x, y) in hi]
    out = []
    for i in range(4):
        j = (i + 1) % 4
        out.append((bm.faces.new((a[i], a[j], b[j], b[i])), col))
    out.append((bm.faces.new(list(reversed(a))), col))
    out.append((bm.faces.new(b), col))
    return out


def gable(bm, x0, y0, x1, y1, z0, z1, eave, col, col_d):
    """A pitched roof with a real OVERHANG, and the overhang is the point: the shadow it throws is a line
    where two surfaces meet, which is where the talk says the detail belongs."""
    ex0, ey0, ex1, ey1 = x0 - eave, y0 - eave, x1 + eave, y1 + eave
    ym = (y0 + y1) * 0.5

    def v(x, y, z):
        return bm.verts.new((x, y, z))

    a0, a1 = v(ex0, ey0, z0), v(ex1, ey0, z0)
    b0, b1 = v(ex0, ey1, z0), v(ex1, ey1, z0)
    r0, r1 = v(ex0, ym, z1), v(ex1, ym, z1)
    out = [(bm.faces.new((a0, a1, r1, r0)), col),
           (bm.faces.new((b1, b0, r0, r1)), col_d),
           (bm.faces.new((a0, r0, b0)), col_d),
           (bm.faces.new((a1, b1, r1)), col_d),
           (bm.faces.new((a0, b0, b1, a1)), col_d)]
    # the fascia: a thin dark band hung off the two eaves. It draws the roof's edge as a line.
    out += box(bm, ex0, ey0 - 0.012, z0 - 0.055, ex1, ey0 + 0.012, z0, col_d)
    out += box(bm, ex0, ey1 - 0.012, z0 - 0.055, ex1, ey1 + 0.012, z0, col_d)
    return out


def hip(bm, x0, y0, x1, y1, z0, z1, eave, col, col_d):
    """A four-sided pitched cap. Every face takes a different tone from the sun's angle, which is what
    gives it a silhouette from directly above."""
    ex0, ey0, ex1, ey1 = x0 - eave, y0 - eave, x1 + eave, y1 + eave
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5

    def v(x, y, z):
        return bm.verts.new((x, y, z))

    c = [v(ex0, ey0, z0), v(ex1, ey0, z0), v(ex1, ey1, z0), v(ex0, ey1, z0)]
    top = v(cx, cy, z1)
    out = []
    for i in range(4):
        j = (i + 1) % 4
        out.append((bm.faces.new((c[i], c[j], top)), col if i == 0 else col_d))
    out.append((bm.faces.new(list(reversed(c))), col_d))
    return out


def post(bm, x, y, z0, z1, r, col):
    return box(bm, x - r, y - r, z0, x + r, y + r, z1, col)


# --- the five ---------------------------------------------------------------------------------------
# Every one is centred on (0, 0) and stands ON z = 0, so the game places it by its footprint centre and
# never has to know how tall it is.

def _keep(bm):
    """**2x2. The hall the run is lost with**, so it has to be what the eye finds first: a stone plinth
    nothing else has, walls that lean, four corner posts, and a tower off ONE corner so its outline is
    not symmetrical."""
    out = []
    out += box(bm, -1.0, -1.0, 0.0, 1.0, 1.0, 0.18, STONE)
    out += box(bm, -0.96, -0.96, 0.18, 0.96, 0.96, 0.26, STONE_D)
    out += taper(bm, -0.86, -0.86, 0.86, 0.86, 0.26, 0.98, 0.05, WALL)
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        out += post(bm, sx * 0.80, sy * 0.80, 0.26, 1.02, 0.055, WOOD)
    out += gable(bm, -0.86, -0.86, 0.86, 0.86, 0.98, 1.62, 0.14, ROOF, ROOF_D)
    out += box(bm, -0.06, -0.06, 1.55, 0.06, 0.06, 1.62, WOOD_D)          # ridge peg
    out += taper(bm, 0.34, 0.34, 0.86, 0.86, 0.26, 1.74, 0.03, WALL)
    out += box(bm, 0.28, 0.28, 1.62, 0.92, 0.92, 1.74, WOOD)              # the tower's gallery
    out += hip(bm, 0.34, 0.34, 0.86, 0.86, 1.74, 2.18, 0.07, ROOF, ROOF_D)
    # WARNING **A chimney has to clear the ridge it comes through.** At 1.46 its cap sat inside the
    # pitch and read as a hole punched in the roof.
    out += box(bm, -0.62, -0.62, 0.98, -0.46, -0.46, 1.86, STONE)
    out += box(bm, -0.16, -0.90, 0.18, 0.16, -0.84, 0.68, WOOD_D)         # door
    return out


def _house(bm):
    """1x1, and the one there will be many of. Everything it has is at an edge: the eave, the sill band
    it stands on, the eave beam, and a chimney that breaks the silhouette."""
    out = []
    out += box(bm, -0.40, -0.40, 0.0, 0.40, 0.40, 0.09, STONE_D)
    out += taper(bm, -0.38, -0.38, 0.38, 0.38, 0.09, 0.50, 0.035, WALL)
    out += box(bm, -0.36, -0.37, 0.44, 0.36, -0.30, 0.50, WOOD)
    out += gable(bm, -0.36, -0.36, 0.36, 0.36, 0.50, 0.86, 0.10, ROOF, ROOF_D)
    out += box(bm, -0.09, -0.44, 0.09, 0.09, -0.36, 0.34, WOOD_D)
    out += box(bm, 0.14, 0.16, 0.50, 0.26, 0.28, 0.98, STONE)
    return out


def _tower(bm):
    """1x1. **Height is the only thing that reads from the game's angle**, so the piece whose job is to
    see far is the piece that is visibly high. The gallery OVERHANGS its shaft, which is its
    silhouette."""
    out = []
    out += box(bm, -0.30, -0.30, 0.0, 0.30, 0.30, 0.14, STONE_D)
    out += taper(bm, -0.26, -0.26, 0.26, 0.26, 0.14, 1.24, 0.045, STONE)
    out += box(bm, -0.34, -0.34, 1.24, 0.34, 0.34, 1.34, WOOD)
    out += box(bm, -0.30, -0.30, 1.34, 0.30, 0.30, 1.54, WOOD_D)
    out += hip(bm, -0.30, -0.30, 0.30, 0.30, 1.54, 1.92, 0.08, ROOF, ROOF_D)
    return out


def _store(bm):
    """1x1. **The one that is NOT pitched.** A row of buildings that all carry the same roof is a
    texture, and one flat top is what breaks it."""
    out = []
    out += box(bm, -0.44, -0.36, 0.0, 0.44, 0.36, 0.08, STONE_D)
    out += taper(bm, -0.42, -0.34, 0.42, 0.34, 0.08, 0.44, 0.03, WOOD)
    for x in (-0.28, 0.0, 0.28):
        out += box(bm, x - 0.035, -0.36, 0.08, x + 0.035, 0.36, 0.44, WOOD_D)   # the studs
    out += box(bm, -0.48, -0.40, 0.44, 0.48, 0.40, 0.50, ROOF_D)
    out += box(bm, -0.46, -0.38, 0.50, 0.46, 0.38, 0.54, ROOF)
    return out


def _wall(bm):
    """1x1. Low enough that a body standing behind it still reads. Its coping is the detail, and the two
    stones sit slightly off each other so a run of them is not one extruded line."""
    out = []
    out += box(bm, -0.5, -0.15, 0.0, 0.02, 0.15, 0.40, STONE)
    out += box(bm, -0.02, -0.17, 0.0, 0.5, 0.17, 0.36, STONE_D)
    out += box(bm, -0.5, -0.20, 0.40, 0.02, 0.20, 0.47, STONE_D)
    out += box(bm, -0.02, -0.21, 0.36, 0.5, 0.21, 0.43, STONE)
    return out


BUILDS = [("keep", _keep, 2, 2, "\ubcf8\ucc44"),
          ("house", _house, 1, 1, "\uc9d1"),
          ("tower", _tower, 1, 1, "\ub9dd\ub8e8"),
          ("store", _store, 1, 1, "\ucc3d\uace0"),
          ("wall", _wall, 1, 1, "\ub3cc\ub2f4")]


def make(name, fn):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    bm = bmesh.new()
    painted = fn(bm)
    slot = {rgb: i for i, (_n, rgb) in enumerate(PALETTE)}
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
    # walls wrong. Flat shading moved to a `sharp_face` attribute and the glTF exporter reads THAT; the
    # old per-polygon flag was written, exported as nothing, and every box came into the game with
    # smoothed vertex normals -- a gradient corner to corner and a hard crease down the silhouette.
    for p in ob.data.polygons:
        p.use_smooth = False
    ob.data.shade_flat()
    return ob


def build():
    names = []
    for i, (name, fn, _w, _h, _label) in enumerate(BUILDS):
        ob = make(name, fn)
        ob.location = (i * 2.6, -22.0, 0.0)
        names.append(name)
    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o.name in names)
    bpy.context.view_layer.objects.active = bpy.data.objects["keep"]
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/buildings.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    print("buildings: " + ", ".join(names))


build()
