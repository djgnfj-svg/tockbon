# Builds ONE shore piece in Blender and renders it beside water.
#
# ⚠⚠ **Read `docs/plan/tickets/01-what-one-piece-is.md` before changing anything here.**
# Six pieces were made and six were rejected, always for the same reason.
#
# What this piece obeys, and where each rule came from:
#   · **2x2 tiles, not 1x1** — the user: 「거기는 칸을 넘나드는 조형물인 거고」, and the Bad North talk
#     calls a piece spanning several cells THE device that breaks the grid up.
#   · **One tile is 1 metre** — the game's world unit is one tile, so nothing has to be rescaled.
#   · **The top is flat** — it is the ground a body stands on, and the talk says the island only has to
#     say *where can I walk*.
#   · **Corners are NOT 45°** — the talk names this: a 45° chamfer stacks into something either spiky
#     or blunt, and a slight tilt breaks the repeat without props.
#   · **Detail sits where faces MEET** — the bevel and the shore break are the only detail; the flat
#     faces are left alone on purpose.
#   · **The side is a SHORE** — it widens as it goes down and wades into the water instead of being cut
#     off. The user: 「해안선답게 바닥에 붙어있고 그 옆에 물이 이렇게 잔잔하게 흐르는 게 좀 보여야」.
import bmesh
import bpy
import math

TILE = 1.0          # one game tile = one metre
SPAN = 2            # the piece covers SPAN x SPAN tiles
TOP_H = 0.62        # how high the walkable top stands above the water line
FOOT_OUT = 0.30     # how far the foot of the shore pushes out past the top, per side
FOOT_DOWN = 0.55    # how far the foot sits below the water line
BEVEL = 0.035       # detail lives on the edges; this is that detail. ⚠ **Small on purpose** — at
                    # 0.075 the piece rendered as a bar of soap: the bevel ate the edges it was
                    # supposed to draw, and rock stopped being rock.
MID_OUT = 0.10      # the shore breaks ONCE on the way down. A single straight side is a wall; a break
                    # is where the eye reads rock.
MID_AT = 0.45       # how far down the break sits, 0 = top, 1 = foot
SEED_A = 1.7        # deterministic wobble — NO RNG, so a piece can be re-made identically
SEED_B = 2.3
WOBBLE = 0.045      # how far the WALKABLE outline wanders. Small — the top is ground, not rock.
SIDE_WOBBLE = 0.16  # ⚠⚠ **How far the SHORE wanders, and it is four times the top's.** At the same
                    # value as the top the piece rendered as a bar of soap twice: a rock reads as rock
                    # because its silhouette is uneven, and evenness is exactly what a bevel adds.


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def wobble(x, y, k):
    return math.sin(x * SEED_A + k) * math.cos(y * SEED_B - k) * WOBBLE


def shore_piece():
    half = SPAN * TILE * 0.5
    bm = bmesh.new()

    # The two rings the piece is built from: the walkable top, and the foot wading into the water.
    # ⚠ The foot is WIDER than the top — that is what makes the side a shore instead of a wall.
    top = []
    mid = []
    foot = []
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    steps = 6          # points along each edge, so the outline is not four straight lines
    for i in range(4):
        ax, ay = corners[i]
        bx, by = corners[(i + 1) % 4]
        for s in range(steps):
            t = s / steps
            cx = (ax + (bx - ax) * t) * half
            cy = (ay + (by - ay) * t) * half
            # A slight tilt on the outline, never a clean 45° corner.
            tx = cx + wobble(cx, cy, 0.0)
            ty = cy + wobble(cy, cx, 1.3)
            tz = TOP_H + wobble(cx, cy, 2.1) * 0.4
            top.append(bm.verts.new((tx, ty, tz)))
            n = math.hypot(cx, cy) or 1.0
            k = SIDE_WOBBLE / WOBBLE
            mz = tz - (tz + FOOT_DOWN) * MID_AT + wobble(cx, cy, 7.4) * k * 0.5
            mid.append(bm.verts.new((cx + cx / n * MID_OUT + wobble(cx, cy, 6.1) * k,
                                     cy + cy / n * MID_OUT + wobble(cy, cx, 6.9) * k, mz)))
            fx = cx + cx / n * FOOT_OUT + wobble(cx, cy, 3.7) * k
            fy = cy + cy / n * FOOT_OUT + wobble(cy, cx, 4.2) * k
            foot.append(bm.verts.new((fx, fy, -FOOT_DOWN + wobble(cx, cy, 5.5) * k * 0.4)))

    bm.faces.new(top)                       # the flat walkable cap
    n = len(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[j], top[i], mid[i], mid[j]))
        bm.faces.new((mid[j], mid[i], foot[i], foot[j]))
    bm.faces.new(list(reversed(foot)))      # close the bottom so the solid is watertight

    bm.normal_update()
    me = bpy.data.meshes.new("shore_2x2")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("shore_2x2", me)
    bpy.context.collection.objects.link(ob)

    # ⚠ **The bevel is the detail.** Everything else is left flat, because the talk says a rock texture
    # only repeats the word "rock" while an edge tells you where you may walk.
    mod = ob.modifiers.new("bevel", 'BEVEL')
    mod.width = BEVEL
    mod.segments = 2
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(25.0)
    ob.data.polygons.foreach_set("use_smooth", [False] * len(ob.data.polygons))
    return ob


