extends SceneTree
## The headless run-player. Plays whole runs with scripted policies and prints, per island:
## soldiers lost, HP pool in and out, fight duration, and the share of the island's seconds in
## which the hand actually had something to press.
##
## The first-slice plan's section "Phase A is not finished until the probe closes these numbers"
## is what this file answers. It is not a net: nothing here asserts, everything here reports.
## A number that comes out wrong is a design answer, not a red round.
##
## **The last probe this repo had graded itself in its owner's favour twice** — it modelled
## one-shot as `force >= hp` after a cap had made that false, and it never read the flee table.
## So the last thing this file does is feed itself a run that MUST be reported as a loss (one
## soldier, one HP). A probe that only ever runs the cases its author expects to pass measures
## its author.
##
## Run it with:
##   Godot.exe --headless --path <project> --script res://tools/probe/run_run.gd
## An `--import` pass has to have happened at least once, or every `class_name` in `src/sim` is
## invisible to `--script` and this dies with "Nonexistent function 'new'".


## 20 Hz. The step size is NOT free: `Battle._walk` crosses whole tiles inside one call, so a
## coarse step does not cap speed — but attack cooldowns are compared against `Rules.EPS` after
## a subtraction, so a step near a period would quantise DPS. 0.05 is 20 frames per the shortest
## period (1.0 s) and 30 per the longest (1.5 s).
const DT := 0.05

## Hang guard. Island 3's limit is 90 s = 1800 steps, so this can only fire if the clock stops
## advancing — and a probe that hangs prints nothing at all, which is the failure shape that
## disarmed a whole net in this repo once.
const MAX_STEPS := 4000

## What fraction of full health the army is chipped to before the boss, for the policy that asks
## whether arriving hurt can lose. The plan's own sweep is what named 60%.
const CHIPPED := 0.6


func _initialize() -> void:
	print("[프로브] 헤드리스 런 — dt %.2fs, 섬마다 한 줄" % DT)
	print("         잃은 병사 · HP 풀 들어감->나옴 · 전투 길이 · 입력 가능했던 초/섬이 돈 초")

	var all_rows := _policy_all()
	var dribble_rows := _policy_dribble()
	var ranged := _policy_ranged()
	var chipped := _policy_chipped_boss()
	_policy_two_doors()
	_inverted_must_lose()

	_verdicts(all_rows, dribble_rows, ranged, chipped)

	print("")
	print("[프로브] 끝.")
	quit(0)


## The plan's four required numbers, graded out loud. A probe whose output has to be eyeballed
## gets eyeballed in its author's favour — this repo's last one did, twice — so each row says what
## it wanted, what it got, and which of the two won. **Nothing here is fixed up to pass.**
func _verdicts(all_rows: Array, dribble_rows: Array, ranged: Dictionary, chipped: Array) -> void:
	print("")
	print("=== 계획서가 요구한 숫자, 그대로 채점 ===")

	var all_won := all_rows.size() == Islands.count()
	for row: Dictionary in all_rows:
		if not bool(row["won"]):
			all_won = false
	print("  1. 전부 한 번에 세 섬을 다 이긴다: %s" % _mark(all_won))

	# Per island, because "loses more HP" is a claim about every island and a total would let one
	# island's blowout pay for another island's free ride.
	var dribble_worse := dribble_rows.size() >= all_rows.size()
	for i in mini(all_rows.size(), dribble_rows.size()):
		var a := float((all_rows[i] as Dictionary)["damage"])
		var d := float((dribble_rows[i] as Dictionary)["damage"])
		var worse := d > a
		if not worse:
			dribble_worse = false
		print("     섬 %d — 전부 %.1f vs 한 척씩 %.1f: %s" % [i + 1, a, d, _mark(worse)])
	print("  2. 한 척씩이 모든 섬에서 HP 를 더 잃는다: %s" % _mark(dribble_worse))

	var solo: Array = ranged["a"]
	var after: Array = ranged["b"]
	var wiped_1 := solo.size() >= 1 and not bool((solo[0] as Dictionary)["won"])
	print("  3a. 원거리만이 섬 1 에서 진다: %s" % _mark(wiped_1))
	var cleared_2 := after.size() >= 2 and bool((after[1] as Dictionary)["won"])
	print("  3b. 원거리만이 섬 2 를 깬다: %s" % _mark(cleared_2))

	var boss_won := false
	if chipped.size() == Islands.count():
		boss_won = bool((chipped[chipped.size() - 1] as Dictionary)["won"])
	# The plan writes in its own words that this row fails today: the lion keeps range 0, so a
	# chipped army still clears the boss. A WIN here is the plan being right, not the probe passing.
	print("  4. 풀 60%%로 보스에 들어가면 진다: %s (계획서는 지금은 이긴다고 적어뒀다)" % _mark(not boss_won))


