extends RefCounted
## Separation, and the grid that makes it affordable.
##
## **Positions coming out right prove nothing about the grid.** A naive O(n²) loop wearing a grid's name
## passes every positional check there is — so this net reads `pair_tests`, the count of candidates the
## grid actually looked at. Set the cell size to the whole field and the positions stay perfect while that
## counter explodes; that mutation is the one this file exists for.
##
## The counter is also asserted to be **above zero**: a loop whose condition is false from the start runs
## nothing and reports nothing, which `CLAUDE.md` lists as its own category of green.
##
## ⚠ **Two pairs live here now, and they have different rules.** Clone↔clone is symmetric; clone↔host moves
## the clone and never the host. `_the_host_itself_never_moves()` is the one-way half's own check and it is
## byte-exact — a tolerance there would let the player be nudged by their own swarm and read as green.

const DT := 1.0 / 60.0


func run(t) -> void:
	var sw := Swarm.new()
	sw.setup(11, Vector2(500.0, 500.0))

	# Exactly coincident — the state a rendezvous actually produces, and the one a force-based separation
	# never resolves in a single step.
	var a := sw.add_clone()
	var b := sw.add_clone()
	sw.pos[a] = Vector2(100.0, 100.0)
	sw.pos[b] = Vector2(100.0, 100.0)
	# Frozen: `1` gathers at the HOST now, so the host is what gets parked on the pair. At distance 0 the
	# FOLLOW branch is already inside `rally_radius()` and steers nowhere, so neither clone WALKS during this
	# step and `travel` below measures the correction alone.
	# ⚠ **The host no longer sits this out.** It used to be skipped at `j <= 0` and this comment said so;
	# `_separate_from_host()` now pushes each clone off it — one-way, so the host itself still does not move.
	sw.pos[0] = Vector2(100.0, 100.0)
	sw.command_rally()
	sw.step(DT, null)
	var gap := sw.pos[a].distance_to(sw.pos[b])
	t.ok(gap >= 15.9, "완전히 겹친 두 마리가 한 스텝에 떨어졌다 (%.2f)" % gap)

	# **A gap assertion alone measured the wrong thing.** The coincident branch once divided by an epsilon
	# and threw the pair ~80,000px to opposite corners of the field — and this net was green, because a
	# blow-up satisfies "at least 16 apart" better than the correct answer does. Sweeping the separation
	# strength from 0.45 down to 0.02 stayed green too, so the strength was entirely unmeasured.
	# Travel is the ceiling — a correction can never move a body further than the overlap it is resolving,
	# on top of the speed it was already allowed. **It is only half the pin**: a WEAKENED correction makes
	# travel smaller, so the gap check above is what catches that direction. Two checks, two sides.
	var travel := maxf(sw.pos[a].distance_to(Vector2(100.0, 100.0)), sw.pos[b].distance_to(Vector2(100.0, 100.0)))
	# ⚠ **Re-derived, not loosened, when clone↔host separation landed.** The host is parked on the pair, so
	# each clone now takes a second correction the old ceiling knew nothing about: the one-way clone↔host
	# push, whose maximum is exactly its own distance `BODY_RADIUS + CLONE_BODY_RADIUS` (a clone standing on
	# the host is moved the whole way and never further). Measured at 22.00 against the 41.58 this sums to.
	# **A third term, never a bigger literal** — the 80,000px epsilon throw is still red under it.
	var ceiling := Rules.CLONE_SPEED_FOLLOW * DT + Rules.SEPARATION_MIN \
			+ (Rules.BODY_RADIUS + Rules.CLONE_BODY_RADIUS)
	t.ok(travel <= ceiling,
			"겹침을 푸는 이동이 겹친 만큼을 넘지 않는다 (%.2f ≤ %.2f)" % [travel, ceiling])

	# Deterministic: the same overlap must resolve the same way every run, or nothing above can be pinned.
	var sw2 := Swarm.new()
	sw2.setup(11, Vector2(500.0, 500.0))
	var a2 := sw2.add_clone()
	var b2 := sw2.add_clone()
	sw2.pos[a2] = Vector2(100.0, 100.0)
	sw2.pos[b2] = Vector2(100.0, 100.0)
	sw2.pos[0] = Vector2(100.0, 100.0)
	sw2.command_rally()
	sw2.step(DT, null)
	t.eq(sw2.pos[a2], sw.pos[a], "같은 겹침은 같은 방향으로 풀린다")

	# 300 clones inside one screen: the density a rendezvous reaches, well past the 40 the build caps at.
	var big := Swarm.new()
	big.setup(5, Vector2(640.0, 360.0))
	var placed := 0
	for i in 300:
		var k := big.add_clone()
		if k < 0:
			break
		big.pos[k] = Vector2(200.0 + float(i % 20) * 30.0, 100.0 + float(i / 20) * 30.0)
		placed += 1
	t.ok(placed >= 39, "풀 상한까지 채웠다 (%d)" % placed)

	# The host already stands at (640, 360) — `setup()` put it there — and the rendezvous is the host now,
	# so the command carries no point.
	big.command_rally()
	big.step(DT, null)
	var tests: int = big.clone_grid.pair_tests
	t.ok(tests > 0, "격자를 실제로 조회했다 — 0이면 루프가 아예 안 돈 것이다 (%d)" % tests)
	# 20 per clone, not NEIGHBOUR_CAP: the cap bounds what is RETURNED, while this counts what was LOOKED
	# AT — a 3×3 walk over 32px cells sees roughly a dozen bodies at this spacing. The number that matters
	# is the gap to the naive loop: 40 clones × 40 = 1600 candidates, four times this ceiling. Widening
	# the cell to the whole field lands exactly there and goes red.
	t.ok(tests <= placed * 20,
			"후보 검사 수가 상한 안이다 — 격자가 실제로 가지를 친다 (%d ≤ %d)" % [tests, placed * 20])

	# **The state the whole design turns on, and it was broken while every check was green.** Separation
	# was only ever measured on TWO clones, and scatter's spacing check runs on a swarm that is spreading
	# out. Forty bodies rallied onto one point is the case both this file and `_separate` name as the one
	# that matters — measured there, the closest pair was 2.15px after twenty seconds and 58 pairs
	# overlapped, because a fixed 24px arrival disc cannot hold forty bodies wanting 16px each.
	# 15.0 is the same pinned literal `net_swarm_scatter` uses.
	for _s in 20 * 60:
		big.step(DT, null)
	var closest := INF
	for i in range(1, big.count):
		for j in range(i + 1, big.count):
			closest = minf(closest, big.pos[i].distance_to(big.pos[j]))
	t.ok(closest >= 15.0, "집결 지점에 40마리가 모여도 서로 겹치지 않는다 (%.2f)" % closest)

	# Timing anything through pumped frames measures nothing — headless pacing is pinned at 6.9ms whatever
	# the load. A synchronous loop against the microsecond clock is the only honest way to catch a
	# quadratic regression, and 40 bodies at a rendezvous is the worst case the build can reach.
	var t0 := Time.get_ticks_usec()
	for _s in 120:
		big.step(DT, null)
	var per_step := float(Time.get_ticks_usec() - t0) / 120.0
	t.ok(per_step < 2000.0, "집결 중 한 스텝이 2ms 아래다 (%.0fus)" % per_step)

	_host_is_separated_from(t)
	_the_host_itself_never_moves(t)


