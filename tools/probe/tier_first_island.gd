extends SceneTree
## verify-run, 티켓 19. Drives the FIRST ISLAND (the one `Rules.MAP_NODES[0]` opens) to a verdict and
## reports numbers only. Nothing here asserts a design value; it reports what the sim did.
##
## Five questions, in the order the report prints them:
##   1. does the fight END (hard frame budget; exhausting it is a FAILURE, not "inconclusive")
##   2. does anything STAND STILL (per-body longest motionless stretch, with where it stood and its level)
##   3. do wolves CLIMB (bodies observed on level 2 by walking; plateau enemies losing HP to melee)
##   4. can a LANDING body end up on the plateau (whole roster onto one tile beside the plateau)
##   5. is it WINNABLE and in how long
##
## Run:
##   Godot_v*.exe --headless --path <project> --script res://tools/probe/tier_first_island.gd

const DT := 0.05

## **The hard budget.** 6000 x 0.05 = 300 simulated seconds. There is no time-limit defeat any more,
## so a fight nobody can finish spins forever; hitting this ceiling is reported as a FAILURE.
const MAX_STEPS := 6000

## A body is "motionless" this frame when it moved less than this. `Rules.EPS` is the sim's own
## settle threshold, so anything at or under it is a body that is not walking.
const STILL := 0.001

const ISLAND := 4


func _initialize() -> void:
	print("[탐침] 첫 섬 — 노드 0 이 여는 섬 %d · dt %.2fs · 프레임 상한 %d (%.0f 초)"
			% [ISLAND, DT, MAX_STEPS, MAX_STEPS * DT])
	_shape()

	var results: Array = []
	results.append(_play("가장 가까운 해안 (기준선)", "near"))
	results.append(_play("계단에서 가장 가까운 해안", "stair"))
	results.append(_play("고원 바로 밑 해안 (상륙 시험)", "under"))
	results.append(_play("가장 먼 해안", "far"))

	_summary(results)
	print("")
	print("[탐침] 끝.")
	quit(0)


# --- 1. what the island is ------------------------------------------------------------------------

func _shape() -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var lv := {0: 0, 1: 0, 2: 0}
	var stairs: Array = []
	for t in g.level.size():
		var l := g.level_of(t)
		lv[l] = int(lv.get(l, 0)) + 1
		if l == 1:
			stairs.append(g.tile_point(t))
	print("")
	print("=== 섬 %d 의 모양 ===" % ISLAND)
	print("  격자 %dx%d · 낮은 땅 %d칸 · 계단 %d칸 · 높은 땅 %d칸"
			% [g.w, g.h, int(lv.get(0, 0)), int(lv.get(1, 0)), int(lv.get(2, 0))])
	print("  계단 좌표: %s" % str(stairs))
	print("  항구 %d개 · Rules.TIER_RISE %.1f · TIER_STEP %.1f · MAX_CLIMB %d"
			% [g.harbour_tiles.size(), Rules.TIER_RISE_TILES, Rules.TIER_STEP_TILES,
			Rules.MAX_CLIMB_LEVELS])

	var send_low := 0
	var send_high := 0
	for t in g.passable.size():
		if g.home_harbour_for(t) < 0:
			continue
		if g.level_of(t) == 0:
			send_low += 1
		else:
			send_high += 1
	print("  배를 보낼 수 있는 칸 %d개 — 낮은 층 %d · 높은 층 %d (높은 쪽이 0 이어야 정상)"
			% [send_low + send_high, send_low, send_high])

	print("  적:")
	for raw2 in Islands.spawns():
		var sp2: Dictionary = raw2
		var p: Vector2 = g.tile_point(int(sp2["tile"]))
		print("    %-10s @ %s · 단 %d · 사거리 %.1f (실제 %.1f)" % [
			Rules.name_of(int(sp2["type_id"])), str(p),
			g.level_of(int(sp2["tile"])),
			Rules.range_of(int(sp2["type_id"])),
			Rules.range_of(int(sp2["type_id"])) + Rules.REACH_BONUS])


