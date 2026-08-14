extends RefCounted
## Force, splitting, absorbing — and the swap that has to carry force with a body when it dies.
##
## **The rule this file exists for is the swap.** `remove_at()` moves the last row down, and a missing
## `force[i] = force[last]` line lands a dead clone's force on a survivor with no error and nothing on
## screen. It only shows when the row being removed is NOT the last one, so the check below kills the
## middle of three clones — killing the only clone never runs the swap branch at all and the missing line
## stays green.
##
## **The second is conservation.** `total_force()` ships for these checks alone: a split conserves the
## total, and a hand-rolled sum in every check would be the second copy `CLAUDE.md` forbids. But a total is
## conserved under EVERY order, so the cap check pins WHICH rows halved, not only the sum.
##
## `sim/` only. Loading a view file here would let a broken panel take the force checks down with it — the
## one exception is `look.gd`'s constant map in check 17, which is read as data, not instantiated.

const DT := 1.0 / 60.0


func run(t) -> void:
	_c1_opening(t)
	_c2_to_c6_split(t)
	_c7_to_c9_hold(t)
	_c10_cap_order(t)
	_c11_child_of_a_clone(t)
	_c12_to_c14_absorb(t)
	_c15_c16_death(t)
	_c15b_clone_kill_is_carried(t)
	_c17_constants(t)
	_c18_clear_beat(t)
	_c19f_split_is_not_power(t)


# -- 1: the run opens alone, at force 10 ---------------------------------------------------------------
## Driven off a real `World.setup()`, not a bare `Swarm`: putting `START_CLONES` back and looping it in
## `World::setup()` is the mutation, and only a `World` sees that line. The 10 is a literal — read through
## `Rules.FORCE_START` this check passes at every value, including the 1 the design rejected.
func _c1_opening(t) -> void:
	var w := World.new()
	w.setup(1)
	t.eq(w.swarm.count, 1, "런은 호스트 하나로 열린다 — 분열해서 만들지 않은 몸은 없다")
	t.eq(w.swarm.total_force(), 10, "호스트의 시작 힘은 10이다")
	t.eq(w.peak_swarm, 0, "최대 무리도 0에서 시작한다")


# -- 2..6: what one full hold does ---------------------------------------------------------------------
func _c2_to_c6_split(t) -> void:
	# 2: an even value halves into two equal halves and the total is untouched.
	var sw := Swarm.new()
	sw.setup(2, Vector2(1000.0, 1000.0))
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 2, "한 번 다 감으면 몸이 둘이 된다")
	t.eq(sw.force[0], 5, "부모에게 5")
	t.eq(sw.force[1], 5, "아이에게 5")
	t.eq(sw.total_force(), 10, "나눠도 힘의 총합은 그대로다 — 분열이 힘을 만들지 않는다")

	# 3: odd, so the halves are DIFFERENT and swapping them is visible. An even value cannot see that
	# mutation at all.
	var sw3 := Swarm.new()
	sw3.setup(3, Vector2(1000.0, 1000.0))
	sw3.force[0] = 5
	sw3.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw3.force[0], 3, "홀수는 부모가 큰 쪽을 갖는다 (5 → 3)")
	t.eq(sw3.force[1], 2, "아이는 작은 쪽을 갖는다 (5 → 2)")

	# 4: cargo is something a body is HOLDING, not what it is made of. Force-only checks pass with the
	# cargo written either way, so both rows are read.
	var sw4 := Swarm.new()
	sw4.setup(4, Vector2(1000.0, 1000.0))
	sw4.carried[0] = 6.0
	sw4.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw4.carried[0], 6.0, "나눠도 싣고 있던 것은 부모가 전부 갖는다")
	t.eq(sw4.carried[1], 0.0, "아이는 빈 몸으로 나온다")

	# 5: the split is simultaneous across EVERY body, not the host alone. Looping over index 0 only leaves
	# the clone's 3 whole and the total at 9.
	var sw5 := Swarm.new()
	sw5.setup(5, Vector2(1000.0, 1000.0))
	sw5.force[0] = 5
	sw5.add_clone(0, 3)
	sw5.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw5.count, 4, "호스트도 분신도 함께 갈라져 넷이 된다")
	t.eq([sw5.force[0], sw5.force[1], sw5.force[2], sw5.force[3]], [3, 2, 2, 1],
			"힘이 3·2·2·1로 나뉜다")
	t.eq(sw5.total_force(), 8, "총합은 5+3 그대로다")

	# 6: the loop bound is read ONCE. ⚠ **The mutation this catches is `while i < count`, not
	# `for i in count`** — measured on 4.7.1, `for i in <int>` evaluates its bound once, so dropping the
	# `snapshot` local changes nothing and this check would stay green against it. Rewritten as a `while`
	# that reads `count` live, the `2` that came out of a `5` is split again inside the same press and one
	# keypress walks force 10 down to a swarm of 1s.
	var sw6 := Swarm.new()
	sw6.setup(6, Vector2(1000.0, 1000.0))
	sw6.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw6.count, 2, "한 번 누름에 나온 아이는 그 자리에서 다시 갈라지지 않는다 (정확히 둘)")


