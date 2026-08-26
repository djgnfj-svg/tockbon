extends SceneTree
## verify-run, 티켓 19. **The controlled experiment behind the deadlock the sweep found.**
##
## The sweep watched a body stand on the island's only stair for 163 seconds without landing a blow,
## while the archer it was chasing stood on the plateau tile DIAGONALLY above the stair. This pins
## that down with a positive control: the SAME body, on the SAME tile, against the SAME archer moved
## one tile over.
##
## Both bodies are pinned in place every frame, so nothing here measures walking — only whether the
## blow lands. **A run where the positive control also fails to land a blow means this probe is
## broken, not the sim**, and it is printed either way.
##
## Run:
##   Godot_v*.exe --headless --path <project> --script res://tools/probe/tier_stair_reach.gd

const DT := 0.05
const FRAMES := 400          # 20 s. A wolf's swing period is well under that.
const ISLAND := 4
const STAIR := Vector2(13.0, 7.0)


func _initialize() -> void:
	print("[탐침3] 계단 위에서 고원의 몸에 닿는가 — 대조군을 붙여서")
	var g := Grid.new()
	Islands.load_into(g)
	print("  계단 %s 단 %d · 근접 실제 사거리 %.2f (사거리 0 + REACH_BONUS %.1f)"
			% [str(STAIR), g.level_at(13, 7), Rules.REACH_BONUS, Rules.REACH_BONUS])
	print("  단 하나의 높이 %.1f 타일 (TIER_STEP_TILES)" % Rules.TIER_STEP_TILES)
	print("")
	# The four plateau tiles that touch the stair. Two orthogonal, two diagonal.
	for spot in [Vector2(13, 6), Vector2(14, 7), Vector2(13, 8), Vector2(14, 6), Vector2(14, 8)]:
		_case(spot)
	print("")
	print("[탐침3] 끝.")
	quit(0)


func _case(spot: Vector2) -> void:
	var battle := _stood_up()
	if battle == null:
		print("  [!!] 섬을 못 세웠다")
		return
	var g := battle.grid
	var lvl := g.level_at(int(spot.x), int(spot.y))

	# one archer, on the tile under test; everything else off the board
	var keep := -1
	for e in battle.enemy_alive.size():
		if keep < 0 and int(battle.enemy_type[e]) == Rules.CROW:
			keep = e
			continue
		battle.enemy_alive[e] = 0
	battle.enemy_pos[keep] = spot
	var hp0 := battle.enemy_hp[keep]

	# one melee body, on the stair; everything else dead so nothing else can reach in
	var mover := -1
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
			continue
		if mover < 0 and battle.army.range_of(i) <= Rules.EPS:
			mover = i
			continue
		battle.army.kill(i)
		battle.soldier_state[i] = Battle.SoldierState.DEAD
	if mover < 0:
		print("  [!!] 근접 병사가 없다")
		return
	battle.army.hp[mover] = 9999.0
	battle.soldier_pos[mover] = STAIR

	var kind := "직교" if (absf(spot.x - STAIR.x) < 0.5 or absf(spot.y - STAIR.y) < 0.5) else "대각"
	var planar := STAIR.distance_to(spot)
	var d3 := battle._dist(STAIR, spot)

	var swings := 0
	for f in FRAMES:
		# pinned: this probe measures REACH, not walking
		# ⚠⚠ **THE GOALS ARE PINNED TOO AND THEY WERE NOT, AND THAT MOVED THE ANSWER** (2026-08-25).
		# Writing only `enemy_pos` leaves `_enemy_goal` on the body's ORIGINAL spawn tile, so
		# `_phase_movement`'s standing branch glides it back toward that tile at `speed * DT` — an
		# archer is 6.0 tiles/s, so **0.3 of a tile every frame, before the blow is tested.** The
		# distance under test was therefore not the one printed, and it drifted in a DIFFERENT
		# DIRECTION for each spot: of the two diagonals at an identical 1.732, one drifted to 1.98 and
		# read as out of reach while the other drifted to 1.68 and read as in reach. **Two identical
		# geometries, two different verdicts, from the fixture rather than the sim.**
		battle.soldier_pos[mover] = STAIR
		battle._soldier_goal[mover] = STAIR
		battle.enemy_pos[keep] = spot
		battle._enemy_goal[keep] = spot
		battle.begin_frame()
		battle.step(DT)
		for raw in battle.events:
			var ev: Dictionary = raw
			if int(ev["kind"]) == Battle.Event.ATTACK and not bool(ev["from_enemy"]):
				swings += 1
		if battle.outcome() != Battle.Outcome.RUNNING:
			break
	var dealt := hp0 - battle.enemy_hp[keep]

	print("  적이 %s 단%d (%s, 평면 %.3f · 높이포함 %.3f) — %.1fs 동안 때린 횟수 %d · 준 피해 %.1f · %s" % [
			str(spot), lvl, kind, planar, d3, FRAMES * DT, swings, maxf(dealt, 0.0),
			"닿는다" if dealt > 0.0 else "⚠⚠ 못 닿는다"])


## A real island 4, committed, with everybody ashore. Nothing is hand-placed until `_case` does it.
func _stood_up() -> Battle:
	var run := Run.new()
	run.seed_cards(99)
	if run.state() == Run.State.PICK:
		run.take_card(0)
	var battle := run.begin_island()
	var tile := -1
	for t in battle.grid.passable.size():
		if battle.grid.home_harbour_for(t) >= 0:
			tile = t
			break
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			battle.send(i, tile)
	battle.commit()
	# step until every boat has emptied, so nobody is still in TRANSIT when `_case` places bodies
	var guard := 0
	while guard < 2000:
		guard += 1
		var waiting := false
		for i in battle.soldier_state.size():
			if battle.soldier_state[i] == Battle.SoldierState.TRANSIT:
				waiting = true
				break
		if not waiting:
			break
		battle.begin_frame()
		battle.step(DT)
	return battle