# --- the driver -----------------------------------------------------------------------------------

func _play(label: String, kind: String) -> Dictionary:
	print("")
	print("=== %s ===" % label)
	var run := Run.new()
	if run.state() == Run.State.PICK:
		run.take_card(0)
	var battle := run.begin_island()
	if battle == null:
		print("  [!!] begin_island 가 null 이다.")
		return {"label": label, "won": false, "ended": false}

	var g := battle.grid
	var tile := _pick_tile(battle, kind)
	if tile < 0:
		print("  [!!] 보낼 수 있는 칸이 없다.")
		return {"label": label, "won": false, "ended": false}
	var tp := g.tile_point(tile)

	var ids: Array = []
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			ids.append(i)
	var roster: Array = []
	for raw in ids:
		roster.append(Rules.name_of(int(battle.army.type_id[int(raw)])))
	print("  로스터 %d명: %s" % [ids.size(), ", ".join(PackedStringArray(roster))])
	print("  상륙 칸 %s (단 %d) · 고원 중심까지 평면 %.1f칸" % [
			str(tp), g.level_of(tile), tp.distance_to(_plateau_centre(g))])

	var sends := 0
	for raw in ids:
		if battle.send(int(raw), tile) >= 0:
			sends += 1
	if not battle.commit():
		print("  [!!] 커밋 거절.")
		return {"label": label, "won": false, "ended": false}
	print("  보낸 배 %d척" % sends)

	# who stands on the plateau at spawn
	var high_enemies: Array = []
	for e in battle.enemy_alive.size():
		var p: Vector2 = battle.enemy_pos[e]
		if g.level_at(int(round(p.x)), int(round(p.y))) >= 2:
			high_enemies.append(e)

	# --- per-frame instruments
	var n_s := battle.soldier_state.size()
	var n_e := battle.enemy_alive.size()
	var prev_s: Array = battle.soldier_pos.duplicate()
	var prev_e: Array = battle.enemy_pos.duplicate()
	var still_s := PackedFloat32Array(); still_s.resize(n_s)
	var still_e := PackedFloat32Array(); still_e.resize(n_e)
	var worst_s: Array = []       # per soldier {sec, at, level, out_of_reach}
	var worst_e: Array = []
	for i in n_s:
		worst_s.append({"sec": 0.0, "at": Vector2.ZERO, "lvl": 0, "far": false})
	for e in n_e:
		worst_e.append({"sec": 0.0, "at": Vector2.ZERO, "lvl": 0, "far": false})

	var max_lvl_s := PackedInt32Array(); max_lvl_s.resize(n_s)
	var first_on_high := -1.0
	var first_climber := -1
	var landed_at: Array = []     # {id, tile, lvl} at the moment each soldier lands
	var landed_seen := PackedByteArray(); landed_seen.resize(n_s)
	# who put damage on the plateau enemies
	var high_hits: Array = []     # {from, species, from_lvl, planar, d3}
	var high_deaths: Array = []

	var steps := 0
	var first_blow := -1.0
	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		battle.begin_frame()
		battle.step(DT)
		steps += 1

		for raw_ev in battle.events:
			var ev: Dictionary = raw_ev
			if int(ev["kind"]) == Battle.Event.LAND:
				var sid := int(ev["id"])
				if landed_seen[sid] == 0:
					landed_seen[sid] = 1
					var lp: Vector2 = battle.soldier_pos[sid]
					landed_at.append({"id": sid, "at": lp,
							"lvl": g.level_at(int(round(lp.x)), int(round(lp.y)))})
			elif int(ev["kind"]) == Battle.Event.ATTACK:
				if first_blow < 0.0:
					first_blow = battle.elapsed
				if not bool(ev["from_enemy"]):
					var to := int(ev["to"])
					var targets := [to]
					for sraw in (ev["splash"] as PackedInt32Array):
						targets.append(int(sraw))
					for traw in targets:
						var t := int(traw)
						if not high_enemies.has(t):
							continue
						var f := int(ev["from"])
						var fp: Vector2 = battle.soldier_pos[f]
						var ep: Vector2 = battle.enemy_pos[t]
						high_hits.append({
							"from": f,
							"sp": Rules.name_of(int(battle.army.type_id[f])),
							"lvl": g.level_at(int(round(fp.x)), int(round(fp.y))),
							"reach": battle.army.range_of(f) + Rules.REACH_BONUS,
							"planar": fp.distance_to(ep),
							"d3": battle._dist(fp, ep),
							"t": battle.elapsed,
						})
			elif int(ev["kind"]) == Battle.Event.DEATH and bool(ev.get("is_enemy", false)):
				if high_enemies.has(int(ev["id"])):
					high_deaths.append({"e": int(ev["id"]), "t": battle.elapsed})

		for i in n_s:
			if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
				still_s[i] = 0.0
				prev_s[i] = battle.soldier_pos[i]
				continue
			var here: Vector2 = battle.soldier_pos[i]
			var lvl := g.level_at(int(round(here.x)), int(round(here.y)))
			if lvl > max_lvl_s[i]:
				max_lvl_s[i] = lvl
			if lvl >= 2 and first_on_high < 0.0:
				first_on_high = battle.elapsed
				first_climber = i
			if here.distance_to(prev_s[i]) <= STILL:
				still_s[i] += DT
				if still_s[i] > float(worst_s[i]["sec"]):
					var tgt := int(battle.soldier_target[i])
					var far := false
					if tgt >= 0 and battle.enemy_alive[tgt] != 0:
						far = battle._dist(here, battle.enemy_pos[tgt]) \
								> battle.army.range_of(i) + Rules.REACH_BONUS + Rules.EPS
					worst_s[i] = {"sec": still_s[i], "at": here, "lvl": lvl, "far": far}
			else:
				still_s[i] = 0.0
			prev_s[i] = here

		for e in n_e:
			if battle.enemy_alive[e] == 0:
				still_e[e] = 0.0
				prev_e[e] = battle.enemy_pos[e]
				continue
			var ehere: Vector2 = battle.enemy_pos[e]
			if ehere.distance_to(prev_e[e]) <= STILL:
				still_e[e] += DT
				if still_e[e] > float(worst_e[e]["sec"]):
					var et := int(battle.enemy_target[e])
					var efar := false
					if et >= 0 and battle.is_hittable(et):
						efar = battle._dist(ehere, battle.soldier_pos[et]) \
								> Rules.range_of(int(battle.enemy_type[e])) + Rules.REACH_BONUS + Rules.EPS
					worst_e[e] = {"sec": still_e[e], "at": ehere,
							"lvl": g.level_at(int(round(ehere.x)), int(round(ehere.y))), "far": efar}
			else:
				still_e[e] = 0.0
			prev_e[e] = ehere

	# --- report
	var ended := battle.outcome() != Battle.Outcome.RUNNING
	var won := battle.outcome() == Battle.Outcome.WON
	print("  1. 끝났나 — %s · %.2fs · %d 프레임 (상한 %d) · 남은 적 %d" % [
			"끝남 (%s)" % ("승" if won else _lose_name(battle)) if ended
					else "⚠ 안 끝났다 — 프레임 상한을 다 썼다",
			battle.elapsed, steps, MAX_STEPS, battle.enemies_left()])

	# 4. landing tiers
	var bad_landing := 0
	var lvl_counts := {}
	for raw in landed_at:
		var d: Dictionary = raw
		var l := int(d["lvl"])
		lvl_counts[l] = int(lvl_counts.get(l, 0)) + 1
		if l != 0:
			bad_landing += 1
	print("  4. 내린 몸 %d명의 단: %s%s" % [landed_at.size(), str(lvl_counts),
			"" if bad_landing == 0 else "   ⚠⚠ 벽 위에 내린 몸 %d명" % bad_landing])
	if bad_landing > 0:
		for raw in landed_at:
			var d2: Dictionary = raw
			if int(d2["lvl"]) != 0:
				print("       ⚠ #%d @ %s 단 %d" % [int(d2["id"]), str(d2["at"]), int(d2["lvl"])])

	# 3. climbing
	var climbed := 0
	var on_stair := 0
	for i in n_s:
		if max_lvl_s[i] >= 2:
			climbed += 1
		elif max_lvl_s[i] == 1:
			on_stair += 1
	print("  3. 걸어서 고원(단 2)에 오른 몸 %d명 · 계단(단 1)까지만 간 몸 %d명" % [climbed, on_stair])
	if first_on_high >= 0.0:
		print("     첫 등정 %.2fs (#%d %s)" % [
				first_on_high, first_climber, Rules.name_of(int(battle.army.type_id[first_climber]))])
	else:
		print("     ⚠⚠ 아무도 고원에 못 올랐다")

	var melee_hits := 0
	var ranged_hits := 0
	var attackers := {}
	for raw in high_hits:
		var h: Dictionary = raw
		attackers[h["sp"]] = int(attackers.get(h["sp"], 0)) + 1
		if float(h["reach"]) <= Rules.REACH_BONUS + Rules.EPS:
			melee_hits += 1
		else:
			ranged_hits += 1
	print("     고원 적 %d마리에 들어간 타격 %d회 — 근접(사거리 %.1f) %d · 원거리 %d · %s" % [
			high_enemies.size(), high_hits.size(), Rules.REACH_BONUS, melee_hits, ranged_hits,
			str(attackers)])
	if melee_hits > 0:
		var first_melee: Dictionary = {}
		for raw in high_hits:
			var h2: Dictionary = raw
			if float(h2["reach"]) <= Rules.REACH_BONUS + Rules.EPS:
				first_melee = h2
				break
		print("     첫 근접 타격 %.2fs — %s 가 단 %d 에서, 평면 %.2f칸 / 높이포함 %.2f칸" % [
				float(first_melee["t"]), str(first_melee["sp"]), int(first_melee["lvl"]),
				float(first_melee["planar"]), float(first_melee["d3"])])
	print("     고원 적 %d/%d 마리가 죽었다" % [high_deaths.size(), high_enemies.size()])
	for e in high_enemies:
		print("       고원 적 #%d %s — HP %.1f/%.1f · %s @ %s" % [
				int(e), Rules.name_of(int(battle.enemy_type[int(e)])), battle.enemy_hp[int(e)],
				Rules.hp_of(int(battle.enemy_type[int(e)])),
				"살아있음" if battle.enemy_alive[int(e)] != 0 else "죽음",
				str(battle.enemy_pos[int(e)])])

	# 2. standing still
	print("  2. 가만히 서 있던 시간 — 몸마다 제일 긴 한 토막")
	var s_rows: Array = []
	for i in n_s:
		if float(worst_s[i]["sec"]) > 0.0:
			s_rows.append({"id": i, "d": worst_s[i], "sp": Rules.name_of(int(battle.army.type_id[i]))})
	s_rows.sort_custom(func(a, b): return float(a["d"]["sec"]) > float(b["d"]["sec"]))
	for k in mini(6, s_rows.size()):
		var r: Dictionary = s_rows[k]
		var d3: Dictionary = r["d"]
		print("     병사 #%-2d %-8s %6.2fs @ %s 단 %d · 목표가 사거리 밖: %s" % [
				int(r["id"]), str(r["sp"]), float(d3["sec"]), str(d3["at"]), int(d3["lvl"]),
				"예 ⚠" if bool(d3["far"]) else "아니오"])
	var e_rows: Array = []
	for e in n_e:
		if float(worst_e[e]["sec"]) > 0.0:
			e_rows.append({"id": e, "d": worst_e[e], "sp": Rules.name_of(int(battle.enemy_type[e]))})
	e_rows.sort_custom(func(a, b): return float(a["d"]["sec"]) > float(b["d"]["sec"]))
	for k in mini(6, e_rows.size()):
		var r2: Dictionary = e_rows[k]
		var d4: Dictionary = r2["d"]
		print("     적   #%-2d %-8s %6.2fs @ %s 단 %d · 목표가 사거리 밖: %s" % [
				int(r2["id"]), str(r2["sp"]), float(d4["sec"]), str(d4["at"]), int(d4["lvl"]),
				"예 ⚠" if bool(d4["far"]) else "아니오"])

	print("  5. 첫 타격 %.2fs · 살아남은 병사 %d/%d" % [
			maxf(first_blow, 0.0), battle.ashore_ids().size(), sends])

	return {"label": label, "won": won, "ended": ended, "dur": battle.elapsed, "steps": steps,
			"climbed": climbed, "bad_landing": bad_landing, "left": battle.enemies_left(),
			"melee": melee_hits, "high_dead": high_deaths.size(),
			"worst_stall": _worst_of(worst_s, worst_e)}


