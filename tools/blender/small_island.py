# Four 2x2 pieces joined into one small island, in the Blender scene.
#
# ⚠⚠ **Read `.scratch/island-hold/issues/01-what-one-piece-is.md` first.**
#
# The user, after judging a single piece from six angles: ***"옆면을 살려야 됐지? 음 이걸 네 개 붙여서
# 좀 약간 간단한 섬 만들어 줄래?"***
#
# **Four pieces, and no seams between them.** The pieces are laid on the grid but only the OUTSIDE of
# the block gets a coast — inside, tiles share their corner heights, so there is nothing to see. That
# is the rule six rejected attempts paid for.
#
# ⚠ **The side is back.** Thinning the top to 0.04 made the piece read as a sheet floating on the sea;
# what fixes that is not a thicker top but a DEEPER underwater part — the land stays thin and the rock
# below it goes down far enough that the island is standing in the water rather than on it.
import bmesh
import bpy
import math
import mathutils

SPAN = 4            # tiles across — two 2x2 pieces each way
TOP_H = 0.15        # the walking surface above the waterline.
                    # ⚠⚠ **「얇게」 and 「옆면을 살려라」 are not in conflict — they name a RATIO.** At
                    # 0.055 on a 4 m island (1:73) there was no side left to see and it read as a sheet
                    # of paper on the sea. The reference picture sits around 1:25, which on this island
                    # is 0.16. Thin means thin FOR ITS WIDTH, not invisible.
WATERLINE = 0.015
BEACH_OUT = 0.46
BEACH_DOWN = 0.34   # ⚠ **Deep, and this is the fix for "floating".** The beach keeps walking down
                    # well under the surface instead of stopping at it.
CLIFF_OUT = 0.12
CLIFF_DOWN = 0.62
SIDE = 0.06         # ⚠ **How far the underwater foot wanders sideways.** At 0.13 the feet stuck out
                    # in ragged flaps that showed straight through the see-through sea and read as a
                    # rendering fault. The wobble belongs on the part above water.
BAND_W = 0.34       # the bright shallow band that rings the coast

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


def is_beach(cx, cy):
    """Which kind of coast this bit of outline is. **Low frequency**, so beaches come out as stretches
    rather than alternating tile by tile."""
    return h(cx * 0.55, cy * 0.55, 9.0) > -0.10


