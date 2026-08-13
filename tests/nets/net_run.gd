extends RefCounted
## The phase machine and the great absorption. `sim/` only — this file must never `load()` a view or
## shell file, so that a broken `hud.gd` (stage 3) cannot take these checks down with it.
##
## **Plan 1's own numbers-only checks.** The shell's rebinding, the screens' drawing, and the deleted
## clock are stage 2/3's — see the run shell plan's implementation section, stage 1 table.

const DT := 1.0 / 60.0


func run(t) -> void:
	# -- 1: TITLE is the start, and it holds no world ----------------
	var r := Run.new()
	t.eq(r.phase, Run.Phase.TITLE, "Run은 TITLE로 시작한다")
	t.eq(r.world, null, "TITLE에서는 world가 없다")

	# -- 2: start() opens PLAY with a real swarm ----------------------
	r.start(1)
	t.eq(r.phase, Run.Phase.PLAY, "start()는 PLAY로 넘어간다")
	t.ok(r.world != null, "start() 후 world가 생긴다")
	# The literal 7, not `1 + Rules.START_CLONES` — a bound read out of the thing it measures passes at
	# any value, and "the swarm started at zero" is the bug that walked through 102 green checks once.
	t.eq(r.world.swarm.count, 7, "무리는 호스트+6으로 시작한다")

	# -- 3: start() twice makes two different Worlds ------------------
	var w1 := r.world
	r.start(2)
	t.ok(r.world != w1, "start()를 두 번 하면 서로 다른 World다")

	# -- 4: dying ends the run in one step -----------------------------
	var r4 := Run.new()
	r4.start(3)
	r4.world.host_hp = 0
	r4.step(DT)
	t.eq(r4.phase, Run.Phase.ENDING, "체력이 0이면 한 스텝만에 ENDING")
	t.eq(r4.outcome, Run.Outcome.DIED, "죽음으로 끝난다")

	# -- 5: clearing does not flip the phase until the beat finishes --
	var r5 := Run.new()
	r5.start(4)
	# The beat now ends the instant every body has arrived (Swarm._absorb() removes each on arrival,
	# Run.step() checks swarm.count<=1), not at a fixed CLEAR_ABSORB_TIME — so "still PLAY at half the
	# beat" needs a swarm that genuinely takes that long to converge. Left at their spawn positions (each
	# exactly ABSORB_RADIUS from the host), the six default clones arrive within a frame or two and this
	# check would read ENDING at the half-beat mark for a reason that is not the phase machine.
	for i in range(1, r5.world.swarm.count):
		r5.world.swarm.pos[i] = r5.world.swarm.pos[0] + Vector2(700.0, 0.0)
	r5.world.stage_cleared = true
	r5.step(DT)
	t.eq(r5.phase, Run.Phase.PLAY, "클리어를 감지한 바로 그 스텝도 아직 PLAY다")
	var half5 := Rules.CLEAR_ABSORB_TIME * 0.5
	var elapsed5 := 0.0
	while elapsed5 < half5:
		r5.step(DT)
		elapsed5 += DT
	t.eq(r5.phase, Run.Phase.PLAY, "흡수 절반 지점에서도 아직 PLAY다")
	var ticks5 := 0
	while r5.phase == Run.Phase.PLAY and ticks5 < 300:
		r5.step(DT)
		ticks5 += 1
	t.eq(r5.phase, Run.Phase.ENDING, "흡수가 끝나면 ENDING이다")
	t.eq(r5.outcome, Run.Outcome.CLEARED, "클리어로 끝난다")

	# -- 5b: the beat ends the instant everyone has arrived, not at a fixed CLEAR_ABSORB_TIME -----------
	# verify-look measured the bug this replaces: most of a 40-body swarm converges well inside the beat's
	# own timer and then sits motionless for whatever is left of it. A swarm placed close enough to arrive
	# in a handful of frames must not still be waiting out the full 72-frame timer.
	var r5b := Run.new()
	r5b.start(26)
	for i in range(1, r5b.world.swarm.count):
		r5b.world.swarm.pos[i] = r5b.world.swarm.pos[0] + Vector2(100.0, 0.0)   ## arrives in ~7 frames
	r5b.world.stage_cleared = true
	r5b.step(DT)
	var ticks5b := 0
	while r5b.phase == Run.Phase.PLAY and ticks5b < 300:
		r5b.step(DT)
		ticks5b += 1
	t.ok(ticks5b < 30, "다 모여 있으면 박동이 정해진 시간을 다 채우지 않고 일찍 끝난다 (%d틱)" % ticks5b)
	t.eq(r5b.phase, Run.Phase.ENDING, "그리고 실제로 ENDING에 도달한다")

	# -- 6: the beat banks without eating, actually pulls, and actually removes the bodies ----------
	var r6 := Run.new()
	r6.start(5)
	_silence_food(r6.world)
	r6.world.critter_count = 0
	var c6 := r6.world.swarm.add_clone()
	r6.world.swarm.carried[c6] = 9.0
	# Far enough that CLEAR_ABSORB_PULL never closes the gap inside CLEAR_ABSORB_TIME (900 * 1.2 = 1080px):
	# the clone must still be carrying its 9.0 when the beat ends, or _finish_clear()'s forced bank never
	# actually runs on it — the natural in-flight _absorb() would have already zeroed it, and the mutation
	# this check exists to catch has nothing left to act on.
	r6.world.swarm.pos[c6] = r6.world.swarm.pos[0] + Vector2(1500.0, 0.0)
	var eaten_before6: float = r6.world.swarm.eaten
	var banked_before6: float = r6.world.swarm.banked
	r6.world.stage_cleared = true
	r6.step(DT)
	# `Run._begin_clear()` setting `swarm.clear_pull = true` is not implied by anything above: banked
	# rising by exactly 9.0 at the end holds even if the clone never moves at all, since `_finish_clear()`
	# force-removes and force-banks every remaining body regardless of where it stands. This is the only
	# check that actually looks at the wire between `Run` and `Swarm` for the pull.
	t.ok(r6.world.swarm.clear_pull, "박동이 시작되면 clear_pull이 켜진다")
	var ticks6 := 0
	while r6.phase == Run.Phase.PLAY and ticks6 < 300:
		r6.step(DT)
		ticks6 += 1
	t.ok(absf(r6.world.swarm.banked - (banked_before6 + 9.0)) < 0.01,
			"흡수 절차가 실은 것만큼만 은행에 넣는다")
	t.eq(r6.world.swarm.eaten, eaten_before6, "흡수 절차는 먹은 총량을 건드리지 않는다")
	t.ok(not r6.world.swarm.clear_pull, "박동이 끝나면 clear_pull이 꺼진다")
	# "On clearing, the whole swarm is absorbed — bodies included" (design). Not just c6: every clone,
	# loaded or not, is removed. Only the host (row 0) survives.
	t.eq(r6.world.swarm.count, 1, "박동이 끝나면 무리 전체가 실제로 제거된다 (흡수는 숫자만이 아니다)")

	# -- 7: a clone that dies in the field still counted what it ate --
	var r7 := Run.new()
	r7.start(6)
	_silence_food(r7.world)
	r7.world.critter_count = 0
	var c7 := r7.world.swarm.add_clone()
	r7.world.swarm.eat(c7, 5.0)
	r7.world.swarm.pos[c7] = r7.world.swarm.pos[0] + Vector2(600.0, 0.0)
	r7.world.critter_count = 1
	r7.world.critter_pos[0] = r7.world.swarm.pos[c7]
	r7.world.critter_threat[0] = 5
	r7.world.critter_dir[0] = Vector2.ZERO
	r7.world.step(DT)   ## the critter kills the loaded clone; too small a swarm to have outgrown threat 5
	r7.world.host_hp = 0
	r7.step(DT)
	t.eq(r7.phase, Run.Phase.ENDING, "죽음으로 런이 끝난다")
	t.eq(r7.result.experience, 5, "밖에서 죽은 분신이 먹은 것도 경험치에 남는다")
	t.eq(r7.world.swarm.banked, 0.0, "그 경험치는 은행에는 들어오지 않았다")

	# -- 8: _absorb() never raises eaten -------------------------------
	var r8 := Run.new()
	r8.start(7)
	_silence_food(r8.world)
	r8.world.critter_count = 0
	var c8 := r8.world.swarm.add_clone()
	r8.world.swarm.carried[c8] = 4.0
	r8.world.swarm.pos[c8] = r8.world.swarm.pos[0] + Vector2(Rules.ABSORB_RADIUS - 2.0, 0.0)
	r8.world.swarm.command_rally(r8.world.swarm.pos[0])
	var eaten_before8: float = r8.world.swarm.eaten
	var banked_before8: float = r8.world.swarm.banked
	r8.world.step(DT)
	t.ok(r8.world.swarm.banked > banked_before8, "몸으로 돌아온 화물은 은행에 들어온다")
	t.eq(r8.world.swarm.eaten, eaten_before8, "_absorb()는 먹은 총량을 올리지 않는다")

	# -- 9: to_title() drops the world, keeps the result ---------------
	var r9 := Run.new()
	r9.start(8)
	r9.world.host_hp = 0
	r9.step(DT)
	r9.to_title()
	t.eq(r9.phase, Run.Phase.TITLE, "to_title()는 TITLE로 돌아간다")
	t.eq(r9.world, null, "TITLE에서는 world를 버린다")
	t.ok(r9.result != null, "result는 여전히 읽을 수 있다")

	# -- 10: restart() skips TITLE and opens a new World ---------------
	var r10 := Run.new()
	r10.start(9)
	r10.world.host_hp = 0
	r10.step(DT)
	r10.paused = true   ## a pause carried from the ended run must not freeze the next one (plan 2's Tab)
	var ended_world10 := r10.world
	r10.restart(10)
	t.eq(r10.phase, Run.Phase.PLAY, "restart()는 PLAY로 넘어간다")
	t.ok(r10.world != null, "restart() 후 world가 있다")
	t.ok(r10.world != ended_world10, "restart()는 새 World다")
	t.ok(not r10.paused, "restart()는 이전 런의 정지 상태를 물려받지 않는다")

	# -- 16: the beat pulls, at the pull's own speed --------------------
	var sw16 := Swarm.new()
	sw16.setup(11, Vector2(2000.0, 1080.0))
	for _i in 20:
		sw16.add_clone()
	# Radii vary (400..750) rather than sharing one ring, so the pack does not arrive in lockstep — a
	# clone at max speed overshoots the host by up to one frame's travel once it is inside that distance
	# (the pull has no arrival deceleration, same as the rest of this file's movement), and twenty clones
	# bouncing in unison would swing the MEAN past "never increases" for a reason that is not the bug.
	# The window below stays short enough that nothing has arrived yet.
	for i in range(1, sw16.count):
		var a := float(i) * 0.31
		sw16.pos[i] = sw16.pos[0] + Vector2(cos(a), sin(a)) * (400.0 + float(i) * 18.0)
	# `rally` defaults to the host's own start position, so with it untouched the pull branch and
	# ordinary FOLLOW steer at the exact same point — deleting the whole `if clear_pull:` branch in
	# _move_clone survives this check unless `rally` is somewhere else. Sending it 1200px off host makes
	# the two branches produce opposite motion: FOLLOW would walk the pack AWAY from the host, not toward
	# it, so a dead pull branch is now visible as the mean distance rising instead of falling.
	sw16.command_rally(sw16.pos[0] + Vector2(1200.0, 0.0))
	sw16.clear_pull = true
	var start16 := _mean_dist_to_host(sw16)
	var prev16 := start16
	var non_increasing16 := true
	var after10_16 := 0.0
	# 400 / CLEAR_ABSORB_PULL = 0.444s to the nearest clone's arrival. 18 frames stays well inside that.
	for frame16 in range(1, 19):
		sw16.step(DT, null)
		var cur16 := _mean_dist_to_host(sw16)
		if cur16 > prev16 + 0.5:
			non_increasing16 = false
		prev16 = cur16
		if frame16 == 10:
			after10_16 = cur16
	t.ok(non_increasing16, "흡수 박동 동안 평균 거리가 매 프레임 늘어나지 않는다")
	t.ok(start16 - after10_16 > 100.0,
			"흡수 당김이 900px/s에 맞는 속도로 줄어든다 (%.1f)" % (start16 - after10_16))

	# -- 16a2: the picture keeps changing for the whole beat, not one jump to 1 -------------------------
	# A still frame followed by a single collapse to 1 satisfies "the beat ends eventually" while looking
	# exactly like the bug this file exists to catch — every body vanishing in ONE batch at the end
	# instead of continuously as each one individually arrives. Ten clones at staggered distances; the
	# swarm's count is sampled every frame, and it has to strictly drop across several distinct frames,
	# not sit flat for a stretch and then fall once.
	var sw16a2 := Swarm.new()
	sw16a2.setup(14, Vector2(2000.0, 1080.0))
	for k in 10:
		var c16a2 := sw16a2.add_clone()
		var a16a2 := float(k) * 1.7
		sw16a2.pos[c16a2] = sw16a2.pos[0] + Vector2(cos(a16a2), sin(a16a2)) * (80.0 + float(k) * 70.0)
	sw16a2.clear_pull = true
	var drops16a2 := 0
	var prev_count16a2 := sw16a2.count
	for _f in int(Rules.CLEAR_ABSORB_TIME / DT):
		sw16a2.step(DT, null)
		if sw16a2.count < prev_count16a2:
			drops16a2 += 1
		prev_count16a2 = sw16a2.count
	t.ok(drops16a2 >= 3, "무리가 한 번에 아니라 여러 프레임에 걸쳐 하나씩 사라진다 (%d번 줄었다)" % drops16a2)

	# -- 16b: arrival does not overshoot the host ------------------------------------------------------
	# A single clone, close enough to arrive partway through the beat. Nothing above catches this on its
	# own: check 16's window ends before any of its 20 clones gets within a frame's travel of the host, so
	# reverting `to.limit_length(speed * dt) / dt` back to the plain `to.normalized() * speed` it replaced
	# leaves every check above green. One clone in isolation, watched every frame of the FULL beat, so a
	# lockstep pile-up of many clones arriving together cannot mask a real regression either way.
	var sw16b := Swarm.new()
	sw16b.setup(13, Vector2(2000.0, 1080.0))
	var only16b := sw16b.add_clone()
	sw16b.pos[only16b] = sw16b.pos[0] + Vector2(50.0, 0.0)   ## 50px, well inside the beat at 900px/s
	sw16b.clear_pull = true
	var prev16b := sw16b.pos[only16b].distance_to(sw16b.pos[0])
	var overshot16b := false
	var arrived16b := false
	for _f in int(Rules.CLEAR_ABSORB_TIME / DT):
		if sw16b.count <= 1:
			# Arrival now removes the body outright (see Swarm._absorb()'s header) — reading `pos[only16b]`
			# after that would read whatever `remove_at()` swapped into that row, not "the clone stopped
			# here". Stop measuring the instant there is nothing left to measure.
			arrived16b = true
			break
		sw16b.step(DT, null)
		if sw16b.count <= 1:
			arrived16b = true
			break
		var cur16b := sw16b.pos[only16b].distance_to(sw16b.pos[0])
		if cur16b > prev16b + 0.01:
			overshot16b = true
		prev16b = cur16b
	t.ok(not overshot16b, "도착이 호스트를 지나쳐 튕기지 않는다 (감속이 걸린다)")
	t.ok(arrived16b, "도착하면 무리에서 실제로 사라진다 (자리에 멈춰 있지 않는다)")

	# -- 17: _separate is off during the beat ---------------------------
	var sw17 := Swarm.new()
	sw17.setup(12, Vector2(3800.0, 2100.0))
	var a17 := sw17.add_clone()
	var b17 := sw17.add_clone()
	sw17.pos[a17] = Vector2(100.0, 100.0)
	sw17.pos[b17] = Vector2(102.0, 100.0)
	sw17.clear_pull = true
	sw17.step(DT, null)
	t.ok(sw17.pos[a17].distance_to(sw17.pos[b17]) < 10.0,
			"박동 중에는 분리가 꺼져 가까운 두 분신이 떨어지지 않는다")

	# -- 18: the outcome latches -----------------------------------------
	var r18 := Run.new()
	r18.start(14)
	_silence_food(r18.world)
	r18.world.critter_count = 0
	r18.world.stage_cleared = true
	r18.step(DT)
	t.eq(r18.phase, Run.Phase.PLAY, "감지 직후에는 아직 PLAY다")
	r18.world.host_hp = 0   ## a hit lands mid-beat
	var ticks18 := 0
	while r18.phase == Run.Phase.PLAY and ticks18 < 300:
		r18.step(DT)
		ticks18 += 1
	t.eq(r18.phase, Run.Phase.ENDING, "박동이 끝나면 ENDING이다")
	t.eq(r18.outcome, Run.Outcome.CLEARED, "박동 중 죽어도 결과는 CLEARED로 고정된다")

	# -- 19: a level earned during the beat opens no cards ----------------------------------------
	# Two different mechanisms, and each needs its own bait or the mutation it belongs to has nothing to
	# act on (the same trap check 6 and check 8's setups fell into):
	#  (a) a level already PENDING the instant _begin_clear() runs. Setting stage_cleared directly and
	#      stepping once (as checks 5/6/18 do) never produces that on its own. The real shape is a
	#      max-threat critter eaten by the host: World::_contact() banks it and sets stage_cleared in the
	#      same world.step(), and _grow() (still unfrozen — Run has not seen stage_cleared yet) queues the
	#      level before Run gets a turn. `pending_levels = 0` is what drops it.
	#      ⚠ This is NOT about the beat hanging — `Run.step()` decrements `absorb_beat` unconditionally
	#      every frame, so the beat always ends on schedule whether or not `World::step()`'s own
	#      `pending_levels > 0` guard is stuck. Skipping the zero just leaves a stale pending_levels
	#      sitting there when the beat ends, which is exactly what this check reads
	#  (b) a level that would be EARNED mid-beat, as a clone's cargo is naturally absorbed on the way
	#      home — `beat_frozen` is what has to hold that off, and nothing about (a) exercises it, since
	#      _grow() only runs once more that same frame and has nothing left to cross
	var r19 := Run.new()
	r19.start(15)
	_silence_food(r19.world)
	for _i in 20:
		r19.world.swarm.add_clone()   # count 27, clears is_hunter_of's 25-clone threshold
	r19.world.swarm.banked = Rules.SPLIT_PER_BANKED - 1.0   # (a): one bite from a level, not there yet
	var c19 := r19.world.swarm.add_clone()   # (b): its cargo crosses a FURTHER threshold once absorbed
	r19.world.swarm.carried[c19] = Rules.SPLIT_PER_BANKED + 5.0
	r19.world.swarm.pos[c19] = r19.world.swarm.pos[0] + Vector2(400.0, 0.0)   ## absorbed mid-beat, not at detection
	r19.world.critter_count = 1
	r19.world.critter_pos[0] = r19.world.swarm.pos[0]
	r19.world.critter_threat[0] = Rules.CRITTER_THREAT_MAX
	r19.world.critter_dir[0] = Vector2.ZERO
	r19.step(DT)   # host eats it: banked crosses a level AND stage_cleared flips, same world.step()
	t.ok(r19.world.stage_cleared, "이 스텝에서 클리어가 감지됐다 (설정이 의도대로 맞았는지)")
	var ticks19 := 0
	while r19.phase == Run.Phase.PLAY and ticks19 < 300:
		r19.step(DT)
		ticks19 += 1
	t.eq(r19.phase, Run.Phase.ENDING, "박동이 실제로 끝까지 진행됐다")
	t.eq(r19.world.pending_levels, 0, "박동 중 감지 시점이든 도중이든 번 레벨은 카드를 열지 않는다")

	# -- 20a: restart() twice makes two different Worlds -----------------
	var r20 := Run.new()
	r20.start(16)
	r20.world.host_hp = 0
	r20.step(DT)
	r20.restart(17)
	var w1_20 := r20.world
	r20.world.host_hp = 0
	r20.step(DT)
	r20.restart(18)
	t.ok(r20.world != w1_20, "restart()를 두 번 하면 서로 다른 World다")

	# -- 22: paused is the one flag, and it can be cleared ----------------
	var r22 := Run.new()
	r22.start(19)
	var before22 := r22.world.elapsed
	r22.paused = true
	r22.step(DT)
	t.eq(r22.world.elapsed, before22, "paused면 world가 멈춘다")
	r22.paused = false
	r22.step(DT)
	t.ok(r22.world.elapsed > before22, "paused를 풀면 다시 흐른다")

	# -- 23: _snapshot() actually runs on the CLEARED path, not just DIED ------------------------------
	# Check 7 already pins `result.experience` after a DIED ending. Nothing above reads `result` at all
	# after a CLEARED one — `_begin_clear()`'s own `_snapshot()` call could be replaced with `pass` and
	# every check to this point would stay green, because they all read `world`/`swarm` directly, never
	# `result`. `RunResult`'s default `outcome` is NONE, so that field alone catches a snapshot that never
	# ran; the rest confirm it is not a stale copy from a previous run either.
	var r23 := Run.new()
	r23.start(20)
	_silence_food(r23.world)
	r23.world.critter_count = 0
	r23.world.swarm.eat(0, 42.0)
	r23.world.stage_cleared = true
	r23.step(DT)
	var elapsed_at_detect23: float = r23.world.elapsed   ## the beat itself must not count toward this
	var ticks23 := 0
	while r23.phase == Run.Phase.PLAY and ticks23 < 300:
		r23.step(DT)
		ticks23 += 1
	t.eq(r23.phase, Run.Phase.ENDING, "박동이 끝까지 진행됐다 (설정 확인)")
	t.eq(r23.result.outcome, Run.Outcome.CLEARED, "클리어에도 result가 실제로 채워진다")
	t.ok(r23.result.elapsed > 0.0, "클리어한 result에 걸린 시간이 담긴다")
	# A second _snapshot() call added inside _finish_clear() would re-stamp elapsed AFTER the beat and
	# stay green against `> 0.0` alone — the beat adds CLEAR_ABSORB_TIME to world.elapsed by the time the
	# loop above exits, so only a value pinned to the DETECTION-time reading catches that.
	t.ok(absf(r23.result.elapsed - elapsed_at_detect23) < 0.001,
			"클리어한 result의 걸린 시간은 박동이 아니라 감지 시점에 찍힌다")
	t.eq(r23.result.experience, 42, "클리어한 result에 먹은 경험치가 담긴다")

	# -- 24: RunResult's remaining fields — elapsed, peak_swarm, clones_lost, cargo_lost -----------------
	# Check 7 only ever reads `result.experience`. The other four fields in the struct have no check
	# anywhere in this stage, in stage 2 (which feeds its net a hand-built RunResult), or in stage 3 —
	# `_snapshot()` could drop any of them to a hardcoded 0 and nothing would notice. Each value below is
	# driven through World's own bookkeeping (not asserted against a copy of the same field) so a mutation
	# has to break the actual wiring, not just a parallel constant.
	var r24 := Run.new()
	r24.start(21)
	_silence_food(r24.world)
	r24.world.critter_count = 0
	for _s in 30:
		r24.step(DT)
	var elapsed_before24: float = r24.world.elapsed
	t.ok(elapsed_before24 > 0.0, "설정: 시간이 흘렀다")
	for _i in 5:
		r24.world.swarm.add_clone()
	r24.world.step(DT)   ## lets World's own peak_swarm bookkeeping register the new high-water mark
	var peak_before24: int = r24.world.peak_swarm
	t.eq(peak_before24, 11, "설정: 최대 무리가 실제로 갱신됐다 (host+11)")
	var cc24 := r24.world.swarm.add_clone()
	r24.world.swarm.carried[cc24] = 7.0
	r24.world.swarm.pos[cc24] = r24.world.swarm.pos[0] + Vector2(600.0, 0.0)
	r24.world.critter_count = 1
	r24.world.critter_pos[0] = r24.world.swarm.pos[cc24]
	r24.world.critter_threat[0] = 5
	r24.world.critter_dir[0] = Vector2.ZERO
	r24.world.step(DT)   ## a threat-5 critter against a 12-clone swarm still hunts (12 < 5*5); kills cc24
	t.eq(r24.world.clones_lost, 1, "설정: 분신 하나를 잃었다")
	t.eq(roundi(r24.world.cargo_lost), 7, "설정: 화물 7을 함께 잃었다")
	r24.world.host_hp = 0
	r24.step(DT)
	t.eq(r24.phase, Run.Phase.ENDING, "죽음으로 런이 끝난다")
	t.ok(r24.result.elapsed >= elapsed_before24, "result에 실제로 흐른 시간이 담긴다")
	t.eq(r24.result.peak_swarm, peak_before24, "result에 최대 무리 값이 담긴다")
	t.eq(r24.result.clones_lost, 1, "result에 잃은 분신 수가 담긴다")
	t.eq(r24.result.cargo_lost, 7, "result에 잃은 화물이 담긴다")

	# -- 25: stage_cleared fires only at the maximum threat, never below --------------------------------
	# World::_contact()'s `if critter_threat[k] == Rules.CRITTER_THREAT_MAX` could be widened to
	# `>= Rules.CRITTER_THREAT_MIN` and every check above stays green — none of them ever eat a
	# below-maximum critter. Both directions have to be driven: a hunter swarm large enough for ANY
	# threat, fed a critter one below the max, then fed one exactly at the max.
	var w25a := World.new()
	w25a.setup(22)
	_silence_food(w25a)
	for _i in 20:
		w25a.swarm.add_clone()
	w25a.critter_count = 1
	w25a.critter_pos[0] = w25a.swarm.pos[0]
	w25a.critter_threat[0] = Rules.CRITTER_THREAT_MAX - 1
	w25a.critter_dir[0] = Vector2.ZERO
	w25a.step(DT)
	# Without this, the check passes vacuously if the critter was never eaten at all (SWARM_PER_THREAT
	# raised so is_hunter_of() is false, say) — "nothing happened" and "it happened but didn't clear" both
	# read as `not stage_cleared`. Confirming the eat actually landed is what tells them apart.
	t.eq(w25a.critters_eaten, 1, "설정: 최댓값보다 낮은 위협도 실제로 잡아먹었다")
	t.ok(not w25a.stage_cleared, "최댓값보다 낮은 위협을 잡아도 클리어로 세지 않는다")

	var w25b := World.new()
	w25b.setup(23)
	_silence_food(w25b)
	for _i in 20:
		w25b.swarm.add_clone()
	w25b.critter_count = 1
	w25b.critter_pos[0] = w25b.swarm.pos[0]
	w25b.critter_threat[0] = Rules.CRITTER_THREAT_MAX
	w25b.critter_dir[0] = Vector2.ZERO
	w25b.step(DT)
	t.ok(w25b.stage_cleared, "최댓값 위협을 잡으면 클리어로 센다")

	# -- 14: a run does not end on a clock, driven -----------------------------------------------------
	# Not "Rules has no RUN_LENGTH" — that measures a name's absence and passes against a hardcoded
	# 300.0 dropped straight into World::step(). Driven long past the old clock instead.
	#
	# **`elapsed` alone is not a late-enough witness.** It is the FIRST line of `World::step()`'s body,
	# so a stray early-return placed right after it — before swarm/food/critters/`_grow()` ever run —
	# would still leave `elapsed` climbing while the rest of the world sat frozen, and this check would
	# stay green measuring nothing. Measured: exactly that placement passed 62/62. `_next_critter -= dt`
	# sits near the END of the body instead, so it only moves if the WHOLE body ran.
	#
	# **`dt` is raised to 1.0 for this check only** (a local var, not the file's shared `DT`) — this check
	# reads `phase`/`elapsed`/`_next_critter`, never physics, and food/critters are already silenced, so
	# nothing here depends on a real 1/60 tick. 900 iterations at dt=1.0 reach the same 900 simulated
	# seconds as 54,000 iterations at 1/60 did, in a fraction of the time: this one check alone measured
	# 17s+ of an otherwise ~1s round, the exact shape `CLAUDE.md` names — a slow net is a net that stops
	# getting run.
	var r14 := Run.new()
	r14.start(24)
	_silence_food(r14.world)
	r14.world.critter_count = 0
	# Zeroing the count once is not enough — `_spawn_critter()` fires again every CRITTER_INTERVAL (45s)
	# regardless, and over 900 simulated seconds a spawned-and-forgotten critter reliably found the host
	# and ended the run in DIED at 114s, well before the clock this check exists to rule out. Pushed the
	# next spawn far past the whole test's horizon instead of trying to re-zero it every interval.
	r14.world._next_critter = 1e9
	var big_dt14 := 1.0
	var ticks14 := 0
	while ticks14 < 900:
		r14.step(big_dt14)
		ticks14 += 1
	t.eq(r14.phase, Run.Phase.PLAY, "900초를 몰아도 PLAY 그대로다")
	t.ok(r14.world.elapsed > 890.0, "그동안 세상의 시간도 실제로 흘렀다 (%.1f)" % r14.world.elapsed)
	t.ok(r14.world._next_critter < 1e9 - 890.0,
			"critter 타이머도 그만큼 줄었다 — elapsed 한 줄만이 아니라 몸통 전체가 돌았다 (%.1f)" % r14.world._next_critter)

	# -- the ecosystem freezes for the whole beat, not just at its edges --------------------------------
	# Without World::_step_critters() gated on beat_frozen, is_hunter_of() flips as swarm.count falls
	# every frame of the beat — a critter that read as prey a moment ago turns hunter again mid-victory
	# and can cost the host a heart while it is swallowing the boss. The outcome is latched (a hit
	# mid-beat cannot turn CLEARED into DIED), but the picture would still show the world going hostile
	# at the exact moment it was won.
	#
	# Measured as a PROCESS, not a final comparison: the critter's position and `host_hp` are asserted
	# unchanged on EVERY frame of the beat. A before/after-only check would pass even if the critter
	# chased, hit the host, and wandered back to exactly where it started by the time the beat ended.
	var rf := Run.new()
	rf.start(27)
	_silence_food(rf.world)
	# Scattered, so the beat actually takes more than a couple of frames — see check 5's identical note.
	for i in range(1, rf.world.swarm.count):
		rf.world.swarm.pos[i] = rf.world.swarm.pos[0] + Vector2(700.0, 0.0)
	# Placed close enough, and at max threat, that an unfrozen critter would land a hit on the very
	# first step: `swarm.count - 1` (6) is nowhere near `CRITTER_THREAT_MAX * SWARM_PER_THREAT` (25), so
	# is_hunter_of() reads false and this critter is the hunter, not the prey.
	rf.world.critter_count = 1
	rf.world.critter_pos[0] = rf.world.swarm.pos[0] + Vector2(30.0, 0.0)
	rf.world.critter_threat[0] = Rules.CRITTER_THREAT_MAX
	rf.world.critter_dir[0] = Vector2.ZERO
	rf.world.stage_cleared = true
	rf.step(DT)
	t.eq(rf.phase, Run.Phase.PLAY, "설정: 박동이 시작됐다")
	var critter_pos_before := rf.world.critter_pos[0]
	var hp_before := rf.world.host_hp
	var frozen_ok := true
	var ticksf := 0
	while rf.phase == Run.Phase.PLAY and ticksf < 300:
		rf.step(DT)
		if rf.world.critter_pos[0] != critter_pos_before or rf.world.host_hp != hp_before:
			frozen_ok = false
		ticksf += 1
	t.ok(ticksf > 5, "설정: 박동이 몇 프레임 만에 끝나지 않고 실제로 걸렸다 (%d틱)" % ticksf)
	t.ok(frozen_ok, "박동 내내 생물이 얼어붙어 있다 (위치·호스트 체력이 매 프레임 그대로다)")


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


func _mean_dist_to_host(sw: Swarm) -> float:
	var sum := 0.0
	for i in range(1, sw.count):
		sum += sw.pos[i].distance_to(sw.pos[0])
	return sum / float(sw.count - 1)
