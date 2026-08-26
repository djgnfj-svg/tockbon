# **The buildings that stand on the island.** One run writes `assets/buildings/buildings.glb` (what the
# game draws) and `assets/buildings/buildings.json` (what the game knows about them: footprint and name).
#
# WARNING **Same rule as the island: this script is the SOURCE.** The game reads what comes out and owns
# neither the shape nor the footprint. A building whose picture and whose tile count disagree is the
# defect this arrangement exists to make impossible.
#
# WARNING **Style is the island's style and not a second one**: flat shading, vertex colours, no texture
# and no material per part. A building that shades differently from the ground it stands on reads as
# pasted on.
#
# Run:  python tools/blender/send.py tools/blender/buildings_build.py
import bmesh
import bpy
import math

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/buildings"

# One tile is one metre, the island's own scale. A building that is 1x1 is exactly one tile wide.
WALL = (0.815, 0.775, 0.700)     # plaster
WOOD = (0.400, 0.310, 0.235)     # beams and doors
ROOF = (0.545, 0.290, 0.235)     # fired tile
ROOF_D = (0.430, 0.225, 0.180)   # the shaded pitch
STONE = (0.560, 0.555, 0.530)    # the keep's base


# WARNING **Every stacked part is sunk into the one below it by this much** (2026-08-26, the user:
# "건물 벽면이 이상함"). A building is boxes standing on boxes, and each box was starting exactly where
# the one below ended -- so the lower box's TOP face and the upper box's BOTTOM face were the same plane,
# both drawn, and the renderer had no way to decide which was in front. That is z-fighting, and on a flat
# white wall it shows as bright and dark wedges that shift with the camera. It was read as bad shading
# and two rounds were spent on normals and flat-shading before the real cause was found.
SINK = 0.014


def box(bm, x0, y0, z0, x1, y1, z1, col):
    """An axis-aligned box, its six faces painted one colour.

    WARNING A box that starts above the ground is sunk by `SINK`, so it never shares a plane with what
    it stands on.
    """
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


def gable(bm, x0, y0, x1, y1, z0, z1, over, col_a, col_b):
    """A pitched roof: a ridge running along X, overhanging the walls on every side.

    The two slopes get DIFFERENT colours. Flat shading gives them nearly the same normal-driven tone
    from the game's fixed camera angle, and a roof that comes out one flat colour reads as a lid.
    """
    x0, x1 = x0 - over, x1 + over
    y0, y1 = y0 - over, y1 + over
    ym = (y0 + y1) * 0.5
    # Same rule as `box`: a roof sits on a wall, so its underside must not share the wall's top plane.
    z0 -= SINK
    a0 = bm.verts.new((x0, y0, z0))
    a1 = bm.verts.new((x1, y0, z0))
    b0 = bm.verts.new((x0, y1, z0))
    b1 = bm.verts.new((x1, y1, z0))
    r0 = bm.verts.new((x0, ym, z1))
    r1 = bm.verts.new((x1, ym, z1))
    return [
        (bm.faces.new((a0, a1, r1, r0)), col_a),
        (bm.faces.new((r0, r1, b1, b0)), col_b),
        (bm.faces.new((a0, r0, b0)), col_b),
        (bm.faces.new((r1, a1, b1)), col_b),
    ]


PALETTE = [("wall", WALL), ("wood", WOOD), ("roof", ROOF), ("roof_d", ROOF_D), ("stone", STONE)]


def to_linear(c):
    """WARNING **Blender material colours are LINEAR, vertex colours are sRGB, and mixing the two is
    how the first buildings came out washed pink.** The palette above is written the way a colour is
    picked -- in sRGB -- so it has to be converted before it is handed to a material, or every tone
    lands several shades too light.
    """
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def for_export(c):
    """WARNING **Convert ONCE, and only once.** Measured 2026-08-26, after getting it wrong in both
    directions: glTF stores `baseColorFactor` in LINEAR and Godot reads it as linear, while a colour is
    PICKED in sRGB. Blender's exporter writes Base Color through unchanged, so one conversion here is
    exactly what the file needs.

    WARNING The reason this looked like it needed two is worth keeping: `flat_mat` reuses a material by
    name and Blender keeps datablocks between runs, so the first (unconverted) colours survived every
    rebuild and the fix appeared to do nothing. `build()` clears materials now.
    """
    return to_linear(c)