# -- 7..9: the wind-up itself --------------------------------------------------------------------------
func _c7_to_c9_hold(t) -> void:
	# 7: force 1 cannot halve, and that is not an error.
	var sw := Swarm.new()
	sw.setup(7, Vector2(1000.0, 1000.0))
	sw.force[0] = 1
	sw.split_hold(Rules.SPLIT_HOLD_TIME * 2.0)
	t.eq(sw.count, 1, "힘 1짜리는 아무리 눌러도 갈라지지 않는다")
	t.eq(sw.force[0], 1, "그리고 힘도 줄지 않는다")

	# 8: an incomplete charge is dropped, not banked.
	var sw8 := Swarm.new()
	sw8.setup(8, Vector2(1000.0, 1000.0))
	sw8.split_hold(Rules.SPLIT_HOLD_TIME * 0.9)
	t.ok(sw8.split_charge > 0.0, "설정: 실제로 감기고 있었다 — 0이면 아래 검사는 아무것도 재지 않는다")
	t.eq(sw8.count, 1, "90%에서는 아직 갈라지지 않았다")
	sw8.split_release()
	t.eq(sw8.split_charge, 0.0, "손을 떼면 감긴 것이 버려진다")
	t.eq(sw8.count, 1, "떼는 것만으로 갈라지지도 않는다")

	# 9: **one split per hold.** Holding four times as long without ever releasing must add ONE body.
	# Mutation: zero the charge on firing and nothing else, and the key ratchets — the charge simply winds
	# again from zero and the swarm doubles every SPLIT_HOLD_TIME for as long as the finger is down.
	#
	# ⚠ The second half is not decoration. "One split per hold" is enforced by a latch, and a latch that is
	# never cleared satisfies the first assertion perfectly while making `F` a once-per-run key — measured:
	# with the clear removed from `split_release()` the first assertion alone stays green. The rule is one
	# split per hold, so the check has to see the NEXT hold split.
	var sw9 := Swarm.new()
	sw9.setup(9, Vector2(1000.0, 1000.0))
	var frames := int(4.0 * Rules.SPLIT_HOLD_TIME / DT)
	# ⚠ **The charge zeroing on FIRING was measured by nothing.** Every existing assertion about
	# `split_charge` exercises `split_release()`; `_hold_fired` latches the count either way, so deleting
	# `split_charge = 0.0` from the firing path left the whole round green while `field_view.gd` drew the
	# wind-up ring pinned FULL for as long as the finger stayed down — the split already landed and the
	# only feedback the hold has says it has not. Captured at the frame the body appeared, not at the end.
	var charge_at_fire := -1.0
	for _f in frames:
		var count_before := sw9.count
		sw9.split_hold(DT)
		if sw9.count > count_before and charge_at_fire < 0.0:
			charge_at_fire = sw9.split_charge
	t.eq(charge_at_fire, 0.0, "갈라진 그 순간 감김이 0으로 비워진다 (떼기를 기다리지 않는다)")
	t.eq(sw9.count, 2, "떼지 않고 네 배로 눌러도 몸은 하나만 늘어난다")
	sw9.split_release()
	for _f in int(Rules.SPLIT_HOLD_TIME / DT) + 1:
		sw9.split_hold(DT)
	t.eq(sw9.count, 4, "손을 뗐다가 다시 누르면 두 몸이 다시 갈라진다")


