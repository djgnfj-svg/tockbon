extends SceneTree
## The headless run-player. Plays whole runs with scripted policies and prints, per island:
## soldiers lost, HP pool in and out, fight duration, and the share of the island's seconds in
## which the hand actually had something to press.
##
## `boat-and-landing`, section 11, is what this file answers now — the open coastline replaced the
## fixed dock, so "which dock" stopped being a question and "where on the coast" started being one.
## It is not a net: nothing here asserts, everything here reports. A number that comes out wrong is
## a design answer, not a red round. **This round's job is to REPORT, not to tune** — `TIME_LIMITS`
## and every other rule constant are read as they stand; a probe that adjusts a constant to make its
## own run look better is grading itself.
##
## **The last probe this repo had graded itself in its owner's favour twice** — it modelled
## one-shot as `force >= hp` after a cap had made that false, and it never read the flee table. So
## the last thing this file does is feed itself a run that MUST be reported as a loss (one soldier,
## one HP), and the landing-point pair below carries its OWN inversion too: two runs landing by the
## SAME strategy must produce identical numbers, or the near/far and near/quiet comparisons above it
## are noise rather than a measurement of the landing point.
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


func _initialize() -> void:
	print("[프로브] 헤드리스 런 — dt %.2fs, 섬마다 한 줄" % DT)
	print("         잃은 병사 · HP 풀 들어감->나옴 · 전투 길이 · 입력 가능했던 초/섬이 돈 초")

	var all_rows := _policy_all()
	var dribble_rows := _policy_dribble()
	var near_rows := _policy_landing("near")
	var far_rows := _policy_landing("far")
	var quiet_rows := _policy_landing("quiet")
	_same_beach_is_a_control(near_rows)
	_inverted_must_lose()

	_verdicts(all_rows, dribble_rows, near_rows, far_rows, quiet_rows)

	print("")
	print("[프로브] 끝.")
	quit(0)


## The plan's required numbers (section 11), graded out loud. A probe whose output has to be
## eyeballed gets eyeballed in its author's favour — this repo's last one did, twice — so each row
## says what it wanted, what it got, and which of the two won. **Nothing here is fixed up to pass.**
func _verdicts(all_rows: Array, dribble_rows: Array, near_rows: Array, far_rows: Array,
		quiet_rows: Array) -> void:
	print("")
	print("=== 계획서(boat-and-landing, 11절)가 요구한 숫자, 그대로 채점 ===")

	var all_won := all_rows.size() == Islands.count()
	for row: Dictionary in all_rows:
		if not bool(row["won"]):
			all_won = false
	print("  1. 전부 한 번에 세 섬을 다 이긴다 (제한 시간 안에): %s" % _mark(all_won))

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

	print("  3. 같은 섬, 두 해안(가까운 곳 vs 먼 곳) — 사상자와 시간이 달라야 한다")
	var landing_matters := near_rows.size() >= 1 and near_rows.size() == far_rows.size()
	for i in mini(near_rows.size(), far_rows.size()):
		var n := near_rows[i] as Dictionary
		var f := far_rows[i] as Dictionary
		var differ := absf(float(n["damage"]) - float(f["damage"])) > 0.01 \
				or absf(float(n["dur"]) - float(f["dur"])) > 0.01
		if not differ:
			landing_matters = false
		print("     섬 %d — 가까운 곳 피해 %.1f / %.1fs · 먼 곳 피해 %.1f / %.1fs: %s" % [
			i + 1, float(n["damage"]), float(n["dur"]), float(f["damage"]), float(f["dur"]),
			_mark(differ)])
	print("  3 결과: %s — 다르면 착륙 지점이 진짜 결정이고, 같으면 그림만 산 것이다"
			% _mark(landing_matters))

	# 4.6's own question. "가까운 곳" reruns the SAME nearest-tile choice every launch, which is
	# what a relocated fleet settles into — the plan's own "steady-state cheap" beach — so it does
	# not need a separate policy from row 3's.
	print("  4. 항구 옆(정착 후 최저가) vs 적이 없는 곳 — 4.6 의 질문")
	var near_dominant := 0
	var quiet_dominant := 0
	var split := 0
	var pairs := mini(near_rows.size(), quiet_rows.size())
	for i in pairs:
		var n := near_rows[i] as Dictionary
		var q := quiet_rows[i] as Dictionary
		var near_wins_dmg := float(n["damage"]) <= float(q["damage"])
		var near_wins_dur := float(n["dur"]) <= float(q["dur"])
		if near_wins_dmg and near_wins_dur:
			near_dominant += 1
		elif not near_wins_dmg and not near_wins_dur:
			quiet_dominant += 1
		else:
			split += 1
		print("     섬 %d — 항구 옆 피해 %.1f / %.1fs · 적 없는 곳 피해 %.1f / %.1fs" % [
			i + 1, float(n["damage"]), float(n["dur"]), float(q["damage"]), float(q["dur"])])
	if pairs > 0 and near_dominant == pairs:
		print("  4 결과: 항구 옆이 사상자·시간 둘 다 이긴다 — 「항상 항구 옆」이 지배적이다 (재개봉 조건 발동, GDD 참고)")
	elif pairs > 0 and quiet_dominant == pairs:
		print("  4 결과: 적이 없는 곳이 둘 다 이긴다 — 거리보다 교전 회피가 더 크다")
	else:
		print("  4 결과: 섬마다 갈린다 — %d/%d 항구 옆 완승, %d/%d 적 없는 곳 완승, %d 갈림 (어느 쪽도 일방적이지 않다)"
				% [near_dominant, pairs, quiet_dominant, pairs, split])

	print("")
	print("  5. 빈 시간(_input_open) — 배가 나가 있으면 다시 못 태운다(4.4), 그래서 누를 손이 줄어야 한다.")
	print("     이건 판정이 아니라 지켜볼 숫자다 — 각 섬 줄의 '입력 가능 …%' 항목을 보라.")


