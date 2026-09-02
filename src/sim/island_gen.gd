class_name IslandGen
extends RefCounted
## **The island, generated from one number instead of drawn.** (2026-09-02, the user: 「그리고 맵이
## 항상 새롭게 생성되는 알고리즘 필요함」 — *"and we need an algorithm where the map is always newly
## generated."* Ticket 08-01.)
##
## ⚠⚠ **THIS DOES NOT PUT THE LETTER GRID BACK INTO `islands.gd`.** That grid was deleted on
## 2026-08-26 because the user is the one drawing islands, and that reversal stands: **a generator
## WRITES a board, it does not hold one.** Nothing here is typed out; every 조각 comes from the seed.
##
## ⚠⚠ **WHAT THIS BUILDS IS THE BOARD, NOT THE PICTURE.** It answers the same dictionary
## `assets/terrain/island.json` holds — `w` `h` `rows` `tiers` `builds` `props` `base_h` `level_h` — so
## `Grid` walks a generated island exactly as it walks the drawn one. **`coast` comes back EMPTY and
## the 3D is not stood up**: the drawn island's outline and its 5 MB mesh are baked by Blender, and
## standing the twelve part sets on a generated board is the other half of 08-01. **Until that half
## exists nothing in `src/` reads this file** — the nets do, and they are what says it is right.
##
## ⚠ **Nothing here is a Node**, so a net drives hundreds of seeds with `.new()` and no tree at all.
##
## **The fifteen things the user decided on 2026-09-02 are the spec, and each constant below carries
## the one it comes from.** What is NOT decided is written on the constant too.
##
## ⚠⚠ **THE WALK IS CHECKED WITH THE GAME'S OWN `Grid.can_step` AND NEVER WITH A SECOND RULE.** A
## generator that judged its own islands walkable by its own arithmetic is the exact failure
## `how-nets-lie` collects: it would go green while the island it made sealed a plateau off. **Every
## candidate board here is loaded into a real `Grid` and asked.** It costs a `load_rows` per candidate
## — measured in the prototype at about 20 ms for a whole island, once per run — and it is the only
## reason the stair rule below could be got right at all.


## **The board in 칸 and in 조각.** ⚠ **The land is 107 칸 — task 06's number** (2026-09-02: today's
## 71 칸 「widened by about half」). The board around it is this file's choice and not the user's: it is
## sized so 107 칸 of land fill a little under two thirds of what `RIM` leaves, which is what keeps the
## outline organic instead of pressing it into a rectangle.
const BLOCKS_W := 18
const BLOCKS_H := 16
const LAND_BLOCKS := 107
## **칸 of open sea kept around the island at minimum.** The boats sail in from open water and aim at
## whatever beach `Grid.beach_ring` finds, so an island pressed against a rim gives that side no sea.
const RIM := 2

## **Resource 칸 per island** (row 9: 「나무 1~3 돌 1~3 철 1~2 로 일단 지정」). Each is a whole 칸 that
## **blocks** (row 11: 「막힌다」) — a body stands on the 조각 beside it and gathers from there.
const TREES_MIN := 1
const TREES_MAX := 3
const ROCKS_MIN := 1
const ROCKS_MAX := 3
const ORE_MIN := 1
const ORE_MAX := 2

## **Plateaus 1~2, every one of them holding a stair** (row 13), **stairs 1~3 in total** (row 12).
const PLATEAUS_MIN := 1
const PLATEAUS_MAX := 2
const STAIRS_MIN := 1
const STAIRS_MAX := 3
## How many 칸 one plateau spans. ⚠ **Not the user's numbers** — nothing was asked about plateau size,
## and these are what makes a plateau big enough to hold the 성채 and small enough to walk around.
const PLATEAU_BLOCKS_MIN := 4
const PLATEAU_BLOCKS_MAX := 9

## **The 성채 stands on a plateau (row 5), at least this many 칸 from every coast** (row 6:
## 「모든변에서 3칸이상」).
const KEEP_COAST_BLOCKS := 3

## **A good fishing spot sits about two 칸 off the island** (2026-09-02, fifth round: 「섬 근처 두 칸
## 밖에 ... 떠야」) — two 칸 is four 조각. ⚠ **How many per island was never asked, so it is one.**
const FISH_TILES := 4

