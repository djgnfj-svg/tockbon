extends RefCounted
## The body — movement, gravity integration, terrain collision, step offset. It only **reads** the grid.
##
## **Extracted out of `character.gd`** (`monsters-minimum` stage 0). Making the character and the monsters
##  use the same five lines (gravity -> walk -> fall -> recompute grounding) is this file's reason to exist —
##  split in two and a mismatch like "only the monster gets stuck on the ledge it broke" is guaranteed to happen.
##
## **It holds none of the size, step height or gravity. All of them are constructor or call arguments.**
##  Keeping them as constants like `W_PX` or `GRAVITY_PX` breaks — at parse time — the nets that read
##  `Character.W_PX == 20` and friends **statically** (`net_character`, `net_damage`, `net_sprite`,
##  `net_staff`, `net_tables`), and `load()` is not null on a parse failure, so **they do not go red,
##  they disappear** (the pass count silently drops) — the implementer then goes and deletes those assertions,
##  and with them goes the defense `net_sprite` wrote for itself ("without this, anyone can put `W_PX` back to
##  32 and every net stays green"). => The character **keeps its own constants** and passes them to the
##  constructor and the call sites.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## Reading the notification's coordinate system (fixed point) needs that constant — for the same reason as
##  `character.gd`, referencing `src/sim/` is inside the contract (what is blocked is only `src/view/` and `src/stage/`).
const SpellSim := preload("res://src/sim/spell_sim.gd")
## Needed so `standing_in_water` can read `Mat.WATER` and `Mat.FLAG_SHALLOW` — the same door as above.
const Mat := preload("res://src/sim/cell_materials.gd")

## Top-left px. **Integers** — the fractional part is held by `_rem_*`.
##  Leave the position fractional and the box straddles a cell boundary by half a cell, and then the landing
##  height differs by up to 1px every time.
var x := 0
var y := 0
var vy := 0.0
var on_ground := false

var w_px: int          # **Not changed after construction**
var h_px: int
var step_cells: int
var step_px: int

## Movement that has not reached 1px yet. **Without this, per-frame movement gets truncated to an integer
##  every time** and the real speed silently slows down.
var _rem_x := 0.0
var _rem_y := 0.0


## **No size validity check is added.** The failure of swapping the arguments (`h, w`) is caught **by value**
##  by `net_character`'s "blocked by an 8-cell wall" and "stops flush against a 3-cell ledge" — add a guard and
##  the guard intercepts what the net was measuring, and that is a false knob.
func _init(box_w: int, box_h: int, step: int) -> void:
	w_px = box_w
	h_px = box_h
	step_cells = step
	step_px = step * Tuning.CELL_PX


## Reverts only `x`, `y`, `vy`, `on_ground` and `_rem_*`. Things like HP and invulnerability are the caller's
##  job (`character.gd` and others) — the body knows only the body.
func place(px: int, py: int) -> void:
	x = px
	y = py
	vy = 0.0
	_rem_x = 0.0
	_rem_y = 0.0
	on_ground = false


func center() -> Vector2:
	return Vector2(x + w_px * 0.5, y + h_px * 0.5)


## Gravity is taken as an argument too. Do not put a `GRAVITY_PX` constant here — it is exactly the same trap
##  as `W_PX`. `net_character` reads
##  `Character.JUMP_VY_PX * Character.JUMP_VY_PX / (2.0 * Character.GRAVITY_PX)` **statically** — that is the
##  only automatic detector biting "double just one of `GRAVITY` and `JUMP_VY` and the reachable height becomes
##  4x or half, with no error raised".
func apply_gravity(dt: float, gravity_px: float, max_fall_px: float) -> void:
	vy = minf(vy + gravity_px * dt, max_fall_px)


## Horizontal. If blocked, try the **step offset**.
## **If blocked, the remainder is discarded** — hold onto it and the remainder piles up while pressed against
##  a wall, then the body teleports a few px the moment the wall disappears.
## **Standing still discards the remainder too — otherwise a stopped body shivers 1px forever.**
##  `roundi` carries the leftover as a signed value: stop walking with `_rem_x` near 0.5 and every later
##  frame rounds it to +1, subtracts it to -0.5, rounds that to -1, and the body oscillates x by one pixel
##  with `dx` exactly 0. **Nothing barks** — position stays within a pixel of correct and the eye reads it as
##  sprite jitter, if it reads it at all.
##  Found by the rooster's wind-up: "it does not move a single pixel while telegraphing" measured **87px of
##  movement** across a run. **The hen has been doing this since it learned to stop at range**, and the
##  character does it whenever the key is released.
func move_x(grid: CellGrid, dx: float) -> void:
	if dx == 0.0:
		_rem_x = 0.0
		return
	_rem_x += dx
	var n := roundi(_rem_x)
	_rem_x -= n
	if n == 0:
		return
	var sgn := signi(n)
	# Push 1px at a time — pushing all at once and backing out loses "how far could it actually get" on thick walls.
	for _i in absi(n):
		if box_free(grid, x + sgn, y):
			x += sgn
			continue
		if not _try_step_up(grid, sgn):
			_rem_x = 0.0
			return


