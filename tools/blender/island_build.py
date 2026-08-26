# Builds the WHOLE island out of pieces in Blender and renders it on real water.
#
# ⚠⚠ **Read `.scratch/island-hold/issues/01-what-one-piece-is.md` first.**
#
# The user, after seeing one piece alone: ***"이렇게 여러개 만들어서 섬을 만들어와야할듯. 그 물도 좀
# 제대로 된 거 쓰자"***. One piece cannot be judged — what is being judged is whether a grid of them
# still reads as a grid.
#
# ⚠⚠ **Pieces are laid on the grid but they do NOT each own a wall.** A tile's top shares its corner
# heights with its neighbours, so between two land tiles there is no seam at all; a side is built ONLY
# where the land ends. That is the difference between an island and a heap of blocks, and six rejected
# attempts are what bought that sentence.
#
# The shore is where every bit of the modelling budget goes, because it is the only place two
# materials meet — the Bad North talk's own rule: detail lives where faces meet, not on faces.
import bmesh
import bpy
import math

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/island_build.png"

# The island the game actually holds (`src/sim/islands.gd`). `~`/`H` are water, everything else land.
ROWS = [
    "~~~~~~~~~~~~~~~~",
    "~~~..........~~~",
    "~~..W......C..~~",
    "~~.........C..~~",
    "~~........B...~~",
    "~~....~~......~~",
    "~~~.W.~~...W.~~~",
    "~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~",
    "~~~H~~~~H~~~~H~~",
]
TIERS = [
    "................",
    "................",
    "..........11....",
    "........../1....",
    "..........11....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

## ⚠⚠ **Thickness is a RATIO to the island's width, not a number** (2026-08-26). This island is 16
## tiles across; 0.42 read as a table. The reference picture sits near 1:25 of the width.
TOP_H = 0.62        # the low level's walking surface, above the waterline
LEVEL_H = 1.05      # how far the plateau stands over it. It is a cliff; it has to read as one.
## ⚠⚠ **THE COAST IS TWO THINGS, NOT ONE** (2026-08-26, the user: ***"지금 거의 다 절벽이잖아. 이게
## 왜 다 절벽처럼 만들어졌는지 모르겠고 ... 바다하고 닿는 부분은 좀 다르게 표현할 수 있을까?"***).
## The first island gave every water-facing edge the same steep wall, so the whole outline read as one
## cliff ring. **Bad North's own list is 걸을 수 있는 곳 · 못 걷는 곳 · 절벽** — a coast a boat can land
## on and a coast it cannot are different things and have to LOOK different.
##
##   · **BEACH** — wades far out, barely drops, sand. This is where a landing happens.
##   · **CLIFF** — drops hard, pushes out almost nothing, rock. Nothing lands here.
BEACH_OUT = 1.10    # how far a beach reaches into the water. ⚠ This is also its AREA seen from
                    # above, and from above is the only place this game is looked at.
BEACH_DOWN = 0.30   # how little it drops on the way. ⚠ **Not too little**: at 0.16 the slope came out
                    # under 10° and every beach face read as flat ground, so the whole island went
                    # green again and the sand was never drawn.
CLIFF_OUT = 0.10
CLIFF_DOWN = 0.86
MID_OUT = 0.11      # the shore breaks once on the way down
MID_AT = 0.45
ROLL = 0.055        # the walking surface wanders this much. Small: it is ground, not rock.
WATERLINE = 0.02    # where a beach corner is dragged down to. **Essentially the water's own level** —
                    # the point is that land and sea share a line rather than stacking.
SIDE = 0.11         # how far the shore wanders. ⚠ **Kept small below the waterline** — bigger values
                    # made ragged flaps that showed straight through the see-through sea.
BAND_W = 0.38       # the bright shallow band that rings the coast. **This band is what makes a coast
                    # read as a coast** — an edge between two materials does not.
# ⚠ **Close to the sea, not to white.** A band far lighter than the water reads as a painted plate
# lying on it; it has to look like the same water, only shallower.
SHALLOW = (0.520, 0.618, 0.642)


def h(x, y, k):
    return math.sin(x * 1.7 + k) * math.cos(y * 2.3 - k)


def levels():
    out = []
    for y, row in enumerate(ROWS):
        line = []
        for x, ch in enumerate(row):
            if ch in "~H":
                line.append(-1)
            else:
                line.append(1 if TIERS[y][x] in "1/" else 0)
        out.append(line)
    return out


def build_island(bm, lv):
    hgt = len(lv)
    wid = len(lv[0])
    # ⚠⚠ **Y IS FLIPPED HERE, ON PURPOSE.** glTF's Y-up conversion turns Blender's +Y into Godot's -Z,
    # so an island built at y = 0..12 lands at z = -12..0 in the game and every body walks on water.
    # Flipping the row order here is the one place to fix it; doing it with a negative scale in Godot
    # would invert the normals instead.
    lv = [row for row in reversed(lv)]

    def top_of(l):
        return TOP_H + l * LEVEL_H

    def is_beach(cx, cy):
        """Whether the coast AT THIS CORNER is a beach rather than a cliff. **Decided per corner, not
        per edge**, so the transition between the two is a slope and not a step."""
        # ⚠⚠ **A LOW frequency on purpose.** At 0.42 the answer flipped from one corner to the next
        # and the sand came out as a chequerboard — the grid, drawn in material instead of geometry.
        # A beach has to be a STRETCH of coast, so the function that decides it has to change slowly.
        return h(cx * 0.15, cy * 0.15, 9.0) > -0.30

    def water_touch(cx, cy):
        """How many of the four tiles around grid corner (cx, cy) are water. 0..4."""
        n = 0
        for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0)):
            x, y = cx + dx, cy + dy
            if not (0 <= x < wid and 0 <= y < hgt) or lv[y][x] < 0:
                n += 1
        return n

    def corner(cx, cy, l):
        """⚠⚠ **THE GROUND COMES DOWN TO MEET THE WATER, and this function is the whole of it**
        (2026-08-26, the user: ***"바다하고 동일선상이 있어야 되거든. 그래서 바닷물이 첨벙첨벙하면서
        올라오는 애니메이션까지도 생각하고 있고"***). Every render before this stood the entire island
        on a plinth: the top sat at a fixed height and the coast fell off it, so land and sea never
        met — they were stacked. **A wave cannot run up a plinth.**

        Now a corner that touches water is pulled DOWN toward the waterline, so the beach walks into
        the sea at the sea's own level and there is somewhere for the water to wash over.
        ⚠ **A cliff corner is not pulled** — that coast is supposed to be a wall, and pulling it would
        delete the difference the last round just built."""
        base = top_of(l) + h(cx, cy, 2.1) * ROLL
        if l != 0:
            return base
        t = water_touch(cx, cy)
        if t == 0 or not is_beach(cx, cy):
            return base
        # Two touching tiles is the open coast; one is an inside corner and stays higher.
        pull = 1.0 if t >= 2 else 0.55
        return base * (1.0 - pull) + WATERLINE * pull + h(cx, cy, 11.3) * 0.03

    cache = {}

    def vert(cx, cy, l):
        key = (cx, cy, l)
        if key not in cache:
            cache[key] = bm.verts.new((cx, cy, corner(cx, cy, l)))
        return cache[key]

    for y in range(hgt):
        for x in range(wid):
            l = lv[y][x]
            if l < 0:
                continue
            # ⚠ The four corners come from the CORNER, so neighbours on the same level share them and
            # the surface has no seam. Nothing is drawn between two land tiles of one level.
            a = vert(x, y, l)
            b = vert(x + 1, y, l)
            c = vert(x + 1, y + 1, l)
            d = vert(x, y + 1, l)
            bm.faces.new((a, b, c, d))

            for s, (dx, dy) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
                nx, ny = x + dx, y + dy
                nl = lv[ny][nx] if 0 <= nx < wid and 0 <= ny < hgt else -1
                if nl >= l:
                    continue
                p0, p1 = (
                    ((x, y), (x + 1, y)),
                    ((x + 1, y), (x + 1, y + 1)),
                    ((x + 1, y + 1), (x, y + 1)),
                    ((x, y + 1), (x, y)),
                )[s]
                if nl >= 0:
                    _cliff(bm, vert, p0, p1, l, nl, corner)
                else:
                    # ⚠ **Which kind of coast, decided by POSITION and nothing random.** A continuous
                    # function thresholded, so neighbouring edges mostly agree and the beaches come out
                    # in stretches instead of alternating tile by tile.
                    mx = (p0[0] + p1[0]) * 0.5
                    my = (p0[1] + p1[1]) * 0.5
                    beach = h(mx * 0.15, my * 0.15, 9.0) > -0.30
                    _shore(bm, p0, p1, (dx, dy), l, corner, beach)


