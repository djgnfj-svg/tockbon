extends RefCounted
## Water and chunk sleep. **Every water failure is silent** — so what is measured here is **values**, not barks.
##
## **What lives here is stage 1 (chunk sleep) and stage 2 (it falls downward).**
##  There is no left-right sharing, no wetness, no water rune yet. This is why the design split the stages:
##  if the chunks stand wrong the water is wrong with them and **you cannot tell which of the two is the cause**
##  (`water-and-chunk-sleep.md`, "build order").
##
## **"It doesn't move" measures nothing.** In v1 the water looked stopped and was not stopping.
##  => Everything measured here is a **number** — `active_chunk_count()`, `chunk_awake_at()` and the like.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## **Stage 7 (K, water rain) moved out to `net_water_rain.gd`** (harness-manager did it — the reason is in
##  that file's head comment). `Stage` and `WaterSource` were used by those checks only, so they were deleted here.


func run(t) -> void:
	_chunk_geometry(t)
	_empty_grid_never_wakes(t)
	_blast_wakes_chunk(t)
	_woken_chunk_sleeps_next_tick(t)
	_fill_wakes_exactly_the_covered_chunks(t)
	_ignite_does_not_touch_chunks(t)
	_flip_is_at_tick_start(t)
	_reset_clears_chunks(t)
	_band_summary_matches_scan(t)
	# -- stage 2 --
	_water_material_derives_its_rules(t)
	_water_door_refuses_bad_targets(t)
	_write_cell_wipes_water(t)
	_water_falls_per_tick(t)
	_water_falls_and_stacks(t)
	_water_total_is_conserved(t)
	_settled_water_sleeps(t)
	_digging_below_a_chunk_edge_wakes_the_water(t)
	_cmd_fill_refuses_water(t)
	_water_moves_mark_the_screen_dirty(t)
	_bottom_row_water_is_safe(t)
	_front_has_no_unburnable(t)
	# -- stage 3 --
	_water_lies_flat(t)
	_min_diff_stops_the_shuffling(t)
	_column_edge_wakes_the_neighbour(t)
	_narrow_bowl_reaches_zero(t)
	_wide_bowl_settles_under_the_cap(t)
	_left_right_has_no_bias(t)
	_tick_cap_delays_but_never_drops(t)
	_same_commands_give_the_same_grid(t)
	_sleeping_grid_is_cheap(t)
	# -- stage 4 --
	_shallow_bit_tracks_the_amount(t)
	# -- stage 5 --
	_water_disc_fills_without_wiping(t)
	_water_rune_makes_water(t)
	# -- stage 6 --
	_water_puts_out_fire(t)
	_no_water_means_no_rescue(t)
	_wet_neighbour_never_catches(t)
	_fire_beside_water_does_not_flicker(t)
	_no_cell_carries_both_bits(t)
	_shallow_water_does_not_put_out_fire(t)
	# -- stage 7 (K, water rain) lives in `net_water_rain.gd` --
	# **harness-manager moved it.** With it here this net went 21s -> 48.5s
	#  (35.7s from those five checks alone). `run_nets.ps1` runs a separate process per `net_*.gd` file,
	#  so moving them makes those five run **concurrently** with the rest — the cost wasn't erased, the process was split.


## If the grid and the chunks don't divide evenly, edge cells **index an out-of-range chunk.**
##  `_init()` is set up to bark about it, but this doesn't lean on the bark and measures it as a value here
##  (CLAUDE.md, "don't lean on the bark — leave a trace as a value and measure it").
func _chunk_geometry(t) -> void:
	t.eq(CellGrid.W % Tuning.CHUNK_CELLS, 0, "W가 청크 한 변으로 나눠떨어진다")
	t.eq(CellGrid.H % Tuning.CHUNK_CELLS, 0, "H가 청크 한 변으로 나눠떨어진다")
	t.eq(CellGrid.CHUNK_W * Tuning.CHUNK_CELLS, CellGrid.W, "청크 열 수 × 한 변 = W")
	t.eq(CellGrid.CHUNK_H * Tuning.CHUNK_CELLS, CellGrid.H, "밴드 수 × 한 변 = H")
	t.eq(CellGrid.CHUNK_COUNT, CellGrid.CHUNK_W * CellGrid.CHUNK_H, "청크 수가 두 축의 곱이다")

	# **The last cell must land in the last chunk.** If there is truncation this goes out of range —
	#  `chunk_awake_at` actually reads that index, so going out makes the engine bark (= not a silent death).
	var g := CellGrid.new()
	t.ok(not g.chunk_awake_at(CellGrid.W - 1, CellGrid.H - 1),
		"격자 마지막 셀의 청크를 읽어도 범위를 안 넘는다")
	t.ok(not g.chunk_awake_at(-1, 0), "격자 밖은 안 깨어 있다 (왼쪽)")
	t.ok(not g.chunk_awake_at(0, CellGrid.H), "격자 밖은 안 깨어 있다 (아래)")


## **This is the floor of this net.** If a grid nobody touched wakes on its own, chunk sleep is
##  void as a whole, and every water acceptance stacked on top of it becomes a lie.
## **One tick cannot measure it** — even with `_chunk_flip` standing wrong, the first tick can be 0 by luck.
func _empty_grid_never_wakes(t) -> void:
	var g := CellGrid.new()
	t.eq(g.active_chunk_count(), 0, "갓 만든 격자는 활성 청크가 0이다")
	for _i in 20:
		g.step()
	t.eq(g.active_chunk_count(), 0, "빈 격자는 20틱을 돌려도 활성 청크가 0이다")
	t.eq(g.get_tick(), 20, "그동안 틱은 실제로 돌았다")


## **Does a blast wake a chunk.** If it doesn't you get "the bowl you punched doesn't leak",
##  and the cause is on the blast side, not the water — on screen it only looks like "the water is broken".
##
## **You have to look after running `step()` once.** A command marks `_dirty`, and the place that turns
##  it into `awake` is `_chunk_flip()`. **If that flip sits at the end of the tick this goes red** — a blast
##  calls the grid inside `spell_sim.step()`, so with the flip behind, the dirty just marked is erased on the spot.
func _blast_wakes_chunk(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 511, 511, Mat.STONE))
	# Laying terrain wakes chunks — **put it fully to sleep first.** Then the wake below is certainly the blast's.
	# **Two ticks are not enough.** 1,024 chunks wake but the per-tick cap is 512, so they **back up** (stage 3).
	#  Not knowing that and leaving it at two ticks makes this check mistake "it is awake" for the blast's doing.
	var calm := _settle(g, 200)
	t.ok(calm > 1 and calm < 200, "지형이 결국 다 잠든다 (%d틱 — 상한에 밀린 만큼 걸린다)" % calm)
	t.eq(g.active_chunk_count(), 0, "완전히 잠들었다")

	g.apply(CellGrid.cmd_blast(200, 200, Tuning.blast_rd(0), Tuning.blast_ignite_r(0), CellGrid.IGNITE_ANY))
	g.step()
	t.ok(g.chunk_awake_at(200, 200), "폭발 자리의 청크가 깨어난다")
	t.ok(g.active_chunk_count() > 0, "활성 청크가 0이 아니다 (%d개)" % g.active_chunk_count())

	# **Far away it does not wake.** If it passes by "wake everything", this net measures nothing.
	t.ok(not g.chunk_awake_at(2000, 800), "폭발과 먼 청크는 안 깨어난다")


## **Does a woken chunk go back to sleep the next tick.** If it doesn't, chunk sleep degenerates into
##  "everything is awake", and **nobody barks about that** — 12% of the budget simply disappears.
func _woken_chunk_sleeps_next_tick(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, 100, 140, 140, Mat.WOOD))
	g.step()
	t.ok(g.chunk_awake_at(120, 120), "채운 자리가 깨어 있다")
	var woke := g.active_chunk_count()
	t.ok(woke > 0, "채우기가 청크를 깨웠다 (%d개)" % woke)

	# Nobody moved, so dirty must be empty, and the flip carries that through as is.
	g.step()
	t.ok(not g.chunk_awake_at(120, 120), "아무 일도 안 일어난 청크는 한 틱 뒤 잠든다")
	t.eq(g.active_chunk_count(), 0, "한 틱 뒤 활성 청크가 0이다")


## **Is the number of woken chunks exactly the number the terrain covers.** "Greater than 0" can't measure it —
##  `_touch` computing the chunk index wrong passes that too.
## That is why a **rectangle aligned exactly to the chunk grid** is used. Off by one cell and the count doesn't match.
func _fill_wakes_exactly_the_covered_chunks(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	var g := CellGrid.new()
	# Chunks (2..5, bands 3..6) = 4 x 4 = 16, covered exactly.
	g.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc - 1, 7 * cc - 1, Mat.STONE))
	g.step()
	# **It is 28, not 16** — because `_touch` **also wakes the neighbouring chunks water can flow in from**
	#  (the "invisible wall" fix at chunk boundaries). Covered 16 + 4 bands above + 4 bands left + 4 bands right = 28.
	#  Back to 16 means the fix vanished whole; 20 means **only the left-right part vanished** (stage 3).
	t.eq(g.active_chunk_count(), 28, "덮은 16청크 + 위·좌·우 이웃 12청크 = 28이 깨어난다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc), "왼쪽 위 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(6 * cc - 1, 7 * cc - 1), "오른쪽 아래 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc - 1), "바로 위 청크가 깨어 있다 (물이 위에서 흘러든다)")

	# **Waking narrowly is a decision.** Marking all 8 neighbours would leave below and both sides awake too,
	#  and one awake band is 128us, so that value becomes the budget directly (verify-run measured).
	#  => Only the direction water can flow in from (above) is woken.
	t.ok(g.chunk_awake_at(2 * cc - 1, 3 * cc), "바로 왼쪽 청크가 깨어 있다 (물이 옆에서 흘러든다)")
	t.ok(g.chunk_awake_at(6 * cc, 3 * cc), "바로 오른쪽 청크가 깨어 있다")
	t.ok(not g.chunk_awake_at(2 * cc, 1 * cc), "두 밴드 위(밴드 1)는 안 깨어 있다 (한 칸만 번진다)")
	t.ok(not g.chunk_awake_at(2 * cc, 7 * cc), "**아래** 청크는 안 깨어 있다 (물은 아래에서 안 온다)")
	t.ok(not g.chunk_awake_at(0 * cc, 3 * cc), "두 청크 왼쪽(열 0)은 안 깨어 있다 (한 칸만 번진다)")

	# Filling one more cell must wake exactly one more column — if the index slips, this goes off.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc, 7 * cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.active_chunk_count(), 29, "오른쪽으로 한 칸 넘치면 밴드 4개가 한 청크씩 더 깨어난다")


## **Ignition does not touch chunks — a decision, not an accident.**
##  `_ignite_cell` touches only `_flag` and `_aux` and never changes the material. Fire is a burn-slot list,
##  so it is independent of chunks (GDD), and since ignition needs fuel > 0 it **cannot in principle reach a water cell (fuel 0).**
##
## **The plan and `_touch`'s comment nailed this down and nobody measured it.** If later, over "should fire wake
##  chunks too", someone puts a `_touch` into `_ignite_cell`, **every burning wood cell wakes chunks every tick** —
##  one forest beside a still lake eats the budget with **no error and no change on screen.**
func _ignite_does_not_touch_chunks(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, 100, 110, 100, Mat.WOOD))
	g.step()
	g.step()
	t.eq(g.active_chunk_count(), 0, "나무를 깔고 재운다 (이 검사의 전제)")

	t.ok(g.ignite(105, 100), "나무에 불이 붙는다 (검사의 전제 — 안 붙으면 아래가 헛돈다)")
	g.step()
	t.eq(g.active_chunk_count(), 0, "점화만으로는 청크가 안 깨어난다")
	# **It doesn't wake them while burning either.** A tick where only the fuel drops never passes `_write_cell`.
	g.step()
	g.step()
	t.ok(g.burning_count() > 0, "아직 타는 중이다 (검사의 전제)")
	t.eq(g.active_chunk_count(), 0, "타는 동안에도 청크가 안 깨어난다")