## How many whole islands to try before giving up on a seed. **Measured over 400 seeds in the
## prototype: 311 landed on the first try, 87 on the second, 2 on the third, and none needed a
## fourth.** The bound is here so a seed that cannot satisfy the rules fails loudly instead of hanging.
const TRIES := 40

const N4 := [[-1, 0], [1, 0], [0, -1], [0, 1]]
const N8 := [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]


## **A 32-bit LCG, written out rather than taken from the engine.**
##
## ⚠⚠ **THE REASON IT IS HAND-WRITTEN IS THAT THE SAME SEED HAS TO GIVE THE SAME ISLAND** (row 4:
## 「시드로 두자」), and that promise has to survive the engine changing its generator under the game.
## `RandomNumberGenerator` is PCG32 today and nothing says it will be tomorrow; **an island the user
## saw and wanted back is worth more than four lines saved.**
## ⚠ **Numerical Recipes' constants.** The multiply stays under 2^52 so it is exact in an int64 and
## never leans on wrap-around.
class Rng extends RefCounted:
	var state: int = 1

	func _init(seed_value: int) -> void:
		state = seed_value & 0xFFFFFFFF
		if state == 0:
			state = 1

	func next() -> int:
		state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
		return state

	## A number in `[0, n)`. ⚠ **Answers 0 for n <= 1** rather than dividing by zero.
	func below(n: int) -> int:
		if n <= 1:
			return 0
		return next() % n

	## A number in `[lo, hi]`, both ends included — every range in the spec is written that way.
	func between(lo: int, hi: int) -> int:
		return lo + below(hi - lo + 1)


## **One island for one seed, or an empty dictionary when the rules could not be met.**
##
## ⚠⚠ **THE SEED IS THE RUN'S OWN** (`Run.seed`, stood up by ticket 03-02). **This draws no second
## number**: two seeds in one run would make 「same seed, same island」 true of the island and false of
## the bodies standing on it.
## ⚠ **The attempt number is mixed INTO the seed rather than continuing one stream**, so a board that
## needed three tries is still the same board when it is asked for again.
static func board(run_seed: int) -> Dictionary:
	for attempt in TRIES:
		var rng := Rng.new((run_seed * 2654435761 + attempt * 40503) & 0xFFFFFFFF)
		var made := _attempt(rng)
		if not made.is_empty():
			made["attempt"] = attempt
			return made
	return {}