def _cliff(bm, vert, p0, p1, l, nl, corner):
    """A face between two levels. It is a wall, not a beach — a plateau is climbed by the stair only."""
    t0 = bm.verts.new((p0[0], p0[1], corner(p0[0], p0[1], l)))
    t1 = bm.verts.new((p1[0], p1[1], corner(p1[0], p1[1], l)))
    b0 = bm.verts.new((p0[0], p0[1], corner(p0[0], p0[1], nl)))
    b1 = bm.verts.new((p1[0], p1[1], corner(p1[0], p1[1], nl)))
    bm.faces.new((t1, t0, b0, b1))


def _shore(bm, p0, p1, out, l, corner, beach):
    """Where the land ends. Two bands down to a foot that wades out under the water.

    ⚠ **The two kinds differ in one pair of numbers and nothing else** — how far out and how far down.
    A beach is long and shallow; a cliff is short and deep. The material is then read off the resulting
    face angle, so the picture and the shape cannot disagree.
    """
    ox, oy = out
    far = BEACH_OUT if beach else CLIFF_OUT
    down = BEACH_DOWN if beach else CLIFF_DOWN
    wob = SIDE * (0.5 if beach else 1.0)
    verts = []
    for (px, py) in (p0, p1):
        tz = corner(px, py, l)
        mz = tz - (tz + down) * MID_AT + h(px, py, 7.4) * wob * 0.5
        m = (px + ox * (far * 0.35) + h(px, py, 6.1) * wob,
             py + oy * (far * 0.35) + h(py, px, 6.9) * wob, mz)
        f = (px + ox * far + h(px, py, 3.7) * wob,
             py + oy * far + h(py, px, 4.2) * wob,
             -down + h(px, py, 5.5) * wob * 0.4)
        verts.append((bm.verts.new((px, py, tz)), bm.verts.new(m), bm.verts.new(f)))
    (t0, m0, f0), (t1, m1, f1) = verts
    bm.faces.new((t1, t0, m0, m1))
    bm.faces.new((m1, m0, f0, f1))


