# **ONE BLOCK, TWICE: with a turf layer and without.** Nothing here touches the island the game reads.
#
# The ask (2026-08-29): 「초록색 부분만 약간 위로 쏫아오르는거임」 -- the green top should be a LAYER
# with thickness sitting on the rock, so that from the side there is a green band above the white.
# ⚠ **Two earlier answers to it were built and rejected** (a painted band, and a plate with the cliff
# stepped back under it); this one changes nothing about the cliff, only where the colour breaks.
#
# Run:  python tools/blender/send.py tools/blender/proto_grass_lip.py
import bpy
import math
import os

HERE = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender"
SRC = os.path.join(HERE, "island_build.py")

# WARNING **THE WALL IS UNCHANGED AND A PLATE RIDES ON TOP OF IT** (2026-08-29, the user: 「벽면이
# 같고 올라가는게 맞는데 그 상태에서 초록색 부분만 살짝 위로떠서 두깨감이 보인다 ... 45도 쯤에서
# 봤을떄」). ⚠⚠ **THIS WAS BUILT ONCE AND READ AS "no change"** because the plate was 0.06 and the
# bevel was 0.05 -- the roll ate almost all of it and there was nothing left to see. **The plate has to
# be several times the bevel or the whole idea is invisible.**
# ⚠ **Moving the colour break DOWN instead is the other thing that was tried and rejected**: that
# shortens the cliff, and the ask is that the cliff stay exactly as it is.
GRASS = [0.0, 0.07, 0.12]           # plate thickness, in tiles, left to right
BEVEL = 0.03        # WARNING **must stay well under the smallest band** or the roll eats it

for o in list(bpy.data.objects):
    if o.name.startswith(("PROTO_", "EX_")):
        bpy.data.objects.remove(o, do_unlink=True)
for n in ("island", "pads", "Cube", "keep", "house", "tower", "store", "wall"):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_set(True)

src = open(SRC, encoding="utf-8").read()
src = src.replace("\nbuild()\n", "\n")
ns = {"__name__": "island_proto"}
exec(compile(src, SRC, "exec"), ns)

block, TOP_H, LEVEL_H = ns["block"], ns["TOP_H"], ns["LEVEL_H"]
vertex_mat, S = ns["vertex_mat"], ns["S"]
z_top = TOP_H + 2.0 * LEVEL_H          # a second storey: two notches up

mat = vertex_mat("island_ground")
made = []
for i, gh in enumerate(GRASS):
    ob, _ = block("PROTO_%d" % i, z_top, "", "senw", [None] * 4, 0.0, 0.0, gh)
    ob.location = (i * S * 1.6, 0.0, 0.0)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    for pl in ob.data.polygons:
        pl.use_smooth = False
    b = ob.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = BEVEL, 3
    b.limit_method, b.angle_limit = "ANGLE", math.radians(24.0)
    made.append(ob)

for o in bpy.data.objects:
    o.select_set(o in made)
bpy.context.view_layer.objects.active = made[0]
bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))
for o in bpy.data.objects:
    o.select_set(False)

cx = (made[0].location.x + made[-1].location.x) * 0.5 + S * 0.5
for win in bpy.context.window_manager.windows:
    for area in win.screen.areas:
        if area.type != "VIEW_3D":
            continue
        sp = area.spaces[0]
        r3d = sp.region_3d
        r3d.view_perspective = "PERSP"
        r3d.view_location = (cx, S * 0.5, z_top * 0.5)
        r3d.view_rotation = __import__("mathutils").Euler(
            (math.radians(45.0), 0.0, math.radians(-20.0)), "XYZ").to_quaternion()
        r3d.view_distance = 13.0
        sp.shading.type = "MATERIAL"
        sp.overlay.show_floor = False
        sp.overlay.show_extras = False
        sp.overlay.show_cursor = False

print("turf bands, left to right: %s" % GRASS)
