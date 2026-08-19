extends RefCounted
## The planning state: an island that cannot be advanced until it is committed, a plan authored one
## `send` at a time and freely undone, and a fight that computes the same whatever rate it is watched
## at. Everything here is driven through `send` / `recall` / `commit` / `step` — the four calls the
## shell makes — and read back off the public columns. **No Node, no view, no shell**: if a row in this
## file can only be made to pass by wiring something on screen, it is in the wrong file.
##
## `net_boat` owns what a boat does once it is sailing; `net_battle` owns the phase order and the
## combat rules; `net_shell` owns the gestures that call into here. This file owns the plan itself.
##
## The design is `plan-then-watch`.
##
## ⚠ **Every equivalence row below carries a FLOOR as well as a ceiling.** Two runs that both did
## nothing at all compare equal on every column, so each arm asserts that it really advanced before
## the two are compared — a ceiling with no floor passes an effect that never happens.

## The bay every non-island fixture is built on: water for the first six columns of rows 3..7, land
## from column 6, one harbour at (2,5). Copied in shape from `net_boat`'s own bay on purpose — the two
## files measure different things about the same geometry, and a second shape would be a second set of
## hand-checked distances.
const ARENA_W := 24
const ARENA_H := 12

## Island 1's cheapest sendable tile from its start harbour (24,31): `√((28-24)² + (20-31)²)` = 11.70,
## which is `net_islands`' own `EXPECT_WAVE1[0][0]`. Written as two literals and self-checked below,
## never derived — a landing tile read back off the thing under test moves with it.
const ISLE1_LANDING_X := 28
const ISLE1_LANDING_Y := 20
const ISLE1_W := 48

## The largest roster a run can ever field: `START_MELEE + START_RANGED + REWARD_MELEE + REWARD_RANGED`.
## Written out here rather than summed from `Rules`, because 「배 수에 상한이 없다」 is the row that
## catches a brake being quietly reintroduced and a bound read off the thing it checks shrinks with it.
const FULL_ROSTER := 13


func run(t) -> void:
	_uncommitted_step_touches_nothing(t)
	_commit_refuses_an_empty_plan(t)
	_the_plan_is_sealed_by_the_commit(t)
	_one_drop_is_one_boat(t)
	_there_is_no_cap(t)
	_send_refusals(t)
	_a_boat_leaves_from_its_own_harbour(t)
	_recall_puts_the_soldier_back(t)
	_drop_order_takes_the_front(t)
	_thirteen_aimed_at_one_tile_stand_on_thirteen(t)
	_the_empty_boat_goes_home_and_vanishes(t)
	_one_slice_and_six_are_the_same_fight(t)
	_they_are_still_the_same_past_the_verdict(t)
	_uneven_frames_are_the_same_fight(t)
	_the_substep_count_itself_matches(t)
	_the_substep_itself_is_pinned(t)
	_zero_stops_the_clock(t)
	_the_comparison_itself(t)


# -- the commit gate --------------------------------------------------------------------------------

## ⚠ **The floor is the second half, not the first.** A `Battle` built wrong — a null grid, an army of
## nobody — is inert for reasons that have nothing to do with `_committed`, and every "unchanged"
## assertion below would pass on it. So the same fixture, driven by the same loop, is committed at the
## end and has to move.
func _uncommitted_step_touches_nothing(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 7, 5)], 999.0)
	t.ok(b.send(0, _tile_of(6, 4)) >= 0 and b.send(1, _tile_of(6, 6)) >= 0,
			"두 척을 계획해 뒀다 (자가 점검)")

	var hp_before := b.enemy_hp[0]
	var pos_before: Array = [b.soldier_pos[0], b.soldier_pos[1]]
	var turns := 0
	for _i in 600:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		turns += 1
	# A loop whose condition is false from the start never runs the check at all — this repo has
	# shipped a settle loop that passed with zero iterations.
	t.eq(turns, 600, "600번 정말로 밀었다 (자가 점검)")
	t.eq(b.elapsed, 0.0, "커밋 전에는 600프레임을 밀어도 시계가 정확히 0이다")
	t.eq(float(b.boats[0]["t"]), 0.0, "커밋 전에는 0번 배의 항해 시간도 정확히 0이다")
	t.eq(float(b.boats[1]["t"]), 0.0, "커밋 전에는 1번 배의 항해 시간도 정확히 0이다")
	t.eq([b.soldier_pos[0], b.soldier_pos[1]], pos_before, "커밋 전에는 병사가 한 칸도 안 움직인다")
	t.eq(b.enemy_hp[0], hp_before, "커밋 전에는 적이 한 대도 안 맞는다")
	t.eq(b.substeps, 0, "커밋 전에는 서브스텝이 한 번도 안 돌았다")

	# The floor: the identical fixture and the identical call, after one `commit()`.
	t.ok(b.commit(), "같은 판을 커밋했다 (자가 점검)")
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(b.elapsed > 0.0, "커밋한 뒤에는 똑같은 호출이 시계를 움직인다 — 판이 죽어서 조용했던 게 아니다")
	t.ok(float(b.boats[0]["t"]) > 0.0, "그리고 배도 움직인다")


