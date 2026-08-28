# **The island, assembled from 2x2 BLOCKS.** One run writes `assets/terrain/island.glb` (what the game
# draws) and `assets/terrain/island.json` (what the game walks on), and they cannot disagree because one
# run writes both.
#
# WARNING **THIS FILE REPLACED A 1245-LINE CALCULATOR ON 2026-08-27.** The old one worked out the whole
# island as one lump -- every coastal corner, every wall lean, every colour ramp a formula -- and the
# user rejected the picture it made six times. What runs now is ticket 01 rule 1 taken literally: a
# piece is 2x2 tiles, the island is those pieces laid down, and nothing about a piece's shape is decided
# by where it happens to sit.
#
# WARNING **The old piece scripts are gone with it** (`pieces.py`, `one_piece.py`, `shore_piece.py`,
# `small_island.py`). They carried rules the user had already overturned -- the beach side above all --
# so anything built from them came out to a spec that stopped being true in August.
#
# Run:  python tools/blender/send.py tools/blender/island_build.py
# WARNING **or through `bake_island.ps1`, which is the only way that makes the GAME see the result.**
# Godot serves its own converted copy and a `--script` run does not re-convert a changed source.
import bmesh
from mathutils import Vector
import bpy
import json
import math
import os

OUT_DIR = r"C:/Users/djgnf/Desktop/godot_games/tockbon/assets/terrain"

S = 2.0             # a piece is 2x2 tiles, and one tile is one metre
# WARNING **LOWERED 0.26 -> 0.15 -> 0.08 ON 2026-08-28** (the user, on the Blender window: 「일 층이 높이가
# 너무 높아. 일 층 높이 낮춰줘」). **This number IS the ground floor's height** — the game's water plane
# sits at 0 and the grass sits here, so the band of rock on show all the way round the island is
# exactly `TOP_H`. At 0.26 it was half a notch of bare wall under every blade of grass; 0.15 was
# still a step, and the user asked for the block itself to come down again: 「그 칸 자체를 좀 내려줘」.
# WARNING **`SEA_Z` is NOT this number and moving it does nothing here** — it was tried first and it is
# only how far the skirt reaches DOWN, all of it under the water plane and invisible. Blender draws no
# water at all, so this is one of the numbers that can only be judged in the game.
# WARNING **A storey is still two notches and a notch is still half a tile.** `LEVEL_H` did not move;
# 「too high」was about the ground's own lip, not about the storey rule.
TOP_H = 0.20        # the walking surface. The game reads this out of `island.json` as `base_h`
LEVEL_H = 0.5       # WARNING **one notch is HALF A TILE, and this is the definition.** A storey is two
                    # notches, a stair is one, and a body may cross one notch -- which is what makes the
                    # stair the only way up. Ground is level 0, the stair 1, the second storey 2.
STOREY = LEVEL_H * 2.0

# WARNING **THE SEA IS AT -0.45 AND THE LAND USED TO STOP AT 0.02** (found 2026-08-27, the user:
# 「다 조금씩 떠 있는데」). `src/look.gd`'s `TERRAIN_H_WATER` is where the water actually is; the island
# ended almost half a tile above it and the gap read as a thin band round the whole coast that nobody
# could name. **If that constant moves, this one moves with it.**
SEA_Z = -0.45
RIM_Z = SEA_Z - 0.05     # the shore ends UNDER the water, so the water laps over it

WALL_DOWN = 1.15    # how far a block's body carries on below its own floor
WALL_DRAFT = 0.05   # how far the foot sits outside the top edge. WARNING **This is not a beach.**
WALL_LIP = 0.16     # the lip under a notch edge, as a fraction of one notch
WALL_LIP_DARK = 0.26
WALL_AO = 0.20      # how much darker the foot of a wall is
EDGE_EARTH = 0.30   # how much of the wall's stone bleeds onto the ground at the lip of a drop
INSET = 0.42        # how far in the flat interior starts

# WARNING **THE COAST IS A SKIRT HUNG OFF THE LAND'S OUTER EDGE, NOT A DIP CUT INTO EACH PIECE**
# (2026-08-27, the user: 「검은 금을 없애자」). Cutting it per piece made the land's own top alternate --
# down at the middle of a coastal edge, back up at a corner an inland piece also owns -- and every one
# of those steps showed as a short black crack round the shore. The land top is FLAT everywhere now and
# the shore hangs outward and down from its boundary. Where two coastal pieces meet, both work the
# skirt's outer point out from the SAME world corner and the SAME land/water pattern, so it is one point
# and nothing can crack.
SKIRT = 0.46
SKIRT_ROLL = 0.55   # where the roll's knee sits along that reach. WARNING **0.40 -> 0.55 on
                    # 2026-08-28**: the knee sat close in and the land turned into the sea with a
                    # visible crease — 「바다랑 닿는 부분이 꺾이잖아」. Further out, the shoulder carries
                    # longer and the fall reads as a roll rather than a bend.

