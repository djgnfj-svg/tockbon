extends RefCounted
## `1` — the rendezvous. Clones walk to the HOST, and they read its position live every frame.
##
## **The command used to take a point and this file used to assert the stored one.** That field is gone:
## a per-frame copy of the host's position is a second source of truth for something the swarm can already
## read, so `command_rally()` takes no argument and `_move_clone()` reads `pos[0]`. The check that read
## `sw.rally` is replaced by the thing it was standing in for — the clones closing on the host across
## frames.
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

	# ⚠ **Scattered FIRST, and that is not decoration.** `setup()` writes `FOLLOW` into row 0 and nothing
	# ever rewrites it (`command_scatter`/`command_strike` both start at index 1), while `add_clone()`
	# copies its parent's state — so every clone in a fresh swarm is ALREADY FOLLOW and `command_rally()`
	# is a no-op in any net that calls it on one. Measured: its body replaced with `pass` left the whole
	# round green, and what this file thought it was measuring was `_move_clone()`'s FOLLOW branch reading
	# `pos[0]` live. Real, but not the key.
	sw.command_scatter()
	var scattered := 0
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.SCATTER:
			scattered += 1
	t.eq(scattered, 40, "설정: 마흔이 전부 흩어진 상태다 — 부르기가 되돌릴 것이 실제로 있다")

	# The host stands somewhere that is NOT where it started, and the command carries no point at all —
	# so a rendezvous that still went to a stored coordinate would send the swarm to (1000, 1000).
	var host_state_before: int = sw.state[0]
	sw.pos[0] = Vector2(600.0, 400.0)
	sw.command_rally()

	var followers := 0
	for i in range(1, sw.count):
		if sw.state[i] == Swarm.FOLLOW:
			followers += 1
	t.eq(followers, 40, "1이 흩어진 마흔을 전부 FOLLOW로 되돌린다")
	t.eq(sw.state[0], host_state_before, "호스트의 줄은 그대로다 — 명령은 1번부터 돈다")

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

	t.ok(prev < first, "60스텝 뒤 호스트에 더 가까워졌다 (%.1f → %.1f)" % [first, prev])
	t.ok(monotone, "매 스텝 가까워졌다 — 최종 위치만 보면 순간이동과 구별이 안 된다")
	t.ok(max_step <= Rules.CLONE_SPEED_FOLLOW * DT + 0.01,
			"한 스텝 이동이 속도×dt 를 넘지 않았다 (%.3f)" % max_step)

	# The command must not drag the host around either — `1` moves the swarm, never the player.
	t.eq(sw.pos[0], Vector2(600.0, 400.0), "호스트는 명령으로 움직이지 않았다")

	# Arrival stops. Without this the whole swarm jitters on one coordinate forever and separation fights
	# steering every frame.
	for _s in 600:
		sw.step(DT, null)
	var settled := _mean_dist(sw)
	# 130px is a pinned literal, not a bound read from the swarm. Forty bodies stop at the arrival ring
	# (~63px for this count) and the ones still coming push the ring outward, so the settled mean sits
	# near 110 — a ring, not a point. Anything under 130 means "arrived and stayed"; a swarm that kept
	# drifting, orbited, or scattered back out fails it.
	t.ok(settled <= 130.0, "도착한 뒤 호스트 근처에 머문다 (%.1f)" % settled)


func _mean_dist(sw: Swarm) -> float:
	var sum := 0.0
	for i in range(1, sw.count):
		sum += sw.pos[i].distance_to(sw.pos[0])
	return sum / float(maxi(1, sw.count - 1))