## One try at a whole island. **Every step that could fail answers empty rather than repairing itself**
## — a repair pass is a second set of rules, and the seed is cheap.
static func _attempt(rng: Rng) -> Dictionary:
	var land := _centred(_grow_island(rng))
	var dist := _coast_distance(land)

	# **Deep enough for the 성채**, which is where a plateau has to start for row 6 to be satisfiable.
	var deep := PackedInt32Array()
	for b in _sorted_keys(land):
		if int(dist.get(b, 0)) >= KEEP_COAST_BLOCKS:
			deep.append(b)
	if deep.is_empty():
		return {}

	# -- plateaus ---------------------------------------------------------------------------------
	# ⚠ **A plateau's own neighbours are taken with it.** Two plateaus that touch are one plateau with
	# a wall down the middle, and the count the user gave (1~2) would be a lie about what is on screen.
	var want_plateaus := rng.between(PLATEAUS_MIN, PLATEAUS_MAX)
	var plateaus: Array = []
	var taken := {}
	for _i in want_plateaus:
		var pool := PackedInt32Array()
		for k in deep.size():
			if not taken.has(int(deep[k])):
				pool.append(int(deep[k]))
		if pool.is_empty():
			break
		var plate := _grow_plateau(rng, land, taken, int(pool[rng.below(pool.size())]),
			rng.between(PLATEAU_BLOCKS_MIN, PLATEAU_BLOCKS_MAX))
		if plate.is_empty():
			break
		plateaus.append(plate)
		for b in _sorted_keys(plate):
			taken[b] = true
			for nb in _n4(b):
				taken[nb] = true
	if plateaus.is_empty():
		return {}

	# -- stairs: one into every plateau first, then up to the budget ------------------------------
	var stairs := PackedInt32Array()
	var serves: Array = []
	for pi in plateaus.size():
		var door := _pick_door(rng, land, plateaus, plateaus[pi], stairs)
		if door < 0:
			return {}
		stairs.append(door)
		serves.append(plateaus[pi])
	var budget := rng.between(plateaus.size(), STAIRS_MAX)
	while stairs.size() < budget:
		var pi := rng.below(plateaus.size())
		var extra := _pick_door(rng, land, plateaus, plateaus[pi], stairs)
		if extra < 0:
			break
		stairs.append(extra)
		serves.append(plateaus[pi])

	# -- the 성채 ---------------------------------------------------------------------------------
	var keep_pool := PackedInt32Array()
	for b in _sorted_keys(plateaus[0]):
		if int(dist.get(b, 0)) >= KEEP_COAST_BLOCKS:
			keep_pool.append(b)
	if keep_pool.is_empty():
		return {}
	var keep := int(keep_pool[rng.below(keep_pool.size())])

	# -- resource 칸 ------------------------------------------------------------------------------
	# ⚠⚠ **A RESOURCE 칸 BLOCKS, SO EVERY ONE OF THEM IS A HOLE CUT IN THE ISLAND.** Cutting one can
	# split the island in two — which is 03-14's first defect made fresh every run — so each candidate
	# is cut, the whole board is loaded into a `Grid`, and the cut is kept only if the island survives.
	var banned := {keep: true}
	for b in _sorted_keys(taken):
		banned[b] = true
	for k in stairs.size():
		banned[int(stairs[k])] = true
		for nb in _n4(int(stairs[k])):
			banned[nb] = true
	for nb in _n4(keep):
		banned[nb] = true
	var counts := {
		"ore": rng.between(ORE_MIN, ORE_MAX),
		"rock": rng.between(ROCKS_MIN, ROCKS_MAX),
		"tree": rng.between(TREES_MIN, TREES_MAX),
	}
	var blocked := {}
	var res_of := {}
	for kind in ["ore", "rock", "tree"]:
		for _n in int(counts[kind]):
			var pool := PackedInt32Array()
			for b in _sorted_keys(land):
				if not banned.has(b) and not blocked.has(b):
					pool.append(b)
			var placed := false
			while pool.size() > 0 and not placed:
				var pick := rng.below(pool.size())
				var b := int(pool[pick])
				pool.remove_at(pick)
				blocked[b] = true
				if _one_walking_piece(_grid_of(_paint(land, plateaus, stairs, blocked))):
					res_of[b] = kind
					placed = true
				else:
					blocked.erase(b)
			if not placed:
				return {}

	# -- the board, and the last word on whether it is walkable -----------------------------------
	var painted := _paint(land, plateaus, stairs, blocked)
	var grid := _grid_of(painted)
	if not _one_walking_piece(grid):
		return {}
	# ⚠⚠ **EVERY STAIR IS ASKED AGAIN ON THE FINISHED BOARD.** A stair's axis comes from a mouth the
	# whole board decides (`Grid._build_runs`), so **a stair added later, or a resource 칸 cut beside
	# one, can turn a stair that climbed into one that does not** — and the island stays walkable
	# through the other stairs while the count says 3.
	for k in stairs.size():
		if not _stair_works(grid, int(stairs[k]), serves[k]):
			return {}

	var props := _props_of(rng, res_of)
	var spot := _fishing_spot(grid, rng)
	var b_size := Rules.BLOCK_TILES
	return {
		"w": BLOCKS_W * b_size,
		"h": BLOCKS_H * b_size,
		"rows": painted["rows"],
		"tiers": painted["tiers"],
		# ⚠ **Empty on purpose.** The outline is baked beside the mesh by Blender and there is no mesh
		# for a generated island yet — see this file's header. Nothing draws a generated board today.
		"coast": [],
		"builds": [{"kind": "keep", "x": (keep % BLOCKS_W) * b_size, "y": (keep / BLOCKS_W) * b_size}],
		"props": props,
		# ⚠ **`spots` is a key `island.json` does not have.** The good fishing spot is part of what the
		# ticket says a generated board must carry, and 05-09 is what will read it. Nothing reads it yet.
		"spots": ([{"kind": "fishing", "x": spot.x, "y": spot.y}] if spot.x >= 0 else []),
		"base_h": 0.21,
		"level_h": 0.5,
		"land_blocks": land.size(),
		"plateaus": plateaus.size(),
		"stairs": stairs.size(),
		"keep_block": keep,
		"stair_blocks": stairs,
	}


