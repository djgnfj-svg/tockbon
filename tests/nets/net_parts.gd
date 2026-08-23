extends RefCounted
## The part table (`rules.gd`) and the board it lands on (`loadout.gd`). See
## `parts-on-a-board-not-on-the-body`.
##
## ⚠⚠ Stage 2 grows this file with the `Army`/`Battle` rows — "two soldiers of one type can differ" is
## the row that proves a fitted part actually reaches combat, not merely a board that fills and empties.

const LOADOUT_PATH := "res://src/sim/loadout.gd"


func run(t) -> void:
	_the_table(t)
	_the_empty_board(t)
	_fitting_and_unfitting(t)
	_one_cell_one_part(t)
	_no_cell_argument_on_fit(t)
	# -- stage 2: parts reach combat --------------------------------------------------------------
	_the_board_survives_the_body(t)
	_every_row_carries_a_slot(t)
	_the_roster_table(t)
	_two_soldiers_of_one_type_can_differ(t)
	_the_beak_still_adds_to_range(t)
	_battle_reads_the_army(t)
	_enemies_stay_type_keyed(t)
	_slot_reserves_are_filtered_by_slot(t)


# -- stage 2: parts reach combat ----------------------------------------------------------------------

## 「판은 슬롯의 것이라 몸이 죽어도 안 사라진다」. Mutation: clear the board inside `kill`.
func _the_board_survives_the_body(t) -> void:
	var a := Army.new()
	var id := a.recruit(0)
	a.loadout.take_card(Rules.Part.CHEST, Rules.Species.MAMMAL)
	a.loadout.fit(0, 0)
	var fitted_hp := a.loadout.stat_of(0, Rules.PART_COL_HP)
	a.kill(id)
	t.eq(a.loadout.stat_of(0, Rules.PART_COL_HP), fitted_hp,
		"슬롯 0의 병사가 죽어도 판의 숫자는 그대로다")
	var next_id := a.recruit(0)
	t.eq(a.max_hp_of(next_id), fitted_hp,
		"그리고 다음에 그 슬롯에서 나온 병사가 끼워진 숫자를 그대로 읽는다")
	# ⚠⚠ 「그 병사는 그 숫자에서 태어난다」 — `max_hp_of` 자체가 아니라 `recruit`가 실제로 WRITE 한
	# `hp[next_id]`. Mutation: `army.gd`의 `hp[id] = max_hp_of(id)` -> `hp[id] = Rules.hp_of(t)` —
	# 위 줄만으로는 못 잡는다: `max_hp_of`는 여전히 올바른 값을 답하고, `hp[next_id]`만 기본값에서
	# 태어나 영원히 「다쳤다」로 읽힌다.
	t.eq(a.hp[next_id], fitted_hp,
		"그리고 실제로 그 숫자로 태어났다 — recruit 가 WRITE 한 hp[next_id] 자체를 잰다")


## ⚠ 「모든 명부 줄에 슬롯이 적혀 있다」. Mutation: `slot_id.append(slot)` -> `slot_id.append(-1)`.
func _every_row_carries_a_slot(t) -> void:
	var a := Army.new()
	a.add_starting_force()
	var bad := 0
	for i in a.type_id.size():
		var s := int(a.slot_id[i])
		if s < 0 or s >= Rules.summon_slot_count():
			bad += 1
	t.eq(bad, 0, "새 군대의 모든 명부 줄이 유효한 슬롯을 갖고 있다")


## 「시작 병력은 표의 열 명이고 슬롯별로 6과 4다」. Mutation: `[CELL_RANGED, 4, 1]` -> `[CELL_RANGED, 0, 1]`.
func _the_roster_table(t) -> void:
	t.eq(Rules.roster_start_count(), 10, "시작 병력은 표의 합인 열 명이다")
	var a := Army.new()
	a.add_starting_force()
	t.eq(a.living_ids_of_slot(0).size(), 6, "슬롯 0(근접)은 여섯으로 시작한다")
	t.eq(a.living_ids_of_slot(1).size(), 4, "슬롯 1(원거리)은 넷으로 시작한다")


