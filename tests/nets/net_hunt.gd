extends RefCounted
## The host, the dash, and the ecosystem.
##
## **The speed ordering is what the design calls the whole tension** — host > critter > scattered clone,
## so the host always escapes and an abandoned clone never does. It was untested: dropping
## `CRITTER_SPEED` to 20 and raising `CLONE_SPEED_SCATTER` to 500 left every net green, because the one
## net that touched them parked a critter **on top of** a clone, where speed never runs.
##
## **And critters are not predators.** Six things walking at the player from the first second was the
## user's first complaint; a critter now wanders until something enters `CRITTER_SENSE`, and then the
## swarm's size against its threat decides which of the two is the meal. Both directions are asserted
## here, because the reversal — what you ran from becoming what you eat — is the point of the design.

const DT := 1.0 / 60.0


func run(t) -> void:
	t.ok(Rules.HOST_SPEED > Rules.CRITTER_SPEED, "호스트가 생물보다 빠르다")
	t.ok(Rules.CRITTER_SPEED > Rules.CLONE_SPEED_SCATTER, "생물이 흩어진 분신보다 빠르다")

	# -- the host actually moves -------------------------------------
	var sw := Swarm.new()
	sw.setup(21, Vector2(1000.0, 1000.0))
	sw.host_input = Vector2.RIGHT
	sw.step(DT, null)
	var walk := sw.pos[0].distance_to(Vector2(1000.0, 1000.0))
	# 3.33 is pinned: read through `Rules.HOST_SPEED` this check scales with the constant and stays green
	# when the speed is set to zero.
	t.ok(absf(walk - 3.33) < 0.02, "한 스텝에 200px/s 만큼 걸었다 (%.3f)" % walk)

	# -- and the dash is a different thing ---------------------------
	t.ok(sw.try_dash(), "대시가 나간다")
	t.ok(not sw.try_dash(), "쿨다운 중에는 두 번째 대시가 없다")
	var before: Vector2 = sw.pos[0]
	sw.step(DT, null)
	var dash_step := sw.pos[0].distance_to(before)
	t.ok(dash_step > walk * 2.0, "대시 한 스텝이 걷기보다 훨씬 멀다 (%.1f > %.1f)" % [dash_step, walk])

	# -- nothing crosses the map to reach you ------------------------
	# The complaint that started this: a thing that walks at you from the far edge is an ambush, not an
	# ecosystem. Outside its senses it must wander, and wandering does not close distance on purpose.
	var far := World.new()
	far.setup(41)
	_silence_food(far)
	far.critter_count = 1
	far.critter_pos[0] = far.swarm.pos[0] + Vector2(1600.0, 0.0)
	far.critter_threat[0] = 5
	far.critter_dir[0] = Vector2.RIGHT
	var far0: float = far.critter_pos[0].distance_to(far.swarm.pos[0])
	for _s in 120:
		far.step(DT)
	t.ok(far.critter_pos[0].distance_to(far.swarm.pos[0]) > far0 - 60.0,
			"감지 범위 밖 생물은 나를 향해 오지 않는다")

	# -- inside its senses, and bigger than the swarm, it comes ------
	var w := World.new()
	w.setup(31)
	_silence_food(w)
	w.critter_count = 0
	var c := w.swarm.add_clone()
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	w.swarm.command_scatter()
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	w.swarm.pos[0] = Vector2(3000.0, 1000.0)
	w.critter_count = 1
	w.critter_pos[0] = Vector2(1000.0, 1300.0)
	w.critter_threat[0] = 5
	w.critter_dir[0] = Vector2.ZERO
	t.ok(not w.is_hunter_of(0), "시작 힘으로는 위협 5짜리를 못 잡는다")
	var gap0: float = w.critter_pos[0].distance_to(w.swarm.pos[c])
	for _s in 90:
		if w.swarm.count < 2:
			break
		w.step(DT)
	t.ok(w.swarm.count < 2 or w.critter_pos[0].distance_to(w.swarm.pos[1]) < gap0,
			"약한 무리에게는 생물이 붙는다")

	# -- outgrow it and the chase runs the other way -----------------
	var big := World.new()
	big.setup(36)
	_silence_food(big)
	# ⚠ **The clones carry force, and that is the point.** The comparison reads `total_force()`, not the
	# row count — twenty force-0 bodies made by nothing outrank nothing, which is exactly what stops `F`
	# from buying the reversal for free. 20 × 2 + the host's 10 = 50, over threat 2's 40.
	for _i in 20:
		big.swarm.add_clone(0, 2)
	big.critter_count = 1
	big.critter_pos[0] = big.swarm.pos[0] + Vector2(300.0, 0.0)
	big.critter_threat[0] = 2
	big.critter_dir[0] = Vector2.ZERO
	t.ok(big.is_hunter_of(0), "무리의 힘이 50이면 위협 2짜리는 먹이다")
	var flee0: float = big.critter_pos[0].distance_to(big.swarm.pos[0])
	var banked0: float = big.swarm.banked
	for _s in 30:
		big.step(DT)
	if big.critter_count == 0:
		t.ok(big.swarm.banked > banked0, "따라잡으면 잡아먹고 은행이 늘어난다")
	else:
		t.ok(big.critter_pos[0].distance_to(big.swarm.pos[0]) > flee0,
				"먹이가 된 생물은 도망친다 (%.0f → %.0f)" % [flee0, big.critter_pos[0].distance_to(big.swarm.pos[0])])
	t.eq(big.host_hp, Rules.HOST_HP, "내가 사냥자일 때는 맞지 않는다")

	# -- a fleeing host outruns it -----------------------------------
	var w2 := World.new()
	w2.setup(32)
	_silence_food(w2)
	w2.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w2.critter_count = 1
	w2.critter_pos[0] = Vector2(700.0, 1000.0)
	w2.critter_threat[0] = 5
	w2.critter_dir[0] = Vector2.ZERO
	w2.swarm.host_input = Vector2.RIGHT
	var gap_before: float = w2.critter_pos[0].distance_to(w2.swarm.pos[0])
	for _s in 120:
		w2.step(DT)
	var gap_after: float = w2.critter_pos[0].distance_to(w2.swarm.pos[0])
	t.ok(gap_after > gap_before + 30.0,
			"도망치는 호스트에게서 생물이 뒤처진다 (%.0f → %.0f)" % [gap_before, gap_after])

	# -- contact costs one hit, and only one inside the grace --------
	var w3 := World.new()
	w3.setup(33)
	_silence_food(w3)
	w3.critter_count = 1
	w3.critter_pos[0] = w3.swarm.pos[0]
	w3.critter_threat[0] = 5
	w3.critter_dir[0] = Vector2.ZERO
	w3.step(DT)
	t.eq(w3.host_hp, Rules.HOST_HP - 1, "생물에 닿으면 한 대 맞는다")
	for _s in 30:
		w3.step(DT)
	t.eq(w3.host_hp, Rules.HOST_HP - 1, "무적 시간 안에는 두 번 맞지 않는다")

	# -- and nothing spawns in your lap ------------------------------
	# Six spawns per run, each with roughly a 31% chance of landing inside the exclusion zone by luck —
	# one seed would have let a missing retry loop through about one time in nine. Ten seeds instead.
	var worst := INF
	for s in 10:
		var w4 := World.new()
		w4.setup(300 + s)
		for k in w4.critter_count:
			worst = minf(worst, w4.critter_pos[k].distance_to(w4.swarm.pos[0]))
	t.ok(worst >= 900.0, "열 판을 돌려도 스폰은 화면 밖에서 일어난다 (%.0f)" % worst)


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
