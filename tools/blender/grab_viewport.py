# Saves what the Blender VIEWPORT is showing to a PNG.
#
# An OpenGL render, not a full render: it draws exactly the shading the user is looking at, which is
# the point — the viewport is the output while a piece is being judged.
import bpy

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/viewport.png"

sc = bpy.context.scene
sc.render.filepath = OUT
sc.render.resolution_x = 1000
sc.render.resolution_y = 700
for area in bpy.context.screen.areas:
    if area.type != 'VIEW_3D':
        continue
    for region in area.regions:
        if region.type == 'WINDOW':
            with bpy.context.temp_override(area=area, region=region):
                bpy.ops.render.opengl(write_still=True)
            break
    break
print("saved", OUT)
