extends RefCounted
## Local depletion — the fourth of the four rules the round trip stands on.
##
## **`food.gd` was completely unmeasured**: the respawn budget forced to zero, the cooldown set to zero,
## and the whole `step()` body skipped were all green, because every other net zeroes the food out before
## it starts. Without depletion a tight ball beats a wide scatter and the width axis dies quietly — the
## build would still run, and it would be measuring nothing.

const DT := 1.0 / 60.0


func run(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var f := Food.new()
	f.setup(Rules.FIELD, Rules.FOOD_SPOTS, rng)
	t.eq(f.alive_count, Rules.FOOD_SPOTS, "시작하면 모든 자리에 먹이가 있다")

	var where: Vector2 = f.pos[3]
	t.ok(f.consume(3), "먹이를 먹는다")
	t.eq(f.alive_count, Rules.FOOD_SPOTS - 1, "먹은 만큼 줄어든다")
	t.ok(not f.consume(3), "같은 자리를 두 번 먹을 수는 없다")

	# One second later it is still gone. A respawn that ignores the cooldown would refill here.
	for _s in 60:
		f.step(DT)
	t.eq(f.alive[3], 0, "먹힌 자리는 1초 뒤에도 비어 있다")

	# Past the cooldown it comes back — **at the same coordinate**. Respawning anywhere would spread food
	# evenly however hard a region is worked, and then no region ever empties.
	for _s in 12 * 60:
		f.step(DT)
	t.eq(f.alive[3], 1, "쿨다운이 지나면 돌아온다")
	t.eq(f.pos[3], where, "돌아온 자리는 원래 자리다")

	# -- the budget --------------------------------------------------
	var g := Food.new()
	g.setup(Rules.FIELD, Rules.FOOD_SPOTS, rng)
	for i in 100:
		g.consume(i)
	t.eq(g.alive_count, Rules.FOOD_SPOTS - 100, "백 자리를 비웠다")

	for _s in 13 * 60:
		g.step(DT)
	var after_cooldown := g.alive_count
	var back := after_cooldown - (Rules.FOOD_SPOTS - 100)
	# 13 seconds: one past the cooldown, so exactly one second of budget has been spendable. Six per
	# second is the rule, and a literal 12 is the ceiling with a second of slack — an unbudgeted respawn
	# would put all 100 back at once.
	t.ok(back > 0, "쿨다운이 끝나면 돌아오기 시작한다 (%d)" % back)
	t.ok(back <= 12, "한꺼번에 다 돌아오지는 않는다 — 초당 예산이 있다 (%d)" % back)

	# -- and a worked region actually empties ------------------------
	var h := Food.new()
	h.setup(Rules.FIELD, Rules.FOOD_SPOTS, rng)
	var corner := Rect2(Vector2.ZERO, Rules.FIELD * 0.25)
	var in_corner := 0
	for i in h.pos.size():
		if corner.has_point(h.pos[i]):
			h.consume(i)
			in_corner += 1
	t.ok(in_corner > 0, "한 구역에 먹이가 있었다 (%d)" % in_corner)
	for _s in 300:
		h.step(DT)
	var left := 0
	for i in h.pos.size():
		if h.alive[i] == 1 and corner.has_point(h.pos[i]):
			left += 1
	t.eq(left, 0, "훑고 간 구역은 한동안 비어 있다 — 이게 넓게 흩는 이유다")
