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
# WARNING **0.20 -> 0.14 ON 2026-08-28** (the user: 「좀더 판판하게 만들줄래 섬을 ... 1층을 조각들을」).
# **The band of rock on show all the way round the island is exactly `TOP_H` minus the water height**,
# so this number IS how far the island sticks up out of the sea.
# WARNING **THE FLOOR UNDER THIS IS `src/look.gd`'s `SEA_Y_TILES`, 0.075.** Go below it and the sea
# closes over the ground bodies walk on. At 0.14 there is 0.065 of a tile left -- about six centimetres
# of rock -- and **the next step down is the last one this island can take without the water moving too.**
TOP_H = 0.14        # the walking surface. The game reads this out of `island.json` as `base_h`
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
# WARNING **WHERE THE GAME'S WATER PLANE ACTUALLY IS, AND IT IS NOT `SEA_Z`** (2026-08-28). `SEA_Z` is
# how far the skirt reaches DOWN and it also anchors the shore colour ramp; the plane the game DRAWS is
# `src/look.gd`'s `SEA_Y_TILES`, which was raised to +0.075 on 「물 높이를 좀 더 올려줄래?」. **The exported
# waterline was still measured at -0.45**, half a tile below where the sea really meets the rock, so the
# white line the sea drew from it stood a third of a tile out to sea all the way round the island. That
# was patched in the game with `WATER_SHORE_OFFSET_TILES`; **this is the repair, and the patch is now 0.**
# WARNING **If `SEA_Y_TILES` moves, THIS moves with it.** Nothing checks that they agree.
SEA_LINE_Z = 0.075

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
# WARNING **0.46 -> 0.75 ON 2026-08-28** (the user: 「그 해얀선에 닿는 칸의 곡선을 그냥 더 완만하게
# 해줘볼래?」). The same drop spread over a longer run is a gentler slope; nothing about the heights moved.
# WARNING **THIS WALKS BACK A LINE THE USER SET THEMSELVES**, and it is said out loud rather than done
# quietly: `CONTEXT.md` records 「완만한 해변은 사용자가 일부러 버렸다」 under 여울, and the land ending in a
# vertical wall is what that decision bought. **This is the user asking to try the other way**, so the
# old line is left standing in the glossary rather than deleted.
SKIRT = 0.75
# WARNING **HOW FAR DOWN THE KNEE SITS, AS A FRACTION OF THE WHOLE DROP** (pulled out of the mesh code
# 2026-08-28, where it was a literal 0.34). **Straight is when it equals `SKIRT_ROLL`**: the knee then
# lands on the line from the top edge to the hem and the shore is a ramp with no bend in it. Below that
# the shoulder carries high and the fall steepens near the water, which is the roll.
# WARNING **0.34 -> 0.50 on the same line as `TOP_H` above** (「해얀선으로 내려가는 곡선도 좀더 줄여주고」)
# -- most of the way to straight, so there is a slope rather than a curve.
SKIRT_KNEE = 0.50
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
# WARNING **HOW MANY POINTS A CUT CORNER IS DRAWN WITH, AND IT USED TO BE TWO** (2026-08-28, the user,
# on a photograph of one: 「각져있지 왜이렇게」). Two points is a straight CUT across the corner, so the
# outline went straight, turned hard, went straight, turned hard again. **The edges were made into arcs
# an hour earlier and the corners between them were left as angles**, which is where the angularity
# moved to. These points ride a quadratic Bezier whose control point is the corner itself, so the cut
# becomes a fillet through the same place the cut was.
# WARNING **The two ENDS of the arc are exactly where the two cut points were**, and those are what the
# neighbouring piece works out from the same shared corner. Everything added is interior to this piece.
CORNER_PTS = 5
# WARNING **HOW MANY POINTS A COASTAL EDGE IS DRAWN WITH, AND IT USED TO BE ONE** (2026-08-28). One
# interior point is a KINK -- the edge runs dead straight, turns once in the middle, and runs dead
# straight again -- so **every stretch of this island's coast was a straight line**, and a foam line
# traced along a straight line reads as a drawn outline whatever the shader does with it. Four rounds of
# shader dials were spent on that.
# WARNING **THIS IS NOT THE WOBBLE THE USER HALVED TWICE.** That was AMPLITUDE, on「윤곽이 굳이 이렇게
# 꼬불꼬불할 필요는 없을 거 같아」and「굴곡도 완화해줘」, and `COAST_WOB` has NOT been touched. This is
# RESOLUTION: the same amplitude spread over three points on an arc instead of piled onto one, so the
# edge curves instead of kinking. **It softens the outline; it does not crinkle it.**
COAST_PTS = 3
# WARNING **The offset is `sin(pi*u)`, so it is ZERO at both corners.** The corners are shared with the
# neighbouring piece and moving them is how every seam opens.
# WARNING **3.0 PUTS THE EFFECTIVE AMPLITUDE BACK ABOVE WHERE THE USER LEFT IT, AND THAT HAS TO BE SAID
# OUT LOUD.** `COAST_WOB` was halved twice on 2026-08-28 (0.28 -> 0.14 -> 0.07) on 「윤곽이 굳이 이렇게
# 꼬불꼬불할 필요는 없을 거 같아」; 0.07 x 3.0 is 0.21, which is three quarters of the value that was
# called too wiggly. **What changed is the SHAPE, not the size**: at one point per edge that amount was
# a single kink in the middle of a straight run, and at three points on a `sin` arc the same amount is a
# curve. ✅ **Measured by eye against 1.0 and against the old kink** (2026-08-28) -- at 1.0 the bow is
# 3.5% of a two-tile edge and cannot be seen at the game's camera at all.
COAST_BOW = 2.0
# How far each point departs from its edge's own arc. WARNING **Small on purpose**: at 1.0 the three
# points move independently and the arc is a crinkle again, which is the thing that was asked to stop.
# WARNING **TAKEN TO 0 ON 2026-08-28** (the user: 「곱선을 더 심플하게 가져가도 될듯」). With any
# jitter each edge is an arc PLUS a wobble on top of it; at 0 the edge is one clean bow and nothing
# else. **The point of the arc was to stop the edge being a straight line, and that is done at 0.**
COAST_JITTER = 0.0
                                   # WARNING **The SPAN narrowed 2026-08-28 with the wobble** — the
                                   # variation is what read as crinkle, and the cut itself is not.

