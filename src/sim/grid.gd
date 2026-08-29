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
	_hold(unit_id, cur)
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
		if reserved[nt] != -1 and reserved[nt] != unit_id:
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
	_hold(unit_id, cur)
	if next_tile < 0 or next_tile >= n or next_tile == cur:
		return from
	if absi(next_tile % w - cx) > 1 or absi(next_tile / w - cy) > 1:
		return from
	if not can_step(cur, next_tile):
		return from
	if keep_level >= 0 and level_of(next_tile) != keep_level:
		return from
	if reserved[next_tile] != -1 and reserved[next_tile] != unit_id:
		return from
	return _commit_step(unit_id, cur, next_tile)


## **The two-tile swap, written once.** Claim the 조각 being walked into, then let go of everything but
## the pair. ⚠ A second copy of these two lines is how a body comes to hold three 조각 and halve every
## doorway with nothing on screen to explain it.
func _commit_step(unit_id: int, cur: int, dest: int) -> Vector2:
	_hold(unit_id, dest)
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