## **Clone↔host, and it is one-way.** Nothing pushed the host or was pushed by it until now: `step()` called
## `_separate()` over `range(1, count)` and `_separate()` skipped `j <= 0`, two deliberate boundaries with no
## reason written anywhere — see 「근접전이 안 읽힌다」's A-2, which is what the user was looking at when they
## said bodies stand inside each other.
##
## Exactly coincident is the case that matters and it is manufactured every run: `1` steers every clone onto
## the host and the arena summon teleports up to forty onto it with `limit_length`, which does not move a
## clone that is already at offset zero.
func _host_is_separated_from(t) -> void:
	var sw := Swarm.new()
	sw.setup(3, Vector2(400.0, 400.0))
	var c := sw.add_clone()
	sw.pos[c] = sw.pos[0]
	sw.command_rally()
	sw.step(DT, null)
	var gap := sw.pos[c].distance_to(sw.pos[0])
	t.ok(gap >= Rules.SEPARATION_MIN,
			"호스트 위에 선 분신이 한 스텝에 떨어진다 (%.2f)" % gap)
	# **Both sides, with a literal.** `>=` alone is satisfied better by a blow-up than by the right answer —
	# the epsilon divisor that threw a coincident pair ~80,000px was green under exactly that shape. 22.0 is
	# `BODY_RADIUS + CLONE_BODY_RADIUS` written as a NUMBER on purpose: read off the constants it would shrink
	# with them, and a body separated to `SEPARATION_MIN` still stands 6px inside the host's drawn radius.
	t.ok(absf(gap - 22.0) < 0.01, "떨어지는 거리는 두 반지름의 합이다 (%.4f)" % gap)

	# ⚠ **The determinism check has to be ONE clone, and the forty-body one below cannot stand in for it.**
	# In a pile the clone↔clone loop moves a body off the host BEFORE `_separate_from_host()` looks, so `l`
	# is never zero there and the host's coincident branch never runs — measured: swapping its angle for
	# `randf()` left the forty-body comparison green. With a single clone nothing else has touched it, so
	# this is the only place that branch decides anything.
	var solo := Swarm.new()
	solo.setup(3, Vector2(400.0, 400.0))
	var c2 := solo.add_clone()
	solo.pos[c2] = solo.pos[0]
	solo.command_rally()
	solo.step(DT, null)
	t.eq(solo.pos[c2], sw.pos[c], "호스트에 정확히 겹친 몸은 두 번 돌려도 같은 방향으로 풀린다")

	# Forty exactly on the host — the arena summon's state, not a tidy grid. `closest_host` is what the old
	# build could not deliver: the pile's centre body simply stayed under the player.
	var big := Swarm.new()
	big.setup(9, Vector2(640.0, 360.0))
	for _i in 40:
		var k := big.add_clone()
		if k < 0:
			break
		big.pos[k] = big.pos[0]
	t.eq(big.count, 41, "설정: 호스트 위에 마흔이 겹쳐 서 있다")
	big.command_rally()
	for _s in 20 * 60:
		big.step(DT, null)
	var closest_host := INF
	var closest_pair := INF
	for i in range(1, big.count):
		closest_host = minf(closest_host, big.pos[i].distance_to(big.pos[0]))
		for j in range(i + 1, big.count):
			closest_pair = minf(closest_pair, big.pos[i].distance_to(big.pos[j]))
	# 14.0 is `BODY_RADIUS` as a pinned literal: no clone's CENTRE stands inside the host's own body. It is
	# deliberately below the 22 above — forty bodies push each other around and one of them ends the frame
	# nearer than the pass alone would leave it, so pinning 22 here would be pinning the wrong claim.
	t.ok(closest_host >= 14.0, "마흔이 집결해도 어느 분신도 호스트 안에 서 있지 않다 (%.2f)" % closest_host)
	# The same pinned 15.0 the rest of this file uses: opening the host pair must not cost the clone pair.
	t.ok(closest_pair >= 15.0, "호스트 분리를 열어도 분신끼리는 그대로 떨어져 있다 (%.2f)" % closest_pair)

	# Deterministic over 1200 steps of the whole pass, which the one-step checks above cannot reach: this is
	# what catches an ORDERING that drifts run to run. ⚠ It does NOT reach the host's coincident branch —
	# see the note by the solo check above for why, and do not read this as covering it.
	var twin := Swarm.new()
	twin.setup(9, Vector2(640.0, 360.0))
	for _i in 40:
		var k := twin.add_clone()
		if k < 0:
			break
		twin.pos[k] = twin.pos[0]
	twin.command_rally()
	for _s in 20 * 60:
		twin.step(DT, null)
	var same := twin.count == big.count
	if same:
		for i in twin.count:
			if twin.pos[i] != big.pos[i]:
				same = false
				break
	t.ok(same, "같은 무더기는 두 번 돌려도 같은 자리로 풀린다")