func _mark(ok: bool) -> String:
	return "충족" if ok else "미달"


# --- the five policies ---------------------------------------------------------------------------

## Everything at once: fill every boat to capacity, launch the moment a berth is free, one dock.
## The plan calls this the baseline the other four are measured against, and it is the row that
## has to win all three islands from full health or the enemies are too strong.
func _policy_all() -> Array:
	return _play_run("정책 1 — 전부 한 번에 (기준선)", [_all_cfg(), _all_cfg(), _all_cfg()], 0.0)


## One boat at a time, waiting out the whole round trip before the next launch. Has to lose more
## HP than policy 1 on every island; if it does not, dribbling is free and "when do I commit" is
## not a decision.
func _policy_dribble() -> Array:
	var c := _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], true, [0], [])
	return _play_run("정책 2 — 한 척씩, 기다리며", [c, c, c], 0.0)


## Ranged only. The plan asks for one exact pair — wiped on island 1, clears island 2 — and those
## are two different armies, so they are two different runs. A single sequential run cannot show
## both: an army wiped on island 1 never reaches island 2.
func _policy_ranged() -> Dictionary:
	var r := _cfg([Rules.CELL_RANGED], false, [0], [])
	var solo := _play_run("정책 3a — 원거리만, 처음부터 (섬 1 에서 전멸해야 한다)", [r, r, r], 0.0)
	var after := _play_run("정책 3b — 섬 1 은 전부, 섬 2 부터 원거리만 (섬 2 를 깨야 한다)",
			[_all_cfg(), r, r], 0.0)
	return {"a": solo, "b": after}


## Everything, but the army is cut to 60% of full health on the way into the boss. The plan
## predicts this WINS today and says so in writing — the lion keeps range 0 until the user
## decides, and this row fails on purpose rather than being quietly retired.
func _policy_chipped_boss() -> Array:
	var rows := _play_run("정책 4 — 전부, 보스에 풀의 %d%% 로 진입" % int(CHIPPED * 100.0),
			[_all_cfg(), _all_cfg(), _all_cfg()], CHIPPED)
	_boss_sweep()
	return rows


## One number is not a band. **This is the inversion of policy 4**: if 60% winning is a real
## answer rather than the probe agreeing with itself, then SOME entering pool has to lose — so the
## sweep walks it down to 5% and reports where the flip is, or that there is none. The plan's own
## sweep found no flip at all with the lion on range 0, which is why it left that row failing on
## purpose instead of retiring it. This is that claim re-measured against the real sim.
func _boss_sweep() -> void:
	print("")
	print("=== 보스 밴드 스윕 — 섬 1·2 는 동일, 섬 3 에 들어가는 풀만 바꾼다 ===")
	for frac: float in [1.0, 0.8, 0.6, 0.4, 0.2, 0.1, 0.05]:
		var rows := _play_run("", [_all_cfg(), _all_cfg(), _all_cfg()], frac, false)
		if rows.size() != Islands.count():
			print("  풀 %3d%% -> 보스에 도달하지 못했다" % int(frac * 100.0))
			continue
		var last: Dictionary = rows[rows.size() - 1]
		print("  풀 %3d%% (%6.1f) -> %s · %5.1fs · 사망 %d · 피해 %.1f" % [
			int(frac * 100.0), float(last["pool_in"]),
			"승" if bool(last["won"]) else "패", float(last["dur"]),
			int(last["lost"]), float(last["damage"])])


