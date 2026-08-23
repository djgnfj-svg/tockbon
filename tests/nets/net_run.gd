extends RefCounted
## The session: a run over the node map, the three rewards, the two ways to lose, and restart.
##
## **The half of this that matters is that HP carries by IDENTITY and not by count.** A `begin_island`
## that built a fresh `Army` for every island would heal every wound, resurrect every corpse and drop
## every beak, and a check that only counted soldiers would stay green through all of it — the roster
## is the same size either way. So every carry-over assertion below names a specific id and reads a
## specific value, and the object itself is compared with `==` so a copied roster is a red rather than
## a coincidence. Rebuilding the roster inside `begin_island` reddens seven checks here.
##
## ⚠ **The run no longer walks a line of islands and `island_index` is no longer its position.** The
## position is `map.at()`; `island_index` is only what `enter_node` last wrote, and `_advance` does not
## touch it. **The row that measures that is 「`finish_island(true)` 는 `island_index` 를 혼자 안
## 옮긴다」**, and the mutation it exists for is putting `island_index += 1` back into `_advance`: the
## map would appear, the run would ignore it, and every check that only counted islands would stay
## green. The graph itself — floors, edges, routes, reachability — is `net_map`'s.
##
## Nothing here drives a fight to its natural end. Winning an island honestly takes a real battle and
## that is `net_battle`'s job; this file calls `finish_island(true)` directly, which is the same door
## the shell uses, and drives `battle.step` only for the two LOSSES — those are the ones the session
## has to read off the fight rather than be told.


## Island 1's cheapest sendable tile from its start harbour, written as two literals. Both losses below
## have to COMMIT the island before `step` will do anything at all (`plan-then-watch`, 4.3), and a
## commit refuses a plan with no boats — so each of them authors the smallest plan there is.
const ISLE1_LANDING_X := 28
const ISLE1_LANDING_Y := 20
const ISLE1_W := 48

## The two routes walked below, as node ids and nothing else. **They are the whole of the fork**: the
## first steps on three `COUNT` nodes and no beak node, the second on one `COUNT` node and two beak
## nodes. `net_map` proves those are the extremes of the real graph; this file proves the run ends up
## in a different place depending on which one the hand picked.
const ROUTE_ALL_CELLS := [0, 1, 4, 5, 6]
const ROUTE_TWO_BEAKS := [0, 2, 3, 5, 6]


## Every win now stops for the card pick before the map (「6개중 2택」), and `enter_node` refuses
## unless `_state == MAP` — so a route walk that does not take the two cards and close the board
## between two wins never reaches the second node at all. A no-op when the run has not stopped for a
## pick (a `REWARD` win has not reached `PICK` yet; the boss pays no cards at all), so a caller may call
## this after every `finish_island(true)` and every `apply_beak` unconditionally.
func _take_two_and_close_refit(r: Run, fit_into_slot0: bool = false) -> void:
	if r.state() != Run.State.PICK:
		return
	r.take_card(0)
	r.take_card(1)
	if fit_into_slot0:
		# A FIXED policy — always fit whatever landed into slot 0's own board, in the order taken —
		# used by `_the_route_is_what_the_board_holds` so the two routes are compared under IDENTICAL
		# fitting behaviour and only the CARDS the route itself produced can make the boards differ.
		# `fit(0, 0)` twice: after the first fit consumes held index 0, the second taken card is the
		# new index 0.
		r.army.loadout.fit(0, 0)
		r.army.loadout.fit(0, 0)
	r.close_refit()


func run(t) -> void:
	_starting_state(t)
	_hp_carries_by_identity(t)
	_rewards(t)
	_the_route_is_what_the_run_takes(t)
	_the_route_is_what_the_board_holds(t)
	_wipe_loses(t)
	_timeout_loses(t)
	_restart_resets(t)


# -- where a run begins -----------------------------------------------------------------------------