# == the shape ========================================================================================

## **A blob grown one 칸 at a time from the middle of the board.**
##
## ⚠⚠ **GROWN AND NEVER CARVED, AND THAT IS WHAT MAKES IT ONE PIECE.** Every 칸 is added touching one
## already in, so the island cannot come out in two halves and no repair pass can be needed — and a
## split island is 03-14's first defect made fresh every run.
## ⚠ **The frontier is weighted by how many land 칸 a candidate already touches, squared.** Unweighted,
## the blob grows one-칸 tendrils that no 부대 can form up on; the square is what keeps it fat.
static func _grow_island(rng: Rng) -> Dictionary:
	var land := {}
	var start := _bi(BLOCKS_W / 2, BLOCKS_H / 2)
	land[start] = true
	var frontier := {}
	for nb in _n4(start):
		_offer(frontier, land, nb)
	while land.size() < LAND_BLOCKS and frontier.size() > 0:
		var keys := _sorted_keys(frontier)
		var total := 0
		for b in keys:
			total += int(frontier[b]) * int(frontier[b])
		var pick := rng.below(total)
		var run := 0
		var chosen := int(keys[keys.size() - 1])
		for b in keys:
			run += int(frontier[b]) * int(frontier[b])
			if pick < run:
				chosen = b
				break
		frontier.erase(chosen)
		land[chosen] = true
		for nb in _n4(chosen):
			if not land.has(nb):
				_offer(frontier, land, nb)
	return land


## Offers one 칸 to the frontier, counting how many land 칸 it touches. ⚠ **`RIM` is enforced here and
## nowhere else** — a 칸 inside the rim is never offered, so the sea margin cannot be eaten later.
static func _offer(frontier: Dictionary, land: Dictionary, b: int) -> void:
	var bx := b % BLOCKS_W
	var by := b / BLOCKS_W
	if bx < RIM or by < RIM or bx >= BLOCKS_W - RIM or by >= BLOCKS_H - RIM:
		return
	if land.has(b):
		return
	frontier[b] = int(frontier.get(b, 0)) + 1


## **Slides the finished blob so the open sea around it is even.** It grows off-centre because the
## frontier is weighted rather than symmetric, and an island pressed against one rim is a side the
## boats have no water to sail in.
static func _centred(land: Dictionary) -> Dictionary:
	var min_x := BLOCKS_W
	var max_x := -1
	var min_y := BLOCKS_H
	var max_y := -1
	for b in _sorted_keys(land):
		var bx := b % BLOCKS_W
		var by := b / BLOCKS_W
		min_x = mini(min_x, bx)
		max_x = maxi(max_x, bx)
		min_y = mini(min_y, by)
		max_y = maxi(max_y, by)
	# ⚠ **Integer division truncates toward zero here, and that is the safe direction** — a negative
	# shift comes out one smaller in size, so the island always moves LESS than the exact middle and
	# can never be pushed past the rim it grew inside.
	var dx := (BLOCKS_W - 1 - max_x - min_x) / 2
	var dy := (BLOCKS_H - 1 - max_y - min_y) / 2
	var out := {}
	for b in _sorted_keys(land):
		out[_bi(b % BLOCKS_W + dx, b / BLOCKS_W + dy)] = true
	return out


## **How many 칸 each land 칸 stands from the nearest thing that is not land.** A flood, so a diagonal
## counts as one — the same Chebyshev the 성채's 「3 칸 from every coast」 is measured in.
static func _coast_distance(land: Dictionary) -> Dictionary:
	var dist := {}
	var queue := PackedInt32Array()
	for b in _sorted_keys(land):
		var bx := b % BLOCKS_W
		var by := b / BLOCKS_W
		for k in N8.size():
			var nx: int = bx + int(N8[k][0])
			var ny: int = by + int(N8[k][1])
			if nx < 0 or ny < 0 or nx >= BLOCKS_W or ny >= BLOCKS_H or not land.has(_bi(nx, ny)):
				dist[b] = 1
				queue.append(b)
				break
	var head := 0
	while head < queue.size():
		var cur := int(queue[head])
		head += 1
		var cx := cur % BLOCKS_W
		var cy := cur / BLOCKS_W
		for k in N8.size():
			var nx: int = cx + int(N8[k][0])
			var ny: int = cy + int(N8[k][1])
			if nx < 0 or ny < 0 or nx >= BLOCKS_W or ny >= BLOCKS_H:
				continue
			var nb := _bi(nx, ny)
			if not land.has(nb) or dist.has(nb):
				continue
			dist[nb] = int(dist[cur]) + 1
			queue.append(nb)
	return dist


