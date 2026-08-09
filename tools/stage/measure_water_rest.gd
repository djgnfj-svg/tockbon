extends SceneTree
## **Does authored-flat water sleep, and how does it compare to poured water.**
##
## `docs/plans/1.ready/stage2-water.md` §6 rests its whole cost argument on one unmeasured claim —
## *"a perfectly uniform pool has a neighbour difference of 0 everywhere, `WATER_MIN_DIFF` is 4, so the
## chunks should sleep on the first tick"* — and that doc lists it first under "what this doc is least sure
## of". This tool is that measurement.
##
## **It is not a net.** A net pins a threshold; this prints a table so a design decision can be taken from
## numbers. The cheap half of it (authored flat sleeps, authored water is full) *is* a net —
## `net_water_authored`. What lives here is everything a net cannot pin: the poured control, the
## never-settles cases, the peak chunk counts.
##
## **The poured control matters more than any single authored number.** "Authored flat sleeps in 2 ticks"
## means nothing on its own — the same grid, the same volume, poured instead, is what gives it a scale.
##
##     Godot_v4.7.1-stable_win64.exe --headless --script res://tools/stage/measure_water_rest.gd

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## The cap the design doc's own poured measurement used (4,000 ticks = 200s at 20Hz).
const CAP := 4000
## After reaching 0, this many more ticks must also be 0. One tick at 0 is not equilibrium.
const HOLD := 50

const X0 := 200


func _initialize() -> void:
	print("[물] 그려진 평평한 물이 잠드는가 — 측정")
	print("[물] WATER_MIN_DIFF=%d · WATER_MAX=%d · CHUNK_CELLS=%d · MAX_CHUNKS_PER_TICK=%d · WATER_SUBSTEPS=%d"
		% [Tuning.WATER_MIN_DIFF, Tuning.WATER_MAX, Tuning.CHUNK_CELLS,
			Tuning.MAX_CHUNKS_PER_TICK, Tuning.WATER_SUBSTEPS])
	print("")
	print("  이름                         | 0되는 틱 | 최대 활성 | 마지막 활성 | 총량 보존")
	print("  -----------------------------|----------|-----------|-------------|----------")

	_flat_walled(32, 4)
	_flat_walled(128, 2)
	_poured_walled(128, 32, 8)
	# **`net_water._make_bowl(128, 900, 32, 8)`, replicated cell for cell.** `docs/design/water.md` records
	#  this bowl as *"still going at 4,000 ticks"* and `net_water._wide_bowl_settles_under_the_cap`'s header
	#  repeats it. The row above disagrees, so the exact bowl is run too — otherwise the disagreement can be
	#  waved away as "a different setup".
	_poured_at(128, 900, 32, 8)
	# **`net_water._make_bowl(32, 750, 8, 6)`, replicated cell for cell.** `water.md` records this one as
	#  *"stops at 2,798 ticks"*, and that figure sitting **above** the 128 bowl's 1,032 makes the wider bowl
	#  settle faster than the narrow one — the reverse of the diffusion argument the same table rests on.
	#  That doc flags it as unexplained. Re-driving it is the cheapest way to find out whether the puzzle is
	#  real or whether 2,798 is simply stale in the same way >4,000 was.
	_poured_at(32, 750, 8, 6)
	_flat_walled(256, 3)
	_flat_at_grid_edge(64, 3)
	_flat_over_stepped_floor()
	_flat_unwalled(64, 3)

	print("")
	print("[물] '0되는 틱' 이 -1 이면 %d틱(=%ds) 안에 안 멈췄다는 뜻이다." % [CAP, CAP / 20])
	print("[물] 놓는 것 자체가 청크를 더럽히므로 1틱째는 반드시 깨어 있다 (`_write_water` -> `_touch`).")
	print("[물] 그래서 '즉시 잠든다' 의 바닥값은 1이 아니라 2다.")
	quit()


# ====================================================================
#  scenarios
# ====================================================================

