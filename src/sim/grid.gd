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
var reserved := PackedInt32Array()     # tile -> unit id, or -1

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
	reserved.resize(n)
	reserved.fill(-1)

	# Built once per load rather than per tile: the string is assembled from a table, and 1536 tiles
	# rebuilding it would be a walk of `SPAWN_ROWS` per tile for an answer that cannot change.
	_runs = {}
	_runs_built = 0
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



## Breadth-first from `target_tile` over passable tiles, 8-way. Cost is hop count; unreachable tiles
## keep `UNREACHABLE`.
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
	var queue := PackedInt32Array()
	queue.append(target_tile)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var tx := t % w
		var ty := t / w
		var next_cost := field[t] + 1
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
			if field[nt] <= next_cost:
				continue
			field[nt] = next_cost
			queue.append(nt)
	return field


## One step down `field`. `from` is in **tile units, tile centres on integers** — not pixels; the view
## multiplies by the tile size, and mixing the two is the 4.8x error this repo has already paid for.
##
## Picks the neighbour with the lowest field value that is passable and either unreserved or already
## this unit's, reserves it, releases the tile behind, and returns the point to walk toward. **If every
## candidate is taken the unit's own position comes back and it stands** — that is the queue at a neck.
## ⚠ **`keep_level` is -1 for everybody except an enemy holding high ground.** At 0 or more the step
## must also LAND on that level, which is what stops a defender posted on a plateau walking down its
## own stair to meet the attackers — 티켓 19's positional advantage only exists if the side holding it
## stays there. **An optional argument rather than a second walker**: the tie-breaks, the reservation
## swap and the queue-at-a-neck behaviour are the same, and a second copy of them would drift.
func step_toward(unit_id: int, from: Vector2, field: PackedInt32Array,
		keep_level: int = -1) -> Vector2:
	var n := w * h
	if n == 0 or field.size() != n:
		return from
	var cx := clampi(int(round(from.x)), 0, w - 1)
	var cy := clampi(int(round(from.y)), 0, h - 1)
	var cur := cy * w + cx
	_hold(unit_id, cur)
	var best := -1
	var best_cost := field[cur]
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
		if reserved[nt] != -1 and reserved[nt] != unit_id:
			continue
		# Strictly better than where it stands. An `<=` here lets a unit already on the target tile
		# step off onto an equal-cost neighbour and oscillate forever, which reads as jitter rather
		# than as a bug.
		if field[nt] >= best_cost:
			continue
		best = nt
		best_cost = field[nt]
	if best == -1:
		_release_except(unit_id, cur, cur)
		return from
	_hold(unit_id, best)
	# The swap: the tile behind is freed only once the unit's rounded position has moved onto the tile
	# it was walking into, so the two-tile hold is never wider than two.
	_release_except(unit_id, cur, best)
	return Vector2(best % w, best / w)


## Every tile this unit holds goes back. Called on death and on boarding.
##
## Rescans `reserved` in full rather than walking `_held`: `battle` may write `reserved` directly when
## it places a landing soldier, and a tile that never entered `_held` would stay locked for the rest of
## the island with no unit standing on it.
func release_all(unit_id: int) -> void:
	for t in reserved.size():
		if reserved[t] == unit_id:
			reserved[t] = -1
	_held.erase(unit_id)


## Claims `tile` unless someone else already holds it. A tile already marked with this unit's id but
## missing from `_held` is adopted, so a direct write by `battle` still gets released later.
func _hold(unit_id: int, tile: int) -> void:
	if reserved[tile] != -1 and reserved[tile] != unit_id:
		return
	reserved[tile] = unit_id
	var held: Array = _held.get(unit_id, [])
	if not held.has(tile):
		held.append(tile)
	_held[unit_id] = held


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
		if reserved[tile] == unit_id:
			reserved[tile] = -1
	_held[unit_id] = kept
