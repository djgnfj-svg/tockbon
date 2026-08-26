# Builds **the ten pieces the island is assembled from**, exports them, and renders them in a row.
#
# WARNING **This is the change of method the user asked for** (2026-08-26, on being told the map is drawn
# by code: "바꾸고 열 개로 시작하는 게 맞고"). `island_build.py` used to CALCULATE the whole island every
# run -- every coastal corner, every wall lean, every colour ramp a formula -- and breaking a pattern
# meant stacking another formula on top, which went wrong three times in one afternoon: a wall of
# pancakes, a blue slit down every corner, a green smudge in a brown tray. The Bad North talk starts
# from the other end: **modelled pieces, ten of them to begin with**, placed by an algorithm that owns
# none of their shape.
#
# WARNING **These are still generated, and that is not the same as the old way.** What changes is where
# the shape LIVES: a piece is a mesh in a file, so it can be opened in Blender and pushed by hand, and
# one edit changes every place it stands.
#
# **A piece is 2x2 tiles** -- ticket 01 rule 1, the same unit `PIECES` in `island_build.py` uses.
# **Only the SOUTH-facing rotation is modelled**; the assembler turns them.
#
# The ten, and why exactly these:
#   six TOPS, one for each way a 2x2 block can meet the sea -- none, one side, two beside each other,
#   two opposite, three, four -- because a top that touches the sea has its outer row of corners dropped
#   to the waterline, and that cannot be added afterwards by laying a second piece on it.
#   two WALLS, coast and cliff, laid on whichever sides need one.
#   one STAIR. one second flat top so the commonest piece is not the same mesh everywhere.
#
#   Run:  python tools/blender/send.py tools/blender/pieces.py
import bmesh
import bpy
import math

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/pieces_look.png"
GLB = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/terrain/pieces.glb"

S = 2.0             # a piece is 2x2 tiles
TOP_H = 0.26        # the walking surface, above the waterline
LEVEL_H = 0.5       # one notch -- half a tile. A storey is two of these, a stair is one.
WALL_DOWN = 0.62    # how far a coastal wall carries on below the waterline
WATERLINE = 0.02

## WARNING **THE WALL IS SPLIT SIDEWAYS, NOT DOWNWARDS.** Horizontal bands were tried on the calculated
## island and from a low angle the whole thing read as **a stack of pancakes**: every band drew a line
## right round the island at the same height. Vertical splits put the creases where the talk says detail
## belongs -- **on the edges that turn** -- and no two pieces line their creases up.
WALL_SEGS = 3
WALL_ROUGH = 0.075  # how far a vertical crease is pushed in or out
TOP_ROUGH = 0.055   # how far an INNER top corner wanders. Edge corners never move: they are the seam.

STONE = (0.615, 0.570, 0.660)


def h(a, b, k):
    return math.sin(a * 1.7 + k) * math.cos(b * 2.3 - k)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


## Which grid line each side letter is, on the 3x3 corner grid: s=y0, n=y2, w=x0, e=x2.
SIDE_ROW = {"s": ("j", 0), "n": ("j", 2), "w": ("i", 0), "e": ("i", 2)}
## The two ends of a side, wound so `wall`'s left-turn normal points OUT of the piece.
SIDE_ENDS = {
    "s": ((S, 0.0), (0.0, 0.0)),
    "w": ((0.0, 0.0), (0.0, S)),
    "n": ((0.0, S), (S, S)),
    "e": ((S, S), (S, 0.0)),
}


def top(bm, coast="", seed=0.0):
    """A walking surface, as a 3x3 grid of corners.

    WARNING **The outer row on a coastal side drops to the waterline.** The island this replaces does the
    same and the user passed it -- "지금이 맞음 바다랑 땅이 바로되는거" -- because a wall standing up out
    of the sea reads as a slab dropped on the water. A coastal edge has no neighbour, so dropping it
    tears nothing; dropping an edge another piece butts against would.

    WARNING **Only the CENTRE corner wanders.** The eight around it are the seam with the next piece and
    never move, or the island opens along every join.
    """
    n = 2
    g = {}
    for j in range(n + 1):
        for i in range(n + 1):
            x, y = S * i / n, S * j / n
            z = TOP_H
            # WARNING **A CORNER OF THE PIECE IS NEVER DROPPED.** The first version dropped the whole
            # outer row on a coastal side, corners included -- and a corner is shared with the piece
            # beside it, which may not be coastal there. The two then disagreed about that corner's
            # height and **the island came apart into floating slabs**. Only the middle of an edge moves,
            # so every seam stays at walking height and the coastline wobbles between them.
            if not ((i in (0, n)) and (j in (0, n))):
                for sd in coast:
                    ax, idx = SIDE_ROW[sd]
                    if (ax == "i" and i == idx) or (ax == "j" and j == idx):
                        z = WATERLINE
            if 0 < i < n and 0 < j < n:
                x += TOP_ROUGH * h(seed * 2.1, seed, 7.0)
                y += TOP_ROUGH * h(seed, seed * 1.7, 13.0)
            g[(i, j)] = bm.verts.new((x, y, z))
    for j in range(n):
        for i in range(n):
            bm.faces.new((g[(i, j)], g[(i + 1, j)], g[(i + 1, j + 1)], g[(i, j + 1)]))


