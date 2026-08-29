# **EVERY BLOCK THE ISLAND IS MADE OF, PULLED APART SO EACH ONE CAN BE SEEN ALONE.**
# A development view and nothing the player ever sees: it answers "what blocks do I actually have",
# which the finished island cannot, because `island_build.py` welds all of them into one mesh.
#
# WARNING **THIS DOES NOT RE-IMPLEMENT THE BUILD.** It runs `island_build.py` itself and intercepts the
# one line where the blocks stop existing separately (`bpy.ops.object.join()`), copying every part a
# moment before. A second copy of the layout loop would drift from the real one the first time a rule
# changed, and the whole point of this view is that it shows what the island is REALLY made of.
#
# Run:  python tools/blender/send.py tools/blender/blocks_explode.py
import bpy
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else \
    r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender"
SRC = os.path.join(HERE, "island_build.py")

GAP = 1.5          # how far the blocks are pushed apart, as a multiple of their own spacing
S_GAP = 3.2        # spacing of the kit row, in metres
saved = []


def _snapshot():
    """Called from inside the build, on the selection that is about to be joined."""
    for o in list(bpy.context.selected_objects):
        d = o.copy()
        d.data = o.data.copy()
        d.name = "EX_" + o.name
        bpy.context.collection.objects.link(d)
        # WARNING **A COPY ARRIVES SELECTED AND THE JOIN THAT FOLLOWS EATS IT.** Every copy went into
        # the island and the list left behind held nineteen dead handles -- "StructRNA of type Object
        # has been removed", which names no cause.
        d.select_set(False)
        saved.append(d)


for o in list(bpy.data.objects):
    if o.name.startswith("EX_"):
        bpy.data.objects.remove(o, do_unlink=True)

src = open(SRC, encoding="utf-8").read()
NEEDLE = "    bpy.ops.object.join()"
assert src.count(NEEDLE) == 1, "the join line moved -- this script is measuring nothing"
src = src.replace(NEEDLE, "    _SNAPSHOT()\n" + NEEDLE)
exec(compile(src, SRC, "exec"), {"__name__": "island_build_exploded", "_SNAPSHOT": _snapshot})

# WARNING **THE KIT PARTS GO IN A ROW OF THEIR OWN, IN FRONT OF THE ISLAND** (2026-08-29). The build
# now leaves one hidden `KIT_` mesh per kind of block; those are the parts, and the spread-out `EX_`
# copies are the island made of them.
for o in list(bpy.data.objects):
    if o.name.startswith("LBL_"):
        bpy.data.objects.remove(o, do_unlink=True)
kitrow = sorted([o for o in bpy.data.objects if o.name.startswith("KIT_")], key=lambda x: x.name)
# ⚠ **A part with no name on it is unreadable** (2026-08-29, the user: 「이렇게 만 봐서는 뭐가 뭔지
# 모르겠네?」). Each one gets its kind written in front of it, level first.
for i, o in enumerate(kitrow):
    o.hide_set(False)
    o.location = ((i % 5) * S_GAP, -(i // 5) * S_GAP, 0.0)
    o.rotation_euler = (0.0, 0.0, 0.0)
    bits = o.name.split("_")
    cu = bpy.data.curves.new("lbl", type="FONT")
    cu.body = "%s층 %s" % ("1" if bits[1] == "0" else "2", bits[2])
    cu.size = 0.42
    lb = bpy.data.objects.new("LBL_" + o.name, cu)
    bpy.context.collection.objects.link(lb)
    lb.location = (o.location.x - 0.1, o.location.y - 0.75, 0.02)
    lb.rotation_euler = (0.0, 0.0, 0.0)

# The blocks stand where they stood on the island; multiplying the spacing opens a gap between every
# pair without moving any of them relative to the others.
#
# WARNING **A BLOCK CARRIES NO MATERIAL UNTIL AFTER THE JOIN**, so a copy taken a moment earlier comes
# out plain white and the tone that says grass from rock is invisible. The finishing the island gets
# after the join -- one vertex-colour material, smoothing by angle, the bevel -- is given to each copy
# here, so what is on screen is the block as the island wears it.
mat = bpy.data.materials.get("island_ground")
# ⚠ **The kit parts leave the build bare.** Material, smoothing and bevel are all put on after the
# join, so a part taken out before that is untextured white and reads as solid rock.
for o in kitrow + saved:
    if mat:
        o.data.materials.clear()
        o.data.materials.append(mat)

xs, ys = [], []
for o in saved:
    o.location = (o.location.x * GAP, o.location.y * GAP, o.location.z)
    xs.append(o.location.x)
    ys.append(o.location.y)
    for pl in o.data.polygons:
        pl.use_smooth = False
    b = o.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = 0.18, 3
    b.limit_method, b.angle_limit = "ANGLE", math.radians(24.0)

for o in kitrow:
    for pl in o.data.polygons:
        pl.use_smooth = False
    b = o.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = 0.18, 3
    b.limit_method, b.angle_limit = "ANGLE", math.radians(24.0)

for o in bpy.data.objects:
    o.select_set(o in saved or o in kitrow)
if saved:
    bpy.context.view_layer.objects.active = saved[0]
    bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))
for o in bpy.data.objects:
    o.select_set(False)
cx, cy = (min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0

for name in ("island", "pads"):
    if name in bpy.data.objects:
        bpy.data.objects[name].hide_set(True)

# WARNING **EVERY WINDOW, NOT `bpy.context.screen`.** Code arriving over the add-on's socket does not
# always run against the screen the user is looking at, and setting the shading on the wrong one leaves
# the picture flat white with no error anywhere.
for win in bpy.context.window_manager.windows:
    for area in win.screen.areas:
        if area.type != "VIEW_3D":
            continue
        sp = area.spaces[0]
        r3d = sp.region_3d
        r3d.view_perspective = "PERSP"
        r3d.view_location = (cx, cy, 0.0)
        r3d.view_rotation = __import__("mathutils").Euler(
            (math.radians(62.0), 0.0, math.radians(-18.0)), "XYZ").to_quaternion()
        r3d.view_distance = 42.0
        sp.shading.type = "MATERIAL"
        sp.overlay.show_floor = False
        sp.overlay.show_axis_x = False
        sp.overlay.show_axis_y = False

print("exploded %d blocks: %s" % (len(saved), " ".join(sorted(o.name for o in saved))))