func _commit_refuses_an_empty_plan(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 7, 5)], 999.0)
	t.ok(not b.commit(), "빈 계획으로는 시작이 안 된다")
	t.ok(not b.committed(), "거절당한 시작은 상태도 안 건드린다")
	t.ok(b.send(0, _tile_of(6, 4)) >= 0, "한 척을 계획했다 (자가 점검)")
	t.ok(b.commit(), "배를 한 척이라도 띄웠으면 시작이 받아들여진다")
	t.ok(b.committed(), "그리고 확정 상태가 된다")
	t.ok(not b.commit(), "두 번째 시작은 거절된다")


func _the_plan_is_sealed_by_the_commit(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 3)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 7, 5)], 999.0)
	var uid := b.send(0, _tile_of(6, 4))
	t.ok(uid >= 0 and b.send(1, _tile_of(6, 6)) >= 0, "두 척을 계획해 뒀다 (자가 점검)")
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var size_before := b.boats.size()
	t.eq(b.send(2, _tile_of(6, 5)), -1, "커밋 뒤에는 병사를 더 못 보낸다")
	t.eq(b.boats.size(), size_before, "거절당한 send 는 배를 한 척도 안 늘렸다")
	t.eq(b.soldier_state[2], Battle.SoldierState.RESERVE, "그 병사는 항구에 그대로 남는다")
	t.ok(not b.recall(uid), "커밋 뒤에는 무를 수도 없다")
	t.eq(b.boats.size(), size_before, "거절당한 recall 은 배를 한 척도 안 줄였다")


# -- one drop, one boat, no ceiling -----------------------------------------------------------------

func _one_drop_is_one_boat(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 3)
	var b := _battle_of(_bay(), army, [], 999.0)
	t.eq(b.boats.size(), 0, "아직 아무것도 안 놓았다 (자가 점검)")
	var a := b.send(0, _tile_of(6, 4))
	t.eq(b.boats.size(), 1, "한 번 끌면 배 한 척이 생긴다")
	var c := b.send(1, _tile_of(6, 5))
	t.eq(b.boats.size(), 2, "두 번째도 한 척이다")
	var d := b.send(2, _tile_of(6, 6))
	t.eq(b.boats.size(), 3, "세 번째도 한 척이다")
	t.ok(a >= 0 and c >= 0 and d >= 0, "셋 다 배 번호를 돌려줬다 — uid 0 도 성공이다")
	t.eq([a, c, d].size(), {a: 1, c: 1, d: 1}.size(), "배마다 다른 번호를 받는다")
	t.eq(a, 0, "첫 배의 번호는 0이다 — 0 을 거절로 읽으면 흔한 쪽이 죽는다")


## ⚠⚠ **This is the deferred brake as a check** (`plan-then-watch`, OPEN 0). The user decided the brake
## is left out and added later — 「일단 빼고 만든 이후에 추가하자는 거임」 — so a cap appearing here is
## not a fix, it is a decision nobody made. **13 succeeded, not "more than five".**
func _there_is_no_cap(t) -> void:
	var g := _island_grid(0)
	var army := _army_of(Rules.CELL_MELEE, FULL_ROSTER)
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))
	var landing := _isle1_landing()
	t.ok(g.home_harbour_for(landing) >= 0, "(28,20) 은 어느 항구에서든 보낼 수 있는 칸이다 (자가 점검)")

	var sent := 0
	for i in FULL_ROSTER:
		if b.send(i, landing) >= 0:
			sent += 1
	t.eq(sent, FULL_ROSTER, "열세 번 다 보내졌다 — 배 수에 상한이 없다")
	t.eq(b.boats.size(), FULL_ROSTER, "열세 척이 동시에 떠 있다")
	var transit := 0
	for i in FULL_ROSTER:
		if b.soldier_state[i] == Battle.SoldierState.TRANSIT:
			transit += 1
	t.eq(transit, FULL_ROSTER, "열세 명 전부 배에 탔다")
	var aboard := 0
	for raw in b.boats:
		var boat: Dictionary = raw
		if (boat["soldiers"] as Array).size() == 1:
			aboard += 1
	t.eq(aboard, FULL_ROSTER, "배 한 척에 한 명씩이다")


func _send_refusals(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 3)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 7, 5)], 999.0)
	var good := _tile_of(6, 4)

	t.eq(b.send(-1, good), -1, "없는 병사 번호(-1)는 거절된다")
	t.eq(b.send(3, good), -1, "명부 크기와 같은 번호도 거절된다")
	t.eq(b.boats.size(), 0, "거절당한 시도들은 배를 안 만들었다")

	t.ok(b.send(0, good) >= 0, "멀쩡한 병사는 보내진다 (자가 점검)")
	t.eq(b.send(0, good), -1, "이미 보낸 병사는 다시 못 보낸다")
	t.eq(b.boats.size(), 1, "그리고 그 거절도 배를 안 늘렸다")

	# A dead soldier: `setup` puts anyone `army.alive` says is gone straight into DEAD.
	var dead_army := _army_of(Rules.CELL_MELEE, 2)
	dead_army.kill(0)
	var db := _battle_of(_bay(), dead_army, [], 999.0)
	t.eq(db.soldier_state[0], Battle.SoldierState.DEAD, "죽은 병사는 DEAD 로 들어온다 (자가 점검)")
	t.eq(db.send(0, good), -1, "죽은 병사는 못 보낸다")
	t.ok(db.send(1, good) >= 0, "옆의 산 병사는 보내진다 — 판이 통째로 막힌 게 아니다")

	# A tile no harbour can see. The bay's own harbour tile is water and therefore not landable.
	var water := int(b.grid.harbour_tiles[0])
	t.eq(b.send(1, water), -1, "어느 항구도 못 보는 칸은 거절된다")
	t.eq(b.send(1, -1), -1, "격자 밖 칸도 거절된다")
	t.eq(b.boats.size(), 1, "그 둘도 배를 안 늘렸다")