## **Is `_chunk_flip()` the start of the tick — the highest-value check in this net.**
##
## **It is easy to think water is the only thing that moves mid-tick, and that is wrong** — `_burn()` calls
##  `_write_cell(EMPTY)` on a burnt-out cell **inside** `step()`, and that rides `_touch`.
##  => **The flip's placement is observable even with no water.**
##
## The split is exactly here (measured):
##    flip in front (correct) — the tick it burns out: active 0 · one tick more: active 1
##    flip behind (wrong)     — the tick it burns out: **active 1**
## Without this check, moving the flip to the end leaves the rest **all green**, and whoever moved it uses
##  that green as evidence. The price then is "punched it with a blast and it doesn't leak next tick", and **no error is raised.**
func _flip_is_at_tick_start(t) -> void:
	var g := CellGrid.new()
	# **It must be a single cell.** With several, the burn-out ticks scatter and the 0/1 below is smeared.
	g.apply(CellGrid.cmd_fill(100, 100, 100, 100, Mat.WOOD))
	g.step()
	g.step()
	t.eq(g.active_chunk_count(), 0, "나무 한 칸을 깔고 재운다 (이 검사의 전제)")

	g.ignite(100, 100)
	var ticks := 0
	while g.burning_count() > 0 and ticks < 200:
		g.step()
		ticks += 1
	t.eq(g.burning_count(), 0, "나무 한 칸이 다 탄다 (%d틱)" % ticks)
	# **Evidence that `_write_cell` actually ran.** If it didn't, the 0 below would come out the same as
	#  "nothing happened at all", and then this check spins idle as a whole.
	t.eq(g.mat_at(100, 100), Mat.EMPTY, "다 탄 자리가 빈칸이 됐다 (`_write_cell` 이 돌았다)")

	t.eq(g.active_chunk_count(), 0, "다 탄 그 틱에는 아직 안 깨어 있다 (flip이 틱 시작이라는 증거)")
	g.step()
	t.eq(g.active_chunk_count(), 1, "한 틱 뒤에 정확히 한 청크가 깨어난다")
	t.ok(g.chunk_awake_at(100, 100), "깨어난 것이 다 탄 자리의 청크다")


## If `_reset` doesn't clear the chunks, **a new stage is born holding the old dirty** —
##  the same trap as `_burning`, and `_reset` uses `fill`, so it never once passes `_write_cell`.
##
## **awake and dirty are measured by different checks. Bundled into one, half of it spins idle.**
##  **This is measured** (the implementation inverted it): dropping just the two lines in `_reset` that clear
##   `_dirty` and `_band_dirty` still left (1) below **green** — (1) runs `step()` before the reset, so dirty
##   was already empty, which made the label "dirty is empty too" wider than what it measured.
##   => It has to be reset **while still marked**, like (2), for that half to actually be measured (CLAUDE.md, "no fake nets").
## **The fill is 128x128, not the old 512x512.** 8x8 = 64 chunks across 8 bands is still plenty to catch
##  a `_band_awake`/`_band_dirty` array left un-cleared (that bug shows up the moment *any* touched band
##  stays nonzero) — the old area bought no extra sensitivity, only 16x the paint cost.
func _reset_clears_chunks(t) -> void:
	# (1) the awake side — does a reset put already-awake chunks back to sleep.
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 127, 127, Mat.STONE))
	g.step()
	t.ok(g.active_chunk_count() > 0, "먼저 청크를 깨운다 (%d개)" % g.active_chunk_count())

	g.apply(CellGrid.cmd_reset())
	t.eq(g.active_chunk_count(), 0, "리셋이 활성 청크를 0으로 만든다")
	# **The band summary has to be looked at too.** Dropping **just the one line** `_band_awake.fill(0)` from
	#  `_reset` leaves the line above green — the summary is a different array from `_awake`, and neither fixes the other.
	#  A summary left inflated makes the sweep **walk empty bands every tick** (it only gets slower, it doesn't bark).
	t.eq(_band_sum(g), 0, "리셋 직후 밴드 요약 합도 0이다")
	g.step()
	t.eq(g.active_chunk_count(), 0, "리셋 뒤 한 틱을 돌려도 활성 청크가 0이다")

	# (2) the dirty side — **reset while still marked.** Since a flip has never been passed, if the old dirty
	#  survives, **the new stage wakes it straight up** on the tick after the reset.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(0, 0, 127, 127, Mat.STONE))
	t.eq(g2.active_chunk_count(), 0, "채우기 직후는 아직 안 깨어 있다 (flip 전이다 — 이 검사의 전제)")
	g2.apply(CellGrid.cmd_reset())
	g2.step()
	t.eq(g2.active_chunk_count(), 0, "찍힌 채로 리셋하면 다음 틱에도 안 깨어난다 (dirty를 비웠다)")
	t.eq(_band_sum(g2), 0, "그때 밴드 요약 합도 0이다 (밴드 쪽 dirty도 비웠다)")


