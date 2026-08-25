extends SceneTree
## verify-run, 티켓 19, round 2. Same island as `tier_first_island.gd` but with the ROSTER PINNED
## (`seed_cards`) so two landing tiles are comparable, and with **every sendable tile swept** instead
## of four hand-picked ones.
##
## Then it deep-dives the worst tile it found: one body's position traced every 0.25 s together with
## what the pathfinder wanted, so "it stood still" can be told apart from "it was queued behind a
## one-tile stair".
##
## Run:
##   Godot_v*.exe --headless --path <project> --script res://tools/probe/tier_sweep.gd

const DT := 0.05
const MAX_STEPS := 6000
const STILL := 0.001
const ISLAND := 4

## The card seeds swept. Three rosters, so a verdict that is really about which beast the run drew
## cannot read as a verdict about the landing tile.
const SEEDS := [1, 7, 99]


func _initialize() -> void:
	print("[탐침2] 첫 섬 전수 — 상륙 가능 칸 전부 x 카드 씨앗 %s · 프레임 상한 %d" % [str(SEEDS), MAX_STEPS])

	var worst := {}
	for s in SEEDS:
		var r := _sweep(int(s))
		if worst.is_empty() or float(r["worst_stall"]) > float(worst["worst_stall"]):
			worst = r

	print("")
	print("=== 제일 오래 멈춰 섰던 판을 다시 돌려서 한 몸을 추적한다 ===")
	_trace(int(worst["seed"]), int(worst["tile"]))

	print("")
	print("[탐침2] 끝.")
	quit(0)


func _open(seed_value: int) -> Battle:
	var run := Run.new()
	run.seed_cards(seed_value)
	if run.state() == Run.State.PICK:
		run.take_card(0)
	if not run.enter_node(0):
		return null
	return run.begin_island()


func _sendable(battle: Battle) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t in battle.grid.passable.size():
		if battle.grid.home_harbour_for(t) >= 0:
			out.append(t)
	return out


func _sweep(seed_value: int) -> Dictionary:
	var probe := _open(seed_value)
	if probe == null:
		print("  [!!] 섬을 못 열었다 (씨앗 %d)" % seed_value)
		return {"seed": seed_value, "worst_stall": 0.0, "tile": -1}
	var roster: Array = []
	for i in probe.army.type_id.size():
		if probe.army.alive[i] != 0:
			roster.append(Rules.name_of(int(probe.army.type_id[i])))
	var tiles := _sendable(probe)
	print("")
	print("=== 카드 씨앗 %d · 로스터 %d명: %s ===" % [
			seed_value, roster.size(), ", ".join(PackedStringArray(roster))])
	print("  상륙 가능 칸 %d개 전부에 로스터 전원을 내려 본다" % tiles.size())

	var wins := 0
	var losses := 0
	var unfinished := 0
	var durs: Array = []
	var worst_stall := 0.0
	var worst_tile := -1
	var bad_landings := 0
	var climbed_any := 0
	var rows: Array = []

	for raw in tiles:
		var t := int(raw)
		var r := _one(seed_value, t)
		rows.append(r)
		if not bool(r["ended"]):
			unfinished += 1
			print("  ⚠⚠ 칸 %s — 안 끝났다. %d 프레임을 다 썼고 적이 %d 마리 남았다"
					% [str(r["at"]), MAX_STEPS, int(r["left"])])
		elif bool(r["won"]):
			wins += 1
			durs.append(float(r["dur"]))
		else:
			losses += 1
		bad_landings += int(r["bad_landing"])
		if int(r["climbed"]) > 0:
			climbed_any += 1
		if float(r["stall"]) > worst_stall:
			worst_stall = float(r["stall"])
			worst_tile = t

	durs.sort()
	var median := 0.0 if durs.is_empty() else float(durs[durs.size() / 2])
	print("  결과 — 승 %d · 패 %d · 안 끝남 %d (칸 %d개)" % [wins, losses, unfinished, tiles.size()])
	if not durs.is_empty():
		print("  이긴 판의 길이 — 최단 %.2fs · 중앙값 %.2fs · 최장 %.2fs"
				% [float(durs[0]), median, float(durs[-1])])
	print("  벽 위에 내린 몸: %d명 (섬 전체, 모든 칸 합쳐서)" % bad_landings)
	print("  고원(단 2)에 오른 몸이 하나라도 있던 칸: %d / %d" % [climbed_any, tiles.size()])
	print("  최장 정지 %.2fs (칸 %s)" % [worst_stall, str(_pt(probe, worst_tile))])

	# The losing tiles, named, because "which beach loses" is the whole decision this game has
	var lost_at: Array = []
	for raw2 in rows:
		var r2: Dictionary = raw2
		if bool(r2["ended"]) and not bool(r2["won"]):
			lost_at.append("%s(%s,%.0fs,정지 %.1fs)" % [
					str(r2["at"]), str(r2["why"]), float(r2["dur"]), float(r2["stall"])])
	if not lost_at.is_empty():
		print("  진 칸: %s" % ", ".join(PackedStringArray(lost_at)))

	# The tiles where somebody stood still for a long time while its target was out of reach
	var frozen: Array = []
	for raw3 in rows:
		var r3: Dictionary = raw3
		if float(r3["stall_far"]) >= 5.0:
			frozen.append("%s %.1fs@%s단%d" % [str(r3["at"]), float(r3["stall_far"]),
					str(r3["stall_far_at"]), int(r3["stall_far_lvl"])])
	print("  목표가 사거리 밖인데 5초 넘게 안 움직인 몸이 있던 칸 %d개:" % frozen.size())
	for k in mini(12, frozen.size()):
		print("     %s" % str(frozen[k]))

	return {"seed": seed_value, "worst_stall": worst_stall, "tile": worst_tile}


