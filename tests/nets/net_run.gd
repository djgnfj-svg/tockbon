extends RefCounted
## The session: three islands in a line, the two rewards, the two ways to lose, and restart.
##
## **The half of this that matters is that HP carries by IDENTITY and not by count.** A `begin_island`
## that built a fresh `Army` for every island would heal every wound, resurrect every corpse and drop
## every beak, and a check that only counted soldiers would stay green through all of it — the roster
## is the same size either way. So every carry-over assertion below names a specific id and reads a
## specific value, and the object itself is compared with `==` so a copied roster is a red rather than
## a coincidence. The first slice plan names exactly that mutation for this net to bite on, and it was
## run: rebuilding the roster inside `begin_island` reddens seven checks here.
##
## Nothing here drives a fight to its natural end. Winning an island honestly takes a real battle and
## that is `net_battle`'s job; this file calls `finish_island(true)` directly, which is the same door
## the shell uses, and drives `battle.step` only for the two LOSSES — those are the ones the session
## has to read off the fight rather than be told.


func run(t) -> void:
	_starting_state(t)
	_hp_carries_by_identity(t)
	_rewards(t)
	_wipe_loses(t)
	_timeout_loses(t)
	_restart_resets(t)


# -- where a run begins -----------------------------------------------------------------------------

func _starting_state(t) -> void:
	var r := Run.new()
	t.eq(r.island_index, 0, "런은 첫 섬에서 시작한다")
	t.eq(r.state(), Run.State.BATTLE, "시작 상태는 전투다")
	t.eq(r.pending_reward(), Run.Reward.NONE, "시작할 때 기다리는 보상은 없다")
	t.eq(r.army.living_count(), Rules.START_MELEE + Rules.START_RANGED, "시작 병력은 10")
	t.eq(r.army.living_ids_of_type(Rules.CELL_MELEE).size(), Rules.START_MELEE, "근접 6으로 시작한다")
	t.eq(r.army.living_ids_of_type(Rules.CELL_RANGED).size(), Rules.START_RANGED, "원거리 4로 시작한다")

	var b := r.begin_island()
	t.ok(b != null, "첫 섬의 전투가 열린다")
	# Identity, not equality of contents. A `begin_island` that handed the fight a fresh roster of the
	# same size would satisfy every count above and this is the only line that sees it.
	t.ok(b.army == r.army, "전투는 런의 로스터 객체 그 자체를 쓴다 — 복사본이 아니다")
	t.eq(b.grid.w, 32, "격자 폭은 32")
	t.eq(b.grid.h, 18, "격자 높이는 18")
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "첫 섬의 적 수는 스폰 표와 같다")
	t.eq(b.time_limit, Islands.time_limit_of(0), "제한 시간은 islands.gd 가 준 값이다")
	t.eq(b.dock_count(), 2, "첫 섬의 부두는 둘이다")


# -- the one that the plan names a mutation for ------------------------------------------------------

func _hp_carries_by_identity(t) -> void:
	var r := Run.new()
	var roster := r.army

	# Written through a local and assigned back: a Packed array is copy-on-write and a write into a
	# temporary would land nowhere while every read afterwards showed full health.
	var hp := roster.hp
	hp[3] = 5.0
	hp[9] = 2.5
	roster.hp = hp
	roster.kill(7)

	r.finish_island(true)
	t.eq(r.island_index, 1, "첫 섬을 이기면 곧장 둘째 섬이다 — 수 보상은 고를 것이 없다")
	t.eq(r.state(), Run.State.BATTLE, "수 보상은 화면을 열지 않는다")
	t.eq(r.pending_reward(), Run.Reward.NONE, "수 보상은 그 자리에서 소모된다")

	t.ok(r.army == roster, "섬을 넘어도 로스터 객체가 그대로다")
	t.eq(r.army.type_id.size(), 13, "죽은 줄은 남고 보상 셋이 붙어 13줄이다")
	t.eq(r.army.living_count(), 12, "살아 있는 것은 12명")
	t.eq(r.army.hp[3], 5.0, "3번의 상처가 그대로 넘어왔다 — 수가 아니라 정체성이다")
	t.eq(r.army.hp[9], 2.5, "9번의 상처도 그대로다")
	t.eq(r.army.alive[7], 0, "7번은 여전히 죽어 있다 — 죽음은 영구다")
	t.eq(r.army.hp[7], 0.0, "죽은 7번의 HP 는 0이다")
	t.eq(r.army.type_id[3], Rules.CELL_MELEE, "3번의 병종도 바뀌지 않았다")

	t.eq(r.army.type_id[10], Rules.CELL_MELEE, "보상 10번은 근접")
	t.eq(r.army.type_id[11], Rules.CELL_MELEE, "보상 11번은 근접")
	t.eq(r.army.type_id[12], Rules.CELL_RANGED, "보상 12번은 원거리")
	t.eq(r.army.hp[10], Rules.hp_of(Rules.CELL_MELEE), "보상 병사는 만피로 온다")
	t.eq(r.army.hp[12], Rules.hp_of(Rules.CELL_RANGED), "원거리 보상 병사도 만피다")

	# And the wounds have to reach the FIGHT, not merely survive in the roster.
	var b := r.begin_island()
	t.ok(b != null, "둘째 섬의 전투가 열린다")
	t.ok(b.army == roster, "둘째 섬의 전투도 같은 로스터를 쓴다")
	t.eq(b.army.hp[3], 5.0, "둘째 섬의 전투가 든 3번도 상처 그대로다")
	t.eq(b.soldier_state[7], Battle.SoldierState.DEAD, "죽은 병사는 예비가 아니라 DEAD 로 들어간다")
	t.eq(b.soldier_state[3], Battle.SoldierState.RESERVE, "산 병사는 예비로 들어간다")
	t.eq(b.soldier_state.size(), 13, "전투는 죽은 줄까지 포함한 13줄을 본다")
	t.eq(b.time_limit, Islands.time_limit_of(1), "둘째 섬의 제한 시간")


