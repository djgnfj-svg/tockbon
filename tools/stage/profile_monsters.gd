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
	var empty := _measure(Defs.KIND_NONE, 0)
	print("[profile] 빈 세계 %.0fus (기준선)" % empty)
	print("[profile] 종류 | 상자 셀 | 1마리 추가 비용 | 60Hz 예산 비중 | 20마리 추정")
	for kind: int in Defs.ALL:
		var cells := (Defs.w_px(kind) / Tuning.CELL_PX) * (Defs.h_px(kind) / Tuning.CELL_PX)
		var one := _measure(kind, 1) - empty
		# **20 is `MAX_MONSTERS`, and the projection is linear on purpose — it is a projection.** The one
		#  number that has never been measured is 20 at once (`monsters-bigger-boxes.md` §4 note 1), and
		#  multiplying one monster by 20 is not that measurement. It is labelled as an estimate here.
		var twenty := _measure(kind, Defs.MAX_MONSTERS) - empty
		print("[profile] %s | %d | +%.0fus (%.1f%%) | 20마리 실측 +%.0fus (%.1f%% · 1마리x20 추정은 %.0fus)" % [
			Defs.name_of(kind), cells, one, one / BUDGET_US * 100.0,
			twenty, twenty / BUDGET_US * 100.0, one * Defs.MAX_MONSTERS])
	quit()


## The median of `RUNS` runs, in microseconds per frame. **Median, not mean** — one scheduler hiccup in 600
##  frames moves a mean and does not move a median.
func _measure(kind: int, count: int) -> float:
	var samples: Array[float] = []
	for _r in RUNS:
		samples.append(_one_run(kind, count))
	samples.sort()
	return samples[samples.size() / 2]


func _one_run(kind: int, count: int) -> float:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + 8, Mat.STONE))
	var ch := Character.new()
	# **The player stands far to the right so every monster walks the whole time.** Standing still would
	#  measure a monster that has stopped, which is the cheap case and not the one the budget is about.
	ch.place(FLOOR_W_CX * Tuning.CELL_PX - 200, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)
	if count > 0:
		# Spread out, so they are not all resolving collisions against each other in one column.
		for i in count:
			world.spawn_monster(kind, 200 + i * (Defs.w_px(kind) + 8), FLOOR_TOP - Defs.h_px(kind))
	# Warm up: the first frames pay for chunk waking and script JIT-ish costs that never recur.
	for _i in WARM_FRAMES:
		world.frame(DT, 0.0, false, false)
	var t0 := Time.get_ticks_usec()
	for _i in WARM_FRAMES:
		world.frame(DT, 0.0, false, false)
	return float(Time.get_ticks_usec() - t0) / float(WARM_FRAMES)
