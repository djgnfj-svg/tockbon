extends RefCounted
## Where things can and cannot be: rocks you walk into, water that slows and hides, and the boss's own
## clock.
##
## **Every rock and every water circle in this file is written into `terrain` by hand at literal
## coordinates.** `Terrain.setup()`'s rejection sampler can legitimately skip a placement, so `rock_pos` is
## seed-dependent and nothing may pin a coordinate off it — the two checks that DO read the generated ground
## (T4, T5) read it as a floor and a distance, never as a position.
##
## ⚠ **No check here waits for the arena to close on its own.** The boss ships slower than the host
## (deferred by the user), so a host that keeps walking is never caught; the arena's own checks live in
## `net_run` and every one of them drives the boss to `ARENA_RADIUS` by hand.
##
## Seeds 440–459 are this file's own block.

const DT := 1.0 / 60.0
const CROW := int(Parts.Species.CROW)
const HORSE := int(Parts.Species.HORSE)


func run(t) -> void:
	_c24_a_rock_stops_everything(t)
	_c25a_water_slows_a_body(t)
	_c25b_water_hides_a_body(t)
	_c25c_water_slows_a_creature(t)
	_c26_the_boss_starts_hunting(t)
	_u15_the_boss_wanders_before_it_hunts(t)
	_u16a_the_arena_holds_the_whole_body(t)
	_t2_a_split_child_is_outside(t)
	_t3_separation_cannot_shove_into_a_rock(t)
	_t8_a_wedged_body_gets_out(t)
	_t4_the_opening_ground_is_clear(t)
	_t5_the_ground_is_actually_placed(t)
	_t7_one_seed_one_world(t)


# -- 24: a rock stops a body AND a creature --------------------------------------------------------------
## ⚠ **Literal rock centre, literal radius, literal expected distance.** A stop distance read back off
## `rock_radius[j] + Rules.BODY_RADIUS` moves with whatever it is checking; 114.0 and 115.0 are computed by
## hand from 100 + 14 and 100 + 15.
func _c24_a_rock_stops_everything(t) -> void:
	var w := World.new()
	w.setup(440)
	_silence_food(w)
	_clear_terrain(w)
	var rock := Vector2(1500.0, 1000.0)
	w.terrain.rock_pos.append(rock)
	w.terrain.rock_radius.append(100.0)

	# The host walks straight at it from the right.
	w.swarm.pos[0] = Vector2(1900.0, 1000.0)
	w.swarm.host_input = Vector2.LEFT
	w.critter_count = 0
	w.boss_index = -1
	var closest := INF
	for _s in 150:
		w.step(DT)
		closest = minf(closest, w.swarm.pos[0].distance_to(rock))
	t.ok(absf(w.swarm.pos[0].distance_to(rock) - 114.0) < 0.01,
			"바위로 걸어 들어간 호스트는 그 밖에서 선다 — 100 + 14 = 114px (리터럴) (%.3f)"
					% w.swarm.pos[0].distance_to(rock))
	t.ok(closest >= 113.99, "그리고 한 프레임도 안으로 들어간 적이 없다 (%.3f)" % closest)

	# And a creature pays the same rule. The crow's counter is re-armed every frame so it keeps walking at
	# the host for the whole run rather than expiring at `CROW_COUNTER_TIME` mid-approach.
	#
	# ⚠ **The host sits 450px away, not 700.** A countering crow still needs a target inside `CRITTER_SENSE`
	# (520) — outside it there is nothing to walk at and the crow stands still, which is a fixture that
	# measures the sense radius instead of the rock.
	var w2 := World.new()
	w2.setup(441)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.terrain.rock_pos.append(rock)
	w2.terrain.rock_radius.append(100.0)
	w2.swarm.pos[0] = Vector2(1650.0, 1000.0)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(CROW, Vector2(1200.0, 1000.0), 10)
	var closest2 := INF
	for _s in 200:
		w2.critter_counter[0] = 5.0
		w2._step_critters(DT)
		closest2 = minf(closest2, w2.critter_pos[0].distance_to(rock))
	t.ok(absf(w2.critter_pos[0].distance_to(rock) - 115.0) < 0.01,
			"바위로 걸어 들어간 까마귀도 그 밖에서 선다 — 100 + 15 = 115px (리터럴) (%.3f)"
					% w2.critter_pos[0].distance_to(rock))
	t.ok(closest2 >= 114.99, "생물도 한 프레임을 안으로 들어가지 못한다 (%.3f)" % closest2)