## ⚠⚠ 「같은 종류 병사 둘이 서로 다를 수 있다」 — THE row of the round. Mutation:
## `damage_of` -> `Rules.damage_of(int(type_id[i]))`.
func _two_soldiers_of_one_type_can_differ(t) -> void:
	var plain := Army.new()
	var plain_id := plain.recruit(0)
	var armed := Army.new()
	var armed_id := armed.recruit(0)
	armed.loadout.take_card(Rules.Part.ARM, Rules.Species.MAMMAL)
	armed.loadout.fit(0, 0)
	t.eq(int(plain.type_id[plain_id]), int(armed.type_id[armed_id]),
		"두 병사는 같은 종류(근접)다 (자가 점검)")
	t.ok(armed.damage_of(armed_id) > plain.damage_of(plain_id),
		"팔을 낀 쪽의 공격력이 더 높다 — 같은 종류 병사 둘이 서로 달라졌다 (%.1f > %.1f)"
			% [armed.damage_of(armed_id), plain.damage_of(plain_id)])


## 「부리는 사거리에 그대로 얹힌다」. Mutation: drop `Rules.BEAK_RANGE` from `range_of`.
func _the_beak_still_adds_to_range(t) -> void:
	var a := Army.new()
	var id := a.recruit(0)
	var base := a.range_of(id)
	a.loadout.take_card(Rules.Part.HEAD, Rules.Species.BIRD)
	a.loadout.fit(0, 0)
	var with_head := a.range_of(id)
	t.eq(with_head, base + Rules.part_bonus(Rules.Part.HEAD, Rules.PART_COL_RANGE),
		"머리 부위가 사거리에 얹혔다")
	a.has_beak[id] = 1
	t.eq(a.range_of(id), with_head + Rules.BEAK_RANGE, "부리도 그 위에 그대로 얹힌다")


## ⚠⚠ 「전투가 병사 숫자를 Army 에서 읽는다」 — driven THROUGH `battle.step`, never by calling an
## `Army` accessor and comparing it against itself (`plain.army.damage_of(0) / plain.army.period_of(0)`
## asserts `Army.damage_of != Army.damage_of` and proves nothing about `battle.gd` — the shape this row
## used to be). A melee soldier stands one tile from a stationary bison; `Battle.setup` zeroes both
## cooldowns, and `REACH_BONUS` (1.5) clears the one-tile gap even at base range 0.0, so ONE sub-step
## lands exactly one blow each way — the same fixture shape `net_battle._no_friendly_fire` already
## drives for the identical reason. Three lookups, three rows, matching the plan's three named
## mutations inside `battle.gd`'s soldier attack branch.
func _battle_reads_the_army(t) -> void:
	# -- army.damage_of(i): a fitted 팔 moves the FIRST blow the sub-step actually threw ------------
	var plain := _adjacent_bison_battle(-1)
	var armed := _adjacent_bison_battle(Rules.Part.ARM)
	var plain_hit := Rules.hp_of(Rules.BISON) - plain.enemy_hp[0]
	var armed_hit := Rules.hp_of(Rules.BISON) - armed.enemy_hp[0]
	t.eq(plain_hit, Rules.damage_of(Rules.CELL_MELEE), "빈 판 병사는 종류값 그대로 때린다 (자가 점검)")
	t.ok(armed_hit > plain_hit,
		"팔을 낀 병사가 첫 타격에서 더 큰 피해를 준다 (%.1f > %.1f) — battle.step 이 army.damage_of 를 읽는다"
			% [armed_hit, plain_hit])
	t.eq(armed_hit, plain_hit + Rules.part_bonus(Rules.Part.ARM, Rules.PART_COL_DAMAGE),
		"차이가 정확히 팔 부위의 공격력 보너스다")
	# The enemy's own hp/type never moved — a fitted board must not leak onto the other side.
	t.eq(plain.enemy_type[0], armed.enemy_type[0], "적 종류는 양쪽 다 같다 (자가 점검)")

	# -- army.period_of(i): a fitted 손 moves the cooldown `step` actually WROTE after that blow ----
	var handed := _adjacent_bison_battle(Rules.Part.HAND)
	t.ok(is_equal_approx(plain._soldier_cd[0], Rules.period_of(Rules.CELL_MELEE)),
		"빈 판 병사의 쿨타임은 종류값 그대로 다시 찬다 (자가 점검)")
	t.ok(handed._soldier_cd[0] < plain._soldier_cd[0],
		"손을 낀 병사는 더 짧은 쿨타임으로 다시 찬다 (%.3f < %.3f) — battle.step 이 army.period_of 를 읽는다"
			% [handed._soldier_cd[0], plain._soldier_cd[0]])
	t.ok(is_equal_approx(handed._soldier_cd[0], handed.army.period_of(0)),
		"그 쿨타임이 정확히 army.period_of(0) 이다")

	# -- army.speed_of(i): a fitted 다리 moves how far a soldier OUT of reach walks in one sub-step --
	var plain_walk := _walk_probe(-1)
	var leg_walk := _walk_probe(Rules.Part.LEG)
	var plain_moved := _WALK_START.distance_to(plain_walk.soldier_pos[0])
	var leg_moved := _WALK_START.distance_to(leg_walk.soldier_pos[0])
	t.ok(plain_moved <= Rules.speed_of(Rules.CELL_MELEE) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
		"빈 판 병사는 종류값 그대로의 속도로, 딱 한 서브스텝만큼만 걸었다 (자가 점검)")
	t.ok(leg_moved > plain_moved,
		"다리를 낀 병사가 한 서브스텝에 더 멀리 걷는다 (%.4f > %.4f) — battle.step 이 army.speed_of 를 읽는다"
			% [leg_moved, plain_moved])
	t.ok(leg_moved <= leg_walk.army.speed_of(0) * Rules.SIM_SUBSTEP_SEC + Rules.EPS,
		"그리고 그 거리가 army.speed_of(0) 을 넘지 않는다 — 딱 한 서브스텝만큼만 걸었다")


