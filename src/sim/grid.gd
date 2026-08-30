class_name Grid
extends RefCounted
## The island's tiles: passability, water, harbours, landing reach, per-unit tile reservation, and the
## BFS flow field every unit walks down. Pure data — no Node, no tree, `.new()` is the whole
## construction.
##
## **Movement is a flow field and never a greedy descent.** Greedy 8-way descent was measured stalling
## on five of twenty-six dock-to-enemy pairs on these three grids, so a walker that "obviously works"
## silently freezes on island 2's north-east crow and everything inside island 3's ring. The first-slice
## plan records the measurement under "What two adversarial passes broke".
##
## **The coastline is open, not docked, and landing is a DENYLIST.** `boat-and-landing`, section 3,
## replaced the old fixed-dock legend with harbours (`H`, plural, water tiles a boat sails from and
## returns to). `speed-off-open-landing` then replaced the permit list with the refusal list the user
## actually asked for: ***"상륙 못하는 데가 있는 거지 상륙 가능한 데가 있는 게 아니야"***.
##
## ⚠⚠ **What the old rule cost, measured on all three shipped islands before it was replaced**: it
## refused **39% · 42% · 40%** of each island's own coastline, because `water_line_clear` sampled a
## STRAIGHT line from the harbour and any headland blocked it. That is what read as *the landing spots
## are fixed*. The replacement is a BFS over WATER — `_water_field` — so a boat sails AROUND the
## headland, and since all water on all three islands is one connected body (724 / 690 / 726 tiles,
## every one reachable from every harbour) **the refused set is now exactly `cliff + inland`, with
## nothing left over**. Sendable went 50 -> 84, 44 -> 76, 48 -> 82.
##
## ⚠ **A bigger number is not the same as the right set.** Merely dropping the coast-adjacency test
## would have given 97 / 83 / 94 — MORE tiles than the water route gives — by letting a boat land one
## tile INLAND while still refusing 40% of the actual shore. `speed-off-open-landing` 2.1 records the
## whole table; do not read that middle column as better.
##
## `can_land_at(harbour, tile)` is the one rule that decides where a boat may go, and
## `home_harbour_for` — which is `can_land_at` filtered and then nearest BY WATER ROUTE — is what
## `Battle.send` answers to, so the screen cannot promise a tile the sim refuses.


## Unreachable tiles carry this instead of a sentinel like -1, so a caller comparing field values with
## `<` treats them as the worst option rather than the best one.
const UNREACHABLE := 1 << 30

## Row legend. Anything not listed is loaded as an impassable hole: validating the legend is
## `net_islands`' job, and a `push_error` here would have to be forgiven by every net that hands this
## function a hand-written fixture.
##
## `.` land, `/` ramp (a doorway through a cliff wall — both walkable).
##
## ⚠⚠ **THE SPAWN LETTERS ARE NOT LISTED HERE ANY MORE, and that was two lists nobody kept in step.**
## This constant used to spell them out (`"./BCL"`) while `islands.gd` bound them to unit rows in a
## `match`, so a letter added to one and missed in the other was a body standing on an impassable
## hole with nothing barking. `land_chars()` appends `Islands.spawn_chars()` instead, which makes
## walkability a CONSEQUENCE of being a spawn letter rather than a second fact about it.
const BARE_LAND_CHARS := "./"
## `~` water, `H` harbour — a water tile a boat may sail from and return to.
const WATER_CHARS := "~H"
const HARBOUR_CHAR := "H"

## **The TIER legend — a second board of the same size as the terrain one, and not new terrain
## letters.** 티켓 19, decision 2: a "high ground" letter would need a high twin of every letter that
## can stand on it (`S` · `A` · `L` and every warrior still to come), so the table would square. A
## second board indexes the same tiles and leaves `BARE_LAND_CHARS` untouched — which is why every
## fixture in every net still measures exactly what it measured before.
##
## `.` low ground (level 0) · `/` stair (level 1) · `1` high ground (level 2).
##
## ⚠ **A third tier is levels 3 and 4 and needs no rule change** — only a row here and a colour. That
## is the whole of what decision 2 bought.
## ⚠ **An unlisted character loads as level 0**, matching what the terrain legend does with an unknown
## letter: barking here would have to be forgiven by every net handing this function a fixture, and
## validating the legend is `net_tiers`' job.
## ⚠⚠ **WIDENED 2026-08-26, and the reason is the stair** (the user: 「이점이 안전하고 그래서 농사
## 같은것도 빌드 건물들도 2층이 유리하지 대신 비싸지」). Three levels meant the plateau was ONE step up
## from a stair that was ONE step up from the ground, so the stair was a single knee-high ledge — and
## a plateau whose whole value is「only one way up」cannot afford for that way up to be invisible. With
## the level DIGITS reading as themselves, a stair can be as many treads as it needs.
## ⚠ **`/` still means level 1** so nothing that spells a stair the old way silently becomes ground.
## ⚠⚠ **BUT `1` NOW MEANS LEVEL 1, WHERE IT USED TO MEAN LEVEL 2.** Any fixture still written in the
## old three-character legend measures a different island than it did. **`net_tiers` is the one that
## has to be re-read**, and the nets are red already under the「measure them all once at the end」
## decision, so this is a known cost and not a silent one.
const TIER_CHARS := "./0123456789"
## `TIER_CHARS[k]` is level `TIER_LEVELS[k]`. Two arrays and not a dictionary, for the reason every
## flat table in this file is an Array: `const X := PackedInt32Array([...])` is a parse error on 4.7.
const TIER_LEVELS := [0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]


## Every character a soldier may stand on: bare ground plus every letter that spawns a body.
static func land_chars() -> String:
	return BARE_LAND_CHARS + Islands.spawn_chars()

## ⚠⚠ **WHICH SIDE OF A CORNER STAIR IS ITS MOUTH, WHEN MORE THAN ONE FACES THE FLOOR BELOW.**
## West, then east, then north, then south — and **the order itself is arbitrary; that it is the SAME
## order in `tools/blender/island_build.py` is not.** The staircase's geometry is cut along the axis
## this picks, and the feet climb along the axis this picks; a disagreement puts the body walking
## across the treads instead of up them (2026-08-28, the user: 「계단 이동할때 뚫는거 같은데」).
## ⚠ **Blender cannot read this file.** The pairing is written down here and there, the same way
## `Rules.STAIR_TREADS` and `TREADS` are paired.
const STAIR_MOUTH_ORDER := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

## 8-way, listed in a fixed order so an equal-cost tie always resolves the same way. Plain `const`
## Arrays: `const X := PackedInt32Array([...])` is a parse error on 4.7, so every read casts.
const NEIGHBOURS := [
	[-1, -1], [0, -1], [1, -1],
	[-1, 0], [1, 0],
	[-1, 1], [0, 1], [1, 1],
]

## ⚠ **`ORTHO` is deleted from this file.** It existed for `landable` — "a tile touching water only
## at a corner is not landable" — and `speed-off-open-landing` deleted that predicate whole: the
## denylist opens the 8-WAY coast, so a tile touching water at a corner IS landable now, and that is
## the difference between 82 and 84 tiles on island 0. Its one other reader was `field_view`'s
## cliff-face pass, which walks a cliff tile's seaward EDGES and genuinely needs the four sides; the
## four offsets moved into that file as its own private constant rather than dying.
##
## ⚠ **`Rules.LINE_SAMPLE_STEP` and `Rules.LINE_SAMPLE_EXEMPT_CHEBYSHEV` are deleted too.** They
## tuned `water_line_clear`, which is gone, and a rule constant nobody reads rots silently.

var w: int = 0
var h: int = 0
var passable := PackedByteArray()      # w*h, 1 = walkable (includes a ramp)
var water := PackedByteArray()         # w*h, 1 = water (includes a harbour)
## w*h, the tier level of each tile. **Every height in this game is derived from this one integer** —
## see `Rules.TIER_STEP_TILES` and `TIER_CHARS` above.
##
## ⚠⚠ **`passable` is NOT folded into this and the two mean different things.** `passable` is still
## "may a body stand here"; whether a body may *cross between* two tiles it could both stand on is
## `can_step`. Folding the height into `passable` would make one byte answer two questions, and this
## repo has already paid for a name whose sense changed under it (티켓 15: four checks became shells
## when 소 and 까마귀 moved sides).
var level := PackedByteArray()
## The stair runs of this board, `tile -> [axis, index, length]`. ⚠ **Derived from `level` and cached,
## never loaded**: it is a restatement of the board, so a second source for it could disagree with the
## first. Built on the first ask rather than during `load_rows`, because most boards are flat and most
## nets never ask. See `_build_runs`.
var _runs := {}
var _runs_built := 0
## The beach ring — every coast 조각 a boat may come to. ⚠ **Derived from `passable` and `water` and
## cached, exactly like `_runs`**: it is a restatement of the board, so a second source for it could
## disagree with the first. See `beach_ring`.
var _ring := PackedInt32Array()
var _ring_built := 0
## **The baked outline the island's mesh was actually cut to**, as `[x0, y0, x1, y1]` segments — what
## the PLAYER sees the land end on, which is not where `passable` ends.
##
## ⚠⚠ **IT IS HALF A 조각 OFF RAW TILE COORDINATES, AND THAT OFFSET IS THE WHOLE REASON THIS IS WRITTEN
## DOWN.** A 조각 at integer `(n, m)` has its centre at `(n + 0.5, m + 0.5)` in this space — the same
## `+0.5` `Look.tile_point_px` already applies. Calibrated by scoring 「inside the outline」 against
## `passable` 조각 by 조각: **+0.5 agrees on 100.0%, +0.0 on 94.4%, -0.5 on 88.5%.** ⚠ **A ray fired
## from a raw tile coordinate is off by up to 0.707 조각 on a diagonal**, and that error is what made an
## earlier measurement of this say -0.97 where an independent one said -0.23.
##
## ⚠ **Empty is a real state**: every hand-built fixture loads rows and no outline, and every rule that
## reads this falls back to the 조각 grid when it is empty.
var coast: Array = []
## ⚠⚠ **`Rules.TILE_CAPACITY` SLOTS PER 조각, SLOT-MAJOR: `reserved[tile * cap + k]`.** It held one
## id per 조각 until 2026-08-30, when a 조각 stopped admitting exactly one body — see that constant for
## the user's own figure and why it is nine to a 칸 rather than three to a 조각.
## ⚠ **Nothing outside this file may index it.** `slot_of`, `holds`, `hold_count`, `has_room` and
## `can_hold` are the readers, and a raw `reserved[tile]` now names slot 0 of a 조각 three times lower
## down the board — a plausible number for the wrong 조각, which is this repo's own named false green.
## ⚠ **The slot is a PLACE and not an identity**: the view reads it to spread a crowd inside its 조각,
## and it changes whenever the body ahead of it in that 조각 leaves.
var reserved := PackedInt32Array()     # tile * Rules.TILE_CAPACITY + slot -> unit id, or -1

