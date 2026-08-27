# Builds the WHOLE island out of pieces in Blender and renders it on real water.
#
# ⚠⚠ **Read `docs/plan/tickets/01-what-one-piece-is.md` first.**
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
import io
import bmesh
import bpy
import math

OUT = r"C:/Users/djgnf/Desktop/godot_games/tockbon/tools/blender/island_build.png"

# The island. ⚠⚠ **THE WHOLE OUTER RING IS HARBOUR (`H`), and that is a decision** (2026-08-26, the
# user: ***"바다랑 만나는 모든 접점에서 상대가 올 수 있었으면 좋겠거든"***). Boats sail FROM a harbour,
# so three harbours on the south edge meant every beast landed on the south shore and the other three
# sides were decoration. A harbour on every border tile makes the whole coastline a place they can come
# from. ⚠ **The landing rule itself was already open** — `grid.gd` refuses only cliff and inland — so
# this is the one edit that was needed.
#
# ⚠ **No beast stands on it.** The garrison letters (`W`/`B`/`C`/`L`) were cleared
# 2026-08-26 by the user: the beasts arrive BY BOAT now, so a body already standing on the ground is a
# leftover of the direction where the player landed and fought a garrison. The letters still parse --
# `islands.gd` keeps reading them -- so a wave can place one later without touching this legend.
# ⚠⚠ **This grid is the SOURCE, not a copy of one** — see `export()` at the foot of this file:
# the game reads the mesh and the board this script writes, and owns neither. `~`/`H` are water, the rest land.
# ⚠⚠ **THE ISLAND IS DRAWN ON A 2x2 GRID, NOT A 1x1 ONE** (2026-08-26). 티켓 01, rule 1: a piece
# that is one tile makes the grid show no matter how it is carved, and that was the cause of six
# rejected renders in a row. **`PIECES` below is the real drawing surface** — one character is one 2x2
# piece — and `ROWS` is expanded from it. An outline that can only turn on even tiles is an outline
# whose steps read as SHAPE rather than as squares.
#
#   `.` land  ·  `~` open water
#
# ⚠ **The border ring must stay water**: the tiles around the edge are harbours, and a boat sails
# from there.
PIECES = [
    "~~~~~~~~~~",
    "~~~....~~~",
    "~~......~~",
    "~........~",
    "~........~",
    "~~......~~",
    "~~~..~~~~~",
    "~~~~~~~~~~",
]

# ⚠⚠ **THE SECOND LEVEL, drawn on the SAME 2x2 piece grid** (2026-08-26). A raised ground drawn tile by
# tile would put the grid straight back where the coastline just stopped showing it — the plateau has to
# turn on the same even boundaries the coast does.
#
#   `.` ground level  ·  `1` the stair  ·  `2` the plateau  ·  `/` an older spelling of the stair
#
# ⚠ **The stair must touch both**, or it leads nowhere. `grid.gd` reads a digit as its own level and
# `/` as level 1, and a stair is simply the ODD level between two floors.
# ⚠ **No separate mesh is needed for the raised ground.** `build_island` already walls any edge where a
# tile meets a LOWER one, which is the same code that walls the coast.
# ⚠⚠ **THE LEVEL BOARD IS WRITTEN IN TILES, NOT IN 2x2 PIECES** (2026-08-26). `PIECES` above stays on
# the piece grid because it draws the island's OUTLINE, and 티켓 01's first rule is about the outline:
# a coast that can only turn on even tiles reads as shape rather than as squares. **A level boundary is
# not the outline.** It is inland, it is walked on, and forcing it onto the piece grid is what made the
# stair a single 2x2 ledge — two tiles deep, one step tall, and invisible as a way up.
#
# **A digit is its own level.** `.` is 0. ⚠⚠ **The board below stands the plateau at 2 and the stair at
# 1** — one storey up, entered by a single tread. A three-tread stair to a plateau at 4 was written into
# these comments once and **never reached the board**; `HIGH` is what runs, so the board is what is true.
# A third floor is levels 3 and 4 and needs no rule change, but nothing has been raised that high yet.
#
# ⚠ **The plateau still turns on even tiles** — that is a choice made here, not a rule the board
# enforces, and it keeps the raised ground reading as a piece of the island rather than as a patch.
# ⚠ **The plateau never reaches the coast.** A rim of low ground all the way round is what lets the
# raised part be seen AS raised.
#
# ⚠⚠ **THE STAIR IS ONE 2x2 BLOCK, CUT INTO THE PLATEAU** (2026-08-27, the user: 「계단이라는 블록이
# 있어야할듯」 · 「하나의 블럭에 개단이 포한이 왜 안되어있냐고」). It is **two tiles wide across the
# climb and two tiles long along it**, and `stair_block` below builds the whole of it in ONE call —
# not a shape smeared across the per-tile loop. **That single call is the seam a hand-carved file
# replaces later**, which is the reason it is one function and not four faces per tile.
# ⚠ **The width costs nothing in rules.** A run still spans exactly one storey, and every tile of one
# step carries the same height, so `Grid.surface_h` reads the same index it always did.
#
# ⚠⚠ **A BLOCK STANDING OUTSIDE THE PLATEAU IS THE THING THAT FAILED, AND CUTTING IT IN IS WHAT FIXED
# IT.** The first 2x2 stair stood against the plateau's west edge with open ground on three sides, and
# **a body could climb onto it from fourteen places on all four sides** — counted, not guessed. The
# user: 「어디서든지 저 계단으로 점프할 수 있다라는 게 좀 불만이거든」, and 「저기 오는데 막 저기
# 어디서든지 올라올 수 있으면 재미가 없을 거 같아? 그래서 계단을 만드는 거로」.
#
# **Cut into the plateau, the block's other three faces are the storey above**, which is two notches
# from the ground and therefore unclimbable. **The mouth is the one face left**, and the count of ways
# on is what it is because of that and not because of a rule.
#
# ⚠⚠ **IT IS TWO TILES LONG, WHICH IS ABOUT THE ANGLE AND NOTHING ELSE** (2026-08-27, the user:
# 「계단 조금 더 늘리고」). A storey is one tile tall, so a one-tile stair climbs at **45°** — steeper
# than a real staircase, which is 30 to 37. **Two tiles of run against one tile of rise is 26.6°**, and
# each tread then measures 0.33 deep by 0.17 high. ⚠ **Lengthening the run does NOT make the stair
# climb further** — the run still spans exactly one storey and each tile carries its share.
# ⚠ **This needs no rule change at all**: `MAX_CLIMB_LEVELS` is untouched and the geometry does the
# refusing. The measured table lives in 티켓 06.
# ⚠ **The stair breaks 「the plateau turns on even tiles」 on purpose.** That choice is about the coast
# reading as shape rather than as squares; the stair is inland and has nothing to do with the outline.
HIGH = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "........222222......",
    "........222222......",
    "........112222......",
    "........112222......",
    "........222222......",
    "........222222......",
    "....................",
    "....................",
    "....................",
    "....................",
]