## Island 3's two doorways. Both runs play islands 1 and 2 identically — the policies are
## deterministic, so both armies reach the boss in the same state — and differ only on the last
## island. Cloning the army instead would need a second copy of what `Army` holds, and a copy
## that drifts from the real roster measures the copy.
func _policy_two_doors() -> void:
	# Two soldiers to the west dock first, everyone else to the east dock: one door baited, the
	# rest of the force through the other.
	var bait := _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], false, [0, 1, 1, 1], [2, 5, 5, 5])
	var one_door := _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], false, [0], [])
	var split := _play_run("정책 5a — 섬 3, 서쪽 문으로 2명 유인 · 나머지는 동쪽 문",
			[_all_cfg(), _all_cfg(), bait], 0.0)
	var single := _play_run("정책 5b — 섬 3, 한 문(서쪽)에 전부",
			[_all_cfg(), _all_cfg(), one_door], 0.0)
	print("")
	print("=== 정책 5 비교 — 섬 3 만 ===")
	_compare_last(" 5a 유인/분산", split)
	_compare_last(" 5b 한 문 전부", single)


func _compare_last(label: String, rows: Array) -> void:
	if rows.is_empty():
		print("  %s: 섬 3 에 도달하지 못했다" % label)
		return
	var last: Dictionary = rows[rows.size() - 1]
	if int(last["island"]) != 2:
		print("  %s: 섬 3 에 도달하지 못했다 (마지막 섬 %d)" % [label, int(last["island"]) + 1])
		return
	print("  %s: 총 피해 %.1f · 사망 %d · %s · %.1fs" % [
		label, float(last["damage"]), int(last["lost"]),
		"승" if bool(last["won"]) else "패", float(last["dur"])])


# --- the inversion -------------------------------------------------------------------------------

## Fed a run that cannot be won: one soldier, one HP, four bison. If this reports anything but a
## loss the probe is grading in its own favour and every number above it is worth nothing.
func _inverted_must_lose() -> void:
	print("")
	print("=== 뒤집기 — 반드시 져야 하는 런 (병사 1명, 1 HP) ===")
	var run := Run.new()
	for i in range(1, run.army.alive.size()):
		run.army.kill(i)
	var h := run.army.hp
	h[0] = 1.0
	run.army.hp = h
	print("  살아 있는 병사 %d명, 풀 %.1f" % [run.army.living_count(), _pool(run.army)])

	var battle := run.begin_island()
	var res := _play_island(battle, _all_cfg())
	var verdict := _outcome_name(battle)
	print("  섬 1 결과: %s · 남은 적 %d · %.1fs · %d 스텝" % [
		verdict, battle.enemies_left(), battle.elapsed, int(res["steps"])])
	if battle.outcome() == Battle.Outcome.LOST:
		print("  [OK] 져야 할 런이 실제로 졌다 — 위 숫자들을 믿어도 된다")
	else:
		print("  [!!] 져야 할 런이 지지 않았다 — 이 프로브의 모든 숫자를 믿지 마라")


# --- the driver ----------------------------------------------------------------------------------

## Plays one whole run and prints a line per island. Returns the per-island rows so a caller can
## compare two runs without re-reading the console.
func _play_run(label: String, cfgs: Array, chip: float, verbose := true) -> Array:
	if verbose:
		print("")
		print("=== %s ===" % label)
	var run := Run.new()
	var rows: Array = []
	# Three islands, plus one reward stop, plus slack. A `while true` here would turn a stuck
	# state machine into a silent hang, and a hang prints nothing at all.
	var guard := 0
	while guard < 12:
		guard += 1
		var st := run.state()
		if st == Run.State.BATTLE:
			var idx := run.island_index
			if idx == Islands.count() - 1 and chip > 0.0:
				_chip_to(run.army, chip)
				if verbose:
					print("  보스 직전에 풀을 %d%% 로 맞췄다 -> %.1f" % [int(chip * 100.0), _pool(run.army)])
			var battle := run.begin_island()
			if battle == null:
				print("  [!!] begin_island 가 null 을 돌려줬다 (상태 %d)" % st)
				break
			var pool_in := _pool(run.army)
			var alive_in := run.army.living_count()
			var cfg: Dictionary = cfgs[idx] if idx < cfgs.size() else cfgs[cfgs.size() - 1]
			var res := _play_island(battle, cfg)
			var pool_out := _pool(run.army)
			var won := battle.outcome() == Battle.Outcome.WON
			var row := {
				"island": idx,
				"won": won,
				"lost": alive_in - run.army.living_count(),
				"pool_in": pool_in,
				"pool_out": pool_out,
				"damage": pool_in - pool_out,
				"dur": battle.elapsed,
				"open_s": float(res["open_s"]),
				"cmds": int(res["cmds"]),
				"launches": int(res["launches"]),
			}
			rows.append(row)
			if verbose:
				_print_row(battle, row, res)
			if int(res["steps"]) >= MAX_STEPS:
				print("  [!!] 스텝 상한에 걸렸다 — 시계가 안 도는 것이다")
				break
			run.finish_island(won)
			if not won:
				break
		elif st == Run.State.REWARD:
			var pick := _beak_pick(run.army)
			if pick < 0:
				print("  [!!] 부리를 달 살아 있는 병사가 없다 — 런이 멈춘다")
				break
			run.apply_beak(pick)
			if verbose:
				print("  부리 -> 병사 #%d (%s, HP %.1f)" % [
					pick, Rules.name_of(int(run.army.type_id[pick])), run.army.hp[pick]])
		else:
			break
	if verbose:
		print("  런: %s · 살아남은 병사 %d · 남은 풀 %.1f" % [
			_state_name(run.state()), run.army.living_count(), _pool(run.army)])
	return rows


