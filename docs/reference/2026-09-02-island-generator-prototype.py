"""Island generator, v2 — with a faithful mirror of Grid.can_step so the boards are PROVEN walkable
before a line of GDScript is written. The stair rule is the reason this exists: a stair is entered and
left only along its run's axis, and that axis is derived from a mouth chosen by lowest tile index and
then W,E,N,S — so a stair placed on the wrong side of a plateau is a door that opens and never leads
anywhere, with nothing to say so."""

BW, BH = 18, 16
B = 2
W, H = BW * B, BH * B
LAND_BLOCKS = 107
RIM = 2
MAX_CLIMB = 1

TREE_MIN, TREE_MAX = 1, 3
ROCK_MIN, ROCK_MAX = 1, 3
ORE_MIN, ORE_MAX = 1, 2
PLATEAU_MIN, PLATEAU_MAX = 1, 2
STAIR_MIN, STAIR_MAX = 1, 3
PLATEAU_BLOCKS_MIN, PLATEAU_BLOCKS_MAX = 4, 9
KEEP_COAST_BLOCKS = 3
FISH_TILES = 4
TRIES = 40

NEIGH4 = [(-1, 0), (1, 0), (0, -1), (0, 1)]
NEIGH8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
MOUTH_ORDER = [(-1, 0), (1, 0), (0, -1), (0, 1)]   # Grid.STAIR_MOUTH_ORDER: W, E, N, S


class Rng:
    def __init__(self, seed):
        self.state = (seed & 0xFFFFFFFF) or 1

    def next(self):
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state

    def below(self, n):
        return 0 if n <= 1 else self.next() % n

    def between(self, lo, hi):
        return lo + self.below(hi - lo + 1)


def bi(bx, by):
    return by * BW + bx


def n4(b):
    bx, by = b % BW, b // BW
    return [bi(bx + dx, by + dy) for dx, dy in NEIGH4
            if 0 <= bx + dx < BW and 0 <= by + dy < BH]


# == the board, as the game reads it ==================================================================