## ⚠ 「적 숫자는 종류에서 그대로 읽는다」 — the opposite direction: a fitted PLAYER board must move
## NOTHING about what an enemy blow takes off a soldier. Driven through `battle.step`, comparing an
## unfitted army against one with 팔 fitted (which raises the PLAYER's own damage and nothing else) —
## if the enemy's damage read `army.loadout.bonus(0, PART_COL_DAMAGE)` by mistake, the armed soldier
## would take MORE from an identical enemy than the plain one does. **Two branches**, because the
## mutation this row guards against has two homes in `battle.gd`'s enemy attack code: the instant-hit
## path (any enemy without a wind-up — driven here with the bison) and the wind-up-complete path
## (driven here with the lion, the only type that carries one).
func _enemies_stay_type_keyed(t) -> void:
	var plain := _adjacent_bison_battle(-1)
	var armed := _adjacent_bison_battle(Rules.Part.ARM)
	t.eq(plain.army.hp[0], Rules.hp_of(Rules.CELL_MELEE) - Rules.damage_of(Rules.BISON),
		"안 낀 병사는 들소의 종류값 그대로 맞는다 (자가 점검 — 즉시 타격 갈래)")
	t.eq(armed.army.hp[0], plain.army.hp[0],
		"팔을 낀 판이어도 들소가 주는 피해는 그대로다 — 적은 플레이어 판을 안 읽는다 (즉시 타격 갈래)")

	var plain_lion := _adjacent_lion_battle(-1)
	var armed_lion := _adjacent_lion_battle(Rules.Part.ARM)
	t.ok(plain_lion.army.hp[0] < Rules.hp_of(Rules.CELL_MELEE), "예고가 끝나자 사자가 실제로 때렸다 (자가 점검)")
	t.eq(plain_lion.army.hp[0], Rules.hp_of(Rules.CELL_MELEE) - Rules.damage_of(Rules.LION),
		"안 낀 병사는 사자의 종류값 그대로 맞는다 (자가 점검 — 예고 갈래)")
	t.eq(armed_lion.army.hp[0], plain_lion.army.hp[0],
		"팔을 낀 판이어도 사자가 주는 피해는 그대로다 — 적은 플레이어 판을 안 읽는다 (예고 갈래)")


