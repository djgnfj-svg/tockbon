extends RefCounted
## Pours water into one band (`_BAND_ROWS` rows) a little at a time over N ticks — "like rain".
## `RefCounted`, so it knows nothing of the scene tree.
## **Not a single row** — a band as tall as the fall ceiling (`WATER_FALL_CELLS × WATER_SUBSTEPS`).
##  The reason is in `tick()`'s header (on-screen striping).
##
## **Why `src/sim/` and not `stage.gd`**: this feature's biggest risk (acceptance 6, "does water arrive
##  at the right rate") is measurable only by value. Keeping the state inside the shell means the nets
##  can't build a scene and would **reimplement pouring inside themselves** to measure it, splitting
##  the measured code from the shipping code
##  (`docs/plans/2.active/water-jump-and-escape.md`, "where it lives").
##  => **The caller (`stage.gd`) knows only "when to start" and "call it every tick".** The arithmetic all lives here.
##
## **Do not put it inside `cell_grid.step()`** — that changes the meaning of `step()` for all 39 nets
##  in this repo. This source stays separate from the grid by **the caller calling `tick()` itself**.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

var _x0: int
var _x1: int
var _row: int
var _per_tick: int

## **The amount the source counted as actually landing** — not the amount it tried to pour.
##  Cells rejected by a wall (`set_water` returns `false`) and the portion blocked by `WATER_MAX` are excluded.
##  => Comparing this against the grid's total water is the only way net B-1 (conservation) works.
var _poured := 0


func _init(x0: int, x1: int, row: int, per_tick: int) -> void:
	_x0 = x0
	_x1 = x1
	_row = row
	_per_tick = per_tick


## **Pours into a band of `WATER_FALL_CELLS × WATER_SUBSTEPS` rows, not one row**
##  (found on screen — see "why not one row" below).
##
## **Not hardcoded — derived from the fall ceiling.** Change K (`WATER_FALL_CELLS`) and this band's
##  height follows automatically. Let the two drift apart and the striping comes back.
const _BAND_ROWS := Tuning.WATER_FALL_CELLS * Tuning.WATER_SUBSTEPS

## Exactly once per tick, into exactly the band `_row .. _row + _BAND_ROWS - 1`.
##
## **Why not one row — horizontal stripes appeared on screen** (verify-look).
##  The fall moves `K × substeps` (= `_BAND_ROWS`) cells per tick while the pour filled only one row,
##  so that row descends as a unit next tick and **the space above spends a whole tick completely empty** —
##  the 12-cell (48px) gaps matched that value exactly.
##  => **Refilling a `_BAND_ROWS`-row band every tick means a new band takes the place of the old one
##  the instant it drops 12 cells** — gaps become 0 in principle (`net_water._rain_leaves_no_gaps` measures it).
##
## **Call it only inside `stage.gd`'s `_on_ticked()` — never `_physics_process`.**
##  Called per physics frame it pours `TICK_DIVIDER` (3) times faster, **with no error** —
##  on screen it only looks like "it fills faster than expected" (net B-2 measures this contract by value).
##
## **It is add, not overwrite.** `set_water` replaces the cell wholesale — calling
##  `set_water(x, y, per_cell)` every tick quietly destroys water accumulated the previous tick.
##  => **Read (`aux_at`), add (`mini(WATER_MAX, ...)`), write.**
## **Walls reject themselves** — `set_water` returns `false` for cells that are neither `EMPTY` nor `WATER`,
##  so rejected cells don't measure `before`/`after` and don't count into `_poured`. **The same holds when
##  the `_BAND_ROWS` rows punch through terrain** — those rows are simply rejected and that much less goes
##  in (nothing leaks; `_poured` is the evidence).
##
## **The per-cell amount drops to `1/_BAND_ROWS` of the old way** (divided across width × `_BAND_ROWS` cells).
##  At the current values (K=4 · substeps=3 => 12 rows) the per-cell amount can fall below `WATER_WET` (32) —
##  meaning it gets painted in the shallow-water color. **How that looks on screen is unmeasured and left open**
##  (verify-look's job).
func tick(grid: CellGrid) -> void:
	var width := _x1 - _x0 + 1
	if width <= 0:
		return
	var per_cell := _per_tick / (width * _BAND_ROWS)
	if per_cell <= 0:
		return
	for y in range(_row, _row + _BAND_ROWS):
		for x in range(_x0, _x1 + 1):
			var before := grid.aux_at(x, y)
			var after := mini(Tuning.WATER_MAX, before + per_cell)
			if grid.set_water(x, y, after):
				_poured += after - before


## Cumulative amount this source has actually poured in so far.
func poured() -> int:
	return _poured
