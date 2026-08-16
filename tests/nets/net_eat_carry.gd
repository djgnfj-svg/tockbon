extends RefCounted
## Eating, carrying — and losing it all.
##
## **The last rule is the one this file exists for.** "A clone killed far from home takes everything it
## carried with it" is the entire brake on scattering, and held as a reference it would fail silently with
## every check still green. So a loaded clone is actually killed and the bank is asserted unchanged.
##
## **Handing over on contact is gone**, and its absence is asserted here rather than left to be noticed.
## A loaded clone standing on the host used to empty into it automatically, which made recall discipline
## free — the one thing this build measures. Cargo comes home because the player pressed `V`, or because
## the run cleared, and nothing else.
##
## Both eat boundaries are pinned one pixel either side, so an off-by-one in the radius comparison bites.
##
## **The pins are LITERALS and that is deliberate.** They read `Rules.EAT_RADIUS_CLONE` until the second
## adversarial review found that a bound taken from the thing it measures shrinks with it: the radius could
## be dropped to 5.0 and both checks stayed green. The two constant-against-constant checks below are the
## other half — a reach smaller than the body it belongs to is the bug the user caught on the first play,
## and it is the one failure this file cannot afford to let back in.

const DT := 1.0 / 60.0


func run(t) -> void:
	# -- the reach has to clear the body it belongs to --------------
	# Constant against constant, so it holds however either is tuned. Both radii live in `rules.gd` now,
	# not `look.gd`: they decide who `V` absorbs, so they change what happens.
	t.ok(Rules.EAT_RADIUS_HOST > Rules.BODY_RADIUS, "호스트의 먹는 거리는 제 몸보다 넓다")
	t.ok(Rules.EAT_RADIUS_CLONE > Rules.CLONE_BODY_RADIUS, "분신의 먹는 거리는 제 몸보다 넓다")

	# -- the boundary, from outside ---------------------------------
	var sw := Swarm.new()
	sw.setup(2, Vector2(500.0, 500.0))
	var c := sw.add_clone()
	sw.pos[c] = Vector2(1000.0, 1000.0)
	sw.eat_cd[c] = 0.0
	# **Held still**, and the freeze is the whole reason the pins below mean anything: without it the clone
	# walks the last pixel and turns a failing distance into a passing one.
	#
	# ⚠ **The freeze used to be "park the HOST 20px away", and clone↔host separation deleted that window.**
	# Parking on the host needs the distance to be under `rally_radius()`'s 24px floor (or the clone walks)
	# and over `BODY_RADIUS + CLONE_BODY_RADIUS` = 22 (or separation shoves the clone toward the food) — a
	# two-pixel window that would go red on any retune of either constant, and at 20 it silently moved the
	# clone 2px closer to the 17px pin below. So the clone is frozen by `3` at its OWN coordinate instead,
	# which holds however the radii are tuned, and the host stands 200px off where it cannot be mistaken for
	# the mouth that ate anything.
	sw.pos[0] = sw.pos[c] + Vector2(-200.0, 0.0)
	sw.command_strike(sw.pos[c])

	# 17.0 and 15.0 are literals around EAT_RADIUS_CLONE's 16.0. Shrink the constant and this goes red on
	# purpose — the value moving is the thing that has to be seen. 37px from the host, so the host's own
	# 26px reach cannot be what moved either.
	var far := _one_food(Vector2(1017.0, 1000.0))
	sw.step(DT, far)
	t.eq(far.alive_count, 1, "먹기 반경 밖 먹이는 안 먹힌다")
	t.eq(sw.carried[c], 0.0, "반경 밖이면 아무것도 싣지 않는다")

	# -- and from inside --------------------------------------------
	var near := _one_food(Vector2(1015.0, 1000.0))
	sw.eat_cd[c] = 0.0
	sw.step(DT, near)
	t.eq(near.alive_count, 0, "반경 안 먹이는 먹힌다")
	t.eq(sw.carried[c], 1.0, "먹은 것은 그 분신 몸에 실린다")
	t.eq(sw.banked, 0.0, "분신이 먹은 것은 아직 내 것이 아니다")

	# -- the host banks instantly -----------------------------------
	# Placed on the far side of the host (206px from the clone, which is still on its 1.5s eat cooldown
	# anyway) so there is no question which mouth this went into.
	var host_food := _one_food(sw.pos[0] + Vector2(-6.0, 0.0))
	sw.eat_cd[0] = 0.0
	var host_food_pos: Vector2 = host_food.pos[0]
	# **A new frame starts here, exactly as the shell starts one.** `step()` no longer clears the event lists
	# — see `Swarm.begin_frame()` — so the clone's mouthful two steps back would still be sitting in
	# `food_eaten_this_frame` and the §F-7 assertion below would be reading two entries.
	sw.begin_frame()
	sw.step(DT, host_food)
	t.eq(sw.banked, 1.0, "내가 문 것은 즉시 내 것이다")

	# -- §F-7: the sim records what was eaten and toward whom -------
	# **The clone `c` cannot also eat this frame** — its cooldown from the earlier mouthful is still running,
	# so this list holds exactly the host's bite and nobody else's.
	t.eq(sw.food_eaten_this_frame.size(), 1, "그 한 입이 목록에 하나로 남는다 %s" % str(sw.food_eaten_this_frame))
	if sw.food_eaten_this_frame.size() == 1:
		var fe: Dictionary = sw.food_eaten_this_frame[0]
		t.eq(fe["pos"], host_food_pos, "먹힌 자리는 그 먹이의 원래 자리다")
		t.eq(fe["to"], sw.pos[0], "간 곳은 먹은 몸(호스트)의 자리다")
	sw.step(DT, null)
	sw.begin_frame()
	t.eq(sw.food_eaten_this_frame.size(), 0,
			"프레임이 새로 시작하면(begin_frame) 비워진다 — view가 지우지 않아도 sim이 스스로 비운다")

	# -- touching the host does NOT hand anything over ---------------
	# The branch that did this is deleted, and this is what asserts it stays deleted. Standing on the host
	# for half a second must move nothing: recall is a key the player presses, not something that happens
	# because a clone drifted home.
	var before_count := sw.count
	var banked_before := sw.banked
	sw.pos[c] = sw.pos[0] + Vector2(Rules.ABSORB_RADIUS - 2.0, 0.0)
	# Back to `1`: the clone was frozen at a `3` point 200px away and would walk back to it over these thirty
	# steps, out of `absorb()`'s reach before the press below. Rallied it is already inside `rally_radius()`
	# and stays put — clone↔host separation lifts it from 18px to 22px on the first step and no further,
	# still well inside both that floor and `ABSORB_RADIUS_BODIES × BODY_RADIUS`.
	sw.command_rally()
	for _s in 30:
		sw.step(DT, null)
	t.eq(sw.banked, banked_before, "몸에 닿기만 해서는 화물이 넘어오지 않는다")
	t.eq(sw.carried[c], 1.0, "닿아 있어도 분신은 실은 것을 그대로 지고 있다")
	t.eq(sw.count, before_count, "닿았다고 분신이 사라지지도 않는다 — 40마리 그림이 저절로 없어지면 안 된다")

	# -- and `V` is what moves it ------------------------------------
	t.eq(sw.absorb(), 1, "V를 누르면 그제야 거둬들여진다")
	t.eq(sw.banked, banked_before + 1.0, "그때 화물이 은행에 들어온다")
	t.eq(sw.count, before_count - 1, "거둬들인 몸은 사라진다")

	# -- killed loaded, and it is gone ------------------------------
	var w := World.new()
	w.setup(4)
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
	# Forty rocks now sit wherever a fixture writes a coordinate, and `push_out` would move both of these off
	# one another. A check that is not about the ground removes the ground first.
	w.terrain.rock_pos.clear()
	w.terrain.rock_radius.clear()
	w.terrain.water_pos.clear()
	w.terrain.water_radius.clear()
	# `add_clone()` with no arguments is a force-0 body, so `Rules.BODY_HP_MIN` is its whole health and one
	# crow hit finishes it. That is what this check wants: it is about what a DEATH costs, not about how
	# many hits it takes to get there.
	var k := w.swarm.add_clone()
	w.swarm.pos[k] = Vector2(500.0, 500.0)
	w.swarm.carried[k] = 9.0
	var banked_before2: float = w.swarm.banked
	var count_before: int = w.swarm.count
	# ⚠ **An explicit species row, and the force is PINNED.** The threat model is gone: a creature's damage
	# is its own force, and a crow rolls 8–12, so a fixture that read the roll would pass or fail by seed.
	w.critter_count = 1
	w.boss_index = -1
	w.critter_pos[0] = Vector2(500.0, 500.0)
	w.critter_species[0] = Parts.Species.CROW
	w.critter_force[0] = 10
	w.critter_hp[0] = 30
	w.critter_flees[0] = 0
	w.critter_atk_cd[0] = 0.0
	w.critter_counter[0] = 0.0
	w.critter_dir[0] = Vector2.ZERO
	w.step(DT)

	t.eq(w.swarm.count, count_before - 1, "물린 분신은 사라진다")
	t.eq(w.clones_lost, 1, "잃은 분신으로 세어진다")
	t.eq(w.cargo_lost, 9.0, "싣고 있던 것이 잃은 것으로 세어진다")
	t.eq(w.swarm.banked, banked_before2, "죽은 분신이 싣고 있던 것은 은행에 들어오지 않는다")
	t.eq(w.swarm.total_carried(), 0.0, "무리 어디에도 그 화물이 남아 있지 않다")


func _one_food(p: Vector2) -> Food:
	var f := Food.new()
	f.pos = PackedVector2Array([p])
	f.alive = PackedInt32Array([1])
	f.timer = PackedFloat32Array([0.0])
	f.alive_count = 1
	return f