def wall(bm, side, z_top, z_bot, seed, segs=None, dip=False):
    """One side of a piece, **split sideways into `WALL_SEGS` panels**.

    The ends sit exactly on the piece's corner so neighbours meet with no seam; only the creases between
    panels move, by an amount from this piece's seed.
    """
    (ax, ay), (bx, by) = SIDE_ENDS[side]
    nx, ny = -(by - ay), (bx - ax)
    m = max((nx * nx + ny * ny) ** 0.5, 1e-6)
    nx, ny = nx / m, ny / m
    n = WALL_SEGS if segs is None else segs
    prev = None
    for i in range(n + 1):
        t = i / float(n)
        x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        # WARNING **A coastal wall's top follows the TOP PIECE'S EDGE, and `dip` is what makes it.** The
        # top drops the middle of a coastal edge to the waterline and leaves its corners at walking
        # height; a wall whose top was flat at the waterline therefore hung a quarter of a tile BELOW the
        # ground at every corner, and the island read as a paper cutout with no side to it.
        zt = WATERLINE if (dip and 0 < i < n) else z_top
        d = 0.0 if (dip or i in (0, n)) else WALL_ROUGH * h(t * 5.1 + seed, seed * 1.3, 19.0)
        vt = bm.verts.new((x + nx * d, y + ny * d, zt))
        vb = bm.verts.new((x + nx * d, y + ny * d, z_bot))
        if prev is not None:
            # WARNING **This winding, and not the other one.** Reversed, every wall on the island faces
            # inward: from above they vanish entirely (back-face culling) and from a low angle they come
            # out black, because the renderer is lighting the side that is turned away.
            bm.faces.new((vt, prev[0], prev[1], vb))
        prev = (vt, vb)


def stair_mesh(bm, seed):
    """**Treads are DRAWN here; the walked height is ONE notch.**

    A body on this piece stands at `TOP_H + LEVEL_H`, half a tile up, whichever tread it looks like it is
    on. Bad North does the same -- what a body may walk is attached to the module and the shape lives
    inside it. Spelling the treads on the BOARD instead cost a round and a wall of pancakes.
    The stair climbs toward +y, so it is placed with its low end facing the ground it comes from.
    """
    n = 3
    for k in range(n):
        zk = TOP_H + LEVEL_H * (k + 1) / n
        y0, y1 = S * k / n, S * (k + 1) / n
        bm.faces.new([bm.verts.new((0.0, y0, zk)), bm.verts.new((S, y0, zk)),
                      bm.verts.new((S, y1, zk)), bm.verts.new((0.0, y1, zk))])
        rz = zk - LEVEL_H / n
        bm.faces.new([bm.verts.new((S, y0, zk)), bm.verts.new((0.0, y0, zk)),
                      bm.verts.new((0.0, y0, rz)), bm.verts.new((S, y0, rz))])


def make(name, kind, coast="", side="", seed=0.0):
    bm = bmesh.new()
    if kind == "top":
        top(bm, coast, seed)
    elif kind == "stair":
        stair_mesh(bm, seed)
    elif kind == "wall_coast":
        wall(bm, side, TOP_H, -WALL_DOWN, seed, segs=2, dip=True)
    elif kind == "wall_cliff":
        wall(bm, side, TOP_H, TOP_H - LEVEL_H * 2.0, seed)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


## The ten. WARNING **The names are the contract**: `island_assemble.py` looks them up by these strings.
PLAN = [
    ("top_0",       dict(kind="top", coast="",     seed=0.3)),
    ("top_0b",      dict(kind="top", coast="",     seed=2.9)),
    ("top_1",       dict(kind="top", coast="s",    seed=1.1)),
    ("top_2a",      dict(kind="top", coast="se",   seed=1.9)),
    ("top_2o",      dict(kind="top", coast="sn",   seed=2.3)),
    ("top_3",       dict(kind="top", coast="swe",  seed=3.1)),
    ("top_4",       dict(kind="top", coast="swen", seed=3.7)),
    ("wall_coast",  dict(kind="wall_coast", side="s", seed=4.3)),
    ("wall_cliff",  dict(kind="wall_cliff", side="s", seed=5.1)),
    ("stair",       dict(kind="stair",      seed=6.7)),
]


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is not None:
        b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        b.inputs["Roughness"].default_value = 1.0
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def build():
    clear()
    stone = mat("stone", STONE)
    for i, (name, kw) in enumerate(PLAN):
        ob = make(name, **kw)
        ob.location = ((i % 5) * (S + 1.2), -(i // 5) * (S + 1.6), 0.0)
        ob.data.materials.append(stone)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob.data.set_sharp_from_angle(angle=math.radians(32.0))

    for o in bpy.data.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 17.5
    cam = bpy.data.objects.new("cam", cam_data)
    # WARNING **The rotation is `90 - pitch`.** A Blender camera looks down its own -Z, so an X rotation
    # of zero is straight down. Setting the pitch directly aimed it at the horizon twice.
    pitch = math.radians(38.0)
    dist = 15.0
    cam.location = (7.4, -2.8 - math.cos(pitch) * dist, math.sin(pitch) * dist)
    cam.rotation_euler = (math.radians(90.0) - pitch, 0.0, 0.0)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("sun", 'SUN')
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(34.0), 0.0, math.radians(-38.0))
    bpy.context.collection.objects.link(sun)

    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = 1400
    sc.render.resolution_y = 700
    sc.render.filepath = OUT
    # ticket 01 rule 8: AgX washes the saturation out and every tone reads as one material.
    sc.view_settings.view_transform = 'Standard'
    if sc.world is None:
        sc.world = bpy.data.worlds.new("world")
    sc.world.use_nodes = True
    bg = next((n for n in sc.world.node_tree.nodes if n.type == 'BACKGROUND'), None)
    if bg is not None:
        bg.inputs[0].default_value = (0.30, 0.33, 0.38, 1.0)
    bpy.ops.render.render(write_still=True)
    print("pieces: %d, rendered %s" % (len(PLAN), OUT))


build()