## **Is the band summary real.** `_band_awake` is carried incrementally by `_touch`, and if that value is low
##  the sweep **skips an awake band entirely** — the water freezes in place and there are zero errors.
##
## **The grid runs exactly right without it (it only gets slower).** So this value can die silently,
##  and the only way to catch that is **butting it against an independent measurement** (the same spot as `claimed_slot_count`).
func _band_summary_matches_scan(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	var g := CellGrid.new()
	t.eq(_band_sum(g), 0, "빈 격자의 밴드 요약 합이 0이다")

	# 5 chunks in band 3, 2 chunks in band 9.
	g.apply(CellGrid.cmd_fill(0, 3 * cc, 5 * cc - 1, 4 * cc - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(40 * cc, 9 * cc, 42 * cc - 1, 10 * cc - 1, Mat.WOOD))
	g.step()

	var mismatched := 0
	for b in CellGrid.CHUNK_H:
		if g.band_awake_count(b) != g.scan_awake_in_band(b):
			mismatched += 1
	t.eq(mismatched, 0, "모든 밴드에서 요약과 직접 센 값이 같다")
	# The left-right neighbours wake too, so it is more than the covered count — band 3 is chunks 0..4 + 1 on the right = 6
	#  (there is nothing on the left, it is the grid edge), band 9 is chunks 40 and 41 + 1 on each side = 4.
	t.eq(g.band_awake_count(3), 6, "밴드 3의 요약이 6이다 (덮은 5 + 오른쪽 이웃 1)")
	t.eq(g.band_awake_count(9), 4, "밴드 9의 요약이 4다 (덮은 2 + 좌우 이웃 2)")
	t.eq(_band_sum(g), g.active_chunk_count(), "밴드 요약의 합이 활성 청크 수와 같다")

	# **Touching the same chunk several times doesn't inflate the summary.** `_touch`'s duplicate guard is that spot —
	#  unfiltered, the summary grows past the truth, and that is the "thinks it is awake and runs" side, which doesn't bark.
	var g2 := CellGrid.new()
	for _i in 4:
		g2.apply(CellGrid.cmd_fill(0, 0, cc - 1, cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.band_awake_count(0), 2, "한 청크를 네 번 채워도 밴드 요약이 안 부푼다 (덮은 1 + 오른쪽 1)")
	t.eq(g2.active_chunk_count(), 2, "활성 청크도 2다")

	# Once they sleep the summary must go back to 0 with them — if the flip doesn't swap the summary, this catches it.
	g2.step()
	t.eq(_band_sum(g2), 0, "다 잠들면 밴드 요약 합도 0이다")


## **Runs to equilibrium. "It steps once first" is the reason this function exists.**
##
## A command only marks `_dirty`, so **before the flip `active_chunk_count()` is 0** —
##  a loop starting with `while active > 0` **never runs once**, and then "it fell asleep" passes for free.
## **That actually happened three times in this repo.** The third time it surfaced because a mutation didn't bite.
##  => **Do not write your own while. Use this door.**
##
## The return is the number of ticks run. If it hit `cap` it is **not** equilibrium — the caller must assert that.
func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


## Collects every row holding water in one column. **It gives "where is it" and "how many cells" at once** —
##  guessing the position up front and probing `aux_at` leaves **duplicated cells outside the check.**
func _column_water_rows(g: CellGrid, x: int, y0: int, y1: int) -> Array[int]:
	var rows: Array[int] = []
	for y in range(y0, y1 + 1):
		if g.aux_at(x, y) > 0:
			rows.append(y)
	return rows


## The whole sum of the band summary. **A path independent of `active_chunk_count()`** — butting the two
##  together catches both "the summary is inflated" and "the summary is empty".
func _band_sum(g: CellGrid) -> int:
	var n := 0
	for b in CellGrid.CHUNK_H:
		n += g.band_awake_count(b)
	return n


# ==================================================================
#  stage 2 — the water material + it only falls downward
# ==================================================================

## **Water's two rules derive from the table. There is no separate code enforcing them** — so the table is measured.
##  Change `DEFS`'s `behavior` to `BEHAVIOR_STATIC` and **the character stands on water**.
##   Raise `fuel` and **water catches fire.** Neither raises an error; it is only strange on screen.
func _water_material_derives_its_rules(t) -> void:
	t.ok(Mat.ALL.has(Mat.WATER), "WATER가 ALL 목록에 있다 (순회가 명시 목록으로만 돈다)")
	t.ok(Mat.DEFS.has(Mat.WATER), "WATER가 DEFS에 있다")
	t.ok(Mat.WATER < Mat.SLOT_COUNT, "WATER id %d 가 팔레트 슬롯 %d 안이다" % [
		Mat.WATER, Mat.SLOT_COUNT])
	t.ok(Mat.rgb_of(Mat.WATER) != Mat.MISSING_RGB, "WATER에 색이 있다 (마젠타 센티넬이 아니다)")

	var g := CellGrid.new()
	t.ok(g.set_water(50, 50, 200), "물을 놓는다 (아래 검사들의 전제)")
	# **Behaviour is measured through the derived value** — `is_solid` is the single source for "is it solid".
	t.ok(not g.is_solid(50, 50), "물은 고체가 아니다 (캐릭터도 탄도 통과한다)")
	t.ok(not g.ignite(50, 50), "물에는 불이 안 붙는다 (연료가 0이라 파생된다)")
	t.eq(g.burning_count(), 0, "파면에도 안 올라간다")


## **The reason the water door can't be used just anywhere is the burn front.** `_write_water` doesn't call
##  `_unburn`, so writing water into a burning cell leaves **a ghost claiming membership**, and that cell can never burn again.
##  `claimed_slot_count()` measures that as a value — it is the kind that appears neither on screen nor as an error.
func _water_door_refuses_bad_targets(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.STONE))
	g.apply(CellGrid.cmd_fill(12, 10, 12, 10, Mat.WOOD))
	g.ignite(12, 10)
	t.eq(g.burning_count(), 1, "나무 한 칸이 탄다 (검사의 전제)")

	t.ok(not g.set_water(10, 10, 100), "돌 위에는 물을 못 놓는다")
	t.eq(g.mat_at(10, 10), Mat.STONE, "돌이 그대로다")
	t.ok(not g.set_water(12, 10, 100), "타는 칸에는 물을 못 놓는다")
	t.eq(g.burning_count(), 1, "파면이 그대로다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "유령 슬롯이 안 생긴다")

	t.ok(not g.set_water(-1, 10, 100), "격자 밖은 조용히 거절한다")
	# **An out-of-range amount barks and is discarded.** Unwatched, `PackedByteArray` silently truncates to the low 8 bits.
	t.expect_error("CellGrid.set_water: amount")
	t.ok(not g.set_water(20, 20, Tuning.WATER_MAX + 1), "최대량을 넘는 양은 짖고 안 놓인다")
	t.eq(g.mat_at(20, 20), Mat.EMPTY, "거절된 양이 칸을 안 건드린다")

	# Water onto water does go down — that is "overwrite the amount", the path the water rune will take.
	t.ok(g.set_water(30, 30, 100), "빈칸에 물을 놓는다")
	t.ok(g.set_water(30, 30, 200), "물 위에 물을 다시 놓는다")
	t.eq(g.aux_at(30, 30), 200, "양이 덮어써진다")
	t.ok(g.set_water(30, 30, 0), "양 0을 쓰면")
	t.eq(g.mat_at(30, 30), Mat.EMPTY, "그 칸이 빈칸이 된다")


## **The boundary between the two doors.** A blast erasing water is not zeroing the amount but **emptying the
##  cell whole**, and `_write_cell` is right for that — the last line of design section (2) nailed that down.
## **The other side (water passing through `_write_cell` evaporates the amount) is caught not here but by `total conserved`.**
func _write_cell_wipes_water(t) -> void:
	var g := CellGrid.new()
	g.set_water(100, 200, 255)
	t.eq(g.aux_at(100, 200), 255, "물이 놓였다 (검사의 전제)")

	g.apply(CellGrid.cmd_carve(100, 200, 3))
	t.eq(g.mat_at(100, 200), Mat.EMPTY, "파기가 물 칸을 비운다")
	t.eq(g.aux_at(100, 200), 0, "그때 양도 같이 0이 된다 (칸을 통째로 비우는 게 맞다)")
	t.eq(g.count_material(Mat.WATER), 0, "물이 한 칸도 안 남는다")


## **The only check that measures the traversal-order contract head-on** (`cell_grid.gd`'s header).
##  Single-buffered, the destination must be "a place already passed this tick, or one not visited at all",
##  and what stands that up is **bands bottom->top, and rows within a band bottom->top too**.
##
## **Invert it and water crosses the grid in one tick** — and yet **the final state is identical.**
##  "Is it all stacked" and "is the total the same" are all green with the order inverted. => **It is caught only by looking every tick.**
## It deliberately crosses a band boundary (575 -> 576). Inverting only the band order splits right there.
##
## **"Exactly one cell" became "at most `WATER_SUBSTEPS` cells per tick".**
##  `cell_grid.step()` runs `_water_step` that many times, so **the fall speeds up by the same factor**
##  (that constant's comment — the result of the user judging "the water spreads too slowly").
##
## **"At most N cells per tick" became "at most `K x N` cells per tick"**
##  (`water-jump-and-escape.md` stage 2, `sim_tuning.WATER_FALL_CELLS`). `_water_fall` already moves
##  up to K cells at once within one substep, and that substep runs N times per tick.
##  => **One more ceiling, and the shape of the contract is unchanged** — `cap` below is that ceiling.
##
## **Why a range and not "exactly N cells"**: there is no `_chunk_flip` between substeps, so on the tick water
##  **crosses a band boundary it rests for the remaining substeps if the band below is not awake yet**
##  (`cell_grid._water_tick`'s comment). => Some ticks descend **less** than `cap`. That is a property of
##  this arrangement, not a fault — **for a check to predict that tick count it would have to rewrite the sim inside the check.**
##
## **The inversion is still caught all the same.** Invert the band or row order and water goes **to the floor
##  in one tick** (as far as free fall allows), blowing well past the ceiling `cap`. **What the range catches
##  is "it doesn't cross", and "the cap actually runs" is measured separately by `max_delta == cap` below** —
##  bundling the two into one assertion goes green even with the substep loop cut to 1 or K put back to 1.
func _water_falls_per_tick(t) -> void:
	var cap := Tuning.WATER_FALL_CELLS * Tuning.WATER_SUBSTEPS
	# The terrain and column positions are fixed first — the guards below must be **derived directly from these
	#  values** so that widening the scene (or raising K) moves both together. The numbers are not written by hand
	#  twice (CLAUDE.md, "if the same explanation appears in two files, move it to one place" — previously `sim_tuning.
	#  WATER_FALL_CELLS` carried its own 27-cell table, and widening this scene to row 700 without fixing that table
	#  split the two files. The table was deleted and folded into this one function).
	var floor_row := 700
	var y0 := 572
	var y1 := 578  # the second column — closest to the floor, so it is this scene's real constraint
	var room := floor_row - 1 - y1

	# **This is where the scene barks at itself.** This check leans on "if it falls to the floor in one tick the
	#  inversion is caught", and once `cap` approaches the headroom (`room`) an inversion is indistinguishable
	#  from the normal range and **it loses its teeth.** **It is not a hand-baked number like `20`** — it says
	#  don't exceed half the headroom, so widening the scene (= a bigger `room`) raises this limit with it.
	t.ok(cap * 2 <= room,
		"K×서브스텝(%d)이 이 장면의 여유(%d칸)의 절반 안이다 — 뒤집어도 확실히 갈린다"
			% [cap, room])
	# **And it checks it isn't so narrow that the loop spins idle either.** Even if `cap` barely reaches `room`,
	#  a `room / cap` below 2 trips `ticks >= 2` below first — that is another check's job.

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, floor_row, 100, floor_row, Mat.STONE))
	t.eq(y0 / Tuning.CHUNK_CELLS, 35, "시작 행이 밴드 35다 (아래 경계 통과의 전제)")
	t.eq(576 / Tuning.CHUNK_CELLS, 36, "네 칸 아래가 밴드 36이다 — 이 검사가 밴드 경계를 지난다")
	g.set_water(50, y0, Tuning.WATER_MAX)
	# **The second column holds the band below awake.** Without it the band-order inversion is **not caught** —
	#  with a single column, on the tick water first enters band 36 that band is still asleep, so the sweep
	#  never runs it and there is nowhere for the inverted order to show (confirmed).
	g.set_water(52, y1, Tuning.WATER_MAX)

	# Only looked at until the lower column reaches the floor — past that it measures stacking, not "cells per tick".
	var ticks := mini(6, room / cap)
	t.ok(ticks >= 2, "루프가 실제로 %d바퀴 돈다 (0바퀴면 이 검사는 공짜로 통과한다)" % ticks)
	var prev := {50: y0, 52: y1}
	var max_delta := 0
	for k in ticks:
		g.step()
		for x in [50, 52]:
			var rows := _column_water_rows(g, x, 560, floor_row - 1)
			t.eq(rows.size(), 1, "%d틱 뒤 x=%d 기둥이 정확히 한 칸이다 (복제도 증발도 없다)"
				% [k + 1, x])
			if rows.size() != 1:
				return
			var y: int = rows[0]
			t.eq(g.aux_at(x, y), Tuning.WATER_MAX, "%d틱 뒤 x=%d 의 양이 그대로다" % [k + 1, x])
			var delta: int = y - int(prev[x])
			# **As long as below is empty it must descend.** A 0 means that cell fell asleep,
			#  which is the symptom of the "invisible wall".
			t.ok(delta >= 1, "%d틱 뒤 x=%d 가 적어도 한 칸 내려갔다 (%d칸)" % [k + 1, x, delta])
			# **This is the traversal-order contract.** Invert it and it reaches the floor in one tick.
			t.ok(delta <= cap,
				"%d틱 뒤 x=%d 가 한 틱에 %d칸을 안 넘었다 (%d칸)" % [k + 1, x, cap, delta])
			max_delta = maxi(max_delta, delta)
			prev[x] = y

	# **Whether K x substeps actually runs is measured by this one line.** All three are caught here:
	#  cutting the substep loop to 1, putting K back to 1, or both — `max_delta` falls short of `cap` and only
	#  this goes red. The range assertion above (`delta <= cap`) lets every "descends less" through.
	t.eq(max_delta, cap, "어느 틱엔가는 정확히 %d칸(K×서브스텝) 내려간다 — 둘 다 실제로 돈다" % cap)
	t.ok(int(prev[50]) >= 576, "물이 실제로 밴드 경계(576)를 지났다 (이 검사의 전제)")
	t.eq(g.count_material(Mat.WATER), 2, "물 칸 수가 내내 2다")


## Does water placed in mid-air fall to the floor and stack. This stage goes **downward only**, so the result is exactly predictable.
func _water_falls_and_stacks(t) -> void:
	var g := CellGrid.new()
	# One row of floor and one column above it.
	g.apply(CellGrid.cmd_fill(0, 300, 200, 300, Mat.STONE))
	# **Left and right walls are needed** (from stage 3 on). Without them water spreads sideways and "it stacks
	#  as a column" can't be measured — what is measured is the fall, and mixing spreading in puts two axes in one check.
	g.apply(CellGrid.cmd_fill(99, 280, 99, 299, Mat.STONE))
	g.apply(CellGrid.cmd_fill(101, 280, 101, 299, Mat.STONE))
	var poured := 0
	for k in 4:
		g.set_water(100, 290 + k, Tuning.WATER_MAX)
		poured += Tuning.WATER_MAX

	t.eq(g.aux_at(100, 299), 0, "바닥 바로 위는 아직 비어 있다 (검사의 전제)")
	for _i in 60:
		g.step()

	# **Four full water cells stack into the four cells above the floor unchanged.** One cell leaking throws this off.
	for k in 4:
		t.eq(g.aux_at(100, 299 - k), Tuning.WATER_MAX,
			"바닥에서 %d칸 위가 꽉 찼다" % (k + 1))
	t.eq(g.aux_at(100, 295), 0, "그 위는 비었다")
	t.eq(g.mat_at(100, 295), Mat.EMPTY, "그 위 재료도 빈칸이다")
	t.eq(g.mat_at(100, 300), Mat.STONE, "바닥 돌은 그대로다 (물이 고체를 안 지난다)")
	t.eq(g.count_material(Mat.WATER), 4, "물 칸 수가 정확히 4다")

	# Partial amounts move too — does "only as much as it can take" actually run.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(0, 300, 200, 300, Mat.STONE))
	g2.apply(CellGrid.cmd_fill(49, 290, 49, 299, Mat.STONE))
	g2.apply(CellGrid.cmd_fill(51, 290, 51, 299, Mat.STONE))
	g2.set_water(50, 299, 200)
	g2.set_water(50, 298, 100)
	for _i in 20:
		g2.step()
	t.eq(g2.aux_at(50, 299), Tuning.WATER_MAX, "아래 칸이 최대까지만 찬다")
	t.eq(g2.aux_at(50, 298), 300 - Tuning.WATER_MAX, "넘친 %d 이 위에 남는다" % (300 - Tuning.WATER_MAX))


## **Total conservation — leaking water is invisible on screen.**
##  The moment water passes through `_write_cell`, `_flag` and `_aux` go to 0 and **the amount evaporates on the spot.**
##   No error, no change on screen. This check is the only net for that risk.
##
## **Three things are measured in one scan**: the sum · the water cell count · the maximum amount.
##  · sum   => is it leaking
##  · count => **did it leak outside the scanned rectangle** (butted against `count_material` — an independent path)
##  · max   => did `_aux` pass 255 and get **truncated to the low 8 bits**
func _water_total_is_conserved(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 400, 300, 400, Mat.STONE))
	var poured := 0
	# Poured at several heights and several columns. A single column can't separate out "correct in one column only".
	for x in range(20, 60):
		for k in 3:
			var amount := 60 + (x % 7) * 20 + k * 10
			if g.set_water(x, 350 + k * 5, amount):
				poured += amount
	t.ok(poured > 0, "물을 부었다 (%d, 검사의 전제)" % poured)

	var before := _water_scan(g, 0, 0, 300, 420)
	t.eq(before[0], poured, "붓기 직후 합이 부은 양과 같다")
	t.eq(before[1], g.count_material(Mat.WATER), "붓기 직후 사각형 밖에 물이 없다")

	for _i in 200:
		g.step()

	var after := _water_scan(g, 0, 0, 300, 420)
	t.eq(after[0], poured, "200틱 뒤에도 총량이 정확히 같다")
	t.eq(after[1], g.count_material(Mat.WATER), "200틱 뒤에도 사각형 밖으로 안 샜다")
	t.ok(after[2] <= Tuning.WATER_MAX, "어떤 칸도 최대량을 안 넘는다 (최대 %d)" % after[2])
	# **Evidence it actually moved.** The total matches even if nothing moved, so without this the two above spin idle.
	t.ok(after[1] < before[1], "물이 실제로 아래로 모였다 (칸 수 %d → %d)" % [before[1], after[1]])


## **The heart of stage 2.** There is no left-right yet, so equilibrium **really does reach 0** —
##  this is the spot where the design wrote "if 0 doesn't come out here, do not go on to stage 3".
## **"The water doesn't move" can't measure it.** Not moving and not sleeping was exactly v1.
func _settled_water_sleeps(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 500, 200, 500, Mat.STONE))
	g.apply(CellGrid.cmd_fill(39, 460, 39, 499, Mat.STONE))
	g.apply(CellGrid.cmd_fill(80, 460, 80, 499, Mat.STONE))
	# **Several layers have to be poured.** With one layer there is no water above the stacked water, so
	#  `_water_fall`'s "below is full (`space <= 0`)" branch is **never once passed** —
	#  deleting that early exit still left this check green (confirmed).
	#  Deleted, full cells trade **writes that change no amount** every tick and wake the chunk forever.
	for x in range(40, 80):
		for k in 3:
			g.set_water(x, 470 + k, Tuning.WATER_MAX)
	# 3 layers poured into the 40 columns between the walls, so equilibrium is exactly 3 layers — the basis for "stays full" below.
	g.step()

	# It must be awake while falling — otherwise the 0 below is just "nothing ever happened".
	t.ok(g.active_chunk_count() > 0, "떨어지는 동안 활성 청크가 0이 아니다 (%d개)" % g.active_chunk_count())

	var ticks := 0
	while g.active_chunk_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
	t.eq(g.active_chunk_count(), 0, "다 쌓이면 활성 청크가 0이 된다 (%d틱)" % ticks)
	t.eq(_band_sum(g), 0, "밴드 요약 합도 0이다")

	# **And it must stay 0.** Being 0 for one tick is not equilibrium.
	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱을 더 돌려도 0이다")
	# **The three layers really do sit stacked and full** — that is the shape that passes the "below is full"
	#  branch every tick, and the point of this check is that it sleeps anyway.
	for k in 3:
		t.eq(g.aux_at(60, 499 - k), Tuning.WATER_MAX,
			"바닥에서 %d칸 위가 꽉 찬 채로 남아 있다" % (k + 1))