def build_island():
    half = SPAN * 0.5
    bm = bmesh.new()
    cache = {}

    def edge_dist(cx, cy):
        """How far a corner is from the outline, in tiles. 0 on the outline."""
        return min(cx + half, half - cx, cy + half, half - cy)

    def vert(cx, cy):
        key = (round(cx, 4), round(cy, 4))
        if key not in cache:
            d = edge_dist(cx, cy)
            if d <= 0.001 and is_beach(cx, cy):
                # A beach corner comes all the way down to the water, so land and sea share a line.
                z = WATERLINE
            elif d <= 1.001:
                t = min(max(d, 0.0), 1.0)
                z = WATERLINE + (TOP_H - WATERLINE) * (t if is_beach(cx, cy) else 1.0)
            else:
                z = TOP_H
            cache[key] = bm.verts.new((cx, cy, z))
        return cache[key]

    for iy in range(SPAN):
        for ix in range(SPAN):
            x = ix - half
            y = iy - half
            bm.faces.new((vert(x, y), vert(x + 1, y), vert(x + 1, y + 1), vert(x, y + 1)))

    # The coast, on the outside only.
    for iy in range(SPAN):
        for ix in range(SPAN):
            x = ix - half
            y = iy - half
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                nx, ny = ix + dx, iy + dy
                if 0 <= nx < SPAN and 0 <= ny < SPAN:
                    continue
                if dx == 0 and dy == -1:
                    p0, p1 = (x, y), (x + 1, y)
                elif dx == 1:
                    p0, p1 = (x + 1, y), (x + 1, y + 1)
                elif dy == 1:
                    p0, p1 = (x + 1, y + 1), (x, y + 1)
                else:
                    p0, p1 = (x, y + 1), (x, y)
                mx, my = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
                beach = is_beach(mx, my)
                far = BEACH_OUT if beach else CLIFF_OUT
                down = BEACH_DOWN if beach else CLIFF_DOWN
                wob = SIDE * (0.5 if beach else 1.0)
                cols = []
                for (px, py) in (p0, p1):
                    tz = vert(px, py).co.z
                    n = math.hypot(dx, dy) or 1.0
                    ox, oy = dx / n, dy / n
                    mz = tz - (tz + down) * 0.45 + h(px, py, 7.4) * wob * 0.5
                    m = bm.verts.new((px + ox * far * 0.35 + h(px, py, 6.1) * wob,
                                      py + oy * far * 0.35 + h(py, px, 6.9) * wob, mz))
                    f = bm.verts.new((px + ox * far + h(px, py, 3.7) * wob,
                                      py + oy * far + h(py, px, 4.2) * wob,
                                      -down + h(px, py, 5.5) * wob * 0.4))
                    cols.append((vert(px, py), m, f))
                (t0, m0, f0), (t1, m1, f1) = cols
                bm.faces.new((t1, t0, m0, m1))
                bm.faces.new((m1, m0, f0, f1))

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
                c = tuple(SAND[k] + (GRASS[k] - SAND[k]) * min(t * 1.8, 1.0) for k in range(3))
            lp[lay] = (*c, 1.0)

    me = bpy.data.meshes.new("island")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("island", me)
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

    # ⚠⚠ **AUTO SMOOTH, and this is what removes the last of the grid.** Every top face was shaded
    # flat, so the four tiles of a piece each took their own slightly different normal and the eye read
    # the boundaries between them as a grid — after the geometry had already stopped drawing one.
    # Smoothing by ANGLE joins the near-coplanar tops into one surface and leaves the cliff edges hard.
    bpy.context.view_layer.objects.active = ob
    for o in bpy.data.objects:
        o.select_set(o is ob)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))

    mod = ob.modifiers.new("bevel", 'BEVEL')
    mod.width = 0.02
    mod.segments = 2
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(24.0)
    return ob


def build_band():
    """The bright shallow ring. Traced from the island's OUTLINE at walking height, so it circles the
    whole block evenly instead of following the wider beach feet."""
    half = SPAN * 0.5
    bm = bmesh.new()
    ring = []
    steps = SPAN * 3
    for i in range(4):
        ax, ay = [(-1, -1), (1, -1), (1, 1), (-1, 1)][i]
        bx, by = [(-1, -1), (1, -1), (1, 1), (-1, 1)][(i + 1) % 4]
        for s in range(steps):
            t = s / steps
            ring.append(((ax + (bx - ax) * t) * half, (ay + (by - ay) * t) * half))
    inner = [bm.verts.new((px, py, -0.02)) for px, py in ring]
    outer = []
    for px, py in ring:
        n = math.hypot(px, py) or 1.0
        wide = BAND_W + 0.10 * math.sin(math.atan2(py, px) * 3.0)
        outer.append(bm.verts.new((px + px / n * wide, py + py / n * wide, -0.035)))
    for i in range(len(ring)):
        j = (i + 1) % len(ring)
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    bm.normal_update()
    me = bpy.data.meshes.new("band")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("band", me)
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


def build_water():
    me = bpy.data.meshes.new("sea")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=90, y_segments=90, size=7.0)
    for v in bm.verts:
        v.co.z = (math.sin(v.co.x * 1.3) * math.cos(v.co.y * 1.05)
                  + math.sin((v.co.x + v.co.y) * 2.2) * 0.45) * 0.03
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("sea", me)
    bpy.context.collection.objects.link(ob)
    m = bpy.data.materials.new("water")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = (*SEA, 1.0)
    b.inputs["Roughness"].default_value = 0.42
    # ⚠ Less see-through than before: the sea has to hide the rock under it and still let the bright
    # shallow band show. At 0.62 it hid nothing.
    b.inputs["Alpha"].default_value = 0.80
    m.blend_method = 'BLEND'
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


clear()
isl = build_island()
build_band()
build_water()
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
sun.data.energy = 2.0
sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-35.0))
bpy.context.collection.objects.link(sun)
for o in bpy.data.objects:
    o.select_set(False)
print("small island: 4x4 tiles = four 2x2 pieces, coast on the outside only")
