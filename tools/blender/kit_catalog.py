# **THE WHOLE KIT: six kinds of block, on both levels, whether this island uses them or not.**
#
# The island builds only the parts it needs. This lays out all twelve so they can be looked at side by
# side -- 2026-08-29, the user: 「12벌 다 만들어서 보여달라고 했음」.
#
# Run:  python tools/blender/send.py tools/blender/kit_catalog.py
import bpy
import math
import os

HERE = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender"
SRC = os.path.join(HERE, "island_build.py")
GAP = 3.6
ROW = 5.4          # rows further apart than columns: a 2F part is a metre tall and hides what is behind it

for o in list(bpy.data.objects):
    if o.name.startswith(("CAT_", "CLBL_", "EX_", "KIT_", "PROTO_", "LBL_")):
        bpy.data.objects.remove(o, do_unlink=True)
for n in ("island", "pads", "Cube", "keep", "house", "tower", "store", "wall"):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_set(True)

src = open(SRC, encoding="utf-8").read().replace("\nbuild()\n", "\n")
ns = {"__name__": "island_catalog"}
exec(compile(src, SRC, "exec"), ns)

block, KIT, kit_corner_out = ns["block"], ns["KIT"], ns["kit_corner_out"]
TOP_H, LEVEL_H, GRASS_LIP = ns["TOP_H"], ns["LEVEL_H"], ns["GRASS_LIP"]
vertex_mat = ns["vertex_mat"]

mat = vertex_mat("island_ground")
made = []
for row, L in enumerate((0, 2)):
    for col, (name, canon) in enumerate(KIT):
        cs = canon if L == 0 else ""
        cl = "" if L == 0 else canon
        # ⚠ **No diagonal variants here.** The catalogue is the six shapes; the island makes its own
        # variants of them where the sea cuts in on a diagonal.
        c_out = [kit_corner_out(set(canon), i) if L == 0 else None for i in range(4)]
        gh = GRASS_LIP if L > 0 else 0.0
        ob, _ = block("CAT_%d_%s" % (L, name), TOP_H + L * LEVEL_H - gh,
                      cs, cl, c_out, 0.0, 0.0, gh)
        ob.location = (col * GAP, -row * ROW, 0.0)
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for pl in ob.data.polygons:
            pl.use_smooth = False
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width, b.segments = 0.18, 3
        b.limit_method, b.angle_limit = "ANGLE", math.radians(24.0)
        made.append(ob)

        cu = bpy.data.curves.new("lbl", type="FONT")
        cu.body = "%s %s" % ("1F" if L == 0 else "2F", name)
        cu.size = 0.40
        lb = bpy.data.objects.new("CLBL_%d_%s" % (L, name), cu)
        bpy.context.collection.objects.link(lb)
        lb.location = (col * GAP - 0.1, -row * ROW - 0.95, 0.02)

for o in bpy.data.objects:
    o.select_set(o in made)
bpy.context.view_layer.objects.active = made[0]
bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))
for o in bpy.data.objects:
    o.select_set(False)

cx = (len(KIT) - 1) * GAP * 0.5
cy = -ROW * 0.5
for win in bpy.context.window_manager.windows:
    for area in win.screen.areas:
        if area.type != "VIEW_3D":
            continue
        sp = area.spaces[0]
        r3d = sp.region_3d
        r3d.view_perspective = "PERSP"
        r3d.view_location = (cx, cy, 0.2)
        r3d.view_rotation = __import__("mathutils").Euler(
            (math.radians(42.0), 0.0, 0.0), "XYZ").to_quaternion()
        r3d.view_distance = 30.0
        sp.shading.type = "MATERIAL"
        sp.overlay.show_floor = False
        sp.overlay.show_extras = False
        sp.overlay.show_cursor = False

print("catalogue: %d parts" % len(made))
