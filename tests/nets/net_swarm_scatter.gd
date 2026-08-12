extends RefCounted
## `2` — scatter. The swarm has to actually spread, in more than one direction, without stacking.
##
## **A/B comparison catches "diverged", never "vanished"** — so this net does not compare scatter against
## follow. It asserts three independent properties of the scattered state, each of which a different
## broken implementation would fail: area (it moved outward at all), spacing (it did not become one dot),
## and heading spread (it is a scatter and not a parade in one direction).

const DT := 1.0 / 60.0


func run(t) -> void:
	var sw := Swarm.new()
	sw.setup(3, Vector2(1900.0, 1100.0))
	for i in 30:
		var k := sw.add_clone()
		sw.pos[k] = Vector2(1900.0 + float(i % 6) * 20.0, 1100.0 + float(i / 6) * 20.0)

	var before := _area(sw)
	sw.command_scatter()
	t.eq(sw.scatter_anchor, Vector2(1900.0, 1100.0), "흩기 기준점은 명령 시점의 호스트 자리다")

	for _s in 180:
		sw.step(DT, null)

	var after := _area(sw)
	t.ok(after >= before * 4.0, "퍼진 넓이가 4배 이상이다 (%.0f → %.0f)" % [before, after])

	var closest := INF
	for i in range(1, sw.count):
		for j in range(i + 1, sw.count):
			closest = minf(closest, sw.pos[i].distance_to(sw.pos[j]))
	# A pinned literal. Reading SEPARATION_MIN through the swarm would let the rule shrink with the code
	# it is supposed to hold; 15.0 is one pixel of slack under the 16 the design commits to.
	t.ok(closest >= 15.0, "가장 가까운 두 마리도 붙어 있지 않다 (%.1f)" % closest)

	var spread := _heading_spread(sw)
	t.ok(spread > PI, "이동 방향이 180°보다 넓게 흩어졌다 (%.0f°)" % rad_to_deg(spread))

	# The leash. Without it a scattering clone walks off the map forever and the swarm stops being one
	# thing — measured out to ten seconds, well past the point a missing leash would show.
	for _s in 600:
		sw.step(DT, null)
	var farthest := 0.0
	for i in range(1, sw.count):
		farthest = maxf(farthest, sw.pos[i].distance_to(sw.scatter_anchor))
	# 1125 is pinned, not `SCATTER_RADIUS * 1.25`: read through the constant, the leash could be widened to
	# 900,000 and this check would widen with it.
	t.ok(farthest <= 1125.0, "기준점에서 목줄 거리 안에 남아 있다 (%.0f)" % farthest)


func _area(sw: Swarm) -> float:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(1, sw.count):
		lo = lo.min(sw.pos[i])
		hi = hi.max(sw.pos[i])
	return maxf(1.0, (hi.x - lo.x)) * maxf(1.0, (hi.y - lo.y))


## Widest angular gap subtracted from a full turn: the span the headings actually cover.
func _heading_spread(sw: Swarm) -> float:
	var angles: Array[float] = []
	for i in range(1, sw.count):
		if sw.vel[i].length_squared() > 1.0:
			angles.append(fposmod(sw.vel[i].angle(), TAU))
	if angles.size() < 2:
		return 0.0
	angles.sort()
	var widest := TAU - (angles[angles.size() - 1] - angles[0])
	for i in range(1, angles.size()):
		widest = maxf(widest, angles[i] - angles[i - 1])
	return TAU - widest