## unit id -> Array of tiles it currently holds. At most two: the tile it stands on and the tile it is
## walking into. This is only the fast path for releasing — `reserved` is the authority, which is why
## `release_all` rescans it in full instead of trusting this.
var _held := {}


## Loads one island's rows. Safe to call twice: every array is rebuilt, so a `Grid` reused across
## islands cannot inherit the previous island's reservations.
##
## ⚠⚠ **`tiers` DEFAULTS TO EMPTY AND EMPTY MEANS FLAT**, and that default is the whole reason this
## change did not move a single existing fixture. Every net that hands this function rows and nothing
## else gets an island at level 0 everywhere, where `can_step` is `passable` and nothing more — so the
## checks written before height existed keep measuring their own subject rather than quietly measuring
## a climb rule as well.
##
## A short `tiers` board, or a short row inside it, reads as level 0 there — the same silence the
## terrain loop keeps for a short row. **`net_tiers` is what asserts the two boards are the same
## shape**, per island, because two boards that disagree about their size is the one way a stair can
## end up somewhere nobody authored it.
func load_rows(rows: Array, tiers: Array = []) -> void:
	h = rows.size()
	w = 0
	if h > 0:
		w = String(rows[0]).length()
	var n := w * h
	passable = PackedByteArray()
	passable.resize(n)
	water = PackedByteArray()
	water.resize(n)
	level = PackedByteArray()
	level.resize(n)
	reserved = PackedInt32Array()
	reserved.resize(n * Rules.TILE_CAPACITY)
	reserved.fill(-1)

	# Built once per load rather than per tile: the string is assembled from a table, and 1536 tiles
	# rebuilding it would be a walk of `SPAWN_ROWS` per tile for an answer that cannot change.
	_runs = {}
	_runs_built = 0
	_ring = PackedInt32Array()
	_ring_built = 0
	# ⚠ **NOT cleared here.** `Islands.load_into` sets it after calling this, and a board loaded twice
	# from the same island would otherwise lose its outline on the second pass.
	_main = PackedByteArray()
	_main_built = 0
	_centre = Vector2.ZERO
	var land := land_chars()
	for y in h:
		var row := String(rows[y])
		var tier_row := String(tiers[y]) if y < tiers.size() else ""
		for x in w:
			var t := y * w + x
			level[t] = _level_of_char(tier_row[x]) if x < tier_row.length() else 0
			if x >= row.length():
				passable[t] = 0
				water[t] = 0
				continue
			var c := row[x]
			passable[t] = 1 if land.find(c) != -1 else 0
			water[t] = 1 if WATER_CHARS.find(c) != -1 else 0



## The level a tier character stands for, or 0 for a character the legend does not list.
static func _level_of_char(c: String) -> int:
	var k := TIER_CHARS.find(c)
	if k < 0:
		return 0
	return int(TIER_LEVELS[k])


## **Whether a level is a stair tread rather than a tier's own floor.** A stair is not a kind of tile —
## it is an ODD level, which is what makes a third tier cost nothing but two more rows in `TIER_CHARS`:
## level 3 would be the stair up to level 4 and this function would already know it.
## ⚠ Its one reader is the picture, which paints a stair its own colour. **Nothing about walking asks
## this** — `can_step` compares levels and never asks what a level means.
static func is_stair_level(lv: int) -> bool:
	return (lv % 2) == 1


## The tier level of a tile. **Off the grid answers 0** — the terrain mesh runs `WATER_MARGIN_TILES`
## wider than the island on every side, and the margin is the sea, which is the bottom of everything.
func level_at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return 0
	return int(level[ty * w + tx])


func level_of(t: int) -> int:
	if t < 0 or t >= level.size():
		return 0
	return int(level[t])


## **How high the ground is under a point, in TILES** — the one place a level becomes a height, so the
## walking rule and the reach rule cannot end up with two ideas of how tall a tier is.
##
## `p` is in tile units with tile centres on integers, the same units `soldier_pos` and `step_toward`
## speak. ⚠ **It ROUNDS to the tile and does not interpolate**, and that is a decision rather than an
## omission: pathfinding is per tile, so a height that slid smoothly between tiles would have the two
## halves of the sim looking at different ground. **A body's height changes in one step as it crosses
## a tile line** — the reach test flips once at a stair mouth, which is intended, and whether that
## reads as a stutter is something only an eye can answer.
func height_at(p: Vector2) -> float:
	return float(level_at(int(round(p.x)), int(round(p.y)))) * Rules.TIER_STEP_TILES


## **Where a body's FEET actually rest, in tiles** — the same surface the Blender bake draws, including
## the slope up a stair.
##
## ⚠⚠ **THIS IS NOT `height_at` AND THE DIFFERENCE IS DELIBERATE.** `height_at` is the RULE height: one
## number per tile, what reach and target choice measure in, and it must stay per-tile or two machines
## running the same island could disagree. **This one is the DRAWN height**, and it slides across a
## stair because the mesh does. ⇒ **Only `src/view/` may call this**; nothing that decides an outcome
## may, or the rounding that keeps the sim reproducible would be quietly undone.
##
## ⚠ **A stair run spans exactly one storey however long it is**, so tile `i` of `n` carries the slice
## from `i/n` to `(i+1)/n` of the climb — the identical arithmetic `island_build.py` uses.
##
## ⚠⚠ **AND THE TREADS ARE MODELLED NOW** (2026-08-28, the user, watching a body climb: 「계단을 캐릭이
## 뚫고감 이건 근본적인문제인데 왜그럴까?」). This function returned a straight RAMP and the mesh is cut
## into `Rules.STAIR_TREADS` steps, so a body walked the average of the steps — **sinking into every
## tread and floating over every riser, the whole way up.** The note that stood here said the treads
## were left out on purpose, because 「drawing it on the nose would make the body bob」; what it did
## instead was put the body inside the staircase, which is worse and is what the user saw.
## ⇒ **The feet land on the tread they are over.** The bob is real and it is one tread of a storey —
## `1/6` of `TIER_RISE_TILES`, which is 0.167 tiles — and it is a body climbing steps.
func surface_h(p: Vector2) -> float:
	var tx := int(round(p.x))
	var ty := int(round(p.y))
	var t := tx + ty * w
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return 0.0
	var run: Array = stair_run_of(t)
	if run.is_empty():
		return float(level_of(t)) * Rules.TIER_STEP_TILES
	var ax: Vector2i = run[0]
	var i := int(run[1])
	var n := int(run[2])
	var floor_h := float(level_of(t) - 1) * Rules.TIER_STEP_TILES
	var storey := 2.0 * Rules.TIER_STEP_TILES
	# How far across this tile the body has walked, along the run: 0 at the downhill edge, 1 at the top.
	var f := (p.x - float(tx)) * float(ax.x) + (p.y - float(ty)) * float(ax.y) + 0.5
	f = clampf(f, 0.0, 1.0)
	# How far up the WHOLE run this point is, 0 at the mouth and 1 at the head.
	var up := (float(i) + f) / float(n)
	# ⚠⚠ **Snapped to the tread the point is standing on**, and this is what stops a body walking
	# through the staircase. `floor` and not `round`: a foot in the middle of a tread rests on THAT
	# tread's top, never on the one above it, and rounding would put the body half a riser into the air
	# for the back half of every step.
	# ⚠ **`min` against the last tread**, because `up == 1.0` at the head would index one past the end
	# and lift the body a whole extra riser above the floor it is stepping onto.
	var tread := minf(floor(up * float(Rules.STAIR_TREADS)), float(Rules.STAIR_TREADS - 1))
	return floor_h + storey * (tread + 1.0) / float(Rules.STAIR_TREADS)


## The stair run a tile belongs to, as `[axis, index, length]`, or an empty array when the tile is not
## part of one. **Built once per board and cached**, because it is a fact about the board.
func stair_run_of(t: int) -> Array:
	if _runs_built == 0:
		_build_runs()
	return _runs.get(t, [])


