# **Renders the baked clump flat, from the front, onto a transparent film.**
#
# The two picture-wearing candidates put THIS on their quads, so the sheet judges the mechanism and
# not the drawing. Flat Workbench, no shadow, no cavity, no outline: the colours come out exactly the
# material colours, which are the island's own leaf palette.
#
# Frame: 0.64 tiles wide by 0.34 high, bush standing on the bottom edge -> 256 x 136 px.
import bpy, os

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/.prototypes/bush/assets"
W_TILES, H_TILES = 0.64, 0.34
PX_W = 256

ob = bpy.data.objects["bush_clump"]

cam_data = bpy.data.cameras.get("bush_cam") or bpy.data.cameras.new("bush_cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = W_TILES
cam = bpy.data.objects.get("bush_cam")
if cam is None:
    cam = bpy.data.objects.new("bush_cam", cam_data)
    bpy.context.collection.objects.link(cam)
cam.data = cam_data
cam.location = (0.0, -4.0, H_TILES * 0.5)
cam.rotation_euler = (1.5707963, 0.0, 0.0)

sc = bpy.context.scene
prev = {
    "engine": sc.render.engine, "cam": sc.camera, "film": sc.render.film_transparent,
    "x": sc.render.resolution_x, "y": sc.render.resolution_y, "pct": sc.render.resolution_percentage,
    "path": sc.render.filepath,
}
hidden = [(o, o.hide_render) for o in bpy.data.objects]
for o, _ in hidden:
    o.hide_render = o is not ob

sc.render.engine = "BLENDER_WORKBENCH"
sc.camera = cam
sc.render.film_transparent = True
sc.render.resolution_x = PX_W
sc.render.resolution_y = int(round(PX_W * H_TILES / W_TILES))
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sh = sc.display.shading
sh.light = "FLAT"
sh.color_type = "MATERIAL"
sh.show_object_outline = False
sh.show_shadows = False
sh.show_cavity = False
sh.show_specular_highlight = False

os.makedirs(OUT, exist_ok=True)
sc.render.filepath = OUT + "/bush_card.png"
bpy.ops.render.render(write_still=True)

for o, h in hidden:
    o.hide_render = h
sc.render.engine = prev["engine"]
sc.camera = prev["cam"]
sc.render.film_transparent = prev["film"]
sc.render.resolution_x, sc.render.resolution_y = prev["x"], prev["y"]
sc.render.resolution_percentage = prev["pct"]
sc.render.filepath = prev["path"]
print("bush_card.png %dx%d" % (PX_W, int(round(PX_W * H_TILES / W_TILES))))
