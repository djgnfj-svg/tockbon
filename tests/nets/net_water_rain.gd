extends RefCounted
## The rain source (K, `src/sim/water_source.gd`) B-1 · B-2 · B-6 — stage 7 of `net_water.gd` moved here.
##
## **Why a separate file (harness-manager, measured)**: putting stage 7 on top of `net_water.gd` took that one
##  net from 21s to 48.5s. Measured per function, the five checks (B-1 · B-2 · B-6 · B-3/4 · B-5) alone were
##  35.7s and the remaining 39 checks were 11.2s — **in one file they run together.**
##  `tests/run_nets.ps1` runs a separate process in parallel **per `net_*.gd` file** (the header comment of that
##  file: "each net runs in its own process in parallel"), so moving them makes several processes run
##  **simultaneously** and the total wall clock drops from the sum of the groups to **the single slowest group.**
##
## **The five were split further into three.** B-3/4 (13.2s) · B-5 (10.9s) were peeled off into their own files
##  (`net_water_rain_speed.gd` · `net_water_rain_cap.gd`) — B-1 · B-2 · B-6 left here are 11.6s.
##  => With all three running at once the wall clock is not the sum of 37s but **the slowest one (~13s).**
##  **The reason further splitting was possible is structural** — `tests/run_nets.ps1` spawns one process per net
##  and runs up to `maxParallel` (core-count based, usually 8) at once. Where there were 16 nets there are now
##  18 and the batch count is unchanged (8 run at a time, so the two extra do not make another batch) — **free parallelization.**
##
## **The cost was not erased.** The ticks each check actually runs and its assertions are unchanged — what moved
##  is only **which process it runs in.** Otherwise it would violate CLAUDE.md's "No fake nets".
##
## **It is safe for the file names to partially contain each other** (`net_water` in `net_water_rain` in
##  `net_water_rain_speed` / `net_water_rain_cap`). It used to be dangerous — the parallel spawn bound a process
##  to a net with a substring filter, so splitting under these names nearly had one process secretly running
##  several nets (a measured 57-second accident). It was fixed by putting `^` exact matching into `run_nets.gd` —
##  since then, each process runs only its own net even when names contain each other.
##
## **The helpers `_settle` · `_water_scan` below also exist in `net_water.gd` and the other rain fragment files.**
##  It is intentional duplication — each file must run in its own process (the reason above), so there is no
##  shared base class. Every other `net_*.gd` in this repo carries its own helpers too.
##  => **If you fix these helpers, fix the ones in the other rain fragment files too.**

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")


func run(t) -> void:
	_rain_conserves_water(t)
	_rain_touches_only_its_row_once(t)
	_rain_leaves_no_gaps(t)


## Same as `net_water.gd._settle` — the "intentional duplication" in the header above.
func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


## Same as `net_water.gd._water_scan` — the "intentional duplication" in the header above.
func _water_scan(g: CellGrid, x0: int, y0: int, x1: int, y1: int) -> Array:
	var total := 0
	var cells := 0
	var peak := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var a := g.aux_at(x, y)
			if g.mat_at(x, y) != Mat.WATER:
				continue
			total += a
			cells += 1
			peak = maxi(peak, a)
	return [total, cells, peak]


# ══════════════════════════════════════════════════════════════════
#  Stage 7 — the rain source (K, `src/sim/water_source.gd`)
# ══════════════════════════════════════════════════════════════════
#
# **From here on `water_source.gd` is run directly — it is not reimplemented here.**
#  The reason that file lives in `src/sim/` was "the nets measure the very code that ships"
#  (`docs/plans/2.active/water-jump-and-escape.md`, "where to put it"). If this net rewrote the pouring
#  arithmetic itself, that reason would be void, and green here would mean nobody measured the game's water speed.
#
# **The real stage 1 pit (1) is used.** `Stage.build_terrain_into()` stands up the real terrain
#  (`net_tables._wood_clumps` already uses the same static door without a scene). **The width is derived from
#  `Tuning.WATER_RAIN_HALF_W`** — a width different from what K actually pours would mean this net measures
#  something other than the game.

## The pit's mouth row (cells). Tile 26 in `stage1-map-layout.md` = cell 208.
const _PIT_ROW := 208
## The first cell inside the left wall (cells). Each check derives the right end itself as a width of `Tuning.WATER_RAIN_HALF_W * 2`.
const _PIT_X0 := 1888


## Stands up the real terrain and runs until it is fully asleep.
##
## **B-1 to B-5 each get their own independent vessel** — sharing one means the water poured by one check breaks
##  the next check's premise ("nothing has been poured yet"). `Stage.build_terrain_into` itself is a bundle of
##  `cmd_fill` and is cheap, but **it is put fully to sleep first** (building the whole map wakes walls and floors
##  all at once) — that keeps "the terrain-building spike" and "the cost of water running" from mixing in the
##  later checks.
func _build_settled_pit() -> CellGrid:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	_settle(g, 400)
	return g