# -- rewards ------------------------------------------------------------------------------------------

func _rewards(t) -> void:
	var r := Run.new()
	r.finish_island(true)
	r.finish_island(true)

	t.eq(r.state(), Run.State.REWARD, "둘째 섬의 보상은 화면을 연다")
	t.eq(r.pending_reward(), Run.Reward.BEAK, "기다리는 보상은 부리다")
	t.eq(r.island_index, 1, "고르는 동안 섬 번호는 둘째 섬에 머문다")
	t.ok(r.begin_island() == null, "보상 화면에서는 전투가 안 열린다")

	# A bad pick must not consume the one beak the whole slice has. It is silent on purpose — the
	# caller can see nothing happened by reading pending_reward again.
	r.apply_beak(-1)
	t.eq(r.pending_reward(), Run.Reward.BEAK, "음수 id 로는 부리가 소모되지 않는다")
	r.apply_beak(9_999)
	t.eq(r.pending_reward(), Run.Reward.BEAK, "명단 밖 id 로도 소모되지 않는다")
	r.army.kill(5)
	r.apply_beak(5)
	t.eq(r.pending_reward(), Run.Reward.BEAK, "죽은 병사에게는 부리를 못 단다")
	t.eq(r.army.has_beak[5], 0, "죽은 병사에게 부리가 붙지도 않았다")
	t.eq(r.state(), Run.State.REWARD, "잘못 고른 뒤에도 화면은 그대로 열려 있다")
	t.eq(r.island_index, 1, "잘못 고른다고 섬이 넘어가지도 않는다")

	var before := r.army.range_of(1)
	r.apply_beak(1)
	t.eq(r.army.has_beak[1], 1, "고른 병사에게 부리가 붙었다")
	t.eq(r.army.range_of(1), before + Rules.BEAK_RANGE, "부리는 사거리를 1타일 늘린다")
	t.eq(r.pending_reward(), Run.Reward.NONE, "부리는 한 번 쓰면 사라진다")
	t.eq(r.state(), Run.State.BATTLE, "고르고 나면 다음 섬이 열린다")
	t.eq(r.island_index, 2, "셋째 섬이다")

	r.apply_beak(2)
	t.eq(r.army.has_beak[2], 0, "부리는 슬라이스 전체에 하나뿐이다 — 두 번째 클릭은 아무것도 안 한다")

	var b := r.begin_island()
	t.ok(b != null, "셋째 섬의 전투가 열린다")
	t.eq(b.army.has_beak[1], 1, "부리는 섬을 넘어 따라간다")
	# The label used to read "90초다" while comparing against the value's own source, so the 90 was
	# never measured anywhere. The literal lives in `net_islands` now; what this line measures is only
	# that `run` hands the island's own limit to the battle, and it says so.
	t.eq(b.time_limit, Islands.time_limit_of(2), "셋째 섬의 제한 시간도 islands.gd 가 준 값이다")
	t.eq(b.enemies_left(), Islands.spawns_of(2).size(), "셋째 섬의 적 수")

	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "마지막 섬을 이기면 런이 끝난다")
	t.eq(r.island_index, Islands.count() - 1, "이겨도 없는 넷째 섬으로 넘어가지 않는다")
	t.ok(r.begin_island() == null, "끝난 런에서는 전투가 안 열린다")
	r.finish_island(false)
	t.eq(r.state(), Run.State.WON, "끝난 런은 뒤늦은 패배로 뒤집히지 않는다")


