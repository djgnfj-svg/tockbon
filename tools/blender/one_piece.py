# Puts ONE piece in the Blender scene and nothing else, for the user to look at in the viewport.
#
# ⚠⚠ **This file is the PIECE VIEWER. `island_build.py` is the board.** Nothing here is exported and
# nothing here is what the game loads — this script exists only so a single tile can be judged up close.
# ⚠ Ticket 01 records that this purpose was re-guessed six times; that is why it is stated up here.
#
# ⚠⚠ **The user asked for one piece three times and got an island twice** (2026-08-26:
# ***"내가 큐브 하나만 보고 싶다고 했어 다시. 기억해서 큐브 하나만 보여주게 해줘"***). This file
# exists so that request has somewhere to live: it clears the scene and builds a single 2x2 piece.
#
# ⚠ **It does NOT render.** The user is watching the Blender window, so the viewport is the output —
# the shading mode is set to material preview and the view is framed on the piece.
#
# What the piece carries, and why (see `docs/plan/tickets/01-what-one-piece-is.md`):
#   · **2x2 tiles** — a piece spanning several cells is what breaks the grid, per the Bad North talk
#   · **One side is a BEACH and the opposite side is a CLIFF**, so both coasts are in one object and
#     can be compared without moving the camera
#   · **The beach walks down to the waterline** — land and sea share a line instead of stacking, which
#     is what makes room for a wave to run up it
#   · **Vertex colours, not per-face materials** — a per-face colour puts every boundary on a tile edge
#   · **Corners are not 45°**
import bmesh
import bpy
import math

TILE = 1.0
SPAN = 2
TOP_H = 0.040       # the walking surface. ⚠⚠ **THIN, and this is the number that decides the whole
                    # impression.** A 2x2 piece is 2 metres across; at 0.24 thick it read as a table,
                    # at 0.11 it reads as land barely out of the water — which is what the reference
                    # picture is. The user: 「두께부터 얇아야함」.
WATERLINE = 0.02
BEACH_OUT = 0.42    # how far the beach wades out. ⚠ **Short.** At 1.15 the beach reached half a tile
                    # past its own piece and the shallow band traced THAT, so the band came out as a
                    # lagoon. In the reference the land meets the water almost at its own edge.
BEACH_DOWN = 0.045
CLIFF_OUT = 0.10    # how little the cliff pushes out
CLIFF_DOWN = 0.11
## ⚠⚠ **FLAT, and that is what kills the grid** (2026-08-26, the user: ***"지금 격자들이 좀 티가
## 나던데?"***). The walking surface used to wobble by `sin(x)·cos(y)` at a frequency near one cycle
## per tile, so every tile got its own little dome and the grid drew itself in shading even after the
## geometry stopped drawing it. **The reference the user gave is a flat, softly lit plate** — the
## interest is all at the coastline, exactly as the Bad North talk says.
ROLL = 0.0
SIDE = 0.15

## Read off the reference image the user supplied (`image copy.png`): a pale khaki plate, a soft
## grey-green sea, and — the thing that makes the picture — **a bright shallow band running around the
## shore**. Nothing in it is saturated.
GRASS = (0.760, 0.735, 0.520)
SAND = (0.815, 0.780, 0.590)
ROCK = (0.520, 0.520, 0.500)
SEA = (0.400, 0.500, 0.530)
SHALLOW = (0.605, 0.725, 0.745)