## ⚠ **A one-harbour fixture proves nothing here**: `home`, `start_harbour` and 0 are the same number,
## so every side of every comparison reads `0 == 0`. This fixture has three harbours and the landing's
## home harbour is deliberately NOT the start harbour.
func _a_boat_leaves_from_its_own_harbour(t) -> void:
	var rows := [
		"~~~~~~~~~~~~~~~~",
		"~..............~",
		"~..............~",
		"~~~~~~~~~#~~~~~~",
		"~~~H~~~~~~H~~~~~",
		"H~~~~~~~~~~~~~~~",
	]
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := _battle_of(rows, army, [_spawn(16, Rules.BISON, 14, 1)], 999.0)
	var landing := 2 * 16 + 12          # (12,2): the east harbour is the nearest that can see it
	var hb := b.grid.home_harbour_for(landing)
	t.ok(hb >= 0, "그 칸을 볼 수 있는 항구가 있다 (자가 점검)")
	t.ok(hb != b.grid.start_harbour,
			"그리고 그 항구는 시작 항구가 아니다 (자가 점검: %d != %d)" % [hb, b.grid.start_harbour])

	t.ok(b.send(0, landing) >= 0, "그 칸으로 보냈다 (자가 점검)")
	# ⚠ `from` is a deleted key — the boat is a polyline, so its departure point is `path[0]`.
	var path: PackedVector2Array = b.boats[0]["path"]
	var from: Vector2 = path[0]
	t.eq(from, b.grid.tile_point(int(b.grid.harbour_tiles[hb])),
			"배는 물길이 가장 짧은 항구에서 뜬다 — 시작 항구가 아니다")
	t.eq(path[path.size() - 1], b.grid.tile_point(landing), "그리고 항로의 끝은 그 상륙지다")
	t.eq(int(b.boats[0]["home"]), hb, "돌아갈 항구도 같은 한 번의 판정에서 적힌다")
	t.eq(b.soldier_pos[0], from, "그리고 병사도 그 항구에 서 있다")