# -- 25a: water slows a body, and it slows a DASH too ----------------------------------------------------
## ⚠ **The multiply goes AFTER the dash branch**, because a burst REPLACES the speed. Applied before it, a
## dash crosses water at full speed — water stops being a wall at exactly the moment the player most wants
## one — and no check that only measured a walking host would see it.
func _c25a_water_slows_a_body(t) -> void:
	var ground := Terrain.new()
	ground.water_pos.append(Vector2(1000.0, 1000.0))
	ground.water_radius.append(300.0)
	var sw := Swarm.new()
	sw.setup(442, Vector2(1000.0, 1000.0))
	sw.terrain = ground
	sw.host_input = Vector2.RIGHT
	var before: Vector2 = sw.pos[0]
	sw.step(DT, null)
	var wet := sw.pos[0].distance_to(before)
	# 2.0 = HOST_SPEED 200 × WATER_SLOW 0.6 / 60, by hand.
	t.ok(absf(wet - 2.0) < 0.005, "물속의 한 걸음은 2.0px다 — 200 × 0.6 / 60 (리터럴) (%.4f)" % wet)

	var dry := Swarm.new()
	dry.setup(443, Vector2(1000.0, 1000.0))
	dry.host_input = Vector2.RIGHT
	var dry_before: Vector2 = dry.pos[0]
	dry.step(DT, null)
	var dry_step := dry.pos[0].distance_to(dry_before)
	t.ok(absf(dry_step - 3.3333) < 0.005,
			"대조: 마른 땅의 한 걸음은 3.333px다 — 물이 실제로 느리게 만든 것이다 (%.4f)" % dry_step)

	# The dash, in the same water. 560 × 0.6 = 336 px/s.
	sw.host_input = Vector2.RIGHT
	t.ok(sw.begin_dash(2.8, 0.16), "설정: 짧은 숨이 실제로 나갔다")
	var dash_before: Vector2 = sw.pos[0]
	sw.step(DT, null)
	var dash_step := sw.pos[0].distance_to(dash_before)
	t.ok(absf(dash_step - 5.6) < 0.01,
			"물속의 대시도 느려진다 — 560 × 0.6 / 60 = 5.6px (리터럴) (%.4f)" % dash_step)