def h(x, y, k):
    return math.sin(x * 1.7 + k) * math.cos(y * 2.3 - k)


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def build_piece():
    half = SPAN * TILE * 0.5
    bm = bmesh.new()

    # South (+y) is the beach, north (-y) is the cliff. Every corner's height is decided by how close
    # it is to the beach edge, so the top TILTS down into the water on one side only.
    def top_z(cx, cy):
        t = (cy + half) / (SPAN * TILE)          # 0 at the cliff edge, 1 at the beach edge
        pull = max(0.0, (t - 0.55) / 0.45) ** 1.4
        return (TOP_H * (1.0 - pull) + WATERLINE * pull) + h(cx, cy, 2.1) * ROLL * (1.0 - pull)

    steps = 5
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    top, mid, foot = [], [], []
    for i in range(4):
        ax, ay = corners[i]
        bx, by = corners[(i + 1) % 4]
        for s in range(steps):
            t = s / steps
            cx = (ax + (bx - ax) * t) * half
            cy = (ay + (by - ay) * t) * half
            beach = cy > 0.0
            far = BEACH_OUT if beach else CLIFF_OUT
            down = BEACH_DOWN if beach else CLIFF_DOWN
            wob = SIDE * (0.5 if beach else 1.0)
            n = math.hypot(cx, cy) or 1.0
            ox, oy = cx / n, cy / n
            tz = top_z(cx, cy)
            top.append(bm.verts.new((cx + h(cx, cy, 0.0) * wob * 0.4,
                                     cy + h(cy, cx, 1.3) * wob * 0.4, tz)))
            mz = tz - (tz + down) * 0.45 + h(cx, cy, 7.4) * wob * 0.5
            mid.append(bm.verts.new((cx + ox * far * 0.35 + h(cx, cy, 6.1) * wob,
                                     cy + oy * far * 0.35 + h(cy, cx, 6.9) * wob, mz)))
            foot.append(bm.verts.new((cx + ox * far + h(cx, cy, 3.7) * wob,
                                      cy + oy * far + h(cy, cx, 4.2) * wob,
                                      -down + h(cx, cy, 5.5) * wob * 0.4)))

    bm.faces.new(top)
    n = len(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[j], top[i], mid[i], mid[j]))
        bm.faces.new((mid[j], mid[i], foot[i], foot[j]))
    bm.faces.new(list(reversed(foot)))
    bm.normal_update()

    lay = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        steep = f.normal.z < 0.34
        for lp in f.loops:
            if steep:
                c = ROCK
            else:
                z = lp.vert.co.z
                t = min(max((z - WATERLINE) / max(TOP_H - WATERLINE, 1e-6), 0.0), 1.0)
                t = min(t * 2.6, 1.0)
                c = tuple(SAND[k] + (GRASS[k] - SAND[k]) * t for k in range(3))
            lp[lay] = (*c, 1.0)

    me = bpy.data.meshes.new("piece_2x2")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("piece_2x2", me)
    bpy.context.collection.objects.link(ob)
    for p in ob.data.polygons:
        p.use_smooth = False

    m = bpy.data.materials.new("ground")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    vc = nt.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = "Col"
    nt.links.new(vc.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 1.0
    ob.data.materials.append(m)

    mod = ob.modifiers.new("bevel", 'BEVEL')
    mod.width = 0.016
    mod.segments = 2
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(24.0)
    return ob


def build_water():
    me = bpy.data.meshes.new("sea")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=80, y_segments=80, size=4.5)
    for v in bm.verts:
        v.co.z = (math.sin(v.co.x * 1.3) * math.cos(v.co.y * 1.05)
                  + math.sin((v.co.x + v.co.y) * 2.2) * 0.45) * 0.04
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("sea", me)
    bpy.context.collection.objects.link(ob)
    m = bpy.data.materials.new("water")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = (*SEA, 1.0)
    b.inputs["Roughness"].default_value = 0.42
    # ⚠ **Opaque in the viewport on purpose.** A blended surface sorts badly against the piece from
    # some angles and swallowed it whole in the first grab. The see-through sea belongs in a render.
    # See-through, so the bright shallows underneath show through and the coast band appears.
    b.inputs["Alpha"].default_value = 0.62
    m.blend_method = 'BLEND'
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def build_shallows():
    """⚠⚠ **The bright band around the coast, and it is the whole look of the reference picture.**

    It is a flat ring sitting just under the water: the island's own foot outline, pushed out and
    flattened. Where it is, the sea reads pale; where it is not, the sea reads deep. **The shoreline
    stops being an edge between two materials and becomes a band with width**, which is what the eye
    actually reads as "coast".
    """
    piece = bpy.data.objects["piece_2x2"]
    bm = bmesh.new()
    bm.from_mesh(piece.data)
    # ⚠⚠ **Traced from the TOP outline, not the foot.** The foot is much wider on the beach side than
    # on the cliff side, so a band following it came out as a lagoon in front and nothing behind — one
    # side read as coast and the other did not. The top outline is the same shape all the way round,
    # which is what lets the band circle the piece evenly.
    zs = sorted(v.co.z for v in bm.verts)
    top_z = zs[-1] - 0.05
    ring = [v.co.copy() for v in bm.verts if v.co.z >= top_z]
    bm.free()
    if len(ring) < 3:
        return None
    cx = sum(p.x for p in ring) / len(ring)
    cy = sum(p.y for p in ring) / len(ring)
    ring.sort(key=lambda p: math.atan2(p.y - cy, p.x - cx))

    bm2 = bmesh.new()
    # Just under the surface, so the sea's own tone still sits over it and the band reads as WATER
    # rather than as a painted rim on the land.
    inner = [bm2.verts.new((p.x, p.y, -0.03)) for p in ring]
    outer = []
    for p in ring:
        dx, dy = p.x - cx, p.y - cy
        n = math.hypot(dx, dy) or 1.0
        # ⚠ **A narrow band.** At 0.55 it was a lagoon around the piece; the reference's band is a
        # hem, wide enough to read and no wider.
        wide = 0.34 + 0.09 * math.sin(math.atan2(dy, dx) * 3.0)
        outer.append(bm2.verts.new((p.x + dx / n * wide, p.y + dy / n * wide, -0.05)))
    for i in range(len(ring)):
        j = (i + 1) % len(ring)
        bm2.faces.new((inner[i], inner[j], outer[j], outer[i]))
    bm2.normal_update()
    me = bpy.data.meshes.new("shallows")
    bm2.to_mesh(me)
    bm2.free()
    ob = bpy.data.objects.new("shallows", me)
    bpy.context.collection.objects.link(ob)
    m = bpy.data.materials.new("shallow")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = (*SHALLOW, 1.0)
    b.inputs["Roughness"].default_value = 1.0
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def frame_it():
    """Point the viewport at the piece and turn the shading up, because **the viewport is the output
    here** — nothing is rendered to a file."""
    for area in bpy.context.screen.areas:
        if area.type != 'VIEW_3D':
            continue
        for space in area.spaces:
            if space.type != 'VIEW_3D':
                continue
            space.shading.type = 'MATERIAL'
            space.shading.use_scene_world = False
            # The game's own pitch (40° above the horizon) so what is looked at here is what is seen
            # there. Yaw is left square-on.
            import mathutils
            # ⚠ Yawed 180° so the BEACH faces the viewer. Square-on put the cliff in front and the
            # beach behind the piece, where the thing being judged could not be seen at all.
            space.region_3d.view_rotation = mathutils.Euler(
                (math.radians(90.0 - 40.0), 0.0, math.radians(180.0)), 'XYZ').to_quaternion()
            space.region_3d.view_perspective = 'ORTHO'
        for region in area.regions:
            if region.type == 'WINDOW':
                with bpy.context.temp_override(area=area, region=region):
                    # ⚠ Framed on the PIECE, not on everything — `view_all` included the sea and left
                    # the piece a thumbnail in the middle of a blue rectangle.
                    piece = bpy.data.objects["piece_2x2"]
                    for o in bpy.data.objects:
                        o.select_set(o is piece)
                    bpy.context.view_layer.objects.active = piece
                    bpy.ops.view3d.view_selected()
                    # ⚠ **Then pull back.** Framed tight, a 2 m piece 0.11 m thick still fills the
                    # screen and there is no way to see HOW thin it is — thinness is a ratio, and a
                    # ratio needs room around it to read.
                    space.region_3d.view_distance *= 2.2
                break


clear()
build_piece()
build_shallows()
build_water()
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
sun.data.energy = 2.0
sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-35.0))
bpy.context.collection.objects.link(sun)
frame_it()
print("one piece is in the scene: beach on +Y, cliff on -Y")
