extends SceneTree
## Per-kind monster frame cost, measured — **the tool `monster_defs.gd`'s own profile table asks for.**
##
## That table carries a standing instruction ("whoever implements is the first person to measure monster cost.
## Leave the measurement in a comment there") and until now the measuring was done by hand, once, by
## verify-run. **A box moved (the hen, 24x28 -> 48x64) and the table had no way to be re-taken**, which is how
## a measured number quietly becomes a stale one.
##
## **The method is verify-run's, kept identical so the numbers are comparable to the ones already recorded**:
##  600 warm-up frames, 3 runs, one `world.frame()` per frame, an empty world measured the same way and
##  subtracted. The 60Hz budget is 16,667us.
##
## **It is not a net.** It measures time, and time is machine- and load-dependent — a threshold on it would go
##  red on a busy laptop and green on an idle one. Run it by hand and write what it says into the table:
##
##     Godot_v4.7.1-stable_win64.exe --headless --script res://tools/stage/profile_monsters.gd

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Character := preload("res://src/actor/character.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Defs := preload("res://src/actor/monster_defs.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const FLOOR_W_CX := 900
const WARM_FRAMES := 600
const RUNS := 3
const BUDGET_US := 16667.0


func _initialize() -> void:
	var empty := _measure(Defs.KIND_NONE, 0, false)
	print("[profile] 빈 세계 %.0fus (기준선)" % empty)
	print("[profile] 종류 | 상자 셀 | 1마리 추가 비용 | 60Hz 예산 비중 | 20마리 실측 · 자는 20마리 실측")
	for kind: int in Defs.ALL:
		var cells := (Defs.w_px(kind) / Tuning.CELL_PX) * (Defs.h_px(kind) / Tuning.CELL_PX)
		var one := _measure(kind, 1, false) - empty
		# **20 is `MAX_MONSTERS`, and the projection is linear on purpose — it is a projection.** The one
		#  number that has never been measured is 20 at once (`monsters-bigger-boxes.md` §4 note 1), and
		#  multiplying one monster by 20 is not that measurement. It is labelled as an estimate here.
		var twenty := _measure(kind, Defs.MAX_MONSTERS, false) - empty
		# `monster-placement-stage1.md` Stage D — the sleeping row team-lead asked for.
		#  Same 20-at-once scene, every monster asleep instead of awake (`_one_run`'s own `sleeping` flag).
		var twenty_asleep := _measure(kind, Defs.MAX_MONSTERS, true) - empty
		print(("[profile] %s | %d | +%.0fus (%.1f%%) | 20마리 실측 +%.0fus (%.1f%% · " +
			"1마리x20 추정은 %.0fus) · 자는 20마리 +%.0fus (%.1f%%)") % [
			Defs.name_of(kind), cells, one, one / BUDGET_US * 100.0,
			twenty, twenty / BUDGET_US * 100.0, one * Defs.MAX_MONSTERS,
			twenty_asleep, twenty_asleep / BUDGET_US * 100.0])
	quit()


## The median of `RUNS` runs, in microseconds per frame. **Median, not mean** — one scheduler hiccup in 600
##  frames moves a mean and does not move a median.
func _measure(kind: int, count: int, sleeping: bool) -> float:
	var samples: Array[float] = []
	for _r in RUNS:
		samples.append(_one_run(kind, count, sleeping))
	samples.sort()
	return samples[samples.size() / 2]


## `sleeping` — `monster-placement-stage1.md` Stage D. **Not a free parameter add** —
## Stage D made every monster's `step()` distance-gated (`WorldStep`'s own `stays_active`/`WAKE_PX`/
## `SLEEP_PX`), and this tool's old placement (character 3200px to the right, monsters spread from x200)
## silently stopped measuring "walking" at all the moment that landed: every monster spawned already
## past `SLEEP_PX` and, being asleep, never walks close enough to wake — **measured, not assumed**: the
## old placement's own numbers dropped from the recorded +192us/+3416us (pig, 1/20) to +39us/+679us, a
## ~5x drop consistent with skipping both `grounded()` sweeps almost the entire run. Left unfixed, this
## table would silently start reporting sleeping-monster cost under an "awake" label.
func _one_run(kind: int, count: int, sleeping: bool) -> float:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + 8, Mat.STONE))
	var ch := Character.new()
	# **Clustered, not spread** (team-lead's own finding) — the old `200 + i*(w_px+8)` gap kept every pair
	#  from ever overlapping, which made a *second* number read as a false 0: separation
	#  (`monster_separation.gd`) only ever calls the real `box_free` inside `Monster.try_shift_x` when a
	#  pair actually overlaps past `OVERLAP_THRESHOLD_PX`, and a permanently non-overlapping spread never
	#  triggers it once. 4px apart is well inside every kind's own width, so separation has real work to
	#  do the first several frames (settling into its own natural ~`w_px`-apart resting spacing well
	#  before the timed window starts, `WARM_FRAMES`=600 into it) — the same shape a real crowd converging
	#  on the player produces, not the artificially conflict-free row the old spread measured.
	var cluster_x0 := 400
	if sleeping:
		# **Far enough that every monster is asleep from the very first tick it runs** (`WorldStep`'s own
		#  `stays_active`, `SLEEP_PX`=840) — and, being asleep, it never walks a single pixel closer, so
		#  the distance this placement fixes at frame 0 is also the distance for every frame after.
		ch.place(cluster_x0 + 4000, FLOOR_TOP - Character.H_PX)
	else:
		# **Close enough that every monster stays awake for the whole run.** `MAX_MONSTERS`(20) settled
		#  `w_px`-apart spans at most `20 * 88` (the bull, the widest kind) = 1760px; centring the character
		#  on the cluster's own estimated settled width keeps the worst single monster's distance well
		#  under `WAKE_PX`=720 for every kind actually placed 20-at-once by any real room in this game
		#  (pig/hen/wolf — `stage1_monsters.gd`), and close enough for the hypothetical bull/rooster rows
		#  that this tool measures anyway that any one outlier briefly crossing the band does not move the
		#  median of 600 timed frames.
		# `count == 0` is the empty-world baseline (`kind == Defs.KIND_NONE`, not in `Defs.DEFS` at all —
		#  `Defs.w_px()` must not be called for it). Character position does not matter with no monsters.
		var settled_half := count * Defs.w_px(kind) / 2 if count > 0 else 0
		ch.place(cluster_x0 + settled_half, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	if count > 0:
		for i in count:
			world.spawn_monster(kind, cluster_x0 + i * 4, FLOOR_TOP - Defs.h_px(kind))
	# Warm up: the first frames pay for chunk waking, script JIT-ish costs, and (now) separation settling
	#  the cluster into its resting spacing — none of which recur once the timed window starts.
	for _i in WARM_FRAMES:
		world.frame(DT, 0.0, false, false)
	var t0 := Time.get_ticks_usec()
	for _i in WARM_FRAMES:
		world.frame(DT, 0.0, false, false)
	return float(Time.get_ticks_usec() - t0) / float(WARM_FRAMES)