## **The "invisible wall" at a chunk boundary.** Digging **directly below** sleeping water when what is below
##  is **the next band** wakes only the dug cell's chunk, and **the band holding the water stays asleep**, so the sweep skips it whole.
##
## **It actually happened in the original code** (verify-read2 · with no mutation):
##  water sat in mid-air at y=335 with `aux=255` **still after 10 ticks.** Zero errors.
## **Blasts, carves and burnt-out wood all take this path** — it hits when the bottom y of a water column is
##  a multiple of 16 minus 1, so **roughly 1 time in 16**. On screen it only looks like "water floating in mid-air".
##
## **A control is measured alongside.** Digging within the same chunk always works, so measuring only that
##  leaves "water falls" green while the boundary dies quietly.
func _digging_below_a_chunk_edge_wakes_the_water(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	# The **last row** of band 20 = right above the chunk boundary.
	var y_edge := 21 * cc - 1
	t.eq(y_edge / cc, 20, "물이 밴드 20의 마지막 행에 있다")
	t.eq((y_edge + 1) / cc, 21, "그 바로 아래가 밴드 21이다 — 이 검사의 전제")

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(90, y_edge + 1, 110, y_edge + 4, Mat.STONE))
	# The sides are walled off — what is measured is **does it flow down**, and leaking sideways blurs that axis.
	g.apply(CellGrid.cmd_fill(99, y_edge, 99, y_edge, Mat.STONE))
	g.apply(CellGrid.cmd_fill(101, y_edge, 101, y_edge, Mat.STONE))
	g.set_water(100, y_edge, Tuning.WATER_MAX)
	# **One tick has to run first.** A command only marks `_dirty`, so before the flip
	#  `active_chunk_count()` is **0** — starting straight into `while active > 0` makes the loop run
	#  **not even once**, and "it fell asleep" below passes for free.
	#  It was actually written that way, and it surfaced because a mutation didn't bite. The check was spinning idle.
	var settle := _settle(g, 20)
	t.ok(settle > 1, "물이 실제로 떨어지는 동안 깨어 있었다 (%d틱 — 루프가 헛돌지 않았다)" % settle)
	t.eq(g.active_chunk_count(), 0, "돌 위에 얹힌 물이 먼저 잠든다 (%d틱)" % settle)
	t.eq(g.aux_at(100, y_edge), Tuning.WATER_MAX, "물은 그 자리에 있다")

	# **Only the cell directly below the water is dug.** The water cell is left alone — touching it wakes the
	#  water's own chunk and this check spins idle as a whole.
	g.apply(CellGrid.cmd_fill(100, y_edge + 1, 100, y_edge + 1, Mat.EMPTY))
	for _i in 10:
		g.step()
	t.eq(g.aux_at(100, y_edge), 0, "10틱 뒤 물이 원래 자리에 없다 (공중에 안 떠 있다)")
	t.eq(g.aux_at(100, y_edge + 1), Tuning.WATER_MAX, "판 자리로 내려왔다")

	# Control — digging within the same chunk always worked. The two splitting apart is the shape of this bug.
	var h := CellGrid.new()
	var y_mid := 21 * cc + 5
	t.eq(y_mid / cc, (y_mid + 1) / cc, "대조군은 위아래가 같은 밴드다 (전제)")
	h.apply(CellGrid.cmd_fill(90, y_mid + 1, 110, y_mid + 4, Mat.STONE))
	h.apply(CellGrid.cmd_fill(99, y_mid, 99, y_mid, Mat.STONE))
	h.apply(CellGrid.cmd_fill(101, y_mid, 101, y_mid, Mat.STONE))
	h.set_water(100, y_mid, Tuning.WATER_MAX)
	var h_settle := _settle(h, 20)
	# **The same line as 511.** Without it, if this control later starts spinning idle it prints `(1 tick)` and passes —
	#  and if the control dies, the "they split" of the boundary check above loses its whole meaning.
	t.ok(h_settle > 1, "대조군도 실제로 떨어지는 동안 깨어 있었다 (%d틱)" % h_settle)
	t.eq(h.active_chunk_count(), 0, "대조군도 먼저 잠든다 (%d틱)" % h_settle)
	h.apply(CellGrid.cmd_fill(100, y_mid + 1, 100, y_mid + 1, Mat.EMPTY))
	for _i in 10:
		h.step()
	t.eq(h.aux_at(100, y_mid + 1), Tuning.WATER_MAX, "대조군도 내려온다 (같은 청크 안)")


## **Water cannot be placed with `cmd_fill`.** That door passes `_write_cell` and zeroes `_aux`,
##  which stands up **a cell whose material is WATER but whose amount is 0** — a state that
##  `cell_materials.gd`'s `_aux` section nailed down as "cannot exist in principle".
## Measured (verify-read2): 55 water cells placed that way are **0 cells after 20 ticks**. They evaporate silently.
## **This will actually be stepped on soon** — the day water goes on the map, terrain baking uses this path. That is why it barks.
func _cmd_fill_refuses_water(t) -> void:
	var g := CellGrid.new()
	t.expect_error("CellGrid: water cannot be placed with cmd_fill")
	g.apply(CellGrid.cmd_fill(10, 695, 20, 699, Mat.WATER))
	t.eq(g.count_material(Mat.WATER), 0, "cmd_fill 이 물을 한 칸도 안 놓는다")
	t.eq(g.mat_at(15, 697), Mat.EMPTY, "그 자리가 빈칸 그대로다")

	# **The point is that refusing is better than "water with amount 0".** Through the water door it still goes down.
	t.ok(g.set_water(15, 697, 128), "같은 자리에 물의 문으로는 놓인다")
	t.eq(g.aux_at(15, 697), 128, "양이 실제로 들어간다")


## **The sim runs but the screen doesn't change — CLAUDE.md's flagship fake.**
##  `_changed` is the single source for "does the screen get re-uploaded", and **`net_water` had never once looked at it** =>
##  deleting `_write_water`'s `_changed += 1` left the whole net green (confirmed).
## **The other side is measured too** — always giving a nonzero value is another fault, "re-upload everything
##  every frame", and that one shows up only as performance.
func _water_moves_mark_the_screen_dirty(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 700, 100, 700, Mat.STONE))
	g.set_water(50, 690, Tuning.WATER_MAX)
	g.consume_changed()  # sweep away the share from the placement itself

	g.step()
	# **It is not nailed down to "one cell"** — `WATER_SUBSTEPS` sets the fall distance, and what is measured
	#  here is not distance but `_changed`. Distance is measured separately by `_water_falls_per_tick`.
	t.eq(g.aux_at(50, 690), 0, "물이 실제로 그 자리를 떠났다 (전제)")
	t.eq(g.count_material(Mat.WATER), 1, "그리고 한 칸 그대로다 (복제되지도 사라지지도 않았다)")
	t.ok(g.consume_changed() > 0, "물이 움직인 틱은 화면을 다시 올리라고 표시한다")

	# Once it has stacked and gone to sleep it must be 0.
	# **There has to be a ceiling.** If the water never stops, **it is not a failure, the runner hangs forever** —
	#  one assertion going red and the whole net never finishing are different accidents.
	#  **That condition arrives in the very next stage**: the design wrote "stage 3's wide water cannot in
	#   principle stop" (128 cells wide doesn't reach equilibrium in 4,000 ticks). => Hitting it **drops to failure.**
	var settle := _settle(g, 200)
	t.ok(settle < 200, "물이 상한 안에 잠든다 (%d틱 — 닿으면 안 멈춘 것이다)" % settle)
	g.consume_changed()
	for _i in 10:
		g.step()
	t.eq(g.consume_changed(), 0, "잠든 뒤에는 화면을 안 건드린다")


## **The bottom row of the grid.** Without `_water_step`'s `y < H - 1` guard, `below` runs past the grid and
##  **an engine "Index out of bounds" fires every tick** — a silent death no assertion catches, only the wrapper does.
## The net was placing water only down to the y=600s, so this guard had **never once been stepped on**.
func _bottom_row_water_is_safe(t) -> void:
	var g := CellGrid.new()
	var last := CellGrid.H - 1
	# The sides are walled off (from stage 3 on) — what is measured is the **bottom edge**, not spreading.
	g.apply(CellGrid.cmd_fill(299, last - 3, 299, last, Mat.STONE))
	g.apply(CellGrid.cmd_fill(301, last - 3, 301, last, Mat.STONE))
	t.ok(g.set_water(300, last, Tuning.WATER_MAX), "격자 맨 아래 행에 물을 놓는다")
	t.ok(g.set_water(300, last - 1, Tuning.WATER_MAX), "그 바로 위에도 놓는다")
	for _i in 20:
		g.step()
	# There is nowhere below to go, so it must stay put. Leaking off the grid would drop the total.
	t.eq(g.aux_at(300, last), Tuning.WATER_MAX, "맨 아래 물이 격자 밖으로 안 샌다")
	t.eq(g.aux_at(300, last - 1), Tuning.WATER_MAX, "위 칸도 그대로다 (아래가 꽉 찼다)")
	t.eq(g.active_chunk_count(), 0, "그리고 잠든다")


## **Is an unburnable material sitting on the burn front.** It is the invariant that keeps water and fire out of
##  the same cell, and **the premise of stage 6**.
## **`claimed == burning` cannot catch it in principle** — those two are butted only against each other, so a
##  water cell can claim front membership with both counts still equal. Then `_burn` **eats the water's amount as fuel**
##  (255 -> 250 -> 245 ..., verify-read2 measured). The water dries up silently.
func _front_has_no_unburnable(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 800, 200, 800, Mat.STONE))
	g.apply(CellGrid.cmd_fill(100, 799, 120, 799, Mat.WOOD))
	for x in range(100, 121):
		g.ignite(x, 799)
	t.ok(g.burning_count() > 0, "나무가 탄다 (전제)")
	t.eq(g.unburnable_in_front_count(), 0, "붙인 직후 파면에 탈 수 없는 재료가 없다")

	# **The guard's "consequence" is measured. Looking at the return value alone is not enough.**
	#  The check that watches `set_water` return false is already above (`_water_door_refuses_bad_targets`).
	#  That one **measures only "it refused" and not "what is bad if it doesn't"** — delete the guard and
	#   that check goes red, but **nobody watches the front actually get contaminated.**
	#  Here the contamination itself is measured as a value: a water cell on the front makes `_burn` **eat the water's amount as fuel.**
	var fuel_before := g.fuel_at(100, 799)
	t.ok(fuel_before > 0, "타는 칸에 연료가 있다 (전제)")
	g.set_water(100, 799, Tuning.WATER_MAX)
	t.eq(g.unburnable_in_front_count(), 0, "타는 칸에 물을 놓으려 해도 파면이 안 오염된다")
	t.eq(g.mat_at(100, 799), Mat.WOOD, "그 칸은 여전히 나무다")
	g.step()
	t.eq(g.unburnable_in_front_count(), 0, "한 틱 뒤에도 파면에 탈 수 없는 재료가 없다")
	t.eq(g.fuel_at(100, 799), fuel_before - Tuning.FIRE_BURN_PER_TICK,
		"연료가 정상적으로 준다 (물의 양을 연료로 먹고 있지 않다)")

	# Water is poured over burning wood — the only place the two axes can meet.
	for x in range(100, 121):
		g.set_water(x, 790, Tuning.WATER_MAX)
	# **It is looked at every tick.** Looking only at the last tick misses "it slipped in and back out", and in
	#  that one tick `_burn` has already eaten the water's amount.
	var dirty_ticks := 0
	for _i in 30:
		g.step()
		if g.unburnable_in_front_count() != 0 or g.claimed_slot_count() != g.burning_count():
			dirty_ticks += 1
	t.eq(dirty_ticks, 0, "물이 불 위로 흐르는 30틱 내내 파면이 깨끗하다")

	t.eq(g.unburnable_in_front_count(), 0, "물이 타는 자리에 닿아도 파면에 물이 안 들어간다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "그때 자리 표도 여전히 맞다")

	# And after it has all burnt out. That is the stretch where the self-swap (`at == last`) runs.
	for _i in 100:
		g.step()
	t.eq(g.unburnable_in_front_count(), 0, "다 탄 뒤에도 파면에 탈 수 없는 재료가 없다")


# ==================================================================
#  stage 3 — left-right sharing · the per-tick cap
# ==================================================================

## Builds one bowl and pours water into one side. `[grid, amount poured]`.
func _make_bowl(width: int, y_floor: int, poured_cols: int, depth: int) -> Array:
	var g := CellGrid.new()
	var x0 := 200
	g.apply(CellGrid.cmd_fill(x0 - 1, y_floor, x0 + width, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x0 - 1, y_floor - 40, x0 - 1, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x0 + width, y_floor - 40, x0 + width, y_floor, Mat.STONE))
	var poured := 0
	for k in poured_cols:
		for d in depth:
			if g.set_water(x0 + k, y_floor - 1 - d, Tuning.WATER_MAX):
				poured += Tuning.WATER_MAX
	return [g, poured]


## **Acceptance 2 — does it become a water surface rather than a staircase.** The most direct value for whether left-right sharing runs.
## **"It spread" is not enough** — spreading to one side only is still spreading. The **height difference** has to be measured.
func _water_lies_flat(t) -> void:
	var made := _make_bowl(32, 700, 8, 8)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	var settle := _settle(g, 4000)
	t.ok(settle > 1 and settle < 4000, "폭 32 그릇이 상한 안에 평형에 든다 (%d틱)" % settle)

	# Surface height = the topmost row holding water in each column.
	var lo := 1 << 30
	var hi := -1
	var dry := 0
	for k in 32:
		var top := -1
		for y in range(660, 700):
			if g.mat_at(200 + k, y) == Mat.WATER:
				top = y
				break
		if top < 0:
			dry += 1
			continue
		lo = mini(lo, top)
		hi = maxi(hi, top)
	# **One dry column means it did not lie flat.** Unwatched, "only the 8 poured columns are flat" passes,
	#  and that is exactly a staircase.
	t.eq(dry, 0, "32열이 전부 젖는다 (한쪽에만 8열 부었다)")
	# The poured amount (8 columns x 8 cells) spread over 32 columns is 2 cells high. The surface must be **within one cell** to count as flat.
	t.ok(hi - lo <= 1, "수면이 평평하다 (가장 높은 곳과 낮은 곳의 차 %d칸)" % (hi - lo))
	t.eq(_water_scan(g, 190, 650, 240, 705)[0], poured, "그동안 총량이 정확히 보존된다")


## **Is `WATER_MIN_DIFF` the heart of stopping.** Left at 0, odd numbers never divide, they shuttle by 1
##  and **the chunk never sleeps** — the spot where v1 died.
## **This check does not measure "it stops", it measures "that constant is the cause of stopping"** —
##  drop the value to 0 and it must go red, and that is what makes the knob a real knob.
func _min_diff_stops_the_shuffling(t) -> void:
	t.ok(Tuning.WATER_MIN_DIFF > 0,
		"차이 하한이 0보다 크다 (0이면 1씩 왕복하며 청크가 영영 안 잠든다)")

	# Two cells whose difference from the neighbour is at or below the floor must not move **a single grain**.
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(400, 800, 410, 800, Mat.STONE))
	# **The two cells have to be walled in.** With an empty cell beside them the difference is 255, so it spreads
	#  **regardless** of the floor, and then this check measures spreading, not the floor.
	g.apply(CellGrid.cmd_fill(403, 795, 403, 799, Mat.STONE))
	g.apply(CellGrid.cmd_fill(406, 795, 406, 799, Mat.STONE))
	g.set_water(404, 799, 100)
	g.set_water(405, 799, 100 + Tuning.WATER_MIN_DIFF)
	g.step()
	g.step()
	t.eq(g.aux_at(404, 799), 100, "차이가 하한과 같으면 왼쪽이 그대로다")
	t.eq(g.aux_at(405, 799), 100 + Tuning.WATER_MIN_DIFF, "오른쪽도 그대로다")
	t.eq(g.active_chunk_count(), 0, "그래서 그 청크가 잠든다")

	# One grain over the floor and it moves — measuring the other side too keeps this from being confused with "nothing moves at all".
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(400, 800, 410, 800, Mat.STONE))
	h.apply(CellGrid.cmd_fill(403, 795, 403, 799, Mat.STONE))
	h.apply(CellGrid.cmd_fill(406, 795, 406, 799, Mat.STONE))
	h.set_water(404, 799, 100)
	h.set_water(405, 799, 100 + Tuning.WATER_MIN_DIFF + 2)
	h.step()
	h.step()
	t.ok(h.aux_at(404, 799) > 100, "하한을 넘으면 실제로 옮겨진다 (%d)" % h.aux_at(404, 799))