func _recall_puts_the_soldier_back(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := _battle_of(_bay(), army, [], 999.0)
	var uid := b.send(0, _tile_of(6, 4))
	t.ok(uid >= 0 and b.send(1, _tile_of(6, 6)) >= 0, "두 척을 놓았다 (자가 점검)")

	t.ok(b.recall(uid), "고른 배를 무를 수 있다")
	t.eq(b.boats.size(), 1, "무르면 배가 한 척 줄어든다")
	t.eq(b.soldier_state[0], Battle.SoldierState.RESERVE, "무르면 병사가 항구로 돌아온다")
	t.eq(b.soldier_pos[0], Battle.OFFMAP, "자리도 setup 이 남긴 그대로다")
	t.eq(int((b.boats[0] as Dictionary)["uid"]), uid + 1, "남은 배는 다른 배다 — 엉뚱한 척을 지우지 않았다")

	var again := b.send(0, _tile_of(6, 5))
	t.ok(again >= 0, "무른 병사는 다시 보낼 수 있다")
	t.ok(again != uid, "그리고 새 번호를 받는다 — 죽은 번호는 재사용되지 않는다")
	t.ok(not b.recall(uid), "죽은 번호를 무르려 하면 거절된다")
	t.ok(not b.recall(-1), "없는 번호도 거절된다")


# -- what the drop ORDER decides, on a real island ---------------------------------------------------

## ⚠ **On a real `Islands` fixture, not a synthetic one.** Two boats aimed at the SAME tile from the
## same harbour have identical `dist` and identical speed, so they arrive on exactly the same sub-step;
## `_phase_landings`' ascending pass and `_free_tiles_from`'s reservation write are the only things
## between them. **That is the whole of what 「어느 순서로」 means now** (`plan-then-watch`, 4.4), and
## a single descending pass — which is what shipped before this round — gives the front row to the boat
## dropped LAST.
func _drop_order_takes_the_front(t) -> void:
	var landing := _isle1_landing()
	var first := _formation_of(t, [0, 1], landing)
	t.eq(first["front"], 0, "놓은 순서대로 앞자리를 가져간다 — 먼저 놓은 0번이 목표 칸에 선다")
	t.ok(first["back"] != landing, "나중에 놓은 1번은 목표 칸이 아니라 그 옆에 선다")

	var swapped := _formation_of(t, [1, 0], landing)
	t.eq(swapped["front"], 1, "순서를 바꾸면 앞자리도 바뀐다 — 먼저 놓은 1번이 목표 칸에 선다")
	t.ok(swapped["back"] != landing, "그리고 이번엔 0번이 옆 칸이다")
	t.ok(first["front"] != swapped["front"],
			"두 배치가 실제로 다르다 — 한쪽 순서만으로 둘 다 통과할 수는 없다")

	# ⚠⚠ **The promise is only visible in the EVENT STREAM, and the polyline is why it has to be
	# re-asserted.** Final positions alone are also produced by a reversed pass 1 whose boats happened
	# to arrive a sub-step apart. Two boats aimed at ONE tile from ONE harbour now sail an identical
	# POLYLINE, so their `dist` must still be identical and they must still land on the SAME sub-step —
	# if a bending route ever gave them different lengths, drop order would silently become arrival
	# order and 「먼저 놓은 쪽이 앞줄」 would hold by accident instead of by rule.
	t.ok(absf(float(first["dist_a"]) - float(first["dist_b"])) <= 1e-5,
			"한 항구에서 한 칸으로 간 두 배의 항로 길이가 같다 (%.6f)" % float(first["dist_a"]))
	t.ok(int(first["route_points"]) >= 2,
			"그 항로는 %d점짜리다 (자가 점검)" % int(first["route_points"]))
	t.eq(int(first["land_substep_a"]), int(first["land_substep_b"]),
			"둘이 같은 서브스텝에 내린다 — 폴리라인이어도 도착이 안 갈린다")
	t.eq(first["land_order"], [0, 1],
			"그 서브스텝의 LAND 사건 순서가 놓은 순서 그대로다 — 최종 자리만 보면 못 잡는다")
	t.eq(swapped["land_order"], [1, 0], "순서를 뒤집으면 사건 순서도 뒤집힌다")


## Sends the given soldier ids to one tile in the given order, commits, and steps until both are
## ashore. Returns `{front, back}` — which soldier id stands ON `landing`, and the tile the other one
## took. `front` is -1 if nobody took the landing tile at all, which reddens the caller rather than
## reading as a pass.
func _formation_of(t, order: Array, landing: int) -> Dictionary:
	var g := _island_grid(0)
	var army := _army_of(Rules.CELL_MELEE, 2)
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))
	for raw in order:
		var sid := int(raw)
		t.ok(b.send(sid, landing) >= 0, "%d번 병사를 상륙지로 보냈다 (자가 점검)" % sid)
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var dist_a := float((b.boats[0] as Dictionary)["dist"])
	var dist_b := float((b.boats[1] as Dictionary)["dist"])
	var route_points := (b.boats[0]["path"] as PackedVector2Array).size()

	var turns := 0
	var land_order: Array = []
	var land_substep := {}
	while turns < 1200 and (b.soldier_state[0] != Battle.SoldierState.ASHORE
			or b.soldier_state[1] != Battle.SoldierState.ASHORE):
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		turns += 1
		# Read out of `events` in the order the sim appended them — that IS pass 1's walk order, and it
		# is the only place the drop-order promise is observable while it is being kept.
		for raw_ev in b.events:
			var ev: Dictionary = raw_ev
			if int(ev["kind"]) != Battle.Event.LAND:
				continue
			land_order.append(int(ev["id"]))
			land_substep[int(ev["id"])] = turns
	# A `while` that never ran, or ran out of budget, is a check measuring nothing.
	t.ok(turns > 0 and turns < 1200, "둘이 상륙할 때까지 %d 서브스텝 돌았다 (자가 점검)" % turns)
	t.eq(land_order.size(), 2, "LAND 사건을 정확히 둘 봤다 (자가 점검)")

	var out := {
		"front": -1, "back": -1,
		"dist_a": dist_a, "dist_b": dist_b, "route_points": route_points,
		"land_order": land_order,
		"land_substep_a": int(land_substep.get(int(order[0]), -1)),
		"land_substep_b": int(land_substep.get(int(order[1]), -2)),
	}
	for i in 2:
		var tile := g.tile_index(int(round(b.soldier_pos[i].x)), int(round(b.soldier_pos[i].y)))
		if tile == landing:
			out["front"] = i
		else:
			out["back"] = tile
	return out