## Floor + two walls. The shape `net_water._make_bowl` uses, so the poured control below is comparable to
##  the numbers already in `docs/design/water.md`.
func _bowl(g: CellGrid, width: int, y_floor: int, wall_h: int) -> void:
	g.apply(CellGrid.cmd_fill(X0 - 1, y_floor, X0 + width, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(X0 - 1, y_floor - wall_h, X0 - 1, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(X0 + width, y_floor - wall_h, X0 + width, y_floor, Mat.STONE))


## **The case the whole design rests on.** Every column the same depth, every cell `WATER_MAX`.
func _flat_walled(width: int, depth: int) -> void:
	var g := CellGrid.new()
	var y_floor := 800
	_bowl(g, width, y_floor, 40)
	var placed := 0
	for k in width:
		for d in depth:
			if g.set_water(X0 + k, y_floor - 1 - d, Tuning.WATER_MAX):
				placed += Tuning.WATER_MAX
	_report("그린 평면 %d폭 %d깊이" % [width, depth], g, placed, y_floor - 60, y_floor)


## **The control.** The same bowl, the same total volume, **poured** into a corner instead of drawn flat.
##  `poured_cols` x `depth` at `WATER_MAX` is exactly the volume `_flat_walled(width, depth*poured_cols/width)`
##  places, so "authored vs poured" is the only difference between this row and the one above it.
func _poured_walled(width: int, poured_cols: int, depth: int) -> void:
	_poured_at(width, 800, poured_cols, depth)


func _poured_at(width: int, y_floor: int, poured_cols: int, depth: int) -> void:
	var g := CellGrid.new()
	_bowl(g, width, y_floor, 40)
	var placed := 0
	for k in poured_cols:
		for d in depth:
			if g.set_water(X0 + k, y_floor - 1 - d, Tuning.WATER_MAX):
				placed += Tuning.WATER_MAX
	_report("부은 %d폭 (%d열x%d, 바닥y=%d)" % [width, poured_cols, depth, y_floor],
		g, placed, y_floor - 60, y_floor)


## **The pool's left edge is the grid edge**, not a stone wall. `_water_share` returns early on `nx < 0`,
##  so it should behave as a wall — but "should" is the word this whole file exists to remove.
func _flat_at_grid_edge(width: int, depth: int) -> void:
	var g := CellGrid.new()
	var y_floor := 800
	g.apply(CellGrid.cmd_fill(0, y_floor, width, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(width, y_floor - 40, width, y_floor, Mat.STONE))
	var placed := 0
	for k in width:
		for d in depth:
			if g.set_water(k, y_floor - 1 - d, Tuning.WATER_MAX):
				placed += Tuning.WATER_MAX
	_report("격자 왼쪽 끝에 붙인 %d폭" % width, g, placed, y_floor - 60, y_floor)


## **The realistic case, and the one most likely never to settle** — a flat *surface* over a floor that
##  steps. Columns hold different depths; only the top row is level.
func _flat_over_stepped_floor() -> void:
	var g := CellGrid.new()
	var y_deep := 800
	var surface := 780          # the water's top row, level across every column
	var width := 96
	# Walls tall enough to hold the surface.
	g.apply(CellGrid.cmd_fill(X0 - 1, surface - 10, X0 - 1, y_deep, Mat.STONE))
	g.apply(CellGrid.cmd_fill(X0 + width, surface - 10, X0 + width, y_deep, Mat.STONE))
	# A floor in 6 steps of 16 columns, each 3 cells higher than the last.
	var placed := 0
	for k in width:
		var step := k / 16
		var floor_y := y_deep - step * 3
		g.apply(CellGrid.cmd_fill(X0 + k, floor_y, X0 + k, y_deep, Mat.STONE))
		for y in range(surface, floor_y):
			if g.set_water(X0 + k, y, Tuning.WATER_MAX):
				placed += Tuning.WATER_MAX
	_report("계단 바닥 위 평면 %d폭" % width, g, placed, surface - 10, y_deep)


## **Flat but with no wall on the right** — the thing §6's level-design rule forbids. Included because a
##  measurement that only ever shows 2 cannot tell you the instrument works.
func _flat_unwalled(width: int, depth: int) -> void:
	var g := CellGrid.new()
	var y_floor := 800
	g.apply(CellGrid.cmd_fill(X0 - 1, y_floor, X0 + 1200, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(X0 - 1, y_floor - 40, X0 - 1, y_floor, Mat.STONE))
	var placed := 0
	for k in width:
		for d in depth:
			if g.set_water(X0 + k, y_floor - 1 - d, Tuning.WATER_MAX):
				placed += Tuning.WATER_MAX
	_report("벽 없는 평면 %d폭" % width, g, placed, y_floor - 60, y_floor)


# ====================================================================
#  the instrument
# ====================================================================

## Steps until `active_chunk_count()` is 0, then confirms it stays 0. Prints one table row.
##
## **The total is summed over a rect wider than the pool** — summing only the pool's own columns turns
##  "it leaked sideways" into "it is conserved", which is the bound-from-the-thing-it-checks failure.
func _report(label: String, g: CellGrid, placed: int, y_top: int, y_bot: int) -> void:
	var before := _sum(g, y_top, y_bot)
	var zero_at := -1
	var peak := 0
	var last := 0
	for i in CAP:
		g.step()
		last = g.active_chunk_count()
		peak = maxi(peak, last)
		if last == 0:
			zero_at = i + 1
			break

	var held := true
	if zero_at > 0:
		for _i in HOLD:
			g.step()
			if g.active_chunk_count() != 0:
				held = false
				break

	var after := _sum(g, y_top, y_bot)
	var conserved := "예" if after == before else "아니오 (%d -> %d)" % [before, after]
	if zero_at > 0 and not held:
		conserved += " · %d틱 뒤 다시 깨어남" % HOLD
	if before != placed:
		conserved += " · 놓은 양(%d)과 초기 합(%d)이 다름" % [placed, before]
	print("  %-28s | %8d | %9d | %11d | %s" % [label, zero_at, peak, last, conserved])


func _sum(g: CellGrid, y_top: int, y_bot: int) -> int:
	var n := 0
	for y in range(y_top, y_bot + 1):
		for x in range(0, X0 + 1400):
			n += g.aux_at(x, y)
	return n