func _print_row(battle: Battle, row: Dictionary, res: Dictionary) -> void:
	var dur := float(row["dur"])
	var open_s := float(row["open_s"])
	var share := 0.0 if dur <= 0.0 else open_s / dur * 100.0
	print("  섬 %d %s | 잃은 병사 %2d | 풀 %6.1f -> %6.1f (피해 %5.1f) | %5.1fs | 입력 가능 %5.2fs/%5.1fs = %4.1f%% (빈 시간 %4.1f%%) | 명령 %2d회 · 출항 %d | 남은 적 %d" % [
		int(row["island"]) + 1,
		"승" if bool(row["won"]) else _lose_name(battle),
		int(row["lost"]),
		float(row["pool_in"]), float(row["pool_out"]), float(row["damage"]),
		dur, open_s, dur, share, 100.0 - share,
		int(res["cmds"]), int(res["launches"]), battle.enemies_left()])
	print("       최장 정지 %.1fs · 상륙 병사가 막혀 서 있던 시간 %.1f%% (표적이 사거리 밖인데 못 움직임)" % [
		float(res["max_stall"]), float(res["stall_share"])])
	if not bool(row["won"]):
		_print_survivors(battle)


## What was still standing when an island was lost. Without this a timeout reads identically
## whether the army was grinding the boss down and ran out of clock or whether every unit was
## frozen doing nothing at all — and "the enemies froze" is exactly the defect this phase exists
## to catch, so it must not be something a reader has to infer.
func _print_survivors(battle: Battle) -> void:
	var parts: Array = []
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] != 0:
			parts.append("%s %.1f/%.1f @%s" % [
				Rules.name_of(int(battle.enemy_type[e])), battle.enemy_hp[e],
				Rules.hp_of(int(battle.enemy_type[e])), str(battle.enemy_pos[e])])
	print("       살아남은 적: %s" % (", ".join(PackedStringArray(parts)) if parts.size() > 0 else "없음"))
	var standing: Array = []
	for i in battle.ashore_ids():
		standing.append("#%d %s %.1f @%s" % [
			int(i), Rules.name_of(int(battle.army.type_id[int(i)])), battle.army.hp[int(i)],
			str(battle.soldier_pos[int(i)])])
	print("       상륙한 병사: %s" % (", ".join(PackedStringArray(standing)) if standing.size() > 0 else "없음"))


