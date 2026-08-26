# Photographs whatever is in the Blender scene from SIX angles.
#
# ⚠⚠ **One angle hides what is wrong.** A piece judged square-on from the game's own pitch looked fine
# three rounds running and still read as wrong on the user's screen — the user asked for this
# directly: 「카메라를 회전하면서 네가 여러 면평을 찍어 줄래?」
#
# Four yaws at the game's pitch, plus one low raking angle and one from nearly overhead: the raking
# one is where thickness shows, the overhead one is where the outline and the coast band show.
import bpy
import math
import mathutils

BASE = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/turn_%s.png"

# (name, pitch above the horizon, yaw)
SHOTS = [
    ("1_front", 40.0, 180.0),
    ("2_right", 40.0, 270.0),
    ("3_back", 40.0, 0.0),
    ("4_left", 40.0, 90.0),
    ("5_low", 12.0, 200.0),
    ("6_over", 78.0, 180.0),
]


def area_region():
    for area in bpy.context.screen.areas:
        if area.type != 'VIEW_3D':
            continue
        for region in area.regions:
            if region.type == 'WINDOW':
                return area, region
    return None, None


area, region = area_region()
space = next(s for s in area.spaces if s.type == 'VIEW_3D')
sc = bpy.context.scene
sc.render.resolution_x = 800
sc.render.resolution_y = 560

# ⚠ Framed on the PIECE before every shot. Without this the first framing carries over and the piece
# shrinks to a speck at the raking angles, where thickness was the whole reason for looking.
piece = bpy.data.objects.get("piece_2x2") or bpy.data.objects.get("island")

for name, pitch, yaw in SHOTS:
    space.region_3d.view_rotation = mathutils.Euler(
        (math.radians(90.0 - pitch), 0.0, math.radians(yaw)), 'XYZ').to_quaternion()
    if piece is not None:
        for o in bpy.data.objects:
            o.select_set(o is piece)
        bpy.context.view_layer.objects.active = piece
        with bpy.context.temp_override(area=area, region=region):
            bpy.ops.view3d.view_selected()
        # ⚠ A small pull-back only. At 2.0 the piece sat as a speck in the middle of the sea plane —
        # room to read a ratio, not room to lose the subject in.
        space.region_3d.view_distance *= 1.15
        for o in bpy.data.objects:
            o.select_set(False)
    sc.render.filepath = BASE % name
    with bpy.context.temp_override(area=area, region=region):
        bpy.ops.render.opengl(write_still=True)
    print("shot", name)