## One plateau, grown inland from a 칸 that is already deep enough for the 성채.
static func _grow_plateau(rng: Rng, land: Dictionary, taken: Dictionary, start: int, want: int) -> Dictionary:
	var plate := {start: true}
	var frontier := PackedInt32Array()
	for nb in _n4(start):
		if land.has(nb) and not taken.has(nb):
			frontier.append(nb)
	while plate.size() < want and frontier.size() > 0:
		var pick := rng.below(frontier.size())
		var b := int(frontier[pick])
		frontier.remove_at(pick)
		if plate.has(b) or taken.has(b) or not land.has(b):
			continue
		plate[b] = true
		for nb in _n4(b):
			if land.has(nb) and not taken.has(nb) and not plate.has(nb):
				frontier.append(nb)
	return plate


## **A 칸 beside `plate` that a body can ACTUALLY climb.**
##
## ⚠⚠ **THE CANDIDATE IS PAINTED AND THEN MEASURED, NEVER REASONED ABOUT.** A stair's axis is the line
## from its mouth, and the mouth is chosen by lowest 조각 index and then west, east, north, south
## (`Grid.STAIR_MOUTH_ORDER`) — so a stair with ground on three sides can come out with an axis ACROSS
## the climb, and `Grid._stair_face_open` then refuses every step onto it. **The door opens and leads
## nowhere, and nothing anywhere says so.** ⚠ The first shape written here was rejected by exactly this
## test while its author was still sure it was fine.
## ⚠ **Ground on the far side is required before the test**, which is cheap and throws out most of the
## bad candidates before a `Grid` is built for them.
static func _pick_door(rng: Rng, land: Dictionary, plateaus: Array, plate: Dictionary,
		taken: PackedInt32Array) -> int:
	var seen := {}
	var cands := PackedInt32Array()
	for b in _sorted_keys(plate):
		var bx := b % BLOCKS_W
		var by := b / BLOCKS_W
		for k in N4.size():
			var dx: int = int(N4[k][0])
			var dy: int = int(N4[k][1])
			var door := _bi_safe(bx + dx, by + dy)
			var back := _bi_safe(bx + dx + dx, by + dy + dy)
			if door < 0 or back < 0:
				continue
			if not land.has(door) or not land.has(back) or seen.has(door):
				continue
			if _in_any(plateaus, door) or _in_any(plateaus, back):
				continue
			if _has(taken, door) or _has(taken, back):
				continue
			seen[door] = true
			cands.append(door)
	while cands.size() > 0:
		var pick := rng.below(cands.size())
		var door := int(cands[pick])
		cands.remove_at(pick)
		var trial := taken.duplicate()
		trial.append(door)
		var grid := _grid_of(_paint(land, plateaus, trial, {}))
		if not _stair_works(grid, door, plate):
			continue
		if _one_walking_piece(grid):
			return door
	return -1


# == the board, and the game's own reading of it ======================================================