GRASS = (0.760, 0.735, 0.520)
GRASS_HIGH = (0.820, 0.800, 0.600)
SAND = (0.815, 0.780, 0.590)
ROCK = (0.520, 0.520, 0.500)


# ⚠ **No sRGB conversion here, and that was tried.** `bm.loops.layers.color` makes a BYTE colour
# layer, which Blender already treats as sRGB — converting first made the island nearly black. What
# was actually too bright was the light, not the numbers.


def _paint(bm):
    """⚠⚠ **The ground is coloured PER VERTEX, and that is what finally kills the grid.**

    Colouring per FACE meant one tile got one colour, so every material boundary landed exactly on a
    tile edge and the island came out as a chequerboard of sand and grass — the grid, redrawn in paint
    after the geometry had stopped drawing it (2026-08-26, the user: ***"이런 느낌을 원한 게 아니야"***).

    Now the tone comes from a vertex's own HEIGHT: at the waterline it is sand, at walking height it is
    grass, and in between it blends. A tile edge is not part of that answer, so it cannot show.
    ⚠ **A steep face is rock whatever its height** — a cliff is a cliff at the top and at the foot.
    """
    lay = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        steep = f.normal.z < 0.34
        for lp in f.loops:
            if steep:
                c = ROCK
            else:
                z = lp.vert.co.z
                if z > TOP_H + LEVEL_H * 0.5:
                    c = GRASS_HIGH
                else:
                    t = (z - WATERLINE) / max(TOP_H - WATERLINE, 1e-6)
                    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
                    # A short ramp, so the sand is a band along the water and not a wash over the
                    # whole island: fully sand at the line, fully grass a third of the way up.
                    t = min(t * 3.0, 1.0)
                    c = tuple(SAND[i] + (GRASS[i] - SAND[i]) * t for i in range(3))
            lp[lay] = (*c, 1.0)