# -- 25b: water HIDES a body, which is a different rule from the slow -------------------------------------
func _c25b_water_hides_a_body(t) -> void:
	# The host stands in the middle of a pool. A horse 300px away can see nothing at all.
	var w := World.new()
	w.setup(444)
	_silence_food(w)
	_clear_terrain(w)
	w.terrain.water_pos.append(Vector2(1000.0, 1000.0))
	w.terrain.water_radius.append(100.0)
	w.swarm.pos[0] = Vector2(1000.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	# ⚠ **A COUNTERING CROW, not a fleeing horse, and the swap is forced.** The horse wanders now
	# (`Rules.SPECIES_WANDER`), so "it cannot see you" and "it does not move" stopped being the same
	# sentence — a horse that sees nothing walks off in a random direction and this check read that as the
	# hiding having failed. The crow is the only species whose `WANDER` row is 0, so its stillness IS the
	# absence of a target, and a crow inside `CROW_COUNTER_TIME` walks at any body it can see. Both halves
	# of the instrument therefore stay: something that WOULD move, and a reason it does not.
	w._write_critter(CROW, Vector2(1300.0, 1000.0), 10)
	w.critter_counter[0] = Rules.CROW_COUNTER_TIME
	w.critter_dir[0] = Vector2.ZERO
	var at: Vector2 = w.critter_pos[0]
	for _s in 60:
		w.critter_counter[0] = Rules.CROW_COUNTER_TIME
		w._step_critters(DT)
	t.ok(w.critter_pos[0].distance_to(at) < 0.001,
			"물속에 선 몸은 반격하는 까마귀에게 보이지 않는다 — 한 발짝도 움직이지 않는다 (%.4f)"
					% w.critter_pos[0].distance_to(at))

	# The control the paragraph above promises: the SAME crow, the same counter, and the host one pixel
	# outside the pool. Without it "it did not move" is satisfied by a crow that never moves at all.
	var wc := World.new()
	wc.setup(444)
	_silence_food(wc)
	_clear_terrain(wc)
	wc.terrain.water_pos.append(Vector2(1000.0, 1000.0))
	wc.terrain.water_radius.append(100.0)
	wc.swarm.pos[0] = Vector2(899.0, 1000.0)
	wc.critter_count = 0
	wc.boss_index = -1
	wc._write_critter(CROW, Vector2(1300.0, 1000.0), 10)
	wc.critter_dir[0] = Vector2.ZERO
	var seen_gap: float = wc.critter_pos[0].distance_to(wc.swarm.pos[0])
	for _s in 60:
		wc.critter_counter[0] = Rules.CROW_COUNTER_TIME
		wc._step_critters(DT)
	t.ok(wc.critter_pos[0].distance_to(wc.swarm.pos[0]) < seen_gap - 50.0,
			"대조: 물 밖에 선 같은 몸에게는 그 까마귀가 걸어온다 (%.0f → %.0f)"
					% [seen_gap, wc.critter_pos[0].distance_to(wc.swarm.pos[0])])

	# The same pool, the same gap, and the body one pixel OUTSIDE it.
	var w2 := World.new()
	w2.setup(445)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.terrain.water_pos.append(Vector2(1000.0, 1000.0))
	w2.terrain.water_radius.append(100.0)
	w2.swarm.pos[0] = Vector2(899.0, 1000.0)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(HORSE, Vector2(1199.0, 1000.0), 30)
	w2.critter_dir[0] = Vector2.ZERO
	var gap0: float = w2.critter_pos[0].distance_to(w2.swarm.pos[0])
	t.ok(absf(gap0 - 300.0) < 0.01, "설정: 두 번째 판의 거리도 똑같이 300px다 (%.2f)" % gap0)
	for _s in 60:
		w2._step_critters(DT)
	t.ok(w2.critter_pos[0].distance_to(w2.swarm.pos[0]) > gap0 + 100.0,
			"물 밖으로 한 픽셀만 나오면 말은 곧바로 도망친다 (%.0f → %.0f)"
					% [gap0, w2.critter_pos[0].distance_to(w2.swarm.pos[0])])


# -- 25c: a CREATURE inside water is slowed too ----------------------------------------------------------
## ⚠ Water that slowed only the swarm would be a stealth field. Slowing everything is what makes it the
## third wall the horse can be herded against, and nothing in the round measured it.
func _c25c_water_slows_a_creature(t) -> void:
	var w := World.new()
	w.setup(446)
	_silence_food(w)
	_clear_terrain(w)
	w.terrain.water_pos.append(Vector2(1500.0, 1000.0))
	w.terrain.water_radius.append(200.0)
	w.swarm.pos[0] = Vector2(1200.0, 1000.0)
	w.critter_count = 0
	w.boss_index = -1
	w._write_critter(HORSE, Vector2(1500.0, 1000.0), 30)
	w.critter_dir[0] = Vector2.ZERO
	var at: Vector2 = w.critter_pos[0]
	w._step_critters(DT)
	var wet := w.critter_pos[0].distance_to(at)
	# 2.3 = HOST_SPEED 200 × SPECIES_SPEED_MUL[HORSE] 1.15 × WATER_SLOW 0.6 / 60.
	t.ok(absf(wet - 2.3) < 0.01, "물속의 말은 한 프레임에 2.3px만 간다 — 230 × 0.6 / 60 (리터럴) (%.4f)" % wet)

	var w2 := World.new()
	w2.setup(447)
	_silence_food(w2)
	_clear_terrain(w2)
	w2.swarm.pos[0] = Vector2(1200.0, 1000.0)
	w2.critter_count = 0
	w2.boss_index = -1
	w2._write_critter(HORSE, Vector2(1500.0, 1000.0), 30)
	w2.critter_dir[0] = Vector2.ZERO
	var at2: Vector2 = w2.critter_pos[0]
	w2._step_critters(DT)
	var dry := w2.critter_pos[0].distance_to(at2)
	t.ok(absf(dry - 3.8333) < 0.01,
			"대조: 마른 땅의 같은 말은 3.833px다 — 물이 실제로 잡은 것이다 (%.4f)" % dry)


# -- 26: the boss wanders, and then it comes -------------------------------------------------------------
## ⚠ **`elapsed` is written directly.** Stepping to 150s at 1/60 is 9,000 frames, and this check runs two.
##
## ⚠ **And `critter_dir` is pinned to a unit vector pointing AWAY from the host before the pre-boundary
## step.** "The distance did not fall" is seed luck — the wander re-rolls at `randf() < dt * 0.6` and a
## boss walking at 150px/s closes on the host by up to 150px in a second at random. What is asserted instead
## is that the boss travelled along the vector it was GIVEN, and that the vector was overwritten toward the
## host on the other side of the boundary.
func _c26_the_boss_starts_hunting(t) -> void:
	var w := _boss_alone(448)
	var host: Vector2 = w.swarm.pos[0]
	var b := w.boss_index
	w.critter_pos[b] = host + Vector2(500.0, 0.0)
	w.critter_dir[b] = Vector2.RIGHT
	w.elapsed = Rules.BOSS_HUNT_AT - 0.001
	w._step_critters(DT)
	t.ok(absf(w.critter_pos[b].x - (host.x + 502.5)) < 0.01,
			"경계 앞에서는 제가 들고 있던 방향으로 2.5px 간다 — 150 × dt (리터럴) (%.3f)"
					% (w.critter_pos[b].x - host.x))
	t.ok(w.critter_pos[b].distance_to(host) > 500.0, "그 방향은 호스트의 반대쪽이었다 — 아직 오지 않는다")

	w.critter_pos[b] = host + Vector2(500.0, 0.0)
	w.critter_dir[b] = Vector2.RIGHT
	w.elapsed = Rules.BOSS_HUNT_AT
	w._step_critters(DT)
	var to_host: Vector2 = (host - w.critter_pos[b]).normalized()
	t.ok(w.critter_dir[b].dot(to_host) > 0.999,
			"경계를 넘으면 방향이 호스트 쪽으로 덮어써진다 (%s)" % str(w.critter_dir[b]))
	t.ok(absf(w.critter_pos[b].distance_to(host) - 497.5) < 0.01,
			"그리고 같은 2.5px가 이번엔 거리를 줄인다 (%.3f)" % w.critter_pos[b].distance_to(host))


# -- U15: the boss's first 150 seconds --------------------------------------------------------------------
## **The whole first act was measured by nothing.** `_c26` above deliberately PINS `critter_dir` before it
## steps, because the wander is random — which leaves the wander itself untouched: `elif _rng.randf() <
## dt * 0.6:` → `dt * 0.0` is green, and replacing the re-rolled angle with a constant `Vector2.RIGHT` is
## green. The boss then stands stock still on its spawn point, or walks due east into the field edge and
## stops, for the whole first act — and the beat this stage is built on is "it is out there, it is on the
## map, and it moves."
##
## The seed is fixed, so the numbers below are deterministic; they are asserted as FLOORS rather than as
## literals because a draw inserted anywhere above shifts the stream and a literal count would break for a
## reason that is not this behaviour.
func _u15_the_boss_wanders_before_it_hunts(t) -> void:
	var w := _boss_alone(452)
	var b := w.boss_index
	t.ok(b >= 0, "설정: 보스가 있다")
	# Far apart in both directions: outside `_contact`, and far from every field edge so a clamp cannot be
	# what stops the walk.
	w.swarm.pos[0] = Vector2(200.0, 200.0)
	w.critter_pos[b] = Rules.FIELD * 0.5
	w.elapsed = 0.0
	var from: Vector2 = w.critter_pos[b]
	var dirs := {}
	var last: Vector2 = w.critter_dir[b]
	var changes := 0
	for _s in 900:
		w._step_critters(DT)
		dirs[str(w.critter_dir[b].round())] = true
		if w.critter_dir[b] != last:
			changes += 1
			last = w.critter_dir[b]
	t.ok(w.elapsed < Rules.BOSS_HUNT_AT,
			"설정: 15초를 걸었고 아직 사냥 시각(150초) 전이다 — 이것은 배회다")
	t.ok(changes >= 3,
			"15초 동안 보스는 방향을 세 번 넘게 바꾼다 — 한 번도 안 바꾸는 것이 초록이었다 (%d)" % changes)
	t.ok(dirs.size() >= 3,
			"그리고 그 방향들은 서로 다르다 — 늘 같은 각으로 다시 굴려도 초록이었다 (%d)" % dirs.size())
	var moved: float = w.critter_pos[b].distance_to(from)
	t.ok(moved > 200.0, "15초 뒤 보스는 출발점에서 200px 넘게 떠나 있다 (%.0f)" % moved)
	t.ok(w.critter_pos[b].distance_to(w.swarm.pos[0]) > 500.0,
			"대조: 그 걸음은 호스트를 향한 것이 아니다 — 사냥은 아직 시작되지 않았다 (%.0f)"
					% w.critter_pos[b].distance_to(w.swarm.pos[0]))


# -- U16a: the arena holds the whole body, not its centre -------------------------------------------------
## `arena_radius - r` → `arena_radius` is green, because `net_run`'s arena guard measures the host's CENTRE
## with `>`. The host's 14px body then hangs half outside the wall the run's last act is sealed inside.
func _u16a_the_arena_holds_the_whole_body(t) -> void:
	var g := Terrain.new()
	var centre := Vector2(1920.0, 1080.0)
	g.close_arena(centre)
	t.ok(g.arena_closed, "설정: 아레나가 닫혔다")
	t.eq(g.arena_radius, 900.0, "설정: 반지름은 900px다 (리터럴)")

	# A host shoved 2000px out. 900 - 14 = 886, hand-computed.
	var host := g.clamp_to_arena(centre + Vector2(2000.0, 0.0), Rules.BODY_RADIUS)
	t.ok(absf(host.distance_to(centre) - 886.0) < 0.01,
			"14px짜리 호스트는 중심에서 886px에 멈춘다 — 900이 아니다 (%.2f)" % host.distance_to(centre))
	t.ok(host.distance_to(centre) + Rules.BODY_RADIUS <= 900.0 + 0.01,
			"그래서 몸 전체가 벽 안이다 — 중심만 재면 몸의 절반이 벽 밖으로 나간다")

	# The boss is 48px, so the same wall holds it 852 out. Two radii, or `- r` could be a constant 14.
	var boss := g.clamp_to_arena(centre + Vector2(2000.0, 0.0), 48.0)
	t.ok(absf(boss.distance_to(centre) - 852.0) < 0.01,
			"48px짜리 보스는 852px에 멈춘다 — 빼는 값은 상수가 아니라 그 몸의 반지름이다 (%.2f)"
					% boss.distance_to(centre))
	t.ok(boss.distance_to(centre) < host.distance_to(centre),
			"큰 몸일수록 더 안쪽에서 멈춘다")
	# A body already inside is not moved, and the open arena is the identity — both are what let every
	# caller run this unconditionally.
	var inside := centre + Vector2(100.0, 0.0)
	t.eq(g.clamp_to_arena(inside, Rules.BODY_RADIUS), inside, "안에 있는 몸은 건드리지 않는다")
	var open := Terrain.new()
	t.eq(open.clamp_to_arena(inside, Rules.BODY_RADIUS), inside, "열린 아레나에서는 아무것도 안 한다")


# -- T2: a split child is placed OUTSIDE a rock ----------------------------------------------------------
## The host is written straight onto the rock's centre, so **every** point on the 20px spawn ring is inside
## it — the child's landing spot cannot depend on which way the ring angle rolled.
func _t2_a_split_child_is_outside(t) -> void:
	var ground := Terrain.new()
	ground.rock_pos.append(Vector2(1500.0, 1000.0))
	ground.rock_radius.append(100.0)
	var sw := Swarm.new()
	sw.setup(449, Vector2(1500.0, 1000.0))
	sw.terrain = ground
	sw.pos[0] = Vector2(1500.0, 1000.0)
	t.ok(Rules.CLONE_SPAWN_RING < 100.0,
			"설정: 태어나는 고리(20px)는 바위 반지름 100px보다 안쪽이다 — 어느 각도로 굴려도 바위 속이다")
	var c := sw.add_clone(0, 4)
	t.eq(c, 1, "설정: 아이가 실제로 태어났다")
	# 108 = the rock's 100 plus CLONE_BODY_RADIUS 8, by hand.
	t.ok(absf(sw.pos[c].distance_to(Vector2(1500.0, 1000.0)) - 108.0) < 0.01,
			"바위에 등을 대고 나눠도 아이는 바위 밖에 놓인다 — 100 + 8 = 108px (리터럴) (%.3f)"
					% sw.pos[c].distance_to(Vector2(1500.0, 1000.0)))


# -- T3: separation cannot shove a body into a rock ------------------------------------------------------
## Separation runs AFTER movement, so it is free to push a body straight back into a rock `push_out` had
## already cleared this frame — and nothing runs after it to undo that.
func _t3_separation_cannot_shove_into_a_rock(t) -> void:
	var ground := Terrain.new()
	var rock := Vector2(1500.0, 1000.0)
	ground.rock_pos.append(rock)
	ground.rock_radius.append(100.0)
	var sw := Swarm.new()
	sw.setup(450, Vector2(3000.0, 1000.0))
	sw.terrain = ground
	var a := sw.add_clone(0, 4)
	var b := sw.add_clone(0, 4)
	sw.pos[a] = Vector2(1608.0, 1000.0)
	sw.pos[b] = Vector2(1614.0, 1000.0)
	# STRIKE at a point both are already inside `rally_radius` of, so `_move_clone` steers nowhere and the
	# only thing that touches these two positions this frame is `_separate()`.
	sw.command_strike(Vector2(1611.0, 1000.0))
	t.ok(sw.pos[a].distance_to(sw.pos[b]) < Rules.SEPARATION_MIN,
			"설정: 두 분신이 서로 밀어낼 만큼 겹쳐 있다 (%.1f)" % sw.pos[a].distance_to(sw.pos[b]))
	t.ok(absf(sw.pos[a].distance_to(rock) - 108.0) < 0.01,
			"설정: 안쪽 분신은 바위에 딱 붙어 서 있다 (%.2f)" % sw.pos[a].distance_to(rock))
	sw.step(DT, null)
	t.ok(sw.pos[a].distance_to(rock) >= 107.99,
			"밀려난 분신도 바위 밖이다 — 떼어놓기가 몸을 바위 속으로 밀어넣지 못한다 (%.3f)"
					% sw.pos[a].distance_to(rock))
	t.ok(sw.pos[b].distance_to(rock) >= 107.99, "다른 쪽도 마찬가지다 (%.3f)" % sw.pos[b].distance_to(rock))
	t.ok(sw.pos[a].distance_to(sw.pos[b]) > 6.0, "설정: 그리고 둘은 실제로 벌어졌다 (%.2f)"
			% sw.pos[a].distance_to(sw.pos[b]))


# -- T8: a body wedged between two rocks gets OUT, and does not settle inside one ------------------------
## **The rule this check exists for: `push_out` never returns a point inside a rock.** Shoving a body clear
## of one rock at a time cannot hold that. On the axis between two rocks whose seam is narrower than the
## body is wide, each rock puts it back inside the other — a FIXED POINT, so the body ends the frame inside
## a rock and stays there for the rest of the run. No number of passes fixes it, because there is no point
## on that axis outside both. The way out is sideways, to the corner of the seam.
##
## ⚠ **Widening `_overlaps_rock` at generation does NOT close this**, which is why the fix is in `push_out`.
## A rejection of `d < r1 + r2 + 2 * BODY_RADIUS` guarantees a 28px seam — enough for the host (14) and a
## clone (8) and **not** enough for a creature: case (c) below is a maxed crow, radius 18, wedged in exactly
## that 28px seam. Creatures run through the same `push_out`, up to the boss's 72.
##
## ⚠ **Every coordinate here is literal and every expected distance is computed by hand**, never read back
## off `rock_radius[j] + r`. The escape points are the intersections of the two inflated circles:
## `sqrt(114² − 105²) = 44.396` for (a)/(b) and `sqrt(58² − 54²) = 21.166` for (c).
func _t8_a_wedged_body_gets_out(t) -> void:
	# (a) The seam is 10px and the body is 28px across. Dead on the axis, which is where the rock-by-rock
	# push had a true fixed point, and the symmetry makes both corners equally near — the side is not
	# asserted here, only that the body left the seam.
	var g := Terrain.new()
	g.rock_pos.append(Vector2(1000.0, 1000.0))
	g.rock_radius.append(100.0)
	g.rock_pos.append(Vector2(1000.0, 1210.0))
	g.rock_radius.append(100.0)
	var out := g.push_out(Vector2(1000.0, 1105.0), Rules.BODY_RADIUS)
	t.ok(out.distance_to(Vector2(1000.0, 1000.0)) >= 113.99,
			"10px 틈에 낀 몸은 위쪽 바위 밖으로 나온다 — 100 + 14 = 114px (리터럴) (%.3f)"
					% out.distance_to(Vector2(1000.0, 1000.0)))
	t.ok(out.distance_to(Vector2(1000.0, 1210.0)) >= 113.99,
			"그리고 아래쪽 바위 밖이기도 하다 — 두 바위를 동시에 만족한다 (%.3f)"
					% out.distance_to(Vector2(1000.0, 1210.0)))
	t.ok(absf(absf(out.x - 1000.0) - 44.396) < 0.01 and absf(out.y - 1105.0) < 0.01,
			"나온 자리는 두 원의 교점이다 — 축을 따라서가 아니라 틈의 옆구리로 나온다 (%.3f, %.3f)"
					% [out.x, out.y])

	# Dead on the axis both corners are exactly as near, so the tie-break is a coin toss — and it has to be
	# the SAME toss every call, or a body sitting in the seam flickers from one side to the other forever.
	t.ok(g.push_out(Vector2(1000.0, 1105.0), Rules.BODY_RADIUS) == out,
			"같은 자리를 두 번 물으면 같은 답이 나온다 — 대칭인 틈에서 좌우로 떨지 않는다")
	# ⚠ **The side IS asserted after all, and measuring it corrected `push_out`'s own comment.** That comment
	# says the strict `<` is what stops a symmetric seam flickering. Measured here: it is not. The candidate
	# list is `[push_off(a), crossings(a,b), push_off(b), crossings(b,a)]` and `crossings(b,a)` walks the same
	# two points back the other way, so the tied pair is a PALINDROME — the first equidistant candidate and
	# the last are the same point, and `if d < best_d:` → `<=` returns this exact coordinate either way.
	# What actually holds the seam still is that the order is fixed, which is what the two calls above check.
	t.ok(absf(out.x - 955.604) < 0.01 and absf(out.y - 1105.0) < 0.01,
			"그리고 그 답은 손으로 계산한 서쪽 교점이다 (955.604, 1105) — 후보 차례가 고정이라는 뜻이다 (%.3f, %.3f)"
					% [out.x, out.y])

	# (b) The same seam, 10px off the axis. Not a fixed point — a rock-by-rock push crawls outward a couple
	# of pixels a sweep — but it is still inside a rock at the end of the frame, which is the frame the
	# contract is broken in. The side IS asserted here: the near corner is the +x one.
	var out2 := g.push_out(Vector2(1010.0, 1105.0), Rules.BODY_RADIUS)
	t.ok(absf(out2.x - 1044.396) < 0.01 and absf(out2.y - 1105.0) < 0.01,
			"축에서 10px 벗어나 낀 몸은 가까운 쪽 교점으로 나온다 (1044.396, 1105) (%.3f, %.3f)"
					% [out2.x, out2.y])

	# (b2) The MIRROR of (b), and it is not padding: with only one side pinned, "the nearest crossing" and
	# "the last crossing tried" are the same point and the choice is unmeasured. Both sides pin it.
	var out2b := g.push_out(Vector2(990.0, 1105.0), Rules.BODY_RADIUS)
	t.ok(absf(out2b.x - 955.604) < 0.01 and absf(out2b.y - 1105.0) < 0.01,
			"반대쪽으로 낀 몸은 반대쪽 교점으로 나온다 (955.604, 1105) — 가까운 쪽이지 마지막 쪽이 아니다 (%.3f, %.3f)"
					% [out2b.x, out2b.y])

	# (c) A maxed crow (radius 18) in a 28px seam — the case a generation-side clearance of `2 * BODY_RADIUS`
	# would leave open. 40 + 18 = 58 by hand.
	var g2 := Terrain.new()
	g2.rock_pos.append(Vector2(500.0, 500.0))
	g2.rock_radius.append(40.0)
	g2.rock_pos.append(Vector2(500.0, 608.0))
	g2.rock_radius.append(40.0)
	var out3 := g2.push_out(Vector2(500.0, 554.0), 18.0)
	t.ok(out3.distance_to(Vector2(500.0, 500.0)) >= 57.99,
			"28px 틈에 낀 반지름 18짜리 생물도 나온다 — 40 + 18 = 58px (리터럴) (%.3f)"
					% out3.distance_to(Vector2(500.0, 500.0)))
	t.ok(out3.distance_to(Vector2(500.0, 608.0)) >= 57.99,
			"두 번째 바위 밖이기도 하다 (%.3f)" % out3.distance_to(Vector2(500.0, 608.0)))
	t.ok(absf(absf(out3.x - 500.0) - 21.166) < 0.01 and absf(out3.y - 554.0) < 0.01,
			"그 교점도 손으로 계산한 자리다 (%.3f, %.3f)" % [out3.x, out3.y])

	# (d) The sideways jump must not fire when one rock is enough. A single rock still pushes to EXACTLY
	# touching, along the line out of its centre — a body that pops sideways off one rock is the fix
	# overreaching, and it would show as a body skittering along every wall it brushes.
	var g3 := Terrain.new()
	g3.rock_pos.append(Vector2(2000.0, 1000.0))
	g3.rock_radius.append(100.0)
	var out4 := g3.push_out(Vector2(2030.0, 1000.0), Rules.BODY_RADIUS)
	t.ok(out4.distance_to(Vector2(2114.0, 1000.0)) < 0.01,
			"바위 하나뿐이면 그대로 밀려 나온다 — (2114, 1000)에 딱 붙는다 (%.3f, %.3f)" % [out4.x, out4.y])
	# (e) And a body already outside is returned untouched, bit for bit. `push_out` is the identity off the
	# rocks, and every fixture in this repo that writes a coordinate by hand leans on that.
	var out5 := g3.push_out(Vector2(2500.0, 1000.0), Rules.BODY_RADIUS)
	t.ok(out5 == Vector2(2500.0, 1000.0), "바위 밖의 몸은 한 픽셀도 움직이지 않는다 (%.3f, %.3f)"
			% [out5.x, out5.y])

	# (f) The same rule against the REAL ground, because (a)–(c) each hand it two rocks and a corner is only
	# ever computed from a PAIR — a corner that answers two walls and lands inside a THIRD is what forty
	# generated rocks can build and three hand-placed ones cannot. It is not hypothetical: an earlier fix
	# that solved only the two deepest rocks left a body 31.9px inside one here. Every pair of rocks with a
	# seam under 100px is squeezed at its midpoint by three bodies: the host, a maxed crow, and the boss.
	#
	# ⚠ **The wedge counter is not decoration.** Without it this is the loop-that-never-runs shape: a seed
	# block whose rocks all stand apart asserts nothing, and it is the seams narrower than the body that the
	# whole of T8 is about.
	var squeezed := 0
	var wedges := 0
	var worst_in := 0.0
	for n in 5:
		var g4 := Terrain.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 456 + n
		g4.setup(Rules.FIELD, Rules.FIELD * 0.5, rng)
		for j in g4.rock_pos.size():
			for k in range(j + 1, g4.rock_pos.size()):
				var gap: float = g4.rock_pos[j].distance_to(g4.rock_pos[k]) \
						- g4.rock_radius[j] - g4.rock_radius[k]
				if gap >= 100.0:
					continue
				var mid: Vector2 = (g4.rock_pos[j] + g4.rock_pos[k]) * 0.5
				for r in [Rules.BODY_RADIUS, 18.0, 48.0]:
					squeezed += 1
					if gap < 2.0 * float(r):
						wedges += 1
					var q: Vector2 = g4.push_out(mid, float(r))
					for m in g4.rock_pos.size():
						worst_in = maxf(worst_in,
								g4.rock_radius[m] + float(r) - q.distance_to(g4.rock_pos[m]))
	t.ok(squeezed >= 150, "설정: 다섯 판에서 좁은 틈을 %d번 눌러봤다" % squeezed)
	t.ok(wedges >= 80, "설정: 그중 %d번은 몸보다 좁은 틈이다 — 진짜 낀 자리를 잰다" % wedges)
	t.ok(worst_in <= 0.01,
			"실제 지형에서도 push_out은 바위 속의 자리를 돌려주지 않는다 (가장 깊이 %.4fpx)" % worst_in)


# -- T4: the run does not open wedged --------------------------------------------------------------------
## ⚠ **T5's floor is asserted first**, because an empty rock array satisfies this perfectly.
##
## ⚠ **And the clearance is a hand-written 400.0**, not `Rules.ROCK_CLEAR_DIST`. Read off the constant under
## test, the check shrinks with it: at 50 the run opens with a rock on the host's face and this stays green.
func _t4_the_opening_ground_is_clear(t) -> void:
	var fewest := INF
	var worst := INF
	for n in 10:
		var g := Terrain.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 451 + n
		g.setup(Rules.FIELD, Rules.FIELD * 0.5, rng)
		fewest = minf(fewest, float(g.rock_pos.size()))
		for j in g.rock_pos.size():
			worst = minf(worst, g.rock_pos[j].distance_to(Rules.FIELD * 0.5)
					- 400.0 - g.rock_radius[j])
	t.ok(fewest >= 30.0, "설정: 열 판 모두 바위가 서른 개 이상 놓였다 (%.0f)" % fewest)
	t.ok(worst >= 0.0,
			"열 판을 돌려도 시작 지점 400px 안에는 바위가 없다 — 런은 끼인 채로 열리지 않는다 (여유 %.1fpx)"
					% worst)


# -- T5: the ground is actually there --------------------------------------------------------------------
## ⚠ **A floor, not `== ROCK_COUNT`.** Rejection legitimately skips, so `rock_pos.size()` is seed-dependent
## and nothing may read it as the constant. Without this floor, T4 and `net_field`'s F3 are the
## loop-that-never-runs shape: both pass perfectly on an empty array.
func _t5_the_ground_is_actually_placed(t) -> void:
	var fewest_rock := INF
	var fewest_water := INF
	var paired := true
	for n in 10:
		var g := Terrain.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 451 + n
		g.setup(Rules.FIELD, Rules.FIELD * 0.5, rng)
		fewest_rock = minf(fewest_rock, float(g.rock_pos.size()))
		fewest_water = minf(fewest_water, float(g.water_pos.size()))
		if g.rock_radius.size() != g.rock_pos.size() or g.water_radius.size() != g.water_pos.size():
			paired = false
	t.ok(fewest_rock >= 30.0, "열 판 모두 바위가 서른 개 이상이다 (%.0f, 상한은 40)" % fewest_rock)
	t.ok(fewest_water >= 10.0, "그리고 물이 열 개 이상이다 (%.0f, 상한은 12)" % fewest_water)
	t.ok(paired, "자리와 반지름은 언제나 같은 개수다 — 한쪽만 append 되는 일이 없다")


# -- T7: one seed, one world, and the DRAW COUNT is part of it -------------------------------------------
## ⚠ **The literal is the point and the A/B is not.** "Two `World.setup(7)` calls agree" compares the same
## code with itself: change how many randoms one attempt draws and both sides shift together — measured, it
## stays green against exactly the mutation it is named for. What cannot move is the state of the shared
## generator AFTER the ground is placed, so that is what is pinned.
func _t7_one_seed_one_world(t) -> void:
	var g := Terrain.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	g.setup(Rules.FIELD, Rules.FIELD * 0.5, rng)
	t.ok(g.rock_pos.size() > 0 and g.water_pos.size() > 0, "설정: 씨앗 7에 땅이 실제로 놓였다")
	var next := rng.randf()
	t.ok(absf(next - 0.019367985) < 0.000001,
			"땅을 다 놓은 뒤 공유 난수의 다음 값은 0.019367985다 — 뽑는 횟수가 바뀌면 이 숫자가 움직인다 (%.9f)"
					% next)

	# The weaker companion: the same seed builds the same ground twice. It cannot see the draw-count
	# mutation above (both sides shift together) and it is kept only because a generator that were not
	# shared at all would still pass the literal.
	var a := World.new()
	a.setup(7)
	var b := World.new()
	b.setup(7)
	t.eq(a.terrain.rock_pos, b.terrain.rock_pos, "같은 씨앗은 같은 바위를 놓는다")
	t.eq(a.terrain.water_pos, b.terrain.water_pos, "같은 물도 놓는다")
	t.eq(a.critter_pos, b.critter_pos, "그리고 열두 마리를 같은 자리에 놓는다 — 난수는 하나다")


# -- fixtures ---------------------------------------------------------------------------------------------
## A world with nothing on it but the boss, on cleared ground with no food. Every other creature is removed
## backwards through `_remove_critter` so `boss_index` is repaired by the real code rather than by hand.
func _boss_alone(seed_value: int) -> World:
	var w := World.new()
	w.setup(seed_value)
	_silence_food(w)
	_clear_terrain(w)
	for k in range(w.critter_count - 1, -1, -1):
		if k != w.boss_index:
			w._remove_critter(k)
	return w


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