# WARNING **EVERY PIECE IS DIFFERENT AND THE SEAMS STILL HOLD** (2026-08-27, the user: 「모두가 동일하면
# 어색함」). The seed is not per PIECE but per WORLD POSITION: a corner shared by four pieces hashes to
# the same number in all four, so it moves as one point. **A per-piece seed tears every seam** -- it was
# tried, and the count of welded vertices fell from 3200 to 2004 until the seed was moved to the corner.
# WARNING **HALVED, THEN HALVED AGAIN, ON 2026-08-28** (the user, on the island in the Blender window: 「윤곽이 굳이 이렇게
# 꼬불꼬불할 필요는 없을 거 같아」 and then 「바다랑 닿는 부분이 꺾이잖아. 그 부분을 조금 더 완화
# 해줄래? 굴곡도 완화해줘」). The wobble exists so no two
# corners of the coast are alike; at the old values it read as a crinkle rather than a coastline.
# WARNING **`COAST_WOB` is cited elsewhere as the floor under how far things sit inside the shore.**
# Anything measured against it moves when this moves.
CORNER_WOB = 0.035
SEAM_WOB = 0.03
COAST_WOB = 0.07    # bigger, because a coastal edge is owned by ONE piece and nothing must agree with it
CHAM_MIN, CHAM_SPAN = 0.34, 0.06   # a corner cut is never the same twice, and never 45 degrees
                                   # WARNING **The SPAN narrowed 2026-08-28 with the wobble** — the
                                   # variation is what read as crinkle, and the cut itself is not.

GRASS = (0.760, 0.735, 0.520)
GRASS_HIGH = (0.655, 0.710, 0.450)
# WARNING **Lifted for the GAME, not for the render.** A face turned away from the sun keeps almost no
# brightness, and a value that looks right in Blender comes out near black in the game -- Blender lights
# with a strong key, the game with one sun and an ambient, and the outline pass darkens the edge on top.
ROCK = (0.615, 0.570, 0.660)
# The tone where the land goes under the water. **Darker and browner than the field, not lighter**: the
# ground already reads bright yellow under the game's sun and a paler shore blows out to white.
SHORE = (0.660, 0.600, 0.440)

CORN = [(0.0, 0.0), (S, 0.0), (S, S), (0.0, S)]
SIDE = ["s", "e", "n", "w"]
OUTW = {"s": (0.0, -1.0), "e": (1.0, 0.0), "n": (0.0, 1.0), "w": (-1.0, 0.0)}

# --- the board -------------------------------------------------------------------------------------
# `.` land, `~` sea. **The outline turns on 2x2 pieces**, which is ticket 01 rule 1: a coast that can
# only turn on even tiles reads as shape rather than as squares.
# WARNING **NINETEEN LAND PIECES, DOWN FROM SIXTY-FOUR** (2026-08-27, the user, holding a Bad North
# screenshot beside ours: the mat that lights up is one PIECE, and sixty-four of them is not a board a
# person can read). Counted off the reference: about twelve mats on the low ground and six or seven on
# the raised part -- twenty for a whole island. **The island was enlarged to 13x10 the day before, when
# the command unit was still the TILE**; the piece became the unit the next day and that number came
# with it unexamined.
#
# WARNING **The interior 2x2 is where the plateau goes and it is the whole reason this outline is not
# thinner.** A raised piece must have low ground on all eight sides -- see `HIGH` below -- so shaving
# another ring off this board leaves nowhere to raise.
PIECES = [
    "~~~~~~~~",
    "~~....~~",
    "~......~",
    "~.....~~",
    "~~....~~",
    "~~~~~~~~",
]
PW, PH = len(PIECES[0]), len(PIECES)
TW, TH = PW * 2, PH * 2

# WARNING **THE LEVEL BOARD IS WRITTEN IN TILES, NOT IN PIECES**, but this island's plateau is laid on
# even tiles anyway so that every raised block is a whole piece. **The plateau never reaches the coast**:
# a rim of low ground all the way round is what lets the raised part be seen AS raised.
_hi = [["." for _ in range(TW)] for _ in range(TH)]
# WARNING **FOUR PIECES, DOWN FROM TWELVE.** Shrunk with the board rather than left at its old size:
# the plateau used to be a fifth of the island and at the new size it would have been most of it,
# leaving the low ground with nowhere to stand.
for _y in range(4, 8):
    for _x in range(6, 10):
        _hi[_y][_x] = "2"
for _y in range(6, 8):        # the stair: one notch, cut into the plateau's west face
    for _x in range(6, 8):
        _hi[_y][_x] = "1"
HIGH = ["".join(r) for r in _hi]