## **The letter board.** `~` water · `.` land · `#` a resource 칸, which blocks; tiers `.` level 0 ·
## `1` the stair · `2` the plateau.
##
## ⚠⚠ **`#` IS NOT A NEW LETTER IN `grid.gd` AND THAT IS THE POINT.** Anything outside `land_chars()`
## and `WATER_CHARS` loads impassable and dry, which is exactly what 「a resource 칸 blocks」 means, so
## a resource 칸 needs no rule of its own on the walking side. **Which resource it is lives in `props`**,
## the same place the drawn island keeps its ore and its rocks.
## ⚠⚠ **NO `H` IS WRITTEN** (row 7: 「항구? 그런건 없는데」). The drawn island's 108 `H` 조각 are its
## border rim and nothing in `src/` sails a boat from them.
static func _paint(land: Dictionary, plateaus: Array, stairs: PackedInt32Array,
		blocked: Dictionary) -> Dictionary:
	var b_size := Rules.BLOCK_TILES
	var w := BLOCKS_W * b_size
	var h := BLOCKS_H * b_size
	var terrain := PackedStringArray()
	var tiers := PackedStringArray()
	terrain.resize(h)
	tiers.resize(h)
	var kind := PackedByteArray()
	kind.resize(w * h)
	var lvl := PackedByteArray()
	lvl.resize(w * h)
	for lb in _sorted_keys(land):
		var lx := (lb % BLOCKS_W) * b_size
		var ly := (lb / BLOCKS_W) * b_size
		var mark := 2 if blocked.has(lb) else 1
		for dy in b_size:
			for dx in b_size:
				kind[(ly + dy) * w + lx + dx] = mark
	for pi in plateaus.size():
		for pb in _sorted_keys(plateaus[pi]):
			var px := (pb % BLOCKS_W) * b_size
			var py := (pb / BLOCKS_W) * b_size
			for dy in b_size:
				for dx in b_size:
					lvl[(py + dy) * w + px + dx] = 2
	for k in stairs.size():
		var sb := int(stairs[k])
		var sx := (sb % BLOCKS_W) * b_size
		var sy := (sb / BLOCKS_W) * b_size
		for dy in b_size:
			for dx in b_size:
				lvl[(sy + dy) * w + sx + dx] = 1
	for y in h:
		var row := ""
		var tier := ""
		for x in w:
			var t := y * w + x
			var face := int(kind[t])
			row += "~" if face == 0 else ("." if face == 1 else "#")
			var notch := int(lvl[t])
			tier += "." if notch == 0 else ("1" if notch == 1 else "2")
		terrain[y] = row
		tiers[y] = tier
	return {"rows": terrain, "tiers": tiers}


## **A real `Grid` over a painted board** — the one place a generated island becomes something the
## game can be asked about. ⚠ **`Grid.new()` and `load_rows` and nothing else**: the moment this
## reached for its own walk rule, the generator could certify an island the game cannot walk.
static func _grid_of(painted: Dictionary) -> Grid:
	var grid := Grid.new()
	grid.load_rows(Array(painted["rows"] as PackedStringArray), Array(painted["tiers"] as PackedStringArray))
	return grid


## **Whether every 조각 a body may STAND on is joined to every other by the walk the game does.**
##
## ⚠ **A stair is crossed and not counted.** It is walked across and never stood on — `Hand`'s own
## `_standable` says the same thing — so it carries the flood without being part of what the flood has
## to cover.
static func _one_walking_piece(grid: Grid) -> bool:
	var n := grid.w * grid.h
	var want := 0
	var start := -1
	for t in n:
		if grid.passable[t] == 1 and not Grid.is_stair_level(grid.level_of(t)):
			want += 1
			if start < 0:
				start = t
	if start < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	seen[start] = 1
	queue.append(start)
	var head := 0
	var got := 0
	while head < queue.size():
		var cur := int(queue[head])
		head += 1
		if not Grid.is_stair_level(grid.level_of(cur)):
			got += 1
		var cx := cur % grid.w
		var cy := cur / grid.w
		for k in N8.size():
			var nx: int = cx + int(N8[k][0])
			var ny: int = cy + int(N8[k][1])
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				continue
			var nt := ny * grid.w + nx
			if seen[nt] == 1 or not grid.can_step(cur, nt):
				continue
			seen[nt] = 1
			queue.append(nt)
	return got == want


## **Whether a body can climb this stair — enter it from the ground and leave it onto the plateau.**
## Asked of the painted board with `Grid.can_step`, for the reason `_pick_door` gives.
static func _stair_works(grid: Grid, door: int, plate: Dictionary) -> bool:
	var b_size := Rules.BLOCK_TILES
	var bx := (door % BLOCKS_W) * b_size
	var by := (door / BLOCKS_W) * b_size
	var plate_tiles := {}
	for b in _sorted_keys(plate):
		var px := (b % BLOCKS_W) * b_size
		var py := (b / BLOCKS_W) * b_size
		for dy in b_size:
			for dx in b_size:
				plate_tiles[(py + dy) * grid.w + px + dx] = true
	var entered := false
	var exited := false
	for dy in b_size:
		for dx in b_size:
			var t := (by + dy) * grid.w + bx + dx
			var tx := t % grid.w
			var ty := t / grid.w
			for k in N8.size():
				var nx: int = tx + int(N8[k][0])
				var ny: int = ty + int(N8[k][1])
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := ny * grid.w + nx
				if grid.passable[nt] == 1 and grid.level_of(nt) == 0 and grid.can_step(nt, t):
					entered = true
				if plate_tiles.has(nt) and grid.can_step(t, nt):
					exited = true
	return entered and exited