# -- 10: over the cap, the LOWEST indices split ---------------------------------------------------------
## ⚠ **Attack the check first.** With every body at the same force, "which rows halved" is unfalsifiable —
## reversing the order leaves an identical array. So every body gets a different force and the setup
## asserts that before anything else. The total is asserted too, but it is the weaker half: a total is
## conserved under every order.
func _c10_cap_order(t) -> void:
	var sw := Swarm.new()
	sw.setup(10, Vector2(1000.0, 1000.0))
	sw.force[0] = 4
	for i in Rules.CLONE_CAP - 3:
		sw.add_clone(0, 6 + 2 * i)
	var bodies := sw.count
	t.eq(bodies, Rules.CLONE_CAP - 2, "설정: 상한 세 자리를 남기고 채웠다")

	var before: Array = []
	var distinct := {}
	var sum_before := 0
	for i in bodies:
		before.append(sw.force[i])
		distinct[sw.force[i]] = true
		sum_before += sw.force[i]
	t.eq(distinct.size(), bodies, "설정: 몸마다 힘이 다르다 — 같으면 순서 주장은 반증 불가능해진다")

	sw.split_hold(Rules.SPLIT_HOLD_TIME)

	var moved: Array = []
	for i in bodies:
		if sw.force[i] != before[i]:
			moved.append(i)
	t.eq(moved, [0, 1, 2], "상한에 걸리면 낮은 번호부터 갈라진다 (0·1·2만 반으로 줄었다)")
	t.eq(sw.force[bodies - 1], before[bodies - 1], "가장 높은 번호는 힘을 통째로 지킨다")
	t.eq(sw.count - 1, Rules.CLONE_CAP, "분신 수가 상한에서 정확히 멈춘다")
	t.eq(sw.total_force(), sum_before, "상한에 걸려도 힘의 총합은 보존된다")


# -- 11: a clone's child is born at ITS parent ----------------------------------------------------------
## The parent sits 900px from the host on purpose: `add_clone()` used to spawn from `pos[0]` with
## `state[0]`, and reusing it unchanged puts every child of every clone on the host — invisible to any
## check that only ever splits the host.
func _c11_child_of_a_clone(t) -> void:
	var sw := Swarm.new()
	sw.setup(11, Vector2(1000.0, 1000.0))
	var p := sw.add_clone(0, 6)
	sw.pos[p] = sw.pos[0] + Vector2(900.0, 0.0)
	sw.state[p] = Swarm.SCATTER
	sw.force[0] = 1   ## the host cannot split, so the only new body is the clone's
	sw.split_hold(Rules.SPLIT_HOLD_TIME)
	t.eq(sw.count, 3, "설정: 분신 하나만 갈라졌다")
	var child := 2
	t.ok(sw.pos[child].distance_to(sw.pos[p]) <= Rules.CLONE_SPAWN_RING + 0.01,
			"아이는 제 부모 곁에 나온다 (%.1f)" % sw.pos[child].distance_to(sw.pos[p]))
	t.ok(sw.pos[child].distance_to(sw.pos[0]) > 800.0, "호스트 위에 나오지 않는다")
	t.eq(sw.state[child], Swarm.SCATTER, "아이는 부모의 상태를 물려받는다")