def vertex_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    attr = nt.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = "Col"
    nt.links.new(attr.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 1.0
    return m


def mat(name, rgb, rough=1.0, metal=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is not None:
        b.inputs["Base Color"].default_value = (*rgb, 1.0)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        if alpha < 1.0:
            b.inputs["Alpha"].default_value = alpha
            m.blend_method = 'BLEND'
    m.diffuse_color = (*rgb, alpha)
    return m


def water(wid, hgt):
    """⚠⚠ **Real water, not a painted plane.** It is subdivided, rippled, nearly smooth and slightly
    metallic so it takes a reflection of the sky — a flat matte quad reads as a backdrop, which is
    exactly what the first renders looked like."""
    me = bpy.data.meshes.new("sea")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=160, y_segments=160, size=26.0)
    for v in bm.verts:
        v.co.z = (math.sin(v.co.x * 1.3) * math.cos(v.co.y * 1.05)
                  + math.sin((v.co.x + v.co.y) * 2.2) * 0.45
                  + math.sin((v.co.x - v.co.y) * 3.6) * 0.22) * 0.055
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("sea", me)
    ob.location = (wid * 0.5, hgt * 0.5, 0.0)
    bpy.context.collection.objects.link(ob)

    floor_me = bpy.data.meshes.new("seabed")
    fbm = bmesh.new()
    bmesh.ops.create_grid(fbm, x_segments=1, y_segments=1, size=26.0)
    fbm.to_mesh(floor_me)
    fbm.free()
    floor = bpy.data.objects.new("seabed", floor_me)
    floor.location = (wid * 0.5, hgt * 0.5, -1.05)
    bpy.context.collection.objects.link(floor)
    floor.data.materials.append(mat("sand", (0.52, 0.50, 0.40)))
    # ⚠⚠ **See-through, over a pale floor.** That is the whole trick: shallow water near the island
    # shows the sand under it and goes bright, deep water does not — **the shoreline draws itself.**
    # An opaque sea has one tone everywhere and no shoreline at all, which every earlier render showed.
    ob.data.materials.append(mat("water", (0.055, 0.145, 0.245), 0.03, 0.15, alpha=0.72))
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def band(lv):
    """The bright shallow ring around the whole coast, traced from the island's outline at walking
    height. **This is the single thing that makes the reference picture read as an island** — the coast
    stops being a line between two materials and becomes a band with width."""
    hgt, wid = len(lv), len(lv[0])
    bm = bmesh.new()
    made = {}

    def v(px, py, z):
        key = (round(px, 3), round(py, 3), round(z, 3))
        if key not in made:
            made[key] = bm.verts.new((px, py, z))
        return made[key]

    for y in range(hgt):
        for x in range(wid):
            if lv[y][x] < 0:
                continue
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                nx, ny = x + dx, y + dy
                inside = 0 <= nx < wid and 0 <= ny < hgt and lv[ny][nx] >= 0
                if inside:
                    continue
                if dx == 0 and dy == -1:
                    p0, p1 = (x, y), (x + 1, y)
                elif dx == 1:
                    p0, p1 = (x + 1, y), (x + 1, y + 1)
                elif dy == 1:
                    p0, p1 = (x + 1, y + 1), (x, y + 1)
                else:
                    p0, p1 = (x, y + 1), (x, y)
                w = BAND_W + 0.22 * h(p0[0] * 0.3, p0[1] * 0.3, 12.0)
                # ⚠⚠ **ABOVE the waterline, not below it.** In Blender the band sat under a
                # see-through sea and showed through; the game's sea is opaque, so a band under it is
                # a band nobody sees. It is a hair over the surface here — high enough to draw, low
                # enough that the land still meets the water at the land's own edge.
                a0 = v(p0[0], p0[1], 0.020)
                a1 = v(p1[0], p1[1], 0.020)
                b0 = v(p0[0] + dx * w, p0[1] + dy * w, 0.012)
                b1 = v(p1[0] + dx * w, p1[1] + dy * w, 0.012)
                bm.faces.new((a0, a1, b1, b0))
    bm.normal_update()
    me = bpy.data.meshes.new("band")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("band", me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat("shallow", SHALLOW))
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def sky():
    """A gradient, not a flat colour. **The water has to have something to reflect** or the reflection
    is one tone and the surface goes dead."""
    w = bpy.data.worlds.new("sky")
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_WORLD':
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_WORLD')
    bg = nt.nodes.new('ShaderNodeBackground')
    grad = nt.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'EASING'
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.10, 0.16, 0.26, 1.0)
    ramp.color_ramp.elements[1].color = (0.42, 0.52, 0.66, 1.0)
    tex = nt.nodes.new('ShaderNodeTexCoord')
    map_ = nt.nodes.new('ShaderNodeMapping')
    map_.inputs['Rotation'].default_value = (math.radians(90.0), 0.0, 0.0)
    nt.links.new(tex.outputs['Generated'], map_.inputs['Vector'])
    nt.links.new(map_.outputs['Vector'], grad.inputs['Vector'])
    nt.links.new(grad.outputs['Color'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])
    bg.inputs['Strength'].default_value = 0.55
    return w