def flat_mat(name, rgb):
    m = bpy.data.materials.get("b_" + name)
    if m:
        return m
    m = bpy.data.materials.new("b_" + name)
    m.use_nodes = True
    nt = m.node_tree
    # WARNING Blender 5.1 does NOT name this node "Principled BSDF" -- looking it up by name raises,
    # and this repo lost an afternoon to that once already. Find it by TYPE.
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    bsdf.inputs["Base Color"].default_value = (for_export(rgb[0]), for_export(rgb[1]), for_export(rgb[2]), 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return m


def make(name, build_fn):
    """Builds one object from a function returning `(face, colour)` pairs.

    WARNING **Buildings are painted with MATERIALS, the island with vertex colours, and that is not an
    inconsistency.** The ground has one material on purpose: with several, every colour boundary landed
    on a tile edge and drew the grid back. A building is its own object -- its boundaries are its own
    edges, which is exactly where they belong. The first attempt used vertex colours here too and every
    building came into the game pure white: the export carried two colour attributes and Godot read the
    empty one.
    """
    bm = bmesh.new()
    painted = build_fn(bm)
    slot_of = {}
    for i, (mat_name, rgb) in enumerate(PALETTE):
        slot_of[rgb] = i
    for f, c in painted:
        f.material_index = slot_of.get(c, 0)
    # WARNING **normal_update BEFORE to_mesh.** Without it the faces carry whatever normals bmesh
    # happened to leave behind, and the shading is not the shading of the shape that was built.
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for mat_name, rgb in PALETTE:
        ob.data.materials.append(flat_mat(mat_name, rgb))
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


# --- the buildings --------------------------------------------------------------------------------
# Every one is centred on (0, 0) and stands ON z = 0, so the game places it by its footprint centre and
# never has to know how tall it is.

def _keep(bm):
    """**The hall in the middle of the island.** 2x2, and the one the game is LOST with -- the user:
    "island centre house burns, you die". So it has to be what the eye finds first: the tallest roof, a
    stone base nothing else has, and a tower off one corner so its outline is not symmetrical."""
    out = []
    out += box(bm, -1.0, -1.0, 0.0, 1.0, 1.0, 0.22, STONE)
    out += box(bm, -0.86, -0.86, 0.22, 0.86, 0.86, 0.95, WALL)
    out += gable(bm, -0.86, -0.86, 0.86, 0.86, 0.95, 1.62, 0.12, ROOF, ROOF_D)
    out += box(bm, 0.34, 0.34, 0.22, 0.86, 0.86, 1.72, WALL)
    out += gable(bm, 0.34, 0.34, 0.86, 0.86, 1.72, 2.16, 0.08, ROOF, ROOF_D)
    out += box(bm, -0.16, -0.92, 0.22, 0.16, -0.84, 0.66, WOOD)
    return out


def _house(bm):
    """1x1. The ordinary one, and the one there will be many of."""
    out = []
    out += box(bm, -0.38, -0.38, 0.0, 0.38, 0.38, 0.46, WALL)
    out += gable(bm, -0.38, -0.38, 0.38, 0.38, 0.46, 0.84, 0.07, ROOF, ROOF_D)
    out += box(bm, -0.09, -0.44, 0.0, 0.09, -0.38, 0.30, WOOD)
    return out


def _tower(bm):
    """1x1. Tall and thin on purpose -- height is the one thing that reads from the game's angle, so the
    piece whose job is to see far has to be the piece that is visibly high."""
    out = []
    out += box(bm, -0.26, -0.26, 0.0, 0.26, 0.26, 1.32, STONE)
    out += box(bm, -0.34, -0.34, 1.32, 0.34, 0.34, 1.50, WOOD)
    out += gable(bm, -0.34, -0.34, 0.34, 0.34, 1.50, 1.80, 0.05, ROOF, ROOF_D)
    return out


def _store(bm):
    """1x1. Low, wide, flat-topped. It exists to be the one that is NOT pitched: a row of buildings that
    all carry the same roof is a texture, and one flat top breaks it."""
    out = []
    out += box(bm, -0.42, -0.34, 0.0, 0.42, 0.34, 0.40, WOOD)
    out += box(bm, -0.46, -0.38, 0.40, 0.46, 0.38, 0.50, ROOF_D)
    return out


def _wall(bm):
    """1x1. A low stone run. Half height, so a body standing behind it still reads."""
    out = []
    out += box(bm, -0.5, -0.16, 0.0, 0.5, 0.16, 0.42, STONE)
    out += box(bm, -0.5, -0.20, 0.42, 0.5, 0.20, 0.48, STONE)
    return out


BUILDS = [
    ("keep", _keep, 2, 2, "\ubcf8\ucc44"),
    ("house", _house, 1, 1, "\uc9d1"),
    ("tower", _tower, 1, 1, "\ub9dd\ub8e8"),
    ("store", _store, 1, 1, "\ucc3d\uace0"),
    ("wall", _wall, 1, 1, "\ub3cc\ub2f4"),
]


def build():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    # WARNING **Materials too.** `flat_mat` reuses one by name, and Blender keeps datablocks between
    # runs of this script -- so an edited colour silently kept the previous run's value and two rebuilds
    # in a row produced an identical file while the source said otherwise.
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    names = []
    for name, fn, _w, _h, _label in BUILDS:
        make(name, fn)
        names.append(name)
    export(names)
    _show(names)


def _show(names):
    """Lines the set up and renders it at the game's own camera angle.

    WARNING **At any other angle this set cannot be judged.** The game looks at the island from a fixed
    tilt, and a building that reads well from the side may be a blank rectangle from up there -- which
    is the whole reason the tower is tall and the store is flat.
    """
    for i, name in enumerate(names):
        ob = bpy.data.objects.get(name)
        if ob:
            ob.location = (i * 2.6 - (len(names) - 1) * 1.3, 0.0, 0.0)

    # A ground plate, so the buildings are seen standing on something rather than floating.
    bm = bmesh.new()
    r = len(names) * 1.6
    for f, c in box(bm, -r, -2.2, -0.06, r, 2.2, 0.0, (0.760, 0.735, 0.520)):
        f.material_index = 0
    me = bpy.data.meshes.new("plate")
    bm.to_mesh(me)
    bm.free()
    plate = bpy.data.objects.new("plate", me)
    bpy.context.collection.objects.link(plate)
    plate.data.materials.append(flat_mat("ground", (0.760, 0.735, 0.520)))

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(35.0))
    bpy.context.collection.objects.link(sun)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = r * 2.3
    cam = bpy.data.objects.new("cam", cam_data)
    # The game's own tilt: a top-down view leaned back 40 degrees.
    cam.location = (0.0, -9.0, 7.6)
    cam.rotation_euler = (math.radians(50.0), 0.0, 0.0)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1400
    sc.render.resolution_y = 460
    sc.render.filepath = OUT_DIR + "/buildings_look.png"
    # WARNING **View transform Standard, never the default AgX.** AgX washes saturation out to look
    # photographic, and in flat-shaded game art the colour IS the information -- a whole round was lost
    # once to a render that had the colours right and showed none of them.
    sc.view_settings.view_transform = "Standard"
    bpy.ops.render.render(write_still=True)
    print("rendered " + sc.render.filepath)


def export(names):
    import json
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/buildings.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    table = [{"kind": k, "w": w, "h": hh, "label": lb} for k, _f, w, hh, lb in BUILDS]
    with open(OUT_DIR + "/buildings.json", "w", encoding="utf-8") as fh:
        json.dump({"builds": table}, fh, ensure_ascii=False, indent=1)
    print("exported %d buildings" % len(table))


build()