# -- 12..14: V ------------------------------------------------------------------------------------------
func _c12_to_c14_absorb(t) -> void:
	# 12: reach is ABSORB_RADIUS_BODIES × BODY_RADIUS = 56px. Two inside, one at 300px outside.
	var sw := Swarm.new()
	sw.setup(12, Vector2(1000.0, 1000.0))
	var near_a := sw.add_clone(0, 4)
	sw.pos[near_a] = sw.pos[0] + Vector2(30.0, 0.0)
	sw.carried[near_a] = 3.0
	var near_b := sw.add_clone(0, 6)
	sw.pos[near_b] = sw.pos[0] + Vector2(0.0, 50.0)
	sw.carried[near_b] = 2.0
	var far := sw.add_clone(0, 7)
	sw.pos[far] = sw.pos[0] + Vector2(300.0, 0.0)
	sw.carried[far] = 5.0

	t.eq(sw.absorb(), 2, "반경 안 둘만 흡수된다")
	t.eq(sw.count, 2, "흡수된 몸은 사라진다")
	# The literal 20 is 10 + 4 + 6, written out rather than read back from the clones: summing the same
	# fields the code summed would pass against a routine that adds nothing at all.
	t.eq(sw.force[0], 20, "흡수한 힘이 호스트에 정확히 더해진다")
	t.eq(sw.banked, 5.0, "싣고 있던 것도 함께 들어온다")
	t.eq(sw.force[1], 7, "반경 밖 분신의 힘은 건드리지 않는다")
	t.eq(sw.carried[1], 5.0, "반경 밖 분신의 화물도 그대로다")

	# 13: nothing in range is a real 0, not a silent success.
	var sw13 := Swarm.new()
	sw13.setup(13, Vector2(1000.0, 1000.0))
	var away := sw13.add_clone(0, 5)
	sw13.pos[away] = sw13.pos[0] + Vector2(400.0, 0.0)
	sw13.carried[away] = 2.0
	t.eq(sw13.absorb(), 0, "닿는 게 없으면 0을 돌려준다")
	t.eq(sw13.count, 2, "아무 몸도 사라지지 않는다")
	t.eq(sw13.force[0], 10, "호스트의 힘도 그대로다")
	t.eq(sw13.banked, 0.0, "은행도 그대로다")

	# 14: V MOVES cargo, it does not find it. Routed through `eat()` the same mouthful would be counted
	# twice and walking a clone home would be worth double.
	var sw14 := Swarm.new()
	sw14.setup(14, Vector2(1000.0, 1000.0))
	var loaded := sw14.add_clone(0, 3)
	sw14.pos[loaded] = sw14.pos[0] + Vector2(10.0, 0.0)
	sw14.eat(loaded, 4.0)   ## picked up in the field: `eaten` was already paid here
	var eaten_before := sw14.eaten
	var banked_before := sw14.banked
	t.eq(sw14.absorb(), 1, "설정: 실제로 하나를 흡수했다")
	t.ok(sw14.banked > banked_before, "V로 돌아온 화물은 은행에 들어온다")
	t.eq(sw14.eaten, eaten_before, "V는 먹은 총량을 올리지 않는다")


# -- 15/16: a body that dies takes its force with it ----------------------------------------------------
func _c15_c16_death(t) -> void:
	# 15: the one rule the whole build rests on, now with force alongside cargo. Neither reaches the host.
	var w := World.new()
	w.setup(15)
	_silence_food(w)
	var k := w.swarm.add_clone(0, 9)
	w.swarm.pos[k] = Vector2(500.0, 500.0)
	w.swarm.carried[k] = 9.0
	var banked_before: float = w.swarm.banked
	var force0_before: int = w.swarm.force[0]
	w.critter_count = 1
	w.critter_pos[0] = Vector2(500.0, 500.0)
	w.critter_threat[0] = Rules.CRITTER_THREAT_MAX
	w.critter_dir[0] = Vector2.ZERO
	w.step(DT)
	t.eq(w.swarm.count, 1, "설정: 물린 분신이 실제로 사라졌다")
	t.eq(w.swarm.banked, banked_before, "밖에서 죽은 분신의 화물은 은행에 들어오지 않는다")
	t.eq(w.swarm.force[0], force0_before, "그 힘도 호스트로 돌아오지 않는다")
	t.eq(w.swarm.total_force(), force0_before, "죽은 몸의 힘은 무리 어디에도 남지 않는다")

	# 16: ⚠ the row removed is NOT the last one. Killing the only clone hits `i == last`, the swap branch
	# never runs, and a missing `force[i] = force[last]` line stays green.
	var sw := Swarm.new()
	sw.setup(16, Vector2(1000.0, 1000.0))
	var c1 := sw.add_clone(0, 3)
	sw.carried[c1] = 1.0
	var c2 := sw.add_clone(0, 5)
	sw.carried[c2] = 2.0
	var c3 := sw.add_clone(0, 7)
	sw.carried[c3] = 4.0
	t.eq(sw.count, 4, "설정: 분신 셋을 세웠다")
	sw.remove_at(1)
	t.eq(sw.count, 3, "가운데 하나가 사라졌다")
	t.eq(sw.force[1], 7, "마지막 줄이 내려오면서 제 힘을 그대로 들고 왔다")
	t.eq(sw.carried[1], 4.0, "제 화물도 그대로 들고 왔다")
	t.eq(sw.force[2], 5, "건드리지 않은 줄은 그대로다")
	t.eq(sw.total_force(), 10 + 7 + 5, "사라진 몸의 힘 3만 총합에서 빠졌다")


