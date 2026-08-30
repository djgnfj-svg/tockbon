# **The three boats side by side, and the new one from two more angles.**
# Writes into `tools/shot/out/boat/`, which carries a `.gdignore` so the engine never imports these
# and `tools/*` keeps them out of both export presets — a picture a ticket points at is not an asset.
#
# WARNING **THE VIEW TRANSFORM IS `Standard`.** Blender's default AgX washes the saturation out, and
# on flat-shaded art the colour IS the information: ticket 01 records a render the user judged as
# 「표시했어? 전혀 안 보이네」 whose colours were already correctly separated underneath.
#
# WARNING **THIS IS BLENDER'S LIGHT, NOT THE GAME'S, AND THE TWO DISAGREE.** Ticket 01 has six rounds
# of a value that was right here and dead on screen. The sun angles below are copied from `look.gd` so
# the shapes fall the same way, but the intensities are Blender's own units and no colour judgement
# taken from these images is safe. **The window that does not lie is `piece_viewer`.**
#
# Run:  python tools/blender/send.py tools/blender/boat_shot.py
import bpy
import math
import os

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/shot/out/boat"
NEW = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props/boat.glb"
SMALL = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/props/boat_small.glb"
OLD = (r"C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/"
       r"6c100c72-0122-4075-bcfc-a712263eba03/scratchpad/boat_old.glb")

# Copied from `look.gd`. ⚠ **`MAP_TILT_DEG` is the CAMERA's pitch** — 40 degrees down from level, not
# from straight down, so a Blender camera looking along -Y is rotated 90 - 40.
CAM_PITCH_DEG = 40.0
SUN_PITCH_DEG = -52.0
SUN_YAW_DEG = -35.0
AMBIENT = (0.620, 0.680, 0.790)

# Far from anything else in the file, so the shot never has to delete another agent's scene.
STAGE_Y = -60.0
# (name, file, x). ⚠ The order is new, old, small and the report says so — nothing in the picture
# labels them.
BOATS = [("new", NEW, -6.2), ("old", OLD, 0.0), ("small", SMALL, 6.0)]


def clear(prefix):
    for ob in list(bpy.data.objects):
        if ob.name.startswith(prefix):
            bpy.data.objects.remove(ob, do_unlink=True)


def bring_in(path, tag, x):
    """Import one glTF and park the whole thing under one empty at (x, STAGE_Y)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    fresh = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("shot_" + tag, None)
    bpy.context.collection.objects.link(root)
    root.location = (x, STAGE_Y, 0.0)
    for o in fresh:
        if o.parent is None:
            o.parent = root
        o.name = "shot_%s_%s" % (tag, o.name)
    return root


def stage():
    clear("shot_")
    for tag, path, x in BOATS:
        bring_in(path, tag, x)

    sun = bpy.data.objects.get("shot_sun")
    if sun is None:
        lamp = bpy.data.lights.new("shot_sun", "SUN")
        sun = bpy.data.objects.new("shot_sun", lamp)
        bpy.context.collection.objects.link(sun)
    sun.data.energy = 3.2
    sun.data.angle = math.radians(2.0)
    sun.rotation_euler = (math.radians(90.0 + SUN_PITCH_DEG), 0.0, math.radians(SUN_YAW_DEG))
    sun.location = (0.0, STAGE_Y, 12.0)

    w = bpy.context.scene.world
    if w is None:
        w = bpy.data.worlds.new("shot_world")
        bpy.context.scene.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (AMBIENT[0], AMBIENT[1], AMBIENT[2], 1.0)
    bg.inputs[1].default_value = 0.9

    cam = bpy.data.objects.get("shot_cam")
    if cam is None:
        cd = bpy.data.cameras.new("shot_cam")
        cam = bpy.data.objects.new("shot_cam", cd)
        bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    return cam


def aim(cam, pitch_deg, yaw_deg, target, dist, ortho):
    """Point an orthographic camera at `target` from `pitch` above and `yaw` around."""
    p = math.radians(pitch_deg)
    y = math.radians(yaw_deg)
    cam.rotation_euler = (math.radians(90.0 - pitch_deg), 0.0, y)
    cam.location = (target[0] + math.sin(y) * math.cos(p) * dist,
                    target[1] - math.cos(y) * math.cos(p) * dist,
                    target[2] + math.sin(p) * dist)
    cam.data.ortho_scale = ortho


def shoot(cam, name, pitch, yaw, target, ortho, w, h):
    aim(cam, pitch, yaw, target, 40.0, ortho)
    sc = bpy.context.scene
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.filepath = OUT + "/" + name + ".png"
    bpy.ops.render.render(write_still=True)
    print("wrote " + sc.render.filepath)


def run():
    os.makedirs(OUT, exist_ok=True)
    hidden = [o for o in bpy.data.objects
              if not o.name.startswith("shot_") and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    try:
        cam = stage()
        for o in bpy.data.objects:
            if o.name.startswith("shot_"):
                o.hide_render = False
        mid = (0.0, STAGE_Y, 0.6)
        # ⚠ The three at ONE scale and one framing — the whole point is a comparison, and a boat shot
        # to fill its own frame proves nothing about how it reads beside the others.
        shoot(cam, "three_at_game_angle", CAM_PITCH_DEG, 0.0, mid, 18.0, 1800, 700)
        shoot(cam, "three_top_down", 89.9, 0.0, mid, 18.0, 1800, 700)
        shoot(cam, "three_low_angle", 12.0, 0.0, mid, 18.0, 1800, 620)
        one = (-6.2, STAGE_Y, 0.6)
        shoot(cam, "new_at_game_angle", CAM_PITCH_DEG, 0.0, one, 6.4, 1200, 800)
        shoot(cam, "new_game_angle_bow_on", CAM_PITCH_DEG, 52.0, one, 6.4, 1200, 800)
        shoot(cam, "new_top_down", 89.9, 0.0, one, 6.4, 1200, 800)
        shoot(cam, "new_low_angle", 12.0, 0.0, one, 6.4, 1200, 700)
    finally:
        for o in hidden:
            o.hide_render = False


run()