## The dominant plan under the deferred brake — everything onto one tile — as a check that nobody
## stands on anybody. `_free_tiles_from` writes `grid.reserved` as it lands each soldier, and this is
## the row that reddens if that write is skipped.
func _thirteen_aimed_at_one_tile_stand_on_thirteen(t) -> void:
	var g := _island_grid(0)
	var army := _army_of(Rules.CELL_MELEE, FULL_ROSTER)
	var b := Battle.new()
	b.setup(g, army, Islands.spawns_of(0), Islands.time_limit_of(0))
	var landing := _isle1_landing()
	for i in FULL_ROSTER:
		t.ok(b.send(i, landing) >= 0, "%d번을 한 칸에 겹쳐 보냈다 (자가 점검)" % i)
	t.ok(b.commit(), "확정했다 (자가 점검)")

	var turns := 0
	while turns < 1200 and b.ashore_ids().size() < FULL_ROSTER:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		turns += 1
	t.ok(turns > 0 and turns < 1200, "열셋이 상륙할 때까지 %d 서브스텝 돌았다 (자가 점검)" % turns)
	t.eq(b.ashore_ids().size(), FULL_ROSTER, "열셋 전부 상륙했다")

	var taken := {}
	for i in FULL_ROSTER:
		var tile := g.tile_index(int(round(b.soldier_pos[i].x)), int(round(b.soldier_pos[i].y)))
		taken[tile] = true
	t.eq(taken.size(), FULL_ROSTER, "같은 칸을 노린 열셋이 열세 칸에 선다 — 아무도 겹치지 않는다")