def material(name, rgb, rough=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    # ⚠ **Found by name, not by index or label.** Blender 5.1 does not call the node "Principled BSDF"
    # any more, and a hard-coded key raises `KeyError` with a traceback that says nothing about why.
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is not None:
        b.inputs["Base Color"].default_value = (*rgb, 1.0)
        b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1.0)
    return m


def build():
    clear()
    piece = shore_piece()
    # The game's own ground and rock tones, so the piece is judged against the game and not a new palette.
    grass = material("grass", (0.235, 0.373, 0.196))
    rock = material("rock", (0.396, 0.341, 0.286))
    piece.data.materials.append(grass)
    piece.data.materials.append(rock)
    # Face 0 is the cap; everything else is the shore. Assigned by NORMAL, not by index, so the split
    # survives the bevel adding faces.
    for p in piece.data.polygons:
        p.material_index = 0 if p.normal.z > 0.7 else 1

    sea = bpy.data.meshes.new("sea")
    bmsea = bmesh.new()
    # ⚠ **Subdivided and nudged, so the water is not one flat mirror.** A single quad takes one shading
    # value across the whole frame and reads as a painted backdrop; a lightly rumpled surface catches
    # the sun differently across it, which is what 「물이 잔잔하게 흐르는 게 보여야」 asks for.
    bmesh.ops.create_grid(bmsea, x_segments=40, y_segments=40, size=14.0)
    for v in bmsea.verts:
        v.co.z = (math.sin(v.co.x * 2.1) * math.cos(v.co.y * 1.7)
                  + math.sin((v.co.x + v.co.y) * 3.3) * 0.5) * 0.012
    bmsea.to_mesh(sea)
    bmsea.free()
    sea_ob = bpy.data.objects.new("sea", sea)
    bpy.context.collection.objects.link(sea_ob)
        # Lighter than the backdrop on purpose: at the same tone the sea and the sky behind it merged and
    # the piece looked like it was floating in mid-air.
    sea_ob.data.materials.append(material("water", (0.128, 0.212, 0.353), 0.18))

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-35.0))
    bpy.context.collection.objects.link(sun)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 5.4   # ⚠ Wide enough that the water around the piece is IN the frame.
    cam = bpy.data.objects.new("cam", cam_data)
    # The game's own camera pitch (40° above the horizon), so what is judged here is what is seen there.
    pitch = math.radians(40.0)
    dist = 12.0
    cam.location = (0.0, -math.cos(pitch) * dist, math.sin(pitch) * dist)
    cam.rotation_euler = (math.radians(90.0) - pitch, 0.0, 0.0)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    # ⚠ In Blender 5.1 the enum is back to 'BLENDER_EEVEE' — 'BLENDER_EEVEE_NEXT' was a 4.2-only name.
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = 900
    sc.render.resolution_y = 600
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bgn = next((n for n in sc.world.node_tree.nodes if n.type == 'BACKGROUND'), None)
    if bgn is not None:
        bgn.inputs[0].default_value = (0.086, 0.145, 0.255, 1.0)
    sc.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("rendered", OUT, "faces", len(piece.data.polygons))


OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/shore_piece.png"
build()