func _mark(ok: bool) -> String:
	return "충족" if ok else "미달"


# --- the policies ----------------------------------------------------------------------------------

## Everything at once: fill every boat to its own capacity, launch the moment it is loaded and not
## at sea, landing at the nearest reachable coast. The baseline the other policies are measured
## against — has to win all three islands from full health or the enemies are too strong.
func _policy_all() -> Array:
	return _play_run("정책 1 — 전부 한 번에 (기준선)", [_all_cfg(), _all_cfg(), _all_cfg()], true)


## One boat at a time, waiting out the WHOLE round trip (`boat_busy`, both legs) before the next
## launch. Has to lose more HP than policy 1 on every island; if it does not, dribbling is free and
## "when do I commit" is not a decision.
func _policy_dribble() -> Array:
	var c := _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], true, "near")
	return _play_run("정책 2 — 한 척씩, 왕복 끝까지 기다리며", [c, c, c], true)


## One landing strategy, played on all three islands. `kind` is "near" (= the nearest reachable
## tile from wherever the boat is CURRENTLY sitting — the steady-state cheap beach once the fleet
## has relocated at least once), "far" (the farthest reachable tile), or "quiet" (the reachable
## tile farthest from every living enemy at launch time).
func _policy_landing(kind: String, verbose := true) -> Array:
	var c := _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], false, kind)
	var label: String = {"near": "가까운 해안", "far": "먼 해안", "quiet": "적이 없는 해안"}[kind]
	return _play_run("정책 — 착륙 지점: %s" % label, [c, c, c], verbose)