TIER_CHARS = "./0123456789"
TIER_LEVELS = [0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


def lvl_of(ch):
    k = TIER_CHARS.find(ch)
    return TIER_LEVELS[k] if k >= 0 else 0


def _expand():
    """`PIECES` -> the tile grid the game reads. **One place, so the two cannot drift.**

    Every border tile becomes a harbour (`H`): boats sail from harbours, and the beasts come from every
    point where the sea meets the land.
    """
    rows = []
    for pr in PIECES:
        line = "".join((("." if c == "." else "~") * 2) for c in pr)
        for _ in range(2):
            rows.append(line)
    w, hgt = len(rows[0]), len(rows)
    out = []
    for y, r in enumerate(rows):
        if y == 0 or y == hgt - 1:
            out.append("H" * w)
        else:
            out.append("H" + r[1:-1] + "H")
    return out


ROWS = _expand()


def _tiers():
    """`HIGH` as the board the game walks on. **No expansion -- it is already in tiles.**

    A tile that is water in `PIECES` is ground level whatever `HIGH` says: the level board has to be the
    same shape as the row board, and nothing stands on water.
    """
    out = []
    for y, row in enumerate(HIGH):
        line = ""
        for x in range(len(ROWS[0])):
            c = row[x] if x < len(row) else "."
            if ROWS[y][x] in "~H":
                c = "."
            line += c
        out.append(line)
    return out


TIERS = _tiers()


# --- the shape -------------------------------------------------------------------------------------
def h2(x, y, k=0.0):
    """A hash of a WORLD point. Same point, same answer, whichever piece is asking."""
    v = math.sin(x * 127.1 + y * 311.7 + k * 74.7) * 43758.5453
    return (v - math.floor(v)) * 2.0 - 1.0


def tone_noise(x, y):
    """WARNING **Two long wavelengths, never one tile.** A wobble near one cycle per tile gives every
    tile its own patch and the grid draws itself back in shading."""
    return (math.sin(x * 0.27 + y * 0.19) * 0.6
            + math.sin(x * 0.11 - y * 0.16 + 2.1) * 0.4)


# WARNING **TURNED OFF ON 2026-08-28, AND IT IS WHAT 「칸 색이 좀 이상하네」 WAS LOOKING AT.** It
# swung every vertex's tone by +-5.5%, sampled per vertex -- and a 칸's top is ONE flat fan, so the
# swing interpolated across a two-metre face and landed its edges on the 칸 boundaries. On a ground
# that had just lost its outline and most of its relief, that read as blotchy rectangles, one per 칸.
# **Measured: zeroed here, the blotches went and nothing else changed.**
# WARNING **What it was FOR is now done by the 판.** It existed so the island did not read as one flat
# slab; the mats break the surface up instead, and they do it in a shape somebody chose.
# WARNING **Not deleted.** Put a number back here and the variation returns — but anything over about
# 0.02 brings the blotches with it on this size of island.
TONE_NOISE = 0.0


def ground_tone(z, mix=0.0, nz=0.0):
    """WARNING **The tone comes from a vertex's own HEIGHT, never from a face or a tile.** Colouring per
    face put every material boundary exactly on a tile edge and the island came out as a chequerboard --
    the grid, redrawn in paint after the geometry had stopped drawing it."""
    if z <= TOP_H:
        t = min(max((z - SEA_Z) / (TOP_H - SEA_Z), 0.0), 1.0)
        t = min(t / 0.72, 1.0)
        c = [SHORE[i] + (GRASS[i] - SHORE[i]) * t for i in range(3)]
    else:
        t = min((z - TOP_H) / STOREY, 1.0)
        c = [GRASS[i] + (GRASS_HIGH[i] - GRASS[i]) * t for i in range(3)]
    if mix:
        c = [c[i] + (ROCK[i] - c[i]) * mix for i in range(3)]
    k = 1.0 + nz * TONE_NOISE
    return (c[0] * k, c[1] * k, c[2] * k)


def wall_tone(z, nz=0.0):
    """Dark right under a notch edge (the lip, which is the crease the detail belongs on), light through
    the middle of the face, dark again at the foot where the wall meets the ground.

    WARNING **No geometry crease goes with it.** Cutting a wall into horizontal bands made the island
    read as a stack of pancakes from a low angle; the break is in the colour only.
    """
    lv = max(int(math.ceil((z - TOP_H) / LEVEL_H - 1e-4)), 0)
    d = max(TOP_H + lv * LEVEL_H - z, 0.0)
    lip = 1.0 - min(d / (LEVEL_H * WALL_LIP), 1.0)
    ft = min(d / (LEVEL_H * 1.05), 1.0)
    k = (1.0 - WALL_AO * ft - WALL_LIP_DARK * lip) * (1.0 + nz * 0.06)
    return tuple(ROCK[i] * k for i in range(3))


def vertex_mat(name):
    """WARNING **ONE material for the whole island.** Four materials meant four hard boundaries and
    every one of them fell on a tile edge; the tone travels in the vertex colours instead."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    # WARNING Blender 5.1 does NOT name this node "Principled BSDF". Find it by TYPE.
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Metallic"].default_value = 0.0
    return m


def waterline_point(prof):
    """Where one shore column crosses the water plane, walked from the land downward.

    `prof` is the column top-down as `(x, y, z)`: the land's own outer point, the skirt's knee, the
    skirt's hem. **This is the point the sea has to measure from** -- not the piece boundary, which is
    half a tile inside the rock, and not the hem, which sits under the water.

    WARNING **It never returns None and it never guesses.** A shore column that does not reach the
    water is a hole in the exported coast, and the sea would draw a straight line through it. Nothing
    in this repo pretends to work, so it raises instead.
    """
    for i in range(len(prof) - 1):
        (x0, y0, z0), (x1, y1, z1) = prof[i], prof[i + 1]
        if z0 >= SEA_Z >= z1 and z0 > z1:
            t = (z0 - SEA_Z) / (z0 - z1)
            return (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
    raise RuntimeError("a shore column never crosses the water at z=%.3f: %r" % (SEA_Z, prof))


def block(name, z_top, coast_sides, cliff_sides, corner_out, wx, wy):
    """One 2x2 piece.

    `coast_sides` are the sides facing the sea, `cliff_sides` the sides facing lower land -- and a
    RAISED block facing the sea is a cliff, not a coast. Dropping its edge to the waterline is a ground
    rule; applied one storey up it ramped from the plateau straight into the water and the plateau's
    edge came out as a sawtooth.
    """
    openS = set(coast_sides) | set(cliff_sides)
    ring, rim, sk = [], [], []
    for i in range(4):
        cx, cy = CORN[i]
        px, py = CORN[(i - 1) % 4]
        nx, ny = CORN[(i + 1) % 4]
        kx = cx + h2(wx + cx, wy + cy, 1.0) * CORNER_WOB
        ky = cy + h2(wx + cx, wy + cy, 2.0) * CORNER_WOB
        prev_s, this_s = SIDE[(i - 1) % 4], SIDE[i]
        # this piece hangs a skirt at the corner only if IT touches the sea there
        at_corner = corner_out[i] if (prev_s in coast_sides or this_s in coast_sides) else None
        if prev_s in openS and this_s in openS:
            # WARNING **A corner is not cut at 45 degrees**, and never the same twice -- stacking
            # identical corners is what makes a repeat visible without any clutter to hide it.
            a = CHAM_MIN + (h2(wx + cx, wy + cy, 3.0) * 0.5 + 0.5) * CHAM_SPAN
            b = CHAM_MIN + (h2(wx + cx, wy + cy, 4.0) * 0.5 + 0.5) * CHAM_SPAN
            for (tx, ty, d, s_own) in ((px, py, a, prev_s), (nx, ny, b, this_s)):
                dx, dy = tx - cx, ty - cy
                L = math.hypot(dx, dy)
                ring.append((kx + dx / L * d, ky + dy / L * d))
                rim.append(this_s in cliff_sides or prev_s in cliff_sides)
                sk.append(OUTW[s_own] if s_own in coast_sides else at_corner)
        else:
            ring.append((kx, ky))
            rim.append(this_s in cliff_sides or prev_s in cliff_sides)
            sk.append(at_corner)
        mx, my = (cx + nx) * 0.5, (cy + ny) * 0.5
        ax, ay = nx - cx, ny - cy
        aL = math.hypot(ax, ay)
        ax, ay = ax / aL, ay / aL
        ox, oy = OUTW[this_s]
        if this_s in coast_sides:
            t = h2(wx + mx, wy + my, 5.0) * COAST_WOB * 0.7
            o = h2(wx + mx, wy + my, 6.0) * COAST_WOB
            ring.append((mx + ax * t + ox * o, my + ay * t + oy * o))
            sk.append((ox, oy))
        else:
            # WARNING **A SEAM MOVES IN WORLD AXES, NEVER ALONG ITS OWN EDGE.** Two pieces sharing an
            # edge disagree about which way is「along」and which is「out」, so one hash pushed them
            # opposite ways and every seam opened.
            ring.append((mx + h2(wx + mx, wy + my, 5.0) * SEAM_WOB,
                         my + h2(wx + mx, wy + my, 6.0) * SEAM_WOB))
            sk.append(None)
        rim.append(this_s in cliff_sides)

    ccx, ccy = S * 0.5, S * 0.5
    bm = bmesh.new()
    rows, tops, inner, knee, hem = [], [], [], [], []
    # **The real coastline, taken off the very vertices the shore is built from.** One entry per ring
    # point: the world XY where that column meets the water, or None where the piece has no shore.
    wline = []
    for k, (x, y) in enumerate(ring):
        dx, dy = x - ccx, y - ccy
        L = math.hypot(dx, dy) or 1.0
        inx, iny = dx / L, dy / L
        v_top = bm.verts.new((x, y, z_top))
        v_in = bm.verts.new((x - inx * INSET, y - iny * INSET, z_top))
        tops.append(v_top)
        inner.append(v_in)
        if sk[k] is None:
            knee.append(None)
            hem.append(None)
            wline.append(None)
            fx, fy = x, y
            z0 = z_top
        else:
            ox, oy = sk[k]
            # WARNING **The reach's own wobble came down with everything else** (0.22 ->
            # 0.10, 2026-08-28): a skirt that varied a fifth of its length per corner is a
            # crinkled hem, and 「굴곡도 완화해줘」 is that hem.
            reach = SKIRT * (1.0 + h2(wx + x, wy + y, 8.0) * 0.10)
            zr = RIM_Z + h2(wx + x, wy + y, 7.0) * 0.05
            # the shoulder stays high and the fall steepens near the water: a roll, not a ramp
            knee.append(bm.verts.new((x + ox * reach * SKIRT_ROLL, y + oy * reach * SKIRT_ROLL,
                                      z_top - (z_top - zr) * 0.34)))
            hem.append(bm.verts.new((x + ox * reach, y + oy * reach, zr)))
            # WARNING **Read off `knee[-1]` and `hem[-1]`, not recomputed.** The exported line and the
            # mesh have to be the same numbers or they drift apart the first time one of them is
            # tuned, and drift is exactly the defect this export was written to end.
            px_, py_ = waterline_point([(x, y, z_top), tuple(knee[-1].co), tuple(hem[-1].co)])
            wline.append((wx + px_, wy + py_))
            fx, fy = x + ox * reach, y + oy * reach
            z0 = RIM_Z
        col = []
        zl = z0 - LEVEL_H * WALL_LIP
        col.append(bm.verts.new((fx, fy, zl)))
        for j in range(1, 13):
            zz = zl - (zl + WALL_DOWN) * j / 12.0
            last = 1.0 if j == 12 else 0.0
            col.append(bm.verts.new((fx - inx * WALL_DRAFT * last,
                                     fy - iny * WALL_DRAFT * last, zz)))
        rows.append(col)
    ctr = bm.verts.new((ccx, ccy, z_top))
    n = len(ring)
    shore = set()
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ctr, inner[i], inner[j]))
        bm.faces.new((inner[i], tops[i], tops[j], inner[j]))
        if sk[i] is not None and sk[j] is not None:
            shore.add(bm.faces.new((tops[i], knee[i], knee[j], tops[j])))
            shore.add(bm.faces.new((knee[i], hem[i], hem[j], knee[j])))
        elif sk[i] is not None:
            shore.add(bm.faces.new((tops[i], knee[i], tops[j])))
            shore.add(bm.faces.new((knee[i], hem[i], tops[j])))
        elif sk[j] is not None:
            shore.add(bm.faces.new((tops[i], knee[j], tops[j])))
            shore.add(bm.faces.new((tops[i], hem[j], knee[j])))
        top_i = hem[i] if sk[i] is not None else tops[i]
        top_j = hem[j] if sk[j] is not None else tops[j]
        bm.faces.new((top_i, rows[i][0], rows[j][0], top_j))
        for k in range(len(rows[i]) - 1):
            bm.faces.new((rows[i][k], rows[i][k + 1], rows[j][k + 1], rows[j][k]))
    bm.faces.new(list(reversed([r[-1] for r in rows])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

    rimset = {tops[i] for i in range(n) if rim[i]}
    # WARNING **The shore TONE reaches further inland than the shore SHAPE does.** The skirt is narrow
    # and almost all of it sits under the water, so a tone that stopped where the skirt stops was
    # invisible from the game's distance. It is carried on the flat land behind it and fades to the
    # field at the tile's centre.
    shoremix = {}
    for k in range(n):
        if sk[k] is not None:
            shoremix[hem[k]] = 1.0
            shoremix[knee[k]] = 0.90
            # WARNING **THE SHORE TONE STOPS AT THE BLOCK'S OUTER LIP SINCE 2026-08-28.** It used to
            # carry 0.55 onto that lip and 0.25 all the way to the inner ring, so a 칸 with sea on one
            # side came out a different colour ACROSS ITS WHOLE TOP from a 칸 with none. The user saw
            # exactly that: 「바다랑 만나지 않는 칸이 이상하다」 — the inland 칸 read as pale rectangles
            # against the gold of the coastal ones.
            # WARNING **`inner` is dropped entirely, not just reduced.** It is a vertex of the flat top
            # a body stands on; any shore tone there is a tone on the walking surface, and the walking
            # surface has to be one colour or the 칸 grid draws itself back in paint.
            shoremix[tops[k]] = 0.22
    lay = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        # WARNING **The shore is GROUND however steep it gets.** With a narrow skirt it tips past the
        # angle the rock test uses, and the shore came out as a purple cliff the tone never reached.
        steep = f.normal.z < 0.34 and f not in shore
        for lp in f.loops:
            v = lp.vert
            nz = tone_noise(wx + v.co.x, wy + v.co.y)
            if steep:
                c = wall_tone(v.co.z, nz)
            else:
                c = ground_tone(v.co.z, EDGE_EARTH if v in rimset else 0.0, nz)
                m = shoremix.get(v, 0.0)
                if m:
                    c = tuple(c[i] + (SHORE[i] - c[i]) * m for i in range(3))
            lp[lay] = (*c, 1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    # **The shore as segments**, one per ring edge that has a shore at both ends -- which is the same
    # test the shore FACES are built with a few lines up, so the line and the rock end together. Two
    # pieces meeting at a corner work that corner out from the same world point and the same hashes, so
    # their chains join on one shared point and the island's coast comes out closed.
    wsegs = [[wline[i], wline[(i + 1) % n]]
             for i in range(n) if wline[i] is not None and wline[(i + 1) % n] is not None]
    return ob, wsegs


TREADS = 6


def stair(name):
    """**The treads are drawn INSIDE the stair's own mesh.**

    WARNING Cutting the walked notch finer to make treads was the wrong lever and cost a round: the code
    that splits a wall makes one seam per level, so halving the notch put twelve seams down one wall and
    the island read as a stack of pancakes. Four treads then read as three big slabs; six with a nosing
    is what finally reads as a stair.
    """
    base = -WALL_DOWN
    run, rise = S / TREADS, STOREY / TREADS
    prof = [(0.0, base), (0.0, TOP_H)]
    for k in range(TREADS):
        prof.append((k * run, TOP_H + k * rise))
        prof.append((k * run - 0.035, TOP_H + (k + 1) * rise))
        prof.append((k * run, TOP_H + (k + 1) * rise))
    prof += [(S, TOP_H + STOREY), (S, base)]
    bm = bmesh.new()
    a = [bm.verts.new((0.0, y, z)) for (y, z) in prof]
    b = [bm.verts.new((S, y, z)) for (y, z) in prof]
    for k in range(len(prof)):
        m = (k + 1) % len(prof)
        bm.faces.new((a[k], b[k], b[m], a[m]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    lay = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for lp in f.loops:
            # WARNING **A TREAD IS STONE WHATEVER ITS HEIGHT.** It is flat, so the steep test says turf,
            # and turf is exactly what made the stair read as a lifted piece of the ground.
            lp[lay] = (*wall_tone(lp.vert.co.z), 1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


# --- the board, read ---------------------------------------------------------------------------------
NB = {"s": (0, 1), "n": (0, -1), "w": (-1, 0), "e": (1, 0)}
CQ = [[(0, 0), (-1, 0), (0, 1), (-1, 1)], [(0, 0), (1, 0), (0, 1), (1, 1)],
      [(0, 0), (1, 0), (0, -1), (1, -1)], [(0, 0), (-1, 0), (0, -1), (-1, -1)]]


def is_land(px, py):
    return 0 <= px < PW and 0 <= py < PH and PIECES[py][px] == "."


def level_of(px, py):
    if not is_land(px, py):
        return -1
    best = 0
    for dy in range(2):
        for dx in range(2):
            best = max(best, lvl_of(TIERS[py * 2 + dy][px * 2 + dx]))
    return best


def corner_outward(px, py, i):
    """Which way the sea lies from this corner, read off the land pattern around it and nothing else.

    WARNING **Every piece touching the corner gets the same answer**, which is what makes the skirt one
    continuous hem instead of four pieces of one that do not quite meet.
    """
    cx, cy = CORN[i]
    wx, wy = px * S + cx, (PH - 1 - py) * S + cy
    sx = sy = 0.0
    for (dx, dy) in CQ[i]:
        if is_land(px + dx, py + dy):
            continue
        qx = (px + dx) * S + S * 0.5
        qy = (PH - 1 - (py + dy)) * S + S * 0.5
        vx, vy = qx - wx, qy - wy
        L = math.hypot(vx, vy) or 1.0
        sx += vx / L
        sy += vy / L
    L = math.hypot(sx, sy)
    if L < 1e-6:
        return None
    return (sx / L, sy / L)


def starting_builds():
    """**What is already standing when the island opens**, and right now that is one thing: the keep.

    The first house is already built and the player puts up everything else; the run is LOST if it
    burns. It stands on the HIGHEST flat 2x2 of land, and only then on the most central one -- a plateau
    exists to be the place worth holding, and putting the hall anywhere else makes it scenery.

    Tiles are the SIM's row order -- `ROWS` as written, not the reversed copy the mesh is built on.
    """
    hgt, wid = len(ROWS), len(ROWS[0])

    def land(x, y):
        return 0 <= x < wid and 0 <= y < hgt and ROWS[y][x] not in "~H"

    mid_x, mid_y = wid * 0.5, hgt * 0.5
    best, at = None, None
    for y in range(hgt - 1):
        for x in range(wid - 1):
            if not (land(x, y) and land(x + 1, y) and land(x, y + 1) and land(x + 1, y + 1)):
                continue
            lv = {lvl_of(TIERS[y][x]), lvl_of(TIERS[y][x + 1]),
                  lvl_of(TIERS[y + 1][x]), lvl_of(TIERS[y + 1][x + 1])}
            if len(lv) != 1:
                continue                        # never straddling a step
            d = (x + 1.0 - mid_x) ** 2 + (y + 1.0 - mid_y) ** 2
            key = (-lv.pop(), d)
            if best is None or key < best:
                best, at = key, (x, y)
    if at is None:
        return []
    return [{"kind": "keep", "x": at[0], "y": at[1]}]


# --- the 판, and it is a SHAPE that gets stamped, not a shape cut out of the block ---------------------
# WARNING **THE 판 STOPPED FOLLOWING THE 칸's OUTLINE ON 2026-08-28** (the user, on the game screen:
# 「모양이 저렇게 막 스펙타클할 필요 없이... 외곽 라인에 맞춰줄 필요도 없다. 판도 몇 개 정해 가지고
# 붙이면 될 듯. 레퍼런스 사진처럼 살짝 네모 동그란 느낌으로」). It was an inward offset of the 칸's own
# wobbled edge, so every 판 was a different jagged polygon and the island read as cracked.
# **A handful of rounded squares, stamped**, is what the reference actually shows.
PAD_SIDE = 1.30     # one side of a 판, in metres. A 칸 is 2.0, so this leaves a clear gutter all round
PAD_ROUND = 0.34    # corner radius. WARNING **0 is a square and half the side is a circle** — 「살짝
                    # 네모 동그란」 is neither, and this is the number that says how far along
PAD_ARC = 4         # segments per corner. Four is round enough at play distance and cheap
PAD_H = 0.02        # how proud the 판 stands. **A lip, not a slab** — 「더 얇게 붙어있어도 될 듯」
PAD_VARIANTS = 3    # WARNING **Three, and which one a 칸 gets comes from the 칸's own position hash.**
                    # One shape repeated reads as a printed grid; a shape per 칸 is what was just
                    # thrown out. Three is enough to break the repeat and few enough to stay a set


def pad_outline(cx, cy, k):
    """**One 판's outline** — a rounded square, centred on `(cx, cy)`, variant `k`.

    WARNING **The variants differ in SIZE and CORNER, never in silhouette.** A variant that changed the
    shape would be back to 「every 판 is its own polygon」, which is the thing this replaced.
    """
    side = PAD_SIDE * (1.0 + (k - 1) * 0.06)
    r = PAD_ROUND * (1.0 + (k - 1) * 0.18)
    h = side * 0.5 - r
    out = []
    for i, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        ax, ay = cx + sx * h, cy + sy * h
        a0 = math.atan2(sy, 0.0) if sx * sy else 0.0
        base = {0: 0.0, 1: math.pi * 0.5, 2: math.pi, 3: math.pi * 1.5}[i]
        for t in range(PAD_ARC + 1):
            a = base + math.pi * 0.5 * t / PAD_ARC
            out.append((ax + math.cos(a) * r, ay + math.sin(a) * r))
    return out


def stamp_the_mats(isl):
    """**Puts one 판 on every 칸 that carries one**, as a rounded-square lip standing `PAD_H` proud.

    WARNING **A stair carries no 판** — it is passed through, not stood on. Odd notches are stairs, and
    that is the same fact that makes a stair the only way up.
    WARNING **The 판 is added to the island's own mesh, not left as its own object.** The game reads one
    terrain file and the 판 is part of the ground, not something laid on it.
    WARNING **Coloured off the height it sits at**, exactly like every other vertex — so the 판 is the
    ground's own tone and only the light on its lip separates it.
    """
    me = isl.data
    bm = bmesh.new()
    bm.from_mesh(me)
    lay = bm.loops.layers.color.verify()
    # WARNING **THE JOIN LEAVES THE ISLAND CARRYING THE FIRST BLOCK'S TRANSFORM**, so a vertex added at
    # a world coordinate lands wherever that offset puts it. Measured 2026-08-28: the 판 came out in the
    # open sea, a whole block-width off the island, and it looked exactly like a row-order mistake.
    # ⇒ Every point below is put through the inverse before it is added.
    to_local = isl.matrix_world.inverted()
    made = 0
    for py in range(PH):
        for px in range(PW):
            L = level_of(px, py)
            if L < 0 or L == 1:
                continue
            z = TOP_H + L * LEVEL_H
            wy = (PH - 1 - py) * S
            cx, cy = px * S + S * 0.5, wy + S * 0.5
            k = int((h2(cx, cy, 11.0) * 0.5 + 0.5) * PAD_VARIANTS) % PAD_VARIANTS
            ring = pad_outline(cx, cy, k)
            top = [bm.verts.new(to_local @ Vector((x, y, z + PAD_H))) for (x, y) in ring]
            bot = [bm.verts.new(to_local @ Vector((x, y, z))) for (x, y) in ring]
            ctr = bm.verts.new(to_local @ Vector((cx, cy, z + PAD_H)))
            n = len(ring)
            faces = []
            for a in range(n):
                b = (a + 1) % n
                faces.append(bm.faces.new((ctr, top[a], top[b])))
                faces.append(bm.faces.new((top[a], bot[a], bot[b], top[b])))
            bmesh.ops.recalc_face_normals(bm, faces=faces)
            for f in faces:
                for lp in f.loops:
                    w = isl.matrix_world @ lp.vert.co
                    lp[lay] = (*ground_tone(z, 0.0, tone_noise(w.x, w.y)), 1.0)
            made += 1
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("판 %d 개를 칸 위에 얹었다 (한 변 %.2f · 모서리 %.2f · 두께 %.2f · 종류 %d)"
          % (made, PAD_SIDE, PAD_ROUND, PAD_H, PAD_VARIANTS))


def build():
    for o in list(bpy.data.objects):
        if o.name == "island" or o.name.startswith("P_"):
            bpy.data.objects.remove(o, do_unlink=True)

    parts, coast = [], []
    # ⚠ **NOT exported any more.** The piece-boundary rectangle is kept only as the yardstick the
    # waterline is measured against at the end of this run.
    grid_coast = []
    for py in range(PH):
        for px in range(PW):
            L = level_of(px, py)
            if L < 0:
                continue
            cs = cl = ""
            lowside = None
            for sd, (dx, dy) in NB.items():
                nl = level_of(px + dx, py + dy)
                if nl < 0:
                    if L == 0:
                        cs += sd
                    else:
                        cl += sd
                    x0, y0 = px * 2, py * 2
                    grid_coast.append({"s": [x0, y0 + 2, x0 + 2, y0 + 2],
                                       "n": [x0, y0, x0 + 2, y0],
                                       "w": [x0, y0, x0, y0 + 2],
                                       "e": [x0 + 2, y0, x0 + 2, y0 + 2]}[sd])
                elif nl < L:
                    cl += sd
                    lowside = sd
            c_out = [corner_outward(px, py, i) if L == 0 else None for i in range(4)]
            # WARNING **The mesh is built on REVERSED rows.** glTF maps Blender +Y to Godot -Z and the
            # game slides the island back by the board height; building rows in order lands it upside
            # down, with every body walking a mirrored island.
            wy = (PH - 1 - py) * S
            if L == 1:
                ob = stair("P_%d_%d" % (px, py))
                th = {"s": 0.0, "e": math.pi / 2, "n": math.pi, "w": -math.pi / 2}[lowside or "w"]
                ob.rotation_euler = (0.0, 0.0, th)
                bpy.context.view_layer.update()
                mnx = mny = 1e9
                for v in ob.data.vertices:
                    w = ob.matrix_world @ v.co
                    mnx = min(mnx, w.x)
                    mny = min(mny, w.y)
                ob.location = (px * S - mnx, wy - mny, 0.0)
            else:
                ob, wsegs = block("P_%d_%d" % (px, py), TOP_H + L * LEVEL_H, cs, cl, c_out,
                                  px * S, wy)
                ob.location = (px * S, wy, 0.0)
                # ⚠⚠ **Rounded HERE, not at the dump.** Two pieces reach a shared corner through
                # different arithmetic and land a few 1e-16 apart; at four decimals -- a tenth of a
                # millimetre -- they weld and the coast comes out as one closed ring. Round later and
                # the closure check below is measuring numbers the game never sees.
                coast += [[round(a[0], 4), round(TH - a[1], 4),
                           round(b[0], 4), round(TH - b[1], 4)] for (a, b) in wsegs]
            parts.append(ob)

    for o in bpy.data.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    isl = bpy.context.active_object
    isl.name = "island"
    isl.data.name = "island_mesh"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # WARNING **This weld is the measurement that says the seams held.** With the seed on the piece
    # instead of the corner it fell by a third and the island opened along every join.
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    isl.data.materials.clear()
    isl.data.materials.append(vertex_mat("island_ground"))
    for p in isl.data.polygons:
        p.use_smooth = False
    # WARNING **Auto smooth by ANGLE.** Flat-shading every face let each tile take its own normal and
    # the shading drew the grid back after the geometry had stopped.
    bpy.context.view_layer.objects.active = isl
    for o in bpy.data.objects:
        o.select_set(o is isl)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(32.0))
    b = isl.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = 0.05, 2
    b.limit_method, b.angle_limit = "ANGLE", math.radians(24.0)
    isl.hide_set(False)

    stamp_the_mats(isl)

    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is isl)
    bpy.context.view_layer.objects.active = isl
    bpy.ops.export_scene.gltf(filepath=OUT_DIR + "/island.glb", export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)

    board = {
        "w": TW,
        "h": TH,
        "rows": list(ROWS),
        "tiers": list(TIERS),
        # WARNING **THE MESH'S REAL WATERLINE, NOT THE TILE GRID** (2026-08-28, the user: 「지금 굴곡에
        # 안 맞춰져 있는 게 보이고」). This used to be four axis-aligned segments per coastal piece --
        # the staircase rectangle the board is written on -- while the mesh beside it had cut corners,
        # a wobble on every one of them and a skirt hung half a tile further out. The sea bakes its
        # distance map from this array and from nothing else, so the water was drawing a rectangle
        # round an island that is not one.
        # ⚠ **Same key, same shape**: a flat `[x0, y0, x1, y1]` in TILE coordinates, order irrelevant,
        # just more of them and no longer axis-aligned. The only reader is `_bake_land_field`.
        # ⚠⚠ **Tile Y is not Blender Y.** The mesh is built on reversed rows, so a world point comes
        # back as `TH - y`; getting this wrong mirrors the coast onto the far side of the island.
        "coast": coast,
        "builds": starting_builds(),
        # WARNING **Empty on purpose** (2026-08-27, the user: 「바위랑 나무는 다 지워주고 집만 남겨」).
        # The scatter is coming back one kind at a time, chosen by hand.
        "props": [],
        "base_h": TOP_H,
        "level_h": LEVEL_H,
    }
    with open(OUT_DIR + "/island.json", "w", encoding="utf-8") as fh:
        json.dump(board, fh, ensure_ascii=False, indent=1)
    # **How far out the waterline actually runs**, measured against the piece boundary the export used
    # until today, so the sea's `WATER_SHORE_OFFSET_TILES` -- which exists only to make up that gap --
    # can be set from a number instead of by eye.
    pts = sorted({(seg[0], seg[1]) for seg in coast} | {(seg[2], seg[3]) for seg in coast})
    out = []
    for (qx, qy) in pts:
        best = 1e9
        for (ax, ay, bx, by) in grid_coast:
            ex, ey = bx - ax, by - ay
            u = max(0.0, min(1.0, ((qx - ax) * ex + (qy - ay) * ey) / (ex * ex + ey * ey)))
            best = min(best, math.hypot(qx - ax - ex * u, qy - ay - ey * u))
        out.append(best)
    print("island %dx%d, %d pieces, %d coast segments, verts %d"
          % (TW, TH, len(parts), len(coast), len(isl.data.vertices)))
    print("waterline: %d points, %.3f..%.3f tiles outside the piece boundary, mean %.3f"
          % (len(pts), min(out), max(out), sum(out) / len(out)))
    # ⚠⚠ **The coast has to CLOSE.** Every point is an end of exactly two segments; anywhere it is an
    # end of one, two pieces worked the same corner out differently and the sea bakes a straight line
    # across the gap. Measured rather than assumed, because the failure is invisible on the mesh.
    deg = {}
    for seg in coast:
        for q in ((seg[0], seg[1]), (seg[2], seg[3])):
            deg[q] = deg.get(q, 0) + 1
    loose = [q for q, d in deg.items() if d != 2]
    print("coast closes: %s (%d points, %d loose)"
          % ("yes" if not loose else "NO", len(deg), len(loose)))


build()