GRASS = (0.760, 0.735, 0.520)
GRASS_HIGH = (0.655, 0.710, 0.450)
# WARNING **Lifted for the GAME, not for the render.** A face turned away from the sun keeps almost no
# brightness, and a value that looks right in Blender comes out near black in the game -- Blender lights
# with a strong key, the game with one sun and an ambient, and the outline pass darkens the edge on top.
# WARNING **THE CLIFF FACE WENT FROM PURPLE TO NEAR-WHITE STONE ON 2026-08-28**, chosen by the user off
# four candidates rendered through the game's own camera (「B가 좋은데?」). It was (0.615, 0.570, 0.660)
# — a dark purple that swallowed the stair standing in front of it, which is what 「계단도 잘 안 돼 있고
# 연결 부분도 이상」 was actually describing: **the stair was there all along and the wall was the same
# colour as it.**
# WARNING **This is the outside answer as well.** Bad North ships crisp near-white vertical cliff faces
# and had to patch its own cross-level readability (1.0.6, Jan 2019: 「Pathways between levels on islands
# are more visible」) — see the research note under `docs/reference/`.
# WARNING **The user saw B and NOT C or D**, which moved the foot darker and dropped the top lip. Those
# two are recorded in the note as rejected-on-sight, not untried.
ROCK = (0.855, 0.845, 0.870)
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
# WARNING **THE STAIR STANDS OUTSIDE THE PLATEAU, ON THE MIDDLE OF ITS WEST WALL** (2026-08-29). Three
# arrangements were tried on screen and this is the one that holds all three claims at once:
#
#  · **cut into the plateau's corner** (until 2026-08-28) — two of its sides were raised, so a body
#    stepped onto the storey from the first tread without climbing (the user: 「계단 옆면으로 오르는게
#    살짝 마음에 안드네?」). Closing those sides then left the storey ABOVE the stair unable to use it:
#    the stair was where it looked and the way down was somewhere else (「계단 방향이랑 내려가는 길이랑
#    다른듯?」)
#  · **plateau lowered over the stair** — that fixed both, and cost the storey a whole 칸 (「블럭이 하나
#    사라졌네?」)
#  · **the lost 칸 returned on the EAST** — it touched the sea diagonally and sealed the 칸 beyond it
#    off from the island: `net_tiers` and `net_islands` both went red, six tiles stranded
#
# ⇒ **The plateau keeps its four 칸 and the stair moves out.** Its east side is the storey; north,
# south and west are floor, and nothing raised stands over it.
for _y in range(6, 8):
    for _x in range(4, 6):
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
    """Where one shore column crosses the GAME'S water plane, walked from the land downward.

    `prof` is the column top-down as `(x, y, z)`: the land's own outer point, the skirt's knee, the
    skirt's hem. **This is the point the sea has to measure from** -- not the piece boundary, which is
    half a tile inside the rock, and not the hem, which sits under the water.

    WARNING **It never returns None and it never guesses.** A shore column that does not reach the
    water is a hole in the exported coast, and the sea would draw a straight line through it. Nothing
    in this repo pretends to work, so it raises instead.
    """
    for i in range(len(prof) - 1):
        (x0, y0, z0), (x1, y1, z1) = prof[i], prof[i + 1]
        if z0 >= SEA_LINE_Z >= z1 and z0 > z1:
            t = (z0 - SEA_LINE_Z) / (z0 - z1)
            return (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
    raise RuntimeError("a shore column never crosses the water at z=%.3f: %r" % (SEA_LINE_Z, prof))


def block(name, z_top, coast_sides, cliff_sides, corner_out, wx, wy):
    """One 2x2 piece.

    `coast_sides` are the sides facing the sea, `cliff_sides` the sides facing lower land -- and a
    RAISED block facing the sea is a cliff, not a coast. Dropping its edge to the waterline is a ground
    rule; applied one storey up it ramped from the plateau straight into the water and the plateau's
    edge came out as a sawtooth.
    """
    # WARNING **A CORNER IS CUT ONLY WHERE THE SEA CAN FILL IT** (2026-08-28, the user: 「1층과 2층의
    # 경계에 빈틈이 있는것도 마음에 안들어 ... 빈틈없이 이어지게 해줘」).
    #
    # This read `set(coast_sides) | set(cliff_sides)`, so the chamfer ran at CLIFF corners too. **At a
    # sea corner the cut-away wedge is filled by water and nothing is missing; at a cliff corner there
    # is nothing to fill it** — the block below has its own corner cut away at the same spot, so the two
    # pieces pull apart and the sea shows straight through the island. That hole is what 티켓 20's
    # 「1층과 2층의 경계에서 몸이 사라진다」 was measured on, photographed and colour-sampled.
    #
    # WARNING **A cliff corner is now square, and that is the trade.** Rounding it needs both blocks to
    # compute the SAME curve and emit it together (티켓 18 makes the same point about inward corners);
    # a square corner that closes is worth more than a round one that leaks.
    # WARNING **`rim` and the skirt still read `cliff_sides`** — what changed is only whether the corner
    # is cut, not what the wall below it looks like.
    openS = set(coast_sides)
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
            ends = []
            for (tx, ty, d, s_own) in ((px, py, a, prev_s), (nx, ny, b, this_s)):
                dx, dy = tx - cx, ty - cy
                L = math.hypot(dx, dy)
                ends.append(((kx + dx / L * d, ky + dy / L * d),
                             OUTW[s_own] if s_own in coast_sides else at_corner))
            (p0, sk0), (p1, sk1) = ends
            for j in range(CORNER_PTS):
                u = j / float(CORNER_PTS - 1)
                m = 1.0 - u
                # Quadratic Bezier, control point the corner: at u 0 and 1 this IS the old cut point.
                ring.append((m * m * p0[0] + 2.0 * m * u * kx + u * u * p1[0],
                             m * m * p0[1] + 2.0 * m * u * ky + u * u * p1[1]))
                rim.append(this_s in cliff_sides or prev_s in cliff_sides)
                # The skirt's outward direction turns with the arc. A corner with no shore on either
                # side has None at both ends and keeps None the whole way round.
                if sk0 is None and sk1 is None:
                    sk.append(None)
                elif sk0 is None:
                    sk.append(sk1)
                elif sk1 is None:
                    sk.append(sk0)
                else:
                    vx, vy = sk0[0] * m + sk1[0] * u, sk0[1] * m + sk1[1] * u
                    vl = math.hypot(vx, vy) or 1.0
                    sk.append((vx / vl, vy / vl))
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
            # WARNING **AN ARC, NOT A KINK.** One offset point in the middle of a straight edge is a
            # triangle: the edge leaves the corner dead straight, turns once, and runs dead straight to
            # the next corner. `COAST_PTS` points weighted by `sin(pi*u)` is a bow instead. The whole
            # edge shares ONE sign -- drawn from the edge's own midpoint -- so it leans one way as a
            # stretch of coast rather than each point wandering off on its own.
            bow = h2(wx + mx, wy + my, 6.0) * COAST_WOB * COAST_BOW
            for j in range(1, COAST_PTS + 1):
                u = j / float(COAST_PTS + 1)
                ex_, ey_ = cx + (nx - cx) * u, cy + (ny - cy) * u
                # Zero at both ends, so the shared corners do not move and the seams hold.
                arc = math.sin(math.pi * u)
                o = arc * (bow + h2(wx + ex_, wy + ey_, 6.0) * COAST_WOB * COAST_JITTER)
                t = arc * h2(wx + ex_, wy + ey_, 5.0) * COAST_WOB * 0.35
                ring.append((ex_ + ax * t + ox * o, ey_ + ay * t + oy * o))
                sk.append((ox, oy))
                rim.append(this_s in cliff_sides)
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
                                      z_top - (z_top - zr) * SKIRT_KNEE)))
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
# WARNING **THE STAIR'S SIDES ARE WALLED** (2026-08-29, the user: 「뭔가 계단 옆으로 그냥 떨어지는거
# 막아야하고」). The RULE has refused a sideways step onto or off a stair since 2026-08-28
# (`Grid._stair_face_open`), but at the mouth the staircase is barely a notch above the floor beside
# it — **the picture read as wide open while the rule said closed**, which is the disagreement this
# closes from the other end.
# WARNING **Inside the tread, not outside it.** A rail hung outside the 칸 would overlap the piece next
# door and cut into whatever stands there.
STAIR_RAIL_W = 0.13   # how far in from each edge the rail eats, in metres
STAIR_RAIL_H = 0.20   # how far it stands above the tread it sits on. **A kerb, not a banister** — the
                      # camera looks down, and anything taller hides the treads it is meant to frame


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

    # The two rails: the same profile again, raised, on a narrow strip at each edge. **Built from the
    # tread profile rather than from a straight slope**, so a rail sits on its own step and the flight
    # still reads as steps from the side.
    for x0, x1 in ((0.0, STAIR_RAIL_W), (S - STAIR_RAIL_W, S)):
        top = [(y, z + STAIR_RAIL_H) for (y, z) in prof]
        ra = [bm.verts.new((x0, y, z)) for (y, z) in top]
        rb = [bm.verts.new((x1, y, z)) for (y, z) in top]
        for k in range(len(top)):
            m = (k + 1) % len(top)
            bm.faces.new((ra[k], rb[k], rb[m], ra[m]))
        bm.faces.new(list(reversed(ra)))
        bm.faces.new(rb)

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