## One island, played to a verdict. The policy acts BEFORE `step`, so a command issued this frame
## is felt this frame — the shell will do the same, since input arrives before `_physics_process`.
func _play_island(battle: Battle, cfg: Dictionary) -> Dictionary:
	var types: Array = cfg["types"]
	var docks: Array = cfg["docks"]
	var sizes: Array = cfg["sizes"]
	var dribble: bool = cfg["dribble"]

	var launches := 0
	var open_s := 0.0
	var cmds := 0
	var steps := 0
	var next_type := 0

	# The freeze detector. See `_stalls`.
	var prev_s: Array = battle.soldier_pos.duplicate()
	var prev_e: Array = battle.enemy_pos.duplicate()
	var stall_s := PackedFloat32Array()
	stall_s.resize(battle.soldier_state.size())
	var stall_e := PackedFloat32Array()
	stall_e.resize(battle.enemy_alive.size())
	var max_stall := 0.0
	var acc := {"ashore_s": 0.0, "stalled_s": 0.0}

	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		# Measured BEFORE the policy acts, and measured against what the GAME allows rather than
		# what this policy chooses to do. A dead-air number that folded in the policy's own waiting
		# would report the dribbler as the busiest hand on the island, which is backwards.
		if _input_open(battle):
			open_s += DT
		if not (dribble and _fleet_busy(battle)):
			var want: int = int(sizes[launches]) if launches < sizes.size() else Rules.CAP
			want = mini(want, Rules.CAP)
			while battle.pending.size() < want:
				var loaded := false
				for k in types.size():
					var slot := (next_type + k) % types.size()
					if battle.load_soldier(int(types[slot])):
						next_type = (slot + 1) % types.size()
						loaded = true
						cmds += 1
						break
				if not loaded:
					break
			if battle.pending.size() > 0:
				var d := int(docks[launches]) if launches < docks.size() else int(docks[docks.size() - 1])
				if battle.launch(d):
					launches += 1
					cmds += 1
		# Every driver of `Battle` clears last frame's facts before the next step — the shell, the nets
		# and this probe. `events` has no cap on purpose, so a driver that forgets grows it for the
		# whole island: 1800 steps of island 3 pile up thousands of ATTACKs and the only symptom is
		# memory. Nothing here reads the list; it is called because forgetting it is the failure, and a
		# probe that quietly does not is a driver that disagrees with the shell.
		battle.begin_frame()
		battle.step(DT)
		steps += 1
		max_stall = maxf(max_stall, _stalls(battle, prev_s, stall_s, prev_e, stall_e, acc))

	var ashore_s := float(acc["ashore_s"])
	var stall_share := 0.0 if ashore_s <= 0.0 else float(acc["stalled_s"]) / ashore_s * 100.0
	return {"steps": steps, "open_s": open_s, "launches": launches, "cmds": cmds,
			"max_stall": max_stall, "stall_share": stall_share}


## Accumulates two numbers about units that are **motionless while their target is out of their
## reach** — so a unit standing because it is already in range, or because nothing is detected, is
## never counted.
##
## This is the instrument for "the enemies froze", which is the failure that cost the last game's
## movement rule two rounds and which no final-state check can see: a run where every unit stood
## still all island and a run where they fought both end with a verdict and a duration.
##
## ⚠ **The first version of this also reported "stall still unresolved when the island ended", and
## that number was structurally 0 on every win** — the win happens because the last enemy dies, and
## a dead target clears `chasing` for everyone on the same frame, so the reset always ran before
## the read. It printed 0.0s on twenty islands and read as proof of no deadlock while measuring
## nothing at all. **The instrument was inverted, not the sim.** What replaced it is the share of
## ashore soldier-seconds spent stalled, which no ending can zero.
##
## A queue at a doorway legitimately parks a unit for many seconds, so this reports NUMBERS and
## judges nothing: on these three islands the open field runs a few percent and the ring runs high.
func _stalls(battle: Battle, prev_s: Array, stall_s: PackedFloat32Array,
		prev_e: Array, stall_e: PackedFloat32Array, acc: Dictionary) -> float:
	var worst := 0.0
	for i in battle.soldier_state.size():
		var here: Vector2 = battle.soldier_pos[i]
		var chasing := false
		if battle.soldier_state[i] == Battle.SoldierState.ASHORE:
			acc["ashore_s"] = float(acc["ashore_s"]) + DT
			var t := int(battle.soldier_target[i])
			if t >= 0 and battle.enemy_alive[t] != 0:
				chasing = here.distance_to(battle.enemy_pos[t]) \
						> battle.army.range_of(i) + Rules.REACH_BONUS + Rules.EPS
		if chasing and here.distance_to(prev_s[i]) <= Rules.EPS:
			stall_s[i] += DT
			acc["stalled_s"] = float(acc["stalled_s"]) + DT
			worst = maxf(worst, stall_s[i])
		else:
			stall_s[i] = 0.0
		prev_s[i] = here
	for e in battle.enemy_alive.size():
		var here: Vector2 = battle.enemy_pos[e]
		var chasing := false
		if battle.enemy_alive[e] != 0:
			var t := int(battle.enemy_target[e])
			if t >= 0 and battle.is_hittable(t):
				chasing = here.distance_to(battle.soldier_pos[t]) \
						> Rules.range_of(int(battle.enemy_type[e])) + Rules.REACH_BONUS + Rules.EPS
		if chasing and here.distance_to(prev_e[e]) <= Rules.EPS:
			stall_e[e] += DT
			worst = maxf(worst, stall_e[e])
		else:
			stall_e[e] = 0.0
		prev_e[e] = here
	return worst


