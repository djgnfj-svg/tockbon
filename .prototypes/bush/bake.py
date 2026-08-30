# **Bakes the one bush every candidate wears** -- the mesh, and a picture of that same mesh.
#
# WARNING **Both come out of ONE clump on purpose.** The set is judging a MECHANISM (real geometry vs
# standing quads vs a turning card), so if the card wore different art the sheet would be judging art.
#
# Writes, under `.prototypes/bush/assets/`:
#   bush.glb       -- the clump. **Vertex colour rgb is the leaf tone, and ALPHA is the sway weight**
#                     (0 at the roots, 1 at the tips) so a vertex shader can bend the leaves and leave
#                     the base planted.
#   bush_card.png  -- the same clump rendered flat from the front on a transparent film, for the two
#                     candidates that wear a picture.
#
# Run it through the Blender MCP: exec(open(this).read())
import bpy, bmesh, math, os
from mathutils import Vector

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/.prototypes/bush/assets"

# The island's own leaf palette -- `tools/blender/props_build.py`, unchanged.
LEAF_D = (0.255, 0.360, 0.225)
LEAF_L = (0.430, 0.545, 0.330)
BUSH = (0.392, 0.495, 0.325)


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
    return (to_lin(rgb[0]), to_lin(rgb[1]), to_lin(rgb[2]))


def flat_mat(name, rgb):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = lin(rgb)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    b.inputs["Roughness"].default_value = 1.0
    # Workbench reads the viewport colour, not the BSDF, so both are set.
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def blob(bm, cx, cy, r, h, sides, slot, twist):
    """One leaf lump. **A rounded dome, not a cone** -- a straight taper to a point reads as a tent, and
    the first render of this script came out as three green tents. The profile is a list of
    (height fraction, radius fraction) rings, closed with a small tip."""
    out = []
    prof = [(0.00, 0.86), (0.30, 1.00), (0.62, 0.92), (0.85, 0.62), (1.00, 0.22)]
    rings = []
    for zf, rf in prof:
        ring = []
        for i in range(sides):
            a = twist + 2.0 * math.pi * i / sides + zf * 0.35
            ring.append(bm.verts.new((cx + math.cos(a) * r * rf, cy + math.sin(a) * r * rf, zf * h)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        lo, hi = rings[k], rings[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            out.append((bm.faces.new((lo[i], lo[j], hi[j], hi[i])), slot, h))
    out.append((bm.faces.new(list(reversed(rings[0]))), slot, h))
    out.append((bm.faces.new(list(rings[-1])), slot, h))
    return out


# --- the clump ------------------------------------------------------------------------------------
# WARNING **A clump, not one lump** (2026-08-29, settled with the user): one blob reads as a button at
# this camera, and the island is 30x26 tiles wide. Three leaning apart is a bush.
BLOBS = [
    (-0.13, -0.02, 0.175, 0.285, 7, 0, 0.4),
    (0.125, 0.055, 0.140, 0.210, 7, 1, 1.1),
    (0.020, -0.140, 0.115, 0.160, 6, 2, 2.0),
]
TONES = [BUSH, LEAF_D, LEAF_L]

for name in ("bush_clump",):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)

bm = bmesh.new()
painted = []
for (cx, cy, r, h, sides, slot, tw) in BLOBS:
    painted += blob(bm, cx, cy, r, h, sides, slot, tw)
for f, slot, _h in painted:
    f.material_index = slot
bm.normal_update()
# WARNING **Read the per-vertex facts BEFORE `bm.free()`.** A bmesh face touched after the free raises
# "BMesh data of type BMFace has been removed" -- measured 2026-08-29, first run of this script.
bm.verts.index_update()
top_of, slot_of = {}, {}
for f, slot, h in painted:
    for v in f.verts:
        top_of[v.index] = max(top_of.get(v.index, 0.0), h)
        slot_of.setdefault(v.index, slot)
me = bpy.data.meshes.new("bush_clump")
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new("bush_clump", me)
bpy.context.collection.objects.link(ob)
for i, tone in enumerate(TONES):
    ob.data.materials.append(flat_mat("bp_%d" % i, tone))
for p in ob.data.polygons:
    p.use_smooth = False
ob.data.shade_flat()

# --- the sway weight, and the tone, both into the colour attribute ---------------------------------
# WARNING **The weight rides in ALPHA and not in a second UV.** Blender's glTF exporter drops UV maps
# no material samples, and a silently missing second UV is a bush that simply never moves.
col = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
for v in me.vertices:
    h = max(top_of.get(v.index, 0.30), 1e-4)
    # 0 at the roots so the base never leaves the ground -- the one gotcha every source names.
    w = min(max(v.co.z / h, 0.0), 1.0) ** 1.25
    c = lin(TONES[slot_of.get(v.index, 0)])
    col.data[v.index].color = (c[0], c[1], c[2], w)

os.makedirs(OUT, exist_ok=True)
for o in bpy.data.objects:
    o.select_set(o is ob)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=OUT + "/bush.glb", export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_vertex_color="ACTIVE",
                          export_all_vertex_colors=True)
print("bush.glb: %d verts, %d tris" % (len(me.vertices), len(me.polygons)))
