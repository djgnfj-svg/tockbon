extends SceneTree
## verify-run, 티켓 19. Replays every landing tile of island 4 that LOST and prints what was still
## standing when the landing force died — species, tile, tier — plus where the last living bodies
## stood. The question is whether the losses are the stair deadlock or something else.

const DT := 0.05
const MAX_STEPS := 6000
const ISLAND := 4
const SEEDS := [1, 7, 99]


func _initialize() -> void:
	for s in SEEDS:
		_seed(int(s))
	print("")
	print("[탐침4] 끝.")
	quit(0)


func _open(seed_value: int) -> Battle:
	var run := Run.new()
	run.seed_cards(seed_value)
	if run.state() == Run.State.PICK:
		run.take_card(0)
	return run.begin_island()


func _seed(seed_value: int) -> void:
	var probe := _open(seed_value)
	var tiles := PackedInt32Array()
	for t in probe.grid.passable.size():
		if probe.grid.home_harbour_for(t) >= 0:
			tiles.append(t)
	print("")
	print("=== 씨앗 %d — 진 칸에서 무엇이 살아남았나 ===" % seed_value)
	var lost := 0
	var high_only := 0
	var stair_stuck := 0
	for raw in tiles:
		var t := int(raw)
		var battle := _open(seed_value)
		var g := battle.grid
		for i in battle.soldier_state.size():
			if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
				battle.send(i, t)
		battle.commit()
		var steps := 0
		while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
			battle.begin_frame()
			battle.step(DT)
			steps += 1
		if battle.outcome() == Battle.Outcome.WON:
			continue
		lost += 1
		var alive: Array = []
		var all_high := true
		for e in battle.enemy_alive.size():
			if battle.enemy_alive[e] == 0:
				continue
			var p: Vector2 = battle.enemy_pos[e]
			var lv := g.level_at(int(round(p.x)), int(round(p.y)))
			if lv < 2:
				all_high = false
			alive.append("%s@%s단%d" % [Rules.name_of(int(battle.enemy_type[e])), str(p), lv])
		if all_high:
			high_only += 1
		# who was the last body standing, and on what tier
		var last: Array = []
		for i in battle.soldier_state.size():
			if battle.soldier_state[i] == Battle.SoldierState.DEAD:
				continue
			if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
				continue
			var sp: Vector2 = battle.soldier_pos[i]
			last.append("#%d %s@%s단%d" % [i, Rules.name_of(int(battle.army.type_id[i])), str(sp),
					g.level_at(int(round(sp.x)), int(round(sp.y)))])
		print("  %s %s · %.0fs · 남은 적: %s%s" % [
				str(g.tile_point(t)), _lose_name(battle), battle.elapsed,
				", ".join(PackedStringArray(alive)),
				"" if last.is_empty() else " · 마지막 몸: " + ", ".join(PackedStringArray(last))])
	print("  진 칸 %d개 중, 살아남은 적이 전부 고원(단 2) 위였던 판: %d개" % [lost, high_only])


func _lose_name(battle: Battle) -> String:
	if battle.outcome() == Battle.Outcome.RUNNING:
		return "안 끝남"
	match battle.lose_reason():
		Battle.Lose.WIPED:
			return "패(전멸)"
		Battle.Lose.LANDING_LOST:
			return "패(상륙군 전멸)"
		_:
			return "패"
	return "패"
