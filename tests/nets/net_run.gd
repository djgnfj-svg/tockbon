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
	# The literal 1. It used to be 7 with a `START_CLONES` constant behind it — and the reason the number
	# is written out rather than derived has not changed: a bound read out of the thing it measures passes
	# at any value, and "the swarm started at zero" is the bug that walked through 102 green checks once.
	# The run opens with the host alone now, on purpose: no body exists that did not come from an `F`.
	t.eq(r.world.swarm.count, 1, "런은 호스트 하나로 시작한다")

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
	# The beat ends the instant every body has arrived (Swarm._clear_arrivals() removes each on arrival,
	# Run.step() checks swarm.count<=1), not at a fixed CLEAR_ABSORB_TIME — so "still PLAY at half the
	# beat" needs a swarm that genuinely takes that long to converge. A run opens with the host alone, so
	# the bodies are placed here; left anywhere near the host they arrive within a frame or two and this
	# check would read ENDING at the half-beat mark for a reason that is not the phase machine.
	for _i in 6:
		r5.world.swarm.add_clone()
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
	for _i in 6:
		r5b.world.swarm.add_clone()
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
	var c6 := r6.world.swarm.add_clone(0, 7)
	r6.world.swarm.carried[c6] = 9.0
	# Far enough that CLEAR_ABSORB_PULL never closes the gap inside CLEAR_ABSORB_TIME (900 * 1.2 = 1080px):
	# the clone must still be carrying its 9.0 when the beat ends, or _finish_clear()'s forced bank never
	# actually runs on it — an in-flight arrival (`_clear_arrivals()`) would have already zeroed it, and the mutation
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
	# **This clone never arrives** — it is 1500px out and the pull cannot close that inside the beat — so
	# it is `Run._finish_clear()`'s forced sweep, not `Swarm._clear_arrivals()`, that takes it. That is the
	# third of the three paths bringing a body home, and it was the one that dropped force on the floor
	# while `V` kept it: 10 + 7 with nothing to catch the difference. `net_force`'s clear-beat check pins
	# the arrival path; this pins the fallback.
	t.eq(r6.world.swarm.total_force(), 17,
			"끝까지 못 온 몸의 힘도 호스트에 남는다 (호스트 10 + 분신 7)")

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
	r7.world.critter_dir[0] = Vector2.ZERO
	r7.world.step(DT)   ## a creature is standing on the loaded clone
	r7.world.host_hp = 0
	r7.step(DT)
	t.eq(r7.phase, Run.Phase.ENDING, "죽음으로 런이 끝난다")
	t.eq(r7.result.experience, 5, "밖에서 죽은 분신이 먹은 것도 경험치에 남는다")
	t.eq(r7.world.swarm.banked, 0.0, "그 경험치는 은행에는 들어오지 않았다")

	# -- 8: cargo comes home on `V`, and `V` never raises eaten ---------
	# Two halves, and the first is the one that stopped being true this plan: standing on the host used to
	# empty a clone automatically. It does not any more — recall is a key the player presses, and the
	# whole tension of the build is that it can be forgotten.
	var r8 := Run.new()
	r8.start(7)
	_silence_food(r8.world)
	r8.world.critter_count = 0
	var c8 := r8.world.swarm.add_clone()
	r8.world.swarm.carried[c8] = 4.0
	r8.world.swarm.pos[c8] = r8.world.swarm.pos[0] + Vector2(Rules.ABSORB_RADIUS - 2.0, 0.0)
	r8.world.swarm.command_rally()
	var eaten_before8: float = r8.world.swarm.eaten
	var banked_before8: float = r8.world.swarm.banked
	for _s in 30:
		r8.world.step(DT)
	t.eq(r8.world.swarm.banked, banked_before8, "몸에 닿아 있어도 저절로 넘어오지 않는다")
	# Cargo was counted into `eaten` when it was picked up. Routed through `eat()` here it would be paid a
	# second time and walking a clone home would be worth double.
	t.eq(r8.world.swarm.absorb(), 1, "설정: V가 실제로 하나를 거둬들였다")
	t.ok(r8.world.swarm.banked > banked_before8, "V로 거둔 화물은 은행에 들어온다")
	t.eq(r8.world.swarm.eaten, eaten_before8, "V는 먹은 총량을 올리지 않는다")

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
	# **The trick this check used to rest on is gone.** It sent `rally` 1200px off host so that a deleted
	# `if clear_pull:` branch showed up as the mean distance RISING — ordinary FOLLOW would have walked the
	# pack the other way. Rallying is at the host now, so both branches steer at the same point and a dead
	# pull branch is invisible to any check that only asks which way the pack moved.
	#
	# **What separates them is the SPEED, so that is what is pinned.** The pull closes
	# `CLEAR_ABSORB_PULL * DT` = 15px a frame; FOLLOW manages `CLONE_SPEED_FOLLOW * DT` = 3.58px. 10.0 is
	# a literal between the two — read through either constant this check would scale with the very thing
	# it is separating. It also measures the PROCESS rather than the endpoint: a teleport home would leave
	# the same final distance.
	sw16.clear_pull = true
	var start16 := _mean_dist_to_host(sw16)
	var prev16 := start16
	var non_increasing16 := true
	# 400 / CLEAR_ABSORB_PULL = 0.444s to the nearest clone's arrival. 18 frames stays well inside that,
	# so nothing decelerates on arrival and every frame is the pull at full speed.
	for _frame16 in 18:
		sw16.step(DT, null)
		var cur16 := _mean_dist_to_host(sw16)
		if cur16 > prev16 + 0.5:
			non_increasing16 = false
		prev16 = cur16
	t.ok(non_increasing16, "흡수 박동 동안 평균 거리가 매 프레임 늘어나지 않는다")
	var per_frame16 := (start16 - prev16) / 18.0
	t.ok(per_frame16 > 10.0,
			"당김이 FOLLOW가 아니라 900px/s 쪽 속도로 좁힌다 (프레임당 %.2fpx)" % per_frame16)
	t.eq(sw16.count, 21, "설정: 18프레임 안에는 아무도 도착하지 않았다 — 감속이 섞이지 않았다")

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
			# Arrival now removes the body outright (see Swarm._clear_arrivals()'s header) — reading `pos[only16b]`
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
	#  (a) a level already PENDING the instant _begin_clear() runs. ⚠ **The critter that used to produce it
	#      is gone**: contact no longer pays, so nothing in a single step both banks a level and clears the
	#      stage until the boss's corpse does. `banked` is written to exactly one level's cost with
	#      `stage_cleared` already up instead — _grow() (still unfrozen, Run has not had its turn) queues
	#      the level inside the same world.step() the beat starts on, which is the shape that matters.
	#      `pending_levels = 0` is what drops it.
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
	# The clones are the swarm the beat has to absorb; the run opens alone, so every one of them is placed
	# here. Their force is what (b)'s cargo rides home on top of.
	for _i in 24:
		r19.world.swarm.add_clone(0, 4)
	r19.world.critter_count = 0
	r19.world.swarm.banked = Rules.LEVEL_COST_BASE   # (a): exactly one level's cost, crossed this step
	var c19 := r19.world.swarm.add_clone()   # (b): its cargo crosses a FURTHER threshold once absorbed
	r19.world.swarm.carried[c19] = Rules.LEVEL_COST_BASE + 5.0
	r19.world.swarm.pos[c19] = r19.world.swarm.pos[0] + Vector2(400.0, 0.0)   ## absorbed mid-beat, not at detection
	r19.world.stage_cleared = true
	r19.step(DT)   # _grow() queues the level, and Run sees the clear, inside the same world.step()
	t.ok(r19.world.pending_levels > 0 or r19.world.level > 0,
			"설정: 감지되는 그 스텝에 레벨이 실제로 하나 올랐다")
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
	t.eq(peak_before24, 5, "설정: 최대 무리가 실제로 갱신됐다 (분신 5)")
	var cc24 := r24.world.swarm.add_clone()
	r24.world.swarm.carried[cc24] = 7.0
	r24.world.swarm.pos[cc24] = r24.world.swarm.pos[0] + Vector2(600.0, 0.0)
	# ⚠ **The ground is removed first.** `push_out` shoves a hand-placed creature off a rock by up to that
	# rock's radius, and at seed 21 there is one right here — the crow landed 48px from the clone it was
	# put on top of and never reached it, with this check reading as a bookkeeping bug.
	_clear_terrain(r24.world)
	r24.world.critter_count = 1
	r24.world.critter_pos[0] = r24.world.swarm.pos[cc24]
	# A clone born with no force has `Rules.BODY_HP_MIN`, so one crow hit is the whole of its life. The
	# force is pinned rather than rolled for the same reason every other creature fixture pins it.
	r24.world.critter_species[0] = Parts.Species.CROW
	r24.world.critter_force[0] = 10
	r24.world.critter_hp[0] = 30
	r24.world.critter_flees[0] = 0
	r24.world.critter_atk_cd[0] = 0.0
	r24.world.critter_counter[0] = 0.0
	r24.world.critter_dir[0] = Vector2.ZERO
	r24.world.step(DT)   ## the crow hits the clone for 10 against its 1 hp: it dies and its cargo with it
	t.eq(r24.world.clones_lost, 1, "설정: 분신 하나를 잃었다")
	t.eq(roundi(r24.world.cargo_lost), 7, "설정: 화물 7을 함께 잃었다")
	r24.world.host_hp = 0
	r24.step(DT)
	t.eq(r24.phase, Run.Phase.ENDING, "죽음으로 런이 끝난다")
	t.ok(r24.result.elapsed >= elapsed_before24, "result에 실제로 흐른 시간이 담긴다")
	t.eq(r24.result.peak_swarm, peak_before24, "result에 최대 무리 값이 담긴다")
	t.eq(r24.result.clones_lost, 1, "result에 잃은 분신 수가 담긴다")
	t.eq(r24.result.cargo_lost, 7, "result에 잃은 화물이 담긴다")

	# -- 25: the stage is cleared by the BOSS's corpse, and by nothing else ------------------------------
	# Restored onto the mechanism that took the job over. Its old subject was the deleted threat model's
	# fiercest-critter comparison inside `World._contact()`, driven from both sides — one below the maximum
	# must not clear, one at the maximum must. That model is gone and contact pays nothing; **finishing a
	# corpse is what pays now**, and the flag hangs off that corpse's SPECIES.
	#
	# **Both halves, because each catches a different one-word mutation**: keying the flag off any finished
	# corpse (the crow half goes red) and keying it off the boss's DEATH rather than its meal (the boss half
	# never fires, since the corpse is what `_step_corpses` finishes). Every other check in this file sets
	# `stage_cleared` by hand and therefore cannot see either.
	#
	# The corpse sits on the host and is written one frame short of done, so a single `world.step()` is the
	# whole drive. `corpse_force` is a literal both times — a boss meal is six seconds and a crow's is half
	# of one, so the two need different openings and reading either off the table would hide that.
	var w25a := World.new()
	w25a.setup(31)
	_silence_food(w25a)
	w25a.critter_count = 0
	w25a.corpse_count = 1
	w25a.corpse_pos[0] = w25a.swarm.pos[0]
	w25a.corpse_species[0] = Parts.Species.CROW
	w25a.corpse_force[0] = 10
	w25a.corpse_progress[0] = 0.999
	w25a.step(DT)
	t.eq(w25a.corpse_count, 0, "설정: 까마귀 시체를 실제로 다 먹었다")
	t.ok(not w25a.stage_cleared, "까마귀를 다 먹어도 스테이지는 끝나지 않는다")
	# The same finish is what writes `species_eaten`, and that array is the card pool's only lock — so this
	# is the line that makes "한 런에 카드가 한 장도 안 나온다" impossible rather than merely unlikely.
	# **Order, not membership**, and a second crow must NOT append: the ending screen prints this list.
	t.eq(w25a.species_eaten.size(), 1, "시체를 다 먹으면 그 종이 먹은 목록에 들어간다")
	# Read through a guard, not straight off the array: the mutation this check exists for empties the list,
	# and an out-of-range index aborts the whole net — which loses the 15 checks below it instead of
	# reddening one. A net that dies is a net that stopped measuring.
	var first25: int = w25a.species_eaten[0] if w25a.species_eaten.size() > 0 else -1
	t.eq(first25, int(Parts.Species.CROW), "먹은 목록에 들어간 것은 그 시체의 종이다")
	# ⚠ **And this is the whole answer to "한 런에 카드가 한 장도 안 나온다".** The pool used to be locked
	# behind the horse, which is uncatchable and arrives about once every 150s; it now opens off the crow,
	# the creature standing still on the first minute. Driven, not assumed: one crow meal banked enough for
	# a level and `_grow()` rolled an offer in the same step. Every card in it is a 까마귀 row.
	t.ok(not w25a.offer.is_empty(), "까마귀 한 마리를 다 먹은 것만으로 카드 풀이 열린다")
	var crow_only := true
	for card in w25a.offer:
		if int(Parts.SPECIES[card]) != int(Parts.Species.CROW):
			crow_only = false
	t.ok(crow_only, "그때 나오는 카드는 전부 까마귀 부품이다 — 먹지 않은 종은 못 나온다")
	# The world is frozen while cards are on screen, which is the banking rule doing its job — cleared by
	# hand here so the second corpse can be stepped at all.
	w25a.pending_levels = 0
	w25a.offer = PackedInt32Array()
	w25a.corpse_count = 1
	w25a.corpse_pos[0] = w25a.swarm.pos[0]
	w25a.corpse_species[0] = Parts.Species.CROW
	w25a.corpse_force[0] = 10
	w25a.corpse_progress[0] = 0.999
	w25a.step(DT)
	t.eq(w25a.corpse_count, 0, "설정: 까마귀를 한 마리 더 다 먹었다")
	t.eq(w25a.species_eaten.size(), 1, "같은 종을 또 먹어도 목록은 늘지 않는다")

	var w25b := World.new()
	w25b.setup(32)
	_silence_food(w25b)
	w25b.critter_count = 0
	w25b.corpse_count = 1
	w25b.corpse_pos[0] = w25b.swarm.pos[0]
	w25b.corpse_species[0] = Parts.Species.BOSS
	w25b.corpse_force[0] = 120
	w25b.corpse_progress[0] = 0.999
	t.ok(not w25b.stage_cleared, "설정: 먹기 전에는 스테이지가 열려 있다")
	w25b.step(DT)
	t.eq(w25b.corpse_count, 0, "설정: 보스 시체를 실제로 다 먹었다")
	t.ok(w25b.stage_cleared, "보스 시체를 다 먹으면 스테이지가 끝난다")

	# -- RunResult.species — the ending screen's 먹은 종 line, driven from real meals -------------------
	# `_snapshot()` filled every other field and left this one at its empty default for three plans; the
	# ending screen's own net feeds it a HAND-BUILT RunResult, so the line that fills it from
	# `World.species_eaten` could be deleted outright with the whole round green. Measured, not assumed.
	#
	# **Two meals of different species, in a fixed order, because the claim is the ORDER.** A snapshot that
	# copied the list as a set, or sorted it, or walked it backwards, satisfies every membership assertion.
	# The horse eats first so that the expected order is NOT the enum's own order (CROW is 0) — read
	# straight off `Parts.SPECIES_NAME` instead of off `species_eaten`, the answer would come back
	# ["까마귀","말"] and look right.
	var r26 := Run.new()
	r26.start(33)
	_silence_food(r26.world)
	r26.world.critter_count = 0
	r26.world.corpse_count = 1
	r26.world.corpse_pos[0] = r26.world.swarm.pos[0]
	r26.world.corpse_species[0] = Parts.Species.HORSE
	r26.world.corpse_force[0] = 35
	# 0.999, not 0.99: a meal is `corpse_force × EAT_TIME_PER_FORCE`, so a horse is 1.75s and one frame at
	# 0.99 adds 0.019 and finishes nothing. The check would then measure an empty list and read as a bug in
	# the snapshot.
	r26.world.corpse_progress[0] = 0.999
	r26.step(DT)
	# A finished horse pays 105 경험치, which banks a level, which rolls an offer — and `World.step()`
	# refuses to advance while cards are on screen. Cleared by hand or the second meal never starts.
	r26.world.pending_levels = 0
	r26.world.offer = PackedInt32Array()
	r26.world.corpse_count = 1
	r26.world.corpse_pos[0] = r26.world.swarm.pos[0]
	r26.world.corpse_species[0] = Parts.Species.CROW
	r26.world.corpse_force[0] = 10
	r26.world.corpse_progress[0] = 0.999
	r26.step(DT)
	t.eq(r26.world.species_eaten.size(), 2, "설정: 말과 까마귀를 그 순서로 실제로 다 먹었다")
	r26.world.pending_levels = 0
	r26.world.offer = PackedInt32Array()
	r26.world.host_hp = 0
	r26.step(DT)
	t.eq(r26.phase, Run.Phase.ENDING, "설정: 런이 실제로 끝났다")
	t.eq(r26.result.species.size(), 2, "result에 먹은 종이 담긴다 — 기본값 빈 배열이 아니다")
	# Guarded reads. The mutation this block exists for empties the list, and an out-of-range index aborts
	# the whole net — which loses every check below it instead of reddening one.
	var sp26_0: String = r26.result.species[0] if r26.result.species.size() > 0 else ""
	var sp26_1: String = r26.result.species[1] if r26.result.species.size() > 1 else ""
	t.eq(sp26_0, "말", "먹은 종은 먹은 순서로 담긴다 — 첫 번째는 말이다")
	t.eq(sp26_1, "까마귀", "두 번째는 까마귀다 — 집합도 아니고 표의 순서도 아니다")

	# The `>= 0` guard, and it is synthetic on purpose: nothing in play writes a bad id into
	# `species_eaten`, but `Parts.SPECIES_NAME[-1]` returns the LAST row rather than erroring, so without
	# the guard a bad id prints 보스 on the ending screen and nothing anywhere goes red. This is the same
	# trap `body_slots`' own `>= 0` names one line above it in `_snapshot()`.
	# **Both halves of the guard, and they fail differently on purpose.** `-1` is the SILENT one — it reads
	# a real row and prints 보스, with nothing barked anywhere. An id past the end is the LOUD one: it
	# barks AND drops the entry (`append(null)` onto a PackedStringArray is refused), so both assertions
	# below move. Measured: dropping `s >= 0` reddens one label; dropping `s < SPECIES_NAME.size()` reddens
	# the other two and prints an engine error beside them. Neither half is carried by the wrapper's
	# stderr check alone.
	var r26b := Run.new()
	r26b.start(34)
	_silence_food(r26b.world)
	r26b.world.critter_count = 0
	r26b.world.species_eaten = PackedInt32Array([-1, Parts.SPECIES_NAME.size()])
	r26b.world.host_hp = 0
	r26b.step(DT)
	var sp26b: String = r26b.result.species[0] if r26b.result.species.size() > 0 else ""
	var sp26b_hi: String = r26b.result.species[1] if r26b.result.species.size() > 1 else ""
	t.eq(r26b.result.species.size(), 2, "설정: 이름 없는 종도 한 칸씩 차지한다")
	t.eq(sp26b, "?", "이름 없는 종은 ?로 나온다 — 표의 마지막 줄을 읽지 않는다")
	t.eq(sp26b_hi, "?", "표 밖의 종도 ?로 나온다 — 종이 하나 늘고 이름이 안 늘어난 날의 답")

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
	# The great absorption is the "you won" moment and nothing in the ecosystem may act during it. Left
	# running, a creature keeps walking at the host while the swarm is being swallowed and can cost it
	# health mid-victory. The outcome is latched (a hit mid-beat cannot turn CLEARED into DIED), but the
	# picture would still show the world going hostile at the exact moment it was won.
	#
	# Measured as a PROCESS, not a final comparison: the creature's position and `host_hp` are asserted
	# unchanged on EVERY frame of the beat. A before/after-only check would pass even if it chased, hit the
	# host, and wandered back to exactly where it started by the time the beat ended.
	#
	# ⚠ **A crow with its counter armed, and that is what makes the check mean anything.** Under plan 4 a
	# crow does not move AT ALL unless it has been damaged, so the obvious fixture would have frozen a
	# creature that was never going to move — and the positive control below is what says so out loud.
	var rf := Run.new()
	rf.start(27)
	_silence_food(rf.world)
	_clear_terrain(rf.world)
	# Six bodies placed far out, so the beat actually takes more than a couple of frames — see check 5's
	# identical note.
	for _i in 6:
		rf.world.swarm.add_clone()
	for i in range(1, rf.world.swarm.count):
		rf.world.swarm.pos[i] = rf.world.swarm.pos[0] + Vector2(700.0, 0.0)
	rf.world.critter_count = 1
	rf.world.boss_index = -1
	rf.world.critter_pos[0] = rf.world.swarm.pos[0] + Vector2(30.0, 0.0)
	_crow_row(rf.world, 0, 10)
	# Armed far past `CROW_COUNTER_TIME`, so it cannot simply expire during the beat and look frozen.
	rf.world.critter_counter[0] = 99.0
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

	# **The positive control, and without it the check above passes against a creature that was never going
	# to move.** The same crow, the same armed counter, the same number of frames — and `beat_frozen` off.
	var rc := World.new()
	rc.setup(271)
	_silence_food(rc)
	_clear_terrain(rc)
	rc.critter_count = 1
	rc.boss_index = -1
	rc.critter_pos[0] = rc.swarm.pos[0] + Vector2(300.0, 0.0)
	_crow_row(rc, 0, 10)
	rc.critter_counter[0] = 99.0
	rc.critter_dir[0] = Vector2.ZERO
	var moved_from: Vector2 = rc.critter_pos[0]
	for _s in 60:
		rc.step(DT)
	t.ok(rc.critter_pos[0].distance_to(moved_from) > 50.0,
			"대조: 얼리지 않으면 같은 까마귀가 실제로 걸어온다 (%.0fpx) — 안 움직일 놈을 얼린 것이 아니다"
					% rc.critter_pos[0].distance_to(moved_from))

	# **The second control, and it is a different subject.** `_step_corpses` and `_step_arena` moved inside
	# the same guard, and nothing else in the round measures that: a corpse finishing mid-absorption pays
	# 경험치, which `_grow()` turns into a level, which opens three cards on top of the ending screen.
	var rz := World.new()
	rz.setup(272)
	_silence_food(rz)
	_clear_terrain(rz)
	rz.critter_count = 0
	rz.boss_index = -1
	rz.corpse_count = 1
	rz.corpse_pos[0] = rz.swarm.pos[0]
	rz.corpse_species[0] = Parts.Species.CROW
	rz.corpse_force[0] = 10
	rz.corpse_progress[0] = 0.9
	# ⚠ **And the spawn timer is the third thing in that block.** It sat BELOW the freeze, so a crow walked
	# onto the field mid-"you won" — the one thing the beat exists to keep the field clear of. Wound to
	# 0.01s so the arrival lands on the very first frame either way.
	rz._next_critter = 0.01
	rz.beat_frozen = true
	for _s in 120:
		rz.step(DT)
	t.eq(rz.corpse_count, 1, "박동 중에는 시체도 익지 않는다 — 2초를 서 있어도 그대로다")
	t.ok(absf(rz.corpse_progress[0] - 0.9) < 0.0001, "진행도도 한 점 안 움직였다")
	t.eq(rz.critter_count, 0, "박동 중에는 생물도 태어나지 않는다 — 「이겼다」 위로 까마귀가 걸어 들어오지 않는다")
	rz.beat_frozen = false
	for _s in 120:
		rz.step(DT)
	t.eq(rz.corpse_count, 0, "대조: 박동이 끝나면 같은 시체가 곧바로 익는다")
	# An arrival is a HERD, so the count is "at least one" — pinned at 1 this reds for four of the six
	# species that can be rolled, for a reason that is not the freeze this check is about.
	t.ok(rz.critter_count >= 1,
			"대조: 그리고 멈춰 있던 그 시계가 곧바로 무리 하나를 내놓는다 (%d마리)" % rz.critter_count)

	# -- 15: the arena closes on the boss, summons the swarm, and holds the host in ---------------------
	# ⚠ **The boss is DRIVEN to `Rules.ARENA_RADIUS` by hand and never waited for.** It ships slower than the
	# host, so a run where the player keeps walking may never close the arena at all — that number is a
	# deferral to the first play session, not a promise this build makes, and a check that stepped until the
	# arena closed by itself would either hang or pass on luck.
	#
	# These live here rather than in the terrain net because the arena is the RUN's last act and this file is
	# where `World` is driven through whole frames. They are the only thing measuring `World::_step_arena`.
	var wa := World.new()
	wa.setup(31)
	_silence_food(wa)
	_clear_terrain(wa)
	t.ok(wa.boss_index >= 0, "설정: 보스가 한 마리 놓였다")
	# Every other creature removed, so nothing else can walk into the host or the clone mid-check. Backwards,
	# because `_remove_critter` swaps the last row down.
	for k in range(wa.critter_count - 1, -1, -1):
		if k != wa.boss_index:
			wa._remove_critter(k)
	t.eq(wa.critter_count, 1, "설정: 보스만 남았다")
	# Past `BOSS_HUNT_AT`, so the boss walks AT the host instead of wandering. From exactly `ARENA_RADIUS` a
	# wandering boss steps 2.5px in a random direction and half of those put it back outside the ring: the
	# hunt is what makes this one frame deterministic rather than a coin flip on the seed.
	wa.elapsed = Rules.BOSS_HUNT_AT
	var host_a: Vector2 = wa.swarm.pos[0]
	wa.critter_pos[wa.boss_index] = host_a + Vector2(Rules.ARENA_RADIUS, 0.0)
	wa.swarm.add_clone()
	wa.swarm.pos[1] = host_a + Vector2(3000.0, 0.0)
	t.ok(not wa.terrain.arena_closed, "설정: 보스가 닿기 전에는 아레나가 열려 있다")
	wa.step(DT)
	t.ok(wa.terrain.arena_closed, "보스가 ARENA_RADIUS 안에 들어오면 아레나가 닫힌다")
	t.eq(wa.terrain.arena_radius, Rules.ARENA_RADIUS, "닫힌 아레나의 반지름은 ARENA_RADIUS다")
	# The midpoint of the two, written as a literal: the boss walked 150 × DT = 2.5px in before the arena
	# read its position, so the centre sits (900 - 2.5) / 2 = 448.75px along +x from where the host stands.
	t.ok(wa.terrain.arena_centre.distance_to(host_a + Vector2(448.75, 0.0)) < 1.0,
			"아레나 중심은 호스트와 보스의 중간이다 (%.1f, %.1f)"
			% [wa.terrain.arena_centre.x - host_a.x, wa.terrain.arena_centre.y - host_a.y])
	# 3000px out on the frame it closed, `ARENA_SUMMON_RING` away on the same frame. **Not clamped to the
	# rim** — a clamp would leave it 900px from the host somewhere on the circle and satisfy "inside the
	# arena" while handing nothing back.
	t.ok(absf(wa.swarm.pos[1].distance_to(wa.swarm.pos[0]) - Rules.ARENA_SUMMON_RING) < 1.0,
			"3000px 밖의 분신이 닫히는 그 프레임에 호스트 300px 안으로 소환된다 (%.1f)"
			% wa.swarm.pos[1].distance_to(wa.swarm.pos[0]))
	t.ok(wa.swarm.pos[1].distance_to(wa.terrain.arena_centre) <= Rules.ARENA_RADIUS,
			"소환된 분신은 아레나 안에 있다")
	# The host cannot leave. Walked straight out from the centre for 5s and measured every frame — a
	# before/after pair would pass on a host that left and came back.
	wa.swarm.host_input = (host_a - wa.terrain.arena_centre).normalized()
	var out_a := false
	var ticks_a := 0
	while ticks_a < 300:
		wa.step(DT)
		if wa.swarm.pos[0].distance_to(wa.terrain.arena_centre) > Rules.ARENA_RADIUS:
			out_a = true
		ticks_a += 1
	t.ok(wa.swarm.pos[0].distance_to(wa.terrain.arena_centre) > 800.0,
			"설정: 호스트가 실제로 가장자리까지 걸어갔다 (%.1f)"
			% wa.swarm.pos[0].distance_to(wa.terrain.arena_centre))
	t.ok(not out_a, "아레나가 닫힌 뒤 호스트는 5초를 걸어 나가도 원 밖으로 못 나간다")

	# -- 16: it never re-opens -------------------------------------------------------------------------
	# Two instruments, because the property is guarded twice and one mutation reaches only one of them:
	# `Terrain::close_arena`'s early return, and `World::_step_arena`'s `arena_closed` guard.
	var centre_a: Vector2 = wa.terrain.arena_centre
	wa.terrain.close_arena(Vector2(1.0, 2.0))
	t.eq(wa.terrain.arena_centre, centre_a, "이미 닫힌 아레나는 close_arena를 다시 불러도 중심이 안 움직인다")
	# The clone is parked 700px out INSIDE the arena for the same step: closing twice would summon it back
	# to the 300px ring, and the centre never moving is not enough to see that — `close_arena`'s early return
	# would hide a summon loop firing every single frame for the rest of the fight.
	wa.swarm.pos[1] = wa.swarm.pos[0] + Vector2(700.0, 0.0)
	wa.critter_pos[wa.boss_index] = wa.swarm.pos[0] + Vector2(0.0, 100.0)
	wa.step(DT)
	t.eq(wa.terrain.arena_centre, centre_a, "보스가 다른 자리에서 다시 가까워져도 아레나는 다시 안 닫힌다")
	t.eq(wa.terrain.arena_radius, Rules.ARENA_RADIUS, "반지름도 그대로다")
	t.ok(wa.swarm.pos[1].distance_to(wa.swarm.pos[0]) > 600.0,
			"닫힌 뒤에는 분신이 매 프레임 다시 불려오지 않는다 (%.1f)"
			% wa.swarm.pos[1].distance_to(wa.swarm.pos[0]))

	# -- 17: the summon goes through `Swarm.place()`, so a clone never lands inside a rock --------------
	var wr := World.new()
	wr.setup(32)
	_silence_food(wr)
	_clear_terrain(wr)
	for k in range(wr.critter_count - 1, -1, -1):
		if k != wr.boss_index:
			wr._remove_critter(k)
	wr.elapsed = Rules.BOSS_HUNT_AT
	var host_r: Vector2 = wr.swarm.pos[0]
	# One rock, hand-placed exactly where the summon ring would drop this clone, so the check does not ride
	# on where seed 32 happened to scatter forty of them.
	var rock_r := host_r + Vector2(Rules.ARENA_SUMMON_RING, 0.0)
	wr.terrain.rock_pos.append(rock_r)
	wr.terrain.rock_radius.append(90.0)
	wr.critter_pos[wr.boss_index] = host_r + Vector2(Rules.ARENA_RADIUS, 0.0)
	wr.swarm.add_clone()
	wr.swarm.pos[1] = host_r + Vector2(3000.0, 0.0)
	wr.step(DT)
	t.ok(wr.terrain.arena_closed, "설정: 아레나가 닫혔다")
	# ⚠ Without this line the check below passes on a clone that was never summoned at all: 3000px from the
	# host is also 2700px from the rock. Measured — the summon loop can be deleted outright and only check
	# 15 goes red.
	t.ok(wr.swarm.pos[1].distance_to(host_r) < 500.0,
			"설정: 분신이 실제로 소환됐다 (%.1f)" % wr.swarm.pos[1].distance_to(host_r))
	# 90 + 8, as literals. A bare `pos[i] = pos[0] + offset` drops it dead centre in the rock at distance 0.
	t.ok(wr.swarm.pos[1].distance_to(rock_r) > 90.0 + Rules.CLONE_BODY_RADIUS - 0.5,
			"소환된 분신은 바위 안이 아니라 바위 밖에 놓인다 (%.1f)" % wr.swarm.pos[1].distance_to(rock_r))

	# -- 18: a DEAD boss cannot close the arena --------------------------------------------------------
	# `boss_index` is -1 once the boss dies, and `critter_pos[-1]` is a legal read in GDScript: it returns
	# the LAST row of a table resized to `CRITTER_MAX`, which is zero-filled — a phantom boss standing at
	# the field's origin. So the host is parked next to that origin here, where a missing guard closes the
	# arena around a creature that does not exist. Anywhere else on the field the bug is silent.
	var wd := World.new()
	wd.setup(33)
	_silence_food(wd)
	_clear_terrain(wd)
	t.ok(wd.boss_index >= 0, "설정: 보스가 놓였다")
	for k in range(wd.critter_count - 1, -1, -1):
		if k != wd.boss_index:
			wd._remove_critter(k)
	# Killed for real, so the repair inside `_remove_critter` is what produces the -1 rather than the net.
	wd._damage_critter(wd.boss_index, 400)
	t.eq(wd.boss_index, -1, "설정: 보스를 실제로 죽였고 boss_index가 -1이 됐다")
	t.eq(wd.critter_count, 0, "설정: 필드에 생물이 남지 않았다")
	wd.swarm.pos[0] = Vector2(5.0, 5.0)
	# ⚠ **Past `BOSS_HUNT_AT`, or this measures check 20's guard instead of this one.** `_step_arena` now
	# returns before it ever reads `boss_index` while the hunt has not started, and at `elapsed = 0` the
	# phantom-boss branch below is unreachable — the check would pass with its own subject deleted.
	wd.elapsed = Rules.BOSS_HUNT_AT
	wd.step(DT)
	t.ok(not wd.terrain.arena_closed, "보스가 죽은 뒤에는 아레나가 닫히지 않는다")

	# -- 19: the arena cannot close during the great absorption -----------------------------------------
	# `_step_arena` sits inside `step()`'s `beat_frozen` guard with the critters and the corpses, and for a
	# sharper reason than either: closing teleports every clone at once while the beat is walking those same
	# clones home one by one. Nothing else in the round would notice the call moving one line down.
	var rb := Run.new()
	rb.start(34)
	_silence_food(rb.world)
	_clear_terrain(rb.world)
	for k in range(rb.world.critter_count - 1, -1, -1):
		if k != rb.world.boss_index:
			rb.world._remove_critter(k)
	rb.world.elapsed = Rules.BOSS_HUNT_AT
	for _i in 6:
		rb.world.swarm.add_clone()
	for i in range(1, rb.world.swarm.count):
		rb.world.swarm.pos[i] = rb.world.swarm.pos[0] + Vector2(700.0, 0.0)
	rb.world.stage_cleared = true
	rb.step(DT)
	t.ok(rb.world.beat_frozen, "설정: 대흡수 박동이 시작됐다")
	# The boss put right on top of the host, well inside the ring, for the whole beat.
	rb.world.critter_pos[rb.world.boss_index] = rb.world.swarm.pos[0] + Vector2(50.0, 0.0)
	var ticks_b := 0
	var closed_b := false
	while rb.phase == Run.Phase.PLAY and ticks_b < 300:
		rb.step(DT)
		if rb.world.terrain.arena_closed:
			closed_b = true
		ticks_b += 1
	t.ok(ticks_b > 5, "설정: 박동이 실제로 여러 프레임 걸렸다 (%d틱)" % ticks_b)
	t.ok(not closed_b, "박동 내내 아레나는 한 프레임도 닫히지 않는다")

	# -- 20: the arena is the LAST act, so nothing closes it before the hunt starts ---------------------
	# ⚠ **`_step_arena` fired on distance alone.** Before `BOSS_HUNT_AT` the boss random-walks ~250px
	# segments at 150px/s from 1800px out, and RMS displacement over 150 seconds is larger than the field:
	# drifting once inside `ARENA_RADIUS` closed the arena permanently at t = 20, caged the host in a 900px
	# circle with no view of any kind to explain it, and then walked back out — because the boss was never
	# clamped to the circle it had closed. Two guards, one fixture, and a control on each.
	var wg := World.new()
	wg.setup(35)
	_silence_food(wg)
	_clear_terrain(wg)
	for k in range(wg.critter_count - 1, -1, -1):
		if k != wg.boss_index:
			wg._remove_critter(k)
	t.eq(wg.critter_count, 1, "설정: 보스만 남았다")
	var host_g: Vector2 = wg.swarm.pos[0]
	wg.critter_pos[wg.boss_index] = host_g + Vector2(800.0, 0.0)
	t.ok(800.0 < Rules.ARENA_RADIUS, "설정: 800px는 아레나 반지름 안이다 — 거리만 보면 닫힐 자리다")
	wg.elapsed = 0.0
	wg._step_arena()
	t.ok(not wg.terrain.arena_closed,
			"BOSS_HUNT_AT 전에는 아레나가 닫히지 않는다 — 떠돌던 보스가 스쳐도 t=20에 갇히지 않는다")
	wg.elapsed = Rules.BOSS_HUNT_AT
	wg._step_arena()
	t.ok(wg.terrain.arena_closed, "대조: 사냥이 시작된 뒤 같은 자리의 같은 보스는 아레나를 닫는다")

	# And the boss cannot walk back out of it. 852 = `ARENA_RADIUS` 900 − the boss's own 48, by hand.
	var centre_g: Vector2 = wg.terrain.arena_centre
	wg.swarm.pos[0] = centre_g
	wg.critter_pos[wg.boss_index] = centre_g + Vector2(1500.0, 0.0)
	# A crow the same 1500px out, as the control: creatures are NOT clamped, only the boss is.
	var kc := wg._write_critter(Parts.Species.CROW, centre_g + Vector2(1500.0, 200.0), 10)
	_crow_row(wg, kc, 10)
	wg._step_critters(DT)
	t.ok(wg.critter_pos[wg.boss_index].distance_to(centre_g) <= 852.0 + 0.01,
			"닫힌 아레나 밖의 보스는 그 안으로 끌려 들어온다 (%.1f <= 852)"
					% wg.critter_pos[wg.boss_index].distance_to(centre_g))
	t.ok(wg.critter_pos[kc].distance_to(centre_g) > 1400.0,
			"대조: 같은 자리의 까마귀는 끌려오지 않는다 — 갇히는 것은 보스뿐이다 (%.1f)"
					% wg.critter_pos[kc].distance_to(centre_g))


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0


## Forty rocks now sit wherever a fixture writes a coordinate, and `push_out` moves a hand-placed creature
## off one by up to that rock's radius. A check that is not about the ground removes the ground first.
func _clear_terrain(w: World) -> void:
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()


## One creature row, every column by hand, with the force PINNED — a crow spawns anywhere in 8–12 and a
## check that reads damage off the roll passes or fails by seed.
func _crow_row(w: World, k: int, force_value: int) -> void:
	w.critter_species[k] = Parts.Species.CROW
	w.critter_force[k] = force_value
	w.critter_hp[k] = force_value * Rules.HP_PER_FORCE
	w.critter_flees[k] = 0
	w.critter_atk_cd[k] = 0.0
	w.critter_counter[k] = 0.0


func _mean_dist_to_host(sw: Swarm) -> float:
	var sum := 0.0
	for i in range(1, sw.count):
		sum += sw.pos[i].distance_to(sw.pos[0])
	return sum / float(sw.count - 1)