# -- 15b: a clone's kill is CARRIED home, never banked from where it stands -------------------------------
## ⚠ `World._contact()`'s hunter branch loops over every body and used to pay `swarm.eat(0, ...)` whatever
## body actually made contact — so a clone sent across the map with `3` dropped `threat × CRITTER_MEAT`
## straight into the bank, unrisked and unwalked. That is the largest single income in the game and it was
## the only one with no recall discipline attached, which is the rule the whole build rests on. Every
## existing check drove the branch where the CRITTER is the hunter; none drove this one.
func _c15b_clone_kill_is_carried(t) -> void:
	var w := World.new()
	w.setup(151)
	_silence_food(w)
	# All the force on the host, so the swarm is a hunter while the clone doing the killing is a 1.
	w.swarm.force[0] = 100
	var c := w.swarm.add_clone(0, 1)
	var out := Vector2(500.0, 500.0)
	w.swarm.pos[c] = out
	# STRIKE standing on its own strike point: `desired` is zero, so the clone is exactly where it was put
	# when contact is tested, rather than a frame's walk toward the host.
	w.swarm.command_strike(out)
	w.critter_count = 1
	w.critter_pos[0] = out
	w.critter_threat[0] = 1
	w.critter_dir[0] = Vector2.ZERO
	t.ok(w.is_hunter_of(0), "설정: 무리가 이 생물을 잡아먹을 만큼 크다")
	t.ok(w.swarm.pos[0].distance_to(out) > 1000.0, "설정: 호스트는 1000px 넘게 떨어져 있다")
	var banked_before: float = w.swarm.banked
	var eaten_before: float = w.swarm.eaten
	w.step(DT)
	t.eq(w.critters_eaten, 1, "설정: 실제로 한 마리가 잡아먹혔다")
	t.eq(w.swarm.banked, banked_before, "밖에서 분신이 잡은 고기는 은행에 바로 들어오지 않는다")
	t.ok(w.swarm.carried[c] > 0.0, "잡은 그 분신이 그것을 지고 있다 (%.1f)" % w.swarm.carried[c])
	t.ok(w.swarm.eaten > eaten_before, "대조: 먹은 총량은 실제로 늘었다 — 아무 일도 없던 것이 아니다")


# -- 17: constants against constants --------------------------------------------------------------------
## A reach smaller than the body it belongs to is the bug the user caught on the first play. Written
## constant-against-constant so it holds however either is tuned.
##
## The third assertion is the one-owner rule. **`Look.HOST_RADIUS` no longer exists**, so it cannot be
## compared against `Rules.BODY_RADIUS`; what is left to protect is that a second copy never comes back.
## Read as `look.gd`'s runtime constant map rather than as file text — a grep measures a file's letters,
## this measures what the class actually declares.
func _c17_constants(t) -> void:
	t.ok(Rules.EAT_RADIUS_HOST > Rules.BODY_RADIUS, "호스트의 먹는 거리는 제 몸보다 넓다")
	t.ok(Rules.EAT_RADIUS_CLONE > Rules.CLONE_BODY_RADIUS, "분신의 먹는 거리는 제 몸보다 넓다")

	var look_script: GDScript = load("res://src/look.gd")
	var consts: Dictionary = look_script.get_script_constant_map()
	t.ok(consts.has("CLONE_LOAD_GROWTH"),
			"설정: 상수 목록을 실제로 읽었다 — 비어 있으면 아래 검사는 저절로 통과한다")
	t.ok(not consts.has("HOST_RADIUS") and not consts.has("CLONE_RADIUS"),
			"몸 반지름은 rules.gd 한 곳에만 있다 (look.gd에 사본이 없다)")