## ⚠⚠ **A STAIR IS A GROUP OF TILES, NOT ONE TILE.** Cut into a plateau, a stair has the storey above
## it on three sides; strung two tiles long, the middle tile has no higher neighbour at all. So the
## MOUTH — the one tile of the group touching the storey below — is what gives the run its direction.
##
## ⚠ **Nothing about this is authored.** The board still says only `1`; the direction falls out of
## which side the ground is on. Dwarf Fortress reads its ramps the same way.
##
## ⚠ **A group that is not a filled RECTANGLE is dropped**, so a mis-drawn board makes the stair fall
## back to flat rather than producing a staircase that climbs through itself.
## ⚠⚠ **A BLOCK MAY BE MORE THAN ONE TILE WIDE, AND THE INDEX IS STILL ALONG THE CLIMB ONLY**
## (2026-08-27, the user: 「계단이라는 블록이 있어야할듯」). Two tiles side by side at the same step
## carry the same index and therefore the same height, which is what makes a wide stair one
## staircase rather than two beside each other. **`surface_h` needed no change for it.**
## ⚠⚠ **This mirrors `stair_runs()` in `tools/blender/island_build.py` and the two must agree** — one
## draws the surface and one says where the feet go. If you change the shape of a run in one, change it
## in the other in the same edit.
func _build_runs() -> void:
	_runs_built = 1
	_runs = {}
	var seen := {}
	for y in h:
		for x in w:
			var t := y * w + x
			var l := level_of(t)
			if l <= 0 or l % 2 == 0 or seen.has(t):
				continue
			var group: Array = []
			var stack: Array = [Vector2i(x, y)]
			var mark := {t: true}
			while stack.size() > 0:
				var pt: Vector2i = stack.pop_back()
				group.append(pt)
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var q: Vector2i = pt + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var qt := q.y * w + q.x
					if mark.has(qt) or level_of(qt) != l:
						continue
					mark[qt] = true
					stack.append(q)
			for k in mark.keys():
				seen[k] = true
			# ⚠⚠ **A CORNER STAIR MEETS THE FLOOR ON TWO SIDES AND ONLY ONE OF THEM CAN BE THE MOUTH**
			# (2026-08-28, the user: 「계단 이동할때 뚫는거 같은데」). This used to keep the LAST mouth
			# the loops happened to find — the group is walked off a stack, so which tile came last was
			# not even stable — and `island_build.py` picked its own by a different rule. **The result
			# was a staircase drawn climbing west-to-east while the feet climbed south-to-north**: the
			# body walked across the treads instead of up them, which is exactly「뚫는다」.
			# ⇒ **The mouth is chosen deterministically and by the same rule in both files**: the
			# lowest tile index wins, and among its own sides `STAIR_MOUTH_ORDER` decides.
			# ⚠⚠ **`island_build.py`'s `lowside` mirrors this and the two must move together.** It is
			# the third pair in this pattern, after `TIER_STEP_TILES`/`level_h` and `STAIR_TREADS`.
			var mouth := Vector2i(-99, -99)
			var mouth_dir := Vector2i.ZERO
			var mouth_tile := 1 << 30
			var has_head := false
			for pt: Vector2i in group:
				var pt_tile := pt.y * w + pt.x
				for d: Vector2i in STAIR_MOUTH_ORDER:
					var q: Vector2i = pt + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var nl := level_of(q.y * w + q.x)
					if nl == l - 1:
						# Lowest tile first; within one tile the first side in the order wins, so a
						# `continue` after the first hit on this tile is what makes the order matter.
						if pt_tile < mouth_tile:
							mouth_tile = pt_tile
							mouth = pt
							mouth_dir = d
					elif nl == l + 1:
						has_head = true
			if mouth_dir == Vector2i.ZERO or not has_head:
				continue
			var ax := Vector2i(-mouth_dir.x, -mouth_dir.y)
			## The cross axis, 90 degrees from the climb — the same one `island_build.py` picks.
			var perp := Vector2i(-ax.y, ax.x)
			## Each tile's place in the block: `x` along the climb, `y` across it.
			var cells := {}
			var jmin := 1 << 30
			var imax := -(1 << 30)
			for pt: Vector2i in group:
				var d: Vector2i = pt - mouth
				var i := d.x * ax.x + d.y * ax.y
				var j := d.x * perp.x + d.y * perp.y
				cells[pt.y * w + pt.x] = Vector2i(i, j)
				if j < jmin:
					jmin = j
				if i > imax:
					imax = i
			var run_n := imax + 1
			var jmax := -(1 << 30)
			for tile in cells.keys():
				var c: Vector2i = cells[tile]
				c.y -= jmin
				cells[tile] = c
				if c.y > jmax:
					jmax = c.y
			var wide := jmax + 1
			# ⚠⚠ **A BLOCK HAS TO BE A FILLED RECTANGLE, AND THIS USED TO DEMAND A SINGLE FILE.** The old
			# test wanted the along-run indices to be exactly `0..n-1`, which a 2-wide stair cannot give —
			# it gives `0,0,1,1` — so the user's 「계단이라는 블록」 was dropped as malformed and every
			# body's feet fell back to the flat plateau height with nothing said. **What actually has to
			# hold is that every step of the climb is the same width.** A negative index is refused by the
			# same test, since the rectangle it is compared against starts at zero.
			var ok := run_n > 0 and wide > 0 and cells.size() == run_n * wide
			if ok:
				var want := {}
				for i in run_n:
					for j in wide:
						want[Vector2i(i, j)] = true
				for c in cells.values():
					if not want.has(c):
						ok = false
						break
			if not ok:
				continue
			for tile in cells.keys():
				_runs[tile] = [ax, int((cells[tile] as Vector2i).x), run_n]


## --- the shore a boat comes to ------------------------------------------------------------------

## ⚠⚠ **IT IS CALLED A BEACH AND NOT A LANDING, AND THE NAME IS LOAD-BEARING.** `net_tiers._is_landing`
## already means 「passable and not a stair」 and answers 280 조각 on this island; **a 해변 is a coast 조각
## a boat may come to** and there are far fewer. Two rules under one word is how this repo has twice
## ended up with a check quietly measuring the other one.

## Every 조각 in the biggest walkable body of land, as a `w*h` byte table. **Cached and derived**, like
## `_runs`: it is a restatement of `passable` plus `can_step`, and a second source could disagree.
var _main := PackedByteArray()
var _main_built := 0
## The reach `_ring` was built for. **The ring depends on it** — see `beach_ring` — so a caller asking
## for a different one gets it rebuilt rather than the previous answer.
var _ring_reach := -1.0
## The middle of that body of land, in 조각 units. Cached with it.
var _centre := Vector2.ZERO


## **Every coast 조각 a boat may come to: land, with water beside it, and walkable to the rest of the
## island — in a ring, ordered by angle about the island's middle.**
##
## ⚠⚠ **THE ORDER IS THE POINT AND IT IS NOT 조각-NUMBER ORDER.** A row-major list is not a loop round
## an island: the stride `Rules.beach_stride_for` hands back walks it into a handful of fixed beaches,
## because 37 rows down is still the same coast. **Sorted by angle, a stride IS「go round to the other
## side」** — see that constant.
##
## ⚠⚠ **A DETACHED ISLET IS EXCLUDED, AND THAT IS `_main` AND NOT A SPECIAL CASE.** The shipped board
## is 284 land 조각 in two pieces: one of 280, and a 2x2 with no walk to them. All four of the small
## one's 조각 touch water, so a bare coast test hands them back — **and they are beaches nothing can
## walk inland from.**
##
## ⚠ **Off the board is NOT water.** The board is the only thing this file knows; the terrain mesh runs
## wider than it, but that is the picture's fact and not the rule's.
##
## ⚠⚠ **`can_land_at` STOOD WHERE THIS DOES AND THIS IS NOT IT COMING BACK.** That one took a harbour
## and ran a BFS over water to it, because the player's boat departed from a named harbour. **The
## beasts' boats depart from open sea**, so there is nothing to route from. The 39/42/40% of shore its
## straight-line sampler used to refuse is recorded in this file's own header and is not something this
## can bring back.
## ⚠⚠ **AND A THIRD TERM: A HULL HAS TO FIT IN FRONT OF IT.** A coast 조각 can stand on INLAND water — a
## lake or a pool inside the island — and `seaward_at` is a local rule that happily aims a boat into it.
## The hull is then born on the island and sails across it, and **every distance check about the
## crossing stays green through that**, because a crossing is measured from the beach 조각 and knows
## nothing about what lies between. ⇒ **a 조각 whose stop point would sit at or past where the hull is
## born is not a beach** — see `land_reach_along`, which is what the stop is built on.
## ⚠ **`reach` is therefore part of what a beach IS**, which is why it is a parameter and not a
## constant this file holds: `Rules.BOAT_START_DIST_TILES` says how far out a hull is born, and a 조각
## reachable from 4 조각 out need not be reachable from 24.
func beach_ring(reach: float) -> PackedInt32Array:
	if _ring_built == 0 or reach != _ring_reach:
		_build_ring(reach)
	return _ring


func _build_ring(reach: float) -> void:
	_ring_built = 1
	_ring_reach = reach
	_ring = PackedInt32Array()
	var main := main_land()
	var centre := island_centre()
	var found: Array = []
	for t in passable.size():
		if passable[t] == 0 or main[t] == 0:
			continue
		if not _touches_water(t):
			continue
		var here := Vector2(t % w, t / w)
		# ⚠⚠ **ADMISSION IS 「CAN A HULL GET IN AND STILL HAVE A CROSSING」, NOT 「IS THE LINE CLEAR」.**
		# The old test refused any beach with land anywhere on its approach; the boat now stops OUTSIDE
		# the outermost land instead, so a headland on the line moves the stop rather than deleting the
		# beach. **What is left to refuse is a corridor with no room**: a beach whose stop point would
		# sit at or past where the hull is born has no crossing at all — and an inner-shore 조각, whose
		# line runs into the island itself, is exactly that.
		# ⚠ `reach` is `Rules.BOAT_START_DIST_TILES` — see this function's header on why the ring
		# depends on it.
		var lead := land_reach_along(t, seaward_at(t), reach)
		# ⚠⚠ **THE HULL MUST STOP IN FRONT OF *THIS* BEACH AND NOT IN FRONT OF SOMETHING ELSE.** Dropping
		# this and keeping only the room test below let **22 inner-shore 조각 straight back into the
		# ring** — measured: their seaward line crosses their pool, runs into the island body and comes
		# out the far side, so the outermost land is a dozen 조각 away, the arithmetic is satisfied, and
		# the boat parks in open water nowhere near the 조각 it is aimed at.
		# ⇒ **The land the hull stops against has to be within a hull's length of the beach.** That is
		# `BOAT_STANDOFF_TILES` and not a new number: a headland 0.98 or 1.40 조각 out is the same shore
		# seen at an angle and the stop simply moves; a dozen 조각 out is a different shore.
		if lead >= Rules.BOAT_STANDOFF_TILES:
			continue
		# And room to cross at all. ⚠ **Its own line**: the test above is about WHICH land, this one is
		# about whether a hull born at `reach` has anywhere to sail to.
		# ⚠⚠ **THE FOOTPRINT IS WHAT DECIDES IT WHERE THERE IS AN OUTLINE.** The 조각 rule above is a
		# floor and the drawn shore can push the stop further out than it — a beach that cannot take the
		# hull's whole forward half is not a beach. **On a board with no outline this is the 조각 rule
		# alone**, which is every fixture.
		var floor_d := lead + Rules.BOAT_STANDOFF_TILES
		var stop_d := hull_stop_along(t, seaward_at(t), Rules.BOAT_HULL_HALF_TILES,
				Rules.BOAT_HULL_BEAM_TILES * 0.5, Rules.BOAT_BEACH_GAP_TILES, floor_d)
		if stop_d == -INF:
			stop_d = floor_d
		if stop_d >= reach:
			continue
		# ⚠⚠ **AND A BEACH THAT CANNOT TAKE THE HULL NEAR IT IS NOT A BEACH.** On a few 조각 the seaward
		# bearing runs ALONGSIDE the coast rather than out of it, so a shoulder ray lies inside land for
		# several 조각 and no stop within reach of the shore clears the hull's width. **The rule then
		# walks the boat out to 7.89 조각 and it parks in open sea with nothing in frame explaining it** —
		# which reads worse than a bow on the grass, because a beached boat at least looks like something
		# happened. ⇒ **Drop the 조각 instead of stranding a boat off it.**
		# ⚠ **A hull length past the plain standoff is the line**, the same bound `net_boats` asserts.
		if stop_d > Rules.BOAT_STANDOFF_TILES + Rules.BOAT_HULL_HALF_TILES:
			continue
		found.append([(here - centre).angle(), t])
	# ⚠ **Ties break on the LOWER 조각 number.** `sort_custom` is not stable, so two beaches at the same
	# angle — the near and far ends of one spoke — would otherwise order themselves differently between
	# two runs from identical state, and every beach after the first would move with them.
	found.sort_custom(func(a, b):
		if float(a[0]) == float(b[0]):
			return int(a[1]) < int(b[1])
		return float(a[0]) < float(b[0]))
	for row in found:
		_ring.append(int(row[1]))


