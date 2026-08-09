extends RefCounted
## The gate — stage 1's ending (`docs/design/gate-ending.md`, `gate-ending-to-game.md`).
## **Geometry and one predicate. No screen, no scene, no `Progress`.**
##
## **`src/actor/`, not `src/stage/`.** `net_layers.RULES` forbids `src/actor/` from reaching `src/view/` or
## `src/stage/`, and a file in `src/stage/` that a view could preload would need to be a third pure file
## alongside `town_map.gd`, for two constants. So the seat lives with the machine, not with the map — the
## precedent `fixtures.gd:11-13` sets for the town is broken on purpose. **The price**: a map repaint moves a
## constant that does not sit next to the map. `net_gate`'s first check pays it, driven against the real
## baked terrain, the same accident `stage_defs.gd`'s `STAGE1_SPAWN_TILE` comment records.
##
## **Which stage's gate this is, is no longer this file's answer** — the shell pushes it in
## (`set_geometry()` below), exactly the way `WorldStep.set_placement()` already takes the monster table.
## `src/actor/` still never learns a stage's name.

const Tuning := preload("res://src/sim/sim_tuning.gd")  ## `src/sim` is allowed from `src/actor` (`net_layers.RULES`).
const TILE_PX := Tuning.TILE_CELLS * Tuning.CELL_PX  ## 32 — one tile, in world px.

const REACH_PX := 48          ## x half-band, +/- from the seat centre. **A feel value, not geometry** — it
                              ##  is the same for every stage's gate and does not belong in the room table.
const BAND_UP_PX := 96        ## y band, upward from the ground line (3 tiles). Same, a feel value.

## ══ Stage 1's gate, in tiles ══
##
## **These six are the room table's (`src/stage/stage_defs.gd`) — its stage-1 row references them by name
##  rather than copying the numbers, so there is still exactly one place each value is written.**
##
## **Why they did not simply move into that table**: `net_gate`'s Stage A checks measure this geometry
##  against the real baked terrain **with no shell standing** (`Stage.build_terrain_into(g)` on a bare grid),
##  so something has to answer `seat_px()` before anything has pushed a room in. Left unset they would
##  measure a sentinel and go green on nothing. ⇒ The numbers stay here as the **declared starting value** of
##  the pushed geometry below, and the table names them.
## **The price, stated**: stage 2's gate numbers will be literals in its own row while stage 1's are here.
##  The day that asymmetry is worth removing, `net_gate` has to gain a `set_geometry()` line first.
const STAGE1_SEAT_TILE_X := 270      ## The arch's column.
const STAGE1_FLOOR_TILE_Y := 25      ## The row it stands ON — its top edge is the ground line.
const STAGE1_WALL_TILE_X0 := 267     ## Room ③'s east wall — both stone columns.
const STAGE1_WALL_TILE_X1 := 268
const STAGE1_WALL_TILE_Y0 := 13
const STAGE1_WALL_TILE_Y1 := 24

## **Which stage's gate this is, right now — pushed in by the shell, never read from `src/stage/`.**
##  `WorldStep.set_placement()` is the precedent this copies verbatim: the shell owns the room table and
##  hands the machine the six numbers, so `src/actor/` still knows nothing of a stage's name.
##
## **Plain ints, deliberately, not one `Dictionary`** — `net_pick`'s no-inventory scan reads a class-level
##  `var` of collection type as a stash and would need an exemption for a Dictionary here. Six ints need none.
static var _seat_tile_x := STAGE1_SEAT_TILE_X
static var _floor_tile_y := STAGE1_FLOOR_TILE_Y
static var _wall_tile_x0 := STAGE1_WALL_TILE_X0
static var _wall_tile_x1 := STAGE1_WALL_TILE_X1
static var _wall_tile_y0 := STAGE1_WALL_TILE_Y0
static var _wall_tile_y1 := STAGE1_WALL_TILE_Y1


## **The shell's one door in** (`stage.gd._apply_room()`). Called on every room build that has a gate.
##
## **A room with no gate does not call this and the last stage's numbers stay standing.** That is deliberate
##  and it is inert: `at()` is unreachable in the town (`_sync_settlement`'s `want` carries `not _in_town`)
##  and the arch derives `visible` from `Progress.boss_died()`, which a reset has just cleared. Clearing the
##  geometry instead would break `net_gate`, whose `_wired_root()` builds the **town** and then measures
##  `wall_cells()` — measured, not predicted.
static func set_geometry(seat_tx: int, floor_ty: int,
		wall_tx0: int, wall_tx1: int, wall_ty0: int, wall_ty1: int) -> void:
	_seat_tile_x = seat_tx
	_floor_tile_y = floor_ty
	_wall_tile_x0 = wall_tx0
	_wall_tile_x1 = wall_tx1
	_wall_tile_y0 = wall_ty0
	_wall_tile_y1 = wall_ty1


## `(seat tile + 0.5) * TILE_PX`. **The `+ 0.5` is `town_map.fixture_seats()`'s own idiom** — off by half a
##  tile and the arch reads as reached a step early.
static func seat_px() -> float:
	return (float(_seat_tile_x) + 0.5) * float(TILE_PX)


## The row the seat stands ON, in world px. The arch's feet touch this line, not float below it.
static func floor_y_px() -> float:
	return float(_floor_tile_y) * float(TILE_PX)


## **Is `center` standing at the gate.** x is a band around the seat; y is a band reaching up from the
## ground line, never down through the floor.
##
## **Why a y band at all**: the x270 column is open from row 0 to row 24 (the room has no ceiling there), so
## an x-only test would say "at the gate" while the player is still sailing over the roof.
##
## **Why not `on_ground` instead**: room ③'s escape is a water escape — a player floating at the gate is not
## "on the ground", and requiring it would fail a run already won, the same reason the design refuses a
## keypress. **The limit that buys**: water deeper than ~3 tiles at the seat lifts the player out of this
## band. Named in the plan's Risk 6; `water-jump-and-escape.md`'s to answer, not this file's.
static func at(center: Vector2) -> bool:
	if absf(center.x - seat_px()) > REACH_PX:
		return false
	var floor_y := floor_y_px()
	return center.y >= floor_y - BAND_UP_PX and center.y <= floor_y


## The east wall's cells, as a `Rect2i` whose **`end` is the last inclusive cell** (not one past it, the way
## `Rect2i.end` ordinarily reads) — `CellGrid.cmd_fill`'s own `x0,y0,x1,y1` are inclusive bounds, and this
## shape lets the caller pass `r.position`/`r.end` straight through without an off-by-one correction.
static func wall_cells() -> Rect2i:
	var tc := Tuning.TILE_CELLS
	var x0 := _wall_tile_x0 * tc
	var y0 := _wall_tile_y0 * tc
	var x1 := (_wall_tile_x1 + 1) * tc - 1
	var y1 := (_wall_tile_y1 + 1) * tc - 1
	return Rect2i(x0, y0, x1 - x0, y1 - y0)