## **Not allowed in mid-air.** Otherwise, while pressed against a wall, it climbs the wall rather than a ledge.
## It also checks that the spot to rise into (`y - lift`) is empty — bump your head climbing into a narrow gap
##  under a ceiling and the body gets stuck in the terrain.
func _try_step_up(grid: CellGrid, dx: int) -> bool:
	if not on_ground:
		return false
	for lift in range(1, step_px + 1):
		if box_free(grid, x, y - lift) and box_free(grid, x + dx, y - lift):
			x += dx
			y -= lift
			return true
	return false


## Vertical. true if blocked (the caller sets `vy` to 0).
func move_y(grid: CellGrid, dy: float) -> bool:
	_rem_y += dy
	var n := roundi(_rem_y)
	_rem_y -= n
	if n == 0:
		return false
	var sgn := signi(n)
	for _i in absi(n):
		if not box_free(grid, x, y + sgn):
			_rem_y = 0.0
			return true
		y += sgn
	return false


func grounded(grid: CellGrid) -> bool:
	return not box_free(grid, x, y + 1)


## **"Is it solid" is asked of the grid** (`grid.is_solid`). Deciding it again here with `mat_at() != EMPTY`
##  makes two copies of the rule, and the day materials grow it becomes "bolts pass through but the body is blocked".
## The last pixel the box covers is `px + w_px - 1`. Drop the `- 1` and it reads one extra column when flush
##  against the boundary, so it **stops 1px off the wall.**
## Negative division truncates toward 0 in GDScript (`-1 / 4 == 0`) — the cell coordinate jumps one cell
##  outside the grid's left and top edges. `floori` forces flooring.
func box_free(grid: CellGrid, px: int, py: int) -> bool:
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + h_px - 1) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if grid.is_solid(cx, cy):
				return false
	return true


# ══════════════════════════════════════════════════════════════════
#  Was I hit · am I on fire — **the second extraction of `monsters-minimum` stage 3**
# ══════════════════════════════════════════════════════════════════
# Moved here from `character.gd`. Monsters have the same box shape, so keeping two copies
# guarantees "only the monster never gets hit" — acceptance 1 is re-hung here (zero behavior change).