func _pt(battle: Battle, t: int) -> Vector2:
	return Vector2(-1, -1) if t < 0 else battle.grid.tile_point(t)


func _one(seed_value: int, tile: int) -> Dictionary:
	var battle := _open(seed_value)
	var g := battle.grid
	var ids: Array = []
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			ids.append(i)
	for raw in ids:
		battle.send(int(raw), tile)
	battle.commit()

	var n_s := battle.soldier_state.size()
	var n_e := battle.enemy_alive.size()
	var prev_s: Array = battle.soldier_pos.duplicate()
	var prev_e: Array = battle.enemy_pos.duplicate()
	var still_s := PackedFloat32Array(); still_s.resize(n_s)
	var still_e := PackedFloat32Array(); still_e.resize(n_e)
	var stall := 0.0
	var stall_far := 0.0
	var stall_far_at := Vector2.ZERO
	var stall_far_lvl := 0
	var climbed := 0
	var seen_high := PackedByteArray(); seen_high.resize(n_s)
	var bad_landing := 0
	var steps := 0

	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		battle.begin_frame()
		battle.step(DT)
		steps += 1
		for raw_ev in battle.events:
			var ev: Dictionary = raw_ev
			if int(ev["kind"]) == Battle.Event.LAND:
				var lp: Vector2 = battle.soldier_pos[int(ev["id"])]
				if g.level_at(int(round(lp.x)), int(round(lp.y))) != 0:
					bad_landing += 1
		for i in n_s:
			if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
				still_s[i] = 0.0
				prev_s[i] = battle.soldier_pos[i]
				continue
			var here: Vector2 = battle.soldier_pos[i]
			var lvl := g.level_at(int(round(here.x)), int(round(here.y)))
			if lvl >= 2 and seen_high[i] == 0:
				seen_high[i] = 1
				climbed += 1
			if here.distance_to(prev_s[i]) <= STILL:
				still_s[i] += DT
				stall = maxf(stall, still_s[i])
				var tgt := int(battle.soldier_target[i])
				if tgt >= 0 and battle.enemy_alive[tgt] != 0 \
						and battle._dist(here, battle.enemy_pos[tgt]) \
						> battle.army.range_of(i) + Rules.REACH_BONUS + Rules.EPS:
					if still_s[i] > stall_far:
						stall_far = still_s[i]
						stall_far_at = here
						stall_far_lvl = lvl
			else:
				still_s[i] = 0.0
			prev_s[i] = here
		for e in n_e:
			if battle.enemy_alive[e] == 0:
				still_e[e] = 0.0
				prev_e[e] = battle.enemy_pos[e]
				continue
			var eh: Vector2 = battle.enemy_pos[e]
			if eh.distance_to(prev_e[e]) <= STILL:
				still_e[e] += DT
				stall = maxf(stall, still_e[e])
			else:
				still_e[e] = 0.0
			prev_e[e] = eh

	return {
		"at": g.tile_point(tile), "tile": tile,
		"ended": battle.outcome() != Battle.Outcome.RUNNING,
		"won": battle.outcome() == Battle.Outcome.WON,
		"why": _lose_name(battle), "dur": battle.elapsed, "left": battle.enemies_left(),
		"stall": stall, "stall_far": stall_far, "stall_far_at": stall_far_at,
		"stall_far_lvl": stall_far_lvl, "climbed": climbed, "bad_landing": bad_landing,
	}


# --- the deep dive ---------------------------------------------------------------------------------