## **The "invisible wall" at a column boundary.** The same accident as the row boundary, and **it hits far more often** —
##  it can be measured for the first time now that left-right sharing is in.
## verify-run confirmed "there is no diagonal path" in stage 2, but **that was a conclusion from when it only went downward.**
func _column_edge_wakes_the_neighbour(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	# Water in the **last cell** of chunk column 25, with its right (the first cell of chunk column 26) blocked.
	var x_edge := 26 * cc - 1
	t.eq(x_edge / cc, 25, "물이 청크 열 25의 마지막 칸에 있다")
	t.eq((x_edge + 1) / cc, 26, "그 오른쪽이 청크 열 26이다 — 이 검사의 전제")

	var g := CellGrid.new()
	var y := 850
	g.apply(CellGrid.cmd_fill(x_edge - 4, y + 1, x_edge + 6, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x_edge + 1, y, x_edge + 1, y, Mat.STONE))  # right wall
	# The left is blocked too. Unblocked, water leaks that way, and then **the chunk is already awake before the
	#  punch**, so what makes "it flows across the boundary" below happen can't be told apart.
	g.apply(CellGrid.cmd_fill(x_edge - 1, y, x_edge - 1, y, Mat.STONE))
	g.set_water(x_edge, y, Tuning.WATER_MAX)
	var settle := _settle(g, 60)
	t.ok(settle > 1, "물이 먼저 자리를 잡는다 (%d틱 — 루프가 헛돌지 않았다)" % settle)
	t.eq(g.active_chunk_count(), 0, "그리고 잠든다")

	# **Only the wall is punched.** The water cell is left alone — touching it wakes the water's chunk by its own hand.
	g.apply(CellGrid.cmd_fill(x_edge + 1, y, x_edge + 1, y, Mat.EMPTY))
	for _i in 20:
		g.step()
	t.ok(g.aux_at(x_edge + 1, y) > 0 or g.aux_at(x_edge + 1, y + 1) > 0,
		"청크 열 경계 너머로 물이 흘러든다 (보이지 않는 벽이 없다)")
	t.ok(g.aux_at(x_edge, y) < Tuning.WATER_MAX, "그만큼 원래 칸이 줄었다")


## **Acceptance 1-a — does narrow water really reach 0 active chunks.**
##  **A different check from acceptance 1-b. Bundled, the label gets wider than what it measures** (the design split it that way).
## The design's "width 32 · MIN_DIFF 16 => about 2,800 ticks" is a value from **spec's proxy implementation**, and `MIN_DIFF` is 4 now.
##  => **The tick count is not asserted** — what is measured is **does it reach 0**, and the actual tick count goes in the label.
func _narrow_bowl_reaches_zero(t) -> void:
	var made := _make_bowl(32, 750, 8, 6)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	var ticks := _settle(g, 6000)
	t.ok(ticks > 1 and ticks < 6000, "폭 32 그릇의 활성 청크가 0이 된다 (%d틱)" % ticks)
	t.eq(g.active_chunk_count(), 0, "정말 0이다")
	t.eq(_band_sum(g), 0, "밴드 요약 합도 0이다")

	# **And it must stay 0.** Being 0 for one tick is not equilibrium.
	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱을 더 돌려도 0이다")
	t.eq(_water_scan(g, 190, 700, 240, 755)[0], poured, "총량이 보존된다")


## ══ Acceptance 1-b — **and the acceptance itself was falsified, not just the check** ══
##
## ~~"Wide water does not reach 0. Instead the active chunks lock into a single digit."~~ **False.**
## Measured directly against this exact bowl (`_make_bowl(128, 900, 32, 8)`), total conserved and confirmed
## still settled 200 ticks later: **it reaches 0 active chunks at tick 1,032**, peak 13.
## `docs/design/water.md`'s standing claim that a 128-cell bowl *"does not stop by 4,000 ticks"* is stale with
## it. **The cause has not been chased** — `WATER_SUBSTEPS` = 3 is a suspicion, not a finding.
##
## **The check that stood here was vacuous and green.** It ran 1,200 ticks and read `late` only over
## `i >= 1100` — a window that now sits **entirely after the water stops moving**, so `late` was 0 and
## `late <= 32` passed while measuring nothing at all.
##
## **That is the same shape as `net_gate`'s re-kick hole, wearing different clothes**: a window positioned
## relative to an event that has since moved out from under it. Neither was wrong when written. **A check
## that observes a fixed window rather than the event itself goes vacuous silently the day the timing moves**,
## and reads green rather than flaky, because nothing about it is random.
## ⇒ **So this asserts the settle tick itself**, which cannot drift out from under the check: if the bowl
## gets faster or slower the number moves and the bounds bite, instead of the window quietly emptying.
##
## **Re-deriving after a water tuning change** (this will go red, and that is the system working — the same
## contract `net_water_rain`'s constants carry): run the bowl to `_SETTLE_CAP` recording the first tick at
## which `active_chunk_count()` is 0, and move the two bounds around the new value. **Do not widen them to
## make red go away** without saying what changed.

## Measured 1,032. **The bounds are wide on purpose and the floor is the load-bearing half**: a bowl that
## settles at 200 has almost certainly lost water rather than levelled it, which is a far worse bug than
## being slow, and no ceiling can catch it.
const _WIDE_SETTLE_MIN := 500
const _WIDE_SETTLE_MAX := 2000
## Only reached when it never settles — i.e. when this check is already going red.
const _SETTLE_CAP := 3000
## Held at 0 for this long afterwards. **Being 0 for one tick is not equilibrium** (`_narrow_bowl_reaches_zero`
## makes the same point for the narrow bowl, which is why the number is the same shape).
const _WIDE_HOLD_TICKS := 150


func _wide_bowl_settles_under_the_cap(t) -> void:
	var made := _make_bowl(128, 900, 32, 8)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	g.step()
	var peak := g.active_chunk_count()
	var settled_at := -1
	var n := 1
	while n < _SETTLE_CAP:
		g.step()
		n += 1
		var a := g.active_chunk_count()
		peak = maxi(peak, a)
		if a == 0:
			settled_at = n
			break

	t.ok(peak > 0, "넓은 물이 실제로 움직였다 (최대 %d청크 — 0이면 아무 일도 안 일어난 것이다)" % peak)
	t.ok(settled_at > 0, "%d틱 안에 활성 청크가 0이 된다 (안 멎으면 여기가 빨개진다)" % _SETTLE_CAP)
	# **Both bounds, and one bite does not prove the range** — proven at both ends against a real knob:
	#  `WATER_MIN_DIFF` 4 -> 32 settles at **142** and trips the floor; 4 -> 1 settles at **2,074** and trips
	#  the ceiling. The ceiling catches "it never finishes"; the floor catches "it finished far too early",
	#  which is what losing water looks like from outside.
	#
	# **The wording carries `settled_at` = -1 too.** When it never settles the assert above is the one that
	#  says so, and these two fire alongside it — a message reading "it settled too fast (-1)" would send the
	#  next reader hunting a leak that is not there. **The count stays fixed rather than being made
	#  conditional**, because a check count that changes shape between runs is its own signal to spend.
	t.ok(settled_at > _WIDE_SETTLE_MIN,
		"멎은 틱(%d)이 %d보다 크다 — 너무 빨리 멎으면 평평해진 게 아니라 샌 것이다 (-1은 '안 멎었다')"
			% [settled_at, _WIDE_SETTLE_MIN])
	t.ok(settled_at > 0 and settled_at < _WIDE_SETTLE_MAX,
		"그리고 %d보다 작다 (%d틱 — 측정값 1,032에서 멀어지면 물 튜닝이 움직인 것이다)"
			% [_WIDE_SETTLE_MAX, settled_at])
	# **The cap is never approached on the way.** The real failure is growing without bound; a fixed ceiling
	#  is what catches it, and the design measured a maximum of 16-18 at width 128.
	t.ok(peak < 64, "도는 내내 64 아래다 (최대 %d, 상한 %d 훨씬 아래)" % [
		peak, Tuning.MAX_CHUNKS_PER_TICK])

	# **And it stays 0.** One tick at zero is not equilibrium.
	for _i in _WIDE_HOLD_TICKS:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 %d틱을 더 돌려도 0이다" % _WIDE_HOLD_TICKS)
	# **The total is the other half of this acceptance** — settling is fine, leaking is not. **And this is
	#  what makes the floor above meaningful**: the two together say it levelled rather than lost.
	t.eq(_water_scan(g, 190, 850, 340, 905)[0], poured, "멎은 뒤에도 총량이 정확히 같다")


## **Left-right bias — does the dir flip actually run.** v1 had this net.
##
## **The terrain and the pour must both be symmetric.** If either is not, this check measures nothing.
## **The tick count is cut on an even number** — dir flips every tick, so cutting on an odd number leaves the
##  last tick's direction hanging and **the two sides differ even with no bias.** That is not a fault, it is measuring wrong.
func _left_right_has_no_bias(t) -> void:
	var g := CellGrid.new()
	var cx := 600
	var y := 950
	g.apply(CellGrid.cmd_fill(cx - 40, y + 1, cx + 40, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(cx - 41, y - 20, cx - 41, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(cx + 41, y - 20, cx + 41, y + 1, Mat.STONE))
	# Poured into the single middle column — the only pour that is exactly left-right symmetric.
	var poured := 0
	for d in 12:
		g.set_water(cx, y - d, Tuning.WATER_MAX)
		poured += Tuning.WATER_MAX

	for _i in 400:
		g.step()

	var left: int = _water_scan(g, cx - 41, y - 30, cx - 1, y + 1)[0]
	var right: int = _water_scan(g, cx + 1, y - 30, cx + 41, y + 1)[0]
	var mid: int = _water_scan(g, cx, y - 30, cx, y + 1)[0]
	t.ok(left + right + mid == poured, "총량이 보존된다 (좌 %d + 중 %d + 우 %d)" % [left, mid, right])
	t.ok(left > 0 and right > 0, "양쪽으로 다 퍼졌다 (좌 %d · 우 %d)" % [left, right])
	# **"Left and right are exactly equal" cannot come out of this rule in principle. That sentence in the design is wrong.**
	#  Within one cell the dir side is divided **first** and **the amount left after that** is divided to the other
	#  side, so left and right are not symmetric within one tick. Even with dir flipping every tick, `diff >> 1`
	#  **rounds down**, so rounding change is left over and does not cancel exactly. The measured difference is **1** out of 3,060 (0.03%).
	# **So what is measured is "bias", not "identity".** Bias means the difference exceeds one water cell's worth
	#  and grows as the ticks go on — the threshold below splits those two.
	# **Do not narrow the threshold to 0.** It cannot be made green, and then the next person deletes this check.
	t.ok(absi(left - right) <= Tuning.WATER_MAX,
		"좌우 편향이 없다 (차이 %d — 물 한 칸 %d 아래면 반올림 잔돈이다)" % [
			absi(left - right), Tuning.WATER_MAX])


## **The per-tick cap — it pushes them back, it does not throw them away.**
##  Throwing them away means "the water disappears", and that is not a safety net but a fault. It is measured by the total.
## **The cap has to actually be hit** — unhit, this check spins idle as a whole.
##  Laying `cmd_fill` broadly makes `_write_cell` mark thousands of chunks (item R of the design's "risks").
func _tick_cap_delays_but_never_drops(t) -> void:
	var g := CellGrid.new()
	# **Only tall enough to clear the cap with margin, not "past 500 rows".** Width 2048 / `CHUNK_CELLS`(16)
	#  = 128 chunk columns already exceeds `MAX_CHUNKS_PER_TICK`(100) on its own; 4 chunk-rows (64px) of height
	#  gives 512 chunks touched — 5.12x the cap — instead of the 3,200 the old 401-row fill painted.
	#  harness-manager measured: this alone was 810ms of `net_water`'s 13s (CellGrid painting is O(area) — the
	#  same lesson as the `FLOOR_DEPTH_CY` thin-floor fix, just for a horizontal cap test instead of a vertical one).
	g.apply(CellGrid.cmd_fill(0, 100, 2047, 163, Mat.STONE))
	g.step()
	# **Evidence the cap actually bit.** Without this, everything below measures nothing.
	t.eq(g.active_chunk_count(), Tuning.MAX_CHUNKS_PER_TICK,
		"깨어 있는 청크가 상한에서 정확히 잘린다")

	# **What was cut off does not disappear** — the next tick must be awake up to the cap again.
	g.step()
	t.ok(g.active_chunk_count() > 0, "다음 틱에도 깨어 있다 (잘린 청크가 버려지지 않았다)")

	# And in the end they are all worked through and it falls asleep.
	var ticks := _settle(g, 200)
	t.ok(ticks < 200, "밀린 청크가 결국 다 처리되고 잠든다 (%d틱)" % ticks)

	# Below the cap nothing is cut — measuring the other side keeps this from being confused with "it always cuts".
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(0, 100, 100, 120, Mat.STONE))
	h.step()
	t.ok(h.active_chunk_count() < Tuning.MAX_CHUNKS_PER_TICK,
		"작은 지형은 상한에 안 걸린다 (%d청크)" % h.active_chunk_count())

	# Even while the cap bites, the total is conserved — that is the safety net's contract itself.
	var w := CellGrid.new()
	w.apply(CellGrid.cmd_fill(0, 600, 2047, 600, Mat.STONE))
	# The right wall. Without it water passes the end of the floor and goes **outside the checked rectangle**,
	#  which is indistinguishable from "it leaked" — going red without leaking makes the next person delete the check.
	w.apply(CellGrid.cmd_fill(2048, 560, 2048, 600, Mat.STONE))
	var poured := 0
	for x in range(0, 2048, 4):
		if w.set_water(x, 599, Tuning.WATER_MAX):
			poured += Tuning.WATER_MAX
	for _i in 60:
		w.step()
	t.eq(_water_scan(w, 0, 540, 2047, 601)[0], poured, "상한에 걸리는 동안에도 총량이 보존된다")


## Determinism — does the same command sequence build the same grid (in multiplayer each side computes water itself).
##
## **What this check measures is narrow. Do not read the label broadly.**
##  Running the same code twice in the same process **always gives the same answer, because a wrong order is wrong identically.**
##  => It catches only "did it lean on something that isn't state" (dictionary hash order · object addresses · clocks · randomness),
##   and **"the cutting order is wrong" cannot be caught in principle.**
## **That is split between `net_determinism`'s text scan and the cap check above** —
##  that the cap cuts **per chunk** is pinned by `active_chunk_count() == MAX_CHUNKS_PER_TICK`, and
##  "only half a chunk's rows run" is prevented by **the sweep structure itself, which reads `_awake` per chunk** (a structural argument).
## **Calling it a structural argument means there is no net.** Whoever changes the sweep has to read this.
func _same_commands_give_the_same_grid(t) -> void:
	var a := _run_scenario()
	var b := _run_scenario()
	# **All of `_aux` is butted byte for byte.** One differing cell splits the two worlds forever after.
	var diff := 0
	for y in range(560, 640):
		for x in range(150, 350):
			if a.aux_at(x, y) != b.aux_at(x, y) or a.mat_at(x, y) != b.mat_at(x, y):
				diff += 1
	t.eq(diff, 0, "같은 커맨드 열이 같은 격자를 만든다")
	t.eq(a.active_chunk_count(), b.active_chunk_count(), "활성 청크 수도 같다")
	t.ok(_water_scan(a, 150, 560, 350, 640)[0] > 0, "그 안에 물이 실제로 있다 (검사의 전제)")


func _run_scenario() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(150, 620, 350, 620, Mat.STONE))
	for k in 40:
		g.set_water(200 + k, 600, Tuning.WATER_MAX)
	for i in 60:
		g.step()
		if i == 20:
			g.apply(CellGrid.cmd_blast(250, 620, 6, 9, CellGrid.IGNITE_ANY))
		if i == 40:
			g.apply(CellGrid.cmd_carve(220, 618, 4))
	return g


## **Is `_band_awake` alive — measurable only through time.**
##
## **Structure cannot catch it.** The check butting the summary against a direct count catches only **divergence**,
##  and **killing `_band_awake` and `_band_dirty` outright still leaves the grid running exactly right** — it only gets slower.
##  => Measured, `step()` on a sleeping grid goes **5.25us -> 8,114us (1,546x)**. That is 16% of the budget.
##
## **It is not measured in absolute terms — machines vary.** It is measured as a **multiple of a yardstick** taken on the same machine.
##  The yardstick is `active_chunk_count()` (a native count over 16,128 entries, measured 2.25us) — a faster machine
##  speeds that up too, so the ratio holds.
##
##      now              sleeping step() / yardstick ~ 5.25 / 2.25 = **2.3x**
##      without summary                              ~ 8,114 / 2.25 = **3,600x**
##  => **Threshold 50x.** 21x above where it is now, 72x below the broken state. There is plenty of room on both sides.
## Do not narrow the threshold — **this net switching itself off from jitter** is worse than `_band_awake` dying.
func _sleeping_grid_is_cheap(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	# 16,128 chunks wake but the per-tick cap is 512, so **putting them all to sleep takes dozens of ticks.**
	#  Left at a fixed count, this check would be measuring a grid that isn't asleep.
	var calm := _settle(g, 500)
	t.ok(calm > 1 and calm < 500, "격자가 결국 다 잠든다 (%d틱)" % calm)
	t.eq(g.active_chunk_count(), 0, "격자가 완전히 잠들었다 (이 검사의 전제)")

	var n := 2000
	var t0 := Time.get_ticks_usec()
	for _i in n:
		g.active_chunk_count()
	var ref := Time.get_ticks_usec() - t0

	var t1 := Time.get_ticks_usec()
	for _i in n:
		g.step()
	var slept := Time.get_ticks_usec() - t1

	t.ok(ref > 0, "기준자가 잴 수 있는 시간을 낸다 (%dμs / %d회)" % [ref, n])
	t.ok(slept <= ref * 50,
		"잠든 격자 step() 이 기준자의 50배 아래다 (%dμs vs 기준 %dμs — %d배)" % [
			slept, ref, slept / maxi(ref, 1)])


# ==================================================================
#  stage 4 — the shallow bit
# ==================================================================

## **Do the amount and the bit move in one place.** If they diverge it shows up **on screen only** —
##  the sim looks only at the amount and the shader only at the bit, so neither corrects the other.
##
## **Both sides of the boundary value are measured.** Measuring only "at or below the threshold it turns on" passes an implementation that **always turns it on**.
## The threshold value is not baked in here — if `WATER_WET` changes, a hand-written number goes quietly stale.
func _shallow_bit_tracks_the_amount(t) -> void:
	var wet := Tuning.WATER_WET
	t.ok(wet > 0 and wet < Tuning.WATER_MAX,
		"임계가 0과 최대량 사이다 (%d — 아니면 아래 두 쪽 중 하나가 원리적으로 안 나온다)" % wet)
	# The two bits don't overlap — overlapping would make "shallow water" and "a burning cell" the same cell on screen.
	t.eq(Mat.FLAG_SHALLOW & Mat.FLAG_BURNING, 0, "얕음 비트와 불 비트가 안 겹친다")
	t.ok(Mat.FLAG_SHALLOW < 16, "얕음 비트가 하위 4비트 안이다 (L8 정밀도 안전선)")

	var g := CellGrid.new()
	# **Just above** the boundary: not shallow.
	g.set_water(500, 100, wet + 1)
	t.eq(g.flag_at(500, 100) & Mat.FLAG_SHALLOW, 0, "임계보다 한 톨 많으면 얕음이 꺼져 있다")
	# **Exactly** at the boundary: shallow ("at or below" is the contract).
	g.set_water(501, 100, wet)
	t.eq(g.flag_at(501, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "임계와 같으면 얕음이 켜진다")
	g.set_water(502, 100, 1)
	t.eq(g.flag_at(502, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "한 톨만 있어도 얕음이다")
	g.set_water(503, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(503, 100) & Mat.FLAG_SHALLOW, 0, "꽉 찬 칸은 안 얕다")

	# **Crossing back and forth flips it along.** Measuring once can't separate out "correct only at the start".
	g.set_water(504, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, 0, "깊게 시작한다")
	g.set_water(504, 100, wet)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "얕아지면 켜진다")
	g.set_water(504, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, 0, "다시 깊어지면 꺼진다")

	# **The clearing side has to bring it down too.** Otherwise an empty cell is left holding the bit, and the next
	#  time that cell becomes water it starts with the amount and the bit out of step — it shows up on screen only.
	# **It only measures if the clearing happens from "shallow water".** Clearing from deep water (bit already 0)
	#  leaves it **green** even with the clearing line deleted whole — it had been written that way and the mutation didn't bite.
	g.set_water(505, 100, wet)
	t.eq(g.flag_at(505, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "먼저 얕음을 켠다 (검사의 전제)")
	g.set_water(505, 100, 0)
	t.eq(g.mat_at(505, 100), Mat.EMPTY, "양 0이면 빈칸이 된다")
	t.eq(g.flag_at(505, 100), 0, "**켜져 있던** 얕음 비트가 빈칸에 안 남는다")

	# **Beyond direct writes — is it right when the sim rolls too.** Measuring only `set_water` passes even if
	#  the paths `_water_step` takes (`_water_fall`, `_water_share`) never touch the bit.
	# **It takes a bowl walled in for both depths to appear at once.** Poured onto an open floor, water spreads to
	#  equilibrium and **goes entirely shallow** — it was written that way and went red with "0 deep cells".
	#  => Poured into a width-8 bowl so it comes to **2 layers + 16 left over**: the lower two rows are 255, the top row 16.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(599, 200, 608, 200, Mat.STONE))
	h.apply(CellGrid.cmd_fill(599, 188, 599, 199, Mat.STONE))
	h.apply(CellGrid.cmd_fill(608, 188, 608, 199, Mat.STONE))
	for k in 16:
		h.set_water(600 + (k % 8), 195 - (k / 8), Tuning.WATER_MAX)
	h.set_water(600, 193, 128)
	var settle := _settle(h, 200)
	t.ok(settle > 1 and settle < 200, "부은 물이 흘러 정착한다 (%d틱)" % settle)

	var mismatched := 0
	var shallow_cells := 0
	var deep_cells := 0
	for y in range(185, 201):
		for x in range(600, 608):
			if h.mat_at(x, y) != Mat.WATER:
				# A shallow bit left on a non-water cell is out of step too.
				if (h.flag_at(x, y) & Mat.FLAG_SHALLOW) != 0:
					mismatched += 1
				continue
			var want := Mat.FLAG_SHALLOW if h.aux_at(x, y) <= wet else 0
			if (h.flag_at(x, y) & Mat.FLAG_SHALLOW) != want:
				mismatched += 1
			if want != 0:
				shallow_cells += 1
			else:
				deep_cells += 1
	t.eq(mismatched, 0, "흘러서 정착한 물의 양과 비트가 한 칸도 안 어긋난다")
	# **Evidence both sides actually appeared.** If either is 0, the check above ran only half.
	t.ok(shallow_cells > 0, "얕은 칸이 실제로 생긴다 (%d칸 — 수면 쪽이다)" % shallow_cells)
	t.ok(deep_cells > 0, "깊은 칸도 남는다 (%d칸 — 그릇 속이다)" % deep_cells)


# ==================================================================
#  stage 5 — the water rune
# ==================================================================

const SpellSim := preload("res://src/sim/spell_sim.gd")

## **`CMD_WATER` must not pass through `_write_cell`.** Passing it makes cells whose material is WATER and
##  whose **amount is 0**, and those evaporate silently on the first sweep (the same spot `cmd_fill` got burned).
## **It fills without overwriting** — overwriting deep water with a shallow value makes **the water rune reduce water.**
func _water_disc_fills_without_wiping(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_water(300, 300, 6, 200))
	var got := _water_scan(g, 280, 280, 320, 320)
	t.ok(got[1] > 0, "물 커맨드가 칸을 적신다 (%d칸)" % got[1])
	t.eq(got[2], 200, "양이 커맨드가 준 값 그대로 들어간다 (증발하지 않는다)")
	t.eq(g.aux_at(300, 300), 200, "한가운데도 200이다")
	# **It is a disc.** A square would wet the corners too — it must be the same shape as `_disc`.
	t.eq(g.aux_at(306, 306), 0, "원 밖 모서리는 안 젖는다")
	t.eq(g.aux_at(306, 300), 200, "원 안 끝은 젖는다")

	# **Deeper water is not overwritten with a shallower value.**
	g.set_water(300, 300, Tuning.WATER_MAX)
	g.apply(CellGrid.cmd_water(300, 300, 6, 100))
	t.eq(g.aux_at(300, 300), Tuning.WATER_MAX, "깊은 칸이 얕은 값으로 안 줄어든다")
	t.eq(g.aux_at(302, 300), 200, "옆 칸도 원래 값(200)보다 안 줄어든다")

	# Terrain is left alone — the water rune is not destruction.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(400, 400, 420, 420, Mat.STONE))
	h.apply(CellGrid.cmd_water(410, 410, 6, Tuning.WATER_MAX))
	t.eq(h.mat_at(410, 410), Mat.STONE, "돌은 물로 안 바뀐다")
	t.eq(h.count_material(Mat.WATER), 0, "고체 속에는 물이 한 칸도 안 생긴다")

	# Burning cells are skipped too — that is the path that leaves a ghost on the burn front.
	var f := CellGrid.new()
	f.apply(CellGrid.cmd_fill(500, 500, 510, 500, Mat.WOOD))
	f.ignite(505, 500)
	f.apply(CellGrid.cmd_water(505, 500, 4, Tuning.WATER_MAX))
	t.eq(f.unburnable_in_front_count(), 0, "타는 칸에 물을 부어도 파면이 안 오염된다")
	t.eq(f.claimed_slot_count(), f.burning_count(), "자리 표도 맞다")

	# An out-of-range amount barks and is discarded.
	t.expect_error("CellGrid.cmd_water: amount")
	var b := CellGrid.new()
	b.apply(CellGrid.cmd_water(600, 600, 4, Tuning.WATER_MAX + 1))
	t.eq(b.count_material(Mat.WATER), 0, "범위 밖 양은 한 칸도 안 적신다")

	# It wakes the chunk — without that, the water it made freezes in place.
	var w := CellGrid.new()
	w.apply(CellGrid.cmd_water(700, 700, 6, Tuning.WATER_MAX))
	w.step()
	t.ok(w.chunk_awake_at(700, 700), "적신 자리의 청크가 깨어난다")


## **Fire the water rune and water appears; fire another rune and it doesn't.**
##  **Measuring the other side is the point** — measuring only "water appears" also passes an implementation
##   where **every impact makes water**, and then the rune is no longer an axis.
##
## **The scan window is read off the impact, not written down.** It used to be the fixed rectangle
##  `(380,180)-(420,220)`, and `speed` 20 -> 12 walked the impact point straight out of it: the bolt is fired
##  horizontally across 100 cells, so **fewer cells per tick means more ticks in the air means a longer fall**,
##  and the impact row drops well past `cy 220`. The main branch went red — but **look at which way the negative
##  control would have gone.** Its `total == 0` would have stayed green while measuring nothing at all, because
##  the window no longer contained the impact point at all. That is the exact shape CLAUDE.md names ("a loop
##  whose condition is false from the start"), and a constant that has to be re-derived every time `speed` moves
##  is the thing that produces it. => The window is now **the water disc's own bounding box, centred on the cell
##  the impact was notified at**, which is what the label "at the impact point" says.
func _water_rune_makes_water(t) -> void:
	for element in Tuning.ELEM_ALL:
		var g := CellGrid.new()
		var spell := SpellSim.new()
		# A wall is stood up and it is fired at — the impact has to actually happen for this to measure.
		g.apply(CellGrid.cmd_fill(400, 0, 400, 400, Mat.STONE))
		t.ok(spell.fire(SpellSim.cmd_fire(300, 200, 1, 0, element, 0)),
			"룬 %d 로 발사된다 (검사의 전제)" % element)
		var hit := false
		var hit_cx := -1
		var hit_cy := -1
		for _i in 60:
			spell.step(g)
			if spell.active_count() == 0:
				# **This is the only moment the impact point can be read.** `_advance` ends a dying bolt's
				#  segment notice at **the impact cell's centre** (not at `x1`), and `step()` clears every
				#  notice at the top of the next tick — one tick later there is nothing left to read.
				if spell.seg_count() > 0:
					hit_cx = spell.get_seg_x1()[0] >> SpellSim.FP_SHIFT
					hit_cy = spell.get_seg_y1()[0] >> SpellSim.FP_SHIFT
				hit = true
				break
		t.ok(hit, "룬 %d 의 탄이 벽에 닿는다" % element)
		# The impact point is **the empty cell just before the solid** (`spell_sim._walk`), and the wall is the
		#  single column 400 — so this pins the window's origin by value. Without it a broken segment notice
		#  would silently move the window somewhere harmless and both branches below would measure nothing.
		t.eq(hit_cx, 399, "룬 %d 의 착탄점이 벽(400) 바로 앞 칸이다 (창의 기준점이다)" % element)

		var wr := Tuning.water_r(0)
		var total: int = _water_scan(g, hit_cx - wr, hit_cy - wr, hit_cx + wr, hit_cy + wr)[0]
		if element == Tuning.ELEM_WATER:
			t.ok(total > 0, "물 룬은 착탄점에 물을 만든다 (합 %d)" % total)
			# **The grid has to be stepped one tick to see it.** `spell.step()` does not run the grid's flip —
			#  a command only marks `_dirty`, and the thing that turns it into `awake` is `_chunk_flip()`.
			#  Not knowing that and looking straight away is always false, so it misdiagnoses as "it doesn't wake" (that actually happened).
			g.step()
			t.ok(g.active_chunk_count() > 0,
				"착탄이 만든 물이 청크를 깨운다 (%d개)" % g.active_chunk_count())
		else:
			t.eq(total, 0, "룬 %d 는 물을 한 톨도 안 만든다" % element)

	# **Does a different amount per generation derive from the radius.** A deeper generation makes a smaller disc, so the total drops too.
	t.ok(Tuning.water_r(1) < Tuning.water_r(0),
		"세대 1의 물 반경이 세대 0보다 작다 (%d < %d)" % [Tuning.water_r(1), Tuning.water_r(0)])
	var a := CellGrid.new()
	a.apply(CellGrid.cmd_water(800, 800, Tuning.water_r(0), Tuning.WATER_MAX))
	var b := CellGrid.new()
	b.apply(CellGrid.cmd_water(800, 800, Tuning.water_r(1), Tuning.WATER_MAX))
	var sum_a: int = _water_scan(a, 780, 780, 820, 820)[0]
	var sum_b: int = _water_scan(b, 780, 780, 820, 820)[0]
	t.ok(sum_b < sum_a, "깊은 세대가 만드는 물이 더 적다 (%d < %d)" % [sum_b, sum_a])


# ==================================================================
#  stage 6 — fire and water
# ==================================================================

## One row of wood + a stone floor beneath it.
## The wood is laid **on stone** — water dropping below the wood would blur the neighbour acceptance.
func _make_forest(y: int) -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, y + 1, 160, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(100, y, 160, y, Mat.WOOD))
	return g


## Pens one water cell **above** the wood row. **Walling the sides in stone is the point.**
##
## **Unwalled, the water covers the whole wood row** — below is solid (wood) so it can't descend, and the
##  sides are empty so it spreads to the ends. Then **the whole forest is wet and nothing burns at all**,
##  and "did the fire spread as far as the water" becomes false in principle.
## **It was actually written that way and the check spun idle** — the fire never even got near the water
##  and "0 flickers" was green anyway. **The premise assertion caught it.**
func _wet_pocket(g: CellGrid, x: int, y_wood: int) -> void:
	g.apply(CellGrid.cmd_fill(x - 1, y_wood - 1, x - 1, y_wood - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x + 1, y_wood - 1, x + 1, y_wood - 1, Mat.STONE))
	g.set_water(x, y_wood - 1, Tuning.WATER_MAX)


## **Water arriving beside an already-burning cell puts it out** — the `_burn` side path.
##  **A different check from `_wet_neighbour_never_catches` below (the ignition side).** Bundled into one,
##   you can't tell which path died — the two really do live in different functions.
func _water_puts_out_fire(t) -> void:
	var g := _make_forest(300)
	g.ignite(130, 300)
	for _i in 8:
		g.step()
	var lit := g.burning_count()
	t.ok(lit > 1, "불이 먼저 번진다 (%d칸 — 검사의 전제)" % lit)
	t.eq(g.unburnable_in_front_count(), 0, "그때 파면이 깨끗하다")

	# **One named cell is measured.** "Fire eventually reaches 0" measures **nothing at all** —
	#  deleting the extinguishing whole still takes those cells to 0 on their own as the fuel runs out (confirmed by inverting).
	#  => What splits it is **"fuel was left, it went out, and the wood survived"**.
	t.ok(g.is_burning(130, 300), "지목한 칸이 타고 있다 (검사의 전제)")
	t.ok(g.fuel_at(130, 300) > 0, "그 칸에 연료가 아직 남아 있다 (%d)" % g.fuel_at(130, 300))
	t.eq(g.mat_at(130, 300), Mat.WOOD, "그리고 아직 나무다")

	# **Water is poured into the middle of the fire.** It uses the door the water rune actually takes (`cmd_water`).
	g.apply(CellGrid.cmd_water(130, 299, 8, Tuning.WATER_MAX))
	g.step()
	t.ok(not g.is_burning(130, 300), "물이 닿은 다음 틱에 곧바로 꺼진다 (연료가 남았는데도)")
	t.eq(g.mat_at(130, 300), Mat.WOOD, "그 나무가 살아남는다 (다 탄 게 아니라 꺼진 것이다)")
	t.eq(g.aux_at(130, 300), 0, "꺼진 칸의 연료 자리가 0으로 돌아간다")

	var ticks := 1
	while g.burning_count() > 0 and ticks < 200:
		g.step()
		ticks += 1
	t.ok(ticks < 200, "물 밖의 불도 결국 다 꺼진다 (%d틱)" % ticks)
	t.eq(g.burning_count(), 0, "정말 0이다")
	t.ok(g.count_material(Mat.WOOD) > 0,
		"나무가 남아 있다 (%d칸)" % g.count_material(Mat.WOOD))
	t.eq(g.unburnable_in_front_count(), 0, "끈 뒤에도 파면에 탈 수 없는 재료가 없다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "자리 표도 맞다")

	# **The water is not reduced** — evaporating it by the amount extinguished would make `_burn` pass
	#  `_write_water`, and that rides `_touch`, so **a lake beside a burning forest wakes every tick.**
	# **That price was paid as "shallow water can't extinguish"** (decided by the user) —
	#  instead of shaving the amount, **spread thin it loses its firebreak on its own.** See `_shallow_water_does_not_put_out_fire`.
	t.ok(g.count_material(Mat.WATER) > 0, "물은 그대로 남는다 (%d칸)" % g.count_material(Mat.WATER))


## **The other side.** Without water it must not go out — unmeasured, it is indistinguishable from "the fire just
##  went out", and the check above becomes **one that measures nothing.**
func _no_water_means_no_rescue(t) -> void:
	var g := _make_forest(400)
	g.ignite(130, 400)
	for _i in 8:
		g.step()
	t.ok(g.burning_count() > 1, "같은 조건에서 불이 번진다 (검사의 전제)")

	# Runs **the same number of ticks** as the check above. Only the water is missing.
	for _i in 20:
		g.step()
	t.ok(g.burning_count() > 0,
		"물이 없으면 같은 시간에 안 꺼진다 (%d칸이 아직 탄다)" % g.burning_count())

	# And in the end it goes out **because the fuel runs out** — no wood left is the evidence.
	var ticks := 0
	while g.burning_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
	t.ok(ticks < 400, "연료가 다하면 결국 꺼진다 (%d틱)" % ticks)
	t.eq(g.count_material(Mat.WOOD), 0, "그때는 나무가 한 칸도 안 남는다 (다 탔다)")


## **Wood beside water never catches in the first place** — the `_ignite_cell` side path.
##  Without this it becomes "it catches and goes out at once", and on screen that is a **flicker** (= read as a fault).
func _wet_neighbour_never_catches(t) -> void:
	var g := _make_forest(500)
	g.set_water(130, 499, Tuning.WATER_MAX)
	t.ok(not g.ignite(130, 500), "물 아래 나무에는 직접 붙여도 안 붙는다")
	t.eq(g.burning_count(), 0, "파면에도 안 올라간다")

	# **All four directions are measured one by one.** Measuring only the left leaves everything green even with
	#  `_water_adjacent` **cut down to two directions** (confirmed). One dead direction lets fire cross water on that side.
	# To make a neighbouring cell water it has to **be dug first** — `set_water` does not write over wood.
	var h := _make_forest(600)
	h.apply(CellGrid.cmd_fill(129, 600, 129, 600, Mat.EMPTY))
	t.ok(h.set_water(129, 600, Tuning.WATER_MAX), "판 자리에 물을 놓는다 (전제)")
	t.ok(not h.ignite(130, 600), "**왼쪽** 칸이 물이어도 안 붙는다")

	var r := _make_forest(620)
	r.apply(CellGrid.cmd_fill(131, 620, 131, 620, Mat.EMPTY))
	t.ok(r.set_water(131, 620, Tuning.WATER_MAX), "오른쪽을 파고 물을 놓는다 (전제)")
	t.ok(not r.ignite(130, 620), "**오른쪽** 칸이 물이어도 안 붙는다")

	# Below — **below** the wood row is stone floor, so it is dug there and water is placed.
	var d2 := _make_forest(640)
	d2.apply(CellGrid.cmd_fill(130, 641, 130, 641, Mat.EMPTY))
	t.ok(d2.set_water(130, 641, Tuning.WATER_MAX), "아래를 파고 물을 놓는다 (전제)")
	t.ok(not d2.ignite(130, 640), "**아래** 칸이 물이어도 안 붙는다")

	# Above — the first lines of this function (wood under water) already measure it.

	# **The other side**: out of the water's reach it does catch. Unmeasured, "it never catches anywhere" passes.
	var d := _make_forest(700)
	d.set_water(120, 699, Tuning.WATER_MAX)
	t.ok(d.ignite(140, 700), "물에서 떨어진 나무에는 붙는다")

	# Spreading stops at water too — measuring only direct ignition never touches `_burn`'s spread path.
	var s := _make_forest(800)
	_wet_pocket(s, 140, 800)
	s.ignite(120, 800)
	for _i in 60:
		s.step()
	t.eq(s.mat_at(140, 800), Mat.WOOD, "번지던 불이 물 아래 나무에서 멈춘다")
	t.ok(s.mat_at(125, 800) != Mat.WOOD, "그 앞쪽 나무는 탔다 (검사의 전제 — 불이 실제로 번졌다)")


## **Is there no oscillation — does the wood under water not repeat "catches, goes out".**
##
## **Extinguishing only in `_burn` gives exactly this**: a neighbouring fire spreads and it catches -> next tick
##  it goes out -> that neighbour is still burning so it catches again. On screen it looks like **fire flickering
##  at the water's edge**, and since `_write_cell` runs each time, that chunk stays awake throughout.
##
## **What is measured is not "does it sleep" but "does it catch for even one tick". That distinction is this check's whole point.**
##  **Written first as "does it finish and sleep", it was green even before the block was added** (measured).
##   The oscillation **ends when the neighbouring wood runs out of fuel** — that is, it is **finite.** So "it never
##   sleeps" is false, and "does it finish and sleep" **passes even with the oscillation present.**
##  => **It is caught only by looking at that cell every tick.** It was pinned after confirming it was red before the block.
func _fire_beside_water_does_not_flicker(t) -> void:
	var g := _make_forest(900)
	# **Penned** water at one end of the forest, fire at the other. The fire spreads toward the water and stops.
	_wet_pocket(g, 150, 900)
	g.ignite(110, 900)

	# **The wood under the water is looked at every tick.** Burning for even one tick is a flicker.
	var lit_ticks := 0
	var ticks := 0
	while g.burning_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
		if g.is_burning(150, 900):
			lit_ticks += 1
	t.ok(ticks < 400, "불이 결국 꺼진다 (%d틱)" % ticks)
	# **Evidence the fire actually spread as far as the water.** If it doesn't, this check spins idle as a whole.
	t.ok(g.mat_at(149, 900) != Mat.WOOD, "불이 물 바로 옆까지 번져 왔다 (검사의 전제)")
	t.eq(lit_ticks, 0, "물 아래 나무가 한 틱도 안 붙는다 (붙었다 꺼졌다를 반복하지 않는다)")

	var settle := _settle(g, 200)
	t.ok(settle < 200, "그 뒤 격자가 잠든다 (%d틱)" % settle)
	t.eq(g.mat_at(150, 900), Mat.WOOD, "물 아래 나무는 안 탔다")
	t.ok(g.count_material(Mat.WATER) > 0, "물도 그대로다")


## **No cell carries shallow and burning at the same time.**
##
## **This property holds up one code comment** — `cell_grid.gdshader`'s "put the water branch ahead of the fire
##  branch" leans on "the two bits cannot stand on the same cell", and **there was no check measuring that**.
## It holds for two reasons: water has 0 fuel so ignition can't reach it, and `_write_water` writes only over
##  EMPTY and WATER. **If either one breaks**, shallow water is drawn as fire on screen.
##
## **The whole grid is measured with a native `count()`.** Those two are the only bits used in `_flag`,
##  so "both on" is exactly the byte value `SHALLOW|BURNING` — that premise is asserted first below.
##  A third state bit would make this arithmetic leak, so **this check has to be fixed that day.**
##
## **When this check bites was measured — it bites only when all three guards are gone**:
##  `_ignite_cell`'s fuel guard · the water-adjacency guard in the same function · `_burn`'s extinguishing.
##  Remove one or two and it stays **green** — the remaining guard intercepts first.
##  => **This is not a first-line detector but a backstop.** Each of the three ahead of it has its own check,
##   and this is the last line preventing **the screen from lying when all three collapse at once.**
## Do not read it as "this is green, so the two bits don't overlap" — **it can be green because the guards are alive.**
func _no_cell_carries_both_bits(t) -> void:
	# Premise: are the bits used in `_flag` really only two. Confirmed by sweeping the constant names.
	var consts: Dictionary = (Mat as GDScript).get_script_constant_map()
	var bits := 0
	var names := 0
	for nm: String in consts:
		if nm.begins_with("FLAG_"):
			bits |= int(consts[nm])
			names += 1
	t.eq(names, 2, "상태 비트가 둘이다 (셋이 되면 아래 count 셈이 샌다)")
	var both: int = Mat.FLAG_SHALLOW | Mat.FLAG_BURNING
	t.eq(bits, both, "그 둘이 얕음과 불이다")

	var g := _make_forest(950)
	_wet_pocket(g, 150, 950)
	# Builds a state where a burning cell and shallow water **both really exist** — without it the 0 below is free.
	g.apply(CellGrid.cmd_fill(120, 949, 120, 949, Mat.EMPTY))
	g.set_water(120, 949, Tuning.WATER_WET)
	g.ignite(110, 950)
	var lit_seen := false
	var shallow_seen := false
	var bad := 0
	for _i in 200:
		g.step()
		if g.burning_count() > 0:
			lit_seen = true
		var flags := g.get_flag()
		if flags.count(Mat.FLAG_SHALLOW) > 0:
			shallow_seen = true
		bad += flags.count(both)
	t.ok(lit_seen, "그동안 불이 실제로 탔다 (검사의 전제)")
	t.ok(shallow_seen, "얕은 물도 실제로 있었다 (검사의 전제)")
	t.eq(bad, 0, "200틱 내내 얕음과 불을 동시에 든 칸이 한 칸도 없다")


## Scans the water in a rectangle in one pass => `[sum, water cell count, maximum amount]`.
## **It uses `aux_at`** — `_aux` can't be read directly, so it goes only through the grid's public door.
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



## Runs until the fire is fully out. The return is the number of ticks run.
## If it hit `cap` it did not go out — the caller must assert that.
func _burn_out(g: CellGrid, cap: int) -> int:
	var n := 0
	while g.burning_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


## **Shallow water cannot put out fire** (decided by the user).
##
## **Why this check came to exist**: on screen **one press of F (797 cells) spread left and right and permanently
##  fireproofed a forest of ~860 cells.** It was still growing after 200 seconds. It was the **product of three** —
##  the water not shrinking · the cells it touched not burning · it spreading on — and this check measures the **middle term**.
##
## **No single assertion can measure the threshold on its own — they are all measured in pairs.**
##  Measuring only "shallow water can't extinguish" is green even with `_water_adjacent` turned into **`return false` whole**,
##   and measuring only "deep water extinguishes" is green even with the threshold **deleted** (that was the old code).
##  => Only two runs **from one arrangement differing in the water amount alone** that **behave differently** put the threshold there.
## **The constant is used as is.** Baking in 32 makes the check spin idle silently the day the value changes.
func _shallow_water_does_not_put_out_fire(t) -> void:
	# -- (1) one penned cell, both sides of the threshold ----------------
	# **The sides are walled in stone** (the same reason as `_wet_pocket`) — unwalled, the water covers the whole
	#  wood row and thins out, so it measures (2)'s sheet below instead of "one shallow cell".
	#  It was actually written that way and the check duplicated (2).
	var wood_by_amount := {}
	for amount in [Tuning.WATER_WET, Tuning.WATER_WET + 1]:
		var g := _make_forest(400)
		g.apply(CellGrid.cmd_fill(149, 399, 149, 399, Mat.STONE))
		g.apply(CellGrid.cmd_fill(151, 399, 151, 399, Mat.STONE))
		t.ok(g.set_water(150, 399, amount), "가둔 자리에 물 %d 을 놓는다 (전제)" % amount)
		g.ignite(120, 400)
		var ticks := _burn_out(g, 600)
		t.ok(ticks < 600, "물 %d — 불이 결국 꺼진다 (%d틱)" % [amount, ticks])
		wood_by_amount[amount] = g.count_material(Mat.WOOD)

	# **Measured: 32 => 0 cells · 33 => 11 cells.** One grain of difference splits a whole forest.
	t.eq(wood_by_amount[Tuning.WATER_WET], 0,
		"**임계와 같은 얕은 물** 아래로 불이 지나가 숲이 한 칸도 안 남는다")
	t.ok(wood_by_amount[Tuning.WATER_WET + 1] > 0,
		"**한 톨만 더 깊으면** 거기서 멈춰 숲이 남는다 (%d칸)" % wood_by_amount[Tuning.WATER_WET + 1])

	# -- (2) the picture that was the real problem — **a spread sheet is not a firebreak** --
	#
	# **(1) measures "one cell". This measures "after it spread"** — this is the shape it took on screen.
	#  And **(1) can be green while only this is red**: whether the settled sheet's amount drops below the
	#   threshold is decided by **the flow**, not by the threshold alone.
	#
	# **Control B is half of this check.** Same position, same terrain, same ticks, **only the water amount differs** —
	#  A is the settled sheet as it lies (shallow), B raises those same cells to `WATER_MAX`.
	#  => Without B there is no way to show that "the forest burns in A" is **because of the threshold**.
	var result := {}
	var sheet_cells := 0
	for tag in ["A", "B"]:
		var g := _make_forest(600)
		t.ok(g.set_water(130, 599, Tuning.WATER_MAX), "%s — 나무 줄 위에 한 덩이를 붓는다 (전제)" % tag)
		var settle := _settle(g, 400)
		t.ok(settle > 1, "%s — 물이 실제로 여러 틱 흘렀다 (%d틱)" % [tag, settle])
		t.ok(settle < 400, "%s — 평형에 도달했다 (cap에 안 닿았다)" % tag)

		# Where the sheet came to rest. The positions are not guessed but **read** — B uses those same positions.
		var xs: Array[int] = []
		var peak := 0
		for x in range(100, 161):
			if g.mat_at(x, 599) == Mat.WATER:
				xs.append(x)
				peak = maxi(peak, g.aux_at(x, 599))
		t.ok(xs.size() > 1, "%s — 한 칸이 아니라 여러 칸으로 퍼졌다 (%d칸)" % [tag, xs.size()])
		sheet_cells = xs.size()

		if tag == "A":
			t.ok(peak <= Tuning.WATER_WET,
				"A — 퍼진 뒤 가장 깊은 칸도 임계 이하다 (%d ≤ %d)" % [peak, Tuning.WATER_WET])
		else:
			for x in xs:
				g.set_water(x, 599, Tuning.WATER_MAX)

		g.ignite(101, 600)
		var ticks := _burn_out(g, 600)
		t.ok(ticks < 600, "%s — 불이 결국 꺼진다 (%d틱)" % [tag, ticks])
		result[tag] = g.count_material(Mat.WOOD)

	# **Measured: sheet 17 cells · A leaves 1 cell · B leaves 56 cells.**
	#  A is not exactly 0 because of **timing** — if the fire passes a cell while the water is still deep,
	#   there is no neighbour left to light it again. So **0 is not demanded.**
	#  Instead it is **weighed against "the number of cells the sheet covers"**: under the old behaviour **all** the wood under the sheet survived.
	t.ok(result["A"] < sheet_cells,
		"A — 얇게 퍼진 시트가 **방화선이 안 된다** (시트 %d칸인데 %d칸만 남았다)"
			% [sheet_cells, result["A"]])
	t.ok(result["B"] > sheet_cells,
		"B — 같은 자리가 **깊으면 여전히 막는다** (%d칸이 살았다 — 대조군이 헛돌지 않는다)"
			% result["B"])
	t.ok(result["B"] > result["A"] * 4,
		"둘의 차이가 자릿수다 (A %d칸 · B %d칸)" % [result["A"], result["B"]])

