extends RefCounted
## Rain source B-5 — do active chunks stay under the cap while pouring. Split further out of `net_water_rain.gd`.
##
## **Why split again**: the same circumstances as the header comment of `net_water_rain.gd`
##  (three groups of 11.6 · 13.2 · 10.9 seconds). This file alone is 10.9 seconds.
##
## **It is failing right now. That is known and deliberately not fixed** (the team lead pinned it down) —
##  `src/` is outside harness-manager's authority, so it is not fixed. **Do not delete this check or
##  loosen the threshold.** The contract was carried over intact even while moving the file.
##
## **The cost was not erased.** The 130 ticks and the cap comparison are unchanged — only the process moved.
##
## **The helpers below are intentional duplication** — same reason as the header comment of `net_water_rain.gd`.
##  => If you fix them, fix the ones in that file · `net_water.gd` · `net_water_rain_speed.gd` too.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")

## Same as `net_water_rain.gd`.
const _PIT_ROW := 208
const _PIT_X0 := 1888


func run(t) -> void:
	_rain_stays_under_the_chunk_cap(t)


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


## **B-5 — while pouring, the cap (100) is never reached.**
##
## **What goes red when inverted**: widen the width (`WATER_RAIN_HALF_W`) or raise the per-tick amount and
##  active chunks stick to the cap — the A/B/C alternative re-measurement recorded that it stays off the cap
##  **only at this width and this rate.**
## **The terrain is settled completely first, then measured** (`_build_settled_pit`). The plan said
##  "skip the first 30 ticks of building terrain", but here that spike has already died down before the start,
##  so **there is no stretch to skip** — only the cost of water running is captured, purely.
func _rain_stays_under_the_chunk_cap(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	var peak := 0
	# 130 ticks ~= 76% of settling capacity — long enough to measure the cap while not overflowing and leaking.
	for _i in 130:
		src.tick(g)
		g.step()
		peak = maxi(peak, g.active_chunk_count())

	t.ok(peak > 0, "붓는 동안 실제로 활성 청크가 생겼다 (전제 — 0이면 아무것도 안 잰 것이다)")
	t.ok(peak < Tuning.MAX_CHUNKS_PER_TICK,
		"붓는 동안 활성 청크가 상한(%d) 아래에 머문다 (최대 %d)" % [Tuning.MAX_CHUNKS_PER_TICK, peak])