## Replays one landing and prints, every `TRACE_EVERY`, the body that has been motionless longest —
## where it stands, what it is chasing, and what `step_toward` would hand it. That last part is the
## whole question: a body whose next tile is RESERVED is queued behind somebody, and a body whose
## target tile is UNREACHABLE in its own flow field is frozen.
const TRACE_EVERY := 20      # frames, = 1.00 s


func _trace(seed_value: int, tile: int) -> void:
	var battle := _open(seed_value)
	var g := battle.grid
	print("  씨앗 %d · 상륙 칸 %s" % [seed_value, str(g.tile_point(tile))])
	var ids: Array = []
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			ids.append(i)
	for raw in ids:
		battle.send(int(raw), tile)
	battle.commit()

	var n_s := battle.soldier_state.size()
	var prev: Array = battle.soldier_pos.duplicate()
	var still := PackedFloat32Array(); still.resize(n_s)
	var steps := 0
	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		battle.begin_frame()
		battle.step(DT)
		steps += 1
		var worst := -1
		for i in n_s:
			if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
				still[i] = 0.0
				prev[i] = battle.soldier_pos[i]
				continue
			var here: Vector2 = battle.soldier_pos[i]
			if here.distance_to(prev[i]) <= STILL:
				still[i] += DT
			else:
				still[i] = 0.0
			prev[i] = here
			if worst < 0 or still[i] > still[worst]:
				worst = i
		if steps % TRACE_EVERY != 0 or worst < 0:
			continue
		_line(battle, worst, still[worst])
	print("  판정 %s · %.2fs · %d 프레임 · 남은 적 %d" % [
			"승" if battle.outcome() == Battle.Outcome.WON else _lose_name(battle),
			battle.elapsed, steps, battle.enemies_left()])


func _line(battle: Battle, i: int, stalled: float) -> void:
	var g := battle.grid
	var here: Vector2 = battle.soldier_pos[i]
	var cur := g.tile_index(int(round(here.x)), int(round(here.y)))
	var tgt := int(battle.soldier_target[i])
	var tgt_txt := "없음"
	var next_txt := "-"
	if tgt >= 0 and battle.enemy_alive[tgt] != 0:
		var ep: Vector2 = battle.enemy_pos[tgt]
		var et := g.tile_index(int(round(ep.x)), int(round(ep.y)))
		var field := g.flow_field(et)
		var cost := int(field[cur])
		tgt_txt = "적#%d %s @%s 단%d · 평면%.2f · 높이포함%.2f (사거리 %.2f) · 내 칸 비용 %s" % [
				tgt, Rules.name_of(int(battle.enemy_type[tgt])), str(ep),
				g.level_of(et), here.distance_to(ep), battle._dist(here, ep),
				battle.army.range_of(i) + Rules.REACH_BONUS,
				"닿지 않음 ⚠⚠" if cost >= Grid.UNREACHABLE else str(cost)]
		# what step_toward would pick, and why it might not
		var best := -1
		var best_cost := cost
		var blocked: Array = []
		for k in Grid.NEIGHBOURS.size():
			var nx := int(round(here.x)) + int(Grid.NEIGHBOURS[k][0])
			var ny := int(round(here.y)) + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= g.w or ny >= g.h:
				continue
			var nt := ny * g.w + nx
			if not g.can_step(cur, nt):
				continue
			if int(field[nt]) >= best_cost:
				continue
			if g.reserved[nt] != -1 and g.reserved[nt] != i:
				blocked.append("(%d,%d)<-#%d" % [nx, ny, int(g.reserved[nt])])
				continue
			best = nt
			best_cost = int(field[nt])
		if best >= 0:
			next_txt = "다음 칸 %s" % str(g.tile_point(best))
		elif not blocked.is_empty():
			next_txt = "더 나은 칸이 전부 예약됨: %s" % ", ".join(PackedStringArray(blocked))
		else:
			next_txt = "더 나은 이웃 칸이 아예 없다 ⚠"
	print("  %6.2fs #%-2d %-6s @%-14s 단%d · 정지 %5.2fs · %s · %s" % [
			battle.elapsed, i, Rules.name_of(int(battle.army.type_id[i])), str(here),
			g.level_of(cur), stalled, tgt_txt, next_txt])


func _lose_name(battle: Battle) -> String:
	if battle.outcome() == Battle.Outcome.RUNNING:
		return "안 끝남"
	match battle.lose_reason():
		Battle.Lose.TIMEOUT:
			return "패(시간)"
		Battle.Lose.WIPED:
			return "패(전멸)"
		Battle.Lose.LANDING_LOST:
			return "패(상륙군 전멸)"
		_:
			return "패"
	return "패"