## 「슬롯 예비 병력은 슬롯으로 걸러진다」. Mutation: `army.slot_id[i] == slot` -> `army.type_id[i] == want`.
## ⚠ Built with a body whose SLOT is relabelled to 1 while its TYPE stays CELL_MELEE (slot 1's own
## bound type is CELL_RANGED) — a net-local stand-in for "a third slot bound to CELL_MELEE" that never
## touches `Rules.SUMMON_SLOTS`. Type-keyed filtering and slot-keyed filtering only disagree on exactly
## this body, which is why the row needs it rather than two ordinary recruits.
func _slot_reserves_are_filtered_by_slot(t) -> void:
	var a := Army.new()
	var id0 := a.recruit(0)
	var id1 := a.recruit(0)
	a.slot_id[id1] = 1
	var grid := Grid.new()
	grid.load_rows(Islands.rows_of(0))
	var b := Battle.new()
	b.setup(grid, a, [], 10.0)
	var slot0 := b.slot_reserve_ids(0)
	var slot1 := b.slot_reserve_ids(1)
	t.eq(slot0, [id0], "슬롯 0의 예비 명단이 근접 타입 전부가 아니라 슬롯 0의 몸만이다")
	t.eq(slot1, [id1], "슬롯 1의 예비 명단은 타입이 근접이어도 슬롯 1로 라벨된 몸을 담는다")


## A hand-built open arena — never the real islands, the same reasoning `net_battle`'s own header
## gives: a fixture that moves when someone edits an island measures the island, not the rule.
const _ARENA_W := 20
const _ARENA_H := 10

func _open_arena() -> Array:
	var rows := []
	for y in _ARENA_H:
		if y == 0 or y == _ARENA_H - 1:
			rows.append("~".repeat(_ARENA_W))
		else:
			rows.append("~" + ".".repeat(_ARENA_W - 2) + "~")
	return rows