class Board:
    def __init__(self):
        self.rows = [["~"] * W for _ in range(H)]
        self.lvl = [[0] * W for _ in range(H)]
        self._runs = None

    def passable(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.rows[y][x] in "./"

    def level(self, x, y):
        return self.lvl[y][x] if 0 <= x < W and 0 <= y < H else 0

    def runs(self):
        """Grid._build_runs, mirrored: 4-connected groups of one odd level, a mouth chosen by lowest
        tile index and then W,E,N,S, and a run with no level l+1 neighbour dropped entirely."""
        if self._runs is not None:
            return self._runs
        self._runs = {}
        seen = set()
        for y in range(H):
            for x in range(W):
                l = self.level(x, y)
                if l <= 0 or l % 2 == 0 or (x, y) in seen:
                    continue
                group, stack, mark = [], [(x, y)], {(x, y)}
                while stack:
                    p = stack.pop()
                    group.append(p)
                    for dx, dy in NEIGH4:
                        q = (p[0] + dx, p[1] + dy)
                        if q in mark or not (0 <= q[0] < W and 0 <= q[1] < H):
                            continue
                        if self.level(q[0], q[1]) != l:
                            continue
                        mark.add(q)
                        stack.append(q)
                seen |= mark
                mouth_dir, mouth_tile, has_head = None, 1 << 30, False
                for px, py in group:
                    pt = py * W + px
                    for dx, dy in MOUTH_ORDER:
                        qx, qy = px + dx, py + dy
                        if not (0 <= qx < W and 0 <= qy < H):
                            continue
                        nl = self.level(qx, qy)
                        if nl == l - 1:
                            if pt < mouth_tile:
                                mouth_tile, mouth_dir = pt, (dx, dy)
                        elif nl == l + 1:
                            has_head = True
                if mouth_dir is None or not has_head:
                    continue
                ax = (-mouth_dir[0], -mouth_dir[1])
                for p in group:
                    self._runs[p] = ax
        return self._runs

    def _face_open(self, a, b, dx, dy):
        runs = self.runs()
        fa, fb = runs.get(a), runs.get(b)
        if fa is None and fb is None:
            return True
        if fa is not None and fb is not None:
            return True
        ax = fa if fb is None else fb
        return dx * ax[0] + dy * ax[1] != 0

    def _shoulder_open(self, from_level, sx, sy):
        if not self.passable(sx, sy):
            return False
        return abs(from_level - self.level(sx, sy)) <= MAX_CLIMB

    def can_step(self, a, b):
        (fx, fy), (tx, ty) = a, b
        if not self.passable(tx, ty):
            return False
        fl = self.level(fx, fy)
        if abs(fl - self.level(tx, ty)) > MAX_CLIMB:
            return False
        if not self._face_open(a, b, tx - fx, ty - fy):
            return False
        if fx == tx or fy == ty:
            return True
        return self._shoulder_open(fl, tx, fy) and self._shoulder_open(fl, fx, ty)

    def standable(self, x, y):
        return self.passable(x, y) and self.level(x, y) % 2 == 0

    def one_walking_piece(self):
        """Every 조각 a body may STAND on, joined by the walk the game itself does. A stair is walked
        across and never stood on, so it is crossed here and not counted."""
        start = None
        want = 0
        for y in range(H):
            for x in range(W):
                if self.standable(x, y):
                    want += 1
                    if start is None:
                        start = (x, y)
        if start is None:
            return False, 0, 0
        seen, queue, head = {start}, [start], 0
        while head < len(queue):
            cur = queue[head]
            head += 1
            for dx, dy in NEIGH8:
                nb = (cur[0] + dx, cur[1] + dy)
                if nb in seen or not (0 <= nb[0] < W and 0 <= nb[1] < H):
                    continue
                if not self.can_step(cur, nb):
                    continue
                seen.add(nb)
                queue.append(nb)
        got = sum(1 for p in seen if self.standable(p[0], p[1]))
        return got == want, got, want


# == the generator ====================================================================================

def grow_island(rng):
    land = {bi(BW // 2, BH // 2)}
    frontier = {}

    def offer(b):
        bx, by = b % BW, b // BW
        if bx < RIM or by < RIM or bx >= BW - RIM or by >= BH - RIM or b in land:
            return
        frontier[b] = frontier.get(b, 0) + 1

    for nb in n4(bi(BW // 2, BH // 2)):
        offer(nb)
    while len(land) < LAND_BLOCKS and frontier:
        keys = sorted(frontier)
        total = sum(frontier[k] * frontier[k] for k in keys)
        pick, run, chosen = rng.below(total), 0, keys[-1]
        for k in keys:
            run += frontier[k] * frontier[k]
            if pick < run:
                chosen = k
                break
        del frontier[chosen]
        land.add(chosen)
        for nb in n4(chosen):
            if nb not in land:
                offer(nb)
    return land


def centre(land):
    """Slide the blob so the open sea around it is even. It grows off-centre — the frontier is
    weighted, not symmetric — and an island pressed against one rim gives the boats on that side no
    water to sail in."""
    xs = [b % BW for b in land]
    ys = [b // BW for b in land]
    dx = int((BW - 1 - max(xs) - min(xs)) / 2)   # truncates toward zero, as GDScript's int / does
    dy = int((BH - 1 - max(ys) - min(ys)) / 2)
    return {bi(b % BW + dx, b // BW + dy) for b in land}


def coast_distance(land):
    dist, queue = {}, []
    for b in sorted(land):
        bx, by = b % BW, b // BW
        for dx, dy in NEIGH8:
            nx, ny = bx + dx, by + dy
            if not (0 <= nx < BW and 0 <= ny < BH) or bi(nx, ny) not in land:
                dist[b] = 1
                queue.append(b)
                break
    head = 0
    while head < len(queue):
        cur = queue[head]
        head += 1
        cx, cy = cur % BW, cur // BW
        for dx, dy in NEIGH8:
            nx, ny = cx + dx, cy + dy
            nb = bi(nx, ny)
            if not (0 <= nx < BW and 0 <= ny < BH) or nb not in land or nb in dist:
                continue
            dist[nb] = dist[cur] + 1
            queue.append(nb)
    return dist


def paint(land, plateaus, stairs, blocked):
    b = Board()
    for blk in land:
        bx, by = (blk % BW) * B, (blk // BW) * B
        for dy in range(B):
            for dx in range(B):
                b.rows[by + dy][bx + dx] = "#" if blk in blocked else "."
    for plate in plateaus:
        for blk in plate:
            bx, by = (blk % BW) * B, (blk // BW) * B
            for dy in range(B):
                for dx in range(B):
                    b.lvl[by + dy][bx + dx] = 2
    for blk in stairs:
        bx, by = (blk % BW) * B, (blk // BW) * B
        for dy in range(B):
            for dx in range(B):
                b.lvl[by + dy][bx + dx] = 1
    return b


def generate(seed):
    for attempt in range(TRIES):
        rng = Rng((seed * 2654435761 + attempt * 40503) & 0xFFFFFFFF)
        board = _one(rng, seed)
        if board is not None:
            board["_debug"]["attempt"] = attempt
            return board
    return None


def _one(rng, seed):
    land = centre(grow_island(rng))
    dist = coast_distance(land)
    deep = sorted(b for b in land if dist.get(b, 0) >= KEEP_COAST_BLOCKS)
    if not deep:
        return None

    n_plateau = rng.between(PLATEAU_MIN, PLATEAU_MAX)
    plateaus, taken = [], set()
    for _ in range(n_plateau):
        pool = [b for b in deep if b not in taken]
        if not pool:
            break
        start = pool[rng.below(len(pool))]
        want = rng.between(PLATEAU_BLOCKS_MIN, PLATEAU_BLOCKS_MAX)
        plate, frontier = {start}, [b for b in n4(start) if b in land and b not in taken]
        while len(plate) < want and frontier:
            b = frontier.pop(rng.below(len(frontier)))
            if b in plate or b in taken or b not in land:
                continue
            plate.add(b)
            frontier.extend(nb for nb in n4(b) if nb in land and nb not in taken and nb not in plate)
        plateaus.append(plate)
        taken |= plate
        for b in list(plate):
            taken.update(n4(b))
    if not plateaus:
        return None

    # -- stairs. **A door is only a door if the walk can use it**, so every candidate is painted and
    #    then measured with the game's own step rule rather than reasoned about.
    stairs, serves = [], []
    for plate in plateaus:
        door = _pick_door(rng, land, plateaus, plate, stairs)
        if door is None:
            return None
        stairs.append(door)
        serves.append(plate)
    budget = rng.between(len(plateaus), STAIR_MAX)
    while len(stairs) < budget:
        plate = plateaus[rng.below(len(plateaus))]
        door = _pick_door(rng, land, plateaus, plate, stairs)
        if door is None:
            break
        stairs.append(door)
        serves.append(plate)

    keep_pool = sorted(b for b in plateaus[0] if dist.get(b, 0) >= KEEP_COAST_BLOCKS)
    if not keep_pool:
        return None
    keep = keep_pool[rng.below(len(keep_pool))]

    banned = set(stairs) | {keep}
    for plate in plateaus:
        banned |= plate
    for b in list(banned):
        banned.update(n4(b))

    counts = {"tree": rng.between(TREE_MIN, TREE_MAX),
              "rock": rng.between(ROCK_MIN, ROCK_MAX),
              "ore": rng.between(ORE_MIN, ORE_MAX)}
    blocked, res_of = set(), {}
    for kind in ("ore", "rock", "tree"):
        for _ in range(counts[kind]):
            pool = sorted(b for b in land if b not in banned and b not in blocked)
            placed = False
            while pool and not placed:
                b = pool.pop(rng.below(len(pool)))
                trial = blocked | {b}
                if paint(land, plateaus, stairs, trial).one_walking_piece()[0]:
                    blocked = trial
                    res_of[b] = kind
                    placed = True
            if not placed:
                return None

    board = paint(land, plateaus, stairs, blocked)
    ok, got, want = board.one_walking_piece()
    if not ok:
        return None
    # ⚠ **Re-asked on the FINAL board.** A stair added later, or a resource 칸 cut beside one, changes
    # what the mouth rule sees — a stair that climbed when it was placed can stop climbing afterwards.
    for k in range(len(stairs)):
        if not stair_works(board, stairs[k], serves[k]):
            return None

    props = []
    kind_prop = {"tree": "tree_pine", "rock": "rock", "ore": "ore"}
    for b in sorted(res_of):
        bx, by = (b % BW) * B, (b // BW) * B
        for dy in range(B):
            for dx in range(B):
                props.append({"kind": kind_prop[res_of[b]], "x": bx + dx, "y": by + dy,
                              "ox": round((rng.below(200) - 100) / 500.0, 3),
                              "oy": round((rng.below(200) - 100) / 500.0, 3),
                              "yaw": float(rng.below(360)), "scale": round(0.8 + rng.below(40) / 100.0, 3)})

    spot = _fishing_spot(board, rng)
    kx, ky = (keep % BW) * B, (keep // BW) * B
    return {
        "w": W, "h": H,
        "rows": ["".join(r) for r in board.rows],
        "tiers": ["".join(".12"[v] if v < 3 else str(v) for v in row) for row in board.lvl],
        "coast": [],
        "builds": [{"kind": "keep", "x": kx, "y": ky}],
        "props": props,
        "spots": [{"kind": "fishing", "x": spot[0], "y": spot[1]}] if spot else [],
        "base_h": 0.21, "level_h": 0.5,
        "_debug": {"land": len(land), "plateaus": [len(p) for p in plateaus], "stairs": len(stairs),
                   "keep_dist": dist.get(keep, 0), "res": counts, "walk": got, "seed": seed,
                   "board": board, "stair_blocks": list(stairs), "serves": [sorted(p) for p in serves]},
    }


def stair_works(board, door, plate):
    """Can a body actually climb this stair? **Asked of the painted board with the game's own step
    rule, never reasoned about.** A stair's axis comes from a mouth chosen by lowest tile index then
    W,E,N,S, so a stair with ground on THREE sides can come out with an axis across the climb — the
    door opens and leads nowhere, and nothing says so."""
    bx, by = (door % BW) * B, (door // BW) * B
    tiles = [(bx + dx, by + dy) for dy in range(B) for dx in range(B)]
    plate_tiles = set()
    for b in plate:
        px, py = (b % BW) * B, (b // BW) * B
        for dy in range(B):
            for dx in range(B):
                plate_tiles.add((px + dx, py + dy))
    entered = exited = False
    for t in tiles:
        for dx, dy in NEIGH8:
            nb = (t[0] + dx, t[1] + dy)
            if not (0 <= nb[0] < W and 0 <= nb[1] < H):
                continue
            if board.level(*nb) == 0 and board.passable(*nb) and board.can_step(nb, t):
                entered = True
            if nb in plate_tiles and board.can_step(t, nb):
                exited = True
    return entered and exited


def _pick_door(rng, land, plateaus, plate, taken):
    """A 칸 beside `plate` that a body can actually climb: land, level 0 today, with GROUND on the
    side opposite the plateau — because the stair's axis is the line from its mouth, and a stair whose
    plateau is not opposite its mouth is entered and never left."""
    cands = []
    for b in sorted(plate):
        bx, by = b % BW, b // BW
        for dx, dy in NEIGH4:
            door = (bx + dx, by + dy)
            back = (bx + 2 * dx, by + 2 * dy)
            if not (0 <= door[0] < BW and 0 <= door[1] < BH):
                continue
            if not (0 <= back[0] < BW and 0 <= back[1] < BH):
                continue
            db, bb = bi(*door), bi(*back)
            if db not in land or bb not in land or db in taken:
                continue
            if any(db in p or bb in p for p in plateaus):
                continue
            if bb in taken:
                continue
            cands.append(db)
    cands = sorted(set(cands))
    while cands:
        door = cands.pop(rng.below(len(cands)))
        trial = paint(land, plateaus, taken + [door], set())
        if not stair_works(trial, door, plate):
            continue
        if trial.one_walking_piece()[0]:
            return door
    return None


def _fishing_spot(board, rng):
    """Open water about two 칸 off the island, found with one flood rather than a search per tile."""
    dist = [[-1] * W for _ in range(H)]
    queue = []
    for y in range(H):
        for x in range(W):
            if board.rows[y][x] != "~":
                dist[y][x] = 0
                queue.append((x, y))
    head = 0
    while head < len(queue):
        cx, cy = queue[head]
        head += 1
        for dx, dy in NEIGH8:
            nx, ny = cx + dx, cy + dy
            if not (0 <= nx < W and 0 <= ny < H) or dist[ny][nx] >= 0:
                continue
            dist[ny][nx] = dist[cy][cx] + 1
            queue.append((nx, ny))
    pool = [(x, y) for y in range(H) for x in range(W) if dist[y][x] == FISH_TILES]
    if not pool:
        pool = [(x, y) for y in range(H) for x in range(W) if dist[y][x] > 0]
    return pool[rng.below(len(pool))] if pool else None


if __name__ == "__main__":
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    bad, stats = 0, {"stairs": {}, "plateaus": {}, "attempts": {}, "walk": set(), "res": {}}
    for seed in range(1, n + 1):
        b = generate(seed)
        if b is None:
            bad += 1
            continue
        d = b["_debug"]
        assert d["land"] == LAND_BLOCKS, (seed, d["land"])
        assert PLATEAU_MIN <= len(d["plateaus"]) <= PLATEAU_MAX
        assert STAIR_MIN <= d["stairs"] <= STAIR_MAX
        assert d["stairs"] >= len(d["plateaus"])
        assert d["keep_dist"] >= KEEP_COAST_BLOCKS
        assert "H" not in "".join(b["rows"])
        assert set("".join(b["tiers"])) <= set(".12")
        assert d["board"].one_walking_piece()[0]
        stats["stairs"][d["stairs"]] = stats["stairs"].get(d["stairs"], 0) + 1
        stats["plateaus"][len(d["plateaus"])] = stats["plateaus"].get(len(d["plateaus"]), 0) + 1
        stats["attempts"][d["attempt"]] = stats["attempts"].get(d["attempt"], 0) + 1
        stats["walk"].add(d["walk"])
        for k, v in d["res"].items():
            bucket = stats["res"].setdefault(k, {})
            bucket[v] = bucket.get(v, 0) + 1
        assert generate(seed)["rows"] == b["rows"], "seed %d is not repeatable" % seed
    print("seeds", n, "failed", bad)
    print("stairs", stats["stairs"], "| plateaus", stats["plateaus"], "| retries", stats["attempts"])
    print("res", stats["res"])
    print("standable 조각", min(stats["walk"]), "..", max(stats["walk"]))
    b = generate(7)
    for i, r in enumerate(b["rows"]):
        print("%2d %s   %s" % (i, r, b["tiers"][i]))
    print(b["builds"], b["spots"], {k: v for k, v in b["_debug"].items() if k != "board"})
