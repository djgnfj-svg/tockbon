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
	sw.command_rally(Vector2(100.0, 100.0))
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
	t.ok(travel <= Rules.CLONE_SPEED_FOLLOW * DT + Rules.SEPARATION_MIN,
			"겹침을 푸는 이동이 겹친 만큼을 넘지 않는다 (%.2f)" % travel)

	# Deterministic: the same overlap must resolve the same way every run, or nothing above can be pinned.
	var sw2 := Swarm.new()
	sw2.setup(11, Vector2(500.0, 500.0))
	var a2 := sw2.add_clone()
	var b2 := sw2.add_clone()
	sw2.pos[a2] = Vector2(100.0, 100.0)
	sw2.pos[b2] = Vector2(100.0, 100.0)
	sw2.command_rally(Vector2(100.0, 100.0))
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

	big.command_rally(Vector2(640.0, 360.0))
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