## **B-1 — conservation.** The "amount actually put in" that the source counts itself must exactly equal the
## grid's total water.
##
## **What goes red when inverted**: if `water_source.tick()` does not read via `aux_at` and just **overwrites**
##  with `set_water(x, row, per_cell)` — the water accumulated on previous ticks disappears and `_water_scan`'s
##  sum comes out lower than `poured()`. That is the accident the plan pinned down as "it is adding, not overwriting".
func _rain_conserves_water(t) -> void:
	var g := _build_settled_pit()
	t.eq(g.active_chunk_count(), 0, "물을 붓기 전에 지형이 완전히 잠들었다 (전제)")

	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	# **The coordinates are not taken on trust.** If the map changes, this assertion goes red by value first.
	t.ok(not g.is_solid(_PIT_X0, _PIT_ROW), "구덩이 입구 왼쪽 끝이 열려 있다 (전제)")
	t.ok(not g.is_solid(x1, _PIT_ROW), "구덩이 입구 오른쪽 끝도 열려 있다 (전제)")
	t.ok(g.is_solid(_PIT_X0 - 1, _PIT_ROW), "그 왼쪽은 벽이다 (전제)")
	t.ok(g.is_solid(x1 + 1, _PIT_ROW), "그 오른쪽도 막혀 있다 (전제 — 램프가 입구부터 막는다)")

	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)
	# **It stops at 100 ticks.** That is about 60% of this vessel's measured capacity (~13,312 cells x 255) —
	#  go past it and the surface overflows into the open sky above the mouth and leaks outside this check's
	#  rectangle, which is indistinguishable from a real leak.
	for _i in 100:
		src.tick(g)
		g.step()

	t.ok(src.poured() > 0, "소스가 실제로 물을 부었다 (전제)")
	var scan := _water_scan(g, _PIT_X0 - 4, _PIT_ROW - 4, x1 + 4, _PIT_ROW + 150)
	t.eq(scan[0], src.poured(), "격자의 물 총량이 소스가 센 누적량과 정확히 같다 (안 샌다)")
	t.ok(scan[2] <= Tuning.WATER_MAX, "어떤 칸도 최대량을 안 넘는다")


## **B-2 — exactly once per tick, into exactly that band (`K x substeps` rows).**
##
## **"That row" became "that band".** Horizontal stripes appeared on screen, so `water_source.tick()` was fixed
##  to fill a band of `WATER_FALL_CELLS x WATER_SUBSTEPS` rows instead of a single row
##  (`water_source.gd` header — "why not one row"). This check measures that band.
##
## **What goes red when inverted**: if the caller calls `tick()` twice per tick (e.g. the accident of wiring it
##  to `_physics_process` instead of `_on_ticked()`, pouring `TICK_DIVIDER` times faster), the "one tick's share"
##  assertion below breaks. Make it touch rows outside the band and the rows above and below break.
##  **Reverting the band width back to 1 row (the stripe bug itself) is not caught by this check** —
##  `_rain_leaves_no_gaps` below catches that separately. **The two are a pair.**
## **`g.step()` is not called** — had it been, the fall would wet the row below the band and "not touched yet"
##  would be false. What this check measures is the share of `tick()` alone.
func _rain_touches_only_its_row_once(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	src.tick(g)
	var width := x1 - _PIT_X0 + 1
	var band_rows := Tuning.WATER_FALL_CELLS * Tuning.WATER_SUBSTEPS
	var per_cell := Tuning.WATER_RAIN_PER_TICK / (width * band_rows)
	# Only three sample cells (both ends + the middle) are looked at — measuring all 176 gives the same answer, and a sample is enough.
	for x in [_PIT_X0, (_PIT_X0 + x1) / 2, x1]:
		for y in range(_PIT_ROW, _PIT_ROW + band_rows):
			t.eq(g.aux_at(x, y), per_cell, "한 번의 몫이 정확히 칸당 양이다 (x=%d, y=%d)" % [x, y])
		t.eq(g.aux_at(x, _PIT_ROW - 1), 0, "띠 바로 위 행은 안 건드린다 (x=%d)" % x)
		t.eq(g.aux_at(x, _PIT_ROW + band_rows), 0,
			"띠 바로 아래 행도 아직 안 건드린다 (x=%d, `step()` 을 안 불렀다)" % x)
	t.eq(src.poured(), per_cell * width * band_rows,
		"누적량도 한 번의 몫(칸당 양 × 폭 × 띠 높이)과 같다")


## **B-6 — no vertical stripes (gaps) while pouring.**
##
## **It actually happened on screen** (verify-look): in one column (cx=1975) the rows holding water repeated
##  exactly every `K x substeps` (=12 cells=48px) with everything in between at 0 — pouring fills only one row
##  while the fall moves 12 cells in one tick, so **that row goes down whole and the space above spends a full
##  tick completely empty.** The cause matched the value of `K x WATER_SUBSTEPS` exactly.
##
## **What goes red when inverted**: change `_BAND_ROWS` in `water_source.gd` back to 1 (the original code that
##  produced the stripes) and this column shows a maximum gap of `K x substeps - 1` — it must be 0 now.
func _rain_leaves_no_gaps(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	var probe_x := (_PIT_X0 + x1) / 2  # the very column verify-look saw on screen (1975).
	var max_gap := 0
	# 20 ticks are looked at — the first tick has not fallen yet so having no gap is trivial, and several ticks
	#  are needed to measure "it keeps not happening".
	for _i in 20:
		src.tick(g)
		g.step()
		var last_row := -1
		for y in range(_PIT_ROW, _PIT_ROW + 200):
			if g.mat_at(probe_x, y) != Mat.WATER:
				continue
			if last_row >= 0:
				max_gap = maxi(max_gap, y - last_row - 1)
			last_row = y
	t.eq(max_gap, 0, "붓는 동안 세로 줄무늬(빈틈)가 없다 (최대 빈틈 %d칸)" % max_gap)