## ⚠ The inversion for the landing-point pair itself: **two runs choosing the SAME strategy must
## produce IDENTICAL numbers**, since the sim is deterministic and every landing-tile picker here is
## a pure function of grid + enemy state. If they do not match, the near/far and near/quiet rows in
## `_verdicts` are measuring run-to-run noise, not the landing point — the same shape as the design
## doc's own "two runs at the same beach" requirement (11절).
func _same_beach_is_a_control(near_rows: Array) -> void:
	var repeat := _policy_landing("near", false)
	print("")
	print("=== 통제 — 같은 착륙 전략을 두 번 돌리면 숫자가 완전히 같아야 한다 ===")
	var same := near_rows.size() > 0 and near_rows.size() == repeat.size()
	for i in mini(near_rows.size(), repeat.size()):
		var a := near_rows[i] as Dictionary
		var b := repeat[i] as Dictionary
		var match_ok := absf(float(a["damage"]) - float(b["damage"])) < 0.01 \
				and absf(float(a["dur"]) - float(b["dur"])) < 0.01
		if not match_ok:
			same = false
		print("  섬 %d — 1회차 %.2f / %.2fs · 2회차 %.2f / %.2fs: %s" % [
			i + 1, float(a["damage"]), float(a["dur"]), float(b["damage"]), float(b["dur"]),
			_mark(match_ok)])
	print("  통제 결과: %s — 실패하면 위 3·4번 비교는 착륙 지점이 아니라 잡음을 재는 것이다" % _mark(same))


# --- the driver ----------------------------------------------------------------------------------

## Plays one whole run and prints a line per island. Returns the per-island rows so a caller can
## compare two runs without re-reading the console.
func _play_run(label: String, cfgs: Array, verbose := true) -> Array:
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
	var dribble: bool = cfg["dribble"]
	var landing: String = cfg["landing"]

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
			# Load whichever boat `load_soldier` picks (lowest-index boat with room), round-robin
			# the roster types, until a full pass over the types loads nobody — either every boat
			# is full/at sea, or the reserve is empty.
			var loaded_any := true
			while loaded_any:
				loaded_any = false
				for k in types.size():
					var slot := (next_type + k) % types.size()
					var boat := battle.load_soldier(int(types[slot]))
					# `load_soldier` returns the BOARDED BOAT'S INDEX, or -1 — never a bool.
					# `if 0:` is falsy in GDScript, so reading this as a bool would report boat 0
					# boarding successfully as a failure. This is one of the two silent breakages
					# `boat-and-landing` 11절 names by name; the other is `pending.size()` below.
					if boat >= 0:
						next_type = (slot + 1) % types.size()
						cmds += 1
						loaded_any = true
						break
			# Launch every boat that is loaded and not at sea — `pending` is an Array of one
			# `PackedInt32Array` PER BOAT now, never a flat cargo count, so each boat's own array is
			# read directly rather than through `.size()` on the outer Array.
			for b in Rules.boat_count():
				if battle.boat_busy(b):
					continue
				var cargo: PackedInt32Array = battle.pending[b]
				if cargo.is_empty():
					continue
				var hb := int(battle.boat_at[b])
				var tile := _pick_tile(battle, hb, landing)
				if tile >= 0 and battle.launch(b, tile):
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


## Could the hand press anything at all this frame? A launch when some boat is loaded and not at
## sea, or a load when some boat has room and a soldier is still in reserve. Nothing here reads the
## policy, so the number is comparable between two policies on the same island.
##
## ⚠ Per `boat-and-landing` 4.4: a boat at sea can no longer be loaded at all — there is no queue for
## a load to join while every boat is out, unlike the old shared berth. So this genuinely has LESS
## to say yes to than the first-slice probe's own version did, which is exactly item 5's own number.
func _input_open(battle: Battle) -> bool:
	for b in Rules.boat_count():
		if battle.boat_busy(b):
			continue
		var cargo: PackedInt32Array = battle.pending[b]
		if not cargo.is_empty():
			return true
		if cargo.size() < Rules.cap_of(b):
			for i in battle.soldier_state.size():
				if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
					return true
	return false


## True while ANY boat is at sea — `boat_busy` already covers both legs (`boat-and-landing` 4.2
## deleted the old berth timer outright specifically so membership in `boats` IS the whole state),
## so "wait out the whole round trip" for the dribble policy is just this, unlike the old version
## which also had to check a separate berth countdown.
func _fleet_busy(battle: Battle) -> bool:
	for b in Rules.boat_count():
		if battle.boat_busy(b):
			return true
	return false


