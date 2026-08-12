extends RefCounted
## The host, the dash, and the three speeds.
##
## **The speed ordering is what the design calls the whole tension** — host > predator > scattered clone,
## so the host always escapes and an abandoned clone never does. It was untested: a verifier dropped
## `PREDATOR_SPEED` to 20 and raised `CLONE_SPEED_SCATTER` to 500 and every net stayed green, because the
## one net that touches predators parks one **on top of** a clone, where speed never runs.
##
## `host_input` and `try_dash()` appeared in no net at all. `HOST_SPEED = 0` was green.

const DT := 1.0 / 60.0


func run(t) -> void:
	# The ordering, as a statement. Cheap, and it fails the moment someone tunes one of the three without
	# looking at the other two.
	t.ok(Rules.HOST_SPEED > Rules.PREDATOR_SPEED, "호스트가 포식자보다 빠르다")
	t.ok(Rules.PREDATOR_SPEED > Rules.CLONE_SPEED_SCATTER, "포식자가 흩어진 분신보다 빠르다")

	# -- the host actually moves -------------------------------------
	var sw := Swarm.new()
	sw.setup(21, Vector2(1000.0, 1000.0))
	sw.host_input = Vector2.RIGHT
	sw.step(DT, null)
	var walk := sw.pos[0].distance_to(Vector2(1000.0, 1000.0))
	t.ok(absf(walk - Rules.HOST_SPEED * DT) < 0.01, "한 스텝에 속도×dt 만큼 걸었다 (%.3f)" % walk)

	# -- and the dash is a different thing ---------------------------
	t.ok(sw.try_dash(), "대시가 나간다")
	t.ok(not sw.try_dash(), "쿨다운 중에는 두 번째 대시가 없다")
	var before: Vector2 = sw.pos[0]
	sw.step(DT, null)
	var dash_step := sw.pos[0].distance_to(before)
	t.ok(dash_step > walk * 2.0, "대시 한 스텝이 걷기보다 훨씬 멀다 (%.1f > %.1f)" % [dash_step, walk])

	# -- a predator closes on a clone --------------------------------
	var w := World.new()
	w.setup(31)
	_silence_food(w)
	w.pred_count = 0
	var c := w.swarm.add_clone()
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	w.swarm.command_scatter()
	w.swarm.pos[c] = Vector2(1000.0, 1000.0)
	w.swarm.pos[0] = Vector2(3000.0, 1000.0)
	w.pred_pos[0] = Vector2(1000.0, 1200.0)
	w.pred_count = 1
	var gap0: float = w.pred_pos[0].distance_to(w.swarm.pos[c])
	for _s in 60:
		if w.swarm.count < 2:
			break
		w.step(DT)
	t.ok(w.swarm.count < 2 or w.pred_pos[0].distance_to(w.swarm.pos[1]) < gap0,
			"포식자가 흩어진 분신에게 붙는다")

	# -- and loses ground against the host ---------------------------
	var w2 := World.new()
	w2.setup(32)
	_silence_food(w2)
	w2.pred_count = 0
	w2.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w2.pred_pos[0] = Vector2(700.0, 1000.0)
	w2.pred_count = 1
	w2.swarm.host_input = Vector2.RIGHT
	var gap_before: float = w2.pred_pos[0].distance_to(w2.swarm.pos[0])
	for _s in 120:
		w2.step(DT)
	var gap_after: float = w2.pred_pos[0].distance_to(w2.swarm.pos[0])
	t.ok(gap_after > gap_before + 50.0,
			"도망치는 호스트에게서 포식자가 뒤처진다 (%.0f → %.0f)" % [gap_before, gap_after])

	# -- contact costs one hit, and only one inside the grace --------
	var w3 := World.new()
	w3.setup(33)
	_silence_food(w3)
	w3.pred_count = 0
	w3.pred_pos[0] = w3.swarm.pos[0]
	w3.pred_count = 1
	w3.step(DT)
	t.eq(w3.host_hp, Rules.HOST_HP - 1, "포식자에 닿으면 한 대 맞는다")
	for _s in 30:
		w3.step(DT)
	t.eq(w3.host_hp, Rules.HOST_HP - 1, "무적 시간 안에는 두 번 맞지 않는다")

	# -- predators never materialise in your lap ---------------------
	var w4 := World.new()
	w4.setup(34)
	var worst := INF
	for k in w4.pred_count:
		worst = minf(worst, w4.pred_pos[k].distance_to(w4.swarm.pos[0]))
	t.ok(worst >= 900.0, "스폰은 화면 밖에서 일어난다 (%.0f)" % worst)


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
