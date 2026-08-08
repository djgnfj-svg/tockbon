extends RefCounted
## Rain source B-3 · B-4 — does it reach the target in proportion to the per-tick amount. Split further out
## of `net_water_rain.gd`.
##
## **Why split again (harness-manager, measured)**: this one check was 13.2 seconds — when it sat in one file
##  with B-1 · B-2 · B-6 (11.6s) and B-5 (10.9s), that whole file was 37 seconds.
##  The full story is in the header comment of `net_water_rain.gd`. Split into three, the wall clock is not
##  the sum (37s) but **the slowest one (~13s)** — the 8-way parallelism (`run_nets.ps1` `maxParallel`) has
##  headroom, so more nets do not add a batch (free parallelization).
##
## **The cost was not erased.** The tick counts and the ratio thresholds are unchanged — only the process moved.
##
## **The helpers below are intentional duplication** — same reason as the header comment of `net_water_rain.gd`.
##  => If you fix them, fix that file · `net_water.gd` · `net_water_rain_cap.gd` too.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")

## Same as `net_water_rain.gd`.
const _PIT_ROW := 208
const _PIT_X0 := 1888


func run(t) -> void:
	_rain_speed_scales_with_per_tick(t)


func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


func _build_settled_pit() -> CellGrid:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	_settle(g, 400)
	return g


## Runs until the total `src` has poured into the grid reaches `target`. Returns the number of ticks run.
## Hitting `cap` is a failure — same idiom as `_settle`, the caller has to assert that.
func _ticks_until(src: WaterSource, g: CellGrid, target: int, cap: int) -> int:
	var n := 0
	while src.poured() < target and n < cap:
		src.tick(g)
		g.step()
		n += 1
	return n


## **B-3 · B-4 — is the time to target proportional to the per-tick amount, and did the loop actually spin
## more than once.**
##
## **What goes red when inverted**: halve the per-tick amount (the mutation the plan named) and reaching the
##  same target must take almost exactly twice as long — anything less than double, or unchanged, means
##  `tick()` is not actually using `_per_tick`.
## **No absolute tick count is pinned down — only the ratio is measured.** Absolute numbers wobble when the
##  terrain changes, but the ratio does not (which is why this check does not break on map changes).
## **B-4 (the loop did not spin idle) is measured here too** — the `ticks > 1` assertion is that spot. It blocks
##  the case where the start condition is false, the loop runs 0 times, and "it reached the target" passes for
##  free (that accident in CLAUDE.md).
func _rain_speed_scales_with_per_tick(t) -> void:
	# Put it around 20-odd percent of the settling capacity (~13,312 cells x 255 ~= 3,394,560) — the half-speed
	#  side takes twice as long and needs headroom not to overflow.
	var target := Tuning.WATER_RAIN_PER_TICK * 40
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1

	var g1 := _build_settled_pit()
	var src1 := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)
	var ticks1 := _ticks_until(src1, g1, target, 400)
	t.ok(ticks1 > 1 and ticks1 < 400, "정상 속도가 상한 안에 목표에 닿는다 (%d틱 — 루프가 헛돌지 않았다)"
		% ticks1)

	var g2 := _build_settled_pit()
	var src2 := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK / 2)
	var ticks2 := _ticks_until(src2, g2, target, 800)
	t.ok(ticks2 > 1 and ticks2 < 800, "반 속도도 상한 안에 목표에 닿는다 (%d틱 — 루프가 헛돌지 않았다)"
		% ticks2)

	var ratio := float(ticks2) / float(ticks1)
	t.ok(ratio > 1.6 and ratio < 2.4,
		"반 속도가 걸리는 틱이 정상의 약 두 배다 (%d → %d, 비율 %.2f)" % [ticks1, ticks2, ratio])