## **Open water about two 칸 off the island**, found with one flood out from the land rather than a
## search per 조각. ⚠ **Falls back to any water at all** when nothing sits at exactly that distance,
## which a very wide island could produce.
static func _fishing_spot(grid: Grid, rng: Rng) -> Vector2i:
	var n := grid.w * grid.h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for t in n:
		if grid.water[t] == 0:
			dist[t] = 0
			queue.append(t)
	var head := 0
	while head < queue.size():
		var cur := int(queue[head])
		head += 1
		var cx := cur % grid.w
		var cy := cur / grid.w
		for k in N8.size():
			var nx: int = cx + int(N8[k][0])
			var ny: int = cy + int(N8[k][1])
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				continue
			var nt := ny * grid.w + nx
			if dist[nt] >= 0:
				continue
			dist[nt] = int(dist[cur]) + 1
			queue.append(nt)
	var pool := PackedInt32Array()
	for t in n:
		if dist[t] == FISH_TILES:
			pool.append(t)
	if pool.is_empty():
		for t in n:
			if dist[t] > 0:
				pool.append(t)
	if pool.is_empty():
		return Vector2i(-1, -1)
	var hit := int(pool[rng.below(pool.size())])
	return Vector2i(hit % grid.w, hit / grid.w)


## **One prop per 조각 of every resource 칸**, jittered so a tree 칸 does not read as four identical
## trees on a grid. ⚠ **The kinds are the ones the drawn island already uses** — `tree_pine`, `rock`,
## `ore` — so nothing new has to be modelled for a generated board to carry them.
static func _props_of(rng: Rng, res_of: Dictionary) -> Array:
	var b_size := Rules.BLOCK_TILES
	var kind_prop := {"tree": "tree_pine", "rock": "rock", "ore": "ore"}
	var out: Array = []
	for b in _sorted_keys(res_of):
		var bx := (b % BLOCKS_W) * b_size
		var by := (b / BLOCKS_W) * b_size
		for dy in b_size:
			for dx in b_size:
				out.append({
					"kind": kind_prop[res_of[b]],
					"x": bx + dx,
					"y": by + dy,
					"ox": float(rng.below(200) - 100) / 500.0,
					"oy": float(rng.below(200) - 100) / 500.0,
					"yaw": float(rng.below(360)),
					"scale": 0.8 + float(rng.below(40)) / 100.0,
				})
	return out


# == small things =====================================================================================

static func _bi(bx: int, by: int) -> int:
	return by * BLOCKS_W + bx


## The 칸 index, or -1 off the block board. ⚠ **`_bi` does not range-check** and a negative column
## would wrap onto the row above with nothing going red.
static func _bi_safe(bx: int, by: int) -> int:
	if bx < 0 or by < 0 or bx >= BLOCKS_W or by >= BLOCKS_H:
		return -1
	return by * BLOCKS_W + bx


static func _n4(b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var bx := b % BLOCKS_W
	var by := b / BLOCKS_W
	for k in N4.size():
		var nb := _bi_safe(bx + int(N4[k][0]), by + int(N4[k][1]))
		if nb >= 0:
			out.append(nb)
	return out


## **A dictionary's keys, ascending.** ⚠⚠ **EVERY LOOP THAT DRAWS A NUMBER WALKS THIS AND NOT THE
## DICTIONARY.** GDScript hands keys back in insertion order, and insertion order here depends on the
## order 칸 happened to be added — so iterating a set directly would make 「same seed, same island」
## true only until something upstream changed the order it inserted in.
static func _sorted_keys(d: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in d:
		out.append(int(k))
	out.sort()
	return out


static func _has(list: PackedInt32Array, value: int) -> bool:
	for k in list.size():
		if int(list[k]) == value:
			return true
	return false


static func _in_any(plateaus: Array, b: int) -> bool:
	for pi in plateaus.size():
		if (plateaus[pi] as Dictionary).has(b):
			return true
	return false