func _the_empty_boat_goes_home_and_vanishes(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	# A live enemy far from the crossing, or `enemies_left() == 0` latches WON on the first sub-step
	# and every step after it returns before the boat has moved an inch.
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	var landing := _tile_of(6, 5)
	var uid := b.send(0, landing)
	t.ok(uid >= 0 and b.commit(), "한 척을 보내고 확정했다 (자가 점검)")

	var turns := 0
	while turns < 600 and b.soldier_state[0] != Battle.SoldierState.ASHORE:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		turns += 1
	t.ok(turns > 0 and turns < 600, "%d 서브스텝 만에 상륙했다 (자가 점검)" % turns)
	t.eq(b.boats.size(), 1, "내려놓은 배는 아직 목록에 있다")
	var boat: Dictionary = b.boats[0]
	t.eq(int(boat["phase"]), Battle.Phase.RETURNING, "빈 배가 되어 돌아가는 중이다")
	t.eq((boat["soldiers"] as Array).size(), 0, "화물은 비었다")
	var home := b.grid.home_harbour_for(landing)
	# The reversed path's LAST point is the harbour — read off `path`, never re-derived, because
	# reversing rather than recomputing is the whole rule this leg obeys.
	var back: PackedVector2Array = boat["path"]
	t.eq(back[back.size() - 1], b.grid.tile_point(int(b.grid.harbour_tiles[home])),
			"돌아가는 항로의 끝이 그 항구다")

	# The floor for the return leg: it is really SAILED, not teleported away on the unload sub-step.
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(float((b.boats[0] as Dictionary)["t"]) > 0.0, "돌아가는 다리도 실제로 항해한다")

	turns = 0
	while turns < 600 and not b.boats.is_empty():
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		turns += 1
	t.ok(turns > 0 and turns < 600, "%d 서브스텝 만에 돌아왔다 (자가 점검)" % turns)
	t.eq(b.boats.size(), 0, "빈 배는 항구까지 돌아가서 사라진다")
	for raw in b.boats:
		t.ok(int((raw as Dictionary)["uid"]) != uid, "그 번호는 목록에 없다")


# -- one span of time, cut into different numbers of pieces ------------------------------------------
#
# ⚠⚠ **These rows are NOT about the speed ladder and they survived its deletion on purpose.**
# `speed-off-open-landing` deleted the chips, the pause and every check that presses one — these press
# nothing. What they measure is `Battle.step`'s SUB-STEP DECOMPOSITION: that the same simulated span
# lands on identical state however many `dt` pieces it is handed in. That is the seam
# `battle.step(delta)` was kept taking a bare delta to preserve, and it is the only guarantee that a
# restored multiplier would still be arithmetically inert. Deleting them with the widget would have
# thrown that away and left nothing to restore against.

## Two identical fights, one driven 120 x `step(1/60)` and the other 20 x `step(6/60)` — the same 2.0
## seconds cut into 120 pieces and into 20.
##
## ⚠ **The floor is not decoration.** Without "both arms really advanced and somebody really got hit",
## a `step` that returned immediately would make every column below compare equal.
func _one_slice_and_six_are_the_same_fight(t) -> void:
	var slow := _skirmish()
	var fast := _skirmish()
	_plan_the_skirmish(t, slow)
	_plan_the_skirmish(t, fast)

	# 120 frames = 2.0 s: the crossing is 4.0 tiles at `BOAT_SPEED` 4.0, so a shorter run would compare
	# two arms that had not yet thrown a punch, and the floor below would be the only thing to catch it.
	for _i in 120:
		slow["battle"].begin_frame()
		slow["battle"].step(1.0 / 60.0)
	for _i in 20:
		fast["battle"].begin_frame()
		fast["battle"].step(6.0 / 60.0)

	var a: Battle = slow["battle"]
	var c: Battle = fast["battle"]
	t.ok(a.elapsed > 0.0 and c.elapsed > 0.0, "두 판 다 실제로 흘렀다 (자가 점검)")
	t.ok(a.enemy_hp[0] < Rules.hp_of(Rules.BISON), "잘게 쪼갠 쪽에서 적이 실제로 맞았다 (자가 점검)")
	_compare_arms(t, a, c, "같은 시간을 120조각으로 나눠도 20조각으로 나눠도 같은 싸움이다")


## The same pair driven PAST the verdict. ⚠ **The row above stops before it and stays green through the
## mutation this one catches** — a running test hoisted out of the sub-step loop lets a WON island keep
## attacking, and `army` carries to the next island so a soldier can die after the fight is over.
func _they_are_still_the_same_past_the_verdict(t) -> void:
	var slow := _skirmish()
	var fast := _skirmish()
	_plan_the_skirmish(t, slow)
	_plan_the_skirmish(t, fast)
	var a: Battle = slow["battle"]
	var c: Battle = fast["battle"]

	for _i in 1800:
		a.begin_frame()
		a.step(1.0 / 60.0)
	for _i in 300:
		c.begin_frame()
		c.step(6.0 / 60.0)

	t.ok(a.outcome() != Battle.Outcome.RUNNING, "잘게 쪼갠 쪽은 판정까지 갔다 (자가 점검)")
	t.ok(c.outcome() != Battle.Outcome.RUNNING, "굵게 쪼갠 쪽도 판정까지 갔다 (자가 점검)")
	t.eq(a.outcome(), c.outcome(), "판정이 난 뒤까지 몰아도 승패가 같다")
	t.eq(a.army.living_count(), c.army.living_count(), "판정이 난 뒤까지 몰아도 살아남은 수가 같다")
	_compare_arms(t, a, c, "판정이 난 뒤까지 몰아도 같다")


## An uneven, non-multiple `dt` sequence against the same total time cut into k-frame chunks — which is
## exactly what a k-times multiplier does per frame.
##
## ⚠ **The `1/60` pair above CANNOT fail the way this one can**: `6 x (1.0/60.0) == 0.1` exactly in IEEE
## double and the quotient is exactly `6.0`, so that fixture never leaves a remainder at all. This one
## does, on nearly every call, which is what makes it the row that measures `_substep_acc`.
func _uneven_frames_are_the_same_fight(t) -> void:
	var seq := _uneven_deltas()
	t.eq(seq.size(), 200, "고르지 않은 간격 200개를 만들었다 (자가 점검)")
	var multiples := 0
	for raw in seq:
		var d := float(raw)
		if absf(d / Rules.SIM_SUBSTEP_SEC - round(d / Rules.SIM_SUBSTEP_SEC)) < 1e-6:
			multiples += 1
	t.eq(multiples, 0, "그 중 서브스텝의 배수는 하나도 없다 (자가 점검)")

	var base := _skirmish()
	_plan_the_skirmish(t, base)
	var a: Battle = base["battle"]
	for raw in seq:
		a.begin_frame()
		a.step(float(raw))
	t.ok(a.elapsed > 0.0 and a.substeps > 0, "기준 판이 실제로 흘렀다 (자가 점검)")

	for k in [2, 3, 6]:
		var arm := _skirmish()
		_plan_the_skirmish(t, arm)
		var c: Battle = arm["battle"]
		var i := 0
		while i < seq.size():
			var chunk := 0.0
			var n := 0
			while n < k and i < seq.size():
				chunk += float(seq[i])
				i += 1
				n += 1
			c.begin_frame()
			c.step(chunk)
		_compare_arms(t, a, c, "고르지 않은 프레임 간격을 %d개씩 묶어도 같다" % k)


## ⚠ **Comparing final state catches *diverged*, never *vanished*.** `substeps` is incremented INSIDE
## the loop, so this is the one row that measures the process rather than the result — a remainder pass
## adds a phase pass without adding a second of simulated time, and every column in `_compare_arms`
## would be blind to it if the phases it re-ran happened to be idempotent that frame.
func _the_substep_count_itself_matches(t) -> void:
	var seq := _uneven_deltas()
	var base := _skirmish()
	_plan_the_skirmish(t, base)
	var a: Battle = base["battle"]
	for raw in seq:
		a.begin_frame()
		a.step(float(raw))
	t.ok(a.substeps > 0, "기준 판의 서브스텝 수가 0보다 크다 (자가 점검)")

	for k in [2, 3, 6]:
		var arm := _skirmish()
		_plan_the_skirmish(t, arm)
		var c: Battle = arm["battle"]
		var i := 0
		while i < seq.size():
			var chunk := 0.0
			var n := 0
			while n < k and i < seq.size():
				chunk += float(seq[i])
				i += 1
				n += 1
			c.begin_frame()
			c.step(chunk)
		t.ok(c.substeps > 0, "%d개씩 묶은 판의 서브스텝 수도 0보다 크다 (자가 점검)" % k)
		t.eq(c.substeps, a.substeps, "%d개씩 묶어도 서브스텝 횟수 자체가 같다" % k)


## ⚠⚠ **The equivalence rows above do NOT pin the sub-step's value, and that was measured.** Setting
## `SIM_SUBSTEP_SEC` to 1/20 leaves every one of them green — correctly, because additivity over `dt`
## is a property of the accumulator and holds for ANY sub-step size. What the value decides is the
## DISCRETISATION the whole fight is computed at, which is a rule, so it is pinned here as a literal
## with both of its ends written out.
func _the_substep_itself_is_pinned(t) -> void:
	t.eq(Rules.SIM_SUBSTEP_SEC, 1.0 / 60.0, "서브스텝은 정확히 1/60초다 — 리터럴로 못 박는다")
	# Floor: the lion's 0.6 s telegraph has to be at least five sub-steps, or the one beat the player
	# is supposed to read is decided in fewer frames than this repo has measured anyone seeing.
	t.ok(Rules.LION_WINDUP_SEC / Rules.SIM_SUBSTEP_SEC >= 5.0,
			"사자의 예고가 서브스텝 다섯 번 이상이다 (%.1f번)"
			% (Rules.LION_WINDUP_SEC / Rules.SIM_SUBSTEP_SEC))
	# Ceiling: the fastest unit (the crow, 6 tiles/s) must not cross a quarter of a tile in one
	# sub-step, or reservation contention — which 「the order you drop is the order」 now rides on —
	# resolves by iteration order instead of by geometry.
	t.ok(Rules.speed_of(Rules.CROW) * Rules.SIM_SUBSTEP_SEC <= 0.25,
			"가장 빠른 놈도 한 서브스텝에 0.25칸을 못 넘는다 (%.3f칸)"
			% (Rules.speed_of(Rules.CROW) * Rules.SIM_SUBSTEP_SEC))


func _zero_stops_the_clock(t) -> void:
	var army := _army_of(Rules.CELL_MELEE, 1)
	var b := _battle_of(_bay(), army, [_spawn(ARENA_W, Rules.BISON, 20, 1)], 999.0)
	t.ok(b.send(0, _tile_of(6, 5)) >= 0 and b.commit(), "보내고 확정했다 (자가 점검)")
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	var was := b.elapsed
	var steps_was := b.substeps
	t.ok(was > 0.0, "한 서브스텝이 시계를 움직였다 (자가 점검)")

	for _i in 120:
		b.begin_frame()
		b.step(0.0)
	t.eq(b.elapsed, was, "dt 0 은 시계를 세운다 — 120프레임을 밀어도 정확히 그대로다")
	t.eq(b.substeps, steps_was, "그리고 서브스텝도 한 번 더 안 돈다")

	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.ok(b.elapsed > was, "다시 dt 를 주면 이어서 간다 — 판이 죽은 게 아니다")

	# ⚠⚠ **This is what gives `if dt <= 0.0: return` a bite at all, and it took measuring to find.**
	# `step(0.0)` is already inert without that guard — the accumulator simply never reaches a whole
	# sub-step — so deleting it changes nothing about a zero frame. A NEGATIVE `dt` is the case that only the
	# guard catches: it eats into `_substep_acc` and silently delays the next sub-step, which reads as
	# the fight stuttering with every check about `elapsed` still green.
	var before_neg := b.elapsed
	var steps_neg := b.substeps
	b.begin_frame()
	b.step(-1.0)
	t.eq(b.elapsed, before_neg, "음수 dt 는 시계를 안 건드린다")
	t.eq(b.substeps, steps_neg, "그리고 서브스텝도 안 돈다")
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	t.eq(b.substeps, steps_neg + 1,
			"바로 다음 한 프레임이 정확히 한 서브스텝을 돈다 — 음수가 누적기를 갉아먹지 않았다")


# -- comparison ------------------------------------------------------------------------------------

## Every column two arms of the same fight can differ in. **All five, every time** — a comparison that
## reads one column proves the other four were never looked at.
func _compare_arms(t, a: Battle, c: Battle, label: String) -> void:
	var r := _columns_match(a, c)
	t.ok(bool(r["clock"]), "%s — 시계" % label)
	t.ok(bool(r["enemy_hp"]), "%s — 적 체력" % label)
	t.ok(bool(r["army_hp"]), "%s — 병사 체력" % label)
	t.ok(bool(r["pos"]), "%s — 병사 자리" % label)
	t.ok(bool(r["boats"]), "%s — 남은 배 수" % label)
	# ⚠ Added with the polyline: a boat now carries `leg`, `t` and `pos` of its own, and two arms could
	# agree on every soldier while their hulls sat on different segments — which is a picture that
	# differs with the sim's own state, exactly the split this file exists to forbid.
	t.ok(bool(r["boat_state"]), "%s — 배의 leg·t·자리" % label)


## The five columns, as five booleans. **Split out of `_compare_arms` so the READER can be inverted**:
## a comparison that answered "same" about columns it never looked at would make every equivalence row
## in this file green for free, and no mutation of `battle.gd` could ever find that — it is the
## instrument, not the subject. `_the_comparison_itself` below is the case that fails it.
func _columns_match(a: Battle, c: Battle) -> Dictionary:
	var hp_same := a.enemy_hp.size() == c.enemy_hp.size()
	if hp_same:
		for e in a.enemy_hp.size():
			if absf(a.enemy_hp[e] - c.enemy_hp[e]) > Rules.EPS:
				hp_same = false
				break
	var army_same := a.army.hp.size() == c.army.hp.size()
	if army_same:
		for i in a.army.hp.size():
			if absf(a.army.hp[i] - c.army.hp[i]) > Rules.EPS:
				army_same = false
				break
	var pos_same := a.soldier_pos.size() == c.soldier_pos.size()
	if pos_same:
		for i in a.soldier_pos.size():
			if Vector2(a.soldier_pos[i]).distance_to(Vector2(c.soldier_pos[i])) > Rules.EPS:
				pos_same = false
				break
	var boat_same := a.boats.size() == c.boats.size()
	if boat_same:
		for k in a.boats.size():
			var ba: Dictionary = a.boats[k]
			var bc: Dictionary = c.boats[k]
			if int(ba["leg"]) != int(bc["leg"]) or absf(float(ba["t"]) - float(bc["t"])) > Rules.EPS \
					or Vector2(ba["pos"]).distance_to(Vector2(bc["pos"])) > Rules.EPS:
				boat_same = false
				break
	return {
		"clock": absf(a.elapsed - c.elapsed) <= Rules.EPS,
		"enemy_hp": hp_same,
		"army_hp": army_same,
		"pos": pos_same,
		"boats": a.boats.size() == c.boats.size(),
		"boat_state": boat_same,
	}


## ⚠⚠ **Inverting the instrument, not the subject.** Twice in one night this repo shipped a check
## carrying the exact defect it existed to catch, and neither was found by mutating the code — both
## were found by mutating the check. So: two arms that are deliberately NOT the same fight, fed to the
## same reader every equivalence row above trusts. Every column has to come back false.
func _the_comparison_itself(t) -> void:
	var same := _skirmish()
	_plan_the_skirmish(t, same)
	var other := _skirmish()
	_plan_the_skirmish(t, other)
	var a: Battle = same["battle"]
	var c: Battle = other["battle"]
	var identical := _columns_match(a, c)
	t.ok(bool(identical["clock"]) and bool(identical["enemy_hp"]) and bool(identical["army_hp"])
			and bool(identical["pos"]) and bool(identical["boats"]),
			"같은 자리에서 출발한 두 판은 다섯 열이 다 같다 (자가 점검)")

	# Now drive one of them and nothing else. Every column has to notice.
	for _i in 240:
		a.begin_frame()
		a.step(Rules.SIM_SUBSTEP_SEC)
	var diverged := _columns_match(a, c)
	t.ok(not bool(diverged["clock"]), "비교기 자가 시험 — 시계가 다르면 다르다고 말한다")
	t.ok(not bool(diverged["enemy_hp"]), "비교기 자가 시험 — 적 체력도 잡는다")
	t.ok(not bool(diverged["army_hp"]), "비교기 자가 시험 — 병사 체력도 잡는다")
	t.ok(not bool(diverged["pos"]), "비교기 자가 시험 — 병사 자리도 잡는다")
	t.ok(not bool(diverged["boats"]), "비교기 자가 시험 — 남은 배 수도 잡는다")


# -- fixtures --------------------------------------------------------------------------------------

## A four-melee landing against two bison standing just inland: it lands at ~1.0 s and reaches a
## verdict in a handful of seconds, which is what keeps the equivalence rows well inside the runner's
## 120 s kill.
func _skirmish() -> Dictionary:
	var army := _army_of(Rules.CELL_MELEE, 4)
	var b := _battle_of(_bay(), army,
			[_spawn(ARENA_W, Rules.BISON, 8, 5), _spawn(ARENA_W, Rules.BISON, 9, 4)], 999.0)
	return {"battle": b, "army": army}


func _plan_the_skirmish(t, fixture: Dictionary) -> void:
	var b: Battle = fixture["battle"]
	var ok := b.send(0, _tile_of(6, 4)) >= 0
	ok = ok and b.send(1, _tile_of(6, 5)) >= 0
	ok = ok and b.send(2, _tile_of(6, 6)) >= 0
	ok = ok and b.send(3, _tile_of(6, 3)) >= 0
	t.ok(ok and b.commit(), "교전 판을 네 척으로 계획하고 확정했다 (자가 점검)")


## 200 deltas that are never a multiple of the sub-step and never repeat a value twice in a row.
## Deterministic — a random sequence would make a red round unreproducible.
func _uneven_deltas() -> Array:
	var out := []
	for i in 200:
		out.append(0.0069 + 0.0007 * float(i % 23) + 0.00013 * float(i % 7))
	return out


func _bay() -> Array:
	var rows := []
	for y in ARENA_H:
		if y == 0 or y == ARENA_H - 1:
			rows.append("~".repeat(ARENA_W))
		elif y >= 3 and y <= 7:
			var row := "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
			if y == 5:
				row = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
			rows.append(row)
		else:
			rows.append("~" + ".".repeat(ARENA_W - 2) + "~")
	return rows


func _island_grid(i: int) -> Grid:
	var g := Grid.new()
	g.load_rows(Islands.rows_of(i))
	return g


func _isle1_landing() -> int:
	return ISLE1_LANDING_Y * ISLE1_W + ISLE1_LANDING_X


func _tile_of(x: int, y: int) -> int:
	return y * ARENA_W + x


func _army_of(type_id: int, n: int) -> Army:
	var a := Army.new()
	for _i in n:
		a.add(type_id)
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var g := Grid.new()
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, army, spawns, limit)
	return b
