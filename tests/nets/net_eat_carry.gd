extends RefCounted
## Eating, carrying, handing over — and losing it all.
##
## **The last rule is the one this file exists for.** "A clone killed far from home takes everything it
## carried with it" is the entire brake on scattering, and held as a reference it would fail silently with
## every check still green. So a loaded clone is actually killed and the bank is asserted unchanged.
##
## Both eat boundaries are pinned one pixel either side, so an off-by-one in the radius comparison bites.

const DT := 1.0 / 60.0


func run(t) -> void:
	# -- the boundary, from outside ---------------------------------
	var sw := Swarm.new()
	sw.setup(2, Vector2(500.0, 500.0))
	var c := sw.add_clone()
	sw.pos[c] = Vector2(1000.0, 1000.0)
	sw.eat_cd[c] = 0.0
	# Held still: FOLLOW with the rendezvous under its feet, so the clone cannot walk the last pixel and
	# turn a failing distance into a passing one.
	sw.command_rally(sw.pos[c])

	var far := _one_food(Vector2(1000.0 + Rules.EAT_RADIUS_CLONE + 1.0, 1000.0))
	sw.step(DT, far)
	t.eq(far.alive_count, 1, "먹기 반경 밖 먹이는 안 먹힌다")
	t.eq(sw.carried[c], 0.0, "반경 밖이면 아무것도 싣지 않는다")

	# -- and from inside --------------------------------------------
	var near := _one_food(Vector2(1000.0 + Rules.EAT_RADIUS_CLONE - 1.0, 1000.0))
	sw.eat_cd[c] = 0.0
	sw.step(DT, near)
	t.eq(near.alive_count, 0, "반경 안 먹이는 먹힌다")
	t.eq(sw.carried[c], 1.0, "먹은 것은 그 분신 몸에 실린다")
	t.eq(sw.banked, 0.0, "분신이 먹은 것은 아직 내 것이 아니다")

	# -- the host banks instantly -----------------------------------
	var host_food := _one_food(sw.pos[0] + Vector2(4.0, 0.0))
	sw.eat_cd[0] = 0.0
	sw.step(DT, host_food)
	t.eq(sw.banked, 1.0, "내가 문 것은 즉시 내 것이다")

	# -- absorption empties the clone, it does not delete it --------
	var before_count := sw.count
	sw.pos[c] = sw.pos[0] + Vector2(Rules.ABSORB_RADIUS - 2.0, 0.0)
	# The rendezvous moves onto the host too: left where it was, the clone walks AWAY during the same step
	# and leaves absorb range before the check runs — which would fail for a reason that is not the rule.
	sw.command_rally(sw.pos[0])
	sw.step(DT, null)
	t.eq(sw.banked, 2.0, "돌아온 분신이 실은 것을 넘겼다")
	t.eq(sw.carried[c], 0.0, "넘긴 분신은 빈 몸이 된다")
	t.eq(sw.count, before_count, "흡수해도 무리는 줄지 않는다 — 40마리 그림이 수확마다 사라지면 안 된다")

	# -- killed loaded, and it is gone ------------------------------
	var w := World.new()
	w.setup(4)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	var k := w.swarm.add_clone()
	w.swarm.pos[k] = Vector2(500.0, 500.0)
	w.swarm.carried[k] = 9.0
	var banked_before: float = w.swarm.banked
	var count_before: int = w.swarm.count
	w.pred_pos[0] = Vector2(500.0, 500.0)
	w.step(DT)

	t.eq(w.swarm.count, count_before - 1, "물린 분신은 사라진다")
	t.eq(w.clones_lost, 1, "잃은 분신으로 세어진다")
	t.eq(w.cargo_lost, 9.0, "싣고 있던 것이 잃은 것으로 세어진다")
	t.eq(w.swarm.banked, banked_before, "죽은 분신이 싣고 있던 것은 은행에 들어오지 않는다")
	t.eq(w.swarm.total_carried(), 0.0, "무리 어디에도 그 화물이 남아 있지 않다")


func _one_food(p: Vector2) -> Food:
	var f := Food.new()
	f.pos = PackedVector2Array([p])
	f.alive = PackedInt32Array([1])
	f.timer = PackedFloat32Array([0.0])
	f.alive_count = 1
	return f