func _starting_state(t) -> void:
	var r := Run.new()
	# 「런은 지도에서 시작하고 밟은 칸이 없다」 — floor: the state is MAP; ceiling: nothing is walked.
	# ⚠ `State.MAP` is 0 on purpose, so a default-constructed int lands on the map rather than in a
	# battle against an island nobody entered.
	t.eq(r.state(), Run.State.MAP, "시작 상태는 지도다")
	t.eq(Run.State.MAP, 0, "그리고 MAP 이 0이다 — 기본값 int 가 아무도 안 고른 섬의 전투로 떨어지지 않는다")
	t.ok(r.map != null, "런이 지도를 하나 들고 시작한다")
	t.eq(r.map.path.size(), 0, "밟은 칸이 하나도 없다")
	t.eq(r.map.at(), -1, "서 있는 칸이 -1 이다")
	t.ok(r.begin_island() == null, "지도 위에서는 전투가 안 열린다 — 아무 섬도 안 골랐다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "시작할 때 기다리는 보상은 없다")
	t.eq(r.army.living_count(), Rules.roster_start_count(), "시작 병력은 10")
	t.eq(r.army.living_ids_of_type(Rules.CELL_MELEE).size(), Rules.slot_start_count(0), "근접 6으로 시작한다")
	t.eq(r.army.living_ids_of_type(Rules.CELL_RANGED).size(), Rules.slot_start_count(1), "원거리 4로 시작한다")

	# ⚠ **`Reward` moved to `rules.gd` and `Run.Reward` is gone.** It had to: `MAP_NODES` names the
	# reward column, and `rules.gd` referencing `Run` would close a class cycle. This row is what stops
	# a second copy of the enum growing back on `Run`.
	# ⚠ **The instrument is inverted on the same two lines.** `get_script_constant_map()` is what can
	# see an enum on a script at all, so the row that says `Reward` is NOT on `Run` is worthless
	# without the row proving the map does hold `State`, which is on `Run` and must stay there.
	# (`get_script_constant_map()` is not static, so it is asked of the instance's script — calling it
	# on the class name is a parse error on 4.7.1.)
	var run_constants: Dictionary = r.get_script().get_script_constant_map()
	t.ok(run_constants.has("State"),
		"State 는 Run 것이다 (자가 점검 — 이 줄이 빨개지면 아래 줄은 아무것도 안 재고 있다)")
	t.ok(not run_constants.has("Reward"),
		"보상 이름표는 Run 이 아니라 Rules 것이다 — 두 벌이면 값이 갈린다")
	# And that `Rules` holds it is not a second check: every `Rules.Reward.*` in this file is a
	# compile-time reference, so the whole net fails to parse if it moves again.

	# The map screen's one verb, refused from every state that is not the map.
	t.ok(not r.enter_node(3), "지도에서도 닿을 수 없는 칸은 못 밟는다")
	t.eq(r.map.path.size(), 0, "거절당한 뒤에도 자취가 비어 있다")
	t.ok(r.enter_node(0), "1층 칸은 밟힌다")
	t.eq(r.state(), Run.State.BATTLE, "칸을 밟자 전투가 됐다")
	t.eq(r.island_index, Rules.map_island_of(0), "그리고 그 칸이 가리키는 섬이 열렸다")
	t.ok(not r.enter_node(1), "전투 중에는 다음 칸을 못 밟는다 — 지도 상태가 아니다")
	t.eq(r.map.at(), 0, "그래서 서 있는 칸도 안 움직였다")

	var b := r.begin_island()
	t.ok(b != null, "첫 섬의 전투가 열린다")
	# Identity, not equality of contents. A `begin_island` that handed the fight a fresh roster of the
	# same size would satisfy every count above and this is the only line that sees it.
	t.ok(b.army == r.army, "전투는 런의 로스터 객체 그 자체를 쓴다 — 복사본이 아니다")
	t.eq(b.grid.w, 48, "격자 폭은 48")
	t.eq(b.grid.h, 32, "격자 높이는 32")
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "첫 섬의 적 수는 스폰 표와 같다")
	t.eq(b.time_limit, Islands.time_limit_of(0), "제한 시간은 islands.gd 가 준 값이다")
	t.eq(b.harbour_count(), 3, "첫 섬의 항구는 셋이다")


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

	t.ok(r.enter_node(0), "0번 칸을 밟는다")
	var was_index := r.island_index
	r.finish_island(true)
	# 「수 보상은 그 자리에서 붙고, 이기면 지도가 아니라 카드 고르기부터 연다」 — and ⚠⚠ **the floor as
	# well**: 「`finish_island(true)` 는 `island_index` 를 혼자 안 옮긴다」. Mutation: put
	# `island_index += 1` back into `_advance`, and the map becomes a picture the run ignores.
	t.eq(r.state(), Run.State.PICK, "첫 칸을 이기면 카드 고르기가 먼저 열린다 — 다음 섬으로 혼자 안 넘어간다")
	t.eq(r.island_index, was_index, "그리고 섬 번호를 혼자 안 옮긴다 — 어느 칸으로 갈지는 손이 정한다")
	t.eq(r.map.at(), 0, "서 있는 칸도 0번 그대로다")
	t.ok(r.begin_island() == null, "카드를 고르는 동안에도 전투는 안 열린다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "수 보상은 그 자리에서 소모된다 — 고를 것이 없다")

	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 비로소 지도다")

	# ⚠ The double-close hole is now closed by the map and not by a counter: a second call falls out on
	# the state guard because the run is no longer in BATTLE.
	r.finish_island(true)
	t.eq(r.map.path.size(), 1, "이긴 섬을 두 번 닫아도 자취가 안 늘어난다")
	t.eq(r.army.type_id.size(), 13, "그리고 보상이 두 번 붙지도 않았다")

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
	t.ok(r.enter_node(1), "2층 왼쪽 칸을 밟는다")
	t.eq(r.island_index, Rules.map_island_of(1), "그 칸이 가리키는 섬이 열렸다")
	var b := r.begin_island()
	t.ok(b != null, "둘째 섬의 전투가 열린다")
	t.ok(b.army == roster, "둘째 섬의 전투도 같은 로스터를 쓴다")
	t.eq(b.army.hp[3], 5.0, "둘째 섬의 전투가 든 3번도 상처 그대로다")
	t.eq(b.soldier_state[7], Battle.SoldierState.DEAD, "죽은 병사는 예비가 아니라 DEAD 로 들어간다")
	t.eq(b.soldier_state[3], Battle.SoldierState.RESERVE, "산 병사는 예비로 들어간다")
	t.eq(b.soldier_state.size(), 13, "전투는 죽은 줄까지 포함한 13줄을 본다")
	t.eq(b.time_limit, Islands.time_limit_of(r.island_index), "둘째 섬의 제한 시간")


# -- rewards ------------------------------------------------------------------------------------------

func _rewards(t) -> void:
	var r := Run.new()
	r.enter_node(0)
	r.finish_island(true)
	# Node 2 is the floor-2 node that pays the beak. Its sibling pays cells — that is the fork, and it
	# is the reason the reward is the NODE's and not the KIND's.
	t.eq(Rules.map_reward_of(2), Rules.Reward.BEAK, "2번 칸은 부리를 낸다 (자가 점검)")
	t.eq(Rules.map_reward_of(1), Rules.Reward.COUNT, "그 옆 1번 칸은 짐승을 낸다 (자가 점검)")
	# 0번 칸의 승리도 여섯 장을 냈다 — 카드를 고르고 정비를 닫아야 `enter_node` 가 다시 먹는다.
	_take_two_and_close_refit(r)
	t.ok(r.enter_node(2), "부리 칸을 밟는다")
	r.finish_island(true)

	t.eq(r.state(), Run.State.REWARD, "부리 칸을 이기면 고르기 화면이 열린다")
	t.eq(r.pending_reward(), Rules.Reward.BEAK, "기다리는 보상은 부리다")
	# 「부리를 고르는 동안 서 있는 칸이 안 바뀐다」 — the index is no longer the position, so the row
	# that used to read `island_index` reads the map now.
	t.eq(r.map.at(), 2, "고르는 동안 서 있는 칸은 2번에 머문다")
	t.ok(r.begin_island() == null, "보상 화면에서는 전투가 안 열린다")

	# A bad pick must not consume the reward. It is silent on purpose — the caller can see nothing
	# happened by reading pending_reward again.
	r.apply_beak(-1)
	t.eq(r.pending_reward(), Rules.Reward.BEAK, "음수 id 로는 부리가 소모되지 않는다")
	r.apply_beak(9_999)
	t.eq(r.pending_reward(), Rules.Reward.BEAK, "명단 밖 id 로도 소모되지 않는다")
	r.army.kill(5)
	r.apply_beak(5)
	t.eq(r.pending_reward(), Rules.Reward.BEAK, "죽은 병사에게는 부리를 못 단다")
	t.eq(r.army.has_beak[5], 0, "죽은 병사에게 부리가 붙지도 않았다")
	t.eq(r.state(), Run.State.REWARD, "잘못 고른 뒤에도 화면은 그대로 열려 있다")
	t.eq(r.map.at(), 2, "잘못 고른다고 칸이 넘어가지도 않는다")

	var before := r.army.range_of(1)
	r.apply_beak(1)
	t.eq(r.army.has_beak[1], 1, "고른 병사에게 부리가 붙었다")
	t.eq(r.army.range_of(1), before + Rules.BEAK_RANGE, "부리는 사거리를 1타일 늘린다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "부리는 한 번 쓰면 사라진다")
	# 「부리를 달고 나면 지도가 아니라 카드 고르기다」 — 2번 칸의 승리도 여섯 장을 냈고 `apply_beak`
	# 는 그 카드를 건드리지 않는다.
	t.eq(r.state(), Run.State.PICK, "고르고 나면 섬도 지도도 아니라 카드 고르기다")
	t.eq(r.map.at(), 2, "그리고 여전히 2번 칸에 서 있다")

	# 「한 칸은 부리를 한 번만 낸다」 — ⚠ **and this row changed meaning.** A route can hold two beak
	# nodes now, so nothing may treat "the roster already has a beak" as proof the reward was spent.
	# `_pending` is what proves it, and this is the check that says so.
	r.apply_beak(2)
	t.eq(r.army.has_beak[2], 0, "한 칸은 부리를 한 번만 낸다 — 두 번째 클릭은 아무것도 안 한다")

	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫아야 비로소 지도다")

	# 「경로가 다르면 명부가 다르다」 comes later; here the SECOND beak on the same run is what proves a
	# beak already on the roster is not the guard.
	t.ok(r.enter_node(3), "3층 왼쪽 칸을 밟는다")
	t.eq(Rules.map_reward_of(3), Rules.Reward.BEAK, "그 칸도 부리 칸이다 (자가 점검)")
	var b := r.begin_island()
	t.ok(b != null, "셋째 섬의 전투가 열린다")
	t.eq(b.army.has_beak[1], 1, "부리는 섬을 넘어 따라간다")
	t.eq(b.time_limit, Islands.time_limit_of(r.island_index), "이 섬의 제한 시간도 islands.gd 가 준 값이다")
	t.eq(b.enemies_left(), Islands.spawns_of(r.island_index).size(), "이 섬의 적 수")
	r.finish_island(true)
	t.eq(r.state(), Run.State.REWARD, "한 런에서 부리를 두 번 받을 수 있다 — 경로가 그렇게 갈렸으면")
	r.apply_beak(4)
	t.eq(r.army.has_beak[4], 1, "둘째 부리가 다른 병사에게 붙었다")
	t.eq(r.army.has_beak[1], 1, "첫째 부리도 그대로 남아 있다")
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "둘째 부리도 카드를 고르고 정비를 닫아야 지도다")

	# ⚠⚠ 「4층 칸(옛 상자 자리)도 섬을 열고, 이기면 짐승 보상을 낸다」 — the chest is gone; node 5 is a
	# fight now, exactly like every other node.
	var before_living := r.army.living_count()
	t.ok(r.enter_node(5), "4층 칸(옛 상자 자리)을 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "섬이 열린다 — 상자처럼 지도에 머물지 않는다")
	t.eq(r.island_index, Rules.map_island_of(5), "이 섬의 번호가 5번 칸이 가리키는 섬이다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.PICK, "COUNT 보상은 고를 게 없어도 카드 고르기부터 연다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "그리고 기다리는 짐승 보상은 없다")
	t.ok(r.army.living_count() > before_living, "COUNT 보상으로 병력이 늘었다")
	_take_two_and_close_refit(r)
	t.eq(r.state(), Run.State.MAP, "카드를 고르고 정비를 닫으면 지도로 돌아온다")

	# 「보스 칸을 이기면 `WON` 이고 지도로 안 돌아간다」
	t.ok(r.enter_node(6), "보스 칸을 밟는다")
	t.eq(r.state(), Run.State.BATTLE, "보스도 섬을 연다")
	r.finish_island(true)
	t.eq(r.state(), Run.State.WON, "보스를 이기면 런이 끝난다")
	t.ok(r.map.is_finished(), "지도도 끝난 것으로 읽힌다")
	t.ok(r.begin_island() == null, "끝난 런에서는 전투가 안 열린다")
	r.finish_island(false)
	t.eq(r.state(), Run.State.WON, "끝난 런은 뒤늦은 패배로 뒤집히지 않는다")
	t.eq(r.map.path, PackedInt32Array(ROUTE_TWO_BEAKS), "걸어온 자취가 부리 두 번 경로 그대로다")


# -- ⚠ the row that measures whether the fork does anything at all ------------------------------------

## 「경로가 다르면 명부가 다르다」 — two whole runs over the same map by the two extreme routes, and
## what comes out the other end has to DIFFER. **This is a floor, not a ceiling**: a map whose four
## routes all produce the same roster is a corridor with pictures on it, and that is the exact shape
## that killed this repo's second game — an advantage with no cost is not a decision.
func _the_route_is_what_the_run_takes(t) -> void:
	var cells := _walk_route(t, ROUTE_ALL_CELLS, "짐승 경로")
	var beaks := _walk_route(t, ROUTE_TWO_BEAKS, "부리 경로")

	t.eq(cells["state"], Run.State.WON, "짐승 경로로도 런이 끝난다")
	t.eq(beaks["state"], Run.State.WON, "부리 경로로도 런이 끝난다")
	t.ok(int(cells["living"]) > int(beaks["living"]),
		"짐승 경로가 병사가 더 많다 (%d명 > %d명) — 짐승 칸을 셋 다 지났다"
			% [int(cells["living"]), int(beaks["living"])])
	t.ok(int(beaks["beaks"]) > int(cells["beaks"]),
		"부리 경로가 부리가 더 많다 (%d개 > %d개)" % [int(beaks["beaks"]), int(cells["beaks"])])
	t.eq(int(cells["beaks"]), 0, "짐승 경로는 부리를 하나도 안 받는다 — 그게 그 갈래의 대가다")
	t.eq(int(beaks["beaks"]), 2, "부리 경로는 부리를 둘 받는다")
	# ⚠⚠ **3 -> 4 COUNT nodes on ROUTE_ALL_CELLS, 1 -> 2 on ROUTE_TWO_BEAKS**: node 5 (floor 4, the
	# ex-chest) pays `Reward.COUNT` now and every route steps on it, so both counts moved by one.
	t.eq(int(cells["living"]), Rules.roster_start_count()
		+ 4 * (Rules.roster_reward_count()),
		"짐승 경로 병사가 10 + 보상 넷 x 3 = 22명이다")
	t.eq(int(beaks["living"]), Rules.roster_start_count()
		+ 2 * (Rules.roster_reward_count()),
		"부리 경로 병사는 10 + 보상 두 번 x 3 = 16명이다 — 4층 칸도 짐승을 낸다")
	t.ok(int(cells["living"]) - int(beaks["living"]) >= 6,
		"두 경로의 병사 수가 %d명이나 갈린다 — 한 명 차이면 고를 이유가 없다"
			% (int(cells["living"]) - int(beaks["living"])))
	# The pool, because a soldier and a beak are not the same currency and the number the map prints
	# is the pool. Both routes are healed at the chest, so this compares like with like.
	t.ok(float(cells["pool"]) > float(beaks["pool"]),
		"HP 총합도 짐승 경로 쪽이 크다 (%.0f > %.0f)" % [float(cells["pool"]), float(beaks["pool"])])
	t.eq(cells["path"], PackedInt32Array(ROUTE_ALL_CELLS), "짐승 경로가 손이 고른 그 칸들을 그대로 걸었다")
	t.eq(beaks["path"], PackedInt32Array(ROUTE_TWO_BEAKS), "부리 경로도 손이 고른 그대로다")


## Walks one route end to end and reports what came out. Every step goes through the run's own public
## verbs — `enter_node`, `finish_island`, `apply_beak` — because a walk that poked at fields would
## measure the fixture.
## ⚠ `seed` and `fit_into_slot0` both default to "off", so every EXISTING call keeps behaving exactly
## as before — a route walk that never fits anything is unaffected by either argument, and its own
## comparisons (roster count, pool, beaks) do not depend on which cards were drawn, only on how many.
func _walk_route(t, route: Array, label: String, fit_into_slot0: bool = false, seed: int = -1) -> Dictionary:
	var r := Run.new()
	if seed >= 0:
		r.seed_cards(seed)
	var refused := 0
	for n in route:
		if not r.enter_node(int(n)):
			refused += 1
			continue
		if r.state() == Run.State.BATTLE:
			r.finish_island(true)
		if r.state() == Run.State.REWARD:
			# The first living soldier with no beak yet. A run may collect more than one now.
			for i in r.army.alive.size():
				if r.army.alive[i] != 0 and r.army.has_beak[i] == 0:
					r.apply_beak(i)
					break
		# Every win now stops for the card pick before the map, and `enter_node` refuses unless
		# `_state == MAP` — walk it all the way through, or the very next node in `route` is refused
		# and `refused` below reads a route that was never actually walked.
		_take_two_and_close_refit(r, fit_into_slot0)
	t.eq(refused, 0, "%s 다섯 칸이 전부 밟혔다 — 하나라도 거절당하면 걸은 길이 고른 길이 아니다" % label)
	var pool := 0.0
	var beaks := 0
	for i in r.army.alive.size():
		if r.army.alive[i] != 0:
			pool += r.army.hp[i]
			beaks += int(r.army.has_beak[i])
	return {"state": r.state(), "living": r.army.living_count(), "beaks": beaks, "pool": pool,
		"path": r.map.path, "board": r.army.loadout.board.duplicate()}


## ⚠ §8.4's dropped row: 「경로가 다르면 명부만이 아니라 판도 다르다」. The check above already proves
## the ROSTER differs by route; nothing anywhere checked the BOARD, and `grep -n 'board\|loadout'` over
## this file found nothing before this row. A FIXED fit policy (`fit_into_slot0`) is what makes the
## claim about the ROUTE and not about which slot a hand happened to fit into — without it, two boards
## fit by two different policies would differ for a reason that has nothing to do with the map.
##
## ⚠⚠ **Deliberately UNSEEDED, and that is not an oversight — it is measured to be the only option.**
## Both routes here are 5 nodes, 4 non-boss wins each (`ROUTE_ALL_CELLS` / `ROUTE_TWO_BEAKS`'s own
## sizes), and every non-boss win now pays six cards regardless of the node's OWN reward kind — so a
## seeded run draws the IDENTICAL card sequence on both routes (same call count, same RNG stream) and
## a fixed policy then fits the identical sequence into the identical slot: the boards are GUARANTEED
## equal, not just usually equal. Confirmed by running it seeded first — it failed 100% of runs, not
## flakily. Unseeded, this is the exact same "two runs, overwhelmingly likely to disagree" shape
## `_the_route_is_what_the_run_takes` right above already accepts for the roster and the pool.
func _the_route_is_what_the_board_holds(t) -> void:
	var cells := _walk_route(t, ROUTE_ALL_CELLS, "짐승 경로 (끼우며)", true)
	var beaks := _walk_route(t, ROUTE_TWO_BEAKS, "부리 경로 (끼우며)", true)
	var cells_board: PackedInt32Array = cells["board"]
	var beaks_board: PackedInt32Array = beaks["board"]
	t.eq(cells_board.size(), beaks_board.size(),
		"두 판의 크기는 같다 — 슬롯 수 x 부위 수는 경로와 무관하다 (자가 점검)")

	var cells_filled := 0
	var beaks_filled := 0
	for v in cells_board:
		if int(v) >= 0:
			cells_filled += 1
	for v in beaks_board:
		if int(v) >= 0:
			beaks_filled += 1
	t.ok(cells_filled > 0 and beaks_filled > 0,
		"두 판 다 실제로 뭔가 끼워져 있다 (%d칸, %d칸) — 빈 판끼리는 다를 수 없다" % [cells_filled, beaks_filled])
	t.ok(cells_board != beaks_board,
		"같은 정책으로 끼워도 짐승 경로와 부리 경로의 0번 슬롯 판이 서로 다르다 — 경로가 판에도 닿는다")


# -- losing ------------------------------------------------------------------------------------------

## The wipe. Driven through `battle.step` rather than asserted, because "every soldier is dead" is a
## verdict the fight has to reach on its own — the session only reads it.
func _wipe_loses(t) -> void:
	var r := Run.new()
	r.enter_node(0)
	var b := r.begin_island()
	t.eq(b.outcome(), Battle.Outcome.RUNNING, "전투는 굴러가는 상태로 시작한다")
	# The smallest plan there is, then the start button: without a commit `step` returns before
	# `_phase_clock` and the wipe would never be latched at all.
	t.ok(b.send(0, _isle1_landing()) >= 0 and b.commit(), "한 명을 보내고 시작을 눌렀다 (자가 점검)")
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
	t.eq(r.map.at(), 0, "져도 서 있는 칸은 그대로다 — 지도는 패널 뒤에 그대로 남는다")
	t.eq(r.map.path.size(), 1, "그리고 자취도 안 지워진다")
	t.ok(r.begin_island() == null, "진 런에서는 전투가 안 열린다")
	t.ok(not r.enter_node(1), "진 런에서는 다음 칸도 못 밟는다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "진 런은 보상을 주지 않는다")


## The clock, through a real `Run`. One soldier is landed and nine stay at the harbour, which is the
## smallest plan a commit will accept. The step count says the run ended ON the clock rather than
## early.
##
## ⚠⚠ **THE LIMIT IS SHORTENED HERE AND THAT IS THE FIX FOR THIS ISLAND'S LOSS RULE, NOT A DODGE.**
## This fixture used island 1's own 60 s and asserted 3600 sub-steps — and it only ever passed because
## the run could not end when the beachhead died. It can now: the lone soldier meets a bison and is
## dead at **7.95 s**, and holding nine reserves no longer keeps the island open. **What sat out the
## other 52 seconds was the defect the user reported**, so a check that needed those 52 seconds was
## measuring the defect.
##
## ⇒ The limit is cut to 5.0 s, comfortably before that death, so the timer is once again the only
## thing that can end this island. **The claim that `Islands.time_limit_of(0)` is what reaches the
## battle is not lost with it** — it is pinned on its own line at the top of this file, which is where
## it belongs; this row is about what the clock DOES, not where its number comes from.
func _timeout_loses(t) -> void:
	var r := Run.new()
	r.enter_node(0)
	var b := r.begin_island()
	t.ok(b.send(0, _isle1_landing()) >= 0 and b.commit(), "한 명만 보내고 시작을 눌렀다 (자가 점검)")
	t.eq(b.time_limit, Islands.time_limit_of(0), "섬이 준 제한 시간은 60초다 (자가 점검 — 줄이기 전에 확인한다)")
	var limit := 5.0
	b.time_limit = limit
	# ⚠ **One sub-step per call, never `step(1.0)`.** `step` consumes whole `Rules.SIM_SUBSTEP_SEC`
	# sub-steps and carries the leftover, so a 1.0 s call runs **59** of them and not 60 — the residue
	# after sixty subtractions lands a hair under the sub-step in IEEE double — and the run would need
	# a 61st call for a reason that is floating point rather than the clock.
	var steps := 0
	while b.outcome() == Battle.Outcome.RUNNING and steps < 8000:
		b.step(Rules.SIM_SUBSTEP_SEC)
		steps += 1

	t.eq(b.outcome(), Battle.Outcome.LOST, "한 명으로는 시간이 다 되어 진다")
	t.eq(b.lose_reason(), Battle.Lose.TIMEOUT, "패인은 시간 초과다")
	t.eq(steps, 300, "제한 시간 %.0f초 = 300 서브스텝을 다 쓰고 나서야 졌다" % limit)
	# Not `== 0.0`: repeated additions of `1/60` land a hair short of the limit, and `_phase_clock`
	# latches on `elapsed + EPS >= limit` for exactly that reason. Both ends, so a clock that never ran
	# is caught by the first line and a clock that overran is caught by the second.
	t.ok(b.elapsed >= limit - Rules.EPS, "시계는 제한 시간까지 갔다 (%.6f초)" % b.elapsed)
	t.ok(b.time_left() <= Rules.EPS, "남은 시간은 0에 붙는다 (%.12f초)" % b.time_left())
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "적은 하나도 안 죽었다 — 한 명으로는 못 죽인다")
	t.ok(r.army.living_count() >= 9, "항구에 남은 아홉은 한 명도 안 죽었다 — 안 내린 병사는 못 맞는다")

	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "시간 초과도 런을 끝낸다")


# -- restart -------------------------------------------------------------------------------------------

## ⚠ **`Run.restart()` does not die with the title screen.** The shell builds a fresh `Run` for
## 시작하기 and never calls this — but it is the only thing keeping `_reset` honest about a field added
## to one path and forgotten in the other, which is exactly how a second run would start somewhere the
## first did not with nothing to bark about it.
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
	r.enter_node(0)
	r.finish_island(true)
	# 0번 칸의 승리도 여섯 장을 냈다 — `enter_node` 는 `MAP` 이 아니면 조용히 거절하므로, 1번 칸을
	# 밟기 전에 카드를 고르고 정비를 닫아야 한다.
	_take_two_and_close_refit(r)
	r.enter_node(1)
	var first_map := r.map
	r.finish_island(false)
	t.eq(r.state(), Run.State.LOST, "재시작 전에는 진 상태다")
	t.eq(r.map.path.size(), 2, "그리고 두 칸을 걸어 둔 상태다 (자가 점검)")

	r.restart()
	# 「재시작하면 지도가 비고 상태가 MAP 이다」
	t.eq(r.state(), Run.State.MAP, "재시작하면 지도로 돌아간다 — 섬이 아니다")
	t.eq(r.map.path.size(), 0, "밟은 자취가 비었다")
	t.eq(r.map.at(), -1, "서 있는 칸도 -1 로 돌아갔다")
	t.ok(r.map != first_map, "지도도 새 객체다 — 이전 런의 자취를 물려받지 않는다")
	t.eq(r.island_index, 0, "섬 번호도 0으로 돌아간다")
	t.eq(r.pending_reward(), Rules.Reward.NONE, "기다리는 보상도 없다")
	t.ok(r.begin_island() == null, "그리고 지도 위이니 전투가 안 열린다")
	# The whole point of "identical starting state": a reset that reused the object would carry the
	# wounds forward and every count below would still be right.
	t.ok(r.army != first, "로스터는 새 객체다 — 이전 런의 상처를 물려받지 않는다")
	t.eq(r.army.type_id.size(), 10, "줄 수도 10으로 돌아간다 — 죽은 줄이 남아 있지 않다")
	t.eq(r.army.living_count(), 10, "10명 전부 살아 있다")
	t.eq(r.army.hp[0], Rules.hp_of(Rules.CELL_MELEE), "0번은 만피다")
	t.eq(r.army.alive[1], 1, "1번은 다시 살아 있다")
	t.eq(r.army.has_beak[2], 0, "부리도 사라졌다")
	t.eq(first.hp[0], 1.0, "옛 로스터는 고쳐진 게 아니라 버려졌다")
	t.eq(first_map.path.size(), 2, "옛 지도도 비워진 게 아니라 버려졌다")

	t.eq(r.map.reachable_nodes(), PackedInt32Array([0]), "그리고 다시 1층 한 칸만 열려 있다")
	t.ok(r.enter_node(0), "재시작 뒤 0번 칸을 다시 밟을 수 있다")
	var b := r.begin_island()
	t.ok(b != null, "재시작 뒤 첫 섬의 전투가 다시 열린다")
	t.ok(b.army == r.army, "새 전투는 새 로스터를 쓴다")
	t.eq(b.enemies_left(), Islands.spawns_of(0).size(), "적도 처음 수로 되살아나 있다")


func _isle1_landing() -> int:
	return ISLE1_LANDING_Y * ISLE1_W + ISLE1_LANDING_X