# -- 18: the clear beat still ends, ends EARLY, and conserves force ---------------------------------------
## `_clear_arrivals()` removing a body on arrival is the only thing that ever makes `swarm.count <= 1`
## true. **Deleting it does not hang the run** — `Run._finish_clear()`'s fallback still fires when
## `absorb_beat` runs out — so "the phase reached ENDING" alone is not the check.
##
## ⚠ **The tick bound comes from the beat's own clock, not a bare literal.** Written as 40 against a
## 72-tick beat, retuning `CLEAR_ABSORB_TIME` to 0.5 would put the fallback path at 30 ticks — under 40 —
## and this check would have reported "it ended the instant everyone arrived" with nothing having arrived
## early at all. The staggered arrivals are pinned separately, and that half cannot be satisfied by one
## lump removal at any beat length.
##
## **And the total force is asserted across the beat.** Three functions bring a body home and only
## `absorb()` used to move force; the other two dropped it, so `total_force()` was silently not conserved
## through the one moment the whole swarm comes back. This one assertion pins all three paths.
func _c18_clear_beat(t) -> void:
	var r := Run.new()
	r.start(18)
	_silence_food(r.world)
	r.world.critter_count = 0
	# Staggered radii, not one shared ring: six bodies at the same distance arrive on the SAME frame, and
	# then "several distinct frames" is unfalsifiable no matter how the removal is written.
	for i in 6:
		var c := r.world.swarm.add_clone(0, 1)
		var a := float(i) * 1.05
		r.world.swarm.pos[c] = r.world.swarm.pos[0] + Vector2(cos(a), sin(a)) * (100.0 + float(i) * 40.0)
	t.eq(r.world.swarm.count, 7, "설정: 분신 여섯을 세웠다")
	var force_before: int = r.world.swarm.total_force()
	t.eq(force_before, 16, "설정: 호스트 10 + 분신 여섯의 1 = 16")
	r.world.stage_cleared = true
	r.step(DT)
	t.eq(r.phase, Run.Phase.PLAY, "설정: 클리어를 감지했고 아직 박동 중이다")
	var ticks := 0
	var drops := 0
	var prev_count: int = r.world.swarm.count
	while r.phase == Run.Phase.PLAY and ticks < 300:
		r.step(DT)
		if r.world.swarm.count < prev_count:
			drops += 1
		prev_count = r.world.swarm.count
		ticks += 1
	t.eq(r.phase, Run.Phase.ENDING, "박동이 끝나고 ENDING에 도달한다")
	t.eq(r.world.swarm.count, 1, "박동이 끝나면 호스트만 남는다")
	t.ok(ticks < int(Rules.CLEAR_ABSORB_TIME / DT) / 2,
			"다 도착한 순간 끝난다 — 박동의 시계를 절반도 못 채운다 (%d틱)" % ticks)
	t.ok(drops >= 3, "몸이 한 덩어리로가 아니라 여러 프레임에 걸쳐 하나씩 도착한다 (%d번 줄었다)" % drops)
	t.eq(r.world.swarm.total_force(), force_before,
			"돌아온 몸의 힘이 호스트에 남는다 — 박동을 건너며 총합이 새지 않는다")


# -- 19f: splitting is not a power-up ---------------------------------------------------------------------
## ⚠ **This is the check the whole force system exists for and it was missing.** `F` conserves the total
## and multiplies the rows, so the only strength comparison in the build — `World.is_hunter_of()` — flipped
## for free the moment it read `swarm.count`: four holds, about two seconds, no eating and no risk, and
## every threat-1 critter turned from hunter into prey. Every conservation check in this file stayed green
## through it, because the total really was conserved. **The comparison has to read the number that did
## not move.**
##
## Both directions, or "never a hunter" passes just as well as the rule does.
func _c19f_split_is_not_power(t) -> void:
	var w := World.new()
	w.setup(19)
	_silence_food(w)
	w.critter_count = 1
	w.critter_pos[0] = Vector2(100.0, 100.0)
	w.critter_threat[0] = 1
	w.critter_dir[0] = Vector2.ZERO
	t.ok(not w.is_hunter_of(0), "설정: 시작 힘 10으로는 위협 1짜리도 아직 사냥감이 아니다")

	var before: int = w.swarm.total_force()
	for _h in 4:
		w.swarm.split_hold(Rules.SPLIT_HOLD_TIME)
		w.swarm.split_release()
	t.ok(w.swarm.count >= 8, "설정: 네 번 눌러 몸이 여덟 이상이 됐다 (%d개)" % w.swarm.count)
	t.eq(w.swarm.total_force(), before, "설정: 그동안 힘의 총합은 한 점도 늘지 않았다")
	t.ok(not w.is_hunter_of(0),
			"나누기만으로는 사냥자가 되지 않는다 — 기준은 몸의 수가 아니라 힘이다 (%d몸)" % w.swarm.count)

	w.swarm.force[0] += 20
	t.ok(w.is_hunter_of(0), "대조: 힘이 실제로 오르면 사냥자가 된다 — 아무것도 못 잡는 검사가 아니다")


func _silence_food(w: World) -> void:
	for i in w.food.alive.size():
		w.food.alive[i] = 0
	w.food.alive_count = 0