## Could the hand press anything at all this frame? A launch when something is loaded and a berth
## is free, or a load when the boat has room and a soldier is still in reserve. Nothing here reads
## the policy, so the number is comparable between two policies on the same island.
func _input_open(battle: Battle) -> bool:
	if battle.pending.size() > 0:
		for b in battle.berth_free_in.size():
			if battle.berth_free_in[b] <= Rules.EPS:
				return true
	if battle.pending.size() >= Rules.CAP:
		return false
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			return true
	return false


## True while any boat is at sea or any berth is still counting down. Both halves are needed: a
## boat is dropped from `boats` on unload, but its berth stays busy for the return leg.
func _fleet_busy(battle: Battle) -> bool:
	if not battle.boats.is_empty():
		return true
	for b in battle.berth_free_in.size():
		if battle.berth_free_in[b] > Rules.EPS:
			return true
	return false


# --- policy configs ------------------------------------------------------------------------------

func _cfg(types: Array, dribble: bool, docks: Array, sizes: Array) -> Dictionary:
	return {"types": types, "dribble": dribble, "docks": docks, "sizes": sizes}


func _all_cfg() -> Dictionary:
	return _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], false, [0], [])


# --- army helpers --------------------------------------------------------------------------------

func _pool(army: Army) -> float:
	var total := 0.0
	for i in army.hp.size():
		if army.alive[i] != 0:
			total += army.hp[i]
	return total


## Scales every living soldier to `frac` of its own maximum, so the pool lands on `frac` of the
## living maximum without a second copy of anyone's max HP living here.
##
## The write is read-modify-write through a local: `PackedFloat32Array` is copy-on-write, and
## indexing straight through the property would land in a temporary and change nothing at all.
func _chip_to(army: Army, frac: float) -> void:
	var h := army.hp
	for i in h.size():
		if army.alive[i] != 0:
			h[i] = maxf(1.0, Rules.hp_of(int(army.type_id[i])) * frac)
	army.hp = h


## The beak goes on the healthiest living melee, falling back to ranged. `living_ids_of_type` is
## already sorted highest-HP first and breaks ties on the smaller id, so two runs from identical
## state bolt it onto the same soldier.
func _beak_pick(army: Army) -> int:
	var ids := army.living_ids_of_type(Rules.CELL_MELEE)
	if ids.is_empty():
		ids = army.living_ids_of_type(Rules.CELL_RANGED)
	return -1 if ids.is_empty() else int(ids[0])


# --- names ---------------------------------------------------------------------------------------

func _outcome_name(battle: Battle) -> String:
	match battle.outcome():
		Battle.Outcome.WON:
			return "승"
		Battle.Outcome.LOST:
			return _lose_name(battle)
		_:
			return "안 끝남"
	return "?"


func _lose_name(battle: Battle) -> String:
	match battle.lose_reason():
		Battle.Lose.TIMEOUT:
			return "패(시간)"
		Battle.Lose.WIPED:
			return "패(전멸)"
		_:
			return "패"
	return "패"


func _state_name(st: int) -> String:
	match st:
		Run.State.BATTLE:
			return "진행 중"
		Run.State.REWARD:
			return "보상 대기"
		Run.State.WON:
			return "클리어"
		Run.State.LOST:
			return "실패"
		_:
			return "?"
	return "?"