## Puts a soldier on the island the way a landing would — state, position AND goal, plus the tile
## reservation `battle` writes on unload. `net_battle._ashore`'s own shape.
func _ashore_at(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[_tile_key(p, b.grid.w)] = i
	b.grid.reserved = claimed


func _tile_key(p: Vector2, w: int) -> int:
	return int(round(p.y)) * w + int(round(p.x))


## One melee soldier one tile from a stationary bison, `part` (a `Rules.Part`, or -1 for none) fitted
## into slot 0's board, driven exactly one sub-step through the real `battle.step`.
func _adjacent_bison_battle(part: int) -> Battle:
	var b := _adjacent_battle(part, Rules.BISON)
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	return b


## The same fixture with a lion — which announces before it strikes — driven until its wind-up ends
## and the blow actually lands. `net_battle`'s own "wait the wind-up out" shape: nobody here walks
## while it runs, so the 1-tile gap the fixture was built at is still the one the blow lands at.
func _adjacent_lion_battle(part: int) -> Battle:
	var b := _adjacent_battle(part, Rules.LION)
	var whole := Rules.hp_of(Rules.CELL_MELEE)
	for _f in 40:
		b.begin_frame()
		b.step(0.05)
		if b.army.hp[0] < whole:
			break
	return b


func _adjacent_battle(part: int, enemy_type: int) -> Battle:
	var a := Army.new()
	a.recruit(0)
	if part >= 0:
		a.loadout.take_card(part, Rules.Species.MAMMAL)
		a.loadout.fit(0, 0)
	var grid := Grid.new()
	grid.load_rows(_open_arena())
	var b := Battle.new()
	b.setup(grid, a, [{"type_id": enemy_type, "tile": _tile_key(Vector2(10, 5), _ARENA_W)}], 999.0)
	b._committed = true
	_ashore_at(b, 0, Vector2(9, 5))
	return b


## The soldier starts far enough from the (stationary, harmless-at-this-range) enemy that one
## sub-step is pure movement — no attack can land on either side yet.
const _WALK_START := Vector2(2.0, 5.0)

func _walk_probe(part: int) -> Battle:
	var a := Army.new()
	a.recruit(0)
	if part >= 0:
		a.loadout.take_card(part, Rules.Species.MAMMAL)
		a.loadout.fit(0, 0)
	var grid := Grid.new()
	grid.load_rows(_open_arena())
	var b := Battle.new()
	b.setup(grid, a, [{"type_id": Rules.BISON, "tile": _tile_key(Vector2(18, 5), _ARENA_W)}], 999.0)
	b._committed = true
	_ashore_at(b, 0, _WALK_START)
	b.begin_frame()
	b.step(Rules.SIM_SUBSTEP_SEC)
	return b


# -- the table --------------------------------------------------------------------------------------

func _the_table(t) -> void:
	# 「부위는 여섯이고 종은 셋이다」 — both halves. Mutation: delete the LEG row.
	t.eq(Rules.part_count(), 6, "부위는 여섯이다")
	t.eq(Rules.species_count(), 3, "종은 셋이다")

	# 「부위 표의 모든 줄이 다섯 칸이다」. Mutation: drop the last column of the ARM row.
	var short_rows := 0
	for p in Rules.part_count():
		if Rules.PART_STATS[p].size() != Rules.PART_COL_TOTAL:
			short_rows += 1
	t.eq(short_rows, 0, "부위 표의 모든 줄이 다섯 칸이다")

	# ⚠ 「어떤 부위도 아무 숫자도 안 움직이지 않는다」 — a part that exists and does nothing would still
	# pass every other row here, which is why this one measures every row independently rather than the
	# table as a whole. Mutation: zero out the ARM row.
	var dead_parts := 0
	for p in Rules.part_count():
		var moves_something := false
		for c in Rules.PART_COL_TOTAL:
			if not is_equal_approx(Rules.part_bonus(p, c), 0.0):
				moves_something = true
		if not moves_something:
			dead_parts += 1
	t.eq(dead_parts, 0, "여섯 부위 전부 적어도 하나의 숫자를 움직인다 — 있으나 마나 한 부위가 없다")

	# ⚠ 「여섯을 다 끼워도 공격주기가 0.2초 밑으로 안 간다」 — the bound is a LITERAL, not the table's own
	# sum, because a bound read out of the table it checks would move with the mutation it exists to
	# catch. Mutation: HAND's period bonus -0.15 -> -1.50.
	var full := Loadout.new()
	for p in Rules.part_count():
		full.board[0 * Rules.part_count() + p] = Rules.Species.MAMMAL
	var full_period := full.stat_of(0, Rules.PART_COL_PERIOD)
	t.ok(full_period >= 0.2,
		"여섯을 다 끼운 판의 공격주기가 0.2초 밑으로 안 간다 (%.2f)" % full_period)


# -- the empty board ----------------------------------------------------------------------------------

func _the_empty_board(t) -> void:
	# 「빈 판의 숫자는 UNITS 그대로다」 — slot 0 is CELL_MELEE: 14 · 2 · 1.0 · 0 · 4, as literals.
	# Mutation: make `stat_of` return `bonus(...)` alone (drops the base entirely).
	var lo := Loadout.new()
	t.eq(lo.stat_of(0, Rules.PART_COL_HP), 14.0, "빈 판의 체력이 UNITS 그대로 14다")
	t.eq(lo.stat_of(0, Rules.PART_COL_DAMAGE), 2.0, "빈 판의 공격력이 2다")
	t.eq(lo.stat_of(0, Rules.PART_COL_PERIOD), 1.0, "빈 판의 공격주기가 1.0이다")
	t.eq(lo.stat_of(0, Rules.PART_COL_RANGE), 0.0, "빈 판의 사거리가 0이다")
	t.eq(lo.stat_of(0, Rules.PART_COL_SPEED), 4.0, "빈 판의 이동속도가 4다")
	t.eq(lo.fitted_species(0, Rules.Part.HEAD), -1, "빈 칸은 -1로 읽힌다")
	t.eq(lo.fitted_species(-1, 0), -1, "슬롯 범위 밖도 -1이다")
	t.eq(lo.fitted_species(0, 999), -1, "부위 범위 밖도 -1이다")


# -- fit / unfit ---------------------------------------------------------------------------------------

func _fitting_and_unfitting(t) -> void:
	# 「가슴을 끼우면 체력이 4 오르고 나머지 넷은 안 움직인다」. Mutation: make `bonus` return 0.0.
	var lo := Loadout.new()
	lo.take_card(Rules.Part.CHEST, Rules.Species.BIRD)
	var before_hp := lo.stat_of(0, Rules.PART_COL_HP)
	t.ok(lo.fit(0, 0), "가슴 카드를 0번 슬롯에 끼운다")
	t.eq(lo.stat_of(0, Rules.PART_COL_HP), before_hp + 4.0, "체력이 정확히 4 올랐다")
	t.eq(lo.stat_of(0, Rules.PART_COL_DAMAGE), 2.0, "공격력은 안 움직였다")
	t.eq(lo.stat_of(0, Rules.PART_COL_PERIOD), 1.0, "공격주기는 안 움직였다")
	t.eq(lo.stat_of(0, Rules.PART_COL_RANGE), 0.0, "사거리는 안 움직였다")
	t.eq(lo.stat_of(0, Rules.PART_COL_SPEED), 4.0, "이동속도는 안 움직였다")
	t.eq(lo.fitted_species(0, Rules.Part.CHEST), Rules.Species.BIRD, "가슴 칸에 종이 적혔다")

	# ⚠ 「부위를 빼면 숫자가 정확히 원래대로 돌아온다」. Mutation: make `unfit` clear the cell without
	# appending to the pile (the number would still return, so the check is written against the PILE).
	var empty_val := Loadout.new().stat_of(0, Rules.PART_COL_HP)
	var pile_before := lo.held_part.size()
	t.ok(lo.unfit(0, Rules.Part.CHEST), "가슴을 뺀다")
	t.eq(lo.stat_of(0, Rules.PART_COL_HP), empty_val, "체력이 정확히 빈 판 값으로 돌아왔다")
	t.eq(lo.held_part.size(), pile_before + 1, "그리고 더미가 하나 늘었다 — 뺀 부위가 사라지지 않았다")
	t.eq(int(lo.held_species[lo.held_species.size() - 1]), Rules.Species.BIRD,
		"더미에 돌아온 카드의 종이 그대로다")

	# 빈 칸을 빼려 하면 false다.
	t.ok(not lo.unfit(0, Rules.Part.LEG), "빈 다리 칸을 빼려 하면 거절한다")


func _one_cell_one_part(t) -> void:
	# 「한 칸에는 한 부위뿐 — 가슴을 두 번 끼우면 앞엣것이 더미로 돌아온다」. Mutation: push the occupant
	# AFTER removing the new card (renumbers the pile under the index being removed).
	var lo := Loadout.new()
	lo.take_card(Rules.Part.CHEST, Rules.Species.MAMMAL)
	lo.take_card(Rules.Part.CHEST, Rules.Species.FISH)
	t.ok(lo.fit(0, 0), "첫 가슴 카드를 끼운다")
	var pile_before := lo.held_part.size()
	t.ok(lo.fit(0, 0), "같은 칸에 두 번째 가슴 카드를 끼운다")
	t.eq(lo.held_part.size(), pile_before, "더미 크기는 그대로다 — 하나 빠지고 하나 돌아왔다")
	var found_old := false
	for i in lo.held_species.size():
		if int(lo.held_part[i]) == Rules.Part.CHEST and int(lo.held_species[i]) == Rules.Species.MAMMAL:
			found_old = true
	t.ok(found_old, "앞에 끼웠던 종이 더미에 돌아와 있다")
	t.eq(lo.fitted_species(0, Rules.Part.CHEST), Rules.Species.FISH, "칸에는 나중 것만 남는다")


func _no_cell_argument_on_fit(t) -> void:
	# 「머리 칸에 다리를 넣을 함수가 없다」 — a source scan, declared as one: the behaviour it stands for
	# (there is no arrangement that puts a leg in the head cell) is unbuildable, which is why a text
	# check is all there is to buy here. Mutation: add a `part` parameter to `fit`.
	var f := FileAccess.open(LOADOUT_PATH, FileAccess.READ)
	t.ok(f != null, "loadout.gd 를 읽었다")
	if f == null:
		return
	var text := f.get_as_text()
	var at := text.find("func fit(")
	t.ok(at >= 0, "fit 함수를 찾았다")
	if at < 0:
		return
	var close := text.find(")", at)
	var sig := text.substr(at, close - at + 1)
	t.eq(sig, "func fit(slot: int, held_index: int)",
		"fit 의 매개변수가 슬롯과 더미 인덱스뿐이다 — 칸을 고르는 인자가 없다 (%s)" % sig)
