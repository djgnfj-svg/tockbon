extends RefCounted
## The staff — **where is the tip.** **This file is the only one that answers that question.**
##  The screen only **draws** that value, and firing only **passes** it to `aim.fire_cmd`.
##
## **If the three (the drawn tip, the place that gets stained, the firing origin) diverge you get "it does not
##  come out of where I shot", and that only shows up in a screenshot** — `character_view.gd` recorded the same
##  thing in advance.
##  => **Do not recompute the value produced here at the call site.**
##
## **Why it lives here and not in `src/view/`**: put it on the screen and the nets have to stand up a scene,
##  but headless has no pixels (`character-sprite` acceptance record: the `SubViewport` texture was NULL).
##  Here, you feed in only the grid, the box and the direction and measure it **by value** — the same idiom as
##  `character.gd`'s `pick_state` and `camera_center`.
##
## **Floats are allowed** — GDD multiplayer table: the grid and projectiles are deterministic, **the player is
##  host-authoritative.**
##  **`src/sim/` is not touched by a single line.** The point of this file is that `spell_sim._walk`'s
##   "the starting cell is not checked" stays alive — that comment was not wrong and **its premise ("the staff
##   tip is in front of the wall") had been broken.** This is what restores that premise.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## **It must equal the width of the staff png** (`net_sprite` measures it). Diverge and "the visible tip" and
##  "the firing origin" are a few px apart, and that only shows up in a screenshot.
## **It moved here from `fx_tuning`.** Values there have "they only touch the screen" as their contract, but
##  this value reaches **the world** via `character_view` -> `stage` -> `aim.fire_cmd` — and this file stacks a
##  terrain dependency on top, which makes any mismatch load-bearing.
##  There is already a precedent: `character.gd`'s `MOVE_SPEED_PX` and `RECOIL_*` are all feel values living there.
##   The real rule is **"a knob that reaches the world lives next to that world's code".**
## It must be longer than the character (32px) to read as a "weapon". Too long and the aim point and the tip
##  get far apart, giving "it does not come out of where I shot" — 36px is between the two.
##  **A value to settle by eye.**
const LEN_PX := 36.0

## Hand height — this far below the body's center. **A value the eye settles** (design: "undecided").
## It must be **inside** the box (`0 <= this value < H_PX/2`) — beyond that the pivot is outside the box, and
##  then the safety grounds for the floor below ("inside the box there is no terrain") die. `net_staff` measures it.
const PIVOT_DY_PX := 4.0

## Scan interval. **Half a cell (4px) — larger than this and it skips cells.**
##  Skip and the tip **occasionally** sits inside a wall, and it is hard to reproduce.
const SCAN_STEP_PX := 2.0


## Where the staff extends from. **The hand height, not the body center** — coming out of the middle of the
##  belly does not read as "holding a staff" (design acceptance 6).
static func pivot_px(box_x: int, box_y: int) -> Vector2:
	return Vector2(
		float(box_x) + Character.W_PX * 0.5,
		float(box_y) + Character.H_PX * 0.5 + PIVOT_DY_PX)


## **The staff tip. Blocked by terrain, it gets shorter.**
##
## ```
## (1) pivot    = hand height
## (2) max tip  = pivot + aim direction * LEN_PX
## (3) scan between them and **cut just before** any solid cell
## (4) floor    = the box's **last inner pixel**. It never shrinks below that
## ```
##
## **The returned point is "the last sample actually confirmed not to be solid".** That is the contract and
##  `net_staff` measures that — "it is in an empty cell" is the value, not "it calls the clamp".
##
## `dir` is **taken as a unit vector. It is not normalized here** — the caller already did it, and doing it
##  twice makes "where do we normalize" live in two places. For the zero vector it returns the pivot as is.
## If `LEN_PX < min_len` (the staff is shorter than the body) **the floor wins.** It is still inside the box, so it is safe.
static func tip_px(grid: CellGrid, box_x: int, box_y: int, dir: Vector2) -> Vector2:
	var pivot := pivot_px(box_x, box_y)
	if dir.length_squared() <= 0.0:
		return pivot
	# The floor itself **takes no sample.** It does not need to — inside the box is where the character is
	#  standing right now, and `_box_free` guards every frame that there is no terrain there.
	var d := _min_len(pivot, box_x, box_y, dir)
	while d < LEN_PX:
		var nd := minf(d + SCAN_STEP_PX, LEN_PX)
		var p := pivot + dir * nd
		if grid.is_solid(
				floori(p.x / float(Tuning.CELL_PX)), floori(p.y / float(Tuning.CELL_PX))):
			break
		d = nd
	return pivot + dir * d


## **The floor — the ray distance to "the box's last inner pixel". It is not "the surface".**
##
## The range `_box_free` actually guards is `[px, px+W-1] x [py, py+H-1]`, so
## `px + W_PX` and `py + H_PX` (the surface) are **already the next cell.** Stepping through it with a
## character standing on the floor:
##
## ```
## box y 768-799 (cells 192-199)      floor cell 200 = px 800-803, solid
## surface     (y = 800) -> floori(800/4) = 200 = solid     X born here and it is the old bug all over again
## last inner  (y = 799) -> floori(799/4) = 199 = empty     O
## ```
##
## **Write it with the surface and the sides and the top are fine while only under the feet keeps the old bug.
##  Not one error is raised.**
## **The left and top corners are correct as plain `box`** — `floori` maps that pixel to the box's cell.
##  The asymmetry is normal.
static func _min_len(pivot: Vector2, box_x: int, box_y: int, dir: Vector2) -> float:
	return minf(
		_axis_exit(pivot.x, dir.x, float(box_x), float(box_x + Character.W_PX - 1)),
		_axis_exit(pivot.y, dir.y, float(box_y), float(box_y + Character.H_PX - 1)))


## The distance at which the ray leaves `[lo, hi]` on one axis.
## If it is parallel to the axis (`d ~= 0`) that axis **does not confine** the ray — handled by a branch, not a
##  division (the same idiom as `character._slab`). The case of both axes being 0 was filtered by the caller first.
## If the pivot is outside the box the result can be negative — it is clamped at 0 (the floor must not go backwards).
static func _axis_exit(a: float, d: float, lo: float, hi: float) -> float:
	if is_zero_approx(d):
		return INF
	return maxf(0.0, ((hi if d > 0.0 else lo) - a) / d)