func _worst_of(a: Array, b: Array) -> float:
	var w := 0.0
	for raw in a:
		w = maxf(w, float((raw as Dictionary)["sec"]))
	for raw in b:
		w = maxf(w, float((raw as Dictionary)["sec"]))
	return w


func _summary(rows: Array) -> void:
	print("")
	print("=== 요약 ===")
	for raw in rows:
		var r: Dictionary = raw
		if not bool(r.get("ended", false)):
			print("  %-24s ⚠⚠ 안 끝났다" % str(r["label"]))
			continue
		print("  %-24s %s %6.2fs · 오른 몸 %d · 고원 적 %d 죽음 · 근접타 %d · 벽 위 상륙 %d · 최장 정지 %.2fs" % [
				str(r["label"]), "승" if bool(r["won"]) else "패",
				float(r["dur"]), int(r["climbed"]), int(r["high_dead"]), int(r["melee"]),
				int(r["bad_landing"]), float(r["worst_stall"])])


# --- landing tile choice ---------------------------------------------------------------------------

func _plateau_centre(g: Grid) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for t in g.level.size():
		if g.level_of(t) >= 2:
			sum += g.tile_point(t)
			n += 1
	return Vector2.ZERO if n == 0 else sum / float(n)


func _sendable(battle: Battle) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t in battle.grid.passable.size():
		if battle.grid.home_harbour_for(t) >= 0:
			out.append(t)
	return out


func _crossing(battle: Battle, tile: int) -> float:
	var hb := battle.grid.home_harbour_for(tile)
	if hb < 0:
		return 1e30
	var route := battle.grid.water_route(hb, tile)
	if route.size() < 2:
		return 1e30
	var total := 0.0
	for k in range(1, route.size()):
		total += route[k - 1].distance_to(route[k])
	return total


func _stair_point(g: Grid) -> Vector2:
	for t in g.level.size():
		if g.level_of(t) == 1:
			return g.tile_point(t)
	return Vector2.ZERO


func _pick_tile(battle: Battle, kind: String) -> int:
	var g := battle.grid
	var best := -1
	var best_v := 0.0
	for raw in _sendable(battle):
		var t := int(raw)
		var v := 0.0
		match kind:
			"near":
				v = _crossing(battle, t)
			"far":
				v = -_crossing(battle, t)
			"stair":
				v = g.tile_point(t).distance_to(_stair_point(g))
			"under":
				v = g.tile_point(t).distance_to(_plateau_centre(g))
			_:
				v = _crossing(battle, t)
		if best == -1 or v < best_v - Rules.EPS:
			best = t
			best_v = v
	return best


func _lose_name(battle: Battle) -> String:
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