TIER_CHARS = "./0123456789"
TIER_LEVELS = [0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


def lvl_of(c):
    """The level a board character stands for. **The same table `grid.gd` reads, in the same order.**"""
    k = TIER_CHARS.find(c)
    return TIER_LEVELS[k] if k >= 0 else 0


PIECE = 2           # tiles per piece side


def _expand():
    """`PIECES` → the tile grid the game reads. **One place, so the two cannot drift.**

    Every border tile becomes a harbour (`H`): boats sail from harbours, and the user asked for the
    beasts to be able to come from every point where the sea meets the land.
    """
    rows = []
    for pr in PIECES:
        line = "".join((("." if c == "." else "~") * PIECE) for c in pr)
        for _ in range(PIECE):
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
    """`HIGH` as the board the game walks on. **No expansion — it is already in tiles.**

    ⚠ A tile that is water in `PIECES` is ground level whatever `HIGH` says: the level board has to be
    the same shape as the row board, and nothing stands on water.
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


ROWS = _expand()
# ⚠⚠ **TWO LEVELS AGAIN** (2026-08-26 evening, the user: 「이제 자연스러운 2층을 만들어보고 거기에
# 건물을 올려보자」). One level was the right thing while the flat island was being judged — the user's
# own 「정말 단순해도 돼, 층이 없어도 돼」 — and the flat island passed, so the level comes back.
TIERS = _tiers()

# --- the numbers the shape is made of -------------------------------------------------------------
TOP_H = 0.26        # the walking surface, above the waterline. ⚠⚠ **This number IS the step the island
                    # stands on** (2026-08-26, the user: 「왜케 섬이 이렇게 한 칸 올라가 있지?」 —
                    # yes, it was, at 0.62). **The game reads this out of `island.json` as `base_h`**, so
                    # lowering it here lowers where every body stands and nothing else has to agree.
LEVEL_H = 0.5       # ⚠⚠ **HALF A TILE, AND THIS IS THE DEFINITION** (2026-08-26, the user: 「한 칸 한
                    # 칸을 그냥 쉽게 올라가는 거로 하자」). Until now the height of a storey was never
                    # written down anywhere: the ground stood 0.26 above the water, the plateau stood
                    # 1.05 above that, and the stair split the gap three ways — **two storeys spelled in
                    # four notches**, with nothing saying which of them was「a floor」.
                    #
                    #   **一 notch = half a tile. A STOREY IS TWO NOTCHES; A STAIR IS ONE.**
                    #
                    #     ground 0 · stair 1 · second floor 2 · stair 3 · third floor 4
                    #
                    # ⚠⚠ **The battle rules already assumed exactly this** — `grid.gd` calls an ODD level
                    # a stair tread, and a body may cross a gap of one notch and no more. So ground(0)
                    # to second floor(2) is refused and the stair(1) between them is the only door, with
                    # no rule change at all. **A third floor is levels 3 and 4 and costs nothing.**
                    # ⚠ **Two storeys is the maximum for now** — the user: 「일단 이 층까지를 최대로 하고
                    # 삼 층은 추후에 추가하자」.
                    #
                    # ⚠ **The stair's TREADS are drawn inside the stair PIECE, not spelled on the board.**
                    # Cutting the walked notches finer to make treads was the wrong lever and cost a
                    # round: it put twelve creases down one wall and the island read as a stack of
                    # pancakes from a low angle.
CUT = 0.42          # how far a rounded coastal corner is pulled IN along its outward diagonal
BULGE = 0.22        # how far a headland corner is pushed OUT. ⚠ **Not named OUT** — that name is
                    # already the render path at the top of this file, and shadowing it made Blender try
                    # to render to the number 0.22.
STEP_CUT = 0.20     # the same for a corner of the PLATEAU, and deliberately about half. ⚠⚠ **This edge
                    # is walked on**: the coast can be pulled a whole `CUT` in because nothing stands
                    # there, but the plateau's rim carries bodies, and every centimetre the drawn edge
                    # moves away from the tile edge is a centimetre a body stands over nothing.
STEP_BULGE = 0.12   # and how far one is pushed out.
WALL_STEPS = 1      # ⚠⚠ **ONE crease per LEVEL, and three was a disaster.** `_cliff` cuts
                    # `(l - nl) * WALL_STEPS` bands, so when the level unit halved and the plateau went
                    # from level 2 to level 4, three bands per level became **twelve bands down one
                    # wall** — from the side the island read as a stack of pancakes. The Bad North talk
                    # is explicit and it is the opposite of what three bands did: **cracks go on the
                    # edges, not down the middle of a cliff face.** One crease per level puts the break
                    # exactly where the ground already steps, and the roughness below moves it off that
                    # line so it is not a ruled stripe.
                    # ⚠⚠ **How many horizontal bands a level wall is cut into** (2026-08-26, the user:
                    # 「절벽 벽면이 너무 반듯함 ... 배드노스를 위주로 확인해봐」). A wall was ONE quad —
                    # four vertices, two of them at the top and two at the bottom — so there was nowhere
                    # for a bump to live and nowhere for a colour to change. 티켓 01 already carried the
                    # rule from the Bad North talk: **detail lives where faces MEET, not on faces**, and
                    # the talk is explicit that even the cracks go on the edges rather than down the
                    # middle of a cliff face. Cutting the wall into bands MAKES those edges: three bands
                    # give two new horizontal creases per wall, and a crease that is pushed in or out is
                    # a silhouette break, not a texture.
WALL_ROUGH = 0.105  # ⚠ How far a band's crease is pushed in or out, from the corner's own position. Same
                    # trick the coastline uses, at a fifth the size — **this face is right beside ground
                    # that bodies stand on**, and the wall may not wander far from the tile edge.
WALL_DRAFT = 0.05   # how far the wall's FOOT sits outside its top edge. ⚠⚠ **This is not a beach.**
                    # 티켓 01 rule 2: a wall at exactly 90 degrees repeats visibly when tiles are stacked;
                    # leaning it a few degrees breaks the repeat without a single piece of clutter.
WALL_DOWN = 0.62    # how far the wall carries on below the waterline. Enough that no angle sees under
                    # the island; the sea is opaque, so nothing below this is ever looked at.
WATERLINE = 0.02    # the water's own level. ⚠⚠ **A coastal corner sits HERE** — that is what joins the
                    # land to the sea (2026-08-26, the user: 「바다랑 땅이 바로 되는 거」).

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
                # ⚠ **The same legend `grid.gd` reads, in the same order.** `.` 0 · `/` 1 · `1` 2.
                line.append(lvl_of(TIERS[y][x]))
        out.append(line)
    return out


EDGE_TOPS = set()   # ⚠⚠ **Every ground vertex that stands on a level boundary** (2026-08-26, the user:
                    # 「이 절벽 부분에 있는 색이 위에 있는 거로 쪼금 쪼금 넘어가야 되는 거예요 ... 살짝
                    # 낭떠러지처럼」). Filled while the surface is built, read by `_paint`. **The earth
                    # of the cliff climbs a little way onto the ground above it**, the way the turf
                    # breaks and the bare soil shows at a drop. Without it the top is flat green right
                    # to the edge and the wall reads as a painted band under a lawn.
                    # ⚠ **This is a vertex SET, not a tile test.** Colour that lands on a tile boundary
                    # redraws the grid (티켓 01, the material row); colour that lands on a shared corner
                    # cannot, because both tiles use the same corner.

STAIR_TOPS = set()  # ⚠⚠ **Every vertex of a stair's treads and risers** (2026-08-27). Filled while the
                    # stair is built, read by `_paint` to give the whole stair the CLIFF's stone.
                    # **A stair is a way cut through rock, so it is made of rock** — and until this
                    # existed the treads came out the same colour as the ground in front of them, which
                    # is what「계단이 땅과 같은 색이라 안 읽힌다」meant. Bad North solves the same problem
                    # the same way: 「the places where you can navigate between the different levels」
                    # get a different surface, not a marker laid on top.
                    # ⚠ **The risers were already stone** — they are steep, and `_paint` reads steepness.
                    # **It is the flat treads that needed telling.**

COAST = []          # the real coastline, in SIM tile coordinates. ⚠⚠ **Filled by `build_island` and
                    # exported.** The sea draws its wash from this, and it has to be the line the mesh
                    # actually ends on — the tile grid stopped being that line the moment coastal
                    # corners started being cut and pushed (2026-08-26, the user: ***"저 임팩트가 면을
                    # 따라서 되는 게 아니라 그냥 네모나게 고정돼 있는 것 같은데"***).


## --- BACK TO CALCULATING THE ISLAND ----------------------------------------------------------------
## WARNING **The piece system was started and then PARKED, 2026-08-26** (the user: 「접고 그냥 게임 한 번
## 보여주자」). `pieces.py` builds ten modules and an assembler in this file placed them; the assembly ran
## and the pieces welded, but walls came out missing on some sides and the result was worse than what it
## replaced. **Half a change of method is the worst place to leave a file**, so the calculating version
## below was restored and the assembler removed.
## WARNING **`pieces.py` is KEPT.** The ten modules are real and the approach is right -- the Bad North
## talk starts from modelled pieces, not formulas. What is not done is the placer. **Whoever picks this
## up: the shapes are already there; the missing part is which side gets which wall.**
## WARNING **Everything else from that day survives here** -- the wider island, the half-tile notch, the
## grey-violet cliff, the stone bleeding onto the lip, the level board written in tiles.


def build_island(bm, lv):
    hgt = len(lv)
    wid = len(lv[0])
    COAST.clear()
    EDGE_TOPS.clear()
    STAIR_TOPS.clear()
    # ⚠⚠ **Y IS FLIPPED HERE, ON PURPOSE.** glTF's Y-up conversion turns Blender's +Y into Godot's -Z,
    # so an island built at y = 0..12 lands at z = -12..0 in the game and every body walks on water.
    # Flipping the row order here is the one place to fix it; doing it with a negative scale in Godot
    # would invert the normals instead.
    lv = [row for row in reversed(lv)]

    def top_of(l):
        return TOP_H + l * LEVEL_H

    def coastal(cx, cy):
        """Whether grid corner (cx, cy) is on the coast — some tile around it is water."""
        for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0)):
            x, y = cx + dx, cy + dy
            if not (0 <= x < wid and 0 <= y < hgt) or lv[y][x] < 0:
                return True
        return False

    def solid_around(cx, cy):
        """How many of the four tiles at this corner are land. 4 = inland, 1 = an outside corner."""
        n = 0
        for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0)):
            x, y = cx + dx, cy + dy
            if 0 <= x < wid and 0 <= y < hgt and lv[y][x] >= 0:
                n += 1
        return n

    def corner_xy(cx, cy):
        """⚠⚠ **WHERE A COASTAL CORNER ACTUALLY SITS, and it is not always on the grid**
        (2026-08-26, the user: ***"어디는 동그랗게 끝나고 또 어디는 또 다르게 끝나고 해야 될 거
        같은데?"***).

        A coastline whose every corner sits exactly on its grid point is a staircase, and a staircase
        reads as a diagram. This moves each coastal corner by an amount decided by **its own position
        and nothing else** — the same corner always gets the same answer, so neighbouring tiles that
        share it stay welded and the surface never splits.

        Three treatments, chosen by a hash of the corner:
          · **cut**   — pulled in along the outward diagonal. With the bevel on top this reads ROUND.
          · **out**   — pushed out a little; the coast bulges.
          · **square**— left alone. ⚠ **Some corners must stay square** or the variety itself becomes
                        a texture, and the island goes back to reading as one repeated thing.
        ⚠ Inland corners are never moved: they are not the silhouette, and moving them would ripple a
        wobble across ground the bodies walk on.
        """
        if not coastal(cx, cy):
            return (float(cx), float(cy))
        k = h(cx * 1.7, cy * 1.7, 31.0)          # -1..1, stable per corner
        n = solid_around(cx, cy)
        if n == 0 or n == 4:
            return (float(cx), float(cy))
        # The outward direction: away from the land around this corner.
        ox = oy = 0.0
        for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0)):
            x, y = cx + dx, cy + dy
            solid = 0 <= x < wid and 0 <= y < hgt and lv[y][x] >= 0
            ox += (-1.0 if solid else 1.0) * (dx + 0.5) * 2.0
            oy += (-1.0 if solid else 1.0) * (dy + 0.5) * 2.0
        m = max((ox * ox + oy * oy) ** 0.5, 1e-6)
        ox, oy = ox / m, oy / m
        if k > 0.30:
            d = -CUT * (0.6 + 0.4 * k)           # in: a rounded end
        elif k < -0.45:
            d = BULGE * (0.6 + 0.4 * -k)           # out: a headland
        else:
            d = 0.0                              # square
        return (float(cx) + ox * d, float(cy) + oy * d)

    def corner(cx, cy, l):
        """The height of a grid corner.

        ⚠⚠ **A CORNER ON THE COAST SITS AT THE WATERLINE** (2026-08-26, the user: 「일단 부드럽게
        이어지는 거 해보자, 지금도 바다랑 너무 벽으로 텀이 있잖아」). The land used to hold its full
        height right to its last vertex, so where it ended a wall stood up out of the sea and the island
        read as a slab dropped on the water.

        ⚠ **This is NOT the old beach coming back, and the difference is the DISTANCE.** That one waded
        a whole tile and more out into the water on a shallow ramp with its own sand colour, and it made
        the island read as clay. This drops the outermost ring of vertices and nothing else: the fall is
        `TOP_H` over one tile — about fifteen degrees — and the wall below it ends up entirely under an
        opaque sea, where nobody ever sees it.

        ⚠ Inland corners are untouched. The ground the bodies walk on stays perfectly flat.
        """
        if l == 0 and coastal(cx, cy):
            return WATERLINE
        return top_of(l)

    cache = {}

    def vert(cx, cy, l):
        key = (cx, cy, l)
        if key not in cache:
            px, py = corner_xy(cx, cy)
            v = bm.verts.new((px, py, corner(cx, cy, l)))
            cache[key] = v
            # The lip of a drop: a corner where the level changes carries the cliff's own stone a little
            # way onto the ground above it -- see `EDGE_EARTH`.
            ls = set()
            for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0)):
                x, y = cx + dx, cy + dy
                if 0 <= x < wid and 0 <= y < hgt and lv[y][x] >= 0:
                    ls.add(lv[y][x])
            if len(ls) > 1:
                EDGE_TOPS.add(v)
        return cache[key]

    def stair_runs():
        """Every connected group of stair tiles as a BLOCK: its uphill axis, how long, how wide.

        ⚠⚠ **A STAIR IS A GROUP, NOT A TILE, AND ASKING A TILE ALONE FAILS.** The first version asked
        each stair tile for one neighbour up and one down. Cut into the plateau, a stair has the storey
        above on THREE sides; strung two tiles long, the middle tile has no higher neighbour at all.
        **The group is the thing with a mouth and a head**, which is also what the user asked for:
        「계단이라는 블록을 하나 만들어서 연결할 수 있도록 할까 저렇게 칸으로 만들지 말고」.

        ⚠ **The direction is read off the geometry and nothing is authored** — the board stays a plain
        `1`. Dwarf Fortress does the same with its ramps.

        Returns `({(x, y): (axis, index, length)}, [block, ...])`. The map is what the tile loop reads —
        which tiles skip their flat top, and which side raises no wall — and the block list is what
        `stair_block` builds from. A group with no mouth, no head, or a shape that is not a filled
        RECTANGLE gets left out of both, and its tiles fall back to a flat top rather than being drawn
        as a staircase to nowhere.

        ⚠⚠ **THE SHAPE TEST IS 「A RECTANGLE」 AND IT USED TO BE 「A SINGLE FILE」** (2026-08-27). The
        first version demanded the along-run indices be exactly `0..n-1`, which a 2-wide block cannot
        satisfy — it gives `0,0,1,1` — so the user's 「계단이라는 블록」 was thrown away as malformed
        and the tiles silently came back as flat plateau. **What actually has to hold is that every
        step of the climb is the same width**, because that is what lets one tread span the block.
        """
        out, blocks = {}, []
        done = set()
        for y in range(hgt):
            for x in range(wid):
                l = lv[y][x]
                if l < 0 or l % 2 == 0 or (x, y) in done:
                    continue
                group, stack, mark = [], [(x, y)], {(x, y)}
                while stack:
                    p = stack.pop()
                    group.append(p)
                    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                        q = (p[0] + dx, p[1] + dy)
                        if q in mark:
                            continue
                        if 0 <= q[0] < wid and 0 <= q[1] < hgt and lv[q[1]][q[0]] == l:
                            mark.add(q)
                            stack.append(q)
                done |= mark
                mouth = head = None
                for p in group:
                    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                        nx, ny = p[0] + dx, p[1] + dy
                        nl = lv[ny][nx] if 0 <= nx < wid and 0 <= ny < hgt else -1
                        if nl == l - 1:
                            mouth = (p, (dx, dy))
                        elif nl == l + 1:
                            head = (p, (dx, dy))
                if mouth is None or head is None:
                    continue
                ax = (-mouth[1][0], -mouth[1][1])
                # ⚠ **The cross axis, 90 degrees counter-clockwise from the climb.** Taking it this way
                # round and not the other is what keeps every face of the block wound outward whatever
                # direction the stair faces: the tread's normal comes out `+z` for all four axes,
                # because `ax × perp` is `(0, 0, ax·ax)` and that is always positive.
                perp = (-ax[1], ax[0])
                m = mouth[0]
                cells = {}
                for p in group:
                    i = (p[0] - m[0]) * ax[0] + (p[1] - m[1]) * ax[1]
                    j = (p[0] - m[0]) * perp[0] + (p[1] - m[1]) * perp[1]
                    cells[p] = (i, j)
                jmin = min(j for _i, j in cells.values())
                cells = {p: (i, j - jmin) for p, (i, j) in cells.items()}
                run_n = max(i for i, _j in cells.values()) + 1
                wide = max(j for _i, j in cells.values()) + 1
                # ⚠ **A block has to be a FILLED rectangle**, or one step of the climb is wider than the
                # one under it and a tread would hang over nothing. Refuse rather than draw it wrong.
                # This also rejects a negative index, which is a group whose mouth is not at its foot.
                if set(cells.values()) != set((i, j) for i in range(run_n) for j in range(wide)):
                    continue
                for p, (i, _j) in cells.items():
                    out[p] = (ax, i, run_n)
                foot = next(p for p, ij in cells.items() if ij == (0, 0))
                blocks.append({
                    "ax": ax,
                    "perp": perp,
                    # The grid corner the block starts from: the foot tile's centre, backed off half a
                    # tile along both axes. Always lands on an integer corner, so the mouth row can come
                    # out of the shared vertex cache and weld to the ground in front.
                    "corner": (int(foot[0] + 0.5 - 0.5 * ax[0] - 0.5 * perp[0]),
                               int(foot[1] + 0.5 - 0.5 * ax[1] - 0.5 * perp[1])),
                    "length": run_n,
                    "width": wide,
                    "level": l,
                })
        return out, blocks

    RUNS, BLOCKS = stair_runs()

    ## ⚠⚠ **TREADS PER TILE, AND THE RATIO IS THE WHOLE POINT.** The stair the user rejected climbed one
    ## notch across TWO tiles — 1 in 4, about 14°, a wheelchair ramp that read as a terraced floor. A run
    ## spans exactly one storey however long it is, so the ANGLE is set by the run's length in tiles:
    ## one tile is 45°, **two tiles is 26.6°**, which is inside the 30-to-37 a real staircase uses.
    ## At three treads per tile over two tiles each tread is 0.33 deep and 0.17 high — about 2 to 1,
    ## against the 1.5 to 1 of a building stair.
    STAIR_TREADS = 3

    def stair_block(blk):
        """⚠⚠ **THE WHOLE STAIR, BUILT BY ONE CALL. THE USER ASKED FOR THIS THREE TIMES**
        (2026-08-27: 「계단이라는 블록이 있어야할듯」 · 「그 블록에 계단만 붙어있는 형식이잖아?」 ·
        「하나의 블럭에 개단이 포한이 왜 안되어있냐고」).

        It used to be `stair_top(x, y, ...)`, called once per tile from inside the tile loop, so「the
        stair」was not a thing anywhere in the file — it was a shape smeared across a loop, and a
        2-wide one grew a wall down its own middle because each tile skirted its own two sides.
        **This takes the block and returns the block.** ⚠ **That is also the seam a hand-carved file
        replaces**: the day the stair comes out of a `.glb` instead of out of arithmetic, this is the
        one function that changes and nothing around it moves.

        ⚠⚠ **The stair spans the WHOLE storey, floor below to floor above** — it is not a shelf at the
        halfway notch. The lowest tread meets the ground at the mouth and the topmost riser arrives
        exactly at the plateau's height on the far edge, so the stair never leads onto a ledge.

        ⚠⚠ **TREAD THEN RISER, AND THE FIRST VERSION GOT THIS WRONG.** Emitting one quad per step from
        the previous corner to the next drew SLOPED PANELS — a ramp in segments, which from above is
        exactly the terraced-floor look this whole change exists to kill. **A stair is a flat tread and
        then a vertical riser**, and the flat/vertical split is also what `_paint` reads to make the
        treads turf and the risers stone.
        """
        ax, perp = blk["ax"], blk["perp"]
        run_n, wide, l = blk["length"], blk["width"], blk["level"]
        ox, oy = blk["corner"]
        floor, ceil_ = top_of(l - 1), top_of(l + 1)

        def at(j, f, z):
            """A fresh vertex `f` tiles up the climb and `j` tile-columns across it."""
            return bm.verts.new((ox + ax[0] * f + perp[0] * j,
                                 oy + ax[1] * f + perp[1] * j, z))

        # ⚠ **The mouth row comes from the shared cache**, so the foot of the stair is welded to the
        # ground tiles in front of it and no crack opens across the doorway. There is one vertex per
        # tile-column boundary and NOT just two at the ends: the ground already has a corner at every
        # one of them, and spanning past one would leave a T-junction across the doorway.
        # ⚠ **The mouth row is NOT stained.** Those are the ground tiles' own shared corners, so
        # colouring them would drag the stone out across the ground in front of the stair.
        prev = [vert(ox + perp[0] * j, oy + perp[1] * j, l - 1) for j in range(wide + 1)]

        # ⚠⚠ **THE CLIMB IS COUNTED OVER THE WHOLE BLOCK, NOT PER TILE.** Same treads in the same
        # places as the per-tile version put them — `STAIR_TREADS` of them for every tile of run — but
        # counted once, so there is no seam vertex in the middle of the flight to come out the wrong
        # colour, which is a bug the per-tile version had to carry a special case for.
        steps = STAIR_TREADS * run_n
        prev_f, z = 0.0, floor
        for k in range(steps):
            f = float(k + 1) * run_n / steps        # tiles travelled along the run
            nz = floor + (ceil_ - floor) * float(k + 1) / steps
            # the tread: flat, at the height walked in on
            tread = [at(j, f, z) for j in range(wide + 1)]
            # the riser: vertical, at the far edge of that tread
            rise = [at(j, f, nz) for j in range(wide + 1)]
            STAIR_TOPS.update(tread)
            STAIR_TOPS.update(rise)
            for j in range(wide):
                # ⚠⚠ **WINDING, AND IT DECIDES WHETHER THE TREAD EXISTS ON SCREEN.** A tread wound the
                # other way is a face whose normal points at the ground, and where back faces are culled
                # it simply is not drawn — the stair looked like an empty notch for a whole round. It
                # also decides the COLOUR: `_paint` calls a face steep when its normal's z is low, so a
                # tread facing down would come out stone instead of turf. `perp` is picked in
                # `stair_runs` so that this order gives `+z` for all four directions a stair can face.
                bm.faces.new((prev[j], tread[j], tread[j + 1], prev[j + 1]))
                bm.faces.new((tread[j], tread[j + 1], rise[j + 1], rise[j]))
            # ⚠⚠ **THE SKIRTS ARE ON THE TWO OUTER EDGES AND NOWHERE ELSE.** The per-tile version put
            # one down each side of every tile, which on a 2-wide block is a WALL STANDING DOWN THE
            # MIDDLE OF THE STAIRCASE. Only `j == 0` and `j == wide` are the outside of the block.
            # ⚠ **Quads and not one profile n-gon**: the n-gon version failed inside a `try/except
            # pass`, which is this repo's named worst case — a face that silently is not there.
            s00 = at(0, prev_f, floor)
            s01 = at(0, f, floor)
            bm.faces.new((s00, s01, tread[0], prev[0]))
            s10 = at(wide, prev_f, floor)
            s11 = at(wide, f, floor)
            bm.faces.new((prev[wide], tread[wide], s11, s10))
            prev_f, z = f, nz
            prev = rise

    for blk in BLOCKS:
        stair_block(blk)

    for y in range(hgt):
        for x in range(wid):
            l = lv[y][x]
            if l < 0:
                continue
            # ⚠ **`st_ax` and NOT `ax`.** The shore branch below already binds `ax, ay = corner_xy(...)`
            # as a float pair, and naming this one `ax` made it a float by the time the mouth test read
            # it — the same shadowing trap `BULGE`'s comment records further up this file.
            run = RUNS.get((x, y))
            st_ax = run[0] if run is not None else None
            # ⚠ **A stair tile has no top of its own** — `stair_block` above already drew the treads
            # over the whole block, and a flat quad here would lie across them.
            if run is None:
                # ⚠ The four corners come from the CORNER, so neighbours on the same level share them
                # and the surface has no seam. Nothing is drawn between two land tiles of one level.
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
                # ⚠⚠ **A STAIR RAISES NO WALL AT ITS MOUTH.** The treads already carry down to the floor
                # below on that side; walling it too would put a face across the doorway and the stair
                # would lead into a box.
                if st_ax is not None and (dx, dy) == (-st_ax[0], -st_ax[1]):
                    continue
                p0, p1 = (
                    ((x, y), (x + 1, y)),
                    ((x + 1, y), (x + 1, y + 1)),
                    ((x + 1, y + 1), (x, y + 1)),
                    ((x, y + 1), (x, y)),
                )[s]
                if nl >= 0:
                    # ⚠⚠ **A WALL BESIDE A STAIR DROPS TO THE FLOOR, NOT TO THE STAIR'S NOTCH.** The
                    # stair spans a whole storey, so its treads near the mouth sit at the floor below;
                    # a wall that stopped at the stair's own level would leave the notch open along its
                    # sides and you would see straight under the plateau.
                    floor_nl = nl - 1 if nl % 2 == 1 else nl
                    _cliff(bm, vert, p0, p1, l, floor_nl, corner)
                else:
                    _shore(bm, p0, p1, (dx, dy), l, corner, corner_xy)
                    # ⚠ **Back to the sim's row order.** The mesh was built on reversed rows so glTF
                    # lands it the right way up; the game's tiles were never reversed. One flip here
                    # is what keeps the sea's shoreline on top of the island's.
                    ax, ay = corner_xy(*p0)
                    bx, by = corner_xy(*p1)
                    COAST.append([ax, hgt - ay, bx, hgt - by])


def _cliff(bm, vert, p0, p1, l, nl, corner):
    """A face between two levels. It is a wall, not a beach — a plateau is climbed by the stair only."""
    t0 = bm.verts.new((p0[0], p0[1], corner(p0[0], p0[1], l)))
    t1 = bm.verts.new((p1[0], p1[1], corner(p1[0], p1[1], l)))
    b0 = bm.verts.new((p0[0], p0[1], corner(p0[0], p0[1], nl)))
    b1 = bm.verts.new((p1[0], p1[1], corner(p1[0], p1[1], nl)))
    bm.faces.new((t1, t0, b0, b1))


def _shore(bm, p0, p1, out, l, corner, corner_xy):
    """Where the land ends: **one wall, straight down.**

    No outward reach, no wobble, no midway break. The two top vertices sit on the tile edge and the two
    below them sit directly under it, so the island's silhouette from above IS the tile outline — which
    is the shape a flat-shaded piece of land needs to read as one object.
    ⚠ **`out` is no longer used and the argument is gone with it.** It existed to push a beach away
    from the island; nothing is pushed anywhere now.
    """
    ax, ay = corner_xy(p0[0], p0[1])
    bx, by = corner_xy(p1[0], p1[1])
    t0 = bm.verts.new((ax, ay, corner(p0[0], p0[1], l)))
    t1 = bm.verts.new((bx, by, corner(p1[0], p1[1], l)))
    ox, oy = out
    b0 = bm.verts.new((ax + ox * WALL_DRAFT, ay + oy * WALL_DRAFT, -WALL_DOWN))
    b1 = bm.verts.new((bx + ox * WALL_DRAFT, by + oy * WALL_DRAFT, -WALL_DOWN))
    bm.faces.new((t1, t0, b0, b1))


GRASS = (0.760, 0.735, 0.520)
## WARNING **THE TOP OF THE PLATEAU HAS TO BE A COLOUR YOU CAN SEE FROM THE GROUND** (2026-08-26). It
## used to be four hundredths brighter than `GRASS`, which is nothing: the raised ground and the ground
## below it were the same tone, so the eye had only the wall to go on and read the whole thing as a box
## sitting ON the sand rather than as sand that had been LIFTED.
## WARNING **Brightness alone did not do it** -- a paler version of the same sand read as the same sand
## with the sun on it. The tone has to move in HUE. And then it had to come DOWN: the first green that
## was actually visible was a lime, and a small patch of high-saturation green on a pale yellow island
## reads as a painted decal. **Turf is DARKER than dry sand, never lighter.**
GRASS_HIGH = (0.655, 0.710, 0.450)
SAND = (0.815, 0.780, 0.590)
## WARNING **STONE, NOT EARTH** (2026-08-26, the user sent a Bad North frame: the cliff there is a dark
## grey-violet and the ground above it is green). A warm brown was chosen back when the wall read as the
## SIDE OF THE GROUND, and the lesson behind that choice still holds: a neutral GREY on a face turned
## away from the sun goes almost black. **A violet-leaning grey is not neutral.** It keeps a hue in shade
## the way the brown did, and it separates from green far harder, because brown sits beside green and
## violet sits opposite it.
## WARNING **Lifted for the GAME, not for the render** (2026-08-26). At 0.455/0.415/0.490 the cliff
## looked right in Blender and came out ALMOST BLACK in the game: Blender lights it with a strong key,
## the game with one sun and an ambient, and the outline pass darkens its edge on top of that. Ticket 01
## already carries the rule -- a face turned away from the sun keeps almost no brightness -- so a colour
## that works on a vertical face has to start much lighter than it looks like it should.
ROCK = (0.615, 0.570, 0.660)
## WARNING **The lip where the top meets the side, and there is a vertex row for it now.** Ticket 01's
## own lesson said a colour given to the top of a wall bleeds down the whole face because **a wall had
## only four vertices**. The pieces carry real rows, so a tone assigned near the top stops there.
WALL_LIP = 0.16         # how far down the lip reaches, as a fraction of ONE notch
WALL_LIP_DARK = 0.26    # how much darker the lip is than the rock
WALL_AO = 0.20          # how much darker the FOOT of a wall is -- the shading Bad North bakes into a
                        # volume, done here as a vertex ramp. It says the wall meets the ground rather
                        # than being pasted onto it.
## WARNING **A LIP, not a border** (2026-08-26, the user: the cliff's colour should eat a LITTLE way onto
## the ground above it, "살짝 낭떠러지처럼"). At 0.55 the plateau's corners are mostly boundary corners
## and the stone ate almost all the turf -- a green smudge in a violet tray.
EDGE_EARTH = 0.30       # how much of the wall's stone bleeds onto the ground at the lip of a drop


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
                # ⚠⚠ **A wall is no longer one flat tone, and it took a vertex row to get there.** The
                # note that used to stand here recorded why the first lip failed: a wall face had FOUR
                # vertices, two at the top and two far below the waterline, so a dark colour on the top
                # pair was interpolated across everything visible and the island's side went black.
                # **That was a fact about the GEOMETRY, not about vertex colour** — see `WALL_STEPS`.
                # Now the tone is read from how far this vertex has fallen below the floor above it:
                # dark right under the top edge (the lip, which is the crease Bad North puts its detail
                # on), light through the middle of the face, dark again at the foot (the contact shade).
                z = lp.vert.co.z
                lv_above = math.ceil((z - TOP_H) / LEVEL_H - 1e-4)
                if lv_above < 0:
                    lv_above = 0
                depth = max(TOP_H + lv_above * LEVEL_H - z, 0.0)
                lip = 1.0 - min(depth / (LEVEL_H * WALL_LIP), 1.0)
                foot = min(depth / (LEVEL_H * 1.05), 1.0)
                k = 1.0 - WALL_AO * foot - WALL_LIP_DARK * lip
                c = tuple(ROCK[i] * k for i in range(3))
            elif lp.vert in STAIR_TOPS:
                # ⚠⚠ **A TREAD IS STONE, WHATEVER ITS HEIGHT.** It is flat, so the steep test above says
                # turf, and turf is exactly what made the stair read as a lifted piece of the ground.
                # The tone is the wall's mid-face value — not its lip and not its foot — so the stair
                # sits in the same material family as the cliff it is cut through.
                c = tuple(ROCK[i] * (1.0 - WALL_AO * 0.35) for i in range(3))
            else:
                z = lp.vert.co.z
                # ⚠⚠ **The turf is the PLATEAU's, and the stair is not the plateau** (2026-08-26).
                # Cutting at half a level was tried while a taller stair was being drawn, and every tread
                # above the halfway mark came out the plateau's green, so the way up read as another patch
                # of high ground rather than as the way to it. **Cut just below the top level instead**:
                # only ground that is actually up there is turf. That still holds for the plateau at 2 and
                # the stair at 1, and it keeps holding if the stair ever gains treads.
                if z > TOP_H + LEVEL_H * 1.4:
                    c = GRASS_HIGH
                else:
                    t = (z - WATERLINE) / max(TOP_H - WATERLINE, 1e-6)
                    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
                    # A short ramp, so the sand is a band along the water and not a wash over the
                    # whole island: fully sand at the line, fully grass a third of the way up.
                    t = min(t * 3.0, 1.0)
                    c = tuple(SAND[i] + (GRASS[i] - SAND[i]) * t for i in range(3))
                # ⚠⚠ **The cliff's earth climbing onto the ground above it.** Only the corners that sit
                # on a level boundary carry it, and vertex colour fades from there to the next corner —
                # so it is a lip of bare soil at the drop, not a stripe along a tile edge.
                if lp.vert in EDGE_TOPS:
                    c = tuple(c[i] + (ROCK[i] - c[i]) * EDGE_EARTH for i in range(3))
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


# --- THE BOARD THE USER PAINTS ---------------------------------------------------------------------
# ⚠⚠ **The island is drawn by MOVING FACES, not by editing letters** (2026-08-27, the user chose this
# over GridMap). `PIECES` and `HIGH` above are now only the SEED: the first bake has no board, so it
# reads them, and then it lays a board over the island it just built. **From the second bake on, the
# board is the source and the letters are ignored.**
#
#   · select faces and raise them — **each 0.5 in Z is one notch, two notches is a storey**
#   · push a face below Z 0 — **that tile becomes sea**
#   · bake again — the island follows the board, and a fresh board is laid over the result
#
# ⚠ **The outline still turns only on 2x2 pieces** — 티켓 01's first rule, and the reason the coast
# stopped reading as squares. The reader ENFORCES it: a piece with any sea tile in it goes to sea whole,
# and it prints how many tiles that cost so a silent trim never happens.
# ⚠ **The board is REBUILT by every bake**, so nothing painted survives a bake it did not feed. That is
# on purpose: a board that disagreed with the island it sits on is the drift this whole file exists to
# prevent.
BOARD_NAME = "ISLAND_BOARD"
BOARD_SEA_Z = -0.5   # where a face has to sit to read as sea. Anything below 0 counts; this is clear of it.
BOARD_LIFT = 0.05    # the whole object floats this far above the island, so the two do not z-fight.


def _board_read():
    """The painted board as `(rows, tiers)`, or `None` when there is no board yet."""
    ob = bpy.data.objects.get(BOARD_NAME)
    if ob is None or ob.type != 'MESH' or len(ob.data.polygons) == 0:
        return None
    cells = {}
    for p in ob.data.polygons:
        c = p.center
        # ⚠⚠ **A face's centre is at `x + 0.5`, so FLOOR IT BARE.** Rounding it — `floor(c.x + 0.5)` —
        # pushes every tile one to the right, and the first run of this reader did exactly that: a 20x16
        # island came back 21x17 and the 2x2 snap then ate 24 tiles that were never wrong.
        cells[(int(math.floor(c.x)), int(math.floor(c.y)))] = c.z
    wid = max(k[0] for k in cells) + 1
    hgt = max(k[1] for k in cells) + 1

    # Blender builds the island with its rows reversed (see `build_island`), so undo that here.
    land = {}
    for (x, r), z in cells.items():
        land[(x, hgt - 1 - r)] = None if z < 0.0 else max(0, int(round((z - TOP_H) / LEVEL_H)))

    dropped = 0
    for py in range(0, hgt - 1, 2):
        for px in range(0, wid - 1, 2):
            piece = [(px + dx, py + dy) for dx in (0, 1) for dy in (0, 1)]
            if any(land.get(t) is None for t in piece):
                for t in piece:
                    if land.get(t) is not None:
                        dropped += 1
                    land[t] = None

    rows, tiers = [], []
    for y in range(hgt):
        r_line, t_line = "", ""
        for x in range(wid):
            lv = land.get((x, y))
            edge = x == 0 or y == 0 or x == wid - 1 or y == hgt - 1
            if lv is None or edge:
                # ⚠ The border ring is always harbour — a boat sails from there, and `_expand` has
                # always done this. Land painted on the rim is trimmed to it.
                r_line += "H" if edge else "~"
                t_line += "."
            else:
                r_line += "."
                # ⚠ A DIGIT, never `/`. Both read as the same level, but `HIGH` above is written in
                # digits and a board that spelled it the other way would show as a diff in every bake.
                t_line += "." if lv == 0 else str(min(lv, 9))
        rows.append(r_line)
        tiers.append(t_line)
    print("board read: %dx%d, %d tiles trimmed to the 2x2 outline" % (wid, hgt, dropped))
    return rows, tiers


def _board_make(rows, tiers):
    """Lay a fresh board over the island that was just built."""
    hgt, wid = len(rows), len(rows[0])
    bm = bmesh.new()
    for y in range(hgt):
        r = hgt - 1 - y
        for x in range(wid):
            sea = rows[y][x] in "~H"
            z = BOARD_SEA_Z if sea else TOP_H + lvl_of(tiers[y][x]) * LEVEL_H
            vs = [bm.verts.new((x + i, r + j, z)) for i, j in ((0, 0), (1, 0), (1, 1), (0, 1))]
            bm.faces.new(vs)
    me = bpy.data.meshes.new(BOARD_NAME)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(BOARD_NAME, me)
    bpy.context.collection.objects.link(ob)
    ob.location = (0.0, 0.0, BOARD_LIFT)
    ob.hide_render = True          # it is a control surface, never a thing that gets rendered
    ob.data.materials.append(mat("board", (0.20, 0.55, 0.95), rough=1.0, alpha=0.25))
    # ⚠ Snap to 0.5 so a dragged face lands on a notch instead of between two.
    ts = bpy.context.scene.tool_settings
    ts.use_snap = True
    ts.snap_elements = {'INCREMENT'}
    return ob


def build():
    global ROWS, TIERS
    # ⚠⚠ **Read the board BEFORE the wipe below deletes it.**
    painted = _board_read()
    if painted is not None:
        ROWS, TIERS = painted

    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    # ⚠⚠ **MATERIALS TOO, and leaving them out cost byte-reproducibility.** Blender never reuses a name:
    # a second `ground` becomes `ground.001`, and the glTF export writes that name into the file. So two
    # bakes of the SAME island differed by exactly one byte — `ground.003` against `ground.007` — and
    # every bake showed up as a diff that meant nothing. Measured 2026-08-27.
    for ma in list(bpy.data.materials):
        bpy.data.materials.remove(ma)

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
    b.width = 0.06
    b.segments = 2
    b.limit_method = 'ANGLE'
    b.angle_limit = math.radians(24.0)

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
    # ⚠ **After the export, so the board is never in the glb** and never in the render above.
    _board_make(ROWS, TIERS)
    print("rendered", OUT, "faces", len(isl.data.polygons))


def _scatter_props():
    """**What is scattered on the ground: trees, rocks, bushes.** As
    `{"kind", "x", "y", "ox", "oy", "yaw", "scale"}` -- the tile, where inside it, which way round, and
    how big.

    WARNING **Decided HERE and never at run time.** The same island always dresses itself the same way,
    so a screenshot is repeatable and a player who leaves and comes back finds the same island. The
    answer comes out of the tile's own position, exactly as the coastline's cut corners do.

    WARNING **Nothing is scattered on a building's footprint, or right against the coast.** The keep
    needs its ground clear to read, and a tree hanging over the water edge fights the one silhouette the
    island has.
    """
    hgt, wid = len(ROWS), len(ROWS[0])
    taken = set()
    for b in _starting_builds():
        w = 2 if b["kind"] == "keep" else 1
        for dy in range(w):
            for dx in range(w):
                taken.add((b["x"] + dx, b["y"] + dy))

    def land(x, y):
        return 0 <= x < wid and 0 <= y < hgt and ROWS[y][x] not in "~H"

    # WARNING **Chosen by RANK, not by threshold.** The first version compared the noise against fixed
    # numbers (`k > 0.72` for a pine, and so on) and the island came out with ten props, no pines and no
    # rocks at all -- the function's real spread never reached the high cuts. Ranking every eligible
    # tile and taking bands off the top gives the same stable, position-derived answer while
    # GUARANTEEING that every kind actually appears.
    eligible = []
    for y in range(hgt):
        for x in range(wid):
            if not land(x, y) or (x, y) in taken:
                continue
            # A tile touching water stays bare: the coast is the island's silhouette, and props on it
            # blur the one line that says where the ground ends.
            if not all(land(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            # ⚠⚠ **And a tile on the EDGE OF A LEVEL stays bare too** (2026-08-26, the user: 「살짝
            # 절벽에서 약간 올라타서 차지하는듯」). A tree standing on the last tile of the plateau hangs
            # its canopy out over the wall below, so the thing that reads is not「a tree on high ground」
            # but「a tree stuck to a cliff」. The coast already had this rule; the level boundary is the
            # same silhouette problem one storey up, and it did not.
            here = lvl_of(TIERS[y][x])
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                nlv = lvl_of(TIERS[ny][nx])
                # ⚠ **Only a tile that is HIGHER than its neighbour is an edge to avoid.** Barring
                # every tile next to a step emptied the island: the plateau is four tiles across, so
                # dropping its rim left a 2x2 the keep already stood on, and on the low ground every
                # tile touching the plateau went too. Standing at the FOOT of a wall is fine — nothing
                # hangs over anything. **Standing on top of one is the problem.**
                if nlv < here:
                    edge = True
                    break
            if edge:
                continue
            eligible.append((h(x * 2.3 + 11.0, y * 2.3 - 7.0, 53.0), x, y))
    eligible.sort(reverse=True)

    n = len(eligible)
    out = []
    for rank, (_k, x, y) in enumerate(eligible):
        share = (rank + 0.5) / max(n, 1)
        if share > 0.62:
            continue                                  # most ground stays open
        j = h(x * 5.1 - 3.0, y * 5.1 + 9.0, 71.0)
        if share < 0.16:
            # WARNING The cut is BELOW zero on purpose. At `j > 0` the five tiles in this band all
            # happened to fall negative and not one pine was planted -- a kind that exists in the file
            # and never appears on the island is the same defect as one that was never modelled.
            kind = "pine" if j > -0.25 else "tree"
        elif share < 0.34:
            kind = "rock" if j > 0.1 else "bush"
        else:
            kind = "stone"
        out.append({
            "kind": kind,
            "x": x, "y": y,
            # Off the tile's centre, so a scatter does not come out on a lattice -- the same mistake in
            # a different coat as painting one colour per tile.
            "ox": round(0.30 * h(x * 7.7, y * 7.7, 17.0), 3),
            "oy": round(0.30 * h(y * 7.7, x * 7.7, 23.0), 3),
            "yaw": round(180.0 * j, 1),
            # ⚠ **Raised from about 1.0 to about 1.7** (2026-08-26, the user: 「더 키워주고」). At life
            # size against a one-metre tile the props read as gravel from the game's distance; the
            # island is looked at from far enough that scenery has to be a little unreal to register.
            "scale": round(1.48 + 0.44 * (1.0 - share), 3),
        })
    return out


def _starting_builds():
    """**What is already standing when the island opens.** Right now that is one thing: the keep.

    The user: the first house is already built and the player puts up everything else, and the run is
    LOST if the island's middle house burns. So the keep is placed here, by the same run that shapes the
    ground, on the 2x2 block of land closest to the middle of the island. Nothing else is placed.

    Tiles are the SIM's row order -- `ROWS` as written, not the reversed copy the mesh is built on.
    """
    hgt, wid = len(ROWS), len(ROWS[0])

    def land(x, y):
        return 0 <= x < wid and 0 <= y < hgt and ROWS[y][x] not in "~H"

    def level(x, y):
        return lvl_of(TIERS[y][x])

    mid_x, mid_y = wid * 0.5, hgt * 0.5
    best, at = None, None
    for y in range(hgt - 1):
        for x in range(wid - 1):
            if not (land(x, y) and land(x + 1, y) and land(x, y + 1) and land(x, y + 1)):
                continue
            if not (land(x + 1, y) and land(x + 1, y + 1)):
                continue
            # ⚠⚠ **The keep stands on the HIGHEST flat block, and only then on the most central one**
            # (2026-08-26, the user: 「자연스러운 2층을 만들어보고 거기에 건물을 올려보자」). A plateau
            # exists to be the place worth holding; putting the hall anywhere else makes it scenery.
            lv = {level(x, y), level(x + 1, y), level(x, y + 1), level(x + 1, y + 1)}
            if len(lv) != 1:
                continue                            # never straddling a step
            d = (x + 1.0 - mid_x) ** 2 + (y + 1.0 - mid_y) ** 2
            key = (-lv.pop(), d)
            if best is None or key < best:
                best, at = key, (x, y)
    if at is None:
        return []
    return [{"kind": "keep", "x": at[0], "y": at[1]}]


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
        o.select_set(o.name == "island")
    bpy.ops.export_scene.gltf(filepath=base + "/island.glb", export_format='GLB',
                              use_selection=True, export_apply=True, export_yup=True)
    for o in bpy.data.objects:
        o.select_set(False)
    board = {
        "w": len(ROWS[0]),
        "h": len(ROWS),
        "rows": list(ROWS),
        "tiers": list(TIERS),
        "coast": COAST,
        "builds": _starting_builds(),
        "props": _scatter_props(),
        "base_h": TOP_H,
        "level_h": LEVEL_H,
    }
    with open(base + "/island.json", "w", encoding="utf-8") as fh:
        json.dump(board, fh, ensure_ascii=False, indent=1)
    print("exported glb + json")


build()