## **The half the whole rule turns on: separation moves the CLONE, never the host.** A host ringed by forty
## bodies that could each push it does not stand where the stick says, and the fix for overlap would have
## cost the one thing the player is holding.
##
## Driven against a host that is WALKING, not a parked one — a parked host's `place(pos[0])` is the identity
## on open ground, so a symmetric push would have to move it by more than nothing to be seen, and any check
## on a still host measures `_move_host()` instead. Byte-exact `==`, not a tolerance: there is no amount of
## drift that is allowed here.
func _the_host_itself_never_moves(t) -> void:
	var alone := Swarm.new()
	alone.setup(21, Vector2(500.0, 500.0))
	alone.host_input = Vector2(0.6, -0.8)

	var crowded := Swarm.new()
	crowded.setup(21, Vector2(500.0, 500.0))
	crowded.host_input = Vector2(0.6, -0.8)
	for _i in 12:
		var k := crowded.add_clone()
		if k < 0:
			break
	t.eq(crowded.count, 13, "설정: 호스트가 자기 위에 선 열둘을 끌고 걷는다")

	var drifted := 0.0
	for _s in 120:
		# **Written back onto the host EVERY step, not once**, so all 120 steps run the coincident branch at
		# a full 22px overlap rather than the one-off the twelve would settle out of at `rally_radius()`'s
		# 34px. ⚠ **Measured, not assumed**: a symmetric push is caught either way (drift 3184px with this
		# line, 132px without it), so the line is not what makes the check bite — it is what makes every step
		# measure the state the rule is about instead of one step out of 120.
		for i in range(1, crowded.count):
			crowded.pos[i] = crowded.pos[0]
		alone.step(DT, null)
		crowded.step(DT, null)
		drifted = maxf(drifted, alone.pos[0].distance_to(crowded.pos[0]))
	t.eq(crowded.pos[0], alone.pos[0], "호스트의 좌표는 무리가 있든 없든 한 비트도 같다")
	t.ok(drifted == 0.0, "120스텝 어느 지점에서도 호스트가 밀린 적이 없다 (%.6f)" % drifted)
	# The fixture has to be able to fail: a host that never left its start would pass the two checks above
	# with `_move_host()` deleted as well.
	t.ok(alone.pos[0].distance_to(Vector2(500.0, 500.0)) > 100.0,
			"설정: 호스트는 그 120스텝 동안 실제로 걸었다 (%.1f)" % alone.pos[0].distance_to(Vector2(500.0, 500.0)))