## **It looks at the one row under the feet too. That single row is this feature's life.**
##  The cells you are standing in are **empty, so their fuel is 0**, and the fire is attached to the
##  **wood cells under your feet.**
##  **Leave it out and the code runs and a net can even be written, but nothing happens in the game at all.**
## The range is the same as the row `grounded()` looks at — the meaning of "standing on" does not get two copies.
func standing_in_fire(grid: CellGrid) -> bool:
	var cx0 := floori(x / float(Tuning.CELL_PX))
	var cx1 := floori((x + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(y / float(Tuning.CELL_PX))
	var cy1 := floori((y + h_px) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			# **"Is it burning" is asked of the grid** — cracking the flag open directly here makes two copies of the rule.
			if grid.is_burning(cx, cy):
				return true
	return false


## **Am I in water — the only detector for infinite jumping underwater** (`water-jump-and-escape.md` stage 1).
##  **Placed next to `standing_in_fire` (above) in exactly the same shape** — if the range (box + one row under
##  the feet) differs, you get "fire is extinguished but the jump does not work" and nobody can explain the
##  mismatch (the plan's "which cells does it look at").
##
## **Depth is split by `FLAG_SHALLOW`** — the very flag the renderer looks at when painting shallow water
##  brighter, and the same line `_deep_water` (`cell_grid.gd`) uses to extinguish fire. => "the jump only works
##  in the dark navy" is **already drawn on screen.** Measuring `aux_at() > WATER_WET` directly gives the same
##  answer today, but then color, fire-proofing and jumping look at three copies of the line (the plan already
##  recorded that price).
func standing_in_water(grid: CellGrid) -> bool:
	var cx0 := floori(x / float(Tuning.CELL_PX))
	var cx1 := floori((x + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(y / float(Tuning.CELL_PX))
	var cy1 := floori((y + h_px) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if grid.mat_at(cx, cy) == Mat.WATER and (grid.flag_at(cx, cy) & Mat.FLAG_SHALLOW) == 0:
				return true
	return false


## **Current — reads the amount difference of the columns just outside left and right directly. It leaves
##  nothing in the grid** (`docs/design/water.md`, "water pushes the character", "a design judgment was made" —
##  it rebuilds here the `diff` that `_water_share` already computes and throws away). **Since it only reads,
##  it is not outside the folder contract** — the character writing or erasing water is what would cross the
##  boundary (`src/actor/` float -> `src/sim/` integer).
##
## **The range is exactly the same as `standing_in_water` (above)** — differ and you get "jumping uses this
##  range, the current uses another", and nobody can explain the mismatch.
##
## Returns a signed integer. **Positive pushes right** (a heavier left column pushes you to the right).
## **It divides by the row count before returning** — even as the box height (row count) grows, the return value
##  must stay in the range of "one row's maximum difference (255)" so that `character.gd`'s `WATER_PUSH_PX`
##  means "the speed when the amount difference is at maximum".
##  => It is an **average**, not a sum. The `WATER_MIN_DIFF` threshold is applied to the sum by multiplying
##  `x rows` — **`|sum| <= 4*rows` and `|average| <= 4` are the same equation.** Applying it either way gives
##  the same result — applying it before the division is just to avoid shaving one more time with integer division.
## **The threshold reuses `WATER_MIN_DIFF` (the constant of stopping) verbatim.** Stand up a new threshold and
##  you get "the water stopped but I am being pushed" — `_water_share` does not move anything at or below that
##  line, so a pool at equilibrium has a left-right difference below that line in principle (using the same
##  constant makes that follow for free).
## **It does not add the `_aux` of non-water cells** — a burning cell's `_aux` holds "remaining fuel"
##  (`cell_materials.gd`, the "_aux" section). Add without the `mat_at` check and fire contaminates the current.
func water_flow(grid: CellGrid) -> int:
	var cx0 := floori(x / float(Tuning.CELL_PX))
	var cx1 := floori((x + w_px - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(y / float(Tuning.CELL_PX))
	var cy1 := floori((y + h_px) / float(Tuning.CELL_PX))
	var left := 0
	var right := 0
	for cy in range(cy0, cy1 + 1):
		if grid.mat_at(cx0 - 1, cy) == Mat.WATER:
			left += grid.aux_at(cx0 - 1, cy)
		if grid.mat_at(cx1 + 1, cy) == Mat.WATER:
			right += grid.aux_at(cx1 + 1, cy)
	var diff := left - right
	var rows := cy1 - cy0 + 1
	if absi(diff) <= Tuning.WATER_MIN_DIFF * rows:
		return 0
	return diff / rows


## **It is segment versus box. Not rectangle versus rectangle.**
##  A generation 0 bolt jumps 80px per tick and the box is 20-44px, so matching only the tick-boundary positions
##  lets **the jump clear the whole box.** It is one frame, so the eye can never see it (design: "measuring a
##  direct hit by rectangle overlap every tick silently fails to catch it").
func hit_by_segment(spell: SpellSim) -> bool:
	var x0 := spell.get_seg_x0()
	var y0 := spell.get_seg_y0()
	var x1 := spell.get_seg_x1()
	var y1 := spell.get_seg_y1()
	for i in spell.seg_count():
		if _seg_hits_box(_fp_px(x0[i]), _fp_px(y0[i]), _fp_px(x1[i]), _fp_px(y1[i])):
			return true
	return false


## **The radius is not carried in the notification** — the caller reads `Tuning.blast_rd(gen)`.
##  Ship it along and the same value lives in two places, and the day the table changes only one follows.
func hit_by_blast(spell: SpellSim) -> bool:
	var bx := spell.get_blast_x()
	var by := spell.get_blast_y()
	var bg := spell.get_blast_gen()
	for i in spell.blast_count():
		var r := float(Tuning.blast_rd(bg[i]) * Tuning.CELL_PX)
		if _circle_hits_box(_cell_px(bx[i]), _cell_px(by[i]), r):
			return true
	return false


## **Coordinate conversion is this one function.** The notification is cell fixed-point and the body is px —
##  convert in two places and the day comes when only one gets fixed, and that mismatch only ever looks like
##  "sometimes it does not connect".
static func _fp_px(fp: int) -> float:
	return float(fp) * Tuning.CELL_PX / SpellSim.FP_ONE


## Cell number -> the px at that cell's **center**. It goes through the function above, so the rule has one copy.
static func _cell_px(c: int) -> float:
	return _fp_px((c << SpellSim.FP_SHIFT) + SpellSim.FP_HALF)


## Segment (a->b) versus box. **A start point inside the box is true** — a bolt born inside the box is caught too.
func _seg_hits_box(ax: float, ay: float, bx: float, by: float) -> bool:
	var rng := Vector2(0.0, 1.0)
	rng = _slab(rng, ax, bx - ax, float(x), float(x + w_px))
	rng = _slab(rng, ay, by - ay, float(y), float(y + h_px))
	return rng.x <= rng.y


## One axis's slab. Narrows and returns the surviving interval `(lo, hi)`.
## **Why the axes are folded into one function**: write the two axes separately and the day comes when only one
##  gets fixed, and then you get "only bolts flying vertically never connect".
## A segment parallel to the axis (d ~= 0) is decided by **whether it is inside the range**, not by division.
static func _slab(rng: Vector2, a: float, d: float, e0: float, e1: float) -> Vector2:
	if is_zero_approx(d):
		return rng if (a >= e0 and a <= e1) else Vector2(1.0, 0.0)
	var t0 := (e0 - a) / d
	var t1 := (e1 - a) / d
	return Vector2(maxf(rng.x, minf(t0, t1)), minf(rng.y, maxf(t0, t1)))


## Circle versus box — measured by the distance from the box's **closest point** to the circle's center.
func _circle_hits_box(cx: float, cy: float, r: float) -> bool:
	var dx := cx - clampf(cx, float(x), float(x + w_px))
	var dy := cy - clampf(cy, float(y), float(y + h_px))
	return dx * dx + dy * dy <= r * r