## The tile `launch` should aim boat `boat`'s current harbour `hb` at, for one of three landing
## strategies. Returns -1 (refuse) if `hb` has no reachable coast at all, which a caller must not
## treat as "wait", or a boat sitting at a harbour with no sendable tile would spin forever trying.
func _pick_tile(battle: Battle, hb: int, kind: String) -> int:
	match kind:
		"far":
			return _farthest_tile(battle, hb)
		"quiet":
			return _quietest_tile(battle, hb)
		_:
			return _nearest_tile(battle, hb)


## Every tile `grid.sendable[hb]` marks reachable — the SAME predicate the drag overlay and
## `battle.launch` both answer to (3.4), so a probe policy can never choose a tile the real game
## would have refused.
func _reachable_tiles(battle: Battle, hb: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if battle.grid == null or hb < 0 or hb >= battle.grid.sendable.size():
		return out
	var arr: PackedByteArray = battle.grid.sendable[hb]
	for t in arr.size():
		if arr[t] != 0:
			out.append(t)
	return out


## The reachable tile CLOSEST to harbour `hb` — "just land right here". This is also 4.6's
## "steady-state cheap" beach: called fresh every launch off `boat_at[boat]`'s CURRENT harbour, so
## once the fleet relocates this keeps picking the nearest tile from wherever it actually is now.
func _nearest_tile(battle: Battle, hb: int) -> int:
	var best := -1
	var best_d := 0.0
	var origin := battle.grid.tile_point(int(battle.grid.harbour_tiles[hb]))
	for raw in _reachable_tiles(battle, hb):
		var t := int(raw)
		var d: float = origin.distance_squared_to(battle.grid.tile_point(t))
		if best == -1 or d < best_d:
			best = t
			best_d = d
	return best


## The reachable tile FARTHEST from harbour `hb` — the far flank.
func _farthest_tile(battle: Battle, hb: int) -> int:
	var best := -1
	var best_d := -1.0
	var origin := battle.grid.tile_point(int(battle.grid.harbour_tiles[hb]))
	for raw in _reachable_tiles(battle, hb):
		var t := int(raw)
		var d: float = origin.distance_squared_to(battle.grid.tile_point(t))
		if d > best_d:
			best = t
			best_d = d
	return best


## The reachable tile whose NEAREST living enemy is farthest away — "land where the enemy is not",
## 4.6's other half. Read from the SIM's own `enemy_alive` / `enemy_pos` at call time, never
## re-derived from what this probe expects to see there — a probe that grades its own step by
## modelling the enemy instead of reading it is the exact shape the last one's flee-table miss was.
func _quietest_tile(battle: Battle, hb: int) -> int:
	var best := -1
	var best_min_d := -1.0
	for raw in _reachable_tiles(battle, hb):
		var t := int(raw)
		var p := battle.grid.tile_point(t)
		var nearest_enemy := 1e30
		for e in battle.enemy_alive.size():
			if battle.enemy_alive[e] == 0:
				continue
			var d: float = p.distance_squared_to(battle.enemy_pos[e])
			nearest_enemy = minf(nearest_enemy, d)
		if nearest_enemy > best_min_d:
			best_min_d = nearest_enemy
			best = t
	return best


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


# --- policy configs --------------------------------------------------------------------------------

func _cfg(types: Array, dribble: bool, landing_kind: String) -> Dictionary:
	return {"types": types, "dribble": dribble, "landing": landing_kind}


func _all_cfg() -> Dictionary:
	return _cfg([Rules.CELL_MELEE, Rules.CELL_RANGED], false, "near")


# --- army helpers --------------------------------------------------------------------------------

func _pool(army: Army) -> float:
	var total := 0.0
	for i in army.hp.size():
		if army.alive[i] != 0:
			total += army.hp[i]
	return total


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