def build():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)

    lv = levels()
    hgt, wid = len(lv), len(lv[0])

    bm = bmesh.new()
    build_island(bm, lv)
    bm.normal_update()
    _paint(bm)
    me = bpy.data.meshes.new("island")
    bm.to_mesh(me)
    bm.free()
    isl = bpy.data.objects.new("island", me)
    bpy.context.collection.objects.link(isl)
    # ⚠ Merge the duplicated shore/cliff corners so the silhouette is one outline, not stitched strips.
    bpy.context.view_layer.objects.active = isl
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode='OBJECT')

    # ⚠ **ONE material.** Four materials meant four hard boundaries and every one of them fell on a
    # tile edge; the tone now travels in the vertex colours instead.
    isl.data.materials.append(vertex_mat("ground"))
    for p in isl.data.polygons:
        p.use_smooth = False

    # ⚠⚠ **Auto smooth by ANGLE.** Flat-shading every face let each tile take its own normal and the
    # shading drew the grid back after the geometry had stopped. Near-coplanar tops join; cliffs stay hard.
    bpy.context.view_layer.objects.active = isl
    for o in bpy.data.objects:
        o.select_set(o is isl)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))
    for o in bpy.data.objects:
        o.select_set(False)

    b = isl.modifiers.new("bevel", 'BEVEL')
    b.width = 0.035
    b.segments = 2
    b.limit_method = 'ANGLE'
    b.angle_limit = math.radians(24.0)

    band(lv)
    water(wid, hgt)

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 1.7
    sun.data.angle = math.radians(2.0)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-35.0))
    bpy.context.collection.objects.link(sun)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = wid + 3.0
    cam = bpy.data.objects.new("cam", cam_data)
    pitch = math.radians(40.0)
    dist = 60.0
    cam.location = (wid * 0.5, hgt * 0.5 - math.cos(pitch) * dist, math.sin(pitch) * dist)
    cam.rotation_euler = (math.radians(90.0) - pitch, 0.0, 0.0)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    # ⚠⚠ **Without ray tracing the water is a flat matte sheet.** Roughness alone does nothing if
    # nothing is being reflected — the first render's sea read as painted card for exactly this reason.
    sc.eevee.use_raytracing = True
    sc.eevee.use_shadows = True
    # ⚠⚠ **THIS is why sand and rock looked like one grey material.** Blender's default view transform
    # is AgX, a filmic curve that desaturates hard toward white — it is right for photoreal renders and
    # wrong for flat-shaded game art, where the colour IS the information. Standard shows the albedo
    # that was actually set.
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.resolution_x = 1200
    sc.render.resolution_y = 800
    sc.world = sky()
    sc.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    export()
    print("rendered", OUT, "faces", len(isl.data.polygons))


def export():
    """⚠⚠ **THE ISLAND IS EXPORTED TWICE: as a MESH and as a BOARD, and both come from this file.**

    Until 2026-08-26 the letter grid lived in `src/sim/islands.gd` and this script read it, so the
    game owned the shape and Blender only decorated it — which is backwards the moment the user is
    the one drawing islands. **Now this file is the source**: `island.glb` is what the game draws and
    `island.json` is what the game walks on, and they cannot disagree because one run writes both.
    """
    import json
    import os
    base = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/terrain"
    os.makedirs(base, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o.name in ("island", "band"))
    bpy.ops.export_scene.gltf(filepath=base + "/island.glb", export_format='GLB',
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    board = {
        "w": len(ROWS[0]),
        "h": len(ROWS),
        "rows": list(ROWS),
        "tiers": list(TIERS),
        "base_h": TOP_H,
        "level_h": LEVEL_H,
    }
    with open(base + "/island.json", "w", encoding="utf-8") as fh:
        json.dump(board, fh, ensure_ascii=False, indent=1)
    print("exported glb + json")


build()