## Whether any of the eight neighbours of `t` is water. ⚠ **Its own function and not folded into the
## bearing**: water on two exactly opposite sides sums to nothing, and a 조각 on a one-조각 isthmus is
## still coast.
func _touches_water(t: int) -> bool:
	var tx := t % w
	var ty := t / w
	for k in NEIGHBOURS.size():
		var nx := tx + int(NEIGHBOURS[k][0])
		var ny := ty + int(NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if water[ny * w + nx] != 0:
			return true
	return false


## The biggest body of land a body can walk around, as a byte per 조각.
##
## ⚠ **Flooded with `can_step` and not with `passable`**, so a strip of land reachable only over a tier
## wall is its own body — which is what「walkable to the rest of the island」has to mean if it is going
## to keep a boat off a beach nothing can leave.
## ⚠ **Ties on size go to the body containing the LOWEST 조각 number**, because the scan is ascending and
## a later body has to be strictly bigger to take the title.
func main_land() -> PackedByteArray:
	if _main_built == 0:
		_build_main()
	return _main


## The middle of the island, in 조각 units — the mean of `main_land`'s 조각.
##
## ⚠⚠ **THE MEAN OF THE LAND AND NOT THE MIDDLE OF THE BOARD.** The board is padded with sea and it is
## not padded evenly; a bearing taken from the board's middle would push every boat off toward whichever
## side had more water on it. **Nor is it the mean of ALL land** — a detached islet would drag it.
func island_centre() -> Vector2:
	if _main_built == 0:
		_build_main()
	return _centre


func _build_main() -> void:
	_main_built = 1
	var n := w * h
	_main = PackedByteArray()
	_main.resize(n)
	_centre = Vector2.ZERO
	if n == 0:
		return
	var seen := PackedByteArray()
	seen.resize(n)
	var best := PackedInt32Array()
	for t in n:
		if passable[t] == 0 or seen[t] != 0:
			continue
		var body := PackedInt32Array()
		var queue := PackedInt32Array()
		queue.append(t)
		seen[t] = 1
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			body.append(cur)
			var cx := cur % w
			var cy := cur / w
			for k in NEIGHBOURS.size():
				var nx := cx + int(NEIGHBOURS[k][0])
				var ny := cy + int(NEIGHBOURS[k][1])
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nt := ny * w + nx
				if seen[nt] != 0 or not can_step(cur, nt):
					continue
				seen[nt] = 1
				queue.append(nt)
		if body.size() > best.size():
			best = body
	var sum := Vector2.ZERO
	for k in best.size():
		var t2 := int(best[k])
		_main[t2] = 1
		sum += Vector2(t2 % w, t2 / w)
	if best.size() > 0:
		_centre = sum / float(best.size())


## **Which way is out to sea from a beach 조각, as a unit vector in 조각 units.**
##
## ⚠⚠ **A BOAT THAT GOT THIS BACKWARDS WOULD BE BORN INLAND AND SAIL ACROSS THE ISLAND**, and every
## distance check about the crossing would stay green through it — a crossing is measured from the
## beach 조각 and knows nothing about which side of it the water is on. `net_boats` measures the
## direction on its own, by stepping one 조각 along it and asking the board what is there.
##
## ⚠⚠ **THE FALLBACK CHAIN IS THREE LINKS AND IT IS WRITTEN DOWN HERE SO IT IS NOT RE-DERIVED.**
##
##  1. **The sum of the watery neighbours' offsets.** Local, so a beach inside a bay faces out of the
##     BAY rather than out of the island — which a line drawn from the island's middle does not do.
##  2. **Away from the middle of the main land**, when that sum is zero. It is zero for exactly one
##     shape: water balanced on opposite sides, which is a 조각 on a one-조각 isthmus, and there the
##     local answer genuinely has nothing to say.
##  3. **North**, when even that is zero — a one-조각 island, or a beach standing on the middle. **Never
##     a zero vector**: that puts the boat exactly on top of its own beach and the crossing has no
##     length at all.
##
## ⚠ **The radial-from-the-middle rule was measured against this and lost.** It is link 2 here for a
## reason: used as link 1 it aims a bay's beaches at the far arm of their own bay.
## ⚠⚠ **IT DOES NOT TEST WHAT IS BETWEEN THE BEACH AND THE OPEN SEA, AND IT MUST NOT.** A beach on
## inland water gets a bearing into that water, and a hull born far enough out along it lands on the
## island. **That is `beach_ring`'s third term, not this function's** — this one answers 「which way is
## the water from here」 for a 조각, and folding a reach into it would make a direction depend on how
## far somebody meant to sail.
func seaward_at(t: int) -> Vector2:
	if w <= 0 or t < 0 or t >= water.size():
		return Vector2.ZERO
	var local := _sea_neighbours(t)
	if local.length() > Rules.EPS:
		return local.normalized()
	var away := Vector2(t % w, t / w) - island_centre()
	if away.length() > Rules.EPS:
		return away.normalized()
	return Vector2(0.0, -1.0)


## **How far seaward of `t`'s own centre the land on the approach line reaches, in 조각.**
##
## ⚠⚠ **THE STANDOFF USED TO BE MEASURED TO THE TARGET 조각 AND NOTHING ELSE, AND TWO BOATS IN FOUR
## PARKED ON THE GRASS** (2026-08-30, measured on the running game across four arrivals). The hull is
## 2.6 조각 to the bow and the stop was 3.2 out from the beach — exact, and blind: **a different piece
## of coastline lay on the approach line NEARER than the beach itself.** East it stuck out 0.98 조각 and
## the bow went 0.38 over; on a diagonal it stuck out 1.40 and the bow went 0.80 over, a third of the
## hull on the turf. **The number was right about the wrong thing.**
##
## ⇒ **This is what the boat actually has to stop against.** It walks the line seaward and answers the
## distance to the OUTERMOST land 조각's centre, projected on the line — **0 when nothing juts out and
## the target itself is the first thing there**, which is exactly the straight-approach case that was
## already correct. `Battle` adds the hull's half-length and the gap to it.
##
## ⚠ **The outermost and not the nearest**, and that is what makes one number enough: everything between
## the stop and the beach is inside `reach` of it, so a hull that clears the outermost land clears the
## whole run in. **There is no second test for 「is the crossing clear」** — this is it.
func land_reach_along(t: int, dir: Vector2, reach: float) -> float:
	if w <= 0 or t < 0 or t >= passable.size():
		return 0.0
	var from := Vector2(t % w, t / w)
	var far := 0.0
	for raw in _line_tiles_along(from, dir, reach):
		var nt := int(raw)
		if passable[nt] == 0:
			continue
		var d := (Vector2(nt % w, nt / w) - from).dot(dir)
		far = maxf(far, d)
	return far


## How many lateral rays the hull's beam is swept with. **Odd, so one of them is the centre line** —
## the ray every earlier version of this measured, and the one a straight approach is decided by.
## ⚠ **5 and not 2**: the ends alone miss a shore that bulges into the middle of the beam.
const HULL_SWEEP_RAYS := 5

## **Where a hull of this size must stop, as a distance from `t`'s centre along `dir`: the INNERMOST
## place its whole body still clears the DRAWN shore by `gap`.**
##
## ⚠⚠ **IT ASKED 「WHERE IS THE FURTHEST LAND ON THIS LINE」 AND THAT PARKED BOATS IN OPEN SEA**
## (2026-08-30, seen on screen). The rays are parallel, so on an approach running ALONGSIDE a coast a
## shoulder ray reaches land far ahead — and the old rule retreated until the hull cleared THAT, which
## put the furthest boat **7.89 조각 out against a normal of 3.82–3.90**, sitting in clear water with
## nothing in frame explaining it. ⚠ **Every beach that used to put a bow on the grass became one of
## the far-out ones**, all at clearance about +1.00 against a median of +0.61 — the rule was not
## correcting them by the gap, it was overshooting.
##
## ⇒ **The question is 「how far in can the hull stand」, not 「where is the outermost land」.** Land the
## hull stops SHORT of cannot push it out; only land between the bow and the stop can. **The window is
## `[s - half_len - gap, s]`** — bow, gap, and back to where the hull's origin sits — and the answer is
## the smallest `s` whose window holds no land on any swept ray.
##
## ⚠⚠ **THE STERN HALF IS DELIBERATELY OUTSIDE THE WINDOW.** Including it (`s + half_len`) put the
## furthest boat at **11.82 조각** and left (8,15) at 7.89: land SEAWARD of the stop is land the hull
## already sailed past, and letting it dirty the window walks the boat outward until that land is
## behind it again. **Whether the run in was clear at all is the ring's admission test, not this one.**
##
## ⚠ **Solved on the crossings rather than stepped.** Every candidate stop is 「just clear of the top of
## some land interval」, so the answer is one of a handful of numbers and there is nothing to sample at.
## ⚠ **`-INF` when there is no outline, or when nothing within reach works** — the caller keeps the 조각
## rule as its floor, and every fixture is that case.
## ⚠⚠ **`floor` IS WHERE THE SEARCH STARTS AND NOT A CLAMP ON ITS ANSWER.** 「Innermost clear」 taken
## from zero finds a POCKET of water close inshore — measured: five beaches came back with a stop
## nearer than the 조각 rule, the caller took the 조각 rule instead, and the hull was on the grass
## again at exactly the beaches this whole round is about. **The hull arrives from the sea**, so the
## only positions it can take are the ones at or beyond where the 조각 rule already puts it.
func hull_stop_along(t: int, dir: Vector2, half_len: float, half_beam: float, gap: float,
		floor: float) -> float:
	if coast.is_empty() or w <= 0 or t < 0 or t >= passable.size():
		return -INF
	# ⚠ **`+0.5`** — see `coast`. Without it every diagonal is measured from the wrong place.
	var centre := Vector2(t % w, t / w) + Vector2(0.5, 0.5)
	var side := Vector2(-dir.y, dir.x)
	var rays: Array = []
	for k in HULL_SWEEP_RAYS:
		var across := (float(k) / float(HULL_SWEEP_RAYS - 1)) * 2.0 - 1.0
		rays.append(_coast_hits(centre + side * (half_beam * across), dir))

	# Every candidate is one land interval's top, plus the body in front of the stop. Zero is in the
	# list so a beach with nothing in the way answers 0 and the 조각 floor decides it.
	var cands := PackedFloat32Array()
	cands.append(floor)
	for raw in rays:
		var hits: PackedFloat32Array = raw
		for hi in hits:
			# ⚠⚠ **`Rules.EPS`, AND WITHOUT IT EVERY CANDIDATE REJECTS ITSELF.** A stop placed exactly
			# `half_len + gap` beyond a crossing puts that crossing exactly ON the window's lower edge,
			# and a `>=` test then calls its own candidate blocked. **Measured: every candidate was
			# refused, the function answered -INF for 32 beaches, the caller fell back to the 조각 floor
			# and the hull was 0.01 조각 short of the shore** — a boundary comparison deciding a whole
			# rule, which is the case `Rules.EPS` exists for.
			cands.append(hi + half_len + gap + Rules.EPS)
	var sorted := Array(cands)
	sorted.sort()
	for raw_s in sorted:
		var stop := float(raw_s)
		if stop < floor or stop > Rules.BOAT_START_DIST_TILES:
			continue
		if _body_clear(rays, stop - half_len - gap, stop):
			return stop
	return -INF


## Whether no ray has land anywhere in `[lo, hi]`.
##
## ⚠ **Two ways in and both are needed**: a crossing INSIDE the window means the shore passes through
## the body, and a window entirely inside land has no crossing in it at all — the midpoint's parity is
## what catches the second.
func _body_clear(rays: Array, lo: float, hi: float) -> bool:
	var mid := (lo + hi) * 0.5
	for raw in rays:
		var hits: PackedFloat32Array = raw
		var beyond := 0
		for h in hits:
			if h >= lo and h <= hi:
				return false
			if h > mid:
				beyond += 1
		if beyond % 2 == 1:
			return false
	return true


## Every distance along the ray at which the outline crosses it. **Unbounded on purpose** — the parity
## test above counts crossings beyond a point, and a truncated list makes 「inside」 read as 「outside」.
func _coast_hits(from: Vector2, dir: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for raw in coast:
		var seg := raw as Array
		var a := Vector2(float(seg[0]), float(seg[1]))
		var b := Vector2(float(seg[2]), float(seg[3]))
		var ab := b - a
		var denom := dir.cross(ab)
		if absf(denom) < 1e-9:
			continue
		var ao := a - from
		var along := ao.cross(dir) / denom
		if along < 0.0 or along > 1.0:
			continue
		out.append(ao.cross(ab) / denom)
	return out


## Whether the straight line out of `t` along `dir` clears land for `reach` 조각.
##
## ⚠ **Sampled every quarter 조각**, which cannot step over one: a 조각 is one unit across, so four
## samples land inside every one the line passes through.
## ⚠ **`t` itself is skipped and it has to be** — a beach IS land, so a line leaving one would be
## refused by its own starting 조각 at every angle.
## ⚠ **Off the board counts as open.** The board is the only thing this file knows and the terrain mesh
## runs wider than it; a line that leaves the board has left the island behind.
func _clear_water_line(t: int, from: Vector2, dir: Vector2, reach: float) -> bool:
	for raw in _line_tiles_along(from, dir, reach):
		var nt := int(raw)
		if nt == t:
			continue
		if passable[nt] != 0:
			return false
	return true


## **Every 조각 the ray from `from` along `dir` passes through, out to `reach`, starting 조각 included.**
##
## ⚠⚠ **A GRID TRAVERSAL AND NOT A SAMPLER, AND THE DIFFERENCE IS MEASURED.** This was four samples per
## 조각 with a `round()`, and an interval — any interval — steps over a 조각 the ray only clips. **It
## walks boundaries instead**: at each step it crosses whichever of the two 조각 edges is nearer along
## the ray, so it cannot skip one at any step size, because it has no step size.
##
## ⚠⚠ **AN EXACT TIE CROSSES BOTH EDGES AT ONCE AND THE RAY ENTERS THE *DIAGONAL* 조각.** `seaward_at`
## hands back an exact 45 degrees whenever a beach's watery neighbours sum to a diagonal, which is most
## corner beaches, and such a ray passes through 조각 CORNERS. **Measured: stepping one axis and then
## the other reported four 조각 as crossed that the ray only ever touched the corner of.**
func _line_tiles_along(from: Vector2, dir: Vector2, reach: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cx := int(round(from.x))
	var cy := int(round(from.y))
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return out
	out.append(cy * w + cx)
	var step_x := 0
	var step_y := 0
	if dir.x > 0.0:
		step_x = 1
	elif dir.x < 0.0:
		step_x = -1
	if dir.y > 0.0:
		step_y = 1
	elif dir.y < 0.0:
		step_y = -1
	# ⚠ **An axis the ray does not move along never crosses an edge** — INF rather than a division by
	# zero, which would poison every comparison below with a NAN.
	var next_x := INF
	var delta_x := INF
	if step_x != 0:
		next_x = (float(cx) + 0.5 * float(step_x) - from.x) / dir.x
		delta_x = 1.0 / absf(dir.x)
	var next_y := INF
	var delta_y := INF
	if step_y != 0:
		next_y = (float(cy) + 0.5 * float(step_y) - from.y) / dir.y
		delta_y = 1.0 / absf(dir.y)
	var travelled := 0.0
	# A bound on the loop and not on the geometry: a ray crosses at most one edge per 조각 per axis.
	# **A net that can hang prints no verdict at all**, which disarms mutation testing on the whole file.
	for _guard in int(ceil(reach * 2.0)) + 4:
		if absf(next_x - next_y) <= 1e-9:
			travelled = next_x
			cx += step_x
			cy += step_y
			next_x += delta_x
			next_y += delta_y
		elif next_x < next_y:
			travelled = next_x
			cx += step_x
			next_x += delta_x
		else:
			travelled = next_y
			cy += step_y
			next_y += delta_y
		if travelled > reach:
			return out
		if cx < 0 or cy < 0 or cx >= w or cy >= h:
			continue
		out.append(cy * w + cx)
	return out


## The sum of the offsets of `t`'s watery neighbours, unnormalised. Zero means either no water at all
## or water balanced on opposite sides — `seaward_at`'s chain is what tells those two apart.
func _sea_neighbours(t: int) -> Vector2:
	var tx := t % w
	var ty := t / w
	var sum := Vector2.ZERO
	for k in NEIGHBOURS.size():
		var dx := int(NEIGHBOURS[k][0])
		var dy := int(NEIGHBOURS[k][1])
		var nx := tx + dx
		var ny := ty + dy
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if water[ny * w + nx] != 0:
			sum += Vector2(dx, dy)
	return sum


## **Whether a body standing on `from_tile` may walk into `to_tile` — the stair rule, and the only
## place it is written.** The destination must be walkable, and the two levels must be within
## `Rules.MAX_CLIMB_LEVELS` of each other.
##
## ⚠⚠ **This is a NEW name and `passable` is untouched, deliberately.** `passable` used to answer "may
## a body go here" on its own, and the day height arrives that question splits in two. Widening
## `passable`'s meaning in place is exactly the shape that left four checks in 티켓 15 measuring
## nothing while still reading correctly, so the question that changed gets the new word.
##
## ⚠ **The ORIGIN's passability is deliberately not asked**, which is what both existing callers
## already did — they test `passable[nt]` and never `passable[t]`. It is load-bearing rather than lax:
## `flow_field` plants its seed on the target's tile *whatever its passability*, because a target
## still aboard a boat would otherwise give an all-unreachable field and freeze every unit chasing it
## for the rest of the island with nothing logged. Asking the origin here would put that freeze back.
##
## ⚠ **Symmetric in the levels.** `absi` and not a signed test: a wall a body may drop off but not
## climb is a one-way door, and 티켓 19's answer says bodies do not fall.
##
## ⚠ **It binds on DIAGONALS too**, which is what keeps a tier boundary from being cut at a corner —
## `flow_field` and `step_toward` walk all eight neighbours through here.
##
## ⚠⚠ **AND SINCE 2026-08-28 IT REFUSES A SQUEEZE AS WELL** (티켓 19; the user, on the game screen:
## 「이동할때 그냥 벽을 뚫는 문제도 있는상태」). Until then this asked about the DESTINATION alone, so
## two blocked tiles touching corner to corner were one step apart and a body walked straight through
## the seam. **`_water_step_open` has carried the boat's half of this rule all along**, and its own
## header said out loud that the land half did not — that note is now out of date and corrected there.
##
## ⚠⚠ **BOTH shoulders are required, which is stricter than the boat's rule and stricter than 티켓 19
## asked for.** The ticket wanted a refusal only when both shoulders were blocked; a body **moves
## continuously** — `Battle._walk` slides it from tile centre to tile centre — so on a diagonal it is
## physically over both shoulder tiles on the way, and one blocked shoulder is one wall corner walked
## through. `_straight_is_all_water` requires both for exactly this reason and says so.
## ⇒ **Nothing is cut off by it**: a refused diagonal is still two orthogonal steps, and
## `net_tiers._the_real_island_still_has_a_route` is the floor that measures the island did not seal.
##
## ⚠ **The shoulders are asked with the SAME two questions the destination gets** — walkable, and
## within `MAX_CLIMB_LEVELS` of the origin. A shoulder that is passable but a storey up is a wall
## corner too, and letting it through would put the leak back at every plateau corner.
## ⚠ **No recursion**: a shoulder shares one coordinate with the origin, so it is an ORTHOGONAL
## neighbour and never re-enters this branch.
func can_step(from_tile: int, to_tile: int) -> bool:
	var n := w * h
	if from_tile < 0 or to_tile < 0 or from_tile >= n or to_tile >= n:
		return false
	if passable[to_tile] == 0:
		return false
	var from_level := level_of(from_tile)
	if absi(from_level - level_of(to_tile)) > Rules.MAX_CLIMB_LEVELS:
		return false
	var fx := from_tile % w
	var fy := from_tile / w
	var tx := to_tile % w
	var ty := to_tile / w
	if not _stair_face_open(from_tile, to_tile, tx - fx, ty - fy):
		return false
	if fx == tx or fy == ty:
		return true
	return _shoulder_open(from_level, fy * w + tx) and _shoulder_open(from_level, ty * w + fx)


## ⚠⚠ **A STAIR IS ENTERED AND LEFT AT ITS ENDS, NEVER OVER ITS SIDE** (2026-08-28, the user: 「계단
## 옆면으로 오르는게 살짝 마음에 안드네?」). A stair carries an odd notch, so `MAX_CLIMB_LEVELS` alone
## lets a body step onto it from the floor beside it — **walking up the staircase's flank instead of its
## treads**, which is what was on screen.
##
## ⚠ **Along the run's axis, and that is the whole test.** A step whose displacement has no component
## along the climb is a sideways one; a diagonal keeps its axis component and is allowed, and its own
## shoulders are checked afterwards by `can_step`.
##
## ⚠ **Stair-to-stair is free.** A run may be two tiles wide, and two bodies climbing side by side have
## to be able to shuffle across it — 2026-08-27, 「계단이라는 블록이 있어야할듯」, and `_build_runs`'s
## own header says a wide stair is ONE staircase rather than two beside each other.
##
## ⚠ **Nothing about this is drawn separately.** The staircase mesh already presents a solid flank to
## the floor beside it; what was missing was the rule agreeing with the picture.
func _stair_face_open(from_tile: int, to_tile: int, dx: int, dy: int) -> bool:
	var from_run: Array = stair_run_of(from_tile)
	var to_run: Array = stair_run_of(to_tile)
	if from_run.is_empty() and to_run.is_empty():
		return true
	if not from_run.is_empty() and not to_run.is_empty():
		return true
	var run: Array = from_run if to_run.is_empty() else to_run
	var ax: Vector2i = run[0]
	return dx * ax.x + dy * ax.y != 0


## One shoulder of a diagonal: walkable, and within the climb rule of the level the body is leaving.
##
## ⚠ **Both shoulders are inside the grid by construction** — each shares one coordinate with the
## origin and one with the destination, and `can_step` has already range-checked both of those. The
## same argument `_water_step_open`'s header makes, one rule over.
func _shoulder_open(from_level: int, shoulder_tile: int) -> bool:
	if passable[shoulder_tile] == 0:
		return false
	return absi(from_level - level_of(shoulder_tile)) <= Rules.MAX_CLIMB_LEVELS


func is_passable(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return false
	return passable[ty * w + tx] != 0


func tile_point(t: int) -> Vector2:
	if w <= 0:
		return Vector2.ZERO
	return Vector2(t % w, t / w)


func tile_index(tx: int, ty: int) -> int:
	return ty * w + tx


## ⚠⚠ **THE WHOLE WATER HALF OF THIS FILE STOOD HERE AND IT IS DELETED** (2026-08-29).
## `_water_step_open` · `_summon_field` · `_summon_frontier_before` · `can_summon_at` · `summon_centre` ·
## `summon_radius` · `summon_landing_of` · `summon_route` · `_smooth_water_path` ·
## `_straight_is_all_water` are gone, and so are `harbour_tiles`, `summon_hops`, `summon_landing` and
## `summon_field_builds` above them. **It went because the player stopped placing boats**: the summon
## gesture was deleted 2026-08-28, `Battle.summon` lost its last caller with it, and every table here
## became a fact nobody asked. **Boats come back on the BEASTS' side and they get built then** (the
## user, 2026-08-29: 그때 만드는 게 맞을듯).
##
## ⚠⚠ **WHAT TO READ BEFORE WRITING THE BEASTS' CROSSING, each line a measurement:**
##
##  · **The reachable coast is 8-WAY, never 4-way** — the user: *"상륙 못하는 데가 있는 거지 상륙
##    가능한 데가 있는 게 아니야"*. Measured on the shipped islands: the ortho coast is 82 tiles
##    and the 8-way coast is 84 — the two extra are corner beaches, and they are what 「어디든지」 meant.
##  · **The water field is built ONCE per board load and READ per query, never walked per call.**
##    Recomputed per press it was 1536 tiles × 3 harbours a FRAME: a BFS is more expensive than the
##    line test it replaced, not less.
##  · **Ties go to the LOWEST tile index.** Flip that comparison and every landing on every island
##    moves — it was the whole of the determinism, not a detail.
##  · **A boat's route descends the field and is smoothed afterwards**, and the smoothing only cuts a
##    corner when the straight line between the two points is water the whole way.
##  · **The BEACHING hop is not asked.** The last water tile before land is where the hull stops; a
##    rule that demanded the land tile be reachable by water refuses every real shore.



## **What one step from `a` to `b` costs.** The two 조각 are assumed to touch; this is asked only about
## neighbours. `Rules` owns the numbers — see `Rules.STEP_COST_ORTHO`.
func step_cost(a: int, b: int) -> int:
	if w <= 0:
		return Rules.STEP_COST_ORTHO
	if (a % w) != (b % w) and (a / w) != (b / w):
		return Rules.STEP_COST_DIAG
	return Rules.STEP_COST_ORTHO


## Cheapest-first flood from `target_tile` over passable tiles, 8-way. Cost is in `Rules.STEP_COST_*`
## units; unreachable tiles keep `UNREACHABLE`.
##
## ⚠⚠ **IT WAS A HOP COUNT UNTIL 2026-08-29 AND THAT IS WHY WALKS ARCED** (티켓 37). Every one of the
## eight neighbours cost **1**, so **a diagonal was free**: a straight line across open ground and a
## detour to the edge of the island were the same price, and among all those equal-cost routes the tie
## went to whichever offset `NEIGHBOURS` happens to list first — north-west. The user saw the result.
##
## ⚠⚠ **THE HEAP BUYS SPEED, NOT CORRECTNESS, AND THE FIRST DRAFT OF THIS HEADER CLAIMED OTHERWISE.**
## What makes the answer right under weighted edges is the RE-PUSH below: a 조각 goes back on the queue
## every time its value improves, so the flood converges whatever order it pops in. **Measured
## 2026-08-29: scramble the heap, or swap it for a plain first-in-first-out queue, and all 288 조각 of
## `net_walk`'s empty-board field stay exact; take the re-push away as well and 223 of them go wrong.**
## ⇒ **Cheapest-first is what stops a 조각 being expanded several times** — without it this is
## Bellman-Ford where it could be Dijkstra. **Nothing in the nets can see the difference except the
## heap's own check**, so do not read the octile row as cover for this line. See `IntHeap` for why a heap
## and not a bucket queue.
##
## ⚠ **`UNREACHABLE` is four orders of magnitude clear of any real value.** The shipped 48 x 32 board is
## 1536 조각, so the worst conceivable route is under `1536 * STEP_COST_DIAG`, about 21500, against
## `1 << 30`.
##
## **Reserved tiles are traversable here on purpose.** If occupancy entered the field, every field
## would have to be rebuilt the moment anybody moved; instead the field is terrain-only and cached,
## and `step_toward` is where occupancy is honoured.
func flow_field(target_tile: int) -> PackedInt32Array:
	var n := w * h
	var field := PackedInt32Array()
	field.resize(n)
	field.fill(UNREACHABLE)
	if target_tile < 0 or target_tile >= n:
		return field
	# The seed is planted whatever the target's own passability. A target standing on an impassable
	# tile — a soldier still aboard a boat — would otherwise produce an all-unreachable field, and
	# every unit asking for it stands still for the rest of the island with nothing logged.
	field[target_tile] = 0
	var heap := IntHeap.new()
	heap.push(0, target_tile)
	while not heap.is_empty():
		var t := heap.pop_value()
		var cost := heap.last_cost
		# ⚠ **Lazy deletion.** The heap has no decrease-key, so a 조각 reached more cheaply later is
		# queued a second time and the earlier, dearer pair is still waiting. Expanding it again is
		# harmless but wasted work — and reading `cost` from the pair rather than from `field` is what
		# makes the skip possible at all.
		if cost > int(field[t]):
			continue
		var tx := t % w
		var ty := t / w
		for k in NEIGHBOURS.size():
			var nx := tx + int(NEIGHBOURS[k][0])
			var ny := ty + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			# ⚠ **`can_step` and not `passable[nt]`.** The height gap is refused HERE, in the field
			# itself, and not by the walker afterwards: a field that reached a plateau over its own
			# wall would send every unit to stand under it, which is what "walk to the stair" has to
			# come out of. The plateau is `UNREACHABLE` until a stair is authored.
			if not can_step(t, nt):
				continue
			var next_cost := cost + (Rules.STEP_COST_DIAG if nx != tx and ny != ty
					else Rules.STEP_COST_ORTHO)
			if int(field[nt]) <= next_cost:
				continue
			field[nt] = next_cost
			heap.push(next_cost, nt)
	return field


## **Which of two candidate 조각 a body standing on `cur` should step onto — the tie-break, written once
## and shared by the descent and the path pull.** `true` when `cand` beats `best`; `best` of -1 means
## nothing has been chosen yet.
##
## The keys, in order:
##
## 1. **The total cost of the route THROUGH the candidate** — `field[cand] + step_cost(cur, cand)`.
## 2. **The smaller perpendicular deviation** from the straight line to `target_tile`.
## 3. **The larger dot product** — of two steps equally off the line, the one that gets nearer wins.
## 4. **The lower 조각 index.** Determinism, and nothing else.
##
## ⚠⚠ **KEY 1 IS THE ROUTE TOTAL AND NOT `field[cand]`, AND THE DIFFERENCE IS THE WHOLE OF WHETHER THIS
## WORKS** (measured 2026-08-29, on 티켓 37's own first draft). Ranked by `field[cand]` alone a diagonal
## neighbour is always `STEP_COST_DIAG` cheaper and an orthogonal one always `STEP_COST_ORTHO`, so **the
## diagonal wins outright and there is never a tie for the other keys to break** — the body spends all its
## diagonals first and then goes straight, which is a bent walk with every arrival check green. Every step
## on an optimal route totals exactly `field[cur]`, so ranking by the total makes **all the optimal steps
## tie**, which is the condition keys 2 and 3 were written for.
##
## ⚠ **With no target (`target_tile` of -1) keys 2 and 3 are skipped** and the rule is 「lowest total cost,
## then lowest 조각 index」. That is not what this function's ancestor did — it took the lowest field value
## and then whatever `NEIGHBOURS` listed first — so a three-argument caller does step somewhere else than
## it used to. It is a better descent and the callers were read before it landed.
func _better_step(field: PackedInt32Array, cur: int, target_tile: int, cand: int, best: int) -> bool:
	if best < 0:
		return true
	var cost_a := int(field[cand]) + step_cost(cur, cand)
	var cost_b := int(field[best]) + step_cost(cur, best)
	if cost_a != cost_b:
		return cost_a < cost_b
	if target_tile >= 0:
		var cx := cur % w
		var cy := cur / w
		var dx := (target_tile % w) - cx
		var dy := (target_tile / w) - cy
		var ax := (cand % w) - cx
		var ay := (cand / w) - cy
		var bx := (best % w) - cx
		var by := (best / w) - cy
		# The cross product is the step's own component ACROSS the line to the goal — the deviation the
		# arc was made of. The dot is its component ALONG it.
		var cross_a := absi(ax * dy - ay * dx)
		var cross_b := absi(bx * dy - by * dx)
		if cross_a != cross_b:
			return cross_a < cross_b
		var dot_a := ax * dx + ay * dy
		var dot_b := bx * dx + by * dy
		if dot_a != dot_b:
			return dot_a > dot_b
	return cand < best


## One step down `field`. `from` is in **tile units, tile centres on integers** — not pixels; the view
## multiplies by the tile size, and mixing the two is the 4.8x error this repo has already paid for.
##
## Picks the best neighbour that is passable, strictly cheaper than the tile the body stands on, and
## either unreserved or already this unit's; reserves it, releases the tile behind, and returns the point
## to walk toward. **If every candidate is taken the unit's own position comes back and it stands** —
## that is the queue at a neck.
## ⚠ **`keep_level` is -1 for everybody except an enemy holding high ground.** At 0 or more the step
## must also LAND on that level, which is what stops a defender posted on a plateau walking down its
## own stair to meet the attackers — 티켓 19's positional advantage only exists if the side holding it
## stays there. **An optional argument rather than a second walker**: the tie-breaks, the reservation
## swap and the queue-at-a-neck behaviour are the same, and a second copy of them would drift.
## ⚠ **`target_tile` is the 조각 the field was built from**, and it only feeds `_better_step`'s deviation
## keys. Left at -1 the descent still works and still terminates; it simply has nothing to be straight
## against.
func step_toward(unit_id: int, from: Vector2, field: PackedInt32Array,
		keep_level: int = -1, target_tile: int = -1) -> Vector2:
	var n := w * h
	if n == 0 or field.size() != n:
		return from
	var cx := clampi(int(round(from.x)), 0, w - 1)
	var cy := clampi(int(round(from.y)), 0, h - 1)
	var cur := cy * w + cx
	hold(unit_id, cur)
	var best := -1
	# ⚠ **The admission test, and it is NOT key 1.** Strictly cheaper than where the body stands: an `<=`
	# here lets a unit already on the target tile step off onto an equal-cost neighbour and oscillate
	# forever, which reads as jitter rather than as a bug. `_better_step` only ranks what survives this.
	#
	# ⚠⚠ **AND THAT SENTENCE IS UNMEASURED. NO CHECK ANYWHERE REDDENS IF THIS `>=` BECOMES `>`** —
	# measured 2026-08-29 by an independent pass: the whole net round stayed green AND a 100-second run
	# on the real island came out identical to the decimal. **It is written down rather than covered**,
	# because a check built around this one mutation would pass because somebody wrote it around the
	# mutation, which is worth less than an honest gap. ⇒ **Do not relax it on the grounds that nothing
	# barks.** The oscillation it stops was paid for once and the payment is not in the nets.
	var cur_cost := int(field[cur])
	for k in NEIGHBOURS.size():
		var nx := cx + int(NEIGHBOURS[k][0])
		var ny := cy + int(NEIGHBOURS[k][1])
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		var nt := ny * w + nx
		# ⚠ **Asked here as well as in `flow_field`, and that is not a second copy of the rule** — it is
		# the same one function, asked about the tile the unit is actually standing on. The field is
		# built once per target; a unit shoved or landed onto a tier the field never expanded from
		# would otherwise read a neighbour's cost and step over the wall to get at it.
		if not can_step(cur, nt):
			continue
		if keep_level >= 0 and level_of(nt) != keep_level:
			continue
		if not can_hold(nt, unit_id):
			continue
		if int(field[nt]) >= cur_cost:
			continue
		if _better_step(field, cur, target_tile, nt, best):
			best = nt
	if best == -1:
		_release_except(unit_id, cur, cur)
		return from
	return _commit_step(unit_id, cur, best)


## **The same commit, for a 조각 the CALLER names** — the straightened route's step. Returns the 조각's
## point on success, or `from` unchanged on a refusal, **releasing nothing** when it refuses: the caller
## falls straight through to `step_toward`, which does its own release when it also refuses.
##
## ⚠⚠ **THE ADJACENCY TEST IS REQUIRED AND `can_step` DOES NOT SUPPLY IT.** Measured 2026-08-29:
## `can_step` asks about bounds, passability, the level gap, the stair face and a diagonal's shoulders,
## **and never whether the two 조각 touch** — it answers `true` for a pair fourteen 조각 apart. It has been
## safe only because both older callers hand it one of eight neighbours. This one takes a 조각 named from
## a stored list, and a stale index would otherwise glide a body several 조각 in a straight line holding
## only the endpoints — through whatever stands between, with every reservation check green.
func step_along(unit_id: int, from: Vector2, next_tile: int, keep_level: int = -1) -> Vector2:
	var n := w * h
	if n == 0:
		return from
	var cx := clampi(int(round(from.x)), 0, w - 1)
	var cy := clampi(int(round(from.y)), 0, h - 1)
	var cur := cy * w + cx
	hold(unit_id, cur)
	if next_tile < 0 or next_tile >= n or next_tile == cur:
		return from
	if absi(next_tile % w - cx) > 1 or absi(next_tile / w - cy) > 1:
		return from
	if not can_step(cur, next_tile):
		return from
	if keep_level >= 0 and level_of(next_tile) != keep_level:
		return from
	if not can_hold(next_tile, unit_id):
		return from
	return _commit_step(unit_id, cur, next_tile)


## **The two-tile swap, written once.** Claim the 조각 being walked into, then let go of everything but
## the pair. ⚠ A second copy of these two lines is how a body comes to hold three 조각 and halve every
## doorway with nothing on screen to explain it.
func _commit_step(unit_id: int, cur: int, dest: int) -> Vector2:
	hold(unit_id, dest)
	_release_except(unit_id, cur, dest)
	return Vector2(dest % w, dest / w)


## **The 조각 a body would step through walking down `field` from `from_tile`, as far as `target_tile`.**
## Empty when the field is the wrong size, the 조각 is off the board, or `from_tile` is `UNREACHABLE`.
## Otherwise `[from_tile, ..., target_tile]`, using the same tie-break the descent uses.
##
## ⚠⚠ **IT RESERVES NOTHING, HOLDS NOTHING AND RELEASES NOTHING.** It is a question about the board, and a
## query that wrote the reservation table would put a body's own hold in the way of its own route.
## ⚠ **It ignores reservations and `keep_level` on purpose.** The field is terrain-only, and a list built
## once at the moment of the order would otherwise bake in whoever happened to be standing there.
## ⚠ **Bounded by `w * h` iterations.** A strictly-decreasing walk cannot loop, so the bound is a guard and
## not a rule; reaching it means a defect, and the partial list comes back rather than the round hanging.
func path_from(field: PackedInt32Array, from_tile: int, target_tile: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := w * h
	if n == 0 or field.size() != n:
		return out
	if from_tile < 0 or from_tile >= n:
		return out
	if int(field[from_tile]) == UNREACHABLE:
		return out
	var cur := from_tile
	out.append(cur)
	var guard := 0
	while cur != target_tile:
		guard += 1
		if guard > n:
			break
		var cx := cur % w
		var cy := cur / w
		var cur_cost := int(field[cur])
		var best := -1
		for k in NEIGHBOURS.size():
			var nx := cx + int(NEIGHBOURS[k][0])
			var ny := cy + int(NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nt := ny * w + nx
			if not can_step(cur, nt):
				continue
			if int(field[nt]) >= cur_cost:
				continue
			if _better_step(field, cur, target_tile, nt, best):
				best = nt
		if best == -1:
			break
		out.append(best)
		cur = best
	return out


## **The 8-connected line from `a_tile` to `b_tile`, or empty when a body could not walk it.** `a_tile`
## itself is NOT in the list — the caller already stands on it.
##
## ⚠⚠ **IT IS AN OCTILE LINE OF EXACTLY `max(|dx|, |dy|)` STEPS AND NOT A DENSE SAMPLE.** Measured
## 2026-08-29 on 티켓 37's own first draft: sampling the segment every quarter 조각 and rounding each axis
## on its own **emits a separate orthogonal step for each axis crossing**, so (2,10) -> (20,2) came out at
## 24 steps and sixteen turns against the octile optimum of 18 — **the straightener made the walk more
## crooked.** Interpolating the whole step index instead moves each axis by at most one per step, giving
## exactly `min(|dx|,|dy|)` diagonals, which is the cheapest any 8-connected route between the two can be.
##
## ⚠⚠ **EVERY STEP IS ASKED THROUGH `can_step`, AND THAT IS THE WHOLE POINT OF THE FUNCTION.** A plain
## passability test here walks a body up a staircase's flank — a stair may be entered only at its ends —
## which is 티켓 22's subject and must not be fed.
##
## ⚠ **A thin line and not a supercover, and that is safe**: consecutive 조각 are 8-neighbours by
## construction, and `can_step` refuses a diagonal whose shoulders are blocked, so the corner cannot be cut.
func line_tiles(a_tile: int, b_tile: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := w * h
	if n == 0 or a_tile < 0 or b_tile < 0 or a_tile >= n or b_tile >= n:
		return out
	var ax := a_tile % w
	var ay := a_tile / w
	var dx := (b_tile % w) - ax
	var dy := (b_tile / w) - ay
	var steps := maxi(absi(dx), absi(dy))
	if steps == 0:
		return out
	var prev := a_tile
	for i in range(1, steps + 1):
		var x := ax + int(round(float(dx) * float(i) / float(steps)))
		var y := ay + int(round(float(dy) * float(i) / float(steps)))
		var nt := y * w + x
		if not can_step(prev, nt):
			return PackedInt32Array()
		out.append(nt)
		prev = nt
	return out


## **The same route with its corners pulled out.** Greedy from the front: standing at `path[i]`, take the
## furthest `j` whose straight line from `path[i]` is walkable, append that line, and carry on from `j`.
## A route of two 조각 or fewer comes back unchanged.
##
## ⚠ **The result is never longer than the input**, and that is a property rather than a per-fixture
## coincidence: a straight line between two 조각 costs the octile minimum, which no 8-connected route
## between them can beat. `net_walk` asserts it, because 「the smoothing made it longer」 is the one way
## this fails invisibly.
## ⚠ **It hands back an ADJACENT-조각 list, never waypoints.** The body still steps one 조각 at a time, so
## reservation, the two-tile hold and the queue at a neck are all untouched — only the list is straighter.
## A waypoint list would have the walker reserve 조각 it never names.
## ⚠ It is O(n²) in 조각 and a route on this board is under sixty. A funnel algorithm buys nothing here.
func string_pull(path: PackedInt32Array) -> PackedInt32Array:
	if path.size() <= 2:
		return path
	var out := PackedInt32Array()
	out.append(int(path[0]))
	var i := 0
	while i < path.size() - 1:
		var j := path.size() - 1
		var seg := PackedInt32Array()
		while j > i + 1:
			seg = line_tiles(int(path[i]), int(path[j]))
			if not seg.is_empty():
				break
			j -= 1
		if j == i + 1:
			seg = line_tiles(int(path[i]), int(path[j]))
			if seg.is_empty():
				# ⚠ **The input's own step, kept verbatim.** Reaching here means the route handed in was
				# not walkable to begin with; inventing a different 조각 would be this function deciding
				# something it has no business deciding, so the step comes through unchanged and the
				# walker refuses it later exactly as it would have.
				seg = PackedInt32Array()
				seg.append(int(path[j]))
		out.append_array(seg)
		i = j
	return out


## Every tile this unit holds goes back. Called on death and on boarding.
##
## Rescans `reserved` in full rather than walking `_held`, and the reason held for as long as `battle`
## wrote the table by hand: a tile that never entered `_held` would stay locked for the rest of the
## island with no unit standing on it. **`battle` goes through `hold` now** (2026-08-30) and the rescan
## stays anyway — `reserved` is the authority and `_held` is the fast path, and a release that trusted
## the fast path would leak exactly the slot the fast path had already lost.
##
## ⚠ **The loop walks SLOTS and not 조각.** A unit holds at most one slot per 조각, so clearing every
## entry that names it is the same set either way — but the index is not a tile number and nothing here
## may treat it as one.
func release_all(unit_id: int) -> void:
	for k in reserved.size():
		if reserved[k] == unit_id:
			reserved[k] = -1
	_held.erase(unit_id)


## Claims a slot in `tile` unless the 조각 is full. A 조각 this unit is already standing in is adopted
## rather than claimed twice, so a body never holds two slots of one 조각 and never widens a neck by
## being asked about it. **Answers whether the unit stands there when the call returns.**
##
## ⚠⚠ **PUBLIC SINCE 2026-08-30, and `battle` writing `reserved` by hand is what it replaced.** Three
## sites there set one int and relied on `release_all`'s full rescan to undo it; with slots there is a
## free one to find first, and three copies of that search would be three chances to pick a different
## slot for the same body.
func hold(unit_id: int, tile: int) -> bool:
	var k := slot_of(tile, unit_id)
	if k < 0:
		k = _free_slot(tile)
		if k < 0:
			return false
		reserved[tile * Rules.TILE_CAPACITY + k] = unit_id
	var held: Array = _held.get(unit_id, [])
	if not held.has(tile):
		held.append(tile)
	_held[unit_id] = held
	return true


## **Takes the WHOLE 조각 for one unit — what a building does, and nothing that walks.** Answers
## whether the 조각 came out wholly this unit's; a slot somebody else is standing in is left alone and
## turns the answer false, because evicting a body from under itself is the shape that puts a walker
## inside a wall with every reservation check green.
##
## ⚠⚠ **WITHOUT THIS THE 성채 STOPPED BEING A WALL THE DAY A 조각 HELD MORE THAN ONE BODY.** One id in
## one slot leaves `Rules.TILE_CAPACITY - 1` slots free, and every body on the island would walk into
## the house through them.
func fill(unit_id: int, tile: int) -> bool:
	var cap := Rules.TILE_CAPACITY
	if tile < 0 or tile >= w * h:
		return false
	var base := tile * cap
	var whole := true
	for k in cap:
		if reserved[base + k] == -1:
			reserved[base + k] = unit_id
		elif reserved[base + k] != unit_id:
			whole = false
	var held: Array = _held.get(unit_id, [])
	if not held.has(tile):
		held.append(tile)
	_held[unit_id] = held
	return whole


## **Which slot of `tile` this unit stands in, or -1.** ⚠ **It is a place inside the 조각 and not a
## name**: the view spreads a crowd by it, and it changes when the body ahead of it leaves.
func slot_of(tile: int, unit_id: int) -> int:
	var cap := Rules.TILE_CAPACITY
	if tile < 0 or tile >= w * h:
		return -1
	var base := tile * cap
	for k in cap:
		if reserved[base + k] == unit_id:
			return k
	return -1


## Whether this unit is standing in `tile`.
func holds(tile: int, unit_id: int) -> bool:
	return slot_of(tile, unit_id) >= 0


## **How many bodies stand in `tile` right now.** Zero on an off-board 조각, which is the same answer
## an empty one gives — nothing here distinguishes them and nothing asks.
func hold_count(tile: int) -> int:
	var cap := Rules.TILE_CAPACITY
	if tile < 0 or tile >= w * h:
		return 0
	var base := tile * cap
	var n := 0
	for k in cap:
		if reserved[base + k] != -1:
			n += 1
	return n


## Whether one more body would fit in `tile`.
func has_room(tile: int) -> bool:
	return _free_slot(tile) >= 0


## Whether this unit may stand in `tile` — it already does, or there is room for it.
## **This is the admission test every walker asks**, and it is one function so the field walk and the
## straightened route cannot come to disagree about what a full 조각 is.
func can_hold(tile: int, unit_id: int) -> bool:
	return slot_of(tile, unit_id) >= 0 or _free_slot(tile) >= 0


## The lowest empty slot of `tile`, or -1 when it is full or off the board.
##
## ⚠⚠ **LOWEST AND NOT ANY, AND THAT IS THE WHOLE OF DETERMINISM HERE.** A body's place inside a 조각
## has to be a function of who was already standing there — pick any free slot and the same seed stops
## giving the same fight, and the crowd the view draws off these indices reshuffles every frame.
func _free_slot(tile: int) -> int:
	var cap := Rules.TILE_CAPACITY
	if tile < 0 or tile >= w * h:
		return -1
	var base := tile * cap
	for k in cap:
		if reserved[base + k] == -1:
			return k
	return -1


func _release_except(unit_id: int, keep_a: int, keep_b: int) -> void:
	if not _held.has(unit_id):
		return
	var kept := []
	for raw in _held[unit_id]:
		var tile := int(raw)
		if tile == keep_a or tile == keep_b:
			if not kept.has(tile):
				kept.append(tile)
			continue
		var k := slot_of(tile, unit_id)
		if k >= 0:
			reserved[tile * Rules.TILE_CAPACITY + k] = -1
	_held[unit_id] = kept