# --- what a 판 says, and the two things it has to say ------------------------------------------------
# WARNING **A 판 USED TO SAY ONLY 「you may STAND here」 AND THAT IS WHAT WAS AMBIGUOUS** (2026-08-28, the
# user, on the game screen: 「조각이 이 층 조각이 조금 애매한 거 그 판정이 애매해 ... 걸쳐져 있다 못 가는
# 부분이 확실히 되는데 그런 게 좀 안 돼 있는데」). A low 판 and a high 판 sat side by side with a wall
# between them and nothing on screen said so: the gap between two 판 that CONNECT looked exactly like
# the gap between two that do not.
# ⇒ **A 판 now carries both**: the pad says 「stand」, and a BRIDGE between two pads says 「go」.
PAD_BRIDGE_W = 0.34   # the bridge width, in metres. WARNING **Narrower than the pad own side**, or the
                      # board reads as one poured slab and the 칸 stop being 칸
# WARNING **`PAD_STAIR_SIDE` AND `PAD_STAIR_LONG` STOOD HERE AND BOTH ARE DELETED** (2026-08-28). They
# sized a narrow bar drawn on the stair 칸 for one round; the user took it back on sight (「계단에 왜
# 그게 생겼지? 판이?」) and kept the bridges instead (「경로선이 보이는건 좋은데」). **A stair is passed
# THROUGH, not stood on**, which is what 2026-08-27's 「계단에는 칸을 안만들어야하는데」 already said.