# -- losing ------------------------------------------------------------------------------------------

## The wipe. Driven through `battle.step` rather than asserted, because "every soldier is dead" is a
## verdict the fight has to reach on its own — the session only reads it.
func _wipe_loses(t) -> void:
	var r := Run.new()
	var b := r.begin_island()
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "전투는 굴러가는 상태로 시작한다")
	for i in range(r.army.type_id.size()):
		r.army.kill(i)
	t.eq(r.army.living_count(), 0, "병사가 하나도 안 남았다")

	b.step(0.1)
	t.eq(b.outcome(), Battle.Outcome.LOST, "병사가 다 죽으면 섬을 진다")
	t.eq(b.lose_reason(), Battle.Lose.WIPED, "패인은 전멸이다")
	t.ok(b.enemies_left() > 0, "적이 아직 남아 있다 — 시간 초과와 헷갈릴 여지가 없다")
	t.ok(b.time_left() > 0.0, "시계도 아직 남아 있다")

	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "섬을 지면 런이 끝난다")
	t.eq(r.island_index, 0, "져도 섬 번호는 그대로다")
	t.ok(r.begin_island() == null, "진 런에서는 전투가 안 열린다")
	t.eq(r.pending_reward(), Run.Reward.NONE, "진 런은 보상을 주지 않는다")


## The clock. Nobody is landed, so nothing can be killed and nothing can die — the only way this ends
## is the timer, and the step count says it took the whole limit rather than ending early.
func _timeout_loses(t) -> void:
	var r := Run.new()
	var b := r.begin_island()
	var limit := Islands.time_limit_of(0)
	var steps := 0
	while b.outcome() == Battle.Outcome.RUNNING and steps < 200:
		b.step(1.0)
		steps += 1

	t.eq(b.outcome(), Battle.Outcome.LOST, "아무도 안 내리면 시간이 다 되어 진다")
	t.eq(b.lose_reason(), Battle.Lose.TIMEOUT, "패인은 시간 초과다")
	t.eq(steps, int(limit), "제한 시간 %.0f초를 다 쓰고 나서야 졌다" % limit)
	t.eq(b.time_left(), 0.0, "남은 시간은 0이다")
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "적은 하나도 안 죽었다")
	t.eq(r.army.living_count(), 10, "병사도 하나도 안 죽었다")

	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "시간 초과도 런을 끝낸다")


# -- restart -------------------------------------------------------------------------------------------

func _restart_resets(t) -> void:
	var r := Run.new()
	var first := r.army
	var hp := first.hp
	hp[0] = 1.0
	first.hp = hp
	first.kill(1)
	var beaks := first.has_beak
	beaks[2] = 1
	first.has_beak = beaks
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "재시작 전에는 진 상태다")

	r.restart()
	t.eq(r.state(), Run.State.BATTLE, "재시작하면 다시 전투다")
	t.eq(r.island_index, 0, "첫 섬으로 돌아간다")
	t.eq(r.pending_reward(), Run.Reward.NONE, "기다리는 보상도 없다")
	# The whole point of "identical starting state": a reset that reused the object would carry the
	# wounds forward and every count below would still be right.
	t.ok(r.army != first, "로스터는 새 객체다 — 이전 런의 상처를 물려받지 않는다")
	t.eq(r.army.type_id.size(), 10, "줄 수도 10으로 돌아간다 — 죽은 줄이 남아 있지 않다")
	t.eq(r.army.living_count(), 10, "10명 전부 살아 있다")
	t.eq(r.army.hp[0], Rules.hp_of(Rules.CELL_MELEE), "0번은 만피다")
	t.eq(r.army.alive[1], 1, "1번은 다시 살아 있다")
	t.eq(r.army.has_beak[2], 0, "부리도 사라졌다")
	t.eq(first.hp[0], 1.0, "옛 로스터는 고쳐진 게 아니라 버려졌다")

	var b := r.begin_island()
	t.ok(b != null, "재시작 뒤 첫 섬의 전투가 다시 열린다")
	t.ok(b.army == r.army, "새 전투는 새 로스터를 쓴다")
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "적도 처음 수로 되살아나 있다")
