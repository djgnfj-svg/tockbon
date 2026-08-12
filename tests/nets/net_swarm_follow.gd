extends RefCounted
## `1` — the rendezvous. Clones walk to the point the key was pressed at, not to the host.
##
## **Final state cannot measure this.** Teleporting every clone onto the point on step 1 leaves the same
## final positions as walking there, and `CLAUDE.md` records three checks staying green through exactly
## that substitution. So the distance is sampled every step and the sequence itself is asserted.
##
## Coordinates are pinned literals. Reading the swarm's own field for the bounds would shrink the test
## along with the thing it tests.

const DT := 1.0 / 60.0
const STEPS := 60


func run(t) -> void:
	var sw := Swarm.new()
	sw.setup(7, Vector2(1000.0, 1000.0))

	# A 5×8 block, 60px apart — far enough that separation never fires, so this net measures steering
	# alone. Separation has its own net.
	for i in 40:
		var k := sw.add_clone()
		sw.pos[k] = Vector2(2400.0 + float(i % 5) * 60.0, 1700.0 + float(i / 5) * 60.0)
	t.eq(sw.count, 41, "호스트 1 + 분신 40")

	sw.command_rally(Vector2(600.0, 400.0))
	t.eq(sw.rally, Vector2(600.0, 400.0), "집결 지점은 호스트 위치가 아니라 찍은 지점이다")

	var prev := _mean_dist(sw)
	var first := prev
	var monotone := true
	var max_step := 0.0
	for _s in STEPS:
		var before := sw.pos.duplicate()
		sw.step(DT, null)
		for i in range(1, sw.count):
			max_step = maxf(max_step, before[i].distance_to(sw.pos[i]))
		var now := _mean_dist(sw)
		if now > prev + 0.001:
			monotone = false
		prev = now

	t.ok(prev < first, "60스텝 뒤 집결 지점에 더 가까워졌다 (%.1f → %.1f)" % [first, prev])
	t.ok(monotone, "매 스텝 가까워졌다 — 최종 위치만 보면 순간이동과 구별이 안 된다")
	t.ok(max_step <= Rules.CLONE_SPEED_FOLLOW * DT + 0.01,
			"한 스텝 이동이 속도×dt 를 넘지 않았다 (%.3f)" % max_step)

	# The host is not what they gather at, and it must not be dragged around by the command either.
	t.eq(sw.pos[0], Vector2(1000.0, 1000.0), "호스트는 명령으로 움직이지 않았다")

	# Arrival stops. Without this the whole swarm jitters on one coordinate forever and separation fights
	# steering every frame.
	for _s in 600:
		sw.step(DT, null)
	var settled := _mean_dist(sw)
	# 130px is a pinned literal, not a bound read from the swarm. Forty bodies stop at the arrival ring
	# (~63px for this count) and the ones still coming push the ring outward, so the settled mean sits
	# near 110 — a ring, not a point. Anything under 130 means "arrived and stayed"; a swarm that kept
	# drifting, orbited, or scattered back out fails it.
	t.ok(settled <= 130.0, "도착한 뒤 지점 근처에 머문다 (%.1f)" % settled)


func _mean_dist(sw: Swarm) -> float:
	var sum := 0.0
	for i in range(1, sw.count):
		sum += sw.pos[i].distance_to(sw.rally)
	return sum / float(maxi(1, sw.count - 1))