def climb_open(a_level, b_level):
    """**Whether a body may cross between two 칸 at these levels** - the rule `Grid.can_step` keeps.

    WARNING **THE NUMBER 1 IS `Rules.MAX_CLIMB_LEVELS` AND IT LIVES IN `rules.gd`.** Blender cannot read
    that file, so the two agree by this comment and by `net_tiers` measuring the game own half. **If the
    climb rule ever changes, this is the second place.**
    WARNING A level below 0 is water or a hole: nothing crosses to it.
    """
    if a_level < 0 or b_level < 0:
        return False
    return abs(a_level - b_level) <= 1


def stamp_the_mats(isl):
    """**Builds the 판 as an object of its OWN** - one pad per walkable 칸, plus a bridge wherever two
    neighbouring 칸 may actually be crossed between.

    WARNING **A STAIR CARRIES NO PAD** (2026-08-27, the user: 「계단에는 칸을 안만들어야하는데」). It
    was given one for a single round on 2026-08-28 and taken straight back out. **What says a stair is
    a door is the BRIDGES running into it** - the sloped strips from the floor below and the storey
    above - not a pad pretending it is somewhere to stand.

    WARNING **IT USED TO ADD THE 판 STRAIGHT INTO THE ISLAND OWN MESH AND THAT IS REVERSED**
    (2026-08-28, the user: 「마우스올리면 호버되도록해주고 특정버튼 눌러야 그 뜨게해줘 판이」). Baked into
    the ground the 판 could be neither hidden nor lit one at a time - the game had no node to touch.

    WARNING **EVERY 판 CARRIES ITS 칸 INDEX IN ITS UV**, as `u = py * PW + px`, `v = 0`. That is the same
    number `field_view._wash_cells` computes for a tile, so the shader lights exactly the 칸 the cursor
    is on. **Both sides derive it from PW; a hand-copied width here would light the wrong 칸.**
    WARNING **A BRIDGE CARRIES BOTH 칸 INDICES** - `u` is the 칸 it was written from, `v` is the
    neighbour. The shader lights on EITHER, so the way up is visible from the bottom and the way down
    from the top. A single index would light a bridge from one end only, and which end would be an
    accident of the loop order.

    WARNING **Vertex colour is the ground own tone, exactly as before.** The shader tints from there
    rather than inventing a colour, so a lit 판 still reads as the ground it is standing on.
    """
    me = bpy.data.meshes.new("pads_mesh")
    bm = bmesh.new()
    lay = bm.loops.layers.color.new("Col")
    uvl = bm.loops.layers.uv.new("UVMap")
    # WARNING **THE ISLAND CARRIES THE FIRST BLOCK TRANSFORM AFTER THE JOIN**, so a vertex added at a
    # world coordinate lands wherever that offset puts it. Measured 2026-08-28: the 판 came out in the
    # open sea, a whole block-width off the island, and it looked exactly like a row-order mistake.
    to_local = isl.matrix_world.inverted()

    def top_z(level):
        return TOP_H + level * LEVEL_H + PAD_H

    def paint(faces, z):
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        return faces

    def lay_face(ring, z, cell, cell_b=None):
        """One flat rounded shape with a skirt, at height `z`, keyed to `cell`.

        WARNING **THE UV CARRIES TWO 칸 INDICES, NOT ONE** - `u` and `v`. A pad puts its own index in
        both; a BRIDGE puts the two 칸 it joins. The shader lights a piece when EITHER matches the 칸
        under the cursor, so a bridge lights from both ends: standing on the low 칸 you see the way up,
        standing on the high one you see the way down. **With one index a bridge would only ever light
        from whichever end the exporter happened to pick.**
        """
        top = [bm.verts.new(to_local @ Vector((x, y, z))) for (x, y) in ring]
        bot = [bm.verts.new(to_local @ Vector((x, y, z - PAD_H))) for (x, y) in ring]
        mx = sum(x for (x, _) in ring) / len(ring)
        my = sum(y for (_, y) in ring) / len(ring)
        ctr = bm.verts.new(to_local @ Vector((mx, my, z)))
        n = len(ring)
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((ctr, top[i], top[j])))
            faces.append(bm.faces.new((top[i], bot[i], bot[j], top[j])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        for f in faces:
            for lp in f.loops:
                wv = isl.matrix_world @ lp.vert.co
                lp[lay] = (*ground_tone(z, 0.0, tone_noise(wv.x, wv.y)), 1.0)
                lp[uvl].uv = (float(cell), float(cell if cell_b is None else cell_b))

    def lay_bridge(ax, ay, az, bx, by, bz, cell_a, cell_b):
        """**A sloped strip between two pad centres** - the whole of 「you may go from here to there」.

        WARNING **It is SLOPED and not stepped**, and that is the point at a stair: the strip visibly
        climbs, so a 칸 one notch up reads as reachable and a 칸 two notches up has no strip at all.
        """
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * PAD_BRIDGE_W * 0.5, dx / L * PAD_BRIDGE_W * 0.5
        quad = [(ax + nx, ay + ny, az), (bx + nx, by + ny, bz),
                (bx - nx, by - ny, bz), (ax - nx, ay - ny, az)]
        top = [bm.verts.new(to_local @ Vector(q)) for q in quad]
        bot = [bm.verts.new(to_local @ Vector((q[0], q[1], q[2] - PAD_H))) for q in quad]
        faces = [bm.faces.new(tuple(top))]
        for i in range(4):
            j = (i + 1) % 4
            faces.append(bm.faces.new((top[i], bot[i], bot[j], top[j])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        for f in faces:
            for lp in f.loops:
                wv = isl.matrix_world @ lp.vert.co
                lp[lay] = (*ground_tone(az, 0.0, tone_noise(wv.x, wv.y)), 1.0)
                lp[uvl].uv = (float(cell_a), float(cell_b))

    def centre_of(px, py):
        wy = (PH - 1 - py) * S
        return px * S + S * 0.5, wy + S * 0.5

    pad_n = 0
    bridge_n = 0
    for py in range(PH):
        for px in range(PW):
            L = level_of(px, py)
            if L < 0:
                continue
            cx, cy = centre_of(px, py)
            cell = py * PW + px
            # WARNING **A STAIR CARRIES NO PAD, AND IT GOT ONE FOR ONE ROUND** (2026-08-28). It was
            # given a narrow bar because the only door in and out of the plateau was drawing nothing;
            # the user took it back the moment it was on screen (「계단에 왜 그게 생겼지? 판이?」) and
            # kept the other half (「경로선이 보이는건 좋은데」).
            # WARNING **The BRIDGES are what say the stair is a door**, and they are drawn below
            # whatever this branch does: two sloped strips run into the stair 칸 from the floor below
            # and the storey above, so the way up is visible without the stair pretending to be a
            # place to stand. **That is the original rule restored, not a new one** — 2026-08-27:
            # 「계단에는 칸을 안만들어야하는데」.
            if L != 1:
                k = int((h2(cx, cy, 11.0) * 0.5 + 0.5) * PAD_VARIANTS) % PAD_VARIANTS
                lay_face(pad_outline(cx, cy, k), top_z(L), cell)
                pad_n += 1

            # The bridges. WARNING **East and south only**, so each pair is written once - the west and
            # north neighbours draw their own halves when their turn comes.
            # WARNING **ORTHOGONAL only.** A diagonal crossing needs both shoulders open
            # (`Grid.can_step`), and a strip across a corner would promise a step the sim refuses.
            for (dx, dy) in ((1, 0), (0, 1)):
                nl = level_of(px + dx, py + dy)
                if not climb_open(L, nl):
                    continue
                nx, ny = centre_of(px + dx, py + dy)
                lay_bridge(cx, cy, top_z(L), nx, ny, top_z(nl),
                           cell, (py + dy) * PW + (px + dx))
                bridge_n += 1

    bm.to_mesh(me)
    bm.free()
    me.update()
    for pol in me.polygons:
        pol.use_smooth = False
    pads_obj = bpy.data.objects.new("pads", me)
    pads_obj.matrix_world = isl.matrix_world.copy()
    bpy.context.collection.objects.link(pads_obj)
    me.materials.append(vertex_mat("island_ground"))
    print("pads %d, bridges %d (side %.2f, bridge %.2f, lip %.2f)"
          % (pad_n, bridge_n, PAD_SIDE, PAD_BRIDGE_W, PAD_H))
    return pads_obj


def build():
    for o in list(bpy.data.objects):
        if o.name in ("island", "pads") or o.name.startswith("P_"):
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
            # WARNING **WHICH SIDE OF A STAIR IS ITS MOUTH, AND `Grid.STAIR_MOUTH_ORDER` HAS TO SAY THE
            # SAME THING** (2026-08-28, the user: 「계단 이동할때 뚫는거 같은데」). A corner stair meets
            # the floor below on two sides; the staircase is CUT along whichever one wins here, and the
            # feet climb along whichever one wins there. **They disagreed** — this file kept the last
            # low side the dict happened to yield, `grid.gd` kept the last one ITS loops found — so the
            # stair was drawn climbing west-to-east while a body climbed south-to-north, walking across
            # the treads instead of up them.
            # WARNING **The order is arbitrary; that it is the SAME order in both files is not.**
            for sd in ("w", "e", "n", "s"):
                dx, dy = NB[sd]
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
                    # WARNING **FIRST wins, not last** — the order above is the priority, so an
                    # assignment here would make the last side beat the first and undo the pairing.
                    if lowside is None:
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

    pads = stamp_the_mats(isl)

    os.makedirs(OUT_DIR, exist_ok=True)
    # ⚠⚠ **BOTH objects are selected and both go into the one GLB.** The game reads a single terrain
    # file and finds the 판 inside it by NAME (`pads`) — a second file would be a second thing to keep
    # in step, and the two have to agree about every height they sit on.
    for o in bpy.data.objects:
        o.select_set(o is isl or o is pads)
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
